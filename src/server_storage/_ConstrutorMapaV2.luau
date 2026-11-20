--[[
	Construtor do mapa v2 (so Edit/Studio). Remonta torre, loja, cura, estrelas, placares, decoracao,
	bases e Refugios a partir de ServerStorage/MapaV2Kit. Regra do kit: a frente de cada modelo e o +Z do
	ponto de giro; place() vira a frente para "facing".
]]
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local kit = SS.MapaV2Kit
local C = {}

local IMG = { glow = 135255086148920, sparkle = 117703775594396, ring = 106813072869220, petal = 130564513029602, ember = 93633042519778 }
local function tex(k) return "rbxassetid://" .. IMG[k] end
C.tex = tex
local NS, NK = NumberSequence.new, NumberSequenceKeypoint.new

function C.part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end
local part = C.part

function C.label(m, label)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and p:GetAttribute("Label") == label then
			return p
		end
	end
end

-- facing: direcao para onde a frente aponta (plano XZ)
function C.place(name, pos, facing, scale, parent, newName)
	local m = kit[name]:Clone()
	if scale and scale ~= 1 then
		m:ScaleTo(scale)
	end
	facing = (facing * Vector3.new(1, 0, 1)).Unit
	m:PivotTo(CFrame.lookAt(pos, pos - facing))
	m.Name = newName or name
	m.Parent = parent
	return m
end
local place = C.place

function C.light(m, label, color, range, bright)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and p:GetAttribute("Label") == label then
			local l = Instance.new("PointLight")
			l.Name = "Luz"
			l.Color = color
			l.Range = range
			l.Brightness = bright
			l.Shadows = false
			l.Parent = p
			CS:AddTag(l, "MapFx")
			CS:AddTag(p, "Lanterna")
		end
	end
end
local light = C.light

function C.emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = parent
	CS:AddTag(e, "MapFx")
	return e
end

-- Area livre? (nada de esteira, caminho, praca, piso de base ou predio por baixo)
local blockers = {}
function C.setBlockers(list)
	blockers = list
end
function C.free(cf: CFrame, size: Vector3)
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	op.FilterDescendantsInstances = blockers
	op.RespectCanCollide = false
	-- geometria real (discos da praca nao viram quadrados)
	local probe = Instance.new("Part")
	probe.Anchored = true
	probe.CanCollide = false
	probe.Size = Vector3.new(size.X, 6, size.Z)
	probe.CFrame = cf
	probe.Parent = workspace
	local hits = workspace:GetPartsInPart(probe, op)
	probe:Destroy()
	return #hits == 0
end

