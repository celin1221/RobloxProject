--[[
	UI: kit de interface do jogo (cliente). Visual definido em ReplicatedStorage/UITheme (gerado de C:\Blender\UI\tema.json).

	Regras que o kit garante:
	- Tamanho e posicao sempre em ESCALA; UIAspectRatioConstraint onde a forma importa. So o contorno (UIStroke)
	  e a sombra usam pixel, recalculados pela altura da tela.
	- Botao com area de toque minima de 44 px (UISizeConstraint).
	- Profundidade: sombra embaixo, face com degrade (claro em cima), contorno escuro grosso igual na tela toda.
	- Texto Fredoka One com contorno; tamanho por papel (Title, Heading, Body, Small) proporcional a altura da tela.
	- Animacao: botao afunda ao tocar e volta com quique; janelas crescem e deslizam; numeros sobem contando; brilho nos raros.
	- Sons por nome (UI.play): click, open, close, purchase, reward, coin, error. Ids verificados no Studio (IsLoaded e TimeLength).
	- Teste de tamanho de tela: atributo DeviceEmu ("667x375") no PlayerGui redimensiona todas as telas como se fossem esse aparelho.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local T = require(ReplicatedStorage:WaitForChild("UITheme"))

local UI = {}
UI.Theme = T
UI.P = T.Palette

-- Icones (desenhados para o jogo; arquivos em C:\Blender\UI\icones)
UI.Icons = {
	coin = 118743113406257, gem = 83435521270134, ore = 115504640219833, team = 100176500204648,
	bag = 107691528595488, house = 129625179805204, shop = 82571282997846, gift = 135394029545926,
	portal = 124302809506337, tower = 99196332730743, sword = 116765767066122, swap = 118546365097162,
	run = 138859658767837, flag = 114050251606888, chest = 140132787874352, clock = 77329952900195,
	trophy = 100747540702207, scroll = 94268206956988, ticket = 84773317662173, potion = 77045254388514,
	seal = 81304980847817, book = 109857484040738, pickaxe = 96250656030165, heal = 73529231091642,
	close = 98854359589958, tick = 110236645052598, star = 99213987791020, lock = 75275569622835,
	heart = 106988462112017, plus = 101956040454774, minus = 71760513326498, arrow = 75508355730640,
	seal_basic = 100621042868382, seal_superior = 132984291965815,
	doce_comum = 135488822674293, doce_raro = 132697637242766, doce_epico = 140556027915418, gear = 80957102713866,
	ore_hp = 98190850262557, ore_def = 81379071551950, ore_vel = 131534143692832, ore_atq = 94276779585364,
	music = 95544281526372, speaker = 136399284995956, sparkle = 84255360310628,
	summon_sunburst = 139837721546408, banner_todos = 80124787437807, banner_onepiece = 88088550646321, banner_naruto = 90282977605958, banner_bleach = 77274797232236,
	-- classes (selos redondos: Blender/UI/icones/classe_*.png)
	classe_espadachim = 107664037444284, classe_lutador = 116069555686683,
	classe_mago = 139698755747879, classe_atirador = 123518987490984,
	-- insignias dos ginasios de anime (Blender/UI/icones/insignia_*.png)
	insignia_naruto = 78965692677391, insignia_onepiece = 112911216601734, insignia_bleach = 102949134179674,
	-- tipos antigos (mantidos por compatibilidade visual)
	tipo_fogo = 75267357253313, tipo_agua = 80328198116962, tipo_natureza = 114992050529106,
	tipo_raio = 72227189979725, tipo_luz = 109203429684282, tipo_trevas = 109541332454865,
}
UI.TypeIcon = {
	Espadachim = "classe_espadachim",
	Lutador = "classe_lutador",
	Mago = "classe_mago",
	Atirador = "classe_atirador",
	Fogo = "tipo_fogo", Agua = "tipo_agua", Natureza = "tipo_natureza", Raio = "tipo_raio", Luz = "tipo_luz", Trevas = "tipo_trevas",
}

-- Sons (Creator Store, gratis; medidos no Studio)
UI.Sounds = {
	click = { Id = 127036696152728, Volume = 0.5 }, -- 0,11 s
	open = { Id = 78897892629188, Volume = 0.45 }, -- 0,20 s
	close = { Id = 78897892629188, Volume = 0.35, Pitch = 0.8 },
	purchase = { Id = 10066947742, Volume = 0.55 }, -- 0,87 s (Roblox)
	reward = { Id = 96102213526905, Volume = 0.55 }, -- 1,41 s
	coin = { Id = 607665037, Volume = 0.4 }, -- 0,52 s
	error = { Id = 87519554692663, Volume = 0.45 }, -- 0,31 s
	-- invocacao (gacha): carga rapida + brilho + revelacao estimulante por raridade
	summon_charge = { Id = 12222200, Volume = 0.5, Pitch = 0.72 }, -- 0,20 s (Roblox swoosh)
	summon_shimmer = { Id = 9116394545, Volume = 0.55, Pitch = 1.15 }, -- 1,43 s (ProSoundEffects Magic Glow Chime)
	summon_reveal = { Id = 9126073001, Volume = 0.68, Pitch = 1.05 }, -- 1,16 s (ProSoundEffects Synth Sparkle Bell)
	summon_epic = { Id = 1844692556, Volume = 0.66, Pitch = 1.0 }, -- 2,17 s (APMOfficial Game Show fanfare)
	summon_legendary = { Id = 1845411858, Volume = 0.72, Pitch = 1.0 }, -- 4,81 s (APMOfficial Top Prize fanfare)
	-- doces de XP: o mesmo brilho, cada vez mais grave e mais alto
	candy_comum = { Id = 96102213526905, Volume = 0.4, Pitch = 1.35 },
	candy_raro = { Id = 96102213526905, Volume = 0.6, Pitch = 1.1 },
	candy_epico = { Id = 96102213526905, Volume = 0.8, Pitch = 0.85 },
}

local player = Players.LocalPlayer
local clickers = setmetatable({}, { __mode = "k" }) -- botao -> OnClick (gancho de teste do Studio)

--------------------------------------------------------------------
-- Utilidades
--------------------------------------------------------------------
function UI.fmt(n: number): string
	local s = tostring(math.floor(n or 0))
	local neg = s:sub(1, 1) == "-"
	if neg then
		s = s:sub(2)
	end
	s = (s:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", ""))
	return (if neg then "-" else "") .. s
end

local function colorOf(c)
	if typeof(c) == "string" then
		c = T.Palette[c] or T.Types[c] or T.Rarity[c] or T.Palette.panel
	end
	return c
end

-- Degrade (topo, base) a partir de uma cor ou par de cores
local function pair(c)
	c = colorOf(c)
	if typeof(c) == "table" then
		return c[1], c[2]
	end
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, math.max(0, s - 0.1), math.min(1, v + 0.16)), c
end
UI.pair = pair

-- Sombra: mais escura e puxada para o azul-abissal profundo
local function shadeOf(c)
	local _, bottom = pair(c)
	local h, s, v = bottom:ToHSV()
	h = (h + (if h < 0.6 then 0.04 else -0.04)) % 1
	return Color3.fromHSV(h, math.min(1, s + 0.10), math.max(0.06, v * 0.52))
end

-- Textura diagonal de luz (3 bandas a 38 graus, padrao patterns.py da skill roblox-ui)
local function addSheenLayer(face: GuiObject, cornerRadius: number, alpha: number?)
	local a = alpha or 0.13
	local t1 = math.clamp(1 - a, 0, 1)
	local t2 = math.clamp(1 - a * 0.72, 0, 1)
	local t3 = math.clamp(1 - a * 0.55, 0, 1)
	local sheen = Instance.new("Frame")
	sheen.Name = "_Sheen"
	sheen.Size = UDim2.fromScale(1, 1)
	sheen.BackgroundColor3 = Color3.new(1, 1, 1)
	sheen.BackgroundTransparency = 0
	sheen.BorderSizePixel = 0
	sheen.ZIndex = face.ZIndex
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(cornerRadius, 0)
	c.Parent = sheen
	local g = Instance.new("UIGradient")
	g.Rotation = 38
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.00, 1),
		NumberSequenceKeypoint.new(0.13, 1),
		NumberSequenceKeypoint.new(0.17, t1),
		NumberSequenceKeypoint.new(0.28, t1),
		NumberSequenceKeypoint.new(0.32, 1),
		NumberSequenceKeypoint.new(0.38, 1),
		NumberSequenceKeypoint.new(0.41, t2),
		NumberSequenceKeypoint.new(0.46, t2),
		NumberSequenceKeypoint.new(0.49, 1),
		NumberSequenceKeypoint.new(0.64, 1),
		NumberSequenceKeypoint.new(0.68, t3),
		NumberSequenceKeypoint.new(0.82, t3),
		NumberSequenceKeypoint.new(0.86, 1),
		NumberSequenceKeypoint.new(1.00, 1),
	})
	g.Parent = sheen
	sheen.Parent = face
	-- Se um layout automatico (UIListLayout/UIGridLayout) for adicionado direto na face, remove o sheen para nao ocupar slot
	face.ChildAdded:Connect(function(ch)
		if ch:IsA("UIGridStyleLayout") and sheen.Parent then
			sheen:Destroy()
		end
	end)
	return sheen
