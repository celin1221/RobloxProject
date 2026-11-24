--[[
	SummonClient (Invocacao estilo Anime Vanguards + Palco 3D ao vivo + Album + Repetidos)
	- Abre no ProximityPrompt dos portais (Estrela Comum / Estrela Premium).
	- Na aba PORTAL: exibe o Palco 3D ao vivo (SummonBannerStage) com cenario tematico por anime
	  (Todos Comum/Premium, Naruto, One Piece), os 3 personagens principais em poses heroicas
	  (1 Lendario no centro + 2 Epicos/Destaques nas laterais) e HUD translucido estilo Anime Vanguards
	  com placas de nome flutuantes sincronizadas em tempo real.
	- Nas abas ALBUM e REPETIDOS: alterna suavemente para a janela padrao preservando toda a colecao,
	  premios, fusao e venda de repetidos.
	- Preserva integralmente: SummonService, PolicyService (PaidRandomRestricted), InvocacaoRapida,
	  SorteEmDobro, Tickets gratis, SummonBanner semanal, playShowcase, showCards e Announce.
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
local Gyms = require(Data:WaitForChild("Gyms"))
local TypeChart = require(Data:WaitForChild("TypeChart"))
local Benefits = require(Data:WaitForChild("Benefits"))
local StageThemes = require(Data:WaitForChild("SummonStageThemes"))
local BannerStage = require(ReplicatedStorage:WaitForChild("SummonBannerStage"))
local UI = require(ReplicatedStorage:WaitForChild("UI"))
local TeamCards = require(ReplicatedStorage:WaitForChild("TeamCards"))
local T = UI.Theme
local player = Players.LocalPlayer

local PORTAL = "Comum"
local portal = Summon.Portals[PORTAL]
local selectedBannerId = "Todos"
local bannerName = nil -- nome exibido do destaque da semana (Premium)
local weeklyCharId = nil -- id resolvido para o Palco 3D
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

local function resolveCharacterIdByName(nameOrId: string?): string?
	if not nameOrId or nameOrId == "" then
		return nil
	end
	if Characters.List[nameOrId] then
		return nameOrId
	end
	for id, def in pairs(Characters.List) do
		if def.Name == nameOrId then
			return id
		end
	end
	return nil
end

local canvas = UI.screen(gui)
gui.DisplayOrder = 9

--------------------------------------------------------------------
-- Janela principal (controla o ciclo de vida no UI.window + Abas Album/Dupes)
--------------------------------------------------------------------
local bannerHud: Frame
local nameplateConn: RBXScriptConnection? = nil
local currentTab = "Portal"
local refreshMain, refreshAlbum, refreshDupes, releaseAllAlbumCards, refreshSlotNameplates, startNameplateSync

local function stopNameplateSync()
	if nameplateConn then
		nameplateConn:Disconnect()
		nameplateConn = nil
	end
end

local savedSiblingGuis: { [ScreenGui]: boolean } = {}
local function setWorldHudHidden(hide: boolean)
	pcall(function()
		local pg = player:FindFirstChildOfClass("PlayerGui")
		if not pg then
			return
		end
		if hide then
			for _, gName in ipairs({ "HudGui", "TeamBarGui", "ProximityPrompts" }) do
				local g = pg:FindFirstChild(gName)
				if g and g:IsA("ScreenGui") and savedSiblingGuis[g] == nil then
					savedSiblingGuis[g] = g.Enabled
					g.Enabled = false
				end
			end
		else
			for g, wasOn in pairs(savedSiblingGuis) do
				if g and g.Parent then
					g.Enabled = wasOn
				end
			end
			table.clear(savedSiblingGuis)
		end
	end)
end

local win = UI.window(canvas, {
	Name = "SummonWindow",
	Title = "PORTAL COMUM",
	Icon = "portal",
	Size = UDim2.fromScale(0.92, 0.86),
	Aspect = 1.95,
	OnClose = function()
		stopNameplateSync()
		if releaseAllAlbumCards then
			releaseAllAlbumCards()
		end
		if bannerHud then
			bannerHud.Visible = false
		end
		BannerStage.Close()
		setWorldHudHidden(false)
	end,
})
local body = win.Body
local winScrim = win.Root:FindFirstChild("Scrim")
local pages = {}

local function syncPortalStageMode()
	local isPortal = win.IsOpen() and currentTab == "Portal"
	if isPortal then
		win.Panel.Visible = false
		if winScrim then
			winScrim.Visible = false
		end
		setWorldHudHidden(true)
		bannerHud.Visible = true
		BannerStage.Open(selectedBannerId, PORTAL, weeklyCharId)
		if refreshSlotNameplates then refreshSlotNameplates() end
		if startNameplateSync then startNameplateSync() end
	else
		stopNameplateSync()
		bannerHud.Visible = false
		BannerStage.Close()
		setWorldHudHidden(false)
		win.Panel.Visible = true
		if winScrim then
			winScrim.Visible = true
		end
	end
end

local walletHolder, walletLabel = UI.pill(body, "coin", "gold", { Name = "Wallet", Size = UDim2.fromScale(0.3, 0.095), Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(1, 0), Aspect = 3.2, MaxSize = Vector2.new(math.huge, 46) })
local msg = UI.text(body, "", { Name = "Message", Size = UDim2.fromScale(1, 0.055), Position = UDim2.fromScale(0, 0.945), Role = "Small", Color = "hpLow" })

local selectTab
selectTab = UI.tabs(body, {
	{ Id = "Portal", Text = "PORTAL" },
	{ Id = "Album", Text = "\u{c1}LBUM" },
	{ Id = "Dupes", Text = "REPETIDOS" },
}, { Size = UDim2.fromScale(0.6, 0.095), MaxWidth = 0.315 }, function(id)
	currentTab = id
	msg.Text = ""
	for name, f in pairs(pages) do
		f.Visible = name == id
	end
	if id ~= "Album" and releaseAllAlbumCards then
		releaseAllAlbumCards()
	end
	syncPortalStageMode()
	refreshMain()
	if id == "Album" then
		refreshAlbum()
	elseif id == "Dupes" then
		refreshDupes()
	end
end)

local function page(name)
	local f = UI.frame(body, { Name = name, Size = UDim2.fromScale(1, 0.78), Position = UDim2.fromScale(0, 0.16), Visible = name == "Portal" })
	UI.fillBetween(f, body:FindFirstChild("Tabs"), msg, 8)
	pages[name] = f
	return f
end

-- Pagina placeholder na janela padrao (a aba Portal usa o HUD ao vivo bannerHud sobre o Palco 3D)
page("Portal")

--------------------------------------------------------------------
-- HUD ESTILO ANIME VANGUARDS SOBRE O PALCO 3D AO VIVO (Aba Portal)
--------------------------------------------------------------------
bannerHud = UI.frame(win.Root, { Name = "BannerStageHUD", Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0, 0), Visible = false, ZIndex = 22 })

local function makeGlassCard(parent: Instance, name: string, size: UDim2, pos: UDim2, anchor: Vector2?, cornerPx: number?, zIndex: number?): (Frame, UIStroke)
	local z = zIndex or 24
	local rScale = if cornerPx and cornerPx <= 12 then 0.18 else 0.14
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = pos
	f.AnchorPoint = anchor or Vector2.zero
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = 0.04
	f.BorderSizePixel = 0
	f.ZIndex = z
	f.Parent = parent

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(rScale, 0)
	c.Parent = f

	local st = UI.stroke(f)

	local topCol, botCol = UI.pair("panel")
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(topCol, botCol)
	g.Parent = f

	if UI.sheen then
		UI.sheen(f, rScale, 0.12)
	end
	return f, st
end

-- Flash suave ao trocar de banner de anime
local swapFlash = Instance.new("Frame")
swapFlash.Name = "SwapFlash"
swapFlash.Size = UDim2.fromScale(3, 3)
swapFlash.Position = UDim2.fromScale(-1, -1)
swapFlash.BackgroundColor3 = Color3.fromRGB(255, 224, 130)
swapFlash.BackgroundTransparency = 1
swapFlash.BorderSizePixel = 0
swapFlash.ZIndex = 36
swapFlash.Parent = bannerHud

local function pulseSwapFlash(col: Color3)
	swapFlash.BackgroundColor3 = col:Lerp(Color3.new(1, 1, 1), 0.35)
	swapFlash.BackgroundTransparency = 0.66
	TweenService:Create(swapFlash, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
end

-- === 1. BARRA SUPERIOR (Titulo do Portal/Anime + Abas com Icones + Carteira + Fechar) ===
local topBar = UI.frame(bannerHud, { Name = "TopBar", Size = UDim2.fromScale(0.96, 0.095), Position = UDim2.fromScale(0.02, 0.016), ZIndex = 25 })
UI.clampHeight(topBar, 48, 60)

local titleCard, titleCardStroke = makeGlassCard(topBar, "TitleCard", UDim2.fromScale(0.30, 1), UDim2.fromScale(0, 0), Vector2.zero, 14, 26)
local titleAccentBar = Instance.new("Frame")
titleAccentBar.Name = "AccentBar"
titleAccentBar.Size = UDim2.new(0, 5, 0.68, 0)
titleAccentBar.Position = UDim2.new(0, 8, 0.5, 0)
titleAccentBar.AnchorPoint = Vector2.new(0, 0.5)
titleAccentBar.BackgroundColor3 = T.Palette.gold
titleAccentBar.BorderSizePixel = 0
titleAccentBar.ZIndex = 27
titleAccentBar.Parent = titleCard
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = titleAccentBar
end
UI.icon(titleCard, "portal", {
	Name = "PortalIcon",
	Size = UDim2.fromScale(0.16, 0.76),
	Position = UDim2.new(0, 18, 0.5, 0),
	AnchorPoint = Vector2.new(0, 0.5),
	AspectAxis = Enum.DominantAxis.Height,
	ZIndex = 27,
})
local hudTitleLabel = UI.text(titleCard, "PORTAL COMUM", {
	Name = "Title",
	Size = UDim2.new(0.76, -24, 0.52, 0),
	Position = UDim2.new(0.20, 10, 0.06, 0),
	Role = "Heading",
	AlignX = Enum.TextXAlignment.Left,
	ZIndex = 27,
})
local hudTaglineLabel = UI.text(titleCard, "TODOS OS ANIMES", {
	Name = "Tagline",
	Size = UDim2.new(0.76, -24, 0.36, 0),
	Position = UDim2.new(0.20, 10, 0.58, 0),
	Role = "Small",
	Color = "gold",
	AlignX = Enum.TextXAlignment.Left,
	StrokeMult = 0.5,
	ZIndex = 27,
})

-- Abas centrais (PORTAL / ALBUM / REPETIDOS) com icones personalizados
local hudTabsBox = UI.frame(topBar, { Name = "NavTabs", Size = UDim2.fromScale(0.35, 0.90), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 26 })
do
	local hl = Instance.new("UIListLayout")
	hl.FillDirection = Enum.FillDirection.Horizontal
	hl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	hl.VerticalAlignment = Enum.VerticalAlignment.Center
	hl.Padding = UDim.new(0.025, 0)
	hl.SortOrder = Enum.SortOrder.LayoutOrder
	hl.Parent = hudTabsBox
end
local hudNavTabs = {
	{ Id = "Portal", Text = "PORTAL", Icon = "portal", Color = "lendario" },
	{ Id = "Album", Text = "\u{c1}LBUM", Icon = "book", Color = "slot" },
	{ Id = "Dupes", Text = "REPETIDOS", Icon = "swap", Color = "slot" },
}
for i, def in ipairs(hudNavTabs) do
	local tb = UI.button(hudTabsBox, {
		Name = "HudTab_" .. def.Id,
		Text = def.Text,
		Icon = def.Icon,
		Layout = "row",
		Color = def.Color,
		Size = UDim2.fromScale(0.315, 0.94),
		Role = "Small",
		Corner = 0.32,
		LayoutOrder = i,
		ZIndex = 27,
		OnClick = function()
			if busy then
				return
			end
			selectTab(def.Id)
		end,
	})
	local existingSc = tb:FindFirstChildOfClass("UISizeConstraint")
	if existingSc then
		existingSc.MinSize = Vector2.new(52, T.TouchMin)
	end
end

-- Carteira + Botao Fechar (direita)
local hudRightTop = UI.frame(topBar, { Name = "RightTop", Size = UDim2.fromScale(0.29, 1), Position = UDim2.fromScale(1, 0.5), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 26 })
local hudWalletHolder, hudWalletLabel = UI.pill(hudRightTop, "coin", "gold", {
	Name = "HudWallet",
	Size = UDim2.fromScale(0.70, 0.88),
	Position = UDim2.fromScale(0.75, 0.5),
	AnchorPoint = Vector2.new(1, 0.5),
	Aspect = 3.2,
	MaxSize = Vector2.new(230, 46),
	ZIndex = 27,
})
local hudCloseBtn = UI.button(hudRightTop, {
	Name = "HudClose",
	Icon = "close",
	Color = "red",
	Size = UDim2.fromScale(0.22, 0.92),
	Position = UDim2.fromScale(1, 0.5),
	AnchorPoint = Vector2.new(1, 0.5),
	Aspect = 1,
	Corner = 0.28,
	ZIndex = 28,
	Sound = "close",
	OnClick = function()
		if not busy then
			win.Close()
		end
	end,
})

-- === 2. TRILHO LATERAL ESQUERDO: SELECAO DE BANNER POR ANIME (estilo Anime Vanguards) ===
local leftRail, leftRailStroke = makeGlassCard(bannerHud, "BannerRail", UDim2.fromScale(0.168, 0.68), UDim2.fromScale(0.018, 0.132), Vector2.zero, 16, 25)
UI.icon(leftRail, "portal", {
	Name = "HeaderIcon",
	Size = UDim2.fromScale(0.15, 0.075),
	Position = UDim2.fromScale(0.05, 0.022),
	AspectAxis = Enum.DominantAxis.Height,
	ZIndex = 26,
})
UI.text(leftRail, "BANNERS", {
	Name = "Header",
	Size = UDim2.fromScale(0.72, 0.075),
	Position = UDim2.fromScale(0.22, 0.022),
	Role = "Small",
	Color = "gold",
	AlignX = Enum.TextXAlignment.Left,
	StrokeMult = 0.5,
	ZIndex = 26,
})
local bannersList = Instance.new("ScrollingFrame")
bannersList.Name = "BannersList"
bannersList.Size = UDim2.fromScale(0.90, 0.875)
bannersList.Position = UDim2.fromScale(0.05, 0.105)
bannersList.BackgroundTransparency = 1
bannersList.BorderSizePixel = 0
bannersList.CanvasSize = UDim2.new(0, 0, 0, 0)
bannersList.AutomaticCanvasSize = Enum.AutomaticSize.Y
bannersList.ScrollBarThickness = 3
bannersList.ScrollBarImageColor3 = Color3.fromRGB(160, 148, 220)
bannersList.ScrollingDirection = Enum.ScrollingDirection.Y
bannersList.ZIndex = 26
bannersList.Parent = leftRail
do
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 2)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 2)
	pad.PaddingRight = UDim.new(0, 4)
	pad.Parent = bannersList

	local vl = Instance.new("UIListLayout")
	vl.FillDirection = Enum.FillDirection.Vertical
	vl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	vl.VerticalAlignment = Enum.VerticalAlignment.Top
	vl.Padding = UDim.new(0, 6)
	vl.SortOrder = Enum.SortOrder.LayoutOrder
	vl.Parent = bannersList
