--!strict
--[[
	ReplicatedStorage/Sukuna/SukunaVFX.luau
	Sistema completo de VFX AAA de Ryomen Sukuna (100% LIVRE DE PRIMITIVOS FEIOS):
	  - PROIBIDO: Cone, Ball, Cylinder ou Wedge de Neon para fogo, flechas, ondas ou explosoes!
	  - Construido exclusivamente com multiplas camadas volumetricas de ParticleEmitter
	    (gradiente termico branco-dourado -> laranja -> vermelho -> fumaca preta, Squash, Drag,
	    VelocityParallel, LightEmission 1 para fogo/cortes e 0 para fumaca densa),
	    Beams esculpidos/curvados, Trails rapidos, PointLight com flicker vivo, Highlight,
	    BloomEffect, BlurEffect e ColorCorrectionEffect (Impact Frames anime).

	Coreografia completa dos 5 golpes:
	  1. Desmantelar
	  2. Clivar
	  3. Fortificacao
	  4. Santuario Malevolente (Ryōiki Tenkai: Fukuma Mizushi)
	  5. Fuga (Flecha de Fogo Termobarica)
]]

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(script.Parent:WaitForChild("Config"))
local Janitor = require(script.Parent:WaitForChild("Janitor"))
local CinematicCamera = require(script.Parent:WaitForChild("CinematicCamera"))
local SoundManager = require(script.Parent:WaitForChild("SoundManager"))
local AnimatorModule = require(script.Parent:WaitForChild("AnimatorModule"))
local MalevolentShrineEnv = require(script.Parent:WaitForChild("MalevolentShrineEnv"))
local FugaVFX = require(script.Parent:WaitForChild("FugaVFX"))

local SukunaVFX = {}

local activeMoveJanitors: { [Janitor.JanitorInstance]: boolean } = {}
local buffAuraByModel: { [Model]: Janitor.JanitorInstance } = {}

local function lowQuality(): boolean
	local ok, lv = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	return ok and lv ~= 0 and lv <= 3
end

local function scaleCount(n: number): number
	return if lowQuality() then math.max(1, math.floor(n * 0.55)) else n
end

local function getContainer(): Folder
	local f = workspace:FindFirstChild(Config.WorkspaceFolderName)
	if f and f:IsA("Folder") then
		return f
	end
	local created = Instance.new("Folder")
	created.Name = Config.WorkspaceFolderName
	created.Parent = workspace
	return created
end

local function rootOf(model: Model?): BasePart?
	if not model then
		return nil
	end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end
	return model.PrimaryPart
end

local function groundYOf(model: Model?): number
	local r = rootOf(model)
	if not r then
		return 0
	end
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	return r.Position.Y - r.Size.Y * 0.5 - (if hum then hum.HipHeight else 2.0)
end

local function rightHandPos(model: Model): Vector3
	local armMesh = model:FindFirstChild("RightArm_Mesh")
	if armMesh and armMesh:IsA("BasePart") then
		return armMesh.CFrame:PointToWorldSpace(Vector3.new(0, -armMesh.Size.Y * 0.44, 0))
	end
	local hand = model:FindFirstChild("RightHand") or model:FindFirstChild("Right Arm")
	if hand and hand:IsA("BasePart") then
		return hand.Position
	end
	local r = rootOf(model)
	return if r then r.CFrame:PointToWorldSpace(Vector3.new(1.2, 0.2, -0.8)) else Vector3.zero
end

local function leftHandPos(model: Model): Vector3
	local armMesh = model:FindFirstChild("LeftArm_Mesh")
	if armMesh and armMesh:IsA("BasePart") then
		return armMesh.CFrame:PointToWorldSpace(Vector3.new(0, -armMesh.Size.Y * 0.44, 0))
	end
	local hand = model:FindFirstChild("LeftHand") or model:FindFirstChild("Left Arm")
	if hand and hand:IsA("BasePart") then
		return hand.Position
	end
	local r = rootOf(model)
	return if r then r.CFrame:PointToWorldSpace(Vector3.new(-1.2, 0.2, -0.8)) else Vector3.zero
end

-- Portador invisivel 100% transparente apenas para Attachments/Emitters/Lights (ZERO geometria visivel!)
local function createInvisibleCarrier(parent: Instance, cf: CFrame, jan: Janitor.JanitorInstance?): Part
	local p = Instance.new("Part")
	p.Name = "SukunaVfxCarrier"
	p.Shape = Enum.PartType.Block
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = cf
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Parent = parent
	if jan then
		jan:Add(p)
	end
	return p
end

local function createFlickerLight(
	carrier: Instance,
	color: Color3,
	baseBrightness: number,
	range: number,
	duration: number,
	jan: Janitor.JanitorInstance
): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = baseBrightness
	light.Range = range
	light.Shadows = false
	light.Parent = carrier
	jan:Add(light)

	local t0 = os.clock()
	jan:Connect(RunService.Heartbeat, function()
		if not light.Parent then
			return
		end
		local elapsed = os.clock() - t0
		local fade = 1 - math.clamp((elapsed - duration * 0.65) / math.max(0.08, duration * 0.35), 0, 1)
		local flicker = 0.84 + 0.32 * math.noise(elapsed * 28, 3.7)
		light.Brightness = math.max(0, baseBrightness * flicker * fade)
	end)
	return light