end
UI.sheen = addSheenLayer

local function gradient(top, bottom)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = 90
	return g
end

local function corner(obj, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(r or T.Corner.Panel, 0)
	c.Parent = obj
	return c
end
UI.corner = corner

--------------------------------------------------------------------
-- Metricas por tela (canvas): contorno e texto acompanham a altura
--------------------------------------------------------------------
local canvases = {} -- [canvas] = { Strokes = {}, Texts = {}, Shadows = {} }

local function canvasOf(obj)
	local o = obj
	while o do
		if canvases[o] then
			return o
		end
		o = o.Parent
	end
	return nil
end

function UI.height(obj): number
	local c = obj and canvasOf(obj)
	local h = c and c.AbsoluteSize.Y or 0
	if h <= 1 then
		local cam = workspace.CurrentCamera
		h = cam and cam.ViewportSize.Y or 720
	end
	return h
end

local function strokePx(h, mult)
	return math.max(1, math.floor(T.StrokeFor(h) * (mult or 1) + 0.5))
end

local function applyMetrics(c)
	local reg = canvases[c]
	if not reg then
		return
	end
	local h = UI.height(c)
	for s, mult in pairs(reg.Strokes) do
		if s.Parent then
			s.Thickness = strokePx(h, mult)
		else
			reg.Strokes[s] = nil
		end
	end
	for lim, role in pairs(reg.Texts) do
		if lim.Parent then
			local r = T.Text[role] or T.Text.Body
			lim.MaxTextSize = math.clamp(math.floor(h * r.Scale + 0.5), r.Min, r.Max)
			lim.MinTextSize = math.min(r.Min, lim.MaxTextSize)
		else
			reg.Texts[lim] = nil
		end
	end
	for sh in pairs(reg.Shadows) do
		if sh.Parent then
			sh.Position = UDim2.new(0, 0, 0, math.max(2, math.floor(h * 0.011 + 0.5)))
		else
			reg.Shadows[sh] = nil
		end
	end
end

local function register(obj, kind, key, value)
	-- registra no canvas assim que o objeto estiver dentro de um
	local function try()
		local c = canvasOf(obj)
		if c then
			canvases[c][kind][key] = value
			local h = UI.height(c)
			if kind == "Strokes" then
				key.Thickness = strokePx(h, value)
			elseif kind == "Texts" then
				local r = T.Text[value] or T.Text.Body
				key.MaxTextSize = math.clamp(math.floor(h * r.Scale + 0.5), r.Min, r.Max)
				key.MinTextSize = math.min(r.Min, key.MaxTextSize)
			else
				key.Position = UDim2.new(0, 0, 0, math.max(2, math.floor(h * 0.011 + 0.5)))
			end
			return true
		end
		return false
	end
	if not try() then
		local conn
		conn = obj.AncestryChanged:Connect(function()
			if try() then
				conn:Disconnect()
			end
		end)
	end
end

function UI.stroke(obj, color, mult)
	local s = Instance.new("UIStroke")
	s.Color = color or T.Outline
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Thickness = 3
	s.Parent = obj
	register(s, "Strokes", s, mult or 1)
	return s
end

--------------------------------------------------------------------
-- Telas e emulacao de aparelho
--------------------------------------------------------------------
-- Area segura do aparelho emulado: barra do Roblox (58 px) no topo e entalhe nas laterais
UI.Devices = {
	["667x375"] = { W = 667, H = 375, Top = 58, Side = 0 }, -- celular pequeno (iPhone SE)
	["932x430"] = { W = 932, H = 430, Top = 58, Side = 47 }, -- celular grande (iPhone Pro Max, com entalhe)
	["1024x768"] = { W = 1024, H = 768, Top = 58, Side = 0 }, -- tablet (iPad)
}

local function applyDevice(canvas)
	local pg = player and player:FindFirstChildOfClass("PlayerGui")
	local emu = pg and pg:GetAttribute("DeviceEmu")
	local d = emu and UI.Devices[emu]
	if d then
		-- aparelho centralizado na janela do Studio (mesmo centro da camera); a area util fica abaixo da barra do aparelho
		local inset = game:GetService("GuiService"):GetGuiInset()
		canvas.AnchorPoint = Vector2.new(0.5, 1)
		canvas.Position = UDim2.new(0.5, 0, 0.5, math.floor(d.H / 2 - inset.Y / 2))
		canvas.Size = UDim2.fromOffset(d.W - 2 * d.Side, d.H - d.Top)
	else
		canvas.AnchorPoint = Vector2.zero
		canvas.Position = UDim2.fromScale(0, 0)
		canvas.Size = UDim2.fromScale(1, 1)
	end
end

-- ScreenGui padrao + Canvas (toda a interface vai dentro do Canvas, em escala)
function UI.screen(gui: ScreenGui)
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local canvas = gui:FindFirstChild("Canvas") or Instance.new("Frame")
	canvas.Name = "Canvas"
	canvas.BackgroundTransparency = 1
	canvas.BorderSizePixel = 0
	canvas.Parent = gui
	canvases[canvas] = {
		Strokes = setmetatable({}, { __mode = "k" }),
		Texts = setmetatable({}, { __mode = "k" }),
		Shadows = setmetatable({}, { __mode = "k" }),
	}
	applyDevice(canvas)
	canvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		applyMetrics(canvas)
	end)
	local pg = player and player:FindFirstChildOfClass("PlayerGui")
	if pg then
		pg:GetAttributeChangedSignal("DeviceEmu"):Connect(function()
			applyDevice(canvas)
		end)
	end
	return canvas
end

--------------------------------------------------------------------
-- Pecas basicas
--------------------------------------------------------------------
local function ancestorScale(obj: Instance?): number
	local scale = 1
	local cur = obj
	while cur and not cur:IsA("ScreenGui") do
		local sc = cur:FindFirstChildOfClass("UIScale")
		if sc then
			scale *= sc.Scale
		end
		cur = cur.Parent
	end
	return scale
