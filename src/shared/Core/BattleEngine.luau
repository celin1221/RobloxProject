--[[
	BattleEngine (GDD secoes 5 e 10)
	Logica pura da maquina de estados de batalha por turnos (testavel sem jogador e sem arena).

	Time de ate 6 por lado, 1 em campo.
	Estados:
	  "WaitingForInput"        cada lado escolhe Lutar / Mochila / Time / Fugir
	  "Resolving"              resolvendo o turno
	  "WaitingForReplacement"  o personagem do jogador desmaiou; ele escolhe o proximo
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
-- moveIds = golpes ativos (salvos); sem eles, os 4 ultimos aprendidos ate o nivel
-- extra (opcional): StatMultiplier (chefes/andares/estrelas+variante), StatMultipliers (Genetica+Treino por atributo),
-- Genetics, Training, Hp, Status e Pp ({ [golpe] = pp })
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
		StatusTurns = if extra.Status == "Sleep" then (extra.StatusTurns or 1) else 0, -- turnos restantes de sono
		Stages = freshStages(),
		Moves = moves,
		Uid = uid, -- id na colecao do jogador (XP no fim da batalha)
		Genetics = if typeof(extra.Genetics) == "table" then Genetics.SanitizeTable(extra.Genetics) else nil,
		Training = if typeof(extra.Training) == "table" then Genetics.SanitizeTable(extra.Training) else nil,
		Participated = false, -- entrou em campo nesta batalha
	}
end

local function newSide(teamDef)
	assert(typeof(teamDef) == "table" and #teamDef >= 1, "Time vazio")
	assert(#teamDef <= MAX_TEAM, "Time com mais de " .. MAX_TEAM .. " personagens")
	local team = {}
	for i, entry in ipairs(teamDef) do
		team[i] = newBattler(entry.CharacterId, entry.Level or 10, entry.Moves, entry.Uid, entry)
	end
	-- entra em campo o primeiro de pe (times herdados podem ter desmaiados)
	local active = 1
	for i, b in ipairs(team) do
		if b.Hp > 0 then
			active = i
			break
		end
	end
	assert(team[active].Hp > 0, "Time sem ninguem de pe")
	team[active].Participated = true
	return { Team = team, Active = active }
end

-- Aceita o formato antigo (CharacterId/Level) ou o novo (Team = {...})
local function teamFrom(def)
	if def.Team then
		return def.Team
	end
	return { { CharacterId = def.CharacterId, Level = def.Level } }
end

local function hasUsableMove(battler): boolean
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
		Mode = "Tower" | "Wild" | "PvP", Bag = { Pocao = 1 }, Seed = numero opcional
	}
]]
function BattleEngine.New(opts)
	local self = setmetatable({}, BattleEngine)
	self.Rng = if opts.Seed then Random.new(opts.Seed) else Random.new()
	self.Sides = {
		Player = newSide(teamFrom(opts.Player)),
		Enemy = newSide(teamFrom(opts.Enemy)),
	}
	self.EnemyAI = opts.Enemy.AI or "Medio"
	self.Mode = opts.Mode or "Tower"
	self.CaptureBlocked = opts.CaptureBlocked -- texto: selos recusados (ex.: deposito de personagens cheio)
	-- GDD secao 5: fugir so contra selvagens; torre e PvP tem Desistir (derrota)
	self.CanFlee = if opts.CanFlee ~= nil then opts.CanFlee == true else self.Mode == "Wild"
	self.Bag = table.clone(opts.Bag or {})
	self.Turn = 1
	self.State = "WaitingForInput"
	self.Winner = nil -- "Player" | "Enemy" | "None"
	self.EndReason = nil -- "Faint" | "Forfeit" | "Fled" | "Disconnect"
	-- PvP: o lado Enemy tambem e um jogador (escolhe acoes e substituicoes; sem IA)
	self.EnemyHuman = opts.EnemyHuman == true
	self.PendingReplace = {} -- [lado] = true enquanto o dono precisa escolher o proximo
	return self
end

function BattleEngine:Active(side: string)
	local s = self.Sides[side]
	return s.Team[s.Active]
end

