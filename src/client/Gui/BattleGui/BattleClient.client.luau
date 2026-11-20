--[[
	BattleClient (GDD secoes 5 e 10)
	So mostra a batalha e envia a escolha do jogador. Nenhum calculo acontece aqui.

	Layout no estilo Pokemon (camera da arena em Arenas/Arena01/CameraPoint, FOV 50):
	  - seu personagem grande, de costas, embaixo a esquerda; o adversario de frente, no meio a direita
	  - cartao do adversario no canto de cima a direita; o seu no canto de baixo a esquerda
	  - mensagem do turno no topo a esquerda; comandos (Lutar, Mochila, Time, Fugir) em 2x2 embaixo a direita
	  - golpes no mesmo canto; Time e Mochila abrem um painel no centro (como a tela de time)
	  - analogico e pulo do celular escondidos durante a batalha
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
local VfxController = require(ReplicatedStorage:WaitForChild("VfxController"))
local UI = require(ReplicatedStorage:WaitForChild("UI"))
local T = UI.Theme

local BATTLE_FOV = 50

-- Carrega antes as animacoes do modelo em campo (golpes com marcadores)
local function preloadModel(model)
	local folder = model and model:FindFirstChild("Animations")
	if folder then
		task.spawn(function()
			pcall(ContentProvider.PreloadAsync, ContentProvider, folder:GetChildren())
		end)
	end
end

local STATUS_BADGE = {
	Burn = { "QUE", Color3.fromRGB(255, 110, 40) },
	Poison = { "VEN", Color3.fromRGB(168, 85, 247) },
	Paralysis = { "PAR", Color3.fromRGB(230, 190, 30) },
	Sleep = { "SON", Color3.fromRGB(125, 130, 160) },
	Freeze = { "CON", Color3.fromRGB(80, 190, 240) },
}

local function typeColor(t)
	return T.Types[t] or TypeChart.Color[t] or T.Palette.grey
end

--------------------------------------------------------------------
-- Montagem da tela
--------------------------------------------------------------------
local canvas = UI.screen(gui)
gui.DisplayOrder = 10
local root = UI.frame(canvas, { Name = "Root", Visible = false })

-- Cartao de vida (adversario em cima a direita, jogador embaixo a esquerda)
local function makeCard(name, anchor, position)
	local holder, face = UI.panel(root, {
		Name = name, Size = UDim2.fromScale(0.29, 0.2), Position = position, AnchorPoint = anchor,
		Color = "panel", Corner = T.Corner.Card, Aspect = 2.7, MaxSize = Vector2.new(380, 141),
	})
	local title = UI.text(face, "", { Name = "Title", Size = UDim2.fromScale(0.5, 0.3), Position = UDim2.fromScale(0.05, 0.07), Role = "Heading", AlignX = Enum.TextXAlignment.Left })
	local level = UI.text(face, "", { Name = "Level", Size = UDim2.fromScale(0.2, 0.26), Position = UDim2.fromScale(0.55, 0.09), Role = "Small", Color = "gold", AlignX = Enum.TextXAlignment.Left })
	local typeChip = UI.chip(face, "", "grey", { Name = "Type", Size = UDim2.fromScale(0.22, 0.24), Position = UDim2.fromScale(0.74, 0.09) })
	local status = UI.chip(face, "", "grey", { Name = "Status", Size = UDim2.fromScale(0.16, 0.22), Position = UDim2.fromScale(0.8, 0.7), Visible = false })
	local bar = UI.bar(face, { Name = "Hp", Size = UDim2.fromScale(0.9, 0.17), Position = UDim2.fromScale(0.05, 0.45), FillColor = "hpHigh" })
	local pips = UI.frame(face, { Name = "Pips", Size = UDim2.fromScale(0.42, 0.16), Position = UDim2.fromScale(0.05, 0.74) })
	local pl = Instance.new("UIListLayout")
	pl.FillDirection = Enum.FillDirection.Horizontal
	pl.Padding = UDim.new(0.04, 0)
	pl.VerticalAlignment = Enum.VerticalAlignment.Center
	pl.SortOrder = Enum.SortOrder.LayoutOrder
	pl.Parent = pips
	local hpText = UI.text(face, "", { Name = "HpText", Size = UDim2.fromScale(0.34, 0.24), Position = UDim2.fromScale(0.44, 0.7), Role = "Small", AlignX = Enum.TextXAlignment.Right })
	return { Frame = holder, Title = title, Level = level, Type = typeChip, Status = status, Bar = bar, HpText = hpText, Pips = pips }
end

local enemyCard = makeCard("EnemyCard", Vector2.new(1, 0), UDim2.fromScale(0.985, 0.015))
local playerCard = makeCard("PlayerCard", Vector2.new(0, 1), UDim2.fromScale(0.015, 0.975))

-- Mensagem do turno (topo a esquerda, no ceu)
local logHolder, logFace = UI.panel(root, { Name = "Log", Size = UDim2.fromScale(0.55, 0.15), Position = UDim2.fromScale(0.015, 0.015), Color = "slot", Corner = 0.3, Transparency = 0.1, Shadow = false, MaxSize = Vector2.new(720, 90) })
local logLabel = UI.text(logFace, "", { Name = "Text", Size = UDim2.fromScale(0.94, 0.8), Position = UDim2.fromScale(0.03, 0.1), Role = "Small", AlignX = Enum.TextXAlignment.Left, Rich = true, StrokeMult = 0.5 })

-- Area dos comandos (embaixo a direita)
local menuArea = UI.frame(root, { Name = "MenuArea", Size = UDim2.fromScale(0.32, 0.44), Position = UDim2.fromScale(0.985, 0.93), AnchorPoint = Vector2.new(1, 1), Aspect = 1.75, MaxSize = Vector2.new(480, 275) })
local waitingHolder, waitingFace = UI.panel(menuArea, { Name = "Waiting", Size = UDim2.fromScale(0.7, 0.24), Position = UDim2.fromScale(1, 1), AnchorPoint = Vector2.new(1, 1), Color = "slot", Corner = T.Corner.Pill, Shadow = false })
local waitingLabel = UI.text(waitingFace, "...", { Name = "Text", Size = UDim2.fromScale(0.9, 0.7), Position = UDim2.fromScale(0.05, 0.15), Role = "Body" })

local function page(name)
	return UI.frame(menuArea, { Name = name, Visible = false })
end

local mainPage = page("Main")
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

-- Golpes: grade 2x2 mais larga, no mesmo canto, com Voltar acima
local movesPage = UI.frame(root, { Name = "Moves", Size = UDim2.fromScale(0.4, 0.44), Position = UDim2.fromScale(0.985, 0.93), AnchorPoint = Vector2.new(1, 1), Aspect = 2.3, Visible = false, MaxSize = Vector2.new(640, 280) })
local moveButtons = {}
for i = 1, 4 do
	local col, row = (i - 1) % 2, (i - 1) // 2
	local b, face = UI.button(movesPage, { Name = "Move" .. i, Color = "grey", Size = UDim2.fromScale(0.485, 0.46), Position = UDim2.fromScale(col * 0.515, row * 0.54), Corner = 0.22 })
	UI.text(face, "", { Name = "MoveName", Size = UDim2.fromScale(0.9, 0.42), Position = UDim2.fromScale(0.05, 0.06), Role = "Body", AlignX = Enum.TextXAlignment.Left })
	UI.chip(face, "", "slot", { Name = "TypeChip", Size = UDim2.fromScale(0.42, 0.32), Position = UDim2.fromScale(0.05, 0.58) })
	UI.text(face, "", { Name = "Pp", Size = UDim2.fromScale(0.46, 0.3), Position = UDim2.fromScale(0.5, 0.59), Role = "Small", AlignX = Enum.TextXAlignment.Right })
	moveButtons[i] = b
end
local movesBack = UI.button(movesPage, { Name = "Back", Text = "VOLTAR", Color = "grey", Size = UDim2.fromScale(0.26, 0.22), Position = UDim2.fromScale(1, -0.06), AnchorPoint = Vector2.new(1, 1), Corner = 0.3, Role = "Body" })

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
local current = nil -- { Id, State, Models, Awaiting }
local logLines = {}
local fleeConfirmUntil = 0
local teamMode = "Switch" -- "Switch" | "Replace" | "ItemTarget"
local pendingItemId = nil
local pendingItemKind = nil

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
			if mv.Pp < mv.MaxPp then
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
	menuArea.Visible = name ~= "Moves"
	if name == "Team" or name == "Bag" then
		openSheet(name)
	else
		sheet.Visible = false
	end
	waitingHolder.Visible = name == nil
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

local function activeOf(sideState)
	return sideState.Team[sideState.Active]
end

local function cardFor(side: string)
	return if side == "Player" then playerCard else enemyCard
end

local function setHp(card, hp: number, maxHp: number, instant: boolean?)
	local ratio = math.clamp(hp / maxHp, 0, 1)
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

-- Bolinhas do time: verde = de pe, vermelho = desmaiado
local function setPips(card, sideState)
	UI.clear(card.Pips)
	for i, m in ipairs(sideState.Team) do
		local dot = UI.frame(card.Pips, { Name = "Pip" .. i, Size = UDim2.fromScale(0.13, 1), Color = if m.Hp > 0 then "hpHigh" else "hpLow", Aspect = 1, LayoutOrder = i })
		UI.stroke(dot, nil, 0.6)
	end
end

local function refreshSide(side: string, instant: boolean?)
	local sideState = current.State[side]
	local card = cardFor(side)
	local m = activeOf(sideState)
	card.Title.Text = m.Name
	card.Level.Text = "Nv. " .. m.Level
	card.Type.Face.Label.Text = UI.upper(TypeChart.DisplayName[m.Type] or m.Type or "")
	UI.paint(card.Type, typeColor(m.Type))
	setHp(card, m.Hp, m.MaxHp, instant)
	setStatus(card, m.Status)
	setPips(card, sideState)
end

local function submit(action)
	if not current or not current.Awaiting then
		return
	end
	current.Awaiting = false
	showPage(nil)
	SubmitAction:FireServer(current.Id, action)
end

local function refreshMoves()
	local active = activeOf(current.State.Player)
	for i, button in ipairs(moveButtons) do
		local move = active.Moves and active.Moves[i]
		button.Visible = move ~= nil
		if move then
			local usable = move.Pp > 0
			UI.paint(button, if usable then typeColor(move.Type) else "grey")
			button:SetAttribute("Disabled", (not usable) or nil)
			local face = button.Face
			face.MoveName.Text = move.Name
			face.TypeChip.Face.Label.Text = UI.upper(move.TypeName or TypeChart.DisplayName[move.Type] or move.Type or "")
			face.Pp.Text = string.format("PP %d/%d", move.Pp, move.MaxPp)
		end
	end
end

local refreshTeam -- definida mais abaixo (usada pela mochila para escolher o alvo)

local ITEM_ICON = { HealHP = "potion", Revive = "heal", CureStatus = "heal", RestorePP = "potion", Capture = "seal" }

local function refreshBag()
	for _, b in ipairs(bagItemButtons) do
		b:Destroy()
	end
	table.clear(bagItemButtons)
	for i, item in ipairs(current.State.Bag) do
		local b = UI.button(bagPage, {
			Name = "Item_" .. item.Id, Text = item.Name .. "  x" .. item.Count, Icon = ITEM_ICON[item.Kind] or "bag",
			Color = if item.Count > 0 then "green" else "grey", Layout = "row", Role = "Small", LayoutOrder = i, Corner = 0.24,
			OnClick = function()
				if not current or not current.Awaiting or item.Count <= 0 then
					return
				end
				if item.Kind == "HealHP" or item.Kind == "CureStatus" or item.Kind == "RestorePP" or item.Kind == "Revive" then
					-- escolhe em quem usar
					pendingItemId = item.Id
					pendingItemKind = item.Kind
					teamMode = "ItemTarget"
					refreshTeam()
					showPage("Team")
					log("Em quem usar " .. item.Name .. "?")
				else
					submit({ Kind = "Item", ItemId = item.Id })
				end
			end,
		})
		b.Size = UDim2.fromScale(1, 1)
		table.insert(bagItemButtons, b)
	end
end

-- Lista do time. Em campo fica marcado; desmaiado fica cinza.
function refreshTeam()
	local sideState = current.State.Player
	sheetTitle.Text = if teamMode == "Replace" then "Escolha quem entra" elseif teamMode == "ItemTarget" then "Usar em quem?" else "Time"
	for i, button in ipairs(memberButtons) do
		local m = sideState.Team[i]
		button.Visible = m ~= nil
		if m then
			local badge = m.Status and STATUS_BADGE[m.Status]
			local usable
			if teamMode == "ItemTarget" then
				usable = itemTargetOk(m)
			else
				usable = m.Hp > 0 and i ~= sideState.Active
			end
			local color = if m.Hp <= 0 then "grey" elseif i == sideState.Active then "blue" else "panelAlt"
			UI.paint(button, color)
			local face = button.Face
			face.MemberName.Text = m.Name
			face.Level.Text = "Nv. " .. m.Level
			local ratio = math.clamp(m.Hp / math.max(1, m.MaxHp), 0, 1)
			UI.setBar(face.Hp, ratio, hpColor(ratio), true)
			local tag = if m.Hp <= 0 then "Desmaiado" elseif i == sideState.Active then "Em campo" else string.format("HP %d/%d", m.Hp, m.MaxHp)
			face.Info.Text = tag .. (if badge then "  " .. badge[1] else "")
			button:SetAttribute("Usable", usable or nil)
		end
	end
	sheetBack.Visible = teamMode ~= "Replace"
end

local function refreshAll(instant: boolean?)
	refreshSide("Player", instant)
	refreshSide("Enemy", instant)
	refreshMoves()
	refreshBag()
	refreshTeam()
	UI.setText(fleeButton, if current.State.CanFlee then "FUGIR" else "DESISTIR")
	UI.setIcon(fleeButton.Face.Icon, if current.State.CanFlee then "run" else "flag")
	-- PvP: itens desativados
	local pvp = current.State.Mode == "PvP"
	UI.setDisabled(bagButton, pvp, "green")
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
			-- Reduz Bloom forte e eleva Threshold para luzes/capas claras nao estourarem a tela
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
	timerHolder.Visible = false
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
	if current.State.MustStruggle then
		submit({ Kind = "Move", Index = 0 })
	else
		showPage("Moves")
	end
end)
bagButton.Activated:Connect(function()
	if current and current.Awaiting then
		if current.State.Mode == "PvP" then
			log("Itens desativados no PvP.")
			return
		end
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
	-- Na torre e no PvP fugir conta como derrota: pede um segundo toque
	if not current.State.CanFlee and os.clock() > fleeConfirmUntil then
		fleeConfirmUntil = os.clock() + 4
		log("<font color=\"#ffcc66\">Desistir conta como derrota. Toque de novo para confirmar.</font>")
		return
	end
	fleeConfirmUntil = 0
	submit({ Kind = "Flee" })
end)
for i, button in ipairs(moveButtons) do
	button.Activated:Connect(function()
		local move = current and activeOf(current.State.Player).Moves[i]
		if not move then
			return
		end
		if move.Pp <= 0 then
			log("Esse golpe est\u{e1} sem PP.")
			return
		end
		submit({ Kind = "Move", Index = i })
	end)
end
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
				submit({ Kind = "Item", ItemId = pendingItemId, TargetIndex = i })
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
		if i == sideState.Active then
			log(m.Name .. " j\u{e1} est\u{e1} em campo.")
			return
		end
		submit({ Kind = if teamMode == "Replace" then "Replace" else "Switch", Index = i })
	end)