end

function UI.unscaledSize(obj: GuiObject): (number, number)
	local sc = ancestorScale(obj)
	if sc < 0.05 then
		return 0, 0
	end
	return obj.AbsoluteSize.X / sc, obj.AbsoluteSize.Y / sc
end

local function setCommon(obj, p, parent)
	obj.Name = p.Name or obj.Name
	obj.Size = p.Size or UDim2.fromScale(1, 1)
	obj.Position = p.Position or UDim2.fromScale(0, 0)
	obj.AnchorPoint = p.AnchorPoint or Vector2.zero
	if p.ZIndex then
		obj.ZIndex = p.ZIndex
	end
	if p.LayoutOrder then
		obj.LayoutOrder = p.LayoutOrder
	end
	if p.Visible ~= nil then
		obj.Visible = p.Visible
	end
	if p.MaxSize then
		-- teto em telas grandes (no celular a escala manda)
		local c = Instance.new("UISizeConstraint")
		c.Name = "MaxSize"
		c.MaxSize = p.MaxSize
		c.Parent = obj
	end
	if p.Aspect and obj.Size.Y.Scale == 0 and obj.Size.Y.Offset == 0 and not p.AspectType then
		-- linha de lista: largura em escala, altura = largura / Aspect (calculada, nao some com altura 0)
		local aspect = p.Aspect
		local rowMax = p.RowMax or math.huge -- teto da altura da linha (tablet)
		obj:SetAttribute("_RowAspect", aspect)
		if p.RowMax then
			obj:SetAttribute("_RowMax", p.RowMax)
		end
		local function fit()
			local sc = ancestorScale(obj)
			if sc < 0.05 then
				return
			end
			local w = obj.AbsoluteSize.X / sc
			if w <= 1 then
				local pObj = obj.Parent or parent
				if pObj and pObj:IsA("GuiObject") then
					local psc = ancestorScale(pObj)
					if psc >= 0.05 then
						local pw = pObj.AbsoluteSize.X / psc
						local pad = pObj:FindFirstChildOfClass("UIPadding")
						if pad then
							pw -= pad.PaddingLeft.Offset + pad.PaddingRight.Offset + pw * (pad.PaddingLeft.Scale + pad.PaddingRight.Scale)
						end
						if pObj:IsA("ScrollingFrame") then
							pw -= pObj.ScrollBarThickness
						end
						w = math.max(0, pw * obj.Size.X.Scale + obj.Size.X.Offset)
					end
				end
			end
			if w > 1 then
				local h = math.min(rowMax, math.floor(w / aspect + 0.5))
				if obj.Size.Y.Offset ~= h then
					obj.Size = UDim2.new(obj.Size.X.Scale, obj.Size.X.Offset, 0, h)
				end
			end
		end
		fit()
		obj:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		task.defer(fit)
	elseif p.Aspect then
		local a = Instance.new("UIAspectRatioConstraint")
		a.AspectRatio = p.Aspect
		a.DominantAxis = p.AspectAxis or Enum.DominantAxis.Width
		a.AspectType = p.AspectType or Enum.AspectType.FitWithinMaxSize
		a.Parent = obj
	end
end

function UI.frame(parent, p)
	p = p or {}
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundTransparency = 1
	setCommon(f, p, parent)
	if p.Color then
		f.BackgroundTransparency = p.Transparency or 0
		local top, bottom = pair(p.Color)
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		gradient(top, bottom).Parent = f
		corner(f, p.Corner or T.Corner.Pill)
		if p.Stroke then
			UI.stroke(f)
		end
	end
	f.Parent = parent
	return f
end

-- Texto: role = "Title" | "Heading" | "Body" | "Small"
function UI.text(parent, text, p)
	p = p or {}
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.FontFace = T.Font
	l.TextScaled = true
	l.TextWrapped = p.Wrap ~= false
	l.RichText = p.Rich == true
	l.Text = text or ""
	l.TextColor3 = colorOf(p.Color or "onDark")
	l.TextXAlignment = p.AlignX or Enum.TextXAlignment.Center
	l.TextYAlignment = p.AlignY or Enum.TextYAlignment.Center
	setCommon(l, p, parent)
	local lim = Instance.new("UITextSizeConstraint")
	lim.Parent = l
	register(l, "Texts", lim, p.Role or "Body")
	if p.Stroke ~= false then
		local s = Instance.new("UIStroke")
		s.Color = T.Outline
		s.LineJoinMode = Enum.LineJoinMode.Bevel
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		s.Parent = l
		register(l, "Strokes", s, p.StrokeMult or 0.7)
	end
	l.Parent = parent
	return l
end

function UI.icon(parent, name, p)
	p = p or {}
	local i = Instance.new("ImageLabel")
	i.BackgroundTransparency = 1
	i.Image = "rbxassetid://" .. tostring(UI.Icons[name] or name)
	i.ScaleType = Enum.ScaleType.Fit
	if p.Aspect == nil then
		p.Aspect = 1
	end
	setCommon(i, p, parent)
	if p.Tint then
		i.ImageColor3 = p.Tint
	end
	i.Parent = parent
	return i
end

function UI.setIcon(img, name)
	img.Image = "rbxassetid://" .. tostring(UI.Icons[name] or name)
end

-- Painel com profundidade: sombra + face (degrade) + contorno. Retorna (container, face).
function UI.panel(parent, p)
	p = p or {}
	local holder = Instance.new(p.Class or "Frame")
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	if holder:IsA("GuiButton") then
		holder.AutoButtonColor = false
		if holder:IsA("TextButton") then
			holder.Text = ""
		end
	end
	setCommon(holder, p, parent)
	local r = p.Corner or T.Corner.Panel
	local top, bottom = pair(p.Color or "panel")
	if p.Shadow ~= false then
		local sh = Instance.new("Frame")
		sh.Name = "Shadow"
		sh.Size = UDim2.fromScale(1, 1)
		sh.BackgroundColor3 = shadeOf(p.Color or "panel")
		sh.BackgroundTransparency = p.Transparency or 0
		sh.BorderSizePixel = 0
		sh.ZIndex = holder.ZIndex
		corner(sh, r)
		UI.stroke(sh)
		sh.Parent = holder
		register(sh, "Shadows", sh, true)
	end
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.BackgroundTransparency = p.Transparency or 0
	face.BorderSizePixel = 0
	face.ZIndex = holder.ZIndex
	corner(face, r)
	local g = gradient(top, bottom)
	g.Name = "Fill"
	g.Parent = face
	if p.Stroke ~= false then
		UI.stroke(face, p.StrokeColor)
	end
	if p.Sheen ~= false then
		local isDarkSlot = (p.Color == "slot" or p.Color == "track")
		addSheenLayer(face, r, if p.Class == "TextButton" then 0.15 elseif isDarkSlot then 0.06 else 0.11)
	end
	face.Parent = holder
	holder.Parent = parent
	return holder, face
end

-- Troca a cor de um painel/botao ja criado
function UI.paint(holder, color)
	local face = holder:FindFirstChild("Face")
	local top, bottom = pair(color)
	if face and face:FindFirstChild("Fill") then
		face.Fill.Color = ColorSequence.new(top, bottom)
	end
	local sh = holder:FindFirstChild("Shadow")
	if sh then
		sh.BackgroundColor3 = shadeOf(color)
	end
end

