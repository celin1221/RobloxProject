--[[
	BaseClient (cliente) - Controlador universal de animacoes padrao (Idle, Walk e Mine)
	para todos os personagens do jogo:
	  - PartyFollower (1o boneco com vida positiva da party seguindo o jogador)
	  - BaseCharacter (personagens passeando ou minerando nas bases)
	  - RefugeWild (personagens selvagens passeando no Refugio)
	  - BattleCharacter (personagens em campo na Arena enquanto aguardam turno)

	Logica da animacao padrao (60 FPS via Motor6D.Transform / Bone.Transform):
	  - Idle ("dar vida ao personagem"): ciclo continuo de respiracao no tronco, leve balanco
	    vertical, movimento sutil de cabeca/olhar e abertura suave dos bracos ao respirar.
	  - Walk ("apenas andar, seguindo a logica da animacao idle"): passada limpa alternando
	    pernas e bracos em oposicao, quique suave a cada passo, contra-rotacao natural de
	    quadril/tronco, combinada com a respiracao viva do Idle e transicao suave (walkAlpha).
	  - Adapta-se automaticamente tanto aos rigs em I-Pose (San, BarbaBranca, Luffy e novos Tripo)
	    quanto aos rigs R15/Skinned em A-Pose (Kaen, Raiko, Yomogi, Setero, Proto*).
	  - Cede controle automaticamente para animacoes de Mineracao (BaseState == "Mine") e para
	    qualquer animacao de golpe/dano/desmaio/vitoria na batalha.
]]

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local MAX_ANIM_DIST = 260
local TAGS = { "PartyFollower", "BaseCharacter", "RefugeWild", "BattleCharacter", "CapsuleCharacter" }
local MOTOR_TO_JOINT = {
	Root = "LowerTorso",
	Waist = "UpperTorso",
	Neck = "Head",
	LeftShoulder = "LeftUpperArm",
	LeftElbow = "LeftLowerArm",
	LeftWrist = "LeftHand",
	RightShoulder = "RightUpperArm",
	RightElbow = "RightLowerArm",
	RightWrist = "RightHand",
	LeftHip = "LeftUpperLeg",
	LeftKnee = "LeftLowerLeg",
	LeftAnkle = "LeftFoot",
	RightHip = "RightUpperLeg",
	RightKnee = "RightLowerLeg",
	RightAnkle = "RightFoot",
}

local rigs = {} -- [Model] = estado de animacao
local GRIP_OFFSET = CFrame.Angles(math.rad(-80), 0, 0)

