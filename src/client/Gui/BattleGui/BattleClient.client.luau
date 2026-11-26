--[[
	BattleClient (GDD secoes 5 e 10)
	So mostra a batalha e envia a escolha do jogador. Nenhum calculo acontece aqui.

	Suporta batalhas 1x1 (classico) e 2x2 (Em Dupla, estilo Pokemon):
	  - 1x1: 1 cartao por lado, menu Lutar / Mochila / Time / Fugir, golpes 2x2.
	  - 2x2: 2 cartoes de inimigo em cima a direita (escalonados) e 2 cartoes do jogador embaixo a esquerda
	         (destaque dourado no lutador que esta escolhendo), selecao sequencial Slot 1 -> Slot 2 com
	         botao VOLTAR, seletor de alvo com indicador de efetividade de tipo (2x / 0.5x) e opcao de aliado,
	         badge AREA em golpes que atingem ambos os adversarios, e substituicao dupla.
	Visual: ReplicatedStorage/UI (escala relativa, toque minimo 44 px, animacoes e sons).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local gui = script.Parent
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local StartBattle = Remotes:WaitForChild("StartBattle")
local SubmitAction = Remotes:WaitForChild("SubmitAction")
local BattleUpdate = Remotes:WaitForChild("BattleUpdate")
local BattleEnd = Remotes:WaitForChild("BattleEnd")
local TypeChart = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("TypeChart"))
local Moves = require(ReplicatedStorage.Data:WaitForChild("Moves"))
local DamageCalc = require(ReplicatedStorage:WaitForChild("Core"):WaitForChild("DamageCalc"))
local VfxController = require(ReplicatedStorage:WaitForChild("VfxController"))
local CombatAnimator = require(ReplicatedStorage:WaitForChild("CombatAnimator"))
local UI = require(ReplicatedStorage:WaitForChild("UI"))
local T = UI.Theme

local BATTLE_FOV = 50
local SKIP_PRELOAD_ANIMS = { Idle = true, Walk = true, Mine = true }

-- Carrega antes as animacoes do modelo em campo (ignora Idle/Walk/Mine e procedurais do CombatAnimator)
local function preloadModel(model)
	local folder = model and model:FindFirstChild("Animations")
	if folder then
		local list = {}
		for _, child in ipairs(folder:GetChildren()) do
			if child:IsA("Animation") and not SKIP_PRELOAD_ANIMS[child.Name] and not CombatAnimator.Has(child.Name) then
				table.insert(list, child)
			end
		end
		if #list > 0 then
			task.spawn(function()
				pcall(ContentProvider.PreloadAsync, ContentProvider, list)
			end)
		end
	end
end

local STATUS_BADGE = {
	Burn = { "QUE", Color3.fromRGB(255, 110, 40) },
	Poison = { "VEN", Color3.fromRGB(168, 85, 247) },
	Paralysis = { "PAR", Color3.fromRGB(230, 190, 30) },
	Sleep = { "SON", Color3.fromRGB(125, 130, 160) },
	Freeze = { "CON", Color3.fromRGB(80, 190, 240) },
}

local STAT_ORDER = { "Attack", "Defense", "Speed", "Accuracy" }
local STAT_SHORT = {
	Attack = "ATQ",
	Defense = "DEF",
	Speed = "VEL",
	Accuracy = "PRE",
}

local function formatStageText(stat: string, stage: number): string
	local short = STAT_SHORT[stat] or stat
	if stage == 0 then
		return short .. " 0%"
	end
	local mult = DamageCalc.StageMultiplier(stage)
	local pct = math.floor((mult - 1) * 100 + (if mult >= 1 then 0.5 else -0.5))
	local sign = if pct > 0 then "+" else ""
	return string.format("%s %s%d%%", short, sign, pct)
end

local function typeColor(t)
	return T.Types[t] or TypeChart.Color[t] or T.Palette.grey
end

--------------------------------------------------------------------
-- Montagem da tela
--------------------------------------------------------------------
local canvas = UI.screen(gui)
gui.DisplayOrder = 10
local root = UI.frame(canvas, { Name = "Root", Visible = false })

-- Cartao de vida (suporta 1 ou 2 cartoes por lado) + faixa de alteracoes de atributo (buff/debuff)
local function makeCard(name, anchor, position, stagesBelow: boolean?)
	local holder, face = UI.panel(root, {
		Name = name, Size = UDim2.fromScale(0.29, 0.2), Position = position, AnchorPoint = anchor,
		Color = "panel", Corner = T.Corner.Card, Aspect = 2.7, MaxSize = Vector2.new(380, 141),
	})
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	local borderStroke = face:FindFirstChildOfClass("UIStroke")
	local defaultStrokeColor = if borderStroke then borderStroke.Color else T.Outline
	local defaultStrokeThick = if borderStroke then borderStroke.Thickness else 2

	local title = UI.text(face, "", { Name = "Title", Size = UDim2.fromScale(0.45, 0.3), Position = UDim2.fromScale(0.04, 0.07), Role = "Heading", AlignX = Enum.TextXAlignment.Left })
	title.TextWrapped = false
	local level = UI.text(face, "", { Name = "Level", Size = UDim2.fromScale(0.19, 0.24), Position = UDim2.fromScale(0.50, 0.09), Role = "Small", Color = "gold", AlignX = Enum.TextXAlignment.Center })
	level.TextWrapped = false
	local typeChip = UI.chip(face, "", "grey", { Name = "Type", Size = UDim2.fromScale(0.26, 0.26), Position = UDim2.fromScale(0.70, 0.08) })
	typeChip.Face.Label.TextWrapped = false
	local status = UI.chip(face, "", "grey", { Name = "Status", Size = UDim2.fromScale(0.22, 0.22), Position = UDim2.fromScale(0.05, 0.70), Visible = false })
	local bar = UI.bar(face, { Name = "Hp", Size = UDim2.fromScale(0.9, 0.17), Position = UDim2.fromScale(0.05, 0.45), FillColor = "hpHigh" })
	local hpText = UI.text(face, "", { Name = "HpText", Size = UDim2.fromScale(0.45, 0.24), Position = UDim2.fromScale(0.50, 0.69), Role = "Small", AlignX = Enum.TextXAlignment.Right })

	-- Faixa externa de alteracoes de atributo (ATQ/DEF/VEL/PRE): acima nos cartoes do jogador, abaixo nos inimigos
	local stagesBar = UI.frame(holder, {
		Name = "StagesBar",
		Size = UDim2.fromScale(1, 0.25),
		Position = if stagesBelow then UDim2.fromScale(0, 1.07) else UDim2.fromScale(0, -0.07),
		AnchorPoint = if stagesBelow then Vector2.new(0, 0) else Vector2.new(0, 1),
		Visible = false,
		ZIndex = holder.ZIndex + 2,
	})
	local sl = Instance.new("UIListLayout")
	sl.FillDirection = Enum.FillDirection.Horizontal
	sl.HorizontalAlignment = if stagesBelow then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left
	sl.VerticalAlignment = if stagesBelow then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Bottom
	sl.Padding = UDim.new(0.02, 0)
	sl.SortOrder = Enum.SortOrder.LayoutOrder
	sl.Parent = stagesBar

	local stageChips = {}
	for idx, statKey in ipairs(STAT_ORDER) do
		local chip = UI.chip(stagesBar, "", "green", {
			Name = "Stage_" .. statKey,
			Size = UDim2.fromScale(0.31, 1),
			LayoutOrder = idx,
			Visible = false,
			ZIndex = holder.ZIndex + 3,
		})
		local lbl = chip.Face.Label
		lbl.TextWrapped = false
		lbl.Size = UDim2.fromScale(0.90, 0.82)
		lbl.Position = UDim2.fromScale(0.05, 0.09)
		local popScale = Instance.new("UIScale")
		popScale.Name = "PopScale"
		popScale.Parent = chip
		stageChips[statKey] = chip
	end

	return {
		Frame = holder, Face = face, Scale = scale,
		BorderStroke = borderStroke, DefaultStrokeColor = defaultStrokeColor, DefaultStrokeThick = defaultStrokeThick,
		Title = title, Level = level, Type = typeChip, Status = status, Bar = bar, HpText = hpText,
		StagesBar = stagesBar, StageChips = stageChips, HasStages = false,
	}
end

-- Barra vertical externa com as bolinhas do time (fora dos cartoes dos personagens)
local function makeTeamPipsBar(name: string, anchor: Vector2, position: UDim2)
	local holder, face = UI.panel(root, {
		Name = name,
		Size = UDim2.fromScale(0.024, 0.20),
		Position = position,
		AnchorPoint = anchor,
		Color = "slot",
		Corner = T.Corner.Pill,
		Shadow = false,
		MaxSize = Vector2.new(30, 141),
		MinSize = Vector2.new(20, 88),
	})
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 4)
	pad.Parent = face
	local vl = Instance.new("UIListLayout")
	vl.FillDirection = Enum.FillDirection.Vertical
	vl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	vl.VerticalAlignment = Enum.VerticalAlignment.Center
	vl.Padding = UDim.new(0.04, 0)
	vl.SortOrder = Enum.SortOrder.LayoutOrder
	vl.Parent = face
	return { Frame = holder, Container = face }
end

local playerTeamPips = makeTeamPipsBar("PlayerTeamPips", Vector2.new(0, 1), UDim2.fromScale(0.010, 0.975))
local enemyTeamPips = makeTeamPipsBar("EnemyTeamPips", Vector2.new(1, 0), UDim2.fromScale(0.990, 0.015))

local enemyCards = {
	makeCard("EnemyCard1", Vector2.new(1, 0), UDim2.fromScale(0.958, 0.015), true),
	makeCard("EnemyCard2", Vector2.new(1, 0), UDim2.fromScale(0.942, 0.015), true),
}
enemyCards[2].Frame.Visible = false

