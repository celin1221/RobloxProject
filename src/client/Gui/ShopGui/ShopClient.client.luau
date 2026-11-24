--[[
	ShopClient (GDD secoes 7, 8, 9 e 10 - Loja)
	Abas: Itens (gold) + Vender Minerio, Beneficios (Robux ou gemas) e Gemas (pacotes em Robux).
	Abre no prompt da loja da praca ou no botao Loja do HUD. O servidor valida tudo;
	compras em Robux passam pelo MarketplaceService (IDs em Data/ProductIds; 0 = ainda nao criado).
	Preco sempre em botao verde com o icone da moeda.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer

local gui = script.Parent
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Items = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("Items"))
local Base = require(ReplicatedStorage.Data:WaitForChild("Base"))
local Benefits = require(ReplicatedStorage.Data:WaitForChild("Benefits"))
local ProductIds = require(ReplicatedStorage.Data:WaitForChild("ProductIds"))
local UI = require(ReplicatedStorage:WaitForChild("UI"))
local T = UI.Theme

local profile = nil
local ITEM_ICON = { Pocao = "potion", Superpocao = "potion", Hiperpocao = "potion", CuraStatus = "heal", Eter = "potion", Reviver = "heal", SeloContrato = "seal_basic", SeloSuperior = "seal_superior" }
-- Visual por item: o Selo de Contrato e simples; o Superior tem cor forte, moldura dourada e brilho
local ITEM_STYLE = {
	SeloContrato = { Color = "slot", Frame = Color3.fromRGB(154, 163, 181), FrameMult = 0.9 },
	SeloSuperior = { Color = "purple", Frame = Color3.fromRGB(255, 200, 60), FrameMult = 1.9, Shine = true, NameColor = "gold" },
}
local BENEFIT_ICON = { MochilaAmpliada = "bag", GoldEmDobro = "coin", CuraAutomatica = "heal", XpEmDobro = "star", VIP = "trophy", MineradorExtra = "pickaxe", InvocacaoRapida = "portal", SorteEmDobro = "star", DepositoAmpliado = "house" }

local canvas = UI.screen(gui)
gui.DisplayOrder = 9
local win = UI.window(canvas, { Name = "ShopWindow", Title = "LOJA", Icon = "shop", HeaderColor = "teal", Size = UDim2.fromScale(0.92, 0.86), Aspect = 1.95 })
local body = win.Body
local tab = "Itens"
local refresh
local pages = {}
local selectTab = UI.tabs(body, { { Id = "Itens", Text = "ITENS" }, { Id = "Beneficios", Text = "BENEF\u{cd}CIOS" }, { Id = "Gemas", Text = "GEMAS" } }, { Size = UDim2.fromScale(0.58, 0.11), MaxWidth = 0.32, ActiveColor = "teal" }, function(id)
	tab = id
	for name, f in pairs(pages) do
		f.Visible = name == id
	end
	refresh()
end)
-- carteira (gold e gemas)
local wallet = UI.frame(body, { Name = "Wallet", Size = UDim2.fromScale(0.38, 0.11), Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(1, 0) })
UI.clampHeight(wallet, T.TouchMin, 50) -- mesma altura e alinhamento das abas
local _, goldLabel = UI.pill(wallet, "coin", "gold", { Name = "Gold", Size = UDim2.fromScale(0.52, 1), Aspect = 3.2, Role = "Body" })
local _, gemsLabel = UI.pill(wallet, "gem", "gems", { Name = "Gems", Size = UDim2.fromScale(0.44, 1), Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(1, 0), Aspect = 2.8, Role = "Body" })
local msg = UI.text(body, "", { Name = "Message", Size = UDim2.fromScale(1, 0.06), Position = UDim2.fromScale(0, 0.945), Role = "Small", Color = "gold" })

local function show(ok, text, sound)
	msg.TextColor3 = if ok then T.Palette.gold else T.Palette.hpLow
	msg.Text = text or ""
	if not ok then
		UI.play("error")
	elseif sound then
		UI.play(sound)
	end
end

local function page(name, columns, aspect)
	local s = UI.scroll(body, { Name = name, Size = UDim2.fromScale(1, 0.73), Position = UDim2.fromScale(0, 0.205), Columns = columns, CellAspect = aspect, Gap = 0.028, Flat = true, Visible = name == "Itens" })
	UI.fillBetween(s, body:FindFirstChild("Tabs"), msg, 8)
	pages[name] = s
	return s
end
local list = page("Itens", 3, 0.74)
local benefitList = page("Beneficios", nil, nil)
local packList = page("Gemas", 3, 1)

-- botao de preco: verde, com o icone da moeda
local function priceButton(parent, p)
	local b, face = UI.button(parent, { Name = p.Name, Color = p.Color or "green", Size = p.Size, Position = p.Position, AnchorPoint = p.AnchorPoint, Corner = 0.3, Sound = false, OnClick = p.OnClick })
	local row = UI.frame(face, { Name = "Row", Size = UDim2.fromScale(0.92, 0.76), Position = UDim2.fromScale(0.04, 0.12) })
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.Padding = UDim.new(0.04, 0)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = row
	if p.Icon then
		UI.icon(row, p.Icon, { Name = "Icon", Size = UDim2.fromScale(0.3, 1), LayoutOrder = 1 })
	end
	UI.text(row, p.Text, { Name = "Label", Size = UDim2.fromScale(if p.Icon then 0.62 else 1, 1), Role = p.Role or "Small", LayoutOrder = 2, AlignX = if p.Icon then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center })
	return b
end

-- Beneficios: Robux (Game Pass) ou gemas (so os que o GDD permite)
local function refreshBenefits()
	UI.clear(benefitList)
	for i, id in ipairs(Benefits.Sorted()) do
		local def = Benefits.List[id]
		local owned = Benefits.Has(profile, id)
		local row, face = UI.panel(benefitList, { Name = "Row_" .. id, Size = UDim2.fromScale(1, 0), Aspect = 8.4, RowMax = 74, Color = if owned then "blue" else "panelAlt", Corner = 0.2, Shadow = false, StrokeMult = 0.8, LayoutOrder = i })
		if owned then
			UI.shine(row)
		end
		UI.icon(face, BENEFIT_ICON[id] or "star", { Name = "Icon", Size = UDim2.fromScale(0.1, 0.76), Position = UDim2.fromScale(0.015, 0.12) })
		UI.text(face, def.Name, { Name = "Name", Size = UDim2.fromScale(0.42, 0.44), Position = UDim2.fromScale(0.12, 0.08), Role = "Body", AlignX = Enum.TextXAlignment.Left })
		UI.text(face, def.Effect, { Name = "Effect", Size = UDim2.fromScale(0.42, 0.36), Position = UDim2.fromScale(0.12, 0.56), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.4 })
		if owned then
			UI.chip(face, "ATIVO", "green", { Name = "Owned", Icon = "tick", Size = UDim2.fromScale(0.3, 0.6), Position = UDim2.fromScale(0.97, 0.5), AnchorPoint = Vector2.new(1, 0.5), Role = "Body" })
		else
			priceButton(face, { Name = "Robux", Text = def.Robux .. " R$", Size = UDim2.fromScale(0.2, 0.68), Position = UDim2.fromScale(0.56, 0.5), AnchorPoint = Vector2.new(0, 0.5),
				OnClick = function()
					local passId = ProductIds.GamePasses[id] or 0
					if passId == 0 then
						show(false, "Este passe ainda n\u{e3}o foi criado no painel do Roblox.")
						return
					end
					UI.play("click")
					MarketplaceService:PromptGamePassPurchase(player, passId)
				end,
			})
			priceButton(face, { Name = "Gems", Icon = if def.Gems then "gem" else nil, Text = if def.Gems then UI.fmt(def.Gems) else "S\u{f3} Robux", Color = if def.Gems then "purple" else "grey", Size = UDim2.fromScale(0.2, 0.68), Position = UDim2.fromScale(0.78, 0.5), AnchorPoint = Vector2.new(0, 0.5),
				OnClick = function()
					if not def.Gems then
						UI.play("error")
						return
					end
					local ok, text = Remotes.BuyBenefit:InvokeServer(id)
					show(ok, text, "purchase")
				end,
			})
		end
	end
end

-- Pacotes de gemas (Developer Products). O maior vem primeiro e maior (destaque).
local function refreshPacks()
	UI.clear(packList)
	local ids = Benefits.SortedPacks()
	for i, id in ipairs(ids) do
		local pack = Benefits.GemPacks[id]
		local best = i == #ids
		local card, face = UI.panel(packList, { Name = "Pack_" .. id, Color = if best then "lendario" else "panelAlt", Corner = T.Corner.Card, Shadow = false, StrokeMult = 0.85, LayoutOrder = i })
		if best then
			UI.shine(card)
			UI.chip(face, "MELHOR VALOR", "red", { Name = "Best", Size = UDim2.fromScale(0.7, 0.11), Position = UDim2.fromScale(0.5, 0.03), AnchorPoint = Vector2.new(0.5, 0) })
		end
		UI.icon(face, "gem", { Name = "Icon", Size = UDim2.fromScale(0.3 + i * 0.05, 0.3 + i * 0.03), Position = UDim2.fromScale(0.5, 0.32), AnchorPoint = Vector2.new(0.5, 0.5) })
		UI.text(face, pack.Name, { Name = "Name", Size = UDim2.fromScale(0.9, 0.15), Position = UDim2.fromScale(0.05, 0.5), Role = "Heading", Color = "gems" })
		priceButton(face, { Name = "Robux", Text = pack.Robux .. " R$", Size = UDim2.fromScale(0.8, 0.27), Position = UDim2.fromScale(0.1, 0.68), Role = "Body",
			OnClick = function()
				local productId = ProductIds.DevProducts[id] or 0
				if productId == 0 then
					show(false, "Este pacote ainda n\u{e3}o foi criado no painel do Roblox.")
					return
				end
				UI.play("click")
				MarketplaceService:PromptProductPurchase(player, productId)
			end,
		})
	end
end

-- Itens + venda de minerio (o cartao de minerio vem primeiro)
local function refreshItems()
	UI.clear(list)
	local sold = if profile.GemsSold and profile.GemsSold.Day == Base.Day(os.time() + (ReplicatedStorage:GetAttribute("ClockOffset") or 0)) then profile.GemsSold.Amount else 0
	local ore, oface = UI.panel(list, { Name = "Row_Ore", Color = "ore", Corner = T.Corner.Card, Shadow = false, StrokeMult = 0.85, LayoutOrder = -1 })
	UI.icon(oface, "ore", { Name = "Icon", Size = UDim2.fromScale(0.36, 0.25), Position = UDim2.fromScale(0.5, 0.03), AnchorPoint = Vector2.new(0.5, 0) })
	UI.text(oface, "VENDER MIN\u{c9}RIO", { Name = "Name", Size = UDim2.fromScale(0.9, 0.1), Position = UDim2.fromScale(0.05, 0.29), Role = "Small" })
	UI.text(oface, string.format("Min\u{e9}rio %s/%s\nGemas hoje %d/%d", UI.fmt(profile.Ore or 0), UI.fmt(Base.OreMax), sold, Base.DailyGemCap), { Name = "Owned", Size = UDim2.fromScale(0.9, 0.22), Position = UDim2.fromScale(0.05, 0.41), Role = "Small", StrokeMult = 0.5 })
	priceButton(oface, { Name = "SellOre", Icon = "gem", Text = Base.OrePerGem .. " = 1", Color = "purple", Size = UDim2.fromScale(0.86, 0.22), Position = UDim2.fromScale(0.07, 0.74),
		OnClick = function()
			local ok, text = Remotes.SellOre:InvokeServer()
			show(ok, text, "purchase")
		end,
	})
	for _, id in ipairs(Items.Sorted()) do
		local item = Items.Get(id)
		if not item.Price then
			continue -- doces e outros itens que nao se compram
		end
		local style = ITEM_STYLE[id] or {}
		local card, face = UI.panel(list, { Name = "Row_" .. id, Color = style.Color or "panelAlt", Corner = T.Corner.Card, Shadow = false, StrokeColor = style.Frame, StrokeMult = if style.Frame then math.min(style.FrameMult or 1, 1.15) else 0.85, LayoutOrder = item.Order or 99 })
		if style.Shine then
			UI.shine(card)
		end
		UI.icon(face, ITEM_ICON[id] or "bag", { Name = "Icon", Size = UDim2.fromScale(0.36, 0.2), Position = UDim2.fromScale(0.5, 0.03), AnchorPoint = Vector2.new(0.5, 0) })
		UI.text(face, "Tem " .. (profile.Bag[id] or 0), { Name = "Owned", Size = UDim2.fromScale(0.3, 0.08), Position = UDim2.fromScale(0.95, 0.03), AnchorPoint = Vector2.new(1, 0), Role = "Small", Color = "gold", AlignX = Enum.TextXAlignment.Right })
		UI.text(face, item.Name, { Name = "Name", Size = UDim2.fromScale(0.9, 0.09), Position = UDim2.fromScale(0.05, 0.24), Role = "Small", Color = style.NameColor })
		UI.text(face, item.Description or "", { Name = "Desc", Size = UDim2.fromScale(0.9, 0.09), Position = UDim2.fromScale(0.05, 0.34), Role = "Small", Color = "inkSoft", StrokeMult = 0.4 })
		for k, qty in ipairs({ 1, 10 }) do
			priceButton(face, { Name = "Buy" .. qty .. "_" .. id, Icon = "coin", Text = (if qty == 10 then "x10 " else "") .. UI.fmt(item.Price * qty), Size = UDim2.fromScale(0.86, 0.2), Position = UDim2.fromScale(0.07, 0.5 + (k - 1) * 0.245),
				Color = if qty == 1 then "green" else "teal",
				OnClick = function()
					local ok, text = Remotes.BuyItem:InvokeServer(id, qty)
					show(ok, text, "purchase")
				end,
			})
		end
	end
end

refresh = function()
	if not profile then
		return
	end
	UI.countTo(goldLabel, profile.Gold or 0)
	UI.countTo(gemsLabel, profile.Gems or 0)
	if tab == "Beneficios" then
		UI.keepScroll(benefitList, refreshBenefits)
	elseif tab == "Gemas" then
		UI.keepScroll(packList, refreshPacks)
	else
		UI.keepScroll(list, refreshItems)
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

local function openShop()
	if UI.inBattle() then
		return
	end
	msg.Text = ""
	win.Open()
	selectTab(tab)
end

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "ShopPrompt" then
		openShop()
	end
end)

-- botao Loja do HUD
UI.onOpen("Shop", function()
	if win.IsOpen() then
		win.Close()
	else
		openShop()
	end
end)
