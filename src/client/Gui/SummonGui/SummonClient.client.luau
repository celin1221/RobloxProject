--[[
	SummonClient (GDD secoes 10 e 13 - Invocacao e Album)
	- Abre no ProximityPrompt do portal (atributo Portal: "Comum" ou "Premium"). Abas Portal, Album e Repetidos.
	- Chances sempre visiveis (cor por raridade), barra da garantia, invocacoes gratis.
	- Portal Premium: banner da semana; escondido onde itens aleatorios pagos sao restritos (atributo PaidRandomRestricted).
	- Invocacao Rapida: botao Invocar 3 e sem animacao. Sorte em Dobro: chances do Portal Comum em dobro na tela.
	- Animacao no cliente: o nucleo do portal abre e um raio sobe na cor da raridade (cinza, azul, roxo, dourado);
	  depois as cartas aparecem uma a uma, com brilho nas raras.
	- Album (obtidos, variantes, premios por tipo e raridade) e Repetidos (fusao e venda). Tambem abre pelo botao Album do HUD.
	O sorteio e todo no servidor (SummonService).
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TextChatService = game:GetService("TextChatService")
local StarterGui = game:GetService("StarterGui")

local gui = script.Parent
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Data = ReplicatedStorage:WaitForChild("Data")
local Characters = require(Data:WaitForChild("Characters"))
local Summon = require(Data:WaitForChild("Summon"))
local TypeChart = require(Data:WaitForChild("TypeChart"))
local Benefits = require(Data:WaitForChild("Benefits"))
local UI = require(ReplicatedStorage:WaitForChild("UI"))
local T = UI.Theme
local player = Players.LocalPlayer

local PORTAL = "Comum"
local portal = Summon.Portals[PORTAL]
local selectedBannerId = "Todos"
local bannerName = nil -- destaque da semana (Premium)
local profile = nil
local busy = false

local function pct(x)
	local s = string.format("%.1f", x * 100):gsub("%.0$", "")
	return s .. "%"
end

local function typeName(t)
	return (TypeChart.DisplayName and TypeChart.DisplayName[t]) or t
end

local function rarityColor(r)
	return T.Rarity[r] or Summon.RarityColor[r] or T.Palette.comum
end

local canvas = UI.screen(gui)
gui.DisplayOrder = 9

--------------------------------------------------------------------
-- Janela com abas
--------------------------------------------------------------------
local win = UI.window(canvas, { Name = "SummonWindow", Title = "PORTAL COMUM", Icon = "portal", Size = UDim2.fromScale(0.92, 0.86), Aspect = 1.95 })
local body = win.Body
local pages = {}
local currentTab = "Portal"
local refreshMain, refreshAlbum, refreshDupes
local selectTab = UI.tabs(body, {
	{ Id = "Portal", Text = "PORTAL" },
	{ Id = "Album", Text = "\u{c1}LBUM" },
	{ Id = "Dupes", Text = "REPETIDOS" },
}, { Size = UDim2.fromScale(0.6, 0.095), MaxWidth = 0.32 }, function(id)
	currentTab = id
	for name, f in pairs(pages) do
		f.Visible = name == id
	end
	refreshMain()
	if id == "Album" then
		refreshAlbum()
	elseif id == "Dupes" then
		refreshDupes()
	end
end)
local walletHolder, walletLabel = UI.pill(body, "coin", "gold", { Name = "Wallet", Size = UDim2.fromScale(0.3, 0.095), Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(1, 0), Aspect = 3.2, MaxSize = Vector2.new(math.huge, 46) })
local msg = UI.text(body, "", { Name = "Message", Size = UDim2.fromScale(1, 0.055), Position = UDim2.fromScale(0, 0.945), Role = "Small", Color = "hpLow" })

local function page(name)
	local f = UI.frame(body, { Name = name, Size = UDim2.fromScale(1, 0.78), Position = UDim2.fromScale(0, 0.16), Visible = name == "Portal" })
	UI.fillBetween(f, body:FindFirstChild("Tabs"), msg, 5)
	pages[name] = f
	return f
end

--------------------------------------------------------------------
-- Aba Portal + Paineis de Selecao de Anime
--------------------------------------------------------------------
local portalPage = page("Portal")
local topArea = UI.frame(portalPage, { Name = "TopArea", Size = UDim2.fromScale(1, 0.57), Position = UDim2.fromScale(0, 0) })
local rates, ratesFace = UI.panel(topArea, { Name = "Rates", Size = UDim2.fromScale(0.47, 1), Color = "slot", Corner = 0.07, Shadow = false })
UI.text(ratesFace, "CHANCES", { Name = "Title", Size = UDim2.fromScale(0.9, 0.11), Position = UDim2.fromScale(0.05, 0.02), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.5 })
local rateRows = {}
for i, r in ipairs(Summon.RarityOrder) do
	local row, rface = UI.panel(ratesFace, { Name = "Rate_" .. r, Size = UDim2.fromScale(0.9, 0.16), Position = UDim2.fromScale(0.05, 0.15 + (i - 1) * 0.18), Color = rarityColor(r), Corner = T.Corner.Pill })
	local name = UI.text(rface, UI.upper(Summon.RarityName[r]), { Name = "Name", Size = UDim2.fromScale(0.6, 0.74), Position = UDim2.fromScale(0.05, 0.13), Role = "Small", AlignX = Enum.TextXAlignment.Left })
	local val = UI.text(rface, "", { Name = "Value", Size = UDim2.fromScale(0.36, 0.74), Position = UDim2.fromScale(0.95, 0.13), AnchorPoint = Vector2.new(1, 0), Role = "Small", AlignX = Enum.TextXAlignment.Right })
	if r == "Lendario" then
		UI.shine(row)
	end
	rateRows[r] = { Name = name, Value = val }
end
local shinyLabel = UI.text(ratesFace, "\u{2726} Brilhante: " .. pct(Summon.ShinyChance) .. " em toda invoca\u{e7}\u{e3}o", { Name = "Shiny", Size = UDim2.fromScale(0.9, 0.095), Position = UDim2.fromScale(0.05, 0.885), Role = "Small", Color = "gold", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.45 })

local side = UI.frame(topArea, { Name = "Actions", Size = UDim2.fromScale(0.5, 1), Position = UDim2.fromScale(0.5, 0) })
local bannerLabel = UI.text(side, "", { Name = "Banner", Size = UDim2.fromScale(1, 0.12), Position = UDim2.fromScale(0, 0), Role = "Small", Color = "lendario", AlignX = Enum.TextXAlignment.Left })
UI.text(side, "GARANTIA DE LEND\u{c1}RIO", { Name = "PityTitle", Size = UDim2.fromScale(0.75, 0.11), Position = UDim2.fromScale(0, 0.13), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.45 })
local pityValue = UI.text(side, "", { Name = "PityValue", Size = UDim2.fromScale(0.25, 0.11), Position = UDim2.fromScale(1, 0.13), AnchorPoint = Vector2.new(1, 0), Role = "Small", Color = "lendario", AlignX = Enum.TextXAlignment.Right })
local pityBar = UI.bar(side, { Name = "Pity", Size = UDim2.fromScale(1, 0.09), Position = UDim2.fromScale(0, 0.25), FillColor = "lendario", Value = 0 })
local freeHolder, freeFace = UI.panel(side, { Name = "Free", Size = UDim2.fromScale(1, 0.14), Position = UDim2.fromScale(0, 0.37), Color = "slot", Corner = T.Corner.Pill, Shadow = false })
UI.icon(freeHolder, "ticket", { Size = UDim2.fromScale(0.14, 1.25), Position = UDim2.fromScale(0.02, 0.5), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 3 })
local freeLabel = UI.text(freeFace, "", { Name = "Text", Size = UDim2.fromScale(0.78, 0.72), Position = UDim2.fromScale(0.18, 0.14), Role = "Small", AlignX = Enum.TextXAlignment.Left })

-- botoes de invocar (altura generosa para toque >= 44 px ate em celulares pequenos)
local function summonButton(name, x, w)
	local b, face = UI.button(side, { Name = name, Color = "green", Size = UDim2.fromScale(w, 0.44), Position = UDim2.fromScale(x, 0.55), Corner = 0.22, Sound = false })
	UI.text(face, "", { Name = "Title", Size = UDim2.fromScale(0.9, 0.38), Position = UDim2.fromScale(0.05, 0.08), Role = "Body" })
	local price = UI.frame(face, { Name = "Price", Size = UDim2.fromScale(0.9, 0.36), Position = UDim2.fromScale(0.05, 0.54) })
	local pl = Instance.new("UIListLayout")
	pl.FillDirection = Enum.FillDirection.Horizontal
	pl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	pl.VerticalAlignment = Enum.VerticalAlignment.Center
	pl.Padding = UDim.new(0.04, 0)
	pl.SortOrder = Enum.SortOrder.LayoutOrder
	pl.Parent = price
	UI.icon(price, "coin", { Name = "Icon", Size = UDim2.fromScale(0.3, 1), LayoutOrder = 1 })
	local t = UI.text(price, "", { Name = "Value", Size = UDim2.fromScale(0.6, 1), Role = "Body", AlignX = Enum.TextXAlignment.Left, LayoutOrder = 2 })
	t.AutomaticSize = Enum.AutomaticSize.None
	return b
end
local one = summonButton("Summon1", 0, 0.48)
local three = summonButton("Summon3", 0.52, 0.48)
three.Visible = false
local ten = summonButton("Summon10", 0.52, 0.48)

-- Faixa inferior com paineis de selecao de anime (estilo banner ilustrado)
local bannerStrip = UI.frame(portalPage, { Name = "BannerStrip", Size = UDim2.fromScale(1, 0.40), Position = UDim2.fromScale(0, 0.60) })
UI.text(bannerStrip, "ESCOLHER ANIME / ESTRELA", {
	Name = "Title",
	Size = UDim2.fromScale(0.38, 0.19),
	Position = UDim2.fromScale(0, 0),
	Role = "Small",
	Color = "inkSoft",
	AlignX = Enum.TextXAlignment.Left,
	StrokeMult = 0.45,
})
local bannerPoolLabel = UI.text(bannerStrip, "", {
	Name = "PoolInfo",
	Size = UDim2.fromScale(0.62, 0.19),
	Position = UDim2.fromScale(1, 0),
	AnchorPoint = Vector2.new(1, 0),
	Role = "Small",
	Color = "gold",
	AlignX = Enum.TextXAlignment.Right,
	StrokeMult = 0.45,
})
local bannersRow = UI.frame(bannerStrip, { Name = "BannersRow", Size = UDim2.fromScale(1, 0.78), Position = UDim2.fromScale(0, 0.22) })

local bannerButtons = {}
local bannerCount = #Summon.BannerOrder
local bannerGap = 0.018
local bannerW = (1 - bannerGap * math.max(0, bannerCount - 1)) / math.max(1, bannerCount)

local function updateBannerSelection()
	local activeCfg = Summon.GetBanner(selectedBannerId)
	bannerPoolLabel.Text = activeCfg.Subtitle or activeCfg.Name
	for id, entry in pairs(bannerButtons) do
		local isSel = id == selectedBannerId
		local accent = entry.Config.Accent or T.Palette.gold
		entry.Stroke.Color = if isSel then accent:Lerp(Color3.new(1, 1, 1), 0.35) else Color3.fromRGB(48, 38, 86)
		entry.Stroke.Thickness = if isSel then 3 else 1.5
		entry.Scale.Scale = if isSel then 1.02 else 0.98
		entry.ActiveTag.Visible = isSel
		entry.ShadeGrad.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, if isSel then 0.25 else 0.45),
			NumberSequenceKeypoint.new(0.55, if isSel then 0.38 else 0.56),
			NumberSequenceKeypoint.new(1, 0.14),
		})
	end
