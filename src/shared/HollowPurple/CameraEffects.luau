--!strict
--[[
	ReplicatedStorage/HollowPurple/CameraEffects.luau
	Sistema de Camera Shake baseado em Trauma^2 + Perlin Noise (math.noise),
	impulsos direcionais com mola amortecida, FOV Punch suave e atenuacao por distancia.
	Restaura Camera.FieldOfView de forma segura mesmo com multiplos disparos simultaneos.
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(script.Parent:WaitForChild("Config"))

local CameraEffects = {}

local trauma = 0.0
local traumaDecay = 1.45
local noiseClock = 0.0
local noiseFrequency = 26.0

local recoilOffset = Vector3.zero
local recoilVelocity = Vector3.zero

-- Controle seguro de sessoes para FieldOfView
local activeSessions: { [string]: number } = {} -- [sessionId] = deltaFOV
local sessionCount = 0
local savedBaseFOV: number? = nil
local fovDriverValue: NumberValue? = nil
local activeFovTween: Tween? = nil
local renderBound = false
local heartbeatFallbackConn: RBXScriptConnection? = nil
local lastRenderTick = 0.0
local BIND_NAME = "HollowPurple_CameraEffects"

local function distanceFactor(worldPos: Vector3?): number
	if not worldPos then
		return 1.0
	end
	local cam = workspace.CurrentCamera
	if not cam then
		return 0.0
	end
	local dist = (cam.CFrame.Position - worldPos).Magnitude
	if dist >= Config.MaxCameraEffectDistance then
		return 0.0
	end
	if dist <= 18.0 then
		return 1.0
	end
	local alpha = 1.0 - (dist - 18.0) / math.max(1.0, Config.MaxCameraEffectDistance - 18.0)
	return math.clamp(alpha * alpha, 0.0, 1.0)
end

local function ensureDriver(): NumberValue
	if fovDriverValue then
		return fovDriverValue
	end
	local nv = Instance.new("NumberValue")
	nv.Name = "HollowPurpleFOVDelta"
	nv.Value = 0
	nv.Parent = script
	fovDriverValue = nv
	return nv
end

local function updateCameraStep(dt: number)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local step = math.min(dt, 0.05)

	-- 1) Atualiza trauma + Perlin Noise 3D
	if trauma > 0.0005 then
		noiseClock += step * noiseFrequency
		local shake = trauma * trauma
		local nx = math.noise(noiseClock, 11.7, 3.1) * 2.0
		local ny = math.noise(7.3, noiseClock, 19.4) * 2.0
		local nz = math.noise(23.9, 5.2, noiseClock) * 2.0

		local posJitter = Vector3.new(nx * 0.95, ny * 0.95, nz * 0.55) * shake
		local rotJitter = CFrame.Angles(
			math.rad(ny * 3.2 * shake),
			math.rad(nx * 3.2 * shake),
			math.rad(nz * 4.4 * shake)
		)
		cam.CFrame = cam.CFrame * CFrame.new(posJitter) * rotJitter
		trauma = math.max(0.0, trauma - traumaDecay * step)
	else
		trauma = 0.0
	end

	-- 2) Mola amortecida de recuo direcional (coice do disparo)
	if recoilOffset.Magnitude > 0.001 or recoilVelocity.Magnitude > 0.001 then
		local stiffness = 140.0
		local damping = 16.0
		local accel = -recoilOffset * stiffness - recoilVelocity * damping
		recoilVelocity += accel * step
		recoilOffset += recoilVelocity * step
		cam.CFrame = cam.CFrame * CFrame.new(recoilOffset)
	else
		recoilOffset = Vector3.zero
		recoilVelocity = Vector3.zero
	end

	-- 3) Aplica delta de FOV sobre o BaseFOV salvo
	if savedBaseFOV ~= nil then
		local totalDelta = if fovDriverValue then fovDriverValue.Value else 0.0
		for _, sessionDelta in pairs(activeSessions) do
			totalDelta += sessionDelta
		end
		cam.FieldOfView = math.clamp(savedBaseFOV + totalDelta, 35.0, 115.0)
	end

	-- Desconecta automaticamente quando completamente ocioso
	if
		trauma <= 0.0
		and recoilOffset.Magnitude <= 0.001
		and recoilVelocity.Magnitude <= 0.001
		and sessionCount == 0
		and (not fovDriverValue or math.abs(fovDriverValue.Value) < 0.01)
	then
		if savedBaseFOV ~= nil then
			cam.FieldOfView = savedBaseFOV
			savedBaseFOV = nil
		end
		if renderBound then
			renderBound = false
			pcall(function()
				RunService:UnbindFromRenderStep(BIND_NAME)
			end)
		end
		if heartbeatFallbackConn and heartbeatFallbackConn.Connected then
			heartbeatFallbackConn:Disconnect()
			heartbeatFallbackConn = nil
		end
	end
