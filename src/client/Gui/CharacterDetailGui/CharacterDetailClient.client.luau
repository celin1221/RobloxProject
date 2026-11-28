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
local Summon = require(Data:WaitForChild("Summon"))
local Progression = require(Data:WaitForChild("Progression"))
local Genetics = require(Data:WaitForChild("Genetics"))
local TypeChart = require(Data:WaitForChild("TypeChart"))
local Awakening = require(Data:WaitForChild("Awakening"))
local UI = require(ReplicatedStorage:WaitForChild("UI"))
local TeamCards = require(ReplicatedStorage:WaitForChild("TeamCards"))
local RadarChart = require(ReplicatedStorage:WaitForChild("RadarChart"))
local T = UI.Theme

local RARITY_NAME = { Comum = "Comum", Raro = "Raro", Epico = "\u{c9}pico", Lendario = "Lend\u{e1}rio", Secreto = "Secreto" }
local RARITY_COLOR = { Comum = "comum", Raro = "raro", Epico = "epico", Lendario = "lendario", Secreto = "secreto" }

local profile = nil
local currentUid = nil
local detailBusy = false
local sellConfirmUid: string? = nil
local sellConfirmToken = 0

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
local favBtn = UI.button(idFace, {
	Name = "FavoriteButton",
	Text = "FAVORITO",
	Icon = "heart",
	Layout = "row",
	Color = "panelAlt",
	Role = "Small",
	Corner = 0.26,
	Sound = false,
	ZIndex = 5,
})
local sellBtn = UI.button(idFace, {
	Name = "SellButton",
	Text = "VENDER",
	Icon = "coin",
	Layout = "row",
	Color = "red",
	Role = "Small",
	Corner = 0.26,
	Sound = false,
	ZIndex = 5,
})
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
for _, b in ipairs({ favBtn, sellBtn, movesBtn }) do
	local sc = b:FindFirstChildOfClass("UISizeConstraint")
	if sc then
		sc.MinSize = Vector2.new(54, 32)
	end
end

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

