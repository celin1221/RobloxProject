--[[
	PvPService (GDD secao 5 - PvP 1x1 e 2x2 com Ranking ELO, Patentes e Recompensa Diaria Anti-Farm)
	- Desafio por proximidade na praca: o cliente mostra "Desafiar" perto de outro jogador;
	  o servidor confere praca, distancia, batalha, torre e time.
	- Times: o time salvo de cada um, todos no nivel 50, HP/PP cheios e sem status (copias: o perfil nao muda).
	- Fim do duelo: atualiza ELO e Patente (2x2 vale K=32; 1x1 vale K=24), paga bonus diario em Gold/Doce
	  (ate 3 vitorias/dia, com trava anti-farm de 1 partida premiada/ranqueada por oponente ao dia)
	  e registra no placar global PvPRank_v1.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")

local Data = ReplicatedStorage:WaitForChild("Data")
local Progression = require(Data.Progression)
local Genetics = require(Data:WaitForChild("Genetics"))
local PvPRank = require(Data:WaitForChild("PvPRank"))
local Items = require(Data.Items)
local Benefits = require(Data.Benefits)

local BattleService = require(script.Parent.BattleService)
local Config = require(script.Parent.BattleConfig)
local PlayerDataService = require(ServerScriptService:WaitForChild("Data"):WaitForChild("PlayerDataService"))
local Clock = require(ServerScriptService.Data:WaitForChild("Clock"))
local TowerService = require(ServerScriptService:WaitForChild("Tower"):WaitForChild("TowerService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PvPService = {}

local invites = {} -- [desafiado] = { From = Player, Format = string, Expires = os.clock() }
local sent = {} -- [quem desafiou] = desafiado
local lastCall = {}
local globalCache = { Time = -math.huge, List = {} }
local nameCache = {}
local GLOBAL_CACHE_TIME = 60

local rankStore = nil
local function getRankStore()
	if not rankStore then
		rankStore = DataStoreService:GetOrderedDataStore(PvPRank.StoreName)
	end
	return rankStore
end

local function notify(player: Player, text: string)
	if player and player.Parent then
		Remotes.Notify:FireClient(player, text)
	end
end

local function ensurePvP(data, day: number)
	if typeof(data.PvP) ~= "table" then
		data.PvP = PvPRank.DefaultState()
	end
	local p = data.PvP
	if typeof(p.Rating) ~= "number" then
		p.Rating = PvPRank.StartRating
	end
	if typeof(p.BestRating) ~= "number" then
		p.BestRating = p.Rating
	end
	if p.DailyDay ~= day then
		p.DailyDay = day
		p.DailyRewards = 0
		p.OpponentsToday = {}
	elseif typeof(p.OpponentsToday) ~= "table" then
		p.OpponentsToday = {}
	end
	return p
end

local function addBagItem(data, itemId: string, qty: number): boolean
	if not Items.Get(itemId) then
		return false
	end
	local slots = Benefits.BagSlots(data, Items.BagSlots)
	local space = Items.SpaceFor(data.Bag, itemId, slots)
	if space < qty then
		return false
	end
	data.Bag[itemId] = (data.Bag[itemId] or 0) + qty
	return true
end

local function nameOf(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local p = Players:GetPlayerByUserId(userId)
	local name = p and p.Name
	if not name then
		local ok, n = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		name = ok and n or ("Jogador " .. userId)
	end
	nameCache[userId] = name
	return name
end

local function recordPvPResult(winner: Player?, loser: Player?, fmt: string, reason: string?)
	if not winner or not loser then
		return
	end
	local wData = PlayerDataService.Get(winner)
	local lData = PlayerDataService.Get(loser)
	if not wData or not lData then
		return
	end
	local day = PvPRank.Day(Clock.Now())
	local wp = ensurePvP(wData, day)
	local lp = ensurePvP(lData, day)

	local wKey = tostring(loser.UserId)
	local lKey = tostring(winner.UserId)
	local alreadyFought = wp.OpponentsToday[wKey] == true or lp.OpponentsToday[lKey] == true

	if alreadyFought then
		notify(winner, string.format("Vit\u{f3}ria amistosa PvP %s! (ELO/b\u{f4}nus contra %s j\u{e1} contaram hoje.)", fmt, loser.DisplayName))
		notify(loser, string.format("Duelo amistoso PvP %s contra %s encerrado.", fmt, winner.DisplayName))
		return
	end

	wp.OpponentsToday[wKey] = true
	lp.OpponentsToday[lKey] = true

	local gain, loss = PvPRank.Delta(wp.Rating, lp.Rating, fmt)
	wp.Rating = math.clamp(wp.Rating + gain, PvPRank.MinRating, PvPRank.MaxRating)
	wp.BestRating = math.max(wp.BestRating, wp.Rating)
	wp.Wins = (wp.Wins or 0) + 1
	if fmt == "2x2" then
		wp.Wins2x2 = (wp.Wins2x2 or 0) + 1
	end

	lp.Rating = math.clamp(lp.Rating - loss, PvPRank.MinRating, PvPRank.MaxRating)
	lp.Losses = (lp.Losses or 0) + 1
	if fmt == "2x2" then
		lp.Losses2x2 = (lp.Losses2x2 or 0) + 1
	end

	-- Recompensa diaria (Gold + Doce no 2x2; gemas continuam raras!)
	local winBonusText = ""
	if (wp.DailyRewards or 0) < PvPRank.DailyRewardCap then
		wp.DailyRewards = (wp.DailyRewards or 0) + 1
		local rw = PvPRank.WinReward[fmt] or PvPRank.WinReward["1x1"]
		local parts = {}
		if rw.Gold and rw.Gold > 0 then
			wData.Gold += rw.Gold
			table.insert(parts, "+" .. rw.Gold .. " gold")
		end
		if rw.Item and addBagItem(wData, rw.Item, 1) then
			local itemDef = Items.Get(rw.Item)
			table.insert(parts, "+1 " .. (itemDef and itemDef.Name or rw.Item))
		end
		winBonusText = string.format(" \u{b7} %s (%d/%d hoje)", table.concat(parts, " "), wp.DailyRewards, PvPRank.DailyRewardCap)
	end

	local loseBonusText = ""
	if reason ~= "Disconnected" and (lp.DailyRewards or 0) < PvPRank.DailyRewardCap then
		lData.Gold += PvPRank.ParticipationGold
		loseBonusText = string.format(" \u{b7} +%d gold (participa\u{e7}\u{e3}o)", PvPRank.ParticipationGold)
	end

	local wTier = PvPRank.TierFor(wp.Rating)
	local lTier = PvPRank.TierFor(lp.Rating)
	notify(winner, string.format("Vit\u{f3}ria PvP %s! +%d ELO (%s \u{b7} %d)%s", fmt, gain, wTier.Name, wp.Rating, winBonusText))
	notify(loser, string.format("Derrota PvP %s: -%d ELO (%s \u{b7} %d)%s", fmt, loss, lTier.Name, lp.Rating, loseBonusText))

	PlayerDataService.MarkChanged(winner)
	PlayerDataService.MarkChanged(loser)
	task.spawn(PlayerDataService.SaveNow, winner)
	task.spawn(PlayerDataService.SaveNow, loser)

	-- Atualiza placar global assincronamente
	globalCache.Time = -math.huge
	task.spawn(function()
		local store = getRankStore()
		pcall(store.SetAsync, store, tostring(winner.UserId), wp.Rating)
		pcall(store.SetAsync, store, tostring(loser.UserId), lp.Rating)
	end)
end

function PvPService.GetLeaderboard(player: Player)
	-- Servidor
	local serverList = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local d = PlayerDataService.Get(p)
		if d then
			local pvp = ensurePvP(d, PvPRank.Day(Clock.Now()))
			table.insert(serverList, {
				Name = p.Name,
				Rating = pvp.Rating,
				Tier = PvPRank.TierFor(pvp.Rating).Name,
				Wins2x2 = pvp.Wins2x2 or 0,
			})
		end
	end
	table.sort(serverList, function(a, b)
		return a.Rating > b.Rating
	end)
	while #serverList > PvPRank.LeaderboardSize do
		table.remove(serverList)
	end

	-- Global (cache 60s)
	if os.clock() - globalCache.Time >= GLOBAL_CACHE_TIME then
		globalCache.Time = os.clock()
		local ok, pages = pcall(function()
			return getRankStore():GetSortedAsync(false, PvPRank.LeaderboardSize)
		end)
		if ok and pages then
			local list = {}
			for _, entry in ipairs(pages:GetCurrentPage()) do
				local uid = tonumber(entry.key)
				if uid then
					local rating = tonumber(entry.value) or PvPRank.StartRating
					table.insert(list, {
						Name = nameOf(uid),
						Rating = rating,
						Tier = PvPRank.TierFor(rating).Name,
					})
				end
			end
			globalCache.List = list
		end
	end

	local meData = PlayerDataService.Get(player)
	local mePvP = meData and ensurePvP(meData, PvPRank.Day(Clock.Now())) or PvPRank.DefaultState()
	return {
		Format = "PvP",
		Server = serverList,
		Global = globalCache.List,
		MyPvP = {
			Rating = mePvP.Rating,
			BestRating = mePvP.BestRating,
			Tier = PvPRank.TierFor(mePvP.Rating).Name,
			Wins = mePvP.Wins or 0,
			Losses = mePvP.Losses or 0,
			Wins2x2 = mePvP.Wins2x2 or 0,
			DailyRewards = mePvP.DailyRewards or 0,
			DailyCap = PvPRank.DailyRewardCap,
		},
	}
end

local function rootOf(player: Player): BasePart?
	local ch = player.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return nil
	end
	return ch:FindFirstChild("HumanoidRootPart")
end

local function inPlaza(player: Player): boolean
	local root = rootOf(player)
	if not root then
		return false
	end
	-- mapa v2: praca = retangulo dentro da esteira
	local p = root.Position
	return math.abs(p.X) <= Config.PlazaHalfX and math.abs(p.Z) <= Config.PlazaHalfZ and p.Y > -20 and p.Y < 60
end

-- Time do PvP: time salvo, nivel 50, cheio
function PvPService.TeamFor(player: Player)
	local data = PlayerDataService.Get(player)
	if not data or not data.StarterChosen or #data.Team == 0 then
		return nil
	end
	local team = {}
	for _, uid in ipairs(data.Team) do
		local m = data.Collection[uid]
		if m then
			table.insert(team, {
				CharacterId = m.CharacterId,
				Level = Config.PvPLevel,
				Moves = table.clone(m.Active),
				StatMultiplier = Progression.MemberMultiplier(m), -- estrelas e variante continuam
				StatMultipliers = Genetics.MultipliersFor(m.Genetics, m.Training),
				Genetics = m.Genetics,
				Training = m.Training,
			})
		end
	end
	return if #team > 0 then team else nil
end

-- Motivo para nao poder entrar em PvP (nil = pode)
local function blocker(player: Player, who: string, format: string?): string?
	if not player.Parent then
		return who .. " saiu do jogo."
	end
	if BattleService.IsInBattle(player) or TowerService.IsRunning(player) then
		return who .. " est\u{e1} em batalha."
	end
	if not inPlaza(player) then
		return who .. " precisa estar na pra\u{e7}a."
	end
	local team = PvPService.TeamFor(player)
	if not team then
		return who .. " ainda n\u{e3}o tem time."
	end
	if format == "2x2" and #team < 2 then
		return who .. " precisa de pelo menos 2 personagens no time para PvP 2x2."
	end
	return nil
end

local function clearInvite(target: Player)
	local inv = invites[target]
	if inv then
		invites[target] = nil
		if sent[inv.From] == target then
			sent[inv.From] = nil
		end
	end
end

local function throttled(player: Player): boolean
	local t = os.clock()
	if lastCall[player] and t - lastCall[player] < 0.5 then
		return true
	end
	lastCall[player] = t
	return false
end

function PvPService.Challenge(player: Player, targetUserId, format)
	if throttled(player) then
		return false, "Aguarde."
	end
	local fmt = if format == "2x2" then "2x2" else "1x1"
	local target = typeof(targetUserId) == "number" and Players:GetPlayerByUserId(targetUserId)
	if not target or target == player then
		return false, "Jogador inv\u{e1}lido."
	end
	local why = blocker(player, "Voc\u{ea}", fmt) or blocker(target, target.DisplayName, fmt)
	if why then
		return false, why
	end
	local a, b = rootOf(player), rootOf(target)
	if (a.Position - b.Position).Magnitude > Config.PvPChallengeDistance + 4 then
		return false, "Chegue mais perto de " .. target.DisplayName .. "."
	end
	if invites[target] and os.clock() < invites[target].Expires then
		return false, target.DisplayName .. " j\u{e1} tem um desafio pendente."
	end
	if sent[player] then
		clearInvite(sent[player])
	end
	if invites[player] and invites[player].From == target then
		-- os dois se desafiaram: vale como aceite (no formato combinado)
		return PvPService.Respond(player, target.UserId, true)
	end
	invites[target] = { From = player, Format = fmt, Expires = os.clock() + Config.PvPInviteTime }
	sent[player] = target
	Remotes.PvPInvite:FireClient(target, { Kind = "Incoming", FromUserId = player.UserId, FromName = player.DisplayName, Format = fmt, Seconds = Config.PvPInviteTime })
	Remotes.PvPInvite:FireClient(player, { Kind = "Sent", ToUserId = target.UserId, ToName = target.DisplayName, Format = fmt, Seconds = Config.PvPInviteTime })
	local inv = invites[target]
	task.delay(Config.PvPInviteTime, function()
		if invites[target] == inv then
			clearInvite(target)
			if player.Parent then
				Remotes.PvPInvite:FireClient(player, { Kind = "Closed", Text = target.DisplayName .. " n\u{e3}o respondeu." })
			end
			if target.Parent then
				Remotes.PvPInvite:FireClient(target, { Kind = "Closed" })
			end
		end
	end)
	return true, "Desafio " .. fmt .. " enviado para " .. target.DisplayName .. "."
end

function PvPService.Respond(player: Player, challengerUserId, accept)
	local inv = invites[player]
	if not inv or inv.From.UserId ~= challengerUserId or os.clock() > inv.Expires then
		clearInvite(player)
		return false, "Esse desafio n\u{e3}o vale mais."
	end
	local challenger = inv.From
	local fmt = inv.Format or "1x1"
	clearInvite(player)
	if accept ~= true then
		if challenger.Parent then
			Remotes.PvPInvite:FireClient(challenger, { Kind = "Closed", Text = player.DisplayName .. " recusou o desafio." })
		end
		return true, "Desafio recusado."
	end
	-- aceite dos dois lados: confere tudo de novo
	local why = blocker(challenger, challenger.DisplayName, fmt) or blocker(player, "Voc\u{ea}", fmt)
	if why then
		if challenger.Parent then
			Remotes.PvPInvite:FireClient(challenger, { Kind = "Closed", Text = "PvP cancelado: " .. why })
		end
		return false, why
	end
	local ok, err = BattleService.StartPvP(challenger, player, PvPService.TeamFor(challenger), PvPService.TeamFor(player), function(winnerSide, reason)
		local winner = if winnerSide == "Player" then challenger elseif winnerSide == "Enemy" then player else nil
		local loser = if winner == challenger then player elseif winner == player then challenger else nil
		if winner and loser then
			print("[PvP " .. fmt .. "] " .. challenger.Name .. " x " .. player.Name .. ": venceu " .. winner.Name .. " (" .. tostring(reason) .. ")")
			recordPvPResult(winner, loser, fmt, reason)
		end
	end, { Format = fmt })
	if not ok then
		if challenger.Parent then
			Remotes.PvPInvite:FireClient(challenger, { Kind = "Closed", Text = "PvP cancelado: " .. tostring(err) })
		end
		return false, err
	end
	if challenger.Parent then
		Remotes.PvPInvite:FireClient(challenger, { Kind = "Closed" })
	end
	return true
end

function PvPService.Cancel(player: Player)
	local target = sent[player]
	if not target then
		return false, "Nenhum desafio enviado."
	end
	clearInvite(target)
	if target.Parent then
		Remotes.PvPInvite:FireClient(target, { Kind = "Closed", Text = player.DisplayName .. " cancelou o desafio." })
	end
	return true, "Desafio cancelado."
end

local function guarded(fn)
	return function(player, ...)
		local ok, a, b = pcall(fn, player, ...)
		if not ok then
			warn("[PvP] " .. tostring(a))
			return false, "Erro no servidor."
		end
		return a, b
	end
end

function PvPService.Init()
	Remotes.PvPChallenge.OnServerInvoke = guarded(PvPService.Challenge)
	Remotes.PvPRespond.OnServerInvoke = guarded(PvPService.Respond)
	Remotes.PvPCancel.OnServerInvoke = guarded(PvPService.Cancel)
	Players.PlayerRemoving:Connect(function(player)
		if sent[player] then
			local target = sent[player]
			clearInvite(target)
			if target.Parent then
				Remotes.PvPInvite:FireClient(target, { Kind = "Closed" })
			end
		end
		local inv = invites[player]
		if inv then
			clearInvite(player)
			if inv.From.Parent then
				Remotes.PvPInvite:FireClient(inv.From, { Kind = "Closed", Text = player.DisplayName .. " saiu do jogo." })
			end
		end
		lastCall[player] = nil
	end)
end

return PvPService
