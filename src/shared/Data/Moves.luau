--[[
	Moves (Sistema de Golpes por Classe + Tecnicas Assinatura)
	Cada golpe e so dado. O BattleEngine/BattleService le estes campos; para criar um golpe novo
	basta adicionar uma entrada aqui, sem mexer no codigo de batalha.

	Golpes Genericos por Classe (`Moves.ClassDefaults`):
	  Todo personagem novo de uma classe (Espadachim, Lutador, Mago, Atirador) herda automaticamente
	  o kit basico da classe com animacoes compativeis (espada, punho, magia, disparo), bastando
	  adicionar suas tecnicas assinatura exclusivas quando desejar.

	Campos:
	  Name          nome mostrado
	  Type          id da classe ("Espadachim" | "Lutador" | "Mago" | "Atirador" | "Universal")
	  Category      "Damage" (causa dano) ou "Status" (so efeito)
	  Power         poder (so Damage)
	  Accuracy      precisao 0-100; nil = nunca erra
	  PP            usos maximos
	  Priority      (opcional) prioridade na fila do turno (+4 Protect, +3 WideProtect, +1 rapido, 0 padrao)
	  CritChance    (opcional) chance de critico propria (padrao 0.0625 em DamageCalc)
	  Drain         (opcional) fracao do dano causado drenado como HP (ex.: 0.5 = 50%)
	  Recoil        (opcional) fracao do dano causado sofrido como recuo (ex.: 0.25 = 25%)
	  BreaksProtect (opcional) true para romper Protect/WideProtect do alvo
	  LearnLevel    (opcional) nivel sugerido de aprendizado para progressao por nivel
	  Effect        efeito opcional:
	                  { Kind = "Status", Status = "Burn" | "Poison" | "Paralysis" | "Sleep" | "Freeze", Chance = 0-100, Target = "Target" | "Self" }
	                  { Kind = "StatStage", Stat = "Attack" | "Defense" | "Speed" | "Accuracy", Stages = n, Target = ... }
	                  { Kind = "MultiStat", Changes = { { Stat = ..., Stages = n }, ... }, Target = "Self" | "Target" }
	                  { Kind = "Protect" } | { Kind = "WideProtect" }
	                  { Kind = "Hazard", Hazard = "Spikes" | "ToxicSpikes" | "StickyWeb" }
	                  { Kind = "ClearHazards", Scope = "Own" | "All", BonusStat = ..., BonusStages = ... }
	                  { Kind = "SideEffect", SideEffect = "Barrier" | "Tailwind", Turns = n }
	                  { Kind = "Heal", Fraction = 0.35..0.5, Target = "Self" | "Target" }
	                  { Kind = "Cleanse", Target = "Self" | "Target" }
	  Anim          (opcional) nome da animacao na pasta Animations do modelo; tocada no cliente
	  Vfx           (opcional) nome do efeito em ReplicatedStorage/Vfx; tocado pelo VfxController
	  Timing        (com Anim) instantes Charge, Release e Impact em segundos
	  Target        (opcional, usado no 2x2): "Single" (padrao), "AllEnemies" (0.75x em 2+ alvos),
	                "AllOthers", "AllAllies", "EnemySide" ou "Self".
	  Generic       true nos golpes genericos compartilhados por classe
	  Signature     true na tecnica assinatura do personagem
]]

local Moves = {}