end

local function fetchBannerFeatured()
	if not portal.Banner then
		bannerName = nil
		refreshMain()
		return
	end
	local curPortal = PORTAL
	local curBanner = selectedBannerId
	task.spawn(function()
		local ok, name = pcall(function()
			return Remotes:WaitForChild("SummonBanner"):InvokeServer(curPortal, curBanner)
		end)
		if ok and PORTAL == curPortal and selectedBannerId == curBanner then
			bannerName = name
			refreshMain()
		end
	end)
end

for idx, bannerId in ipairs(Summon.BannerOrder) do
	local cfg = Summon.Banners[bannerId]
	local x = (idx - 1) * (bannerW + bannerGap)
	local btn = Instance.new("TextButton")
	btn.Name = "BannerPanel_" .. bannerId
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.BackgroundColor3 = Color3.fromRGB(22, 16, 48)
	btn.BorderSizePixel = 0
	btn.Size = UDim2.fromScale(bannerW, 1)
	btn.Position = UDim2.fromScale(x, 0)
	btn.ClipsDescendants = true
	btn.ZIndex = 2
	btn.Parent = bannersRow

	local minTouch = Instance.new("UISizeConstraint")
	minTouch.MinSize = Vector2.new(44, 44)
	minTouch.Parent = btn

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0.14, 0)
	bCorner.Parent = btn

	local bScale = Instance.new("UIScale")
	bScale.Parent = btn

	local bStroke = Instance.new("UIStroke")
	bStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bStroke.Color = Color3.fromRGB(48, 38, 86)
	bStroke.Thickness = 1.5
	bStroke.Parent = btn

	local art = Instance.new("ImageLabel")
	art.Name = "Artwork"
	art.BackgroundTransparency = 1
	art.Image = "rbxassetid://" .. tostring(cfg.ImageId)
	art.ScaleType = Enum.ScaleType.Crop
	art.Size = UDim2.fromScale(1, 1)
	art.ZIndex = 2
	art.Parent = btn

	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.fromRGB(12, 8, 28)
	shade.BorderSizePixel = 0
	shade.ZIndex = 3
	shade.Parent = btn
	local shadeGrad = Instance.new("UIGradient")
	shadeGrad.Rotation = 90
	shadeGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.55, 0.45),
		NumberSequenceKeypoint.new(1, 0.14),
	})
	shadeGrad.Parent = shade

	local activePill, activeFace = UI.panel(btn, {
		Name = "SelectedTag",
		Size = UDim2.fromScale(0.38, 0.25),
		Position = UDim2.fromScale(0.96, 0.08),
		AnchorPoint = Vector2.new(1, 0),
		Color = cfg.Accent or "gold",
		Corner = T.Corner.Pill,
		Shadow = false,
		Visible = false,
		ZIndex = 5,
	})
	UI.text(activeFace, "\u{2605} ATIVO", { Name = "Label", Size = UDim2.fromScale(0.92, 0.8), Position = UDim2.fromScale(0.04, 0.1), Role = "Small", StrokeMult = 0.45, ZIndex = 6 })

	local titleBar = UI.frame(btn, { Name = "BottomRow", Size = UDim2.fromScale(0.92, 0.34), Position = UDim2.fromScale(0.04, 0.62), ZIndex = 5 })
	UI.icon(titleBar, cfg.Icon or "star", { Name = "Icon", Size = UDim2.fromScale(0.18, 0.9), Position = UDim2.fromScale(0, 0.05), DominantAxis = Enum.DominantAxis.Height, ZIndex = 6 })
	UI.text(titleBar, cfg.Short or cfg.Name, { Name = "Name", Size = UDim2.fromScale(0.80, 0.9), Position = UDim2.fromScale(0.19, 0.05), Role = "Body", AlignX = Enum.TextXAlignment.Left, ZIndex = 6 })

	btn.Activated:Connect(function()
		if busy or selectedBannerId == bannerId then
			return
		end
		selectedBannerId = bannerId
		UI.play("click")
		updateBannerSelection()
		refreshMain()
		fetchBannerFeatured()
	end)

	bannerButtons[bannerId] = {
		Button = btn,
		Config = cfg,
		Stroke = bStroke,
		Scale = bScale,
		ActiveTag = activePill,
		ShadeGrad = shadeGrad,
	}
