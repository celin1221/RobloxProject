--[[
	RetentionService (GDD secao 13 - mecanicas de retorno)
	- Login diario de 7 dias (botao; reinicia se pular um dia).
	- Baus por tempo online no dia: 5, 15, 30 e 60 minutos (cada um 1 vez por dia).
	- 3 missoes diarias (sorteadas por dia) e 5 semanais; recompensa entregue ao completar.
	- Temporada mensal do Infinito: placar por mes; na virada, gemas por faixa e aparencia para os 100 primeiros.
	- Fim de semana 2x gold ou 2x XP (Data/Retention.EventAt; aplicado na torre, na base e no XP).
	- Codigos (ServerStorage/Codes), 1 vez por jogador, com limite de tentativas.
	Tudo no servidor; o cliente so pede pelo remote Rewards. Relogio: Data/Clock (adiantavel so no Studio).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")

local Data = ReplicatedStorage:WaitForChild("Data")
local Retention = require(Data:WaitForChild("Retention"))
local StarterTrack = require(Data:WaitForChild("StarterTrack"))
local Items = require(Data.Items)
local Benefits = require(Data.Benefits)
local Characters = require(Data.Characters)
local AccountLevel = require(Data:WaitForChild("AccountLevel"))

local PlayerDataService = require(script.Parent.PlayerDataService)
local AccountLevelService = require(script.Parent:WaitForChild("AccountLevelService"))
local ProgressionService = require(script.Parent.ProgressionService)
local Clock = require(script.Parent.Clock)
local Codes = require(ServerStorage:WaitForChild("Codes"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local RetentionService = {}

local TICK = 10 -- segundos entre contagens do tempo online
local TOP_CHECK_EVERY = 60
local CODE_TRIES_PER_MIN = 10

local busy = {}
local codeTries = {} -- [Player] = { Start, Count }
local lastTopCheck = {}
local storeCache = {}

local function notify(player: Player, text: string)
	Remotes.Notify:FireClient(player, text)
end

local function changed(player: Player, save: boolean?)
	PlayerDataService.MarkChanged(player)
	if save then
		task.spawn(PlayerDataService.SaveNow, player)
	end
end

local function premiumBlocked(player: Player): boolean
	return player:GetAttribute("PaidRandomRestricted") ~= false
end

function RetentionService.SeasonStore(id: string, format: string?)
	local key = if format == "2x2" then ("2x2_" .. id) else id
	if not storeCache[key] then
		storeCache[key] = DataStoreService:GetOrderedDataStore(Retention.Season.StorePrefix .. key)
	end
	return storeCache[key]
end

function RetentionService.CurrentSeason(): string
	return Retention.SeasonId(Clock.Now())
end

--------------------------------------------------------------------
-- Recompensas
--------------------------------------------------------------------
local function bagSlots(data)
	return Benefits.BagSlots(data, Items.BagSlots)
end

-- Todos os itens cabem na mochila?
local function itemsFit(data, items): boolean
	local bag = table.clone(data.Bag)
	for id, n in pairs(items or {}) do
		if Items.SpaceFor(bag, id, bagSlots(data)) < n then
			return false
		end
		bag[id] = (bag[id] or 0) + n
	end
	return true
end

-- Entrega uma recompensa { Gold, Gems, Items, Tickets, Xp } e devolve as linhas do que veio
local function grant(player: Player, data, reward): { string }
	local lines = {}
	if reward.Gold and reward.Gold > 0 then
		data.Gold += reward.Gold
		table.insert(lines, "+" .. reward.Gold .. " gold")
	end
	if reward.Gems and reward.Gems > 0 then
		data.Gems += reward.Gems
		table.insert(lines, "+" .. reward.Gems .. " gemas")
	end
	for id, n in pairs(reward.Items or {}) do
		local item = Items.Get(id)
		if item then
			local give = math.min(n, Items.SpaceFor(data.Bag, id, bagSlots(data)))
			if give > 0 then
				data.Bag[id] = (data.Bag[id] or 0) + give
				table.insert(lines, "+" .. give .. "x " .. item.Name)
			end
			if give < n then
				table.insert(lines, "mochila cheia: " .. (n - give) .. "x " .. item.Name .. " ficou de fora")
			end
		end
	end
	for kind, n in pairs(reward.Tickets or {}) do
		if kind == "Premium" and premiumBlocked(player) then
			-- Portal Premium bloqueado na regiao (PolicyService): vale o preco em gemas
			local gems = n * Retention.PremiumTicketGems
			data.Gems += gems
			table.insert(lines, "+" .. gems .. " gemas (no lugar da invoca\u{e7}\u{e3}o Premium)")
		else
			data.Tickets[kind] = (data.Tickets[kind] or 0) + n
			table.insert(lines, "+" .. n .. " invoca\u{e7}\u{e3}o " .. (if kind == "Premium" then "Premium" else "Comum") .. " gr\u{e1}tis")
		end
	end
	if reward.Xp and reward.Xp > 0 then
		local any = false
		for _, uid in ipairs(data.Team) do
			if data.Collection[uid] then
				ProgressionService.AddXp(player, uid, reward.Xp)
				any = true
			end
		end
		if any then
			table.insert(lines, "+" .. reward.Xp .. " XP para o time")
		end
	end
	local charList = {}
	if reward.Character then
		table.insert(charList, reward.Character)
	end
	for _, cid in ipairs(reward.Characters or {}) do
		table.insert(charList, cid)
	end
	for _, cid in ipairs(charList) do
		local def = Characters.Get(cid)
		if def then
			local lvl = reward.Level or def.BaseLevel or 10
			local toTeam = #data.Team < 3
			ProgressionService.AddCharacter(player, cid, lvl, toTeam, reward.Variant, nil, { Source = "Reward", Silent = #charList > 6 })
			table.insert(lines, "+1 " .. def.Name .. " (Nv. " .. lvl .. ")")
		end
	end
	return lines
end
RetentionService._grant = grant

--------------------------------------------------------------------
-- Dia e semana: missoes e baus
--------------------------------------------------------------------
local function refresh(player: Player, data, t: number): boolean
	local changedAny = false
	local day = Retention.Day(t)
	local m = data.Missions
	if m.Day ~= day then
		m.Day = day
		m.AllDone = false
		m.Daily = {}
		for _, id in ipairs(Retention.DailyIds(day, player.UserId)) do
			table.insert(m.Daily, { Id = id, Progress = 0, Done = false })
		end
		changedAny = true
	else
		-- missao do dia que saiu do sorteio (ex.: captura desativada): troca por outra do sorteio
		for _, e in ipairs(m.Daily) do
			if not Retention.Daily.Pool[e.Id] then
				local used = {}
				for _, x in ipairs(m.Daily) do
					used[x.Id] = true
				end
				local free = {}
				for id in pairs(Retention.Daily.Pool) do
					if not used[id] then
						table.insert(free, id)
					end
				end
				table.sort(free)
				if free[1] then
					e.Id, e.Progress, e.Done = free[1], 0, false
					changedAny = true
				end
			end
		end
	end
	local week = Retention.Week(t)
	if m.Week ~= week then
		m.Week = week
		m.WeeklyDone = false
		m.Weekly = {}
		for _, w in ipairs(Retention.Weekly.List) do
			m.Weekly[w.Id] = { Progress = 0, Done = false }
		end
		changedAny = true
	else
		-- semanal nova na lista (ex.: Collect10 no lugar da captura): entra zerada
		for _, w in ipairs(Retention.Weekly.List) do
			if not m.Weekly[w.Id] then
				m.Weekly[w.Id] = { Progress = 0, Done = false }
				changedAny = true
			end
		end
	end
	local s = data.Session
	if s.Day ~= day then
		s.Day = day
		s.Seconds = 0
		s.Claimed = {}
		changedAny = true
	end
	return changedAny
end

-- Temporada: na virada do mes paga a faixa de gemas e marca a conferencia do top 100
local function ensureSeason(player: Player, data): boolean
	local cur = Retention.SeasonId(Clock.Now())
	local changedAny = false
	local s = data.Season
	if s.Id ~= cur then
		if s.Id ~= "" and (s.Best or 0) > 0 then
			local gems = Retention.SeasonGems(s.Best)
			data.Gems += gems
			s.Last = { Id = s.Id, Best = s.Best, Gems = gems }
			s.PendingTop = s.Id
			notify(player, string.format("Temporada 1x1 %s encerrada: andar %d, +%d gemas.", s.Id, s.Best, gems))
		end
		s.Id = cur
		s.Best = 0
		changedAny = true
	end
	data.Season2x2 = data.Season2x2 or { Id = "", Best = 0 }
	local s2 = data.Season2x2
	if s2.Id ~= cur then
		if s2.Id ~= "" and (s2.Best or 0) > 0 then
			local gems2 = Retention.SeasonGems(s2.Best)
			data.Gems += gems2
			s2.Last = { Id = s2.Id, Best = s2.Best, Gems = gems2 }
			notify(player, string.format("Temporada 2x2 %s encerrada: andar %d, +%d gemas.", s2.Id, s2.Best, gems2))
		end
		s2.Id = cur
		s2.Best = 0
		changedAny = true
	end
	return changedAny
end

local function applyCosmetics(player: Player, data)
	local top = data.Cosmetics.InfinitoTop
	player:SetAttribute("SeasonTop", if top then top.Season else nil)
end

-- Confere no placar da temporada encerrada se o jogador ficou entre os 100 primeiros
local function checkTop(player: Player, data): boolean
	local s = data.Season
	local id = s.PendingTop
	if not id then
		return false
	end
	if lastTopCheck[player] and os.clock() - lastTopCheck[player] < TOP_CHECK_EVERY then
		return false
	end
	lastTopCheck[player] = os.clock()
	local store = RetentionService.SeasonStore(id)
	local ok, pages = pcall(store.GetSortedAsync, store, false, Retention.Season.TopCount)
	if not ok then
		warn("[Retention] Placar da temporada indispon\u{ed}vel: " .. tostring(pages))
		return false -- tenta de novo depois
	end
	local rank
	for i, entry in ipairs(pages:GetCurrentPage()) do
		if tonumber(entry.key) == player.UserId then
			rank = i
			break
		end
	end
	s.PendingTop = nil
	if s.Last and s.Last.Id == id then
		s.Last.Rank = rank
	end
	if rank then
		data.Cosmetics.InfinitoTop = { Season = id, Rank = rank }
		applyCosmetics(player, data)
		notify(player, string.format("Voc\u{ea} ficou em %d\u{ba} na temporada %s: apar\u{ea}ncia %s liberada!", rank, id, Retention.Season.TopTag))
	end
	return true
end

-- Andar do Infinito vencido (TowerService). format = "1x1" (padrao) ou "2x2". Retorna true se for recorde da temporada.
function RetentionService.OnInfiniteFloor(player: Player, floor: number, format: string?): boolean
	local data = PlayerDataService.Get(player)
	if not data then
		return false
	end
	ensureSeason(player, data)
	local fmt = if format == "2x2" then "2x2" else "1x1"
	local s = if fmt == "2x2" then data.Season2x2 else data.Season
	if floor <= (s.Best or 0) then
		return false
	end
	s.Best = floor
	local store = RetentionService.SeasonStore(s.Id, fmt)
	task.spawn(function()
		local ok, err = pcall(store.UpdateAsync, store, tostring(player.UserId), function(old)
			if typeof(old) == "number" and old >= floor then
				return nil
			end
			return floor
		end)
		if not ok then
			warn("[Retention] Falha ao enviar ao placar da temporada (" .. fmt .. "): " .. tostring(err))
		end
	end)
	return true
end

--------------------------------------------------------------------
-- Login diario
--------------------------------------------------------------------
function RetentionService.ClaimLogin(player: Player)
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Dados ainda carregando."
	end
	local today = Retention.Day(Clock.Now())
	local L = data.DailyLogin
	if L.LastDay == today then
		return false, "Recompensa de hoje j\u{e1} recebida. Volte amanh\u{e3}."
	end
	local streak = if L.LastDay == today - 1 and L.Streak < #Retention.Login then L.Streak + 1 else 1
	L.LastDay = today
	L.Streak = streak
	local lines = grant(player, data, Retention.Login[streak])
	changed(player, true)
	return true, "Login dia " .. streak .. ": " .. table.concat(lines, ", ") .. "."
end

--------------------------------------------------------------------
-- Baus por tempo online
--------------------------------------------------------------------
function RetentionService.ClaimChest(player: Player, index)
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Dados ainda carregando."
	end
	if typeof(index) ~= "number" or index % 1 ~= 0 or not Retention.Chests[index] then
		return false, "Ba\u{fa} inv\u{e1}lido."
	end
	if refresh(player, data, Clock.Now()) then
		changed(player)
	end
	local chest = Retention.Chests[index]
	local s = data.Session
	local key = "c" .. index
	if s.Claimed[key] then
		return false, "Ba\u{fa} j\u{e1} aberto hoje."
	end
	local need = chest.Minutes * 60 - s.Seconds
	if need > 0 then
		return false, "Faltam " .. math.ceil(need / 60) .. " min de jogo hoje."
	end
	if not itemsFit(data, chest.Items) then
		return false, "Mochila sem espa\u{e7}o para os itens do ba\u{fa}."
	end
	s.Claimed[key] = true
	local lines = grant(player, data, chest)
	changed(player, true)
	return true, "Ba\u{fa} de " .. chest.Minutes .. " min: " .. table.concat(lines, ", ") .. "."
end

-- So para testes: soma tempo online
function RetentionService.AddPlaytime(player: Player, seconds: number)
	local data = PlayerDataService.Get(player)
	refresh(player, data, Clock.Now())
	data.Session.Seconds += seconds
	changed(player)
	return data.Session.Seconds
end

--------------------------------------------------------------------
-- Missoes
--------------------------------------------------------------------
function RetentionService.Track(player: Player, event: string, amount: number?)
	local data = PlayerDataService.Get(player)
	if not data then
		return
	end
	amount = amount or 1
	refresh(player, data, Clock.Now())
	local m = data.Missions
	local any, rewarded = false, false
	local dailyDone = 0
	for _, e in ipairs(m.Daily) do
		local def = Retention.Daily.Pool[e.Id]
		if def and def.Event == event and not e.Done then
			e.Progress = math.min(def.Goal, e.Progress + amount)
			any = true
			if e.Progress >= def.Goal then
				e.Done = true
				rewarded = true
				dailyDone += 1
				local lines = grant(player, data, Retention.Daily.Reward)
				AccountLevelService.AddXp(player, AccountLevel.XpSources.DailyMission, "Miss\u{e3}o Di\u{e1}ria", false)
				notify(player, "Miss\u{e3}o di\u{e1}ria: " .. string.format(def.Text, def.Goal) .. "! " .. table.concat(lines, ", "))
			end
		end
	end
	if not m.AllDone and #m.Daily > 0 then
		local all = true
		for _, e in ipairs(m.Daily) do
			all = all and e.Done
		end
		if all then
			m.AllDone = true
			local lines = grant(player, data, Retention.Daily.AllReward)
			AccountLevelService.AddXp(player, AccountLevel.XpSources.AllDailyBonus, "Todas Di\u{e1}rias", false)
			task.delay(1.5, notify, player, "As 3 miss\u{f5}es di\u{e1}rias conclu\u{ed}das! " .. table.concat(lines, ", "))
		end
	end
	for _, w in ipairs(Retention.Weekly.List) do
		local e = m.Weekly[w.Id]
		if e and w.Event == event and not e.Done then
			e.Progress = math.min(w.Goal, e.Progress + amount)
			any = true
			if e.Progress >= w.Goal then
				e.Done = true
				rewarded = true
				AccountLevelService.AddXp(player, AccountLevel.XpSources.WeeklyMission, "Miss\u{e3}o Semanal", false)
				task.delay(0.8, notify, player, "Miss\u{e3}o semanal conclu\u{ed}da: " .. string.format(w.Text, w.Goal) .. "!")
			end
		end
	end
	if not m.WeeklyDone then
		local all = true
		for _, w in ipairs(Retention.Weekly.List) do
			all = all and (m.Weekly[w.Id] and m.Weekly[w.Id].Done)
		end
		if all then
			m.WeeklyDone = true
			local lines = grant(player, data, Retention.Weekly.AllReward)
			AccountLevelService.AddXp(player, AccountLevel.XpSources.AllWeeklyBonus, "Todas Semanais", false)
			task.delay(2.5, notify, player, "As 5 miss\u{f5}es semanais conclu\u{ed}das! " .. table.concat(lines, ", "))
		end
	end
	if dailyDone > 0 then
		RetentionService.Track(player, "DailyDone", dailyDone)
	end
	if any then
		changed(player, rewarded)
	end
end

--------------------------------------------------------------------
-- Codigos
--------------------------------------------------------------------
function RetentionService.Redeem(player: Player, text)
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Dados ainda carregando."
	end
	if typeof(text) ~= "string" or #text == 0 or #text > 30 then
		return false, "Digite um c\u{f3}digo."
	end
	local tries = codeTries[player]
	if not tries or os.clock() - tries.Start > 60 then
		tries = { Start = os.clock(), Count = 0 }
		codeTries[player] = tries
	end
	if tries.Count >= CODE_TRIES_PER_MIN then
		return false, "Muitas tentativas. Espere um minuto."
	end
	tries.Count += 1
	local key = string.upper((text:gsub("%s", "")))
	local def = Codes[key]
	if typeof(def) ~= "table" then
		return false, "C\u{f3}digo inv\u{e1}lido."
	end
	if def.Expires and Clock.Now() > def.Expires then
		return false, "Este c\u{f3}digo expirou."
	end
	if data.Codes[key] and not def.Repeatable then
		return false, "Voc\u{ea} j\u{e1} usou este c\u{f3}digo."
	end
	if not itemsFit(data, def.Items) then
		return false, "Mochila sem espa\u{e7}o para os itens do c\u{f3}digo."
	end
	data.Codes[key] = Clock.Now()
	local lines = grant(player, data, def)
	changed(player, true)
	return true, "C\u{f3}digo " .. key .. ": " .. table.concat(lines, ", ") .. "."
end

-- Resgate de um passo da Trilha Inicial (valida progresso no servidor)
function RetentionService.ClaimStarterStep(player: Player, stepId)
	local data = PlayerDataService.Get(player)
	if not data or not data.StarterChosen then
		return false, "Escolha seu personagem inicial primeiro."
	end
	if typeof(stepId) ~= "string" then
		return false, "Objetivo inv\u{e1}lido."
	end
	local step = StarterTrack.ById[stepId]
	if not step then
		return false, "Objetivo inv\u{e1}lido."
	end
	data.StarterTrack = data.StarterTrack or { Claimed = {} }
	data.StarterTrack.Claimed = data.StarterTrack.Claimed or {}
	if data.StarterTrack.Claimed[stepId] then
		return false, "Objetivo j\u{e1} resgatado."
	end
	local _, _, done = StarterTrack.Progress(data, stepId)
	if not done then
		return false, "Objetivo ainda n\u{e3}o conclu\u{ed}do."
	end
	if step.Reward and step.Reward.Items and not itemsFit(data, step.Reward.Items) then
		return false, "Mochila cheia: libere espa\u{e7}o antes de resgatar."
	end
	data.StarterTrack.Claimed[stepId] = true
	local lines = grant(player, data, step.Reward or {})
	AccountLevelService.AddXp(player, AccountLevel.XpSources.StarterStep, "Trilha Inicial", false)
	changed(player, true)
	return true, step.Title .. ": " .. table.concat(lines, ", ") .. "!"
end

--------------------------------------------------------------------
-- Init
--------------------------------------------------------------------
local function prepare(player: Player)
	local data = PlayerDataService.Get(player)
	if not data then
		return
	end
	local a = refresh(player, data, Clock.Now())
	local b = ensureSeason(player, data)
	applyCosmetics(player, data)
	if a or b then
		changed(player, b)
	end
	task.spawn(function()
		if checkTop(player, data) then
			changed(player, true)
		end
	end)
end
RetentionService.Prepare = prepare

function RetentionService.Init()
	local remote = Remotes:WaitForChild("Rewards")
	remote.OnServerInvoke = function(player, action, arg)
		if busy[player] then
			return false, "Aguarde."
		end
		busy[player] = true
		local ok, a, b = pcall(function()
			if action == "Login" then
				return RetentionService.ClaimLogin(player)
			elseif action == "Chest" then
				return RetentionService.ClaimChest(player, arg)
			elseif action == "Code" then
				return RetentionService.Redeem(player, arg)
			elseif action == "StarterStep" then
				return RetentionService.ClaimStarterStep(player, arg)
			end
			return false, "A\u{e7}\u{e3}o inv\u{e1}lida."
		end)
		busy[player] = nil
		if not ok then
			warn("[Retention] " .. tostring(a))
			return false, "Erro no servidor."
		end
		return a, b
	end

	PlayerDataService.Loaded:Connect(function(player)
		prepare(player)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(prepare, p)
	end

	-- Batalhas: vitorias, torre e captura contam nas missoes
	table.insert(ProgressionService.Listeners, function(player, battle, result)
		if result ~= "Win" then
			return
		end
		RetentionService.Track(player, "Win", 1)
		if battle.Mode == "Tower" then
			RetentionService.Track(player, "TowerWin", 1)
		end
		if battle.EndReason == "Captured" then
			RetentionService.Track(player, "Capture", 1)
		end
	end)

	-- Tempo online, virada de dia/semana/mes e conferencia do top 100
	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = PlayerDataService.Get(player)
				if data then
					local t = Clock.Now()
					local dirty = refresh(player, data, t)
					local season = ensureSeason(player, data)
					local s = data.Session
					local before = s.Seconds
					s.Seconds += TICK
					for _, chest in ipairs(Retention.Chests) do
						local at = chest.Minutes * 60
						if before < at and s.Seconds >= at then
							notify(player, "Ba\u{fa} de " .. chest.Minutes .. " min pronto! Abra em Pr\u{ea}mios.")
							dirty = true
						end
					end
					if data.Season.PendingTop then
						task.spawn(function()
							if checkTop(player, data) then
								changed(player, true)
							end
						end)
					end
					if dirty or season then
						changed(player, season)
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
		codeTries[player] = nil
		lastTopCheck[player] = nil
	end)
end

-- So para testes (ponte do Studio)
RetentionService._checkTop = function(player)
	lastTopCheck[player] = nil
	return checkTop(player, PlayerDataService.Get(player))
end

return RetentionService
