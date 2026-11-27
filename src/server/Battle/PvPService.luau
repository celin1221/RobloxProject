--[[
	PvPService (Filas Competitiva & Casual 1x1/2x2, Matchmaking Hibrido Global/Local,
	ELO Separado, leaderstats Nativo, Temporada Mensal e Quadro 3D na Praca)

	- Competitivo (Ranked2x2 / Ranked1x1):
	    * Nivel 50, BST de colecao normalizado (1.00x), Secreto normalizado para Lendario (170).
	    * Estrelas, Variantes e +10% do Despertar ficam apenas cosmeticos (0% bonus de stats).
	    * Genetica, Treino da Capsula e Passiva Secreta (se Desperto) CONTAM.
	    * Species Clause (sem repetidos) + Limite de Elite (max. 1 Secreto e ate 2 Lendarios).
	    * ELO, Patente e Ranking Global independentes para 1x1 (PvPRank1x1_v1) e 2x2 (PvPRank2x2_v1).
	    * NUNCA pareia com bots na Ranqueada; expande janela de ELO (+-100 -> +-250 -> +-500 -> Global).
	- Casual (Casual2x2 / Casual1x1) e Duelo Amistoso por proximidade na praca:
	    * Poder real nao normalizado ("vale tudo": nivel real, +5% por colecao, Estrelas, Variantes, Despertar).
	    * Sem alteracao de ELO (elimina farm/boost com contas secundarias).
	- Matchmaking Hibrido:
	    * Pareamento instantaneo no mesmo servidor (zero tela de carregamento).
	    * Matchmaking global entre servidores via MemoryStoreService (SortedMap) + TeleportService:ReserveServer.
	- leaderstats nativo do Roblox:
	    * Folder "leaderstats" com IntValue "ELO" (1o filho -> ordenacao automatica decrescente na PlayerList)
	      e StringValue "Patente".
	- Quadro 3D na Praca (Workspace.Map.PvPBoardMonument): atualizado periodicamente com Top 10 Global 2x2 e 1x1.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Data = ReplicatedStorage:WaitForChild("Data")
local Progression = require(Data.Progression)
local Genetics = require(Data:WaitForChild("Genetics"))
local PvPRank = require(Data:WaitForChild("PvPRank"))
local Items = require(Data.Items)
local Benefits = require(Data.Benefits)
local AccountLevel = require(Data:WaitForChild("AccountLevel"))

local BattleService = require(script.Parent.BattleService)
local Config = require(script.Parent.BattleConfig)
local PlayerDataService = require(ServerScriptService:WaitForChild("Data"):WaitForChild("PlayerDataService"))
local AccountLevelService = require(ServerScriptService.Data:WaitForChild("AccountLevelService"))
local Clock = require(ServerScriptService.Data:WaitForChild("Clock"))
local TowerService = require(ServerScriptService:WaitForChild("Tower"):WaitForChild("TowerService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PvPService = {}

local invites = {} -- [desafiado] = { From = Player, Format = string, Expires = os.clock() }
local sent = {} -- [quem desafiou] = desafiado
local lastCall = {}
local nameCache = {}

local GLOBAL_CACHE_TIME = 60
local MATCH_TICK = 1.5
local GLOBAL_QUEUE_TTL = 45
local GLOBAL_FALLBACK_WAIT = 3.0
local RESERVED_ARRIVE_TIMEOUT = 22
local SERVER_ID = if game.JobId ~= "" then game.JobId else HttpService:GenerateGUID(false)

local globalCaches = {
	["1x1"] = { Time = -math.huge, List = {} },
	["2x2"] = { Time = -math.huge, List = {} },
}

local rankStores = {}
local queueMaps = {}
local memoryStoreDisabled = false

local localQueues: { [string]: { any } } = {}
for _, qid in ipairs(PvPRank.QueueOrder) do
	localQueues[qid] = {}
end
local playerQueue: { [Player]: any } = {}
local pendingGlobalMatches: { [string]: any } = {}

--------------------------------------------------------------------
-- Stores e utilitarios
--------------------------------------------------------------------
local function normFormat(fmt: string?): string
	return if fmt == "1x1" then "1x1" else "2x2"
end

local function getRankStore(fmt: string)
	local f = normFormat(fmt)
	if not rankStores[f] then
		local storeName = PvPRank.StoreNames[f] or PvPRank.StoreName
		rankStores[f] = DataStoreService:GetOrderedDataStore(storeName)
	end
	return rankStores[f]
end

local function getQueueMap(queueId: string)
	if memoryStoreDisabled or RunService:IsStudio() then
		return nil
	end
	if not queueMaps[queueId] then
		local ok, map = pcall(MemoryStoreService.GetSortedMap, MemoryStoreService, "PvPGlobalQueue_" .. queueId)
		if ok and map then
			queueMaps[queueId] = map
		else
			memoryStoreDisabled = true
			return nil
		end
	end
	return queueMaps[queueId]
end

local function notify(player: Player?, text: string)
	if player and player.Parent then
		Remotes.Notify:FireClient(player, text)
	end
end

local function fireQueueState(player: Player?, payload)
	if not player or not player.Parent then
		return
	end
	local re = Remotes:FindFirstChild("PvPQueueState")
	if re and re:IsA("RemoteEvent") then
		re:FireClient(player, payload)
	end
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

--------------------------------------------------------------------
-- Estado PvP, Temporada Mensal e leaderstats nativo do Roblox
--------------------------------------------------------------------
local function softResetRating(rating: number): number
	local delta = rating - PvPRank.StartRating
	return math.clamp(PvPRank.StartRating + math.floor(delta * 0.5), PvPRank.MinRating, PvPRank.MaxRating)
end

local function ensurePvP(data, now: number?, player: Player?)
	local t = now or Clock.Now()
	local day = PvPRank.Day(t)
	local seasonId = PvPRank.SeasonId(t)

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
	if typeof(p.Mode2x2) ~= "table" then
		p.Mode2x2 = PvPRank.DefaultModeSlot(p.Rating)
		p.Mode2x2.BestRating = math.max(p.Mode2x2.Rating, p.BestRating or p.Rating)
		p.Mode2x2.Wins = tonumber(p.Wins2x2) or 0
		p.Mode2x2.Losses = tonumber(p.Losses2x2) or 0
	end
	if typeof(p.Mode1x1) ~= "table" then
		p.Mode1x1 = PvPRank.DefaultModeSlot(p.Rating)
		p.Mode1x1.BestRating = math.max(p.Mode1x1.Rating, p.BestRating or p.Rating)
		p.Mode1x1.Wins = math.max(0, (tonumber(p.Wins) or 0) - (tonumber(p.Wins2x2) or 0))
		p.Mode1x1.Losses = math.max(0, (tonumber(p.Losses) or 0) - (tonumber(p.Losses2x2) or 0))
	end

	-- Virada da Temporada Mensal Competitiva
	if typeof(p.SeasonId) ~= "string" or p.SeasonId == "" then
		p.SeasonId = seasonId
	elseif p.SeasonId ~= seasonId then
		local prevSeason = p.SeasonId
		local peak = math.max(
			p.Mode1x1.BestRating or PvPRank.StartRating,
			p.Mode2x2.BestRating or PvPRank.StartRating,
			p.Mode1x1.Rating or PvPRank.StartRating,
			p.Mode2x2.Rating or PvPRank.StartRating
		)
		local tier = PvPRank.TierFor(peak)
		local gems = tier.SeasonGems or 0
		if gems > 0 then
			data.Gems = (data.Gems or 0) + gems
		end
		data.Cosmetics = data.Cosmetics or {}
		if tier.Id == "Lenda" then
			data.Cosmetics.PvPLegend = { Season = prevSeason }
		end
		p.LastSeason = {
			Id = prevSeason,
			BestRating = peak,
			Tier = tier.Name,
			Gems = gems,
		}
		p.Mode1x1.Rating = softResetRating(p.Mode1x1.Rating)
		p.Mode1x1.BestRating = p.Mode1x1.Rating
		p.Mode2x2.Rating = softResetRating(p.Mode2x2.Rating)
		p.Mode2x2.BestRating = p.Mode2x2.Rating
		p.SeasonId = seasonId
		if player and player.Parent then
			if gems > 0 then
				notify(player, string.format("Temporada PvP %s encerrada! Patente %s: +%d gemas!", prevSeason, tier.Name, gems))
			else
				notify(player, string.format("Nova Temporada PvP (%s) iniciada!", seasonId))
			end
		end
	end

	p.Rating = PvPRank.BestRatingOf(p)
	p.BestRating = math.max(p.BestRating or p.Rating, p.Rating, p.Mode1x1.BestRating, p.Mode2x2.BestRating)
	p.Wins = (p.Mode1x1.Wins or 0) + (p.Mode2x2.Wins or 0)
	p.Losses = (p.Mode1x1.Losses or 0) + (p.Mode2x2.Losses or 0)
	p.Wins2x2 = p.Mode2x2.Wins or 0
	p.Losses2x2 = p.Mode2x2.Losses or 0

	if p.DailyDay ~= day then
		p.DailyDay = day
		p.DailyRewards = 0
		p.OpponentsToday = {}
	elseif typeof(p.OpponentsToday) ~= "table" then
		p.OpponentsToday = {}
	end
	return p
end

local function syncLeaderstats(player: Player)
	if not player or not player.Parent then
		return
	end
	local data = PlayerDataService.Get(player)
	if not data then
		return
	end
	local pvp = ensurePvP(data, Clock.Now(), player)
	local bestElo = PvPRank.BestRatingOf(pvp)
	local tier = PvPRank.TierFor(bestElo)

	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		ls.Parent = player
	end

	-- ELO e o primeiro filho numerico de leaderstats -> PlayerList ordena automaticamente por ELO!
	local eloVal = ls:FindFirstChild("ELO")
	if not eloVal then
		eloVal = Instance.new("IntValue")
		eloVal.Name = "ELO"
		eloVal.Parent = ls
	end
	(eloVal :: IntValue).Value = bestElo

	local tierVal = ls:FindFirstChild("Patente")
	if not tierVal then
		tierVal = Instance.new("StringValue")
		tierVal.Name = "Patente"
		tierVal.Parent = ls
	end
	(tierVal :: StringValue).Value = tier.Name

	player:SetAttribute("PvPElo", bestElo)
	player:SetAttribute("PvPTier", tier.Name)
	player:SetAttribute("PvPElo1x1", pvp.Mode1x1.Rating)
	player:SetAttribute("PvPElo2x2", pvp.Mode2x2.Rating)

	local title = nil
	if tier.Id == "Lenda" or (data.Cosmetics and data.Cosmetics.PvPLegend) then
		title = "Lenda PvP"
	elseif data.Cosmetics and data.Cosmetics.PvPTop then
		title = "Top 100 PvP"
	end
	player:SetAttribute("PvPTitle", title)
end

--------------------------------------------------------------------
-- Montagem de Times (Ranked VGC vs Casual Poder Real)
--------------------------------------------------------------------
local function rawTeamMembers(player: Player)
	local data = PlayerDataService.Get(player)
	if not data or not data.StarterChosen or #data.Team == 0 then
		return nil
	end
	local list = {}
	for _, uid in ipairs(data.Team) do
		local m = data.Collection[uid]
		if m then
			table.insert(list, m)
		end
	end
	return if #list > 0 then list else nil
end

-- mode = "Ranked" | "Casual" | "Friendly"
function PvPService.TeamFor(player: Player, mode: string?, format: string?)
	local members = rawTeamMembers(player)
	if not members then
		return nil, "Escolha seu personagem inicial e monte um time primeiro."
	end
	local isRanked = mode == "Ranked"
	local fmt = if format == "2x2" then "2x2" elseif format == "1x1" then "1x1" else nil

	if isRanked then
		local ok, err = PvPRank.ValidateRankedTeam(members, fmt or "1x1")
		if not ok then
			return nil, err
		end
	elseif fmt == "2x2" and #members < 2 then
		return nil, "Precisa de pelo menos 2 personagens no time para 2x2."
	end

	local team = {}
	for _, m in ipairs(members) do
		if isRanked then
			-- Competitivo: Nv. 50, BST da colecao 1.00x, Estrelas/Variantes/+10% Despertar = 0% (cosmetico),
			-- Genetica, Treino da Capsula e Passiva Secreta (se Desperto) CONTAM.
			table.insert(team, {
				CharacterId = m.CharacterId,
				Level = PvPRank.RankedRules.NormalizedLevel,
				Moves = table.clone(m.Active),
				RankedNormalized = true,
				StatMultiplier = 1,
				StatMultipliers = Genetics.MultipliersFor(m.Genetics, m.Training),
				Genetics = m.Genetics,
				Training = m.Training,
				Awakened = m.Awakened == true,
			})
		else
			-- Casual / Amistoso: poder real nao normalizado ("vale tudo")
			table.insert(team, {
				CharacterId = m.CharacterId,
				Level = m.Level,
				Moves = table.clone(m.Active),
				RankedNormalized = false,
				StatMultiplier = Progression.MemberMultiplier(m),
				StatMultipliers = Genetics.MultipliersFor(m.Genetics, m.Training),
				Genetics = m.Genetics,
				Training = m.Training,
				Awakened = m.Awakened == true,
			})
		end
	end
	return team, nil
end

--------------------------------------------------------------------
-- Registro de Resultados (Competitivo ELO Separado vs Casual vs Amistoso)
--------------------------------------------------------------------
local refreshMonumentBoard

local function recordPvPResult(winner: Player?, loser: Player?, mode: string, fmt: string, reason: string?)
	if not winner or not loser then
		return
	end
	local wData = PlayerDataService.Get(winner)
	local lData = PlayerDataService.Get(loser)
	if not wData or not lData then
		return
	end
	local now = Clock.Now()
	local wp = ensurePvP(wData, now, winner)
	local lp = ensurePvP(lData, now, loser)

	-- Duelo Amistoso na Praca: sem ELO e sem boost
	if mode == "Friendly" then
		notify(winner, string.format("Vit\u{f3}ria no Duelo Amistoso %s contra %s!", fmt, loser.DisplayName))
		notify(loser, string.format("Duelo Amistoso %s contra %s encerrado.", fmt, winner.DisplayName))
		return
	end

	-- Fila Casual: sem ELO, mas paga recompensa diaria enxuta (compartilhada no teto 3x/dia)
	if mode == "Casual" then
		local bonusText = ""
		if (wp.DailyRewards or 0) < PvPRank.DailyRewardCap then
			wp.DailyRewards = (wp.DailyRewards or 0) + 1
			local rw = if fmt == "2x2" then PvPRank.WinReward.Casual2x2 else PvPRank.WinReward.Casual1x1
			if rw and rw.Gold and rw.Gold > 0 then
				wData.Gold += rw.Gold
				bonusText = string.format(" · +%d gold (%d/%d hoje)", rw.Gold, wp.DailyRewards, PvPRank.DailyRewardCap)
			end
			AccountLevelService.AddXp(winner, math.floor(AccountLevel.XpSources.PvPWin * 0.6), "Vit\u{f3}ria Casual " .. fmt, true)
		end
		local loseText = ""
		if reason ~= "Disconnected" and reason ~= "Disconnect" and (lp.DailyRewards or 0) < PvPRank.DailyRewardCap then
			lData.Gold += 200
			loseText = " · +200 gold (participa\u{e7}\u{e3}o)"
		end
		notify(winner, string.format("Vit\u{f3}ria Casual %s contra %s!%s", fmt, loser.DisplayName, bonusText))
		notify(loser, string.format("Partida Casual %s contra %s encerrada.%s", fmt, winner.DisplayName, loseText))
		PlayerDataService.MarkChanged(winner)
		PlayerDataService.MarkChanged(loser)
		return
	end

	-- Fila Competitiva (Ranked): ELO separado por formato (1x1 vs 2x2) + trava anti-farm por oponente/dia
	local wKey = fmt .. "_" .. tostring(loser.UserId)
	local lKey = fmt .. "_" .. tostring(winner.UserId)
	local alreadyFought = wp.OpponentsToday[wKey] == true or lp.OpponentsToday[lKey] == true
	if alreadyFought then
		notify(winner, string.format("Vit\u{f3}ria Competitiva %s! (ELO/b\u{f4}nus contra %s j\u{e1} contaram hoje.)", fmt, loser.DisplayName))
		notify(loser, string.format("Partida %s contra %s encerrada (sem altera\u{e7}\u{e3}o de ELO hoje).", fmt, winner.DisplayName))
		return
	end

	wp.OpponentsToday[wKey] = true
	lp.OpponentsToday[lKey] = true

	local wSlot = PvPRank.ModeSlotOf(wp, fmt)
	local lSlot = PvPRank.ModeSlotOf(lp, fmt)
	local gain, loss = PvPRank.Delta(wSlot.Rating, lSlot.Rating, fmt)

	wSlot.Rating = math.clamp(wSlot.Rating + gain, PvPRank.MinRating, PvPRank.MaxRating)
	wSlot.BestRating = math.max(wSlot.BestRating, wSlot.Rating)
	wSlot.Wins = (wSlot.Wins or 0) + 1

	lSlot.Rating = math.clamp(lSlot.Rating - loss, PvPRank.MinRating, PvPRank.MaxRating)
	lSlot.Losses = (lSlot.Losses or 0) + 1

	wp.Rating = PvPRank.BestRatingOf(wp)
	wp.BestRating = math.max(wp.BestRating, wp.Rating)
	wp.Wins = (wp.Mode1x1.Wins or 0) + (wp.Mode2x2.Wins or 0)
	wp.Wins2x2 = wp.Mode2x2.Wins or 0

	lp.Rating = PvPRank.BestRatingOf(lp)
	lp.Losses = (lp.Mode1x1.Losses or 0) + (lp.Mode2x2.Losses or 0)
	lp.Losses2x2 = lp.Mode2x2.Losses or 0

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
		winBonusText = string.format(" · %s (%d/%d hoje)", table.concat(parts, " "), wp.DailyRewards, PvPRank.DailyRewardCap)
		AccountLevelService.AddXp(winner, AccountLevel.XpSources.PvPWin, "Vit\u{f3}ria Competitiva " .. fmt, true)
	end

	local loseBonusText = ""
	if reason ~= "Disconnected" and reason ~= "Disconnect" and (lp.DailyRewards or 0) < PvPRank.DailyRewardCap then
		lData.Gold += PvPRank.ParticipationGold
		loseBonusText = string.format(" · +%d gold (participa\u{e7}\u{e3}o)", PvPRank.ParticipationGold)
	end

	local wTier = PvPRank.TierFor(wSlot.Rating)
	local lTier = PvPRank.TierFor(lSlot.Rating)
	notify(winner, string.format("Vit\u{f3}ria Competitiva %s! +%d ELO (%s · %d)%s", fmt, gain, wTier.Name, wSlot.Rating, winBonusText))
	notify(loser, string.format("Derrota Competitiva %s: -%d ELO (%s · %d)%s", fmt, loss, lTier.Name, lSlot.Rating, loseBonusText))

	syncLeaderstats(winner)
	syncLeaderstats(loser)
	PlayerDataService.MarkChanged(winner)
	PlayerDataService.MarkChanged(loser)
	task.spawn(PlayerDataService.SaveNow, winner)
	task.spawn(PlayerDataService.SaveNow, loser)

	-- Atualiza placar global da modalidade (1x1 ou 2x2)
	local cache = globalCaches[fmt]
	if cache then
		cache.Time = -math.huge
	end
	task.spawn(function()
		local store = getRankStore(fmt)
		pcall(store.SetAsync, store, tostring(winner.UserId), wSlot.Rating)
		pcall(store.SetAsync, store, tostring(loser.UserId), lSlot.Rating)
		if refreshMonumentBoard then
			refreshMonumentBoard()
		end
	end)
end

--------------------------------------------------------------------
-- Placar Global e do Servidor (Separado 1x1 e 2x2)
--------------------------------------------------------------------
local function fetchGlobalList(fmt: string)
	local f = normFormat(fmt)
	local cache = globalCaches[f]
	if os.clock() - cache.Time < GLOBAL_CACHE_TIME then
		return cache.List
	end
	cache.Time = os.clock()
	local ok, pages = pcall(function()
		return getRankStore(f):GetSortedAsync(false, PvPRank.LeaderboardSize)
	end)
	if ok and pages then
		local list = {}
		for _, entry in ipairs(pages:GetCurrentPage()) do
			local uid = tonumber(entry.key)
			if uid then
				local rating = tonumber(entry.value) or PvPRank.StartRating
				table.insert(list, {
					UserId = uid,
					Name = nameOf(uid),
					Rating = rating,
					Tier = PvPRank.TierFor(rating).Name,
				})
			end
		end
		cache.List = list
	end
	return cache.List
end

local function fetchServerList(fmt: string)
	local f = normFormat(fmt)
	local now = Clock.Now()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local d = PlayerDataService.Get(p)
		if d then
			local pvp = ensurePvP(d, now, p)
			local slot = PvPRank.ModeSlotOf(pvp, f)
			table.insert(list, {
				UserId = p.UserId,
				Name = p.Name,
				Rating = slot.Rating,
				Tier = PvPRank.TierFor(slot.Rating).Name,
				Wins = slot.Wins or 0,
				Losses = slot.Losses or 0,
			})
		end
	end
	table.sort(list, function(a, b)
		if a.Rating ~= b.Rating then
			return a.Rating > b.Rating
		end
		return (a.Wins or 0) > (b.Wins or 0)
	end)
	while #list > PvPRank.LeaderboardSize do
		table.remove(list)
	end
	return list
end

function PvPService.GetLeaderboard(player: Player?, format: string?)
	local fmt = normFormat(format)
	local now = Clock.Now()
	local serverList = fetchServerList(fmt)
	local globalList = fetchGlobalList(fmt)

	local meData = player and PlayerDataService.Get(player) or nil
	local mePvP = if meData then ensurePvP(meData, now, player) else PvPRank.DefaultState()
	local mySlot = PvPRank.ModeSlotOf(mePvP, fmt)
	local bestOverall = PvPRank.BestRatingOf(mePvP)

	return {
		Format = fmt,
		Server = serverList,
		Global = globalList,
		SeasonId = PvPRank.SeasonId(now),
		SeasonEnd = PvPRank.SeasonEnd(now),
		MyPvP = {
			Format = fmt,
			Rating = mySlot.Rating,
			BestRating = mySlot.BestRating,
			Tier = PvPRank.TierFor(mySlot.Rating).Name,
			Wins = mySlot.Wins or 0,
			Losses = mySlot.Losses or 0,
			BestOverall = bestOverall,
			TierOverall = PvPRank.TierFor(bestOverall).Name,
			Rating1x1 = mePvP.Mode1x1.Rating,
			Tier1x1 = PvPRank.TierFor(mePvP.Mode1x1.Rating).Name,
			Wins1x1 = mePvP.Mode1x1.Wins or 0,
			Losses1x1 = mePvP.Mode1x1.Losses or 0,
			Rating2x2 = mePvP.Mode2x2.Rating,
			Tier2x2 = PvPRank.TierFor(mePvP.Mode2x2.Rating).Name,
			Wins2x2 = mePvP.Mode2x2.Wins or 0,
			Losses2x2 = mePvP.Mode2x2.Losses or 0,
			Wins2x2Legacy = mePvP.Mode2x2.Wins or 0,
			DailyRewards = mePvP.DailyRewards or 0,
			DailyCap = PvPRank.DailyRewardCap,
			LastSeason = mePvP.LastSeason,
		},
	}
end

--------------------------------------------------------------------
-- Quadro 3D de Ranking na Praca (Workspace.Map.PvPBoardMonument)
--------------------------------------------------------------------
local function fillBoardColumn(colFrame: Instance?, entries: { any })
	if not colFrame then
		return
	end
	for i = 1, PvPRank.LeaderboardSize do
		local row = colFrame:FindFirstChild("Row" .. i)
		if row then
			local entry = entries[i]
			local nameLbl = row:FindFirstChild("PlayerName")
			local tierLbl = row:FindFirstChild("TierLabel")
			local eloLbl = row:FindFirstChild("EloLabel")
			if entry then
				if nameLbl and nameLbl:IsA("TextLabel") then
					nameLbl.Text = entry.Name
					nameLbl.TextColor3 = if i == 1 then Color3.fromRGB(255, 224, 102) elseif i == 2 then Color3.fromRGB(220, 232, 255) elseif i == 3 then Color3.fromRGB(255, 184, 118) else Color3.fromRGB(238, 244, 255)
				end
				if tierLbl and tierLbl:IsA("TextLabel") then
					tierLbl.Text = entry.Tier or "Bronze"
				end
				if eloLbl and eloLbl:IsA("TextLabel") then
					eloLbl.Text = tostring(entry.Rating) .. " ELO"
				end
			else
				if nameLbl and nameLbl:IsA("TextLabel") then
					nameLbl.Text = "Aguardando competidor"
					nameLbl.TextColor3 = Color3.fromRGB(130, 146, 186)
				end
				if tierLbl and tierLbl:IsA("TextLabel") then
					tierLbl.Text = "--"
				end
				if eloLbl and eloLbl:IsA("TextLabel") then
					eloLbl.Text = "--"
				end
			end
		end
	end
end

refreshMonumentBoard = function()
	local map = workspace:FindFirstChild("Map")
	local monument = map and map:FindFirstChild("PvPBoardMonument")
	if not monument then
		return
	end
	local screen = monument:FindFirstChild("BoardScreen", true)
	local gui = screen and screen:FindFirstChild("BoardGui")
	if not gui then
		return
	end
	local list2x2 = fetchGlobalList("2x2")
	if #list2x2 == 0 then
		list2x2 = fetchServerList("2x2")
	end
	local list1x1 = fetchGlobalList("1x1")
	if #list1x1 == 0 then
		list1x1 = fetchServerList("1x1")
	end

	local body = gui:FindFirstChild("Body", true)
	if body then
		fillBoardColumn(body:FindFirstChild("Col2x2"), list2x2)
		fillBoardColumn(body:FindFirstChild("Col1x1"), list1x1)
	end
	local seasonLbl = gui:FindFirstChild("SeasonLabel", true)
	if seasonLbl and seasonLbl:IsA("TextLabel") then
		seasonLbl.Text = "TEMPORADA " .. PvPRank.SeasonId(Clock.Now()) .. "  |  PRESSIONE E PARA ENTRAR NA FILA"
	end
end

--------------------------------------------------------------------
-- Validacao de localizacao e ocupacao
--------------------------------------------------------------------
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
	local p = root.Position
	return math.abs(p.X) <= Config.PlazaHalfX and math.abs(p.Z) <= Config.PlazaHalfZ and p.Y > -20 and p.Y < 60
end

local function inMainWorld(player: Player): boolean
	local root = rootOf(player)
	if not root then
		return false
	end
	-- Mapa principal (Praca + Bases/Plots + Esteira); exclui Arenas (X > 1500) e cavernas do Refugio (Y < -20)
	local p = root.Position
	return math.abs(p.X) <= 500 and math.abs(p.Z) <= 500 and p.Y > -20 and p.Y < 120
end

local function blocker(player: Player, who: string, mode: string?, format: string?, requirePlaza: boolean?): string?
	if not player.Parent then
		return who .. " saiu do jogo."
	end
	if BattleService.IsInBattle(player) or TowerService.IsRunning(player) then
		return who .. " est\u{e1} em batalha."
	end
	if requirePlaza then
		if not inPlaza(player) then
			return who .. " precisa estar na pra\u{e7}a."
		end
	elseif not inMainWorld(player) then
		return who .. " precisa sair da arena/ref\u{fa}gio para entrar na fila."
	end
	local team, teamErr = PvPService.TeamFor(player, mode or "Casual", format)
	if not team then
		return if who == "Voc\u{ea}" then (teamErr or "Time inv\u{e1}lido.") else (who .. ": " .. (teamErr or "time inv\u{e1}lido."))
	end
	return nil
end

local function throttled(player: Player): boolean
	local t = os.clock()
	if lastCall[player] and t - lastCall[player] < 0.45 then
		return true
	end
	lastCall[player] = t
	return false
end

--------------------------------------------------------------------
-- Filas Competitiva e Casual (Matchmaking Hibrido Local + Global)
--------------------------------------------------------------------
local function buildQueuePayload(player: Player)
	local entry = playerQueue[player]
	local counts = {}
	for _, qid in ipairs(PvPRank.QueueOrder) do
		counts[qid] = #localQueues[qid]
	end
	if not entry then
		return {
			InQueue = false,
			QueueCounts = counts,
		}
	end
	local elapsed = math.max(0, math.floor(os.clock() - entry.JoinedAt))
	local cfg = PvPRank.QueueConfig(entry.QueueId)
	local range = if cfg and cfg.IsRanked then PvPRank.AllowedEloGap(elapsed) else 9999
	return {
		InQueue = true,
		QueueId = entry.QueueId,
		Title = cfg and cfg.Title or entry.QueueId,
		Short = cfg and cfg.Short or entry.QueueId,
		Mode = entry.Mode,
		Format = entry.Format,
		IsRanked = cfg and cfg.IsRanked or false,
		Rating = entry.Rating,
		Elapsed = elapsed,
		Range = range,
		QueueCounts = counts,
	}
end

local function removeGlobalTicket(queueId: string, userId: number)
	local map = getQueueMap(queueId)
	if not map then
		return
	end
	task.spawn(function()
		pcall(map.RemoveAsync, map, tostring(userId))
	end)
end

local function removeFromQueue(player: Player, reason: string?, silent: boolean?)
	local entry = playerQueue[player]
	if not entry then
		return false
	end
	playerQueue[player] = nil
	local q = localQueues[entry.QueueId]
	if q then
		local idx = table.find(q, entry)
		if idx then
			table.remove(q, idx)
		end
	end
	removeGlobalTicket(entry.QueueId, entry.UserId)
	if not silent and player.Parent then
		local payload = buildQueuePayload(player)
		payload.Reason = reason
		fireQueueState(player, payload)
	end
	return true
end

local function launchMatchedPair(entryA, entryB, queueId: string, isReservedMatch: boolean?)
	local pA, pB = entryA.Player, entryB.Player
	local cfg = PvPRank.QueueConfig(queueId)
	if not cfg then
		return false
	end
	local teamA, errA = PvPService.TeamFor(pA, cfg.Mode, cfg.Format)
	local teamB, errB = PvPService.TeamFor(pB, cfg.Mode, cfg.Format)
	if not teamA or not teamB then
		if not teamA then
			notify(pA, "Partida cancelada: " .. tostring(errA))
		end
		if not teamB then
			notify(pB, "Partida cancelada: " .. tostring(errB))
		end
		return false
	end

	fireQueueState(pA, { InQueue = false, MatchFound = true, QueueId = queueId, OpponentName = pB.DisplayName })
	fireQueueState(pB, { InQueue = false, MatchFound = true, QueueId = queueId, OpponentName = pA.DisplayName })

	local ok, err = BattleService.StartPvP(pA, pB, teamA, teamB, function(winnerSide, reason)
		local winner = if winnerSide == "Player" then pA elseif winnerSide == "Enemy" then pB else nil
		local loser = if winner == pA then pB elseif winner == pB then pA else nil
		if winner and loser then
			print(string.format("[PvP %s %s] %s x %s -> venceu %s (%s)", cfg.Mode, cfg.Format, pA.Name, pB.Name, winner.Name, tostring(reason)))
			recordPvPResult(winner, loser, cfg.Mode, cfg.Format, reason)
		end
		if isReservedMatch then
			task.delay(5, function()
				local back = {}
				if pA.Parent then
					table.insert(back, pA)
				end
				if pB.Parent then
					table.insert(back, pB)
				end
				if #back > 0 then
					pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, back)
				end
			end)
		end
	end, { Format = cfg.Format, Mode = cfg.Mode })

	if not ok then
		notify(pA, "N\u{e3}o foi poss\u{ed}vel iniciar a arena: " .. tostring(err))
		notify(pB, "N\u{e3}o foi poss\u{ed}vel iniciar a arena: " .. tostring(err))
		return false
	end
	return true
end

local function tryLocalMatches()
	local nowClock = os.clock()
	for _, qid in ipairs(PvPRank.QueueOrder) do
		local cfg = PvPRank.QueueConfig(qid)
		local q = localQueues[qid]
		-- 1. Limpa entradas invalidas (saiu, entrou em batalha/torre/raid, saiu da praca ou time ficou invalido)
		for i = #q, 1, -1 do
			local e = q[i]
			local why = blocker(e.Player, "Voc\u{ea}", cfg.Mode, cfg.Format)
			if why then
				removeFromQueue(e.Player, "Removido da fila: " .. why)
				if e.Player.Parent then
					notify(e.Player, "Saiu da fila PvP: " .. why)
				end
			end
		end

		-- 2. Pareamento local instantaneo (zero tela de carregamento)
		local i = 1
		while i <= #q do
			local a = q[i]
			local bestIdx = nil
			local bestDiff = math.huge
			local waitA = nowClock - a.JoinedAt
			local gapA = if cfg.IsRanked then PvPRank.AllowedEloGap(waitA) else math.huge

			for j = i + 1, #q do
				local b = q[j]
				local diff = math.abs(a.Rating - b.Rating)
				local waitB = nowClock - b.JoinedAt
				local allowed = if cfg.IsRanked then math.max(gapA, PvPRank.AllowedEloGap(waitB)) else math.huge
				if diff <= allowed and diff < bestDiff then
					bestDiff = diff
					bestIdx = j
				end
			end

			if bestIdx then
				local b = q[bestIdx]
				removeFromQueue(a.Player, nil, true)
				removeFromQueue(b.Player, nil, true)
				launchMatchedPair(a, b, qid, false)
			else
				i += 1
			end
		end
	end
end

-- Matchmaking Global entre servidores via MemoryStoreService + TeleportService:ReserveServer
local function stepGlobalMatchmaking()
	if memoryStoreDisabled or RunService:IsStudio() then
		return
	end
	local nowClock = os.clock()
	for _, qid in ipairs(PvPRank.QueueOrder) do
		local q = localQueues[qid]
		if #q > 0 then
			local cfg = PvPRank.QueueConfig(qid)
			local map = getQueueMap(qid)
			if not map then
				return
			end
			for _, entry in ipairs(table.clone(q)) do
				if playerQueue[entry.Player] == entry and (nowClock - entry.JoinedAt) >= GLOBAL_FALLBACK_WAIT then
					local myKey = tostring(entry.UserId)
					-- Atualiza/verifica o proprio ticket (outro servidor pode ja ter reservado uma arena para nos!)
					local claimedMatch = nil
					local okUp, val = pcall(function()
						return map:UpdateAsync(myKey, function(old)
							if typeof(old) == "table" and old.MatchCode and old.MatchData then
								claimedMatch = old
								return old
							end
							return {
								UserId = entry.UserId,
								Name = entry.Name,
								ServerId = SERVER_ID,
								Rating = entry.Rating,
								JoinedAt = entry.JoinedUnix,
								QueueId = qid,
							}
						end, GLOBAL_QUEUE_TTL)
					end)
					if okUp and claimedMatch and claimedMatch.MatchCode then
						removeFromQueue(entry.Player, nil, true)
						notify(entry.Player, "Partida global encontrada! Teleportando para a Arena...")
						fireQueueState(entry.Player, { InQueue = false, MatchFound = true, QueueId = qid, Global = true })
						local opts = Instance.new("TeleportOptions")
						opts.ReservedServerAccessCode = claimedMatch.MatchCode
						opts:SetTeleportData({ PvPMatch = claimedMatch.MatchData })
						pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, { entry.Player }, opts)
					elseif okUp and val then
						-- Procura oponente elegivel em outro servidor
						local okRange, items = pcall(map.GetRangeAsync, map, Enum.SortDirection.Ascending, 20)
						if okRange and typeof(items) == "table" then
							local allowedGap = if cfg.IsRanked then PvPRank.AllowedEloGap(nowClock - entry.JoinedAt) else math.huge
							for _, item in ipairs(items) do
								local other = item.value
								if typeof(other) == "table"
									and other.UserId ~= entry.UserId
									and other.ServerId ~= SERVER_ID
									and not other.MatchCode
									and entry.UserId < other.UserId -- desempate deterministico evita dupla reserva
								then
									local diff = math.abs(entry.Rating - (tonumber(other.Rating) or PvPRank.StartRating))
									if diff <= allowedGap then
										local okRes, code = pcall(TeleportService.ReserveServer, TeleportService, game.PlaceId)
										if okRes and code then
											local matchData = {
												MatchId = HttpService:GenerateGUID(false),
												QueueId = qid,
												Mode = cfg.Mode,
												Format = cfg.Format,
												Players = { entry.UserId, other.UserId },
											}
											local claimSucceeded = false
											pcall(function()
												map:UpdateAsync(tostring(other.UserId), function(cur)
													if typeof(cur) == "table" and not cur.MatchCode then
														cur.MatchCode = code
														cur.MatchData = matchData
														claimSucceeded = true
														return cur
													end
													return nil
												end, 30)
											end)
											if claimSucceeded then
												removeFromQueue(entry.Player, nil, true)
												notify(entry.Player, "Partida global encontrada! Teleportando para a Arena...")
												fireQueueState(entry.Player, { InQueue = false, MatchFound = true, QueueId = qid, Global = true })
												local opts = Instance.new("TeleportOptions")
												opts.ReservedServerAccessCode = code
												opts:SetTeleportData({ PvPMatch = matchData })
												pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, { entry.Player }, opts)
												break
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
end

-- Chegada em servidor reservado de partida global
local function handleIncomingReservedPlayer(player: Player)
	if game.PrivateServerId == "" then
		return
	end
	local ok, joinData = pcall(player.GetJoinData, player)
	if not ok or typeof(joinData) ~= "table" then
		return
	end
	local tpData = joinData.TeleportData
	if typeof(tpData) ~= "table" or typeof(tpData.PvPMatch) ~= "table" then
		return
	end
	local match = tpData.PvPMatch
	local matchId = tostring(match.MatchId or "")
	if matchId == "" or not PvPRank.QueueConfig(match.QueueId) then
		return
	end

	local bucket = pendingGlobalMatches[matchId]
	if not bucket then
		bucket = {
			MatchId = matchId,
			QueueId = match.QueueId,
			Expected = match.Players or {},
			Arrived = {},
			Started = false,
		}
		pendingGlobalMatches[matchId] = bucket
		task.delay(RESERVED_ARRIVE_TIMEOUT, function()
			if not bucket.Started then
				pendingGlobalMatches[matchId] = nil
				local toReturn = {}
				for _, p in ipairs(bucket.Arrived) do
					if p.Parent then
						notify(p, "Oponente n\u{e3}o conectou \u{e0} arena. Retornando \u{e0} pra\u{e7}a...")
						table.insert(toReturn, p)
					end
				end
				if #toReturn > 0 then
					pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, toReturn)
				end
			end
		end)
	end

	task.spawn(function()
		PlayerDataService.WaitFor(player, 15)
		if not player.Parent then
			return
		end
		if not player.Character then
			player.CharacterAdded:Wait()
		end
		task.wait(0.8)
		if not player.Parent or bucket.Started then
			return
		end
		table.insert(bucket.Arrived, player)
		if #bucket.Arrived >= 2 and not bucket.Started then
			bucket.Started = true
			pendingGlobalMatches[matchId] = nil
			local pA, pB = bucket.Arrived[1], bucket.Arrived[2]
			launchMatchedPair({ Player = pA }, { Player = pB }, bucket.QueueId, true)
		else
			notify(player, "Arena global pronta! Aguardando o oponente conectar...")
		end
	end)
