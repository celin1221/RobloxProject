--[[
	RadarChart (cliente): grafico de radar de 4 eixos (HP, ATQ, DEF, VEL) de 0 a 100%.
	Desenha grade em losangos (25%, 50%, 75%, 100%), eixos centrais, preenchimento
	triangular exato via UIGradient por quadrante, arestas e vertices luminosos.
	Nao sai dos limites do container e adapta dinamicamente ao tamanho na tela.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(ReplicatedStorage:WaitForChild("UI"))
local T = UI.Theme

local RadarChart = {}

local AXES = {
	{ Key = "HP", Short = "HP", Dir = Vector2.new(0, -1), LabelOffset = Vector2.new(0, -1), AlignX = Enum.TextXAlignment.Center },
	{ Key = "Attack", Short = "ATQ", Dir = Vector2.new(1, 0), LabelOffset = Vector2.new(1, 0), AlignX = Enum.TextXAlignment.Left },
	{ Key = "Defense", Short = "DEF", Dir = Vector2.new(0, 1), LabelOffset = Vector2.new(0, 1), AlignX = Enum.TextXAlignment.Center },
	{ Key = "Speed", Short = "VEL", Dir = Vector2.new(-1, 0), LabelOffset = Vector2.new(-1, 0), AlignX = Enum.TextXAlignment.Right },
}

local QUAD_ANGLES = { -45, 45, 135, -135 } -- Q1 (HP-ATQ), Q2 (ATQ-DEF), Q3 (DEF-VEL), Q4 (VEL-HP)
local RINGS = { 0.25, 0.50, 0.75, 1.00 }

local function makeLine(parent: Instance, color: Color3, transparency: number, z: number)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.ZIndex = z
	f.Parent = parent
	return f
end

local function placeLine(line: Frame, p1: Vector2, p2: Vector2, thickness: number)
	local delta = p2 - p1
	local len = delta.Magnitude
	if len < 0.5 then
		line.Visible = false
		return
	end
	line.Visible = true
	local mid = (p1 + p2) * 0.5
	line.Size = UDim2.fromOffset(math.max(1, len), thickness)
	line.Position = UDim2.fromOffset(mid.X, mid.Y)
	line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
end

local function makeQuad(parent: Instance, color: Color3, transparency: number, angleDeg: number, z: number)
	local f = Instance.new("Frame")
	f.Name = "Quad"
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.ZIndex = z
	local g = Instance.new("UIGradient")
	g.Rotation = angleDeg
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, transparency),
		NumberSequenceKeypoint.new(0.492, transparency),
		NumberSequenceKeypoint.new(0.508, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = f
	f.Parent = parent
	return f, g
end

local function makeDot(parent: Instance, color: Color3, z: number)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.ZIndex = z
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = f
	local s = Instance.new("UIStroke")
	s.Color = T.Outline
	s.Thickness = 1.5
	s.Parent = f
	f.Parent = parent
	return f
end

function RadarChart.new(parent: Instance, p)
	p = p or {}
	local z = p.ZIndex or 4
	local chart = {}

	local root = UI.frame(parent, {
		Name = p.Name or "RadarChart",
		Size = p.Size or UDim2.fromScale(1, 1),
		Position = p.Position or UDim2.fromScale(0, 0),
		AnchorPoint = p.AnchorPoint or Vector2.zero,
		ZIndex = z,
	})
	chart.Root = root

	local plot = root

	-- Fundo sutil em losango (100%)
	local gridLines = {}
	for rIdx = 1, #RINGS do
		gridLines[rIdx] = {}
		local isOuter = rIdx == #RINGS
		for e = 1, 4 do
			gridLines[rIdx][e] = makeLine(plot, if isOuter then Color3.fromRGB(165, 155, 235) else Color3.fromRGB(125, 118, 195), if isOuter then 0.35 else 0.68, z + 1)
		end
	end

	-- Eixos diagonais/ortogonais (HP-DEF e ATQ-VEL)
	local spokeV = makeLine(plot, Color3.fromRGB(135, 128, 210), 0.6, z + 1)
	local spokeH = makeLine(plot, Color3.fromRGB(135, 128, 210), 0.6, z + 1)

	-- Cria uma camada de dados (poligono preenchido + arestas + vertices)
	local function createLayer(name: string, fillColor: Color3, lineColor: Color3, fillAlpha: number, layerZ: number)
		local layer = {
			Values = { HP = 0, Attack = 0, Defense = 0, Speed = 0 },
			Visible = true,
			FillColor = fillColor,
			LineColor = lineColor,
			FillAlpha = fillAlpha,
			Quads = {},
			QuadsGrad = {},
			Edges = {},
			Dots = {},
		}
		for q = 1, 4 do
			local f, g = makeQuad(plot, fillColor, fillAlpha, QUAD_ANGLES[q], layerZ)
			f.Name = name .. "_Q" .. q
			layer.Quads[q] = f
			layer.QuadsGrad[q] = g
		end
		for e = 1, 4 do
			local line = makeLine(plot, lineColor, 0, layerZ + 1)
			line.Name = name .. "_E" .. e
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(1, 0)
			c.Parent = line
			layer.Edges[e] = line
		end
		for d = 1, 4 do
			local dot = makeDot(plot, lineColor, layerZ + 2)
			dot.Name = name .. "_D" .. d
			layer.Dots[d] = dot
		end
		return layer
	end

	-- Treino por baixo (laranja/ouro) e Genetica por cima (ciano), ambos semi-transparentes
	local layers = {
		Training = createLayer("Train", Color3.fromRGB(255, 176, 32), Color3.fromRGB(255, 206, 84), 0.56, z + 2),
		Genetics = createLayer("Gen", Color3.fromRGB(38, 216, 224), Color3.fromRGB(115, 245, 255), 0.52, z + 5),
	}

	-- Rotulos nos 4 extremos (sempre dentro do quadrado)
	local axisLabels = {}
	for i, ax in ipairs(AXES) do
		local lbl = Instance.new("TextLabel")
		lbl.Name = "Axis_" .. ax.Key
		lbl.BackgroundTransparency = 1
		lbl.FontFace = T.Font
		lbl.TextScaled = true
		lbl.TextColor3 = T.Palette.onDark
		lbl.ZIndex = z + 9
		lbl.RichText = true
		local lim = Instance.new("UITextSizeConstraint")
		lim.MinTextSize = 9
		lim.MaxTextSize = 18
		lim.Parent = lbl
		local st = Instance.new("UIStroke")
		st.Color = T.Outline
		st.Thickness = 1.6
		st.LineJoinMode = Enum.LineJoinMode.Round
		st.Parent = lbl
		lbl.Parent = plot
		axisLabels[i] = lbl
	end

	local mode = "Both" -- "Both" | "Genetics" | "Training"

	local function layoutLayer(layer, cx: number, cy: number, radius: number, lineThick: number, dotSize: number)
		if not layer.Visible then
			for i = 1, 4 do
				layer.Quads[i].Visible = false
				layer.Edges[i].Visible = false
				layer.Dots[i].Visible = false
			end
			return
		end

		local anyNonZero = false
		local lens = {}
		local pts = {}
		local center = Vector2.new(cx, cy)
		for i, ax in ipairs(AXES) do
			local pct = math.clamp(layer.Values[ax.Key] or 0, 0, 100) / 100
			if pct > 0 then
				anyNonZero = true
			end
			local len = pct * radius
			lens[i] = len
			pts[i] = center + ax.Dir * len
		end

		if not anyNonZero then
			for i = 1, 4 do
				layer.Quads[i].Visible = false
				layer.Edges[i].Visible = false
				layer.Dots[i].Visible = false
			end
			return
		end

		-- Q1: HP(1) & ATQ(2), Q2: ATQ(2) & DEF(3), Q3: DEF(3) & VEL(4), Q4: VEL(4) & HP(1)
		-- UIGradient gira em espaco de pixel (x, y), entao o angulo da normal da hipotenusa usa atan2(+-W, +-H)
		local qSpec = {
			{ x = 0, y = -lens[1], w = lens[2], h = lens[1], rotFn = function(w, h) return math.deg(math.atan2(-w, h)) end }, -- Top-Right
			{ x = 0, y = 0, w = lens[2], h = lens[3], rotFn = function(w, h) return math.deg(math.atan2(w, h)) end },          -- Bottom-Right
			{ x = -lens[4], y = 0, w = lens[4], h = lens[3], rotFn = function(w, h) return math.deg(math.atan2(w, -h)) end }, -- Bottom-Left
			{ x = -lens[4], y = -lens[1], w = lens[4], h = lens[1], rotFn = function(w, h) return math.deg(math.atan2(-w, -h)) end }, -- Top-Left
		}
		for q = 1, 4 do
			local sp = qSpec[q]
			local quad = layer.Quads[q]
			if sp.w >= 1 and sp.h >= 1 then
				quad.Visible = true
				quad.Position = UDim2.fromOffset(cx + sp.x, cy + sp.y)
				quad.Size = UDim2.fromOffset(sp.w, sp.h)
				layer.QuadsGrad[q].Rotation = sp.rotFn(sp.w, sp.h)
			else
				quad.Visible = false
			end
		end

		for e = 1, 4 do
			local nxt = e % 4 + 1
			placeLine(layer.Edges[e], pts[e], pts[nxt], lineThick)
		end
		for i = 1, 4 do
			local dot = layer.Dots[i]
			dot.Visible = true
			dot.Position = UDim2.fromOffset(pts[i].X, pts[i].Y)
			dot.Size = UDim2.fromOffset(dotSize, dotSize)
		end
	end

	local function refreshLabels()
		local g = layers.Genetics.Values
		local t = layers.Training.Values
		for i, ax in ipairs(AXES) do
			local gv = math.floor((g[ax.Key] or 0) + 0.5)
			local tv = math.floor((t[ax.Key] or 0) + 0.5)
			local text
			if mode == "Genetics" then
				text = string.format("%s <font color='#73F5FF'>%d%%</font>", ax.Short, gv)
			elseif mode == "Training" then
				text = string.format("%s <font color='#FFCE54'>%d%%</font>", ax.Short, tv)
			else
				if i == 1 or i == 3 then
					text = string.format("%s <font color='#73F5FF'>%d%%</font> / <font color='#FFCE54'>%d%%</font>", ax.Short, gv, tv)
				else
					text = string.format("%s\n<font color='#73F5FF'>%d%%</font>\n<font color='#FFCE54'>%d%%</font>", ax.Short, gv, tv)
				end
			end
			axisLabels[i].Text = text
		end
	end

	local function redraw()
		local W, H = root.AbsoluteSize.X, root.AbsoluteSize.Y
		local S = math.min(W, H)
		if S < 24 then
			return
		end
		local cx, cy = W * 0.5, H * 0.5
		local center = Vector2.new(cx, cy)
		-- Deixa folga vertical para HP/DEF e usa a largura total de root para ATQ/VEL
		local radius = math.floor(S * 0.29)
		local lineThick = math.max(2, math.floor(S * 0.016))
		local dotSize = math.max(5, math.floor(S * 0.038))

		for rIdx, frac in ipairs(RINGS) do
			local rr = radius * frac
			local pts = {}
			for i, ax in ipairs(AXES) do
				pts[i] = center + ax.Dir * rr
			end
			local thick = if rIdx == #RINGS then 1.5 else 1
			for e = 1, 4 do
				placeLine(gridLines[rIdx][e], pts[e], pts[e % 4 + 1], thick)
			end
		end

		placeLine(spokeV, center + Vector2.new(0, -radius), center + Vector2.new(0, radius), 1)
		placeLine(spokeH, center + Vector2.new(-radius, 0), center + Vector2.new(radius, 0), 1)

		layers.Genetics.Visible = mode == "Both" or mode == "Genetics"
		layers.Training.Visible = mode == "Both" or mode == "Training"
		layoutLayer(layers.Training, cx, cy, radius, lineThick, dotSize)
		layoutLayer(layers.Genetics, cx, cy, radius, lineThick, dotSize)

		-- Posiciona os 4 rotulos sempre dentro de root [0..W] x [0..H]
		local topW = math.floor(W * 0.92)
		local topH = math.max(20, math.floor(cy - radius - 4))
		local sideW = math.max(36, math.floor(cx - radius - 6))
		local sideH = math.max(36, math.floor(S * 0.34))

		-- Top (HP)
		axisLabels[1].AnchorPoint = Vector2.new(0.5, 1)
		axisLabels[1].Position = UDim2.fromOffset(cx, math.max(topH, cy - radius - 3))
		axisLabels[1].Size = UDim2.fromOffset(topW, topH)
		axisLabels[1].TextXAlignment = Enum.TextXAlignment.Center

		-- Right (ATQ)
		axisLabels[2].AnchorPoint = Vector2.new(0, 0.5)
		axisLabels[2].Position = UDim2.fromOffset(math.min(W - sideW, cx + radius + 5), cy)
		axisLabels[2].Size = UDim2.fromOffset(sideW, sideH)
		axisLabels[2].TextXAlignment = Enum.TextXAlignment.Left

		-- Bottom (DEF)
		axisLabels[3].AnchorPoint = Vector2.new(0.5, 0)
		axisLabels[3].Position = UDim2.fromOffset(cx, math.min(H - topH, cy + radius + 3))
		axisLabels[3].Size = UDim2.fromOffset(topW, topH)
		axisLabels[3].TextXAlignment = Enum.TextXAlignment.Center

		-- Left (VEL)
		axisLabels[4].AnchorPoint = Vector2.new(1, 0.5)
		axisLabels[4].Position = UDim2.fromOffset(math.max(sideW, cx - radius - 5), cy)
		axisLabels[4].Size = UDim2.fromOffset(sideW, sideH)
		axisLabels[4].TextXAlignment = Enum.TextXAlignment.Right

		refreshLabels()
	end

	plot:GetPropertyChangedSignal("AbsoluteSize"):Connect(redraw)

	function chart.SetData(geneticsTbl, trainingTbl)
		for _, ax in ipairs(AXES) do
			layers.Genetics.Values[ax.Key] = math.clamp((geneticsTbl and geneticsTbl[ax.Key]) or 0, 0, 100)
			layers.Training.Values[ax.Key] = math.clamp((trainingTbl and trainingTbl[ax.Key]) or 0, 0, 100)
		end
		refreshLabels()
		redraw()
	end

	function chart.SetMode(newMode: string)
		if newMode == "Genetics" or newMode == "Training" or newMode == "Both" then
			mode = newMode
			refreshLabels()
			redraw()
		end
	end

	function chart.GetMode(): string
		return mode
	end

	task.defer(redraw)
	return chart
end

return RadarChart
