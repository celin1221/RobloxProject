--!strict
--[[
	AccountLevel: sistema balanceado de Nivel da Conta (inspirado em Anime Vanguards / TDS / ASTD).
	- O nivel da conta NUNCA diminui, apenas cresce continuamente (sem teto travado).
	- Curva de XP em 3 fases (estilo Tower Defense):
	    1..10  (Inicio rapido):  90 + 35*L + 4*L^2     (1-2 batalhas por nivel para engajar logo no comeco)
	    11..30 (Meio estavel):  240 + 55*L + 5*L^2     (3-5 batalhas por nivel)
	    31+    (Veterano):      6390 + (L - 30) * 380  (crescimento linear suave, nunca vira parede impossivel)
	- Recompensas exclusivas para TODOS os niveis (1..50+ escalando infinitamente):
	    * Niveis comuns: rotacao equilibrada de Gold, Pocoes/Selos/Doces de XP, Gemas e Tickets Comuns.
	    * A cada 5 niveis (5, 15, 25...): MARCO EPICO (Gold + Gemas + Invocacao Comum + Doce Raro).
	    * A cada 10 niveis (10, 20, 30...): MARCO LENDARIO (Jackpot de Gold + Gemas + Invocacao Premium + Doce Epico).
]]

local AccountLevel = {}

AccountLevel.DefaultDisplayMax = 50 -- minimo de niveis exibidos na lista de recompensas (expande automaticamente se passar de 50)

-- Fontes de XP da conta (balanceadas para a economia real do jogo)
AccountLevel.XpSources = {
	BattleWinBase = 30,
	BattleWinPerEnemyLevel = 1.5,
	TowerModeComplete = {
		Facil = 90,
		Medio = 240,
		Dificil = 550,
	},
	TowerInfiniteBase = 45,
	TowerInfinitePerFloor = 4,
	TowerInfiniteBossBonus = 140,
	GymWin = 180,
	PvPWin = 90,
	StarterStep = 60,
	SummonComum = 15,
	SummonPremium = 35,
	BaseCollectGoldDivisor = 25,
	BaseCollectMin = 5,
	BaseCollectMax = 90,
	BaseCollectCooldown = 120, -- segundos entre creditos de XP de conta na coleta (evita spam/exploit)
	TrainingClaim = 75,
	DailyMission = 100,
	AllDailyBonus = 150,
	WeeklyMission = 250,
	AllWeeklyBonus = 500,
	RefugeCapture = 45,
	RefugeWildDefeat = 25,
}

-- XP necessario para subir do nivel `level` para `level + 1`
function AccountLevel.XpToNext(level: number): number
	local lv = math.max(1, math.floor(level))
	if lv <= 10 then
		return math.floor(90 + lv * 35 + lv * lv * 4)
	elseif lv <= 30 then
		return math.floor(240 + lv * 55 + lv * lv * 5)
	else
		return math.floor(6390 + (lv - 30) * 380)
	end
end

-- XP ganho ao vencer uma batalha (respeita soma dos niveis inimigos)
function AccountLevel.BattleVictoryXp(enemyLevels: { number }): number
	local sum = 0
	for _, lv in ipairs(enemyLevels) do
		sum += math.max(1, lv)
	end
	return math.floor(AccountLevel.XpSources.BattleWinBase + sum * AccountLevel.XpSources.BattleWinPerEnemyLevel)
end

export type LevelReward = {
	Level: number,
	Tier: string, -- "Normal" | "Epico" | "Lendario"
	Title: string,
	Gold: number?,
	Gems: number?,
	Tickets: { Comum: number?, Premium: number? }?,
	Items: { [string]: number }?,
}

