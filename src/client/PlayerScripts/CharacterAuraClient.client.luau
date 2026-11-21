--!strict
--[[
	CharacterAuraClient (cliente) - anima e gerencia auras de personagens (tag "CharacterAura") estilo Anime Dice:
	  - Gira aneis de chao, fitas 3D helicoidais, orbes orbitais (Satoru Gojo) e halos traseiros (Barba Branca / Gojo)
	    via AuraWeld.C0, preservando escala (ex.: variante Gigante 1.5x) e offset Y.
	  - Pulso organico de brilho na AuraLight, nos aneis do chao e no contorno AnimeOutline3D.
	  - Harmoniza cores com variantes especiais (Ouro, Esmeralda, Rubi, Diamante, ArcoIris).
	  - Respeita a configuracao "Auras dos personagens" (ClientSettings.Current.CharacterAuras / PlayerGui:GetAttribute("CharacterAuras")).
	  - Culling por distancia (MAX_DIST) para manter FPS alto no mapa.
	Totalmente isolado em pcall: cosmeticos nunca podem interromper o gameplay.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local ClientSettings = require(ReplicatedStorage:WaitForChild("ClientSettings"))
ClientSettings.start()

local player = Players.LocalPlayer
local TAG = "CharacterAura"
local MAX_DIST = 190
local PULSE_HZ = 1.15 -- abaixo de 3 Hz (seguro contra fotossensibilidade)

local VARIANT_TINTS: { [string]: { Primary: Color3, Accent: Color3 } } = {
	Prata = { Primary = Color3.fromRGB(220, 232, 248), Accent = Color3.fromRGB(140, 210, 255) },
	Ouro = { Primary = Color3.fromRGB(255, 224, 72), Accent = Color3.fromRGB(255, 246, 175) },
	Esmeralda = { Primary = Color3.fromRGB(64, 242, 138), Accent = Color3.fromRGB(155, 255, 210) },
	Rubi = { Primary = Color3.fromRGB(255, 58, 92), Accent = Color3.fromRGB(255, 168, 96) },
	Diamante = { Primary = Color3.fromRGB(160, 238, 255), Accent = Color3.fromRGB(235, 250, 255) },
}

type Spinner = {
	part: BasePart,
	weld: Weld?,
	speed: number,
	axis: string, -- "Y" | "Z"
	basePos: Vector3,
	baseRot: CFrame,
	bobAmp: number,
	angle: number,
}

type RingGuiEntry = {
	gui: SurfaceGui,
	img: ImageLabel?,
	baseBr: number,
	isOuter: boolean,
}

type AuraEntry = {
	folder: Instance,
	model: Model?,
	root: BasePart?,
	spinners: { Spinner },
	light: PointLight?,
	baseLightBr: number,
	ringGuis: { RingGuiEntry },
	outline: Highlight?,
	fxToggle: { Instance },
	visibleParts: { BasePart },
	culled: boolean,
	seed: number,
	lastVariant: string?,
}

local entries: { [Instance]: AuraEntry } = {}

local function aurasEnabled(): boolean
	local pg = player and player:FindFirstChildOfClass("PlayerGui")
	local attr = pg and pg:GetAttribute("CharacterAuras")
	if attr ~= nil then
		return attr ~= false
	end
	return ClientSettings.Current.CharacterAuras ~= false
end

local function setFxEnabled(entry: AuraEntry, on: boolean)
	if entry.culled == (not on) then
		return
	end
	entry.culled = not on
	for _, d in ipairs(entry.fxToggle) do
		if d.Parent then
			if
				d:IsA("ParticleEmitter")
				or d:IsA("Beam")
				or d:IsA("Trail")
				or d:IsA("PointLight")
				or d:IsA("SurfaceGui")
				or d:IsA("BillboardGui")
			then
				(d :: any).Enabled = on
			end
		end
	end
	for _, p in ipairs(entry.visibleParts) do
		if p.Parent then
			p.LocalTransparencyModifier = if on then 0 else 1
		end
	end
	if entry.outline and entry.outline.Parent then
		entry.outline.Enabled = on
	end
end

local function applyVariantTint(entry: AuraEntry, variant: string?, t: number)
	if not variant or variant == "Brilhante" or variant == "Gigante" then
		return
	end
	local prim: Color3? = nil
	local acc: Color3? = nil
	if variant == "ArcoIris" then
		local h = (t * 0.22 + entry.seed * 0.01) % 1
		prim = Color3.fromHSV(h, 0.78, 1)
		acc = Color3.fromHSV((h + 0.18) % 1, 0.72, 1)
	else
		local v = VARIANT_TINTS[variant]
		if v then
			prim = v.Primary
			acc = v.Accent
		end
	end
	if not prim or not acc then
		return
	end
	if entry.light and entry.light.Parent then
		entry.light.Color = prim
	end
	if entry.outline and entry.outline.Parent then
		entry.outline.OutlineColor = prim
		entry.outline.FillColor = prim
	end
	for _, r in ipairs(entry.ringGuis) do
		if r.img and r.img.Parent then
			r.img.ImageColor3 = if r.isOuter then prim else acc
		end
	end
end

local function register(folder: Instance)
	if entries[folder] or not folder:IsDescendantOf(workspace) then
		return
	end
	local model = folder:FindFirstAncestorOfClass("Model")
	local root = model and (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") :: BasePart?) or nil

	local spinners: { Spinner } = {}
	local ringGuis: { RingGuiEntry } = {}
	local fxToggle: { Instance } = {}
	local visibleParts: { BasePart } = {}
	local light: PointLight? = nil

	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") then
			if d.Transparency < 0.99 then
				table.insert(visibleParts, d)
			end
			local spd = d:GetAttribute("SpinSpeed")
			if typeof(spd) == "number" and spd ~= 0 then
				local weld = d:FindFirstChild("AuraWeld")
				local w = if weld and weld:IsA("Weld") then weld else nil
				local basePos = if w then w.C0.Position else d.Position
				local baseRot = if w then (w.C0 - w.C0.Position) else (d.CFrame - d.CFrame.Position)
				local axisAttr = d:GetAttribute("SpinAxis")
				local bobAttr = d:GetAttribute("BobAmp")
				local bobAmp = if typeof(bobAttr) == "number"
					then bobAttr
					elseif d.Name == "RibbonCarrier" then 0.16
					elseif d.Name == "OrbitOrbsCarrier" then 0.14
					else 0
				table.insert(spinners, {
					part = d,
					weld = w,
					speed = spd,
					axis = if typeof(axisAttr) == "string" then axisAttr else "Y",
					basePos = basePos,
					baseRot = baseRot,
					bobAmp = bobAmp,
					angle = 0,
				})
			end
		elseif d:IsA("PointLight") then
			if not light then
				light = d
			end
			table.insert(fxToggle, d)
		elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("BillboardGui") then
			table.insert(fxToggle, d)
		elseif d:IsA("SurfaceGui") then
			local img = d:FindFirstChildOfClass("ImageLabel")
			table.insert(ringGuis, {
				gui = d,
				img = img,
				baseBr = d.Brightness,
				isOuter = d.Parent ~= nil and (d.Parent.Name:find("Outer") ~= nil or d.Parent.Name == "GroundGlow"),
			})
			table.insert(fxToggle, d)
		end
	end

	-- Tambem inclui eventuais emissores extras de aura no corpo do personagem (ex.: BarbaBranca.UpperTorso.YonkoPresence)
	if model then
		local yonko = model:FindFirstChild("YonkoPresence", true)
		if yonko and yonko:IsA("ParticleEmitter") and not yonko:IsDescendantOf(folder) then
			table.insert(fxToggle, yonko)
		end
	end

	local outline = model and model:FindFirstChild("AnimeOutline3D")
	local entry: AuraEntry = {
		folder = folder,
		model = model,
		root = root,
		spinners = spinners,
		light = light,
		baseLightBr = if light then light.Brightness else 1.6,
		ringGuis = ringGuis,
		outline = if outline and outline:IsA("Highlight") then outline else nil,
		fxToggle = fxToggle,
		visibleParts = visibleParts,
		culled = false,
		seed = math.random() * 100,
		lastVariant = nil,
	}
	entries[folder] = entry

	-- Aplica o estado inicial ja no cadastro (se o jogador entrou com auras desligadas, desliga na hora)
	if not aurasEnabled() then
		setFxEnabled(entry, false)
	end
end

local pendingAncestry: { [Instance]: RBXScriptConnection } = {}

local function unregister(folder: Instance)
	entries[folder] = nil
	local c = pendingAncestry[folder]
	if c then
		c:Disconnect()
		pendingAncestry[folder] = nil
	end
end

local function trackTagged(folder: Instance)
	if entries[folder] then
		return
	end
	if folder:IsDescendantOf(workspace) then
		pcall(register, folder)
		return
	end
	if pendingAncestry[folder] then
		return
	end
	pendingAncestry[folder] = folder.AncestryChanged:Connect(function()
		if folder:IsDescendantOf(workspace) then
			local c = pendingAncestry[folder]
			if c then
				c:Disconnect()
				pendingAncestry[folder] = nil
			end
			pcall(register, folder)
		end
	end)
end

for _, inst in ipairs(CollectionService:GetTagged(TAG)) do
	trackTagged(inst)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(trackTagged)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(unregister)

ClientSettings.Changed:Connect(function()
	local on = aurasEnabled()
	for _, entry in pairs(entries) do
		pcall(setFxEnabled, entry, on)
	end
end)

local elapsed = 0
RunService.RenderStepped:Connect(function(dt: number)
	elapsed += dt
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local globalOn = aurasEnabled()

	for folder, entry in pairs(entries) do
		if not folder.Parent or not folder:IsDescendantOf(workspace) then
			entries[folder] = nil
			continue
		end

		pcall(function()
			if not globalOn then
				setFxEnabled(entry, false)
				return
			end

			local root = entry.root
			if not root or not root.Parent then
				if entry.model and entry.model.Parent then
					root = entry.model.PrimaryPart or (entry.model:FindFirstChild("HumanoidRootPart") :: BasePart?)
					entry.root = root
				end
			end
			if not root or not root.Parent then
				return
			end

			local hidden = entry.model ~= nil and entry.model:GetAttribute("HiddenLocal") == true
			local dist = (root.Position - camPos).Magnitude
			if hidden or dist > MAX_DIST then
				setFxEnabled(entry, false)
				return
			end
			setFxEnabled(entry, true)

			for _, sp in ipairs(entry.spinners) do
				sp.angle = (sp.angle + sp.speed * dt) % (math.pi * 2)
				local bob = if sp.bobAmp > 0 then math.sin(elapsed * 2.1 + entry.seed) * sp.bobAmp else 0
				local spinCF = if sp.axis == "Z" then CFrame.Angles(0, 0, sp.angle) else CFrame.Angles(0, sp.angle, 0)
				local w = sp.weld
				if w and w.Parent and not sp.part.Anchored then
					local pos = sp.basePos
					w.C0 = CFrame.new(pos.X, pos.Y + bob, pos.Z) * sp.baseRot * spinCF
				elseif sp.part.Parent then
					local p = sp.part.Position
					sp.part.CFrame = CFrame.new(p) * sp.baseRot * spinCF
				end
			end

			local pulse = 0.5 + 0.5 * math.sin(elapsed * math.pi * 2 * PULSE_HZ + entry.seed)
			local flicker = 0.5 + 0.5 * math.noise(elapsed * 2.2, entry.seed)
			local energy = 0.65 * pulse + 0.35 * flicker

			if entry.light and entry.light.Parent then
				entry.light.Brightness = entry.baseLightBr * (0.82 + 0.36 * energy)
			end
			for _, r in ipairs(entry.ringGuis) do
				if r.gui.Parent then
					r.gui.Brightness = r.baseBr * (0.86 + 0.28 * energy)
				end
			end
			if entry.outline and entry.outline.Parent then
				entry.outline.OutlineTransparency = 0.36 + 0.16 * (1 - energy)
			end

			local variant = entry.model and entry.model:GetAttribute("Variant")
			if typeof(variant) == "string" then
				if variant == "ArcoIris" or variant ~= entry.lastVariant then
					entry.lastVariant = variant
					applyVariantTint(entry, variant, elapsed)
				end
			end
		end)
	end
end)
