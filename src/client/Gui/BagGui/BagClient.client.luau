--[[
	BagClient (GDD secoes 7 e 10 - Mochila)
	30 espacos, pilhas de 99. Fora de batalha: Pocoes e Reviver, escolhendo o personagem.
	Os outros itens aparecem com "so em batalha". Abre pelo botao Mochila do HUD (UI.open("Bag")).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local gui = script.Parent
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Data = ReplicatedStorage:WaitForChild("Data")
local Items = require(Data:WaitForChild("Items"))
local Benefits = require(Data:WaitForChild("Benefits"))
local Characters = require(Data:WaitForChild("Characters"))
local Summon = require(Data:WaitForChild("Summon"))
local Progression = require(Data:WaitForChild("Progression"))
local Genetics = require(Data:WaitForChild("Genetics"))
local Awakening = require(Data:WaitForChild("Awakening"))
local CharacterFilter = require(ReplicatedStorage:WaitForChild("CharacterFilter"))
local UI = require(ReplicatedStorage:WaitForChild("UI"))
local T = UI.Theme

local profile = nil
local selected = nil -- item escolhido
local activeTab = "Itens"
local confirmSellUid: string? = nil
local confirmSellToken = 0
local sellBusy = false

local ITEM_ICON = { Pocao = "potion", Superpocao = "potion", Hiperpocao = "potion", CuraStatus = "heal", Eter = "potion", Reviver = "heal", SeloContrato = "seal", SeloSuperior = "seal", DoceComum = "doce_comum", DoceRaro = "doce_raro", DoceEpico = "doce_epico" }
local RARITY_COLOR = { Comum = "comum", Raro = "raro", Epico = "epico", Lendario = "lendario", Secreto = "secreto" }
local RARITY_TEXT = { Comum = "COMUM", Raro = "RARO", Epico = "\u{c9}PICO", Lendario = "LEND\u{c1}RIO", Secreto = "SECRETO" }

local canvas = UI.screen(gui)
gui.DisplayOrder = 9
local win = UI.window(canvas, { Name = "BagWindow", Title = "MOCHILA", Icon = "bag", HeaderColor = "green", Size = UDim2.fromScale(0.92, 0.88), MaxSize = Vector2.new(1120, 580) })
local body = win.Body

local itemsView = UI.frame(body, { Name = "ItemsView" })
local slotsLabel = UI.text(itemsView, "", { Name = "Slots", Size = UDim2.fromScale(0.48, 0.075), Position = UDim2.fromScale(0, 0), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.4 })
local itemsList = UI.scroll(itemsView, { Name = "Items", Size = UDim2.fromScale(0.48, 0.90), Position = UDim2.fromScale(0, 0.095), Columns = 2, CellAspect = 1.22, Gap = 0.036, Flat = true })
local side, sideFace = UI.panel(itemsView, { Name = "Side", Size = UDim2.fromScale(0.5, 1), Position = UDim2.fromScale(0.5, 0), Color = "slot", Corner = 0.06, Shadow = false, StrokeMult = 0.8 })
local targetTitle = UI.text(sideFace, "", { Name = "TargetTitle", Size = UDim2.fromScale(0.92, 0.12), Position = UDim2.fromScale(0.04, 0.03), Role = "Body", AlignX = Enum.TextXAlignment.Left })
local targets = UI.scroll(sideFace, { Name = "Targets", Size = UDim2.fromScale(0.96, 0.82), Position = UDim2.fromScale(0.02, 0.16), Gap = 0.024 })

local charsView = UI.frame(body, { Name = "CharsView", Visible = false })
local charFilterRow = UI.frame(charsView, { Name = "Filters" })
local filterState = CharacterFilter.CreateState()
local charCount = UI.text(charFilterRow, "", { Name = "Count", Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Right, StrokeMult = 0.4 })

local sellBar, sellBarFace = UI.panel(charsView, { Name = "SellBar", Color = "slot", Corner = 0.24, Shadow = false, StrokeMult = 0.75 })
local capSummaryLbl = UI.text(sellBarFace, "", { Name = "CapSummary", Role = "Small", Color = "onDark", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.45 })
local sellHintLbl = UI.text(sellBarFace, "Protegidos: Time, Favoritos, Treino e Despertos", { Name = "SellHint", Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.35 })
local sellAllBtn = UI.button(sellBarFace, {
	Name = "SellAllUnfav",
	Text = "VENDER N\u{c3}O-FAV (0)",
	Icon = "coin",
	Layout = "row",
	Color = "red",
	Role = "Small",
	Corner = 0.26,
	Sound = false,
})
local sellAllMin = sellAllBtn:FindFirstChildOfClass("UISizeConstraint")
if sellAllMin then
	sellAllMin.MinSize = Vector2.new(160, 36)
end

local charsList = UI.scroll(charsView, { Name = "Characters", Gap = 0.024, Flat = true })

-- Modal de confirmacao para vender todos os nao-favoritos de uma vez
local sellAllOverlay = Instance.new("TextButton")
sellAllOverlay.Name = "SellAllModal"
sellAllOverlay.Size = UDim2.fromScale(1, 1)
sellAllOverlay.BackgroundColor3 = Color3.fromRGB(6, 8, 22)
sellAllOverlay.BackgroundTransparency = 0.3
sellAllOverlay.Text = ""
sellAllOverlay.AutoButtonColor = false
sellAllOverlay.Visible = false
sellAllOverlay.ZIndex = 30
sellAllOverlay.Parent = body
UI.corner(sellAllOverlay, 0.04)

local sellModalCard, sellModalFace = UI.panel(sellAllOverlay, {
	Name = "Card",
	Size = UDim2.fromScale(0.80, 0.84),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	MaxSize = Vector2.new(540, 310),
	Color = "panel",
	Corner = 0.09,
	ZIndex = 31,
})
UI.stroke(sellModalFace, T.Palette.red, 1.35)
UI.icon(sellModalFace, "coin", {
	Name = "Icon",
	Size = UDim2.fromScale(0.11, 0.14),
	Position = UDim2.fromScale(0.04, 0.04),
	AspectAxis = Enum.DominantAxis.Height,
	ZIndex = 32,
})
UI.text(sellModalFace, "VENDER N\u{c3}O-FAVORITOS", {
	Name = "Title",
	Size = UDim2.fromScale(0.78, 0.14),
	Position = UDim2.fromScale(0.16, 0.04),
	Role = "Heading",
	Color = "gold",
	AlignX = Enum.TextXAlignment.Left,
	ZIndex = 32,
})
local sellModalSummary = UI.text(sellModalFace, "", {
	Name = "Summary",
	Size = UDim2.fromScale(0.92, 0.14),
	Position = UDim2.fromScale(0.04, 0.20),
	Role = "Body",
	Color = "onDark",
	Rich = true,
	AlignX = Enum.TextXAlignment.Left,
	ZIndex = 32,
})
local sellModalBreakdown = UI.text(sellModalFace, "", {
	Name = "Breakdown",
	Size = UDim2.fromScale(0.92, 0.11),
	Position = UDim2.fromScale(0.04, 0.35),
	Role = "Small",
	Color = "inkSoft",
	AlignX = Enum.TextXAlignment.Left,
	StrokeMult = 0.4,
	ZIndex = 32,
})
local sellModalWarn = UI.text(sellModalFace, "", {
	Name = "Warning",
	Size = UDim2.fromScale(0.92, 0.10),
	Position = UDim2.fromScale(0.04, 0.47),
	Role = "Small",
	Color = "hpLow",
	AlignX = Enum.TextXAlignment.Left,
	StrokeMult = 0.45,
	ZIndex = 32,
})
local sellModalProtect = UI.text(sellModalFace, "Protegidos: Time, Favoritos, Treino e Despertos (sempre sobra ao menos 1).", {
	Name = "ProtectNote",
	Size = UDim2.fromScale(0.92, 0.10),
	Position = UDim2.fromScale(0.04, 0.58),
	Role = "Small",
	Color = "inkSoft",
	AlignX = Enum.TextXAlignment.Left,
	StrokeMult = 0.35,
	ZIndex = 32,
})
local sellModalCancelBtn = UI.button(sellModalFace, {
	Name = "CancelSellAll",
	Text = "CANCELAR",
	Color = "grey",
	Size = UDim2.fromScale(0.42, 0.17),
	Position = UDim2.fromScale(0.04, 0.96),
	AnchorPoint = Vector2.new(0, 1),
	Corner = 0.24,
	Role = "Small",
	ZIndex = 33,
})
local sellModalConfirmBtn = UI.button(sellModalFace, {
	Name = "ConfirmSellAll",
	Text = "CONFIRMAR VENDA",
	Icon = "coin",
	Layout = "row",
	Color = "red",
	Size = UDim2.fromScale(0.48, 0.17),
	Position = UDim2.fromScale(0.96, 0.96),
	AnchorPoint = Vector2.new(1, 1),
	Corner = 0.24,
	Role = "Small",
	Sound = false,
	ZIndex = 33,
})
for _, mb in ipairs({ sellModalCancelBtn, sellModalConfirmBtn }) do
	local mc = mb:FindFirstChildOfClass("UISizeConstraint")
	if mc then
		mc.MinSize = Vector2.new(100, 32)
	end
end

local matsView = UI.frame(body, { Name = "MaterialsView", Visible = false })
local matsHint = UI.text(matsView, "Materiais de Despertar n\u{e3}o ocupam espa\u{e7}o na mochila. Descubra onde us\u{e1}-los explorando a floresta!", {
	Name = "Hint", Size = UDim2.fromScale(1, 0.085), Position = UDim2.fromScale(0, 0),
	Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.4,
})
local matsList = UI.scroll(matsView, { Name = "Materials", Size = UDim2.fromScale(1, 0.90), Position = UDim2.fromScale(0, 0.10), Columns = 2, CellAspect = 2.6, Gap = 0.03, Flat = true })

local msg = UI.text(body, "", { Name = "Message", Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -20), Role = "Small", Color = "gold" })

local searchBox, animeBtn, rarityBtn, typeBtn, sortBtn

local function show(ok, text)
	msg.TextColor3 = if ok then UI.P.gold else UI.P.hpLow
	msg.Text = text or ""
	UI.play(if ok then "reward" else "error")
end

local refresh

local function layoutViews()
	local rawW, rawH = UI.unscaledSize(body)
	local W, H = math.floor(rawW + 0.5), math.floor(rawH + 0.5)
	if W < 10 or H < 10 then
		return
	end
	local tabClear = math.clamp(math.floor(UI.height(body) * 0.018 + 0.5), 11, 18)
	local topOffset = T.TouchMin + tabClear
	local msgH = 20
	local contentH = math.max(T.TouchMin, H - topOffset - msgH - 4)
	itemsView.Position = UDim2.fromOffset(0, topOffset)
	itemsView.Size = UDim2.fromOffset(W, contentH)
	charsView.Position = UDim2.fromOffset(0, topOffset)
	charsView.Size = UDim2.fromOffset(W, contentH)
	matsView.Position = UDim2.fromOffset(0, topOffset)
	matsView.Size = UDim2.fromOffset(W, contentH)

	local twoRows = W < 820
	local g = math.max(8, math.floor(W * 0.014))
	local bh = T.TouchMin
	local rowGap = 10
	local fh = if twoRows then (bh * 2 + rowGap) else bh
	charFilterRow.Position = UDim2.fromOffset(0, 0)
	charFilterRow.Size = UDim2.fromOffset(W, fh)

	if searchBox and animeBtn and rarityBtn and typeBtn and sortBtn then
		if twoRows then
			local sw = math.floor(W * 0.64)
			searchBox.Root.Size = UDim2.fromOffset(sw, bh)
			searchBox.Root.Position = UDim2.fromOffset(0, 0)
			charCount.Visible = true
			charCount.AnchorPoint = Vector2.new(1, 0)
			charCount.Size = UDim2.fromOffset(math.max(40, W - sw - g), bh)
			charCount.Position = UDim2.fromOffset(W, 0)

			local avail = W - g * 3
			local wA = math.floor(avail * 0.28)
			local wR = math.floor(avail * 0.21)
			local wT = math.floor(avail * 0.21)
			local wS = avail - wA - wR - wT
			local y2 = bh + rowGap
			animeBtn.Size = UDim2.fromOffset(wA, bh)
			animeBtn.Position = UDim2.fromOffset(0, y2)
			rarityBtn.Size = UDim2.fromOffset(wR, bh)
			rarityBtn.Position = UDim2.fromOffset(wA + g, y2)
			typeBtn.Size = UDim2.fromOffset(wT, bh)
			typeBtn.Position = UDim2.fromOffset(wA + wR + g * 2, y2)
			sortBtn.Size = UDim2.fromOffset(wS, bh)
			sortBtn.Position = UDim2.fromOffset(wA + wR + wT + g * 3, y2)
		else
			local avail = W - g * 5
			local wSearch = math.floor(avail * 0.24)
			local wA = math.floor(avail * 0.175)
			local wR = math.floor(avail * 0.13)
			local wT = math.floor(avail * 0.13)
			local wS = math.floor(avail * 0.195)
			local wCount = avail - wSearch - wA - wR - wT - wS
			local x = 0
			searchBox.Root.Size = UDim2.fromOffset(wSearch, bh)
			searchBox.Root.Position = UDim2.fromOffset(x, 0)
			x += wSearch + g
			animeBtn.Size = UDim2.fromOffset(wA, bh)
			animeBtn.Position = UDim2.fromOffset(x, 0)
			x += wA + g
			rarityBtn.Size = UDim2.fromOffset(wR, bh)
			rarityBtn.Position = UDim2.fromOffset(x, 0)
			x += wR + g
			typeBtn.Size = UDim2.fromOffset(wT, bh)
			typeBtn.Position = UDim2.fromOffset(x, 0)
			x += wT + g
			sortBtn.Size = UDim2.fromOffset(wS, bh)
			sortBtn.Position = UDim2.fromOffset(x, 0)
			charCount.Visible = true
			charCount.AnchorPoint = Vector2.new(1, 0)
			charCount.Size = UDim2.fromOffset(math.max(40, wCount), bh)
			charCount.Position = UDim2.fromOffset(W, 0)
		end
	end

	local barGap = 8
	local barY = fh + barGap
	local barH = math.max(44, math.min(52, math.floor(contentH * 0.15)))
	sellBar.Position = UDim2.fromOffset(0, barY)
	sellBar.Size = UDim2.fromOffset(W, barH)

	local sBtnW = math.clamp(math.floor(W * 0.34), 172, 276)
	local sBtnH = math.max(36, barH - 8)
	sellAllBtn.AnchorPoint = Vector2.new(1, 0.5)
	sellAllBtn.Size = UDim2.fromOffset(sBtnW, sBtnH)
	sellAllBtn.Position = UDim2.new(1, -6, 0.5, 0)

	local infoW = math.max(80, W - sBtnW - 20)
	local halfH = math.floor((barH - 6) / 2)
	capSummaryLbl.Position = UDim2.fromOffset(10, 3)
	capSummaryLbl.Size = UDim2.fromOffset(infoW, halfH)
	sellHintLbl.Position = UDim2.fromOffset(10, 3 + halfH)
	sellHintLbl.Size = UDim2.fromOffset(infoW, barH - 6 - halfH)

	local ly = barY + barH + barGap
	charsList.Position = UDim2.fromOffset(0, ly)
	charsList.Size = UDim2.fromOffset(W, math.max(T.TouchMin, contentH - ly))
end
body:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutViews)

