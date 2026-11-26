--[[
	VfxController (so no cliente; GDD secao 11)
	Toca a animacao do golpe no atacante e o efeito do golpe, sincronizados pelos
	marcadores Charge, Release e Impact da animacao.

	Uso (BattleClient):
	  VfxController.PlayMove(moveId, atacante, alvo)   -- golpe com campos Anim e Vfx em Data/Moves
	  VfxController.Play(nomeDoEfeito, atacante, alvo)  -- so o efeito, sem animacao
	  VfxController.CritFlash()                          -- flash de critico
	  VfxController.Cleanup()                            -- fim da batalha

	Modelos dos efeitos: ReplicatedStorage/Vfx/<nome>. Cada efeito tem um roteiro em HANDLERS
	com as fases Charge, Release e Impact. Objetos sao reaproveitados (pool).
	Limites: ate 150 particulas por efeito (200 na tecnica assinatura), 2 PointLights sem sombra.
	Qualidade baixa: metade das particulas, sem tremor de camera.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local Moves = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("Moves"))
local CombatAnimator = require(ReplicatedStorage:WaitForChild("CombatAnimator"))
local SukunaVFX = require(ReplicatedStorage:WaitForChild("Sukuna"):WaitForChild("SukunaVFX"))
local VFX = ReplicatedStorage:WaitForChild("Vfx")

local VfxController = {}

local PHASES = { "Charge", "Release", "Impact" }
local pool = {} -- [nome] = { modelos livres }
local active = {} -- modelos em uso
local tracks = setmetatable({}, { __mode = "k" }) -- cache de AnimationTrack por modelo
local activeTweens = {}
local cutInState = nil
local camPoseValue = Instance.new("CFrameValue")
local camFovValue = Instance.new("NumberValue")
camFovValue.Value = 50
local camTiltValue = Instance.new("NumberValue")
local fovPunchValue = Instance.new("NumberValue")
local activeTiltTweens = {}
local activeFovPunchTweens = {}
local shakeState = nil
local springShakeState = nil
local camDriverConn: RBXScriptConnection? = nil

local function getBattleBase(cam: Camera): (CFrame, number)
	local attrCF = cam:GetAttribute("BattleBaseCFrame")
	local attrFov = cam:GetAttribute("BattleBaseFov")
	local baseCF = if typeof(attrCF) == "CFrame" then attrCF else ((cutInState and cutInState.baseCF) or cam.CFrame)
	local baseFov = if typeof(attrFov) == "number" then attrFov else ((cutInState and cutInState.baseFov) or 50)
	return baseCF, baseFov
end

local function ensureCamDriver()
	if camDriverConn then
		return
	end
	camDriverConn = RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam or cam.CameraType ~= Enum.CameraType.Scriptable then
			shakeState = nil
			springShakeState = nil
			camTiltValue.Value = 0
			fovPunchValue.Value = 0
			if camDriverConn then
				camDriverConn:Disconnect()
				camDriverConn = nil
			end
			return
		end

		local baseCF, baseFov = getBattleBase(cam)
		local hasPose = cutInState ~= nil and cutInState.activePose == true
		local poseCF = if hasPose then camPoseValue.Value else baseCF
		local fovPunch = fovPunchValue.Value
		local hasFovPunch = math.abs(fovPunch) > 0.01
		local fov = (if hasPose then camFovValue.Value else baseFov) + fovPunch

		local tiltDeg = camTiltValue.Value
		local hasTilt = math.abs(tiltDeg) > 0.001
		local tiltCF = if hasTilt then CFrame.Angles(0, 0, math.rad(tiltDeg)) else CFrame.identity

		local jitterCF = CFrame.identity
		if shakeState then
			local elapsed = os.clock() - shakeState.t0
			if elapsed >= shakeState.dur then
				shakeState = nil
			else
				local k = shakeState.mag * (1 - elapsed / shakeState.dur)
				jitterCF = CFrame.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
			end
		end
		if springShakeState then
			local elapsed = os.clock() - springShakeState.t0
			if elapsed >= springShakeState.dur then
				springShakeState = nil
			else
				local decay = math.exp(-springShakeState.damping * elapsed)
				local ox = math.sin(elapsed * springShakeState.freq + springShakeState.sx) * springShakeState.mag * decay
				local oy = math.cos(elapsed * springShakeState.freq * 1.18 + springShakeState.sy) * springShakeState.mag * 0.72 * decay
				local rz = math.sin(elapsed * springShakeState.freq * 0.85) * math.rad(springShakeState.rotDeg) * decay
				jitterCF = jitterCF * CFrame.new(ox, oy, 0) * CFrame.Angles(0, 0, rz)
			end
		end

		if not hasPose and not hasTilt and not hasFovPunch and not shakeState and not springShakeState then
			cam.CFrame = baseCF
			cam.FieldOfView = baseFov
			if camDriverConn then
				camDriverConn:Disconnect()
				camDriverConn = nil
			end
			return
		end

		cam.CFrame = poseCF * tiltCF * jitterCF
		cam.FieldOfView = math.clamp(fov, 32, 75)
	end)
end

local function lowQuality(): boolean
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	return ok and level ~= 0 and level <= 3
end

local function container(): Folder
	local f = workspace:FindFirstChild("BattleVfx")
	if not f then
		f = Instance.new("Folder")
		f.Name = "BattleVfx"
		f.Parent = workspace
	end
	return f
end

local function acquire(name: string): Model?
	local list = pool[name]
	local m = list and table.remove(list)
	if not m then
		local template = VFX:FindFirstChild(name)
		if not template then
			warn("Efeito nao encontrado em ReplicatedStorage/Vfx: " .. name)
			return nil
		end
		m = template:Clone()
	end
	m.Parent = container()
	active[m] = name
	return m
end

local function release(m: Model)
	local name = active[m]
	if not name then
		return
	end
	active[m] = nil
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Origin" and d.Name ~= "Hit" and d.Name ~= "Ground" then
			d.Transparency = 1
		elseif d:IsA("Decal") then
			d.Transparency = 1
		elseif d:IsA("PointLight") then
			d.Brightness = 0
		elseif d:IsA("Trail") or d:IsA("Beam") or d:IsA("ParticleEmitter") then
			d.Enabled = false
		elseif d:IsA("Sound") then
			d:Stop()
		end
	end
	m.Parent = nil
	pool[name] = pool[name] or {}
	table.insert(pool[name], m)
end

local function emit(part: Instance, emitterName: string, count: number)
	local e = part:FindFirstChild(emitterName, true)
	if e and e:IsA("ParticleEmitter") then
		e:Emit(if lowQuality() then math.max(1, math.floor(count / 2)) else count)
	end
end

local function tween(obj: Instance, time: number, props, style, dir)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- Luz de impacto: sobe rapido e cai em 0,3 s (com teto para nao clarear a tela)
local function pulseLight(light: PointLight?, peak: number, range: number?)
	if not light then
		return
	end
	local capped = math.min(peak or 3.5, 4.0)
	light.Range = range or 14
	light.Brightness = 0
	tween(light, 0.06, { Brightness = capped }).Completed:Once(function()
		tween(light, 0.3, { Brightness = 0 })
	end)
end

-- Tremor leve de camera, composto sem sobrescrever tweens de CutIn/retorno
local function shake(duration: number, magnitude: number)
	if lowQuality() then
		return
	end
	local cam = workspace.CurrentCamera
	if not cam or cam.CameraType ~= Enum.CameraType.Scriptable then
		return
	end
	shakeState = {
		t0 = os.clock(),
		dur = duration,
		mag = magnitude,
	}
	ensureCamDriver()
end

-- Tremor harmonico amortecido (mola 2a ordem: impacto anime sem ruido seco)
local function springShake(magnitude: number, duration: number?, freq: number?, damping: number?, rotDeg: number?)
	if lowQuality() then
		return
	end
	local cam = workspace.CurrentCamera
	if not cam or cam.CameraType ~= Enum.CameraType.Scriptable then
		return
	end
	springShakeState = {
		t0 = os.clock(),
		dur = duration or 0.34,
		mag = magnitude,
		freq = freq or 42,
		damping = damping or 10.5,
		rotDeg = rotDeg or (magnitude * 2.4),
		sx = math.random() * math.pi * 2,
		sy = math.random() * math.pi * 2,
	}
	ensureCamDriver()
end