-- decoracao com checagem: tenta o ponto, depois anda em direcao a "toward"; se nao achar lugar, nao poe
function C.decor(name, pos, facing, scale, parent, toward, footprint)
	local m = place(name, pos, facing, scale, nil)
	local function ok()
		local cf, sz = m:GetBoundingBox()
		local fp = footprint or Vector3.new(sz.X, 1, sz.Z)
		return C.free(CFrame.new(cf.Position.X, 9, cf.Position.Z), fp)
	end
	if ok() then
		m.Parent = parent
		return m
	end
	local dir = toward and ((toward - pos) * Vector3.new(1, 0, 1)) or nil
	if dir and dir.Magnitude > 0.1 then
		dir = dir.Unit
		for i = 1, 8 do
			m:PivotTo(m:GetPivot() + dir * 2.5)
			if ok() then
				m.Parent = parent
				return m
			end
		end
	else
		-- sem direcao: procura em volta do ponto, do mais perto ao mais longe
		local start = m:GetPivot()
		for r = 3, 18, 3 do
			for k = 0, 11 do
				local a = k / 12 * math.pi * 2
				m:PivotTo(start + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
				if ok() then
					m.Parent = parent
					return m
				end
			end
		end
	end
	m:Destroy()
	return nil
end

function C.rdir(R)
	local a = R:NextNumber(0, math.pi * 2)
	return Vector3.new(math.cos(a), 0, math.sin(a))
end

--------------------------------------------------------------------
-- Estrela (portal)
--------------------------------------------------------------------
function C.star(parent, id, x, z, col, col2, title)
	local m = Instance.new("Model")
	m.Name = "Portal" .. id
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = parent
	m:SetAttribute("Portal", id)
	local base = part(m, { Name = "Base", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 12, 12), CFrame = CFrame.new(x, 9, z) * CFrame.Angles(0, 0, math.pi / 2), Material = Enum.Material.Slate, MaterialVariant = "PedraPraca", Color = Color3.fromRGB(150, 138, 130) })
	part(m, { Name = "Aro", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 12.8, 12.8), CFrame = CFrame.new(x, 9.85, z) * CFrame.Angles(0, 0, math.pi / 2), Material = Enum.Material.Metal, Color = Color3.fromRGB(230, 184, 74), CanQuery = false })
	local rune = part(m, { Name = "Runa", Size = Vector3.new(11, 0.1, 11), CFrame = CFrame.new(x, 10.08, z), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	local d = Instance.new("Decal")
	d.Name = "RunaDecal"
	d.Face = Enum.NormalId.Top
	d.Texture = tex("ring")
	d.Color3 = col
	d.Transparency = 0.1
	d.Parent = rune
	CS:AddTag(d, "MapFx")
	-- estrela: o centro geometrico fica exatamente sobre o eixo
	local s = kit.Estrela:Clone()
	s:ScaleTo(1.6)
	local cf0 = s:GetBoundingBox()
	local center = Vector3.new(x, 20, z)
	s:PivotTo(s:GetPivot() + (center - cf0.Position))
	-- estrela de uma cor so (sem miolo branco)
	local body = s:FindFirstChildWhichIsA("MeshPart")
	body.Name = "Core"
	body.Color = col
	body.Material = Enum.Material.Neon
	body.Parent = m
	s:Destroy()
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	m:SetAttribute("StarCenter", center)
	-- ponto no centro da estrela (luz, brilho, feixe)
	local ca = Instance.new("Attachment")
	ca.Name = "Centro"
	ca.WorldPosition = center
	ca.Parent = body
	ca.WorldPosition = center
	local glow = Instance.new("PointLight")
	glow.Name = "Glow"
	glow.Color = col
	glow.Brightness = 1.5
	glow.Range = 16
	glow.Shadows = false
	glow.Parent = body
	CS:AddTag(glow, "MapFx")
	local bb = Instance.new("BillboardGui")
	bb.Name = "Halo"
	bb.Adornee = body
	bb.Size = UDim2.fromScale(20, 20)
	bb.LightInfluence = 0
	bb.Brightness = 1.6
	bb.MaxDistance = 400
	bb.StudsOffsetWorldSpace = center - body.Position
	bb.Parent = body
	local im = Instance.new("ImageLabel")
	im.Size = UDim2.fromScale(1, 1)
	im.BackgroundTransparency = 1
	im.Image = tex("glow")
	im.ImageColor3 = col
	im.ImageTransparency = 0.45
	im.Parent = bb
	CS:AddTag(bb, "MapFx")
	C.emitter(ca, { Name = "Brilhos", Texture = tex("sparkle"), Color = ColorSequence.new(Color3.new(1, 1, 1), col2), LightEmission = 1, Rate = 10, Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(180, 180), Size = NS({ NK(0, 0), NK(0.2, 1), NK(1, 0) }), Transparency = NS(0.1, 1), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90) })
	local a2 = Instance.new("Attachment")
	a2.Name = "ChaoFx"
	a2.CFrame = CFrame.new(1.2, 0, 0)
	a2.Parent = base
	C.emitter(a2, { Name = "Subindo", Texture = tex("glow"), Color = ColorSequence.new(col), LightEmission = 1, Rate = 6, Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(3, 5), EmissionDirection = Enum.NormalId.Right, Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, Size = NS({ NK(0, 0.6), NK(1, 0) }), Transparency = NS(0.2, 1) })
	-- feixe fino, do centro da base ao centro da estrela
	local b0 = Instance.new("Attachment")
	b0.Name = "Feixe0"
	b0.CFrame = CFrame.new(1.1, 0, 0)
	b0.Parent = base
	local beam = Instance.new("Beam")
	beam.Name = "Feixe"
	beam.Attachment0 = b0
	beam.Attachment1 = ca
	beam.Texture = tex("glow")
	beam.Color = ColorSequence.new(col)
	beam.LightEmission = 1
	beam.Transparency = NS({ NK(0, 0.35), NK(1, 0.8) })
	beam.Width0 = 1.2
	beam.Width1 = 0.5
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Parent = base
	CS:AddTag(beam, "MapFx")
	-- nome em cima
	local tag = Instance.new("BillboardGui")
	tag.Name = "Nome"
	tag.Adornee = base
	tag.Size = UDim2.fromOffset(260, 60)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 18.5, 0)
	tag.MaxDistance = 140
	tag.LightInfluence = 0
	tag.Parent = base
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Font = Enum.Font.FredokaOne
	tl.TextScaled = true
	tl.Text = title
	tl.TextColor3 = col2
	tl.Parent = tag
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Color = Color3.fromRGB(26, 18, 51)
	st.Parent = tl
	-- prompt
	local pp = Instance.new("Attachment")
	pp.Name = "PromptPoint"
	pp.CFrame = CFrame.new(3, 0, 0)
	pp.Parent = base
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "SummonPrompt"
	pr.ActionText = "Invocar"
	pr.ObjectText = title
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 14
	pr.RequiresLineOfSight = false
	pr:SetAttribute("Portal", id)
	pr.Parent = pp
	CS:AddTag(m, "MapStar")
	m.PrimaryPart = base
	return m