end

function PvPService.JoinQueue(player: Player, queueId: string?)
	if throttled(player) then
		return false, "Aguarde um instante."
	end
	local cfg = PvPRank.QueueConfig(queueId)
	if not cfg then
		return false, "Fila PvP inv\u{e1}lida."
	end
	local why = blocker(player, "Voc\u{ea}", cfg.Mode, cfg.Format)
	if why then
		return false, why
	end
	if playerQueue[player] then
		if playerQueue[player].QueueId == cfg.Id then
			return true, buildQueuePayload(player)
		end
		removeFromQueue(player, nil, true)
	end

	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Dados ainda carregando."
	end
	local pvp = ensurePvP(data, Clock.Now(), player)
	local rating = PvPRank.ModeSlotOf(pvp, cfg.Format).Rating

	local entry = {
		Player = player,
		UserId = player.UserId,
		Name = player.Name,
		Rating = rating,
		JoinedAt = os.clock(),
		JoinedUnix = os.time(),
		QueueId = cfg.Id,
		Mode = cfg.Mode,
		Format = cfg.Format,
	}
	table.insert(localQueues[cfg.Id], entry)
	playerQueue[player] = entry

	local payload = buildQueuePayload(player)
	fireQueueState(player, payload)
	task.spawn(tryLocalMatches)
	return true, payload