-- Pulso rapido de FOV no impacto (ex.: -5 graus em 0.06s e volta em 0.24s)
local function fovPunch(deltaFov: number, inTime: number?, outTime: number?)
	if lowQuality() then
		return
	end
	local cam = workspace.CurrentCamera
	if not cam or cam.CameraType ~= Enum.CameraType.Scriptable then
		return
	end
	for _, t in activeFovPunchTweens do
		t:Cancel()
	end
	table.clear(activeFovPunchTweens)
	ensureCamDriver()
	local t1 = tween(fovPunchValue, inTime or 0.055, { Value = deltaFov }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	table.insert(activeFovPunchTweens, t1)
	t1.Completed:Once(function()
		local t2 = tween(fovPunchValue, outTime or 0.24, { Value = 0 }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		table.insert(activeFovPunchTweens, t2)
	end)
end

local function rootOf(model: Model): BasePart?
	return model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
end

local function groundY(model: Model): number
	local root = rootOf(model)
	if not root then
		return 0
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	return root.Position.Y - root.Size.Y / 2 - (hum and hum.HipHeight or 2)
end

local function handPos(model: Model): Vector3
	if not model then
		return Vector3.zero
	end
	local solidArm = model:FindFirstChild("RightArm_Mesh")
	if solidArm and solidArm:IsA("BasePart") then
		return solidArm.CFrame:PointToWorldSpace(Vector3.new(0, -solidArm.Size.Y * 0.44, 0))
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d.Name == "RightHand" and d:IsA("Bone") then
			return d.TransformedWorldCFrame.Position
		end
	end
	local hand = model:FindFirstChild("RightHand") or rootOf(model)
	return if hand then hand.Position else Vector3.zero
end

local function leftHandPos(model: Model): Vector3
	if not model then
		return Vector3.zero
	end
	local solidArm = model:FindFirstChild("LeftArm_Mesh")
	if solidArm and solidArm:IsA("BasePart") then
		return solidArm.CFrame:PointToWorldSpace(Vector3.new(0, -solidArm.Size.Y * 0.44, 0))
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d.Name == "LeftHand" and d:IsA("Bone") then
			return d.TransformedWorldCFrame.Position
		end
	end
	local hand = model:FindFirstChild("LeftHand") or rootOf(model)
	return if hand then hand.Position else Vector3.zero
end

local function targetCenter(model: Model): Vector3
	local root = rootOf(model)
	return if root then root.Position + Vector3.new(0, 0.35, 0) else Vector3.zero
end

local function playSfx(parent: Instance, soundName: string)
	local s = parent and parent:FindFirstChild(soundName, true)
	if s and s:IsA("Sound") then
		s:Stop()
		s.TimePosition = 0
		s:Play()
	end
end

local function setDisc(part: BasePart, cf: CFrame, sizeXZ: number, decalTrans: number)
	part.CFrame = cf
	part.Size = Vector3.new(sizeXZ, 0.05, sizeXZ)
	part.Transparency = 1
	for _, d in part:GetChildren() do
		if d:IsA("Decal") then
			d.Transparency = decalTrans
		end
	end
end

local function tweenDisc(part: BasePart, duration: number, endSizeXZ: number, endTrans: number)
	tween(part, duration, { Size = Vector3.new(endSizeXZ, 0.05, endSizeXZ) })
	for _, d in part:GetChildren() do
		if d:IsA("Decal") then
			tween(d, duration, { Transparency = endTrans })
		end
	end
end

local function impactFrame(darkTime: number, brightTime: number)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "TudoRoxoImpact"
	cc.Contrast = 0.65
	cc.Saturation = -0.85
	cc.Brightness = -0.22
	cc.Parent = Lighting
	Debris:AddItem(cc, darkTime + brightTime + 0.15)
	task.delay(darkTime, function()
		if not cc.Parent then
			return
		end
		cc.Brightness = 0.08
		cc.Contrast = 0.22
		cc.Saturation = 0.20
		tween(cc, brightTime, { Brightness = 0, Contrast = 0, Saturation = 0 }).Completed:Once(function()
			cc:Destroy()
		end)
	end)
end

-- Impact Frame 2D estilo anime (alto contraste com tom opcional + vinheta sutil de impacto)
local function animeImpactFrame(tint: Color3?, darkTime: number?, brightTime: number?, withFlashLines: boolean?)
	local dt = darkTime or 0.045
	local bt = brightTime or 0.20
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "AnimeImpactFrame"
	cc.Contrast = 0.72
	cc.Saturation = -0.82
	cc.Brightness = -0.20
	cc.TintColor = tint or Color3.fromRGB(255, 232, 244)
	cc.Parent = Lighting
	Debris:AddItem(cc, dt + bt + 0.15)

	if withFlashLines and not lowQuality() then
		local player = Players.LocalPlayer
		local pg = player and player:FindFirstChildOfClass("PlayerGui")
		if pg then
			local sg = Instance.new("ScreenGui")
			sg.Name = "AnimeImpactOverlay"
			sg.DisplayOrder = 16
			sg.IgnoreGuiInset = true
			sg.Parent = pg
			local flash = Instance.new("Frame")
			flash.Size = UDim2.fromScale(1, 1)
			flash.BackgroundColor3 = tint or Color3.fromRGB(255, 210, 235)
			flash.BackgroundTransparency = 0.72
			flash.BorderSizePixel = 0
			flash.Parent = sg
			tween(flash, dt + bt * 0.7, { BackgroundTransparency = 1 })
			Debris:AddItem(sg, dt + bt + 0.1)
		end
	end

	task.delay(dt, function()
		if not cc.Parent then
			return
		end
		cc.Brightness = 0.10
		cc.Contrast = 0.24
		cc.Saturation = 0.18
		tween(cc, bt, { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) }).Completed:Once(function()
			cc:Destroy()
		end)
	end)
end

local function clearCutIn()
	for _, t in activeTweens do
		t:Cancel()
	end
	table.clear(activeTweens)
	for _, t in activeTiltTweens do
		t:Cancel()
	end
	table.clear(activeTiltTweens)
	for _, t in activeFovPunchTweens do
		t:Cancel()
	end
	table.clear(activeFovPunchTweens)
	camTiltValue.Value = 0
	fovPunchValue.Value = 0
	shakeState = nil
	springShakeState = nil
	if camDriverConn then
		camDriverConn:Disconnect()
		camDriverConn = nil
	end
	local cam = workspace.CurrentCamera
	if cutInState then
		if cutInState.banner and cutInState.banner.Parent then
			cutInState.banner:Destroy()
		end
		if not cutInState.customCamera and cam and cam.CameraType == Enum.CameraType.Scriptable then
			local baseCF, baseFov = getBattleBase(cam)
			cam.CFrame = baseCF
			cam.FieldOfView = baseFov
		end
		cutInState = nil
	elseif cam and cam.CameraType == Enum.CameraType.Scriptable then
		local attrCF = cam:GetAttribute("BattleBaseCFrame")
		if typeof(attrCF) == "CFrame" then
			cam.CFrame = attrCF
			cam.FieldOfView = cam:GetAttribute("BattleBaseFov") or 50
		end
	end
end

-- GDD Sec 5: Tecnica assinatura de Epico/Lendario tem aproximacao de camera e nome do golpe na tela
local function playCutIn(move, attacker: Model, timing)
	clearCutIn()
	local state = {}
	cutInState = state

	-- Faixa com o nome do golpe na tela
	local player = Players.LocalPlayer
	local pg = player and player:FindFirstChildOfClass("PlayerGui")
	if pg then
		local sg = Instance.new("ScreenGui")
		sg.Name = "SignatureMoveBanner"
		sg.DisplayOrder = 18
		sg.IgnoreGuiInset = true
		sg.Parent = pg
		state.banner = sg

		local pal = move.CutInColors or {}
		local bar = Instance.new("Frame")
		bar.Size = UDim2.fromScale(0.38, 0.095)
		bar.Position = UDim2.fromScale(0.5, move.CutInBannerY or 0.23)
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.BackgroundColor3 = pal.Bg or Color3.fromRGB(36, 14, 72)
		bar.BackgroundTransparency = 0.04
		bar.Parent = sg
		local cr = Instance.new("UICorner")
		cr.CornerRadius = UDim.new(0.35, 0)
		cr.Parent = bar
		local st = Instance.new("UIStroke")
		st.Color = pal.Stroke or Color3.fromRGB(205, 110, 255)
		st.Thickness = 3
		st.Parent = bar
		local gr = Instance.new("UIGradient")
		gr.Color = ColorSequence.new(pal.Grad1 or Color3.fromRGB(95, 25, 175), pal.Grad2 or Color3.fromRGB(32, 10, 64))
		gr.Parent = bar

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(0.92, 0.8)
		lbl.Position = UDim2.fromScale(0.04, 0.1)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextScaled = true
		lbl.Text = string.upper(move.Name) .. "!"
		lbl.TextColor3 = pal.Text or Color3.fromRGB(255, 224, 110)
		lbl.Parent = bar
		local ts = Instance.new("UIStroke")
		ts.Color = pal.TextStroke or Color3.fromRGB(26, 12, 50)
		ts.Thickness = 3
		ts.Parent = lbl

		local sc = Instance.new("UIScale")
		sc.Scale = 0.35
		sc.Parent = bar
		tween(sc, 0.22, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

		local hold = math.max(1.0, (timing and timing.Impact or 1.45) - 0.05)
		task.delay(hold, function()
			if state.banner ~= sg or not sg.Parent then
				return
			end
			tween(sc, 0.22, { Scale = 0.7 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween(bar, 0.22, { BackgroundTransparency = 1 })
			tween(st, 0.22, { Transparency = 1 })
			tween(lbl, 0.22, { TextTransparency = 1 })
			tween(ts, 0.22, { Transparency = 1 }).Completed:Once(function()
				if sg.Parent then
					sg:Destroy()
				end
			end)
		end)
	end

	-- Se o golpe possui direcao de camera cinematografica dedicada (ex.: Sukuna), cede 100% do controle de camera
	if move.CustomCinematicCamera then
		state.customCamera = true
		return
	end

	-- Aproximacao temporaria de camera na batalha (sempre referenciada na camera base da arena)
	local cam = workspace.CurrentCamera
	local root = rootOf(attacker)
	if cam and root and cam.CameraType == Enum.CameraType.Scriptable and not lowQuality() then
		local baseCF, baseFov = getBattleBase(cam)
		state.baseCF = baseCF
		state.baseFov = baseFov
		state.activePose = true
		camPoseValue.Value = baseCF
		camFovValue.Value = baseFov
		ensureCamDriver()

		local focus = root.Position + Vector3.new(0, move.CutInFocusY or 1.3, 0)
		local closerPos = baseCF.Position:Lerp(focus, if move.CutInFov then 0.14 else 0.24) + baseCF.RightVector * 1.3 + Vector3.new(0, 0.4, 0)
		local zoomCF = CFrame.lookAt(closerPos, focus + (baseCF.LookVector * 3))

		local relT = (timing and timing.Release) or 0.95
		local impT = (timing and timing.Impact) or 1.45
		local inTime = math.min(0.42, math.max(0.22, relT * 0.55))
		local t1 = tween(camPoseValue, inTime, { Value = zoomCF }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tf1 = tween(camFovValue, inTime, { Value = move.CutInFov or 40 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		table.insert(activeTweens, t1)
		table.insert(activeTweens, tf1)

		local backAt = math.max(inTime + 0.15, relT - 0.05)
		local backDur = math.max(0.26, impT - backAt + 0.08)
		task.delay(backAt, function()
			if cutInState ~= state or cam.CameraType ~= Enum.CameraType.Scriptable then
				return
			end
			local t2 = tween(camPoseValue, backDur, { Value = baseCF }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
			local tf2 = tween(camFovValue, backDur, { Value = baseFov }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
			table.insert(activeTweens, t2)
			table.insert(activeTweens, tf2)
			t2.Completed:Once(function()
				if cutInState == state then
					state.activePose = false
					camPoseValue.Value = baseCF
					camFovValue.Value = baseFov
				end
			end)
		end)
	end
end

-- o modelo ainda esta no mundo? (pode sumir no meio do efeito: troca, desmaio, fim da batalha)
local function alive(model: Model?): boolean
	return model ~= nil and model.Parent ~= nil and rootOf(model) ~= nil
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

--------------------------------------------------------------------
-- Roteiros dos efeitos
--------------------------------------------------------------------
local HANDLERS = {}

-- Arranhao (Neutro): flash na mao, 3 riscos de garra no alvo, poeira
HANDLERS.Arranhao = {
	Charge = function(ctx)
		ctx.fx.Origin.CFrame = CFrame.new(handPos(ctx.attacker))
		emit(ctx.fx.Origin, "Flash", 10)
	end,
	Impact = function(ctx)
		local tr = rootOf(ctx.target)
		local look = CFrame.lookAt(tr.Position, flat(rootOf(ctx.attacker).Position) + Vector3.new(0, tr.Position.Y, 0))
		ctx.fx.Hit.CFrame = look
		emit(ctx.fx.Hit, "Dust", 18)
		emit(ctx.fx.Hit, "Shards", 22)
		pulseLight(ctx.fx.Hit:FindFirstChild("Light"), 6, 12)
		for i = 1, 3 do
			local claw = ctx.fx["Claw" .. i]
			local off = (i - 2) * 0.7
			claw.CFrame = look * CFrame.new(off, 0.3, -1.2) * CFrame.Angles(0, 0, math.rad(35))
			claw.Size = Vector3.new(0.18, 0.2, 0.08)
			claw.Transparency = 0
			tween(claw, 0.08, { Size = Vector3.new(0.18, 3.6, 0.08) })
			task.delay(0.12, function()
				tween(claw, 0.25, { Transparency = 1, Size = Vector3.new(0.05, 4, 0.05) })
			end)
		end
		shake(0.15, 0.25)
	end,
	Duration = 1.0,
}

-- Semente Toxica (Natureza): brilho na mao, semente voa em arco com rastro, esporos e folhas
HANDLERS.SementeToxica = {
	Charge = function(ctx)
		ctx.fx.Origin.CFrame = CFrame.new(handPos(ctx.attacker))
		emit(ctx.fx.Origin, "Glow", 12)
	end,
	Release = function(ctx)
		local seed = ctx.fx.Seed
		local from = handPos(ctx.attacker)
		local to = rootOf(ctx.target).Position
		local flight = math.max(0.12, (ctx.timing.Impact or 0.6) - (ctx.timing.Release or 0.38))
		seed.CFrame = CFrame.new(from)
		seed.Transparency = 0
		seed.Trail.Enabled = true
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local a = math.clamp((os.clock() - t0) / flight, 0, 1)
			local p = from:Lerp(to, a) + Vector3.new(0, math.sin(a * math.pi) * 2.5, 0)
			seed.CFrame = CFrame.new(p) * CFrame.Angles(a * 8, a * 5, 0)
			if a >= 1 then
				conn:Disconnect()
			end
		end)
	end,
	Impact = function(ctx)
		local seed = ctx.fx.Seed
		seed.Transparency = 1
		task.delay(0.25, function()
			seed.Trail.Enabled = false
		end)
		ctx.fx.Hit.CFrame = CFrame.new(rootOf(ctx.target).Position)
		emit(ctx.fx.Hit, "Core", 3)
		emit(ctx.fx.Hit, "Spores", 30)
		emit(ctx.fx.Hit, "Leaves", 22)
		pulseLight(ctx.fx.Hit:FindFirstChild("Light"), 5, 12)
		shake(0.15, 0.15)
	end,
	Duration = 1.4,
}

-- Casca de Carvalho (suporte): folhas girando para dentro, anel de casca e aura verde subindo
HANDLERS.CascaDeCarvalho = {
	Charge = function(ctx)
		ctx.fx.Origin.CFrame = CFrame.new(rootOf(ctx.attacker).Position)
		emit(ctx.fx.Origin, "Swirl", 24)
	end,
	Release = function(ctx)
		local base = Vector3.new(rootOf(ctx.attacker).Position.X, groundY(ctx.attacker) + 0.2, rootOf(ctx.attacker).Position.Z)
		ctx.fx.Origin.CFrame = CFrame.new(base)
		emit(ctx.fx.Origin, "Rise", 40)
		for i, name in { "Ring", "Ring2" } do
			local ring = ctx.fx[name]
			ring.CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90))
			ring.Size = Vector3.new(0.15, 2.5, 2.5)
			ring.Transparency = 0.35
			local delayT = (i - 1) * 0.12
			task.delay(delayT, function()
				tween(ring, 0.6, { Size = Vector3.new(0.15, 5.5, 5.5), Transparency = 1, CFrame = CFrame.new(base + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, 0, math.rad(90)) }, Enum.EasingStyle.Sine)
			end)
		end
	end,
	Duration = 1.2,
}

-- Gaiola de Espinhos (tecnica assinatura): semente brilhando na mao, cravada no chao,
-- onda de brotos ate o alvo e espinhos subindo em espiral que se fecham sobre ele.
HANDLERS.GaiolaDeEspinhos = {
	Charge = function(ctx)
		local fx = ctx.fx
		local seed = fx.SeedGlow
		seed.Size = Vector3.new(0.2, 0.2, 0.2)
		seed.Transparency = 0
		tween(seed, 0.45, { Size = Vector3.new(1, 1, 1) }, Enum.EasingStyle.Back)
		pulseLight(fx.Origin:FindFirstChild("HandLight"), 3, 10)
		local t0 = os.clock()
		ctx.follow = RunService.RenderStepped:Connect(function()
			if not alive(ctx.attacker) then
				ctx.follow:Disconnect()
				ctx.follow = nil
				return
			end
			local p = handPos(ctx.attacker) + Vector3.new(0, 0.6, 0)
			seed.CFrame = CFrame.new(p) * CFrame.Angles(0, (os.clock() - t0) * 6, 0)
			fx.Origin.CFrame = CFrame.new(p)
		end)
		emit(fx.Origin, "Gather", 16)
		task.delay(0.25, function()
			emit(fx.Origin, "Gather", 14)
		end)
	end,
	Release = function(ctx)
		local fx = ctx.fx
		if ctx.follow then
			ctx.follow:Disconnect()
			ctx.follow = nil
		end
		fx.SeedGlow.Transparency = 1
		local aRoot, tRoot = rootOf(ctx.attacker), rootOf(ctx.target)
		local gy = groundY(ctx.attacker)
		local from = Vector3.new(aRoot.Position.X, gy, aRoot.Position.Z)
		local to = Vector3.new(tRoot.Position.X, groundY(ctx.target), tRoot.Position.Z)
		local dir = (flat(to) - flat(from)).Unit
		from += dir * 1.5
		fx.Ground.CFrame = CFrame.new(from)
		emit(fx.Ground, "Crack", 16)
		local ring = fx.GroundRing
		ring.CFrame = CFrame.new(from + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Size = Vector3.new(0.12, 1, 1)
		ring.Transparency = 0.1
		tween(ring, 0.35, { Size = Vector3.new(0.12, 6, 6), Transparency = 1 })
		-- onda de brotos ate o alvo
		local sprouts = {}
		for i = 1, 5 do
			table.insert(sprouts, fx.Thorns["Sprout" .. i])
		end
		local travel = math.max(0.15, (ctx.timing.Impact or 1.05) - (ctx.timing.Release or 0.72) - 0.05)
		for i, s in sprouts do
			local p = from:Lerp(to - dir * 2.5, i / (#sprouts + 0.5))
			local up = CFrame.new(p) * CFrame.Angles(0, math.random() * 6.28, math.rad(math.random(-15, 15)))
			task.delay(travel * (i - 1) / #sprouts, function()
				if not ctx.alive then
					return
				end
				for _, part in s:GetChildren() do
					part.Transparency = 0
				end
				s:PivotTo(up * CFrame.new(0, -2, 0))
				local v = Instance.new("CFrameValue")
				v.Value = up * CFrame.new(0, -2, 0)
				v.Changed:Connect(function(cf)
					s:PivotTo(cf)
				end)
				tween(v, 0.1, { Value = up })
				task.delay(0.22, function()
					tween(v, 0.25, { Value = up * CFrame.new(0, -2, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Once(function()
						for _, part in s:GetChildren() do
							part.Transparency = 1
						end
						v:Destroy()
					end)
				end)
			end)
		end
		shake(0.12, 0.15)
	end,
	Impact = function(ctx)
		local fx = ctx.fx
		local tRoot = rootOf(ctx.target)
		local center = Vector3.new(tRoot.Position.X, groundY(ctx.target), tRoot.Position.Z)
		fx.Hit.CFrame = CFrame.new(center + Vector3.new(0, 2.5, 0))
		emit(fx.Hit, "Core", 3)
		emit(fx.Hit, "Leaves", 40)
		emit(fx.Hit, "Pollen", 36)
		pulseLight(fx.Hit:FindFirstChild("HitLight"), 8, 16)
		shake(0.15, 0.35)
		-- 8 espinhos sobem em espiral e se fecham sobre o alvo
		for i = 1, 8 do
			local thorn = fx.Thorns["Thorn" .. i]
			local ang = (i / 8) * math.pi * 2
			local radius = 2.6
			local pos = center + Vector3.new(math.cos(ang) * radius, 0, math.sin(ang) * radius)
			-- eixo X local aponta para o centro; inclinar = girar a ponta em direcao ao alvo
			local facing = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z)) * CFrame.Angles(0, math.pi / 2, 0)
			local function at(lean, depth)
				return facing * CFrame.new(0, -depth, 0) * CFrame.Angles(0, 0, math.rad(-lean))
			end
			for _, part in thorn:GetChildren() do
				part.Transparency = 0
			end
			local v = Instance.new("CFrameValue")
			v.Value = at(10, 6)
			thorn:PivotTo(v.Value)
			v.Changed:Connect(function(cf)
				thorn:PivotTo(cf)
			end)
			local d = (i - 1) * 0.025
			task.delay(d, function()
				tween(v, 0.16, { Value = at(18, 0) }, Enum.EasingStyle.Back)
			end)
			task.delay(d + 0.22, function()
				tween(v, 0.18, { Value = at(38, 0) }, Enum.EasingStyle.Quad)
			end)
			task.delay(0.95, function()
				tween(v, 0.4, { Value = at(30, 6) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Once(function()
					for _, part in thorn:GetChildren() do
						part.Transparency = 1
					end
					v:Destroy()
				end)
			end)
		end
	end,
	Duration = 2.2,
}

-- Atracao (Setero, Luz): esfera gravitacional azul na mao que puxa e implode no alvo
HANDLERS.Atracao = {
	Charge = function(ctx)
		local fx = ctx.fx
		playSfx(fx.Origin, "ChargeSfx")
		local p = handPos(ctx.attacker)
		fx.Origin.CFrame = CFrame.new(p)
		fx.Orb.Size = Vector3.new(0.2, 0.2, 0.2)
		fx.Orb.Transparency = 0.05
		fx.OrbShell.Size = Vector3.new(0.35, 0.35, 0.35)
		fx.OrbShell.Transparency = 0.35
		tween(fx.Orb, 0.28, { Size = Vector3.new(1.15, 1.15, 1.15) }, Enum.EasingStyle.Back)
		tween(fx.OrbShell, 0.28, { Size = Vector3.new(1.8, 1.8, 1.8) }, Enum.EasingStyle.Back)
		setDisc(fx.VortexRing, CFrame.new(p), 2.2, 0.15)
		emit(fx.Origin, "Gather", 18)
		emit(fx.Origin, "Streaks", 14)
		tween(fx.Origin:FindFirstChild("HandLight"), 0.15, { Brightness = 5 })
		local spin = 0
		ctx.follow = RunService.RenderStepped:Connect(function(dt)
			if not ctx.alive or not alive(ctx.attacker) then
				return
			end
			spin += dt * 9
			local hp = handPos(ctx.attacker)
			fx.Origin.CFrame = CFrame.new(hp)
			fx.Orb.Position = hp
			fx.OrbShell.Position = hp
			fx.VortexRing.CFrame = CFrame.new(hp) * CFrame.Angles(0.35, spin, 0.15)
		end)
	end,
	Release = function(ctx)
		local fx = ctx.fx
		if ctx.follow then
			ctx.follow:Disconnect()
			ctx.follow = nil
		end
		playSfx(fx.Hit, "ReleaseSfx")
		tween(fx.Origin:FindFirstChild("HandLight"), 0.15, { Brightness = 0 })
		local startPos = handPos(ctx.attacker)
		local endPos = targetCenter(ctx.target)
		local travel = math.max(0.18, (ctx.timing.Impact or 0.90) - (ctx.timing.Release or 0.55) - 0.02)
		fx.Orb.CFrame = CFrame.lookAt(startPos, endPos)
		fx.OrbShell.CFrame = fx.Orb.CFrame
		fx.Orb.OrbTrail.Enabled = true
		emit(fx.Orb, "OrbSparks", 16)
		local t0 = os.clock()
		ctx.follow = RunService.RenderStepped:Connect(function()
			local a = math.clamp((os.clock() - t0) / travel, 0, 1)
			local eased = a * a
			local pos = startPos:Lerp(endPos, eased)
			fx.Orb.Position = pos
			fx.OrbShell.Position = pos
			fx.VortexRing.CFrame = CFrame.new(pos) * CFrame.Angles(0.6, a * 10, 0.2)
			if a >= 1 and ctx.follow then
				ctx.follow:Disconnect()
				ctx.follow = nil
			end
		end)
	end,
	Impact = function(ctx)
		local fx = ctx.fx
		if ctx.follow then
			ctx.follow:Disconnect()
			ctx.follow = nil
		end
		local hitPos = targetCenter(ctx.target)
		fx.Orb.OrbTrail.Enabled = false
		tween(fx.Orb, 0.10, { Size = Vector3.new(2.2, 2.2, 2.2), Transparency = 1 })
		tween(fx.OrbShell, 0.10, { Size = Vector3.new(3.0, 3.0, 3.0), Transparency = 1 })
		tweenDisc(fx.VortexRing, 0.12, 4.0, 1)

		fx.Hit.CFrame = CFrame.new(hitPos)
		playSfx(fx.Hit, "ImpactSfx")
		emit(fx.Hit, "PullDebris", 26)
		task.delay(0.06, function()
			if not ctx.alive then
				return
			end
			emit(fx.Hit, "Core", 4)
			emit(fx.Hit, "Puffs", 24)
		end)
		setDisc(fx.ShockRing, CFrame.new(hitPos) * CFrame.Angles(0.25, 0, -0.15), 1.4, 0.05)
		tweenDisc(fx.ShockRing, 0.34, 9.0, 1)
		pulseLight(fx.Hit:FindFirstChild("HitLight"), 8, 18)
		shake(0.16, 0.36)
	end,
	Duration = 1.5,
}

-- Tudo Roxo / Vazio Roxo (Setero - Gojo Satoru, Lendario assinatura):
-- Delegado ao motor AAA de 5 fases ReplicatedStorage/HollowPurple/HollowPurpleVFX
HANDLERS.TudoRoxo = {
	Charge = function(ctx)
		local fx = ctx.fx
		-- Esconde as pecas antigas do pool legado e usa 100% o novo sistema HollowPurpleVFX de 5 fases!
		for _, d in ipairs(fx:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Transparency = 1
			elseif d:IsA("Beam") or d:IsA("Trail") or d:IsA("ParticleEmitter") then
				d.Enabled = false
			elseif d:IsA("Decal") then
				d.Transparency = 1
			end
		end
		playSfx(fx.Origin, "ChargeSfx")

		local hpFolder = ReplicatedStorage:FindFirstChild("HollowPurple")
		local hpModule = hpFolder and hpFolder:FindFirstChild("HollowPurpleVFX")
		if hpModule and hpModule:IsA("ModuleScript") then
			local ok, hpVfx = pcall(require, hpModule)
			if ok and hpVfx and typeof(hpVfx.PlayBattleUltimate) == "function" then
				ctx.hpHandle = hpVfx.PlayBattleUltimate(
					ctx.attacker,
					ctx.target,
					ctx.targets,
					(ctx.timing and ctx.timing.Impact) or 2.15
				)
			end
		end
	end,
	Release = function(ctx)
		local fx = ctx.fx
		playSfx(fx.Origin, "ReleaseSfx")
	end,
	Impact = function(ctx)
		local fx = ctx.fx
		local hitPos = targetCenter(ctx.target)
		fx.Hit.CFrame = CFrame.new(hitPos)
		CombatAnimator.Hitstop(ctx.attacker, 0.065)
		playSfx(fx.Hit, "ImpactSfx")
	end,
	Duration = 2.95,
}

-- Kamehameha (San, Luz especial): carga de Ki entre as duas maos no quadril -> disparo de canhao de plasma azul-celeste
HANDLERS.Kamehameha = {
	Charge = function(ctx)
		local fx = ctx.fx
		playSfx(fx.Origin, "ChargeSfx")
		local t0 = os.clock()
		local chargeDur = math.max(0.45, (ctx.timing.Release or 1.08) - (ctx.timing.Charge or 0.32))

		fx.ChargeCore.Size = Vector3.new(0.18, 0.18, 0.18)
		fx.ChargeShell.Size = Vector3.new(0.32, 0.32, 0.32)
		fx.ChargeCore.Transparency = 0.02
		fx.ChargeShell.Transparency = 0.28
		tween(fx.ChargeCore, chargeDur * 0.85, { Size = Vector3.new(1.05, 1.05, 1.05) }, Enum.EasingStyle.Back)
		tween(fx.ChargeShell, chargeDur * 0.85, { Size = Vector3.new(1.75, 1.75, 1.75) }, Enum.EasingStyle.Back)
		tween(fx.Origin:FindFirstChild("ChargeLight"), 0.45, { Brightness = 3.4 })

		local aRoot = rootOf(ctx.attacker)
		local gy = groundY(ctx.attacker)
		local footBase = Vector3.new(aRoot.Position.X, gy + 0.08, aRoot.Position.Z)
		fx.Ground.CFrame = CFrame.new(footBase)
		setDisc(fx.CasterRing, CFrame.new(footBase), 2.2, 0.12)
		tweenDisc(fx.CasterRing, chargeDur, 6.2, 0.55)

		emit(fx.Origin, "GatherRays", 24)
		emit(fx.Origin, "StarFlare", 4)
		emit(fx.Ground, "AuraFlames", 14)
		task.delay(chargeDur * 0.48, function()
			if not ctx.alive then return end
			emit(fx.Origin, "GatherRays", 26)
			emit(fx.Origin, "StarFlare", 5)
			emit(fx.Ground, "AuraFlames", 14)
		end)

		ctx.follow = RunService.RenderStepped:Connect(function()
			if not ctx.alive or not alive(ctx.attacker) then return end
			local p = (leftHandPos(ctx.attacker) + handPos(ctx.attacker)) * 0.5
			local pulse = 1 + math.sin((os.clock() - t0) * 26) * 0.08
			fx.Origin.CFrame = CFrame.new(p)
			fx.ChargeCore.Position = p
			fx.ChargeShell.Position = p
			fx.ChargeShell.Size = fx.ChargeCore.Size * (1.62 * pulse)
		end)
	end,
	Release = function(ctx)
		local fx = ctx.fx
		if ctx.follow then
			ctx.follow:Disconnect()
			ctx.follow = nil
		end
		playSfx(fx.Origin, "ReleaseSfx")

		local aRoot = rootOf(ctx.attacker)
		local endPos = targetCenter(ctx.target)
		local function muzzlePos()
			if not alive(ctx.attacker) then return aRoot.Position end
			local handsMid = (leftHandPos(ctx.attacker) + handPos(ctx.attacker)) * 0.5
			local fwd = (endPos - handsMid)
			fwd = if fwd.Magnitude > 0.05 then fwd.Unit else aRoot.CFrame.LookVector
			return handsMid + fwd * 0.85
		end

		local startPos = muzzlePos()
		fx.ChargeCore.Size = Vector3.new(2.1, 2.1, 2.1)
		fx.ChargeShell.Size = Vector3.new(3.2, 3.2, 3.2)
		fx.ChargeCore.Transparency = 0.02
		fx.ChargeShell.Transparency = 0.22

		fx.BeamSpine.Transparency = 0.02
		fx.BeamSheath.Transparency = 0.25
		fx.BeamTipOrb.Transparency = 0.04
		fx.BeamTipOrb.Size = Vector3.new(2.7, 2.7, 2.7)

		fx.BeamStartAnchor.PlasmaStreamCore.Enabled = true
		fx.BeamStartAnchor.PlasmaStreamOuter.Enabled = true
		emit(fx.Origin, "StarFlare", 5)

		local lookCF = CFrame.lookAt(startPos, endPos)
		setDisc(fx.MuzzleRing1, lookCF * CFrame.Angles(math.pi / 2, 0, 0), 1.8, 0.05)
		setDisc(fx.MuzzleRing2, lookCF * CFrame.Angles(math.pi / 2, 0.4, 0), 2.4, 0.12)
		tweenDisc(fx.MuzzleRing1, 0.36, 7.2, 1)
		tweenDisc(fx.MuzzleRing2, 0.48, 8.6, 1)

		local travel = math.max(0.18, (ctx.timing.Impact or 1.52) - (ctx.timing.Release or 1.08) - 0.02)
		local t0 = os.clock()
		shake(0.18, 0.22)

		local rings = { fx.WaveRing1, fx.WaveRing2, fx.WaveRing3 }
		for _, r in rings do
			setDisc(r, lookCF * CFrame.Angles(math.pi / 2, 0, 0), 3.4, 0.18)
		end

		ctx.follow = RunService.RenderStepped:Connect(function()
			if not ctx.alive then return end
			local elapsed = os.clock() - t0
			local reach = math.clamp(elapsed / (travel * 0.65), 0, 1)
			reach = 1 - (1 - reach) * (1 - reach)
			local sPos = muzzlePos()
			local tipPos = sPos:Lerp(endPos, reach)
			local dist = math.max(0.4, (tipPos - sPos).Magnitude)
			local mid = (sPos + tipPos) * 0.5
			local pulse = 1 + math.sin(elapsed * 34) * 0.12

			fx.Origin.CFrame = CFrame.new(sPos)
			fx.ChargeCore.Position = sPos
			fx.ChargeShell.Position = sPos
			fx.ChargeCore.Size = Vector3.new(2.0, 2.0, 2.0) * pulse
			fx.ChargeShell.Size = Vector3.new(3.1, 3.1, 3.1) * pulse

			fx.BeamStartAnchor.CFrame = CFrame.lookAt(sPos, endPos)
			fx.BeamEndAnchor.CFrame = CFrame.lookAt(tipPos, tipPos + (endPos - sPos))
			-- Part.Cylinder tem o eixo no X local
			local cylCF = CFrame.lookAt(mid, tipPos) * CFrame.Angles(0, math.pi / 2, 0)
			fx.BeamSpine.CFrame = cylCF
			fx.BeamSpine.Size = Vector3.new(dist, 1.45 * pulse, 1.45 * pulse)
			fx.BeamSheath.CFrame = cylCF
			fx.BeamSheath.Size = Vector3.new(dist, 2.75 * pulse, 2.75 * pulse)
			fx.BeamTipOrb.Position = tipPos
			fx.BeamTipOrb.Size = Vector3.new(2.8, 2.8, 2.8) * pulse

			for idx, r in ipairs(rings) do
				local u = ((elapsed * 2.4 + (idx - 1) / 3) % 1) * reach
				local rp = sPos:Lerp(tipPos, math.clamp(u, 0.04, 0.96))
				r.CFrame = CFrame.lookAt(rp, tipPos) * CFrame.Angles(math.pi / 2, elapsed * 8 + idx, 0)
				local sz = 2.8 + math.sin(u * math.pi) * 1.6
				r.Size = Vector3.new(sz, 0.05, sz)
			end
		end)
	end,
	Impact = function(ctx)
		local fx = ctx.fx
		local hitPos = targetCenter(ctx.target)
		fx.Hit.CFrame = CFrame.new(hitPos)
		playSfx(fx.Hit, "ImpactSfx")
		impactFrame(0.04, 0.20)
		emit(fx.Hit, "ImpactStar", 6)
		emit(fx.Hit, "KiSparks", 38)
		emit(fx.Hit, "VaporSmoke", 26)
		pulseLight(fx.Hit:FindFirstChild("HitLight"), 11, 22)
		shake(0.24, 0.48)

		fx.BlastCore.CFrame = CFrame.new(hitPos)
		fx.BlastDome.CFrame = CFrame.new(hitPos)
		fx.BlastCore.Size = Vector3.new(1.8, 1.8, 1.8)
		fx.BlastDome.Size = Vector3.new(2.6, 2.6, 2.6)
		fx.BlastCore.Transparency = 0.02
		fx.BlastDome.Transparency = 0.22
		tween(fx.BlastCore, 0.34, { Size = Vector3.new(6.8, 6.8, 6.8), Transparency = 1 })
		tween(fx.BlastDome, 0.40, { Size = Vector3.new(9.4, 9.4, 9.4), Transparency = 1 })

		setDisc(fx.ShockRing1, CFrame.new(hitPos) * CFrame.Angles(0.35, 0, -0.2), 2.2, 0.04)
		setDisc(fx.ShockRing2, CFrame.new(hitPos) * CFrame.Angles(-0.3, 0.5, 0.3), 1.8, 0.08)
		tweenDisc(fx.ShockRing1, 0.42, 13.5, 1)
		tweenDisc(fx.ShockRing2, 0.48, 11.2, 1)

		-- Dissipa o feixe suavemente logo apos cravar o impacto
		task.delay(0.24, function()
			if ctx.follow then
				ctx.follow:Disconnect()
				ctx.follow = nil
			end
			fx.BeamStartAnchor.PlasmaStreamCore.Enabled = false
			fx.BeamStartAnchor.PlasmaStreamOuter.Enabled = false
			tween(fx.Origin:FindFirstChild("ChargeLight"), 0.22, { Brightness = 0 })
			tween(fx.ChargeCore, 0.20, { Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1 })
			tween(fx.ChargeShell, 0.22, { Size = Vector3.new(0.4, 0.4, 0.4), Transparency = 1 })
			tween(fx.BeamSpine, 0.20, { Size = Vector3.new(fx.BeamSpine.Size.X, 0.1, 0.1), Transparency = 1 })
			tween(fx.BeamSheath, 0.22, { Size = Vector3.new(fx.BeamSheath.Size.X, 0.2, 0.2), Transparency = 1 })
			tween(fx.BeamTipOrb, 0.18, { Size = Vector3.new(0.4, 0.4, 0.4), Transparency = 1 })
			for _, r in { fx.WaveRing1, fx.WaveRing2, fx.WaveRing3 } do
				tweenDisc(r, 0.18, 5.2, 1)
			end
		end)
	end,
	Duration = 1.9,
}

-- Genki Dama (San, Luz assinatura suprema): reune energia celeste em esfera colossal acima da cabeca e arremessa no alvo
HANDLERS.GenkiDama = {
	Charge = function(ctx)
		local fx = ctx.fx
		playSfx(fx.Origin, "ChargeSfx")
		local aRoot = rootOf(ctx.attacker)
		local gy = groundY(ctx.attacker)
		local chargeDur = math.max(0.65, (ctx.timing.Release or 1.38) - (ctx.timing.Charge or 0.35))
		local skyCenter = aRoot.Position + Vector3.new(0, 6.2, 0)

		fx.Origin.CFrame = CFrame.new(skyCenter)
		fx.Ground.CFrame = CFrame.new(aRoot.Position.X, gy + 0.1, aRoot.Position.Z)
		setDisc(fx.CasterHalo, CFrame.new(aRoot.Position.X, gy + 0.08, aRoot.Position.Z), 2.5, 0.1)
		tweenDisc(fx.CasterHalo, chargeDur, 7.8, 0.45)

		fx.SpiritCore.CFrame = CFrame.new(skyCenter)
		fx.SpiritShell.CFrame = CFrame.new(skyCenter)
		fx.SpiritOuter.CFrame = CFrame.new(skyCenter)
		fx.SpiritCore.Size = Vector3.new(0.6, 0.6, 0.6)
		fx.SpiritShell.Size = Vector3.new(1.0, 1.0, 1.0)
		fx.SpiritOuter.Size = Vector3.new(1.2, 1.2, 1.2)
		fx.SpiritCore.Transparency = 0.02
		fx.SpiritShell.Transparency = 0.24
		fx.SpiritOuter.Transparency = 0.68

		tween(fx.SpiritCore, chargeDur * 0.92, { Size = Vector3.new(3.5, 3.5, 3.5) }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		tween(fx.SpiritShell, chargeDur * 0.92, { Size = Vector3.new(5.5, 5.5, 5.5) }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		tween(fx.SpiritOuter, chargeDur * 0.92, { Size = Vector3.new(6.3, 6.3, 6.3) }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		tween(fx.Origin:FindFirstChild("SpiritLight"), chargeDur * 0.85, { Brightness = 3.6 })

		setDisc(fx.OrbitRing1, CFrame.new(skyCenter) * CFrame.Angles(0.28, 0, 0.22), 2.4, 0.12)
		setDisc(fx.OrbitRing2, CFrame.new(skyCenter) * CFrame.Angles(-0.32, 0.6, -0.25), 2.0, 0.16)
		tweenDisc(fx.OrbitRing1, chargeDur * 0.92, 7.6, 0.12)
		tweenDisc(fx.OrbitRing2, chargeDur * 0.92, 6.6, 0.18)

		emit(fx.Origin, "CelestialStreams", 28)
		emit(fx.Origin, "SolarMotes", 16)
		emit(fx.Ground, "CasterRise", 14)
		emit(fx.SpiritCore, "CoreCorona", 3)
		task.delay(chargeDur * 0.45, function()
			if not ctx.alive then return end
			emit(fx.Origin, "CelestialStreams", 30)
			emit(fx.Origin, "SolarMotes", 18)
			emit(fx.Ground, "CasterRise", 14)
			emit(fx.SpiritCore, "CoreCorona", 4)
		end)

		local spin = 0
		ctx.follow = RunService.RenderStepped:Connect(function(dt)
			if not ctx.alive or not alive(ctx.attacker) then return end
			spin += dt * 4.5
			local r = rootOf(ctx.attacker)
			local sc = r.Position + Vector3.new(0, 6.2, 0)
			fx.Origin.CFrame = CFrame.new(sc)
			fx.SpiritCore.Position = sc
			fx.SpiritShell.Position = sc
			fx.SpiritOuter.Position = sc
			fx.OrbitRing1.CFrame = CFrame.new(sc) * CFrame.Angles(0.28, spin, 0.22)
			fx.OrbitRing2.CFrame = CFrame.new(sc) * CFrame.Angles(-0.32, -spin * 1.25, -0.25)
		end)
	end,
	Release = function(ctx)
		local fx = ctx.fx
		if ctx.follow then
			ctx.follow:Disconnect()
			ctx.follow = nil
		end
		playSfx(fx.Origin, "ReleaseSfx")
		tweenDisc(fx.CasterHalo, 0.25, 9.0, 1)

		local startPos = fx.SpiritCore.Position
		local tRoot = rootOf(ctx.target)
		local endPos = Vector3.new(tRoot.Position.X, groundY(ctx.target) + 2.2, tRoot.Position.Z)
		local travel = math.max(0.24, (ctx.timing.Impact or 1.88) - (ctx.timing.Release or 1.38) - 0.02)

		fx.SpiritCore.SpiritTrail.Enabled = true
		emit(fx.SpiritCore, "CoreCorona", 4)

		local t0 = os.clock()
		ctx.follow = RunService.RenderStepped:Connect(function()
			if not ctx.alive then return end
			local a = math.clamp((os.clock() - t0) / travel, 0, 1)
			local eased = a ^ 1.75
			local pos = startPos:Lerp(endPos, eased)
			fx.Origin.CFrame = CFrame.new(pos)
			fx.SpiritCore.CFrame = CFrame.lookAt(pos, endPos + Vector3.new(0, -0.5, 0))
			fx.SpiritShell.Position = pos
			fx.SpiritOuter.Position = pos
			fx.OrbitRing1.CFrame = CFrame.new(pos) * CFrame.Angles(0.35 + a * 4, a * 9, 0.25)
			fx.OrbitRing2.CFrame = CFrame.new(pos) * CFrame.Angles(-0.35, -a * 11, -0.25 + a * 3)
			if a >= 1 and ctx.follow then
				ctx.follow:Disconnect()
				ctx.follow = nil
			end
		end)
	end,
	Impact = function(ctx)
		local fx = ctx.fx
		if ctx.follow then
			ctx.follow:Disconnect()
			ctx.follow = nil
		end
		local tRoot = rootOf(ctx.target)
		local floorCenter = Vector3.new(tRoot.Position.X, groundY(ctx.target) + 0.08, tRoot.Position.Z)
		local hitPos = floorCenter + Vector3.new(0, 2.2, 0)

		fx.SpiritCore.SpiritTrail.Enabled = false
		tween(fx.Origin:FindFirstChild("SpiritLight"), 0.20, { Brightness = 0 })
		tween(fx.SpiritCore, 0.14, { Size = Vector3.new(8.2, 8.2, 8.2), Transparency = 1 })
		tween(fx.SpiritShell, 0.16, { Size = Vector3.new(11.0, 11.0, 11.0), Transparency = 1 })
		tween(fx.SpiritOuter, 0.16, { Size = Vector3.new(12.2, 12.2, 12.2), Transparency = 1 })
		tweenDisc(fx.OrbitRing1, 0.16, 13.5, 1)
		tweenDisc(fx.OrbitRing2, 0.16, 12.0, 1)

		fx.Hit.CFrame = CFrame.new(hitPos)
		playSfx(fx.Hit, "ImpactSfx")
		impactFrame(0.06, 0.28)
		emit(fx.Hit, "NovaStar", 8)
		emit(fx.Hit, "SpiritShards", 46)
		emit(fx.Hit, "CelestialMist", 30)
		pulseLight(fx.Hit:FindFirstChild("HitLight"), 14, 28)
		shake(0.28, 0.62)

		-- Domo em hemisferio (sem cilindro vertical no impacto)
		fx.SupernovaCore.CFrame = CFrame.new(floorCenter + Vector3.new(0, 1.2, 0))
		fx.SupernovaDome.CFrame = CFrame.new(floorCenter + Vector3.new(0, 1.2, 0))
		fx.SupernovaCore.Size = Vector3.new(3.2, 3.2, 3.2)
		fx.SupernovaDome.Size = Vector3.new(4.6, 4.6, 4.6)
		fx.SupernovaCore.Transparency = 0.02
		fx.SupernovaDome.Transparency = 0.20
		tween(fx.SupernovaCore, 0.45, { Size = Vector3.new(10.5, 9.5, 10.5), Transparency = 1 })
		tween(fx.SupernovaDome, 0.52, { Size = Vector3.new(14.5, 13.0, 14.5), Transparency = 1 })

		setDisc(fx.GroundShock1, CFrame.new(floorCenter), 3.0, 0.02)
		setDisc(fx.GroundShock2, CFrame.new(floorCenter + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0.8, 0), 2.2, 0.08)
		tweenDisc(fx.GroundShock1, 0.48, 18.0, 1)
		tweenDisc(fx.GroundShock2, 0.56, 14.5, 1)
	end,
	Duration = 2.2,
}

-- Combo Marcial (Lutador basico #2 compartilhado): Jab Esquerdo -> Cruzado Direito -> Chute Giratorio 360
-- 100% particulas fluidas + trilhas cineticas + impactos em 3 estagios (zero discos planos ou blocos rigidos)
HANDLERS.ComboMarcial = {
	Charge = function(ctx)
		local fx = ctx.fx
		playSfx(fx.Origin, "ChargeSfx")
		local aRoot = rootOf(ctx.attacker)
		fx.Origin.CFrame = CFrame.new(handPos(ctx.attacker))
		-- Pulso fluido de energia marcial nos punhos e na base
		local function quickBurst(pos: Vector3, tex: string, c1: Color3, c2: Color3, count: number, sMin: number, sMax: number, sz0: number, sz1: number, life: number, stretch: boolean?)
			local anchor = Instance.new("Part")
			anchor.Anchored = true
			anchor.CanCollide = false
			anchor.CanQuery = false
			anchor.CanTouch = false
			anchor.Transparency = 1
			anchor.Size = Vector3.new(0.2, 0.2, 0.2)
			anchor.CFrame = CFrame.new(pos)
			anchor.Parent = fx
			local pe = Instance.new("ParticleEmitter")
			pe.Texture = tex
			pe.Color = ColorSequence.new(c1, c2)
			pe.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, sz0),
				NumberSequenceKeypoint.new(0.4, sz0 * 0.7 + sz1 * 0.3),
				NumberSequenceKeypoint.new(1, sz1),
			})
			pe.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.05),
				NumberSequenceKeypoint.new(0.65, 0.30),
				NumberSequenceKeypoint.new(1, 1),
			})
			pe.Speed = NumberRange.new(sMin, sMax)
			pe.Lifetime = NumberRange.new(life * 0.7, life)
			pe.SpreadAngle = Vector2.new(180, 180)
			pe.LightEmission = 0.95
			pe.Brightness = 2.4
			pe.Drag = 3.2
			if stretch then
				pe.Orientation = Enum.ParticleOrientation.VelocityParallel
				pe.Squash = NumberSequence.new(1.1)
			end
			pe.Rate = 0
			pe.Parent = anchor
			pe:Emit(if lowQuality() then math.max(2, math.floor(count / 2)) else count)
			Debris:AddItem(anchor, life + 0.5)
		end
		ctx._martialBurst = quickBurst
		quickBurst(handPos(ctx.attacker), "rbxassetid://83184852649242", Color3.fromRGB(255, 245, 200), Color3.fromRGB(255, 165, 62), 14, 3, 9, 0.45, 0.05, 0.30, true)
		quickBurst(leftHandPos(ctx.attacker), "rbxassetid://83184852649242", Color3.fromRGB(255, 245, 200), Color3.fromRGB(255, 165, 62), 14, 3, 9, 0.45, 0.05, 0.30, true)
		quickBurst(Vector3.new(aRoot.Position.X, groundY(ctx.attacker) + 0.3, aRoot.Position.Z), "rbxasset://textures/particles/smoke_main.dds", Color3.fromRGB(255, 224, 158), Color3.fromRGB(210, 175, 125), 14, 5, 12, 0.9, 2.2, 0.38, false)
	end,
	Release = function(ctx)
		local fx = ctx.fx
		local hitPos = targetCenter(ctx.target)
		local aPos = rootOf(ctx.attacker).Position
		local look = CFrame.lookAt(hitPos, Vector3.new(aPos.X, hitPos.Y, aPos.Z))
		fx.Hit.CFrame = look
		local burst = ctx._martialBurst

		local function launchStrikeRibbon(fromPos: Vector3, toPos: Vector3, dur: number, curveSide: number, c1: Color3, c2: Color3)
			local anchor = Instance.new("Part")
			anchor.Anchored = true
			anchor.CanCollide = false
			anchor.CanQuery = false
			anchor.CanTouch = false
			anchor.Transparency = 1
			anchor.Size = Vector3.new(0.2, 0.2, 0.2)
			anchor.CFrame = CFrame.new(fromPos)
			anchor.Parent = fx
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(0, 0.45, 0)
			a0.Parent = anchor
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(0, -0.45, 0)
			a1.Parent = anchor
			local tr = Instance.new("Trail")
			tr.Attachment0 = a0
			tr.Attachment1 = a1
			tr.Texture = "rbxassetid://115075243133786"
			tr.Color = ColorSequence.new(c2, c1)
			tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.6, 0.4), NumberSequenceKeypoint.new(1, 1) })
			tr.Lifetime = 0.16
			tr.LightEmission = 0.95
			tr.FaceCamera = true
			tr.Parent = anchor
			local pe = Instance.new("ParticleEmitter")
			pe.Texture = "rbxassetid://83184852649242"
			pe.Color = ColorSequence.new(c2, c1)
			pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.48), NumberSequenceKeypoint.new(1, 0) })
			pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) })
			pe.Speed = NumberRange.new(1, 4)
			pe.Lifetime = NumberRange.new(0.16, 0.28)
			pe.Rate = if lowQuality() then 24 else 48
			pe.LightEmission = 1
			pe.Brightness = 2.6
			pe.Orientation = Enum.ParticleOrientation.VelocityParallel
			pe.Squash = NumberSequence.new(0.9)
			pe.Parent = anchor
			local right = look.RightVector
			local t0 = os.clock()
			local conn
			conn = RunService.RenderStepped:Connect(function()
				if not ctx.alive or not anchor.Parent then conn:Disconnect(); return end
				local a = math.clamp((os.clock() - t0) / dur, 0, 1)
				local p = fromPos:Lerp(toPos, a) + right * (math.sin(a * math.pi) * curveSide) + Vector3.new(0, math.sin(a * math.pi) * 0.55, 0)
				anchor.CFrame = CFrame.new(p)
				if a >= 1 then
					conn:Disconnect()
					pe.Enabled = false
					tr.Enabled = false
					Debris:AddItem(anchor, 0.45)
				end
			end)
		end

		-- Hit 1: Jab Esquerdo (t = 0.00s do Release)
		playSfx(fx.Hit, "ReleaseSfx")
		launchStrikeRibbon(leftHandPos(ctx.attacker), hitPos + Vector3.new(0, 0.3, 0), 0.14, -1.6, Color3.fromRGB(255, 195, 78), Color3.fromRGB(255, 252, 224))
		task.delay(0.10, function()
			if not ctx.alive or not burst then return end
			burst(hitPos + Vector3.new(0, 0.3, 0), "rbxassetid://83184852649242", Color3.fromRGB(255, 250, 215), Color3.fromRGB(255, 178, 62), 20, 8, 22, 0.52, 0.04, 0.28, true)
			emit(fx.Hit, "ImpactSparks", 12)
		end)

		-- Hit 2: Cruzado Direito (t = +0.20s)
		task.delay(0.20, function()
			if not ctx.alive or not alive(ctx.attacker) then return end
			playSfx(fx.Hit, "ReleaseSfx")
			launchStrikeRibbon(handPos(ctx.attacker), hitPos + Vector3.new(0, 0.15, 0), 0.15, 1.9, Color3.fromRGB(255, 138, 46), Color3.fromRGB(255, 245, 200))
			task.delay(0.11, function()
				if not ctx.alive or not burst then return end
				burst(hitPos + Vector3.new(0, 0.15, 0), "rbxassetid://83184852649242", Color3.fromRGB(255, 242, 196), Color3.fromRGB(255, 118, 38), 24, 10, 26, 0.62, 0.05, 0.32, true)
				burst(hitPos, "rbxasset://textures/particles/fire_main.dds", Color3.fromRGB(255, 192, 84), Color3.fromRGB(255, 96, 36), 14, 4, 12, 0.9, 2.2, 0.34, false)
				emit(fx.Hit, "ImpactSparks", 16)
			end)
		end)

		-- Preparo do Chute Giratorio 360 (t = +0.42s)
		task.delay(0.42, function()
			if not ctx.alive or not alive(ctx.attacker) then return end
			launchStrikeRibbon(rootOf(ctx.attacker).Position + Vector3.new(0, 0.5, 0), hitPos + Vector3.new(0, 0.5, 0), 0.16, -2.4, Color3.fromRGB(255, 104, 38), Color3.fromRGB(255, 248, 210))
			launchStrikeRibbon(rootOf(ctx.attacker).Position + Vector3.new(0, 0.3, 0), hitPos + Vector3.new(0, 0.4, 0), 0.16, 2.4, Color3.fromRGB(255, 204, 82), Color3.fromRGB(255, 255, 235))
		end)
	end,
	Impact = function(ctx)
		local fx = ctx.fx
		local hitPos = targetCenter(ctx.target)
		fx.Hit.CFrame = CFrame.new(hitPos)
		CombatAnimator.Hitstop(ctx.attacker, 0.055)
		playSfx(fx.Hit, "ImpactSfx")
		emit(fx.Hit, "ImpactSparks", 28)
		emit(fx.Hit, "DustPuff", 18)
		pulseLight(fx.Hit:FindFirstChild("HitLight"), 6, 16)
		springShake(0.36, 0.26, 46, 12, 1.1)
		fovPunch(-3.0, 0.05, 0.22)
		if ctx._martialBurst then
			ctx._martialBurst(hitPos, "rbxassetid://83184852649242", Color3.fromRGB(255, 252, 224), Color3.fromRGB(255, 128, 42), 34, 12, 32, 0.72, 0.04, 0.38, true)
			ctx._martialBurst(hitPos, "rbxasset://textures/particles/fire_main.dds", Color3.fromRGB(255, 214, 108), Color3.fromRGB(255, 92, 32), 22, 6, 16, 1.1, 3.0, 0.42, false)
			ctx._martialBurst(hitPos, "rbxasset://textures/particles/smoke_main.dds", Color3.fromRGB(255, 228, 178), Color3.fromRGB(190, 155, 120), 16, 6, 15, 1.3, 3.6, 0.48, false)
		end
	end,
	Duration = 1.25,
}

-- Carga de Ki (San, suporte +1 Ataque): postura concentrada com explosao dourada-celeste de aura
HANDLERS.CargaDeKi = {
	Charge = function(ctx)
		local fx = ctx.fx
		playSfx(fx.Origin, "ChargeSfx")
		local aRoot = rootOf(ctx.attacker)
		fx.Origin.CFrame = CFrame.new(aRoot.Position)
		emit(fx.Origin, "GatherKi", 26)
		task.delay(0.32, function()
			if not ctx.alive or not alive(ctx.attacker) then return end
			fx.Origin.CFrame = CFrame.new(rootOf(ctx.attacker).Position)
			emit(fx.Origin, "GatherKi", 26)
		end)
	end,
	Release = function(ctx)
		local fx = ctx.fx
		playSfx(fx.Origin, "ReleaseSfx")
		local aRoot = rootOf(ctx.attacker)
		local gy = groundY(ctx.attacker)
		local floorPos = Vector3.new(aRoot.Position.X, gy + 0.08, aRoot.Position.Z)

		fx.Origin.CFrame = CFrame.new(aRoot.Position)
		emit(fx.Origin, "KiFlames", 34)
		emit(fx.Origin, "KiSparks", 28)
		pulseLight(fx.Origin:FindFirstChild("AuraLight"), 9, 18)
		shake(0.16, 0.28)

		fx.AuraDome.CFrame = CFrame.new(aRoot.Position + Vector3.new(0, 0.4, 0))
		fx.AuraDome.Size = Vector3.new(2.2, 3.4, 2.2)
		fx.AuraDome.Transparency = 0.18
		tween(fx.AuraDome, 0.45, { Size = Vector3.new(6.4, 8.8, 6.4), Transparency = 1 })

		setDisc(fx.GroundShock1, CFrame.new(floorPos), 2.0, 0.05)
		setDisc(fx.GroundShock2, CFrame.new(floorPos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0.6, 0), 1.6, 0.12)
		tweenDisc(fx.GroundShock1, 0.42, 9.8, 1)
		tweenDisc(fx.GroundShock2, 0.50, 7.6, 1)
	end,
	Impact = function(ctx)
		local fx = ctx.fx
		if alive(ctx.attacker) then
			fx.Origin.CFrame = CFrame.new(rootOf(ctx.attacker).Position)
			emit(fx.Origin, "KiFlames", 18)
		end
	end,
	Duration = 1.2,
}

-- Soco Sismico (Barba Branca, Agua especial): bolha Gura-Gura no punho -> estilhaca o proprio ar como vidro!
HANDLERS.SocoSismico = {
	Charge = function(ctx)
		local fx = ctx.fx
		playSfx(fx.Origin, "ChargeSfx")
		local t0 = os.clock()
		local chargeDur = math.max(0.5, (ctx.timing.Release or 1.28) - (ctx.timing.Charge or 0.20))

		fx.QuakeCore.Size = Vector3.new(0.25, 0.25, 0.25)
		fx.QuakeBubble.Size = Vector3.new(0.55, 0.55, 0.55)
		fx.QuakeCore.Transparency = 0.05
		fx.QuakeBubble.Transparency = 0.28
		tween(fx.QuakeCore, chargeDur * 0.85, { Size = Vector3.new(1.25, 1.25, 1.25) }, Enum.EasingStyle.Back)
		tween(fx.QuakeBubble, chargeDur * 0.85, { Size = Vector3.new(2.55, 2.55, 2.55) }, Enum.EasingStyle.Back)
		tween(fx.Origin:FindFirstChild("QuakeLight"), 0.45, { Brightness = 3.8 })

		emit(fx.Origin, "TremorCompress", 24)
		task.delay(chargeDur * 0.5, function()
			if not ctx.alive then return end
			emit(fx.Origin, "TremorCompress", 26)
		end)

		ctx.follow = RunService.RenderStepped:Connect(function()
			if not ctx.alive or not alive(ctx.attacker) then return end
			local p = handPos(ctx.attacker)
			local vib = Vector3.new((math.random() - 0.5) * 0.14, (math.random() - 0.5) * 0.14, (math.random() - 0.5) * 0.14)
			local pulse = 1 + math.sin((os.clock() - t0) * 32) * 0.09
			fx.Origin.CFrame = CFrame.new(p)
			fx.QuakeCore.Position = p + vib * 0.5
			fx.QuakeBubble.Position = p + vib
			fx.QuakeBubble.Size = fx.QuakeCore.Size * (2.05 * pulse)
		end)
	end,
	Release = function(ctx)
		local fx = ctx.fx
		if ctx.follow then
			ctx.follow:Disconnect()
			ctx.follow = nil
		end
		playSfx(fx.Origin, "ReleaseSfx")

		local aRoot = rootOf(ctx.attacker)
		local endPos = targetCenter(ctx.target)
		local punchPos = handPos(ctx.attacker)
		local dir = (endPos - punchPos)
		dir = if dir.Magnitude > 0.05 then dir.Unit else aRoot.CFrame.LookVector
		local crackPos = punchPos + dir * 1.15
		local crackLook = CFrame.lookAt(crackPos, endPos)

		-- Bolha explode no punho ao rachar o ar!
		tween(fx.QuakeCore, 0.14, { Size = Vector3.new(3.0, 3.0, 3.0), Transparency = 1 })
		tween(fx.QuakeBubble, 0.16, { Size = Vector3.new(4.8, 4.8, 4.8), Transparency = 1 })
		fx.Origin.CFrame = CFrame.new(crackPos)
		emit(fx.Origin, "CrackSparks", 34)
		pulseLight(fx.Origin:FindFirstChild("QuakeLight"), 9, 20)
		shake(0.20, 0.42)

		-- Rachadura de vidro gigante aberta em pleno ar!
		setDisc(fx.AirCrackMain, crackLook * CFrame.Angles(math.pi / 2, 0, 0.18), 1.8, 0)
		setDisc(fx.AirCrackCross, crackLook * CFrame.Angles(math.pi / 2, 0.55, -0.35), 1.5, 0.08)
		tween(fx.AirCrackMain, 0.08, { Size = Vector3.new(9.2, 0.05, 9.2) }, Enum.EasingStyle.Back)
		tween(fx.AirCrackCross, 0.10, { Size = Vector3.new(7.6, 0.05, 7.6) }, Enum.EasingStyle.Back)
		task.delay(0.45, function()
			tweenDisc(fx.AirCrackMain, 0.35, 10.4, 1)
			tweenDisc(fx.AirCrackCross, 0.35, 8.6, 1)
		end)

		-- Ondas de pressao sismica disparando ate o alvo
		local travel = math.max(0.14, (ctx.timing.Impact or 1.48) - (ctx.timing.Release or 1.28))
		for i, wName in ipairs({ "PressureWave1", "PressureWave2" }) do
			local wave = fx[wName]
			task.delay((i - 1) * 0.06, function()
				if not ctx.alive then return end
				setDisc(wave, crackLook * CFrame.Angles(math.pi / 2, 0, 0), 3.0, 0.08)
				tween(wave, travel, {
					CFrame = CFrame.lookAt(endPos, endPos + dir) * CFrame.Angles(math.pi / 2, 0, 0),
					Size = Vector3.new(8.5, 0.05, 8.5),
				})
				for _, d in wave:GetChildren() do
					if d:IsA("Decal") then tween(d, travel + 0.1, { Transparency = 1 }) end
				end
			end)
		end
	end,
	Impact = function(ctx)
		local fx = ctx.fx
		local hitPos = targetCenter(ctx.target)
		local aPos = rootOf(ctx.attacker).Position
		local hitLook = CFrame.lookAt(hitPos, Vector3.new(aPos.X, hitPos.Y, aPos.Z))

		fx.Hit.CFrame = CFrame.new(hitPos)
		playSfx(fx.Hit, "ImpactSfx")
		impactFrame(0.05, 0.22)
		emit(fx.Hit, "ShatterBurst", 6)
		emit(fx.Hit, "QuakeShards", 38)
		emit(fx.Hit, "SeaMist", 24)
		pulseLight(fx.Hit:FindFirstChild("HitLight"), 11, 24)
		shake(0.26, 0.56)

		setDisc(fx.ImpactCrack, hitLook * CFrame.Angles(math.pi / 2, 0, -0.22), 2.4, 0)
		tween(fx.ImpactCrack, 0.09, { Size = Vector3.new(10.2, 0.05, 10.2) }, Enum.EasingStyle.Back)
		task.delay(0.32, function()
			tweenDisc(fx.ImpactCrack, 0.30, 11.8, 1)
		end)

		fx.HitDome.CFrame = CFrame.new(hitPos)
		fx.HitDome.Size = Vector3.new(2.2, 2.2, 2.2)
		fx.HitDome.Transparency = 0.20
		tween(fx.HitDome, 0.36, { Size = Vector3.new(9.6, 9.6, 9.6), Transparency = 1 })

		setDisc(fx.HitShockRing, CFrame.new(hitPos) * CFrame.Angles(0.25, 0, 0.18), 2.6, 0.05)
		tweenDisc(fx.HitShockRing, 0.42, 14.0, 1)
	end,
	Duration = 1.9,
}

-- Abalo do Ceu e da Terra (Barba Branca, Agua assinatura suprema): agarra o ar com as duas maos, inclina o mundo e ergue maremoto!
HANDLERS.CeuETerra = {
	Charge = function(ctx)
		local fx = ctx.fx
		playSfx(fx.Origin, "ChargeSfx")
		local aRoot = rootOf(ctx.attacker)
		local gy = groundY(ctx.attacker)
		local chargeDur = math.max(0.6, (ctx.timing.Release or 1.38) - (ctx.timing.Charge or 0.28))

		fx.Ground.CFrame = CFrame.new(aRoot.Position.X, gy + 0.1, aRoot.Position.Z)
		emit(fx.Ground, "SeaSpray", 18)
		task.delay(chargeDur * 0.5, function()
			if not ctx.alive then return end
			emit(fx.Ground, "SeaSpray", 20)
		end)

		for _, side in ipairs({ "Left", "Right" }) do
			local core = fx[side .. "Core"]
			local bub = fx[side .. "Bubble"]
			local crk = fx[side .. "SkyCrack"]
			core.Size = Vector3.new(0.3, 0.3, 0.3); core.Transparency = 0.04
			bub.Size = Vector3.new(0.6, 0.6, 0.6); bub.Transparency = 0.26
			tween(core, chargeDur * 0.75, { Size = Vector3.new(1.3, 1.3, 1.3) }, Enum.EasingStyle.Back)
			tween(bub, chargeDur * 0.75, { Size = Vector3.new(2.6, 2.6, 2.6) }, Enum.EasingStyle.Back)
			setDisc(crk, CFrame.new(aRoot.Position), 1.2, 0.05)
			tween(crk, chargeDur * 0.75, { Size = Vector3.new(6.8, 0.05, 6.8) }, Enum.EasingStyle.Back)
		end
		tween(fx.Origin:FindFirstChild("QuakeLight"), 0.5, { Brightness = 4.2 })

		local t0 = os.clock()
		ctx.follow = RunService.RenderStepped:Connect(function()
			if not ctx.alive or not alive(ctx.attacker) then return end
			local r = rootOf(ctx.attacker)
			local lp = leftHandPos(ctx.attacker)
			local rp = handPos(ctx.attacker)
			local pulse = 1 + math.sin((os.clock() - t0) * 28) * 0.08
			fx.Origin.CFrame = CFrame.new(r.Position + Vector3.new(0, 1.5, 0))
			fx.LeftCore.Position = lp
			fx.LeftBubble.Position = lp
			fx.LeftBubble.Size = fx.LeftCore.Size * (2.0 * pulse)
			fx.LeftSkyCrack.CFrame = CFrame.lookAt(lp, lp + r.CFrame.LookVector) * CFrame.Angles(math.pi / 2, 0, 0.25)

			fx.RightCore.Position = rp
			fx.RightBubble.Position = rp
			fx.RightBubble.Size = fx.RightCore.Size * (2.0 * pulse)
			fx.RightSkyCrack.CFrame = CFrame.lookAt(rp, rp + r.CFrame.LookVector) * CFrame.Angles(math.pi / 2, 0, -0.25)
		end)
	end,
	Release = function(ctx)
		local fx = ctx.fx
		if ctx.follow then
			ctx.follow:Disconnect()
			ctx.follow = nil
		end
		playSfx(fx.Origin, "ReleaseSfx")

		for _, side in ipairs({ "Left", "Right" }) do
			tween(fx[side .. "Core"], 0.18, { Size = Vector3.new(2.8, 2.8, 2.8), Transparency = 1 })
			tween(fx[side .. "Bubble"], 0.20, { Size = Vector3.new(4.6, 4.6, 4.6), Transparency = 1 })
			tweenDisc(fx[side .. "SkyCrack"], 0.28, 8.8, 1)
		end
		tween(fx.Origin:FindFirstChild("QuakeLight"), 0.25, { Brightness = 0 })

		-- Inclina brevemente o horizonte da camera (como Marineford inclinando!)
		local cam = workspace.CurrentCamera
		if cam and cam.CameraType == Enum.CameraType.Scriptable and not lowQuality() then
			for _, t in activeTiltTweens do
				t:Cancel()
			end
			table.clear(activeTiltTweens)
			ensureCamDriver()
			local tt1 = tween(camTiltValue, 0.16, { Value = 6.5 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			table.insert(activeTiltTweens, tt1)
			task.delay(0.32, function()
				if cam.CameraType == Enum.CameraType.Scriptable then
					local tt2 = tween(camTiltValue, 0.24, { Value = 0 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
					table.insert(activeTiltTweens, tt2)
				end
			end)
		end

		local aRoot, tRoot = rootOf(ctx.attacker), rootOf(ctx.target)
		local gy = groundY(ctx.attacker)
		local sFloor = Vector3.new(aRoot.Position.X, gy + 0.08, aRoot.Position.Z)
		local eFloor = Vector3.new(tRoot.Position.X, groundY(ctx.target) + 0.08, tRoot.Position.Z)
		local midFloor = (sFloor + eFloor) * 0.5
		local dist = math.max(4, (eFloor - sFloor).Magnitude)
		local dir = (eFloor - sFloor).Unit
		local right = dir:Cross(Vector3.yAxis)
		local travel = math.max(0.20, (ctx.timing.Impact or 1.72) - (ctx.timing.Release or 1.38))

		-- Fenda tectonica abrindo no chao ate o inimigo
		setDisc(fx.FaultFissure, CFrame.lookAt(midFloor, eFloor), 2.0, 0.02)
		fx.FaultFissure.Size = Vector3.new(3.5, 0.05, 2.0)
		tween(fx.FaultFissure, travel * 0.85, { Size = Vector3.new(7.5, 0.05, dist + 4) })
		task.delay(travel + 0.45, function()
			for _, d in fx.FaultFissure:GetChildren() do
				if d:IsA("Decal") then tween(d, 0.35, { Transparency = 1 }) end
			end
		end)

		-- Duas muralhas de maremoto correndo pelas laterais da fenda!
		for idx, wName in ipairs({ "TsunamiWaveL", "TsunamiWaveR" }) do
			local sgn = if idx == 1 then -1 else 1
			local wave = fx[wName]
			local wStart = sFloor + right * (sgn * 3.8) + Vector3.new(0, 2.4, 0)
			local wEnd = eFloor + right * (sgn * 1.6) + Vector3.new(0, 3.2, 0)
			setDisc(wave, CFrame.lookAt(wStart, wEnd) * CFrame.Angles(math.rad(65), 0, math.rad(sgn * -35)), 6.5, 0.08)
			tween(wave, travel, {
				CFrame = CFrame.lookAt(wEnd, wEnd + dir) * CFrame.Angles(math.rad(65), 0, math.rad(sgn * -20)),
				Size = Vector3.new(10.5, 0.05, 10.5),
			})
			task.delay(travel, function()
				tweenDisc(wave, 0.22, 12.0, 1)
			end)
		end
		shake(0.22, 0.38)
	end,
	Impact = function(ctx)
		local fx = ctx.fx
		local tRoot = rootOf(ctx.target)
		local floorCenter = Vector3.new(tRoot.Position.X, groundY(ctx.target) + 0.09, tRoot.Position.Z)
		local hitPos = floorCenter + Vector3.new(0, 2.2, 0)

		fx.Hit.CFrame = CFrame.new(hitPos)
		playSfx(fx.Hit, "ImpactSfx")
		impactFrame(0.06, 0.28)
		emit(fx.Hit, "CrackFlash", 8)
		emit(fx.Hit, "EruptShards", 46)
		emit(fx.Hit, "GeyserMist", 32)
		pulseLight(fx.Hit:FindFirstChild("HitLight"), 14, 30)
		shake(0.30, 0.68)

		-- Cratera sismica + geiser oceanico sob o inimigo!
		setDisc(fx.CraterCrack1, CFrame.new(floorCenter), 3.0, 0)
		setDisc(fx.CraterCrack2, CFrame.new(floorCenter + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0.9, 0), 2.8, 0.05)
		tween(fx.CraterCrack1, 0.12, { Size = Vector3.new(14.5, 0.05, 14.5) }, Enum.EasingStyle.Back)
		tween(fx.CraterCrack2, 0.14, { Size = Vector3.new(13.0, 0.05, 13.0) }, Enum.EasingStyle.Back)
		task.delay(0.55, function()
			tweenDisc(fx.CraterCrack1, 0.40, 16.0, 1)
			tweenDisc(fx.CraterCrack2, 0.40, 14.5, 1)
		end)

		fx.QuakeGeyserShell.CFrame = CFrame.new(floorCenter + Vector3.new(0, 1.5, 0))
		fx.QuakeGeyserShell.Size = Vector3.new(4.2, 4.2, 4.2)
		fx.QuakeGeyserShell.Transparency = 0.18
		tween(fx.QuakeGeyserShell, 0.50, { Size = Vector3.new(15.0, 13.5, 15.0), Transparency = 1 })

		setDisc(fx.MegaShock1, CFrame.new(floorCenter + Vector3.new(0, 0.12, 0)), 3.2, 0.02)
		setDisc(fx.MegaShock2, CFrame.new(hitPos) * CFrame.Angles(0.22, 0.5, -0.18), 2.5, 0.08)
		tweenDisc(fx.MegaShock1, 0.48, 19.0, 1)
		tweenDisc(fx.MegaShock2, 0.54, 15.0, 1)
	end,
	Duration = 2.2,
}

-- Corte Murakumo (Barba Branca, Neutro): bisento revestido de terremoto dispara onda crescente cortante!
local function setBackBisentoHidden(model: Model?, hidden: boolean)
	local mf = model and model:FindFirstChild("Marineford3D")
	local backB = mf and mf:FindFirstChild("Murakumogiri_Acc")
	if not backB then
		return
	end
	for _, p in ipairs(backB:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "Bisento_Anchor" then
			p.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

HANDLERS.CorteMurakumo = {
	Charge = function(ctx)
		local fx = ctx.fx
		setBackBisentoHidden(ctx.attacker, true)
		ctx.onCleanup = function()
			setBackBisentoHidden(ctx.attacker, false)
		end
		playSfx(fx.Origin, "ChargeSfx")
		tween(fx.Origin:FindFirstChild("BladeLight"), 0.25, { Brightness = 4 })
		emit(fx.Origin, "BladeGather", 22)

		fx.BisentoShaft.Transparency = 0.05
		fx.BisentoBlade.Transparency = 0.02
		fx.BladeQuakeOrb.Transparency = 0.28
		fx.BladeQuakeOrb.Size = Vector3.new(0.6, 0.6, 0.6)
		tween(fx.BladeQuakeOrb, 0.35, { Size = Vector3.new(2.4, 2.4, 2.4) }, Enum.EasingStyle.Back)

		ctx.follow = RunService.RenderStepped:Connect(function()
			if not ctx.alive or not alive(ctx.attacker) then return end
			local lp = leftHandPos(ctx.attacker)
			local rp = handPos(ctx.attacker)
			local mid = (lp + rp) * 0.5
			local axis = (lp - rp)
			axis = if axis.Magnitude > 0.1 then axis.Unit else rootOf(ctx.attacker).CFrame.RightVector
			local bladePos = mid + axis * 3.2
			fx.Origin.CFrame = CFrame.new(bladePos)
			fx.BisentoShaft.CFrame = CFrame.lookAt(mid, bladePos) * CFrame.Angles(0, math.pi / 2, 0)
			fx.BisentoBlade.CFrame = CFrame.lookAt(bladePos, bladePos + axis)
			fx.BladeQuakeOrb.Position = bladePos
		end)
	end,
	Release = function(ctx)
		local fx = ctx.fx
		if ctx.follow then
			ctx.follow:Disconnect()
			ctx.follow = nil
		end
		playSfx(fx.Origin, "ReleaseSfx")
		tween(fx.BisentoShaft, 0.18, { Transparency = 1 })
		tween(fx.BisentoBlade, 0.18, { Transparency = 1 })
		tween(fx.BladeQuakeOrb, 0.18, { Size = Vector3.new(3.6, 3.6, 3.6), Transparency = 1 })
		tween(fx.Origin:FindFirstChild("BladeLight"), 0.2, { Brightness = 0 })

		local aRoot = rootOf(ctx.attacker)
		local startPos = aRoot.CFrame:PointToWorldSpace(Vector3.new(0, 0.6, -2.4))
		local endPos = targetCenter(ctx.target)
		local travel = math.max(0.16, (ctx.timing.Impact or 1.15) - (ctx.timing.Release or 0.85))
		local lookCF = CFrame.lookAt(startPos, endPos)

		setDisc(fx.SlashWave, lookCF * CFrame.Angles(0, 0, math.rad(-14)), 5.8, 0.02)
		setDisc(fx.SlashWake, lookCF * CFrame.Angles(0, 0, math.rad(14)), 4.8, 0.16)
		fx.SlashWave.SlashTrail.Enabled = true

		local t0 = os.clock()
		ctx.follow = RunService.RenderStepped:Connect(function()
			if not ctx.alive then return end
			local a = math.clamp((os.clock() - t0) / travel, 0, 1)
			local pos = startPos:Lerp(endPos, a)
			local cf = CFrame.lookAt(pos, pos + lookCF.LookVector)
			fx.SlashWave.CFrame = cf * CFrame.Angles(0, 0, math.rad(-14))
			fx.SlashWake.CFrame = cf * CFrame.new(0, 0, 1.1) * CFrame.Angles(0, 0, math.rad(14))
			local sz = 5.8 + a * 2.8
			fx.SlashWave.Size = Vector3.new(sz, 0.05, sz)
			fx.SlashWake.Size = Vector3.new(sz * 0.85, 0.05, sz * 0.85)
			if a >= 1 and ctx.follow then
				ctx.follow:Disconnect()
				ctx.follow = nil
			end
		end)
	end,
	Impact = function(ctx)
		local fx = ctx.fx
		if ctx.follow then
			ctx.follow:Disconnect()
			ctx.follow = nil
		end
		local hitPos = targetCenter(ctx.target)
		fx.SlashWave.SlashTrail.Enabled = false
		tweenDisc(fx.SlashWave, 0.14, 10.2, 1)
		tweenDisc(fx.SlashWake, 0.14, 8.8, 1)

		fx.Hit.CFrame = CFrame.new(hitPos)
		playSfx(fx.Hit, "ImpactSfx")
		emit(fx.Hit, "SlashStar", 6)
		emit(fx.Hit, "CutSparks", 28)
		pulseLight(fx.Hit:FindFirstChild("HitLight"), 9, 18)
		shake(0.18, 0.38)

		fx.SlashCut.CFrame = CFrame.new(hitPos) * CFrame.Angles(0, 0, math.rad(68))
		fx.SlashCut.Size = Vector3.new(0.24, 0.6, 0.24)
		fx.SlashCut.Transparency = 0
		tween(fx.SlashCut, 0.10, { Size = Vector3.new(0.28, 7.2, 0.28) })
		task.delay(0.12, function()
			tween(fx.SlashCut, 0.22, { Size = Vector3.new(0.06, 8.4, 0.06), Transparency = 1 })
		end)

		setDisc(fx.HitShock, CFrame.new(hitPos) * CFrame.Angles(0.2, 0, -0.25), 2.0, 0.05)
		tweenDisc(fx.HitShock, 0.34, 10.5, 1)
	end,
	Duration = 1.3,
}

-- Haki do Conquistador (Barba Branca, suporte +1 Ataque): relampagos rubro-negros imperiais e pressao esmagadora!
HANDLERS.HakiDoConquistador = {
	Charge = function(ctx)
		local fx = ctx.fx
		playSfx(fx.Origin, "ChargeSfx")
		local aRoot = rootOf(ctx.attacker)
		fx.Origin.CFrame = CFrame.new(aRoot.Position)
		emit(fx.Origin, "DarkFlames", 18)
		emit(fx.Origin, "HakiBolts", 6)
	end,
	Release = function(ctx)
		local fx = ctx.fx
		playSfx(fx.Origin, "ReleaseSfx")
		local aRoot = rootOf(ctx.attacker)
		local gy = groundY(ctx.attacker)
		local floorPos = Vector3.new(aRoot.Position.X, gy + 0.08, aRoot.Position.Z)

		fx.Origin.CFrame = CFrame.new(aRoot.Position)
		emit(fx.Origin, "HakiBolts", 14)
		emit(fx.Origin, "DarkFlames", 28)
		emit(fx.Origin, "CrimsonSparks", 32)
		pulseLight(fx.Origin:FindFirstChild("HakiLight"), 10, 22)
		impactFrame(0.04, 0.18)
		shake(0.22, 0.44)

		fx.ConquerorDome.CFrame = CFrame.new(aRoot.Position + Vector3.new(0, 0.5, 0))
		fx.ConquerorDome.Size = Vector3.new(2.6, 2.6, 2.6)
		fx.ConquerorDome.Transparency = 0.16
		tween(fx.ConquerorDome, 0.48, { Size = Vector3.new(12.0, 10.5, 12.0), Transparency = 1 })

		-- 4 relampagos 3D rubro-negros saltando em volta do Barba Branca
		for i = 1, 4 do
			local bolt = fx["BoltArc" .. i]
			local ang = (i - 0.5) * (math.pi * 0.5)
			local bPos = floorPos + Vector3.new(math.cos(ang) * 3.0, 3.8, math.sin(ang) * 3.0)
			setDisc(bolt, CFrame.lookAt(bPos, aRoot.Position + Vector3.new(0, 3.8, 0)) * CFrame.Angles(math.pi / 2, 0, math.rad((i % 2 == 0 and 18 or -18))), 4.5, 0)
			tween(bolt, 0.14, { Size = Vector3.new(7.2, 0.05, 7.2) })
			task.delay(0.18, function()
				tweenDisc(bolt, 0.24, 8.2, 1)
			end)
		end

		setDisc(fx.HakiRing1, CFrame.new(floorPos), 2.4, 0.02)
		setDisc(fx.HakiRing2, CFrame.new(floorPos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0.7, 0), 1.8, 0.08)
		tweenDisc(fx.HakiRing1, 0.46, 15.0, 1)
		tweenDisc(fx.HakiRing2, 0.54, 12.0, 1)
	end,
	Impact = function(ctx)
		local fx = ctx.fx
		if alive(ctx.attacker) then
			fx.Origin.CFrame = CFrame.new(rootOf(ctx.attacker).Position)
			emit(fx.Origin, "HakiBolts", 8)
		end
	end,
	Duration = 1.4,
}

--------------------------------------------------------------------
-- Golpes Basicos Compartilhados: ESPADACHIM (identicos para todos os Espadachins)
--------------------------------------------------------------------

-- Corte Rapido (Espadachim basico #1): brilho metalico na lamina -> onda crescente diagonal -> rasgo cel + faiscas
HANDLERS.CorteBasico = {
	Charge = function(ctx)
		local fx = ctx.fx
		playSfx(fx.Origin, "ChargeSfx")
		local hp = handPos(ctx.attacker)
		fx.Origin.CFrame = CFrame.new(hp)
		emit(fx.Origin, "DrawGlint", 5)
		emit(fx.Origin, "SteelGather", 12)
		pulseLight(fx.Origin:FindFirstChild("DrawLight"), 2.4, 9)
	end,
	Release = function(ctx)
		local fx = ctx.fx
		playSfx(fx.Origin, "ReleaseSfx")
		local aRoot = rootOf(ctx.attacker)
		local startPos = aRoot.CFrame:PointToWorldSpace(Vector3.new(0.4, 0.7, -2.0))
		local endPos = targetCenter(ctx.target)
		local lookCF = CFrame.lookAt(startPos, endPos)
		local travel = math.max(0.09, (ctx.timing.Impact or 0.38) - (ctx.timing.Release or 0.28))

		setDisc(fx.SlashArc, lookCF * CFrame.Angles(0, 0, math.rad(-28)), 4.6, 0.02)
		fx.SlashArc.SlashTrail.Enabled = true

		-- Dois riscos de vento cel acompanhando o corte
		for i = 1, 2 do
			local ws = fx["WindStreak" .. i]
			local offX = if i == 1 then -0.8 else 0.8
			local offY = if i == 1 then 0.5 else -0.4
			ws.CFrame = lookCF * CFrame.new(offX, offY, -0.4)
			ws.Size = Vector3.new(0.10, 0.10, 0.8)
			ws.Transparency = 0.12
			tween(ws, travel + 0.06, {
				CFrame = CFrame.lookAt(endPos, endPos + lookCF.LookVector) * CFrame.new(offX * 0.4, offY * 0.4, 0.6),
				Size = Vector3.new(0.05, 0.05, 4.4),
				Transparency = 1,
			})
		end

		local t0 = os.clock()
		ctx.follow = RunService.RenderStepped:Connect(function()
			if not ctx.alive then return end
			local a = math.clamp((os.clock() - t0) / travel, 0, 1)
			local eased = 1 - (1 - a) * (1 - a)
			local pos = startPos:Lerp(endPos, eased)
			local cf = CFrame.lookAt(pos, pos + lookCF.LookVector)
			fx.SlashArc.CFrame = cf * CFrame.Angles(0, 0, math.rad(-28))
			local sz = 4.6 + eased * 2.4
			fx.SlashArc.Size = Vector3.new(sz, 0.05, sz)
			if a >= 1 and ctx.follow then
				ctx.follow:Disconnect()
				ctx.follow = nil
			end
		end)
	end,
	Impact = function(ctx)
		local fx = ctx.fx
		if ctx.follow then
			ctx.follow:Disconnect()
			ctx.follow = nil
		end
		local hitPos = targetCenter(ctx.target)
		local aPos = rootOf(ctx.attacker).Position
		local hitLook = CFrame.lookAt(hitPos, Vector3.new(aPos.X, hitPos.Y, aPos.Z))

		fx.SlashArc.SlashTrail.Enabled = false
		tweenDisc(fx.SlashArc, 0.12, 8.2, 1)

		fx.Hit.CFrame = hitLook
		playSfx(fx.Hit, "ImpactSfx")
		CombatAnimator.Hitstop(ctx.attacker, 0.045)
		emit(fx.Hit, "SlashStar", 4)
		emit(fx.Hit, "SteelSparks", 24)
		emit(fx.Hit, "HitDust", 12)
		pulseLight(fx.Hit:FindFirstChild("HitLight"), 3.4, 14)
		springShake(0.28, 0.24, 46, 13, 0.8)

		-- Rasgo neon diagonal limpo atravessando o inimigo
		fx.SlashMark.CFrame = hitLook * CFrame.new(0, 0.1, -0.7) * CFrame.Angles(0, 0, math.rad(42))
		fx.SlashMark.Size = Vector3.new(0.22, 0.5, 0.12)
		fx.SlashMark.Transparency = 0
		tween(fx.SlashMark, 0.07, { Size = Vector3.new(0.24, 6.2, 0.12) }, Enum.EasingStyle.Exponential)
		task.delay(0.09, function()
			tween(fx.SlashMark, 0.18, { Size = Vector3.new(0.04, 7.2, 0.05), Transparency = 1 })
		end)

		setDisc(fx.HitShock, hitLook * CFrame.Angles(math.pi / 2, 0, math.rad(22)), 1.4, 0.06)
		tweenDisc(fx.HitShock, 0.28, 7.6, 1)
	end,
	Duration = 0.95,
}

-- Corte Cruzado (Espadachim basico #2): dois cortes diagonais rapidos formando um X luminoso com impacto cruzado!
HANDLERS.CorteCruzado = {
	Charge = function(ctx)
		local fx = ctx.fx
		playSfx(fx.Origin, "ChargeSfx")
		local hp = handPos(ctx.attacker)
		fx.Origin.CFrame = CFrame.new(hp)
		emit(fx.Origin, "BladeCharge", 18)
		emit(fx.Origin, "DrawGlint", 5)
		pulseLight(fx.Origin:FindFirstChild("ChargeLight"), 3.0, 11)
	end,
	Release = function(ctx)
		local fx = ctx.fx
		local aRoot = rootOf(ctx.attacker)
		local startPos = aRoot.CFrame:PointToWorldSpace(Vector3.new(0, 0.65, -2.0))
		local endPos = targetCenter(ctx.target)
		local lookCF = CFrame.lookAt(startPos, endPos)
		local totalSpan = math.max(0.24, (ctx.timing.Impact or 0.62) - (ctx.timing.Release or 0.34))
		local flight = math.max(0.11, totalSpan * 0.56)

		local function launchWave(part: BasePart, rollDeg: number, delayT: number)
			task.delay(delayT, function()
				if not ctx.alive then return end
				playSfx(fx.Origin, "ReleaseSfx")
				setDisc(part, lookCF * CFrame.Angles(0, 0, math.rad(rollDeg)), 4.8, 0.02)
				local tr = part:FindFirstChild("SlashTrail")
				if tr and tr:IsA("Trail") then
					tr.Enabled = true
				end
				local t0 = os.clock()
				local conn
				conn = RunService.RenderStepped:Connect(function()
					if not ctx.alive then
						conn:Disconnect()
						return
					end
					local a = math.clamp((os.clock() - t0) / flight, 0, 1)
					local eased = 1 - (1 - a) * (1 - a)
					local pos = startPos:Lerp(endPos, eased)
					part.CFrame = CFrame.lookAt(pos, pos + lookCF.LookVector) * CFrame.Angles(0, 0, math.rad(rollDeg))
					local sz = 4.8 + eased * 2.8
					part.Size = Vector3.new(sz, 0.05, sz)
					if a >= 1 then
						conn:Disconnect()
						if tr and tr:IsA("Trail") then
							tr.Enabled = false
						end
						tweenDisc(part, 0.12, 8.8, 1)
					end
				end)
			end)
		end

		launchWave(fx.SlashArcA, -38, 0)
		launchWave(fx.SlashArcB, 38, totalSpan * 0.42)
	end,
	Impact = function(ctx)
		local fx = ctx.fx
		local hitPos = targetCenter(ctx.target)
		local aPos = rootOf(ctx.attacker).Position
		local hitLook = CFrame.lookAt(hitPos, Vector3.new(aPos.X, hitPos.Y, aPos.Z))

		fx.Hit.CFrame = hitLook
		playSfx(fx.Hit, "ImpactSfx")
		CombatAnimator.Hitstop(ctx.attacker, 0.055)
		animeImpactFrame(Color3.fromRGB(220, 245, 255), 0.035, 0.16, false)
		fovPunch(-3.4, 0.05, 0.22)
		springShake(0.42, 0.30, 44, 11, 1.3)

		emit(fx.Hit, "CrossStar", 6)
		emit(fx.Hit, "CrossSparks", 32)
		emit(fx.Hit, "VaporDust", 16)
		pulseLight(fx.Hit:FindFirstChild("HitLight"), 3.9, 17)

		-- X luminoso cravado no alvo!
		for i, cutInfo in ipairs({ { fx.CutA, 42 }, { fx.CutB, -42 } }) do
			local cutPart: BasePart = cutInfo[1]
			local ang: number = cutInfo[2]
			cutPart.CFrame = hitLook * CFrame.new(0, 0.15, -0.75) * CFrame.Angles(0, 0, math.rad(ang))
			cutPart.Size = Vector3.new(0.26, 0.6, 0.14)
			cutPart.Transparency = 0
			tween(cutPart, 0.075, { Size = Vector3.new(0.28, 7.2, 0.14) }, Enum.EasingStyle.Exponential)
			task.delay(0.11 + (i - 1) * 0.02, function()
				tween(cutPart, 0.22, { Size = Vector3.new(0.04, 8.4, 0.05), Transparency = 1 })
			end)
		end

		setDisc(fx.HitShock1, hitLook * CFrame.Angles(math.pi / 2, 0, 0.25), 1.8, 0.04)
		setDisc(fx.HitShock2, hitLook * CFrame.Angles(math.pi / 2, 0.4, -0.35), 1.4, 0.08)
		tweenDisc(fx.HitShock1, 0.32, 9.8, 1)
		tweenDisc(fx.HitShock2, 0.38, 8.0, 1)
	end,
	Duration = 1.15,
}

--------------------------------------------------------------------
-- Tecnicas Assinatura do Byakuya Kuchiki (Bleach)
--------------------------------------------------------------------

-- Senbonzakura (Shikai): lamina se desfaz em mil petalas luminosas que correm em fita espiral e retalham o alvo!
HANDLERS.Senbonzakura = {
	Charge = function(ctx)
		local fx = ctx.fx
		playSfx(fx.Origin, "ChargeSfx")
		local hp = handPos(ctx.attacker) + Vector3.new(0, 1.0, 0)
		fx.Origin.CFrame = CFrame.new(hp)
		setDisc(fx.DisperseRing, CFrame.new(hp) * CFrame.Angles(0.2, 0, 0.15), 0.9, 0.05)
		tweenDisc(fx.DisperseRing, 0.45, 5.2, 1)
		emit(fx.Origin, "PetalBurstOrigin", 26)
		emit(fx.Origin, "BladeGlints", 12)
		pulseLight(fx.Origin:FindFirstChild("OriginLight"), 3.2, 13)

		-- Mantem a nuvem de petalas acompanhando a mao durante a dissolucao
		ctx.follow = RunService.RenderStepped:Connect(function()
			if not ctx.alive or not alive(ctx.attacker) then return end
			fx.Origin.CFrame = CFrame.new(handPos(ctx.attacker) + Vector3.new(0, 0.6, 0))
		end)
		task.delay(0.22, function()
			if not ctx.alive then return end
			emit(fx.Origin, "PetalBurstOrigin", 20)
		end)
	end,
	Release = function(ctx)
		local fx = ctx.fx
		if ctx.follow then
			ctx.follow:Disconnect()
			ctx.follow = nil
		end
		playSfx(fx.Origin, "ReleaseSfx")

		local startPos = handPos(ctx.attacker) + Vector3.new(0, 0.4, 0)
		local endPos = targetCenter(ctx.target)
		local lookCF = CFrame.lookAt(startPos, endPos)
		local right = lookCF.RightVector
		local travel = math.max(0.20, (ctx.timing.Impact or 1.08) - (ctx.timing.Release or 0.68))

		fx.StreamStart.CFrame = lookCF
		fx.StreamHead.CFrame = lookCF
		fx.StreamStart.SakuraRibbonCore.Enabled = true
		fx.StreamStart.SakuraRibbonOuter.Enabled = true
		fx.StreamHead.StreamPetals.Enabled = true
		fx.StreamHead.StreamGlints.Enabled = true

		local t0 = os.clock()
		ctx.follow = RunService.RenderStepped:Connect(function()
			if not ctx.alive then return end
			local a = math.clamp((os.clock() - t0) / travel, 0, 1)
			local eased = 1 - (1 - a) * (1 - a)
			-- Curva graciosa em S das petalas da Senbonzakura!
			local arcX = math.sin(a * math.pi) * 2.6
			local arcY = math.sin(a * math.pi) * 1.4
			local pos = startPos:Lerp(endPos, eased) + right * arcX + Vector3.new(0, arcY, 0)
			fx.StreamHead.CFrame = CFrame.lookAt(pos, endPos + Vector3.new(0, 0.2, 0))
			if a >= 1 and ctx.follow then
				ctx.follow:Disconnect()
				ctx.follow = nil
			end
		end)
	end,
	Impact = function(ctx)
		local fx = ctx.fx
		if ctx.follow then
			ctx.follow:Disconnect()
			ctx.follow = nil
		end
		local hitPos = targetCenter(ctx.target)
		local aPos = rootOf(ctx.attacker).Position
		local hitLook = CFrame.lookAt(hitPos, Vector3.new(aPos.X, hitPos.Y, aPos.Z))

		fx.StreamHead.StreamPetals.Enabled = false
		fx.StreamHead.StreamGlints.Enabled = false
		task.delay(0.18, function()
			if fx.StreamStart and fx.StreamStart.Parent then
				fx.StreamStart.SakuraRibbonCore.Enabled = false
				fx.StreamStart.SakuraRibbonOuter.Enabled = false
			end
		end)

		fx.Hit.CFrame = hitLook
		playSfx(fx.Hit, "ImpactSfx")
		CombatAnimator.Hitstop(ctx.attacker, 0.05)
		animeImpactFrame(Color3.fromRGB(255, 206, 232), 0.04, 0.18, false)
		fovPunch(-4.5, 0.055, 0.24)
		springShake(0.46, 0.32, 42, 10.5, 1.5)

		emit(fx.Hit, "HitStar", 6)
		emit(fx.Hit, "HitPetals", 48)
		emit(fx.Hit, "HitSparks", 26)
		pulseLight(fx.Hit:FindFirstChild("HitLight"), 4.0, 18)

		-- 4 cortes luminosos rosados em cascata rapida (mil laminas retalhando!)
		local cutAngles = { 34, -46, 12, -22 }
		local cutOffsets = {
			Vector3.new(-0.4, 0.5, -0.7),
			Vector3.new(0.45, 0.1, -0.75),
			Vector3.new(-0.2, -0.35, -0.7),
			Vector3.new(0.25, 0.65, -0.75),
		}
		for i = 1, 4 do
			local cut = fx["SakuraCut" .. i]
			task.delay((i - 1) * 0.045, function()
				if not ctx.alive then return end
				cut.CFrame = hitLook * CFrame.new(cutOffsets[i]) * CFrame.Angles(0, 0, math.rad(cutAngles[i]))
				cut.Size = Vector3.new(0.18, 0.5, 0.10)
				cut.Transparency = 0
				tween(cut, 0.07, { Size = Vector3.new(0.22, 6.4, 0.10) }, Enum.EasingStyle.Exponential)
				task.delay(0.10, function()
					tween(cut, 0.22, { Size = Vector3.new(0.04, 7.6, 0.04), Transparency = 1 })
				end)
			end)
		end

		setDisc(fx.SakuraRing1, CFrame.new(hitPos) * CFrame.Angles(0.28, 0, -0.22), 1.8, 0.04)
		setDisc(fx.SakuraRing2, CFrame.new(hitPos) * CFrame.Angles(-0.32, 0.6, 0.28), 1.5, 0.08)
		tweenDisc(fx.SakuraRing1, 0.42, 10.6, 1)
		tweenDisc(fx.SakuraRing2, 0.48, 8.8, 1)
	end,
	Duration = 1.65,
}

-- Senbonzakura Kageyoshi (Bankai — Tecnica Assinatura Suprema do Byakuya):
-- Katana afunda no chao -> 6 laminas espectrais colossais se erguem nas laterais -> estilhacam em ciclone colossal de petalas!
HANDLERS.SenbonzakuraKageyoshi = {
	Charge = function(ctx)
		local fx = ctx.fx
		playSfx(fx.Origin, "ChargeSfx")
		local aRoot = rootOf(ctx.attacker)
		local tRoot = rootOf(ctx.target)
		local gy = groundY(ctx.attacker)
		local sFloor = Vector3.new(aRoot.Position.X, gy + 0.06, aRoot.Position.Z)
		local eFloor = Vector3.new(tRoot.Position.X, groundY(ctx.target) + 0.06, tRoot.Position.Z)
		local dir = flat(eFloor - sFloor)
		dir = if dir.Magnitude > 0.1 then dir.Unit else aRoot.CFrame.LookVector
		local right = dir:Cross(Vector3.yAxis)
		if right.Magnitude < 0.05 then
			right = Vector3.xAxis
		else
			right = right.Unit
		end

		-- Anel luminoso de absorcao quando a katana cai e afunda no piso
		local dropPos = sFloor + dir * 2.1
		fx.Origin.CFrame = CFrame.new(dropPos + Vector3.new(0, 0.4, 0))
		setDisc(fx.FloorRipple, CFrame.new(dropPos), 0.8, 0.02)
		task.delay(0.26, function()
			if not ctx.alive then return end
			tweenDisc(fx.FloorRipple, 0.55, 7.6, 1)
			emit(fx.Origin, "DropPetals", 16)
			pulseLight(fx.Origin:FindFirstChild("OriginLight"), 3.4, 16)
			springShake(0.22, 0.28, 36, 10, 0.5)
		end)

		-- 6 Laminas Espectrais Gigantes subindo em duas fileiras majestosas nos flancos da arena!
		ctx.bladeTopPositions = {}
		local arenaSpan = math.clamp((eFloor - sFloor).Magnitude, 8, 22)
		for i = 1, 6 do
			local side = if i <= 3 then -1 else 1
			local rank = ((i - 1) % 3) + 1
			local forwardDist = (rank / 3.4) * arenaSpan * 0.72 + 1.2
			local lateralDist = 4.0 + (rank - 1) * 0.55
			local basePos = sFloor + dir * forwardDist + right * (side * lateralDist)
			local bladeH = 10.5 + (rank % 2) * 1.6
			local blade = fx["GiantBlade" .. i]
			local rim = fx["GiantBladeRim" .. i]
			local bCF = CFrame.lookAt(basePos + Vector3.new(0, bladeH * 0.5, 0), basePos + Vector3.new(0, bladeH * 0.5, 0) + dir)
			local startCF = bCF * CFrame.new(0, -bladeH - 1.5, 0)
			ctx.bladeTopPositions[i] = basePos + Vector3.new(0, bladeH * 0.55, 0)

			task.delay(0.32 + (rank - 1) * 0.08 + (if side > 0 then 0.03 else 0), function()
				if not ctx.alive then return end
				blade.CFrame = startCF
				blade.Size = Vector3.new(0.28, bladeH, 1.45)
				blade.Transparency = 0.06
				rim.CFrame = startCF
				rim.Size = Vector3.new(0.42, bladeH * 1.02, 1.65)
				rim.Transparency = 0.34
				tween(blade, 0.32, { CFrame = bCF }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
				tween(rim, 0.32, { CFrame = bCF }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			end)
		end
	end,
	Release = function(ctx)
		local fx = ctx.fx
		playSfx(fx.Origin, "ReleaseSfx")

		-- Todas as 6 laminas gigantes estilhacam em luz branca e milhares de petalas simultaneamente!
		local positions = ctx.bladeTopPositions or {}
		for i = 1, 6 do
			local blade = fx["GiantBlade" .. i]
			local rim = fx["GiantBladeRim" .. i]
			tween(blade, 0.16, { Size = blade.Size + Vector3.new(0.5, 1.5, 0.8), Transparency = 1 })
			tween(rim, 0.18, { Size = rim.Size + Vector3.new(0.8, 1.8, 1.0), Transparency = 1 })
			if positions[i] then
				fx.ShatterAnchor.CFrame = CFrame.new(positions[i])
				emit(fx.ShatterAnchor, "BladeShatterPetals", 8)
				emit(fx.ShatterAnchor, "BladeShatterGlints", 3)
			end
		end

		local aRoot = rootOf(ctx.attacker)
		local startPos = aRoot.CFrame:PointToWorldSpace(Vector3.new(0, 1.4, -2.5))
		local endPos = targetCenter(ctx.target)
		local lookCF = CFrame.lookAt(startPos, endPos)
		local travel = math.max(0.24, (ctx.timing.Impact or 1.66) - (ctx.timing.Release or 1.16))

		fx.TorrentStart.CFrame = lookCF
		fx.StormHead.CFrame = lookCF
		fx.TorrentStart.TorrentBeam1.Enabled = true
		fx.TorrentStart.TorrentBeam2.Enabled = true
		fx.StormHead.StormPetals.Enabled = true
		fx.StormHead.StormGlints.Enabled = true

		local rings = { fx.PetalSwirlRing1, fx.PetalSwirlRing2, fx.PetalSwirlRing3 }
		for _, r in ipairs(rings) do
			setDisc(r, lookCF * CFrame.Angles(math.pi / 2, 0, 0), 4.6, 0.10)
		end

		springShake(0.32, 0.36, 38, 9, 1.1)

		local t0 = os.clock()
		ctx.follow = RunService.RenderStepped:Connect(function()
			if not ctx.alive then return end
			local elapsed = os.clock() - t0
			local a = math.clamp(elapsed / travel, 0, 1)
			local eased = a * a * (3 - 2 * a)
			local pos = startPos:Lerp(endPos, eased)
			fx.StormHead.CFrame = CFrame.lookAt(pos, endPos + lookCF.LookVector)
			for idx, r in ipairs(rings) do
				local u = ((elapsed * 2.6 + (idx - 1) / 3) % 1) * math.max(0.15, eased)
				local rp = startPos:Lerp(pos, math.clamp(u, 0.05, 0.98))
				r.CFrame = CFrame.lookAt(rp, endPos + lookCF.LookVector) * CFrame.Angles(math.pi / 2, elapsed * 9 + idx * 1.4, 0)
				local sz = 4.2 + math.sin(u * math.pi) * 3.4
				r.Size = Vector3.new(sz, 0.05, sz)
			end
			if a >= 1 and ctx.follow then
				ctx.follow:Disconnect()
				ctx.follow = nil
			end
		end)
	end,
	Impact = function(ctx)
		local fx = ctx.fx
		if ctx.follow then
			ctx.follow:Disconnect()
			ctx.follow = nil
		end
		local tRoot = rootOf(ctx.target)
		local floorCenter = Vector3.new(tRoot.Position.X, groundY(ctx.target) + 0.09, tRoot.Position.Z)
		local hitPos = floorCenter + Vector3.new(0, 2.2, 0)
		local aPos = rootOf(ctx.attacker).Position
		local hitLook = CFrame.lookAt(hitPos, Vector3.new(aPos.X, hitPos.Y, aPos.Z))

		fx.StormHead.StormPetals.Enabled = false
		fx.StormHead.StormGlints.Enabled = false
		task.delay(0.20, function()
			if fx.TorrentStart and fx.TorrentStart.Parent then
				fx.TorrentStart.TorrentBeam1.Enabled = false
				fx.TorrentStart.TorrentBeam2.Enabled = false
			end
		end)

		fx.Hit.CFrame = hitLook
		playSfx(fx.Hit, "ImpactSfx")
		CombatAnimator.Hitstop(ctx.attacker, 0.065)
		animeImpactFrame(Color3.fromRGB(255, 186, 224), 0.055, 0.26, true)
		fovPunch(-6.2, 0.06, 0.32)
		springShake(0.68, 0.44, 46, 9.5, 2.4)

		emit(fx.Hit, "BankaiStar", 8)
		emit(fx.Hit, "BankaiPetals", 62)
		emit(fx.Hit, "BankaiGlints", 22)
		emit(fx.Hit, "SakuraMist", 24)
		pulseLight(fx.Hit:FindFirstChild("HitLight"), 4.0, 26)

		-- 3 aneis de furacao de petalas subindo em espiral ao redor do alvo (sem cilindros verticais no impacto)
		for idx, r in ipairs({ fx.PetalSwirlRing1, fx.PetalSwirlRing2, fx.PetalSwirlRing3 }) do
			local startY = floorCenter.Y + 0.6 + (idx - 1) * 1.4
			local endY = startY + 5.8
			local tilt = if idx % 2 == 0 then 0.24 else -0.22
			setDisc(r, CFrame.new(floorCenter.X, startY, floorCenter.Z) * CFrame.Angles(tilt, idx * 1.1, -tilt * 0.7), 3.2 + idx * 0.9, 0.08)
			tween(r, 0.52 + idx * 0.06, {
				CFrame = CFrame.new(floorCenter.X, endY, floorCenter.Z) * CFrame.Angles(tilt, idx * 1.1 + 3.6, -tilt * 0.7),
				Size = Vector3.new(10.5 + idx * 1.8, 0.05, 10.5 + idx * 1.8),
			})
			for _, d in r:GetChildren() do
				if d:IsA("Decal") then tween(d, 0.52 + idx * 0.06, { Transparency = 1 }) end
			end
		end

		-- 6 flashes de corte anime cortando o alvo em todas as direcoes dentro do ciclone!
		local bankaiAngles = { 44, -44, 16, -24, 68, -62 }
		for i = 1, 6 do
			local cut = fx["BankaiCut" .. i]
			task.delay((i - 1) * 0.04, function()
				if not ctx.alive then return end
				local ox = ((i % 2 == 0) and 0.65 or -0.65)
				local oy = ((i % 3) - 1) * 0.65
				cut.CFrame = hitLook * CFrame.new(ox, oy, -0.8) * CFrame.Angles(0, 0, math.rad(bankaiAngles[i]))
				cut.Size = Vector3.new(0.24, 0.6, 0.12)
				cut.Transparency = 0
				tween(cut, 0.075, { Size = Vector3.new(0.26, 8.4, 0.12) }, Enum.EasingStyle.Exponential)
				task.delay(0.11, function()
					tween(cut, 0.24, { Size = Vector3.new(0.05, 9.6, 0.05), Transparency = 1 })
				end)
			end)
		end

		setDisc(fx.MegaShock1, CFrame.new(floorCenter + Vector3.new(0, 0.10, 0)), 3.0, 0.02)
		setDisc(fx.MegaShock2, CFrame.new(hitPos) * CFrame.Angles(0.25, 0.6, -0.20), 2.4, 0.08)
		tweenDisc(fx.MegaShock1, 0.50, 18.5, 1)
		tweenDisc(fx.MegaShock2, 0.56, 15.0, 1)

		-- Residuo poetico: petalas caindo suavemente apos o furacao
		task.delay(0.40, function()
			if not ctx.alive then return end
			emit(fx.Hit, "ResiduePetals", 20)
		end)
	end,
	Duration = 2.35,
}

--------------------------------------------------------------------
-- Tecnicas Elementais do Sarutobi Hiruzen (Naruto — 4 Elementos)
-- 100% particulas fluidas, trilhas 3D em helice e orbiters de furacao.
-- ZERO cones, ZERO cubos, ZERO circulos/decals engessados!
--------------------------------------------------------------------

local function setSwarmEnabled(fx: Model, count: number, on: boolean)
	for i = 1, count do
		local sw = fx:FindFirstChild("Swarm" .. i)
		if sw then
			for _, d in ipairs(sw:GetChildren()) do
				if d:IsA("ParticleEmitter") or d:IsA("Trail") then
					d.Enabled = on
				end
			end
		end
	end
end

local function setOrbitersEnabled(fx: Model, count: number, on: boolean)
	for i = 1, count do
		local orb = fx:FindFirstChild("Orbiter" .. i)
		if orb then
			for _, d in ipairs(orb:GetChildren()) do
				if d:IsA("ParticleEmitter") or d:IsA("Trail") then
					d.Enabled = on
				end
			end
		end
	end
end

-- Faz N cabecas fluidas viajarem em helice 3D organica do atacante ate o alvo
local function runHelixSwarm(ctx, count: number, startPos: Vector3, endPos: Vector3, travel: number, cfg)
	local fx = ctx.fx
	local lookCF = CFrame.lookAt(startPos, endPos)
	local right = lookCF.RightVector
	local up = lookCF.UpVector
	local radius = cfg.radius or 1.4
	local twist = cfg.twist or 10
	local swayAmp = cfg.sway or 1.2
	local liftAmp = cfg.lift or 0.9

	for i = 1, count do
		local sw = fx["Swarm" .. i]
		sw.CFrame = CFrame.new(startPos)
	end
	setSwarmEnabled(fx, count, true)

	local t0 = os.clock()
	ctx.follow = RunService.RenderStepped:Connect(function()
		if not ctx.alive then return end
		local elapsed = os.clock() - t0
		local a = math.clamp(elapsed / travel, 0, 1)
		local eased = if cfg.smooth then (a * a * (3 - 2 * a)) else (1 - (1 - a) * (1 - a))
		local basePos = startPos:Lerp(endPos, eased)
			+ right * (math.sin(a * math.pi * 2.2) * swayAmp * (1 - a * 0.3))
			+ Vector3.new(0, math.sin(a * math.pi * 1.6) * liftAmp, 0)
		local rNow = radius * math.sin(math.clamp(a, 0.05, 0.98) * math.pi)
		for i = 1, count do
			local sw = fx["Swarm" .. i]
			local ang = elapsed * twist + (i - 1) * (math.pi * 2 / count)
			local radial = if i == 1 then (rNow * 0.35) else rNow
			local pos = basePos + right * (math.cos(ang) * radial) + up * (math.sin(ang) * radial)
			sw.CFrame = CFrame.new(pos)
		end
		if a >= 1 and ctx.follow then
			ctx.follow:Disconnect()
			ctx.follow = nil
		end
	end)
end

-- Faz N orbiters girarem em espiral ascendente real 3D ao redor de um ponto (furacao de particulas sem circulos duros!)
local function runVortexOrbiters(ctx, count: number, centerPos: Vector3, dur: number, cfg)
	local fx = ctx.fx
	local baseR = cfg.startR or 2.6
	local endR = cfg.endR or 4.8
	local spinSpd = cfg.spin or 13
	local riseH = cfg.riseH or 5.5
	local startYOff = cfg.startY or -0.6

	for i = 1, count do
		local orb = fx["Orbiter" .. i]
		local ang = (i - 1) * (math.pi * 2 / count)
		orb.CFrame = CFrame.new(centerPos + Vector3.new(math.cos(ang) * baseR, startYOff, math.sin(ang) * baseR))
	end
	setOrbitersEnabled(fx, count, true)

	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not ctx.alive then
			conn:Disconnect()
			setOrbitersEnabled(fx, count, false)
			return
		end
		local elapsed = os.clock() - t0
		local a = math.clamp(elapsed / dur, 0, 1)
		local r = baseR + (endR - baseR) * a
		for i = 1, count do
			local orb = fx["Orbiter" .. i]
			local ang = elapsed * spinSpd + (i - 1) * (math.pi * 2 / count)
			local hOff = startYOff + a * riseH + ((i - 1) * (cfg.staggerY or 0.9))
			orb.CFrame = CFrame.new(centerPos + Vector3.new(math.cos(ang) * r, hOff, math.sin(ang) * r))
		end
		if a >= 1 then
			conn:Disconnect()
			setOrbitersEnabled(fx, count, false)
		end
	end)
	return conn
end

-- 1. TERRA (Doton: Dragao de Terra): poeira e faiscas sismicas nas palmas -> enxame fluido rente ao chao -> erupcao espiral de terra!
HANDLERS.DotonMuralhaTerrestre = {
	Charge = function(ctx)
		local fx = ctx.fx
		playSfx(fx.Origin, "ChargeSfx")
		local handsMid = (leftHandPos(ctx.attacker) + handPos(ctx.attacker)) * 0.5
		fx.Origin.CFrame = CFrame.new(handsMid)
		emit(fx.Origin, "ChargeDust", 18)
		emit(fx.Origin, "ChargeSparks", 28)
		pulseLight(fx.Origin:FindFirstChild("OriginLight"), 3.0, 14)
	end,
	Release = function(ctx)
		local fx = ctx.fx
		playSfx(fx.Origin, "ReleaseSfx")
		local aRoot, tRoot = rootOf(ctx.attacker), rootOf(ctx.target)
		local sFloor = Vector3.new(aRoot.Position.X, groundY(ctx.attacker) + 0.5, aRoot.Position.Z)
		local eFloor = Vector3.new(tRoot.Position.X, groundY(ctx.target) + 0.6, tRoot.Position.Z)
		local dir = flat(eFloor - sFloor)
		dir = if dir.Magnitude > 0.1 then dir.Unit else aRoot.CFrame.LookVector
		local slamPos = sFloor + dir * 1.4

		fx.Origin.CFrame = CFrame.new(slamPos)
		emit(fx.Origin, "SlamPlume", 28)
		emit(fx.Origin, "ChargeSparks", 24)
		springShake(0.28, 0.28, 38, 11, 0.7)

		local travel = math.max(0.24, (ctx.timing.Impact or 1.12) - (ctx.timing.Release or 0.68))
		runHelixSwarm(ctx, 3, slamPos, eFloor, travel, { radius = 1.4, twist = 11, sway = 1.5, lift = 0.7, smooth = false })
	end,
	Impact = function(ctx)
		local fx = ctx.fx
		if ctx.follow then ctx.follow:Disconnect(); ctx.follow = nil end
		setSwarmEnabled(fx, 3, false)

		local tRoot = rootOf(ctx.target)
		local floorCenter = Vector3.new(tRoot.Position.X, groundY(ctx.target) + 0.35, tRoot.Position.Z)
		fx.Hit.CFrame = CFrame.new(floorCenter)
		playSfx(fx.Hit, "ImpactSfx")
		CombatAnimator.Hitstop(ctx.attacker, 0.055)
		animeImpactFrame(Color3.fromRGB(255, 224, 175), 0.04, 0.18, false)
		fovPunch(-4.2, 0.055, 0.24)
		springShake(0.58, 0.40, 42, 10, 1.7)
		pulseLight(fx.Hit:FindFirstChild("HitLight"), 3.8, 22)

		-- Explosao sismica em multi-ondas + 2 orbiters 3D jogando poeira e faiscas em espiral!
		emit(fx.Hit, "EruptionPlume", 36)
		emit(fx.Hit, "DebrisArcs", 46)
		task.delay(0.10, function()
			if not ctx.alive then return end
			emit(fx.Hit, "EruptionPlume", 24)
			emit(fx.Hit, "DebrisArcs", 32)
		end)
		task.delay(0.30, function()
			if not ctx.alive then return end
			emit(fx.Hit, "GoldenResidue", 24)
		end)
		runVortexOrbiters(ctx, 2, floorCenter + Vector3.new(0, 0.5, 0), 0.58, { startR = 2.0, endR = 4.6, spin = 12, riseH = 4.8, startY = 0, staggerY = 0.8 })
	end,
	Duration = 1.75,
}

-- 2. FOGO (Katon: Dragao de Fogo): brasas na boca -> 3 espirais de fogo vivo -> turbilhao de chamas envolvendo o alvo!
HANDLERS.KatonDragaoDeFogo = {
	Charge = function(ctx)
		local fx = ctx.fx
		playSfx(fx.Origin, "ChargeSfx")
		local aRoot = rootOf(ctx.attacker)
		local mouthPos = aRoot.CFrame:PointToWorldSpace(Vector3.new(0, 1.45, -1.25))
		fx.Origin.CFrame = CFrame.new(mouthPos)
		emit(fx.Origin, "BreathFire", 18)
		emit(fx.Origin, "BreathSparks", 30)
		pulseLight(fx.Origin:FindFirstChild("OriginLight"), 3.4, 15)

		ctx.follow = RunService.RenderStepped:Connect(function()
			if not ctx.alive or not alive(ctx.attacker) then return end
			local r = rootOf(ctx.attacker)
			fx.Origin.CFrame = CFrame.new(r.CFrame:PointToWorldSpace(Vector3.new(0, 1.45, -1.25)))
		end)
	end,
	Release = function(ctx)
		local fx = ctx.fx
		if ctx.follow then ctx.follow:Disconnect(); ctx.follow = nil end
		playSfx(fx.Origin, "ReleaseSfx")
		local aRoot = rootOf(ctx.attacker)
		local startPos = aRoot.CFrame:PointToWorldSpace(Vector3.new(0, 1.45, -1.5))
		local endPos = targetCenter(ctx.target)
		local travel = math.max(0.24, (ctx.timing.Impact or 1.18) - (ctx.timing.Release or 0.72))

		springShake(0.28, 0.30, 42, 11, 0.8)
		runHelixSwarm(ctx, 3, startPos, endPos, travel, { radius = 1.6, twist = 13, sway = 1.8, lift = 1.1, smooth = false })
	end,
	Impact = function(ctx)
		local fx = ctx.fx
		if ctx.follow then ctx.follow:Disconnect(); ctx.follow = nil end
		setSwarmEnabled(fx, 3, false)

		local hitPos = targetCenter(ctx.target)
		fx.Hit.CFrame = CFrame.new(hitPos)
		playSfx(fx.Hit, "ImpactSfx")
		CombatAnimator.Hitstop(ctx.attacker, 0.06)
		animeImpactFrame(Color3.fromRGB(255, 198, 140), 0.045, 0.22, false)
		fovPunch(-5.0, 0.055, 0.26)
		springShake(0.62, 0.42, 44, 10, 1.9)
		pulseLight(fx.Hit:FindFirstChild("HitLight"), 4.0, 24)

		-- Multi-ondas de chamas vivas + 2 orbiters envolvendo o inimigo em espiral flamejante!
		emit(fx.Hit, "FlameBloom", 42)
		emit(fx.Hit, "FireStreaks", 48)
		emit(fx.Hit, "HeatSmoke", 24)
		task.delay(0.10, function()
			if not ctx.alive then return end
			emit(fx.Hit, "FlameBloom", 30)
			emit(fx.Hit, "FireStreaks", 34)
		end)
		task.delay(0.32, function()
			if not ctx.alive then return end
			emit(fx.Hit, "ResidueEmbers", 28)
		end)
		runVortexOrbiters(ctx, 2, hitPos, 0.65, { startR = 1.9, endR = 4.5, spin = 14, riseH = 5.6, startY = -0.8, staggerY = 1.0 })
	end,
	Duration = 1.85,
}

-- 3. AGUA (Suiton: Dragao de Agua): agua gira ao redor do Sarutobi -> 3 correntes fluidas serpenteiam -> turbilhao de mare e espuma!
HANDLERS.SuitonDragaoDeAgua = {
	Charge = function(ctx)
		local fx = ctx.fx
		playSfx(fx.Origin, "ChargeSfx")
		local aRoot = rootOf(ctx.attacker)
		fx.Origin.CFrame = CFrame.new(aRoot.Position + Vector3.new(0, 0.6, 0))
		emit(fx.Origin, "WaterMistCharge", 22)
		emit(fx.Origin, "DropletCharge", 30)
		pulseLight(fx.Origin:FindFirstChild("OriginLight"), 3.0, 15)
		-- Orbiters giram ao redor do Sarutobi acumulando agua durante os selos!
		ctx.chargeOrb = runVortexOrbiters(ctx, 2, aRoot.Position, 0.44, { startR = 3.2, endR = 1.8, spin = 10, riseH = 1.8, startY = -0.6, staggerY = 0.6 })
	end,
	Release = function(ctx)
		local fx = ctx.fx
		if ctx.chargeOrb then ctx.chargeOrb:Disconnect(); ctx.chargeOrb = nil end
		setOrbitersEnabled(fx, 2, false)
		playSfx(fx.Origin, "ReleaseSfx")

		local aRoot = rootOf(ctx.attacker)
		local startPos = aRoot.CFrame:PointToWorldSpace(Vector3.new(0, 1.1, -1.8))
		local endPos = targetCenter(ctx.target)
		local travel = math.max(0.26, (ctx.timing.Impact or 1.22) - (ctx.timing.Release or 0.74))

		springShake(0.24, 0.30, 36, 10, 0.8)
		runHelixSwarm(ctx, 3, startPos, endPos, travel, { radius = 1.8, twist = 11, sway = 2.4, lift = 2.0, smooth = true })
	end,
	Impact = function(ctx)
		local fx = ctx.fx
		if ctx.follow then ctx.follow:Disconnect(); ctx.follow = nil end
		setSwarmEnabled(fx, 3, false)

		local targets = if typeof(ctx.targets) == "table" and #ctx.targets > 0 then ctx.targets else { ctx.target }
		local primaryPos = targetCenter(ctx.target)

		fx.Hit.CFrame = CFrame.new(primaryPos)
		playSfx(fx.Hit, "ImpactSfx")
		CombatAnimator.Hitstop(ctx.attacker, 0.055)
		animeImpactFrame(Color3.fromRGB(182, 240, 255), 0.04, 0.20, false)
		fovPunch(-4.8, 0.055, 0.26)
		springShake(0.58, 0.40, 40, 9.5, 1.7)
		pulseLight(fx.Hit:FindFirstChild("HitLight"), 3.9, 24)

		for idx, tgt in ipairs(targets) do
			if not alive(tgt) then continue end
			local tp = targetCenter(tgt)
			local mult = if idx == 1 then 1 else 0.65
			fx.Hit.CFrame = CFrame.new(tp)
			emit(fx.Hit, "SplashBurst", math.floor(42 * mult))
			emit(fx.Hit, "SeaMist", math.floor(28 * mult))
			emit(fx.Hit, "WaterStreaks", math.floor(44 * mult))
		end
		task.delay(0.12, function()
			if not ctx.alive then return end
			fx.Hit.CFrame = CFrame.new(primaryPos)
			emit(fx.Hit, "SplashBurst", 28)
			emit(fx.Hit, "WaterStreaks", 32)
		end)
		runVortexOrbiters(ctx, 2, primaryPos, 0.68, { startR = 2.2, endR = 5.4, spin = 13, riseH = 5.2, startY = -0.9, staggerY = 1.0 })
	end,
	Duration = 1.90,
}

-- 4. VENTO (Futon: Tempestade Celeste — Assinatura): vendaval 3D sobe ao redor -> 3 helices aceleradas -> furacao vivo de 3 Orbiters!
HANDLERS.FutonTempestadeCeleste = {
	Charge = function(ctx)
		local fx = ctx.fx
		playSfx(fx.Origin, "ChargeSfx")
		local aRoot = rootOf(ctx.attacker)
		fx.Origin.CFrame = CFrame.new(aRoot.Position + Vector3.new(0, 0.6, 0))
		emit(fx.Origin, "WindChargeStreaks", 34)
		emit(fx.Origin, "KonohaLeaves", 22)
		pulseLight(fx.Origin:FindFirstChild("OriginLight"), 3.3, 16)
		ctx.chargeOrb = runVortexOrbiters(ctx, 3, aRoot.Position, 0.60, { startR = 3.8, endR = 1.6, spin = 14, riseH = 3.2, startY = -0.8, staggerY = 0.8 })
	end,
	Release = function(ctx)
		local fx = ctx.fx
		if ctx.chargeOrb then ctx.chargeOrb:Disconnect(); ctx.chargeOrb = nil end
		setOrbitersEnabled(fx, 3, false)
		playSfx(fx.Origin, "ReleaseSfx")

		local aRoot = rootOf(ctx.attacker)
		local startPos = aRoot.CFrame:PointToWorldSpace(Vector3.new(0, 1.35, -2.0))
		local endPos = targetCenter(ctx.target)
		local travel = math.max(0.28, (ctx.timing.Impact or 1.48) - (ctx.timing.Release or 0.92))

		springShake(0.34, 0.38, 42, 9.5, 1.2)
		runHelixSwarm(ctx, 3, startPos, endPos, travel, { radius = 2.2, twist = 16, sway = 2.0, lift = 1.3, smooth = true })
	end,
	Impact = function(ctx)
		local fx = ctx.fx
		if ctx.follow then ctx.follow:Disconnect(); ctx.follow = nil end
		setSwarmEnabled(fx, 3, false)

		local targets = if typeof(ctx.targets) == "table" and #ctx.targets > 0 then ctx.targets else { ctx.target }
		local primaryPos = targetCenter(ctx.target)

		fx.Hit.CFrame = CFrame.new(primaryPos)
		playSfx(fx.Hit, "ImpactSfx")
		CombatAnimator.Hitstop(ctx.attacker, 0.065)
		animeImpactFrame(Color3.fromRGB(205, 255, 232), 0.055, 0.26, true)
		fovPunch(-6.0, 0.06, 0.32)
		springShake(0.68, 0.46, 46, 9.5, 2.3)
		pulseLight(fx.Hit:FindFirstChild("HitLight"), 4.0, 26)

		for idx, tgt in ipairs(targets) do
			if not alive(tgt) then continue end
			local tp = targetCenter(tgt)
			local mult = if idx == 1 then 1 else 0.65
			fx.Hit.CFrame = CFrame.new(tp)
			emit(fx.Hit, "TempestMist", math.floor(34 * mult))
			emit(fx.Hit, "TempestStreaks", math.floor(54 * mult))
			emit(fx.Hit, "TempestLeaves", math.floor(34 * mult))
		end
		task.delay(0.14, function()
			if not ctx.alive then return end
			fx.Hit.CFrame = CFrame.new(primaryPos + Vector3.new(0, 1.2, 0))
			emit(fx.Hit, "TempestMist", 24)
			emit(fx.Hit, "TempestStreaks", 42)
		end)
		task.delay(0.36, function()
			if not ctx.alive then return end
			fx.Hit.CFrame = CFrame.new(primaryPos + Vector3.new(0, 1.8, 0))
			emit(fx.Hit, "ResidueWind", 28)
			emit(fx.Hit, "TempestLeaves", 18)
		end)

		-- Furacao 3D REAL subindo ao redor do alvo com 3 orbiters de particulas e trilhas!
		runVortexOrbiters(ctx, 3, primaryPos, 0.78, { startR = 2.0, endR = 6.2, spin = 17, riseH = 7.4, startY = -1.0, staggerY = 1.1 })
	end,
	Duration = 2.30,
}

--------------------------------------------------------------------
-- Sistema Procedural de VFX para Golpes Genericos e Classicos
-- (Leve, sem cilindros finais, 100% versionado em codigo, suporte 1x1 e 2x2)
--------------------------------------------------------------------
local procActive = {} -- [Model] = ctx

local TEX = {
	Spark = "rbxassetid://111340920948521",
	Star = "rbxassetid://77032248103074",
	Glint = "rbxassetid://105042923162509",
	Diamond = "rbxassetid://105200043049019",
	Flame = "rbxassetid://79477996185324",
	Bolt = "rbxassetid://78119176408303",
	Streak = "rbxassetid://122479098668481",
	Gather = "rbxassetid://115073640656853",
	Puff = "rbxassetid://82305102124278",
	Ring = "rbxassetid://136971071117749",
	Shock = "rbxassetid://83043634785289",
	Trail = "rbxassetid://115075243133786",
	Leaves = "rbxassetid://134973377891827",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	SoftGlow = "rbxassetid://83184852649242",
}

local SFX = {
	Charge = "rbxassetid://6456542119",
	Release = "rbxassetid://126546670067885",
	ReleaseHeavy = "rbxassetid://92846408037360",
	Impact = "rbxassetid://98753363372264",
	ImpactHeavy = "rbxassetid://99881515803650",
}

local function genPart(parent: Instance, size: Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?, trans: number?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Neon
	p.Shape = shape or Enum.PartType.Block
	p.Transparency = trans or 0
	p.Parent = parent
	return p
end

local function genAnchor(parent: Instance, cf: CFrame): Part
	local p = genPart(parent, Vector3.new(0.2, 0.2, 0.2), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, Enum.PartType.Block, 1)
	p.CFrame = cf
	return p
end

local function genSound(parent: Instance, soundId: string, volume: number?, pitch: number?)
	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume = volume or 0.42
	s.PlaybackSpeed = pitch or 1
	local grp = SoundService:FindFirstChild("Efeitos")
	if grp and grp:IsA("SoundGroup") then
		s.SoundGroup = grp
	end
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, 2.5)
end

local function genLight(parent: Instance, pos: Vector3, color: Color3, peak: number?, range: number?)
	local a = genAnchor(parent, CFrame.new(pos))
	local l = Instance.new("PointLight")
	l.Color = color
	l.Shadows = false
	l.Brightness = 0
	l.Range = range or 12
	l.Parent = a
	pulseLight(l, math.min(peak or 3.0, 3.6), range or 12)
	return a
end

local function genBurst(parent: Instance, pos: Vector3, tex: string, c1: Color3, c2: Color3?, count: number, sMin: number, sMax: number, sz0: number, sz1: number, life: number?, spread: number?, rotSpd: number?, accel: Vector3?, stretch: number?)
	local a = genAnchor(parent, CFrame.new(pos))
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = tex
	pe.Color = ColorSequence.new(c1, c2 or c1)
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, sz0),
		NumberSequenceKeypoint.new(0.55, sz0 * 0.72 + sz1 * 0.28),
		NumberSequenceKeypoint.new(1, sz1),
	})
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.04),
		NumberSequenceKeypoint.new(0.68, 0.30),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe.Speed = NumberRange.new(sMin, sMax)
	pe.Lifetime = NumberRange.new((life or 0.38) * 0.7, life or 0.38)
	pe.SpreadAngle = Vector2.new(spread or 180, spread or 180)
	pe.RotSpeed = NumberRange.new(-(rotSpd or 120), rotSpd or 120)
	pe.Rotation = NumberRange.new(0, 360)
	pe.LightEmission = if tex == TEX.Smoke then 0.35 else 0.92
	pe.Brightness = if tex == TEX.SoftGlow then 2.8 else 1.9
	pe.Drag = 3.2
	if stretch and stretch > 0 then
		pe.Orientation = Enum.ParticleOrientation.VelocityParallel
		pe.Squash = NumberSequence.new(stretch)
	end
	if accel then
		pe.Acceleration = accel
	end
	pe.Rate = 0
	pe.Parent = a
	pe:Emit(if lowQuality() then math.max(2, math.floor(count / 2)) else count)
	return a
end

-- Onda fluida 100% em particulas (substitui discos planos de decal por faiscas radiais + nevoa organica)
local function genFluidRing(parent: Instance, cf: CFrame, c1: Color3, c2: Color3?, radius: number, dur: number, useSmoke: boolean?)
	local pos = cf.Position
	local count = math.clamp(math.floor(radius * 3.4), 16, 36)
	local spd = math.clamp(radius * 2.4, 8, 28)
	genBurst(parent, pos, TEX.SoftGlow, c2 or Color3.new(1, 1, 1), c1, count, spd * 0.55, spd, 0.55, 0.05, dur, 180, 0, nil, 1.15)
	if useSmoke then
		genBurst(parent, pos, TEX.Smoke, c1, c2 or c1, math.max(10, math.floor(count * 0.5)), spd * 0.28, spd * 0.65, 1.1, math.clamp(radius * 0.42, 2.2, 4.8), dur * 1.25, 180, 90)
	else
		genBurst(parent, pos, TEX.Fire, c1, c2 or c1, math.max(12, math.floor(count * 0.55)), spd * 0.32, spd * 0.72, 0.95, math.clamp(radius * 0.36, 1.8, 4.0), dur * 1.1, 180, 120)
	end
end

-- Corte luminoso fluido em particulas e rastro (zero barras retangulares rigidas)
local function genSlashMark(parent: Instance, lookCF: CFrame, offset: Vector3, angleDeg: number, len: number, thick: number, c1: Color3, c2: Color3?)
	local centerCF = lookCF * CFrame.new(offset) * CFrame.Angles(0, 0, math.rad(angleDeg))
	local p0 = (centerCF * CFrame.new(0, -len * 0.5, 0)).Position
	local p1 = (centerCF * CFrame.new(0, len * 0.5, 0)).Position
	local a = genAnchor(parent, CFrame.new(p0))
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, thick * 1.6, 0)
	a0.Parent = a
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -thick * 1.6, 0)
	a1.Parent = a
	local tr = Instance.new("Trail")
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Texture = TEX.Trail
	tr.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, c2 or Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.45, c1),
		ColorSequenceKeypoint.new(1, c1),
	})
	tr.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.02),
		NumberSequenceKeypoint.new(0.65, 0.32),
		NumberSequenceKeypoint.new(1, 1),
	})
	tr.Lifetime = 0.22
	tr.MinLength = 0.04
	tr.LightEmission = 1
	tr.FaceCamera = true
	tr.Parent = a

	local pe = Instance.new("ParticleEmitter")
	pe.Texture = TEX.SoftGlow
	pe.Color = ColorSequence.new(c2 or Color3.new(1, 1, 1), c1)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, thick * 2.2), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) })
	pe.Speed = NumberRange.new(2, 7)
	pe.Lifetime = NumberRange.new(0.16, 0.28)
	pe.Rate = if lowQuality() then 35 else 75
	pe.LightEmission = 1
	pe.Brightness = 2.8
	pe.Orientation = Enum.ParticleOrientation.VelocityParallel
	pe.Squash = NumberSequence.new(1.1)
	pe.Parent = a

	local t0 = os.clock()
	local dur = 0.11
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not parent.Parent or not a.Parent then conn:Disconnect(); return end
		local alpha = math.clamp((os.clock() - t0) / dur, 0, 1)
		a.CFrame = CFrame.new(p0:Lerp(p1, alpha))
		if alpha >= 1 then
			conn:Disconnect()
			pe.Enabled = false
			tr.Enabled = false
		end
	end)
