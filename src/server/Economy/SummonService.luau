--[[
	SummonService (GDD secao 13 - Portal Comum e Portal Premium)
	- Sorteio so no servidor (Data/Summon.Roll), custo em gold (Comum) ou gemas (Premium), garantia de Lendario e Brilhante 1%.
	- Portal Premium: item aleatorio pago, recusado onde PolicyService restringe (atributo PaidRandomRestricted,
	  colocado pelo MonetizationService; sem resposta da PolicyService conta como restrito).
	- Banner da semana no Premium: o Lendario em destaque fica com metade da chance de Lendario.
	- Beneficios (secao 9): Invocacao Rapida (3 de uma vez), Sorte em Dobro (Portal Comum), Deposito Ampliado (vagas).
	- Personagem sorteado entre os do elenco com a raridade sorteada.
	  Se o elenco ainda nao tem personagem daquela raridade, vem um da raridade abaixo mais proxima
	  (registrado em PROGRESSO.md; some quando o elenco tiver todas as raridades).
	- Fusao: 3 copias iguais viram +1 estrela (ate 5). Venda de repetidos por gold.
	- Lendario e Brilhante anunciados no chat do servidor.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Data = ReplicatedStorage:WaitForChild("Data")
local Characters = require(Data.Characters)
local Summon = require(Data.Summon)
local Progression = require(Data.Progression)
local Benefits = require(Data.Benefits)

local DataFolder = ServerScriptService:WaitForChild("Data")
local PlayerDataService = require(DataFolder:WaitForChild("PlayerDataService"))
local ProgressionService = require(DataFolder:WaitForChild("ProgressionService"))
local RetentionService = require(DataFolder:WaitForChild("RetentionService"))
local BattleService = require(ServerScriptService:WaitForChild("Battle"):WaitForChild("BattleService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local SummonService = {}

local MAX_TEAM = 6
local rng = Random.new()
local busy = {} -- [Player] = true durante um pedido

-- Personagens do elenco por raridade
local function byRarity()
	local map = {}
	for id, def in pairs(Characters.List) do
		if not def.Prototype then -- prototipos de teste nunca saem na invocacao
			map[def.Rarity] = map[def.Rarity] or {}
			table.insert(map[def.Rarity], id)
		end
	end
	for _, list in pairs(map) do
		table.sort(list)
	end
	return map
end

function SummonService.Legendaries(): { string }
	return byRarity().Lendario or {}
end

function SummonService.BannerOf(portalId: string): string?
	return Summon.BannerOf(portalId, os.time(), SummonService.Legendaries())
end

local function pickCharacter(rarity: string, banner: string?, share: number?)
	local map = byRarity()
	-- banner: o Lendario em destaque leva metade das vezes que sai Lendario; a outra metade e dos demais
	if rarity == "Lendario" and banner and Characters.Get(banner) then
		local others = {}
		for _, id in ipairs(map.Lendario or {}) do
			if id ~= banner then
				table.insert(others, id)
			end
		end
		if #others == 0 or rng:NextNumber() < (share or 0.5) then
			return banner
		end
		return others[rng:NextInteger(1, #others)]
	end
	local idx = table.find(Summon.RarityOrder, rarity) or 1
	for i = idx, 1, -1 do
		local list = map[Summon.RarityOrder[i]]
		if list and #list > 0 then
			return list[rng:NextInteger(1, #list)]
		end
	end
	return nil
end

local function announce(text: string)
	Remotes.Announce:FireAllClients(text)
end

-- Faz as invocacoes. Retorna (true, resultados) ou (false, motivo).
function SummonService.Summon(player: Player, portalId: string, count: number)
	local portal = Summon.Portals[portalId]
	if not portal then
		return false, "Portal inv\u{e1}lido."
	end
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Dados ainda carregando."
	end
	local quick = count == Benefits.QuickSummonCount and Benefits.Has(data, "InvocacaoRapida")
	if count ~= 1 and count ~= 10 and not quick then
		return false, "Quantidade inv\u{e1}lida."
	end
	if portal.PaidRandom and player:GetAttribute("PaidRandomRestricted") ~= false then
		return false, "O " .. portal.Name .. " n\u{e3}o est\u{e1} dispon\u{ed}vel na sua regi\u{e3}o. Use o Portal Comum."
	end
	local free = Benefits.CollectionMax(data) - Benefits.CollectionCount(data)
	if free < count then
		return false, "Dep\u{f3}sito de personagens cheio (" .. Benefits.CollectionCount(data) .. "/" .. Benefits.CollectionMax(data) .. "). Venda ou funda repetidos."
	end
	if not data.StarterChosen then
		return false, "Escolha seu personagem inicial primeiro."
	end
	if BattleService.IsInBattle(player) then
		return false, "N\u{e3}o d\u{e1} para invocar durante a batalha."
	end
	-- invocacao gratis (login, missoes semanais, codigos): usada primeiro no "Invocar 1"
	local tickets = data.Tickets or {}
	if count == 1 and (tickets[portal.PityKey] or 0) > 0 then
		tickets[portal.PityKey] -= 1
	else
		local cost = if count == 10 then portal.Cost10 else portal.Cost * count
		local field = if portal.Currency == "Gems" then "Gems" else "Gold"
		if data[field] < cost then
			return false, (if field == "Gems" then "Gemas" else "Gold") .. " insuficiente (precisa de " .. cost .. ")."
		end
		data[field] -= cost
	end

	local results = {}
	local pity = data.SummonPity[portal.PityKey] or 0
	local rates = Summon.RatesFor(portalId, data.Benefits)
	local banner = SummonService.BannerOf(portalId)
	for i = 1, count do
		local rarity, forced, newPity, shiny = Summon.Roll(portalId, rng, pity, rates)
		pity = newPity
		local charId = pickCharacter(rarity, banner, portal.Banner and portal.Banner.Share)
		local def = Characters.Get(charId)
		local isNew = data.Album.Owned[charId] == nil
		local variant = if shiny then "Brilhante" else nil
		local toTeam = #data.Team < MAX_TEAM
		local uid, albumLines = ProgressionService.AddCharacter(player, charId, Summon.SummonLevel, toTeam, variant)
		table.insert(results, {
			Uid = uid,
			CharacterId = charId,
			Name = def.Name,
			Type = def.Type,
			Rarity = def.Rarity, -- raridade do personagem entregue
			Rolled = rarity, -- raridade sorteada
			Forced = forced, -- veio pela garantia
			Banner = banner ~= nil and charId == banner,
			Variant = variant,
			New = isNew,
			Album = albumLines,
		})
		if def.Rarity == "Lendario" or shiny then
			announce(string.format("%s invocou %s%s (%s)!", player.Name, def.Name, if shiny then " Brilhante" else "", Summon.RarityName[def.Rarity]))
		end
	end
	data.SummonPity[portal.PityKey] = pity
	RetentionService.Track(player, "Summon", count)
	PlayerDataService.MarkChanged(player)
	task.spawn(PlayerDataService.SaveNow, player) -- compra: salva ja
	return true, results
end

-- Copias de um personagem: as que estao fora do time primeiro, as mais fracas primeiro
local function copiesOf(data, characterId: string)
	local list = {}
	for uid, m in pairs(data.Collection) do
		if m.CharacterId == characterId then
			table.insert(list, m)
		end
	end
	return list
end

local function inTeam(data, uid: string): boolean
	return table.find(data.Team, uid) ~= nil
end

-- 3 iguais viram +1 estrela: fica a melhor copia, 2 copias fora do time sao consumidas
function SummonService.Fuse(player: Player, characterId)
	local data = PlayerDataService.Get(player)
	if not data or typeof(characterId) ~= "string" or not Characters.Get(characterId) then
		return false, "Personagem inv\u{e1}lido."
	end
	local copies = copiesOf(data, characterId)
	if #copies < Summon.Stars.CopiesPerStar then
		return false, "Precisa de " .. Summon.Stars.CopiesPerStar .. " c\u{f3}pias."
	end
	table.sort(copies, function(a, b)
		if (a.Stars or 0) ~= (b.Stars or 0) then
			return (a.Stars or 0) > (b.Stars or 0)
		end
		return a.Level > b.Level
	end)
	local target = copies[1]
	if (target.Stars or 0) >= Summon.Stars.Max then
		return false, "J\u{e1} tem " .. Summon.Stars.Max .. " estrelas."
	end
	local fodder = {}
	for i = #copies, 2, -1 do
		local m = copies[i]
		if not inTeam(data, m.Uid) and #fodder < Summon.Stars.CopiesPerStar - 1 then
			table.insert(fodder, m)
		end
	end
	if #fodder < Summon.Stars.CopiesPerStar - 1 then
		return false, "Tire do time as c\u{f3}pias extras para fundir."
	end
	for _, m in ipairs(fodder) do
		data.Collection[m.Uid] = nil
	end
	target.Stars = (target.Stars or 0) + 1
	PlayerDataService.MarkChanged(player)
	task.spawn(PlayerDataService.SaveNow, player)
	return true, Characters.Get(characterId).Name .. " agora tem " .. target.Stars .. " estrela(s)."
end

-- Vende uma copia repetida (fora do time; precisa sobrar outra copia)
function SummonService.SellDuplicate(player: Player, characterId)
	local data = PlayerDataService.Get(player)
	if not data or typeof(characterId) ~= "string" or not Characters.Get(characterId) then
		return false, "Personagem inv\u{e1}lido."
	end
	local copies = copiesOf(data, characterId)
	if #copies < 2 then
		return false, "S\u{f3} d\u{e1} para vender repetidos."
	end
	-- a mais fraca fora do time
	table.sort(copies, function(a, b)
		if (a.Stars or 0) ~= (b.Stars or 0) then
			return (a.Stars or 0) < (b.Stars or 0)
		end
		return a.Level < b.Level
	end)
	local sold
	for _, m in ipairs(copies) do
		if not inTeam(data, m.Uid) then
			sold = m
			break
		end
	end
	if not sold then
		return false, "Todas as c\u{f3}pias est\u{e3}o no time."
	end
	local def = Characters.Get(characterId)
	local price = Summon.SellPrice[def.Rarity] or 0
	data.Collection[sold.Uid] = nil
	data.Gold += price
	PlayerDataService.MarkChanged(player)
	task.spawn(PlayerDataService.SaveNow, player)
	return true, def.Name .. " vendido por " .. price .. " gold."
end

local function guarded(fn)
	return function(player, ...)
		if busy[player] then
			return false, "Aguarde."
		end
		busy[player] = true
		local ok, a, b = pcall(fn, player, ...)
		busy[player] = nil
		if not ok then
			warn("[Summon] " .. tostring(a))
			return false, "Erro no servidor."
		end
		return a, b
	end
end

function SummonService.Init()
	Remotes.Summon.OnServerInvoke = guarded(function(player, portalId, count)
		return SummonService.Summon(player, portalId, count)
	end)
	-- destaque da semana do Portal Premium (para a tela)
	local bannerRF = Remotes:FindFirstChild("SummonBanner")
	if bannerRF then
		bannerRF.OnServerInvoke = function(_, portalId)
			if typeof(portalId) ~= "string" or not Summon.Portals[portalId] then
				return nil
			end
			local id = SummonService.BannerOf(portalId)
			local def = id and Characters.Get(id)
			return def and def.Name or nil
		end
	end
	Remotes.Fuse.OnServerInvoke = guarded(SummonService.Fuse)
	Remotes.SellDuplicate.OnServerInvoke = guarded(SummonService.SellDuplicate)
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return SummonService