end

function PvPService.LeaveQueue(player: Player)
	local removed = removeFromQueue(player, "Busca cancelada.")
	return true, { InQueue = false, WasQueued = removed }
end

function PvPService.GetQueueStatus(player: Player)
	local data = PlayerDataService.Get(player)
	local pvp = data and ensurePvP(data, Clock.Now(), player) or PvPRank.DefaultState()
	local members = rawTeamMembers(player) or {}
	local ok2, err2, counts2 = PvPRank.ValidateRankedTeam(members, "2x2")
	local ok1, err1, counts1 = PvPRank.ValidateRankedTeam(members, "1x1")
	local payload = buildQueuePayload(player)
	payload.TeamSize = #members
	payload.RankedCheck = {
		["2x2"] = { Valid = ok2, Reason = err2, Counts = counts2 },
		["1x1"] = { Valid = ok1, Reason = err1, Counts = counts1 },
	}
	payload.MyPvP = {
		Rating1x1 = pvp.Mode1x1.Rating,
		Tier1x1 = PvPRank.TierFor(pvp.Mode1x1.Rating).Name,
		Wins1x1 = pvp.Mode1x1.Wins or 0,
		Losses1x1 = pvp.Mode1x1.Losses or 0,
		Rating2x2 = pvp.Mode2x2.Rating,
		Tier2x2 = PvPRank.TierFor(pvp.Mode2x2.Rating).Name,
		Wins2x2 = pvp.Mode2x2.Wins or 0,
		Losses2x2 = pvp.Mode2x2.Losses or 0,
		BestOverall = PvPRank.BestRatingOf(pvp),
		TierOverall = PvPRank.TierFor(PvPRank.BestRatingOf(pvp)).Name,
		DailyRewards = pvp.DailyRewards or 0,
		DailyCap = PvPRank.DailyRewardCap,
		SeasonId = PvPRank.SeasonId(Clock.Now()),
		SeasonEnd = PvPRank.SeasonEnd(Clock.Now()),
	}
	return true, payload
