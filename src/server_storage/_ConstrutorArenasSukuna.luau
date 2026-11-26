--[[
	_ConstrutorArenasSukuna (v5 - Edicao Definitiva Fiel a Referencia)
	Recria fielmente a imagem de referencia enviada pelo usuario:
	- Grande Portao do Santuario Malevolente sobre o mar raso "infinito" rosa-carmesim espelhado
	  com fundo panoramico de nuvens rubras e reflexo liquido ciano/carmesim/negro alinhado sob o portao.
	- SEM Sukuna sentado e SEM trono.
	- DOIS Grandes Portoes espelhados em 180 graus (quem esta de um lado ve o portao, quem esta do outro
	  ve o outro portao identico).
	- Grade 2x5 com 700x750 studs de distancia (370+ studs livres entre arenas, zero sobreposicao).
]]

local SS = game:GetService("ServerStorage")

local sukunaKit = SS:WaitForChild("ArenaSukunaKit")
local mapaKit = SS:WaitForChild("MapaV2Kit")

local M = {}

M.TEX = {
	SKY_CLOUDS       = "rbxassetid://140064376944220",
	WATER_RIPPLES    = "rbxassetid://101898582620559",
	WATER_REFLECTION = "rbxassetid://100029044981062",
	WATER_VIGNETTE   = "rbxassetid://108091004521195",
	CYAN_PORTAL      = "rbxassetid://105597434772797",
	VFX_RIPPLE       = "rbxassetid://121641539746345",
	VFX_MOTE         = "rbxassetid://79340195572497",
	VFX_WISP         = "rbxassetid://129037333227435",
	VFX_EMBER        = "rbxassetid://93633042519778",
	PEDESTAL_SEAL    = "rbxassetid://102932403043800",
}

M.GRID = {
	{ id = 1,  pos = Vector3.new(1600, 40,    0) },
	{ id = 2,  pos = Vector3.new(1600, 40,  700) },
	{ id = 3,  pos = Vector3.new(1600, 40, 1400) },
	{ id = 4,  pos = Vector3.new(1600, 40, 2100) },
	{ id = 5,  pos = Vector3.new(1600, 40, 2800) },
	{ id = 6,  pos = Vector3.new(2350, 40,    0) },
	{ id = 7,  pos = Vector3.new(2350, 40,  700) },
	{ id = 8,  pos = Vector3.new(2350, 40, 1400) },
	{ id = 9,  pos = Vector3.new(2350, 40, 2100) },
	{ id = 10, pos = Vector3.new(2350, 40, 2800) },
}

local COL = {
	skyTop       = Color3.fromRGB(14, 0, 3),
	skyHorizon   = Color3.fromRGB(2, 0, 1),
	waterBase    = Color3.fromRGB(68, 10, 16),
	waterDeep    = Color3.fromRGB(48, 6, 12),
	cyanBright   = Color3.fromRGB(115, 244, 242),
	cyanDeep     = Color3.fromRGB(48, 192, 202),
	gumMain      = Color3.fromRGB(178, 24, 64),
	gumDark      = Color3.fromRGB(132, 14, 44),
	tooth        = Color3.fromRGB(234, 200, 196),
	toothRoot    = Color3.fromRGB(202, 156, 154),
	roofTile     = Color3.fromRGB(186, 22, 45),
	roofRidge    = Color3.fromRGB(214, 48, 66),
	woodDark     = Color3.fromRGB(38, 6, 8),
	woodPillar   = Color3.fromRGB(74, 11, 20),
	totemDark    = Color3.fromRGB(22, 5, 9),
	totemCap     = Color3.fromRGB(122, 16, 42),
	hornBase     = Color3.fromRGB(64, 15, 28),
	hornMid      = Color3.fromRGB(152, 102, 124),
	hornTip      = Color3.fromRGB(224, 208, 220),
	boneTint     = Color3.fromRGB(236, 178, 166),
	hornOrange   = Color3.fromRGB(245, 76, 28),
}

local function lerpColor(a: Color3, b: Color3, t: number): Color3
	return Color3.new(
		a.R + (b.R - a.R) * t,
		a.G + (b.G - a.G) * t,
		a.B + (b.B - a.B) * t
	)
end

