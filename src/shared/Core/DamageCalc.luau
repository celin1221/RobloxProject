--[[
	DamageCalc (GDD secao 5)
	Formula de dano, estagios de atributo e regras de status. Modulo Core compartilhado.

	Dano = ((2*Nivel/5 + 2) * Poder * Ataque/Defesa / 50 + 2) * Bonus * Tipo * Critico * Sorte
	  Bonus   1,5 se o golpe e do mesmo tipo do personagem, senao 1
	  Tipo    2 / 0,5 / 1 (TypeChart)
	  Critico 1,5 com 6,25% de chance
	  Sorte   aleatorio entre 0,85 e 1,00
	O resultado e arredondado para o inteiro mais proximo (minimo 1).
	Conferencia do GDD: Corte Flamejante de Kaen em Raiko = 12 a 14.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TypeChart = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("TypeChart"))

local DamageCalc = {}

DamageCalc.SAME_TYPE_BONUS = 1.5
DamageCalc.SPREAD_MULTIPLIER = 0.75 -- Regra Pokemon 2x2: golpes em area que atingem 2+ alvos causam 75% do dano
DamageCalc.CRIT_CHANCE = 0.0625
DamageCalc.CRIT_MULTIPLIER = 1.5
DamageCalc.LUCK_MIN = 0.85
DamageCalc.LUCK_MAX = 1.00
DamageCalc.MIN_STAGE = -6
DamageCalc.MAX_STAGE = 6

-- Regras de status (GDD secao 5). 1 status por personagem de cada vez.
DamageCalc.STATUS = {
	Burn = { Name = "Queimadura", TickFraction = 1 / 16, AttackMultiplier = 0.5 },
	Poison = { Name = "Veneno", TickFraction = 1 / 8 },
	Paralysis = { Name = "Paralisia", SkipChance = 0.25, SpeedMultiplier = 0.5 },
	Sleep = { Name = "Sono", MinTurns = 1, MaxTurns = 3 },
	Freeze = { Name = "Congelamento", ThawChance = 0.2 },
}

--[[
	Multiplicador de estagio. GDD: cada estagio positivo soma 50% do valor base
	(+1 = x1,5; +2 = x2; ... +6 = x4). O GDD nao define os negativos; usamos o
	espelho: -1 = x2/3, -2 = x1/2, ... -6 = x1/4.
]]
function DamageCalc.StageMultiplier(stage: number): number
	stage = math.clamp(stage or 0, DamageCalc.MIN_STAGE, DamageCalc.MAX_STAGE)
	if stage >= 0 then
		return 1 + 0.5 * stage
	end
	return 2 / (2 - stage)
end

-- Atributo em uso agora: base x estagio x status
function DamageCalc.EffectiveStat(battler, stat: string): number
	local value = battler.Stats[stat] * DamageCalc.StageMultiplier(battler.Stages[stat] or 0)
	if stat == "Attack" and battler.Status == "Burn" then
		value *= DamageCalc.STATUS.Burn.AttackMultiplier
	end
	if stat == "Speed" and battler.Status == "Paralysis" then
		value *= DamageCalc.STATUS.Paralysis.SpeedMultiplier
	end
	return value
end

-- Parte fixa da formula (sem Bonus, Tipo, Critico e Sorte)
function DamageCalc.Base(level: number, power: number, attack: number, defense: number): number
	return (2 * level / 5 + 2) * power * attack / defense / 50 + 2
end

-- Dano real de um golpe. Retorna { Damage, Crit, TypeMultiplier, SameType, Spread }
-- spreadMult (opcional): 0.75 em golpes de area no 2x2 quando atingem 2+ alvos (padrao 1)
function DamageCalc.Compute(attacker, defender, move, rng: Random, spreadMult: number?)
	local typeMult = TypeChart.Multiplier(move.Type, defender.Type)
	local sameType = move.Type == attacker.Type
	local bonus = sameType and DamageCalc.SAME_TYPE_BONUS or 1
	local spread = if typeof(spreadMult) == "number" then spreadMult else 1
	local critChance = if typeof(move.CritChance) == "number" then move.CritChance else DamageCalc.CRIT_CHANCE
	local crit = rng:NextNumber() < critChance
	local luck = rng:NextNumber(DamageCalc.LUCK_MIN, DamageCalc.LUCK_MAX)

	local base = DamageCalc.Base(
		attacker.Level,
		move.Power,
		DamageCalc.EffectiveStat(attacker, "Attack"),
		DamageCalc.EffectiveStat(defender, "Defense")
	)
	local raw = base * bonus * typeMult * spread * (crit and DamageCalc.CRIT_MULTIPLIER or 1) * luck
	local damage = if typeMult == 0 then 0 else math.max(1, math.floor(raw + 0.5))
	return { Damage = damage, Crit = crit, TypeMultiplier = typeMult, SameType = sameType, Spread = spread }
end

-- Dano medio esperado (usado pela IA). Conta precisao, chance de critico, sorte media e spread (2x2).
function DamageCalc.ExpectedDamage(attacker, defender, move, spreadMult: number?): number
	if move.Category ~= "Damage" then
		return 0
	end
	local typeMult = TypeChart.Multiplier(move.Type, defender.Type)
	local bonus = (move.Type == attacker.Type) and DamageCalc.SAME_TYPE_BONUS or 1
	local spread = if typeof(spreadMult) == "number" then spreadMult else 1
	local critChance = if typeof(move.CritChance) == "number" then move.CritChance else DamageCalc.CRIT_CHANCE
	local critAvg = 1 + critChance * (DamageCalc.CRIT_MULTIPLIER - 1)
	local luckAvg = (DamageCalc.LUCK_MIN + DamageCalc.LUCK_MAX) / 2
	local hit = (move.Accuracy or 100) / 100
	local base = DamageCalc.Base(
		attacker.Level,
		move.Power,
		DamageCalc.EffectiveStat(attacker, "Attack"),
		DamageCalc.EffectiveStat(defender, "Defense")
	)
	return base * bonus * typeMult * spread * critAvg * luckAvg * hit
end

return DamageCalc
