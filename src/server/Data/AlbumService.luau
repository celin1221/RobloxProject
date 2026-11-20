--[[
	AlbumService (GDD secao 13 - Album)
	Registra todo personagem e variante ja obtidos (vender ou fundir nao apaga do album).
	Completar cada tipo e cada raridade paga gold e gemas uma vez (Data/Summon.AlbumReward).
	Grupos sem nenhum personagem no elenco nao contam.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = ReplicatedStorage:WaitForChild("Data")
local Characters = require(Data.Characters)
local Summon = require(Data.Summon)
local TypeChart = require(Data.TypeChart)

local AlbumService = {}

local function groups()
	local byType, byRarity = {}, {}
	for id, def in pairs(Characters.List) do
		if def.Prototype then
			continue -- prototipos de teste ficam fora do album
		end
		byType[def.Type] = byType[def.Type] or {}
		table.insert(byType[def.Type], id)
		byRarity[def.Rarity] = byRarity[def.Rarity] or {}
		table.insert(byRarity[def.Rarity], id)
	end
	return byType, byRarity
end
AlbumService.Groups = groups

-- Marca como obtido e paga premios novos. Retorna mensagens.
function AlbumService.Record(data, characterId: string, variant: string?)
	local album = data.Album
	local entry = album.Owned[characterId]
	if not entry then
		entry = { Variants = {} }
		album.Owned[characterId] = entry
	end
	if variant then
		entry.Variants[variant] = true
	end
	return AlbumService.CheckRewards(data)
end

function AlbumService.CheckRewards(data)
	local lines = {}
	local album = data.Album
	local byType, byRarity = groups()
	local function check(key, list, label)
		if album.Claimed[key] or #list == 0 then
			return
		end
		for _, id in ipairs(list) do
			if not album.Owned[id] then
				return
			end
		end
		album.Claimed[key] = true
		data.Gold += Summon.AlbumReward.Gold
		data.Gems += Summon.AlbumReward.Gems
		table.insert(lines, "\u{c1}lbum: " .. label .. " completo! +" .. Summon.AlbumReward.Gold .. " gold e +" .. Summon.AlbumReward.Gems .. " gemas.")
	end
	for typeId, list in pairs(byType) do
		check("Tipo:" .. typeId, list, "tipo " .. ((TypeChart.DisplayName and TypeChart.DisplayName[typeId]) or typeId))
	end
	for rarity, list in pairs(byRarity) do
		check("Raridade:" .. rarity, list, "raridade " .. (Summon.RarityName[rarity] or rarity))
	end
	return lines
end

-- Perfis antigos: registra no album o que ja esta na colecao
function AlbumService.Backfill(data)
	for _, m in pairs(data.Collection) do
		local entry = data.Album.Owned[m.CharacterId]
		if not entry then
			entry = { Variants = {} }
			data.Album.Owned[m.CharacterId] = entry
		end
		if m.Variant then
			entry.Variants[m.Variant] = true
		end
	end
	return AlbumService.CheckRewards(data)
end

return AlbumService