local function protectionReason(m, uid: string): string?
	if not profile then
		return nil
	end
	if table.find(profile.Team, uid) ~= nil then
		return "TIME"
	end
	if profile.TrainingMachine and profile.TrainingMachine.Job and profile.TrainingMachine.Job.Uid == uid then
		return "TREINO"
	end
	if m.Favorite == true then
		return "FAV"
	end
	if m.Awakened == true then
		return "DESPERTO"
	end
	return nil
end

local function computeSellAllSummary()
	local totalCount = 0
	local favCount = 0
	local sellable = {}
	if profile and typeof(profile.Collection) == "table" then
		for uid, m in pairs(profile.Collection) do
			totalCount += 1
			if m.Favorite == true then
				favCount += 1
			end
			if protectionReason(m, uid) == nil then
				local def = Characters.Get(m.CharacterId)
				if def then
					table.insert(sellable, { Uid = uid, Member = m, Def = def })
				end
			end
		end
	end
	if #sellable >= totalCount and #sellable > 0 then
		table.remove(sellable)
	end
	local totalGold = 0
	local byRarity = { Comum = 0, Raro = 0, Epico = 0, Lendario = 0, Secreto = 0 }
	local highWarn = 0
	for _, e in ipairs(sellable) do
		local r = e.Def.Rarity or "Comum"
		byRarity[r] = (byRarity[r] or 0) + 1
		totalGold += Summon.SellPrice[r] or Summon.SellPrice.Comum or 50
		if r == "Lendario" or r == "Secreto" or e.Member.Variant == "Brilhante" then
			highWarn += 1
		end
	end
	return {
		TotalCount = totalCount,
		MaxCap = if profile then Benefits.CollectionMax(profile) else Benefits.CollectionBase,
		FavCount = favCount,
		Count = #sellable,
		Gold = totalGold,
		ByRarity = byRarity,
		HighWarn = highWarn,
	}
