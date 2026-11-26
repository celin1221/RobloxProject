--!strict
--[[
	ReplicatedStorage/Sukuna/Config.luau
	Configuracao centralizada do sistema audiovisual AAA de Ryomen Sukuna:
	  1. Desmantelar
	  2. Clivar
	  3. Fortificacao
	  4. Santuario Malevolente (Ryōiki Tenkai: Fukuma Mizushi)
	  5. Fuga (Chama Divina / Flecha de Fogo Termobarica — Rework 6 Fases JJK S2)

	Todos os slots de Config.Assets e Config.Assets.Fuga aceitam "rbxassetid://..." customizados.
	Quando deixados como "", o sistema usa automaticamente texturas/sons nativos
	verificados do projeto e animacoes procedurais 60 FPS sem qualquer erro de carregamento.
]]

export type FugaAssetSlots = {
	-- Voz e Animacao opcional ("" usa animacao procedural 6 fases Motor6D)
	VoiceId: string,
	AnimationId: string,

	-- Flipbooks / Texturas opcionais das 4 camadas termicas, Beams e Trails
	FireCoreFlipbookId: string,
	FireBodyFlipbookId: string,
	PyroSmokeTextureId: string,
	EmberSparkTextureId: string,
	ArrowBeamTextureId: string,
	PillarBeamTextureId: string,
	ShockRingTextureId: string,
	TrailFlameTextureId: string,

	-- SFX opcionais por fase do Fuga
	IgniteSfxId: string,
	FurnaceLoopSfxId: string,
	BowTensionSfxId: string,
	SonicLaunchSfxId: string,
	VacuumSubSfxId: string,
	ThermobaricBoomSfxId: string,
	FirestormRoarSfxId: string,
}

export type SukunaAssets = {
	-- Subtabela dedicada e limpa para o Rework AAA do Fuga
	Fuga: FugaAssetSlots,

	-- Vozes sincronizadas dos outros golpes (retrocompativeis)
	RyoikiTenkaiVoiceId: string,
	FukumaMizushiVoiceId: string,
	FugaVoiceId: string,

	-- Animacoes customizadas opcionais ("" usa Motor6D procedural 60 FPS)
	DesmantelarAnimId: string,
	ClivarAnimId: string,
	FortificacaoAnimId: string,
	SantuarioAnimId: string,
	FugaAnimId: string,

	-- Texturas / Flipbooks gerais
	FireCoreTextureId: string,
	FireWispTextureId: string,
	PyroSmokeTextureId: string,
	EmberSparkTextureId: string,
	SlashStreakTextureId: string,
	SlashBeamTextureId: string,
	BloodMistTextureId: string,
	TrailFlameTextureId: string,

	-- Overrides opcionais de efeitos sonoros
	SlashSfxId: string,
	HeavySlashSfxId: string,
	ShrineBellSfxId: string,
	FireIgniteSfxId: string,
	FireArrowLaunchSfxId: string,
	ThermobaricExplosionSfxId: string,
}

