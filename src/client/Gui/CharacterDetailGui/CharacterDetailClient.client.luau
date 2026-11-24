--[[
	CharacterDetailClient (GDD secao 4 - Detalhamento de Genetica e Treino)
	Janela empilhada (Stack = true) aberta via UI.open("CharacterDetail", uid).
	Acessivel pela Barra do Time, tela de Equipe e Mochila > Personagens.
	Exibe retrato 3D, anime/raridade/rank genetico, grafico de radar (0-100%)
	com modos Ambos / Genetica / Treino e tabela detalhada dos 4 atributos.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local gui = script.Parent
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Data = ReplicatedStorage:WaitForChild("Data")
local Characters = require(Data:WaitForChild("Characters"))
local Progression = require(Data:WaitForChild("Progression"))
local Genetics = require(Data:WaitForChild("Genetics"))
local TypeChart = require(Data:WaitForChild("TypeChart"))
local UI = require(ReplicatedStorage:WaitForChild("UI"))
local TeamCards = require(ReplicatedStorage:WaitForChild("TeamCards"))
local RadarChart = require(ReplicatedStorage:WaitForChild("RadarChart"))
local T = UI.Theme

local RARITY_NAME = { Comum = "Comum", Raro = "Raro", Epico = "\u{c9}pico", Lendario = "Lend\u{e1}rio" }
local RARITY_COLOR = { Comum = "comum", Raro = "raro", Epico = "epico", Lendario = "lendario" }

local profile = nil
local currentUid = nil

local canvas = UI.screen(gui)
gui.DisplayOrder = 16 -- acima de Equipe (8) e Mochila (9)

local win = UI.window(canvas, {
	Name = "DetailWindow",
	Title = "ATRIBUTOS DO PERSONAGEM",
	Icon = "star",
	HeaderColor = "purple",
	Stack = true,
	Size = UDim2.fromScale(0.94, 0.88),
	MaxSize = Vector2.new(1080, 580),
})
local body = win.Body

-- Tres paineis responsivos dentro do Body
local idPanel, idFace = UI.panel(body, { Name = "Identity", Color = "slot", Corner = 0.06, Shadow = false, ZIndex = 2 })
local radarPanel, radarFace = UI.panel(body, { Name = "RadarPanel", Color = "slot", Corner = 0.06, Shadow = false, ZIndex = 2 })
local statsPanel, statsFace = UI.panel(body, { Name = "StatsPanel", Color = "slot", Corner = 0.06, Shadow = false, ZIndex = 2 })

-- 1) Painel esquerdo: Retrato 3D + Metadados + Medias
local portrait = TeamCards.new(idFace, { Name = "Portrait", ZIndex = 3 })
portrait.Root.Active = false
portrait.Root.Selectable = false

local metaTag = UI.text(idFace, "", { Name = "Meta", Role = "Small", Color = "inkSoft", ZIndex = 4, StrokeMult = 0.45 })
local gradeBadge, gradeFace = UI.panel(idFace, { Name = "Grade", Color = "epico", Corner = 0.35, Shadow = false, ZIndex = 4 })
local gradeLabel = UI.text(gradeFace, "", { Name = "Value", Role = "Small", ZIndex = 5 })
local genAvgLabel = UI.text(idFace, "", { Name = "GenAvg", Role = "Small", ZIndex = 4, Rich = true, StrokeMult = 0.45 })
local trnAvgLabel = UI.text(idFace, "", { Name = "TrnAvg", Role = "Small", ZIndex = 4, Rich = true, StrokeMult = 0.45 })
local powerLabel = UI.text(idFace, "", { Name = "TotalPower", Role = "Small", Color = "gold", ZIndex = 4, StrokeMult = 0.5 })
local movesBtn = UI.button(idFace, {
	Name = "MovesButton",
	Text = "GOLPES",
	Icon = "sword",
	Layout = "row",
	Color = "blue",
	Role = "Small",
	Corner = 0.26,
	ZIndex = 5,
	OnClick = function()
		local uid = currentUid
		if not uid then
			return
		end
		portrait.Clear()
		win.Close(true)
		UI.open("Team", uid)
	end,
})

-- 2) Painel central: Seletor de camada + Radar + Legenda
local modeRow = UI.frame(radarFace, { Name = "ModeButtons", ZIndex = 3 })
local modeBtns = {}
local activeMode = "Both"
local radar = RadarChart.new(radarFace, { Name = "Radar", ZIndex = 4 })
local legendLabel = UI.text(radarFace, "<font color='#73F5FF'>Gen\u{e9}tica (+40%)</font>   \u{b7}   <font color='#FFCE54'>Treino (+30%)</font>", {
	Name = "Legend",
	Role = "Small",
	Rich = true,
	StrokeMult = 0.45,
	ZIndex = 4,
})

