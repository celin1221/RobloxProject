--[[
	AIController (GDD secao 5 - IA da maquina)
	  Facil   golpe aleatorio entre os que tem PP
	  Medio   70% o golpe de maior dano esperado; 30% aleatorio   <- usado no prototipo
	  Dificil sempre o maior dano esperado; usa status se o alvo estiver sem status;
	          troca quando esta em desvantagem de tipo
	Retorna uma acao no mesmo formato que o cliente envia:
	  { Kind = "Move", Index = n }  (Index 0 = golpe reserva, todos sem PP)
	  { Kind = "Switch", Index = n } (so a IA Dificil)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = ReplicatedStorage:WaitForChild("Data")
local Moves = require(Data:WaitForChild("Moves"))
local TypeChart = require(Data:WaitForChild("TypeChart"))
local DamageCalc = require(script.Parent.DamageCalc)

local AIController = {}

AIController.MEDIUM_BEST_CHANCE = 0.7

-- Indices dos golpes que ainda tem PP
local function usableMoves(battler)
	local list = {}
	for i, slot in ipairs(battler.Moves) do
		if slot.Pp > 0 then
			table.insert(list, i)
		end
	end
	return list
end

-- Golpe de maior dano esperado (empate: o primeiro da lista)
local function bestDamage(self, foe, usable)
	local bestIndex, bestValue = usable[1], -1
	for _, i in ipairs(usable) do
		local value = DamageCalc.ExpectedDamage(self, foe, Moves.Get(self.Moves[i].Id))
		if value > bestValue then
			bestIndex, bestValue = i, value
		end
	end
	return bestIndex
end

-- Pontua o confronto de um membro do time contra o adversario em campo:
-- positivo = vantagem de tipo, negativo = desvantagem
local function matchup(member, foe): number
	local attack = TypeChart.Multiplier(member.Type, foe.Type)
	local defend = TypeChart.Multiplier(foe.Type, member.Type)
	return attack - defend
end

-- Escolhe quem entra depois de um desmaio. team = lista do lado; active = indice atual.
function AIController.ChooseReplacement(level: string, team, active: number, foe, rng: Random): number?
	local best, bestScore = nil, -math.huge
	for i, member in ipairs(team) do
		if i ~= active and member.Hp > 0 then
			if level ~= "Dificil" then
				return i -- Facil e Medio: o proximo da ordem do time
			end
			local score = matchup(member, foe)
			if score > bestScore then
				best, bestScore = i, score
			end
		end
	end
	return best
end

-- team e active sao opcionais (usados so pela IA Dificil para trocar)
function AIController.ChooseAction(level: string, self, foe, rng: Random, team, active: number?)
	-- Dificil: em desvantagem de tipo, troca para alguem melhor
	if level == "Dificil" and team and active and TypeChart.Multiplier(foe.Type, self.Type) > 1 then
		local best, bestScore = nil, matchup(self, foe)
		for i, member in ipairs(team) do
			if i ~= active and member.Hp > 0 then
				local score = matchup(member, foe)
				if score > bestScore then
					best, bestScore = i, score
				end
			end
		end
		if best then
			return { Kind = "Switch", Index = best }
		end
	end

	local usable = usableMoves(self)
	if #usable == 0 then
		return { Kind = "Move", Index = 0 }
	end

	local function randomPick()
		return usable[rng:NextInteger(1, #usable)]
	end

	local index
	if level == "Facil" then
		index = randomPick()
	elseif level == "Dificil" then
		if not foe.Status then
			for _, i in ipairs(usable) do
				local move = Moves.Get(self.Moves[i].Id)
				if move.Effect and move.Effect.Kind == "Status" and move.Effect.Target ~= "Self" and move.Category == "Status" then
					return { Kind = "Move", Index = i }
				end
			end
		end
		index = bestDamage(self, foe, usable)
	else -- "Medio"
		if rng:NextNumber() < AIController.MEDIUM_BEST_CHANCE then
			index = bestDamage(self, foe, usable)
		else
			index = randomPick()
		end
	end
	return { Kind = "Move", Index = index }
end

return AIController
