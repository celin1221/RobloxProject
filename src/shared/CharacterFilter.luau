--[[
	CharacterFilter (compartilhado): busca por nome, filtros (anime, raridade, tipo) e ordenacao por status.
	Usado pela tela de Equipe, pela Mochila e reutilizavel em futuros modos (ex.: Torre).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = ReplicatedStorage:WaitForChild("Data")
local Characters = require(Data:WaitForChild("Characters"))
local Progression = require(Data:WaitForChild("Progression"))

local CharacterFilter = {}

CharacterFilter.RarityOrder = { Comum = 1, Raro = 2, Epico = 3, Lendario = 4 }
CharacterFilter.Rarities = { "Todas", "Comum", "Raro", "Epico", "Lendario" }
CharacterFilter.Types = { "Todos", "Espadachim", "Lutador", "Mago", "Atirador" }
CharacterFilter.Sorts = { "Raridade", "Geral", "HP", "Attack", "Defense", "Speed", "Nivel", "Recente" }

local animes = { "Todos" }
for _, animeId in ipairs(Characters.AnimeOrder or {}) do
	table.insert(animes, animeId)
end
CharacterFilter.Animes = animes

local labels = {
	Todas = "TODAS", Comum = "COMUM", Raro = "RARO", Epico = "\u{c9}PICO", Lendario = "LEND\u{c1}RIO",
	Todos = "CLASSE: TODAS", Espadachim = "ESPADACHIM", Lutador = "LUTADOR", Mago = "MAGO", Atirador = "ATIRADOR",
	Raridade = "RARIDADE", Nivel = "N\u{cd}VEL", Recente = "RECENTE",
	Geral = "STATUS GERAL", HP = "STATUS: HP", Attack = "STATUS: ATQ", Defense = "STATUS: DEF", Speed = "STATUS: VEL",
	Time = "ORD: TIME",
}
local animeLabels = {
	Todos = "ANIME: TODOS",
}
for animeId, info in pairs(Characters.Animes or {}) do
	animeLabels[animeId] = info.Short or string.upper(info.Name or animeId)
end
CharacterFilter.Labels = labels
CharacterFilter.AnimeLabels = animeLabels

local ACCENT_FOLD = {
	["\u{e1}"] = "a", ["\u{c1}"] = "a", ["\u{e0}"] = "a", ["\u{c0}"] = "a", ["\u{e2}"] = "a", ["\u{c2}"] = "a", ["\u{e3}"] = "a", ["\u{c3}"] = "a",
	["\u{e9}"] = "e", ["\u{c9}"] = "e", ["\u{ea}"] = "e", ["\u{ca}"] = "e",
	["\u{ed}"] = "i", ["\u{cd}"] = "i",
	["\u{f3}"] = "o", ["\u{d3}"] = "o", ["\u{f4}"] = "o", ["\u{d4}"] = "o", ["\u{f5}"] = "o", ["\u{d5}"] = "o",
	["\u{fa}"] = "u", ["\u{da}"] = "u",
	["\u{e7}"] = "c", ["\u{c7}"] = "c",
}

function CharacterFilter.Normalize(text: string?): string
	local s = tostring(text or "")
	for k, v in pairs(ACCENT_FOLD) do
		s = string.gsub(s, k, v)
	end
	s = string.lower(s)
	s = string.gsub(s, "%s+", " ")
	s = string.gsub(s, "^%s+", "")
	s = string.gsub(s, "%s+$", "")
	return s
end

function CharacterFilter.TotalStats(stats): number
	if not stats then
		return 0
	end
	return (stats.HP or 0) + (stats.Attack or 0) + (stats.Defense or 0) + (stats.Speed or 0)
end

function CharacterFilter.StatValue(stats, sortKey: string): number
	if not stats then
		return 0
	end
	if sortKey == "HP" then
		return stats.HP or 0
	elseif sortKey == "Attack" then
		return stats.Attack or 0
	elseif sortKey == "Defense" then
		return stats.Defense or 0
	elseif sortKey == "Speed" then
		return stats.Speed or 0
	end
	return CharacterFilter.TotalStats(stats)
end

function CharacterFilter.LabelFor(kind: string, value: string): string
	if kind == "Anime" then
		return animeLabels[value] or string.upper(Characters.AnimeDisplay(value))
	end
	return labels[value] or string.upper(tostring(value))
end

function CharacterFilter.Matches(def, opts): boolean
	if not def then
		return false
	end
	opts = opts or {}
	local af = opts.Anime or "Todos"
	if af ~= "Todos" and Characters.AnimeOf(def.Id) ~= af then
		return false
	end
	local rf = opts.Rarity or "Todas"
	if rf ~= "Todas" and def.Rarity ~= rf then
		return false
	end
	local tf = opts.Type or "Todos"
	if tf ~= "Todos" and def.Type ~= tf then
		return false
	end
	local q = opts._NormalizedSearch
	if q == nil then
		q = CharacterFilter.Normalize(opts.Search)
	end
	if q ~= "" then
		local nameNorm = CharacterFilter.Normalize(def.Name)
		local idNorm = CharacterFilter.Normalize(def.Id)
		if not string.find(nameNorm, q, 1, true) and not string.find(idNorm, q, 1, true) then
			return false
		end
	end
	return true
end

function CharacterFilter.FilterAndSort(collection, opts)
	local list = {}
	local statsByUid = {}
	if not collection then
		return list, statsByUid
	end
	opts = opts or {}
	local normalized = {
		Anime = opts.Anime or "Todos",
		Rarity = opts.Rarity or "Todas",
		Type = opts.Type or "Todos",
		_NormalizedSearch = CharacterFilter.Normalize(opts.Search),
	}
	for uid, m in pairs(collection) do
		local def = m and Characters.Get(m.CharacterId)
		if def and CharacterFilter.Matches(def, normalized) then
			statsByUid[uid] = Progression.MemberStats(m)
			table.insert(list, uid)
		end
	end

	local sortKey = opts.Sort or "Raridade"
	local teamRank = {}
	if opts.Team then
		for i, uid in ipairs(opts.Team) do
			teamRank[uid] = i
		end
	end

	table.sort(list, function(a, b)
		local ma, mb = collection[a], collection[b]
		local da, db = Characters.Get(ma.CharacterId), Characters.Get(mb.CharacterId)
		local ra, rb = CharacterFilter.RarityOrder[da.Rarity] or 0, CharacterFilter.RarityOrder[db.Rarity] or 0
		local sa, sb = statsByUid[a], statsByUid[b]
		local ta, tb = CharacterFilter.TotalStats(sa), CharacterFilter.TotalStats(sb)

		if sortKey == "Time" then
			local ia, ib = teamRank[a] or 9999, teamRank[b] or 9999
			if ia ~= ib then
				return ia < ib
			end
			if ta ~= tb then
				return ta > tb
			end
		elseif sortKey == "Geral" or sortKey == "HP" or sortKey == "Attack" or sortKey == "Defense" or sortKey == "Speed" then
			local va, vb = CharacterFilter.StatValue(sa, sortKey), CharacterFilter.StatValue(sb, sortKey)
			if va ~= vb then
				return va > vb
			end
			if ta ~= tb then
				return ta > tb
			end
			if ra ~= rb then
				return ra > rb
			end
			if (ma.Level or 1) ~= (mb.Level or 1) then
				return (ma.Level or 1) > (mb.Level or 1)
			end
		elseif sortKey == "Recente" then
			if (ma.ObtainedAt or 0) ~= (mb.ObtainedAt or 0) then
				return (ma.ObtainedAt or 0) > (mb.ObtainedAt or 0)
			end
			if ra ~= rb then
				return ra > rb
			end
		elseif sortKey == "Nivel" then
			if (ma.Level or 1) ~= (mb.Level or 1) then
				return (ma.Level or 1) > (mb.Level or 1)
			end
			if ra ~= rb then
				return ra > rb
			end
			if ta ~= tb then
				return ta > tb
			end
		else
			if ra ~= rb then
				return ra > rb
			end
			if (ma.Level or 1) ~= (mb.Level or 1) then
				return (ma.Level or 1) > (mb.Level or 1)
			end
			if ta ~= tb then
				return ta > tb
			end
		end

		local na, nb = CharacterFilter.Normalize(da.Name), CharacterFilter.Normalize(db.Name)
		if na ~= nb then
			return na < nb
		end
		return a < b
	end)

	return list, statsByUid
end

function CharacterFilter.CreateState(config)
	config = config or {}
	local sorts = config.Sorts or CharacterFilter.Sorts
	local animeIdx, rarityIdx, typeIdx, sortIdx = 1, 1, 1, 1
	if config.DefaultSort then
		local found = table.find(sorts, config.DefaultSort)
		if found then
			sortIdx = found
		end
	end
	local search = ""

	local state = {}
	function state.Anime(): string
		return CharacterFilter.Animes[animeIdx] or "Todos"
	end
	function state.Rarity(): string
		return CharacterFilter.Rarities[rarityIdx] or "Todas"
	end
	function state.Type(): string
		return CharacterFilter.Types[typeIdx] or "Todos"
	end
	function state.Sort(): string
		return sorts[sortIdx] or "Raridade"
	end
	function state.Search(): string
		return search
	end
	function state.SetSearch(text: string?)
		search = text or ""
	end
	function state.NextAnime(): string
		animeIdx = animeIdx % #CharacterFilter.Animes + 1
		return state.Anime()
	end
	function state.NextRarity(): string
		rarityIdx = rarityIdx % #CharacterFilter.Rarities + 1
		return state.Rarity()
	end
	function state.NextType(): string
		typeIdx = typeIdx % #CharacterFilter.Types + 1
		return state.Type()
	end
	function state.NextSort(): string
		sortIdx = sortIdx % #sorts + 1
		return state.Sort()
	end
	function state.Options(extra)
		local opts = {
			Anime = state.Anime(),
			Rarity = state.Rarity(),
			Type = state.Type(),
			Sort = state.Sort(),
			Search = search,
		}
		if extra then
			for k, v in pairs(extra) do
				opts[k] = v
			end
		end
		return opts
	end
	function state.Apply(collection, extra)
		return CharacterFilter.FilterAndSort(collection, state.Options(extra))
	end
	return state
end

return CharacterFilter
