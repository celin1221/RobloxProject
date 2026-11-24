--[[
	CombatAnimator (cliente)
	Motor procedural de animacoes de combate 60 FPS (Motor6D.Transform / Bone.Transform)
	com suporte universal a rigs Hibridos R6-em-R15 (I-Pose: Byakuya, Zoro, Ichigo, Renji,
	Sasuke, BarbaBranca) e R15/Skinned (A-Pose: Kaen, Setero, Proto*).

	Recursos:
	  - Keyframes de pose multi-junta com interpolacao suave (Linear, Quad, Cubic, Back, Expo, Sine)
	  - Suporte a Hitstop real (congelamento de impacto por ~40-60ms)
	  - Espada/Katana procedural acoplada a mao direita com Trail de corte e paleta por espadachim
	    (incluindo dissolucao de lamina na Shikai e queda vertical da katana no Bankai do Byakuya)
	  - Compativel com BaseClient via atributo `ProceduralAttack` (cede controle sem conflito)
	  - Sem dependencia de permissao de AnimationId entre contas (100% versionado no repositorio)
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CombatAnimator = {}

local MOTOR_TO_JOINT = {
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
}

local JOINT_NAMES = {
	"LowerTorso", "UpperTorso", "Head",
	"LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
	"RightUpperLeg", "RightLowerLeg", "RightFoot",
}

-- Paletas personalizadas de katana por personagem espadachim
local SWORD_STYLES = {
	Byakuya = {
		Blade = Color3.fromRGB(238, 244, 255),
		Edge = Color3.fromRGB(255, 178, 218),
		Guard = Color3.fromRGB(218, 198, 138),
		Grip = Color3.fromRGB(240, 242, 250),
		Trail = Color3.fromRGB(255, 162, 210),
		TrailCore = Color3.fromRGB(255, 245, 252),
		Length = 4.35,
	},
	Zoro = {
		Blade = Color3.fromRGB(230, 242, 248),
		Edge = Color3.fromRGB(115, 255, 185),
		Guard = Color3.fromRGB(232, 205, 118),
		Grip = Color3.fromRGB(242, 244, 248),
		Trail = Color3.fromRGB(95, 255, 175),
		TrailCore = Color3.fromRGB(235, 255, 245),
		Length = 4.2,
	},
	Ichigo = {
		Blade = Color3.fromRGB(36, 40, 52),
		Edge = Color3.fromRGB(228, 238, 255),
		Guard = Color3.fromRGB(28, 30, 38),
		Grip = Color3.fromRGB(198, 42, 54),
		Trail = Color3.fromRGB(110, 210, 255),
		TrailCore = Color3.fromRGB(240, 250, 255),
		Length = 4.5,
	},
	Renji = {
		Blade = Color3.fromRGB(224, 232, 244),
		Edge = Color3.fromRGB(255, 92, 102),
		Guard = Color3.fromRGB(225, 182, 74),
		Grip = Color3.fromRGB(178, 34, 46),
		Trail = Color3.fromRGB(255, 96, 86),
		TrailCore = Color3.fromRGB(255, 238, 210),
		Length = 4.3,
	},
	Sasuke = {
		Blade = Color3.fromRGB(228, 236, 250),
		Edge = Color3.fromRGB(142, 196, 255),
		Guard = Color3.fromRGB(48, 52, 72),
		Grip = Color3.fromRGB(34, 36, 48),
		Trail = Color3.fromRGB(130, 185, 255),
		TrailCore = Color3.fromRGB(242, 248, 255),
		Length = 4.15,
	},
	Kaen = {
		Blade = Color3.fromRGB(232, 236, 245),
		Edge = Color3.fromRGB(255, 138, 58),
		Guard = Color3.fromRGB(226, 172, 66),
		Grip = Color3.fromRGB(68, 32, 28),
		Trail = Color3.fromRGB(255, 136, 56),
		TrailCore = Color3.fromRGB(255, 242, 200),
		Length = 4.1,
	},
	Default = {
		Blade = Color3.fromRGB(232, 240, 252),
		Edge = Color3.fromRGB(165, 224, 255),
		Guard = Color3.fromRGB(214, 192, 126),
		Grip = Color3.fromRGB(38, 42, 58),
		Trail = Color3.fromRGB(145, 220, 255),
		TrailCore = Color3.fromRGB(245, 252, 255),
		Length = 4.15,
	},
}

local function degCF(rx: number?, ry: number?, rz: number?, pos: Vector3?): CFrame
	local rot = CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
	return if pos then CFrame.new(pos) * rot else rot
end

local function easeAlpha(a: number, ease: string?): number
	a = math.clamp(a, 0, 1)
	if ease == "QuadIn" then
		return a * a
	elseif ease == "QuadOut" then
		return 1 - (1 - a) * (1 - a)
	elseif ease == "CubicOut" then
		local inv = 1 - a
		return 1 - inv * inv * inv
	elseif ease == "ExpoOut" then
		return if a >= 1 then 1 else 1 - math.pow(2, -9 * a)
	elseif ease == "BackOut" then
		local c1 = 1.70158
		local c3 = c1 + 1
		local u = a - 1
		return 1 + c3 * u * u * u + c1 * u * u
	elseif ease == "SineInOut" then
		return -(math.cos(math.pi * a) - 1) * 0.5
	end
	return a
end

-- Helper para construir um keyframe completo (juntas ausentes ficam em CFrame.identity)
local function kf(t: number, ease: string, joints: { [string]: CFrame }, extra: { [string]: any }?)
	local entry: { [string]: any } = {
		t = t,
		ease = ease,
		joints = joints,
	}
	if extra then
		for k, v in pairs(extra) do
			entry[k] = v
		end
	end
	return entry
end

--------------------------------------------------------------------
-- Definicao das 4 Animacoes de Combate (2 Espadachim Compartilhadas + 2 Byakuya)
--------------------------------------------------------------------
local ANIMATIONS: { [string]: any } = {
	-- 1. CORTE RAPIDO (Ataque basico compartilhado #1 de TODOS os Espadachins)
	-- Iai coil (antecipacao) -> Corte diagonal explosivo -> Hitstop -> Recuperacao
	CorteBasico = {
		Duration = 0.88,
		UseSword = true,
		Keyframes = {
			kf(0.00, "Linear", {
				LowerTorso = degCF(0, 0, 0),
				UpperTorso = degCF(0, 0, 0),
				RightUpperArm = degCF(12, 0, 6),
				LeftUpperArm = degCF(10, 0, -6),
			}, { katana = degCF(-78, 0, 0), trail = false }),

			-- Antecipacao: agacha leve, gira tronco para a direita e ergue a katana no ombro direito
			kf(0.14, "QuadOut", {
				LowerTorso = degCF(-4, -22, 0, Vector3.new(0, -0.22, 0.16)),
				UpperTorso = degCF(8, -28, -4),
				Head = degCF(-4, 42, 2),
				RightUpperArm = degCF(132, -16, 26),
				RightLowerArm = degCF(34, 0, 0),
				LeftUpperArm = degCF(36, 18, 22),
				LeftLowerArm = degCF(38, 0, 0),
				LeftUpperLeg = degCF(16, 0, -4),
				RightUpperLeg = degCF(-18, 0, 5),
			}, { katana = degCF(-58, 0, -14), trail = false }),

			-- Corte diagonal explosivo: chicote de quadril + avanco + braco rasgando alto-dir -> baixo-esq
			kf(0.29, "ExpoOut", {
				LowerTorso = degCF(-8, 34, 4, Vector3.new(0, -0.28, -0.62)),
				UpperTorso = degCF(-16, 44, 6),
				Head = degCF(10, -56, -4),
				RightUpperArm = degCF(38, 24, -46),
				RightLowerArm = degCF(12, 0, 0),
				LeftUpperArm = degCF(-28, -14, -28),
				LeftLowerArm = degCF(16, 0, 0),
				LeftUpperLeg = degCF(-24, 0, -6),
				RightUpperLeg = degCF(26, 0, 6),
			}, { katana = degCF(-116, 14, -32), trail = true }),

			-- Follow-through curto mantendo silhueta nitida no impacto
			kf(0.46, "QuadOut", {
				LowerTorso = degCF(-5, 38, 3, Vector3.new(0, -0.20, -0.48)),
				UpperTorso = degCF(-12, 42, 4),
				Head = degCF(8, -52, -2),
				RightUpperArm = degCF(26, 18, -50),
				RightLowerArm = degCF(10, 0, 0),
				LeftUpperArm = degCF(-22, -10, -24),
				LeftUpperLeg = degCF(-18, 0, -5),
				RightUpperLeg = degCF(20, 0, 5),
			}, { katana = degCF(-118, 12, -28), trail = false }),

			-- Retorno elegante a guarda
			kf(0.88, "SineInOut", {
				LowerTorso = degCF(0, 0, 0),
				UpperTorso = degCF(0, 0, 0),
				Head = degCF(0, 0, 0),
				RightUpperArm = degCF(6, 0, 5),
				LeftUpperArm = degCF(6, 0, -5),
			}, { katana = degCF(-78, 0, 0), trail = false }),
		},
	},

	-- 2. CORTE CRUZADO (Ataque basico compartilhado #2 de TODOS os Espadachins)
	-- Combo duplo em X: Corte 1 (alto-dir -> baixo-esq) + Recoil rapido + Corte 2 ascendente (baixo-esq -> alto-dir)
	CorteCruzado = {
		Duration = 1.14,
		UseSword = true,
		Keyframes = {
			kf(0.00, "Linear", {
				LowerTorso = degCF(0, 0, 0),
				UpperTorso = degCF(0, 0, 0),
				RightUpperArm = degCF(12, 0, 6),
				LeftUpperArm = degCF(10, 0, -6),
			}, { katana = degCF(-78, 0, 0), trail = false }),

			-- Antecipacao profunda
			kf(0.15, "QuadOut", {
				LowerTorso = degCF(-6, -28, -3, Vector3.new(0, -0.30, 0.22)),
				UpperTorso = degCF(10, -34, -5),
				Head = degCF(-4, 50, 3),
				RightUpperArm = degCF(142, -18, 28),
				RightLowerArm = degCF(36, 0, 0),
				LeftUpperArm = degCF(42, 22, 20),
				LeftLowerArm = degCF(42, 0, 0),
				LeftUpperLeg = degCF(20, 0, -5),
				RightUpperLeg = degCF(-22, 0, 6),
			}, { katana = degCF(-52, 0, -16), trail = false }),

			-- Corte 1: diagonal descendente da direita para a esquerda
			kf(0.32, "ExpoOut", {
				LowerTorso = degCF(-9, 36, 4, Vector3.new(0, -0.32, -0.52)),
				UpperTorso = degCF(-16, 46, 7),
				Head = degCF(10, -62, -4),
				RightUpperArm = degCF(32, 28, -54),
				RightLowerArm = degCF(14, 0, 0),
				LeftUpperArm = degCF(-30, -16, -28),
				LeftUpperLeg = degCF(-22, 0, -5),
				RightUpperLeg = degCF(24, 0, 5),
			}, { katana = degCF(-118, 16, -34), trail = true }),

			-- Re-coil compacto a esquerda preparando o corte cruzado ascendente
			kf(0.45, "QuadIn", {
				LowerTorso = degCF(-10, 44, 5, Vector3.new(0, -0.36, -0.44)),
				UpperTorso = degCF(-14, 52, 8),
				Head = degCF(8, -68, -5),
				RightUpperArm = degCF(22, 34, -58),
				RightLowerArm = degCF(28, 0, 0),
				LeftUpperArm = degCF(16, -12, -26),
				LeftUpperLeg = degCF(-18, 0, -6),
				RightUpperLeg = degCF(22, 0, 6),
			}, { katana = degCF(-124, 24, -40), trail = false }),

			-- Corte 2 (X-Cross): rasgo ascendente explosivo da esquerda baixa para a direita alta!
			kf(0.61, "ExpoOut", {
				LowerTorso = degCF(4, -34, -5, Vector3.new(0, 0.14, -0.82)),
				UpperTorso = degCF(14, -44, -7),
				Head = degCF(-8, 60, 4),
				RightUpperArm = degCF(146, -24, 38),
				RightLowerArm = degCF(10, 0, 0),
				LeftUpperArm = degCF(-26, 16, -34),
				LeftLowerArm = degCF(18, 0, 0),
				LeftUpperLeg = degCF(26, 0, -5),
				RightUpperLeg = degCF(-26, 0, 6),
			}, { katana = degCF(-48, -14, 24), trail = true }),

			-- Sustentacao heroica no apice do X
			kf(0.78, "QuadOut", {
				LowerTorso = degCF(2, -30, -4, Vector3.new(0, 0.06, -0.66)),
				UpperTorso = degCF(10, -38, -5),
				Head = degCF(-6, 52, 3),
				RightUpperArm = degCF(134, -20, 34),
				RightLowerArm = degCF(12, 0, 0),
				LeftUpperArm = degCF(-18, 12, -28),
				LeftUpperLeg = degCF(18, 0, -4),
				RightUpperLeg = degCF(-18, 0, 5),
			}, { katana = degCF(-56, -10, 20), trail = false }),

			-- Retorno limpo
			kf(1.14, "SineInOut", {
				LowerTorso = degCF(0, 0, 0),
				UpperTorso = degCF(0, 0, 0),
				Head = degCF(0, 0, 0),
				RightUpperArm = degCF(6, 0, 5),
				LeftUpperArm = degCF(6, 0, -5),
			}, { katana = degCF(-78, 0, 0), trail = false }),
		},
	},

	-- 3. SENBONZAKURA (Shikai — Especial Assinatura #1 do Byakuya)
	-- "Chire, Senbonzakura": ergue lamina perfeitamente vertical -> lamina se dissolve em petalas -> varredura nobre com 1 braco
	Senbonzakura = {
		Duration = 1.58,
		UseSword = true,
		Keyframes = {
			kf(0.00, "Linear", {
				LowerTorso = degCF(0, 0, 0),
				UpperTorso = degCF(0, 0, 0),
				RightUpperArm = degCF(8, 0, 5),
				LeftUpperArm = degCF(6, 0, -5),
			}, { katana = degCF(-78, 0, 0), bladeDissolve = 0, trail = false }),

			-- Postura nobre: traz Senbonzakura perfeitamente vertical a frente do rosto
			kf(0.22, "CubicOut", {
				LowerTorso = degCF(0, -10, 0, Vector3.new(0, 0.04, 0.05)),
				UpperTorso = degCF(2, -14, 0),
				Head = degCF(-2, 22, 0),
				RightUpperArm = degCF(86, 8, -18),
				RightLowerArm = degCF(24, 0, 0),
				LeftUpperArm = degCF(8, 0, -10),
				LeftLowerArm = degCF(10, 0, 0),
			}, { katana = degCF(-4, 0, 0), bladeDissolve = 0, trail = false }),

			-- Lamina brilha e se desfaz em mil petalas na mao enquanto prepara a varredura elegante
			kf(0.62, "SineInOut", {
				LowerTorso = degCF(0, 14, 0, Vector3.new(0, 0.02, 0)),
				UpperTorso = degCF(3, 18, 2),
				Head = degCF(-2, -26, 0),
				RightUpperArm = degCF(92, 26, -38),
				RightLowerArm = degCF(18, 0, 0),
				LeftUpperArm = degCF(4, -6, -12),
			}, { katana = degCF(-4, 0, 0), bladeDissolve = 1, trail = false }),

			-- Varredura ampla e serena com o braco direito comandando o fluxo de petalas contra o alvo!
			kf(0.86, "ExpoOut", {
				LowerTorso = degCF(-2, -22, -2, Vector3.new(0, -0.06, -0.22)),
				UpperTorso = degCF(-4, -28, -3),
				Head = degCF(2, 42, 2),
				RightUpperArm = degCF(96, -22, 54),
				RightLowerArm = degCF(6, 0, 0),
				LeftUpperArm = degCF(-8, 6, -16),
				LeftUpperLeg = degCF(8, 0, -3),
				RightUpperLeg = degCF(-8, 0, 3),
			}, { katana = degCF(-70, 0, 0), bladeDissolve = 1, trail = false }),

			-- Mantem a pose aristocratica impecavel enquanto as petalas retalham o alvo
			kf(1.18, "SineInOut", {
				LowerTorso = degCF(-1, -20, -1, Vector3.new(0, -0.04, -0.18)),
				UpperTorso = degCF(-2, -24, -2),
				Head = degCF(1, 36, 1),
				RightUpperArm = degCF(90, -18, 48),
				RightLowerArm = degCF(6, 0, 0),
				LeftUpperArm = degCF(-6, 4, -14),
			}, { katana = degCF(-70, 0, 0), bladeDissolve = 1, trail = false }),

			-- Retorno sereno
			kf(1.58, "SineInOut", {
				LowerTorso = degCF(0, 0, 0),
				UpperTorso = degCF(0, 0, 0),
				Head = degCF(0, 0, 0),
				RightUpperArm = degCF(6, 0, 5),
				LeftUpperArm = degCF(6, 0, -5),
			}, { katana = degCF(-78, 0, 0), bladeDissolve = 1, trail = false }),
		},
	},

	-- 4. SENBONZAKURA KAGEYOSHI (Bankai — Tecnica Assinatura Suprema #2 do Byakuya)
	-- Estende lamina apontada para baixo -> solta a katana afundando no chao -> abre bracos enquanto 6 laminas gigantes emergem -> comanda o ciclone!
	SenbonzakuraKageyoshi = {
		Duration = 2.25,
		UseSword = true,
		Keyframes = {
			kf(0.00, "Linear", {
				LowerTorso = degCF(0, 0, 0),
				UpperTorso = degCF(0, 0, 0),
				RightUpperArm = degCF(8, 0, 5),
				LeftUpperArm = degCF(6, 0, -5),
			}, { katana = degCF(-78, 0, 0), bladeDrop = 0, bladeDissolve = 0, trail = false }),

			-- "Bankai...": estende o braco direito a frente segurando a lamina apontada verticalmente para baixo
			kf(0.26, "CubicOut", {
				LowerTorso = degCF(0, -8, 0, Vector3.new(0, 0.02, 0)),
				UpperTorso = degCF(2, -10, 0),
				Head = degCF(-4, 14, 0),
				RightUpperArm = degCF(92, 0, 6),
				RightLowerArm = degCF(6, 0, 0),
				LeftUpperArm = degCF(4, 0, -10),
			}, { katana = degCF(176, 0, 0), bladeDrop = 0, bladeDissolve = 0, trail = false }),

			-- Solta a espada: a katana cai e afunda verticalmente no chao atraves do anel de luz!
			kf(0.58, "QuadIn", {
				LowerTorso = degCF(0, -6, 0, Vector3.new(0, 0, 0)),
				UpperTorso = degCF(3, -6, 0),
				Head = degCF(-2, 10, 0),
				RightUpperArm = degCF(88, 0, 10),
				RightLowerArm = degCF(4, 0, 0),
				LeftUpperArm = degCF(8, 0, -14),
			}, { katana = degCF(176, 0, 0), bladeDrop = 1, bladeDissolve = 1, trail = false }),

			-- As 6 laminas gigantes se erguem nos flancos da arena: Byakuya abre os dois bracos com imponencia!
			kf(1.10, "SineInOut", {
				LowerTorso = degCF(2, 0, 0, Vector3.new(0, 0.08, 0.12)),
				UpperTorso = degCF(6, 0, 0),
				Head = degCF(-6, 0, 0),
				RightUpperArm = degCF(58, -16, 46),
				RightLowerArm = degCF(12, 0, 0),
				LeftUpperArm = degCF(58, 16, -46),
				LeftLowerArm = degCF(12, 0, 0),
				LeftUpperLeg = degCF(6, 0, -5),
				RightUpperLeg = degCF(6, 0, 5),
			}, { katana = degCF(176, 0, 0), bladeDrop = 1, bladeDissolve = 1, trail = false }),

			-- "Senbonzakura Kageyoshi!" — Arremessa as duas maos a frente disparando a tempestade de petalas!
			kf(1.38, "ExpoOut", {
				LowerTorso = degCF(-6, 0, 0, Vector3.new(0, -0.14, -0.36)),
				UpperTorso = degCF(-12, 0, 0),
				Head = degCF(8, 0, 0),
				RightUpperArm = degCF(106, 12, 16),
				RightLowerArm = degCF(8, 0, 0),
				LeftUpperArm = degCF(106, -12, -16),
				LeftLowerArm = degCF(8, 0, 0),
				LeftUpperLeg = degCF(-14, 0, -5),
				RightUpperLeg = degCF(14, 0, 5),
			}, { katana = degCF(176, 0, 0), bladeDrop = 1, bladeDissolve = 1, trail = false }),

			-- Mantem a pose majestosa durante o impacto e o ciclone
			kf(1.78, "QuadOut", {
				LowerTorso = degCF(-4, 0, 0, Vector3.new(0, -0.08, -0.26)),
				UpperTorso = degCF(-8, 0, 0),
				Head = degCF(5, 0, 0),
				RightUpperArm = degCF(98, 8, 22),
				RightLowerArm = degCF(8, 0, 0),
				LeftUpperArm = degCF(98, -8, -22),
				LeftLowerArm = degCF(8, 0, 0),
				LeftUpperLeg = degCF(-10, 0, -4),
				RightUpperLeg = degCF(10, 0, 4),
			}, { katana = degCF(176, 0, 0), bladeDrop = 1, bladeDissolve = 1, trail = false }),

			-- Retorno aristocratico calmo
			kf(2.25, "SineInOut", {
				LowerTorso = degCF(0, 0, 0),
				UpperTorso = degCF(0, 0, 0),
				Head = degCF(0, 0, 0),
				RightUpperArm = degCF(6, 0, 5),
				LeftUpperArm = degCF(6, 0, -5),
			}, { katana = degCF(-78, 0, 0), bladeDrop = 1, bladeDissolve = 1, trail = false }),
		},
	},
}

--------------------------------------------------------------------
-- Rig helpers e Katana procedural
--------------------------------------------------------------------
local activeStates: { [Model]: any } = {}

local function collectJoints(model: Model): ({ [string]: any }, boolean)
	local map = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") then
			local key = MOTOR_TO_JOINT[d.Name] or (d.Part1 and d.Part1.Name) or (d.Parent and d.Parent.Name)
			if key then
				map[key] = d
			end
		elseif d:IsA("Bone") then
			map[d.Name] = map[d.Name] or d
		end
	end
	local isIPose = (model:FindFirstChild("LeftArm_Mesh") ~= nil) or (model:FindFirstChild("Torso_Mesh") ~= nil)
	return map, isIPose
end

local function makePart(parent: Instance, name: string, size: Vector3, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function resolveSwordStyle(model: Model)
	local name = model.Name
	if SWORD_STYLES[name] then
		return SWORD_STYLES[name]
	end
	for key, style in pairs(SWORD_STYLES) do
		if key ~= "Default" and string.find(name, key, 1, true) then
			return style
		end
	end
	return SWORD_STYLES.Default
end

local function buildKatana(model: Model, joints: { [string]: any })
	local style = resolveSwordStyle(model)
	local _, bboxSize = model:GetBoundingBox()
	local scale = math.clamp(bboxSize.Y / 6.0, 0.85, 1.35)
	local bladeLen = style.Length * scale

	local sword = Instance.new("Model")
	sword.Name = "BattleKatana"

	-- Punho centrado em (0, 0, 0), lamina cresce ao longo de +Y
	local grip = makePart(sword, "Grip", Vector3.new(0.14 * scale, 0.95 * scale, 0.16 * scale), style.Grip, Enum.Material.SmoothPlastic)
	sword.PrimaryPart = grip

	local pommel = makePart(sword, "Pommel", Vector3.new(0.17 * scale, 0.14 * scale, 0.19 * scale), style.Guard, Enum.Material.Metal)
	local guard = makePart(sword, "Guard", Vector3.new(0.36 * scale, 0.10 * scale, 0.44 * scale), style.Guard, Enum.Material.Metal)
	local blade = makePart(sword, "Blade", Vector3.new(0.06 * scale, bladeLen, 0.16 * scale), style.Blade, Enum.Material.Metal)
	local edge = makePart(sword, "BladeEdge", Vector3.new(0.072 * scale, bladeLen * 0.98, 0.06 * scale), style.Edge, Enum.Material.Neon)
	edge.Transparency = 0.25

	local tip = Instance.new("WedgePart")
	tip.Name = "BladeTip"
	tip.Size = Vector3.new(0.06 * scale, 0.42 * scale, 0.16 * scale)
	tip.Color = style.Blade
	tip.Material = Enum.Material.Metal
	tip.CanCollide = false
	tip.CanQuery = false
	tip.CanTouch = false
	tip.Massless = true
	tip.CastShadow = false
	tip.Parent = sword

	local subOffsets = {
		{ pommel, CFrame.new(0, -0.52 * scale, 0) },
		{ guard, CFrame.new(0, 0.48 * scale, 0) },
		{ blade, CFrame.new(0, 0.52 * scale + bladeLen * 0.5, 0) },
		{ edge, CFrame.new(0, 0.52 * scale + bladeLen * 0.5, -0.065 * scale) },
		{ tip, CFrame.new(0, 0.52 * scale + bladeLen + 0.21 * scale, 0) },
	}

	-- Trail luminoso na lamina (ativo so nos frames de corte)
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailBase"
	a0.Position = Vector3.new(0, 0.65 * scale, 0)
	a0.Parent = grip
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailTip"
	a1.Position = Vector3.new(0, 0.52 * scale + bladeLen + 0.35 * scale, 0)
	a1.Parent = grip

	local trail = Instance.new("Trail")
	trail.Name = "BladeTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Texture = "rbxassetid://115075243133786"
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, style.TrailCore),
		ColorSequenceKeypoint.new(0.45, style.Trail),
		ColorSequenceKeypoint.new(1, style.Trail),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(0.55, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = 0.20
	trail.MinLength = 0.08
	trail.LightEmission = 0.9
	trail.FaceCamera = false
	trail.Enabled = false
	trail.Parent = grip

	-- Prende na mao direita (RightArm_Mesh para hibridos I-Pose, RightHand para R15, Bone para Skinned)
	local armMesh = model:FindFirstChild("RightArm_Mesh")
	local boneHand = joints.RightHand and typeof(joints.RightHand) == "Instance" and joints.RightHand:IsA("Bone") and joints.RightHand or nil
	local partHand = model:FindFirstChild("RightHand")

	local attachPart: BasePart? = nil
	local baseOffset = CFrame.identity
	if armMesh and armMesh:IsA("BasePart") then
		attachPart = armMesh
		baseOffset = CFrame.new(0, -armMesh.Size.Y * 0.44, -armMesh.Size.Z * 0.14)
	elseif not boneHand and partHand and partHand:IsA("BasePart") then
		attachPart = partHand
		baseOffset = CFrame.new(0, -partHand.Size.Y * 0.25, -0.04)
	end

	local weld: Weld? = nil
	if attachPart then
		local worldCF = attachPart.CFrame * baseOffset
		grip.CFrame = worldCF
		for _, entry in ipairs(subOffsets) do
			local p, rel = entry[1], entry[2]
			p.CFrame = worldCF * rel
			local w = Instance.new("Weld")
			w.Part0 = grip
			w.Part1 = p
			w.C0 = rel
			w.Parent = p
		end
		weld = Instance.new("Weld")
		weld.Name = "KatanaHandWeld"
		weld.Part0 = attachPart
		weld.Part1 = grip
		weld.C0 = baseOffset * degCF(-78, 0, 0)
		weld.Parent = grip
		sword.Parent = model
	elseif boneHand then
		grip.Anchored = true
		for _, entry in ipairs(subOffsets) do
			entry[1].Anchored = true
		end
		sword.Parent = model
	else
		sword:Destroy()
		return nil
	end

	return {
		model = sword,
		grip = grip,
		weld = weld,
		baseOffset = baseOffset,
		boneHand = boneHand,
		subOffsets = subOffsets,
		bladeParts = { blade, edge, tip },
		allParts = { grip, pommel, guard, blade, edge, tip },
		trail = trail,
		dropped = false,
		dropStartCF = nil :: CFrame?,
	}
end

local function cleanupState(model: Model)
	local st = activeStates[model]
	if not st then
		return
	end
	activeStates[model] = nil
	if st.conn then
		st.conn:Disconnect()
		st.conn = nil
	end
	if st.katana and st.katana.model and st.katana.model.Parent then
		st.katana.model:Destroy()
	end
	if model and model.Parent then
		model:SetAttribute("ProceduralAttack", nil)
	end
end

local function applyPose(joints: { [string]: any }, isIPose: boolean, lockNeck: boolean, pose: { [string]: CFrame })
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
			j.Transform = cf
		end
	end
end

--------------------------------------------------------------------
-- API Publica
--------------------------------------------------------------------
function CombatAnimator.Has(animName: string?): boolean
	return animName ~= nil and ANIMATIONS[animName] ~= nil
end

function CombatAnimator.Hitstop(model: Model?, duration: number?)
	if not model then
		return
	end
	local st = activeStates[model]
	if st then
		st.hitstopUntil = math.max(st.hitstopUntil or 0, os.clock() + (duration or 0.055))
	end
end

function CombatAnimator.Stop(model: Model?)
	if model then
		cleanupState(model)
	end
end

function CombatAnimator.Play(model: Model, animName: string, timing: { [string]: number }?): boolean
	local def = ANIMATIONS[animName]
	if not def or not model or not model.Parent then
		return false
	end

	cleanupState(model)

	local joints, isIPose = collectJoints(model)
	if next(joints) == nil then
		return false
	end

	-- Para eventual AnimationTrack de combate anterior para nao brigar com Motor6D.Transform
	local hum = model:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if animator then
		for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
			if tr.Priority ~= Enum.AnimationPriority.Idle and tr.Priority ~= Enum.AnimationPriority.Core then
				tr:Stop(0.05)
			end
		end
	end

	model:SetAttribute("ProceduralAttack", true)

	local totalDur = (timing and timing.Length) or def.Duration or 1.0
	local timeScale = (def.Duration or 1.0) / math.max(0.25, totalDur)
	local katana = if def.UseSword then buildKatana(model, joints) else nil

	local st = {
		model = model,
		joints = joints,
		isIPose = isIPose,
		def = def,
		katana = katana,
		elapsed = 0,
		timeScale = timeScale,
		hitstopUntil = 0,
		conn = nil :: RBXScriptConnection?,
	}
	activeStates[model] = st

	local kfs = def.Keyframes
	local animDur = def.Duration

	st.conn = RunService.Stepped:Connect(function(_, dt)
		if not model.Parent or activeStates[model] ~= st then
			cleanupState(model)
			return
		end

		-- Congela o tempo da animacao durante o Hitstop (mantendo a pose travada no impacto!)
		local now = os.clock()
		if now >= st.hitstopUntil then
			st.elapsed += math.min(dt, 0.05) * st.timeScale
		end

		local t = st.elapsed
		if t >= animDur then
			cleanupState(model)
			return
		end

		-- Encontra o par de keyframes [k0, k1] ao redor de t
		local k0 = kfs[1]
		local k1 = kfs[#kfs]
		for i = 1, #kfs - 1 do
			if t >= kfs[i].t and t <= kfs[i + 1].t then
				k0 = kfs[i]
				k1 = kfs[i + 1]
				break
			end
		end

		local span = math.max(0.0001, k1.t - k0.t)
		local rawA = math.clamp((t - k0.t) / span, 0, 1)
		local alpha = easeAlpha(rawA, k1.ease)

		local pose: { [string]: CFrame } = {}
		for _, jName in ipairs(JOINT_NAMES) do
			local c0 = k0.joints[jName] or CFrame.identity
			local c1 = k1.joints[jName] or CFrame.identity
			pose[jName] = c0:Lerp(c1, alpha)
		end
		local lockNeck = model:GetAttribute("LockNeckHair") == true
		applyPose(joints, isIPose, lockNeck, pose)

		-- Atualiza Katana (rotacao de punho, Trail, dissolucao Shikai, queda vertical Bankai)
		if katana and katana.model and katana.model.Parent then
			local kat0 = k0.katana or degCF(-78, 0, 0)
			local kat1 = k1.katana or degCF(-78, 0, 0)
			local katRot = kat0:Lerp(kat1, alpha)

			local drop0 = k0.bladeDrop or 0
			local drop1 = k1.bladeDrop or 0
			local dropA = drop0 + (drop1 - drop0) * alpha

			local dis0 = k0.bladeDissolve or 0
			local dis1 = k1.bladeDissolve or 0
			local disA = dis0 + (dis1 - dis0) * alpha

			if dropA > 0.01 then
				-- Solta a espada da mao e faz ela afundar verticalmente no chao!
				if not katana.dropped then
					katana.dropped = true
					katana.dropStartCF = katana.grip.CFrame
					if katana.weld then
						katana.weld:Destroy()
						katana.weld = nil
					end
					for _, p in ipairs(katana.allParts) do
						p.Anchored = true
					end
				end
				if katana.dropStartCF then
					local fallY = -dropA * 4.4
					local cf = katana.dropStartCF + Vector3.new(0, fallY, 0)
					katana.grip.CFrame = cf
					for _, entry in ipairs(katana.subOffsets) do
						entry[1].CFrame = cf * entry[2]
					end
				end
				-- Esconde suavemente ao entrar no chao
				local fade = math.clamp((dropA - 0.55) / 0.45, 0, 1)
				for _, p in ipairs(katana.allParts) do
					p.Transparency = math.max(if p.Name == "BladeEdge" then 0.25 else 0, fade)
				end
			else
				if katana.weld and katana.weld.Parent then
					katana.weld.C0 = katana.baseOffset * katRot
				elseif katana.boneHand then
					local cf = katana.boneHand.TransformedWorldCFrame * katRot
					katana.grip.CFrame = cf
					for _, entry in ipairs(katana.subOffsets) do
						entry[1].CFrame = cf * entry[2]
					end
				end
				-- Dissolucao Shikai: lamina some em brilho rosa enquanto o punho fica na mao
				if disA > 0.01 then
					for _, p in ipairs(katana.bladeParts) do
						p.Transparency = math.clamp(disA, 0, 1)
					end
				end
			end

			local trailOn = (k1.trail == true) and (rawA > 0.06 and rawA < 0.96) and (disA < 0.5) and (dropA < 0.05)
			if katana.trail and katana.trail.Parent then
				katana.trail.Enabled = trailOn
			end
		end
	end)

	return true
end

function CombatAnimator.Cleanup()
	for model in pairs(activeStates) do
		cleanupState(model)
	end
end

return CombatAnimator
