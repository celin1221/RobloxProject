--[[
	SummonClient (GDD secoes 10 e 13 - Invocacao e Album)
	- Abre no ProximityPrompt do portal (atributo Portal: "Comum" ou "Premium"). Abas Portal, Album e Repetidos.
	- Chances sempre visiveis (cor por raridade), barra da garantia, invocacoes gratis.
	- Portal Premium: banner da semana; escondido onde itens aleatorios pagos sao restritos (atributo PaidRandomRestricted).
	- Invocacao Rapida: botao Invocar 3 e sem animacao. Sorte em Dobro: chances do Portal Comum em dobro na tela.
	- Animacao no cliente: o nucleo do portal abre e um raio sobe na cor da raridade (cinza, azul, roxo, dourado);
	  depois as cartas aparecem uma a uma, com brilho nas raras.
	- Album (obtidos, variantes, premios por tipo e raridade) e Repetidos (fusao e venda). Tambem abre pelo botao Album do HUD.
	O sorteio e todo no servidor (SummonService).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TextChatService = game:GetService("TextChatService")
local StarterGui = game:GetService("StarterGui")

local gui = script.Parent
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Data = ReplicatedStorage:WaitForChild("Data")
local Characters = require(Data:WaitForChild("Characters"))
local Summon = require(Data:WaitForChild("Summon"))
local TypeChart = require(Data:WaitForChild("TypeChart"))
local Benefits = require(Data:WaitForChild("Benefits"))
local UI = require(ReplicatedStorage:WaitForChild("UI"))
local T = UI.Theme
local player = Players.LocalPlayer

local PORTAL = "Comum"
local portal = Summon.Portals[PORTAL]
local bannerName = nil -- destaque da semana (Premium)
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

local canvas = UI.screen(gui)
gui.DisplayOrder = 9

--------------------------------------------------------------------
-- Janela com abas
--------------------------------------------------------------------
local win = UI.window(canvas, { Name = "SummonWindow", Title = "PORTAL COMUM", Icon = "portal", Size = UDim2.fromScale(0.92, 0.86), Aspect = 1.95 })
local body = win.Body
local pages = {}
local currentTab = "Portal"
local refreshMain, refreshAlbum, refreshDupes
local selectTab = UI.tabs(body, {
	{ Id = "Portal", Text = "PORTAL" },
	{ Id = "Album", Text = "\u{c1}LBUM" },
	{ Id = "Dupes", Text = "REPETIDOS" },
}, { Size = UDim2.fromScale(0.6, 0.11), MaxWidth = 0.32 }, function(id)
	currentTab = id
	for name, f in pairs(pages) do
		f.Visible = name == id
	end
	refreshMain()
	if id == "Album" then
		refreshAlbum()
	elseif id == "Dupes" then
		refreshDupes()
	end
end)
local walletHolder, walletLabel = UI.pill(body, "coin", "gold", { Name = "Wallet", Size = UDim2.fromScale(0.3, 0.11), Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(1, 0), Aspect = 3.2, MaxSize = Vector2.new(math.huge, 50) })
local msg = UI.text(body, "", { Name = "Message", Size = UDim2.fromScale(1, 0.07), Position = UDim2.fromScale(0, 0.94), Role = "Small", Color = "hpLow" })

local function page(name)
	local f = UI.frame(body, { Name = name, Size = UDim2.fromScale(1, 0.73), Position = UDim2.fromScale(0, 0.205), Visible = name == "Portal" })
	UI.fillBetween(f, body:FindFirstChild("Tabs"), msg, 6)
	pages[name] = f
	return f
end

--------------------------------------------------------------------
-- Aba Portal
--------------------------------------------------------------------
local portalPage = page("Portal")
local rates, ratesFace = UI.panel(portalPage, { Name = "Rates", Size = UDim2.fromScale(0.47, 1), Color = "slot", Corner = 0.07, Shadow = false })
UI.text(ratesFace, "CHANCES", { Name = "Title", Size = UDim2.fromScale(0.9, 0.12), Position = UDim2.fromScale(0.05, 0.03), Role = "Body", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left })
local rateRows = {}
for i, r in ipairs(Summon.RarityOrder) do
	local row, rface = UI.panel(ratesFace, { Name = "Rate_" .. r, Size = UDim2.fromScale(0.9, 0.15), Position = UDim2.fromScale(0.05, 0.17 + (i - 1) * 0.18), Color = rarityColor(r), Corner = T.Corner.Pill })
	local name = UI.text(rface, UI.upper(Summon.RarityName[r]), { Name = "Name", Size = UDim2.fromScale(0.6, 0.7), Position = UDim2.fromScale(0.05, 0.15), Role = "Body", AlignX = Enum.TextXAlignment.Left })
	local val = UI.text(rface, "", { Name = "Value", Size = UDim2.fromScale(0.36, 0.7), Position = UDim2.fromScale(0.95, 0.15), AnchorPoint = Vector2.new(1, 0), Role = "Body", AlignX = Enum.TextXAlignment.Right })
	if r == "Lendario" then
		UI.shine(row)
	end
	rateRows[r] = { Name = name, Value = val }
end
local shinyLabel = UI.text(ratesFace, "\u{2726} Brilhante: " .. pct(Summon.ShinyChance) .. " em toda invoca\u{e7}\u{e3}o", { Name = "Shiny", Size = UDim2.fromScale(0.9, 0.09), Position = UDim2.fromScale(0.05, 0.89), Role = "Small", Color = "gold", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.5 })

local side = UI.frame(portalPage, { Name = "Actions", Size = UDim2.fromScale(0.5, 1), Position = UDim2.fromScale(0.5, 0) })
local bannerLabel = UI.text(side, "", { Name = "Banner", Size = UDim2.fromScale(1, 0.1), Position = UDim2.fromScale(0, 0), Role = "Small", Color = "lendario", AlignX = Enum.TextXAlignment.Left })
UI.text(side, "GARANTIA DE LEND\u{c1}RIO", { Name = "PityTitle", Size = UDim2.fromScale(0.75, 0.1), Position = UDim2.fromScale(0, 0.11), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left })
local pityValue = UI.text(side, "", { Name = "PityValue", Size = UDim2.fromScale(0.25, 0.1), Position = UDim2.fromScale(1, 0.11), AnchorPoint = Vector2.new(1, 0), Role = "Small", Color = "lendario", AlignX = Enum.TextXAlignment.Right })
local pityBar = UI.bar(side, { Name = "Pity", Size = UDim2.fromScale(1, 0.08), Position = UDim2.fromScale(0, 0.23), FillColor = "lendario", Value = 0 })
local freeHolder, freeFace = UI.panel(side, { Name = "Free", Size = UDim2.fromScale(1, 0.13), Position = UDim2.fromScale(0, 0.37), Color = "slot", Corner = T.Corner.Pill, Shadow = false })
UI.icon(freeHolder, "ticket", { Size = UDim2.fromScale(0.16, 1.3), Position = UDim2.fromScale(0, 0.5), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 3 })
local freeLabel = UI.text(freeFace, "", { Name = "Text", Size = UDim2.fromScale(0.78, 0.7), Position = UDim2.fromScale(0.18, 0.15), Role = "Small", AlignX = Enum.TextXAlignment.Left })

-- botoes de invocar (verdes, com o icone da moeda)
local function summonButton(name, x, w)
	local b, face = UI.button(side, { Name = name, Color = "green", Size = UDim2.fromScale(w, 0.4), Position = UDim2.fromScale(x, 0.58), Corner = 0.22, Sound = false })
	UI.text(face, "", { Name = "Title", Size = UDim2.fromScale(0.9, 0.38), Position = UDim2.fromScale(0.05, 0.08), Role = "Body" })
	local price = UI.frame(face, { Name = "Price", Size = UDim2.fromScale(0.9, 0.36), Position = UDim2.fromScale(0.05, 0.54) })
	local pl = Instance.new("UIListLayout")
	pl.FillDirection = Enum.FillDirection.Horizontal
	pl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	pl.VerticalAlignment = Enum.VerticalAlignment.Center
	pl.Padding = UDim.new(0.04, 0)
	pl.SortOrder = Enum.SortOrder.LayoutOrder
	pl.Parent = price
	UI.icon(price, "coin", { Name = "Icon", Size = UDim2.fromScale(0.3, 1), LayoutOrder = 1 })
	local t = UI.text(price, "", { Name = "Value", Size = UDim2.fromScale(0.6, 1), Role = "Body", AlignX = Enum.TextXAlignment.Left, LayoutOrder = 2 })
	t.AutomaticSize = Enum.AutomaticSize.None
	return b
end
local one = summonButton("Summon1", 0, 0.48)
local three = summonButton("Summon3", 0.52, 0.48)
three.Visible = false
local ten = summonButton("Summon10", 0.52, 0.48)

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
	win.Title.Text = UI.upper(portal.Name)
	UI.paint(win.Header, if gems then "lendario" else "header")
	UI.setIcon(walletHolder.Icon, icon)
	walletLabel.TextColor3 = if gems then T.Palette.gems else T.Palette.gold
	UI.countTo(walletLabel, if gems then (profile.Gems or 0) else (profile.Gold or 0))
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
		bannerLabel.Text = if bannerName then string.format("\u{2605} DESTAQUE: %s (%s)", bannerName, pct((ratesNow.Lendario or 0) * portal.Banner.Share)) else "\u{2605} Destaque da semana: nenhum Lend\u{e1}rio ainda"
	else
		bannerLabel.Text = ""
	end
	local pity = (profile.SummonPity and profile.SummonPity[portal.PityKey]) or 0
	pityValue.Text = string.format("%d/%d", pity, portal.PityAt)
	UI.setBar(pityBar, pity / portal.PityAt, "lendario")
	local free = (profile.Tickets and profile.Tickets[portal.PityKey]) or 0
	freeHolder.Visible = free > 0
	freeLabel.Text = free .. " invoca\u{e7}\u{e3}o" .. (if free > 1 then "\u{f5}es" else "") .. " gr\u{e1}tis"
	local quick = Benefits.Has(profile, "InvocacaoRapida")
	three.Visible = quick
	if quick then
		one.Size = UDim2.fromScale(0.31, 0.4)
		three.Size = UDim2.fromScale(0.31, 0.4)
		three.Position = UDim2.fromScale(0.345, 0.58)
		ten.Size = UDim2.fromScale(0.31, 0.4)
		ten.Position = UDim2.fromScale(0.69, 0.58)
	else
		one.Size = UDim2.fromScale(0.48, 0.4)
		ten.Size = UDim2.fromScale(0.48, 0.4)
		ten.Position = UDim2.fromScale(0.52, 0.58)
	end
	setSummonButton(one, "INVOCAR 1", portal.Cost, icon, free > 0)
	setSummonButton(three, "INVOCAR " .. Benefits.QuickSummonCount, portal.Cost * Benefits.QuickSummonCount, icon, false)
	setSummonButton(ten, "INVOCAR 10", portal.Cost10, icon, false)
end

--------------------------------------------------------------------
-- Animacao do portal (so no cliente)
--------------------------------------------------------------------
local function portalModel()
	local folder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Portals")
	return folder and folder:FindFirstChild("Portal" .. PORTAL)
end

local function playPortal(rarity: string, shiny: boolean)
	local model = portalModel()
	local core = model and model:FindFirstChild("Core")
	if not core then
		task.wait(0.5)
		return
	end
	local color = rarityColor(rarity)
	local baseColor = core.Color
	local light = core:FindFirstChild("Glow")
	-- 1. portal abre: nucleo pulsa e escurece
	TweenService:Create(core, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { Color = Color3.new(0.05, 0.05, 0.1) }):Play()
	task.wait(0.5)
	-- 2. raio sobe na cor da raridade
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
	beam.Transparency = 0.15
	local base = core.Position
	beam.Size = Vector3.new(1, 3, 3)
	beam.CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90))
	beam.Parent = workspace
	TweenService:Create(beam, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(80, 3, 3),
		CFrame = CFrame.new(base + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	}):Play()
	local att = Instance.new("Attachment")
	att.Parent = core
	local burst = Instance.new("ParticleEmitter")
	burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	burst.Enabled = false
	burst.Lifetime = NumberRange.new(0.6, 1.1)
	burst.Speed = NumberRange.new(8, 16)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	burst.Color = ColorSequence.new(if shiny then Color3.fromRGB(255, 245, 170) else color)
	burst.LightEmission = 1
	burst.Parent = att
	burst:Emit(if shiny then 80 else 50)
	task.wait(1.1)
	-- 3. dissipa e volta ao normal
	TweenService:Create(beam, TweenInfo.new(0.4), { Transparency = 1, Size = Vector3.new(80, 0.2, 0.2) }):Play()
	TweenService:Create(core, TweenInfo.new(0.6), { Color = baseColor }):Play()
	if light then
		TweenService:Create(light, TweenInfo.new(0.6), { Brightness = 1.5, Range = 16, Color = baseColor }):Play()
	end
	task.delay(1.2, function()
		beam:Destroy()
		att:Destroy()
	end)
	task.wait(0.3)
