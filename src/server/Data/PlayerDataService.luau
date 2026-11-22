--[[
	PlayerDataService (GDD secao 10: DataStore com trava de sessao)

	Dados salvos (secao 10): colecao, time, mochila, gold, minerio, gemas, beneficios, torre,
	gemas vendidas no dia, missoes, login diario, garantia de invocacao.

	Registro no DataStore (chave "u_<UserId>"):
	  { Data = <perfil>, Lock = { Server = id, Time = os.time() } | nil, SavedAt = os.time(), Version = n }

	Protecao contra perda de dados:
	  - Trava de sessao: so o servidor dono da trava salva. Outro servidor espera a trava ser liberada;
	    trava sem renovacao ha LOCK_STALE segundos e considerada de um servidor morto e e assumida.
	    Depois de esperar LOCK_WAIT_TRIES vezes, a trava e tomada; o servidor antigo perde o direito
	    de salvar (confere a trava em todo salvamento) e expulsa o jogador sem sobrescrever.
	  - Se o carregamento falhar (DataStore fora do ar), o jogador e expulso com aviso:
	    nunca joga com perfil vazio, que apagaria o progresso ao salvar.
	  - Salvamento com UpdateAsync, novas tentativas com espera crescente, validacao dos numeros.
	  - Copia de seguranca (PlayerDataBackup) a cada saida; usada se o registro principal vier corrompido.
	  - Salvamento automatico a cada AUTOSAVE segundos, ao sair e no fechamento do servidor (BindToClose).

	Uso (servidor):
	  PlayerDataService.Get(player) -> perfil (tabela viva) ou nil se ainda nao carregou
	  PlayerDataService.WaitFor(player, timeout?) -> perfil ou nil
	  PlayerDataService.MarkChanged(player)  -- envia o perfil ao cliente
	  PlayerDataService.SaveNow(player)      -- salva ja (eventos importantes)
	  PlayerDataService.Loaded:Connect(function(player) end) -- use Get(player); o evento copia tabelas
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = ReplicatedStorage:WaitForChild("Data")
local Characters = require(Data:WaitForChild("Characters"))
local Genetics = require(Data:WaitForChild("Genetics"))
local Training = require(Data:WaitForChild("Training"))
local PvPRank = require(Data:WaitForChild("PvPRank"))

local PlayerDataService = {}
local rng = Random.new()

local STORE_NAME = "PlayerData_v1"
local BACKUP_NAME = "PlayerDataBackup_v1"
local VERSION = 1
local AUTOSAVE = 60 -- segundos
local LOCK_STALE = 600 -- trava sem renovacao ha 10 min = servidor morto
local LOCK_WAIT_TRIES = 5 -- tentativas esperando a trava antes de tomar
local LOCK_WAIT = 4 -- segundos entre tentativas
local IO_TRIES = 4 -- tentativas por chamada ao DataStore

local SERVER_ID = HttpService:GenerateGUID(false) -- JobId e vazio no Studio

local store = DataStoreService:GetDataStore(STORE_NAME)
local backup = DataStoreService:GetDataStore(BACKUP_NAME)

local profiles = {} -- [Player] = { Data, Key, Released, LostLock, Saving }
local loadedEvent = Instance.new("BindableEvent")
PlayerDataService.Loaded = loadedEvent.Event

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ProfileUpdatedRE = Remotes:WaitForChild("ProfileUpdated")

--------------------------------------------------------------------
-- Perfil padrao (todos os campos da secao 10)
--------------------------------------------------------------------
local function defaultProfile()
	return {
		Version = VERSION,
		StarterChosen = false,
		Collection = {}, -- [uid] = { Uid, CharacterId, Level, Xp, Learned = {}, Active = {}, Variant, Stars, ObtainedAt }
		NextUid = 1,
		Team = {}, -- ate 6 uids, na ordem
		Bag = {}, -- [itemId] = quantidade
		Gold = 0,
		Ore = 0, -- minerio bruto
		TrainingOres = { HP = 0, Attack = 0, Defense = 0, Speed = 0 }, -- 4 minerios de atributo para treino
		Gems = 0,
		Benefits = {}, -- [beneficio] = "Pass" (Game Pass, conferido a cada entrada) ou "Gems" (comprado com gemas)
		Receipts = {}, -- [PurchaseId] = os.time(): compras em Robux ja entregues (ProcessReceipt nao entrega 2 vezes)
		Tower = { Unlocked = "Facil", BestInfiniteFloor = 0, LastHardRewardDay = 0 },
		Tower2x2 = { Unlocked = "Facil", BestInfiniteFloor = 0, LastHardRewardDay = 0 },
		UnlockedBanners = {}, -- [animeId] = true (desbloqueado pelo inicial ou vencendo o Ginasio respectivo)
		GymsCleared = {}, -- [gymId] = true (Insignias conquistadas nos Ginasios da Torre)
		StarterTrack = { Claimed = {} }, -- trilha guiada inicial (7 passos)
		PvP = PvPRank.DefaultState(), -- patente, ELO, vitorias 1x1/2x2 e bonus diario anti-farm
		GemsSold = { Day = 0, Amount = 0 }, -- gemas vendidas no dia
		-- retorno (secao 13): Daily = { {Id, Progress, Done} }, Weekly[id] = {Progress, Done}
		Missions = { Day = 0, Daily = {}, AllDone = false, Week = 0, Weekly = {}, WeeklyDone = false },
		DailyLogin = { LastDay = 0, Streak = 0 },
		Session = { Day = 0, Seconds = 0, Claimed = {} }, -- tempo online no dia e baus abertos
		Tickets = { Comum = 0, Premium = 0 }, -- invocacoes gratis (login, missoes, codigos)
		Codes = {}, -- [codigo] = quando resgatou
		Cosmetics = {}, -- InfinitoTop = { Season, Rank }
		Season = { Id = "", Best = 0 }, -- temporada do Infinito 1x1 (mes UTC); Last = resultado da anterior
		Season2x2 = { Id = "", Best = 0 }, -- temporada do Infinito 2x2 (mes UTC)
		SummonPity = { Comum = 0, Premium = 0 }, -- garantia de invocacao
		Album = { Owned = {}, Claimed = {} }, -- [personagem] = { Variants = { Brilhante = true } }; premios ja pagos
		-- base (secao 8): Active[uid] = "Walk" | "Mine"; vagas compradas; nivel mineracao; producao pendente; ultimo calculo
		Base = {
			Active = {},
			MiningSlots = 2,
			MiningLevel = 1,
			Pending = { Gold = 0, Ore = 0, Ores = { HP = 0, Attack = 0, Defense = 0, Speed = 0 } },
			GoldCarry = 0,
			MiningProgress = 0,
			LastTick = 0,
		},
		-- maquina de treinamento (secao 8): nivel (eficiencia) e trabalho ativo na cupula
		TrainingMachine = { Level = 1, Job = nil },
		-- configuracoes do jogador (volumes de 0 a 100)
		Settings = { MusicOn = true, MusicVolume = 50, SfxOn = true, SfxVolume = 80, MapFx = true, CharacterAuras = true },
		-- Refugio (secao 14): nivel da Forja, contadores, Bau ({ {Id, Qty} }), selvagens pendentes e ultimo surgimento
		Refuge = { Forja = 1, WildDefeated = 0, Captures = 0, Bau = {}, Pending = {}, LastSpawn = 0, NextId = 1 },
		CreatedAt = os.time(),
	}
end

-- Preenche campos que faltam (perfis antigos ganham campos novos sem perder nada)
local function reconcile(data, template)
	for k, v in pairs(template) do
		if data[k] == nil then
			data[k] = if typeof(v) == "table" then table.clone(v) else v
		elseif typeof(v) == "table" and typeof(data[k]) == "table" and next(v) ~= nil then
			reconcile(data[k], v)
		end
	end
	return data
end

local function migrate(data)
	-- Substitui o prototipo ProtoLendario (Satoru) pelo personagem oficial Setero
	if typeof(data.Collection) == "table" then
		for _, m in pairs(data.Collection) do
			if m.CharacterId == "ProtoLendario" then
				m.CharacterId = "Setero"
				if m.Name == "Satoru" or not m.Name then
					m.Name = "Setero"
				end
				m.Learned = { "Atracao", "SocoDireto", "TudoRoxo", "PosturaDeCombate" }
				m.Active = { "TudoRoxo", "Atracao", "SocoDireto", "PosturaDeCombate" }
			end
		end
	end
	if typeof(data.Album) == "table" and typeof(data.Album.Owned) == "table" and data.Album.Owned.ProtoLendario then
		data.Album.Owned.Setero = data.Album.Owned.Setero or data.Album.Owned.ProtoLendario
		data.Album.Owned.ProtoLendario = nil
	end
	data.Version = VERSION
	return data
end

-- Numeros validos e nao negativos; evita salvar NaN ou infinito
local function cleanNumber(v, max)
	if typeof(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
		return 0
	end
	return math.clamp(math.floor(v), 0, max or 1e12)
end

local function sanitize(data)
	data.Gold = cleanNumber(data.Gold)
	data.Gems = cleanNumber(data.Gems)
	data.Ore = cleanNumber(data.Ore)
	data.TrainingOres = Training.SanitizeOres(data.TrainingOres, Training.MaxOrePerType)
	if typeof(data.Base) == "table" then
		data.Base.MiningSlots = math.clamp(math.max(2, cleanNumber(data.Base.MiningSlots, 6)), 2, 6)
		data.Base.MiningLevel = math.clamp(math.max(1, cleanNumber(data.Base.MiningLevel, 10)), 1, 10)
		data.Base.MiningProgress = if typeof(data.Base.MiningProgress) == "number" and data.Base.MiningProgress == data.Base.MiningProgress then math.max(0, data.Base.MiningProgress) else 0
		data.Base.GoldCarry = if typeof(data.Base.GoldCarry) == "number" and data.Base.GoldCarry == data.Base.GoldCarry then math.clamp(data.Base.GoldCarry, 0, 1000) else 0
		if typeof(data.Base.Pending) ~= "table" then
			data.Base.Pending = { Gold = 0, Ore = 0, Ores = Training.ZeroOres() }
		else
			data.Base.Pending.Gold = math.max(0, tonumber(data.Base.Pending.Gold) or 0)
			data.Base.Pending.Ore = math.max(0, tonumber(data.Base.Pending.Ore) or 0)
			data.Base.Pending.Ores = Training.SanitizeOres(data.Base.Pending.Ores, Training.MaxOrePerType)
		end
	end
	if typeof(data.TrainingMachine) ~= "table" then
		data.TrainingMachine = { Level = 1, Job = nil }
	else
		data.TrainingMachine.Level = math.clamp(math.max(1, cleanNumber(data.TrainingMachine.Level, Training.MaxLevel)), 1, Training.MaxLevel)
		local job = data.TrainingMachine.Job
		if typeof(job) ~= "table" or typeof(job.Uid) ~= "string" or not data.Collection[job.Uid] then
			data.TrainingMachine.Job = nil
		else
			job.Targets = Training.SanitizeOres(job.Targets, Training.Max)
			job.Cost = Training.SanitizeOres(job.Cost, Training.MaxOrePerType)
			job.StartedAt = cleanNumber(job.StartedAt, 1e10)
			job.EndsAt = cleanNumber(job.EndsAt, 1e10)
			job.Duration = math.max(1, cleanNumber(job.Duration, 86400))
		end
	end
	for id, n in pairs(data.Bag) do
		data.Bag[id] = cleanNumber(n, 99)
		if data.Bag[id] == 0 then
			data.Bag[id] = nil
		end
	end
	for _, m in pairs(data.Collection) do
		m.Level = math.clamp(cleanNumber(m.Level), 1, 50)
		m.Xp = cleanNumber(m.Xp)
		local def = Characters.Get(m.CharacterId)
		if typeof(m.Genetics) ~= "table" then
			m.Genetics = Genetics.Roll(def and def.Rarity or "Comum", rng)
		else
			if not Genetics.HasAllKeys(m.Genetics) then
				local rolled = Genetics.Roll(def and def.Rarity or "Comum", rng)
				for _, stat in ipairs(Genetics.Stats) do
					if typeof(m.Genetics[stat]) ~= "number" then
						m.Genetics[stat] = rolled[stat]
					end
				end
			end
			m.Genetics = Genetics.SanitizeTable(m.Genetics)
		end
		if typeof(m.Training) ~= "table" then
			m.Training = Genetics.ZeroTable()
		else
			m.Training = Genetics.SanitizeTable(m.Training)
		end
	end
	local r = data.Refuge
	if typeof(r) == "table" then
		r.Forja = math.clamp(cleanNumber(r.Forja), 1, 10)
		r.WildDefeated = cleanNumber(r.WildDefeated)
		r.Captures = cleanNumber(r.Captures)
		r.LastSpawn = cleanNumber(r.LastSpawn, 1e10)
		r.NextId = math.max(1, cleanNumber(r.NextId))
		if typeof(r.Pending) == "table" then
			for _, e in ipairs(r.Pending) do
				if typeof(e) == "table" and not Genetics.HasAllKeys(e.Genetics) then
					local eDef = Characters.Get(e.CharacterId)
					e.Genetics = Genetics.Roll(eDef and eDef.Rarity or e.Rarity or "Comum", rng)
				end
			end
		end
	end
	if typeof(data.Tower2x2) ~= "table" then
		data.Tower2x2 = { Unlocked = "Facil", BestInfiniteFloor = 0, LastHardRewardDay = 0 }
	else
		data.Tower2x2.BestInfiniteFloor = cleanNumber(data.Tower2x2.BestInfiniteFloor, 1e6)
		data.Tower2x2.LastHardRewardDay = cleanNumber(data.Tower2x2.LastHardRewardDay, 1e6)
	end
	if typeof(data.Season2x2) ~= "table" then
		data.Season2x2 = { Id = "", Best = 0 }
	else
		data.Season2x2.Best = cleanNumber(data.Season2x2.Best, 1e6)
	end
	if typeof(data.UnlockedBanners) ~= "table" then
		data.UnlockedBanners = {}
	end
	if typeof(data.GymsCleared) ~= "table" then
		data.GymsCleared = {}
	end
	if typeof(data.StarterTrack) ~= "table" then
		data.StarterTrack = { Claimed = {} }
	elseif typeof(data.StarterTrack.Claimed) ~= "table" then
		data.StarterTrack.Claimed = {}
	end
	if typeof(data.PvP) ~= "table" then
		data.PvP = PvPRank.DefaultState()
	else
		local p = data.PvP
		p.Rating = math.clamp(cleanNumber(if typeof(p.Rating) == "number" then p.Rating else PvPRank.StartRating, PvPRank.MaxRating), PvPRank.MinRating, PvPRank.MaxRating)
		p.BestRating = math.max(p.Rating, math.clamp(cleanNumber(if typeof(p.BestRating) == "number" then p.BestRating else p.Rating, PvPRank.MaxRating), PvPRank.MinRating, PvPRank.MaxRating))
		p.Wins = cleanNumber(p.Wins, 1e6)
		p.Losses = cleanNumber(p.Losses, 1e6)
		p.Wins2x2 = cleanNumber(p.Wins2x2, 1e6)
		p.Losses2x2 = cleanNumber(p.Losses2x2, 1e6)
		p.DailyDay = cleanNumber(p.DailyDay, 1e6)
		p.DailyRewards = cleanNumber(p.DailyRewards, PvPRank.DailyRewardCap)
		if typeof(p.OpponentsToday) ~= "table" then
			p.OpponentsToday = {}
		end
	end
	return data
end

local function isValidProfile(data)
	return typeof(data) == "table" and typeof(data.Collection) == "table" and typeof(data.Team) == "table"
end

--------------------------------------------------------------------
-- DataStore com novas tentativas
--------------------------------------------------------------------
local function withRetry(fn)
	local lastErr
	for attempt = 1, IO_TRIES do
		local ok, a, b = pcall(fn)
		if ok then
			return true, a, b
		end
		lastErr = a
		warn("[PlayerData] Tentativa " .. attempt .. " falhou: " .. tostring(a))
		task.wait(2 ^ (attempt - 1)) -- 1, 2, 4, 8 s
	end
	return false, lastErr
end

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

-- Carrega e trava. Retorna o perfil ou nil + motivo.
local function loadProfile(player: Player)
	local key = keyFor(player)
	for tryLock = 1, LOCK_WAIT_TRIES + 1 do
		local force = tryLock > LOCK_WAIT_TRIES
		local lockedByOther = false
		local ok, record = withRetry(function()
			return store:UpdateAsync(key, function(old)
				old = if typeof(old) == "table" then old else {}
				local lock = old.Lock
				if lock and lock.Server ~= SERVER_ID and not force and os.time() - (lock.Time or 0) < LOCK_STALE then
					lockedByOther = true
					return nil -- cancela: outro servidor ainda tem a trava
				end
				old.Lock = { Server = SERVER_ID, Time = os.time() }
				return old
			end)
		end)
		if not ok then
			return nil, "DataStore indispon\u{ed}vel"
		end
		if not player.Parent then
			return nil, "saiu"
		end
		if record then
			local data = record.Data
			if data ~= nil and not isValidProfile(data) then
				warn("[PlayerData] Registro corrompido de " .. player.Name .. "; usando a copia de seguranca")
				local okB, saved = withRetry(function()
					return backup:GetAsync(key)
				end)
				data = if okB and typeof(saved) == "table" and isValidProfile(saved.Data) then saved.Data else nil
				if data == nil then
					return nil, "dados corrompidos"
				end
			end
			data = migrate(reconcile(data or defaultProfile(), defaultProfile()))
			return data
		end
		if lockedByOther then
			warn("[PlayerData] Perfil de " .. player.Name .. " travado por outro servidor; esperando (" .. tryLock .. ")")
			task.wait(LOCK_WAIT)
		end
	end
	return nil, "trava"
end

-- Salva. release = libera a trava (saida). Retorna true se salvou.
local function saveProfile(player: Player, release: boolean)
	local p = profiles[player]
	if not p or p.LostLock or p.Released then
		return false
	end
	while p.Saving do
		task.wait(0.1)
	end
	if p.Released then
		return false
	end
	p.Saving = true
	local data = sanitize(p.Data)
	local lost = false
	local ok, err = withRetry(function()
		return store:UpdateAsync(p.Key, function(old)
			old = if typeof(old) == "table" then old else {}
			if old.Lock and old.Lock.Server ~= SERVER_ID then
				lost = true
				return nil -- outro servidor tomou a trava: nao sobrescreve
			end
			old.Data = data
			old.Version = VERSION
			old.SavedAt = os.time()
			old.Lock = if release then nil else { Server = SERVER_ID, Time = os.time() }
			return old
		end)
	end)
	p.Saving = false
	if lost then
		p.LostLock = true
		warn("[PlayerData] " .. player.Name .. " abriu outra sessao; este servidor parou de salvar")
		if player.Parent then
			player:Kick("Sua conta foi aberta em outro servidor.")
		end
		return false
	end
	if not ok then
		warn("[PlayerData] Falha ao salvar " .. player.Name .. ": " .. tostring(err))
		return false
	end
	if release then
		p.Released = true
		-- copia de seguranca do ultimo estado bom
		pcall(function()
			backup:SetAsync(p.Key, { Data = data, SavedAt = os.time() })
		end)
	end
	return true
end

--------------------------------------------------------------------
-- API
--------------------------------------------------------------------
function PlayerDataService.Get(player: Player)
	local p = profiles[player]
	return p and not p.Released and p.Data or nil
end

function PlayerDataService.WaitFor(player: Player, timeout: number?)
	local t0 = os.clock()
	while player.Parent and os.clock() - t0 < (timeout or 30) do
		local data = PlayerDataService.Get(player)
		if data then
			return data
		end
		task.wait(0.1)
	end
	return nil
end

-- Copia do perfil para o cliente (sem nada interno)
function PlayerDataService.PublicView(player: Player)
	local data = PlayerDataService.Get(player)
	if not data then
		return nil
	end
	return data
end

local changedListeners = {} -- { function(player) }

function PlayerDataService.OnChanged(fn: (Player) -> ())
	table.insert(changedListeners, fn)
end

function PlayerDataService.MarkChanged(player: Player)
	local view = PlayerDataService.PublicView(player)
	if view then
		ProfileUpdatedRE:FireClient(player, view)
		for _, fn in ipairs(changedListeners) do
			task.spawn(fn, player)
		end
	end
end

function PlayerDataService.SaveNow(player: Player): boolean
	return saveProfile(player, false)
end

function PlayerDataService.NewUid(player: Player): string
	local data = assert(PlayerDataService.Get(player), "Perfil nao carregado")
	local uid = "c" .. data.NextUid
	data.NextUid += 1
	return uid
end

local function onPlayerAdded(player: Player)
	local data, reason = loadProfile(player)
	if not player.Parent then
		-- saiu durante o carregamento: libera a trava que acabamos de pegar
		if data then
			profiles[player] = { Data = data, Key = keyFor(player) }
			saveProfile(player, true)
			profiles[player] = nil
		end
		return
	end
	if not data then
		warn("[PlayerData] Nao carregou " .. player.Name .. ": " .. tostring(reason))
		player:Kick("N\u{e3}o foi poss\u{ed}vel carregar seus dados (" .. tostring(reason) .. "). Seu progresso est\u{e1} seguro; entre de novo em instantes.")
		return
	end
	profiles[player] = { Data = data, Key = keyFor(player) }
	loadedEvent:Fire(player, data)
	PlayerDataService.MarkChanged(player)
end

local function onPlayerRemoving(player: Player)
	if profiles[player] then
		saveProfile(player, true)
		profiles[player] = nil
	end
end

function PlayerDataService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, p)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Salvamento automatico (escalonado para nao estourar o limite do DataStore)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE)
			for player in pairs(profiles) do
				if player.Parent then
					task.spawn(saveProfile, player, false)
					task.wait(0.5)
				end
			end
		end
	end)

	-- Fechamento do servidor: salva e libera todos
	game:BindToClose(function()
		local pending = 0
		for player in pairs(profiles) do
			pending += 1
			task.spawn(function()
				saveProfile(player, true)
				pending -= 1
			end)
		end
		local t0 = os.clock()
		while pending > 0 and os.clock() - t0 < 25 do
			task.wait(0.1)
		end
	end)
end

return PlayerDataService