end

local function attachGenTrail(part: BasePart, c1: Color3, c2: Color3?, width: number, life: number?): Trail
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, width * 0.5, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -width * 0.5, 0)
	a1.Parent = part
	local tr = Instance.new("Trail")
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Texture = TEX.Trail
	tr.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, c2 or Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.4, c1),
		ColorSequenceKeypoint.new(1, c1),
	})
	tr.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.6, 0.38),
		NumberSequenceKeypoint.new(1, 1),
	})
	tr.Lifetime = life or 0.20
	tr.MinLength = 0.06
	tr.LightEmission = 0.95
	tr.FaceCamera = true
	tr.Parent = part
	return tr
end

-- Enxame fluido 3D em helice/arco: ancoras invisiveis com Trail + particulas organicas (zero esferas/blocos solidos!)
local function genFluidSwarm(ctx, fromPos: Vector3, toPos: Vector3, travel: number, c1: Color3, c2: Color3?, opts: { [string]: any }?)
	local o = opts or {}
	local strands = o.strands or 2
	local radius = o.radius or 0.9
	local turns = o.turns or 1.4
	local arcUp = o.arcUp or 0.55
	local trailW = o.trailW or 0.65
	local flowTex = o.flowTex or TEX.Fire
	local moteTex = o.moteTex or TEX.SoftGlow
	local flowRate = if lowQuality() then math.floor((o.flowRate or 46) * 0.5) else (o.flowRate or 46)
	local moteRate = if lowQuality() then math.floor((o.moteRate or 54) * 0.5) else (o.moteRate or 54)
	local flowSz = o.flowSz or 1.25
	local moteSz = o.moteSz or 0.45

	local dir = toPos - fromPos
	local lookCF = if dir.Magnitude > 0.1 then CFrame.lookAt(fromPos, toPos) else CFrame.new(fromPos)
	local right = lookCF.RightVector
	local up = lookCF.UpVector

	for s = 1, strands do
		local phase = ((s - 1) / math.max(1, strands)) * math.pi * 2 + (o.phaseOffset or 0)
		local anchor = genAnchor(ctx.fx, CFrame.new(fromPos))
		local tr = attachGenTrail(anchor, c1, c2, trailW, o.trailLife or 0.22)

		local flow = Instance.new("ParticleEmitter")
		flow.Texture = flowTex
		flow.Color = ColorSequence.new(c2 or Color3.new(1, 1, 1), c1)
		flow.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, flowSz * 0.55),
			NumberSequenceKeypoint.new(0.45, flowSz),
			NumberSequenceKeypoint.new(1, flowSz * 0.2),
		})
		flow.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.18),
			NumberSequenceKeypoint.new(0.65, 0.48),
			NumberSequenceKeypoint.new(1, 1),
		})
		flow.Speed = NumberRange.new(0.6, 2.6)
		flow.Lifetime = NumberRange.new(0.22, 0.38)
		flow.SpreadAngle = Vector2.new(180, 180)
		flow.RotSpeed = NumberRange.new(-110, 110)
		flow.Rotation = NumberRange.new(0, 360)
		flow.LightEmission = if flowTex == TEX.Smoke then 0.35 else 0.90
		flow.Brightness = 2.0
		flow.Drag = 2.6
		flow.Rate = flowRate
		flow.Parent = anchor

		local motes = Instance.new("ParticleEmitter")
		motes.Texture = moteTex
		motes.Color = ColorSequence.new(c2 or Color3.new(1, 1, 1), c1)
		motes.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, moteSz),
			NumberSequenceKeypoint.new(0.5, moteSz * 0.65),
			NumberSequenceKeypoint.new(1, 0),
		})
		motes.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.04),
			NumberSequenceKeypoint.new(0.7, 0.28),
			NumberSequenceKeypoint.new(1, 1),
		})
		motes.Speed = NumberRange.new(1.5, 5.5)
		motes.Lifetime = NumberRange.new(0.18, 0.34)
		motes.SpreadAngle = Vector2.new(180, 180)
		motes.LightEmission = 1
		motes.Brightness = 2.8
		motes.Orientation = Enum.ParticleOrientation.VelocityParallel
		motes.Squash = NumberSequence.new(1.0)
		motes.Drag = 2.8
		motes.Rate = moteRate
		motes.Parent = anchor

		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			if not ctx.alive or not anchor.Parent then conn:Disconnect(); return end
			local a = math.clamp((os.clock() - t0) / math.max(0.08, travel), 0, 1)
			local env = math.sin(a * math.pi)
			local ang = phase + a * math.pi * 2 * turns
			local radial = (right * math.cos(ang) + up * math.sin(ang)) * (radius * env)
			local pos = fromPos:Lerp(toPos, a) + radial + Vector3.new(0, env * arcUp, 0)
			anchor.CFrame = CFrame.new(pos)
			if a >= 1 then
				conn:Disconnect()
				flow.Enabled = false
				motes.Enabled = false
				tr.Enabled = false
			end
		end)
	end
