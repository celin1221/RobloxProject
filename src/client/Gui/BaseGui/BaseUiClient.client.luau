--[[
	BaseUiClient (GDD secao 8 - menu da base + niveis de mineracao + 4 minerios de atributo)
	Ate 6 personagens na base, Passeando (gold) ou Minerando (minerio bruto + 50% gold + 4 minerios de atributo).
	Coleta a producao, compra vagas de mineracao, sobe nivel da mineracao (libera Defesa/Velocidade/Ataque),
	e abre a Maquina de Treinamento (Capsula).
	O cliente so mostra e pede; o servidor (BaseService / TrainingService) valida e calcula.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local gui = script.Parent
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Data = ReplicatedStorage:WaitForChild("Data")
local Base = require(Data:WaitForChild("Base"))
local Training = require(Data:WaitForChild("Training"))
local Characters = require(Data:WaitForChild("Characters"))
local Summon = require(Data:WaitForChild("Summon"))
local UI = require(ReplicatedStorage:WaitForChild("UI"))
local T = UI.Theme

local profile = nil

local canvas = UI.screen(gui)
gui.DisplayOrder = 9
local win = UI.window(canvas, { Name = "BaseWindow", Title = "BASE", Icon = "house", HeaderColor = "orange", Size = UDim2.fromScale(0.94, 0.88), MaxSize = Vector2.new(1080, 580) })
local body = win.Body

-- Resumo superior: producao, vagas, nivel de mineracao e coleta
local info, infoFace = UI.panel(body, { Name = "Info", Size = UDim2.fromScale(1, 0.22), Color = "slot", Corner = 0.12, Shadow = false })
UI.clampHeight(info, 52, 84)
local _, goldRate = UI.pill(infoFace, "coin", "gold", { Name = "GoldRate", Size = UDim2.fromScale(0.19, 0.42), Position = UDim2.fromScale(0.015, 0.08), Aspect = 3.6, Role = "Small" })
local _, oreRate = UI.pill(infoFace, "ore", "ore", { Name = "OreRate", Size = UDim2.fromScale(0.19, 0.42), Position = UDim2.fromScale(0.22, 0.08), Aspect = 3.6, Role = "Small" })
local slotLabel = UI.text(infoFace, "", { Name = "Slots", Size = UDim2.fromScale(0.56, 0.38), Position = UDim2.fromScale(0.425, 0.1), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.4 })
local pendingLabel = UI.text(infoFace, "", { Name = "Pending", Size = UDim2.fromScale(0.59, 0.36), Position = UDim2.fromScale(0.015, 0.58), Role = "Small", Color = "gold", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.45 })
local msg = UI.text(infoFace, "", { Name = "Message", Size = UDim2.fromScale(0.37, 0.36), Position = UDim2.fromScale(0.985, 0.58), AnchorPoint = Vector2.new(1, 0), Role = "Small", Color = "gold", AlignX = Enum.TextXAlignment.Right })

-- Faixa dos 4 minerios de atributo (estoque + chance equilibrada por nivel de mineracao + pendente)
local oreStrip, oreFace = UI.panel(body, { Name = "OreStrip", Size = UDim2.fromScale(1, 0.14), Color = "panelAlt", Corner = 0.22, Shadow = false })
UI.clampHeight(oreStrip, 34, 46)
local oreBoxes = {}
for i, stat in ipairs(Training.OreOrder) do
	local cfg = Training.Ores[stat]
	local box, bface = UI.panel(oreFace, {
		Name = "Ore_" .. stat,
		Size = UDim2.fromScale(0.238, 0.82),
		Position = UDim2.fromScale(0.01 + (i - 1) * 0.248, 0.09),
		Color = "slot",
		Corner = 0.25,
		Shadow = false,
	})
	UI.stroke(bface, cfg.Color, 0.85)
	UI.icon(bface, cfg.Icon or "ore", { Name = "Icon", Size = UDim2.fromScale(0.18, 0.76), Position = UDim2.fromScale(0.03, 0.5), AnchorPoint = Vector2.new(0, 0.5), AspectAxis = Enum.DominantAxis.Height })
	local txt = UI.text(bface, "", { Name = "Text", Size = UDim2.fromScale(0.75, 0.84), Position = UDim2.fromScale(0.22, 0.08), Role = "Small", Rich = true, AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.4 })
	oreBoxes[stat] = { Box = box, Face = bface, Label = txt, Color = cfg.Color }
end

-- Barra inferior de acoes (5 botoes com area >= 44 px garantida)
local bar = UI.frame(body, { Name = "Actions", Size = UDim2.fromScale(1, 0.12), Position = UDim2.fromScale(0, 1), AnchorPoint = Vector2.new(0, 1) })
UI.clampHeight(bar, T.TouchMin, 50)
local list = UI.scroll(body, { Name = "List", Size = UDim2.fromScale(1, 0.4), Position = UDim2.fromScale(0, 0.38) })

local function layoutBody()
	local W, H = body.AbsoluteSize.X, body.AbsoluteSize.Y
	if W < 20 or H < 20 then
		return
	end
	local ih = info.AbsoluteSize.Y
	local oh = oreStrip.AbsoluteSize.Y
	local bh = bar.AbsoluteSize.Y
	local gap = 5
	oreStrip.Position = UDim2.fromOffset(0, ih + gap)
	local ly = ih + oh + gap * 2
	list.Position = UDim2.fromOffset(0, ly)
	list.Size = UDim2.fromOffset(W, math.max(54, H - ly - bh - gap))
end
body:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutBody)
info:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutBody)
oreStrip:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutBody)
bar:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutBody)

