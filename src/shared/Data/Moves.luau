--[[
	Moves (GDD secao 4 - golpes do prototipo)
	Cada golpe e so dado. O BattleService le estes campos; para criar um golpe novo
	basta adicionar uma entrada aqui, sem mexer no codigo de batalha.

	Campos:
	  Name      nome mostrado
	  Type      id do tipo (ver TypeChart)
	  Category  "Damage" (causa dano) ou "Status" (so efeito)
	  Power     poder (so Damage)
	  Accuracy  precisao 0-100; nil = nunca erra
	  PP        usos maximos
	  Effect    efeito opcional:
	              { Kind = "Status", Status = "Burn" | "Paralysis", Chance = 0-100, Target = "Target" | "Self" }
	              { Kind = "StatStage", Stat = "Attack" | "Defense" | "Speed" | "Accuracy", Stages = n, Target = ... }
	  Anim      (opcional) nome da animacao do golpe na pasta Animations do modelo; tocada no cliente
	  Vfx       (opcional) nome do efeito em ReplicatedStorage/Vfx; tocado pelo VfxController no cliente
	  Timing    (com Anim) instantes dos marcadores Charge, Release e Impact da animacao, em segundos.
	            O servidor espera ate o Impact para mandar o dano; o cliente usa como reserva se o marcador falhar.
	  Signature true na tecnica assinatura do personagem
]]

local Moves = {}

