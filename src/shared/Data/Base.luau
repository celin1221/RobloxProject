--[[
	Base (GDD secao 8 - Base, mineracao e economia)
	Terreno de 40 x 40 por jogador; ate 6 personagens ativos, cada um Passeando (gold) ou Minerando (minerio).
	Vagas de mineracao: 2 no inicio; melhorias em gold ate 6 (5.000, 15.000, 40.000, 100.000).
	Producao acumula ate 8 horas com o jogador fora.
	100 de minerio = 1 gema; teto de venda 50 gemas por dia; minerio guardado no maximo 10.000.
	Beneficios (secao 9): Gold em Dobro (2x gold de quem passeia), VIP (+10% de gold), Minerador Extra (+2 vagas).
]]

local Training = require(script.Parent:WaitForChild("Training"))

local Base = {}

Base.MaxActive = 6
Base.StartMiningSlots = 2
Base.MaxMiningSlots = 6
Base.SlotUpgradeCost = { 5000, 15000, 40000, 100000 } -- 3a, 4a, 5a e 6a vaga
Base.OfflineCapHours = 8
Base.OrePerGem = 100
Base.DailyGemCap = 50
Base.OreMax = 10000

-- Por hora, pela raridade (tabela da secao 8)
Base.GoldPerHour = { Comum = 20, Raro = 30, Epico = 45, Lendario = 70 }
Base.OrePerHour = { Comum = 10, Raro = 18, Epico = 30, Lendario = 50 }
Base.MiningGoldRatio = 0.50 -- mineracao tambem fornece 50% do Gold/h alem dos minerios

Base.States = { Walk = "Passeando", Mine = "Minerando" }

-- Niveis da Mineracao (Nv. 1..10): libera minerios de Defesa, Velocidade e Ataque e equilibra chances
Base.MaxMiningLevel = 10
Base.MiningCycleSeconds = 60 -- intervalo base (1 min) por minerador Comum (10 min/h = 1.0 ciclo/min)
Base.MaxOfflineMiningCycles = 480 -- limite de 8h no ciclo base por personagem

Base.MiningUpgradeCost = {
	[2] = 500,
	[3] = 1500,
	[4] = 3500,
	[5] = 7500,
	[6] = 15000,
	[7] = 30000,
	[8] = 60000,
	[9] = 110000,
	[10] = 200000,
}

-- Chances independentes (0..1) e quantidade por achado em cada nivel da Mineracao.
-- Como cada minerio rola independente, um mesmo ciclo pode render mais de um tipo e mais de 1 unidade.
-- Ao subir de nivel, os outros minerios sao liberados e se equilibram, mantendo Ataque como o mais raro.
Base.MiningDropTable = {
	[1] = { HP = { Chance = 0.55, Min = 1, Max = 2 }, Defense = { Chance = 0.00, Min = 0, Max = 0 }, Speed = { Chance = 0.00, Min = 0, Max = 0 }, Attack = { Chance = 0.00, Min = 0, Max = 0 } },
	[2] = { HP = { Chance = 0.52, Min = 1, Max = 2 }, Defense = { Chance = 0.18, Min = 1, Max = 1 }, Speed = { Chance = 0.00, Min = 0, Max = 0 }, Attack = { Chance = 0.00, Min = 0, Max = 0 } },
	[3] = { HP = { Chance = 0.50, Min = 1, Max = 2 }, Defense = { Chance = 0.26, Min = 1, Max = 2 }, Speed = { Chance = 0.00, Min = 0, Max = 0 }, Attack = { Chance = 0.00, Min = 0, Max = 0 } },
	[4] = { HP = { Chance = 0.48, Min = 1, Max = 2 }, Defense = { Chance = 0.30, Min = 1, Max = 2 }, Speed = { Chance = 0.14, Min = 1, Max = 1 }, Attack = { Chance = 0.00, Min = 0, Max = 0 } },
	[5] = { HP = { Chance = 0.46, Min = 1, Max = 2 }, Defense = { Chance = 0.34, Min = 1, Max = 2 }, Speed = { Chance = 0.22, Min = 1, Max = 2 }, Attack = { Chance = 0.00, Min = 0, Max = 0 } },
	[6] = { HP = { Chance = 0.44, Min = 1, Max = 3 }, Defense = { Chance = 0.36, Min = 1, Max = 2 }, Speed = { Chance = 0.26, Min = 1, Max = 2 }, Attack = { Chance = 0.10, Min = 1, Max = 1 } },
	[7] = { HP = { Chance = 0.43, Min = 1, Max = 3 }, Defense = { Chance = 0.37, Min = 1, Max = 2 }, Speed = { Chance = 0.30, Min = 1, Max = 2 }, Attack = { Chance = 0.16, Min = 1, Max = 2 } },
	[8] = { HP = { Chance = 0.42, Min = 1, Max = 3 }, Defense = { Chance = 0.38, Min = 1, Max = 3 }, Speed = { Chance = 0.33, Min = 1, Max = 2 }, Attack = { Chance = 0.22, Min = 1, Max = 2 } },
	[9] = { HP = { Chance = 0.42, Min = 2, Max = 3 }, Defense = { Chance = 0.40, Min = 1, Max = 3 }, Speed = { Chance = 0.36, Min = 1, Max = 3 }, Attack = { Chance = 0.28, Min = 1, Max = 2 } },
	[10] = { HP = { Chance = 0.44, Min = 2, Max = 4 }, Defense = { Chance = 0.42, Min = 2, Max = 3 }, Speed = { Chance = 0.39, Min = 2, Max = 3 }, Attack = { Chance = 0.34, Min = 1, Max = 3 } },
}

