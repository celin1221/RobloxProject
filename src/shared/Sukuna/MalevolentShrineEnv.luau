--!strict
--[[
	ReplicatedStorage/Sukuna/MalevolentShrineEnv.luau
	Transformacao do Campo e Arquitetura 3D Monumental do Santuario Malevolente (Fukuma Mizushi):
	  - Ceu vermelho-sangue apocaliptico (Sky + Atmosphere + Lighting) com restauracao via Janitor
	  - Mare de nevoa escura e carmesim tomando o piso reflexivo avermelhado
	  - Santuario Malevolente 3D erguendo-se atras do Sukuna entre fumaca negra e faiscas
	    (pilares escuros, telhados curvos de pagode em duas camadas, beirais empinados,
	    mandibulas/presas osseas nas bocas do templo, cranios e chifres estilizados)
	  - Dezenas de cortes 3D rasgando o ar continuamente e rajadas sincronizadas com os
	    ticks de 15% do HP Maximo de sangramento por rodada.
	  - ZERO cones, esferas ou cilindros de Neon!
]]

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(script.Parent:WaitForChild("Config"))
local Janitor = require(script.Parent:WaitForChild("Janitor"))
local SoundManager = require(script.Parent:WaitForChild("SoundManager"))

local MalevolentShrineEnv = {}

local domainJanitor: Janitor.JanitorInstance? = nil
local activeShrineModel: Model? = nil
local activeDomainCenter = Vector3.zero
local activeFloorY = 0.0

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

local function getVfxContainer(): Folder
	local f = workspace:FindFirstChild(Config.WorkspaceFolderName)
	if f and f:IsA("Folder") then
		return f
	end
	local created = Instance.new("Folder")
	created.Name = Config.WorkspaceFolderName
	created.Parent = workspace
	return created
end