end

--------------------------------------------------------------------
-- Cartas reveladas
--------------------------------------------------------------------
local reveal = UI.window(canvas, { Name = "RevealWindow", Title = "RESULTADO", Icon = "star", HeaderColor = "lendario", Size = UDim2.fromScale(0.92, 0.86), Aspect = 1.95,
	OnClose = function(silent)
		if not silent then
			task.defer(function()
				win.Open()
				refreshMain()
			end)
		end
	end,
})
local cardsBox = UI.frame(reveal.Body, { Name = "Cards", Size = UDim2.fromScale(1, 0.74), Position = UDim2.fromScale(0, 0) })
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromScale(0.18, 0.47)
grid.CellPadding = UDim2.fromScale(0.02, 0.04)
grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
grid.VerticalAlignment = Enum.VerticalAlignment.Center
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = cardsBox
local gridAspect = Instance.new("UIAspectRatioConstraint")
gridAspect.AspectRatio = 0.78
gridAspect.Parent = grid
local revealInfo = UI.text(reveal.Body, "", { Name = "Info", Size = UDim2.fromScale(0.72, 0.2), Position = UDim2.fromScale(0, 0.78), Role = "Small", Color = "gold", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.5 })
UI.button(reveal.Body, { Name = "OK", Text = "OK", Icon = "tick", Layout = "row", Color = "green", Size = UDim2.fromScale(0.24, 0.17), Position = UDim2.fromScale(1, 0.8), AnchorPoint = Vector2.new(1, 0), Role = "Heading",
	OnClick = function()
		reveal.Close()
	end,
})