end

-- Vortice orbital 3D fluido ao redor de um ponto/personagem (para Buff, Cura, Escudo, Vento, Hex, Impacto)
local function genFluidVortex(ctx, centerPos: Vector3, c1: Color3, c2: Color3?, opts: { [string]: any }?)
	local o = opts or {}
	local count = o.count or 2
	local radius = o.radius or 2.8
	local height = o.height or 4.6
	local dur = o.dur or 0.56
	local turns = o.turns or 2.0
	local flowTex = o.flowTex or TEX.Fire
	local trailW = o.trailW or 0.55

	for i = 1, count do
		local baseAng = ((i - 1) / math.max(1, count)) * math.pi * 2
		local startP = centerPos + Vector3.new(math.cos(baseAng) * radius, 0, math.sin(baseAng) * radius)
		local anchor = genAnchor(ctx.fx, CFrame.new(startP))
		local tr = attachGenTrail(anchor, c1, c2, trailW, 0.24)

		local pe = Instance.new("ParticleEmitter")
		pe.Texture = flowTex
		pe.Color = ColorSequence.new(c2 or Color3.new(1, 1, 1), c1)
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.65), NumberSequenceKeypoint.new(0.5, 1.15), NumberSequenceKeypoint.new(1, 0.1) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(0.7, 0.55), NumberSequenceKeypoint.new(1, 1) })
		pe.Speed = NumberRange.new(1.0, 3.2)
		pe.Lifetime = NumberRange.new(0.24, 0.42)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.LightEmission = if flowTex == TEX.Smoke then 0.4 else 0.92
		pe.Brightness = 2.1
		pe.Rate = if lowQuality() then 18 else 36
		pe.Parent = anchor

		local sparks = Instance.new("ParticleEmitter")
		sparks.Texture = TEX.SoftGlow
		sparks.Color = ColorSequence.new(c2 or Color3.new(1, 1, 1), c1)
		sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.42), NumberSequenceKeypoint.new(1, 0) })
		sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.04), NumberSequenceKeypoint.new(1, 1) })
		sparks.Speed = NumberRange.new(1.2, 4.5)
		sparks.Lifetime = NumberRange.new(0.22, 0.40)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.LightEmission = 1
		sparks.Brightness = 2.9
		sparks.Rate = if lowQuality() then 22 else 44
		sparks.Parent = anchor

		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			if not ctx.alive or not anchor.Parent then conn:Disconnect(); return end
			local a = math.clamp((os.clock() - t0) / dur, 0, 1)
			local ang = baseAng + a * math.pi * 2 * turns
			local r = radius * (1.0 - a * (o.taper or 0.22))
			local y = a * height
			anchor.CFrame = CFrame.new(centerPos + Vector3.new(math.cos(ang) * r, y, math.sin(ang) * r))
			if a >= 1 then
				conn:Disconnect()
				pe.Enabled = false
				sparks.Enabled = false
				tr.Enabled = false
			end
		end)
	end
