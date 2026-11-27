--[[
	PvPRank (Data/PvPRank - Filas Competitiva e Casual 1x1/2x2, ELO Separado, Regras VGC e Temporada Mensal)
	So dados e funcoes matematicas puras (sem estado mutavel e sem APIs de servidor).
	- Competitivo 1x1 e Competitivo 2x2 possuem ELO, Patente e Ranking Global independentes.
	- Regras da Ranqueada (estilo Pokemon VGC):
	    * Nivel 50, BST da colecao normalizado (1.00x) e Secreto normalizado no patamar de Lendario.
	    * Estrelas, Variantes e +10% do Despertar ficam apenas visuais (0% bonus de stats).
	    * Genetica, Treino da Capsula e Passiva Secreta (se Desperto) CONTAM normalmente.
	    * Species Clause (sem repetidos) + Limite de Elite (max. 1 Secreto e ate 2 Lendarios).
	- Casual 1x1 e Casual 2x2 (e Duelo Amistoso na praca): poder real nao normalizado ("vale tudo"), sem ELO.
	- Temporada Mensal do Competitivo: premia Gemas enxutas pela melhor Patente + Tag Top 100 / Lenda.
]]

local Characters = require(script.Parent:WaitForChild("Characters"))

local PvPRank = {}

PvPRank.StartRating = 1000
PvPRank.MinRating = 800
PvPRank.MaxRating = 9999
PvPRank.DailyRewardCap = 3 -- ate 3 vitorias premiadas por dia UTC nas filas PvP
PvPRank.LeaderboardSize = 10
PvPRank.SeasonTopCutoff = 100
PvPRank.LegacyStoreName = "PvPRank_v1"
PvPRank.StoreName = "PvPRank2x2_v1" -- alias de compatibilidade
PvPRank.StoreNames = {
	["1x1"] = "PvPRank1x1_v1",
	["2x2"] = "PvPRank2x2_v1",
}
PvPRank.SeasonStorePrefix = "PvPSeason_"

PvPRank.Tiers = {
	{ Id = "Bronze", Name = "Bronze", Min = 0, Color = "orange", SeasonGems = 0 },
	{ Id = "Prata", Name = "Prata", Min = 1100, Color = "comum", SeasonGems = 15 },
	{ Id = "Ouro", Name = "Ouro", Min = 1250, Color = "gold", SeasonGems = 30 },
	{ Id = "Platina", Name = "Platina", Min = 1450, Color = "teal", SeasonGems = 50 },
	{ Id = "Diamante", Name = "Diamante", Min = 1700, Color = "blue", SeasonGems = 75 },
	{ Id = "Lenda", Name = "Lenda", Min = 2000, Color = "lendario", SeasonGems = 110 },
}

-- Regras oficiais do time no Competitivo
PvPRank.RankedRules = {
	NormalizedLevel = 50,
	UniqueSpecies = true,
	MaxLegendary = 2,
	MaxSecret = 1,
}

-- Filas oficiais disponiveis no Hub Arena PvP
PvPRank.QueueOrder = { "Ranked2x2", "Ranked1x1", "Casual2x2", "Casual1x1" }
PvPRank.Queues = {
	Ranked2x2 = {
		Id = "Ranked2x2",
		Title = "COMPETITIVO 2x2",
		Short = "RANK 2x2",
		Mode = "Ranked",
		Format = "2x2",
		IsRanked = true,
		MinTeam = 2,
		Color = "lendario",
		Desc = "Nv. 50 \u{b7} BST normalizado \u{b7} Valendo ELO 2x2",
		RewardText = "+1.500g + Doce Comum (3x/dia)",
	},
	Ranked1x1 = {
		Id = "Ranked1x1",
		Title = "COMPETITIVO 1x1",
		Short = "RANK 1x1",
		Mode = "Ranked",
		Format = "1x1",
		IsRanked = true,
		MinTeam = 1,
		Color = "blue",
		Desc = "Nv. 50 \u{b7} BST normalizado \u{b7} Valendo ELO 1x1",
		RewardText = "+1.100g (3x/dia)",
	},
	Casual2x2 = {
		Id = "Casual2x2",
		Title = "CASUAL 2x2",
		Short = "CASUAL 2x2",
		Mode = "Casual",
		Format = "2x2",
		IsRanked = false,
		MinTeam = 2,
		Color = "orange",
		Desc = "Poder real sem normaliza\u{e7}\u{e3}o \u{b7} Vale tudo",
		RewardText = "+600g (3x/dia) \u{b7} Sem ELO",
	},
	Casual1x1 = {
		Id = "Casual1x1",
		Title = "CASUAL 1x1",
		Short = "CASUAL 1x1",
		Mode = "Casual",
		Format = "1x1",
		IsRanked = false,
		MinTeam = 1,
		Color = "green",
		Desc = "Poder real sem normaliza\u{e7}\u{e3}o \u{b7} Vale tudo",
		RewardText = "+450g (3x/dia) \u{b7} Sem ELO",
	},
}

