--[[
	CharacterPreviews:
	  1. ReplicatedStorage/CharacterPreviews: modelos leves (sem particulas/auras/luzes) para
	     ViewportFrames 2D (barra do time, Equipe, Album, cartas de resultado do Gacha).
	  2. ReplicatedStorage/SummonShowcaseModels: modelos completos para o Palco 3D do Banner de
	     Invocacao, preservando AuraVfx, YonkoPresence, Highlight, armas 3D, Motor6D e Bones,
	     prontos para poses dinamicas e contencao limpa de VFX no cliente.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local CharacterLibrary = require(ServerScriptService:WaitForChild("CharacterLibrary"))
local CharactersData = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("Characters"))

local function sanitizePreview(model: Model, targetName: string): Model
	local c = model:Clone()
	c.Name = targetName
	for _, d in ipairs(c:GetDescendants()) do
		if not d.Parent then
			continue
		end
		if
			d:IsA("LuaSourceContainer")
			or d:IsA("Light")
			or d:IsA("ParticleEmitter")
			or d:IsA("Beam")
			or d:IsA("Trail")
			or d:IsA("Highlight")
			or d:IsA("Sound")
			or d:IsA("Animator")
			or d.ClassName == "Attachment"
			or d:IsA("JointInstance")
			or d:IsA("WeldConstraint")
			or (d:IsA("Folder") and (d.Name == "Animations" or d.Name == "AuraVfx" or d.Name == "VariantPresets"))
		then
			d:Destroy()
		end
	end
	-- Remove partes invisiveis sem malha/osso/decal (exceto Head e HumanoidRootPart usados no enquadramento)
	for _, d in ipairs(c:GetDescendants()) do
		if d.Parent and d:IsA("BasePart") then
			if
				d.Transparency >= 0.99
				and d.Name ~= "Head"
				and d.Name ~= "HumanoidRootPart"
				and not d:FindFirstChildWhichIsA("Bone", true)
				and not d:FindFirstChildWhichIsA("Decal", true)
				and not d:FindFirstChildWhichIsA("Texture", true)
			then
				local hasVisibleChild = false
				for _, sub in ipairs(d:GetDescendants()) do
					if sub:IsA("BasePart") and sub.Transparency < 0.99 then
						hasVisibleChild = true
						break
					end
				end
				if not hasVisibleChild then
					d:Destroy()
					continue
				end
			end
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

local function sanitizeShowcase(model: Model, targetName: string): Model
	local c = model:Clone()
	c.Name = targetName

	-- Remove scripts, sons, animadores e pasta de animacoes (preserva AuraVfx, Beams, Particulas, Highlight, Armas)
	for _, d in ipairs(c:GetDescendants()) do
		if CollectionService:HasTag(d, "CharacterAura") then
			CollectionService:RemoveTag(d, "CharacterAura")
		end
		if
			d:IsA("LuaSourceContainer")
			or d:IsA("Sound")
			or d:IsA("Animator")
			or (d:IsA("Folder") and (d.Name == "Animations" or d.Name == "VariantPresets"))
		then
			d:Destroy()
		end
	end

	local hrp = c:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		c.PrimaryPart = hrp
	end

	-- Verifica conectividade a partir do HumanoidRootPart para garantir que nenhuma peca solta caia
	local reachable: { [BasePart]: boolean } = {}
	if hrp and hrp:IsA("BasePart") then
		local adj: { [BasePart]: { BasePart } } = {}
		local function addEdge(a: BasePart?, b: BasePart?)
			if a and b then
				adj[a] = adj[a] or {}
				adj[b] = adj[b] or {}
				table.insert(adj[a], b)
				table.insert(adj[b], a)
			end
		end
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
				addEdge(d.Part0, d.Part1)
			end
		end
		reachable[hrp] = true
		local queue = { hrp }
		while #queue > 0 do
			local cur = table.remove(queue)
			if cur and adj[cur] then
				for _, nb in ipairs(adj[cur]) do
					if not reachable[nb] then
						reachable[nb] = true
						table.insert(queue, nb)
					end
				end
			end
		end
	end

	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			if hrp and d == hrp then
				d.Anchored = true
			elseif hrp and hrp:IsA("BasePart") then
				if not reachable[d] then
					local wc = Instance.new("WeldConstraint")
					wc.Part0 = hrp
					wc.Part1 = d
					wc.Parent = d
				end
				d.Anchored = false
			else
				d.Anchored = true
			end
		end
	end

	local hum = c:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.PlatformStand = true
		pcall(function()
			hum.EvaluateStateMachine = false
		end)
	end
	return c
end

-- 1. Previews leves para ViewportFrames 2D
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

-- 2. Modelos completos para o Palco 3D do Banner de Invocacao (indexados por CharacterId)
local showcaseFolder = Instance.new("Folder")
showcaseFolder.Name = "SummonShowcaseModels"
for id, def in pairs(CharactersData.List) do
	if not def.Prototype then
		local ok, src = pcall(CharacterLibrary.CloneSource, id)
		if ok and src and src:IsA("Model") then
			local model = sanitizeShowcase(src, id)
			model.Parent = showcaseFolder
			src:Destroy()
		end
	end
end
showcaseFolder.Parent = ReplicatedStorage
