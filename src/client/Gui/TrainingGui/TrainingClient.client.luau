--[[
	TrainingClient (GDD secao 8 - Maquina de Treinamento / Cupula de Vidro)
	Abre pela interacao com a Cupula na Base (TrainingOpen) ou pelo botao TREINO no menu BASE (UI.open("Training")).
	- Sem treino ativo: escolhe personagem, seleciona incrementos de 20 em 20 nos 4 atributos (ate 100%),
	  visualiza custo em minerios (por atributo + raridade + acrescimo multi-atributo) e tempo estimado.
	- Com treino ativo: exibe retrato 3D, barra de progresso ao vivo e acao Resgatar (quando pronto) ou Cancelar (50%).
	- Melhoria da Maquina com Gold aumenta eficiencia e reduz tempo de treinamento.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local gui = script.Parent
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Data = ReplicatedStorage:WaitForChild("Data")
local Characters = require(Data:WaitForChild("Characters"))
local Genetics = require(Data:WaitForChild("Genetics"))
local Training = require(Data:WaitForChild("Training"))
local Summon = require(Data:WaitForChild("Summon"))
local UI = require(ReplicatedStorage:WaitForChild("UI"))
local TeamCards = require(ReplicatedStorage:WaitForChild("TeamCards"))
local T = UI.Theme

local profile = nil
local selectedUid = nil
local draft = Training.ZeroOres() -- incrementos escolhidos de 20 em 20

local canvas = UI.screen(gui)
gui.DisplayOrder = 10

local selectedPortrait, activePortrait
local win = UI.window(canvas, {
	Name = "TrainingWindow",
	Title = "M\u{c1}QUINA DE TREINO",
	Icon = "sparkle",
	HeaderColor = "teal",
	Size = UDim2.fromScale(0.94, 0.88),
	MaxSize = Vector2.new(1080, 580),
	OnClose = function()
		if selectedPortrait then
			selectedPortrait.Clear()
		end
		if activePortrait then
			activePortrait.Clear()
		end
	end,
})
do
	local hi = win.Header:FindFirstChild("Icon")
	if hi then
		hi.Size = UDim2.fromScale(0.18, 0.72)
		hi.Position = UDim2.fromScale(0.015, 0.5)
	end
end
local body = win.Body

local function nowClient(): number
	return os.time() + (ReplicatedStorage:GetAttribute("ClockOffset") or 0)
end

local function fmtTime(sec: number): string
	sec = math.max(0, math.floor(sec))
	return string.format("%02d:%02d", sec // 60, sec % 60)
end

local onUpgradeMachine, onStartTraining, onActiveAction, onStepStat, onPickCharacter

-- Barra superior: nivel de eficiencia da maquina, estoque dos 4 minerios e botao de upgrade com Gold
local topBar, topFace = UI.panel(body, { Name = "TopBar", Color = "slot", Corner = 0.2, Shadow = false, ZIndex = 2 })
local machineLabel = UI.text(topFace, "", { Name = "MachineInfo", Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.4, ZIndex = 3 })
local oresRow = UI.frame(topFace, { Name = "OreStockRow", ZIndex = 3 })
local topOreSlots = {}
for i, statKey in ipairs(Training.OreOrder) do
	local cfg = Training.Ores[statKey]
	local slot = UI.frame(oresRow, { Name = "TopOre_" .. statKey, Size = UDim2.fromScale(0.245, 1), Position = UDim2.fromScale((i - 1) * 0.25, 0), ZIndex = 3 })
	local ico = UI.icon(slot, cfg.Icon or "ore", { Name = "Icon", Size = UDim2.fromScale(0.25, 0.78), Position = UDim2.fromScale(0, 0.5), AnchorPoint = Vector2.new(0, 0.5), AspectAxis = Enum.DominantAxis.Height, ZIndex = 4 })
	local lbl = UI.text(slot, "", { Name = "Val", Size = UDim2.fromScale(0.76, 0.9), Position = UDim2.fromScale(0.23, 0.05), Role = "Small", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.45, ZIndex = 4 })
	lbl.TextColor3 = cfg.Color
	topOreSlots[statKey] = { Frame = slot, Icon = ico, Label = lbl }
end
local upgradeBtn = UI.button(topFace, { Name = "UpgradeMachine", Text = "", Color = "gold", Role = "Small", Corner = 0.25, ZIndex = 4,
	OnClick = function() if onUpgradeMachine then onUpgradeMachine() end end,
})

-- Area de mensagem
local msgLabel = UI.text(body, "", { Name = "Message", Role = "Small", Color = "gold", AlignX = Enum.TextXAlignment.Right, ZIndex = 3 })

-- Conteudo modo OCIOSO (retrato 3D do personagem escolhido + botao para abrir o seletor Equipe + crafting +20)
local idleView = UI.frame(body, { Name = "IdleView", ZIndex = 2 })
local charPanel, charFace = UI.panel(idleView, { Name = "SelectedChar", Color = "slot", Corner = 0.08, Shadow = false, ZIndex = 2 })
selectedPortrait = TeamCards.new(charFace, { Name = "SelectedCard", ZIndex = 3 })
selectedPortrait.Root.Activated:Connect(function()
	UI.play("click")
	if onPickCharacter then
		onPickCharacter()
	end
end)
local selectedMeta = UI.text(charFace, "", { Name = "SelectedMeta", Role = "Small", Color = "inkSoft", StrokeMult = 0.45, ZIndex = 4 })
local pickCharBtn = UI.button(charFace, {
	Name = "PickCharacter", Text = "ESCOLHER", Icon = "team", Layout = "row", Color = "blue", Role = "Small", Corner = 0.25, ZIndex = 4,
	OnClick = function()
		if onPickCharacter then
			onPickCharacter()
		end
	end,
})
local configPanel, configFace = UI.panel(idleView, { Name = "Config", Color = "slot", Corner = 0.08, Shadow = false, ZIndex = 2 })
local configTitle = UI.text(configFace, "", { Name = "Title", Role = "Small", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.45, ZIndex = 3 })
local statGrid = UI.frame(configFace, { Name = "StatGrid", ZIndex = 3 })
local configFooter = UI.frame(configFace, { Name = "Footer", ZIndex = 3 })
local summaryLabel = UI.text(configFooter, "", { Name = "Summary", Role = "Small", Rich = true, AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.45, ZIndex = 4 })
local startBtn = UI.button(configFooter, { Name = "StartTraining", Text = "INICIAR TREINO", Icon = "sparkle", Layout = "row", Color = "green", Role = "Small", Corner = 0.25, ZIndex = 4,
	OnClick = function() if onStartTraining then onStartTraining() end end,
})
do
	local si = startBtn.Face:FindFirstChild("Icon")
	if si then
		si.Size = UDim2.fromScale(0.18, 0.48)
		si.Position = UDim2.fromScale(0.06, 0.5)
	end
	local sl = startBtn.Face:FindFirstChild("Label")
	if sl then
		sl.Size = UDim2.fromScale(0.68, 0.70)
		sl.Position = UDim2.fromScale(0.27, 0.15)
	end
end

local statCards = {}
for _, statKey in ipairs(Training.OreOrder) do
	local oreCfg = Training.Ores[statKey]
	local card, cface = UI.panel(statGrid, { Name = "Card_" .. statKey, Color = "panelAlt", Corner = 0.18, Shadow = false, ZIndex = 3 })
	UI.stroke(cface, oreCfg.Color, 0.9)
	local title = UI.text(cface, "", { Name = "Title", Role = "Small", Rich = true, AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.45, ZIndex = 4 })
	local oreIcon = UI.icon(cface, oreCfg.Icon or "ore", { Name = "OreIcon", ZIndex = 4 })
	local costTxt = UI.text(cface, "", { Name = "Cost", Role = "Small", Rich = true, AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.4, ZIndex = 4 })
	local minusBtn = UI.button(cface, { Name = "Minus", Text = "-", Color = "red", Role = "Body", Corner = 0.3, ZIndex = 4,
		OnClick = function() if onStepStat then onStepStat(statKey, -Training.Step) end end,
	})
	local plusBtn = UI.button(cface, { Name = "Plus", Text = "+", Color = "teal", Role = "Body", Corner = 0.3, ZIndex = 4,
		OnClick = function() if onStepStat then onStepStat(statKey, Training.Step) end end,
	})
	statCards[statKey] = {
		Card = card,
		Face = cface,
		Title = title,
		OreIcon = oreIcon,
		Cost = costTxt,
		Minus = minusBtn,
		Plus = plusBtn,
	}
end

-- Conteudo modo ATIVO (personagem na capsula)
local activeView, activeFace = UI.panel(body, { Name = "ActiveView", Color = "slot", Corner = 0.08, Shadow = false, Visible = false, ZIndex = 2 })
activePortrait = TeamCards.new(activeFace, { Name = "Portrait", ZIndex = 3 })
activePortrait.Root.Active = false
activePortrait.Root.Selectable = false
local activeTitle = UI.text(activeFace, "", { Name = "Title", Role = "Heading", AlignX = Enum.TextXAlignment.Left, ZIndex = 3 })
local activeGains = UI.text(activeFace, "", { Name = "Gains", Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.45, ZIndex = 3 })
local activeBar = UI.bar(activeFace, { Name = "Progress", ZIndex = 3 })
local activeTimer = UI.text(activeFace, "", { Name = "Timer", Role = "Small", Color = "gold", AlignX = Enum.TextXAlignment.Left, ZIndex = 3 })
local activeActionBtn = UI.button(activeFace, { Name = "JobAction", Text = "RESGATAR", Color = "green", Role = "Body", Corner = 0.24, ZIndex = 4, Sound = false,
	OnClick = function() if onActiveAction then onActiveAction() end end,
})

local function showMsg(ok: boolean, text: string?)
	msgLabel.TextColor3 = if ok then T.Palette.gold else T.Palette.hpLow
	msgLabel.Text = text or ""
	if not ok then
		UI.play("error")
	end
end

local function layout()
	local rawW, rawH = UI.unscaledSize(body)
	local W, H = math.floor(rawW + 0.5), math.floor(rawH + 0.5)
	if W < 20 or H < 20 then
		return
	end
	local pad = 6
	local topH = math.max(T.TouchMin, 48)
	topBar.Position = UDim2.fromOffset(0, 0)
	topBar.Size = UDim2.fromOffset(W, topH)

	local upW = math.clamp(math.floor(W * 0.28), 130, 230)
	local infoW = math.max(120, W - upW - pad * 3)
	machineLabel.Position = UDim2.fromOffset(8, 2)
	machineLabel.Size = UDim2.fromOffset(infoW, math.floor(topH * 0.44))
	oresRow.Position = UDim2.fromOffset(8, math.floor(topH * 0.48))
	oresRow.Size = UDim2.fromOffset(infoW, math.floor(topH * 0.48))

	upgradeBtn.AnchorPoint = Vector2.new(1, 0.5)
	upgradeBtn.Position = UDim2.fromOffset(W - 4, math.floor(topH / 2))
	upgradeBtn.Size = UDim2.fromOffset(upW, T.TouchMin)

	local msgH = 18
	msgLabel.AnchorPoint = Vector2.new(1, 1)
	msgLabel.Position = UDim2.fromOffset(W, H)
	msgLabel.Size = UDim2.fromOffset(W, msgH)

	local contentY = topH + pad
	local contentH = math.max(90, H - contentY - msgH - 2)
	idleView.Position = UDim2.fromOffset(0, contentY)
	idleView.Size = UDim2.fromOffset(W, contentH)
	activeView.Position = UDim2.fromOffset(0, contentY)
	activeView.Size = UDim2.fromOffset(W, contentH)

	-- Idle: Retrato 3D + botao Escolher a esquerda | Configurador 2x2 a direita
	local leftW = math.clamp(math.floor(W * 0.30), 156, 290)
	local rightW = math.max(160, W - leftW - pad)
	charPanel.Position = UDim2.fromOffset(0, 0)
	charPanel.Size = UDim2.fromOffset(leftW, contentH)
	configPanel.Position = UDim2.fromOffset(leftW + pad, 0)
	configPanel.Size = UDim2.fromOffset(rightW, contentH)

	local padL = 8
	local btnH = T.TouchMin
	local metaH = if contentH < 150 then 16 else 22
	pickCharBtn.Position = UDim2.fromOffset(padL, contentH - padL - btnH)
	pickCharBtn.Size = UDim2.fromOffset(math.max(88, leftW - padL * 2), btnH)
	selectedMeta.Position = UDim2.fromOffset(padL, contentH - padL - btnH - metaH - 4)
	selectedMeta.Size = UDim2.fromOffset(math.max(88, leftW - padL * 2), metaH)
	local availCardH = math.max(48, contentH - padL * 2 - btnH - metaH - 10)
	local cardS = math.clamp(math.min(leftW - padL * 2, availCardH), 48, 168)
	selectedPortrait.Root.Position = UDim2.fromOffset(math.floor((leftW - cardS) / 2), padL + math.max(0, math.floor((availCardH - cardS) / 2)))
	selectedPortrait.Root.Size = UDim2.fromOffset(cardS, cardS)

	local cp = 8
	local cw, ch = rightW - cp * 2, contentH - cp * 2
	local titleH = math.max(16, math.floor(ch * 0.11))
	local footerH = T.TouchMin
	configTitle.Position = UDim2.fromOffset(cp, cp)
	configTitle.Size = UDim2.fromOffset(cw, titleH)

	configFooter.Position = UDim2.fromOffset(cp, contentH - cp - footerH)
	configFooter.Size = UDim2.fromOffset(cw, footerH)
	local startW = math.clamp(math.floor(cw * 0.38), 110, 190)
	summaryLabel.Position = UDim2.fromOffset(0, 0)
	summaryLabel.Size = UDim2.fromOffset(math.max(80, cw - startW - 6), footerH)
	startBtn.AnchorPoint = Vector2.new(1, 0)
	startBtn.Position = UDim2.fromOffset(cw, 0)
	startBtn.Size = UDim2.fromOffset(startW, footerH)

	local gridY = cp + titleH + 4
	local gridH = math.max(80, contentH - gridY - footerH - cp - 4)
	statGrid.Position = UDim2.fromOffset(cp, gridY)
	statGrid.Size = UDim2.fromOffset(cw, gridH)

	local gGap = 6
	local cellW = math.floor((cw - gGap) / 2)
	local cellH = math.floor((gridH - gGap) / 2)
	for idx, statKey in ipairs(Training.OreOrder) do
		local col = (idx - 1) % 2
		local row = (idx - 1) // 2
		local sc = statCards[statKey]
		sc.Card.Position = UDim2.fromOffset(col * (cellW + gGap), row * (cellH + gGap))
		sc.Card.Size = UDim2.fromOffset(cellW, cellH)

		local btnS = T.TouchMin
		local btnAreaW = btnS * 2 + 4
		local textW = math.max(40, cellW - btnAreaW - 10)
		local halfH = math.floor((cellH - 4) / 2)
		local iconS = math.clamp(math.floor(halfH * 0.62), 14, 20)
		sc.Title.Position = UDim2.fromOffset(6, 2)
		sc.Title.Size = UDim2.fromOffset(textW, halfH)
		local costH = cellH - halfH - 4
		sc.OreIcon.Position = UDim2.fromOffset(6, 2 + halfH + math.floor((costH - iconS) / 2))
		sc.OreIcon.Size = UDim2.fromOffset(iconS, iconS)
		sc.Cost.Position = UDim2.fromOffset(6 + iconS + 4, 2 + halfH)
		sc.Cost.Size = UDim2.fromOffset(math.max(24, textW - iconS - 4), costH)

		local by = math.floor((cellH - btnS) / 2)
		sc.Minus.Position = UDim2.fromOffset(cellW - btnAreaW - 4, by)
		sc.Minus.Size = UDim2.fromOffset(btnS, btnS)
		sc.Plus.Position = UDim2.fromOffset(cellW - btnS - 4, by)
		sc.Plus.Size = UDim2.fromOffset(btnS, btnS)
	end

	-- Active: Retrato a esquerda + Status/Progresso/Acao a direita
	local pSize = math.clamp(math.min(math.floor(W * 0.25), contentH - 20), 68, 168)
	activePortrait.Root.AnchorPoint = Vector2.new(0, 0.5)
	activePortrait.Root.Position = UDim2.fromOffset(14, math.floor(contentH / 2))
	activePortrait.Root.Size = UDim2.fromOffset(pSize, pSize)

	local rx = 14 + pSize + 16
	local rw = math.max(120, W - rx - 14)
	local ry = math.max(10, math.floor((contentH - 134) / 2))
	activeTitle.Position = UDim2.fromOffset(rx, ry)
	activeTitle.Size = UDim2.fromOffset(rw, 26)
	activeGains.Position = UDim2.fromOffset(rx, ry + 28)
	activeGains.Size = UDim2.fromOffset(rw, 22)
	activeBar.Position = UDim2.fromOffset(rx, ry + 56)
	activeBar.Size = UDim2.fromOffset(rw, 18)
	activeTimer.Position = UDim2.fromOffset(rx, ry + 78)
	activeTimer.Size = UDim2.fromOffset(rw, 22)
	activeActionBtn.Position = UDim2.fromOffset(rx, math.min(contentH - T.TouchMin - 6, ry + 104))
	activeActionBtn.Size = UDim2.fromOffset(math.min(rw, 280), T.TouchMin)
end
body:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

local refresh

local function clampDraftToMember(member)
	local cur = Genetics.SanitizeTable(member and member.Training)
	for _, st in ipairs(Training.Stats) do
		local maxAdd = math.max(0, ((Training.Max - (cur[st] or 0)) // Training.Step) * Training.Step)
		draft[st] = math.clamp(draft[st] or 0, 0, maxAdd)
	end
end

local function refreshConfig()
	if not profile or not selectedUid or not profile.Collection[selectedUid] then
		configTitle.Text = "Selecione um personagem"
		summaryLabel.Text = ""
		UI.setDisabled(startBtn, true, "green")
		return
	end
	local member = profile.Collection[selectedUid]
	local def = Characters.Get(member.CharacterId)
	local rarity = def and def.Rarity or "Comum"
	clampDraftToMember(member)

	local mLevel = Training.MachineLevelOf(profile)
	local stock = Training.SanitizeOres(profile.TrainingOres, Training.MaxOrePerType)
	local curTrn = Genetics.SanitizeTable(member.Training)

	local rarName = Summon.RarityName and Summon.RarityName[rarity] or rarity
	configTitle.Text = string.format("%s (%s · Custo %.2fx · Tempo %.2fx)", def and def.Name or member.CharacterId, rarName, Training.RarityCostMult[rarity] or 1, Training.RarityTimeMult[rarity] or 1)

	local cost, selectedCount, multiMult = Training.CalculateCost(rarity, draft)
	local dur = Training.CalculateDuration(mLevel, rarity, draft)

	local canAfford = selectedCount > 0
	for _, statKey in ipairs(Training.OreOrder) do
		local oreCfg = Training.Ores[statKey]
		local sc = statCards[statKey]
		local curVal = curTrn[statKey] or 0
		local addVal = draft[statKey] or 0
		local need = cost[statKey] or 0
		local have = stock[statKey] or 0
		local hex = oreCfg.Color:ToHex()

		if addVal > 0 then
			sc.Title.Text = string.format("<font color='#%s'>%s</font> %d%% \u{2192} <font color='#73F5FF'>%d%%</font>", hex, Training.StatLabels[statKey].Short, curVal, curVal + addVal)
		else
			sc.Title.Text = string.format("<font color='#%s'>%s</font> %d%% / 100%%", hex, Training.StatLabels[statKey].Short, curVal)
		end

		if need > 0 then
			local okCol = if have >= need then "#4BE07A" else "#FF4D5E"
			sc.Cost.Text = string.format("<font color='#%s'>%d/%d</font>", okCol, have, need)
			if have < need then
				canAfford = false
			end
		else
			sc.Cost.Text = string.format("Disp.: %d", have)
		end

		local canSub = addVal >= Training.Step
		local canAdd = curVal + addVal + Training.Step <= Training.Max
		UI.setDisabled(sc.Minus, not canSub, "red")
		UI.setDisabled(sc.Plus, not canAdd, "teal")
	end

	local loneTeam = #profile.Team <= 1 and table.find(profile.Team, selectedUid) ~= nil
	if loneTeam then
		summaryLabel.Text = "<font color='#FF4D5E'>Deixe outro personagem no time primeiro.</font>"
		canAfford = false
	elseif selectedCount == 0 then
		summaryLabel.Text = "Escolha passos de +20 nos atributos desejados."
	else
		local extraTxt = if selectedCount > 1 then string.format(" · Custo +%.0f%% (%d atribs)", (multiMult - 1) * 100, selectedCount) else ""
		summaryLabel.Text = string.format("Dura\u{e7}\u{e3}o: <font color='#FFD447'>%s</font>%s", fmtTime(dur), extraTxt)
	end

	UI.setDisabled(startBtn, not canAfford, "green")
end

local function refreshActiveJob()
	local job = profile and profile.TrainingMachine and profile.TrainingMachine.Job
	if not job then
		return
	end
	local member = profile.Collection[job.Uid]
	local def = member and Characters.Get(member.CharacterId)
	activePortrait.Set(job.Uid, member)
	activeTitle.Text = (def and def.Name or "Personagem") .. "  \u{b7}  Nv. " .. tostring(member and member.Level or 1)

	local parts = {}
	for _, st in ipairs(Training.OreOrder) do
		local v = job.Targets and job.Targets[st] or 0
		if v > 0 then
			table.insert(parts, Training.StatLabels[st].Short .. " +" .. v .. "%")
		end
	end
	activeGains.Text = "Treinando: " .. table.concat(parts, "  \u{b7}  ")

	local dur = math.max(1, job.Duration or 1)
	local left = math.max(0, (job.EndsAt or 0) - nowClient())
	local frac = math.clamp(1 - left / dur, 0, 1)
	local ready = left <= 0
	UI.setBar(activeBar, frac, if ready then "hpHigh" else "teal", true)

	if ready then
		activeTimer.Text = "\u{2713} Treino conclu\u{ed}do! Clique para resgatar."
		activeTimer.TextColor3 = T.Palette.hpHigh
		UI.paint(activeActionBtn, "green")
		UI.setText(activeActionBtn, "RESGATAR TREINO")
	else
		activeTimer.Text = string.format("Restante: %s  /  %s", fmtTime(left), fmtTime(dur))
		activeTimer.TextColor3 = T.Palette.gold
		UI.paint(activeActionBtn, "red")
		UI.setText(activeActionBtn, "CANCELAR (50% MIN.)")
	end
end

local function isFullyTrained(member): boolean
	local cur = Genetics.SanitizeTable(member and member.Training)
	for _, st in ipairs(Training.Stats) do
		if (cur[st] or 0) + Training.Step <= Training.Max then
			return false
		end
	end
	return true
end

onPickCharacter = function()
	if not profile then
		return
	end
	UI.pickCharacter({
		Title = "ESCOLHER PARA TREINO",
		HeaderColor = "teal",
		Icon = "sparkle",
		Subtitle = "Escolha quem entrar\u{e1} na C\u{e1}psula de Treino",
		ActionLabel = "TREINAR ESTE",
		ActionColor = "teal",
		ReturnTo = "Training",
		SelectedUid = selectedUid,
		GetBadge = function(uid, m, _def, prof)
			if #prof.Team <= 1 and table.find(prof.Team, uid) ~= nil then
				return "\u{da}NICO TIME", "red"
			end
			if isFullyTrained(m) then
				return "TRN 100%", "gold"
			end
			local trnAvg = math.floor(Genetics.Average(m.Training) + 0.5)
			if trnAvg > 0 then
				return string.format("TRN %d%%", trnAvg), "teal"
			end
			if table.find(prof.Team, uid) ~= nil then
				return "NO TIME", "green"
			end
			return nil, nil
		end,
		IsEligible = function(uid, m, _def, prof)
			if #prof.Team <= 1 and table.find(prof.Team, uid) ~= nil then
				return false, "Deixe outro personagem no time primeiro."
			end
			if isFullyTrained(m) then
				return false, "Treino j\u{e1} est\u{e1} em 100%."
			end
			return true, nil
		end,
		OnPick = function(uid)
			selectedUid = uid
			draft = Training.ZeroOres()
			msgLabel.Text = ""
			return true, nil, true
		end,
	})
end

refresh = function()
	if not profile then
		return
	end
	local mLevel = Training.MachineLevelOf(profile)
	local speed = Training.SpeedMultiplier(mLevel)
	local basicSec = math.max(5, math.floor(Training.BaseStepSeconds / speed + 0.5))
	machineLabel.Text = string.format("C\u{e1}psula Nv. %d/%d  \u{b7}  Efici\u{ea}ncia %.2fx (%ds no +20 b\u{e1}sico)", mLevel, Training.MaxLevel, speed, basicSec)

	local stock = Training.SanitizeOres(profile.TrainingOres, Training.MaxOrePerType)
	for _, st in ipairs(Training.OreOrder) do
		local slot = topOreSlots[st]
		slot.Label.Text = string.format("%s: %d", Training.StatLabels[st].Short, stock[st] or 0)
	end

	local upCost = Training.NextMachineCost(mLevel)
	UI.setText(upgradeBtn, if upCost then ("UP M\u{c1}Q: " .. UI.fmt(upCost) .. " G") else "M\u{c1}QUINA M\u{c1}X")
	UI.setDisabled(upgradeBtn, not upCost, "gold")

	local job = profile.TrainingMachine and profile.TrainingMachine.Job
	idleView.Visible = job == nil
	activeView.Visible = job ~= nil

	if job then
		selectedPortrait.Clear()
		refreshActiveJob()
		return
	end
	activePortrait.Clear()

	-- Escolhe um personagem inicial valido se nenhum estiver selecionado
	if not selectedUid or not profile.Collection[selectedUid] then
		local uids = {}
		for uid in pairs(profile.Collection) do
			table.insert(uids, uid)
		end
		table.sort(uids, function(a, b)
			local ma, mb = profile.Collection[a], profile.Collection[b]
			if ma.Level ~= mb.Level then
				return ma.Level > mb.Level
			end
			return a < b
		end)
		selectedUid = uids[1]
		for _, uid in ipairs(uids) do
			local m = profile.Collection[uid]
			local lone = #profile.Team <= 1 and table.find(profile.Team, uid) ~= nil
			if not lone and not isFullyTrained(m) then
				selectedUid = uid
				break
			end
		end
		draft = Training.ZeroOres()
	end

	local selMember = selectedUid and profile.Collection[selectedUid]
	if selMember then
		selectedPortrait.Set(selectedUid, selMember)
		local genAvg = math.floor(Genetics.Average(selMember.Genetics) + 0.5)
		local trnAvg = math.floor(Genetics.Average(selMember.Training) + 0.5)
		local onTeam = table.find(profile.Team, selectedUid) ~= nil
		selectedMeta.Text = string.format("GEN %d%% · TRN %d%%%s", genAvg, trnAvg, if onTeam then " · [TIME]" else "")
		UI.setText(pickCharBtn, "TROCAR")
	else
		selectedPortrait.Clear()
		selectedMeta.Text = "Nenhum personagem"
		UI.setText(pickCharBtn, "ESCOLHER")
	end

	refreshConfig()
end

onStepStat = function(statKey: string, delta: number)
	if not profile or not selectedUid then
		return
	end
	local m = profile.Collection[selectedUid]
	local baseVal = (m and m.Training and m.Training[statKey]) or 0
	local cur = draft[statKey] or 0
	local nxt = cur + delta
	if nxt >= 0 and baseVal + nxt <= Training.Max then
		draft[statKey] = nxt
		refreshConfig()
	end
end

onUpgradeMachine = function()
	if upgradeBtn:GetAttribute("Disabled") then return end
	local ok, text = Remotes:WaitForChild("TrainingUpgrade"):InvokeServer()
	showMsg(ok, text)
	if ok then UI.play("purchase") end
end

onStartTraining = function()
	if startBtn:GetAttribute("Disabled") or not selectedUid then return end
	local ok, text = Remotes:WaitForChild("TrainingStart"):InvokeServer(selectedUid, draft)
	showMsg(ok, text)
	if ok then
		draft = Training.ZeroOres()
		UI.play("reward")
	end
end

onActiveAction = function()
	local job = profile and profile.TrainingMachine and profile.TrainingMachine.Job
	if not job then return end
	local ready = (job.EndsAt or 0) <= nowClient()
	local remoteName = if ready then "TrainingClaim" else "TrainingCancel"
	local ok, text = Remotes:WaitForChild(remoteName):InvokeServer()
	showMsg(ok, text)
	if ok then
		UI.play(if ready then "reward" else "click")
	end
end

-- Atualiza timer ao vivo a cada 1s enquanto a janela estiver aberta em treino
task.spawn(function()
	while true do
		task.wait(1)
		if win.IsOpen() and profile and profile.TrainingMachine and profile.TrainingMachine.Job then
			refreshActiveJob()
		end
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
	local rem = Remotes:WaitForChild("TrainingOpen", 15)
	if rem and rem:IsA("RemoteEvent") then
		rem.OnClientEvent:Connect(function()
			UI.open("Training")
		end)
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

UI.onOpen("Training", function()
	if not profile or not profile.StarterChosen then
		return
	end
	if UI.inBattle() then
		return
	end
	if win.IsOpen() then
		win.Close()
		return
	end
	msgLabel.Text = ""
	win.Open()
	layout()
	refresh()
	task.defer(layout)
end)

UI.onBattle(function(on)
	if on and win.IsOpen() then
		win.Close(true)
	end
end)