local function makeWedge(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Size = size
	w.CFrame = cframe
	w.Color = color
	w.Material = material
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.CanCollide = false
	w.CanQuery = false
	w.CanTouch = false
	w.Massless = true
	w.Parent = parent
	return w
end

local function makeBox(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Parent = parent
	return p
end

local function buildPickaxe(scale: number, anchoredBone: boolean): (Model, BasePart, ParticleEmitter, { { Part: BasePart, Offset: CFrame } })
	local m = Instance.new("Model")
	m.Name = "MiningPickaxe"
	local wood = Color3.fromRGB(132, 82, 44)
	local leather = Color3.fromRGB(58, 38, 28)
	local iron = Color3.fromRGB(142, 152, 170)
	local steel = Color3.fromRGB(186, 196, 212)
	local edge = Color3.fromRGB(235, 152, 62)

	-- Handle orientado em +Y (o centro do punho fica a -0.82*s abaixo da origem do cabo)
	local handle = makeBox(m, "Handle", Vector3.new(0.16 * scale, 2.35 * scale, 0.16 * scale), CFrame.identity, wood, Enum.Material.SmoothPlastic)
	handle.Anchored = anchoredBone
	m.PrimaryPart = handle

	local defs = {
		{ makeBox(m, "GripWrap", Vector3.new(0.21 * scale, 0.62 * scale, 0.21 * scale), CFrame.new(0, -0.78 * scale, 0), leather, Enum.Material.SmoothPlastic), CFrame.new(0, -0.78 * scale, 0) },
		{ makeBox(m, "Pommel", Vector3.new(0.22 * scale, 0.15 * scale, 0.22 * scale), CFrame.new(0, -1.16 * scale, 0), iron, Enum.Material.SmoothPlastic), CFrame.new(0, -1.16 * scale, 0) },
		{ makeBox(m, "Collar", Vector3.new(0.28 * scale, 0.34 * scale, 0.30 * scale), CFrame.new(0, 0.94 * scale, 0), iron, Enum.Material.Metal), CFrame.new(0, 0.94 * scale, 0) },
		{ makeBox(m, "HeadCore", Vector3.new(0.24 * scale, 0.28 * scale, 0.70 * scale), CFrame.new(0, 0.98 * scale, 0), steel, Enum.Material.Metal), CFrame.new(0, 0.98 * scale, 0) },
		{ makeWedge(m, "FrontBlade", Vector3.new(0.16 * scale, 0.24 * scale, 0.72 * scale), CFrame.new(0, 0.91 * scale, -0.68 * scale) * CFrame.Angles(math.rad(-14), 0, 0), steel, Enum.Material.Metal), CFrame.new(0, 0.91 * scale, -0.68 * scale) * CFrame.Angles(math.rad(-14), 0, 0) },
		{ makeWedge(m, "BackBlade", Vector3.new(0.16 * scale, 0.24 * scale, 0.54 * scale), CFrame.new(0, 0.91 * scale, 0.59 * scale) * CFrame.Angles(math.rad(14), math.rad(180), 0), iron, Enum.Material.Metal), CFrame.new(0, 0.91 * scale, 0.59 * scale) * CFrame.Angles(math.rad(14), math.rad(180), 0) },
		{ makeBox(m, "FrontAccent", Vector3.new(0.20 * scale, 0.12 * scale, 0.20 * scale), CFrame.new(0, 0.94 * scale, -0.44 * scale), edge, Enum.Material.SmoothPlastic), CFrame.new(0, 0.94 * scale, -0.44 * scale) },
	}

	local tipAtt = Instance.new("Attachment")
	tipAtt.Name = "Tip"
	tipAtt.Position = Vector3.new(0, 0.84 * scale, -0.98 * scale)
	tipAtt.Parent = handle

	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "RockChips"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 210, 110), Color3.fromRGB(240, 130, 50))
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22 * scale), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.18, 0.32)
	sparks.Speed = NumberRange.new(4, 9)
	sparks.SpreadAngle = Vector2.new(70, 70)
	sparks.Acceleration = Vector3.new(0, -18, 0)
	sparks.Rate = 0
	sparks.Enabled = false
	sparks.Parent = tipAtt

	local subParts = {}
	for _, entry in ipairs(defs) do
		local p, rel = entry[1], entry[2]
		p.Anchored = anchoredBone
		table.insert(subParts, { Part = p, Offset = rel })
		if not anchoredBone then
			local w = Instance.new("Weld")
			w.Part0 = handle
			w.Part1 = p
			w.C0 = rel
			w.Parent = p
		end
	end
	return m, handle, sparks, subParts
end

local HAND_PARTS = {
	RightArm_Mesh = true,
	RightHand = true,
	RightLowerArm = true,
	RightUpperArm = true,
}

local function setHandAccessoriesHidden(st, hidden: boolean)
	if not hidden then
		if st.hiddenHandAccs then
			for part, origTrans in pairs(st.hiddenHandAccs) do
				if part and part.Parent then
					part.Transparency = origTrans
				end
			end
			st.hiddenHandAccs = nil
		end
		return
	end
	if st.hiddenHandAccs or not st.model then
		return
	end
	local hiddenMap = {}
	local function hideIfPart(p: BasePart)
		if not hiddenMap[p] then
			hiddenMap[p] = p.Transparency
			p.Transparency = 1
		end
	end
	for _, d in ipairs(st.model:GetDescendants()) do
		if string.sub(d.Name, -4) == "_Acc" then
			if d:IsA("BasePart") then
				local weldedToHand = false
				for _, jc in ipairs(d:GetDescendants()) do
					if jc:IsA("Weld") or jc:IsA("WeldConstraint") then
						local other = if jc.Part0 == d then jc.Part1 else jc.Part0
						if other and HAND_PARTS[other.Name] then
							weldedToHand = true
							break
						end
					end
				end
				if weldedToHand then
					hideIfPart(d)
				end
			elseif d:IsA("Model") then
				local weldedToHand = false
				for _, jc in ipairs(d:GetDescendants()) do
					if jc:IsA("Weld") or jc:IsA("WeldConstraint") then
						if (jc.Part0 and HAND_PARTS[jc.Part0.Name]) or (jc.Part1 and HAND_PARTS[jc.Part1.Name]) then
							weldedToHand = true
							break
						end
					end
				end
				if weldedToHand then
					for _, sub in ipairs(d:GetDescendants()) do
						if sub:IsA("BasePart") then
							hideIfPart(sub)
						end
					end
				end
			end
		end
	end
	if next(hiddenMap) then
		st.hiddenHandAccs = hiddenMap
	end