Moves.List = {
	--------------------------------------------------------------------
	-- Golpes Genericos de Classe: ESPADACHIM (15 genericos: Nv. 1 -> 38)
	-- (CorteBasico e CorteCruzado sao os 2 ataques basicos identicos para TODOS os espadachins)
	--------------------------------------------------------------------
	CorteBasico = {
		Name = "Corte R\u{e1}pido", Type = "Espadachim", Category = "Damage", Power = 40, Accuracy = 100, PP = 30,
		Generic = true, LearnLevel = 1,
		Anim = "CorteBasico", Vfx = "CorteBasico",
		Timing = { Charge = 0.12, Release = 0.28, Impact = 0.38, Length = 0.90 },
	},
	CorteCruzado = {
		Name = "Corte Cruzado", Type = "Espadachim", Category = "Damage", Power = 52, Accuracy = 95, PP = 20,
		CritChance = 0.15, Generic = true, LearnLevel = 1,
		Anim = "CorteCruzado", Vfx = "CorteCruzado",
		Timing = { Charge = 0.14, Release = 0.34, Impact = 0.62, Length = 1.15 },
	},
	PosturaDaLamina = {
		Name = "Postura da L\u{e2}mina", Type = "Espadachim", Category = "Status", Accuracy = nil, PP = 15,
		Effect = { Kind = "StatStage", Stat = "Attack", Stages = 1, Target = "Self" },
		Generic = true, LearnLevel = 5,
		Anim = "SwordStance", Vfx = "GenBuff",
		Timing = { Charge = 0.14, Release = 0.38, Impact = 0.48, Length = 0.90 },
	},
	EstocadaVeloz = {
		Name = "Estocada Veloz", Type = "Espadachim", Category = "Damage", Power = 35, Accuracy = 100, PP = 25,
		Priority = 1, Generic = true, LearnLevel = 8,
		Anim = "SwordThrust", Vfx = "GenSlash",
		Timing = { Charge = 0.10, Release = 0.22, Impact = 0.34, Length = 0.78 },
	},
	CorteGiratorio = {
		Name = "Corte Girat\u{f3}rio", Type = "Espadachim", Category = "Damage", Power = 42, Accuracy = 100, PP = 15,
		Target = "AllEnemies", Generic = true, LearnLevel = 10,
		Anim = "SwordSpin", Vfx = "GenSlash",
		Timing = { Charge = 0.12, Release = 0.26, Impact = 0.48, Length = 0.96 },
	},
	CorteCerteiro = {
		Name = "Corte Certeiro", Type = "Espadachim", Category = "Damage", Power = 45, Accuracy = nil, PP = 20,
		Generic = true, LearnLevel = 12,
		Anim = "SwordThrust", Vfx = "GenSlash",
		Timing = { Charge = 0.10, Release = 0.22, Impact = 0.34, Length = 0.78 },
	},
	LaminaAfiada = {
		Name = "L\u{e2}mina Afiada", Type = "Espadachim", Category = "Status", Accuracy = nil, PP = 15,
		Target = "Self",
		Effect = { Kind = "MultiStat", Changes = { { Stat = "Attack", Stages = 1 }, { Stat = "Speed", Stages = 1 } }, Target = "Self" },
		Generic = true, LearnLevel = 15,
		Anim = "SwordStance", Vfx = "GenBuff",
		Timing = { Charge = 0.14, Release = 0.38, Impact = 0.48, Length = 0.90 },
	},
	CorteDrenante = {
		Name = "Corte Drenante", Type = "Espadachim", Category = "Damage", Power = 48, Accuracy = 100, PP = 15,
		Drain = 0.5, Generic = true, LearnLevel = 18,
		Anim = "SwordDashSlash", Vfx = "GenSlash",
		Timing = { Charge = 0.12, Release = 0.28, Impact = 0.42, Length = 0.90 },
	},
	QuebraLamina = {
		Name = "Quebra-L\u{e2}mina", Type = "Espadachim", Category = "Damage", Power = 50, Accuracy = 100, PP = 15,
		BreaksProtect = true, Generic = true, LearnLevel = 20,
		Anim = "SwordHeavyCleave", Vfx = "GenSlash",
		Timing = { Charge = 0.14, Release = 0.34, Impact = 0.48, Length = 0.96 },
	},
	FioVenenoso = {
		Name = "Fio Venenoso", Type = "Espadachim", Category = "Damage", Power = 52, Accuracy = 100, PP = 15,
		Effect = { Kind = "Status", Status = "Poison", Chance = 30, Target = "Target" },
		Generic = true, LearnLevel = 22,
		Anim = "SwordDashSlash", Vfx = "GenSlash",
		Timing = { Charge = 0.12, Release = 0.28, Impact = 0.42, Length = 0.90 },
	},
	LaminaPesada = {
		Name = "L\u{e2}mina Pesada", Type = "Espadachim", Category = "Damage", Power = 60, Accuracy = 95, PP = 15,
		Effect = { Kind = "StatStage", Stat = "Defense", Stages = -1, Chance = 20, Target = "Target" },
		Generic = true, LearnLevel = 26,
		Anim = "SwordHeavyCleave", Vfx = "GenSlash",
		Timing = { Charge = 0.14, Release = 0.34, Impact = 0.48, Length = 0.96 },
	},
	DancaDasEspadas = {
		Name = "Dan\u{e7}a das Espadas", Type = "Espadachim", Category = "Status", Accuracy = nil, PP = 10,
		Target = "Self",
		Effect = { Kind = "StatStage", Stat = "Attack", Stages = 2, Target = "Self" },
		Generic = true, LearnLevel = 28,
		Anim = "SwordStance", Vfx = "GenBuff",
		Timing = { Charge = 0.14, Release = 0.36, Impact = 0.48, Length = 0.90 },
	},
	LaminasNoChao = {
		Name = "L\u{e2}minas no Ch\u{e3}o", Type = "Espadachim", Category = "Status", Accuracy = nil, PP = 15,
		Target = "EnemySide",
		Effect = { Kind = "Hazard", Hazard = "Spikes" },
		Generic = true, LearnLevel = 30,
		Anim = "SwordGroundPlant", Vfx = "GenHazard",
		Timing = { Charge = 0.12, Release = 0.32, Impact = 0.50, Length = 0.90 },
	},
	TempestadeDeCortes = {
		Name = "Tempestade de Cortes", Type = "Espadachim", Category = "Damage", Power = 56, Accuracy = 95, PP = 10,
		Target = "AllEnemies", CritChance = 0.12, Generic = true, LearnLevel = 34,
		Anim = "SwordSpin", Vfx = "GenSlash",
		Timing = { Charge = 0.12, Release = 0.26, Impact = 0.48, Length = 0.96 },
	},
	InvestidaCortante = {
		Name = "Investida Cortante", Type = "Espadachim", Category = "Damage", Power = 72, Accuracy = 90, PP = 10,
		Recoil = 0.25, Generic = true, LearnLevel = 38,
		Anim = "SwordDashSlash", Vfx = "GenSlash",
		Timing = { Charge = 0.12, Release = 0.28, Impact = 0.42, Length = 0.90 },
	},

	--------------------------------------------------------------------
	-- Golpes Genericos de Classe: LUTADOR (15 genericos: Nv. 1 -> 38)
	--------------------------------------------------------------------
	SocoDireto = {
		Name = "Soco Direto", Type = "Lutador", Category = "Damage", Power = 40, Accuracy = 100, PP = 30,
		Generic = true, LearnLevel = 1,
		Anim = "PunchJab", Vfx = "GenMelee",
		Timing = { Charge = 0.10, Release = 0.22, Impact = 0.34, Length = 0.72 },
	},
	ComboMarcial = {
		Name = "Combo Marcial", Type = "Lutador", Category = "Damage", Power = 45, Accuracy = 100, PP = 25,
		Generic = true, LearnLevel = 1,
		Anim = "ComboMarcial", Vfx = "ComboMarcial", AnimSpeed = 2.6,
		Timing = { Charge = 0.12, Release = 0.54, Impact = 1.15, Length = 1.52 },
	},
	PosturaDeCombate = {
		Name = "Postura de Combate", Type = "Lutador", Category = "Status", Accuracy = nil, PP = 15,
		Effect = { Kind = "StatStage", Stat = "Attack", Stages = 1, Target = "Self" },
		Generic = true, LearnLevel = 5,
		Anim = "FighterFlex", Vfx = "GenBuff",
		Timing = { Charge = 0.14, Release = 0.36, Impact = 0.46, Length = 0.88 },
	},
	SocoRelampago = {
		Name = "Soco Rel\u{e2}mpago", Type = "Lutador", Category = "Damage", Power = 35, Accuracy = 100, PP = 25,
		Priority = 1, Generic = true, LearnLevel = 8,
		Anim = "PunchJab", Vfx = "GenMelee",
		Timing = { Charge = 0.10, Release = 0.22, Impact = 0.34, Length = 0.72 },
	},
	QuebraGuarda = {
		Name = "Quebra-Guarda", Type = "Lutador", Category = "Damage", Power = 45, Accuracy = 95, PP = 15,
		Effect = { Kind = "StatStage", Stat = "Defense", Stages = -1, Chance = 40, Target = "Target" },
		Generic = true, LearnLevel = 10,
		Anim = "PunchHeavy", Vfx = "GenMelee",
		Timing = { Charge = 0.14, Release = 0.32, Impact = 0.46, Length = 0.92 },
	},
	Rasteira = {
		Name = "Rasteira", Type = "Lutador", Category = "Damage", Power = 42, Accuracy = 100, PP = 20,
		Effect = { Kind = "StatStage", Stat = "Speed", Stages = -1, Chance = 100, Target = "Target" },
		Generic = true, LearnLevel = 12,
		Anim = "LowSweepKick", Vfx = "GenMelee",
		Timing = { Charge = 0.12, Release = 0.26, Impact = 0.44, Length = 0.88 },
	},
	CorpoDeFerro = {
		Name = "Corpo de Ferro", Type = "Lutador", Category = "Status", Accuracy = nil, PP = 15,
		Target = "Self",
		Effect = { Kind = "MultiStat", Changes = { { Stat = "Attack", Stages = 1 }, { Stat = "Defense", Stages = 1 } }, Target = "Self" },
		Generic = true, LearnLevel = 15,
		Anim = "FighterFlex", Vfx = "GenBuff",
		Timing = { Charge = 0.14, Release = 0.36, Impact = 0.46, Length = 0.88 },
	},
	SocoDrenante = {
		Name = "Soco Drenante", Type = "Lutador", Category = "Damage", Power = 48, Accuracy = 100, PP = 15,
		Drain = 0.5, Generic = true, LearnLevel = 18,
		Anim = "PunchJab", Vfx = "GenMelee",
		Timing = { Charge = 0.10, Release = 0.22, Impact = 0.34, Length = 0.72 },
	},
	PunhoDemolidor = {
		Name = "Punho Demolidor", Type = "Lutador", Category = "Damage", Power = 50, Accuracy = 100, PP = 15,
		BreaksProtect = true, Generic = true, LearnLevel = 20,
		Anim = "PunchHeavy", Vfx = "GenMelee",
		Timing = { Charge = 0.14, Release = 0.32, Impact = 0.46, Length = 0.92 },
	},
	OndaDeImpacto = {
		Name = "Onda de Impacto", Type = "Lutador", Category = "Damage", Power = 48, Accuracy = 100, PP = 15,
		Target = "AllEnemies",
		Effect = { Kind = "StatStage", Stat = "Defense", Stages = -1, Chance = 20, Target = "Target" },
		Generic = true, LearnLevel = 22,
		Anim = "GroundSlam", Vfx = "GenGroundWave",
		Timing = { Charge = 0.14, Release = 0.38, Impact = 0.54, Length = 0.96 },
	},
	GritoDeGuerra = {
		Name = "Grito de Guerra", Type = "Lutador", Category = "Status", Accuracy = nil, PP = 15,
		Target = "AllAllies",
		Effect = { Kind = "StatStage", Stat = "Attack", Stages = 1, Target = "Target" },
		Generic = true, LearnLevel = 25,
		Anim = "FighterFlex", Vfx = "GenBuff",
		Timing = { Charge = 0.14, Release = 0.36, Impact = 0.46, Length = 0.88 },
	},
	PunhoArdente = {
		Name = "Punho Ardente", Type = "Lutador", Category = "Damage", Power = 58, Accuracy = 95, PP = 15,
		Effect = { Kind = "Status", Status = "Burn", Chance = 20, Target = "Target" },
		Generic = true, LearnLevel = 28,
		Anim = "PunchHeavy", Vfx = "GenMelee",
		Timing = { Charge = 0.14, Release = 0.32, Impact = 0.46, Length = 0.92 },
	},
	GiroVarredor = {
		Name = "Giro Varredor", Type = "Lutador", Category = "Damage", Power = 35, Accuracy = 100, PP = 20,
		Effect = { Kind = "ClearHazards", Scope = "Own", BonusStat = "Speed", BonusStages = 1 },
		Generic = true, LearnLevel = 30,
		Anim = "LowSweepKick", Vfx = "GenMelee",
		Timing = { Charge = 0.12, Release = 0.26, Impact = 0.44, Length = 0.88 },
	},
	FocoInterior = {
		Name = "Foco Interior", Type = "Lutador", Category = "Status", Accuracy = nil, PP = 10,
		Target = "Self",
		Effect = { Kind = "Heal", Fraction = 0.5, Target = "Self" },
		Generic = true, LearnLevel = 34,
		Anim = "MeditateFocus", Vfx = "GenHeal",
		Timing = { Charge = 0.16, Release = 0.44, Impact = 0.54, Length = 0.92 },
	},
	ImpactoTotal = {
		Name = "Impacto Total", Type = "Lutador", Category = "Damage", Power = 74, Accuracy = 90, PP = 10,
		Recoil = 0.30, Generic = true, LearnLevel = 38,
		Anim = "PunchHeavy", Vfx = "GenMelee",
		Timing = { Charge = 0.14, Release = 0.32, Impact = 0.46, Length = 0.92 },
	},

	--------------------------------------------------------------------
	-- Golpes Genericos de Classe: MAGO (16 genericos: Nv. 1 -> 38)
	--------------------------------------------------------------------
	EsferaArcana = {
		Name = "Esfera Arcana", Type = "Mago", Category = "Damage", Power = 42, Accuracy = 100, PP = 25,
		Generic = true, LearnLevel = 1,
		Anim = "MagicCastOrb", Vfx = "GenProjectile",
		Timing = { Charge = 0.12, Release = 0.30, Impact = 0.46, Length = 0.84 },
	},
	ChamaMistica = {
		Name = "Chama M\u{ed}stica", Type = "Mago", Category = "Damage", Power = 35, Accuracy = 100, PP = 15,
		Target = "AllEnemies",
		Effect = { Kind = "Status", Status = "Burn", Chance = 30, Target = "Target" },
		Generic = true, LearnLevel = 1,
		Anim = "MagicWaveCast", Vfx = "GenVolley",
		Timing = { Charge = 0.14, Release = 0.34, Impact = 0.54, Length = 0.94 },
	},
	SeloParalisante = {
		Name = "Selo Paralisante", Type = "Mago", Category = "Status", Accuracy = 90, PP = 15,
		Effect = { Kind = "Status", Status = "Paralysis", Chance = 100, Target = "Target" },
		Generic = true, LearnLevel = 5,
		Anim = "MagicHexSeal", Vfx = "GenHex",
		Timing = { Charge = 0.14, Release = 0.32, Impact = 0.50, Length = 0.86 },
	},
	PulsoVeloz = {
		Name = "Pulso Veloz", Type = "Mago", Category = "Damage", Power = 35, Accuracy = 100, PP = 25,
		Priority = 1, Generic = true, LearnLevel = 8,
		Anim = "MagicCastOrb", Vfx = "GenProjectile",
		Timing = { Charge = 0.10, Release = 0.24, Impact = 0.38, Length = 0.78 },
	},
	OndaArcana = {
		Name = "Onda Arcana", Type = "Mago", Category = "Damage", Power = 45, Accuracy = 100, PP = 15,
		Target = "AllEnemies", Generic = true, LearnLevel = 10,
		Anim = "MagicWaveCast", Vfx = "GenVolley",
		Timing = { Charge = 0.14, Release = 0.34, Impact = 0.54, Length = 0.94 },
	},
	RaioCongelante = {
		Name = "Raio Congelante", Type = "Mago", Category = "Damage", Power = 48, Accuracy = 100, PP = 15,
		Effect = { Kind = "Status", Status = "Freeze", Chance = 15, Target = "Target" },
		Generic = true, LearnLevel = 12,
		Anim = "MagicCastOrb", Vfx = "GenProjectile",
		Timing = { Charge = 0.12, Release = 0.30, Impact = 0.44, Length = 0.84 },
	},
	FogoFatuo = {
		Name = "Fogo-F\u{e1}tuo", Type = "Mago", Category = "Status", Accuracy = 85, PP = 15,
		Effect = { Kind = "Status", Status = "Burn", Chance = 100, Target = "Target" },
		Generic = true, LearnLevel = 14,
		Anim = "MagicHexSeal", Vfx = "GenHex",
		Timing = { Charge = 0.14, Release = 0.32, Impact = 0.50, Length = 0.86 },
	},
	MenteCalma = {
		Name = "Mente Calma", Type = "Mago", Category = "Status", Accuracy = nil, PP = 15,
		Target = "Self",
		Effect = { Kind = "MultiStat", Changes = { { Stat = "Attack", Stages = 1 }, { Stat = "Defense", Stages = 1 } }, Target = "Self" },
		Generic = true, LearnLevel = 16,
		Anim = "MagicAuraChannel", Vfx = "GenBuff",
		Timing = { Charge = 0.16, Release = 0.44, Impact = 0.54, Length = 0.96 },
	},
	SifaoArcano = {
		Name = "Sif\u{e3}o Arcano", Type = "Mago", Category = "Damage", Power = 48, Accuracy = 100, PP = 15,
		Drain = 0.5, Generic = true, LearnLevel = 18,
		Anim = "MagicCastOrb", Vfx = "GenProjectile",
		Timing = { Charge = 0.12, Release = 0.30, Impact = 0.46, Length = 0.84 },
	},
	NevoaDoSono = {
		Name = "N\u{e9}voa do Sono", Type = "Mago", Category = "Status", Accuracy = 75, PP = 10,
		Effect = { Kind = "Status", Status = "Sleep", Chance = 100, Target = "Target" },
		Generic = true, LearnLevel = 20,
		Anim = "MagicHexSeal", Vfx = "GenHex",
		Timing = { Charge = 0.14, Release = 0.32, Impact = 0.50, Length = 0.86 },
	},
	BarreiraArcana = {
		Name = "Barreira Arcana", Type = "Mago", Category = "Status", Accuracy = nil, PP = 15,
		Target = "Self",
		Effect = { Kind = "SideEffect", SideEffect = "Barrier", Turns = 5 },
		Generic = true, LearnLevel = 22,
		Anim = "MagicBarrierCast", Vfx = "GenShield",
		Timing = { Charge = 0.14, Release = 0.34, Impact = 0.46, Length = 0.86 },
	},
	RunasToxicas = {
		Name = "Runas T\u{f3}xicas", Type = "Mago", Category = "Status", Accuracy = nil, PP = 15,
		Target = "EnemySide",
		Effect = { Kind = "Hazard", Hazard = "ToxicSpikes" },
		Generic = true, LearnLevel = 24,
		Anim = "MagicHexSeal", Vfx = "GenHazard",
		Timing = { Charge = 0.14, Release = 0.32, Impact = 0.50, Length = 0.86 },
	},
	CuraLuminosa = {
		Name = "Cura Luminosa", Type = "Mago", Category = "Status", Accuracy = nil, PP = 10,
		Target = "AllAllies",
		Effect = { Kind = "Heal", Fraction = 0.35, Target = "Target" },
		Generic = true, LearnLevel = 26,
		Anim = "MagicAuraChannel", Vfx = "GenHeal",
		Timing = { Charge = 0.16, Release = 0.44, Impact = 0.54, Length = 0.96 },
	},
	Purificacao = {
		Name = "Purifica\u{e7}\u{e3}o", Type = "Mago", Category = "Status", Accuracy = nil, PP = 15,
		Target = "AllAllies",
		Effect = { Kind = "Cleanse", Target = "Target" },
		Generic = true, LearnLevel = 28,
		Anim = "MagicAuraChannel", Vfx = "GenHeal",
		Timing = { Charge = 0.16, Release = 0.44, Impact = 0.54, Length = 0.96 },
	},
	ExplosaoAstral = {
		Name = "Explos\u{e3}o Astral", Type = "Mago", Category = "Damage", Power = 60, Accuracy = 95, PP = 10,
		Target = "AllEnemies",
		Effect = { Kind = "StatStage", Stat = "Defense", Stages = -1, Chance = 15, Target = "Target" },
		Generic = true, LearnLevel = 34,
		Anim = "MagicWaveCast", Vfx = "GenVolley",
		Timing = { Charge = 0.14, Release = 0.34, Impact = 0.56, Length = 0.94 },
	},
	MeteoroArcano = {
		Name = "Meteoro Arcano", Type = "Mago", Category = "Damage", Power = 72, Accuracy = 90, PP = 10,
		Effect = { Kind = "StatStage", Stat = "Attack", Stages = -1, Chance = 100, Target = "Self" },
		Generic = true, LearnLevel = 38,
		Anim = "MagicSkyCall", Vfx = "GenSkyStrike",
		Timing = { Charge = 0.14, Release = 0.38, Impact = 0.60, Length = 1.04 },
	},

	--------------------------------------------------------------------
	-- Golpes Genericos de Classe: ATIRADOR (15 genericos: Nv. 1 -> 38)
	--------------------------------------------------------------------
	DisparoPreciso = {
		Name = "Disparo Preciso", Type = "Atirador", Category = "Damage", Power = 42, Accuracy = nil, PP = 25,
		Generic = true, LearnLevel = 1,
		Anim = "RangedSnapShot", Vfx = "GenProjectile",
		Timing = { Charge = 0.10, Release = 0.24, Impact = 0.38, Length = 0.74 },
	},
	TiroPerfurante = {
		Name = "Tiro Perfurante", Type = "Atirador", Category = "Damage", Power = 52, Accuracy = 95, PP = 15,
		CritChance = 0.18, Generic = true, LearnLevel = 1,
		Anim = "RangedSnipeShot", Vfx = "GenProjectile",
		Timing = { Charge = 0.14, Release = 0.36, Impact = 0.48, Length = 0.94 },
	},
	MiraFirme = {
		Name = "Mira Firme", Type = "Atirador", Category = "Status", Accuracy = nil, PP = 15,
		Effect = { Kind = "StatStage", Stat = "Attack", Stages = 1, Target = "Self" },
		Generic = true, LearnLevel = 5,
		Anim = "IntimidateGlare", Vfx = "GenBuff",
		Timing = { Charge = 0.12, Release = 0.28, Impact = 0.40, Length = 0.80 },
	},
	TiroRapido = {
		Name = "Tiro R\u{e1}pido", Type = "Atirador", Category = "Damage", Power = 35, Accuracy = 100, PP = 25,
		Priority = 1, Generic = true, LearnLevel = 8,
		Anim = "RangedSnapShot", Vfx = "GenProjectile",
		Timing = { Charge = 0.10, Release = 0.24, Impact = 0.36, Length = 0.74 },
	},
	ChuvaDeProjeteis = {
		Name = "Chuva de Proj\u{e9}teis", Type = "Atirador", Category = "Damage", Power = 40, Accuracy = 95, PP = 15,
		Target = "AllEnemies", Generic = true, LearnLevel = 10,
		Anim = "RangedVolley", Vfx = "GenVolley",
		Timing = { Charge = 0.10, Release = 0.24, Impact = 0.52, Length = 0.94 },
	},
	DardoVenenoso = {
		Name = "Dardo Venenoso", Type = "Atirador", Category = "Damage", Power = 42, Accuracy = 100, PP = 20,
		Effect = { Kind = "Status", Status = "Poison", Chance = 40, Target = "Target" },
		Generic = true, LearnLevel = 12,
		Anim = "RangedSnapShot", Vfx = "GenProjectile",
		Timing = { Charge = 0.10, Release = 0.24, Impact = 0.38, Length = 0.74 },
	},
	FocoDePrecisao = {
		Name = "Foco de Precis\u{e3}o", Type = "Atirador", Category = "Status", Accuracy = nil, PP = 15,
		Target = "Self",
		Effect = { Kind = "MultiStat", Changes = { { Stat = "Attack", Stages = 1 }, { Stat = "Accuracy", Stages = 1 } }, Target = "Self" },
		Generic = true, LearnLevel = 15,
		Anim = "IntimidateGlare", Vfx = "GenBuff",
		Timing = { Charge = 0.12, Release = 0.28, Impact = 0.40, Length = 0.80 },
	},
	DisparoDeRede = {
		Name = "Disparo de Rede", Type = "Atirador", Category = "Status", Accuracy = nil, PP = 15,
		Target = "EnemySide",
		Effect = { Kind = "Hazard", Hazard = "StickyWeb" },
		Generic = true, LearnLevel = 18,
		Anim = "RangedThrowGadget", Vfx = "GenHazard",
		Timing = { Charge = 0.12, Release = 0.30, Impact = 0.50, Length = 0.84 },
	},
	TiroDeSupressao = {
		Name = "Tiro de Supress\u{e3}o", Type = "Atirador", Category = "Damage", Power = 44, Accuracy = 95, PP = 15,
		Target = "AllEnemies",
		Effect = { Kind = "StatStage", Stat = "Speed", Stages = -1, Chance = 100, Target = "Target" },
		Generic = true, LearnLevel = 20,
		Anim = "RangedVolley", Vfx = "GenVolley",
		Timing = { Charge = 0.10, Release = 0.24, Impact = 0.52, Length = 0.94 },
	},
	DisparoRompeEscudo = {
		Name = "Disparo Rompe-Escudo", Type = "Atirador", Category = "Damage", Power = 50, Accuracy = 100, PP = 15,
		BreaksProtect = true, Generic = true, LearnLevel = 22,
		Anim = "RangedSnipeShot", Vfx = "GenProjectile",
		Timing = { Charge = 0.14, Release = 0.36, Impact = 0.48, Length = 0.94 },
	},
	BombaDeFumaca = {
		Name = "Bomba de Fuma\u{e7}a", Type = "Atirador", Category = "Status", Accuracy = 95, PP = 15,
		Target = "AllEnemies",
		Effect = { Kind = "StatStage", Stat = "Accuracy", Stages = -1, Target = "Target" },
		Generic = true, LearnLevel = 24,
		Anim = "RangedThrowGadget", Vfx = "GenHex",
		Timing = { Charge = 0.12, Release = 0.30, Impact = 0.50, Length = 0.84 },
	},
	MinaDeEstrepes = {
		Name = "Mina de Estrepes", Type = "Atirador", Category = "Status", Accuracy = nil, PP = 15,
		Target = "EnemySide",
		Effect = { Kind = "Hazard", Hazard = "Spikes" },
		Generic = true, LearnLevel = 28,
		Anim = "RangedThrowGadget", Vfx = "GenHazard",
		Timing = { Charge = 0.12, Release = 0.30, Impact = 0.50, Length = 0.84 },
	},
	DardoEletrico = {
		Name = "Dardo El\u{e9}trico", Type = "Atirador", Category = "Damage", Power = 52, Accuracy = 95, PP = 15,
		Effect = { Kind = "Status", Status = "Paralysis", Chance = 30, Target = "Target" },
		Generic = true, LearnLevel = 30,
		Anim = "RangedSnapShot", Vfx = "GenProjectile",
		Timing = { Charge = 0.10, Release = 0.24, Impact = 0.38, Length = 0.74 },
	},
	RajadaTatica = {
		Name = "Rajada T\u{e1}tica", Type = "Atirador", Category = "Damage", Power = 58, Accuracy = 95, PP = 10,
		Target = "AllEnemies", CritChance = 0.12, Generic = true, LearnLevel = 34,
		Anim = "RangedVolley", Vfx = "GenVolley",
		Timing = { Charge = 0.10, Release = 0.24, Impact = 0.52, Length = 0.94 },
	},
	DisparoDeElite = {
		Name = "Disparo de Elite", Type = "Atirador", Category = "Damage", Power = 72, Accuracy = 90, PP = 10,
		CritChance = 0.25, Generic = true, LearnLevel = 38,
		Anim = "RangedSnipeShot", Vfx = "GenProjectile",
		Timing = { Charge = 0.14, Release = 0.36, Impact = 0.48, Length = 0.94 },
	},

	--------------------------------------------------------------------
	-- Golpes Genericos Universais (10 genericos taticos para qualquer classe)
	--------------------------------------------------------------------
	AtaqueRapido = {
		Name = "Ataque R\u{e1}pido", Type = "Universal", Category = "Damage", Power = 35, Accuracy = 100, PP = 30,
		Priority = 1, Generic = true, LearnLevel = 6,
		Anim = "ShoulderRush", Vfx = "GenMelee",
		Timing = { Charge = 0.10, Release = 0.22, Impact = 0.34, Length = 0.74 },
	},
	Proteger = {
		Name = "Proteger", Type = "Universal", Category = "Status", Accuracy = nil, PP = 10,
		Priority = 4, Target = "Self",
		Effect = { Kind = "Protect" },
		Generic = true, LearnLevel = 10,
		Anim = "GuardBrace", Vfx = "GenShield",
		Timing = { Charge = 0.10, Release = 0.24, Impact = 0.36, Length = 0.80 },
	},
	OlharIntimidador = {
		Name = "Olhar Intimidador", Type = "Universal", Category = "Status", Accuracy = 100, PP = 20,
		Target = "AllEnemies",
		Effect = { Kind = "StatStage", Stat = "Attack", Stages = -1, Target = "Target" },
		Generic = true, LearnLevel = 12,
		Anim = "IntimidateGlare", Vfx = "GenHex",
		Timing = { Charge = 0.12, Release = 0.28, Impact = 0.40, Length = 0.80 },
	},
	GuardaAmpla = {
		Name = "Guarda Ampla", Type = "Universal", Category = "Status", Accuracy = nil, PP = 10,
		Priority = 3, Target = "Self",
		Effect = { Kind = "WideProtect" },
		Generic = true, LearnLevel = 16,
		Anim = "GuardBrace", Vfx = "GenShield",
		Timing = { Charge = 0.10, Release = 0.24, Impact = 0.36, Length = 0.80 },
	},
	VenenoPuro = {
		Name = "Veneno Puro", Type = "Universal", Category = "Status", Accuracy = 90, PP = 15,
		Effect = { Kind = "Status", Status = "Poison", Chance = 100, Target = "Target" },
		Generic = true, LearnLevel = 16,
		Anim = "MagicHexSeal", Vfx = "GenHex",
		Timing = { Charge = 0.14, Release = 0.32, Impact = 0.50, Length = 0.86 },
	},
	Agilidade = {
		Name = "Agilidade", Type = "Universal", Category = "Status", Accuracy = nil, PP = 20,
		Target = "Self",
		Effect = { Kind = "StatStage", Stat = "Speed", Stages = 2, Target = "Self" },
		Generic = true, LearnLevel = 18,
		Anim = "WindSweep", Vfx = "GenBuff",
		Timing = { Charge = 0.12, Release = 0.32, Impact = 0.44, Length = 0.84 },
	},
	Desobstruir = {
		Name = "Desobstruir", Type = "Universal", Category = "Status", Accuracy = nil, PP = 15,
		Target = "Self",
		Effect = { Kind = "ClearHazards", Scope = "All" },
		Generic = true, LearnLevel = 18,
		Anim = "WindSweep", Vfx = "GenWind",
		Timing = { Charge = 0.12, Release = 0.32, Impact = 0.44, Length = 0.84 },
	},
	VentoAFavor = {
		Name = "Vento a Favor", Type = "Universal", Category = "Status", Accuracy = nil, PP = 15,
		Target = "Self",
		Effect = { Kind = "SideEffect", SideEffect = "Tailwind", Turns = 4 },
		Generic = true, LearnLevel = 20,
		Anim = "WindSweep", Vfx = "GenWind",
		Timing = { Charge = 0.12, Release = 0.32, Impact = 0.44, Length = 0.84 },
	},
	MuralhaDeFerro = {
		Name = "Muralha de Ferro", Type = "Universal", Category = "Status", Accuracy = nil, PP = 15,
		Target = "Self",
		Effect = { Kind = "StatStage", Stat = "Defense", Stages = 2, Target = "Self" },
		Generic = true, LearnLevel = 22,
		Anim = "GuardBrace", Vfx = "GenBuff",
		Timing = { Charge = 0.10, Release = 0.24, Impact = 0.36, Length = 0.80 },
	},
	Recuperacao = {
		Name = "Recupera\u{e7}\u{e3}o", Type = "Universal", Category = "Status", Accuracy = nil, PP = 10,
		Target = "Self",
		Effect = { Kind = "Heal", Fraction = 0.5, Target = "Self" },
		Generic = true, LearnLevel = 24,
		Anim = "MeditateFocus", Vfx = "GenHeal",
		Timing = { Charge = 0.16, Release = 0.44, Impact = 0.54, Length = 0.92 },
	},

	--------------------------------------------------------------------
	-- Golpes Classicos e Tecnicas Assinatura Existentes (preservados para saves)
	--------------------------------------------------------------------
	-- Kaen (Espadachim)
	CorteFlamejante = {
		Name = "Corte Flamejante", Type = "Espadachim", Category = "Damage", Power = 50, Accuracy = 100, PP = 20,
		Anim = "SwordHeavyCleave", Vfx = "GenSlash",
		Timing = { Charge = 0.14, Release = 0.34, Impact = 0.48, Length = 0.96 },
	},
	Investida = {
		Name = "Investida", Type = "Lutador", Category = "Damage", Power = 40, Accuracy = 100, PP = 30,
		Anim = "ShoulderRush", Vfx = "GenMelee",
		Timing = { Charge = 0.10, Release = 0.22, Impact = 0.34, Length = 0.74 },
	},
	BrasaViva = {
		Name = "Brasa Viva", Type = "Mago", Category = "Damage", Power = 35, Accuracy = 100, PP = 15,
		Target = "AllEnemies",
		Effect = { Kind = "Status", Status = "Burn", Chance = 30, Target = "Target" },
		Anim = "MagicWaveCast", Vfx = "GenVolley",
		Timing = { Charge = 0.14, Release = 0.34, Impact = 0.54, Length = 0.94 },
	},

	-- Raiko / Eletricos
	Descarga = {
		Name = "Descarga", Type = "Mago", Category = "Damage", Power = 50, Accuracy = 100, PP = 20, Target = "AllEnemies",
		Anim = "MagicSkyCall", Vfx = "GenSkyStrike",
		Timing = { Charge = 0.14, Release = 0.38, Impact = 0.60, Length = 1.04 },
	},
	PunhoDeMare = {
		Name = "Punho de Mar\u{e9}", Type = "Lutador", Category = "Damage", Power = 40, Accuracy = 95, PP = 15,
		Anim = "PunchJab", Vfx = "GenMelee",
		Timing = { Charge = 0.10, Release = 0.22, Impact = 0.34, Length = 0.72 },
	},
	Estatica = {
		Name = "Est\u{e1}tica", Type = "Mago", Category = "Status", Accuracy = 90, PP = 15,
		Effect = { Kind = "Status", Status = "Paralysis", Chance = 100, Target = "Target" },
		Anim = "MagicHexSeal", Vfx = "GenHex",
		Timing = { Charge = 0.14, Release = 0.32, Impact = 0.50, Length = 0.86 },
	},

	-- Yomogi (Mago da Floresta)
	GaiolaDeEspinhos = {
		Name = "Gaiola de Espinhos", Type = "Mago", Category = "Damage", Power = 50, Accuracy = 100, PP = 20,
		Target = "AllEnemies",
		Signature = true, Anim = "GaiolaDeEspinhos", Vfx = "GaiolaDeEspinhos",
		Timing = { Charge = 0.15, Release = 0.72, Impact = 1.05, Length = 1.5 },
	},
	Arranhao = {
		Name = "Arranh\u{e3}o", Type = "Lutador", Category = "Damage", Power = 40, Accuracy = 100, PP = 30,
		Anim = "Arranhao", Vfx = "Arranhao",
		Timing = { Charge = 0.1, Release = 0.26, Impact = 0.3, Length = 0.6 },
	},
	SementeToxica = {
		Name = "Semente T\u{f3}xica", Type = "Atirador", Category = "Damage", Power = 35, Accuracy = 100, PP = 15,
		Effect = { Kind = "Status", Status = "Poison", Chance = 30, Target = "Target" },
		Anim = "SementeToxica", Vfx = "SementeToxica",
		Timing = { Charge = 0.12, Release = 0.38, Impact = 0.62, Length = 0.8 },
	},
	CascaDeCarvalho = {
		Name = "Casca de Carvalho", Type = "Mago", Category = "Status", Accuracy = nil, PP = 15,
		Effect = { Kind = "StatStage", Stat = "Defense", Stages = 1, Target = "Self" },
		Anim = "CascaDeCarvalho", Vfx = "CascaDeCarvalho",
		Timing = { Charge = 0.12, Release = 0.45, Impact = 0.48, Length = 0.85 },
	},

	-- Setero (Mago, Lendario)
	Atracao = {
		Name = "Atra\u{e7}\u{e3}o", Type = "Mago", Category = "Damage", Power = 45, Accuracy = 100, PP = 25,
		Anim = "Atracao", Vfx = "Atracao",
		Timing = { Charge = 0.20, Release = 0.55, Impact = 0.90, Length = 1.25 },
	},
	TudoRoxo = {
		Name = "Tudo Roxo", Type = "Mago", Category = "Damage", Power = 65, Accuracy = 95, PP = 10,
		Target = "AllEnemies",
		Signature = true, CutIn = true, Anim = "TudoRoxo", Vfx = "TudoRoxo",
		Timing = { Charge = 0.25, Release = 0.95, Impact = 1.45, Length = 2.00 },
	},

	-- San (Lutador, Lendario)
	Kamehameha = {
		Name = "Kamehameha", Type = "Lutador", Category = "Damage", Power = 55, Accuracy = 100, PP = 15,
		CutIn = true, Anim = "Kamehameha", Vfx = "Kamehameha", AnimSpeed = 3.0,
		CutInColors = {
			Bg = Color3.fromRGB(8, 32, 76),
			Grad1 = Color3.fromRGB(0, 128, 235),
			Grad2 = Color3.fromRGB(8, 36, 92),
			Stroke = Color3.fromRGB(120, 235, 255),
			Text = Color3.fromRGB(255, 252, 235),
			TextStroke = Color3.fromRGB(6, 24, 62),
		},
		Timing = { Charge = 0.32, Release = 1.08, Impact = 1.52, Length = 1.99 },
	},
	GenkiDama = {
		Name = "Genki Dama", Type = "Lutador", Category = "Damage", Power = 70, Accuracy = 95, PP = 10,
		Target = "AllEnemies",
		Signature = true, CutIn = true, Anim = "GenkiDama", Vfx = "GenkiDama", AnimSpeed = 1.35,
		CutInFocusY = 3.8, CutInFov = 48, CutInBannerY = 0.84,
		CutInColors = {
			Bg = Color3.fromRGB(10, 38, 84),
			Grad1 = Color3.fromRGB(25, 155, 255),
			Grad2 = Color3.fromRGB(12, 46, 108),
			Stroke = Color3.fromRGB(255, 228, 115),
			Text = Color3.fromRGB(255, 244, 165),
			TextStroke = Color3.fromRGB(8, 26, 68),
		},
		Timing = { Charge = 0.35, Release = 1.38, Impact = 1.88, Length = 2.20 },
	},
	CargaDeKi = {
		Name = "Carga de Ki", Type = "Lutador", Category = "Status", Accuracy = nil, PP = 15,
		Effect = { Kind = "StatStage", Stat = "Attack", Stages = 1, Target = "Self" },
		Anim = "CargaDeKi", Vfx = "CargaDeKi", AnimSpeed = 2.6,
		Timing = { Charge = 0.12, Release = 0.90, Impact = 1.00, Length = 1.52 },
	},

	-- Barba Branca (Espadachim / Bisento, Lendario)
	SocoSismico = {
		Name = "Soco S\u{ed}smico", Type = "Espadachim", Category = "Damage", Power = 55, Accuracy = 100, PP = 15,
		CutIn = true, CutInFocusY = 1.6, CutInFov = 44, Anim = "SocoSismico", Vfx = "SocoSismico", AnimSpeed = 1.65,
		CutInColors = {
			Bg = Color3.fromRGB(10, 28, 52),
			Grad1 = Color3.fromRGB(28, 125, 195),
			Grad2 = Color3.fromRGB(10, 32, 64),
			Stroke = Color3.fromRGB(185, 245, 255),
			Text = Color3.fromRGB(245, 252, 255),
			TextStroke = Color3.fromRGB(8, 20, 42),
		},
		Timing = { Charge = 0.20, Release = 1.28, Impact = 1.48, Length = 1.80 },
	},
	CeuETerra = {
		Name = "Abalo do C\u{e9}u e da Terra", Type = "Espadachim", Category = "Damage", Power = 75, Accuracy = 90, PP = 10,
		Target = "AllEnemies",
		Signature = true, CutIn = true, Anim = "CeuETerra", Vfx = "CeuETerra", AnimSpeed = 1.45,
		CutInFocusY = 2.0, CutInFov = 46, CutInBannerY = 0.16,
		CutInColors = {
			Bg = Color3.fromRGB(8, 24, 48),
			Grad1 = Color3.fromRGB(15, 140, 220),
			Grad2 = Color3.fromRGB(18, 42, 86),
			Stroke = Color3.fromRGB(255, 232, 130),
			Text = Color3.fromRGB(255, 248, 205),
			TextStroke = Color3.fromRGB(6, 18, 40),
		},
		Timing = { Charge = 0.28, Release = 1.38, Impact = 1.72, Length = 2.05 },
	},
	CorteMurakumo = {
		Name = "Corte Murakumo", Type = "Espadachim", Category = "Damage", Power = 45, Accuracy = 100, PP = 25,
		Anim = "CorteMurakumo", Vfx = "CorteMurakumo", AnimSpeed = 1.35,
		Timing = { Charge = 0.22, Release = 0.85, Impact = 1.15, Length = 1.46 },
	},
	HakiDoConquistador = {
		Name = "Haki do Conquistador", Type = "Espadachim", Category = "Status", Accuracy = nil, PP = 15,
		Effect = { Kind = "StatStage", Stat = "Attack", Stages = 1, Target = "Self" },
		Anim = "HakiDoConquistador", Vfx = "HakiDoConquistador", AnimSpeed = 1.35,
		Timing = { Charge = 0.12, Release = 0.45, Impact = 0.55, Length = 1.46 },
	},

	-- Byakuya Kuchiki (Bleach, Espadachim, Lendario)
	Senbonzakura = {
		Name = "Senbonzakura", Type = "Espadachim", Category = "Damage", Power = 58, Accuracy = 100, PP = 15,
		CutIn = true, CutInFocusY = 1.65, CutInFov = 44, Anim = "Senbonzakura", Vfx = "Senbonzakura",
		CutInColors = {
			Bg = Color3.fromRGB(36, 14, 34),
			Grad1 = Color3.fromRGB(224, 96, 158),
			Grad2 = Color3.fromRGB(48, 16, 44),
			Stroke = Color3.fromRGB(255, 212, 234),
			Text = Color3.fromRGB(255, 246, 252),
			TextStroke = Color3.fromRGB(42, 10, 32),
		},
		Timing = { Charge = 0.20, Release = 0.68, Impact = 1.08, Length = 1.60 },
	},
	SenbonzakuraKageyoshi = {
		Name = "Senbonzakura Kageyoshi", Type = "Espadachim", Category = "Damage", Power = 72, Accuracy = 95, PP = 10,
		Target = "AllEnemies",
		Signature = true, CutIn = true, Anim = "SenbonzakuraKageyoshi", Vfx = "SenbonzakuraKageyoshi",
		CutInFocusY = 1.9, CutInFov = 45, CutInBannerY = 0.16,
		CutInColors = {
			Bg = Color3.fromRGB(24, 10, 28),
			Grad1 = Color3.fromRGB(240, 74, 148),
			Grad2 = Color3.fromRGB(42, 12, 46),
			Stroke = Color3.fromRGB(255, 224, 170),
			Text = Color3.fromRGB(255, 244, 250),
			TextStroke = Color3.fromRGB(32, 8, 28),
		},
		Timing = { Charge = 0.26, Release = 1.16, Impact = 1.66, Length = 2.25 },
	},

	-- Golpe reserva usado so quando todos os golpes estao sem PP
	Esforco = {
		Name = "Esfor\u{e7}o", Type = "Universal", Category = "Damage", Power = 30, Accuracy = 100, PP = 0, Hidden = true,
		Anim = "ShoulderRush", Vfx = "GenMelee",
		Timing = { Charge = 0.10, Release = 0.22, Impact = 0.34, Length = 0.74 },
	},
}

