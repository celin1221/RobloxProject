--[[
	Tower (GDD secao 6) - valores da torre. So dados; a logica fica em ServerScriptService/Tower.

	| Modo     | Batalhas | Por NPC | Nivel inimigos   | IA      | Recompensa                                   |
	| Facil    | 3        | 2       | 5 a 10           | Facil   | 150 gold                                     |
	| Medio    | 5        | 4       | 15 a 25          | Medio   | 500 gold, 1 item                             |
	| Dificil  | 7        | 6       | 30 a 45          | Dificil | 1.500 gold, 2 itens, 5 gemas (1 vez por dia) |
	| Infinito | sem fim  | 6       | 10 + 2 por andar | Dificil | 100 gold por andar, bonus a cada 5 andares   |

	Valores que o GDD nao define (escolhido o mais simples, registrado em PROGRESSO.md):
	  itens: Medio = 1 Superpocao; Dificil = 1 Hiperpocao + 1 Reviver
	  bonus do Infinito a cada 5 andares = 500 gold
	  personagem do chefe entregue no nivel do chefe
]]

local Tower = {}

Tower.Order = { "Facil", "Medio", "Dificil", "Infinito" }

Tower.Modes = {
	Facil = {
		Name = "F\u{e1}cil", Battles = 3, TeamSize = 2, MinLevel = 5, MaxLevel = 10, AI = "Facil",
		Reward = { Gold = 300, Items = { "DoceComum" } },
	},
	Medio = {
		Name = "M\u{e9}dio", Battles = 5, TeamSize = 4, MinLevel = 15, MaxLevel = 25, AI = "Medio",
		Reward = { Gold = 1200, Items = { "Superpocao", "DoceRaro" } },
	},
	Dificil = {
		Name = "Dif\u{ed}cil", Battles = 7, TeamSize = 6, MinLevel = 30, MaxLevel = 45, AI = "Dificil",
		Reward = { Gold = 3500, Items = { "Hiperpocao", "Reviver", "DoceEpico" }, DailyGems = 5 },
	},
	Infinito = {
		Name = "Infinito", Battles = nil, TeamSize = 6, AI = "Dificil",
		BaseLevel = 10, LevelPerFloor = 2,
		GoldPerFloor = 250, BonusEvery = 5, BonusGold = 1200,
		HealBetweenFloors = 0.30, -- recupera 30% do HP entre andares
		BossEvery = 5, BossStatBonus = 0.20, -- chefe a cada 5 andares, atributos +20%
		ScalingFromFloor = 20, ScalingPerFloor = 0.04, -- a partir do andar 20, +4% por andar
		BossDrop = { First = 0.05, PerBoss = 0.01, Max = 0.15 }, -- 5% no andar 5, +1 ponto por chefe, ate 15%
	},
}

Tower.MaxLevel = 50
Tower.LeaderboardSize = 10

function Tower.Index(mode: string): number
	return table.find(Tower.Order, mode) or 0
end

-- Desbloqueio em sequencia: Unlocked guarda o modo mais alto liberado
function Tower.IsUnlocked(unlocked: string?, mode: string): boolean
	return Tower.Index(mode) >= 1 and Tower.Index(mode) <= math.max(1, Tower.Index(unlocked or "Facil"))
end

function Tower.NextMode(mode: string): string?
	return Tower.Order[Tower.Index(mode) + 1]
end

-- Infinito
function Tower.FloorLevel(floor: number): number
	local m = Tower.Modes.Infinito
	return math.min(Tower.MaxLevel, m.BaseLevel + m.LevelPerFloor * floor)
end

function Tower.IsBossFloor(floor: number): boolean
	return floor % Tower.Modes.Infinito.BossEvery == 0
end

function Tower.FloorStatMultiplier(floor: number): number
	local m = Tower.Modes.Infinito
	local mult = 1
	if floor >= m.ScalingFromFloor then
		mult += m.ScalingPerFloor * (floor - m.ScalingFromFloor + 1)
	end
	if Tower.IsBossFloor(floor) then
		mult *= 1 + m.BossStatBonus
	end
	return mult
end

function Tower.FloorGold(floor: number): number
	local m = Tower.Modes.Infinito
	return m.GoldPerFloor + (if floor % m.BonusEvery == 0 then m.BonusGold else 0)
end

function Tower.BossDropChance(floor: number): number
	local d = Tower.Modes.Infinito.BossDrop
	local bossNumber = floor // Tower.Modes.Infinito.BossEvery
	return math.min(d.Max, d.First + d.PerBoss * (bossNumber - 1))
end

return Tower
