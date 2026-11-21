--!strict
--[[
	SummonBannerStage (cliente): Palco 3D ao vivo estilo Anime Vanguards para o Banner de Invocacao.
	  - Constroi e alterna cenarios 3D tematicos por anime (Todos Comum/Premium, Naruto, OnePiece, etc.)
	    em espaco isolado (STAGE_ORIGIN = 0, 620, -600), sem interferir no mapa principal.
	  - Exibe os 3 personagens principais em poses heroicas dinamicas (1 Lendario elevado no centro +
	    2 Epicos/Destaques nas laterais) com respiracao suave a 60 FPS e pes firmes nos pedestais.
	  - Contem automaticamente VFX proprios dos personagens (ex.: San.AuraVfx, BarbaBranca.YonkoPresence)
	    para que brilhem lindamente dentro do proprio pedestal sem atrapalhar a visao dos outros dois.
	  - Fornece projecao WorldToViewportPoint para as placas de nome flutuantes na UI.
	Totalmente protegido por pcall para nunca impactar o gameplay.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Themes = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("SummonStageThemes"))

local Stage = {}

local ORIGIN = Themes.STAGE_ORIGIN
local ASSETS = Themes.Assets

-- Pre-carrega texturas do palco em segundo plano para abrir sem atraso
task.spawn(function()
	pcall(function()
		local decals = {}
		for _, id in pairs(ASSETS) do
			local d = Instance.new("Decal")
			d.Texture = id
			table.insert(decals, d)
		end
		ContentProvider:PreloadAsync(decals)
	end)
end)

-- Estado interno do palco
local rootFolder: Folder? = nil
local themeFolder: Folder? = nil
local unitsFolder: Folder? = nil
local animConn: RBXScriptConnection? = nil
local isOpen = false
local elapsed = 0
local currentBannerId = "Todos"
local currentPortalId = "Comum"
local currentWeeklyId: string? = nil
local currentFeatured: { { Id: string, Def: any, SlotRole: string } } = {}

-- Referencias animaveis da cena atual
type AnimSpinner = {
	part: BasePart,
	weld: Weld?,
	baseCF: CFrame,
	speed: number,
	axis: string, -- "Y" | "Z"
	bobAmp: number,
	phase: number,
}

type RigState = {
	model: Model,
	slotIndex: number,
	isIPose: boolean,
	isSkinned: boolean,
	motors: { [string]: { motor: Motor6D, baseC0: CFrame } },
	bones: { [string]: { bone: Bone, baseCF: CFrame } },
	pose: any,
	seed: number,
	basePivot: CFrame,
	enterTime: number,
	auraSpinners: { AnimSpinner },
	auraLight: PointLight?,
	auraLightBase: number,
}

local sceneSpinners: { AnimSpinner } = {}
local floaters: { { part: BasePart, baseCF: CFrame, amp: number, freq: number, phase: number } } = {}
local activeRigs: { RigState } = {}
local slotAnchorWorld: { [number]: Vector3 } = {}
local burstEmitter: ParticleEmitter? = nil

-- Backup da camera do jogador
local savedLighting: {
	Brightness: number,
	Exposure: number,
	Bloom: { Enabled: boolean, Intensity: number, Size: number, Threshold: number }?,
}? = nil

local function applyStageLighting(on: boolean)
	pcall(function()
		local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
		if on then
			if not savedLighting then
				savedLighting = {
					Brightness = Lighting.Brightness,
					Exposure = Lighting.ExposureCompensation,
					Bloom = if bloom
						then { Enabled = bloom.Enabled, Intensity = bloom.Intensity, Size = bloom.Size, Threshold = bloom.Threshold }
						else nil,
				}
			end
			Lighting.Brightness = math.min(savedLighting.Brightness, 1.28)
			Lighting.ExposureCompensation = math.min(savedLighting.Exposure, -0.38)
			if bloom then
				bloom.Intensity = math.min(bloom.Intensity, 0.24)
				bloom.Size = math.min(bloom.Size, 20)
				bloom.Threshold = math.max(bloom.Threshold, 1.85)
			end
		elseif savedLighting then
			Lighting.Brightness = savedLighting.Brightness
			Lighting.ExposureCompensation = savedLighting.Exposure
			if bloom and savedLighting.Bloom then
				bloom.Enabled = savedLighting.Bloom.Enabled
				bloom.Intensity = savedLighting.Bloom.Intensity
				bloom.Size = savedLighting.Bloom.Size
				bloom.Threshold = savedLighting.Bloom.Threshold
			end
			savedLighting = nil
		end
	end)
end

local savedCam: {
	Type: Enum.CameraType,
	CFrame: CFrame,
	Focus: CFrame,
	FieldOfView: number,
}? = nil

-- Auxiliares de geometria limpa
local function makePart(props: {
	Name: string,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3?,
	Material: Enum.Material?,
	Transparency: number?,
	Shape: Enum.PartType?,
	Parent: Instance,
}): Part
	local p = Instance.new("Part")
	p.Name = props.Name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = props.Size
	p.CFrame = props.CFrame
	if props.Shape then
		p.Shape = props.Shape
	end
	if props.Color then
		p.Color = props.Color
	end
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Transparency = props.Transparency or 0
	p.Parent = props.Parent
	return p
end

local function makeCyl(name: string, center: Vector3, height: number, diameter: number, color: Color3, mat: Enum.Material, parent: Instance, transp: number?): Part
	-- Cilindro Roblox tem eixo de altura ao longo do X local -> rotacao +90 em Z deixa em pe no Y
	return makePart({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = mat,
		Transparency = transp or 0,
		Parent = parent,
	})
end

local function makeSurfaceImage(parent: BasePart, face: Enum.NormalId, texture: string, color: Color3, brightness: number, transp: number?): ImageLabel
	local sg = Instance.new("SurfaceGui")
	sg.Name = "FxGui_" .. face.Name
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize = Vector2.new(512, 512)
	sg.LightInfluence = 0
	sg.Brightness = brightness
	sg.AlwaysOnTop = false
	sg.ClipsDescendants = true
	sg.Parent = parent

	local img = Instance.new("ImageLabel")
	img.Name = "Img"
	img.Size = UDim2.fromScale(1, 1)
	img.BackgroundTransparency = 1
	img.Image = texture
	img.ImageColor3 = color
	img.ImageTransparency = transp or 0
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = sg
	return img
end

local function makePillarBeam(parent: Instance, basePos: Vector3, height: number, width: number, color: Color3, opacity: number, speed: number)
	local holder = makePart({
		Name = "PillarHolder",
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(basePos),
		Transparency = 1,
		Parent = parent,
	})
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0, 0)
	a0.Parent = holder
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, height, 0)
	a1.Parent = holder

	local b = Instance.new("Beam")
	b.Name = "RarityPillar"
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Texture = ASSETS.PillarGlow
	b.TextureMode = Enum.TextureMode.Stretch
	b.TextureLength = 1
	b.TextureSpeed = speed * 0.45
	b.Width0 = width
	b.Width1 = width * 1.24
	b.FaceCamera = true
	b.LightEmission = 1
	b.LightInfluence = 0
	b.Brightness = 1.05
	b.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(0.45, color:Lerp(Color3.new(1, 1, 1), 0.24)),
		ColorSequenceKeypoint.new(1, color),
	})
	b.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.94),
		NumberSequenceKeypoint.new(0.14, opacity),
		NumberSequenceKeypoint.new(0.58, math.min(1, opacity + 0.20)),
		NumberSequenceKeypoint.new(1, 1),
	})
	b.Parent = holder
end

-- ============================================================================
-- CICLORAMA DE CEU GRADIENTE (garante fundo dramatico em qualquer horario do jogo)
-- ============================================================================
local function buildSkyCyclorama(parent: Instance, theme: Themes.StageTheme)
	local skyFolder = Instance.new("Folder")
	skyFolder.Name = "SkyCyclorama"
	skyFolder.Parent = parent

	local numPanels = 7
	local radius = 33
	local panelW = 16.6
	local panelH = 34
	local centerPos = ORIGIN + Vector3.new(0, 9.0, 8)

	for i = 1, numPanels do
		local frac = (i - (numPanels + 1) / 2) / ((numPanels - 1) / 2)
		local ang = frac * math.rad(74)
		local px = math.sin(ang) * radius
		local pz = -math.cos(ang) * radius
		local pos = centerPos + Vector3.new(px, 0, pz)
		local cf = CFrame.lookAt(pos, Vector3.new(centerPos.X, pos.Y, centerPos.Z))

		local panel = makePart({
			Name = "SkyPanel_" .. i,
			Size = Vector3.new(panelW, panelH, 0.4),
			CFrame = cf,
			Color = theme.SkyMid,
			Material = Enum.Material.SmoothPlastic,
			Parent = skyFolder,
		})

		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		sg.CanvasSize = Vector2.new(512, 512)
		sg.LightInfluence = 0
		sg.Brightness = 1.05
		sg.Parent = panel

		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BorderSizePixel = 0
		bg.BackgroundColor3 = Color3.new(1, 1, 1)
		bg.Parent = sg

		local grad = Instance.new("UIGradient")
		grad.Rotation = 90
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, theme.SkyTop),
			ColorSequenceKeypoint.new(0.32, theme.SkyMid),
			ColorSequenceKeypoint.new(0.60, theme.SkyHorizon),
			ColorSequenceKeypoint.new(0.80, theme.SkyMid:Lerp(theme.FloorColor, 0.35)),
			ColorSequenceKeypoint.new(1.0, theme.SkyTop),
		})
		grad.Parent = bg
	end

	-- Brilho atmosferico unico e continuo no horizonte (sem nenhuma emenda entre paineis!)
	local horizonGlow = makePart({
		Name = "HorizonAtmosphereGlow",
		Size = Vector3.new(44, 24, 0.1),
		CFrame = CFrame.new(ORIGIN + Vector3.new(0, 8.2, -19.5)),
		Transparency = 1,
		Parent = skyFolder,
	})
	makeSurfaceImage(horizonGlow, Enum.NormalId.Back, ASSETS.GlowFalloff, theme.Primary:Lerp(theme.SkyHorizon, 0.45), 1.02, 0.48)

	makePart({
		Name = "SkyCapTop",
		Size = Vector3.new(96, 1, 70),
		CFrame = CFrame.new(ORIGIN + Vector3.new(0, 27, -8)),
		Color = theme.SkyTop,
		Material = Enum.Material.SmoothPlastic,
		Parent = skyFolder,
	})
	makePart({
		Name = "AbyssFloor",
		Size = Vector3.new(96, 1, 74),
		CFrame = CFrame.new(ORIGIN + Vector3.new(0, -3.5, -8)),
		Color = theme.SkyTop:Lerp(Color3.new(0, 0, 0), 0.35),
		Material = Enum.Material.SmoothPlastic,
		Parent = skyFolder,
	})