end

local function removePickaxe(st)
	if st.pickaxe then
		st.pickaxe:Destroy()
		st.pickaxe = nil
		st.pickaxeHandle = nil
		st.pickaxeBone = nil
		st.pickaxeOffset = nil
		st.pickaxeSparks = nil
	end
	setHandAccessoriesHidden(st, false)
end

local function ensurePickaxe(st)
	if st.pickaxe and st.pickaxe.Parent then
		return
	end
	if st.model then
		for _, ch in ipairs(st.model:GetChildren()) do
			if ch.Name == "MiningPickaxe" then
				ch:Destroy()
			end
		end
	end
	setHandAccessoriesHidden(st, true)
	local model = st.model
	local _, bboxSize = model:GetBoundingBox()
	local scale = math.clamp(bboxSize.Y / 6.0, 0.85, 1.50)
	local shaftShift = CFrame.new(0, 0.82 * scale, 0)

	local armMesh = model:FindFirstChild("RightArm_Mesh")
	local boneHand = st.joints and typeof(st.joints.RightHand) == "Instance" and st.joints.RightHand:IsA("Bone") and st.joints.RightHand or nil
	local partHand = model:FindFirstChild("RightHand")

	local attachPart, handOffset = nil, nil
	if armMesh and armMesh:IsA("BasePart") then
		attachPart = armMesh
		handOffset = CFrame.new(0, -armMesh.Size.Y * 0.40, -armMesh.Size.Z * 0.12) * GRIP_OFFSET * shaftShift
	elseif not boneHand and partHand and partHand:IsA("BasePart") then
		local wrist = partHand:FindFirstChild("RightWrist")
		local palm = if partHand.Size.Z > 1.5 and wrist and wrist:IsA("Motor6D")
			then wrist.C1 * CFrame.new(0, -0.14, -0.06)
			else CFrame.new(0, -partHand.Size.Y * 0.25, -0.04)
		attachPart = partHand
		handOffset = palm * GRIP_OFFSET * shaftShift
	end

	if attachPart and handOffset then
		local pick, handle, sparks, subParts = buildPickaxe(scale, false)
		local worldCF = attachPart.CFrame * handOffset
		handle.CFrame = worldCF
		for _, sub in ipairs(subParts) do
			sub.Part.CFrame = worldCF * sub.Offset
		end
		local weld = Instance.new("Weld")
		weld.Part0 = attachPart
		weld.Part1 = handle
		weld.C0 = handOffset
		weld.Parent = handle
		pick.Parent = model
		st.pickaxe = pick
		st.pickaxeHandle = handle
		st.pickaxeSparks = sparks
	elseif boneHand then
		local pick, handle, sparks = buildPickaxe(scale, true)
		local boneOffset = GRIP_OFFSET * shaftShift
		st.pickaxeBone = boneHand
		st.pickaxeOffset = boneOffset
		pick:PivotTo(boneHand.TransformedWorldCFrame * boneOffset)
		pick.Parent = model
		st.pickaxe = pick
		st.pickaxeHandle = handle
		st.pickaxeSparks = sparks
	end
end

local function loadMineTrack(model: Model): AnimationTrack?
	local folder = model:FindFirstChild("Animations")
	local anim = folder and folder:FindFirstChild("Mine")
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not anim or not hum then
		return nil
	end
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local ok, t = pcall(animator.LoadAnimation, animator, anim)
	if not ok or not t then
		return nil
	end
	t.Looped = true
	return t
end

local function collectJoints(model: Model): ({ [string]: any }, number)
	local map = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") then
			local key = MOTOR_TO_JOINT[d.Name] or (d.Part1 and d.Part1.Name) or (d.Parent and d.Parent.Name)
			if key then
				map[key] = d
			end
		elseif d:IsA("Bone") then
			map[d.Name] = map[d.Name] or d
		end
	end
	local count = 0
	for _ in pairs(map) do
		count += 1
	end
	return map, count
end