local function showCards(results)
	UI.clear(cardsBox)
	local info = {}
	grid.CellSize = if #results <= 3 then UDim2.fromScale(0.26, 0.92) else UDim2.fromScale(0.18, 0.47)
	reveal.Open()
	for i, r in ipairs(results) do
		local rare = r.Rarity == "Epico" or r.Rarity == "Lendario" or r.Variant ~= nil
		local card, face = UI.panel(cardsBox, { Name = "Card" .. i, Color = rarityColor(r.Rarity), Corner = T.Corner.Card, LayoutOrder = i, Visible = false })
		if r.Variant then
			UI.stroke(face, Color3.fromRGB(255, 245, 170), 1.4)
		end
		UI.text(face, r.Name, { Name = "Name", Size = UDim2.fromScale(0.9, 0.2), Position = UDim2.fromScale(0.05, 0.08), Role = "Heading" })
		UI.chip(face, UI.upper(Summon.RarityName[r.Rarity]), "slot", { Name = "Rarity", Size = UDim2.fromScale(0.84, 0.14), Position = UDim2.fromScale(0.08, 0.34) })
		UI.chip(face, UI.upper(typeName(r.Type)), T.Types[r.Type] or TypeChart.Color[r.Type] or T.Palette.grey, { Name = "Type", Size = UDim2.fromScale(0.6, 0.12), Position = UDim2.fromScale(0.2, 0.53) })
		local tags = {}
		if r.Variant then
			table.insert(tags, "\u{2726} " .. r.Variant)
		end
		if r.New then
			table.insert(tags, "NOVO")
		end
		if r.Banner then
			table.insert(tags, "DESTAQUE")
		end
		UI.text(face, table.concat(tags, "  "), { Name = "Tags", Size = UDim2.fromScale(0.9, 0.16), Position = UDim2.fromScale(0.05, 0.74), Role = "Small", Color = "gold" })
		if rare then
			UI.shine(card)
		end
		if r.Rolled ~= r.Rarity then
			table.insert(info, "Sorteado " .. Summon.RarityName[r.Rolled] .. ": o elenco ainda n\u{e3}o tem essa raridade, veio " .. r.Name .. ".")
		end
		for _, line in ipairs(r.Album or {}) do
			table.insert(info, line)
		end
		-- carta aparece com pulo
		task.delay(0.12 * i, function()
			card.Visible = true
			local sc = Instance.new("UIScale")
			sc.Scale = 0.2
			sc.Parent = card
			TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			UI.play(if rare then "reward" else "click")
		end)
	end
	revealInfo.Text = table.concat(info, "\n")
