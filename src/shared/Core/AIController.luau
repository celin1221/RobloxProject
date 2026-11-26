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

local function isProtectMove(move): boolean
	return move ~= nil and move.Effect ~= nil and (move.Effect.Kind == "Protect" or move.Effect.Kind == "WideProtect")
end

-- Evita spam consecutivo de Protect/WideProtect se houver outro golpe com PP
local function pickSmartRandom(battler, usable, rng: Random): number
	if (battler.ProtectStreak or 0) > 0 and #usable > 1 then
		local nonProtect = {}
		for _, i in ipairs(usable) do
			if not isProtectMove(Moves.Get(battler.Moves[i].Id)) then
				table.insert(nonProtect, i)
			end
		end
		if #nonProtect > 0 then
			return nonProtect[rng:NextInteger(1, #nonProtect)]
		end
	end
	return usable[rng:NextInteger(1, #usable)]
end

-- Procura um golpe de cura, purificacao ou Expansao de Dominio util para a IA
local function pickDomainMove(battler, usable): number?
	if battler._StandardMoves ~= nil then
		return nil
	end
	for _, i in ipairs(usable) do
		local move = Moves.Get(battler.Moves[i].Id)
		if move and move.Effect and move.Effect.Kind == "DomainExpansion" then
			return i
		end
	end
	return nil
end

local function pickSupportMove(battler, usable): number?
	if battler.Hp / math.max(1, battler.MaxHp) < 0.45 then
		for _, i in ipairs(usable) do
			local move = Moves.Get(battler.Moves[i].Id)
			if move and move.Category == "Status" and move.Effect and move.Effect.Kind == "Heal" then
				return i
			end
		end
	end
	if battler.Status then
		for _, i in ipairs(usable) do
			local move = Moves.Get(battler.Moves[i].Id)
			if move and move.Category == "Status" and move.Effect and move.Effect.Kind == "Cleanse" then
				return i
			end
		end
	end
	return nil
end

-- Golpe de maior dano esperado (empate: o primeiro da lista)
local function bestDamage(self, foe, usable)
	local bestIndex, bestValue = usable[1], -1
	for _, i in ipairs(usable) do
		local move = Moves.Get(self.Moves[i].Id)
		local value = DamageCalc.ExpectedDamage(self, foe, move)
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

-- Escolhe quem entra depois de um desmaio.
-- team = lista do lado; active = indice atual (ou lista ActiveSlots); exclude = tabela [teamIndex] = true a ignorar.
function AIController.ChooseReplacement(level: string, team, active, foe, rng: Random, exclude): number?
	local blocked = {}
	if typeof(active) == "table" then
		for _, idx in pairs(active) do
			if typeof(idx) == "number" then
				blocked[idx] = true
			end
		end
	elseif typeof(active) == "number" then
		blocked[active] = true
	end
	if typeof(exclude) == "table" then
		for idx, on in pairs(exclude) do
			if on then
				blocked[idx] = true
			end
		end
	end
	local best, bestScore = nil, -math.huge
	for i, member in ipairs(team) do
		if not blocked[i] and member.Hp > 0 then
			if level ~= "Dificil" or not foe then
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
		return pickSmartRandom(self, usable, rng)
	end

	local index
	if level == "Facil" then
		index = randomPick()
	elseif level == "Dificil" then
		local domIdx = pickDomainMove(self, usable)
		if domIdx then
			return { Kind = "Move", Index = domIdx }
		end
		local supportIdx = pickSupportMove(self, usable)
		if supportIdx then
			return { Kind = "Move", Index = supportIdx }
		end
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
		local domIdx = pickDomainMove(self, usable)
		if domIdx and rng:NextNumber() < 0.75 then
			return { Kind = "Move", Index = domIdx }
		end
		if rng:NextNumber() < AIController.MEDIUM_BEST_CHANCE then
			index = bestDamage(self, foe, usable)
		else
			index = randomPick()
		end
	end
	return { Kind = "Move", Index = index }
end

-- Escolha para batalha 2x2: devolve { Kind = "Double", Actions = { { FieldSlot = fs, ... }, ... } }
function AIController.ChooseActionsDouble(level: string, ownSide, foeSide, rng: Random)
	local foes = {}
	local foeSlots = foeSide.ActiveSlots or { foeSide.Active }
	for fs = 1, 2 do
		local idx = foeSlots[fs]
		local b = idx and foeSide.Team[idx]
		if b and b.Hp > 0 then
			table.insert(foes, { FieldSlot = fs, Battler = b })
		end
	end

	local ownSlots = ownSide.ActiveSlots or { ownSide.Active }
	local onField = {}
	for fs = 1, 2 do
		local idx = ownSlots[fs]
		if idx then
			onField[idx] = true
		end
	end

	local reservedSwitches = {}
	local actions = {}

	for fs = 1, 2 do
		local teamIdx = ownSlots[fs]
		local battler = teamIdx and ownSide.Team[teamIdx]
		if not battler or battler.Hp <= 0 then
			continue
		end

		local chosen = nil

		-- Dificil: se algum oponente tem vantagem de tipo, tenta trocar para alguem melhor no banco
		if level == "Dificil" and #foes > 0 then
			local threatened = false
			local curScore = 0
			for _, f in ipairs(foes) do
				if TypeChart.Multiplier(f.Battler.Type, battler.Type) > 1 then
					threatened = true
				end
				curScore += matchup(battler, f.Battler)
			end
			if threatened then
				local best, bestScore = nil, curScore
				for i, member in ipairs(ownSide.Team) do
					if not onField[i] and not reservedSwitches[i] and member.Hp > 0 then
						local score = 0
						for _, f in ipairs(foes) do
							score += matchup(member, f.Battler)
						end
						if score > bestScore then
							best, bestScore = i, score
						end
					end
				end
				if best then
					reservedSwitches[best] = true
					chosen = { FieldSlot = fs, Kind = "Switch", Index = best }
				end
			end
		end

		if not chosen then
			local usable = usableMoves(battler)
			local defaultTargetSlot = if #foes > 0 then foes[rng:NextInteger(1, #foes)].FieldSlot else 1
			if #usable == 0 then
				chosen = { FieldSlot = fs, Kind = "Move", Index = 0, TargetSide = "Enemy", TargetSlot = defaultTargetSlot }
			else
				local function pickBestMoveAndTarget()
					local bestMoveIdx, bestSlot, bestVal = usable[1], defaultTargetSlot, -1
					for _, mIdx in ipairs(usable) do
						local move = Moves.Get(battler.Moves[mIdx].Id)
						local mode = Moves.TargetMode(move)
						if mode == "AllEnemies" or mode == "AllOthers" then
							local spread = if #foes >= 2 then DamageCalc.SPREAD_MULTIPLIER else 1
							local total = 0
							for _, f in ipairs(foes) do
								total += DamageCalc.ExpectedDamage(battler, f.Battler, move, spread)
							end
							if total > bestVal then
								bestMoveIdx, bestSlot, bestVal = mIdx, defaultTargetSlot, total
							end
						elseif mode == "Single" then
							for _, f in ipairs(foes) do
								local val = DamageCalc.ExpectedDamage(battler, f.Battler, move, 1)
								if val > bestVal then
									bestMoveIdx, bestSlot, bestVal = mIdx, f.FieldSlot, val
								end
							end
						end
					end
					return bestMoveIdx, bestSlot
				end

				local moveIdx, targetSlot = pickSmartRandom(battler, usable, rng), defaultTargetSlot
				local domIdx = pickDomainMove(battler, usable)
				if domIdx and (level == "Dificil" or (level == "Medio" and rng:NextNumber() < 0.75)) then
					moveIdx, targetSlot = domIdx, defaultTargetSlot
				elseif level == "Dificil" then
					local supportIdx = pickSupportMove(battler, usable)
					if supportIdx then
						moveIdx, targetSlot = supportIdx, defaultTargetSlot
					else
						local pickedStatus = false
						for _, f in ipairs(foes) do
							if not f.Battler.Status then
								for _, mIdx in ipairs(usable) do
									local move = Moves.Get(battler.Moves[mIdx].Id)
									if move.Effect and move.Effect.Kind == "Status" and move.Effect.Target ~= "Self" and move.Category == "Status" then
										moveIdx, targetSlot = mIdx, f.FieldSlot
										pickedStatus = true
										break
									end
								end
								if pickedStatus then
									break
								end
							end
						end
						if not pickedStatus then
							moveIdx, targetSlot = pickBestMoveAndTarget()
						end
					end
				elseif level == "Medio" and rng:NextNumber() < AIController.MEDIUM_BEST_CHANCE then
					moveIdx, targetSlot = pickBestMoveAndTarget()
				end
				chosen = { FieldSlot = fs, Kind = "Move", Index = moveIdx, TargetSide = "Enemy", TargetSlot = targetSlot }
			end
		end

		table.insert(actions, chosen)
	end

	return { Kind = "Double", Actions = actions }
end

return AIController
