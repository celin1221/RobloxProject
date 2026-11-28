--[[
	RaidClient (Camada 4 - Client): Interface e apresentacao 3D da Raid Global Cooperativa 4x1.
	- Tema Midnight-Blue Anime (UI.luau / UITheme.luau / 100% UI.Icons, ZERO emojis).
	- Contem:
	    1. Banner compacto no topo do HUD com status/timer global e acesso rapido a Fenda de Raid.
	    2. Janela da Raid & Lobby (preview 3D do Boss, recompensas sem Gemas/Despertar, aviso de Selo,
	       lista de 4 slots Jogadores/NPCs, seletor de 1 personagem da colecao, contagem de 30s e "Iniciar Agora").
	    3. HUD de Combate 4x1 (barra colossal do Boss + segmentos de Escudo de Fase, timer de 20s,
	       4 cards de aliados com Vidas 2/2 e contagem de revive 2t, barra dos 4 golpes sem Mochila/Torcida,
	       camera ampla da arena e animacoes/VFX reais via VfxController).
	    4. Tela de Resultado + Ranking de Dano/MVP + Captura Pos-Raid com Selos reais da mochila.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local gui = script.Parent

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RaidStateRE = Remotes:WaitForChild("RaidState") :: RemoteEvent
local RaidActionRF = Remotes:WaitForChild("RaidAction") :: RemoteFunction
local ProfileUpdatedRE = Remotes:WaitForChild("ProfileUpdated") :: RemoteEvent
local GetProfileRF = Remotes:WaitForChild("GetProfile") :: RemoteFunction

local Data = ReplicatedStorage:WaitForChild("Data")
local Raids = require(Data:WaitForChild("Raids"))
local Characters = require(Data:WaitForChild("Characters"))
local TypeChart = require(Data:WaitForChild("TypeChart"))
local UI = require(ReplicatedStorage:WaitForChild("UI"))
local TeamCards = require(ReplicatedStorage:WaitForChild("TeamCards"))
local VfxController = require(ReplicatedStorage:WaitForChild("VfxController"))
local T = UI.Theme

local profile = nil
local globalStatus = nil
local lastStatusAt = os.clock()

local activeRaid = nil -- { RaidId, Camera, BossModel, AllyModels, MySlot, State, TurnEndsAt, MoveSent, Stars, BossId }
local inBattleLock = false
local pickerOpen = false

local canvas = UI.screen(gui)
gui.DisplayOrder = 11

local function fmtMmSs(secs: number): string
	secs = math.max(0, math.floor(secs))
	return string.format("%02d:%02d", secs // 60, secs % 60)
end

local function fmtPct(rate: number): string
	local pct = (rate or 0) * 100
	if math.abs(pct - math.floor(pct + 0.5)) < 0.05 then
		return string.format("%d%%", math.floor(pct + 0.5))
	end
	return string.format("%.1f%%", pct)
end

local function typeColor(t: string?)
	return (t and (T.Types[t] or TypeChart.Color[t])) or T.Palette.grey
end

local function tierColor(stars: number): Color3
	local t = Raids.Tiers[stars]
	if not t then
		return T.Palette.blue
	end
	return if stars == 6 then t.AccentColor else t.Color
end

local function setBattleCamera(cf: CFrame?)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	if cf then
		cam.CameraType = Enum.CameraType.Scriptable
		cam.FieldOfView = 54
		cam.CFrame = cf
	else
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = 70
	end
end

local function setInRaidBattle(flag: boolean)
	inBattleLock = flag
	pg:SetAttribute("InBattle", flag)
end

--------------------------------------------------------------------
-- 1. BANNER COMPACTO NO TOPO DO HUD (fora de batalha)
--------------------------------------------------------------------
local hudBannerBtn, hudBannerFace = UI.button(canvas, {
	Name = "RaidHudBanner",
	Color = "panel",
	Size = UDim2.fromScale(0.24, 0.074),
	Position = UDim2.fromScale(0.605, 0.028),
	AnchorPoint = Vector2.new(0.5, 0),
	Corner = T.Corner.Pill,
	MaxSize = Vector2.new(280, 46),
	Visible = false,
	ZIndex = 6,
})
local hudBannerStroke = UI.stroke(hudBannerFace, T.Palette.gold, 1.35)
local hudBannerIcon = UI.icon(hudBannerFace, "sword", {
	Name = "Icon",
	Size = UDim2.fromScale(0.14, 0.60),
	Position = UDim2.fromScale(0.04, 0.5),
	AnchorPoint = Vector2.new(0, 0.5),
	AspectAxis = Enum.DominantAxis.Height,
	ZIndex = 7,
})
local hudBannerTitle = UI.text(hudBannerFace, "RAID GLOBAL", {
	Name = "Title",
	Size = UDim2.fromScale(0.49, 0.48),
	Position = UDim2.fromScale(0.23, 0.08),
	Role = "Small",
	Color = "gold",
	AlignX = Enum.TextXAlignment.Left,
	StrokeMult = 0.45,
	ZIndex = 7,
})
local hudBannerSub = UI.text(hudBannerFace, "", {
	Name = "Sub",
	Size = UDim2.fromScale(0.49, 0.38),
	Position = UDim2.fromScale(0.23, 0.56),
	Role = "Small",
	Color = "onDark",
	AlignX = Enum.TextXAlignment.Left,
	StrokeMult = 0.4,
	ZIndex = 7,
})
local hudBannerTimer = UI.text(hudBannerFace, "00:00", {
	Name = "Timer",
	Size = UDim2.fromScale(0.22, 0.68),
	Position = UDim2.fromScale(0.96, 0.5),
	AnchorPoint = Vector2.new(1, 0.5),
	Role = "Small",
	Color = "gold",
	AlignX = Enum.TextXAlignment.Right,
	StrokeMult = 0.45,
	ZIndex = 7,
})

--------------------------------------------------------------------
-- 2. JANELA DA RAID & LOBBY
--------------------------------------------------------------------
local lobbyWin = UI.window(canvas, {
	Name = "RaidLobbyWindow",
	Title = "RAID GLOBAL 4x1",
	Icon = "sword",
	HeaderColor = "purple",
	Size = UDim2.fromScale(0.92, 0.86),
	Aspect = 1.78,
})
local lBody = lobbyWin.Body

-- Coluna Esquerda: Preview 3D do Boss + Recompensas + Regras de Selo
local leftCol, leftFace = UI.panel(lBody, {
	Name = "BossCol",
	Size = UDim2.fromScale(0.41, 0.96),
	Position = UDim2.fromScale(0.01, 0.02),
	Color = "panelAlt",
	Corner = T.Corner.Card,
})
local bossTierChip = UI.chip(leftFace, "3 ESTRELAS", "blue", {
	Name = "TierChip",
	Size = UDim2.fromScale(0.62, 0.085),
	Position = UDim2.fromScale(0.05, 0.03),
})
local bossClassIcon = UI.icon(leftFace, "classe_lutador", {
	Name = "ClassIcon",
	Size = UDim2.fromScale(0.16, 0.09),
	Position = UDim2.fromScale(0.95, 0.03),
	AnchorPoint = Vector2.new(1, 0),
	AspectAxis = Enum.DominantAxis.Height,
})
local bossPortraitHolder = UI.frame(leftFace, {
	Name = "BossPortrait",
	Size = UDim2.fromScale(0.62, 0.34),
	Position = UDim2.fromScale(0.5, 0.13),
	AnchorPoint = Vector2.new(0.5, 0),
	Aspect = 1,
	AspectAxis = Enum.DominantAxis.Height,
	Color = "slot",
	Corner = T.Corner.Card,
})
local bossPortrait = TeamCards.new(bossPortraitHolder, { Size = UDim2.fromScale(1, 1) })
local bossNameLbl = UI.text(leftFace, "BOSS", {
	Name = "BossName",
	Size = UDim2.fromScale(0.92, 0.075),
	Position = UDim2.fromScale(0.04, 0.48),
	Role = "Heading",
	Color = "onDark",
})
local bossLvLbl = UI.text(leftFace, "Nv. 25 | Recomendado: Nv. 20+", {
	Name = "BossLv",
	Size = UDim2.fromScale(0.92, 0.055),
	Position = UDim2.fromScale(0.04, 0.555),
	Role = "Small",
	Color = "gold",
})
local rewardBox, rewardFace = UI.panel(leftFace, {
	Name = "RewardsBox",
	Size = UDim2.fromScale(0.92, 0.18),
	Position = UDim2.fromScale(0.04, 0.625),
	Color = "slot",
	Corner = T.Corner.Card,
})
local rewardTitleLbl = UI.text(rewardFace, "RECOMPENSAS (+25% GOLD/XP PARA MVP)", {
	Name = "Title",
	Size = UDim2.fromScale(0.94, 0.30),
	Position = UDim2.fromScale(0.03, 0.06),
	Role = "Small",
	Color = "gold",
	AlignX = Enum.TextXAlignment.Left,
})
local rewardBodyLbl = UI.text(rewardFace, "", {
	Name = "Body",
	Size = UDim2.fromScale(0.94, 0.60),
	Position = UDim2.fromScale(0.03, 0.36),
	Role = "Small",
	Color = "onDark",
	AlignX = Enum.TextXAlignment.Left,
})

local sealBox, sealFace = UI.panel(leftFace, {
	Name = "SealBox",
	Size = UDim2.fromScale(0.92, 0.155),
	Position = UDim2.fromScale(0.04, 0.82),
	Color = "slot",
	Corner = T.Corner.Card,
})
local sealBoxStroke = UI.stroke(sealFace, T.Palette.blue, 1.1)
local sealWarnLbl = UI.text(sealFace, "", {
	Name = "Warn",
	Size = UDim2.fromScale(0.94, 0.88),
	Position = UDim2.fromScale(0.03, 0.06),
	Role = "Small",
	Color = "onDark",
	AlignX = Enum.TextXAlignment.Left,
})

-- Coluna Direita: Status, Grupo 4 Slots, Seletor de Lutador e Acoes
local rightCol, rightFace = UI.panel(lBody, {
	Name = "PartyCol",
	Size = UDim2.fromScale(0.56, 0.96),
	Position = UDim2.fromScale(0.43, 0.02),
	Color = "panelAlt",
	Corner = T.Corner.Card,
})
local lobbyStatusLbl = UI.text(rightFace, "FENDA ABERTA", {
	Name = "Status",
	Size = UDim2.fromScale(0.94, 0.08),
	Position = UDim2.fromScale(0.03, 0.025),
	Role = "Heading",
	Color = "gold",
	AlignX = Enum.TextXAlignment.Left,
})
local lobbyRuleLbl = UI.text(rightFace, "1 personagem por jogador | 2 vidas (volta em 2 turnos) | 10 turnos | Timer 20s", {
	Name = "Rules",
	Size = UDim2.fromScale(0.94, 0.06),
	Position = UDim2.fromScale(0.03, 0.10),
	Role = "Small",
	Color = "inkSoft",
	AlignX = Enum.TextXAlignment.Left,
})

-- 4 Cards do Grupo (Jogadores + Aliados NPCs)
local slotsHolder = UI.frame(rightFace, {
	Name = "Slots",
	Size = UDim2.fromScale(0.94, 0.44),
	Position = UDim2.fromScale(0.03, 0.17),
})
local lobbySlotCards = {}
for i = 1, 4 do
	local row = (i - 1) // 2
	local col = (i - 1) % 2
	local card, face = UI.panel(slotsHolder, {
		Name = "Slot" .. i,
		Size = UDim2.fromScale(0.485, 0.46),
		Position = UDim2.fromScale(col * 0.515, row * 0.52),
		Color = "slot",
		Corner = T.Corner.Card,
	})
	local title = UI.text(face, "SLOT " .. i, {
		Name = "Owner",
		Size = UDim2.fromScale(0.92, 0.34),
		Position = UDim2.fromScale(0.04, 0.08),
		Role = "Small",
		Color = "gold",
		AlignX = Enum.TextXAlignment.Left,
	})
	local fighter = UI.text(face, "Aliado NPC (Automatico)", {
		Name = "Fighter",
		Size = UDim2.fromScale(0.92, 0.34),
		Position = UDim2.fromScale(0.04, 0.42),
		Role = "Body",
		Color = "onDark",
		AlignX = Enum.TextXAlignment.Left,
	})
	local sub = UI.text(face, "", {
		Name = "Sub",
		Size = UDim2.fromScale(0.92, 0.24),
		Position = UDim2.fromScale(0.04, 0.74),
		Role = "Small",
		Color = "inkSoft",
		AlignX = Enum.TextXAlignment.Left,
	})
	lobbySlotCards[i] = { Card = card, Face = face, Owner = title, Fighter = fighter, Sub = sub }
end

-- Seletor rapido de 1 personagem (Scroll horizontal/vertical compacto)
local pickerTitle = UI.text(rightFace, "SEU LUTADOR PARA ESTA RAID:", {
	Name = "PickerTitle",
	Size = UDim2.fromScale(0.94, 0.055),
	Position = UDim2.fromScale(0.03, 0.62),
	Role = "Small",
	Color = "gold",
	AlignX = Enum.TextXAlignment.Left,
	Visible = false,
})
local pickerScroll = UI.scroll(rightFace, {
	Name = "FighterPicker",
	Size = UDim2.fromScale(0.94, 0.165),
	Position = UDim2.fromScale(0.03, 0.68),
	Columns = 3,
	CellAspect = 2.4,
	Visible = false,
})
local lastPickerKey = ""

local lobbyMsgLbl = UI.text(rightFace, "", {
	Name = "Message",
	Size = UDim2.fromScale(0.94, 0.052),
	Position = UDim2.fromScale(0.03, 0.805),
	Role = "Small",
	Color = "gold",
})

-- Botoes de acao no rodape da coluna direita
local joinBtn = UI.button(rightFace, {
	Name = "JoinBtn",
	Text = "ENTRAR NO GRUPO (1-4)",
	Icon = "sword",
	Color = "green",
	Size = UDim2.fromScale(0.56, 0.105),
	Position = UDim2.fromScale(0.03, 0.98),
	AnchorPoint = Vector2.new(0, 1),
})
local teleportBtn = UI.button(rightFace, {
	Name = "TeleportBtn",
	Text = "IR A FENDA",
	Icon = "portal",
	Color = "blue",
	Size = UDim2.fromScale(0.36, 0.105),
	Position = UDim2.fromScale(0.61, 0.98),
	AnchorPoint = Vector2.new(0, 1),
})
local startNowBtn = UI.button(rightFace, {
	Name = "StartNowBtn",
	Text = "INICIAR AGORA",
	Icon = "sword",
	Color = "gold",
	Size = UDim2.fromScale(0.54, 0.105),
	Position = UDim2.fromScale(0.03, 0.98),
	AnchorPoint = Vector2.new(0, 1),
	Visible = false,
})
local leaveLobbyBtn = UI.button(rightFace, {
	Name = "LeaveBtn",
	Text = "SAIR",
	Icon = "close",
	Color = "red",
	Size = UDim2.fromScale(0.38, 0.105),
	Position = UDim2.fromScale(0.59, 0.98),
	AnchorPoint = Vector2.new(0, 1),
	Visible = false,
})
for _, b in ipairs({ joinBtn, teleportBtn, startNowBtn, leaveLobbyBtn }) do
	local sc = b:FindFirstChildOfClass("UISizeConstraint")
	if sc then
		sc.MinSize = Vector2.new(88, 36)
	end
end

-- Layout pixel-exato da coluna direita do Lobby (zero sobreposicao no Desktop e Mobile 667x375)
local function layoutLobbyRight()
	local rw, rh = UI.unscaledSize(rightFace)
	local W, H = math.floor(rw + 0.5), math.floor(rh + 0.5)
	if W < 40 or H < 40 then
		return
	end
	local padX = math.max(8, math.floor(W * 0.03))
	local innerW = W - padX * 2
	local gap = math.clamp(math.floor(H * 0.014), 3, 7)

	local btnH = math.clamp(math.floor(H * 0.115), 36, 46)
	local btnY = H - math.max(6, gap)
	local jW = math.floor(innerW * 0.58)
	local tW = innerW - jW - 8
	joinBtn.Size = UDim2.fromOffset(jW, btnH)
	joinBtn.Position = UDim2.fromOffset(padX, btnY)
	teleportBtn.Size = UDim2.fromOffset(tW, btnH)
	teleportBtn.Position = UDim2.fromOffset(padX + jW + 8, btnY)
	local sW = math.floor(innerW * 0.56)
	local lW = innerW - sW - 8
	startNowBtn.Size = UDim2.fromOffset(sW, btnH)
	startNowBtn.Position = UDim2.fromOffset(padX, btnY)
	leaveLobbyBtn.Size = UDim2.fromOffset(lW, btnH)
	leaveLobbyBtn.Position = UDim2.fromOffset(padX + sW + 8, btnY)

	local msgH = math.clamp(math.floor(H * 0.058), 16, 24)
	local msgY = btnY - btnH - gap - msgH
	lobbyMsgLbl.Position = UDim2.fromOffset(padX, msgY)
	lobbyMsgLbl.Size = UDim2.fromOffset(innerW, msgH)

	local y = math.max(6, gap)
	local statusH = math.clamp(math.floor(H * 0.078), 20, 34)
	lobbyStatusLbl.Position = UDim2.fromOffset(padX, y)
	lobbyStatusLbl.Size = UDim2.fromOffset(innerW, statusH)
	y += statusH + math.max(2, gap - 2)

	local rulesH = math.clamp(math.floor(H * 0.052), 14, 22)
	lobbyRuleLbl.Position = UDim2.fromOffset(padX, y)
	lobbyRuleLbl.Size = UDim2.fromOffset(innerW, rulesH)
	y += rulesH + gap

	local availMid = math.max(80, msgY - y - gap)
	local pTitleH = math.clamp(math.floor(H * 0.050), 14, 22)
	local slotsH = math.floor(availMid * 0.57)
	slotsHolder.Position = UDim2.fromOffset(padX, y)
	slotsHolder.Size = UDim2.fromOffset(innerW, slotsH)
	y += slotsH + gap

	pickerTitle.Position = UDim2.fromOffset(padX, y)
	pickerTitle.Size = UDim2.fromOffset(innerW, pTitleH)
	y += pTitleH + 2

	local pickH = math.max(36, msgY - y - gap)
	pickerScroll.Position = UDim2.fromOffset(padX, y)
	pickerScroll.Size = UDim2.fromOffset(innerW, pickH)
end
rightFace:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutLobbyRight)
task.defer(layoutLobbyRight)

--------------------------------------------------------------------
-- 3. HUD DE COMBATE 4x1
--------------------------------------------------------------------
local battleRoot = UI.frame(canvas, { Name = "RaidBattleRoot", Visible = false, ZIndex = 12 })

-- Barra colossal do Boss no topo central
local bossBarHolder, bossBarFace = UI.panel(battleRoot, {
	Name = "BossTopBar",
	Size = UDim2.fromScale(0.56, 0.165),
	Position = UDim2.fromScale(0.5, 0.025),
	AnchorPoint = Vector2.new(0.5, 0),
	Color = "panel",
	Corner = T.Corner.Card,
	MaxSize = Vector2.new(720, 118),
})
local bTopTier = UI.chip(bossBarFace, "6 ESTRELAS", "dark", {
	Name = "Tier",
	Size = UDim2.fromScale(0.24, 0.25),
	Position = UDim2.fromScale(0.025, 0.07),
})
local bTopName = UI.text(bossBarFace, "BOSS", {
	Name = "Name",
	Size = UDim2.fromScale(0.44, 0.28),
	Position = UDim2.fromScale(0.28, 0.06),
	Role = "Heading",
	Color = "onDark",
	AlignX = Enum.TextXAlignment.Left,
})
local bTopTurn = UI.text(bossBarFace, "TURNO 1/10", {
	Name = "Turn",
	Size = UDim2.fromScale(0.14, 0.24),
	Position = UDim2.fromScale(0.73, 0.08),
	Role = "Small",
	Color = "inkSoft",
})
local bTopTimer = UI.text(bossBarFace, "20s", {
	Name = "Timer",
	Size = UDim2.fromScale(0.10, 0.26),
	Position = UDim2.fromScale(0.975, 0.07),
	AnchorPoint = Vector2.new(1, 0),
	Role = "Heading",
	Color = "gold",
	AlignX = Enum.TextXAlignment.Right,
})
local bTopHpBar = UI.bar(bossBarFace, {
	Name = "BossHp",
	Size = UDim2.fromScale(0.95, 0.21),
	Position = UDim2.fromScale(0.025, 0.39),
	FillColor = "hpLow",
})
local bTopHpText = UI.text(bossBarFace, "1000 / 1000", {
	Name = "HpText",
	Size = UDim2.fromScale(0.44, 0.22),
	Position = UDim2.fromScale(0.975, 0.65),
	AnchorPoint = Vector2.new(1, 0),
	Role = "Small",
	Color = "onDark",
	AlignX = Enum.TextXAlignment.Right,
})
local bTopStatus = UI.text(bossBarFace, "", {
	Name = "BossStatus",
	Size = UDim2.fromScale(0.50, 0.22),
	Position = UDim2.fromScale(0.025, 0.65),
	Role = "Small",
	Color = "gold",
	AlignX = Enum.TextXAlignment.Left,
})

-- Segmentos do Escudo de Fase (ate 7 barras luminosas abaixo da barra de HP do Boss)
local shieldBarRow = UI.frame(bossBarHolder, {
	Name = "ShieldRow",
	Size = UDim2.fromScale(0.92, 0.16),
	Position = UDim2.fromScale(0.04, 1.04),
	Visible = false,
})
local shieldSegments = {}
for i = 1, 7 do
	local seg = UI.frame(shieldBarRow, {
		Name = "Seg" .. i,
		Size = UDim2.fromScale(0.132, 1),
		Position = UDim2.fromScale((i - 1) * 0.144, 0),
		Color = "blue",
		Corner = T.Corner.Pill,
	})
	UI.stroke(seg, Color3.fromRGB(215, 245, 255), 1.1)
	shieldSegments[i] = seg
end

-- Log narrativo centralizado acima dos controles inferiores
local logHolder, logFace = UI.panel(battleRoot, {
	Name = "RaidLog",
	Size = UDim2.fromScale(0.56, 0.068),
	Position = UDim2.fromScale(0.5, 0.635),
	AnchorPoint = Vector2.new(0.5, 0),
	Color = "panel",
	Corner = T.Corner.Pill,
	MaxSize = Vector2.new(720, 46),
})
local logText = UI.text(logFace, "A Raid come\u{e7}ou! Escolha seu golpe.", {
	Name = "Text",
	Size = UDim2.fromScale(0.94, 0.80),
	Position = UDim2.fromScale(0.03, 0.10),
	Role = "Small",
	Color = "onDark",
})

-- 4 Cards dos Aliados (canto inferior esquerdo, grade 2x2)
local allyGridHolder = UI.frame(battleRoot, {
	Name = "AllyGrid",
	Size = UDim2.fromScale(0.46, 0.245),
	Position = UDim2.fromScale(0.02, 0.98),
	AnchorPoint = Vector2.new(0, 1),
	MinSize = Vector2.new(250, 96),
	MaxSize = Vector2.new(560, 160),
})
local allyCards = {}
for i = 1, 4 do
	local row = (i - 1) // 2
	local col = (i - 1) % 2
	local holder, face = UI.panel(allyGridHolder, {
		Name = "Ally" .. i,
		Size = UDim2.fromScale(0.488, 0.47),
		Position = UDim2.fromScale(col * 0.512, row * 0.53),
		Color = "panel",
		Corner = T.Corner.Card,
	})
	local stroke = face:FindFirstChildOfClass("UIStroke")
	local nameLbl = UI.text(face, "Aliado", {
		Name = "Name",
		Size = UDim2.fromScale(0.48, 0.34),
		Position = UDim2.fromScale(0.04, 0.06),
		Role = "Small",
		Color = "onDark",
		AlignX = Enum.TextXAlignment.Left,
	})
	local livesLbl = UI.text(face, "VIDAS 2/2", {
		Name = "Lives",
		Size = UDim2.fromScale(0.32, 0.30),
		Position = UDim2.fromScale(0.96, 0.08),
		AnchorPoint = Vector2.new(1, 0),
		Role = "Small",
		Color = "gold",
		AlignX = Enum.TextXAlignment.Right,
	})
	local hpBar = UI.bar(face, {
		Name = "Hp",
		Size = UDim2.fromScale(0.92, 0.21),
		Position = UDim2.fromScale(0.04, 0.44),
		FillColor = "hpHigh",
	})
	local ownerLbl = UI.text(face, "", {
		Name = "Owner",
		Size = UDim2.fromScale(0.56, 0.26),
		Position = UDim2.fromScale(0.04, 0.70),
		Role = "Small",
		Color = "inkSoft",
		AlignX = Enum.TextXAlignment.Left,
	})
	local dmgLbl = UI.text(face, "0 dano", {
		Name = "Dmg",
		Size = UDim2.fromScale(0.36, 0.26),
		Position = UDim2.fromScale(0.96, 0.70),
		AnchorPoint = Vector2.new(1, 0),
		Role = "Small",
		Color = "gold",
		AlignX = Enum.TextXAlignment.Right,
	})
	local readyIcon = UI.icon(face, "tick", {
		Name = "Ready",
		Size = UDim2.fromScale(0.09, 0.30),
		Position = UDim2.fromScale(0.535, 0.07),
		AspectAxis = Enum.DominantAxis.Height,
		Visible = false,
	})
	allyCards[i] = {
		Holder = holder, Face = face, Stroke = stroke,
		Name = nameLbl, Lives = livesLbl, HpBar = hpBar,
		Owner = ownerLbl, Dmg = dmgLbl, Ready = readyIcon,
	}
end

-- Grade dos 4 Golpes (canto inferior direito — SOMENTE os 4 golpes, sem Mochila e sem Torcida!)
local movesHolder = UI.frame(battleRoot, {
	Name = "MovesGrid",
	Size = UDim2.fromScale(0.47, 0.245),
	Position = UDim2.fromScale(0.98, 0.98),
	AnchorPoint = Vector2.new(1, 1),
	MinSize = Vector2.new(250, 96),
	MaxSize = Vector2.new(580, 160),
})
local moveButtons = {}
for i = 1, 4 do
	local row = (i - 1) // 2
	local col = (i - 1) % 2
	local btn, face = UI.button(movesHolder, {
		Name = "Move" .. i,
		Color = "panelAlt",
		Size = UDim2.fromScale(0.488, 0.46),
		Position = UDim2.fromScale(col * 0.512, row * 0.54),
		Corner = T.Corner.Card,
	})
	local mvMin = btn:FindFirstChildOfClass("UISizeConstraint")
	if mvMin then
		mvMin.MinSize = Vector2.new(100, 40)
	end
	local mName = UI.text(face, "Golpe " .. i, {
		Name = "Name",
		Size = UDim2.fromScale(0.64, 0.46),
		Position = UDim2.fromScale(0.05, 0.08),
		Role = "Body",
		Color = "onDark",
		AlignX = Enum.TextXAlignment.Left,
	})
	local mEff = UI.text(face, "", {
		Name = "Eff",
		Size = UDim2.fromScale(0.24, 0.36),
		Position = UDim2.fromScale(0.96, 0.10),
		AnchorPoint = Vector2.new(1, 0),
		Role = "Small",
		Color = "gold",
		AlignX = Enum.TextXAlignment.Right,
	})
	local mMeta = UI.text(face, "", {
		Name = "Meta",
		Size = UDim2.fromScale(0.90, 0.36),
		Position = UDim2.fromScale(0.05, 0.56),
		Role = "Small",
		Color = "inkSoft",
		AlignX = Enum.TextXAlignment.Left,
	})
	moveButtons[i] = { Btn = btn, Face = face, Name = mName, Eff = mEff, Meta = mMeta }
end

--------------------------------------------------------------------
-- 4. TELA DE RESULTADO (RANKING MVP + CAPTURA POS-RAID)
--------------------------------------------------------------------
local resultWin = UI.window(canvas, {
	Name = "RaidResultWindow",
	Title = "VITORIA NA RAID!",
	Icon = "trophy",
	HeaderColor = "gold",
	Size = UDim2.fromScale(0.88, 0.82),
	Aspect = 1.75,
})
local rBody = resultWin.Body
local resultSummaryLbl = UI.text(rBody, "", {
	Name = "Summary",
	Size = UDim2.fromScale(0.96, 0.11),
	Position = UDim2.fromScale(0.02, 0.02),
	Role = "Body",
	Color = "gold",
})
local rankPanel, rankFace = UI.panel(rBody, {
	Name = "RankingPanel",
	Size = UDim2.fromScale(0.47, 0.66),
	Position = UDim2.fromScale(0.02, 0.15),
	Color = "panelAlt",
	Corner = T.Corner.Card,
})
UI.text(rankFace, "RANKING DE DANO (MVP +25% GOLD/XP)", {
	Name = "Title",
	Size = UDim2.fromScale(0.94, 0.11),
	Position = UDim2.fromScale(0.03, 0.03),
	Role = "Small",
	Color = "gold",
	AlignX = Enum.TextXAlignment.Left,
})
local rankRows = {}
for i = 1, 4 do
	local rowP, rowF = UI.panel(rankFace, {
		Name = "Row" .. i,
		Size = UDim2.fromScale(0.94, 0.18),
		Position = UDim2.fromScale(0.03, 0.16 + (i - 1) * 0.205),
		Color = "slot",
		Corner = T.Corner.Card,
	})
	local icon = UI.icon(rowF, "trophy", {
		Name = "Mvp",
		Size = UDim2.fromScale(0.12, 0.68),
		Position = UDim2.fromScale(0.03, 0.5),
		AnchorPoint = Vector2.new(0, 0.5),
		AspectAxis = Enum.DominantAxis.Height,
		Visible = false,
	})
	local lbl = UI.text(rowF, "", {
		Name = "Lbl",
		Size = UDim2.fromScale(0.58, 0.80),
		Position = UDim2.fromScale(0.16, 0.10),
		Role = "Small",
		Color = "onDark",
		AlignX = Enum.TextXAlignment.Left,
	})
	local val = UI.text(rowF, "", {
		Name = "Val",
		Size = UDim2.fromScale(0.24, 0.80),
		Position = UDim2.fromScale(0.97, 0.10),
		AnchorPoint = Vector2.new(1, 0),
		Role = "Small",
		Color = "gold",
		AlignX = Enum.TextXAlignment.Right,
	})
	rankRows[i] = { Panel = rowP, Icon = icon, Lbl = lbl, Val = val }
end

local capPanel, capFace = UI.panel(rBody, {
	Name = "CapturePanel",
	Size = UDim2.fromScale(0.47, 0.66),
	Position = UDim2.fromScale(0.51, 0.15),
	Color = "panelAlt",
	Corner = T.Corner.Card,
})
local capTitleLbl = UI.text(capFace, "CAPTURA POS-RAID", {
	Name = "Title",
	Size = UDim2.fromScale(0.94, 0.11),
	Position = UDim2.fromScale(0.03, 0.03),
	Role = "Heading",
	Color = "gold",
})
local capDescLbl = UI.text(capFace, "", {
	Name = "Desc",
	Size = UDim2.fromScale(0.94, 0.24),
	Position = UDim2.fromScale(0.03, 0.16),
	Role = "Small",
	Color = "onDark",
})
local capContratoBtn, capContratoFace = UI.button(capFace, {
	Name = "CapContratoBtn",
	Text = "SELO DE CONTRATO",
	Icon = "seal_basic",
	Color = "blue",
	Size = UDim2.fromScale(0.92, 0.17),
	Position = UDim2.fromScale(0.04, 0.43),
})
local capSuperiorBtn, capSuperiorFace = UI.button(capFace, {
	Name = "CapSuperiorBtn",
	Text = "SELO SUPERIOR",
	Icon = "seal_superior",
	Color = "purple",
	Size = UDim2.fromScale(0.92, 0.17),
	Position = UDim2.fromScale(0.04, 0.63),
})
local capFeedbackLbl = UI.text(capFace, "", {
	Name = "Feedback",
	Size = UDim2.fromScale(0.94, 0.16),
	Position = UDim2.fromScale(0.03, 0.82),
	Role = "Body",
	Color = "gold",
})
for _, cb in ipairs({ capContratoBtn, capSuperiorBtn }) do
	local sc = cb:FindFirstChildOfClass("UISizeConstraint")
	if sc then
		sc.MinSize = Vector2.new(120, 32)
	end
end
local function layoutCapturePanel()
	local cw, ch = UI.unscaledSize(capFace)
	local W, H = math.floor(cw + 0.5), math.floor(ch + 0.5)
	if W < 40 or H < 40 then
		return
	end
	local padX = math.max(8, math.floor(W * 0.04))
	local innerW = W - padX * 2
	local gap = math.clamp(math.floor(H * 0.025), 3, 8)
	local titleH = math.clamp(math.floor(H * 0.12), 18, 30)
	local btnH = math.clamp(math.floor(H * 0.185), 32, 46)
	local fbH = math.clamp(math.floor(H * 0.14), 18, 32)

	local y = math.max(6, gap)
	capTitleLbl.Position = UDim2.fromOffset(padX, y)
	capTitleLbl.Size = UDim2.fromOffset(innerW, titleH)
	y += titleH + gap

	local descH = math.max(20, H - y - btnH * 2 - fbH - gap * 4)
	capDescLbl.Position = UDim2.fromOffset(padX, y)
	capDescLbl.Size = UDim2.fromOffset(innerW, descH)
	y += descH + gap

	capContratoBtn.Position = UDim2.fromOffset(padX, y)
	capContratoBtn.Size = UDim2.fromOffset(innerW, btnH)
	y += btnH + gap

	capSuperiorBtn.Position = UDim2.fromOffset(padX, y)
	capSuperiorBtn.Size = UDim2.fromOffset(innerW, btnH)
	y += btnH + gap

	capFeedbackLbl.Position = UDim2.fromOffset(padX, y)
	capFeedbackLbl.Size = UDim2.fromOffset(innerW, math.max(16, H - y - 4))
end
capFace:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutCapturePanel)
task.defer(layoutCapturePanel)

local exitRaidBtn = UI.button(rBody, {
	Name = "ExitRaidBtn",
	Text = "VOLTAR A PRACA",
	Icon = "house",
	Color = "green",
	Size = UDim2.fromScale(0.42, 0.12),
	Position = UDim2.fromScale(0.5, 0.985),
	AnchorPoint = Vector2.new(0.5, 1),
})
local exitMin = exitRaidBtn:FindFirstChildOfClass("UISizeConstraint")
if exitMin then
	exitMin.MinSize = Vector2.new(120, 36)
end

--------------------------------------------------------------------
-- RENDERIZACAO DO BANNER HUD E DO LOBBY
--------------------------------------------------------------------
local function refreshHudBanner()
	if not globalStatus or inBattleLock or UI.inBattle() or not (profile and profile.StarterChosen) then
		hudBannerBtn.Visible = false
		return
	end
	local elapsed = os.clock() - lastStatusAt
	local isOpen = globalStatus.Open == true
	local left = if isOpen
		then math.max(0, (globalStatus.ClosesIn or 0) - elapsed)
		else math.max(0, (globalStatus.NextOpenIn or 0) - elapsed)

	-- Exibe banner quando a Raid esta ABERTA ou faltam <= 10 minutos
	if not isOpen and left > 600 then
		hudBannerBtn.Visible = false
		return
	end

	hudBannerBtn.Visible = true
	local st = globalStatus.Stars or 3
	hudBannerStroke.Color = if isOpen then tierColor(st) else T.Palette.blue
	UI.setIcon(hudBannerIcon, if st == 6 then "sparkle" else "sword")
	if isOpen then
		hudBannerTitle.Text = string.format("RAID %d ESTRELAS ABERTA!", st)
		hudBannerTitle.TextColor3 = if st == 6 then Color3.fromRGB(255, 92, 122) else T.Palette.gold
		hudBannerSub.Text = (globalStatus.BossName or "Boss") .. " (Nv. " .. tostring(globalStatus.BossLevel or 25) .. ")"
		hudBannerTimer.Text = fmtMmSs(left)
		hudBannerTimer.TextColor3 = Color3.fromRGB(130, 255, 168)
	else
		hudBannerTitle.Text = string.format("PROXIMA RAID (%d ESTRELAS)", st)
		hudBannerTitle.TextColor3 = T.Palette.inkSoft
		hudBannerSub.Text = globalStatus.BossName or "Boss"
		hudBannerTimer.Text = fmtMmSs(left)
		hudBannerTimer.TextColor3 = T.Palette.gold
	end
end

local function populateFighterPicker(selectedUid: string?, forceRebuild: boolean?)
	if not profile or typeof(profile.Collection) ~= "table" then
		return
	end
	local list = {}
	for uid, m in pairs(profile.Collection) do
		table.insert(list, { Uid = uid, Member = m })
	end
	local key = tostring(selectedUid or "") .. ":" .. tostring(#list)
	if not forceRebuild and key == lastPickerKey then
		return
	end
	lastPickerKey = key

	for _, ch in ipairs(pickerScroll:GetChildren()) do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end
	table.sort(list, function(a, b)
		if (a.Member.Level or 1) ~= (b.Member.Level or 1) then
			return (a.Member.Level or 1) > (b.Member.Level or 1)
		end
		return a.Uid < b.Uid
	end)
	for idx, entry in ipairs(list) do
		local m = entry.Member
		local def = Characters.Get(m.CharacterId)
		local chosen = entry.Uid == selectedUid
		local b, bf = UI.button(pickerScroll, {
			Name = "Pick_" .. entry.Uid,
			Color = if chosen then "gold" else "slot",
			LayoutOrder = idx,
			Corner = T.Corner.Card,
			Sound = false,
			OnClick = function()
				local res = RaidActionRF:InvokeServer("SelectFighter", entry.Uid)
				if res and res.Ok and res.Data then
					globalStatus = res.Data
					lastStatusAt = os.clock()
					lastPickerKey = ""
					UI.play("click")
				elseif res and res.Message then
					lobbyMsgLbl.Text = res.Message
					UI.play("error")
				end
			end,
		})
		UI.text(bf, (def and def.Name or m.CharacterId) .. "\nNv. " .. tostring(m.Level or 1), {
			Name = "Lbl",
			Size = UDim2.fromScale(0.92, 0.88),
			Position = UDim2.fromScale(0.04, 0.06),
			Role = "Small",
			Color = if chosen then "onLight" else "onDark",
		})
	end
end

local lastPortraitBossId = ""
local function refreshLobbyWindow()
	if not globalStatus then
		return
	end
	local st = globalStatus.Stars or 3
	local bossId = globalStatus.BossId or "Freeza"
	local bossDef = Characters.Get(bossId)
	local bossName = globalStatus.BossName or (bossDef and bossDef.Name) or bossId

	bossTierChip.Face.Label.Text = string.format("%d ESTRELAS", st)
	UI.paint(bossTierChip, if st == 6 then "dark" elseif st == 5 then "gold" elseif st == 4 then "purple" else "blue")
	UI.setIcon(bossClassIcon, UI.TypeIcon[globalStatus.BossType or "Lutador"] or "classe_lutador")
	if lastPortraitBossId ~= bossId then
		lastPortraitBossId = bossId
		bossPortrait.Set("raid_boss_" .. bossId, { CharacterId = bossId, Level = globalStatus.BossLevel or 25, Stars = 0 })
	end
	bossNameLbl.Text = string.upper(bossName)
	bossLvLbl.Text = string.format("Boss Nv. %d | Recomendado: Nv. %d+ (Entrada Livre)", globalStatus.BossLevel or 25, globalStatus.RecommendedLevel or 20)

	local rw = globalStatus.Rewards or {}
	rewardBodyLbl.Text = string.format(
		"%s Gold | +%d XP Conta | +%d XP Lutador | +%d de cada Min\u{e9}rio de Treino",
		UI.fmt(rw.Gold or 0),
		rw.AccountXp or 0,
		rw.CharXp or 0,
		rw.OrePerStat or 0
	)

	local seals = globalStatus.Seals or { SeloContrato = 0, SeloSuperior = 0 }
	local cap = globalStatus.Capture or {}
	if globalStatus.SuperiorOnly then
		local haveSup = seals.SeloSuperior or 0
		sealBoxStroke.Color = if haveSup > 0 then T.Palette.gold else T.Palette.hpLow
		sealWarnLbl.TextColor3 = if haveSup > 0 then T.Palette.onDark else T.Palette.hpLow
		sealWarnLbl.Text = string.format(
			"CAPTURA (%s): EXIGE SELO SUPERIOR!\nVoc\u{ea} tem %dx Selo Superior na mochila.%s",
			fmtPct(cap.SeloSuperior or 0.01),
			haveSup,
			if haveSup <= 0 then " Compre na Loja ou pegue no Login Di\u{e1}rio!" else ""
		)
	else
		local totalSeals = (seals.SeloContrato or 0) + (seals.SeloSuperior or 0)
		sealBoxStroke.Color = if totalSeals > 0 then T.Palette.blue else T.Palette.hpLow
		sealWarnLbl.TextColor3 = if totalSeals > 0 then T.Palette.onDark else T.Palette.hpLow
		sealWarnLbl.Text = string.format(
			"CAPTURA: Contrato %s (%dx) | Superior %s (%dx)%s",
			fmtPct(cap.SeloContrato or 0.35), seals.SeloContrato or 0,
			fmtPct(cap.SeloSuperior or 0.525), seals.SeloSuperior or 0,
			if totalSeals <= 0 then "\nAVISO: Voc\u{ea} est\u{e1} sem Selos na mochila!" else ""
		)
	end

	local elapsed = os.clock() - lastStatusAt
	local lobby = globalStatus.Lobby
	if globalStatus.Open then
		local left = math.max(0, (globalStatus.ClosesIn or 0) - elapsed)
		if lobby then
			lobbyStatusLbl.Text = string.format("NO GRUPO (%d/4) - INICIANDO EM %ds", #lobby.Members, math.max(0, math.floor((lobby.CountdownLeft or 0) - elapsed)))
		else
			lobbyStatusLbl.Text = string.format("RAID ABERTA - FECHA EM %s", fmtMmSs(left))
		end
		lobbyStatusLbl.TextColor3 = Color3.fromRGB(130, 255, 168)
	else
		local nextIn = math.max(0, (globalStatus.NextOpenIn or 0) - elapsed)
		lobbyStatusLbl.Text = "FENDA FECHADA - ABRE EM " .. fmtMmSs(nextIn)
		lobbyStatusLbl.TextColor3 = T.Palette.gold
	end

	if globalStatus.Claimed then
		lobbyMsgLbl.Text = "Recompensa desta hora j\u{e1} resgatada (voc\u{ea} ainda pode entrar para ajudar amigos)."
		lobbyMsgLbl.TextColor3 = T.Palette.inkSoft
	end

	-- Preenche os 4 slots do grupo
	local myUid = nil
	local isLeader = false
	for i = 1, 4 do
		local c = lobbySlotCards[i]
		local mem = lobby and lobby.Members and lobby.Members[i]
		if mem then
			if mem.UserId == player.UserId then
				myUid = mem.Uid
				isLeader = mem.IsLeader == true
			end
			c.Owner.Text = (if mem.IsLeader then "[LIDER] " else "") .. (mem.PlayerName or "Jogador")
			c.Owner.TextColor3 = if mem.UserId == player.UserId then T.Palette.gold else T.Palette.onDark
			c.Fighter.Text = string.format("%s (Nv. %d)", mem.CharacterName or mem.CharacterId, mem.Level or 1)
			c.Sub.Text = mem.Type or ""
		else
			c.Owner.Text = "SLOT " .. i .. " (ALIADO NPC)"
			c.Owner.TextColor3 = T.Palette.inkSoft
			c.Fighter.Text = "Aliado NPC (Automatico)"
			c.Sub.Text = "Nao consome vidas dos jogadores"
		end
	end

	local inLobby = lobby ~= nil
	joinBtn.Visible = not inLobby
	teleportBtn.Visible = not inLobby
	startNowBtn.Visible = inLobby
	leaveLobbyBtn.Visible = inLobby
	pickerTitle.Visible = inLobby
	pickerScroll.Visible = inLobby

	if inLobby then
		startNowBtn:SetAttribute("Disabled", not isLeader)
		UI.paint(startNowBtn, if isLeader then "gold" else "slot")
		populateFighterPicker(myUid, false)
	end
end

--------------------------------------------------------------------
-- RENDERIZACAO DO COMBATE 4x1
--------------------------------------------------------------------
local function refreshBattleHud()
	if not activeRaid or not activeRaid.State then
		return
	end
	local st = activeRaid.State
	local boss = st.Boss
	local stars = st.Stars or activeRaid.Stars or 3

	bTopTier.Face.Label.Text = string.format("%d ESTRELAS", stars)
	UI.paint(bTopTier, if stars == 6 then "dark" elseif stars == 5 then "gold" elseif stars == 4 then "purple" else "blue")
	bTopName.Text = string.format("%s (Nv. %d)", boss.Name or "Boss", boss.Level or 25)
	bTopTurn.Text = string.format("TURNO %d/%d", math.max(1, st.Turn or 0), st.MaxTurns or Raids.MaxTurns)

	local hpFrac = (boss.Hp or 0) / math.max(1, boss.MaxHp or 1)
	UI.setBar(bTopHpBar, hpFrac, if hpFrac > 0.5 then "hpHigh" elseif hpFrac > 0.25 then "hpMid" else "hpLow", false)
	bTopHpText.Text = string.format("%s / %s HP", UI.fmt(boss.Hp or 0), UI.fmt(boss.MaxHp or 1))

	if boss.Stunned then
		bTopStatus.Text = "ATORDOADO! (DEFESA REDUZIDA)"
		bTopStatus.TextColor3 = Color3.fromRGB(115, 245, 255)
	elseif (boss.Shield or 0) > 0 then
		bTopStatus.Text = string.format("ESCUDO DE FASE ATIVO (%d/%d) - SUPER EFETIVO QUEBRA 2X!", boss.Shield, boss.MaxShield)
		bTopStatus.TextColor3 = T.Palette.gold
	else
		local defStage = (boss.Stages and boss.Stages.Defense) or 0
		bTopStatus.Text = if defStage < 0 then ("DEFESA " .. tostring(defStage)) else ""
		bTopStatus.TextColor3 = T.Palette.inkSoft
	end

	-- Segmentos do Escudo de Fase
	local maxSh = boss.MaxShield or 0
	local curSh = boss.Shield or 0
	shieldBarRow.Visible = curSh > 0
	if curSh > 0 then
		local segW = (1 - (maxSh - 1) * 0.014) / math.max(1, maxSh)
		for i = 1, 7 do
			local seg = shieldSegments[i]
			seg.Visible = i <= maxSh
			if i <= maxSh then
				seg.Size = UDim2.fromScale(segW, 1)
				seg.Position = UDim2.fromScale((i - 1) * (segW + 0.014), 0)
				UI.paint(seg, if i <= curSh then "blue" else "slot")
			end
		end
	end

	-- 4 Cards dos Aliados
	local mySlotState = nil
	for i = 1, 4 do
		local c = allyCards[i]
		local s = st.Slots and st.Slots[i]
		if s then
			local isMine = i == activeRaid.MySlot
			if isMine then
				mySlotState = s
			end
			if c.Stroke then
				c.Stroke.Color = if isMine then T.Palette.gold else T.Outline
				c.Stroke.Thickness = if isMine then 2.2 else 1.4
			end
			c.Name.Text = string.format("%s (Nv.%d)", s.Name or "?", s.Level or 1)
			c.Owner.Text = if s.IsNpc then "Aliado NPC" else (s.OwnerName or "Jogador")
			c.Dmg.Text = UI.fmt(s.TotalDamage or 0) .. " dano"

			if s.Out then
				c.Lives.Text = "FORA (0/2)"
				c.Lives.TextColor3 = T.Palette.hpLow
			elseif (s.Hp or 0) <= 0 then
				c.Lives.Text = string.format("VOLTA %dT", s.RespawnIn or 2)
				c.Lives.TextColor3 = T.Palette.gold
			elseif s.IsNpc then
				c.Lives.Text = "NPC"
				c.Lives.TextColor3 = T.Palette.inkSoft
			else
				c.Lives.Text = string.format("VIDAS %d/%d", s.Lives or 2, s.MaxLives or 2)
				c.Lives.TextColor3 = if (s.Lives or 2) >= 2 then T.Palette.hpHigh else T.Palette.gold
			end

			local aFrac = (s.Hp or 0) / math.max(1, s.MaxHp or 1)
			UI.setBar(c.HpBar, aFrac, if aFrac > 0.5 then "hpHigh" elseif aFrac > 0.25 then "hpMid" else "hpLow", false)
			c.Ready.Visible = activeRaid.ReadySlots and activeRaid.ReadySlots[i] == true
		end
	end

	-- 4 Golpes do jogador (SOMENTE golpes — zero Mochila e zero Torcida!)
	local canAct = mySlotState ~= nil and (mySlotState.Hp or 0) > 0 and not mySlotState.Out and not activeRaid.MoveSent and st.State == "WaitingForInput"
	for i = 1, 4 do
		local mb = moveButtons[i]
		local mv = mySlotState and mySlotState.Moves and mySlotState.Moves[i]
		if mv then
			mb.Btn.Visible = true
			mb.Name.Text = mv.Name or mv.Id
			local eff = mv.Eff or 1
			if mv.Category == "Damage" and eff > 1 then
				mb.Eff.Text = "2x SUPER"
				mb.Eff.TextColor3 = Color3.fromRGB(120, 255, 165)
			elseif mv.Category == "Damage" and eff < 1 then
				mb.Eff.Text = "0.5x"
				mb.Eff.TextColor3 = T.Palette.hpLow
			else
				mb.Eff.Text = ""
			end
			mb.Meta.Text = string.format("%s | Pod %d | PP %d/%d", mv.Type or "", mv.Power or 0, mv.Pp or 0, mv.MaxPp or 0)
			local usable = canAct and (mv.Pp or 0) > 0
			mb.Btn:SetAttribute("Disabled", not usable)
			UI.paint(mb.Btn, if usable then typeColor(mv.Type) else "slot")
		else
			mb.Btn.Visible = false
		end
	end
end

local function populateResultRanking(ranking, mvpSlot: number?)
	for i = 1, 4 do
		local row = rankRows[i]
		local entry = ranking and ranking[i]
		if entry then
			row.Panel.Visible = true
			local isMvp = (mvpSlot ~= nil and entry.Slot == mvpSlot)
			row.Icon.Visible = isMvp
			row.Lbl.Text = string.format(
				"#%d %s (%s)%s",
				i,
				entry.OwnerName or "Aliado",
				entry.CharacterName or entry.CharacterId,
				if isMvp then " - MVP" else ""
			)
			row.Val.Text = UI.fmt(entry.TotalDamage or 0) .. " dano"
		else
			row.Panel.Visible = false
		end
	end
end

local function updateCaptureButtons(payload)
	local seals = payload.Seals or { SeloContrato = 0, SeloSuperior = 0 }
	local cap = payload.Capture or {}
	local canCap = payload.CanCapture == true and not payload.CaptureUsed
	local supOnly = payload.SuperiorOnly == true

	local cHave = seals.SeloContrato or 0
	local sHave = seals.SeloSuperior or 0

	local cLabel = capContratoFace:FindFirstChild("Label")
	if cLabel and cLabel:IsA("TextLabel") then
		cLabel.Text = if supOnly
			then "SELO CONTRATO (BLOQUEADO 5-6 ESTRELAS)"
			else string.format("SELO DE CONTRATO (%s) - Voce tem %dx", fmtPct(cap.SeloContrato or 0), cHave)
	end
	local sLabel = capSuperiorFace:FindFirstChild("Label")
	if sLabel and sLabel:IsA("TextLabel") then
		sLabel.Text = string.format("SELO SUPERIOR (%s) - Voce tem %dx", fmtPct(cap.SeloSuperior or 0), sHave)
	end

	local cUsable = canCap and (not supOnly) and cHave >= 1
	local sUsable = canCap and sHave >= 1
	capContratoBtn:SetAttribute("Disabled", not cUsable)
	capSuperiorBtn:SetAttribute("Disabled", not sUsable)
	UI.paint(capContratoBtn, if cUsable then "blue" else "slot")
	UI.paint(capSuperiorBtn, if sUsable then "purple" else "slot")
end

--------------------------------------------------------------------
-- EVENTOS DE BOTAO
--------------------------------------------------------------------
hudBannerBtn.Activated:Connect(function()
	local res = RaidActionRF:InvokeServer("GetStatus")
	if res and res.Ok and res.Data then
		globalStatus = res.Data
		lastStatusAt = os.clock()
	end
	lastPickerKey = ""
	refreshLobbyWindow()
	lobbyWin.Open()
end)

teleportBtn.Activated:Connect(function()
	local res = RaidActionRF:InvokeServer("TeleportMonolith")
	if res and res.Ok then
		if res.Data then
			globalStatus = res.Data
			lastStatusAt = os.clock()
		end
		lobbyWin.Close()
		UI.play("open")
	elseif res and res.Message then
		lobbyMsgLbl.Text = res.Message
		UI.play("error")
	end
end)

joinBtn.Activated:Connect(function()
	local res = RaidActionRF:InvokeServer("JoinLobby")
	if res and res.Ok and res.Data then
		globalStatus = res.Data
		lastStatusAt = os.clock()
		lobbyMsgLbl.Text = ""
		lastPickerKey = ""
		refreshLobbyWindow()
		UI.play("open")
	elseif res and res.Message then
		lobbyMsgLbl.Text = res.Message
		UI.play("error")
	end
end)

leaveLobbyBtn.Activated:Connect(function()
	local res = RaidActionRF:InvokeServer("LeaveLobby")
	if res and res.Ok and res.Data then
		globalStatus = res.Data
		lastStatusAt = os.clock()
		refreshLobbyWindow()
		UI.play("close")
	end
end)

startNowBtn.Activated:Connect(function()
	if startNowBtn:GetAttribute("Disabled") then
		return
	end
	local res = RaidActionRF:InvokeServer("StartNow")
	if res and not res.Ok and res.Message then
		lobbyMsgLbl.Text = res.Message
		UI.play("error")
	end
end)

for i = 1, 4 do
	moveButtons[i].Btn.Activated:Connect(function()
		if moveButtons[i].Btn:GetAttribute("Disabled") or not activeRaid or activeRaid.MoveSent then
			return
		end
		activeRaid.MoveSent = true
		activeRaid.ReadySlots = activeRaid.ReadySlots or {}
		activeRaid.ReadySlots[activeRaid.MySlot] = true
		refreshBattleHud()
		local res = RaidActionRF:InvokeServer("SubmitMove", i)
		if res and not res.Ok then
			activeRaid.MoveSent = false
			activeRaid.ReadySlots[activeRaid.MySlot] = nil
			logText.Text = res.Message or "Nao foi possivel enviar golpe."
			refreshBattleHud()
			UI.play("error")
		else
			logText.Text = "Golpe confirmado! Aguardando o resto do grupo..."
			UI.play("click")
		end
	end)
end

local lastVictoryPayload = nil

local function doCapture(sealId: string)
	if not lastVictoryPayload or lastVictoryPayload.CaptureUsed then
		return
	end
	local res = RaidActionRF:InvokeServer("Capture", sealId)
	if not res or not res.Ok then
		capFeedbackLbl.Text = (res and res.Message) or "Falha ao tentar capturar."
		capFeedbackLbl.TextColor3 = T.Palette.hpLow
		UI.play("error")
		return
	end
	lastVictoryPayload.CaptureUsed = true
	lastVictoryPayload.Seals = res.Seals or lastVictoryPayload.Seals
	updateCaptureButtons(lastVictoryPayload)
	if res.Caught then
		capFeedbackLbl.Text = string.format("CAPTURADO! %s (Nv. %d) entrou na sua cole\u{e7}\u{e3}o!", res.BossName or "Boss", res.Level or 15)
		capFeedbackLbl.TextColor3 = Color3.fromRGB(120, 255, 165)
		UI.play("summon_legendary")
	else
		capFeedbackLbl.Text = string.format("%s escapou do Selo! (%s de chance)", res.BossName or "Boss", fmtPct(res.Chance or 0))
		capFeedbackLbl.TextColor3 = T.Palette.hpLow
		UI.play("error")
	end
end

capContratoBtn.Activated:Connect(function()
	if not capContratoBtn:GetAttribute("Disabled") then
		doCapture("SeloContrato")
	end
end)
capSuperiorBtn.Activated:Connect(function()
	if not capSuperiorBtn:GetAttribute("Disabled") then
		doCapture("SeloSuperior")
	end
end)

exitRaidBtn.Activated:Connect(function()
	RaidActionRF:InvokeServer("ExitRaid")
	resultWin.Close()
end)

--------------------------------------------------------------------
-- RECEPCAO DE EVENTOS DO SERVIDOR (RaidState)
--------------------------------------------------------------------
local function allLivingAllyModels(): { Model }
	local out = {}
	if activeRaid and activeRaid.AllyModels then
		for i = 1, 4 do
			local m = activeRaid.AllyModels["Slot" .. i]
			if m and m.Parent then
				table.insert(out, m)
			end
		end
	end
	return out
end

RaidStateRE.OnClientEvent:Connect(function(kind: string, payload: any)
	if kind == "GlobalStatus" then
		globalStatus = payload
		lastStatusAt = os.clock()
		refreshHudBanner()
		if lobbyWin.Root.Visible then
			refreshLobbyWindow()
		end
	elseif kind == "OpenPanel" then
		globalStatus = payload
		lastStatusAt = os.clock()
		lobbyMsgLbl.Text = ""
		refreshLobbyWindow()
		lobbyWin.Open()
		task.defer(layoutLobbyRight)
	elseif kind == "LobbyUpdate" then
		if globalStatus then
			globalStatus.Lobby = payload
			lastStatusAt = os.clock()
			if lobbyWin.Root.Visible then
				refreshLobbyWindow()
			end
		end
	elseif kind == "LobbyClosed" then
		if globalStatus then
			globalStatus.Lobby = nil
		end
		if payload and payload.Message then
			lobbyMsgLbl.Text = payload.Message
		end
		if lobbyWin.Root.Visible then
			refreshLobbyWindow()
		end
	elseif kind == "BattleStart" then
		lobbyWin.Close()
		resultWin.Close()
		UI.closeAllWindows()
		activeRaid = {
			RaidId = payload.RaidId,
			Stars = payload.Stars,
			BossId = payload.BossId,
			Camera = payload.Camera,
			BossModel = payload.BossModel,
			AllyModels = payload.AllyModels or {},
			MySlot = payload.MySlot,
			State = payload.State,
			TurnEndsAt = os.clock() + Raids.TurnTimer,
			MoveSent = false,
			ReadySlots = {},
		}
		setInRaidBattle(true)
		setBattleCamera(payload.Camera)
		battleRoot.Visible = true
		hudBannerBtn.Visible = false
		logText.Text = string.format("RAID %d ESTRELAS INICIADA! Derrote %s em at\u{e9} 10 turnos!", payload.Stars or 3, payload.State.Boss.Name)
		refreshBattleHud()
		UI.play("open")
	elseif kind == "TurnPrompt" then
		if not activeRaid or activeRaid.RaidId ~= payload.RaidId then
			return
		end
		activeRaid.State = payload.State
		activeRaid.TurnEndsAt = os.clock() + (payload.TurnDuration or Raids.TurnTimer)
		activeRaid.MoveSent = false
		activeRaid.ReadySlots = {}
		local mySlot = activeRaid.State.Slots[activeRaid.MySlot]
		if mySlot and mySlot.Out then
			logText.Text = "Voc\u{ea} esgotou suas 2 vidas. Assistindo o restante do grupo..."
		elseif mySlot and (mySlot.Hp or 0) <= 0 then
			logText.Text = string.format("Aguardando reviver (%d turno(s))...", mySlot.RespawnIn or 2)
		else
			logText.Text = "Escolha 1 dos seus 4 golpes antes do tempo zerar!"
		end
		refreshBattleHud()
	elseif kind == "SlotReady" then
		if activeRaid and activeRaid.RaidId == payload.RaidId and payload.Slot then
			activeRaid.ReadySlots = activeRaid.ReadySlots or {}
			activeRaid.ReadySlots[payload.Slot] = true
			refreshBattleHud()
		end
	elseif kind == "BattleEvent" then
		if not activeRaid or activeRaid.RaidId ~= payload.RaidId then
			return
		end
		local ev = payload.Event
		if not ev then
			return
		end
		if ev.Kind == "Move" then
			logText.Text = string.format("%s usou %s!", ev.ActorName or "?", ev.MoveName or ev.MoveId)
			-- Dispara animacao e VFX fluidos reais no cliente (sem travar turno se algo falhar)
			task.spawn(function()
				pcall(function()
					if ev.ActorKind == "Ally" then
						local aModel = activeRaid.AllyModels["Slot" .. tostring(ev.Slot)]
						local target = if ev.TargetKind == "Ally" then aModel else activeRaid.BossModel
						if aModel and target then
							VfxController.PlayMove(ev.MoveId, aModel, target, { target })
						end
					elseif ev.ActorKind == "Boss" then
						local bModel = activeRaid.BossModel
						if bModel then
							local tList = {}
							for _, sIdx in ipairs(ev.TargetSlots or {}) do
								local am = activeRaid.AllyModels["Slot" .. tostring(sIdx)]
								if am and am.Parent then
									table.insert(tList, am)
								end
							end
							if #tList == 0 then
								tList = allLivingAllyModels()
							end
							if #tList > 0 then
								VfxController.PlayMove(ev.MoveId, bModel, tList[1], tList)
							end
						end
					end
				end)
			end)
		elseif ev.Kind == "Damage" then
			if ev.TargetKind == "Boss" then
				activeRaid.State.Boss.Hp = ev.Hp
				if ev.AttackerSlot and activeRaid.State.Slots[ev.AttackerSlot] then
					activeRaid.State.Slots[ev.AttackerSlot].TotalDamage = (activeRaid.State.Slots[ev.AttackerSlot].TotalDamage or 0) + (ev.Amount or 0)
				end
				local extra = (if ev.Crit then " CRITICO!" else "") .. (if (ev.Eff or 1) > 1 then " SUPER EFETIVO!" else "")
				logText.Text = string.format("Boss sofreu %d de dano!%s", ev.Amount or 0, extra)
				if ev.Crit then
					pcall(VfxController.CritFlash)
				end
			elseif ev.TargetKind == "Ally" and ev.Slot and activeRaid.State.Slots[ev.Slot] then
				activeRaid.State.Slots[ev.Slot].Hp = ev.Hp
				logText.Text = string.format("%s sofreu %d de dano!", activeRaid.State.Slots[ev.Slot].Name, ev.Amount or 0)
			end
			refreshBattleHud()
		elseif ev.Kind == "ShieldUp" then
			activeRaid.State.Boss.Shield = ev.Shield
			activeRaid.State.Boss.MaxShield = ev.MaxShield
			logText.Text = ev.Text or "O Boss ergueu um Escudo de Fase!"
			UI.play("open")
			refreshBattleHud()
		elseif ev.Kind == "ShieldHit" then
			activeRaid.State.Boss.Shield = ev.Shield
			refreshBattleHud()
		elseif ev.Kind == "ShieldBreak" then
			activeRaid.State.Boss.Shield = 0
			activeRaid.State.Boss.Stunned = true
			activeRaid.State.Boss.Hp = ev.Hp
			logText.Text = ev.Text or "ESCUDO QUEBRADO! Boss atordoado!"
			pcall(VfxController.CritFlash)
			UI.play("reward")
			refreshBattleHud()
		elseif ev.Kind == "PhasePulse" then
			logText.Text = ev.Text or "Pulso de Anulacao do Boss!"
			UI.play("error")
		elseif ev.Kind == "BossStunned" then
			activeRaid.State.Boss.Stunned = false
			logText.Text = ev.Text or "Boss atordoado!"
			refreshBattleHud()
		elseif ev.Kind == "AllyFaint" and ev.Slot and activeRaid.State.Slots[ev.Slot] then
			local s = activeRaid.State.Slots[ev.Slot]
			s.Hp = 0
			s.Lives = ev.Lives
			s.RespawnIn = ev.RespawnIn
			s.Out = ev.Out
			logText.Text = if ev.Out
				then (ev.Name .. " esgotou suas 2 vidas!")
				else string.format("%s desmaiou! Volta em %d turnos.", ev.Name, ev.RespawnIn or 2)
			refreshBattleHud()
		elseif ev.Kind == "AllyRevive" and ev.Slot and activeRaid.State.Slots[ev.Slot] then
			local s = activeRaid.State.Slots[ev.Slot]
			s.Hp = ev.Hp
			s.RespawnIn = 0
			logText.Text = ev.Name .. " reviveu e voltou ao combate!"
			UI.play("reward")
			refreshBattleHud()
		elseif ev.Text then
			logText.Text = ev.Text
		end
	elseif kind == "StateSync" then
		if activeRaid and activeRaid.RaidId == payload.RaidId then
			activeRaid.State = payload.State
			refreshBattleHud()
		end
	elseif kind == "BattleVictory" then
		battleRoot.Visible = false
		lastVictoryPayload = payload
		resultWin.Title.Text = "VITORIA NA RAID!"
		populateResultRanking(payload.Ranking, payload.MvpSlot)
		if payload.AlreadyClaimed then
			resultSummaryLbl.Text = "Voc\u{ea} j\u{e1} recebeu a recompensa desta janela hor\u{e1}ria. Obrigado por ajudar o grupo!"
			capTitleLbl.Text = "CAPTURA JA USADA NESTA HORA"
			capDescLbl.Text = "Cada jogador pode tentar capturar 1 vez por Raid hor\u{e1}ria."
			capFeedbackLbl.Text = ""
		else
			local rw = payload.Rewards or {}
			resultSummaryLbl.Text = string.format(
				"%s+%s Gold | +%d XP Conta | +%d XP Lutador | +%d de cada Min\u{e9}rio de Treino",
				if rw.IsMvp then "[MVP +25%] " else "",
				UI.fmt(rw.Gold or 0),
				rw.AccountXp or 0,
				rw.CharXp or 0,
				rw.OrePerStat or 0
			)
			capTitleLbl.Text = "CAPTURAR " .. string.upper(payload.BossName or "BOSS")
			capDescLbl.Text = if payload.SuperiorOnly
				then "Use 1 Selo Superior da mochila para tentar capturar este Boss!"
				else "Escolha um Selo da mochila para tentar capturar o Boss derrotado!"
			capFeedbackLbl.Text = ""
		end
		capPanel.Visible = true
		updateCaptureButtons(payload)
		resultWin.Open()
		task.defer(layoutCapturePanel)
		UI.play("reward")
	elseif kind == "BattleDefeat" then
		battleRoot.Visible = false
		lastVictoryPayload = nil
		resultWin.Title.Text = "RAID FRACASSADA"
		resultSummaryLbl.Text = if payload.Reason == "TurnLimit"
			then "Limite de 10 turnos atingido! Voc\u{ea} pode tentar novamente enquanto a Raid estiver aberta."
			else "Todos os jogadores esgotaram suas 2 vidas! Tente novamente com o grupo."
		populateResultRanking(payload.Ranking, payload.MvpSlot)
		capPanel.Visible = false
		resultWin.Open()
		UI.play("error")
	elseif kind == "RaidClosed" then
		battleRoot.Visible = false
		resultWin.Close()
		activeRaid = nil
		lastVictoryPayload = nil
		pcall(VfxController.Cleanup)
		setBattleCamera(nil)
		setInRaidBattle(false)
		refreshHudBanner()
	end
end)

--------------------------------------------------------------------
-- LOOP DE RELÓGIO / TIMERS (0.5s) E PERFIL
--------------------------------------------------------------------
ProfileUpdatedRE.OnClientEvent:Connect(function(p)
	profile = p
	refreshHudBanner()
end)

pg:GetAttributeChangedSignal("InBattle"):Connect(refreshHudBanner)

task.spawn(function()
	local ok, p = pcall(GetProfileRF.InvokeServer, GetProfileRF)
	if ok and p then
		profile = p
	end
	local sOk, res = pcall(RaidActionRF.InvokeServer, RaidActionRF, "GetStatus")
	if sOk and res and res.Ok and res.Data then
		globalStatus = res.Data
		lastStatusAt = os.clock()
	end
	refreshHudBanner()
end)

task.spawn(function()
	while true do
		task.wait(0.5)
		refreshHudBanner()
		if lobbyWin.Root.Visible and globalStatus then
			refreshLobbyWindow()
		end
		if activeRaid and battleRoot.Visible then
			local left = math.max(0, math.ceil((activeRaid.TurnEndsAt or 0) - os.clock()))
			bTopTimer.Text = tostring(left) .. "s"
			bTopTimer.TextColor3 = if left <= 5 then T.Palette.hpLow else T.Palette.gold
		end
	end
end)
