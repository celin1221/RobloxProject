--[[
	Retention (GDD secao 13 - mecanicas de retorno)
	Valores do GDD: login de 7 dias (gold crescente, dia 7 = 1 invocacao Premium), baus aos 5, 15, 30 e 60 min
	(gold, pocoes, Selos), 3 missoes diarias (gold e XP; as 3 = 5 gemas), 5 semanais (1 invocacao Premium),
	temporada mensal do Infinito (aparencia para os 100 primeiros, gemas por faixa), fim de semana 2x gold ou 2x XP.
	Quantidades que o GDD nao define estao registradas em PROGRESSO.md.
	Dias e semanas em UTC; a semana comeca segunda 00:00 (igual ao banner do Portal Premium).
	O servidor decide tudo (RetentionService); o cliente so mostra.
]]

local Retention = {}

-- Calendario (UTC)
function Retention.Day(t: number): number
	return t // 86400
end

-- 01/01/1970 foi quinta: +3 faz a semana virar na segunda
function Retention.Week(t: number): number
	return (t // 86400 + 3) // 7
end

function Retention.WeekEnd(t: number): number
	return ((Retention.Week(t) + 1) * 7 - 3) * 86400
end

local function daysFromCivil(y: number, m: number, d: number): number
	if m <= 2 then
		y -= 1
	end
	local era = (if y >= 0 then y else y - 399) // 400
	local yoe = y - era * 400
	local mp = (m + 9) % 12
	local doy = (153 * mp + 2) // 5 + d - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return era * 146097 + doe - 719468
end

-- Temporada do Infinito = mes UTC, ex. "2026-11"
function Retention.SeasonId(t: number): string
	return os.date("!%Y-%m", t)
end

function Retention.SeasonEnd(t: number): number
	local d = os.date("!*t", t)
	local y, m = d.year, d.month + 1
	if m > 12 then
		m = 1
		y += 1
	end
	return daysFromCivil(y, m, 1) * 86400
end

-- Login diario: 7 dias, reinicia se pular um
Retention.Login = {
	{ Gold = 300 },
	{ Gold = 600 },
	{ Gold = 900 },
	{ Gold = 1200 },
	{ Gold = 1800 },
	{ Gold = 2500 },
	{ Tickets = { Premium = 1 } },
}

-- Baus por tempo online no dia (cada um 1 vez por dia)
Retention.Chests = {
	{ Minutes = 5, Gold = 300 },
	{ Minutes = 15, Gold = 400, Items = { Pocao = 2 } },
	{ Minutes = 30, Gold = 600, Items = { SeloContrato = 2 } },
	{ Minutes = 60, Gold = 1200, Items = { SeloSuperior = 1 } },
}

-- Missoes. Event = o que o servidor conta.
Retention.Daily = {
	Count = 3,
	Reward = { Gold = 600, Xp = 120 }, -- cada missao; Xp para cada personagem do time
	AllReward = { Gems = 10 }, -- completar as 3
	Pool = {
		Win3 = { Text = "Vencer %d batalhas", Goal = 3, Event = "Win" },
		Tower3 = { Text = "Vencer %d batalhas na torre", Goal = 3, Event = "TowerWin" },
		Summon3 = { Text = "Invocar %d vezes", Goal = 3, Event = "Summon" },
		Collect2 = { Text = "Coletar a base %d vezes", Goal = 2, Event = "Collect" },
		Buy5 = { Text = "Comprar %d itens na loja", Goal = 5, Event = "BuyItem" },
		-- captura voltou com o Refugio (secao 14)
		Capture1 = { Text = "Capturar %d personagem", Goal = 1, Event = "Capture" },
	},
}

Retention.Weekly = {
	AllReward = { Tickets = { Premium = 1 } }, -- completar as 5
	List = {
		{ Id = "Win25", Text = "Vencer %d batalhas", Goal = 25, Event = "Win" },
		{ Id = "Summon15", Text = "Invocar %d vezes", Goal = 15, Event = "Summon" },
		{ Id = "Collect10", Text = "Coletar a base %d vezes", Goal = 10, Event = "Collect" },
		{ Id = "Tower15", Text = "Vencer %d batalhas na torre", Goal = 15, Event = "TowerWin" },
		{ Id = "Daily10", Text = "Completar %d miss\u{f5}es di\u{e1}rias", Goal = 10, Event = "DailyDone" },
	},
}

-- Capture1 voltou para o sorteio diario com o Refugio. Capture5 (semanal) fica guardada: a semana
-- continua com 5 missoes (premio "completar as 5").
Retention.DisabledMissions = {
	Capture5 = { Text = "Capturar %d personagens", Goal = 5, Event = "Capture" },
}

-- Sorteio das 3 diarias do dia (o mesmo para o jogador o dia inteiro)
function Retention.DailyIds(day: number, userId: number): { string }
	local ids = {}
	for id in pairs(Retention.Daily.Pool) do
		table.insert(ids, id)
	end
	table.sort(ids)
	local rng = Random.new(day * 7919 + (userId % 1000003))
	local out = {}
	for _ = 1, math.min(Retention.Daily.Count, #ids) do
		table.insert(out, table.remove(ids, rng:NextInteger(1, #ids)))
	end
	return out
end

-- Temporada do Infinito
Retention.Season = {
	TopCount = 100, -- aparencia para os 100 primeiros
	TopTag = "Top 100 do Infinito",
	Tiers = { -- gemas por faixa (maior andar vencido na temporada)
		{ Floor = 30, Gems = 100 },
		{ Floor = 20, Gems = 50 },
		{ Floor = 10, Gems = 25 },
		{ Floor = 5, Gems = 10 },
	},
	StorePrefix = "InfiniteSeason_",
}

function Retention.SeasonGems(best: number): number
	for _, tier in ipairs(Retention.Season.Tiers) do
		if best >= tier.Floor then
			return tier.Gems
		end
	end
	return 0
end

-- Fim de semana (sabado e domingo UTC): alterna 2x gold e 2x XP a cada semana, sem custo
Retention.Weekend = { Rotation = { "Gold", "Xp" }, Multiplier = 2 }
Retention.EventNames = { Gold = "2x gold", Xp = "2x XP" }

function Retention.EventAt(t: number): string?
	local wday = os.date("!*t", t).wday -- 1 = domingo, 7 = sabado
	if wday ~= 1 and wday ~= 7 then
		return nil
	end
	local rot = Retention.Weekend.Rotation
	return rot[Retention.Week(t) % #rot + 1]
end

function Retention.GoldMultiplier(t: number): number
	return if Retention.EventAt(t) == "Gold" then Retention.Weekend.Multiplier else 1
end

function Retention.XpMultiplier(t: number): number
	return if Retention.EventAt(t) == "Xp" then Retention.Weekend.Multiplier else 1
end

-- Gemas no lugar da invocacao Premium onde o Portal Premium e bloqueado (PolicyService)
Retention.PremiumTicketGems = 25

return Retention
