--!strict
--[[
	SummonStageThemes: configuracao centralizada do Palco 3D de Banner de Invocacao (estilo Anime Vanguards).
	Define texturas VFX, paletas por anime (Todos, Naruto, OnePiece + presets prontos para futuros animes),
	diferenciacao visual entre Estrela Normal (Comum) e Estrela Premium, posicoes dos 3 pedestais e
	selecao automatica dos 3 destaques (1 Lendario no centro + 2 Epicos nas laterais, com fallback elegante).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Characters = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("Characters"))
local SummonData = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("Summon"))

local Themes = {}

-- Coordenada isolada no espaco 3D (muito acima e fora do Mapa, Plots, Arenas e Refugios)
Themes.STAGE_ORIGIN = Vector3.new(0, 620, -600)

-- Texturas VFX exclusivas geradas via roblox-vfx (todas white-on-transparent para tintagem fiel)
Themes.Assets = {
	CelestialSeal = "rbxassetid://101536437178297",
	NarutoSeal = "rbxassetid://118713249222833",
	OnePieceCompass = "rbxassetid://70372901963639",
	SunburstRays = "rbxassetid://129754593309900",
	PillarGlow = "rbxassetid://83672903547497",
	LeafPetal = "rbxassetid://133426697336558",
	-- Texturas cel-anime ja enviadas no projeto
	GroundVortex = "rbxassetid://103301763929497",
	BeamRibbon = "rbxassetid://122049768303881",
	SparkShard = "rbxassetid://105200043049019",
	StarFlare = "rbxassetid://105042923162509",
	GlowFalloff = "rbxassetid://83184852649242",
	FlameGlow = "rbxassetid://138010377521833",
	ShockRing = "rbxassetid://127905458355753",
}

-- Cores de raridade para pilares de energia, aneis de chao e placas de nome
Themes.RarityColors = {
	Comum = {
		Main = Color3.fromRGB(165, 178, 198),
		Glow = Color3.fromRGB(205, 220, 240),
		Badge = Color3.fromRGB(85, 96, 114),
		Label = "COMUM",
	},
	Raro = {
		Main = Color3.fromRGB(58, 168, 255),
		Glow = Color3.fromRGB(130, 215, 255),
		Badge = Color3.fromRGB(36, 112, 204),
		Label = "RARO",
	},
	Epico = {
		Main = Color3.fromRGB(186, 86, 255),
		Glow = Color3.fromRGB(224, 155, 255),
		Badge = Color3.fromRGB(128, 46, 206),
		Label = "ÉPICO",
	},
	Lendario = {
		Main = Color3.fromRGB(255, 202, 48),
		Glow = Color3.fromRGB(255, 238, 150),
		Badge = Color3.fromRGB(218, 146, 18),
		Label = "LENDÁRIO",
	},
	Secreto = {
		Main = Color3.fromRGB(16, 16, 22),
		Glow = Color3.fromRGB(224, 32, 62),
		Badge = Color3.fromRGB(10, 10, 14),
		Label = "SECRETO",
	},
}

-- Layout dos 3 pedestais no palco (relativo ao STAGE_ORIGIN)
-- Camera fica em +Z olhando para -Z; personagens olham para +Z (em direcao a camera)
Themes.Slots = {
	{
		Key = "Left",
		Index = 1,
		Offset = Vector3.new(-6.5, 0.0, 1.4),
		YawDeg = 22, -- vira levemente para o centro/camera
		PedestalHeight = 1.0,
		PedestalRadius = 3.1,
		ScaleTargetHeight = 5.9,
		PoseName = "Left_GuardReady",
		IsHero = false,
		MaxAuraWidth = 4.6,
	},
	{
		Key = "Center",
		Index = 2,
		Offset = Vector3.new(0.0, 1.25, -0.4),
		YawDeg = 0, -- de frente imponente
		PedestalHeight = 2.25,
		PedestalRadius = 3.7,
		ScaleTargetHeight = 6.5,
		PoseName = "Center_HeroPower",
		IsHero = true,
		MaxAuraWidth = 5.6,
	},
	{
		Key = "Right",
		Index = 3,
		Offset = Vector3.new(6.5, 0.0, 1.4),
		YawDeg = -22, -- vira levemente para o centro/camera
		PedestalHeight = 1.0,
		PedestalRadius = 3.1,
		ScaleTargetHeight = 5.9,
		PoseName = "Right_RivalStance",
		IsHero = false,
		MaxAuraWidth = 4.6,
	},
}