end

local function doSummon(count)
	if busy then
		return
	end
	busy = true
	msg.Text = ""
	local ok, res = Remotes.Summon:InvokeServer(PORTAL, count)
	if not ok then
		msg.Text = res or "N\u{e3}o foi poss\u{ed}vel invocar."
		UI.play("error")
		busy = false
		return
	end
	UI.play("purchase")
	win.Close(true)
	local best, shiny = 1, false
	for _, r in ipairs(res) do
		best = math.max(best, table.find(Summon.RarityOrder, r.Rarity) or 1)
		shiny = shiny or r.Variant ~= nil
	end
	-- Invocacao Rapida pula a animacao
	if not Benefits.Has(profile, "InvocacaoRapida") then
		playPortal(Summon.RarityOrder[best], shiny)
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
-- Aba Album
--------------------------------------------------------------------
local albumPage = page("Album")
local albumGrid = UI.scroll(albumPage, { Name = "Grid", Size = UDim2.fromScale(0.62, 1), Columns = 3, CellAspect = 0.95 })
local goals, goalsFace = UI.panel(albumPage, { Name = "Goals", Size = UDim2.fromScale(0.36, 1), Position = UDim2.fromScale(0.64, 0), Color = "slot", Corner = 0.06, Shadow = false })
local goalsList = UI.scroll(goalsFace, { Name = "List", Size = UDim2.fromScale(0.94, 0.94), Position = UDim2.fromScale(0.03, 0.03), Gap = 0.015 })