--------------------------------------------------------------------
-- Sons
--------------------------------------------------------------------
local soundCache = {}
function UI.play(name: string)
	local def = UI.Sounds[name]
	if not def then
		return
	end
	pcall(function()
		local s = soundCache[name]
		if not s then
			s = Instance.new("Sound")
			s.Name = "UI_" .. name
			s.SoundId = "rbxassetid://" .. def.Id
			s.Volume = def.Volume or 0.5
			s.PlaybackSpeed = def.Pitch or 1
			s.SoundGroup = SoundService:FindFirstChild("Efeitos") -- volume e liga/desliga dos efeitos
			s.Parent = SoundService
			soundCache[name] = s
		end
		SoundService:PlayLocalSound(s)
	end)
end

function UI.preloadSounds()
	for name in pairs(UI.Sounds) do
		if not soundCache[name] then
			local def = UI.Sounds[name]
			local s = Instance.new("Sound")
			s.Name = "UI_" .. name
			s.SoundId = "rbxassetid://" .. def.Id
			s.Volume = def.Volume or 0.5
			s.PlaybackSpeed = def.Pitch or 1
			s.SoundGroup = SoundService:FindFirstChild("Efeitos")
			s.Parent = SoundService
			soundCache[name] = s
		end
	end
end

--------------------------------------------------------------------
-- Botao
--------------------------------------------------------------------
-- p: Text, Icon, Color, Role, Layout ("row" icone a esquerda | "stack" icone em cima | "icon"),
--    OnClick, Sound (nome; false = mudo), Disabled
function UI.button(parent, p)
	p = p or {}
	p.Class = "TextButton"
	p.Corner = p.Corner or T.Corner.Button
	local holder, face = UI.panel(parent, p)
	if not (parent and parent:FindFirstChildOfClass("UIGridLayout")) then
		-- em grade a celula ja garante o tamanho (constraint dentro de grade encolhe a celula)
		local min = Instance.new("UISizeConstraint")
		min.MinSize = Vector2.new(T.TouchMin, T.TouchMin)
		min.Parent = holder
	end
	local scale = Instance.new("UIScale")
	scale.Parent = holder

	local layout = p.Layout or (if p.Icon and p.Text then "row" elseif p.Icon then "icon" else "text")
	if p.Icon then
		local ip
		if layout == "stack" then
			ip = { Name = "Icon", Size = UDim2.fromScale(0.78, 0.62), Position = UDim2.fromScale(0.5, 0.06), AnchorPoint = Vector2.new(0.5, 0) }
		elseif layout == "row" then
			ip = { Name = "Icon", Size = UDim2.fromScale(0.28, 0.78), Position = UDim2.fromScale(0.05, 0.5), AnchorPoint = Vector2.new(0, 0.5), AspectAxis = Enum.DominantAxis.Height }
		else
			ip = { Name = "Icon", Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) }
		end
		UI.icon(face, p.Icon, ip)
	end
	if p.Text then
		local tp
		if layout == "stack" then
			tp = { Name = "Label", Size = UDim2.fromScale(1.12, 0.34), Position = UDim2.fromScale(0.5, 1.04), AnchorPoint = Vector2.new(0.5, 1), Role = p.Role or "Small" }
		elseif layout == "row" then
			tp = { Name = "Label", Size = UDim2.fromScale(0.61, 0.72), Position = UDim2.fromScale(0.35, 0.14), Role = p.Role or "Body", AlignX = Enum.TextXAlignment.Left }
		else
			tp = { Name = "Label", Size = UDim2.fromScale(0.9, 0.72), Position = UDim2.fromScale(0.05, 0.14), Role = p.Role or "Body" }
		end
		tp.Wrap = p.Wrap
		UI.text(face, p.Text, tp)
	end

	local hovering = false
	local function tween(s, t, style)
		TweenService:Create(scale, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = s }):Play()
	end
	local function pressFace(down: boolean)
		local yOff = if down then 2 else 0
		TweenService:Create(face, TweenInfo.new(if down then T.Motion.PressTime else T.Motion.ReleaseTime, if down then Enum.EasingStyle.Quad else T.Motion.ReleaseStyle, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, yOff),
		}):Play()
	end
	holder.MouseEnter:Connect(function()
		hovering = true
		if not holder:GetAttribute("Disabled") then
			tween(T.Motion.HoverScale, T.Motion.HoverTime)
		end
	end)
	holder.MouseLeave:Connect(function()
		hovering = false
		tween(1, T.Motion.HoverTime)
		pressFace(false)
	end)
	holder.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			tween(T.Motion.PressScale, T.Motion.PressTime)
			if not holder:GetAttribute("Disabled") then
				pressFace(true)
			end
		end
	end)
	holder.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			tween(if hovering and input.UserInputType ~= Enum.UserInputType.Touch then T.Motion.HoverScale else 1, T.Motion.ReleaseTime, T.Motion.ReleaseStyle)
			pressFace(false)
		end
	end)
	holder.Activated:Connect(function()
		if holder:GetAttribute("Disabled") then
			UI.play("error")
			return
		end
		if p.Sound ~= false then
			UI.play(p.Sound or "click")
		end
		if p.OnClick then
			p.OnClick(holder)
		end
	end)
	if p.OnClick then
		clickers[holder] = p.OnClick
	end
	if p.Disabled then
		UI.setDisabled(holder, true)
	end
	return holder, face
end

-- Botao apagado (cinza), ainda clicavel para mostrar o motivo
function UI.setDisabled(btn, on: boolean, color)
	btn:SetAttribute("Disabled", on or nil)
	if on then
		UI.paint(btn, "grey")
	elseif color then
		UI.paint(btn, color)
	end
end

function UI.setText(btn, text)
	local l = btn:FindFirstChild("Face") and btn.Face:FindFirstChild("Label")
	if l then
		l.Text = text
	end
end

--------------------------------------------------------------------
-- Componentes
--------------------------------------------------------------------
-- Contador de moeda: icone grande saindo pela esquerda + numero. Retorna (holder, label)
function UI.pill(parent, iconName, color, p)
	p = p or {}
	p.Color = p.Color or "slot"
	p.Corner = T.Corner.Pill
	local aspect = p.Aspect or 3
	local holder, face = UI.panel(parent, p)
	local baseZ = holder.ZIndex or 1
	-- icone 1,3x a altura, saindo um pouco pela esquerda (ZIndex sempre ACIMA da face!)
	local iw = 1.3 / aspect
	UI.icon(holder, iconName, { Name = "Icon", Size = UDim2.fromScale(iw, 1.3), Position = UDim2.fromScale(-iw * 0.22, 0.5), AnchorPoint = Vector2.new(0, 0.5), ZIndex = baseZ + 3 })
	local start = iw * 0.86
	local l = UI.text(face, p.Text or "0", { Name = "Value", Size = UDim2.fromScale(0.95 - start, 0.72), Position = UDim2.fromScale(start, 0.14), Color = color, Role = p.Role or "Heading", AlignX = p.AlignX or Enum.TextXAlignment.Left, ZIndex = baseZ + 2 })
	return holder, l
end

-- Barra de progresso (HP, garantia, missoes). Retorna o container; use UI.setBar
function UI.bar(parent, p)
	p = p or {}
	local track = UI.frame(parent, { Name = p.Name or "Bar", Size = p.Size, Position = p.Position, AnchorPoint = p.AnchorPoint, Color = "track", Corner = T.Corner.Pill, LayoutOrder = p.LayoutOrder, ZIndex = p.ZIndex })
	UI.stroke(track, nil, 0.85)
	track.ClipsDescendants = true
	local fill = UI.frame(track, { Name = "Fill", Size = UDim2.fromScale(p.Value or 1, 1), Color = p.FillColor or "green", Corner = T.Corner.Pill, ZIndex = (p.ZIndex or 1) + 1 })
	fill.ClipsDescendants = false
	addSheenLayer(fill, T.Corner.Pill, 0.16)
	return track
