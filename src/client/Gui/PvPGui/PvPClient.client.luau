--[[
	PvPClient (GDD secao 5 - desafio PvP 1x1 e 2x2)
	- Perto de outro jogador na praca aparece "Desafiar (PvP)" (prompt so deste cliente).
	- Ao acionar, abre a escolha de formato: 2x2 Em Dupla (estilo Pokemon) ou 1x1 Individual.
	- Desafio recebido: caixa Aceitar / Recusar com formato em destaque e contagem.
	- Desafio enviado: aviso com formato e Cancelar.
	O servidor (PvPService) confere praca, distancia, batalha e time; aqui so mostra e pede.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local gui = script.Parent
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UI = require(ReplicatedStorage:WaitForChild("UI"))
local T = UI.Theme

local PLAZA_HALF_X, PLAZA_HALF_Z = 130, 90
local PROMPT_DISTANCE = 12

local function toast(text)
	if text and text ~= "" then
		UI.toast(text)
	end
end

local function formatLabel(fmt: string?): string
	return if fmt == "2x2" then "2x2 EM DUPLA" else "1x1 INDIVIDUAL"
end

local function formatColor(fmt: string?): string
	return if fmt == "2x2" then "orange" else "blue"
end

local canvas = UI.screen(gui)
gui.DisplayOrder = 12

--------------------------------------------------------------------
-- Escolha de formato ao desafiar (2x2 Em Dupla / 1x1 Individual)
--------------------------------------------------------------------
local pickerBox, pickerFace = UI.panel(canvas, {
	Name = "FormatPicker", Size = UDim2.fromScale(0.52, 0.48), Position = UDim2.fromScale(0.5, 0.48),
	AnchorPoint = Vector2.new(0.5, 0.5), Color = "panel", Corner = 0.08, Aspect = 1.9,
	Visible = false, ZIndex = 44, MaxSize = Vector2.new(580, 305),
})
local pickerScale = Instance.new("UIScale")
pickerScale.Parent = pickerBox
UI.stroke(pickerFace, T.Palette.orange, 1.3)
local pickerClose = UI.button(pickerFace, {
	Name = "Close", Icon = "close", Color = "grey",
	Size = UDim2.fromScale(0.11, 0.2), Position = UDim2.fromScale(0.97, 0.06),
	AnchorPoint = Vector2.new(1, 0), Corner = 0.32, ZIndex = 46,
})
local pickerTitle = UI.text(pickerFace, "Desafiar para PvP", {
	Name = "Title", Size = UDim2.fromScale(0.78, 0.19), Position = UDim2.fromScale(0.05, 0.07),
	Role = "Heading", AlignX = Enum.TextXAlignment.Left, ZIndex = 45,
})
local pickerSub = UI.text(pickerFace, "N\u{ed}vel 50 \u{b7} 30 s/turno \u{b7} sem itens", {
	Name = "Sub", Size = UDim2.fromScale(0.84, 0.13), Position = UDim2.fromScale(0.05, 0.26),
	Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.4, ZIndex = 45,
})

local function makeFormatOption(name: string, xScale: number, color: string, titleText: string, descText: string)
	local b, face = UI.button(pickerFace, {
		Name = name, Color = color, Size = UDim2.fromScale(0.43, 0.46),
		Position = UDim2.fromScale(xScale, 0.45), Corner = 0.16, ZIndex = 45,
	})
	UI.text(face, titleText, {
		Name = "Label", Size = UDim2.fromScale(0.9, 0.42), Position = UDim2.fromScale(0.05, 0.12),
		Role = "Heading", ZIndex = 46,
	})
	UI.text(face, descText, {
		Name = "Desc", Size = UDim2.fromScale(0.9, 0.34), Position = UDim2.fromScale(0.05, 0.56),
		Role = "Small", StrokeMult = 0.45, ZIndex = 46,
	})
	return b
end

local btn2x2 = makeFormatOption("Format2x2", 0.05, "orange", "2x2 EM DUPLA", "2 ativos por lado (m\u{ed}n. 2 no time)")
local btn1x1 = makeFormatOption("Format1x1", 0.52, "blue", "1x1 CL\u{c1}SSICO", "Duelo individual 1 contra 1")

local pickTargetId: number? = nil

local function closePicker()
	pickerBox.Visible = false
	pickTargetId = nil
end

local function openPicker(targetUserId: number, targetName: string)
	pickTargetId = targetUserId
	pickerTitle.Text = "Desafiar " .. targetName
	pickerBox.Visible = true
	pickerScale.Scale = T.Motion.OpenFrom
	TweenService:Create(pickerScale, TweenInfo.new(T.Motion.OpenTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	UI.play("open")
end

local function sendChallenge(fmt: string)
	local uid = pickTargetId
	closePicker()
	if not uid then
		return
	end
	local ok, text = Remotes.PvPChallenge:InvokeServer(uid, fmt)
	if not ok then
		toast(text)
	end
end

btn2x2.Activated:Connect(function()
	sendChallenge("2x2")
end)
btn1x1.Activated:Connect(function()
	sendChallenge("1x1")
end)
pickerClose.Activated:Connect(closePicker)

--------------------------------------------------------------------
-- Caixa de desafio recebido / enviado (centro, acima de tudo)
--------------------------------------------------------------------
local box, face = UI.panel(canvas, {
	Name = "Invite", Size = UDim2.fromScale(0.5, 0.44), Position = UDim2.fromScale(0.5, 0.44),
	AnchorPoint = Vector2.new(0.5, 0.5), Color = "panel", Corner = 0.1, Aspect = 2.0,
	Visible = false, ZIndex = 40, MaxSize = Vector2.new(560, 280),
})
local boxScale = Instance.new("UIScale")
boxScale.Parent = box
UI.stroke(face, T.Palette.red, 1.3)
UI.icon(box, "sword", { Name = "Icon", Size = UDim2.fromScale(0.18, 0.36), Position = UDim2.fromScale(0.5, 0), AnchorPoint = Vector2.new(0.5, 0.62), ZIndex = 42 })
local formatChip = UI.chip(face, "1x1 INDIVIDUAL", "blue", {
	Name = "FormatChip", Size = UDim2.fromScale(0.46, 0.17), Position = UDim2.fromScale(0.5, 0.14),
	AnchorPoint = Vector2.new(0.5, 0), ZIndex = 41,
})
local title = UI.text(face, "", { Name = "Title", Size = UDim2.fromScale(0.9, 0.22), Position = UDim2.fromScale(0.05, 0.33), Role = "Body", ZIndex = 41 })
local info = UI.text(face, "", { Name = "Info", Size = UDim2.fromScale(0.9, 0.14), Position = UDim2.fromScale(0.05, 0.54), Role = "Small", Color = "inkSoft", StrokeMult = 0.4, ZIndex = 41 })
local accept = UI.button(face, { Name = "Accept", Text = "ACEITAR", Icon = "tick", Layout = "row", Color = "green", Size = UDim2.fromScale(0.42, 0.24), Position = UDim2.fromScale(0.05, 0.71), Role = "Body", ZIndex = 41 })
local decline = UI.button(face, { Name = "Decline", Text = "RECUSAR", Icon = "close", Layout = "row", Color = "red", Size = UDim2.fromScale(0.42, 0.24), Position = UDim2.fromScale(0.53, 0.71), Role = "Body", ZIndex = 41 })

local mode = nil -- "Incoming" | "Sent"
local fromUserId = nil
local expires = 0
local baseInfo = ""

local function close()
	box.Visible = false
	mode = nil
	fromUserId = nil
end

local function open(kind, text, fmt, seconds)
	closePicker()
	mode = kind
	expires = os.clock() + (seconds or 20)
	title.Text = text
	formatChip.Face.Label.Text = formatLabel(fmt)
	UI.paint(formatChip, formatColor(fmt))
	baseInfo = "N\u{ed}vel 50 \u{b7} 30 s/turno \u{b7} sem itens"
	accept.Visible = kind == "Incoming"
	UI.setText(decline, if kind == "Incoming" then "RECUSAR" else "CANCELAR")
	decline.Position = if kind == "Incoming" then UDim2.fromScale(0.53, 0.71) else UDim2.fromScale(0.29, 0.71)
	box.Visible = true
	boxScale.Scale = T.Motion.OpenFrom
	TweenService:Create(boxScale, TweenInfo.new(T.Motion.OpenTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	UI.play("open")
end

accept.Activated:Connect(function()
	if mode ~= "Incoming" then
		return
	end
	local id = fromUserId
	close()
	local ok, text = Remotes.PvPRespond:InvokeServer(id, true)
	if not ok then
		toast(text)
	end
end)
decline.Activated:Connect(function()
	if mode == "Incoming" then
		local id = fromUserId
		close()
		Remotes.PvPRespond:InvokeServer(id, false)
	elseif mode == "Sent" then
		close()
		Remotes.PvPCancel:InvokeServer()
	end
end)

Remotes:WaitForChild("PvPInvite").OnClientEvent:Connect(function(data)
	if data.Kind == "Incoming" then
		fromUserId = data.FromUserId
		local fmtTag = if data.Format == "2x2" then "PvP 2x2" else "PvP 1x1"
		open("Incoming", data.FromName .. " desafiou voc\u{ea} para um " .. fmtTag .. "!", data.Format, data.Seconds)
	elseif data.Kind == "Sent" then
		local fmtTag = if data.Format == "2x2" then "2x2" else "1x1"
		open("Sent", "Desafio " .. fmtTag .. " enviado para " .. data.ToName .. ". Aguardando...", data.Format, data.Seconds)
	elseif data.Kind == "Closed" then
		close()
		toast(data.Text)
	end
end)

-- batalha comecou: as caixas somem
UI.onBattle(function(inBattle)
	if inBattle then
		close()
		closePicker()
	end
end)

-- contagem
task.spawn(function()
	while true do
		task.wait(0.25)
		if box.Visible then
			local left = math.max(0, math.ceil(expires - os.clock()))
			info.Text = baseInfo .. "  (" .. left .. " s)"
			if left <= 0 then
				close()
			end
		end
	end
end)

--------------------------------------------------------------------
-- "Desafiar" nos outros jogadores (prompt local, so na praca)
--------------------------------------------------------------------
local prompts = {} -- [Player] = ProximityPrompt

local function inPlaza(model: Model?): boolean
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	-- mapa v2: praca = retangulo dentro da esteira (|x| <= 130, |z| <= 90)
	local p = root.Position
	return math.abs(p.X) <= PLAZA_HALF_X and math.abs(p.Z) <= PLAZA_HALF_Z and p.Y < 60
end

local function attach(other: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PvPPrompt"
	prompt.ActionText = "Desafiar (PvP)"
	prompt.ObjectText = other.DisplayName
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt:SetAttribute("UserId", other.UserId)
	prompt:SetAttribute("DisplayName", other.DisplayName)
	prompt.Enabled = false
	prompt.Parent = root
	prompts[other] = prompt
end

local function watch(other: Player)
	if other == player then
		return
	end
	other.CharacterAdded:Connect(function(ch)
		attach(other, ch)
	end)
	if other.Character then
		task.spawn(attach, other, other.Character)
	end
end
for _, p in ipairs(Players:GetPlayers()) do
	watch(p)
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(function(p)
	prompts[p] = nil
	if pickTargetId == p.UserId then
		closePicker()
	end
end)

-- so na praca e fora de batalha
task.spawn(function()
	while true do
		task.wait(0.5)
		local meOk = not UI.inBattle() and inPlaza(player.Character)
		for other, prompt in pairs(prompts) do
			if prompt.Parent then
				prompt.Enabled = meOk and inPlaza(other.Character)
			end
		end
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name ~= "PvPPrompt" then
		return
	end
	local targetId = prompt:GetAttribute("UserId")
	local targetName = prompt:GetAttribute("DisplayName") or prompt.ObjectText or "Jogador"
	if typeof(targetId) == "number" then
		openPicker(targetId, targetName)
	end
end)