local playerCards = {
	makeCard("PlayerCard1", Vector2.new(0, 1), UDim2.fromScale(0.042, 0.975), false),
	makeCard("PlayerCard2", Vector2.new(0, 1), UDim2.fromScale(0.302, 0.975), false),
}
playerCards[2].Frame.Visible = false

-- Faixas compactas de efeitos de campo/hazards por lado (visiveis apenas quando algum efeito esta ativo)
local function makeFieldBar(name: string, anchor: Vector2, position: UDim2, vertical: boolean)
	local bar = UI.frame(root, {
		Name = name,
		Size = if vertical then UDim2.fromScale(0.115, 0.19) else UDim2.fromScale(0.46, 0.036),
		Position = position,
		AnchorPoint = anchor,
		Visible = false,
		ZIndex = 3,
	})
	local ll = Instance.new("UIListLayout")
	ll.FillDirection = if vertical then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
	ll.HorizontalAlignment = if vertical then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left
	ll.VerticalAlignment = if vertical then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Center
	ll.Padding = UDim.new(0, 4)
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Parent = bar
	return { Frame = bar, Vertical = vertical }
end

local playerFieldBar = makeFieldBar("PlayerFieldBar", Vector2.new(0, 1), UDim2.fromScale(0.042, 0.72), false)
local enemyFieldBar = makeFieldBar("EnemyFieldBar", Vector2.new(1, 0), UDim2.fromScale(0.658, 0.015), true)

-- Mensagem do turno (topo a esquerda, no ceu)
local logHolder, logFace = UI.panel(root, { Name = "Log", Size = UDim2.fromScale(0.55, 0.15), Position = UDim2.fromScale(0.015, 0.015), Color = "slot", Corner = 0.3, Transparency = 0.1, Shadow = false, MaxSize = Vector2.new(720, 90) })
local logLabel = UI.text(logFace, "", { Name = "Text", Size = UDim2.fromScale(0.94, 0.8), Position = UDim2.fromScale(0.03, 0.1), Role = "Small", AlignX = Enum.TextXAlignment.Left, Rich = true, StrokeMult = 0.5 })

-- Banner rapido estilo Pokemon quando uma Passiva dispara em batalha
local passiveBanner, passiveBannerFace = UI.panel(root, {
	Name = "PassiveCallout",
	Size = UDim2.fromScale(0.28, 0.075),
	Position = UDim2.fromScale(0.015, 0.185),
	Color = "panelAlt",
	Corner = 0.32,
	Shadow = false,
	Visible = false,
	MaxSize = Vector2.new(340, 52),
	ZIndex = 12,
})
local passiveBannerIcon = UI.icon(passiveBannerFace, "sparkle", {
	Name = "Icon",
	Size = UDim2.fromScale(0.14, 0.68),
	Position = UDim2.fromScale(0.04, 0.16),
	ZIndex = 13,
})
local passiveBannerTitle = UI.text(passiveBannerFace, "", {
	Name = "Title",
	Size = UDim2.fromScale(0.78, 0.84),
	Position = UDim2.fromScale(0.20, 0.08),
	Role = "Small",
	AlignX = Enum.TextXAlignment.Left,
	Rich = true,
	StrokeMult = 0.45,
	ZIndex = 13,
})
local passiveBannerToken = 0
local function showPassiveBanner(side: string?, actorName: string?, passiveName: string?, tier: string?)
	passiveBannerToken += 1
	local tok = passiveBannerToken
	local isEnemy = side == "Enemy"
	local tierHex = if tier == "Secret" then "#F578FF" elseif tier == "Unique" then "#FFD154" else "#76C8FF"
	local panelCol = if tier == "Secret" then "purple" else "panelAlt"
	UI.paint(passiveBanner, panelCol)
	UI.setIcon(passiveBannerIcon, if tier == "Secret" or tier == "Unique" then "star" else "sparkle")
	passiveBannerTitle.Text = string.format("<font color='%s'><b>%s</b></font>  \u{b7}  %s", tierHex, passiveName or "Passiva", actorName or "")
	passiveBanner.AnchorPoint = Vector2.new(if isEnemy then 1 else 0, 0)
	local startPos = UDim2.fromScale(if isEnemy then 1.04 else -0.04, 0.185)
	local endPos = UDim2.fromScale(if isEnemy then 0.985 else 0.015, 0.185)
	passiveBanner.Position = startPos
	passiveBanner.Visible = true
	TweenService:Create(passiveBanner, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = endPos }):Play()
	task.delay(1.35, function()
		if passiveBannerToken == tok then
			local outTw = TweenService:Create(passiveBanner, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = startPos })
			outTw:Play()
			outTw.Completed:Connect(function()
				if passiveBannerToken == tok then
					passiveBanner.Visible = false
				end
			end)
		end
	end)
end

-- Area dos comandos (embaixo a direita)
local menuArea = UI.frame(root, { Name = "MenuArea", Size = UDim2.fromScale(0.32, 0.44), Position = UDim2.fromScale(0.985, 0.93), AnchorPoint = Vector2.new(1, 1), Aspect = 1.75, MaxSize = Vector2.new(480, 275) })
local waitingHolder, waitingFace = UI.panel(menuArea, { Name = "Waiting", Size = UDim2.fromScale(0.7, 0.24), Position = UDim2.fromScale(1, 1), AnchorPoint = Vector2.new(1, 1), Color = "slot", Corner = T.Corner.Pill, Shadow = false })
local waitingLabel = UI.text(waitingFace, "...", { Name = "Text", Size = UDim2.fromScale(0.9, 0.7), Position = UDim2.fromScale(0.05, 0.15), Role = "Body" })

local function page(name)
	return UI.frame(menuArea, { Name = name, Visible = false })
end

local mainPage = page("Main")
local mainActorChip = UI.chip(mainPage, "", "orange", { Name = "ActorChip", Size = UDim2.fromScale(0.68, 0.22), Position = UDim2.fromScale(0, -0.06), AnchorPoint = Vector2.new(0, 1), Visible = false })
local mainStepBack = UI.button(mainPage, { Name = "StepBack", Text = "VOLTAR", Color = "grey", Size = UDim2.fromScale(0.3, 0.22), Position = UDim2.fromScale(1, -0.06), AnchorPoint = Vector2.new(1, 1), Corner = 0.3, Role = "Small", Visible = false })

local function cmd(name, text, icon, color, i)
	local col, row = (i - 1) % 2, (i - 1) // 2
	return UI.button(mainPage, {
		Name = name, Text = text, Icon = icon, Color = color, Layout = "row", Role = "Heading",
		Size = UDim2.fromScale(0.48, 0.46), Position = UDim2.fromScale(col * 0.52, row * 0.54), Corner = 0.24,
	})
end
local fightButton = cmd("Fight", "LUTAR", "sword", "orange", 1)
local bagButton = cmd("Bag", "MOCHILA", "bag", "green", 2)
local teamButton = cmd("Team", "TIME", "swap", "blue", 3)
local fleeButton = cmd("Flee", "FUGIR", "run", "grey", 4)

-- Golpes: grade 2x2 mais larga, no mesmo canto, com Voltar e chip do lutador acima
local movesPage = UI.frame(root, { Name = "Moves", Size = UDim2.fromScale(0.4, 0.44), Position = UDim2.fromScale(0.985, 0.93), AnchorPoint = Vector2.new(1, 1), Aspect = 2.3, Visible = false, MaxSize = Vector2.new(640, 280) })
local movesActorChip = UI.chip(movesPage, "", "orange", { Name = "ActorChip", Size = UDim2.fromScale(0.68, 0.22), Position = UDim2.fromScale(0, -0.06), AnchorPoint = Vector2.new(0, 1), Visible = false })
local moveButtons = {}
for i = 1, 4 do
	local col, row = (i - 1) % 2, (i - 1) // 2
	local b, face = UI.button(movesPage, { Name = "Move" .. i, Color = "grey", Size = UDim2.fromScale(0.485, 0.46), Position = UDim2.fromScale(col * 0.515, row * 0.54), Corner = 0.22 })
	UI.text(face, "", { Name = "MoveName", Size = UDim2.fromScale(0.74, 0.42), Position = UDim2.fromScale(0.05, 0.06), Role = "Body", AlignX = Enum.TextXAlignment.Left })
	UI.chip(face, "\u{c1}REA", "gold", { Name = "ScopeChip", Size = UDim2.fromScale(0.24, 0.28), Position = UDim2.fromScale(0.95, 0.11), AnchorPoint = Vector2.new(1, 0), Visible = false })
	UI.chip(face, "", "slot", { Name = "TypeChip", Size = UDim2.fromScale(0.42, 0.32), Position = UDim2.fromScale(0.05, 0.58) })
	UI.text(face, "", { Name = "Pp", Size = UDim2.fromScale(0.46, 0.3), Position = UDim2.fromScale(0.5, 0.59), Role = "Small", AlignX = Enum.TextXAlignment.Right })
	moveButtons[i] = b
end
local movesBack = UI.button(movesPage, { Name = "Back", Text = "VOLTAR", Color = "grey", Size = UDim2.fromScale(0.26, 0.22), Position = UDim2.fromScale(1, -0.06), AnchorPoint = Vector2.new(1, 1), Corner = 0.3, Role = "Body" })

-- Seletor de Alvo (2x2): escolhe inimigo da esquerda (Slot 2), direita (Slot 1) ou aliado
local targetPage = UI.frame(root, { Name = "Targets", Size = UDim2.fromScale(0.4, 0.44), Position = UDim2.fromScale(0.985, 0.93), AnchorPoint = Vector2.new(1, 1), Aspect = 2.3, Visible = false, MaxSize = Vector2.new(640, 280) })
local targetHeaderChip = UI.chip(targetPage, "ESCOLHA O ALVO", "orange", { Name = "HeaderChip", Size = UDim2.fromScale(0.7, 0.22), Position = UDim2.fromScale(0, -0.06), AnchorPoint = Vector2.new(0, 1) })
local targetBack = UI.button(targetPage, { Name = "Back", Text = "VOLTAR", Color = "grey", Size = UDim2.fromScale(0.26, 0.22), Position = UDim2.fromScale(1, -0.06), AnchorPoint = Vector2.new(1, 1), Corner = 0.3, Role = "Body" })