-- Enquadramento da camera (relativo ao STAGE_ORIGIN)
Themes.Camera = {
	Position = Vector3.new(0, 6.7, 23.6),
	LookAt = Vector3.new(0, 4.9, -0.8),
	FieldOfView = 44,
	DriftX = 0.24,
	DriftY = 0.12,
	DriftFreq = 0.40,
}

export type StageTheme = {
	Id: string,
	Architecture: string,
	Title: string,
	Tagline: string,
	SealTexture: string,
	Primary: Color3,
	Secondary: Color3,
	Accent: Color3,
	FloorColor: Color3,
	FloorMaterial: Enum.Material,
	TrimColor: Color3,
	StoneColor: Color3,
	SkyTop: Color3,
	SkyMid: Color3,
	SkyHorizon: Color3,
	SunburstColor: Color3,
	AmbientParticle: {
		Texture: string,
		ColorA: Color3,
		ColorB: Color3,
		Rate: number,
		SizeMin: number,
		SizeMax: number,
		SpeedMin: number,
		SpeedMax: number,
		Accel: Vector3,
		LightEmission: number,
		LifetimeMin: number,
		LifetimeMax: number,
	},
	KeyLightColor: Color3,
	RimLightColor: Color3,
}

Themes.Presets = {
	Todos_Comum = {
		Id = "Todos_Comum",
		Architecture = "Celestial",
		Title = "SANTUÁRIO DAS ESTRELAS",
		Tagline = "TODOS OS ANIMES • INVOCAÇÃO COMUM",
		SealTexture = Themes.Assets.CelestialSeal,
		Primary = Color3.fromRGB(255, 206, 72),
		Secondary = Color3.fromRGB(72, 174, 255),
		Accent = Color3.fromRGB(255, 240, 170),
		FloorColor = Color3.fromRGB(26, 32, 54),
		FloorMaterial = Enum.Material.SmoothPlastic,
		TrimColor = Color3.fromRGB(248, 198, 72),
		StoneColor = Color3.fromRGB(36, 44, 72),
		SkyTop = Color3.fromRGB(16, 30, 74),
		SkyMid = Color3.fromRGB(36, 68, 138),
		SkyHorizon = Color3.fromRGB(132, 114, 188),
		SunburstColor = Color3.fromRGB(255, 218, 92),
		AmbientParticle = {
			Texture = Themes.Assets.StarFlare,
			ColorA = Color3.fromRGB(255, 232, 130),
			ColorB = Color3.fromRGB(120, 205, 255),
			Rate = 18,
			SizeMin = 0.22,
			SizeMax = 0.55,
			SpeedMin = 1.4,
			SpeedMax = 3.2,
			Accel = Vector3.new(0, 0.9, 0),
			LightEmission = 1.0,
			LifetimeMin = 2.4,
			LifetimeMax = 4.2,
		},
		KeyLightColor = Color3.fromRGB(255, 244, 224),
		RimLightColor = Color3.fromRGB(255, 206, 92),
	},

	Todos_Premium = {
		Id = "Todos_Premium",
		Architecture = "Celestial",
		Title = "SANTUÁRIO CELESTIAL MÍTICO",
		Tagline = "TODOS OS ANIMES • INVOCAÇÃO PREMIUM",
		SealTexture = Themes.Assets.CelestialSeal,
		Primary = Color3.fromRGB(184, 88, 255),
		Secondary = Color3.fromRGB(255, 208, 68),
		Accent = Color3.fromRGB(234, 184, 255),
		FloorColor = Color3.fromRGB(26, 18, 44),
		FloorMaterial = Enum.Material.SmoothPlastic,
		TrimColor = Color3.fromRGB(255, 206, 74),
		StoneColor = Color3.fromRGB(40, 26, 68),
		SkyTop = Color3.fromRGB(24, 16, 62),
		SkyMid = Color3.fromRGB(78, 36, 138),
		SkyHorizon = Color3.fromRGB(164, 72, 202),
		SunburstColor = Color3.fromRGB(255, 214, 88),
		AmbientParticle = {
			Texture = Themes.Assets.StarFlare,
			ColorA = Color3.fromRGB(224, 155, 255),
			ColorB = Color3.fromRGB(255, 218, 95),
			Rate = 22,
			SizeMin = 0.24,
			SizeMax = 0.62,
			SpeedMin = 1.6,
			SpeedMax = 3.6,
			Accel = Vector3.new(0, 1.1, 0),
			LightEmission = 1.0,
			LifetimeMin = 2.2,
			LifetimeMax = 4.0,
		},
		KeyLightColor = Color3.fromRGB(255, 240, 255),
		RimLightColor = Color3.fromRGB(205, 125, 255),
	},

	Recrutas = {
		Id = "Recrutas",
		Architecture = "Celestial",
		Title = "RECRUTAS DA ACADEMIA",
		Tagline = "BANNER INICIAL \u{2022} 100% COMUM \u{2022} 100 GOLD",
		SealTexture = Themes.Assets.CelestialSeal,
		Primary = Color3.fromRGB(52, 218, 168),
		Secondary = Color3.fromRGB(255, 206, 72),
		Accent = Color3.fromRGB(168, 255, 224),
		FloorColor = Color3.fromRGB(22, 36, 56),
		FloorMaterial = Enum.Material.SmoothPlastic,
		TrimColor = Color3.fromRGB(52, 218, 168),
		StoneColor = Color3.fromRGB(32, 48, 76),
		SkyTop = Color3.fromRGB(14, 30, 68),
		SkyMid = Color3.fromRGB(24, 78, 118),
		SkyHorizon = Color3.fromRGB(58, 174, 164),
		SunburstColor = Color3.fromRGB(118, 248, 206),
		AmbientParticle = {
			Texture = Themes.Assets.StarFlare,
			ColorA = Color3.fromRGB(108, 248, 202),
			ColorB = Color3.fromRGB(255, 224, 112),
			Rate = 20,
			SizeMin = 0.22,
			SizeMax = 0.52,
			SpeedMin = 1.4,
			SpeedMax = 3.0,
			Accel = Vector3.new(0, 0.9, 0),
			LightEmission = 1.0,
			LifetimeMin = 2.4,
			LifetimeMax = 4.2,
		},
		KeyLightColor = Color3.fromRGB(238, 255, 248),
		RimLightColor = Color3.fromRGB(72, 232, 184),
	},

	Naruto = {
		Id = "Naruto",
		Architecture = "Naruto",
		Title = "BANNER DA VILA DA FOLHA",
		Tagline = "VILA DA FOLHA \u{2022} SANTU\u{c1}RIO SHINOBI OCULTO",
		SealTexture = Themes.Assets.NarutoSeal,
		Primary = Color3.fromRGB(255, 134, 34),
		Secondary = Color3.fromRGB(224, 52, 42),
		Accent = Color3.fromRGB(255, 216, 104),
		FloorColor = Color3.fromRGB(52, 42, 38),
		FloorMaterial = Enum.Material.Slate,
		TrimColor = Color3.fromRGB(218, 52, 38),
		StoneColor = Color3.fromRGB(78, 66, 62),
		SkyTop = Color3.fromRGB(48, 24, 68),
		SkyMid = Color3.fromRGB(166, 58, 44),
		SkyHorizon = Color3.fromRGB(255, 148, 62),
		SunburstColor = Color3.fromRGB(255, 168, 52),
		AmbientParticle = {
			Texture = Themes.Assets.LeafPetal,
			ColorA = Color3.fromRGB(255, 162, 68),
			ColorB = Color3.fromRGB(255, 114, 134),
			Rate = 22,
			SizeMin = 0.28,
			SizeMax = 0.56,
			SpeedMin = 1.4,
			SpeedMax = 3.0,
			Accel = Vector3.new(2.2, -0.7, 0.4),
			LightEmission = 0.45,
			LifetimeMin = 3.2,
			LifetimeMax = 5.4,
		},
		KeyLightColor = Color3.fromRGB(255, 232, 206),
		RimLightColor = Color3.fromRGB(255, 138, 46),
	},

	OnePiece = {
		Id = "OnePiece",
		Architecture = "OnePiece",
		Title = "BANNER DOS MARES LIVRES",
		Tagline = "MARES LIVRES \u{2022} CONV\u{c9}S DOS IMPERADORES",
		SealTexture = Themes.Assets.OnePieceCompass,
		Primary = Color3.fromRGB(48, 198, 255),
		Secondary = Color3.fromRGB(255, 204, 62),
		Accent = Color3.fromRGB(148, 238, 255),
		FloorColor = Color3.fromRGB(82, 54, 34),
		FloorMaterial = Enum.Material.WoodPlanks,
		TrimColor = Color3.fromRGB(246, 194, 64),
		StoneColor = Color3.fromRGB(58, 38, 24),
		SkyTop = Color3.fromRGB(18, 64, 134),
		SkyMid = Color3.fromRGB(38, 138, 212),
		SkyHorizon = Color3.fromRGB(118, 222, 248),
		SunburstColor = Color3.fromRGB(255, 218, 92),
		AmbientParticle = {
			Texture = Themes.Assets.StarFlare,
			ColorA = Color3.fromRGB(124, 232, 255),
			ColorB = Color3.fromRGB(255, 222, 108),
			Rate = 18,
			SizeMin = 0.22,
			SizeMax = 0.52,
			SpeedMin = 1.2,
			SpeedMax = 2.8,
			Accel = Vector3.new(1.4, 0.7, 0.3),
			LightEmission = 0.95,
			LifetimeMin = 2.5,
			LifetimeMax = 4.4,
		},
		KeyLightColor = Color3.fromRGB(238, 248, 255),
		RimLightColor = Color3.fromRGB(72, 206, 255),
	},

	Bleach = {
		Id = "Bleach",
		Architecture = "Naruto",
		Title = "BANNER DO REINO DAS ALMAS",
		Tagline = "REINO DAS ALMAS \u{2022} DOM\u{cd}NIO ESPIRITUAL",
		SealTexture = Themes.Assets.CelestialSeal,
		Primary = Color3.fromRGB(48, 222, 248),
		Secondary = Color3.fromRGB(255, 136, 40),
		Accent = Color3.fromRGB(162, 245, 255),
		FloorColor = Color3.fromRGB(22, 26, 38),
		FloorMaterial = Enum.Material.Slate,
		TrimColor = Color3.fromRGB(48, 212, 238),
		StoneColor = Color3.fromRGB(36, 40, 58),
		SkyTop = Color3.fromRGB(10, 14, 34),
		SkyMid = Color3.fromRGB(22, 52, 92),
		SkyHorizon = Color3.fromRGB(56, 152, 198),
		SunburstColor = Color3.fromRGB(82, 228, 255),
		AmbientParticle = {
			Texture = Themes.Assets.LeafPetal,
			ColorA = Color3.fromRGB(92, 232, 255),
			ColorB = Color3.fromRGB(255, 158, 196),
			Rate = 22,
			SizeMin = 0.24,
			SizeMax = 0.54,
			SpeedMin = 1.6,
			SpeedMax = 3.4,
			Accel = Vector3.new(1.5, -0.4, 0.2),
			LightEmission = 0.85,
			LifetimeMin = 2.6,
			LifetimeMax = 4.6,
		},
		KeyLightColor = Color3.fromRGB(226, 246, 255),
		RimLightColor = Color3.fromRGB(64, 222, 255),
	},

	-- Presets prontos para futuros banners
	DragonBall = {
		Id = "DragonBall",
		Architecture = "Celestial",
		Title = "BANNER DA ESFERA SUPREMA",
		Tagline = "ESFERA SUPREMA \u{2022} PLANALTO DA AURA DOURADA",
		SealTexture = Themes.Assets.CelestialSeal,
		Primary = Color3.fromRGB(255, 208, 44),
		Secondary = Color3.fromRGB(64, 212, 255),
		Accent = Color3.fromRGB(255, 245, 168),
		FloorColor = Color3.fromRGB(46, 44, 52),
		FloorMaterial = Enum.Material.Slate,
		TrimColor = Color3.fromRGB(255, 206, 54),
		StoneColor = Color3.fromRGB(68, 62, 74),
		SkyTop = Color3.fromRGB(14, 28, 66),
		SkyMid = Color3.fromRGB(36, 86, 132),
		SkyHorizon = Color3.fromRGB(196, 146, 56),
		SunburstColor = Color3.fromRGB(255, 220, 76),
		AmbientParticle = {
			Texture = Themes.Assets.SparkShard,
			ColorA = Color3.fromRGB(255, 224, 78),
			ColorB = Color3.fromRGB(108, 226, 255),
			Rate = 22,
			SizeMin = 0.22,
			SizeMax = 0.48,
			SpeedMin = 2.8,
			SpeedMax = 5.4,
			Accel = Vector3.new(0, 1.8, 0),
			LightEmission = 1.0,
			LifetimeMin = 1.8,
			LifetimeMax = 3.2,
		},
		KeyLightColor = Color3.fromRGB(255, 244, 214),
		RimLightColor = Color3.fromRGB(255, 212, 62),
	},

	JujutsuKaisen = {
		Id = "JujutsuKaisen",
		Architecture = "Naruto",
		Title = "BANNER DA ORDEM MALDITA",
		Tagline = "ORDEM MALDITA \u{2022} SANTU\u{c1}RIO AMALDI\u{c7}OADO",
		SealTexture = Themes.Assets.CelestialSeal,
		Primary = Color3.fromRGB(178, 72, 255),
		Secondary = Color3.fromRGB(232, 46, 86),
		Accent = Color3.fromRGB(122, 222, 255),
		FloorColor = Color3.fromRGB(22, 16, 30),
		FloorMaterial = Enum.Material.Slate,
		TrimColor = Color3.fromRGB(218, 44, 78),
		StoneColor = Color3.fromRGB(36, 26, 48),
		SkyTop = Color3.fromRGB(12, 8, 22),
		SkyMid = Color3.fromRGB(54, 16, 46),
		SkyHorizon = Color3.fromRGB(132, 28, 64),
		SunburstColor = Color3.fromRGB(224, 76, 146),
		AmbientParticle = {
			Texture = Themes.Assets.StarFlare,
			ColorA = Color3.fromRGB(196, 98, 255),
			ColorB = Color3.fromRGB(255, 74, 118),
			Rate = 20,
			SizeMin = 0.24,
			SizeMax = 0.54,
			SpeedMin = 1.5,
			SpeedMax = 3.4,
			Accel = Vector3.new(0, 1.2, 0),
			LightEmission = 1.0,
			LifetimeMin = 2.2,
			LifetimeMax = 3.8,
		},
		KeyLightColor = Color3.fromRGB(244, 226, 255),
		RimLightColor = Color3.fromRGB(226, 72, 152),
	},
}