end

local function genDrainOrbs(parent: Instance, fromPos: Vector3, attacker: Model, c1: Color3, c2: Color3?)
	for i = 1, 3 do
		task.delay((i - 1) * 0.06, function()
			if not parent.Parent or not alive(attacker) then
				return
			end
			local anchor = genAnchor(parent, CFrame.new(fromPos))
			local tr = attachGenTrail(anchor, c1, c2 or Color3.fromRGB(220, 255, 225), 0.48, 0.20)
			local pe = Instance.new("ParticleEmitter")
			pe.Texture = TEX.SoftGlow
			pe.Color = ColorSequence.new(c2 or Color3.fromRGB(225, 255, 235), c1)
			pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0) })
			pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.04), NumberSequenceKeypoint.new(1, 1) })
			pe.Speed = NumberRange.new(0.8, 2.5)
			pe.Lifetime = NumberRange.new(0.18, 0.30)
			pe.Rate = if lowQuality() then 24 else 48
			pe.LightEmission = 1
			pe.Brightness = 3.0
			pe.Parent = anchor

			local arcSide = (i - 2) * 2.1
			local arcUp = 1.4 + (i % 2) * 1.1
			local t0 = os.clock()
			local dur = 0.34
			local conn
			conn = RunService.RenderStepped:Connect(function()
				if not parent.Parent or not alive(attacker) then
					conn:Disconnect()
					return
				end
				local a = math.clamp((os.clock() - t0) / dur, 0, 1)
				local toPos = targetCenter(attacker)
				local dir = flat(toPos - fromPos)
				local right = if dir.Magnitude > 0.1 then dir.Unit:Cross(Vector3.yAxis) else Vector3.xAxis
				local pos = fromPos:Lerp(toPos, a) + right * (math.sin(a * math.pi) * arcSide) + Vector3.new(0, math.sin(a * math.pi) * arcUp, 0)
				anchor.CFrame = CFrame.new(pos)
				if a >= 1 then
					conn:Disconnect()
					pe.Enabled = false
					tr.Enabled = false
					if i == 1 then
						genBurst(parent, toPos, TEX.SoftGlow, c1, Color3.fromRGB(235, 255, 235), 22, 4, 11, 0.55, 0.05, 0.36, 180, 0, nil, 0.8)
					end
				end
			end)
		end)
	end
