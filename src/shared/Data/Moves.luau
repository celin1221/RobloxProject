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
	},
	EstocadaVeloz = {
		Name = "Estocada Veloz", Type = "Espadachim", Category = "Damage", Power = 35, Accuracy = 100, PP = 25,
		Priority = 1, Generic = true, LearnLevel = 8,
	},
	CorteGiratorio = {
		Name = "Corte Girat\u{f3}rio", Type = "Espadachim", Category = "Damage", Power = 42, Accuracy = 100, PP = 15,
		Target = "AllEnemies", Generic = true, LearnLevel = 10,
	},
	CorteCerteiro = {
		Name = "Corte Certeiro", Type = "Espadachim", Category = "Damage", Power = 45, Accuracy = nil, PP = 20,
		Generic = true, LearnLevel = 12,
	},
	LaminaAfiada = {
		Name = "L\u{e2}mina Afiada", Type = "Espadachim", Category = "Status", Accuracy = nil, PP = 15,
		Target = "Self",
		Effect = { Kind = "MultiStat", Changes = { { Stat = "Attack", Stages = 1 }, { Stat = "Speed", Stages = 1 } }, Target = "Self" },
		Generic = true, LearnLevel = 15,
	},
	CorteDrenante = {
		Name = "Corte Drenante", Type = "Espadachim", Category = "Damage", Power = 48, Accuracy = 100, PP = 15,
		Drain = 0.5, Generic = true, LearnLevel = 18,
	},
	QuebraLamina = {
		Name = "Quebra-L\u{e2}mina", Type = "Espadachim", Category = "Damage", Power = 50, Accuracy = 100, PP = 15,
		BreaksProtect = true, Generic = true, LearnLevel = 20,
	},
	FioVenenoso = {
		Name = "Fio Venenoso", Type = "Espadachim", Category = "Damage", Power = 52, Accuracy = 100, PP = 15,
		Effect = { Kind = "Status", Status = "Poison", Chance = 30, Target = "Target" },
		Generic = true, LearnLevel = 22,
	},
	LaminaPesada = {
		Name = "L\u{e2}mina Pesada", Type = "Espadachim", Category = "Damage", Power = 60, Accuracy = 95, PP = 15,
		Effect = { Kind = "StatStage", Stat = "Defense", Stages = -1, Chance = 20, Target = "Target" },
		Generic = true, LearnLevel = 26,
	},
	DancaDasEspadas = {
		Name = "Dan\u{e7}a das Espadas", Type = "Espadachim", Category = "Status", Accuracy = nil, PP = 10,
		Target = "Self",
		Effect = { Kind = "StatStage", Stat = "Attack", Stages = 2, Target = "Self" },
		Generic = true, LearnLevel = 28,
	},
	LaminasNoChao = {
		Name = "L\u{e2}minas no Ch\u{e3}o", Type = "Espadachim", Category = "Status", Accuracy = nil, PP = 15,
		Target = "EnemySide",
		Effect = { Kind = "Hazard", Hazard = "Spikes" },
		Generic = true, LearnLevel = 30,
	},
	TempestadeDeCortes = {
		Name = "Tempestade de Cortes", Type = "Espadachim", Category = "Damage", Power = 56, Accuracy = 95, PP = 10,
		Target = "AllEnemies", CritChance = 0.12, Generic = true, LearnLevel = 34,
	},
	InvestidaCortante = {
		Name = "Investida Cortante", Type = "Espadachim", Category = "Damage", Power = 72, Accuracy = 90, PP = 10,
		Recoil = 0.25, Generic = true, LearnLevel = 38,
	},

	--------------------------------------------------------------------
	-- Golpes Genericos de Classe: LUTADOR (15 genericos: Nv. 1 -> 38)
	--------------------------------------------------------------------
	SocoDireto = {
		Name = "Soco Direto", Type = "Lutador", Category = "Damage", Power = 40, Accuracy = 100, PP = 30,
		Generic = true, LearnLevel = 1,
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
	},
	SocoRelampago = {
		Name = "Soco Rel\u{e2}mpago", Type = "Lutador", Category = "Damage", Power = 35, Accuracy = 100, PP = 25,
		Priority = 1, Generic = true, LearnLevel = 8,
	},
	QuebraGuarda = {
		Name = "Quebra-Guarda", Type = "Lutador", Category = "Damage", Power = 45, Accuracy = 95, PP = 15,
		Effect = { Kind = "StatStage", Stat = "Defense", Stages = -1, Chance = 40, Target = "Target" },
		Generic = true, LearnLevel = 10,
	},
	Rasteira = {
		Name = "Rasteira", Type = "Lutador", Category = "Damage", Power = 42, Accuracy = 100, PP = 20,
		Effect = { Kind = "StatStage", Stat = "Speed", Stages = -1, Chance = 100, Target = "Target" },
		Generic = true, LearnLevel = 12,
	},
	CorpoDeFerro = {
		Name = "Corpo de Ferro", Type = "Lutador", Category = "Status", Accuracy = nil, PP = 15,
		Target = "Self",
		Effect = { Kind = "MultiStat", Changes = { { Stat = "Attack", Stages = 1 }, { Stat = "Defense", Stages = 1 } }, Target = "Self" },
		Generic = true, LearnLevel = 15,
	},
	SocoDrenante = {
		Name = "Soco Drenante", Type = "Lutador", Category = "Damage", Power = 48, Accuracy = 100, PP = 15,
		Drain = 0.5, Generic = true, LearnLevel = 18,
	},
	PunhoDemolidor = {
		Name = "Punho Demolidor", Type = "Lutador", Category = "Damage", Power = 50, Accuracy = 100, PP = 15,
		BreaksProtect = true, Generic = true, LearnLevel = 20,
	},
	OndaDeImpacto = {
		Name = "Onda de Impacto", Type = "Lutador", Category = "Damage", Power = 48, Accuracy = 100, PP = 15,
		Target = "AllEnemies",
		Effect = { Kind = "StatStage", Stat = "Defense", Stages = -1, Chance = 20, Target = "Target" },
		Generic = true, LearnLevel = 22,
	},
	GritoDeGuerra = {
		Name = "Grito de Guerra", Type = "Lutador", Category = "Status", Accuracy = nil, PP = 15,
		Target = "AllAllies",
		Effect = { Kind = "StatStage", Stat = "Attack", Stages = 1, Target = "Target" },
		Generic = true, LearnLevel = 25,
	},
	PunhoArdente = {
		Name = "Punho Ardente", Type = "Lutador", Category = "Damage", Power = 58, Accuracy = 95, PP = 15,
		Effect = { Kind = "Status", Status = "Burn", Chance = 20, Target = "Target" },
		Generic = true, LearnLevel = 28,
	},
	GiroVarredor = {
		Name = "Giro Varredor", Type = "Lutador", Category = "Damage", Power = 35, Accuracy = 100, PP = 20,
		Effect = { Kind = "ClearHazards", Scope = "Own", BonusStat = "Speed", BonusStages = 1 },
		Generic = true, LearnLevel = 30,
	},
	FocoInterior = {
		Name = "Foco Interior", Type = "Lutador", Category = "Status", Accuracy = nil, PP = 10,
		Target = "Self",
		Effect = { Kind = "Heal", Fraction = 0.5, Target = "Self" },
		Generic = true, LearnLevel = 34,
	},
	ImpactoTotal = {
		Name = "Impacto Total", Type = "Lutador", Category = "Damage", Power = 74, Accuracy = 90, PP = 10,
		Recoil = 0.30, Generic = true, LearnLevel = 38,
	},

	--------------------------------------------------------------------
	-- Golpes Genericos de Classe: MAGO (16 genericos: Nv. 1 -> 38)
	--------------------------------------------------------------------
	EsferaArcana = {
		Name = "Esfera Arcana", Type = "Mago", Category = "Damage", Power = 42, Accuracy = 100, PP = 25,
		Generic = true, LearnLevel = 1,
	},
	ChamaMistica = {
		Name = "Chama M\u{ed}stica", Type = "Mago", Category = "Damage", Power = 35, Accuracy = 100, PP = 15,
		Target = "AllEnemies",
		Effect = { Kind = "Status", Status = "Burn", Chance = 30, Target = "Target" },
		Generic = true, LearnLevel = 1,
	},
	SeloParalisante = {
		Name = "Selo Paralisante", Type = "Mago", Category = "Status", Accuracy = 90, PP = 15,
		Effect = { Kind = "Status", Status = "Paralysis", Chance = 100, Target = "Target" },
		Generic = true, LearnLevel = 5,
	},
	PulsoVeloz = {
		Name = "Pulso Veloz", Type = "Mago", Category = "Damage", Power = 35, Accuracy = 100, PP = 25,
		Priority = 1, Generic = true, LearnLevel = 8,
	},
	OndaArcana = {
		Name = "Onda Arcana", Type = "Mago", Category = "Damage", Power = 45, Accuracy = 100, PP = 15,
		Target = "AllEnemies", Generic = true, LearnLevel = 10,
	},
	RaioCongelante = {
		Name = "Raio Congelante", Type = "Mago", Category = "Damage", Power = 48, Accuracy = 100, PP = 15,
		Effect = { Kind = "Status", Status = "Freeze", Chance = 15, Target = "Target" },
		Generic = true, LearnLevel = 12,
	},
	FogoFatuo = {
		Name = "Fogo-F\u{e1}tuo", Type = "Mago", Category = "Status", Accuracy = 85, PP = 15,
		Effect = { Kind = "Status", Status = "Burn", Chance = 100, Target = "Target" },
		Generic = true, LearnLevel = 14,
	},
	MenteCalma = {
		Name = "Mente Calma", Type = "Mago", Category = "Status", Accuracy = nil, PP = 15,
		Target = "Self",
		Effect = { Kind = "MultiStat", Changes = { { Stat = "Attack", Stages = 1 }, { Stat = "Defense", Stages = 1 } }, Target = "Self" },
		Generic = true, LearnLevel = 16,
	},
	SifaoArcano = {
		Name = "Sif\u{e3}o Arcano", Type = "Mago", Category = "Damage", Power = 48, Accuracy = 100, PP = 15,
		Drain = 0.5, Generic = true, LearnLevel = 18,
	},
	NevoaDoSono = {
		Name = "N\u{e9}voa do Sono", Type = "Mago", Category = "Status", Accuracy = 75, PP = 10,
		Effect = { Kind = "Status", Status = "Sleep", Chance = 100, Target = "Target" },
		Generic = true, LearnLevel = 20,
	},
	BarreiraArcana = {
		Name = "Barreira Arcana", Type = "Mago", Category = "Status", Accuracy = nil, PP = 15,
		Target = "Self",
		Effect = { Kind = "SideEffect", SideEffect = "Barrier", Turns = 5 },
		Generic = true, LearnLevel = 22,
	},
	RunasToxicas = {
		Name = "Runas T\u{f3}xicas", Type = "Mago", Category = "Status", Accuracy = nil, PP = 15,
		Target = "EnemySide",
		Effect = { Kind = "Hazard", Hazard = "ToxicSpikes" },
		Generic = true, LearnLevel = 24,
	},
	CuraLuminosa = {
		Name = "Cura Luminosa", Type = "Mago", Category = "Status", Accuracy = nil, PP = 10,
		Target = "AllAllies",
		Effect = { Kind = "Heal", Fraction = 0.35, Target = "Target" },
		Generic = true, LearnLevel = 26,
	},
	Purificacao = {
		Name = "Purifica\u{e7}\u{e3}o", Type = "Mago", Category = "Status", Accuracy = nil, PP = 15,
		Target = "AllAllies",
		Effect = { Kind = "Cleanse", Target = "Target" },
		Generic = true, LearnLevel = 28,
	},
	ExplosaoAstral = {
		Name = "Explos\u{e3}o Astral", Type = "Mago", Category = "Damage", Power = 60, Accuracy = 95, PP = 10,
		Target = "AllEnemies",
		Effect = { Kind = "StatStage", Stat = "Defense", Stages = -1, Chance = 15, Target = "Target" },
		Generic = true, LearnLevel = 34,
	},
	MeteoroArcano = {
		Name = "Meteoro Arcano", Type = "Mago", Category = "Damage", Power = 72, Accuracy = 90, PP = 10,
		Effect = { Kind = "StatStage", Stat = "Attack", Stages = -1, Chance = 100, Target = "Self" },
		Generic = true, LearnLevel = 38,
	},

	--------------------------------------------------------------------
	-- Golpes Genericos de Classe: ATIRADOR (15 genericos: Nv. 1 -> 38)
	--------------------------------------------------------------------
	DisparoPreciso = {
		Name = "Disparo Preciso", Type = "Atirador", Category = "Damage", Power = 42, Accuracy = nil, PP = 25,
		Generic = true, LearnLevel = 1,
	},
	TiroPerfurante = {
		Name = "Tiro Perfurante", Type = "Atirador", Category = "Damage", Power = 52, Accuracy = 95, PP = 15,
		CritChance = 0.18, Generic = true, LearnLevel = 1,
	},
	MiraFirme = {
		Name = "Mira Firme", Type = "Atirador", Category = "Status", Accuracy = nil, PP = 15,
		Effect = { Kind = "StatStage", Stat = "Attack", Stages = 1, Target = "Self" },
		Generic = true, LearnLevel = 5,
	},
	TiroRapido = {
		Name = "Tiro R\u{e1}pido", Type = "Atirador", Category = "Damage", Power = 35, Accuracy = 100, PP = 25,
		Priority = 1, Generic = true, LearnLevel = 8,
	},
	ChuvaDeProjeteis = {
		Name = "Chuva de Proj\u{e9}teis", Type = "Atirador", Category = "Damage", Power = 40, Accuracy = 95, PP = 15,
		Target = "AllEnemies", Generic = true, LearnLevel = 10,
	},
	DardoVenenoso = {
		Name = "Dardo Venenoso", Type = "Atirador", Category = "Damage", Power = 42, Accuracy = 100, PP = 20,
		Effect = { Kind = "Status", Status = "Poison", Chance = 40, Target = "Target" },
		Generic = true, LearnLevel = 12,
	},
	FocoDePrecisao = {
		Name = "Foco de Precis\u{e3}o", Type = "Atirador", Category = "Status", Accuracy = nil, PP = 15,
		Target = "Self",
		Effect = { Kind = "MultiStat", Changes = { { Stat = "Attack", Stages = 1 }, { Stat = "Accuracy", Stages = 1 } }, Target = "Self" },
		Generic = true, LearnLevel = 15,
	},
	DisparoDeRede = {
		Name = "Disparo de Rede", Type = "Atirador", Category = "Status", Accuracy = nil, PP = 15,
		Target = "EnemySide",
		Effect = { Kind = "Hazard", Hazard = "StickyWeb" },
		Generic = true, LearnLevel = 18,
	},
	TiroDeSupressao = {
		Name = "Tiro de Supress\u{e3}o", Type = "Atirador", Category = "Damage", Power = 44, Accuracy = 95, PP = 15,
		Target = "AllEnemies",
		Effect = { Kind = "StatStage", Stat = "Speed", Stages = -1, Chance = 100, Target = "Target" },
		Generic = true, LearnLevel = 20,
	},
	DisparoRompeEscudo = {
		Name = "Disparo Rompe-Escudo", Type = "Atirador", Category = "Damage", Power = 50, Accuracy = 100, PP = 15,
		BreaksProtect = true, Generic = true, LearnLevel = 22,
	},
	BombaDeFumaca = {
		Name = "Bomba de Fuma\u{e7}a", Type = "Atirador", Category = "Status", Accuracy = 95, PP = 15,
		Target = "AllEnemies",
		Effect = { Kind = "StatStage", Stat = "Accuracy", Stages = -1, Target = "Target" },
		Generic = true, LearnLevel = 24,
	},
	MinaDeEstrepes = {
		Name = "Mina de Estrepes", Type = "Atirador", Category = "Status", Accuracy = nil, PP = 15,
		Target = "EnemySide",
		Effect = { Kind = "Hazard", Hazard = "Spikes" },
		Generic = true, LearnLevel = 28,
	},
	DardoEletrico = {
		Name = "Dardo El\u{e9}trico", Type = "Atirador", Category = "Damage", Power = 52, Accuracy = 95, PP = 15,
		Effect = { Kind = "Status", Status = "Paralysis", Chance = 30, Target = "Target" },
		Generic = true, LearnLevel = 30,
	},
	RajadaTatica = {
		Name = "Rajada T\u{e1}tica", Type = "Atirador", Category = "Damage", Power = 58, Accuracy = 95, PP = 10,
		Target = "AllEnemies", CritChance = 0.12, Generic = true, LearnLevel = 34,
	},
	DisparoDeElite = {
		Name = "Disparo de Elite", Type = "Atirador", Category = "Damage", Power = 72, Accuracy = 90, PP = 10,
		CritChance = 0.25, Generic = true, LearnLevel = 38,
	},

	--------------------------------------------------------------------
	-- Golpes Genericos Universais (10 genericos taticos para qualquer classe)
	--------------------------------------------------------------------
	AtaqueRapido = {
		Name = "Ataque R\u{e1}pido", Type = "Universal", Category = "Damage", Power = 35, Accuracy = 100, PP = 30,
		Priority = 1, Generic = true, LearnLevel = 6,
	},
	Proteger = {
		Name = "Proteger", Type = "Universal", Category = "Status", Accuracy = nil, PP = 10,
		Priority = 4, Target = "Self",
		Effect = { Kind = "Protect" },
		Generic = true, LearnLevel = 10,
	},
	OlharIntimidador = {
		Name = "Olhar Intimidador", Type = "Universal", Category = "Status", Accuracy = 100, PP = 20,
		Target = "AllEnemies",
		Effect = { Kind = "StatStage", Stat = "Attack", Stages = -1, Target = "Target" },
		Generic = true, LearnLevel = 12,
	},
	GuardaAmpla = {
		Name = "Guarda Ampla", Type = "Universal", Category = "Status", Accuracy = nil, PP = 10,
		Priority = 3, Target = "Self",
		Effect = { Kind = "WideProtect" },
		Generic = true, LearnLevel = 16,
	},
	VenenoPuro = {
		Name = "Veneno Puro", Type = "Universal", Category = "Status", Accuracy = 90, PP = 15,
		Effect = { Kind = "Status", Status = "Poison", Chance = 100, Target = "Target" },
		Generic = true, LearnLevel = 16,
	},
	Agilidade = {
		Name = "Agilidade", Type = "Universal", Category = "Status", Accuracy = nil, PP = 20,
		Target = "Self",
		Effect = { Kind = "StatStage", Stat = "Speed", Stages = 2, Target = "Self" },
		Generic = true, LearnLevel = 18,
	},
	Desobstruir = {
		Name = "Desobstruir", Type = "Universal", Category = "Status", Accuracy = nil, PP = 15,
		Target = "Self",
		Effect = { Kind = "ClearHazards", Scope = "All" },
		Generic = true, LearnLevel = 18,
	},
	VentoAFavor = {
		Name = "Vento a Favor", Type = "Universal", Category = "Status", Accuracy = nil, PP = 15,
		Target = "Self",
		Effect = { Kind = "SideEffect", SideEffect = "Tailwind", Turns = 4 },
		Generic = true, LearnLevel = 20,
	},
	MuralhaDeFerro = {
		Name = "Muralha de Ferro", Type = "Universal", Category = "Status", Accuracy = nil, PP = 15,
		Target = "Self",
		Effect = { Kind = "StatStage", Stat = "Defense", Stages = 2, Target = "Self" },
		Generic = true, LearnLevel = 22,
	},
	Recuperacao = {
		Name = "Recupera\u{e7}\u{e3}o", Type = "Universal", Category = "Status", Accuracy = nil, PP = 10,
		Target = "Self",
		Effect = { Kind = "Heal", Fraction = 0.5, Target = "Self" },
		Generic = true, LearnLevel = 24,
	},

	--------------------------------------------------------------------
	-- Golpes Classicos e Tecnicas Assinatura Existentes (preservados para saves)
	--------------------------------------------------------------------
	-- Kaen (Espadachim)
	CorteFlamejante = { Name = "Corte Flamejante", Type = "Espadachim", Category = "Damage", Power = 50, Accuracy = 100, PP = 20 },
	Investida = { Name = "Investida", Type = "Lutador", Category = "Damage", Power = 40, Accuracy = 100, PP = 30 },
	BrasaViva = {
		Name = "Brasa Viva", Type = "Mago", Category = "Damage", Power = 35, Accuracy = 100, PP = 15,
		Target = "AllEnemies",
		Effect = { Kind = "Status", Status = "Burn", Chance = 30, Target = "Target" },
	},

	-- Raiko / Eletricos
	Descarga = { Name = "Descarga", Type = "Mago", Category = "Damage", Power = 50, Accuracy = 100, PP = 20, Target = "AllEnemies" },
	PunhoDeMare = { Name = "Punho de Mar\u{e9}", Type = "Lutador", Category = "Damage", Power = 40, Accuracy = 95, PP = 15 },
	Estatica = {
		Name = "Est\u{e1}tica", Type = "Mago", Category = "Status", Accuracy = 90, PP = 15,
		Effect = { Kind = "Status", Status = "Paralysis", Chance = 100, Target = "Target" },
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
	Esforco = { Name = "Esfor\u{e7}o", Type = "Universal", Category = "Damage", Power = 30, Accuracy = 100, PP = 0, Hidden = true },
}