end

--------------------------------------------------------------------
-- Placar
--------------------------------------------------------------------
function C.board(parent, name, title, pos, facing, accent)
	local m = place("Placar", pos, facing, 1, parent, name)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local panel = C.label(m, "Panel")
	local gold = C.label(m, "Gold")
	-- tela do lado da frente do painel (a placa dourada fica atras)
	local g = panel.CFrame:PointToObjectSpace(gold.Position)
	local side = (g.Z > 0) and -1 or 1
	local scr = part(m, { Name = "Screen", Size = Vector3.new(panel.Size.X - 1, panel.Size.Y - 0.9, 0.2), CFrame = panel.CFrame * CFrame.new(0, 0, side * (panel.Size.Z / 2 + 0.15)), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Board"
	sg.Face = (side == -1) and Enum.NormalId.Front or Enum.NormalId.Back
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize = Vector2.new(900, 590)
	sg.LightInfluence = 0
	sg.Brightness = 1.4
	sg.MaxDistance = 180
	sg.Parent = scr
	local bg = Instance.new("Frame")
	bg.Name = "Bg"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(30, 23, 72)
	bg.BorderSizePixel = 0
	bg.Parent = sg
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(52, 40, 110), Color3.fromRGB(22, 16, 52))
	grad.Rotation = 90
	grad.Parent = bg
	local t = Instance.new("TextLabel")
	t.Name = "Title"
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, -40, 0, 90)
	t.Position = UDim2.fromOffset(20, 10)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = title
	t.TextColor3 = accent
	t.Parent = bg
	local st = Instance.new("UIStroke")
	st.Thickness = 4
	st.Color = Color3.fromRGB(20, 12, 40)
	st.Parent = t
	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Size = UDim2.new(1, -40, 1, -120)
	list.Position = UDim2.fromOffset(20, 108)
	list.Parent = bg
	local ll = Instance.new("UIListLayout")
	ll.Padding = UDim.new(0, 6)
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Parent = list
	local medal = { Color3.fromRGB(255, 206, 64), Color3.fromRGB(205, 215, 230), Color3.fromRGB(222, 140, 80) }
	for i = 1, 10 do
		local row = Instance.new("Frame")
		row.Name = "Row" .. i
		row.LayoutOrder = i
		row.Size = UDim2.new(1, 0, 0, i <= 3 and 50 or 36)
		row.BackgroundColor3 = i <= 3 and medal[i] or Color3.fromRGB(70, 58, 140)
		row.BackgroundTransparency = i <= 3 and 0.15 or 0.55
		row.BorderSizePixel = 0
		row.Parent = list
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 14)
		c.Parent = row
		local function lab(n, txt, x, w, al)
			local l = Instance.new("TextLabel")
			l.Name = n
			l.BackgroundTransparency = 1
			l.Position = UDim2.new(x, 0, 0.08, 0)
			l.Size = UDim2.new(w, 0, 0.84, 0)
			l.Font = Enum.Font.FredokaOne
			l.TextScaled = true
			l.Text = txt
			l.TextXAlignment = al
			l.TextColor3 = i <= 3 and Color3.fromRGB(40, 24, 10) or Color3.new(1, 1, 1)
			l.Parent = row
		end
		lab("Pos", "#" .. i, 0.02, 0.1, Enum.TextXAlignment.Left)
		lab("Name", "\u{2014}", 0.13, 0.55, Enum.TextXAlignment.Left)
		lab("Value", "", 0.68, 0.3, Enum.TextXAlignment.Right)
	end
	return m
end

return C