end

local function genShieldShatter(parent: Instance, pos: Vector3)
	genBurst(parent, pos, TEX.Diamond, Color3.fromRGB(165, 248, 255), Color3.fromRGB(95, 212, 255), 24, 10, 26, 0.65, 0.06, 0.40, 180, 220, Vector3.new(0, -14, 0))
	genBurst(parent, pos, TEX.SoftGlow, Color3.fromRGB(235, 255, 255), Color3.fromRGB(115, 240, 255), 20, 8, 22, 0.55, 0.05, 0.34, 180, 0, nil, 1.2)
end

local function ctxTargets(ctx): { Model }
	local list = {}
	if typeof(ctx.targets) == "table" and #ctx.targets > 0 then
		for _, m in ipairs(ctx.targets) do
			if alive(m) then
				table.insert(list, m)
			end
		end
	end
	if #list == 0 and alive(ctx.target) then
		table.insert(list, ctx.target)
	end
	return list
end

local function ctxCenterOfTargets(ctx): (Vector3, number)
	local ts = ctxTargets(ctx)
	if #ts == 0 then
		return targetCenter(ctx.attacker), groundY(ctx.attacker)
	end
	local sum = Vector3.zero
	local gy = groundY(ts[1])
	for _, m in ipairs(ts) do
		sum += targetCenter(m)
	end
	return sum / #ts, gy
end

-- Paletas e variacoes individuais para os 75 golpes genericos e classicos
local GENERIC_STYLES: { [string]: any } = {
	-- ESPADACHIM (13 genericos + CorteFlamejante)
	PosturaDaLamina = { variant = "attack", c1 = Color3.fromRGB(255, 118, 92), c2 = Color3.fromRGB(255, 232, 180), pitch = 1.1 },
	EstocadaVeloz = { variant = "thrust", c1 = Color3.fromRGB(125, 225, 255), c2 = Color3.fromRGB(245, 252, 255), pitch = 1.28 },
	CorteGiratorio = { variant = "spin", c1 = Color3.fromRGB(165, 228, 255), c2 = Color3.fromRGB(255, 255, 255), pitch = 1.12 },
	CorteCerteiro = { variant = "thrust", c1 = Color3.fromRGB(255, 214, 96), c2 = Color3.fromRGB(255, 250, 225), pitch = 1.2 },
	LaminaAfiada = { variant = "attack", c1 = Color3.fromRGB(115, 230, 255), c2 = Color3.fromRGB(255, 240, 175), pitch = 1.22 },
	CorteDrenante = { variant = "dash", c1 = Color3.fromRGB(92, 245, 152), c2 = Color3.fromRGB(225, 255, 235), drain = true, pitch = 1.05 },
	QuebraLamina = { variant = "heavy", c1 = Color3.fromRGB(115, 238, 255), c2 = Color3.fromRGB(255, 245, 200), breaksProtect = true, heavy = true, pitch = 0.92 },
	FioVenenoso = { variant = "dash", c1 = Color3.fromRGB(184, 88, 255), c2 = Color3.fromRGB(145, 255, 130), tex = TEX.Puff, pitch = 1.08 },
	LaminaPesada = { variant = "heavy", c1 = Color3.fromRGB(255, 152, 72), c2 = Color3.fromRGB(255, 238, 196), heavy = true, pitch = 0.85 },
	DancaDasEspadas = { variant = "swords", c1 = Color3.fromRGB(255, 198, 72), c2 = Color3.fromRGB(255, 248, 215), pitch = 1.15 },
	LaminasNoChao = { variant = "spikes", c1 = Color3.fromRGB(215, 228, 248), c2 = Color3.fromRGB(130, 195, 255), pitch = 1.05 },
	TempestadeDeCortes = { variant = "spin", c1 = Color3.fromRGB(140, 218, 255), c2 = Color3.fromRGB(255, 235, 160), heavy = true, pitch = 1.04 },
	InvestidaCortante = { variant = "dash", c1 = Color3.fromRGB(255, 92, 82), c2 = Color3.fromRGB(255, 234, 168), recoil = true, heavy = true, pitch = 0.94 },
	CorteFlamejante = { variant = "heavy", c1 = Color3.fromRGB(255, 110, 32), c2 = Color3.fromRGB(255, 232, 128), tex = TEX.Flame, heavy = true, pitch = 0.96 },

	-- LUTADOR (14 genericos + Investida + PunhoDeMare)
	SocoDireto = { variant = "jab", c1 = Color3.fromRGB(255, 190, 96), c2 = Color3.fromRGB(255, 248, 222), pitch = 1.12 },
	PosturaDeCombate = { variant = "attack", c1 = Color3.fromRGB(255, 138, 62), c2 = Color3.fromRGB(255, 232, 165), pitch = 1.0 },
	SocoRelampago = { variant = "jab", c1 = Color3.fromRGB(255, 232, 78), c2 = Color3.fromRGB(245, 252, 255), tex = TEX.Bolt, pitch = 1.32 },
	QuebraGuarda = { variant = "heavy", c1 = Color3.fromRGB(255, 146, 56), c2 = Color3.fromRGB(255, 236, 178), pitch = 0.96 },
	Rasteira = { variant = "sweep", c1 = Color3.fromRGB(238, 196, 118), c2 = Color3.fromRGB(255, 242, 210), pitch = 1.15 },
	CorpoDeFerro = { variant = "defense", c1 = Color3.fromRGB(168, 206, 242), c2 = Color3.fromRGB(240, 248, 255), pitch = 0.88 },
	SocoDrenante = { variant = "jab", c1 = Color3.fromRGB(98, 242, 148), c2 = Color3.fromRGB(228, 255, 236), drain = true, pitch = 1.06 },
	PunhoDemolidor = { variant = "heavy", c1 = Color3.fromRGB(110, 236, 255), c2 = Color3.fromRGB(255, 236, 170), breaksProtect = true, heavy = true, pitch = 0.88 },
	OndaDeImpacto = { variant = "wave", c1 = Color3.fromRGB(255, 164, 62), c2 = Color3.fromRGB(255, 240, 185), heavy = true, pitch = 0.84 },
	GritoDeGuerra = { variant = "roar", c1 = Color3.fromRGB(255, 112, 62), c2 = Color3.fromRGB(255, 224, 115), pitch = 0.90 },
	PunhoArdente = { variant = "heavy", c1 = Color3.fromRGB(255, 96, 28), c2 = Color3.fromRGB(255, 226, 108), tex = TEX.Flame, heavy = true, pitch = 0.95 },
	GiroVarredor = { variant = "sweep", c1 = Color3.fromRGB(132, 238, 255), c2 = Color3.fromRGB(245, 255, 255), clearGust = true, pitch = 1.2 },
	FocoInterior = { variant = "heal", c1 = Color3.fromRGB(92, 245, 162), c2 = Color3.fromRGB(255, 244, 178), pitch = 1.1 },
	ImpactoTotal = { variant = "heavy", c1 = Color3.fromRGB(255, 76, 56), c2 = Color3.fromRGB(255, 228, 132), recoil = true, heavy = true, pitch = 0.82 },
	Investida = { variant = "rush", c1 = Color3.fromRGB(245, 210, 140), c2 = Color3.fromRGB(255, 252, 240), pitch = 1.1 },
	PunhoDeMare = { variant = "jab", c1 = Color3.fromRGB(58, 182, 255), c2 = Color3.fromRGB(215, 246, 255), pitch = 1.05 },

	-- MAGO (16 genericos + BrasaViva + Descarga + Estatica)
	EsferaArcana = { variant = "orb", c1 = Color3.fromRGB(168, 104, 255), c2 = Color3.fromRGB(238, 215, 255), pitch = 1.12 },
	ChamaMistica = { variant = "flames", c1 = Color3.fromRGB(255, 108, 42), c2 = Color3.fromRGB(255, 214, 108), pitch = 1.02 },
	SeloParalisante = { variant = "paralysis", c1 = Color3.fromRGB(255, 226, 56), c2 = Color3.fromRGB(255, 252, 200), pitch = 1.24 },
	PulsoVeloz = { variant = "orb", c1 = Color3.fromRGB(115, 216, 255), c2 = Color3.fromRGB(245, 252, 255), pitch = 1.35 },
	OndaArcana = { variant = "wave", c1 = Color3.fromRGB(178, 96, 255), c2 = Color3.fromRGB(130, 218, 255), pitch = 1.04 },
	RaioCongelante = { variant = "beam", c1 = Color3.fromRGB(108, 226, 255), c2 = Color3.fromRGB(240, 252, 255), tex = TEX.Diamond, pitch = 1.18 },
	FogoFatuo = { variant = "burn", c1 = Color3.fromRGB(120, 198, 255), c2 = Color3.fromRGB(255, 138, 56), pitch = 1.14 },
	MenteCalma = { variant = "defense", c1 = Color3.fromRGB(172, 138, 255), c2 = Color3.fromRGB(160, 242, 255), pitch = 1.16 },
	SifaoArcano = { variant = "orb", c1 = Color3.fromRGB(132, 248, 178), c2 = Color3.fromRGB(196, 132, 255), drain = true, pitch = 1.08 },
	NevoaDoSono = { variant = "sleep", c1 = Color3.fromRGB(186, 152, 255), c2 = Color3.fromRGB(238, 228, 255), pitch = 0.92 },
	BarreiraArcana = { variant = "wall", c1 = Color3.fromRGB(142, 192, 255), c2 = Color3.fromRGB(228, 246, 255), pitch = 1.06 },
	RunasToxicas = { variant = "toxic", c1 = Color3.fromRGB(172, 72, 248), c2 = Color3.fromRGB(145, 255, 128), pitch = 0.98 },
	CuraLuminosa = { variant = "heal", c1 = Color3.fromRGB(105, 252, 168), c2 = Color3.fromRGB(255, 248, 196), pitch = 1.18 },
	Purificacao = { variant = "cleanse", c1 = Color3.fromRGB(168, 245, 255), c2 = Color3.fromRGB(255, 255, 255), pitch = 1.24 },
	ExplosaoAstral = { variant = "stars", c1 = Color3.fromRGB(192, 118, 255), c2 = Color3.fromRGB(255, 226, 126), heavy = true, pitch = 0.92 },
	MeteoroArcano = { variant = "meteor", c1 = Color3.fromRGB(196, 92, 255), c2 = Color3.fromRGB(255, 168, 62), heavy = true, pitch = 0.80 },
	BrasaViva = { variant = "flames", c1 = Color3.fromRGB(255, 92, 28), c2 = Color3.fromRGB(255, 222, 98), pitch = 1.08 },
	Descarga = { variant = "lightning", c1 = Color3.fromRGB(255, 232, 68), c2 = Color3.fromRGB(145, 232, 255), heavy = true, pitch = 1.15 },
	Estatica = { variant = "paralysis", c1 = Color3.fromRGB(255, 236, 78), c2 = Color3.fromRGB(195, 242, 255), pitch = 1.28 },

	-- ATIRADOR (15 genericos)
	DisparoPreciso = { variant = "dart", c1 = Color3.fromRGB(115, 232, 255), c2 = Color3.fromRGB(255, 255, 255), pitch = 1.26 },
	TiroPerfurante = { variant = "beam", c1 = Color3.fromRGB(255, 196, 74), c2 = Color3.fromRGB(255, 250, 224), pitch = 1.12 },
	MiraFirme = { variant = "attack", c1 = Color3.fromRGB(255, 214, 78), c2 = Color3.fromRGB(255, 250, 215), pitch = 1.25 },
	TiroRapido = { variant = "dart", c1 = Color3.fromRGB(152, 242, 255), c2 = Color3.fromRGB(255, 255, 255), pitch = 1.38 },
	ChuvaDeProjeteis = { variant = "shots", c1 = Color3.fromRGB(130, 224, 255), c2 = Color3.fromRGB(255, 244, 190), pitch = 1.22 },
	DardoVenenoso = { variant = "dart", c1 = Color3.fromRGB(178, 84, 255), c2 = Color3.fromRGB(142, 255, 132), tex = TEX.Puff, pitch = 1.18 },
	FocoDePrecisao = { variant = "attack", c1 = Color3.fromRGB(98, 234, 255), c2 = Color3.fromRGB(255, 232, 128), pitch = 1.28 },
	DisparoDeRede = { variant = "web", c1 = Color3.fromRGB(224, 246, 255), c2 = Color3.fromRGB(132, 222, 255), pitch = 1.10 },
	TiroDeSupressao = { variant = "shots", c1 = Color3.fromRGB(255, 168, 72), c2 = Color3.fromRGB(255, 242, 198), pitch = 1.14 },
	DisparoRompeEscudo = { variant = "beam", c1 = Color3.fromRGB(108, 242, 255), c2 = Color3.fromRGB(255, 248, 200), breaksProtect = true, heavy = true, pitch = 0.98 },
	BombaDeFumaca = { variant = "smoke", c1 = Color3.fromRGB(112, 118, 152), c2 = Color3.fromRGB(190, 198, 228), pitch = 0.88 },
	MinaDeEstrepes = { variant = "spikes", c1 = Color3.fromRGB(255, 164, 72), c2 = Color3.fromRGB(225, 232, 245), pitch = 1.02 },
	DardoEletrico = { variant = "dart", c1 = Color3.fromRGB(255, 234, 72), c2 = Color3.fromRGB(165, 238, 255), tex = TEX.Bolt, pitch = 1.28 },
	RajadaTatica = { variant = "shots", c1 = Color3.fromRGB(255, 142, 72), c2 = Color3.fromRGB(255, 236, 142), heavy = true, pitch = 1.16 },
	DisparoDeElite = { variant = "beam", c1 = Color3.fromRGB(255, 86, 86), c2 = Color3.fromRGB(255, 236, 138), heavy = true, pitch = 0.90 },

	-- UNIVERSAL (10 genericos + Esforco)
	AtaqueRapido = { variant = "rush", c1 = Color3.fromRGB(215, 242, 255), c2 = Color3.fromRGB(255, 255, 255), pitch = 1.32 },
	Proteger = { variant = "dome", c1 = Color3.fromRGB(72, 232, 238), c2 = Color3.fromRGB(225, 255, 255), pitch = 1.18 },
	OlharIntimidador = { variant = "glare", c1 = Color3.fromRGB(255, 76, 88), c2 = Color3.fromRGB(255, 212, 148), pitch = 0.86 },
	GuardaAmpla = { variant = "wall", c1 = Color3.fromRGB(78, 236, 224), c2 = Color3.fromRGB(225, 255, 248), pitch = 1.08 },
	VenenoPuro = { variant = "poison", c1 = Color3.fromRGB(172, 68, 248), c2 = Color3.fromRGB(132, 255, 118), pitch = 0.96 },
	Agilidade = { variant = "speed", c1 = Color3.fromRGB(122, 242, 255), c2 = Color3.fromRGB(255, 255, 255), pitch = 1.32 },
	Desobstruir = { variant = "clear", c1 = Color3.fromRGB(156, 246, 255), c2 = Color3.fromRGB(255, 255, 255), pitch = 1.22 },
	VentoAFavor = { variant = "tailwind", c1 = Color3.fromRGB(115, 242, 225), c2 = Color3.fromRGB(255, 242, 168), pitch = 1.18 },
	MuralhaDeFerro = { variant = "defense", c1 = Color3.fromRGB(178, 208, 238), c2 = Color3.fromRGB(245, 250, 255), pitch = 0.86 },
	Recuperacao = { variant = "heal", c1 = Color3.fromRGB(98, 248, 164), c2 = Color3.fromRGB(240, 255, 228), pitch = 1.14 },
	Esforco = { variant = "rush", c1 = Color3.fromRGB(215, 218, 232), c2 = Color3.fromRGB(255, 255, 255), recoil = true, pitch = 1.0 },
}

