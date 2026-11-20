--[[
	Base (GDD secao 8 - Base, mineracao e economia)
	Terreno de 40 x 40 por jogador; ate 6 personagens ativos, cada um Passeando (gold) ou Minerando (minerio).
	Vagas de mineracao: 2 no inicio; melhorias em gold ate 6 (5.000, 15.000, 40.000, 100.000).
	Producao acumula ate 8 horas com o jogador fora.
	100 de minerio = 1 gema; teto de venda 50 gemas por dia; minerio guardado no maximo 10.000.
	Beneficios (secao 9): Gold em Dobro (2x gold de quem passeia), VIP (+10% de gold), Minerador Extra (+2 vagas).
]]

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

Base.States = { Walk = "Passeando", Mine = "Minerando" }

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

-- Producao por hora do perfil: gold (passeando) e minerio (minerando)
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
			else
				gold += (Base.GoldPerHour[rarity] or 0) * goldMult
			end
		end
	end
	return gold, ore
end

return Base
