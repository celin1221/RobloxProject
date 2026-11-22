--[[
	Genetics (GDD secao 4 - Genetica e Treino / equivalentes a IVs e EVs)
	Dados estaticos e funcoes puras. Nao guarda estado e nao chama APIs de servidor.

	Escala de 0 a 100 (porcentagem inteira) em cada um dos 4 atributos:
	  HP, Attack, Defense, Speed.

	Impacto nos atributos finais em batalha:
	  Genetica 0..100 -> +0% ate +40% no atributo correspondente
	  Treino   0..100 -> +0% ate +30% no atributo correspondente
	  Multiplicador combinado = 1 + 0.40*(Gen/100) + 0.30*(Treino/100)
	  (0/0 = 1.00x; 100/100 = 1.70x; Torre PvE 70/100 = 1.58x).

	Distribuicao da Genetica ao surgir um personagem:
	  Curva de Kumaraswamy F(x) = 1 - (1 - x^a)^b por raridade (quanto maior a raridade,
	  maior a media esperada, mas sempre aleatorio e sem garantia) + chance muito baixa de
	  "Prodigio 100%" (100 em todos os 4 atributos) em todas as raridades.
	Treino sempre inicia em 0 em todos os atributos (exceto NPCs da Torre PvE).
]]

local Genetics = {}

Genetics.Stats = { "HP", "Attack", "Defense", "Speed" }

Genetics.StatLabels = {
	HP = { Name = "HP", Short = "HP" },
	Attack = { Name = "Ataque", Short = "ATQ" },
	Defense = { Name = "Defesa", Short = "DEF" },
	Speed = { Name = "Velocidade", Short = "VEL" },
}

Genetics.Min = 0
Genetics.Max = 100

Genetics.GeneticsMaxBonus = 0.40 -- +40% em Genetica 100%
Genetics.TrainingMaxBonus = 0.30 -- +30% em Treino 100%

-- NPCs PvE da Torre e Ginasios (escalado por dificuldade para curva justa do inicio ao Infinito)
Genetics.TowerPreset = {
	Genetics = 70,
	Training = 100,
}

Genetics.TowerPresets = {
	Facil = { Genetics = 25, Training = 0 },     -- 1.10x: acessivel para novatos Nv. 5-10
	Medio = { Genetics = 45, Training = 35 },    -- 1.285x: pede time organizado e treino inicial
	Dificil = { Genetics = 60, Training = 75 },  -- 1.465x: desafio real mid/late game
	Infinito = { Genetics = 70, Training = 100 }, -- 1.58x: teto endgame do GDD
}

Genetics.GymPresets = {
	[1] = { Genetics = 35, Training = 15 }, -- Konoha (1o Ginasio): 1.185x
	[2] = { Genetics = 50, Training = 45 }, -- Grand Line (2o Ginasio): 1.335x
	[3] = { Genetics = 65, Training = 75 }, -- Soul Society (3o Ginasio): 1.485x
}

-- Parametros por raridade:
-- A, B -> curva de Kumaraswamy para cada atributo individual
-- PerfectAllChance -> probabilidade rara de nascer 100/100/100/100 (100% perfeito)
Genetics.RarityCurves = {
	Comum = { A = 1.10, B = 2.00, PerfectAllChance = 0.00005, ExpectedAvg = 36 },
	Raro = { A = 1.70, B = 1.65, PerfectAllChance = 0.00012, ExpectedAvg = 53 },
	Epico = { A = 2.35, B = 1.35, PerfectAllChance = 0.00025, ExpectedAvg = 65 },
	Lendario = { A = 3.15, B = 1.15, PerfectAllChance = 0.00050, ExpectedAvg = 74 },
}