-- Kit generico padrao por classe (Nv. 1 -> 42, herdado automaticamente por novos personagens sem Learnset proprio)
Moves.ClassDefaults = {
	Espadachim = {
		{ Level = 1, Move = "CorteBasico" },
		{ Level = 1, Move = "CorteCruzado" },
		{ Level = 5, Move = "PosturaDaLamina" },
		{ Level = 8, Move = "EstocadaVeloz" },
		{ Level = 12, Move = "CorteGiratorio" },
		{ Level = 16, Move = "LaminaAfiada" },
		{ Level = 20, Move = "CorteDrenante" },
		{ Level = 24, Move = "QuebraLamina" },
		{ Level = 28, Move = "LaminaPesada" },
		{ Level = 32, Move = "DancaDasEspadas" },
		{ Level = 36, Move = "TempestadeDeCortes" },
		{ Level = 42, Move = "InvestidaCortante" },
	},
	Lutador = {
		{ Level = 1, Move = "SocoDireto" },
		{ Level = 1, Move = "ComboMarcial" },
		{ Level = 5, Move = "PosturaDeCombate" },
		{ Level = 8, Move = "SocoRelampago" },
		{ Level = 12, Move = "QuebraGuarda" },
		{ Level = 16, Move = "CorpoDeFerro" },
		{ Level = 20, Move = "SocoDrenante" },
		{ Level = 24, Move = "PunhoDemolidor" },
		{ Level = 28, Move = "OndaDeImpacto" },
		{ Level = 32, Move = "GritoDeGuerra" },
		{ Level = 36, Move = "FocoInterior" },
		{ Level = 42, Move = "ImpactoTotal" },
	},
	Mago = {
		{ Level = 1, Move = "EsferaArcana" },
		{ Level = 1, Move = "ChamaMistica" },
		{ Level = 5, Move = "SeloParalisante" },
		{ Level = 8, Move = "PulsoVeloz" },
		{ Level = 12, Move = "OndaArcana" },
		{ Level = 16, Move = "MenteCalma" },
		{ Level = 20, Move = "SifaoArcano" },
		{ Level = 24, Move = "BarreiraArcana" },
		{ Level = 28, Move = "CuraLuminosa" },
		{ Level = 32, Move = "Purificacao" },
		{ Level = 36, Move = "ExplosaoAstral" },
		{ Level = 42, Move = "MeteoroArcano" },
	},
	Atirador = {
		{ Level = 1, Move = "DisparoPreciso" },
		{ Level = 1, Move = "TiroPerfurante" },
		{ Level = 5, Move = "MiraFirme" },
		{ Level = 8, Move = "TiroRapido" },
		{ Level = 12, Move = "ChuvaDeProjeteis" },
		{ Level = 16, Move = "FocoDePrecisao" },
		{ Level = 20, Move = "DisparoDeRede" },
		{ Level = 24, Move = "TiroDeSupressao" },
		{ Level = 28, Move = "DisparoRompeEscudo" },
		{ Level = 32, Move = "DardoEletrico" },
		{ Level = 36, Move = "RajadaTatica" },
		{ Level = 42, Move = "DisparoDeElite" },
	},
}