-- Card de Passiva (mostra Passiva ativa + mistério da Passiva Secreta para Epicos ainda nao despertos)
local passiveCard, passiveFace = UI.panel(statsFace, { Name = "PassiveCard", Color = "panelAlt", Corner = 0.18, Shadow = false, ZIndex = 3 })
local passiveIcon = UI.icon(passiveFace, "sparkle", { Name = "Icon", ZIndex = 4 })
local passiveTitle = UI.text(passiveFace, "", { Name = "Title", Role = "Small", AlignX = Enum.TextXAlignment.Left, Rich = true, StrokeMult = 0.45, ZIndex = 4 })
local passiveDesc = UI.text(passiveFace, "", { Name = "Desc", Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, AlignY = Enum.TextYAlignment.Top, Wrap = true, StrokeMult = 0.35, ZIndex = 4 })
local secretRow = UI.frame(passiveFace, { Name = "SecretRow", Visible = false, ZIndex = 4 })
local secretIcon = UI.icon(secretRow, "lock", { Name = "LockIcon", ZIndex = 5 })
local secretText = UI.text(secretRow, "", { Name = "SecretText", Role = "Small", AlignX = Enum.TextXAlignment.Left, Rich = true, Wrap = true, StrokeMult = 0.35, ZIndex = 5 })

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

	-- 1) Layout esquerdo (retrato + info + linha Favorito/Vender + botao Golpes)
	local idW, idH = col1W - 12, H - 12
	local btnGap = 4
	local actionBtnH = math.clamp(math.floor(idH * 0.105), 32, 42)
	local movesBtnY = H - 6 - actionBtnH
	movesBtn.Size = UDim2.fromOffset(idW, actionBtnH)
	movesBtn.Position = UDim2.fromOffset(6, movesBtnY)

	local subRowY = movesBtnY - btnGap - actionBtnH
	local halfBtnW = math.floor((idW - btnGap) / 2)
	favBtn.Size = UDim2.fromOffset(halfBtnW, actionBtnH)
	favBtn.Position = UDim2.fromOffset(6, subRowY)
	sellBtn.Size = UDim2.fromOffset(idW - halfBtnW - btnGap, actionBtnH)
	sellBtn.Position = UDim2.fromOffset(6 + halfBtnW + btnGap, subRowY)

	local portMaxH = math.max(48, math.floor((subRowY - 10) * 0.44))
	local portS = math.min(idW - 8, portMaxH)
	portrait.Root.AnchorPoint = Vector2.new(0.5, 0)
	portrait.Root.Size = UDim2.fromOffset(portS, portS)
	portrait.Root.Position = UDim2.fromOffset(math.floor(col1W / 2), 6)

	local y = 6 + portS + 3
	local rem = math.max(55, subRowY - y - 4)
	local rowH = math.max(11, math.floor(rem / 5))
	metaTag.Size = UDim2.fromOffset(idW, rowH)
	metaTag.Position = UDim2.fromOffset(6, y)
	y += rowH

	local gradeH = math.max(14, math.min(24, rowH + 2))
	gradeBadge.Size = UDim2.fromOffset(math.min(idW, 140), gradeH)
	gradeBadge.AnchorPoint = Vector2.new(0.5, 0)
	gradeBadge.Position = UDim2.fromOffset(math.floor(col1W / 2), y)
	y += gradeH + 2

	local leftRem = math.max(30, subRowY - y - 3)
	local statLineH = math.max(10, math.floor(leftRem / 3))
	genAvgLabel.Size = UDim2.fromOffset(idW, statLineH)
	genAvgLabel.Position = UDim2.fromOffset(6, y)
	y += statLineH

	trnAvgLabel.Size = UDim2.fromOffset(idW, statLineH)
	trnAvgLabel.Position = UDim2.fromOffset(6, y)
	y += statLineH

	powerLabel.Size = UDim2.fromOffset(idW, math.max(10, subRowY - y - 2))
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

	-- 3) Layout direito (Tabela 4 atributos + Card de Passiva)
	local sPad = 8
	local sW = col3W - sPad * 2
	local hdrH = math.max(15, math.floor(H * 0.065))
	local passH = math.clamp(math.floor(H * 0.27), 88, 140)
	statsHeader.Size = UDim2.fromOffset(sW, hdrH)
	statsHeader.Position = UDim2.fromOffset(sPad, 5)

	passiveCard.Size = UDim2.fromOffset(sW, passH)
	passiveCard.Position = UDim2.fromOffset(sPad, H - passH - 6)

	local pw, ph = sW - 12, passH - 8
	local hasSecretRow = secretRow.Visible
	local pTitleH = math.max(16, math.floor(ph * 0.24))
	local secH = if hasSecretRow then math.max(24, math.floor(ph * 0.34)) else 0
	local pDescH = math.max(20, ph - pTitleH - secH - (if hasSecretRow then 6 else 4))

	local icoS = math.max(14, math.min(20, pTitleH))
	passiveIcon.Position = UDim2.fromOffset(6, 4)
	passiveIcon.Size = UDim2.fromOffset(icoS, icoS)
	passiveTitle.Position = UDim2.fromOffset(6 + icoS + 5, 3)
	passiveTitle.Size = UDim2.fromOffset(math.max(40, pw - icoS - 5), pTitleH)

	passiveDesc.Position = UDim2.fromOffset(6, 4 + pTitleH + 2)
	passiveDesc.Size = UDim2.fromOffset(pw, pDescH)

	if hasSecretRow then
		secretRow.Position = UDim2.fromOffset(6, ph - secH + 2)
		secretRow.Size = UDim2.fromOffset(pw, secH)
		local lS = math.max(13, math.min(18, secH - 4))
		secretIcon.Position = UDim2.fromOffset(0, math.floor((secH - lS) / 2))
		secretIcon.Size = UDim2.fromOffset(lS, lS)
		secretText.Position = UDim2.fromOffset(lS + 5, 0)
		secretText.Size = UDim2.fromOffset(math.max(40, pw - lS - 5), secH)
	end

	local listY = 5 + hdrH + 4
	local listH = math.max(80, H - listY - passH - 12)
	local rowGap = math.max(3, math.floor(listH * 0.022))
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

