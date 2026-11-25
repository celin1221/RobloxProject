--[[
	DamageCalc (GDD secao 5)
	Formula de dano, estagios de atributo, regras de status e modificadores de Passivas. Modulo Core compartilhado.

	Dano = ((2*Nivel/5 + 2) * Poder * Ataque/Defesa / 50 + 2) * Bonus * Tipo * Critico * Sorte
	  Bonus   1,5 se o golpe e do mesmo tipo do personagem, senao 1
	  Tipo    2 / 0,5 / 1 (TypeChart)
	  Critico 1,5 com 6,25% de chance (ou modificado por Passiva)
	  Sorte   aleatorio entre 0,85 e 1,00
	O resultado e arredondado para o inteiro mais proximo (minimo 1).
	Conferencia do GDD: Corte Flamejante de Kaen em Raiko = 12 a 14.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = ReplicatedStorage:WaitForChild("Data")
local TypeChart = require(Data:WaitForChild("TypeChart"))
local Passives = require(Data:WaitForChild("Passives"))

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

local function passiveEffect(battler)
	if not battler or not battler.PassiveId then
		return nil, nil
	end
	local p = Passives.Get(battler.PassiveId)
	return p and p.Effect or nil, p
end

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

-- Atributo em uso agora: base x estagio x status x passiva
function DamageCalc.EffectiveStat(battler, stat: string, ignorePositiveStages: boolean?): number
	local stage = battler.Stages[stat] or 0
	if ignorePositiveStages and stage > 0 then
		stage = 0
	end
	local value = battler.Stats[stat] * DamageCalc.StageMultiplier(stage)
	local eff = passiveEffect(battler)
	if stat == "Attack" then
		if battler.Status == "Burn" and not (eff and eff.IgnoreBurnAttackPenalty) then
			value *= DamageCalc.STATUS.Burn.AttackMultiplier
		end
		if battler.Status ~= nil and eff and eff.StatusAttackMult then
			value *= eff.StatusAttackMult
		end
	elseif stat == "Speed" then
		if battler.Status == "Paralysis" then
			value *= DamageCalc.STATUS.Paralysis.SpeedMultiplier
		end
		if eff and eff.SpeedMult then
			value *= eff.SpeedMult
		end
	end
	return value
end

-- Parte fixa da formula (sem Bonus, Tipo, Critico e Sorte)
function DamageCalc.Base(level: number, power: number, attack: number, defense: number): number
	return (2 * level / 5 + 2) * power * attack / defense / 50 + 2
end

-- Calcula multiplicadores de passiva do atacante e defensor (compartilhado por Compute e ExpectedDamage)
local function computePassiveMods(attacker, defender, move, spread: number, opts)
	local aEff, aDef = passiveEffect(attacker)
	local dEff, dDef = passiveEffect(defender)
	local atkMult = 1
	local defMult = 1
	local triggers = {}

	-- Tremor dos Mares: golpes em area ignoram penalidade de spread no 2x2
	if spread < 1 and aEff and aEff.NoSpreadPenalty then
		spread = 1
		table.insert(triggers, { Who = "Attacker", Passive = aDef })
	end

	-- Bonus de dano por classe (Petalas Infinitas / Mestre dos Elementos)
	if aEff and aEff.ClassDamageBonus and move.Type == aEff.ClassDamageBonus.Type then
		atkMult *= aEff.ClassDamageBonus.Mult
	end

	-- Bonus de dano com HP baixo (Chama Interior / Manto da Raposa)
	local aMaxHp = math.max(1, attacker.MaxHp or (attacker.Stats and attacker.Stats.HP) or 1)
	local aHp = attacker.Hp or aMaxHp
	local aRatio = aHp / aMaxHp
	if aEff and aEff.LowHpThreshold and aEff.LowHpDamageMult and aRatio < aEff.LowHpThreshold then
		atkMult *= aEff.LowHpDamageMult
		table.insert(triggers, { Who = "Attacker", Passive = aDef })
	end

	-- Bonus condicional de classe com HP baixo ou apos despertar em batalha (Vontade de D)
	if aEff and aEff.LowHpClassBonus and move.Type == aEff.LowHpClassBonus.Type then
		if aRatio < aEff.LowHpClassBonus.Below or attacker.AwakenTriggered == true then
			atkMult *= aEff.LowHpClassBonus.Mult
			table.insert(triggers, { Who = "Attacker", Passive = aDef })
		end
	end

	-- Bonus de dano com HP alto (Tremor dos Mares)
	if aEff and aEff.HighHpThreshold and aEff.HighHpDamageMult and aRatio > aEff.HighHpThreshold then
		atkMult *= aEff.HighHpDamageMult
	end

	-- Mente Tatica: +20% de dano se agir depois do alvo no turno
	if aEff and aEff.MoveLastDamageMult and opts and opts.TargetActedThisTurn == true then
		atkMult *= aEff.MoveLastDamageMult
		table.insert(triggers, { Who = "Attacker", Passive = aDef })
	end

	-- Espirito Guerreiro: registra ativacao quando bate sob status
	if aEff and aEff.StatusAttackMult and attacker.Status ~= nil then
		table.insert(triggers, { Who = "Attacker", Passive = aDef })
	end

	-- Ignorar buffs positivos de Defesa do defensor (Petalas Infinitas)
	local ignorePosDef = aEff ~= nil and aEff.IgnorePositiveDefStages == true
	if ignorePosDef and defender.Stages and (defender.Stages.Defense or 0) > 0 then
		table.insert(triggers, { Who = "Attacker", Passive = aDef })
	end

	-- Infinito Absoluto: reduz dano recebido em 50% com HP cheio
	local dMaxHp = math.max(1, defender.MaxHp or (defender.Stats and defender.Stats.HP) or 1)
	local dHp = defender.Hp or dMaxHp
	if dEff and dEff.FullHpDamageTakenMult and dHp >= dMaxHp then
		defMult *= dEff.FullHpDamageTakenMult
		table.insert(triggers, { Who = "Defender", Passive = dDef })
	end

	-- Escudo Natural: reduz dano de golpes em area
	if dEff and dEff.SpreadDefenseMult and opts and opts.IsSpread == true then
		defMult *= dEff.SpreadDefenseMult
		table.insert(triggers, { Who = "Defender", Passive = dDef })
	end

	local critBonus = (aEff and aEff.CritChanceBonus) or 0
	local critMult = (aEff and aEff.CritMult) or DamageCalc.CRIT_MULTIPLIER

	return spread, atkMult, defMult, ignorePosDef, critBonus, critMult, triggers
end

-- Dano real de um golpe. Retorna { Damage, Crit, TypeMultiplier, SameType, Spread, Triggers }
-- spreadMult (opcional): 0.75 em golpes de area no 2x2 quando atingem 2+ alvos (padrao 1)
-- barrierMult (opcional): reducao de dano de barreira ativa no lado defensor (padrao 1; critico ignora barreira)
function DamageCalc.Compute(attacker, defender, move, rng: Random, spreadMult: number?, barrierMult: number?, opts)
	local typeMult = TypeChart.Multiplier(move.Type, defender.Type)
	local sameType = move.Type == attacker.Type
	local bonus = sameType and DamageCalc.SAME_TYPE_BONUS or 1
	local baseSpread = if typeof(spreadMult) == "number" then spreadMult else 1
	local spread, atkMult, defMult, ignorePosDef, critBonus, critMult, triggers =
		computePassiveMods(attacker, defender, move, baseSpread, opts)

	local critChance = (if typeof(move.CritChance) == "number" then move.CritChance else DamageCalc.CRIT_CHANCE) + critBonus
	local crit = rng:NextNumber() < critChance
	local barrier = if (not crit) and typeof(barrierMult) == "number" then barrierMult else 1
	local luck = rng:NextNumber(DamageCalc.LUCK_MIN, DamageCalc.LUCK_MAX)

	local base = DamageCalc.Base(
		attacker.Level,
		move.Power,
		DamageCalc.EffectiveStat(attacker, "Attack", false),
		DamageCalc.EffectiveStat(defender, "Defense", ignorePosDef)
	)
	local raw = base * bonus * typeMult * spread * barrier * atkMult * defMult * (crit and critMult or 1) * luck
	local damage = if typeMult == 0 then 0 else math.max(1, math.floor(raw + 0.5))
	return {
		Damage = damage,
		Crit = crit,
		TypeMultiplier = typeMult,
		SameType = sameType,
		Spread = spread,
		Triggers = triggers,
	}
end

-- Dano medio esperado (usado pela IA). Conta precisao, critico, passivas, sorte media e spread (2x2).
function DamageCalc.ExpectedDamage(attacker, defender, move, spreadMult: number?, barrierMult: number?, opts): number
	if not move or move.Category ~= "Damage" or not move.Power then
		return 0
	end
	local typeMult = TypeChart.Multiplier(move.Type, defender.Type)
	local bonus = (move.Type == attacker.Type) and DamageCalc.SAME_TYPE_BONUS or 1
	local baseSpread = if typeof(spreadMult) == "number" then spreadMult else 1
	local spread, atkMult, defMult, ignorePosDef, critBonus, critMult =
		computePassiveMods(attacker, defender, move, baseSpread, opts)

	local barrier = if typeof(barrierMult) == "number" then barrierMult else 1
	local critChance = math.min(1, (if typeof(move.CritChance) == "number" then move.CritChance else DamageCalc.CRIT_CHANCE) + critBonus)
	local critAvg = 1 + critChance * (critMult - 1)
	local luckAvg = (DamageCalc.LUCK_MIN + DamageCalc.LUCK_MAX) / 2
	local aEff = passiveEffect(attacker)
	local accBonus = (aEff and aEff.AccuracyBonus) or 0
	local hit = math.min(1, ((move.Accuracy or 100) + accBonus) / 100)
	local base = DamageCalc.Base(
		attacker.Level,
		move.Power,
		DamageCalc.EffectiveStat(attacker, "Attack", false),
		DamageCalc.EffectiveStat(defender, "Defense", ignorePosDef)
	)
	return base * bonus * typeMult * spread * barrier * atkMult * defMult * critAvg * luckAvg * hit
end

return DamageCalc