function Base.Day(now: number): number
	return now // 86400 -- dia UTC
end

-- Vagas de mineracao do perfil (com Minerador Extra)
function Base.MiningSlots(data): number
	local slots = (data.Base and data.Base.MiningSlots) or Base.StartMiningSlots
	if data.Benefits and data.Benefits.MineradorExtra then
		slots += 2
	end
	return slots
end

-- Custo da proxima vaga comprada com gold (nil = ja no maximo)
function Base.NextSlotCost(data): number?
	local bought = ((data.Base and data.Base.MiningSlots) or Base.StartMiningSlots) - Base.StartMiningSlots
	return Base.SlotUpgradeCost[bought + 1]
end

function Base.MiningLevelOf(data): number
	local lv = data and data.Base and data.Base.MiningLevel
	if typeof(lv) ~= "number" or lv ~= lv then
		return 1
	end
	return math.clamp(math.floor(lv), 1, Base.MaxMiningLevel)
end

function Base.NextMiningLevelCost(data): number?
	local lv = Base.MiningLevelOf(data)
	return Base.MiningUpgradeCost[lv + 1]
end

-- Poder de ciclo de drops conforme os mineradores ativos (Comum = 1.0x .. Lendario = 5.0x)
function Base.MinerPower(data, rarityOf): number
	local power = 0
	local baseRate = Base.OrePerHour.Comum or 10
	for uid, state in pairs((data.Base and data.Base.Active) or {}) do
		if state == "Mine" then
			local m = data.Collection and data.Collection[uid]
			local rarity = m and rarityOf(m.CharacterId)
			if rarity then
				power += (Base.OrePerHour[rarity] or baseRate) / baseRate
			end
		end
	end
	return power
end

-- Producao por hora do perfil: gold (passeando + minerando) e minerio bruto (minerando)
function Base.Rates(data, rarityOf)
	local gold, ore = 0, 0
	local goldMult = 1
	if data.Benefits then
		if data.Benefits.GoldEmDobro then
			goldMult *= 2
		end
		if data.Benefits.VIP then
			goldMult *= 1.1
		end
	end
	for uid, state in pairs((data.Base and data.Base.Active) or {}) do
		local m = data.Collection[uid]
		local rarity = m and rarityOf(m.CharacterId)
		if rarity then
			if state == "Mine" then
				ore += Base.OrePerHour[rarity] or 0
				gold += (Base.GoldPerHour[rarity] or 0) * Base.MiningGoldRatio * goldMult
			else
				gold += (Base.GoldPerHour[rarity] or 0) * goldMult
			end
		end
	end
	return gold, ore
end

-- Participacao relativa (%) entre os minerios desbloqueados no nivel de mineracao atual
function Base.DropShares(level: number)
	local row = Base.MiningDropTable[math.clamp(math.floor(level or 1), 1, Base.MaxMiningLevel)]
	local expected, total = {}, 0
	for _, stat in ipairs(Training.OreOrder) do
		local cfg = row and row[stat]
		local avg = if cfg and cfg.Chance > 0 then cfg.Chance * ((cfg.Min + cfg.Max) * 0.5) else 0
		expected[stat] = avg
		total += avg
	end
	local shares = {}
	for _, stat in ipairs(Training.OreOrder) do
		shares[stat] = if total > 0 then (expected[stat] / total * 100) else 0
	end
	return shares
end

return Base
