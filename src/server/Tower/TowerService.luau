--[[
	TowerService (Torre 1x1, Torre 2x2, Ginasios de Anime e Modo Treino)
	- Menu da torre ao entrar no gatilho (3 abas: Torre 1x1/2x2, Ginasios e Treino).
	- Torre 1x1 e Torre 2x2: desbloqueio independente (Facil > Medio > Dificil > Infinito)
	  e placares de temporada separados para Infinito 1x1 e Infinito 2x2.
	- Ginasios de Anime (Data/Gyms): mini-trilha de 3 lutas (2 desafios + Lider com 6 personagens do anime),
	  jogavel em 1x1 ou 2x2. Ao vencer o Lider: conquista a Insignia do Ginasio, desbloqueia o Banner
	  daquele anime no Portal de Invocacao (se ainda trancado) e paga recompensa de primeira vitoria.
	- Modo Treino (1x1 e 2x2): escolhe IA (Facil/Medio/Dificil) e Nivel 50 igualado (simulador PvP) ou Nivel Real.
	  Usa copia limpa do time (HP/PP cheios, sem itens, sem alterar perfil salvo e sem XP/gold).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Data = ReplicatedStorage:WaitForChild("Data")
local Characters = require(Data.Characters)
local Tower = require(Data.Tower)
local Gyms = require(Data:WaitForChild("Gyms"))
local Items = require(Data.Items)
local Progression = require(Data.Progression)
local AccountLevel = require(Data:WaitForChild("AccountLevel"))
local Benefits = require(Data.Benefits)
local Genetics = require(Data:WaitForChild("Genetics"))

local BattleService = require(ServerScriptService:WaitForChild("Battle"):WaitForChild("BattleService"))
local Config = require(ServerScriptService.Battle:WaitForChild("BattleConfig"))
local PlayerDataService = require(ServerScriptService:WaitForChild("Data"):WaitForChild("PlayerDataService"))
local AccountLevelService = require(ServerScriptService.Data:WaitForChild("AccountLevelService"))
local ProgressionService = require(ServerScriptService.Data:WaitForChild("ProgressionService"))
local RetentionService = require(ServerScriptService.Data:WaitForChild("RetentionService"))
local Clock = require(ServerScriptService.Data:WaitForChild("Clock"))
local Retention = require(Data:WaitForChild("Retention"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local TowerService = {}

local BAG_SLOTS = 30
local STACK = 99
local GLOBAL_CACHE_TIME = 60

local runs = {} -- [Player] = corrida (Tower | Gym)
local menuOpen = {} -- [Player] = true
local rng = Random.new()

local globalCaches = {
	["1x1"] = { Time = -math.huge, List = {}, Season = "" },
	["2x2"] = { Time = -math.huge, List = {}, Season = "" },
}
local nameCache = {}

local function today(): number
	return os.time() // 86400 -- dia UTC
end

local function normFormat(fmt): string
	return if fmt == "2x2" then "2x2" else "1x1"
end

local function towerSlot(data, format: string)
	if format == "2x2" then
		data.Tower2x2 = data.Tower2x2 or { Unlocked = "Facil", BestInfiniteFloor = 0, LastHardRewardDay = 0 }
		return data.Tower2x2
	end
	data.Tower = data.Tower or { Unlocked = "Facil", BestInfiniteFloor = 0, LastHardRewardDay = 0 }
	return data.Tower
end

local function seasonSlot(data, format: string)
	if format == "2x2" then
		data.Season2x2 = data.Season2x2 or { Id = "", Best = 0 }
		return data.Season2x2
	end
	data.Season = data.Season or { Id = "", Best = 0 }
	return data.Season
end

local function aliveCountInTeam(team): number
	local n = 0
	for _, entry in ipairs(team or {}) do
		if entry.Hp == nil or entry.Hp > 0 then
			n += 1
		end
	end
	return n
end

--------------------------------------------------------------------
-- Placar (separado para 1x1 e 2x2)
--------------------------------------------------------------------
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

local function serverBoard(format: string)
	local list = {}
	local season = RetentionService.CurrentSeason()
	for _, p in ipairs(Players:GetPlayers()) do
		local data = PlayerDataService.Get(p)
		if data then
			local s = seasonSlot(data, format)
			if s.Id == season and (s.Best or 0) > 0 then
				table.insert(list, { Name = p.Name, Floor = s.Best })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Floor > b.Floor
	end)
	while #list > Tower.LeaderboardSize do
		table.remove(list)
	end
	return list
end

local function getGlobalBoard(format: string)
	local cache = globalCaches[format] or globalCaches["1x1"]
	local season = RetentionService.CurrentSeason()
	if cache.Season == season and os.clock() - cache.Time < GLOBAL_CACHE_TIME then
		return cache.List
	end
	if cache.Season ~= season then
		cache.List = {}
	end
	cache.Season = season
	cache.Time = os.clock()
	local globalBoard = RetentionService.SeasonStore(season, format)
	local ok, pages = pcall(globalBoard.GetSortedAsync, globalBoard, false, Tower.LeaderboardSize)
	if ok then
		local list = {}
		for _, entry in ipairs(pages:GetCurrentPage()) do
			local userId = tonumber(entry.key)
			if userId then
				table.insert(list, { Name = nameOf(userId), Floor = entry.value })
			end
		end
		cache.List = list
	else
		warn("[Tower] Placar global indispon\u{ed}vel (" .. format .. "): " .. tostring(pages))
	end
	return cache.List
end

local function submitSeason(player: Player, floor: number, format: string): boolean
	local record = RetentionService.OnInfiniteFloor(player, floor, format)
	if record then
		local cache = globalCaches[format]
		if cache then
			cache.Time = -math.huge
		end
	end
	return record
end

local function eventGold(gold: number, lines): number
	local mult = Retention.GoldMultiplier(Clock.Now())
	if mult > 1 then
		table.insert(lines, "Evento de fim de semana: " .. Retention.EventNames.Gold .. ".")
	end
	return gold * mult
end

--------------------------------------------------------------------
-- Mochila e recompensas
--------------------------------------------------------------------
local function addItem(data, itemId: string, n: number): boolean
	if not Items.Get(itemId) then
		return false
	end
	local have = data.Bag[itemId] or 0
	if have == 0 then
		local slots = 0
		for _, count in pairs(data.Bag) do
			if count > 0 then
				slots += 1
			end
		end
		if slots >= BAG_SLOTS then
			return false
		end
	end
	if have >= STACK then
		return false
	end
	data.Bag[itemId] = math.min(STACK, have + n)
	return true
end

--------------------------------------------------------------------
-- Times de NPC
--------------------------------------------------------------------
local function roster(): { string }
	local list = {}
	for id, def in pairs(Characters.List) do
		if not def.Prototype then
			table.insert(list, id)
		end
	end
	table.sort(list)
	return list
end

local function npcTeam(size: number, levelFn, extra, modeId: string?)
	local pool = roster()
	local bag = {}
	local team = {}
	local towerGen, towerTrain = Genetics.TowerEnemyPreset(modeId)
	local towerMults = Genetics.MultipliersFor(towerGen, towerTrain)
	for i = 1, size do
		if #bag == 0 then
			bag = table.clone(pool)
		end
		local id = table.remove(bag, rng:NextInteger(1, #bag))
		local entry = {
			CharacterId = id,
			Level = levelFn(i),
			Genetics = table.clone(towerGen),
			Training = table.clone(towerTrain),
			StatMultipliers = table.clone(towerMults),
		}
		for k, v in pairs(extra or {}) do
			entry[k] = v
		end
		team[i] = entry
	end
	return team
end

local function gymStageTeam(stage, gymTier: number?)
	local team = {}
	local gymGen, gymTrain = Genetics.GymEnemyPreset(gymTier)
	local gymMults = Genetics.MultipliersFor(gymGen, gymTrain)
	for i, charId in ipairs(stage.Team) do
		team[i] = {
			CharacterId = charId,
			Level = stage.Level,
			Genetics = table.clone(gymGen),
			Training = table.clone(gymTrain),
			StatMultipliers = table.clone(gymMults),
		}
	end
	return team
end

local function enemyTeamFor(run)
	if run.Kind == "Gym" then
		local gym = Gyms.Get(run.GymId)
		return gymStageTeam(gym.Stages[run.Index + 1], gym.Tier)
	end
	local mode = Tower.Modes[run.Mode]
	if run.Mode == "Infinito" then
		local floor = run.Floor
		local level = Tower.FloorLevel(floor)
		return npcTeam(mode.TeamSize, function()
			return level
		end, { StatMultiplier = Tower.FloorStatMultiplier(floor) }, "Infinito")
	end
	return npcTeam(mode.TeamSize, function()
		return rng:NextInteger(mode.MinLevel, mode.MaxLevel)
	end, nil, run.Mode)
end

-- Copia limpa do time para o Modo Treino (HP/PP cheios, sem status, sem alterar perfil salvo)
local function practiceTeamFor(player: Player, levelMode: string): ({ any }?, string?, number?)
	local data = PlayerDataService.Get(player)
	if not data or not data.StarterChosen or #data.Team == 0 then
		return nil, "Escolha seu personagem inicial primeiro."
	end
	local team = {}
	local levelSum = 0
	for _, uid in ipairs(data.Team) do
		local m = data.Collection[uid]
		if m then
			local lvl = if levelMode == "Equal50" then (Config.PvPLevel or 50) else m.Level
			levelSum += lvl
			table.insert(team, {
				CharacterId = m.CharacterId,
				Level = lvl,
				Moves = table.clone(m.Active),
				StatMultiplier = Progression.MemberMultiplier(m),
				StatMultipliers = Genetics.MultipliersFor(m.Genetics, m.Training),
				Genetics = m.Genetics,
				Training = m.Training,
			})
		end
	end
	if #team == 0 then
		return nil, "Seu time est\u{e1} vazio."
	end
	return team, nil, math.clamp(math.floor(levelSum / #team + 0.5), 1, 50)
end

--------------------------------------------------------------------
-- Corrida (Torre 1x1 / 2x2 e Ginasios de Anime)
--------------------------------------------------------------------
local startNext

local function endRun(player: Player, run, returnPlayer: boolean)
	if runs[player] ~= run then
		return
	end
	runs[player] = nil
	if returnPlayer and player.Parent then
		BattleService.ReturnToPlaza(player)
		BattleService.RequireLeaveTrigger(player)
	end
	if player.Parent then
		PlayerDataService.MarkChanged(player)
		task.spawn(PlayerDataService.SaveNow, player)
	end
end

-- Recompensa ao concluir Facil, Medio ou Dificil (1x1 ou 2x2)
local function completeMode(player: Player, run, lines)
	local data = PlayerDataService.Get(player)
	local tSlot = towerSlot(data, run.Format)
	local mode = Tower.Modes[run.Mode]
	local gold = eventGold(mode.Reward.Gold, lines)
	data.Gold += gold
	table.insert(lines, "Torre " .. run.Format .. " " .. mode.Name .. " conclu\u{ed}da! +" .. gold .. " gold.")
	for _, itemId in ipairs(mode.Reward.Items) do
		if addItem(data, itemId, 1) then
			table.insert(lines, "Recebeu " .. Items.Get(itemId).Name .. ".")
		else
			table.insert(lines, "Mochila cheia: " .. Items.Get(itemId).Name .. " ficou de fora.")
		end
	end
	if mode.Reward.DailyGems then
		if tSlot.LastHardRewardDay ~= today() then
			tSlot.LastHardRewardDay = today()
			data.Gems += mode.Reward.DailyGems
			table.insert(lines, "+" .. mode.Reward.DailyGems .. " gemas (limite di\u{e1}rio " .. run.Format .. ").")
		else
			table.insert(lines, "As gemas do Dif\u{ed}cil (" .. run.Format .. ") j\u{e1} foram recebidas hoje.")
		end
	end
	local nextMode = Tower.NextMode(run.Mode)
	if nextMode and Tower.Index(nextMode) > Tower.Index(tSlot.Unlocked) then
		tSlot.Unlocked = nextMode
		table.insert(lines, "Modo " .. Tower.Modes[nextMode].Name .. " (" .. run.Format .. ") desbloqueado!")
	end
	local modeXp = AccountLevel.XpSources.TowerModeComplete[run.Mode] or 0
	if modeXp > 0 then
		AccountLevelService.AddXp(player, modeXp, "Torre " .. mode.Name, true)
	end
end

-- Recompensa ao vencer o Lider de um Ginasio (luta 3/3)
local function completeGym(player: Player, run, lines)
	local data = PlayerDataService.Get(player)
	local gym = Gyms.Get(run.GymId)
	data.GymsCleared = data.GymsCleared or {}
	data.UnlockedBanners = data.UnlockedBanners or {}

	local firstBadge = not data.GymsCleared[gym.Id]
	local unlockedNewBanner = not data.UnlockedBanners[gym.Anime]

	data.GymsCleared[gym.Id] = true
	data.UnlockedBanners[gym.Anime] = true

	if firstBadge then
		table.insert(lines, gym.Name .. " vencido! Voc\u{ea} conquistou a " .. gym.BadgeName .. "!")
		if unlockedNewBanner then
			table.insert(lines, "Banner de " .. gym.AnimeName .. " desbloqueado no Portal de Invoca\u{e7}\u{e3}o!")
		end
		local gold = eventGold(gym.FirstReward.Gold or 0, lines)
		if gold > 0 then
			data.Gold += gold
		end
		local gems = gym.FirstReward.Gems or 0
		if gems > 0 then
			data.Gems += gems
		end
		local rewardParts = {}
		if gold > 0 then
			table.insert(rewardParts, "+" .. gold .. " gold")
		end
		if gems > 0 then
			table.insert(rewardParts, "+" .. gems .. " gemas")
		end
		for _, itemId in ipairs(gym.FirstReward.Items or {}) do
			local itemDef = Items.Get(itemId)
			if itemDef then
				if addItem(data, itemId, 1) then
					table.insert(rewardParts, "+1 " .. itemDef.Name)
				else
					table.insert(lines, "Mochila cheia: " .. itemDef.Name .. " ficou de fora.")
				end
			end
		end
		table.insert(lines, "Recompensa do Gin\u{e1}sio: " .. table.concat(rewardParts, ", ") .. "!")
	else
		local gold = eventGold(gym.RepeatReward.Gold or 0, lines)
		if gold > 0 then
			data.Gold += gold
		end
		table.insert(lines, gym.Name .. " vencido novamente! +" .. gold .. " gold.")
	end
	AccountLevelService.AddXp(player, AccountLevel.XpSources.GymWin, gym.Name, true)
end

local function onBattleEnd(player: Player, run, battle, result: string)
	local lines = {}
	if runs[player] ~= run then
		return lines
	end
	local data = PlayerDataService.Get(player)
	if not data then
		return lines
	end

	-- Ginasio de Anime (3 lutas)
	if run.Kind == "Gym" then
		local gym = Gyms.Get(run.GymId)
		local total = #gym.Stages
		if result ~= "Win" then
			run.Over = true
			table.insert(lines, "Desafio do " .. gym.Name .. " encerrado na luta " .. (run.Index + 1) .. " de " .. total .. ".")
			return lines
		end
		run.Index += 1
		if run.Index >= total then
			completeGym(player, run, lines)
			run.Over = true
		else
			local nextStage = gym.Stages[run.Index + 1]
			table.insert(lines, "Luta " .. run.Index .. " de " .. total .. " vencida! Pr\u{f3}ximo: " .. nextStage.Title .. ".")
		end
		PlayerDataService.MarkChanged(player)
		return lines
	end

	-- Torre (1x1 ou 2x2)
	local mode = Tower.Modes[run.Mode]
	if result ~= "Win" then
		run.Over = true
		if run.Mode == "Infinito" then
			table.insert(lines, "A corrida (" .. run.Format .. ") terminou no andar " .. run.Floor .. ". Gold ganho: " .. run.GoldEarned .. ".")
		else
			table.insert(lines, "A corrida (" .. run.Format .. ") terminou na batalha " .. run.Index .. " de " .. mode.Battles .. ".")
		end
		return lines
	end

	if run.Mode == "Infinito" then
		local floor = run.Floor
		local tSlot = towerSlot(data, run.Format)
		local gold = eventGold(Tower.FloorGold(floor), lines)
		data.Gold += gold
		run.GoldEarned += gold
		table.insert(lines, "Andar " .. floor .. " (" .. run.Format .. ") vencido! +" .. gold .. " gold.")
		if floor > (tSlot.BestInfiniteFloor or 0) then
			tSlot.BestInfiniteFloor = floor
			table.insert(lines, "Novo recorde (" .. run.Format .. "): andar " .. floor .. ".")
		end
		if submitSeason(player, floor, run.Format) then
			table.insert(lines, "Recorde da temporada (" .. run.Format .. "): andar " .. floor .. ".")
		end
		if Tower.IsBossFloor(floor) then
			local chance = Tower.BossDropChance(floor)
			if rng:NextNumber() < chance then
				local boss = battle.Sides.Enemy.Team[1]
				local bossDef = boss and Characters.Get(boss.Id)
				local bossAnime = bossDef and bossDef.Anime
				local bannerOpen = (not bossAnime) or bossAnime == "Generico" or (data.UnlockedBanners and data.UnlockedBanners[bossAnime] == true)
				if not bannerOpen then
					local reqGym = Gyms.ByAnime(bossAnime)
					data.Gold += 300
					table.insert(lines, string.format("Chefe %s deixou +300 gold b\u{f4}nus! (Ven\u{e7}a o %s para recrutar.)", boss.Name, reqGym and reqGym.Name or "Gin\u{e1}sio"))
				elseif Benefits.CollectionCount(data) >= Benefits.CollectionMax(data) then
					table.insert(lines, "O chefe " .. boss.Name .. " queria se juntar, mas o dep\u{f3}sito de personagens est\u{e1} cheio (" .. Benefits.CollectionMax(data) .. ").")
				else
					local toTeam = #data.Team < 6
					ProgressionService.AddCharacter(player, boss.Id, boss.Level, toTeam)
					table.insert(lines, "O chefe " .. boss.Name .. " se juntou a voc\u{ea}!")
				end
			end
		end
		-- recupera 30% do HP entre andares (time salvo)
		local infXp = AccountLevel.XpSources.TowerInfiniteBase + floor * AccountLevel.XpSources.TowerInfinitePerFloor + (if Tower.IsBossFloor(floor) then AccountLevel.XpSources.TowerInfiniteBossBonus else 0)
		AccountLevelService.AddXp(player, infXp, "Infinito Andar " .. floor, true)
		for _, uid in ipairs(data.Team) do
			local m = data.Collection[uid]
			if m and m.Hp ~= nil then
				local _, max = Progression.CurrentHp(m)
				local hp = math.min(max, m.Hp + math.floor(max * Tower.Modes.Infinito.HealBetweenFloors + 0.5))
				m.Hp = if hp >= max then nil else hp
			end
		end
		run.Floor += 1
	else
		run.Index += 1
		if run.Index >= mode.Battles then
			completeMode(player, run, lines)
			run.Over = true
		else
			table.insert(lines, "Batalha " .. run.Index .. " de " .. mode.Battles .. " vencida.")
		end
	end
	PlayerDataService.MarkChanged(player)
	return lines
end

startNext = function(player: Player, run)
	if runs[player] ~= run or not player.Parent then
		return
	end
	local team = ProgressionService.TeamFor(player)
	if not team then
		endRun(player, run, true)
		return
	end

	local intro, enemyAI
	if run.Kind == "Gym" then
		local gym = Gyms.Get(run.GymId)
		local stageIdx = run.Index + 1
		local stage = gym.Stages[stageIdx]
		enemyAI = stage.AI
		intro = {
			string.format("%s (%s) \u{b7} Luta %d/%d: %s (Nv. %d)", gym.Name, run.Format, stageIdx, #gym.Stages, stage.Title, stage.Level),
		}
	else
		local mode = Tower.Modes[run.Mode]
		enemyAI = mode.AI
		if run.Mode == "Infinito" then
			intro = { "Torre Infinito (" .. run.Format .. ") - andar " .. run.Floor .. (if Tower.IsBossFloor(run.Floor) then " - CHEFE!" else "") .. " (n\u{ed}vel " .. Tower.FloorLevel(run.Floor) .. ")" }
		else
			intro = { "Torre " .. mode.Name .. " (" .. run.Format .. ") - batalha " .. (run.Index + 1) .. " de " .. mode.Battles }
		end
	end

	local ok = BattleService.StartBattle(player, {
		PlayerTeam = team,
		EnemyTeam = enemyTeamFor(run),
		EnemyAI = enemyAI,
		Format = run.Format,
		Mode = "Tower",
		Intro = intro,
		KeepPlayer = true,
		OnEnd = function(battle, result)
			return onBattleEnd(player, run, battle, result)
		end,
		OnClosed = function(result)
			if runs[player] ~= run then
				return
			end
			if result == "Win" and not run.Over then
				task.wait(1 * (Config.TimeScale or 1))
				startNext(player, run)
			else
				endRun(player, run, result ~= "Cancelled")
			end
		end,
	})
	if not ok then
		endRun(player, run, true)
	end
end

--------------------------------------------------------------------
-- Entradas publicas: Torre 1x1/2x2, Ginasio e Modo Treino
--------------------------------------------------------------------
function TowerService.StartRun(player: Player, modeId, format): (boolean, string?)
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Dados ainda carregando."
	end
	local fmt = normFormat(format)
	if typeof(modeId) ~= "string" or not Tower.Modes[modeId] then
		return false, "Modo inv\u{e1}lido."
	end
	local tSlot = towerSlot(data, fmt)
	if not Tower.IsUnlocked(tSlot.Unlocked, modeId) then
		return false, "Conclua o modo anterior (" .. fmt .. ") para desbloquear."
	end
	if runs[player] or BattleService.IsInBattle(player) then
		return false, "Voc\u{ea} j\u{e1} est\u{e1} em batalha."
	end
	local team, reason = ProgressionService.TeamFor(player)
	if not team then
		return false, reason
	end
	if fmt == "2x2" and aliveCountInTeam(team) < 2 then
		return false, "Precisa de pelo menos 2 personagens vivos no time para a Torre 2x2."
	end
	local run = { Kind = "Tower", Format = fmt, Mode = modeId, Index = 0, Floor = 1, GoldEarned = 0 }
	runs[player] = run
	menuOpen[player] = nil
	task.spawn(startNext, player, run)
	return true
end

function TowerService.StartGym(player: Player, gymId, format): (boolean, string?)
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Dados ainda carregando."
	end
	local gym = Gyms.Get(gymId)
	if not gym then
		return false, "Gin\u{e1}sio inv\u{e1}lido."
	end
	local fmt = normFormat(format)
	if runs[player] or BattleService.IsInBattle(player) then
		return false, "Voc\u{ea} j\u{e1} est\u{e1} em batalha."
	end
	local team, reason = ProgressionService.TeamFor(player)
	if not team then
		return false, reason
	end
	if fmt == "2x2" and aliveCountInTeam(team) < 2 then
		return false, "Precisa de pelo menos 2 personagens vivos no time para o Gin\u{e1}sio 2x2."
	end
	local run = { Kind = "Gym", GymId = gym.Id, Format = fmt, Index = 0 }
	runs[player] = run
	menuOpen[player] = nil
	task.spawn(startNext, player, run)
	return true
end

function TowerService.StartPractice(player: Player, opts): (boolean, string?)
	opts = if typeof(opts) == "table" then opts else {}
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Dados ainda carregando."
	end
	if runs[player] or BattleService.IsInBattle(player) then
		return false, "Voc\u{ea} j\u{e1} est\u{e1} em batalha."
	end
	local fmt = normFormat(opts.Format)
	local ai = if opts.AI == "Facil" or opts.AI == "Medio" or opts.AI == "Dificil" then opts.AI else "Medio"
	local levelMode = if opts.LevelMode == "Real" then "Real" else "Equal50"

	local playerTeam, err, avgLvl = practiceTeamFor(player, levelMode)
	if not playerTeam then
		return false, err
	end
	if fmt == "2x2" and #playerTeam < 2 then
		return false, "Precisa de pelo menos 2 personagens no time para treinar em 2x2."
	end
	local enemySize = math.clamp(math.max(if fmt == "2x2" then 2 else 1, #playerTeam), 1, 6)
	local enemyLevel = if levelMode == "Equal50" then (Config.PvPLevel or 50) else (avgLvl or 10)
	local practicePreset = if levelMode == "Equal50" then "Infinito" else ai
	local enemyTeam = npcTeam(enemySize, function()
		return enemyLevel
	end, nil, practicePreset)

	menuOpen[player] = nil
	local aiLabel = if ai == "Facil" then "F\u{e1}cil" elseif ai == "Dificil" then "Dif\u{ed}cil" else "M\u{e9}dio"
	local lvlLabel = if levelMode == "Equal50" then "N\u{ed}vel 50 (Simulador PvP)" else "N\u{ed}vel real"
	local ok = BattleService.StartBattle(player, {
		PlayerTeam = playerTeam,
		EnemyTeam = enemyTeam,
		EnemyAI = ai,
		Format = fmt,
		Mode = "Practice",
		Bag = {},
		CanFlee = true,
		NoWriteBack = true,
		Intro = {
			string.format("Modo Treino %s \u{b7} IA %s \u{b7} %s. Sem gasto de HP/PP.", fmt, aiLabel, lvlLabel),
		},
	})
	if not ok then
		return false, "Nenhuma arena livre agora. Tente novamente."
	end
	return true
end

-- Dados da tela da torre (1x1, 2x2, Ginasios e Insignias)
function TowerService.MenuInfo(player: Player, format: string?)
	local data = PlayerDataService.Get(player)
	if not data then
		return nil
	end
	local fmt = normFormat(format)
	local season = RetentionService.CurrentSeason()
	local t1 = towerSlot(data, "1x1")
	local t2 = towerSlot(data, "2x2")
	local s1 = seasonSlot(data, "1x1")
	local s2 = seasonSlot(data, "2x2")
	local curT = if fmt == "2x2" then t2 else t1
	local curS = if fmt == "2x2" then s2 else s1

	return {
		Format = fmt,
		Unlocked = curT.Unlocked,
		BestFloor = curT.BestInfiniteFloor,
		Season = season,
		SeasonBest = if curS.Id == season then curS.Best else 0,
		SeasonEnd = Retention.SeasonEnd(Clock.Now()),
		HardGemsToday = curT.LastHardRewardDay == today(),
		Tower1x1 = {
			Unlocked = t1.Unlocked,
			BestFloor = t1.BestInfiniteFloor,
			SeasonBest = if s1.Id == season then s1.Best else 0,
			HardGemsToday = t1.LastHardRewardDay == today(),
		},
		Tower2x2 = {
			Unlocked = t2.Unlocked,
			BestFloor = t2.BestInfiniteFloor,
			SeasonBest = if s2.Id == season then s2.Best else 0,
			HardGemsToday = t2.LastHardRewardDay == today(),
		},
		GymsCleared = table.clone(data.GymsCleared or {}),
		UnlockedBanners = table.clone(data.UnlockedBanners or {}),
	}
end

function TowerService.OnTrigger(player: Player)
	if runs[player] or menuOpen[player] then
		return
	end
	local info = TowerService.MenuInfo(player, "1x1")
	if not info then
		return
	end
	menuOpen[player] = true
	BattleService.RequireLeaveTrigger(player)
	Remotes.TowerOpen:FireClient(player, info)
end

function TowerService.IsRunning(player: Player): boolean
	return runs[player] ~= nil
end

function TowerService.Init()
	Remotes.TowerStart.OnServerInvoke = function(player, req, legacyFormat)
		if not menuOpen[player] then
			return false, "V\u{e1} at\u{e9} a porta da torre."
		end
		if typeof(req) == "string" then
			return TowerService.StartRun(player, req, legacyFormat)
		end
		if typeof(req) ~= "table" then
			return false, "Pedido inv\u{e1}lido."
		end
		if req.Kind == "Gym" then
			return TowerService.StartGym(player, req.GymId, req.Format)
		elseif req.Kind == "Practice" then
			return TowerService.StartPractice(player, req)
		else
			return TowerService.StartRun(player, req.Mode, req.Format)
		end
	end
	Remotes.TowerBoard.OnServerInvoke = function(player, format)
		if format == "PvP" then
			local PvPService = require(ServerScriptService:WaitForChild("Battle"):WaitForChild("PvPService"))
			return PvPService.GetLeaderboard(player)
		end
		local fmt = normFormat(format)
		return { Format = fmt, Server = serverBoard(fmt), Global = getGlobalBoard(fmt), Info = TowerService.MenuInfo(player, fmt) }
	end
	Remotes.TowerClose.OnServerEvent:Connect(function(player)
		menuOpen[player] = nil
	end)
	Players.PlayerRemoving:Connect(function(player)
		runs[player] = nil
		menuOpen[player] = nil
	end)
end

-- So para testes (ponte do Studio)
TowerService._runs = runs

return TowerService