local function updateModeButtons()
	for id, b in pairs(modeBtns) do
		local c = if id == activeMode then "teal" else "panelAlt"
		UI.paint(b, c)
		b:SetAttribute("BaseColor", c)
	end
end

local MODES = {
	{ Id = "Both", Text = "AMBOS", Icon = "star" },
	{ Id = "Genetics", Text = "GEN\u{c9}TICA", Icon = "sparkle" },
	{ Id = "Training", Text = "TREINO", Icon = "pickaxe" },
}
for _, m in ipairs(MODES) do
	modeBtns[m.Id] = UI.button(modeRow, {
		Name = "Mode_" .. m.Id,
		Text = m.Text,
		Icon = m.Icon,
		Layout = "row",
		Color = "panelAlt",
		Role = "Small",
		Corner = 0.28,
		ZIndex = 4,
		OnClick = function()
			activeMode = m.Id
			radar.SetMode(activeMode)
			updateModeButtons()
		end,
	})
end
updateModeButtons()

-- 3) Painel direito: Detalhamento por atributo
local statsHeader = UI.text(statsFace, "DETALHAMENTO (BASE / FINAL)", {
	Name = "Header",
	Role = "Small",
	Color = "inkSoft",
	AlignX = Enum.TextXAlignment.Left,
	StrokeMult = 0.45,
	ZIndex = 3,
})

local statRows = {}
for _, statKey in ipairs(Genetics.Stats) do
	local row, rface = UI.panel(statsFace, { Name = "Row_" .. statKey, Color = "panelAlt", Corner = 0.22, Shadow = false, ZIndex = 3 })
	local topText = UI.text(rface, "", { Name = "Top", Role = "Small", AlignX = Enum.TextXAlignment.Left, Rich = true, StrokeMult = 0.45, ZIndex = 4 })
	local finalText = UI.text(rface, "", { Name = "Final", Role = "Small", Color = "gold", AlignX = Enum.TextXAlignment.Right, Rich = true, StrokeMult = 0.5, ZIndex = 4 })
	local pctText = UI.text(rface, "", { Name = "Pcts", Role = "Small", AlignX = Enum.TextXAlignment.Left, Rich = true, StrokeMult = 0.45, ZIndex = 4 })

	-- Duas micro-barras de progresso (Genetica = ciano, Treino = laranja/ouro)
	local genTrack = Instance.new("Frame")
	genTrack.Name = "GenTrack"
	genTrack.BackgroundColor3 = T.Palette.track
	genTrack.BorderSizePixel = 0
	genTrack.ZIndex = 4
	UI.corner(genTrack, 1)
	genTrack.Parent = rface
	local genFill = Instance.new("Frame")
	genFill.Name = "Fill"
	genFill.BackgroundColor3 = Color3.fromRGB(70, 232, 244)
	genFill.BorderSizePixel = 0
	genFill.Size = UDim2.fromScale(0, 1)
	genFill.ZIndex = 5
	UI.corner(genFill, 1)
	genFill.Parent = genTrack

	local trnTrack = Instance.new("Frame")
	trnTrack.Name = "TrnTrack"
	trnTrack.BackgroundColor3 = T.Palette.track
	trnTrack.BorderSizePixel = 0
	trnTrack.ZIndex = 4
	UI.corner(trnTrack, 1)
	trnTrack.Parent = rface
	local trnFill = Instance.new("Frame")
	trnFill.Name = "Fill"
	trnFill.BackgroundColor3 = Color3.fromRGB(255, 194, 64)
	trnFill.BorderSizePixel = 0
	trnFill.Size = UDim2.fromScale(0, 1)
	trnFill.ZIndex = 5
	UI.corner(trnFill, 1)
	trnFill.Parent = trnTrack

	statRows[statKey] = {
		Row = row,
		Face = rface,
		Top = topText,
		Final = finalText,
		Pcts = pctText,
		GenTrack = genTrack,
		GenFill = genFill,
		TrnTrack = trnTrack,
		TrnFill = trnFill,
	}
end

local footerNote = UI.text(statsFace, "Treine atributos na C\u{e1}psula da Base para subir at\u{e9} 100%.", {
	Name = "Note",
	Role = "Small",
	Color = "inkSoft",
	AlignX = Enum.TextXAlignment.Left,
	StrokeMult = 0.4,
	ZIndex = 3,
})

