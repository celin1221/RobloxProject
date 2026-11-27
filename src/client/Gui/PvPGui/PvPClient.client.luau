--[[
	PvPClient (Hub Arena PvP + Filas Competitiva/Casual 1x1 & 2x2 + Ranking Global + Duelo Amistoso na Praca)
	- Tema Midnight-Blue Anime (100% UI.Icons, ZERO emojis ou simbolos Unicode).
	- Abre pelo botao PVP no HUD (UI.open("PvP")) ou pelo Quadro 3D de Ranking na praca (PvPBoardPrompt, tecla E).
	- Aba FILAS: 4 filas oficiais (Competitivo 2x2, Competitivo 1x1, Casual 2x2, Casual 1x1), validacao ao vivo
	  das regras VGC (Species Clause + max. 1 Secreto e 2 Lendarios) e botao ENTRAR NA FILA / CANCELAR.
	- Aba RANKING: Top 10 Global e do Servidor separado para 2x2 e 1x1 + painel de Temporada Mensal com Gemas.
	- Barra flutuante de busca de partida no topo enquanto o jogador anda livre pela praca.
	- Duelo Amistoso por proximidade na praca (tecla F): poder real liberado (Casual), sem ELO.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local gui = script.Parent
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PvPRank = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("PvPRank"))
local UI = require(ReplicatedStorage:WaitForChild("UI"))
local T = UI.Theme

local myProfile = nil
local queueState = { InQueue = false }
local queueReceivedAt = os.clock()
local queueBusy = false
local boardFormat = "2x2"
local boardScope = "Global" -- "Global" | "Server"
local boardCache = { ["2x2"] = nil, ["1x1"] = nil }
local statusData = nil

local PLAZA_HALF_X, PLAZA_HALF_Z = 130, 90
local PROMPT_DISTANCE = 12

local function toast(text)
	if text and text ~= "" then
		UI.toast(text)
	end
end

local function fmtMmSs(secs: number): string
	secs = math.max(0, math.floor(secs))
	return string.format("%02d:%02d", secs // 60, secs % 60)
end

local function formatLabel(fmt: string?): string
	return if fmt == "2x2" then "AMISTOSO 2x2" else "AMISTOSO 1x1"
end

local function formatColor(fmt: string?): string
	return if fmt == "2x2" then "orange" else "blue"
end

local function myTeamMembers()
	if not myProfile or typeof(myProfile.Team) ~= "table" or typeof(myProfile.Collection) ~= "table" then
		return {}
	end
	local list = {}
	for _, uid in ipairs(myProfile.Team) do
		local m = myProfile.Collection[uid]
		if m then
			table.insert(list, m)
		end
	end
	return list
end

local canvas = UI.screen(gui)
gui.DisplayOrder = 12

--------------------------------------------------------------------
-- 1. BARRA FLUTUANTE DE BUSCA DE PARTIDA (topo, abaixo do banner de Raid)
--------------------------------------------------------------------
local queueBanner, queueBannerFace = UI.panel(canvas, {
	Name = "PvPQueueBanner",
	Color = "panel",
	Size = UDim2.fromScale(0.38, 0.068),
	Position = UDim2.fromScale(0.5, 0.148),
	AnchorPoint = Vector2.new(0.5, 0),
	Corner = T.Corner.Pill,
	MaxSize = Vector2.new(420, 42),
	MinSize = Vector2.new(260, 36),
	Visible = false,
	ZIndex = 18,
})
local queueBannerStroke = UI.stroke(queueBannerFace, T.Palette.gold, 1.3)
UI.icon(queueBannerFace, "sword", {
	Name = "Icon",
	Size = UDim2.fromScale(0.09, 0.70),
	Position = UDim2.fromScale(0.035, 0.5),
	AnchorPoint = Vector2.new(0, 0.5),
	AspectAxis = Enum.DominantAxis.Height,
	ZIndex = 19,
})
local queueBannerText = UI.text(queueBannerFace, "BUSCANDO PARTIDA...", {
	Name = "Status",
	Size = UDim2.fromScale(0.64, 0.78),
	Position = UDim2.fromScale(0.13, 0.11),
	Role = "Small",
	Color = "onDark",
	AlignX = Enum.TextXAlignment.Left,
	StrokeMult = 0.45,
	ZIndex = 19,
})
queueBannerText.TextWrapped = false
local queueLeaveBtn = UI.button(queueBannerFace, {
	Name = "CancelQueue",
	Text = "SAIR",
	Color = "red",
	Size = UDim2.fromScale(0.20, 0.74),
	Position = UDim2.fromScale(0.975, 0.5),
	AnchorPoint = Vector2.new(1, 0.5),
	Corner = T.Corner.Pill,
	Role = "Small",
	ZIndex = 20,
})
local leaveMin = queueLeaveBtn:FindFirstChildOfClass("UISizeConstraint")
if leaveMin then
	leaveMin.MinSize = Vector2.new(64, 30)
end

--------------------------------------------------------------------
-- 2. JANELA PRINCIPAL: HUB ARENA PVP (Abas FILAS e RANKING)
--------------------------------------------------------------------
local hubWin = UI.window(canvas, {
	Name = "PvPWindow",
	Title = "ARENA PVP",
	Icon = "sword",
	HeaderColor = "red",
	Size = UDim2.fromScale(0.94, 0.88),
	Aspect = 1.9,
})
local hubBody = hubWin.Body
local hubMsg = UI.text(hubBody, "", {
	Name = "Message",
	Size = UDim2.fromScale(1, 0.06),
	Position = UDim2.fromScale(0, 0.94),
	Role = "Small",
	Color = "hpLow",
	AlignX = Enum.TextXAlignment.Left,
})
local hubContent = UI.frame(hubBody, {
	Name = "Content",
	Size = UDim2.fromScale(1, 0.79),
	Position = UDim2.fromScale(0, 0.135),
})

local filasPage = UI.frame(hubContent, { Name = "Page_Filas", Size = UDim2.fromScale(1, 1), Visible = true })
local rankingPage = UI.frame(hubContent, { Name = "Page_Ranking", Size = UDim2.fromScale(1, 1), Visible = false })

local currentHubTab = "Filas"
local refreshHubView
local fetchLeaderboard
local fetchStatus

local selectHubTab = UI.tabs(hubBody, {
	{ Id = "Filas", Text = "FILAS PVP", Icon = "sword" },
	{ Id = "Ranking", Text = "RANKING GLOBAL", Icon = "trophy" },
}, { Size = UDim2.fromScale(1, 0.115), MaxHeight = 46, MaxWidth = 0.49, ActiveColor = "red" }, function(id)
	currentHubTab = id
	filasPage.Visible = id == "Filas"
	rankingPage.Visible = id == "Ranking"
	hubMsg.Text = ""
	if id == "Ranking" and fetchLeaderboard then
		fetchLeaderboard(boardFormat)
	elseif id == "Filas" and fetchStatus then
		fetchStatus()
	end
end)

--------------------------------------------------------------------
-- 2A. ABA FILAS: Resumo ELO + Grid 2x2 das 4 Filas Oficiais
--------------------------------------------------------------------
local summaryBar, summaryFace = UI.panel(filasPage, {
	Name = "SummaryBar",
	Size = UDim2.fromScale(1, 0.145),
	Position = UDim2.fromScale(0, 0),
	Color = "slot",
	Corner = 0.24,
	Shadow = false,
})
UI.icon(summaryFace, "trophy", {
	Name = "TrophyIcon",
	Size = UDim2.fromScale(0.055, 0.72),
	Position = UDim2.fromScale(0.018, 0.5),
	AnchorPoint = Vector2.new(0, 0.5),
	AspectAxis = Enum.DominantAxis.Height,
})
local summaryMain = UI.text(summaryFace, "ELO 2x2: 1000 (Bronze)  |  ELO 1x1: 1000 (Bronze)", {
	Name = "SummaryMain",
	Size = UDim2.fromScale(0.62, 0.54),
	Position = UDim2.fromScale(0.08, 0.08),
	Role = "Body",
	Color = "gold",
	AlignX = Enum.TextXAlignment.Left,
})
local summarySub = UI.text(summaryFace, "B\u{f4}nus di\u{e1}rio: 0/3 vit\u{f3}rias  |  Ranqueada: Nv. 50 e BST normalizado", {
	Name = "SummarySub",
	Size = UDim2.fromScale(0.62, 0.36),
	Position = UDim2.fromScale(0.08, 0.58),
	Role = "Small",
	Color = "inkSoft",
	AlignX = Enum.TextXAlignment.Left,
	StrokeMult = 0.4,
})
local summarySeason = UI.text(summaryFace, "TEMPORADA", {
	Name = "SummarySeason",
	Size = UDim2.fromScale(0.28, 0.72),
	Position = UDim2.fromScale(0.98, 0.14),
	AnchorPoint = Vector2.new(1, 0),
	Role = "Small",
	Color = "onDark",
	AlignX = Enum.TextXAlignment.Right,
	StrokeMult = 0.45,
})

local gridWrap = UI.frame(filasPage, {
	Name = "QueueGrid",
	Size = UDim2.fromScale(1, 0.755),
	Position = UDim2.fromScale(0, 0.165),
})

local queueCards = {}

-- InvokeServer retorna (ok, dataOrErr), capturamos ambos os retornos com seguranca
local function invokeQueue(action: string, arg)
	local queueRF = Remotes:FindFirstChild("PvPQueue")
	if not queueRF then
		return false, "Fila PvP indispon\u{ed}vel."
	end
	local callOk, srvOk, srvRes = pcall(function()
		return queueRF:InvokeServer(action, arg)
	end)
	if not callOk then
		return false, "Erro de conex\u{e3}o com o servidor."
	end
	return srvOk == true, srvRes
end

local function toggleQueue(queueId: string)
	if queueBusy then
		return
	end
	queueBusy = true
	hubMsg.Text = ""
	local leavingSame = queueState.InQueue and queueState.QueueId == queueId
	local ok, res = invokeQueue(if leavingSame then "Leave" else "Join", queueId)
	queueBusy = false
	if not ok then
		hubMsg.Text = tostring(res or "N\u{e3}o foi poss\u{ed}vel entrar na fila.")
		UI.play("error")
	elseif leavingSame then
		queueState = { InQueue = false }
		UI.play("click")
	elseif typeof(res) == "table" then
		queueState = res
		queueReceivedAt = os.clock()
		UI.play("open")
		toast("Buscando " .. (res.Title or queueId) .. "!")
	end
	if refreshHubView then
		refreshHubView()
	end
end

for idx, qid in ipairs(PvPRank.QueueOrder) do
	local q = PvPRank.Queues[qid]
	local col = (idx - 1) % 2
	local row = (idx - 1) // 2
	local accentColor = select(2, UI.pair(q.Color))
	local card, face = UI.panel(gridWrap, {
		Name = "Card_" .. qid,
		Size = UDim2.fromScale(0.49, 0.48),
		Position = UDim2.fromScale(col * 0.51, row * 0.52),
		Color = "panelAlt",
		Corner = 0.12,
		Shadow = false,
		StrokeColor = accentColor,
		StrokeMult = 0.9,
	})
	local bar = Instance.new("Frame")
	bar.Name = "Accent"
	bar.Size = UDim2.new(0, 6, 0.78, 0)
	bar.Position = UDim2.new(0, 8, 0.5, 0)
	bar.AnchorPoint = Vector2.new(0, 0.5)
	bar.BackgroundColor3 = accentColor
	bar.BorderSizePixel = 0
	bar.Parent = face
	UI.corner(bar, 0.5)

	UI.text(face, q.Title, {
		Name = "Title",
		Size = UDim2.fromScale(0.62, 0.24),
		Position = UDim2.fromScale(0.055, 0.06),
		Role = "Heading",
		Color = accentColor,
		AlignX = Enum.TextXAlignment.Left,
	})
	local chipText = if q.IsRanked then ("ELO " .. q.Format) else "VALE TUDO"
	local modeChip = UI.chip(face, chipText, q.Color, {
		Name = "Chip",
		Size = UDim2.fromScale(0.28, 0.21),
		Position = UDim2.fromScale(0.965, 0.07),
		AnchorPoint = Vector2.new(1, 0),
	})
	local descLbl = UI.text(face, q.Desc, {
		Name = "Desc",
		Size = UDim2.fromScale(0.90, 0.18),
		Position = UDim2.fromScale(0.055, 0.31),
		Role = "Small",
		Color = "onDark",
		AlignX = Enum.TextXAlignment.Left,
		StrokeMult = 0.4,
	})
	local rewardLbl = UI.text(face, q.RewardText, {
		Name = "Reward",
		Size = UDim2.fromScale(0.56, 0.17),
		Position = UDim2.fromScale(0.055, 0.51),
		Role = "Small",
		Color = "gold",
		AlignX = Enum.TextXAlignment.Left,
		StrokeMult = 0.45,
	})
	local checkLbl = UI.text(face, "", {
		Name = "Check",
		Size = UDim2.fromScale(0.56, 0.24),
		Position = UDim2.fromScale(0.055, 0.71),
		Role = "Small",
		Color = "inkSoft",
		AlignX = Enum.TextXAlignment.Left,
		StrokeMult = 0.35,
	})
	local btn = UI.button(face, {
		Name = "Join_" .. qid,
		Text = "ENTRAR",
		Color = q.Color,
		Size = UDim2.fromScale(0.35, 0.36),
		Position = UDim2.fromScale(0.965, 0.89),
		AnchorPoint = Vector2.new(1, 1),
		Corner = 0.22,
		Role = "Small",
		OnClick = function()
			toggleQueue(qid)
		end,
	})
	queueCards[qid] = {
		Config = q,
		Card = card,
		Chip = modeChip,
		Desc = descLbl,
		Reward = rewardLbl,
		Check = checkLbl,
		Button = btn,
	}
end

UI.text(filasPage, "Regras Ranqueada: Sem repetidos · M\u{e1}x. 1 Secreto e 2 Lend\u{e1}rios · Estrelas/Variantes apenas visuais · Gen\u{e9}tica, Treino e Passiva Secreta contam", {
	Name = "RulesFooter",
	Size = UDim2.fromScale(1, 0.07),
	Position = UDim2.fromScale(0, 0.93),
	Role = "Small",
	Color = "inkSoft",
	AlignX = Enum.TextXAlignment.Center,
	StrokeMult = 0.35,
})

--------------------------------------------------------------------
-- 2B. ABA RANKING: Top 10 Global/Servidor (2x2 e 1x1) + Temporada
--------------------------------------------------------------------
local rankLeft = UI.frame(rankingPage, { Name = "RankLeft", Size = UDim2.fromScale(0.64, 1) })
local rankTopRow = UI.frame(rankLeft, { Name = "TopRow", Size = UDim2.fromScale(1, 0.14) })
UI.clampHeight(rankTopRow, 42, 48)

local rankFmtWrap = UI.frame(rankTopRow, { Name = "FmtWrap", Size = UDim2.fromScale(0.52, 1) })
local selectRankFormat = UI.tabs(rankFmtWrap, {
	{ Id = "2x2", Text = "2x2 DUPLA" },
	{ Id = "1x1", Text = "1x1 CL\u{c1}SSICO" },
}, { Size = UDim2.fromScale(1, 1), MaxHeight = 44, MaxWidth = 0.485, ActiveColor = "orange" }, function(id)
	boardFormat = id
	if fetchLeaderboard then
		fetchLeaderboard(id)
	end
end)

local rankScopeWrap = UI.frame(rankTopRow, { Name = "ScopeWrap", Size = UDim2.fromScale(0.46, 1), Position = UDim2.fromScale(0.54, 0) })
local selectRankScope = UI.tabs(rankScopeWrap, {
	{ Id = "Global", Text = "GLOBAL" },
	{ Id = "Server", Text = "SERVIDOR" },
}, { Size = UDim2.fromScale(1, 1), MaxHeight = 44, MaxWidth = 0.485, ActiveColor = "blue" }, function(id)
	boardScope = id
	if refreshHubView then
		refreshHubView()
	end
end)

local rankListScroll = UI.scroll(rankLeft, { Name = "RankList", Size = UDim2.fromScale(1, 0.82), Gap = 0.025, Flat = true })
UI.fillBetween(rankListScroll, rankTopRow, nil, 8)

-- Painel direito: Seu Perfil Competitivo + Tabela de Gemas da Temporada Mensal
local rankRight, rankRightFace = UI.panel(rankingPage, {
	Name = "SeasonPanel",
	Size = UDim2.fromScale(0.34, 1),
	Position = UDim2.fromScale(0.66, 0),
	Color = "slot",
	Corner = 0.07,
	Shadow = false,
})
local seasonTitle = UI.text(rankRightFace, "SUA TEMPORADA", {
	Name = "Title",
	Size = UDim2.fromScale(0.92, 0.10),
	Position = UDim2.fromScale(0.04, 0.03),
	Role = "Heading",
	Color = "gold",
	AlignX = Enum.TextXAlignment.Left,
})
local seasonMyStats = UI.text(rankRightFace, "", {
	Name = "MyStats",
	Size = UDim2.fromScale(0.92, 0.25),
	Position = UDim2.fromScale(0.04, 0.135),
	Role = "Small",
	Color = "onDark",
	AlignX = Enum.TextXAlignment.Left,
	StrokeMult = 0.4,
})
local seasonDivider = Instance.new("Frame")
seasonDivider.Size = UDim2.new(0.92, 0, 0, 2)
seasonDivider.Position = UDim2.fromScale(0.04, 0.405)
seasonDivider.BackgroundColor3 = T.Palette.blue
seasonDivider.BackgroundTransparency = 0.45
seasonDivider.BorderSizePixel = 0
seasonDivider.Parent = rankRightFace

UI.text(rankRightFace, "PR\u{ca}MIOS DA TEMPORADA", {
	Name = "RewardsHead",
	Size = UDim2.fromScale(0.92, 0.09),
	Position = UDim2.fromScale(0.04, 0.425),
	Role = "Small",
	Color = "gems",
	AlignX = Enum.TextXAlignment.Left,
})

local seasonTiersBox = UI.frame(rankRightFace, {
	Name = "TierRewards",
	Size = UDim2.fromScale(0.92, 0.44),
	Position = UDim2.fromScale(0.04, 0.525),
})
local rewardTiers = { "Lenda", "Diamante", "Platina", "Ouro", "Prata" }
for idx, tid in ipairs(rewardTiers) do
	local tDef = nil
	for _, entry in ipairs(PvPRank.Tiers) do
		if entry.Id == tid then
			tDef = entry
			break
		end
	end
	if tDef then
		local rFrame = UI.frame(seasonTiersBox, {
			Name = "Tier_" .. tid,
			Size = UDim2.fromScale(1, 0.185),
			Position = UDim2.fromScale(0, (idx - 1) * 0.20),
		})
		UI.text(rFrame, string.format("%s (%d+)", tDef.Name, tDef.Min), {
			Name = "TierName",
			Size = UDim2.fromScale(0.56, 1),
			Position = UDim2.fromScale(0, 0),
			Role = "Small",
			Color = tDef.Color,
			AlignX = Enum.TextXAlignment.Left,
			StrokeMult = 0.4,
		})
		UI.icon(rFrame, "gem", {
			Name = "GemIcon",
			Size = UDim2.fromScale(0.11, 0.82),
			Position = UDim2.fromScale(0.58, 0.09),
			AspectAxis = Enum.DominantAxis.Height,
		})
		local tagBonus = if tid == "Lenda" then " + Tag" else ""
		UI.text(rFrame, string.format("%d%s", tDef.SeasonGems or 0, tagBonus), {
			Name = "GemQty",
			Size = UDim2.fromScale(0.30, 1),
			Position = UDim2.fromScale(0.70, 0),
			Role = "Small",
			Color = "onDark",
			AlignX = Enum.TextXAlignment.Right,
			StrokeMult = 0.4,
		})
	end
end

--------------------------------------------------------------------
-- Renderizacao do Hub e da Barra de Busca
--------------------------------------------------------------------
local function updateQueueBanner()
	if not queueState.InQueue or UI.inBattle() then
		queueBanner.Visible = false
		return
	end
	local elapsed = (queueState.Elapsed or 0) + math.max(0, math.floor(os.clock() - queueReceivedAt))
	local range = if queueState.IsRanked then PvPRank.AllowedEloGap(elapsed) else 9999
	local rangeStr = if not queueState.IsRanked
		then "Livre"
		elseif range >= 9000 then "Global"
		else ("+/-" .. tostring(range))
	queueBannerText.Text = string.format("BUSCANDO %s · %s · Faixa %s", queueState.Short or "PVP", fmtMmSs(elapsed), rangeStr)
	queueBannerStroke.Color = if queueState.IsRanked then T.Palette.gold else T.Palette.teal
	queueBanner.Visible = true
end

local function renderRankingList()
	UI.clear(rankListScroll)
	local data = boardCache[boardFormat]
	local me = data and data.MyPvP
	if data and me then
		local now = os.time() + (ReplicatedStorage:GetAttribute("RetentionOffset") or 0)
		local days = math.max(0, math.ceil(((data.SeasonEnd or now) - now) / 86400))
		seasonTitle.Text = "TEMPORADA " .. tostring(data.SeasonId or "")
		seasonMyStats.Text = string.format(
			"2x2: %s (%d ELO · %dV/%dD)\n1x1: %s (%d ELO · %dV/%dD)\nEncerra em %d dia%s",
			me.Tier2x2 or "Bronze", me.Rating2x2 or 1000, me.Wins2x2 or 0, me.Losses2x2 or 0,
			me.Tier1x1 or "Bronze", me.Rating1x1 or 1000, me.Wins1x1 or 0, me.Losses1x1 or 0,
			days, if days == 1 then "" else "s"
		)
	else
		seasonMyStats.Text = "Carregando dados da temporada..."
	end

	local list = data and data[boardScope] or {}
	if #list == 0 then
		UI.text(rankListScroll, string.format("Nenhum competidor no ranking %s (%s) ainda.", boardFormat, if boardScope == "Global" then "Global" else "Servidor"), {
			Name = "Empty",
			Size = UDim2.fromScale(1, 0),
			Aspect = 6.5,
			Role = "Small",
			Color = "inkSoft",
		})
		return
	end
	for i, e in ipairs(list) do
		local color = if i == 1 then "lendario" elseif i == 2 then "comum" elseif i == 3 then "orange" else "panelAlt"
		local _, f = UI.panel(rankListScroll, {
			Name = "Entry_" .. i,
			Size = UDim2.fromScale(1, 0),
			Aspect = 7.6,
			RowMax = 48,
			Color = color,
			Corner = T.Corner.Pill,
			Shadow = false,
			LayoutOrder = i,
		})
		UI.text(f, string.format("#%d  %s", i, tostring(e.Name or "")), {
			Name = "PlayerName",
			Size = UDim2.fromScale(0.54, 0.76),
			Position = UDim2.fromScale(0.04, 0.12),
			Role = "Small",
			AlignX = Enum.TextXAlignment.Left,
		})
		UI.text(f, string.format("%s · %d ELO", tostring(e.Tier or "Bronze"), tonumber(e.Rating) or 1000), {
			Name = "Elo",
			Size = UDim2.fromScale(0.40, 0.76),
			Position = UDim2.fromScale(0.96, 0.12),
			AnchorPoint = Vector2.new(1, 0),
			Role = "Small",
			Color = if i <= 3 then "onDark" else "gold",
			AlignX = Enum.TextXAlignment.Right,
		})
	end
end

refreshHubView = function()
	updateQueueBanner()

	local myPvP = statusData and statusData.MyPvP
	local pvpProf = myProfile and myProfile.PvP
	local r2 = (myPvP and myPvP.Rating2x2) or (pvpProf and pvpProf.Mode2x2 and pvpProf.Mode2x2.Rating) or (pvpProf and pvpProf.Rating) or PvPRank.StartRating
	local r1 = (myPvP and myPvP.Rating1x1) or (pvpProf and pvpProf.Mode1x1 and pvpProf.Mode1x1.Rating) or (pvpProf and pvpProf.Rating) or PvPRank.StartRating
	local t2 = PvPRank.TierFor(r2).Name
	local t1 = PvPRank.TierFor(r1).Name
	local dailyDone = (myPvP and myPvP.DailyRewards) or (pvpProf and pvpProf.DailyRewards) or 0
	local dailyCap = (myPvP and myPvP.DailyCap) or PvPRank.DailyRewardCap
	local seasonId = (myPvP and myPvP.SeasonId) or PvPRank.SeasonId(os.time())

	summaryMain.Text = string.format("2x2: %d ELO (%s)  |  1x1: %d ELO (%s)", r2, t2, r1, t1)
	summarySub.Text = string.format("B\u{f4}nus di\u{e1}rio: %d/%d vit\u{f3}rias  |  Matchmaking Global + Local", dailyDone, dailyCap)
	summarySeason.Text = "TEMP. " .. tostring(seasonId)

	local members = myTeamMembers()
	for _, qid in ipairs(PvPRank.QueueOrder) do
		local c = queueCards[qid]
		local q = c.Config
		local isThisQueue = queueState.InQueue and queueState.QueueId == qid
		local eligible = true
		local checkText = ""
		if q.IsRanked then
			local okR, errR = PvPRank.ValidateRankedTeam(members, q.Format)
			eligible = okR
			checkText = if okR then ("Time v\u{e1}lido (" .. #members .. " no time)") else (errR or "Time inv\u{e1}lido")
		else
			if #members < q.MinTeam then
				eligible = false
				checkText = string.format("Precisa de %d+ personagens no time", q.MinTeam)
			else
				checkText = string.format("Pronto (%d no time · poder real)", #members)
			end
		end
		c.Check.Text = checkText
		c.Check.TextColor3 = if isThisQueue then T.Palette.gold elseif eligible then T.Palette.green else T.Palette.hpLow

		if isThisQueue then
			UI.setText(c.Button, "CANCELAR")
			UI.setDisabled(c.Button, false, "red")
		else
			UI.setText(c.Button, "ENTRAR")
			UI.setDisabled(c.Button, not eligible, q.Color)
		end
	end

	if currentHubTab == "Ranking" then
		renderRankingList()
	end
end

fetchStatus = function()
	task.spawn(function()
		local ok, res = invokeQueue("Status")
		if ok and typeof(res) == "table" then
			statusData = res
			if res.InQueue ~= nil then
				queueState = res
				queueReceivedAt = os.clock()
			end
			refreshHubView()
		end
	end)
end

fetchLeaderboard = function(fmt: string)
	task.spawn(function()
		local ok, res = invokeQueue("Leaderboard", fmt)
		if ok and typeof(res) == "table" then
			boardCache[fmt] = res
			renderRankingList()
		end
	end)
end

queueLeaveBtn.Activated:Connect(function()
	if queueState.InQueue and queueState.QueueId then
		toggleQueue(queueState.QueueId)
	end
end)

local function openHub(tab: string?)
	if UI.inBattle() then
		return
	end
	hubMsg.Text = ""
	if tab == "Ranking" then
		selectHubTab("Ranking")
	else
		selectHubTab("Filas")
	end
	hubWin.Open()
	refreshHubView()
	fetchStatus()
	fetchLeaderboard(boardFormat)
end

UI.onOpen("PvP", function(tab)
	openHub(if typeof(tab) == "string" then tab else nil)
end)

local queueStateRE = Remotes:FindFirstChild("PvPQueueState")
if queueStateRE and queueStateRE:IsA("RemoteEvent") then
	queueStateRE.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		queueState = payload
		queueReceivedAt = os.clock()
		if payload.MatchFound then
			hubWin.Close()
			if payload.OpponentName then
				toast("Partida encontrada contra " .. tostring(payload.OpponentName) .. "!")
			end
		elseif payload.Reason and payload.Reason ~= "" then
			toast(payload.Reason)
		end
		refreshHubView()
	end)
end

--------------------------------------------------------------------
-- 3. DUELO AMISTOSO POR PROXIMIDADE (Casual, Poder Real, Sem ELO)
--------------------------------------------------------------------
local pickerBox, pickerFace = UI.panel(canvas, {
	Name = "FormatPicker", Size = UDim2.fromScale(0.52, 0.48), Position = UDim2.fromScale(0.5, 0.48),
	AnchorPoint = Vector2.new(0.5, 0.5), Color = "panel", Corner = 0.08, Aspect = 1.9,
	Visible = false, ZIndex = 44, MaxSize = Vector2.new(580, 305),
})
local pickerScale = Instance.new("UIScale")
pickerScale.Parent = pickerBox
UI.stroke(pickerFace, T.Palette.orange, 1.3)
local pickerClose = UI.button(pickerFace, {
	Name = "Close", Icon = "close", Color = "grey",
	Size = UDim2.fromScale(0.11, 0.2), Position = UDim2.fromScale(0.97, 0.06),
	AnchorPoint = Vector2.new(1, 0), Corner = 0.32, ZIndex = 46,
})
local pickerTitle = UI.text(pickerFace, "Duelo Amistoso", {
	Name = "Title", Size = UDim2.fromScale(0.78, 0.19), Position = UDim2.fromScale(0.05, 0.07),
	Role = "Heading", AlignX = Enum.TextXAlignment.Left, ZIndex = 45,
})
local pickerSub = UI.text(pickerFace, "Casual (Poder Real) · Sem ELO · 30 s/turno · Sem itens", {
	Name = "Sub", Size = UDim2.fromScale(0.84, 0.13), Position = UDim2.fromScale(0.05, 0.26),
	Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.4, ZIndex = 45,
})

local function makeFormatOption(name: string, xScale: number, color: string, titleText: string, descText: string)
	local b, face = UI.button(pickerFace, {
		Name = name, Color = color, Size = UDim2.fromScale(0.43, 0.46),
		Position = UDim2.fromScale(xScale, 0.45), Corner = 0.16, ZIndex = 45,
	})
	UI.text(face, titleText, {
		Name = "Label", Size = UDim2.fromScale(0.9, 0.42), Position = UDim2.fromScale(0.05, 0.12),
		Role = "Heading", ZIndex = 46,
	})
	UI.text(face, descText, {
		Name = "Desc", Size = UDim2.fromScale(0.9, 0.34), Position = UDim2.fromScale(0.05, 0.56),
		Role = "Small", StrokeMult = 0.45, ZIndex = 46,
	})
	return b
end

local btn2x2 = makeFormatOption("Format2x2", 0.05, "orange", "AMISTOSO 2x2", "Em dupla · Poder real · Sem ELO")
local btn1x1 = makeFormatOption("Format1x1", 0.52, "blue", "AMISTOSO 1x1", "Cl\u{e1}ssico · Poder real · Sem ELO")

local pickTargetId: number? = nil

local function closePicker()
	pickerBox.Visible = false
	pickTargetId = nil
end

local function openPicker(targetUserId: number, targetName: string)
	pickTargetId = targetUserId
	pickerTitle.Text = "Duelo Amistoso: " .. targetName
	pickerSub.Text = "Modo Casual (Poder real liberado) · Sem ELO · Use a Arena PvP para Ranqueada"
	pickerBox.Visible = true
	pickerScale.Scale = T.Motion.OpenFrom
	TweenService:Create(pickerScale, TweenInfo.new(T.Motion.OpenTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	UI.play("open")
end

Remotes:WaitForChild("ProfileUpdated").OnClientEvent:Connect(function(p)
	if typeof(p) == "table" then
		myProfile = p
		refreshHubView()
	end
end)
task.spawn(function()
	local ok, p = pcall(function()
		return Remotes:WaitForChild("GetProfile"):InvokeServer()
	end)
	if ok and typeof(p) == "table" then
		myProfile = p
		refreshHubView()
	end
end)

local function sendChallenge(fmt: string)
	local uid = pickTargetId
	closePicker()
	if not uid then
		return
	end
	local ok, text = Remotes.PvPChallenge:InvokeServer(uid, fmt)
	if not ok then
		toast(text)
	end
end

btn2x2.Activated:Connect(function()
	sendChallenge("2x2")
end)
btn1x1.Activated:Connect(function()
	sendChallenge("1x1")
end)
pickerClose.Activated:Connect(closePicker)

--------------------------------------------------------------------
-- 4. CAIXA DE CONVITE AMISTOSO RECEBIDO / ENVIADO
--------------------------------------------------------------------
local box, face = UI.panel(canvas, {
	Name = "Invite", Size = UDim2.fromScale(0.5, 0.44), Position = UDim2.fromScale(0.5, 0.44),
	AnchorPoint = Vector2.new(0.5, 0.5), Color = "panel", Corner = 0.1, Aspect = 2.0,
	Visible = false, ZIndex = 40, MaxSize = Vector2.new(560, 280),
})
local boxScale = Instance.new("UIScale")
boxScale.Parent = box
UI.stroke(face, T.Palette.red, 1.3)
UI.icon(box, "sword", { Name = "Icon", Size = UDim2.fromScale(0.18, 0.36), Position = UDim2.fromScale(0.5, 0), AnchorPoint = Vector2.new(0.5, 0.62), ZIndex = 42 })
local formatChip = UI.chip(face, "AMISTOSO 1x1", "blue", {
	Name = "FormatChip", Size = UDim2.fromScale(0.46, 0.17), Position = UDim2.fromScale(0.5, 0.14),
	AnchorPoint = Vector2.new(0.5, 0), ZIndex = 41,
})
local title = UI.text(face, "", { Name = "Title", Size = UDim2.fromScale(0.9, 0.22), Position = UDim2.fromScale(0.05, 0.33), Role = "Body", ZIndex = 41 })
local info = UI.text(face, "", { Name = "Info", Size = UDim2.fromScale(0.9, 0.14), Position = UDim2.fromScale(0.05, 0.54), Role = "Small", Color = "inkSoft", StrokeMult = 0.4, ZIndex = 41 })
local accept = UI.button(face, { Name = "Accept", Text = "ACEITAR", Icon = "tick", Layout = "row", Color = "green", Size = UDim2.fromScale(0.42, 0.24), Position = UDim2.fromScale(0.05, 0.71), Role = "Body", ZIndex = 41 })
local decline = UI.button(face, { Name = "Decline", Text = "RECUSAR", Icon = "close", Layout = "row", Color = "red", Size = UDim2.fromScale(0.42, 0.24), Position = UDim2.fromScale(0.53, 0.71), Role = "Body", ZIndex = 41 })

local inviteMode = nil -- "Incoming" | "Sent"
local fromUserId = nil
local expires = 0
local baseInfo = ""

local function closeInvite()
	box.Visible = false
	inviteMode = nil
	fromUserId = nil
end

local function openInvite(kind, text, fmt, seconds)
	closePicker()
	inviteMode = kind
	expires = os.clock() + (seconds or 20)
	title.Text = text
	formatChip.Face.Label.Text = formatLabel(fmt)
	UI.paint(formatChip, formatColor(fmt))
	baseInfo = "Duelo Amistoso (Poder real) · Sem ELO · 30 s/turno"
	accept.Visible = kind == "Incoming"
	UI.setText(decline, if kind == "Incoming" then "RECUSAR" else "CANCELAR")
	decline.Position = if kind == "Incoming" then UDim2.fromScale(0.53, 0.71) else UDim2.fromScale(0.29, 0.71)
	box.Visible = true
	boxScale.Scale = T.Motion.OpenFrom
	TweenService:Create(boxScale, TweenInfo.new(T.Motion.OpenTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	UI.play("open")
end

accept.Activated:Connect(function()
	if inviteMode ~= "Incoming" then
		return
	end
	local id = fromUserId
	closeInvite()
	local ok, text = Remotes.PvPRespond:InvokeServer(id, true)
	if not ok then
		toast(text)
	end
end)
decline.Activated:Connect(function()
	if inviteMode == "Incoming" then
		local id = fromUserId
		closeInvite()
		Remotes.PvPRespond:InvokeServer(id, false)
	elseif inviteMode == "Sent" then
		closeInvite()
		Remotes.PvPCancel:InvokeServer()
	end
end)

Remotes:WaitForChild("PvPInvite").OnClientEvent:Connect(function(data)
	if data.Kind == "Incoming" then
		fromUserId = data.FromUserId
		local fmtTag = if data.Format == "2x2" then "Amistoso 2x2" else "Amistoso 1x1"
		openInvite("Incoming", data.FromName .. " desafiou voc\u{ea} para um " .. fmtTag .. "!", data.Format, data.Seconds)
	elseif data.Kind == "Sent" then
		local fmtTag = if data.Format == "2x2" then "2x2" else "1x1"
		openInvite("Sent", "Duelo Amistoso " .. fmtTag .. " enviado para " .. data.ToName .. "...", data.Format, data.Seconds)
	elseif data.Kind == "Closed" then
		closeInvite()
		toast(data.Text)
	end
end)

UI.onBattle(function(inBattle)
	if inBattle then
		closeInvite()
		closePicker()
		hubWin.Close()
	end
	updateQueueBanner()
end)

-- Contagem de convite e cronometro ao vivo da barra de fila
task.spawn(function()
	while true do
		task.wait(0.25)
		if box.Visible then
			local left = math.max(0, math.ceil(expires - os.clock()))
			info.Text = baseInfo .. "  (" .. left .. " s)"
			if left <= 0 then
				closeInvite()
			end
		end
		if queueState.InQueue then
			updateQueueBanner()
		end
	end
end)

--------------------------------------------------------------------
-- 5. PROMPTS: Duelo Amistoso (F) nos jogadores + Quadro 3D PvP (E)
--------------------------------------------------------------------
local prompts = {} -- [Player] = ProximityPrompt

local function inPlaza(model: Model?): boolean
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local p = root.Position
	return math.abs(p.X) <= PLAZA_HALF_X and math.abs(p.Z) <= PLAZA_HALF_Z and p.Y < 60
end

local function attach(other: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PvPPrompt"
	prompt.ActionText = "Duelo Amistoso"
	prompt.ObjectText = other.DisplayName
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt:SetAttribute("UserId", other.UserId)
	prompt:SetAttribute("DisplayName", other.DisplayName)
	prompt.Enabled = false
	prompt.Parent = root
	prompts[other] = prompt
end

local function watch(other: Player)
	if other == player then
		return
	end
	other.CharacterAdded:Connect(function(ch)
		attach(other, ch)
	end)
	if other.Character then
		task.spawn(attach, other, other.Character)
	end
end
for _, p in ipairs(Players:GetPlayers()) do
	watch(p)
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(function(p)
	prompts[p] = nil
	if pickTargetId == p.UserId then
		closePicker()
	end
end)

task.spawn(function()
	while true do
		task.wait(0.5)
		local meOk = not UI.inBattle() and inPlaza(player.Character)
		for other, prompt in pairs(prompts) do
			if prompt.Parent then
				prompt.Enabled = meOk and inPlaza(other.Character)
			end
		end
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "PvPBoardPrompt" then
		openHub("Filas")
		return
	end
	if prompt.Name ~= "PvPPrompt" then
		return
	end
	local targetId = prompt:GetAttribute("UserId")
	local targetName = prompt:GetAttribute("DisplayName") or prompt.ObjectText or "Jogador"
	if typeof(targetId) == "number" then
		openPicker(targetId, targetName)
	end
end)