-- Expansao progressiva da janela de ELO na fila global (nunca usa Bots na Ranqueada)
PvPRank.MatchWindows = {
	{ Wait = 0, Range = 100 },
	{ Wait = 15, Range = 250 },
	{ Wait = 30, Range = 500 },
	{ Wait = 50, Range = 9999 },
}

-- Recompensa diaria por vitoria (ate DailyRewardCap/dia; Competitivo 2x2 > 1x1 > Casual; gemas continuam raras)
PvPRank.WinReward = {
	["2x2"] = { Gold = 1500, Item = "DoceComum" },
	["1x1"] = { Gold = 1100 },
	Casual2x2 = { Gold = 600 },
	Casual1x1 = { Gold = 450 },
}
PvPRank.ParticipationGold = 350 -- premio de participacao ao perder sem abandonar imediatamente

function PvPRank.Day(now: number): number
	return now // 86400
end

-- Temporada mensal UTC ("YYYY-MM") alinhada com Retention.SeasonId
function PvPRank.SeasonId(now: number): string
	local t = os.date("!*t", now)
	return string.format("%04d-%02d", t.year, t.month)
end

function PvPRank.SeasonEnd(now: number): number
	local t = os.date("!*t", now)
	local year, month = t.year, t.month + 1
	if month > 12 then
		month = 1
		year += 1
	end
	return os.time({ year = year, month = month, day = 1, hour = 0, min = 0, sec = 0 })
end

function PvPRank.TierFor(rating: number?)
	local r = if typeof(rating) == "number" then rating else PvPRank.StartRating
	local pick = PvPRank.Tiers[1]
	for _, tier in ipairs(PvPRank.Tiers) do
		if r >= tier.Min then
			pick = tier
		end
	end
	return pick
end

function PvPRank.QueueConfig(queueId: string?)
	if typeof(queueId) ~= "string" then
		return nil
	end
	return PvPRank.Queues[queueId]
end

function PvPRank.QueueIdFor(mode: string?, format: string?): string
	local isRanked = mode == "Ranked"
	local is2x2 = format == "2x2"
	if isRanked then
		return if is2x2 then "Ranked2x2" else "Ranked1x1"
	end
	return if is2x2 then "Casual2x2" else "Casual1x1"
end

function PvPRank.AllowedEloGap(waitSeconds: number): number
	local w = math.max(0, tonumber(waitSeconds) or 0)
	local allowed = PvPRank.MatchWindows[1].Range
	for _, step in ipairs(PvPRank.MatchWindows) do
		if w >= step.Wait then
			allowed = step.Range
		end
	end
	return allowed
end

-- Calcula (gainWinner, lossLoser) usando formula ELO padrao (2x2 vale K=32; 1x1 vale K=24)
function PvPRank.Delta(winnerRating: number?, loserRating: number?, format: string?): (number, number)
	local w = if typeof(winnerRating) == "number" then winnerRating else PvPRank.StartRating
	local l = if typeof(loserRating) == "number" then loserRating else PvPRank.StartRating
	local k = if format == "2x2" then 32 else 24
	local expected = 1 / (1 + 10 ^ ((l - w) / 400))
	local gain = math.max(8, math.floor(k * (1 - expected) + 0.5))
	local loss = math.max(6, math.floor(gain * 0.8 + 0.5))
	return gain, loss
end