local function layout()
	local W, H = body.AbsoluteSize.X, body.AbsoluteSize.Y
	if W < 20 or H < 20 then
		return
	end
	local gap = math.max(6, math.floor(W * 0.012))
	local col1W = math.floor(W * 0.25)
	local col2W = math.floor(W * 0.365)
	local col3W = math.max(100, W - col1W - col2W - gap * 2)

	idPanel.Position = UDim2.fromOffset(0, 0)
	idPanel.Size = UDim2.fromOffset(col1W, H)

	radarPanel.Position = UDim2.fromOffset(col1W + gap, 0)
	radarPanel.Size = UDim2.fromOffset(col2W, H)

	statsPanel.Position = UDim2.fromOffset(col1W + col2W + gap * 2, 0)
	statsPanel.Size = UDim2.fromOffset(col3W, H)

	-- 1) Layout esquerdo
	local idW, idH = col1W - 12, H - 12
	local movesBtnH = math.max(T.TouchMin, math.min(48, math.floor(idH * 0.125)))
	local movesBtnY = H - 6 - movesBtnH
	movesBtn.Size = UDim2.fromOffset(idW, movesBtnH)
	movesBtn.Position = UDim2.fromOffset(6, movesBtnY)

	local portMaxH = math.max(54, math.floor((movesBtnY - 10) * 0.43))
	local portS = math.min(idW - 8, portMaxH)
	portrait.Root.AnchorPoint = Vector2.new(0.5, 0)
	portrait.Root.Size = UDim2.fromOffset(portS, portS)
	portrait.Root.Position = UDim2.fromOffset(math.floor(col1W / 2), 6)

	local y = 6 + portS + 4
	local rem = math.max(60, movesBtnY - y - 6)
	local rowH = math.max(15, math.floor(rem / 5))
	metaTag.Size = UDim2.fromOffset(idW, rowH)
	metaTag.Position = UDim2.fromOffset(6, y)
	y += rowH

	gradeBadge.Size = UDim2.fromOffset(math.min(idW, 140), math.max(18, rowH))
	gradeBadge.AnchorPoint = Vector2.new(0.5, 0)
	gradeBadge.Position = UDim2.fromOffset(math.floor(col1W / 2), y)
	y += gradeBadge.Size.Y.Offset + 2

	genAvgLabel.Size = UDim2.fromOffset(idW, rowH)
	genAvgLabel.Position = UDim2.fromOffset(6, y)
	y += rowH

	trnAvgLabel.Size = UDim2.fromOffset(idW, rowH)
	trnAvgLabel.Position = UDim2.fromOffset(6, y)
	y += rowH

	powerLabel.Size = UDim2.fromOffset(idW, math.max(15, movesBtnY - y - 4))
	powerLabel.Position = UDim2.fromOffset(6, y)

	-- 2) Layout central (Radar)
	local rPad = 6
	local rW, rH = col2W - rPad * 2, H - rPad * 2
	local btnH = T.TouchMin
	local bw = math.floor((rW - 8) / 3)
	modeRow.Size = UDim2.fromOffset(rW, btnH)
	modeRow.Position = UDim2.fromOffset(rPad, rPad)
	for i, m in ipairs(MODES) do
		local b = modeBtns[m.Id]
		b.Size = UDim2.fromOffset(bw, btnH)
		b.Position = UDim2.fromOffset((i - 1) * (bw + 4), 0)
	end

	local legH = math.max(16, math.floor(H * 0.08))
	legendLabel.Size = UDim2.fromOffset(rW, legH)
	legendLabel.Position = UDim2.fromOffset(rPad, H - rPad - legH)

	local plotY = rPad + btnH + 2
	local plotH = math.max(60, H - plotY - legH - rPad - 2)
	radar.Root.Position = UDim2.fromOffset(rPad, plotY)
	radar.Root.Size = UDim2.fromOffset(rW, plotH)

	-- 3) Layout direito (Tabela 4 atributos)
	local sPad = 8
	local sW = col3W - sPad * 2
	local hdrH = math.max(16, math.floor(H * 0.085))
	local ftrH = math.max(16, math.floor(H * 0.08))
	statsHeader.Size = UDim2.fromOffset(sW, hdrH)
	statsHeader.Position = UDim2.fromOffset(sPad, 6)

	footerNote.Size = UDim2.fromOffset(sW, ftrH)
	footerNote.Position = UDim2.fromOffset(sPad, H - ftrH - 4)

	local listY = 6 + hdrH + 4
	local listH = math.max(80, H - listY - ftrH - 8)
	local rowGap = math.max(4, math.floor(listH * 0.025))
	local cardH = math.floor((listH - rowGap * 3) / 4)

	for i, statKey in ipairs(Genetics.Stats) do
		local st = statRows[statKey]
		st.Row.Size = UDim2.fromOffset(sW, cardH)
		st.Row.Position = UDim2.fromOffset(sPad, listY + (i - 1) * (cardH + rowGap))

		local rw, rh = sW - 12, cardH - 6
		local topH = math.max(15, math.floor(rh * 0.42))
		local pctH = math.max(14, math.floor(rh * 0.36))
		local barH = math.max(4, math.floor(rh * 0.14))

		st.Top.Position = UDim2.fromOffset(6, 2)
		st.Top.Size = UDim2.fromOffset(math.floor(rw * 0.52), topH)
		st.Final.Position = UDim2.fromOffset(math.floor(rw * 0.54) + 6, 2)
		st.Final.Size = UDim2.fromOffset(math.max(20, rw - math.floor(rw * 0.54)), topH)

		st.Pcts.Position = UDim2.fromOffset(6, 2 + topH)
		st.Pcts.Size = UDim2.fromOffset(rw, pctH)

		local barY = math.min(cardH - barH - 2, 2 + topH + pctH + 1)
		local halfBar = math.floor((rw - 6) / 2)
		st.GenTrack.Position = UDim2.fromOffset(6, barY)
		st.GenTrack.Size = UDim2.fromOffset(halfBar, barH)
		st.TrnTrack.Position = UDim2.fromOffset(6 + halfBar + 6, barY)
		st.TrnTrack.Size = UDim2.fromOffset(halfBar, barH)
	end
