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
local list = UI.scroll(body, { Name = "List", Size = UDim2.fromScale(1, 0.4), Position = UDim2.fromScale(0, 0.38), Gap = 0.025, Flat = true })

local function layoutBody()
	local W, H = UI.unscaledSize(body)
	W, H = math.floor(W + 0.5), math.floor(H + 0.5)
	if W < 20 or H < 20 then
		return
	end
	local _, ih = UI.unscaledSize(info)
	local _, oh = UI.unscaledSize(oreStrip)
	local _, bh = UI.unscaledSize(bar)
	ih, oh, bh = math.floor(ih + 0.5), math.floor(oh + 0.5), math.floor(bh + 0.5)
	local gap = 8
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

local function countsFor(prof)
	local active, miners = 0, 0
	local actMap = prof and prof.Base and prof.Base.Active
	if actMap then
		for _, s in pairs(actMap) do
			active += 1
			if s == "Mine" then
				miners += 1
			end
		end
	end
	return active, miners
end

local function counts()
	return countsFor(profile)
end

local function setState(uid, state)
	local ok, text = Remotes.BaseSetState:InvokeServer(uid, state)
	show(ok, if ok then "" else text)
end

local function openBasePicker(targetState: string)
	if not profile or not profile.Base then
		return
	end
	local isMine = targetState == "Mine"
	UI.pickCharacter({
		Title = if isMine then "COLOCAR PARA MINERAR" else "COLOCAR PARA PASSEAR",
		HeaderColor = if isMine then "ore" else "gold",
		Icon = if isMine then "pickaxe" else "house",
		ActionLabel = if isMine then "COLOCAR NA MINA" else "COLOCAR PASSEIO",
		ActionColor = if isMine then "ore" else "gold",
		ReturnTo = "Base",
		KeepOpen = true,
		SubtitleFn = function(prof)
			local act, min = countsFor(prof)
			local sl = Base.MiningSlots(prof)
			return string.format("Ativos %d/%d · Vagas Mina %d/%d", act, Base.MaxActive, min, sl)
		end,
		FormatSelected = function(_uid, m, def)
			local rar = def.Rarity
			local gWalk = Base.MemberGoldPerSecond(m, rar, false)
			local gMine = Base.MemberGoldPerSecond(m, rar, true)
			local oMine = Base.OrePerHour[rar] or 0
			local rate = if isMine then string.format("+%.1fg/s +%dm/h", gMine, oMine) else string.format("+%.1fg/s", gWalk)
			return string.format("<b>%s</b> Nv.%d (%s \u{b7} %s)", def.Name, m.Level or 1, Summon.RarityName and Summon.RarityName[rar] or rar, rate)
		end,
		GetBadge = function(uid, _m, _def, prof)
			local capUid = prof.TrainingMachine and prof.TrainingMachine.Job and prof.TrainingMachine.Job.Uid
			if uid == capUid then
				return "C\u{c1}PSULA", "teal"
			end
			local st = prof.Base and prof.Base.Active and prof.Base.Active[uid]
			if st == "Mine" then
				return "MINERANDO", "ore"
			elseif st == "Walk" then
				return "PASSEANDO", "gold"
			elseif table.find(prof.Team, uid) ~= nil then
				return "NO TIME", "green"
			end
			return nil, nil
		end,
		IsEligible = function(uid, _m, _def, prof)
			local capUid = prof.TrainingMachine and prof.TrainingMachine.Job and prof.TrainingMachine.Job.Uid
			if uid == capUid then
				return false, "Est\u{e1} na C\u{e1}psula de Treino."
			end
			local st = prof.Base and prof.Base.Active and prof.Base.Active[uid]
			if st == targetState then
				return false, if isMine then "J\u{e1} est\u{e1} minerando." else "J\u{e1} est\u{e1} passeando."
			end
			local act, min = countsFor(prof)
			local sl = Base.MiningSlots(prof)
			if not st and act >= Base.MaxActive then
				return false, string.format("Base cheia (%d/%d). Tire algu\u{e9}m primeiro.", act, Base.MaxActive)
			end
			if isMine and min >= sl then
				return false, string.format("Vagas de minera\u{e7}\u{e3}o cheias (%d/%d).", min, sl)
			end
			return true, nil
		end,
		OnPick = function(uid)
			local beforeAct, beforeMin = countsFor(profile)
			local wasActive = profile.Base and profile.Base.Active and profile.Base.Active[uid] ~= nil
			local ok, text = Remotes.BaseSetState:InvokeServer(uid, targetState)
			if not ok then
				return false, text
			end
			local newAct = beforeAct + (if wasActive then 0 else 1)
			local newMin = beforeMin + (if isMine then 1 else 0)
			local sl = Base.MiningSlots(profile)
			local full = if isMine then (newMin >= sl) else (newAct >= Base.MaxActive)
			return true, if isMine then "Colocado para minerar!" else "Colocado para passear!", full
		end,
	})
