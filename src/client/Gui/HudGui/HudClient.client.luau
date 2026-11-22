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
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local gui = script.Parent
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Data = ReplicatedStorage:WaitForChild("Data")
local Characters = require(Data:WaitForChild("Characters"))
local Moves = require(Data:WaitForChild("Moves"))
local TypeChart = require(Data:WaitForChild("TypeChart"))
local Progression = require(Data:WaitForChild("Progression"))
local AccountLevel = require(Data:WaitForChild("AccountLevel"))
local StarterTrack = require(Data:WaitForChild("StarterTrack"))
local UI = require(ReplicatedStorage:WaitForChild("UI"))
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
local top = UI.frame(hud, { Name = "Top", Size = UDim2.fromScale(0.50, 0.11), Position = UDim2.fromScale(0.02, 0.03), MaxSize = Vector2.new(600, 56) })
local topLayout = Instance.new("UIListLayout")
topLayout.FillDirection = Enum.FillDirection.Horizontal
topLayout.Padding = UDim.new(0.045, 0)
topLayout.VerticalAlignment = Enum.VerticalAlignment.Center
topLayout.SortOrder = Enum.SortOrder.LayoutOrder
topLayout.Parent = top
local _, goldLabel = UI.pill(top, "coin", "gold", { Name = "Gold", Size = UDim2.fromScale(0.33, 1), Aspect = 3.2, LayoutOrder = 1 })
local _, gemsLabel = UI.pill(top, "gem", "gems", { Name = "Gems", Size = UDim2.fromScale(0.27, 1), Aspect = 2.5, LayoutOrder = 2 })
local _, oreLabel = UI.pill(top, "ore", "ore", { Name = "Ore", Size = UDim2.fromScale(0.29, 1), Aspect = 2.8, LayoutOrder = 3 })
-- um pequeno respiro a esquerda para o icone que sai da pilula
local topPad = Instance.new("UIPadding")
topPad.PaddingLeft = UDim.new(0.02, 0)
topPad.Parent = top