end

-- Impact Frame estilo anime em preto/branco/carmesim ou branco/laranja/preto + Blur curto
local function playAnimeImpactFrame(
	flashTint: Color3,
	holdSec: number,
	recoverSec: number,
	highHeat: boolean?
)
	if lowQuality() then
		return
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "SukunaImpactFrameCC"
	cc.Saturation = -1.0
	cc.Contrast = if highHeat then 1.35 else 1.05
	cc.Brightness = if highHeat then 0.24 else -0.18
	cc.TintColor = flashTint
	cc.Parent = Lighting
	Debris:AddItem(cc, holdSec + recoverSec + 0.25)

	local blur = Instance.new("BlurEffect")
	blur.Name = "SukunaImpactBlur"
	blur.Size = if highHeat then 14 else 9
	blur.Parent = Lighting
	Debris:AddItem(blur, holdSec + recoverSec + 0.25)

	local bloom: BloomEffect? = nil
	if highHeat then
		local b = Instance.new("BloomEffect")
		b.Name = "SukunaThermobaricBloom"
		b.Intensity = 1.65
		b.Size = 36
		b.Threshold = 0.85
		b.Parent = Lighting
		Debris:AddItem(b, holdSec + recoverSec + 1.1)
		bloom = b
	end

	task.delay(holdSec, function()
		if cc.Parent then
			cc.Saturation = if highHeat then 0.28 else -0.15
			cc.Contrast = 0.35
			cc.Brightness = if highHeat then 0.12 else 0.05
			TweenService:Create(cc, TweenInfo.new(recoverSec, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Saturation = 0,
				Contrast = 0,
				Brightness = 0,
				TintColor = Color3.new(1, 1, 1),
			}):Play()
		end
		if blur.Parent then
			TweenService:Create(blur, TweenInfo.new(recoverSec, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = 0,
			}):Play()
		end
		if bloom and bloom.Parent then
			TweenService:Create(bloom, TweenInfo.new(recoverSec + 0.75, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				Intensity = 0,
				Threshold = 2.5,
			}):Play()
		end
	end)
end

local function newMoveJanitor(totalLifetime: number): Janitor.JanitorInstance
	local jan = Janitor.new()
	activeMoveJanitors[jan] = true
	jan:Add(function()
		activeMoveJanitors[jan] = nil
	end)
	jan:Delay(totalLifetime, function()
		jan:Cleanup()
	end)
	return jan
end