end

function UI.setBar(track, frac, color, instant)
	local fill = track:FindFirstChild("Fill")
	if not fill then
		return
	end
	frac = math.clamp(frac or 0, 0, 1)
	fill.Visible = frac > 0.001
	if color then
		local top, bottom = pair(color)
		local g = fill:FindFirstChildOfClass("UIGradient")
		if g then
			g.Color = ColorSequence.new(top, bottom)
		end
	end
	if instant then
		fill.Size = UDim2.fromScale(frac, 1)
	else
		TweenService:Create(fill, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromScale(frac, 1) }):Play()
	end
end

-- Numero subindo contando ate o valor
local counting = {}
function UI.countTo(label: TextLabel, value: number, format)
	format = format or UI.fmt
	local from = counting[label] or tonumber(label:GetAttribute("Value")) or value
	label:SetAttribute("Value", value)
	if from == value then
		label.Text = format(value)
		counting[label] = value
		return
	end
	local nv = Instance.new("NumberValue")
	nv.Value = from
	nv.Changed:Connect(function(v)
		counting[label] = v
		label.Text = format(math.floor(v + 0.5))
	end)
	local tw = TweenService:Create(nv, TweenInfo.new(T.Motion.CountTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = value })
	tw.Completed:Connect(function()
		counting[label] = value
		label.Text = format(value)
		nv:Destroy()
	end)
	tw:Play()
	-- pulinho no numero
	local sc = label:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	sc.Parent = label
	sc.Scale = 1.18
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- Brilho passando (itens raros)
function UI.shine(obj: GuiObject, color)
	local holder = obj:FindFirstChild("Face") or obj
	local f = Instance.new("Frame")
	f.Name = "Shine"
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color or Color3.new(1, 1, 1)
	f.BackgroundTransparency = 0
	f.BorderSizePixel = 0
	f.ZIndex = holder.ZIndex + 1
	corner(f, (holder:FindFirstChildOfClass("UICorner") and holder:FindFirstChildOfClass("UICorner").CornerRadius.Scale) or T.Corner.Button)
	local g = Instance.new("UIGradient")
	g.Rotation = 25
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Offset = Vector2.new(-1, 0)
	g.Parent = f
	f.Parent = holder
	task.spawn(function()
		while f.Parent do
			g.Offset = Vector2.new(-1, 0)
			local tw = TweenService:Create(g, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { Offset = Vector2.new(1, 0) })
			tw:Play()
			task.wait(T.Motion.ShinePeriod)
		end
	end)
	return f
end

-- Lista rolavel. Columns > 0 = grade (celulas com proporcao CellAspect); senao lista vertical.
function UI.scroll(parent, p)
	p = p or {}
	local s = Instance.new("ScrollingFrame")
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 6
	s.ScrollBarImageColor3 = Color3.fromRGB(200, 190, 255)
	-- altura da lista calculada em pixels (nunca usar Scale vertical em UIPadding/UIListLayout dentro de
	-- ScrollingFrame: no Roblox Scale vertical multiplica CanvasSize.Y e cria loop exponencial com muitos itens)
	s.AutomaticCanvasSize = Enum.AutomaticSize.None
	s.CanvasSize = UDim2.new()
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	setCommon(s, p, parent)

	local topPx, botPx, leftPx, rightPx = 4, 8, 4, 10
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, topPx)
	pad.PaddingBottom = UDim.new(0, botPx)
	pad.PaddingLeft = UDim.new(0, leftPx)
	pad.PaddingRight = UDim.new(0, rightPx)
	pad.Parent = s

	local cols, aspect = p.Columns, p.CellAspect or 1
	local gap = if p.Gap ~= nil then p.Gap else 0.02
	local layout: UIGridStyleLayout
	if cols then
		local g = Instance.new("UIGridLayout")
		g.SortOrder = Enum.SortOrder.LayoutOrder
		g.FillDirectionMaxCells = cols
		g.Parent = s
		layout = g
	else
		local l = Instance.new("UIListLayout")
		l.Padding = UDim.new(0, if gap <= 0 then 0 else 6)
		l.SortOrder = Enum.SortOrder.LayoutOrder
		l.HorizontalAlignment = Enum.HorizontalAlignment.Center
		l.Parent = s
		layout = l
	end

	-- canvas = conteudo + margens em pixels + sombra do ultimo item (o ultimo sempre aparece inteiro)
	local function fitCanvas()
		local sc = ancestorScale(s)
		if sc < 0.05 then
			return
		end
		local contentY = layout.AbsoluteContentSize.Y / sc
		local shadowPx = math.max(2, math.floor(UI.height(s) * 0.011 + 0.5))
		local h = math.ceil(contentY + topPx + botPx + shadowPx + 8)
		if s.CanvasSize.Y.Scale ~= 0 or s.CanvasSize.Y.Offset ~= h then
			s.CanvasSize = UDim2.fromOffset(0, h)
		end
	end

	local function fitMetrics()
		local sc = ancestorScale(s)
		if sc < 0.05 then
			return
		end
		local w = s.AbsoluteSize.X / sc
		local h = s.AbsoluteSize.Y / sc
		if w <= 1 or h <= 1 then
			return
		end
		topPx = math.clamp(math.floor(h * 0.015 + 0.5), 3, 10)
		botPx = math.clamp(math.floor(h * 0.03 + 0.5), 6, 16)
		leftPx = math.clamp(math.floor(w * 0.012 + 0.5), 3, 12)
		rightPx = math.clamp(math.floor(w * 0.03 + 0.5), 8, 20)
		pad.PaddingTop = UDim.new(0, topPx)
		pad.PaddingBottom = UDim.new(0, botPx)
		pad.PaddingLeft = UDim.new(0, leftPx)
		pad.PaddingRight = UDim.new(0, rightPx)

		if cols then
			local g = layout :: UIGridLayout
			local inner = w - leftPx - rightPx - s.ScrollBarThickness
			if inner > 0 then
				local gapPx = math.floor(inner * gap)
				local cw = math.max(1, math.floor((inner - gapPx * (cols - 1)) / cols))
				local ch = math.max(1, math.floor(cw / aspect))
				if g.CellPadding.X.Offset ~= gapPx or g.CellPadding.Y.Offset ~= gapPx then
					g.CellPadding = UDim2.fromOffset(gapPx, gapPx)
				end
				if g.CellSize.X.Offset ~= cw or g.CellSize.Y.Offset ~= ch then
					g.CellSize = UDim2.fromOffset(cw, ch)
				end
			end
		else
			local l = layout :: UIListLayout
			local gapPx = if gap <= 0
				then 0
				else math.clamp(math.floor(math.max(h * gap, UI.height(s) * (gap * 0.55)) + 0.5), 4, 14)
			if l.Padding.Scale ~= 0 or l.Padding.Offset ~= gapPx then
				l.Padding = UDim.new(0, gapPx)
			end
			-- Atualiza altura de todas as linhas (inclusive fora da area visivel, onde AbsoluteSize pode ser adiado)
			local innerW = w - leftPx - rightPx - s.ScrollBarThickness
			if innerW > 1 then
				for _, ch in ipairs(s:GetChildren()) do
					if ch:IsA("GuiObject") then
						local a = ch:GetAttribute("_RowAspect")
						if typeof(a) == "number" and a > 0 then
							local rmax = ch:GetAttribute("_RowMax")
							local cw = math.max(0, innerW * ch.Size.X.Scale + ch.Size.X.Offset)
							if cw > 1 then
								local rh = math.min(if typeof(rmax) == "number" then rmax else math.huge, math.floor(cw / a + 0.5))
								if ch.Size.Y.Offset ~= rh then
									ch.Size = UDim2.new(ch.Size.X.Scale, ch.Size.X.Offset, 0, rh)
								end
							end
						end
					end
				end
			end
		end
		fitCanvas()
	end

	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitCanvas)
	s:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitMetrics)
	s.Parent = parent
	task.defer(fitMetrics)
	return s