local function makePart(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = false
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function placeSukunaModel(name, baseCF, scale, parent, tintColor)
	local m = sukunaKit[name]:Clone()
	if scale and scale ~= 1 then
		m:ScaleTo(scale)
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CastShadow = false
			if tintColor then
				d.Color = tintColor
			end
		end
	end
	m.PrimaryPart = nil
	m:PivotTo(CFrame.new(0, 0, 0))
	local cf, sz = m:GetBoundingBox()
	local targetCenter = baseCF * CFrame.new(0, sz.Y / 2, 0)
	local pivotOffset = m:GetPivot().Position - cf.Position
	m:PivotTo(targetCenter + pivotOffset)
	m.Parent = parent
	return m, sz
end

local function buildRoundedTooth(parent, cf: CFrame, w: number, h: number, d: number, isUpper: boolean)
	local radius = math.min(w, d) * 0.48
	local bodyH = math.max(0.2, h - radius)
	local dirSign = if isUpper then -1 else 1
	makePart(parent, {
		Name = "DenteRaiz",
		Size = Vector3.new(w * 0.94, bodyH * 0.38, d * 0.92),
		CFrame = cf * CFrame.new(0, -dirSign * (bodyH * 0.31), 0),
		Color = COL.toothRoot,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	makePart(parent, {
		Name = "DenteCorpo",
		Size = Vector3.new(w, bodyH * 0.72, d),
		CFrame = cf * CFrame.new(0, dirSign * (bodyH * 0.14), 0),
		Color = COL.tooth,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	makePart(parent, {
		Name = "DentePonta",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(w * 0.98, d, d),
		CFrame = cf * CFrame.new(0, dirSign * (bodyH * 0.5), 0),
		Color = COL.tooth,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
end

local function buildJawArch(parent, centerCF: CFrame, width: number, archRise: number, toothCount: number, toothH: number, toothD: number, isUpper: boolean)
	local dirSign = if isUpper then 1 else -1
	local nGum = toothCount + 2
	for i = 1, nGum do
		local u = (i - (nGum + 1) / 2) / ((nGum - 1) / 2)
		local x = u * (width * 0.52)
		local y = dirSign * archRise * (1 - u * u * 0.85)
		local tilt = -dirSign * u * 0.32
		local segW = (width / toothCount) * 1.35
		makePart(parent, {
			Name = "Gengiva",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(segW, toothD * 1.48, toothD * 1.48),
			CFrame = centerCF * CFrame.new(x, y, 0) * CFrame.Angles(0, 0, tilt),
			Color = if math.abs(u) > 0.75 then COL.gumDark else COL.gumMain,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
	end

	local toothW = (width / toothCount) * 0.90
	for i = 1, toothCount do
		local u = (i - (toothCount + 1) / 2) / math.max(1, (toothCount - 1) / 2)
		local x = u * (width * 0.46)
		local curveY = dirSign * archRise * (1 - u * u * 0.82)
		local scaleH = toothH * (1 - 0.16 * u * u)
		local toothCF = centerCF
			* CFrame.new(x, curveY - dirSign * (toothD * 0.40 + scaleH * 0.35), -0.08)
			* CFrame.Angles(0, -u * 0.14, -dirSign * u * 0.16)
		buildRoundedTooth(parent, toothCF, toothW, scaleH, toothD, isUpper)
	end
end

-- Chifre curvo crescente (curva PARA CIMA como presa de touro, afinando ate ponta fina sem tampa achatada!)
local function buildUpwardTuskHorn(parent, gateCF: CFrame, sx: number, startPos: Vector3, reachX: number, riseY: number, sweepZ: number, baseRadius: number)
	local segs = 18
	-- Curva Bezier quadratica: sai horizontal/diagonal para fora e curva forte PARA CIMA ate ponta agulha!
	local p0 = Vector3.new(0, 0, 0)
	local p1 = Vector3.new(reachX * 0.72, riseY * 0.22, sweepZ * 0.5)
	local p2 = Vector3.new(reachX, riseY, sweepZ)

	local function localPt(t: number): Vector3
		local omt = 1 - t
		local b = omt * omt * p0 + 2 * omt * t * p1 + t * t * p2
		return Vector3.new(sx * (startPos.X + b.X), startPos.Y + b.Y, startPos.Z + b.Z)
	end

	local prev = localPt(0)
	for i = 1, segs do
		local t = i / segs
		local cur = localPt(t)
		local segLen = (cur - prev).Magnitude + 0.22
		local mid = (prev + cur) * 0.5
		local diam = math.max(0.12, baseRadius * 2 * ((1 - t * 0.94) ^ 1.18))

		local w1 = gateCF:PointToWorldSpace(prev)
		local w2 = gateCF:PointToWorldSpace(cur)
		local wMid = gateCF:PointToWorldSpace(mid)
		local dir = (w2 - w1).Unit
		local upRef = math.abs(dir.Z) < 0.95 and Vector3.zAxis or Vector3.yAxis
		local zAxis = dir:Cross(upRef).Unit
		local yAxis = zAxis:Cross(dir).Unit

		local col
		if t < 0.35 then
			col = lerpColor(COL.hornBase, COL.hornMid, t / 0.35)
		else
			col = lerpColor(COL.hornMid, COL.hornTip, (t - 0.35) / 0.65)
		end

		makePart(parent, {
			Name = "HornSeg",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(segLen, diam, diam),
			CFrame = CFrame.fromMatrix(wMid, dir, yAxis, zAxis),
			Color = col,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
		makePart(parent, {
			Name = "HornJoint",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(diam, diam, diam),
			Position = w2,
			Color = col,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
		prev = cur
	end
end

local function buildDarkTotem(parent, baseCF: CFrame)
	local m = Instance.new("Model")
	m.Name = "TotemEscuro"
	makePart(m, {
		Name = "Coluna",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(10.5, 2.7, 2.7),
		CFrame = baseCF * CFrame.new(0, 5.25, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = COL.totemDark,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	makePart(m, {
		Name = "LotusBase",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3.4, 3.0, 3.4),
		CFrame = baseCF * CFrame.new(0, 11.0, 0),
		Color = COL.totemCap,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	makePart(m, {
		Name = "LotusTopo",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.1, 2.8, 2.1),
		CFrame = baseCF * CFrame.new(0, 12.1, 0),
		Color = COL.roofRidge,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})

	for _, br in ipairs({
		{ sx = -1, y = 9.2, ang = 58,  len = 5.8 },
		{ sx = -1, y = 9.9, ang = 34,  len = 3.6, offX = -2.0, offY = 1.1 },
		{ sx =  1, y = 9.0, ang = -60, len = 5.6 },
		{ sx =  1, y = 9.8, ang = -36, len = 3.5, offX =  1.9, offY = 1.0 },
	}) do
		makePart(m, {
			Name = "Galho",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(br.len, 0.36, 0.36),
			CFrame = baseCF
				* CFrame.new((br.offX or 0) + br.sx * (br.len * 0.42), br.y + (br.offY or 0), 0)
				* CFrame.Angles(0, 0, math.rad(br.ang) + math.pi / 2),
			Color = COL.totemDark,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
	end
	m.Parent = parent
	return m
end

local function buildMonumentalGate(parent, gateCF: CFrame)
	local gate = Instance.new("Model")
	gate.Name = "GrandePortaoSantuario"

	local portalW, portalH, bodyD = 16.6, 15.8, 12.0
	for _, sx in ipairs({ -1, 1 }) do
		makePart(gate, {
			Name = "PilarPrincipal",
			Size = Vector3.new(3.5, 18.8, bodyD),
			CFrame = gateCF * CFrame.new(sx * (portalW * 0.5 + 1.5), 9.4, 0),
			Color = COL.woodPillar,
			Material = Enum.Material.Wood,
			CanCollide = true,
		})
		makePart(gate, {
			Name = "MolduraEscura",
			Size = Vector3.new(0.9, 17.6, bodyD + 0.6),
			CFrame = gateCF * CFrame.new(sx * (portalW * 0.5 - 0.1), 8.8, 0),
			Color = COL.woodDark,
			Material = Enum.Material.Wood,
			CanCollide = false,
		})
	end
	makePart(gate, {
		Name = "VigaLintel",
		Size = Vector3.new(portalW + 7.8, 3.0, bodyD + 1.0),
		CFrame = gateCF * CFrame.new(0, 17.8, 0),
		Color = COL.woodPillar,
		Material = Enum.Material.Wood,
		CanCollide = false,
	})

	-- Interior Azul-Ciano Turquesa Saturado
	local cyanBack = makePart(gate, {
		Name = "PortalCianoFundo",
		Size = Vector3.new(portalW - 0.2, portalH + 1.2, 1.0),
		CFrame = gateCF * CFrame.new(0, 8.6, 1.8),
		Color = COL.cyanBright,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	local cyanDecal = Instance.new("Decal")
	cyanDecal.Face = Enum.NormalId.Front
	cyanDecal.Texture = M.TEX.CYAN_PORTAL
	cyanDecal.Parent = cyanBack

	makePart(gate, {
		Name = "PortalCianoDomo",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(portalW * 0.90, 7.6, 5.8),
		CFrame = gateCF * CFrame.new(0, 4.6, 1.2),
		Color = COL.cyanDeep,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})

	local cyanIllum = makePart(gate, {
		Name = "CyanInnerIllum",
		Size = Vector3.new(portalW - 1, portalH, 0.4),
		CFrame = gateCF * CFrame.new(0, 8.6, -2.5) * CFrame.Angles(0, math.pi, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local sl = Instance.new("SurfaceLight")
	sl.Face = Enum.NormalId.Front
	sl.Color = Color3.fromRGB(165, 255, 252)
	sl.Brightness = 3.2
	sl.Range = 14
	sl.Angle = 160
	sl.Shadows = false
	sl.Parent = cyanIllum

	for _, sx in ipairs({ -1, 1 }) do
		makePart(gate, {
			Name = "ParedeCiano",
			Size = Vector3.new(0.8, portalH + 1.2, 7.4),
			CFrame = gateCF * CFrame.new(sx * (portalW * 0.5 - 0.3), 8.6, -1.4),
			Color = COL.cyanDeep,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
	end

	-- 2. A Grande Boca Central
	buildJawArch(gate, gateCF * CFrame.new(0, 15.2, -5.2), 15.6, 2.3, 8, 2.9, 1.95, true)
	buildJawArch(gate, gateCF * CFrame.new(0,  2.2, -5.2), 15.2, 1.4, 8, 2.7, 1.90, false)

	-- 3. Bocas Laterais
	for _, sx in ipairs({ -1, 1 }) do
		local sideMouthCF = gateCF
			* CFrame.new(sx * 12.2, 8.8, -2.8)
			* CFrame.Angles(0, math.rad(-sx * 22), math.rad(-sx * 8))
		buildJawArch(gate, sideMouthCF * CFrame.new(0,  3.5, 0), 8.4, 1.2, 5, 2.2, 1.65, true)
		buildJawArch(gate, sideMouthCF * CFrame.new(0, -3.5, 0), 8.0, 1.0, 5, 2.0, 1.55, false)
	end

	-- 4. Marcenaria Kumimono
	for tierIdx, bSpec in ipairs({
		{ y = 19.6, w = 27.5, d = 15.5, h = 1.3 },
		{ y = 21.0, w = 32.0, d = 17.8, h = 1.3 },
		{ y = 22.4, w = 36.8, d = 20.2, h = 1.4 },
	}) do
		makePart(gate, {
			Name = "VigaKumimono" .. tierIdx,
			Size = Vector3.new(bSpec.w, bSpec.h, bSpec.d),
			CFrame = gateCF * CFrame.new(0, bSpec.y, -0.5),
			Color = if tierIdx % 2 == 1 then COL.woodDark else COL.woodPillar,
			Material = Enum.Material.Wood,
			CanCollide = false,
		})
		local nRafters = 13 + tierIdx * 2
		for r = 1, nRafters do
			local u = (r - (nRafters + 1) / 2) / ((nRafters - 1) / 2)
			makePart(gate, {
				Name = "Caibro",
				Size = Vector3.new(0.7, 0.7, bSpec.d + 1.5),
				CFrame = gateCF * CFrame.new(u * (bSpec.w * 0.46), bSpec.y - 0.28, -0.5),
				Color = COL.woodDark,
				Material = Enum.Material.Wood,
				CanCollide = false,
			})
		end
	end

	-- 5. Telhado Carmesim
	local roofMeshTemplate = mapaKit.Pavilhao:FindFirstChild("Roof_24365A", true)
	if roofMeshTemplate and roofMeshTemplate:IsA("MeshPart") then
		local mainRoof = roofMeshTemplate:Clone()
		mainRoof.Name = "TelhadoCarmesim"
		mainRoof.Anchored = true
		mainRoof.CanCollide = false
		mainRoof.CastShadow = false
		mainRoof.Color = COL.roofTile
		mainRoof.Material = Enum.Material.SmoothPlastic
		mainRoof.Size = Vector3.new(41.5, 8.2, 25.0)
		mainRoof.CFrame = gateCF * CFrame.new(0, 26.0, -0.6)
		mainRoof.Parent = gate

		local upperRoof = roofMeshTemplate:Clone()
		upperRoof.Name = "TelhadoSuperior"
		upperRoof.Anchored = true
		upperRoof.CanCollide = false
		upperRoof.CastShadow = false
		upperRoof.Color = COL.roofRidge
		upperRoof.Material = Enum.Material.SmoothPlastic
		upperRoof.Size = Vector3.new(25.5, 5.8, 16.5)
		upperRoof.CFrame = gateCF * CFrame.new(0, 30.0, -0.6)
		upperRoof.Parent = gate
	end

	for i = 1, 19 do
		local u = (i - 10) / 9
		makePart(gate, {
			Name = "TelhaGomo",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3.4, 1.1, 1.1),
			CFrame = gateCF * CFrame.new(u * 18.0, 23.9, -11.0) * CFrame.Angles(math.rad(18), math.pi / 2, 0),
			Color = COL.roofRidge,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
	end

	-- 6. Boca na Cumeeira + Chifres internos curvos para cima + Cranio de Touro no Pico
	for _, sx in ipairs({ -1, 1 }) do
		makePart(gate, {
			Name = "FrontaoBorda",
			Size = Vector3.new(8.8, 1.3, 2.4),
			CFrame = gateCF * CFrame.new(sx * 3.7, 29.4, -8.4) * CFrame.Angles(0, 0, math.rad(-sx * 32)),
			Color = COL.roofRidge,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
		buildUpwardTuskHorn(gate, gateCF, sx, Vector3.new(3.0, 29.5, -7.8), 2.4, 5.2, -0.8, 0.90)
	end
	buildJawArch(gate, gateCF * CFrame.new(0, 28.5, -8.8), 7.4, 1.0, 6, 1.35, 1.05, true)
	buildJawArch(gate, gateCF * CFrame.new(0, 26.0, -8.8), 7.2, 0.55, 6, 1.25, 1.0, false)

	placeSukunaModel("BullSkull", gateCF * CFrame.new(0, 32.2, -8.2), 1.15, gate, COL.boneTint)

	-- Cranios duplos pendurados nos beirais
	for _, sx in ipairs({ -1, 1 }) do
		makePart(gate, {
			Name = "CorrenteBeiral",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3.6, 0.16, 0.16),
			CFrame = gateCF * CFrame.new(sx * 17.8, 20.5, -9.2) * CFrame.Angles(0, 0, math.pi / 2),
			Color = COL.woodDark,
			Material = Enum.Material.Metal,
			CanCollide = false,
		})
		placeSukunaModel("HumanSkull", gateCF * CFrame.new(sx * 17.8, 17.4, -9.2) * CFrame.Angles(0, math.rad(-sx * 18), 0), 0.78, gate, COL.boneTint)
		placeSukunaModel("HumanSkull", gateCF * CFrame.new(sx * 17.6, 15.3, -9.1) * CFrame.Angles(math.rad(14), math.rad(sx * 22), 0), 0.68, gate, COL.boneTint)
	end

	-- 7. LEQUES DE CHIFRES CURVANDO PARA CIMA COMO PRESAS GIGANTES (igualzinho a silhueta da referencia!)
	for _, sx in ipairs({ -1, 1 }) do
		for _, hSpec in ipairs({
			{ pos = Vector3.new( 6.0, 25.8, -6.2), rx =  7.5, ry = 13.5, rz = -1.2, r = 1.95 },
			{ pos = Vector3.new( 8.6, 25.0, -5.0), rx = 12.2, ry = 14.8, rz = -0.8, r = 2.25 },
			{ pos = Vector3.new(11.4, 24.4, -4.2), rx = 14.5, ry = 12.2, rz =  0.4, r = 2.00 },
			{ pos = Vector3.new( 7.2, 26.8, -3.4), rx =  5.4, ry = 11.2, rz =  1.2, r = 1.65 },
			{ pos = Vector3.new(12.8, 23.8, -5.6), rx = 11.5, ry =  8.6, rz = -1.8, r = 1.55 },
		}) do
			buildUpwardTuskHorn(gate, gateCF, sx, hSpec.pos, hSpec.rx, hSpec.ry, hSpec.rz, hSpec.r)
		end
	end

	-- 8. Totens negros com galhos secos
	for _, sx in ipairs({ -1, 1 }) do
		buildDarkTotem(gate, gateCF * CFrame.new(sx * 16.4, 0.0, -9.8))
	end

	-- 9. Cranios de Touro semi-submersos + Maos Esqueleticas (pulso submerso, dedos agarrando os cranios!)
	for _, sk in ipairs({
		{ x = -21.5, y = -2.4, z = -11.5, sc = 1.55, yaw = -40, pitch = 16 },
		{ x = -14.2, y = -1.9, z = -12.8, sc = 1.72, yaw = -24, pitch = 10 },
		{ x =  -8.2, y = -2.5, z = -13.2, sc = 1.48, yaw = -14, pitch = 18 },
		{ x =   8.2, y = -2.5, z = -13.2, sc = 1.48, yaw =  14, pitch = 18 },
		{ x =  14.2, y = -1.9, z = -12.8, sc = 1.72, yaw =  24, pitch = 10 },
		{ x =  21.5, y = -2.4, z = -11.5, sc = 1.55, yaw =  40, pitch = 16 },
		{ x = -25.5, y = -2.9, z =  -7.5, sc = 1.38, yaw = -58, pitch = 18 },
		{ x =  25.5, y = -2.9, z =  -7.5, sc = 1.38, yaw =  58, pitch = 18 },
	}) do
		local scf = gateCF
			* CFrame.new(sk.x, sk.y, sk.z)
			* CFrame.Angles(math.rad(sk.pitch), math.rad(sk.yaw), 0)
		placeSukunaModel("BullSkull", scf, sk.sc, gate, COL.boneTint)

		local hornGlow = makePart(gate, {
			Name = "LuzCranioLaranja",
			Size = Vector3.new(0.5, 0.5, 0.5),
			CFrame = scf * CFrame.new(0, 4.8, -1.5),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		local pl = Instance.new("PointLight")
		pl.Color = COL.hornOrange
		pl.Brightness = 1.55
		pl.Range = 13
		pl.Shadows = false
		pl.Parent = hornGlow
	end

	-- Maos esqueleticas inclinadas para tras (+34 graus) com pulso submerso e dedos subindo sobre os cranios!
	if sukunaKit:FindFirstChild("BoneHand") then
		for _, bh in ipairs({
			{ x = -16.2, y = -1.7, z = -14.8, sc = 1.45, yaw = 158, pitch = 32 },
			{ x =  -9.8, y = -1.9, z = -14.9, sc = 1.32, yaw = 170, pitch = 30 },
			{ x =   9.8, y = -1.9, z = -14.9, sc = 1.32, yaw = -170,pitch = 30 },
			{ x =  16.2, y = -1.7, z = -14.8, sc = 1.45, yaw = -158,pitch = 32 },
		}) do
			local hcf = gateCF
				* CFrame.new(bh.x, bh.y, bh.z)
				* CFrame.Angles(math.rad(bh.pitch), math.rad(bh.yaw), 0)
			placeSukunaModel("BoneHand", hcf, bh.sc, gate, COL.boneTint)
		end
	end

	local frontLightPart = makePart(gate, {
		Name = "ShrineFrontKeyLight",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.lookAt(
			(gateCF * CFrame.new(0, 19, -34)).Position,
			(gateCF * CFrame.new(0, 15, 0)).Position
		),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local spot = Instance.new("SpotLight")
	spot.Color = Color3.fromRGB(255, 196, 198)
	spot.Brightness = 2.1
	spot.Range = 58
	spot.Angle = 70
	spot.Face = Enum.NormalId.Front
	spot.Shadows = false
	spot.Parent = frontLightPart

	gate.Parent = parent
	return gate
end

-- Constroi um Altar/Pedestal Amaldicoado emergindo da agua (topo exato em floorY para os pes dos personagens!)
local function buildCursedPedestal(parent, centerXZ: Vector3, yawRad: number, mainDiam: number, waterY: number, floorY: number, withDetails: boolean)
	local m = Instance.new("Model")
	m.Name = if withDetails then "AltarCombate" else "AltarApoio"
	local px, pz = centerXZ.X, centerXZ.Z

	-- 1. Degrau inferior de basalto negro submerso na linha d'agua
	makePart(m, {
		Name = "BaseObsidiana",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.55, mainDiam + 2.6, mainDiam + 2.6),
		CFrame = CFrame.new(px, waterY - 0.08, pz) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(22, 5, 10),
		Material = Enum.Material.Slate,
		CanCollide = true,
	})

	-- 2. Degrau intermediario laqueado em vermelho-santuario
	makePart(m, {
		Name = "DegrauCarmesim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.48, mainDiam + 1.1, mainDiam + 1.1),
		CFrame = CFrame.new(px, waterY + 0.18, pz) * CFrame.Angles(0, 0, math.pi / 2),
		Color = COL.roofTile,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
	})

	-- 3. Plataforma principal de pedra escura do templo (topo EXATO em floorY!)
	local topH = (floorY - waterY) + 0.15
	makePart(m, {
		Name = "TopoAltar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(topH, mainDiam, mainDiam),
		CFrame = CFrame.new(px, floorY - topH * 0.5, pz) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(30, 8, 15),
		Material = Enum.Material.Slate,
		CanCollide = true,
	})

	-- 4. Filete luminoso azul-ciano embutido na borda superior (combinando com a boca do Santuario!)
	makePart(m, {
		Name = "FrisoCiano",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.08, mainDiam + 0.16, mainDiam + 0.16),
		CFrame = CFrame.new(px, floorY - 0.11, pz) * CFrame.Angles(0, 0, math.pi / 2),
		Color = COL.cyanBright,
		Material = Enum.Material.Neon,
		Transparency = 0.20,
		CanCollide = false,
	})

	-- 5. Selo Amaldicoado do Sukuna gravado no topo do altar (levemente acima do topo para nitidez total em angulos rasos!)
	local sealPlate = makePart(m, {
		Name = "SeloAmaldicoado",
		Size = Vector3.new(mainDiam * 0.90, 0.02, mainDiam * 0.90),
		CFrame = CFrame.new(px, floorY + 0.012, pz) * CFrame.Angles(0, yawRad, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local sealDecal = Instance.new("Decal")
	sealDecal.Face = Enum.NormalId.Top
	sealDecal.Texture = M.TEX.PEDESTAL_SEAL
	sealDecal.Transparency = 0.06
	sealDecal.Parent = sealPlate

	if withDetails then
		-- 4 travas de madeira carmesim do templo + 4 pequenos cranios na linha d'agua ao redor da base
		for k = 1, 4 do
			local a1 = yawRad + (k - 1) * (math.pi / 2)
			local bx = px + math.cos(a1) * (mainDiam * 0.5 + 0.45)
			local bz = pz + math.sin(a1) * (mainDiam * 0.5 + 0.45)
			makePart(m, {
				Name = "TravaTemplo" .. k,
				Size = Vector3.new(1.1, 0.46, 1.5),
				CFrame = CFrame.lookAt(Vector3.new(bx, floorY - 0.24, bz), Vector3.new(px, floorY - 0.24, pz)),
				Color = COL.woodDark,
				Material = Enum.Material.Wood,
				CanCollide = false,
			})

			local a2 = a1 + math.pi / 4
			local sx = px + math.cos(a2) * (mainDiam * 0.5 + 0.95)
			local sz = pz + math.sin(a2) * (mainDiam * 0.5 + 0.95)
			local skCF = CFrame.lookAt(Vector3.new(sx, waterY - 0.22, sz), Vector3.new(sx + math.cos(a2), waterY - 0.22, sz + math.sin(a2)))
			placeSukunaModel("HumanSkull", skCF, 0.45, m, COL.boneTint)
		end

		-- Ondas suaves saindo da base do altar na agua + iluminacao suave sobre o selo e o lutador
		local rippleHolder = makePart(m, {
			Name = "AltarWaterRipple",
			Size = Vector3.new(0.4, 0.1, 0.4),
			Position = Vector3.new(px, waterY + 0.07, pz),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "OndaBaseAltar"
		pe.Texture = M.TEX.VFX_RIPPLE
		pe.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		pe.EmissionDirection = Enum.NormalId.Top
		pe.Speed = NumberRange.new(0.01, 0.02)
		pe.Color = ColorSequence.new(Color3.fromRGB(165, 252, 248), Color3.fromRGB(245, 150, 188))
		pe.LightEmission = 0.85
		pe.LightInfluence = 0
		pe.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, mainDiam * 0.54),
			NumberSequenceKeypoint.new(1, mainDiam * 0.82),
		})
		pe.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.85),
			NumberSequenceKeypoint.new(0.25, 0.38),
			NumberSequenceKeypoint.new(1, 1),
		})
		pe.Lifetime = NumberRange.new(2.6, 3.4)
		pe.Rate = 1.5
		pe.Parent = rippleHolder

		local topLit = makePart(m, {
			Name = "AltarTopLight",
			Size = Vector3.new(0.5, 0.5, 0.5),
			Position = Vector3.new(px, floorY + 5.0, pz),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		local pl = Instance.new("PointLight")
		pl.Color = Color3.fromRGB(235, 242, 255)
		pl.Brightness = 0.95
		pl.Range = 14
		pl.Shadows = false
		pl.Parent = topLit
	end

	m.Parent = parent
	return m
end

function M.buildArena(id: number, centerPos: Vector3): Model
	local arenasFolder = workspace:FindFirstChild("Arenas")
	if not arenasFolder then
		arenasFolder = Instance.new("Folder")
		arenasFolder.Name = "Arenas"
		arenasFolder.Parent = workspace
	end

	local arenaName = string.format("Arena%02d", id)
	local old = arenasFolder:FindFirstChild(arenaName)
	if old then
		old:Destroy()
	end

	local arena = Instance.new("Model")
	arena.Name = arenaName
	arena:SetAttribute("ArenaId", id)
	arena:SetAttribute("InUse", false)

	local cx, baseY, cz = centerPos.X, centerPos.Y, centerPos.Z
	local floorY = baseY + 0.5       -- 40.50: topo exato dos altares onde os personagens pisam!
	local waterY = floorY - 0.62     -- 39.88: lamina d'agua rasa abaixo do topo dos altares!

	--------------------------------------------------------------------
	-- 1. Pecas de Gameplay obrigatorias
	--------------------------------------------------------------------
	makePart(arena, {
		Name = "FloorMid",
		Size = Vector3.new(16, 1, 16),
		Position = Vector3.new(cx, baseY, cz),
		Transparency = 1,
		CanCollide = false,
	})
	for _, sx in ipairs({ -1, 1 }) do
		makePart(arena, {
			Name = "FloorEnd",
			Size = Vector3.new(4, 1, 4),
			Position = Vector3.new(cx + sx * 17, baseY, cz),
			Transparency = 1,
			CanCollide = false,
		})
		makePart(arena, {
			Name = "BaseEnd",
			Size = Vector3.new(4, 1, 4),
			Position = Vector3.new(cx + sx * 17, baseY - 1, cz),
			Transparency = 1,
			CanCollide = false,
		})
	end
	makePart(arena, {
		Name = "BaseMid",
		Size = Vector3.new(4, 1, 4),
		Position = Vector3.new(cx, baseY - 1, cz),
		Transparency = 1,
		CanCollide = false,
	})

	local playerPointPart = makePart(arena, {
		Name = "PlayerPoint",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.lookAt(Vector3.new(cx - 15, floorY + 3, cz), Vector3.new(cx + 15, floorY + 3, cz)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local enemyPointPart = makePart(arena, {
		Name = "EnemyPoint",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.lookAt(Vector3.new(cx + 15, floorY + 3, cz), Vector3.new(cx - 15, floorY + 3, cz)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})

	makePart(arena, {
		Name = "PlayerMark",
		Size = Vector3.new(1, 0.1, 1),
		Position = Vector3.new(cx - 15, floorY, cz),
		Transparency = 1,
		CanCollide = false,
	})
	makePart(arena, {
		Name = "EnemyMark",
		Size = Vector3.new(1, 0.1, 1),
		Position = Vector3.new(cx + 15, floorY, cz),
		Transparency = 1,
		CanCollide = false,
	})

	-- CameraPoint diagonal estilo Pokemon: adversario limpo a direita (u ~ +0.35) e Grande Portao livre ao fundo centro-esquerda (u ~ -0.16), zero sobreposicao!
	local camPosA  = Vector3.new(cx - 24.0, floorY + 6.3, cz + 8.5)
	local camLookA = Vector3.new(cx + 16.0, floorY + 5.2, cz - 12.2)
	makePart(arena, {
		Name = "CameraPoint",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.lookAt(camPosA, camLookA),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})

	arena.Parent = arenasFolder

	--------------------------------------------------------------------
	-- 2. Cenario da Expansao de Dominio
	--------------------------------------------------------------------
	local decor = Instance.new("Folder")
	decor.Name = "DomainDecor"

	local VAULT_R = 175
	local WALL_H  = 156

	local skyVault = Instance.new("Model")
	skyVault.Name = "SkyCloudPanorama"
	local N_PANELS = 24
	local panelW = 2 * VAULT_R * math.tan(math.pi / N_PANELS) + 1.2
	local tileW = panelW * 6

	for i = 1, N_PANELS do
		local a = ((i - 0.5) / N_PANELS) * math.pi * 2
		local wx = cx + math.cos(a) * VAULT_R
		local wz = cz + math.sin(a) * VAULT_R
		local pcf = CFrame.lookAt(
			Vector3.new(wx, floorY + WALL_H * 0.5 - 3, wz),
			Vector3.new(cx, floorY + WALL_H * 0.5 - 3, cz)
		)
		local wall = makePart(skyVault, {
			Name = "SkyPanel" .. i,
			Size = Vector3.new(panelW, WALL_H, 2),
			CFrame = pcf,
			Color = COL.skyHorizon,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = true,
			CastShadow = true,
		})
		local tex = Instance.new("Texture")
		tex.Name = "CloudPanoramaTex"
		tex.Face = Enum.NormalId.Front
		tex.Texture = M.TEX.SKY_CLOUDS
		tex.Color3 = Color3.fromRGB(148, 38, 44)
		tex.StudsPerTileU = tileW
		tex.StudsPerTileV = WALL_H
		tex.OffsetStudsU = ((i - 1) % 6) * panelW
		tex.Parent = wall
		makePart(skyVault, {
			Name = "HorizonSkirt" .. i,
			Size = Vector3.new(panelW + 1.5, 14.0, 3.5),
			CFrame = pcf * CFrame.new(0, -WALL_H * 0.5 + 7.0, -1.2),
			Color = Color3.fromRGB(2, 0, 1),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})

		-- Ilumina suavemente apenas o alto das nuvens rubras sombrias, mantendo o horizonte em escuridao abissal infinita!
		local litHolder = makePart(skyVault, {
			Name = "SkyIllum" .. i,
			Size = Vector3.new(panelW * 1.15, WALL_H * 0.58, 0.5),
			CFrame = pcf * CFrame.new(0, WALL_H * 0.18, -16) * CFrame.Angles(0, math.pi, 0),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		local sl = Instance.new("SurfaceLight")
		sl.Face = Enum.NormalId.Front
		sl.Color = Color3.fromRGB(172, 26, 36)
		sl.Brightness = 0.90
		sl.Range = 34
		sl.Angle = 165
		sl.Shadows = false
		sl.Parent = litHolder
	end

	makePart(skyVault, {
		Name = "SkyCeiling",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4, VAULT_R * 2 + 8, VAULT_R * 2 + 8),
		CFrame = CFrame.new(cx, floorY + WALL_H - 3, cz) * CFrame.Angles(0, 0, math.pi / 2),
		Color = COL.skyTop,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
		CastShadow = true,
	})
	skyVault.Parent = decor

	local BARRIER_R = 85
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2
		local bx = cx + math.cos(a) * BARRIER_R
		local bz = cz + math.sin(a) * BARRIER_R
		makePart(decor, {
			Name = "InvisibleBounds" .. i,
			Size = Vector3.new(72, 40, 2),
			CFrame = CFrame.lookAt(Vector3.new(bx, floorY + 20, bz), Vector3.new(cx, floorY + 20, cz)),
			Transparency = 1,
			CanCollide = true,
			CanQuery = false,
		})
	end

	-- B. Chao de Agua Rosa-Carmesim Opaco (em waterY = floorY - 0.62, abaixo do topo dos altares dos personagens!)
	makePart(decor, {
		Name = "WaterSolidFloor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.0, (VAULT_R + 4) * 2, (VAULT_R + 4) * 2),
		CFrame = CFrame.new(cx, waterY - 1.1, cz) * CFrame.Angles(0, 0, math.pi / 2),
		Color = COL.skyHorizon,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = true,
	})

	local camYaw = math.atan2(-(camLookA.Z - camPosA.Z), camLookA.X - camPosA.X)
	local waterTop = makePart(decor, {
		Name = "InfiniteMirrorWater",
		Size = Vector3.new(VAULT_R * 2.05, 0.14, VAULT_R * 2.05),
		CFrame = CFrame.new(cx, waterY - 0.06, cz) * CFrame.Angles(0, camYaw, 0),
		Color = Color3.fromRGB(68, 10, 16),
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0,
		Transparency = 0,
		CanCollide = true,
	})
	local rippleTex = Instance.new("Texture")
	rippleTex.Name = "PinkWaterRipples"
	rippleTex.Face = Enum.NormalId.Top
	rippleTex.Texture = M.TEX.WATER_RIPPLES
	rippleTex.Color3 = Color3.fromRGB(118, 22, 30)
	rippleTex.StudsPerTileU = 20
	rippleTex.StudsPerTileV = 34
	rippleTex.Transparency = 0.12
	rippleTex.ZIndex = 1
	rippleTex.Parent = waterTop

	-- Vinheta radial de abismo negro aplicada diretamente na superficie OPACA da agua (G-buffer: nunca corta particulas/VFX no horizonte!)
	local vigDecal = Instance.new("Decal")
	vigDecal.Name = "AbyssVignetteDecal"
	vigDecal.Face = Enum.NormalId.Top
	vigDecal.Texture = M.TEX.WATER_VIGNETTE
	vigDecal.Transparency = 0
	vigDecal.ZIndex = 2
	vigDecal.Parent = waterTop

	-- B2. ALTARES AMALDICOADOS ONDE OS PERSONAGENS SEMPRE FICAM EM CIMA (Lutadores + Avatares dos Jogadores!)
	local altarsFolder = Instance.new("Folder")
	altarsFolder.Name = "AltaresPersonagens"
	for _, pt in ipairs({
		{ part = playerPointPart, yaw = 0 },
		{ part = enemyPointPart,  yaw = math.pi },
	}) do
		-- Altar principal do lutador ativo (PlayerPoint / EnemyPoint)
		buildCursedPedestal(altarsFolder, pt.part.Position, pt.yaw, 7.8, waterY, floorY, true)

		-- Altar do treinador/avatar do jogador (posicao exata de ArenaManager.PlaceViewer: point.CFrame * CFrame.new(-5, 0, 8))
		local viewerPos = (pt.part.CFrame * CFrame.new(-5, 0, 8)).Position
		buildCursedPedestal(altarsFolder, viewerPos, pt.yaw, 4.8, waterY, floorY, false)

		-- Ponte ritual de pedra escura ligando o altar do jogador ao altar do lutador
		local midStep = viewerPos:Lerp(pt.part.Position, 0.46)
		makePart(altarsFolder, {
			Name = "PedraPassagem",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(floorY - waterY + 0.06, 2.2, 2.2),
			CFrame = CFrame.new(midStep.X, (floorY + waterY) * 0.5 - 0.08, midStep.Z) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(30, 8, 15),
			Material = Enum.Material.Slate,
			CanCollide = true,
		})
	end
	altarsFolder.Parent = decor

	local wLit = makePart(decor, {
		Name = "WaterPinkFill",
		Size = Vector3.new(130, 1, 130),
		CFrame = CFrame.new(cx, floorY + 15.5, cz) * CFrame.Angles(-math.pi / 2, 0, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local wsl = Instance.new("SurfaceLight")
	wsl.Face = Enum.NormalId.Front
	wsl.Color = Color3.fromRGB(162, 32, 42)
	wsl.Brightness = 0.42
	wsl.Range = 28
	wsl.Angle = 170
	wsl.Shadows = false
	wsl.Parent = wLit

	local centerLightHolder = makePart(decor, {
		Name = "CenterBattleLight",
		Size = Vector3.new(1, 1, 1),
		Position = Vector3.new(cx, floorY + 18, cz),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local centerLight = Instance.new("PointLight")
	centerLight.Color = Color3.fromRGB(238, 194, 198)
	centerLight.Brightness = 1.15
	centerLight.Range = 60
	centerLight.Shadows = false
	centerLight.Parent = centerLightHolder

	--------------------------------------------------------------------
	-- 2B. VFX AMBIENTE DO CENARIO (Ondas Vivas na Agua + Aura de Luz Flutuante + Nevoa de Seda)
	--     Nota (roblox-vfx): emissores com Shape Volume ficam DIRETO na Part (nunca em Attachment!)
	--------------------------------------------------------------------
	local vfxFolder = Instance.new("Folder")
	vfxFolder.Name = "DomainAuraVfx"

	-- Aneis de ondulacao rosas expandindo horizontalmente sobre o espelho d'agua
	local battleRipplesPart = makePart(vfxFolder, {
		Name = "WaterRippleVolume",
		Size = Vector3.new(115, 0.2, 95),
		Position = Vector3.new(cx, waterY + 0.08, cz),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local roseRipples = Instance.new("ParticleEmitter")
	roseRipples.Name = "OndasEspelhoRosa"
	roseRipples.Texture = M.TEX.VFX_RIPPLE
	roseRipples.Shape = Enum.ParticleEmitterShape.Box
	roseRipples.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	roseRipples.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	roseRipples.EmissionDirection = Enum.NormalId.Top
	roseRipples.Speed = NumberRange.new(0.02, 0.03)
	roseRipples.Color = ColorSequence.new(Color3.fromRGB(190, 48, 60), Color3.fromRGB(115, 16, 26))
	roseRipples.LightEmission = 0.45
	roseRipples.LightInfluence = 0
	roseRipples.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(0.55, 3.4),
		NumberSequenceKeypoint.new(1, 5.6),
	})
	roseRipples.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.36),
		NumberSequenceKeypoint.new(0.65, 0.65),
		NumberSequenceKeypoint.new(1, 1),
	})
	roseRipples.Lifetime = NumberRange.new(3.0, 4.4)
	roseRipples.Rate = 8
	roseRipples.Parent = battleRipplesPart

	-- Particulas de espirito/aura rosa-dourada e turquesa flutuando suavemente no ar
	local airAuraPart = makePart(vfxFolder, {
		Name = "AirSpiritAuraVolume",
		Size = Vector3.new(140, 24, 115),
		Position = Vector3.new(cx, floorY + 12, cz),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local spiritMotes = Instance.new("ParticleEmitter")
	spiritMotes.Name = "OrbesDeAuraRosa"
	spiritMotes.Texture = M.TEX.VFX_MOTE
	spiritMotes.Shape = Enum.ParticleEmitterShape.Box
	spiritMotes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	spiritMotes.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(235, 130, 140)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(185, 32, 48)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(115, 12, 22)),
	})
	spiritMotes.LightEmission = 0.65
	spiritMotes.LightInfluence = 0
	spiritMotes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.44),
		NumberSequenceKeypoint.new(0.75, 0.32),
		NumberSequenceKeypoint.new(1, 0),
	})
	spiritMotes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.18, 0.08),
		NumberSequenceKeypoint.new(0.82, 0.22),
		NumberSequenceKeypoint.new(1, 1),
	})
	spiritMotes.Lifetime = NumberRange.new(4.8, 7.2)
	spiritMotes.Rate = 24
	spiritMotes.Speed = NumberRange.new(0.6, 1.5)
	spiritMotes.EmissionDirection = Enum.NormalId.Top
	spiritMotes.SpreadAngle = Vector2.new(35, 35)
	spiritMotes.Rotation = NumberRange.new(-25, 25)
	spiritMotes.RotSpeed = NumberRange.new(-18, 18)
	spiritMotes.Parent = airAuraPart

	local cyanMotes = Instance.new("ParticleEmitter")
	cyanMotes.Name = "OrbesDeAuraCiano"
	cyanMotes.Texture = M.TEX.VFX_MOTE
	cyanMotes.Shape = Enum.ParticleEmitterShape.Box
	cyanMotes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	cyanMotes.Color = ColorSequence.new(Color3.fromRGB(180, 255, 252), Color3.fromRGB(68, 224, 235))
	cyanMotes.LightEmission = 1
	cyanMotes.LightInfluence = 0
	cyanMotes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.25, 0.35),
		NumberSequenceKeypoint.new(0.8, 0.24),
		NumberSequenceKeypoint.new(1, 0),
	})
	cyanMotes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.14),
		NumberSequenceKeypoint.new(0.8, 0.28),
		NumberSequenceKeypoint.new(1, 1),
	})
	cyanMotes.Lifetime = NumberRange.new(4.5, 6.8)
	cyanMotes.Rate = 9
	cyanMotes.Speed = NumberRange.new(0.5, 1.3)
	cyanMotes.SpreadAngle = Vector2.new(180, 40)
	cyanMotes.Parent = airAuraPart

	-- Veu de nevoa de seda rosada deslizando rente a agua
	local silkMistPart = makePart(vfxFolder, {
		Name = "WaterSilkMistVolume",
		Size = Vector3.new(160, 2.2, 135),
		Position = Vector3.new(cx, floorY + 1.2, cz),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local silkMist = Instance.new("ParticleEmitter")
	silkMist.Name = "NevoaSedaRosa"
	silkMist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	silkMist.Shape = Enum.ParticleEmitterShape.Box
	silkMist.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	silkMist.Color = ColorSequence.new(Color3.fromRGB(132, 24, 34), Color3.fromRGB(68, 8, 16))
	silkMist.LightEmission = 0.10
	silkMist.LightInfluence = 0
	silkMist.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 5.5),
		NumberSequenceKeypoint.new(0.5, 8.5),
		NumberSequenceKeypoint.new(1, 10.5),
	})
	silkMist.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.87),
		NumberSequenceKeypoint.new(0.7, 0.88),
		NumberSequenceKeypoint.new(1, 1),
	})
	silkMist.Lifetime = NumberRange.new(5.5, 8.0)
	silkMist.Rate = 9
	silkMist.Speed = NumberRange.new(0.5, 1.4)
	silkMist.SpreadAngle = Vector2.new(180, 6)
	silkMist.Parent = silkMistPart

	vfxFolder.Parent = decor

	--------------------------------------------------------------------
	-- 3. DOIS GRANDES PORTOES SIMETRICOS EM 180 GRAUS + REFLEXOS CORRETAMENTE ORIENTADOS SOB O PORTAO!
	--------------------------------------------------------------------
	for _, side in ipairs({ 1, -1 }) do
		local sideFolder = Instance.new("Folder")
		sideFolder.Name = if side == 1 then "GrandePortaoLeste" else "GrandePortaoOeste"

		local rootCF = CFrame.new(cx, waterY, cz) * CFrame.Angles(0, if side == 1 then 0 else math.pi, 0)
		-- Deslocado lateralmente (x = 70, z = -54) para deixar o adversario 100% livre na direita e o Grande Portao imponente ao lado!
		local gateWorldPos   = rootCF:PointToWorldSpace(Vector3.new(70, 0, -54.0))
		local viewerWorldPos = rootCF:PointToWorldSpace(Vector3.new(-24.0, 0, 8.5))
		local gateCF = CFrame.lookAt(gateWorldPos, viewerWorldPos)

		buildMonumentalGate(sideFolder, gateCF)

		-- Reflexo liquido em parte OPACA rente a agua (evita Z-sorting sobre particulas!)
		local reflPlane = makePart(sideFolder, {
			Name = "WaterSurfaceReflection",
			Size = Vector3.new(54, 0.05, 39),
			CFrame = gateCF * CFrame.new(0, -0.01, -27.0) * CFrame.Angles(0, math.pi, 0),
			Color = Color3.fromRGB(68, 10, 16),
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0,
			CanCollide = false,
			CanQuery = false,
		})
		local reflDecal = Instance.new("Decal")
		reflDecal.Name = "LiquidReflectionDecal"
		reflDecal.Face = Enum.NormalId.Top
		reflDecal.Texture = M.TEX.WATER_REFLECTION
		reflDecal.Color3 = Color3.fromRGB(165, 68, 76)
		reflDecal.Transparency = 0.14
		reflDecal.Parent = reflPlane

		local reflCyanGlow = makePart(sideFolder, {
			Name = "WaterCyanGlowLight",
			Size = Vector3.new(1, 1, 1),
			CFrame = gateCF * CFrame.new(0, 2.2, -21),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		local rpl = Instance.new("PointLight")
		rpl.Color = Color3.fromRGB(110, 248, 245)
		rpl.Brightness = 1.65
		rpl.Range = 22
		rpl.Shadows = false
		rpl.Parent = reflCyanGlow

		-- D. VFX DE AURA DO GRANDE PORTAO (Portal Ciano Vivo + Feixes de Energia + Brasas nos Cranios + Aura nos Chifres + Ondas Ciano!)
		-- 1) Aura e feixes fluindo de dentro da Grande Boca Ciano
		local portalVfxBox = makePart(sideFolder, {
			Name = "PortalCyanAuraVfx",
			Size = Vector3.new(13.5, 11.5, 3.5),
			CFrame = gateCF * CFrame.new(0, 8.6, -3.4),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		local portalWisps = Instance.new("ParticleEmitter")
		portalWisps.Name = "FiosEnergiaCiano"
		portalWisps.Texture = M.TEX.VFX_WISP
		portalWisps.Shape = Enum.ParticleEmitterShape.Box
		portalWisps.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		portalWisps.Orientation = Enum.ParticleOrientation.VelocityParallel
		portalWisps.Color = ColorSequence.new(Color3.fromRGB(195, 255, 252), Color3.fromRGB(52, 218, 232))
		portalWisps.LightEmission = 1
		portalWisps.LightInfluence = 0
		portalWisps.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(0.4, 1.25),
			NumberSequenceKeypoint.new(1, 0),
		})
		portalWisps.Squash = NumberSequence.new(0.35)
		portalWisps.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.18),
			NumberSequenceKeypoint.new(0.8, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		portalWisps.Lifetime = NumberRange.new(1.8, 3.0)
		portalWisps.Rate = 12
		portalWisps.Speed = NumberRange.new(2.4, 4.6)
		portalWisps.EmissionDirection = Enum.NormalId.Front
		portalWisps.SpreadAngle = Vector2.new(28, 36)
		portalWisps.Acceleration = Vector3.new(0, 2.6, 0)
		portalWisps.Parent = portalVfxBox

		local portalOrbs = Instance.new("ParticleEmitter")
		portalOrbs.Name = "ParticulasPortalCiano"
		portalOrbs.Texture = M.TEX.VFX_MOTE
		portalOrbs.Shape = Enum.ParticleEmitterShape.Box
		portalOrbs.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		portalOrbs.Color = ColorSequence.new(Color3.fromRGB(210, 255, 254), Color3.fromRGB(75, 235, 242))
		portalOrbs.LightEmission = 1
		portalOrbs.LightInfluence = 0
		portalOrbs.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.25, 0.52),
			NumberSequenceKeypoint.new(0.75, 0.34),
			NumberSequenceKeypoint.new(1, 0),
		})
		portalOrbs.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.1),
			NumberSequenceKeypoint.new(0.85, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		portalOrbs.Lifetime = NumberRange.new(2.6, 4.2)
		portalOrbs.Rate = 16
		portalOrbs.Speed = NumberRange.new(1.5, 3.2)
		portalOrbs.EmissionDirection = Enum.NormalId.Front
		portalOrbs.SpreadAngle = Vector2.new(35, 45)
		portalOrbs.Acceleration = Vector3.new(0, 1.8, 0)
		portalOrbs.Parent = portalVfxBox

		-- 2) Feixes (Beams) etereos ondulando suavemente dentro da boca ciano
		for bIdx, bCfg in ipairs({
			{ x0 = -5.2, y0 = 4.2, x1 =  5.2, y1 = 12.6, c0 =  3.5, c1 = -3.5, spd =  0.42 },
			{ x0 =  5.2, y0 = 4.6, x1 = -5.2, y1 = 12.2, c0 = -3.2, c1 =  3.2, spd = -0.36 },
		}) do
			local a0 = Instance.new("Attachment")
			a0.Name = "BeamA" .. bIdx
			a0.Position = Vector3.new(bCfg.x0, bCfg.y0 - 8.6, 1.2)
			a0.CFrame = CFrame.new(a0.Position) * CFrame.Angles(0, 0, math.rad(25))
			a0.Parent = portalVfxBox

			local a1 = Instance.new("Attachment")
			a1.Name = "BeamB" .. bIdx
			a1.Position = Vector3.new(bCfg.x1, bCfg.y1 - 8.6, 0.4)
			a1.CFrame = CFrame.new(a1.Position) * CFrame.Angles(0, 0, math.rad(-25))
			a1.Parent = portalVfxBox

			local bm = Instance.new("Beam")
			bm.Name = "CorrenteCiano" .. bIdx
			bm.Attachment0 = a0
			bm.Attachment1 = a1
			bm.Texture = M.TEX.VFX_WISP
			bm.TextureMode = Enum.TextureMode.Wrap
			bm.TextureLength = 6
			bm.TextureSpeed = bCfg.spd
			bm.Color = ColorSequence.new(Color3.fromRGB(180, 255, 252), Color3.fromRGB(80, 238, 245))
			bm.LightEmission = 1
			bm.LightInfluence = 0
			bm.Width0 = 1.6
			bm.Width1 = 1.6
			bm.CurveSize0 = bCfg.c0
			bm.CurveSize1 = bCfg.c1
			bm.Segments = 20
			bm.FaceCamera = true
			bm.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.25, 0.55),
				NumberSequenceKeypoint.new(0.75, 0.55),
				NumberSequenceKeypoint.new(1, 1),
			})
			bm.Parent = portalVfxBox
		end

		-- 3) Ondas circulares ciano brilhantes sobre o reflexo da boca na agua!
		local cyanRipplePad = makePart(sideFolder, {
			Name = "PortalWaterRipplesVfx",
			Size = Vector3.new(18, 0.2, 24),
			CFrame = gateCF * CFrame.new(0, 0.09, -22),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		local cyanRipples = Instance.new("ParticleEmitter")
		cyanRipples.Name = "OndasReflexoCiano"
		cyanRipples.Texture = M.TEX.VFX_RIPPLE
		cyanRipples.Shape = Enum.ParticleEmitterShape.Box
		cyanRipples.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		cyanRipples.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		cyanRipples.EmissionDirection = Enum.NormalId.Top
		cyanRipples.Speed = NumberRange.new(0.02, 0.03)
		cyanRipples.Color = ColorSequence.new(Color3.fromRGB(175, 255, 252), Color3.fromRGB(85, 232, 242))
		cyanRipples.LightEmission = 0.95
		cyanRipples.LightInfluence = 0
		cyanRipples.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.0),
			NumberSequenceKeypoint.new(0.5, 4.2),
			NumberSequenceKeypoint.new(1, 6.8),
		})
		cyanRipples.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.18, 0.28),
			NumberSequenceKeypoint.new(0.7, 0.62),
			NumberSequenceKeypoint.new(1, 1),
		})
		cyanRipples.Lifetime = NumberRange.new(2.6, 3.8)
		cyanRipples.Rate = 4
		cyanRipples.Parent = cyanRipplePad

		-- 4) Brasas alaranjadas/rubras subindo dos cranios de touro na linha d'agua
		for _, sx in ipairs({ -1, 1 }) do
			local skullAuraBox = makePart(sideFolder, {
				Name = "SkullEmberAura" .. (sx == 1 and "R" or "L"),
				Size = Vector3.new(18, 3.5, 7),
				CFrame = gateCF * CFrame.new(sx * 15, 1.4, -12.5),
				Transparency = 1,
				CanCollide = false,
				CanQuery = false,
			})
			local skullEmbers = Instance.new("ParticleEmitter")
			skullEmbers.Name = "BrasasCranios"
			skullEmbers.Texture = M.TEX.VFX_EMBER
			skullEmbers.Shape = Enum.ParticleEmitterShape.Box
			skullEmbers.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			skullEmbers.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 135)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 88, 52)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(205, 20, 62)),
			})
			skullEmbers.LightEmission = 1
			skullEmbers.LightInfluence = 0
			skullEmbers.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.2, 0.34),
				NumberSequenceKeypoint.new(0.8, 0.22),
				NumberSequenceKeypoint.new(1, 0),
			})
			skullEmbers.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.15, 0.08),
				NumberSequenceKeypoint.new(0.85, 0.25),
				NumberSequenceKeypoint.new(1, 1),
			})
			skullEmbers.Lifetime = NumberRange.new(2.4, 4.0)
			skullEmbers.Rate = 12
			skullEmbers.Speed = NumberRange.new(1.8, 3.6)
			skullEmbers.EmissionDirection = Enum.NormalId.Top
			skullEmbers.SpreadAngle = Vector2.new(22, 22)
			skullEmbers.Parent = skullAuraBox
		end

		-- 5) Aura mistica carmesim-lavanda subindo dos grandes leques de chifres no topo do telhado
		local crownAuraBox = makePart(sideFolder, {
			Name = "CrownHornAuraVfx",
			Size = Vector3.new(36, 9, 7),
			CFrame = gateCF * CFrame.new(0, 31.5, -5.5),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		local hornWisps = Instance.new("ParticleEmitter")
		hornWisps.Name = "AuraChifresSantuario"
		hornWisps.Texture = M.TEX.VFX_WISP
		hornWisps.Shape = Enum.ParticleEmitterShape.Box
		hornWisps.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		hornWisps.Orientation = Enum.ParticleOrientation.VelocityParallel
		hornWisps.Color = ColorSequence.new(Color3.fromRGB(248, 205, 232), Color3.fromRGB(220, 28, 72))
		hornWisps.LightEmission = 0.92
		hornWisps.LightInfluence = 0
		hornWisps.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(0.45, 1.55),
			NumberSequenceKeypoint.new(1, 0),
		})
		hornWisps.Squash = NumberSequence.new(0.3)
		hornWisps.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.25, 0.36),
			NumberSequenceKeypoint.new(0.75, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		})
		hornWisps.Lifetime = NumberRange.new(2.2, 3.6)
		hornWisps.Rate = 15
		hornWisps.Speed = NumberRange.new(2.2, 4.4)
		hornWisps.EmissionDirection = Enum.NormalId.Top
		hornWisps.SpreadAngle = Vector2.new(24, 18)
		hornWisps.Parent = crownAuraBox

		sideFolder.Parent = decor
	end

	decor.Parent = arena
	return arena
end

return M
