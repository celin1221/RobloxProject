--[[
	TrainingService (GDD secao 8 - Maquina de Treinamento / Cupula de Vidro)
	- Cada base (Plot) recebe uma Cupula de Vidro fisica (TrainingCapsule) com painel frontal e ProximityPrompt.
	- Enquanto houver um treino ativo (data.TrainingMachine.Job), o modelo 3D do personagem fica suspenso dentro
	  da cupula recebendo energia, bloqueado de minerar/passear/entrar em batalha ou ser fundido/vendido.
	- Toda validacao, calculo de custo (4 minerios por atributo + raridade + multi-atributo), duracao,
	  upgrade de eficiencia (gold) e aplicacao dos ganhos (passos de 20 ate 100) rodam no servidor.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

local Data = ReplicatedStorage:WaitForChild("Data")
local Characters = require(Data.Characters)
local Genetics = require(Data:WaitForChild("Genetics"))
local Training = require(Data:WaitForChild("Training"))

local PlayerDataService = require(ServerScriptService:WaitForChild("Data"):WaitForChild("PlayerDataService"))
local BaseService = require(ServerScriptService:WaitForChild("Economy"):WaitForChild("BaseService"))
local CharacterLibrary = require(ServerScriptService:WaitForChild("CharacterLibrary"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local TrainingService = {}

local busy = {}
local activeCapsules = {} -- [Plot] = { Model, CharacterModel, LastKey, LastReady }

local function now(): number
	return BaseService.Now()
end

local function fmt(n: number): string
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", ""))
end

local function fmtTime(sec: number): string
	sec = math.max(0, math.floor(sec))
	local m = sec // 60
	local s = sec % 60
	return string.format("%02d:%02d", m, s)
end

local function changed(player: Player, saveNow: boolean?)
	PlayerDataService.MarkChanged(player)
	if saveNow then
		task.spawn(PlayerDataService.SaveNow, player)
	end
end

local function ensureRemote(name: string, className: string)
	local existing = Remotes:FindFirstChild(name)
	if existing then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = Remotes
	return inst
end

--------------------------------------------------------------------
-- Modelo 3D fisico da Cupula de Vidro no Terreno (Plot)
--------------------------------------------------------------------
local function makePart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = opts.Shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.Transparency = opts.Transparency or 0
	p.Anchored = true
	p.CanCollide = if opts.CanCollide ~= nil then opts.CanCollide else true
	p.CanQuery = if opts.CanQuery ~= nil then opts.CanQuery else true
	p.CanTouch = false
	p.CastShadow = if opts.CastShadow ~= nil then opts.CastShadow else true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function buildCapsuleModel(plot: Model): Model
	local old = plot:FindFirstChild("TrainingCapsule")
	if old then
		old:Destroy()
	end
	local floor = plot:FindFirstChild("Floor")
	local centerPart = plot:FindFirstChild("Center")
	local floorTopY = if floor then floor.Position.Y + floor.Size.Y * 0.5 else plot:GetPivot().Position.Y
	-- Canto frontal direito do terreno (deixa o patio aberto)
	local originPos = if floor then (floor.CFrame * CFrame.new(14.5, floor.Size.Y * 0.5, -14.2)).Position else (plot:GetPivot().Position + Vector3.new(14.5, 0, -14.2))
	local lookTarget = if centerPart then Vector3.new(centerPart.Position.X, floorTopY, centerPart.Position.Z) else (originPos + Vector3.new(-1, 0, 1))
	local baseCF = CFrame.lookAt(Vector3.new(originPos.X, floorTopY, originPos.Z), lookTarget)

	local model = Instance.new("Model")
	model.Name = "TrainingCapsule"

	local darkMetal = Color3.fromRGB(34, 40, 62)
	local steel = Color3.fromRGB(72, 84, 118)
	local goldTrim = Color3.fromRGB(232, 184, 72)
	local idleGlow = Color3.fromRGB(92, 175, 225)
	local uprightCyl = CFrame.Angles(0, 0, math.pi / 2)

	-- Base tecnologica escalonada (Collision ativa no pedestal)
	local lowerRim = makePart(model, "LowerRim", Vector3.new(0.32, 7.0, 7.0), baseCF * CFrame.new(0, 0.16, 0) * uprightCyl, goldTrim, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	makePart(model, "BasePlinth", Vector3.new(0.75, 6.6, 6.6), baseCF * CFrame.new(0, 0.52, 0) * uprightCyl, darkMetal, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	local ringBottom = makePart(model, "EnergyRingBottom", Vector3.new(0.22, 6.0, 6.0), baseCF * CFrame.new(0, 0.96, 0) * uprightCyl, idleGlow, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder, CanCollide = false })
	local hoverPad = makePart(model, "HoverPad", Vector3.new(0.24, 4.0, 4.0), baseCF * CFrame.new(0, 1.06, 0) * uprightCyl, steel, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder, CanCollide = false })

	-- Cilindro de vidro translucido (cupula alta o bastante ate para personagens gigantes)
	local glass = makePart(model, "GlassDome", Vector3.new(9.8, 5.9, 5.9), baseCF * CFrame.new(0, 5.95, 0) * uprightCyl, Color3.fromRGB(145, 238, 255), Enum.Material.Glass, {
		Shape = Enum.PartType.Cylinder,
		Transparency = 0.72,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})

	-- 4 hastes estruturais ao redor da cupula de vidro
	for k = 0, 3 do
		local ang = math.rad(45 + k * 90)
		local rx, rz = math.cos(ang) * 3.1, math.sin(ang) * 3.1
		makePart(model, "Strut" .. (k + 1), Vector3.new(0.38, 10.2, 0.38), baseCF * CFrame.new(rx, 6.0, rz), steel, Enum.Material.Metal)
	end

	-- Tampa superior da capsula
	local ringTop = makePart(model, "EnergyRingTop", Vector3.new(0.22, 6.1, 6.1), baseCF * CFrame.new(0, 10.8, 0) * uprightCyl, idleGlow, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder, CanCollide = false })
	makePart(model, "UpperCap", Vector3.new(0.85, 6.9, 6.9), baseCF * CFrame.new(0, 11.28, 0) * uprightCyl, darkMetal, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	local crown = makePart(model, "TopCrown", Vector3.new(0.42, 4.2, 4.2), baseCF * CFrame.new(0, 11.85, 0) * uprightCyl, steel, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	makePart(model, "CrownTrim", Vector3.new(0.18, 4.5, 4.5), baseCF * CFrame.new(0, 11.68, 0) * uprightCyl, goldTrim, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder, CanCollide = false })

	-- Luz interna suave e emissor de energia dentro da cupula
	local core = makePart(model, "CoreAnchor", Vector3.new(1, 1, 1), baseCF * CFrame.new(0, 4.6, 0), idleGlow, Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
	local light = Instance.new("PointLight")
	light.Name = "CapsuleLight"
	light.Color = idleGlow
	light.Range = 14
	light.Brightness = 0.3
	light.Shadows = false
	light.Parent = core

	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0, 0.15, 0)
	att.Parent = hoverPad
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "EnergyBubbles"
	emitter.Texture = "rbxassetid://117703775594396"
	emitter.Color = ColorSequence.new(Color3.fromRGB(95, 240, 255), Color3.fromRGB(220, 255, 255))
	emitter.LightEmission = 0.75
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(1.5, 2.5)
	emitter.Speed = NumberRange.new(2.2, 3.8)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.SpreadAngle = Vector2.new(14, 14)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(0.6, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(0.8, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = att

	-- Painel frontal de controle + ProximityPrompt (no lado da praca interna da base)
	local consoleCF = baseCF * CFrame.new(0, 1.45, -3.9)
	local consoleStand = makePart(model, "ConsoleStand", Vector3.new(2.0, 2.9, 0.95), consoleCF, darkMetal, Enum.Material.Metal)
	makePart(model, "ConsoleScreen", Vector3.new(1.65, 1.05, 0.16), consoleCF * CFrame.new(0, 0.68, -0.42) * CFrame.Angles(math.rad(-22), 0, 0), Color3.fromRGB(56, 224, 240), Enum.Material.Neon, { CanCollide = false })

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TrainingPrompt"
	prompt.ActionText = "Treinar"
	prompt.ObjectText = "C\u{e1}psula de Treino"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = consoleStand

	-- Etiqueta flutuante acima da cupula
	local bb = Instance.new("BillboardGui")
	bb.Name = "StatusGui"
	bb.Size = UDim2.fromOffset(220, 52)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 2.8, 0)
	bb.MaxDistance = 75
	bb.AlwaysOnTop = true
	bb.Parent = crown
	local lbl = Instance.new("TextLabel")
	lbl.Name = "Label"
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	lbl.TextStrokeTransparency = 0.25
	lbl.TextColor3 = Color3.fromRGB(160, 242, 255)
	lbl.Text = "C\u{e1}psula de Treino \u{b7} Nv. 1"
	lbl.Parent = bb

	-- Guarnece referencias uteis
	model:SetAttribute("BasePosition", baseCF.Position)
	model.PrimaryPart = lowerRim
	model.Parent = plot
	return model
end

local function bindPrompt(plot: Model, capsule: Model)
	local stand = capsule:FindFirstChild("ConsoleStand")
	local prompt = stand and stand:FindFirstChild("TrainingPrompt")
	if not prompt or prompt:GetAttribute("Bound") then
		return
	end
	prompt:SetAttribute("Bound", true)
	prompt.Triggered:Connect(function(player)
		if plot:GetAttribute("OwnerUserId") ~= player.UserId then
			Remotes.Notify:FireClient(player, "S\u{f3} o dono desta base pode usar a C\u{e1}psula.")
			return
		end
		Remotes.TrainingOpen:FireClient(player)
	end)
end

local function clearCapsuleVisuals(plot: Model)
	local state = activeCapsules[plot]
	if state and state.CharModel then
		state.CharModel:Destroy()
		state.CharModel = nil
	end
	local capsule = plot:FindFirstChild("TrainingCapsule")
	if capsule then
		local charFolder = capsule:FindFirstChild("InsideChar")
		if charFolder then
			charFolder:Destroy()
		end
		local rb = capsule:FindFirstChild("EnergyRingBottom")
		local rt = capsule:FindFirstChild("EnergyRingTop")
		local core = capsule:FindFirstChild("CoreAnchor")
		local hp = capsule:FindFirstChild("HoverPad")
		local crown = capsule:FindFirstChild("TopCrown")
		local idle = Color3.fromRGB(92, 175, 225)
		if rb then rb.Color = idle end
		if rt then rt.Color = idle end
		if core and core:FindFirstChild("CapsuleLight") then
			core.CapsuleLight.Color = idle
			core.CapsuleLight.Brightness = 0.3
		end
		if hp and hp:FindFirstChild("Attachment") and hp.Attachment:FindFirstChild("EnergyBubbles") then
			hp.Attachment.EnergyBubbles.Rate = 0
		end
		if crown and crown:FindFirstChild("StatusGui") then
			local lbl = crown.StatusGui.Label
			lbl.Text = "C\u{e1}psula de Treino"
			lbl.TextColor3 = Color3.fromRGB(160, 242, 255)
		end
		local stand = capsule:FindFirstChild("ConsoleStand")
		local prompt = stand and stand:FindFirstChild("TrainingPrompt")
		if prompt then
			prompt.ActionText = "Treinar"
		end
	end
	if state then
		state.LastKey = nil
		state.LastReady = nil
	end
end

local function syncPlotCapsule(player: Player?, plot: Model?)
	if not plot then
		return
	end
	local capsule = plot:FindFirstChild("TrainingCapsule")
	if not capsule then
		capsule = buildCapsuleModel(plot)
	end
	bindPrompt(plot, capsule)

	local data = player and PlayerDataService.Get(player)
	if not data then
		clearCapsuleVisuals(plot)
		return
	end

	local lvl = Training.MachineLevelOf(data)
	local job = data.TrainingMachine and data.TrainingMachine.Job
	local member = job and job.Uid and data.Collection[job.Uid]
	local def = member and Characters.Get(member.CharacterId)

	local rb = capsule:FindFirstChild("EnergyRingBottom")
	local rt = capsule:FindFirstChild("EnergyRingTop")
	local core = capsule:FindFirstChild("CoreAnchor")
	local hp = capsule:FindFirstChild("HoverPad")
	local crown = capsule:FindFirstChild("TopCrown")
	local stand = capsule:FindFirstChild("ConsoleStand")
	local prompt = stand and stand:FindFirstChild("TrainingPrompt")
	local lbl = crown and crown:FindFirstChild("StatusGui") and crown.StatusGui:FindFirstChild("Label")
	local bubbles = hp and hp:FindFirstChild("Attachment") and hp.Attachment:FindFirstChild("EnergyBubbles")

	local state = activeCapsules[plot]
	if not state then
		state = { Model = capsule }
		activeCapsules[plot] = state
	end

	if not (job and def) then
		if state.CharModel then
			state.CharModel:Destroy()
			state.CharModel = nil
		end
		state.LastKey = nil
		state.LastReady = nil
		local idle = Color3.fromRGB(92, 175, 225)
		if rb then rb.Color = idle end
		if rt then rt.Color = idle end
		if core and core:FindFirstChild("CapsuleLight") then
			core.CapsuleLight.Color = idle
			core.CapsuleLight.Brightness = 0.3
		end
		if bubbles then bubbles.Rate = 0 end
		if lbl then
			lbl.Text = "C\u{e1}psula de Treino \u{b7} Nv. " .. lvl
			lbl.TextColor3 = Color3.fromRGB(160, 242, 255)
		end
		if prompt then prompt.ActionText = "Treinar" end
		return
	end

	local remaining = math.max(0, (job.EndsAt or 0) - now())
	local ready = remaining <= 0
	local glowColor = if ready then Color3.fromRGB(75, 232, 128) else Color3.fromRGB(56, 235, 255)

	if rb then rb.Color = glowColor end
	if rt then rt.Color = glowColor end
	if core and core:FindFirstChild("CapsuleLight") then
		core.CapsuleLight.Color = glowColor
		core.CapsuleLight.Brightness = if ready then 0.95 else 0.75
	end
	if bubbles then
		bubbles.Rate = if ready then 22 else 16
		bubbles.Color = ColorSequence.new(glowColor, Color3.fromRGB(235, 255, 255))
	end
	if lbl then
		if ready then
			lbl.Text = string.format("\u{2713} %s PRONTO!\nRESGATAR TREINO", def.Name)
		else
			lbl.Text = string.format("Treinando %s\n%s restante", def.Name, fmtTime(remaining))
		end
		lbl.TextColor3 = glowColor
	end
	if prompt then
		prompt.ActionText = if ready then "Resgatar" else "Ver Treino"
	end

	-- Spawna/mantem o modelo 3D dentro da cupula de vidro
	local key = tostring(job.Uid) .. "|" .. tostring(def.ModelName)
	if state.LastKey ~= key or not state.CharModel or not state.CharModel.Parent then
		if state.CharModel then
			state.CharModel:Destroy()
		end
		local charModel = CharacterLibrary.Spawn(def.ModelName, nil, nil)
		charModel.Name = "InsideChar"
		local root = charModel:FindFirstChild("HumanoidRootPart")
		local hum = charModel:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		for _, d in charModel:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		if root and hp then
			root.Anchored = true
			local hip = hum and hum.HipHeight or 2
			local y = hp.Position.Y + 1.5 + hip + root.Size.Y * 0.5
			local padCF = capsule.PrimaryPart and capsule.PrimaryPart.CFrame or capsule:GetPivot()
			-- baseCF olhava para o centro; orienta o boneco de frente para o console
			local forward = if stand then (Vector3.new(stand.Position.X, y, stand.Position.Z) - Vector3.new(hp.Position.X, y, hp.Position.Z)) else Vector3.new(0, 0, -1)
			local targetLook = Vector3.new(hp.Position.X, y, hp.Position.Z) + (if forward.Magnitude > 0.05 then forward.Unit else Vector3.new(0, 0, -1))
			charModel:PivotTo(CFrame.lookAt(Vector3.new(hp.Position.X, y, hp.Position.Z), targetLook))
		end
		charModel:SetAttribute("CapsuleState", if ready then "Ready" else "Training")
		charModel.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		CollectionService:AddTag(charModel, "CapsuleCharacter")
		charModel.Parent = capsule
		state.CharModel = charModel
		state.LastKey = key
	elseif state.LastReady ~= ready and state.CharModel then
		state.CharModel:SetAttribute("CapsuleState", if ready then "Ready" else "Training")
	end
	state.LastReady = ready
end

function TrainingService.SyncCapsule(player: Player)
	syncPlotCapsule(player, BaseService.PlotOf(player))
end

--------------------------------------------------------------------
-- Acoes do Jogador (validacao 100% no servidor)
--------------------------------------------------------------------
function TrainingService.Start(player: Player, uid, rawTargets): (boolean, string?)
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Dados ainda carregando."
	end
	if not data.StarterChosen then
		return false, "Escolha seu personagem inicial primeiro."
	end
	local BattleService = require(ServerScriptService.Battle.BattleService)
	local TowerService = require(ServerScriptService.Tower.TowerService)
	if BattleService.IsInBattle(player) or TowerService.IsRunning(player) then
		return false, "N\u{e3}o d\u{e1} para iniciar treino durante uma batalha."
	end
	if data.TrainingMachine and data.TrainingMachine.Job then
		return false, "A c\u{e1}psula j\u{e1} est\u{e1} ocupada."
	end
	if typeof(uid) ~= "string" or not data.Collection[uid] then
		return false, "Personagem inv\u{e1}lido."
	end
	local member = data.Collection[uid]
	local def = Characters.Get(member.CharacterId)
	if not def then
		return false, "Personagem desconhecido."
	end

	local cleanTargets, _, _, _, err = Training.ValidateTargets(member, rawTargets)
	if not cleanTargets then
		return false, err or "Configura\u{e7}\u{e3}o inv\u{e1}lida."
	end

	-- Verifica se e o unico personagem do time de batalha
	local inTeamIdx = table.find(data.Team, uid)
	if inTeamIdx and #data.Team <= 1 then
		return false, "Deixe outro personagem no time antes de treinar este."
	end

	-- Verifica minerios necessarios
	data.TrainingOres = Training.SanitizeOres(data.TrainingOres, Training.MaxOrePerType)
	local cost = Training.CalculateCost(def.Rarity, cleanTargets)
	for _, stat in ipairs(Training.OreOrder) do
		local need = cost[stat] or 0
		if need > 0 and (data.TrainingOres[stat] or 0) < need then
			return false, string.format("Falta %s (%d/%d).", Training.Ores[stat].Name, data.TrainingOres[stat] or 0, need)
		end
	end

	-- Deduz minerios, remove da base ativa e (se estava no time) tira do time
	for _, stat in ipairs(Training.OreOrder) do
		data.TrainingOres[stat] = (data.TrainingOres[stat] or 0) - (cost[stat] or 0)
	end
	local removedFromTeam = false
	if inTeamIdx then
		table.remove(data.Team, inTeamIdx)
		removedFromTeam = true
	end
	if data.Base and data.Base.Active and data.Base.Active[uid] then
		BaseService.Accrue(data, false)
		data.Base.Active[uid] = nil
		BaseService.SyncNPCs(player)
	end

	local mLevel = Training.MachineLevelOf(data)
	local duration = Training.CalculateDuration(mLevel, def.Rarity, cleanTargets)
	local t0 = now()
	data.TrainingMachine = data.TrainingMachine or { Level = mLevel }
	data.TrainingMachine.Job = {
		Uid = uid,
		Targets = cleanTargets,
		Cost = cost,
		StartedAt = t0,
		EndsAt = t0 + duration,
		Duration = duration,
	}

	syncPlotCapsule(player, BaseService.PlotOf(player))
	changed(player, true)
	local msg = def.Name .. " entrou na C\u{e1}psula (" .. fmtTime(duration) .. ")."
	if removedFromTeam then
		msg ..= " Saiu do time durante o treino."
	end
	return true, msg
end

function TrainingService.Claim(player: Player): (boolean, string?)
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Dados ainda carregando."
	end
	local job = data.TrainingMachine and data.TrainingMachine.Job
	if not job then
		return false, "Nenhum treino em andamento."
	end
	local left = (job.EndsAt or 0) - now()
	if left > 0 then
		return false, "Ainda falta " .. fmtTime(left) .. " para concluir."
	end
	local member = data.Collection[job.Uid]
	if member then
		member.Training = Genetics.SanitizeTable(member.Training)
		local gains = {}
		for _, stat in ipairs(Training.Stats) do
			local addVal = job.Targets and job.Targets[stat] or 0
			if addVal > 0 then
				local before = member.Training[stat] or 0
				member.Training[stat] = math.clamp(before + addVal, Genetics.Min, Genetics.Max)
				local realGain = member.Training[stat] - before
				if realGain > 0 then
					table.insert(gains, Genetics.StatLabels[stat].Short .. " +" .. realGain .. "%")
				end
			end
		end
		data.TrainingMachine.Job = nil
		syncPlotCapsule(player, BaseService.PlotOf(player))
		changed(player, true)
		local def = Characters.Get(member.CharacterId)
		return true, (def and def.Name or "Personagem") .. " concluiu o treino! (" .. table.concat(gains, " · ") .. ")"
	end
	data.TrainingMachine.Job = nil
	syncPlotCapsule(player, BaseService.PlotOf(player))
	changed(player, true)
	return true, "C\u{e1}psula liberada."
end

function TrainingService.Cancel(player: Player): (boolean, string?)
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Dados ainda carregando."
	end
	local job = data.TrainingMachine and data.TrainingMachine.Job
	if not job then
		return false, "Nenhum treino para cancelar."
	end
	if now() >= (job.EndsAt or 0) then
		return TrainingService.Claim(player)
	end
	data.TrainingOres = Training.SanitizeOres(data.TrainingOres, Training.MaxOrePerType)
	local refunded = {}
	for _, stat in ipairs(Training.OreOrder) do
		local spent = job.Cost and job.Cost[stat] or 0
		local back = math.floor(spent * Training.CancelRefundRatio)
		if back > 0 then
			data.TrainingOres[stat] = math.min(Training.MaxOrePerType, (data.TrainingOres[stat] or 0) + back)
			table.insert(refunded, "+" .. back .. " " .. Training.Ores[stat].Short)
		end
	end
	data.TrainingMachine.Job = nil
	syncPlotCapsule(player, BaseService.PlotOf(player))
	changed(player, true)
	local extra = if #refunded > 0 then " (" .. table.concat(refunded, ", ") .. ")" else ""
	return true, "Treino cancelado. 50% dos min\u{e9}rios devolvidos" .. extra .. "."
end

function TrainingService.Upgrade(player: Player): (boolean, string?)
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Dados ainda carregando."
	end
	local cur = Training.MachineLevelOf(data)
	local cost = Training.NextMachineCost(cur)
	if not cost then
		return false, "M\u{e1}quina j\u{e1} est\u{e1} no n\u{ed}vel m\u{e1}ximo."
	end
	if data.Gold < cost then
		return false, "Gold insuficiente (precisa de " .. fmt(cost) .. ")."
	end
	data.Gold -= cost
	local nextLv = cur + 1
	data.TrainingMachine = data.TrainingMachine or {}
	data.TrainingMachine.Level = nextLv
	syncPlotCapsule(player, BaseService.PlotOf(player))
	changed(player, true)
	return true, string.format("M\u{e1}quina Nv. %d! Efici\u{ea}ncia %.2fx.", nextLv, Training.SpeedMultiplier(nextLv))
end

local function guarded(fn)
	return function(player, ...)
		if busy[player] then
			return false, "Aguarde."
		end
		busy[player] = true
		local ok, a, b = pcall(fn, player, ...)
		busy[player] = nil
		if not ok then
			warn("[Training] " .. tostring(a))
			return false, "Erro no servidor."
		end
		return a, b
	end
end

function TrainingService.Init()
	ensureRemote("TrainingOpen", "RemoteEvent")
	local rfStart = ensureRemote("TrainingStart", "RemoteFunction")
	local rfClaim = ensureRemote("TrainingClaim", "RemoteFunction")
	local rfCancel = ensureRemote("TrainingCancel", "RemoteFunction")
	local rfUpgrade = ensureRemote("TrainingUpgrade", "RemoteFunction")

	rfStart.OnServerInvoke = guarded(TrainingService.Start)
	rfClaim.OnServerInvoke = guarded(TrainingService.Claim)
	rfCancel.OnServerInvoke = guarded(TrainingService.Cancel)
	rfUpgrade.OnServerInvoke = guarded(TrainingService.Upgrade)

	local plots = workspace:FindFirstChild("Plots")
	if plots then
		for _, plot in ipairs(plots:GetChildren()) do
			local capsule = plot:FindFirstChild("TrainingCapsule") or buildCapsuleModel(plot)
			bindPrompt(plot, capsule)
		end
	end

	BaseService.SetPlotObserver(function(player)
		syncPlotCapsule(player, BaseService.PlotOf(player))
	end, function(plot)
		clearCapsuleVisuals(plot)
	end)

	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)

	-- Atualiza contagem regressiva e transicao Training -> Ready na etiqueta da cupula a cada 1s
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = PlayerDataService.Get(player)
				if data and data.TrainingMachine and data.TrainingMachine.Job then
					syncPlotCapsule(player, BaseService.PlotOf(player))
				end
			end
		end
	end)
end

TrainingService.EnsureCapsuleModel = buildCapsuleModel

return TrainingService
