--[[
	BaseUiClient (GDD secao 8 - menu da base)
	Ate 6 personagens na base, Passeando (gold) ou Minerando (minerio, limitado pelas vagas);
	coleta a producao, compra vagas de mineracao e leva o jogador ao terreno.
	O cliente so mostra e pede; o servidor (BaseService) valida e calcula. Abre pelo HUD (UI.open("Base")).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local gui = script.Parent
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Data = ReplicatedStorage:WaitForChild("Data")
local Base = require(Data:WaitForChild("Base"))
local Characters = require(Data:WaitForChild("Characters"))
local Summon = require(Data:WaitForChild("Summon"))
local UI = require(ReplicatedStorage:WaitForChild("UI"))
local T = UI.Theme

local profile = nil

local canvas = UI.screen(gui)
gui.DisplayOrder = 9
local win = UI.window(canvas, { Name = "BaseWindow", Title = "BASE", Icon = "house", HeaderColor = "orange", Size = UDim2.fromScale(0.92, 0.86), Aspect = 1.95 })
local body = win.Body

-- Resumo: producao, vagas, deposito e acoes
local info, infoFace = UI.panel(body, { Name = "Info", Size = UDim2.fromScale(1, 0.22), Color = "slot", Corner = 0.12, Shadow = false })
UI.clampHeight(info, 48, 96)
local _, goldRate = UI.pill(infoFace, "coin", "gold", { Name = "GoldRate", Size = UDim2.fromScale(0.2, 0.4), Position = UDim2.fromScale(0.02, 0.08), Aspect = 3.6, Role = "Body" })
local _, oreRate = UI.pill(infoFace, "ore", "ore", { Name = "OreRate", Size = UDim2.fromScale(0.2, 0.4), Position = UDim2.fromScale(0.24, 0.08), Aspect = 3.6, Role = "Body" })
local slotLabel = UI.text(infoFace, "", { Name = "Slots", Size = UDim2.fromScale(0.52, 0.34), Position = UDim2.fromScale(0.46, 0.1), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.4 })
local pendingLabel = UI.text(infoFace, "", { Name = "Pending", Size = UDim2.fromScale(0.6, 0.34), Position = UDim2.fromScale(0.02, 0.58), Role = "Small", Color = "gold", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.5 })

-- barra de acoes embaixo (altura limitada: 44 a 50 px)
local bar = UI.frame(body, { Name = "Actions", Size = UDim2.fromScale(1, 0.12), Position = UDim2.fromScale(0, 1), AnchorPoint = Vector2.new(0, 1) })
UI.clampHeight(bar, T.TouchMin, 50)
-- mensagem no canto do resumo (nao rouba altura da lista)
local msg = UI.text(infoFace, "", { Name = "Message", Size = UDim2.fromScale(0.36, 0.34), Position = UDim2.fromScale(0.98, 0.58), AnchorPoint = Vector2.new(1, 0), Role = "Small", Color = "gold", AlignX = Enum.TextXAlignment.Right })
local list = UI.scroll(body, { Name = "List", Size = UDim2.fromScale(1, 0.45), Position = UDim2.fromScale(0, 0.27) })
UI.fillBetween(list, info, bar, 6)

local collectButton = UI.button(bar, { Name = "Collect", Text = "COLETAR", Icon = "chest", Layout = "row", Color = "green", Size = UDim2.fromScale(0.24, 1), Role = "Body", Sound = false })
local upgradeButton = UI.button(bar, { Name = "Upgrade", Color = "blue", Size = UDim2.fromScale(0.46, 1), Position = UDim2.fromScale(0.5, 0), AnchorPoint = Vector2.new(0.5, 0), Role = "Small", Sound = false })
UI.icon(upgradeButton.Face, "pickaxe", { Name = "Icon", Size = UDim2.fromScale(0.16, 0.8), Position = UDim2.fromScale(0.04, 0.1) })
local upgradeText = UI.text(upgradeButton.Face, "", { Name = "Label", Size = UDim2.fromScale(0.76, 0.66), Position = UDim2.fromScale(0.21, 0.17), Role = "Small", AlignX = Enum.TextXAlignment.Left })
local goButton = UI.button(bar, { Name = "GoHome", Text = "IR \u{c0} BASE", Icon = "house", Layout = "row", Color = "orange", Size = UDim2.fromScale(0.24, 1), Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(1, 0), Role = "Body" })

local function show(ok, text, sound)
	msg.TextColor3 = if ok then T.Palette.gold else T.Palette.hpLow
	msg.Text = text or ""
	if not ok then
		UI.play("error")
	elseif sound then
		UI.play(sound)
	end
end

local function rarityOf(id)
	local def = Characters.Get(id)
	return def and def.Rarity
end

local function counts()
	local active, miners = 0, 0
	for _, s in pairs(profile.Base.Active) do
		active += 1
		if s == "Mine" then
			miners += 1
		end
	end
	return active, miners
end

local function setState(uid, state)
	local ok, text = Remotes.BaseSetState:InvokeServer(uid, state)
	show(ok, if ok then "" else text)
end

local STATE_NAME = { Walk = Base.States.Walk, Mine = Base.States.Mine }

local function refreshNow()
	if not profile or not profile.Base then
		return
	end
	local b = profile.Base
	local active, miners = counts()
	local slots = Base.MiningSlots(profile)
	local gold, ore = Base.Rates(profile, rarityOf)
	goldRate.Text = UI.fmt(gold) .. "/h"
	oreRate.Text = UI.fmt(ore) .. "/h"
	slotLabel.Text = string.format("Ativos %d/%d \u{b7} Minera\u{e7}\u{e3}o %d/%d \u{b7} Dep\u{f3}sito %s/%s", active, Base.MaxActive, miners, slots, UI.fmt(profile.Ore or 0), UI.fmt(Base.OreMax))
	pendingLabel.Text = string.format("Para coletar: %s gold e %s de min\u{e9}rio (fora: at\u{e9} %d h)", UI.fmt(b.Pending.Gold), UI.fmt(b.Pending.Ore), Base.OfflineCapHours)
	local cost = Base.NextSlotCost(profile)
	upgradeText.Text = if cost then "Nova vaga: " .. UI.fmt(cost) .. " gold" else "Vagas no m\u{e1}ximo"
	UI.setDisabled(upgradeButton, not cost, "blue")

	-- lista: primeiro quem esta na base, depois o resto da colecao
	UI.clear(list)
	local uids = {}
	for uid in pairs(profile.Collection) do
		table.insert(uids, uid)
	end
	table.sort(uids, function(x, y)
		local ax, ay = b.Active[x] ~= nil, b.Active[y] ~= nil
		if ax ~= ay then
			return ax
		end
		local mx, my = profile.Collection[x], profile.Collection[y]
		if mx.Level ~= my.Level then
			return mx.Level > my.Level
		end
		return x < y
	end)
	for i, uid in ipairs(uids) do
		local m = profile.Collection[uid]
		local def = Characters.Get(m.CharacterId)
		if def then
			local state = b.Active[uid]
			local row, face = UI.panel(list, { Name = "Row_" .. uid, Size = UDim2.fromScale(0.98, 0), Aspect = 9, RowMax = 64, Color = "panelAlt", Corner = 0.3, LayoutOrder = i })
			if state then
				UI.stroke(face, if state == "Mine" then T.Palette.ore else T.Palette.gold, 1.2)
			end
			local rarity = def.Rarity
			UI.text(face, string.format("%s  Nv. %d", def.Name, m.Level), { Name = "Name", Size = UDim2.fromScale(0.34, 0.46), Position = UDim2.fromScale(0.02, 0.08), Role = "Body", AlignX = Enum.TextXAlignment.Left })
			UI.text(face, string.format("%s \u{b7} %d gold/h \u{b7} %d min/h", Summon.RarityName and Summon.RarityName[rarity] or rarity, Base.GoldPerHour[rarity] or 0, Base.OrePerHour[rarity] or 0), { Name = "Rarity", Size = UDim2.fromScale(0.35, 0.34), Position = UDim2.fromScale(0.02, 0.58), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.4 })
			UI.chip(face, if state then UI.upper(STATE_NAME[state]) else "FORA", if state == "Mine" then "ore" elseif state then "gold" else "slot", { Name = "State", Size = UDim2.fromScale(0.17, 0.46), Position = UDim2.fromScale(0.38, 0.27) })
			local function act(name, text, icon, color, x, target, enabled)
				UI.button(face, { Name = name, Text = text, Color = if enabled then color else "grey", Size = UDim2.fromScale(0.135, 0.76), Position = UDim2.fromScale(x, 0.12), Role = "Small",
					OnClick = function()
						if enabled then
							setState(uid, target)
						end
					end,
				})
			end
			act("Walk", "PASSEAR", "coin", "gold", 0.565, "Walk", state ~= "Walk")
			act("Mine", "MINERAR", "pickaxe", "ore", 0.71, "Mine", state ~= "Mine")
			act("Remove", "TIRAR", "close", "red", 0.855, "None", state ~= nil)
		end
	end
end

local function refresh()
	UI.keepScroll(list, refreshNow)
end

collectButton.Activated:Connect(function()
	local ok, text = Remotes.BaseCollect:InvokeServer()
	show(ok, text, "coin")
end)
upgradeButton.Activated:Connect(function()
	if upgradeButton:GetAttribute("Disabled") then
		return
	end
	local ok, text = Remotes.BaseUpgrade:InvokeServer()
	show(ok, text, "purchase")
end)
goButton.Activated:Connect(function()
	local ok, text = Remotes.BaseTeleport:InvokeServer()
	if ok then
		win.Close()
	else
		show(false, text)
	end
end)

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

UI.onOpen("Base", function()
	if not profile or not profile.StarterChosen then
		return
	end
	if win.IsOpen() then
		win.Close()
		return
	end
	msg.Text = ""
	refresh()
	win.Open()
end)
