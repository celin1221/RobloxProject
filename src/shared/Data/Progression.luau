--[[
	Progression (GDD secoes 4 e 7)
	Niveis 1 a 50; por nivel +3 HP e +1 em Ataque, Defesa e Velocidade (Characters.StatsAt).
	XP por vitoria. Curva em 2 fases para manter o inicio agil e dar peso real aos niveis finais (42-50):
	  Nv. 1..15:  XP para passar do nivel N ao N+1 = 10 * N
	  Nv. 16..49: XP para passar do nivel N ao N+1 = floor(10 * N + 1.8 * (N - 15)^2)
	  XP por vitoria = 3 x soma dos niveis dos inimigos, para cada personagem do time que entrou em campo
	  Beneficio XP em Dobro (GDD secao 9) multiplica por 2
]]

local Characters = require(script.Parent:WaitForChild("Characters"))
local Summon = require(script.Parent:WaitForChild("Summon"))
local Genetics = require(script.Parent:WaitForChild("Genetics"))

local Progression = {}
Progression.Genetics = Genetics

Progression.MaxLevel = 50
Progression.StarterLevel = 5
Progression.XpPerEnemyLevel = 3
Progression.BenchXpRatio = 0.40 -- 40% do XP da vitoria compartilhado com o banco vivo (facilita montar times 2x2)
Progression.MaxActiveMoves = 4

-- Kit inicial entregue ao escolher o 1o parceiro (sem gemas: gemas seguem raras)
Progression.StarterKit = {
	Gold = 600,
	Items = {
		Pocao = 3,
		SeloContrato = 3,
	},
}

function Progression.XpToNext(level: number): number
	if level >= Progression.MaxLevel then
		return 0
	end
	if level <= 15 then
		return 10 * level
	end
	return math.floor(10 * level + 1.8 * (level - 15) ^ 2)
end

function Progression.VictoryXp(enemyLevels: { number }, doubleXp: boolean?): number
	local sum = 0
	for _, lv in ipairs(enemyLevels) do
		sum += lv
	end
	return Progression.XpPerEnemyLevel * sum * (if doubleXp then 2 else 1)
end

-- Multiplicador base de um membro salvo: estrelas (+5% cada) e variante
function Progression.MemberMultiplier(m): number
	local variantBonus = (m.Variant and Characters.VariantBonus and Characters.VariantBonus[m.Variant]) or 0
	return Summon.StarMultiplier(m.Stars) * (1 + variantBonus)
end

-- Multiplicadores finais por atributo (estrelas, variante, Genetica e Treino)
function Progression.MemberMultipliers(m)
	local baseMult = Progression.MemberMultiplier(m)
	local statMults = Genetics.MultipliersFor(m and m.Genetics, m and m.Training)
	for _, stat in ipairs(Genetics.Stats) do
		statMults[stat] *= baseMult
	end
	return statMults
end

-- Atributos finais de um membro salvo (mesma conta da batalha)
function Progression.MemberStats(m)
	local stats = Characters.StatsAt(m.CharacterId, m.Level)
	local mults = Progression.MemberMultipliers(m)
	for k, v in pairs(stats) do
		local mult = mults[k] or 1
		if mult ~= 1 then
			stats[k] = math.max(1, math.floor(v * mult + 0.5))
		end
	end
	return stats
end

-- Detalhamento completo para HUD de inspecao e grafico de radar
function Progression.StatBreakdown(m)
	local baseStats = Characters.StatsAt(m.CharacterId, m.Level)
	local gen = Genetics.SanitizeTable(m and m.Genetics)
	local trn = Genetics.SanitizeTable(m and m.Training)
	local baseMult = Progression.MemberMultiplier(m)
	local mults = Progression.MemberMultipliers(m)
	local stats = {}
	local totalBase, totalFinal = 0, 0
	for _, stat in ipairs(Genetics.Stats) do
		local b = baseStats[stat] or 0
		local mult = mults[stat] or baseMult
		local final = if mult ~= 1 then math.max(1, math.floor(b * mult + 0.5)) else b
		local g = gen[stat]
		local t = trn[stat]
		stats[stat] = {
			Base = b,
			Genetics = g,
			Training = t,
			GeneticsBonusPct = Genetics.GeneticsMaxBonus * (g / Genetics.Max) * 100,
			TrainingBonusPct = Genetics.TrainingMaxBonus * (t / Genetics.Max) * 100,
			Multiplier = mult,
			Final = final,
		}
		totalBase += b
		totalFinal += final
	end
	return {
		Stats = stats,
		Genetics = gen,
		Training = trn,
		GeneticsAvg = Genetics.Average(gen),
		TrainingAvg = Genetics.Average(trn),
		IsPerfectGenetics = Genetics.IsPerfect(gen),
		BaseMultiplier = baseMult,
		TotalBase = totalBase,
		TotalFinal = totalFinal,
	}
end

-- HP atual salvo (nil = cheio)
function Progression.CurrentHp(m): (number, number)
	local max = Progression.MemberStats(m).HP
	return if m.Hp == nil then max else math.clamp(m.Hp, 0, max), max
end

return Progression