end
body:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

local function refresh()
	local m = profile and currentUid and profile.Collection and profile.Collection[currentUid]
	if not m then
		return
	end
	local def = Characters.Get(m.CharacterId)
	if not def then
		return
	end

	local bd = Progression.StatBreakdown(m)
	local rarityText = RARITY_NAME[def.Rarity] or def.Rarity
	local animeText = Characters.AnimeDisplay(Characters.AnimeOf(def.Id))
	local typeText = TypeChart.DisplayName[def.Type] or def.Type
	win.Title.Text = string.upper(def.Name) .. "  \u{b7}  NV " .. tostring(m.Level or 1)

	portrait.Set(currentUid, m)
	metaTag.Text = string.format("%s  \u{b7}  %s  \u{b7}  %s", rarityText, animeText, typeText)

	local rank, rankColor = Genetics.Grade(bd.Genetics)
	UI.paint(gradeBadge, rankColor)
	gradeLabel.Text = string.format("GEN\u{c9}TICA %s  (%.0f%%)", rank, bd.GeneticsAvg)

	genAvgLabel.Text = string.format("Gen\u{e9}tica m\u{e9}dia: <font color='#73F5FF'>%.0f%%</font>", bd.GeneticsAvg)
	trnAvgLabel.Text = string.format("Treino m\u{e9}dio: <font color='#FFCE54'>%.0f%%</font>", bd.TrainingAvg)
	powerLabel.Text = string.format("Geral: %d  (Base %d)", bd.TotalFinal, bd.TotalBase)

	radar.SetData(bd.Genetics, bd.Training)

	for _, statKey in ipairs(Genetics.Stats) do
		local info = bd.Stats[statKey]
		local row = statRows[statKey]
		local label = Genetics.StatLabels[statKey].Name
		row.Top.Text = string.format("%s  <font color='#B8B2E0'>(%d)</font>", label, info.Base)
		row.Final.Text = string.format("Final: %d", info.Final)
		row.Pcts.Text = string.format(
			"<font color='#73F5FF'>Gen %d%% (+%.0f%%)</font>  \u{b7}  <font color='#FFCE54'>Trn %d%% (+%.0f%%)</font>",
			info.Genetics,
			info.GeneticsBonusPct,
			info.Training,
			info.TrainingBonusPct
		)
		row.GenFill.Size = UDim2.fromScale(math.clamp(info.Genetics / 100, 0, 1), 1)
		row.TrnFill.Size = UDim2.fromScale(math.clamp(info.Training / 100, 0, 1), 1)
	end
end

win.CloseButton.Activated:Connect(function()
	portrait.Clear()
end)

UI.onOpen("CharacterDetail", function(uid)
	if not uid then
		return
	end
	if not profile or not profile.Collection or not profile.Collection[uid] then
		local ok, p = pcall(function()
			return Remotes:WaitForChild("GetProfile"):InvokeServer()
		end)
		if ok and typeof(p) == "table" then
			profile = p
		end
	end
	if not profile or not profile.Collection or not profile.Collection[uid] then
		return
	end
	currentUid = uid
	if not win.IsOpen() then
		win.Open()
	end
	task.defer(function()
		layout()
		refresh()
	end)
end)

UI.onBattle(function(on)
	if on and win.IsOpen() then
		portrait.Clear()
		win.Close(true)
	end
end)

Remotes:WaitForChild("ProfileUpdated").OnClientEvent:Connect(function(p)
	if typeof(p) == "table" then
		profile = p
		if win.IsOpen() then
			refresh()
		end
	end
end)

task.spawn(function()
	local ok, p = pcall(function()
		return Remotes:WaitForChild("GetProfile"):InvokeServer()
	end)
	if ok and typeof(p) == "table" then
		profile = p
	end
end)