end

local function openSellAllModal()
	if not profile or sellBusy then
		return
	end
	local sum = computeSellAllSummary()
	if sum.Count <= 0 then
		show(false, "Nenhum personagem eleg\u{ed}vel para vender.")
		return
	end
	sellModalSummary.Text = string.format(
		"Vender <b>%d %s</b> por <font color='#FFD154'><b>+%s Gold</b></font>?",
		sum.Count,
		if sum.Count == 1 then "personagem" else "personagens",
		UI.fmt(sum.Gold)
	)
	local parts = {}
	for _, r in ipairs(Summon.RarityOrder) do
		local n = sum.ByRarity[r] or 0
		if n > 0 then
			table.insert(parts, string.format("%s: %d", Summon.RarityName[r] or r, n))
		end
	end
	sellModalBreakdown.Text = table.concat(parts, "  \u{b7}  ")
	if sum.HighWarn > 0 then
		sellModalWarn.Visible = true
		sellModalWarn.Text = string.format("ATEN\u{c7}\u{c3}O: inclui %d Lend\u{e1}rio/Secreto/Brilhante sem Favorito!", sum.HighWarn)
	else
		sellModalWarn.Visible = false
		sellModalWarn.Text = ""
	end
	UI.setText(sellModalConfirmBtn, "VENDER (+" .. UI.fmt(sum.Gold) .. ")")
	sellAllOverlay.Visible = true
	UI.play("open")
