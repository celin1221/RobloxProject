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
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local Moves = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("Moves"))
local CombatAnimator = require(ReplicatedStorage:WaitForChild("CombatAnimator"))
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
		if cam and cam.CameraType == Enum.CameraType.Scriptable then
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
		setBackBisentoHidden(ctx.attacker, false)
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

-- Tudo Roxo (Setero, Lendario assinatura): Azul (mao esq) + Vermelho (mao dir) se fundem e disparam Vazio Roxo
HANDLERS.TudoRoxo = {
	Charge = function(ctx)
		local fx = ctx.fx
		playSfx(fx.Origin, "ChargeSfx")
		local t0 = os.clock()
		local dur = math.max(0.4, (ctx.timing.Release or 0.95) - (ctx.timing.Charge or 0.25))
		fx.BlueOrb.Size = Vector3.new(0.25, 0.25, 0.25)
		fx.BlueShell.Size = Vector3.new(0.45, 0.45, 0.45)
		fx.RedOrb.Size = Vector3.new(0.25, 0.25, 0.25)
		fx.RedShell.Size = Vector3.new(0.45, 0.45, 0.45)
		fx.BlueOrb.Transparency = 0.05
		fx.BlueShell.Transparency = 0.3
		fx.RedOrb.Transparency = 0.05
		fx.RedShell.Transparency = 0.3
		tween(fx.BlueOrb, 0.35, { Size = Vector3.new(0.95, 0.95, 0.95) }, Enum.EasingStyle.Back)
		tween(fx.BlueShell, 0.35, { Size = Vector3.new(1.5, 1.5, 1.5) }, Enum.EasingStyle.Back)
		tween(fx.RedOrb, 0.35, { Size = Vector3.new(0.95, 0.95, 0.95) }, Enum.EasingStyle.Back)
		tween(fx.RedShell, 0.35, { Size = Vector3.new(1.5, 1.5, 1.5) }, Enum.EasingStyle.Back)
		emit(fx.BlueOrb, "GatherBlue", 18)
		emit(fx.RedOrb, "GatherRed", 18)
		tween(fx.Origin:FindFirstChild("ChargeLight"), 0.55, { Brightness = 6 })

		ctx.follow = RunService.RenderStepped:Connect(function()
			if not ctx.alive or not alive(ctx.attacker) then
				return
			end
			local a = math.clamp((os.clock() - t0) / dur, 0, 1)
			local root = rootOf(ctx.attacker)
			local meet = root.CFrame:PointToWorldSpace(Vector3.new(0, 0.5, -2.6))
			local lPos = leftHandPos(ctx.attacker)
			local rPos = handPos(ctx.attacker)
			local merge = math.clamp((a - 0.35) / 0.65, 0, 1)
			merge = merge * merge
			local orbL = lPos:Lerp(meet, merge)
			local orbR = rPos:Lerp(meet, merge)
			fx.Origin.CFrame = CFrame.new(meet)
			fx.BlueOrb.Position = orbL
			fx.BlueShell.Position = orbL
			fx.RedOrb.Position = orbR
			fx.RedShell.Position = orbR
		end)
	end,
	Release = function(ctx)
		local fx = ctx.fx
		if ctx.follow then
			ctx.follow:Disconnect()
			ctx.follow = nil
		end
		fx.BlueOrb.Transparency = 1
		fx.BlueShell.Transparency = 1
		fx.RedOrb.Transparency = 1
		fx.RedShell.Transparency = 1

		local root = rootOf(ctx.attacker)
		local startPos = root.CFrame:PointToWorldSpace(Vector3.new(0, 0.5, -2.6))
		local endPos = targetCenter(ctx.target)
		fx.Origin.CFrame = CFrame.lookAt(startPos, endPos)
		fx.VoidOrb.CFrame = fx.Origin.CFrame
		fx.VoidShell.CFrame = fx.Origin.CFrame
		fx.VoidOrb.Size = Vector3.new(0.6, 0.6, 0.6)
		fx.VoidOrb.Transparency = 0.02
		fx.VoidShell.Size = Vector3.new(1.0, 1.0, 1.0)
		fx.VoidShell.Transparency = 0.25
		tween(fx.VoidOrb, 0.14, { Size = Vector3.new(2.0, 2.0, 2.0) }, Enum.EasingStyle.Back)
		tween(fx.VoidShell, 0.14, { Size = Vector3.new(3.2, 3.2, 3.2) }, Enum.EasingStyle.Back)
		setDisc(fx.VoidRing1, fx.Origin.CFrame * CFrame.Angles(0.4, 0, 0.5), 4.2, 0.1)
		setDisc(fx.VoidRing2, fx.Origin.CFrame * CFrame.Angles(-0.5, 0.4, -0.4), 3.4, 0.15)
		emit(fx.VoidOrb, "FuseFlash", 6)
		emit(fx.VoidOrb, "VoidSparks", 22)
		fx.VoidOrb.VoidTrail.Enabled = true
		fx.Origin.VoidBeam.Enabled = true
		playSfx(fx.Origin, "ReleaseSfx")
		tween(fx.Origin:FindFirstChild("ChargeLight"), 0.25, { Brightness = 0 })

		local travel = math.max(0.22, (ctx.timing.Impact or 1.45) - (ctx.timing.Release or 0.95) - 0.02)
		local t0 = os.clock()
		ctx.follow = RunService.RenderStepped:Connect(function()
			local a = math.clamp((os.clock() - t0) / travel, 0, 1)
			local eased = a * a * a
			local pos = startPos:Lerp(endPos, eased)
			fx.VoidOrb.Position = pos
			fx.VoidShell.Position = pos
			fx.VoidRing1.CFrame = CFrame.new(pos) * CFrame.Angles(0.4 + a * 6, a * 8, 0.5)
			fx.VoidRing2.CFrame = CFrame.new(pos) * CFrame.Angles(-0.5, -a * 9, -0.4 + a * 5)
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
		fx.VoidOrb.VoidTrail.Enabled = false
		fx.Origin.VoidBeam.Enabled = false
		tween(fx.VoidOrb, 0.12, { Size = Vector3.new(4.2, 4.2, 4.2), Transparency = 1 })
		tween(fx.VoidShell, 0.14, { Size = Vector3.new(6.0, 6.0, 6.0), Transparency = 1 })
		tweenDisc(fx.VoidRing1, 0.14, 7.0, 1)
		tweenDisc(fx.VoidRing2, 0.14, 6.0, 1)

		fx.Hit.CFrame = CFrame.new(hitPos)
		playSfx(fx.Hit, "ImpactSfx")
		impactFrame(0.06, 0.26)
		emit(fx.Hit, "FlashStar", 8)
		emit(fx.Hit, "VoidSmoke", 38)
		emit(fx.Hit, "DebrisSparks", 42)
		setDisc(fx.ShockRing1, CFrame.new(hitPos) * CFrame.Angles(0.3, 0, -0.25), 2.4, 0.05)
		setDisc(fx.ShockRing2, CFrame.new(hitPos) * CFrame.Angles(-0.35, 0.4, 0.35), 2.0, 0.08)
		tweenDisc(fx.ShockRing1, 0.42, 13.5, 1)
		tweenDisc(fx.ShockRing2, 0.48, 11.5, 1)
		pulseLight(fx.Hit:FindFirstChild("HitLight"), 12, 24)
		shake(0.24, 0.55)
	end,
	Duration = 2.0,
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

		-- Domo em hemisferio + coluna celeste ascendente!
		fx.SupernovaCore.CFrame = CFrame.new(floorCenter + Vector3.new(0, 1.2, 0))
		fx.SupernovaDome.CFrame = CFrame.new(floorCenter + Vector3.new(0, 1.2, 0))
		fx.SupernovaCore.Size = Vector3.new(3.2, 3.2, 3.2)
		fx.SupernovaDome.Size = Vector3.new(4.6, 4.6, 4.6)
		fx.SupernovaCore.Transparency = 0.02
		fx.SupernovaDome.Transparency = 0.20
		tween(fx.SupernovaCore, 0.45, { Size = Vector3.new(10.5, 9.5, 10.5), Transparency = 1 })
		tween(fx.SupernovaDome, 0.52, { Size = Vector3.new(14.5, 13.0, 14.5), Transparency = 1 })

		fx.SkyPillar.CFrame = CFrame.new(floorCenter + Vector3.new(0, 9.0, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		fx.SkyPillar.Size = Vector3.new(18, 1.8, 1.8)
		fx.SkyPillar.Transparency = 0.08
		tween(fx.SkyPillar, 0.46, { Size = Vector3.new(22, 6.8, 6.8), Transparency = 1 })

		setDisc(fx.GroundShock1, CFrame.new(floorCenter), 3.0, 0.02)
		setDisc(fx.GroundShock2, CFrame.new(floorCenter + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0.8, 0), 2.2, 0.08)
		tweenDisc(fx.GroundShock1, 0.48, 18.0, 1)
		tweenDisc(fx.GroundShock2, 0.56, 14.5, 1)
	end,
	Duration = 2.2,
}

-- Combo Marcial (San, Neutro): rajada veloz de socos + chute alto giratorio com ondas de impacto
HANDLERS.ComboMarcial = {
	Charge = function(ctx)
		local fx = ctx.fx
		playSfx(fx.Origin, "ChargeSfx")
		local aRoot = rootOf(ctx.attacker)
		local gy = groundY(ctx.attacker)
		fx.Origin.CFrame = CFrame.new(handPos(ctx.attacker))
		emit(fx.Origin, "FistFlash", 3)
		setDisc(fx.DashRing, CFrame.new(aRoot.Position.X, gy + 0.08, aRoot.Position.Z), 1.6, 0.15)
		tweenDisc(fx.DashRing, 0.28, 5.2, 1)
	end,
	Release = function(ctx)
		local fx = ctx.fx
		local hitPos = targetCenter(ctx.target)
		local aPos = rootOf(ctx.attacker).Position
		local look = CFrame.lookAt(hitPos, Vector3.new(aPos.X, hitPos.Y, aPos.Z))
		fx.Hit.CFrame = look
		playSfx(fx.Hit, "ReleaseSfx")

		setDisc(fx.PunchShock1, look * CFrame.new(-0.5, 0.3, -0.8) * CFrame.Angles(math.pi / 2, 0.2, 0), 1.1, 0.08)
		tweenDisc(fx.PunchShock1, 0.22, 4.6, 1)
		emit(fx.Hit, "ImpactSparks", 12)

		task.delay(0.16, function()
			if not ctx.alive then return end
			playSfx(fx.Hit, "ReleaseSfx")
			setDisc(fx.PunchShock2, look * CFrame.new(0.6, 0.5, -0.7) * CFrame.Angles(math.pi / 2, -0.25, 0), 1.2, 0.08)
			tweenDisc(fx.PunchShock2, 0.24, 5.0, 1)
			emit(fx.Hit, "ImpactSparks", 12)
		end)

		for i = 1, 4 do
			local st = fx["Streak" .. i]
			task.delay((i - 1) * 0.06, function()
				if not ctx.alive then return end
				local ox = ((i % 2 == 0) and 1 or -1) * (0.55 + (i - 1) * 0.18)
				local oy = -0.3 + i * 0.28
				st.CFrame = look * CFrame.new(ox, oy, -2.4)
				st.Size = Vector3.new(0.18, 0.18, 0.6)
				st.Transparency = 0.05
				tween(st, 0.14, { CFrame = look * CFrame.new(ox * 0.4, oy, 0.4), Size = Vector3.new(0.08, 0.08, 3.6), Transparency = 1 })
			end)
		end
	end,
	Impact = function(ctx)
		local fx = ctx.fx
		local hitPos = targetCenter(ctx.target)
		fx.Hit.CFrame = CFrame.new(hitPos)
		playSfx(fx.Hit, "ImpactSfx")
		emit(fx.Hit, "HitStar", 5)
		emit(fx.Hit, "ImpactSparks", 26)
		emit(fx.Hit, "DustPuff", 18)
		pulseLight(fx.Hit:FindFirstChild("HitLight"), 8, 16)
		shake(0.16, 0.32)

		setDisc(fx.KickShock, CFrame.new(hitPos) * CFrame.Angles(0.35, 0.2, -0.45), 1.6, 0.04)
		tweenDisc(fx.KickShock, 0.32, 8.6, 1)
	end,
	Duration = 1.1,
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

		fx.QuakeGeyserCore.CFrame = CFrame.new(floorCenter + Vector3.new(0, 8.5, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		fx.QuakeGeyserCore.Size = Vector3.new(17, 2.0, 2.0)
		fx.QuakeGeyserCore.Transparency = 0.04
		tween(fx.QuakeGeyserCore, 0.46, { Size = Vector3.new(21, 7.2, 7.2), Transparency = 1 })

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

		-- Coluna/Ciclone organico de Senbonzakura (nucleo sutil translucido + aneis giratorios subindo + 6 cortes!)
		fx.StormPillarCore.CFrame = CFrame.new(floorCenter + Vector3.new(0, 5.5, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		fx.StormPillarCore.Size = Vector3.new(11.0, 1.3, 1.3)
		fx.StormPillarCore.Transparency = 0.42
		tween(fx.StormPillarCore, 0.48, { Size = Vector3.new(14.5, 4.4, 4.4), Transparency = 1 })

		fx.StormPillarOuter.CFrame = CFrame.new(floorCenter + Vector3.new(0, 4.8, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		fx.StormPillarOuter.Size = Vector3.new(9.5, 2.8, 2.8)
		fx.StormPillarOuter.Transparency = 0.68
		tween(fx.StormPillarOuter, 0.56, { Size = Vector3.new(13.5, 8.6, 8.6), Transparency = 1 })

		-- 3 aneis de furacao de petalas subindo em espiral ao redor do alvo
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
-- API
--------------------------------------------------------------------
local function runEffect(name: string, attacker: Model, target: Model, timing, track: AnimationTrack?, exactTiming: boolean?)
	local handler = HANDLERS[name]
	if not handler or not attacker or not rootOf(attacker) then
		return false
	end
	target = if target and rootOf(target) then target else attacker
	local fx = acquire(name)
	if not fx then
		return false
	end
	local ctx = { fx = fx, attacker = attacker, target = target, timing = timing or {}, alive = true }
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
		release(fx)
	end)
	return true
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
		if move and move.Anim then
			loadTrack(model, move.Anim)
		end
	end
end

-- Toca animacao + efeito de um golpe. Retorna false se o golpe nao tem Anim/Vfx.
function VfxController.PlayMove(moveId: string, attacker: Model, target: Model?)
	local move = Moves.Get(moveId)
	if not move or not move.Vfx or not attacker then
		return false
	end
	local track: AnimationTrack? = nil
	local usedProcedural = false
	if move.Anim and CombatAnimator.Has(move.Anim) then
		usedProcedural = CombatAnimator.Play(attacker, move.Anim, move.Timing)
	end
	if not usedProcedural then
		track = move.Anim and loadTrack(attacker, move.Anim)
		if track then
			track:Play(0.05)
			track:AdjustSpeed(move.AnimSpeed or 1)
		end
	end
	if move.CutIn then
		playCutIn(move, attacker, move.Timing)
	end
	return runEffect(move.Vfx, attacker, target, move.Timing, track, move.AnimSpeed ~= nil or usedProcedural)
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

-- Limpa tudo no fim da batalha
function VfxController.Cleanup()
	CombatAnimator.Cleanup()
	clearCutIn()
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
