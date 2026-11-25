--!strict
--[[
	ReplicatedStorage/HollowPurple/HollowPurpleVFX.luau
	Orquestrador cinematografico principal das 5 fases do "Vazio Roxo" (Hollow Purple - Gojo Satoru / Setero):
	  - Fase 1 (0.00s - 1.20s): Conjuracao Lapso Azul (implosao gravitacional a esquerda)
	  - Fase 2 (1.20s - 2.40s): Reversao Vermelho (pressao explosiva a direita)
	  - Fase 3 (2.40s - 4.00s): Orbita espiral + Impact Frame (3.50s) + Singularidade de 5 camadas
	  - Fase 4 (4.00s - 6.80s): Estalo de dedos + Disparo continuo (Mach rings, tripla helice, Ground Carving, raios)
	  - Fase 5 (6.80s - 9.00s): Implosao pre-impacto + Cataclismo Roxo (domos, pilar celestial, cratera, brasas)
	100% procedural (zero assets quebrados), dt-driven (60-240 FPS), Distance Culling e limpeza absoluta via Janitor.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(script.Parent:WaitForChild("Config"))
local Janitor = require(script.Parent:WaitForChild("Janitor"))
local LightningModule = require(script.Parent:WaitForChild("LightningModule"))
local DebrisModule = require(script.Parent:WaitForChild("DebrisModule"))
local CameraEffects = require(script.Parent:WaitForChild("CameraEffects"))
local LightingEffects = require(script.Parent:WaitForChild("LightingEffects"))

export type CastParams = {
	CastId: string,
	CasterModel: Model,
	AimDirection: Vector3,
	TimeScale: number?, -- 1.0 padrao (modo R livre); >1 permite corte compacto em batalha por turnos (Setero)
	TargetPositionOverride: Vector3?, -- opcional para detonar exatamente sobre o time inimigo em batalha
	EnableCameraAndLighting: boolean?,
}

export type ActiveCastHandle = {
	CastId: string,
	SyncLaunch: (origin: Vector3, direction: Vector3, maxTravelDist: number) -> (),
	Destroy: () -> (),
}

local HollowPurpleVFX = {}

local activeCasts: { [string]: ActiveCastHandle } = {}
local rng = Random.new()

--------------------------------------------------------------------
-- Utilitarios de Container, Culling e Primitivas Procedurais
--------------------------------------------------------------------
function HollowPurpleVFX.GetContainer(): Folder
	local existing = workspace:FindFirstChild(Config.WorkspaceFolderName)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = Config.WorkspaceFolderName
	folder.Parent = workspace
	return folder
end

local function getCameraDistance(pos: Vector3): number
	local cam = workspace.CurrentCamera
	if not cam then
		return 0.0
	end
	return (cam.CFrame.Position - pos).Magnitude
end

local function makePart(
	parent: Instance,
	name: string,
	shape: Enum.PartType,
	material: Enum.Material,
	color: Color3,
	size: Vector3,
	transparency: number
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Material = material
	p.Color = color
	p.Size = size
	p.Transparency = transparency
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function makeSpecialSphere(
	parent: Instance,
	name: string,
	material: Enum.Material,
	color: Color3,
	radius: number,
	transparency: number,
	invertScale: boolean?
): (Part, SpecialMesh)
	local d = math.max(0.05, radius * 2.0)
	local p = makePart(parent, name, Enum.PartType.Block, material, color, Vector3.new(1, 1, 1), transparency)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	local sign = if invertScale then -1.0 else 1.0
	mesh.Scale = Vector3.new(d * sign, d * sign, d)
	mesh.Parent = p
	return p, mesh
end

local function playConfiguredSound(parent: Instance, assetId: string, volume: number, playbackSpeed: number, looped: boolean?): Sound?
	if assetId == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = assetId
	s.Volume = volume
	s.PlaybackSpeed = playbackSpeed
	s.Looped = looped == true
	local grp = SoundService:FindFirstChild("Efeitos")
	if grp and grp:IsA("SoundGroup") then
		s.SoundGroup = grp
	end
	s.Parent = parent
	s:Play()
	return s
end

local function createTrailBetween(
	parent: Instance,
	att0: Attachment,
	att1: Attachment,
	c0: Color3,
	c1: Color3,
	lifetime: number,
	lightEmission: number
): Trail
	local tr = Instance.new("Trail")
	tr.Attachment0 = att0
	tr.Attachment1 = att1
	local customTex = Config.ResolveTexture("Trail")
	if customTex ~= "" then
		tr.Texture = customTex
	end
	tr.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.new(1, 1, 1):Lerp(c0, 0.35)),
		ColorSequenceKeypoint.new(0.35, c0),
		ColorSequenceKeypoint.new(1.0, c1),
	})
	tr.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 0.05),
		NumberSequenceKeypoint.new(0.55, 0.32),
		NumberSequenceKeypoint.new(1.0, 1.0),
	})
	tr.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 1.0),
		NumberSequenceKeypoint.new(0.7, 0.55),
		NumberSequenceKeypoint.new(1.0, 0.0),
	})
	tr.Lifetime = lifetime
	tr.MinLength = 0.05
	tr.FaceCamera = true
	tr.LightEmission = lightEmission
	tr.Brightness = 2.4
	tr.Parent = parent
	return tr
end

-- Anel 3D oco verdadeiro (poligono circular de segmentos Neon, zero disco chapado!)
local function spawnHollowShockRing(
	parent: Instance,
	centerCF: CFrame,
	startRadius: number,
	endRadius: number,
	startThickness: number,
	endThickness: number,
	color: Color3,
	duration: number,
	segmentCount: number,
	inward: boolean,
	janitor: Janitor.JanitorInstance
)
	if not parent.Parent then
		return
	end
	local segs: { Part } = {}
	local n = math.clamp(segmentCount, 10, 20)
	local ringModel = Instance.new("Model")
	ringModel.Name = "HollowShockRing"
	ringModel.Parent = parent
	janitor:Add(ringModel)

	for i = 1, n do
		local seg = makePart(
			ringModel,
			"RingSeg_" .. tostring(i),
			Enum.PartType.Block,
			Enum.Material.Neon,
			color,
			Vector3.new(startThickness, startThickness, 1.0),
			if inward then 0.82 else 0.06
		)
		table.insert(segs, seg)
	end

	local elapsed = 0.0
	local conn: RBXScriptConnection? = nil
	conn = janitor:Connect(RunService.Heartbeat, function(dt: number)
		elapsed += math.min(dt, 0.05)
		local rawA = math.clamp(elapsed / math.max(0.04, duration), 0, 1)
		local eased = if inward then (rawA * rawA * rawA) else (1 - (1 - rawA) ^ 4)
		local r = startRadius + (endRadius - startRadius) * eased
		local thick = math.max(0.03, startThickness + (endThickness - startThickness) * eased)
		local trans = if inward then (0.85 * (1 - rawA) + 0.08 * rawA) else (0.06 + 0.94 * (rawA * rawA))
		local chord = 2.0 * r * math.sin(math.pi / n) * 1.08

		for i = 1, n do
			local seg = segs[i]
			if seg.Parent then
				local ang = ((i - 0.5) / n) * math.pi * 2
				local localPos = Vector3.new(math.cos(ang) * r, math.sin(ang) * r, 0)
				local tangent = Vector3.new(-math.sin(ang), math.cos(ang), 0)
				local worldP = centerCF:PointToWorldSpace(localPos)
				local worldTan = centerCF:VectorToWorldSpace(tangent)
				seg.Size = Vector3.new(thick, thick, math.max(0.06, chord))
				seg.Transparency = trans
				seg.CFrame = CFrame.lookAt(worldP, worldP + worldTan)
			end
		end

		if rawA >= 1.0 then
			if conn and conn.Connected then
				conn:Disconnect()
			end
			if ringModel.Parent then
				ringModel:Destroy()
			end
		end
	end)
end

--------------------------------------------------------------------
-- Construtor de Esferas Multicamadas (Azul, Vermelho e Vazio Roxo 5 Camadas)
--------------------------------------------------------------------
type TriOrb = {
	Root: Part,
	CoreMesh: SpecialMesh,
	MidPart: Part,
	MidMesh: SpecialMesh,
	ShellPart: Part,
	ShellMesh: SpecialMesh,
	Light: PointLight,
	Trail: Trail,
	Particles: ParticleEmitter,
	SetCFrame: (cf: CFrame, shellJitter: Vector3?) -> (),
	SetScale: (radius: number, shellPulse: number) -> (),
	FadeOutAndDestroy: (dur: number) -> (),
}

