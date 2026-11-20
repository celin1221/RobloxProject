--[[
	Refuge (GDD secao 14 - Refugio): tabelas da Forja, da melhoria e do Bau.
	So dados; o sorteio, os contadores e a validacao ficam no servidor (RefugeService).
]]
local Refuge = {}

Refuge.RarityOrder = { "Comum", "Raro", "Epico", "Lendario" }

-- Chances (%) por raridade, nivel do selvagem, maximo simultaneo e intervalo (segundos)
Refuge.Levels = {
	[1] = { Chances = { Comum = 80, Raro = 18, Epico = 2, Lendario = 0 }, MinLevel = 3, MaxLevel = 8, Max = 2, Interval = 240 },
	[2] = { Chances = { Comum = 75, Raro = 22, Epico = 3, Lendario = 0 }, MinLevel = 6, MaxLevel = 12, Max = 2, Interval = 240 },
	[3] = { Chances = { Comum = 70, Raro = 25, Epico = 5, Lendario = 0 }, MinLevel = 10, MaxLevel = 16, Max = 3, Interval = 210 },
	[4] = { Chances = { Comum = 65, Raro = 28, Epico = 6.5, Lendario = 0.5 }, MinLevel = 14, MaxLevel = 20, Max = 3, Interval = 210 },
	[5] = { Chances = { Comum = 60, Raro = 30, Epico = 9, Lendario = 1 }, MinLevel = 18, MaxLevel = 25, Max = 3, Interval = 180 },
	[6] = { Chances = { Comum = 55, Raro = 32, Epico = 11.5, Lendario = 1.5 }, MinLevel = 22, MaxLevel = 30, Max = 4, Interval = 180 },
	[7] = { Chances = { Comum = 50, Raro = 34, Epico = 14, Lendario = 2 }, MinLevel = 27, MaxLevel = 35, Max = 4, Interval = 150 },
	[8] = { Chances = { Comum = 46, Raro = 35, Epico = 16.5, Lendario = 2.5 }, MinLevel = 32, MaxLevel = 40, Max = 4, Interval = 150 },
	[9] = { Chances = { Comum = 43, Raro = 36, Epico = 18, Lendario = 3 }, MinLevel = 36, MaxLevel = 45, Max = 5, Interval = 120 },
	[10] = { Chances = { Comum = 40, Raro = 37, Epico = 19, Lendario = 4 }, MinLevel = 40, MaxLevel = 50, Max = 5, Interval = 120 },
}
Refuge.MaxLevel = 10

-- Melhoria para o nivel N: gemas + todos os requisitos
-- Tipos: TowerWin (Mode), WildDefeated (Count), Captures (Count), CharLevel (Count, Level),
--        InfinitoFloor (Floor), Stars (Count, Stars), LegendaryLevel (Level)
Refuge.Upgrades = {
	[2] = { Gems = 50, Req = { { Kind = "TowerWin", Mode = "Facil" }, { Kind = "WildDefeated", Count = 10 } } },
	[3] = { Gems = 100, Req = { { Kind = "CharLevel", Count = 3, Level = 10 }, { Kind = "Captures", Count = 5 } } },
	[4] = { Gems = 200, Req = { { Kind = "TowerWin", Mode = "Medio" }, { Kind = "WildDefeated", Count = 40 } } },
	[5] = { Gems = 350, Req = { { Kind = "CharLevel", Count = 3, Level = 20 }, { Kind = "Captures", Count = 15 } } },
	[6] = { Gems = 500, Req = { { Kind = "TowerWin", Mode = "Dificil" }, { Kind = "WildDefeated", Count = 100 } } },
	[7] = { Gems = 750, Req = { { Kind = "InfinitoFloor", Floor = 10 }, { Kind = "CharLevel", Count = 6, Level = 25 } } },
	[8] = { Gems = 1000, Req = { { Kind = "InfinitoFloor", Floor = 20 }, { Kind = "Stars", Count = 1, Stars = 3 } } },
	[9] = { Gems = 1500, Req = { { Kind = "InfinitoFloor", Floor = 30 }, { Kind = "CharLevel", Count = 6, Level = 40 }, { Kind = "Captures", Count = 80 } } },
	[10] = { Gems = 2000, Req = { { Kind = "InfinitoFloor", Floor = 50 }, { Kind = "LegendaryLevel", Level = 50 }, { Kind = "Captures", Count = 150 } } },
}

local MODE_NAME = { Facil = "F\u{e1}cil", Medio = "M\u{e9}dio", Dificil = "Dif\u{ed}cil" }

-- Texto do requisito
function Refuge.ReqText(req): string
	if req.Kind == "TowerWin" then
		return "Vencer a torre " .. (MODE_NAME[req.Mode] or req.Mode)
	elseif req.Kind == "WildDefeated" then
		return "Derrotar " .. req.Count .. " selvagens"
	elseif req.Kind == "Captures" then
		return "Capturar " .. req.Count .. " personagens"
	elseif req.Kind == "CharLevel" then
		return req.Count .. " personagens no n\u{ed}vel " .. req.Level
	elseif req.Kind == "InfinitoFloor" then
		return "Andar " .. req.Floor .. " do Infinito"
	elseif req.Kind == "Stars" then
		return req.Count .. " personagem com " .. req.Stars .. " estrelas"
	elseif req.Kind == "LegendaryLevel" then
		return "1 Lend\u{e1}rio no n\u{ed}vel " .. req.Level
	end
	return tostring(req.Kind)
end

-- Bau
Refuge.DropChance = 0.30
Refuge.BauBase = 10
Refuge.BauPerLevel = 2
Refuge.OreMin = 20
Refuge.OreMax = 50
Refuge.DropItems = { "Pocao", "Superpocao", "CuraStatus", "SeloContrato", "Ore" }
Refuge.DropItemsHigh = { "SeloSuperior", "Eter" } -- a partir da Forja 6
Refuge.HighDropLevel = 6

function Refuge.BauCapacity(level: number): number
	return Refuge.BauBase + Refuge.BauPerLevel * level
end

function Refuge.DropPool(level: number)
	local pool = table.clone(Refuge.DropItems)
	if level >= Refuge.HighDropLevel then
		for _, id in ipairs(Refuge.DropItemsHigh) do
			table.insert(pool, id)
		end
	end
	return pool
end

-- Gold por selvagem derrotado (GDD nao define o valor; registrado em PROGRESSO.md)
Refuge.GoldPerLevel = 5

-- Modelo da Forja por nivel (muda nos niveis 4, 7 e 10)
function Refuge.ForgeModel(level: number): string
	if level >= 10 then
		return "Forja10"
	elseif level >= 7 then
		return "Forja7"
	elseif level >= 4 then
		return "Forja4"
	end
	return "Forja1"
end

return Refuge