-- Cria bloco arquitetonico estrutural (madeira escura, pedra obsidiana ou osso — NUNCA Cone/Ball/Cylinder de Neon!)
local function archBlock(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	reflectance: number?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Reflectance = reflectance or 0
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

local function makeAnchor(parent: Instance, cf: CFrame): Part
	local p = archBlock(parent, "VfxAnchor", Vector3.new(0.2, 0.2, 0.2), cf, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	p.Transparency = 1
	return p
end

-- Constroi chifre estilizado segmentado em blocos afilados (sem cones!)
local function buildStylizedHorn(parent: Instance, baseCF: CFrame, sideSign: number, scale: number)
	local segs = 5
	local curCF = baseCF
	for i = 1, segs do
		local frac = (i - 1) / segs
		local thick = (0.85 - frac * 0.58) * scale
		local len = 1.45 * scale
		curCF = curCF
			* CFrame.Angles(math.rad(-14), math.rad(sideSign * 8), math.rad(sideSign * 16))
			* CFrame.new(0, len * 0.5, 0)
		archBlock(parent, "ShrineHornSeg", Vector3.new(thick, len, thick), curCF, Config.Colors.BonePale, Enum.Material.Slate)
		curCF = curCF * CFrame.new(0, len * 0.45, 0)
	end
end

-- Constroi cranio bovino/demoniaco estilizado com chifres na fachada do Santuario
local function buildStylizedSkull(parent: Instance, skullCF: CFrame, scale: number)
	archBlock(parent, "SkullCranium", Vector3.new(2.2 * scale, 1.7 * scale, 1.5 * scale), skullCF, Config.Colors.BonePale, Enum.Material.Slate)
	archBlock(
		parent,
		"SkullSnout",
		Vector3.new(1.35 * scale, 1.25 * scale, 1.65 * scale),
		skullCF * CFrame.new(0, -0.65 * scale, -0.45 * scale),
		Config.Colors.BonePale,
		Enum.Material.Slate
	)
	-- Cavidades oculares escuras
	for _, sx in ipairs({ -0.58, 0.58 }) do
		archBlock(
			parent,
			"SkullSocket",
			Vector3.new(0.46 * scale, 0.38 * scale, 0.35 * scale),
			skullCF * CFrame.new(sx * scale, 0.12 * scale, -0.68 * scale),
			Config.Colors.Obsidian,
			Enum.Material.SmoothPlastic
		)
	end
	buildStylizedHorn(parent, skullCF * CFrame.new(-0.95 * scale, 0.55 * scale, 0), -1, scale)
	buildStylizedHorn(parent, skullCF * CFrame.new(0.95 * scale, 0.55 * scale, 0), 1, scale)
end

-- Constroi telhado de pagode curvo em placas inclinadas com pontas arrebitadas
local function buildPagodaRoofTier(parent: Instance, centerCF: CFrame, width: number, depth: number, height: number)
	-- Nucleo central do telhado
	archBlock(parent, "RoofCore", Vector3.new(width * 0.76, height * 0.55, depth * 0.72), centerCF * CFrame.new(0, height * 0.25, 0), Config.Colors.ShrineRoof, Enum.Material.Slate)

	-- Duas aguas principais inclinadas (frente e tras) + beirais curvos arrebitados
	for _, sz in ipairs({ -1, 1 }) do
		local slopeCF = centerCF
			* CFrame.new(0, height * 0.08, sz * (depth * 0.28))
			* CFrame.Angles(math.rad(sz * 22), 0, 0)
		archBlock(parent, "RoofSlope", Vector3.new(width * 0.96, 0.55, depth * 0.62), slopeCF, Config.Colors.ShrineRoof, Enum.Material.Slate)

		-- Beiral externo empinado para cima (curvatura classica de pagode)
		local eaveCF = centerCF
			* CFrame.new(0, -height * 0.16, sz * (depth * 0.56))
			* CFrame.Angles(math.rad(sz * -12), 0, 0)
		archBlock(parent, "RoofEave", Vector3.new(width * 1.08, 0.42, depth * 0.22), eaveCF, Config.Colors.CrimsonCore, Enum.Material.WoodPlanks)
	end

	-- Pontas dos 4 cantos arrebitadas com chifres de beiral
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local cornerCF = centerCF
				* CFrame.new(sx * (width * 0.52), -height * 0.04, sz * (depth * 0.54))
				* CFrame.Angles(math.rad(sz * -18), math.rad(sx * sz * 28), math.rad(sx * 18))
			archBlock(parent, "CornerRafter", Vector3.new(2.2, 0.38, 3.2), cornerCF, Config.Colors.CrimsonBright, Enum.Material.WoodPlanks)
		end
	end

	-- Cumeeira ornamental superior (Shachihoko / espinha dorsal maldita)
	archBlock(parent, "RidgeBeam", Vector3.new(width * 0.88, 0.75, 0.95), centerCF * CFrame.new(0, height * 0.62, 0), Config.Colors.Obsidian, Enum.Material.Slate)
	buildStylizedHorn(parent, centerCF * CFrame.new(-width * 0.42, height * 0.65, 0) * CFrame.Angles(0, math.rad(90), 0), -1, 0.72)
	buildStylizedHorn(parent, centerCF * CFrame.new(width * 0.42, height * 0.65, 0) * CFrame.Angles(0, math.rad(-90), 0), 1, 0.72)
end

-- Monta o modelo arquitetonico completo do Santuario Malevolente
local function buildShrineModel(originCF: CFrame): (Model, { { part: BasePart, relCF: CFrame } })
	local shrine = Instance.new("Model")
	shrine.Name = Config.ShrineModelName

	-- Base escalonada de pedra escura / altar
	archBlock(shrine, "PlinthBase1", Vector3.new(28, 1.6, 22), originCF * CFrame.new(0, 0.8, 0), Config.Colors.Obsidian, Enum.Material.Basalt)
	archBlock(shrine, "PlinthBase2", Vector3.new(24, 1.4, 18.5), originCF * CFrame.new(0, 2.3, 0), Config.Colors.ShrineWood, Enum.Material.Slate)
	archBlock(shrine, "PlinthTrim", Vector3.new(24.6, 0.35, 19.1), originCF * CFrame.new(0, 3.05, 0), Config.Colors.CrimsonCore, Enum.Material.SmoothPlastic)

	-- Camara escura interna do Santuario (boca abissal)
	local mawCore = archBlock(shrine, "AbyssMaw", Vector3.new(15.5, 10.2, 11.5), originCF * CFrame.new(0, 8.2, 0), Color3.fromRGB(6, 2, 4), Enum.Material.SmoothPlastic)
	local mawLight = Instance.new("PointLight")
	mawLight.Name = "ShrineMawLight"
	mawLight.Color = Config.Colors.CrimsonBright
	mawLight.Brightness = 3.6
	mawLight.Range = 42
	mawLight.Shadows = false
	mawLight.Parent = mawCore

	-- 4 Pilares principais vermelhos-escuros + 4 pilares internos
	for _, sx in ipairs({ -9.2, -4.2, 4.2, 9.2 }) do
		for _, sz in ipairs({ -6.8, 6.8 }) do
			local colH = 10.6
			archBlock(
				shrine,
				"ShrinePillar",
				Vector3.new(1.35, colH, 1.35),
				originCF * CFrame.new(sx, 3.0 + colH * 0.5, sz),
				Config.Colors.CrimsonCore,
				Enum.Material.WoodPlanks
			)
			archBlock(
				shrine,
				"PillarBase",
				Vector3.new(1.85, 0.65, 1.85),
				originCF * CFrame.new(sx, 3.32, sz),
				Config.Colors.Obsidian,
				Enum.Material.Basalt
			)
		end
	end

	-- Mandibula e presas osseas gigantes na boca frontal do Santuario!
	archBlock(shrine, "UpperJawLintel", Vector3.new(9.8, 1.1, 1.8), originCF * CFrame.new(0, 12.6, -7.0), Config.Colors.BonePale, Enum.Material.Slate)
	archBlock(shrine, "LowerJawStep", Vector3.new(9.8, 0.85, 1.8), originCF * CFrame.new(0, 3.45, -7.0), Config.Colors.BonePale, Enum.Material.Slate)
	for i = -3, 3 do
		local fx = i * 1.22
		local toothH = if math.abs(i) == 3 then 1.95 else 1.25
		-- Presas superiores
		archBlock(
			shrine,
			"UpperFang",
			Vector3.new(0.52, toothH, 0.52),
			originCF * CFrame.new(fx, 12.1 - toothH * 0.5, -7.15) * CFrame.Angles(math.rad(6), 0, 0),
			Config.Colors.BonePale,
			Enum.Material.Slate
		)
		-- Presas inferiores
		archBlock(
			shrine,
			"LowerFang",
			Vector3.new(0.48, toothH * 0.82, 0.48),
			originCF * CFrame.new(fx, 3.85 + toothH * 0.4, -7.15) * CFrame.Angles(math.rad(-6), 0, 0),
			Config.Colors.BonePale,
			Enum.Material.Slate
		)
	end

	-- Telhado de Pagode Nivel 1 (amplo)
	buildPagodaRoofTier(shrine, originCF * CFrame.new(0, 14.4, 0), 30.0, 21.0, 3.4)

	-- Segundo andar do templo + cranios com chifres
	archBlock(shrine, "UpperSanctum", Vector3.new(16.0, 5.2, 11.0), originCF * CFrame.new(0, 18.2, 0), Config.Colors.ShrineWood, Enum.Material.WoodPlanks)
	for _, sx in ipairs({ -6.8, 6.8 }) do
		for _, sz in ipairs({ -4.8, 4.8 }) do
			archBlock(shrine, "UpperPillar", Vector3.new(1.05, 5.4, 1.05), originCF * CFrame.new(sx, 18.2, sz), Config.Colors.CrimsonCore, Enum.Material.WoodPlanks)
		end
	end

	-- Cranio monumental central na fachada frontal e laterais
	buildStylizedSkull(shrine, originCF * CFrame.new(0, 18.4, -6.1), 1.35)
	buildStylizedSkull(shrine, originCF * CFrame.new(-8.6, 10.6, -6.9) * CFrame.Angles(0, math.rad(16), 0), 0.82)
	buildStylizedSkull(shrine, originCF * CFrame.new(8.6, 10.6, -6.9) * CFrame.Angles(0, math.rad(-16), 0), 0.82)

	-- Telhado de Pagode Nivel 2 (topo monumental)
	buildPagodaRoofTier(shrine, originCF * CFrame.new(0, 21.8, 0), 23.0, 16.0, 3.2)

	-- Emissores continuos de fumaca negra e brasas carmesim emanando da boca do Santuario
	local smokeEmitter = Instance.new("ParticleEmitter")
	smokeEmitter.Name = "ShrineSmoke"
	smokeEmitter.Texture = Config.ResolveAsset(Config.Assets.PyroSmokeTextureId, Config.Fallbacks.Smoke)
	smokeEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Config.Colors.BloodDeep),
		ColorSequenceKeypoint.new(0.4, Config.Colors.Obsidian),
		ColorSequenceKeypoint.new(1, Config.Colors.Obsidian),
	})
	smokeEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.35, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	smokeEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 3.5),
		NumberSequenceKeypoint.new(0.6, 8.5),
		NumberSequenceKeypoint.new(1, 13.0),
	})
	smokeEmitter.Lifetime = NumberRange.new(1.8, 3.0)
	smokeEmitter.Rate = 26
	smokeEmitter.Speed = NumberRange.new(3, 8)
	smokeEmitter.SpreadAngle = Vector2.new(85, 45)
	smokeEmitter.RotSpeed = NumberRange.new(-35, 35)
	smokeEmitter.LightEmission = 0
	smokeEmitter.Parent = mawCore

	local emberEmitter = Instance.new("ParticleEmitter")
	emberEmitter.Name = "ShrineEmbers"
	emberEmitter.Texture = Config.ResolveAsset(Config.Assets.EmberSparkTextureId, Config.Fallbacks.Spark)
	emberEmitter.Color = ColorSequence.new(Config.Colors.SlashWhite, Config.Colors.CrimsonBright)
	emberEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.7, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	emberEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.38),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	emberEmitter.Lifetime = NumberRange.new(1.2, 2.4)
	emberEmitter.Rate = 34
	emberEmitter.Speed = NumberRange.new(6, 16)
	emberEmitter.SpreadAngle = Vector2.new(120, 75)
	emberEmitter.Acceleration = Vector3.new(0, 5, 0)
	emberEmitter.Drag = 1.8
	emberEmitter.LightEmission = 1
	emberEmitter.Parent = mawCore

	local partsRel: { { part: BasePart, relCF: CFrame } } = {}
	local invOrigin = originCF:Inverse()
	for _, d in ipairs(shrine:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(partsRel, { part = d, relCF = invOrigin * d.CFrame })
		end
	end

	return shrine, partsRel
end

-- Cria um corte 3D instantaneo no espaco usando Beam curvado + particulas VelocityParallel (ZERO primitivos!)
function MalevolentShrineEnv.SpawnAirSlash3D(
	parent: Instance,
	center: Vector3,
	length: number,
	width: number,
	duration: number,
	isCrimson: boolean,
	curveAmt: number?
)
	local rotCF = CFrame.new(center)
		* CFrame.Angles(
			math.rad(math.random(-75, 75)),
			math.rad(math.random(0, 360)),
			math.rad(math.random(-85, 85))
		)
	local holder = makeAnchor(parent, rotCF)

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(-length * 0.5, 0, 0)
	a0.Parent = holder
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(length * 0.5, 0, 0)
	a1.Parent = holder

	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Texture = Config.ResolveAsset(Config.Assets.SlashBeamTextureId, Config.Fallbacks.Streak)
	beam.TextureSpeed = 3.5
	beam.TextureLength = 1.0
	local mainCol = if isCrimson then Config.Colors.CrimsonBright else Config.Colors.SlashWhite
	beam.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Config.Colors.CrimsonCore),
		ColorSequenceKeypoint.new(0.5, mainCol),
		ColorSequenceKeypoint.new(1, Config.Colors.CrimsonCore),
	})
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.18, 0.04),
		NumberSequenceKeypoint.new(0.5, 0.0),
		NumberSequenceKeypoint.new(0.82, 0.04),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Width0 = width * 0.18
	beam.Width1 = width
	beam.CurveSize0 = curveAmt or ((math.random() - 0.5) * 3.6)
	beam.CurveSize1 = -(curveAmt or ((math.random() - 0.5) * 3.6))
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Segments = 18
	beam.Parent = holder

	-- Segundo Beam fino central branco-puro para nitidez de lamina anime
	local coreBeam = beam:Clone()
	coreBeam.Color = ColorSequence.new(Config.Colors.SlashWhite)
	coreBeam.Width0 = width * 0.06
	coreBeam.Width1 = width * 0.34
	coreBeam.Parent = holder

	-- Faiscas cortantes VelocityParallel rasgando ao longo da linha do corte
	local slashSparks = Instance.new("ParticleEmitter")
	slashSparks.Texture = Config.ResolveAsset(Config.Assets.SlashStreakTextureId, Config.Fallbacks.Streak)
	slashSparks.Orientation = Enum.ParticleOrientation.VelocityParallel
	slashSparks.Color = ColorSequence.new(Config.Colors.SlashWhite, Config.Colors.CrimsonBright)
	slashSparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.65, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	slashSparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.42),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	slashSparks.Squash = NumberSequence.new(1.8, 2.8)
	slashSparks.Lifetime = NumberRange.new(0.14, 0.26)
	slashSparks.Speed = NumberRange.new(22, 46)
	slashSparks.SpreadAngle = Vector2.new(180, 18)
	slashSparks.Drag = 4.5
	slashSparks.LightEmission = 1
	slashSparks.Rate = 0
	slashSparks.Parent = holder
	slashSparks:Emit(8)

	TweenService:Create(
		beam,
		TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Width0 = 0, Width1 = 0 }
	):Play()
	TweenService:Create(
		coreBeam,
		TweenInfo.new(duration * 0.85, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Width0 = 0, Width1 = 0 }
	):Play()

	task.delay(duration + 0.28, function()
		if holder.Parent then
			holder:Destroy()
		end
	end)
