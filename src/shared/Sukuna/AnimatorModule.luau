--!strict
--[[
	ReplicatedStorage/Sukuna/AnimatorModule.luau
	Motor de animacoes completo para Ryomen Sukuna (compativel com R6, R15, Skinned e R6-on-R15):
	  - Quando Config.Assets.<Move>AnimId estiver preenchido, carrega e toca a AnimationTrack nativa.
	  - Quando vazio (""), executa animacoes procedurais 60 FPS manipulando Motor6D.Transform
	    com suporte a Hitstop, dash ate o inimigo com afterimages sombrias no Clivar,
	    selo Enmaten no Santuario Malevolente e postura completa de arqueiro no Fuga,
	    restaurando 100% da pose e CFrame originais ao final via Janitor.
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(script.Parent:WaitForChild("Config"))
local Janitor = require(script.Parent:WaitForChild("Janitor"))

local AnimatorModule = {}

type KeyframeDef = {
	t: number,
	ease: string,
	joints: { [string]: CFrame },
}

type AnimDef = {
	Duration: number,
	AssetSlot: string,
	DashToTarget: boolean?,
	Keyframes: { KeyframeDef },
}

local MOTOR_TO_JOINT: { [string]: string } = {
	-- R15 / Hybrid R6-on-R15
	Root = "LowerTorso",
	Waist = "UpperTorso",
	Neck = "Head",
	LeftShoulder = "LeftUpperArm",
	LeftElbow = "LeftLowerArm",
	LeftWrist = "LeftHand",
	RightShoulder = "RightUpperArm",
	RightElbow = "RightLowerArm",
	RightWrist = "RightHand",
	LeftHip = "LeftUpperLeg",
	LeftKnee = "LeftLowerLeg",
	LeftAnkle = "LeftFoot",
	RightHip = "RightUpperLeg",
	RightKnee = "RightLowerLeg",
	RightAnkle = "RightFoot",
	-- R6 classico
	RootJoint = "LowerTorso",
	["Left Shoulder"] = "LeftUpperArm",
	["Right Shoulder"] = "RightUpperArm",
	["Left Hip"] = "LeftUpperLeg",
	["Right Hip"] = "RightUpperLeg",
}

local JOINT_NAMES = {
	"LowerTorso",
	"UpperTorso",
	"Head",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}

local activeAnimJanitors: { [Model]: Janitor.JanitorInstance } = {}
local hitstopUntilByModel: { [Model]: number } = {}

local function degCF(rx: number?, ry: number?, rz: number?, pos: Vector3?): CFrame
	local rot = CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
	return if pos then CFrame.new(pos) * rot else rot
end

local function kf(t: number, ease: string, joints: { [string]: CFrame }): KeyframeDef
	return { t = t, ease = ease, joints = joints }
end

local function easeAlpha(a: number, ease: string): number
	a = math.clamp(a, 0, 1)
	if ease == "QuadIn" then
		return a * a
	elseif ease == "QuadOut" then
		return 1 - (1 - a) * (1 - a)
	elseif ease == "CubicOut" then
		local inv = 1 - a
		return 1 - inv * inv * inv
	elseif ease == "ExpoOut" then
		return if a >= 1 then 1 else 1 - 2 ^ (-10 * a)
	elseif ease == "BackOut" then
		local c1 = 1.70158
		local c3 = c1 + 1
		local p = a - 1
		return 1 + c3 * p * p * p + c1 * p * p
	elseif ease == "SineInOut" then
		return -(math.cos(math.pi * a) - 1) * 0.5
	end
	return a
end

local ANIM_DEFS: { [string]: AnimDef } = {
	-- 1. DESMANTELAR: Postura fria; ergue mao direita com dois dedos e faz gesto seco cortante na diagonal
	SukunaDesmantelar = {
		Duration = 1.44,
		AssetSlot = "DesmantelarAnimId",
		Keyframes = {
			kf(0.00, "Linear", { RightUpperArm = degCF(6, 0, 5), LeftUpperArm = degCF(6, 0, -5) }),
			-- Ergue mao direita friamente na altura do ombro/rosto (2 dedos apontados)
			kf(0.28, "CubicOut", {
				LowerTorso = degCF(2, -22, 0, Vector3.new(0, -0.05, 0.10)),
				UpperTorso = degCF(4, -26, -3),
				Head = degCF(-3, 42, 0),
				RightUpperArm = degCF(102, -16, 36),
				RightLowerArm = degCF(38, 0, 0),
				RightHand = degCF(-12, 0, 0),
				LeftUpperArm = degCF(12, 6, -14),
				LeftLowerArm = degCF(20, 0, 0),
			}),
			-- Gesto seco, rapido e cortante na diagonal!
			kf(0.56, "ExpoOut", {
				LowerTorso = degCF(-5, 24, 0, Vector3.new(0, -0.09, -0.28)),
				UpperTorso = degCF(-8, 32, 6),
				Head = degCF(4, -44, 0),
				RightUpperArm = degCF(72, 36, -42),
				RightLowerArm = degCF(6, 0, 0),
				RightHand = degCF(14, 0, -18),
				LeftUpperArm = degCF(-10, -10, -22),
				LeftUpperLeg = degCF(-12, 0, -6),
				RightUpperLeg = degCF(14, 0, 6),
			}),
			kf(0.96, "QuadOut", {
				LowerTorso = degCF(-3, 12, 0, Vector3.new(0, -0.05, -0.14)),
				UpperTorso = degCF(-4, 16, 2),
				Head = degCF(2, -22, 0),
				RightUpperArm = degCF(64, 22, -26),
				LeftUpperArm = degCF(-4, -6, -14),
			}),
			kf(1.44, "SineInOut", { RightUpperArm = degCF(6, 0, 5), LeftUpperArm = degCF(6, 0, -5) }),
		},
	},

	-- 2. CLIVAR: Dash rapido com afterimage escura ate o inimigo, toque da palma no tronco e gestos rasgantes antes de recuar
	SukunaClivar = {
		Duration = 1.62,
		AssetSlot = "ClivarAnimId",
		DashToTarget = true,
		Keyframes = {
			kf(0.00, "Linear", { RightUpperArm = degCF(6, 0, 5), LeftUpperArm = degCF(6, 0, -5) }),
			-- Agachamento predatorio antes do dash
			kf(0.24, "CubicOut", {
				LowerTorso = degCF(-16, -18, 0, Vector3.new(0, -0.44, 0.24)),
				UpperTorso = degCF(-18, -16, 0),
				Head = degCF(18, 28, 0),
				RightUpperArm = degCF(44, -22, 32),
				RightLowerArm = degCF(64, 0, 0),
				LeftUpperArm = degCF(-24, 16, -28),
				LeftLowerArm = degCF(38, 0, 0),
				LeftUpperLeg = degCF(32, 0, -10),
				LeftLowerLeg = degCF(-28, 0, 0),
				RightUpperLeg = degCF(-26, 0, 10),
			}),
			-- Toque direto da palma direita no tronco do inimigo!
			kf(0.56, "ExpoOut", {
				LowerTorso = degCF(-10, 26, 0, Vector3.new(0, -0.18, -0.45)),
				UpperTorso = degCF(-14, 32, 4),
				Head = degCF(8, -36, 0),
				RightUpperArm = degCF(96, 12, -8),
				RightLowerArm = degCF(4, 0, 0),
				RightHand = degCF(-28, 0, 0),
				LeftUpperArm = degCF(36, -18, -32),
				LeftLowerArm = degCF(42, 0, 0),
				LeftUpperLeg = degCF(-24, 0, -8),
				RightUpperLeg = degCF(28, 0, 8),
			}),
			-- Gesto rasgante brutal 1 (cruzado duplo)
			kf(0.82, "ExpoOut", {
				LowerTorso = degCF(-12, -28, 0, Vector3.new(0, -0.20, -0.38)),
				UpperTorso = degCF(-16, -34, -6),
				Head = degCF(10, 38, 0),
				RightUpperArm = degCF(68, -36, 52),
				RightLowerArm = degCF(16, 0, 0),
				LeftUpperArm = degCF(114, 30, -34),
				LeftLowerArm = degCF(12, 0, 0),
			}),
			-- Gesto rasgante brutal 2 (rasgo final)
			kf(1.06, "ExpoOut", {
				LowerTorso = degCF(-8, 24, 0, Vector3.new(0, -0.14, -0.32)),
				UpperTorso = degCF(-12, 28, 6),
				Head = degCF(6, -30, 0),
				RightUpperArm = degCF(118, 28, -44),
				RightLowerArm = degCF(10, 0, 0),
				LeftUpperArm = degCF(62, -34, -48),
				LeftLowerArm = degCF(14, 0, 0),
			}),
			-- Salto agil recuando de volta a base
			kf(1.36, "BackOut", {
				LowerTorso = degCF(4, 0, 0, Vector3.new(0, 0.16, 0.12)),
				UpperTorso = degCF(6, 0, 0),
				RightUpperArm = degCF(32, 0, 22),
				LeftUpperArm = degCF(32, 0, -22),
			}),
			kf(1.62, "SineInOut", { RightUpperArm = degCF(6, 0, 5), LeftUpperArm = degCF(6, 0, -5) }),
		},
	},

	-- 3. FORTIFICACAO: Base firme, punhos cerrados junto ao corpo concentrando energia, cabeca baixa subindo bruscamente
	SukunaFortificacao = {
		Duration = 1.28,
		AssetSlot = "FortificacaoAnimId",
		Keyframes = {
			kf(0.00, "Linear", { RightUpperArm = degCF(6, 0, 5), LeftUpperArm = degCF(6, 0, -5) }),
			-- Concentracao: base firme, punhos cerrados junto ao tronco, cabeca baixa
			kf(0.36, "CubicOut", {
				LowerTorso = degCF(-8, 0, 0, Vector3.new(0, -0.34, 0.08)),
				UpperTorso = degCF(-14, 0, 0),
				Head = degCF(-26, 0, 0),
				RightUpperArm = degCF(28, -14, 24),
				RightLowerArm = degCF(92, 0, 0),
				LeftUpperArm = degCF(28, 14, -24),
				LeftLowerArm = degCF(92, 0, 0),
				LeftUpperLeg = degCF(18, 0, -12),
				LeftLowerLeg = degCF(-18, 0, 0),
				RightUpperLeg = degCF(18, 0, 12),
				RightLowerLeg = degCF(-18, 0, 0),
			}),
			-- Estouro de pressao espiritual: cabeca sobe bruscamente com imponencia!
			kf(0.60, "ExpoOut", {
				LowerTorso = degCF(6, 0, 0, Vector3.new(0, 0.08, -0.08)),
				UpperTorso = degCF(18, 0, 0),
				Head = degCF(14, 0, 0),
				RightUpperArm = degCF(48, -24, 54),
				RightLowerArm = degCF(46, 0, 0),
				LeftUpperArm = degCF(48, 24, -54),
				LeftLowerArm = degCF(46, 0, 0),
				LeftUpperLeg = degCF(-6, 0, -12),
				RightUpperLeg = degCF(-6, 0, 12),
			}),
			kf(0.96, "QuadOut", {
				LowerTorso = degCF(3, 0, 0, Vector3.new(0, 0.04, -0.04)),
				UpperTorso = degCF(10, 0, 0),
				Head = degCF(6, 0, 0),
				RightUpperArm = degCF(32, -16, 36),
				RightLowerArm = degCF(34, 0, 0),
				LeftUpperArm = degCF(32, 16, -36),
				LeftLowerArm = degCF(34, 0, 0),
			}),
			kf(1.28, "SineInOut", { RightUpperArm = degCF(6, 0, 5), LeftUpperArm = degCF(6, 0, -5) }),
		},
	},

	-- 4. SANTUARIO MALEVOLENTE: Une as maos solenemente no selo Enmaten diante do peito e sustenta enquanto o Santuario emerge
	SukunaSantuario = {
		Duration = 2.85,
		AssetSlot = "SantuarioAnimId",
		Keyframes = {
			kf(0.00, "Linear", { RightUpperArm = degCF(6, 0, 5), LeftUpperArm = degCF(6, 0, -5) }),
			-- Ergue calmamente os cotovelos preparando o selo Enmaten
			kf(0.28, "CubicOut", {
				LowerTorso = degCF(2, 0, 0, Vector3.new(0, 0.04, 0)),
				UpperTorso = degCF(4, 0, 0),
				Head = degCF(-8, 0, 0),
				RightUpperArm = degCF(74, 28, -32),
				RightLowerArm = degCF(68, 0, 0),
				LeftUpperArm = degCF(74, -28, 32),
				LeftLowerArm = degCF(68, 0, 0),
			}),
			-- Fecha o selo Enmaten (maos unidas no centro do peito, olhar soberano)
			kf(0.58, "BackOut", {
				LowerTorso = degCF(3, 0, 0, Vector3.new(0, 0.08, 0)),
				UpperTorso = degCF(6, 0, 0),
				Head = degCF(-6, 0, 0),
				RightUpperArm = degCF(68, 34, -40),
				RightLowerArm = degCF(82, -12, 0),
				RightHand = degCF(10, 0, 14),
				LeftUpperArm = degCF(68, -34, 40),
				LeftLowerArm = degCF(82, 12, 0),
				LeftHand = degCF(10, 0, -14),
				LeftUpperLeg = degCF(4, 0, -7),
				RightUpperLeg = degCF(4, 0, 7),
			}),
			-- "Fukuma Mizushi": cabeca ergue levemente enquanto o Santuario se levanta atras
			kf(1.35, "SineInOut", {
				LowerTorso = degCF(4, 0, 0, Vector3.new(0, 0.14, -0.04)),
				UpperTorso = degCF(10, 0, 0),
				Head = degCF(6, 0, 0),
				RightUpperArm = degCF(70, 34, -40),
				RightLowerArm = degCF(82, -12, 0),
				LeftUpperArm = degCF(70, -34, 40),
				LeftLowerArm = degCF(82, 12, 0),
				LeftUpperLeg = degCF(4, 0, -8),
				RightUpperLeg = degCF(4, 0, 8),
			}),
			kf(2.35, "SineInOut", {
				LowerTorso = degCF(3, 0, 0, Vector3.new(0, 0.08, 0)),
				UpperTorso = degCF(6, 0, 0),
				Head = degCF(2, 0, 0),
				RightUpperArm = degCF(68, 32, -38),
				RightLowerArm = degCF(78, -10, 0),
				LeftUpperArm = degCF(68, -32, 38),
				LeftLowerArm = degCF(78, 10, 0),
			}),
			kf(2.85, "SineInOut", { RightUpperArm = degCF(6, 0, 5), LeftUpperArm = degCF(6, 0, -5) }),
		},
	},

	-- 5. FUGA (Flecha de Fogo):
	-- Fase 1 aproxima e abre as palmas -> Fase 2 postura de arqueiro puxando o arco -> Fase 3 soltura com recuo
	SukunaFuga = {
		Duration = 3.15,
		AssetSlot = "FugaAnimId",
		Keyframes = {
			kf(0.00, "Linear", { RightUpperArm = degCF(6, 0, 5), LeftUpperArm = degCF(6, 0, -5) }),
			-- Palmas unidas na frente do peito ("Fuga")
			kf(0.24, "CubicOut", {
				LowerTorso = degCF(-2, 0, 0, Vector3.new(0, -0.06, 0)),
				UpperTorso = degCF(-4, 0, 0),
				Head = degCF(-8, 0, 0),
				RightUpperArm = degCF(68, 28, -34),
				RightLowerArm = degCF(64, 0, 0),
				LeftUpperArm = degCF(68, -28, 34),
				LeftLowerArm = degCF(64, 0, 0),
			}),
			-- Abre as palmas devagar revelando a fornalha viva de fogo
			kf(0.68, "SineInOut", {
				LowerTorso = degCF(0, 0, 0, Vector3.new(0, -0.04, 0)),
				UpperTorso = degCF(4, 0, 0),
				Head = degCF(-4, 0, 0),
				RightUpperArm = degCF(72, -12, 26),
				RightLowerArm = degCF(34, 0, 0),
				LeftUpperArm = degCF(72, 12, -26),
				LeftLowerArm = degCF(34, 0, 0),
			}),
			-- Gira em postura de arqueiro: braco esquerdo estendido mirando, direito puxando a corda incandescente!
			kf(1.42, "CubicOut", {
				LowerTorso = degCF(-6, -52, 0, Vector3.new(0, -0.24, 0.14)),
				UpperTorso = degCF(-4, -36, 0),
				Head = degCF(4, 78, 0),
				LeftUpperArm = degCF(94, 58, -8),
				LeftLowerArm = degCF(6, 0, 0),
				RightUpperArm = degCF(92, -22, 28),
				RightLowerArm = degCF(96, 0, 0),
				LeftUpperLeg = degCF(24, 0, -10),
				RightUpperLeg = degCF(-24, 0, 10),
			}),
			-- Disparo brusco com recuo violento do braco direito!
			kf(1.58, "ExpoOut", {
				LowerTorso = degCF(6, -38, 0, Vector3.new(0, -0.18, 0.48)),
				UpperTorso = degCF(14, -24, 0),
				Head = degCF(-6, 58, 0),
				LeftUpperArm = degCF(108, 48, -12),
				LeftLowerArm = degCF(8, 0, 0),
				RightUpperArm = degCF(104, -38, 48),
				RightLowerArm = degCF(16, 0, 0),
				LeftUpperLeg = degCF(18, 0, -8),
				RightUpperLeg = degCF(-20, 0, 8),
			}),
			-- Sustenta a postura observando o pilar colossal de fogo
			kf(2.45, "QuadOut", {
				LowerTorso = degCF(2, -24, 0, Vector3.new(0, -0.08, 0.24)),
				UpperTorso = degCF(6, -16, 0),
				Head = degCF(-2, 36, 0),
				LeftUpperArm = degCF(92, 34, -8),
				RightUpperArm = degCF(68, -18, 28),
			}),
			kf(3.15, "SineInOut", { RightUpperArm = degCF(6, 0, 5), LeftUpperArm = degCF(6, 0, -5) }),
		},
	},
}

local function collectJoints(model: Model): ({ [string]: Motor6D | Bone }, boolean)
	local map: { [string]: Motor6D | Bone } = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") then
			local key = MOTOR_TO_JOINT[d.Name] or (d.Part1 and d.Part1.Name) or (d.Parent and d.Parent.Name)
			if key then
				map[key] = d
			end
		elseif d:IsA("Bone") then
			if not map[d.Name] then
				map[d.Name] = d
			end
		end
	end
	local isIPose = (model:FindFirstChild("LeftArm_Mesh") ~= nil) or (model:FindFirstChild("Torso_Mesh") ~= nil)
	return map, isIPose
end

local function applyPose(
	joints: { [string]: Motor6D | Bone },
	isIPose: boolean,
	lockNeck: boolean,
	pose: { [string]: CFrame }
)
	local armDelta = if isIPose then 0 else math.rad(34)
	for _, jName in ipairs(JOINT_NAMES) do
		local j = joints[jName]
		if j then
			local cf = if (lockNeck and jName == "Head") then CFrame.identity else (pose[jName] or CFrame.identity)
			if armDelta ~= 0 then
				if jName == "LeftUpperArm" then
					cf = cf * CFrame.Angles(0, 0, armDelta)
				elseif jName == "RightUpperArm" then
					cf = cf * CFrame.Angles(0, 0, -armDelta)
				end
			end
			(j :: any).Transform = cf
		end
	end
end

-- Cria afterimage escura/carmesim clonando apenas as malhas/partes reais do corpo do Sukuna (zero primitivos feios!)
local function spawnDashAfterimage(model: Model, parentFolder: Instance)
	local ghostModel = Instance.new("Model")
	ghostModel.Name = "SukunaDashAfterimage"
	ghostModel.Parent = parentFolder

	for _, d in ipairs(model:GetChildren()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 0.95 then
			local clone = d:Clone()
			for _, sub in ipairs(clone:GetDescendants()) do
				if not sub:IsA("SpecialMesh") then
					sub:Destroy()
				end
			end
			clone.Anchored = true
			clone.CanCollide = false
			clone.CanQuery = false
			clone.CanTouch = false
			clone.CastShadow = false
			clone.Massless = true
			clone.Material = Enum.Material.Neon
			clone.Color = Config.Colors.CrimsonCore
			clone.Transparency = 0.52
			clone.CFrame = d.CFrame
			clone.Parent = ghostModel
			TweenService:Create(
				clone,
				TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Transparency = 1, Color = Config.Colors.Obsidian }
			):Play()
		end
	end

	task.delay(0.32, function()
		if ghostModel.Parent then
			ghostModel:Destroy()
		end
	end)
end

function AnimatorModule.Has(animName: string?): boolean
	return animName ~= nil and ANIM_DEFS[animName] ~= nil
end

function AnimatorModule.Hitstop(model: Model?, duration: number?)
	if not model then
		return
	end
	local cur = hitstopUntilByModel[model] or 0
	hitstopUntilByModel[model] = math.max(cur, os.clock() + (duration or 0.05))
end

function AnimatorModule.Stop(model: Model?)
	if not model then
		return
	end
	local jan = activeAnimJanitors[model]
	if jan then
		activeAnimJanitors[model] = nil
		jan:Cleanup()
	end
	hitstopUntilByModel[model] = nil
end

function AnimatorModule.Play(
	model: Model,
	animName: string,
	timing: { [string]: number }?,
	targetModel: Model?
): boolean
	local def = ANIM_DEFS[animName]
	if not def or not model or not model.Parent then
		return false
	end

	AnimatorModule.Stop(model)

	local jan = Janitor.new()
	activeAnimJanitors[model] = jan

	-- 1. Verifica se ha AnimationId customizado em Config.Assets
	local customAssetId = (Config.Assets :: any)[def.AssetSlot] :: string?
	if Config.HasCustomAsset(customAssetId) then
		local hum = model:FindFirstChildOfClass("Humanoid")
		local animator = hum and hum:FindFirstChildOfClass("Animator")
		if animator then
			local animObj = Instance.new("Animation")
			animObj.AnimationId = Config.ResolveAsset(customAssetId, "")
			jan:Add(animObj)
			local ok, track = pcall(function()
				return animator:LoadAnimation(animObj)
			end)
			if ok and track then
				track.Priority = Enum.AnimationPriority.Action4
				track.Looped = false
				track:Play(0.06)
				jan:Add(function()
					pcall(function()
						track:Stop(0.10)
					end)
				end)
				local dur = (timing and timing.Length) or def.Duration
				jan:Delay(dur, function()
					if activeAnimJanitors[model] == jan then
						activeAnimJanitors[model] = nil
					end
					jan:Cleanup()
				end)
				return true
			end
		end
	end

	-- 2. Fallback Procedural 60 FPS em Motor6D.Transform
	local joints, isIPose = collectJoints(model)
	if next(joints) == nil then
		activeAnimJanitors[model] = nil
		jan:Cleanup()
		return false
	end

	local hum = model:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if animator then
		for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
			if tr.Priority ~= Enum.AnimationPriority.Idle and tr.Priority ~= Enum.AnimationPriority.Core then
				tr:Stop(0.05)
			end
		end
	end

	local hrp = model:FindFirstChild("HumanoidRootPart")
	local savedRootCF = if hrp and hrp:IsA("BasePart") then hrp.CFrame else nil
	local tHrp = if targetModel then targetModel:FindFirstChild("HumanoidRootPart") else nil

	model:SetAttribute("ProceduralAttack", true)

	jan:Add(function()
		for _, jName in ipairs(JOINT_NAMES) do
			local j = joints[jName]
			if j then
				pcall(function()
					(j :: any).Transform = CFrame.identity
				end)
			end
		end
		if hrp and hrp:IsA("BasePart") and hrp.Parent and savedRootCF then
			hrp.CFrame = savedRootCF
		end
		if model.Parent then
			model:SetAttribute("ProceduralAttack", nil)
		end
	end)

	local vfxFolder = workspace:FindFirstChild(Config.WorkspaceFolderName)
	if not vfxFolder then
		local f = Instance.new("Folder")
		f.Name = Config.WorkspaceFolderName
		f.Parent = workspace
		vfxFolder = f
	end

	local totalDur = (timing and timing.Length) or def.Duration
	local timeScale = def.Duration / math.max(0.25, totalDur)
	local kfs = def.Keyframes
	local animDur = def.Duration
	local elapsed = 0.0
	local lastGhostAt = 0.0

	jan:Connect(RunService.Stepped, function(_, dt: number)
		if not model.Parent or activeAnimJanitors[model] ~= jan then
			if activeAnimJanitors[model] == jan then
				activeAnimJanitors[model] = nil
			end
			jan:Cleanup()
			return
		end

		local now = os.clock()
		local hsUntil = hitstopUntilByModel[model] or 0
		if now >= hsUntil then
			elapsed += math.min(dt, 0.05) * timeScale
		end

		if elapsed >= animDur then
			activeAnimJanitors[model] = nil
			jan:Cleanup()
			return
		end

		local k0 = kfs[1]
		local k1 = kfs[#kfs]
		for i = 1, #kfs - 1 do
			if elapsed >= kfs[i].t and elapsed <= kfs[i + 1].t then
				k0 = kfs[i]
				k1 = kfs[i + 1]
				break
			end
		end

		local span = math.max(0.0001, k1.t - k0.t)
		local rawA = math.clamp((elapsed - k0.t) / span, 0, 1)
		local alpha = easeAlpha(rawA, k1.ease)

		local pose: { [string]: CFrame } = {}
		for _, jName in ipairs(JOINT_NAMES) do
			local c0 = k0.joints[jName] or CFrame.identity
			local c1 = k1.joints[jName] or CFrame.identity
			pose[jName] = c0:Lerp(c1, alpha)
		end
		local lockNeck = model:GetAttribute("LockNeckHair") == true
		applyPose(joints, isIPose, lockNeck, pose)

		-- Dash fisico com afterimages sombrias no Clivar!
		if def.DashToTarget and hrp and hrp:IsA("BasePart") and savedRootCF and tHrp and tHrp:IsA("BasePart") and tHrp.Parent then
			local startPos = savedRootCF.Position
			local tgtPos = Vector3.new(tHrp.Position.X, startPos.Y, tHrp.Position.Z)
			local delta = tgtPos - startPos
			local dist = delta.Magnitude
			if dist > 2.5 then
				local fwd = delta.Unit
				local strikePos = tgtPos - fwd * 2.85
				local strikeCF = CFrame.lookAt(strikePos, Vector3.new(tHrp.Position.X, strikePos.Y, tHrp.Position.Z))
				if elapsed >= 0.24 and elapsed < 0.54 then
					local da = easeAlpha((elapsed - 0.24) / 0.30, "ExpoOut")
					hrp.CFrame = savedRootCF:Lerp(strikeCF, da)
					if elapsed - lastGhostAt >= 0.065 and vfxFolder then
						lastGhostAt = elapsed
						spawnDashAfterimage(model, vfxFolder)
					end
				elseif elapsed >= 0.54 and elapsed < 1.12 then
					hrp.CFrame = strikeCF
				elseif elapsed >= 1.12 and elapsed < 1.42 then
					local ba = easeAlpha((elapsed - 1.12) / 0.30, "CubicOut")
					hrp.CFrame = strikeCF:Lerp(savedRootCF, ba)
					if elapsed - lastGhostAt >= 0.085 and vfxFolder then
						lastGhostAt = elapsed
						spawnDashAfterimage(model, vfxFolder)
					end
				else
					hrp.CFrame = savedRootCF
				end
			end
		end
	end)

	return true
end

function AnimatorModule.Cleanup()
	for m, jan in pairs(activeAnimJanitors) do
		activeAnimJanitors[m] = nil
		jan:Cleanup()
	end
	table.clear(hitstopUntilByModel)
end

return AnimatorModule
