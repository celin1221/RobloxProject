--!strict
--[[
	ReplicatedStorage/HollowPurple/Config.luau
	Configuracao centralizada do sistema AAA "Vazio Roxo" (Hollow Purple - Gojo Satoru / Setero).
	Todos os tempos, cores, escalas, parametros de camera, hitbox e IDs opcionais ficam aqui.
]]

export type AssetTable = {
	BlueSoundId: string,
	RedSoundId: string,
	OrbitSoundId: string,
	MergeSoundId: string,
	LaunchSoundId: string,
	FlightLoopSoundId: string,
	HitSoundId: string,
	ExplosionSoundId: string,
	CastAnimationId: string,
	SparkTextureId: string,
	SmokeTextureId: string,
	FireTextureId: string,
	TrailTextureId: string,
}

local Config = {
	-- Ativacao e controle geral
	ActivationKey = Enum.KeyCode.R,
	RemoteName = "HollowPurpleRemote",
	WorkspaceFolderName = "HollowPurpleVFX",
	Cooldown = 9.5,

	-- Controle de personagem durante a conjuracao (0.00s -> 4.15s)
	LockCasterDuringWindup = true,
	WindupWalkSpeed = 4.0,
	OrientCasterToAim = true,
	RequireSeteroInParty = false, -- false permite testar imediatamente com R no Play Mode
	AlsoAnimateSeteroFollower = true, -- se o seguidor ativo for Setero, ele conjura junto!
	SpawnStudioTestDummy = true, -- cria um Dummy de teste na praca no Studio para testar dano/knockback na hora
	AllowPvPFreeRoam = false, -- protege outros jogadores fora de arenas PvP

	-- Culling de distancia no cliente (otimizacao FPS)
	MaxCameraEffectDistance = 165.0,
	ReducedDetailDistance = 175.0,
	MaxRenderDistance = 420.0,

	-- Linha do tempo exata das 5 Fases (em segundos)
	Timing = {
		Phase1Start = 0.00, -- Lapso Azul (esquerda)
		Phase1End = 1.20,
		Phase2Start = 1.20, -- Reversao Vermelho (direita)
		Phase2End = 2.40,
		Phase3OrbitStart = 2.40, -- Convergencia espiral
		Phase3MergeTime = 3.50, -- Impact Frame + Singularidade Vazio Roxo
		Phase3End = 4.00, -- Formacao completa da esfera de 5 camadas
		LaunchTensionPause = 0.15, -- Pausa dramatica antes do disparo (4.00s -> 4.15s)
		Phase4LaunchTime = 4.15, -- Estalo de dedos e disparo continuo
		Phase4MaxFlight = 2.65, -- Ate ~6.80s (ou colisao com parede solida)
		Phase5ImplodeDuration = 0.12, -- Compressao pre-detonacao
		Phase5ExplosionDuration = 2.08, -- Cataclismo Roxo + dissipacao limpa (~6.80s -> 9.00s)
		EmberLingerDuration = 2.50,
	},

	-- Posicionamentos relativos ao HumanoidRootPart do conjurador
	Offsets = {
		BlueLocal = CFrame.new(-4.5, 1.2, -3.5),
		RedLocal = CFrame.new(4.5, 1.2, -3.5),
		ConvergenceLocal = CFrame.new(0.0, 1.5, -8.0),
		FollowLerpSpeed = 14.0,
	},

	-- Escalas das esferas e elementos visuais (em studs)
	Scales = {
		BlueRadius = 2.15,
		BlueSuctionRingStart = 10.0,
		RedRadius = 2.15,
		RedShockInterval = 0.22,
		RedJitterAmplitude = 0.16,

		VoidBirthRadius = 5.6, -- diametro ~11.2
		ProjectileStartRadius = 6.0, -- cresce de raio ~6 ate ~12 durante o voo
		ProjectileEndRadius = 12.2,

		MachRingInterval = 0.05,
		GroundCarveInterval = 0.06,
		GroundRayDepth = 28.0,

		LevitateRockCount = 20,
		LevitateRingRadius = 9.5,

		ExplosionMaxRadius = 55.0,
		SkyPillarHeight = 148.0,
		SkyPillarRadius = 15.0,
		CraterRadius = 32.0,
		CraterRockCount = 26,
	},

	-- Fisica do projetil e combate (Servidor)
	Combat = {
		ProjectileSpeed = 140.0, -- studs/s
		MaxRange = 350.0, -- alcance maximo em studs
		WallSpherecastRadius = 2.6, -- raio para detectar obstaculos solidos indestrutiveis
		HitboxRadiusPadding = 2.5, -- margem extra sobre o raio atual da esfera
		HitTickCooldownPerTarget = 0.22, -- dano continuo ao atravessar inimigos
		TickDamage = 22.0,
		FinalExplosionDamage = 55.0,
		FinalExplosionHitRadius = 46.0,
		KnockbackHorizontal = 86.0,
		KnockbackVertical = 30.0,
		FinalKnockbackHorizontal = 112.0,
		FinalKnockbackVertical = 44.0,
	},

	-- Intensidades de Camera e Pos-Processamento
	Camera = {
		BaseFOV = 70.0,
		BluePulseFOV = 66.0,
		MergeCompressFOV = 52.0,
		MergeExplodeFOV = 88.0,
		LaunchPeakFOV = 92.0,
		FlightSustainFOV = 78.0,
		BlueTrauma = 0.18,
		RedTrauma = 0.28,
		MergeTrauma = 0.82,
		LaunchTrauma = 0.92,
		FlightContinuousTrauma = 0.24,
		DetonationTrauma = 0.96,
	},

	-- Paleta cromatica fiel ao anime (RGB)
	Colors = {
		-- Fase 1: Lapso Azul
		BlueCore = Color3.fromRGB(220, 250, 255),
		BlueMid = Color3.fromRGB(0, 145, 255),
		BlueShell = Color3.fromRGB(0, 90, 255),
		BlueLight = Color3.fromRGB(55, 175, 255),

		-- Fase 2: Reversao Vermelho
		RedCore = Color3.fromRGB(255, 220, 225),
		RedMid = Color3.fromRGB(255, 20, 45),
		RedShell = Color3.fromRGB(180, 0, 25),
		RedLight = Color3.fromRGB(255, 45, 70),

		-- Fases 3-5: Vazio Roxo (Hollow Purple)
		VoidCore = Color3.fromRGB(12, 0, 24),
		VoidAbyss = Color3.fromRGB(28, 0, 52),
		VoidHalo = Color3.fromRGB(235, 195, 255),
		VoidMain = Color3.fromRGB(140, 0, 255),
		VoidMagenta = Color3.fromRGB(210, 45, 255),
		VoidWhite = Color3.fromRGB(250, 240, 255),
		VoidScorch = Color3.fromRGB(36, 6, 62),
		VoidLight = Color3.fromRGB(175, 65, 255),
	},

	-- IDs customizaveis opcionais ("" usa fallbacks procedurais/locais nativos 100% garantidos)
	Assets = {
		BlueSoundId = "",
		RedSoundId = "",
		OrbitSoundId = "",
		MergeSoundId = "",
		LaunchSoundId = "",
		FlightLoopSoundId = "",
		HitSoundId = "",
		ExplosionSoundId = "",
		CastAnimationId = "",
		SparkTextureId = "",
		SmokeTextureId = "",
		FireTextureId = "",
		TrailTextureId = "",
	} :: AssetTable,

	-- Texturas locais embutidas na instalacao do Roblox (nunca falham ao carregar)
	BuiltinTextures = {
		Spark = "rbxasset://textures/particles/sparkles_main.dds",
		Smoke = "rbxasset://textures/particles/smoke_main.dds",
		Fire = "rbxasset://textures/particles/fire_main.dds",
	},
}

function Config.ResolveTexture(kind: "Spark" | "Smoke" | "Fire" | "Trail"): string
	if kind == "Spark" and Config.Assets.SparkTextureId ~= "" then
		return Config.Assets.SparkTextureId
	elseif kind == "Smoke" and Config.Assets.SmokeTextureId ~= "" then
		return Config.Assets.SmokeTextureId
	elseif kind == "Fire" and Config.Assets.FireTextureId ~= "" then
		return Config.Assets.FireTextureId
	elseif kind == "Trail" and Config.Assets.TrailTextureId ~= "" then
		return Config.Assets.TrailTextureId
	end
	if kind == "Smoke" then
		return Config.BuiltinTextures.Smoke
	elseif kind == "Fire" then
		return Config.BuiltinTextures.Fire
	elseif kind == "Spark" then
		return Config.BuiltinTextures.Spark
	end
	return ""
end

return Config