end
updateBannerSelection()

local function setSummonButton(b, title, cost, icon, free)
	local face = b.Face
	face.Title.Text = title
	UI.setIcon(face.Price.Icon, if free then "ticket" else icon)
	face.Price.Value.Text = if free then "GR\u{c1}TIS" else UI.fmt(cost)
end

refreshMain = function()
	if not profile then
		return
	end
	local gems = portal.Currency == "Gems"
	local icon = if gems then "gem" else "coin"
	local bCfg = Summon.GetBanner(selectedBannerId)
	win.Title.Text = UI.upper(portal.Name) .. " \u{b7} " .. UI.upper(bCfg.Short or bCfg.Name)
	UI.paint(win.Header, if gems then "lendario" else "header")
	UI.setIcon(walletHolder.Icon, icon)
	walletLabel.TextColor3 = if gems then T.Palette.gems else T.Palette.gold
	UI.countTo(walletLabel, if gems then (profile.Gems or 0) else (profile.Gold or 0))
	local ratesNow = Summon.RatesFor(PORTAL, profile.Benefits)
	local lucky = PORTAL == "Comum" and Benefits.Has(profile, "SorteEmDobro")
	for _, r in ipairs(Summon.RarityOrder) do
		local text = pct(ratesNow[r] or 0)
		if lucky and (r == "Epico" or r == "Lendario") then
			text ..= " x2"
		end
		rateRows[r].Value.Text = text
	end
	if portal.Banner then
		bannerLabel.Text = if bannerName then string.format("\u{2605} DESTAQUE (%s): %s (%s)", bCfg.Name, bannerName, pct((ratesNow.Lendario or 0) * portal.Banner.Share)) else ("\u{2605} Estrela " .. bCfg.Name .. ": sem destaque Lend\u{e1}rio")
	else
		bannerLabel.Text = "\u{2605} Estrela selecionada: " .. bCfg.Name
	end
	local pity = (profile.SummonPity and profile.SummonPity[portal.PityKey]) or 0
	pityValue.Text = string.format("%d/%d", pity, portal.PityAt)
	UI.setBar(pityBar, pity / portal.PityAt, "lendario")
	local free = (profile.Tickets and profile.Tickets[portal.PityKey]) or 0
	freeHolder.Visible = free > 0
	freeLabel.Text = free .. " invoca\u{e7}\u{e3}o" .. (if free > 1 then "\u{f5}es" else "") .. " gr\u{e1}tis"
	local quick = Benefits.Has(profile, "InvocacaoRapida")
	three.Visible = quick
	if quick then
		one.Size = UDim2.fromScale(0.31, 0.44)
		three.Size = UDim2.fromScale(0.31, 0.44)
		three.Position = UDim2.fromScale(0.345, 0.55)
		ten.Size = UDim2.fromScale(0.31, 0.44)
		ten.Position = UDim2.fromScale(0.69, 0.55)
	else
		one.Size = UDim2.fromScale(0.48, 0.44)
		ten.Size = UDim2.fromScale(0.48, 0.44)
		ten.Position = UDim2.fromScale(0.52, 0.55)
	end
	setSummonButton(one, "INVOCAR 1", portal.Cost, icon, free > 0)
	setSummonButton(three, "INVOCAR " .. Benefits.QuickSummonCount, portal.Cost * Benefits.QuickSummonCount, icon, false)
	setSummonButton(ten, "INVOCAR 10", portal.Cost10, icon, false)
end

--------------------------------------------------------------------
-- Animacao de Destaque 3D na Frente da Tela + Efeitos Sonoros + Portal
--------------------------------------------------------------------
local function portalModel()
	local folder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Portals")
	return folder and folder:FindFirstChild("Portal" .. PORTAL)
end

local function clonePreviewModel(modelName: string): Model?
	local folder = ReplicatedStorage:FindFirstChild("CharacterPreviews")
	local src = folder and (folder:FindFirstChild(modelName) or folder:FindFirstChild("Kaen"))
	if not src then
		return nil
	end
	return src:Clone()
end

local function frameFullBodyCamera(view: ViewportFrame, model: Model)
	local cf, size = model:GetBoundingBox()
	local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
	local front = if root then root.CFrame.LookVector else Vector3.new(0, 0, -1)
	front = Vector3.new(front.X, 0, front.Z)
	front = if front.Magnitude > 0.01 then front.Unit else Vector3.new(0, 0, -1)
	local target = cf.Position + Vector3.new(0, size.Y * 0.03, 0)
	local radius = math.max(size.Y * 0.56, math.max(size.X, size.Z) * 0.62)
	local dist = radius / math.tan(math.rad(18))
	local cam = view:FindFirstChildOfClass("Camera") or Instance.new("Camera")
	cam.FieldOfView = 36
	cam.Parent = view
	view.CurrentCamera = cam
	return { Cam = cam, Target = target, Front = front, Dist = dist, Height = size.Y }
end

local function frameChestCamera(view: ViewportFrame, model: Model)
	local head = model:FindFirstChild("Head")
	local root = model:FindFirstChild("HumanoidRootPart") or head
	if not head or not root then
		return frameFullBodyCamera(view, model)
	end
	local front = root.CFrame.LookVector
	front = Vector3.new(front.X, 0, front.Z)
	front = if front.Magnitude > 0.01 then front.Unit else Vector3.new(0, 0, -1)
	local target = head.Position - Vector3.new(0, head.Size.Y * 0.35, 0)
	local dist = head.Size.Y * 1.65 / math.tan(math.rad(17))
	local cam = view:FindFirstChildOfClass("Camera") or Instance.new("Camera")
	cam.FieldOfView = 34
	cam.Parent = view
	view.CurrentCamera = cam
	return { Cam = cam, Target = target, Front = front, Dist = dist, Height = 0 }
end