end

--------------------------------------------------------------------
-- Desafio Amistoso por Proximidade na Praca (Casual, Poder Real, Sem ELO)
--------------------------------------------------------------------
local function clearInvite(target: Player)
	local inv = invites[target]
	if inv then
		invites[target] = nil
		if sent[inv.From] == target then
			sent[inv.From] = nil
		end
	end
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
	local why = blocker(player, "Voc\u{ea}", "Casual", fmt, true) or blocker(target, target.DisplayName, "Casual", fmt, true)
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
		return PvPService.Respond(player, target.UserId, true)
	end
	invites[target] = { From = player, Format = fmt, Expires = os.clock() + Config.PvPInviteTime }
	sent[player] = target
	Remotes.PvPInvite:FireClient(target, { Kind = "Incoming", FromUserId = player.UserId, FromName = player.DisplayName, Format = fmt, Mode = "Friendly", Seconds = Config.PvPInviteTime })
	Remotes.PvPInvite:FireClient(player, { Kind = "Sent", ToUserId = target.UserId, ToName = target.DisplayName, Format = fmt, Mode = "Friendly", Seconds = Config.PvPInviteTime })
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
	return true, "Desafio Amistoso " .. fmt .. " enviado para " .. target.DisplayName .. "."
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
	local why = blocker(challenger, challenger.DisplayName, "Casual", fmt, true) or blocker(player, "Voc\u{ea}", "Casual", fmt, true)
	if why then
		if challenger.Parent then
			Remotes.PvPInvite:FireClient(challenger, { Kind = "Closed", Text = "Duelo cancelado: " .. why })
		end
		return false, why
	end
	removeFromQueue(challenger, "Entrou em duelo amistoso.")
	removeFromQueue(player, "Entrou em duelo amistoso.")

	local teamA = PvPService.TeamFor(challenger, "Casual", fmt)
	local teamB = PvPService.TeamFor(player, "Casual", fmt)
	local ok, err = BattleService.StartPvP(challenger, player, teamA, teamB, function(winnerSide, reason)
		local winner = if winnerSide == "Player" then challenger elseif winnerSide == "Enemy" then player else nil
		local loser = if winner == challenger then player elseif winner == player then challenger else nil
		if winner and loser then
			print("[PvP Amistoso " .. fmt .. "] " .. challenger.Name .. " x " .. player.Name .. ": venceu " .. winner.Name .. " (" .. tostring(reason) .. ")")
			recordPvPResult(winner, loser, "Friendly", fmt, reason)
		end
	end, { Format = fmt, Mode = "Friendly" })
	if not ok then
		if challenger.Parent then
			Remotes.PvPInvite:FireClient(challenger, { Kind = "Closed", Text = "Duelo cancelado: " .. tostring(err) })
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