end

sellAllBtn.Activated:Connect(openSellAllModal)
sellModalCancelBtn.Activated:Connect(function()
	sellAllOverlay.Visible = false
end)
sellAllOverlay.Activated:Connect(function()
	if not sellBusy then
		sellAllOverlay.Visible = false
	end
end)
sellModalConfirmBtn.Activated:Connect(function()
	if sellBusy then
		return
	end
	sellBusy = true
	UI.setDisabled(sellModalConfirmBtn, true, "red")
	local rf = Remotes:FindFirstChild("SellUnfavorited")
	local callOk, srvOk, srvMsg = false, false, "Servi\u{e7}o indispon\u{ed}vel."
	if rf and rf:IsA("RemoteFunction") then
		callOk, srvOk, srvMsg = pcall(function()
			return rf:InvokeServer()
		end)
	end
	sellBusy = false
	UI.setDisabled(sellModalConfirmBtn, false, "red")
	sellAllOverlay.Visible = false
	confirmSellUid = nil
	if not callOk then
		show(false, "Erro de conex\u{e3}o ao vender.")
		return
	end
	if srvOk then
		UI.play("coin")
		msg.TextColor3 = UI.P.gold
		msg.Text = tostring(srvMsg or "Personagens vendidos!")
	else
		show(false, tostring(srvMsg or "N\u{e3}o foi poss\u{ed}vel vender."))
	end
end)