end

-- Dispara rajada de dezenas de cortes 3D no ar + efeito de sangramento de 15% sobre os alvos!
function MalevolentShrineEnv.PlayDomainSlashVolley(targets: { Model }, isInvocation: boolean?)
	local vfxRoot = getVfxContainer()
	local countPerTarget = if isInvocation then 22 else 16

	for idx, tgt in ipairs(targets) do
		local tRoot = rootOf(tgt)
		if not tRoot or not tRoot.Parent then
			continue
		end
		local center = tRoot.Position + Vector3.new(0, 0.55, 0)

		if idx == 1 then
			local sndAnchor = makeAnchor(vfxRoot, CFrame.new(center))
			SoundManager.PlayDomainSlashVolley(sndAnchor)
			task.delay(2.0, function()
				if sndAnchor.Parent then
					sndAnchor:Destroy()
				end
			end)
		end

		-- Dezenas de cortes 3D fatiando o espaco ao redor do oponente
		for i = 1, countPerTarget do
			task.delay((i - 1) * 0.026, function()
				if not vfxRoot.Parent then
					return
				end
				local curCenter = if tRoot.Parent then (tRoot.Position + Vector3.new(0, 0.55, 0)) else center
				local jitter = Vector3.new(
					(math.random() - 0.5) * 6.4,
					(math.random() - 0.5) * 5.2,
					(math.random() - 0.5) * 6.4
				)
				MalevolentShrineEnv.SpawnAirSlash3D(
					vfxRoot,
					curCenter + jitter,
					8.5 + math.random() * 6.5,
					0.65 + math.random() * 0.45,
					0.24,
					i % 2 == 1
				)
			end)
		end

		-- Efeito visceral/estilizado de sangramento amaldicoado no alvo (nevoa carmesim + gotas energeticas)
		local bleedAnchor = makeAnchor(vfxRoot, CFrame.new(center))
		local bleedMist = Instance.new("ParticleEmitter")
		bleedMist.Texture = Config.ResolveAsset(Config.Assets.BloodMistTextureId, Config.Fallbacks.Smoke)
		bleedMist.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Config.Colors.CrimsonBright),
			ColorSequenceKeypoint.new(0.55, Config.Colors.BloodDeep),
			ColorSequenceKeypoint.new(1, Config.Colors.Obsidian),
		})
		bleedMist.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(0.5, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		})
		bleedMist.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.4),
			NumberSequenceKeypoint.new(1, 4.8),
		})
		bleedMist.Lifetime = NumberRange.new(0.38, 0.68)
		bleedMist.Speed = NumberRange.new(5, 16)
		bleedMist.SpreadAngle = Vector2.new(180, 180)
		bleedMist.Drag = 3.2
		bleedMist.LightEmission = 0.2
		bleedMist.Rate = 0
		bleedMist.Parent = bleedAnchor
		bleedMist:Emit(26)

		local bleedSparks = Instance.new("ParticleEmitter")
		bleedSparks.Texture = Config.ResolveAsset(Config.Assets.SlashStreakTextureId, Config.Fallbacks.Streak)
		bleedSparks.Orientation = Enum.ParticleOrientation.VelocityParallel
		bleedSparks.Color = ColorSequence.new(Config.Colors.SlashWhite, Config.Colors.CrimsonBright)
		bleedSparks.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		bleedSparks.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.52),
			NumberSequenceKeypoint.new(1, 0.06),
		})
		bleedSparks.Squash = NumberSequence.new(1.6, 2.8)
		bleedSparks.Lifetime = NumberRange.new(0.22, 0.42)
		bleedSparks.Speed = NumberRange.new(18, 42)
		bleedSparks.SpreadAngle = Vector2.new(180, 180)
		bleedSparks.Acceleration = Vector3.new(0, -28, 0)
		bleedSparks.Drag = 2.4
		bleedSparks.LightEmission = 0.9
		bleedSparks.Rate = 0
		bleedSparks.Parent = bleedAnchor
		bleedSparks:Emit(32)

		-- Highlight carmesim breve de impacto de sangramento
		if tgt.Parent then
			local hl = Instance.new("Highlight")
			hl.Name = "DomainBleedHighlight"
			hl.FillColor = Config.Colors.CrimsonBright
			hl.OutlineColor = Config.Colors.SlashWhite
			hl.FillTransparency = 0.35
			hl.OutlineTransparency = 0.1
			hl.Parent = tgt
			TweenService:Create(hl, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				FillTransparency = 1,
				OutlineTransparency = 1,
			}):Play()
			task.delay(0.45, function()
				if hl.Parent then
					hl:Destroy()
				end
			end)
		end

		task.delay(0.85, function()
			if bleedAnchor.Parent then
				bleedAnchor:Destroy()
			end
		end)
	end