-- Taxa de gold ao vivo da Base (+X/s logo abaixo da pilula de gold)
local liveRateLabel = UI.text(hud, "", {
	Name = "LiveGoldRate",
	Size = UDim2.fromScale(0.20, 0.042),
	Position = UDim2.fromScale(0.032, 0.145),
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

-- Cartao do Nivel da Conta (canto superior direito, logo abaixo da engrenagem; abre Recompensas de Nivel)
local accBtn, accFace = UI.button(hud, {
	Name = "AccountLevelCard",
	Color = "panel",
	Size = UDim2.fromScale(0.25, 0.145),
	Position = UDim2.fromScale(0.985, 0.20),
	AnchorPoint = Vector2.new(1, 0),
	Corner = 0.22,
	MaxSize = Vector2.new(255, 58),
	Visible = false,
	Sound = "click",
	OnClick = function()
		if not profile or not profile.StarterChosen then
			return
		end
		UI.open("LevelRewards")
	end,
})
local accStroke = UI.stroke(accFace, T.Palette.gold, 1.1)
local accLvPill, accLvFace = UI.panel(accFace, {
	Name = "LvPill",
	Size = UDim2.fromScale(0.30, 0.74),
	Position = UDim2.fromScale(0.04, 0.13),
	Color = "lendario",
	Corner = 0.26,
	Shadow = false,
})
local _accLvPill = accLvPill
local accLvText = UI.text(accLvFace, "NV. 1", {
	Name = "Text",
	Size = UDim2.fromScale(0.92, 0.80),
	Position = UDim2.fromScale(0.04, 0.10),
	Role = "Small",
})
local accTitle = UI.text(accFace, "CONTA", {
	Name = "Title",
	Size = UDim2.fromScale(0.60, 0.34),
	Position = UDim2.fromScale(0.37, 0.09),
	Role = "Small",
	Color = "gold",
	AlignX = Enum.TextXAlignment.Left,
	StrokeMult = 0.45,
})
local accBar = UI.bar(accFace, {
	Name = "XpBar",
	Size = UDim2.fromScale(0.60, 0.36),
	Position = UDim2.fromScale(0.37, 0.50),
	FillColor = "blue",
})
local accBarText = UI.text(accBar, "0 / 129", {
	Name = "XpLabel",
	Size = UDim2.fromScale(0.94, 0.90),
	Position = UDim2.fromScale(0.03, 0.05),
	Role = "Small",
	StrokeMult = 0.6,
	ZIndex = 4,
})
local accBadge = UI.frame(accBtn, {
	Name = "Badge",
	Size = UDim2.fromOffset(20, 20),
	Position = UDim2.fromScale(0.0, 0.0),
	AnchorPoint = Vector2.new(0.35, 0.2),
	Color = "red",
	Corner = 0.5,
	ZIndex = 6,
	Visible = false,
})
UI.stroke(accBadge)
local accBadgeText = UI.text(accBadge, "!", {
	Name = "Count",
	Size = UDim2.fromScale(1, 1),
	Role = "Small",
	ZIndex = 7,
})
local accXpFlashId = 0

local function refreshAccountCard(instant: boolean?)
	if not profile or not profile.StarterChosen then
		accBtn.Visible = false
		return
	end
	local acc = profile.Account or { Level = 1, Xp = 0, TotalXp = 0, Claimed = {} }
	local lv = math.max(1, math.floor(tonumber(acc.Level) or 1))
	local xp = math.max(0, math.floor(tonumber(acc.Xp) or 0))
	local need = AccountLevel.XpToNext(lv)
	local frac = math.clamp(if need > 0 then xp / need else 0, 0, 1)
	local unclaimed = AccountLevel.CountUnclaimed(acc)

	accBtn.Visible = true
	accLvText.Text = "NV. " .. lv
	UI.setBar(accBar, frac, "blue", instant == true)
	accBarText.Text = UI.fmt(xp) .. "/" .. UI.fmt(need)
	if unclaimed > 0 then
		accBadge.Visible = true
		accBadgeText.Text = if unclaimed > 9 then "9+" else tostring(unclaimed)
		accStroke.Color = T.Palette.gold
	else
		accBadge.Visible = false
		accStroke.Color = T.Palette.blue
	end
end

-- Card compacto da Trilha de Objetivos Iniciais (canto superior direito, abaixo do Nivel da Conta)
local trackBtn, trackFace = UI.button(hud, {
	Name = "StarterTrack",
	Color = "panel",
	Size = UDim2.fromScale(0.25, 0.21),
	Position = UDim2.fromScale(0.985, 0.365),
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
-- Configuracoes: engrenagem no canto de cima a direita
local settingsButton = UI.button(hud, { Name = "SettingsButton", Icon = "gear", Color = "grey", Layout = "icon", Size = UDim2.fromScale(0.12, 0.15), Position = UDim2.fromScale(0.985, 0.03), AnchorPoint = Vector2.new(1, 0), Aspect = 1, AspectAxis = Enum.DominantAxis.Height, MaxSize = Vector2.new(62, 62), Corner = 0.3,
	OnClick = function()
		UI.open("Settings")
	end,
})

-- Posiciona a pilha direita (AccountLevelCard + StarterTrack) exatamente abaixo da engrenagem sem colisoes
local function layoutRightStack()
	local h = hud.AbsoluteSize.Y
	if h < 40 then
		return
	end
	local topY = math.floor(h * 0.03)
	local gearH = math.max(T.TouchMin, math.floor(settingsButton.AbsoluteSize.Y))
	local accY = topY + gearH + 8
	accBtn.Position = UDim2.new(0.985, 0, 0, accY)
	local accH = math.max(T.TouchMin, math.floor(accBtn.AbsoluteSize.Y))
	trackBtn.Position = UDim2.new(0.985, 0, 0, accY + accH + 8)
end
hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutRightStack)
settingsButton:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutRightStack)
accBtn:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutRightStack)
task.defer(layoutRightStack)

-- ponto vermelho dos Premios (RewardsClient marca o atributo RewardsBadge no PlayerGui)
local badge = UI.frame(menuButtons.Rewards, { Name = "Badge", Size = UDim2.fromScale(0.36, 0.36), Position = UDim2.fromScale(0.95, -0.08), AnchorPoint = Vector2.new(0.5, 0), Color = "red", Aspect = 1, ZIndex = 4, Visible = false })
UI.stroke(badge)
UI.text(badge, "!", { Size = UDim2.fromScale(1, 1), Role = "Small", ZIndex = 5 })

--------------------------------------------------------------------
-- Evento de fim de semana (RewardsClient marca WeekendEvent) e avisos
--------------------------------------------------------------------
local eventHolder, eventFace = UI.panel(hud, { Name = "Event", Size = UDim2.fromScale(0.32, 0.1), Position = UDim2.fromScale(0.895, 0.03), AnchorPoint = Vector2.new(1, 0), Color = "lendario", Corner = T.Corner.Pill, Aspect = 4.6, Visible = false, MaxSize = Vector2.new(280, 56) })
UI.icon(eventHolder, "star", { Size = UDim2.fromScale(0.25, 1.25), Position = UDim2.fromScale(-0.04, 0.5), AnchorPoint = Vector2.new(0, 0.5), AspectAxis = Enum.DominantAxis.Height, ZIndex = 3 })
local eventLabel = UI.text(eventFace, "", { Name = "Text", Size = UDim2.fromScale(0.78, 0.74), Position = UDim2.fromScale(0.2, 0.13), Role = "Small" })

local toastHolder, toastFace = UI.panel(canvas, { Name = "Toast", Size = UDim2.fromScale(0.5, 0.1), Position = UDim2.fromScale(0.5, 0.17), AnchorPoint = Vector2.new(0.5, 0), Color = "panel", Corner = T.Corner.Pill, Visible = false, ZIndex = 30, MaxSize = Vector2.new(560, 60) })
local toastScale = Instance.new("UIScale")
toastScale.Parent = toastHolder
local toastLabel = UI.text(toastFace, "", { Name = "Text", Size = UDim2.fromScale(0.92, 0.72), Position = UDim2.fromScale(0.04, 0.14), Role = "Small", ZIndex = 31 })
local toastId = 0
local function showToast(text, kind)
	toastId += 1
	local id = toastId
	toastLabel.Text = tostring(text)
	-- na batalha fica abaixo do registro de mensagens
	toastHolder.Position = UDim2.fromScale(0.5, if UI.inBattle() then 0.2 else 0.17)
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

local pg = player:WaitForChild("PlayerGui")
local function syncAttrs()
	badge.Visible = pg:GetAttribute("RewardsBadge") == true
	local ev = pg:GetAttribute("WeekendEvent")
	eventHolder.Visible = typeof(ev) == "string" and ev ~= ""
	eventLabel.Text = ev or ""
end
pg:GetAttributeChangedSignal("RewardsBadge"):Connect(syncAttrs)
pg:GetAttributeChangedSignal("WeekendEvent"):Connect(syncAttrs)
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
-- Menu Time (nivel, XP e golpes ativos)
--------------------------------------------------------------------
local teamWin = UI.window(canvas, { Name = "TeamWindow", Title = "GOLPES", Icon = "book", HeaderColor = "blue", Size = UDim2.fromScale(0.92, 0.84), Aspect = 1.9 })
local list = UI.scroll(teamWin.Body, { Name = "Members", Size = UDim2.fromScale(0.42, 1), Position = UDim2.fromScale(0, 0) })
local detail, detailFace = UI.panel(teamWin.Body, { Name = "Detail", Size = UDim2.fromScale(0.56, 1), Position = UDim2.fromScale(0.44, 0), Color = "slot", Corner = 0.06, Shadow = false })
local detailTitle = UI.text(detailFace, "", { Name = "Title", Size = UDim2.fromScale(0.7, 0.12), Position = UDim2.fromScale(0.04, 0.03), Role = "Heading", AlignX = Enum.TextXAlignment.Left })
local detailType = UI.chip(detailFace, "", "grey", { Name = "Type", Size = UDim2.fromScale(0.22, 0.09), Position = UDim2.fromScale(0.96, 0.045), AnchorPoint = Vector2.new(1, 0) })
local detailInfo = UI.text(detailFace, "", { Name = "Info", Size = UDim2.fromScale(0.92, 0.09), Position = UDim2.fromScale(0.04, 0.16), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.4 })
local movesBox = UI.scroll(detailFace, { Name = "Moves", Size = UDim2.fromScale(0.94, 0.44), Position = UDim2.fromScale(0.03, 0.26), Columns = 2, CellAspect = 2.3, Gap = 0.03 })
-- Doces de XP (so caem no Refugio): um botao por doce, usa no personagem escolhido
local CANDIES = { { Id = "DoceComum", Icon = "doce_comum", Color = "panelAlt" }, { Id = "DoceRaro", Icon = "doce_raro", Color = "blue" }, { Id = "DoceEpico", Icon = "doce_epico", Color = "purple" } }
local detailBottomBar = UI.frame(detailFace, { Name = "BottomBar", Size = UDim2.fromScale(0.94, 0.16), Position = UDim2.fromScale(0.03, 0.97), AnchorPoint = Vector2.new(0, 1) })
UI.clampHeight(detailBottomBar, T.TouchMin, 50)
local candyRow = UI.frame(detailBottomBar, { Name = "Candies", Size = UDim2.fromScale(0.60, 1), Position = UDim2.fromScale(0, 0) })
local candyButtons = {}
local useCandy
local detailMsg = UI.text(detailFace, "", { Name = "Message", Size = UDim2.fromScale(0.92, 0.08), Position = UDim2.fromScale(0.04, 0.72), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.4 })
local saveButton = UI.button(detailBottomBar, { Name = "SaveMoves", Text = "SALVAR", Icon = "tick", Color = "green", Layout = "row", Size = UDim2.fromScale(0.37, 1), Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(1, 0), Role = "Body" })

local function layoutTeamDetail()
	local h = detailFace.AbsoluteSize.Y
	if h < 40 then
		return
	end
	local bottomH = math.max(T.TouchMin, math.floor(detailBottomBar.AbsoluteSize.Y))
	local msgH = math.max(16, math.floor(h * 0.075))
	local msgY = h - math.floor(h * 0.03) - bottomH - msgH - 4
	detailMsg.Position = UDim2.new(0.04, 0, 0, msgY)
	detailMsg.Size = UDim2.new(0.92, 0, 0, msgH)
	local movesTop = math.floor(h * 0.255)
	local movesH = math.max(44, msgY - movesTop - 4)
	movesBox.Position = UDim2.new(0.03, 0, 0, movesTop)
	movesBox.Size = UDim2.new(0.94, 0, 0, movesH)
end
detailFace:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutTeamDetail)
detailBottomBar:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutTeamDetail)
task.defer(layoutTeamDetail)