local function clampStat(v: number?): number
	if typeof(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
		return 0
	end
	return math.clamp(math.floor(v + 0.5), Genetics.Min, Genetics.Max)
end

function Genetics.ZeroTable()
	return { HP = 0, Attack = 0, Defense = 0, Speed = 0 }
end

function Genetics.UniformTable(value: number)
	local v = clampStat(value)
	return { HP = v, Attack = v, Defense = v, Speed = v }
end

function Genetics.SanitizeTable(tbl)
	local out = Genetics.ZeroTable()
	if typeof(tbl) ~= "table" then
		return out
	end
	for _, stat in ipairs(Genetics.Stats) do
		out[stat] = clampStat(tbl[stat])
	end
	return out
end

function Genetics.CloneTable(tbl)
	return Genetics.SanitizeTable(tbl)
end

function Genetics.HasAllKeys(tbl): boolean
	if typeof(tbl) ~= "table" then
		return false
	end
	for _, stat in ipairs(Genetics.Stats) do
		if typeof(tbl[stat]) ~= "number" then
			return false
		end
	end
	return true
end

function Genetics.Total(tbl): number
	if typeof(tbl) ~= "table" then
		return 0
	end
	local sum = 0
	for _, stat in ipairs(Genetics.Stats) do
		sum += clampStat(tbl[stat])
	end
	return sum
end

function Genetics.Average(tbl): number
	return Genetics.Total(tbl) / #Genetics.Stats
end

function Genetics.IsPerfect(tbl): boolean
	if typeof(tbl) ~= "table" then
		return false
	end
	for _, stat in ipairs(Genetics.Stats) do
		if clampStat(tbl[stat]) < Genetics.Max then
			return false
		end
	end
	return true
end

function Genetics.Grade(tbl): (string, string)
	if Genetics.IsPerfect(tbl) then
		return "S+", "gold"
	end
	local avg = Genetics.Average(tbl)
	if avg >= 85 then
		return "S", "lendario"
	elseif avg >= 70 then
		return "A", "epico"
	elseif avg >= 50 then
		return "B", "raro"
	elseif avg >= 30 then
		return "C", "green"
	end
	return "D", "comum"
end

function Genetics.StatBonusMultiplier(genValue: number?, trainValue: number?): number
	local g = clampStat(genValue) / Genetics.Max
	local t = clampStat(trainValue) / Genetics.Max
	return 1 + Genetics.GeneticsMaxBonus * g + Genetics.TrainingMaxBonus * t
end

function Genetics.MultipliersFor(genTbl, trainTbl)
	local out = {}
	for _, stat in ipairs(Genetics.Stats) do
		local g = if typeof(genTbl) == "table" then genTbl[stat] else 0
		local t = if typeof(trainTbl) == "table" then trainTbl[stat] else 0
		out[stat] = Genetics.StatBonusMultiplier(g, t)
	end
	return out
end

-- Sorteia um atributo individual pela inversa da CDF de Kumaraswamy:
--   x = (1 - (1 - u)^(1/b))^(1/a), mapeado em [0..100].
local function rollSingle(a: number, b: number, rng: Random?): number
	local u = if rng then rng:NextNumber() else math.random()
	-- evita u = 1 exato causar raiz negativa/NaN por ponto flutuante
	u = math.clamp(u, 0, 0.9999999)
	local x = (1 - (1 - u) ^ (1 / b)) ^ (1 / a)
	return math.clamp(math.floor(x * 101), Genetics.Min, Genetics.Max)
end

-- Sorteia os 4 atributos geneticos conforme a raridade do personagem.
-- Mesma formula usada no Gacha, na Forja Pessoal (Refugio) e em encontros/inicial.
function Genetics.Roll(rarity: string?, rng: Random?)
	local cfg = Genetics.RarityCurves[rarity or "Comum"] or Genetics.RarityCurves.Comum
	local jackpot = if rng then rng:NextNumber() else math.random()
	if jackpot < cfg.PerfectAllChance then
		return Genetics.UniformTable(Genetics.Max)
	end
	local out = {}
	for _, stat in ipairs(Genetics.Stats) do
		out[stat] = rollSingle(cfg.A, cfg.B, rng)
	end
	return out
end

function Genetics.TowerEnemyPreset(modeId: string?)
	local p = (modeId and Genetics.TowerPresets[modeId]) or Genetics.TowerPreset
	return Genetics.UniformTable(p.Genetics), Genetics.UniformTable(p.Training)
end

function Genetics.GymEnemyPreset(tierIndex: number?)
	local idx = math.clamp(math.floor(tierIndex or 1), 1, #Genetics.GymPresets)
	local p = Genetics.GymPresets[idx] or Genetics.TowerPreset
	return Genetics.UniformTable(p.Genetics), Genetics.UniformTable(p.Training)
end

return Genetics