-- Golpe de um slot do personagem em campo. Index 0 = golpe reserva.
function BattleEngine:GetMove(battler, index: number)
	if index == 0 then
		return Moves.Get(Moves.FALLBACK_ID), nil
	end
	local slot = battler.Moves[index]
	return slot and Moves.Get(slot.Id), slot
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

	-- Escolha obrigatoria do proximo depois de um desmaio
	if self.State == "WaitingForReplacement" then
		if not self.PendingReplace[side] or action.Kind ~= "Replace" then
			return false, if self.PendingReplace[side] then "Escolha o pr\u{f3}ximo personagem." else "Aguardando o advers\u{e1}rio."
		end
		local member = isInt(action.Index) and sideState.Team[action.Index]
		if not member or member.Hp <= 0 or action.Index == sideState.Active then
			return false, "Esse personagem n\u{e3}o pode entrar."
		end
		return true
	end

	if self.State ~= "WaitingForInput" then
		return false, "Ainda n\u{e3}o \u{e9} a sua vez."
	end
	local active = sideState.Team[sideState.Active]

	if action.Kind == "Move" then
		local index = action.Index
		if not isInt(index) then
			return false, "Golpe inv\u{e1}lido."
		end
		if index == 0 then
			if hasUsableMove(active) then
				return false, "Ainda h\u{e1} golpes com PP."
			end
			return true
		end
		local slot = active.Moves[index]
		if not slot then
			return false, "Golpe inv\u{e1}lido."
		end
		if slot.Pp <= 0 then
			return false, "Esse golpe est\u{e1} sem PP."
		end
		return true
	elseif action.Kind == "Switch" then
		local member = isInt(action.Index) and sideState.Team[action.Index]
		if not member then
			return false, "Personagem inv\u{e1}lido."
		end
		if action.Index == sideState.Active then
			return false, member.Name .. " j\u{e1} est\u{e1} em campo."
		end
		if member.Hp <= 0 then
			return false, member.Name .. " est\u{e1} desmaiado."
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
		if (self.Bag[itemId] or 0) <= 0 then
			return false, "Voc\u{ea} n\u{e3}o tem " .. item.Name .. "."
		end
		-- Selos: so contra selvagens (GDD secao 7)
		if item.Kind == "Capture" then
			if self.Mode ~= "Wild" then
				return false, "Selos s\u{f3} funcionam contra personagens selvagens."
			end
			if self.CaptureBlocked then
				return false, self.CaptureBlocked
			end
			if self:Active("Enemy").Hp <= 0 then
				return false, "Alvo inv\u{e1}lido."
			end
			return true
		end
		local targetIndex = action.TargetIndex
		if targetIndex == nil then
			targetIndex = sideState.Active
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
	enemyAction = enemyAction or AIController.ChooseAction(
		self.EnemyAI, self:Active("Enemy"), self:Active("Player"), self.Rng, enemy.Team, enemy.Active
	)

	-- Ordem (GDD): fuga, troca e item primeiro; depois golpes do mais veloz ao mais lento; empate sorteado
	local queue = {
		{ Side = "Player", Action = playerAction },
		{ Side = "Enemy", Action = enemyAction },
	}
	for _, q in ipairs(queue) do
		local kind = q.Action.Kind
		q.Priority = if kind == "Flee" then 2 elseif kind == "Switch" or kind == "Item" then 1 else 0
		q.Speed = DamageCalc.EffectiveStat(self:Active(q.Side), "Speed")
		q.Tiebreak = self.Rng:NextNumber()
	end
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
		-- quem desmaiou antes de agir perde a acao
		if self:Active(q.Side).Hp > 0 then
			local kind = q.Action.Kind
			if kind == "Move" then
				self:_DoMove(q.Side, q.Action.Index, push)
			elseif kind == "Switch" then
				self:_DoSwitch(q.Side, q.Action.Index, push, false)
			elseif kind == "Item" then
				self:_DoItem(q.Side, q.Action.ItemId, q.Action.TargetIndex, push)
			elseif kind == "Flee" then
				self:_DoFlee(q.Side, push)
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
	-- A maquina escolhe o proximo na hora; no PvP o outro jogador escolhe pela tela
	if self:Active("Enemy").Hp <= 0 then
		if self.EnemyHuman then
			self.PendingReplace.Enemy = true
		else
			local enemy = self.Sides.Enemy
			local index = AIController.ChooseReplacement(self.EnemyAI, enemy.Team, enemy.Active, self:Active("Player"), self.Rng)
			self:_DoSwitch("Enemy", index, push, true)
		end
	end
	-- O jogador escolhe o proximo pela tela
	if self:Active("Player").Hp <= 0 then
		self.PendingReplace.Player = true
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
	return AIController.ChooseAction("Facil", self:Active(side), self:Active(otherSide(side)), self.Rng)
