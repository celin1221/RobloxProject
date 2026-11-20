--[[
	PvPClient (GDD secao 5 - desafio PvP)
	- Perto de outro jogador na praca aparece "Desafiar" (prompt so deste cliente, no outro jogador).
	- Desafio recebido: caixa Aceitar / Recusar com contagem. Desafio enviado: aviso com Cancelar.
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

--------------------------------------------------------------------
-- Caixa de desafio recebido / enviado (centro, acima de tudo)
--------------------------------------------------------------------
local canvas = UI.screen(gui)
gui.DisplayOrder = 12
local box, face = UI.panel(canvas, { Name = "Invite", Size = UDim2.fromScale(0.5, 0.42), Position = UDim2.fromScale(0.6, 0.42), AnchorPoint = Vector2.new(0.5, 0.5), Color = "panel", Corner = 0.1, Aspect = 2.1, Visible = false, ZIndex = 40, MaxSize = Vector2.new(560, 267) })
local boxScale = Instance.new("UIScale")
boxScale.Parent = box
UI.stroke(face, T.Palette.red, 1.3)
UI.icon(box, "sword", { Name = "Icon", Size = UDim2.fromScale(0.2, 0.42), Position = UDim2.fromScale(0.5, 0), AnchorPoint = Vector2.new(0.5, 0.6), ZIndex = 42 })
local title = UI.text(face, "", { Name = "Title", Size = UDim2.fromScale(0.9, 0.26), Position = UDim2.fromScale(0.05, 0.16), Role = "Body", ZIndex = 41 })
local info = UI.text(face, "", { Name = "Info", Size = UDim2.fromScale(0.9, 0.16), Position = UDim2.fromScale(0.05, 0.44), Role = "Small", Color = "inkSoft", StrokeMult = 0.4, ZIndex = 41 })
local accept = UI.button(face, { Name = "Accept", Text = "ACEITAR", Icon = "tick", Layout = "row", Color = "green", Size = UDim2.fromScale(0.42, 0.26), Position = UDim2.fromScale(0.05, 0.66), Role = "Body", ZIndex = 41 })
local decline = UI.button(face, { Name = "Decline", Text = "RECUSAR", Icon = "close", Layout = "row", Color = "red", Size = UDim2.fromScale(0.42, 0.26), Position = UDim2.fromScale(0.53, 0.66), Role = "Body", ZIndex = 41 })

local mode = nil -- "Incoming" | "Sent"
local fromUserId = nil
local expires = 0
local baseInfo = ""

local function close()
	box.Visible = false
	mode = nil
	fromUserId = nil
end

local function open(kind, text, seconds)
	mode = kind
	expires = os.clock() + (seconds or 20)
	title.Text = text
	baseInfo = "N\u{ed}vel 50 \u{b7} 30 s/turno \u{b7} sem itens"
	accept.Visible = kind == "Incoming"
	UI.setText(decline, if kind == "Incoming" then "RECUSAR" else "CANCELAR")
	decline.Position = if kind == "Incoming" then UDim2.fromScale(0.53, 0.66) else UDim2.fromScale(0.29, 0.66)
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
		open("Incoming", data.FromName .. " desafiou voc\u{ea} para um PvP!", data.Seconds)
	elseif data.Kind == "Sent" then
		open("Sent", "Desafio enviado para " .. data.ToName .. ". Aguardando...", data.Seconds)
	elseif data.Kind == "Closed" then
		close()
		toast(data.Text)
	end
end)

-- batalha comecou: a caixa some
UI.onBattle(function(inBattle)
	if inBattle then
		close()
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
	local ok, text = Remotes.PvPChallenge:InvokeServer(prompt:GetAttribute("UserId"))
	if not ok then
		toast(text)
	end
end)