-- Kit generico padrao por classe (herdado automaticamente por novos personagens sem Learnset proprio)
Moves.ClassDefaults = {
	Espadachim = {
		{ Level = 1, Move = "CorteBasico" },
		{ Level = 1, Move = "CorteCruzado" },
		{ Level = 5, Move = "PosturaDaLamina" },
		{ Level = 10, Move = "CorteGiratorio" },
	},
	Lutador = {
		{ Level = 1, Move = "SocoDireto" },
		{ Level = 1, Move = "ComboMarcial" },
		{ Level = 5, Move = "PosturaDeCombate" },
		{ Level = 10, Move = "QuebraGuarda" },
	},
	Mago = {
		{ Level = 1, Move = "EsferaArcana" },
		{ Level = 1, Move = "ChamaMistica" },
		{ Level = 5, Move = "SeloParalisante" },
		{ Level = 10, Move = "OndaArcana" },
	},
	Atirador = {
		{ Level = 1, Move = "DisparoPreciso" },
		{ Level = 1, Move = "TiroPerfurante" },
		{ Level = 5, Move = "MiraFirme" },
		{ Level = 10, Move = "ChuvaDeProjeteis" },
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

-- Retorna o Learnset padrao de uma classe (opcionalmente adicionando tecnica assinatura)
function Moves.ClassKit(classId: string, signatureMoveId: string?)
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
			table.insert(out, { Level = 10, Move = signatureMoveId })
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

return Moves
