--!strict
--[[
	ReplicatedStorage/Sukuna/Config.luau
	Configuracao centralizada do sistema audiovisual AAA de Ryomen Sukuna:
	  1. Desmantelar
	  2. Clivar
	  3. Fortificacao
	  4. Santuario Malevolente (Ryōiki Tenkai: Fukuma Mizushi)
	  5. Fuga (Flecha de Fogo Termobarica)

	Todos os slots de Config.Assets aceitam "rbxassetid://..." customizados.
	Quando deixados como "", o sistema usa automaticamente texturas/sons nativos
	verificados do projeto e animacoes procedurais 60 FPS sem qualquer erro de carregamento.
]]

export type SukunaAssets = {
	-- Vozes sincronizadas (substitua "" pelo seu "rbxassetid://...")
	RyoikiTenkaiVoiceId: string,
	FukumaMizushiVoiceId: string,
	FugaVoiceId: string,

	-- Animacoes customizadas opcionais ("" usa Motor6D procedural 60 FPS)
	DesmantelarAnimId: string,
	ClivarAnimId: string,
	FortificacaoAnimId: string,
	SantuarioAnimId: string,
	FugaAnimId: string,

	-- Texturas / Flipbooks opcionais para particulas, Beams e Trails
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
	MaxCameraDistance = 175.0,
	ReducedDetailDistance = 185.0,
	MaxRenderDistance = 420.0,

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
		Trail = "rbxassetid://115075243133786",
		SoftGlow = "rbxassetid://83184852649242",

		SfxCharge = "rbxassetid://6456542119",
		SfxRelease = "rbxassetid://126546670067885",
		SfxReleaseHeavy = "rbxassetid://92846408037360",
		SfxImpact = "rbxassetid://98753363372264",
		SfxImpactHeavy = "rbxassetid://99881515803650",
	},

	-- Paleta cromatica amaldicoada e termica real (branco-dourado -> laranja -> carmesim -> fuligem preta)
	Colors = {
		SlashWhite = Color3.fromRGB(255, 246, 248),
		CrimsonBright = Color3.fromRGB(242, 24, 54),
		CrimsonCore = Color3.fromRGB(198, 14, 38),
		BloodDeep = Color3.fromRGB(108, 6, 22),
		Obsidian = Color3.fromRGB(12, 6, 10),
		BonePale = Color3.fromRGB(218, 206, 194),
		ShrineWood = Color3.fromRGB(24, 12, 14),
		ShrineRoof = Color3.fromRGB(16, 10, 14),

		-- Transicao termica do Fuga (Flecha de Fogo)
		FireWhiteGold = Color3.fromRGB(255, 252, 228),
		FireGold = Color3.fromRGB(255, 208, 84),
		FireOrange = Color3.fromRGB(255, 108, 22),
		FireCrimson = Color3.fromRGB(206, 24, 28),
		PyroSootLit = Color3.fromRGB(68, 24, 16),
		PyroBlack = Color3.fromRGB(12, 9, 10),
		AshGrey = Color3.fromRGB(148, 136, 132),
	},

	-- Slots centralizados prontos para receber IDs customizados futuramente
	Assets = {
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

function Config.HasCustomAsset(customId: string?): boolean
	return typeof(customId) == "string" and #customId > 0
end

return Config