function Themes.GetTheme(bannerId: string?, portalId: string?): StageTheme
	local bid = bannerId or "Todos"
	if bid == "Todos" then
		if portalId == "Premium" then
			return Themes.Presets.Todos_Premium
		end
		return Themes.Presets.Todos_Comum
	end
	local preset = Themes.Presets[bid]
	if preset then
		return preset
	end
	local bDef = SummonData.Banners and SummonData.Banners[bid]
	if bDef and bDef.Anime and Themes.Presets[bDef.Anime] then
		return Themes.Presets[bDef.Anime]
	end
	return if portalId == "Premium" then Themes.Presets.Todos_Premium else Themes.Presets.Todos_Comum
end

-- Ranking para escolha deterministica dos 3 personagens principais do banner
local RARITY_RANK: { [string]: number } = {
	Secreto = 5,
	Lendario = 4,
	Epico = 3,
	Raro = 2,
	Comum = 1,
}

-- Preferencia de desempate dentro da MESMA raridade (Epicos sempre vencem Raros automaticamente)
local PREFERRED_ORDER: { [string]: number } = {
	Sukuna = 120,
	San = 100,
	BarbaBranca = 95,
	Setero = 90,
	Byakuya = 88,
	Sarutobi = 85,
	Luffy = 80,
	Naruto = 78,
	Ichigo = 77,
	Nanami = 76,
	Freeza = 76,
	Zoro = 75,
	Sasuke = 72,
	Vegeta = 72,
	Renji = 71,
	Fushiguro = 71,
	Kakashi = 70,
	Todo = 70,
	Gohan = 70,
	Rukia = 69,
	Sanji = 68,
	Kaen = 66,
	Sora = 65,
	Lina = 64,
	Yomogi = 63,
	Raiko = 62,
	Tora = 61,
	Goro = 60,
	Bram = 59,
}