end

local bannerButtons = {}
local function fitBannerButtons()
	local w = bannersList.AbsoluteSize.X - 10
	if w <= 1 then
		return
	end
	local h = math.max(44, math.floor(w / 2.38 + 0.5))
	for _, entry in pairs(bannerButtons) do
		entry.Button.Size = UDim2.new(1, 0, 0, h)
	end
end
bannersList:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBannerButtons)

local function isBannerUnlocked(bannerId: string): boolean
	local gym = Gyms.ForBanner(bannerId)
	if not gym then
		return true
	end
	return profile ~= nil and profile.UnlockedBanners ~= nil and profile.UnlockedBanners[gym.Anime] == true
end

local function lockedBannerReason(bannerId: string): string?
	local gym = Gyms.ForBanner(bannerId)
	if not gym or isBannerUnlocked(bannerId) then
		return nil
	end
	return string.format("Banner trancado! Ven\u{e7}a o %s na Torre para desbloquear.", gym.Name)
end

local function updateBannerSelection()
	for id, entry in pairs(bannerButtons) do
		local isSel = id == selectedBannerId
		local unlocked = isBannerUnlocked(id)
		local accent = entry.Config.Accent or T.Palette.gold
		entry.Stroke.Color = if isSel
			then (if unlocked then accent:Lerp(Color3.new(1, 1, 1), 0.35) else T.Palette.red)
			else Color3.fromRGB(64, 52, 112)
		entry.Stroke.Thickness = if isSel then 3 else 1.5
		entry.Scale.Scale = if isSel then 1.02 else 1.0
		entry.ActiveTag.Visible = isSel and unlocked
		entry.LockedTag.Visible = not unlocked
		entry.Artwork.ImageColor3 = if unlocked then Color3.new(1, 1, 1) else Color3.fromRGB(130, 125, 148)
		entry.ShadeGrad.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, if not unlocked then 0.25 elseif isSel then 0.22 else 0.48),
			NumberSequenceKeypoint.new(0.55, if not unlocked then 0.42 elseif isSel then 0.36 else 0.62),
			NumberSequenceKeypoint.new(1, 0.12),
		})
	end