-- Animacao padrao recomendada por classe (quando o golpe generico nao tem animacao exclusiva no modelo)
Moves.ClassDefaultAnimations = {
	Espadachim = { Attack = 136035334634731, Special = 136035334634731 },
	Lutador = { Attack = 135688782086034, Special = 111193439375608 },
	Mago = { Attack = 133310018588724, Special = 105158348948965 },
	Atirador = { Attack = 105789525703577, Special = 105789525703577 },
}

Moves.FALLBACK_ID = "Esforco"

-- Preenche o Id de cada golpe a partir da chave
for id, move in pairs(Moves.List) do
	move.Id = id
end

function Moves.Get(id: string)
	return Moves.List[id]
end

-- Retorna o Learnset padrao de uma classe (opcionalmente adicionando tecnica assinatura no nivel indicado)
function Moves.ClassKit(classId: string, signatureMoveId: string?, signatureLevel: number?)
	local base = Moves.ClassDefaults[classId] or Moves.ClassDefaults.Lutador
	local out = {}
	for _, entry in ipairs(base) do
		table.insert(out, { Level = entry.Level, Move = entry.Move })
	end
	if signatureMoveId and Moves.List[signatureMoveId] then
		local found = false
		for _, entry in ipairs(out) do
			if entry.Move == signatureMoveId then
				found = true
				break
			end
		end
		if not found then
			table.insert(out, { Level = signatureLevel or 45, Move = signatureMoveId })
		end
	end
	return out
