--[[
	RaidService (Camada 3 - Server): Orquestrador da Raid Global Cooperativa 4x1.
	- Sincroniza o relogio global UTC (Data/Raids) via Data/Clock e atualiza o Monolito 3D na Praca.
	- Gerencia Lobbies (1 a 4 jogadores, contagem de 30s ou "Iniciar Agora", escolha de 1 lutador).
	- Aloca Arenas de Raid dedicadas (Workspace.Arenas.RaidArena01..03), instancia 4 Aliados + 1 Boss gigante
	  com aura minimalista 100% particulas, executa turnos via Core/RaidEngine (timer 20s, IA em desconexao).
	- Entrega recompensas garantidas (Gold, XP de Conta, XP de Personagem, Minerios de Treino + bonus MVP +25%,
	  SEM Gemas e SEM Materiais de Despertar) 1x por janela horaria UTC.
	- Executa Captura Pos-Raid consumindo Selo real da mochila (5* e 6* exigem SeloSuperior; Sukuna 6* = 1%).
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Data = ReplicatedStorage:WaitForChild("Data")
local Raids = require(Data:WaitForChild("Raids"))
local Characters = require(Data:WaitForChild("Characters"))
local Moves = require(Data:WaitForChild("Moves"))
local Progression = require(Data:WaitForChild("Progression"))
local Training = require(Data:WaitForChild("Training"))
local Benefits = require(Data:WaitForChild("Benefits"))
local Items = require(Data:WaitForChild("Items"))
local VariantController = require(ReplicatedStorage:WaitForChild("VariantController"))

local Core = ReplicatedStorage:WaitForChild("Core")
local RaidEngine = require(Core:WaitForChild("RaidEngine"))

local DataSvc = ServerScriptService:WaitForChild("Data")
local PlayerDataService = require(DataSvc:WaitForChild("PlayerDataService"))
local AccountLevelService = require(DataSvc:WaitForChild("AccountLevelService"))
local ProgressionService = require(DataSvc:WaitForChild("ProgressionService"))
local Clock = require(DataSvc:WaitForChild("Clock"))

local BattleFolder = ServerScriptService:WaitForChild("Battle")
local BattleService = require(BattleFolder:WaitForChild("BattleService"))
local ArenaManager = require(BattleFolder:WaitForChild("ArenaManager"))
local CharacterLibrary = require(ServerScriptService:WaitForChild("CharacterLibrary"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RaidStateRE = Remotes:WaitForChild("RaidState") :: RemoteEvent
local RaidActionRF = Remotes:WaitForChild("RaidAction") :: RemoteFunction

local RaidService = {}

local rng = Random.new()
local initialized = false
local devOverride: { [string]: any }? = nil
local lastAnnouncedSlotKey: string? = nil

local nextLobbyId = 1
local lobbies = {} -- [lobbyId] = lobby
local playerLobby = {} -- [Player] = lobby

local nextRaidId = 1
local activeRaids = {} -- [raidId] = raidSession
local playerRaid = {} -- [Player] = raidSession

local function currentRaidState()
	return Raids.StateAt(Clock.Now(), devOverride)
end

function RaidService.IsInRaid(player: Player): boolean
	return playerRaid[player] ~= nil or playerLobby[player] ~= nil
end

function RaidService.IsInRaidBattle(player: Player): boolean
	return playerRaid[player] ~= nil
end

local function isBusyOutsideRaid(player: Player): boolean
	return BattleService.IsInStandardBattle(player)
end

local function ensureRaidProfile(data)
	if typeof(data.Raid) ~= "table" then
		data.Raid = { ClaimedSlots = {}, Wins = 0 }
	end
	if typeof(data.Raid.ClaimedSlots) ~= "table" then
		data.Raid.ClaimedSlots = {}
	end
	if typeof(data.Raid.Wins) ~= "number" then
		data.Raid.Wins = 0
	end
	return data.Raid
end

local function hasClaimedSlot(data, slotKey: string): boolean
	if not data or slotKey == "" then
		return false
	end
	local r = data.Raid
	return typeof(r) == "table" and typeof(r.ClaimedSlots) == "table" and r.ClaimedSlots[slotKey] ~= nil
end

local function markClaimedSlot(data, slotKey: string)
	local r = ensureRaidProfile(data)
	r.ClaimedSlots[slotKey] = os.time()
	r.Wins = (r.Wins or 0) + 1
	-- Mantem apenas os ultimos 24 registros no DataStore
	local keys = {}
	for k, ts in pairs(r.ClaimedSlots) do
		table.insert(keys, { Key = k, Ts = tonumber(ts) or 0 })
	end
	if #keys > 24 then
		table.sort(keys, function(a, b)
			return a.Ts > b.Ts
		end)
		for i = 25, #keys do
			r.ClaimedSlots[keys[i].Key] = nil
		end
	end
end

local function bagSeals(data)
	local bag = (data and data.Bag) or {}
	return {
		SeloContrato = bag.SeloContrato or 0,
		SeloSuperior = bag.SeloSuperior or 0,
	}
end

local function pickDefaultFighterUid(data): string?
	if not data or typeof(data.Collection) ~= "table" then
		return nil
	end
	for _, uid in ipairs(data.Team or {}) do
		if data.Collection[uid] then
			return uid
		end
	end
	local bestUid, bestLv = nil, -1
	for uid, m in pairs(data.Collection) do
		local lv = tonumber(m.Level) or 1
		if lv > bestLv then
			bestLv = lv
			bestUid = uid
		end
	end
	return bestUid
end

local function serializeMember(m)
	local def = Characters.Get(m.CharacterId)
	return {
		UserId = m.Player.UserId,
		PlayerName = if #m.Player.DisplayName > 0 then m.Player.DisplayName else m.Player.Name,
		Uid = m.Uid,
		CharacterId = m.CharacterId,
		CharacterName = def and def.Name or m.CharacterId,
		Type = def and def.Type or "Lutador",
		Level = m.Level,
		Stars = m.Stars or 0,
		Awakened = m.Awakened == true,
		Variant = m.Variant,
		IsLeader = false,
	}
end

local function serializeLobby(lobby)
	local list = {}
	for i, m in ipairs(lobby.Members) do
		local entry = serializeMember(m)
		entry.Slot = i
		entry.IsLeader = (m.Player.UserId == lobby.LeaderUserId)
		table.insert(list, entry)
	end
	return {
		LobbyId = lobby.Id,
		SlotKey = lobby.SlotKey,
		Stars = lobby.Stars,
		BossId = lobby.BossId,
		LeaderUserId = lobby.LeaderUserId,
		CountdownLeft = math.max(0, math.ceil(lobby.CountdownEndsAt - os.clock())),
		Members = list,
	}
end

local function buildGlobalPayload(player: Player?)
	local st = currentRaidState()
	local bossDef = Characters.Get(st.BossId)
	local data = if player then PlayerDataService.Get(player) else nil
	local myLobby = if player then playerLobby[player] else nil
	local openLobbiesCount = 0
	for _ in pairs(lobbies) do
		openLobbiesCount += 1
	end
	return {
		Open = st.Open,
		SlotId = st.SlotId,
		SlotKey = st.SlotKey,
		Stars = st.Stars,
		TierName = st.Tier.Name,
		TierShort = st.Tier.Short,
		RecommendedLevel = st.Tier.RecommendedLevel,
		BossId = st.BossId,
		BossName = bossDef and bossDef.Name or st.BossId,
		BossType = bossDef and bossDef.Type or "Lutador",
		BossRarity = bossDef and bossDef.Rarity or "Epico",
		BossLevel = st.Tier.Level,
		ClosesIn = st.ClosesIn,
		NextOpenIn = st.NextOpenIn,
		SuperiorOnly = st.Tier.Capture.SuperiorOnly == true,
		Rewards = st.Tier.Rewards,
		Capture = st.Tier.Capture,
		Claimed = if data then hasClaimedSlot(data, st.SlotKey) else false,
		Seals = bagSeals(data),
		OpenLobbies = openLobbiesCount,
		Lobby = if myLobby then serializeLobby(myLobby) else nil,
		InRaidBattle = if player then (playerRaid[player] ~= nil) else false,
	}
end

local function broadcastLobby(lobby)
	local snap = serializeLobby(lobby)
	for _, m in ipairs(lobby.Members) do
		if m.Player.Parent then
			RaidStateRE:FireClient(m.Player, "LobbyUpdate", snap)
		end
	end
end

--------------------------------------------------------------------
-- Visual do Monolito 3D na Praca (cor da estrela + status ao vivo)
--------------------------------------------------------------------
local function fmtMmSs(secs: number): string
	secs = math.max(0, math.floor(secs))
	return string.format("%02d:%02d", secs // 60, secs % 60)
end

local function updateMonolithVisuals(st)
	local map = workspace:FindFirstChild("Map")
	local mono = map and map:FindFirstChild("RaidMonolith")
	if not mono then
		return
	end
	local mainCol = if st.Open then (if st.Stars == 6 then st.Tier.AccentColor else st.Tier.Color) else Color3.fromRGB(95, 110, 165)
	local accentCol = if st.Open then st.Tier.AccentColor else Color3.fromRGB(145, 165, 220)

	local ring = mono:FindFirstChild("AccentRing")
	if ring and ring:IsA("BasePart") then
		ring.Color = mainCol
	end
	for i = 1, 4 do
		local rune = mono:FindFirstChild("PillarRune_" .. i)
		if rune and rune:IsA("BasePart") then
			rune.Color = mainCol
		end
	end
	local core = mono:FindFirstChild("RiftCore")
	if core and core:IsA("BasePart") then
		core.Color = mainCol
		local light = core:FindFirstChild("RiftLight")
		if light and light:IsA("PointLight") then
			light.Color = mainCol
			light.Brightness = if st.Open then 3.2 else 1.2
		end
		local att = core:FindFirstChild("BeaconAttachment")
		if att then
			local stream = att:FindFirstChild("BeaconStream")
			if stream and stream:IsA("ParticleEmitter") then
				stream.Color = ColorSequence.new(mainCol, accentCol)
				stream.Rate = if st.Open then (if st.Stars == 6 then 28 else 20) else 5
			end
			local sparks = att:FindFirstChild("BeaconSparks")
			if sparks and sparks:IsA("ParticleEmitter") then
				sparks.Color = ColorSequence.new(accentCol)
				sparks.Rate = if st.Open then 18 else 4
			end
		end
	end

	local signAnchor = mono:FindFirstChild("SignAnchor")
	local bb = signAnchor and signAnchor:FindFirstChild("RaidSign")
	if bb then
		local title = bb:FindFirstChild("Title")
		local sub = bb:FindFirstChild("Sub")
		local bossDef = Characters.Get(st.BossId)
		local bossName = bossDef and bossDef.Name or st.BossId
		if title and title:IsA("TextLabel") then
			title.Text = if st.Open then string.format("RAID %d ESTRELAS: %s", st.Stars, string.upper(bossName)) else "FENDA DE RAID GLOBAL"
			title.TextColor3 = if st.Open then accentCol else Color3.fromRGB(255, 215, 75)
		end
		if sub and sub:IsA("TextLabel") then
			if st.Open then
				sub.Text = "ABERTA! Fecha em " .. fmtMmSs(st.ClosesIn)
				sub.TextColor3 = Color3.fromRGB(130, 255, 168)
			else
				sub.Text = string.format("Pr\u{f3}xima (%d Estrelas - %s) em %s", st.Stars, bossName, fmtMmSs(st.NextOpenIn))
				sub.TextColor3 = Color3.fromRGB(220, 232, 255)
			end
		end
	end
end

local function announceRaidOpening(st)
	local bossDef = Characters.Get(st.BossId)
	local bossName = bossDef and bossDef.Name or st.BossId
	local text = string.format(
		"EVENTO GLOBAL: Raid %d Estrelas contra %s (Nv. %d) est\u{e1} ABERTA por 15 minutos!",
		st.Stars,
		bossName,
		st.Tier.Level
	)
	local rarity = if st.Stars == 6 then "Secreto" elseif st.Stars == 5 then "Lendario" else "Epico"
	local announceRemote = Remotes:FindFirstChild("Announce")
	if announceRemote then
		announceRemote:FireAllClients(text, {
			Kind = "RaidOpen",
			Stars = st.Stars,
			CharacterId = st.BossId,
			CharacterName = bossName,
			BossLevel = st.Tier.Level,
			Rarity = rarity,
		})
	end
end

--------------------------------------------------------------------
-- Arenas dedicadas 4x1 (Workspace.Arenas.RaidArena01..03)
--------------------------------------------------------------------
local function acquireRaidArena(): Model?
	local folder = workspace:FindFirstChild("Arenas")
	if not folder then
		return nil
	end
	for _, arena in ipairs(folder:GetChildren()) do
		if arena:IsA("Model") and arena:GetAttribute("IsRaidArena") == true and not arena:GetAttribute("InUse") then
			arena:SetAttribute("InUse", true)
			return arena
		end
	end
	return nil
end

local function tintRaidArena(arena: Model, mainColor: Color3)
	local decor = arena:FindFirstChild("RaidDecor")
	if not decor then
		return
	end
	for _, ch in ipairs(decor:GetChildren()) do
		if ch:IsA("BasePart") and (ch.Name == "BossAltarRing" or ch.Name:sub(1, 10) == "SpireGlow_") then
			ch.Color = mainColor
		end
	end
end

-- Posiciona modelo (inclusive Boss escalado 1.75x..2.05x) exatamente apoiado sobre floorY
local function standModelOnFloor(model: Model, spot: CFrame, floorY: number)
	local look = spot.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.01 then
		look = Vector3.new(1, 0, 0)
	end
	local flatCF = CFrame.lookAt(Vector3.new(spot.Position.X, floorY + 4, spot.Position.Z), Vector3.new(spot.Position.X, floorY + 4, spot.Position.Z) + look)
	model:PivotTo(flatCF)
	local bboxCF, bboxSize = model:GetBoundingBox()
	local bottomY = bboxCF.Position.Y - bboxSize.Y * 0.5
	local dy = floorY - bottomY
	model:PivotTo(model:GetPivot() + Vector3.new(0, dy, 0))
end

-- Aura minimalista 100% particulas puras para o Boss da Raid (zero discos/decals/stickers)
local function attachBossRaidAura(model: Model, mainCol: Color3, accentCol: Color3)
	local host = model:FindFirstChild("UpperTorso") or model:FindFirstChild("HumanoidRootPart")
	if not host or not host:IsA("BasePart") then
		return
	end
	local att = Instance.new("Attachment")
	att.Name = "RaidBossAura"
	att.Parent = host

	local wisps = Instance.new("ParticleEmitter")
	wisps.Texture = "rbxasset://textures/particles/smoke_main.dds"
	wisps.Color = ColorSequence.new(mainCol, accentCol)
	wisps.LightEmission = 0.75
	wisps.LightInfluence = 0
	wisps.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.92),
		NumberSequenceKeypoint.new(0.25, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	wisps.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2.2),
		NumberSequenceKeypoint.new(0.6, 3.0),
		NumberSequenceKeypoint.new(1, 0.6),
	})
	wisps.Lifetime = NumberRange.new(0.9, 1.5)
	wisps.Speed = NumberRange.new(3, 6)
	wisps.EmissionDirection = Enum.NormalId.Top
	wisps.SpreadAngle = Vector2.new(35, 35)
	wisps.Rate = 14
	wisps.Parent = att

	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(accentCol)
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Lifetime = NumberRange.new(0.6, 1.2)
	sparks.Speed = NumberRange.new(5, 11)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = 12
	sparks.Parent = att
end

local function setModelVisible(model: Model?, visible: boolean)
	if not model or not model.Parent then
		return
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			if not visible then
				if d:GetAttribute("_RaidOrigTrans") == nil then
					d:SetAttribute("_RaidOrigTrans", d.Transparency)
				end
				d.Transparency = 1
			else
				local orig = d:GetAttribute("_RaidOrigTrans")
				if typeof(orig) == "number" then
					d.Transparency = orig
				end
			end
		elseif d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			d.Enabled = visible
		end
	end
end

--------------------------------------------------------------------
-- Ciclo completo da Batalha de Raid 4x1
--------------------------------------------------------------------
local function cleanupRaid(raid)
	if raid.Cleaned then
		return
	end
	raid.Cleaned = true
	activeRaids[raid.Id] = nil

	for _, p in pairs(raid.HumanBySlot) do
		if playerRaid[p] == raid then
			playerRaid[p] = nil
			ArenaManager.ReturnToPlaza(p)
			if p.Parent then
				RaidStateRE:FireClient(p, "RaidClosed", {})
			end
		end
	end

	if raid.Actors and raid.Actors.Parent then
		raid.Actors:Destroy()
	end
	if raid.Arena and raid.Arena.Parent then
		raid.Arena:SetAttribute("InUse", false)
	end
end

local function releasePlayerFromRaid(player: Player, raid)
	if playerRaid[player] ~= raid then
		return
	end
	playerRaid[player] = nil
	ArenaManager.ReturnToPlaza(player)
	if player.Parent then
		RaidStateRE:FireClient(player, "RaidClosed", {})
	end
	-- Verifica se ainda restou algum humano conectado na Raid
	local anyLeft = false
	for _, p in pairs(raid.HumanBySlot) do
		if playerRaid[p] == raid and p.Parent then
			anyLeft = true
			break
		end
	end
	if not anyLeft then
		cleanupRaid(raid)
	end
end

local function eventPaceDelay(ev): number
	local k = ev.Kind
	if k == "Move" then
		local mv = ev.MoveId and Moves.Get(ev.MoveId)
		if mv and mv.Timing and typeof(mv.Timing.Impact) == "number" then
			return math.clamp(mv.Timing.Impact, 0.25, 0.72)
		end
		return 0.40
	elseif k == "Damage" then
		return if ev.TargetKind == "Boss" then 0.22 else 0.10
	elseif k == "ShieldHit" then
		return 0.08
	elseif k == "PhasePulse" or k == "ShieldUp" or k == "ShieldBreak" then
		return 0.70
	elseif k == "AllyFaint" or k == "AllyRevive" or k == "BossStunned" then
		return 0.50
	elseif k == "TurnStart" then
		return 0.18
	end
	return 0.16
end

local function runRaidLoop(raid)
	local engine = raid.Engine
	while not raid.Cleaned and engine.State == "WaitingForInput" do
		-- Abre janela de 20s para os humanos vivos (nao convertidos para IA) escolherem 1 dos 4 golpes
		raid.TurnActions = {}
		raid.TurnEndsAt = os.clock() + Raids.TurnTimer
		raid.AwaitingInput = true
		local snap = engine:Snapshot()

		for slotIdx, p in pairs(raid.HumanBySlot) do
			if playerRaid[p] == raid and p.Parent then
				RaidStateRE:FireClient(p, "TurnPrompt", {
					RaidId = raid.Id,
					State = snap,
					MySlot = slotIdx,
					TurnEndsAt = raid.TurnEndsAt,
					TurnDuration = Raids.TurnTimer,
				})
			end
		end

		-- Espera todos os humanos vivos escolherem ou o timer de 20s acabar
		while not raid.Cleaned and os.clock() < raid.TurnEndsAt do
			local allReady = true
			for slotIdx, p in pairs(raid.HumanBySlot) do
				local s = engine.Slots[slotIdx]
				if s and not s.ConvertedToAi and s.Hp > 0 and not s.Out and playerRaid[p] == raid and p.Parent then
					if not raid.TurnActions[slotIdx] then
						allReady = false
						break
					end
				end
			end
			if allReady then
				break
			end
			task.wait(0.10)
		end

		raid.AwaitingInput = false
		if raid.Cleaned then
			return
		end

		-- Resolve turno no RaidEngine puro
		local events = engine:ResolveTurn(raid.TurnActions)
		local finalSnap = engine:Snapshot()

		for _, ev in ipairs(events) do
			if raid.Cleaned then
				return
			end
			-- Atualiza visibilidade de modelos em desmaio/revive no servidor
			if ev.Kind == "AllyFaint" and ev.Slot then
				setModelVisible(raid.AllyModels[ev.Slot], false)
			elseif ev.Kind == "AllyRevive" and ev.Slot then
				setModelVisible(raid.AllyModels[ev.Slot], true)
			elseif ev.Kind == "Damage" and ev.TargetKind == "Boss" then
				ArenaManager.ImpactBurst(raid.BossModel, Color3.fromRGB(255, 220, 110))
			elseif ev.Kind == "ShieldBreak" then
				ArenaManager.ImpactBurst(raid.BossModel, Color3.fromRGB(115, 245, 255))
			end

			for _, p in pairs(raid.HumanBySlot) do
				if playerRaid[p] == raid and p.Parent then
					RaidStateRE:FireClient(p, "BattleEvent", {
						RaidId = raid.Id,
						Event = ev,
						BossHp = if ev.TargetKind == "Boss" and ev.Hp ~= nil then ev.Hp else nil,
						BossShield = if ev.Shield ~= nil then ev.Shield else nil,
					})
				end
			end
			task.wait(eventPaceDelay(ev))
		end

		-- Sincroniza snapshot completo apos o turno
		for _, p in pairs(raid.HumanBySlot) do
			if playerRaid[p] == raid and p.Parent then
				RaidStateRE:FireClient(p, "StateSync", {
					RaidId = raid.Id,
					State = finalSnap,
				})
			end
		end
	end

	if raid.Cleaned then
		return
	end

	-- Fim da Raid!
	local winner = engine.Winner
	if winner == "Players" then
		setModelVisible(raid.BossModel, false)
		raid.Phase = "Capture"
		raid.CaptureEndsAt = os.clock() + Raids.CaptureWindowSeconds
		raid.CaptureEligibility = {}

		for slotIdx, p in pairs(raid.HumanBySlot) do
			if playerRaid[p] == raid and p.Parent then
				local data = PlayerDataService.Get(p)
				local slotState = engine.Slots[slotIdx]
				local alreadyClaimed = hasClaimedSlot(data, raid.SlotKey)
				local rewards = nil
				local canCapture = false

				if data and not alreadyClaimed then
					markClaimedSlot(data, raid.SlotKey)
					local isMvp = (engine.MvpSlot == slotIdx)
					rewards = Raids.ComputeRewards(raid.Stars, isMvp)
					data.Gold += rewards.Gold
					AccountLevelService.AddXp(p, rewards.AccountXp, "Raid")
					if slotState and slotState.Uid and data.Collection[slotState.Uid] then
						ProgressionService.AddXp(p, slotState.Uid, rewards.CharXp)
					end
					data.TrainingOres = Training.SanitizeOres(data.TrainingOres, Training.MaxOrePerType)
					for _, statKey in ipairs(Training.OreOrder) do
						data.TrainingOres[statKey] = math.min(Training.MaxOrePerType, (data.TrainingOres[statKey] or 0) + rewards.OrePerStat)
					end
					PlayerDataService.MarkChanged(p)
					task.spawn(PlayerDataService.SaveNow, p)
					canCapture = true
				end

				raid.CaptureEligibility[p] = {
					CanCapture = canCapture,
					Used = false,
				}

				RaidStateRE:FireClient(p, "BattleVictory", {
					RaidId = raid.Id,
					Stars = raid.Stars,
					BossId = raid.BossId,
					BossName = engine.Boss.Name,
					BossLevel = engine.Boss.Level,
					Ranking = engine.DamageRanking,
					MvpSlot = engine.MvpSlot,
					MySlot = slotIdx,
					AlreadyClaimed = alreadyClaimed,
					Rewards = rewards,
					CanCapture = canCapture,
					SuperiorOnly = raid.Tier.Capture.SuperiorOnly == true,
					Capture = raid.Tier.Capture,
					Seals = bagSeals(data),
					CaptureEndsAt = raid.CaptureEndsAt,
				})
			end
		end

		-- Aguarda janela de captura ou saida de todos os jogadores
		while not raid.Cleaned and os.clock() < raid.CaptureEndsAt do
			local anyWaiting = false
			for _, p in pairs(raid.HumanBySlot) do
				if playerRaid[p] == raid and p.Parent then
					anyWaiting = true
					break
				end
			end
			if not anyWaiting then
				break
			end
			task.wait(0.4)
		end
		cleanupRaid(raid)
	else
		raid.Phase = "Defeat"
		for slotIdx, p in pairs(raid.HumanBySlot) do
			if playerRaid[p] == raid and p.Parent then
				RaidStateRE:FireClient(p, "BattleDefeat", {
					RaidId = raid.Id,
					Reason = engine.EndReason,
					Ranking = engine.DamageRanking,
					MvpSlot = engine.MvpSlot,
					MySlot = slotIdx,
					BossName = engine.Boss.Name,
				})
			end
		end
		local waitUntil = os.clock() + 10
		while not raid.Cleaned and os.clock() < waitUntil do
			local anyWaiting = false
			for _, p in pairs(raid.HumanBySlot) do
				if playerRaid[p] == raid and p.Parent then
					anyWaiting = true
					break
				end
			end
			if not anyWaiting then
				break
			end
			task.wait(0.3)
		end
		cleanupRaid(raid)
	end
end

local function launchLobby(lobby)
	if lobby.Launched then
		return false, "Lobby j\u{e1} iniciado."
	end
	if #lobby.Members == 0 then
		lobbies[lobby.Id] = nil
		return false, "Lobby vazio."
	end
	local arena = acquireRaidArena()
	if not arena then
		return false, "Todas as Arenas de Raid est\u{e3}o ocupadas. Tente em instantes."
	end

	lobby.Launched = true
	lobbies[lobby.Id] = nil

	local tier = Raids.Tiers[lobby.Stars] or Raids.Tiers[3]
	local slotConfigs = {}
	local humanBySlot = {}

	for i, m in ipairs(lobby.Members) do
		playerLobby[m.Player] = nil
		local data = PlayerDataService.Get(m.Player)
		local colEntry = data and data.Collection and data.Collection[m.Uid]
		local charId = if colEntry then colEntry.CharacterId else m.CharacterId
		local level = if colEntry then colEntry.Level else m.Level
		local activeMoves = if colEntry and typeof(colEntry.Active) == "table" and #colEntry.Active > 0 then colEntry.Active else nil
		local mult = if colEntry then Progression.MemberMultiplier(colEntry) else 1

		slotConfigs[i] = {
			CharacterId = charId,
			Level = level,
			Moves = activeMoves,
			Uid = m.Uid,
			UserId = m.Player.UserId,
			OwnerName = if #m.Player.DisplayName > 0 then m.Player.DisplayName else m.Player.Name,
			IsNpc = false,
			StatMultiplier = mult,
			Genetics = colEntry and colEntry.Genetics,
			Training = colEntry and colEntry.Training,
			Variant = colEntry and colEntry.Variant,
			Awakened = colEntry and colEntry.Awakened == true,
			Stars = colEntry and colEntry.Stars or 0,
		}
		humanBySlot[i] = m.Player
	end

	local engine = RaidEngine.New({
		Stars = lobby.Stars,
		BossId = lobby.BossId,
		SlotKey = lobby.SlotKey,
		Slots = slotConfigs,
		Seed = os.time() + nextRaidId * 97,
	})

	local floorY = ArenaManager.GetFloorY(arena)
	local tintCol = if lobby.Stars == 6 then tier.AccentColor else tier.Color
	tintRaidArena(arena, tintCol)

	local actors = Instance.new("Folder")
	actors.Name = "RaidActors_" .. nextRaidId
	actors.Parent = arena

	-- Instancia Boss Gigante
	local bossPoint = arena:WaitForChild("BossPoint") :: BasePart
	local bossModel = CharacterLibrary.Spawn(engine.Boss.ModelName, nil, actors)
	local bHum = bossModel:FindFirstChildOfClass("Humanoid")
	if bHum then
		bHum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		bHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local bRoot = bossModel:FindFirstChild("HumanoidRootPart") :: BasePart?
	if bRoot then
		bRoot.Anchored = true
	end
	pcall(function()
		bossModel:ScaleTo(tier.BossScale)
	end)
	standModelOnFloor(bossModel, bossPoint.CFrame, floorY)
	bossModel:SetAttribute("CharacterId", engine.Boss.Id)
	bossModel:SetAttribute("IsRaidBoss", true)
	attachBossRaidAura(bossModel, tintCol, tier.AccentColor)
	CollectionService:AddTag(bossModel, "BattleCharacter")

	-- Instancia 4 Aliados no arco frontal
	local allyModels = {}
	for i = 1, Raids.MaxPlayers do
		local s = engine.Slots[i]
		local aPoint = arena:WaitForChild("AllyPoint" .. i) :: BasePart
		local aModel = CharacterLibrary.Spawn(s.ModelName, nil, actors)
		local aHum = aModel:FindFirstChildOfClass("Humanoid")
		if aHum then
			aHum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			aHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		local aRoot = aModel:FindFirstChild("HumanoidRootPart") :: BasePart?
		if aRoot then
			aRoot.Anchored = true
		end
		if s.Variant then
			pcall(VariantController.Apply, aModel, s.Variant)
		end
		standModelOnFloor(aModel, aPoint.CFrame, floorY)
		aModel:SetAttribute("CharacterId", s.Id)
		aModel:SetAttribute("Awakened", s.Awakened == true)
		CollectionService:AddTag(aModel, "BattleCharacter")
		allyModels[i] = aModel
	end

	local raidId = nextRaidId
	nextRaidId += 1

	local raid = {
		Id = raidId,
		SlotKey = lobby.SlotKey,
		Stars = lobby.Stars,
		Tier = tier,
		BossId = lobby.BossId,
		Arena = arena,
		Actors = actors,
		BossModel = bossModel,
		AllyModels = allyModels,
		Engine = engine,
		HumanBySlot = humanBySlot,
		Phase = "Battle",
		TurnActions = {},
		TurnEndsAt = 0,
		CaptureEndsAt = 0,
		CaptureEligibility = {},
		Cleaned = false,
	}
	activeRaids[raidId] = raid

	-- Teleporta jogadores para os pontos de treinador atras do arco e envia BattleStart
	local camPoint = arena:WaitForChild("RaidCameraPoint") :: BasePart
	local packedAllies = {
		Slot1 = allyModels[1],
		Slot2 = allyModels[2],
		Slot3 = allyModels[3],
		Slot4 = allyModels[4],
	}
	local initSnap = engine:Snapshot()

	for slotIdx, p in pairs(humanBySlot) do
		playerRaid[p] = raid
		local tPoint = arena:WaitForChild("TrainerPoint" .. slotIdx) :: BasePart
		local char = p.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			pcall(function()
				p:RequestStreamAroundAsync(bossPoint.Position, 5)
			end)
			hrp.Anchored = true
			ArenaManager.StandAt(char, tPoint.CFrame, floorY)
		end
		local data = PlayerDataService.Get(p)
		RaidStateRE:FireClient(p, "BattleStart", {
			RaidId = raidId,
			Stars = lobby.Stars,
			BossId = lobby.BossId,
			Camera = camPoint.CFrame,
			BossModel = bossModel,
			AllyModels = packedAllies,
			MySlot = slotIdx,
			State = initSnap,
			AlreadyClaimed = hasClaimedSlot(data, lobby.SlotKey),
		})
	end

	task.spawn(runRaidLoop, raid)
	return true
end

--------------------------------------------------------------------
-- Acoes do Cliente (RemoteFunction: RaidAction)
--------------------------------------------------------------------
local function removePlayerFromLobby(player: Player)
	local lobby = playerLobby[player]
	if not lobby then
		return
	end
	playerLobby[player] = nil
	for i, m in ipairs(lobby.Members) do
		if m.Player == player then
			table.remove(lobby.Members, i)
			break
		end
	end
	if #lobby.Members == 0 then
		lobbies[lobby.Id] = nil
	else
		if lobby.LeaderUserId == player.UserId then
			lobby.LeaderUserId = lobby.Members[1].Player.UserId
		end
		broadcastLobby(lobby)
	end
end

local function handleAction(player: Player, action: string, arg1: any)
	if typeof(action) ~= "string" then
		return { Ok = false, Message = "A\u{e7}\u{e3}o inv\u{e1}lida." }
	end

	if action == "GetStatus" then
		return { Ok = true, Data = buildGlobalPayload(player) }
	end

	if action == "TeleportMonolith" then
		if isBusyOutsideRaid(player) or playerRaid[player] then
			return { Ok = false, Message = "Voc\u{ea} est\u{e1} em batalha no momento." }
		end
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			char:PivotTo(CFrame.lookAt(Vector3.new(-40, 11.5, 42), Vector3.new(-40, 11.5, 30)))
		end
		return { Ok = true, Data = buildGlobalPayload(player) }
	end

	if action == "JoinLobby" then
		if isBusyOutsideRaid(player) or playerRaid[player] then
			return { Ok = false, Message = "Saia da batalha atual antes de entrar na Raid." }
		end
		local st = currentRaidState()
		if not st.Open then
			return { Ok = false, Message = "A Fenda de Raid est\u{e1} fechada no momento." }
		end
		local data = PlayerDataService.Get(player)
		if not data or not data.StarterChosen then
			return { Ok = false, Message = "Escolha seu personagem inicial antes de entrar na Raid." }
		end
		local uid = if typeof(arg1) == "string" and data.Collection[arg1] then arg1 else pickDefaultFighterUid(data)
		if not uid then
			return { Ok = false, Message = "Voc\u{ea} precisa ter ao menos 1 personagem." }
		end
		if playerLobby[player] then
			return { Ok = true, Data = buildGlobalPayload(player) }
		end

		-- Procura um lobby aberto da mesma hora com vaga (< 4)
		local targetLobby = nil
		for _, lb in pairs(lobbies) do
			if not lb.Launched and lb.SlotKey == st.SlotKey and #lb.Members < Raids.MaxPlayers then
				targetLobby = lb
				break
			end
		end
		if not targetLobby then
			local id = nextLobbyId
			nextLobbyId += 1
			targetLobby = {
				Id = id,
				SlotId = st.SlotId,
				SlotKey = st.SlotKey,
				Stars = st.Stars,
				BossId = st.BossId,
				LeaderUserId = player.UserId,
				CountdownEndsAt = os.clock() + Raids.LobbyCountdown,
				Launched = false,
				Members = {},
			}
			lobbies[id] = targetLobby
		end

		local col = data.Collection[uid]
		table.insert(targetLobby.Members, {
			Player = player,
			Uid = uid,
			CharacterId = col.CharacterId,
			Level = col.Level,
			Stars = col.Stars or 0,
			Awakened = col.Awakened == true,
			Variant = col.Variant,
		})
		playerLobby[player] = targetLobby
		broadcastLobby(targetLobby)
		return { Ok = true, Data = buildGlobalPayload(player) }
	end

	if action == "LeaveLobby" then
		removePlayerFromLobby(player)
		return { Ok = true, Data = buildGlobalPayload(player) }
	end

	if action == "SelectFighter" then
		local lobby = playerLobby[player]
		if not lobby or lobby.Launched then
			return { Ok = false, Message = "Voc\u{ea} n\u{e3}o est\u{e1} em um lobby de Raid." }
		end
		local data = PlayerDataService.Get(player)
		if not data or typeof(arg1) ~= "string" or not data.Collection[arg1] then
			return { Ok = false, Message = "Personagem inv\u{e1}lido." }
		end
		local col = data.Collection[arg1]
		for _, m in ipairs(lobby.Members) do
			if m.Player == player then
				m.Uid = arg1
				m.CharacterId = col.CharacterId
				m.Level = col.Level
				m.Stars = col.Stars or 0
				m.Awakened = col.Awakened == true
				m.Variant = col.Variant
				break
			end
		end
		broadcastLobby(lobby)
		return { Ok = true, Data = buildGlobalPayload(player) }
	end

	if action == "StartNow" then
		local lobby = playerLobby[player]
		if not lobby or lobby.Launched then
			return { Ok = false, Message = "Nenhum lobby ativo." }
		end
		if lobby.LeaderUserId ~= player.UserId then
			return { Ok = false, Message = "Somente o l\u{ed}der do grupo pode iniciar antes da contagem." }
		end
		local ok, err = launchLobby(lobby)
		if not ok then
			return { Ok = false, Message = err }
		end
		return { Ok = true }
	end

	if action == "SubmitMove" then
		local raid = playerRaid[player]
		if not raid or raid.Phase ~= "Battle" or not raid.AwaitingInput or raid.Engine.State ~= "WaitingForInput" then
			return { Ok = false, Message = "Aguarde o turno atual terminar." }
		end
		local mySlot = nil
		for sIdx, p in pairs(raid.HumanBySlot) do
			if p == player then
				mySlot = sIdx
				break
			end
		end
		if not mySlot then
			return { Ok = false, Message = "Slot n\u{e3}o encontrado." }
		end
		local s = raid.Engine.Slots[mySlot]
		if not s or s.Hp <= 0 or s.Out then
			return { Ok = false, Message = "Seu personagem est\u{e1} aguardando reviver." }
		end
		local idx = math.floor(tonumber(arg1) or 0)
		if idx < 1 or idx > #s.Moves then
			return { Ok = false, Message = "Golpe inv\u{e1}lido." }
		end
		raid.TurnActions[mySlot] = { MoveIndex = idx }
		-- Informa aos demais jogadores que este slot ja confirmou o golpe
		for _, p in pairs(raid.HumanBySlot) do
			if playerRaid[p] == raid and p.Parent then
				RaidStateRE:FireClient(p, "SlotReady", { RaidId = raid.Id, Slot = mySlot })
			end
		end
		return { Ok = true }
	end

	if action == "Capture" then
		local raid = playerRaid[player]
		if not raid or raid.Phase ~= "Capture" then
			return { Ok = false, Message = "Tela de captura n\u{e3}o est\u{e1} ativa." }
		end
		local elig = raid.CaptureEligibility[player]
		if not elig or not elig.CanCapture or elig.Used then
			return { Ok = false, Message = "Voc\u{ea} j\u{e1} usou sua tentativa de captura nesta Raid." }
		end
		local sealId = if typeof(arg1) == "string" then arg1 else ""
		local allowed, chance, reason = Raids.CaptureChance(raid.Stars, sealId)
		if not allowed then
			return { Ok = false, Message = reason or "Selo n\u{e3}o permitido." }
		end
		local data = PlayerDataService.Get(player)
		if not data then
			return { Ok = false, Message = "Perfil n\u{e3}o carregado." }
		end
		local have = (data.Bag and data.Bag[sealId]) or 0
		if have < 1 then
			local itemDef = Items.Get(sealId)
			return { Ok = false, Message = "Voc\u{ea} n\u{e3}o tem " .. (itemDef and itemDef.Name or sealId) .. " na mochila!" }
		end
		-- Verifica espaco na colecao antes de consumir o Selo
		local cap = Benefits.CollectionMax(data)
		local ownedCount = Benefits.CollectionCount(data)
		if ownedCount >= cap then
			return { Ok = false, Message = "Cole\u{e7}\u{e3}o cheia (" .. ownedCount .. "/" .. cap .. "). Venda ou funda repetidos primeiro." }
		end

		elig.Used = true
		data.Bag[sealId] = have - 1
		if data.Bag[sealId] <= 0 then
			data.Bag[sealId] = nil
		end

		local caught = rng:NextNumber() < chance
		local bossDef = Characters.Get(raid.BossId)
		local capturedLv = if raid.Stars >= 5 then 20 elseif raid.Stars == 4 then 15 else 10
		if caught then
			ProgressionService.AddCharacter(player, raid.BossId, capturedLv, #data.Team < 6, nil, nil, { Source = "Raid" })
		end
		PlayerDataService.MarkChanged(player)
		task.spawn(PlayerDataService.SaveNow, player)

		return {
			Ok = true,
			Caught = caught,
			Chance = chance,
			BossId = raid.BossId,
			BossName = bossDef and bossDef.Name or raid.BossId,
			Level = capturedLv,
			Seals = bagSeals(data),
		}
	end

	if action == "ExitRaid" then
		local raid = playerRaid[player]
		if raid and raid.Phase ~= "Battle" then
			releasePlayerFromRaid(player, raid)
		end
		return { Ok = true }
	end

	return { Ok = false, Message = "A\u{e7}\u{e3}o desconhecida: " .. action }
end

--------------------------------------------------------------------
-- Ferramenta Dev (Studio) para testar qualquer estrela/Boss na hora
--------------------------------------------------------------------
function RaidService.Dev(player: Player?, cmd: string, a: any, b: any)
	if not RunService:IsStudio() then
		return false, "Disponivel apenas no Studio."
	end
	if cmd == "open" then
		local stars = tonumber(a) or 6
		if not Raids.Tiers[stars] then
			stars = 6
		end
		local tier = Raids.Tiers[stars]
		local bossId = if typeof(b) == "string" and Characters.Get(b) then b else tier.Bosses[1]
		local now = Clock.Now()
		devOverride = {
			Stars = stars,
			BossId = bossId,
			ExpiresAt = now + Raids.OpenDurationSeconds,
			SlotId = math.floor(now),
		}
		lastAnnouncedSlotKey = nil
		local st = currentRaidState()
		updateMonolithVisuals(st)
		announceRaidOpening(st)
		for _, p in ipairs(Players:GetPlayers()) do
			RaidStateRE:FireClient(p, "GlobalStatus", buildGlobalPayload(p))
		end
		return true, st
	elseif cmd == "clear" then
		devOverride = nil
		local st = currentRaidState()
		updateMonolithVisuals(st)
		for _, p in ipairs(Players:GetPlayers()) do
			RaidStateRE:FireClient(p, "GlobalStatus", buildGlobalPayload(p))
		end
		return true
	elseif cmd == "resetclaim" and player then
		local data = PlayerDataService.Get(player)
		if data then
			data.Raid = { ClaimedSlots = {}, Wins = 0 }
			PlayerDataService.MarkChanged(player)
		end
		return true
	elseif cmd == "status" then
		return buildGlobalPayload(player)
	end
	return false, "Comando dev desconhecido: " .. tostring(cmd)
end

--------------------------------------------------------------------
-- Inicializacao
--------------------------------------------------------------------
function RaidService.Init()
	if initialized then
		return
	end
	initialized = true

	RaidActionRF.OnServerInvoke = handleAction

	-- Conecta o ProximityPrompt do Monolito 3D na Praca
	local map = workspace:FindFirstChild("Map")
	local mono = map and map:FindFirstChild("RaidMonolith")
	local prompt = mono and mono:FindFirstChild("RaidPrompt", true)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(function(player: Player)
			if isBusyOutsideRaid(player) or playerRaid[player] then
				return
			end
			RaidStateRE:FireClient(player, "OpenPanel", buildGlobalPayload(player))
		end)
	end

	-- Envia status global ao jogador quando o perfil carregar
	PlayerDataService.Loaded:Connect(function(player: Player)
		task.defer(function()
			if player.Parent then
				RaidStateRE:FireClient(player, "GlobalStatus", buildGlobalPayload(player))
			end
		end)
	end)

	-- Desconexao segura: sai do lobby ou converte slot da batalha para IA aliada sem cancelar o grupo!
	Players.PlayerRemoving:Connect(function(player: Player)
		removePlayerFromLobby(player)
		local raid = playerRaid[player]
		if raid then
			playerRaid[player] = nil
			for slotIdx, p in pairs(raid.HumanBySlot) do
				if p == player then
					raid.Engine:ConvertPlayerToAi(slotIdx)
					raid.HumanBySlot[slotIdx] = nil
					break
				end
			end
			-- Se nao restar nenhum humano na Raid, encerra e libera a arena
			if next(raid.HumanBySlot) == nil then
				cleanupRaid(raid)
			end
		end
	end)

	-- Loop de relogio global (1s) + auto-inicio de lobbies (30s)
	task.spawn(function()
		local tickCount = 0
		while true do
			local st = currentRaidState()
			updateMonolithVisuals(st)

			if st.Open and lastAnnouncedSlotKey ~= st.SlotKey then
				lastAnnouncedSlotKey = st.SlotKey
				announceRaidOpening(st)
				for _, p in ipairs(Players:GetPlayers()) do
					RaidStateRE:FireClient(p, "GlobalStatus", buildGlobalPayload(p))
				end
			elseif not st.Open then
				-- Fecha lobbies pendentes caso a janela de 15 min tenha expirado
				for id, lb in pairs(lobbies) do
					if not lb.Launched then
						lobbies[id] = nil
						for _, m in ipairs(lb.Members) do
							playerLobby[m.Player] = nil
							if m.Player.Parent then
								RaidStateRE:FireClient(m.Player, "LobbyClosed", { Message = "A janela da Raid encerrou." })
							end
						end
					end
				end
			end

			-- Inicia automaticamente lobbies cuja contagem de 30s zerou
			local nowClk = os.clock()
			for _, lb in pairs(table.clone(lobbies)) do
				if not lb.Launched and nowClk >= lb.CountdownEndsAt then
					task.spawn(launchLobby, lb)
				end
			end

			tickCount += 1
			if tickCount % 5 == 0 then
				for _, p in ipairs(Players:GetPlayers()) do
					if not playerRaid[p] then
						RaidStateRE:FireClient(p, "GlobalStatus", buildGlobalPayload(p))
					end
				end
			end

			task.wait(1)
		end
	end)
end

return RaidService
