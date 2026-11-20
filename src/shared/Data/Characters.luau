--[[
	Characters (GDD secao 4)
	Personagens sao so dados. ModelName e o nome do modelo em ServerStorage/Characters
	(e a unica ligacao com o modelo 3D; trocar o modelo nao exige mexer em codigo).

	BaseStats sao os atributos no BaseLevel, exatamente como na tabela do GDD.
	Por nivel: +3 HP e +1 em Ataque, Defesa e Velocidade (Growth),
	multiplicado pelo multiplicador da raridade.
]]

local Characters = {}

Characters.MaxLevel = 50

-- Animacoes padrao compartilhadas (respiracao/vida no Idle e caminhada limpa no Walk)
Characters.DefaultAnimations = {
	Idle = 82392963584557,
	Walk = 113228340758956,
}

Characters.Growth = { HP = 3, Attack = 1, Defense = 1, Speed = 1 }

-- Categorizacao por anime (tag de codigo usada em Mochila, Equipe, Torre, etc.; nao exibida em cartas)
Characters.AnimeOrder = { "OnePiece", "Naruto", "DragonBall", "JujutsuKaisen", "Generico" }
Characters.Animes = {
	Naruto = { Id = "Naruto", Name = "Naruto", Short = "NARUTO" },
	DragonBall = { Id = "DragonBall", Name = "Dragon Ball", Short = "DRAGON BALL" },
	OnePiece = { Id = "OnePiece", Name = "One Piece", Short = "ONE PIECE" },
	JujutsuKaisen = { Id = "JujutsuKaisen", Name = "Jujutsu Kaisen", Short = "JUJUTSU" },
	Generico = { Id = "Generico", Name = "Gen\u{e9}rico", Short = "GEN\u{c9}RICO", Generic = true },
}

