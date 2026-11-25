--[[
	Passives (Camada 1 - Data): catalogo de Passivas (habilidades inatas estilo Pokemon).
	- Generic: pool reutilizavel em escala para Comuns, Raros e Epicos antes do Despertar.
	- Unique:  passivas exclusivas de Lendarios (e futuras raridades acima).
	- Secret:  passivas exclusivas desbloqueadas ao evoluir/despertar Epicos na Maquina Secreta (Nv. 35+).

	Regras declarativas em `Effect` sao executadas de forma pura por Core/DamageCalc e Core/BattleEngine.
]]

local Passives = {}

Passives.TierLabels = {
	Generic = "Comum",
	Unique = "Única",
	Secret = "Secreta",
}

Passives.TierColors = {
	Generic = Color3.fromRGB(110, 185, 255),
	Unique = Color3.fromRGB(255, 200, 70),
	Secret = Color3.fromRGB(245, 110, 255),
}

Passives.List = {
	--------------------------------------------------------------------
	-- 12 PASSIVAS GENERICAS (estilo Pokemon — escalaveis para novos personagens)
	--------------------------------------------------------------------
	OlhoDeAguia = {
		Name = "Olho de Águia",
		Tier = "Generic",
		Short = "+10% Precisão · Imune a queda de Precisão",
		Description = "A Precisão não pode ser reduzida por inimigos e todos os golpes ganham +10% de precisão final.",
		Effect = {
			AccuracyBonus = 10,
			BlockStatDrop = { Accuracy = true },
		},
	},
	Intimidacao = {
		Name = "Intimidação",
		Tier = "Generic",
		Short = "Ao entrar: -1 Ataque nos inimigos",
		Description = "Ao entrar em campo, intimida todos os adversários reduzindo o Ataque deles em 1 estágio.",
		Effect = {
			OnEnterDebuff = { Stat = "Attack", Stages = -1 },
		},
	},
	Firmeza = {
		Name = "Firmeza",
		Tier = "Generic",
		Short = "Sobrevive com 1 HP se estiver com HP cheio",
		Description = "Enquanto estiver com 100% de HP, resiste a qualquer golpe fatal ficando com 1 HP (1x por entrada em campo).",
		Effect = {
			Sturdy = true,
		},
	},
	EspiritoGuerreiro = {
		Name = "Espírito Guerreiro",
		Tier = "Generic",
		Short = "+30% Ataque sob status negativo",
		Description = "Aumenta o Ataque em +30% enquanto sofrer qualquer status negativo e ignora a penalidade de Ataque da Queimadura.",
		Effect = {
			StatusAttackMult = 1.30,
			IgnoreBurnAttackPenalty = true,
		},
	},
	ChamaInterior = {
		Name = "Chama Interior",
		Tier = "Generic",
		Short = "+25% de dano abaixo de 35% HP",
		Description = "Quando o HP cai abaixo de 35%, libera sua força interior causando +25% de dano em todos os ataques.",
		Effect = {
			LowHpThreshold = 0.35,
			LowHpDamageMult = 1.25,
		},
	},
	SedeDeVitoria = {
		Name = "Sede de Vitória",
		Tier = "Generic",
		Short = "+1 Ataque ao nocautear um inimigo",
		Description = "Sempre que derrubar um adversário com um golpe, ganha +1 estágio de Ataque.",
		Effect = {
			OnKoSelfBuff = { Stat = "Attack", Stages = 1 },
		},
	},
	MenteTatica = {
		Name = "Mente Tática",
		Tier = "Generic",
		Short = "+20% de dano se agir após o alvo",
		Description = "Analisa o movimento adversário: se atacar depois de o alvo já ter agido no turno, causa +20% de dano.",
		Effect = {
			MoveLastDamageMult = 1.20,
		},
	},
	Regeneracao = {
		Name = "Regeneração",
		Tier = "Generic",
		Short = "Recupera 6% HP ao fim de cada turno",
		Description = "Restaura continuamente 6% do HP máximo ao final de cada turno em campo.",
		Effect = {
			EndTurnHealFraction = 0.06,
		},
	},
	PassosVelozes = {
		Name = "Passos Velozes",
		Tier = "Generic",
		Short = "+15% de Velocidade em batalha",
		Description = "Agilidade superior que concede +15% de Velocidade efetiva durante toda a batalha.",
		Effect = {
			SpeedMult = 1.15,
		},
	},
	GolpeCerteiro = {
		Name = "Golpe Certeiro",
		Tier = "Generic",
		Short = "Crítico dobrado (12,5%) e dano 1,75x",
		Description = "Dobra a chance base de acerto crítico (+6,25%) e aumenta o multiplicador crítico de 1,5x para 1,75x.",
		Effect = {
			CritChanceBonus = 0.0625,
			CritMult = 1.75,
		},
	},
	EscudoNatural = {
		Name = "Escudo Natural",
		Tier = "Generic",
		Short = "-50% Hazards/Status · -12% dano em área",
		Description = "Reduz pela metade o dano de Hazards, Queimadura e Veneno, além de sofrer 12% menos dano de golpes em área.",
		Effect = {
			HazardAndDotMult = 0.50,
			SpreadDefenseMult = 0.88,
		},
	},
	ContraEspinhos = {
		Name = "Contra-Espinhos",
		Tier = "Generic",
		Short = "Devolve 10% HP em ataques corpo a corpo",
		Description = "Ao sofrer um golpe direto de Espadachim ou Lutador, fere o atacante em 10% do HP máximo dele.",
		Effect = {
			ContactReflectFraction = 0.10,
			ContactTypes = { Espadachim = true, Lutador = true },
		},
	},

	--------------------------------------------------------------------
	-- 5 PASSIVAS UNICAS (Lendarios)
	--------------------------------------------------------------------
	PetalasInfinitas = {
		Name = "Pétalas Infinitas",
		Tier = "Unique",
		Owner = "Byakuya",
		Short = "+15% dano Espadachim · Ignora buffs de Defesa",
		Description = "A chuva de pétalas concede +15% de dano em golpes de Espadachim e ignora aumentos positivos de Defesa do alvo.",
		Effect = {
			ClassDamageBonus = { Type = "Espadachim", Mult = 1.15 },
			IgnorePositiveDefStages = true,
		},
	},
	TremorDosMares = {
		Name = "Tremor dos Mares",
		Tier = "Unique",
		Owner = "BarbaBranca",
		Short = "Área 100% no 2x2 · +15% dano acima de 50% HP",
		Description = "Golpes em área no 2x2 causam 100% do dano (sem penalidade de 0,75x) e ataques causam +15% de dano acima de 50% de HP.",
		Effect = {
			NoSpreadPenalty = true,
			HighHpThreshold = 0.50,
			HighHpDamageMult = 1.15,
		},
	},
	MestreDosElementos = {
		Name = "Mestre dos Elementos",
		Tier = "Unique",
		Owner = "Sarutobi",
		Short = "+15% dano Mago · Dobro de chance de efeito",
		Description = "Domínio elemental total: golpes de Mago causam +15% de dano e têm a chance de efeitos secundários dobrada.",
		Effect = {
			ClassDamageBonus = { Type = "Mago", Mult = 1.15 },
			SecondaryChanceMult = 2.0,
		},
	},
	InstintoZenkai = {
		Name = "Instinto Zenkai",
		Tier = "Unique",
		Owner = "San",
		Short = "Abaixo de 50% HP: cura 20%, +1 ATQ e +1 VEL",
		Description = "Na primeira vez em cada batalha que cair abaixo de 50% de HP, supera seus limites curando 20% do HP e ganhando +1 Ataque e +1 Velocidade.",
		Effect = {
			ThresholdTrigger = {
				Below = 0.50,
				OncePerBattle = true,
				HealFraction = 0.20,
				Buffs = {
					{ Stat = "Attack", Stages = 1 },
					{ Stat = "Speed", Stages = 1 },
				},
			},
		},
	},
	InfinitoAbsoluto = {
		Name = "Infinito Absoluto",
		Tier = "Unique",
		Owner = "Setero",
		Short = "-50% dano com HP cheio · Imune a debuffs",
		Description = "A barreira do Infinito reduz em 50% o dano recebido enquanto estiver com 100% de HP e impede que inimigos reduzam seus atributos.",
		Effect = {
			FullHpDamageTakenMult = 0.50,
			BlockAllEnemyStatDrops = true,
		},
	},
	ReiDasMaldicoes = {
		Name = "Rei das Maldições",
		Tier = "Unique",
		Owner = "Sukuna",
		Short = "+18% dano Mago · +10% Crítico · Ignora buffs de Defesa",
		Description = "Supremacia amaldiçoada: golpes de Mago causam +18% de dano, têm +10% de chance crítica e ignoram aumentos positivos de Defesa do alvo.",
		Effect = {
			ClassDamageBonus = { Type = "Mago", Mult = 1.18 },
			CritChanceBonus = 0.10,
			IgnorePositiveDefStages = true,
		},
	},

	--------------------------------------------------------------------
	-- 3 PASSIVAS SECRETAS UNICAS (Epicos Iniciais — Despertar Nv. 35+)
	--------------------------------------------------------------------
	VontadeDeD = {
		Name = "Vontade de D",
		Tier = "Secret",
		Owner = "Luffy",
		Short = "Imune a Paralisia · <40% HP: +1 ATQ/VEL e +20% Lutador",
		Description = "Corpo de borracha imune a Paralisia. Ao cair abaixo de 40% de HP (1x por batalha), desperta ganhando +1 Ataque, +1 Velocidade e +20% de dano em golpes de Lutador.",
		Effect = {
			StatusImmune = { Paralysis = true },
			ThresholdTrigger = {
				Below = 0.40,
				OncePerBattle = true,
				Buffs = {
					{ Stat = "Attack", Stages = 1 },
					{ Stat = "Speed", Stages = 1 },
				},
			},
			LowHpClassBonus = { Below = 0.40, Type = "Lutador", Mult = 1.20 },
		},
	},
	MantoDaRaposa = {
		Name = "Manto da Raposa",
		Tier = "Secret",
		Owner = "Naruto",
		Short = "Cura 8%/turno · Imune Sono/Gelo · +25% dano <50% HP",
		Description = "Regenera 8% do HP máximo ao fim de cada turno, é imune a Sono e Congelamento, e causa +25% de dano quando estiver abaixo de 50% de HP.",
		Effect = {
			EndTurnHealFraction = 0.08,
			StatusImmune = { Sleep = true, Freeze = true },
			LowHpThreshold = 0.50,
			LowHpDamageMult = 1.25,
		},
	},
	DespertarHollow = {
		Name = "Despertar Hollow",
		Tier = "Secret",
		Owner = "Ichigo",
		Short = "+20% VEL · +10% Crítico · Nocaute: +1 ATQ e cura 15%",
		Description = "Velocidade +20% e chance de crítico +10%. Sempre que nocautear um adversário, ganha +1 estágio de Ataque e recupera 15% do HP máximo.",
		Effect = {
			SpeedMult = 1.20,
			CritChanceBonus = 0.10,
			OnKoSelfBuff = { Stat = "Attack", Stages = 1 },
			OnKoHealFraction = 0.15,
		},
	},
}