end

-- Substituicao automatica: o proximo de pe na ordem do time
function BattleEngine:AutoReplacement(side: string): number?
	local s = self.Sides[side]
	return AIController.ChooseReplacement("Facil", s.Team, s.Active, self:Active(otherSide(side)), self.Rng)
end

-- Escolha do proximo depois de um desmaio (estado WaitingForReplacement)
function BattleEngine:ResolveReplacement(side: string, index: number)
	local ok, err = self:ValidateAction(side, { Kind = "Replace", Index = index })
	assert(ok, err)
	local events = {}
	self:_DoSwitch(side, index, function(ev)
		table.insert(events, ev)
	end, true)
	self.PendingReplace[side] = nil
	self.State = if next(self.PendingReplace) then "WaitingForReplacement" else "WaitingForInput"
	return events
end

-- Paralisia, sono e congelamento podem impedir o golpe. Retorna true se pode agir.
function BattleEngine:_CanAct(side: string, actor, push): boolean
	if actor.Status == "Sleep" then
		push({ Kind = "Message", Side = side, Text = actor.Name .. " est\u{e1} dormindo." })
		return false
	end
	if actor.Status == "Freeze" then
		if self.Rng:NextNumber() < DamageCalc.STATUS.Freeze.ThawChance then
			actor.Status = nil
			push({ Kind = "StatusCured", Side = side, Status = "Freeze", Text = actor.Name .. " descongelou!" })
		else
			push({ Kind = "Message", Side = side, Text = actor.Name .. " est\u{e1} congelado e n\u{e3}o consegue se mover." })
			return false
		end
	end
	if actor.Status == "Paralysis" and self.Rng:NextNumber() < DamageCalc.STATUS.Paralysis.SkipChance then
		push({ Kind = "Message", Side = side, Text = actor.Name .. " est\u{e1} paralisado! N\u{e3}o consegue se mover." })
		return false
	end
	return true
end

function BattleEngine:_DoMove(side: string, index: number, push)
	local actor = self:Active(side)
	local targetSide = otherSide(side)
	local target = self:Active(targetSide)
	local move, slot = self:GetMove(actor, index)

	if not self:_CanAct(side, actor, push) then
		return -- o PP nao e gasto
	end

	if slot then
		slot.Pp -= 1
	end
	push({
		Kind = "UseMove",
		Side = side,
		MoveId = move.Id,
		MoveName = move.Name,
		MoveType = move.Type,
		Text = actor.Name .. " usou " .. move.Name .. "!",
	})

	local selfOnly = move.Category == "Status" and move.Effect and move.Effect.Target == "Self"
	if not selfOnly and target.Hp <= 0 then
		push({ Kind = "Message", Text = "Mas n\u{e3}o havia alvo." })
		return
	end

	-- Precisao (golpes de status no proprio usuario nunca erram)
	if move.Accuracy and not selfOnly then
		local chance = move.Accuracy * DamageCalc.StageMultiplier(actor.Stages.Accuracy)
		if self.Rng:NextNumber() * 100 >= chance then
			push({ Kind = "Miss", Side = side, Text = "Mas errou!" })
			return
		end
	end

	if move.Category == "Damage" then
		local result = DamageCalc.Compute(actor, target, move, self.Rng)
		target.Hp = math.max(0, target.Hp - result.Damage)
		push({
			Kind = "Damage",
			Side = targetSide,
			Amount = result.Damage,
			Hp = target.Hp,
			MaxHp = target.MaxHp,
			Crit = result.Crit,
			TypeMultiplier = result.TypeMultiplier,
			MoveType = move.Type,
			Text = target.Name .. " perdeu " .. result.Damage .. " de HP.",
		})
		if result.Crit then
			push({ Kind = "Message", Text = "Golpe cr\u{ed}tico!" })
		end
		if result.TypeMultiplier > 1 then
			push({ Kind = "Message", Text = "\u{c9} super efetivo!" })
		elseif result.TypeMultiplier < 1 then
			push({ Kind = "Message", Text = "N\u{e3}o \u{e9} muito efetivo..." })
		end
		if target.Hp <= 0 then
			self:_Faint(targetSide, push)
			return
		end
		if move.Effect then
			self:_ApplyEffect(side, move.Effect, false, push)
		end
	else
		self:_ApplyEffect(side, move.Effect, true, push)
	end