end

-- Abre e sustenta o cenario completo do Santuario Malevolente pelas 2 rodadas ativas
function MalevolentShrineEnv.OpenDomain(attacker: Model, primaryTarget: Model?)
	MalevolentShrineEnv.CloseDomain(true)

	local aRoot = rootOf(attacker)
	if not aRoot then
		return
	end

	local jan = Janitor.new()
	domainJanitor = jan

	local vfxRoot = getVfxContainer()
	local floorY = groundYOf(attacker)
	activeFloorY = floorY

	local tRoot = rootOf(primaryTarget)
	local arenaCenter = if tRoot
		then Vector3.new((aRoot.Position.X + tRoot.Position.X) * 0.5, floorY, (aRoot.Position.Z + tRoot.Position.Z) * 0.5)
		else Vector3.new(aRoot.Position.X, floorY, aRoot.Position.Z)
	activeDomainCenter = arenaCenter

	-- 1. Ceu vermelho-sangue apocaliptico + Atmosphere densa (snapshot restaurado pelo Janitor!)
	local existingAtmos, existingSky = jan:SnapshotLighting()
	if existingSky then
		existingSky.Parent = nil
	end

	local bloodSky = Instance.new("Sky")
	bloodSky.Name = "MalevolentShrineSky"
	bloodSky.CelestialBodiesShown = false
	bloodSky.StarCount = 0
	bloodSky.Parent = Lighting
	jan:Add(bloodSky)

	local domainAtmos = existingAtmos
	if not domainAtmos then
		local createdAtmos = Instance.new("Atmosphere")
		createdAtmos.Name = "MalevolentShrineAtmosphere"
		createdAtmos.Parent = Lighting
		jan:Add(createdAtmos)
		domainAtmos = createdAtmos
	end

	Lighting.ClockTime = 0.2
	jan:Add(TweenService:Create(Lighting, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Ambient = Color3.fromRGB(48, 6, 12),
		OutdoorAmbient = Color3.fromRGB(64, 8, 16),
		ColorShift_Top = Color3.fromRGB(185, 16, 34),
		ColorShift_Bottom = Color3.fromRGB(28, 3, 8),
		Brightness = 0.55,
		ExposureCompensation = -0.25,
	})):Play()

	if domainAtmos then
		jan:Add(TweenService:Create(domainAtmos, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Density = 0.44,
			Offset = 0.18,
			Color = Color3.fromRGB(132, 10, 24),
			Decay = Color3.fromRGB(22, 2, 6),
			Glare = 0.32,
			Haze = 2.35,
		})):Play()
	end

	-- ColorCorrection sutil persistente de dominio amaldicoado
	local domainCC = Instance.new("ColorCorrectionEffect")
	domainCC.Name = "MalevolentShrineCC"
	domainCC.Contrast = 0.14
	domainCC.Saturation = 0.12
	domainCC.TintColor = Color3.fromRGB(255, 222, 226)
	domainCC.Parent = Lighting
	jan:Add(domainCC)

	-- 2. Piso escuro/avermelhado reflexivo OPACO (Transparency = 0 no G-buffer para NUNCA cortar particulas no horizonte!) + mare de nevoa
	local bloodMirrorFloor = archBlock(
		vfxRoot,
		"ShrineReflectiveFloor",
		Vector3.new(136, 0.08, 136),
		CFrame.new(arenaCenter.X, floorY - 0.12, arenaCenter.Z),
		Color3.fromRGB(16, 2, 5),
		Enum.Material.SmoothPlastic,
		0.26
	)
	bloodMirrorFloor.Transparency = 0
	jan:Add(bloodMirrorFloor)
	jan:Add(TweenService:Create(bloodMirrorFloor, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(arenaCenter.X, floorY + 0.04, arenaCenter.Z),
	})):Play()

	local floorMistEmitter = Instance.new("ParticleEmitter")
	floorMistEmitter.Name = "CrimsonFloorMist"
	floorMistEmitter.Texture = Config.ResolveAsset(Config.Assets.BloodMistTextureId, Config.Fallbacks.Smoke)
	floorMistEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Config.Colors.BloodDeep),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(42, 4, 10)),
		ColorSequenceKeypoint.new(1, Config.Colors.Obsidian),
	})
	floorMistEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.85),
		NumberSequenceKeypoint.new(0.35, 0.52),
		NumberSequenceKeypoint.new(0.8, 0.65),
		NumberSequenceKeypoint.new(1, 1),
	})
	floorMistEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 7.5),
		NumberSequenceKeypoint.new(0.5, 14.5),
		NumberSequenceKeypoint.new(1, 20.0),
	})
	floorMistEmitter.Lifetime = NumberRange.new(2.6, 4.2)
	floorMistEmitter.Rate = 28
	floorMistEmitter.Speed = NumberRange.new(1.5, 5.0)
	floorMistEmitter.SpreadAngle = Vector2.new(180, 6)
	floorMistEmitter.RotSpeed = NumberRange.new(-18, 18)
	floorMistEmitter.LightEmission = 0.08
	floorMistEmitter.Parent = bloodMirrorFloor
	floorMistEmitter:Emit(24)

	-- 3. Santuario Malevolente erguendo-se monumentalmente atras do Sukuna!
	local fwdVec = if tRoot
		then Vector3.new(tRoot.Position.X - aRoot.Position.X, 0, tRoot.Position.Z - aRoot.Position.Z)
		else aRoot.CFrame.LookVector
	local fwd = if fwdVec.Magnitude > 0.05 then fwdVec.Unit else Vector3.new(0, 0, -1)
	local shrineGroundPos = Vector3.new(aRoot.Position.X, floorY, aRoot.Position.Z) - fwd * 17.5
	local finalShrineCF = CFrame.lookAt(shrineGroundPos, shrineGroundPos + fwd)
	local buriedShrineCF = finalShrineCF * CFrame.new(0, -25.0, 0)

	local shrineModel, partsRel = buildShrineModel(buriedShrineCF)
	shrineModel.Parent = vfxRoot
	activeShrineModel = shrineModel
	jan:Add(shrineModel)

	-- Nuvem de fumaca negra e faiscas na base onde o templo emerge
	local riseBurstAnchor = makeAnchor(vfxRoot, CFrame.new(shrineGroundPos + Vector3.new(0, 0.8, 0)))
	jan:Add(riseBurstAnchor)
	local riseSmoke = floorMistEmitter:Clone()
	riseSmoke.Rate = 0
	riseSmoke.Speed = NumberRange.new(10, 26)
	riseSmoke.SpreadAngle = Vector2.new(180, 25)
	riseSmoke.Parent = riseBurstAnchor
	riseSmoke:Emit(38)

	-- Elevacao suave a 60 FPS do Santuario com leve tremor sismico
	local riseDuration = 1.05
	local t0 = os.clock()
	local nextAmbientSlashAt = 0.35

	jan:Connect(RunService.Heartbeat, function()
		if not shrineModel.Parent then
			return
		end
		local elapsed = os.clock() - t0
		if elapsed <= riseDuration then
			local a = math.clamp(elapsed / riseDuration, 0, 1)
			local ease = 1 - (1 - a) ^ 3
			local jitterX = (1 - a) * (math.random() - 0.5) * 0.45
			local jitterZ = (1 - a) * (math.random() - 0.5) * 0.45
			local curOrigin = buriedShrineCF:Lerp(finalShrineCF, ease) + Vector3.new(jitterX, 0, jitterZ)
			for _, item in ipairs(partsRel) do
				if item.part.Parent then
					item.part.CFrame = curOrigin * item.relCF
				end
			end
		end

		-- Cortes continuos rasgando o ar ao redor da arena enquanto o Dominio permanece ativo!
		if elapsed >= nextAmbientSlashAt then
			nextAmbientSlashAt = elapsed + 0.16 + math.random() * 0.14
			local randOffset = Vector3.new(
				(math.random() - 0.5) * 44,
				2.0 + math.random() * 14,
				(math.random() - 0.5) * 44
			)
			MalevolentShrineEnv.SpawnAirSlash3D(
				vfxRoot,
				arenaCenter + randOffset,
				9.0 + math.random() * 8.0,
				0.48 + math.random() * 0.35,
				0.22,
				math.random() < 0.65
			)
		end
	end)
end

function MalevolentShrineEnv.IsActive(): boolean
	return domainJanitor ~= nil and not domainJanitor:IsCleaned()
end

function MalevolentShrineEnv.GetArenaCenter(): (Vector3, number)
	return activeDomainCenter, activeFloorY
end

function MalevolentShrineEnv.CloseDomain(immediate: boolean?)
	local jan = domainJanitor
	domainJanitor = nil
	local shrine = activeShrineModel
	activeShrineModel = nil
	if not jan then
		return
	end
	if immediate or not shrine or not shrine.Parent then
		jan:Cleanup()
		return
	end

	-- Dissipacao limpa de 0.45s: afunda entre fumaca (sem deixar piso gigante semi-transparente que recorte particulas) e restaura Lighting/Sky/Atmosphere
	for _, d in ipairs(shrine:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			d.Enabled = false
		elseif d:IsA("BasePart") then
			TweenService:Create(d, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = d.Position - Vector3.new(0, 26, 0),
			}):Play()
		end
	end
	task.delay(0.45, function()
		jan:Cleanup()
	end)
end

return MalevolentShrineEnv
