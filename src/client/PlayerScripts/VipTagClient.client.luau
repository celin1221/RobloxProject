-- Tags no chat e titulo acima da cabeca: [VIP], [Lenda PvP] / [Top 100 PvP] e [Top 100 Infinito].
-- O servidor marca os atributos VIP, PvPTitle e SeasonTop no jogador (zero emojis/simbolos Unicode).
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local function updateOverhead(p: Player)
	local pvpTitle = p:GetAttribute("PvPTitle")
	local season = p:GetAttribute("SeasonTop")
	local char = p.Character
	local head = char and char:FindFirstChild("Head")
	local old = char and char:FindFirstChild("SeasonTitle")
	if (not pvpTitle and not season) or not head then
		if old then
			old:Destroy()
		end
		return
	end
	local bb = old or Instance.new("BillboardGui")
	bb.Name = "SeasonTitle"
	bb.Adornee = head
	bb.Size = UDim2.new(0, 190, 0, 26)
	bb.StudsOffset = Vector3.new(0, 1.85, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 60
	local l = bb:FindFirstChild("Text") or Instance.new("TextLabel")
	l.Name = "Text"
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextStrokeTransparency = 0.28
	if typeof(pvpTitle) == "string" and pvpTitle ~= "" then
		l.Text = "[" .. pvpTitle .. "]"
		l.TextColor3 = if pvpTitle == "Lenda PvP" then Color3.fromRGB(255, 214, 72) else Color3.fromRGB(92, 230, 255)
	else
		l.Text = "Top 100 Infinito " .. tostring(season)
		l.TextColor3 = Color3.fromRGB(200, 160, 255)
	end
	l.Parent = bb
	bb.Parent = char
end

local function watch(p: Player)
	p:GetAttributeChangedSignal("SeasonTop"):Connect(function()
		updateOverhead(p)
	end)
	p:GetAttributeChangedSignal("PvPTitle"):Connect(function()
		updateOverhead(p)
	end)
	p.CharacterAdded:Connect(function(char)
		char:WaitForChild("Head", 10)
		updateOverhead(p)
	end)
	if p.Character then
		task.spawn(updateOverhead, p)
	end
end
Players.PlayerAdded:Connect(watch)
for _, p in ipairs(Players:GetPlayers()) do
	watch(p)
end

TextChatService.OnIncomingMessage = function(message: TextChatMessage)
	local source = message.TextSource
	if not source then
		return nil
	end
	local p = Players:GetPlayerByUserId(source.UserId)
	if not p then
		return nil
	end
	local prefix = ""
	if p:GetAttribute("VIP") then
		prefix ..= "<font color=\"#FFCD46\">[VIP]</font> "
	end
	local pvpTitle = p:GetAttribute("PvPTitle")
	if typeof(pvpTitle) == "string" and pvpTitle ~= "" then
		local col = if pvpTitle == "Lenda PvP" then "#FFD84A" else "#5CE6FF"
		prefix ..= string.format("<font color=\"%s\">[%s]</font> ", col, pvpTitle)
	end
	if p:GetAttribute("SeasonTop") then
		prefix ..= "<font color=\"#C8A0FF\">[Top 100 Infinito]</font> "
	end
	if prefix == "" then
		return nil
	end
	local props = Instance.new("TextChatMessageProperties")
	props.PrefixText = prefix .. message.PrefixText
	return props
end
