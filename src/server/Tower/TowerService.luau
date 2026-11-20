--[[
	TowerService (GDD secao 6)
	- Menu da torre ao entrar no gatilho; desbloqueio em sequencia Facil > Medio > Dificil > Infinito.
	- Corrida = batalhas em sequencia com o time salvo. HP, status e PP passam de uma batalha
	  para a outra (sem cura no Facil, Medio e Dificil); no Infinito recupera 30% do HP entre andares.
	- Times de NPC sorteados do elenco (Data/Characters), nivel e IA conforme o modo.
	- Recompensas: gold, itens, gemas do Dificil 1 vez por dia; Infinito paga por andar, bonus a cada 5,
	  chefe a cada 5 andares (+20% de atributos) que pode entregar o personagem.
	- Derrota encerra a corrida; o gold ja ganho fica.
	- Placar do Infinito: servidor (jogadores presentes) e global (OrderedDataStore).
	- Temporada (secao 13): o placar e da temporada do mes (RetentionService); o recorde geral continua no perfil.
	- Fim de semana com 2x gold: dobra o gold da torre.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")

local Data = ReplicatedStorage:WaitForChild("Data")
local Characters = require(Data.Characters)
local Tower = require(Data.Tower)
local Items = require(Data.Items)
local Progression = require(Data.Progression)
local Benefits = require(Data.Benefits)
local Genetics = require(Data:WaitForChild("Genetics"))

local BattleService = require(ServerScriptService:WaitForChild("Battle"):WaitForChild("BattleService"))
local Config = require(ServerScriptService.Battle:WaitForChild("BattleConfig"))
local PlayerDataService = require(ServerScriptService:WaitForChild("Data"):WaitForChild("PlayerDataService"))
local ProgressionService = require(ServerScriptService.Data:WaitForChild("ProgressionService"))
local RetentionService = require(ServerScriptService.Data:WaitForChild("RetentionService"))
local Clock = require(ServerScriptService.Data:WaitForChild("Clock"))
local Retention = require(Data:WaitForChild("Retention"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local TowerService = {}

local BAG_SLOTS = 30
local STACK = 99
local GLOBAL_CACHE_TIME = 60

local runs = {} -- [Player] = corrida
local menuOpen = {} -- [Player] = true
local rng = Random.new()

local globalCache = { Time = -math.huge, List = {}, Season = "" }
local nameCache = {}

local function today(): number
	return os.time() // 86400 -- dia UTC
end

--------------------------------------------------------------------
-- Placar
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

local function serverBoard()
	local list = {}
	local season = RetentionService.CurrentSeason()
	for _, p in ipairs(Players:GetPlayers()) do
		local data = PlayerDataService.Get(p)
		if data and data.Season.Id == season and data.Season.Best > 0 then
			table.insert(list, { Name = p.Name, Floor = data.Season.Best })
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

local function getGlobalBoard()
	local season = RetentionService.CurrentSeason()
	if globalCache.Season == season and os.clock() - globalCache.Time < GLOBAL_CACHE_TIME then
		return globalCache.List
	end
	if globalCache.Season ~= season then
		globalCache.List = {}
	end
	globalCache.Season = season
	globalCache.Time = os.clock()
	local globalBoard = RetentionService.SeasonStore(season)
	local ok, pages = pcall(globalBoard.GetSortedAsync, globalBoard, false, Tower.LeaderboardSize)
	if ok then
		local list = {}
		for _, entry in ipairs(pages:GetCurrentPage()) do
			local userId = tonumber(entry.key)
			if userId then
				table.insert(list, { Name = nameOf(userId), Floor = entry.value })
			end
		end
		globalCache.List = list
	else
		warn("[Tower] Placar global indispon\u{ed}vel: " .. tostring(pages))
	end
	return globalCache.List
end

-- Placar da temporada: o envio fica no RetentionService
local function submitSeason(player: Player, floor: number): boolean
	local record = RetentionService.OnInfiniteFloor(player, floor)
	if record then
		globalCache.Time = -math.huge
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
-- Times
--------------------------------------------------------------------
local function roster(): { string }
	local list = {}
	for id, def in pairs(Characters.List) do
		if not def.Prototype then -- prototipos de teste fora dos times da torre
			table.insert(list, id)
		end
	end
	table.sort(list)
	return list
end

-- Time de NPC sorteado do elenco (sem repetir enquanto houver personagem diferente)
local function npcTeam(size: number, levelFn, extra)
	local pool = roster()
	local bag = {}
	local team = {}
	local towerGen, towerTrain = Genetics.TowerEnemyPreset()
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

local function enemyTeamFor(run)
	local mode = Tower.Modes[run.Mode]
	if run.Mode == "Infinito" then
		local floor = run.Floor
		local level = Tower.FloorLevel(floor)
		return npcTeam(mode.TeamSize, function()
			return level
		end, { StatMultiplier = Tower.FloorStatMultiplier(floor) })
	end
	return npcTeam(mode.TeamSize, function()
		return rng:NextInteger(mode.MinLevel, mode.MaxLevel)
	end)
end

-- Time do jogador: HP, status, PP e mochila ficam salvos no perfil entre as batalhas
-- (ProgressionService.WriteBack no fim de cada batalha), entao nao ha cura no Facil, Medio e Dificil.
local function playerTeamFor(player: Player, run)
	return ProgressionService.TeamFor(player)
end

--------------------------------------------------------------------
-- Corrida
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

-- Recompensa ao concluir Facil, Medio ou Dificil
local function completeMode(player: Player, run, lines)
	local data = PlayerDataService.Get(player)
	local mode = Tower.Modes[run.Mode]
	local gold = eventGold(mode.Reward.Gold, lines)
	data.Gold += gold
	table.insert(lines, "Torre " .. mode.Name .. " conclu\u{ed}da! +" .. gold .. " gold.")
	for _, itemId in ipairs(mode.Reward.Items) do
		if addItem(data, itemId, 1) then
			table.insert(lines, "Recebeu " .. Items.Get(itemId).Name .. ".")
		else
			table.insert(lines, "Mochila cheia: " .. Items.Get(itemId).Name .. " ficou de fora.")
		end
	end
	if mode.Reward.DailyGems then
		if data.Tower.LastHardRewardDay ~= today() then
			data.Tower.LastHardRewardDay = today()
			data.Gems += mode.Reward.DailyGems
			table.insert(lines, "+" .. mode.Reward.DailyGems .. " gemas (limite di\u{e1}rio).")
		else
			table.insert(lines, "As gemas do Dif\u{ed}cil j\u{e1} foram recebidas hoje.")
		end
	end
	local nextMode = Tower.NextMode(run.Mode)
	if nextMode and Tower.Index(nextMode) > Tower.Index(data.Tower.Unlocked) then
		data.Tower.Unlocked = nextMode
		table.insert(lines, "Modo " .. Tower.Modes[nextMode].Name .. " desbloqueado!")
	end
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
	local mode = Tower.Modes[run.Mode]
	if result ~= "Win" then
		run.Over = true
		if run.Mode == "Infinito" then
			table.insert(lines, "A corrida terminou no andar " .. run.Floor .. ". Gold ganho: " .. run.GoldEarned .. ".")
		else
			table.insert(lines, "A corrida terminou na batalha " .. run.Index .. " de " .. mode.Battles .. ".")
		end
		return lines
	end

	if run.Mode == "Infinito" then
		local floor = run.Floor
		local gold = eventGold(Tower.FloorGold(floor), lines)
		data.Gold += gold
		run.GoldEarned += gold
		table.insert(lines, "Andar " .. floor .. " vencido! +" .. gold .. " gold.")
		if floor > data.Tower.BestInfiniteFloor then
			data.Tower.BestInfiniteFloor = floor
			table.insert(lines, "Novo recorde: andar " .. floor .. ".")
		end
		if submitSeason(player, floor) then
			table.insert(lines, "Recorde da temporada: andar " .. floor .. ".")
		end
		if Tower.IsBossFloor(floor) then
			local chance = Tower.BossDropChance(floor)
			if rng:NextNumber() < chance then
				local boss = battle.Sides.Enemy.Team[1]
				if Benefits.CollectionCount(data) >= Benefits.CollectionMax(data) then
					table.insert(lines, "O chefe " .. boss.Name .. " queria se juntar, mas o dep\u{f3}sito de personagens est\u{e1} cheio (" .. Benefits.CollectionMax(data) .. ").")
				else
					local toTeam = #data.Team < 6
					ProgressionService.AddCharacter(player, boss.Id, boss.Level, toTeam)
					table.insert(lines, "O chefe " .. boss.Name .. " se juntou a voc\u{ea}!")
				end
			end
		end
		-- recupera 30% do HP entre andares (time salvo)
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
	local mode = Tower.Modes[run.Mode]
	local team = playerTeamFor(player, run)
	if not team then
		endRun(player, run, true)
		return
	end
	local intro
	if run.Mode == "Infinito" then
		intro = { "Torre Infinito - andar " .. run.Floor .. (if Tower.IsBossFloor(run.Floor) then " - CHEFE!" else "") .. " (n\u{ed}vel " .. Tower.FloorLevel(run.Floor) .. ")" }
	else
		intro = { "Torre " .. mode.Name .. " - batalha " .. (run.Index + 1) .. " de " .. mode.Battles }
	end
	local ok = BattleService.StartBattle(player, {
		PlayerTeam = team,
		EnemyTeam = enemyTeamFor(run),
		EnemyAI = mode.AI,
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

function TowerService.StartRun(player: Player, modeId): (boolean, string?)
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Dados ainda carregando."
	end
	if typeof(modeId) ~= "string" or not Tower.Modes[modeId] then
		return false, "Modo inv\u{e1}lido."
	end
	if not Tower.IsUnlocked(data.Tower.Unlocked, modeId) then
		return false, "Conclua o modo anterior para desbloquear."
	end
	if runs[player] or BattleService.IsInBattle(player) then
		return false, "Voc\u{ea} j\u{e1} est\u{e1} na torre."
	end
	local team, reason = ProgressionService.TeamFor(player)
	if not team then
		return false, reason
	end
	local run = { Mode = modeId, Index = 0, Floor = 1, GoldEarned = 0 }
	runs[player] = run
	menuOpen[player] = nil
	task.spawn(startNext, player, run)
	return true
end

-- Dados da tela da torre
function TowerService.MenuInfo(player: Player)
	local data = PlayerDataService.Get(player)
	if not data then
		return nil
	end
	return {
		Unlocked = data.Tower.Unlocked,
		BestFloor = data.Tower.BestInfiniteFloor,
		Season = RetentionService.CurrentSeason(),
		SeasonBest = if data.Season.Id == RetentionService.CurrentSeason() then data.Season.Best else 0,
		SeasonEnd = Retention.SeasonEnd(Clock.Now()),
		HardGemsToday = data.Tower.LastHardRewardDay == today(),
	}
end

function TowerService.OnTrigger(player: Player)
	if runs[player] or menuOpen[player] then
		return
	end
	local info = TowerService.MenuInfo(player)
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
	Remotes.TowerStart.OnServerInvoke = function(player, modeId)
		-- seguranca: so quem abriu a tela pela porta da torre
		if not menuOpen[player] then
			return false, "V\u{e1} at\u{e9} a porta da torre."
		end
		return TowerService.StartRun(player, modeId)
	end
	Remotes.TowerBoard.OnServerInvoke = function(player)
		return { Server = serverBoard(), Global = getGlobalBoard(), Info = TowerService.MenuInfo(player) }
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