end

-- Linha de lista com altura proporcional a largura da lista (AspectRatio largura/altura)
function UI.row(parent, p)
	p = p or {}
	p.Size = p.Size or UDim2.fromScale(1, 0)
	p.Aspect = p.Aspect or 7
	return UI.panel(parent, p)
end

function UI.clear(container)
	for _, c in ipairs(container:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

--------------------------------------------------------------------
-- Janela (tela cheia modal): fundo escuro + painel que cresce e desliza
--------------------------------------------------------------------
local openWindows = {}
local windowsSignal = Instance.new("BindableEvent")

-- Alguma janela (tela cheia) aberta? A barra do time se esconde enquanto houver uma.
function UI.anyWindowOpen(): boolean
	return next(openWindows) ~= nil
end

function UI.onWindows(fn)
	return windowsSignal.Event:Connect(fn)
end

-- p: Title, Icon, HeaderColor, Size (escala do canvas), Aspect, OnClose
-- retorna objeto { Root, Panel, Body, Open(), Close(), IsOpen() }
function UI.window(canvas, p)
	p = p or {}
	local win = {}
	local root = UI.frame(canvas, { Name = p.Name or "Window", Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = p.ZIndex or 20 })
	local scrim = Instance.new("TextButton")
	scrim.Name = "Scrim"
	scrim.Text = ""
	scrim.AutoButtonColor = false
	-- cobre a tela toda, inclusive a faixa da barra do Roblox e as bordas seguras fora do Canvas
	scrim.Size = UDim2.fromScale(3, 3)
	scrim.Position = UDim2.fromScale(-1, -1)
	scrim.BackgroundColor3 = Color3.new(0, 0, 0)
	scrim.BackgroundTransparency = 0.45
	scrim.BorderSizePixel = 0
	scrim.Parent = root

	local holder, face = UI.panel(root, {
		Name = "Panel",
		MaxSize = p.MaxSize or Vector2.new(1150, 640),
		Size = p.Size or UDim2.fromScale(0.9, 0.84),
		Position = UDim2.fromScale(0.5, 0.56),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = "panel",
		Corner = p.Corner or 0.06,
		Aspect = p.Aspect,
		AspectType = Enum.AspectType.FitWithinMaxSize,
		AspectAxis = Enum.DominantAxis.Height,
	})
	local sc = Instance.new("UIScale")
	sc.Parent = holder

	-- cabecalho em pilula saindo pela borda de cima
	local header, hface = UI.panel(holder, {
		Name = "Header",
		Size = UDim2.fromScale(0.52, 0.15),
		Position = UDim2.fromScale(0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.45),
		Color = p.HeaderColor or "header",
		Corner = T.Corner.Pill,
		ZIndex = 3,
	})
	if p.Icon then
		UI.icon(header, p.Icon, { Name = "Icon", Size = UDim2.fromScale(0.3, 1.25), Position = UDim2.fromScale(-0.04, 0.5), AnchorPoint = Vector2.new(0, 0.5), AspectAxis = Enum.DominantAxis.Height, ZIndex = 4 })
	end
	win.Title = UI.text(hface, p.Title or "", { Name = "Title", Size = UDim2.fromScale(0.74, 0.74), Position = UDim2.fromScale(0.56, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Role = "Title", ZIndex = 4 })

	-- fechar (vermelho) saindo pelo canto
	local close = UI.button(holder, {
		Name = "Close",
		Icon = "close",
		Color = "red",
		Size = UDim2.fromScale(0.09, 0.15),
		Position = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(0.65, 0.35),
		Aspect = 1,
		Corner = 0.3,
		ZIndex = 5,
		Sound = "close",
		OnClick = function()
			win.Close()
		end,
	})
	win.CloseButton = close

	local body = UI.frame(face, { Name = "Body", Size = UDim2.fromScale(0.94, 0.8), Position = UDim2.fromScale(0.03, 0.15) })
	win.Root, win.Panel, win.Face, win.Body, win.Header = root, holder, face, body, header

	local isOpen = false
	function win.IsOpen()
		return isOpen
	end
	function win.Open()
		if isOpen then
			return
		end
		for other in pairs(openWindows) do
			if other ~= win and not p.Stack then
				other.Close(true)
			end
		end
		isOpen = true
		openWindows[win] = true
		windowsSignal:Fire()
		root.Visible = true
		sc.Scale = T.Motion.OpenFrom
		holder.Position = UDim2.fromScale(0.5, 0.56 + T.Motion.OpenSlide)
		scrim.BackgroundTransparency = 1
		TweenService:Create(sc, TweenInfo.new(T.Motion.OpenTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(holder, TweenInfo.new(T.Motion.OpenTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.56) }):Play()
		TweenService:Create(scrim, TweenInfo.new(0.2), { BackgroundTransparency = 0.45 }):Play()
		UI.play("open")
		if p.OnOpen then
			p.OnOpen()
		end
	end
	function win.Close(silent)
		if not isOpen then
			return
		end
		isOpen = false
		openWindows[win] = nil
		windowsSignal:Fire()
		local tw = TweenService:Create(sc, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.8 })
		tw.Completed:Connect(function()
			if not isOpen then
				root.Visible = false
			end
		end)
		tw:Play()
		TweenService:Create(scrim, TweenInfo.new(0.14), { BackgroundTransparency = 1 }):Play()
		if p.OnClose then
			p.OnClose(silent)
		end
	end
	function win.Toggle()
		if isOpen then
			win.Close()
		else
			win.Open()
		end
	end
	return win
end

function UI.closeAllWindows()
	for w in pairs(openWindows) do
		w.Close(true)
	end
end

-- Abas: lista de { Id, Text, Icon? }. Retorna funcao select(id)
local DEFAULT_TAB_ICONS = {
	Login = "gift", Baus = "chest", Missoes = "scroll", Temporada = "trophy", Codigos = "ticket",
	Itens = "bag", Beneficios = "star", Gemas = "gem",
	Portal = "portal", Album = "book", Dupes = "swap",
	Todos = "star",
	Torre = "tower", Ginasios = "trophy", Treino = "sword",
}
function UI.tabs(parent, list, p, onSelect)
	p = p or {}
	local bar = UI.frame(parent, { Name = "Tabs", Size = p.Size or UDim2.fromScale(1, 0.11), Position = p.Position or UDim2.fromScale(0, 0) })
	-- altura das abas: no minimo o toque (44 px), no maximo 50 px (nao crescem no tablet)
	UI.clampHeight(bar, T.TouchMin, p.MaxHeight or 50)
	local n = #list
	local gap = 0.02
	local w = math.min(p.MaxWidth or 0.3, (1 - gap * (n - 1)) / n)
	local buttons = {}
	local current
	local function select(id)
		current = id
		for bid, b in pairs(buttons) do
			local active = (bid == id)
			UI.paint(b, if active then (p.ActiveColor or "lendario") else "slot")
			local lbl = b:FindFirstChild("Face") and b.Face:FindFirstChild("Label")
			if lbl and lbl:IsA("TextLabel") then
				lbl.TextColor3 = if active then T.Palette.onDark else T.Palette.inkSoft
			end
		end
		if onSelect then
			onSelect(id)
		end
	end
	for i, t in ipairs(list) do
		local iconName = if t.Icon ~= false then (t.Icon or DEFAULT_TAB_ICONS[t.Id]) else nil
		buttons[t.Id] = UI.button(bar, {
			Name = "Tab_" .. t.Id,
			Text = t.Text,
			Icon = iconName,
			Layout = if iconName then "row" else "text",
			Color = "slot",
			Size = UDim2.fromScale(w, 1),
			Position = UDim2.fromScale((i - 1) * (w + gap), 0),
			Corner = 0.35,
			Role = "Small",
			OnClick = function()
				if current ~= t.Id then
					select(t.Id)
				end
			end,
		})
	end
	return select, buttons
end

-- Marca "!" vermelha no canto de cima de um botao (ex.: aba com recompensa para pegar)
function UI.badge(button: GuiObject, visible: boolean)
	local b = button:FindFirstChild("Badge")
	if not b then
		if not visible then
			return
		end
		b = UI.frame(button, { Name = "Badge", Size = UDim2.fromScale(0.3, 0.62), Position = UDim2.fromScale(0.97, -0.22), AnchorPoint = Vector2.new(0.5, 0), Color = "red", Aspect = 1, ZIndex = (button.ZIndex or 1) + 4 })
		UI.stroke(b)
		UI.text(b, "!", { Size = UDim2.fromScale(1, 1), Role = "Small", ZIndex = (button.ZIndex or 1) + 5 })
	end
	b.Visible = visible
end

--------------------------------------------------------------------
-- Comunicacao entre telas (mesmo cliente: o modulo e compartilhado)
--------------------------------------------------------------------
local screenSignal = Instance.new("BindableEvent")

-- So no Studio: gancho de teste para abrir telas e acionar botoes do kit sem clicar
if game:GetService("RunService"):IsStudio() and player then
	task.spawn(function()
		local pg = player:WaitForChild("PlayerGui")
		if pg:FindFirstChild("_UITest") then
			return
		end
		local hook = Instance.new("BindableFunction")
		hook.Name = "_UITest"
		hook.OnInvoke = function(action, a, ...)
			if action == "open" then
				screenSignal:Fire(a, ...)
			elseif action == "click" then
				local fn = clickers[a]
				if fn then
					task.spawn(fn, a)
					return true
				end
				return false
			end
			return nil
		end
		hook.Parent = pg
	end)
end

-- Abre uma tela pelo nome: "Team", "Bag", "Base", "Shop", "Rewards", "Album", "Toast"
function UI.open(id: string, ...)
	screenSignal:Fire(id, ...)
end

function UI.onOpen(id: string, fn)
	return screenSignal.Event:Connect(function(x, ...)
		if x == id then
			fn(...)
		end
	end)
end

-- Seletor visual unificado de personagem (reutiliza a tela Equipe com filtros e cartoes 3D;
-- chamada direta em Luau para preservar callbacks como OnPick, GetBadge e IsEligible)
local characterPickerHandler = nil
function UI.onPickCharacter(fn)
	characterPickerHandler = fn
end

function UI.pickCharacter(opts)
	if characterPickerHandler then
		characterPickerHandler(opts)
	end
end

function UI.toast(text: string, kind: string?)
	UI.open("Toast", text, kind)
end

-- Batalha aberta? (o BattleClient marca o atributo InBattle no PlayerGui)
function UI.inBattle(): boolean
	local pg = player and player:FindFirstChildOfClass("PlayerGui")
	return pg ~= nil and pg:GetAttribute("InBattle") == true
end

function UI.onBattle(fn)
	task.spawn(function()
		local pg = player:WaitForChild("PlayerGui")
		pg:GetAttributeChangedSignal("InBattle"):Connect(function()
			fn(pg:GetAttribute("InBattle") == true)
		end)
	end)
end

-- Controle deslizante 0..1 (arrastar ou tocar). onChange(valor, terminou)
-- A area de toque tem no minimo 44 px de altura.
function UI.slider(parent, p, onChange)
	p = p or {}
	local holder = UI.frame(parent, { Name = p.Name or "Slider", Size = p.Size, Position = p.Position, AnchorPoint = p.AnchorPoint, LayoutOrder = p.LayoutOrder })
	local track = UI.frame(holder, { Name = "Track", Size = UDim2.fromScale(1, 0.32), Position = UDim2.fromScale(0, 0.5), AnchorPoint = Vector2.new(0, 0.5), Color = "track", Corner = T.Corner.Pill })
	UI.stroke(track)
	local fill = UI.frame(track, { Name = "Fill", Size = UDim2.fromScale(0.5, 1), Color = p.Color or "teal", Corner = T.Corner.Pill })
	local knob = UI.frame(holder, { Name = "Knob", Size = UDim2.fromScale(0.9, 0.9), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Color = "onDark", Corner = T.Corner.Pill, Aspect = 1, AspectAxis = Enum.DominantAxis.Height, ZIndex = 3 })
	UI.stroke(knob)
	local hit = Instance.new("TextButton")
	hit.Name = "Hit"
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.Size = UDim2.fromScale(1, 1)
	hit.Position = UDim2.fromScale(0.5, 0.5)
	hit.AnchorPoint = Vector2.new(0.5, 0.5)
	hit.ZIndex = 5
	hit.Parent = holder
	UI.clampHeight(hit, T.TouchMin, math.huge)
	local value = 0.5
	local function set(v)
		value = math.clamp(v, 0, 1)
		fill.Size = UDim2.fromScale(value, 1)
		knob.Position = UDim2.fromScale(value, 0.5)
	end
	local dragging = false
	local function fromX(x)
		local a, w = track.AbsolutePosition.X, track.AbsoluteSize.X
		if w <= 0 then
			return value
		end
		return (x - a) / w
	end
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			set(fromX(input.Position.X))
			if onChange then
				onChange(value, false)
			end
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			set(fromX(input.Position.X))
			if onChange then
				onChange(value, false)
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			if onChange then
				onChange(value, true)
			end
		end
	end)
	set(p.Value or 0.5)
	return holder, set
end

-- Recria o conteudo de uma lista sem perder a rolagem (atualizacao do perfil nao volta ao topo)
function UI.keepScroll(sf, rebuild)
	local pos = sf.CanvasPosition
	rebuild()
	local function restore()
		if not sf.Parent then
			return
		end
		local maxY = math.max(0, sf.AbsoluteCanvasSize.Y - sf.AbsoluteWindowSize.Y)
		sf.CanvasPosition = Vector2.new(pos.X, math.clamp(pos.Y, 0, maxY))
	end
	task.defer(function()
		restore()
		task.defer(restore)
	end)
end

-- Altura limitada (em escala, com piso e teto em pixels)
function UI.clampHeight(obj, minH, maxH)
	local c = obj:FindFirstChild("HeightClamp") or Instance.new("UISizeConstraint")
	c.Name = "HeightClamp"
	c.MinSize = Vector2.new(0, minH or 0)
	c.MaxSize = Vector2.new(math.huge, maxH or math.huge)
	c.Parent = obj
	return obj
end

-- Ocupa o espaco entre a borda de baixo de 'topObj' e a de cima de 'bottomObj' (irmaos, mesmo pai).
-- Usado para listas abaixo das abas: as abas tem altura limitada e a lista acompanha.
function UI.fillBetween(obj, topObj, bottomObj, gapPx)
	gapPx = gapPx or 6
	local parent = obj.Parent
	local pending = false
	local function fit()
		pending = false
		local pTop, pH = parent.AbsolutePosition.Y, parent.AbsoluteSize.Y
		if pH <= 0 then
			return
		end
		-- tudo em fracao da altura do pai: nao muda com o UIScale das animacoes de abrir
		local y0 = if topObj then topObj.AbsolutePosition.Y + topObj.AbsoluteSize.Y - pTop + gapPx else 0
		local y1 = if bottomObj then bottomObj.AbsolutePosition.Y - pTop - gapPx else pH
		obj.Position = UDim2.new(obj.Position.X.Scale, obj.Position.X.Offset, y0 / pH, 0)
		obj.Size = UDim2.new(obj.Size.X.Scale, obj.Size.X.Offset, math.max(0, y1 - y0) / pH, 0)
	end
	local function queue()
		if not pending then
			pending = true
			task.defer(fit)
		end
	end
	for _, o in ipairs({ parent, topObj, bottomObj }) do
		if o then
			o:GetPropertyChangedSignal("AbsoluteSize"):Connect(queue)
			o:GetPropertyChangedSignal("AbsolutePosition"):Connect(queue)
		end
	end
	queue()
	return obj
end

-- Maiusculas com acento (string.upper nao converte á, é, ç...)
local ACCENT_UP = { ["á"] = "Á", ["à"] = "À", ["â"] = "Â", ["ã"] = "Ã", ["é"] = "É", ["ê"] = "Ê", ["í"] = "Í", ["ó"] = "Ó", ["ô"] = "Ô", ["õ"] = "Õ", ["ú"] = "Ú", ["ç"] = "Ç" }
function UI.upper(s: string): string
	s = string.upper(s)
	for a, b in pairs(ACCENT_UP) do
		s = string.gsub(s, a, b)
	end
	return s
end

-- Chip pequeno (tipo, raridade, "NOVO", com suporte opcional a icone personalizado p.Icon)
function UI.chip(parent, text, color, p)
	p = p or {}
	p.Color = color
	p.Corner = T.Corner.Pill
	p.Shadow = false
	local holder, face = UI.panel(parent, p)
	if p.Icon then
		UI.icon(face, p.Icon, {
			Name = "Icon",
			Size = UDim2.fromScale(0.28, 0.78),
			Position = UDim2.fromScale(0.06, 0.5),
			AnchorPoint = Vector2.new(0, 0.5),
			AspectAxis = Enum.DominantAxis.Height,
			ZIndex = face.ZIndex + 1,
		})
		UI.text(face, text, {
			Name = "Label",
			Size = UDim2.fromScale(0.62, 0.8),
			Position = UDim2.fromScale(0.34, 0.1),
			Role = p.Role or "Small",
			AlignX = Enum.TextXAlignment.Left,
			ZIndex = face.ZIndex + 1,
		})
	else
		UI.text(face, text, { Name = "Label", Size = UDim2.fromScale(0.86, 0.8), Position = UDim2.fromScale(0.07, 0.1), Role = p.Role or "Small", ZIndex = face.ZIndex + 1 })
	end
	return holder
end

-- Campo de pesquisa de texto (altura minima de toque e botao limpar opcional)
function UI.searchBox(parent, p)
	p = p or {}
	local holder, face = UI.panel(parent, {
		Name = p.Name or "SearchBox",
		Color = p.Color or "slot",
		Corner = p.Corner or T.Corner.Button,
		Shadow = false,
		Size = p.Size,
		Position = p.Position,
		AnchorPoint = p.AnchorPoint,
		LayoutOrder = p.LayoutOrder,
		ZIndex = p.ZIndex,
		Visible = p.Visible,
	})
	local min = Instance.new("UISizeConstraint")
	min.MinSize = Vector2.new(88, T.TouchMin)
	min.Parent = holder

	local z = holder.ZIndex
	local input = Instance.new("TextBox")
	input.Name = "Input"
	input.BackgroundTransparency = 1
	input.BorderSizePixel = 0
	input.ClearTextOnFocus = false
	input.FontFace = T.Font
	input.TextScaled = true
	input.TextWrapped = false
	input.TextTruncate = Enum.TextTruncate.AtEnd
	input.TextXAlignment = Enum.TextXAlignment.Left
	input.TextYAlignment = Enum.TextYAlignment.Center
	input.TextColor3 = colorOf("onDark")
	input.PlaceholderColor3 = colorOf("inkSoft")
	input.PlaceholderText = p.Placeholder or "Buscar nome..."
	input.Text = p.Text or ""
	input.Position = UDim2.new(0, 10, 0.5, 0)
	input.AnchorPoint = Vector2.new(0, 0.5)
	input.ZIndex = z + 1
	local lim = Instance.new("UITextSizeConstraint")
	lim.Parent = input
	register(input, "Texts", lim, p.Role or "Small")
	local stroke = Instance.new("UIStroke")
	stroke.Color = T.Outline
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = input
	register(input, "Strokes", stroke, 0.5)
	input.Parent = face

	local clearBtn = Instance.new("TextButton")
	clearBtn.Name = "Clear"
	clearBtn.Text = "X"
	clearBtn.AutoButtonColor = false
	clearBtn.BackgroundTransparency = 1
	clearBtn.BorderSizePixel = 0
	clearBtn.FontFace = T.Font
	clearBtn.TextScaled = true
	clearBtn.TextColor3 = colorOf("inkSoft")
	clearBtn.Size = UDim2.fromOffset(T.TouchMin, T.TouchMin)
	clearBtn.Position = UDim2.fromScale(1, 0.5)
	clearBtn.AnchorPoint = Vector2.new(1, 0.5)
	clearBtn.ZIndex = z + 2
	clearBtn.Visible = false
	local cMin = Instance.new("UISizeConstraint")
	cMin.MinSize = Vector2.new(T.TouchMin, T.TouchMin)
	cMin.Parent = clearBtn
	local cLim = Instance.new("UITextSizeConstraint")
	cLim.Parent = clearBtn
	register(clearBtn, "Texts", cLim, "Small")
	local cStroke = Instance.new("UIStroke")
	cStroke.Color = T.Outline
	cStroke.LineJoinMode = Enum.LineJoinMode.Round
	cStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	cStroke.Parent = clearBtn
	register(clearBtn, "Strokes", cStroke, 0.5)
	clearBtn.Parent = face

	local function syncClearState()
		local hasText = input.Text ~= ""
		clearBtn.Visible = hasText
		input.Size = UDim2.new(1, if hasText then -(T.TouchMin + 12) else -18, 0.72, 0)
	end
	syncClearState()

	clearBtn.Activated:Connect(function()
		UI.play("click")
		input.Text = ""
	end)
	clickers[clearBtn] = function()
		UI.play("click")
		input.Text = ""
	end
	input:GetPropertyChangedSignal("Text"):Connect(function()
		syncClearState()
		if p.OnChanged then
			p.OnChanged(input.Text)
		end
	end)

	return {
		Root = holder,
		Face = face,
		Input = input,
		ClearButton = clearBtn,
		Get = function(): string
			return input.Text
		end,
		Set = function(value: string?)
			input.Text = value or ""
		end,
		Clear = function()
			input.Text = ""
		end,
	}
end

return UI
