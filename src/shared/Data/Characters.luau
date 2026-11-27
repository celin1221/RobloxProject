--[[
	Characters (GDD secao 4)
	Personagens sao so dados. ModelName e o nome do modelo em ServerStorage/Characters
	(e a unica ligacao com o modelo 3D; trocar o modelo nao exige mexer em codigo).

	BaseStats sao os atributos no BaseLevel, exatamente como na tabela do GDD.
	Por nivel: +3 HP e +1 em Ataque, Defesa e Velocidade (Growth),
	multiplicado pelo multiplicador da raridade.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Moves = require(script.Parent:WaitForChild("Moves"))
local Passives = require(script.Parent:WaitForChild("Passives"))

local Characters = {}

Characters.MaxLevel = 50

-- Animacoes padrao compartilhadas (IDs autorizados na experiencia; BaseClient anima Idle/Walk proceduralmente a 60 FPS)
Characters.DefaultAnimations = {
	Idle = 95978454415689,
	Walk = 81539047602340,
}

Characters.Growth = { HP = 3, Attack = 1, Defense = 1, Speed = 1 } -- mantido por compatibilidade de referencia
-- Crescimento proporcional estilo Pokemon: preserva 100% os arquetipos extremos ate o Nv. 50
-- levelFactor(level) = GrowthBase + GrowthPerLevel * level  (Nv. 1 = 0.595x | Nv. 10 = 1.000x | Nv. 50 = 2.800x)
Characters.GrowthBase = 0.55
Characters.GrowthPerLevel = 0.045

-- Escala de BST por Colecao/Geracao no PvE e Casual (+5% por colecao/Ginasio; na Ranqueada TODAS = 1.00x)
Characters.CollectionScales = {
	Generico = 1.00,
	Naruto = 1.00,
	OnePiece = 1.05,
	Bleach = 1.10,
	JujutsuKaisen = 1.15,
	DragonBall = 1.20,
}

-- Regua de BST normalizado por raridade na Ranqueada (Nv. 10 = 1.00x; Secreto normaliza para Lendario = 170)
Characters.RankedBst = {
	Comum = 125,
	Raro = 138,
	Epico = 152,
	Lendario = 170,
	Secreto = 170,
}

-- Categorizacao por anime (tag de codigo usada em Mochila, Equipe, Torre, Ginasios e Banners)
Characters.AnimeOrder = { "OnePiece", "Naruto", "Bleach", "DragonBall", "JujutsuKaisen", "Generico" }
Characters.Animes = {
	Naruto = { Id = "Naruto", Name = "Vila da Folha", Short = "FOLHA", Tier = 1, CollectionScale = 1.00 },
	OnePiece = { Id = "OnePiece", Name = "Mares Livres", Short = "MARES", Tier = 2, CollectionScale = 1.05 },
	Bleach = { Id = "Bleach", Name = "Reino das Almas", Short = "ALMAS", Tier = 3, CollectionScale = 1.10 },
	JujutsuKaisen = { Id = "JujutsuKaisen", Name = "Ordem Maldita", Short = "MALDITOS", Tier = 4, CollectionScale = 1.15 },
	DragonBall = { Id = "DragonBall", Name = "Esfera Suprema", Short = "SUPREMA", Tier = 5, CollectionScale = 1.20 },
	Generico = { Id = "Generico", Name = "Gen\u{e9}rico", Short = "GEN\u{c9}RICO", Generic = true, Tier = 0, CollectionScale = 1.00 },
}

-- Tabela de raridade do GDD (secao 4)
Characters.Rarities = {
	Comum = { Name = "Comum", StatMultiplier = 1.00, EncounterChance = 0.60, OrePerHour = 15, CaptureRate = 0.60 },
	Raro = { Name = "Raro", StatMultiplier = 1.10, EncounterChance = 0.28, OrePerHour = 28, CaptureRate = 0.40 },
	Epico = { Name = "Épico", StatMultiplier = 1.20, EncounterChance = 0.10, OrePerHour = 45, CaptureRate = 0.20 },
	Lendario = { Name = "Lendário", StatMultiplier = 1.35, EncounterChance = 0.02, OrePerHour = 75, CaptureRate = 0.08 },
	Secreto = { Name = "Secreto", StatMultiplier = 1.50, EncounterChance = 0, OrePerHour = 110, CaptureRate = 0.03 },
}

--[[
	Captura (GDD secao 7):
	  Chance = Taxa x (1 - 0,7 x HP_atual / HP_max) x Selo x Status
	  Taxa pela raridade (CaptureRate); Selo 1 (Contrato) ou 1,5 (Superior); Status 1,5 se o alvo tiver status.
]]
function Characters.CaptureChance(characterId: string, hp: number, maxHp: number, sealMultiplier: number, hasStatus: boolean): number
	local def = assert(Characters.List[characterId], "Personagem desconhecido: " .. tostring(characterId))
	local rarity = Characters.Rarities[def.Rarity] or Characters.Rarities.Comum
	local chance = rarity.CaptureRate * (1 - 0.7 * math.clamp(hp / math.max(1, maxHp), 0, 1)) * (sealMultiplier or 1) * (if hasStatus then 1.5 else 1)
	return math.clamp(chance, 0, 1)
end

-- Variantes visuais (GDD secao 4): mudam so aparencia e atributos, nunca golpes
Characters.VariantBonus = {
	Brilhante = 0.10, Prata = 0.03, Ouro = 0.05, Esmeralda = 0.07, Rubi = 0.07, Diamante = 0.07, ArcoIris = 0.10, Gigante = 0.05,
}
local Variants = { "Brilhante", "Prata", "Ouro", "Esmeralda", "Rubi", "Diamante", "ArcoIris", "Gigante" }

Characters.List = {
	Kaen = {
		Name = "Kaen",
		ModelName = "Kaen",
		Anime = "Generico",
		Type = "Espadachim",
		Rarity = "Comum",
		Passive = "ChamaInterior",
		Concept = "Espadachim jovem e impulsivo",
		BaseLevel = 10,
		BaseStats = { HP = 53, Attack = 24, Defense = 18, Speed = 30 }, -- BST 125 (Atacante Agil; preserva ATK 24 GDD)
		Learnset = {
			{ Level = 1, Move = "CorteBasico" },
			{ Level = 1, Move = "CorteCruzado" },
			{ Level = 5, Move = "PosturaDaLamina" },
			{ Level = 8, Move = "Investida" },
			{ Level = 10, Move = "CorteFlamejante" },
			{ Level = 14, Move = "BrasaViva" },
			{ Level = 18, Move = "EstocadaVeloz" },
			{ Level = 22, Move = "CorteDrenante" },
			{ Level = 28, Move = "DancaDasEspadas" },
			{ Level = 34, Move = "TempestadeDeCortes" },
			{ Level = 40, Move = "InvestidaCortante" },
		},
	},
	Raiko = {
		Name = "Raiko",
		ModelName = "Raiko",
		Anime = "Generico",
		Type = "Lutador",
		Rarity = "Comum",
		Passive = "EspiritoGuerreiro",
		Concept = "Lutador de rua calmo e r\u{e1}pido",
		BaseLevel = 10,
		BaseStats = { HP = 63, Attack = 24, Defense = 20, Speed = 18 }, -- BST 125 (Bruiser Equilibrado; preserva DEF 20 GDD)
		Learnset = {
			{ Level = 1, Move = "SocoDireto" },
			{ Level = 1, Move = "PunhoDeMare" },
			{ Level = 5, Move = "Estatica" },
			{ Level = 10, Move = "Descarga" },
			{ Level = 14, Move = "SocoRelampago" },
			{ Level = 18, Move = "Rasteira" },
			{ Level = 22, Move = "Agilidade" },
			{ Level = 26, Move = "GiroVarredor" },
			{ Level = 30, Move = "OndaDeImpacto" },
			{ Level = 36, Move = "FocoInterior" },
			{ Level = 40, Move = "ImpactoTotal" },
		},
	},
	Yomogi = {
		Name = "Yomogi",
		ModelName = "Yomogi",
		Anime = "Generico",
		Type = "Mago",
		Rarity = "Comum",
		Passive = "Regeneracao",
		Concept = "Meio-fera da floresta, instintivo e protetor",
		BaseLevel = 10,
		BaseStats = { HP = 72, Attack = 16, Defense = 25, Speed = 12 }, -- BST 125 (Tanque de HP / Clerigo Sustentado)
		Learnset = {
			{ Level = 1, Move = "Arranhao" },
			{ Level = 1, Move = "SementeToxica" },
			{ Level = 5, Move = "CascaDeCarvalho" },
			{ Level = 10, Move = "GaiolaDeEspinhos" },
			{ Level = 14, Move = "FogoFatuo" },
			{ Level = 18, Move = "SifaoArcano" },
			{ Level = 22, Move = "RunasToxicas" },
			{ Level = 26, Move = "Recuperacao" },
			{ Level = 30, Move = "CuraLuminosa" },
			{ Level = 36, Move = "Purificacao" },
			{ Level = 42, Move = "ExplosaoAstral" },
		},
		-- Animacoes publicadas (copias em ServerStorage/Characters/Yomogi/Animations)
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 72898431375427, Faint = 108505801464543,
			Victory = 118621507192389, Mine = 102522462046052,
			GaiolaDeEspinhos = 138342022639761, Arranhao = 124943270558908,
			SementeToxica = 105789525703577, CascaDeCarvalho = 80204195163280,
		},
		Variants = Variants,
		-- Paleta da variante Brilhante: outono (verdes viram laranja e ambar)
		ShinyPalette = { Primary = Color3.fromRGB(214, 120, 40), Secondary = Color3.fromRGB(240, 190, 70) },
		KeepTextureParts = { "Head", "LeftHand", "RightHand" },
	},
	Setero = {
		Name = "Setero",
		ModelName = "Setero",
		Anime = "JujutsuKaisen",
		Type = "Mago",
		Rarity = "Lendario",
		Passive = "InfinitoAbsoluto",
		Concept = "Feiticeiro lend\u{e1}rio da barreira absoluta, mestre de Atra\u{e7}\u{e3}o e Colapso P\u{fa}rpura",
		BaseLevel = 10,
		BaseStats = { HP = 64, Attack = 38, Defense = 32, Speed = 36 }, -- BST 170 (Feiticeiro Supremo Agil & Intocavel)
		Learnset = {
			{ Level = 1, Move = "EsferaArcana" },
			{ Level = 1, Move = "SocoDireto" },
			{ Level = 5, Move = "PosturaDeCombate" },
			{ Level = 8, Move = "PulsoVeloz" },
			{ Level = 12, Move = "OndaArcana" },
			{ Level = 16, Move = "MenteCalma" },
			{ Level = 20, Move = "Proteger" },
			{ Level = 24, Move = "BarreiraArcana" },
			{ Level = 28, Move = "SifaoArcano" },
			{ Level = 32, Move = "VentoAFavor" },
			{ Level = 36, Move = "ExplosaoAstral" },
			{ Level = 42, Move = "Atracao" },
			{ Level = 50, Move = "TudoRoxo" },
		},
		-- Animacoes padrao R6-on-R15 autorizadas + golpes exclusivos (Atracao, TudoRoxo)
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			Atracao = 133310018588724, TudoRoxo = 131932987016123, Attack = 133310018588724, Special = 105158348948965,
		},
		Variants = Variants,
		-- Paleta da variante Brilhante: branco platina com azul glacial e energia celeste
		ShinyPalette = { Primary = Color3.fromRGB(230, 238, 252), Secondary = Color3.fromRGB(70, 180, 255) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
	Sukuna = {
		Name = "Sukuno",
		ModelName = "Sukuna",
		Anime = "JujutsuKaisen",
		Type = "Mago",
		Rarity = "Secreto",
		Passive = "ReiDasMaldicoes",
		Concept = "Soberano maldito ancestral, mestre dos cortes invis\u{ed}veis e do Templo Carmesim",
		BaseLevel = 10,
		BaseStats = { HP = 82, Attack = 44, Defense = 30, Speed = 34 }, -- BST 190 PvE/Casual (normalizado 170 na Ranqueada)
		Learnset = {
			{ Level = 1, Move = "EsferaArcana" },
			{ Level = 1, Move = "ChamaMistica" },
			{ Level = 5, Move = "SeloParalisante" },
			{ Level = 8, Move = "PulsoVeloz" },
			{ Level = 12, Move = "OndaArcana" },
			{ Level = 16, Move = "OlharIntimidador" },
			{ Level = 20, Move = "SifaoArcano" },
			{ Level = 24, Move = "Proteger" },
			{ Level = 28, Move = "ExplosaoAstral" },
			{ Level = 34, Move = "Fortificacao" },
			{ Level = 40, Move = "Desmantelar" },
			{ Level = 45, Move = "Clivar" },
			{ Level = 50, Move = "SantuarioMalevolente" },
		},
		DefaultOrder = { "Desmantelar", "Clivar", "Fortificacao", "SantuarioMalevolente" },
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			Attack = 133310018588724, Special = 105158348948965,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(22, 18, 28), Secondary = Color3.fromRGB(255, 58, 86) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
	San = {
		Name = "San",
		ModelName = "San",
		Anime = "DragonBall",
		Type = "Lutador",
		Rarity = "Lendario",
		Passive = "InstintoZenkai",
		Concept = "Artista marcial lend\u{e1}rio que canaliza aura celeste e energia espiritual",
		BaseLevel = 10,
		BaseStats = { HP = 80, Attack = 38, Defense = 24, Speed = 28 }, -- BST 170 (Guerreiro Marcial de Resistencia & Explosao)
		Learnset = {
			{ Level = 1, Move = "SocoDireto" },
			{ Level = 1, Move = "ComboMarcial" },
			{ Level = 5, Move = "PosturaDeCombate" },
			{ Level = 8, Move = "SocoRelampago" },
			{ Level = 12, Move = "QuebraGuarda" },
			{ Level = 16, Move = "Agilidade" },
			{ Level = 20, Move = "CorpoDeFerro" },
			{ Level = 24, Move = "PunhoDemolidor" },
			{ Level = 28, Move = "GritoDeGuerra" },
			{ Level = 32, Move = "FocoInterior" },
			{ Level = 36, Move = "CargaDeKi" },
			{ Level = 38, Move = "ImpactoTotal" },
			{ Level = 42, Move = "Kamehameha" },
			{ Level = 50, Move = "GenkiDama" },
		},
		-- Animacoes publicadas (copias em ServerStorage/Characters/San/Animations)
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			Kamehameha = 114895944226250, GenkiDama = 105158348948965,
			ComboMarcial = 135688782086034, CargaDeKi = 94954698224565,
			Attack = 135688782086034, Special = 105158348948965,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(255, 224, 95), Secondary = Color3.fromRGB(85, 215, 255) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
	BarbaBranca = {
		Name = "Barba Alva",
		ModelName = "BarbaBranca",
		Anime = "OnePiece",
		Type = "Espadachim",
		Rarity = "Lendario",
		Passive = "TremorDosMares",
		Concept = "Colosso lend\u{e1}rio dos mares capaz de rachar o pr\u{f3}prio ar com sua alabarda",
		BaseLevel = 10,
		BaseStats = { HP = 92, Attack = 41, Defense = 26, Speed = 11 }, -- BST 170 (Colosso Juggernaut Lento)
		Learnset = {
			{ Level = 1, Move = "CorteBasico" },
			{ Level = 1, Move = "CorteCruzado" },
			{ Level = 5, Move = "PosturaDaLamina" },
			{ Level = 10, Move = "CorteGiratorio" },
			{ Level = 14, Move = "OlharIntimidador" },
			{ Level = 18, Move = "QuebraLamina" },
			{ Level = 22, Move = "MuralhaDeFerro" },
			{ Level = 26, Move = "LaminaPesada" },
			{ Level = 30, Move = "GuardaAmpla" },
			{ Level = 34, Move = "CorteMurakumo" },
			{ Level = 38, Move = "HakiDoConquistador" },
			{ Level = 44, Move = "SocoSismico" },
			{ Level = 50, Move = "CeuETerra" },
		},
		-- Animacoes padrao compartilhadas + 4 golpes exclusivos publicados
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			SocoSismico = 111193439375608, CeuETerra = 98016585283343,
			CorteMurakumo = 136035334634731, HakiDoConquistador = 85577521631653,
			Attack = 136035334634731, Special = 98016585283343,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(220, 245, 255), Secondary = Color3.fromRGB(255, 215, 95) },
		KeepTextureParts = { "Head", "Head_Mesh", "Coat_Acc" },
	},
	Luffy = {
		Name = "Luffen",
		ModelName = "Luffy",
		Anime = "OnePiece",
		Type = "Lutador",
		Rarity = "Epico",
		Starter = true,
		Passive = "EspiritoGuerreiro",
		SecretPassive = "VontadeDeD",
		Concept = "Capit\u{e3}o pirata el\u{e1}stico com combos velozes e golpes de impacto",
		BaseLevel = 10,
		BaseStats = { HP = 68, Attack = 34, Defense = 22, Speed = 28 }, -- BST 152 (Brawler Relampago de Virada)
		Learnset = {
			{ Level = 1, Move = "SocoDireto" },
			{ Level = 1, Move = "ComboMarcial" },
			{ Level = 5, Move = "PosturaDeCombate" },
			{ Level = 8, Move = "SocoRelampago" },
			{ Level = 12, Move = "QuebraGuarda" },
			{ Level = 16, Move = "CorpoDeFerro" },
			{ Level = 20, Move = "PunhoDemolidor" },
			{ Level = 24, Move = "OndaDeImpacto" },
			{ Level = 28, Move = "GritoDeGuerra" },
			{ Level = 32, Move = "PunhoArdente" },
			{ Level = 36, Move = "GiroVarredor" },
			{ Level = 42, Move = "ImpactoTotal" },
		},
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			ComboMarcial = 135688782086034, SocoDireto = 135688782086034,
			QuebraGuarda = 111193439375608, PosturaDeCombate = 94954698224565,
			Attack = 135688782086034, Special = 111193439375608,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(255, 240, 250), Secondary = Color3.fromRGB(255, 195, 70) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
	Nami = {
		Name = "Nari",
		ModelName = "Nami",
		Anime = "OnePiece",
		Type = "Mago",
		Rarity = "Comum",
		Passive = "EscudoNatural",
		Concept = "Navegadora astuta especialista em tempestades e golpes em \u{e1}rea",
		BaseLevel = 10,
		BaseStats = { HP = 44, Attack = 31, Defense = 14, Speed = 36 }, -- BST 125 (Suporte/Canhao Tempestade Ultrarrapido)
		Learnset = {
			{ Level = 1, Move = "EsferaArcana" },
			{ Level = 1, Move = "Descarga" },
			{ Level = 5, Move = "SeloParalisante" },
			{ Level = 10, Move = "OndaArcana" },
			{ Level = 14, Move = "RaioCongelante" },
			{ Level = 18, Move = "VentoAFavor" },
			{ Level = 22, Move = "Desobstruir" },
			{ Level = 26, Move = "BarreiraArcana" },
			{ Level = 30, Move = "CuraLuminosa" },
			{ Level = 36, Move = "ExplosaoAstral" },
			{ Level = 42, Move = "MeteoroArcano" },
		},
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			Attack = 133310018588724, Special = 105158348948965,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(255, 215, 95), Secondary = Color3.fromRGB(80, 200, 255) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
	Usopp = {
		Name = "Yusop",
		ModelName = "Usopp",
		Anime = "OnePiece",
		Type = "Atirador",
		Rarity = "Comum",
		Passive = "OlhoDeAguia",
		Concept = "Atirador engenhoso de disparos certeiros e sementes explosivas",
		BaseLevel = 10,
		BaseStats = { HP = 49, Attack = 22, Defense = 20, Speed = 34 }, -- BST 125 (Atirador Veloz de Hazards)
		Learnset = {
			{ Level = 1, Move = "DisparoPreciso" },
			{ Level = 1, Move = "SementeToxica" },
			{ Level = 5, Move = "MiraFirme" },
			{ Level = 6, Move = "AtaqueRapido" },
			{ Level = 8, Move = "TiroRapido" },
			{ Level = 12, Move = "DardoVenenoso" },
			{ Level = 16, Move = "FocoDePrecisao" },
			{ Level = 18, Move = "DisparoDeRede" },
			{ Level = 22, Move = "BombaDeFumaca" },
			{ Level = 26, Move = "MinaDeEstrepes" },
			{ Level = 32, Move = "ChuvaDeProjeteis" },
			{ Level = 38, Move = "DisparoDeElite" },
		},
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			Attack = 105789525703577, Special = 105789525703577,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(245, 210, 80), Secondary = Color3.fromRGB(95, 220, 120) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
	Zoro = {
		Name = "Zoren",
		ModelName = "Zoro",
		Anime = "OnePiece",
		Type = "Espadachim",
		Rarity = "Raro",
		Passive = "Intimidacao",
		Concept = "Espadachim implac\u{e1}vel do estilo tr\u{ea}s l\u{e2}minas",
		BaseLevel = 10,
		BaseStats = { HP = 66, Attack = 37, Defense = 21, Speed = 14 }, -- BST 138 (Colosso Cortante)
		Learnset = {
			{ Level = 1, Move = "CorteBasico" },
			{ Level = 1, Move = "CorteCruzado" },
			{ Level = 5, Move = "PosturaDaLamina" },
			{ Level = 8, Move = "EstocadaVeloz" },
			{ Level = 12, Move = "CorteGiratorio" },
			{ Level = 16, Move = "LaminaAfiada" },
			{ Level = 20, Move = "QuebraLamina" },
			{ Level = 24, Move = "OlharIntimidador" },
			{ Level = 28, Move = "LaminaPesada" },
			{ Level = 32, Move = "DancaDasEspadas" },
			{ Level = 36, Move = "TempestadeDeCortes" },
			{ Level = 42, Move = "InvestidaCortante" },
		},
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			CorteMurakumo = 136035334634731, ComboMarcial = 135688782086034,
			Attack = 136035334634731, Special = 136035334634731,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(70, 230, 145), Secondary = Color3.fromRGB(165, 95, 255) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
	Sanji = {
		Name = "Sanzu",
		ModelName = "Sanji",
		Anime = "OnePiece",
		Type = "Lutador",
		Rarity = "Raro",
		Passive = "PassosVelozes",
		Concept = "Cozinheiro combatente especialista em chutes flamejantes r\u{e1}pidos e precisos",
		BaseLevel = 10,
		BaseStats = { HP = 54, Attack = 30, Defense = 17, Speed = 37 }, -- BST 138 (Pivot / Velocista de Chutes)
		Learnset = {
			{ Level = 1, Move = "SocoDireto" },
			{ Level = 1, Move = "ComboMarcial" },
			{ Level = 5, Move = "PosturaDeCombate" },
			{ Level = 8, Move = "SocoRelampago" },
			{ Level = 12, Move = "Rasteira" },
			{ Level = 16, Move = "Agilidade" },
			{ Level = 20, Move = "Proteger" },
			{ Level = 24, Move = "VentoAFavor" },
			{ Level = 28, Move = "PunhoArdente" },
			{ Level = 32, Move = "GiroVarredor" },
			{ Level = 38, Move = "ImpactoTotal" },
		},
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			ComboMarcial = 135688782086034,
			Attack = 135688782086034, Special = 135688782086034,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(255, 220, 90), Secondary = Color3.fromRGB(75, 185, 255) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},

	-- Anime: Naruto
	Sakura = {
		Name = "Sakira",
		ModelName = "Sakura",
		Anime = "Naruto",
		Type = "Lutador",
		Rarity = "Comum",
		Passive = "Regeneracao",
		Concept = "Lutadora \u{e1}gil de golpes f\u{ed}sicos diretos e quebra-guarda",
		BaseLevel = 10,
		BaseStats = { HP = 70, Attack = 25, Defense = 18, Speed = 12 }, -- BST 125 (Curandeira de HP Alto & Impacto)
		Learnset = {
			{ Level = 1, Move = "SocoDireto" },
			{ Level = 1, Move = "ComboMarcial" },
			{ Level = 5, Move = "PosturaDeCombate" },
			{ Level = 10, Move = "QuebraGuarda" },
			{ Level = 14, Move = "CorpoDeFerro" },
			{ Level = 18, Move = "SocoDrenante" },
			{ Level = 22, Move = "PunhoDemolidor" },
			{ Level = 26, Move = "CuraLuminosa" },
			{ Level = 30, Move = "Purificacao" },
			{ Level = 34, Move = "FocoInterior" },
			{ Level = 40, Move = "ImpactoTotal" },
		},
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			ComboMarcial = 135688782086034,
			Attack = 135688782086034, Special = 111193439375608,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(255, 175, 210), Secondary = Color3.fromRGB(115, 235, 155) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
	Shikamaru = {
		Name = "Shikaro",
		ModelName = "Shikamaru",
		Anime = "Naruto",
		Type = "Mago",
		Rarity = "Comum",
		Passive = "MenteTatica",
		Concept = "Estrategista t\u{e1}tico especialista em controle e paralisia de sombras",
		BaseLevel = 10,
		BaseStats = { HP = 48, Attack = 13, Defense = 29, Speed = 35 }, -- BST 125 (Suporte Controle Super-Veloz)
		Learnset = {
			{ Level = 1, Move = "EsferaArcana" },
			{ Level = 1, Move = "ChamaMistica" },
			{ Level = 5, Move = "SeloParalisante" },
			{ Level = 10, Move = "OlharIntimidador" },
			{ Level = 14, Move = "VenenoPuro" },
			{ Level = 18, Move = "DisparoDeRede" },
			{ Level = 22, Move = "NevoaDoSono" },
			{ Level = 26, Move = "BarreiraArcana" },
			{ Level = 30, Move = "RunasToxicas" },
			{ Level = 34, Move = "GuardaAmpla" },
			{ Level = 40, Move = "ExplosaoAstral" },
		},
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			Attack = 133310018588724, Special = 105158348948965,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(110, 88, 168), Secondary = Color3.fromRGB(145, 220, 120) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
	Kakashi = {
		Name = "Kashi",
		ModelName = "Kakashi",
		Anime = "Naruto",
		Type = "Mago",
		Rarity = "Raro",
		Passive = "GolpeCerteiro",
		Concept = "Veterano mascarado de reflexos r\u{e1}pidos e t\u{e9}cnicas em \u{e1}rea",
		BaseLevel = 10,
		BaseStats = { HP = 52, Attack = 34, Defense = 17, Speed = 35 }, -- BST 138 (Assassino Arcano Veloz)
		Learnset = {
			{ Level = 1, Move = "EsferaArcana" },
			{ Level = 1, Move = "Descarga" },
			{ Level = 5, Move = "SeloParalisante" },
			{ Level = 8, Move = "PulsoVeloz" },
			{ Level = 12, Move = "OndaArcana" },
			{ Level = 16, Move = "MenteCalma" },
			{ Level = 20, Move = "Proteger" },
			{ Level = 24, Move = "Desobstruir" },
			{ Level = 28, Move = "SifaoArcano" },
			{ Level = 34, Move = "ExplosaoAstral" },
			{ Level = 40, Move = "MeteoroArcano" },
		},
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			Attack = 133310018588724, Special = 105158348948965,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(220, 232, 248), Secondary = Color3.fromRGB(70, 200, 255) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
	Sasuke = {
		Name = "Sazuro",
		ModelName = "Sasuke",
		Anime = "Naruto",
		Type = "Espadachim",
		Rarity = "Raro",
		Passive = "SedeDeVitoria",
		Concept = "Espadachim disciplinado especialista em cortes el\u{e9}tricos r\u{e1}pidos e precisos",
		BaseLevel = 10,
		BaseStats = { HP = 48, Attack = 38, Defense = 16, Speed = 36 }, -- BST 138 (Sweeper Canhao de Vidro)
		Learnset = {
			{ Level = 1, Move = "CorteBasico" },
			{ Level = 1, Move = "CorteCruzado" },
			{ Level = 5, Move = "PosturaDaLamina" },
			{ Level = 8, Move = "EstocadaVeloz" },
			{ Level = 12, Move = "CorteFlamejante" },
			{ Level = 16, Move = "LaminaAfiada" },
			{ Level = 20, Move = "Proteger" },
			{ Level = 24, Move = "QuebraLamina" },
			{ Level = 28, Move = "DancaDasEspadas" },
			{ Level = 34, Move = "TempestadeDeCortes" },
			{ Level = 40, Move = "InvestidaCortante" },
		},
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			Attack = 136035334634731, Special = 136035334634731,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(80, 74, 148), Secondary = Color3.fromRGB(240, 120, 255) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
	Naruto = {
		Name = "Narito",
		ModelName = "Naruto",
		Anime = "Naruto",
		Type = "Lutador",
		Rarity = "Epico",
		Starter = true,
		Passive = "ChamaInterior",
		SecretPassive = "MantoDaRaposa",
		Concept = "Guerreiro determinado da Folha com vigor elevado e combos intensos",
		BaseLevel = 10,
		BaseStats = { HP = 78, Attack = 31, Defense = 21, Speed = 22 }, -- BST 152 (Tanque-Lutador de Vigor Infinito)
		Learnset = {
			{ Level = 1, Move = "SocoDireto" },
			{ Level = 1, Move = "ComboMarcial" },
			{ Level = 5, Move = "PosturaDeCombate" },
			{ Level = 6, Move = "AtaqueRapido" },
			{ Level = 8, Move = "SocoRelampago" },
			{ Level = 12, Move = "QuebraGuarda" },
			{ Level = 16, Move = "Agilidade" },
			{ Level = 20, Move = "SocoDrenante" },
			{ Level = 24, Move = "OndaDeImpacto" },
			{ Level = 28, Move = "GritoDeGuerra" },
			{ Level = 32, Move = "FocoInterior" },
			{ Level = 36, Move = "Desobstruir" },
			{ Level = 42, Move = "ImpactoTotal" },
		},
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			ComboMarcial = 135688782086034,
			Attack = 135688782086034, Special = 111193439375608,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(255, 224, 90), Secondary = Color3.fromRGB(255, 135, 35) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
	Sarutobi = {
		Name = "Hiruzo",
		ModelName = "Sarutobi",
		Anime = "Naruto",
		Type = "Mago",
		Rarity = "Lendario",
		Passive = "MestreDosElementos",
		Concept = "Mestre lend\u{e1}rio de todos os elementos da Vila da Folha",
		BaseLevel = 10,
		BaseStats = { HP = 76, Attack = 33, Defense = 37, Speed = 24 }, -- BST 170 (Mestre Elemental Defensivo)
		Learnset = {
			{ Level = 1, Move = "EsferaArcana" },
			{ Level = 1, Move = "ChamaMistica" },
			{ Level = 5, Move = "SeloParalisante" },
			{ Level = 10, Move = "OndaArcana" },
			{ Level = 14, Move = "MenteCalma" },
			{ Level = 18, Move = "FogoFatuo" },
			{ Level = 22, Move = "BarreiraArcana" },
			{ Level = 26, Move = "GuardaAmpla" },
			{ Level = 30, Move = "Purificacao" },
			{ Level = 34, Move = "DotonMuralhaTerrestre" },
			{ Level = 40, Move = "KatonDragaoDeFogo" },
			{ Level = 45, Move = "SuitonDragaoDeAgua" },
			{ Level = 50, Move = "FutonTempestadeCeleste" },
		},
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			Attack = 133310018588724, Special = 105158348948965,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(255, 210, 75), Secondary = Color3.fromRGB(190, 42, 42) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},

	-- Anime: Bleach
	Chad = {
		Name = "Brado",
		ModelName = "Chad",
		Anime = "Bleach",
		Type = "Lutador",
		Rarity = "Comum",
		Passive = "Firmeza",
		Concept = "Lutador resistente com golpes pesados de bra\u{e7}o blindado",
		BaseLevel = 10,
		BaseStats = { HP = 64, Attack = 16, Defense = 35, Speed = 10 }, -- BST 125 (Muralha Fisica Pura)
		Learnset = {
			{ Level = 1, Move = "SocoDireto" },
			{ Level = 1, Move = "ComboMarcial" },
			{ Level = 5, Move = "PosturaDeCombate" },
			{ Level = 10, Move = "QuebraGuarda" },
			{ Level = 14, Move = "CorpoDeFerro" },
			{ Level = 18, Move = "MuralhaDeFerro" },
			{ Level = 22, Move = "GuardaAmpla" },
			{ Level = 26, Move = "PunhoDemolidor" },
			{ Level = 30, Move = "OndaDeImpacto" },
			{ Level = 34, Move = "Recuperacao" },
			{ Level = 40, Move = "ImpactoTotal" },
		},
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			ComboMarcial = 135688782086034, Attack = 135688782086034, Special = 111193439375608,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(215, 70, 60), Secondary = Color3.fromRGB(245, 210, 120) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
	Uryu = {
		Name = "Uryen",
		ModelName = "Uryu",
		Anime = "Bleach",
		Type = "Atirador",
		Rarity = "Comum",
		Passive = "OlhoDeAguia",
		Concept = "Arqueiro espiritual de flechas luminosas certeiras e r\u{e1}pidas",
		BaseLevel = 10,
		BaseStats = { HP = 44, Attack = 34, Defense = 12, Speed = 35 }, -- BST 125 (Sniper Canhao de Vidro)
		Learnset = {
			{ Level = 1, Move = "DisparoPreciso" },
			{ Level = 1, Move = "TiroPerfurante" },
			{ Level = 5, Move = "MiraFirme" },
			{ Level = 8, Move = "TiroRapido" },
			{ Level = 12, Move = "ChuvaDeProjeteis" },
			{ Level = 16, Move = "FocoDePrecisao" },
			{ Level = 20, Move = "TiroDeSupressao" },
			{ Level = 24, Move = "DisparoRompeEscudo" },
			{ Level = 28, Move = "DardoEletrico" },
			{ Level = 34, Move = "RajadaTatica" },
			{ Level = 40, Move = "DisparoDeElite" },
		},
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			Attack = 105789525703577, Special = 105789525703577,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(130, 225, 255), Secondary = Color3.fromRGB(250, 252, 255) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
	Rukia = {
		Name = "Yukia",
		ModelName = "Rukia",
		Anime = "Bleach",
		Type = "Mago",
		Rarity = "Raro",
		Passive = "EscudoNatural",
		Concept = "Ceifadora especialista em artes glaciais e controle de campo",
		BaseLevel = 10,
		BaseStats = { HP = 56, Attack = 28, Defense = 31, Speed = 23 }, -- BST 138 (Maga de Controle Defensivo)
		Learnset = {
			{ Level = 1, Move = "EsferaArcana" },
			{ Level = 1, Move = "ChamaMistica" },
			{ Level = 5, Move = "SeloParalisante" },
			{ Level = 8, Move = "PulsoVeloz" },
			{ Level = 12, Move = "RaioCongelante" },
			{ Level = 16, Move = "MenteCalma" },
			{ Level = 20, Move = "NevoaDoSono" },
			{ Level = 24, Move = "BarreiraArcana" },
			{ Level = 28, Move = "Purificacao" },
			{ Level = 34, Move = "ExplosaoAstral" },
			{ Level = 40, Move = "MeteoroArcano" },
		},
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			Attack = 133310018588724, Special = 105158348948965,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(175, 238, 255), Secondary = Color3.fromRGB(245, 250, 255) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
	Renji = {
		Name = "Renzo",
		ModelName = "Renji",
		Anime = "Bleach",
		Type = "Espadachim",
		Rarity = "Raro",
		Passive = "Intimidacao",
		Concept = "Tenente impetuoso que domina cortes amplos de longo alcance",
		BaseLevel = 10,
		BaseStats = { HP = 68, Attack = 31, Defense = 23, Speed = 16 }, -- BST 138 (Bruiser de Hazards)
		Learnset = {
			{ Level = 1, Move = "CorteBasico" },
			{ Level = 1, Move = "CorteCruzado" },
			{ Level = 5, Move = "PosturaDaLamina" },
			{ Level = 10, Move = "CorteGiratorio" },
			{ Level = 14, Move = "CorteCerteiro" },
			{ Level = 18, Move = "FioVenenoso" },
			{ Level = 22, Move = "QuebraLamina" },
			{ Level = 26, Move = "LaminaPesada" },
			{ Level = 30, Move = "LaminasNoChao" },
			{ Level = 34, Move = "TempestadeDeCortes" },
			{ Level = 40, Move = "InvestidaCortante" },
		},
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			Attack = 136035334634731, Special = 136035334634731,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(240, 68, 86), Secondary = Color3.fromRGB(255, 212, 92) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
	Ichigo = {
		Name = "Ichiro",
		ModelName = "Ichigo",
		Anime = "Bleach",
		Type = "Espadachim",
		Rarity = "Epico",
		Starter = true,
		Passive = "SedeDeVitoria",
		SecretPassive = "DespertarHollow",
		Concept = "Ceifador substituto veloz com cortes espirituais devastadores",
		BaseLevel = 10,
		BaseStats = { HP = 56, Attack = 39, Defense = 20, Speed = 37 }, -- BST 152 (Hyper-Sweeper Veloz)
		Learnset = {
			{ Level = 1, Move = "CorteBasico" },
			{ Level = 1, Move = "CorteCruzado" },
			{ Level = 5, Move = "PosturaDaLamina" },
			{ Level = 8, Move = "EstocadaVeloz" },
			{ Level = 12, Move = "CorteGiratorio" },
			{ Level = 16, Move = "LaminaAfiada" },
			{ Level = 20, Move = "CorteDrenante" },
			{ Level = 24, Move = "QuebraLamina" },
			{ Level = 28, Move = "LaminaPesada" },
			{ Level = 34, Move = "TempestadeDeCortes" },
			{ Level = 42, Move = "InvestidaCortante" },
		},
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			Attack = 136035334634731, Special = 136035334634731,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(255, 145, 42), Secondary = Color3.fromRGB(70, 218, 255) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
	Byakuya = {
		Name = "Byakuren",
		ModelName = "Byakuya",
		Anime = "Bleach",
		Type = "Espadachim",
		Rarity = "Lendario",
		Passive = "PetalasInfinitas",
		Concept = "Capit\u{e3}o nobre do Reino das Almas mestre em tempestades de p\u{e9}talas",
		BaseLevel = 10,
		BaseStats = { HP = 66, Attack = 38, Defense = 31, Speed = 35 }, -- BST 170 (Duelista Preciso Anti-Tanque)
		Learnset = {
			{ Level = 1, Move = "CorteBasico" },
			{ Level = 1, Move = "CorteCruzado" },
			{ Level = 5, Move = "PosturaDaLamina" },
			{ Level = 8, Move = "EstocadaVeloz" },
			{ Level = 12, Move = "CorteCerteiro" },
			{ Level = 16, Move = "LaminaAfiada" },
			{ Level = 20, Move = "Proteger" },
			{ Level = 24, Move = "QuebraLamina" },
			{ Level = 28, Move = "DancaDasEspadas" },
			{ Level = 32, Move = "LaminasNoChao" },
			{ Level = 36, Move = "TempestadeDeCortes" },
			{ Level = 42, Move = "Senbonzakura" },
			{ Level = 50, Move = "SenbonzakuraKageyoshi" },
		},
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			Attack = 136035334634731, Special = 136035334634731,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(255, 165, 208), Secondary = Color3.fromRGB(242, 246, 255) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},

	-- Anime: Jujutsu Kaisen (Nobara, Itadori, Fushiguro, Todo, Nanami + Gojo/Setero + Sukuna)
	Nobara = {
		Name = "Nobari",
		ModelName = "Nobara",
		Anime = "JujutsuKaisen",
		Type = "Atirador",
		Rarity = "Comum",
		Passive = "GolpeCerteiro",
		Concept = "Feiticeira impetuosa especialista em disparos certeiros de energia maldita",
		BaseLevel = 10,
		BaseStats = { HP = 45, Attack = 36, Defense = 14, Speed = 30 }, -- BST 125 (Canhao de Vidro)
		Learnset = {
			{ Level = 1, Move = "DisparoPreciso" },
			{ Level = 1, Move = "TiroPerfurante" },
			{ Level = 5, Move = "MiraFirme" },
			{ Level = 8, Move = "TiroRapido" },
			{ Level = 12, Move = "ChuvaDeProjeteis" },
			{ Level = 16, Move = "FocoDePrecisao" },
			{ Level = 20, Move = "TiroDeSupressao" },
			{ Level = 24, Move = "DisparoRompeEscudo" },
			{ Level = 28, Move = "DardoEletrico" },
			{ Level = 34, Move = "RajadaTatica" },
			{ Level = 40, Move = "DisparoDeElite" },
		},
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			Attack = 105789525703577, Special = 105789525703577,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(255, 148, 72), Secondary = Color3.fromRGB(195, 88, 255) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
	Itadori = {
		Name = "Itaro",
		ModelName = "Itadori",
		Anime = "JujutsuKaisen",
		Type = "Lutador",
		Rarity = "Comum",
		Passive = "EspiritoGuerreiro",
		Concept = "Lutador veloz e destemido que canaliza energia maldita em combos diretos",
		BaseLevel = 10,
		BaseStats = { HP = 58, Attack = 32, Defense = 13, Speed = 22 }, -- BST 125 (Berserker Explosivo)
		Learnset = {
			{ Level = 1, Move = "SocoDireto" },
			{ Level = 1, Move = "ComboMarcial" },
			{ Level = 5, Move = "PosturaDeCombate" },
			{ Level = 8, Move = "SocoRelampago" },
			{ Level = 12, Move = "QuebraGuarda" },
			{ Level = 16, Move = "Agilidade" },
			{ Level = 20, Move = "PunhoDemolidor" },
			{ Level = 24, Move = "OndaDeImpacto" },
			{ Level = 28, Move = "GritoDeGuerra" },
			{ Level = 34, Move = "PunhoArdente" },
			{ Level = 40, Move = "ImpactoTotal" },
		},
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			ComboMarcial = 135688782086034, Attack = 135688782086034, Special = 111193439375608,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(255, 110, 145), Secondary = Color3.fromRGB(68, 212, 255) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
	Fushiguro = {
		Name = "Fushiro",
		ModelName = "Fushiguro",
		Anime = "JujutsuKaisen",
		Type = "Mago",
		Rarity = "Raro",
		Passive = "MenteTatica",
		Concept = "Feiticeiro t\u{e1}tico das sombras que domina controle de campo e golpes arcanos",
		BaseLevel = 10,
		BaseStats = { HP = 62, Attack = 32, Defense = 30, Speed = 14 }, -- BST 138 (Mago Tanque)
		Learnset = {
			{ Level = 1, Move = "EsferaArcana" },
			{ Level = 1, Move = "ChamaMistica" },
			{ Level = 5, Move = "SeloParalisante" },
			{ Level = 8, Move = "PulsoVeloz" },
			{ Level = 12, Move = "OndaArcana" },
			{ Level = 16, Move = "MenteCalma" },
			{ Level = 20, Move = "Proteger" },
			{ Level = 24, Move = "BarreiraArcana" },
			{ Level = 28, Move = "SifaoArcano" },
			{ Level = 34, Move = "ExplosaoAstral" },
			{ Level = 40, Move = "MeteoroArcano" },
		},
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			Attack = 133310018588724, Special = 105158348948965,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(72, 118, 224), Secondary = Color3.fromRGB(168, 92, 255) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
	Todo = {
		Name = "Todor",
		ModelName = "Todo",
		Anime = "JujutsuKaisen",
		Type = "Lutador",
		Rarity = "Raro",
		Passive = "ContraEspinhos",
		Concept = "Colosso de for\u{e7}a brutal, reflexos geniais e contra-ataques devastadores",
		BaseLevel = 10,
		BaseStats = { HP = 74, Attack = 24, Defense = 29, Speed = 11 }, -- BST 138 (Colosso Counter)
		Learnset = {
			{ Level = 1, Move = "SocoDireto" },
			{ Level = 1, Move = "ComboMarcial" },
			{ Level = 5, Move = "PosturaDeCombate" },
			{ Level = 8, Move = "QuebraGuarda" },
			{ Level = 12, Move = "CorpoDeFerro" },
			{ Level = 16, Move = "GritoDeGuerra" },
			{ Level = 20, Move = "PunhoDemolidor" },
			{ Level = 24, Move = "OndaDeImpacto" },
			{ Level = 28, Move = "GiroVarredor" },
			{ Level = 34, Move = "FocoInterior" },
			{ Level = 40, Move = "ImpactoTotal" },
		},
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			ComboMarcial = 135688782086034, Attack = 135688782086034, Special = 111193439375608,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(255, 192, 72), Secondary = Color3.fromRGB(165, 86, 245) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
	Nanami = {
		Name = "Kentar",
		ModelName = "Nanami",
		Anime = "JujutsuKaisen",
		Type = "Espadachim",
		Rarity = "Epico",
		Passive = "GolpeCerteiro",
		Concept = "Feiticeiro met\u{f3}dico que acerta pontos cr\u{ed}ticos com precis\u{e3}o cir\u{fa}rgica",
		BaseLevel = 10,
		BaseStats = { HP = 68, Attack = 36, Defense = 30, Speed = 18 }, -- BST 152 (Executor 7:3)
		Learnset = {
			{ Level = 1, Move = "CorteBasico" },
			{ Level = 1, Move = "CorteCruzado" },
			{ Level = 5, Move = "PosturaDaLamina" },
			{ Level = 8, Move = "EstocadaVeloz" },
			{ Level = 12, Move = "CorteCerteiro" },
			{ Level = 16, Move = "LaminaAfiada" },
			{ Level = 20, Move = "Proteger" },
			{ Level = 24, Move = "QuebraLamina" },
			{ Level = 28, Move = "LaminaPesada" },
			{ Level = 34, Move = "TempestadeDeCortes" },
			{ Level = 42, Move = "InvestidaCortante" },
		},
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			Attack = 136035334634731, Special = 136035334634731,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(255, 224, 118), Secondary = Color3.fromRGB(62, 165, 215) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},

	-- Anime: Dragon Ball (Piccolo, Kuririn, Vegeta, Gohan, Freeza + San)
	Piccolo = {
		Name = "Pikor",
		ModelName = "Piccolo",
		Anime = "DragonBall",
		Type = "Mago",
		Rarity = "Comum",
		Passive = "Regeneracao",
		Concept = "Guerreiro estrategista de regenera\u{e7}\u{e3}o constante e feixes de energia",
		BaseLevel = 10,
		BaseStats = { HP = 66, Attack = 19, Defense = 29, Speed = 11 }, -- BST 125 (Parede Regenerativa)
		Learnset = {
			{ Level = 1, Move = "EsferaArcana" },
			{ Level = 1, Move = "ChamaMistica" },
			{ Level = 5, Move = "SeloParalisante" },
			{ Level = 8, Move = "PulsoVeloz" },
			{ Level = 12, Move = "OndaArcana" },
			{ Level = 16, Move = "MenteCalma" },
			{ Level = 20, Move = "BarreiraArcana" },
			{ Level = 24, Move = "Recuperacao" },
			{ Level = 28, Move = "SifaoArcano" },
			{ Level = 34, Move = "ExplosaoAstral" },
			{ Level = 40, Move = "MeteoroArcano" },
		},
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			Attack = 133310018588724, Special = 105158348948965,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(255, 198, 52), Secondary = Color3.fromRGB(165, 78, 240) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
	Kuririn = {
		Name = "Kurin",
		ModelName = "Kuririn",
		Anime = "DragonBall",
		Type = "Atirador",
		Rarity = "Comum",
		Passive = "OlhoDeAguia",
		Concept = "Artista marcial \u{e1}gil especializado em discos cortantes de energia",
		BaseLevel = 10,
		BaseStats = { HP = 43, Attack = 30, Defense = 14, Speed = 38 }, -- BST 125 (Batedor Supersonico — VEL 38 supera Gojo!)
		Learnset = {
			{ Level = 1, Move = "DisparoPreciso" },
			{ Level = 1, Move = "TiroPerfurante" },
			{ Level = 5, Move = "MiraFirme" },
			{ Level = 8, Move = "TiroRapido" },
			{ Level = 12, Move = "ChuvaDeProjeteis" },
			{ Level = 16, Move = "FocoDePrecisao" },
			{ Level = 20, Move = "BombaDeFumaca" },
			{ Level = 24, Move = "DisparoRompeEscudo" },
			{ Level = 28, Move = "TiroDeSupressao" },
			{ Level = 34, Move = "RajadaTatica" },
			{ Level = 40, Move = "DisparoDeElite" },
		},
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			Attack = 105789525703577, Special = 105789525703577,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(255, 220, 80), Secondary = Color3.fromRGB(64, 178, 255) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
	Vegeta = {
		Name = "Vegor",
		ModelName = "Vegeta",
		Anime = "DragonBall",
		Type = "Lutador",
		Rarity = "Raro",
		Passive = "SedeDeVitoria",
		Concept = "Pr\u{ed}ncipe guerreiro orgulhoso com ofensiva implac\u{e1}vel e explos\u{f5}es de aura",
		BaseLevel = 10,
		BaseStats = { HP = 52, Attack = 40, Defense = 16, Speed = 30 }, -- BST 138 (Sweeper Saiyajin — ATK 40 empata com Lendarios!)
		Learnset = {
			{ Level = 1, Move = "SocoDireto" },
			{ Level = 1, Move = "ComboMarcial" },
			{ Level = 5, Move = "PosturaDeCombate" },
			{ Level = 8, Move = "SocoRelampago" },
			{ Level = 12, Move = "QuebraGuarda" },
			{ Level = 16, Move = "Agilidade" },
			{ Level = 20, Move = "PunhoDemolidor" },
			{ Level = 24, Move = "OndaDeImpacto" },
			{ Level = 28, Move = "GritoDeGuerra" },
			{ Level = 34, Move = "PunhoArdente" },
			{ Level = 40, Move = "ImpactoTotal" },
		},
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			ComboMarcial = 135688782086034, Attack = 135688782086034, Special = 111193439375608,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(255, 224, 68), Secondary = Color3.fromRGB(58, 162, 255) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
	Gohan = {
		Name = "Gohran",
		ModelName = "Gohan",
		Anime = "DragonBall",
		Type = "Lutador",
		Rarity = "Raro",
		Passive = "ChamaInterior",
		Concept = "Jovem prod\u{ed}gio cujo potencial oculto explode nos momentos cr\u{ed}ticos da luta",
		BaseLevel = 10,
		BaseStats = { HP = 64, Attack = 34, Defense = 22, Speed = 18 }, -- BST 138 (Bruiser de Climax)
		Learnset = {
			{ Level = 1, Move = "SocoDireto" },
			{ Level = 1, Move = "ComboMarcial" },
			{ Level = 5, Move = "PosturaDeCombate" },
			{ Level = 8, Move = "SocoRelampago" },
			{ Level = 12, Move = "QuebraGuarda" },
			{ Level = 16, Move = "CorpoDeFerro" },
			{ Level = 20, Move = "PunhoDemolidor" },
			{ Level = 24, Move = "OndaDeImpacto" },
			{ Level = 28, Move = "FocoInterior" },
			{ Level = 34, Move = "GiroVarredor" },
			{ Level = 40, Move = "ImpactoTotal" },
		},
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			ComboMarcial = 135688782086034, Attack = 135688782086034, Special = 111193439375608,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(255, 226, 92), Secondary = Color3.fromRGB(168, 92, 255) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
	Freeza = {
		Name = "Frizor",
		ModelName = "Freeza",
		Anime = "DragonBall",
		Type = "Mago",
		Rarity = "Epico",
		Passive = "Intimidacao",
		Concept = "Imperador gal\u{e1}ctico implac\u{e1}vel de raios letais e esferas de energia destrutiva",
		BaseLevel = 10,
		BaseStats = { HP = 58, Attack = 40, Defense = 20, Speed = 34 }, -- BST 152 (Tirano Sweeper)
		Learnset = {
			{ Level = 1, Move = "EsferaArcana" },
			{ Level = 1, Move = "ChamaMistica" },
			{ Level = 5, Move = "OlharIntimidador" },
			{ Level = 8, Move = "PulsoVeloz" },
			{ Level = 12, Move = "OndaArcana" },
			{ Level = 16, Move = "MenteCalma" },
			{ Level = 20, Move = "Proteger" },
			{ Level = 24, Move = "BarreiraArcana" },
			{ Level = 28, Move = "SifaoArcano" },
			{ Level = 34, Move = "ExplosaoAstral" },
			{ Level = 42, Move = "MeteoroArcano" },
		},
		Animations = {
			Idle = 95978454415689, Walk = 81539047602340, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			Attack = 133310018588724, Special = 105158348948965,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(255, 212, 68), Secondary = Color3.fromRGB(168, 62, 232) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
}

--[[
	PROTOTIPOS DE TESTE (17/11/2026): um por raridade, so para testar a barra e a tela de Equipe.
	Prototype = true: nunca saem na invocacao, no Refugio, na torre nem no album; entram so pela ponte de teste.
]]
Characters.List.ProtoRaro = {
	Name = "ProtoAtirador", ModelName = "ProtoRaro", Anime = "Generico", Type = "Atirador", Rarity = "Raro", Prototype = true,
	Passive = "OlhoDeAguia",
	Concept = "Modelo provis\u{f3}rio de teste", BaseLevel = 10,
	BaseStats = { HP = 64, Attack = 22, Defense = 21, Speed = 21 },
}
Characters.List.ProtoEpico = {
	Name = "Yoru", ModelName = "ProtoEpico", Anime = "Generico", Type = "Mago", Rarity = "Epico", Prototype = true,
	Passive = "EscudoNatural",
	Concept = "Modelo provis\u{f3}rio de teste", BaseLevel = 10,
	BaseStats = { HP = 64, Attack = 23, Defense = 20, Speed = 21 },
}

for id, def in pairs(Characters.List) do
	def.Id = id
	def.Anime = def.Anime or "Generico"
	-- Herda automaticamente o kit generico de golpes da classe quando o personagem nao define Learnset proprio
	if not def.Learnset then
		local sigLevel = if def.Rarity == "Lendario" or def.Rarity == "Secreto" then 50 else 45
		def.Learnset = Moves.ClassKit(def.Type, def.SignatureMove, sigLevel)
	end
	table.sort(def.Learnset, function(a, b)
		if a.Level ~= b.Level then
			return a.Level < b.Level
		end
		return a.Move < b.Move
	end)
	if not def.Moves then
		local list = {}
		for _, entry in ipairs(def.Learnset) do
			if not table.find(list, entry.Move) then
				table.insert(list, entry.Move)
			end
		end
		def.Moves = list
	end
end

function Characters.Get(id: string)
	return Characters.List[id]
end

--[[
	Aprendizado de golpes por nivel (Nv. 1 -> 50):
	  Learnset = { { Level = n, Move = id }, ... }. Nivel 1 = golpes iniciais.
	  Lendarios desbloqueiam seus ataques especiais/assinaturas nos ultimos niveis (Nv. 42-44 e Nv. 50).
]]
function Characters.LearnedAt(id: string, level: number): { string }
	local def = assert(Characters.List[id], "Personagem desconhecido: " .. tostring(id))
	if not def.Learnset then
		return table.clone(def.Moves)
	end
	local list = {}
	for _, entry in ipairs(def.Learnset) do
		if entry.Level <= level and not table.find(list, entry.Move) then
			table.insert(list, entry.Move)
		end
	end
	return list
end

-- Nivel em que o personagem aprende um golpe especifico (nil se nao esta no Learnset)
function Characters.LearnLevelOf(id: string, moveId: string): number?
	local def = Characters.List[id]
	for _, entry in ipairs(def and def.Learnset or {}) do
		if entry.Move == moveId then
			return entry.Level
		end
	end
	return nil
end

-- Proximos golpes ainda bloqueados acima do nivel atual (em ordem crescente de nivel)
function Characters.UpcomingMoves(id: string, level: number): { { Level: number, Move: string } }
	local def = Characters.List[id]
	local out = {}
	local seen = {}
	for _, entry in ipairs(def and def.Learnset or {}) do
		if entry.Level > level and not seen[entry.Move] then
			seen[entry.Move] = true
			table.insert(out, { Level = entry.Level, Move = entry.Move })
		end
	end
	return out
end

-- Golpes aprendidos exatamente ao chegar num nivel
function Characters.NewMovesAt(id: string, level: number): { string }
	local def = Characters.List[id]
	local list = {}
	for _, entry in ipairs(def and def.Learnset or {}) do
		if entry.Level == level and level > 1 then
			table.insert(list, entry.Move)
		end
	end
	return list
end

-- 4 golpes ativos padrao: os 4 ultimos aprendidos ate o nivel (garante ao menos 1 golpe de dano)
function Characters.DefaultActive(id: string, level: number): { string }
	local def = Characters.List[id]
	local learned = Characters.LearnedAt(id, level)
	if def and def.DefaultOrder then
		local allLearned = true
		for _, mid in ipairs(def.DefaultOrder) do
			if not table.find(learned, mid) then
				allLearned = false
				break
			end
		end
		if allLearned then
			return table.clone(def.DefaultOrder)
		end
	end
	local active = {}
	for i = math.max(1, #learned - 3), #learned do
		table.insert(active, learned[i])
	end
	local hasDamage = false
	for _, mid in ipairs(active) do
		local mv = Moves.Get(mid)
		if mv and mv.Category == "Damage" then
			hasDamage = true
			break
		end
	end
	if not hasDamage and #active > 0 then
		local bestDmg, bestPow = nil, -1
		for _, mid in ipairs(learned) do
			local mv = Moves.Get(mid)
			if mv and mv.Category == "Damage" and (mv.Power or 0) > bestPow then
				bestDmg, bestPow = mid, mv.Power or 0
			end
		end
		if bestDmg then
			active[1] = bestDmg
		end
	end
	return active
end

-- Personagens iniciais: Luffy (One Piece), Naruto (Naruto) e Ichigo (Bleach)
function Characters.Starters(): { string }
	local list = {}
	for id, def in pairs(Characters.List) do
		if def.Starter then
			table.insert(list, id)
		end
	end
	local order = { Luffy = 1, Naruto = 2, Ichigo = 3 }
	table.sort(list, function(a, b)
		return (order[a] or 9) < (order[b] or 9)
	end)
	return list
end

-- Soma dos 4 atributos (BST) de uma tabela de stats
function Characters.BstOf(stats): number
	if typeof(stats) ~= "table" then
		return 0
	end
	return (stats.HP or 0) + (stats.Attack or 0) + (stats.Defense or 0) + (stats.Speed or 0)
end

-- Multiplicador de Colecao/Geracao no PvE e Casual (+5% por colecao/Ginasio; sempre 1.00x na Ranqueada)
function Characters.CollectionScaleOf(id: string): number
	local def = Characters.List[id]
	if not def then
		return 1.0
	end
	local animeId = def.Anime or "Generico"
	local info = Characters.Animes[animeId]
	if info and typeof(info.CollectionScale) == "number" then
		return info.CollectionScale
	end
	return Characters.CollectionScales[animeId] or 1.0
end

-- Atributos de um personagem num nivel com crescimento proporcional (estilo Pokemon).
-- opts = { Ranked = true } normaliza a colecao para 1.00x e alinha Secreto ao BST de Lendario (170).
function Characters.StatsAt(id: string, level: number, opts: { Ranked: boolean? }?)
	local def = assert(Characters.List[id], "Personagem desconhecido: " .. tostring(id))
	level = math.clamp(math.floor(level), 1, Characters.MaxLevel)
	local levelFactor = Characters.GrowthBase + Characters.GrowthPerLevel * level
	local isRanked = typeof(opts) == "table" and opts.Ranked == true
	local scale = 1.0
	if isRanked then
		local targetBst = not def.Prototype and Characters.RankedBst[def.Rarity]
		if targetBst then
			local baseBst = Characters.BstOf(def.BaseStats)
			if baseBst > 0 then
				scale = targetBst / baseBst
			end
		end
	else
		scale = Characters.CollectionScaleOf(id)
	end
	local stats = {}
	for stat, base in pairs(def.BaseStats) do
		local grown = base * levelFactor * scale
		stats[stat] = math.max(1, math.floor(grown + 0.5))
	end
	return stats
end

-- Retorna o id da tag de anime do personagem ("DragonBall", "OnePiece", "JujutsuKaisen", "Generico")
function Characters.AnimeOf(id: string): string
	local def = Characters.List[id]
	return (def and def.Anime) or "Generico"
end

function Characters.AnimeInfo(animeId: string)
	return Characters.Animes[animeId]
end

function Characters.AnimeDisplay(animeId: string): string
	local info = Characters.Animes[animeId]
	return (info and info.Name) or tostring(animeId)
end

-- Indica se o personagem usa a tag provisoria "Generico"
function Characters.IsGeneric(id: string): boolean
	local animeId = Characters.AnimeOf(id)
	local info = Characters.Animes[animeId]
	return animeId == "Generico" or (info ~= nil and info.Generic == true)
end

-- Lista ordenada de ids de personagens de um anime (exclui Prototype por padrao)
function Characters.ByAnime(animeId: string, includePrototype: boolean?): { string }
	local out = {}
	for id, def in pairs(Characters.List) do
		if (includePrototype or not def.Prototype) and (def.Anime or "Generico") == animeId then
			table.insert(out, id)
		end
	end
	table.sort(out)
	return out
end

-- Passiva ativa do personagem (troca para SecretPassive se estiver Desperto)
function Characters.PassiveIdOf(id: string, awakened: boolean?): string?
	local def = Characters.List[id]
	if not def then
		return nil
	end
	if awakened and def.SecretPassive then
		return def.SecretPassive
	end
	return def.Passive
end

function Characters.PassiveOf(id: string, awakened: boolean?)
	local pid = Characters.PassiveIdOf(id, awakened)
	return if pid then Passives.Get(pid) else nil
end

function Characters.SecretPassiveOf(id: string)
	local def = Characters.List[id]
	return if def and def.SecretPassive then Passives.Get(def.SecretPassive) else nil
end

function Characters.HasAwakening(id: string): boolean
	local def = Characters.List[id]
	return def ~= nil and def.SecretPassive ~= nil
end

return Characters