refreshAlbum = function()
	UI.clear(albumGrid)
	UI.clear(goalsList)
	if not profile then
		return
	end
	local owned = profile.Album and profile.Album.Owned or {}
	local claimed = profile.Album and profile.Album.Claimed or {}
	local ids = {}
	for id, def in pairs(Characters.List) do
		if not def.Prototype then -- prototipos de teste fora do album
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
	local byType, byRarity = {}, {}
	for i, id in ipairs(ids) do
		local def = Characters.List[id]
		byType[def.Type] = byType[def.Type] or { 0, 0 }
		byRarity[def.Rarity] = byRarity[def.Rarity] or { 0, 0 }
		byType[def.Type][2] += 1
		byRarity[def.Rarity][2] += 1
		local has = owned[id] ~= nil
		if has then
			byType[def.Type][1] += 1
			byRarity[def.Rarity][1] += 1
		end
		local cell, face = UI.panel(albumGrid, { Name = "Entry_" .. id, Color = if has then rarityColor(def.Rarity) else "slot", Corner = T.Corner.Card, LayoutOrder = i })
		UI.text(face, if has then def.Name else "???", { Name = "Name", Size = UDim2.fromScale(0.9, 0.26), Position = UDim2.fromScale(0.05, 0.08), Role = "Body", Color = if has then "onDark" else "inkSoft" })
		UI.chip(face, UI.upper(typeName(def.Type)), if has then (T.Types[def.Type] or T.Palette.grey) else "grey", { Name = "Type", Size = UDim2.fromScale(0.7, 0.18), Position = UDim2.fromScale(0.15, 0.42) })
		local variants = {}
		for v in pairs(has and owned[id].Variants or {}) do
			table.insert(variants, "\u{2726}" .. v)
		end
		UI.text(face, table.concat(variants, " "), { Name = "Variants", Size = UDim2.fromScale(0.9, 0.2), Position = UDim2.fromScale(0.05, 0.72), Role = "Small", Color = "gold" })
		if not has then
			UI.icon(face, "lock", { Name = "Lock", Size = UDim2.fromScale(0.3, 0.3), Position = UDim2.fromScale(0.5, 0.7), AnchorPoint = Vector2.new(0.5, 0.5) })
		end
	end
	local order = 0
	local function goalRow(text, color, done)
		order += 1
		local row, f = UI.panel(goalsList, { Name = "Goal" .. order, Size = UDim2.fromScale(1, 0), Aspect = 5, Color = color or "panelAlt", Corner = T.Corner.Pill, Shadow = false, LayoutOrder = order })
		UI.text(f, text, { Name = "Text", Size = UDim2.fromScale(0.9, 0.7), Position = UDim2.fromScale(0.05, 0.15), Role = "Small", AlignX = Enum.TextXAlignment.Left })
		if done then
			UI.icon(row, "tick", { Size = UDim2.fromScale(0.2, 0.9), Position = UDim2.fromScale(0.97, 0.5), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 3 })
		end
	end
	local function header(text)
		order += 1
		local h = UI.text(goalsList, text, { Name = "H" .. order, Size = UDim2.fromScale(1, 0), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, LayoutOrder = order, Aspect = 7 })
		return h
	end
	header("Pr\u{ea}mio por grupo: " .. Summon.AlbumReward.Gold .. " gold + " .. Summon.AlbumReward.Gems .. " gemas")
	header("TIPOS")
	local types = {}
	for t in pairs(byType) do
		table.insert(types, t)
	end
	table.sort(types)
	for _, t in ipairs(types) do
		local v = byType[t]
		goalRow(string.format("%s  %d/%d", typeName(t), v[1], v[2]), T.Types[t], claimed["Tipo:" .. t])
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
UI.text(dupPage, string.format("%d c\u{f3}pias iguais viram +1 estrela (at\u{e9} %d, +%d%% de atributos cada). C\u{f3}pias no time n\u{e3}o s\u{e3}o usadas.", Summon.Stars.CopiesPerStar, Summon.Stars.Max, Summon.Stars.BonusPerStar * 100), { Name = "Help", Size = UDim2.fromScale(1, 0.1), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.4 })
local dupList = UI.scroll(dupPage, { Name = "List", Size = UDim2.fromScale(1, 0.88), Position = UDim2.fromScale(0, 0.12) })

