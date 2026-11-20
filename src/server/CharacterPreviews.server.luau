--[[
	CharacterPreviews: copia os modelos de ServerStorage/Characters para ReplicatedStorage/CharacterPreviews,
	so para as previas 3D da interface (ViewportFrame na barra do time, tela de Equipe e destaque do Gacha).
	Tambem gera previas provisorias pelo CharacterLibrary.CloneSource para personagens ainda sem modelo 3D proprio.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local CharacterLibrary = require(ServerScriptService:WaitForChild("CharacterLibrary"))
local CharactersData = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("Characters"))

local function sanitizePreview(model: Model, targetName: string): Model
	local c = model:Clone()
	c.Name = targetName
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
	return c
end

local folder = Instance.new("Folder")
folder.Name = "CharacterPreviews"
local created = {}
for _, model in ipairs(ServerStorage:WaitForChild("Characters"):GetChildren()) do
	if model:IsA("Model") then
		sanitizePreview(model, model.Name).Parent = folder
		created[model.Name] = true
	end
end
for id, def in pairs(CharactersData.List) do
	local modelName = def.ModelName or id
	if not created[modelName] then
		local placeholder = CharacterLibrary.CloneSource(id)
		local preview = sanitizePreview(placeholder, modelName)
		preview.Parent = folder
		placeholder:Destroy()
		created[modelName] = true
	end
end
folder.Parent = ReplicatedStorage