Passives.Order = {
	-- Genericas
	"OlhoDeAguia",
	"Intimidacao",
	"Firmeza",
	"EspiritoGuerreiro",
	"ChamaInterior",
	"SedeDeVitoria",
	"MenteTatica",
	"Regeneracao",
	"PassosVelozes",
	"GolpeCerteiro",
	"EscudoNatural",
	"ContraEspinhos",
	-- Unicas (Lendarios)
	"PetalasInfinitas",
	"TremorDosMares",
	"MestreDosElementos",
	"InstintoZenkai",
	"InfinitoAbsoluto",
	"ReiDasMaldicoes",
	-- Secretas (Epicos Despertos)
	"VontadeDeD",
	"MantoDaRaposa",
	"DespertarHollow",
}

for id, def in pairs(Passives.List) do
	def.Id = id
	def.Color = def.Color or Passives.TierColors[def.Tier] or Passives.TierColors.Generic
	def.TierLabel = Passives.TierLabels[def.Tier] or "Comum"
end

function Passives.Get(id: string?)
	if typeof(id) ~= "string" then
		return nil
	end
	return Passives.List[id]
end

function Passives.ListByTier(tier: string): { any }
	local out = {}
	for _, id in ipairs(Passives.Order) do
		local p = Passives.List[id]
		if p and p.Tier == tier then
			table.insert(out, p)
		end
	end
	return out
end

return Passives