local function makeTargetEnemyBtn(name: string, xScale: number)
	local b, face = UI.button(targetPage, { Name = name, Color = "panelAlt", Size = UDim2.fromScale(0.485, 0.62), Position = UDim2.fromScale(xScale, 0), Corner = 0.18 })
	UI.text(face, "", { Name = "TargetName", Size = UDim2.fromScale(0.55, 0.32), Position = UDim2.fromScale(0.05, 0.07), Role = "Body", AlignX = Enum.TextXAlignment.Left })
	local tc = UI.chip(face, "", "grey", { Name = "TypeChip", Size = UDim2.fromScale(0.34, 0.26), Position = UDim2.fromScale(0.95, 0.09), AnchorPoint = Vector2.new(1, 0) })
	tc.Face.Label.TextWrapped = false
	UI.bar(face, { Name = "Hp", Size = UDim2.fromScale(0.88, 0.16), Position = UDim2.fromScale(0.06, 0.46), FillColor = "hpHigh" })
	UI.chip(face, "", "slot", { Name = "EffChip", Size = UDim2.fromScale(0.56, 0.24), Position = UDim2.fromScale(0.06, 0.7) })
	UI.text(face, "", { Name = "HpText", Size = UDim2.fromScale(0.32, 0.24), Position = UDim2.fromScale(0.94, 0.7), AnchorPoint = Vector2.new(1, 0), Role = "Small", AlignX = Enum.TextXAlignment.Right })
	return b
end

-- Ordem visual esquerda -> direita na arena: Enemy Slot 2 a esquerda, Enemy Slot 1 a direita
local targetEnemyBtns = {
	[2] = makeTargetEnemyBtn("TargetEnemyLeft", 0),
	[1] = makeTargetEnemyBtn("TargetEnemyRight", 0.515),
}
local targetAllyBtn, targetAllyFace = UI.button(targetPage, {
	Name = "TargetAlly", Color = "slot", Size = UDim2.fromScale(1, 0.3), Position = UDim2.fromScale(0, 0.7), Corner = 0.26, Visible = false,
})
local targetAllyLabel = UI.text(targetAllyFace, "", { Name = "Label", Size = UDim2.fromScale(0.92, 0.76), Position = UDim2.fromScale(0.04, 0.12), Role = "Small", Color = "inkSoft" })

-- Painel central (Time e Mochila), como a tela de time do Pokemon
local sheet, sheetFace = UI.panel(root, { Name = "Sheet", Size = UDim2.fromScale(0.74, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Color = "panel", Corner = 0.06, Visible = false, ZIndex = 5, Aspect = 1.75, MaxSize = Vector2.new(980, 560) })
local sheetScale = Instance.new("UIScale")
sheetScale.Parent = sheet
local sheetTitle = UI.text(sheetFace, "", { Name = "Title", Size = UDim2.fromScale(0.7, 0.12), Position = UDim2.fromScale(0.04, 0.03), Role = "Heading", AlignX = Enum.TextXAlignment.Left })
local sheetBack = UI.button(sheetFace, { Name = "Back", Text = "VOLTAR", Color = "grey", Size = UDim2.fromScale(0.2, 0.12), Position = UDim2.fromScale(0.96, 0.03), AnchorPoint = Vector2.new(1, 0), Corner = 0.3, Role = "Body" })
local teamPage = UI.frame(sheetFace, { Name = "Team", Size = UDim2.fromScale(0.92, 0.76), Position = UDim2.fromScale(0.04, 0.2), Visible = false })
local bagPage = UI.scroll(sheetFace, { Name = "Bag", Size = UDim2.fromScale(0.94, 0.76), Position = UDim2.fromScale(0.03, 0.2), Columns = 3, CellAspect = 2.4, Visible = false })

-- Time: 6 cartoes 3x2
local memberButtons = {}
for i = 1, 6 do
	local col, row = (i - 1) % 3, (i - 1) // 3
	local b, face = UI.button(teamPage, { Name = "Member" .. i, Color = "panelAlt", Size = UDim2.fromScale(0.315, 0.46), Position = UDim2.fromScale(col * 0.3425, row * 0.53), Corner = 0.16 })
	UI.text(face, "", { Name = "MemberName", Size = UDim2.fromScale(0.62, 0.26), Position = UDim2.fromScale(0.06, 0.08), Role = "Body", AlignX = Enum.TextXAlignment.Left })
	UI.text(face, "", { Name = "Level", Size = UDim2.fromScale(0.3, 0.22), Position = UDim2.fromScale(0.66, 0.1), Role = "Small", Color = "gold", AlignX = Enum.TextXAlignment.Right })
	UI.bar(face, { Name = "Hp", Size = UDim2.fromScale(0.88, 0.14), Position = UDim2.fromScale(0.06, 0.44), FillColor = "hpHigh" })
	UI.text(face, "", { Name = "Info", Size = UDim2.fromScale(0.88, 0.24), Position = UDim2.fromScale(0.06, 0.66), Role = "Small", AlignX = Enum.TextXAlignment.Left })
	memberButtons[i] = b
end
local bagItemButtons = {}

-- PvP: tempo do turno (30 s)
local timerHolder, timerFace = UI.panel(root, { Name = "Timer", Size = UDim2.fromScale(0.12, 0.12), Position = UDim2.fromScale(0.5, 0.015), AnchorPoint = Vector2.new(0.5, 0), Color = "slot", Corner = T.Corner.Pill, Visible = false, Aspect = 1.9, MaxSize = Vector2.new(150, 79) })
local timerLabel = UI.text(timerFace, "", { Name = "Text", Size = UDim2.fromScale(0.8, 0.76), Position = UDim2.fromScale(0.1, 0.12), Role = "Heading" })

-- Resultado (vitoria/derrota)
local resultLabel = UI.text(root, "", { Name = "Result", Size = UDim2.fromScale(0.6, 0.22), Position = UDim2.fromScale(0.5, 0.36), AnchorPoint = Vector2.new(0.5, 0.5), Role = "Title", Visible = false, StrokeMult = 1.2, ZIndex = 8 })
local resultScale = Instance.new("UIScale")
resultScale.Parent = resultLabel

--------------------------------------------------------------------
-- Estado do cliente
--------------------------------------------------------------------
local current = nil -- { Id, State, Models, SlotModels, Awaiting, Deadline }
local logLines = {}
local fleeConfirmUntil = 0
local teamMode = "Switch" -- "Switch" | "Replace" | "ItemTarget"
local pendingItemId = nil
local pendingItemKind = nil

-- Plano do turno em 2x2 (Slot 1 -> Slot 2) e selecao de alvo/substituicao
local turnPlan = nil -- { SlotOrder = { ... }, Step = 1, Actions = { [fieldSlot] = action } }
local pendingMoveIndex: number? = nil
local pendingTargetAllySlot: number? = nil
local replacePlan = nil -- { PendingSlots = { ... }, Step = 1, Replacements = { { FieldSlot, Index }, ... } }

local function isDouble(): boolean
	return current ~= nil and current.State ~= nil and (current.State.Format == "2x2" or (current.State.SlotsPerSide or 1) > 1)
end

local function slotsPerSide(): number
	return if isDouble() then 2 else 1
end

local function activeIndexAt(sideState, fieldSlot: number?): number?
	local fs = fieldSlot or 1
	if sideState.ActiveSlots then
		local idx = sideState.ActiveSlots[fs]
		if typeof(idx) == "number" and idx > 0 then
			return idx
		end
		return nil
	end
	return if fs == 1 then sideState.Active else nil
end

local function memberAt(sideState, fieldSlot: number?)
	local idx = activeIndexAt(sideState, fieldSlot)
	return if idx then sideState.Team[idx] else nil
end

local function isOnField(sideState, teamIndex: number): boolean
	for fs = 1, slotsPerSide() do
		if activeIndexAt(sideState, fs) == teamIndex then
			return true
		end
	end
	return false
end

local function aliveFieldSlots(sideState): { number }
	local out = {}
	for fs = 1, slotsPerSide() do
		local m = memberAt(sideState, fs)
		if m and m.Hp > 0 then
			table.insert(out, fs)
		end
	end
	return out
end

local function currentChoosingSlot(): number
	if turnPlan and turnPlan.SlotOrder[turnPlan.Step] then
		return turnPlan.SlotOrder[turnPlan.Step]
	end
	if current and current.State then
		local alive = aliveFieldSlots(current.State.Player)
		return alive[1] or 1
	end
	return 1
end

local function activeOf(sideState, fieldSlot: number?)
	if fieldSlot ~= nil then
		return memberAt(sideState, fieldSlot)
	end
	local fs = currentChoosingSlot()
	return memberAt(sideState, fs) or sideState.Team[sideState.Active]
end

local function slotModelFor(side: string?, fieldSlot: number?): Model?
	if not current or not side then
		return nil
	end
	local fs = fieldSlot or 1
	local sm = current.SlotModels and current.SlotModels[side]
	if sm and sm[fs] then
		return sm[fs]
	end
	if fs == 1 then
		return current.Models and current.Models[side]
	end
	return nil
end

local function setSlotModel(side: string, fieldSlot: number, model: Model?)
	if not current then
		return
	end
	current.SlotModels = current.SlotModels or { Player = {}, Enemy = {} }
	current.SlotModels[side] = current.SlotModels[side] or {}
	current.SlotModels[side][fieldSlot] = model
	if fieldSlot == 1 then
		current.Models[side] = model
	end
end

local function cardFor(side: string, fieldSlot: number?)
	local fs = fieldSlot or 1
	if side == "Player" then
		return playerCards[fs] or playerCards[1]
	end
	return enemyCards[fs] or enemyCards[1]
end

local function updateCardHighlights()
	local choosing = if current and current.Awaiting and isDouble() and turnPlan then currentChoosingSlot() else nil
	for fs = 1, 2 do
		local card = playerCards[fs]
		local active = choosing == fs
		if card.BorderStroke then
			card.BorderStroke.Color = if active then T.Palette.gold else card.DefaultStrokeColor
			card.BorderStroke.Thickness = if active then math.max(4, card.DefaultStrokeThick * 1.8) else card.DefaultStrokeThick
		end
		local targetScale = if active then 1.04 else 1
		if math.abs(card.Scale.Scale - targetScale) > 0.005 then
			TweenService:Create(card.Scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = targetScale }):Play()
		end
	end
