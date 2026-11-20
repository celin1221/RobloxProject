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
local Progression = require(Data:WaitForChild("Progression"))
local CharacterFilter = require(ReplicatedStorage:WaitForChild("CharacterFilter"))
local UI = require(ReplicatedStorage:WaitForChild("UI"))
local T = UI.Theme

local profile = nil
local selected = nil -- item escolhido
local activeTab = "Itens"

local ITEM_ICON = { Pocao = "potion", Superpocao = "potion", Hiperpocao = "potion", CuraStatus = "heal", Eter = "potion", Reviver = "heal", SeloContrato = "seal", SeloSuperior = "seal", DoceComum = "doce_comum", DoceRaro = "doce_raro", DoceEpico = "doce_epico" }
local RARITY_COLOR = { Comum = "comum", Raro = "raro", Epico = "epico", Lendario = "lendario" }
local RARITY_TEXT = { Comum = "COMUM", Raro = "RARO", Epico = "\u{c9}PICO", Lendario = "LEND\u{c1}RIO" }

local canvas = UI.screen(gui)
gui.DisplayOrder = 9
local win = UI.window(canvas, { Name = "BagWindow", Title = "MOCHILA", Icon = "bag", HeaderColor = "green", Size = UDim2.fromScale(0.92, 0.88), MaxSize = Vector2.new(1120, 580) })
local body = win.Body

local itemsView = UI.frame(body, { Name = "ItemsView" })
local slotsLabel = UI.text(itemsView, "", { Name = "Slots", Size = UDim2.fromScale(0.46, 0.09), Position = UDim2.fromScale(0, 0), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.4 })
local itemsList = UI.scroll(itemsView, { Name = "Items", Size = UDim2.fromScale(0.48, 0.89), Position = UDim2.fromScale(0, 0.11), Columns = 2, CellAspect = 1.25 })
local side, sideFace = UI.panel(itemsView, { Name = "Side", Size = UDim2.fromScale(0.5, 1), Position = UDim2.fromScale(0.5, 0), Color = "slot", Corner = 0.06, Shadow = false })
local targetTitle = UI.text(sideFace, "", { Name = "TargetTitle", Size = UDim2.fromScale(0.92, 0.13), Position = UDim2.fromScale(0.04, 0.03), Role = "Body", AlignX = Enum.TextXAlignment.Left })
local targets = UI.scroll(sideFace, { Name = "Targets", Size = UDim2.fromScale(0.96, 0.82), Position = UDim2.fromScale(0.02, 0.17) })

local charsView = UI.frame(body, { Name = "CharsView", Visible = false })
local charFilterRow = UI.frame(charsView, { Name = "Filters" })
local filterState = CharacterFilter.CreateState()
local charCount = UI.text(charFilterRow, "", { Name = "Count", Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Right, StrokeMult = 0.4 })
local charsList = UI.scroll(charsView, { Name = "Characters", Gap = 0.015 })

local msg = UI.text(body, "", { Name = "Message", Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -20), Role = "Small", Color = "gold" })

local searchBox, animeBtn, rarityBtn, typeBtn, sortBtn

local function show(ok, text)
	msg.TextColor3 = if ok then UI.P.gold else UI.P.hpLow
	msg.Text = text or ""
	UI.play(if ok then "reward" else "error")
end

local refresh

local function layoutViews()
	local W, H = body.AbsoluteSize.X, body.AbsoluteSize.Y
	if W < 10 or H < 10 then
		return
	end
	local topOffset = T.TouchMin + 6
	local msgH = 20
	local contentH = math.max(T.TouchMin, H - topOffset - msgH - 4)
	itemsView.Position = UDim2.fromOffset(0, topOffset)
	itemsView.Size = UDim2.fromOffset(W, contentH)
	charsView.Position = UDim2.fromOffset(0, topOffset)
	charsView.Size = UDim2.fromOffset(W, contentH)

	local twoRows = W < 820
	local g = math.max(4, math.floor(W * 0.01))
	local bh = T.TouchMin
	local fh = if twoRows then (bh * 2 + 4) else bh
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
			local y2 = bh + 4
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

	local ly = fh + 6
	charsList.Position = UDim2.fromOffset(0, ly)
	charsList.Size = UDim2.fromOffset(W, math.max(T.TouchMin, contentH - ly))
