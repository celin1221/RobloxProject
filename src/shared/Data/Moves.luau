--[[
	Moves (Sistema de Golpes por Classe + Tecnicas Assinatura)
	Cada golpe e so dado. O BattleEngine/BattleService le estes campos; para criar um golpe novo
	basta adicionar uma entrada aqui, sem mexer no codigo de batalha.

	Golpes Genericos por Classe (`Moves.ClassDefaults`):
	  Todo personagem novo de uma classe (Espadachim, Lutador, Mago, Atirador) herda automaticamente
	  o kit basico da classe com animacoes compativeis (espada, punho, magia, disparo), bastando
	  adicionar suas tecnicas assinatura exclusivas quando desejar.

	Campos:
	  Name       nome mostrado
	  Type       id da classe ("Espadachim" | "Lutador" | "Mago" | "Atirador" | "Universal")
	  Category   "Damage" (causa dano) ou "Status" (so efeito)
	  Power      poder (so Damage)
	  Accuracy   precisao 0-100; nil = nunca erra
	  PP         usos maximos
	  CritChance (opcional) chance de critico propria (padrao 0.0625 em DamageCalc)
	  Effect     efeito opcional:
	               { Kind = "Status", Status = "Burn" | "Poison" | "Paralysis" | "Sleep" | "Freeze", Chance = 0-100, Target = "Target" | "Self" }
	               { Kind = "StatStage", Stat = "Attack" | "Defense" | "Speed" | "Accuracy", Stages = n, Target = ... }
	  Anim       (opcional) nome da animacao na pasta Animations do modelo; tocada no cliente
	  Vfx        (opcional) nome do efeito em ReplicatedStorage/Vfx; tocado pelo VfxController
	  Timing     (com Anim) instantes Charge, Release e Impact em segundos
	  Target     (opcional, usado no 2x2): "Single" (padrao), "AllEnemies" (0.75x em 2+ alvos),
	             "AllOthers", "AllAllies" ou "Self".
	  Generic    true nos golpes genericos compartilhados por classe
	  Signature  true na tecnica assinatura do personagem
]]

local Moves = {}

Moves.List = {
	--------------------------------------------------------------------
	-- Golpes Genericos de Classe: ESPADACHIM
	--------------------------------------------------------------------
	CorteBasico = {
		Name = "Corte R\u{e1}pido", Type = "Espadachim", Category = "Damage", Power = 40, Accuracy = 100, PP = 30,
		Generic = true,
	},
	CorteCruzado = {
		Name = "Corte Cruzado", Type = "Espadachim", Category = "Damage", Power = 52, Accuracy = 95, PP = 20,
		CritChance = 0.15, Generic = true,
	},
	CorteGiratorio = {
		Name = "Corte Girat\u{f3}rio", Type = "Espadachim", Category = "Damage", Power = 42, Accuracy = 100, PP = 15,
		Target = "AllEnemies", Generic = true,
	},
	PosturaDaLamina = {
		Name = "Postura da L\u{e2}mina", Type = "Espadachim", Category = "Status", Accuracy = nil, PP = 15,
		Effect = { Kind = "StatStage", Stat = "Attack", Stages = 1, Target = "Self" },
		Generic = true,
	},

	--------------------------------------------------------------------
	-- Golpes Genericos de Classe: LUTADOR
	--------------------------------------------------------------------
	SocoDireto = {
		Name = "Soco Direto", Type = "Lutador", Category = "Damage", Power = 40, Accuracy = 100, PP = 30,
		Generic = true,
	},
	ComboMarcial = {
		Name = "Combo Marcial", Type = "Lutador", Category = "Damage", Power = 45, Accuracy = 100, PP = 25,
		Generic = true,
		Anim = "ComboMarcial", Vfx = "ComboMarcial", AnimSpeed = 2.6,
		Timing = { Charge = 0.12, Release = 0.54, Impact = 1.15, Length = 1.52 },
	},
	QuebraGuarda = {
		Name = "Quebra-Guarda", Type = "Lutador", Category = "Damage", Power = 45, Accuracy = 95, PP = 15,
		Effect = { Kind = "StatStage", Stat = "Defense", Stages = -1, Chance = 40, Target = "Target" },
		Generic = true,
	},
	PosturaDeCombate = {
		Name = "Postura de Combate", Type = "Lutador", Category = "Status", Accuracy = nil, PP = 15,
		Effect = { Kind = "StatStage", Stat = "Attack", Stages = 1, Target = "Self" },
		Generic = true,
	},

	--------------------------------------------------------------------
	-- Golpes Genericos de Classe: MAGO
	--------------------------------------------------------------------
	EsferaArcana = {
		Name = "Esfera Arcana", Type = "Mago", Category = "Damage", Power = 42, Accuracy = 100, PP = 25,
		Generic = true,
	},
	OndaArcana = {
		Name = "Onda Arcana", Type = "Mago", Category = "Damage", Power = 45, Accuracy = 100, PP = 15,
		Target = "AllEnemies", Generic = true,
	},
	ChamaMistica = {
		Name = "Chama M\u{ed}stica", Type = "Mago", Category = "Damage", Power = 35, Accuracy = 100, PP = 15,
		Target = "AllEnemies",
		Effect = { Kind = "Status", Status = "Burn", Chance = 30, Target = "Target" },
		Generic = true,
	},
	SeloParalisante = {
		Name = "Selo Paralisante", Type = "Mago", Category = "Status", Accuracy = 90, PP = 15,
		Effect = { Kind = "Status", Status = "Paralysis", Chance = 100, Target = "Target" },
		Generic = true,
	},

	--------------------------------------------------------------------
	-- Golpes Genericos de Classe: ATIRADOR
	--------------------------------------------------------------------
	DisparoPreciso = {
		Name = "Disparo Preciso", Type = "Atirador", Category = "Damage", Power = 42, Accuracy = nil, PP = 25,
		Generic = true,
	},
	TiroPerfurante = {
		Name = "Tiro Perfurante", Type = "Atirador", Category = "Damage", Power = 52, Accuracy = 95, PP = 15,
		CritChance = 0.18, Generic = true,
	},
	ChuvaDeProjeteis = {
		Name = "Chuva de Proj\u{e9}teis", Type = "Atirador", Category = "Damage", Power = 40, Accuracy = 95, PP = 15,
		Target = "AllEnemies", Generic = true,
	},
	MiraFirme = {
		Name = "Mira Firme", Type = "Atirador", Category = "Status", Accuracy = nil, PP = 15,
		Effect = { Kind = "StatStage", Stat = "Attack", Stages = 1, Target = "Self" },
		Generic = true,
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

-- Modo de alvo do golpe (usado no 2x2): "Single" | "AllEnemies" | "AllOthers" | "AllAllies" | "Self"
function Moves.TargetMode(move): string
	if not move then
		return "Single"
	end
	if move.Target then
		return move.Target
	end
	if move.Category == "Status" and move.Effect and move.Effect.Target == "Self" then
		return "Self"
	end
	return "Single"
end

return Moves
