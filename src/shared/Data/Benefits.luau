--[[
	Benefits (GDD secao 9 - Monetizacao)
	Game Pass so em Robux; gemas liberam o mesmo beneficio dentro do jogo (salvo no perfil).
	Perfil: Benefits[id] = "Pass" (Game Pass, conferido a cada entrada) ou "Gems" (comprado com gemas).
	Nenhum beneficio aumenta dano, HP, captura ou o teto diario de gemas.
	IDs do painel do Roblox: Data/ProductIds.
]]

local Benefits = {}

Benefits.List = {
	MochilaAmpliada = { Name = "Mochila Ampliada", Effect = "+20 espa\u{e7}os na mochila", Robux = 99, Gems = 1500, Order = 1 },
	GoldEmDobro = { Name = "Gold em Dobro", Effect = "2x gold dos personagens passeando", Robux = 249, Gems = 4000, Order = 2 },
	CuraAutomatica = { Name = "Cura Autom\u{e1}tica", Effect = "Time curado ap\u{f3}s cada batalha fora da torre", Robux = 399, Gems = 9000, Order = 3 },
	XpEmDobro = { Name = "XP em Dobro", Effect = "2x XP", Robux = 299, Order = 4 },
	VIP = { Name = "VIP", Effect = "Tag no chat, base dourada, +10% de gold", Robux = 349, Order = 5 },
	MineradorExtra = { Name = "Minerador Extra", Effect = "+2 vagas de minera\u{e7}\u{e3}o (teto de gemas n\u{e3}o muda)", Robux = 499, Order = 6 },
	InvocacaoRapida = { Name = "Invoca\u{e7}\u{e3}o R\u{e1}pida", Effect = "Invoca 3 de uma vez e pula a anima\u{e7}\u{e3}o", Robux = 199, Order = 7 },
	SorteEmDobro = { Name = "Sorte em Dobro", Effect = "Dobra \u{c9}pico e Lend\u{e1}rio no Portal Comum", Robux = 399, Order = 8 },
	DepositoAmpliado = { Name = "Dep\u{f3}sito Ampliado", Effect = "+50 vagas de personagens", Robux = 149, Order = 9 },
}

Benefits.GemPacks = {
	Gems500 = { Name = "500 Gemas", Gems = 500, Robux = 49, Order = 1 },
	Gems1500 = { Name = "1.500 Gemas", Gems = 1500, Robux = 129, Order = 2 },
	Gems5000 = { Name = "5.000 Gemas", Gems = 5000, Robux = 399, Order = 3 },
}

Benefits.BagBonus = 20
Benefits.CollectionBase = 100 -- vagas de personagens (GDD nao define; registrado em PROGRESSO.md)
Benefits.CollectionBonus = 50
Benefits.QuickSummonCount = 3

function Benefits.Sorted(): { string }
	local ids = {}
	for id in pairs(Benefits.List) do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Benefits.List[a].Order < Benefits.List[b].Order
	end)
	return ids
end

function Benefits.SortedPacks(): { string }
	local ids = {}
	for id in pairs(Benefits.GemPacks) do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Benefits.GemPacks[a].Order < Benefits.GemPacks[b].Order
	end)
	return ids
end

function Benefits.Has(data, id: string): boolean
	return data ~= nil and data.Benefits ~= nil and data.Benefits[id] ~= nil and data.Benefits[id] ~= false
end

function Benefits.BagSlots(data, baseSlots: number): number
	return baseSlots + (if Benefits.Has(data, "MochilaAmpliada") then Benefits.BagBonus else 0)
end

function Benefits.CollectionMax(data): number
	return Benefits.CollectionBase + (if Benefits.Has(data, "DepositoAmpliado") then Benefits.CollectionBonus else 0)
end

function Benefits.CollectionCount(data): number
	local n = 0
	for _ in pairs(data.Collection or {}) do
		n += 1
	end
	return n
end

return Benefits
