--[[
	Summon (GDD secao 13 - Invocacao). So dados e o sorteio puro; quem sorteia de verdade e o servidor
	(ServerScriptService/Economy/SummonService).

	|           | Portal Comum                          |
	| Custo     | 300 gold (10 por 2.700)               |
	| Chances   | Comum 70%, Raro 23%, Epico 6%, Lendario 1% |
	| Garantia  | Lendario na 200a seguida sem Lendario |
	Variante Brilhante: 1% em toda invocacao.
	Repetidos: 3 iguais viram +1 estrela (ate 5, +5% de atributos cada);
	sobras vendidas por gold (Comum 50, Raro 150, Epico 500, Lendario 3.000).
	Album: completar cada tipo e cada raridade paga gold e gemas uma vez.

	Valores que o GDD nao define (registrados em PROGRESSO.md): nivel do invocado = 5 (igual ao inicial);
	premio do Album = 1.000 gold + 10 gemas por tipo ou raridade completa.
]]

local Summon = {}

Summon.RarityOrder = { "Comum", "Raro", "Epico", "Lendario" }
Summon.RarityName = { Comum = "Comum", Raro = "Raro", Epico = "\u{c9}pico", Lendario = "Lend\u{e1}rio" }
-- Cor do raio na animacao: cinza, azul, roxo, dourado
Summon.RarityColor = {
	Comum = Color3.fromRGB(190, 195, 205),
	Raro = Color3.fromRGB(70, 150, 255),
	Epico = Color3.fromRGB(170, 80, 255),
	Lendario = Color3.fromRGB(255, 200, 50),
}

Summon.Portals = {
	Comum = {
		Name = "Portal Comum",
		Currency = "Gold",
		Cost = 300,
		Cost10 = 2700,
		Rates = { Comum = 0.70, Raro = 0.23, Epico = 0.06, Lendario = 0.01 },
		PityAt = 200, -- Lendario garantido na 200a seguida sem Lendario
		PityKey = "Comum", -- campo em SummonPity no perfil
	},
	-- Item aleatorio pago: bloqueado por PolicyService (ArePaidRandomItemsRestricted) onde for restrito
	Premium = {
		Name = "Portal Premium",
		Currency = "Gems",
		Cost = 25,
		Cost10 = 225,
		Rates = { Comum = 0, Raro = 0.72, Epico = 0.25, Lendario = 0.03 },
		PityAt = 60, -- Lendario garantido na 60a seguida sem Lendario
		PityKey = "Premium",
		PaidRandom = true,
		-- Banner da semana: 1 Lendario em destaque fica com metade da chance de Lendario.
		-- Rodizio na ordem da lista (troca segunda 00:00 UTC). Lista vazia = todos os Lendarios do elenco em ordem alfabetica.
		Banner = { Share = 0.5, Rotation = {} },
	},
}

Summon.CurrencyName = { Gold = "gold", Gems = "gemas" }

-- Semana para o banner: muda toda segunda 00:00 UTC (o dia 0 do Unix foi uma quinta)
function Summon.Week(t: number): number
	return (t - 4 * 86400) // 604800
end

-- Lendario em destaque do portal na semana (nil se o portal nao tem banner ou o elenco nao tem Lendario)
function Summon.BannerOf(portalId: string, t: number, legendaries: { string }): string?
	local portal = Summon.Portals[portalId]
	if not portal or not portal.Banner then
		return nil
	end
	local list = if #portal.Banner.Rotation > 0 then portal.Banner.Rotation else legendaries
	if #list == 0 then
		return nil
	end
	return list[Summon.Week(t) % #list + 1]
end

-- Chances do portal para o jogador. Sorte em Dobro (Portal Comum): Epico e Lendario em dobro, o extra sai do Comum.
function Summon.RatesFor(portalId: string, benefits): { [string]: number }
	local portal = Summon.Portals[portalId]
	local rates = table.clone(portal.Rates)
	if portalId == "Comum" and benefits and benefits.SorteEmDobro then
		local extra = rates.Epico + rates.Lendario
		rates.Epico *= 2
		rates.Lendario *= 2
		rates.Comum -= extra
	end
	return rates
end

Summon.ShinyChance = 0.01
Summon.SummonLevel = 5
Summon.Stars = { Max = 5, CopiesPerStar = 3, BonusPerStar = 0.05 }
Summon.SellPrice = { Comum = 50, Raro = 150, Epico = 500, Lendario = 3000 }
Summon.AlbumReward = { Gold = 1000, Gems = 10 }

-- Sorteio puro. pity = invocacoes seguidas sem Lendario antes desta.
-- Retorna raridade, se foi pela garantia, novo valor de pity e se saiu Brilhante.
function Summon.Roll(portalId: string, rng: Random, pity: number, rates: { [string]: number }?)
	local portal = assert(Summon.Portals[portalId], "Portal desconhecido")
	rates = rates or portal.Rates
	local rarity
	local forced = false
	if pity + 1 >= portal.PityAt then
		rarity = "Lendario"
		forced = true
	else
		local r = rng:NextNumber()
		local acc = 0
		for _, id in ipairs(Summon.RarityOrder) do
			acc += rates[id] or 0
			if r < acc then
				rarity = id
				break
			end
		end
		rarity = rarity or "Lendario" -- arredondamento no fim da soma
	end
	local newPity = if rarity == "Lendario" then 0 else pity + 1
	local shiny = rng:NextNumber() < Summon.ShinyChance
	return rarity, forced, newPity, shiny
end

function Summon.StarMultiplier(stars: number?): number
	return 1 + Summon.Stars.BonusPerStar * (stars or 0)
end

return Summon