end
body:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutViews)

local function refreshCharacters()
	UI.clear(charsList)
	if not profile then
		charCount.Text = ""
		return
	end
	local list, statsByUid = filterState.Apply(profile.Collection)
	local totalCount = 0
	for _ in pairs(profile.Collection) do
		totalCount += 1
	end
	charCount.Text = string.format("%d/%d", #list, totalCount)
	if #list == 0 then
		UI.text(charsList, "Nenhum personagem encontrado.", { Name = "Empty", Size = UDim2.fromScale(0.96, 0.35), Role = "Small", Color = "inkSoft" })
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
			local _, face = UI.panel(charsList, {
				Name = "Char_" .. uid, Color = "panelAlt", Size = UDim2.fromScale(0.98, 0), Aspect = 11.2, RowMax = 62, LayoutOrder = i, Corner = 0.22, Shadow = false,
			})
			UI.chip(face, RARITY_TEXT[def.Rarity] or def.Rarity, RARITY_COLOR[def.Rarity] or "comum", {
				Name = "Rarity", Size = UDim2.fromScale(0.15, 0.56), Position = UDim2.fromScale(0.015, 0.22), Role = "Small",
			})
			local titleParts = { def.Name }
			if m.Variant and m.Variant ~= "" then
				table.insert(titleParts, "(" .. m.Variant .. ")")
			end
			table.insert(titleParts, "Nv." .. tostring(m.Level))
			if onTeam then
				table.insert(titleParts, "[TIME]")
			end
			UI.text(face, table.concat(titleParts, "  "), {
				Name = "Title", Size = UDim2.fromScale(0.79, 0.42), Position = UDim2.fromScale(0.185, 0.08), Role = "Small", AlignX = Enum.TextXAlignment.Left,
			})
			local hpColor = if curHp <= 0 then "hpLow" else "gold"
			local statsText = string.format("GERAL %d  \u{b7}  HP %d/%d  \u{b7}  ATQ %d  \u{b7}  DEF %d  \u{b7}  VEL %d", total, curHp, stats.HP, stats.Attack, stats.Defense, stats.Speed)
			UI.text(face, statsText, {
				Name = "Stats", Size = UDim2.fromScale(0.79, 0.40), Position = UDim2.fromScale(0.185, 0.52), Role = "Small", Color = hpColor, AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.45,
			})
		end
	end
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
	{ Id = "Personagens", Text = "PERSONAGENS", Icon = "team" },
}, { ActiveColor = "green", MaxHeight = T.TouchMin, MaxWidth = 0.44 }, function(id)
	activeTab = id
	itemsView.Visible = id == "Itens"
	charsView.Visible = id == "Personagens"
	msg.Text = ""
	if refresh then
		refresh()
	end
end)