end

-- ============================================================================
-- ARQUITETURA TEMATICA POR ANIME
-- ============================================================================
local function buildCelestialSetpiece(parent: Instance, theme: Themes.StageTheme)
	local f = Instance.new("Folder")
	f.Name = "Arch_Celestial"
	f.Parent = parent

	-- Arco Celestial monumental atras do palco
	for _, side in ipairs({ -1, 1 }) do
		local px = side * 11.4
		local pz = -7.2
		-- Base da coluna
		makePart({
			Name = "ColBase_" .. side,
			Size = Vector3.new(3.0, 1.4, 3.0),
			CFrame = CFrame.new(ORIGIN + Vector3.new(px, 0.7, pz)),
			Color = theme.StoneColor,
			Material = Enum.Material.Marble,
			Parent = f,
		})
		makePart({
			Name = "ColTrimLow_" .. side,
			Size = Vector3.new(3.2, 0.25, 3.2),
			CFrame = CFrame.new(ORIGIN + Vector3.new(px, 1.45, pz)),
			Color = theme.TrimColor,
			Material = Enum.Material.Neon,
			Parent = f,
		})
		-- Fuste da coluna
		makePart({
			Name = "ColShaft_" .. side,
			Size = Vector3.new(2.0, 12.6, 2.0),
			CFrame = CFrame.new(ORIGIN + Vector3.new(px, 7.8, pz)),
			Color = theme.StoneColor,
			Material = Enum.Material.Marble,
			Parent = f,
		})
		-- Faixa luminosa vertical na face frontal da coluna
		makePart({
			Name = "ColRuneStrip_" .. side,
			Size = Vector3.new(0.28, 11.2, 0.2),
			CFrame = CFrame.new(ORIGIN + Vector3.new(px, 7.8, pz + 1.02)),
			Color = theme.Primary,
			Material = Enum.Material.Neon,
			Parent = f,
		})
		-- Capitel dourado
		makePart({
			Name = "ColCap_" .. side,
			Size = Vector3.new(3.0, 1.0, 3.0),
			CFrame = CFrame.new(ORIGIN + Vector3.new(px, 14.4, pz)),
			Color = theme.TrimColor,
			Material = Enum.Material.Metal,
			Parent = f,
		})
	end

	-- Arco segmentado elegante unindo as colunas sobre o Lendario
	local archSegments = 11
	local archR = 11.4
	local archCenter = ORIGIN + Vector3.new(0, 14.0, -7.2)
	for i = 1, archSegments do
		local u = (i - 0.5) / archSegments
		local ang = math.pi * (0.08 + 0.84 * u)
		local p = archCenter + Vector3.new(math.cos(ang) * archR, math.sin(ang) * 5.2, 0)
		local tangent = Vector3.new(-math.sin(ang) * archR, math.cos(ang) * 5.2, 0)
		local rotZ = math.atan2(tangent.Y, tangent.X)
		makePart({
			Name = "ArchSeg_" .. i,
			Size = Vector3.new(2.6, 0.85, 1.6),
			CFrame = CFrame.new(p) * CFrame.Angles(0, 0, rotZ),
			Color = theme.StoneColor,
			Material = Enum.Material.Marble,
			Parent = f,
		})
		makePart({
			Name = "ArchNeon_" .. i,
			Size = Vector3.new(2.3, 0.2, 1.75),
			CFrame = CFrame.new(p + Vector3.new(0, -0.32, 0)) * CFrame.Angles(0, 0, rotZ),
			Color = if i % 2 == 0 then theme.Primary else theme.TrimColor,
			Material = Enum.Material.Neon,
			Parent = f,
		})
	end

	-- Cristal estrela flutuante no apice do arco
	local keystone = makePart({
		Name = "ArchKeystone",
		Size = Vector3.new(1.8, 1.8, 1.8),
		CFrame = CFrame.new(ORIGIN + Vector3.new(0, 18.2, -6.5)) * CFrame.Angles(math.rad(45), math.rad(45), 0),
		Color = theme.Primary,
		Material = Enum.Material.Neon,
		Parent = f,
	})
	table.insert(floaters, { part = keystone, baseCF = keystone.CFrame, amp = 0.35, freq = 1.6, phase = 0 })

	-- 4 Obeliscos cristalinos esculpidos levitando nas laterais (pedra escura + nucleo luminoso + anel dourado)
	local obelisks = {
		{ x = -14.8, y = 6.0, z = -4.2, h = 5.4, tilt = 10, col = theme.Primary, ph = 0.4 },
		{ x = 14.8, y = 6.0, z = -4.2, h = 5.4, tilt = -10, col = theme.Primary, ph = 2.1 },
		{ x = -17.4, y = 9.0, z = -10.2, h = 4.4, tilt = 15, col = theme.Secondary, ph = 1.2 },
		{ x = 17.4, y = 9.0, z = -10.2, h = 4.4, tilt = -15, col = theme.Secondary, ph = 3.7 },
	}
	for idx, ob in ipairs(obelisks) do
		local baseCF = CFrame.new(ORIGIN + Vector3.new(ob.x, ob.y, ob.z)) * CFrame.Angles(math.rad(4), math.rad(ob.tilt * 1.4), math.rad(ob.tilt))
		local body = makePart({
			Name = "ObeliskStone_" .. idx,
			Size = Vector3.new(1.25, ob.h, 1.25),
			CFrame = baseCF,
			Color = theme.StoneColor,
			Material = Enum.Material.Marble,
			Parent = f,
		})
		table.insert(floaters, { part = body, baseCF = baseCF, amp = 0.45, freq = 1.25, phase = ob.ph })

		local coreCF = baseCF * CFrame.new(0, 0, 0.56)
		local coreStrip = makePart({
			Name = "ObeliskCore_" .. idx,
			Size = Vector3.new(0.28, ob.h * 0.78, 0.22),
			CFrame = coreCF,
			Color = ob.col,
			Material = Enum.Material.Neon,
			Parent = f,
		})
		table.insert(floaters, { part = coreStrip, baseCF = coreCF, amp = 0.45, freq = 1.25, phase = ob.ph })

		local capCF = baseCF * CFrame.new(0, ob.h * 0.5 + 0.55, 0) * CFrame.Angles(math.rad(45), math.rad(45), 0)
		local cap = makePart({
			Name = "ObeliskTip_" .. idx,
			Size = Vector3.new(0.88, 0.88, 0.88),
			CFrame = capCF,
			Color = ob.col,
			Material = Enum.Material.Neon,
			Transparency = 0.1,
			Parent = f,
		})
		table.insert(floaters, { part = cap, baseCF = capCF, amp = 0.45, freq = 1.25, phase = ob.ph })

		local collarCF = baseCF * CFrame.new(0, -ob.h * 0.34, 0)
		local collar = makePart({
			Name = "ObeliskCollar_" .. idx,
			Size = Vector3.new(1.52, 0.22, 1.52),
			CFrame = collarCF,
			Color = theme.TrimColor,
			Material = Enum.Material.Metal,
			Parent = f,
		})
		table.insert(floaters, { part = collar, baseCF = collarCF, amp = 0.45, freq = 1.25, phase = ob.ph })
	end
end