end

-- Lista todos os golpes genericos de uma classe (opcionalmente incluindo "Universal"),
-- ordenados por LearnLevel crescente. Base para montar Learnsets de progressao por nivel.
function Moves.GenericsByClass(classId: string?, includeUniversal: boolean?)
	local out = {}
	for _, move in pairs(Moves.List) do
		if move.Generic and not move.Hidden then
			if classId == nil or move.Type == classId or (includeUniversal and move.Type == "Universal") then
				table.insert(out, move)
			end
		end
	end
	table.sort(out, function(a, b)
		local la = a.LearnLevel or 1
		local lb = b.LearnLevel or 1
		if la ~= lb then
			return la < lb
		end
		if a.Type ~= b.Type then
			return a.Type < b.Type
		end
		return a.Name < b.Name
	end)
	return out
end

-- Modo de alvo do golpe (usado no 2x2): "Single" | "AllEnemies" | "AllOthers" | "AllAllies" | "EnemySide" | "Self"
function Moves.TargetMode(move): string
	if not move then
		return "Single"
	end
	if move.Target then
		return move.Target
	end
	if move.Category == "Status" and move.Effect then
		local kind = move.Effect.Kind
		if move.Effect.Target == "Self" or kind == "Protect" or kind == "WideProtect" or kind == "SideEffect" or kind == "ClearHazards" then
			return "Self"
		elseif kind == "Hazard" then
			return "EnemySide"
		end
	end
	return "Single"