end

local function fetchBannerFeatured()
	if not portal.Banner then
		bannerName = nil
		weeklyCharId = nil
		if win.IsOpen() and currentTab == "Portal" then
			BannerStage.SetBanner(selectedBannerId, PORTAL, nil)
		end
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
			weeklyCharId = resolveCharacterIdByName(name)
			if win.IsOpen() and currentTab == "Portal" then
				BannerStage.SetBanner(selectedBannerId, PORTAL, weeklyCharId)
			end
			refreshMain()
		end
	end)
end

for idx, bannerId in ipairs(Summon.BannerOrder) do
	local cfg = Summon.Banners[bannerId]
	local btn = Instance.new("TextButton")
	btn.Name = "BannerTab_" .. bannerId
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.BackgroundColor3 = Color3.fromRGB(22, 16, 48)
	btn.BorderSizePixel = 0
	btn.Size = UDim2.new(1, 0, 0, 68)
	btn.ClipsDescendants = true
	btn.LayoutOrder = idx
	btn.ZIndex = 27
	btn.Parent = bannersList

	local minTouch = Instance.new("UISizeConstraint")
	minTouch.MinSize = Vector2.new(44, 44)
	minTouch.Parent = btn

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 12)
	bCorner.Parent = btn

	local bScale = Instance.new("UIScale")
	bScale.Parent = btn

	local bStroke = Instance.new("UIStroke")
	bStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bStroke.Color = Color3.fromRGB(64, 52, 112)
	bStroke.Thickness = 1.5
	bStroke.Parent = btn

	local art = Instance.new("ImageLabel")
	art.Name = "Artwork"
	art.BackgroundTransparency = 1
	art.Image = "rbxassetid://" .. tostring(cfg.ImageId)
	art.ScaleType = Enum.ScaleType.Crop
	art.Size = UDim2.fromScale(1, 1)
	art.ZIndex = 27
	art.Parent = btn

	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.fromRGB(12, 8, 28)
	shade.BorderSizePixel = 0
	shade.ZIndex = 28
	shade.Parent = btn
	local shadeGrad = Instance.new("UIGradient")
	shadeGrad.Rotation = 90
	shadeGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.55, 0.48),
		NumberSequenceKeypoint.new(1, 0.14),
	})
	shadeGrad.Parent = shade

	local activePill, activeFace = UI.panel(btn, {
		Name = "SelectedTag",
		Size = UDim2.fromScale(0.52, 0.28),
		Position = UDim2.fromScale(0.95, 0.08),
		AnchorPoint = Vector2.new(1, 0),
		Color = cfg.Accent or "gold",
		Corner = T.Corner.Pill,
		Shadow = false,
		Visible = false,
		ZIndex = 30,
	})
	UI.icon(activeFace, "tick", {
		Name = "Icon",
		Size = UDim2.fromScale(0.26, 0.78),
		Position = UDim2.fromScale(0.07, 0.5),
		AnchorPoint = Vector2.new(0, 0.5),
		AspectAxis = Enum.DominantAxis.Height,
		ZIndex = 31,
	})
	UI.text(activeFace, "ATIVO", { Name = "Label", Size = UDim2.fromScale(0.60, 0.8), Position = UDim2.fromScale(0.35, 0.1), Role = "Small", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.5, ZIndex = 31 })

	local lockedPill, lockedFace = UI.panel(btn, {
		Name = "LockedTag",
		Size = UDim2.fromScale(0.68, 0.29),
		Position = UDim2.fromScale(0.95, 0.08),
		AnchorPoint = Vector2.new(1, 0),
		Color = "red",
		Corner = T.Corner.Pill,
		Shadow = false,
		Visible = false,
		ZIndex = 30,
	})
	UI.icon(lockedFace, "lock", { Name = "Icon", Size = UDim2.fromScale(0.22, 0.78), Position = UDim2.fromScale(0.06, 0.11), DominantAxis = Enum.DominantAxis.Height, ZIndex = 31 })
	UI.text(lockedFace, "TRANCADO", { Name = "Label", Size = UDim2.fromScale(0.68, 0.8), Position = UDim2.fromScale(0.28, 0.1), Role = "Small", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.45, ZIndex = 31 })

	local titleRow = UI.frame(btn, { Name = "BottomRow", Size = UDim2.fromScale(0.92, 0.38), Position = UDim2.fromScale(0.04, 0.58), ZIndex = 30 })
	UI.icon(titleRow, cfg.Icon or "star", { Name = "Icon", Size = UDim2.fromScale(0.22, 0.88), Position = UDim2.fromScale(0, 0.06), DominantAxis = Enum.DominantAxis.Height, ZIndex = 31 })
	UI.text(titleRow, UI.upper(cfg.Short or cfg.Name), { Name = "Name", Size = UDim2.fromScale(0.75, 0.9), Position = UDim2.fromScale(0.24, 0.05), Role = "Small", AlignX = Enum.TextXAlignment.Left, ZIndex = 31 })

	btn.Activated:Connect(function()
		if busy or selectedBannerId == bannerId then
			return
		end
		selectedBannerId = bannerId
		UI.play("click")
		updateBannerSelection()
		local th = StageThemes.GetTheme(selectedBannerId, PORTAL)
		pulseSwapFlash(th.Primary)
		if win.IsOpen() and currentTab == "Portal" then
			BannerStage.SetBanner(selectedBannerId, PORTAL, nil)
		end
		refreshMain()
		fetchBannerFeatured()
	end)

	bannerButtons[bannerId] = {
		Button = btn,
		Config = cfg,
		Artwork = art,
		Stroke = bStroke,
		Scale = bScale,
		ActiveTag = activePill,
		LockedTag = lockedPill,
		ShadeGrad = shadeGrad,
	}
end
fitBannerButtons()
task.defer(fitBannerButtons)
updateBannerSelection()