local function refreshTargets()
	UI.clear(targets)
	local item = selected and Items.Get(selected)
	if not item or not profile then
		targetTitle.Text = "Escolha um item"
		return
	end
	if item.TeamUse then
		targetTitle.Text = item.Name .. ": use no menu Time, escolhendo o personagem"
		return
	end
	if not item.OutsideBattle then
		targetTitle.Text = item.Name .. ": s\u{f3} em batalha"
		return
	end
	targetTitle.Text = "Usar " .. item.Name .. " em:"
	-- time primeiro, depois a base
	local order = {}
	for _, uid in ipairs(profile.Team) do
		table.insert(order, uid)
	end
	local rest = {}
	for uid in pairs(profile.Collection) do
		if not table.find(order, uid) then
			table.insert(rest, uid)
		end
	end
	table.sort(rest)
	for _, uid in ipairs(rest) do
		table.insert(order, uid)
	end
	for i, uid in ipairs(order) do
		local m = profile.Collection[uid]
		local def = m and Characters.Get(m.CharacterId)
		if def then
			local hp, max = Progression.CurrentHp(m)
			local ok
			if item.Kind == "Revive" then
				ok = hp <= 0
			else
				ok = hp > 0 and hp < max
			end
			local b, face = UI.button(targets, {
				Name = "Target_" .. uid, Color = if ok then "green" else "grey", Size = UDim2.fromScale(0.98, 0), Aspect = 4.6, LayoutOrder = i, Corner = 0.24,
				Sound = false,
				OnClick = function()
					local success, text2 = Remotes.UseItem:InvokeServer(selected, uid)
					show(success, text2)
				end,
			})
			UI.text(face, def.Name .. "  Nv." .. m.Level .. (if table.find(profile.Team, uid) then "  (time)" else ""), { Name = "Name", Size = UDim2.fromScale(0.62, 0.44), Position = UDim2.fromScale(0.05, 0.08), Role = "Small", AlignX = Enum.TextXAlignment.Left })
			local bar = UI.bar(face, { Name = "Hp", Size = UDim2.fromScale(0.6, 0.2), Position = UDim2.fromScale(0.05, 0.62) })
			local ratio = if max > 0 then hp / max else 0
			UI.setBar(bar, ratio, if ratio > 0.5 then "hpHigh" elseif ratio > 0.2 then "hpMid" else "hpLow", true)
			UI.text(face, if hp <= 0 then "Desmaiado" else (hp .. "/" .. max), { Name = "Hp", Size = UDim2.fromScale(0.28, 0.5), Position = UDim2.fromScale(0.95, 0.25), AnchorPoint = Vector2.new(1, 0), Role = "Small", AlignX = Enum.TextXAlignment.Right })
		end
	end
end

refresh = function()
	if not profile then
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
			local b, face = UI.button(itemsList, {
				Name = "Item_" .. id, Color = if selected == id then "blue" else "panelAlt", LayoutOrder = item.Order or 99, Corner = 0.18,
				OnClick = function()
					selected = id
					msg.Text = ""
					refresh()
				end,
			})
			UI.icon(face, ITEM_ICON[id] or "bag", { Name = "Icon", Size = UDim2.fromScale(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.06), AnchorPoint = Vector2.new(0.5, 0) })
			UI.text(face, "x" .. n, { Name = "Count", Size = UDim2.fromScale(0.36, 0.24), Position = UDim2.fromScale(0.95, 0.06), AnchorPoint = Vector2.new(1, 0), Role = "Body", Color = "gold", AlignX = Enum.TextXAlignment.Right })
			UI.text(face, item.Name, { Name = "ItemName", Size = UDim2.fromScale(0.9, 0.2), Position = UDim2.fromScale(0.05, 0.58), Role = "Small" })
			UI.text(face, if item.OutsideBattle or item.TeamUse then (item.Short or item.Description or "") else "S\u{f3} em batalha", { Name = "Desc", Size = UDim2.fromScale(0.9, 0.16), Position = UDim2.fromScale(0.05, 0.8), Role = "Small", Color = "inkSoft", StrokeMult = 0.4 })
		end
	end
	if not any then
		UI.text(itemsList, "Mochila vazia. Compre itens na loja da pra\u{e7}a.", { Name = "Empty", Size = UDim2.fromScale(1, 0.3), Role = "Small", Color = "inkSoft" })
	end
	if selected and (profile.Bag[selected] or 0) <= 0 then
		selected = nil
	end
	refreshTargets()
	if activeTab == "Personagens" then
		refreshCharacters()
	end
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

UI.onOpen("Bag", function()
	if win.IsOpen() then
		win.Close()
		return
	end
	msg.Text = ""
	selectTab(activeTab)
	win.Open()
	task.defer(layoutViews)
end)