--============================================================================
-- 1. DESMANTELAR (Ataque Padrao 1)
-- Clarao branco-carmesim nos dedos -> 3 laminas arqueadas (Beams ultrafinos + VelocityParallel + poeira no chao)
-- -> corte luminoso em X/diagonal + faiscas carmesim/pretas + micro-hitstop (0.04s)
--============================================================================
function SukunaVFX.PlayDesmantelar(attacker: Model, target: Model, timing: { [string]: number }?)
	local aRoot = rootOf(attacker)
	local tRoot = rootOf(target) or aRoot
	if not aRoot or not tRoot then
		return
	end

	local chargeT = (timing and timing.Charge) or 0.18
	local relT = (timing and timing.Release) or 0.56
	local impT = (timing and timing.Impact) or 0.92
	local lenT = (timing and timing.Length) or 1.44
	local jan = newMoveJanitor(lenT + 0.8)
	local container = getContainer()

	CinematicCamera.PlayDesmantelar(attacker, target, timing)

	-- Fase Charge: clarao branco-carmesim nos dois dedos
	jan:Delay(chargeT, function()
		if not attacker.Parent then
			return
		end
		local fingerPos = rightHandPos(attacker)
		local fingerCarrier = createInvisibleCarrier(container, CFrame.new(fingerPos), jan)
		SoundManager.PlayDesmantelarCharge(fingerCarrier, jan)
		createFlickerLight(fingerCarrier, Config.Colors.CrimsonBright, 3.2, 14, 0.35, jan)

		local glint = Instance.new("ParticleEmitter")
		glint.Texture = Config.Fallbacks.Star
		glint.Color = ColorSequence.new(Config.Colors.SlashWhite, Config.Colors.CrimsonBright)
		glint.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.25, 2.2),
			NumberSequenceKeypoint.new(1, 0),
		})
		glint.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		glint.Lifetime = NumberRange.new(0.18, 0.28)
		glint.Speed = NumberRange.new(0.5, 3)
		glint.SpreadAngle = Vector2.new(180, 180)
		glint.LightEmission = 1
		glint.Rate = 0
		glint.Parent = fingerCarrier
		glint:Emit(scaleCount(14))
	end)

	-- Fase Release: 3 laminas arqueadas de ar cortante voando + poeira rasgada no chao!
	jan:Delay(relT, function()
		if not aRoot.Parent or not tRoot.Parent then
			return
		end
		local startPos = rightHandPos(attacker)
		local endPos = tRoot.Position + Vector3.new(0, 0.65, 0)
		local floorY = groundYOf(attacker) + 0.15
		local travelDur = math.max(0.16, impT - relT)

		local launchCarrier = createInvisibleCarrier(container, CFrame.new(startPos), jan)
		SoundManager.PlayDesmantelarRelease(launchCarrier, jan)
		CinematicCamera.AddTrauma(0.28, 2.6)

		local bladeAngles = { -26, 0, 28 }
		for idx, tiltDeg in ipairs(bladeAngles) do
			local bladeCarrier = createInvisibleCarrier(container, CFrame.lookAt(startPos, endPos) * CFrame.Angles(0, 0, math.rad(tiltDeg)), jan)
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(-2.8, 0, 0)
			a0.Parent = bladeCarrier
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(2.8, 0, 0)
			a1.Parent = bladeCarrier

			local arcBeam = Instance.new("Beam")
			arcBeam.Attachment0 = a0
			arcBeam.Attachment1 = a1
			arcBeam.Texture = Config.ResolveAsset(Config.Assets.SlashBeamTextureId, Config.Fallbacks.Streak)
			arcBeam.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Config.Colors.CrimsonCore),
				ColorSequenceKeypoint.new(0.5, Config.Colors.SlashWhite),
				ColorSequenceKeypoint.new(1, Config.Colors.CrimsonBright),
			})
			arcBeam.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.2, 0.05),
				NumberSequenceKeypoint.new(0.8, 0.05),
				NumberSequenceKeypoint.new(1, 1),
			})
			arcBeam.Width0 = 0.16
			arcBeam.Width1 = 0.55
			arcBeam.CurveSize0 = 2.1
			arcBeam.CurveSize1 = -2.1
			arcBeam.LightEmission = 1
			arcBeam.FaceCamera = false
			arcBeam.Segments = 20
			arcBeam.Parent = bladeCarrier

			local windSparks = Instance.new("ParticleEmitter")
			windSparks.Texture = Config.ResolveAsset(Config.Assets.SlashStreakTextureId, Config.Fallbacks.Streak)
			windSparks.Orientation = Enum.ParticleOrientation.VelocityParallel
			windSparks.Color = ColorSequence.new(Config.Colors.SlashWhite, Config.Colors.CrimsonBright)
			windSparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.04) })
			windSparks.Squash = NumberSequence.new(1.8, 2.8)
			windSparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) })
			windSparks.Lifetime = NumberRange.new(0.12, 0.22)
			windSparks.Rate = if lowQuality() then 35 else 75
			windSparks.Speed = NumberRange.new(10, 24)
			windSparks.SpreadAngle = Vector2.new(35, 12)
			windSparks.Drag = 3.5
			windSparks.LightEmission = 1
			windSparks.Parent = bladeCarrier

			-- Poeira rasgada no chao acompanhando a lamina central
			local dustCarrier: Part? = nil
			if idx == 2 then
				local dc = createInvisibleCarrier(container, CFrame.new(startPos.X, floorY, startPos.Z), jan)
				local groundDust = Instance.new("ParticleEmitter")
				groundDust.Texture = Config.Fallbacks.Smoke
				groundDust.Color = ColorSequence.new(Color3.fromRGB(85, 68, 66), Config.Colors.Obsidian)
				groundDust.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.35),
					NumberSequenceKeypoint.new(1, 1),
				})
				groundDust.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.8),
					NumberSequenceKeypoint.new(1, 3.2),
				})
				groundDust.Lifetime = NumberRange.new(0.28, 0.48)
				groundDust.Rate = if lowQuality() then 30 else 65
				groundDust.Speed = NumberRange.new(4, 14)
				groundDust.SpreadAngle = Vector2.new(110, 25)
				groundDust.Drag = 2.8
				groundDust.LightEmission = 0
				groundDust.Parent = dc
				dustCarrier = dc
			end

			local t0 = os.clock()
			local conn: RBXScriptConnection? = nil
			conn = jan:Connect(RunService.Heartbeat, function()
				local a = math.clamp((os.clock() - t0) / travelDur, 0, 1)
				local curTarget = if tRoot.Parent then (tRoot.Position + Vector3.new(0, 0.65, 0)) else endPos
				local lateral = (idx - 2) * 0.75 * math.sin(a * math.pi)
				local pos = startPos:Lerp(curTarget, a) + Vector3.new(0, lateral * 0.4, 0)
				bladeCarrier.CFrame = CFrame.lookAt(pos, curTarget + (curTarget - startPos).Unit * 2) * CFrame.Angles(0, 0, math.rad(tiltDeg))
				if dustCarrier then
					dustCarrier.CFrame = CFrame.new(pos.X, floorY, pos.Z)
				end
				if a >= 1 then
					arcBeam.Enabled = false
					windSparks.Enabled = false
					if dustCarrier then
						for _, ch in ipairs(dustCarrier:GetChildren()) do
							if ch:IsA("ParticleEmitter") then
								ch.Enabled = false
							end
						end
					end
					if conn and conn.Connected then
						conn:Disconnect()
					end
				end
			end)
		end
	end)

	-- Fase Impact: corte luminoso em X/diagonal + faiscas carmesim/pretas + micro-hitstop (0.04s)
	jan:Delay(impT, function()
		if not tRoot.Parent then
			return
		end
		local hitPos = tRoot.Position + Vector3.new(0, 0.65, 0)
		local hitCarrier = createInvisibleCarrier(container, CFrame.new(hitPos), jan)

		AnimatorModule.Hitstop(attacker, 0.04)
		SoundManager.PlayDesmantelarImpact(hitCarrier, jan)
		CinematicCamera.AddTrauma(0.62, 2.5)
		CinematicCamera.FovPunch(-5.0)
		createFlickerLight(hitCarrier, Config.Colors.CrimsonBright, 3.8, 22, 0.38, jan)

		-- Corte em X/diagonal com 3 Beams afiados
		MalevolentShrineEnv.SpawnAirSlash3D(container, hitPos, 10.5, 0.85, 0.28, true, 1.4)
		MalevolentShrineEnv.SpawnAirSlash3D(container, hitPos, 9.8, 0.72, 0.28, false, -1.4)
		jan:Delay(0.035, function()
			MalevolentShrineEnv.SpawnAirSlash3D(container, hitPos, 11.2, 0.65, 0.26, true, 0.5)
		end)

		-- Explosao de faiscas carmesim e fumaca preta
		local darkSmoke = Instance.new("ParticleEmitter")
		darkSmoke.Texture = Config.Fallbacks.Smoke
		darkSmoke.Color = ColorSequence.new(Config.Colors.Obsidian, Config.Colors.BloodDeep)
		darkSmoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 1) })
		darkSmoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3.8) })
		darkSmoke.Lifetime = NumberRange.new(0.28, 0.52)
		darkSmoke.Speed = NumberRange.new(6, 18)
		darkSmoke.SpreadAngle = Vector2.new(180, 180)
		darkSmoke.Drag = 3.2
		darkSmoke.LightEmission = 0
		darkSmoke.Rate = 0
		darkSmoke.Parent = hitCarrier
		darkSmoke:Emit(scaleCount(22))
	end)