local function createTriLayerOrb(
	parent: Instance,
	label: string,
	coreColor: Color3,
	midColor: Color3,
	shellColor: Color3,
	lightColor: Color3,
	midTrans: number,
	inwardSuction: boolean,
	janitor: Janitor.JanitorInstance
): TriOrb
	local corePart, coreMesh = makeSpecialSphere(parent, label .. "_Core", Enum.Material.Neon, coreColor, 0.2, 0.0, false)
	local midPart, midMesh = makeSpecialSphere(parent, label .. "_Mid", Enum.Material.Neon, midColor, 0.3, midTrans, false)
	local shellPart, shellMesh = makeSpecialSphere(parent, label .. "_Shell", Enum.Material.ForceField, shellColor, 0.4, 0.22, false)
	janitor:Add(corePart)
	janitor:Add(midPart)
	janitor:Add(shellPart)

	local light = Instance.new("PointLight")
	light.Name = label .. "_Light"
	light.Color = lightColor
	light.Brightness = 3.6
	light.Range = 20.0
	light.Shadows = false
	light.Parent = corePart

	local att0 = Instance.new("Attachment")
	att0.Position = Vector3.new(0, 1.25, 0)
	att0.Parent = corePart
	local att1 = Instance.new("Attachment")
	att1.Position = Vector3.new(0, -1.25, 0)
	att1.Parent = corePart
	local tr = createTrailBetween(corePart, att0, att1, midColor, shellColor, 0.34, 0.95)
	tr.Enabled = false

	local pe = Instance.new("ParticleEmitter")
	pe.Texture = Config.ResolveTexture("Spark")
	pe.Color = ColorSequence.new(coreColor, midColor)
	pe.LightEmission = 1.0
	pe.Brightness = 2.6
	pe.Orientation = Enum.ParticleOrientation.VelocityParallel
	pe.Squash = NumberSequence.new(1.1)
	if inwardSuction then
		pe.Shape = Enum.ParticleEmitterShape.Sphere
		pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		pe.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
		pe.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.08),
			NumberSequenceKeypoint.new(0.4, 0.42),
			NumberSequenceKeypoint.new(1, 0.05),
		})
		pe.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.25, 0.08),
			NumberSequenceKeypoint.new(1, 0.9),
		})
		pe.Speed = NumberRange.new(10.0, 18.0)
		pe.Lifetime = NumberRange.new(0.22, 0.36)
		pe.Rate = 48
	else
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.46),
			NumberSequenceKeypoint.new(0.6, 0.24),
			NumberSequenceKeypoint.new(1, 0),
		})
		pe.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.04),
			NumberSequenceKeypoint.new(0.7, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		})
		pe.Speed = NumberRange.new(14.0, 28.0)
		pe.Drag = 3.4
		pe.Lifetime = NumberRange.new(0.22, 0.38)
		pe.Rate = 54
	end
	pe.Parent = midPart

	return {
		Root = corePart,
		CoreMesh = coreMesh,
		MidPart = midPart,
		MidMesh = midMesh,
		ShellPart = shellPart,
		ShellMesh = shellMesh,
		Light = light,
		Trail = tr,
		Particles = pe,
		SetCFrame = function(cf: CFrame, shellJitter: Vector3?)
			corePart.CFrame = cf
			midPart.CFrame = cf
			shellPart.CFrame = if shellJitter then (cf + shellJitter) else cf
		end,
		SetScale = function(radius: number, shellPulse: number)
			local dCore = math.max(0.08, radius * 1.15)
			local dMid = math.max(0.12, radius * 1.95)
			local dShell = math.max(0.16, radius * 2.45 * shellPulse)
			coreMesh.Scale = Vector3.new(dCore, dCore, dCore)
			midPart.Size = Vector3.new(dMid, dMid, dMid)
			midMesh.Scale = Vector3.new(1, 1, 1)
			shellMesh.Scale = Vector3.new(dShell, dShell, dShell)
		end,
		FadeOutAndDestroy = function(dur: number)
			pe.Enabled = false
			tr.Enabled = false
			local ti = TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			for _, part in ipairs({ corePart, midPart, shellPart }) do
				if part.Parent then
					TweenService:Create(part, ti, { Transparency = 1 }):Play()
				end
			end
			TweenService:Create(light, ti, { Brightness = 0 }):Play()
		end,
	}
end

--------------------------------------------------------------------
-- Coreografia Corporal Procedural (Gojo Satoru / Setero)
--------------------------------------------------------------------
local JOINT_MAP: { [string]: string } = {
	Root = "LowerTorso",
	Waist = "UpperTorso",
	Neck = "Head",
	LeftShoulder = "LeftUpperArm",
	LeftElbow = "LeftLowerArm",
	RightShoulder = "RightUpperArm",
	RightElbow = "RightLowerArm",
}

local function degCF(rx: number, ry: number, rz: number, pos: Vector3?): CFrame
	local rot = CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
	return if pos then (CFrame.new(pos) * rot) else rot
end

local function attachProceduralCasterPose(caster: Model, totalWindup: number, timeScale: number, janitor: Janitor.JanitorInstance)
	if Config.Assets.CastAnimationId ~= "" then
		local hum = caster:FindFirstChildOfClass("Humanoid")
		local animator = hum and hum:FindFirstChildOfClass("Animator")
		if animator then
			local anim = Instance.new("Animation")
			anim.AnimationId = Config.Assets.CastAnimationId
			janitor:Add(anim)
			local ok, track = pcall(function()
				return animator:LoadAnimation(anim)
			end)
			if ok and track then
				track.Priority = Enum.AnimationPriority.Action4
				track:Play(0.1)
				track:AdjustSpeed(timeScale)
				janitor:Add(function()
					pcall(function()
						track:Stop(0.2)
					end)
				end)
				return
			end
		end
	end

	local joints: { [string]: Motor6D | Bone } = {}
	for _, d in ipairs(caster:GetDescendants()) do
		if d:IsA("Motor6D") then
			local key = JOINT_MAP[d.Name] or (d.Part1 and d.Part1.Name)
			if key then
				joints[key] = d
			end
		elseif d:IsA("Bone") then
			if joints[d.Name] == nil then
				joints[d.Name] = d
			end
		end
	end
	if next(joints) == nil then
		return
	end

	local isIPose = (caster:FindFirstChild("LeftArm_Mesh") ~= nil) or (caster:FindFirstChild("Torso_Mesh") ~= nil)
	local armDelta = if isIPose then 0 else math.rad(30)
	local elapsed = 0.0
	local poseDuration = (totalWindup + 0.75) / math.max(0.2, timeScale)

	local function resetJoints()
		for _, j in pairs(joints) do
			pcall(function()
				(j :: any).Transform = CFrame.identity
			end)
		end
	end
	janitor:Add(resetJoints)

	local conn: RBXScriptConnection? = nil
	conn = janitor:Connect(RunService.Stepped, function(_, dt: number)
		if not caster.Parent then
			if conn and conn.Connected then
				conn:Disconnect()
			end
			return
		end
		elapsed += math.min(dt, 0.05) * timeScale
		if elapsed >= totalWindup + 0.75 then
			resetJoints()
			if conn and conn.Connected then
				conn:Disconnect()
			end
			return
		end

		local lArm = CFrame.identity
		local lFore = CFrame.identity
		local rArm = CFrame.identity
		local rFore = CFrame.identity
		local uTorso = CFrame.identity
		local lTorso = CFrame.identity
		local head = CFrame.identity

		if elapsed < 1.20 then
			-- Fase 1: Mao esquerda erguida conjurando Lapso Azul
			local a = math.clamp(elapsed / 0.35, 0, 1)
			lArm = CFrame.identity:Lerp(degCF(86, 22, -26), a)
			lFore = CFrame.identity:Lerp(degCF(14, 0, 0), a)
			rArm = CFrame.identity:Lerp(degCF(12, 0, 8), a)
			uTorso = CFrame.identity:Lerp(degCF(4, -14, 0), a)
			head = CFrame.identity:Lerp(degCF(-4, 16, 0), a)
		elseif elapsed < 2.40 then
			-- Fase 2: Mao direita sobe conjurando Reversao Vermelho enquanto esquerda sustenta Azul
			local a = math.clamp((elapsed - 1.20) / 0.30, 0, 1)
			lArm = degCF(86, 22, -26)
			lFore = degCF(14, 0, 0)
			rArm = degCF(12, 0, 8):Lerp(degCF(86, -22, 26), a)
			rFore = CFrame.identity:Lerp(degCF(14, 0, 0), a)
			uTorso = degCF(4, -14, 0):Lerp(degCF(6, 0, 0), a)
			head = degCF(-4, 16, 0):Lerp(degCF(-6, 0, 0), a)
		elseif elapsed < 4.15 then
			-- Fase 3: Maos convergem diante do peito formando o Vazio Roxo + leve levitacao
			local a = math.clamp((elapsed - 2.40) / 1.10, 0, 1)
			lTorso = CFrame.identity:Lerp(degCF(2, 0, 0, Vector3.new(0, 0.38, 0)), a)
			uTorso = degCF(6, 0, 0):Lerp(degCF(10, -8, 0), a)
			head = degCF(-6, 0, 0):Lerp(degCF(-8, 8, 0), a)
			lArm = degCF(86, 22, -26):Lerp(degCF(74, -18, 22), a)
			lFore = degCF(14, 0, 0):Lerp(degCF(52, 0, 0), a)
			rArm = degCF(86, -22, 26):Lerp(degCF(92, 14, -14), a)
			rFore = degCF(14, 0, 0):Lerp(degCF(38, 0, 0), a)
		else
			-- Fase 4: Estalo de dedos e projecao explosiva para frente -> retorno suave
			local post = elapsed - 4.15
			if post < 0.25 then
				local a = math.clamp(post / 0.12, 0, 1)
				lTorso = degCF(-8, 16, 0, Vector3.new(0, 0.12, -0.35))
				uTorso = degCF(-12, 22, 4)
				head = degCF(8, -22, 0)
				rArm = degCF(92, 14, -14):Lerp(degCF(104, 4, 8), a)
				rFore = degCF(38, 0, 0):Lerp(degCF(4, 0, 0), a)
				lArm = degCF(74, -18, 22):Lerp(degCF(32, -14, -36), a)
			else
				local a = math.clamp((post - 0.25) / 0.50, 0, 1)
				lTorso = degCF(-8, 16, 0, Vector3.new(0, 0.12, -0.35)):Lerp(CFrame.identity, a)
				uTorso = degCF(-12, 22, 4):Lerp(CFrame.identity, a)
				head = degCF(8, -22, 0):Lerp(CFrame.identity, a)
				rArm = degCF(104, 4, 8):Lerp(CFrame.identity, a)
				lArm = degCF(32, -14, -36):Lerp(CFrame.identity, a)
			end
		end

		if armDelta ~= 0 then
			lArm = lArm * CFrame.Angles(0, 0, armDelta)
			rArm = rArm * CFrame.Angles(0, 0, -armDelta)
		end

		if joints.LowerTorso then
			(joints.LowerTorso :: any).Transform = lTorso
		end
		if joints.UpperTorso then
			(joints.UpperTorso :: any).Transform = uTorso
		end
		if joints.Head then
			(joints.Head :: any).Transform = head
		end
		if joints.LeftUpperArm then
			(joints.LeftUpperArm :: any).Transform = lArm
		end
		if joints.LeftLowerArm then
			(joints.LeftLowerArm :: any).Transform = lFore
		end
		if joints.RightUpperArm then
			(joints.RightUpperArm :: any).Transform = rArm
		end
		if joints.RightLowerArm then
			(joints.RightLowerArm :: any).Transform = rFore
		end
	end)
	local _ = poseDuration
