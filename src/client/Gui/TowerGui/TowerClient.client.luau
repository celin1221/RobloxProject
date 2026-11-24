--[[
	TowerClient (Torre 1x1 & 2x2, Ginasios de Anime com Insignias e Modo Treino)
	- Aba TORRE: seletor 1x1 / 2x2 com progresso e placares da temporada do Infinito independentes.
	- Aba GINASIOS: Porta-Insignias + 3 Ginasios de Anime (mini-trilha de 3 lutas em 1x1 ou 2x2)
	  que concedem Insignias e desbloqueiam os respectivos banners no Portal de Invocacao.
	- Aba TREINO: simulador livre (1x1 ou 2x2, IA Facil/Medio/Dificil, Nivel 50 igualado ou Nivel Real)
	  sem alterar HP, PP, itens, XP ou gold do perfil.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local gui = script.Parent
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Data = ReplicatedStorage:WaitForChild("Data")
local Tower = require(Data:WaitForChild("Tower"))
local Gyms = require(Data:WaitForChild("Gyms"))
local Items = require(Data:WaitForChild("Items"))
local UI = require(ReplicatedStorage:WaitForChild("UI"))
local T = UI.Theme

local MODE_COLOR = { Facil = "green", Medio = "orange", Dificil = "red", Infinito = "purple" }

local canvas = UI.screen(gui)
gui.DisplayOrder = 8
local win = UI.window(canvas, {
	Name = "TowerWindow",
	Title = "TORRE DE BATALHA",
	Icon = "tower",
	HeaderColor = "purple",
	Size = UDim2.fromScale(0.94, 0.88),
	Aspect = 1.9,
	OnClose = function()
		Remotes.TowerClose:FireServer()
	end,
})
local body = win.Body
local msg = UI.text(body, "", {
	Name = "Message",
	Size = UDim2.fromScale(1, 0.065),
	Position = UDim2.fromScale(0, 0.935),
	Role = "Small",
	Color = "hpLow",
	AlignX = Enum.TextXAlignment.Left,
})
local content = UI.frame(body, { Name = "Content", Size = UDim2.fromScale(1, 0.78), Position = UDim2.fromScale(0, 0.14) })

-- Estado compartilhado da tela
local currentMainTab = "Torre"
local towerFormat = "1x1"
local gymFormat = "1x1"
local boardScope = "Server" -- "Server" | "Global"
local latestInfo = nil
local boardByFormat = { ["1x1"] = nil, ["2x2"] = nil, ["PvP"] = nil }

local practiceFormat = "1x1"
local practiceAI = "Medio"
local practiceLevel = "Equal50"

local function setError(text: string?)
	msg.TextColor3 = T.Palette.hpLow
	msg.Text = text or "N\u{e3}o foi poss\u{ed}vel iniciar."
	UI.play("error")
end

local function rewardText(m): string
	if m.Battles == nil then
		return string.format("%d gold/andar, +%d a cada %d", m.GoldPerFloor, m.BonusGold, m.BonusEvery)
	end
	local parts = { m.Reward.Gold .. " gold" }
	for _, id in ipairs(m.Reward.Items) do
		local item = Items.Get(id)
		table.insert(parts, if item then item.Name else id)
	end
	if m.Reward.DailyGems then
		table.insert(parts, m.Reward.DailyGems .. " gemas/dia")
	end
	return table.concat(parts, ", ")
end

local function gymRewardText(gym, cleared: boolean): string
	if cleared then
		local r = gym.RepeatReward or {}
		return string.format("%d gold (revanche)", r.Gold or 150)
	end
	local r = gym.FirstReward or {}
	local parts = {}
	if r.Gold and r.Gold > 0 then
		table.insert(parts, r.Gold .. " gold")
	end
	if r.Gems and r.Gems > 0 then
		table.insert(parts, r.Gems .. " gemas")
	end
	for _, itemId in ipairs(r.Items or {}) do
		local item = Items.Get(itemId)
		table.insert(parts, if item then item.Name else itemId)
	end
	table.insert(parts, gym.BadgeName)
	return table.concat(parts, " + ")
end

--------------------------------------------------------------------
-- Paginas das 3 abas principais
--------------------------------------------------------------------
local torrePage = UI.frame(content, { Name = "Page_Torre", Size = UDim2.fromScale(1, 1), Visible = true })
local ginasiosPage = UI.frame(content, { Name = "Page_Ginasios", Size = UDim2.fromScale(1, 1), Visible = false })
local treinoPage = UI.frame(content, { Name = "Page_Treino", Size = UDim2.fromScale(1, 1), Visible = false })

local pages = {
	Torre = torrePage,
	Ginasios = ginasiosPage,
	Treino = treinoPage,
}

--------------------------------------------------------------------
-- ABA 1: TORRE (1x1 e 2x2 + Placar do Infinito separado)
--------------------------------------------------------------------
local leftCol = UI.frame(torrePage, { Name = "LeftCol", Size = UDim2.fromScale(0.64, 1) })
local towerFmtSelected
local fetchBoard
local refreshTowerView

local selectTowerFormat = UI.tabs(leftCol, {
	{ Id = "1x1", Text = "1x1 CL\u{c1}SSICO" },
	{ Id = "2x2", Text = "2x2 EM DUPLA" },
}, { Size = UDim2.fromScale(1, 0.14), MaxHeight = 46, MaxWidth = 0.49, ActiveColor = "orange" }, function(id)
	towerFormat = id
	msg.Text = ""
	if refreshTowerView then
		refreshTowerView()
	end
	if fetchBoard then
		fetchBoard(id)
	end
end)
local towerFmtBar = leftCol:FindFirstChild("Tabs")

local modesScroll = UI.scroll(leftCol, { Name = "Modes", Size = UDim2.fromScale(1, 0.82), Gap = 0.02 })
UI.fillBetween(modesScroll, towerFmtBar, nil, 6)

local modeRows = {}
for i, id in ipairs(Tower.Order) do
	local m = Tower.Modes[id]
	local row, face = UI.panel(modesScroll, {
		Name = "Row_" .. id,
		Size = UDim2.fromScale(1, 0),
		Aspect = 5.4,
		RowMax = 88,
		Color = "panelAlt",
		Corner = 0.2,
		LayoutOrder = i,
	})
	UI.stroke(face, UI.pair(MODE_COLOR[id]), 1.2)
	UI.text(face, UI.upper(m.Name), {
		Name = "Name",
		Size = UDim2.fromScale(0.55, 0.34),
		Position = UDim2.fromScale(0.03, 0.06),
		Role = "Heading",
		Color = select(2, UI.pair(MODE_COLOR[id])),
		AlignX = Enum.TextXAlignment.Left,
	})
	local infoLabel = UI.text(face, "", {
		Name = "Info",
		Size = UDim2.fromScale(0.69, 0.25),
		Position = UDim2.fromScale(0.03, 0.42),
		Role = "Small",
		Color = "inkSoft",
		AlignX = Enum.TextXAlignment.Left,
		StrokeMult = 0.4,
	})
	UI.icon(face, "trophy", { Size = UDim2.fromScale(0.04, 0.25), Position = UDim2.fromScale(0.03, 0.70) })
	UI.text(face, rewardText(m), {
		Name = "Reward",
		Size = UDim2.fromScale(0.64, 0.24),
		Position = UDim2.fromScale(0.08, 0.71),
		Role = "Small",
		Color = "gold",
		AlignX = Enum.TextXAlignment.Left,
		StrokeMult = 0.5,
	})
	local b = UI.button(face, {
		Name = "Enter_" .. id,
		Text = "ENTRAR",
		Color = MODE_COLOR[id],
		Size = UDim2.fromScale(0.22, 0.68),
		Position = UDim2.fromScale(0.97, 0.5),
		AnchorPoint = Vector2.new(1, 0.5),
		Role = "Body",
		OnClick = function()
			if not modeRows[id].Open then
				setError("Conclua o modo anterior na Torre " .. towerFormat .. " para desbloquear.")
				return
			end
			msg.Text = ""
			local ok, err = Remotes.TowerStart:InvokeServer({ Kind = "Tower", Mode = id, Format = towerFormat })
			if ok then
				win.Close(true)
			else
				setError(err)
			end
		end,
	})
	local lockIcon = UI.icon(b.Face, "lock", {
		Name = "Lock",
		Size = UDim2.fromScale(0.5, 0.78),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
	})
	modeRows[id] = { Button = b, Lock = lockIcon, Info = infoLabel, Open = false, Mode = m }
end

-- Placar da temporada do Infinito (independente para 1x1 e 2x2)
local board, boardFace = UI.panel(torrePage, {
	Name = "Board",
	Size = UDim2.fromScale(0.34, 1),
	Position = UDim2.fromScale(0.66, 0),
	Color = "slot",
	Corner = 0.06,
	Shadow = false,
})
local boardTitle = UI.text(boardFace, "Infinito 1x1", {
	Name = "Title",
	Size = UDim2.fromScale(0.92, 0.16),
	Position = UDim2.fromScale(0.04, 0.02),
	Role = "Small",
	AlignX = Enum.TextXAlignment.Left,
	Wrap = true,
})
local bestLabel = UI.text(boardFace, "", {
	Name = "Best",
	Size = UDim2.fromScale(0.92, 0.08),
	Position = UDim2.fromScale(0.04, 0.18),
	Role = "Small",
	Color = "inkSoft",
	AlignX = Enum.TextXAlignment.Left,
	StrokeMult = 0.4,
})
local listBox = UI.scroll(boardFace, { Name = "List", Size = UDim2.fromScale(0.94, 0.48), Position = UDim2.fromScale(0.03, 0.48), Gap = 0.015 })

local function renderBoard()
	UI.clear(listBox)
	if boardScope == "PvP" then
		local pvpData = boardByFormat.PvP
		local me = pvpData and pvpData.MyPvP
		if me then
			boardTitle.Text = string.format("Ranking PvP \u{b7} %s (%d ELO)", me.Tier or "Bronze", me.Rating or 1000)
			bestLabel.Text = string.format("Vit\u{f3}rias: %d (2x2: %d) \u{b7} B\u{f4}nus hoje: %d/%d", me.Wins or 0, me.Wins2x2 or 0, me.DailyRewards or 0, me.DailyCap or 3)
		else
			boardTitle.Text = "Ranking PvP (2x2 & 1x1)"
			bestLabel.Text = "Carregando patentes..."
		end
		local list = pvpData and (if #(pvpData.Global or {}) > 0 then pvpData.Global else pvpData.Server) or {}
		if #list == 0 then
			UI.text(listBox, "Ningu\u{e9}m no ranking PvP ainda.", {
				Name = "Empty",
				Size = UDim2.fromScale(1, 0),
				Aspect = 5.5,
				Role = "Small",
				Color = "inkSoft",
			})
			return
		end
		for i, e in ipairs(list) do
			local color = if i == 1 then "lendario" elseif i == 2 then "comum" elseif i == 3 then "orange" else "panelAlt"
			local _, f = UI.panel(listBox, {
				Name = "Entry" .. i,
				Size = UDim2.fromScale(1, 0),
				Aspect = 6,
				Color = color,
				Corner = T.Corner.Pill,
				Shadow = false,
				LayoutOrder = i,
			})
			UI.text(f, i .. ". " .. e.Name, { Name = "Name", Size = UDim2.fromScale(0.56, 0.72), Position = UDim2.fromScale(0.05, 0.14), Role = "Small", AlignX = Enum.TextXAlignment.Left })
			UI.text(f, string.format("%s %d", e.Tier or "", e.Rating or 1000), { Name = "Floor", Size = UDim2.fromScale(0.38, 0.72), Position = UDim2.fromScale(0.95, 0.14), AnchorPoint = Vector2.new(1, 0), Role = "Small", AlignX = Enum.TextXAlignment.Right })
		end
		return
	end

	local bData = boardByFormat[towerFormat]
	local list = bData and bData[boardScope] or {}
	if #list == 0 then
		UI.text(listBox, "Ningu\u{e9}m no placar " .. towerFormat .. " ainda.", {
			Name = "Empty",
			Size = UDim2.fromScale(1, 0),
			Aspect = 5.5,
			Role = "Small",
			Color = "inkSoft",
		})
		return
	end
	for i, e in ipairs(list) do
		local color = if i == 1 then "lendario" elseif i == 2 then "comum" elseif i == 3 then "orange" else "panelAlt"
		local _, f = UI.panel(listBox, {
			Name = "Entry" .. i,
			Size = UDim2.fromScale(1, 0),
			Aspect = 6,
			Color = color,
			Corner = T.Corner.Pill,
			Shadow = false,
			LayoutOrder = i,
		})
		UI.text(f, i .. ". " .. e.Name, { Name = "Name", Size = UDim2.fromScale(0.62, 0.72), Position = UDim2.fromScale(0.05, 0.14), Role = "Small", AlignX = Enum.TextXAlignment.Left })
		UI.text(f, "andar " .. e.Floor, { Name = "Floor", Size = UDim2.fromScale(0.32, 0.72), Position = UDim2.fromScale(0.95, 0.14), AnchorPoint = Vector2.new(1, 0), Role = "Small", AlignX = Enum.TextXAlignment.Right })
	end
end

local selectBoardScope = UI.tabs(boardFace, {
	{ Id = "Server", Text = "SERV." },
	{ Id = "Global", Text = "GLOBAL" },
	{ Id = "PvP", Text = "PVP" },
}, { Size = UDim2.fromScale(0.92, 0.16), Position = UDim2.fromScale(0.04, 0.27), MaxHeight = 44, MaxWidth = 0.32, ActiveColor = "purple" }, function(id)
	boardScope = id
	if id == "PvP" and fetchBoard then
		fetchBoard("PvP")
	end
	if refreshTowerView then
		refreshTowerView()
	else
		renderBoard()
	end
end)
UI.fillBetween(listBox, boardFace:FindFirstChild("Tabs"), nil, 6)

refreshTowerView = function()
	local slot = nil
	if latestInfo then
		slot = if towerFormat == "2x2" then latestInfo.Tower2x2 else latestInfo.Tower1x1
	end
	local unlocked = (slot and slot.Unlocked) or (latestInfo and latestInfo.Unlocked) or "Facil"
	local bestFloor = (slot and slot.BestFloor) or (latestInfo and latestInfo.BestFloor) or 0
	local seasonBest = (slot and slot.SeasonBest) or (latestInfo and latestInfo.SeasonBest) or 0

	if boardScope ~= "PvP" then
		if latestInfo and latestInfo.Season then
			local days = math.max(0, math.ceil(((latestInfo.SeasonEnd or 0) - (os.time() + (ReplicatedStorage:GetAttribute("RetentionOffset") or 0))) / 86400))
			boardTitle.Text = string.format("Infinito %s \u{b7} Temp. %s \u{b7} %d dia%s", towerFormat, tostring(latestInfo.Season), days, if days == 1 then "" else "s")
			bestLabel.Text = string.format("Temp.: %d \u{b7} Recorde %s: %d", seasonBest, towerFormat, bestFloor)
		else
			boardTitle.Text = "Placar do Infinito " .. towerFormat
			bestLabel.Text = string.format("Recorde %s: andar %d", towerFormat, bestFloor)
		end
	end

	local suffix2x2 = if towerFormat == "2x2" then " \u{b7} m\u{ed}n. 2 vivos" else ""
	for id, r in pairs(modeRows) do
		local m = r.Mode
		if m.Battles then
			r.Info.Text = string.format("%d lutas \u{b7} %d/NPC \u{b7} nv. %d-%d \u{b7} sem cura%s", m.Battles, m.TeamSize, m.MinLevel, m.MaxLevel, suffix2x2)
		else
			r.Info.Text = string.format("%d/NPC \u{b7} nv. %d +%d/andar \u{b7} cura 30%%%s", m.TeamSize, m.BaseLevel, m.LevelPerFloor, suffix2x2)
		end
		local open = Tower.IsUnlocked(unlocked, id)
		r.Open = open
		UI.setText(r.Button, if open then "ENTRAR" else "")
		local lbl = r.Button.Face:FindFirstChild("Label")
		if lbl then
			lbl.Visible = open
		end
		UI.setDisabled(r.Button, not open, MODE_COLOR[id])
		r.Lock.Visible = not open
	end
	renderBoard()
end

fetchBoard = function(format: string)
	task.spawn(function()
		local ok, data = pcall(function()
			return Remotes.TowerBoard:InvokeServer(format)
		end)
		if ok and data then
			boardByFormat[format] = data
			if data.Info then
				latestInfo = data.Info
			end
			if format == "PvP" and boardScope == "PvP" then
				renderBoard()
			elseif towerFormat == format then
				refreshTowerView()
			end
		end
	end)
end

--------------------------------------------------------------------
-- ABA 2: GINASIOS DE ANIME (Porta-Insignias + 3 Ginasios)
--------------------------------------------------------------------
local gymTopBar = UI.frame(ginasiosPage, { Name = "GymTopBar", Size = UDim2.fromScale(1, 0.16) })
UI.clampHeight(gymTopBar, 46, 56)

local gymFmtWrap = UI.frame(gymTopBar, { Name = "FmtWrap", Size = UDim2.fromScale(0.36, 1) })
local selectGymFormat = UI.tabs(gymFmtWrap, {
	{ Id = "1x1", Text = "1x1" },
	{ Id = "2x2", Text = "2x2" },
}, { Size = UDim2.fromScale(1, 1), MaxHeight = 52, MaxWidth = 0.49, ActiveColor = "orange" }, function(id)
	gymFormat = id
	msg.Text = ""
end)

local shelfPanel, shelfFace = UI.panel(gymTopBar, {
	Name = "BadgesShelf",
	Size = UDim2.fromScale(0.62, 1),
	Position = UDim2.fromScale(0.38, 0),
	Color = "slot",
	Corner = 0.24,
	Shadow = false,
})
local badgesTitle = UI.text(shelfFace, "INS\u{cd}GNIAS 0/3", {
	Name = "Title",
	Size = UDim2.fromScale(0.42, 0.78),
	Position = UDim2.fromScale(0.03, 0.11),
	Role = "Small",
	Color = "gold",
	AlignX = Enum.TextXAlignment.Left,
})
local badgesRow = UI.frame(shelfFace, { Name = "BadgesRow", Size = UDim2.fromScale(0.52, 0.86), Position = UDim2.fromScale(0.46, 0.07) })
do
	local hl = Instance.new("UIListLayout")
	hl.FillDirection = Enum.FillDirection.Horizontal
	hl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	hl.VerticalAlignment = Enum.VerticalAlignment.Center
	hl.Padding = UDim.new(0.04, 0)
	hl.SortOrder = Enum.SortOrder.LayoutOrder
	hl.Parent = badgesRow
end

local badgeSlots = {}
for idx, gymId in ipairs(Gyms.Order) do
	local gym = Gyms.List[gymId]
	local slot, slotFace = UI.panel(badgesRow, {
		Name = "Badge_" .. gymId,
		Size = UDim2.fromScale(0.28, 1),
		Aspect = 1,
		AspectAxis = Enum.DominantAxis.Height,
		Color = "panelAlt",
		Corner = 0.5,
		Shadow = false,
		LayoutOrder = idx,
	})
	local stroke = UI.stroke(slotFace, T.Palette.grey, 1.1)
	local img = UI.icon(slotFace, gym.BadgeIcon, {
		Name = "Icon",
		Size = UDim2.fromScale(0.84, 0.84),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
	})
	local lock = UI.icon(slotFace, "lock", {
		Name = "Lock",
		Size = UDim2.fromScale(0.45, 0.45),
		Position = UDim2.fromScale(0.86, 0.86),
		AnchorPoint = Vector2.new(1, 1),
		ZIndex = 3,
	})
	local tick = UI.icon(slotFace, "tick", {
		Name = "Tick",
		Size = UDim2.fromScale(0.45, 0.45),
		Position = UDim2.fromScale(0.92, 0.92),
		AnchorPoint = Vector2.new(1, 1),
		Visible = false,
		ZIndex = 3,
	})
	badgeSlots[gymId] = { Frame = slot, Stroke = stroke, Icon = img, Lock = lock, Tick = tick, Gym = gym }
end

local gymsScroll = UI.scroll(ginasiosPage, { Name = "GymsList", Size = UDim2.fromScale(1, 0.8), Gap = 0.025 })
UI.fillBetween(gymsScroll, gymTopBar, nil, 6)

local gymCards = {}
for idx, gymId in ipairs(Gyms.Order) do
	local gym = Gyms.List[gymId]
	local card, face = UI.panel(gymsScroll, {
		Name = "Gym_" .. gymId,
		Size = UDim2.fromScale(1, 0),
		Aspect = 5.4,
		RowMax = 104,
		Color = "panelAlt",
		Corner = 0.18,
		LayoutOrder = idx,
	})
	UI.stroke(face, gym.Accent or UI.pair(gym.Color), 1.3)

	-- Emblema da insignia a esquerda
	local emblem, emblemFace = UI.panel(face, {
		Name = "Emblem",
		Size = UDim2.fromScale(0.11, 0.82),
		Position = UDim2.fromScale(0.02, 0.5),
		AnchorPoint = Vector2.new(0, 0.5),
		Aspect = 1,
		AspectAxis = Enum.DominantAxis.Height,
		Color = "slot",
		Corner = 0.5,
		Shadow = false,
	})
	local emblemIcon = UI.icon(emblemFace, gym.BadgeIcon, {
		Name = "Badge",
		Size = UDim2.fromScale(0.86, 0.86),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
	})

	-- Informacoes centrais
	UI.text(face, UI.upper(gym.Name), {
		Name = "Title",
		Size = UDim2.fromScale(0.42, 0.30),
		Position = UDim2.fromScale(0.145, 0.07),
		Role = "Heading",
		Color = gym.Accent or "onDark",
		AlignX = Enum.TextXAlignment.Left,
	})
	local statusChip = UI.chip(face, "TRANCADO", "grey", {
		Name = "BannerChip",
		Size = UDim2.fromScale(0.195, 0.25),
		Position = UDim2.fromScale(0.575, 0.09),
	})
	local firstLvl = gym.Stages[1] and gym.Stages[1].Level or 12
	local lastLvl = gym.Stages[#gym.Stages] and gym.Stages[#gym.Stages].Level or gym.RecommendedLevel
	UI.text(
		face,
		string.format("3 lutas (2 / 4 / 6) \u{b7} L\u{ed}der: %s \u{b7} Nv. %d a %d", gym.LeaderName, firstLvl, lastLvl),
		{
			Name = "Trail",
			Size = UDim2.fromScale(0.62, 0.24),
			Position = UDim2.fromScale(0.145, 0.40),
			Role = "Small",
			Color = "inkSoft",
			AlignX = Enum.TextXAlignment.Left,
			StrokeMult = 0.4,
		}
	)
	UI.icon(face, "trophy", { Size = UDim2.fromScale(0.032, 0.24), Position = UDim2.fromScale(0.145, 0.69) })
	local rewardLbl = UI.text(face, gymRewardText(gym, false), {
		Name = "Reward",
		Size = UDim2.fromScale(0.58, 0.24),
		Position = UDim2.fromScale(0.185, 0.69),
		Role = "Small",
		Color = "gold",
		AlignX = Enum.TextXAlignment.Left,
		StrokeMult = 0.45,
	})

	local challengeBtn = UI.button(face, {
		Name = "Challenge_" .. gymId,
		Text = "DESAFIAR",
		Color = gym.Color or "orange",
		Size = UDim2.fromScale(0.19, 0.68),
		Position = UDim2.fromScale(0.98, 0.5),
		AnchorPoint = Vector2.new(1, 0.5),
		Role = "Body",
		OnClick = function()
			msg.Text = ""
			local ok, err = Remotes.TowerStart:InvokeServer({ Kind = "Gym", GymId = gym.Id, Format = gymFormat })
			if ok then
				win.Close(true)
			else
				setError(err)
			end
		end,
	})

	gymCards[gymId] = {
		Gym = gym,
		EmblemIcon = emblemIcon,
		StatusChip = statusChip,
		RewardLabel = rewardLbl,
		Button = challengeBtn,
	}
end

local function refreshGymsView()
	local clearedMap = (latestInfo and latestInfo.GymsCleared) or {}
	local bannersMap = (latestInfo and latestInfo.UnlockedBanners) or {}
	local count = 0

	for _, gymId in ipairs(Gyms.Order) do
		local cleared = clearedMap[gymId] == true
		if cleared then
			count += 1
		end
		local slot = badgeSlots[gymId]
		if slot then
			slot.Icon.ImageColor3 = if cleared then Color3.new(1, 1, 1) else Color3.fromRGB(115, 115, 130)
			slot.Icon.ImageTransparency = if cleared then 0 else 0.55
			slot.Stroke.Color = if cleared then T.Palette.gold else T.Palette.grey
			slot.Lock.Visible = not cleared
			slot.Tick.Visible = cleared
		end

		local card = gymCards[gymId]
		if card then
			local bannerOpen = bannersMap[card.Gym.Anime] == true
			card.EmblemIcon.ImageColor3 = if cleared then Color3.new(1, 1, 1) else Color3.fromRGB(130, 130, 145)
			card.EmblemIcon.ImageTransparency = if cleared then 0 else 0.4
			if cleared then
				card.StatusChip.Face.Label.Text = "CONQUISTADO"
				UI.paint(card.StatusChip, "green")
				UI.setText(card.Button, "REVANCHE")
			elseif bannerOpen then
				card.StatusChip.Face.Label.Text = "BANNER ABERTO"
				UI.paint(card.StatusChip, "blue")
				UI.setText(card.Button, "DESAFIAR")
			else
				card.StatusChip.Face.Label.Text = "LIBERA BANNER"
				UI.paint(card.StatusChip, "orange")
				UI.setText(card.Button, "DESAFIAR")
			end
			card.RewardLabel.Text = gymRewardText(card.Gym, cleared)
		end
	end
	badgesTitle.Text = string.format("INS\u{cd}GNIAS %d/%d", count, #Gyms.Order)
end

--------------------------------------------------------------------
-- ABA 3: MODO TREINO (Simulador livre 1x1 e 2x2)
--------------------------------------------------------------------
local startRow, startRowFace = UI.panel(treinoPage, {
	Name = "StartRow",
	Size = UDim2.fromScale(1, 0.18),
	Position = UDim2.fromScale(0, 1),
	AnchorPoint = Vector2.new(0, 1),
	Color = "slot",
	Corner = 0.22,
	Shadow = false,
})
UI.clampHeight(startRow, 48, 60)

local treinoScroll = UI.scroll(treinoPage, { Name = "TreinoScroll", Size = UDim2.fromScale(1, 0.78), Gap = 0.02 })
UI.fillBetween(treinoScroll, nil, startRow, 6)

do
	local _, f = UI.panel(treinoScroll, {
		Name = "TreinoInfo",
		Size = UDim2.fromScale(1, 0),
		Aspect = 13.5,
		RowMax = 44,
		Color = "slot",
		Corner = 0.24,
		Shadow = false,
		LayoutOrder = 1,
	})
	UI.text(f, "Simulador livre: entra com HP e PP cheios, sem gastar itens e sem alterar seu time salvo. Ideal para testar combos 1x1 e 2x2!", {
		Name = "Desc",
		Size = UDim2.fromScale(0.96, 0.84),
		Position = UDim2.fromScale(0.02, 0.08),
		Role = "Small",
		Color = "inkSoft",
		StrokeMult = 0.4,
	})
end

local summaryLabel
local function updatePracticeSummary()
	if not summaryLabel then
		return
	end
	local aiText = if practiceAI == "Facil" then "IA F\u{e1}cil" elseif practiceAI == "Dificil" then "IA Dif\u{ed}cil" else "IA M\u{e9}dio"
	local lvlText = if practiceLevel == "Equal50" then "N\u{ed}vel 50 (PvP)" else "N\u{ed}vel Real"
	summaryLabel.Text = string.format("Treino %s \u{b7} %s \u{b7} %s \u{b7} Fuga livre", practiceFormat, lvlText, aiText)
end

local function makeOptionRow(order: number, label: string, choices: { { Id: string, Text: string } }, activeColor: string, onPick: (string) -> ())
	local _, f = UI.panel(treinoScroll, {
		Name = "Opt_" .. order,
		Size = UDim2.fromScale(1, 0),
		Aspect = 8.5,
		RowMax = 60,
		Color = "panelAlt",
		Corner = 0.22,
		LayoutOrder = order,
	})
	UI.text(f, label, {
		Name = "Label",
		Size = UDim2.fromScale(0.24, 0.72),
		Position = UDim2.fromScale(0.03, 0.14),
		Role = "Body",
		Color = "gold",
		AlignX = Enum.TextXAlignment.Left,
	})
	local wrap = UI.frame(f, { Name = "Choices", Size = UDim2.fromScale(0.70, 0.88), Position = UDim2.fromScale(0.28, 0.06) })
	local maxW = math.min(0.48, (1 - 0.02 * (#choices - 1)) / #choices)
	local sel = UI.tabs(wrap, choices, {
		Size = UDim2.fromScale(1, 1),
		MaxHeight = 46,
		MaxWidth = maxW,
		ActiveColor = activeColor,
	}, function(id)
		onPick(id)
		updatePracticeSummary()
	end)
	return sel
end

local selectPracticeFmt = makeOptionRow(2, "FORMATO", {
	{ Id = "1x1", Text = "1x1 CL\u{c1}SSICO" },
	{ Id = "2x2", Text = "2x2 EM DUPLA" },
}, "orange", function(id)
	practiceFormat = id
end)

local selectPracticeLvl = makeOptionRow(3, "N\u{cd}VEL", {
	{ Id = "Equal50", Text = "NV. 50 (SIMULADOR PVP)" },
	{ Id = "Real", Text = "N\u{cd}VEL REAL" },
}, "blue", function(id)
	practiceLevel = id
end)

local selectPracticeAI = makeOptionRow(4, "DIFICULDADE", {
	{ Id = "Facil", Text = "F\u{c1}CIL" },
	{ Id = "Medio", Text = "M\u{c9}DIO" },
	{ Id = "Dificil", Text = "DIF\u{cd}CIL" },
}, "purple", function(id)
	practiceAI = id
end)

do
	summaryLabel = UI.text(startRowFace, "", {
		Name = "Summary",
		Size = UDim2.fromScale(0.62, 0.74),
		Position = UDim2.fromScale(0.03, 0.13),
		Role = "Body",
		Color = "onDark",
		AlignX = Enum.TextXAlignment.Left,
	})
	UI.button(startRowFace, {
		Name = "StartPractice",
		Text = "INICIAR TREINO",
		Icon = "sword",
		Layout = "row",
		Color = "green",
		Size = UDim2.fromScale(0.32, 0.82),
		Position = UDim2.fromScale(0.98, 0.5),
		AnchorPoint = Vector2.new(1, 0.5),
		Role = "Body",
		OnClick = function()
			msg.Text = ""
			local ok, err = Remotes.TowerStart:InvokeServer({
				Kind = "Practice",
				Format = practiceFormat,
				AI = practiceAI,
				LevelMode = practiceLevel,
			})
			if ok then
				win.Close(true)
			else
				setError(err)
			end
		end,
	})
end

--------------------------------------------------------------------
-- Barra de abas principais no topo
--------------------------------------------------------------------
local selectMainTab = UI.tabs(body, {
	{ Id = "Torre", Text = "TORRE", Icon = "tower" },
	{ Id = "Ginasios", Text = "GIN\u{c1}SIOS", Icon = "trophy" },
	{ Id = "Treino", Text = "TREINO", Icon = "sword" },
}, { Size = UDim2.fromScale(1, 0.12), MaxHeight = 48, MaxWidth = 0.32, ActiveColor = "purple" }, function(id)
	currentMainTab = id
	msg.Text = ""
	for pid, page in pairs(pages) do
		page.Visible = pid == id
	end
	if id == "Torre" then
		refreshTowerView()
		fetchBoard(towerFormat)
	elseif id == "Ginasios" then
		refreshGymsView()
	else
		updatePracticeSummary()
	end
end)
UI.fillBetween(content, body:FindFirstChild("Tabs"), msg, 6)

-- Inicializacao dos seletores internos
selectTowerFormat("1x1")
selectBoardScope("Server")
selectGymFormat("1x1")
selectPracticeFmt("1x1")
selectPracticeLvl("Equal50")
selectPracticeAI("Medio")
updatePracticeSummary()

local function applyInfo(info)
	if not info then
		return
	end
	latestInfo = info
	refreshTowerView()
	refreshGymsView()
end

local function open(info)
	if UI.inBattle() then
		return
	end
	msg.Text = ""
	applyInfo(info)
	win.Open()
	selectMainTab(currentMainTab)
	fetchBoard(towerFormat)
end

Remotes:WaitForChild("TowerOpen").OnClientEvent:Connect(open)
