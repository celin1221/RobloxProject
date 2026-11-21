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

local DamageCalc = require(script.Parent.DamageCalc)
local AIController = require(script.Parent.AIController)

local BattleEngine = {}
BattleEngine.__index = BattleEngine

local SIDES = { "Player", "Enemy" }
BattleEngine.SIDES = SIDES

local MAX_TEAM = 6

local STAT_NAMES = { Attack = "Ataque", Defense = "Defesa", Speed = "Velocidade", Accuracy = "Precis\u{e3}o" }

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
	return { Team = team, Active = activeSlots[1], ActiveSlots = activeSlots }
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

-- Empilha acoes de um lado na fila do turno
function BattleEngine:_EnqueueSide(queue, side: string, sideAction)
	if sideAction.Kind == "Flee" then
		table.insert(queue, {
			Side = side,
			FieldSlot = 0,
			Action = sideAction,
			Priority = 2,
			Speed = 0,
			Tiebreak = self.Rng:NextNumber(),
		})
		return
	end
	if not self:IsDouble() then
		local actor = self:ActiveAt(side, 1)
		if actor and actor.Hp > 0 then
			local kind = sideAction.Kind
			table.insert(queue, {
				Side = side,
				FieldSlot = 1,
				Actor = actor,
				Action = sideAction,
				Priority = if kind == "Switch" or kind == "Item" then 1 else 0,
				Speed = DamageCalc.EffectiveStat(actor, "Speed"),
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
			local kind = sub.Kind
			table.insert(queue, {
				Side = side,
				FieldSlot = fs,
				Actor = actor,
				Action = sub,
				Priority = if kind == "Switch" or kind == "Item" then 1 else 0,
				Speed = DamageCalc.EffectiveStat(actor, "Speed"),
				Tiebreak = self.Rng:NextNumber(),
			})
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

	local events = {}
	local function push(ev)
		table.insert(events, ev)
	end
	for _, ev in ipairs(prefix or {}) do
		push(ev)
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
			end
		end
	end

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
				-- Maquina escolhe imediatamente quantos substitutos tiver no banco
				local foe = self:Active("Player")
				local exclude = {}
				for _, fs in ipairs(faintedSlots) do
					local nextIdx = AIController.ChooseReplacement(self.EnemyAI, s.Team, s.ActiveSlots, foe, self.Rng, exclude)
					if nextIdx then
						exclude[nextIdx] = true
						self:_DoSwitch("Enemy", fs, nextIdx, push, true)
					else
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
		self:_DoSwitch(side, entry.FieldSlot, entry.Index, push, true)
	end
	self.PendingReplace[side] = nil
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

function BattleEngine:_DoMove(side: string, fieldSlot: number, action, push)
	local actor = self:ActiveAt(side, fieldSlot)
	local move, slot = self:GetMove(actor, action.Index)

	if not self:_CanAct(side, fieldSlot, actor, push) then
		return -- o PP nao e gasto
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

	for _, t in ipairs(targets) do
		if self.Winner then
			break
		end
		if t.Battler.Hp <= 0 then
			continue
		end

		-- Precisao por alvo (golpes de status no proprio usuario nunca erram)
		if move.Accuracy and targetMode ~= "Self" then
			local chance = move.Accuracy * DamageCalc.StageMultiplier(actor.Stages.Accuracy)
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
			local result = DamageCalc.Compute(actor, t.Battler, move, self.Rng, spreadMult)
			t.Battler.Hp = math.max(0, t.Battler.Hp - result.Damage)
			push({
				Kind = "Damage",
				Side = t.Side,
				FieldSlot = t.FieldSlot,
				Amount = result.Damage,
				Hp = t.Battler.Hp,
				MaxHp = t.Battler.MaxHp,
				Crit = result.Crit,
				TypeMultiplier = result.TypeMultiplier,
				MoveType = move.Type,
				Spread = spreadMult,
				Text = t.Battler.Name .. " perdeu " .. result.Damage .. " de HP.",
			})
			if result.Crit then
				push({ Kind = "Message", Text = if multiTarget then "Golpe cr\u{ed}tico em " .. t.Battler.Name .. "!" else "Golpe cr\u{ed}tico!" })
			end
			if result.TypeMultiplier > 1 then
				push({ Kind = "Message", Text = if multiTarget then "\u{c9} super efetivo em " .. t.Battler.Name .. "!" else "\u{c9} super efetivo!" })
			elseif result.TypeMultiplier < 1 then
				push({ Kind = "Message", Text = if multiTarget then "N\u{e3}o \u{e9} muito efetivo em " .. t.Battler.Name .. "..." else "N\u{e3}o \u{e9} muito efetivo..." })
			end
			if t.Battler.Hp <= 0 then
				self:_Faint(t.Side, t.FieldSlot, push)
			elseif move.Effect then
				self:_ApplyEffect(side, fieldSlot, t.Side, t.FieldSlot, move.Effect, false, push)
			end
		else
			self:_ApplyEffect(side, fieldSlot, t.Side, t.FieldSlot, move.Effect, true, push)
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

-- Aplica o Effect de um golpe. isPrimary = golpe de status (avisa quando falha).
function BattleEngine:_ApplyEffect(actorSide: string, actorSlot: number, hitSide: string, hitSlot: number, effect, isPrimary: boolean, push)
	if not effect then
		return
	end
	if self.Rng:NextNumber() * 100 >= (effect.Chance or 100) then
		return
	end
	local targetSide = if effect.Target == "Self" then actorSide else hitSide
	local targetSlot = if effect.Target == "Self" then actorSlot else hitSlot
	local target = self:ActiveAt(targetSide, targetSlot)
	if not target or target.Hp <= 0 then
		return
	end

	if effect.Kind == "Status" then
		self:_SetStatus(targetSide, targetSlot, effect.Status, push, isPrimary)
	elseif effect.Kind == "StatStage" then
		local before = target.Stages[effect.Stat] or 0
		local after = math.clamp(before + effect.Stages, DamageCalc.MIN_STAGE, DamageCalc.MAX_STAGE)
		local statName = STAT_NAMES[effect.Stat] or effect.Stat
		if after == before then
			push({ Kind = "Message", Text = statName .. " de " .. target.Name .. " n\u{e3}o pode mudar mais." })
			return
		end
		target.Stages[effect.Stat] = after
		push({
			Kind = "StatStage",
			Side = targetSide,
			FieldSlot = targetSlot,
			Stat = effect.Stat,
			Stage = after,
			Text = statName .. " de " .. target.Name .. (if effect.Stages > 0 then " aumentou!" else " diminuiu!"),
		})
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
	end
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

-- Fim do turno (GDD secao 5): queimadura, veneno e contagem de sono, de todos os ativos em campo
function BattleEngine:_EndOfTurn(push)
	for _, side in ipairs(SIDES) do
		for fs = 1, self.SlotsPerSide do
			local b = self:ActiveAt(side, fs)
			if b and b.Hp > 0 then
				local rule = b.Status and DamageCalc.STATUS[b.Status]
				if rule and rule.TickFraction then
					local dmg = math.max(1, math.floor(b.MaxHp * rule.TickFraction))
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
					end
				elseif b.Status == "Sleep" then
					b.StatusTurns -= 1
					if b.StatusTurns <= 0 then
						b.Status = nil
						b.StatusTurns = 0
						push({ Kind = "StatusCured", Side = side, FieldSlot = fs, Status = "Sleep", Text = b.Name .. " acordou!" })
					end
				end
			end
		end
	end
end

-- Informacao de um membro para o cliente (golpes so do proprio time)
function BattleEngine:_MemberInfo(b, withMoves: boolean)
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
		return { Active = s.Active, ActiveSlots = activeSlots, Team = team }
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