local function refreshCharacters()
	if not profile then
		UI.clear(charsList)
		charCount.Text = ""
		capSummaryLbl.Text = ""
		UI.setText(sellAllBtn, "VENDER N\u{c3}O-FAV (0)")
		UI.setDisabled(sellAllBtn, true, "red")
		return
	end
	local list, statsByUid = filterState.Apply(profile.Collection)
	local sum = computeSellAllSummary()
	charCount.Text = string.format("%d/%d", #list, sum.TotalCount)
	capSummaryLbl.Text = string.format("Cole\u{e7}\u{e3}o: %d/%d  \u{b7}  Favoritos: %d", sum.TotalCount, sum.MaxCap, sum.FavCount)
	local fillRatio = if sum.MaxCap > 0 then sum.TotalCount / sum.MaxCap else 0
	capSummaryLbl.TextColor3 = if fillRatio >= 0.95 then T.Palette.hpLow elseif fillRatio >= 0.80 then T.Palette.gold else T.Palette.onDark
	UI.setText(sellAllBtn, string.format("VENDER N\u{c3}O-FAV (%d)", sum.Count))
	UI.setDisabled(sellAllBtn, sum.Count <= 0 or sellBusy, "red")

	UI.keepScroll(charsList, function()
		UI.clear(charsList)
		if #list == 0 then
			UI.text(charsList, "Nenhum personagem encontrado.", { Name = "Empty", Size = UDim2.fromScale(0.96, 0), Aspect = 10, Role = "Small", Color = "inkSoft" })
			return
		end
		for i, uid in ipairs(list) do
			local m = profile.Collection[uid]
			local def = m and Characters.Get(m.CharacterId)
			if def then
				local stats = statsByUid[uid]
				local total = CharacterFilter.TotalStats(stats)
				local curHp = Progression.CurrentHp(m)
				local onTeam = table.find(profile.Team, uid) ~= nil
				local isFav = m.Favorite == true
				local prot = protectionReason(m, uid)
				if not prot and sum.TotalCount <= 1 then
					prot = "\u{da}LTIMO"
				end
				local price = Summon.SellPrice[def.Rarity] or Summon.SellPrice.Comum or 50
				local genAvg = math.floor(Genetics.Average(m.Genetics) + 0.5)

				local _, face = UI.panel(charsList, {
					Name = "Char_" .. uid,
					Color = "panelAlt",
					Size = UDim2.fromScale(1, 0),
					Aspect = 9.8,
					RowMax = 66,
					LayoutOrder = i,
					Corner = 0.2,
					Shadow = false,
					StrokeColor = if isFav then Color3.fromRGB(255, 92, 138) else nil,
					StrokeMult = if isFav then 0.95 else 0.75,
				})
				UI.chip(face, RARITY_TEXT[def.Rarity] or def.Rarity, RARITY_COLOR[def.Rarity] or "comum", {
					Name = "Rarity", Size = UDim2.fromScale(0.122, 0.56), Position = UDim2.fromScale(0.012, 0.22), Role = "Small",
				})
				local titleParts = { def.Name }
				if m.Variant and m.Variant ~= "" then
					table.insert(titleParts, "(" .. m.Variant .. ")")
				end
				table.insert(titleParts, "Nv." .. tostring(m.Level))
				if onTeam then
					table.insert(titleParts, "[TIME]")
				elseif m.Awakened == true then
					table.insert(titleParts, "[DESPERTO]")
				end
				UI.text(face, table.concat(titleParts, "  "), {
					Name = "Title", Size = UDim2.fromScale(0.425, 0.42), Position = UDim2.fromScale(0.144, 0.08), Role = "Small", AlignX = Enum.TextXAlignment.Left,
				})
				local hpColor = if curHp <= 0 then "hpLow" else "gold"
				local statsText = string.format("GERAL %d  \u{b7}  HP %d/%d  \u{b7}  GEN %d%%", total, curHp, stats.HP, genAvg)
				UI.text(face, statsText, {
					Name = "Stats", Size = UDim2.fromScale(0.425, 0.40), Position = UDim2.fromScale(0.144, 0.52), Role = "Small", Color = hpColor, AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.45,
				})

				-- Botao Favorito (coracao)
				local favBtn = UI.button(face, {
					Name = "FavBtn",
					Icon = "heart",
					Layout = "icon",
					Color = if isFav then "red" else "slot",
					Size = UDim2.fromScale(0.068, 0.78),
					Position = UDim2.fromScale(0.578, 0.11),
					Corner = 0.28,
					Sound = false,
					OnClick = function()
						if sellBusy then
							return
						end
						sellBusy = true
						local rf = Remotes:FindFirstChild("ToggleFavorite")
						local callOk, srvOk, srvVal = false, false, nil
						if rf and rf:IsA("RemoteFunction") then
							callOk, srvOk, srvVal = pcall(function()
								return rf:InvokeServer(uid)
							end)
						end
						sellBusy = false
						if callOk and srvOk then
							confirmSellUid = nil
							UI.play("click")
							msg.TextColor3 = UI.P.gold
							msg.Text = if srvVal then (def.Name .. " marcado como Favorito.") else (def.Name .. " removido dos Favoritos.")
						else
							show(false, tostring(srvVal or "N\u{e3}o foi poss\u{ed}vel favoritar."))
						end
					end,
				})
				local favMin = favBtn:FindFirstChildOfClass("UISizeConstraint")
				if favMin then
					favMin.MinSize = Vector2.new(34, 34)
				end

				-- Botao Vender individual (confirmacao em 2 cliques) ou selo Protegido
				if prot then
					local pBox, pFace = UI.panel(face, {
						Name = "ProtectedTag",
						Color = "slot",
						Size = UDim2.fromScale(0.198, 0.72),
						Position = UDim2.fromScale(0.656, 0.14),
						Corner = 0.28,
						Shadow = false,
					})
					local _ = pBox
					UI.icon(pFace, if prot == "FAV" then "heart" else "lock", {
						Name = "Icon",
						Size = UDim2.fromScale(0.22, 0.62),
						Position = UDim2.fromScale(0.08, 0.5),
						AnchorPoint = Vector2.new(0, 0.5),
						AspectAxis = Enum.DominantAxis.Height,
						Tint = if prot == "FAV" then Color3.fromRGB(255, 92, 138) else T.Palette.inkSoft,
					})
					UI.text(pFace, prot, {
						Name = "Label",
						Size = UDim2.fromScale(0.64, 0.78),
						Position = UDim2.fromScale(0.32, 0.11),
						Role = "Small",
						Color = if prot == "FAV" then Color3.fromRGB(255, 138, 174) else "inkSoft",
						AlignX = Enum.TextXAlignment.Left,
						StrokeMult = 0.4,
					})
				else
					local isArmed = confirmSellUid == uid
					local sellBtn = UI.button(face, {
						Name = "SellBtn",
						Text = if isArmed then "CONFIRMAR?" else ("+" .. UI.fmt(price)),
						Icon = "coin",
						Layout = "row",
						Color = if isArmed then "orange" else "red",
						Size = UDim2.fromScale(0.198, 0.78),
						Position = UDim2.fromScale(0.656, 0.11),
						Corner = 0.28,
						Role = "Small",
						Sound = false,
						OnClick = function()
							if sellBusy then
								return
							end
							if confirmSellUid ~= uid then
								confirmSellUid = uid
								confirmSellToken += 1
								local tok = confirmSellToken
								UI.play("click")
								refreshCharacters()
								task.delay(3, function()
									if confirmSellToken == tok and confirmSellUid == uid then
										confirmSellUid = nil
										if win.IsOpen() and activeTab == "Personagens" then
											refreshCharacters()
										end
									end
								end)
								return
							end
							confirmSellUid = nil
							sellBusy = true
							local rf = Remotes:FindFirstChild("SellCharacter")
							local callOk, srvOk, srvMsg = false, false, "Servi\u{e7}o indispon\u{ed}vel."
							if rf and rf:IsA("RemoteFunction") then
								callOk, srvOk, srvMsg = pcall(function()
									return rf:InvokeServer(uid)
								end)
							end
							sellBusy = false
							if callOk and srvOk then
								UI.play("coin")
								msg.TextColor3 = UI.P.gold
								msg.Text = tostring(srvMsg or "Vendido!")
							else
								show(false, tostring(srvMsg or "N\u{e3}o foi poss\u{ed}vel vender."))
							end
						end,
					})
					local sellMin = sellBtn:FindFirstChildOfClass("UISizeConstraint")
					if sellMin then
						sellMin.MinSize = Vector2.new(72, 34)
					end
				end

				-- Botao INFO (abre tela de detalhes do personagem)
				local infoBtn = UI.button(face, {
					Name = "InfoBtn",
					Text = "INFO",
					Color = "blue",
					Size = UDim2.fromScale(0.124, 0.78),
					Position = UDim2.fromScale(0.864, 0.11),
					Corner = 0.28,
					Role = "Small",
					OnClick = function()
						UI.open("CharacterDetail", uid)
					end,
				})
				local infoMin = infoBtn:FindFirstChildOfClass("UISizeConstraint")
				if infoMin then
					infoMin.MinSize = Vector2.new(44, 34)
				end
			end
		end
	end)
end

local function filterText()
	UI.setText(animeBtn, CharacterFilter.LabelFor("Anime", filterState.Anime()))
	UI.setText(rarityBtn, CharacterFilter.LabelFor("Rarity", filterState.Rarity()))
	UI.setText(typeBtn, CharacterFilter.LabelFor("Type", filterState.Type()))
	UI.setText(sortBtn, CharacterFilter.LabelFor("Sort", filterState.Sort()))
end

local function applyCharFilter()
	filterText()
	charsList.CanvasPosition = Vector2.zero
	refreshCharacters()
end

searchBox = UI.searchBox(charFilterRow, {
	Name = "SearchBox",
	Placeholder = "Buscar nome...",
	Role = "Small",
	OnChanged = function(text)
		filterState.SetSearch(text)
		charsList.CanvasPosition = Vector2.zero
		refreshCharacters()
	end,
})
animeBtn = UI.button(charFilterRow, {
	Name = "AnimeFilter", Text = "ANIME: TODOS", Icon = "book", Layout = "row", Color = "blue", Size = UDim2.fromOffset(120, T.TouchMin), Role = "Small",
	OnClick = function()
		filterState.NextAnime()
		applyCharFilter()
	end,
})
rarityBtn = UI.button(charFilterRow, {
	Name = "RarityFilter", Text = "TODAS", Icon = "star", Layout = "row", Color = "purple", Size = UDim2.fromOffset(100, T.TouchMin), Role = "Small",
	OnClick = function()
		filterState.NextRarity()
		applyCharFilter()
	end,
})
typeBtn = UI.button(charFilterRow, {
	Name = "TypeFilter", Text = "TODOS", Icon = "tipo_fogo", Layout = "row", Color = "teal", Size = UDim2.fromOffset(100, T.TouchMin), Role = "Small",
	OnClick = function()
		local nextType = filterState.NextType()
		local ti = UI.TypeIcon[nextType]
		local icon = typeBtn.Face:FindFirstChild("Icon")
		if icon then
			UI.setIcon(icon, ti or "tipo_fogo")
			icon.ImageTransparency = if ti then 0 else 0.5
		end
		applyCharFilter()
	end,
})
sortBtn = UI.button(charFilterRow, {
	Name = "Sort", Text = "RARIDADE", Icon = "arrow", Layout = "row", Color = "orange", Size = UDim2.fromOffset(120, T.TouchMin), Role = "Small",
	OnClick = function()
		filterState.NextSort()
		applyCharFilter()
	end,
})
do
	local icon = typeBtn.Face:FindFirstChild("Icon")
	if icon then
		icon.ImageTransparency = 0.5
	end
end

local selectTab = UI.tabs(body, {
	{ Id = "Itens", Text = "ITENS", Icon = "bag" },
	{ Id = "Materiais", Text = "MATERIAIS", Icon = "sparkle" },
	{ Id = "Personagens", Text = "PERSONAGENS", Icon = "team" },
}, { ActiveColor = "green", MaxHeight = T.TouchMin, MaxWidth = 0.31 }, function(id)
	activeTab = id
	sellAllOverlay.Visible = false
	confirmSellUid = nil
	itemsView.Visible = id == "Itens"
	matsView.Visible = id == "Materiais"
	charsView.Visible = id == "Personagens"
	msg.Text = ""
	if refresh then
		refresh()
	end
end)

local function openBagItemPicker(itemId: string)
	local item = Items.Get(itemId)
	if not item or not profile then
		return
	end
	local isCandy = item.Kind == "XpCandy"
	local isRevive = item.Kind == "Revive"
	UI.pickCharacter({
		Title = "USAR " .. UI.upper(item.Name),
		HeaderColor = if isCandy then "purple" else "green",
		Icon = ITEM_ICON[itemId] or "bag",
		ActionLabel = "USAR " .. UI.upper(item.Name),
		ActionColor = if isCandy then "purple" else "green",
		ReturnTo = "Bag",
		KeepOpen = true,
		Sound = false,
		SubtitleFn = function(prof)
			local qty = (prof.Bag and prof.Bag[itemId]) or 0
			return string.format("Restam x%d · %s", qty, item.Short or item.Description or "")
		end,
		FormatSelected = function(_uid, m, def)
			if isCandy then
				local need = Progression.XpToNext(m.Level or 1)
				local xpTxt = if need > 0 then string.format("XP %d/%d", m.Xp or 0, need) else "N\u{ed}vel m\u{e1}ximo"
				return string.format("<b>%s</b> Nv.%d · %s", def.Name, m.Level or 1, xpTxt)
			end
			local hp, max = Progression.CurrentHp(m)
			local hpTxt = if hp <= 0 then "Desmaiado" else string.format("HP %d/%d", hp, max)
			return string.format("<b>%s</b> Nv.%d · %s", def.Name, m.Level or 1, hpTxt)
		end,
		GetBadge = function(_uid, m)
			if isCandy then
				if (m.Level or 1) >= Progression.MaxLevel then
					return "NV. M\u{c1}X", "gold"
				end
				return "NV. " .. tostring(m.Level or 1), "purple"
			end
			local hp, max = Progression.CurrentHp(m)
			if isRevive then
				if hp <= 0 then
					return "DESMAIADO", "green"
				end
				return "VIVO", "slot"
			end
			if hp <= 0 then
				return "DESMAIADO", "red"
			elseif hp < max then
				return string.format("%d/%d", hp, max), "green"
			end
			return "CHEIO", "slot"
		end,
		IsEligible = function(_uid, m, _def, prof)
			local qty = (prof.Bag and prof.Bag[itemId]) or 0
			if qty <= 0 then
				return false, "Sem " .. item.Name .. " na mochila."
			end
			if isCandy then
				if (m.Level or 1) >= Progression.MaxLevel then
					return false, "J\u{e1} est\u{e1} no n\u{ed}vel m\u{e1}ximo."
				end
				return true, nil
			end
			local hp, max = Progression.CurrentHp(m)
			if isRevive then
				if hp > 0 then
					return false, "N\u{e3}o est\u{e1} desmaiado."
				end
				return true, nil
			end
			if hp <= 0 then
				return false, "Desmaiado. Use um Reviver."
			elseif hp >= max then
				return false, "HP j\u{e1} est\u{e1} cheio."
			end
			return true, nil
		end,
		OnPick = function(uid)
			local beforeQty = (profile and profile.Bag and profile.Bag[itemId]) or 0
			local ok, text2 = Remotes.UseItem:InvokeServer(itemId, uid)
			if not ok then
				return false, text2
			end
			UI.play("reward")
			local shouldClose = beforeQty <= 1
			return true, text2, shouldClose
		end,
	})
end

local function refreshTargets()
	local item = selected and Items.Get(selected)
	if not item or not profile then
		UI.clear(targets)
		targetTitle.Text = "Escolha um item"
		return
	end
	local canUseOutside = item.OutsideBattle == true or item.Kind == "XpCandy"
	if not canUseOutside then
		UI.clear(targets)
		targetTitle.Text = item.Name .. ": s\u{f3} em batalha"
		return
	end
	targetTitle.Text = "Usar " .. item.Name .. " em:"
	UI.keepScroll(targets, function()
		UI.clear(targets)
		-- Botao principal: abre o HUD visual da Equipe com filtros e cartoes 3D para escolher qualquer personagem da colecao
		UI.button(targets, {
			Name = "OpenCollectionPicker",
			Text = "ESCOLHER NA COLE\u{c7}\u{c3}O",
			Icon = "team",
			Layout = "row",
			Color = "blue",
			Size = UDim2.new(0.98, 0, 0, T.TouchMin + 4),
			LayoutOrder = 0,
			Corner = 0.24,
			Role = "Small",
			OnClick = function()
				openBagItemPicker(selected)
			end,
		})
		-- Atalho rapido para o time ativo (ate 6 personagens)
		for i, uid in ipairs(profile.Team) do
			local m = profile.Collection[uid]
			local def = m and Characters.Get(m.CharacterId)
			if def then
				local hp, max = Progression.CurrentHp(m)
				local ok
				if item.Kind == "XpCandy" then
					ok = (m.Level or 1) < Progression.MaxLevel
				elseif item.Kind == "Revive" then
					ok = hp <= 0
				else
					ok = hp > 0 and hp < max
				end
				local b, face = UI.button(targets, {
					Name = "Target_" .. uid, Color = if ok then "green" else "grey", Size = UDim2.fromScale(0.98, 0), Aspect = 4.6, RowMax = 72, LayoutOrder = i, Corner = 0.24,
					Sound = false,
					OnClick = function()
						local success, text2 = Remotes.UseItem:InvokeServer(selected, uid)
						show(success, text2)
					end,
				})
				UI.text(face, def.Name .. "  Nv." .. m.Level .. "  (time)", { Name = "Name", Size = UDim2.fromScale(0.62, 0.44), Position = UDim2.fromScale(0.05, 0.08), Role = "Small", AlignX = Enum.TextXAlignment.Left })
				local bar = UI.bar(face, { Name = "Hp", Size = UDim2.fromScale(0.6, 0.2), Position = UDim2.fromScale(0.05, 0.62) })
				local ratio = if max > 0 then hp / max else 0
				UI.setBar(bar, ratio, if ratio > 0.5 then "hpHigh" elseif ratio > 0.2 then "hpMid" else "hpLow", true)
				UI.text(face, if hp <= 0 then "Desmaiado" else (hp .. "/" .. max), { Name = "Hp", Size = UDim2.fromScale(0.28, 0.5), Position = UDim2.fromScale(0.95, 0.25), AnchorPoint = Vector2.new(1, 0), Role = "Small", AlignX = Enum.TextXAlignment.Right })
			end
		end
	end)
end

local function refreshMaterials()
	UI.clear(matsList)
	local mats = (profile and profile.Materials) or {}
	for i, matId in ipairs(Awakening.MaterialOrder) do
		local def = Awakening.GetMaterial(matId)
		if def then
			local qty = math.max(0, math.floor(tonumber(mats[matId]) or 0))
			local _, face = UI.panel(matsList, {
				Name = "Mat_" .. matId,
				Color = if qty > 0 then "panelAlt" else "slot",
				Corner = 0.16,
				Shadow = false,
				StrokeColor = if qty > 0 then def.Color else nil,
				StrokeMult = 0.8,
				LayoutOrder = i,
			})
			local ico = UI.icon(face, def.Icon or "sparkle", {
				Name = "Icon",
				Size = UDim2.fromScale(0.18, 0.62),
				Position = UDim2.fromScale(0.04, 0.19),
			})
			ico.ImageTransparency = if qty > 0 then 0 else 0.45
			UI.text(face, def.Name, {
				Name = "MatName",
				Size = UDim2.fromScale(0.56, 0.38),
				Position = UDim2.fromScale(0.24, 0.10),
				Role = "Small",
				AlignX = Enum.TextXAlignment.Left,
			})
			UI.text(face, "x" .. qty, {
				Name = "Qty",
				Size = UDim2.fromScale(0.18, 0.42),
				Position = UDim2.fromScale(0.96, 0.08),
				AnchorPoint = Vector2.new(1, 0),
				Role = "Body",
				Color = if qty > 0 then "gold" else "inkSoft",
				AlignX = Enum.TextXAlignment.Right,
			})
			UI.text(face, "Origem: " .. (def.Source or ""), {
				Name = "Source",
				Size = UDim2.fromScale(0.72, 0.42),
				Position = UDim2.fromScale(0.24, 0.50),
				Role = "Small",
				Color = "inkSoft",
				AlignX = Enum.TextXAlignment.Left,
				Wrap = true,
				StrokeMult = 0.35,
			})
		end
	end
end

refresh = function()
	if not profile then
		return
	end
	if activeTab == "Personagens" then
		refreshCharacters()
		return
	elseif activeTab == "Materiais" then
		refreshMaterials()
		return
	end
	slotsLabel.Text = string.format("%d/%d espa\u{e7}os \u{b7} pilhas de %d", Items.SlotsUsed(profile.Bag), Benefits.BagSlots(profile, Items.BagSlots), Items.StackLimit)
	UI.clear(itemsList)
	local any = false
	for _, id in ipairs(Items.Sorted()) do
		local n = profile.Bag[id] or 0
		if n > 0 then
			any = true
			local item = Items.Get(id)
			local isSelected = selected == id
			local b, face = UI.button(itemsList, {
				Name = "Item_" .. id, Color = if isSelected then "blue" else "panelAlt", LayoutOrder = item.Order or 99, Corner = 0.16, Shadow = false, StrokeColor = if isSelected then T.Palette.gold else nil, StrokeMult = 0.85,
				OnClick = function()
					if selected ~= id then
						targets.CanvasPosition = Vector2.zero
					end
					selected = id
					msg.Text = ""
					refresh()
				end,
			})
			UI.text(face, "x" .. n, { Name = "Count", Size = UDim2.fromScale(0.44, 0.17), Position = UDim2.fromScale(0.93, 0.05), AnchorPoint = Vector2.new(1, 0), Role = "Small", Color = "gold", AlignX = Enum.TextXAlignment.Right })
			UI.icon(face, ITEM_ICON[id] or "bag", { Name = "Icon", Size = UDim2.fromScale(0.32, 0.32), Position = UDim2.fromScale(0.5, 0.21), AnchorPoint = Vector2.new(0.5, 0) })
			UI.text(face, item.Name, { Name = "ItemName", Size = UDim2.fromScale(0.9, 0.2), Position = UDim2.fromScale(0.05, 0.56), Role = "Small" })
			UI.text(face, if item.OutsideBattle or item.TeamUse then (item.Short or item.Description or "") else "S\u{f3} em batalha", { Name = "Desc", Size = UDim2.fromScale(0.9, 0.16), Position = UDim2.fromScale(0.05, 0.77), Role = "Small", Color = "inkSoft", StrokeMult = 0.4 })
		end
	end
	if not any then
		UI.text(itemsList, "Mochila vazia. Compre itens na loja da pra\u{e7}a.", { Name = "Empty", Size = UDim2.fromScale(1, 0.3), Role = "Small", Color = "inkSoft" })
	end
	if selected and (profile.Bag[selected] or 0) <= 0 then
		selected = nil
	end
	refreshTargets()
end

Remotes:WaitForChild("ProfileUpdated").OnClientEvent:Connect(function(p)
	profile = p
	if win.IsOpen() then
		refresh()
	end
end)
task.spawn(function()
	local ok, p = pcall(function()
		return Remotes:WaitForChild("GetProfile"):InvokeServer()
	end)
	if ok and p then
		profile = p
	end
end)

UI.onOpen("Bag", function(requestedTab)
	local wantTab = if typeof(requestedTab) == "string" and (requestedTab == "Itens" or requestedTab == "Materiais" or requestedTab == "Personagens")
		then requestedTab
		else nil
	if win.IsOpen() and not wantTab then
		sellAllOverlay.Visible = false
		confirmSellUid = nil
		win.Close()
		return
	end
	if wantTab then
		activeTab = wantTab
	end
	sellAllOverlay.Visible = false
	confirmSellUid = nil
	msg.Text = ""
	if not win.IsOpen() then
		win.Open()
	end
	layoutViews()
	selectTab(activeTab)
	task.defer(layoutViews)
end)
