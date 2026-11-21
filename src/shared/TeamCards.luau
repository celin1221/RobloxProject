--[[
	TeamCards (cliente): cartao de personagem com previa 3D, usado na barra do time e na tela de Equipe.
	- Moldura na cor da raridade (degrade claro em cima, contorno escuro do tema); Lendario com brilho animado.
	- Previa 3D: ViewportFrame com a copia do modelo (ReplicatedStorage/CharacterPreviews), do peito para cima.
	- Detalhes: nivel no canto, icone do tipo no outro canto, estrelas embaixo, barra fina de HP se nao estiver cheio,
	  Brilhante com brilho extra. Espaco vazio: moldura apagada, fundo escuro transparente e "+".
	O ViewportFrame so renderiza quando o cartao esta visivel; o giro (SetAngle) e chamado por quem usa o cartao.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(ReplicatedStorage:WaitForChild("UI"))
local Data = ReplicatedStorage:WaitForChild("Data")
local Characters = require(Data:WaitForChild("Characters"))
local Progression = require(Data:WaitForChild("Progression"))
local T = UI.Theme

local TeamCards = {}

local RARITY_TOP = {
	Comum = Color3.fromRGB(196, 203, 218), Raro = Color3.fromRGB(120, 180, 255),
	Epico = Color3.fromRGB(205, 140, 255), Lendario = Color3.fromRGB(255, 222, 110),
}
local RARITY_INNER = {
	Comum = { Color3.fromRGB(164, 174, 194), Color3.fromRGB(76, 84, 104) },
	Raro = { Color3.fromRGB(82, 156, 255), Color3.fromRGB(26, 66, 158) },
	Epico = { Color3.fromRGB(186, 104, 255), Color3.fromRGB(82, 30, 146) },
	Lendario = { Color3.fromRGB(255, 202, 74), Color3.fromRGB(164, 82, 12) },
}
local EMPTY_INNER_TOP = Color3.fromRGB(58, 46, 128)
local EMPTY_INNER_BOT = Color3.fromRGB(26, 20, 64)
local EMPTY = Color3.fromRGB(70, 62, 112)

local function previews()
	return ReplicatedStorage:FindFirstChild("CharacterPreviews")
end

local function gradientOf(top: Color3, bottom: Color3)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(top, bottom)
	return g
end

local function corner(obj, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(r, 0)
	c.Parent = obj
end

-- Enquadra do peito para cima, de frente
local function frameModel(view: ViewportFrame, model: Model)
	local head = model:FindFirstChild("Head")
	local root = model:FindFirstChild("HumanoidRootPart") or head
	if not head or not root then
		return nil
	end
	local front = root.CFrame.LookVector
	front = Vector3.new(front.X, 0, front.Z)
	front = if front.Magnitude > 0.01 then front.Unit else Vector3.new(0, 0, -1)
	-- cabeca um pouco acima do meio, ombros e peito embaixo
	-- quadro de (cabeca - 1,5) a (cabeca + 1,0) alturas de cabeca: rosto no meio, sobra em cima para o nivel
	local target = head.Position - Vector3.new(0, head.Size.Y * 0.25, 0)
	local dist = head.Size.Y * 1.25 / math.tan(math.rad(17))
	local cam = view:FindFirstChildOfClass("Camera") or Instance.new("Camera")
	cam.FieldOfView = 34
	cam.Parent = view
	view.CurrentCamera = cam
	return { Cam = cam, Target = target, Front = front, Dist = dist }
end

function TeamCards.new(parent: Instance, p)
	p = p or {}
	local card = {}
	local z = p.ZIndex or 2

	local root = Instance.new("TextButton")
	root.Name = p.Name or "Card"
	root.Text = ""
	root.AutoButtonColor = false
	root.BackgroundTransparency = 1
	root.Size = p.Size or UDim2.fromScale(1, 1)
	root.Position = p.Position or UDim2.new()
	root.AnchorPoint = p.AnchorPoint or Vector2.zero
	root.ZIndex = z
	if p.LayoutOrder then
		root.LayoutOrder = p.LayoutOrder
	end
	local scale = Instance.new("UIScale")
	scale.Parent = root

	-- sombra (profundidade do tema)
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.Position = UDim2.fromScale(0, 0.06)
	shadow.BorderSizePixel = 0
	shadow.ZIndex = z
	corner(shadow, 0.2)
	shadow.Parent = root

	local border = Instance.new("Frame")
	border.Name = "Border"
	border.Size = UDim2.fromScale(1, 1)
	border.BackgroundColor3 = Color3.new(1, 1, 1)
	border.BorderSizePixel = 0
	border.ZIndex = z
	corner(border, 0.2)
	local fill = gradientOf(EMPTY, EMPTY)
	fill.Parent = border
	UI.stroke(border, nil, 0.6)
	border.Parent = root

	-- brilho leve na borda de dentro
	local glow = Instance.new("UIStroke")
	glow.Name = "Glow"
	glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	glow.Thickness = 1
	glow.Transparency = 0.35

	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.Size = UDim2.fromScale(0.92, 0.92)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.BackgroundColor3 = Color3.new(1, 1, 1)
	inner.BorderSizePixel = 0
	inner.ZIndex = z + 1
	corner(inner, 0.18)
	local innerFill = gradientOf(Color3.fromRGB(58, 46, 128), Color3.fromRGB(26, 20, 64))
	innerFill.Parent = inner
	glow.Parent = inner
	inner.Parent = border

	local view: ViewportFrame? = nil
	local function destroyView()
		if view then
			view:Destroy()
			view = nil
			card.View = nil
		end
	end
	local function recreateView(): ViewportFrame
		destroyView()
		local v = Instance.new("ViewportFrame")
		v.Name = "View"
		v.Size = UDim2.fromScale(1, 1)
		v.BackgroundTransparency = 1
		v.Ambient = Color3.fromRGB(170, 165, 190)
		v.LightColor = Color3.fromRGB(255, 248, 235)
		v.LightDirection = Vector3.new(-0.4, -1, -0.6)
		v.ZIndex = z + 2
		corner(v, 0.18)
		v.Parent = inner
		view = v
		card.View = v
		return v
	end

	-- sombra escura embaixo, para o nome ler bem sobre o modelo
	local fade = Instance.new("Frame")
	fade.Name = "NameShade"
	fade.Size = UDim2.fromScale(1, 0.42)
	fade.Position = UDim2.fromScale(0, 1)
	fade.AnchorPoint = Vector2.new(0, 1)
	fade.BackgroundColor3 = Color3.fromRGB(14, 10, 34)
	fade.BorderSizePixel = 0
	fade.ZIndex = z + 3
	corner(fade, 0.3)
	local fg = Instance.new("UIGradient")
	fg.Rotation = 90
	fg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0.08) })
	fg.Parent = fade
	fade.Parent = inner

	-- nome do personagem: fonte do tema, contorno escuro e degrade na cor da raridade
	local nameText = Instance.new("TextLabel")
	nameText.Name = "CharName"
	nameText.BackgroundTransparency = 1
	nameText.Size = UDim2.fromScale(0.94, 0.24)
	nameText.Position = UDim2.fromScale(0.5, 0.93)
	nameText.AnchorPoint = Vector2.new(0.5, 1)
	nameText.FontFace = T.Font
	nameText.TextScaled = true
	nameText.TextColor3 = Color3.new(1, 1, 1)
	nameText.ZIndex = z + 6
	local nameLim = Instance.new("UITextSizeConstraint")
	nameLim.MinTextSize = 9
	nameLim.MaxTextSize = 26
	nameLim.Parent = nameText
	local nameGrad = Instance.new("UIGradient")
	nameGrad.Rotation = 90
	nameGrad.Parent = nameText
	local nameStroke = Instance.new("UIStroke")
	nameStroke.Color = T.Outline
	nameStroke.LineJoinMode = Enum.LineJoinMode.Round
	nameStroke.Thickness = 1.5
	nameStroke.Parent = nameText
	nameText.Parent = root

	local plus = UI.icon(inner, "plus", { Name = "Plus", Size = UDim2.fromScale(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = z + 3 })
	plus.ImageTransparency = 0.25

	-- nivel (canto de cima a esquerda)
	local lvl = Instance.new("Frame")
	lvl.Name = "Level"
	lvl.Size = UDim2.fromScale(0.64, 0.25)
	lvl.Position = UDim2.fromScale(0.02, 0.02)
	lvl.BackgroundColor3 = T.Outline
	lvl.BackgroundTransparency = 0.25
	lvl.BorderSizePixel = 0
	lvl.ZIndex = z + 4
	corner(lvl, 0.5)
	lvl.Parent = root
	local lvlText = Instance.new("TextLabel")
	lvlText.Name = "Text"
	lvlText.BackgroundTransparency = 1
	lvlText.Size = UDim2.fromScale(0.9, 0.86)
	lvlText.Position = UDim2.fromScale(0.05, 0.07)
	lvlText.FontFace = T.Font
	lvlText.TextScaled = true
	lvlText.TextColor3 = T.Palette.onDark
	lvlText.ZIndex = z + 5
	local lvlLim = Instance.new("UITextSizeConstraint")
	lvlLim.MinTextSize = 9
	lvlLim.MaxTextSize = 18
	lvlLim.Parent = lvlText
	lvlText.Parent = lvl

	-- tipo (canto de cima a direita)
	local typeIcon = UI.icon(root, "tipo_fogo", { Name = "Type", Size = UDim2.fromScale(0.28, 0.28), Position = UDim2.fromScale(0.99, 0.01), AnchorPoint = Vector2.new(1, 0), ZIndex = z + 4 })

	-- estrelas: selo pequeno (estrela + numero) embaixo do icone do tipo
	local stars = Instance.new("Frame")
	stars.Name = "Stars"
	stars.Size = UDim2.fromScale(0.4, 0.21)
	stars.Position = UDim2.fromScale(0.98, 0.3)
	stars.AnchorPoint = Vector2.new(1, 0)
	stars.BackgroundColor3 = T.Outline
	stars.BackgroundTransparency = 0.25
	stars.BorderSizePixel = 0
	stars.ZIndex = z + 4
	corner(stars, 0.5)
	local starIcon = UI.icon(stars, "star", { Name = "Icon", Size = UDim2.fromScale(0.5, 0.9), Position = UDim2.fromScale(0.02, 0.5), AnchorPoint = Vector2.new(0, 0.5), AspectAxis = Enum.DominantAxis.Height, ZIndex = z + 5 })
	local starText = Instance.new("TextLabel")
	starText.Name = "Count"
	starText.BackgroundTransparency = 1
	starText.Size = UDim2.fromScale(0.5, 0.86)
	starText.Position = UDim2.fromScale(0.48, 0.07)
	starText.FontFace = T.Font
	starText.TextScaled = true
	starText.TextColor3 = T.Palette.gold
	starText.ZIndex = z + 5
	local starLim = Instance.new("UITextSizeConstraint")
	starLim.MinTextSize = 9
	starLim.MaxTextSize = 16
	starLim.Parent = starText
	starText.Parent = stars
	local _ = starIcon
	stars.Parent = root

	-- HP (barra fina)
	local hp = Instance.new("Frame")
	hp.Name = "Hp"
	-- HP: faixa fina colada na borda de baixo, embaixo do nome
	hp.Size = UDim2.fromScale(0.8, 0.055)
	hp.Position = UDim2.fromScale(0.5, 0.975)
	hp.AnchorPoint = Vector2.new(0.5, 1)
	hp.BackgroundColor3 = T.Palette.track
	hp.BorderSizePixel = 0
	hp.ZIndex = z + 4
	corner(hp, 0.5)
	local hpFill = Instance.new("Frame")
	hpFill.Name = "Fill"
	hpFill.BorderSizePixel = 0
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.ZIndex = z + 5
	corner(hpFill, 0.5)
	hpFill.Parent = hp
	hp.Parent = root

	-- selo contextual ("NO TIME", "MINERANDO", "PASSEANDO", "CAPSULA", etc.)
	local badge = Instance.new("Frame")
	badge.Name = "InTeam"
	badge.Size = UDim2.fromScale(0.86, 0.2)
	badge.Position = UDim2.fromScale(0.5, 0.7)
	badge.AnchorPoint = Vector2.new(0.5, 1)
	badge.BackgroundColor3 = T.Palette.green
	badge.BorderSizePixel = 0
	badge.ZIndex = z + 6
	badge.Visible = false
	corner(badge, 0.5)
	UI.stroke(badge, nil, 0.7)
	local badgeText = UI.text(badge, "NO TIME", { Name = "Text", Size = UDim2.fromScale(0.9, 0.84), Position = UDim2.fromScale(0.05, 0.08), Role = "Small", ZIndex = z + 7, StrokeMult = 0.5 })
	badge.Parent = root

	-- escurecimento leve para personagens inelegiveis no modo seletor (continua clicavel)
	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.fromRGB(16, 12, 38)
	dim.BackgroundTransparency = 0.56
	dim.BorderSizePixel = 0
	dim.ZIndex = z + 5
	dim.Visible = false
	corner(dim, 0.18)
	dim.Parent = inner

	-- brilhos (Brilhante e Lendario)
	local sparkle = UI.icon(root, "sparkle", { Name = "Sparkle", Size = UDim2.fromScale(0.26, 0.26), Position = UDim2.fromScale(0.03, 0.29), ZIndex = z + 6, Visible = false })

	local select = Instance.new("UIStroke")
	select.Name = "Selected"
	select.Color = Color3.fromRGB(255, 255, 255)
	select.Thickness = 3
	select.Enabled = false
	select.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	select.Parent = shadow

	local model, framing, shine
	local currentKey

	function card.Clear()
		if model then
			model:Destroy()
			model = nil
		end
		destroyView()
		framing = nil
		currentKey = nil
		if shine then
			shine:Destroy()
			shine = nil
		end
		fill.Color = ColorSequence.new(EMPTY, EMPTY)
		innerFill.Color = ColorSequence.new(EMPTY_INNER_TOP, EMPTY_INNER_BOT)
		border.BackgroundTransparency = 0.35
		shadow.BackgroundColor3 = Color3.fromRGB(20, 15, 45)
		shadow.BackgroundTransparency = 0.5
		inner.BackgroundTransparency = 0.45
		glow.Enabled = false
		plus.Visible = true
		fade.Visible = false
		nameText.Visible = false
		lvl.Visible = false
		typeIcon.Visible = false
		stars.Visible = false
		hp.Visible = false
		badge.Visible = false
		dim.Visible = false
		sparkle.Visible = false
		card.Uid = nil
		card.Member = nil
	end

	-- m: membro salvo do perfil (CharacterId, Level, Stars, Variant, Hp...)
	function card.Set(uid, m)
		if not m then
			card.Clear()
			return
		end
		local def = Characters.Get(m.CharacterId)
		if not def then
			card.Clear()
			return
		end
		card.Uid = uid
		card.Member = m
		local rc = T.Rarity[def.Rarity] or T.Palette.comum
		local ri = RARITY_INNER[def.Rarity]
		fill.Color = ColorSequence.new(RARITY_TOP[def.Rarity] or rc, rc:Lerp(Color3.new(0, 0, 0), 0.28))
		innerFill.Color = ColorSequence.new(
			ri and ri[1] or rc:Lerp(Color3.new(1, 1, 1), 0.16),
			ri and ri[2] or rc:Lerp(Color3.fromRGB(16, 12, 34), 0.48)
		)
		border.BackgroundTransparency = 0
		shadow.BackgroundColor3 = rc:Lerp(Color3.fromRGB(10, 10, 60), 0.62)
		shadow.BackgroundTransparency = 0
		inner.BackgroundTransparency = 0
		glow.Enabled = true
		glow.Color = (RARITY_TOP[def.Rarity] or rc):Lerp(Color3.new(1, 1, 1), 0.4)
		plus.Visible = false
		fade.Visible = true
		nameText.Visible = true
		nameText.Text = def.Name
		local light = RARITY_TOP[def.Rarity] or rc
		nameGrad.Color = ColorSequence.new(Color3.new(1, 1, 1), light:Lerp(Color3.new(1, 1, 1), 0.25))
		nameStroke.Thickness = math.clamp(math.floor(root.AbsoluteSize.Y / 40 + 0.5), 1, 3)
		lvl.Visible = true
		lvlText.Text = "Nv " .. tostring(m.Level or 1)
		local ti = UI.TypeIcon[def.Type]
		typeIcon.Visible = ti ~= nil
		if ti then
			UI.setIcon(typeIcon, ti)
		end
		-- estrelas
		local n = m.Stars or 0
		stars.Visible = n > 0
		starText.Text = tostring(n)
		-- HP
		local cur, max = Progression.CurrentHp(m)
		local frac = if max > 0 then cur / max else 1
		hp.Visible = frac < 0.999
		hpFill.Size = UDim2.fromScale(math.max(0.04, frac), 1)
		hpFill.BackgroundColor3 = if frac > 0.5 then T.Palette.hpHigh elseif frac > 0.2 then T.Palette.hpMid else T.Palette.hpLow
		-- (a posicao da faixa de HP e fixa: borda de baixo)
		-- brilho
		local shiny = m.Variant == "Brilhante"
		sparkle.Visible = shiny
		local wantShine = def.Rarity == "Lendario" or shiny
		if wantShine and not shine then
			shine = UI.shine(border, if shiny then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(255, 240, 170))
			shine.ZIndex = z + 3
		elseif not wantShine and shine then
			shine:Destroy()
			shine = nil
		end
		select.Color = if shiny then Color3.fromRGB(255, 250, 200) else Color3.fromRGB(255, 255, 255)
		-- modelo (recria ViewportFrame ao trocar personagem para evitar cache/textura antiga no Roblox)
		local key = def.ModelName .. "|" .. tostring(m.Variant)
		if key ~= currentKey or not model or not view then
			if model then
				model:Destroy()
				model = nil
			end
			framing = nil
			currentKey = nil
			local folder = previews()
			local src = folder and folder:FindFirstChild(def.ModelName)
			if src then
				local v = recreateView()
				currentKey = key
				model = src:Clone()
				model.Parent = v
				framing = frameModel(v, model)
				card.SetAngle(0)
			else
				destroyView()
			end
		end
	end

	function card.SetAngle(a: number)
		if not framing then
			return
		end
		local dir = (CFrame.fromAxisAngle(Vector3.yAxis, a) * framing.Front)
		local pos = framing.Target + dir * framing.Dist
		framing.Cam.CFrame = CFrame.lookAt(pos, framing.Target)
	end

	function card.SetSelected(on: boolean)
		select.Enabled = on
		scale.Scale = if on then 1.06 else 1
	end

	function card.SetBadge(text: string?, color: (string | Color3)?)
		if not text or text == "" then
			badge.Visible = false
			return
		end
		badgeText.Text = text
		local c = color
		if typeof(c) == "string" then
			c = T.Palette[c] or T.Types[c] or T.Rarity[c] or T.Palette.green
		end
		if typeof(c) == "table" then
			c = c[1]
		end
		badge.BackgroundColor3 = if typeof(c) == "Color3" then c else T.Palette.green
		badge.Visible = true
	end

	function card.SetDimmed(on: boolean)
		dim.Visible = on == true
	end

	function card.SetInTeam(on: boolean)
		card.SetBadge(if on then "NO TIME" else nil, "green")
	end

	function card.Destroy()
		card.Clear()
		root:Destroy()
	end

	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		nameStroke.Thickness = math.clamp(math.floor(root.AbsoluteSize.Y / 40 + 0.5), 1, 3)
	end)
	card.Root = root
	card.View = view
	card.Clear()
	root.Parent = parent
	return card
end

return TeamCards