end

--============================================================================
-- 2. CLIVAR (Ataque Padrao 2)
-- Teia geometrica de linhas de corte (Beams carmesim e brancos pulsando) envolvendo o corpo do alvo
-- -> explosao caotica de 16 cortes simultaneos + faiscas + nevoa sanguinea + mini Impact Frame (0.05s)
--============================================================================
function SukunaVFX.PlayClivar(attacker: Model, target: Model, timing: { [string]: number }?)
	local aRoot = rootOf(attacker)
	local tRoot = rootOf(target) or aRoot
	if not aRoot or not tRoot then
		return
	end

	local relT = (timing and timing.Release) or 0.64
	local impT = (timing and timing.Impact) or 1.06
	local lenT = (timing and timing.Length) or 1.62
	local jan = newMoveJanitor(lenT + 0.9)
	local container = getContainer()

	CinematicCamera.PlayClivar(attacker, target, timing)

	-- Toque da palma e formacao da teia geometrica envolvendo o tronco do alvo!
	jan:Delay(0.52, function()
		if not tRoot.Parent then
			return
		end
		local center = tRoot.Position + Vector3.new(0, 0.45, 0)
		local webCarrier = createInvisibleCarrier(container, CFrame.new(center), jan)
		SoundManager.PlayClivarPalmAndWeb(webCarrier, jan)
		CinematicCamera.AddTrauma(0.38, 2.2)
		createFlickerLight(webCarrier, Config.Colors.CrimsonBright, 3.2, 18, impT - 0.45, jan)

		-- Constroi gaiola/teia geometrica icosaedrica de 14 Beams finos pulsando ao redor do alvo
		local nodes: { Attachment } = {}
		local r = 2.65
		local coords = {
			Vector3.new(r, 1.8, 0),
			Vector3.new(-r, 1.8, 0),
			Vector3.new(0, 1.8, r),
			Vector3.new(0, 1.8, -r),
			Vector3.new(r * 0.85, 0, r * 0.85),
			Vector3.new(-r * 0.85, 0, r * 0.85),
			Vector3.new(-r * 0.85, 0, -r * 0.85),
			Vector3.new(r * 0.85, 0, -r * 0.85),
			Vector3.new(r * 0.6, -1.8, 0),
			Vector3.new(-r * 0.6, -1.8, 0),
		}
		for _, pos in ipairs(coords) do
			local att = Instance.new("Attachment")
			att.Position = pos
			att.Parent = webCarrier
			table.insert(nodes, att)
		end

		local edges = {
			{ 1, 3 }, { 3, 2 }, { 2, 4 }, { 4, 1 },
			{ 5, 6 }, { 6, 7 }, { 7, 8 }, { 8, 5 },
			{ 1, 6 }, { 2, 8 }, { 3, 7 }, { 4, 5 },
			{ 5, 10 }, { 6, 9 }, { 7, 9 }, { 8, 10 },
		}
		local webBeams: { Beam } = {}
		for idx, pair in ipairs(edges) do
			local b = Instance.new("Beam")
			b.Attachment0 = nodes[pair[1]]
			b.Attachment1 = nodes[pair[2]]
			b.Color = ColorSequence.new(if idx % 2 == 0 then Config.Colors.SlashWhite else Config.Colors.CrimsonBright)
			b.Width0 = 0.09
			b.Width1 = 0.09
			b.LightEmission = 1
			b.LightInfluence = 0
			b.FaceCamera = true
			b.Parent = webCarrier
			table.insert(webBeams, b)
		end

		local t0 = os.clock()
		local webDur = math.max(0.18, impT - 0.52)
		local conn: RBXScriptConnection? = nil
		conn = jan:Connect(RunService.Heartbeat, function()
			local elapsed = os.clock() - t0
			if tRoot.Parent then
				webCarrier.CFrame = CFrame.new(tRoot.Position + Vector3.new(0, 0.45, 0))
					* CFrame.Angles(0, elapsed * 1.8, math.sin(elapsed * 14) * 0.08)
			end
			local pulse = 0.07 + math.abs(math.sin(elapsed * 32)) * 0.14
			for _, b in ipairs(webBeams) do
				b.Width0 = pulse
				b.Width1 = pulse
			end
			if elapsed >= webDur then
				for _, b in ipairs(webBeams) do
					b.Enabled = false
				end
				if conn and conn.Connected then
					conn:Disconnect()
				end
			end
		end)
	end)

	-- Fase Impact: Explosao caotica de 16 cortes simultaneos/escalonados + nevoa sanguinea + mini Impact Frame (0.05s)!
	jan:Delay(impT, function()
		if not tRoot.Parent then
			return
		end
		local hitPos = tRoot.Position + Vector3.new(0, 0.55, 0)
		local hitCarrier = createInvisibleCarrier(container, CFrame.new(hitPos), jan)

		AnimatorModule.Hitstop(attacker, 0.05)
		playAnimeImpactFrame(Color3.fromRGB(255, 148, 168), 0.05, 0.22, false)
		SoundManager.PlayClivarFlurry(hitCarrier, 16, 0.024, jan)
		CinematicCamera.AddTrauma(0.92, 2.2)
		CinematicCamera.FovPunch(-7.0)
		createFlickerLight(hitCarrier, Config.Colors.CrimsonBright, 4.0, 26, 0.52, jan)

		for i = 1, 16 do
			jan:Delay((i - 1) * 0.018, function()
				local curPos = if tRoot.Parent then (tRoot.Position + Vector3.new(0, 0.55, 0)) else hitPos
				local off = Vector3.new(
					(math.random() - 0.5) * 3.8,
					(math.random() - 0.5) * 3.8,
					(math.random() - 0.5) * 3.8
				)
				MalevolentShrineEnv.SpawnAirSlash3D(
					container,
					curPos + off,
					9.5 + math.random() * 5.0,
					0.62 + math.random() * 0.42,
					0.26,
					i % 3 ~= 0
				)
			end)
		end

		-- Nevoa sanguinea densa + faiscas de energia amaldicoada
		local bloodMist = Instance.new("ParticleEmitter")
		bloodMist.Texture = Config.ResolveAsset(Config.Assets.BloodMistTextureId, Config.Fallbacks.Smoke)
		bloodMist.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Config.Colors.CrimsonBright),
			ColorSequenceKeypoint.new(0.5, Config.Colors.BloodDeep),
			ColorSequenceKeypoint.new(1, Config.Colors.Obsidian),
		})
		bloodMist.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.55, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		})
		bloodMist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 5.6) })
		bloodMist.Lifetime = NumberRange.new(0.38, 0.72)
		bloodMist.Speed = NumberRange.new(7, 22)
		bloodMist.SpreadAngle = Vector2.new(180, 180)
		bloodMist.Drag = 3.0
		bloodMist.LightEmission = 0.15
		bloodMist.Rate = 0
		bloodMist.Parent = hitCarrier
		bloodMist:Emit(scaleCount(34))
	end)