Moves.List = {
	-- Kaen
	CorteFlamejante = { Name = "Corte Flamejante", Type = "Fogo", Category = "Damage", Power = 50, Accuracy = 100, PP = 20 },
	Investida = { Name = "Investida", Type = "Neutro", Category = "Damage", Power = 40, Accuracy = 100, PP = 30 },
	BrasaViva = {
		Name = "Brasa Viva", Type = "Fogo", Category = "Damage", Power = 35, Accuracy = 100, PP = 15,
		Effect = { Kind = "Status", Status = "Burn", Chance = 30, Target = "Target" },
	},
	-- O GDD nao define tipo para Postura de Combate; Neutro (o tipo nao afeta golpe de status)
	PosturaDeCombate = {
		Name = "Postura de Combate", Type = "Neutro", Category = "Status", Accuracy = nil, PP = 15,
		Effect = { Kind = "StatStage", Stat = "Attack", Stages = 1, Target = "Self" },
	},

	-- Raiko
	Descarga = { Name = "Descarga", Type = "Raio", Category = "Damage", Power = 50, Accuracy = 100, PP = 20 },
	SocoDireto = { Name = "Soco Direto", Type = "Neutro", Category = "Damage", Power = 40, Accuracy = 100, PP = 30 },
	-- Existe para testar a vantagem de tipo (Agua contra Fogo) no prototipo
	PunhoDeMare = { Name = "Punho de Maré", Type = "Agua", Category = "Damage", Power = 40, Accuracy = 95, PP = 15 },
	-- O GDD nao define tipo para Estatica; Raio (so usado na cor do botao)
	Estatica = {
		Name = "Estática", Type = "Raio", Category = "Status", Accuracy = 90, PP = 15,
		Effect = { Kind = "Status", Status = "Paralysis", Chance = 100, Target = "Target" },
	},

	-- Yomogi (Natureza, skill personagem-anime-roblox)
	GaiolaDeEspinhos = {
		Name = "Gaiola de Espinhos", Type = "Natureza", Category = "Damage", Power = 50, Accuracy = 100, PP = 20,
		Signature = true, Anim = "GaiolaDeEspinhos", Vfx = "GaiolaDeEspinhos",
		Timing = { Charge = 0.15, Release = 0.72, Impact = 1.05, Length = 1.5 },
	},
	Arranhao = {
		Name = "Arranhão", Type = "Neutro", Category = "Damage", Power = 40, Accuracy = 100, PP = 30,
		Anim = "Arranhao", Vfx = "Arranhao",
		Timing = { Charge = 0.1, Release = 0.26, Impact = 0.3, Length = 0.6 },
	},
	SementeToxica = {
		Name = "Semente Tóxica", Type = "Natureza", Category = "Damage", Power = 35, Accuracy = 100, PP = 15,
		Effect = { Kind = "Status", Status = "Poison", Chance = 30, Target = "Target" },
		Anim = "SementeToxica", Vfx = "SementeToxica",
		Timing = { Charge = 0.12, Release = 0.38, Impact = 0.62, Length = 0.8 },
	},
	CascaDeCarvalho = {
		Name = "Casca de Carvalho", Type = "Natureza", Category = "Status", Accuracy = nil, PP = 15,
		Effect = { Kind = "StatStage", Stat = "Defense", Stages = 1, Target = "Self" },
		Anim = "CascaDeCarvalho", Vfx = "CascaDeCarvalho",
		Timing = { Charge = 0.12, Release = 0.45, Impact = 0.48, Length = 0.85 },
	},

	-- Setero (Luz, Lendario)
	Atracao = {
		Name = "Atração", Type = "Luz", Category = "Damage", Power = 45, Accuracy = 100, PP = 25,
		Anim = "Atracao", Vfx = "Atracao",
		Timing = { Charge = 0.20, Release = 0.55, Impact = 0.90, Length = 1.25 },
	},
	TudoRoxo = {
		Name = "Tudo Roxo", Type = "Luz", Category = "Damage", Power = 65, Accuracy = 95, PP = 10,
		Signature = true, CutIn = true, Anim = "TudoRoxo", Vfx = "TudoRoxo",
		Timing = { Charge = 0.25, Release = 0.95, Impact = 1.45, Length = 2.00 },
	},

	-- San (Luz, Lendario - lutador marcial de Ki)
	Kamehameha = {
		Name = "Kamehameha", Type = "Luz", Category = "Damage", Power = 55, Accuracy = 100, PP = 15,
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
		Name = "Genki Dama", Type = "Luz", Category = "Damage", Power = 70, Accuracy = 95, PP = 10,
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
	ComboMarcial = {
		Name = "Combo Marcial", Type = "Neutro", Category = "Damage", Power = 40, Accuracy = 100, PP = 30,
		Anim = "ComboMarcial", Vfx = "ComboMarcial", AnimSpeed = 2.6,
		Timing = { Charge = 0.12, Release = 0.54, Impact = 1.15, Length = 1.52 },
	},
	CargaDeKi = {
		Name = "Carga de Ki", Type = "Luz", Category = "Status", Accuracy = nil, PP = 15,
		Effect = { Kind = "StatStage", Stat = "Attack", Stages = 1, Target = "Self" },
		Anim = "CargaDeKi", Vfx = "CargaDeKi", AnimSpeed = 2.6,
		Timing = { Charge = 0.12, Release = 0.90, Impact = 1.00, Length = 1.52 },
	},

	-- Barba Branca (Agua, Lendario - O Homem que Abala os Mares)
	SocoSismico = {
		Name = "Soco Sísmico", Type = "Agua", Category = "Damage", Power = 55, Accuracy = 100, PP = 15,
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
		Name = "Abalo do Céu e da Terra", Type = "Agua", Category = "Damage", Power = 75, Accuracy = 90, PP = 10,
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
		Name = "Corte Murakumo", Type = "Neutro", Category = "Damage", Power = 45, Accuracy = 100, PP = 25,
		Anim = "CorteMurakumo", Vfx = "CorteMurakumo", AnimSpeed = 1.35,
		Timing = { Charge = 0.22, Release = 0.85, Impact = 1.15, Length = 1.46 },
	},
	HakiDoConquistador = {
		Name = "Haki do Conquistador", Type = "Trevas", Category = "Status", Accuracy = nil, PP = 15,
		Effect = { Kind = "StatStage", Stat = "Attack", Stages = 1, Target = "Self" },
		Anim = "HakiDoConquistador", Vfx = "HakiDoConquistador", AnimSpeed = 1.35,
		Timing = { Charge = 0.12, Release = 0.45, Impact = 0.55, Length = 1.46 },
	},

	-- Fora do GDD: golpe reserva usado so quando todos os golpes estao sem PP
	Esforco = { Name = "Esforço", Type = "Neutro", Category = "Damage", Power = 30, Accuracy = 100, PP = 0, Hidden = true },
}

Moves.FALLBACK_ID = "Esforco"

-- Preenche o Id de cada golpe a partir da chave
for id, move in pairs(Moves.List) do
	move.Id = id
end

function Moves.Get(id: string)
	return Moves.List[id]
end

return Moves
