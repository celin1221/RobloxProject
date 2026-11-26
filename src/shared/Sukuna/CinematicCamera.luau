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

local function samplePerlinShake(now: number, currentTrauma: number): CFrame
	if currentTrauma <= 0.001 or lowQuality() then
		return CFrame.identity
	end
	local shakeAmt = currentTrauma * currentTrauma
	local freq = 26.0
	local nx = math.noise(now * freq, noiseSeed, 0.17) * 2.0
	local ny = math.noise(now * freq, noiseSeed + 19.3, 0.53) * 2.0
	local nz = math.noise(now * freq * 0.85, noiseSeed + 41.7, 0.91) * 2.0
	local maxOffset = 1.35
	local maxRollDeg = 3.8
	return CFrame.new(nx * maxOffset * shakeAmt, ny * maxOffset * 0.85 * shakeAmt, 0)
		* CFrame.Angles(
			math.rad(ny * 1.1 * shakeAmt),
			math.rad(nx * 1.1 * shakeAmt),
			math.rad(nz * maxRollDeg * shakeAmt)
		)
end

function CinematicCamera.AddTrauma(amount: number, decayRate: number?)
	if lowQuality() then
		return
	end
	trauma = math.clamp(trauma + amount, 0, 1.25)
	if decayRate then
		traumaDecay = decayRate
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
		fovPunchOffset = 0
		fovPunchVel = 0
		restoreBattleBase()
	end)

	local t0 = os.clock()
	jan:Connect(RunService.Heartbeat, function(dt: number)
		local curCam = workspace.CurrentCamera
		if not curCam or curCam.CameraType ~= Enum.CameraType.Scriptable then
			jan:Cleanup()
			if activeJanitor == jan then
				activeJanitor = nil
			end
			return
		end

		local elapsed = os.clock() - t0
		if elapsed >= duration then
			jan:Cleanup()
			if activeJanitor == jan then
				activeJanitor = nil
			end
			return
		end

		local stepDt = math.min(dt, 0.05)
		trauma = math.max(0, trauma - traumaDecay * stepDt)
		-- Mola amortecida para FOV punch
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
		local shakeCF = samplePerlinShake(os.clock(), trauma)

		curCam.CFrame = poseCF * dutchCF * shakeCF
		curCam.FieldOfView = math.clamp(targetFov + fovPunchOffset, 30, 86)
	end)
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

-- 5. FUGA (Flecha de Fogo):
-- Fase 1 close nas palmas -> Fase 2 orbita ate over-the-shoulder alinhado com a flecha (FOV 70 -> 46)
-- -> Fase 3 tracking shot supersônico -> Fase 4 plano aberto epico no pilar termobarico + trauma shake pesado
function CinematicCamera.PlayFuga(attacker: Model, target: Model, timing: { [string]: number }?)
	local aRoot = rootOf(attacker)
	local tRoot = rootOf(target) or aRoot
	if not aRoot or not tRoot then
		return
	end
	local p1End = 0.68
	local relT = (timing and timing.Release) or 1.48
	local impT = (timing and timing.Impact) or 2.08
	local lenT = (timing and timing.Length) or 3.15
	local startPos = aRoot.Position
	local endPos = tRoot.Position

	startSequence(startPos, lenT, function(t: number, baseCF: CFrame, baseFov: number)
		local aCF = aRoot.CFrame
		local tgtPos = (if tRoot.Parent then tRoot.Position else endPos) + Vector3.new(0, 1.0, 0)
		local aimVec = tgtPos - (aCF.Position + Vector3.new(0, 1.1, 0))
		local aimDir = if aimVec.Magnitude > 0.05 then aimVec.Unit else aCF.LookVector
		local right = aimDir:Cross(Vector3.yAxis)
		right = if right.Magnitude > 0.05 then right.Unit else aCF.RightVector

		-- Fase 1: Close nas maos abrindo as chamas branco-douradas diante do rosto
		local palmsFocus = aCF.Position + aimDir * 1.15 + Vector3.new(0, 1.05, 0)
		local closeHandsCF = CFrame.lookAt(aCF.Position + aimDir * 3.2 + right * 1.45 + Vector3.new(0, 1.28, 0), palmsFocus)

		-- Fase 2: Orbita ate over-the-shoulder alinhado com a ponta incandescente da flecha (FOV 70 -> 46)
		local otsPos = aCF.Position - aimDir * 3.35 + right * 1.38 + Vector3.new(0, 1.62, 0)
		local arrowTipPos = aCF.Position + aimDir * 2.8 + Vector3.new(0, 1.18, 0)
		local otsCF = CFrame.lookAt(otsPos, arrowTipPos:Lerp(tgtPos, 0.72))

		if t < p1End then
			local a = math.clamp(t / p1End, 0, 1)
			local ease = 1 - (1 - a) ^ 3
			return baseCF:Lerp(closeHandsCF, ease), baseFov + (46 - baseFov) * ease, 0
		elseif t < relT then
			local a = math.clamp((t - p1End) / math.max(0.12, relT - p1End), 0, 1)
			local ease = a * a * (3 - 2 * a)
			-- Orbita ao redor do Sukuna enquanto fecha FOV de 70 -> 46!
			local orbitAng = (1 - ease) * math.pi * 0.78
			local midPos = aCF.Position
				+ (aimDir * math.cos(orbitAng) * -3.5)
				+ (right * (1.38 + math.sin(orbitAng) * 2.8))
				+ Vector3.new(0, 1.55, 0)
			local orbCF = CFrame.lookAt(midPos, arrowTipPos:Lerp(tgtPos, ease * 0.72))
			local blendedCF = orbCF:Lerp(otsCF, ease)
			local fov = 70 + (46 - 70) * ease
			return blendedCF, fov, -2.5 * ease
		elseif t < impT then
			-- Fase 3: Tracking shot acompanhando o projetil supersônico de fogo!
			local a = math.clamp((t - relT) / math.max(0.08, impT - relT), 0, 1)
			local arrowPos = (aCF.Position + Vector3.new(0, 1.2, 0)):Lerp(tgtPos, a)
			local trackPos = arrowPos - aimDir * 5.2 + right * 3.6 + Vector3.new(0, 1.45, 0)
			local trackCF = CFrame.lookAt(trackPos, arrowPos + aimDir * 3.2)
			return trackCF, 64 + 8 * a, -4.5
		else
			-- Fase 4: Hitstop (0.08s) -> Plano aberto epico no pilar colossal de fogo + retorno suave
			local post = t - impT
			local widePos = tgtPos - aimDir * 18.5 + right * 11.5 + Vector3.new(0, 5.4, 0)
			local wideLook = tgtPos + Vector3.new(0, 5.2, 0)
			local wideCF = CFrame.lookAt(widePos, wideLook)
			if post < 0.08 then
				-- Hitstop travado no impacto
				local freezePos = tgtPos - aimDir * 6.5 + right * 4.2 + Vector3.new(0, 1.8, 0)
				return CFrame.lookAt(freezePos, tgtPos), 44, -6.0
			elseif post < 0.72 then
				return wideCF, 66, -2.5
			else
				local a = math.clamp((post - 0.72) / math.max(0.15, (lenT - impT) - 0.72), 0, 1)
				local ease = a * a * (3 - 2 * a)
				return wideCF:Lerp(baseCF, ease), 66 + (baseFov - 66) * ease, -2.5 * (1 - ease)
			end
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