end

-- Desloca EnemyCard1 no 2x2 para abrir espaco limpo quando EnemyCard2 tiver badges de atributo ativos
local function updateEnemyCardsStack(instant: boolean?)
	if not isDouble() then
		return
	end
	local y = if enemyCards[2].Frame.Visible and enemyCards[2].HasStages then 0.238 else 0.184
	local targetPos = UDim2.fromScale(0.958, y)
	if instant then
		enemyCards[1].Frame.Position = targetPos
	elseif enemyCards[1].Frame.Position ~= targetPos then
		TweenService:Create(enemyCards[1].Frame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = targetPos }):Play()
	end
end

-- Ajusta tamanho/posicao dos cartoes, barras de bolinhas e log para 1x1 vs 2x2 (sem sobreposicao em nenhuma tela)
local function applyFormatLayout(double: boolean)
	local logMax = logHolder:FindFirstChildOfClass("UISizeConstraint")
	if double then
		-- Log mais compacto para nao encostar no Timer (0.44..0.56)
		logHolder.Size = UDim2.fromScale(0.415, 0.15)
		if logMax then
			logMax.MaxSize = Vector2.new(540, 90)
		end
		-- Barras verticais de bolinhas nas laterais externas (mesma altura dos cartoes 2x2)
		playerTeamPips.Frame.Size = UDim2.fromScale(0.024, 0.16)
		enemyTeamPips.Frame.Size = UDim2.fromScale(0.024, 0.15)
		for _, bar in ipairs({ playerTeamPips, enemyTeamPips }) do
			local sc = bar.Frame:FindFirstChildOfClass("UISizeConstraint")
			if sc then
				sc.MaxSize = Vector2.new(28, 118)
			end
		end
		-- Inimigos escalonados no topo a direita (a esquerda da barra de bolinhas inimiga)
		enemyCards[2].Frame.Size = UDim2.fromScale(0.25, 0.15)
		enemyCards[2].Frame.Position = UDim2.fromScale(0.942, 0.015)
		enemyCards[1].Frame.Size = UDim2.fromScale(0.25, 0.15)
		enemyCards[1].Frame.Position = UDim2.fromScale(0.958, if enemyCards[2].HasStages then 0.238 else 0.184)
		-- Jogador lado a lado embaixo a esquerda (a direita da barra de bolinhas do jogador)
		playerCards[1].Frame.Size = UDim2.fromScale(0.25, 0.16)
		playerCards[1].Frame.Position = UDim2.fromScale(0.042, 0.975)
		playerCards[2].Frame.Size = UDim2.fromScale(0.25, 0.16)
		playerCards[2].Frame.Position = UDim2.fromScale(0.302, 0.975)
		playerFieldBar.Frame.Position = UDim2.fromScale(0.042, 0.755)
		enemyFieldBar.Frame.Position = UDim2.fromScale(0.682, 0.015)
		for _, list in ipairs({ enemyCards, playerCards }) do
			for _, card in ipairs(list) do
				local sc = card.Frame:FindFirstChildOfClass("UISizeConstraint")
				if sc then
					sc.MaxSize = Vector2.new(320, 118)
				end
			end
		end
	else
		logHolder.Size = UDim2.fromScale(0.55, 0.15)
		if logMax then
			logMax.MaxSize = Vector2.new(720, 90)
		end
		playerTeamPips.Frame.Size = UDim2.fromScale(0.024, 0.20)
		enemyTeamPips.Frame.Size = UDim2.fromScale(0.024, 0.20)
		for _, bar in ipairs({ playerTeamPips, enemyTeamPips }) do
			local sc = bar.Frame:FindFirstChildOfClass("UISizeConstraint")
			if sc then
				sc.MaxSize = Vector2.new(30, 141)
			end
		end
		enemyCards[1].Frame.Size = UDim2.fromScale(0.29, 0.2)
		enemyCards[1].Frame.Position = UDim2.fromScale(0.958, 0.015)
		enemyCards[2].Frame.Visible = false
		playerCards[1].Frame.Size = UDim2.fromScale(0.29, 0.2)
		playerCards[1].Frame.Position = UDim2.fromScale(0.042, 0.975)
		playerCards[2].Frame.Visible = false
		playerFieldBar.Frame.Position = UDim2.fromScale(0.042, 0.72)
		enemyFieldBar.Frame.Position = UDim2.fromScale(0.658, 0.015)
		for _, card in ipairs({ enemyCards[1], playerCards[1] }) do
			local sc = card.Frame:FindFirstChildOfClass("UISizeConstraint")
			if sc then
				sc.MaxSize = Vector2.new(380, 141)
			end
		end
	end
end

-- O item pode ser usado neste membro? (mensagem quando nao)
local function itemTargetOk(m)
	if pendingItemKind == "Revive" then
		return m.Hp <= 0, m.Name .. " n\u{e3}o est\u{e1} desmaiado."
	end
	if m.Hp <= 0 then
		return false, m.Name .. " est\u{e1} desmaiado."
	end
	if pendingItemKind == "CureStatus" then
		return m.Status ~= nil, m.Name .. " n\u{e3}o tem status."
	elseif pendingItemKind == "RestorePP" then
		for _, mv in ipairs(m.Moves or {}) do
			if not mv.OncePerBattle and not mv.DomainExclusive and mv.Pp < mv.MaxPp then
				return true
			end
		end
		return false, m.Name .. " est\u{e1} com o PP cheio."
	end
	return m.Hp < m.MaxHp, m.Name .. " j\u{e1} est\u{e1} com o HP cheio."
end