end

-- Aplica um status no personagem em campo de um lado. Retorna true se aplicou.
function BattleEngine:_SetStatus(side: string, status: string, push, isPrimary: boolean?): boolean
	assert(DamageCalc.STATUS[status], "Status desconhecido: " .. tostring(status))
	local target = self:Active(side)
	if target.Hp <= 0 then
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
	push({ Kind = "Status", Side = side, Status = status, Text = target.Name .. STATUS_TEXT[status] })
	return true
end

-- Uso externo (testes, itens e golpes futuros): aplica um status e devolve os eventos
function BattleEngine:ApplyStatus(side: string, status: string)
	local events = {}
	self:_SetStatus(side, status, function(ev)
		table.insert(events, ev)
	end, true)
	return events
end

-- Aplica o Effect de um golpe. isPrimary = golpe de status (avisa quando falha).
function BattleEngine:_ApplyEffect(side: string, effect, isPrimary: boolean, push)
	if not effect then
		return
	end
	if self.Rng:NextNumber() * 100 >= (effect.Chance or 100) then
		return
	end
	local targetSide = if effect.Target == "Self" then side else otherSide(side)
	local target = self:Active(targetSide)

	if effect.Kind == "Status" then
		self:_SetStatus(targetSide, effect.Status, push, isPrimary)
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
			Stat = effect.Stat,
			Stage = after,
			Text = statName .. " de " .. target.Name .. (if effect.Stages > 0 then " aumentou!" else " diminuiu!"),
		})
	end
end

-- Troca o personagem em campo. Os estagios de quem sai voltam a zero (GDD secao 5).
-- isReplacement = entrada depois de um desmaio (nao gasta turno).
function BattleEngine:_DoSwitch(side: string, index: number, push, isReplacement: boolean)
	local sideState = self.Sides[side]
	local outgoing = sideState.Team[sideState.Active]
	local incoming = sideState.Team[index]
	outgoing.Stages = freshStages()
	local fromIndex = sideState.Active
	sideState.Active = index
	incoming.Participated = true

	-- texto do ponto de vista de quem le (o dono do lado ou o adversario)
	local ownText = if isReplacement then "Vai, " .. incoming.Name .. "!" else "Volte, " .. outgoing.Name .. "! Vai, " .. incoming.Name .. "!"
	local foeText = if isReplacement then "O advers\u{e1}rio mandou " .. incoming.Name .. "." else "O advers\u{e1}rio trocou " .. outgoing.Name .. " por " .. incoming.Name .. "."
	push({
		Kind = "Switch",
		Side = side,
		FromIndex = fromIndex,
		ToIndex = index,
		Replacement = isReplacement == true,
		Member = self:_MemberInfo(incoming, side == "Player"),
		MemberEnemyView = if self.EnemyHuman then self:_MemberInfo(incoming, side == "Enemy") else nil,
		Text = if side == "Player" then ownText else foeText,
		TextEnemy = if self.EnemyHuman then (if side == "Enemy" then ownText else foeText) else nil,
	})
end