local function sortScore(id: string, def: any): number
	local customBonus = if def.PlaceholderColors == nil then 10000 else 0
	local prefBonus = (PREFERRED_ORDER[id] or 0) * 100
	return customBonus + prefBonus + (def.Power or def.BaseAttack or def.Attack or 0)
end

-- Retorna sempre 3 slots: { [1] = Left (Epico/Fallback), [2] = Center (Lendario), [3] = Right (Epico/Fallback) }
function Themes.ResolveFeatured(bannerId: string?, portalId: string?, weeklyLegendaryId: string?): { { Id: string, Def: any, SlotRole: string } }
	local bid = bannerId or "Todos"
	local bDef = SummonData.Banners and SummonData.Banners[bid]
	local animeFilter = bDef and bDef.Anime or nil

	local byRarity: { [string]: { { Id: string, Def: any } } } = {
		Lendario = {},
		Epico = {},
		Raro = {},
		Comum = {},
	}

	for id, def in pairs(Characters.List) do
		if not def.Prototype then
			if (not animeFilter) or def.Anime == animeFilter then
				local bucket = byRarity[def.Rarity]
				if bucket then
					table.insert(bucket, { Id = id, Def = def })
				end
			end
		end
	end

	for _, list in pairs(byRarity) do
		table.sort(list, function(a, b)
			local sa, sb = sortScore(a.Id, a.Def), sortScore(b.Id, b.Def)
			if sa ~= sb then
				return sa > sb
			end
			return a.Id < b.Id
		end)
	end

	-- 1. Centro: Lendario principal (em "Todos", prioriza o destaque semanal se estiver no pool; senao o topo dos Lendarios)
	local centerPick = nil
	if weeklyLegendaryId and weeklyLegendaryId ~= "" then
		for _, item in ipairs(byRarity.Lendario) do
			if item.Id == weeklyLegendaryId then
				centerPick = item
				break
			end
		end
	end
	if not centerPick then
		-- Para "Todos", prefere San se disponivel (lendario iconico com AuraVfx); para outros animes, primeiro Lendario
		if not animeFilter then
			for _, item in ipairs(byRarity.Lendario) do
				if item.Id == "San" then
					centerPick = item
					break
				end
			end
		end
		centerPick = centerPick or byRarity.Lendario[1] or byRarity.Epico[1] or byRarity.Raro[1] or byRarity.Comum[1]
	end

	local used: { [string]: boolean } = {}
	if centerPick then
		used[centerPick.Id] = true
	end

	-- 2. Laterais: 2 Epicos do banner (se o anime ainda tiver < 2 Epicos, completa com o maior Raro/Lendario restante)
	local sideCandidates: { { Id: string, Def: any } } = {}
	for _, rarity in ipairs({ "Epico", "Raro", "Lendario", "Comum" }) do
		for _, item in ipairs(byRarity[rarity]) do
			if not used[item.Id] then
				table.insert(sideCandidates, item)
			end
		end
	end

	local leftPick = sideCandidates[1]
	local rightPick = sideCandidates[2]

	-- Garante que mesmo em pools minusculos nao falte nenhum slot
	if not leftPick then
		leftPick = centerPick
	end
	if not rightPick then
		rightPick = leftPick or centerPick
	end

	local out = {}
	if leftPick then
		out[1] = { Id = leftPick.Id, Def = leftPick.Def, SlotRole = "FlankLeft" }
	end
	if centerPick then
		out[2] = { Id = centerPick.Id, Def = centerPick.Def, SlotRole = "HeroCenter" }
	end
	if rightPick then
		out[3] = { Id = rightPick.Id, Def = rightPick.Def, SlotRole = "FlankRight" }
	end
	return out