local PROC_HANDLERS: { [string]: any } = {}

-- 1. GenSlash: cortes, estocadas, giros 360 e golpes pesados de Espadachim (100% particulas e rastros fluidos)
PROC_HANDLERS.GenSlash = {
	Charge = function(ctx)
		local cfg = ctx.cfg
		local hp = handPos(ctx.attacker)
		genSound(ctx.fx, SFX.Charge, 0.28, cfg.pitch or 1.1)
		genBurst(ctx.fx, hp, TEX.SoftGlow, cfg.c2 or Color3.new(1, 1, 1), cfg.c1, 14, 2, 7, 0.50, 0.04, 0.26, 180, 0, nil, 0.9)
		genLight(ctx.fx, hp, cfg.c1, 2.2, 10)
	end,
	Release = function(ctx)
		local cfg = ctx.cfg
		local aRoot = rootOf(ctx.attacker)
		local startPos = aRoot.CFrame:PointToWorldSpace(Vector3.new(0, 0.6, -1.8))
		local endPos = ctxCenterOfTargets(ctx)
		local travel = math.max(0.10, (ctx.timing.Impact or 0.38) - (ctx.timing.Release or 0.24))
		genSound(ctx.fx, if cfg.heavy then SFX.ReleaseHeavy else SFX.Release, 0.36, cfg.pitch or 1.05)

		if cfg.variant == "spin" then
			genFluidVortex(ctx, aRoot.Position + Vector3.new(0, -0.4, 0), cfg.c1, cfg.c2, {
				count = 3, radius = 3.4, height = 2.6, dur = 0.42, turns = 1.6, flowTex = TEX.Fire, trailW = 0.65, taper = -0.35,
			})
			genFluidSwarm(ctx, startPos, endPos, travel, cfg.c1, cfg.c2, {
				strands = 2, radius = 1.6, turns = 1.2, arcUp = 0.2, trailW = 0.65, flowTex = TEX.Fire, flowRate = 48, moteRate = 64,
			})
		elseif cfg.variant == "thrust" then
			genFluidSwarm(ctx, startPos, endPos, travel, cfg.c1, cfg.c2, {
				strands = 2, radius = 0.42, turns = 2.0, arcUp = 0.1, trailW = 0.55, flowTex = TEX.Fire, flowRate = 40, moteRate = 70, flowSz = 0.9,
			})
		else
			genFluidSwarm(ctx, startPos, endPos, travel, cfg.c1, cfg.c2, {
				strands = if cfg.heavy then 3 else 2,
				radius = if cfg.heavy then 1.35 else 0.95,
				turns = 1.1,
				arcUp = 0.45,
				trailW = if cfg.heavy then 0.85 else 0.65,
				flowTex = if cfg.tex == TEX.Flame then TEX.Fire elseif cfg.tex == TEX.Puff then TEX.Smoke else TEX.Fire,
				flowRate = if cfg.heavy then 62 else 46,
				moteRate = if cfg.heavy then 75 else 56,
				flowSz = if cfg.heavy then 1.55 else 1.15,
			})
		end
	end,
	Impact = function(ctx)
		local cfg = ctx.cfg
		local aPos = rootOf(ctx.attacker).Position
		CombatAnimator.Hitstop(ctx.attacker, if cfg.heavy then 0.055 else 0.038)
		genSound(ctx.fx, if cfg.heavy then SFX.ImpactHeavy else SFX.Impact, if cfg.heavy then 0.45 else 0.38, cfg.pitch or 1.0)
		springShake(if cfg.heavy then 0.36 else 0.22, 0.24, 44, 12, if cfg.heavy then 1.1 else 0.6)
		if cfg.heavy then fovPunch(-2.8, 0.05, 0.20) end

		for _, tModel in ipairs(ctxTargets(ctx)) do
			local hitPos = targetCenter(tModel)
			local hitLook = CFrame.lookAt(hitPos, Vector3.new(aPos.X, hitPos.Y, aPos.Z))
			if cfg.variant == "thrust" then
				genSlashMark(ctx.fx, hitLook, Vector3.new(0, 0.1, -0.7), 0, 5.4, 0.24, cfg.c1, cfg.c2)
			elseif cfg.variant == "spin" then
				genSlashMark(ctx.fx, hitLook, Vector3.new(0, 0.35, -0.7), 72, 6.0, 0.24, cfg.c1, cfg.c2)
				genSlashMark(ctx.fx, hitLook, Vector3.new(0, -0.25, -0.7), -72, 5.6, 0.22, cfg.c1, cfg.c2)
			elseif cfg.variant == "heavy" then
				genSlashMark(ctx.fx, hitLook, Vector3.new(0, 0.15, -0.7), 12, 7.2, 0.32, cfg.c1, cfg.c2)
				genFluidRing(ctx.fx, CFrame.new(hitPos.X, groundY(tModel) + 0.3, hitPos.Z), cfg.c1, cfg.c2, 7.5, 0.42, true)
			else
				genSlashMark(ctx.fx, hitLook, Vector3.new(0, 0.1, -0.7), -40, 6.2, 0.26, cfg.c1, cfg.c2)
			end
			genFluidRing(ctx.fx, CFrame.new(hitPos), cfg.c1, cfg.c2, if cfg.heavy then 7.2 else 5.2, 0.34, false)
			genBurst(ctx.fx, hitPos, TEX.SoftGlow, cfg.c2 or Color3.new(1, 1, 1), cfg.c1, if cfg.heavy then 32 else 22, 10, 26, 0.62, 0.04, 0.38, 180, 0, nil, 1.15)
			genLight(ctx.fx, hitPos, cfg.c1, if cfg.heavy then 3.4 else 2.6, 14)
			if cfg.drain then genDrainOrbs(ctx.fx, hitPos, ctx.attacker, cfg.c1, cfg.c2) end
			if cfg.breaksProtect then genShieldShatter(ctx.fx, hitPos) end
		end
		if cfg.recoil and alive(ctx.attacker) then
			genBurst(ctx.fx, targetCenter(ctx.attacker), TEX.Smoke, cfg.c1, Color3.fromRGB(255, 220, 200), 14, 4, 10, 1.0, 2.4, 0.36)
		end
	end,
	Duration = 0.90,
}

-- 2. GenMelee: socos, chutes varredores e investidas marciais (100% particulas e rastros cineticos)
PROC_HANDLERS.GenMelee = {
	Charge = function(ctx)
		local cfg = ctx.cfg
		local hp = handPos(ctx.attacker)
		genBurst(ctx.fx, hp, TEX.SoftGlow, cfg.c2 or Color3.new(1, 1, 1), cfg.c1, 16, 3, 9, 0.52, 0.04, 0.28, 180, 0, nil, 1.0)
		genBurst(ctx.fx, hp, TEX.Fire, cfg.c1, cfg.c2, 10, 2, 6, 0.65, 1.2, 0.28)
		genLight(ctx.fx, hp, cfg.c1, 2.4, 10)
	end,
	Release = function(ctx)
		local cfg = ctx.cfg
		local aRoot = rootOf(ctx.attacker)
		genSound(ctx.fx, if cfg.heavy then SFX.ReleaseHeavy else SFX.Release, 0.34, cfg.pitch or 1.05)
		local startPos = handPos(ctx.attacker)
		local endPos = ctxCenterOfTargets(ctx)
		local travel = math.max(0.09, (ctx.timing.Impact or 0.34) - (ctx.timing.Release or 0.22))
		if cfg.variant == "sweep" then
			local gy = groundY(ctx.attacker) + 0.35
			genFluidVortex(ctx, Vector3.new(aRoot.Position.X, gy, aRoot.Position.Z), cfg.c1, cfg.c2, {
				count = 2, radius = 3.2, height = 1.4, dur = 0.38, turns = 1.5, flowTex = TEX.Smoke, trailW = 0.65, taper = -0.35,
			})
			genFluidSwarm(ctx, Vector3.new(aRoot.Position.X, gy + 0.6, aRoot.Position.Z), endPos, travel, cfg.c1, cfg.c2, {
				strands = 2, radius = 1.2, turns = 1.0, arcUp = 0.15, flowTex = TEX.Smoke, trailW = 0.6,
			})
		elseif cfg.variant == "rush" then
			genFluidSwarm(ctx, aRoot.Position, endPos, travel, cfg.c1, cfg.c2, {
				strands = 2, radius = 0.85, turns = 1.2, arcUp = 0.25, flowTex = TEX.Fire, trailW = 0.7,
			})
		else
			genFluidSwarm(ctx, startPos, endPos, travel, cfg.c1, cfg.c2, {
				strands = if cfg.heavy then 3 else 2,
				radius = if cfg.heavy then 1.05 else 0.55,
				turns = 1.6,
				arcUp = 0.20,
				trailW = if cfg.heavy then 0.82 else 0.58,
				flowTex = TEX.Fire,
				flowRate = if cfg.heavy then 65 else 48,
				moteRate = if cfg.heavy then 75 else 56,
				flowSz = if cfg.heavy then 1.45 else 1.05,
			})
		end
	end,
	Impact = function(ctx)
		local cfg = ctx.cfg
		CombatAnimator.Hitstop(ctx.attacker, if cfg.heavy then 0.055 else 0.036)
		genSound(ctx.fx, if cfg.heavy then SFX.ImpactHeavy else SFX.Impact, if cfg.heavy then 0.45 else 0.38, cfg.pitch or 1.0)
		springShake(if cfg.heavy then 0.38 else 0.22, 0.24, 46, 12, if cfg.heavy then 1.2 else 0.6)
		if cfg.heavy then fovPunch(-3.0, 0.05, 0.22) end

		for _, tModel in ipairs(ctxTargets(ctx)) do
			local hitPos = targetCenter(tModel)
			genFluidRing(ctx.fx, CFrame.new(hitPos), cfg.c1, cfg.c2, if cfg.heavy then 7.8 else 5.4, 0.36, cfg.variant == "sweep")
			genBurst(ctx.fx, hitPos, TEX.SoftGlow, cfg.c2 or Color3.new(1, 1, 1), cfg.c1, if cfg.heavy then 34 else 22, 10, 28, 0.68, 0.04, 0.38, 180, 0, nil, 1.2)
			genBurst(ctx.fx, hitPos, TEX.Fire, cfg.c1, cfg.c2, if cfg.heavy then 22 else 14, 5, 16, 1.0, 2.8, 0.40)
			if cfg.heavy then
				genBurst(ctx.fx, hitPos, TEX.Smoke, cfg.c1, cfg.c2, 14, 6, 14, 1.2, 3.6, 0.46)
			end
			genLight(ctx.fx, hitPos, cfg.c1, if cfg.heavy then 3.5 else 2.6, 14)
			if cfg.drain then genDrainOrbs(ctx.fx, hitPos, ctx.attacker, cfg.c1, cfg.c2) end
			if cfg.breaksProtect then genShieldShatter(ctx.fx, hitPos) end
		end
		if cfg.recoil and alive(ctx.attacker) then
			genBurst(ctx.fx, targetCenter(ctx.attacker), TEX.Smoke, cfg.c1, Color3.fromRGB(255, 220, 200), 12, 4, 10, 1.0, 2.5, 0.34)
		end
	end,
	Duration = 0.88,
}

-- 3. GenGroundWave: soco no chao enviando ondas sismicas fluidas de poeira e energia ate os inimigos
PROC_HANDLERS.GenGroundWave = {
	Charge = function(ctx)
		local cfg = ctx.cfg
		genBurst(ctx.fx, rootOf(ctx.attacker).Position + Vector3.new(0, 1.2, 0), TEX.SoftGlow, cfg.c2 or Color3.new(1, 1, 1), cfg.c1, 18, 3, 10, 0.55, 0.05, 0.30, 180, 0, nil, 0.9)
	end,
	Release = function(ctx)
		local cfg = ctx.cfg
		local aRoot = rootOf(ctx.attacker)
		local floorPos = Vector3.new(aRoot.Position.X, groundY(ctx.attacker) + 0.35, aRoot.Position.Z)
		local travel = math.max(0.14, (ctx.timing.Impact or 0.52) - (ctx.timing.Release or 0.34))
		genSound(ctx.fx, SFX.ReleaseHeavy, 0.42, cfg.pitch or 0.85)
		genFluidRing(ctx.fx, CFrame.new(floorPos), cfg.c1, cfg.c2, 8.5, 0.44, true)
		for _, tModel in ipairs(ctxTargets(ctx)) do
			local tPos = Vector3.new(targetCenter(tModel).X, groundY(tModel) + 0.4, targetCenter(tModel).Z)
			genFluidSwarm(ctx, floorPos, tPos, travel, cfg.c1, cfg.c2, {
				strands = 2, radius = 1.15, turns = 1.2, arcUp = 0.35, flowTex = TEX.Smoke, trailW = 0.85, flowRate = 60, moteRate = 60, flowSz = 1.8,
			})
		end
		springShake(0.24, 0.22, 38, 10, 0.6)
	end,
	Impact = function(ctx)
		local cfg = ctx.cfg
		genSound(ctx.fx, SFX.ImpactHeavy, 0.44, cfg.pitch or 0.86)
		springShake(0.36, 0.28, 42, 10, 1.0)
		for _, tModel in ipairs(ctxTargets(ctx)) do
			local hitPos = targetCenter(tModel)
			local gy = groundY(tModel) + 0.25
			genFluidVortex(ctx, Vector3.new(hitPos.X, gy, hitPos.Z), cfg.c1, cfg.c2, {
				count = 2, radius = 2.8, height = 5.2, dur = 0.48, turns = 1.6, flowTex = TEX.Smoke, trailW = 0.75,
			})
			genBurst(ctx.fx, Vector3.new(hitPos.X, gy + 0.6, hitPos.Z), TEX.SoftGlow, cfg.c2 or Color3.new(1, 1, 1), cfg.c1, 30, 10, 26, 0.70, 0.05, 0.44, 65, 0, Vector3.new(0, 12, 0), 1.2)
			genBurst(ctx.fx, Vector3.new(hitPos.X, gy + 0.5, hitPos.Z), TEX.Smoke, cfg.c1, cfg.c2, 22, 6, 18, 1.6, 4.4, 0.52, 85, 110, Vector3.new(0, 8, 0))
			genLight(ctx.fx, hitPos, cfg.c1, 3.2, 15)
		end
	end,
	Duration = 0.96,
}

-- 4. GenProjectile: cometas arcanos, flechas de luz e feixes espiralados 100% fluidos (zero blocos/esferas rigidas)
PROC_HANDLERS.GenProjectile = {
	Charge = function(ctx)
		local cfg = ctx.cfg
		local hp = handPos(ctx.attacker)
		genSound(ctx.fx, SFX.Charge, 0.26, cfg.pitch or 1.15)
		genBurst(ctx.fx, hp, TEX.SoftGlow, cfg.c2 or Color3.new(1, 1, 1), cfg.c1, 18, 2, 7, 0.60, 0.04, 0.28, 180, 0, nil, 0.7)
		genBurst(ctx.fx, hp, TEX.Fire, cfg.c1, cfg.c2, 12, 1, 4, 0.75, 1.4, 0.26)
		genLight(ctx.fx, hp, cfg.c1, 2.4, 10)
	end,
	Release = function(ctx)
		local cfg = ctx.cfg
		local fromPos = handPos(ctx.attacker)
		local toPos = ctxCenterOfTargets(ctx)
		local travel = math.max(0.11, (ctx.timing.Impact or 0.44) - (ctx.timing.Release or 0.28))
		genSound(ctx.fx, if cfg.heavy then SFX.ReleaseHeavy else SFX.Release, 0.36, cfg.pitch or 1.15)

		if cfg.variant == "beam" then
			-- Feixe perfurante espiralado em 3 fios fluidos (TiroPerfurante, RaioCongelante, DisparoDeElite)
			genFluidSwarm(ctx, fromPos, toPos, travel, cfg.c1, cfg.c2, {
				strands = 3, radius = 0.58, turns = 2.6, arcUp = 0.08, trailW = 0.72, flowTex = TEX.Fire,
				flowRate = 65, moteRate = 85, flowSz = 1.15, moteSz = 0.50, trailLife = 0.26,
			})
			genFluidRing(ctx.fx, CFrame.new(fromPos), cfg.c1, cfg.c2, 3.6, 0.26, false)
		elseif cfg.variant == "dart" then
			-- Flecha/dardo de luz fluido de alta velocidade (DisparoPreciso, TiroRapido, Dardos)
			genFluidSwarm(ctx, fromPos, toPos, travel, cfg.c1, cfg.c2, {
				strands = 2, radius = 0.32, turns = 2.2, arcUp = 0.22, trailW = 0.48,
				flowTex = if cfg.tex == TEX.Puff then TEX.Smoke else TEX.Fire,
				flowRate = 48, moteRate = 76, flowSz = 0.85, moteSz = 0.42, trailLife = 0.22,
			})
		else
			-- Cometa arcano espiralado (EsferaArcana, PulsoVeloz, SifaoArcano)
			genFluidSwarm(ctx, fromPos, toPos, travel, cfg.c1, cfg.c2, {
				strands = 3, radius = 0.82, turns = 2.0, arcUp = 0.65, trailW = 0.68, flowTex = TEX.Fire,
				flowRate = 64, moteRate = 74, flowSz = 1.35, moteSz = 0.48, trailLife = 0.26,
			})
		end
	end,
	Impact = function(ctx)
		local cfg = ctx.cfg
		genSound(ctx.fx, if cfg.heavy then SFX.ImpactHeavy else SFX.Impact, if cfg.heavy then 0.44 else 0.36, cfg.pitch or 1.1)
		springShake(if cfg.heavy then 0.34 else 0.20, 0.22, 46, 12, if cfg.heavy then 1.0 else 0.5)
		if cfg.heavy then fovPunch(-2.8, 0.05, 0.20) end

		for _, tModel in ipairs(ctxTargets(ctx)) do
			local hitPos = targetCenter(tModel)
			genFluidRing(ctx.fx, CFrame.new(hitPos), cfg.c1, cfg.c2, if cfg.heavy then 7.8 else 5.6, 0.34, false)
			genBurst(ctx.fx, hitPos, TEX.SoftGlow, cfg.c2 or Color3.new(1, 1, 1), cfg.c1, if cfg.heavy then 34 else 24, 10, 28, 0.68, 0.04, 0.38, 180, 0, nil, 1.2)
			genBurst(ctx.fx, hitPos, if cfg.tex == TEX.Puff then TEX.Smoke else TEX.Fire, cfg.c1, cfg.c2, if cfg.heavy then 22 else 16, 5, 16, 1.1, 2.9, 0.40)
			genLight(ctx.fx, hitPos, cfg.c1, if cfg.heavy then 3.4 else 2.6, 14)
			if cfg.drain then genDrainOrbs(ctx.fx, hitPos, ctx.attacker, cfg.c1, cfg.c2) end
			if cfg.breaksProtect then genShieldShatter(ctx.fx, hitPos) end
		end
	end,
	Duration = 0.90,
}