end

--------------------------------------------------------------------
-- Feedback Instantaneo de Hit em Inimigos / Dummies (Fase 4)
--------------------------------------------------------------------
function HollowPurpleVFX.PlayHitImpact(hitPos: Vector3)
	if getCameraDistance(hitPos) > Config.MaxRenderDistance then
		return
	end
	local container = HollowPurpleVFX.GetContainer()
	local hitJanitor = Janitor.new()

	local anchor = makePart(container, "HollowPurpleHitFX", Enum.PartType.Block, Enum.Material.SmoothPlastic, Color3.new(1, 1, 1), Vector3.new(0.2, 0.2, 0.2), 1)
	anchor.CFrame = CFrame.new(hitPos)
	hitJanitor:Add(anchor)

	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = Config.ResolveTexture("Spark")
	sparks.Color = ColorSequence.new(Config.Colors.VoidWhite, Config.Colors.VoidMain)
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.75),
		NumberSequenceKeypoint.new(0.5, 0.38),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.02),
		NumberSequenceKeypoint.new(0.7, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparks.Speed = NumberRange.new(18, 42)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Lifetime = NumberRange.new(0.18, 0.34)
	sparks.LightEmission = 1.0
	sparks.Brightness = 3.0
	sparks.Orientation = Enum.ParticleOrientation.VelocityParallel
	sparks.Squash = NumberSequence.new(1.25)
	sparks.Drag = 3.2
	sparks.Rate = 0
	sparks.Parent = anchor
	sparks:Emit(26)

	playConfiguredSound(anchor, Config.Assets.HitSoundId, 0.55, rng:NextNumber(0.94, 1.08), false)

	local randomRot = CFrame.new(hitPos) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3))
	spawnHollowShockRing(container, randomRot, 1.2, 8.5, 0.32, 0.04, Config.Colors.VoidMagenta, 0.24, 12, false, hitJanitor)
	LightningModule.BurstAround(container, hitPos, 0.6, 5.4, 3, false, {
		InnerColor = Config.Colors.VoidWhite,
		OuterColor = Config.Colors.VoidMain,
		Thickness = 0.18,
		Duration = 0.14,
		BranchChance = 0.25,
	}, hitJanitor)

	CameraEffects.AddTrauma(0.22, hitPos, 28.0, 2.2)

	task.delay(0.55, function()
		hitJanitor:Cleanup()
	end)
end