end

--============================================================================
-- 3. FORTIFICACAO (Habilidade 3)
-- Onda radial de poeira/faiscas no chao + espirais negras/carmesim (ParticleEmitter + Beams helicoidais)
-- + Highlight carmesim pulsando + aura sutil persistente enquanto o buff estiver ativo!
--============================================================================
local function attachPersistentBuffAura(attacker: Model)
	local prev = buffAuraByModel[attacker]
	if prev then
		prev:Cleanup()
		buffAuraByModel[attacker] = nil
	end
	local hrp = rootOf(attacker)
	if not hrp then
		return
	end
	local auraJan = Janitor.new()
	buffAuraByModel[attacker] = auraJan
	auraJan:Add(function()
		if buffAuraByModel[attacker] == auraJan then
			buffAuraByModel[attacker] = nil
		end
	end)

	local att = Instance.new("Attachment")
	att.Name = "SukunaFortifyAuraAtt"
	att.Parent = hrp
	auraJan:Add(att)

	local wisps = Instance.new("ParticleEmitter")
	wisps.Name = "FortifyCursedWisps"
	wisps.Texture = Config.Fallbacks.Flame
	wisps.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Config.Colors.CrimsonBright),
		ColorSequenceKeypoint.new(0.6, Config.Colors.BloodDeep),
		ColorSequenceKeypoint.new(1, Config.Colors.Obsidian),
	})
	wisps.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.72),
		NumberSequenceKeypoint.new(0.45, 0.48),
		NumberSequenceKeypoint.new(1, 1),
	})
	wisps.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.65),
		NumberSequenceKeypoint.new(1, 0.12),
	})
	wisps.Lifetime = NumberRange.new(0.55, 0.95)
	wisps.Rate = if lowQuality() then 8 else 16
	wisps.Speed = NumberRange.new(2.5, 5.5)
	wisps.SpreadAngle = Vector2.new(180, 35)
	wisps.Acceleration = Vector3.new(0, 6, 0)
	wisps.LightEmission = 0.75
	wisps.Parent = att

	auraJan:Connect(attacker.AncestryChanged, function(_, parent)
		if not parent then
			auraJan:Cleanup()
		end
	end)