local function refreshRig(st)
	local model = st.model
	local joints, count = collectJoints(model)
	st.joints = joints
	st.jointCount = count
	st.isIPose = (model:FindFirstChild("LeftArm_Mesh") ~= nil) or (model:FindFirstChild("Torso_Mesh") ~= nil)
end

local settingUp: { [Model]: boolean } = {}
local lastRescan = 0

local function cleanupRig(model: Model, st)
	removePickaxe(st)
	if st.descConn then
		st.descConn:Disconnect()
		st.descConn = nil
	end
	rigs[model] = nil
end

local function setup(model: Instance, tag: string)
	if not model:IsA("Model") then
		return
	end
	local existing = rigs[model]
	if existing then
		if tag == "BattleCharacter" then
			existing.isBattle = true
		elseif tag == "PartyFollower" then
			existing.isFollower = true
		end
		refreshRig(existing)
		return
	end
	if settingUp[model] then
		return
	end
	settingUp[model] = true

	local hum = model:WaitForChild("Humanoid", 5)
	local root = model:WaitForChild("HumanoidRootPart", 5)
	settingUp[model] = nil
	if not hum or not root or not model.Parent or not root.Parent then
		return
	end
	if rigs[model] then
		return
	end
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local st = {
		model = model,
		root = root,
		hum = hum,
		animator = animator,
		joints = {},
		jointCount = 0,
		dirtyRig = false,
		isIPose = false,
		isBattle = (tag == "BattleCharacter"),
		isFollower = (tag == "PartyFollower"),
		isCapsule = (tag == "CapsuleCharacter"),
		mineTrack = nil,
		mineAlpha = 0,
		minePhase = math.random(),
		walkAlpha = 0,
		walkPhase = math.random() * math.pi * 2,
		seed = math.random() * math.pi * 2,
	}
	st.descConn = model.DescendantAdded:Connect(function(inst)
		if inst:IsA("Motor6D") or inst:IsA("Bone") or inst.Name == "LeftArm_Mesh" or inst.Name == "Torso_Mesh" then
			st.dirtyRig = true
		end
	end)
	refreshRig(st)
	rigs[model] = st
end

for _, tag in ipairs(TAGS) do
	for _, m in ipairs(CollectionService:GetTagged(tag)) do
		task.spawn(setup, m, tag)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(m)
		task.spawn(setup, m, tag)
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(m)
		local st = rigs[m]
		if st then
			cleanupRig(m :: Model, st)
		end
	end)
end

local function hasActiveCombatTrack(animator: Animator?): boolean
	if not animator then
		return false
	end
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track.IsPlaying and track.WeightCurrent > 0.02 then
			return true
		end
	end
	return false
end

local function setJoint(joints, name: string, cf: CFrame)
	local j = joints[name]
	if j then
		j.Transform = cf
	end
end