--------------------------------------------------------------------
-- Execucao Completa das 5 Fases (Vazio Roxo)
--------------------------------------------------------------------
function HollowPurpleVFX.PlayCast(params: CastParams): ActiveCastHandle
	local castId = params.CastId
	if activeCasts[castId] then
		activeCasts[castId].Destroy()
	end

	local caster = params.CasterModel
	local hrp = (caster:FindFirstChild("HumanoidRootPart") or caster.PrimaryPart) :: BasePart?
	local timeScale = math.max(0.25, params.TimeScale or 1.0)
	local useCamAndLight = params.EnableCameraAndLighting ~= false

	local janitor = Janitor.new()
	local container = HollowPurpleVFX.GetContainer()
	local castFolder = Instance.new("Folder")
	castFolder.Name = "Cast_" .. castId
	castFolder.Parent = container
	janitor:Add(castFolder)

	local initialCenter = if hrp then hrp.Position else Vector3.zero
	if getCameraDistance(initialCenter) > Config.MaxRenderDistance then
		-- Muito distante: limpa imediatamente para economizar CPU/GPU
		local noopHandle: ActiveCastHandle = {
			CastId = castId,
			SyncLaunch = function() end,
			Destroy = function()
				activeCasts[castId] = nil
				janitor:Cleanup()
			end,
		}
		return noopHandle
	end

	local reducedDetail = getCameraDistance(initialCenter) > Config.ReducedDetailDistance
	local sessionId = "HP_" .. castId

	if useCamAndLight and not reducedDetail then
		CameraEffects.BeginSession(sessionId)
		LightingEffects.BeginSession(sessionId)
		janitor:Add(function()
			CameraEffects.EndSession(sessionId, 0.55)
			LightingEffects.EndSession(sessionId, 0.65)
		end)
	end

	-- Anima o conjurador (e tambem o seguidor Setero caso esteja ao lado do jogador!)
	attachProceduralCasterPose(caster, Config.Timing.Phase4LaunchTime, timeScale, janitor)
	if Config.AlsoAnimateSeteroFollower then
		local followersFolder = workspace:FindFirstChild("PartyFollowers")
		local ownerPlr = Players:GetPlayerFromCharacter(caster)
		if followersFolder and ownerPlr then
			local fol = followersFolder:FindFirstChild("Follower_" .. ownerPlr.Name)
			if fol and fol:IsA("Model") and fol ~= caster then
				attachProceduralCasterPose(fol, Config.Timing.Phase4LaunchTime, timeScale, janitor)
			end
		end
	end

	-- Estado dinamico sincronizado entre fases
	local aimDir = if params.AimDirection.Magnitude > 0.001 then params.AimDirection.Unit else -Vector3.zAxis
	local syncedOrigin: Vector3? = nil
	local syncedDir: Vector3? = nil
	local syncedMaxDist: number? = nil

	local function getCasterCF(): CFrame
		if hrp and hrp.Parent then
			local pos = hrp.Position
			local flatAim = Vector3.new(aimDir.X, 0, aimDir.Z)
			if flatAim.Magnitude > 0.01 then
				return CFrame.lookAt(pos, pos + flatAim.Unit)
			end
			return hrp.CFrame
		end
		return CFrame.lookAt(initialCenter, initialCenter + aimDir)
	end

	local baseCF = getCasterCF()
	local curBluePos = (baseCF * Config.Offsets.BlueLocal).Position
	local curRedPos = (baseCF * Config.Offsets.RedLocal).Position
	local curCenterPos = (baseCF * Config.Offsets.ConvergenceLocal).Position

	-- ================================================================
	-- FASE 1: CONJURACAO LAPSO AZUL (0.00s -> 1.20s)
	-- ================================================================
	local blueOrb = createTriLayerOrb(
		castFolder,
		"LapseBlue",
		Config.Colors.BlueCore,
		Config.Colors.BlueMid,
		Config.Colors.BlueShell,
		Config.Colors.BlueLight,
		0.30,
		true,
		janitor
	)
	blueOrb.SetCFrame(CFrame.new(curBluePos))
	blueOrb.SetScale(0.15, 1.0)
	playConfiguredSound(blueOrb.Root, Config.Assets.BlueSoundId, 0.65, timeScale, false)

	if useCamAndLight then
		CameraEffects.TweenFOV(Config.Camera.BluePulseFOV, 0.55 / timeScale, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, curBluePos)
		CameraEffects.AddTrauma(Config.Camera.BlueTrauma, curBluePos, 18.0, 0.8)
		LightingEffects.PulseBloom(0.95, 0.65 / timeScale, curBluePos)
	end

	if not reducedDetail then
		DebrisModule.SpawnSuctionPebbles(castFolder, curBluePos, 10, 1.15 / timeScale, janitor)
	end

	-- Variaveis criadas sob demanda nas fases seguintes
	local redOrb: TriOrb? = nil
	local casterHighlight: Highlight? = nil
	local levitateRing: DebrisModule.LevitateRingHandle? = nil

	-- 5 camadas do Vazio Roxo (criadas exatamente aos 3.50s!)
	local voidCreated = false
	local voidCorePart: Part? = nil
	local voidCoreMesh: SpecialMesh? = nil
	local voidHaloPart: Part? = nil
	local voidHaloMesh: SpecialMesh? = nil
	local voidMainPart: Part? = nil
	local voidMainMesh: SpecialMesh? = nil
	local voidNeonPart: Part? = nil
	local voidNeonMesh: SpecialMesh? = nil
	local voidLight: PointLight? = nil
	local orbitalRings: { { Segs: { Part }, Axis: CFrame, Speed: number, Angle: number, TrailPivot: Part } } = {}
	local helixOrbiters: { { Part: Part, Trail: Trail, Phase: number } } = {}
	local flightSound: Sound? = nil

	local phase2Triggered = false
	local orbitTriggered = false
	local launchTriggered = false
	local detonateTriggered = false

	local launchStartPos = curCenterPos
	local launchDir = aimDir
	local plannedMaxDist = Config.Combat.MaxRange
	local currentProjPos = curCenterPos
	local currentProjRadius = Config.Scales.VoidBirthRadius

	-- Acumuladores de intervalos baseados em dt
	local elapsed = 0.0
	local blueSuctionTimer = 0.0
	local blueBoltTimer = 0.0
	local redShockTimer = 0.0
	local redBoltTimer = 0.0
	local orbitArcTimer = 0.0
	local voidStormTimer = 0.0
	local machRingTimer = 0.0
	local carveTimer = 0.0
	local proxBoltTimer = 0.0

	-- Funcao para criar a Esfera de 5 Camadas do Vazio Roxo (3.50s)
	local function buildFiveLayerVoidSphere(spawnPos: Vector3)
		voidCreated = true
		-- Camada 1: Nucleo Abissal (Void Core quase preto/violeta escuro + inversao visual de profundidade)
		local cPart, cMesh = makeSpecialSphere(castFolder, "Void_1_AbyssCore", Enum.Material.SmoothPlastic, Config.Colors.VoidCore, 0.4, 0.0, false)
		voidCorePart, voidCoreMesh = cPart, cMesh
		janitor:Add(cPart)

		-- Camada 2: Halo Incandescente branco-lilas (Neon, trans 0.25)
		local hPart, hMesh = makeSpecialSphere(castFolder, "Void_2_IncandescentHalo", Enum.Material.Neon, Config.Colors.VoidHalo, 0.5, 0.25, false)
		voidHaloPart, voidHaloMesh = hPart, hMesh
		janitor:Add(hPart)

		-- Camada 3A + 3B: Aura Principal Roxo Vazio (ForceField distorcido + Neon translucido)
		local mPart, mMesh = makeSpecialSphere(castFolder, "Void_3A_ForceField", Enum.Material.ForceField, Config.Colors.VoidMain, 0.6, 0.16, false)
		local nPart, nMesh = makeSpecialSphere(castFolder, "Void_3B_NeonShell", Enum.Material.Neon, Config.Colors.VoidMain, 0.56, 0.48, false)
		voidMainPart, voidMainMesh = mPart, mMesh
		voidNeonPart, voidNeonMesh = nPart, nMesh
		janitor:Add(mPart)
		janitor:Add(nPart)

		local pLight = Instance.new("PointLight")
		pLight.Name = "VoidPointLight"
		pLight.Color = Config.Colors.VoidLight
		pLight.Brightness = 6.5
		pLight.Range = 42.0
		pLight.Shadows = false
		pLight.Parent = cPart
		voidLight = pLight

		-- Emissor de faiscas abissais na aura principal
		local voidSparks = Instance.new("ParticleEmitter")
		voidSparks.Texture = Config.ResolveTexture("Spark")
		voidSparks.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Config.Colors.VoidWhite),
			ColorSequenceKeypoint.new(0.45, Config.Colors.VoidMagenta),
			ColorSequenceKeypoint.new(1, Config.Colors.VoidCore),
		})
		voidSparks.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.85),
			NumberSequenceKeypoint.new(0.6, 0.42),
			NumberSequenceKeypoint.new(1, 0),
		})
		voidSparks.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.02),
			NumberSequenceKeypoint.new(0.75, 0.28),
			NumberSequenceKeypoint.new(1, 1),
		})
		voidSparks.Speed = NumberRange.new(16, 38)
		voidSparks.SpreadAngle = Vector2.new(180, 180)
		voidSparks.Lifetime = NumberRange.new(0.24, 0.46)
		voidSparks.Rate = if reducedDetail then 35 else 85
		voidSparks.LightEmission = 1.0
		voidSparks.Brightness = 3.0
		voidSparks.Orientation = Enum.ParticleOrientation.VelocityParallel
		voidSparks.Squash = NumberSequence.new(1.2)
		voidSparks.Drag = 2.6
		voidSparks.Parent = hPart

		-- Camada 4: 4 Aneis Orbitais Energeticos inclinados em eixos distintos com Trails roxo/branco
		local axes = {
			CFrame.Angles(math.rad(32), math.rad(15), 0),
			CFrame.Angles(math.rad(-48), 0, math.rad(38)),
			CFrame.Angles(math.rad(72), math.rad(-28), math.rad(-18)),
			CFrame.Angles(math.rad(-18), math.rad(64), math.rad(54)),
		}
		local ringCount = if reducedDetail then 2 else 4
		for rIdx = 1, ringCount do
			local segList: { Part } = {}
			local segN = 12
			for sIdx = 1, segN do
				local col = if sIdx % 2 == 0 then Config.Colors.VoidHalo else Config.Colors.VoidMain
				local seg = makePart(castFolder, "OrbRingSeg", Enum.PartType.Block, Enum.Material.Neon, col, Vector3.new(0.18, 0.18, 0.8), 0.12)
				janitor:Add(seg)
				table.insert(segList, seg)
			end
			local pivot = makePart(castFolder, "OrbRingTrailNode", Enum.PartType.Block, Enum.Material.SmoothPlastic, Color3.new(1, 1, 1), Vector3.new(0.2, 0.2, 0.2), 1)
			pivot.CFrame = CFrame.new(spawnPos)
			janitor:Add(pivot)

			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(1.0, 0.25, 0)
			a0.Parent = pivot
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(1.0, -0.25, 0)
			a1.Parent = pivot
			createTrailBetween(
				pivot,
				a0,
				a1,
				if rIdx % 2 == 0 then Config.Colors.VoidWhite else Config.Colors.VoidMagenta,
				Config.Colors.VoidMain,
				0.22,
				1.0
			)

			table.insert(orbitalRings, {
				Segs = segList,
				Axis = axes[rIdx],
				Speed = (7.5 + rIdx * 2.1) * (if rIdx % 2 == 0 then 1 else -1),
				Angle = rIdx * 1.1,
				TrailPivot = pivot,
			})
		end

		-- 3 ondas de choque inclinadas em angulos distintos explodindo na formacao!
		local shockTilts = {
			CFrame.Angles(math.rad(25), 0, math.rad(18)),
			CFrame.Angles(math.rad(-35), math.rad(40), math.rad(-24)),
			CFrame.Angles(math.rad(78), math.rad(-20), math.rad(12)),
		}
		for idx, tilt in ipairs(shockTilts) do
			spawnHollowShockRing(
				castFolder,
				CFrame.new(spawnPos) * tilt,
				1.8,
				18.0 + idx * 3.5,
				0.48,
				0.05,
				if idx == 1 then Config.Colors.VoidWhite else Config.Colors.VoidMagenta,
				0.42 / timeScale,
				16,
				false,
				janitor
			)
		end

		-- Highlight roxo temporario destacando a silhueta do conjurador
		if caster.Parent then
			local hl = Instance.new("Highlight")
			hl.Name = "HollowPurpleCasterRim"
			hl.Adornee = caster
			hl.FillColor = Config.Colors.VoidMain
			hl.FillTransparency = 0.82
			hl.OutlineColor = Config.Colors.VoidHalo
			hl.OutlineTransparency = 0.08
			hl.DepthMode = Enum.HighlightDepthMode.Occluded
			hl.Parent = castFolder
			janitor:Add(hl)
			casterHighlight = hl
		end
	end

	local function updateVoidSphereTransform(pos: Vector3, radius: number, t: number, dtStep: number)
		if not voidCreated then
			return
		end
		local pulse1 = 1.0 + 0.06 * math.sin(t * 22.0)
		local pulse2 = 1.0 + 0.09 * math.cos(t * 17.0 + 1.1)

		local dCore = radius * 1.28
		local dHalo = radius * 1.56 * pulse1
		local dMain = radius * 2.02 * pulse2
		local dNeon = radius * 1.88

		if voidCorePart and voidCoreMesh then
			voidCorePart.CFrame = CFrame.new(pos)
			voidCoreMesh.Scale = Vector3.new(dCore, dCore, dCore)
		end
		if voidHaloPart and voidHaloMesh then
			voidHaloPart.CFrame = CFrame.new(pos)
			voidHaloMesh.Scale = Vector3.new(dHalo, dHalo, dHalo)
		end
		if voidMainPart and voidMainMesh then
			voidMainPart.CFrame = CFrame.new(pos) * CFrame.Angles(t * 2.1, t * 1.7, 0)
			voidMainMesh.Scale = Vector3.new(dMain, dMain, dMain)
		end
		if voidNeonPart and voidNeonMesh then
			voidNeonPart.CFrame = CFrame.new(pos)
			voidNeonMesh.Scale = Vector3.new(dNeon, dNeon, dNeon)
		end

		-- Atualiza os aneis orbitais de alta velocidade (Camada 4)
		local orbR = radius * 1.32
		for _, ring in ipairs(orbitalRings) do
			ring.Angle += ring.Speed * dtStep
			local ringCF = CFrame.new(pos) * ring.Axis * CFrame.Angles(0, 0, ring.Angle)
			local n = #ring.Segs
			local chord = 2.0 * orbR * math.sin(math.pi / math.max(3, n)) * 1.06
			local thick = math.max(0.14, radius * 0.045)
			for i, seg in ipairs(ring.Segs) do
				if seg.Parent then
					local ang = ((i - 0.5) / n) * math.pi * 2
					local lp = Vector3.new(math.cos(ang) * orbR, math.sin(ang) * orbR, 0)
					local lt = Vector3.new(-math.sin(ang), math.cos(ang), 0)
					local wp = ringCF:PointToWorldSpace(lp)
					local wt = ringCF:VectorToWorldSpace(lt)
					seg.Size = Vector3.new(thick, thick, chord)
					seg.CFrame = CFrame.lookAt(wp, wp + wt)
				end
			end
			if ring.TrailPivot.Parent then
				local trailWorld = ringCF:PointToWorldSpace(Vector3.new(orbR, 0, 0))
				ring.TrailPivot.CFrame = CFrame.new(trailWorld)
			end
		end
	end

	-- Raycast cliente local para parede solida (caso rode standalone/batalha antes do sync do servidor)
	local function computeWallBlockedDistance(origin: Vector3, dir: Vector3, maxDist: number): number
		local paramsRay = RaycastParams.new()
		paramsRay.FilterType = Enum.RaycastFilterType.Exclude
		local ignoreList: { Instance } = { container, caster }
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr.Character then
				table.insert(ignoreList, plr.Character)
			end
		end
		for _, ch in ipairs(workspace:GetChildren()) do
			if ch:IsA("Model") and ch:FindFirstChildOfClass("Humanoid") then
				table.insert(ignoreList, ch)
			end
		end
		local pf = workspace:FindFirstChild("PartyFollowers")
		if pf then
			table.insert(ignoreList, pf)
		end
		paramsRay.FilterDescendantsInstances = ignoreList

		local res = workspace:Spherecast(origin, Config.Combat.WallSpherecastRadius, dir.Unit * maxDist, paramsRay)
		if res and res.Instance and res.Instance.CanCollide then
			return math.max(8.0, res.Distance)
		end
		return maxDist
	end

	-- ================================================================
	-- FASE 5: DETONACAO FINAL & DISSIPACAO (6.80s -> 9.00s)
	-- ================================================================
	local mainConn: RBXScriptConnection? = nil

	local function triggerPhase5Detonation(epicenter: Vector3)
		if detonateTriggered then
			return
		end
		detonateTriggered = true
		if mainConn and mainConn.Connected then
			mainConn:Disconnect()
		end
		if flightSound and flightSound.Parent then
			flightSound:Stop()
		end
		for _, h in ipairs(helixOrbiters) do
			h.Trail.Enabled = false
		end

		-- 1) Implosao Pre-Explosao (0.12s): comprime rapidamente a esfera sugando luz para dentro
		local implodeDur = Config.Timing.Phase5ImplodeDuration / timeScale
		spawnHollowShockRing(castFolder, CFrame.new(epicenter), currentProjRadius * 2.2, 0.5, 0.55, 0.12, Config.Colors.VoidWhite, implodeDur, 16, true, janitor)

		local implodeStart = os.clock()
		local implodeConn: RBXScriptConnection? = nil
		implodeConn = janitor:Connect(RunService.Heartbeat, function(dt: number)
			local a = math.clamp((os.clock() - implodeStart) / math.max(0.03, implodeDur), 0, 1)
			local r = currentProjRadius * (1.0 - 0.82 * (a * a))
			updateVoidSphereTransform(epicenter, math.max(0.5, r), os.clock(), dt)
			if a >= 1.0 and implodeConn and implodeConn.Connected then
				implodeConn:Disconnect()
			end
		end)

		janitor:Delay(implodeDur, function()
			-- Oculta a esfera do projetil e libera os aneis orbitais
			for _, p in ipairs({ voidCorePart, voidHaloPart, voidMainPart, voidNeonPart }) do
				if p and p.Parent then
					p.Transparency = 1
				end
			end
			for _, ring in ipairs(orbitalRings) do
				for _, seg in ipairs(ring.Segs) do
					if seg.Parent then
						seg.Transparency = 1
					end
				end
			end

			playConfiguredSound(voidCorePart or castFolder, Config.Assets.ExplosionSoundId, 0.95, 1.0, false)

			-- 2) Cataclismo Roxo: Mini Impact Frame + Camera Trauma + FOV
			if useCamAndLight then
				LightingEffects.PlayDetonationFlash(epicenter)
				CameraEffects.AddTrauma(Config.Camera.DetonationTrauma, epicenter, 30.0, 1.15)
				CameraEffects.Impulse(Vector3.new(0, 0.55, 2.2), epicenter)
				CameraEffects.TweenFOV(Config.Camera.BaseFOV, 0.85 / timeScale, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, epicenter)
			end

			local expDur = Config.Timing.Phase5ExplosionDuration / timeScale
			local maxR = Config.Scales.ExplosionMaxRadius * (if params.TargetPositionOverride then 0.52 else 1.0)

			-- Domo esferico multicamadas (domo branco interno + roxo neon + ForceField externo expandindo ate ~55 studs)
			local innerDome, innerMesh = makeSpecialSphere(castFolder, "Cataclysm_WhiteCore", Enum.Material.Neon, Config.Colors.VoidWhite, 1.5, 0.02, false)
			local midDome, midMesh = makeSpecialSphere(castFolder, "Cataclysm_PurpleNeon", Enum.Material.Neon, Config.Colors.VoidMain, 2.0, 0.16, false)
			local outerDome, outerMesh = makeSpecialSphere(castFolder, "Cataclysm_ForceField", Enum.Material.ForceField, Config.Colors.VoidMagenta, 2.5, 0.12, false)
			innerDome.CFrame = CFrame.new(epicenter)
			midDome.CFrame = CFrame.new(epicenter)
			outerDome.CFrame = CFrame.new(epicenter)
			janitor:Add(innerDome)
			janitor:Add(midDome)
			janitor:Add(outerDome)

			local expLight = Instance.new("PointLight")
			expLight.Color = Config.Colors.VoidLight
			expLight.Brightness = 8.0
			expLight.Range = 60.0
			expLight.Shadows = false
			expLight.Parent = innerDome

			TweenService:Create(innerMesh, TweenInfo.new(expDur * 0.48, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				Scale = Vector3.new(maxR * 1.35, maxR * 1.35, maxR * 1.35),
			}):Play()
			TweenService:Create(innerDome, TweenInfo.new(expDur * 0.52, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()

			TweenService:Create(midMesh, TweenInfo.new(expDur * 0.62, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
				Scale = Vector3.new(maxR * 1.82, maxR * 1.82, maxR * 1.82),
			}):Play()
			TweenService:Create(midDome, TweenInfo.new(expDur * 0.68, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()

			TweenService:Create(outerMesh, TweenInfo.new(expDur * 0.78, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
				Scale = Vector3.new(maxR * 2.05, maxR * 2.05, maxR * 2.05),
			}):Play()
			TweenService:Create(outerDome, TweenInfo.new(expDur * 0.82, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { Transparency = 1 }):Play()
			TweenService:Create(expLight, TweenInfo.new(expDur * 0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()

			-- Pilar de Luz Celestial disparando para o ceu e se estreitando ate sumir!
			local pillarH = Config.Scales.SkyPillarHeight * (if params.TargetPositionOverride then 0.65 else 1.0)
			local pillarD = Config.Scales.SkyPillarRadius * 2.0 * (if params.TargetPositionOverride then 0.65 else 1.0)
			local groundSample = DebrisModule.SampleGround(epicenter, 36.0)
			local basePillarPos = if groundSample.Hit then groundSample.Position else (epicenter - Vector3.new(0, 2, 0))
			local pillarCF = CFrame.new(basePillarPos + Vector3.new(0, pillarH * 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))

			local pillarCore = makePart(castFolder, "CelestialPillarCore", Enum.PartType.Cylinder, Enum.Material.Neon, Config.Colors.VoidWhite, Vector3.new(pillarH, 1.0, 1.0), 0.02)
			local pillarOuter = makePart(castFolder, "CelestialPillarOuter", Enum.PartType.Cylinder, Enum.Material.Neon, Config.Colors.VoidMain, Vector3.new(pillarH, 1.8, 1.8), 0.28)
			pillarCore.CFrame = pillarCF
			pillarOuter.CFrame = pillarCF
			janitor:Add(pillarCore)
			janitor:Add(pillarOuter)

			TweenService:Create(pillarCore, TweenInfo.new(0.14 / timeScale, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
				Size = Vector3.new(pillarH, pillarD * 0.52, pillarD * 0.52),
			}):Play()
			TweenService:Create(pillarOuter, TweenInfo.new(0.16 / timeScale, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
				Size = Vector3.new(pillarH, pillarD, pillarD),
			}):Play()

			janitor:Delay(0.18 / timeScale, function()
				if pillarCore.Parent then
					TweenService:Create(pillarCore, TweenInfo.new(expDur * 0.62, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
						Size = Vector3.new(pillarH * 1.12, 0.08, 0.08),
						Transparency = 1,
					}):Play()
				end
				if pillarOuter.Parent then
					TweenService:Create(pillarOuter, TweenInfo.new(expDur * 0.68, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
						Size = Vector3.new(pillarH * 1.12, 0.16, 0.16),
						Transparency = 1,
					}):Play()
				end
			end)

			-- Tripla onda de choque horizontal rente ao chao + Cratera radial gigante!
			local flatRingCF = CFrame.new(basePillarPos + Vector3.new(0, 0.6, 0)) * CFrame.Angles(math.rad(90), 0, 0)
			for w = 1, 3 do
				janitor:Delay(((w - 1) * 0.09) / timeScale, function()
					spawnHollowShockRing(
						castFolder,
						flatRingCF * CFrame.new(0, 0, -(w - 1) * 1.1),
						2.5,
						maxR * (0.85 + w * 0.22),
						0.85,
						0.08,
						if w == 1 then Config.Colors.VoidWhite elseif w == 2 then Config.Colors.VoidMagenta else Config.Colors.VoidMain,
						(0.55 + w * 0.12) / timeScale,
						18,
						false,
						janitor
					)
				end)
			end

			if not reducedDetail then
				DebrisModule.SpawnCraterRing(
					castFolder,
					epicenter,
					Config.Scales.CraterRadius * (if params.TargetPositionOverride then 0.50 else 1.0),
					if params.TargetPositionOverride then 16 else Config.Scales.CraterRockCount,
					expDur,
					janitor
				)
				LightningModule.BurstAround(castFolder, epicenter, 3.0, maxR * 0.95, 10, false, {
					InnerColor = Config.Colors.VoidWhite,
					OuterColor = Config.Colors.VoidMain,
					Thickness = 0.34,
					Subdivisions = 4,
					Duration = 0.32,
					BranchChance = 0.45,
				}, janitor)
			end

			-- Brasas violetas flutuando lentamente para cima por 2.5s enquanto o cenario se acalma
			local emberBox = makePart(castFolder, "VoidEmberCloud", Enum.PartType.Block, Enum.Material.SmoothPlastic, Color3.new(1, 1, 1), Vector3.new(maxR * 1.1, 4.0, maxR * 1.1), 1)
			emberBox.CFrame = CFrame.new(basePillarPos + Vector3.new(0, 2.5, 0))
			janitor:Add(emberBox)

			local embers = Instance.new("ParticleEmitter")
			embers.Texture = Config.ResolveTexture("Spark")
			embers.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Config.Colors.VoidWhite),
				ColorSequenceKeypoint.new(0.4, Config.Colors.VoidMagenta),
				ColorSequenceKeypoint.new(1, Config.Colors.VoidMain),
			})
			embers.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.48),
				NumberSequenceKeypoint.new(0.6, 0.28),
				NumberSequenceKeypoint.new(1, 0),
			})
			embers.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.05),
				NumberSequenceKeypoint.new(0.75, 0.32),
				NumberSequenceKeypoint.new(1, 1),
			})
			embers.Lifetime = NumberRange.new(1.4, 2.4)
			embers.Speed = NumberRange.new(3.5, 9.5)
			embers.Acceleration = Vector3.new(0, 2.4, 0)
			embers.SpreadAngle = Vector2.new(35, 35)
			embers.EmissionDirection = Enum.NormalId.Top
			embers.LightEmission = 1.0
			embers.Brightness = 2.8
			embers.Rate = if reducedDetail then 22 else 55
			embers.Parent = emberBox
			embers:Emit(if reducedDetail then 25 else 65)

			local linger = Config.Timing.EmberLingerDuration / timeScale
			janitor:Delay(linger * 0.55, function()
				embers.Enabled = false
			end)

			-- Limpeza absoluta ao final da Fase 5 (zero instancias sobrando em workspace.HollowPurpleVFX)
			janitor:Delay(math.max(expDur, linger) + 0.35, function()
				activeCasts[castId] = nil
				janitor:Cleanup()
			end)
		end)
	end

	-- ================================================================
	-- LOOP PRINCIPAL DT-DRIVEN (60 - 240 FPS): FASES 1, 2, 3 E 4
	-- ================================================================
	mainConn = janitor:Connect(RunService.Heartbeat, function(rawDt: number)
		local dt = math.min(rawDt, 0.05) * timeScale
		elapsed += dt

		local casterCF = getCasterCF()
		local lerpAlpha = math.clamp(rawDt * Config.Offsets.FollowLerpSpeed, 0, 1)
		local desiredBlue = (casterCF * Config.Offsets.BlueLocal).Position
		local desiredRed = (casterCF * Config.Offsets.RedLocal).Position
		local desiredCenter = (casterCF * Config.Offsets.ConvergenceLocal).Position

		curBluePos = curBluePos:Lerp(desiredBlue, lerpAlpha)
		curRedPos = curRedPos:Lerp(desiredRed, lerpAlpha)
		curCenterPos = curCenterPos:Lerp(desiredCenter, lerpAlpha)

		-- ------------------------------------------------------------
		-- FASE 1 (0.00s -> 1.20s) + sustentacao ate 2.40s: LAPSO AZUL
		-- ------------------------------------------------------------
		if elapsed < Config.Timing.Phase3OrbitStart then
			local blueGrow = math.clamp(elapsed / 0.45, 0, 1)
			local easedBlue = 1 - (1 - blueGrow) ^ 4
			local shellPulse = 1.0 + 0.11 * math.sin(elapsed * 14.0)
			blueOrb.SetCFrame(CFrame.new(curBluePos) * CFrame.Angles(0, elapsed * 2.5, 0))
			blueOrb.SetScale(Config.Scales.BlueRadius * easedBlue, shellPulse)

			blueSuctionTimer += dt
			if blueSuctionTimer >= 0.24 then
				blueSuctionTimer = 0.0
				local randCF = CFrame.new(curBluePos) * CFrame.Angles(rng:NextNumber(0, 3.14), rng:NextNumber(0, 3.14), 0)
				spawnHollowShockRing(
					castFolder,
					randCF,
					Config.Scales.BlueSuctionRingStart,
					0.45,
					0.16,
					0.05,
					Config.Colors.BlueMid,
					0.26 / timeScale,
					12,
					true,
					janitor
				)
			end

			blueBoltTimer += dt
			if blueBoltTimer >= 0.15 and not reducedDetail then
				blueBoltTimer = 0.0
				LightningModule.BurstAround(castFolder, curBluePos, Config.Scales.BlueRadius * 0.7, 6.2, 2, true, {
					InnerColor = Config.Colors.BlueCore,
					OuterColor = Config.Colors.BlueMid,
					Thickness = 0.14,
					Duration = 0.12,
					BranchChance = 0.25,
				}, janitor)
			end
		end

		-- ------------------------------------------------------------
		-- FASE 2 (1.20s -> 2.40s): REVERSAO VERMELHO (nasce com flash a direita!)
		-- ------------------------------------------------------------
		if elapsed >= Config.Timing.Phase2Start and not phase2Triggered then
			phase2Triggered = true
			curRedPos = desiredRed
			local createdRed = createTriLayerOrb(
				castFolder,
				"ReversalRed",
				Config.Colors.RedCore,
				Config.Colors.RedMid,
				Config.Colors.RedShell,
				Config.Colors.RedLight,
				0.25,
				false,
				janitor
			)
			redOrb = createdRed
			createdRed.SetCFrame(CFrame.new(curRedPos))
			createdRed.SetScale(0.2, 1.0)
			playConfiguredSound(createdRed.Root, Config.Assets.RedSoundId, 0.72, timeScale, false)

			-- Flash brusco de nascimento do Vermelho
			spawnHollowShockRing(castFolder, CFrame.new(curRedPos), 0.6, 8.5, 0.34, 0.05, Config.Colors.RedCore, 0.22 / timeScale, 14, false, janitor)
			if useCamAndLight then
				CameraEffects.AddTrauma(Config.Camera.RedTrauma, curRedPos, 28.0, 1.4)
				LightingEffects.PulseBloom(1.35, 0.45 / timeScale, curRedPos)
			end
		end

		if elapsed >= Config.Timing.Phase2Start and elapsed < Config.Timing.Phase3OrbitStart and redOrb then
			local redAge = elapsed - Config.Timing.Phase2Start
			local redGrow = math.clamp(redAge / 0.28, 0, 1)
			local easedRed = 1 + 2.2 * ((redGrow - 1) ^ 3) + 1.2 * ((redGrow - 1) ^ 2) -- curva BackOut
			if redGrow >= 1 then
				easedRed = 1.0
			end
			-- Micro-vibracao aleatoria na casca externa (pressao explosiva contida!)
			local jitter = Vector3.new(
				rng:NextNumber(-1, 1) * Config.Scales.RedJitterAmplitude,
				rng:NextNumber(-1, 1) * Config.Scales.RedJitterAmplitude,
				rng:NextNumber(-1, 1) * Config.Scales.RedJitterAmplitude
			)
			redOrb.SetCFrame(CFrame.new(curRedPos), jitter)
			redOrb.SetScale(Config.Scales.RedRadius * math.max(0.1, easedRed), 1.0 + 0.14 * math.sin(elapsed * 26.0))

			redShockTimer += dt
			if redShockTimer >= Config.Scales.RedShockInterval then
				redShockTimer = 0.0
				local tilt = CFrame.new(curRedPos) * CFrame.Angles(rng:NextNumber(0, 3.14), rng:NextNumber(0, 3.14), 0)
				spawnHollowShockRing(castFolder, tilt, 1.2, 9.2, 0.28, 0.04, Config.Colors.RedMid, 0.24 / timeScale, 14, false, janitor)
				if useCamAndLight then
					CameraEffects.AddTrauma(0.12, curRedPos, 32.0, 2.0)
				end
			end

			redBoltTimer += dt
			if redBoltTimer >= 0.14 and not reducedDetail then
				redBoltTimer = 0.0
				LightningModule.BurstAround(castFolder, curRedPos, Config.Scales.RedRadius * 0.8, 7.2, 2, false, {
					InnerColor = Config.Colors.RedCore,
					OuterColor = Config.Colors.RedMid,
					Thickness = 0.16,
					Duration = 0.12,
					BranchChance = 0.35,
				}, janitor)
			end
		end

		-- ------------------------------------------------------------
		-- FASE 3A (2.40s -> 3.50s): ORBITA ESPIRAL & ARCOS ENTRE ESFERAS
		-- ------------------------------------------------------------
		if elapsed >= Config.Timing.Phase3OrbitStart and elapsed < Config.Timing.Phase3MergeTime then
			if not orbitTriggered then
				orbitTriggered = true
				blueOrb.Trail.Enabled = true
				if redOrb then
					redOrb.Trail.Enabled = true
				end
				playConfiguredSound(blueOrb.Root, Config.Assets.OrbitSoundId, 0.65, timeScale, false)
			end

			local orbitSpan = Config.Timing.Phase3MergeTime - Config.Timing.Phase3OrbitStart -- 1.10s
			local u = math.clamp((elapsed - Config.Timing.Phase3OrbitStart) / orbitSpan, 0, 1)
			-- Raio diminui suavemente ate 0 enquanto a velocidade angular acelera exponencialmente!
			local startR = 4.6
			local radius = startR * ((1.0 - u) ^ 1.65)
			local theta = math.pi + (u * 3.5 + (u ^ 3.2) * 16.5)

			local planeCF = CFrame.lookAt(curCenterPos, curCenterPos + casterCF.LookVector)
			local offsetBlue = Vector3.new(math.cos(theta) * radius, math.sin(theta) * radius, 0)
			local offsetRed = -offsetBlue
			local worldBlue = planeCF:PointToWorldSpace(offsetBlue)
			local worldRed = planeCF:PointToWorldSpace(offsetRed)

			local shrinkOrb = Config.Scales.BlueRadius * (1.0 - 0.35 * u)
			blueOrb.SetCFrame(CFrame.new(worldBlue))
			blueOrb.SetScale(shrinkOrb, 1.08)
			if redOrb then
				redOrb.SetCFrame(CFrame.new(worldRed))
				redOrb.SetScale(shrinkOrb, 1.12)
			end

			orbitArcTimer += dt
			if orbitArcTimer >= 0.065 then
				orbitArcTimer = 0.0
				-- Arcos continuos ligando diretamente Azul <-> Vermelho + primeiros lampejos roxos!
				local arcColor = if u > 0.45 and rng:NextNumber() < u then Config.Colors.VoidMain
					elseif rng:NextNumber() < 0.5 then Config.Colors.BlueMid
					else Config.Colors.RedMid
				LightningModule.DrawBolt(castFolder, worldBlue, worldRed, {
					InnerColor = Config.Colors.VoidWhite,
					OuterColor = arcColor,
					Thickness = 0.20,
					Subdivisions = 3,
					Duration = 0.09,
					BranchChance = 0.3,
				}, janitor)
				if useCamAndLight then
					CameraEffects.AddTrauma(0.06 * u, curCenterPos, 24.0, 1.8)
				end
			end
		end

		-- ------------------------------------------------------------
		-- FASE 3B (3.50s -> 4.00s) + Tensao (4.00s -> 4.15s): COLISAO, IMPACT FRAME & VAZIO ROXO
		-- ------------------------------------------------------------
		if elapsed >= Config.Timing.Phase3MergeTime and not voidCreated then
			blueOrb.FadeOutAndDestroy(0.08)
			if redOrb then
				redOrb.FadeOutAndDestroy(0.08)
			end

			buildFiveLayerVoidSphere(curCenterPos)
			playConfiguredSound(voidCorePart or castFolder, Config.Assets.MergeSoundId, 0.85, timeScale, false)

			if useCamAndLight then
				LightingEffects.PlayMergeImpactFrame(curCenterPos)
				CameraEffects.AddTrauma(Config.Camera.MergeTrauma, curCenterPos, 30.0, 1.35)
				-- FOV fecha rapido para 52 e explode para 88 no frame da fusao!
				CameraEffects.TweenFOV(Config.Camera.MergeCompressFOV, 0.055 / timeScale, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out, curCenterPos)
				janitor:Delay(0.06 / timeScale, function()
					CameraEffects.TweenFOV(Config.Camera.MergeExplodeFOV, 0.18 / timeScale, Enum.EasingStyle.Back, Enum.EasingDirection.Out, curCenterPos)
				end)
			end

			if not reducedDetail then
				levitateRing = DebrisModule.SpawnLevitatingRing(
					castFolder,
					function()
						return if hrp and hrp.Parent then hrp.Position else initialCenter
					end,
					Config.Scales.LevitateRockCount,
					Config.Scales.LevitateRingRadius,
					janitor
				)
			end
		end

		if elapsed >= Config.Timing.Phase3MergeTime and elapsed < Config.Timing.Phase4LaunchTime then
			local mergeAge = elapsed - Config.Timing.Phase3MergeTime
			local formAlpha = math.clamp(mergeAge / 0.32, 0, 1)
			-- Durante a pausa dramatica de tensao (4.00s -> 4.15s), a esfera comprime levemente acumulando energia!
			local tensionCompress = 1.0
			if elapsed >= Config.Timing.Phase3End then
				local tAlpha = math.clamp((elapsed - Config.Timing.Phase3End) / Config.Timing.LaunchTensionPause, 0, 1)
				tensionCompress = 1.0 - 0.14 * math.sin(tAlpha * math.pi * 0.5)
			end
			local easedForm = 1 - (1 - formAlpha) ^ 4
			currentProjRadius = Config.Scales.VoidBirthRadius * easedForm * tensionCompress
			currentProjPos = curCenterPos
			updateVoidSphereTransform(curCenterPos, math.max(0.4, currentProjRadius), elapsed, dt)

			-- Tempestade eletrica constante (Camada 5: raios roxos brilhantes + roxo-escuro/preto atingindo o chao)
			voidStormTimer += dt
			if voidStormTimer >= 0.08 and not reducedDetail then
				voidStormTimer = 0.0
				LightningModule.BurstAround(castFolder, curCenterPos, currentProjRadius * 0.75, currentProjRadius * 2.15, 2, false, {
					InnerColor = Config.Colors.VoidHalo,
					OuterColor = Config.Colors.VoidMain,
					Thickness = 0.22,
					Duration = 0.13,
					BranchChance = 0.35,
				}, janitor)
				local groundHit = DebrisModule.SampleGround(curCenterPos, 24.0)
				if groundHit.Hit then
					local strikeTarget = groundHit.Position + Vector3.new(rng:NextNumber(-7, 7), 0, rng:NextNumber(-7, 7))
					LightningModule.DrawBolt(castFolder, curCenterPos, strikeTarget, {
						InnerColor = Config.Colors.VoidMain,
						OuterColor = Config.Colors.VoidCore,
						Thickness = 0.24,
						Subdivisions = 4,
						Duration = 0.15,
						OuterTransparency = 0.12,
					}, janitor)
				end
			end
		end

		-- ------------------------------------------------------------
		-- FASE 4 (4.15s -> ~6.80s): ESTALO DE DEDOS, DISPARO & ANIQUILACAO CONTINUA
		-- ------------------------------------------------------------
		if elapsed >= Config.Timing.Phase4LaunchTime and not launchTriggered then
			launchTriggered = true
			launchStartPos = syncedOrigin or curCenterPos
			launchDir = syncedDir or (if params.TargetPositionOverride then (params.TargetPositionOverride - launchStartPos).Unit else casterCF.LookVector)
			if launchDir.Magnitude < 0.001 then
				launchDir = -Vector3.zAxis
			end
			launchDir = launchDir.Unit

			if params.TargetPositionOverride then
				plannedMaxDist = math.max(6.0, (params.TargetPositionOverride - launchStartPos).Magnitude)
			elseif syncedMaxDist then
				plannedMaxDist = syncedMaxDist
			else
				plannedMaxDist = computeWallBlockedDistance(launchStartPos, launchDir, Config.Combat.MaxRange)
			end

			playConfiguredSound(voidCorePart or castFolder, Config.Assets.LaunchSoundId, 0.92, 1.0, false)
			flightSound = playConfiguredSound(voidCorePart or castFolder, Config.Assets.FlightLoopSoundId, 0.65, 1.0, true)

			-- Remove suavemente o Highlight do conjurador apos o disparo
			if casterHighlight and casterHighlight.Parent then
				TweenService:Create(casterHighlight, TweenInfo.new(0.45), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
			end

			-- Arremessa violentamente as pedras levitando para frente e para os lados!
			if levitateRing then
				levitateRing.BlastOutward(launchStartPos - launchDir * 4.0, launchDir)
			end

			-- Cone de choque gigante (anéis escalonados em cone de Mach) atras da esfera no momento do disparo!
			local launchLook = CFrame.lookAt(launchStartPos, launchStartPos + launchDir)
			for cIdx = 1, 4 do
				spawnHollowShockRing(
					castFolder,
					launchLook * CFrame.new(0, 0, (cIdx - 1) * 2.4),
					1.6 + cIdx * 0.8,
					16.0 + cIdx * 5.5,
					0.55,
					0.06,
					if cIdx % 2 == 1 then Config.Colors.VoidWhite else Config.Colors.VoidMain,
					(0.28 + cIdx * 0.06) / timeScale,
					16,
					false,
					janitor
				)
			end

			-- Recuo + Shake intenso + FOV sobe para 92 e acomoda suavemente para 78!
			if useCamAndLight then
				CameraEffects.AddTrauma(Config.Camera.LaunchTrauma, launchStartPos, 32.0, 1.45)
				CameraEffects.Impulse(Vector3.new(0, 0.45, 2.4), launchStartPos)
				CameraEffects.TweenFOV(Config.Camera.LaunchPeakFOV, 0.08 / timeScale, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out, launchStartPos)
				janitor:Delay(0.10 / timeScale, function()
					CameraEffects.TweenFOV(Config.Camera.FlightSustainFOV, 0.45 / timeScale, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, launchStartPos)
				end)
			end

			-- Cria os 3 pontos do Vortice Helicoidal traseiro (roxo neon, magenta e preto-violeta)
			local helixColors = {
				{ Config.Colors.VoidMain, Config.Colors.VoidHalo },
				{ Config.Colors.VoidMagenta, Config.Colors.VoidMain },
				{ Config.Colors.VoidCore, Config.Colors.VoidAbyss },
			}
			for hIdx = 1, 3 do
				local node = makePart(castFolder, "HelixVortexNode_" .. tostring(hIdx), Enum.PartType.Block, Enum.Material.SmoothPlastic, Color3.new(1, 1, 1), Vector3.new(0.2, 0.2, 0.2), 1)
				node.CFrame = CFrame.new(launchStartPos)
				janitor:Add(node)
				local a0 = Instance.new("Attachment")
				a0.Position = Vector3.new(0, 1.35, 0)
				a0.Parent = node
				local a1 = Instance.new("Attachment")
				a1.Position = Vector3.new(0, -1.35, 0)
				a1.Parent = node
				local tr = createTrailBetween(node, a0, a1, helixColors[hIdx][1], helixColors[hIdx][2], 0.36, if hIdx == 3 then 0.25 else 0.95)
				table.insert(helixOrbiters, {
					Part = node,
					Trail = tr,
					Phase = ((hIdx - 1) / 3) * math.pi * 2,
				})
			end
		end

		if launchTriggered and not detonateTriggered then
			-- Caso o pacote LaunchSync do servidor tenha acabado de chegar, aplica origem/direcao/alcance autoritativos
			if syncedOrigin then
				launchStartPos = syncedOrigin
				syncedOrigin = nil
			end
			if syncedDir then
				launchDir = syncedDir.Unit
				syncedDir = nil
			end
			if syncedMaxDist then
				plannedMaxDist = syncedMaxDist
				syncedMaxDist = nil
			end

			local flightElapsed = elapsed - Config.Timing.Phase4LaunchTime
			local speed = if params.TargetPositionOverride
				then (plannedMaxDist / math.max(0.22, 0.55))
				else Config.Combat.ProjectileSpeed
			local traveled = speed * flightElapsed
			local flightAlpha = math.clamp(traveled / math.max(1.0, plannedMaxDist), 0, 1)

			currentProjPos = launchStartPos + launchDir * math.min(traveled, plannedMaxDist)
			currentProjRadius = Config.Scales.ProjectileStartRadius
				+ (Config.Scales.ProjectileEndRadius - Config.Scales.ProjectileStartRadius) * math.sqrt(flightAlpha)
			if params.TargetPositionOverride then
				currentProjRadius *= 0.65
			end

			updateVoidSphereTransform(currentProjPos, currentProjRadius, elapsed, dt)

			-- Atualiza o Vortice Helicoidal triplo orbitando o eixo traseiro da esfera
			local flightCF = CFrame.lookAt(currentProjPos, currentProjPos + launchDir)
			local helixR = currentProjRadius * 1.18
			for _, h in ipairs(helixOrbiters) do
				local ang = h.Phase + flightElapsed * 15.5
				local localOff = Vector3.new(math.cos(ang) * helixR, math.sin(ang) * helixR, currentProjRadius * 0.55)
				h.Part.CFrame = CFrame.new(flightCF:PointToWorldSpace(localOff))
			end

			-- Tremor continuo proporcional a proximidade da camera com a esfera em voo
			if useCamAndLight then
				CameraEffects.AddTrauma(Config.Camera.FlightContinuousTrauma * dt * 2.5, currentProjPos, 26.0, 2.2)
			end

			-- 1) Cones de Mach / Aneis Sonicos a cada 0.05s
			machRingTimer += dt
			if machRingTimer >= Config.Scales.MachRingInterval then
				machRingTimer = 0.0
				spawnHollowShockRing(
					castFolder,
					flightCF,
					currentProjRadius * 0.85,
					currentProjRadius * 2.35,
					0.36,
					0.04,
					Config.Colors.VoidHalo,
					0.24 / timeScale,
					14,
					false,
					janitor
				)
			end

			-- 2) Rasgo no Chao (Ground Carving) a cada 0.06s
			carveTimer += dt
			if carveTimer >= Config.Scales.GroundCarveInterval then
				carveTimer = 0.0
				DebrisModule.CarveGroundStep(castFolder, currentProjPos, launchDir, currentProjRadius, reducedDetail, janitor)
			end

			-- 3) Raios de Proximidade pulando da esfera gigante para chao e paredes
			proxBoltTimer += dt
			if proxBoltTimer >= 0.075 and not reducedDetail then
				proxBoltTimer = 0.0
				local sample = DebrisModule.SampleGround(currentProjPos, Config.Scales.GroundRayDepth)
				if sample.Hit then
					local gTarget = sample.Position + Vector3.new(rng:NextNumber(-9, 9), 0, rng:NextNumber(-9, 9))
					LightningModule.DrawBolt(castFolder, currentProjPos, gTarget, {
						InnerColor = Config.Colors.VoidWhite,
						OuterColor = if rng:NextNumber() < 0.7 then Config.Colors.VoidMain else Config.Colors.VoidCore,
						Thickness = 0.28,
						Subdivisions = 3,
						Duration = 0.13,
						BranchChance = 0.35,
					}, janitor)
				else
					LightningModule.BurstAround(castFolder, currentProjPos, currentProjRadius * 0.9, currentProjRadius * 2.1, 2, false, {
						InnerColor = Config.Colors.VoidWhite,
						OuterColor = Config.Colors.VoidMagenta,
						Thickness = 0.24,
						Duration = 0.12,
					}, janitor)
				end
			end

			-- Chegou no alcance maximo ou obstaculo solido -> dispara Fase 5!
			if traveled >= plannedMaxDist or flightElapsed >= Config.Timing.Phase4MaxFlight then
				triggerPhase5Detonation(currentProjPos)
			end
		end
	end)

	local handle: ActiveCastHandle = {
		CastId = castId,
		SyncLaunch = function(origin: Vector3, direction: Vector3, maxTravelDist: number)
			syncedOrigin = origin
			syncedDir = direction
			syncedMaxDist = maxTravelDist
		end,
		Destroy = function()
			activeCasts[castId] = nil
			janitor:Cleanup()
		end,
	}
	activeCasts[castId] = handle
	return handle