end

function SukunaVFX.PlayFortificacao(attacker: Model, timing: { [string]: number }?)
	local aRoot = rootOf(attacker)
	if not aRoot then
		return
	end

	local chargeT = (timing and timing.Charge) or 0.16
	local relT = (timing and timing.Release) or 0.56
	local lenT = (timing and timing.Length) or 1.28
	local jan = newMoveJanitor(lenT + 0.8)
	local container = getContainer()

	CinematicCamera.PlayFortificacao(attacker, timing)

	jan:Delay(chargeT, function()
		if not aRoot.Parent then
			return
		end
		local floorPos = Vector3.new(aRoot.Position.X, groundYOf(attacker) + 0.15, aRoot.Position.Z)
		local baseCarrier = createInvisibleCarrier(container, CFrame.new(floorPos), jan)
		SoundManager.PlayFortificacaoCharge(baseCarrier, jan)

		-- 2 espirais helicoidais (carmesim + obsidiana) subindo pelo corpo com Beams + Trails + particulas!
		local orbiters: { Part } = {}
		for i = 1, 2 do
			local orb = createInvisibleCarrier(container, CFrame.new(floorPos), jan)
			local t0Att = Instance.new("Attachment")
			t0Att.Position = Vector3.new(0, -0.35, 0)
			t0Att.Parent = orb
			local t1Att = Instance.new("Attachment")
			t1Att.Position = Vector3.new(0, 0.35, 0)
			t1Att.Parent = orb

			local tr = Instance.new("Trail")
			tr.Attachment0 = t0Att
			tr.Attachment1 = t1Att
			tr.Texture = Config.Fallbacks.Trail
			tr.Color = ColorSequence.new(
				if i == 1 then Config.Colors.SlashWhite else Config.Colors.CrimsonCore,
				if i == 1 then Config.Colors.CrimsonBright else Config.Colors.Obsidian
			)
			tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.08), NumberSequenceKeypoint.new(1, 1) })
			tr.Lifetime = 0.32
			tr.LightEmission = if i == 1 then 1 else 0.25
			tr.FaceCamera = true
			tr.Parent = orb

			local sp = Instance.new("ParticleEmitter")
			sp.Texture = Config.Fallbacks.Flame
			sp.Color = ColorSequence.new(Config.Colors.CrimsonBright, Config.Colors.Obsidian)
			sp.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
			sp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(1, 0.1) })
			sp.Lifetime = NumberRange.new(0.25, 0.45)
			sp.Rate = if lowQuality() then 28 else 55
			sp.Speed = NumberRange.new(1, 4)
			sp.LightEmission = if i == 1 then 0.9 else 0.1
			sp.Parent = orb

			table.insert(orbiters, orb)
		end

		-- Beam helicoidal conectando os dois orbiters
		local bAtt0 = orbiters[1]:FindFirstChildOfClass("Attachment")
		local bAtt1 = orbiters[2]:FindFirstChildOfClass("Attachment")
		if bAtt0 and bAtt1 then
			local spiralBeam = Instance.new("Beam")
			spiralBeam.Attachment0 = bAtt0
			spiralBeam.Attachment1 = bAtt1
			spiralBeam.Texture = Config.Fallbacks.Streak
			spiralBeam.Color = ColorSequence.new(Config.Colors.CrimsonBright, Config.Colors.Obsidian)
			spiralBeam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.4) })
			spiralBeam.Width0 = 0.45
			spiralBeam.Width1 = 0.45
			spiralBeam.CurveSize0 = 2.6
			spiralBeam.CurveSize1 = -2.6
			spiralBeam.LightEmission = 0.85
			spiralBeam.FaceCamera = true
			spiralBeam.Parent = baseCarrier
		end

		local t0 = os.clock()
		local spiralDur = 0.85
		jan:Connect(RunService.Heartbeat, function()
			if not aRoot.Parent then
				return
			end
			local el = os.clock() - t0
			local a = math.clamp(el / spiralDur, 0, 1)
			local r = 2.4 + math.sin(a * math.pi) * 1.1
			local gy = groundYOf(attacker) + 0.2 + a * 5.8
			for i, orb in ipairs(orbiters) do
				local ang = el * 14.0 + (i - 1) * math.pi
				orb.CFrame = CFrame.new(aRoot.Position.X + math.cos(ang) * r, gy, aRoot.Position.Z + math.sin(ang) * r)
				if a >= 1 then
					for _, ch in ipairs(orb:GetChildren()) do
						if ch:IsA("ParticleEmitter") or ch:IsA("Trail") then
							(ch :: any).Enabled = false
						end
					end
				end
			end
		end)
	end)

	-- Estouro radial de poeira/faiscas no chao + Highlight carmesim pulsando + aura persistente
	jan:Delay(relT, function()
		if not attacker.Parent or not aRoot.Parent then
			return
		end
		local floorPos = Vector3.new(aRoot.Position.X, groundYOf(attacker) + 0.18, aRoot.Position.Z)
		local burstCarrier = createInvisibleCarrier(container, CFrame.new(floorPos), jan)

		SoundManager.PlayFortificacaoBurst(burstCarrier, jan)
		CinematicCamera.AddTrauma(0.55, 2.4)
		CinematicCamera.FovPunch(6.5)
		createFlickerLight(burstCarrier, Config.Colors.CrimsonBright, 3.6, 22, 0.55, jan)

		-- Onda radial de poeira no chao (100% particulas horizontais com Drag, zero disco de Neon!)
		local dustWave = Instance.new("ParticleEmitter")
		dustWave.Texture = Config.Fallbacks.Smoke
		dustWave.Color = ColorSequence.new(Color3.fromRGB(72, 48, 52), Config.Colors.Obsidian)
		dustWave.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 1) })
		dustWave.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4.8) })
		dustWave.Lifetime = NumberRange.new(0.42, 0.72)
		dustWave.Speed = NumberRange.new(18, 34)
		dustWave.SpreadAngle = Vector2.new(180, 8)
		dustWave.Drag = 3.5
		dustWave.LightEmission = 0
		dustWave.Rate = 0
		dustWave.Parent = burstCarrier
		dustWave:Emit(scaleCount(34))

		local sparkWave = Instance.new("ParticleEmitter")
		sparkWave.Texture = Config.Fallbacks.Streak
		sparkWave.Orientation = Enum.ParticleOrientation.VelocityParallel
		sparkWave.Color = ColorSequence.new(Config.Colors.SlashWhite, Config.Colors.CrimsonBright)
		sparkWave.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		sparkWave.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0.06) })
		sparkWave.Squash = NumberSequence.new(1.5, 2.6)
		sparkWave.Lifetime = NumberRange.new(0.28, 0.48)
		sparkWave.Speed = NumberRange.new(22, 42)
		sparkWave.SpreadAngle = Vector2.new(180, 22)
		sparkWave.Drag = 3.2
		sparkWave.LightEmission = 1
		sparkWave.Rate = 0
		sparkWave.Parent = burstCarrier
		sparkWave:Emit(scaleCount(36))

		-- Highlight carmesim pulsando no corpo do Sukuna
		local hl = Instance.new("Highlight")
		hl.Name = "SukunaFortifyHighlight"
		hl.FillColor = Config.Colors.CrimsonCore
		hl.OutlineColor = Config.Colors.CrimsonBright
		hl.FillTransparency = 0.35
		hl.OutlineTransparency = 0.0
		hl.Parent = attacker
		jan:Add(hl)
		jan:Add(TweenService:Create(hl, TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			FillTransparency = 1,
			OutlineTransparency = 1,
		})):Play()

		attachPersistentBuffAura(attacker)
	end)