end

-- Poses heroicas de banner (graus; adaptadas automaticamente para I-Pose, A-Pose e Skinned Bones)
-- Regra confirmada no BaseClient:
--   UpperArm X+ = braco para frente/cima; LeftUpperArm Z- = abre para esquerda; RightUpperArm Z+ = abre para direita
--   Elbow X+ = dobra antebraco para frente/cima; Knee X- = dobra joelho para tras; UpperTorso X+ = peito erguido
Themes.Poses = {
	Center_HeroPower = {
		-- Postura Lendaria central: peito altivo, ombro direito levemente a frente com braco em poder/guarda, esquerdo firme junto ao corpo
		LowerTorso = { Y = 0.0, RX = -2, RY = -10, RZ = 0 },
		UpperTorso = { RX = 5, RY = 14, RZ = 0 },
		Head = { RX = -3, RY = -4, RZ = 2 },
		LeftUpperArm = { RX = -10, RY = 8, RZ = -9 },
		LeftLowerArm = { RX = 26, RY = 0, RZ = 0 },
		RightUpperArm = { RX = 38, RY = -14, RZ = 10 },
		RightLowerArm = { RX = 34, RY = 0, RZ = 0 },
		LeftUpperLeg = { RX = 9, RY = -6, RZ = -5 },
		LeftLowerLeg = { RX = -12, RY = 0, RZ = 0 },
		LeftFoot = { RX = 3, RY = 0, RZ = 0 },
		RightUpperLeg = { RX = -7, RY = 8, RZ = 5 },
		RightLowerLeg = { RX = -8, RY = 0, RZ = 0 },
		RightFoot = { RX = 12, RY = 0, RZ = 0 },
		BreathAmp = 0.9,
	},
	Left_GuardReady = {
		-- Flanco esquerdo: angulado para o centro, braco direito em guarda/punho confiante a frente, esquerdo recuado pronto
		LowerTorso = { Y = -0.04, RX = -3, RY = 14, RZ = 0 },
		UpperTorso = { RX = 3, RY = -12, RZ = -2 },
		Head = { RX = -2, RY = -8, RZ = 2 },
		LeftUpperArm = { RX = -16, RY = 6, RZ = -9 },
		LeftLowerArm = { RX = 28, RY = 0, RZ = 0 },
		RightUpperArm = { RX = 44, RY = -16, RZ = 8 },
		RightLowerArm = { RX = 38, RY = 0, RZ = 0 },
		LeftUpperLeg = { RX = -8, RY = -5, RZ = -6 },
		LeftLowerLeg = { RX = -10, RY = 0, RZ = 0 },
		LeftFoot = { RX = 14, RY = 0, RZ = 0 },
		RightUpperLeg = { RX = 12, RY = 5, RZ = 4 },
		RightLowerLeg = { RX = -15, RY = 0, RZ = 0 },
		RightFoot = { RX = 3, RY = 0, RZ = 0 },
		BreathAmp = 0.8,
	},
	Right_RivalStance = {
		-- Flanco direito: postura rival estilosa, braco esquerdo erguido em guarda/jutsu, direito relaxado junto a cintura/espada
		LowerTorso = { Y = -0.03, RX = -2, RY = -14, RZ = 0 },
		UpperTorso = { RX = 4, RY = 12, RZ = 2 },
		Head = { RX = -2, RY = 8, RZ = -2 },
		LeftUpperArm = { RX = 42, RY = 16, RZ = -8 },
		LeftLowerArm = { RX = 38, RY = 0, RZ = 0 },
		RightUpperArm = { RX = -14, RY = -6, RZ = 9 },
		RightLowerArm = { RX = 24, RY = 0, RZ = 0 },
		LeftUpperLeg = { RX = 12, RY = -5, RZ = -4 },
		LeftLowerLeg = { RX = -15, RY = 0, RZ = 0 },
		LeftFoot = { RX = 3, RY = 0, RZ = 0 },
		RightUpperLeg = { RX = -8, RY = 5, RZ = 6 },
		RightLowerLeg = { RX = -10, RY = 0, RZ = 0 },
		RightFoot = { RX = 14, RY = 0, RZ = 0 },
		BreathAmp = 0.8,
	},
}

return Themes