-- Valida se um time cumpre todas as regras do Competitivo (Species Clause + Limite de Elite)
-- Aceita lista de entradas com CharacterId (membros da colecao ou objetos de time)
function PvPRank.ValidateRankedTeam(members: { any }?, format: string?): (boolean, string?, { Total: number, Legendaries: number, Secrets: number, Duplicates: { string } })
	local counts = { Total = 0, Legendaries = 0, Secrets = 0, Duplicates = {} }
	if typeof(members) ~= "table" or #members == 0 then
		return false, "Monte seu time antes de entrar na Ranqueada.", counts
	end
	local minNeed = if format == "2x2" then 2 else 1
	local seen: { [string]: boolean } = {}
	for _, m in ipairs(members) do
		local cid = if typeof(m) == "table" then (m.CharacterId or m.Id) elseif typeof(m) == "string" then m else nil
		if typeof(cid) == "string" then
			local def = Characters.Get(cid)
			if def then
				counts.Total += 1
				if seen[cid] then
					if not table.find(counts.Duplicates, def.Name or cid) then
						table.insert(counts.Duplicates, def.Name or cid)
					end
				else
					seen[cid] = true
				end
				if def.Rarity == "Lendario" then
					counts.Legendaries += 1
				elseif def.Rarity == "Secreto" then
					counts.Secrets += 1
				end
			end
		end
	end
	if counts.Total < minNeed then
		return false, string.format("Precisa de pelo menos %d personagens no time para %s.", minNeed, format or "1x1"), counts
	end
	if PvPRank.RankedRules.UniqueSpecies and #counts.Duplicates > 0 then
		return false, "Ranqueada n\u{e3}o permite personagens repetidos: " .. table.concat(counts.Duplicates, ", ") .. ".", counts
	end
	if counts.Secrets > PvPRank.RankedRules.MaxSecret then
		return false, string.format("Ranqueada permite no m\u{e1}ximo %d Secreto no time (voc\u{ea} tem %d).", PvPRank.RankedRules.MaxSecret, counts.Secrets), counts
	end
	if counts.Legendaries > PvPRank.RankedRules.MaxLegendary then
		return false, string.format("Ranqueada permite no m\u{e1}ximo %d Lend\u{e1}rios no time (voc\u{ea} tem %d).", PvPRank.RankedRules.MaxLegendary, counts.Legendaries), counts
	end
	return true, nil, counts
end

function PvPRank.DefaultModeSlot(rating: number?)
	local r = if typeof(rating) == "number" then rating else PvPRank.StartRating
	return {
		Rating = r,
		BestRating = r,
		Wins = 0,
		Losses = 0,
	}
end

function PvPRank.DefaultState()
	return {
		Rating = PvPRank.StartRating, -- espelho do maior ELO (1x1 ou 2x2) para compatibilidade e leaderstats
		BestRating = PvPRank.StartRating,
		Wins = 0,
		Losses = 0,
		Wins2x2 = 0,
		Losses2x2 = 0,
		Mode1x1 = PvPRank.DefaultModeSlot(PvPRank.StartRating),
		Mode2x2 = PvPRank.DefaultModeSlot(PvPRank.StartRating),
		SeasonId = "",
		LastSeason = nil,
		DailyDay = 0,
		DailyRewards = 0,
		OpponentsToday = {}, -- [userIdStr] = true
	}
end

function PvPRank.ModeSlotOf(pvpState: any, format: string?)
	if typeof(pvpState) ~= "table" then
		return PvPRank.DefaultModeSlot(PvPRank.StartRating)
	end
	if format == "1x1" then
		return pvpState.Mode1x1 or PvPRank.DefaultModeSlot(pvpState.Rating)
	end
	return pvpState.Mode2x2 or PvPRank.DefaultModeSlot(pvpState.Rating)
end

function PvPRank.BestRatingOf(pvpState: any): number
	if typeof(pvpState) ~= "table" then
		return PvPRank.StartRating
	end
	local r1 = (pvpState.Mode1x1 and tonumber(pvpState.Mode1x1.Rating)) or tonumber(pvpState.Rating) or PvPRank.StartRating
	local r2 = (pvpState.Mode2x2 and tonumber(pvpState.Mode2x2.Rating)) or tonumber(pvpState.Rating) or PvPRank.StartRating
	return math.max(r1, r2)
end

return PvPRank