end

local STATE_NAME = { Walk = Base.States.Walk, Mine = Base.States.Mine }
local lastListKey = nil

local function refreshNow()
	if not profile or not profile.Base then
		return
	end
	local b = profile.Base
	local active, miners = counts()
	local slots = Base.MiningSlots(profile)
	local miningLv = Base.MiningLevelOf(profile)
	local gold, ore, goldPerSec = Base.Rates(profile, rarityOf)
	local gps = goldPerSec or (gold / 3600)
	local gpsStr = if gps >= 10 then UI.fmt(math.floor(gps + 0.5)) else (string.format("%.1f", gps):gsub("%.0$", ""))
	goldRate.Text = "+" .. gpsStr .. "/s"
	oreRate.Text = UI.fmt(ore) .. "/h"
	slotLabel.Text = string.format("Ativos %d/%d \u{b7} Vagas %d/%d \u{b7} Min. Nv.%d/%d \u{b7} Dep. %s", active, Base.MaxActive, miners, slots, miningLv, Base.MaxMiningLevel, UI.fmt(profile.Ore or 0))

	local pendOres = (b.Pending and b.Pending.Ores) or Training.ZeroOres()
	local pendAttrSum = 0
	for _, st in ipairs(Training.OreOrder) do
		pendAttrSum += math.floor(pendOres[st] or 0)
	end
	if (b.Pending.Gold or 0) >= 1 then
		pendingLabel.Text = string.format("Online: +%s/s direto \u{b7} Coletar: %s gold (offline) \u{b7} %s min \u{b7} %d atrib.", gpsStr, UI.fmt(b.Pending.Gold), UI.fmt(b.Pending.Ore), pendAttrSum)
	else
		pendingLabel.Text = string.format("Gold cai direto (+%s/s) \u{b7} Coletar: %s min \u{b7} %d min. atributo", gpsStr, UI.fmt(b.Pending.Ore), pendAttrSum)
	end

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

	-- Exibe os botoes para abrir o seletor visual da Equipe + apenas os personagens ativos na base/capsula
	local uids = {}
	for uid in pairs(profile.Collection) do
		if b.Active[uid] ~= nil or uid == capsuleUid then
			table.insert(uids, uid)
		end
	end
	table.sort(uids, function(x, y)
		local cx, cy = x == capsuleUid, y == capsuleUid
		if cx ~= cy then
			return cx
		end
		local mxState, myState = b.Active[x] == "Mine", b.Active[y] == "Mine"
		if mxState ~= myState then
			return mxState
		end
		local mx, my = profile.Collection[x], profile.Collection[y]
		if mx.Level ~= my.Level then
			return mx.Level > my.Level
		end
		return x < y
	end)

	-- So recria os itens quando os ativos ou vagas mudam (evita travamento e pulo de rolagem a cada tick de 10s)
	local sigParts = { string.format("H:%d/%d:%d/%d", active, Base.MaxActive, miners, slots) }
	for _, uid in ipairs(uids) do
		local m = profile.Collection[uid]
		table.insert(sigParts, string.format("%s:%s:%d:%s:%s", uid, tostring(m.CharacterId), m.Level or 1, tostring(b.Active[uid] or ""), if uid == capsuleUid then "1" else "0"))
	end
	local listKey = table.concat(sigParts, "|")
	if listKey == lastListKey then
		return
	end
	lastListKey = listKey

	UI.keepScroll(list, function()
		UI.clear(list)

		-- Barra de selecao visual (abre o HUD da Equipe com filtros e cartoes 3D)
		local addRow = UI.frame(list, { Name = "AddRow", Size = UDim2.new(0.98, 0, 0, T.TouchMin + 4), LayoutOrder = 0 })
		local canAddAny = active < Base.MaxActive
		local canAddMine = miners < slots and (active < Base.MaxActive or active > miners)
		UI.button(addRow, {
			Name = "AddWalk",
			Text = "+ ESCOLHER PASSEIO",
			Icon = "team",
			Layout = "row",
			Color = if canAddAny then "gold" else "grey",
			Size = UDim2.fromScale(0.49, 1),
			Position = UDim2.fromScale(0, 0),
			Role = "Small",
			Corner = 0.28,
			OnClick = function()
				openBasePicker("Walk")
			end,
		})
		UI.button(addRow, {
			Name = "AddMine",
			Text = "+ ESCOLHER MINA",
			Icon = "pickaxe",
			Layout = "row",
			Color = if canAddMine then "ore" else "grey",
			Size = UDim2.fromScale(0.49, 1),
			Position = UDim2.fromScale(0.51, 0),
			Role = "Small",
			Corner = 0.28,
			OnClick = function()
				openBasePicker("Mine")
			end,
		})

		if #uids == 0 then
			UI.text(list, "Nenhum personagem ativo na base. Use os bot\u{f5}es acima para escolher na cole\u{e7}\u{e3}o!", {
				Name = "Empty", Size = UDim2.fromScale(0.96, 0), Aspect = 12, Role = "Small", Color = "inkSoft", LayoutOrder = 1,
			})
			return
		end

		for i, uid in ipairs(uids) do
			local m = profile.Collection[uid]
			local def = Characters.Get(m.CharacterId)
			if def then
				local inCapsule = uid == capsuleUid
				local state = b.Active[uid]
				local rowStroke = if inCapsule then T.Palette.teal elseif state == "Mine" then T.Palette.ore elseif state then T.Palette.gold else nil
				local row, face = UI.panel(list, { Name = "Row_" .. uid, Size = UDim2.fromScale(1, 0), Aspect = 8.6, RowMax = 72, Color = "panelAlt", Corner = 0.2, Shadow = false, StrokeColor = rowStroke, StrokeMult = 0.85, LayoutOrder = i })
				local rarity = def.Rarity
				local gWalk = Base.MemberGoldPerSecond(m, rarity, false)
				local gMine = Base.MemberGoldPerSecond(m, rarity, true)
				local oMine = Base.OrePerHour[rarity] or 0
				UI.text(face, string.format("%s  Nv. %d", def.Name, m.Level), { Name = "Name", Size = UDim2.fromScale(0.34, 0.44), Position = UDim2.fromScale(0.025, 0.09), Role = "Body", AlignX = Enum.TextXAlignment.Left })
				UI.text(face, string.format("%s \u{b7} Passeio %.1fg/s \u{b7} Mina %.1fg/s+%dm/h", Summon.RarityName and Summon.RarityName[rarity] or rarity, gWalk, gMine, oMine), { Name = "Rarity", Size = UDim2.fromScale(0.35, 0.34), Position = UDim2.fromScale(0.025, 0.56), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.4 })
				local chipText = if inCapsule then "C\u{c1}PSULA" elseif state then UI.upper(STATE_NAME[state]) else "FORA"
				local chipColor = if inCapsule then "teal" elseif state == "Mine" then "ore" elseif state then "gold" else "slot"
				UI.chip(face, chipText, chipColor, { Name = "State", Size = UDim2.fromScale(0.17, 0.46), Position = UDim2.fromScale(0.38, 0.5), AnchorPoint = Vector2.new(0, 0.5) })
				local function act(name, text, color, x, target, enabled)
					UI.button(face, { Name = name, Text = text, Color = if enabled then color else "grey", Size = UDim2.fromScale(0.135, 0.68), Position = UDim2.fromScale(x, 0.5), AnchorPoint = Vector2.new(0, 0.5), Role = "Small",
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
	end)
end

local function refresh()
	refreshNow()
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
	win.Open()
	layoutBody()
	refresh()
	task.defer(layoutBody)
end)