-- === 3. PAINEL LATERAL DIREITO COMPACTO: CHANCES + DESTAQUE SEMANAL + TICKETS ===
local rightRail, rightRailStroke = makeGlassCard(bannerHud, "RatesRail", UDim2.fromScale(0.175, 0.56), UDim2.fromScale(0.982, 0.145), Vector2.new(1, 0), 16, 25)
-- Garante que BannerRail e RatesRail sempre comecem abaixo do TopBar sem colidir em telas pequenas
local function layoutBannerRails()
	local H = bannerHud.AbsoluteSize.Y
	if H < 40 then
		return
	end
	local topBottom = math.floor(H * 0.016) + math.max(48, math.floor(topBar.AbsoluteSize.Y)) + 6
	local railH = math.max(120, H - topBottom - math.floor(H * 0.04))
	leftRail.Position = UDim2.new(0.018, 0, 0, topBottom)
	leftRail.Size = UDim2.new(0.168, 0, 0, math.min(math.floor(H * 0.68), railH))
	rightRail.Position = UDim2.new(0.982, 0, 0, topBottom)
	rightRail.Size = UDim2.new(0.175, 0, 0, math.min(math.floor(H * 0.56), railH))
end
bannerHud:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutBannerRails)
topBar:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutBannerRails)
task.defer(layoutBannerRails)

UI.icon(rightRail, "sparkle", {
	Name = "HeaderIcon",
	Size = UDim2.fromScale(0.15, 0.08),
	Position = UDim2.fromScale(0.05, 0.025),
	AspectAxis = Enum.DominantAxis.Height,
	ZIndex = 26,
})
UI.text(rightRail, "CHANCES", {
	Name = "Header",
	Size = UDim2.fromScale(0.72, 0.09),
	Position = UDim2.fromScale(0.22, 0.025),
	Role = "Small",
	Color = "gold",
	AlignX = Enum.TextXAlignment.Left,
	StrokeMult = 0.5,
	ZIndex = 26,
})
local rateRows = {}
for i, r in ipairs(Summon.RarityOrder) do
	local row, rface = UI.panel(rightRail, {
		Name = "Rate_" .. r,
		Size = UDim2.fromScale(0.90, 0.125),
		Position = UDim2.fromScale(0.05, 0.125 + (i - 1) * 0.142),
		Color = rarityColor(r),
		Corner = T.Corner.Pill,
		Shadow = false,
		ZIndex = 26,
	})
	local nameLbl = UI.text(rface, UI.upper(Summon.RarityName[r]), { Name = "Name", Size = UDim2.fromScale(0.50, 0.78), Position = UDim2.fromScale(0.06, 0.11), Role = "Small", AlignX = Enum.TextXAlignment.Left, ZIndex = 27 })
	local valLbl = UI.text(rface, "", { Name = "Value", Size = UDim2.fromScale(0.36, 0.78), Position = UDim2.fromScale(0.94, 0.11), AnchorPoint = Vector2.new(1, 0), Role = "Small", AlignX = Enum.TextXAlignment.Right, ZIndex = 27 })
	if r == "Lendario" then
		UI.shine(row)
	end
	rateRows[r] = { Name = nameLbl, Value = valLbl }
end

local shinyRow = UI.frame(rightRail, { Name = "ShinyRow", Size = UDim2.fromScale(0.90, 0.075), Position = UDim2.fromScale(0.05, 0.705), ZIndex = 26 })
UI.icon(shinyRow, "sparkle", {
	Name = "Icon",
	Size = UDim2.fromScale(0.16, 0.90),
	Position = UDim2.fromScale(0, 0.5),
	AnchorPoint = Vector2.new(0, 0.5),
	AspectAxis = Enum.DominantAxis.Height,
	ZIndex = 27,
})
UI.text(shinyRow, "Brilhante: " .. pct(Summon.ShinyChance), {
	Name = "Shiny",
	Size = UDim2.fromScale(0.80, 1),
	Position = UDim2.fromScale(0.18, 0),
	Role = "Small",
	Color = "gold",
	AlignX = Enum.TextXAlignment.Left,
	StrokeMult = 0.5,
	ZIndex = 27,
})

local featuredRow = UI.frame(rightRail, { Name = "FeaturedRow", Size = UDim2.fromScale(0.90, 0.095), Position = UDim2.fromScale(0.05, 0.785), ZIndex = 26 })
UI.icon(featuredRow, "star", {
	Name = "Icon",
	Size = UDim2.fromScale(0.16, 0.84),
	Position = UDim2.fromScale(0, 0.5),
	AnchorPoint = Vector2.new(0, 0.5),
	AspectAxis = Enum.DominantAxis.Height,
	ZIndex = 27,
})
local bannerLabel = UI.text(featuredRow, "", {
	Name = "WeeklyFeatured",
	Size = UDim2.fromScale(0.80, 1),
	Position = UDim2.fromScale(0.18, 0),
	Role = "Small",
	Color = "lendario",
	AlignX = Enum.TextXAlignment.Left,
	StrokeMult = 0.5,
	ZIndex = 27,
})

local freeHolder, freeFace = UI.panel(rightRail, {
	Name = "FreeTickets",
	Size = UDim2.fromScale(0.90, 0.105),
	Position = UDim2.fromScale(0.05, 0.88),
	Color = "green",
	Corner = T.Corner.Pill,
	Shadow = false,
	Visible = false,
	ZIndex = 26,
})
UI.icon(freeHolder, "ticket", { Size = UDim2.fromScale(0.20, 1.15), Position = UDim2.fromScale(0.04, 0.5), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 28 })
local freeLabel = UI.text(freeFace, "", { Name = "Text", Size = UDim2.fromScale(0.74, 0.8), Position = UDim2.fromScale(0.24, 0.1), Role = "Small", AlignX = Enum.TextXAlignment.Left, ZIndex = 28 })

-- === 4. PLACAS DE NOME FLUTUANTES DOS 3 PERSONAGENS DO PALCO ===
local nameplatesLayer = UI.frame(bannerHud, { Name = "Nameplates", Size = UDim2.fromScale(1, 1), ZIndex = 24 })
local slotCards = {}
for i = 1, 3 do
	local isHero = (i == 2)
	local w = if isHero then 0.175 else 0.145
	local h = if isHero then 0.098 else 0.084
	local defaultX = if i == 1 then 0.295 elseif i == 2 then 0.50 else 0.705
	local defaultY = if isHero then 0.655 else 0.675

	local card, stroke = makeGlassCard(nameplatesLayer, "SlotPlate_" .. i, UDim2.fromScale(w, h), UDim2.fromScale(defaultX, defaultY), Vector2.new(0.5, 0.2), 12, if isHero then 26 else 25)
	UI.clampHeight(card, if isHero then 46 else 40, if isHero then 82 else 68)
	card.BackgroundTransparency = 0.16

	local topStripe = Instance.new("Frame")
	topStripe.Name = "RarityBar"
	topStripe.Size = UDim2.new(0.76, 0, 0, 4)
	topStripe.Position = UDim2.new(0.5, 0, 0, 4)
	topStripe.AnchorPoint = Vector2.new(0.5, 0)
	topStripe.BorderSizePixel = 0
	topStripe.ZIndex = 27
	topStripe.Parent = card
	do
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(1, 0)
		rc.Parent = topStripe
	end

	-- Selo dourado flutuante acima da placa do Lendario Central (com icone trophy personalizado)
	local crownPill, crownText = nil, nil
	if isHero then
		local cp, cface = UI.panel(card, {
			Name = "HeroCrown",
			Size = UDim2.fromScale(0.82, 0.36),
			Position = UDim2.fromScale(0.5, -0.06),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Color = "lendario",
			Corner = T.Corner.Pill,
			Shadow = false,
			ZIndex = 29,
		})
		crownPill = cp
		UI.icon(cface, "trophy", {
			Name = "Icon",
			Size = UDim2.fromScale(0.16, 0.80),
			Position = UDim2.fromScale(0.05, 0.5),
			AnchorPoint = Vector2.new(0, 0.5),
			AspectAxis = Enum.DominantAxis.Height,
			ZIndex = 30,
		})
		crownText = UI.text(cface, "DESTAQUE PRINCIPAL", {
			Name = "Txt",
			Size = UDim2.fromScale(0.74, 0.84),
			Position = UDim2.fromScale(0.22, 0.08),
			Role = "Small",
			AlignX = Enum.TextXAlignment.Left,
			StrokeMult = 0.5,
			ZIndex = 30,
		})
	end

	local typeIcon = UI.icon(card, "classe_espadachim", {
		Name = "TypeIcon",
		Size = UDim2.fromScale(0.22, 0.62),
		Position = UDim2.fromScale(0.05, if isHero then 0.56 else 0.52),
		AnchorPoint = Vector2.new(0, 0.5),
		AspectAxis = Enum.DominantAxis.Height,
		ZIndex = 27,
	})
	local nameLbl = UI.text(card, "", {
		Name = "CharName",
		Size = UDim2.fromScale(0.68, 0.40),
		Position = UDim2.new(0.28, 0, if isHero then 0.24 else 0.22, 2),
		Role = if isHero then "Heading" else "Body",
		AlignX = Enum.TextXAlignment.Left,
		ZIndex = 27,
	})
	local metaLbl = UI.text(card, "", {
		Name = "CharMeta",
		Size = UDim2.fromScale(0.68, 0.28),
		Position = UDim2.fromScale(0.28, 0.68),
		Role = "Small",
		Color = "gold",
		AlignX = Enum.TextXAlignment.Left,
		StrokeMult = 0.5,
		ZIndex = 27,
	})

	slotCards[i] = {
		Card = card,
		Stroke = stroke,
		TopStripe = topStripe,
		CrownPill = crownPill,
		CrownText = crownText,
		TypeIcon = typeIcon,
		NameLabel = nameLbl,
		MetaLabel = metaLbl,
		DefaultX = defaultX,
		DefaultY = defaultY,
		IsHero = isHero,
	}
