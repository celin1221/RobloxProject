--[[
	Progression (GDD secoes 4 e 7)
	Niveis 1 a 50; por nivel +3 HP e +1 em Ataque, Defesa e Velocidade (Characters.StatsAt).
	XP por vitoria. O GDD nao define a curva nem a quantidade de XP; foi usado o mais simples
	(registrado em PROGRESSO.md):
	  XP para passar do nivel N ao N+1 = 10 x N
	  XP por vitoria = 3 x soma dos niveis dos inimigos, para cada personagem do time que entrou em campo
	  Beneficio XP em Dobro (GDD secao 9) multiplica por 2
]]

local Characters = require(script.Parent:WaitForChild("Characters"))
local Summon = require(script.Parent:WaitForChild("Summon"))

local Progression = {}

Progression.MaxLevel = 50
Progression.StarterLevel = 5
Progression.XpPerEnemyLevel = 3
Progression.MaxActiveMoves = 4

function Progression.XpToNext(level: number): number
	if level >= Progression.MaxLevel then
		return 0
	end
	return 10 * level
end

function Progression.VictoryXp(enemyLevels: { number }, doubleXp: boolean?): number
	local sum = 0
	for _, lv in ipairs(enemyLevels) do
		sum += lv
	end
	return Progression.XpPerEnemyLevel * sum * (if doubleXp then 2 else 1)
end

-- Multiplicador de atributos de um membro salvo: estrelas (+5% cada) e variante
function Progression.MemberMultiplier(m): number
	local variantBonus = (m.Variant and Characters.VariantBonus and Characters.VariantBonus[m.Variant]) or 0
	return Summon.StarMultiplier(m.Stars) * (1 + variantBonus)
end

-- Atributos finais de um membro salvo (mesma conta da batalha)
function Progression.MemberStats(m)
	local stats = Characters.StatsAt(m.CharacterId, m.Level)
	local mult = Progression.MemberMultiplier(m)
	if mult ~= 1 then
		for k, v in pairs(stats) do
			stats[k] = math.max(1, math.floor(v * mult + 0.5))
		end
	end
	return stats
end

-- HP atual salvo (nil = cheio)
function Progression.CurrentHp(m): (number, number)
	local max = Progression.MemberStats(m).HP
	return if m.Hp == nil then max else math.clamp(m.Hp, 0, max), max
end

return Progression