-- Tabela de raridade do GDD (secao 4)
Characters.Rarities = {
	Comum = { Name = "Comum", StatMultiplier = 1.00, EncounterChance = 0.60, OrePerHour = 10, CaptureRate = 0.60 },
	Raro = { Name = "Raro", StatMultiplier = 1.10, EncounterChance = 0.28, OrePerHour = 18, CaptureRate = 0.40 },
	Epico = { Name = "Épico", StatMultiplier = 1.20, EncounterChance = 0.10, OrePerHour = 30, CaptureRate = 0.20 },
	Lendario = { Name = "Lendário", StatMultiplier = 1.35, EncounterChance = 0.02, OrePerHour = 50, CaptureRate = 0.08 },
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
		Type = "Fogo",
		Rarity = "Comum",
		Concept = "Espadachim jovem e impulsivo",
		BaseLevel = 10,
		BaseStats = { HP = 62, Attack = 24, Defense = 18, Speed = 22 },
		Moves = { "CorteFlamejante", "Investida", "BrasaViva", "PosturaDeCombate" },
		Starter = true,
		Learnset = { { Level = 1, Move = "Investida" }, { Level = 1, Move = "BrasaViva" }, { Level = 5, Move = "PosturaDeCombate" }, { Level = 10, Move = "CorteFlamejante" } },
	},
	Raiko = {
		Name = "Raiko",
		ModelName = "Raiko",
		Anime = "Generico",
		Type = "Raio",
		Rarity = "Comum",
		Concept = "Lutador de rua calmo e rápido",
		BaseLevel = 10,
		BaseStats = { HP = 66, Attack = 22, Defense = 20, Speed = 20 },
		Moves = { "Descarga", "SocoDireto", "PunhoDeMare", "Estatica" },
		Learnset = { { Level = 1, Move = "SocoDireto" }, { Level = 1, Move = "PunhoDeMare" }, { Level = 5, Move = "Estatica" }, { Level = 10, Move = "Descarga" } },
	},
	Yomogi = {
		Name = "Yomogi",
		ModelName = "Yomogi",
		Anime = "Generico",
		Type = "Natureza",
		Rarity = "Comum",
		Concept = "Meio-fera da floresta, instintivo e protetor",
		BaseLevel = 10,
		BaseStats = { HP = 64, Attack = 21, Defense = 23, Speed = 19 },
		Moves = { "GaiolaDeEspinhos", "Arranhao", "SementeToxica", "CascaDeCarvalho" },
		Starter = true,
		Learnset = { { Level = 1, Move = "Arranhao" }, { Level = 1, Move = "SementeToxica" }, { Level = 5, Move = "CascaDeCarvalho" }, { Level = 10, Move = "GaiolaDeEspinhos" } },
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
		Type = "Luz",
		Rarity = "Lendario",
		Concept = "Feiticeiro lendário de luz, gravidade e vazio",
		BaseLevel = 10,
		BaseStats = { HP = 66, Attack = 24, Defense = 21, Speed = 23 },
		Moves = { "TudoRoxo", "Atracao", "SocoDireto", "PosturaDeCombate" },
		Learnset = {
			{ Level = 1, Move = "Atracao" },
			{ Level = 1, Move = "SocoDireto" },
			{ Level = 1, Move = "TudoRoxo" },
			{ Level = 5, Move = "PosturaDeCombate" },
		},
		-- Animacoes publicadas (copias em ServerStorage/Characters/Setero/Animations)
		Animations = {
			Idle = 134346784779778, Walk = 100508212147856, Hit = 137080344357585, Faint = 83134062837771,
			Victory = 82876850577652, Mine = 88262424470805,
			Atracao = 133310018588724, TudoRoxo = 131932987016123, Attack = 133558294831680,
		},
		Variants = Variants,
		-- Paleta da variante Brilhante: branco platina com azul glacial e energia celeste
		ShinyPalette = { Primary = Color3.fromRGB(230, 238, 252), Secondary = Color3.fromRGB(70, 180, 255) },
		KeepTextureParts = { "Head", "Blindfold_Acc", "LeftHand", "RightHand" },
	},
	San = {
		Name = "San",
		ModelName = "San",
		Anime = "DragonBall",
		Type = "Luz",
		Rarity = "Lendario",
		Concept = "Artista marcial lendário que canaliza o Ki e a energia vital celeste",
		BaseLevel = 10,
		BaseStats = { HP = 68, Attack = 25, Defense = 20, Speed = 22 },
		Moves = { "Kamehameha", "GenkiDama", "ComboMarcial", "CargaDeKi" },
		Learnset = {
			{ Level = 1, Move = "Kamehameha" },
			{ Level = 1, Move = "GenkiDama" },
			{ Level = 1, Move = "ComboMarcial" },
			{ Level = 5, Move = "CargaDeKi" },
		},
		-- Animacoes publicadas (copias em ServerStorage/Characters/San/Animations)
		Animations = {
			Idle = 82392963584557, Walk = 113228340758956, Hit = 103416185331712, Faint = 79648116867663,
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
		Name = "Barba Branca",
		ModelName = "BarbaBranca",
		Anime = "OnePiece",
		Type = "Agua",
		Rarity = "Lendario",
		Concept = "Colosso lendário dos mares capaz de rachar o próprio ar e erguer maremotos",
		BaseLevel = 10,
		BaseStats = { HP = 76, Attack = 27, Defense = 22, Speed = 15 },
		Moves = { "SocoSismico", "CeuETerra", "CorteMurakumo", "HakiDoConquistador" },
		Learnset = {
			{ Level = 1, Move = "SocoSismico" },
			{ Level = 1, Move = "CeuETerra" },
			{ Level = 1, Move = "CorteMurakumo" },
			{ Level = 5, Move = "HakiDoConquistador" },
		},
		-- Animacoes padrao compartilhadas + 4 golpes exclusivos publicados
		Animations = {
			Idle = 82392963584557, Walk = 113228340758956, Hit = 103416185331712, Faint = 79648116867663,
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
		Name = "Luffy",
		ModelName = "Luffy",
		Anime = "OnePiece",
		Type = "Fogo",
		Rarity = "Epico",
		Concept = "Capitão pirata de borracha com chapéu de palha (em desenvolvimento)",
		BaseLevel = 10,
		BaseStats = { HP = 68, Attack = 25, Defense = 20, Speed = 23 },
		Moves = { "ComboMarcial", "SocoDireto", "Investida", "PosturaDeCombate" },
		Learnset = {
			{ Level = 1, Move = "ComboMarcial" },
			{ Level = 1, Move = "SocoDireto" },
			{ Level = 1, Move = "Investida" },
			{ Level = 5, Move = "PosturaDeCombate" },
		},
		Animations = {
			Idle = 82392963584557, Walk = 113228340758956, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			ComboMarcial = 135688782086034, SocoDireto = 135688782086034,
			Investida = 135688782086034, PosturaDeCombate = 94954698224565,
			Attack = 135688782086034, Special = 111193439375608,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(255, 240, 250), Secondary = Color3.fromRGB(255, 195, 70) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
	Nami = {
		Name = "Nami",
		ModelName = "Nami",
		Anime = "OnePiece",
		Type = "Raio",
		Rarity = "Comum",
		Concept = "Navegadora astuta especialista em tempestades e raios (em desenvolvimento)",
		BaseLevel = 10,
		BaseStats = { HP = 60, Attack = 23, Defense = 18, Speed = 25 },
		Moves = { "Descarga", "Estatica", "SocoDireto", "PosturaDeCombate" },
		Learnset = {
			{ Level = 1, Move = "Descarga" },
			{ Level = 1, Move = "SocoDireto" },
			{ Level = 1, Move = "Estatica" },
			{ Level = 5, Move = "PosturaDeCombate" },
		},
		Animations = {
			Idle = 82392963584557, Walk = 113228340758956, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			Attack = 135688782086034, Special = 105158348948965,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(255, 215, 95), Secondary = Color3.fromRGB(80, 200, 255) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
	Usopp = {
		Name = "Usopp",
		ModelName = "Usopp",
		Anime = "OnePiece",
		Type = "Natureza",
		Rarity = "Comum",
		Concept = "Atirador engenhoso de sementes explosivas e armadilhas (em desenvolvimento)",
		BaseLevel = 10,
		BaseStats = { HP = 62, Attack = 22, Defense = 19, Speed = 24 },
		Moves = { "SementeToxica", "Arranhao", "Investida", "CascaDeCarvalho" },
		Learnset = {
			{ Level = 1, Move = "SementeToxica" },
			{ Level = 1, Move = "Investida" },
			{ Level = 1, Move = "Arranhao" },
			{ Level = 5, Move = "CascaDeCarvalho" },
		},
		Animations = {
			Idle = 82392963584557, Walk = 113228340758956, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			Attack = 135688782086034, Special = 105158348948965,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(245, 210, 80), Secondary = Color3.fromRGB(95, 220, 120) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
	Zoro = {
		Name = "Zoro",
		ModelName = "Zoro",
		Anime = "OnePiece",
		Type = "Trevas",
		Rarity = "Raro",
		Concept = "Espadachim implacável do estilo três espadas (em desenvolvimento)",
		BaseLevel = 10,
		BaseStats = { HP = 66, Attack = 26, Defense = 21, Speed = 20 },
		Moves = { "CorteMurakumo", "ComboMarcial", "SocoDireto", "PosturaDeCombate" },
		Learnset = {
			{ Level = 1, Move = "CorteMurakumo" },
			{ Level = 1, Move = "ComboMarcial" },
			{ Level = 1, Move = "SocoDireto" },
			{ Level = 5, Move = "PosturaDeCombate" },
		},
		Animations = {
			Idle = 82392963584557, Walk = 113228340758956, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			CorteMurakumo = 136035334634731, ComboMarcial = 135688782086034,
			Attack = 136035334634731, Special = 136035334634731,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(70, 230, 145), Secondary = Color3.fromRGB(165, 95, 255) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},
	Sanji = {
		Name = "Sanji",
		ModelName = "Sanji",
		Anime = "OnePiece",
		Type = "Fogo",
		Rarity = "Raro",
		Concept = "Cozinheiro combatente especialista em chutes flamejantes velozes (em desenvolvimento)",
		BaseLevel = 10,
		BaseStats = { HP = 65, Attack = 25, Defense = 19, Speed = 24 },
		Moves = { "CorteFlamejante", "BrasaViva", "ComboMarcial", "PosturaDeCombate" },
		Learnset = {
			{ Level = 1, Move = "CorteFlamejante" },
			{ Level = 1, Move = "BrasaViva" },
			{ Level = 1, Move = "ComboMarcial" },
			{ Level = 5, Move = "PosturaDeCombate" },
		},
		Animations = {
			Idle = 82392963584557, Walk = 113228340758956, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			ComboMarcial = 135688782086034,
			Attack = 135688782086034, Special = 135688782086034,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(255, 220, 90), Secondary = Color3.fromRGB(75, 185, 255) },
		KeepTextureParts = { "Head", "Head_Mesh" },
	},

	-- Anime: Naruto (sem modelo 3D proprio ainda; usa rigor provisorio colorido e ataques padrao ate os modelos entrarem)
	Sakura = {
		Name = "Sakura",
		ModelName = "Sakura",
		Anime = "Naruto",
		Type = "Natureza",
		Rarity = "Comum",
		Concept = "Kunoichi ágil de golpes físicos diretos e boa resistência (modelo provisório)",
		BaseLevel = 10,
		BaseStats = { HP = 64, Attack = 23, Defense = 20, Speed = 21 },
		Moves = { "SocoDireto", "Investida", "Arranhao", "CascaDeCarvalho" },
		Learnset = {
			{ Level = 1, Move = "SocoDireto" },
			{ Level = 1, Move = "Investida" },
			{ Level = 5, Move = "Arranhao" },
			{ Level = 10, Move = "CascaDeCarvalho" },
		},
		Animations = {
			Idle = 82392963584557, Walk = 113228340758956, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			Attack = 135688782086034, Special = 105158348948965,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(255, 175, 210), Secondary = Color3.fromRGB(115, 235, 155) },
		KeepTextureParts = { "Head", "LeftHand", "RightHand" },
		PlaceholderColors = {
			Torso = Color3.fromRGB(224, 62, 112),
			Accent = Color3.fromRGB(245, 165, 195),
			Legs = Color3.fromRGB(48, 36, 56),
		},
	},
	Shikamaru = {
		Name = "Shikamaru",
		ModelName = "Shikamaru",
		Anime = "Naruto",
		Type = "Trevas",
		Rarity = "Comum",
		Concept = "Estrategista tático veloz de combate versátil (modelo provisório)",
		BaseLevel = 10,
		BaseStats = { HP = 61, Attack = 21, Defense = 21, Speed = 24 },
		Moves = { "Investida", "SocoDireto", "SementeToxica", "PosturaDeCombate" },
		Learnset = {
			{ Level = 1, Move = "Investida" },
			{ Level = 1, Move = "SocoDireto" },
			{ Level = 5, Move = "PosturaDeCombate" },
			{ Level = 10, Move = "SementeToxica" },
		},
		Animations = {
			Idle = 82392963584557, Walk = 113228340758956, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			Attack = 135688782086034, Special = 105158348948965,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(110, 88, 168), Secondary = Color3.fromRGB(145, 220, 120) },
		KeepTextureParts = { "Head", "LeftHand", "RightHand" },
		PlaceholderColors = {
			Torso = Color3.fromRGB(58, 72, 54),
			Accent = Color3.fromRGB(42, 46, 52),
			Legs = Color3.fromRGB(34, 38, 46),
		},
	},
	Kakashi = {
		Name = "Kakashi",
		ModelName = "Kakashi",
		Anime = "Naruto",
		Type = "Raio",
		Rarity = "Raro",
		Concept = "Jounin veterano de reflexos rápidos e golpes elétricos (modelo provisório)",
		BaseLevel = 10,
		BaseStats = { HP = 65, Attack = 25, Defense = 20, Speed = 25 },
		Moves = { "Descarga", "Estatica", "SocoDireto", "PosturaDeCombate" },
		Learnset = {
			{ Level = 1, Move = "Descarga" },
			{ Level = 1, Move = "SocoDireto" },
			{ Level = 1, Move = "Estatica" },
			{ Level = 5, Move = "PosturaDeCombate" },
		},
		Animations = {
			Idle = 82392963584557, Walk = 113228340758956, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			Attack = 135688782086034, Special = 105158348948965,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(220, 232, 248), Secondary = Color3.fromRGB(70, 200, 255) },
		KeepTextureParts = { "Head", "LeftHand", "RightHand" },
		PlaceholderColors = {
			Torso = Color3.fromRGB(44, 68, 56),
			Accent = Color3.fromRGB(185, 198, 214),
			Legs = Color3.fromRGB(32, 42, 68),
		},
	},
	Sasuke = {
		Name = "Sasuke",
		ModelName = "Sasuke",
		Anime = "Naruto",
		Type = "Fogo",
		Rarity = "Raro",
		Concept = "Lutador disciplinado especialista em ataques precisos e chamas (modelo provisório)",
		BaseLevel = 10,
		BaseStats = { HP = 64, Attack = 26, Defense = 19, Speed = 24 },
		Moves = { "CorteFlamejante", "BrasaViva", "Investida", "PosturaDeCombate" },
		Learnset = {
			{ Level = 1, Move = "CorteFlamejante" },
			{ Level = 1, Move = "Investida" },
			{ Level = 1, Move = "BrasaViva" },
			{ Level = 5, Move = "PosturaDeCombate" },
		},
		Animations = {
			Idle = 82392963584557, Walk = 113228340758956, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			Attack = 135688782086034, Special = 105158348948965,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(80, 74, 148), Secondary = Color3.fromRGB(240, 120, 255) },
		KeepTextureParts = { "Head", "LeftHand", "RightHand" },
		PlaceholderColors = {
			Torso = Color3.fromRGB(44, 54, 118),
			Accent = Color3.fromRGB(145, 130, 185),
			Legs = Color3.fromRGB(28, 30, 52),
		},
	},
	Naruto = {
		Name = "Naruto",
		ModelName = "Naruto",
		Anime = "Naruto",
		Type = "Luz",
		Rarity = "Epico",
		Concept = "Shinobi determinado com vigor elevado e ataques diretos intensos (modelo provisório)",
		BaseLevel = 10,
		BaseStats = { HP = 70, Attack = 25, Defense = 21, Speed = 24 },
		Moves = { "SocoDireto", "Investida", "Arranhao", "PosturaDeCombate" },
		Learnset = {
			{ Level = 1, Move = "SocoDireto" },
			{ Level = 1, Move = "Investida" },
			{ Level = 1, Move = "Arranhao" },
			{ Level = 5, Move = "PosturaDeCombate" },
		},
		Animations = {
			Idle = 82392963584557, Walk = 113228340758956, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			Attack = 135688782086034, Special = 105158348948965,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(255, 224, 90), Secondary = Color3.fromRGB(255, 135, 35) },
		KeepTextureParts = { "Head", "LeftHand", "RightHand" },
		PlaceholderColors = {
			Torso = Color3.fromRGB(245, 122, 32),
			Accent = Color3.fromRGB(36, 42, 58),
			Legs = Color3.fromRGB(228, 108, 28),
		},
	},
	Sarutobi = {
		Name = "Sarutobi",
		ModelName = "Sarutobi",
		Anime = "Naruto",
		Type = "Fogo",
		Rarity = "Lendario",
		Concept = "Mestre lendário equilibrado especialista em chamas e combate direto (modelo provisório)",
		BaseLevel = 10,
		BaseStats = { HP = 72, Attack = 26, Defense = 24, Speed = 21 },
		Moves = { "CorteFlamejante", "BrasaViva", "SocoDireto", "PosturaDeCombate" },
		Learnset = {
			{ Level = 1, Move = "CorteFlamejante" },
			{ Level = 1, Move = "BrasaViva" },
			{ Level = 1, Move = "SocoDireto" },
			{ Level = 5, Move = "PosturaDeCombate" },
		},
		Animations = {
			Idle = 82392963584557, Walk = 113228340758956, Hit = 103416185331712, Faint = 79648116867663,
			Victory = 107803042519026, Mine = 88262424470805,
			Attack = 135688782086034, Special = 105158348948965,
		},
		Variants = Variants,
		ShinyPalette = { Primary = Color3.fromRGB(255, 210, 75), Secondary = Color3.fromRGB(190, 42, 42) },
		KeepTextureParts = { "Head", "LeftHand", "RightHand" },
		PlaceholderColors = {
			Torso = Color3.fromRGB(168, 34, 40),
			Accent = Color3.fromRGB(242, 200, 74),
			Legs = Color3.fromRGB(48, 38, 42),
		},
	},
}

--[[
	PROTOTIPOS DE TESTE (17/11/2026): um por raridade, so para testar a barra e a tela de Equipe.
	Prototype = true: nunca saem na invocacao, no Refugio, na torre nem no album; entram so pela ponte de teste.
	Remover quando o usuario pedir (dados aqui + modelos em ServerStorage/Characters/Proto*).
]]
Characters.List.ProtoRaro = {
	Name = "Nami", ModelName = "ProtoRaro", Anime = "Generico", Type = "Agua", Rarity = "Raro", Prototype = true,
	Concept = "Modelo provis\u{f3}rio de teste", BaseLevel = 10,
	BaseStats = { HP = 64, Attack = 22, Defense = 21, Speed = 21 },
	Moves = { "PunhoDeMare", "SocoDireto", "Investida", "PosturaDeCombate" },
}
Characters.List.ProtoEpico = {
	Name = "Yoru", ModelName = "ProtoEpico", Anime = "Generico", Type = "Trevas", Rarity = "Epico", Prototype = true,
	Concept = "Modelo provis\u{f3}rio de teste", BaseLevel = 10,
	BaseStats = { HP = 64, Attack = 23, Defense = 20, Speed = 21 },
	Moves = { "Arranhao", "SementeToxica", "Investida", "PosturaDeCombate" },
}

for id, def in pairs(Characters.List) do
	def.Id = id
	def.Anime = def.Anime or "Generico"
end

function Characters.Get(id: string)
	return Characters.List[id]
end

--[[
	Aprendizado de golpes (GDD secao 7): golpes novos nos niveis 5, 10, 18, 26, 35 e 45.
	Learnset = { { Level = n, Move = id }, ... }. Nivel 1 = golpes iniciais.
	Sem Learnset, o personagem conhece a lista Moves inteira.
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

-- 4 golpes ativos padrao: os 4 ultimos aprendidos ate o nivel
function Characters.DefaultActive(id: string, level: number): { string }
	local learned = Characters.LearnedAt(id, level)
	local active = {}
	for i = math.max(1, #learned - 3), #learned do
		table.insert(active, learned[i])
	end
	return active
end

-- Personagens iniciais (GDD secao 7: 1 entre 3 comuns de Fogo, Agua e Natureza)
function Characters.Starters(): { string }
	local list = {}
	for id, def in pairs(Characters.List) do
		if def.Starter then
			table.insert(list, id)
		end
	end
	local order = { Fogo = 1, Agua = 2, Natureza = 3 }
	table.sort(list, function(a, b)
		return (order[Characters.List[a].Type] or 9) < (order[Characters.List[b].Type] or 9)
	end)
	return list
end

-- Atributos de um personagem num nivel. No BaseLevel devolve exatamente BaseStats.
function Characters.StatsAt(id: string, level: number)
	local def = assert(Characters.List[id], "Personagem desconhecido: " .. tostring(id))
	level = math.clamp(math.floor(level), 1, Characters.MaxLevel)
	local rarity = Characters.Rarities[def.Rarity] or Characters.Rarities.Comum
	local diff = level - def.BaseLevel
	local stats = {}
	for stat, base in pairs(def.BaseStats) do
		local grown = base + Characters.Growth[stat] * diff * rarity.StatMultiplier
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

return Characters