end

refreshSlotNameplates = function()
	local featured = BannerStage.GetFeatured()
	if #featured == 0 then
		featured = StageThemes.ResolveFeatured(selectedBannerId, PORTAL, weeklyCharId)
	end
	for i = 1, 3 do
		local sc = slotCards[i]
		local pick = featured[i]
		if pick and pick.Def then
			sc.Card.Visible = true
			local rInfo = StageThemes.RarityColors[pick.Def.Rarity] or StageThemes.RarityColors.Epico
			sc.Stroke.Color = rInfo.Main
			sc.TopStripe.BackgroundColor3 = rInfo.Main
			sc.NameLabel.Text = UI.upper(pick.Def.Name or pick.Id)
			local tKey = pick.Def.Type or "Neutro"
			UI.setIcon(sc.TypeIcon, UI.TypeIcon[tKey] or "star")
			sc.MetaLabel.Text = rInfo.Label .. " \u{b7} " .. UI.upper(typeName(tKey))
			sc.MetaLabel.TextColor3 = rInfo.Glow
			if sc.CrownText then
				if portal.Banner and bannerName and (pick.Def.Name == bannerName or pick.Id == weeklyCharId) then
					sc.CrownText.Text = "DESTAQUE SEMANAL"
				else
					sc.CrownText.Text = "LEND\u{c1}RIO DO BANNER"
				end
			end
		else
			sc.Card.Visible = false
		end
	end
end

startNameplateSync = function()
	stopNameplateSync()
	nameplateConn = RunService.RenderStepped:Connect(function()
		if not bannerHud.Visible then
			return
		end
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local vs = cam.ViewportSize
		if vs.X < 10 or vs.Y < 10 then
			return
		end
		local anchors = BannerStage.GetSlotScreenAnchors()
		for i = 1, 3 do
			local sc = slotCards[i]
			local a = anchors[i]
			if a and a.Visible then
				local sx = math.clamp(a.Pos.X / vs.X, 0.295, 0.705)
				local sy = math.clamp(a.Pos.Y / vs.Y, 0.56, 0.675)
				sc.Card.Position = UDim2.fromScale(sx, sy)
			else
				sc.Card.Position = UDim2.fromScale(sc.DefaultX, sc.DefaultY)
			end
		end
	end)
end

-- === 5. DOCA INFERIOR: GARANTIA DE LENDARIO + BOTOES DE INVOCAR ===
local bottomDock, bottomDockStroke = makeGlassCard(bannerHud, "BottomDock", UDim2.fromScale(0.58, 0.185), UDim2.fromScale(0.5, 0.982), Vector2.new(0.5, 1), 16, 26)
UI.clampHeight(bottomDock, 82, 134)
local bannerMsg = UI.text(bannerHud, "", {
	Name = "BannerMessage",
	Size = UDim2.fromScale(0.56, 0.042),
	Position = UDim2.fromScale(0.5, 0.785),
	AnchorPoint = Vector2.new(0.5, 1),
	Role = "Small",
	Color = "hpLow",
	ZIndex = 29,
})

local pityRow = UI.frame(bottomDock, { Name = "PityRow", Size = UDim2.fromScale(0.93, 0.25), Position = UDim2.fromScale(0.035, 0.07), ZIndex = 27 })
UI.icon(pityRow, "trophy", {
	Name = "PityIcon",
	Size = UDim2.fromScale(0.055, 0.88),
	Position = UDim2.fromScale(0, 0.5),
	AnchorPoint = Vector2.new(0, 0.5),
	AspectAxis = Enum.DominantAxis.Height,
	ZIndex = 28,
})
UI.text(pityRow, "GARANTIA LEND\u{c1}RIO", {
	Name = "PityTitle",
	Size = UDim2.fromScale(0.30, 1),
	Position = UDim2.fromScale(0.065, 0),
	Role = "Small",
	Color = "gold",
	AlignX = Enum.TextXAlignment.Left,
	StrokeMult = 0.5,
	ZIndex = 28,
})
local pityBar = UI.bar(pityRow, { Name = "Pity", Size = UDim2.fromScale(0.62, 0.74), Position = UDim2.fromScale(0.38, 0.13), FillColor = "lendario", Value = 0, ZIndex = 28 })
local pityValue = UI.text(pityBar, "", {
	Name = "PityValue",
	Size = UDim2.fromScale(0.92, 0.90),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Role = "Small",
	Color = "onDark",
	ZIndex = 30,
})

local actionsRow = UI.frame(bottomDock, { Name = "ActionsRow", Size = UDim2.fromScale(0.93, 0.51), Position = UDim2.fromScale(0.035, 0.37), ZIndex = 27 })

local function summonButton(name, x, w, colorKey, shine)
	local b, face = UI.button(actionsRow, {
		Name = name,
		Color = colorKey or "green",
		Size = UDim2.fromScale(w, 1),
		Position = UDim2.fromScale(x, 0),
		Corner = 0.24,
		Sound = false,
		ZIndex = 28,
	})
	local minTouch = Instance.new("UISizeConstraint")
	minTouch.MinSize = Vector2.new(88, 44)
	minTouch.Parent = b
	UI.text(face, "", {
		Name = "Title",
		Size = UDim2.fromScale(0.92, 0.44),
		Position = UDim2.fromScale(0.5, 0.06),
		AnchorPoint = Vector2.new(0.5, 0),
		AlignX = Enum.TextXAlignment.Center,
		Role = "Body",
		ZIndex = 29,
	})
	local price = UI.frame(face, {
		Name = "Price",
		Size = UDim2.fromScale(0.92, 0.42),
		Position = UDim2.fromScale(0.5, 0.51),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 29,
	})
	local iconImg = UI.icon(price, "coin", {
		Name = "Icon",
		Size = UDim2.fromScale(0.90, 0.90),
		Position = UDim2.fromScale(0.35, 0.5),
		AnchorPoint = Vector2.new(0, 0.5),
		AspectAxis = Enum.DominantAxis.Height,
		ZIndex = 30,
	})
	local t = UI.text(price, "", {
		Name = "Value",
		Size = UDim2.fromScale(0.72, 0.92),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0, 0.5),
		Role = "Body",
		AlignX = Enum.TextXAlignment.Left,
		ZIndex = 30,
	})
	local function centerPriceGroup()
		local pw, ph = UI.unscaledSize(price)
		if pw <= 1 or ph <= 1 then
			return
		end
		local sc = price.AbsoluteSize.X / pw
		local iconW = math.floor(ph * 0.90 + 0.5)
		local textW = if sc > 0.05 then math.ceil(t.TextBounds.X / sc) else math.floor(ph * 1.6)
		local gap = math.clamp(math.floor(ph * 0.22), 5, 8)
		local totalW = iconW + gap + textW
		local startX = math.max(0, math.floor((pw - totalW) / 2 + 0.5))
		iconImg.Position = UDim2.new(0, startX, 0.5, 0)
		t.Position = UDim2.new(0, startX + iconW + gap, 0.5, 0)
	end
	t:GetPropertyChangedSignal("TextBounds"):Connect(centerPriceGroup)
	t:GetPropertyChangedSignal("Text"):Connect(function()
		task.defer(centerPriceGroup)
	end)
	price:GetPropertyChangedSignal("AbsoluteSize"):Connect(centerPriceGroup)
	task.defer(centerPriceGroup)
	if shine then
		UI.shine(b)
	end
	return b
