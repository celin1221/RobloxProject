--[[
	BaseService (GDD secao 8)
	- Ao entrar, o jogador recebe um terreno livre (Workspace/Plots, atributo OwnerUserId); ao sair, ele e liberado.
	- Ate 6 personagens ativos na base: Passeando (andam pelo terreno, geram gold) ou Minerando
	  (ficam na pedreira, geram minerio), com as taxas da tabela por raridade.
	- Vagas de mineracao: 2 no inicio, melhorias em gold ate 6.
	- Producao fica pendente ate o jogador coletar; com o jogador fora acumula ate 8 horas.
	- Coleta: gold vai para o perfil; minerio vai para o deposito (maximo 10.000; o resto fica na base).
	- Venda de minerio na loja: 100 minerio = 1 gema, teto de 50 gemas por dia (dia UTC).
	O relogio pode ser adiantado so no Studio (testes).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

local Data = ReplicatedStorage:WaitForChild("Data")
local Base = require(Data.Base)
local Training = require(Data:WaitForChild("Training"))
local Characters = require(Data.Characters)
local AccountLevel = require(Data:WaitForChild("AccountLevel"))

local PlayerDataService = require(ServerScriptService:WaitForChild("Data"):WaitForChild("PlayerDataService"))
local AccountLevelService = require(ServerScriptService.Data:WaitForChild("AccountLevelService"))
local CharacterLibrary = require(ServerScriptService:WaitForChild("CharacterLibrary"))
local RetentionService = require(ServerScriptService.Data:WaitForChild("RetentionService"))
local Clock = require(ServerScriptService.Data:WaitForChild("Clock"))
local Retention = require(Data:WaitForChild("Retention"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local BaseService = {}

local LIVE_TICK = 1 -- segundos entre creditos ao vivo de gold com o jogador online
local SYNC_EVERY = 10 -- segundos entre replicacoes completas de perfil para minerios pendentes
local WALK_SPEED = 6
local BASE_NPC_GROUP = "BaseNPC"
local clockOffset = 0 -- so testes no Studio
local plotOf = {} -- [Player] = terreno
local walkers = {} -- [Model] = { Plot, Next, Moving }
local busy = {}
local rng = Random.new()

local function ensureNpcCollisionGroup()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(BASE_NPC_GROUP)
		for _, info in ipairs(PhysicsService:GetRegisteredCollisionGroups()) do
			PhysicsService:CollisionGroupSetCollidable(BASE_NPC_GROUP, info.name, false)
		end
	end)
end

local function makeNpcPartIntangible(inst: Instance)
	if inst:IsA("BasePart") then
		inst.CanCollide = false
		inst.CanQuery = false
		inst.CanTouch = false
		inst.Massless = true
		inst.CollisionGroup = BASE_NPC_GROUP
	elseif inst:IsA("Humanoid") then
		inst.EvaluateStateMachine = false
		inst.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		inst.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
end

local function makeNpcIntangible(model: Model)
	ensureNpcCollisionGroup()
	for _, d in ipairs(model:GetDescendants()) do
		makeNpcPartIntangible(d)
	end
	model.DescendantAdded:Connect(makeNpcPartIntangible)
end

local function now(): number
	return os.time() + clockOffset
end
BaseService.Now = now

local function rarityOf(characterId: string)
	local def = Characters.Get(characterId)
	return def and def.Rarity
end

local function notify(player: Player, text: string)
	Remotes.Notify:FireClient(player, text)
end

local function fmt(n: number): string
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", ""))
end

--------------------------------------------------------------------
-- Producao
--------------------------------------------------------------------
local function trainingUidOf(data): string?
	local job = data and data.TrainingMachine and data.TrainingMachine.Job
	return job and job.Uid or nil
end

-- Remove da base quem nao existe mais (ou esta treinando na capsula) e respeita os limites
local function sanitizeBase(data)
	local b = data.Base
	if typeof(b.Pending) ~= "table" then
		b.Pending = { Gold = 0, Ore = 0, Ores = Training.ZeroOres() }
	end
	if typeof(b.Pending.Ores) ~= "table" then
		b.Pending.Ores = Training.ZeroOres()
	end
	local busyUid = trainingUidOf(data)
	local active, miners = 0, 0
	local slots = Base.MiningSlots(data)
	local uids = {}
	for uid in pairs(b.Active) do
		table.insert(uids, uid)
	end
	table.sort(uids)
	for _, uid in ipairs(uids) do
		local state = b.Active[uid]
		if uid == busyUid or not data.Collection[uid] or (state ~= "Walk" and state ~= "Mine") or active >= Base.MaxActive then
			b.Active[uid] = nil
		else
			active += 1
			if state == "Mine" then
				if miners >= slots then
					b.Active[uid] = "Walk"
				else
					miners += 1
				end
			end
		end
	end
end

-- Rola os minerios de atributo por ciclo de mineracao conforme o nivel da Mineracao
local function rollMiningCycles(data, cycles: number)
	if cycles <= 0 then
		return
	end
	local level = Base.MiningLevelOf(data)
	local dropRow = Base.MiningDropTable[level]
	if not dropRow then
		return
	end
	local pendingOres = data.Base.Pending.Ores
	for _ = 1, cycles do
		for _, stat in ipairs(Training.OreOrder) do
			local cfg = dropRow[stat]
			if cfg and cfg.Chance > 0 and rng:NextNumber() < cfg.Chance then
				local qty = if cfg.Max > cfg.Min then rng:NextInteger(cfg.Min, cfg.Max) else cfg.Min
				pendingOres[stat] = math.min(Training.MaxOrePerType, (pendingOres[stat] or 0) + qty)
			end
		end
	end
end

-- Soma a producao desde o ultimo calculo.
-- offline = true (ate 8h fora): gold e minerios acumulam em Pending para coletar.
-- liveOnline = true (jogador online): gold cai direto na carteira a cada segundo!
local function accrue(data, offline: boolean, liveOnline: boolean?)
	local b = data.Base
	local t = now()
	local goldMult = Retention.GoldMultiplier(Clock.Now())
	local goldRate, oreRate, goldPerSec = Base.Rates(data, rarityOf)
	local liveRate = (goldPerSec or (goldRate / 3600)) * goldMult
	-- sem marca ainda, ou marca no futuro (relogio adiantado em teste): recomeca a contar agora
	if (b.LastTick or 0) <= 0 or b.LastTick > t then
		b.LastTick = t
		return 0, 0, 0, liveRate
	end
	if typeof(b.Pending.Ores) ~= "table" then
		b.Pending.Ores = Training.ZeroOres()
	end
	local dt = math.max(0, t - b.LastTick)
	if offline then
		dt = math.min(dt, Base.OfflineCapHours * 3600)
	end
	-- fim de semana com 2x gold (secao 13): vale para a producao do periodo
	local gold = goldRate * dt / 3600 * goldMult
	local ore = oreRate * dt / 3600
	local credited = 0
	if liveOnline and not offline then
		b.GoldCarry = (b.GoldCarry or 0) + gold
		credited = math.floor(b.GoldCarry)
		if credited >= 1 then
			data.Gold += credited
			b.GoldCarry -= credited
		end
	else
		b.Pending.Gold += gold
	end
	b.Pending.Ore += ore

	local minerPower = Base.MinerPower(data, rarityOf)
	if minerPower > 0 and dt > 0 then
		b.MiningProgress = (b.MiningProgress or 0) + (dt / Base.MiningCycleSeconds) * minerPower
		local cycles = math.floor(b.MiningProgress)
		if cycles >= 1 then
			b.MiningProgress -= cycles
			rollMiningCycles(data, math.min(Base.MaxOfflineMiningCycles, cycles))
		end
	end

	b.LastTick = t
	return (if liveOnline and not offline then credited else gold), ore, dt, liveRate
end
BaseService.Accrue = accrue

local function syncLiveRateAttr(player: Player, data)
	local goldRate, _, goldPerSec = Base.Rates(data, rarityOf)
	local liveRate = (goldPerSec or (goldRate / 3600)) * Retention.GoldMultiplier(Clock.Now())
	player:SetAttribute("LiveGoldRate", math.floor(liveRate * 100 + 0.5) / 100)
end

--------------------------------------------------------------------
-- Personagens na base
--------------------------------------------------------------------
local function floorTop(plot: Model): number
	local f = plot:FindFirstChild("Floor")
	return if f then f.Position.Y + f.Size.Y / 2 else plot:GetPivot().Position.Y
end

local function npcFolder(plot: Model): Folder
	local f = plot:FindFirstChild("BaseCharacters")
	if not f then
		f = Instance.new("Folder")
		f.Name = "BaseCharacters"
		f.Parent = plot
	end
	return f
end

local function standCFrame(plot: Model, model: Model, pos: Vector3, lookAt: Vector3?): CFrame
	local root = model:FindFirstChild("HumanoidRootPart")
	local hum = model:FindFirstChildOfClass("Humanoid")
	local y = floorTop(plot) + (hum and hum.HipHeight or 2) + (root and root.Size.Y / 2 or 1)
	local p = Vector3.new(pos.X, y, pos.Z)
	local target = lookAt and Vector3.new(lookAt.X, y, lookAt.Z) or (p + Vector3.new(0, 0, -1))
	if (target - p).Magnitude < 0.01 then
		target = p + Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(p, target)
end

-- Ponto livre para passear (longe da pedreira)
local function randomWalkPoint(plot: Model): Vector3
	local floor = plot:FindFirstChild("Floor")
	local quarry = plot:FindFirstChild("Quarry")
	local qGround = quarry and quarry:FindFirstChild("Ground")
	for _ = 1, 10 do
		local p = (floor.CFrame * CFrame.new(rng:NextNumber(-15, 15), 0, rng:NextNumber(-15, 15))).Position
		if not qGround or ((p - qGround.Position) * Vector3.new(1, 0, 1)).Magnitude > 7 then
			return p
		end
	end
	return floor.Position
end

-- Mede o raio externo da pedreira (rochas + vagoneta) na direcao horizontal u
local function quarrySurfaceRadius(quarry: Model?, center: Vector3, u: Vector3): number
	if not quarry then
		return 4.5
	end
	local maxR = 4.0
	for _, d in ipairs(quarry:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "Ground" and d.Name ~= "MinePoint" and d.Transparency < 1 then
			local rel = d.Position - center
			local proj = rel.X * u.X + rel.Z * u.Z
			local cf = d.CFrame
			local half = 0.5 * (
				math.abs(cf.RightVector.X * u.X + cf.RightVector.Z * u.Z) * d.Size.X
				+ math.abs(cf.UpVector.X * u.X + cf.UpVector.Z * u.Z) * d.Size.Y
				+ math.abs(cf.LookVector.X * u.X + cf.LookVector.Z * u.Z) * d.Size.Z
			)
			maxR = math.max(maxR, proj + half * 0.94)
		end
	end
	return maxR
end

local function minePoint(plot: Model, index: number, totalMiners: number, model: Model): (Vector3, Vector3)
	local quarry = plot:FindFirstChild("Quarry")
	local floor = plot:FindFirstChild("Floor")
	local mp = quarry and quarry:FindFirstChild("MinePoint")
	local rock = quarry and quarry:FindFirstChild("Ground")
	local center = rock and rock.Position or plot:GetPivot().Position
	local from = mp and mp.Position or center
	-- arco centralizado no lado aberto da pedreira, com folga real para personagens grandes sem colidir com a rocha
	local dir = (from - center) * Vector3.new(1, 0, 1)
	dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.new(-1, 0, 0)
	local count = math.max(1, totalMiners or 1)
	local spanDeg = if count <= 1 then 0 else math.min(26, 112 / (count - 1))
	local angle = math.rad((index - (count + 1) / 2) * spanDeg)
	local rotated = CFrame.Angles(0, angle, 0) * dir
	rotated = Vector3.new(rotated.X, 0, rotated.Z).Unit

	local _, charSize = model:GetBoundingBox()
	local charRadius = math.max(charSize.X, charSize.Z) * 0.45
	local surface = quarrySurfaceRadius(quarry, center, rotated)
	local dist = math.max(5.5, surface + charRadius + 1.0)
	local pos = center + rotated * dist

	if floor then
		local localPos = floor.CFrame:PointToObjectSpace(pos)
		local margin = math.max(2.6, charRadius + 0.6)
		local maxX = math.max(1, floor.Size.X * 0.5 - margin)
		local maxZ = math.max(1, floor.Size.Z * 0.5 - margin)
		local clamped = Vector3.new(math.clamp(localPos.X, -maxX, maxX), localPos.Y, math.clamp(localPos.Z, -maxZ, maxZ))
		pos = floor.CFrame:PointToWorldSpace(clamped)
	end
	return pos, center
end

local function syncNPCs(player: Player)
	local plot = plotOf[player]
	local data = PlayerDataService.Get(player)
	if not plot or not data then
		return
	end
	local folder = npcFolder(plot)
	local existing = {}
	for _, m in folder:GetChildren() do
		local uid = m:GetAttribute("Uid")
		if uid and data.Base.Active[uid] and data.Collection[uid] then
			existing[uid] = m
		else
			walkers[m] = nil
			m:Destroy()
		end
	end
	local uids = {}
	for uid in pairs(data.Base.Active) do
		table.insert(uids, uid)
	end
	table.sort(uids)
	local totalMiners = 0
	for _, uid in ipairs(uids) do
		if data.Base.Active[uid] == "Mine" then
			totalMiners += 1
		end
	end
	local mineIndex = 0
	for _, uid in ipairs(uids) do
		local state = data.Base.Active[uid]
		local member = data.Collection[uid]
		local def = member and Characters.Get(member.CharacterId)
		if def then
			local model = existing[uid]
			if not model then
				model = CharacterLibrary.Spawn(def.ModelName, nil, nil)
				model.Name = def.Name
				local root = model:FindFirstChild("HumanoidRootPart")
				root.Anchored = true
				makeNpcIntangible(model)
				model:SetAttribute("Uid", uid)
				model:SetAttribute("OwnerUserId", player.UserId)
				model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
				CollectionService:AddTag(model, "BaseCharacter")
				model.Parent = folder
			else
				makeNpcIntangible(model)
			end
			local changed = model:GetAttribute("BaseState") ~= state
			model:SetAttribute("BaseState", state)
			if state == "Mine" then
				mineIndex += 1
				walkers[model] = nil
				model:SetAttribute("Moving", false)
				local pos, rock = minePoint(plot, mineIndex, totalMiners, model)
				model:PivotTo(standCFrame(plot, model, pos, rock))
			elseif changed or not walkers[model] then
				walkers[model] = { Plot = plot, Next = os.clock() + rng:NextNumber(0.5, 2), Moving = false }
				model:SetAttribute("Moving", false)
				model:PivotTo(standCFrame(plot, model, randomWalkPoint(plot), nil))
			end
		end
	end
end
BaseService.SyncNPCs = syncNPCs

-- Passeio: anda ate um ponto do terreno, para um pouco e escolhe outro.
-- Desempenho: o cliente anda liso (NpcWalkClient, pelos atributos Walk*); o servidor so acerta a
-- posicao 2 vezes por segundo (antes um Tween no servidor mandava a posicao todo quadro).
local WALK_SYNC = 0.5
local function walkStep()
	local t = os.clock()
	for model, w in pairs(walkers) do
		if not model.Parent then
			walkers[model] = nil
		elseif w.Moving then
			local root = model:FindFirstChild("HumanoidRootPart")
			local a = (t - w.Start) / w.Dur
			if a >= 1 then
				if root then
					root.CFrame = w.To
				end
				w.Moving = false
				w.Next = t + rng:NextNumber(1.5, 4)
				model:SetAttribute("Moving", false)
			elseif root and t - w.Synced >= WALK_SYNC then
				w.Synced = t
				root.CFrame = w.From:Lerp(w.To, a)
			end
		elseif t >= w.Next then
			local root = model:FindFirstChild("HumanoidRootPart")
			if root then
				local target = randomWalkPoint(w.Plot)
				local goal = standCFrame(w.Plot, model, target, nil)
				local from = root.Position
				local face = CFrame.lookAt(from, Vector3.new(goal.X, from.Y, goal.Z))
				local dist = (goal.Position - from).Magnitude
				local dur = math.max(0.5, dist / WALK_SPEED)
				root.CFrame = face
				w.From, w.To, w.Start, w.Dur, w.Synced = face, face.Rotation + goal.Position, t, dur, t
				w.Moving = true
				model:SetAttribute("WalkFrom", w.From)
				model:SetAttribute("WalkTo", w.To)
				model:SetAttribute("WalkDur", dur)
				model:SetAttribute("WalkT0", workspace:GetServerTimeNow())
				model:SetAttribute("Moving", true)
			end
		end
	end
end

--------------------------------------------------------------------
-- Terrenos
--------------------------------------------------------------------
local VIP_GOLD = Color3.fromRGB(255, 205, 70)

local function setSign(plot: Model, text: string?, vip: boolean?)
	-- mapa v2: placa de madeira na frente da base (SurfaceGui); sem dono mostra "Base livre"
	local sign = plot:FindFirstChild("Sign")
	local face = sign and sign:FindFirstChild("SignFace")
	local label = face and face:FindFirstChild("OwnerGui") and face.OwnerGui:FindFirstChild("OwnerText")
	if label then
		label.Text = text or "Base livre"
		label.TextColor3 = if vip then Color3.fromRGB(200, 140, 20) elseif text then Color3.fromRGB(90, 52, 26) else Color3.fromRGB(150, 120, 95)
		return
	end
	local gate = plot:FindFirstChild("Gate")
	local part = gate and (gate.PrimaryPart or gate:FindFirstChildWhichIsA("BasePart", true))
	if not part then
		return
	end
	local bb = part:FindFirstChild("OwnerSign")
	if not text then
		if bb then
			bb:Destroy()
		end
		return
	end
	if not bb then
		bb = Instance.new("BillboardGui")
		bb.Name = "OwnerSign"
		bb.Size = UDim2.fromOffset(220, 40)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
		bb.MaxDistance = 120
		bb.Parent = part
		local l = Instance.new("TextLabel")
		l.Name = "Text"
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamBold
		l.TextScaled = true
		l.TextColor3 = Color3.fromRGB(255, 240, 200)
		l.TextStrokeTransparency = 0.3
		l.Parent = bb
	end
	bb.Text.Text = text
	bb.Text.TextColor3 = if vip then VIP_GOLD else Color3.fromRGB(255, 240, 200)
end

-- VIP (secao 9): aparencia de base = cerca e portao dourados e placa com a tag
local function setVipLook(plot: Model, vip: boolean)
	for _, folderName in { "Fence", "Gate" } do
		local f = plot:FindFirstChild(folderName)
		if f then
			for _, p in f:GetDescendants() do
				if p:IsA("BasePart") then
					if p:GetAttribute("BaseColor") == nil then
						p:SetAttribute("BaseColor", p.Color)
						p:SetAttribute("BaseMaterial", p.Material.Name)
					end
					if vip then
						p.Color = VIP_GOLD
						p.Material = Enum.Material.Metal
					else
						p.Color = p:GetAttribute("BaseColor")
						p.Material = Enum.Material[p:GetAttribute("BaseMaterial")]
					end
				end
			end
		end
	end
end

-- Placa e aparencia do terreno conforme os beneficios (chamado na entrada e quando um beneficio muda)
function BaseService.RefreshLook(player: Player)
	local plot = plotOf[player]
	local data = PlayerDataService.Get(player)
	if not plot or not data then
		return
	end
	local vip = data.Benefits.VIP ~= nil
	setSign(plot, (if vip then "\u{2605} VIP \u{2605}  " else "") .. "Base de " .. player.DisplayName, vip)
	setVipLook(plot, vip)
	sanitizeBase(data)
	syncNPCs(player)
end

local function plotsSorted()
	local list = workspace:WaitForChild("Plots"):GetChildren()
	table.sort(list, function(a, b)
		return (a:GetAttribute("PlotId") or 99) < (b:GetAttribute("PlotId") or 99)
	end)
	return list
end

local plotObserver = nil -- { OnAssigned(player, plot), OnReleased(plot) }

function BaseService.SetPlotObserver(onAssigned, onReleased)
	plotObserver = { OnAssigned = onAssigned, OnReleased = onReleased }
	for player, plot in pairs(plotOf) do
		if onAssigned then
			task.spawn(onAssigned, player, plot)
		end
	end
end

local function assignPlot(player: Player)
	if plotOf[player] then
		return plotOf[player]
	end
	for _, plot in ipairs(plotsSorted()) do
		if (plot:GetAttribute("OwnerUserId") or 0) == 0 then
			plot:SetAttribute("OwnerUserId", player.UserId)
			plotOf[player] = plot
			setSign(plot, "Base de " .. player.DisplayName)
			player:SetAttribute("PlotId", plot:GetAttribute("PlotId"))
			if plotObserver and plotObserver.OnAssigned then
				task.spawn(plotObserver.OnAssigned, player, plot)
			end
			return plot
		end
	end
	warn("[Base] Sem terreno livre para " .. player.Name)
	return nil
end

local function releasePlot(player: Player)
	local plot = plotOf[player]
	plotOf[player] = nil
	if plot then
		local folder = plot:FindFirstChild("BaseCharacters")
		if folder then
			for _, m in folder:GetChildren() do
				walkers[m] = nil
			end
			folder:ClearAllChildren()
		end
		if plotObserver and plotObserver.OnReleased then
			task.spawn(plotObserver.OnReleased, plot)
		end
		plot:SetAttribute("OwnerUserId", 0)
		setSign(plot, nil)
		setVipLook(plot, false)
	end
end

function BaseService.PlotOf(player: Player)
	return plotOf[player]
end

--------------------------------------------------------------------
-- Acoes do jogador
--------------------------------------------------------------------
local function changed(player: Player, saveNow: boolean?)
	PlayerDataService.MarkChanged(player)
	if saveNow then
		task.spawn(PlayerDataService.SaveNow, player)
	end
end

-- state = "Walk" | "Mine" | "None"
function BaseService.SetState(player: Player, uid, state)
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Dados ainda carregando."
	end
	if typeof(uid) ~= "string" or not data.Collection[uid] then
		return false, "Personagem inv\u{e1}lido."
	end
	if state ~= "Walk" and state ~= "Mine" and state ~= "None" then
		return false, "Estado inv\u{e1}lido."
	end
	if state ~= "None" and uid == trainingUidOf(data) then
		return false, "Personagem est\u{e1} na M\u{e1}quina de Treinamento."
	end
	accrue(data, false, true) -- fecha a conta com as taxas antigas
	sanitizeBase(data) -- tira da base quem foi vendido ou fundido (nao ocupa vaga)
	local b = data.Base
	local current = b.Active[uid]
	if state == "None" then
		b.Active[uid] = nil
	else
		local active, miners = 0, 0
		for _, s in pairs(b.Active) do
			active += 1
			if s == "Mine" then
				miners += 1
			end
		end
		if not current and active >= Base.MaxActive then
			return false, "A base j\u{e1} tem " .. Base.MaxActive .. " personagens ativos."
		end
		if state == "Mine" and current ~= "Mine" and miners >= Base.MiningSlots(data) then
			return false, "Todas as vagas de minera\u{e7}\u{e3}o est\u{e3}o ocupadas."
		end
		b.Active[uid] = state
	end
	syncNPCs(player)
	syncLiveRateAttr(player, data)
	changed(player, true)
	return true
end

function BaseService.Collect(player: Player)
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Dados ainda carregando."
	end
	accrue(data, false, true)
	local p = data.Base.Pending
	local gold = math.floor(p.Gold)
	local ore = math.floor(p.Ore)
	local space = math.max(0, Base.OreMax - data.Ore)
	local oreTaken = math.min(ore, space)

	data.TrainingOres = Training.SanitizeOres(data.TrainingOres, Training.MaxOrePerType)
	local pOres = p.Ores or Training.ZeroOres()
	local attrTaken = Training.ZeroOres()
	local attrSummary = {}
	local anyAttr = false
	for _, stat in ipairs(Training.OreOrder) do
		local avail = math.floor(pOres[stat] or 0)
		local room = math.max(0, Training.MaxOrePerType - (data.TrainingOres[stat] or 0))
		local take = math.min(avail, room)
		if take > 0 then
			anyAttr = true
			attrTaken[stat] = take
			data.TrainingOres[stat] += take
			pOres[stat] -= take
			table.insert(attrSummary, "+" .. fmt(take) .. " " .. Training.Ores[stat].Short)
		end
	end

	if gold <= 0 and oreTaken <= 0 and not anyAttr then
		if ore > 0 then
			return false, "Dep\u{f3}sito de min\u{e9}rio cheio (" .. fmt(Base.OreMax) .. "). Venda min\u{e9}rio na loja."
		end
		return false, "Nada para coletar ainda."
	end
	data.Gold += gold
	data.Ore += oreTaken
	p.Gold -= gold
	p.Ore -= oreTaken
	if gold > 0 then
		player:SetAttribute("LiveGold", data.Gold)
	end
	changed(player, true)
	RetentionService.Track(player, "Collect", 1)
	local attrTotal = 0
	for _, qty in pairs(attrTaken) do
		attrTotal += qty
	end
	local xpAmt = math.clamp(
		math.floor((gold + oreTaken + attrTotal * 5) / AccountLevel.XpSources.BaseCollectGoldDivisor),
		AccountLevel.XpSources.BaseCollectMin,
		AccountLevel.XpSources.BaseCollectMax
	)
	AccountLevelService.AddXp(player, xpAmt, "Coleta da Base", false)
	local parts = {}
	if gold > 0 then
		table.insert(parts, fmt(gold) .. " gold")
	end
	if oreTaken > 0 then
		table.insert(parts, fmt(oreTaken) .. " min.")
	end
	local text = if #parts > 0 then ("Coletou " .. table.concat(parts, " e ")) else "Coletou min\u{e9}rios de atributo"
	if anyAttr then
		text ..= " (" .. table.concat(attrSummary, ", ") .. ")"
	end
	if oreTaken < ore then
		text ..= " Dep\u{f3}sito cheio (" .. fmt(Base.OreMax) .. ")."
	end
	return true, text
end

function BaseService.UpgradeSlots(player: Player)
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Dados ainda carregando."
	end
	local cost = Base.NextSlotCost(data)
	if not cost then
		return false, "Vagas de minera\u{e7}\u{e3}o no m\u{e1}ximo."
	end
	if data.Gold < cost then
		return false, "Gold insuficiente (precisa de " .. fmt(cost) .. ")."
	end
	data.Gold -= cost
	data.Base.MiningSlots += 1
	changed(player, true)
	return true, "Nova vaga de minera\u{e7}\u{e3}o! Agora s\u{e3}o " .. Base.MiningSlots(data) .. "."
end

function BaseService.UpgradeMining(player: Player)
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Dados ainda carregando."
	end
	local cost = Base.NextMiningLevelCost(data)
	if not cost then
		return false, "Minera\u{e7}\u{e3}o j\u{e1} est\u{e1} no n\u{ed}vel m\u{e1}ximo."
	end
	if data.Gold < cost then
		return false, "Gold insuficiente (precisa de " .. fmt(cost) .. ")."
	end
	data.Gold -= cost
	local newLv = Base.MiningLevelOf(data) + 1
	data.Base.MiningLevel = newLv
	changed(player, true)
	local unlockedMsg = ""
	for _, stat in ipairs(Training.OreOrder) do
		local info = Training.Ores[stat]
		if info.UnlockMiningLevel == newLv then
			unlockedMsg = " Desbloqueou " .. info.Name .. "!"
		end
	end
	return true, "Minera\u{e7}\u{e3}o n\u{ed}vel " .. newLv .. "!" .. unlockedMsg
end

-- Venda de minerio por gemas com teto diario
function BaseService.SellOre(player: Player)
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Dados ainda carregando."
	end
	local day = Base.Day(now())
	if data.GemsSold.Day ~= day then
		data.GemsSold.Day = day
		data.GemsSold.Amount = 0
	end
	local left = Base.DailyGemCap - data.GemsSold.Amount
	if left <= 0 then
		return false, "Teto de " .. Base.DailyGemCap .. " gemas por dia atingido. Volte amanh\u{e3}."
	end
	local can = data.Ore // Base.OrePerGem
	if can <= 0 then
		return false, "Precisa de " .. Base.OrePerGem .. " de min\u{e9}rio para cada gema."
	end
	local gems = math.min(can, left)
	data.Ore -= gems * Base.OrePerGem
	data.Gems += gems
	data.GemsSold.Amount += gems
	changed(player, true)
	return true, "Vendeu " .. fmt(gems * Base.OrePerGem) .. " de min\u{e9}rio por " .. gems .. " gemas (" .. data.GemsSold.Amount .. "/" .. Base.DailyGemCap .. " hoje)."
end

function BaseService.TeleportHome(player: Player)
	local plot = plotOf[player]
	local char = player.Character
	if not plot or not char or not char:FindFirstChild("HumanoidRootPart") then
		return false, "Sem terreno."
	end
	local gate = plot:FindFirstChild("Gate")
	local center = plot:FindFirstChild("Center")
	local from = gate and gate:GetPivot().Position or plot:GetPivot().Position
	local to = center and center.Position or plot:GetPivot().Position
	pcall(function()
		player:RequestStreamAroundAsync(to, 3)
	end)
	char:PivotTo(CFrame.lookAt(from + (to - from).Unit * 6 + Vector3.new(0, 3, 0), to + Vector3.new(0, 3, 0)))
	return true
end

-- So no Studio: adianta o relogio como se o jogador tivesse ficado fora (limite de 8 horas)
function BaseService.AdvanceClock(player: Player?, seconds: number)
	if not RunService:IsStudio() then
		return nil
	end
	local data = player and PlayerDataService.Get(player)
	if data then
		accrue(data, false)
	end
	clockOffset += seconds
	ReplicatedStorage:SetAttribute("ClockOffset", clockOffset) -- o cliente mostra o dia certo
	if data then
		local gold, ore, dt = accrue(data, true)
		changed(player)
		return { Gold = gold, Ore = ore, Seconds = dt, Offset = clockOffset }
	end
	return { Offset = clockOffset }
end

--------------------------------------------------------------------
local function guarded(fn)
	return function(player, ...)
		if busy[player] then
			return false, "Aguarde."
		end
		busy[player] = true
		local ok, a, b = pcall(fn, player, ...)
		busy[player] = nil
		if not ok then
			warn("[Base] " .. tostring(a))
			return false, "Erro no servidor."
		end
		return a, b
	end
end

local function onLoaded(player: Player)
	local data = PlayerDataService.Get(player)
	if not data then
		return
	end
	assignPlot(player)
	BaseService.RefreshLook(player)
	-- o jogador nasce dentro da propria base (ao entrar e ao renascer)
	task.spawn(function()
		local char = player.Character or player.CharacterAdded:Wait()
		char:WaitForChild("HumanoidRootPart", 10)
		-- espera o cliente assumir o personagem (senao a posicao volta para o spawn)
		task.wait(1)
		if player.Parent and plotOf[player] then
			BaseService.TeleportHome(player)
		end
	end)
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.5)
		if plotOf[player] then
			BaseService.TeleportHome(player)
		end
	end)
	sanitizeBase(data)
	local gold, ore, dt = accrue(data, true) -- tempo fora, ate 8 horas
	syncNPCs(player)
	syncLiveRateAttr(player, data)
	player:SetAttribute("LiveGold", data.Gold)
	PlayerDataService.MarkChanged(player)
	if dt >= 60 and (gold >= 1 or ore >= 1) then
		task.delay(4, function()
			if player.Parent then
				notify(player, string.format("Enquanto voc\u{ea} esteve fora (%.1f h), sua base produziu %s gold e %s de min\u{e9}rio. Colete no menu Base.", dt / 3600, fmt(gold), fmt(ore)))
			end
		end)
	end
end

function BaseService.Init()
	if not Remotes:FindFirstChild("BaseUpgradeMining") then
		local rf = Instance.new("RemoteFunction")
		rf.Name = "BaseUpgradeMining"
		rf.Parent = Remotes
	end
	Remotes.BaseSetState.OnServerInvoke = guarded(BaseService.SetState)
	Remotes.BaseCollect.OnServerInvoke = guarded(BaseService.Collect)
	Remotes.BaseUpgrade.OnServerInvoke = guarded(BaseService.UpgradeSlots)
	Remotes.BaseUpgradeMining.OnServerInvoke = guarded(BaseService.UpgradeMining)
	Remotes.SellOre.OnServerInvoke = guarded(BaseService.SellOre)
	Remotes.BaseTeleport.OnServerInvoke = guarded(function(player)
		-- seguranca: sem teleporte no meio da batalha ou da torre
		local BattleService = require(ServerScriptService.Battle.BattleService)
		local TowerService = require(ServerScriptService.Tower.TowerService)
		if BattleService.IsInBattle(player) or TowerService.IsRunning(player) then
			return false, "N\u{e3}o d\u{e1} durante a batalha."
		end
		return BaseService.TeleportHome(player)
	end)

	PlayerDataService.Loaded:Connect(onLoaded)
	for _, p in ipairs(Players:GetPlayers()) do
		if PlayerDataService.Get(p) then
			task.spawn(onLoaded, p)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		local data = PlayerDataService.Get(player)
		if data then
			accrue(data, false, true)
		end
		releasePlot(player)
		busy[player] = nil
	end)

	-- producao com o jogador online: gold cai direto na carteira a cada 1s; perfil completo a cada 10s
	task.spawn(function()
		local step = 0
		while true do
			task.wait(LIVE_TICK)
			step += 1
			local fullSync = (step % SYNC_EVERY) == 0
			for _, player in ipairs(Players:GetPlayers()) do
				local data = PlayerDataService.Get(player)
				if data then
					-- quem foi vendido ou fundido sai da base
					local gone = false
					for uid in pairs(data.Base.Active) do
						if not data.Collection[uid] then
							data.Base.Active[uid] = nil
							gone = true
						end
					end
					if gone then
						syncNPCs(player)
					end
					local credited, _, _, liveRate = accrue(data, false, true)
					local roundedRate = math.floor((liveRate or 0) * 100 + 0.5) / 100
					if player:GetAttribute("LiveGoldRate") ~= roundedRate then
						player:SetAttribute("LiveGoldRate", roundedRate)
					end
					if credited >= 1 then
						player:SetAttribute("LiveGold", data.Gold)
					end
					if fullSync and next(data.Base.Active) then
						PlayerDataService.MarkChanged(player)
					end
				end
			end
		end
	end)
	-- passeio dos personagens
	task.spawn(function()
		while true do
			task.wait(0.25)
			walkStep()
		end
	end)
end

return BaseService
