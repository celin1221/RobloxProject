--[[
	CharacterPreviews: copia os modelos de ServerStorage/Characters para ReplicatedStorage/CharacterPreviews,
	so para as previas 3D da interface (ViewportFrame na barra do time e na tela de Equipe).
	Sem animacoes, scripts nem luzes; tudo ancorado. A fonte continua sendo ServerStorage/Characters.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local folder = Instance.new("Folder")
folder.Name = "CharacterPreviews"
for _, model in ipairs(ServerStorage:WaitForChild("Characters"):GetChildren()) do
	if model:IsA("Model") then
		local c = model:Clone()
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("LuaSourceContainer") or d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Sound") or (d:IsA("Folder") and d.Name == "Animations") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		local hum = c:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		c.Parent = folder
	end
end
folder.Parent = ReplicatedStorage
