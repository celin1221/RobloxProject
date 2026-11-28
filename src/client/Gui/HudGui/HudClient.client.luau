--[[
	HudClient (GDD secao 10 - HUD do mapa)
	- Moedas no topo a esquerda (gold, gemas, minerio), com o numero subindo contando.
	- Menu 3x2 a esquerda, acima da zona do analogico: Equipe, Mochila, Base, Loja, Premios, Album.
  A tela Time (nivel, XP, golpes e doces) abre pelo botao GOLPES do cartao da barra do time.
	- Aviso do evento de fim de semana e avisos curtos (toast) do servidor.
	- Escolha do personagem inicial e menu Time (nivel, XP e golpes ativos).
	O cliente so mostra e pede; o servidor valida (ProgressionService).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local gui = script.Parent
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Data = ReplicatedStorage:WaitForChild("Data")
local Characters = require(Data:WaitForChild("Characters"))
local Moves = require(Data:WaitForChild("Moves"))
local TypeChart = require(Data:WaitForChild("TypeChart"))
local Progression = require(Data:WaitForChild("Progression"))
local StarterTrack = require(Data:WaitForChild("StarterTrack"))
local UI = require(ReplicatedStorage:WaitForChild("UI"))
local TeamCards = require(ReplicatedStorage:WaitForChild("TeamCards"))
local T = UI.Theme

local profile = nil
local canvas = UI.screen(gui)
gui.DisplayOrder = 5

local function typeColor(t)
	return T.Types[t] or TypeChart.Color[t] or T.Palette.grey
end

--------------------------------------------------------------------
-- Topo: moedas
--------------------------------------------------------------------
local hud = UI.frame(canvas, { Name = "Hud" })
local top = UI.frame(hud, { Name = "Top", Size = UDim2.fromScale(0.42, 0.095), Position = UDim2.fromScale(0.02, 0.028), MaxSize = Vector2.new(470, 50) })
local topLayout = Instance.new("UIListLayout")
topLayout.FillDirection = Enum.FillDirection.Horizontal
topLayout.Padding = UDim.new(0.04, 0)
topLayout.VerticalAlignment = Enum.VerticalAlignment.Center
topLayout.SortOrder = Enum.SortOrder.LayoutOrder
topLayout.Parent = top
local _, goldLabel = UI.pill(top, "coin", "gold", { Name = "Gold", Size = UDim2.fromScale(0.34, 1), Aspect = 3.1, LayoutOrder = 1 })
local _, gemsLabel = UI.pill(top, "gem", "gems", { Name = "Gems", Size = UDim2.fromScale(0.27, 1), Aspect = 2.4, LayoutOrder = 2 })
local _, oreLabel = UI.pill(top, "ore", "ore", { Name = "Ore", Size = UDim2.fromScale(0.29, 1), Aspect = 2.7, LayoutOrder = 3 })
-- um pequeno respiro a esquerda para o icone que sai da pilula
local topPad = Instance.new("UIPadding")
topPad.PaddingLeft = UDim.new(0.02, 0)
topPad.Parent = top

-- Taxa de gold ao vivo da Base (+X/s logo abaixo da pilula de gold)
local liveRateLabel = UI.text(hud, "", {
	Name = "LiveGoldRate",
	Size = UDim2.fromScale(0.18, 0.038),
	Position = UDim2.fromScale(0.032, 0.128),
	Role = "Small",
	Color = "gold",
	AlignX = Enum.TextXAlignment.Left,
	StrokeMult = 0.55,
	Visible = false,
})

local function formatRatePerSec(rate: number): string
	if rate >= 10 then
		return string.format("+%s/s", UI.fmt(math.floor(rate + 0.5)))
	end
	local s = string.format("%.1f", rate):gsub("%.0$", "")
	return "+" .. s .. "/s"
end

local function syncLiveGoldRate()
	local r = player:GetAttribute("LiveGoldRate")
	if typeof(r) == "number" and r > 0 then
		liveRateLabel.Text = formatRatePerSec(r)
		liveRateLabel.Visible = true
	else
		liveRateLabel.Visible = false
	end
end
player:GetAttributeChangedSignal("LiveGoldRate"):Connect(syncLiveGoldRate)
syncLiveGoldRate()

-- Card compacto da Trilha de Objetivos Iniciais (canto superior direito, logo abaixo da engrenagem)
local trackBtn, trackFace = UI.button(hud, {
	Name = "StarterTrack",
	Color = "panel",
	Size = UDim2.fromScale(0.25, 0.21),
	Position = UDim2.fromScale(0.985, 0.20),
	AnchorPoint = Vector2.new(1, 0),
	Corner = 0.16,
	MaxSize = Vector2.new(255, 86),
	Visible = false,
	Sound = false,
})
local trackStroke = UI.stroke(trackFace, T.Palette.gold, 1.15)
local trackHeader = UI.text(trackFace, "", {
	Name = "Header",
	Size = UDim2.fromScale(0.92, 0.28),
	Position = UDim2.fromScale(0.04, 0.06),
	Role = "Small",
	Color = "gold",
	AlignX = Enum.TextXAlignment.Left,
	StrokeMult = 0.45,
})
local trackDesc = UI.text(trackFace, "", {
	Name = "Desc",
	Size = UDim2.fromScale(0.92, 0.34),
	Position = UDim2.fromScale(0.04, 0.34),
	Role = "Small",
	Color = "onDark",
	AlignX = Enum.TextXAlignment.Left,
	StrokeMult = 0.4,
})
local trackFoot = UI.text(trackFace, "", {
	Name = "Foot",
	Size = UDim2.fromScale(0.92, 0.26),
	Position = UDim2.fromScale(0.04, 0.70),
	Role = "Small",
	Color = "inkSoft",
	AlignX = Enum.TextXAlignment.Left,
	StrokeMult = 0.45,
})
local currentTrackStep = nil
local currentTrackDone = false
local claimingTrack = false

local function refreshStarterTrack()
	if not profile or not profile.StarterChosen then
		trackBtn.Visible = false
		currentTrackStep = nil
		currentTrackDone = false
		return
	end
	local step, have, need, done = StarterTrack.CurrentStep(profile)
	if not step then
		trackBtn.Visible = false
		currentTrackStep = nil
		currentTrackDone = false
		return
	end
	currentTrackStep = step
	currentTrackDone = done
	trackBtn.Visible = true
	trackHeader.Text = string.format("GUIA %d/%d \u{b7} %s", step.Index, #StarterTrack.Steps, step.Title)
	trackDesc.Text = step.Desc
	if done then
		UI.paint(trackBtn, "green")
		trackStroke.Color = T.Palette.gold
		trackFoot.TextColor3 = T.Palette.gold
		trackFoot.Text = "TOQUE PARA RESGATAR: " .. step.RewardText
	else
		UI.paint(trackBtn, "panel")
		trackStroke.Color = T.Palette.blue
		trackFoot.TextColor3 = T.Palette.inkSoft
		trackFoot.Text = string.format("Progresso %d/%d \u{b7} %s", have, need, step.RewardText)
	end
end

trackBtn.Activated:Connect(function()
	if not currentTrackStep or claimingTrack then
		return
	end
	if currentTrackDone then
		claimingTrack = true
		local ok, text = Remotes.Rewards:InvokeServer("StarterStep", currentTrackStep.Id)
		claimingTrack = false
		if ok then
			UI.play("reward")
			showToast(text)
		else
			UI.play("error")
			if text and text ~= "" then
				showToast(text)
			end
		end
	elseif currentTrackStep.HintAction then
		UI.play("click")
		UI.open(currentTrackStep.HintAction)
	else
		UI.play("click")
		showToast(currentTrackStep.Desc)
	end
end)

--------------------------------------------------------------------
-- Menu 3x2 (acima da zona do analogico)
--------------------------------------------------------------------
local menu = UI.frame(hud, { Name = "Menu", Size = UDim2.fromScale(0.3, 0.4), Position = UDim2.fromScale(0.02, 0.20), Aspect = 1.55, AspectAxis = Enum.DominantAxis.Height, MaxSize = Vector2.new(330, 213) })
local MENU = {
	{ "Equipe", "team", "EQUIPE", "blue" }, -- tela de Equipe (EquipeClient); golpes e doces abrem pelo cartao do personagem
	{ "Bag", "bag", "MOCHILA", "green" },
	{ "Base", "house", "BASE", "orange" },
	{ "Shop", "shop", "LOJA", "teal" },
	{ "Rewards", "gift", "PR\u{ca}MIOS", "purple" },
	{ "Album", "book", "\u{c1}LBUM", "red" },
}
local menuButtons = {}
for i, e in ipairs(MENU) do
	local col, row = (i - 1) % 3, (i - 1) // 3
	menuButtons[e[1]] = UI.button(menu, {
		Name = e[1] .. "Button", Icon = e[2], Text = e[3], Color = e[4], Layout = "stack", Role = "Small",
		Size = UDim2.fromScale(0.29, 0.42), Position = UDim2.fromScale(col * 0.355, row * 0.55), Aspect = 1, Corner = 0.26,
		OnClick = function()
			if not profile or not profile.StarterChosen then
				return
			end
			UI.open(e[1])
		end,
	})
end
-- Configuracoes: engrenagem no canto de cima a direita + botao discreto da Arena PvP ao lado
local settingsButton = UI.button(hud, { Name = "SettingsButton", Icon = "gear", Color = "grey", Layout = "icon", Size = UDim2.fromScale(0.10, 0.12), Position = UDim2.fromScale(0.985, 0.028), AnchorPoint = Vector2.new(1, 0), Aspect = 1, AspectAxis = Enum.DominantAxis.Height, MaxSize = Vector2.new(52, 52), Corner = 0.3,
	OnClick = function()
		UI.open("Settings")
	end,
})
local pvpButton = UI.button(hud, {
	Name = "PvPButton",
	Icon = "sword",
	Text = "PVP",
	Color = "red",
	Layout = "row",
	Role = "Small",
	Size = UDim2.fromOffset(92, 50),
	Position = UDim2.new(0.985, -62, 0.028, 0),
	AnchorPoint = Vector2.new(1, 0),
	Corner = 0.3,
	MaxSize = Vector2.new(100, 52),
	OnClick = function()
		if not profile or not profile.StarterChosen then
			return
		end
		UI.open("PvP")
	end,
})

-- Posiciona o botao PVP ao lado da engrenagem e a Trilha Inicial abaixo sem colisoes
local function layoutRightStack()
	local h = hud.AbsoluteSize.Y
	if h < 40 then
		return
	end
	local topY = math.floor(h * 0.028)
	local gearW = math.max(T.TouchMin, math.floor(settingsButton.AbsoluteSize.X))
	local gearH = math.max(T.TouchMin, math.floor(settingsButton.AbsoluteSize.Y))
	local pvpW = math.clamp(math.floor(gearH * 1.8), 80, 100)
	pvpButton.Size = UDim2.fromOffset(pvpW, gearH)
	pvpButton.Position = UDim2.new(0.985, -(gearW + 10), 0, topY)
	trackBtn.Position = UDim2.new(0.985, 0, 0, topY + gearH + 14)
end
hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutRightStack)
settingsButton:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutRightStack)
task.defer(layoutRightStack)

-- ponto vermelho dos Premios (RewardsClient marca o atributo RewardsBadge no PlayerGui)
local badge = UI.frame(menuButtons.Rewards, { Name = "Badge", Size = UDim2.fromScale(0.36, 0.36), Position = UDim2.fromScale(0.95, -0.08), AnchorPoint = Vector2.new(0.5, 0), Color = "red", Aspect = 1, ZIndex = 4, Visible = false })
UI.stroke(badge)
UI.text(badge, "!", { Size = UDim2.fromScale(1, 1), Role = "Small", ZIndex = 5 })

--------------------------------------------------------------------
-- Evento de fim de semana (selo minimalista no canto inferior direito + tooltip no hover)
--------------------------------------------------------------------
local isTouchOnly = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local eventWrap = UI.frame(hud, {
	Name = "Event",
	Size = UDim2.fromScale(0.28, 0.09),
	Position = UDim2.fromScale(0.985, if isTouchOnly then 0.64 else 0.965),
	AnchorPoint = Vector2.new(1, 1),
	MaxSize = Vector2.new(280, 54),
	Visible = false,
	ZIndex = 4,
})
local eventWrapLim = eventWrap:FindFirstChild("MaxSize")
if eventWrapLim and eventWrapLim:IsA("UISizeConstraint") then
	eventWrapLim.MinSize = Vector2.new(160, T.TouchMin)
end

local eventBadge, eventBadgeFace = UI.panel(eventWrap, {
	Name = "Badge",
	Class = "TextButton",
	Color = "slot",
	Corner = T.Corner.Pill,
	Shadow = false,
	Size = UDim2.fromScale(1, 1),
	Position = UDim2.fromScale(1, 0.5),
	AnchorPoint = Vector2.new(1, 0.5),
	Aspect = 1,
	AspectAxis = Enum.DominantAxis.Height,
	ZIndex = 5,
})
local eventMin = Instance.new("UISizeConstraint")
eventMin.MinSize = Vector2.new(T.TouchMin, T.TouchMin)
eventMin.MaxSize = Vector2.new(54, 54)
eventMin.Parent = eventBadge
local eventBadgeScale = Instance.new("UIScale")
eventBadgeScale.Parent = eventBadge

local eventIcon = UI.icon(eventBadgeFace, "coin", {
	Name = "Icon",
	Size = UDim2.fromScale(0.7, 0.7),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	ZIndex = 6,
})

local eventTip, eventTipFace = UI.panel(eventWrap, {
	Name = "Tooltip",
	Color = "slot",
	Corner = T.Corner.Pill,
	Shadow = false,
	Size = UDim2.fromScale(0.7, 0.78),
	Position = UDim2.new(1, -64, 0.5, 0),
	AnchorPoint = Vector2.new(1, 0.5),
	Visible = false,
	ZIndex = 6,
})
local eventTipScale = Instance.new("UIScale")
eventTipScale.Parent = eventTip
local eventTipLabel = UI.text(eventTipFace, "2x de Moedas", {
	Name = "Text",
	Size = UDim2.fromScale(0.88, 0.84),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Color = "gold",
	Role = "Small",
	StrokeMult = 0.7,
	ZIndex = 7,
})

local function layoutEventTip()
	local bSz = UI.unscaledSize(eventBadge)
	if bSz > 1 then
		eventTip.Position = UDim2.new(1, -(math.floor(bSz + 0.5) + 10), 0.5, 0)
	end
	local hudW = hud.AbsoluteSize.X
	if hudW > 40 then
		eventWrap.Position = UDim2.fromScale(0.985, if isTouchOnly or hudW < 820 then 0.64 else 0.965)
	end
end
eventBadge:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutEventTip)
hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutEventTip)
task.defer(layoutEventTip)

