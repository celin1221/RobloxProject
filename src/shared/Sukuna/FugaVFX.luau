--!strict
--[[
	ReplicatedStorage/Sukuna/FugaVFX.luau
	Rework Completo Nivel AAA — "FUGA" (Chama Divina / Flecha de Fogo de Ryomen Sukuna)
	Inspirado em Jujutsu Kaisen Temporada 2 (Sukuna vs Jogo / Mahoraga).

	REGRAS TECNICAS RIGIDAS CUMPRIDAS:
	  1. ZERO Primitivos de Neon (zero Cone, Ball, Cylinder ou Wedge visiveis!).
	  2. Empilhamento Termico Real de 4 Camadas em todas as fontes de fogo:
	       - Camada 1: Nucleo Incandescente (ZOffset = 2, LightEmission = 1, RGB 255,255,235 -> 255,220,90)
	       - Camada 2: Corpo da Chama (ZOffset = 1, LightEmission = 0.75, RGB 255,115,10 -> 210,25,5)
	       - Camada 3: Fumaca Piroclastica Densa (ZOffset = -1, LightEmission = 0, RGB 28,22,22 -> 10,8,10)
	       - Camada 4: Brasas & Faiscas Esticadas (VelocityParallel, Squash alto, Drag)
	  3. PointLight com flicker procedural em tempo real via math.noise(t * 14, seed, 0) variando brilho e alcance.
	  4. 6 Fases cinematograficas (0.00s a 8.80s) em RunService.RenderStepped (dt) + limpeza absoluta via Janitor.
]]

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(script.Parent:WaitForChild("Config"))
local Janitor = require(script.Parent:WaitForChild("Janitor"))
local CinematicCamera = require(script.Parent:WaitForChild("CinematicCamera"))
local SoundManager = require(script.Parent:WaitForChild("SoundManager"))
local AnimatorModule = require(script.Parent:WaitForChild("AnimatorModule"))

local FugaVFX = {}

export type ThermalStack = {
	Core: ParticleEmitter,
	Body: ParticleEmitter,
	Smoke: ParticleEmitter,
	Sparks: ParticleEmitter,
	SetEnabled: (enabled: boolean) -> (),
	EmitBurst: (coreN: number, bodyN: number, smokeN: number, sparkN: number) -> (),
}

local activeFugaJanitors: { [Janitor.JanitorInstance]: boolean } = {}

local function isLowQuality(): boolean
	local ok, lv = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	return ok and lv ~= 0 and lv <= 3
end

local function qScale(count: number): number
	return if isLowQuality() then math.max(1, math.floor(count * 0.55)) else count
end

local function getVfxContainer(): Folder
	local existing = workspace:FindFirstChild(Config.WorkspaceFolderName)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = Config.WorkspaceFolderName
	folder.Parent = workspace
	return folder
end

local function rootOf(model: Model?): BasePart?
	if not model then
		return nil
	end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end
	return model.PrimaryPart
end

local function groundYOf(model: Model?): number
	local r = rootOf(model)
	if not r then
		return 0
	end
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	return r.Position.Y - r.Size.Y * 0.5 - (if hum then hum.HipHeight else 2.0)
end

local function rightHandWorldPos(model: Model): Vector3
	local armMesh = model:FindFirstChild("RightArm_Mesh")
	if armMesh and armMesh:IsA("BasePart") then
		return armMesh.CFrame:PointToWorldSpace(Vector3.new(0, -armMesh.Size.Y * 0.44, 0))
	end
	local hand = model:FindFirstChild("RightHand") or model:FindFirstChild("Right Arm")
	if hand and hand:IsA("BasePart") then
		return hand.Position
	end
	local r = rootOf(model)
	return if r then r.CFrame:PointToWorldSpace(Vector3.new(1.15, 0.25, -0.85)) else Vector3.zero
end

local function leftHandWorldPos(model: Model): Vector3
	local armMesh = model:FindFirstChild("LeftArm_Mesh")
	if armMesh and armMesh:IsA("BasePart") then
		return armMesh.CFrame:PointToWorldSpace(Vector3.new(0, -armMesh.Size.Y * 0.44, 0))
	end
	local hand = model:FindFirstChild("LeftHand") or model:FindFirstChild("Left Arm")
	if hand and hand:IsA("BasePart") then
		return hand.Position
	end
	local r = rootOf(model)
	return if r then r.CFrame:PointToWorldSpace(Vector3.new(-1.15, 0.25, -0.85)) else Vector3.zero
end

-- Portador invisivel (Transparency = 1, Block 0.2^3, sem colisao/sombra — ZERO geometria visivel!)
local function makeCarrier(parent: Instance, cf: CFrame, jan: Janitor.JanitorInstance, name: string?): Part
	local p = Instance.new("Part")
	p.Name = name or "FugaInvisibleCarrier"
	p.Shape = Enum.PartType.Block
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = cf
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Parent = parent
	jan:Add(p)
	return p
end

-- PointLight com flicker procedural vivo em tempo real via math.noise(t * 14, seed, 0) variando Brilho e Alcance!
local function createNoiseFireLight(
	parent: Instance,
	color: Color3,
	baseBrightness: number,
	baseRange: number,
	seed: number,
	jan: Janitor.JanitorInstance
): (PointLight, (mult: number) -> ())
	local light = Instance.new("PointLight")
	light.Name = "FugaDynamicFireLight"
	light.Color = color
	light.Brightness = baseBrightness
	light.Range = baseRange
	light.Shadows = false
	light.Parent = parent
	jan:Add(light)

	local intensityMult = 1.0
	local elapsed = 0.0

	local function stepLight(dt: number)
		if not light.Parent then
			return
		end
		elapsed += math.min(dt, 0.05)
		local n1 = math.noise(elapsed * 14.0, seed, 0.0)
		local n2 = math.noise(elapsed * 29.0, seed + 13.7, 0.5)
		local briFactor = math.clamp(1.0 + n1 * 0.36 + n2 * 0.16, 0.45, 1.55)
		local rngFactor = math.clamp(1.0 + n1 * 0.22 + n2 * 0.08, 0.65, 1.35)
		light.Brightness = math.max(0, baseBrightness * briFactor * intensityMult)
		light.Range = math.max(0, baseRange * rngFactor * (0.35 + 0.65 * math.clamp(intensityMult, 0, 1.35)))
	end

	if RunService:IsClient() then
		jan:Connect(RunService.RenderStepped, stepLight)
	else
		jan:Connect(RunService.Heartbeat, stepLight)
	end

	return light, function(m: number)
		intensityMult = m
	end
end

--============================================================================
-- EMPILHAMENTO TERMICO REAL DE 4 CAMADAS (ANTI-FOGO CHAPADO)
--   Camada 1: Nucleo Incandescente (ZOffset = 2, LightEmission = 1, RGB 255,255,235 -> 255,220,90)
--   Camada 2: Corpo da Chama (ZOffset = 1, LightEmission = 0.75, RGB 255,115,10 -> 210,25,5)
--   Camada 3: Fumaca Piroclastica Densa (ZOffset = -1, LightEmission = 0, RGB 28,22,22 -> 10,8,10)
--   Camada 4: Brasas & Faiscas Esticadas (VelocityParallel, Squash alto, Drag)
--============================================================================
type StackOpts = {
	Scale: number,
	RateMult: number,
	SpeedMult: number,
	UpAccel: number,
	Spread: Vector2?,
	VerticalColumn: boolean?,
}