-- 5. GenVolley: chuvas de projeteis, rajadas, ondas arcanas e leques de fogo 100% fluidos em particulas
PROC_HANDLERS.GenVolley = {
	Charge = function(ctx)
		local cfg = ctx.cfg
		local hp = handPos(ctx.attacker)
		genSound(ctx.fx, SFX.Charge, 0.26, cfg.pitch or 1.1)
		genBurst(ctx.fx, hp, TEX.SoftGlow, cfg.c2 or Color3.new(1, 1, 1), cfg.c1, 16, 3, 9, 0.55, 0.04, 0.28, 180, 0, nil, 0.8)
		genBurst(ctx.fx, leftHandPos(ctx.attacker), TEX.SoftGlow, cfg.c2 or Color3.new(1, 1, 1), cfg.c1, 14, 3, 9, 0.50, 0.04, 0.28, 180, 0, nil, 0.8)
		genLight(ctx.fx, hp, cfg.c1, 2.4, 10)
	end,
	Release = function(ctx)
		local cfg = ctx.cfg
		local ts = ctxTargets(ctx)
		local aRoot = rootOf(ctx.attacker)
		local travel = math.max(0.15, (ctx.timing.Impact or 0.54) - (ctx.timing.Release or 0.30))
		genSound(ctx.fx, if cfg.heavy then SFX.ReleaseHeavy else SFX.Release, 0.36, cfg.pitch or 1.12)

		local shotsCount = if cfg.variant == "wave" then 3 else 5
		for i = 1, shotsCount do
			task.delay((i - 1) * 0.045, function()
				if not ctx.alive or not alive(ctx.attacker) then return end
				local tModel = ts[((i - 1) % math.max(1, #ts)) + 1]
				if not tModel or not alive(tModel) then return end
				local fromPos = if i % 2 == 0 then leftHandPos(ctx.attacker) else handPos(ctx.attacker)
				local toPos = targetCenter(tModel) + Vector3.new((math.random() - 0.5) * 1.4, (math.random() - 0.5) * 1.0, 0)
				local segDur = math.max(0.12, travel - (i - 1) * 0.025)
				genFluidSwarm(ctx, fromPos, toPos, segDur, cfg.c1, cfg.c2, {
					strands = 1,
					radius = 0.75 + (i % 2) * 0.55,
					turns = 0.85,
					phaseOffset = i * 1.25,
					arcUp = 0.5 + (i % 3) * 0.45,
					trailW = if cfg.variant == "wave" then 0.85 else 0.55,
					flowTex = TEX.Fire,
					flowRate = 48,
					moteRate = 58,
					flowSz = if cfg.variant == "flames" or cfg.variant == "wave" then 1.45 else 1.0,
					moteSz = 0.42,
				})
			end)
		end
		if cfg.variant == "flames" then
			genBurst(ctx.fx, aRoot.CFrame:PointToWorldSpace(Vector3.new(0, 0.6, -1.8)), TEX.Fire, cfg.c1, cfg.c2, 18, 6, 16, 1.1, 2.5, 0.34)
		end
	end,
	Impact = function(ctx)
		local cfg = ctx.cfg
		genSound(ctx.fx, if cfg.heavy then SFX.ImpactHeavy else SFX.Impact, if cfg.heavy then 0.44 else 0.36, cfg.pitch or 1.08)
		springShake(if cfg.heavy then 0.34 else 0.22, 0.24, 44, 11, 0.9)
		for _, tModel in ipairs(ctxTargets(ctx)) do
			local hitPos = targetCenter(tModel)
			genFluidVortex(ctx, hitPos + Vector3.new(0, -1.5, 0), cfg.c1, cfg.c2, {
				count = 2, radius = 2.4, height = 3.8, dur = 0.42, turns = 1.4, flowTex = TEX.Fire, trailW = 0.55,
			})
			genBurst(ctx.fx, hitPos, TEX.Fire, cfg.c1, cfg.c2, if cfg.heavy then 26 else 18, 6, 18, 1.2, 3.0, 0.42)
			genBurst(ctx.fx, hitPos, TEX.SoftGlow, cfg.c2 or Color3.new(1, 1, 1), cfg.c1, if cfg.heavy then 30 else 20, 8, 24, 0.62, 0.04, 0.38, 180, 0, nil, 1.15)
			genLight(ctx.fx, hitPos, cfg.c1, 3.0, 14)
		end
	end,
	Duration = 0.95,
}

-- 6. GenSkyStrike: raios celestes (Descarga) e meteoros arcanos (MeteoroArcano) 100% fluidos em enxames celestes
PROC_HANDLERS.GenSkyStrike = {
	Charge = function(ctx)
		local cfg = ctx.cfg
		local hp = handPos(ctx.attacker)
		genSound(ctx.fx, SFX.Charge, 0.34, cfg.pitch or 0.95)
		genBurst(ctx.fx, hp + Vector3.new(0, 1.2, 0), TEX.SoftGlow, cfg.c2 or Color3.new(1, 1, 1), cfg.c1, 20, 3, 10, 0.60, 0.05, 0.32, 180, 0, nil, 0.9)
		for _, tModel in ipairs(ctxTargets(ctx)) do
			local skyPos = targetCenter(tModel) + Vector3.new(0, 13.5, 0)
			genFluidVortex(ctx, skyPos, cfg.c1, cfg.c2, {
				count = 2, radius = 4.2, height = -1.2, dur = 0.42, turns = 1.5, flowTex = TEX.Fire, trailW = 0.75, taper = 0.45,
			})
		end
	end,
	Release = function(ctx)
		local cfg = ctx.cfg
		local travel = math.max(0.15, (ctx.timing.Impact or 0.56) - (ctx.timing.Release or 0.32))
		genSound(ctx.fx, SFX.ReleaseHeavy, 0.40, cfg.pitch or 0.95)
		for _, tModel in ipairs(ctxTargets(ctx)) do
			local hitPos = targetCenter(tModel)
			local skyPos = hitPos + Vector3.new(if cfg.variant == "meteor" then 5.2 else 0.8, 15.0, 0)
			if cfg.variant == "meteor" then
				genFluidSwarm(ctx, skyPos, hitPos, travel, cfg.c1, cfg.c2, {
					strands = 3, radius = 1.15, turns = 1.8, arcUp = 0, trailW = 1.35, flowTex = TEX.Fire,
					flowRate = 85, moteRate = 90, flowSz = 2.4, moteSz = 0.65, trailLife = 0.30,
				})
			else
				genFluidSwarm(ctx, skyPos, hitPos, math.min(travel, 0.16), cfg.c1, cfg.c2, {
					strands = 3, radius = 1.45, turns = 2.4, arcUp = 0, trailW = 0.52, flowTex = TEX.Fire,
					flowRate = 55, moteRate = 95, flowSz = 1.1, moteSz = 0.52, trailLife = 0.22,
				})
			end
		end
	end,
	Impact = function(ctx)
		local cfg = ctx.cfg
		genSound(ctx.fx, SFX.ImpactHeavy, 0.46, cfg.pitch or 0.90)
		springShake(0.42, 0.30, 46, 10, 1.4)
		fovPunch(-3.5, 0.055, 0.24)
		for _, tModel in ipairs(ctxTargets(ctx)) do
			local hitPos = targetCenter(tModel)
			local gy = groundY(tModel) + 0.25
			genFluidVortex(ctx, Vector3.new(hitPos.X, gy, hitPos.Z), cfg.c1, cfg.c2, {
				count = 3, radius = 3.4, height = 6.2, dur = 0.54, turns = 2.0, flowTex = TEX.Fire, trailW = 0.85,
			})
			genFluidRing(ctx.fx, CFrame.new(hitPos.X, gy + 0.3, hitPos.Z), cfg.c1, cfg.c2, 9.5, 0.44, cfg.variant == "meteor")
			genBurst(ctx.fx, hitPos, TEX.SoftGlow, cfg.c2 or Color3.new(1, 1, 1), cfg.c1, 38, 12, 32, 0.78, 0.05, 0.44, 180, 0, nil, 1.25)
			genBurst(ctx.fx, hitPos, TEX.Fire, cfg.c1, cfg.c2, 28, 7, 22, 1.5, 4.2, 0.48)
			genLight(ctx.fx, hitPos, cfg.c1, 3.6, 18)
		end
	end,
	Duration = 1.00,
}

-- 7. GenHex: maldicoes, selos de status, nevoas, fumaca e olhar intimidador (100% particulas fluidas)
PROC_HANDLERS.GenHex = {
	Charge = function(ctx)
		local cfg = ctx.cfg
		local hp = handPos(ctx.attacker)
		genSound(ctx.fx, SFX.Charge, 0.26, cfg.pitch or 1.05)
		genBurst(ctx.fx, hp, TEX.SoftGlow, cfg.c2 or Color3.new(1, 1, 1), cfg.c1, 14, 2, 7, 0.50, 0.04, 0.28, 180, 0, nil, 0.7)
	end,
	Release = function(ctx)
		local cfg = ctx.cfg
		genSound(ctx.fx, SFX.Release, 0.30, cfg.pitch or 1.0)
		local fromPos = handPos(ctx.attacker)
		local toPos = ctxCenterOfTargets(ctx)
		local travel = math.max(0.14, (ctx.timing.Impact or 0.48) - (ctx.timing.Release or 0.28))
		if cfg.variant == "glare" then
			genBurst(ctx.fx, rootOf(ctx.attacker).Position + Vector3.new(0, 1.5, 0), TEX.SoftGlow, cfg.c2 or Color3.new(1, 1, 1), cfg.c1, 22, 6, 18, 0.65, 0.04, 0.34, 180, 0, nil, 1.2)
			return
		end
		local isCloud = cfg.variant == "smoke" or cfg.variant == "sleep" or cfg.variant == "poison"
		genFluidSwarm(ctx, fromPos, toPos, travel, cfg.c1, cfg.c2, {
			strands = 2, radius = 0.85, turns = 1.6, arcUp = 1.2, trailW = 0.62,
			flowTex = if isCloud then TEX.Smoke else TEX.Fire,
			flowRate = 52, moteRate = 58, flowSz = 1.45,
		})
	end,
	Impact = function(ctx)
		local cfg = ctx.cfg
		genSound(ctx.fx, SFX.Impact, 0.30, cfg.pitch or 1.05)
		local isCloud = cfg.variant == "smoke" or cfg.variant == "sleep" or cfg.variant == "poison"
		for _, tModel in ipairs(ctxTargets(ctx)) do
			local hitPos = targetCenter(tModel)
			local gy = groundY(tModel) + 0.25
			genFluidVortex(ctx, Vector3.new(hitPos.X, gy, hitPos.Z), cfg.c1, cfg.c2, {
				count = 2, radius = 2.6, height = 4.4, dur = 0.56, turns = 1.8,
				flowTex = if isCloud then TEX.Smoke else TEX.Fire, trailW = 0.60,
			})
			genBurst(ctx.fx, hitPos, if isCloud then TEX.Smoke else TEX.Fire, cfg.c1, cfg.c2, if cfg.variant == "smoke" then 28 else 20, 4, 14, if cfg.variant == "smoke" then 2.2 else 1.2, 3.8, 0.54)
			genBurst(ctx.fx, hitPos, TEX.SoftGlow, cfg.c2 or Color3.new(1, 1, 1), cfg.c1, 24, 6, 18, 0.55, 0.04, 0.42, 180, 0, nil, 0.9)
			genLight(ctx.fx, hitPos, cfg.c1, 2.4, 12)
		end
	end,
	Duration = 0.92,
}

-- 8. GenBuff: posturas, gritos de guerra, danca das espadas, corpo de ferro e agilidade (vortice ascendente fluido)
PROC_HANDLERS.GenBuff = {
	Charge = function(ctx)
		local cfg = ctx.cfg
		local aPos = rootOf(ctx.attacker).Position
		genSound(ctx.fx, SFX.Charge, 0.30, cfg.pitch or 1.1)
		genBurst(ctx.fx, aPos, TEX.SoftGlow, cfg.c2 or Color3.new(1, 1, 1), cfg.c1, 18, 3, 9, 0.50, 0.04, 0.30, 180, 0, Vector3.new(0, 8, 0), 1.0)
	end,
	Release = function(ctx)
		local cfg = ctx.cfg
		genSound(ctx.fx, SFX.Release, 0.32, cfg.pitch or 1.12)
		local targets = if cfg.variant == "roar" then ctxTargets(ctx) else { ctx.attacker }
		for _, m in ipairs(targets) do
			if not alive(m) then continue end
			local pos = targetCenter(m)
			local gy = groundY(m) + 0.25
			local strands = if cfg.variant == "swords" then 3 else 2
			genFluidVortex(ctx, Vector3.new(pos.X, gy, pos.Z), cfg.c1, cfg.c2, {
				count = strands, radius = if cfg.variant == "swords" then 3.0 else 2.5,
				height = 4.8, dur = 0.58, turns = if cfg.variant == "swords" then 2.6 else 1.8,
				flowTex = TEX.Fire, trailW = if cfg.variant == "swords" then 0.72 else 0.55,
			})
			genBurst(ctx.fx, Vector3.new(pos.X, gy + 0.6, pos.Z), TEX.SoftGlow, cfg.c2 or Color3.new(1, 1, 1), cfg.c1, 28, 5, 14, 0.55, 0.04, 0.48, 55, 0, Vector3.new(0, 14, 0), 1.2)
			genBurst(ctx.fx, Vector3.new(pos.X, gy + 0.8, pos.Z), TEX.Fire, cfg.c1, cfg.c2, 16, 3, 10, 0.9, 2.2, 0.42, 65, 90, Vector3.new(0, 8, 0))
			genLight(ctx.fx, pos, cfg.c1, 2.6, 12)
		end
	end,
	Impact = function() end,
	Duration = 0.90,
}

-- 9. GenShield: Proteger, Guarda Ampla e Barreira Arcana (barreira eterea 3D em particulas e fitas orbitais)
PROC_HANDLERS.GenShield = {
	Charge = function(ctx)
		local cfg = ctx.cfg
		genSound(ctx.fx, SFX.Charge, 0.28, cfg.pitch or 1.15)
		genBurst(ctx.fx, targetCenter(ctx.attacker), TEX.SoftGlow, cfg.c2 or Color3.new(1, 1, 1), cfg.c1, 16, 3, 8, 0.50, 0.04, 0.28, 180, 0, nil, 0.8)
	end,
	Release = function(ctx)
		local cfg = ctx.cfg
		local aRoot = rootOf(ctx.attacker)
		genSound(ctx.fx, SFX.Release, 0.32, cfg.pitch or 1.15)
		if cfg.variant == "dome" then
			local gy = groundY(ctx.attacker) + 0.3
			genFluidVortex(ctx, Vector3.new(aRoot.Position.X, gy, aRoot.Position.Z), cfg.c1, cfg.c2, {
				count = 3, radius = 3.2, height = 4.6, dur = 0.56, turns = 2.2, flowTex = TEX.Fire, trailW = 0.68, taper = 0.15,
			})
			genBurst(ctx.fx, aRoot.Position, TEX.SoftGlow, cfg.c2 or Color3.new(1, 1, 1), cfg.c1, 28, 6, 14, 0.62, 0.05, 0.48, 180, 0, nil, 0.6)
			genLight(ctx.fx, aRoot.Position, cfg.c1, 2.8, 13)
		else
			-- Muralha fluida de energia na frente do time (particulas + 3 arcos horizontais de luz)
			local wallCenter = aRoot.CFrame:PointToWorldSpace(Vector3.new(0, 0.8, -3.4))
			local right = aRoot.CFrame.RightVector
			for row = -1, 1 do
				local fromP = wallCenter - right * 5.8 + Vector3.new(0, row * 1.4, 0)
				local toP = wallCenter + right * 5.8 + Vector3.new(0, row * 1.4, 0)
				genFluidSwarm(ctx, fromP, toP, 0.34, cfg.c1, cfg.c2, {
					strands = 1, radius = 0.35, turns = 1.0, arcUp = 0.25, trailW = 0.95, flowTex = TEX.Fire, flowRate = 44, moteRate = 54, trailLife = 0.38,
				})
			end
			genBurst(ctx.fx, wallCenter, TEX.SoftGlow, cfg.c2 or Color3.new(1, 1, 1), cfg.c1, 28, 6, 16, 0.60, 0.05, 0.48, 140, 0, Vector3.new(0, 4, 0), 1.0)
			genLight(ctx.fx, wallCenter, cfg.c1, 2.8, 14)
		end
	end,
	Impact = function() end,
	Duration = 0.90,
}

-- 10. GenHazard: laminas, runas toxicas e rede pegajosa no campo inimigo (100% particulas e rastros fluidos)
PROC_HANDLERS.GenHazard = {
	Charge = function(ctx)
		local cfg = ctx.cfg
		genSound(ctx.fx, SFX.Charge, 0.26, cfg.pitch or 1.05)
		genBurst(ctx.fx, handPos(ctx.attacker), TEX.SoftGlow, cfg.c2 or Color3.new(1, 1, 1), cfg.c1, 14, 2, 7, 0.48, 0.04, 0.26, 180, 0, nil, 0.8)
	end,
	Release = function(ctx)
		local cfg = ctx.cfg
		local fromPos = handPos(ctx.attacker)
		local center, gy = ctxCenterOfTargets(ctx)
		local landCenter = Vector3.new(center.X, gy + 0.3, center.Z)
		local travel = math.max(0.15, (ctx.timing.Impact or 0.48) - (ctx.timing.Release or 0.28))
		genSound(ctx.fx, SFX.Release, 0.32, cfg.pitch or 1.05)
		for i = 1, 3 do
			local off = Vector3.new((i - 2) * 2.4, 0, ((i % 2) - 0.5) * 1.4)
			genFluidSwarm(ctx, fromPos, landCenter + off, travel, cfg.c1, cfg.c2, {
				strands = 1, radius = 0.45, turns = 0.8, arcUp = 2.8, trailW = 0.42,
				flowTex = if cfg.variant == "toxic" then TEX.Smoke else TEX.Fire, flowRate = 36, moteRate = 52,
			})
		end
	end,
	Impact = function(ctx)
		local cfg = ctx.cfg
		local center, gy = ctxCenterOfTargets(ctx)
		local floorCenter = Vector3.new(center.X, gy + 0.25, center.Z)
		genSound(ctx.fx, SFX.Impact, 0.32, cfg.pitch or 1.02)
		genFluidVortex(ctx, floorCenter, cfg.c1, cfg.c2, {
			count = 2, radius = 4.2, height = 1.2, dur = 0.52, turns = 1.5,
			flowTex = if cfg.variant == "toxic" then TEX.Smoke else TEX.Fire, trailW = 0.55, taper = -0.15,
		})
		if cfg.variant == "toxic" then
			genBurst(ctx.fx, floorCenter + Vector3.new(0, 0.5, 0), TEX.Smoke, cfg.c1, cfg.c2, 26, 4, 14, 1.5, 3.8, 0.56, 80, 90, Vector3.new(0, 4, 0))
		else
			genBurst(ctx.fx, floorCenter + Vector3.new(0, 0.4, 0), TEX.SoftGlow, cfg.c2 or Color3.new(1, 1, 1), cfg.c1, 30, 8, 22, 0.58, 0.04, 0.46, 85, 0, Vector3.new(0, 5, 0), 1.15)
		end
		genLight(ctx.fx, floorCenter + Vector3.new(0, 1.0, 0), cfg.c1, 2.5, 13)
	end,
	Duration = 0.92,
}

-- 11. GenHeal: cura individual/em grupo e purificacao radiante (helice ascendente serena de luz e particulas)
PROC_HANDLERS.GenHeal = {
	Charge = function(ctx)
		local cfg = ctx.cfg
		genSound(ctx.fx, SFX.Charge, 0.28, cfg.pitch or 1.18)
		genBurst(ctx.fx, targetCenter(ctx.attacker), TEX.SoftGlow, cfg.c2 or Color3.new(1, 1, 1), cfg.c1, 18, 2, 7, 0.52, 0.04, 0.32, 180, 0, Vector3.new(0, 6, 0))
	end,
	Release = function(ctx)
		local cfg = ctx.cfg
		genSound(ctx.fx, SFX.Release, 0.30, cfg.pitch or 1.2)
		local targets = ctxTargets(ctx)
		for _, m in ipairs(targets) do
			if not alive(m) then continue end
			local pos = targetCenter(m)
			local gy = groundY(m) + 0.20
			genFluidVortex(ctx, Vector3.new(pos.X, gy, pos.Z), cfg.c1, cfg.c2, {
				count = 2, radius = 2.5, height = 5.2, dur = 0.58, turns = 2.0, flowTex = TEX.Fire, trailW = 0.52,
			})
			genBurst(ctx.fx, Vector3.new(pos.X, gy + 0.6, pos.Z), TEX.SoftGlow, cfg.c2 or Color3.new(1, 1, 1), cfg.c1, 30, 4, 11, 0.56, 0.05, 0.54, 55, 0, Vector3.new(0, 10, 0), 0.7)
			genLight(ctx.fx, pos, cfg.c1, 2.6, 13)
		end
	end,
	Impact = function() end,
	Duration = 0.92,
}

-- 12. GenWind: Vento a Favor e Desobstruir (ciclones 3D fluidos de ventania varrendo a arena)
PROC_HANDLERS.GenWind = {
	Charge = function(ctx)
		local cfg = ctx.cfg
		genSound(ctx.fx, SFX.Charge, 0.26, cfg.pitch or 1.2)
		genBurst(ctx.fx, rootOf(ctx.attacker).Position, TEX.SoftGlow, cfg.c2 or Color3.new(1, 1, 1), cfg.c1, 16, 6, 14, 0.48, 0.04, 0.28, 180, 0, nil, 1.2)
	end,
	Release = function(ctx)
		local cfg = ctx.cfg
		local aRoot = rootOf(ctx.attacker)
		genSound(ctx.fx, SFX.Release, 0.34, cfg.pitch or 1.2)
		local gy = groundY(ctx.attacker) + 0.4
		genFluidVortex(ctx, Vector3.new(aRoot.Position.X, gy, aRoot.Position.Z), cfg.c1, cfg.c2, {
			count = 3, radius = 4.2, height = 5.5, dur = 0.56, turns = 2.2, flowTex = TEX.Smoke, trailW = 0.72, taper = -0.35,
		})
		genBurst(ctx.fx, aRoot.Position + Vector3.new(0, 1.0, 0), TEX.SoftGlow, cfg.c2 or Color3.new(1, 1, 1), cfg.c1, 32, 12, 28, 0.58, 0.04, 0.44, 120, 0, nil, 1.3)
		genBurst(ctx.fx, aRoot.Position + Vector3.new(0, 0.8, 0), TEX.Smoke, cfg.c1, cfg.c2, 18, 8, 18, 1.3, 3.6, 0.46, 110, 120)
		genLight(ctx.fx, aRoot.Position, cfg.c1, 2.6, 14)
	end,
	Impact = function() end,
	Duration = 0.90,
}

--------------------------------------------------------------------
-- Tecnicas Exclusivas AAA do SUKUNA (Jujutsu Kaisen — Secreto)
-- Delegadas integralmente ao pacote modular ReplicatedStorage/Sukuna/*
-- (ZERO cones, ZERO esferas, ZERO cilindros de Neon!)
--------------------------------------------------------------------
PROC_HANDLERS.SukunaFortificacao = {
	Charge = function(ctx)
		SukunaVFX.PlayFortificacao(ctx.attacker, ctx.timing)
	end,
	Release = function() end,
	Impact = function() end,
	Duration = 1.10,
}

PROC_HANDLERS.SukunaDesmantelar = {
	Charge = function(ctx)
		SukunaVFX.PlayDesmantelar(ctx.attacker, ctx.target, ctx.timing)
	end,
	Release = function() end,
	Impact = function() end,
	Duration = 1.15,
}

PROC_HANDLERS.SukunaClivar = {
	Charge = function(ctx)
		SukunaVFX.PlayClivar(ctx.attacker, ctx.target, ctx.timing)
	end,
	Release = function() end,
	Impact = function() end,
	Duration = 1.25,
}

PROC_HANDLERS.SukunaSantuario = {
	Charge = function(ctx)
		SukunaVFX.PlaySantuario(ctx.attacker, ctx.target, ctxTargets(ctx), ctx.timing)
	end,
	Release = function() end,
	Impact = function() end,
	Duration = 1.45,
}

PROC_HANDLERS.SukunaFuga = {
	Charge = function(ctx)
		SukunaVFX.PlayFuga(ctx.attacker, ctx.target, ctxTargets(ctx), ctx.timing)
	end,
	Release = function() end,
	Impact = function() end,
	Duration = 1.65,
}

local function fallbackGenericStyle(moveId: string?)
	local mv = moveId and Moves.Get(moveId)
	local col = Color3.fromRGB(165, 224, 255)
	if mv then
		if mv.Type == "Espadachim" then col = Color3.fromRGB(165, 224, 255)
		elseif mv.Type == "Lutador" then col = Color3.fromRGB(255, 170, 78)
		elseif mv.Type == "Mago" then col = Color3.fromRGB(178, 112, 255)
		elseif mv.Type == "Atirador" then col = Color3.fromRGB(115, 232, 255)
		end
	end
	return { variant = "jab", c1 = col, c2 = Color3.new(1, 1, 1), pitch = 1.05 }
end

--------------------------------------------------------------------
-- API
--------------------------------------------------------------------
local function runEffect(name: string, attacker: Model, target: Model, timing, track: AnimationTrack?, exactTiming: boolean?, moveId: string?, targetModels: { Model }?)
	local isProc = false
	local handler = HANDLERS[name]
	if not handler then
		handler = PROC_HANDLERS[name]
		isProc = handler ~= nil
	end
	if not handler or not attacker or not rootOf(attacker) then
		return false
	end
	target = if target and rootOf(target) then target else attacker

	local fx: Model?
	if isProc then
		local m = Instance.new("Model")
		m.Name = "ProcVfx_" .. name
		m.Parent = container()
		fx = m
	else
		fx = acquire(name)
	end
	if not fx then
		return false
	end

	local ctx = {
		fx = fx,
		attacker = attacker,
		target = target,
		targets = targetModels,
		timing = timing or {},
		cfg = if isProc then ((moveId and GENERIC_STYLES[moveId]) or fallbackGenericStyle(moveId)) else nil,
		alive = true,
	}
	if isProc then
		procActive[fx] = ctx
	end

	local fired = {}
	local function fire(phase)
		if fired[phase] or not ctx.alive then
			return
		end
		fired[phase] = true
		local fn = handler[phase]
		-- atacante ou alvo saiu do mundo: pula a fase (o efeito e liberado no fim normalmente)
		if fn and alive(ctx.attacker) and alive(ctx.target) then
			local ok, err = pcall(fn, ctx)
			if not ok then
				warn("[Vfx] " .. name .. "." .. phase .. ": " .. tostring(err))
			end
		end
	end
	local conns = {}
	if track then
		for _, phase in PHASES do
			table.insert(conns, track:GetMarkerReachedSignal(phase):Connect(function()
				fire(phase)
			end))
		end
	end
	-- reserva: se o marcador nao chegar (animacao nao carregou), dispara pelo tempo do golpe
	for _, phase in PHASES do
		local t = ctx.timing[phase]
		if t then
			task.delay(t + (if track and not exactTiming then 0.1 else 0), function()
				fire(phase)
			end)
		elseif not track then
			fire(phase)
		end
	end
	local myCutIn = cutInState
	task.delay((ctx.timing.Impact or 0) + (handler.Duration or 1.2), function()
		ctx.alive = false
		if ctx.follow then
			ctx.follow:Disconnect()
		end
		if ctx.onCleanup then
			pcall(ctx.onCleanup)
		end
		for _, c in conns do
			c:Disconnect()
		end
		if myCutIn and cutInState == myCutIn then
			clearCutIn()
		end
		if isProc then
			procActive[fx] = nil
			if fx.Parent then
				fx:Destroy()
			end
		else
			release(fx)
		end
	end)
	return true
end

function VfxController.HasVfx(name: string?): boolean
	if not name then
		return false
	end
	if PROC_HANDLERS[name] ~= nil then
		return true
	end
	return HANDLERS[name] ~= nil and VFX:FindFirstChild(name) ~= nil
end

function VfxController.Play(name: string, attacker: Model, target: Model?)
	return runEffect(name, attacker, target, nil, nil)
end

local function loadTrack(model: Model, animName: string): AnimationTrack?
	local cache = tracks[model]
	if cache and cache[animName] then
		return cache[animName]
	end
	local folder = model:FindFirstChild("Animations")
	local anim = folder and folder:FindFirstChild(animName)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not (anim and animator) then
		return nil
	end
	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if not ok then
		return nil
	end
	track.Priority = Enum.AnimationPriority.Action2
	track.Looped = false
	tracks[model] = cache or {}
	tracks[model][animName] = track
	return track
end

-- Carrega antes as animacoes de golpe de um modelo (evita atraso no primeiro uso)
function VfxController.Preload(model: Model, moveIds: { string }?)
	if not model then
		return
	end
	for _, id in moveIds or {} do
		local move = Moves.Get(id)
		if move and move.Anim and not CombatAnimator.Has(move.Anim) then
			loadTrack(model, move.Anim)
		end
	end
end

-- Toca animacao + efeito de um golpe. Retorna false se o golpe nao tem Anim/Vfx.
function VfxController.PlayMove(moveId: string, attacker: Model, target: Model?, targetModels: { Model }?)
	local move = Moves.Get(moveId)
	if not move or not move.Vfx or not attacker then
		return false
	end
	local track: AnimationTrack? = nil
	local usedProcedural = false
	if move.Anim and CombatAnimator.Has(move.Anim) then
		usedProcedural = CombatAnimator.Play(attacker, move.Anim, move.Timing, target)
	end
	if not usedProcedural then
		track = move.Anim and loadTrack(attacker, move.Anim)
		if track then
			track:Play(0.05)
			track:AdjustSpeed(move.AnimSpeed or 1)
		elseif move.Anim then
			-- Fallback procedural caso o modelo nao possua a AnimationTrack especifica (ex.: ComboMarcial)
			usedProcedural = CombatAnimator.Play(attacker, "PunchHeavy", move.Timing)
		end
	end
	if move.CutIn then
		playCutIn(move, attacker, move.Timing)
	end
	return runEffect(move.Vfx, attacker, target, move.Timing, track, move.AnimSpeed ~= nil or usedProcedural, moveId, targetModels)
end

-- Flash de ColorCorrection so em golpe critico
function VfxController.CritFlash()
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "CritFlash"
	cc.Brightness = 0.08
	cc.Contrast = 0.10
	cc.Parent = Lighting
	tween(cc, 0.25, { Brightness = 0, Contrast = 0 }).Completed:Once(function()
		cc:Destroy()
	end)
end

function VfxController.PlayDomainSlash(targets: { Model })
	SukunaVFX.OnDomainSlashEvent(targets)
end

function VfxController.CloseDomain()
	SukunaVFX.OnDomainEnd()
end

-- Limpa tudo no fim da batalha
function VfxController.Cleanup()
	SukunaVFX.Cleanup()
	CombatAnimator.Cleanup()
	clearCutIn()
	for m, ctx in procActive do
		procActive[m] = nil
		ctx.alive = false
		if ctx.follow then
			ctx.follow:Disconnect()
		end
		if m.Parent then
			m:Destroy()
		end
	end
	for m in active do
		active[m] = nil
		m:Destroy()
	end
	for name, list in pool do
		for _, m in list do
			m:Destroy()
		end
		pool[name] = nil
	end
	local f = workspace:FindFirstChild("BattleVfx")
	if f then
		f:Destroy()
	end
	table.clear(tracks)
end

return VfxController