local function show(ok, text, sound)
	msg.TextColor3 = if ok then T.Palette.gold else T.Palette.hpLow
	msg.Text = text or ""
	if not ok then
		UI.play("error")
	elseif sound then
		UI.play(sound)
	end
end

local collectButton, upgradeButton, miningUpgradeButton, trainButton, goButton
collectButton = UI.button(bar, {
	Name = "Collect", Text = "COLETAR", Icon = "chest", Layout = "row", Color = "green", Size = UDim2.fromScale(0.175, 1), Position = UDim2.fromScale(0, 0), Role = "Small", Sound = false,
	OnClick = function()
		local ok, text = Remotes.BaseCollect:InvokeServer()
		show(ok, text, "coin")
	end,
})
upgradeButton = UI.button(bar, {
	Name = "Upgrade", Text = "", Color = "blue", Size = UDim2.fromScale(0.21, 1), Position = UDim2.fromScale(0.185, 0), Role = "Small", Sound = false,
	OnClick = function()
		if upgradeButton:GetAttribute("Disabled") then
			return
		end
		local ok, text = Remotes.BaseUpgrade:InvokeServer()
		show(ok, text, "purchase")
	end,
})
miningUpgradeButton = UI.button(bar, {
	Name = "UpgradeMining", Text = "", Color = "purple", Size = UDim2.fromScale(0.215, 1), Position = UDim2.fromScale(0.405, 0), Role = "Small", Sound = false,
	OnClick = function()
		if miningUpgradeButton:GetAttribute("Disabled") then
			return
		end
		local ok, text = Remotes.BaseUpgradeMining:InvokeServer()
		show(ok, text, "purchase")
	end,
})
trainButton = UI.button(bar, {
	Name = "OpenTraining", Text = "TREINO", Icon = "sparkle", Layout = "row", Color = "teal", Size = UDim2.fromScale(0.185, 1), Position = UDim2.fromScale(0.63, 0), Role = "Small",
	OnClick = function()
		UI.open("Training")
	end,
})
goButton = UI.button(bar, {
	Name = "GoHome", Text = "BASE", Icon = "house", Layout = "row", Color = "orange", Size = UDim2.fromScale(0.175, 1), Position = UDim2.fromScale(0.825, 0), Role = "Small",
	OnClick = function()
		local ok, text = Remotes.BaseTeleport:InvokeServer()
		if ok then
			win.Close()
		else
			show(false, text)
		end
	end,
})

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
	local miningLv = Base.MiningLevelOf(profile)
	local gold, ore = Base.Rates(profile, rarityOf)
	goldRate.Text = UI.fmt(gold) .. "/h"
	oreRate.Text = UI.fmt(ore) .. "/h"
	slotLabel.Text = string.format("Ativos %d/%d \u{b7} Vagas %d/%d \u{b7} Min. Nv.%d/%d \u{b7} Dep. %s", active, Base.MaxActive, miners, slots, miningLv, Base.MaxMiningLevel, UI.fmt(profile.Ore or 0))

	local pendOres = (b.Pending and b.Pending.Ores) or Training.ZeroOres()
	local pendAttrSum = 0
	for _, st in ipairs(Training.OreOrder) do
		pendAttrSum += math.floor(pendOres[st] or 0)
	end
	pendingLabel.Text = string.format("Coletar: %s gold \u{b7} %s min \u{b7} %d min. atributo", UI.fmt(b.Pending.Gold), UI.fmt(b.Pending.Ore), pendAttrSum)

	local slotCost = Base.NextSlotCost(profile)
	UI.setText(upgradeButton, if slotCost then ("+VAGA: " .. UI.fmt(slotCost)) else "VAGAS M\u{c1}X")
	UI.setDisabled(upgradeButton, not slotCost, "blue")

	local minCost = Base.NextMiningLevelCost(profile)
	UI.setText(miningUpgradeButton, if minCost then string.format("MIN NV.%d: %s", miningLv + 1, UI.fmt(minCost)) else string.format("MIN M\u{c1}X (%d)", miningLv))
	UI.setDisabled(miningUpgradeButton, not minCost, "purple")

	-- Atualiza os 4 minerios de atributo (estoque, participacao %, e pendencias)
	local stock = Training.SanitizeOres(profile.TrainingOres, Training.MaxOrePerType)
	local dropRow = Base.MiningDropTable[miningLv]
	local shares = Base.DropShares(miningLv)
	for _, stat in ipairs(Training.OreOrder) do
		local cfg = Training.Ores[stat]
		local box = oreBoxes[stat]
		local drop = dropRow and dropRow[stat]
		local unlocked = drop and drop.Chance > 0
		local pend = math.floor(pendOres[stat] or 0)
		if unlocked then
			local extra = if pend > 0 then string.format(" (+%d)", pend) else ""
			box.Label.Text = string.format("%s: <b>%d</b>%s \u{b7} %.0f%%", Training.StatLabels[stat].Short, stock[stat] or 0, extra, shares[stat] or 0)
			box.Label.TextColor3 = cfg.Color
		else
			box.Label.Text = string.format("%s: <b>%d</b> \u{b7} Nv.%d", Training.StatLabels[stat].Short, stock[stat] or 0, cfg.UnlockMiningLevel)
			box.Label.TextColor3 = T.Palette.inkSoft
		end
	end

	local capsuleUid = profile.TrainingMachine and profile.TrainingMachine.Job and profile.TrainingMachine.Job.Uid

	-- Lista: primeiro quem esta na base ou na capsula, depois o resto da colecao
	UI.clear(list)
	local uids = {}
	for uid in pairs(profile.Collection) do
		table.insert(uids, uid)
	end
	table.sort(uids, function(x, y)
		local cx, cy = x == capsuleUid, y == capsuleUid
		if cx ~= cy then
			return cx
		end
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
			local inCapsule = uid == capsuleUid
			local state = b.Active[uid]
			local row, face = UI.panel(list, { Name = "Row_" .. uid, Size = UDim2.fromScale(0.98, 0), Aspect = 9, RowMax = 64, Color = "panelAlt", Corner = 0.3, LayoutOrder = i })
			if inCapsule then
				UI.stroke(face, T.Palette.teal, 1.3)
			elseif state then
				UI.stroke(face, if state == "Mine" then T.Palette.ore else T.Palette.gold, 1.2)
			end
			local rarity = def.Rarity
			local gWalk = Base.GoldPerHour[rarity] or 0
			local gMine = math.floor(gWalk * Base.MiningGoldRatio + 0.5)
			local oMine = Base.OrePerHour[rarity] or 0
			UI.text(face, string.format("%s  Nv. %d", def.Name, m.Level), { Name = "Name", Size = UDim2.fromScale(0.34, 0.46), Position = UDim2.fromScale(0.02, 0.08), Role = "Body", AlignX = Enum.TextXAlignment.Left })
			UI.text(face, string.format("%s \u{b7} Passeio %dg \u{b7} Mina %dg+%dm", Summon.RarityName and Summon.RarityName[rarity] or rarity, gWalk, gMine, oMine), { Name = "Rarity", Size = UDim2.fromScale(0.35, 0.34), Position = UDim2.fromScale(0.02, 0.58), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.4 })
			local chipText = if inCapsule then "C\u{c1}PSULA" elseif state then UI.upper(STATE_NAME[state]) else "FORA"
			local chipColor = if inCapsule then "teal" elseif state == "Mine" then "ore" elseif state then "gold" else "slot"
			UI.chip(face, chipText, chipColor, { Name = "State", Size = UDim2.fromScale(0.17, 0.46), Position = UDim2.fromScale(0.38, 0.27) })
			local function act(name, text, color, x, target, enabled)
				UI.button(face, { Name = name, Text = text, Color = if enabled then color else "grey", Size = UDim2.fromScale(0.135, 0.76), Position = UDim2.fromScale(x, 0.12), Role = "Small",
					OnClick = function()
						if enabled then
							setState(uid, target)
						end
					end,
				})
			end
			act("Walk", "PASSEAR", "gold", 0.565, "Walk", (not inCapsule) and state ~= "Walk")
			act("Mine", "MINERAR", "ore", 0.71, "Mine", (not inCapsule) and state ~= "Mine")
			act("Remove", "TIRAR", "red", 0.855, "None", (not inCapsule) and state ~= nil)
		end
	end
end

local function refresh()
	UI.keepScroll(list, refreshNow)
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
	task.defer(layoutBody)
end)