-- Sons dedicados controlaveis para poder interromper suavemente se o jogador clicar PULAR
local sfxPlayers = {}
local function playControlledSfx(soundKey: string)
	local def = UI.Sounds[soundKey]
	if not def then
		return
	end
	pcall(function()
		local s = sfxPlayers[soundKey]
		if not s then
			s = Instance.new("Sound")
			s.Name = "GachaSfx_" .. soundKey
			s.SoundId = "rbxassetid://" .. def.Id
			s.Volume = def.Volume or 0.6
			s.PlaybackSpeed = def.Pitch or 1
			s.SoundGroup = SoundService:FindFirstChild("Efeitos")
			s.Parent = SoundService
			sfxPlayers[soundKey] = s
		end
		s.TimePosition = 0
		s:Play()
	end)
end

local function stopShowcaseSfx()
	for _, s in pairs(sfxPlayers) do
		pcall(function()
			if s.IsPlaying then
				s:Stop()
			end
		end)
	end
end

-- Overlay de revelacao com personagem 3D girando na frente da tela
local showcase = UI.frame(canvas, { Name = "SummonShowcase", Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0, 0), Visible = false, ZIndex = 40 })
local showScrim = Instance.new("Frame")
showScrim.Name = "Scrim"
showScrim.Size = UDim2.fromScale(3, 3)
showScrim.Position = UDim2.fromScale(0.5, 0.5)
showScrim.AnchorPoint = Vector2.new(0.5, 0.5)
showScrim.BackgroundColor3 = Color3.fromRGB(10, 6, 26)
showScrim.BackgroundTransparency = 1
showScrim.BorderSizePixel = 0
showScrim.ZIndex = 40
showScrim.Parent = showcase

local showBurstBg = Instance.new("ImageLabel")
showBurstBg.Name = "Sunburst"
showBurstBg.BackgroundTransparency = 1
showBurstBg.Image = "rbxassetid://" .. tostring(UI.Icons.summon_sunburst)
showBurstBg.ImageTransparency = 1
showBurstBg.Size = UDim2.fromScale(0.85, 0.85)
showBurstBg.Position = UDim2.fromScale(0.5, 0.47)
showBurstBg.AnchorPoint = Vector2.new(0.5, 0.5)
showBurstBg.ZIndex = 41
showBurstBg.Parent = showcase
do
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.Parent = showBurstBg
end

local showRing = Instance.new("Frame")
showRing.Name = "PulseRing"
showRing.Size = UDim2.fromScale(0.28, 0.28)
showRing.Position = UDim2.fromScale(0.5, 0.47)
showRing.AnchorPoint = Vector2.new(0.5, 0.5)
showRing.BackgroundTransparency = 1
showRing.Visible = false
showRing.ZIndex = 42
showRing.Parent = showcase
do
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.Parent = showRing
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0.5, 0)
	rc.Parent = showRing
end
local showRingStroke = Instance.new("UIStroke")
showRingStroke.Thickness = 5
showRingStroke.Color = T.Palette.gold
showRingStroke.Parent = showRing

local orbCore = Instance.new("Frame")
orbCore.Name = "ChargeOrb"
orbCore.Size = UDim2.fromScale(0.18, 0.18)
orbCore.Position = UDim2.fromScale(0.5, 0.47)
orbCore.AnchorPoint = Vector2.new(0.5, 0.5)
orbCore.BackgroundColor3 = Color3.new(1, 1, 1)
orbCore.BorderSizePixel = 0
orbCore.Visible = false
orbCore.ZIndex = 43
orbCore.Parent = showcase
do
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.Parent = orbCore
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = orbCore
end
local orbScale = Instance.new("UIScale")
orbScale.Parent = orbCore

local fxLayer = UI.frame(showcase, { Name = "Particles", Size = UDim2.fromScale(1, 1), ZIndex = 42 })

local heroHolder = UI.frame(showcase, { Name = "HeroStage", Size = UDim2.fromScale(0.46, 0.58), Position = UDim2.fromScale(0.5, 0.46), AnchorPoint = Vector2.new(0.5, 0.5), Aspect = 0.9, ZIndex = 44 })
local heroScale = Instance.new("UIScale")
heroScale.Scale = 0.1
heroScale.Parent = heroHolder

local showView = Instance.new("ViewportFrame")
showView.Name = "HeroViewport"
showView.Size = UDim2.fromScale(1, 1)
showView.BackgroundTransparency = 1
showView.Ambient = Color3.fromRGB(205, 200, 224)
showView.LightColor = Color3.fromRGB(255, 250, 238)
showView.LightDirection = Vector3.new(-0.35, -0.9, -0.55)
showView.ZIndex = 45
showView.Parent = heroHolder

local rarityBanner, rarityBannerFace = UI.panel(showcase, { Name = "RarityBanner", Size = UDim2.fromScale(0.38, 0.085), Position = UDim2.fromScale(0.5, 0.09), AnchorPoint = Vector2.new(0.5, 0.5), Color = "lendario", Corner = T.Corner.Pill, ZIndex = 46, Visible = false })
local rarityBannerLabel = UI.text(rarityBannerFace, "", { Name = "Text", Size = UDim2.fromScale(0.92, 0.78), Position = UDim2.fromScale(0.04, 0.11), Role = "Heading", ZIndex = 47 })

local nameBanner = UI.frame(showcase, { Name = "NameBanner", Size = UDim2.fromScale(0.68, 0.22), Position = UDim2.fromScale(0.5, 0.84), AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, ZIndex = 46 })
local heroNameLabel = UI.text(nameBanner, "", { Name = "HeroName", Size = UDim2.fromScale(1, 0.44), Position = UDim2.fromScale(0, 0), Role = "Title", Color = "onDark", ZIndex = 47 })
local heroSubLabel = UI.text(nameBanner, "", { Name = "HeroMeta", Size = UDim2.fromScale(1, 0.28), Position = UDim2.fromScale(0, 0.46), Role = "Body", Color = "gold", ZIndex = 47 })
local heroTagsLabel = UI.text(nameBanner, "", { Name = "HeroTags", Size = UDim2.fromScale(1, 0.22), Position = UDim2.fromScale(0, 0.76), Role = "Small", Color = "inkSoft", ZIndex = 47 })

local showFlash = Instance.new("Frame")
showFlash.Name = "Flash"
showFlash.Size = UDim2.fromScale(1, 1)
showFlash.Position = UDim2.fromScale(0, 0)
showFlash.BackgroundColor3 = Color3.new(1, 1, 1)
showFlash.BackgroundTransparency = 1
showFlash.BorderSizePixel = 0
showFlash.ZIndex = 48
showFlash.Parent = showcase

local skipFlag = false
local skipBtn = UI.button(showcase, {
	Name = "SkipShowcase",
	Text = "PULAR",
	Icon = "arrow",
	Layout = "row",
	Color = "slot",
	Size = UDim2.fromScale(0.16, 0.085),
	Position = UDim2.fromScale(0.97, 0.94),
	AnchorPoint = Vector2.new(1, 1),
	Role = "Small",
	ZIndex = 50,
	Visible = false,
	OnClick = function()
		skipFlag = true
	end,
})