local function sellProtectTag(m, uid: string): string?
	if not profile then
		return "BLOQ."
	end
	if table.find(profile.Team, uid) ~= nil then
		return "NO TIME"
	end
	if profile.TrainingMachine and profile.TrainingMachine.Job and profile.TrainingMachine.Job.Uid == uid then
		return "TREINO"
	end
	if m.Favorite == true then
		return "FAVORITO"
	end
	if m.Awakened == true then
		return "DESPERTO"
	end
	local count = 0
	for _ in pairs(profile.Collection or {}) do
		count += 1
	end
	if count <= 1 then
		return "\u{da}LTIMO"
	end
	return nil
end

local refresh

favBtn.Activated:Connect(function()
	if detailBusy or not currentUid then
		return
	end
	detailBusy = true
	local rf = Remotes:FindFirstChild("ToggleFavorite")
	local callOk, srvOk, srvVal = false, false, nil
	if rf and rf:IsA("RemoteFunction") then
		callOk, srvOk, srvVal = pcall(function()
			return rf:InvokeServer(currentUid)
		end)
	end
	detailBusy = false
	if callOk and srvOk then
		sellConfirmUid = nil
		UI.play("click")
		UI.toast(if srvVal then "Marcado como Favorito!" else "Removido dos Favoritos.")
		if profile and profile.Collection and profile.Collection[currentUid] then
			profile.Collection[currentUid].Favorite = if srvVal then true else nil
		end
		if refresh then
			refresh()
		end
	else
		UI.play("error")
		UI.toast(tostring(srvVal or "N\u{e3}o foi poss\u{ed}vel favoritar."))
	end
end)

sellBtn.Activated:Connect(function()
	if detailBusy or not currentUid or not profile then
		return
	end
	local m = profile.Collection and profile.Collection[currentUid]
	if not m then
		return
	end
	local prot = sellProtectTag(m, currentUid)
	if prot then
		UI.play("error")
		UI.toast("Protegido (" .. prot .. ").")
		return
	end
	if sellConfirmUid ~= currentUid then
		sellConfirmUid = currentUid
		sellConfirmToken += 1
		local tok = sellConfirmToken
		local uidSnap = currentUid
		UI.play("click")
		if refresh then
			refresh()
		end
		task.delay(3, function()
			if sellConfirmToken == tok and sellConfirmUid == uidSnap then
				sellConfirmUid = nil
				if win.IsOpen() and refresh then
					refresh()
				end
			end
		end)
		return
	end
	sellConfirmUid = nil
	detailBusy = true
	local rf = Remotes:FindFirstChild("SellCharacter")
	local callOk, srvOk, srvMsg = false, false, "Servi\u{e7}o indispon\u{ed}vel."
	if rf and rf:IsA("RemoteFunction") then
		callOk, srvOk, srvMsg = pcall(function()
			return rf:InvokeServer(currentUid)
		end)
	end
	detailBusy = false
	if callOk and srvOk then
		UI.play("coin")
		UI.toast(tostring(srvMsg or "Personagem vendido!"))
		portrait.Clear()
		currentUid = nil
		win.Close(true)
	else
		UI.play("error")
		UI.toast(tostring(srvMsg or "N\u{e3}o foi poss\u{ed}vel vender."))
	end
end)