end
local one = summonButton("Summon1", 0, 0.485, "green", false)
local three = summonButton("Summon3", 0.345, 0.31, "purple", false)
three.Visible = false
local ten = summonButton("Summon10", 0.515, 0.485, "lendario", true)

local lockedDock, lockedDockFace = UI.panel(actionsRow, {
	Name = "LockedBannerDock",
	Size = UDim2.fromScale(1, 1),
	Color = "slot",
	Corner = 0.24,
	Shadow = false,
	Visible = false,
	ZIndex = 30,
})
UI.stroke(lockedDockFace, T.Palette.red, 1.2)
UI.icon(lockedDockFace, "lock", {
	Name = "LockIcon",
	Size = UDim2.fromScale(0.09, 0.72),
	Position = UDim2.fromScale(0.03, 0.5),
	AnchorPoint = Vector2.new(0, 0.5),
	DominantAxis = Enum.DominantAxis.Height,
	ZIndex = 31,
})
local lockedDockText = UI.text(lockedDockFace, "", {
	Name = "Label",
	Size = UDim2.fromScale(0.84, 0.84),
	Position = UDim2.fromScale(0.13, 0.08),
	Role = "Body",
	Color = "gold",
	AlignX = Enum.TextXAlignment.Left,
	ZIndex = 31,
})

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
	local theme = StageThemes.GetTheme(selectedBannerId, PORTAL)

	-- Titulo e cores tematicas tanto na janela padrao quanto no HUD 3D
	local fullTitle = UI.upper(portal.Name) .. " \u{b7} " .. UI.upper(bCfg.Short or bCfg.Name)
	win.Title.Text = fullTitle
	UI.paint(win.Header, if gems then "lendario" else "header")
	hudTitleLabel.Text = fullTitle
	hudTaglineLabel.Text = theme.Tagline
	hudTaglineLabel.TextColor3 = theme.Accent
	titleAccentBar.BackgroundColor3 = theme.Primary
	titleCardStroke.Color = theme.Primary
	leftRailStroke.Color = theme.Primary:Lerp(Color3.fromRGB(90, 74, 150), 0.35)
	rightRailStroke.Color = theme.Primary:Lerp(Color3.fromRGB(90, 74, 150), 0.35)
	bottomDockStroke.Color = theme.Primary

	-- Carteira nas duas vistas
	local amount = if gems then (profile.Gems or 0) else (profile.Gold or 0)
	local amtColor = if gems then T.Palette.gems else T.Palette.gold
	UI.setIcon(walletHolder.Icon, icon)
	walletLabel.TextColor3 = amtColor
	UI.countTo(walletLabel, amount)
	UI.setIcon(hudWalletHolder.Icon, icon)
	hudWalletLabel.TextColor3 = amtColor
	UI.countTo(hudWalletLabel, amount)

	-- Chances
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
		bannerLabel.Text = if bannerName
			then string.format("%s (%s)", bannerName, pct((ratesNow.Lendario or 0) * portal.Banner.Share))
			else "Banner " .. (bCfg.Short or bCfg.Name)
	else
		bannerLabel.Text = bCfg.Subtitle or bCfg.Name
	end

	-- Pity & Tickets
	local pity = (profile.SummonPity and profile.SummonPity[portal.PityKey]) or 0
	pityValue.Text = string.format("%d/%d", pity, portal.PityAt)
	UI.setBar(pityBar, pity / portal.PityAt, "lendario")
	local free = (profile.Tickets and profile.Tickets[portal.PityKey]) or 0
	freeHolder.Visible = free > 0
	freeLabel.Text = free .. " gr\u{e1}tis"

	-- Botoes de invocacao (ou aviso de banner trancado pelo Ginasio)
	local lockReason = lockedBannerReason(selectedBannerId)
	local quick = Benefits.Has(profile, "InvocacaoRapida")
	if lockReason then
		one.Visible = false
		three.Visible = false
		ten.Visible = false
		lockedDock.Visible = true
		lockedDockText.Text = lockReason
	else
		lockedDock.Visible = false
		one.Visible = true
		ten.Visible = true
		three.Visible = quick
		if quick then
			one.Size = UDim2.fromScale(0.315, 1)
			one.Position = UDim2.fromScale(0, 0)
			three.Size = UDim2.fromScale(0.315, 1)
			three.Position = UDim2.fromScale(0.342, 0)
			ten.Size = UDim2.fromScale(0.315, 1)
			ten.Position = UDim2.fromScale(0.685, 0)
		else
			one.Size = UDim2.fromScale(0.485, 1)
			one.Position = UDim2.fromScale(0, 0)
			ten.Size = UDim2.fromScale(0.485, 1)
			ten.Position = UDim2.fromScale(0.515, 0)
		end
		setSummonButton(one, "INVOCAR 1", portal.Cost, icon, free > 0)
		setSummonButton(three, "INVOCAR " .. Benefits.QuickSummonCount, portal.Cost * Benefits.QuickSummonCount, icon, false)
		setSummonButton(ten, "INVOCAR 10", portal.Cost10, icon, false)
	end
	updateBannerSelection()

	-- Placas dos 3 personagens em destaque
	refreshSlotNameplates()
	if win.IsOpen() and currentTab == "Portal" and not nameplateConn then
		startNameplateSync()
	end
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
local rarityIconL = UI.icon(rarityBannerFace, "star", { Name = "IconL", Size = UDim2.fromScale(0.12, 0.78), Position = UDim2.fromScale(0.05, 0.5), AnchorPoint = Vector2.new(0, 0.5), AspectAxis = Enum.DominantAxis.Height, ZIndex = 47 })
local rarityIconR = UI.icon(rarityBannerFace, "star", { Name = "IconR", Size = UDim2.fromScale(0.12, 0.78), Position = UDim2.fromScale(0.95, 0.5), AnchorPoint = Vector2.new(1, 0.5), AspectAxis = Enum.DominantAxis.Height, ZIndex = 47 })
local rarityBannerLabel = UI.text(rarityBannerFace, "", { Name = "Text", Size = UDim2.fromScale(0.68, 0.78), Position = UDim2.fromScale(0.16, 0.11), Role = "Heading", ZIndex = 47 })

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
		UI.setIcon(rarityIconL, if shiny then "sparkle" else "star")
		UI.setIcon(rarityIconR, if shiny then "sparkle" else "star")
		rarityBannerLabel.Text = UI.upper(Summon.RarityName[hero.Rarity] or hero.Rarity) .. (if shiny then " BRILHANTE" else "")
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
local reveal = UI.window(canvas, {
	Name = "RevealWindow",
	Title = "RESULTADO",
	Icon = "star",
	HeaderColor = "lendario",
	Size = UDim2.fromScale(0.92, 0.86),
	Aspect = 1.95,
	OnClose = function(silent)
		if not silent then
			task.defer(function()
				win.Open()
				selectTab("Portal")
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
UI.button(reveal.Body, {
	Name = "OK",
	Text = "OK",
	Icon = "tick",
	Layout = "row",
	Color = "green",
	Size = UDim2.fromScale(0.24, 0.17),
	Position = UDim2.fromScale(1, 0.81),
	AnchorPoint = Vector2.new(1, 0),
	Role = "Heading",
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
			table.insert(tags, UI.upper(r.Variant))
			UI.icon(face, "sparkle", { Name = "ShinyIcon", Size = UDim2.fromScale(0.16, 0.13), Position = UDim2.fromScale(0.84, 0.06), ZIndex = 6 })
		end
		if r.New then
			table.insert(tags, "NOVO")
		end
		if r.Banner then
			table.insert(tags, "DESTAQUE")
		end
		UI.text(face, table.concat(tags, " \u{b7} "), { Name = "Tags", Size = UDim2.fromScale(0.9, 0.12), Position = UDim2.fromScale(0.05, 0.85), Role = "Small", Color = "gold", StrokeMult = 0.45 })
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
	local lockReason = lockedBannerReason(selectedBannerId)
	if lockReason then
		msg.Text = lockReason
		bannerMsg.Text = lockReason
		UI.play("error")
		return
	end
	busy = true
	msg.Text = ""
	bannerMsg.Text = ""
	local ok, res = Remotes.Summon:InvokeServer(PORTAL, count, selectedBannerId)
	if not ok then
		local errTxt = res or "N\u{e3}o foi poss\u{ed}vel invocar."
		msg.Text = errTxt
		bannerMsg.Text = errTxt
		UI.play("error")
		busy = false
		return
	end
	UI.play("purchase")
	win.Close(true)
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
-- Aba Album (cartoes 3D iguais aos da Equipe + silhueta/sombra para nao obtidos)
--------------------------------------------------------------------
local albumPage = page("Album")
local albumGrid = Instance.new("ScrollingFrame")
albumGrid.Name = "Grid"
albumGrid.Size = UDim2.fromScale(0.64, 1)
albumGrid.Position = UDim2.fromScale(0, 0)
albumGrid.BackgroundTransparency = 1
albumGrid.BorderSizePixel = 0
albumGrid.ScrollBarThickness = 6
albumGrid.ScrollBarImageColor3 = Color3.fromRGB(200, 190, 255)
albumGrid.ScrollingDirection = Enum.ScrollingDirection.Y
albumGrid.CanvasSize = UDim2.new()
albumGrid.Parent = albumPage

local goals, goalsFace = UI.panel(albumPage, { Name = "Goals", Size = UDim2.fromScale(0.34, 1), Position = UDim2.fromScale(0.66, 0), Color = "slot", Corner = 0.06, Shadow = false, StrokeMult = 0.8 })
local goalsList = UI.scroll(goalsFace, { Name = "List", Size = UDim2.fromScale(0.96, 0.96), Position = UDim2.fromScale(0.02, 0.02), Gap = 0.022, Flat = true })

local albumIds: { string } = {}
local albumActive: { [string]: any } = {}
local albumFree: { any } = {}

local function releaseAlbumCard(id: string)
	local c = albumActive[id]
	if c then
		albumActive[id] = nil
		c.Clear()
		c.Root.Visible = false
		table.insert(albumFree, c)
	end
end

releaseAllAlbumCards = function()
	for id in pairs(albumActive) do
		releaseAlbumCard(id)
	end
end

local function onAlbumCardClick(charId: string)
	local def = Characters.Get(charId)
	if not def then
		return
	end
	local owned = profile and profile.Album and profile.Album.Owned or {}
	local entry = owned[charId]
	UI.play("click")
	if entry then
		local variants = {}
		for vName, ok in pairs(entry.Variants or {}) do
			if ok then
				table.insert(variants, vName)
			end
		end
		table.sort(variants)
		local extra = if #variants > 0 then (" \u{b7} " .. table.concat(variants, ", ")) else ""
		msg.TextColor3 = T.Palette.gold
		msg.Text = string.format("%s \u{b7} %s \u{b7} %s \u{b7} %s%s", def.Name, Characters.AnimeDisplay(def.Anime), typeName(def.Type), Summon.RarityName[def.Rarity] or def.Rarity, extra)
	else
		msg.TextColor3 = T.Palette.inkSoft
		msg.Text = string.format("??? \u{b7} Classe: %s \u{b7} Raridade: %s \u{b7} Invoque ou capture para desbloquear!", typeName(def.Type), Summon.RarityName[def.Rarity] or def.Rarity)
	end
end

local function updateAlbumGrid(force: boolean?)
	if not win.IsOpen() or currentTab ~= "Album" or not profile then
		return
	end
	local rawW, rawH = UI.unscaledSize(albumGrid)
	local W, H = math.floor(rawW + 0.5), math.floor(rawH + 0.5)
	if W < 20 or H < 20 then
		return
	end
	local padX = 8
	local padY = 8
	local gw = math.max(120, W - albumGrid.ScrollBarThickness - padX * 2 - 4)
	local cols = if gw >= 520 then 4 else 3
	local gapX = math.clamp(math.floor(gw * 0.025 + 0.5), 8, 14)
	local gapY = gapX + 8
	local cell = math.max(64, math.floor((gw - gapX * (cols - 1)) / cols))
	local stepX = cell + gapX
	local stepY = cell + gapY
	local rows = math.ceil(#albumIds / cols)
	local canvasH = math.max(0, padY + rows * stepY - gapY + padY + 12)
	if albumGrid.CanvasSize.Y.Offset ~= canvasH then
		albumGrid.CanvasSize = UDim2.fromOffset(0, canvasH)
	end

	local y0 = albumGrid.CanvasPosition.Y
	-- virtualiza apenas as linhas visiveis (mantem ViewportFrames 3D leves e sempre nitidos)
	local first = math.max(0, math.floor((y0 - padY) / stepY))
	local last = math.max(first, math.floor((y0 + math.max(1, H) - padY) / stepY))
	local want: { [string]: number } = {}
	for r = first, last do
		for c = 0, cols - 1 do
			local idx = r * cols + c + 1
			local id = albumIds[idx]
			if id then
				want[id] = idx
			end
		end
	end

	for id in pairs(albumActive) do
		if not want[id] then
			releaseAlbumCard(id)
		end
	end

	local owned = profile.Album and profile.Album.Owned or {}
	for id, idx in pairs(want) do
		local card = albumActive[id]
		local entry = owned[id]
		if not card then
			card = table.remove(albumFree)
			if not card then
				card = TeamCards.new(albumGrid, { Name = "Entry", ZIndex = 3 })
				card.Root.Activated:Connect(function()
					if card.Uid then
						onAlbumCardClick(card.Uid)
					end
				end)
			end
			albumActive[id] = card
			card.Root.Visible = true
			card.SetAlbum(id, { Owned = entry ~= nil, Variants = entry and entry.Variants })
		elseif force then
			card.SetAlbum(id, { Owned = entry ~= nil, Variants = entry and entry.Variants })
		end
		card.Root.Name = "Entry_" .. id
		local i0 = idx - 1
		card.Root.Size = UDim2.fromOffset(cell, cell)
		card.Root.Position = UDim2.fromOffset(padX + (i0 % cols) * stepX, padY + (i0 // cols) * stepY)
	end
end

albumGrid:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
	updateAlbumGrid(false)
end)
albumGrid:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	updateAlbumGrid(true)
end)

refreshAlbum = function()
	UI.clear(goalsList)
	if not profile then
		releaseAllAlbumCards()
		return
	end
	local owned = profile.Album and profile.Album.Owned or {}
	local claimed = profile.Album and profile.Album.Claimed or {}
	local ids = {}
	for id, def in pairs(Characters.List) do
		if not def.Prototype then
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
	albumIds = ids

	local totalOwned = 0
	local byType, byRarity = {}, {}
	for _, id in ipairs(ids) do
		local def = Characters.List[id]
		byType[def.Type] = byType[def.Type] or { 0, 0 }
		byRarity[def.Rarity] = byRarity[def.Rarity] or { 0, 0 }
		byType[def.Type][2] += 1
		byRarity[def.Rarity][2] += 1
		if owned[id] ~= nil then
			totalOwned += 1
			byType[def.Type][1] += 1
			byRarity[def.Rarity][1] += 1
		end
	end

	updateAlbumGrid(true)
	task.defer(function()
		updateAlbumGrid(true)
	end)

	local order = 0
	local function goalRow(text, color, done)
		order += 1
		local row, f = UI.panel(goalsList, { Name = "Goal" .. order, Size = UDim2.fromScale(1, 0), Aspect = 5.4, RowMax = 44, Color = color or "panelAlt", Corner = T.Corner.Pill, Shadow = false, StrokeMult = 0.7, LayoutOrder = order })
		UI.text(f, text, { Name = "Text", Size = UDim2.fromScale(0.86, 0.72), Position = UDim2.fromScale(0.06, 0.14), Role = "Small", AlignX = Enum.TextXAlignment.Left })
		if done then
			UI.icon(row, "tick", { Size = UDim2.fromScale(0.18, 0.84), Position = UDim2.fromScale(0.96, 0.5), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 3 })
		end
	end
	local function header(text, col)
		order += 1
		local h = UI.text(goalsList, text, { Name = "H" .. order, Size = UDim2.fromScale(1, 0), Role = "Small", Color = col or "inkSoft", AlignX = Enum.TextXAlignment.Left, LayoutOrder = order, Aspect = 8.5, RowMax = 28 })
		return h
	end
	header(string.format("COLE\u{c7}\u{c3}O: %d/%d", totalOwned, #ids), "gold")
	header("Pr\u{ea}mio por grupo: " .. Summon.AlbumReward.Gold .. " gold + " .. Summon.AlbumReward.Gems .. " gemas")
	header("CLASSES")
	local types = {}
	for t in pairs(byType) do
		table.insert(types, t)
	end
	table.sort(types)
	for _, t in ipairs(types) do
		local v = byType[t]
		goalRow(string.format("%s  %d/%d", typeName(t), v[1], v[2]), T.Types[t], claimed["Classe:" .. t])
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
UI.text(dupPage, string.format("%d c\u{f3}pias iguais viram +1 estrela (at\u{e9} %d, +%d%% de atributos cada). C\u{f3}pias no time n\u{e3}o s\u{e3}o usadas.", Summon.Stars.CopiesPerStar, Summon.Stars.Max, Summon.Stars.BonusPerStar * 100), { Name = "Help", Size = UDim2.fromScale(1, 0.08), Position = UDim2.fromScale(0, 0), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.4 })
local dupList = UI.scroll(dupPage, { Name = "List", Size = UDim2.fromScale(1, 0.90), Position = UDim2.fromScale(0, 0.10), Gap = 0.028, Flat = true })

refreshDupes = function()
	if not profile then
		UI.clear(dupList)
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
	UI.keepScroll(dupList, function()
		UI.clear(dupList)
		for i, id in ipairs(ids) do
			local g = groups[id]
			local def = Characters.Get(id)
			if def then
				local rCol = rarityColor(def.Rarity)
				local row, face = UI.panel(dupList, { Name = "Row_" .. id, Size = UDim2.fromScale(1, 0), Aspect = 8.4, RowMax = 74, Color = "panelAlt", Corner = 0.18, Shadow = false, StrokeColor = rCol, StrokeMult = 0.85, LayoutOrder = i })
				local accent = Instance.new("Frame")
				accent.Name = "Accent"
				accent.Size = UDim2.new(0, 5, 0.68, 0)
				accent.Position = UDim2.new(0, 8, 0.5, 0)
				accent.AnchorPoint = Vector2.new(0, 0.5)
				accent.BackgroundColor3 = rCol
				accent.BorderSizePixel = 0
				accent.Parent = face
				UI.corner(accent, 0.5)

				UI.text(face, string.format("%s  x%d", def.Name, g.Count), { Name = "Name", Size = UDim2.fromScale(0.28, 0.44), Position = UDim2.fromScale(0.04, 0.10), Role = "Body", AlignX = Enum.TextXAlignment.Left })
				if g.Stars > 0 then
					local starsRow = UI.frame(face, { Name = "StarsRow", Size = UDim2.fromScale(0.16, 0.36), Position = UDim2.fromScale(0.325, 0.14) })
					for sIdx = 1, math.min(5, g.Stars) do
						UI.icon(starsRow, "star", {
							Name = "S" .. sIdx,
							Size = UDim2.fromScale(0.18, 1),
							Position = UDim2.fromScale((sIdx - 1) * 0.20, 0),
							AspectAxis = Enum.DominantAxis.Height,
						})
					end
				end
				UI.text(face, string.format("%s \u{b7} %d no time", Summon.RarityName[def.Rarity], g.InTeam), { Name = "Info", Size = UDim2.fromScale(0.44, 0.30), Position = UDim2.fromScale(0.04, 0.58), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.4 })
				local canFuse = g.Count >= Summon.Stars.CopiesPerStar
				local canSell = g.Count >= 2
				UI.button(face, {
					Name = "Fuse_" .. id,
					Text = "FUNDIR +1",
					Icon = "star",
					Layout = "row",
					Color = if canFuse then "purple" else "grey",
					Size = UDim2.fromScale(0.225, 0.66),
					Position = UDim2.fromScale(0.505, 0.5),
					AnchorPoint = Vector2.new(0, 0.5),
					Role = "Small",
					Sound = false,
					OnClick = function()
						local ok, text = Remotes.Fuse:InvokeServer(id)
						msg.TextColor3 = if ok then T.Palette.gold else T.Palette.hpLow
						msg.Text = text or (if ok then "Pronto." else "N\u{e3}o foi poss\u{ed}vel.")
						UI.play(if ok then "reward" else "error")
					end,
				})
				local sell, sface = UI.button(face, {
					Name = "Sell_" .. id,
					Color = if canSell then "green" else "grey",
					Size = UDim2.fromScale(0.225, 0.66),
					Position = UDim2.fromScale(0.75, 0.5),
					AnchorPoint = Vector2.new(0, 0.5),
					Sound = false,
					OnClick = function()
						local ok, text = Remotes.SellDuplicate:InvokeServer(id)
						msg.TextColor3 = if ok then T.Palette.gold else T.Palette.hpLow
						msg.Text = text or (if ok then "Pronto." else "N\u{e3}o foi poss\u{ed}vel.")
						UI.play(if ok then "purchase" else "error")
					end,
				})
				UI.icon(sface, "coin", { Size = UDim2.fromScale(0.28, 0.78), Position = UDim2.fromScale(0.06, 0.5), AnchorPoint = Vector2.new(0, 0.5) })
				UI.text(sface, "+" .. UI.fmt(Summon.SellPrice[def.Rarity]), { Name = "Price", Size = UDim2.fromScale(0.6, 0.72), Position = UDim2.fromScale(0.36, 0.14), Role = "Small", AlignX = Enum.TextXAlignment.Left })
			end
		end
	end)
end

--------------------------------------------------------------------
-- Perfil, portal e chat
--------------------------------------------------------------------
local function apply(p)
	if typeof(p) ~= "table" then
		return
	end
	profile = p
	updateBannerSelection()
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
	weeklyCharId = nil
	msg.Text = ""
	bannerMsg.Text = ""
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
		stopNameplateSync()
		if releaseAllAlbumCards then
			releaseAllAlbumCards()
		end
		showcase.Visible = false
		BannerStage.Close()
		win.Close(true)
		reveal.Close(true)
	end
end)
