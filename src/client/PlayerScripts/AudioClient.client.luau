--[[
	AudioClient (GDD secao 10 - Som)
	- Musica do mapa e da batalha (Data/Audio), em loop, no SoundGroup Musica, com transicao
	  suave ao entrar e sair da batalha (atributo InBattle do PlayerGui, marcado pelo BattleClient).
	- Todo o resto (sons de golpes, interface, mapa) vai para o SoundGroup Efeitos.
	- Aplica as configuracoes salvas (ClientSettings).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local Audio = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("Audio"))
local CS = require(ReplicatedStorage:WaitForChild("ClientSettings"))

local musicGroup = SoundService:WaitForChild("Musica")
local sfxGroup = SoundService:WaitForChild("Efeitos")

CS.start()

-- Faixas
local tracks = {}
for key, def in pairs(Audio.Music) do
	local s = Instance.new("Sound")
	s.Name = "Musica_" .. key
	s.SoundId = "rbxassetid://" .. def.Id
	s.Looped = true
	s.Volume = 0
	s.SoundGroup = musicGroup
	s:SetAttribute("Music", true)
	s.Parent = SoundService
	tracks[key] = { Sound = s, Volume = def.Volume or 0.5 }
end

-- Transicao feita no Heartbeat (anda mesmo se a janela nao estiver desenhando, ao contrario do TweenService)
local current = nil
local fadeConn = nil
local function fadeTo(key: string)
	if current == key then
		return
	end
	current = key
	local start = {}
	for k, t in pairs(tracks) do
		start[k] = t.Sound.Volume
		if k == key and not t.Sound.IsPlaying then
			t.Sound.TimePosition = 0
			t.Sound:Play()
		end
	end
	if fadeConn then
		fadeConn:Disconnect()
	end
	local elapsed = 0
	fadeConn = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local a = math.clamp(elapsed / Audio.Fade, 0, 1)
		local e = 0.5 - 0.5 * math.cos(a * math.pi) -- suave nas pontas
		for k, t in pairs(tracks) do
			local target = if k == key then t.Volume else 0
			t.Sound.Volume = start[k] + (target - start[k]) * e
		end
		if a >= 1 then
			fadeConn:Disconnect()
			fadeConn = nil
			for k, t in pairs(tracks) do
				if k ~= key then
					t.Sound:Stop()
				end
			end
		end
	end)
end

local function update()
	fadeTo(if pg:GetAttribute("InBattle") == true then "Battle" else "Map")
end
pg:GetAttributeChangedSignal("InBattle"):Connect(update)
update()

-- Efeitos: qualquer som sem grupo vai para Efeitos (golpes, interface, cenario)
local function route(inst: Instance)
	if inst:IsA("Sound") and inst.SoundGroup == nil and not inst:GetAttribute("Music") then
		inst.SoundGroup = sfxGroup
	end
end
for _, root in ipairs({ workspace, SoundService, pg, ReplicatedStorage }) do
	for _, d in ipairs(root:GetDescendants()) do
		route(d)
	end
	root.DescendantAdded:Connect(route)
end
player.CharacterAdded:Connect(function(ch)
	for _, d in ipairs(ch:GetDescendants()) do
		route(d)
	end
end)
