--[[
	PvPRank (Data/PvPRank - Patentes, ELO e Recompensa Diaria do PvP 2x2 / 1x1)
	So dados e funcoes matematicas puras (sem estado mutavel).
	Foco competitivo no 2x2 (maior ganho de ELO e melhor recompensa em Gold + Doce),
	mantendo Gemas raras (recompensas diarias do PvP pagam Gold e Doces de XP).
]]

local PvPRank = {}

PvPRank.StartRating = 1000
PvPRank.MinRating = 800
PvPRank.MaxRating = 9999
PvPRank.DailyRewardCap = 3 -- ate 3 vitorias premiadas por dia UTC (com trava anti-farm por oponente)
PvPRank.StoreName = "PvPRank_v1"
PvPRank.LeaderboardSize = 10

PvPRank.Tiers = {
	{ Id = "Bronze", Name = "Bronze", Min = 0, Color = "orange" },
	{ Id = "Prata", Name = "Prata", Min = 1100, Color = "comum" },
	{ Id = "Ouro", Name = "Ouro", Min = 1250, Color = "gold" },
	{ Id = "Platina", Name = "Platina", Min = 1450, Color = "teal" },
	{ Id = "Diamante", Name = "Diamante", Min = 1700, Color = "blue" },
	{ Id = "Lenda", Name = "Lenda", Min = 2000, Color = "lendario" },
}

-- Recompensa diaria por vitoria (ate DailyRewardCap/dia; 1x por oponente/dia)
PvPRank.WinReward = {
	["2x2"] = { Gold = 450, Item = "DoceComum" },
	["1x1"] = { Gold = 300 },
}
PvPRank.ParticipationGold = 100 -- premio de participacao ao perder sem abandonar imediatamente

function PvPRank.Day(now: number): number
	return now // 86400
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

-- Calcula (gainWinner, lossLoser) usando formula ELO padrao (2x2 vale mais pontos!)
function PvPRank.Delta(winnerRating: number?, loserRating: number?, format: string?): (number, number)
	local w = if typeof(winnerRating) == "number" then winnerRating else PvPRank.StartRating
	local l = if typeof(loserRating) == "number" then loserRating else PvPRank.StartRating
	local k = if format == "2x2" then 32 else 24
	local expected = 1 / (1 + 10 ^ ((l - w) / 400))
	local gain = math.max(8, math.floor(k * (1 - expected) + 0.5))
	local loss = math.max(6, math.floor(gain * 0.8 + 0.5))
	return gain, loss
end

function PvPRank.DefaultState()
	return {
		Rating = PvPRank.StartRating,
		BestRating = PvPRank.StartRating,
		Wins = 0,
		Losses = 0,
		Wins2x2 = 0,
		Losses2x2 = 0,
		DailyDay = 0,
		DailyRewards = 0,
		OpponentsToday = {}, -- [userIdStr] = true (anti-farm: 1 vez por oponente/dia)
	}
end

return PvPRank