-- Item da mochila: gasta o turno do jogador. Pode mirar qualquer membro de pe do time.
function BattleEngine:_DoItem(side: string, itemId: string, targetIndex: number?, push)
	local sideState = self.Sides[side]
	targetIndex = targetIndex or sideState.Active
	local target = sideState.Team[targetIndex]
	local item = Items.Get(itemId)
	self.Bag[itemId] -= 1
	if item.Kind == "Capture" then
		local foe = self:Active("Enemy")
		local chance = Characters.CaptureChance(foe.Id, foe.Hp, foe.MaxHp, item.SealMultiplier, foe.Status ~= nil)
		push({ Kind = "Message", Text = "Voc\u{ea} usou " .. item.Name .. "!" })
		if self.Rng:NextNumber() < chance then
			self.Winner = "Player"
			self.EndReason = "Captured"
			self.Captured = { CharacterId = foe.Id, Level = foe.Level, Genetics = foe.Genetics }
			push({ Kind = "Capture", Side = "Enemy", Success = true, Chance = chance, Text = foe.Name .. " foi capturado!" })
		else
			push({ Kind = "Capture", Side = "Enemy", Success = false, Chance = chance, Text = "O selo se rompeu! " .. foe.Name .. " escapou." })
		end
		return
	end
	if item.Kind == "CureStatus" then
		local old = target.Status
		target.Status = nil
		target.StatusTurns = 0
		push({ Kind = "ItemUsed", Side = side, Slot = targetIndex, ItemId = itemId, Text = "Voc\u{ea} usou " .. item.Name .. ". " .. target.Name .. " est\u{e1} sem status." })
		if targetIndex == sideState.Active and old then
			push({ Kind = "StatusCured", Side = side, Status = old })
		end
		return
	elseif item.Kind == "RestorePP" then
		-- o golpe com mais PP faltando
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
		push({ Kind = "ItemUsed", Side = side, Slot = targetIndex, ItemId = itemId, Text = "Voc\u{ea} usou " .. item.Name .. ". " .. (if best then Moves.Get(best.Id).Name .. " recuperou " .. gained .. " de PP." else "Nada aconteceu.") })
		return
	elseif item.Kind == "Revive" then
		target.Hp = math.max(1, math.floor(target.MaxHp * item.Percent))
		target.Status = nil
		target.StatusTurns = 0
		target.Stages = freshStages()
		push({ Kind = "Heal", Side = side, Slot = targetIndex, Active = targetIndex == sideState.Active, Amount = target.Hp, Hp = target.Hp, MaxHp = target.MaxHp, ItemId = itemId, Text = "Voc\u{ea} usou " .. item.Name .. ". " .. target.Name .. " voltou com " .. target.Hp .. " de HP!" })
		return
	end
	if item.Kind == "HealHP" then
		local healed = math.min(item.Amount, target.MaxHp - target.Hp)
		target.Hp += healed
		push({
			Kind = "Heal",
			Side = side,
			Slot = targetIndex,
			Active = targetIndex == sideState.Active,
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

function BattleEngine:_Faint(side: string, push)
	local battler = self:Active(side)
	battler.Status = nil
	battler.StatusTurns = 0
	push({ Kind = "Faint", Side = side, Text = battler.Name .. " desmaiou!" })
	if aliveCount(self.Sides[side]) == 0 then
		self.Winner = otherSide(side)
		self.EndReason = "Faint"
	end
end

-- Fim do turno (GDD secao 5): queimadura, veneno e contagem de sono, so de quem esta em campo
function BattleEngine:_EndOfTurn(push)
	for _, side in ipairs(SIDES) do
		local b = self:Active(side)
		if b.Hp > 0 then
			local rule = b.Status and DamageCalc.STATUS[b.Status]
			if rule and rule.TickFraction then
				local dmg = math.max(1, math.floor(b.MaxHp * rule.TickFraction))
				b.Hp = math.max(0, b.Hp - dmg)
				local cause = if b.Status == "Burn" then "da queimadura" else "do veneno"
				push({
					Kind = "StatusDamage",
					Side = side,
					Status = b.Status,
					Amount = dmg,
					Hp = b.Hp,
					MaxHp = b.MaxHp,
					Text = b.Name .. " sofreu " .. dmg .. " de dano " .. cause .. ".",
				})
				if b.Hp <= 0 then
					self:_Faint(side, push)
					if self.Winner then
						return
					end
				end
			elseif b.Status == "Sleep" then
				b.StatusTurns -= 1
				if b.StatusTurns <= 0 then
					b.Status = nil
					b.StatusTurns = 0
					push({ Kind = "StatusCured", Side = side, Status = "Sleep", Text = b.Name .. " acordou!" })
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
function BattleEngine:Snapshot(view: string?)
	view = view or "Player"
	local function sideInfo(side: string)
		local s = self.Sides[side]
		local team = {}
		for i, m in ipairs(s.Team) do
			team[i] = self:_MemberInfo(m, side == view)
		end
		return { Active = s.Active, Team = team }
	end
	if view == "Enemy" then
		return {
			Turn = self.Turn,
			State = if self.PendingReplace.Enemy then "WaitingForReplacement" else self.State,
			Mode = self.Mode,
			CanFlee = self.CanFlee,
			MustStruggle = not hasUsableMove(self:Active("Enemy")),
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
		Turn = self.Turn,
		State = if self.State == "WaitingForReplacement" and not self.PendingReplace.Player then "WaitingForOpponent" else self.State,
		Mode = self.Mode,
		CanFlee = self.CanFlee,
		MustStruggle = not hasUsableMove(self:Active("Player")),
		Player = sideInfo("Player"),
		Enemy = sideInfo("Enemy"),
		Bag = if self.Mode == "PvP" then {} else bag,
	}
end

return BattleEngine
