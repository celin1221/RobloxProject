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

Summon.RarityOrder = { "Comum", "Raro", "Epico", "Lendario", "Secreto" }
Summon.RarityName = { Comum = "Comum", Raro = "Raro", Epico = "\u{c9}pico", Lendario = "Lend\u{e1}rio", Secreto = "Secreto" }
-- Cor do raio na animacao: cinza, azul, roxo, dourado, preto (Secreto)
Summon.RarityColor = {
	Comum = Color3.fromRGB(190, 195, 205),
	Raro = Color3.fromRGB(70, 150, 255),
	Epico = Color3.fromRGB(170, 80, 255),
	Lendario = Color3.fromRGB(255, 200, 50),
	Secreto = Color3.fromRGB(16, 16, 22),
}

-- Regra da raridade Secreto: 0,001% (1 em 100.000) em qualquer banner a partir do Nivel da Conta 15
Summon.SecretChance = 0.00001
Summon.SecretMinAccountLevel = 15

Summon.Portals = {
	Comum = {
		Name = "Portal Comum",
		Currency = "Gold",
		Cost = 300,
		Cost10 = 2700,
		Rates = { Comum = 0.745, Raro = 0.215, Epico = 0.035, Lendario = 0.005 },
		PityAt = 300, -- Lendario garantido na 300a seguida sem Lendario (prepara terreno para futuro Mitico/Secreto)
		PityKey = "Comum", -- campo em SummonPity no perfil
	},
	-- Item aleatorio pago: bloqueado por PolicyService (ArePaidRandomItemsRestricted) onde for restrito
	Premium = {
		Name = "Portal Premium",
		Currency = "Gems",
		Cost = 25,
		Cost10 = 225,
		Rates = { Comum = 0, Raro = 0.78, Epico = 0.20, Lendario = 0.02 },
		PityAt = 75, -- Lendario garantido na 75a seguida sem Lendario (4x mais chance que o Comum)
		PityKey = "Premium",
		PaidRandom = true,
		-- Banner da semana: 1 Lendario em destaque fica com metade da chance de Lendario.
		-- Rodizio na ordem da lista (troca segunda 00:00 UTC). Lista vazia = todos os Lendarios do elenco em ordem alfabetica.
		Banner = { Share = 0.5, Rotation = {} },
	},
}

Summon.CurrencyName = { Gold = "gold", Gems = "gemas" }

-- Paineis selecionaveis na estrela de invocacao (Anime filter + arte de painel)
Summon.BannerOrder = { "Todos", "OnePiece", "Naruto", "Bleach" }
Summon.Banners = {
	Todos = {
		Id = "Todos",
		Anime = nil, -- personagens invocaveis dos animes ja desbloqueados pelo jogador
		Name = "Todos os Desbloqueados",
		Short = "TODOS",
		Subtitle = "Animes Desbloqueados",
		ImageId = 80124787437807,
		Accent = Color3.fromRGB(168, 85, 247),
		Icon = "star",
	},
	OnePiece = {
		Id = "OnePiece",
		Anime = "OnePiece",
		Name = "One Piece",
		Short = "ONE PIECE",
		Subtitle = "Nami · Usopp · Zoro · Sanji · Luffy · Barba Branca",
		ImageId = 88088550646321,
		Accent = Color3.fromRGB(56, 178, 255),
		Icon = "insignia_onepiece",
	},
	Naruto = {
		Id = "Naruto",
		Anime = "Naruto",
		Name = "Naruto",
		Short = "NARUTO",
		Subtitle = "Sakura · Shikamaru · Kakashi · Sasuke · Naruto · Sarutobi",
		ImageId = 90282977605958,
		Accent = Color3.fromRGB(255, 138, 40),
		Icon = "insignia_naruto",
	},
	Bleach = {
		Id = "Bleach",
		Anime = "Bleach",
		Name = "Bleach",
		Short = "BLEACH",
		Subtitle = "Chad · Uryu · Rukia · Renji · Ichigo · Byakuya",
		ImageId = 77274797232236,
		Accent = Color3.fromRGB(48, 212, 232),
		Icon = "insignia_bleach",
	},
}

function Summon.GetBanner(bannerId: string?)
	if typeof(bannerId) == "string" and Summon.Banners[bannerId] then
		return Summon.Banners[bannerId]
	end
	return Summon.Banners.Todos
end

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
-- Secreto: 0,001% em qualquer banner quando o jogador esta no Nivel da Conta >= 15.
function Summon.RatesFor(portalId: string, benefits, accountLevel: number?): { [string]: number }
	local portal = Summon.Portals[portalId]
	local rates = table.clone(portal.Rates)
	if portalId == "Comum" and benefits and benefits.SorteEmDobro then
		local extra = rates.Epico + rates.Lendario
		rates.Epico *= 2
		rates.Lendario *= 2
		rates.Comum -= extra
	end
	if accountLevel ~= nil then
		rates.Secreto = if accountLevel >= Summon.SecretMinAccountLevel then Summon.SecretChance else 0
	end
	return rates
end

Summon.ShinyChance = 0.01
Summon.SummonLevel = 5
Summon.Stars = { Max = 5, CopiesPerStar = 3, BonusPerStar = 0.05 }
Summon.SellPrice = { Comum = 50, Raro = 150, Epico = 600, Lendario = 4000, Secreto = 12000 }
Summon.AlbumReward = { Gold = 1000, Gems = 10 }

-- Sorteio puro. pity = invocacoes seguidas sem Lendario antes desta.
-- Retorna raridade, se foi pela garantia, novo valor de pity e se saiu Brilhante.
function Summon.Roll(portalId: string, rng: Random, pity: number, rates: { [string]: number }?, accountLevel: number?)
	local portal = assert(Summon.Portals[portalId], "Portal desconhecido")
	rates = rates or portal.Rates
	local rarity
	local forced = false
	local secretChance = if rates.Secreto ~= nil
		then rates.Secreto
		elseif accountLevel ~= nil and accountLevel >= Summon.SecretMinAccountLevel then Summon.SecretChance
		else 0
	if secretChance > 0 and rng:NextNumber() < secretChance then
		rarity = "Secreto"
	elseif pity + 1 >= portal.PityAt then
		rarity = "Lendario"
		forced = true
	else
		local r = rng:NextNumber()
		local acc = 0
		for _, id in ipairs(Summon.RarityOrder) do
			if id == "Secreto" then
				continue
			end
			acc += rates[id] or 0
			if r < acc then
				rarity = id
				break
			end
		end
		rarity = rarity or "Lendario" -- arredondamento no fim da soma
	end
	local newPity = if rarity == "Lendario"
		then 0
		elseif rarity == "Secreto" then math.min(pity, math.max(0, portal.PityAt - 1))
		else pity + 1
	local shiny = rng:NextNumber() < Summon.ShinyChance
	return rarity, forced, newPity, shiny
end

function Summon.StarMultiplier(stars: number?): number
	return 1 + Summon.Stars.BonusPerStar * (stars or 0)
end

return Summon