end

local TARGET_LABELS = {
	Single = "1 Alvo",
	AllEnemies = "Todos Inimigos",
	AllOthers = "Todos Outros",
	AllAllies = "Time Aliado",
	EnemySide = "Campo Inimigo",
	Self = "Pr\u{f3}prio",
}

local STAT_LABELS = {
	Attack = "Ataque",
	Defense = "Defesa",
	Speed = "Velocidade",
	Accuracy = "Precis\u{e3}o",
}

local STATUS_LABELS = {
	Burn = "Queimadura",
	Poison = "Veneno",
	Paralysis = "Paralisia",
	Sleep = "Sono",
	Freeze = "Congelamento",
}

local SPECIAL_DESCRIPTIONS = {
	Senbonzakura = "Dispersa a l\u{e2}mina em mil p\u{e9}talas cortantes contra o alvo (Ataque Especial com Cut-In).",
	SenbonzakuraKageyoshi = "Libera o Bankai em uma tempestade devastadora de p\u{e9}talas sobre todos os inimigos (Assinatura).",
	SocoSismico = "Concentra ondas de tremor no punho e estilha\u{e7}a o ar contra o alvo (Ataque Especial com Cut-In).",
	CeuETerra = "Inclina os mares e o c\u{e9}u em um abalo catacl\u{ed}smico sobre todos os inimigos (Assinatura).",
	Kamehameha = "Dispara um feixe concentrado de energia Ki de alto impacto no alvo (Ataque Especial com Cut-In).",
	GenkiDama = "Re\u{fa}ne energia vital celeste em uma esfera colossal que atinge todos os inimigos (Assinatura).",
	Atracao = "Cria um ponto de atra\u{e7}\u{e3}o gravitacional intensa que esmaga o alvo (Ataque Especial).",
	TudoRoxo = "Funde atra\u{e7}\u{e3}o e repuls\u{e3}o em massa imagin\u{e1}ria que varre todos os inimigos (Assinatura).",
	GaiolaDeEspinhos = "Invoca uma pris\u{e3}o de ra\u{ed}zes e espinhos que atinge todos os inimigos (Assinatura).",
	CorteMurakumo = "Golpe largo e poderoso desferido com a l\u{e2}mina gigante Murakumogiri.",
	HakiDoConquistador = "Libera press\u{e3}o espiritual avassaladora, aumentando o Ataque (+50%) do usu\u{e1}rio.",
	CargaDeKi = "Eleva o Ki interior ao m\u{e1}ximo, aumentando o Ataque (+50%) do usu\u{e1}rio.",
}

