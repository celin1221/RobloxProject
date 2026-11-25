--[[
	BattleEngine (GDD secoes 5 e 10)
	Logica pura da maquina de estados de batalha por turnos (testavel sem jogador e sem arena).

	Suporta formatos:
	  "1x1" (padrao) -> 1 lutador em campo por lado
	  "2x2"          -> 2 lutadores em campo por lado (estilo Pokemon Doubles: ordem por Velocidade
	                    entre os 4 ativos, escolha de alvo, golpes em area com 0.75x em 2+ alvos,
	                    redirecionamento se o alvo desmaiar no meio do turno, substituicao dupla e 2x1).

	Estados:
	  "WaitingForInput"        cada lado escolhe acoes do turno
	  "Resolving"              resolvendo o turno
	  "WaitingForReplacement"  um ou mais personagens desmaiaram; o dono escolhe quem entra
	  "Ended"                  um lado ficou sem personagens de pe (ou desistiu/fugiu)
	ResolveTurn e ResolveReplacement devolvem a lista de eventos do que aconteceu.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = ReplicatedStorage:WaitForChild("Data")
local Characters = require(Data.Characters)
local Moves = require(Data.Moves)
local Items = require(Data.Items)
local TypeChart = require(Data.TypeChart)
local Genetics = require(Data.Genetics)
local Passives = require(Data:WaitForChild("Passives"))

local DamageCalc = require(script.Parent.DamageCalc)
local AIController = require(script.Parent.AIController)

local BattleEngine = {}
BattleEngine.__index = BattleEngine

local SIDES = { "Player", "Enemy" }
BattleEngine.SIDES = SIDES

local MAX_TEAM = 6

local STAT_NAMES = { Attack = "Ataque", Defense = "Defesa", Speed = "Velocidade", Accuracy = "Precis\u{e3}o" }

local STATUS_DISPLAY = {
	Burn = "Queimadura",
	Poison = "Veneno",
	Paralysis = "Paralisia",
	Sleep = "Sono",
	Freeze = "Congelamento",
}

local function passiveOf(battler)
	if not battler or not battler.PassiveId then
		return nil, nil
	end
	local p = Passives.Get(battler.PassiveId)
	return p, p and p.Effect or nil
end

-- Texto quando o status e aplicado
local STATUS_TEXT = {
	Burn = " foi queimado!",
	Poison = " foi envenenado!",
	Paralysis = " ficou paralisado! Pode n\u{e3}o conseguir se mover.",
	Sleep = " caiu no sono!",
	Freeze = " ficou congelado!",
}

local function otherSide(side: string): string
	return if side == "Player" then "Enemy" else "Player"
end
BattleEngine.OtherSide = otherSide

local function freshStages()
	return { Attack = 0, Defense = 0, Speed = 0, Accuracy = 0 }
end

local function freshHazards()
	return { Spikes = 0, ToxicSpikes = 0, StickyWeb = false }
end

local function freshSideEffects()
	return { Barrier = 0, Tailwind = 0 }
end

local SPIKES_FRACTION = { 1 / 8, 1 / 6, 1 / 4 }

-- Cria um lutador a partir dos dados (Characters + Moves)
local function newBattler(characterId: string, level: number, moveIds: { string }?, uid: string?, extra)
	local def = assert(Characters.Get(characterId), "Personagem desconhecido: " .. tostring(characterId))
	local stats = Characters.StatsAt(characterId, level)
	extra = extra or {}
	local scalarMult = if typeof(extra.StatMultiplier) == "number" then extra.StatMultiplier else 1
	local perStat = if typeof(extra.StatMultipliers) == "table" then extra.StatMultipliers else nil
	if not perStat and (extra.Genetics or extra.Training) then
		perStat = Genetics.MultipliersFor(extra.Genetics, extra.Training)
	end
	for k, v in pairs(stats) do
		local m = scalarMult * (if perStat and typeof(perStat[k]) == "number" then perStat[k] else 1)
		if m ~= 1 then
			stats[k] = math.max(1, math.floor(v * m + 0.5))
		end
	end
	local moves = {}
	for i, moveId in ipairs(moveIds or Characters.DefaultActive(characterId, level)) do
		local move = assert(Moves.Get(moveId), "Golpe desconhecido: " .. tostring(moveId))
		local pp = extra.Pp and extra.Pp[moveId]
		moves[i] = { Id = moveId, Pp = if typeof(pp) == "number" then math.clamp(pp, 0, move.PP) else move.PP, MaxPp = move.PP }
	end
	local awakened = extra.Awakened == true
	local passiveId = if typeof(extra.PassiveId) == "string" then extra.PassiveId else Characters.PassiveIdOf(characterId, awakened)
	return {
		Id = characterId,
		Name = def.Name,
		ModelName = def.ModelName,
		Type = def.Type,
		Level = level,
		Stats = stats,
		Hp = if typeof(extra.Hp) == "number" then math.clamp(math.floor(extra.Hp), 0, stats.HP) else stats.HP,
		MaxHp = stats.HP,
		Status = extra.Status, -- "Burn" | "Poison" | "Paralysis" | "Sleep" | "Freeze" | nil
		StatusTurns = if extra.Status == "Sleep" then (extra.StatusTurns or 1) else 0,
		Stages = freshStages(),
		Protected = false,
		ProtectStreak = 0,
		Awakened = awakened,
		PassiveId = passiveId,
		SturdyUsed = false,
		ThresholdUsed = false,
		AwakenTriggered = false,
		Moves = moves,
		Uid = uid,
		Genetics = if typeof(extra.Genetics) == "table" then Genetics.SanitizeTable(extra.Genetics) else nil,
		Training = if typeof(extra.Training) == "table" then Genetics.SanitizeTable(extra.Training) else nil,
		Participated = false,
	}
end

local function newSide(teamDef, slotsPerSide: number)
	assert(typeof(teamDef) == "table" and #teamDef >= 1, "Time vazio")
	assert(#teamDef <= MAX_TEAM, "Time com mais de " .. MAX_TEAM .. " personagens")
	local team = {}
	for i, entry in ipairs(teamDef) do
		team[i] = newBattler(entry.CharacterId, entry.Level or 10, entry.Moves, entry.Uid, entry)
	end
	-- entram em campo os primeiros de pe (ate slotsPerSide)
	local activeSlots = {}
	for i, b in ipairs(team) do
		if b.Hp > 0 then
			table.insert(activeSlots, i)
			b.Participated = true
			if #activeSlots >= slotsPerSide then
				break
			end
		end
	end
	assert(#activeSlots >= 1, "Time sem ninguem de pe")
	return {
		Team = team,
		Active = activeSlots[1],
		ActiveSlots = activeSlots,
		Hazards = freshHazards(),
		SideEffects = freshSideEffects(),
		WideProtected = false,
	}
end

-- Aceita o formato antigo (CharacterId/Level) ou o novo (Team = {...})
local function teamFrom(def)
	if def.Team then
		return def.Team
	end
	return { { CharacterId = def.CharacterId, Level = def.Level } }
end

local function hasUsableMove(battler): boolean
	if not battler then
		return false
	end
	for _, slot in ipairs(battler.Moves) do
		if slot.Pp > 0 then
			return true
		end
	end
	return false
end

local function aliveCount(sideState): number
	local n = 0
	for _, m in ipairs(sideState.Team) do
		if m.Hp > 0 then
			n += 1
		end
	end
	return n
end

local function isInt(v): boolean
	return typeof(v) == "number" and v == v and v % 1 == 0
end

--[[
	opts = {
		Player = { Team = { { CharacterId = "Kaen", Level = 10 }, ... } },
		Enemy  = { Team = { ... }, AI = "Medio" },
		Format = "1x1" | "2x2", (padrao "1x1")
		Mode = "Tower" | "Wild" | "PvP", Bag = { Pocao = 1 }, Seed = numero opcional
	}
]]
function BattleEngine.New(opts)
	local self = setmetatable({}, BattleEngine)
	self.Rng = if opts.Seed then Random.new(opts.Seed) else Random.new()
	self.Format = if opts.Format == "2x2" then "2x2" else "1x1"
	self.SlotsPerSide = if self.Format == "2x2" then 2 else 1
	self.Sides = {
		Player = newSide(teamFrom(opts.Player), self.SlotsPerSide),
		Enemy = newSide(teamFrom(opts.Enemy), self.SlotsPerSide),
	}
	self.EnemyAI = opts.Enemy.AI or "Medio"
	self.Mode = opts.Mode or "Tower"
	self.CaptureBlocked = opts.CaptureBlocked
	-- GDD secao 5: fugir so contra selvagens; torre e PvP tem Desistir (derrota)
	self.CanFlee = if opts.CanFlee ~= nil then opts.CanFlee == true else self.Mode == "Wild"
	self.Bag = table.clone(opts.Bag or {})
	self.Turn = 1
	self.State = "WaitingForInput"
	self.Winner = nil -- "Player" | "Enemy" | "None"
	self.EndReason = nil -- "Faint" | "Forfeit" | "Fled" | "Disconnect" | "Captured"
	self.EnemyHuman = opts.EnemyHuman == true
	-- [lado] = { slot1, ... } enquanto o dono precisa escolher o(s) proximo(s)
	self.PendingReplace = {}
	return self
end

function BattleEngine:IsDouble(): boolean
	return self.SlotsPerSide > 1
end

function BattleEngine:SyncLegacyActive(side: string)
	local s = self.Sides[side]
	for fs = 1, self.SlotsPerSide do
		local idx = s.ActiveSlots[fs]
		if idx and s.Team[idx] and s.Team[idx].Hp > 0 then
			s.Active = idx
			return
		end
	end
	s.Active = s.ActiveSlots[1] or s.ActiveSlots[2] or s.Active
end

function BattleEngine:ActiveIndex(side: string, fieldSlot: number?): number?
	local s = self.Sides[side]
	if fieldSlot then
		return s.ActiveSlots[fieldSlot]
	end
	return s.ActiveSlots[1] or s.ActiveSlots[2] or s.Active
end

function BattleEngine:ActiveAt(side: string, fieldSlot: number?)
	local s = self.Sides[side]
	if not s then
		return nil
	end
	local idx = s.ActiveSlots[fieldSlot or 1]
	return if idx then s.Team[idx] else nil
end

function BattleEngine:Active(side: string, fieldSlot: number?)
	if fieldSlot ~= nil then
		return self:ActiveAt(side, fieldSlot)
	end
	local s = self.Sides[side]
	local idx = s.ActiveSlots[1] or s.ActiveSlots[2] or s.Active
	return idx and s.Team[idx] or nil
end

function BattleEngine:FieldSlotOf(side: string, teamIndex: number): number?
	local s = self.Sides[side]
	for fs = 1, self.SlotsPerSide do
		if s.ActiveSlots[fs] == teamIndex then
			return fs
		end
	end
	return nil
end

function BattleEngine:AliveFieldSlots(side: string): { number }
	local out = {}
	local s = self.Sides[side]
	for fs = 1, self.SlotsPerSide do
		local idx = s.ActiveSlots[fs]
		local b = idx and s.Team[idx]
		if b and b.Hp > 0 then
			table.insert(out, fs)
		end
	end
	return out
end

function BattleEngine:BenchAliveIndices(side: string): { number }
	local s = self.Sides[side]
	local onField = {}
	for fs = 1, self.SlotsPerSide do
		local idx = s.ActiveSlots[fs]
		if idx then
			onField[idx] = true
		end
	end
	local out = {}
	for i, m in ipairs(s.Team) do
		if m.Hp > 0 and not onField[i] then
			table.insert(out, i)
		end
	end
	return out
end

-- Golpe de um slot do personagem em campo. Index 0 = golpe reserva.
function BattleEngine:GetMove(battler, index: number)
	if index == 0 then
		return Moves.Get(Moves.FALLBACK_ID), nil
	end
	local slot = battler.Moves[index]
	return slot and Moves.Get(slot.Id), slot
end

-- Normaliza { Kind = "Double", Actions = ... } em mapa [fieldSlot] = action
local function mapSlotActions(action, slotsPerSide: number)
	if typeof(action.Actions) ~= "table" then
		return nil
	end
	local bySlot = {}
	for k, entry in pairs(action.Actions) do
		if typeof(entry) ~= "table" then
			return nil
		end
		local fs = if isInt(entry.FieldSlot) then entry.FieldSlot elseif isInt(k) then k else nil
		if not fs or fs < 1 or fs > slotsPerSide then
			return nil
		end
		if bySlot[fs] then
			return nil
		end
		bySlot[fs] = entry
	end
	return bySlot
end

-- Normaliza substituicao para lista { { FieldSlot = fs, Index = teamIdx }, ... }
local function normalizeReplacements(pendingSlots: { number }, actionOrChoice)
	if typeof(actionOrChoice) == "number" then
		if #pendingSlots ~= 1 then
			return nil
		end
		return { { FieldSlot = pendingSlots[1], Index = actionOrChoice } }
	end
	if typeof(actionOrChoice) ~= "table" then
		return nil
	end
	local rawList = actionOrChoice.Replacements
	if rawList == nil and actionOrChoice.Kind == nil then
		-- ResolveReplacement(side, { { FieldSlot = 1, Index = 3 }, ... })
		rawList = actionOrChoice
	end
	if typeof(rawList) == "table" then
		local out = {}
		for i, entry in ipairs(rawList) do
			if typeof(entry) == "table" and isInt(entry.Index) then
				local fs = if isInt(entry.FieldSlot) then entry.FieldSlot else pendingSlots[i]
				if not fs then
					return nil
				end
				table.insert(out, { FieldSlot = fs, Index = entry.Index })
			else
				return nil
			end
		end
		return out
	elseif isInt(actionOrChoice.Index) and #pendingSlots == 1 then
		return { { FieldSlot = pendingSlots[1], Index = actionOrChoice.Index } }
	end
	return nil
end

-- Valida a acao de um unico slot em campo (usado tanto no 1x1 quanto em cada slot do 2x2)
function BattleEngine:_ValidateSlotAction(side: string, fieldSlot: number, action, reservedSwitch, reservedItems): (boolean, string?)
	if typeof(action) ~= "table" or typeof(action.Kind) ~= "string" then
		return false, "A\u{e7}\u{e3}o inv\u{e1}lida."
	end
	local sideState = self.Sides[side]
	local active = self:ActiveAt(side, fieldSlot)
	if not active or active.Hp <= 0 then
		return false, "Slot inativo."
	end

	if action.Kind == "Move" then
		local index = action.Index
		if not isInt(index) then
			return false, "Golpe inv\u{e1}lido."
		end
		local move
		if index == 0 then
			if hasUsableMove(active) then
				return false, "Ainda h\u{e1} golpes com PP."
			end
			move = Moves.Get(Moves.FALLBACK_ID)
		else
			local slot = active.Moves[index]
			if not slot then
				return false, "Golpe inv\u{e1}lido."
			end
			if slot.Pp <= 0 then
				return false, "Esse golpe est\u{e1} sem PP."
			end
			move = Moves.Get(slot.Id)
		end

		if self:IsDouble() and Moves.TargetMode(move) == "Single" and index ~= 0 then
			local targetSide = action.TargetSide or "Enemy"
			if targetSide ~= "Enemy" and targetSide ~= "Ally" then
				return false, "Alvo inv\u{e1}lido."
			end
			local targetSlot = action.TargetSlot
			if targetSlot ~= nil then
				if not isInt(targetSlot) or targetSlot < 1 or targetSlot > self.SlotsPerSide then
					return false, "Alvo inv\u{e1}lido."
				end
				if targetSide == "Ally" then
					if targetSlot == fieldSlot then
						return false, "N\u{e3}o \u{e9} poss\u{ed}vel mirar em si mesmo."
					end
					local ally = self:ActiveAt(side, targetSlot)
					if not ally or ally.Hp <= 0 then
						return false, "Aliado inv\u{e1}lido."
					end
				end
			elseif targetSide == "Ally" then
				return false, "Alvo inv\u{e1}lido."
			end
		end
		return true
	elseif action.Kind == "Switch" then
		local member = isInt(action.Index) and sideState.Team[action.Index]
		if not member then
			return false, "Personagem inv\u{e1}lido."
		end
		if self:FieldSlotOf(side, action.Index) ~= nil then
			return false, member.Name .. " j\u{e1} est\u{e1} em campo."
		end
		if member.Hp <= 0 then
			return false, member.Name .. " est\u{e1} desmaiado."
		end
		if reservedSwitch and reservedSwitch[action.Index] then
			return false, member.Name .. " j\u{e1} foi escolhido para outro slot."
		end
		if reservedSwitch then
			reservedSwitch[action.Index] = true
		end
		return true
	elseif action.Kind == "Item" then
		if self.Mode == "PvP" then
			return false, "Itens desativados no PvP."
		end
		if side ~= "Player" then
			return false, "A\u{e7}\u{e3}o inv\u{e1}lida."
		end
		local itemId = action.ItemId
		local item = typeof(itemId) == "string" and Items.Get(itemId)
		if not item or not item.UsableInBattle then
			return false, "Esse item n\u{e3}o pode ser usado em batalha."
		end
		local already = if reservedItems then (reservedItems[itemId] or 0) else 0
		if (self.Bag[itemId] or 0) - already <= 0 then
			return false, "Voc\u{ea} n\u{e3}o tem " .. item.Name .. "."
		end
		if reservedItems then
			reservedItems[itemId] = already + 1
		end
		-- Selos: so contra selvagens (GDD secao 7) e apenas se houver 1 adversario em campo
		if item.Kind == "Capture" then
			if self.Mode ~= "Wild" then
				return false, "Selos s\u{f3} funcionam contra personagens selvagens."
			end
			if self.CaptureBlocked then
				return false, self.CaptureBlocked
			end
			local aliveFoes = self:AliveFieldSlots("Enemy")
			if #aliveFoes == 0 then
				return false, "Alvo inv\u{e1}lido."
			end
			if #aliveFoes > 1 then
				return false, "N\u{e3}o \u{e9} poss\u{ed}vel capturar com dois advers\u{e1}rios em campo."
			end
			return true
		end
		local targetIndex = action.TargetIndex
		if targetIndex == nil then
			targetIndex = sideState.ActiveSlots[fieldSlot]
		end
		local target = isInt(targetIndex) and sideState.Team[targetIndex]
		if not target then
			return false, "Alvo inv\u{e1}lido."
		end
		if item.Kind == "Revive" then
			if target.Hp > 0 then
				return false, target.Name .. " n\u{e3}o est\u{e1} desmaiado."
			end
			return true
		end
		if target.Hp <= 0 then
			return false, target.Name .. " est\u{e1} desmaiado."
		end
		if item.Kind == "HealHP" then
			if target.Hp >= target.MaxHp then
				return false, target.Name .. " j\u{e1} est\u{e1} com o HP cheio."
			end
			return true
		elseif item.Kind == "CureStatus" then
			if not target.Status then
				return false, target.Name .. " n\u{e3}o tem status."
			end
			return true
		elseif item.Kind == "RestorePP" then
			for _, slot in ipairs(target.Moves) do
				if slot.Pp < slot.MaxPp then
					return true
				end
			end
			return false, target.Name .. " est\u{e1} com o PP cheio."
		end
		return false, item.Name .. " n\u{e3}o funciona em batalha."
	elseif action.Kind == "Flee" then
		return true
	end
	return false, "A\u{e7}\u{e3}o inv\u{e1}lida."
end

-- Validacao de toda acao recebida. Retorna ok, mensagemDeErro.
function BattleEngine:ValidateAction(side: string, action): (boolean, string?)
	if typeof(action) ~= "table" or typeof(action.Kind) ~= "string" then
		return false, "A\u{e7}\u{e3}o inv\u{e1}lida."
	end
	local sideState = self.Sides[side]
	if not sideState then
		return false, "A\u{e7}\u{e3}o inv\u{e1}lida."
	end

	-- Escolha obrigatoria do(s) proximo(s) depois de um desmaio
	if self.State == "WaitingForReplacement" then
		local pending = self.PendingReplace[side]
		if not pending or #pending == 0 or action.Kind ~= "Replace" then
			return false, if pending and #pending > 0 then "Escolha o pr\u{f3}ximo personagem." else "Aguardando o advers\u{e1}rio."
		end
		local list = normalizeReplacements(pending, action)
		if not list or #list ~= #pending then
			return false, "Escolha todos os substitutos necess\u{e1}rios."
		end
		local needSlot = {}
		for _, fs in ipairs(pending) do
			needSlot[fs] = true
		end
		local usedTeam = {}
		for _, entry in ipairs(list) do
			if not needSlot[entry.FieldSlot] then
				return false, "Slot de substitui\u{e7}\u{e3}o inv\u{e1}lido."
			end
			needSlot[entry.FieldSlot] = nil
			local member = sideState.Team[entry.Index]
			if not member or member.Hp <= 0 or self:FieldSlotOf(side, entry.Index) ~= nil or usedTeam[entry.Index] then
				return false, "Esse personagem n\u{e3}o pode entrar."
			end
			usedTeam[entry.Index] = true
		end
		if next(needSlot) ~= nil then
			return false, "Escolha todos os substitutos necess\u{e1}rios."
		end
		return true
	end

	if self.State ~= "WaitingForInput" then
		return false, "Ainda n\u{e3}o \u{e9} a sua vez."
	end

	if action.Kind == "Flee" then
		return true
	end

	if not self:IsDouble() then
		return self:_ValidateSlotAction(side, 1, action)
	end

	-- Formato 2x2: aceita { Kind = "Double", Actions = { ... } }
	if action.Kind ~= "Double" then
		-- Conveniencia: se so ha 1 lutador vivo em campo, tambem aceita acao simples direta
		local aliveSlots = self:AliveFieldSlots(side)
		if #aliveSlots == 1 then
			return self:_ValidateSlotAction(side, aliveSlots[1], action)
		end
		return false, "Escolha a a\u{e7}\u{e3}o de todos os lutadores em campo."
	end

	local bySlot = mapSlotActions(action, self.SlotsPerSide)
	if not bySlot then
		return false, "A\u{e7}\u{f5}es de dupla inv\u{e1}lidas."
	end
	local aliveSlots = self:AliveFieldSlots(side)
	local reservedSwitch = {}
	local reservedItems = {}
	for _, fs in ipairs(aliveSlots) do
		local sub = bySlot[fs]
		if not sub or sub.Kind == "Flee" or sub.Kind == "Double" or sub.Kind == "Replace" then
			return false, "Faltou escolher a a\u{e7}\u{e3}o de um personagem em campo."
		end
		local ok, err = self:_ValidateSlotAction(side, fs, sub, reservedSwitch, reservedItems)
		if not ok then
			return false, err
		end
	end
	return true
end

-- Velocidade efetiva do lutador considerando Tailwind do lado
function BattleEngine:_EffectiveSpeed(side: string, actor): number
	local spd = DamageCalc.EffectiveStat(actor, "Speed")
	local sideState = self.Sides[side]
	if sideState and sideState.SideEffects and sideState.SideEffects.Tailwind > 0 then
		spd = math.floor(spd * 2)
	end
	return spd
end

-- Prioridade da acao na fila do turno: Flee (10) > Switch/Item (6) > Golpes (move.Priority ou 0)
function BattleEngine:_ActionPriority(actor, sub): number
	if sub.Kind == "Flee" then
		return 10
	elseif sub.Kind == "Switch" or sub.Kind == "Item" then
		return 6
	elseif sub.Kind == "Move" and actor then
		local move = self:GetMove(actor, sub.Index)
		return if move and typeof(move.Priority) == "number" then move.Priority else 0
	end
	return 0
end

-- Empilha acoes de um lado na fila do turno
function BattleEngine:_EnqueueSide(queue, side: string, sideAction)
	if sideAction.Kind == "Flee" then
		table.insert(queue, {
			Side = side,
			FieldSlot = 0,
			Action = sideAction,
			Priority = 10,
			Speed = 0,
			Tiebreak = self.Rng:NextNumber(),
		})
		return
	end
	if not self:IsDouble() then
		local actor = self:ActiveAt(side, 1)
		if actor and actor.Hp > 0 then
			table.insert(queue, {
				Side = side,
				FieldSlot = 1,
				Actor = actor,
				Action = sideAction,
				Priority = self:_ActionPriority(actor, sideAction),
				Speed = self:_EffectiveSpeed(side, actor),
				Tiebreak = self.Rng:NextNumber(),
			})
		end
		return
	end

	local bySlot
	if sideAction.Kind == "Double" then
		bySlot = mapSlotActions(sideAction, self.SlotsPerSide)
	else
		local alive = self:AliveFieldSlots(side)
		if #alive == 1 then
			bySlot = { [alive[1]] = sideAction }
		end
	end
	for _, fs in ipairs(self:AliveFieldSlots(side)) do
		local sub = bySlot and bySlot[fs]
		local actor = self:ActiveAt(side, fs)
		if sub and actor and actor.Hp > 0 then
			table.insert(queue, {
				Side = side,
				FieldSlot = fs,
				Actor = actor,
				Action = sub,
				Priority = self:_ActionPriority(actor, sub),
				Speed = self:_EffectiveSpeed(side, actor),
				Tiebreak = self.Rng:NextNumber(),
			})
		end
	end
end

-- Dispara evento visual/log de ativacao de Passiva
function BattleEngine:_PushPassive(side: string, fieldSlot: number, battler, push, text: string?)
	local p = passiveOf(battler)
	if not p then
		return
	end
	push({
		Kind = "Passive",
		Side = side,
		FieldSlot = fieldSlot,
		PassiveId = p.Id,
		PassiveName = p.Name,
		PassiveTier = p.Tier,
		Text = text or (battler.Name .. " ativou " .. p.Name .. "!"),
	})
end

-- Passivas de entrada em campo (ex.: Intimidacao reduz Ataque dos adversarios)
function BattleEngine:_TriggerOnEnter(side: string, fieldSlot: number, battler, push)
	if not battler or battler.Hp <= 0 then
		return
	end
	local p, eff = passiveOf(battler)
	if not p or not eff or not eff.OnEnterDebuff then
		return
	end
	local foeSide = otherSide(side)
	local aliveFoes = self:AliveFieldSlots(foeSide)
	if #aliveFoes == 0 then
		return
	end
	self:_PushPassive(side, fieldSlot, battler, push, battler.Name .. " intimidou o advers\u{e1}rio com " .. p.Name .. "!")
	for _, fs in ipairs(aliveFoes) do
		local foe = self:ActiveAt(foeSide, fs)
		if foe and foe.Hp > 0 then
			self:_ApplyStatStage(foeSide, fs, foe, eff.OnEnterDebuff.Stat, eff.OnEnterDebuff.Stages, false, push, side)
		end
	end
end

-- Passivas de limiar de HP (ex.: Instinto Zenkai <50%, Vontade de D <40%)
function BattleEngine:_CheckThresholdPassive(side: string, fieldSlot: number, battler, push)
	if not battler or battler.Hp <= 0 or battler.ThresholdUsed then
		return
	end
	local p, eff = passiveOf(battler)
	local trig = eff and eff.ThresholdTrigger
	if not p or not trig then
		return
	end
	if (battler.Hp / math.max(1, battler.MaxHp)) < trig.Below then
		battler.ThresholdUsed = true
		battler.AwakenTriggered = true
		self:_PushPassive(side, fieldSlot, battler, push, battler.Name .. " despertou " .. p.Name .. "!")
		if trig.HealFraction and battler.Hp < battler.MaxHp then
			local healed = math.min(battler.MaxHp - battler.Hp, math.max(1, math.floor(battler.MaxHp * trig.HealFraction)))
			if healed > 0 then
				battler.Hp += healed
				push({
					Kind = "Heal",
					Side = side,
					FieldSlot = fieldSlot,
					Active = true,
					Amount = healed,
					Hp = battler.Hp,
					MaxHp = battler.MaxHp,
					Text = battler.Name .. " recuperou " .. healed .. " de HP!",
				})
			end
		end
		for _, buff in ipairs(trig.Buffs or {}) do
			self:_ApplyStatStage(side, fieldSlot, battler, buff.Stat, buff.Stages, false, push, side)
		end
	end
end

-- Resolve um turno inteiro. Devolve a lista de eventos, na ordem em que aconteceram.
-- enemyAction: so no PvP (o outro jogador); sem ela, a IA escolhe.
-- prefix: eventos que entram antes (ex.: aviso de tempo esgotado)
function BattleEngine:ResolveTurn(playerAction, enemyAction, prefix)
	local ok, err = self:ValidateAction("Player", playerAction)
	assert(ok, err)
	if enemyAction then
		local okE, errE = self:ValidateAction("Enemy", enemyAction)
		assert(okE, errE)
	end
	assert(self.State == "WaitingForInput", "Fora de turno")
	self.State = "Resolving"

	-- Protecoes duram apenas 1 turno e sao resetadas no inicio da resolucao
	for _, sideName in ipairs(SIDES) do
		local s = self.Sides[sideName]
		s.WideProtected = false
		for _, b in ipairs(s.Team) do
			b.Protected = false
		end
	end

	local events = {}
	local function push(ev)
		table.insert(events, ev)
	end
	for _, ev in ipairs(prefix or {}) do
		push(ev)
	end

	-- Passivas de entrada dos lutadores iniciais no Turno 1 (ordenadas por Velocidade)
	if not self._EntryPassivesDone then
		self._EntryPassivesDone = true
		local starters = {}
		for _, sideName in ipairs(SIDES) do
			for _, fs in ipairs(self:AliveFieldSlots(sideName)) do
				local b = self:ActiveAt(sideName, fs)
				if b and b.Hp > 0 then
					table.insert(starters, {
						Side = sideName,
						FieldSlot = fs,
						Battler = b,
						Speed = self:_EffectiveSpeed(sideName, b),
					})
				end
			end
		end
		table.sort(starters, function(a, b)
			return a.Speed > b.Speed
		end)
		for _, st in ipairs(starters) do
			self:_TriggerOnEnter(st.Side, st.FieldSlot, st.Battler, push)
		end
	end

	local enemy = self.Sides.Enemy
	if not enemyAction then
		if self:IsDouble() then
			enemyAction = AIController.ChooseActionsDouble(self.EnemyAI, enemy, self.Sides.Player, self.Rng)
		else
			enemyAction = AIController.ChooseAction(
				self.EnemyAI, self:Active("Enemy"), self:Active("Player"), self.Rng, enemy.Team, enemy.Active
			)
		end
	end

	-- Ordem (GDD + Pokemon 2x2): fuga, troca e item primeiro; depois golpes do mais veloz ao mais lento; empate sorteado
	local queue = {}
	self:_EnqueueSide(queue, "Player", playerAction)
	self:_EnqueueSide(queue, "Enemy", enemyAction)

	table.sort(queue, function(a, b)
		if a.Priority ~= b.Priority then
			return a.Priority > b.Priority
		end
		if a.Speed ~= b.Speed then
			return a.Speed > b.Speed
		end
		return a.Tiebreak > b.Tiebreak
	end)

	self._ActedThisTurn = {}
	for _, q in ipairs(queue) do
		if self.Winner then
			break
		end
		local kind = q.Action.Kind
		if kind == "Flee" then
			self:_DoFlee(q.Side, push)
		else
			-- quem desmaiou (ou saiu do slot) antes de agir perde a acao
			local current = self:ActiveAt(q.Side, q.FieldSlot)
			if current and current == q.Actor and current.Hp > 0 then
				if kind == "Move" then
					self:_DoMove(q.Side, q.FieldSlot, q.Action, push)
				elseif kind == "Switch" then
					self:_DoSwitch(q.Side, q.FieldSlot, q.Action.Index, push, false)
				elseif kind == "Item" then
					self:_DoItem(q.Side, q.FieldSlot, q.Action.ItemId, q.Action.TargetIndex, push)
				end
				self._ActedThisTurn[current] = true
			end
		end
	end
	self._ActedThisTurn = nil

	if not self.Winner then
		self:_EndOfTurn(push)
	end
	self:_AfterTurn(push)
	return events
end

-- Depois do turno: fim de batalha, substituicao da maquina e pedido de escolha ao jogador
function BattleEngine:_AfterTurn(push)
	if self.Winner then
		self.State = "Ended"
		return
	end
	self.Turn += 1

	for _, side in ipairs({ "Enemy", "Player" }) do
		local s = self.Sides[side]
		local faintedSlots = {}
		for fs = 1, self.SlotsPerSide do
			local idx = s.ActiveSlots[fs]
			if idx and s.Team[idx] and s.Team[idx].Hp <= 0 then
				table.insert(faintedSlots, fs)
			end
		end
		if #faintedSlots > 0 then
			local bench = self:BenchAliveIndices(side)
			if side == "Enemy" and not self.EnemyHuman then
				-- Maquina escolhe imediatamente quantos substitutos tiver no banco (repete se cair em hazards de entrada)
				local foe = self:Active("Player")
				local exclude = {}
				for _, fs in ipairs(faintedSlots) do
					local filled = false
					while not self.Winner do
						local nextIdx = AIController.ChooseReplacement(self.EnemyAI, s.Team, s.ActiveSlots, foe, self.Rng, exclude)
						if not nextIdx then
							break
						end
						exclude[nextIdx] = true
						self:_DoSwitch("Enemy", fs, nextIdx, push, true)
						local entered = self:ActiveAt("Enemy", fs)
						if entered and entered.Hp > 0 then
							filled = true
							break
						end
					end
					if self.Winner then
						self.State = "Ended"
						return
					end
					if not filled then
						s.ActiveSlots[fs] = nil
						push({ Kind = "ClearSlot", Side = "Enemy", FieldSlot = fs })
					end
				end
			else
				local needCount = math.min(#faintedSlots, #bench)
				for i = needCount + 1, #faintedSlots do
					local emptySlot = faintedSlots[i]
					s.ActiveSlots[emptySlot] = nil
					push({ Kind = "ClearSlot", Side = side, FieldSlot = emptySlot })
				end
				if needCount > 0 then
					local pending = {}
					for i = 1, needCount do
						table.insert(pending, faintedSlots[i])
					end
					self.PendingReplace[side] = pending
				end
			end
		end
		self:SyncLegacyActive(side)
	end

	self.State = if next(self.PendingReplace) then "WaitingForReplacement" else "WaitingForInput"
end

-- Desistir no PvP: vale na hora, sem esperar a escolha do outro lado
function BattleEngine:Forfeit(side: string, reason: string?)
	local events = {}
	if self.State == "Ended" then
		return events
	end
	local function push(ev)
		table.insert(events, ev)
	end
	if reason == "Disconnect" then
		push({ Kind = "Message", Text = "O advers\u{e1}rio desconectou.", TextEnemy = "O advers\u{e1}rio desconectou." })
	else
		self:_DoFlee(side, push)
	end
	self.Winner = otherSide(side)
	self.EndReason = reason or "Forfeit"
	self.State = "Ended"
	return events
end

-- Acao automatica quando o tempo do turno acaba (golpe aleatorio com PP, ou o golpe reserva)
function BattleEngine:AutoAction(side: string)
	if self:IsDouble() then
		return AIController.ChooseActionsDouble("Facil", self.Sides[side], self.Sides[otherSide(side)], self.Rng)
	end
	return AIController.ChooseAction("Facil", self:Active(side), self:Active(otherSide(side)), self.Rng)
end

-- Substituicao automatica: proximo(s) de pe na ordem do time
function BattleEngine:AutoReplacement(side: string)
	local s = self.Sides[side]
	local pending = self.PendingReplace[side]
	if not self:IsDouble() then
		return AIController.ChooseReplacement("Facil", s.Team, s.ActiveSlots, self:Active(otherSide(side)), self.Rng)
	end
	local list = {}
	local exclude = {}
	for _, fs in ipairs(pending or {}) do
		local idx = AIController.ChooseReplacement("Facil", s.Team, s.ActiveSlots, self:Active(otherSide(side)), self.Rng, exclude)
		if idx then
			exclude[idx] = true
			table.insert(list, { FieldSlot = fs, Index = idx })
		end
	end
	return list
end

-- Escolha do(s) proximo(s) depois de um desmaio (estado WaitingForReplacement)
-- choice pode ser numero (1x1 ou 1 slot pendente) ou lista { { FieldSlot = fs, Index = idx }, ... }
function BattleEngine:ResolveReplacement(side: string, choice)
	local pending = self.PendingReplace[side]
	local action = if typeof(choice) == "number"
		then { Kind = "Replace", Index = choice }
		else { Kind = "Replace", Replacements = choice }
	local ok, err = self:ValidateAction(side, action)
	assert(ok, err)
	local list = normalizeReplacements(pending, action)
	local events = {}
	local function push(ev)
		table.insert(events, ev)
	end
	for _, entry in ipairs(list) do
		if self.Winner then
			break
		end
		self:_DoSwitch(side, entry.FieldSlot, entry.Index, push, true)
	end
	if self.Winner then
		self.PendingReplace = {}
		self:SyncLegacyActive(side)
		self.State = "Ended"
		return events
	end
	-- Se algum substituto desmaiou ao pisar em hazards de entrada, pede novo substituto ou limpa o slot
	local s = self.Sides[side]
	local stillFainted = {}
	for _, entry in ipairs(list) do
		local b = self:ActiveAt(side, entry.FieldSlot)
		if b and b.Hp <= 0 then
			table.insert(stillFainted, entry.FieldSlot)
		end
	end
	if #stillFainted > 0 then
		local bench = self:BenchAliveIndices(side)
		local needCount = math.min(#stillFainted, #bench)
		for i = needCount + 1, #stillFainted do
			local emptySlot = stillFainted[i]
			s.ActiveSlots[emptySlot] = nil
			push({ Kind = "ClearSlot", Side = side, FieldSlot = emptySlot })
		end
		if needCount > 0 then
			local nextPending = {}
			for i = 1, needCount do
				table.insert(nextPending, stillFainted[i])
			end
			self.PendingReplace[side] = nextPending
		else
			self.PendingReplace[side] = nil
		end
	else
		self.PendingReplace[side] = nil
	end
	self:SyncLegacyActive(side)
	self.State = if next(self.PendingReplace) then "WaitingForReplacement" else "WaitingForInput"
	return events
end

-- Paralisia, sono e congelamento podem impedir o golpe. Retorna true se pode agir.
function BattleEngine:_CanAct(side: string, fieldSlot: number, actor, push): boolean
	if actor.Status == "Sleep" then
		push({ Kind = "Message", Side = side, FieldSlot = fieldSlot, Text = actor.Name .. " est\u{e1} dormindo." })
		return false
	end
	if actor.Status == "Freeze" then
		if self.Rng:NextNumber() < DamageCalc.STATUS.Freeze.ThawChance then
			actor.Status = nil
			push({ Kind = "StatusCured", Side = side, FieldSlot = fieldSlot, Status = "Freeze", Text = actor.Name .. " descongelou!" })
		else
			push({ Kind = "Message", Side = side, FieldSlot = fieldSlot, Text = actor.Name .. " est\u{e1} congelado e n\u{e3}o consegue se mover." })
			return false
		end
	end
	if actor.Status == "Paralysis" and self.Rng:NextNumber() < DamageCalc.STATUS.Paralysis.SkipChance then
		push({ Kind = "Message", Side = side, FieldSlot = fieldSlot, Text = actor.Name .. " est\u{e1} paralisado! N\u{e3}o consegue se mover." })
		return false
	end
	return true
end

-- Resolve a lista de alvos de um golpe no momento da execucao (com redirecionamento Pokemon 2x2)
function BattleEngine:_ResolveTargets(side: string, fieldSlot: number, move, action)
	local targetMode = Moves.TargetMode(move)
	local foeSide = otherSide(side)
	local targets = {}

	if targetMode == "Self" then
		local actor = self:ActiveAt(side, fieldSlot)
		if actor and actor.Hp > 0 then
			table.insert(targets, { Side = side, FieldSlot = fieldSlot, Battler = actor })
		end
		return targets, targetMode
	elseif targetMode == "AllAllies" then
		for _, fs in ipairs(self:AliveFieldSlots(side)) do
			table.insert(targets, { Side = side, FieldSlot = fs, Battler = self:ActiveAt(side, fs) })
		end
		return targets, targetMode
	elseif targetMode == "AllEnemies" then
		for _, fs in ipairs(self:AliveFieldSlots(foeSide)) do
			table.insert(targets, { Side = foeSide, FieldSlot = fs, Battler = self:ActiveAt(foeSide, fs) })
		end
		return targets, targetMode
	elseif targetMode == "AllOthers" then
		for _, fs in ipairs(self:AliveFieldSlots(foeSide)) do
			table.insert(targets, { Side = foeSide, FieldSlot = fs, Battler = self:ActiveAt(foeSide, fs) })
		end
		for _, fs in ipairs(self:AliveFieldSlots(side)) do
			if fs ~= fieldSlot then
				table.insert(targets, { Side = side, FieldSlot = fs, Battler = self:ActiveAt(side, fs) })
			end
		end
		return targets, targetMode
	elseif targetMode == "EnemySide" then
		local alive = self:AliveFieldSlots(foeSide)
		local fs = alive[1] or 1
		local foe = self:ActiveAt(foeSide, fs)
		if foe and foe.Hp > 0 then
			table.insert(targets, { Side = foeSide, FieldSlot = fs, Battler = foe, IsSideTarget = true })
		end
		return targets, targetMode
	end

	-- "Single" (padrao)
	local reqSide = if action.TargetSide == "Ally" then side else foeSide
	local reqSlot = action.TargetSlot
	if not reqSlot then
		local alive = self:AliveFieldSlots(reqSide)
		reqSlot = alive[1] or 1
	end
	local chosen = self:ActiveAt(reqSide, reqSlot)
	if chosen and chosen.Hp > 0 then
		table.insert(targets, { Side = reqSide, FieldSlot = reqSlot, Battler = chosen })
		return targets, targetMode
	end

	-- Redirecionamento Pokemon 2x2: se o inimigo escolhido ja desmaiou neste turno, redireciona para o outro inimigo de pe
	if reqSide == foeSide then
		for _, fs in ipairs(self:AliveFieldSlots(foeSide)) do
			table.insert(targets, { Side = foeSide, FieldSlot = fs, Battler = self:ActiveAt(foeSide, fs) })
			break
		end
	end
	return targets, targetMode
end

local function isSelfOrFieldEffect(effect): boolean
	if not effect then
		return false
	end
	return effect.Target == "Self"
		or effect.Kind == "ClearHazards"
		or effect.Kind == "Hazard"
		or effect.Kind == "SideEffect"
		or effect.Kind == "Protect"
		or effect.Kind == "WideProtect"
end

function BattleEngine:_DoMove(side: string, fieldSlot: number, action, push)
	local actor = self:ActiveAt(side, fieldSlot)
	local move, slot = self:GetMove(actor, action.Index)

	if not self:_CanAct(side, fieldSlot, actor, push) then
		actor.ProtectStreak = 0
		return -- o PP nao e gasto
	end

	local isProtectMove = move.Effect ~= nil and (move.Effect.Kind == "Protect" or move.Effect.Kind == "WideProtect")
	if not isProtectMove then
		actor.ProtectStreak = 0
	end

	if slot then
		slot.Pp -= 1
	end

	local targets, targetMode = self:_ResolveTargets(side, fieldSlot, move, action)
	local targetRefs = {}
	for _, t in ipairs(targets) do
		table.insert(targetRefs, { Side = t.Side, FieldSlot = t.FieldSlot })
	end

	push({
		Kind = "UseMove",
		Side = side,
		FieldSlot = fieldSlot,
		MoveId = move.Id,
		MoveName = move.Name,
		MoveType = move.Type,
		TargetMode = targetMode,
		TargetSide = targets[1] and targets[1].Side or otherSide(side),
		TargetFieldSlot = targets[1] and targets[1].FieldSlot or 1,
		Targets = targetRefs,
		Text = actor.Name .. " usou " .. move.Name .. "!",
	})

	if #targets == 0 then
		push({ Kind = "Message", Text = "Mas n\u{e3}o havia alvo." })
		return
	end

	local isSpread = targetMode == "AllEnemies" or targetMode == "AllOthers"
	local spreadMult = if isSpread and #targets >= 2 then DamageCalc.SPREAD_MULTIPLIER else 1
	local multiTarget = #targets > 1
	local selfFieldEffectDone = false
	local aPassive, aEff = passiveOf(actor)
	local shownPassiveForMove = {}

	for _, t in ipairs(targets) do
		if self.Winner or actor.Hp <= 0 then
			break
		end
		if t.Battler.Hp <= 0 then
			continue
		end

		-- Verificacao de Protect / WideProtect (nao bloqueia golpes em si, aliados ou hazards de lado)
		if t.Side ~= side and not t.IsSideTarget then
			if move.BreaksProtect then
				if t.Battler.Protected then
					t.Battler.Protected = false
					push({ Kind = "Message", Side = t.Side, FieldSlot = t.FieldSlot, Text = actor.Name .. " rompeu a prote\u{e7}\u{e3}o de " .. t.Battler.Name .. "!" })
				end
			else
				if t.Battler.Protected then
					push({
						Kind = "Protected",
						Side = t.Side,
						FieldSlot = t.FieldSlot,
						Text = t.Battler.Name .. " se protegeu!",
					})
					continue
				elseif isSpread and self.Sides[t.Side].WideProtected then
					push({
						Kind = "Protected",
						Side = t.Side,
						FieldSlot = t.FieldSlot,
						Text = t.Battler.Name .. " foi protegido pela Guarda Ampla!",
					})
					continue
				end
			end
		end

		-- Precisao por alvo (golpes em si ou no lado do campo nunca erram; Olho de Aguia soma +10%)
		if move.Accuracy and targetMode ~= "Self" and not t.IsSideTarget then
			local baseAcc = move.Accuracy + (if aEff and aEff.AccuracyBonus then aEff.AccuracyBonus else 0)
			local chance = baseAcc * DamageCalc.StageMultiplier(actor.Stages.Accuracy)
			if self.Rng:NextNumber() * 100 >= chance then
				push({
					Kind = "Miss",
					Side = side,
					FieldSlot = fieldSlot,
					TargetSide = t.Side,
					TargetFieldSlot = t.FieldSlot,
					Text = if multiTarget then t.Battler.Name .. " desviou!" else "Mas errou!",
				})
				continue
			end
		end

		if move.Category == "Damage" then
			local barrierMult = if self.Sides[t.Side].SideEffects.Barrier > 0
				then (if self:IsDouble() then 0.75 else 0.67)
				else 1
			local targetActed = self._ActedThisTurn ~= nil and self._ActedThisTurn[t.Battler] == true
			local result = DamageCalc.Compute(actor, t.Battler, move, self.Rng, spreadMult, barrierMult, {
				TargetActedThisTurn = targetActed,
				IsSpread = isSpread,
			})
			local dPassive, dEff = passiveOf(t.Battler)

			-- Anuncia ativacoes marcantes de Passiva (sem repetir no mesmo golpe multi-alvo)
			for _, trig in ipairs(result.Triggers or {}) do
				local whoKey = trig.Who .. "_" .. trig.Passive.Id .. "_" .. tostring(t.FieldSlot)
				if not shownPassiveForMove[whoKey] then
					shownPassiveForMove[whoKey] = true
					if trig.Who == "Attacker" then
						self:_PushPassive(side, fieldSlot, actor, push, actor.Name .. " ativou " .. trig.Passive.Name .. "!")
					else
						self:_PushPassive(t.Side, t.FieldSlot, t.Battler, push, t.Battler.Name .. " ativou " .. trig.Passive.Name .. "!")
					end
				end
			end

			-- Firmeza (Sturdy): se estava com 100% HP, resiste ao golpe fatal ficando com 1 HP
			local finalDmg = result.Damage
			local sturdyTriggered = false
			if dEff and dEff.Sturdy and not t.Battler.SturdyUsed and t.Battler.Hp >= t.Battler.MaxHp and finalDmg >= t.Battler.Hp then
				finalDmg = math.max(0, t.Battler.Hp - 1)
				t.Battler.SturdyUsed = true
				sturdyTriggered = true
			end

			t.Battler.Hp = math.max(0, t.Battler.Hp - finalDmg)
			push({
				Kind = "Damage",
				Side = t.Side,
				FieldSlot = t.FieldSlot,
				Amount = finalDmg,
				Hp = t.Battler.Hp,
				MaxHp = t.Battler.MaxHp,
				Crit = result.Crit,
				TypeMultiplier = result.TypeMultiplier,
				MoveType = move.Type,
				Spread = result.Spread,
				Text = t.Battler.Name .. " perdeu " .. finalDmg .. " de HP.",
			})
			if sturdyTriggered then
				self:_PushPassive(t.Side, t.FieldSlot, t.Battler, push, t.Battler.Name .. " resistiu com 1 HP gra\u{e7}as \u{e0} " .. (dPassive and dPassive.Name or "Firmeza") .. "!")
			end
			if result.Crit then
				push({ Kind = "Message", Text = if multiTarget then "Golpe cr\u{ed}tico em " .. t.Battler.Name .. "!" else "Golpe cr\u{ed}tico!" })
			end
			if result.TypeMultiplier > 1 then
				push({ Kind = "Message", Text = if multiTarget then "\u{c9} super efetivo em " .. t.Battler.Name .. "!" else "\u{c9} super efetivo!" })
			elseif result.TypeMultiplier < 1 then
				push({ Kind = "Message", Text = if multiTarget then "N\u{e3}o \u{e9} muito efetivo em " .. t.Battler.Name .. "..." else "N\u{e3}o \u{e9} muito efetivo..." })
			end

			-- Dreno de vida (absorve parte do dano causado)
			if move.Drain and finalDmg > 0 and actor.Hp > 0 and actor.Hp < actor.MaxHp then
				local healed = math.min(actor.MaxHp - actor.Hp, math.max(1, math.floor(finalDmg * move.Drain)))
				if healed > 0 then
					actor.Hp += healed
					push({
						Kind = "Heal",
						Side = side,
						FieldSlot = fieldSlot,
						Active = true,
						Amount = healed,
						Hp = actor.Hp,
						MaxHp = actor.MaxHp,
						Text = actor.Name .. " absorveu " .. healed .. " de HP!",
					})
				end
			end

			local targetFainted = t.Battler.Hp <= 0
			if targetFainted then
				self:_Faint(t.Side, t.FieldSlot, push)
				-- Passivas ao nocautear um adversario (Sede de Vitoria / Despertar Hollow)
				if not self.Winner and t.Side ~= side and actor.Hp > 0 and aEff and (aEff.OnKoSelfBuff or aEff.OnKoHealFraction) then
					self:_PushPassive(side, fieldSlot, actor, push, actor.Name .. " ativou " .. (aPassive and aPassive.Name or "Passiva") .. "!")
					if aEff.OnKoSelfBuff then
						self:_ApplyStatStage(side, fieldSlot, actor, aEff.OnKoSelfBuff.Stat, aEff.OnKoSelfBuff.Stages, false, push, side)
					end
					if aEff.OnKoHealFraction and actor.Hp < actor.MaxHp then
						local koHeal = math.min(actor.MaxHp - actor.Hp, math.max(1, math.floor(actor.MaxHp * aEff.OnKoHealFraction)))
						if koHeal > 0 then
							actor.Hp += koHeal
							push({
								Kind = "Heal",
								Side = side,
								FieldSlot = fieldSlot,
								Active = true,
								Amount = koHeal,
								Hp = actor.Hp,
								MaxHp = actor.MaxHp,
								Text = actor.Name .. " recuperou " .. koHeal .. " de HP!",
							})
						end
					end
				end
			else
				-- Passivas de limiar de HP no defensor (Instinto Zenkai / Vontade de D)
				self:_CheckThresholdPassive(t.Side, t.FieldSlot, t.Battler, push)
			end

			-- Contra-Espinhos (reflete dano em golpes de Espadachim ou Lutador)
			if not self.Winner and t.Side ~= side and finalDmg > 0 and actor.Hp > 0
				and dEff and dEff.ContactReflectFraction and dEff.ContactTypes and dEff.ContactTypes[move.Type] then
				local refl = math.max(1, math.floor(actor.MaxHp * dEff.ContactReflectFraction))
				actor.Hp = math.max(0, actor.Hp - refl)
				self:_PushPassive(t.Side, t.FieldSlot, t.Battler, push, (dPassive and dPassive.Name or "Contra-Espinhos") .. " feriu " .. actor.Name .. "!")
				push({
					Kind = "Damage",
					Side = side,
					FieldSlot = fieldSlot,
					Amount = refl,
					Hp = actor.Hp,
					MaxHp = actor.MaxHp,
					Recoil = true,
					Text = actor.Name .. " sofreu " .. refl .. " de dano refletido!",
				})
				if actor.Hp <= 0 then
					self:_Faint(side, fieldSlot, push)
				else
					self:_CheckThresholdPassive(side, fieldSlot, actor, push)
				end
			end

			-- Efeito secundario (se for no usuario/campo, aplica mesmo se o alvo desmaiou, e no maximo 1 vez por uso)
			if move.Effect and not self.Winner and actor.Hp > 0 then
				if isSelfOrFieldEffect(move.Effect) then
					if not selfFieldEffectDone then
						selfFieldEffectDone = true
						self:_ApplyEffect(side, fieldSlot, t.Side, t.FieldSlot, move.Effect, false, multiTarget, push)
					end
				elseif not targetFainted then
					self:_ApplyEffect(side, fieldSlot, t.Side, t.FieldSlot, move.Effect, false, multiTarget, push)
				end
			end

			-- Recuo (usuario sofre parte do dano causado)
			if move.Recoil and finalDmg > 0 and actor.Hp > 0 and not self.Winner then
				local recoil = math.max(1, math.floor(finalDmg * move.Recoil))
				actor.Hp = math.max(0, actor.Hp - recoil)
				push({
					Kind = "Damage",
					Side = side,
					FieldSlot = fieldSlot,
					Amount = recoil,
					Hp = actor.Hp,
					MaxHp = actor.MaxHp,
					Recoil = true,
					MoveType = move.Type,
					Text = actor.Name .. " sofreu " .. recoil .. " de recuo!",
				})
				if actor.Hp <= 0 then
					self:_Faint(side, fieldSlot, push)
				else
					self:_CheckThresholdPassive(side, fieldSlot, actor, push)
				end
			end
		else
			self:_ApplyEffect(side, fieldSlot, t.Side, t.FieldSlot, move.Effect, true, multiTarget, push)
		end
	end
end

-- Aplica um status em um lutador ativo. Retorna true se aplicou.
function BattleEngine:_SetStatus(side: string, fieldSlot: number, status: string, push, isPrimary: boolean?): boolean
	assert(DamageCalc.STATUS[status], "Status desconhecido: " .. tostring(status))
	local target = self:ActiveAt(side, fieldSlot)
	if not target or target.Hp <= 0 then
		return false
	end
	local tPassive, tEff = passiveOf(target)
	if tEff and tEff.StatusImmune and tEff.StatusImmune[status] then
		self:_PushPassive(side, fieldSlot, target, push, (tPassive and tPassive.Name or "Passiva") .. " protegeu " .. target.Name .. " contra " .. (STATUS_DISPLAY[status] or status) .. "!")
		return false
	end
	if target.Status then
		if isPrimary then
			push({ Kind = "Message", Text = "Mas n\u{e3}o teve efeito." })
		end
		return false
	end
	target.Status = status
	if status == "Sleep" then
		local rule = DamageCalc.STATUS.Sleep
		target.StatusTurns = self.Rng:NextInteger(rule.MinTurns, rule.MaxTurns)
	end
	push({ Kind = "Status", Side = side, FieldSlot = fieldSlot, Status = status, Text = target.Name .. STATUS_TEXT[status] })
	return true
end

-- Uso externo (testes, itens e golpes futuros): aplica um status e devolve os eventos
function BattleEngine:ApplyStatus(side: string, status: string, fieldSlot: number?)
	local events = {}
	self:_SetStatus(side, fieldSlot or 1, status, function(ev)
		table.insert(events, ev)
	end, true)
	return events
end

function BattleEngine:_PushFieldUpdate(side: string, push, text: string?, textEnemy: string?)
	local s = self.Sides[side]
	push({
		Kind = "FieldUpdate",
		Side = side,
		Hazards = table.clone(s.Hazards),
		SideEffects = table.clone(s.SideEffects),
		Text = text,
		TextEnemy = if self.EnemyHuman then textEnemy else nil,
	})
end

function BattleEngine:_ApplyStatStage(targetSide: string, targetSlot: number, target, stat: string, delta: number, announceCap: boolean, push, sourceSide: string?): boolean
	local statName = STAT_NAMES[stat] or stat
	-- Protecao de passiva contra quedas de atributo causadas pelo adversario
	if delta < 0 and sourceSide ~= nil and sourceSide ~= targetSide then
		local tPassive, tEff = passiveOf(target)
		if tEff and (tEff.BlockAllEnemyStatDrops or (tEff.BlockStatDrop and tEff.BlockStatDrop[stat])) then
			self:_PushPassive(targetSide, targetSlot, target, push, (tPassive and tPassive.Name or "Passiva") .. " impediu a queda de " .. statName .. " de " .. target.Name .. "!")
			return false
		end
	end
	local before = target.Stages[stat] or 0
	local after = math.clamp(before + delta, DamageCalc.MIN_STAGE, DamageCalc.MAX_STAGE)
	if after == before then
		if announceCap then
			push({ Kind = "Message", Text = statName .. " de " .. target.Name .. " n\u{e3}o pode mudar mais." })
		end
		return false
	end
	target.Stages[stat] = after
	local verb = if delta >= 2 then " aumentou muito!" elseif delta > 0 then " aumentou!" elseif delta <= -2 then " caiu muito!" else " diminuiu!"
	push({
		Kind = "StatStage",
		Side = targetSide,
		FieldSlot = targetSlot,
		Stat = stat,
		Stage = after,
		Text = statName .. " de " .. target.Name .. verb,
	})
	return true
end

-- Aplica o Effect de um golpe. isPrimary = golpe de status (avisa quando falha).
function BattleEngine:_ApplyEffect(actorSide: string, actorSlot: number, hitSide: string, hitSlot: number, effect, isPrimary: boolean, multiTarget: boolean, push)
	if not effect then
		return
	end
	local actor = self:ActiveAt(actorSide, actorSlot)
	local _, aEff = passiveOf(actor)
	local chance = effect.Chance or 100
	if not isPrimary and aEff and aEff.SecondaryChanceMult and chance < 100 then
		chance = math.min(100, chance * aEff.SecondaryChanceMult)
	end
	if self.Rng:NextNumber() * 100 >= chance then
		return
	end

	local kind = effect.Kind

	-- Efeitos de protecao e de campo (independem de alvo inimigo estar vivo)
	if kind == "Protect" then
		if not actor or actor.Hp <= 0 then
			return
		end
		local successChance = 1 / (2 ^ (actor.ProtectStreak or 0))
		if self.Rng:NextNumber() < successChance then
			actor.Protected = true
			actor.ProtectStreak = (actor.ProtectStreak or 0) + 1
			push({ Kind = "Message", Side = actorSide, FieldSlot = actorSlot, Text = actor.Name .. " entrou em posi\u{e7}\u{e3}o de defesa!" })
		else
			actor.ProtectStreak = 0
			push({ Kind = "Message", Side = actorSide, FieldSlot = actorSlot, Text = "Mas falhou!" })
		end
		return
	elseif kind == "WideProtect" then
		if not actor or actor.Hp <= 0 then
			return
		end
		local successChance = 1 / (2 ^ (actor.ProtectStreak or 0))
		if self.Rng:NextNumber() < successChance then
			self.Sides[actorSide].WideProtected = true
			actor.ProtectStreak = (actor.ProtectStreak or 0) + 1
			push({ Kind = "Message", Side = actorSide, FieldSlot = actorSlot, Text = "Guarda Ampla protegeu o time de " .. actor.Name .. "!" })
		else
			actor.ProtectStreak = 0
			push({ Kind = "Message", Side = actorSide, FieldSlot = actorSlot, Text = "Mas falhou!" })
		end
		return
	elseif kind == "Hazard" then
		local foeSide = otherSide(actorSide)
		local h = self.Sides[foeSide].Hazards
		local hType = effect.Hazard
		local changed = false
		local ownTxt, foeTxt = "", ""
		if hType == "Spikes" then
			if h.Spikes < 3 then
				h.Spikes += 1
				changed = true
				ownTxt = "Estrepes foram espalhados no campo advers\u{e1}rio! (x" .. h.Spikes .. ")"
				foeTxt = "Estrepes foram espalhados no seu campo! (x" .. h.Spikes .. ")"
			end
		elseif hType == "ToxicSpikes" then
			if h.ToxicSpikes < 2 then
				h.ToxicSpikes += 1
				changed = true
				ownTxt = "Estrepes t\u{f3}xicos foram espalhados no campo advers\u{e1}rio! (x" .. h.ToxicSpikes .. ")"
				foeTxt = "Estrepes t\u{f3}xicos foram espalhados no seu campo! (x" .. h.ToxicSpikes .. ")"
			end
		elseif hType == "StickyWeb" then
			if not h.StickyWeb then
				h.StickyWeb = true
				changed = true
				ownTxt = "Uma rede aderente cobriu o campo advers\u{e1}rio!"
				foeTxt = "Uma rede aderente cobriu o seu campo!"
			end
		end
		if changed then
			local text = if actorSide == "Player" then ownTxt else foeTxt
			local textEnemy = if actorSide == "Enemy" then ownTxt else foeTxt
			self:_PushFieldUpdate(foeSide, push, text, textEnemy)
		elseif isPrimary then
			push({ Kind = "Message", Text = "Mas o campo j\u{e1} est\u{e1} no limite." })
		end
		return
	elseif kind == "ClearHazards" then
		local sidesToClear = if effect.Scope == "All" then SIDES else { actorSide }
		local clearedAny = false
		for _, sName in ipairs(sidesToClear) do
			local h = self.Sides[sName].Hazards
			if h.Spikes > 0 or h.ToxicSpikes > 0 or h.StickyWeb then
				self.Sides[sName].Hazards = freshHazards()
				clearedAny = true
				self:_PushFieldUpdate(sName, push, "O campo foi limpo de armadilhas!", "O campo foi limpo de armadilhas!")
			end
		end
		if effect.BonusStat and actor and actor.Hp > 0 then
			self:_ApplyStatStage(actorSide, actorSlot, actor, effect.BonusStat, effect.BonusStages or 1, false, push)
		elseif not clearedAny and isPrimary then
			push({ Kind = "Message", Text = "Mas n\u{e3}o havia armadilhas em campo." })
		end
		return
	elseif kind == "SideEffect" then
		local se = self.Sides[actorSide].SideEffects
		local seType = effect.SideEffect
		local turns = effect.Turns or (if seType == "Tailwind" then 4 else 5)
		if seType == "Barrier" then
			if se.Barrier > 0 then
				if isPrimary then
					push({ Kind = "Message", Text = "Mas a barreira j\u{e1} est\u{e1} ativa." })
				end
				return
			end
			se.Barrier = turns
			local ownTxt = "Uma barreira reduziu o dano recebido pelo seu time!"
			local foeTxt = "Uma barreira protegeu o time advers\u{e1}rio!"
			self:_PushFieldUpdate(actorSide, push, if actorSide == "Player" then ownTxt else foeTxt, if actorSide == "Enemy" then ownTxt else foeTxt)
		elseif seType == "Tailwind" then
			if se.Tailwind > 0 then
				if isPrimary then
					push({ Kind = "Message", Text = "Mas o vento a favor j\u{e1} est\u{e1} ativo." })
				end
				return
			end
			se.Tailwind = turns
			local ownTxt = "Vento a favor dobrou a velocidade do seu time!"
			local foeTxt = "Vento a favor dobrou a velocidade do advers\u{e1}rio!"
			self:_PushFieldUpdate(actorSide, push, if actorSide == "Player" then ownTxt else foeTxt, if actorSide == "Enemy" then ownTxt else foeTxt)
		end
		return
	end

	local targetSide = if effect.Target == "Self" then actorSide else hitSide
	local targetSlot = if effect.Target == "Self" then actorSlot else hitSlot
	local target = self:ActiveAt(targetSide, targetSlot)
	if not target or target.Hp <= 0 then
		return
	end

	if kind == "Status" then
		self:_SetStatus(targetSide, targetSlot, effect.Status, push, isPrimary and not multiTarget)
	elseif kind == "StatStage" then
		self:_ApplyStatStage(targetSide, targetSlot, target, effect.Stat, effect.Stages, true, push, actorSide)
	elseif kind == "MultiStat" then
		local anyChanged = false
		for _, ch in ipairs(effect.Changes or {}) do
			if self:_ApplyStatStage(targetSide, targetSlot, target, ch.Stat, ch.Stages, false, push, actorSide) then
				anyChanged = true
			end
		end
		if not anyChanged and isPrimary and not multiTarget then
			push({ Kind = "Message", Text = "Os atributos de " .. target.Name .. " n\u{e3}o podem mudar mais." })
		end
	elseif kind == "Heal" then
		if target.Hp >= target.MaxHp then
			if isPrimary and not multiTarget then
				push({ Kind = "Message", Text = target.Name .. " j\u{e1} est\u{e1} com o HP cheio." })
			end
			return
		end
		local fraction = effect.Fraction or 0.5
		local healed = math.min(target.MaxHp - target.Hp, math.max(1, math.floor(target.MaxHp * fraction)))
		target.Hp += healed
		push({
			Kind = "Heal",
			Side = targetSide,
			FieldSlot = targetSlot,
			Active = true,
			Amount = healed,
			Hp = target.Hp,
			MaxHp = target.MaxHp,
			Text = target.Name .. " recuperou " .. healed .. " de HP!",
		})
	elseif kind == "Cleanse" then
		if not target.Status then
			if isPrimary and not multiTarget then
				push({ Kind = "Message", Text = "Mas n\u{e3}o teve efeito." })
			end
			return
		end
		local old = target.Status
		target.Status = nil
		target.StatusTurns = 0
		push({
			Kind = "StatusCured",
			Side = targetSide,
			FieldSlot = targetSlot,
			Status = old,
			Text = target.Name .. " se purificou do status!",
		})
	end
end

-- Aplica hazards de entrada no lutador recem-entrado no campo
function BattleEngine:_ApplyEntryHazards(side: string, fieldSlot: number, incoming, push)
	if not incoming or incoming.Hp <= 0 then
		return
	end
	local h = self.Sides[side].Hazards
	if not h then
		return
	end
	local _, inEff = passiveOf(incoming)
	local hazardMult = if inEff and inEff.HazardAndDotMult then inEff.HazardAndDotMult else 1
	if h.Spikes > 0 then
		local frac = SPIKES_FRACTION[math.clamp(h.Spikes, 1, 3)]
		local dmg = math.max(1, math.floor(incoming.MaxHp * frac * hazardMult))
		incoming.Hp = math.max(0, incoming.Hp - dmg)
		push({
			Kind = "Damage",
			Side = side,
			FieldSlot = fieldSlot,
			Amount = dmg,
			Hp = incoming.Hp,
			MaxHp = incoming.MaxHp,
			Hazard = "Spikes",
			Text = incoming.Name .. " pisou nos estrepes e perdeu " .. dmg .. " de HP!",
		})
		if incoming.Hp <= 0 then
			self:_Faint(side, fieldSlot, push)
			return
		else
			self:_CheckThresholdPassive(side, fieldSlot, incoming, push)
		end
	end
	if h.ToxicSpikes > 0 and incoming.Hp > 0 then
		self:_SetStatus(side, fieldSlot, "Poison", push, false)
		if h.ToxicSpikes >= 2 then
			local chip = math.max(1, math.floor((incoming.MaxHp / 16) * hazardMult))
			incoming.Hp = math.max(0, incoming.Hp - chip)
			push({
				Kind = "StatusDamage",
				Side = side,
				FieldSlot = fieldSlot,
				Status = "Poison",
				Amount = chip,
				Hp = incoming.Hp,
				MaxHp = incoming.MaxHp,
				Text = incoming.Name .. " sofreu " .. chip .. " de dano dos estrepes t\u{f3}xicos!",
			})
			if incoming.Hp <= 0 then
				self:_Faint(side, fieldSlot, push)
				return
			else
				self:_CheckThresholdPassive(side, fieldSlot, incoming, push)
			end
		end
	end
	if h.StickyWeb and incoming.Hp > 0 then
		self:_ApplyStatStage(side, fieldSlot, incoming, "Speed", -1, false, push, otherSide(side))
	end
end

-- Troca o personagem em campo de um slot. Os estagios de quem sai voltam a zero (GDD secao 5).
-- isReplacement = entrada depois de um desmaio (nao gasta turno).
function BattleEngine:_DoSwitch(side: string, fieldSlot: number, index: number, push, isReplacement: boolean)
	local sideState = self.Sides[side]
	local fromIndex = sideState.ActiveSlots[fieldSlot]
	local outgoing = fromIndex and sideState.Team[fromIndex]
	local incoming = sideState.Team[index]
	if outgoing then
		outgoing.Stages = freshStages()
		outgoing.Protected = false
		outgoing.ProtectStreak = 0
	end
	incoming.Protected = false
	incoming.ProtectStreak = 0
	incoming.SturdyUsed = false
	sideState.ActiveSlots[fieldSlot] = index
	self:SyncLegacyActive(side)
	incoming.Participated = true

	local outName = if outgoing then outgoing.Name else ""
	local ownText = if isReplacement or not outgoing then "Vai, " .. incoming.Name .. "!" else "Volte, " .. outName .. "! Vai, " .. incoming.Name .. "!"
	local foeText = if isReplacement or not outgoing then "O advers\u{e1}rio mandou " .. incoming.Name .. "." else "O advers\u{e1}rio trocou " .. outName .. " por " .. incoming.Name .. "."
	push({
		Kind = "Switch",
		Side = side,
		FieldSlot = fieldSlot,
		FromIndex = fromIndex,
		ToIndex = index,
		Replacement = isReplacement == true,
		Member = self:_MemberInfo(incoming, side == "Player"),
		MemberEnemyView = if self.EnemyHuman then self:_MemberInfo(incoming, side == "Enemy") else nil,
		Text = if side == "Player" then ownText else foeText,
		TextEnemy = if self.EnemyHuman then (if side == "Enemy" then ownText else foeText) else nil,
	})

	self:_ApplyEntryHazards(side, fieldSlot, incoming, push)
	if incoming.Hp > 0 and not self.Winner then
		self:_TriggerOnEnter(side, fieldSlot, incoming, push)
	end
end

-- Item da mochila: gasta o turno do slot. Pode mirar qualquer membro do time.
function BattleEngine:_DoItem(side: string, fieldSlot: number, itemId: string, targetIndex: number?, push)
	local sideState = self.Sides[side]
	targetIndex = targetIndex or sideState.ActiveSlots[fieldSlot] or sideState.Active
	local target = sideState.Team[targetIndex]
	local targetFieldSlot = self:FieldSlotOf(side, targetIndex)
	local item = Items.Get(itemId)
	self.Bag[itemId] -= 1
	if item.Kind == "Capture" then
		local aliveFoes = self:AliveFieldSlots("Enemy")
		local foeSlot = aliveFoes[1] or 1
		local foe = self:ActiveAt("Enemy", foeSlot)
		local chance = Characters.CaptureChance(foe.Id, foe.Hp, foe.MaxHp, item.SealMultiplier, foe.Status ~= nil)
		push({ Kind = "Message", Text = "Voc\u{ea} usou " .. item.Name .. "!" })
		if self.Rng:NextNumber() < chance then
			self.Winner = "Player"
			self.EndReason = "Captured"
			self.Captured = { CharacterId = foe.Id, Level = foe.Level, Genetics = foe.Genetics }
			push({ Kind = "Capture", Side = "Enemy", FieldSlot = foeSlot, Success = true, Chance = chance, Text = foe.Name .. " foi capturado!" })
		else
			push({ Kind = "Capture", Side = "Enemy", FieldSlot = foeSlot, Success = false, Chance = chance, Text = "O selo se rompeu! " .. foe.Name .. " escapou." })
		end
		return
	end
	if item.Kind == "CureStatus" then
		local old = target.Status
		target.Status = nil
		target.StatusTurns = 0
		push({ Kind = "ItemUsed", Side = side, Slot = targetIndex, FieldSlot = targetFieldSlot, ItemId = itemId, Text = "Voc\u{ea} usou " .. item.Name .. ". " .. target.Name .. " est\u{e1} sem status." })
		if targetFieldSlot and old then
			push({ Kind = "StatusCured", Side = side, FieldSlot = targetFieldSlot, Status = old })
		end
		return
	elseif item.Kind == "RestorePP" then
		local best, missing = nil, 0
		for _, slot in ipairs(target.Moves) do
			if slot.MaxPp - slot.Pp > missing then
				best, missing = slot, slot.MaxPp - slot.Pp
			end
		end
		local gained = 0
		if best then
			gained = math.min(item.Amount, missing)
			best.Pp += gained
		end
		push({ Kind = "ItemUsed", Side = side, Slot = targetIndex, FieldSlot = targetFieldSlot, ItemId = itemId, Text = "Voc\u{ea} usou " .. item.Name .. ". " .. (if best then Moves.Get(best.Id).Name .. " recuperou " .. gained .. " de PP." else "Nada aconteceu.") })
		return
	elseif item.Kind == "Revive" then
		target.Hp = math.max(1, math.floor(target.MaxHp * item.Percent))
		target.Status = nil
		target.StatusTurns = 0
		target.Stages = freshStages()
		push({ Kind = "Heal", Side = side, Slot = targetIndex, FieldSlot = targetFieldSlot, Active = targetFieldSlot ~= nil, Amount = target.Hp, Hp = target.Hp, MaxHp = target.MaxHp, ItemId = itemId, Text = "Voc\u{ea} usou " .. item.Name .. ". " .. target.Name .. " voltou com " .. target.Hp .. " de HP!" })
		return
	end
	if item.Kind == "HealHP" then
		local healed = math.min(item.Amount, target.MaxHp - target.Hp)
		target.Hp += healed
		push({
			Kind = "Heal",
			Side = side,
			Slot = targetIndex,
			FieldSlot = targetFieldSlot,
			Active = targetFieldSlot ~= nil,
			Amount = healed,
			Hp = target.Hp,
			MaxHp = target.MaxHp,
			ItemId = itemId,
			Text = "Voc\u{ea} usou " .. item.Name .. ". " .. target.Name .. " recuperou " .. healed .. " de HP.",
		})
	end
end

-- Fugir: so contra selvagens. Na torre e no PvP vira Desistir e conta como derrota.
function BattleEngine:_DoFlee(side: string, push)
	if self.CanFlee then
		push({ Kind = "Message", Text = "Voc\u{ea} fugiu da batalha." })
		self.Winner = "None"
		self.EndReason = "Fled"
	else
		local own, foe = "Voc\u{ea} desistiu da batalha.", "O advers\u{e1}rio desistiu da batalha."
		push({ Kind = "Message", Text = if side == "Player" then own else foe, TextEnemy = if self.EnemyHuman then (if side == "Enemy" then own else foe) else nil })
		self.Winner = otherSide(side)
		self.EndReason = "Forfeit"
	end
end

function BattleEngine:_Faint(side: string, fieldSlot: number, push)
	local battler = self:ActiveAt(side, fieldSlot)
	if not battler then
		return
	end
	battler.Status = nil
	battler.StatusTurns = 0
	push({ Kind = "Faint", Side = side, FieldSlot = fieldSlot, Text = battler.Name .. " desmaiou!" })
	if aliveCount(self.Sides[side]) == 0 then
		self.Winner = otherSide(side)
		self.EndReason = "Faint"
	end
end

-- Fim do turno (GDD secao 5): queimadura, veneno, sono, passivas de regeneracao e efeitos de campo (Barrier/Tailwind)
function BattleEngine:_EndOfTurn(push)
	for _, side in ipairs(SIDES) do
		for fs = 1, self.SlotsPerSide do
			local b = self:ActiveAt(side, fs)
			if b and b.Hp > 0 then
				local bPassive, bEff = passiveOf(b)
				local rule = b.Status and DamageCalc.STATUS[b.Status]
				if rule and rule.TickFraction then
					local dotMult = if bEff and bEff.HazardAndDotMult then bEff.HazardAndDotMult else 1
					local dmg = math.max(1, math.floor(b.MaxHp * rule.TickFraction * dotMult))
					b.Hp = math.max(0, b.Hp - dmg)
					local cause = if b.Status == "Burn" then "da queimadura" else "do veneno"
					push({
						Kind = "StatusDamage",
						Side = side,
						FieldSlot = fs,
						Status = b.Status,
						Amount = dmg,
						Hp = b.Hp,
						MaxHp = b.MaxHp,
						Text = b.Name .. " sofreu " .. dmg .. " de dano " .. cause .. ".",
					})
					if b.Hp <= 0 then
						self:_Faint(side, fs, push)
						if self.Winner then
							return
						end
					else
						self:_CheckThresholdPassive(side, fs, b, push)
					end
				elseif b.Status == "Sleep" then
					b.StatusTurns -= 1
					if b.StatusTurns <= 0 then
						b.Status = nil
						b.StatusTurns = 0
						push({ Kind = "StatusCured", Side = side, FieldSlot = fs, Status = "Sleep", Text = b.Name .. " acordou!" })
					end
				end

				-- Cura por turno de passiva (Regeneracao 6%, Manto da Raposa 8%)
				if b.Hp > 0 and b.Hp < b.MaxHp and bEff and bEff.EndTurnHealFraction then
					local healed = math.min(b.MaxHp - b.Hp, math.max(1, math.floor(b.MaxHp * bEff.EndTurnHealFraction)))
					if healed > 0 then
						b.Hp += healed
						self:_PushPassive(side, fs, b, push, (bPassive and bPassive.Name or "Regenera\u{e7}\u{e3}o") .. " restaurou " .. healed .. " HP de " .. b.Name .. "!")
						push({
							Kind = "Heal",
							Side = side,
							FieldSlot = fs,
							Active = true,
							Amount = healed,
							Hp = b.Hp,
							MaxHp = b.MaxHp,
						})
					end
				end
			end
		end
	end

	-- Decrementa efeitos de campo por lado (Barrier e Tailwind)
	for _, side in ipairs(SIDES) do
		local se = self.Sides[side].SideEffects
		if se.Barrier > 0 then
			se.Barrier -= 1
			if se.Barrier == 0 then
				local ownTxt = "A barreira do seu time se dissipou."
				local foeTxt = "A barreira do advers\u{e1}rio se dissipou."
				self:_PushFieldUpdate(side, push, if side == "Player" then ownTxt else foeTxt, if side == "Enemy" then ownTxt else foeTxt)
			end
		end
		if se.Tailwind > 0 then
			se.Tailwind -= 1
			if se.Tailwind == 0 then
				local ownTxt = "O vento a favor do seu time cessou."
				local foeTxt = "O vento a favor do advers\u{e1}rio cessou."
				self:_PushFieldUpdate(side, push, if side == "Player" then ownTxt else foeTxt, if side == "Enemy" then ownTxt else foeTxt)
			end
		end
	end
end

-- Informacao de um membro para o cliente (golpes so do proprio time)
function BattleEngine:_MemberInfo(b, withMoves: boolean)
	local p = passiveOf(b)
	local info = {
		Id = b.Id,
		Name = b.Name,
		Type = b.Type,
		TypeName = TypeChart.DisplayName[b.Type],
		Level = b.Level,
		Hp = b.Hp,
		MaxHp = b.MaxHp,
		Status = b.Status,
		Stages = table.clone(b.Stages),
		Fainted = b.Hp <= 0,
		Awakened = b.Awakened == true,
		PassiveId = b.PassiveId,
		PassiveName = p and p.Name or nil,
		PassiveTier = p and p.Tier or nil,
	}
	if withMoves then
		local moves = {}
		for i, slot in ipairs(b.Moves) do
			local m = Moves.Get(slot.Id)
			moves[i] = {
				Id = slot.Id,
				Name = m.Name,
				Type = m.Type,
				TypeName = TypeChart.DisplayName[m.Type],
				Category = m.Category,
				Target = Moves.TargetMode(m),
				Power = m.Power,
				Accuracy = m.Accuracy,
				Priority = m.Priority or 0,
				EffectKind = m.Effect and m.Effect.Kind or nil,
				Pp = slot.Pp,
				MaxPp = slot.MaxPp,
			}
		end
		info.Moves = moves
	end
	return info
end

-- Foto do estado para o cliente (so leitura). view = lado de quem le ("Enemy" no PvP: tudo espelhado)
-- Arrays sempre densos (0 = slot vazio) para evitar buracos na serializacao de RemoteEvents do Roblox.
function BattleEngine:Snapshot(view: string?)
	view = view or "Player"
	local function sideInfo(side: string)
		local s = self.Sides[side]
		local team = {}
		for i, m in ipairs(s.Team) do
			team[i] = self:_MemberInfo(m, side == view)
		end
		local activeSlots = {}
		for fs = 1, self.SlotsPerSide do
			activeSlots[fs] = s.ActiveSlots[fs] or 0
		end
		return {
			Active = s.Active,
			ActiveSlots = activeSlots,
			Team = team,
			Hazards = table.clone(s.Hazards),
			SideEffects = table.clone(s.SideEffects),
		}
	end
	local function struggleSlots(side: string)
		local out = {}
		for fs = 1, self.SlotsPerSide do
			local b = self:ActiveAt(side, fs)
			out[fs] = b ~= nil and b.Hp > 0 and not hasUsableMove(b)
		end
		return out
	end
	local function pendingSlots(side: string)
		local p = self.PendingReplace[side]
		return if p then table.clone(p) else {}
	end

	if view == "Enemy" then
		return {
			Format = self.Format,
			SlotsPerSide = self.SlotsPerSide,
			Turn = self.Turn,
			State = if self.PendingReplace.Enemy then "WaitingForReplacement" elseif self.State == "WaitingForReplacement" then "WaitingForOpponent" else self.State,
			Mode = self.Mode,
			CanFlee = self.CanFlee,
			MustStruggle = not hasUsableMove(self:Active("Enemy")),
			MustStruggleSlots = struggleSlots("Enemy"),
			PendingReplaceSlots = pendingSlots("Enemy"),
			Player = sideInfo("Enemy"),
			Enemy = sideInfo("Player"),
			Bag = {},
		}
	end
	local bag = {}
	for itemId, count in pairs(self.Bag) do
		local item = Items.Get(itemId)
		if item and item.UsableInBattle then
			table.insert(bag, { Id = itemId, Name = item.Name, Kind = item.Kind, Count = count })
		end
	end
	table.sort(bag, function(a, b)
		return a.Name < b.Name
	end)
	return {
		Format = self.Format,
		SlotsPerSide = self.SlotsPerSide,
		Turn = self.Turn,
		State = if self.State == "WaitingForReplacement" and not self.PendingReplace.Player then "WaitingForOpponent" else self.State,
		Mode = self.Mode,
		CanFlee = self.CanFlee,
		MustStruggle = not hasUsableMove(self:Active("Player")),
		MustStruggleSlots = struggleSlots("Player"),
		PendingReplaceSlots = pendingSlots("Player"),
		Player = sideInfo("Player"),
		Enemy = sideInfo("Enemy"),
		Bag = if self.Mode == "PvP" then {} else bag,
	}
end

return BattleEngine