local function triggerWorldPortalBeam(rarity: string, shiny: boolean)
	task.spawn(function()
		local model = portalModel()
		local core = model and model:FindFirstChild("Core")
		if not core then
			return
		end
		local color = rarityColor(rarity)
		local baseColor = core.Color
		local light = core:FindFirstChild("Glow")
		TweenService:Create(core, TweenInfo.new(0.25), { Color = color }):Play()
		if light then
			light.Color = color
			TweenService:Create(light, TweenInfo.new(0.25), { Brightness = 3, Range = 22 }):Play()
		end
		local beam = Instance.new("Part")
		beam.Name = "SummonBeam"
		beam.Shape = Enum.PartType.Cylinder
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanQuery = false
		beam.CanTouch = false
		beam.CastShadow = false
		beam.Material = Enum.Material.Neon
		beam.Color = color
		beam.Transparency = 0.2
		local base = core.Position
		beam.Size = Vector3.new(1, 3, 3)
		beam.CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90))
		beam.Parent = workspace
		TweenService:Create(beam, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(80, 3, 3),
			CFrame = CFrame.new(base + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		}):Play()
		task.delay(1.1, function()
			TweenService:Create(beam, TweenInfo.new(0.4), { Transparency = 1, Size = Vector3.new(80, 0.2, 0.2) }):Play()
			TweenService:Create(core, TweenInfo.new(0.5), { Color = baseColor }):Play()
			if light then
				TweenService:Create(light, TweenInfo.new(0.5), { Brightness = 1.5, Range = 16, Color = baseColor }):Play()
			end
			task.delay(0.55, function()
				beam:Destroy()
			end)
		end)
	end)
end

local function pickShowcaseHero(results)
	local best = results[1]
	local bestRank = 0
	for _, r in ipairs(results) do
		local rank = (table.find(Summon.RarityOrder, r.Rarity) or 1) * 10
		if r.Variant then
			rank += 4
		end
		if r.New then
			rank += 1
		end
		if rank > bestRank then
			bestRank = rank
			best = r
		end
	end
	return best
end

local function spawnUiSparkles(color: Color3, count: number)
	UI.clear(fxLayer)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + math.rad((i * 19) % 25)
		local star = Instance.new("ImageLabel")
		star.BackgroundTransparency = 1
		star.Image = "rbxassetid://" .. tostring(UI.Icons.sparkle)
		star.ImageColor3 = if i % 3 == 0 then Color3.fromRGB(255, 248, 185) else color
		star.Size = UDim2.fromScale(0.05, 0.05)
		star.Position = UDim2.fromScale(0.5, 0.46)
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.ZIndex = 43
		star.Parent = fxLayer
		local ar = Instance.new("UIAspectRatioConstraint")
		ar.AspectRatio = 1
		ar.Parent = star
		local dist = 0.28 + (i % 4) * 0.06
		local tx = 0.5 + math.cos(angle) * dist
		local ty = 0.46 + math.sin(angle) * (dist * 1.1)
		TweenService:Create(star, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(tx, ty),
			ImageTransparency = 1,
			Size = UDim2.fromScale(0.015, 0.015),
			Rotation = (i % 2 == 0 and 180 or -180),
		}):Play()
	end
end

