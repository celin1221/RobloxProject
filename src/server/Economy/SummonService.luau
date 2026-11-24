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
local Gyms = require(Data:WaitForChild("Gyms"))
local Progression = require(Data.Progression)
local AccountLevel = require(Data:WaitForChild("AccountLevel"))
local Benefits = require(Data.Benefits)
local Genetics = require(Data:WaitForChild("Genetics"))

local DataFolder = ServerScriptService:WaitForChild("Data")
local PlayerDataService = require(DataFolder:WaitForChild("PlayerDataService"))
local AccountLevelService = require(DataFolder:WaitForChild("AccountLevelService"))
local ProgressionService = require(DataFolder:WaitForChild("ProgressionService"))
local RetentionService = require(DataFolder:WaitForChild("RetentionService"))
local BattleService = require(ServerScriptService:WaitForChild("Battle"):WaitForChild("BattleService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local SummonService = {}

local MAX_TEAM = 6
local rng = Random.new()
local busy = {} -- [Player] = true durante um pedido

-- Confere se o banner esta desbloqueado para o jogador ("Todos" e sempre aberto; banners de anime exigem inicial ou Ginasio)
function SummonService.IsBannerUnlocked(data, bannerId: string?): (boolean, any)
	local cfg = Summon.GetBanner(bannerId)
	if not cfg or not cfg.Anime then
		return true, nil
	end
	local gym = Gyms.ForBanner(cfg.Id)
	if not gym then
		return true, nil
	end
	local unlocked = data and typeof(data.UnlockedBanners) == "table" and data.UnlockedBanners[gym.Anime] == true
	return unlocked == true, gym
end

-- Animes permitidos no banner "Todos" para este jogador (apenas os desbloqueados; fallback para Generico se nenhum ainda)
local function unlockedAnimeSet(data): { [string]: boolean }
	local set = {}
	local any = false
	if data and typeof(data.UnlockedBanners) == "table" then
		for animeId, on in pairs(data.UnlockedBanners) do
			if on == true then
				set[animeId] = true
				any = true
			end
		end
	end
	if not any then
		set.Generico = true
	end
	return set
end

-- Personagens do elenco por raridade (filtrados por Anime ou por conjunto de Animes desbloqueados)
local function byRarity(animeFilter: string?, allowedAnimes: { [string]: boolean }?)
	local map = {}
	for id, def in pairs(Characters.List) do
		if not def.Prototype then
			local anime = Characters.AnimeOf(id)
			local ok = if animeFilter then (anime == animeFilter) elseif allowedAnimes then (allowedAnimes[anime] == true) else true
			if ok then
				map[def.Rarity] = map[def.Rarity] or {}
				table.insert(map[def.Rarity], id)
			end
		end
	end
	for _, list in pairs(map) do
		table.sort(list)
	end
	return map
end

local function resolveBanner(bannerId: string?)
	if bannerId ~= nil and (typeof(bannerId) ~= "string" or not Summon.Banners[bannerId]) then
		return nil
	end
	return Summon.GetBanner(bannerId)
end

function SummonService.Legendaries(animeFilter: string?, allowedAnimes: { [string]: boolean }?): { string }
	return byRarity(animeFilter, allowedAnimes).Lendario or {}
end

function SummonService.BannerOf(portalId: string, bannerId: string?, allowedAnimes: { [string]: boolean }?): string?
	local cfg = resolveBanner(bannerId)
	local animeFilter = cfg and cfg.Anime or nil
	return Summon.BannerOf(portalId, os.time(), SummonService.Legendaries(animeFilter, if animeFilter then nil else allowedAnimes))
end

local function pickCharacter(rarity: string, banner: string?, share: number?, animeFilter: string?, allowedAnimes: { [string]: boolean }?)
	local map = byRarity(animeFilter, if animeFilter then nil else allowedAnimes)
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

-- Faz as invocacoes. Retorna (true, resultados) ou (false, motivo).
function SummonService.Summon(player: Player, portalId: string, count: number, bannerId: string?)
	local portal = Summon.Portals[portalId]
	if not portal then
		return false, "Portal inv\u{e1}lido."
	end
	local bannerCfg = resolveBanner(bannerId)
	if not bannerCfg then
		return false, "Estrela/Anime inv\u{e1}lido."
	end
	local animeFilter = bannerCfg.Anime
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
	local unlocked, reqGym = SummonService.IsBannerUnlocked(data, bannerCfg.Id)
	if not unlocked then
		local gymName = if reqGym then reqGym.Name else ("Gin\u{e1}sio de " .. (bannerCfg.Name or bannerCfg.Id))
		return false, "Banner trancado! Ven\u{e7}a o " .. gymName .. " na Torre para desbloquear."
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
	local allowedAnimes = if not animeFilter then unlockedAnimeSet(data) else nil
	local banner = SummonService.BannerOf(portalId, bannerCfg.Id, allowedAnimes)
	for i = 1, count do
		local rarity, forced, newPity, shiny = Summon.Roll(portalId, rng, pity, rates)
		pity = newPity
		local charId = pickCharacter(rarity, banner, portal.Banner and portal.Banner.Share, animeFilter, allowedAnimes)
		local def = Characters.Get(charId)
		local isNew = data.Album.Owned[charId] == nil
		local variant = if shiny then "Brilhante" else nil
		local toTeam = #data.Team < MAX_TEAM
		local uid, albumLines = ProgressionService.AddCharacter(player, charId, Summon.SummonLevel, toTeam, variant, nil, { Source = "Summon" })
		local member = data.Collection[uid]
		table.insert(results, {
			Uid = uid,
			CharacterId = charId,
			Name = def.Name,
			ModelName = def.ModelName or charId,
			Anime = def.Anime or "Generico",
			BannerId = bannerCfg.Id,
			Type = def.Type,
			Rarity = def.Rarity, -- raridade do personagem entregue
			Rolled = rarity, -- raridade sorteada
			Forced = forced, -- veio pela garantia
			Banner = banner ~= nil and charId == banner,
			Variant = variant,
			Genetics = member and member.Genetics,
			New = isNew,
			Album = albumLines,
		})
	end
	data.SummonPity[portal.PityKey] = pity
	RetentionService.Track(player, "Summon", count)
	local perSummon = if portalId == "Premium" then AccountLevel.XpSources.SummonPremium else AccountLevel.XpSources.SummonComum
	AccountLevelService.AddXp(player, count * perSummon, "Invoca\u{e7}\u{e3}o", false)
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

local function inTraining(data, uid: string): boolean
	return data.TrainingMachine and data.TrainingMachine.Job and data.TrainingMachine.Job.Uid == uid or false
end

local function protectedFromConsume(data, uid: string): boolean
	return inTeam(data, uid) or inTraining(data, uid)
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
		if a.Level ~= b.Level then
			return a.Level > b.Level
		end
		local ga = Genetics.Total(a.Genetics) + Genetics.Total(a.Training)
		local gb = Genetics.Total(b.Genetics) + Genetics.Total(b.Training)
		return ga > gb
	end)
	local target = copies[1]
	if (target.Stars or 0) >= Summon.Stars.Max then
		return false, "J\u{e1} tem " .. Summon.Stars.Max .. " estrelas."
	end
	local fodder = {}
	for i = #copies, 2, -1 do
		local m = copies[i]
		if not protectedFromConsume(data, m.Uid) and #fodder < Summon.Stars.CopiesPerStar - 1 then
			table.insert(fodder, m)
		end
	end
	if #fodder < Summon.Stars.CopiesPerStar - 1 then
		return false, "Tire do time ou da c\u{e1}psula as c\u{f3}pias extras para fundir."
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
		if a.Level ~= b.Level then
			return a.Level < b.Level
		end
		local ga = Genetics.Total(a.Genetics) + Genetics.Total(a.Training)
		local gb = Genetics.Total(b.Genetics) + Genetics.Total(b.Training)
		return ga < gb
	end)
	local sold
	for _, m in ipairs(copies) do
		if not protectedFromConsume(data, m.Uid) then
			sold = m
			break
		end
	end
	if not sold then
		return false, "Todas as c\u{f3}pias est\u{e3}o no time ou em treino."
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
	Remotes.Summon.OnServerInvoke = guarded(function(player, portalId, count, bannerId)
		return SummonService.Summon(player, portalId, count, bannerId)
	end)
	-- destaque da semana do Portal Premium (para a tela, considerando o painel/anime escolhido)
	local bannerRF = Remotes:FindFirstChild("SummonBanner")
	if bannerRF then
		bannerRF.OnServerInvoke = function(player, portalId, bannerId)
			if typeof(portalId) ~= "string" or not Summon.Portals[portalId] then
				return nil
			end
			if bannerId ~= nil and (typeof(bannerId) ~= "string" or not Summon.Banners[bannerId]) then
				return nil
			end
			local data = PlayerDataService.Get(player)
			local cfg = resolveBanner(bannerId)
			local allowed = if cfg and not cfg.Anime then unlockedAnimeSet(data) else nil
			local id = SummonService.BannerOf(portalId, bannerId, allowed)
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
