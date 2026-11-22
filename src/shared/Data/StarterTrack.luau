--[[
	StarterTrack (Data/StarterTrack - Trilha de Objetivos Iniciais)
	So dados e avaliacao pura do progresso (sem estado mutavel e sem APIs de servidor).
	Guia o jogador novato pelos primeiros 15-30 minutos (Base, Invocacao, Dupla 2x2,
	Refugio, Torre Facil, Treino/Mina e 1o Ginasio) entregando Gold, itens e Doces de XP.
	Gemas continuam escassas: apenas 2 gemas no marco final (passo 7/7).
]]

local Tower = require(script.Parent:WaitForChild("Tower"))

local StarterTrack = {}

StarterTrack.Steps = {
	{
		Id = "BaseActive",
		Title = "Ative sua Base",
		Desc = "Coloque 1 her\u{f3}i na Base para ganhar Gold/s",
		HintAction = "Base",
		Goal = 1,
		Reward = { Gold = 300 },
		RewardText = "+300 gold",
	},
	{
		Id = "Summon1",
		Title = "1\u{aa} Invoca\u{e7}\u{e3}o",
		Desc = "Tenha 2 personagens na cole\u{e7}\u{e3}o (Estrela ou Ref\u{fa}gio)",
		HintAction = nil,
		Goal = 2,
		Reward = { Items = { Pocao = 2, SeloContrato = 2 } },
		RewardText = "2x Po\u{e7}\u{e3}o + 2x Selo",
	},
	{
		Id = "Team2",
		Title = "Monte sua Dupla 2x2",
		Desc = "Coloque 2 personagens no seu Time (menu Equipe)",
		HintAction = "Equipe",
		Goal = 2,
		Reward = { Gold = 350, Items = { DoceComum = 1 } },
		RewardText = "+350 gold + Doce Comum",
	},
	{
		Id = "Refuge1",
		Title = "Explore o Ref\u{fa}gio",
		Desc = "Derrote ou capture 1 selvagem na caverna da Base",
		HintAction = nil,
		Goal = 1,
		Reward = { Gold = 450, Items = { DoceComum = 1 } },
		RewardText = "+450 gold + Doce Comum",
	},
	{
		Id = "TowerEasy",
		Title = "Conclua a Torre F\u{e1}cil",
		Desc = "Venza a Torre F\u{e1}cil (1x1 ou 2x2)",
		HintAction = nil,
		Goal = 1,
		Reward = { Gold = 600, Items = { DoceRaro = 1 } },
		RewardText = "+600 gold + Doce Raro",
	},
	{
		Id = "BaseUpgrade",
		Title = "Evolua sua Estrutura",
		Desc = "Suba a Minera\u{e7}\u{e3}o ou M\u{e1}quina de Treino ao Nv. 2",
		HintAction = "Base",
		Goal = 2,
		Reward = { Gold = 750, Items = { Superpocao = 1 } },
		RewardText = "+750 gold + Superpo\u{e7}\u{e3}o",
	},
	{
		Id = "Gym1",
		Title = "1\u{aa} Ins\u{ed}gnia de Gin\u{e1}sio",
		Desc = "Venza um Gin\u{e1}sio na Torre e libere outro Banner",
		HintAction = nil,
		Goal = 1,
		Reward = { Gold = 1200, Gems = 2, Items = { DoceEpico = 1 } },
		RewardText = "+1.200 gold + 2 gemas + Doce \u{c9}pico",
	},
}

StarterTrack.ById = {}
for idx, step in ipairs(StarterTrack.Steps) do
	step.Index = idx
	StarterTrack.ById[step.Id] = step
end

local function countMap(tbl): number
	local n = 0
	if typeof(tbl) == "table" then
		for _ in pairs(tbl) do
			n += 1
		end
	end
	return n
end

local function countTrue(tbl): number
	local n = 0
	if typeof(tbl) == "table" then
		for _, v in pairs(tbl) do
			if v == true then
				n += 1
			end
		end
	end
	return n
end

-- Retorna (have, need, done) para um passo a partir do perfil
function StarterTrack.Progress(data, stepId: string): (number, number, boolean)
	local step = StarterTrack.ById[stepId]
	if not step or typeof(data) ~= "table" then
		return 0, 1, false
	end
	local have = 0
	if stepId == "BaseActive" then
		have = countMap(data.Base and data.Base.Active)
	elseif stepId == "Summon1" then
		have = countMap(data.Collection)
	elseif stepId == "Team2" then
		have = if typeof(data.Team) == "table" then #data.Team else 0
	elseif stepId == "Refuge1" then
		local r = data.Refuge
		have = (if r then (r.WildDefeated or 0) + (r.Captures or 0) else 0)
	elseif stepId == "TowerEasy" then
		local r1 = Tower.Index(data.Tower and data.Tower.Unlocked or "Facil")
		local r2 = Tower.Index(data.Tower2x2 and data.Tower2x2.Unlocked or "Facil")
		have = if math.max(r1, r2) > Tower.Index("Facil") then 1 else 0
	elseif stepId == "BaseUpgrade" then
		local mLv = (data.Base and data.Base.MiningLevel) or 1
		local tLv = (data.TrainingMachine and data.TrainingMachine.Level) or 1
		have = math.max(mLv, tLv)
	elseif stepId == "Gym1" then
		have = countTrue(data.GymsCleared)
	end
	local clamped = math.min(have, step.Goal)
	return clamped, step.Goal, have >= step.Goal
end

-- Retorna o passo atual ainda nao resgatado (ou nil se a trilha inteira foi concluida)
function StarterTrack.CurrentStep(data)
	if typeof(data) ~= "table" then
		return nil
	end
	local claimed = (data.StarterTrack and data.StarterTrack.Claimed) or {}
	for _, step in ipairs(StarterTrack.Steps) do
		if not claimed[step.Id] then
			local have, need, done = StarterTrack.Progress(data, step.Id)
			return step, have, need, done
		end
	end
	return nil
end

function StarterTrack.CompletedCount(data): number
	local claimed = (typeof(data) == "table" and data.StarterTrack and data.StarterTrack.Claimed) or {}
	local n = 0
	for _, step in ipairs(StarterTrack.Steps) do
		if claimed[step.Id] then
			n += 1
		end
	end
	return n
end

return StarterTrack
