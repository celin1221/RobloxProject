--[[
	MapFxClient (cliente) - animacoes de cenario do mapa
	- Estrelas de invocacao (tag MapStar): flutuam e giram sempre.
	- Esteira (tag Esteira): textura rola no sentido do movimento.
	- Com "Efeitos do mapa" ligado: lanternas piscando (tag Lanterna), carpas nadando (tag Carpa),
	  petalas caindo e vaga-lumes perto da camera (emissores locais com a tag MapFx).
	So visual; nada aqui muda o jogo.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientSettings = require(ReplicatedStorage:WaitForChild("ClientSettings"))
ClientSettings.start()

local player = Players.LocalPlayer
local IMG_PETAL = "rbxassetid://130564513029602"
local IMG_GLOW = "rbxassetid://135255086148920"
local CONVEYOR_SPEED = 25

local function fxOn(): boolean
	-- o atributo do PlayerGui e a fonte unica (ClientSettings.applyMapFx sempre o atualiza)
	local pg = player:FindFirstChildOfClass("PlayerGui")
	local a = pg and pg:GetAttribute("MapFx")
	if a ~= nil then
		return a
	end
	return ClientSettings.Current.MapFx ~= false
end

-- conjuntos vivos (streaming: entram e saem)
local function tracked(tag: string, onAdd)
	local set = {}
	local function add(inst)
		task.spawn(function()
			local v = onAdd and onAdd(inst) or true
			if inst.Parent then
				set[inst] = v
			end
		end)
	end
	for _, inst in ipairs(CollectionService:GetTagged(tag)) do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(inst)
		set[inst] = nil
	end)
	return set
end

-- estrelas: guarda a posicao original de cada peca relativa ao centro
local stars = tracked("MapStar", function(model)
	local parts = {}
	local core = model:WaitForChild("Core", 10)
	if not core then
		return {}
	end
	-- gira em volta do centro de verdade da estrela (atributo gravado na montagem)
	local center = model:GetAttribute("StarCenter") or core.Position
	for _, n in ipairs({ "Core", "Heart" }) do
		local p = model:FindFirstChild(n)
		if p then
			parts[p] = CFrame.new(center):ToObjectSpace(p.CFrame)
		end
	end
	return { Center = center, Parts = parts, Phase = math.random() * 6 }
end)

local belts = tracked("Esteira", function(part)
	local tex = part:FindFirstChild("Esteira")
	return { Tex = tex, Diag = part.Size.X == part.Size.Z }
end)

local lanterns = tracked("Lanterna", function(part)
	local l = part:FindFirstChildOfClass("PointLight")
	return { Light = l, Base = l and l.Brightness or 1, Seed = math.random() * 100 }
end)

local portalSeals = tracked("PortalSeal", function(part)
	return { Base = part.CFrame, Speed = 0.35 }
end)

local koi = tracked("Carpa", function(part)
	return { Center = part.Position, R = part:GetAttribute("Raio") or 5, V = part:GetAttribute("Vel") or 0.4, A = math.random() * 6 }
end)

-- emissores locais que seguem a camera
local holder = Instance.new("Part")
holder.Name = "AmbienteFx"
holder.Anchored = true
holder.CanCollide = false
holder.CanQuery = false
holder.CanTouch = false
holder.Transparency = 1
holder.Size = Vector3.new(110, 1, 110)
holder.Parent = workspace.CurrentCamera

local petals = Instance.new("ParticleEmitter")
petals.Name = "Petalas"
petals.Texture = IMG_PETAL
petals.Rate = 9
petals.Lifetime = NumberRange.new(7, 9)
petals.Speed = NumberRange.new(0.5, 1.5)
petals.EmissionDirection = Enum.NormalId.Bottom
petals.Acceleration = Vector3.new(1.2, -1.6, 0.6)
petals.Drag = 0.6
petals.Size = NumberSequence.new(0.45, 0.35)
petals.Rotation = NumberRange.new(0, 360)
petals.RotSpeed = NumberRange.new(-120, 120)
petals.SpreadAngle = Vector2.new(40, 40)
petals.Color = ColorSequence.new(Color3.fromRGB(255, 205, 225), Color3.fromRGB(255, 170, 205))
petals.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0.1), NumberSequenceKeypoint.new(0.85, 0.1), NumberSequenceKeypoint.new(1, 1) })
petals.Shape = Enum.ParticleEmitterShape.Box
petals.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
petals.Parent = holder