RunService.Stepped:Connect(function(now, dt)
	-- Autorecuperacao para modelos que voltaram via StreamingEnabled (ex.: retornar do Refugio/Arena para a Base)
	if now - lastRescan >= 0.35 then
		lastRescan = now
		for _, tag in ipairs(TAGS) do
			for _, m in ipairs(CollectionService:GetTagged(tag)) do
				if m:IsA("Model") and m.Parent and not rigs[m] and not settingUp[m] then
					if m:FindFirstChild("HumanoidRootPart") and m:FindFirstChildOfClass("Humanoid") then
						task.spawn(setup, m, tag)
					end
				end
			end
		end
	end

	if next(rigs) == nil then
		return
	end
	dt = math.clamp(dt, 1 / 240, 0.1)
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero

	for model, st in pairs(rigs) do
		if not model.Parent or not st.root or not st.root.Parent then
			cleanupRig(model, st)
			continue
		end

		local isMining = model:GetAttribute("BaseState") == "Mine"
		if st.mineTrack and st.mineTrack.IsPlaying then
			st.mineTrack:Stop(0.2)
		end
		if isMining then
			ensurePickaxe(st)
		elseif st.pickaxe then
			removePickaxe(st)
		end

		-- Em batalha: cede controle imediatamente para golpes, dano, desmaio ou vitoria
		if st.isBattle then
			if model:GetAttribute("Fainted") or model:GetAttribute("Victory") or hasActiveCombatTrack(st.animator) then
				continue
			end
		end

		if (st.root.Position - camPos).Magnitude > MAX_ANIM_DIST then
			continue
		end

		if st.dirtyRig or st.jointCount < 15 or (not st.isIPose and model:FindFirstChild("LeftArm_Mesh") ~= nil) then
			st.dirtyRig = false
			refreshRig(st)
		end

		if st.isCapsule then
			-- Flutuacao suave em gravidade zero dentro da Cupula de Vidro
			local phase = now * 2.1 + st.seed
			local floatY = 0.28 * math.sin(phase)
			local armWave = math.sin(phase * 0.85)
			local isReady = model:GetAttribute("CapsuleState") == "Ready"
			local liftArms = if isReady then math.rad(12) else 0
			local armOut = (if st.isIPose then math.rad(-14) else math.rad(36)) + math.rad(4 * armWave)
			local joints = st.joints
			setJoint(joints, "LowerTorso", CFrame.new(0, floatY, 0) * CFrame.Angles(math.rad(-3), math.rad(8 * math.sin(phase * 0.5)), 0))
			setJoint(joints, "UpperTorso", CFrame.Angles(math.rad(3 + 2 * math.cos(phase)), math.rad(-4 * math.sin(phase * 0.5)), 0))
			setJoint(joints, "Head", CFrame.Angles(math.rad(-6 + 3 * math.sin(phase)), math.rad(6 * math.cos(phase * 0.45)), 0))
			setJoint(joints, "LeftUpperArm", CFrame.Angles(math.rad(-14 - 5 * armWave) - liftArms, 0, armOut))
			setJoint(joints, "LeftLowerArm", CFrame.Angles(math.rad(22), 0, 0))
			setJoint(joints, "LeftHand", CFrame.identity)
			setJoint(joints, "RightUpperArm", CFrame.Angles(math.rad(-14 + 5 * armWave) - liftArms, 0, -armOut))
			setJoint(joints, "RightLowerArm", CFrame.Angles(math.rad(22), 0, 0))
			setJoint(joints, "RightHand", CFrame.identity)
			setJoint(joints, "LeftUpperLeg", CFrame.Angles(math.rad(12 + 4 * math.sin(phase)), 0, math.rad(-4)))
			setJoint(joints, "LeftLowerLeg", CFrame.Angles(math.rad(-16), 0, 0))
			setJoint(joints, "LeftFoot", CFrame.Angles(math.rad(-8), 0, 0))
			setJoint(joints, "RightUpperLeg", CFrame.Angles(math.rad(-6 - 4 * math.sin(phase)), 0, math.rad(4)))
			setJoint(joints, "RightLowerLeg", CFrame.Angles(math.rad(-12), 0, 0))
			setJoint(joints, "RightFoot", CFrame.Angles(math.rad(-8), 0, 0))
			continue
		end

		local moving = (not isMining) and (model:GetAttribute("Moving") == true)
		local targetWalk = if moving then 1 else 0
		st.walkAlpha += (targetWalk - st.walkAlpha) * math.min(1, dt * 10)
		local w = st.walkAlpha

		local targetMine = if isMining then 1 else 0
		st.mineAlpha += (targetMine - st.mineAlpha) * math.min(1, dt * 8)
		local m = st.mineAlpha

		-- Fase continua de Idle (respiracao e vida do personagem)
		local idlePhase = now * 2.4 + st.seed
		local breath = math.sin(idlePhase)
		local sway = math.sin(idlePhase * 0.5)
		local lookWave = math.sin(idlePhase * 0.42)

		-- Fase de Walk ("apenas andar", avançando quando em movimento)
		local walkFreq = if st.isFollower then 11.0 else 8.5
		if w > 0.01 then
			st.walkPhase = (st.walkPhase + dt * walkFreq) % (math.pi * 2)
		end
		local s = math.sin(st.walkPhase)
		local c = math.cos(st.walkPhase)
		local stepBounce = math.abs(s)

		-- Ciclo polido de Mineracao (windup overhead -> impacto rapido -> recoil -> retorno)
		local mineArmDeg, mineLeftArmDeg, mineElbowDeg = 55, 16, 18
		local mineTorsoXDeg, mineTorsoYDeg, mineHipDrop, mineHeadDeg = 0, 0, 0, 0
		if m > 0.01 then
			local prevP = st.minePhase
			st.minePhase = (st.minePhase + dt * 0.92) % 1
			local p = st.minePhase
			if isMining and prevP < 0.58 and p >= 0.58 and st.pickaxeSparks then
				st.pickaxeSparks:Emit(5)
			end
			if p < 0.44 then
				local u = p / 0.44
				local ease = u * u * (3 - 2 * u)
				mineArmDeg = 55 + (158 - 55) * ease
				mineLeftArmDeg = 16 + 18 * ease
				mineElbowDeg = 16 + 18 * ease
				mineTorsoXDeg = 2 + 8 * ease
				mineTorsoYDeg = 4 - 18 * ease
				mineHipDrop = -0.05 * ease
				mineHeadDeg = -3 + 7 * ease
			elseif p < 0.58 then
				local u = (p - 0.44) / 0.14
				local strike = u * u
				mineArmDeg = 158 + (46 - 158) * strike
				mineLeftArmDeg = 34 - 22 * strike
				mineElbowDeg = 34 - 18 * strike
				mineTorsoXDeg = 10 - 23 * strike
				mineTorsoYDeg = -14 + 28 * strike
				mineHipDrop = -0.05 - 0.08 * strike
				mineHeadDeg = 4 - 12 * strike
			elseif p < 0.72 then
				local u = (p - 0.58) / 0.14
				local recoil = math.sin(u * math.pi)
				mineArmDeg = 46 + 10 * recoil
				mineLeftArmDeg = 12 + 4 * recoil
				mineElbowDeg = 16 + 6 * recoil
				mineTorsoXDeg = -13 + 5 * recoil
				mineTorsoYDeg = 14 - 4 * recoil
				mineHipDrop = -0.13 + 0.04 * recoil
				mineHeadDeg = -8 + 3 * recoil
			else
				local u = (p - 0.72) / 0.28
				local rec = u * u * (3 - 2 * u)
				mineArmDeg = 46 + (55 - 46) * rec
				mineLeftArmDeg = 12 + (16 - 12) * rec
				mineElbowDeg = 16 + (18 - 16) * rec
				mineTorsoXDeg = -13 + (2 - (-13)) * rec
				mineTorsoYDeg = 14 + (4 - 14) * rec
				mineHipDrop = -0.13 * (1 - rec)
				mineHeadDeg = -8 + (-3 - (-8)) * rec
			end
		end

		local liveW = 1 - m * 0.7

		-- 1. LowerTorso (respiracao no Idle + passo no Walk + flexao na Mineracao)
		local idleBobY = 0.05 * breath * (1 - 0.5 * w) * liveW + mineHipDrop * m
		local walkBobY = (0.09 * stepBounce - 0.035) * w
		local hipRotX = math.rad(-1.5 * w - 2.0 * m)
		local hipRotY = math.rad(1.8 * sway * (1 - w) * liveW - 4.5 * s * w + mineTorsoYDeg * 0.35 * m)
		local hipRotZ = math.rad(0.8 * sway * (1 - w) * liveW + 1.5 * c * w)

		-- 2. UpperTorso (expansao no Idle + inclinacao no Walk + giro de ombro na Mineracao)
		local torsoRotX = math.rad(((-1.8 + 2.2 * breath) * (1 - 0.3 * w) - 3.0 * w) * liveW + mineTorsoXDeg * m)
		local torsoRotY = math.rad((-1.5 * sway * (1 - w) + 5.5 * s * w) * liveW + mineTorsoYDeg * m)
		local torsoRotZ = math.rad((1.0 * math.cos(idlePhase * 0.5) * (1 - 0.5 * w) - 1.2 * c * w) * liveW)

		-- 3. Head (compensacao da respiracao + foco na pedra durante Mineracao)
		local headRotX = math.rad(((1.4 - 1.8 * breath) + 1.2 * (stepBounce - 0.5) * w) * liveW + mineHeadDeg * m)
		local headRotY = math.rad((3.2 * lookWave * (1 - 0.6 * w) - 1.8 * s * w) * liveW - mineTorsoYDeg * 0.45 * m)
		local headRotZ = math.rad(-0.8 * sway * (1 - w) * liveW)

		-- 4. Bracos (respiracao no Idle + balanco no Walk + golpe com picareta na Mineracao)
		local armBaseZ = if st.isIPose then math.rad(-4.5) else math.rad(32.0)
		local elbowBaseX = if st.isIPose then 0 else math.rad(15.0)
		local idleArmFlare = math.rad(2.0 * (0.5 + 0.5 * breath))
		local idleArmSwing = math.rad(2.8 * math.cos(idlePhase)) * (1 - 0.6 * w) * liveW

		local leftArmX = (math.rad(-24.0 * s) * w + idleArmSwing) * (1 - m) + math.rad(mineLeftArmDeg) * m
		local rightArmX = (math.rad(24.0 * s) * w - idleArmSwing) * (1 - m) + math.rad(mineArmDeg) * m
		local leftArmZ = armBaseZ - idleArmFlare
		local rightArmZ = (-armBaseZ + idleArmFlare) * (1 - m * 0.72) - math.rad(4.0) * m

		local leftElbowX = elbowBaseX + (if st.isIPose then 0 else (math.rad(10.0 * math.max(0, -s)) * w * (1 - m) + math.rad(2.5 * (0.5 + 0.5 * breath)) + math.rad(12) * m))
		local rightElbowX = elbowBaseX + (if st.isIPose then 0 else (math.rad(10.0 * math.max(0, s)) * w * (1 - m) + math.rad(2.5 * (0.5 + 0.5 * breath)) + math.rad(mineElbowDeg) * m))

		-- 5. Pernas (postura viva no Idle + passada no Walk + base firme na Mineracao)
		local strideAngle = 27.0
		local leftHipX = math.rad(strideAngle * s) * w * (1 - m) + math.rad(1.4 * breath) * (1 - w) * liveW + math.rad(6.0) * m
		local rightHipX = math.rad(-strideAngle * s) * w * (1 - m) - math.rad(1.4 * breath) * (1 - w) * liveW - math.rad(6.0) * m
		local leftHipZ = math.rad(-1.0) * (1 - w) + math.rad(-4.0) * m
		local rightHipZ = math.rad(1.0) * (1 - w) + math.rad(4.0) * m

		local leftKneeX = 0
		local rightKneeX = 0
		local leftFootX = 0
		local rightFootX = 0
		if not st.isIPose then
			leftKneeX = math.rad(-8.0 - 16.0 * math.max(0, -c)) * w + math.rad(-3.0 + 1.5 * breath) * (1 - w)
			rightKneeX = math.rad(-8.0 - 16.0 * math.max(0, c)) * w + math.rad(-3.0 + 1.5 * breath) * (1 - w)
			leftFootX = math.rad(-6.0 * s) * w + math.rad(1.5) * (1 - w)
			rightFootX = math.rad(6.0 * s) * w + math.rad(1.5) * (1 - w)
		end

		local joints = st.joints
		setJoint(joints, "LowerTorso", CFrame.new(0, idleBobY + walkBobY, 0) * CFrame.Angles(hipRotX, hipRotY, hipRotZ))
		setJoint(joints, "UpperTorso", CFrame.Angles(torsoRotX, torsoRotY, torsoRotZ))
		setJoint(joints, "Head", CFrame.Angles(headRotX, headRotY, headRotZ))

		setJoint(joints, "LeftUpperArm", CFrame.Angles(leftArmX, 0, leftArmZ))
		setJoint(joints, "LeftLowerArm", CFrame.Angles(leftElbowX, 0, 0))
		setJoint(joints, "LeftHand", CFrame.identity)

		setJoint(joints, "RightUpperArm", CFrame.Angles(rightArmX, 0, rightArmZ))
		setJoint(joints, "RightLowerArm", CFrame.Angles(rightElbowX, 0, 0))
		setJoint(joints, "RightHand", CFrame.identity)

		setJoint(joints, "LeftUpperLeg", CFrame.Angles(leftHipX, 0, leftHipZ))
		setJoint(joints, "LeftLowerLeg", CFrame.Angles(leftKneeX, 0, 0))
		setJoint(joints, "LeftFoot", CFrame.Angles(leftFootX, 0, 0))

		setJoint(joints, "RightUpperLeg", CFrame.Angles(rightHipX, 0, rightHipZ))
		setJoint(joints, "RightLowerLeg", CFrame.Angles(rightKneeX, 0, 0))
		setJoint(joints, "RightFoot", CFrame.Angles(rightFootX, 0, 0))
	end
end)

-- Atualiza picaretas presas a ossos (rigs Skinned Mesh como Setero) apos o passo da animacao
RunService.RenderStepped:Connect(function()
	for model, st in pairs(rigs) do
		if st.pickaxe and st.pickaxeBone and st.pickaxeOffset and model.Parent then
			st.pickaxe:PivotTo(st.pickaxeBone.TransformedWorldCFrame * st.pickaxeOffset)
		end
	end
end)