local function openSheet(name)
	if not sheet.Visible then
		sheet.Visible = true
		sheetScale.Scale = T.Motion.OpenFrom
		TweenService:Create(sheetScale, TweenInfo.new(T.Motion.OpenTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		UI.play("open")
	end
	teamPage.Visible = name == "Team"
	bagPage.Visible = name == "Bag"
end

local function showPage(name: string?)
	mainPage.Visible = name == "Main"
	movesPage.Visible = name == "Moves"
	targetPage.Visible = name == "Targets"
	menuArea.Visible = name ~= "Moves" and name ~= "Targets"
	if name == "Team" or name == "Bag" then
		openSheet(name)
	else
		sheet.Visible = false
	end
	waitingHolder.Visible = name == nil
	updateCardHighlights()
end

local function log(text: string)
	table.insert(logLines, text)
	while #logLines > 2 do
		table.remove(logLines, 1)
	end
	logLabel.Text = table.concat(logLines, "\n")
end

local function hpColor(ratio: number)
	return if ratio > 0.5 then "hpHigh" elseif ratio > 0.2 then "hpMid" else "hpLow"
end

local function setHp(card, hp: number, maxHp: number, instant: boolean?)
	local ratio = math.clamp(hp / math.max(1, maxHp), 0, 1)
	UI.setBar(card.Bar, ratio, hpColor(ratio), instant)
	card.HpText.Text = string.format("%d/%d", hp, maxHp)
end

local function setStatus(card, status: string?)
	local badge = status and STATUS_BADGE[status]
	card.Status.Visible = badge ~= nil
	if badge then
		card.Status.Face.Label.Text = badge[1]
		UI.paint(card.Status, badge[2])
	end
end

-- Atualiza a faixa de alteracoes de atributos (buffs verdes / debuffs vermelhos) no cartao do lutador
local function setStages(card, stages: { [string]: number }?, highlightStat: string?, instant: boolean?)
	local activeCount = 0
	if stages then
		for _, statKey in ipairs(STAT_ORDER) do
			if (stages[statKey] or 0) ~= 0 then
				activeCount += 1
			end
		end
	end
	card.HasStages = activeCount > 0
	card.StagesBar.Visible = activeCount > 0
	local chipW = if activeCount >= 4 then 0.235 else 0.31
	for _, statKey in ipairs(STAT_ORDER) do
		local chip = card.StageChips[statKey]
		local st = if stages then (stages[statKey] or 0) else 0
		if st ~= 0 then
			chip.Visible = true
			chip.Size = UDim2.fromScale(chipW, 1)
			chip.Face.Label.Text = formatStageText(statKey, st)
			UI.paint(chip, if st > 0 then "green" else "red")
			if highlightStat == statKey then
				local pop = chip:FindFirstChild("PopScale")
				if pop and pop:IsA("UIScale") then
					pop.Scale = 1.28
					TweenService:Create(pop, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
				end
			end
		else
			chip.Visible = false
		end
	end
	if card == enemyCards[2] then
		updateEnemyCardsStack(instant)
	end
end

-- Bolinhas do time na barra vertical externa: verde = de pe, vermelho = desmaiado
local function setTeamPips(side: string, sideState)
	local bar = if side == "Player" then playerTeamPips else enemyTeamPips
	UI.clear(bar.Container)
	local n = #sideState.Team
	bar.Frame.Visible = n > 0
	for i, m in ipairs(sideState.Team) do
		local dot = UI.frame(bar.Container, {
			Name = "Pip" .. i,
			Size = UDim2.fromScale(0.76, 0.135),
			Color = if m.Hp > 0 then "hpHigh" else "hpLow",
			Aspect = 1,
			Corner = T.Corner.Pill,
			LayoutOrder = i,
		})
		UI.stroke(dot, nil, 0.6)
	end
end

-- Chips de efeitos de campo/hazards ativos no lado (Spikes, ToxicSpikes, StickyWeb, Barrier, Tailwind)
local function setFieldBadges(side: string, sideState)
	local bar = if side == "Player" then playerFieldBar else enemyFieldBar
	UI.clear(bar.Frame)
	if not sideState then
		bar.Frame.Visible = false
		return
	end
	local items = {}
	local se = sideState.SideEffects
	if se then
		if (se.MalevolentShrine or 0) > 0 then
			table.insert(items, { Text = "SANTU\u{c1}RIO " .. se.MalevolentShrine .. "t", Color = "red" })
		end
		if (se.Barrier or 0) > 0 then
			table.insert(items, { Text = "BARREIRA " .. se.Barrier .. "t", Color = "blue" })
		end
		if (se.Tailwind or 0) > 0 then
			table.insert(items, { Text = "VENTO " .. se.Tailwind .. "t", Color = "teal" })
		end
	end
	local h = sideState.Hazards
	if h then
		if (h.Spikes or 0) > 0 then
			table.insert(items, { Text = "ESPINHOS x" .. h.Spikes, Color = "orange" })
		end
		if (h.ToxicSpikes or 0) > 0 then
			table.insert(items, { Text = "T\u{d3}XICO x" .. h.ToxicSpikes, Color = "purple" })
		end
		if h.StickyWeb then
			table.insert(items, { Text = "REDE", Color = "red" })
		end
	end
	bar.Frame.Visible = #items > 0
	for idx, item in ipairs(items) do
		local chipSize = if bar.Vertical then UDim2.fromScale(0.98, 0.175) else UDim2.fromScale(0.21, 1)
		local chip = UI.chip(bar.Frame, item.Text, item.Color, {
			Name = "FieldChip" .. idx,
			Size = chipSize,
			LayoutOrder = idx,
		})
		chip.Face.Label.TextWrapped = false
	end
end

local function refreshSide(side: string, instant: boolean?)
	local sideState = current.State[side]
	local count = slotsPerSide()
	setTeamPips(side, sideState)
	setFieldBadges(side, sideState)
	for fs = 1, 2 do
		local card = cardFor(side, fs)
		local m = if fs <= count then memberAt(sideState, fs) else nil
		card.Frame.Visible = m ~= nil
		if m then
			card.Title.Text = m.Name
			card.Level.Text = "Nv. " .. m.Level
			card.Type.Face.Label.Text = UI.upper(TypeChart.DisplayName[m.Type] or m.Type or "")
			UI.paint(card.Type, typeColor(m.Type))
			setHp(card, m.Hp, m.MaxHp, instant)
			setStatus(card, m.Status)
			setStages(card, m.Stages, nil, instant)
		else
			setStages(card, nil, nil, instant)
		end
	end
end

local function submit(action)
	if not current or not current.Awaiting then
		return
	end
	current.Awaiting = false
	turnPlan = nil
	replacePlan = nil
	pendingMoveIndex = nil
	showPage(nil)
	SubmitAction:FireServer(current.Id, action)
end

local refreshMoves
local refreshBag
local refreshTeam
local refreshActorPrompt

-- Atualiza cabecalho de qual lutador esta escolhendo no 2x2
function refreshActorPrompt()
	if not current or not current.State then
		return
	end
	local double = isDouble() and turnPlan ~= nil
	mainActorChip.Visible = double
	movesActorChip.Visible = double
	mainStepBack.Visible = double and turnPlan.Step > 1
	if double then
		local fs = currentChoosingSlot()
		local m = memberAt(current.State.Player, fs)
		local name = if m then UI.upper(m.Name) else ("SLOT " .. fs)
		local txt = string.format("%s (%d/%d)", name, turnPlan.Step, #turnPlan.SlotOrder)
		mainActorChip.Face.Label.Text = txt
		movesActorChip.Face.Label.Text = txt
		local col = if fs == 1 then "orange" else "blue"
		UI.paint(mainActorChip, col)
		UI.paint(movesActorChip, col)
	end
	updateCardHighlights()
end

-- Registra a acao escolhida para o slot atual (1x1 envia na hora; 2x2 avanca para o proximo slot ou envia o pacote)
local function commitSlotAction(action)
	if not current or not current.Awaiting then
		return
	end
	if not isDouble() or not turnPlan then
		submit(action)
		return
	end
	local fs = currentChoosingSlot()
	action.FieldSlot = fs
	turnPlan.Actions[fs] = action
	turnPlan.Step += 1
	if turnPlan.Step > #turnPlan.SlotOrder then
		local dense = {}
		for _, slotNum in ipairs(turnPlan.SlotOrder) do
			if turnPlan.Actions[slotNum] then
				table.insert(dense, turnPlan.Actions[slotNum])
			end
		end
		submit({ Kind = "Double", Actions = dense })
		return
	end
	-- Avanca para o 2o lutador
	pendingMoveIndex = nil
	teamMode = "Switch"
	refreshMoves()
	refreshBag()
	refreshTeam()
	refreshActorPrompt()
	local nextM = memberAt(current.State.Player, currentChoosingSlot())
	if nextM then
		log("Agora: o que " .. nextM.Name .. " vai fazer?")
	end
	showPage("Main")
end

-- Conta quantos itens de um tipo ja foram reservados pelo Slot 1 neste turno 2x2
local function reservedItemCount(itemId: string): number
	if not turnPlan then
		return 0
	end
	local n = 0
	local curSlot = currentChoosingSlot()
	for fs, act in pairs(turnPlan.Actions) do
		if fs ~= curSlot and act.Kind == "Item" and act.ItemId == itemId then
			n += 1
		end
	end
	return n
end

-- Verifica se um membro do banco ja foi reservado para troca (ou substituicao) por outro slot
local function isReservedBench(teamIdx: number): boolean
	if teamMode == "Replace" and replacePlan then
		for _, entry in ipairs(replacePlan.Replacements) do
			if entry.Index == teamIdx then
				return true
			end
		end
		return false
	end
	if turnPlan then
		local curSlot = currentChoosingSlot()
		for fs, act in pairs(turnPlan.Actions) do
			if fs ~= curSlot and act.Kind == "Switch" and act.Index == teamIdx then
				return true
			end
		end
	end
	return false
end

function refreshMoves()
	local active = activeOf(current.State.Player, currentChoosingSlot())
	if not active then
		return
	end
	local double = isDouble()
	local singleDomainOnly = active.Moves ~= nil and #active.Moves == 1 and active.Moves[1].DomainExclusive == true
	for i, button in ipairs(moveButtons) do
		local move = active.Moves and active.Moves[i]
		button.Visible = move ~= nil
		if move then
			if singleDomainOnly and i == 1 then
				button.Size = UDim2.fromScale(1.0, 0.58)
				button.Position = UDim2.fromScale(0, 0.21)
			else
				local col, row = (i - 1) % 2, (i - 1) // 2
				button.Size = UDim2.fromScale(0.485, 0.46)
				button.Position = UDim2.fromScale(col * 0.515, row * 0.54)
			end
			local usable = move.Pp > 0
			local btnCol = if not usable then "grey" elseif move.DomainExclusive then "orange" else typeColor(move.Type)
			UI.paint(button, btnCol)
			button:SetAttribute("Disabled", (not usable) or nil)
			local face = button.Face
			face.MoveName.Text = move.Name
			face.TypeChip.Face.Label.Text = UI.upper(move.TypeName or TypeChart.DisplayName[move.Type] or move.Type or "")
			face.Pp.Text = string.format("PP %d/%d", move.Pp, move.MaxPp)
			local scope = face:FindFirstChild("ScopeChip")
			if scope then
				local chipText, chipColor = nil, nil
				local effKind = move.EffectKind
				local prio = move.Priority or 0
				if move.DomainExclusive then
					chipText, chipColor = "DOM\u{cd}NIO", "red"
				elseif effKind == "DomainExpansion" then
					chipText, chipColor = "DOM\u{cd}NIO", "purple"
				elseif effKind == "Protect" or effKind == "WideProtect" then
					chipText, chipColor = "PROT.", "teal"
				elseif move.Target == "EnemySide" or effKind == "Hazard" or effKind == "SideEffect" or effKind == "ClearHazards" then
					chipText, chipColor = "CAMPO", "purple"
				elseif move.Target == "AllAllies" then
					chipText, chipColor = "TIME", "green"
				elseif move.Target == "AllEnemies" or move.Target == "AllOthers" then
					if double then
						chipText, chipColor = "\u{c1}REA", "gold"
					end
				elseif prio > 0 then
					chipText, chipColor = "R\u{c1}PIDO", "teal"
				elseif double and move.Target == "Self" then
					chipText, chipColor = "SI", "blue"
				end
				local showScope = chipText ~= nil
				scope.Visible = showScope
				face.MoveName.Size = UDim2.fromScale(if showScope then 0.65 else 0.9, 0.42)
				if showScope then
					scope.Face.Label.Text = chipText
					UI.paint(scope, chipColor)
				end
			end
		end
	end
end

local function effectivenessBadge(move, _target)
	if move.Category ~= "Damage" then
		return "STATUS", "blue"
	end
	local def = move.Id and Moves.Get(move.Id)
	if def and (def.CritChance or 0) >= 0.15 then
		return "CR\u{cd}TICO+", "gold"
	elseif def and def.Status then
		return "EFEITO", "purple"
	end
	return "ALVO \u{b7} ATQ", "orange"
end

-- Abre seletor de alvo para golpe de alvo unico no 2x2
local function openTargetPicker(moveIdx: number, move)
	pendingMoveIndex = moveIdx
	targetHeaderChip.Face.Label.Text = "ALVO: " .. UI.upper(move.Name)

	local enemyState = current.State.Enemy
	local aliveEnemies = aliveFieldSlots(enemyState)
	local onlyOneEnemy = #aliveEnemies == 1

	for _, fs in ipairs({ 2, 1 }) do
		local btn = targetEnemyBtns[fs]
		local m = memberAt(enemyState, fs)
		local alive = m ~= nil and m.Hp > 0
		btn.Visible = alive
		if alive then
			if onlyOneEnemy then
				btn.Size = UDim2.fromScale(1, 0.62)
				btn.Position = UDim2.fromScale(0, 0)
			else
				btn.Size = UDim2.fromScale(0.485, 0.62)
				btn.Position = UDim2.fromScale(if fs == 2 then 0 else 0.515, 0)
			end
			local face = btn.Face
			face.TargetName.Text = m.Name
			face.TypeChip.Face.Label.Text = UI.upper(TypeChart.DisplayName[m.Type] or m.Type or "")
			UI.paint(face.TypeChip, typeColor(m.Type))
			local ratio = math.clamp(m.Hp / math.max(1, m.MaxHp), 0, 1)
			UI.setBar(face.Hp, ratio, hpColor(ratio), true)
			face.HpText.Text = string.format("%d/%d", m.Hp, m.MaxHp)
			local effText, effColor = effectivenessBadge(move, m)
			face.EffChip.Face.Label.Text = effText
			UI.paint(face.EffChip, effColor)
		end
	end

	-- Opcao secundaria: mirar no aliado (regras oficiais de Pokemon Doubles)
	local mySlot = currentChoosingSlot()
	local otherSlot = if mySlot == 1 then 2 else 1
	local ally = memberAt(current.State.Player, otherSlot)
	if ally and ally.Hp > 0 then
		pendingTargetAllySlot = otherSlot
		targetAllyBtn.Visible = true
		targetAllyLabel.Text = string.format("Atingir aliado: %s (HP %d/%d)", ally.Name, ally.Hp, ally.MaxHp)
	else
		pendingTargetAllySlot = nil
		targetAllyBtn.Visible = false
	end

	showPage("Targets")
end

local ITEM_ICON = { HealHP = "potion", Revive = "heal", CureStatus = "heal", RestorePP = "potion", Capture = "seal" }

function refreshBag()
	for _, b in ipairs(bagItemButtons) do
		b:Destroy()
	end
	table.clear(bagItemButtons)
	for i, item in ipairs(current.State.Bag) do
		local avail = math.max(0, item.Count - reservedItemCount(item.Id))
		local b = UI.button(bagPage, {
			Name = "Item_" .. item.Id, Text = item.Name .. "  x" .. avail, Icon = ITEM_ICON[item.Kind] or "bag",
			Color = if avail > 0 then "green" else "grey", Layout = "row", Role = "Small", LayoutOrder = i, Corner = 0.24,
			OnClick = function()
				if not current or not current.Awaiting or avail <= 0 then
					return
				end
				if item.Kind == "HealHP" or item.Kind == "CureStatus" or item.Kind == "RestorePP" or item.Kind == "Revive" then
					pendingItemId = item.Id
					pendingItemKind = item.Kind
					teamMode = "ItemTarget"
					refreshTeam()
					showPage("Team")
					log("Em quem usar " .. item.Name .. "?")
				else
					commitSlotAction({ Kind = "Item", ItemId = item.Id })
				end
			end,
		})
		b.Size = UDim2.fromScale(1, 1)
		table.insert(bagItemButtons, b)
	end
end

-- Lista do time. Em campo fica marcado; reservado por outro slot fica marcado; desmaiado fica cinza.
function refreshTeam()
	local sideState = current.State.Player
	if teamMode == "Replace" then
		if replacePlan and #replacePlan.PendingSlots > 1 then
			sheetTitle.Text = string.format("Escolha quem entra (%d/%d)", replacePlan.Step, #replacePlan.PendingSlots)
		else
			sheetTitle.Text = "Escolha quem entra"
		end
	elseif teamMode == "ItemTarget" then
		sheetTitle.Text = "Usar em quem?"
	else
		sheetTitle.Text = "Time"
	end
	for i, button in ipairs(memberButtons) do
		local m = sideState.Team[i]
		button.Visible = m ~= nil
		if m then
			local badge = m.Status and STATUS_BADGE[m.Status]
			local onField = isOnField(sideState, i)
			local reserved = isReservedBench(i)
			local usable
			if teamMode == "ItemTarget" then
				usable = itemTargetOk(m)
			else
				usable = m.Hp > 0 and not onField and not reserved
			end
			local color = if m.Hp <= 0 then "grey" elseif onField then "blue" elseif reserved then "orange" else "panelAlt"
			UI.paint(button, color)
			local face = button.Face
			face.MemberName.Text = m.Name
			face.Level.Text = "Nv. " .. m.Level
			local ratio = math.clamp(m.Hp / math.max(1, m.MaxHp), 0, 1)
			UI.setBar(face.Hp, ratio, hpColor(ratio), true)
			local tag = if m.Hp <= 0 then "Desmaiado"
				elseif onField then "Em campo"
				elseif reserved then "Escolhido"
				else string.format("HP %d/%d", m.Hp, m.MaxHp)
			face.Info.Text = tag .. (if badge then "  " .. badge[1] else "")
			button:SetAttribute("Usable", usable or nil)
		end
	end
	local canGoBack = teamMode ~= "Replace" or (replacePlan ~= nil and replacePlan.Step > 1)
	sheetBack.Visible = canGoBack
end

local function refreshAll(instant: boolean?)
	refreshSide("Player", instant)
	refreshSide("Enemy", instant)
	refreshMoves()
	refreshBag()
	refreshTeam()
	refreshActorPrompt()
	UI.setText(fleeButton, if current.State.CanFlee then "FUGIR" else "DESISTIR")
	UI.setIcon(fleeButton.Face.Icon, if current.State.CanFlee then "run" else "flag")
	local noItems = current.State.Mode == "PvP" or current.State.Mode == "Practice"
	UI.setDisabled(bagButton, noItems, "green")
end

-- Numero flutuante sobre o personagem (dano, cura, erro)
local function popNumber(model: Model?, text: string, color: Color3)
	local anchor = model and model.Parent and (model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart"))
	if not anchor then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = anchor
	billboard.Size = UDim2.fromScale(3.2, 1.6)
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Parent = player:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = T.Font
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.Parent = billboard
	local s = Instance.new("UIStroke")
	s.Color = T.Outline
	s.Thickness = 3
	s.Parent = label
	local sc = Instance.new("UIScale")
	sc.Scale = 0.4
	sc.Parent = label
	TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(billboard, TweenInfo.new(1, Enum.EasingStyle.Quad), { StudsOffset = Vector3.new(0, 4.2, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
	TweenService:Create(s, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	Debris:AddItem(billboard, 1.1)
end

--------------------------------------------------------------------
-- Camera e controles
--------------------------------------------------------------------
local controls = nil
task.spawn(function()
	local module = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10)
	if module then
		local ok, result = pcall(require, module)
		if ok and result then
			controls = result:GetControls()
		end
	end
end)

local function setControls(enabled: boolean)
	pcall(function()
		GuiService.TouchControlsEnabled = enabled
	end)
	if controls then
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end
end

local savedFov = nil
local function setBattleCamera(cf: CFrame?)
	local camera = workspace.CurrentCamera
	if cf then
		camera.CameraType = Enum.CameraType.Scriptable
		camera:SetAttribute("BattleBaseCFrame", cf)
		camera:SetAttribute("BattleBaseFov", BATTLE_FOV)
		camera.CFrame = cf
		savedFov = savedFov or camera.FieldOfView
		camera.FieldOfView = BATTLE_FOV
	end
end

local function restoreCamera()
	local camera = workspace.CurrentCamera
	camera:SetAttribute("BattleBaseCFrame", nil)
	camera:SetAttribute("BattleBaseFov", nil)
	camera.CameraType = Enum.CameraType.Custom
	if savedFov then
		camera.FieldOfView = savedFov
		savedFov = nil
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

local savedLighting = nil
local function setInBattle(on: boolean)
	root.Visible = on
	local pg = player:FindFirstChildOfClass("PlayerGui")
	if pg then
		pg:SetAttribute("InBattle", on)
	end
	local lighting = game:GetService("Lighting")
	local atmos = lighting:FindFirstChildOfClass("Atmosphere")
	local bloom = lighting:FindFirstChildOfClass("BloomEffect")
	local sunRays = lighting:FindFirstChildOfClass("SunRaysEffect")
	if on then
		if not savedLighting then
			savedLighting = {
				Brightness = lighting.Brightness,
				Exposure = lighting.ExposureCompensation,
				Atmos = atmos and { Color = atmos.Color, Decay = atmos.Decay, Glare = atmos.Glare, Haze = atmos.Haze } or nil,
				Bloom = bloom and { Enabled = bloom.Enabled, Intensity = bloom.Intensity, Size = bloom.Size, Threshold = bloom.Threshold } or nil,
				SunRays = sunRays and { Enabled = sunRays.Enabled, Intensity = sunRays.Intensity } or nil,
			}
		end
		lighting.Brightness = math.min(savedLighting.Brightness, 0.85)
		lighting.ExposureCompensation = math.min(savedLighting.Exposure, -0.55)
		if atmos then
			atmos.Color = Color3.fromRGB(8, 4, 14)
			atmos.Decay = Color3.fromRGB(14, 8, 22)
			atmos.Glare = 0
			atmos.Haze = 0
		end
		if bloom then
			bloom.Intensity = 0.16
			bloom.Size = 14
			bloom.Threshold = 2.35
		end
		if sunRays then
			sunRays.Enabled = false
		end
	elseif savedLighting then
		lighting.Brightness = savedLighting.Brightness
		lighting.ExposureCompensation = savedLighting.Exposure
		if atmos and savedLighting.Atmos then
			atmos.Color = savedLighting.Atmos.Color
			atmos.Decay = savedLighting.Atmos.Decay
			atmos.Glare = savedLighting.Atmos.Glare
			atmos.Haze = savedLighting.Atmos.Haze
		end
		if bloom and savedLighting.Bloom then
			bloom.Enabled = savedLighting.Bloom.Enabled
			bloom.Intensity = savedLighting.Bloom.Intensity
			bloom.Size = savedLighting.Bloom.Size
			bloom.Threshold = savedLighting.Bloom.Threshold
		end
		if sunRays and savedLighting.SunRays then
			sunRays.Enabled = savedLighting.SunRays.Enabled
			sunRays.Intensity = savedLighting.SunRays.Intensity
		end
		savedLighting = nil
	end
end

local function closeBattle()
	current = nil
	turnPlan = nil
	replacePlan = nil
	pendingMoveIndex = nil
	timerHolder.Visible = false
	setFieldBadges("Player", nil)
	setFieldBadges("Enemy", nil)
	VfxController.Cleanup()
	setInBattle(false)
	resultLabel.Visible = false
	restoreCamera()
	setControls(true)
end

--------------------------------------------------------------------
-- Botoes
--------------------------------------------------------------------
fightButton.Activated:Connect(function()
	if not current or not current.Awaiting then
		return
	end
	local fs = currentChoosingSlot()
	local mustStruggle = if current.State.MustStruggleSlots
		then current.State.MustStruggleSlots[fs] == true
		else current.State.MustStruggle == true
	if mustStruggle then
		commitSlotAction({ Kind = "Move", Index = 0 })
	else
		refreshMoves()
		refreshActorPrompt()
		showPage("Moves")
	end
end)

bagButton.Activated:Connect(function()
	if current and current.Awaiting then
		if current.State.Mode == "PvP" then
			log("Itens desativados no PvP.")
			return
		elseif current.State.Mode == "Practice" then
			log("Itens desativados no Treino.")
			return
		end
		refreshBag()
		showPage("Bag")
	end
end)

teamButton.Activated:Connect(function()
	if current and current.Awaiting then
		teamMode = "Switch"
		refreshTeam()
		showPage("Team")
	end
end)

fleeButton.Activated:Connect(function()
	if not current or not current.Awaiting then
		return
	end
	if not current.State.CanFlee and os.clock() > fleeConfirmUntil then
		fleeConfirmUntil = os.clock() + 4
		log("<font color=\"#ffcc66\">Desistir conta como derrota. Toque de novo para confirmar.</font>")
		return
	end
	fleeConfirmUntil = 0
	submit({ Kind = "Flee" })
end)

mainStepBack.Activated:Connect(function()
	if not current or not current.Awaiting or not turnPlan or turnPlan.Step <= 1 then
		return
	end
	turnPlan.Step -= 1
	local fs = currentChoosingSlot()
	turnPlan.Actions[fs] = nil
	refreshMoves()
	refreshBag()
	refreshTeam()
	refreshActorPrompt()
	local m = memberAt(current.State.Player, fs)
	if m then
		log("Voltou: o que " .. m.Name .. " vai fazer?")
	end
	showPage("Main")
end)

for i, button in ipairs(moveButtons) do
	button.Activated:Connect(function()
		if not current or not current.Awaiting then
			return
		end
		local active = activeOf(current.State.Player, currentChoosingSlot())
		local move = active and active.Moves and active.Moves[i]
		if not move then
			return
		end
		if move.Pp <= 0 then
			log("Esse golpe est\u{e1} sem PP.")
			return
		end
		if isDouble() and (move.Target or "Single") == "Single" then
			local aliveEnemies = aliveFieldSlots(current.State.Enemy)
			local mySlot = currentChoosingSlot()
			local otherSlot = if mySlot == 1 then 2 else 1
			local ally = memberAt(current.State.Player, otherSlot)
			local hasAliveAlly = ally ~= nil and ally.Hp > 0
			if #aliveEnemies == 1 and not hasAliveAlly then
				commitSlotAction({ Kind = "Move", Index = i, TargetSide = "Enemy", TargetSlot = aliveEnemies[1] })
			else
				openTargetPicker(i, move)
			end
			return
		end
		commitSlotAction({ Kind = "Move", Index = i })
	end)
end

for _, fs in ipairs({ 1, 2 }) do
	targetEnemyBtns[fs].Activated:Connect(function()
		if not current or not current.Awaiting or not pendingMoveIndex then
			return
		end
		local m = memberAt(current.State.Enemy, fs)
		if not m or m.Hp <= 0 then
			return
		end
		local moveIdx = pendingMoveIndex
		pendingMoveIndex = nil
		commitSlotAction({ Kind = "Move", Index = moveIdx, TargetSide = "Enemy", TargetSlot = fs })
	end)
end

targetAllyBtn.Activated:Connect(function()
	if not current or not current.Awaiting or not pendingMoveIndex or not pendingTargetAllySlot then
		return
	end
	local moveIdx = pendingMoveIndex
	local allySlot = pendingTargetAllySlot
	pendingMoveIndex = nil
	commitSlotAction({ Kind = "Move", Index = moveIdx, TargetSide = "Ally", TargetSlot = allySlot })
end)

targetBack.Activated:Connect(function()
	if current and current.Awaiting then
		pendingMoveIndex = nil
		showPage("Moves")
	end
end)

for i, button in ipairs(memberButtons) do
	button.Activated:Connect(function()
		if not current or not current.Awaiting then
			return
		end
		local sideState = current.State.Player
		local m = sideState.Team[i]
		if not m then
			return
		end
		if teamMode == "ItemTarget" then
			local ok, why = itemTargetOk(m)
			if ok then
				commitSlotAction({ Kind = "Item", ItemId = pendingItemId, TargetIndex = i })
			else
				log(why)
				UI.play("error")
			end
			return
		end
		if m.Hp <= 0 then
			log(m.Name .. " est\u{e1} desmaiado.")
			UI.play("error")
			return
		end
		if isOnField(sideState, i) then
			log(m.Name .. " j\u{e1} est\u{e1} em campo.")
			return
		end
		if isReservedBench(i) then
			log(m.Name .. " j\u{e1} foi escolhido.")
			UI.play("error")
			return
		end
		if teamMode == "Replace" then
			if isDouble() and replacePlan and #replacePlan.PendingSlots > 0 then
				local fs = replacePlan.PendingSlots[replacePlan.Step]
				table.insert(replacePlan.Replacements, { FieldSlot = fs, Index = i })
				replacePlan.Step += 1
				if replacePlan.Step > #replacePlan.PendingSlots then
					submit({ Kind = "Replace", Replacements = replacePlan.Replacements })
				else
					refreshTeam()
					log("Escolha o pr\u{f3}ximo substituto.")
				end
				return
			end
			submit({ Kind = "Replace", Index = i })
			return
		end
		commitSlotAction({ Kind = "Switch", Index = i })
	end)
end

movesBack.Activated:Connect(function()
	if current and current.Awaiting then
		showPage("Main")
	end
end)

sheetBack.Activated:Connect(function()
	if not current or not current.Awaiting then
		return
	end
	if teamMode == "Replace" then
		if replacePlan and replacePlan.Step > 1 then
			replacePlan.Step -= 1
			table.remove(replacePlan.Replacements)
			refreshTeam()
		end
		return
	end
	teamMode = "Switch"
	showPage("Main")
end)

--------------------------------------------------------------------
-- Remotes
--------------------------------------------------------------------
local function unpackSlotModels(payload)
	local out = { Player = {}, Enemy = {} }
	if payload.SlotModels then
		for _, side in ipairs({ "Player", "Enemy" }) do
			local src = payload.SlotModels[side]
			if src then
				out[side][1] = src.Slot1
				out[side][2] = src.Slot2
			end
		end
	end
	if payload.Models then
		out.Player[1] = out.Player[1] or payload.Models.Player
		out.Enemy[1] = out.Enemy[1] or payload.Models.Enemy
	end
	return out
end

local function beginTurnPrompt()
	local state = current.State
	if isDouble() then
		turnPlan = { SlotOrder = aliveFieldSlots(state.Player), Step = 1, Actions = {} }
	else
		turnPlan = nil
	end
	replacePlan = nil
	pendingMoveIndex = nil
	teamMode = "Switch"
	refreshAll()
	local m = memberAt(state.Player, currentChoosingSlot()) or activeOf(state.Player)
	if m then
		log("O que " .. m.Name .. " vai fazer?")
	end
	showPage("Main")
end

local function beginReplacePrompt()
	local state = current.State
	turnPlan = nil
	pendingMoveIndex = nil
	teamMode = "Replace"
	if isDouble() and state.PendingReplaceSlots and #state.PendingReplaceSlots > 0 then
		replacePlan = { PendingSlots = table.clone(state.PendingReplaceSlots), Step = 1, Replacements = {} }
	else
		replacePlan = nil
	end
	refreshAll()
	if replacePlan and #replacePlan.PendingSlots > 1 then
		log("Dois personagens desmaiaram! Escolha quem entra (" .. #replacePlan.PendingSlots .. ").")
	else
		log("Escolha quem entra agora.")
	end
	showPage("Team")
end

StartBattle.OnClientEvent:Connect(function(battleId, payload)
	current = {
		Id = battleId,
		State = payload.State,
		Models = payload.Models or {},
		SlotModels = unpackSlotModels(payload),
		Awaiting = false,
	}
	turnPlan = nil
	replacePlan = nil
	pendingMoveIndex = nil
	waitingLabel.Text = "..."
	timerHolder.Visible = false
	table.clear(logLines)
	logLabel.Text = ""
	resultLabel.Visible = false
	fleeConfirmUntil = 0
	teamMode = "Switch"
	applyFormatLayout(isDouble())
	refreshAll(true)
	setInBattle(true)
	showPage(nil)
	setControls(false)
	setBattleCamera(payload.Camera)
	for _, slots in pairs(current.SlotModels) do
		for _, m in pairs(slots) do
			preloadModel(m)
		end
	end
end)

-- Atualiza o membro em campo de um lado/slot com os campos do evento
local function patchActive(side: string, fieldSlot: number?, fields)
	local m = memberAt(current.State[side], fieldSlot or 1)
	if not m then
		return
	end
	for k, v in pairs(fields) do
		m[k] = v
	end
end

BattleUpdate.OnClientEvent:Connect(function(battleId, data)
	if not current or current.Id ~= battleId then
		return
	end

	if data.Deadline then
		current.Deadline = data.Deadline
	end
	if data.Waiting then
		current.Awaiting = false
		turnPlan = nil
		replacePlan = nil
		waitingLabel.Text = data.Waiting
		showPage(nil)
		if data.State then
			current.State = data.State
			refreshAll()
		end
		return
	end

	if data.Error then
		log("<font color=\"#ff8080\">" .. data.Error .. "</font>")
		UI.play("error")
		if data.State then
			current.State = data.State
			current.Awaiting = true
			if data.State.State == "WaitingForReplacement" then
				beginReplacePrompt()
			else
				beginTurnPrompt()
			end
		end
		return
	end

	local ev = data.Event
	if ev then
		current.Deadline = nil
		waitingLabel.Text = "..."
		if ev.Text then
			log(ev.Text)
		end
		local side = ev.Side
		local fs = ev.FieldSlot or 1
		local model = side and slotModelFor(side, fs)
		if ev.Kind == "UseMove" then
			local attackerModel = ev.Model or model
			local targetSide = ev.TargetSide or (if side == "Player" then "Enemy" else "Player")
			local targetModel = ev.TargetModel or slotModelFor(targetSide, ev.TargetFieldSlot or 1)
			local targetModels = ev.TargetModels
			if not targetModels and typeof(ev.Targets) == "table" and #ev.Targets > 1 then
				targetModels = {}
				for _, ref in ipairs(ev.Targets) do
					local tm = ref.Side and slotModelFor(ref.Side, ref.FieldSlot or 1)
					if tm then
						table.insert(targetModels, tm)
					end
				end
			end
			VfxController.PlayMove(ev.MoveId, attackerModel, targetModel, targetModels)
		elseif ev.Kind == "Damage" or ev.Kind == "StatusDamage" then
			if ev.Crit then
				VfxController.CritFlash()
			end
			patchActive(side, fs, { Hp = ev.Hp })
			setHp(cardFor(side, fs), ev.Hp, ev.MaxHp)
			popNumber(model, "-" .. ev.Amount, if ev.Kind == "StatusDamage" then Color3.fromRGB(255, 120, 60) elseif ev.Crit then Color3.fromRGB(255, 176, 32) else Color3.new(1, 1, 1))
		elseif ev.Kind == "DomainStart" then
			local sideState = side and current.State[side]
			if sideState then
				sideState.SideEffects = sideState.SideEffects or {}
				sideState.SideEffects.MalevolentShrine = ev.Turns or 2
				setFieldBadges(side, sideState)
			end
		elseif ev.Kind == "DomainSlash" then
			patchActive(side, fs, { Hp = ev.Hp })
			setHp(cardFor(side, fs), ev.Hp, ev.MaxHp)
			popNumber(model, "-" .. ev.Amount, Color3.fromRGB(255, 42, 74))
			local hitModel = ev.Model or model
			if hitModel and not ev.Invocation then
				VfxController.PlayDomainSlash({ hitModel })
			end
		elseif ev.Kind == "DomainEnd" then
			local sideState = side and current.State[side]
			if sideState and sideState.SideEffects then
				sideState.SideEffects.MalevolentShrine = 0
				setFieldBadges(side, sideState)
			end
			VfxController.CloseDomain()
		elseif ev.Kind == "Heal" then
			local m = current.State[side].Team[ev.Slot]
			if m then
				m.Hp = ev.Hp
			end
			if ev.Active then
				local healSlot = ev.FieldSlot or 1
				setHp(cardFor(side, healSlot), ev.Hp, ev.MaxHp)
				popNumber(slotModelFor(side, healSlot), "+" .. ev.Amount, T.Palette.hpHigh)
			end
		elseif ev.Kind == "Miss" then
			local targetSide = ev.TargetSide or (if side == "Player" then "Enemy" else "Player")
			local targetModel = slotModelFor(targetSide, ev.TargetFieldSlot or 1)
			popNumber(targetModel, "Errou", Color3.fromRGB(210, 210, 225))
		elseif ev.Kind == "Passive" then
			local tierCol = if ev.PassiveTier == "Secret"
				then Color3.fromRGB(245, 115, 255)
				elseif ev.PassiveTier == "Unique" then Color3.fromRGB(255, 206, 72)
				else Color3.fromRGB(115, 210, 255)
			local mActor = side and memberAt(current.State[side], fs)
			showPassiveBanner(side, mActor and mActor.Name or "", ev.PassiveName, ev.PassiveTier)
			popNumber(model, ev.PassiveName or "Passiva!", tierCol)
			UI.play("click")
		elseif ev.Kind == "Protected" then
			popNumber(model, "Protegido!", T.Palette.teal)
		elseif ev.Kind == "FieldUpdate" then
			local sideState = side and current.State[side]
			if sideState then
				if ev.Hazards then
					sideState.Hazards = ev.Hazards
				end
				if ev.SideEffects then
					sideState.SideEffects = ev.SideEffects
				end
				setFieldBadges(side, sideState)
			end
		elseif ev.Kind == "Status" then
			patchActive(side, fs, { Status = ev.Status })
			setStatus(cardFor(side, fs), ev.Status)
		elseif ev.Kind == "StatusCured" then
			patchActive(side, fs, { Status = nil })
			setStatus(cardFor(side, fs), nil)
		elseif ev.Kind == "StatStage" then
			local m = memberAt(current.State[side], fs)
			local prev = 0
			if m then
				m.Stages = m.Stages or {}
				prev = m.Stages[ev.Stat] or 0
				m.Stages[ev.Stat] = ev.Stage
				setStages(cardFor(side, fs), m.Stages, ev.Stat, false)
			end
			local popCol = if ev.Stage > prev then T.Palette.hpHigh elseif ev.Stage < prev then T.Palette.hpLow else T.Palette.onDark
			popNumber(model, formatStageText(ev.Stat, ev.Stage), popCol)
		elseif ev.Kind == "Faint" then
			patchActive(side, fs, { Hp = 0, Status = nil, Stages = {}, Fainted = true })
			setStatus(cardFor(side, fs), nil)
			setStages(cardFor(side, fs), nil, nil, true)
			refreshSide(side, true)
		elseif ev.Kind == "ClearSlot" then
			local sideState = current.State[side]
			if sideState.ActiveSlots then
				sideState.ActiveSlots[fs] = 0
			end
			setSlotModel(side, fs, nil)
			refreshSide(side, true)
		elseif ev.Kind == "Switch" then
			local sideState = current.State[side]
			if sideState.ActiveSlots then
				sideState.ActiveSlots[fs] = ev.ToIndex
			end
			if fs == 1 then
				sideState.Active = ev.ToIndex
			end
			if ev.Member then
				local old = sideState.Team[ev.ToIndex]
				if old and old.Moves and not ev.Member.Moves then
					ev.Member.Moves = old.Moves
				end
				sideState.Team[ev.ToIndex] = ev.Member
			end
			if ev.Model then
				setSlotModel(side, fs, ev.Model)
				preloadModel(ev.Model)
			end
			refreshSide(side, true)
		end
	end

	if data.State and (data.Await or data.AwaitReplacement) then
		current.State = data.State
		current.Awaiting = true
		if data.AwaitReplacement then
			beginReplacePrompt()
		else
			beginTurnPrompt()
		end
	end
end)

-- Relogio do turno (PvP)
task.spawn(function()
	while true do
		task.wait(0.2)
		local deadline = current and current.Deadline
		if deadline then
			local left = math.max(0, math.ceil(deadline - workspace:GetServerTimeNow()))
			timerLabel.Text = left .. " s"
			timerLabel.TextColor3 = if left <= 5 then T.Palette.hpLow else Color3.new(1, 1, 1)
			timerHolder.Visible = true
		else
			timerHolder.Visible = false
		end
	end
end)

BattleEnd.OnClientEvent:Connect(function(battleId, data)
	if not current or current.Id ~= battleId then
		return
	end
	current.Awaiting = false
	current.Deadline = nil
	showPage(nil)
	waitingHolder.Visible = false
	if data.Result == "Cancelled" then
		closeBattle()
		return
	end
	local text = if data.Result == "Win" then "VIT\u{d3}RIA!" elseif data.Result == "Lose" then "DERROTA..." else "FIM DA BATALHA"
	if data.Reason == "Disconnect" then
		text ..= if data.Result == "Win" then "\nO advers\u{e1}rio saiu" else "\nVoc\u{ea} saiu da batalha"
	elseif data.Reason == "Forfeit" then
		text ..= if data.Result == "Win" then "\nO advers\u{e1}rio desistiu" else "\nVoc\u{ea} desistiu"
	end
	resultLabel.Text = text
	resultLabel.TextColor3 = if data.Result == "Win" then T.Palette.gold else Color3.fromRGB(230, 230, 240)
	resultLabel.Visible = true
	resultScale.Scale = 0.3
	TweenService:Create(resultScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	UI.play(if data.Result == "Win" then "reward" else "close")
	local id = battleId
	task.delay(3, function()
		if current and current.Id == id then
			closeBattle()
		end
	end)
end)

UI.preloadSounds()