local flies = Instance.new("ParticleEmitter")
flies.Name = "VagaLumes"
flies.Texture = IMG_GLOW
flies.Rate = 4
flies.Lifetime = NumberRange.new(5, 7)
flies.Speed = NumberRange.new(0.3, 1)
flies.SpreadAngle = Vector2.new(180, 180)
flies.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.55), NumberSequenceKeypoint.new(0.8, 0.45), NumberSequenceKeypoint.new(1, 0) })
flies.Color = ColorSequence.new(Color3.fromRGB(230, 255, 140))
flies.LightEmission = 1
flies.Shape = Enum.ParticleEmitterShape.Box
flies.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume

local fliesHolder = holder:Clone()
fliesHolder.Name = "VagaLumesFx"
fliesHolder:ClearAllChildren()
fliesHolder.Size = Vector3.new(70, 6, 70)
fliesHolder.Parent = workspace.CurrentCamera
flies.Parent = fliesHolder
CollectionService:AddTag(petals, "MapFx")
CollectionService:AddTag(flies, "MapFx")

-- dentro do mapa principal (nao nas arenas nem no Refugio); o Refugio tem os proprios efeitos
local function inMainMap(p: Vector3): boolean
	return math.abs(p.X) < 260 and math.abs(p.Z) < 220 and p.Y < 200
end

local t = 0
local flickerAcc = 0
local FLICKER_DIST = 150 -- desempenho: so as lanternas perto da camera piscam

RunService.RenderStepped:Connect(function(dt)
	t += dt
	local cam = workspace.CurrentCamera
	local focus = cam.Focus.Position
	local inside = inMainMap(focus)
	-- desempenho: na arena e no Refugio o mapa nao aparece; nada do mapa e animado
	if not inside then
		petals.Enabled = false
		flies.Enabled = false
		return
	end
	local on = fxOn()
	-- estrelas: giro e flutuacao (sempre)
	for model, s in pairs(stars) do
		if typeof(s) == "table" and s.Parts and model.Parent then
			local c = CFrame.new(s.Center + Vector3.new(0, math.sin(t * 1.6 + s.Phase) * 0.9, 0)) * CFrame.Angles(0, t * 1.2 + s.Phase, 0)
			for p, rel in pairs(s.Parts) do
				if p.Parent then
					p.CFrame = c * rel
				end
			end
		end
	end
	-- selos dos portais de invocacao: giro celestial continuo
	for part, ps in pairs(portalSeals) do
		if typeof(ps) == "table" and part.Parent then
			part.CFrame = ps.Base * CFrame.Angles(0, t * ps.Speed, 0)
		end
	end
	-- esteira: textura acompanha o movimento
	local shift = (t * CONVEYOR_SPEED) % 12
	for _, b in pairs(belts) do
		-- cantos ficam parados (seta na diagonal); retas rolam no sentido do movimento
		if typeof(b) == "table" and b.Tex then
			if b.Diag then
				-- canto: setas na diagonal andam na diagonal (repete a cada 6 studs em U e V)
				local d = (t * CONVEYOR_SPEED / math.sqrt(2)) % 6
				b.Tex.OffsetStudsU = d
				b.Tex.OffsetStudsV = d
			else
				b.Tex.OffsetStudsV = shift
			end
		end
	end
	if on then
		-- carpas em circulo
		for part, k in pairs(koi) do
			if typeof(k) == "table" and part.Parent then
				local a = k.A + t * k.V
				local pos = k.Center + Vector3.new(math.cos(a) * k.R, 0, math.sin(a) * k.R * 0.5)
				local nxt = k.Center + Vector3.new(math.cos(a + 0.1) * k.R, 0, math.sin(a + 0.1) * k.R * 0.5)
				part.CFrame = CFrame.lookAt(pos, nxt) * CFrame.Angles(0, math.sin(t * 6 + k.A) * 0.15, 0)
			end
		end
		-- lanternas: luz tremendo de leve (10 vezes por segundo)
		flickerAcc += dt
		if flickerAcc > 0.1 then
			flickerAcc = 0
			local camPos = cam.CFrame.Position
			for part, l in pairs(lanterns) do
				if typeof(l) == "table" and l.Light and (part.Position - camPos).Magnitude < FLICKER_DIST then
					l.Light.Brightness = l.Base * (0.85 + 0.3 * (math.noise(t * 2.5, l.Seed) + 0.5))
				end
			end
		end
	end
	-- emissores de ambiente seguem a camera, so no mapa principal
	petals.Enabled = on
	flies.Enabled = on
	holder.CFrame = CFrame.new(focus.X, 40, focus.Z)
	fliesHolder.CFrame = CFrame.new(focus.X, 11, focus.Z)
end)