end

--============================================================================
-- 4. SANTUARIO MALEVOLENTE (Habilidade 4 — 1 PP / 2 Rodadas / 15% Sangramento)
-- Parte A: Selo Enmaten + "Ryōiki Tenkai..." + pulso negro/vermelho nos dedos
-- Parte B: "Fukuma Mizushi" + Impact Frame P&B/carmesim + Transformacao do Campo e Santuario 3D
-- Parte C: Cortes 3D incessantes no ar + sangramento de 15%
--============================================================================
function SukunaVFX.PlaySantuario(
	attacker: Model,
	primaryTarget: Model?,
	allTargets: { Model }?,
	timing: { [string]: number }?
)
	local aRoot = rootOf(attacker)
	if not aRoot then
		return
	end

	local chargeT = (timing and timing.Charge) or 0.28
	local relT = (timing and timing.Release) or 1.18
	local impT = (timing and timing.Impact) or 1.86
	local lenT = (timing and timing.Length) or 2.85
	local jan = newMoveJanitor(lenT + 1.0)
	local container = getContainer()
	local targets: { Model } = if allTargets and #allTargets > 0
		then allTargets
		elseif primaryTarget then { primaryTarget }
		else {}

	CinematicCamera.PlaySantuario(attacker, primaryTarget, timing)

	-- Parte A: Selo Enmaten + Voz "Ryōiki Tenkai..." + energia negra/vermelha escapando dos dedos
	jan:Delay(chargeT, function()
		if not aRoot.Parent then
			return
		end
		local sealPos = aRoot.CFrame:PointToWorldSpace(Vector3.new(0, 0.55, -1.05))
		local sealCarrier = createInvisibleCarrier(container, CFrame.new(sealPos), jan)

		SoundManager.PlaySantuarioPartA(sealCarrier, jan)
		createFlickerLight(sealCarrier, Config.Colors.CrimsonBright, 3.0, 14, relT - chargeT + 0.2, jan)

		local fingerWisps = Instance.new("ParticleEmitter")
		fingerWisps.Texture = Config.Fallbacks.Flame
		fingerWisps.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Config.Colors.CrimsonBright),
			ColorSequenceKeypoint.new(0.45, Config.Colors.BloodDeep),
			ColorSequenceKeypoint.new(1, Config.Colors.Obsidian),
		})
		fingerWisps.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(0.6, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		})
		fingerWisps.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.42),
			NumberSequenceKeypoint.new(1, 1.35),
		})
		fingerWisps.Lifetime = NumberRange.new(0.35, 0.65)
		fingerWisps.Rate = if lowQuality() then 25 else 52
		fingerWisps.Speed = NumberRange.new(1.5, 5.5)
		fingerWisps.SpreadAngle = Vector2.new(180, 180)
		fingerWisps.Acceleration = Vector3.new(0, 4, 0)
		fingerWisps.LightEmission = 0.55
		fingerWisps.Parent = sealCarrier

		jan:Delay(math.max(0.2, relT - chargeT), function()
			fingerWisps.Enabled = false
		end)
	end)

	-- Parte B: Pausa tensa -> "Fukuma Mizushi" + Impact Frame P&B/carmesim + Santuario Malevolente erguendo-se!
	jan:Delay(relT, function()
		if not attacker.Parent or not aRoot.Parent then
			return
		end
		local castCarrier = createInvisibleCarrier(container, aRoot.CFrame, jan)
		SoundManager.PlaySantuarioPartB(castCarrier, jan)
		playAnimeImpactFrame(Config.Colors.CrimsonBright, 0.065, 0.34, false)
		CinematicCamera.AddTrauma(0.88, 1.65)
		CinematicCamera.FovPunch(-6.5)

		MalevolentShrineEnv.OpenDomain(attacker, primaryTarget)
	end)

	-- Parte C: Tempestade inaugural de cortes 3D no ar sincronizada com os 15% de sangramento na invocacao!
	jan:Delay(impT, function()
		CinematicCamera.AddTrauma(0.82, 2.0)
		if #targets > 0 then
			MalevolentShrineEnv.PlayDomainSlashVolley(targets, true)
		end
	end)