end

function HollowPurpleVFX.SyncLaunch(castId: string, origin: Vector3, direction: Vector3, maxTravelDist: number)
	local h = activeCasts[castId]
	if h then
		h.SyncLaunch(origin, direction, maxTravelDist)
	end
end

-- Helper dedicado para o golpe assinatura "TudoRoxo" do Setero (Gojo) nas batalhas 1x1 e 2x2
function HollowPurpleVFX.PlayBattleUltimate(
	attacker: Model,
	target: Model?,
	targetModels: { Model }?,
	impactTime: number?
): ActiveCastHandle?
	local hrp = attacker and (attacker:FindFirstChild("HumanoidRootPart") or attacker.PrimaryPart) :: BasePart?
	if not hrp then
		return nil
	end

	-- Calcula centro medio de todos os inimigos vivos em campo (1x1 ou 2x2)
	local sum = Vector3.zero
	local count = 0
	if targetModels then
		for _, tm in ipairs(targetModels) do
			local r = tm and (tm:FindFirstChild("HumanoidRootPart") or tm.PrimaryPart) :: BasePart?
			if r then
				sum += r.Position
				count += 1
			end
		end
	end
	if count == 0 and target then
		local r = (target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart) :: BasePart?
		if r then
			sum = r.Position
			count = 1
		end
	end
	local targetCenterPos = if count > 0 then (sum / count) else (hrp.Position + hrp.CFrame.LookVector * 18.0)
	local aim = targetCenterPos - hrp.Position
	local aimUnit = if aim.Magnitude > 0.01 then aim.Unit else hrp.CFrame.LookVector

	-- Ajusta TimeScale para que o impacto coincida exatamente com o Timing.Impact da batalha!
	local desiredImpact = math.max(1.15, impactTime or 1.45)
	local naturalImpact = Config.Timing.Phase4LaunchTime + 0.55 -- ~4.70s na velocidade 1x
	local battleTimeScale = naturalImpact / desiredImpact

	local castId = "BattleTudoRoxo_" .. tostring(math.floor(os.clock() * 1000)) .. "_" .. tostring(rng:NextInteger(100, 999))
	return HollowPurpleVFX.PlayCast({
		CastId = castId,
		CasterModel = attacker,
		AimDirection = aimUnit,
		TimeScale = battleTimeScale,
		TargetPositionOverride = targetCenterPos,
		EnableCameraAndLighting = true,
	})
end

function HollowPurpleVFX.CleanupAll()
	for id, h in pairs(activeCasts) do
		activeCasts[id] = nil
		h.Destroy()
	end
end

return HollowPurpleVFX
