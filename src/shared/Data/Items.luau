--[[
	Items (GDD secao 7 - Itens da mochila)
	Valores exatos do GDD. Kind diz o que o item faz:
	  HealHP (cura Amount de HP), CureStatus (remove status), RestorePP (Amount de PP em um golpe),
	  Revive (levanta desmaiado com Percent do HP), Capture (Selo; so contra selvagens).
	Usar item em batalha gasta o turno. Mochila de 30 espacos, pilhas de 99.
	Pocoes e Reviver tambem fora de batalha (OutsideBattle). Itens nao sao trocaveis.
]]

local Items = {}

Items.BagSlots = 30
Items.StackLimit = 99

Items.List = {
	Pocao = { Name = "Poção", Kind = "HealHP", Amount = 20, Price = 50, UsableInBattle = true, OutsideBattle = true, Order = 1, Description = "Cura 20 de HP" },
	Superpocao = { Name = "Superpoção", Kind = "HealHP", Amount = 50, Price = 150, UsableInBattle = true, OutsideBattle = true, Order = 2, Description = "Cura 50 de HP" },
	Hiperpocao = { Name = "Hiperpoção", Kind = "HealHP", Amount = 120, Price = 400, UsableInBattle = true, OutsideBattle = true, Order = 3, Description = "Cura 120 de HP" },
	CuraStatus = { Name = "Cura-Status", Kind = "CureStatus", Price = 100, UsableInBattle = true, Order = 4, Description = "Remove qualquer status" },
	Eter = { Name = "Éter", Kind = "RestorePP", Amount = 10, Price = 200, UsableInBattle = true, Order = 5, Description = "Restaura 10 PP de um golpe" },
	Reviver = { Name = "Reviver", Kind = "Revive", Percent = 0.5, Price = 500, UsableInBattle = true, OutsideBattle = true, Order = 6, Description = "Levanta desmaiado com 50% do HP", Short = "Revive: 50% HP" },
	SeloContrato = { Name = "Selo de Contrato", Kind = "Capture", SealMultiplier = 1, Price = 100, UsableInBattle = true, Order = 7, Description = "Tenta capturar um selvagem" },
	SeloSuperior = { Name = "Selo Superior", Kind = "Capture", SealMultiplier = 1.5, Price = 300, UsableInBattle = true, Order = 8, Description = "Captura com bônus 1,5" },
	-- Doces de XP (secao 14): so caem no Refugio. Sem Price = fora da loja; uso pelo menu Time (TeamUse).
	DoceComum = { Name = "Doce Comum", Kind = "XpCandy", XpPercent = 0.25, TeamUse = true, Rarity = "Comum", Order = 9, Description = "+25% do XP do n\u{ed}vel atual", Short = "+25% de XP" },
	DoceRaro = { Name = "Doce Raro", Kind = "XpCandy", Levels = 1, TeamUse = true, Rarity = "Raro", Order = 10, Description = "Sobe 1 n\u{ed}vel" },
	DoceEpico = { Name = "Doce \u{c9}pico", Kind = "XpCandy", Levels = 3, TeamUse = true, Rarity = "Epico", Order = 11, Description = "Sobe 3 n\u{ed}veis" },
}

-- Doces na ordem do sorteio (mais raro primeiro) e chance de cada um por selvagem derrotado ou capturado
Items.Candies = {
	{ Id = "DoceEpico", Chance = 0.01 },
	{ Id = "DoceRaro", Chance = 0.04 },
	{ Id = "DoceComum", Chance = 0.12 },
}

for id, item in pairs(Items.List) do
	item.Id = id
end

function Items.Get(id: string)
	return Items.List[id]
end

-- Lista ordenada (loja e mochila)
function Items.Sorted(): { string }
	local ids = {}
	for id in pairs(Items.List) do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return (Items.List[a].Order or 99) < (Items.List[b].Order or 99)
	end)
	return ids
end

-- Espacos ocupados (cada item diferente com quantidade > 0 ocupa 1)
function Items.SlotsUsed(bag): number
	local n = 0
	for _, count in pairs(bag or {}) do
		if typeof(count) == "number" and count > 0 then
			n += 1
		end
	end
	return n
end

-- Quantos daquele item ainda cabem na mochila (slots = espacos do jogador; Mochila Ampliada da +20)
function Items.SpaceFor(bag, id: string, slots: number?): number
	local have = (bag and bag[id]) or 0
	if have <= 0 and Items.SlotsUsed(bag) >= (slots or Items.BagSlots) then
		return 0
	end
	return math.max(0, Items.StackLimit - have)
end

return Items