local function createThermalStack(host: Instance, opts: StackOpts): ThermalStack
	local sc = opts.Scale
	local rm = if isLowQuality() then opts.RateMult * 0.52 else opts.RateMult
	local sm = opts.SpeedMult
	local spread = opts.Spread or Vector2.new(52, 52)
	local fugaAssets = Config.Assets.Fuga

	local coreTex = Config.ResolveFugaAsset(fugaAssets.FireCoreFlipbookId, Config.Assets.FireCoreTextureId, Config.Fallbacks.Fire)
	local bodyTex = Config.ResolveFugaAsset(fugaAssets.FireBodyFlipbookId, Config.Assets.FireWispTextureId, Config.Fallbacks.Fire)
	local smokeTex = Config.ResolveFugaAsset(fugaAssets.PyroSmokeTextureId, Config.Assets.PyroSmokeTextureId, Config.Fallbacks.Smoke)
	local sparkTex = Config.ResolveFugaAsset(fugaAssets.EmberSparkTextureId, Config.Assets.EmberSparkTextureId, Config.Fallbacks.Streak)

	-- Camada 1: Nucleo Incandescente (ZOffset = 2, LightEmission = 1)
	local core = Instance.new("ParticleEmitter")
	core.Name = "ThermalLayer1_Core"
	core.Texture = coreTex
	core.ZOffset = 2
	core.LightEmission = 1
	core.LightInfluence = 0
	if opts.VerticalColumn then
		core.Orientation = Enum.ParticleOrientation.VelocityParallel
		core.Squash = NumberSequence.new(1.35, 2.25)
	end
	core.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Config.Colors.ThermalCoreStart),
		ColorSequenceKeypoint.new(0.65, Config.Colors.ThermalCoreEnd),
		ColorSequenceKeypoint.new(1.0, Config.Colors.ThermalFlameStart),
	})
	core.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0.00, 0.42 * sc),
		NumberSequenceKeypoint.new(0.32, 0.92 * sc),
		NumberSequenceKeypoint.new(0.75, 0.54 * sc),
		NumberSequenceKeypoint.new(1.00, 0.08 * sc),
	})
	core.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.00, 0.02),
		NumberSequenceKeypoint.new(0.60, 0.14),
		NumberSequenceKeypoint.new(1.00, 1.00),
	})
	core.Lifetime = NumberRange.new(0.18, 0.34)
	core.Rate = math.floor(64 * rm)
	core.Speed = NumberRange.new(4.5 * sm, 11.0 * sm)
	core.SpreadAngle = spread * 0.65
	core.RotSpeed = NumberRange.new(-95, 95)
	core.Acceleration = Vector3.new(0, opts.UpAccel, 0)
	core.Parent = host

	-- Camada 2: Corpo da Chama (ZOffset = 1, LightEmission = 0.75)
	local body = Instance.new("ParticleEmitter")
	body.Name = "ThermalLayer2_FlameBody"
	body.Texture = bodyTex
	body.ZOffset = 1
	body.LightEmission = 0.75
	body.LightInfluence = 0
	body.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, Config.Colors.ThermalFlameStart),
		ColorSequenceKeypoint.new(0.58, Config.Colors.ThermalFlameEnd),
		ColorSequenceKeypoint.new(1.00, Color3.fromRGB(95, 12, 4)),
	})
	body.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0.00, 0.68 * sc),
		NumberSequenceKeypoint.new(0.38, 1.65 * sc),
		NumberSequenceKeypoint.new(0.78, 1.05 * sc),
		NumberSequenceKeypoint.new(1.00, 0.16 * sc),
	})
	body.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.00, 0.08),
		NumberSequenceKeypoint.new(0.55, 0.26),
		NumberSequenceKeypoint.new(1.00, 1.00),
	})
	body.Lifetime = NumberRange.new(0.28, 0.54)
	body.Rate = math.floor(56 * rm)
	body.Speed = NumberRange.new(3.8 * sm, 9.5 * sm)
	body.SpreadAngle = spread
	body.RotSpeed = NumberRange.new(-140, 140)
	body.Rotation = NumberRange.new(0, 360)
	body.Acceleration = Vector3.new(0, opts.UpAccel * 0.9, 0)
	body.Drag = 0.8
	body.Parent = host

	-- Camada 3: Fumaca Piroclastica Densa (ZOffset = -1, LightEmission = 0)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "ThermalLayer3_PyroSmoke"
	smoke.Texture = smokeTex
	smoke.ZOffset = -1
	smoke.LightEmission = 0
	smoke.LightInfluence = 0.15
	smoke.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, Config.Colors.ThermalSmokeStart),
		ColorSequenceKeypoint.new(0.55, Config.Colors.ThermalSmokeEnd),
		ColorSequenceKeypoint.new(1.00, Config.Colors.ThermalSmokeEnd),
	})
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0.00, 0.95 * sc),
		NumberSequenceKeypoint.new(0.48, 2.35 * sc),
		NumberSequenceKeypoint.new(1.00, 3.65 * sc),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.00, 0.36),
		NumberSequenceKeypoint.new(0.35, 0.22),
		NumberSequenceKeypoint.new(0.80, 0.58),
		NumberSequenceKeypoint.new(1.00, 1.00),
	})
	smoke.Lifetime = NumberRange.new(0.55, 1.15)
	smoke.Rate = math.floor(34 * rm)
	smoke.Speed = NumberRange.new(2.5 * sm, 7.2 * sm)
	smoke.SpreadAngle = spread * 1.15
	smoke.RotSpeed = NumberRange.new(-55, 55)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.Acceleration = Vector3.new(0, opts.UpAccel * 0.55, 0)
	smoke.Drag = 1.4
	smoke.Parent = host

	-- Camada 4: Brasas & Faiscas Esticadas (VelocityParallel, Squash alto, Drag)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "ThermalLayer4_Embers"
	sparks.Texture = sparkTex
	sparks.Orientation = Enum.ParticleOrientation.VelocityParallel
	sparks.ZOffset = 2
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, Config.Colors.ThermalCoreStart),
		ColorSequenceKeypoint.new(0.45, Config.Colors.ThermalCoreEnd),
		ColorSequenceKeypoint.new(1.00, Config.Colors.ThermalFlameStart),
	})
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0.00, 0.28 * math.clamp(sc, 0.65, 2.4)),
		NumberSequenceKeypoint.new(0.70, 0.16 * math.clamp(sc, 0.65, 2.4)),
		NumberSequenceKeypoint.new(1.00, 0.03),
	})
	sparks.Squash = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 1.8),
		NumberSequenceKeypoint.new(0.5, 3.1),
		NumberSequenceKeypoint.new(1.0, 1.2),
	})
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.00, 0.0),
		NumberSequenceKeypoint.new(0.75, 0.18),
		NumberSequenceKeypoint.new(1.00, 1.0),
	})
	sparks.Lifetime = NumberRange.new(0.28, 0.68)
	sparks.Rate = math.floor(46 * rm)
	sparks.Speed = NumberRange.new(12.0 * sm, 28.0 * sm)
	sparks.SpreadAngle = Vector2.new(145, 115)
	sparks.Acceleration = Vector3.new(0, opts.UpAccel * 0.4 - 6.0, 0)
	sparks.Drag = 2.6
	sparks.Parent = host

	return {
		Core = core,
		Body = body,
		Smoke = smoke,
		Sparks = sparks,
		SetEnabled = function(on: boolean)
			core.Enabled = on
			body.Enabled = on
			smoke.Enabled = on
			sparks.Enabled = on
		end,
		EmitBurst = function(cN: number, bN: number, sN: number, eN: number)
			if cN > 0 then
				core:Emit(qScale(cN))
			end
			if bN > 0 then
				body:Emit(qScale(bN))
			end
			if sN > 0 then
				smoke:Emit(qScale(sN))
			end
			if eN > 0 then
				sparks:Emit(qScale(eN))
			end
		end,
	}
end

-- Cria anel de ar/fogo usando exclusivamente 2 Beams semicirculares curvos (ZERO cilindros/esferas/discos de Neon!)
local function spawnBeamShockRing(
	container: Instance,
	ringCF: CFrame,
	startRadius: number,
	endRadius: number,
	startWidth: number,
	duration: number,
	col0: Color3,
	col1: Color3,
	jan: Janitor.JanitorInstance
)
	local carrier = Instance.new("Part")
	carrier.Name = "FugaSonicBeamRing"
	carrier.Size = Vector3.new(0.2, 0.2, 0.2)
	carrier.CFrame = ringCF
	carrier.Transparency = 1
	carrier.Anchored = true
	carrier.CanCollide = false
	carrier.CanQuery = false
	carrier.CanTouch = false
	carrier.CastShadow = false
	carrier.Massless = true
	carrier.Parent = container
	jan:Add(carrier)

	local attTop = Instance.new("Attachment")
	attTop.Position = Vector3.new(0, startRadius, 0)
	attTop.Parent = carrier
	local attBot = Instance.new("Attachment")
	attBot.Position = Vector3.new(0, -startRadius, 0)
	attBot.Parent = carrier

	local ringTex = Config.ResolveFugaAsset(Config.Assets.Fuga.ShockRingTextureId, nil, Config.Fallbacks.Streak)
	local arcs: { Beam } = {}
	for _, sign in ipairs({ 1, -1 }) do
		local b = Instance.new("Beam")
		b.Attachment0 = if sign == 1 then attTop else attBot
		b.Attachment1 = if sign == 1 then attBot else attTop
		b.Texture = ringTex
		b.TextureSpeed = 3.2
		b.Color = ColorSequence.new(col0, col1)
		b.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.08),
			NumberSequenceKeypoint.new(0.5, 0.02),
			NumberSequenceKeypoint.new(1, 0.08),
		})
		b.Width0 = startWidth
		b.Width1 = startWidth
		b.CurveSize0 = startRadius * 1.33 * sign
		b.CurveSize1 = startRadius * 1.33 * sign
		b.LightEmission = 1
		b.LightInfluence = 0
		b.FaceCamera = false
		b.Segments = 24
		b.Parent = carrier
		table.insert(arcs, b)
	end

	-- Fumaca quente evaporando do anel sonico
	local hotPuff = Instance.new("ParticleEmitter")
	hotPuff.Texture = Config.Fallbacks.Smoke
	hotPuff.ZOffset = -1
	hotPuff.LightEmission = 0
	hotPuff.Color = ColorSequence.new(Config.Colors.PyroSootLit, Config.Colors.ThermalSmokeEnd)
	hotPuff.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, startRadius * 0.45 + 0.6), NumberSequenceKeypoint.new(1, endRadius * 0.55 + 1.8) })
	hotPuff.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.52), NumberSequenceKeypoint.new(1, 1) })
	hotPuff.Lifetime = NumberRange.new(duration * 0.8, duration * 1.35)
	hotPuff.Speed = NumberRange.new(3, 10)
	hotPuff.SpreadAngle = Vector2.new(180, 180)
	hotPuff.Rate = 0
	hotPuff.Parent = carrier
	hotPuff:Emit(qScale(6))

	local elapsed = 0.0
	local conn: RBXScriptConnection? = nil
	local sig = if RunService:IsClient() then RunService.RenderStepped else RunService.Heartbeat
	conn = jan:Connect(sig, function(dt: number)
		if not carrier.Parent then
			if conn and conn.Connected then
				conn:Disconnect()
			end
			return
		end
		elapsed += math.min(dt, 0.05)
		local a = math.clamp(elapsed / duration, 0, 1)
		local ease = 1 - (1 - a) ^ 3
		local curR = startRadius + (endRadius - startRadius) * ease
		local curW = startWidth * (1 - a)
		attTop.Position = Vector3.new(0, curR, 0)
		attBot.Position = Vector3.new(0, -curR, 0)
		for idx, b in ipairs(arcs) do
			local sgn = if idx == 1 then 1 else -1
			b.CurveSize0 = curR * 1.33 * sgn
			b.CurveSize1 = curR * 1.33 * sgn
			b.Width0 = curW
			b.Width1 = curW
		end
		if a >= 1 then
			if conn and conn.Connected then
				conn:Disconnect()
			end
			if carrier.Parent then
				carrier:Destroy()
			end
		end
	end)
end

-- Constroi um Beam flamejante estilizado reutilizavel
local function makeFlameBeam(
	parent: Instance,
	a0: Attachment,
	a1: Attachment,
	textureId: string,
	colSeq: ColorSequence,
	w0: number,
	w1: number,
	texSpeed: number,
	lightEm: number
): Beam
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Texture = textureId
	b.TextureSpeed = texSpeed
	b.TextureLength = 0.9
	b.Color = colSeq
	b.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.00, 0.12),
		NumberSequenceKeypoint.new(0.50, 0.00),
		NumberSequenceKeypoint.new(1.00, 0.12),
	})
	b.Width0 = w0
	b.Width1 = w1
	b.LightEmission = lightEm
	b.LightInfluence = 0
	b.FaceCamera = true
	b.Segments = 24
	b.Parent = parent
	return b
