--!strict
--[[
	AccountLevelService (servidor): gerencia XP e Nivel da Conta (monotonicamente crescente)
	e entrega das Recompensas de Nivel da Arvore perto da Torre.
	100% autoritativo no servidor: o cliente apenas exibe a barra e solicita o resgate.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataFolder = ReplicatedStorage:WaitForChild("Data")
local AccountLevel = require(DataFolder:WaitForChild("AccountLevel"))
local Benefits = require(DataFolder:WaitForChild("Benefits"))
local Items = require(DataFolder:WaitForChild("Items"))
local Retention = require(DataFolder:WaitForChild("Retention"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local Clock = require(script.Parent:WaitForChild("Clock"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ClaimLevelRewardRF = Remotes:WaitForChild("ClaimLevelReward") :: RemoteFunction
local AccountXpGainRE = Remotes:WaitForChild("AccountXpGain") :: RemoteEvent
local NotifyRE = Remotes:WaitForChild("Notify") :: RemoteEvent

local AccountLevelService = {}
local lastClaim: { [Player]: number } = {}

local function ensureAccount(data: any)
	if typeof(data.Account) ~= "table" then
		data.Account = { Level = 1, Xp = 0, TotalXp = 0, Claimed = {} }
	end
	local acc = data.Account
	acc.Level = math.max(1, math.floor(tonumber(acc.Level) or 1))
	acc.Xp = math.max(0, math.floor(tonumber(acc.Xp) or 0))
	acc.TotalXp = math.max(0, math.floor(tonumber(acc.TotalXp) or 0))
	if typeof(acc.Claimed) ~= "table" then
		acc.Claimed = {}
	end
	return acc
end

local function bagSlotsUsed(bag: { [string]: number }): number
	local n = 0
	for _, qty in pairs(bag) do
		if qty > 0 then
			n += 1
		end
	end
	return n
end

local function canFitItems(data: any, items: { [string]: number }?): boolean
	if not items then
		return true
	end
	data.Bag = data.Bag or {}
	local maxSlots = Benefits.BagSlots(data, Items.BagSlots)
	local used = bagSlotsUsed(data.Bag)
	local newSlots = 0
	for id, qty in pairs(items) do
		if qty > 0 then
			local cur = data.Bag[id] or 0
			if cur == 0 then
				newSlots += 1
			elseif cur + qty > Items.StackLimit then
				-- empilha ate 99 sem erro fatal, mas garante espaco para novos itens
			end
		end
	end
	return used + newSlots <= maxSlots
end

local function premiumBlocked(player: Player): boolean
	return player:GetAttribute("PaidRandomRestricted") ~= false
end

local function grantReward(player: Player, data: any, r: AccountLevel.LevelReward): ({ string }, number, number)
	local parts = {}
	local extraGems = 0
	local premTicketsGranted = 0
	if r.Gold and r.Gold > 0 then
		data.Gold = (data.Gold or 0) + r.Gold
		player:SetAttribute("LiveGold", data.Gold)
		table.insert(parts, "+" .. r.Gold .. " gold")
	end
	if r.Gems and r.Gems > 0 then
		data.Gems = (data.Gems or 0) + r.Gems
		table.insert(parts, "+" .. r.Gems .. " gemas")
	end
	if r.Tickets then
		data.Tickets = data.Tickets or { Comum = 0, Premium = 0 }
		if r.Tickets.Comum and r.Tickets.Comum > 0 then
			data.Tickets.Comum = (data.Tickets.Comum or 0) + r.Tickets.Comum
			table.insert(parts, "+" .. r.Tickets.Comum .. " invoca\u{e7}\u{e3}o Comum")
		end
		if r.Tickets.Premium and r.Tickets.Premium > 0 then
			if premiumBlocked(player) then
				local conv = r.Tickets.Premium * Retention.PremiumTicketGems
				data.Gems = (data.Gems or 0) + conv
				extraGems += conv
				table.insert(parts, "+" .. conv .. " gemas (no lugar da invoca\u{e7}\u{e3}o Premium)")
			else
				data.Tickets.Premium = (data.Tickets.Premium or 0) + r.Tickets.Premium
				premTicketsGranted += r.Tickets.Premium
				table.insert(parts, "+" .. r.Tickets.Premium .. " invoca\u{e7}\u{e3}o Premium")
			end
		end
	end
	if r.Items then
		data.Bag = data.Bag or {}
		local ids = {}
		for id in pairs(r.Items) do
			table.insert(ids, id)
		end
		table.sort(ids)
		for _, id in ipairs(ids) do
			local qty = r.Items[id]
			if qty and qty > 0 then
				local before = data.Bag[id] or 0
				data.Bag[id] = math.min(Items.StackLimit, before + qty)
				local def = Items.Get(id)
				table.insert(parts, "+" .. qty .. "x " .. (if def then def.Name else id))
			end
		end
	end
	return parts, extraGems, premTicketsGranted
end

-- Adiciona XP da Conta (nunca diminui; pode subir multiplos niveis de uma vez)
function AccountLevelService.AddXp(player: Player, amount: number, reason: string?, allowBoosts: boolean?): (number, number)
	if not player or not player.Parent or typeof(amount) ~= "number" or amount <= 0 then
		return 0, 0
	end
	local data = PlayerDataService.Get(player)
	if not data then
		return 0, 0
	end
	local acc = ensureAccount(data)
	local gain = math.floor(amount)
	if allowBoosts then
		if Benefits.Has(data, "XpEmDobro") then
			gain *= 2
		end
		local evMult = Retention.XpMultiplier(Clock.Now())
		if evMult > 1 then
			gain = math.floor(gain * evMult)
		end
	end
	if gain <= 0 then
		return 0, 0
	end

	local oldLevel = acc.Level
	acc.Xp += gain
	acc.TotalXp += gain

	local safety = 0
	while safety < 50 do
		local needed = AccountLevel.XpToNext(acc.Level)
		if acc.Xp >= needed then
			acc.Xp -= needed
			acc.Level += 1
			safety += 1
		else
			break
		end
	end

	local levelsGained = acc.Level - oldLevel
	PlayerDataService.MarkChanged(player)
	if levelsGained > 0 then
		task.spawn(PlayerDataService.SaveNow, player)
		pcall(function()
			NotifyRE:FireClient(
				player,
				string.format("N\u{ed}vel da Conta subiu para %d! Resgate sua recompensa na \u{c1}rvore perto da Torre!", acc.Level)
			)
		end)
	end

	pcall(function()
		AccountXpGainRE:FireClient(player, {
			Amount = gain,
			Reason = reason or "",
			Level = acc.Level,
			Xp = acc.Xp,
			Needed = AccountLevel.XpToNext(acc.Level),
			LeveledUp = levelsGained > 0,
			LevelsGained = levelsGained,
			Unclaimed = AccountLevel.CountUnclaimed(acc),
		})
	end)

	return gain, levelsGained
end

function AccountLevelService.Claim(player: Player, levelArg: any): (boolean, string)
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Perfil ainda carregando."
	end
	local now = os.clock()
	if lastClaim[player] and now - lastClaim[player] < 0.25 then
		return false, "Aguarde um instante."
	end
	lastClaim[player] = now

	local acc = ensureAccount(data)

	if levelArg == "All" then
		local claimedCount = 0
		local skippedBag = 0
		local totalGold, totalGems, totalComum, totalPrem, totalItems = 0, 0, 0, 0, 0
		for lv = 1, acc.Level do
			if not AccountLevel.IsClaimed(acc, lv) then
				local r = AccountLevel.RewardFor(lv)
				if canFitItems(data, r.Items) then
					acc.Claimed[tostring(lv)] = true
					local _, extraGems, premGranted = grantReward(player, data, r)
					claimedCount += 1
					totalGold += r.Gold or 0
					totalGems += (r.Gems or 0) + extraGems
					if r.Tickets then
						totalComum += r.Tickets.Comum or 0
						totalPrem += premGranted
					end
					if r.Items then
						for _, q in pairs(r.Items) do
							totalItems += q
						end
					end
				else
					skippedBag += 1
				end
			end
		end
		if claimedCount == 0 then
			if skippedBag > 0 then
				return false, "Mochila cheia! Libere espa\u{e7}o para resgatar os itens."
			end
			return false, "Nenhuma recompensa dispon\u{ed}vel no momento."
		end
		PlayerDataService.MarkChanged(player)
		task.spawn(PlayerDataService.SaveNow, player)
		local summary = {}
		if totalGold > 0 then table.insert(summary, "+" .. totalGold .. " gold") end
		if totalGems > 0 then table.insert(summary, "+" .. totalGems .. " gemas") end
		if totalComum > 0 then table.insert(summary, "+" .. totalComum .. " inv. Comum") end
		if totalPrem > 0 then table.insert(summary, "+" .. totalPrem .. " inv. Premium") end
		if totalItems > 0 then table.insert(summary, "+" .. totalItems .. " itens") end
		local msg = string.format("Resgatou %d recompensa%s: %s!", claimedCount, if claimedCount > 1 then "s" else "", table.concat(summary, ", "))
		if skippedBag > 0 then
			msg ..= " (" .. skippedBag .. " aguardando espa\u{e7}o na mochila)"
		end
		return true, msg
	end

	local lv = tonumber(levelArg)
	if not lv or lv ~= lv or lv < 1 or lv ~= math.floor(lv) then
		return false, "N\u{ed}vel inv\u{e1}lido."
	end
	if lv > acc.Level then
		return false, "Alcance o N\u{ed}vel " .. lv .. " para desbloquear esta recompensa."
	end
	if AccountLevel.IsClaimed(acc, lv) then
		return false, "Recompensa do N\u{ed}vel " .. lv .. " j\u{e1} foi resgatada."
	end

	local r = AccountLevel.RewardFor(lv)
	if not canFitItems(data, r.Items) then
		return false, "Mochila cheia! Libere espa\u{e7}o antes de resgatar."
	end

	acc.Claimed[tostring(lv)] = true
	local parts = grantReward(player, data, r)
	PlayerDataService.MarkChanged(player)
	task.spawn(PlayerDataService.SaveNow, player)
	return true, "N\u{ed}vel " .. lv .. " resgatado: " .. table.concat(parts, ", ") .. "!"
end

function AccountLevelService.Init()
	ClaimLevelRewardRF.OnServerInvoke = function(player, levelArg)
		return AccountLevelService.Claim(player, levelArg)
	end
	Players.PlayerRemoving:Connect(function(p)
		lastClaim[p] = nil
	end)
end

return AccountLevelService