refreshDupes = function()
	UI.clear(dupList)
	if not profile then
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
	for i, id in ipairs(ids) do
		local g = groups[id]
		local def = Characters.Get(id)
		local row, face = UI.panel(dupList, { Name = "Row_" .. id, Size = UDim2.fromScale(0.98, 0), Aspect = 7.5, Color = "panelAlt", Corner = 0.24, LayoutOrder = i })
		UI.stroke(face, rarityColor(def.Rarity), 1.2)
		UI.text(face, string.format("%s  x%d   %s", def.Name, g.Count, string.rep("\u{2605}", g.Stars)), { Name = "Name", Size = UDim2.fromScale(0.44, 0.46), Position = UDim2.fromScale(0.03, 0.08), Role = "Body", AlignX = Enum.TextXAlignment.Left })
		UI.text(face, string.format("%s \u{b7} %d no time", Summon.RarityName[def.Rarity], g.InTeam), { Name = "Info", Size = UDim2.fromScale(0.44, 0.3), Position = UDim2.fromScale(0.03, 0.6), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.4 })
		local canFuse = g.Count >= Summon.Stars.CopiesPerStar
		local canSell = g.Count >= 2
		UI.button(face, { Name = "Fuse_" .. id, Text = "FUNDIR +1\u{2605}", Color = if canFuse then "purple" else "grey", Size = UDim2.fromScale(0.24, 0.74), Position = UDim2.fromScale(0.48, 0.13), Role = "Small", Sound = false,
			OnClick = function()
				local ok, text = Remotes.Fuse:InvokeServer(id)
				msg.TextColor3 = if ok then T.Palette.gold else T.Palette.hpLow
				msg.Text = text or (if ok then "Pronto." else "N\u{e3}o foi poss\u{ed}vel.")
				UI.play(if ok then "reward" else "error")
			end,
		})
		local sell, sface = UI.button(face, { Name = "Sell_" .. id, Color = if canSell then "green" else "grey", Size = UDim2.fromScale(0.24, 0.74), Position = UDim2.fromScale(0.74, 0.13), Sound = false,
			OnClick = function()
				local ok, text = Remotes.SellDuplicate:InvokeServer(id)
				msg.TextColor3 = if ok then T.Palette.gold else T.Palette.hpLow
				msg.Text = text or (if ok then "Pronto." else "N\u{e3}o foi poss\u{ed}vel.")
				UI.play(if ok then "purchase" else "error")
			end,
		})
		UI.icon(sface, "coin", { Size = UDim2.fromScale(0.3, 0.8), Position = UDim2.fromScale(0.05, 0.1) })
		UI.text(sface, "+" .. UI.fmt(Summon.SellPrice[def.Rarity]), { Name = "Price", Size = UDim2.fromScale(0.6, 0.7), Position = UDim2.fromScale(0.36, 0.15), Role = "Small", AlignX = Enum.TextXAlignment.Left })
	end
end

--------------------------------------------------------------------
-- Perfil, portal e chat
--------------------------------------------------------------------
local function apply(p)
	if typeof(p) ~= "table" then
		return
	end
	profile = p
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
	if def.Banner then
		task.spawn(function()
			local ok, name = pcall(function()
				return Remotes:WaitForChild("SummonBanner"):InvokeServer(id)
			end)
			if ok and PORTAL == id then
				bannerName = name
				refreshMain()
			end
		end)
	end
	msg.Text = ""
	reveal.Close(true)
	win.Open()
	selectTab(tab or "Portal")
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
		win.Close(true)
		reveal.Close(true)
	end
end)

Remotes:WaitForChild("Announce").OnClientEvent:Connect(function(text)
	local shown = false
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general then
			general:DisplaySystemMessage("<font color=\"#ffd84a\">" .. text .. "</font>")
			shown = true
		end
	end)
	if not shown then
		pcall(function()
			StarterGui:SetCore("ChatMakeSystemMessage", { Text = text, Color = Color3.fromRGB(255, 216, 74) })
		end)
	end
end)
