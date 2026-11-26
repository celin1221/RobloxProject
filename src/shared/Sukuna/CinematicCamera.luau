--!strict
--[[
	ReplicatedStorage/Sukuna/CinematicCamera.luau
	Direcao de camera cinematografica AAA do Ryomen Sukuna:
	  - Planos fechados (close-ups em olhos/maos a FOV 48)
	  - Contra-plongee (low-angle orbitando na Fortificacao)
	  - Dutch Angles e 3 cortes secos de anime (Clivar)
	  - Crane shot epico revelando o Santuario Malevolente
	  - Plano over-the-shoulder de arqueiro (FOV 70 -> 46) + Tracking Shot supersônico + Plano aberto termobarico (Fuga)
	  - Perlin Trauma Shake + FOV Punch
	Devolve o controle limpo para BattleBaseCFrame / BattleBaseFov ao encerrar cada sequencia.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(script.Parent:WaitForChild("Config"))
local Janitor = require(script.Parent:WaitForChild("Janitor"))

local CinematicCamera = {}

local activeJanitor: Janitor.JanitorInstance? = nil
local trauma = 0.0
local traumaDecay = 1.9
local shakeFrequency = 26.0
local fovPunchOffset = 0.0
local fovPunchVel = 0.0
local noiseSeed = math.random() * 100.0

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

local function headPosOf(model: Model?): Vector3
	if not model then
		return Vector3.zero
	end
	local headMesh = model:FindFirstChild("Head_Mesh")
	if headMesh and headMesh:IsA("BasePart") then
		return headMesh.Position
	end
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end
	local r = rootOf(model)
	return if r then r.Position + Vector3.new(0, 1.55, 0) else Vector3.zero
end

local function lowQuality(): boolean
	local ok, lv = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	return ok and lv ~= 0 and lv <= 3
end

local function canControlLocalBattleCamera(originPos: Vector3): (boolean, Camera?, CFrame, number)
	local cam = workspace.CurrentCamera
	if not cam or cam.CameraType ~= Enum.CameraType.Scriptable then
		return false, cam, CFrame.identity, 50
	end
	local player = Players.LocalPlayer
	local pg = player and player:FindFirstChildOfClass("PlayerGui")
	if pg and pg:GetAttribute("InBattle") ~= true then
		return false, cam, CFrame.identity, 50
	end
	local attrCF = cam:GetAttribute("BattleBaseCFrame")
	local attrFov = cam:GetAttribute("BattleBaseFov")
	local baseCF = if typeof(attrCF) == "CFrame" then attrCF else cam.CFrame
	local baseFov = if typeof(attrFov) == "number" then attrFov else cam.FieldOfView
	if (baseCF.Position - originPos).Magnitude > Config.MaxCameraDistance then
		return false, cam, baseCF, baseFov
	end
	return true, cam, baseCF, baseFov
end

local function restoreBattleBase()
	local cam = workspace.CurrentCamera
	if not cam or cam.CameraType ~= Enum.CameraType.Scriptable then
		return
	end
	local attrCF = cam:GetAttribute("BattleBaseCFrame")
	local attrFov = cam:GetAttribute("BattleBaseFov")
	if typeof(attrCF) == "CFrame" then
		cam.CFrame = attrCF
	end
	if typeof(attrFov) == "number" then
		cam.FieldOfView = attrFov
	end
end

local function samplePerlinShake(now: number, currentTrauma: number, freqOverride: number?): CFrame
	if currentTrauma <= 0.001 or lowQuality() then
		return CFrame.identity
	end
	local shakeAmt = currentTrauma * currentTrauma
	local freq = freqOverride or shakeFrequency
	local nx = math.noise(now * freq, noiseSeed, 0.17) * 2.0
	local ny = math.noise(now * freq, noiseSeed + 19.3, 0.53) * 2.0
	local nz = math.noise(now * freq * 0.85, noiseSeed + 41.7, 0.91) * 2.0
	local maxOffset = 1.55
	local maxRollDeg = 4.2
	return CFrame.new(nx * maxOffset * shakeAmt, ny * maxOffset * 0.85 * shakeAmt, 0)
		* CFrame.Angles(
			math.rad(ny * 1.2 * shakeAmt),
			math.rad(nx * 1.2 * shakeAmt),
			math.rad(nz * maxRollDeg * shakeAmt)
		)
end

function CinematicCamera.AddTrauma(amount: number, decayRate: number?, freq: number?)
	if lowQuality() then
		return
	end
	trauma = math.clamp(trauma + amount, 0, 1.35)
	if decayRate then
		traumaDecay = decayRate
	end
	if freq then
		shakeFrequency = freq
	end
end

function CinematicCamera.SetTrauma(value: number, decayRate: number?, freq: number?)
	if lowQuality() then
		return
	end
	trauma = math.clamp(value, 0, 1.35)
	if decayRate then
		traumaDecay = decayRate
	end
	if freq then
		shakeFrequency = freq
	end
end

function CinematicCamera.FovPunch(deltaFov: number)
	if lowQuality() then
		return
	end
	fovPunchOffset += deltaFov
end

local function startSequence(
	originPos: Vector3,
	duration: number,
	evaluator: (elapsed: number, baseCF: CFrame, baseFov: number) -> (CFrame, number, number?)
)
	if activeJanitor then
		activeJanitor:Cleanup()
		activeJanitor = nil
	end
	local ok, cam, baseCF, baseFov = canControlLocalBattleCamera(originPos)
	if not ok or not cam then
		return
	end

	local jan = Janitor.new()
	activeJanitor = jan
	fovPunchOffset = 0
	fovPunchVel = 0

	jan:Add(function()
		trauma = 0
		shakeFrequency = 26.0
		fovPunchOffset = 0
		fovPunchVel = 0
		restoreBattleBase()
	end)

	local elapsed = 0.0
	local lastRenderTick = os.clock()

	local function stepCamera(dt: number)
		local curCam = workspace.CurrentCamera
		if not curCam or curCam.CameraType ~= Enum.CameraType.Scriptable then
			jan:Cleanup()
			if activeJanitor == jan then
				activeJanitor = nil
			end
			return
		end

		local stepDt = math.clamp(dt, 0.0001, 0.25)
		elapsed += stepDt
		if elapsed >= duration then
			jan:Cleanup()
			if activeJanitor == jan then
				activeJanitor = nil
			end
			return
		end

		trauma = math.max(0, trauma - traumaDecay * stepDt)
		local springForce = -fovPunchOffset * 58.0 - fovPunchVel * 12.5
		fovPunchVel += springForce * stepDt
		fovPunchOffset += fovPunchVel * stepDt

		local curBaseCF = curCam:GetAttribute("BattleBaseCFrame")
		local curBaseFov = curCam:GetAttribute("BattleBaseFov")
		local refCF = if typeof(curBaseCF) == "CFrame" then curBaseCF else baseCF
		local refFov = if typeof(curBaseFov) == "number" then curBaseFov else baseFov

		local poseCF, targetFov, dutchDeg = evaluator(elapsed, refCF, refFov)
		local dutchCF = if dutchDeg and math.abs(dutchDeg) > 0.01
			then CFrame.Angles(0, 0, math.rad(dutchDeg))
			else CFrame.identity
		local shakeCF = samplePerlinShake(elapsed, trauma, shakeFrequency)

		curCam.CFrame = poseCF * dutchCF * shakeCF
		curCam.FieldOfView = math.clamp(targetFov + fovPunchOffset, 28, 96)
	end

	if RunService:IsClient() then
		jan:Connect(RunService.RenderStepped, function(dt: number)
			lastRenderTick = os.clock()
			stepCamera(dt)
		end)
		-- Fallback seguro caso a janela do Studio esteja minimizada/sem foco
		jan:Connect(RunService.Heartbeat, function(dt: number)
			if os.clock() - lastRenderTick > 0.12 then
				stepCamera(dt)
			end
		end)
	else
		jan:Connect(RunService.Heartbeat, stepCamera)
	end
end

-- 1. DESMANTELAR: Close rapido no gesto -> chicote acompanhando o corte -> Dutch Angle + shake seco
function CinematicCamera.PlayDesmantelar(attacker: Model, target: Model, timing: { [string]: number }?)
	local aRoot = rootOf(attacker)
	local tRoot = rootOf(target) or aRoot
	if not aRoot or not tRoot then
		return
	end
	local relT = (timing and timing.Release) or 0.56
	local impT = (timing and timing.Impact) or 0.92
	local lenT = (timing and timing.Length) or 1.44

	startSequence(aRoot.Position, lenT, function(t: number, baseCF: CFrame, baseFov: number)
		local aCF = aRoot.CFrame
		local headPos = headPosOf(attacker)
		local tgtPos = tRoot.Position + Vector3.new(0, 0.8, 0)

		-- Close no gesto dos dois dedos
		local closeCamPos = aCF:PointToWorldSpace(Vector3.new(2.2, 1.35, -3.6))
		local closeCF = CFrame.lookAt(closeCamPos, headPos + aCF.LookVector * 0.8 - Vector3.new(0, 0.2, 0))

		-- Chicote rapido acompanhando o voo das laminas ate o alvo
		local dir = (tgtPos - aCF.Position)
		local flatDir = Vector3.new(dir.X, 0, dir.Z)
		local unitDir = if flatDir.Magnitude > 0.05 then flatDir.Unit else aCF.LookVector
		local rightVec = unitDir:Cross(Vector3.yAxis)
		local whipCamPos = tgtPos - unitDir * 6.8 + rightVec * 3.8 + Vector3.new(0, 1.7, 0)
		local whipCF = CFrame.lookAt(whipCamPos, tgtPos)

		if t < relT then
			local a = math.clamp(t / math.max(0.08, relT), 0, 1)
			local ease = 1 - (1 - a) ^ 3
			return baseCF:Lerp(closeCF, ease), baseFov + (43 - baseFov) * ease, -2.0 * ease
		elseif t < impT then
			local a = math.clamp((t - relT) / math.max(0.08, impT - relT), 0, 1)
			local ease = 1 - (1 - a) ^ 4
			return closeCF:Lerp(whipCF, ease), 43 + 9 * ease, -2.0 - 4.5 * ease
		elseif t < impT + 0.24 then
			return whipCF, 50, -6.5
		else
			local a = math.clamp((t - (impT + 0.24)) / math.max(0.12, lenT - (impT + 0.24)), 0, 1)
			local ease = a * a * (3 - 2 * a)
			return whipCF:Lerp(baseCF, ease), 50 + (baseFov - 50) * ease, -6.5 * (1 - ease)
		end
	end)
end

-- 2. CLIVAR: 3 cortes secos agressivos de anime proximos ao inimigo + trauma shake intenso
function CinematicCamera.PlayClivar(attacker: Model, target: Model, timing: { [string]: number }?)
	local aRoot = rootOf(attacker)
	local tRoot = rootOf(target) or aRoot
	if not aRoot or not tRoot then
		return
	end
	local relT = (timing and timing.Release) or 0.64
	local impT = (timing and timing.Impact) or 1.06
	local lenT = (timing and timing.Length) or 1.62
	local tgtOrigin = tRoot.Position

	startSequence(aRoot.Position, lenT, function(t: number, baseCF: CFrame, baseFov: number)
		local tgtCenter = (if tRoot.Parent then tRoot.Position else tgtOrigin) + Vector3.new(0, 0.75, 0)
		local dir = tgtCenter - aRoot.Position
		local flatDir = Vector3.new(dir.X, 0, dir.Z)
		local fwd = if flatDir.Magnitude > 0.05 then flatDir.Unit else Vector3.new(0, 0, -1)
		local right = fwd:Cross(Vector3.yAxis)

		-- Corte Seco 1: Low-angle predatorio no avanco e toque da palma
		local cut1CF = CFrame.lookAt(tgtCenter - fwd * 4.8 + right * 3.1 + Vector3.new(0, -0.55, 0), tgtCenter + Vector3.new(0, 0.25, 0))
		-- Corte Seco 2: Close obliquo reverso na teia geometrica envolvendo o tronco
		local cut2CF = CFrame.lookAt(tgtCenter - fwd * 3.9 - right * 3.4 + Vector3.new(0, 1.35, 0), tgtCenter)
		-- Corte Seco 3: Plano medio dinamico para a explosao caotica de 16 cortes
		local cut3CF = CFrame.lookAt(tgtCenter - fwd * 8.4 + right * 4.6 + Vector3.new(0, 2.2, 0), tgtCenter)

		if t < 0.28 then
			local a = math.clamp(t / 0.28, 0, 1)
			local prepCF = CFrame.lookAt(aRoot.CFrame:PointToWorldSpace(Vector3.new(-2.4, 0.4, -4.2)), aRoot.Position + Vector3.new(0, 0.8, 0))
			return baseCF:Lerp(prepCF, a), baseFov + (44 - baseFov) * a, 3.5 * a
		elseif t < relT + 0.16 then
			-- CORTE SECO 1
			return cut1CF, 45, -7.5
		elseif t < impT then
			-- CORTE SECO 2
			return cut2CF, 42, 8.5
		elseif t < impT + 0.30 then
			-- CORTE SECO 3 (impacto brutal)
			return cut3CF, 54, -5.0
		else
			local a = math.clamp((t - (impT + 0.30)) / math.max(0.12, lenT - (impT + 0.30)), 0, 1)
			local ease = a * a * (3 - 2 * a)
			return cut3CF:Lerp(baseCF, ease), 54 + (baseFov - 54) * ease, -5.0 * (1 - ease)
		end
	end)
end

-- 3. FORTIFICACAO: Contra-plongee (low-angle) orbitando o Sukuna + FOV contraindo e expandindo no estouro
function CinematicCamera.PlayFortificacao(attacker: Model, timing: { [string]: number }?)
	local aRoot = rootOf(attacker)
	if not aRoot then
		return
	end
	local relT = (timing and timing.Release) or 0.56
	local lenT = (timing and timing.Length) or 1.28

	startSequence(aRoot.Position, lenT, function(t: number, baseCF: CFrame, baseFov: number)
		local center = aRoot.Position + Vector3.new(0, 1.05, 0)
		local baseYaw = math.atan2(-aRoot.CFrame.LookVector.X, -aRoot.CFrame.LookVector.Z)
		local progress = math.clamp(t / lenT, 0, 1)
		local orbitAngle = baseYaw - 0.55 + progress * 1.15
		local radius = 6.2
		local camPos = Vector3.new(
			center.X + math.sin(orbitAngle) * radius,
			aRoot.Position.Y - 0.65,
			center.Z + math.cos(orbitAngle) * radius
		)
		local lowOrbitCF = CFrame.lookAt(camPos, center + Vector3.new(0, 0.55, 0))

		if t < relT then
			local a = math.clamp(t / math.max(0.1, relT), 0, 1)
			local ease = 1 - (1 - a) ^ 2
			return baseCF:Lerp(lowOrbitCF, ease), baseFov + (41 - baseFov) * ease, 0
		elseif t < relT + 0.36 then
			local a = math.clamp((t - relT) / 0.36, 0, 1)
			return lowOrbitCF, 55 - 5 * a, 0
		else
			local a = math.clamp((t - (relT + 0.36)) / math.max(0.12, lenT - (relT + 0.36)), 0, 1)
			local ease = a * a * (3 - 2 * a)
			return lowOrbitCF:Lerp(baseCF, ease), 50 + (baseFov - 50) * ease, 0
		end
	end)
end

-- 4. SANTUARIO MALEVOLENTE: Parte A close extremo olhos/maos (FOV 48) -> Parte B crane shot epico revelando o Santuario
function CinematicCamera.PlaySantuario(attacker: Model, target: Model?, timing: { [string]: number }?)
	local aRoot = rootOf(attacker)
	if not aRoot then
		return
	end
	local relT = (timing and timing.Release) or 1.18
	local impT = (timing and timing.Impact) or 1.86
	local lenT = (timing and timing.Length) or 2.85
	local tRoot = rootOf(target)

	startSequence(aRoot.Position, lenT, function(t: number, baseCF: CFrame, baseFov: number)
		local aCF = aRoot.CFrame
		local headPos = headPosOf(attacker)
		local handsPos = aCF:PointToWorldSpace(Vector3.new(0, 0.55, -1.05))
		local shrineFocus = aCF:PointToWorldSpace(Vector3.new(0, 6.2, 7.5))

		-- Close 1: Olhos frios do Rei das Maldicoes (FOV 48)
		local eyeCamCF = CFrame.lookAt(aCF:PointToWorldSpace(Vector3.new(0.65, 1.62, -2.55)), headPos + Vector3.new(0, 0.08, 0))
		-- Close 2: Selo Enmaten nas maos (FOV 48)
		local sealCamCF = CFrame.lookAt(aCF:PointToWorldSpace(Vector3.new(-1.15, 0.72, -2.35)), handsPos)

		-- Crane Shot epico subindo e recuando para enquadrar Sukuna + Santuario monumental atras + inimigo
		local arenaMid = if tRoot then (aCF.Position * 0.55 + tRoot.Position * 0.45) else aCF:PointToWorldSpace(Vector3.new(0, 0, -6))
		local craneStartCF = CFrame.lookAt(aCF:PointToWorldSpace(Vector3.new(4.2, 2.2, -9.5)), aCF.Position + Vector3.new(0, 3.2, 0))
		local craneHighCF = CFrame.lookAt(
			aCF:PointToWorldSpace(Vector3.new(11.5, 9.2, -19.5)),
			(arenaMid * 0.5 + shrineFocus * 0.5)
		)

		if t < relT * 0.52 then
			return eyeCamCF, 48, -1.5
		elseif t < relT then
			return sealCamCF, 48, 2.0
		elseif t < impT then
			local a = math.clamp((t - relT) / math.max(0.12, impT - relT), 0, 1)
			local ease = 1 - (1 - a) ^ 3
			return craneStartCF:Lerp(craneHighCF, ease), 48 + 14 * ease, 0
		elseif t < lenT - 0.42 then
			return craneHighCF, 62, -2.0
		else
			local a = math.clamp((t - (lenT - 0.42)) / 0.42, 0, 1)
			local ease = a * a * (3 - 2 * a)
			return craneHighCF:Lerp(baseCF, ease), 62 + (baseFov - 62) * ease, -2.0 * (1 - ease)
		end
	end)
end

-- Pulso rapido de camera durante os ticks de 15% de sangramento por rodada do Santuario
function CinematicCamera.PlayDomainSlashTick(target: Model?)
	local tRoot = rootOf(target)
	if not tRoot then
		return
	end
	local ok = canControlLocalBattleCamera(tRoot.Position)
	if not ok then
		return
	end
	CinematicCamera.AddTrauma(0.58, 2.4)
	CinematicCamera.FovPunch(-4.5)
	startSequence(tRoot.Position, 0.55, function(t: number, baseCF: CFrame, baseFov: number)
		local focus = tRoot.Position + Vector3.new(0, 0.9, 0)
		local punchCF = baseCF:Lerp(CFrame.lookAt(baseCF.Position + (focus - baseCF.Position) * 0.14, focus), math.sin(math.clamp(t / 0.55, 0, 1) * math.pi))
		local dutch = math.sin(math.clamp(t / 0.55, 0, 1) * math.pi) * -3.2
		return punchCF, baseFov, dutch
	end)
end

-- 5. FUGA (Chama Divina / Flecha de Fogo — Coreografia Cinematografica de 6 Fases, 0.00s a 8.80s):
-- Fase 1 (0.00..1.45s): Corte seco para Close-Up extremo peito/maos (FOV 44), Dutch Angle 6° e Dolly Out lento acompanhando abertura
-- Fase 2 (1.45..3.20s): Movimento orbital continuo da frente/rosto ate Over-The-Shoulder direito alinhado na flecha, FOV 62 -> 40
-- Fase 3 (3.20..3.85s): Apice 0.10s -> em 3.30s coice instantaneo FOV 40 -> 90 + corte para Tracking Shot lateral-dianteiro supersônico
-- Fase 4 (3.85..4.05s): Close tenso travado na implosao de vacuo (0.12s) + Duplo Impact Frame
-- Fase 5 (4.05..7.20s): Corte brusco para Wide Low-Angle Crane Shot olhando para o pilar de ~165 studs + Trauma Shake violento decaindo
-- Fase 6 (7.20..8.80s): Retorno suave ao enquadramento base da batalha sob a chuva de cinzas
function CinematicCamera.PlayFuga(attacker: Model, target: Model, timing: { [string]: number }?)
	local aRoot = rootOf(attacker)
	local tRoot = rootOf(target) or aRoot
	if not aRoot or not tRoot then
		return
	end

	local TL = Config.FugaTimeline
	local lenT = (timing and timing.Length) or TL.TotalDuration
	local startPos = aRoot.Position
	local endPos = tRoot.Position
	local didLaunchKick = false
	local didPillarBoom = false

	startSequence(startPos, lenT, function(t: number, baseCF: CFrame, baseFov: number)
		local curOrigin = if aRoot.Parent then aRoot.Position else startPos
		local curTarget = if tRoot.Parent then tRoot.Position else endPos
		local chestPos = curOrigin + Vector3.new(0, 0.85, 0)
		local tgtChest = curTarget + Vector3.new(0, 0.95, 0)
		local flatVec = Vector3.new(curTarget.X - curOrigin.X, 0, curTarget.Z - curOrigin.Z)
		local aimDir = if flatVec.Magnitude > 0.05 then flatVec.Unit else aRoot.CFrame.LookVector
		local right = aimDir:Cross(Vector3.yAxis)
		right = if right.Magnitude > 0.05 then right.Unit else Vector3.xAxis

		if t < TL.Phase2BowStart then
			-- FASE 1 (0.00s..1.45s): Corte seco Close-Up extremo peito/maos (FOV = 44), Dutch Angle 6°, Dolly Out lento
			local a = math.clamp(t / TL.Phase2BowStart, 0, 1)
			local smooth = a * a * (3 - 2 * a)
			local dollyDist = 2.35 + smooth * 1.45
			local camPos = chestPos + aimDir * dollyDist + right * (0.42 + smooth * 0.35) + Vector3.new(0, 0.18 + smooth * 0.16, 0)
			local lookFocus = chestPos + Vector3.new(0, 0.12 + smooth * 0.22, 0)
			return CFrame.lookAt(camPos, lookFocus), 44.0, 6.0 - smooth * 1.2

		elseif t < TL.Phase3ApexStart then
			-- FASE 2 (1.45s..3.20s): Orbita continua da frente/lateral do rosto ate Over-The-Shoulder direito + FOV 62 -> 40!
			local a = math.clamp((t - TL.Phase2BowStart) / (TL.Phase3ApexStart - TL.Phase2BowStart), 0, 1)
			local ease = a * a * (3 - 2 * a)
			local compressEase = 1 - (1 - a) ^ 2.6

			-- Angulo orbital: sai da frente-direita (theta = 0.22*pi) e desliza suavemente para tras do ombro direito (theta = 0.88*pi)
			local theta = (0.20 + ease * 0.68) * math.pi
			local rad = 3.65 - ease * 0.35
			local orbPos = curOrigin
				+ aimDir * (math.cos(theta) * rad)
				+ right * (math.sin(theta) * 2.35 + ease * 0.85)
				+ Vector3.new(0, 1.42 + ease * 0.20, 0)

			-- Plano exato Over-The-Shoulder direito alinhado ao longo da flecha ardente mirando no alvo
			local otsPos = curOrigin - aimDir * 3.15 + right * 1.28 + Vector3.new(0, 1.54, 0)
			local arrowShaftLook = (curOrigin + aimDir * 3.8 + Vector3.new(0, 1.18, 0)):Lerp(tgtChest, 0.78)
			local faceFocus = headPosOf(attacker) + aimDir * 0.55

			local orbCF = CFrame.lookAt(orbPos, faceFocus:Lerp(arrowShaftLook, ease))
			local otsCF = CFrame.lookAt(otsPos, arrowShaftLook)
			local finalCF = orbCF:Lerp(otsCF, ease * ease)

			-- Tremor de tensao pura crescendo progressivamente na puxada maxima
			local tensionTrauma = 0.06 + (a ^ 2.2) * 0.30
			CinematicCamera.SetTrauma(tensionTrauma, 3.0, 38.0 + a * 16.0)

			local fov = 62.0 + (40.0 - 62.0) * compressEase
			return finalCF, fov, -2.5 * ease

		elseif t < TL.LaunchTime then
			-- FASE 3A (3.20s..3.30s): Pausa de tensao absoluta de 0.10s no apice (FOV travado em 40)
			local otsPos = curOrigin - aimDir * 3.22 + right * 1.28 + Vector3.new(0, 1.54, 0)
			local arrowShaftLook = (curOrigin + aimDir * 4.0 + Vector3.new(0, 1.18, 0)):Lerp(tgtChest, 0.82)
			CinematicCamera.SetTrauma(0.36, 3.2, 54.0)
			return CFrame.lookAt(otsPos, arrowShaftLook), 40.0, -2.8

		elseif t < TL.Phase4ImplodeStart then
			-- FASE 3B (3.30s..3.85s): Coice FOV 40 -> 90 + Corte para Tracking Shot lateral-dianteiro acompanhando a flecha!
			if not didLaunchKick then
				didLaunchKick = true
				CinematicCamera.SetTrauma(0.92, 3.4, 42.0)
			end
			local flightSpan = TL.Phase4ImplodeStart - TL.LaunchTime
			local u = math.clamp((t - TL.LaunchTime) / flightSpan, 0, 1)
			local accelU = u ^ 1.35
			local arrowStart = curOrigin + aimDir * 2.4 + Vector3.new(0, 1.18, 0)
			local arrowNow = arrowStart:Lerp(tgtChest, accelU)

			-- Primeiros 0.08s: explosao do coice no OTS (FOV 40 -> 90!), depois corte imediato pro Tracking Shot lateral-dianteiro!
			if t - TL.LaunchTime < 0.075 then
				local k = (t - TL.LaunchTime) / 0.075
				local kickPos = curOrigin - aimDir * (3.22 + k * 1.4) + right * 1.35 + Vector3.new(0, 1.54, 0)
				return CFrame.lookAt(kickPos, arrowNow + aimDir * 4.0), 40.0 + 50.0 * (1 - (1 - k) ^ 3), -5.5
			end

			-- Tracking Shot dinamico lateral-dianteiro escoltando o cometa de fogo ate o impacto!
			local trackPos = arrowNow + aimDir * 2.8 + right * 4.65 + Vector3.new(0, 0.95, 0)
			local trackLook = arrowNow:Lerp(tgtChest, 0.45)
			local dynFov = 88.0 - u * 12.0
			return CFrame.lookAt(trackPos, trackLook), dynFov, -6.5

		elseif t < TL.Phase5PillarStart then
			-- FASE 4 (3.85s..4.05s): Implosao de Vacuo & Hitstop (camera travada no ponto de colisao comprimindo!)
			local a = math.clamp((t - TL.Phase4ImplodeStart) / (TL.Phase5PillarStart - TL.Phase4ImplodeStart), 0, 1)
			CinematicCamera.SetTrauma(0.08 * (1 - a), 6.0, 20.0)
			local impCamPos = tgtChest - aimDir * (5.6 - a * 1.1) + right * 3.4 + Vector3.new(0, 0.55, 0)
			return CFrame.lookAt(impCamPos, tgtChest), 46.0 - a * 8.0, -7.5

		elseif t < TL.Phase6AftermathStart then
			-- FASE 5 (4.05s..7.20s): Corte brusco para Wide Low-Angle Crane Shot olhando para cima no pilar de ~165 studs!
			local pTime = t - TL.Phase5PillarStart
			if not didPillarBoom then
				didPillarBoom = true
				CinematicCamera.SetTrauma(1.32, 0.85, 34.0)
			end
			-- Primeiros 0.8s violentissimos (alta freq), depois decai organicamente em tremores lentos e pesados!
			if pTime < 0.80 then
				CinematicCamera.SetTrauma(math.max(trauma, 1.25 - pTime * 0.55), 0.95, 32.0 - pTime * 14.0)
			else
				local slowDecay = math.max(0.08, 0.72 * math.exp(-(pTime - 0.80) * 0.75))
				CinematicCamera.SetTrauma(slowDecay, 0.8, 11.5)
			end

			local craneProgress = math.clamp(pTime / (TL.Phase6AftermathStart - TL.Phase5PillarStart), 0, 1)
			local floorY = curTarget.Y - 2.6
			local wideLowPos = Vector3.new(curTarget.X, floorY + 1.85 + craneProgress * 2.8, curTarget.Z)
				- aimDir * (34.0 + craneProgress * 6.5)
				+ right * (18.5 - craneProgress * 4.5)
			-- Olha de baixo para cima acompanhando a escala colossal do pilar de 165 studs engolindo o ceu!
			local lookUpHeight = 28.0 + math.min(1, pTime / 0.65) * 24.0 - craneProgress * 8.0
			local wideLook = Vector3.new(curTarget.X, floorY + lookUpHeight, curTarget.Z)
			return CFrame.lookAt(wideLowPos, wideLook), 74.0 - craneProgress * 4.0, -2.4 * (1 - craneProgress * 0.5)

		else
			-- FASE 6 (7.20s..8.80s): Retorno suave e cinematografico para a camera padrao da batalha enquanto as cinzas caem
			local a = math.clamp((t - TL.Phase6AftermathStart) / math.max(0.15, lenT - TL.Phase6AftermathStart), 0, 1)
			local ease = a * a * (3 - 2 * a)
			local floorY = curTarget.Y - 2.6
			local lastWidePos = Vector3.new(curTarget.X, floorY + 4.65, curTarget.Z) - aimDir * 40.5 + right * 14.0
			local lastWideLook = Vector3.new(curTarget.X, floorY + 44.0, curTarget.Z)
			local fromCF = CFrame.lookAt(lastWidePos, lastWideLook)
			return fromCF:Lerp(baseCF, ease), 70.0 + (baseFov - 70.0) * ease, -1.2 * (1 - ease)
		end
	end)
end

function CinematicCamera.Cleanup()
	if activeJanitor then
		activeJanitor:Cleanup()
		activeJanitor = nil
	else
		trauma = 0
		fovPunchOffset = 0
		fovPunchVel = 0
		restoreBattleBase()
	end
end

return CinematicCamera