local selectedUid = nil
local pick = {} -- golpes marcados no menu
local refreshDetail
local STATUS_NAME = { Burn = "Queimado", Poison = "Envenenado", Paralysis = "Paralisado", Sleep = "Dormindo", Freeze = "Congelado" }

local function refreshList()
	UI.clear(list)
	if not profile then
		return
	end
	for i, uid in ipairs(profile.Team) do
		local m = profile.Collection[uid]
		if m then
			local def = Characters.Get(m.CharacterId)
			local hp, max = Progression.CurrentHp(m)
			local need = Progression.XpToNext(m.Level)
			local b, face = UI.button(list, {
				Name = "Member_" .. uid, Color = if uid == selectedUid then "blue" else "panelAlt", Size = UDim2.fromScale(0.98, 0), Aspect = 3.6, LayoutOrder = i, Corner = 0.2,
				OnClick = function()
					selectedUid = uid
					pick = table.clone(m.Active)
					detailMsg.Text = ""
					refreshList()
					refreshDetail()
				end,
			})
			UI.text(face, def and def.Name or m.CharacterId, { Name = "MemberName", Size = UDim2.fromScale(0.55, 0.32), Position = UDim2.fromScale(0.05, 0.08), Role = "Body", AlignX = Enum.TextXAlignment.Left })
			UI.text(face, "Nv. " .. m.Level, { Name = "Level", Size = UDim2.fromScale(0.3, 0.28), Position = UDim2.fromScale(0.95, 0.1), AnchorPoint = Vector2.new(1, 0), Role = "Small", Color = "gold", AlignX = Enum.TextXAlignment.Right })
			local bar = UI.bar(face, { Name = "Hp", Size = UDim2.fromScale(0.9, 0.16), Position = UDim2.fromScale(0.05, 0.47) })
			local ratio = if max > 0 then hp / max else 0
			UI.setBar(bar, ratio, if ratio > 0.5 then "hpHigh" elseif ratio > 0.2 then "hpMid" else "hpLow", true)
			local xp = if need > 0 then string.format("XP %d/%d", m.Xp, need) else "N\u{ed}vel m\u{e1}ximo"
			local hpText = if hp <= 0 then "Desmaiado" else string.format("HP %d/%d", hp, max)
			UI.text(face, hpText .. "   " .. xp .. (if m.Status then "  " .. (STATUS_NAME[m.Status] or m.Status) else ""), { Name = "Info", Size = UDim2.fromScale(0.9, 0.24), Position = UDim2.fromScale(0.05, 0.69), Role = "Small", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.5 })
		end
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
	detailTitle.Text = def.Name .. "  Nv. " .. m.Level
	detailType.Face.Label.Text = UI.upper(TypeChart.DisplayName[def.Type] or def.Type)
	UI.paint(detailType, typeColor(def.Type))
	detailInfo.Text = string.format("HP %d  ATQ %d  DEF %d  VEL %d  \u{b7}  Golpes %d/%d", st.HP, st.Attack, st.Defense, st.Speed, #pick, Progression.MaxActiveMoves)
	for i, c in ipairs(CANDIES) do
		local n = (profile.Bag and profile.Bag[c.Id]) or 0
		local b = candyButtons[c.Id]
		if not b then
			b = UI.button(candyRow, { Name = "Use_" .. c.Id, Color = c.Color, Size = UDim2.fromScale(0.32, 1), Position = UDim2.fromScale((i - 1) * 0.34, 0), Corner = 0.3, Sound = false,
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
	for i, moveId in ipairs(m.Learned) do
		local mv = Moves.Get(moveId)
		if mv then
			local on = table.find(pick, moveId) ~= nil
			local b, face = UI.button(movesBox, {
				Name = "Move_" .. moveId, Color = if on then typeColor(mv.Type) else "grey", LayoutOrder = i, Corner = 0.22,
				OnClick = function()
					local idx = table.find(pick, moveId)
					if idx then
						if #pick > 1 then
							table.remove(pick, idx)
						end
					elseif #pick < Progression.MaxActiveMoves then
						table.insert(pick, moveId)
					else
						detailMsg.Text = "M\u{e1}ximo de 4 golpes. Desmarque um antes."
						UI.play("error")
						return
					end
					detailMsg.Text = ""
					refreshDetail()
				end,
			})
			UI.text(face, (if on then "\u{2713} " else "") .. mv.Name, { Name = "MoveName", Size = UDim2.fromScale(0.68, 0.7), Position = UDim2.fromScale(0.05, 0.15), Role = "Small", AlignX = Enum.TextXAlignment.Left })
			UI.text(face, if mv.Power then tostring(mv.Power) else "\u{2014}", { Name = "Power", Size = UDim2.fromScale(0.22, 0.6), Position = UDim2.fromScale(0.95, 0.2), AnchorPoint = Vector2.new(1, 0), Role = "Small", Color = "gold", AlignX = Enum.TextXAlignment.Right })
		end
	end
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

saveButton.Activated:Connect(function()
	if not selectedUid then
		return
	end
	local ok, err = Remotes.SetActiveMoves:InvokeServer(selectedUid, pick)
	detailMsg.Text = if ok then "Golpes salvos." else (err or "N\u{e3}o foi poss\u{ed}vel salvar.")
	if not ok then
		UI.play("error")
	end
end)

UI.onOpen("Team", function(uid)
	if not profile or not profile.StarterChosen then
		return
	end
	if teamWin.IsOpen() and uid == nil then
		teamWin.Close()
		return
	end
	-- aberto pelo cartao da barra do time: ja no personagem tocado
	if typeof(uid) == "string" and profile.Collection[uid] then
		selectedUid = uid
	end
	if not selectedUid or not profile.Collection[selectedUid] then
		selectedUid = profile.Team[1]
	end
	local m = selectedUid and profile.Collection[selectedUid]
	pick = m and table.clone(m.Active) or {}
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
	refreshAccountCard(isFirst)
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
		if m then
			pick = table.clone(m.Active)
		end
		refreshList()
		refreshDetail()
	end
end

Remotes:WaitForChild("ProfileUpdated").OnClientEvent:Connect(apply)
Remotes:WaitForChild("AccountXpGain").OnClientEvent:Connect(function(info)
	if typeof(info) ~= "table" then
		return
	end
	if profile then
		profile.Account = profile.Account or { Level = 1, Xp = 0, TotalXp = 0, Claimed = {} }
		if typeof(info.Level) == "number" then
			profile.Account.Level = info.Level
		end
		if typeof(info.Xp) == "number" then
			profile.Account.Xp = info.Xp
		end
	end
	refreshAccountCard(false)
	local amt = tonumber(info.Amount) or 0
	if amt > 0 then
		accXpFlashId += 1
		local fid = accXpFlashId
		accTitle.Text = if info.LeveledUp then ("SUBIU NV. " .. tostring(info.Level) .. "!") else ("+" .. UI.fmt(amt) .. " XP")
		accTitle.TextColor3 = if info.LeveledUp then T.Palette.hpHigh else T.Palette.gold
		if info.LeveledUp then
			UI.play("reward")
		end
		task.delay(2.4, function()
			if accXpFlashId == fid then
				accTitle.Text = "CONTA"
				accTitle.TextColor3 = T.Palette.gold
			end
		end)
	end
end)
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