local function buildNarutoSetpiece(parent: Instance, theme: Themes.StageTheme)
	local f = Instance.new("Folder")
	f.Name = "Arch_Naruto"
	f.Parent = parent

	local vermilion = Color3.fromRGB(206, 44, 34)
	local darkWood = Color3.fromRGB(32, 24, 24)
	local goldTrim = Color3.fromRGB(242, 192, 64)
	local cliffRock = Color3.fromRGB(76, 54, 48)
	local cliffLight = Color3.fromRGB(116, 76, 58)

	-- 1. GRANDE PORTAL TORII VERMELHO DE KONOHA atras do centro
	local toriiZ = -7.2
	for _, side in ipairs({ -1, 1 }) do
		local px = side * 9.8
		-- Pedestal de pedra (Kamebara)
		makeCyl("ToriiStone_" .. side, ORIGIN + Vector3.new(px, 0.9, toriiZ), 1.8, 2.3, darkWood, Enum.Material.Slate, f)
		-- Pilar vermelho (Hashira) levemente inclinado para dentro
		local pillar = makePart({
			Name = "ToriiPillar_" .. side,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(14.8, 1.55, 1.55),
			CFrame = CFrame.new(ORIGIN + Vector3.new(px * 0.96, 8.2, toriiZ)) * CFrame.Angles(0, 0, math.rad(90 + side * 3.2)),
			Color = vermilion,
			Material = Enum.Material.Wood,
			Parent = f,
		})
		local _ = pillar
		-- Anel dourado decorativo no topo do pilar
		makeCyl("ToriiCollar_" .. side, ORIGIN + Vector3.new(px * 0.92, 13.6, toriiZ), 0.35, 1.75, goldTrim, Enum.Material.Metal, f)
	end

	-- Viga inferior (Nuki) atravessando os pilares
	makePart({
		Name = "ToriiNuki",
		Size = Vector3.new(25.0, 1.05, 1.15),
		CFrame = CFrame.new(ORIGIN + Vector3.new(0, 12.6, toriiZ)),
		Color = vermilion,
		Material = Enum.Material.Wood,
		Parent = f,
	})
	-- Cunhas pretas nas extremidades da Nuki
	for _, side in ipairs({ -1, 1 }) do
		makePart({
			Name = "ToriiWedge_" .. side,
			Size = Vector3.new(1.1, 1.25, 1.3),
			CFrame = CFrame.new(ORIGIN + Vector3.new(side * 12.3, 12.6, toriiZ)),
			Color = darkWood,
			Material = Enum.Material.Wood,
			Parent = f,
		})
	end
	-- Viga superior vermelha (Shimaki) + cobertura escura (Kasagi) com pontas curvadas para cima!
	makePart({
		Name = "ToriiShimaki",
		Size = Vector3.new(27.2, 1.0, 1.65),
		CFrame = CFrame.new(ORIGIN + Vector3.new(0, 15.2, toriiZ)),
		Color = vermilion,
		Material = Enum.Material.Wood,
		Parent = f,
	})
	makePart({
		Name = "ToriiKasagiMid",
		Size = Vector3.new(22.0, 0.85, 2.35),
		CFrame = CFrame.new(ORIGIN + Vector3.new(0, 16.05, toriiZ)),
		Color = darkWood,
		Material = Enum.Material.Slate,
		Parent = f,
	})
	for _, side in ipairs({ -1, 1 }) do
		makePart({
			Name = "ToriiWing_" .. side,
			Size = Vector3.new(5.2, 0.85, 2.35),
			CFrame = CFrame.new(ORIGIN + Vector3.new(side * 12.9, 16.55, toriiZ)) * CFrame.Angles(0, 0, math.rad(side * 13)),
			Color = darkWood,
			Material = Enum.Material.Slate,
			Parent = f,
		})
		makePart({
			Name = "ToriiWingGold_" .. side,
			Size = Vector3.new(0.45, 0.92, 2.42),
			CFrame = CFrame.new(ORIGIN + Vector3.new(side * 15.4, 17.15, toriiZ)) * CFrame.Angles(0, 0, math.rad(side * 13)),
			Color = goldTrim,
			Material = Enum.Material.Neon,
			Parent = f,
		})
	end
	-- Placa central (Gakuzuka) com emblema espiral brilhante de Konoha
	local plaque = makePart({
		Name = "ToriiPlaque",
		Size = Vector3.new(2.2, 2.7, 0.45),
		CFrame = CFrame.new(ORIGIN + Vector3.new(0, 13.95, toriiZ + 0.65)),
		Color = darkWood,
		Material = Enum.Material.SmoothPlastic,
		Parent = f,
	})
	makePart({
		Name = "ToriiPlaqueFrame",
		Size = Vector3.new(2.45, 2.95, 0.35),
		CFrame = CFrame.new(ORIGIN + Vector3.new(0, 13.95, toriiZ + 0.52)),
		Color = goldTrim,
		Material = Enum.Material.Metal,
		Parent = f,
	})
	makeSurfaceImage(plaque, Enum.NormalId.Back, ASSETS.NarutoSeal, Color3.fromRGB(255, 174, 62), 2.0, 0.05)

	-- 2. LANTERNAS DE PEDRA TORO ladeando o palco
	for _, side in ipairs({ -1, 1 }) do
		local lx = side * 11.4
		local lz = -1.0
		makePart({ Name = "ToroBase_" .. side, Size = Vector3.new(2.2, 0.7, 2.2), CFrame = CFrame.new(ORIGIN + Vector3.new(lx, 0.35, lz)), Color = cliffRock, Material = Enum.Material.Cobblestone, Parent = f })
		makeCyl("ToroPost_" .. side, ORIGIN + Vector3.new(lx, 2.4, lz), 3.4, 0.95, cliffRock, Enum.Material.Slate, f)
		makePart({ Name = "ToroTray_" .. side, Size = Vector3.new(2.1, 0.45, 2.1), CFrame = CFrame.new(ORIGIN + Vector3.new(lx, 4.3, lz)), Color = cliffRock, Material = Enum.Material.Slate, Parent = f })
		local core = makePart({
			Name = "ToroFlame_" .. side,
			Size = Vector3.new(1.25, 1.5, 1.25),
			CFrame = CFrame.new(ORIGIN + Vector3.new(lx, 5.25, lz)),
			Color = Color3.fromRGB(255, 166, 56),
			Material = Enum.Material.Neon,
			Parent = f,
		})
		local pl = Instance.new("PointLight")
		pl.Color = Color3.fromRGB(255, 152, 54)
		pl.Brightness = 0.75
		pl.Range = 14
		pl.Parent = core
		makePart({ Name = "ToroRoof1_" .. side, Size = Vector3.new(2.7, 0.5, 2.7), CFrame = CFrame.new(ORIGIN + Vector3.new(lx, 6.2, lz)), Color = darkWood, Material = Enum.Material.Slate, Parent = f })
		makePart({ Name = "ToroRoof2_" .. side, Size = Vector3.new(1.5, 0.55, 1.5), CFrame = CFrame.new(ORIGIN + Vector3.new(lx, 6.7, lz)), Color = darkWood, Material = Enum.Material.Slate, Parent = f })
	end

	-- 3. SILHUETAS DE PENHASCOS DE KONOHA + COPAS DE FOLHAS OUTONAIS NAS BORDAS
	local cliffs = {
		{ x = -18.5, y = 5.5, z = -14.5, sx = 12, sy = 14, sz = 6, col = cliffRock },
		{ x = 18.5, y = 6.0, z = -14.5, sx = 12, sy = 15, sz = 6, col = cliffRock },
		{ x = -9.5, y = 3.2, z = -16.5, sx = 11, sy = 10, sz = 5, col = cliffLight },
		{ x = 9.5, y = 3.5, z = -16.5, sx = 11, sy = 11, sz = 5, col = cliffLight },
	}
	for i, c in ipairs(cliffs) do
		makePart({
			Name = "KonohaCliff_" .. i,
			Size = Vector3.new(c.sx, c.sy, c.sz),
			CFrame = CFrame.new(ORIGIN + Vector3.new(c.x, c.y, c.z)) * CFrame.Angles(0, math.rad(if c.x < 0 then 14 else -14), 0),
			Color = c.col,
			Material = Enum.Material.Rock,
			Parent = f,
		})
	end

	-- Lanternas japonesas Chochin vermelhas e douradas penduradas na viga do Torii (muito mais autenticas!)
	for _, side in ipairs({ -1, 1 }) do
		local hx = side * 6.4
		-- Corda de suspensao presa na Nuki (Y=12.6)
		makeCyl("ChochinCord_" .. side, ORIGIN + Vector3.new(hx, 11.45, toriiZ + 0.35), 1.4, 0.14, darkWood, Enum.Material.Wood, f)
		-- Tampa superior preta e anel dourado
		makeCyl("ChochinCapTop_" .. side, ORIGIN + Vector3.new(hx, 10.65, toriiZ + 0.35), 0.25, 1.35, darkWood, Enum.Material.Metal, f)
		makeCyl("ChochinGoldTop_" .. side, ORIGIN + Vector3.new(hx, 10.50, toriiZ + 0.35), 0.12, 1.42, goldTrim, Enum.Material.Neon, f)
		-- Corpo brilhante da lanterna de papel (vermelho-laranja quente)
		local body = makePart({
			Name = "ChochinBody_" .. side,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.85, 2.25, 1.85),
			CFrame = CFrame.new(ORIGIN + Vector3.new(hx, 9.45, toriiZ + 0.35)),
			Color = Color3.fromRGB(255, 108, 42),
			Material = Enum.Material.Neon,
			Parent = f,
		})
		local pl = Instance.new("PointLight")
		pl.Color = Color3.fromRGB(255, 134, 48)
		pl.Brightness = 0.70
		pl.Range = 14
		pl.Parent = body
		-- Faixas horizontais da lanterna
		makeCyl("ChochinBand_" .. side, ORIGIN + Vector3.new(hx, 9.45, toriiZ + 0.35), 0.16, 1.92, darkWood, Enum.Material.SmoothPlastic, f)
		-- Base inferior + borla dourada
		makeCyl("ChochinCapBot_" .. side, ORIGIN + Vector3.new(hx, 8.35, toriiZ + 0.35), 0.25, 1.25, darkWood, Enum.Material.Metal, f)
		makeCyl("ChochinTassel_" .. side, ORIGIN + Vector3.new(hx, 7.65, toriiZ + 0.35), 1.15, 0.22, goldTrim, Enum.Material.Neon, f)
	end
end