local Config = {
	WorkspaceFolderName = "BattleVfx",
	ShrineModelName = "SukunaMalevolentShrine",

	-- Culling de distancia para otimizacao de FPS e protecao de camera de jogadores distantes
	MaxCameraDistance = 195.0,
	ReducedDetailDistance = 195.0,
	MaxRenderDistance = 450.0,

	-- Timeline exata das 6 Fases do Fuga (em segundos)
	FugaTimeline = {
		Phase1Start = 0.00, -- Abertura da Fornalha & Low-Pass
		VoiceTime = 0.35, -- Voz "Fuga" + Legenda Cinematografica
		HandsPartTime = 0.45, -- Afastamento lento das palmas
		IgniteTime = 0.50, -- Estalo seco de ignicao + rugido da fornalha
		Phase2BowStart = 1.45, -- Postura 75° de arqueiro + Arco/Corda/Flecha + Succao 20 studs
		TremorStart = 2.70, -- Micro-tremor muscular nos ultimos 0.5s da puxada
		Phase3ApexStart = 3.20, -- Pausa de tensao absoluta de 0.10s no apice
		LaunchTime = 3.30, -- Soltura explosiva, recuo e voo supersonico
		Phase4ImplodeStart = 3.85, -- Hitstop (0.12s) + Silencio Subito + Implosao + Duplo Impact Frame
		Phase5PillarStart = 4.05, -- Detonacao do Pilar Colossal de Fogo Termobarico (~165 studs)
		Phase6AftermathStart = 7.20, -- Nucleo branco apaga, fumaca escura + chuva de cinzas
		TotalDuration = 8.80, -- Restauracao limpa total via Janitor
	},

	-- Texturas nativas/verificadas do projeto usadas como fallback imediato quando Config.Assets estiver ""
	Fallbacks = {
		Fire = "rbxasset://textures/particles/fire_main.dds",
		Smoke = "rbxasset://textures/particles/smoke_main.dds",
		Flame = "rbxassetid://79477996185324",
		Spark = "rbxassetid://111340920948521",
		Star = "rbxassetid://77032248103074",
		Glint = "rbxassetid://105042923162509",
		Streak = "rbxassetid://122479098668481",
		Gather = "rbxassetid://115073640656853",
		Puff = "rbxassetid://82305102124278",
		Ring = "rbxassetid://136971071117749",
		Shock = "rbxassetid://83043634785289",
		Trail = "rbxassetid://115075243133786",
		SoftGlow = "rbxassetid://83184852649242",

		SfxCharge = "rbxassetid://6456542119",
		SfxRelease = "rbxassetid://126546670067885",
		SfxReleaseHeavy = "rbxassetid://92846408037360",
		SfxImpact = "rbxassetid://98753363372264",
		SfxImpactHeavy = "rbxassetid://99881515803650",
	},

	-- Paleta cromatica amaldicoada + Empilhamento Termico Real de 4 Camadas do Fuga
	Colors = {
		SlashWhite = Color3.fromRGB(255, 246, 248),
		CrimsonBright = Color3.fromRGB(242, 24, 54),
		CrimsonCore = Color3.fromRGB(198, 14, 38),
		BloodDeep = Color3.fromRGB(108, 6, 22),
		Obsidian = Color3.fromRGB(12, 6, 10),
		BonePale = Color3.fromRGB(218, 206, 194),
		ShrineWood = Color3.fromRGB(24, 12, 14),
		ShrineRoof = Color3.fromRGB(16, 10, 14),

		-- Camada 1: Nucleo Incandescente (ZOffset = 2, LightEmission = 1)
		ThermalCoreStart = Color3.fromRGB(255, 255, 235),
		ThermalCoreEnd = Color3.fromRGB(255, 220, 90),

		-- Camada 2: Corpo da Chama (ZOffset = 1, LightEmission = 0.75)
		ThermalFlameStart = Color3.fromRGB(255, 115, 10),
		ThermalFlameEnd = Color3.fromRGB(210, 25, 5),

		-- Camada 3: Fumaca Piroclastica Densa (ZOffset = -1, LightEmission = 0)
		ThermalSmokeStart = Color3.fromRGB(28, 22, 22),
		ThermalSmokeEnd = Color3.fromRGB(10, 8, 10),

		-- Camada 4 & Paleta auxiliar de brasas/luzes
		FireWhiteGold = Color3.fromRGB(255, 255, 235),
		FireGold = Color3.fromRGB(255, 220, 90),
		FireOrange = Color3.fromRGB(255, 115, 10),
		FireCrimson = Color3.fromRGB(210, 25, 5),
		ImpactFlashScarlet = Color3.fromRGB(255, 110, 40),
		PyroSootLit = Color3.fromRGB(68, 26, 14),
		PyroBlack = Color3.fromRGB(10, 8, 10),
		AshGrey = Color3.fromRGB(148, 136, 132),
	},

	-- Slots centralizados prontos para receber IDs customizados futuramente
	Assets = {
		Fuga = {
			VoiceId = "",
			AnimationId = "",

			FireCoreFlipbookId = "",
			FireBodyFlipbookId = "",
			PyroSmokeTextureId = "",
			EmberSparkTextureId = "",
			ArrowBeamTextureId = "",
			PillarBeamTextureId = "",
			ShockRingTextureId = "",
			TrailFlameTextureId = "",

			IgniteSfxId = "",
			FurnaceLoopSfxId = "",
			BowTensionSfxId = "",
			SonicLaunchSfxId = "",
			VacuumSubSfxId = "",
			ThermobaricBoomSfxId = "",
			FirestormRoarSfxId = "",
		},

		RyoikiTenkaiVoiceId = "",
		FukumaMizushiVoiceId = "",
		FugaVoiceId = "",

		DesmantelarAnimId = "",
		ClivarAnimId = "",
		FortificacaoAnimId = "",
		SantuarioAnimId = "",
		FugaAnimId = "",

		FireCoreTextureId = "",
		FireWispTextureId = "",
		PyroSmokeTextureId = "",
		EmberSparkTextureId = "",
		SlashStreakTextureId = "",
		SlashBeamTextureId = "",
		BloodMistTextureId = "",
		TrailFlameTextureId = "",

		SlashSfxId = "",
		HeavySlashSfxId = "",
		ShrineBellSfxId = "",
		FireIgniteSfxId = "",
		FireArrowLaunchSfxId = "",
		ThermobaricExplosionSfxId = "",
	} :: SukunaAssets,
}

function Config.ResolveAsset(customId: string?, fallbackId: string): string
	if typeof(customId) == "string" and #customId > 0 then
		if string.find(customId, "://") then
			return customId
		end
		return "rbxassetid://" .. customId
	end
	return fallbackId
end

function Config.ResolveFugaAsset(fugaSlot: string?, legacySlot: string?, fallbackId: string): string
	if typeof(fugaSlot) == "string" and #fugaSlot > 0 then
		return Config.ResolveAsset(fugaSlot, fallbackId)
	end
	if typeof(legacySlot) == "string" and #legacySlot > 0 then
		return Config.ResolveAsset(legacySlot, fallbackId)
	end
	return fallbackId
end

function Config.HasCustomAsset(customId: string?): boolean
	return typeof(customId) == "string" and #customId > 0
end

return Config