local tipToken = 0
local function setEventTip(show: boolean)
	tipToken += 1
	if show then
		layoutEventTip()
		eventTip.Visible = true
		eventTipScale.Scale = 0.85
		TweenService:Create(eventTipScale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(eventBadgeScale, TweenInfo.new(T.Motion.HoverTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = T.Motion.HoverScale }):Play()
	else
		eventTip.Visible = false
		TweenService:Create(eventBadgeScale, TweenInfo.new(T.Motion.HoverTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
end

eventBadge.MouseEnter:Connect(function()
	setEventTip(true)
end)
eventBadge.MouseLeave:Connect(function()
	setEventTip(false)
end)
eventBadge.Activated:Connect(function()
	-- No celular (ou clique), alterna o tooltip e fecha sozinho apos 2.5s
	if eventTip.Visible then
		setEventTip(false)
	else
		setEventTip(true)
		local myToken = tipToken
		task.delay(2.5, function()
			if myToken == tipToken then
				setEventTip(false)
			end
		end)
	end
end)

local EVENT_STYLE = {
	Gold = { Icon = "coin", Text = "2x de Moedas", Color = "gold", Width = 0.72 },
	Xp = { Icon = "sparkle", Text = "2x de XP", Color = "blue", Width = 0.58 },
}

local toastHolder, toastFace = UI.panel(canvas, { Name = "Toast", Size = UDim2.fromScale(0.5, 0.1), Position = UDim2.fromScale(0.5, 0.265), AnchorPoint = Vector2.new(0.5, 0), Color = "panel", Corner = T.Corner.Pill, Visible = false, ZIndex = 30, MaxSize = Vector2.new(560, 60) })
local toastScale = Instance.new("UIScale")
toastScale.Parent = toastHolder
local toastLabel = UI.text(toastFace, "", { Name = "Text", Size = UDim2.fromScale(0.92, 0.72), Position = UDim2.fromScale(0.04, 0.14), Role = "Small", ZIndex = 31 })
local toastId = 0
local function showToast(text, kind)
	toastId += 1
	local id = toastId
	toastLabel.Text = tostring(text)
	-- na batalha fica abaixo do registro de mensagens; fora de batalha abaixo do banner de Raid e Fila PvP
	toastHolder.Position = UDim2.fromScale(0.5, if UI.inBattle() then 0.20 else 0.265)
	toastHolder.Visible = true
	toastScale.Scale = 0.6
	TweenService:Create(toastScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(3.5, function()
		if toastId == id then
			toastHolder.Visible = false
		end
	end)
end
UI.onOpen("Toast", showToast)
Remotes:WaitForChild("Notify").OnClientEvent:Connect(function(text)
	showToast(text)
end)

--------------------------------------------------------------------
-- Anuncio global do servidor (Lendario / Brilhante): banner animado + chat do sistema
--------------------------------------------------------------------
local pg = player:WaitForChild("PlayerGui")

local function escapeRich(s: string): string
	return (tostring(s or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local announceGui = pg:FindFirstChild("ServerAnnounceOverlay")
if not announceGui then
	announceGui = Instance.new("ScreenGui")
	announceGui.Name = "ServerAnnounceOverlay"
	announceGui.ResetOnSpawn = false
	announceGui.IgnoreGuiInset = false
	announceGui.DisplayOrder = 25 -- acima de todas as janelas (Info = 16, Battle = 10, Rewards/Shop/Summon = 9)
	announceGui.Parent = pg
end
local announceCanvas = UI.screen(announceGui)

local bannerHolder, bannerFace = UI.panel(announceCanvas, {
	Name = "LegendaryBanner",
	Size = UDim2.fromScale(0.48, 0.115),
	Position = UDim2.fromScale(0.5, -0.15),
	AnchorPoint = Vector2.new(0.5, 0),
	Color = "panel",
	Corner = 0.24,
	Visible = false,
	ZIndex = 40,
	MaxSize = Vector2.new(540, 74),
	MinSize = Vector2.new(300, 56),
})
bannerHolder.Active = false
bannerFace.Active = false
local bannerScale = Instance.new("UIScale")
bannerScale.Parent = bannerHolder
local bannerShine = UI.shine(bannerFace, Color3.fromRGB(255, 240, 175))
bannerShine.ZIndex = 41

local bannerPortrait = TeamCards.new(bannerFace, {
	Name = "Portrait",
	CompactPortrait = true,
	Size = UDim2.fromScale(0.14, 0.84),
	Position = UDim2.fromScale(0.02, 0.5),
	AnchorPoint = Vector2.new(0, 0.5),
	ZIndex = 42,
})
local bannerPortraitAr = Instance.new("UIAspectRatioConstraint")
bannerPortraitAr.AspectRatio = 1
bannerPortraitAr.DominantAxis = Enum.DominantAxis.Height
bannerPortraitAr.Parent = bannerPortrait.Root
bannerPortrait.Root.Active = false
bannerPortrait.Root.Selectable = false

local bannerFallbackIcon = UI.icon(bannerFace, "star", {
	Name = "FallbackIcon",
	Size = UDim2.fromScale(0.11, 0.72),
	Position = UDim2.fromScale(0.03, 0.5),
	AnchorPoint = Vector2.new(0, 0.5),
	AspectAxis = Enum.DominantAxis.Height,
	ZIndex = 42,
	Visible = false,
})

local bannerTagIcon = UI.icon(bannerFace, "star", {
	Name = "TagIcon",
	Size = UDim2.fromScale(0.055, 0.30),
	Position = UDim2.fromScale(0.175, 0.11),
	AspectAxis = Enum.DominantAxis.Height,
	ZIndex = 43,
})
local bannerTagLabel = UI.text(bannerFace, "LEND\u{c1}RIO NO SERVIDOR", {
	Name = "TagLabel",
	Size = UDim2.fromScale(0.74, 0.31),
	Position = UDim2.fromScale(0.225, 0.10),
	Role = "Small",
	Color = "gold",
	AlignX = Enum.TextXAlignment.Left,
	StrokeMult = 0.5,
	ZIndex = 43,
})
bannerTagLabel.TextWrapped = false

local bannerMainLabel = UI.text(bannerFace, "", {
	Name = "MainLabel",
	Size = UDim2.fromScale(0.79, 0.50),
	Position = UDim2.fromScale(0.175, 0.43),
	Role = "Small",
	Color = "onDark",
	AlignX = Enum.TextXAlignment.Left,
	Rich = true,
	StrokeMult = 0.5,
	ZIndex = 43,
})

local announceQueue = {}
local announceBusy = false
local bannerTurnConn: RBXScriptConnection? = nil

local function stopBannerTurn()
	if bannerTurnConn then
		bannerTurnConn:Disconnect()
		bannerTurnConn = nil
	end
end

local function startBannerTurn()
	stopBannerTurn()
	local elapsed = 0
	bannerTurnConn = RunService.RenderStepped:Connect(function(dt)
		if not bannerHolder.Visible then
			stopBannerTurn()
			return
		end
		elapsed += dt
		bannerPortrait.SetAngle(math.sin(elapsed * 1.6) * 0.28)
	end)
end

local function postSystemChat(text: string, meta)
	local isSecret = meta and meta.Rarity == "Secreto"
	local isLeg = meta and meta.Rarity == "Lendario"
	local isShiny = meta and meta.Variant == "Brilhante"
	local richMsg
	if meta and meta.PlayerName and meta.CharacterName then
		local tagColor = if isSecret then "#FF4D6D" elseif isShiny then "#73F5FF" else "#FFD84A"
		local tagText = if isSecret and isShiny
			then "[SECRETO BRILHANTE]"
			elseif isSecret then "[SECRETO]"
			elseif isLeg and isShiny then "[LEND\u{c1}RIO BRILHANTE]"
			elseif isLeg then "[LEND\u{c1}RIO]"
			else "[BRILHANTE]"
		local nameCol = if isSecret then "#FF5E7A" else "#FFB41F"
		local pName = escapeRich(meta.PlayerName)
		local cName = escapeRich(meta.CharacterName)
		local verb = escapeRich(meta.Verb or "conseguiu")
		local place = if meta.Place and #meta.Place > 0 then (" " .. escapeRich(meta.Place)) else ""
		local shinyTxt = if isShiny then " Brilhante" else ""
		richMsg = string.format(
			'<font color="%s"><b>%s</b></font> <font color="#FFFFFF"><b>%s</b></font> <font color="#FFE79A">%s</font> <font color="%s"><b>%s%s</b></font><font color="#FFE79A">%s!</font>',
			tagColor, tagText, pName, verb, nameCol, cName, shinyTxt, place
		)
	else
		richMsg = '<font color="#FFD84A">' .. escapeRich(text) .. "</font>"
	end

	local shown = false
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general then
			general:DisplaySystemMessage(richMsg)
			shown = true
		end
	end)
	if not shown then
		pcall(function()
			StarterGui:SetCore("ChatMakeSystemMessage", {
				Text = text,
				Color = if isSecret then Color3.fromRGB(255, 77, 109) elseif isShiny then Color3.fromRGB(115, 245, 255) else Color3.fromRGB(255, 216, 74),
			})
		end)
	end
end

local function drainAnnounceQueue()
	if announceBusy then
		return
	end
	announceBusy = true
	task.spawn(function()
		while #announceQueue > 0 do
			local item = table.remove(announceQueue, 1)
			local text, meta = item.Text, item.Meta
			local isRaidOpen = meta and meta.Kind == "RaidOpen"
			local isSecret = meta and meta.Rarity == "Secreto"
			local isLeg = meta and meta.Rarity == "Lendario"
			local isShiny = meta and meta.Variant == "Brilhante"

			local stroke = bannerFace:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = if isSecret
					then Color3.fromRGB(235, 42, 74)
					elseif isRaidOpen and (meta.Stars or 3) == 4 then Color3.fromRGB(168, 85, 247)
					elseif isRaidOpen and (meta.Stars or 3) == 3 then Color3.fromRGB(63, 168, 255)
					elseif isShiny then Color3.fromRGB(115, 245, 255)
					else T.Palette.lendario
			end

			if isRaidOpen then
				UI.setIcon(bannerTagIcon, if isSecret then "sparkle" else "sword")
				bannerTagLabel.Text = string.format("RAID GLOBAL %d ESTRELAS ABERTA!", tonumber(meta.Stars) or 3)
				bannerTagLabel.TextColor3 = if isSecret then Color3.fromRGB(255, 92, 122) else T.Palette.gold
			elseif isSecret and isShiny then
				UI.setIcon(bannerTagIcon, "sparkle")
				bannerTagLabel.Text = "SECRETO BRILHANTE NO SERVIDOR"
				bannerTagLabel.TextColor3 = Color3.fromRGB(255, 92, 122)
			elseif isSecret then
				UI.setIcon(bannerTagIcon, "sparkle")
				bannerTagLabel.Text = "SECRETO NO SERVIDOR"
				bannerTagLabel.TextColor3 = Color3.fromRGB(240, 240, 248)
			elseif isLeg and isShiny then
				UI.setIcon(bannerTagIcon, "sparkle")
				bannerTagLabel.Text = "LEND\u{c1}RIO BRILHANTE NO SERVIDOR"
				bannerTagLabel.TextColor3 = Color3.fromRGB(115, 245, 255)
			elseif isLeg then
				UI.setIcon(bannerTagIcon, "star")
				bannerTagLabel.Text = "LEND\u{c1}RIO NO SERVIDOR"
				bannerTagLabel.TextColor3 = T.Palette.gold
			else
				UI.setIcon(bannerTagIcon, "sparkle")
				bannerTagLabel.Text = "BRILHANTE NO SERVIDOR"
				bannerTagLabel.TextColor3 = Color3.fromRGB(115, 245, 255)
			end

			local targetY = if UI.inBattle() then 0.145 else 0.16
			bannerHolder.Position = UDim2.fromScale(0.5, -0.15)
			bannerScale.Scale = 0.82
			bannerHolder.Visible = true

			if meta and meta.CharacterId and Characters.Get(meta.CharacterId) then
				bannerPortrait.Root.Visible = true
				bannerFallbackIcon.Visible = false
				bannerPortrait.Set("announce_" .. meta.CharacterId, {
					CharacterId = meta.CharacterId,
					Level = 1,
					Variant = meta.Variant,
					Stars = 0,
				})
				startBannerTurn()
			else
				stopBannerTurn()
				bannerPortrait.Clear()
				bannerPortrait.Root.Visible = false
				bannerFallbackIcon.Visible = true
			end

			if meta and meta.PlayerName and meta.CharacterName then
				local pName = escapeRich(meta.PlayerName)
				local cName = escapeRich(meta.CharacterName)
				local verb = escapeRich(meta.Verb or "conseguiu")
				local place = if meta.Place and #meta.Place > 0 then (" " .. escapeRich(meta.Place)) else ""
				local shinyTxt = if isShiny then " Brilhante" else ""
				bannerMainLabel.Text = string.format(
					'<font color="#FFFFFF"><b>%s</b></font> %s <font color="#FFB41F"><b>%s%s</b></font>%s!',
					pName, verb, cName, shinyTxt, place
				)
			else
				bannerMainLabel.Text = escapeRich(text)
			end

			TweenService:Create(bannerHolder, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, targetY) }):Play()
			TweenService:Create(bannerScale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			if not (meta and meta.SourceKey == "Summon" and meta.UserId == player.UserId) then
				UI.play("reward")
			end

			task.wait(4.8)

			local hideTween = TweenService:Create(bannerHolder, TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromScale(0.5, -0.15) })
			hideTween:Play()
			hideTween.Completed:Wait()
			stopBannerTurn()
			bannerHolder.Visible = false
			bannerPortrait.Clear()
			task.wait(0.2)
		end
		announceBusy = false
	end)
end

Remotes:WaitForChild("Announce").OnClientEvent:Connect(function(text, meta)
	if typeof(text) ~= "string" or #text == 0 then
		return
	end
	local function dispatch()
		postSystemChat(text, meta)
		table.insert(announceQueue, { Text = text, Meta = meta })
		drainAnnounceQueue()
	end
	-- Para quem esta invocando, espera o fim da revelacao 3D para nao dar spoiler antes da carta aparecer
	if typeof(meta) == "table" and meta.SourceKey == "Summon" and meta.UserId == player.UserId then
		task.delay(3.8, dispatch)
	else
		dispatch()
	end
end)

local function syncAttrs()
	badge.Visible = pg:GetAttribute("RewardsBadge") == true
	local evId = pg:GetAttribute("WeekendEventId")
	local ev = pg:GetAttribute("WeekendEvent")
	local active = (typeof(evId) == "string" and evId ~= "") or (typeof(ev) == "string" and ev ~= "")
	if not active then
		eventWrap.Visible = false
		eventTip.Visible = false
		return
	end
	local key = if typeof(evId) == "string" and EVENT_STYLE[evId]
		then evId
		elseif typeof(ev) == "string" and string.find(string.upper(ev), "XP") then "Xp"
		else "Gold"
	local st = EVENT_STYLE[key]
	UI.setIcon(eventIcon, st.Icon)
	eventTipLabel.Text = st.Text
	eventTipLabel.TextColor3 = T.Palette[st.Color] or T.Palette.gold
	eventTip.Size = UDim2.fromScale(st.Width, 0.78)
	eventWrap.Visible = true
	layoutEventTip()
end
pg:GetAttributeChangedSignal("RewardsBadge"):Connect(syncAttrs)
pg:GetAttributeChangedSignal("WeekendEvent"):Connect(syncAttrs)
pg:GetAttributeChangedSignal("WeekendEventId"):Connect(syncAttrs)
syncAttrs()

--------------------------------------------------------------------
-- Escolha do inicial
--------------------------------------------------------------------
local starterWin = UI.window(canvas, { Name = "Starter", Title = "ESCOLHA SEU PARCEIRO", Icon = "star", Size = UDim2.fromScale(0.86, 0.8), Aspect = 1.9 })
starterWin.CloseButton.Visible = false
local starterMsg = UI.text(starterWin.Body, "", { Name = "Message", Size = UDim2.fromScale(1, 0.1), Position = UDim2.fromScale(0, 0.9), Role = "Small", Color = "hpLow" })
local cards = UI.frame(starterWin.Body, { Name = "Cards", Size = UDim2.fromScale(1, 0.86), Position = UDim2.fromScale(0, 0.02) })
local cardsLayout = Instance.new("UIListLayout")
cardsLayout.FillDirection = Enum.FillDirection.Horizontal
cardsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
cardsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
cardsLayout.Padding = UDim.new(0.03, 0)
cardsLayout.Parent = cards

local choosing = false
local function buildStarterCards()
	UI.clear(cards)
	for i, id in ipairs(Characters.Starters()) do
		local def = Characters.Get(id)
		local animeInfo = def.Anime and Characters.Animes and Characters.Animes[def.Anime]
		local animeName = (animeInfo and animeInfo.Name) or def.Anime or ""
		local card, face = UI.panel(cards, { Name = "Card_" .. id, Size = UDim2.fromScale(0.31, 1), Color = "panelAlt", Corner = T.Corner.Card, Aspect = 0.72, LayoutOrder = i })
		UI.stroke(face, typeColor(def.Type), 1.3)
		UI.text(face, def.Name, { Name = "Name", Size = UDim2.fromScale(0.9, 0.11), Position = UDim2.fromScale(0.05, 0.03), Role = "Heading" })
		UI.text(face, UI.upper(animeName), { Name = "Anime", Size = UDim2.fromScale(0.9, 0.07), Position = UDim2.fromScale(0.05, 0.145), Role = "Small", Color = "gold", StrokeMult = 0.4 })
		local classRow = UI.frame(face, { Name = "ClassRow", Size = UDim2.fromScale(0.84, 0.10), Position = UDim2.fromScale(0.08, 0.23) })
		local iconKey = UI.TypeIcon[def.Type]
		if iconKey then
			UI.icon(classRow, iconKey, { Name = "ClassIcon", Size = UDim2.fromScale(0.22, 0.92), Position = UDim2.fromScale(0.02, 0.04), AspectAxis = Enum.DominantAxis.Height })
		end
		UI.chip(classRow, UI.upper(TypeChart.DisplayName[def.Type] or def.Type), typeColor(def.Type), {
			Name = "Type",
			Size = UDim2.fromScale(if iconKey then 0.74 else 0.9, 0.86),
			Position = UDim2.fromScale(if iconKey then 0.24 else 0.05, 0.07),
		})
		UI.text(face, def.Concept or "", { Name = "Concept", Size = UDim2.fromScale(0.88, 0.18), Position = UDim2.fromScale(0.06, 0.345), Role = "Small", Color = "inkSoft", StrokeMult = 0.4 })
		local st = Characters.StatsAt(id, Progression.StarterLevel)
		UI.text(face, string.format("HP %d  ATQ %d\nDEF %d  VEL %d", st.HP, st.Attack, st.Defense, st.Speed), { Name = "Stats", Size = UDim2.fromScale(0.88, 0.16), Position = UDim2.fromScale(0.06, 0.53), Role = "Small" })
		if animeName ~= "" then
			UI.text(face, "Libera Banner " .. animeName, { Name = "BannerUnlock", Size = UDim2.fromScale(0.88, 0.075), Position = UDim2.fromScale(0.06, 0.70), Role = "Small", Color = "gold", StrokeMult = 0.4 })
		end
		UI.button(face, {
			Name = "Choose_" .. id, Text = "ESCOLHER", Color = "green", Size = UDim2.fromScale(0.8, 0.14), Position = UDim2.fromScale(0.1, 0.8), Role = "Body",
			Sound = "reward",
			OnClick = function()
				if choosing then
					return
				end
				choosing = true
				starterMsg.Text = ""
				local ok, err = Remotes.ChooseStarter:InvokeServer(id)
				choosing = false
				if ok then
					starterWin.Close()
				else
					starterMsg.Text = err or "Tente de novo."
					UI.play("error")
				end
			end,
		})
	end
end

--------------------------------------------------------------------
-- Menu Golpes (estilo Pokemon: retratos 3D, 4 golpes ativos + card de detalhes + lista completa)
--------------------------------------------------------------------
local teamWin = UI.window(canvas, { Name = "TeamWindow", Title = "GOLPES", Icon = "book", HeaderColor = "blue", Size = UDim2.fromScale(0.92, 0.86), Aspect = 1.88 })
local list = UI.scroll(teamWin.Body, { Name = "Members", Size = UDim2.fromScale(0.40, 1), Position = UDim2.fromScale(0, 0) })
local detail, detailFace = UI.panel(teamWin.Body, { Name = "Detail", Size = UDim2.fromScale(0.58, 1), Position = UDim2.fromScale(0.42, 0), Color = "slot", Corner = 0.06, Shadow = false })
local detailTitle = UI.text(detailFace, "", { Name = "Title", Size = UDim2.fromScale(0.68, 0.09), Position = UDim2.fromScale(0.035, 0.02), Role = "Heading", AlignX = Enum.TextXAlignment.Left })
local detailType = UI.chip(detailFace, "", "grey", { Name = "Type", Size = UDim2.fromScale(0.24, 0.072), Position = UDim2.fromScale(0.965, 0.028), AnchorPoint = Vector2.new(1, 0) })
local detailInfo = UI.text(detailFace, "", { Name = "Info", Size = UDim2.fromScale(0.93, 0.06), Position = UDim2.fromScale(0.035, 0.105), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.4 })

local movesBox = UI.scroll(detailFace, { Name = "Moves", Size = UDim2.fromScale(0.94, 0.40), Position = UDim2.fromScale(0.03, 0.175), Columns = 2, CellAspect = 3.85, Gap = 0.024 })

-- Card inferior de detalhes do golpe selecionado (estilo Pokemon: nome, chips, poder/precisao/PP e descricao)
local moveInfoPanel, moveInfoFace = UI.panel(detailFace, {
	Name = "MoveInfoCard",
	Size = UDim2.fromScale(0.94, 0.255),
	Position = UDim2.fromScale(0.03, 0.58),
	Color = "panelAlt",
	Corner = 0.12,
	Shadow = false,
})
local moveInfoName = UI.text(moveInfoFace, "", {
	Name = "MoveInfoName",
	Size = UDim2.fromScale(0.49, 0.27),
	Position = UDim2.fromScale(0.03, 0.06),
	Role = "Body",
	AlignX = Enum.TextXAlignment.Left,
})
moveInfoName.TextWrapped = false
local moveNameLim = moveInfoName:FindFirstChildOfClass("UITextSizeConstraint")
if moveNameLim then
	moveNameLim.MinTextSize = 10
end
local moveInfoChips = UI.frame(moveInfoFace, {
	Name = "MoveInfoChips",
	Size = UDim2.fromScale(0.43, 0.24),
	Position = UDim2.fromScale(0.97, 0.075),
	AnchorPoint = Vector2.new(1, 0),
})
local chipRowLayout = Instance.new("UIListLayout")
chipRowLayout.FillDirection = Enum.FillDirection.Horizontal
chipRowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
chipRowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
chipRowLayout.Padding = UDim.new(0, 4)
chipRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
chipRowLayout.Parent = moveInfoChips
local moveInfoClassChip = UI.chip(moveInfoChips, "", "grey", { Name = "ClassChip", Size = UDim2.fromScale(0.38, 1), LayoutOrder = 1 })
local moveInfoCatChip = UI.chip(moveInfoChips, "", "blue", { Name = "CatChip", Size = UDim2.fromScale(0.26, 1), LayoutOrder = 2 })
local moveInfoTargetChip = UI.chip(moveInfoChips, "", "slot", { Name = "TargetChip", Size = UDim2.fromScale(0.32, 1), LayoutOrder = 3 })
for _, ch in ipairs({ moveInfoClassChip, moveInfoCatChip, moveInfoTargetChip }) do
	ch.Face.Label.TextWrapped = false
end
local moveInfoStats = UI.text(moveInfoFace, "", {
	Name = "MoveInfoStats",
	Size = UDim2.fromScale(0.94, 0.21),
	Position = UDim2.fromScale(0.03, 0.36),
	Role = "Small",
	Color = "onDark",
	AlignX = Enum.TextXAlignment.Left,
	Rich = true,
	StrokeMult = 0.45,
})
local moveInfoDesc = UI.text(moveInfoFace, "", {
	Name = "MoveInfoDesc",
	Size = UDim2.fromScale(0.94, 0.36),
	Position = UDim2.fromScale(0.03, 0.59),
	Role = "Small",
	Color = "inkSoft",
	AlignX = Enum.TextXAlignment.Left,
	AlignY = Enum.TextYAlignment.Top,
	StrokeMult = 0.35,
})

-- Doces de XP (so caem no Refugio): um botao por doce, usa no personagem escolhido
local CANDIES = { { Id = "DoceComum", Icon = "doce_comum", Color = "panelAlt" }, { Id = "DoceRaro", Icon = "doce_raro", Color = "blue" }, { Id = "DoceEpico", Icon = "doce_epico", Color = "purple" } }
local detailBottomBar = UI.frame(detailFace, { Name = "BottomBar", Size = UDim2.fromScale(0.94, 0.13), Position = UDim2.fromScale(0.03, 0.975), AnchorPoint = Vector2.new(0, 1) })
UI.clampHeight(detailBottomBar, T.TouchMin, 48)
local candyRow = UI.frame(detailBottomBar, { Name = "Candies", Size = UDim2.fromScale(0.55, 1), Position = UDim2.fromScale(0, 0) })
local candyButtons = {}
local useCandy
local detailMsg = UI.text(detailFace, "", { Name = "Message", Size = UDim2.fromScale(0.93, 0.055), Position = UDim2.fromScale(0.035, 0.80), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.4 })
local changeMovesBtn = UI.button(detailBottomBar, { Name = "ChangeMoves", Text = "TROCAR GOLPES", Icon = "swap", Color = "blue", Layout = "row", Size = UDim2.fromScale(0.42, 1), Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(1, 0), Role = "Small" })
local cancelChangeBtn = UI.button(detailBottomBar, { Name = "CancelChange", Text = "VOLTAR", Color = "grey", Size = UDim2.fromScale(0.36, 1), Position = UDim2.fromScale(0, 0), Role = "Body", Visible = false })
local saveButton = UI.button(detailBottomBar, { Name = "SaveMoves", Text = "SALVAR", Icon = "tick", Color = "green", Layout = "row", Size = UDim2.fromScale(0.60, 1), Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(1, 0), Role = "Body", Visible = false })

local function layoutTeamDetail()
	local h = detailFace.AbsoluteSize.Y
	if h < 60 then
		return
	end
	local padBot = math.max(6, math.floor(h * 0.022))
	local bottomH = math.max(T.TouchMin, math.floor(detailBottomBar.AbsoluteSize.Y))
	local bottomY = h - padBot - bottomH
	local msgH = math.max(15, math.floor(h * 0.052))
	local msgY = bottomY - msgH - 3
	detailMsg.Position = UDim2.new(0.035, 0, 0, msgY)
	detailMsg.Size = UDim2.new(0.93, 0, 0, msgH)

	local infoH = math.clamp(math.floor(h * 0.255), 78, 118)
	local infoY = msgY - infoH - 5
	moveInfoPanel.Position = UDim2.new(0.03, 0, 0, infoY)
	moveInfoPanel.Size = UDim2.new(0.94, 0, 0, infoH)

	local movesTop = math.floor(h * 0.172)
	local movesH = math.max(60, infoY - movesTop - 6)
	movesBox.Position = UDim2.new(0.03, 0, 0, movesTop)
	movesBox.Size = UDim2.new(0.94, 0, 0, movesH)
end
detailFace:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutTeamDetail)
detailBottomBar:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutTeamDetail)
task.defer(layoutTeamDetail)

local selectedUid = nil
local pick = {} -- golpes marcados no modo "Change"
local viewMode = "Equipped" -- "Equipped" (4 golpes estilo Pokemon) | "Change" (lista aprendidos + bloqueados)
local inspectedMoveId: string? = nil
local inspectedUnlockLv: number? = nil
local listPortraits = {} -- TeamCards ativos na barra lateral (limpos antes de reconstruir ou fechar)
local lastListKey: string? = nil
local refreshDetail
local STATUS_NAME = { Burn = "Queimado", Poison = "Envenenado", Paralysis = "Paralisado", Sleep = "Dormindo", Freeze = "Congelado" }

local function clearListPortraits()
	for _, card in ipairs(listPortraits) do
		card.Clear()
	end
	table.clear(listPortraits)
	lastListKey = nil
end

local function computeListKey(): string
	if not profile then
		return ""
	end
	local parts = { tostring(selectedUid) }
	local inTeam = {}
	for _, uid in ipairs(profile.Team or {}) do
		inTeam[uid] = true
	end
	local uids = {}
	if selectedUid and profile.Collection and profile.Collection[selectedUid] and not inTeam[selectedUid] then
		table.insert(uids, selectedUid)
	end
	for _, uid in ipairs(profile.Team or {}) do
		table.insert(uids, uid)
	end
	for _, uid in ipairs(uids) do
		local m = profile.Collection and profile.Collection[uid]
		if m then
			table.insert(parts, string.format("%s:%d:%d:%s:%s:%s", uid, m.Level or 1, m.Xp or 0, tostring(m.Hp), tostring(m.Status), tostring(m.Variant)))
		end
	end
	return table.concat(parts, ";")
end

local function refreshList(force: boolean?)
	local key = computeListKey()
	if not force and lastListKey == key and #listPortraits > 0 then
		return
	end
	clearListPortraits()
	UI.clear(list)
	if not profile then
		return
	end
	lastListKey = key
	local uids = {}
	local inTeam = {}
	for _, uid in ipairs(profile.Team or {}) do
		inTeam[uid] = true
	end
	-- Se abriu pela tela Info de um personagem fora do time ativo, mostra ele no topo da lista
	if selectedUid and profile.Collection and profile.Collection[selectedUid] and not inTeam[selectedUid] then
		table.insert(uids, selectedUid)
	end
	for _, uid in ipairs(profile.Team or {}) do
		table.insert(uids, uid)
	end

	for i, uid in ipairs(uids) do
		local m = profile.Collection[uid]
		if m then
			local def = Characters.Get(m.CharacterId)
			local hp, max = Progression.CurrentHp(m)
			local need = Progression.XpToNext(m.Level)
			local isBench = not inTeam[uid]
			local _, face = UI.button(list, {
				Name = "Member_" .. uid,
				Color = if uid == selectedUid then "blue" else "panelAlt",
				Size = UDim2.fromScale(0.98, 0),
				Aspect = 3.25,
				LayoutOrder = i,
				Corner = 0.2,
				OnClick = function()
					selectedUid = uid
					pick = table.clone(m.Active)
					viewMode = "Equipped"
					inspectedMoveId = m.Active[1] or m.Learned[1]
					inspectedUnlockLv = nil
					detailMsg.Text = ""
					refreshList()
					refreshDetail()
				end,
			})
			-- Retrato 3D do personagem (TeamCards em modo CompactPortrait)
			local portrait = TeamCards.new(face, {
				Name = "Portrait",
				CompactPortrait = true,
				Size = UDim2.fromScale(0.24, 0.84),
				Position = UDim2.fromScale(0.025, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				ZIndex = 4,
			})
			local ar = Instance.new("UIAspectRatioConstraint")
			ar.AspectRatio = 1
			ar.DominantAxis = Enum.DominantAxis.Height
			ar.Parent = portrait.Root
			portrait.Root.Active = false
			portrait.Root.Selectable = false
			portrait.Set(uid, m)
			table.insert(listPortraits, portrait)

			UI.text(face, def and def.Name or m.CharacterId, { Name = "MemberName", Size = UDim2.fromScale(0.45, 0.32), Position = UDim2.fromScale(0.28, 0.08), Role = "Body", AlignX = Enum.TextXAlignment.Left })
			UI.text(face, "Nv. " .. m.Level, { Name = "Level", Size = UDim2.fromScale(0.22, 0.28), Position = UDim2.fromScale(0.96, 0.1), AnchorPoint = Vector2.new(1, 0), Role = "Small", Color = "gold", AlignX = Enum.TextXAlignment.Right })
			local bar = UI.bar(face, { Name = "Hp", Size = UDim2.fromScale(0.68, 0.16), Position = UDim2.fromScale(0.28, 0.47) })
			local ratio = if max > 0 then hp / max else 0
			UI.setBar(bar, ratio, if ratio > 0.5 then "hpHigh" elseif ratio > 0.2 then "hpMid" else "hpLow", true)
			local xp = if need > 0 then string.format("XP %d/%d", m.Xp, need) else "Nv. m\u{e1}x."
			local hpText = if hp <= 0 then "Desmaiado" else string.format("HP %d/%d", hp, max)
			local prefix = if isBench then "Cole\u{e7}\u{e3}o | " else ""
			UI.text(face, prefix .. hpText .. "  " .. xp .. (if m.Status then "  " .. (STATUS_NAME[m.Status] or m.Status) else ""), {
				Name = "Info",
				Size = UDim2.fromScale(0.68, 0.24),
				Position = UDim2.fromScale(0.28, 0.69),
				Role = "Small",
				AlignX = Enum.TextXAlignment.Left,
				StrokeMult = 0.5,
			})
		end
	end
end

local function moveRightTag(mv): string
	if mv.Power then
		if (mv.Priority or 0) > 0 then
			return tostring(mv.Power) .. " +" .. tostring(mv.Priority)
		end
		return tostring(mv.Power)
	end
	local kind = mv.Effect and mv.Effect.Kind
	if kind == "Protect" or kind == "WideProtect" then
		return "PROT"
	elseif kind == "Hazard" then
		return "HZD"
	elseif kind == "SideEffect" or kind == "ClearHazards" then
		return "CAMPO"
	elseif kind == "Heal" or kind == "Cleanse" then
		return "CURA"
	end
	return "SUP"
end

local function refreshMoveInfoCard(m)
	local mv = inspectedMoveId and Moves.Get(inspectedMoveId)
	if not mv and m and m.Active and m.Active[1] then
		inspectedMoveId = m.Active[1]
		inspectedUnlockLv = nil
		mv = Moves.Get(inspectedMoveId)
	end
	if not mv then
		moveInfoName.Text = "Selecione um golpe"
		moveInfoClassChip.Visible = false
		moveInfoCatChip.Visible = false
		moveInfoTargetChip.Visible = false
		moveInfoStats.Text = ""
		moveInfoDesc.Text = "Toque em qualquer golpe acima para ver poder, precis\u{e3}o, PP e efeito."
		return
	end

	local isSpecial = mv.Signature or mv.CutIn
	local stroke = moveInfoFace:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if isSpecial then T.Palette.gold else typeColor(mv.Type)
	end

	moveInfoName.Text = mv.Name
	moveInfoName.TextColor3 = if isSpecial then T.Palette.gold else T.Palette.onDark

	moveInfoClassChip.Visible = true
	moveInfoClassChip.Face.Label.Text = UI.upper(TypeChart.DisplayName[mv.Type] or mv.Type)
	UI.paint(moveInfoClassChip, typeColor(mv.Type))

	moveInfoCatChip.Visible = true
	local isDmg = mv.Category == "Damage"
	moveInfoCatChip.Face.Label.Text = if isDmg then "DANO" else "STATUS"
	UI.paint(moveInfoCatChip, if isDmg then "red" else "blue")

	moveInfoTargetChip.Visible = true
	if inspectedUnlockLv then
		moveInfoTargetChip.Face.Label.Text = "NV. " .. tostring(inspectedUnlockLv)
		UI.paint(moveInfoTargetChip, if isSpecial then "gold" else "slot")
	else
		moveInfoTargetChip.Face.Label.Text = UI.upper(Moves.TargetDisplay(mv))
		UI.paint(moveInfoTargetChip, "slot")
	end

	local powTxt = if mv.Power then tostring(mv.Power) else "-"
	local accTxt = if mv.Accuracy then (tostring(mv.Accuracy) .. "%") else "100% (Certeiro)"
	local ppMax = mv.PP or 0
	local ppCur = if (not inspectedUnlockLv) and m and m.Pp and typeof(m.Pp[mv.Id]) == "number" then m.Pp[mv.Id] else ppMax
	local ppTxt = if inspectedUnlockLv then tostring(ppMax) else string.format("%d/%d", ppCur, ppMax)
	local statItems = {
		string.format("<font color='#FFD84A'>PODER</font> %s", powTxt),
		string.format("<font color='#FFD84A'>PRECIS\u{c3}O</font> %s", accTxt),
		string.format("<font color='#FFD84A'>PP</font> %s", ppTxt),
	}
	if (mv.Priority or 0) > 0 then
		table.insert(statItems, string.format("<font color='#1AD1C5'>PRIO +%d</font>", mv.Priority))
	end
	if (mv.CritChance or 0) >= 0.12 then
		table.insert(statItems, string.format("<font color='#FF8C24'>CR\u{cd}T %d%%</font>", math.floor(mv.CritChance * 100 + 0.5)))
	end
	if inspectedUnlockLv then
		table.insert(statItems, string.format("<font color='#FFD84A'>BLOQUEADO (NV. %d)</font>", inspectedUnlockLv))
	end
	moveInfoStats.Text = table.concat(statItems, "   |   ")
	moveInfoDesc.Text = Moves.Describe(mv)
end

local function styleMoveButtonStroke(face, isSelected: boolean, isSpecial: boolean)
	local st0 = face:FindFirstChildOfClass("UIStroke")
	if not st0 then
		return
	end
	if isSelected then
		st0.Color = if isSpecial then T.Palette.gold else Color3.fromRGB(255, 255, 255)
	elseif isSpecial then
		st0.Color = T.Palette.gold
	end
end

refreshDetail = function()
	UI.clear(movesBox)
	local m = profile and selectedUid and profile.Collection[selectedUid]
	detail.Visible = m ~= nil
	if not m then
		return
	end
	local def = Characters.Get(m.CharacterId)
	local st = Progression.MemberStats(m)
	local upcoming = Characters.UpcomingMoves(m.CharacterId, m.Level)
	local totalLearnset = #m.Learned + #upcoming
	detailTitle.Text = def.Name .. "  Nv. " .. m.Level
	detailType.Face.Label.Text = UI.upper(TypeChart.DisplayName[def.Type] or def.Type)
	UI.paint(detailType, typeColor(def.Type))

	local isChange = viewMode == "Change"
	if isChange then
		detailInfo.Text = string.format(
			"Selecione at\u{e9} %d golpes ativos (%d/%d)  |  %d/%d aprendidos",
			Progression.MaxActiveMoves, #pick, Progression.MaxActiveMoves, #m.Learned, totalLearnset
		)
	else
		detailInfo.Text = string.format(
			"HP %d  ATQ %d  DEF %d  VEL %d  |  Golpes %d/%d (%d/%d)",
			st.HP, st.Attack, st.Defense, st.Speed, #m.Active, Progression.MaxActiveMoves, #m.Learned, totalLearnset
		)
	end

	candyRow.Visible = not isChange
	changeMovesBtn.Visible = not isChange
	cancelChangeBtn.Visible = isChange
	saveButton.Visible = isChange

	for i, c in ipairs(CANDIES) do
		local n = (profile.Bag and profile.Bag[c.Id]) or 0
		local b = candyButtons[c.Id]
		if not b then
			b = UI.button(candyRow, {
				Name = "Use_" .. c.Id, Color = c.Color, Size = UDim2.fromScale(0.315, 1), Position = UDim2.fromScale((i - 1) * 0.34, 0), Corner = 0.3, Sound = false,
				OnClick = function()
					useCandy(c.Id)
				end,
			})
			UI.icon(b.Face, c.Icon, { Name = "Icon", Size = UDim2.fromScale(0.5, 0.95), Position = UDim2.fromScale(0.02, 0.025) })
			UI.text(b.Face, "", { Name = "Count", Size = UDim2.fromScale(0.46, 0.6), Position = UDim2.fromScale(0.52, 0.2), Role = "Small", AlignX = Enum.TextXAlignment.Left })
			candyButtons[c.Id] = b
		end
		b.Face.Count.Text = "x" .. n
		UI.setDisabled(b, n <= 0 or m.Level >= Progression.MaxLevel, c.Color)
	end

	if not isChange then
		-- MODO EQUIPADOS (estilo Pokemon: os 4 ataques ativos, clique seleciona para ver detalhes abaixo)
		if not inspectedMoveId or (not table.find(m.Active, inspectedMoveId) and not inspectedUnlockLv) then
			inspectedMoveId = m.Active[1] or m.Learned[1]
			inspectedUnlockLv = nil
		end
		for idx, moveId in ipairs(m.Active) do
			local mv = Moves.Get(moveId)
			if mv then
				local isSelected = inspectedMoveId == moveId and inspectedUnlockLv == nil
				local isSpecial = mv.Signature or mv.CutIn
				local _, face = UI.button(movesBox, {
					Name = "Active_" .. moveId,
					Color = typeColor(mv.Type),
					LayoutOrder = idx,
					Corner = 0.22,
					OnClick = function()
						inspectedMoveId = moveId
						inspectedUnlockLv = nil
						detailMsg.Text = ""
						refreshDetail()
					end,
				})
				styleMoveButtonStroke(face, isSelected, isSpecial)
				UI.icon(face, if isSpecial then "star" else (UI.TypeIcon[mv.Type] or "sword"), {
					Name = "MoveIcon",
					Size = UDim2.fromScale(0.14, 0.72),
					Position = UDim2.fromScale(0.035, 0.5),
					AnchorPoint = Vector2.new(0, 0.5),
					AspectAxis = Enum.DominantAxis.Height,
				})
				UI.text(face, mv.Name, { Name = "MoveName", Size = UDim2.fromScale(0.54, 0.72), Position = UDim2.fromScale(0.19, 0.14), Role = "Small", Color = "onDark", AlignX = Enum.TextXAlignment.Left })
				UI.text(face, moveRightTag(mv), { Name = "Power", Size = UDim2.fromScale(0.23, 0.62), Position = UDim2.fromScale(0.95, 0.19), AnchorPoint = Vector2.new(1, 0), Role = "Small", Color = "gold", AlignX = Enum.TextXAlignment.Right })
			end
		end
	else
		-- MODO TROCAR GOLPES (lista completa: aprendidos clicaveis para marcar + bloqueados com cadeado)
		local order = 0
		for _, moveId in ipairs(m.Learned) do
			local mv = Moves.Get(moveId)
			if mv then
				order += 1
				local on = table.find(pick, moveId) ~= nil
				local isSelected = inspectedMoveId == moveId and inspectedUnlockLv == nil
				local isSpecial = mv.Signature or mv.CutIn
				local _, face = UI.button(movesBox, {
					Name = "Move_" .. moveId,
					Color = if on then typeColor(mv.Type) else "grey",
					LayoutOrder = order,
					Corner = 0.22,
					OnClick = function()
						inspectedMoveId = moveId
						inspectedUnlockLv = nil
						local idx = table.find(pick, moveId)
						if idx then
							if #pick > 1 then
								table.remove(pick, idx)
								detailMsg.Text = ""
							else
								detailMsg.Text = "Mantenha ao menos 1 golpe equipado."
								UI.play("error")
							end
						elseif #pick < Progression.MaxActiveMoves then
							table.insert(pick, moveId)
							detailMsg.Text = ""
						else
							detailMsg.Text = "M\u{e1}ximo de 4 golpes. Desmarque um antes."
							UI.play("error")
						end
						refreshDetail()
					end,
				})
				styleMoveButtonStroke(face, isSelected, isSpecial)
				UI.icon(face, if on then "tick" elseif isSpecial then "star" else (UI.TypeIcon[mv.Type] or "sword"), {
					Name = "MoveIcon",
					Size = UDim2.fromScale(0.14, 0.72),
					Position = UDim2.fromScale(0.035, 0.5),
					AnchorPoint = Vector2.new(0, 0.5),
					AspectAxis = Enum.DominantAxis.Height,
				})
				UI.text(face, mv.Name, { Name = "MoveName", Size = UDim2.fromScale(0.54, 0.72), Position = UDim2.fromScale(0.19, 0.14), Role = "Small", Color = if isSpecial and not on then "gold" else "onDark", AlignX = Enum.TextXAlignment.Left })
				UI.text(face, moveRightTag(mv), { Name = "Power", Size = UDim2.fromScale(0.23, 0.62), Position = UDim2.fromScale(0.95, 0.19), AnchorPoint = Vector2.new(1, 0), Role = "Small", Color = "gold", AlignX = Enum.TextXAlignment.Right })
			end
		end
		-- Proximos golpes da progressao por nivel (bloqueados, mas clicaveis para inspecionar no card!)
		for _, entry in ipairs(upcoming) do
			local mv = Moves.Get(entry.Move)
			if mv then
				order += 1
				local isSpecial = mv.Signature or mv.CutIn
				local unlockLv = entry.Level
				local isSelected = inspectedMoveId == entry.Move and inspectedUnlockLv == unlockLv
				local _, face = UI.button(movesBox, {
					Name = "Locked_" .. entry.Move,
					Color = "slot",
					LayoutOrder = order,
					Corner = 0.22,
					Sound = false,
					OnClick = function()
						inspectedMoveId = entry.Move
						inspectedUnlockLv = unlockLv
						if mv.Signature then
							detailMsg.Text = string.format("T\u{e9}cnica Assinatura: desbloqueia no N\u{ed}vel %d.", unlockLv)
						elseif mv.CutIn then
							detailMsg.Text = string.format("Ataque Especial: desbloqueia no N\u{ed}vel %d.", unlockLv)
						else
							detailMsg.Text = string.format("%s desbloqueia no N\u{ed}vel %d.", mv.Name, unlockLv)
						end
						UI.play("click")
						refreshDetail()
					end,
				})
				styleMoveButtonStroke(face, isSelected, isSpecial)
				UI.icon(face, "lock", {
					Name = "LockIcon",
					Size = UDim2.fromScale(0.14, 0.7),
					Position = UDim2.fromScale(0.035, 0.5),
					AnchorPoint = Vector2.new(0, 0.5),
					AspectAxis = Enum.DominantAxis.Height,
				})
				UI.text(face, mv.Name, {
					Name = "MoveName",
					Size = UDim2.fromScale(0.54, 0.72),
					Position = UDim2.fromScale(0.19, 0.14),
					Role = "Small",
					Color = if isSpecial then "gold" else "inkSoft",
					AlignX = Enum.TextXAlignment.Left,
					StrokeMult = 0.5,
				})
				UI.text(face, "Nv. " .. unlockLv, {
					Name = "UnlockLevel",
					Size = UDim2.fromScale(0.23, 0.62),
					Position = UDim2.fromScale(0.95, 0.19),
					AnchorPoint = Vector2.new(1, 0),
					Role = "Small",
					Color = if isSpecial then "gold" else "inkSoft",
					AlignX = Enum.TextXAlignment.Right,
				})
			end
		end
	end

	refreshMoveInfoCard(m)
end

useCandy = function(id)
	local m = profile and selectedUid and profile.Collection[selectedUid]
	if not m then
		return
	end
	if ((profile.Bag and profile.Bag[id]) or 0) <= 0 then
		detailMsg.Text = "Doces s\u{f3} caem no Ref\u{fa}gio."
		UI.play("error")
		return
	end
	local ok, text = Remotes.UseItem:InvokeServer(id, selectedUid)
	detailMsg.Text = text or ""
	if not ok then
		UI.play("error")
	end
end

changeMovesBtn.Activated:Connect(function()
	local m = profile and selectedUid and profile.Collection[selectedUid]
	if not m then
		return
	end
	pick = table.clone(m.Active)
	viewMode = "Change"
	detailMsg.Text = ""
	refreshDetail()
end)

cancelChangeBtn.Activated:Connect(function()
	local m = profile and selectedUid and profile.Collection[selectedUid]
	if m then
		pick = table.clone(m.Active)
		inspectedMoveId = m.Active[1] or m.Learned[1]
	end
	viewMode = "Equipped"
	inspectedUnlockLv = nil
	detailMsg.Text = ""
	refreshDetail()
end)

saveButton.Activated:Connect(function()
	if not selectedUid then
		return
	end
	local ok, err = Remotes.SetActiveMoves:InvokeServer(selectedUid, pick)
	if ok then
		viewMode = "Equipped"
		inspectedUnlockLv = nil
		if not table.find(pick, inspectedMoveId) then
			inspectedMoveId = pick[1]
		end
		detailMsg.Text = "Golpes salvos."
		refreshDetail()
	else
		detailMsg.Text = err or "N\u{e3}o foi poss\u{ed}vel salvar."
		UI.play("error")
	end
end)

teamWin.CloseButton.Activated:Connect(function()
	clearListPortraits()
end)

UI.onOpen("Team", function(uid)
	if not profile or not profile.StarterChosen then
		return
	end
	if teamWin.IsOpen() and uid == nil then
		clearListPortraits()
		teamWin.Close()
		return
	end
	-- aberto pelo cartao da barra do time ou pela tela Info do personagem
	if typeof(uid) == "string" and profile.Collection[uid] then
		selectedUid = uid
	end
	if not selectedUid or not profile.Collection[selectedUid] then
		selectedUid = profile.Team[1]
	end
	local m = selectedUid and profile.Collection[selectedUid]
	pick = m and table.clone(m.Active) or {}
	viewMode = "Equipped"
	inspectedMoveId = m and (m.Active[1] or m.Learned[1]) or nil
	inspectedUnlockLv = nil
	detailMsg.Text = ""
	refreshList()
	refreshDetail()
	teamWin.Open()
	task.defer(layoutTeamDetail)
end)

--------------------------------------------------------------------
-- Perfil
--------------------------------------------------------------------
local first = true
local function apply(p)
	if typeof(p) ~= "table" then
		return
	end
	profile = p
	local isFirst = first
	if first then
		goldLabel.Text = UI.fmt(p.Gold or 0)
		gemsLabel.Text = UI.fmt(p.Gems or 0)
		oreLabel.Text = UI.fmt(p.Ore or 0)
		goldLabel:SetAttribute("Value", p.Gold or 0)
		gemsLabel:SetAttribute("Value", p.Gems or 0)
		oreLabel:SetAttribute("Value", p.Ore or 0)
		first = false
	else
		local before = goldLabel:GetAttribute("Value") or 0
		UI.countTo(goldLabel, p.Gold or 0)
		UI.countTo(gemsLabel, p.Gems or 0)
		UI.countTo(oreLabel, p.Ore or 0)
		if (p.Gold or 0) - before >= 25 then
			UI.play("coin")
		end
	end
	local _ = isFirst
	refreshStarterTrack()
	layoutRightStack()
	if not p.StarterChosen then
		if not starterWin.IsOpen() then
			buildStarterCards()
			starterWin.Open()
		end
	elseif starterWin.IsOpen() then
		starterWin.Close()
	end
	if teamWin.IsOpen() then
		local m = selectedUid and p.Collection[selectedUid]
		if m and viewMode ~= "Change" then
			pick = table.clone(m.Active)
		end
		refreshList()
		refreshDetail()
	end
end

Remotes:WaitForChild("ProfileUpdated").OnClientEvent:Connect(apply)
-- Atualiza gold ao vivo a cada segundo enquanto a Base gera renda online
player:GetAttributeChangedSignal("LiveGold"):Connect(function()
	if first or not profile then
		return
	end
	local live = player:GetAttribute("LiveGold")
	if typeof(live) == "number" and live >= 0 then
		profile.Gold = live
		UI.countTo(goldLabel, live)
	end
end)
task.spawn(function()
	local ok, p = pcall(function()
		return Remotes:WaitForChild("GetProfile"):InvokeServer()
	end)
	if ok and p then
		apply(p)
	end
end)

-- Esconde o HUD durante a batalha
UI.onBattle(function(inBattle)
	hud.Visible = not inBattle
	if inBattle then
		clearListPortraits()
		UI.closeAllWindows()
	end
end)

UI.preloadSounds()

--------------------------------------------------------------------
-- Efeito do Doce de XP (so visual): brilho no personagem do jogador e no painel do time
--------------------------------------------------------------------
local CANDY_FX = {
	DoceComum = { Color = Color3.fromRGB(255, 255, 255), Color2 = Color3.fromRGB(220, 230, 255), Count = 24, Size = 0.6, Sound = "candy_comum", Light = 1.5 },
	DoceRaro = { Color = Color3.fromRGB(120, 200, 255), Color2 = Color3.fromRGB(40, 120, 255), Count = 45, Size = 0.8, Sound = "candy_raro", Light = 3 },
	DoceEpico = { Color = Color3.fromRGB(220, 140, 255), Color2 = Color3.fromRGB(255, 215, 80), Count = 90, Size = 1.1, Sound = "candy_epico", Light = 5, Ring = true },
}
Remotes:WaitForChild("CandyFx").OnClientEvent:Connect(function(id, uid, gained)
	local fx = CANDY_FX[id]
	if not fx then
		return
	end
	UI.play(fx.Sound)
	if gained and gained > 0 then
		task.delay(0.35, function()
			UI.play("reward")
		end)
	end
	-- painel: o card do personagem pulsa
	local card = list:FindFirstChild("Member_" .. tostring(uid))
	if card then
		local sc2 = Instance.new("UIScale")
		sc2.Parent = card
		sc2.Scale = 1.08
		game:GetService("TweenService"):Create(sc2, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		task.delay(0.5, function()
			sc2:Destroy()
		end)
	end
	-- mundo: explosao de brilhos em volta do jogador
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local a = Instance.new("Attachment")
	a.Parent = root
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxassetid://117703775594396"
	e.Color = ColorSequence.new(fx.Color, fx.Color2)
	e.LightEmission = 1
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.8, 1.5)
	e.Speed = NumberRange.new(6, 14)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 3
	e.Acceleration = Vector3.new(0, 4, 0)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, fx.Size), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(0, 1)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-180, 180)
	e.Parent = a
	e:Emit(fx.Count)
	local l = Instance.new("PointLight")
	l.Color = fx.Color2
	l.Range = 14
	l.Brightness = fx.Light
	l.Shadows = false
	l.Parent = root
	task.spawn(function()
		for i = 1, 15 do
			l.Brightness = fx.Light * (1 - i / 15)
			task.wait(0.05)
		end
		l:Destroy()
	end)
	if fx.Ring then
		-- Epico: anel de luz subindo pelo corpo
		local ring = Instance.new("ParticleEmitter")
		ring.Texture = "rbxassetid://106813072869220"
		ring.Color = ColorSequence.new(fx.Color)
		ring.LightEmission = 1
		ring.Rate = 0
		ring.Lifetime = NumberRange.new(0.7)
		ring.Speed = NumberRange.new(5)
		ring.EmissionDirection = Enum.NormalId.Top
		ring.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		ring.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) })
		ring.Transparency = NumberSequence.new(0.1, 1)
		ring.Parent = a
		ring:Emit(1)
		task.delay(0.25, function()
			ring:Emit(1)
		end)
		task.delay(0.5, function()
			ring:Emit(1)
		end)
	end
	task.delay(2, function()
		a:Destroy()
	end)
end)