local function playShowcase(results)
	local hero = pickShowcaseHero(results)
	if not hero then
		return
	end
	local rCol = rarityColor(hero.Rarity)
	local shiny = hero.Variant ~= nil
	local tierIdx = table.find(Summon.RarityOrder, hero.Rarity) or 1

	skipFlag = false
	showcase.Visible = true
	showScrim.BackgroundTransparency = 1
	showFlash.BackgroundTransparency = 1
	showBurstBg.ImageTransparency = 1
	showBurstBg.Rotation = 0
	showBurstBg.ImageColor3 = if shiny then Color3.fromRGB(255, 240, 140) else rCol
	showRing.Visible = false
	orbCore.Visible = true
	orbCore.BackgroundColor3 = rCol
	orbScale.Scale = 0.1
	heroHolder.Visible = true
	heroScale.Scale = 0.01
	showView.ImageTransparency = 1
	rarityBanner.Visible = false
	nameBanner.Visible = false
	skipBtn.Visible = false
	UI.clear(showView)
	UI.clear(fxLayer)

	local def = Characters.Get(hero.CharacterId)
	local modelName = hero.ModelName or (def and def.ModelName) or hero.CharacterId
	local previewModel = clonePreviewModel(modelName)
	local framing = nil
	if previewModel then
		previewModel.Parent = showView
		framing = frameFullBodyCamera(showView, previewModel)
		if framing then
			local dir0 = framing.Front
			framing.Cam.CFrame = CFrame.lookAt(framing.Target + dir0 * framing.Dist + Vector3.new(0, framing.Height * 0.08, 0), framing.Target)
		end
	end

	-- Fase 1 (0 -> 0.40s): Carga rapida + antecipacao sonora (aquece ViewportFrame durante a carga)
	TweenService:Create(showScrim, TweenInfo.new(0.25), { BackgroundTransparency = 0.16 }):Play()
	TweenService:Create(orbScale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.25 }):Play()
	playControlledSfx("summon_charge")
	playControlledSfx("summon_shimmer")
	triggerWorldPortalBeam(hero.Rarity, shiny)

	local t0 = os.clock()
	while os.clock() - t0 < 0.40 and not skipFlag do
		if os.clock() - t0 > 0.22 then
			skipBtn.Visible = true
		end
		task.wait()
	end

	if not skipFlag then
		-- Fase 2 (0.40s -> 1.90s): Explosao na frente da tela + Personagem 3D rodando + SFX estimulante
		orbCore.Visible = false
		skipBtn.Visible = true
		playControlledSfx("summon_reveal")
		if tierIdx >= 4 or shiny then
			playControlledSfx("summon_legendary")
		elseif tierIdx == 3 then
			playControlledSfx("summon_epic")
		end

		showFlash.BackgroundColor3 = if shiny then Color3.fromRGB(255, 250, 200) else rCol:Lerp(Color3.new(1, 1, 1), 0.45)
		showFlash.BackgroundTransparency = 0.22
		TweenService:Create(showFlash, TweenInfo.new(0.36, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()

		showRing.Visible = true
		showRing.Size = UDim2.fromScale(0.2, 0.2)
		showRingStroke.Color = rCol
		showRingStroke.Transparency = 0
		TweenService:Create(showRing, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromScale(0.9, 0.9) }):Play()
		TweenService:Create(showRingStroke, TweenInfo.new(0.6), { Transparency = 1 }):Play()

		showBurstBg.ImageTransparency = 0.18
		showView.ImageTransparency = 0
		showView.Size = UDim2.new(1, 1, 1, 1)
		task.defer(function()
			showView.Size = UDim2.fromScale(1, 1)
		end)
		heroScale.Scale = 0.14
		TweenService:Create(heroScale, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		spawnUiSparkles(rCol, if tierIdx >= 3 or shiny then 16 else 10)

		UI.paint(rarityBanner, hero.Rarity:lower())
		rarityBannerLabel.Text = (if shiny then "\u{2726} " else "\u{2605} ") .. UI.upper(Summon.RarityName[hero.Rarity] or hero.Rarity) .. (if shiny then " BRILHANTE \u{2726}" else " \u{2605}")
		rarityBanner.Visible = true

		local animeName = Characters.AnimeDisplay(hero.Anime or (def and def.Anime) or "Generico")
		heroNameLabel.Text = UI.upper(hero.Name)
		heroSubLabel.Text = animeName .. " \u{b7} " .. UI.upper(typeName(hero.Type))
		local metaTags = {}
		if #results > 1 then
			table.insert(metaTags, "DESTAQUE DE " .. #results .. " INVOCA\u{c7}\u{d5}ES")
		end
		if hero.New then
			table.insert(metaTags, "NOVO NA COLE\u{c7}\u{c3}O!")
		end
		if hero.Banner then
			table.insert(metaTags, "DESTAQUE DA ESTRELA")
		end
		heroTagsLabel.Text = table.concat(metaTags, "  \u{b7}  ")
		nameBanner.Visible = true

		local duration = if tierIdx >= 4 or shiny then 1.85 elseif tierIdx == 3 then 1.65 else 1.45
		local spinStart = os.clock()
		local spinConn = RunService.RenderStepped:Connect(function()
			local elapsed = os.clock() - spinStart
			showBurstBg.Rotation = (elapsed * 55) % 360
			if framing then
				local p = math.clamp(elapsed / 0.72, 0, 1)
				local fastEase = 1 - (1 - p) ^ 3
				local angle = fastEase * math.pi * 4 + elapsed * 1.35
				local dir = CFrame.fromAxisAngle(Vector3.yAxis, angle) * framing.Front
				local pos = framing.Target + dir * framing.Dist + Vector3.new(0, framing.Height * 0.08, 0)
				framing.Cam.CFrame = CFrame.lookAt(pos, framing.Target)
			end
		end)

		while os.clock() - spinStart < duration and not skipFlag do
			task.wait()
		end
		spinConn:Disconnect()
	end

	if skipFlag then
		stopShowcaseSfx()
	end
	if previewModel then
		previewModel:Destroy()
	end
	UI.clear(showView)
	UI.clear(fxLayer)
	showcase.Visible = false
end

--------------------------------------------------------------------
-- Cartas reveladas (com previa 3D dos personagens obtidos)
--------------------------------------------------------------------
local reveal = UI.window(canvas, { Name = "RevealWindow", Title = "RESULTADO", Icon = "star", HeaderColor = "lendario", Size = UDim2.fromScale(0.92, 0.86), Aspect = 1.95,
	OnClose = function(silent)
		if not silent then
			task.defer(function()
				win.Open()
				refreshMain()
			end)
		end
	end,
})
local cardsBox = UI.frame(reveal.Body, { Name = "Cards", Size = UDim2.fromScale(1, 0.76), Position = UDim2.fromScale(0, 0) })
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromScale(0.18, 0.45)
grid.CellPadding = UDim2.fromScale(0.02, 0.04)
grid.FillDirectionMaxCells = 5
grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
grid.VerticalAlignment = Enum.VerticalAlignment.Center
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = cardsBox
local gridAspect = Instance.new("UIAspectRatioConstraint")
gridAspect.AspectRatio = 0.90
gridAspect.Parent = grid
local revealInfo = UI.text(reveal.Body, "", { Name = "Info", Size = UDim2.fromScale(0.72, 0.18), Position = UDim2.fromScale(0, 0.80), Role = "Small", Color = "gold", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.5 })
UI.button(reveal.Body, { Name = "OK", Text = "OK", Icon = "tick", Layout = "row", Color = "green", Size = UDim2.fromScale(0.24, 0.17), Position = UDim2.fromScale(1, 0.81), AnchorPoint = Vector2.new(1, 0), Role = "Heading",
	OnClick = function()
		reveal.Close()
	end,
})

local cardFramesToSpin = {}
local cardSpinConn: RBXScriptConnection? = nil
local function stopCardSpins()
	if cardSpinConn then
		cardSpinConn:Disconnect()
		cardSpinConn = nil
	end
	table.clear(cardFramesToSpin)
end

reveal.Root:GetPropertyChangedSignal("Visible"):Connect(function()
	if not reveal.Root.Visible then
		stopCardSpins()
	end
end)

local function showCards(results)
	stopCardSpins()
	UI.clear(cardsBox)
	local info = {}
	grid.CellSize = if #results <= 3 then UDim2.fromScale(0.26, 0.92) else UDim2.fromScale(0.18, 0.45)
	reveal.Open()
	for i, r in ipairs(results) do
		local rare = r.Rarity == "Epico" or r.Rarity == "Lendario" or r.Variant ~= nil
		local card, face = UI.panel(cardsBox, { Name = "Card" .. i, Color = rarityColor(r.Rarity), Corner = T.Corner.Card, LayoutOrder = i, Visible = false })
		if r.Variant then
			UI.stroke(face, Color3.fromRGB(255, 245, 170), 1.4)
		end

		local _, vpFace = UI.panel(face, { Name = "PreviewBg", Size = UDim2.fromScale(0.86, 0.48), Position = UDim2.fromScale(0.07, 0.06), Color = "slot", Corner = 0.14, Shadow = false })
		local vp = Instance.new("ViewportFrame")
		vp.Name = "View"
		vp.Size = UDim2.fromScale(1, 1)
		vp.BackgroundTransparency = 1
		vp.Ambient = Color3.fromRGB(190, 185, 215)
		vp.LightColor = Color3.fromRGB(255, 248, 235)
		vp.LightDirection = Vector3.new(-0.4, -1, -0.6)
		vp.ZIndex = 4
		vp.Parent = vpFace
		local def = Characters.Get(r.CharacterId)
		local pModel = clonePreviewModel(r.ModelName or (def and def.ModelName) or r.CharacterId)
		if pModel then
			pModel.Parent = vp
			local f = frameChestCamera(vp, pModel)
			if f then
				table.insert(cardFramesToSpin, f)
			end
		end

		UI.text(face, r.Name, { Name = "Name", Size = UDim2.fromScale(0.92, 0.14), Position = UDim2.fromScale(0.04, 0.55), Role = "Body" })
		UI.chip(face, UI.upper(Summon.RarityName[r.Rarity]), "slot", { Name = "Rarity", Size = UDim2.fromScale(0.45, 0.12), Position = UDim2.fromScale(0.04, 0.71) })
		UI.chip(face, UI.upper(typeName(r.Type)), T.Types[r.Type] or TypeChart.Color[r.Type] or T.Palette.grey, { Name = "Type", Size = UDim2.fromScale(0.47, 0.12), Position = UDim2.fromScale(0.50, 0.71) })
		local tags = {}
		if r.Variant then
			table.insert(tags, "\u{2726} " .. r.Variant)
		end
		if r.New then
			table.insert(tags, "NOVO")
		end
		if r.Banner then
			table.insert(tags, "DESTAQUE")
		end
		UI.text(face, table.concat(tags, " "), { Name = "Tags", Size = UDim2.fromScale(0.9, 0.12), Position = UDim2.fromScale(0.05, 0.85), Role = "Small", Color = "gold", StrokeMult = 0.45 })
		if rare then
			UI.shine(card)
		end
		if r.Rolled ~= r.Rarity then
			table.insert(info, "Sorteado " .. Summon.RarityName[r.Rolled] .. ": o elenco ainda n\u{e3}o tem essa raridade, veio " .. r.Name .. ".")
		end
		for _, line in ipairs(r.Album or {}) do
			table.insert(info, line)
		end
		task.delay(0.09 * i, function()
			card.Visible = true
			-- Forca re-desenho imediato do ViewportFrame ao sair de Visible = false
			vp.Size = UDim2.new(1, 1, 1, 1)
			task.defer(function()
				if vp.Parent then
					vp.Size = UDim2.fromScale(1, 1)
				end
			end)
			local sc = Instance.new("UIScale")
			sc.Scale = 0.2
			sc.Parent = card
			TweenService:Create(sc, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			UI.play(if rare then "reward" else "click")
		end)
	end
	if #cardFramesToSpin > 0 then
		local tStart = os.clock()
		cardSpinConn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - tStart
			for idx, f in ipairs(cardFramesToSpin) do
				local a = math.sin(t * 1.5 + idx * 0.45) * 0.34
				local dir = CFrame.fromAxisAngle(Vector3.yAxis, a) * f.Front
				f.Cam.CFrame = CFrame.lookAt(f.Target + dir * f.Dist, f.Target)
			end
		end)
	end
	revealInfo.Text = table.concat(info, "\n")
end

local function doSummon(count)
	if busy then
		return
	end
	busy = true
	msg.Text = ""
	local ok, res = Remotes.Summon:InvokeServer(PORTAL, count, selectedBannerId)
	if not ok then
		msg.Text = res or "N\u{e3}o foi poss\u{ed}vel invocar."
		UI.play("error")
		busy = false
		return
	end
	UI.play("purchase")
	win.Close(true)
	-- Invocacao Rapida pula a animacao
	if not Benefits.Has(profile, "InvocacaoRapida") then
		playShowcase(res)
	end
	showCards(res)
	busy = false
end
one.Activated:Connect(function()
	doSummon(1)
end)
ten.Activated:Connect(function()
	doSummon(10)
end)
three.Activated:Connect(function()
	doSummon(Benefits.QuickSummonCount)
end)

--------------------------------------------------------------------
-- Aba Album
--------------------------------------------------------------------
local albumPage = page("Album")
local albumGrid = UI.scroll(albumPage, { Name = "Grid", Size = UDim2.fromScale(0.62, 1), Columns = 3, CellAspect = 0.95 })
local goals, goalsFace = UI.panel(albumPage, { Name = "Goals", Size = UDim2.fromScale(0.36, 1), Position = UDim2.fromScale(0.64, 0), Color = "slot", Corner = 0.06, Shadow = false })
local goalsList = UI.scroll(goalsFace, { Name = "List", Size = UDim2.fromScale(0.94, 0.94), Position = UDim2.fromScale(0.03, 0.03), Gap = 0.015 })

refreshAlbum = function()
	UI.clear(albumGrid)
	UI.clear(goalsList)
	if not profile then
		return
	end
	local owned = profile.Album and profile.Album.Owned or {}
	local claimed = profile.Album and profile.Album.Claimed or {}
	local ids = {}
	for id, def in pairs(Characters.List) do
		if not def.Prototype then -- prototipos de teste fora do album
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		local ra = table.find(Summon.RarityOrder, Characters.List[a].Rarity) or 0
		local rb = table.find(Summon.RarityOrder, Characters.List[b].Rarity) or 0
		if ra ~= rb then
			return ra < rb
		end
		return a < b
	end)
	local byType, byRarity = {}, {}
	for i, id in ipairs(ids) do
		local def = Characters.List[id]
		byType[def.Type] = byType[def.Type] or { 0, 0 }
		byRarity[def.Rarity] = byRarity[def.Rarity] or { 0, 0 }
		byType[def.Type][2] += 1
		byRarity[def.Rarity][2] += 1
		local has = owned[id] ~= nil
		if has then
			byType[def.Type][1] += 1
			byRarity[def.Rarity][1] += 1
		end
		local cell, face = UI.panel(albumGrid, { Name = "Entry_" .. id, Color = if has then rarityColor(def.Rarity) else "slot", Corner = T.Corner.Card, LayoutOrder = i })
		UI.text(face, if has then def.Name else "???", { Name = "Name", Size = UDim2.fromScale(0.9, 0.26), Position = UDim2.fromScale(0.05, 0.08), Role = "Body", Color = if has then "onDark" else "inkSoft" })
		UI.chip(face, UI.upper(typeName(def.Type)), if has then (T.Types[def.Type] or T.Palette.grey) else "grey", { Name = "Type", Size = UDim2.fromScale(0.7, 0.18), Position = UDim2.fromScale(0.15, 0.42) })
		local variants = {}
		for v in pairs(has and owned[id].Variants or {}) do
			table.insert(variants, "\u{2726}" .. v)
		end
		UI.text(face, table.concat(variants, " "), { Name = "Variants", Size = UDim2.fromScale(0.9, 0.2), Position = UDim2.fromScale(0.05, 0.72), Role = "Small", Color = "gold" })
		if not has then
			UI.icon(face, "lock", { Name = "Lock", Size = UDim2.fromScale(0.3, 0.3), Position = UDim2.fromScale(0.5, 0.7), AnchorPoint = Vector2.new(0.5, 0.5) })
		end
	end
	local order = 0
	local function goalRow(text, color, done)
		order += 1
		local row, f = UI.panel(goalsList, { Name = "Goal" .. order, Size = UDim2.fromScale(1, 0), Aspect = 5, Color = color or "panelAlt", Corner = T.Corner.Pill, Shadow = false, LayoutOrder = order })
		UI.text(f, text, { Name = "Text", Size = UDim2.fromScale(0.9, 0.7), Position = UDim2.fromScale(0.05, 0.15), Role = "Small", AlignX = Enum.TextXAlignment.Left })
		if done then
			UI.icon(row, "tick", { Size = UDim2.fromScale(0.2, 0.9), Position = UDim2.fromScale(0.97, 0.5), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 3 })
		end
	end
	local function header(text)
		order += 1
		local h = UI.text(goalsList, text, { Name = "H" .. order, Size = UDim2.fromScale(1, 0), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, LayoutOrder = order, Aspect = 7 })
		return h
	end
	header("Pr\u{ea}mio por grupo: " .. Summon.AlbumReward.Gold .. " gold + " .. Summon.AlbumReward.Gems .. " gemas")
	header("TIPOS")
	local types = {}
	for t in pairs(byType) do
		table.insert(types, t)
	end
	table.sort(types)
	for _, t in ipairs(types) do
		local v = byType[t]
		goalRow(string.format("%s  %d/%d", typeName(t), v[1], v[2]), T.Types[t], claimed["Tipo:" .. t])
	end
	header("RARIDADES")
	for _, r in ipairs(Summon.RarityOrder) do
		local v = byRarity[r]
		if v then
			goalRow(string.format("%s  %d/%d", Summon.RarityName[r], v[1], v[2]), rarityColor(r), claimed["Raridade:" .. r])
		else
			goalRow(Summon.RarityName[r] .. ": nenhum ainda", "slot", false)
		end
	end
end

--------------------------------------------------------------------
-- Aba Repetidos: fusao (3 iguais = +1 estrela) e venda
--------------------------------------------------------------------
local dupPage = page("Dupes")
UI.text(dupPage, string.format("%d c\u{f3}pias iguais viram +1 estrela (at\u{e9} %d, +%d%% de atributos cada). C\u{f3}pias no time n\u{e3}o s\u{e3}o usadas.", Summon.Stars.CopiesPerStar, Summon.Stars.Max, Summon.Stars.BonusPerStar * 100), { Name = "Help", Size = UDim2.fromScale(1, 0.1), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.4 })
local dupList = UI.scroll(dupPage, { Name = "List", Size = UDim2.fromScale(1, 0.88), Position = UDim2.fromScale(0, 0.12) })

refreshDupes = function()
	UI.clear(dupList)
	if not profile then
		return
	end
	local groups = {}
	for uid, m in pairs(profile.Collection) do
		local g = groups[m.CharacterId]
		if not g then
			g = { Count = 0, Stars = 0, InTeam = 0 }
			groups[m.CharacterId] = g
		end
		g.Count += 1
		g.Stars = math.max(g.Stars, m.Stars or 0)
		if table.find(profile.Team, uid) then
			g.InTeam += 1
		end
	end
	local ids = {}
	for id in pairs(groups) do
		table.insert(ids, id)
	end
	table.sort(ids)
	for i, id in ipairs(ids) do
		local g = groups[id]
		local def = Characters.Get(id)
		local row, face = UI.panel(dupList, { Name = "Row_" .. id, Size = UDim2.fromScale(0.98, 0), Aspect = 7.5, Color = "panelAlt", Corner = 0.24, LayoutOrder = i })
		UI.stroke(face, rarityColor(def.Rarity), 1.2)
		UI.text(face, string.format("%s  x%d   %s", def.Name, g.Count, string.rep("\u{2605}", g.Stars)), { Name = "Name", Size = UDim2.fromScale(0.44, 0.46), Position = UDim2.fromScale(0.03, 0.08), Role = "Body", AlignX = Enum.TextXAlignment.Left })
		UI.text(face, string.format("%s \u{b7} %d no time", Summon.RarityName[def.Rarity], g.InTeam), { Name = "Info", Size = UDim2.fromScale(0.44, 0.3), Position = UDim2.fromScale(0.03, 0.6), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.4 })
		local canFuse = g.Count >= Summon.Stars.CopiesPerStar
		local canSell = g.Count >= 2
		UI.button(face, { Name = "Fuse_" .. id, Text = "FUNDIR +1\u{2605}", Color = if canFuse then "purple" else "grey", Size = UDim2.fromScale(0.24, 0.74), Position = UDim2.fromScale(0.48, 0.13), Role = "Small", Sound = false,
			OnClick = function()
				local ok, text = Remotes.Fuse:InvokeServer(id)
				msg.TextColor3 = if ok then T.Palette.gold else T.Palette.hpLow
				msg.Text = text or (if ok then "Pronto." else "N\u{e3}o foi poss\u{ed}vel.")
				UI.play(if ok then "reward" else "error")
			end,
		})
		local sell, sface = UI.button(face, { Name = "Sell_" .. id, Color = if canSell then "green" else "grey", Size = UDim2.fromScale(0.24, 0.74), Position = UDim2.fromScale(0.74, 0.13), Sound = false,
			OnClick = function()
				local ok, text = Remotes.SellDuplicate:InvokeServer(id)
				msg.TextColor3 = if ok then T.Palette.gold else T.Palette.hpLow
				msg.Text = text or (if ok then "Pronto." else "N\u{e3}o foi poss\u{ed}vel.")
				UI.play(if ok then "purchase" else "error")
			end,
		})
		UI.icon(sface, "coin", { Size = UDim2.fromScale(0.3, 0.8), Position = UDim2.fromScale(0.05, 0.1) })
		UI.text(sface, "+" .. UI.fmt(Summon.SellPrice[def.Rarity]), { Name = "Price", Size = UDim2.fromScale(0.6, 0.7), Position = UDim2.fromScale(0.36, 0.15), Role = "Small", AlignX = Enum.TextXAlignment.Left })
	end
end

--------------------------------------------------------------------
-- Perfil, portal e chat
--------------------------------------------------------------------
local function apply(p)
	if typeof(p) ~= "table" then
		return
	end
	profile = p
	if win.IsOpen() then
		if currentTab == "Dupes" then
			refreshDupes()
		elseif currentTab == "Album" then
			refreshAlbum()
		else
			refreshMain()
		end
	end
end
Remotes:WaitForChild("ProfileUpdated").OnClientEvent:Connect(apply)
task.spawn(function()
	local ok, p = pcall(function()
		return Remotes:WaitForChild("GetProfile"):InvokeServer()
	end)
	if ok then
		apply(p)
	end
end)

local function restricted(): boolean
	return player:GetAttribute("PaidRandomRestricted") ~= false
end

-- Portal Premium some onde item aleatorio pago e restrito (fica so o Portal Comum)
local origCollide = {}
local function applyPolicy()
	local folder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Portals")
	if not folder then
		return
	end
	for _, model in folder:GetChildren() do
		local prompt = model:FindFirstChild("SummonPrompt", true)
		local id = prompt and prompt:GetAttribute("Portal")
		local def = id and Summon.Portals[id]
		if def and def.PaidRandom then
			local hide = restricted()
			local fxOn = player.PlayerGui:GetAttribute("MapFx") ~= false
			prompt.Enabled = not hide
			model:SetAttribute("HiddenLocal", hide)
			for _, d in model:GetDescendants() do
				if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("LayerCollector") then
					d.Enabled = not hide and fxOn
				elseif d:IsA("Decal") then
					if d:GetAttribute("FxT") == nil then
						d:SetAttribute("FxT", d.Transparency)
					end
					d.Transparency = if hide or not fxOn then 1 else d:GetAttribute("FxT")
				end
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = if hide then 1 else 0
					if origCollide[d] == nil then
						origCollide[d] = d.CanCollide
					end
					d.CanCollide = not hide and origCollide[d]
				elseif d:IsA("Light") then
					d.Enabled = not hide and fxOn
				end
			end
		end
	end
end
player:GetAttributeChangedSignal("PaidRandomRestricted"):Connect(applyPolicy)
task.defer(applyPolicy)

local function openPortal(id, tab)
	local def = Summon.Portals[id]
	if not def or (def.PaidRandom and restricted()) then
		return
	end
	PORTAL = id
	portal = def
	bannerName = nil
	msg.Text = ""
	reveal.Close(true)
	showcase.Visible = false
	skipFlag = true
	updateBannerSelection()
	win.Open()
	selectTab(tab or "Portal")
	fetchBannerFeatured()
end

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "SummonPrompt" and not UI.inBattle() then
		openPortal(prompt:GetAttribute("Portal") or "Comum", "Portal")
	end
end)

-- botao Album do HUD
UI.onOpen("Album", function()
	if win.IsOpen() and currentTab == "Album" then
		win.Close()
		return
	end
	openPortal(PORTAL, "Album")
end)

UI.onBattle(function(inBattle)
	if inBattle then
		skipFlag = true
		stopShowcaseSfx()
		stopCardSpins()
		showcase.Visible = false
		win.Close(true)
		reveal.Close(true)
	end
end)

Remotes:WaitForChild("Announce").OnClientEvent:Connect(function(text)
	local shown = false
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general then
			general:DisplaySystemMessage("<font color=\"#ffd84a\">" .. text .. "</font>")
			shown = true
		end
	end)
	if not shown then
		pcall(function()
			StarterGui:SetCore("ChatMakeSystemMessage", { Text = text, Color = Color3.fromRGB(255, 216, 74) })
		end)
	end
end)