end

local function ensureBound()
	local cam = workspace.CurrentCamera
	if savedBaseFOV == nil and cam then
		savedBaseFOV = cam.FieldOfView
	end
	if not renderBound then
		renderBound = true
		RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 8, function(dt: number)
			lastRenderTick = os.clock()
			updateCameraStep(dt)
		end)
	end
	if not heartbeatFallbackConn or not heartbeatFallbackConn.Connected then
		heartbeatFallbackConn = RunService.Heartbeat:Connect(function(dt: number)
			-- Se a janela estiver em segundo plano (RenderStepped pausado), decai trauma e FOV normalmente
			if (os.clock() - lastRenderTick) > 0.08 then
				updateCameraStep(dt)
			end
		end)
	end
end

function CameraEffects.DistanceAttenuation(epicenter: Vector3?): number
	return distanceFactor(epicenter)
end

function CameraEffects.AddTrauma(amount: number, epicenter: Vector3?, customFrequency: number?, customDecay: number?)
	local factor = distanceFactor(epicenter)
	if factor <= 0.01 then
		return
	end
	ensureBound()
	if customFrequency then
		noiseFrequency = customFrequency
	end
	if customDecay then
		traumaDecay = customDecay
	end
	trauma = math.clamp(trauma + amount * factor, 0.0, 1.25)
end

-- Impulso direcional no espaco da camera (ex.: Vector3.new(0, 0.35, 1.8) empurra a camera para tras)
function CameraEffects.Impulse(localKick: Vector3, epicenter: Vector3?)
	local factor = distanceFactor(epicenter)
	if factor <= 0.01 then
		return
	end
	ensureBound()
	recoilVelocity += localKick * (18.0 * factor)
end

-- Anima suavemente o FieldOfView para targetFOV (atenuado pela distancia)
function CameraEffects.TweenFOV(
	targetFOV: number,
	duration: number,
	easingStyle: Enum.EasingStyle?,
	easingDirection: Enum.EasingDirection?,
	epicenter: Vector3?
)
	local factor = distanceFactor(epicenter)
	if factor <= 0.01 then
		return
	end
	ensureBound()
	local base = savedBaseFOV or Config.Camera.BaseFOV
	local desiredDelta = (targetFOV - base) * factor
	local driver = ensureDriver()
	if activeFovTween then
		activeFovTween:Cancel()
	end
	local tw = TweenService:Create(
		driver,
		TweenInfo.new(
			math.max(0.03, duration),
			easingStyle or Enum.EasingStyle.Quint,
			easingDirection or Enum.EasingDirection.Out
		),
		{ Value = desiredDelta }
	)
	activeFovTween = tw
	tw:Play()
end

-- Registra uma sessao ativa (garante restauracao limpa do FOV mesmo com 2 jogadores simultaneos)
function CameraEffects.BeginSession(sessionId: string)
	if activeSessions[sessionId] == nil then
		sessionCount += 1
		activeSessions[sessionId] = 0.0
	end
	ensureBound()
end

function CameraEffects.EndSession(sessionId: string, restoreDuration: number?)
	if activeSessions[sessionId] ~= nil then
		activeSessions[sessionId] = nil
		sessionCount = math.max(0, sessionCount - 1)
	end
	if sessionCount == 0 and fovDriverValue then
		if activeFovTween then
			activeFovTween:Cancel()
		end
		local dur = restoreDuration or 0.45
		local tw = TweenService:Create(
			fovDriverValue,
			TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ Value = 0.0 }
		)
		activeFovTween = tw
		tw:Play()
	end
end

return CameraEffects
