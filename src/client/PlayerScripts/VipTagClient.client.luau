-- Tags no chat: [VIP] (GDD secao 9) e [Top 100 Infinito] da temporada (secao 13).
-- O servidor marca os atributos VIP e SeasonTop no jogador. Tambem mostra o titulo da temporada
-- em cima da cabeca de quem ficou entre os 100 primeiros (so visual, no cliente).
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local function seasonTitle(p: Player)
	local season = p:GetAttribute("SeasonTop")
	local char = p.Character
	local head = char and char:FindFirstChild("Head")
	local old = char and char:FindFirstChild("SeasonTitle")
	if not season or not head then
		if old then
			old:Destroy()
		end
		return
	end
	local bb = old or Instance.new("BillboardGui")
	bb.Name = "SeasonTitle"
	bb.Adornee = head
	bb.Size = UDim2.new(0, 170, 0, 26)
	bb.StudsOffset = Vector3.new(0, 1.8, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 60
	local l = bb:FindFirstChild("Text") or Instance.new("TextLabel")
	l.Name = "Text"
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(200, 160, 255)
	l.TextStrokeTransparency = 0.3
	l.Text = "\u{2605} Top 100 Infinito " .. tostring(season)
	l.Parent = bb
	bb.Parent = char
end

local function watch(p: Player)
	p:GetAttributeChangedSignal("SeasonTop"):Connect(function()
		seasonTitle(p)
	end)
	p.CharacterAdded:Connect(function(char)
		char:WaitForChild("Head", 10)
		seasonTitle(p)
	end)
	if p.Character then
		task.spawn(seasonTitle, p)
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