-- Recompensa garantida e balanceada para QUALQUER nivel >= 1
function AccountLevel.RewardFor(level: number): LevelReward
	local lv = math.max(1, math.floor(level))

	-- Nivel 1: presente de boas-vindas liberado de imediato na Arvore!
	if lv == 1 then
		return {
			Level = 1,
			Tier = "Normal",
			Title = "Boas-Vindas de Aventureiro",
			Gold = 300,
			Items = { Pocao = 2 },
		}
	end

	-- Marcos Lendarios (10, 20, 30, 40, 50, 60...)
	if lv % 10 == 0 then
		local tierIdx = lv // 10
		local gold = 2500 + tierIdx * 1500
		local gems = math.min(120, 20 + tierIdx * 10)
		local premTickets = if tierIdx >= 5 then 3 elseif tierIdx >= 3 then 2 else 1
		local doceEpico = math.min(5, tierIdx)
		return {
			Level = lv,
			Tier = "Lendario",
			Title = "Marco Lend\u{e1}rio \u{b7} N\u{ed}vel " .. lv,
			Gold = gold,
			Gems = gems,
			Tickets = { Premium = premTickets },
			Items = { DoceEpico = doceEpico },
		}
	end

	-- Marcos Epicos (5, 15, 25, 35, 45...)
	if lv % 5 == 0 then
		local step = (lv + 5) // 10
		local gold = 1000 + lv * 75
		local gems = math.min(45, 8 + step * 4)
		local comumTickets = if lv >= 25 then 2 else 1
		local doceRaro = math.min(4, 1 + step // 2)
		return {
			Level = lv,
			Tier = "Epico",
			Title = "Marco \u{c9}pico \u{b7} N\u{ed}vel " .. lv,
			Gold = gold,
			Gems = gems,
			Tickets = { Comum = comumTickets },
			Items = { DoceRaro = doceRaro },
		}
	end

	-- Niveis comuns: rotacao em ciclo de 4 para toda subida de nivel parecer util e variada!
	local goldBase = math.floor((250 + lv * 80) / 10) * 10
	local mod4 = lv % 4
	if mod4 == 2 then
		-- Gold + Pocoes (evolui de Pocao -> Superpocao -> Hiperpocao conforme o nivel)
		local itemId = if lv >= 26 then "Hiperpocao" elseif lv >= 10 then "Superpocao" else "Pocao"
		local qty = if lv >= 26 then 2 elseif lv >= 10 then 2 else 3
		return {
			Level = lv,
			Tier = "Normal",
			Title = "Recompensa do N\u{ed}vel " .. lv,
			Gold = goldBase,
			Items = { [itemId] = qty },
		}
	elseif mod4 == 3 then
		-- Gold + Selos de Contrato / Superior (ou Reviver em niveis altos)
		local itemId = if lv >= 18 then "SeloSuperior" else "SeloContrato"
		local qty = if lv >= 30 then 3 else 2
		return {
			Level = lv,
			Tier = "Normal",
			Title = "Recompensa do N\u{ed}vel " .. lv,
			Gold = goldBase,
			Items = { [itemId] = qty },
		}
	elseif mod4 == 0 then
		-- Gold + Gemas!
		local gems = math.min(20, 3 + math.floor(lv / 5) * 2)
		return {
			Level = lv,
			Tier = "Normal",
			Title = "Recompensa do N\u{ed}vel " .. lv,
			Gold = math.floor(goldBase * 1.15 / 10) * 10,
			Gems = gems,
		}
	else
		-- mod4 == 1 (ex.: 9, 13, 17, 21...): Gold + Doce de XP / Ticket Comum em niveis mais altos
		if lv >= 9 and lv % 8 == 1 then
			return {
				Level = lv,
				Tier = "Normal",
				Title = "Recompensa do N\u{ed}vel " .. lv,
				Gold = goldBase,
				Tickets = { Comum = 1 },
			}
		end
		local candyId = if lv >= 21 then "DoceRaro" else "DoceComum"
		local qty = if lv >= 33 then 3 else 2
		return {
			Level = lv,
			Tier = "Normal",
			Title = "Recompensa do N\u{ed}vel " .. lv,
			Gold = goldBase,
			Items = { [candyId] = qty },
		}
	end
end

function AccountLevel.IsClaimed(accountData: any, level: number): boolean
	if typeof(accountData) ~= "table" or typeof(accountData.Claimed) ~= "table" then
		return false
	end
	return accountData.Claimed[tostring(level)] == true or accountData.Claimed[level] == true
end

function AccountLevel.CountUnclaimed(accountData: any): number
	if typeof(accountData) ~= "table" then
		return 0
	end
	local curLv = math.max(1, math.floor(tonumber(accountData.Level) or 1))
	local count = 0
	for lv = 1, curLv do
		if not AccountLevel.IsClaimed(accountData, lv) then
			count += 1
		end
	end
	return count
end

function AccountLevel.FirstUnclaimedLevel(accountData: any): number?
	if typeof(accountData) ~= "table" then
		return nil
	end
	local curLv = math.max(1, math.floor(tonumber(accountData.Level) or 1))
	for lv = 1, curLv do
		if not AccountLevel.IsClaimed(accountData, lv) then
			return lv
		end
	end
	return nil
end

return AccountLevel