end

--============================================================================
-- EXECUCAO COMPLETA DAS 6 FASES DO FUGA (0.00s -> 8.80s)
--============================================================================
function FugaVFX.Play(
	attacker: Model,
	primaryTarget: Model?,
	allTargets: { Model }?,
	timing: { [string]: number }?
)
	local aRoot = rootOf(attacker)
	local tRoot = rootOf(primaryTarget) or aRoot
	if not aRoot or not tRoot then
		return
	end

	local TL = Config.FugaTimeline
	local totalDur = (timing and timing.Length) or TL.TotalDuration
	local jan = Janitor.new()
	activeFugaJanitors[jan] = true
	jan:Add(function()
		activeFugaJanitors[jan] = nil
	end)

	local container = getVfxContainer()
	local fugaAssets = Config.Assets.Fuga
	local arrowBeamTex = Config.ResolveFugaAsset(fugaAssets.ArrowBeamTextureId, Config.Assets.FireWispTextureId, Config.Fallbacks.Flame)
	local pillarBeamTex = Config.ResolveFugaAsset(fugaAssets.PillarBeamTextureId, Config.Assets.FireWispTextureId, Config.Fallbacks.Fire)
	local trailTex = Config.ResolveFugaAsset(fugaAssets.TrailFlameTextureId, Config.Assets.TrailFlameTextureId, Config.Fallbacks.Trail)

	-- Parametros de Raycast para rastro de chao queimado e destrocos (ignora VFX e personagens)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local filterList: { Instance } = { container, attacker }
	if primaryTarget then
		table.insert(filterList, primaryTarget)
	end
	if allTargets then
		for _, m in ipairs(allTargets) do
			table.insert(filterList, m)
		end
	end
	rayParams.FilterDescendantsInstances = filterList

	-- Dispara a camera cinematografica de 6 fases sincronizada
	CinematicCamera.PlayFuga(attacker, primaryTarget or attacker, timing)

	-- Pos-processamento controlado pelo Janitor (restaura 100% ao estado atual do Santuario/mapa no fim!)
	local snapAmbient = Lighting.Ambient
	local snapOutdoor = Lighting.OutdoorAmbient
	local snapShiftTop = Lighting.ColorShift_Top
	local snapExposure = Lighting.ExposureCompensation
	jan:Add(function()
		Lighting.Ambient = snapAmbient
		Lighting.OutdoorAmbient = snapOutdoor
		Lighting.ColorShift_Top = snapShiftTop
		Lighting.ExposureCompensation = snapExposure
	end)

	local fugaBloom = Instance.new("BloomEffect")
	fugaBloom.Name = "SukunaFugaBloom"
	fugaBloom.Intensity = 0.0
	fugaBloom.Size = 24
	fugaBloom.Threshold = 1.6
	fugaBloom.Parent = Lighting
	jan:Add(fugaBloom)

	local fugaCC = Instance.new("ColorCorrectionEffect")
	fugaCC.Name = "SukunaFugaCC"
	fugaCC.Brightness = 0
	fugaCC.Contrast = 0
	fugaCC.Saturation = 0
	fugaCC.TintColor = Color3.new(1, 1, 1)
	fugaCC.Parent = Lighting
	jan:Add(fugaCC)

	local fugaBlur = Instance.new("BlurEffect")
	fugaBlur.Name = "SukunaFugaBlur"
	fugaBlur.Size = 0
	fugaBlur.Parent = Lighting
	jan:Add(fugaBlur)

	-- Highlight quente bem sutil na borda do corpo do Sukuna (Fase 1 -> Fase 3)
	local casterHighlight = Instance.new("Highlight")
	casterHighlight.Name = "FugaWarmRimHighlight"
	casterHighlight.FillColor = Config.Colors.ThermalFlameStart
	casterHighlight.OutlineColor = Config.Colors.ThermalCoreEnd
	casterHighlight.FillTransparency = 0.92
	casterHighlight.OutlineTransparency = 0.45
	casterHighlight.Parent = attacker
	jan:Add(casterHighlight)

	--------------------------------------------------------------------
	-- ESTRUTURAS FASE 1 (0.00s..1.45s): ABERTURA DA FORNALHA
	--------------------------------------------------------------------
	SoundManager.MuffleAmbient(1.42, 1.05)

	local startOrigin = aRoot.Position
	local startTarget = tRoot.Position
	local floorY = groundYOf(attacker)

	local furnaceMidCarrier = makeCarrier(container, CFrame.new((leftHandWorldPos(attacker) + rightHandWorldPos(attacker)) * 0.5), jan, "FugaFurnaceCore")
	local attPalmL = Instance.new("Attachment")
	attPalmL.Parent = furnaceMidCarrier
	local attPalmR = Instance.new("Attachment")
	attPalmR.Parent = furnaceMidCarrier

	local _, setFurnaceLightMult = createNoiseFireLight(
		furnaceMidCarrier,
		Config.Colors.ThermalFlameStart,
		3.6,
		20.0,
		11.3,
		jan
	)
	setFurnaceLightMult(0.25)

	-- Faisca branco-dourada inicial nascendo exatamente entre as palmas em 0.00s!
	local birthSpark = Instance.new("ParticleEmitter")
	birthSpark.Texture = Config.Fallbacks.Star
	birthSpark.ZOffset = 2
	birthSpark.LightEmission = 1
	birthSpark.Color = ColorSequence.new(Config.Colors.ThermalCoreStart, Config.Colors.ThermalCoreEnd)
	birthSpark.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.25, 1.35),
		NumberSequenceKeypoint.new(1, 0.0),
	})
	birthSpark.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	birthSpark.Lifetime = NumberRange.new(0.22, 0.36)
	birthSpark.Speed = NumberRange.new(0.4, 2.2)
	birthSpark.SpreadAngle = Vector2.new(180, 180)
	birthSpark.Rate = 0
	birthSpark.Parent = furnaceMidCarrier
	birthSpark:Emit(qScale(12))

	-- Feixe instavel de chama viva esticando entre as duas maos + 4 camadas termicas compactas
	local furnaceCoreBeam = makeFlameBeam(
		furnaceMidCarrier,
		attPalmL,
		attPalmR,
		arrowBeamTex,
		ColorSequence.new(Config.Colors.ThermalCoreStart, Config.Colors.ThermalCoreEnd),
		0.18,
		0.18,
		6.8,
		1.0
	)
	furnaceCoreBeam.Enabled = false

	local furnaceAuraBeam = makeFlameBeam(
		furnaceMidCarrier,
		attPalmL,
		attPalmR,
		arrowBeamTex,
		ColorSequence.new(Config.Colors.ThermalFlameStart, Config.Colors.ThermalFlameEnd),
		0.52,
		0.52,
		5.2,
		0.82
	)
	furnaceAuraBeam.Enabled = false

	local furnaceStack = createThermalStack(furnaceMidCarrier, {
		Scale = 0.62,
		RateMult = 0.95,
		SpeedMult = 0.65,
		UpAccel = 13.0,
		Spread = Vector2.new(68, 68),
	})
	furnaceStack.SetEnabled(false)

	--------------------------------------------------------------------
	-- ESTRUTURAS FASE 2 (1.45s..3.30s): ARCO, CORDA EM "V", FLECHA DE 3 BEAMS & SUCCAO 20 STUDS
	--------------------------------------------------------------------
	local bowCarrier = makeCarrier(container, aRoot.CFrame, jan, "FugaLivingBow")
	local attBowGrip = Instance.new("Attachment")
	attBowGrip.Parent = bowCarrier
	local attBowTop = Instance.new("Attachment")
	attBowTop.Parent = bowCarrier
	local attBowBot = Instance.new("Attachment")
	attBowBot.Parent = bowCarrier
	local attStringHand = Instance.new("Attachment")
	attStringHand.Parent = bowCarrier
	local attArrowTip = Instance.new("Attachment")
	attArrowTip.Parent = bowCarrier
	local attArrowMid = Instance.new("Attachment")
	attArrowMid.Parent = bowCarrier

	-- O Arco Flamejante: 2 pares de Beams curvos (nucleo branco + aura laranja) envergando dinamicamente!
	local bowUpperCore = makeFlameBeam(bowCarrier, attBowGrip, attBowTop, arrowBeamTex, ColorSequence.new(Config.Colors.ThermalCoreStart, Config.Colors.ThermalCoreEnd), 0.24, 0.08, 6.2, 1.0)
	local bowUpperAura = makeFlameBeam(bowCarrier, attBowGrip, attBowTop, arrowBeamTex, ColorSequence.new(Config.Colors.ThermalFlameStart, Config.Colors.ThermalFlameEnd), 0.78, 0.22, 4.8, 0.8)
	local bowLowerCore = makeFlameBeam(bowCarrier, attBowGrip, attBowBot, arrowBeamTex, ColorSequence.new(Config.Colors.ThermalCoreStart, Config.Colors.ThermalCoreEnd), 0.24, 0.08, 6.2, 1.0)
	local bowLowerAura = makeFlameBeam(bowCarrier, attBowGrip, attBowBot, arrowBeamTex, ColorSequence.new(Config.Colors.ThermalFlameStart, Config.Colors.ThermalFlameEnd), 0.78, 0.22, 4.8, 0.8)

	-- A Corda de Plasma Igneo: 2 Beams esticados em "V" vibrando em alta frequencia!
	local stringTopBeam = makeFlameBeam(bowCarrier, attBowTop, attStringHand, arrowBeamTex, ColorSequence.new(Config.Colors.ThermalCoreEnd, Config.Colors.ThermalCoreStart), 0.09, 0.16, 9.5, 1.0)
	local stringBotBeam = makeFlameBeam(bowCarrier, attBowBot, attStringHand, arrowBeamTex, ColorSequence.new(Config.Colors.ThermalCoreEnd, Config.Colors.ThermalCoreStart), 0.09, 0.16, 9.5, 1.0)

	-- A Flecha Divina: 3 feixes de Beams entrelacados (nucleo branco afinando na ponta + corpo laranja + helice espiralada)!
	local arrowShaftCore = makeFlameBeam(bowCarrier, attStringHand, attArrowTip, arrowBeamTex, ColorSequence.new(Config.Colors.ThermalCoreStart, Config.Colors.ThermalCoreEnd), 0.30, 0.06, 8.5, 1.0)
	local arrowShaftBody = makeFlameBeam(bowCarrier, attStringHand, attArrowTip, arrowBeamTex, ColorSequence.new(Config.Colors.ThermalFlameStart, Config.Colors.ThermalFlameEnd), 0.95, 0.34, 6.4, 0.82)
	local arrowHelixA = makeFlameBeam(bowCarrier, attStringHand, attArrowMid, arrowBeamTex, ColorSequence.new(Config.Colors.ThermalCoreEnd, Config.Colors.ThermalFlameStart), 0.42, 0.48, 10.5, 1.0)
	local arrowHelixB = makeFlameBeam(bowCarrier, attArrowMid, attArrowTip, arrowBeamTex, ColorSequence.new(Config.Colors.ThermalFlameStart, Config.Colors.ThermalCoreStart), 0.48, 0.14, 10.5, 1.0)

	local allBowBeams = {
		bowUpperCore, bowUpperAura, bowLowerCore, bowLowerAura,
		stringTopBeam, stringBotBeam,
		arrowShaftCore, arrowShaftBody, arrowHelixA, arrowHelixB,
	}
	for _, b in ipairs(allBowBeams) do
		b.Enabled = false
	end

	-- Emissores termicos de 4 camadas na ponta ardente (ponta de lanca), na cauda e nas pontas do arco!
	local tipStack = createThermalStack(attArrowTip, {
		Scale = 0.82,
		RateMult = 1.25,
		SpeedMult = 0.95,
		UpAccel = 12.0,
		Spread = Vector2.new(38, 38),
	})
	tipStack.SetEnabled(false)

	local tailStack = createThermalStack(attStringHand, {
		Scale = 0.52,
		RateMult = 0.85,
		SpeedMult = 1.15,
		UpAccel = 6.0,
		Spread = Vector2.new(95, 95),
	})
	tailStack.SetEnabled(false)

	local topTipWisps = createThermalStack(attBowTop, {
		Scale = 0.42,
		RateMult = 0.45,
		SpeedMult = 0.65,
		UpAccel = 14.0,
		Spread = Vector2.new(40, 40),
	})
	topTipWisps.SetEnabled(false)

	local botTipWisps = createThermalStack(attBowBot, {
		Scale = 0.42,
		RateMult = 0.45,
		SpeedMult = 0.65,
		UpAccel = 14.0,
		Spread = Vector2.new(40, 40),
	})
	botTipWisps.SetEnabled(false)

	-- Vortice de Succao Termica de 20 studs (6 orbiters espiralando de R=20 studs para dentro da flecha + fumaca sob os pes!)
	local suctionNodes: { { carrier: Part, trail: Trail, sparks: ParticleEmitter } } = {}
	for i = 1, 6 do
		local sc = makeCarrier(container, CFrame.new(startOrigin), jan, "FugaSuctionNode" .. i)
		local s0 = Instance.new("Attachment")
		s0.Position = Vector3.new(0, -0.22, 0)
		s0.Parent = sc
		local s1 = Instance.new("Attachment")
		s1.Position = Vector3.new(0, 0.22, 0)
		s1.Parent = sc

		local tr = Instance.new("Trail")
		tr.Attachment0 = s0
		tr.Attachment1 = s1
		tr.Texture = trailTex
		tr.Color = ColorSequence.new(
			if i % 2 == 0 then Config.Colors.ThermalCoreEnd else Config.Colors.AshGrey,
			Config.Colors.ThermalFlameStart
		)
		tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 1) })
		tr.Lifetime = 0.26
		tr.LightEmission = if i % 2 == 0 then 1 else 0.35
		tr.FaceCamera = true
		tr.Enabled = false
		tr.Parent = sc

		local sp = Instance.new("ParticleEmitter")
		sp.Texture = Config.Fallbacks.Spark
		sp.Orientation = Enum.ParticleOrientation.VelocityParallel
		sp.Color = ColorSequence.new(Config.Colors.ThermalCoreEnd, Config.Colors.AshGrey)
		sp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.24), NumberSequenceKeypoint.new(1, 0.04) })
		sp.Squash = NumberSequence.new(1.8, 2.8)
		sp.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
		sp.Lifetime = NumberRange.new(0.18, 0.35)
		sp.Rate = if isLowQuality() then 14 else 28
		sp.Speed = NumberRange.new(2, 6)
		sp.LightEmission = 0.85
		sp.Enabled = false
		sp.Parent = sc

		table.insert(suctionNodes, { carrier = sc, trail = tr, sparks = sp })
	end

	local feetHeatCarrier = makeCarrier(container, CFrame.new(startOrigin.X, floorY + 0.12, startOrigin.Z), jan, "FugaFeetHeat")
	local feetSmoke = Instance.new("ParticleEmitter")
	feetSmoke.Texture = Config.Fallbacks.Smoke
	feetSmoke.ZOffset = -1
	feetSmoke.LightEmission = 0
	feetSmoke.Color = ColorSequence.new(Config.Colors.PyroSootLit, Config.Colors.ThermalSmokeEnd)
	feetSmoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 4.8) })
	feetSmoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	feetSmoke.Lifetime = NumberRange.new(0.55, 1.05)
	feetSmoke.Rate = if isLowQuality() then 16 else 32
	feetSmoke.Speed = NumberRange.new(2, 6)
	feetSmoke.SpreadAngle = Vector2.new(165, 18)
	feetSmoke.Acceleration = Vector3.new(0, 7, 0)
	feetSmoke.Enabled = false
	feetSmoke.Parent = feetHeatCarrier

	--------------------------------------------------------------------
	-- ESTRUTURAS FASE 3 (3.30s..3.85s): COMETA DE FOGO COM 4 TRAILS + ANEIS SONICOS + CHAO QUEIMADO
	--------------------------------------------------------------------
	local projectileCarrier = makeCarrier(container, CFrame.new(startOrigin), jan, "FugaSupersonicArrow")
	local _, setProjLightMult = createNoiseFireLight(
		projectileCarrier,
		Config.Colors.ThermalCoreEnd,
		5.2,
		38.0,
		27.9,
		jan
	)
	setProjLightMult(0)

	local projHeadAtt = Instance.new("Attachment")
	projHeadAtt.Position = Vector3.new(0, 0, -3.4)
	projHeadAtt.Parent = projectileCarrier
	local projTailAtt = Instance.new("Attachment")
	projTailAtt.Position = Vector3.new(0, 0, 3.8)
	projTailAtt.Parent = projectileCarrier

	local projCoreBeam = makeFlameBeam(projectileCarrier, projTailAtt, projHeadAtt, arrowBeamTex, ColorSequence.new(Config.Colors.ThermalCoreEnd, Config.Colors.ThermalCoreStart), 0.45, 1.25, 12.0, 1.0)
	local projBodyBeam = makeFlameBeam(projectileCarrier, projTailAtt, projHeadAtt, arrowBeamTex, ColorSequence.new(Config.Colors.ThermalFlameEnd, Config.Colors.ThermalFlameStart), 1.35, 2.65, 9.0, 0.85)
	projCoreBeam.Enabled = false
	projBodyBeam.Enabled = false

	-- 4 Trails de larguras e cores diferentes (1: branco central, 2: dourado, 3: laranja-fogo, 4: fumaca escura!)
	local trailSpecs = {
		{ halfW = 0.22, col0 = Config.Colors.ThermalCoreStart, col1 = Config.Colors.ThermalCoreStart, life = 0.24, lightEm = 1.0, trans0 = 0.0 },
		{ halfW = 0.58, col0 = Config.Colors.ThermalCoreEnd, col1 = Config.Colors.ThermalFlameStart, life = 0.30, lightEm = 1.0, trans0 = 0.05 },
		{ halfW = 1.25, col0 = Config.Colors.ThermalFlameStart, col1 = Config.Colors.ThermalFlameEnd, life = 0.38, lightEm = 0.78, trans0 = 0.12 },
		{ halfW = 2.15, col0 = Config.Colors.ThermalSmokeStart, col1 = Config.Colors.ThermalSmokeEnd, life = 0.56, lightEm = 0.0, trans0 = 0.34 },
	}
	local projTrails: { Trail } = {}
	for idx, spec in ipairs(trailSpecs) do
		local aL = Instance.new("Attachment")
		aL.Position = Vector3.new(-spec.halfW, 0, if idx == 4 then 1.2 else -0.8)
		aL.Parent = projectileCarrier
		local aR = Instance.new("Attachment")
		aR.Position = Vector3.new(spec.halfW, 0, if idx == 4 then 1.2 else -0.8)
		aR.Parent = projectileCarrier

		local tr = Instance.new("Trail")
		tr.Name = "FugaCometTrail_" .. idx
		tr.Attachment0 = aL
		tr.Attachment1 = aR
		tr.Texture = if idx == 4 then Config.Fallbacks.Smoke else trailTex
		tr.Color = ColorSequence.new(spec.col0, spec.col1)
		tr.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.00, spec.trans0),
			NumberSequenceKeypoint.new(0.55, math.min(0.95, spec.trans0 + 0.28)),
			NumberSequenceKeypoint.new(1.00, 1.00),
		})
		tr.WidthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 1.0),
			NumberSequenceKeypoint.new(0.6, 0.72),
			NumberSequenceKeypoint.new(1.0, 0.08),
		})
		tr.Lifetime = spec.life
		tr.LightEmission = spec.lightEm
		tr.LightInfluence = 0
		tr.FaceCamera = true
		tr.Enabled = false
		tr.Parent = projectileCarrier
		table.insert(projTrails, tr)
	end

	local projStack = createThermalStack(projectileCarrier, {
		Scale = 1.45,
		RateMult = 1.85,
		SpeedMult = 1.35,
		UpAccel = 8.0,
		Spread = Vector2.new(125, 125),
	})
	projStack.SetEnabled(false)

	--------------------------------------------------------------------
	-- CONTROLE DE ESTADO FRAME A FRAME NAS 6 FASES (RenderStepped + dt)
	--------------------------------------------------------------------
	local elapsed = 0.0
	local lastRenderClock = os.clock()

	local firedVoice = false
	local firedIgnite = false
	local firedPhase2 = false
	local firedLaunch = false
	local firedPhase4 = false
	local firedImpactFrame2 = false
	local firedPhase5 = false
	local firedPhase6 = false

	local furnaceSnd: Sound? = nil
	local bowTurbineSnd: Sound? = nil
	local bowStringSnd: Sound? = nil
	local jetFlightSnd: Sound? = nil

	local lastSonicRingAt = 0.0
	local lastGroundScorchAt = 0.0
	local launchWorldPos = startOrigin + Vector3.new(0, 1.2, 0)
	local impactWorldPos = startTarget + Vector3.new(0, 0.9, 0)

	-- Estruturas criadas na Fase 5 (para controle fino na Fase 6)
	local pillarStacks: { ThermalStack } = {}
	local pillarBeams: { Beam } = {}
	local vortexNodes: { { carrier: Part, trail: Trail, stack: ThermalStack } } = {}
	local setEpicenterLightMult: ((number) -> ())? = nil
	local ashRainEmitter: ParticleEmitter? = nil
	local emberRainEmitter: ParticleEmitter? = nil
	local groundImpactOrigin = Vector3.new(startTarget.X, floorY, startTarget.Z)

	-- Spawna rastro de chao queimado abaixo da flecha via Raycast real!
	local function spawnGroundScorch(worldPoint: Vector3, fwdDir: Vector3)
		local rayRes = workspace:Raycast(worldPoint + Vector3.new(0, 4.0, 0), Vector3.new(0, -24.0, 0), rayParams)
		local hitPos = if rayRes then rayRes.Position else Vector3.new(worldPoint.X, floorY, worldPoint.Z)
		local scorchCarrier = makeCarrier(container, CFrame.lookAt(hitPos + Vector3.new(0, 0.08, 0), hitPos + Vector3.new(0, 0.08, 0) + fwdDir), jan, "FugaFloorScorch")

		-- Coluna de poeira incandescente + brasas levantadas do chao
		local scorchStack = createThermalStack(scorchCarrier, {
			Scale = 0.78,
			RateMult = 0.0,
			SpeedMult = 1.15,
			UpAccel = 16.0,
			Spread = Vector2.new(85, 35),
		})
		scorchStack.SetEnabled(false)
		scorchStack.EmitBurst(6, 10, 10, 16)

		-- Marca residual de brasa viva via emissor rasteiro lento (zero decal chapado / zero cilindro!)
		local residualGlow = scorchStack.Core
		residualGlow.Lifetime = NumberRange.new(0.65, 1.25)
		residualGlow.Speed = NumberRange.new(0.4, 1.8)
		residualGlow:Emit(qScale(5))
	end

	-- Spawna destrocos escurecidos/em brasa na detonacao termobarica copiando o material do piso!
	local function spawnThermobaricDebris(epicenter: Vector3)
		local rayRes = workspace:Raycast(epicenter + Vector3.new(0, 6.0, 0), Vector3.new(0, -24.0, 0), rayParams)
		local floorMat = if rayRes then rayRes.Material else Enum.Material.Basalt
		local chunkCount = if isLowQuality() then 10 else 20

		for i = 1, chunkCount do
			local ang = (i / chunkCount) * math.pi * 2 + (math.random() - 0.5) * 0.35
			local speedXZ = 24.0 + math.random() * 44.0
			local speedY = 22.0 + math.random() * 34.0
			local vel = Vector3.new(math.cos(ang) * speedXZ, speedY, math.sin(ang) * speedXZ)
			local rotVel = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))

			local chunk = Instance.new("Part")
			chunk.Name = "FugaScorchedDebris"
			chunk.Shape = Enum.PartType.Block
			chunk.Size = Vector3.new(0.65 + math.random() * 1.15, 0.45 + math.random() * 0.85, 0.65 + math.random() * 1.15)
			chunk.CFrame = CFrame.new(epicenter + Vector3.new(math.cos(ang) * 2.2, 0.4, math.sin(ang) * 2.2))
			chunk.Material = floorMat
			chunk.Color = Color3.fromRGB(24, 14, 12)
			chunk.Anchored = true
			chunk.CanCollide = false
			chunk.CanQuery = false
			chunk.CanTouch = false
			chunk.CastShadow = false
			chunk.Massless = true
			chunk.Parent = container
			jan:Add(chunk)

			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(0, 0.25, 0)
			a0.Parent = chunk
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(0, -0.25, 0)
			a1.Parent = chunk
			local emberTrail = Instance.new("Trail")
			emberTrail.Attachment0 = a0
			emberTrail.Attachment1 = a1
			emberTrail.Texture = trailTex
			emberTrail.Color = ColorSequence.new(Config.Colors.ThermalFlameStart, Config.Colors.ThermalSmokeEnd)
			emberTrail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
			emberTrail.Lifetime = 0.28
			emberTrail.LightEmission = 0.75
			emberTrail.Parent = chunk

			local pos = chunk.Position
			local rot = CFrame.identity
			local life = 0.0
			local dConn: RBXScriptConnection? = nil
			local sig = if RunService:IsClient() then RunService.RenderStepped else RunService.Heartbeat
			dConn = jan:Connect(sig, function(dt: number)
				local step = math.min(dt, 0.05)
				life += step
				vel += Vector3.new(0, -68.0 * step, 0)
				pos += vel * step
				if pos.Y <= epicenter.Y + 0.25 and vel.Y < 0 then
					pos = Vector3.new(pos.X, epicenter.Y + 0.25, pos.Z)
					vel = Vector3.new(vel.X * 0.45, math.abs(vel.Y) * 0.28, vel.Z * 0.45)
				end
				rot *= CFrame.Angles(rotVel.X * step, rotVel.Y * step, rotVel.Z * step)
				chunk.CFrame = CFrame.new(pos) * rot
				if life > 1.35 then
					chunk.Transparency = math.clamp((life - 1.35) / 0.45, 0, 1)
					emberTrail.Enabled = false
				end
				if life >= 1.85 then
					if dConn and dConn.Connected then
						dConn:Disconnect()
					end
					if chunk.Parent then
						chunk:Destroy()
					end
				end
			end)
		end
	end

	-- Loop Mestre das 6 Fases em RenderStepped (dt)
	local function stepTimeline(dt: number)
		local stepDt = math.clamp(dt, 0.0001, 0.25)
		elapsed += stepDt

		if elapsed >= totalDur then
			jan:Cleanup()
			return
		end

		local curOrigin = if aRoot.Parent then aRoot.Position else startOrigin
		local curTarget = if tRoot.Parent then tRoot.Position else startTarget
		floorY = if aRoot.Parent then groundYOf(attacker) else floorY
		local flatAim = Vector3.new(curTarget.X - curOrigin.X, 0, curTarget.Z - curOrigin.Z)
		local aimDir = if flatAim.Magnitude > 0.05 then flatAim.Unit else Vector3.new(0, 0, -1)

		----------------------------------------------------------------
		-- FASE 1: ABERTURA DA FORNALHA & VOZ "FUGA" (0.00s a 1.45s)
		----------------------------------------------------------------
		if elapsed < TL.Phase2BowStart then
			local lPos = if attacker.Parent then leftHandWorldPos(attacker) else (curOrigin + Vector3.new(-0.6, 0.85, -1.0))
			local rPos = if attacker.Parent then rightHandWorldPos(attacker) else (curOrigin + Vector3.new(0.6, 0.85, -1.0))
			local midPos = (lPos + rPos) * 0.5
			furnaceMidCarrier.CFrame = CFrame.new(midPos)
			attPalmL.WorldPosition = lPos
			attPalmR.WorldPosition = rPos

			if elapsed >= TL.VoiceTime and not firedVoice then
				firedVoice = true
				SoundManager.PlayFugaVoice(furnaceMidCarrier, jan)
			end

			if elapsed >= TL.IgniteTime and not firedIgnite then
				firedIgnite = true
				furnaceSnd = SoundManager.PlayFugaIgniteFurnace(furnaceMidCarrier, jan)
				furnaceCoreBeam.Enabled = true
				furnaceAuraBeam.Enabled = true
				furnaceStack.SetEnabled(true)
				furnaceStack.EmitBurst(16, 18, 10, 24)
			end

			if firedIgnite then
				local openAlpha = math.clamp((elapsed - TL.HandsPartTime) / (TL.Phase2BowStart - TL.HandsPartTime), 0, 1)
				setFurnaceLightMult(0.55 + openAlpha * 0.95)
				local curveJitter = math.noise(elapsed * 26.0, 5.1, 0) * (0.35 + openAlpha * 0.65)
				furnaceCoreBeam.CurveSize0 = curveJitter
				furnaceCoreBeam.CurveSize1 = -curveJitter
				furnaceAuraBeam.CurveSize0 = -curveJitter * 1.4
				furnaceAuraBeam.CurveSize1 = curveJitter * 1.4
				fugaBloom.Intensity = openAlpha * 0.35
				casterHighlight.OutlineTransparency = 0.65 - openAlpha * 0.35
			end

		----------------------------------------------------------------
		-- FASE 2: CONJURACAO E TENSAO DO ARCO (1.45s a 3.20s) + APICE (3.20s a 3.30s)
		----------------------------------------------------------------
		elseif elapsed < TL.LaunchTime then
			if not firedPhase2 then
				firedPhase2 = true
				furnaceCoreBeam.Enabled = false
				furnaceAuraBeam.Enabled = false
				furnaceStack.SetEnabled(false)
				if furnaceSnd and furnaceSnd.Parent then
					TweenService:Create(furnaceSnd, TweenInfo.new(0.25), { Volume = 0 }):Play()
				end

				for _, b in ipairs(allBowBeams) do
					b.Enabled = true
				end
				tipStack.SetEnabled(true)
				tailStack.SetEnabled(true)
				topTipWisps.SetEnabled(true)
				botTipWisps.SetEnabled(true)
				feetSmoke.Enabled = true
				for _, sn in ipairs(suctionNodes) do
					sn.trail.Enabled = true
					sn.sparks.Enabled = true
				end

				bowTurbineSnd, bowStringSnd = SoundManager.PlayFugaBowTension(bowCarrier, TL.LaunchTime - TL.Phase2BowStart, jan)
			end

			local drawAlpha = math.clamp((elapsed - TL.Phase2BowStart) / (TL.Phase3ApexStart - TL.Phase2BowStart), 0, 1)
			-- Tensao progressiva pesada: desacelera conforme chega no limite!
			local heavyDraw = 1 - (1 - drawAlpha) ^ 2.8

			local lHand = if attacker.Parent then leftHandWorldPos(attacker) else (curOrigin + aimDir * 1.8 + Vector3.new(0, 1.15, 0))
			local rHand = if attacker.Parent then rightHandWorldPos(attacker) else (curOrigin - aimDir * 0.8 + Vector3.new(0, 1.25, 0))
			local tgtChest = curTarget + Vector3.new(0, 0.95, 0)
			local arrowDirVec = tgtChest - lHand
			local arrowDir = if arrowDirVec.Magnitude > 0.05 then arrowDirVec.Unit else aimDir

			-- Posiciona o arco ancorado dinamicamente na mao esquerda apontando para o peito do oponente!
			local bowCF = CFrame.lookAt(lHand, lHand + arrowDir)
			bowCarrier.CFrame = bowCF
			furnaceMidCarrier.CFrame = bowCF * CFrame.new(0, 0, -1.2)
			setFurnaceLightMult(1.15 + heavyDraw * 0.75)

			-- O Arco enverga para tras conforme a mao direita puxa!
			local halfSpan = 2.35 + heavyDraw * 1.45
			local limbBendBack = 0.55 + heavyDraw * 1.55
			local stringVib = math.sin(elapsed * 98.0) * (0.03 + heavyDraw * 0.08)

			attBowGrip.Position = Vector3.new(0, 0, 0)
			attBowTop.Position = Vector3.new(0, halfSpan, limbBendBack)
			attBowBot.Position = Vector3.new(0, -halfSpan, limbBendBack)
			attStringHand.WorldPosition = rHand + Vector3.new(0, stringVib, 0)

			local spearTipWorld = lHand + arrowDir * (1.85 + heavyDraw * 2.45)
			attArrowTip.WorldPosition = spearTipWorld
			attArrowMid.WorldPosition = rHand:Lerp(spearTipWorld, 0.52)

			-- Curvatura dinamica do arco + helice giratoria nos 3 feixes da Flecha Divina!
			local bendCurve = 1.45 + heavyDraw * 2.15
			local turb = math.noise(elapsed * 32.0, 9.2, 0) * 0.45
			bowUpperCore.CurveSize0 = bendCurve + turb * 0.4
			bowUpperAura.CurveSize0 = bendCurve + turb
			bowLowerCore.CurveSize0 = -(bendCurve + turb * 0.4)
			bowLowerAura.CurveSize0 = -(bendCurve + turb)

			stringTopBeam.CurveSize0 = stringVib * 2.5
			stringBotBeam.CurveSize0 = -stringVib * 2.5

			local helixSpin = elapsed * 20.0
			local helixAmp = 0.55 + heavyDraw * 0.45
			arrowHelixA.CurveSize0 = math.sin(helixSpin) * helixAmp
			arrowHelixA.CurveSize1 = math.cos(helixSpin) * helixAmp
			arrowHelixB.CurveSize0 = -math.sin(helixSpin) * helixAmp
			arrowHelixB.CurveSize1 = -math.cos(helixSpin) * helixAmp

			-- Vortice de Succao Termica de 20 studs espiralando cinzas e faiscas para dentro da flecha!
			local arrowCenter = lHand:Lerp(spearTipWorld, 0.45)
			for i, sn in ipairs(suctionNodes) do
				local cyc = ((elapsed * (1.35 + heavyDraw * 0.85) + i / #suctionNodes) % 1.0)
				local rad = (1.0 - cyc) * 20.0 + 0.35
				local ang = elapsed * (7.5 + heavyDraw * 5.5) + i * (math.pi * 2 / #suctionNodes)
				local yLift = math.sin(ang * 1.5) * (1.0 - cyc) * 3.8
				local worldP = arrowCenter + Vector3.new(math.cos(ang) * rad, yLift, math.sin(ang) * rad)
				sn.carrier.CFrame = CFrame.new(worldP)
			end
			feetHeatCarrier.CFrame = CFrame.new(curOrigin.X, floorY + 0.12, curOrigin.Z)

			-- Bloom aquecendo gradualmente na puxada maxima
			fugaBloom.Intensity = 0.35 + heavyDraw * 0.65
			fugaBloom.Threshold = 1.5 - heavyDraw * 0.45
			launchWorldPos = spearTipWorld

		----------------------------------------------------------------
		-- FASE 3: SOLTURA, RECUO E VOO SUPERSONICO (3.30s a 3.85s)
		----------------------------------------------------------------
		elseif elapsed < TL.Phase4ImplodeStart then
			local flightSpan = TL.Phase4ImplodeStart - TL.LaunchTime
			local u = math.clamp((elapsed - TL.LaunchTime) / flightSpan, 0, 1)
			-- Leve aceleracao exponencial de projetil hipersonico
			local accelU = u ^ 1.32

			if not firedLaunch then
				firedLaunch = true
				-- Desliga o arco e o vortice de succao
				for _, b in ipairs(allBowBeams) do
					b.Enabled = false
				end
				tipStack.SetEnabled(false)
				tailStack.SetEnabled(false)
				topTipWisps.SetEnabled(false)
				botTipWisps.SetEnabled(false)
				feetSmoke.Enabled = false
				for _, sn in ipairs(suctionNodes) do
					sn.trail.Enabled = false
					sn.sparks.Enabled = false
				end
				setFurnaceLightMult(0)
				if bowTurbineSnd and bowTurbineSnd.Parent then
					bowTurbineSnd:Stop()
				end
				if bowStringSnd and bowStringSnd.Parent then
					bowStringSnd:Stop()
				end
				TweenService:Create(casterHighlight, TweenInfo.new(0.35), {
					FillTransparency = 1,
					OutlineTransparency = 1,
				}):Play()

				-- Explosao conica de vento e faiscas na soltura + 3 aneis finos de ar distorcido via Beam circular!
				local releaseOriginCF = CFrame.lookAt(launchWorldPos, curTarget + Vector3.new(0, 0.95, 0))
				local releaseBurstCarrier = makeCarrier(container, releaseOriginCF, jan, "FugaBowShatterBurst")
				local releaseStack = createThermalStack(releaseBurstCarrier, {
					Scale = 1.25,
					RateMult = 0.0,
					SpeedMult = 2.4,
					UpAccel = 4.0,
					Spread = Vector2.new(42, 42),
				})
				releaseStack.SetEnabled(false)
				releaseStack.EmitBurst(24, 28, 16, 68)

				for rIdx = 1, 3 do
					jan:Delay((rIdx - 1) * 0.028, function()
						spawnBeamShockRing(
							container,
							releaseOriginCF * CFrame.new(0, 0, -(rIdx - 1) * 1.4),
							0.8,
							5.5 + rIdx * 2.4,
							0.42,
							0.24 + rIdx * 0.05,
							Config.Colors.ThermalCoreStart,
							Config.Colors.ThermalFlameStart,
							jan
						)
					end)
				end

				-- Liga o cometa de 4 Trails!
				projectileCarrier.CFrame = releaseOriginCF
				projCoreBeam.Enabled = true
				projBodyBeam.Enabled = true
				projStack.SetEnabled(true)
				setProjLightMult(1.35)
				for _, tr in ipairs(projTrails) do
					tr.Enabled = true
				end

				jetFlightSnd = SoundManager.PlayFugaSonicLaunch(projectileCarrier, flightSpan, jan)
				lastSonicRingAt = elapsed
				lastGroundScorchAt = elapsed
			end

			impactWorldPos = curTarget + Vector3.new(0, 0.95, 0)
			local curArrowPos = launchWorldPos:Lerp(impactWorldPos, accelU)
			local flightDirVec = impactWorldPos - launchWorldPos
			local flightDir = if flightDirVec.Magnitude > 0.05 then flightDirVec.Unit else aimDir

			projectileCarrier.CFrame = CFrame.lookAt(curArrowPos, curArrowPos + flightDir)
				* CFrame.Angles(0, 0, elapsed * 24.0)

			-- Aneis sonicos de fogo spawnados a cada 0.035s rasgando o ar!
			if elapsed - lastSonicRingAt >= 0.035 then
				lastSonicRingAt = elapsed
				spawnBeamShockRing(
					container,
					CFrame.lookAt(curArrowPos, curArrowPos + flightDir),
					0.65,
					4.8,
					0.36,
					0.22,
					Config.Colors.ThermalCoreEnd,
					Config.Colors.ThermalFlameEnd,
					jan
				)
			end

			-- Rastro continuo de chao queimado via Raycast para baixo!
			if elapsed - lastGroundScorchAt >= 0.032 then
				lastGroundScorchAt = elapsed
				spawnGroundScorch(curArrowPos, flightDir)
			end

		----------------------------------------------------------------
		-- FASE 4: IMPLOSAO DE VACUO & DUPLO IMPACT FRAME (3.85s a 4.05s)
		----------------------------------------------------------------
		elseif elapsed < TL.Phase5PillarStart then
			if not firedPhase4 then
				firedPhase4 = true
				-- Corta o projetil e o som de voo abruptamente para os 0.12s de silencio!
				projCoreBeam.Enabled = false
				projBodyBeam.Enabled = false
				projStack.SetEnabled(false)
				for _, tr in ipairs(projTrails) do
					tr.Enabled = false
				end
				if jetFlightSnd and jetFlightSnd.Parent then
					jetFlightSnd:Stop()
				end

				-- 1. Hitstop (0.12s) + Silencio Subito!
				AnimatorModule.Hitstop(attacker, 0.12)
				if primaryTarget then
					AnimatorModule.Hitstop(primaryTarget, 0.12)
				end
				groundImpactOrigin = Vector3.new(curTarget.X, groundYOf(primaryTarget or attacker), curTarget.Z)
				projectileCarrier.CFrame = CFrame.new(impactWorldPos)
				SoundManager.PlayFugaVacuumImplosion(projectileCarrier, jan)

				-- 2. Implosao Rapida (0.10s): luz e particulas sugadas para dentro num clarao branco-dourado minusculo!
				local implodeEmitter = Instance.new("ParticleEmitter")
				implodeEmitter.Texture = Config.Fallbacks.Gather
				implodeEmitter.ZOffset = 3
				implodeEmitter.LightEmission = 1
				implodeEmitter.Color = ColorSequence.new(Config.Colors.ThermalCoreStart, Config.Colors.ThermalCoreEnd)
				implodeEmitter.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0.0, 9.5),
					NumberSequenceKeypoint.new(0.85, 0.65),
					NumberSequenceKeypoint.new(1.0, 0.05),
				})
				implodeEmitter.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0.0, 0.55),
					NumberSequenceKeypoint.new(0.7, 0.0),
					NumberSequenceKeypoint.new(1.0, 0.0),
				})
				implodeEmitter.Lifetime = NumberRange.new(0.10, 0.14)
				implodeEmitter.Speed = NumberRange.new(0.1, 0.5)
				implodeEmitter.RotSpeed = NumberRange.new(-320, 320)
				implodeEmitter.Rate = 0
				implodeEmitter.Parent = projectileCarrier
				implodeEmitter:Emit(qScale(18))

				-- 3A. Impact Frame 1 (0.05s): Alto contraste P&B puro (Saturation = -1, Contrast = 3.2, Brightness = 0.3 + Bloom maximo!)
				if not isLowQuality() then
					fugaCC.Saturation = -1.0
					fugaCC.Contrast = 3.2
					fugaCC.Brightness = 0.30
					fugaCC.TintColor = Color3.new(1, 1, 1)
					fugaBloom.Intensity = 2.85
					fugaBloom.Size = 56
					fugaBloom.Threshold = 0.45
					fugaBlur.Size = 12
				end
			end

			local impElapsed = elapsed - TL.Phase4ImplodeStart
			setProjLightMult(math.max(0.15, 2.2 * (1 - impElapsed / 0.14)))

			-- 3B. Impact Frame 2 (0.05s -> 3.90s..3.95s): Flash laranja-escarlate extremo (TintColor = 255, 110, 40)!
			if impElapsed >= 0.05 and not firedImpactFrame2 then
				firedImpactFrame2 = true
				if not isLowQuality() then
					fugaCC.Saturation = 0.25
					fugaCC.Contrast = 1.45
					fugaCC.Brightness = 0.22
					fugaCC.TintColor = Config.Colors.ImpactFlashScarlet
					fugaBlur.Size = 6
				end
			elseif impElapsed >= 0.10 and not isLowQuality() then
				-- Breve compressao escura pre-detonacao (3.95s..4.05s) para o clarao do pilar explodir na tela!
				fugaCC.Contrast = 0.45
				fugaCC.Brightness = -0.08
				fugaBlur.Size = 0
			end

		----------------------------------------------------------------
		-- FASE 5: PILAR COLOSSAL DE FOGO TERMOBARICO ~165 STUDS (4.05s a 7.20s)
		----------------------------------------------------------------
		elseif elapsed < TL.Phase6AftermathStart then
			if not firedPhase5 then
				firedPhase5 = true
				setProjLightMult(0)

				local epicenter = groundImpactOrigin + Vector3.new(0, 0.2, 0)
				local blastRoot = makeCarrier(container, CFrame.new(epicenter), jan, "FugaThermobaricEpicenter")

				-- Audio ensurdecedor em 4 camadas!
				SoundManager.PlayFugaThermobaricDetonation(blastRoot, TL.TotalDuration - TL.Phase5PillarStart, jan)

				-- Iluminacao Apocaliptica Global inundando o Santuario de dourado-alaranjado!
				local _, setEpiLight = createNoiseFireLight(
					blastRoot,
					Config.Colors.ThermalFlameStart,
					6.8,
					60.0,
					41.6,
					jan
				)
				setEpicenterLightMult = setEpiLight

				Lighting.ColorShift_Top = Color3.fromRGB(255, 145, 48)
				Lighting.OutdoorAmbient = Color3.fromRGB(145, 64, 24)
				Lighting.ExposureCompensation = 0.38
				TweenService:Create(Lighting, TweenInfo.new(2.8, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
					ColorShift_Top = snapShiftTop:Lerp(Color3.fromRGB(255, 110, 35), 0.35),
					OutdoorAmbient = snapOutdoor:Lerp(Color3.fromRGB(95, 38, 16), 0.35),
					ExposureCompensation = snapExposure,
				}):Play()

				if not isLowQuality() then
					fugaCC.Saturation = 0.18
					fugaCC.Contrast = 0.32
					fugaCC.Brightness = 0.14
					fugaCC.TintColor = Color3.fromRGB(255, 224, 188)
					fugaBloom.Intensity = 1.85
					fugaBloom.Size = 44
					fugaBloom.Threshold = 0.78
					TweenService:Create(fugaCC, TweenInfo.new(2.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
						Brightness = 0.02,
						Contrast = 0.12,
						TintColor = Color3.fromRGB(255, 238, 220),
					}):Play()
					TweenService:Create(fugaBloom, TweenInfo.new(2.8, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
						Intensity = 0.65,
						Threshold = 1.15,
					}):Play()
				end

				-- 1. PILAR VERTICAL GIGANTESCO (~165 STUDS): 7 emissores termicos empilhados + 4 Beams largos turbulentos + Cogumelo Piroclastico!
				local nodeHeights = { 2.5, 22.0, 46.0, 74.0, 104.0, 134.0, 162.0 }
				local nodeScales = { 5.8, 6.6, 7.2, 7.6, 8.2, 9.4, 11.8 }
				for idx, h in ipairs(nodeHeights) do
					local nodeCarrier = makeCarrier(container, CFrame.new(epicenter + Vector3.new(0, h, 0)), jan, "FugaPillarNode_" .. idx)
					local isCrown = idx >= 6
					local st = createThermalStack(nodeCarrier, {
						Scale = nodeScales[idx],
						RateMult = if isCrown then 1.35 else 1.55,
						SpeedMult = if isCrown then 2.2 else 3.4,
						UpAccel = if isCrown then 18.0 else 44.0,
						Spread = if isCrown then Vector2.new(82, 55) else Vector2.new(18, 18),
						VerticalColumn = not isCrown,
					})
					-- No topo (134..162 studs), amplifica a nuvem piroclastica preta em cogumelo!
					if isCrown then
						st.Smoke.Size = NumberSequence.new({
							NumberSequenceKeypoint.new(0.0, 12.0),
							NumberSequenceKeypoint.new(0.5, 24.0),
							NumberSequenceKeypoint.new(1.0, 36.0),
						})
						st.Smoke.Rate = if isLowQuality() then 28 else 58
						st.Smoke.SpreadAngle = Vector2.new(135, 45)
					end
					st.EmitBurst(18, 22, if isCrown then 28 else 14, 24)
					table.insert(pillarStacks, st)
				end

				-- 4 Beams verticais largos com textura turbulenta subindo a 165 studs de altura!
				local attBase = Instance.new("Attachment")
				attBase.Position = Vector3.new(0, 0, 0)
				attBase.Parent = blastRoot
				local attTop165 = Instance.new("Attachment")
				attTop165.Position = Vector3.new(0, 165.0, 0)
				attTop165.Parent = blastRoot

				local beamConfigs = {
					{ w0 = 10.5, w1 = 14.5, col0 = Config.Colors.ThermalCoreStart, col1 = Config.Colors.ThermalCoreEnd, spd = 9.5, em = 1.0 },
					{ w0 = 18.0, w1 = 25.0, col0 = Config.Colors.ThermalFlameStart, col1 = Config.Colors.ThermalFlameEnd, spd = 7.4, em = 0.85 },
					{ w0 = 22.0, w1 = 30.0, col0 = Config.Colors.ThermalFlameEnd, col1 = Config.Colors.PyroSootLit, spd = 5.8, em = 0.45 },
					{ w0 = 13.0, w1 = 18.0, col0 = Config.Colors.ThermalCoreEnd, col1 = Config.Colors.ThermalFlameStart, spd = 11.2, em = 1.0 },
				}
				for _, bc in ipairs(beamConfigs) do
					local pb = makeFlameBeam(
						blastRoot,
						attBase,
						attTop165,
						pillarBeamTex,
						ColorSequence.new(bc.col0, bc.col1),
						bc.w0,
						bc.w1,
						bc.spd,
						bc.em
					)
					pb.TextureLength = 0.32
					table.insert(pillarBeams, pb)
				end

				-- 2. VORTICE ESPIRAL ASCENDENTE: 4 pontos orbitando a coluna de baixo para cima com Trails grossos flamejantes!
				for v = 1, 4 do
					local vc = makeCarrier(container, CFrame.new(epicenter), jan, "FugaPillarVortex_" .. v)
					local va0 = Instance.new("Attachment")
					va0.Position = Vector3.new(-1.35, 0, 0)
					va0.Parent = vc
					local va1 = Instance.new("Attachment")
					va1.Position = Vector3.new(1.35, 0, 0)
					va1.Parent = vc

					local vTrail = Instance.new("Trail")
					vTrail.Attachment0 = va0
					vTrail.Attachment1 = va1
					vTrail.Texture = trailTex
					vTrail.Color = ColorSequence.new(
						if v % 2 == 1 then Config.Colors.ThermalCoreStart else Config.Colors.ThermalFlameStart,
						Config.Colors.ThermalFlameEnd
					)
					vTrail.Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0.0, 0.06),
						NumberSequenceKeypoint.new(0.6, 0.32),
						NumberSequenceKeypoint.new(1.0, 1.0),
					})
					vTrail.Lifetime = 0.48
					vTrail.LightEmission = 1
					vTrail.FaceCamera = true
					vTrail.Parent = vc

					local vStack = createThermalStack(vc, {
						Scale = 2.2,
						RateMult = 0.75,
						SpeedMult = 1.5,
						UpAccel = 22.0,
						Spread = Vector2.new(45, 45),
					})
					table.insert(vortexNodes, { carrier = vc, trail = vTrail, stack = vStack })
				end

				-- 3. ONDA DE CHOQUE RENTE AO CHAO (360°) + DESTROCOS EM BRASA + ANEIS DE IMPACTO!
				local groundWaveStack = createThermalStack(blastRoot, {
					Scale = 3.8,
					RateMult = 0.0,
					SpeedMult = 4.2,
					UpAccel = 2.0,
					Spread = Vector2.new(180, 6),
				})
				groundWaveStack.SetEnabled(false)
				groundWaveStack.Core.Speed = NumberRange.new(48, 92)
				groundWaveStack.Body.Speed = NumberRange.new(42, 84)
				groundWaveStack.Smoke.Speed = NumberRange.new(32, 68)
				groundWaveStack.Sparks.Speed = NumberRange.new(58, 125)
				groundWaveStack.Sparks.SpreadAngle = Vector2.new(180, 8)
				groundWaveStack.EmitBurst(45, 58, 52, 110)

				for w = 1, 3 do
					jan:Delay((w - 1) * 0.06, function()
						spawnBeamShockRing(
							container,
							CFrame.new(epicenter + Vector3.new(0, 0.45 + w * 0.3, 0)) * CFrame.Angles(math.rad(90), 0, 0),
							2.5,
							38.0 + w * 12.0,
							1.65,
							0.48 + w * 0.10,
							Config.Colors.ThermalCoreStart,
							Config.Colors.ThermalFlameEnd,
							jan
						)
					end)
				end

				spawnThermobaricDebris(epicenter)

				-- Highlight incandescente nos alvos atingidos
				local hitModels: { Model } = if allTargets and #allTargets > 0
					then allTargets
					elseif primaryTarget then { primaryTarget }
					else {}
				for _, hm in ipairs(hitModels) do
					if hm.Parent then
						local hl = Instance.new("Highlight")
						hl.FillColor = Config.Colors.ThermalCoreEnd
						hl.OutlineColor = Config.Colors.ThermalFlameStart
						hl.FillTransparency = 0.12
						hl.OutlineTransparency = 0
						hl.Parent = hm
						jan:Add(hl)
						TweenService:Create(hl, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
							FillTransparency = 1,
							OutlineTransparency = 1,
						}):Play()
					end
				end

				-- Inicia o dossel da Chuva de Cinzas e Brasas em 6.30s (durando os 2.5s finais ate 8.80s!)
				jan:Delay(math.max(0.1, (TL.TotalDuration - 2.50) - TL.Phase5PillarStart), function()
					local canopy = makeCarrier(container, CFrame.new(epicenter + Vector3.new(0, 34.0, 0)), jan, "FugaAshRainCanopy")
					canopy.Size = Vector3.new(92, 1, 92)

					local ashes = Instance.new("ParticleEmitter")
					ashes.Name = "FugaFallingAshes"
					ashes.Texture = Config.Fallbacks.Spark
					ashes.ZOffset = 1
					ashes.LightEmission = 0.15
					ashes.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0.0, Config.Colors.AshGrey),
						ColorSequenceKeypoint.new(0.6, Color3.fromRGB(92, 84, 82)),
						ColorSequenceKeypoint.new(1.0, Config.Colors.ThermalSmokeStart),
					})
					ashes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0.12) })
					ashes.Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0.0, 0.25),
						NumberSequenceKeypoint.new(0.8, 0.42),
						NumberSequenceKeypoint.new(1.0, 1.0),
					})
					ashes.Lifetime = NumberRange.new(1.8, 2.8)
					ashes.Rate = if isLowQuality() then 45 else 95
					ashes.Speed = NumberRange.new(3.0, 7.5)
					ashes.SpreadAngle = Vector2.new(28, 28)
					ashes.EmissionDirection = Enum.NormalId.Bottom
					ashes.Acceleration = Vector3.new(2.2, -4.5, 1.4)
					ashes.RotSpeed = NumberRange.new(-90, 90)
					ashes.Parent = canopy
					ashRainEmitter = ashes

					local cinders = Instance.new("ParticleEmitter")
					cinders.Name = "FugaFallingEmbers"
					cinders.Texture = Config.Fallbacks.Spark
					cinders.ZOffset = 2
					cinders.LightEmission = 1.0
					cinders.Color = ColorSequence.new(Config.Colors.ThermalCoreEnd, Config.Colors.ThermalFlameStart)
					cinders.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.24), NumberSequenceKeypoint.new(1, 0.04) })
					cinders.Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0.0, 0.05),
						NumberSequenceKeypoint.new(0.75, 0.28),
						NumberSequenceKeypoint.new(1.0, 1.0),
					})
					cinders.Lifetime = NumberRange.new(1.6, 2.6)
					cinders.Rate = if isLowQuality() then 32 else 68
					cinders.Speed = NumberRange.new(2.5, 6.5)
					cinders.SpreadAngle = Vector2.new(32, 32)
					cinders.EmissionDirection = Enum.NormalId.Bottom
					cinders.Acceleration = Vector3.new(2.8, -3.8, -1.2)
					cinders.Parent = canopy
					emberRainEmitter = cinders
				end)
			end

			-- Atualiza em tempo real os Beams turbulentos do pilar e os 4 orbiters espirais ascendentes!
			local pTime = elapsed - TL.Phase5PillarStart
			for idx, pb in ipairs(pillarBeams) do
				local wave = math.noise(elapsed * 9.5, idx * 7.3, 0) * 6.5
				pb.CurveSize0 = wave
				pb.CurveSize1 = -wave
			end

			for v, vn in ipairs(vortexNodes) do
				local climbFrac = ((pTime * 0.95 + (v - 1) * 0.25) % 1.0)
				local yH = climbFrac * 156.0
				local rad = 6.5 + climbFrac * 7.5 + math.sin(elapsed * 8.0 + v) * 1.4
				local ang = elapsed * 11.5 + (v - 1) * (math.pi * 0.5)
				local nextAng = ang + 0.35
				local pNow = groundImpactOrigin + Vector3.new(math.cos(ang) * rad, yH, math.sin(ang) * rad)
				local pNext = groundImpactOrigin + Vector3.new(math.cos(nextAng) * rad, yH + 6.0, math.sin(nextAng) * rad)
				vn.carrier.CFrame = CFrame.lookAt(pNow, pNext)
			end

			if setEpicenterLightMult then
				local coolFactor = 1.0 - math.clamp((pTime - 1.8) / 1.6, 0, 0.45)
				setEpicenterLightMult(coolFactor)
			end

		----------------------------------------------------------------
		-- FASE 6: POS-CATACLISMO & RESTAURACAO LIMPA (7.20s a 8.80s)
		----------------------------------------------------------------
		else
			if not firedPhase6 then
				firedPhase6 = true
				-- O nucleo branco do pilar apaga primeiro, deixando chamas vermelho-escuras morrendo e rolos de fumaca negra!
				for idx, st in ipairs(pillarStacks) do
					st.Core.Enabled = false
					st.Sparks.Enabled = false
					if idx > 2 then
						st.Body.Enabled = false
					else
						st.Body.Color = ColorSequence.new(Config.Colors.ThermalFlameEnd, Color3.fromRGB(72, 8, 4))
						st.Body.Rate = if isLowQuality() then 10 else 22
					end
					st.Smoke.Rate = if isLowQuality() then 12 else 26
				end
				for _, vn in ipairs(vortexNodes) do
					vn.trail.Enabled = false
					vn.stack.SetEnabled(false)
				end
				for _, pb in ipairs(pillarBeams) do
					TweenService:Create(pb, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Width0 = 0,
						Width1 = 0,
					}):Play()
				end

				TweenService:Create(fugaBloom, TweenInfo.new(1.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
					Intensity = 0,
					Threshold = 2.0,
				}):Play()
				TweenService:Create(fugaCC, TweenInfo.new(1.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
					Brightness = 0,
					Contrast = 0,
					Saturation = 0,
					TintColor = Color3.new(1, 1, 1),
				}):Play()
				TweenService:Create(Lighting, TweenInfo.new(1.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
					Ambient = snapAmbient,
					OutdoorAmbient = snapOutdoor,
					ColorShift_Top = snapShiftTop,
					ExposureCompensation = snapExposure,
				}):Play()
			end

			local afterProgress = math.clamp((elapsed - TL.Phase6AftermathStart) / (totalDur - TL.Phase6AftermathStart), 0, 1)
			if setEpicenterLightMult then
				setEpicenterLightMult(math.max(0, 0.55 * (1 - afterProgress)))
			end

			if afterProgress > 0.55 then
				for _, st in ipairs(pillarStacks) do
					st.SetEnabled(false)
				end
			end
			if afterProgress > 0.78 then
				if ashRainEmitter then
					ashRainEmitter.Enabled = false
				end
				if emberRainEmitter then
					emberRainEmitter.Enabled = false
				end
			end
		end
	end

	if RunService:IsClient() then
		jan:Connect(RunService.RenderStepped, function(dt: number)
			lastRenderClock = os.clock()
			stepTimeline(dt)
		end)
		jan:Connect(RunService.Heartbeat, function(dt: number)
			if os.clock() - lastRenderClock > 0.12 then
				stepTimeline(dt)
			end
		end)
	else
		jan:Connect(RunService.Heartbeat, stepTimeline)
	end
end

function FugaVFX.Cleanup()
	for jan in pairs(activeFugaJanitors) do
		activeFugaJanitors[jan] = nil
		jan:Cleanup()
	end
end

return FugaVFX