function Moves.TargetDisplay(move): string
	return TARGET_LABELS[Moves.TargetMode(move)] or "1 Alvo"
end

local function stagePctLabel(stages: number): string
	local mult = if stages >= 0 then (1 + 0.5 * stages) else (2 / (2 - stages))
	local pct = math.floor((mult - 1) * 100 + (if mult >= 1 then 0.5 else -0.5))
	return if pct >= 0 then ("+" .. pct .. "%") else (pct .. "%")
end

-- Descricao legivel em portugues do que o golpe faz (usada na tela de Golpes)
function Moves.Describe(move): string
	if not move then
		return ""
	end
	if typeof(move.Description) == "string" and #move.Description > 0 then
		return move.Description
	end
	if move.Id and SPECIAL_DESCRIPTIONS[move.Id] then
		return SPECIAL_DESCRIPTIONS[move.Id]
	end

	local mode = Moves.TargetMode(move)
	local eff = move.Effect

	if move.Category == "Status" and eff then
		local kind = eff.Kind
		if kind == "Protect" then
			return "Protege o usu\u{e1}rio de ataques inimigos neste turno. A chance cai se usado seguido."
		elseif kind == "WideProtect" then
			return "Protege todo o seu time contra golpes em \u{e1}rea neste turno (2x2). Chance cai se repetido."
		elseif kind == "Hazard" then
			if eff.Hazard == "Spikes" then
				return "Espalha estrepes no campo inimigo (at\u{e9} 3x). Quem entrar perde 1/8, 1/6 ou 1/4 do HP."
			elseif eff.Hazard == "ToxicSpikes" then
				return "Espalha estrepes t\u{f3}xicos no campo inimigo (at\u{e9} 2x). Envenena quem entra (2x causa dano extra)."
			elseif eff.Hazard == "StickyWeb" then
				return "Cobre o campo inimigo com rede aderente que reduz a Velocidade (-1) de quem entrar."
			end
		elseif kind == "ClearHazards" then
			local scope = if eff.Scope == "All" then "de ambos os campos" else "do seu campo"
			return "Remove todas as armadilhas de entrada (hazards) " .. scope .. "."
		elseif kind == "SideEffect" then
			local turns = eff.Turns or (if eff.SideEffect == "Tailwind" then 4 else 5)
			if eff.SideEffect == "Barrier" then
				return "Ergue uma barreira por " .. turns .. " turnos que reduz o dano recebido pelo time (cr\u{ed}ticos ignoram)."
			elseif eff.SideEffect == "Tailwind" then
				return "Vento a favor por " .. turns .. " turnos que dobra a Velocidade de todo o time."
			end
		elseif kind == "Heal" then
			local pct = math.floor((eff.Fraction or 0.5) * 100 + 0.5)
			if mode == "AllAllies" then
				return "Recupera " .. pct .. "% do HP m\u{e1}ximo de todos os aliados ativos em campo."
			end
			return "Recupera " .. pct .. "% do HP m\u{e1}ximo do usu\u{e1}rio."
		elseif kind == "Cleanse" then
			if mode == "AllAllies" then
				return "Purifica e remove qualquer status negativo de todos os aliados ativos em campo."
			end
			return "Remove qualquer status negativo do usu\u{e1}rio."
		elseif kind == "Status" then
			local stName = STATUS_LABELS[eff.Status] or tostring(eff.Status)
			local who = if mode == "AllEnemies" then "todos os inimigos" else "o alvo"
			return "Aplica " .. stName .. " em " .. who .. "."
		elseif kind == "StatStage" then
			local statName = STAT_LABELS[eff.Stat] or tostring(eff.Stat)
			local stages = eff.Stages or 1
			local verb = if stages >= 2 then "Aumenta muito" elseif stages > 0 then "Aumenta" elseif stages <= -2 then "Reduz muito" else "Reduz"
			local who = if mode == "AllAllies" then "de todos os aliados" elseif mode == "AllEnemies" then "de todos os inimigos" elseif eff.Target == "Self" then "do usu\u{e1}rio" else "do alvo"
			return string.format("%s %s (%s) %s.", verb, statName, stagePctLabel(stages), who)
		elseif kind == "MultiStat" then
			local items = {}
			for _, ch in ipairs(eff.Changes or {}) do
				local sn = STAT_LABELS[ch.Stat] or tostring(ch.Stat)
				table.insert(items, string.format("%s (%s)", sn, stagePctLabel(ch.Stages or 1)))
			end
			local who = if mode == "AllAllies" then "de todos os aliados" elseif eff.Target == "Self" then "do usu\u{e1}rio" else "do alvo"
			return "Eleva " .. table.concat(items, " e ") .. " " .. who .. "."
		end
	end

	-- Golpe de Dano
	local parts = {}
	local usedPrio, usedCrit, usedAcc, usedBreak, usedDrain, usedRecoil = false, false, false, false, false, false
	if mode == "AllEnemies" then
		table.insert(parts, "Golpe em \u{e1}rea que atinge todos os inimigos.")
	elseif mode == "AllOthers" then
		table.insert(parts, "Golpe em \u{e1}rea que atinge todos os outros lutadores.")
	elseif move.Accuracy == nil then
		table.insert(parts, "Ataque certeiro que nunca erra o alvo.")
		usedAcc = true
	elseif (move.Priority or 0) > 0 then
		table.insert(parts, "Ataque veloz (Prioridade +" .. tostring(move.Priority) .. ") que age primeiro.")
		usedPrio = true
	elseif move.BreaksProtect then
		table.insert(parts, "Ataque perfurante que rompe Proteger e Guarda Ampla.")
		usedBreak = true
	elseif move.Drain then
		table.insert(parts, "Absorve " .. math.floor(move.Drain * 100 + 0.5) .. "% do dano causado em HP.")
		usedDrain = true
	elseif move.Recoil then
		table.insert(parts, "Ataque pesado que causa " .. math.floor(move.Recoil * 100 + 0.5) .. "% do dano como recuo.")
		usedRecoil = true
	elseif (move.CritChance or 0) >= 0.12 then
		table.insert(parts, "Ataque preciso com " .. math.floor(move.CritChance * 100 + 0.5) .. "% de chance cr\u{ed}tica.")
		usedCrit = true
	else
		local clsLabel = if move.Type == "Universal" then "universal" else ("de " .. tostring(move.Type))
		table.insert(parts, "Ataque direto " .. clsLabel .. " (b\u{f4}nus de 1,5x na mesma classe).")
	end

	if (move.Priority or 0) > 0 and not usedPrio then
		table.insert(parts, "Prioridade +" .. tostring(move.Priority) .. ".")
	end
	if move.BreaksProtect and not usedBreak then
		table.insert(parts, "Rompe Proteger e Guarda Ampla.")
	end
	if move.Drain and not usedDrain then
		table.insert(parts, "Drena " .. math.floor(move.Drain * 100 + 0.5) .. "% do dano em HP.")
	end
	if move.Recoil and not usedRecoil then
		table.insert(parts, "Sofre " .. math.floor(move.Recoil * 100 + 0.5) .. "% de recuo.")
	end
	if (move.CritChance or 0) >= 0.12 and not usedCrit then
		table.insert(parts, math.floor(move.CritChance * 100 + 0.5) .. "% de chance cr\u{ed}tica.")
	end
	if move.Accuracy == nil and not usedAcc then
		table.insert(parts, "Nunca erra.")
	end

	if eff then
		local chance = eff.Chance or 100
		if eff.Kind == "Status" then
			local stName = STATUS_LABELS[eff.Status] or tostring(eff.Status)
			if chance >= 100 then
				table.insert(parts, "Causa " .. stName .. ".")
			else
				table.insert(parts, chance .. "% de causar " .. stName .. ".")
			end
		elseif eff.Kind == "StatStage" then
			local sn = STAT_LABELS[eff.Stat] or tostring(eff.Stat)
			local stg = eff.Stages or 1
			local verb = if stg > 0 then "aumentar" else "reduzir"
			local who = if eff.Target == "Self" then "do usu\u{e1}rio" else "do alvo"
			if chance >= 100 then
				table.insert(parts, string.format("%s %s (%s) %s.", if stg > 0 then "Aumenta" else "Reduz", sn, stagePctLabel(stg), who))
			else
				table.insert(parts, string.format("%d%% de %s %s (%s) %s.", chance, verb, sn, stagePctLabel(stg), who))
			end
		elseif eff.Kind == "ClearHazards" then
			local txt = "Limpa armadilhas do seu campo"
			if eff.BonusStat then
				local sn = STAT_LABELS[eff.BonusStat] or tostring(eff.BonusStat)
				txt ..= " e aumenta " .. sn .. " (" .. stagePctLabel(eff.BonusStages or 1) .. ")."
			else
				txt ..= "."
			end
			table.insert(parts, txt)
		end
	end

	return table.concat(parts, " ")
end

return Moves