--------------------------------------------------------------------
-- Remote PvPQueue + Dev Bridge
--------------------------------------------------------------------
local function handleQueueRemote(player: Player, action: string?, arg)
	if action == "Join" then
		return PvPService.JoinQueue(player, if typeof(arg) == "string" then arg else nil)
	elseif action == "Leave" then
		return PvPService.LeaveQueue(player)
	elseif action == "Status" then
		return PvPService.GetQueueStatus(player)
	elseif action == "Leaderboard" then
		return true, PvPService.GetLeaderboard(player, if typeof(arg) == "string" then arg else "2x2")
	end
	return false, "A\u{e7}\u{e3}o PvP desconhecida."
end

function PvPService.Dev(player: Player, action: string, a, b)
	if action == "status" then
		return PvPService.GetQueueStatus(player)
	elseif action == "leaderboard" then
		return PvPService.GetLeaderboard(player, a)
	elseif action == "join" then
		return PvPService.JoinQueue(player, a)
	elseif action == "leave" then
		return PvPService.LeaveQueue(player)
	elseif action == "setelo" then
		local data = PlayerDataService.Get(player)
		if not data then
			return false
		end
		local pvp = ensurePvP(data, Clock.Now(), player)
		local slot = PvPRank.ModeSlotOf(pvp, normFormat(a))
		slot.Rating = math.clamp(math.floor(tonumber(b) or PvPRank.StartRating), PvPRank.MinRating, PvPRank.MaxRating)
		slot.BestRating = math.max(slot.BestRating, slot.Rating)
		pvp.Rating = PvPRank.BestRatingOf(pvp)
		syncLeaderstats(player)
		PlayerDataService.MarkChanged(player)
		refreshMonumentBoard()
		return slot.Rating
	elseif action == "refreshboard" then
		refreshMonumentBoard()
		return true
	end
	return nil
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

	local queueRF = Remotes:WaitForChild("PvPQueue", 10)
	if queueRF and queueRF:IsA("RemoteFunction") then
		queueRF.OnServerInvoke = guarded(handleQueueRemote)
	else
		warn("[PvP] RemoteFunction PvPQueue nao encontrado em ReplicatedStorage/Remotes")
	end

	PlayerDataService.Loaded:Connect(function(player)
		syncLeaderstats(player)
		task.defer(refreshMonumentBoard)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		if PlayerDataService.Get(p) then
			syncLeaderstats(p)
		end
		handleIncomingReservedPlayer(p)
	end
	Players.PlayerAdded:Connect(handleIncomingReservedPlayer)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player, nil, true)
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

	-- Loop de matchmaking hibrido + heartbeat de tempo/faixa de busca
	task.spawn(function()
		local ticks = 0
		while true do
			task.wait(MATCH_TICK)
			ticks += 1
			pcall(tryLocalMatches)
			if ticks % 2 == 0 then
				pcall(stepGlobalMatchmaking)
				for p in pairs(playerQueue) do
					if p.Parent then
						fireQueueState(p, buildQueuePayload(p))
					end
				end
			end
		end
	end)

	-- Atualizacao periodica do Quadro 3D de Ranking na praca
	task.spawn(function()
		task.wait(2)
		pcall(refreshMonumentBoard)
		while true do
			task.wait(GLOBAL_CACHE_TIME)
			pcall(refreshMonumentBoard)
		end
	end)
end

return PvPService