end

--============================================================================
-- 5. FUGA (Rework Completo Nivel AAA — Chama Divina / Flecha de Fogo)
-- Delegado integralmente ao modulo dedicado FugaVFX (6 fases em RenderStepped,
-- empilhamento termico real de 4 camadas, PointLight noise e zero primitivos).
--============================================================================
function SukunaVFX.PlayFuga(
	attacker: Model,
	primaryTarget: Model?,
	allTargets: { Model }?,
	timing: { [string]: number }?
)
	FugaVFX.Play(attacker, primaryTarget, allTargets, timing)
end

-- Eventos diretos do Dominio acionados pela HUD/BattleClient
function SukunaVFX.OnDomainSlashEvent(targets: { Model })
	if #targets > 0 then
		CinematicCamera.PlayDomainSlashTick(targets[1])
		MalevolentShrineEnv.PlayDomainSlashVolley(targets, false)
	end
end

function SukunaVFX.OnDomainEnd()
	MalevolentShrineEnv.CloseDomain(false)
end

function SukunaVFX.Cleanup()
	for jan in pairs(activeMoveJanitors) do
		activeMoveJanitors[jan] = nil
		jan:Cleanup()
	end
	for m, jan in pairs(buffAuraByModel) do
		buffAuraByModel[m] = nil
		jan:Cleanup()
	end
	FugaVFX.Cleanup()
	MalevolentShrineEnv.CloseDomain(true)
	AnimatorModule.Cleanup()
	CinematicCamera.Cleanup()
	SoundManager.Cleanup()
end

return SukunaVFX