end
movesBack.Activated:Connect(function()
	if current and current.Awaiting then
		showPage("Main")
	end
end)
sheetBack.Activated:Connect(function()
	if current and current.Awaiting and teamMode ~= "Replace" then
		teamMode = "Switch"
		showPage("Main")
	end
end)

--------------------------------------------------------------------
-- Remotes
--------------------------------------------------------------------
StartBattle.OnClientEvent:Connect(function(battleId, payload)
	current = { Id = battleId, State = payload.State, Models = payload.Models or {}, Awaiting = false }
	waitingLabel.Text = "..."
	timerHolder.Visible = false
	table.clear(logLines)
	logLabel.Text = ""
	resultLabel.Visible = false
	fleeConfirmUntil = 0
	teamMode = "Switch"
	refreshAll(true)
	setInBattle(true)
	showPage(nil)
	setControls(false)
	setBattleCamera(payload.Camera)
	for _, m in pairs(current.Models) do
		preloadModel(m)
	end
end)

-- Atualiza o membro em campo de um lado com os campos do evento
local function patchActive(side: string, fields)
	local m = activeOf(current.State[side])
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
		-- PvP: ja escolheu (ou o outro esta escolhendo); espera o adversario
		current.Awaiting = false
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
			refreshAll()
			current.Awaiting = true
			if data.State.State == "WaitingForReplacement" then
				teamMode = "Replace"
				refreshTeam()
				showPage("Team")
			else
				showPage("Main")
			end
		end
		return
	end

	local ev = data.Event
	if ev then
		-- turno resolvendo: sem relogio
		current.Deadline = nil
		waitingLabel.Text = "..."
		if ev.Text then
			log(ev.Text)
		end
		local side = ev.Side
		local model = side and current.Models[side]
		if ev.Kind == "UseMove" then
			-- animacao e efeito do golpe (so golpes com Anim/Vfx em Data/Moves)
			VfxController.PlayMove(ev.MoveId, model, current.Models[if side == "Player" then "Enemy" else "Player"])
		elseif ev.Kind == "Damage" or ev.Kind == "StatusDamage" then
			if ev.Crit then
				VfxController.CritFlash()
			end
			patchActive(side, { Hp = ev.Hp })
			setHp(cardFor(side), ev.Hp, ev.MaxHp)
			popNumber(model, "-" .. ev.Amount, if ev.Kind == "StatusDamage" then Color3.fromRGB(255, 120, 60) elseif ev.Crit then Color3.fromRGB(255, 176, 32) else Color3.new(1, 1, 1))
		elseif ev.Kind == "Heal" then
			local m = current.State[side].Team[ev.Slot]
			if m then
				m.Hp = ev.Hp
			end
			if ev.Active then
				setHp(cardFor(side), ev.Hp, ev.MaxHp)
				popNumber(model, "+" .. ev.Amount, T.Palette.hpHigh)
			end
		elseif ev.Kind == "Miss" then
			popNumber(current.Models[if side == "Player" then "Enemy" else "Player"], "Errou", Color3.fromRGB(210, 210, 225))
		elseif ev.Kind == "Status" then
			patchActive(side, { Status = ev.Status })
			setStatus(cardFor(side), ev.Status)
		elseif ev.Kind == "StatusCured" then
			patchActive(side, { Status = nil })
			setStatus(cardFor(side), nil)
		elseif ev.Kind == "Faint" then
			patchActive(side, { Hp = 0, Status = nil, Fainted = true })
			setStatus(cardFor(side), nil)
			setPips(cardFor(side), current.State[side])
		elseif ev.Kind == "Switch" then
			local sideState = current.State[side]
			sideState.Active = ev.ToIndex
			if ev.Member then
				local old = sideState.Team[ev.ToIndex]
				if old and old.Moves and not ev.Member.Moves then
					ev.Member.Moves = old.Moves
				end
				sideState.Team[ev.ToIndex] = ev.Member
			end
			if ev.Model then
				current.Models[side] = ev.Model
				preloadModel(ev.Model)
			end
			refreshSide(side, true)
		end
	end

	if data.State and (data.Await or data.AwaitReplacement) then
		current.State = data.State
		refreshAll()
		current.Awaiting = true
		if data.AwaitReplacement then
			teamMode = "Replace"
			refreshTeam()
			log("Escolha quem entra agora.")
			showPage("Team")
		else
			teamMode = "Switch"
			log("O que " .. activeOf(data.State.Player).Name .. " vai fazer?")
			showPage("Main")
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