local function buildOnePieceSetpiece(parent: Instance, theme: Themes.StageTheme)
	local f = Instance.new("Folder")
	f.Name = "Arch_OnePiece"
	f.Parent = parent

	local oakDark = Color3.fromRGB(64, 40, 24)
	local oakWarm = Color3.fromRGB(98, 64, 38)
	local brassGold = Color3.fromRGB(246, 194, 62)
	local sailCream = Color3.fromRGB(204, 188, 160)
	local oceanDeep = Color3.fromRGB(14, 96, 152)
	local oceanFoam = Color3.fromRGB(168, 240, 255)

	-- 1. GUARDA-CORPO DE MADEIRA E BRONZE DO CONVES DO NAVIO PIRATA
	for _, side in ipairs({ -1, 1 }) do
		local rx = side * 12.6
		-- Corrimao superior
		makePart({
			Name = "DeckRailTop_" .. side,
			Size = Vector3.new(0.85, 0.55, 16.5),
			CFrame = CFrame.new(ORIGIN + Vector3.new(rx, 2.6, -0.8)),
			Color = oakWarm,
			Material = Enum.Material.Wood,
			Parent = f,
		})
		makePart({
			Name = "DeckRailGold_" .. side,
			Size = Vector3.new(0.95, 0.16, 16.6),
			CFrame = CFrame.new(ORIGIN + Vector3.new(rx, 2.9, -0.8)),
			Color = brassGold,
			Material = Enum.Material.Metal,
			Parent = f,
		})
		-- Balaustres verticais
		for bz = -8, 6, 3.5 do
			makePart({
				Name = "RailPost_" .. side .. "_" .. bz,
				Size = Vector3.new(0.65, 2.6, 0.65),
				CFrame = CFrame.new(ORIGIN + Vector3.new(rx, 1.3, bz)),
				Color = oakDark,
				Material = Enum.Material.Wood,
				Parent = f,
			})
		end
	end
	-- Guarda-corpo traseiro na popa
	makePart({
		Name = "SternRail",
		Size = Vector3.new(25.8, 0.65, 0.9),
		CFrame = CFrame.new(ORIGIN + Vector3.new(0, 2.8, -8.8)),
		Color = oakWarm,
		Material = Enum.Material.Wood,
		Parent = f,
	})
	makePart({
		Name = "SternRailTrim",
		Size = Vector3.new(26.0, 0.2, 1.0),
		CFrame = CFrame.new(ORIGIN + Vector3.new(0, 3.18, -8.8)),
		Color = brassGold,
		Material = Enum.Material.Metal,
		Parent = f,
	})

	-- 2. GRANDE LEME PIRATA atras do Lendario central
	local helmCenter = ORIGIN + Vector3.new(0, 6.2, -5.6)
	local helmHub = makePart({
		Name = "PirateHelmHub",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.85, 1.6, 1.6),
		CFrame = CFrame.new(helmCenter) * CFrame.Angles(0, math.rad(90), 0),
		Color = brassGold,
		Material = Enum.Material.Metal,
		Parent = f,
	})
	-- 8 raios do leme com cabos dourados
	for i = 0, 7 do
		local a = i * math.pi / 4
		local spoke = makePart({
			Name = "HelmSpoke_" .. i,
			Size = Vector3.new(0.32, 7.6, 0.32),
			CFrame = CFrame.new(helmCenter) * CFrame.Angles(0, 0, a),
			Color = oakWarm,
			Material = Enum.Material.Wood,
			Parent = f,
		})
		local _ = spoke
		local tipPos = helmCenter + Vector3.new(-math.sin(a) * 3.9, math.cos(a) * 3.9, 0)
		makePart({
			Name = "HelmKnob_" .. i,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.55, 0.55, 0.55),
			CFrame = CFrame.new(tipPos),
			Color = brassGold,
			Material = Enum.Material.Metal,
			Parent = f,
		})
	end
	-- Aro do leme em 12 segmentos octogonais/circulares
	for i = 1, 12 do
		local a = (i - 0.5) * (2 * math.pi / 12)
		local r = 2.85
		local pos = helmCenter + Vector3.new(math.cos(a) * r, math.sin(a) * r, 0)
		makePart({
			Name = "HelmRim_" .. i,
			Size = Vector3.new(1.58, 0.48, 0.5),
			CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, a + math.pi / 2),
			Color = oakDark,
			Material = Enum.Material.Wood,
			Parent = f,
		})
	end
	local _ = helmHub

	-- 3. MASTRO PRINCIPAL, VERGA E VELA ENFUNADA DA GRAND LINE
	local mastZ = -10.8
	makeCyl("MainMast", ORIGIN + Vector3.new(0, 12.0, mastZ), 24.0, 1.85, oakDark, Enum.Material.Wood, f)
	-- Cesto da gavea (Crow's Nest)
	makeCyl("CrowsNest", ORIGIN + Vector3.new(0, 17.8, mastZ), 1.8, 3.6, oakWarm, Enum.Material.Wood, f)
	makeCyl("CrowsNestTrim", ORIGIN + Vector3.new(0, 18.7, mastZ), 0.25, 3.8, brassGold, Enum.Material.Metal, f)
	-- Verga horizontal (Yardarm)
	makePart({
		Name = "Yardarm",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(25.0, 0.9, 0.9),
		CFrame = CFrame.new(ORIGIN + Vector3.new(0, 15.6, mastZ + 0.8)),
		Color = oakWarm,
		Material = Enum.Material.Wood,
		Parent = f,
	})
	-- Vela branca/creme com leve curvatura (3 faixas elegantes para dar volume enfunado)
	local sailCols = { -6.5, 0, 6.5 }
	for idx, sx in ipairs(sailCols) do
		local bulge = if idx == 2 then 1.35 else 0.75
		local yaw = if idx == 1 then -10 elseif idx == 3 then 10 else 0
		makePart({
			Name = "PirateSail_" .. idx,
			Size = Vector3.new(7.0, 9.6, 0.25),
			CFrame = CFrame.new(ORIGIN + Vector3.new(sx, 10.6, mastZ + 1.0 + bulge)) * CFrame.Angles(math.rad(-7), math.rad(yaw), 0),
			Color = sailCream,
			Material = Enum.Material.Fabric,
			Transparency = 0.08,
			Parent = f,
		})
	end
	-- Faixa azul-marinho e dourada estilizada na vela central
	makePart({
		Name = "SailStripe",
		Size = Vector3.new(19.5, 0.65, 0.3),
		CFrame = CFrame.new(ORIGIN + Vector3.new(0, 14.8, mastZ + 1.7)),
		Color = Color3.fromRGB(28, 136, 214),
		Material = Enum.Material.Fabric,
		Parent = f,
	})
	-- Flâmulas piratas vermelhas nas pontas da verga
	for _, side in ipairs({ -1, 1 }) do
		local flag = makePart({
			Name = "PiratePennant_" .. side,
			Size = Vector3.new(3.2, 0.9, 0.14),
			CFrame = CFrame.new(ORIGIN + Vector3.new(side * 13.4, 15.2, mastZ + 0.8)) * CFrame.Angles(0, math.rad(side * -14), math.rad(side * -10)),
			Color = Color3.fromRGB(218, 44, 48),
			Material = Enum.Material.Fabric,
			Parent = f,
		})
		table.insert(floaters, { part = flag, baseCF = flag.CFrame, amp = 0.22, freq = 2.6, phase = side })
	end

	-- 4. MAR TURQUESA E ONDAS ESTILIZADAS DA GRAND LINE ao redor do conves
	makePart({
		Name = "GrandLineSea",
		Size = Vector3.new(90, 0.8, 65),
		CFrame = CFrame.new(ORIGIN + Vector3.new(0, -1.6, -6)),
		Color = oceanDeep,
		Material = Enum.Material.SmoothPlastic,
		Parent = f,
	})
	local waves = {
		{ x = -16.5, y = -0.3, z = 2.2, sx = 10, sy = 2.4, sz = 3.2, rot = 18, ph = 0.2 },
		{ x = 16.5, y = -0.3, z = 2.2, sx = 10, sy = 2.4, sz = 3.2, rot = -18, ph = 1.6 },
		{ x = -18.0, y = 0.4, z = -6.5, sx = 12, sy = 3.2, sz = 3.8, rot = 24, ph = 0.9 },
		{ x = 18.0, y = 0.4, z = -6.5, sx = 12, sy = 3.2, sz = 3.8, rot = -24, ph = 2.4 },
	}
	for i, wv in ipairs(waves) do
		local wPart = makePart({
			Name = "OceanWave_" .. i,
			Size = Vector3.new(wv.sx, wv.sy, wv.sz),
			CFrame = CFrame.new(ORIGIN + Vector3.new(wv.x, wv.y, wv.z)) * CFrame.Angles(math.rad(-14), math.rad(wv.rot), math.rad(if wv.x < 0 then 16 else -16)),
			Color = Color3.fromRGB(36, 168, 224),
			Material = Enum.Material.SmoothPlastic,
			Parent = f,
		})
		table.insert(floaters, { part = wPart, baseCF = wPart.CFrame, amp = 0.35, freq = 1.7, phase = wv.ph })
		local crest = makePart({
			Name = "WaveFoam_" .. i,
			Size = Vector3.new(wv.sx * 0.92, 0.42, 0.95),
			CFrame = wPart.CFrame * CFrame.new(0, wv.sy * 0.48, wv.sz * 0.28),
			Color = oceanFoam,
			Material = Enum.Material.Neon,
			Transparency = 0.18,
			Parent = f,
		})
		table.insert(floaters, { part = crest, baseCF = crest.CFrame, amp = 0.35, freq = 1.7, phase = wv.ph })
	end
end

-- ============================================================================
-- MONTAGEM DO PALCO PRINCIPAL, PEDESTAIS E VFX DE FUNDO
-- ============================================================================
local function rebuildThemeScene(theme: Themes.StageTheme, featured: { { Id: string, Def: any, SlotRole: string } })
	if not rootFolder then
		return
	end
	if themeFolder then
		themeFolder:Destroy()
	end
	table.clear(sceneSpinners)
	table.clear(floaters)
	table.clear(slotAnchorWorld)

	local tf = Instance.new("Folder")
	tf.Name = "ThemeScene_" .. theme.Id
	tf.Parent = rootFolder
	themeFolder = tf

	-- 1. Fundo de ceu ciclorama
	buildSkyCyclorama(tf, theme)

	-- 2. Deck/chao principal do palco
	makePart({
		Name = "StageDeck",
		Size = Vector3.new(26.5, 1.2, 20.5),
		CFrame = CFrame.new(ORIGIN + Vector3.new(0, -0.6, 0.5)),
		Color = theme.FloorColor,
		Material = theme.FloorMaterial,
		Parent = tf,
	})
	makePart({
		Name = "StageFrontTrim",
		Size = Vector3.new(26.8, 0.24, 0.35),
		CFrame = CFrame.new(ORIGIN + Vector3.new(0, 0.04, 10.65)),
		Color = theme.TrimColor,
		Material = Enum.Material.Neon,
		Parent = tf,
	})
	-- Sombra suave / degrau frontal
	makePart({
		Name = "StageFrontStep",
		Size = Vector3.new(18.0, 0.55, 2.2),
		CFrame = CFrame.new(ORIGIN + Vector3.new(0, -0.25, 11.4)),
		Color = theme.StoneColor,
		Material = theme.FloorMaterial,
		Parent = tf,
	})

	-- 3. Arquitetura especifica do anime
	if theme.Architecture == "Naruto" then
		buildNarutoSetpiece(tf, theme)
	elseif theme.Architecture == "OnePiece" then
		buildOnePieceSetpiece(tf, theme)
	else
		buildCelestialSetpiece(tf, theme)
	end

	-- 4. Os 3 Pedestais + Selos de Chao + Pilares de Energia por Raridade
	for i, slotCfg in ipairs(Themes.Slots) do
		local pick = featured[i]
		local rarity = pick and pick.Def and pick.Def.Rarity or (if slotCfg.IsHero then "Lendario" else "Epico")
		local rInfo = Themes.RarityColors[rarity] or Themes.RarityColors.Epico
		local baseCenter = ORIGIN + Vector3.new(slotCfg.Offset.X, 0, slotCfg.Offset.Z)
		local topY = slotCfg.PedestalHeight

		if slotCfg.IsHero then
			-- Dais cerimonial elevado em 3 degraus para o Lendario Central
			makeCyl("HeroStep1", baseCenter + Vector3.new(0, 0.3, 0), 0.6, 9.4, theme.StoneColor, theme.FloorMaterial, tf)
			makeCyl("HeroStep2", baseCenter + Vector3.new(0, 0.95, 0), 0.7, 8.0, theme.FloorColor:Lerp(theme.StoneColor, 0.5), theme.FloorMaterial, tf)
			makeCyl("HeroTop", baseCenter + Vector3.new(0, 1.75, 0), 1.0, slotCfg.PedestalRadius * 2, theme.StoneColor, theme.FloorMaterial, tf)
			-- Anel dourado luminoso na borda superior
			makeCyl("HeroRimGlow", baseCenter + Vector3.new(0, topY - 0.16, 0), 0.16, slotCfg.PedestalRadius * 2 + 0.34, rInfo.Main, Enum.Material.Neon, tf, 0.22)
			makeCyl("HeroRimLow", baseCenter + Vector3.new(0, 0.62, 0), 0.12, 9.55, theme.Primary, Enum.Material.Neon, tf, 0.32)
		else
			-- Pedestal lateral elegante para os 2 Epicos
			makeCyl("SideStep1_" .. i, baseCenter + Vector3.new(0, 0.22, 0), 0.44, slotCfg.PedestalRadius * 2 + 1.1, theme.StoneColor, theme.FloorMaterial, tf)
			makeCyl("SideTop_" .. i, baseCenter + Vector3.new(0, 0.72, 0), 0.56, slotCfg.PedestalRadius * 2, theme.FloorColor:Lerp(theme.StoneColor, 0.55), theme.FloorMaterial, tf)
			makeCyl("SideRimGlow_" .. i, baseCenter + Vector3.new(0, topY - 0.15, 0), 0.16, slotCfg.PedestalRadius * 2 + 0.28, rInfo.Main, Enum.Material.Neon, tf, 0.24)
		end

		-- Selo/Vortex luminoso girando no topo de cada pedestal
		local floorSigil = makePart({
			Name = "PedestalSigil_" .. i,
			Size = Vector3.new(slotCfg.PedestalRadius * 1.92, 0.06, slotCfg.PedestalRadius * 1.92),
			CFrame = CFrame.new(baseCenter + Vector3.new(0, topY + 0.04, 0)),
			Transparency = 1,
			Parent = tf,
		})
		makeSurfaceImage(
			floorSigil,
			Enum.NormalId.Top,
			if slotCfg.IsHero then theme.SealTexture else ASSETS.GroundVortex,
			if slotCfg.IsHero then theme.Primary:Lerp(rInfo.Main, 0.4) else rInfo.Main,
			if slotCfg.IsHero then 1.25 else 1.12,
			0.22
		)
		table.insert(sceneSpinners, {
			part = floorSigil,
			weld = nil,
			baseCF = floorSigil.CFrame,
			speed = if slotCfg.IsHero then 0.32 else (if i == 1 then -0.45 else 0.45),
			axis = "Y",
			bobAmp = 0,
			phase = i * 1.1,
		})

		-- Pilar volumetrico de energia de raridade subindo ATRAS do personagem
		makePillarBeam(
			tf,
			baseCenter + Vector3.new(0, topY + 0.1, -0.75),
			if slotCfg.IsHero then 15.5 else 11.5,
			if slotCfg.IsHero then 6.4 else 4.6,
			rInfo.Main,
			if slotCfg.IsHero then 0.56 else 0.68,
			if slotCfg.IsHero then 0.62 else 0.48
		)

		-- Ancora 3D na frente da base do pedestal para a placa de nome flutuante na UI
		slotAnchorWorld[i] = baseCenter + Vector3.new(0, if slotCfg.IsHero then 0.55 else 0.15, slotCfg.PedestalRadius * 0.72)
	end

	-- 5. GRANDE HALO VERTICAL (Sunburst + Selo do Anime) atras do Lendario Central (Back = +Z virado para a camera!)
	local haloPos = ORIGIN + Vector3.new(0, 7.2, -4.0)
	local sunburstPart = makePart({
		Name = "HeroSunburstBackdrop",
		Size = Vector3.new(17.5, 17.5, 0.08),
		CFrame = CFrame.new(haloPos + Vector3.new(0, 0, -0.35)),
		Transparency = 1,
		Parent = tf,
	})
	makeSurfaceImage(sunburstPart, Enum.NormalId.Back, ASSETS.SunburstRays, theme.SunburstColor, 0.90, 0.46)
	table.insert(sceneSpinners, {
		part = sunburstPart,
		weld = nil,
		baseCF = sunburstPart.CFrame,
		speed = 0.14,
		axis = "Z",
		bobAmp = 0,
		phase = 0,
	})

	local sealBackPart = makePart({
		Name = "HeroAnimeSealBackdrop",
		Size = Vector3.new(11.6, 11.6, 0.08),
		CFrame = CFrame.new(haloPos),
		Transparency = 1,
		Parent = tf,
	})
	makeSurfaceImage(sealBackPart, Enum.NormalId.Back, theme.SealTexture, theme.Primary, 1.15, 0.20)
	table.insert(sceneSpinners, {
		part = sealBackPart,
		weld = nil,
		baseCF = sealBackPart.CFrame,
		speed = -0.22,
		axis = "Z",
		bobAmp = 0,
		phase = 0.8,
	})

-- 6. Iluminacao de Estudio (Key Light frontal + Rim Light traseira + Fill suave)
	local function addLight(name: string, pos: Vector3, col: Color3, br: number, range: number)
		local lp = makePart({
			Name = name,
			Size = Vector3.new(0.4, 0.4, 0.4),
			CFrame = CFrame.new(pos),
			Transparency = 1,
			Parent = tf,
		})
		local pl = Instance.new("PointLight")
		pl.Color = col
		pl.Brightness = br
		pl.Range = range
		pl.Shadows = false
		pl.Parent = lp
	end
	addLight("KeyLightFront", ORIGIN + Vector3.new(0, 9.5, 12.0), theme.KeyLightColor, 0.45, 36)
	addLight("FillLightLeft", ORIGIN + Vector3.new(-10.5, 6.2, 8.5), theme.KeyLightColor:Lerp(theme.Secondary, 0.25), 0.22, 26)
	addLight("FillLightRight", ORIGIN + Vector3.new(10.5, 6.2, 8.5), theme.KeyLightColor:Lerp(theme.Primary, 0.25), 0.22, 26)
	addLight("RimLightBack", ORIGIN + Vector3.new(0, 9.0, -5.5), theme.RimLightColor, 0.55, 30)

	-- 7. Particulas ambientais do tema (SEMPRE em BasePart direta com Shape=Box, nunca em Attachment!)
	local ambSpec = theme.AmbientParticle
	local ambBox = makePart({
		Name = "AmbientParticleVolume",
		Size = Vector3.new(26, 12, 12),
		CFrame = CFrame.new(ORIGIN + Vector3.new(0, 6.5, -1.5)),
		Transparency = 1,
		Parent = tf,
	})
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "ThemeAmbientFx"
	pe.Texture = ambSpec.Texture
	pe.Color = ColorSequence.new(ambSpec.ColorA, ambSpec.ColorB)
	pe.LightEmission = ambSpec.LightEmission
	pe.LightInfluence = 0
	pe.Rate = ambSpec.Rate
	pe.Lifetime = NumberRange.new(ambSpec.LifetimeMin, ambSpec.LifetimeMax)
	pe.Speed = NumberRange.new(ambSpec.SpeedMin, ambSpec.SpeedMax)
	pe.Acceleration = ambSpec.Accel
	pe.Drag = 0.35
	pe.SpreadAngle = Vector2.new(35, 35)
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-90, 90)
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.18, ambSpec.SizeMax),
		NumberSequenceKeypoint.new(0.75, ambSpec.SizeMin),
		NumberSequenceKeypoint.new(1, 0),
	})
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.12),
		NumberSequenceKeypoint.new(0.80, 0.18),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe.Shape = Enum.ParticleEmitterShape.Box
	pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	pe.Parent = ambBox

	-- Emissor de burst rapido na troca de banner
	local burstBox = makePart({
		Name = "ThemeSwapBurstVolume",
		Size = Vector3.new(18, 8, 4),
		CFrame = CFrame.new(ORIGIN + Vector3.new(0, 5.2, 0.4)),
		Transparency = 1,
		Parent = tf,
	})
	local bpe = Instance.new("ParticleEmitter")
	bpe.Name = "SwapBurst"
	bpe.Texture = ASSETS.StarFlare
	bpe.Color = ColorSequence.new(theme.Primary, theme.Accent)
	bpe.LightEmission = 1
	bpe.LightInfluence = 0
	bpe.Rate = 0
	bpe.Lifetime = NumberRange.new(0.45, 0.85)
	bpe.Speed = NumberRange.new(4, 10)
	bpe.Drag = 3.5
	bpe.SpreadAngle = Vector2.new(180, 180)
	bpe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(0.5, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	bpe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	bpe.Shape = Enum.ParticleEmitterShape.Box
	bpe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	bpe.Parent = burstBox
	burstEmitter = bpe
end

-- ============================================================================
-- CONTENCAO ELEGANTE DE VFX PROPRIOS DOS PERSONAGENS (ex.: San.AuraVfx, BarbaBranca)
-- ============================================================================
local function scaleNumberSequence(seq: NumberSequence, factor: number): NumberSequence
	local kps = {}
	for _, kp in ipairs(seq.Keypoints) do
		table.insert(kps, NumberSequenceKeypoint.new(kp.Time, kp.Value * factor, kp.Envelope * factor))
	end
	return NumberSequence.new(kps)
end

local function containCharacterVfx(model: Model, slotCfg: any): ({ AnimSpinner }, PointLight?, number)
	local auraSpinners: { AnimSpinner } = {}
	local auraLight: PointLight? = nil
	local auraLightBase = 1.4
	local maxW: number = slotCfg.MaxAuraWidth or 5.2

	-- Garante que CharacterAuraClient nao anime/cull clones do palco em duplicidade
	for _, d in ipairs(model:GetDescendants()) do
		if CollectionService:HasTag(d, "CharacterAura") then
			CollectionService:RemoveTag(d, "CharacterAura")
		end
	end

	local Players = game:GetService("Players")
	local lp = Players.LocalPlayer
	local pg = lp and lp:FindFirstChildOfClass("PlayerGui")
	local aurasOn = (not pg) or (pg:GetAttribute("CharacterAuras") ~= false)
	local auraFolder = model:FindFirstChild("AuraVfx")
	if not aurasOn then
		if auraFolder then
			auraFolder:Destroy()
		end
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("Highlight") or (d:IsA("ParticleEmitter") and d.Name == "YonkoPresence") then
				d:Destroy()
			end
		end
		return auraSpinners, auraLight, auraLightBase
	end

	-- 1. Encolhe pecas de chao e fitas 3D da AuraVfx para caberem com perfeicao no pedestal do slot
	if auraFolder then
		for _, d in ipairs(auraFolder:GetDescendants()) do
			if d:IsA("BasePart") then
				-- Aneis planos de chao (ex.: GroundGlow 11x0.05x11, GroundVortexOuter 10.2)
				if d.Size.Y <= 0.25 and (d.Size.X > maxW or d.Size.Z > maxW) then
					local ratio = maxW / math.max(d.Size.X, d.Size.Z)
					d.Size = Vector3.new(d.Size.X * ratio, d.Size.Y, d.Size.Z * ratio)
					local w = d:FindFirstChild("AuraWeld")
					if w and w:IsA("Weld") then
						w.C0 = w.C0 + Vector3.new(0, 0.08, 0)
					end
				elseif d.Name == "AuraPerimeter" and (d.Size.X > maxW * 0.72 or d.Size.Z > maxW * 0.72) then
					local ratio = (maxW * 0.72) / math.max(d.Size.X, d.Size.Z)
					d.Size = Vector3.new(d.Size.X * ratio, d.Size.Y * 0.85, d.Size.Z * ratio)
				elseif d.Name == "AuraVolume" then
					d.Size = Vector3.new(math.min(d.Size.X, 2.4), math.min(d.Size.Y, 4.4), math.min(d.Size.Z, 2.4))
				end

				-- Recolhe attachments de fitas helicoidais e orbes orbitais para abracar o personagem sem invadir vizinhos
				if d.Name == "RibbonCarrier" then
					for _, child in ipairs(d:GetChildren()) do
						if child:IsA("Attachment") then
							child.Position = Vector3.new(child.Position.X * 0.68, child.Position.Y * 0.88, child.Position.Z * 0.68)
						end
					end
				elseif d.Name == "OrbitOrbsCarrier" then
					for _, child in ipairs(d:GetDescendants()) do
						if child:IsA("Weld") and child.Name == "OrbWeld" then
							local p = child.C0.Position
							child.C0 = CFrame.new(p.X * 0.72, p.Y * 0.85, p.Z * 0.72)
						end
					end
				elseif d.Name == "BackHaloAnchor" and (d.Size.X > 3.6 or d.Size.Y > 3.6) then
					d.Size = Vector3.new(math.min(d.Size.X, 3.6), math.min(d.Size.Y, 3.6), d.Size.Z)
				end

				-- Registra SpinSpeed (ex.: aneis do chao, fitas 3D, orbes e halos traseiros) para animacao propria no palco
				local spd = d:GetAttribute("SpinSpeed")
				if typeof(spd) == "number" and spd ~= 0 then
					local weld = d:FindFirstChild("AuraWeld")
					local w = if weld and weld:IsA("Weld") then weld else nil
					local baseCF = if w then w.C0 else d.CFrame
					local axisAttr = d:GetAttribute("SpinAxis")
					table.insert(auraSpinners, {
						part = d,
						weld = w,
						baseCF = baseCF,
						speed = spd,
						axis = if typeof(axisAttr) == "string" then axisAttr else "Y",
						bobAmp = if d.Name == "RibbonCarrier" or d.Name == "OrbitOrbsCarrier" then 0.12 else 0,
						phase = 0,
					})
				end
			end
		end
	end

	-- 2. Ajusta emissores, beams, luzes e glows de QUALQUER personagem com VFX proprio
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			local inAura = auraFolder and d:IsDescendantOf(auraFolder)
			local sizeMul = if slotCfg.IsHero then 0.64 else 0.52
			local rateMul = if slotCfg.IsHero then 0.70 else 0.56
			if not inAura then
				-- Emissores mais sutis como BarbaBranca.YonkoPresence ficam quase intactos
				sizeMul = if slotCfg.IsHero then 0.82 else 0.70
				rateMul = if slotCfg.IsHero then 0.85 else 0.72
			end
			d.Size = scaleNumberSequence(d.Size, sizeMul)
			d.Rate = math.max(1.5, d.Rate * rateMul)
			d.Speed = NumberRange.new(d.Speed.Min * 0.72, d.Speed.Max * 0.74)
			d.Brightness = math.min(d.Brightness, 1.45)
			-- Empurra chamas/glows grandes levemente para tras para o rosto e os vizinhos ficarem nitidos
			if inAura and (d.Name:find("Flame") or d.Name:find("Back") or d.Name:find("Crown")) then
				d.ZOffset = math.min(d.ZOffset, -0.55)
			end
		elseif d:IsA("Beam") then
			d.Width0 *= 0.64
			d.Width1 *= 0.64
			d.CurveSize0 *= 0.68
			d.CurveSize1 *= 0.68
			d.Brightness = math.min(d.Brightness, 1.45)
		elseif d:IsA("PointLight") then
			d.Range = math.min(d.Range, 9.5)
			d.Brightness = math.min(d.Brightness, 0.95)
			if not auraLight then
				auraLight = d
				auraLightBase = d.Brightness
			end
		elseif d:IsA("Highlight") then
			-- Preserva o contorno cel-anime limpo sem ofuscar o personagem
			d.FillTransparency = math.max(d.FillTransparency, 0.88)
			d.OutlineTransparency = math.clamp(d.OutlineTransparency, 0.08, 0.45)
		end
	end

	return auraSpinners, auraLight, auraLightBase
end

-- ============================================================================
-- POSES HEROICAS DINAMICAS (I-Pose, R15 A-Pose e Skinned Bones)
-- ============================================================================
local JOINT_MAP: { [string]: string } = {
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

local function buildRigState(model: Model, slotIndex: number, poseName: string): RigState
	local isIPose = (model:FindFirstChild("LeftArm_Mesh") ~= nil) or (model:FindFirstChild("Torso_Mesh") ~= nil)
	local motors: { [string]: { motor: Motor6D, baseC0: CFrame } } = {}
	local bones: { [string]: { bone: Bone, baseCF: CFrame } } = {}
	local boneCount = 0

	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") then
			local key = JOINT_MAP[d.Name] or (d.Part1 and d.Part1.Name)
			if key and not motors[key] then
				d.Transform = CFrame.identity
				motors[key] = { motor = d, baseC0 = d.C0 }
			end
		elseif d:IsA("Bone") then
			boneCount += 1
			if not bones[d.Name] then
				d.Transform = CFrame.identity
				bones[d.Name] = { bone = d, baseCF = d.CFrame }
			end
		end
	end

	local isSkinned = (boneCount >= 8) and (motors.LeftUpperArm == nil)
	return {
		model = model,
		slotIndex = slotIndex,
		isIPose = isIPose,
		isSkinned = isSkinned,
		motors = motors,
		bones = bones,
		pose = Themes.Poses[poseName] or Themes.Poses.Center_HeroPower,
		seed = slotIndex * 2.13,
		basePivot = model:GetPivot(),
		enterTime = elapsed,
		auraSpinners = {},
		auraLight = nil,
		auraLightBase = 1.4,
	}
end

local function setRigJoint(rig: RigState, jointName: string, delta: CFrame)
	if rig.isSkinned then
		local b = rig.bones[jointName]
		if b and b.bone.Parent then
			b.bone.CFrame = b.baseCF * delta
		end
	else
		local m = rig.motors[jointName]
		if m and m.motor.Parent then
			m.motor.C0 = m.baseC0 * delta
		end
	end
end

local function applyPoseFrame(rig: RigState, t: number)
	local p = rig.pose
	local phase = t * 2.1 + rig.seed
	local breath = math.sin(phase) * (p.BreathAmp or 1.0)
	local sway = math.sin(phase * 0.5) * (p.BreathAmp or 1.0)

	-- Compensacao A-Pose exata (medida em ProtoRaro: +40 graus em Z zera o braco esquerdo para I-Pose vertical exato!)
	local aPoseLeft = if rig.isIPose then CFrame.identity else CFrame.Angles(0, 0, math.rad(40))
	local aPoseRight = if rig.isIPose then CFrame.identity else CFrame.Angles(0, 0, math.rad(-40))
	local bendMult = if rig.isIPose then 0 else 1

	local function ang(tbl: any, addX: number, addY: number, addZ: number): CFrame
		if not tbl then
			return CFrame.Angles(math.rad(addX), math.rad(addY), math.rad(addZ))
		end
		return CFrame.Angles(
			math.rad((tbl.RX or 0) + addX),
			math.rad((tbl.RY or 0) + addY),
			math.rad((tbl.RZ or 0) + addZ)
		)
	end

	local lt = p.LowerTorso
	local bobY = (lt and lt.Y or 0) + 0.045 * breath
	setRigJoint(rig, "LowerTorso", CFrame.new(0, bobY, 0) * ang(lt, 0, 1.4 * sway, 0.7 * sway))
	setRigJoint(rig, "UpperTorso", ang(p.UpperTorso, 2.2 * breath, -1.2 * sway, 0))
	setRigJoint(rig, "Head", ang(p.Head, -1.6 * breath, 2.2 * sway, -0.6 * sway))

	-- Bracos: aplica aPoseLeft/Right A DIREITA para neutralizar o A-pose antes da rotacao da pose heroica!
	local armXScale = if rig.isIPose then 0.78 else 1.0
	local la = p.LeftUpperArm
	local ra = p.RightUpperArm
	setRigJoint(
		rig,
		"LeftUpperArm",
		CFrame.Angles(
			math.rad((la and la.RX or 0) * armXScale + 2.0 * breath),
			math.rad(la and la.RY or 0),
			math.rad((la and la.RZ or 0) - 1.6 * breath)
		) * aPoseLeft
	)
	setRigJoint(
		rig,
		"RightUpperArm",
		CFrame.Angles(
			math.rad((ra and ra.RX or 0) * armXScale - 2.0 * breath),
			math.rad(ra and ra.RY or 0),
			math.rad((ra and ra.RZ or 0) + 1.6 * breath)
		) * aPoseRight
	)

	if bendMult > 0 then
		setRigJoint(rig, "LeftLowerArm", ang(p.LeftLowerArm, 2.0 * breath, 0, 0))
		setRigJoint(rig, "RightLowerArm", ang(p.RightLowerArm, 2.0 * breath, 0, 0))
	end

	-- Pernas (postura heroica firme + contra-rotacao de tornozelo em R15)
	local legScale = if rig.isIPose then 0.72 else 1.0
	local ll = p.LeftUpperLeg
	local rl = p.RightUpperLeg
	setRigJoint(
		rig,
		"LeftUpperLeg",
		CFrame.Angles(
			math.rad((ll and ll.RX or 0) * legScale),
			math.rad((ll and ll.RY or 0) * legScale),
			math.rad((ll and ll.RZ or 0))
		)
	)
	setRigJoint(
		rig,
		"RightUpperLeg",
		CFrame.Angles(
			math.rad((rl and rl.RX or 0) * legScale),
			math.rad((rl and rl.RY or 0) * legScale),
			math.rad((rl and rl.RZ or 0))
		)
	)
	if bendMult > 0 then
		setRigJoint(rig, "LeftLowerLeg", ang(p.LeftLowerLeg, 0, 0, 0))
		setRigJoint(rig, "RightLowerLeg", ang(p.RightLowerLeg, 0, 0, 0))
		setRigJoint(rig, "LeftFoot", ang(p.LeftFoot, 0, 0, 0))
		setRigJoint(rig, "RightFoot", ang(p.RightFoot, 0, 0, 0))
	end
end

-- Calcula altura e base real do corpo (ignorando AuraVfx e armas enormes como o Bisento)
local function measureBodyBounds(model: Model): (number, number)
	local auraFolder = model:FindFirstChild("AuraVfx")
	local mfFolder = model:FindFirstChild("Marineford3D")
	local minY = math.huge
	local maxY = -math.huge
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.96 then
			if (not auraFolder or not d:IsDescendantOf(auraFolder)) and (not mfFolder or not d:IsDescendantOf(mfFolder)) then
				local cf = d.CFrame
				local half = d.Size * 0.5
				local extentY = math.abs(cf.RightVector.Y) * half.X
					+ math.abs(cf.UpVector.Y) * half.Y
					+ math.abs(cf.LookVector.Y) * half.Z
				minY = math.min(minY, cf.Position.Y - extentY)
				maxY = math.max(maxY, cf.Position.Y + extentY)
			end
		end
	end
	if minY == math.huge then
		local cf, sz = model:GetBoundingBox()
		return cf.Position.Y - sz.Y * 0.5, cf.Position.Y + sz.Y * 0.5
	end
	return minY, maxY
end

local function cloneShowcaseUnit(charId: string, editModelProvider: ((string) -> Model?)?): Model?
	if editModelProvider then
		return editModelProvider(charId)
	end
	local showcaseFolder = ReplicatedStorage:FindFirstChild("SummonShowcaseModels") or ReplicatedStorage:WaitForChild("SummonShowcaseModels", 1.5)
	if showcaseFolder then
		local tpl = showcaseFolder:FindFirstChild(charId)
		if tpl and tpl:IsA("Model") then
			return tpl:Clone()
		end
	end
	-- Fallback para CharacterPreviews se o modelo ainda estiver carregando
	local previews = ReplicatedStorage:FindFirstChild("CharacterPreviews")
	if previews then
		local tpl = previews:FindFirstChild(charId)
		if tpl and tpl:IsA("Model") then
			return tpl:Clone()
		end
	end
	return nil
end

local function spawnFeaturedUnits(featured: { { Id: string, Def: any, SlotRole: string } }, editModelProvider: ((string) -> Model?)?)
	if not rootFolder then
		return
	end
	if unitsFolder then
		unitsFolder:Destroy()
	end
	table.clear(activeRigs)

	local uf = Instance.new("Folder")
	uf.Name = "FeaturedUnits"
	uf.Parent = rootFolder
	unitsFolder = uf

	for i, slotCfg in ipairs(Themes.Slots) do
		local pick = featured[i]
		if not pick then
			continue
		end
		local clone = cloneShowcaseUnit(pick.Id, editModelProvider)
		if not clone then
			continue
		end

		clone.Name = string.format("Slot%d_%s", i, pick.Id)
		local hrp = clone:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			clone.PrimaryPart = hrp
		end

		-- Posiciona temporariamente no palco e normaliza altura extrema (ex.: BarbaBranca 8.2 studs)
		local pedestalTopPos = ORIGIN + Vector3.new(slotCfg.Offset.X, slotCfg.PedestalHeight, slotCfg.Offset.Z)
		-- Faceia +Z (em direcao a camera) + yaw lateral para enquadrar o trio
		local facingCF = CFrame.new(pedestalTopPos + Vector3.new(0, 3.2, 0))
			* CFrame.Angles(0, math.rad(180 + slotCfg.YawDeg), 0)
		clone:PivotTo(facingCF)
		clone.Parent = uf

		-- Mede corpo e normaliza escala com suavidade (Lendario central pode ser um pouco mais imponente)
		local minY0, maxY0 = measureBodyBounds(clone)
		local bodyH = math.max(2.0, maxY0 - minY0)
		local targetH = slotCfg.ScaleTargetHeight
		if bodyH > targetH * 1.12 or bodyH < targetH * 0.85 then
			local sc = math.clamp(targetH / bodyH, 0.78, 1.12)
			pcall(function()
				clone:ScaleTo(sc)
			end)
		end

		-- Contem VFX proprios do personagem (ex.: San.AuraVfx, BarbaBranca.YonkoPresence) sem estragar vizinhos
		local auraSpinners, auraLight, auraLightBase = containCharacterVfx(clone, slotCfg)

		-- Monta rig e aplica pose heroica inicial ANTES de assentar os pes no pedestal
		local rig = buildRigState(clone, i, slotCfg.PoseName)
		rig.auraSpinners = auraSpinners
		rig.auraLight = auraLight
		rig.auraLightBase = auraLightBase
		applyPoseFrame(rig, elapsed)

		-- Assenta pes EXATAMENTE no topo do pedestal (zero flutuacao, zero tornozelo enterrado)
		local minY, _ = measureBodyBounds(clone)
		local targetFootY = ORIGIN.Y + slotCfg.PedestalHeight + 0.03
		local liftY = targetFootY - minY
		local finalPivot = clone:GetPivot() + Vector3.new(0, liftY, 0)
		clone:PivotTo(finalPivot)
		rig.basePivot = finalPivot
		table.insert(activeRigs, rig)
	end
end

-- ============================================================================
-- LOOP DE ANIMACAO DO PALCO (60 FPS suave: poses, halos, flutuadores, auras, camera)
-- ============================================================================
local function stepStage(dt: number, updateCamera: boolean)
	elapsed += math.min(dt, 0.05)

	-- 1. Selos e sunbursts girando
	for _, sp in ipairs(sceneSpinners) do
		if sp.part.Parent then
			local ang = elapsed * sp.speed + sp.phase
			if sp.axis == "Z" then
				sp.part.CFrame = sp.baseCF * CFrame.Angles(0, 0, ang)
			else
				sp.part.CFrame = sp.baseCF * CFrame.Angles(0, ang, 0)
			end
		end
	end

	-- 2. Cristais, ondas e flamulas flutuando suavemente
	for _, fl in ipairs(floaters) do
		if fl.part.Parent then
			local dy = math.sin(elapsed * fl.freq + fl.phase) * fl.amp
			fl.part.CFrame = fl.baseCF + Vector3.new(0, dy, 0)
		end
	end

	-- 3. Poses vivas + auras contidas dos 3 personagens
	for _, rig in ipairs(activeRigs) do
		if rig.model.Parent then
			applyPoseFrame(rig, elapsed)

			-- Entrada suave de surgimento (0.28s ease-out ao trocar banner)
			local age = elapsed - rig.enterTime
			if age < 0.30 then
				local u = math.clamp(age / 0.30, 0, 1)
				local ease = 1 - (1 - u) ^ 3
				rig.model:PivotTo(rig.basePivot + Vector3.new(0, -0.55 * (1 - ease), 0))
			elseif age < 0.38 then
				rig.model:PivotTo(rig.basePivot)
			end

			-- Anima SpinSpeed de auras proprias (ex.: San.AuraVfx)
			for _, sp in ipairs(rig.auraSpinners) do
				if sp.weld and sp.weld.Parent then
					local ang = elapsed * sp.speed
					local bob = if sp.bobAmp > 0 then math.sin(elapsed * 2.4) * sp.bobAmp else 0
					local spinRot = if sp.axis == "Z" then CFrame.Angles(0, 0, ang) else CFrame.Angles(0, ang, 0)
					sp.weld.C0 = CFrame.new(sp.baseCF.Position + Vector3.new(0, bob, 0))
						* (sp.baseCF - sp.baseCF.Position)
						* spinRot
				end
			end
			if rig.auraLight and rig.auraLight.Parent then
				rig.auraLight.Brightness = rig.auraLightBase * (0.9 + 0.14 * math.sin(elapsed * 3.8 + rig.seed))
			end
		end
	end

	-- 4. Camera cinematografica com respiracao bem sutil
	if updateCamera then
		local cam = workspace.CurrentCamera
		if cam then
			local c = Themes.Camera
			local dx = math.sin(elapsed * c.DriftFreq) * c.DriftX
			local dy = math.cos(elapsed * c.DriftFreq * 0.72) * c.DriftY
			local pos = ORIGIN + c.Position + Vector3.new(dx, dy, 0)
			local look = ORIGIN + c.LookAt
			cam.CameraType = Enum.CameraType.Scriptable
			cam.FieldOfView = c.FieldOfView
			cam.CFrame = CFrame.lookAt(pos, look)
			cam.Focus = CFrame.new(look)
		end
	end
end

local function ensureRoot(): Folder
	if rootFolder and rootFolder.Parent then
		return rootFolder
	end
	local old = workspace:FindFirstChild("_SummonBannerStage")
	if old then
		old:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "_SummonBannerStage"
	f.Parent = workspace
	rootFolder = f
	return f
end

-- ============================================================================
-- API PUBLICA
-- ============================================================================
function Stage.IsOpen(): boolean
	return isOpen
end

function Stage.GetFeatured(): { { Id: string, Def: any, SlotRole: string } }
	return currentFeatured
end

function Stage.GetTheme(): Themes.StageTheme
	return Themes.GetTheme(currentBannerId, currentPortalId)
end

-- Retorna posicoes de tela (Vector2 em pixels, visible) dos 3 pedestais para alinhar nameplates
function Stage.GetSlotScreenAnchors(): { [number]: { Pos: Vector2, Visible: boolean } }
	local out: { [number]: { Pos: Vector2, Visible: boolean } } = {}
	local cam = workspace.CurrentCamera
	if not cam then
		return out
	end
	for i = 1, 3 do
		local wp = slotAnchorWorld[i]
		if wp then
			local vp, onScreen = cam:WorldToViewportPoint(wp)
			out[i] = { Pos = Vector2.new(vp.X, vp.Y), Visible = onScreen and vp.Z > 0 }
		end
	end
	return out
end

function Stage.SetBanner(bannerId: string, portalId: string, weeklyLegendaryId: string?)
	pcall(function()
		currentBannerId = bannerId or "Todos"
		currentPortalId = portalId or "Comum"
		currentWeeklyId = weeklyLegendaryId
		local theme = Themes.GetTheme(currentBannerId, currentPortalId)
		currentFeatured = Themes.ResolveFeatured(currentBannerId, currentPortalId, currentWeeklyId)
		if not isOpen then
			return
		end
		ensureRoot()
		rebuildThemeScene(theme, currentFeatured)
		spawnFeaturedUnits(currentFeatured, nil)
		if burstEmitter and burstEmitter.Parent then
			burstEmitter:Emit(24)
		end
	end)
end

function Stage.Open(bannerId: string, portalId: string, weeklyLegendaryId: string?)
	pcall(function()
		currentBannerId = bannerId or "Todos"
		currentPortalId = portalId or "Comum"
		currentWeeklyId = weeklyLegendaryId

		if not isOpen then
			local cam = workspace.CurrentCamera
			if cam then
				savedCam = {
					Type = cam.CameraType,
					CFrame = cam.CFrame,
					Focus = cam.Focus,
					FieldOfView = cam.FieldOfView,
				}
			end
			isOpen = true
		end
		applyStageLighting(true)

		ensureRoot()
		local theme = Themes.GetTheme(currentBannerId, currentPortalId)
		currentFeatured = Themes.ResolveFeatured(currentBannerId, currentPortalId, currentWeeklyId)
		rebuildThemeScene(theme, currentFeatured)
		spawnFeaturedUnits(currentFeatured, nil)
		stepStage(0, true)

		if burstEmitter and burstEmitter.Parent then
			burstEmitter:Emit(20)
		end

		if not animConn then
			animConn = RunService.RenderStepped:Connect(function(dt)
				if isOpen then
					stepStage(dt, true)
				end
			end)
		end
	end)
end

function Stage.Close()
	pcall(function()
		if animConn then
			animConn:Disconnect()
			animConn = nil
		end
		isOpen = false
		table.clear(activeRigs)
		table.clear(sceneSpinners)
		table.clear(floaters)
		table.clear(slotAnchorWorld)
		burstEmitter = nil

		if rootFolder then
			rootFolder:Destroy()
			rootFolder = nil
			themeFolder = nil
			unitsFolder = nil
		end

		local cam = workspace.CurrentCamera
		if cam and savedCam then
			cam.FieldOfView = savedCam.FieldOfView
			cam.CameraType = savedCam.Type
			if savedCam.Type == Enum.CameraType.Scriptable then
				cam.CFrame = savedCam.CFrame
				cam.Focus = savedCam.Focus
			end
		end
		savedCam = nil
		applyStageLighting(false)
	end)
end

-- Helper somente para preview visual em Edit mode (nao usado em runtime)
function Stage.BuildPreviewForEdit(bannerId: string, portalId: string, weeklyLegendaryId: string?, modelProvider: (string) -> Model?)
	currentBannerId = bannerId or "Todos"
	currentPortalId = portalId or "Comum"
	currentWeeklyId = weeklyLegendaryId
	ensureRoot()
	local theme = Themes.GetTheme(currentBannerId, currentPortalId)
	currentFeatured = Themes.ResolveFeatured(currentBannerId, currentPortalId, currentWeeklyId)
	rebuildThemeScene(theme, currentFeatured)
	spawnFeaturedUnits(currentFeatured, modelProvider)
	stepStage(0.35, false)
	return ORIGIN + Themes.Camera.Position, ORIGIN + Themes.Camera.LookAt, currentFeatured
end

function Stage.DestroyPreview()
	Stage.Close()
end

return Stage
