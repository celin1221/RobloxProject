--[[
	VariantController (GDD secao 4 - Variantes)
	Muda so a aparencia de um modelo de personagem; nunca golpes. O bonus de atributo
	fica em Data/Characters.VariantBonus e e aplicado pela logica de colecao no servidor.

	Chamar no cliente (Arco-iris anima a cor a cada quadro):
	  VariantController.Apply(modelo, "Brilhante" | "Prata" | "Ouro" | "Esmeralda" | "Rubi" | "Diamante" | "ArcoIris" | "Gigante", idDoPersonagem?)

	Brilhante usa a paleta alternativa salva no modelo (VariantPresets/Brilhante, um SurfaceAppearance).
	As variantes de material trocam cor e material das partes, mantendo a textura das partes
	da lista KeepTextureParts do personagem (rosto e maos).
	Gigante: escala 1,5 no mapa e na base; na arena nao aplicar.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Characters = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("Characters"))

local VariantController = {}

local MATERIALS = {
	Prata = { Color = Color3.fromRGB(205, 210, 220), Material = Enum.Material.Metal, Reflectance = 0.25 },
	Ouro = { Color = Color3.fromRGB(240, 190, 60), Material = Enum.Material.Metal, Reflectance = 0.3, Sparkle = Color3.fromRGB(255, 225, 120) },
	Esmeralda = { Color = Color3.fromRGB(40, 200, 110), Material = Enum.Material.Glass, Reflectance = 0.3, Transparency = 0.05 },
	Rubi = { Color = Color3.fromRGB(215, 30, 60), Material = Enum.Material.Glass, Reflectance = 0.3, Transparency = 0.05 },
	Diamante = { Color = Color3.fromRGB(195, 235, 255), Material = Enum.Material.Glass, Reflectance = 0.4, Transparency = 0.1 },
}

local function bodyParts(model: Model, keep)
	local list = {}
	for _, p in model:GetDescendants() do
		if p:IsA("MeshPart") and p.Name ~= "HumanoidRootPart" and p.Transparency < 1 and not keep[p.Name] then
			table.insert(list, p)
		end
	end
	return list
end

-- Brilhos piscando: Emit em quantidade fixa de tempos em tempos (sem emissor ligado o tempo todo)
local function sparkle(model: Model, color: Color3)
	local torso = model:FindFirstChild("UpperTorso")
	if not torso or torso:FindFirstChild("VariantSparkle") then
		return
	end
	local e = Instance.new("ParticleEmitter")
	e.Name = "VariantSparkle"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Enabled = false
	e.Lifetime = NumberRange.new(0.4, 0.7)
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.45), NumberSequenceKeypoint.new(1, 0) })
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Parent = torso
	task.spawn(function()
		while e.Parent and model.Parent do
			e:Emit(3)
			task.wait(0.6)
		end
	end)
end

function VariantController.Apply(model: Model, variant: string, characterId: string?)
	local def = Characters.Get(characterId or model.Name)
	assert(def, "Personagem desconhecido: " .. tostring(characterId or model.Name))
	if def.Variants and not table.find(def.Variants, variant) then
		warn(def.Name .. " nao tem a variante " .. variant)
		return false
	end
	local keep = {}
	for _, n in def.KeepTextureParts or { "Head", "LeftHand", "RightHand" } do
		keep[n] = true
	end

	if variant == "Brilhante" then
		local preset = model:FindFirstChild("VariantPresets") and model.VariantPresets:FindFirstChild("Brilhante")
		if not preset then
			warn(model.Name .. " sem VariantPresets/Brilhante")
			return false
		end
		for _, p in model:GetDescendants() do
			if p:IsA("MeshPart") and p:FindFirstChildOfClass("SurfaceAppearance") then
				p:FindFirstChildOfClass("SurfaceAppearance"):Destroy()
				preset:Clone().Parent = p
			end
		end
		sparkle(model, (def.ShinyPalette and def.ShinyPalette.Secondary) or Color3.new(1, 1, 0.7))
	elseif MATERIALS[variant] then
		local m = MATERIALS[variant]
		for _, p in bodyParts(model, keep) do
			local sa = p:FindFirstChildOfClass("SurfaceAppearance")
			if sa then
				sa:Destroy()
			end
			p.Material = m.Material
			p.Color = m.Color
			p.Reflectance = m.Reflectance or 0
			p.Transparency = m.Transparency or 0
		end
		sparkle(model, m.Sparkle or m.Color)
	elseif variant == "ArcoIris" then
		local parts = bodyParts(model, keep)
		for _, p in parts do
			local sa = p:FindFirstChildOfClass("SurfaceAppearance")
			if sa then
				sa:Destroy()
			end
			p.Material = Enum.Material.SmoothPlastic
		end
		if RunService:IsClient() then
			local conn
			conn = RunService.RenderStepped:Connect(function()
				if not model.Parent then
					conn:Disconnect()
					return
				end
				local t = os.clock() * 0.25
				for i, p in parts do
					p.Color = Color3.fromHSV((t + i * 0.04) % 1, 0.7, 1)
				end
			end)
		else
			for i, p in parts do
				p.Color = Color3.fromHSV((i * 0.08) % 1, 0.7, 1)
			end
		end
	elseif variant == "Gigante" then
		model:ScaleTo(1.5)
	else
		return false
	end
	model:SetAttribute("Variant", variant)
	return true
end

return VariantController