refresh = function()
	local m = profile and currentUid and profile.Collection and profile.Collection[currentUid]
	if not m then
		return
	end
	local def = Characters.Get(m.CharacterId)
	if not def then
		return
	end

	-- Atualiza botoes Favorito e Vender
	local isFav = m.Favorite == true
	local favCol = if isFav then "red" else "panelAlt"
	UI.paint(favBtn, favCol)
	favBtn:SetAttribute("BaseColor", favCol)
	UI.setText(favBtn, if isFav then "FAV: ON" else "FAV")

	local prot = sellProtectTag(m, currentUid)
	local price = Summon.SellPrice[def.Rarity] or Summon.SellPrice.Comum or 50
	if prot then
		UI.setText(sellBtn, prot)
		UI.setDisabled(sellBtn, true, "red")
	else
		local armed = sellConfirmUid == currentUid
		UI.setText(sellBtn, if armed then "CONFIRMAR?" else ("+" .. UI.fmt(price)))
		UI.setDisabled(sellBtn, false, if armed then "orange" else "red")
	end

	local bd = Progression.StatBreakdown(m)
	local rarityText = RARITY_NAME[def.Rarity] or def.Rarity
	local animeText = Characters.AnimeDisplay(Characters.AnimeOf(def.Id))
	local typeText = TypeChart.DisplayName[def.Type] or def.Type
	local awakened = m.Awakened == true
	local awTag = if awakened then "  \u{b7}  DESPERTO" else ""
	win.Title.Text = string.upper(def.Name) .. awTag .. "  \u{b7}  NV " .. tostring(m.Level or 1)

	portrait.Set(currentUid, m)
	metaTag.Text = string.format("%s  \u{b7}  %s  \u{b7}  %s", rarityText, animeText, typeText)

	local rank, rankColor = Genetics.Grade(bd.Genetics)
	UI.paint(gradeBadge, rankColor)
	gradeLabel.Text = string.format("GEN\u{c9}TICA %s  (%.0f%%)", rank, bd.GeneticsAvg)

	genAvgLabel.Text = string.format("Gen\u{e9}tica m\u{e9}dia: <font color='#73F5FF'>%.0f%%</font>", bd.GeneticsAvg)
	trnAvgLabel.Text = string.format("Treino m\u{e9}dio: <font color='#FFCE54'>%.0f%%</font>", bd.TrainingAvg)
	local awPow = if awakened then " (+10% Desperto)" else ""
	powerLabel.Text = string.format("Geral: %d  (Base %d)%s", bd.TotalFinal, bd.TotalBase, awPow)

	-- Atualiza Card de Passiva + pista secreta para Epicos nao despertos
	local passive = Characters.PassiveOf(def.Id, awakened)
	local hasSecretLocked = (not awakened) and Characters.HasAwakening(def.Id)
	if passive then
		local tierColHex = if passive.Tier == "Secret" then "#F578FF" elseif passive.Tier == "Unique" then "#FFD154" else "#76C8FF"
		local tierTag = if passive.Tier == "Secret" then "PASSIVA SECRETA" elseif passive.Tier == "Unique" then "PASSIVA \u{da}NICA" else "PASSIVA"
		UI.paint(passiveCard, if passive.Tier == "Secret" then "purple" elseif passive.Tier == "Unique" then "panelAlt" else "panelAlt")
		UI.setIcon(passiveIcon, if passive.Tier == "Secret" or passive.Tier == "Unique" then "star" else "sparkle")
		passiveTitle.Text = string.format("<font color='%s'>%s</font>  \u{b7}  <b>%s</b>", tierColHex, tierTag, passive.Name)
		passiveDesc.Text = passive.Description or ""
	else
		passiveTitle.Text = "PASSIVA  \u{b7}  Nenhuma"
		passiveDesc.Text = ""
	end
	secretRow.Visible = hasSecretLocked
	if hasSecretLocked then
		secretText.Text = "<font color='#F578FF'><b>Passiva Secreta: ???</b></font>  <font color='#C9C4E8'>" .. Awakening.SecretHint .. "</font>"
	end
	layout()

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
	sellConfirmUid = nil
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
