--[[
	RaidEngine (Camada 2 - Core): Maquina de estados pura de Raid Cooperativa 4x1.
	- Zero dependencias de Players, Workspace, ServerScriptService, RemoteEvent ou task.wait.
	- 100% deterministica com Seed fixa e testavel diretamente na suite de validacao.
	- Implementa:
	    * 4 slots aliados (1..4 jogadores humanos + Aliados NPCs completando 4 lutadores)
	    * 2 vidas individuais por jogador humano com 2 turnos de espera para reviver (NPCs nunca gastam vidas humanas)
	    * 1 Boss gigante com Escudo de Fase (65% e 30% HP), quebra de escudo (Super Efetivo/Critico = 2 cargas,
	      atordoamento + -2 DEF + 4% dano de estilhacamento), Pulso de Anulacao e 2 acoes por turno (1 alvo + 1 area)
	    * Somente os 4 golpes do personagem (sem Mochila e sem Torcida), limite de 10 turnos e ranking de dano/MVP
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = ReplicatedStorage:WaitForChild("Data")
local Characters = require(Data:WaitForChild("Characters"))
local Moves = require(Data:WaitForChild("Moves"))
local TypeChart = require(Data:WaitForChild("TypeChart"))
local Genetics = require(Data:WaitForChild("Genetics"))
local Passives = require(Data:WaitForChild("Passives"))
local Raids = require(Data:WaitForChild("Raids"))

local DamageCalc = require(script.Parent:WaitForChild("DamageCalc"))

local RaidEngine = {}
RaidEngine.__index = RaidEngine

local STAT_NAMES = {
	Attack = "Ataque",
	Defense = "Defesa",
	Speed = "Velocidade",
	Accuracy = "Precis\u{e3}o",
}

local function freshStages()
	return { Attack = 0, Defense = 0, Speed = 0, Accuracy = 0 }
end

local function passiveEffect(battler)
	if not battler or not battler.PassiveId then
		return nil, nil
	end
	local p = Passives.Get(battler.PassiveId)
	return p and p.Effect or nil, p
end

local function buildMoves(characterId: string, level: number, moveIds: { string }?, ensureAoe: boolean?)
	local ids = if typeof(moveIds) == "table" and #moveIds > 0
		then table.clone(moveIds)
		else Characters.DefaultActive(characterId, level)

	if ensureAoe then
		local hasAoe = false
		local hasSingle = false
		for _, mid in ipairs(ids) do
			local mv = Moves.Get(mid)
			if mv and mv.Category == "Damage" then
				if mv.Target == "AllEnemies" then
					hasAoe = true
				else
					hasSingle = true
				end
			end
		end
		local def = Characters.Get(characterId)
		if not hasAoe and def then
			local aoeId = Raids.ClassAoeMove[def.Type] or "OndaDeImpacto"
			if #ids >= 4 then
				ids[4] = aoeId
			else
				table.insert(ids, aoeId)
			end
		end
		if not hasSingle and def then
			local defaults = Characters.DefaultActive(characterId, 1)
			if defaults[1] then
				ids[1] = defaults[1]
			end
		end
	end

	local out = {}
	for i = 1, math.min(4, #ids) do
		local mid = ids[i]
		local mv = Moves.Get(mid)
		if mv then
			table.insert(out, { Id = mid, Pp = mv.PP, MaxPp = mv.PP })
		end
	end
	if #out == 0 then
		local fallback = Moves.Get("SocoDireto")
		if fallback then
			table.insert(out, { Id = "SocoDireto", Pp = fallback.PP, MaxPp = fallback.PP })
		end
	end
	return out
end

local function newAllySlot(slotIndex: number, cfg)
	local def = assert(Characters.Get(cfg.CharacterId), "Personagem desconhecido na Raid: " .. tostring(cfg.CharacterId))
	local level = math.clamp(math.floor(cfg.Level or 10), 1, Characters.MaxLevel)
	local stats = Characters.StatsAt(cfg.CharacterId, level)
	local scalarMult = if typeof(cfg.StatMultiplier) == "number" then cfg.StatMultiplier else 1
	local perStat = if typeof(cfg.StatMultipliers) == "table" then cfg.StatMultipliers else nil
	if not perStat and (cfg.Genetics or cfg.Training) then
		perStat = Genetics.MultipliersFor(cfg.Genetics, cfg.Training)
	end
	for k, v in pairs(stats) do
		local m = scalarMult * (if perStat and typeof(perStat[k]) == "number" then perStat[k] else 1)
		if m ~= 1 then
			stats[k] = math.max(1, math.floor(v * m + 0.5))
		end
	end

	local awakened = cfg.Awakened == true
	local passiveId = if typeof(cfg.PassiveId) == "string" then cfg.PassiveId else Characters.PassiveIdOf(cfg.CharacterId, awakened)
	local isNpc = cfg.IsNpc == true

	return {
		Slot = slotIndex,
		IsNpc = isNpc,
		ConvertedToAi = false,
		UserId = cfg.UserId,
		OwnerName = cfg.OwnerName or (if isNpc then ("Aliado " .. def.Name) else ("Jogador " .. slotIndex)),
		Uid = cfg.Uid,
		Id = cfg.CharacterId,
		Name = def.Name,
		ModelName = def.ModelName,
		Type = def.Type,
		Level = level,
		Stats = stats,
		Hp = stats.HP,
		MaxHp = stats.HP,
		Moves = buildMoves(cfg.CharacterId, level, cfg.Moves, false),
		Stages = freshStages(),
		Status = nil,
		StatusTurns = 0,
		PassiveId = passiveId,
		Variant = cfg.Variant,
		Awakened = awakened,
		Stars = cfg.Stars or 0,
		Lives = if isNpc then 99 else Raids.PlayerLives,
		MaxLives = if isNpc then 99 else Raids.PlayerLives,
		RespawnIn = 0,
		Out = false,
		Protected = false,
		TotalDamage = 0,
	}
end

local function newBoss(bossId: string, stars: number)
	local tier = assert(Raids.Tiers[stars], "Estrela de Raid invalida: " .. tostring(stars))
	local def = assert(Characters.Get(bossId), "Boss desconhecido na Raid: " .. tostring(bossId))
	local stats = Characters.StatsAt(bossId, tier.Level)
	stats.HP = math.max(100, math.floor(stats.HP * tier.HpMult + 0.5))
	stats.Attack = math.max(10, math.floor(stats.Attack * tier.AtkMult + 0.5))

	local customMoves = Raids.BossMoves[bossId]
	local moves = buildMoves(bossId, tier.Level, customMoves, true)

	return {
		Id = bossId,
		Name = def.Name,
		ModelName = def.ModelName,
		Type = def.Type,
		Rarity = def.Rarity,
		Anime = def.Anime or "Generico",
		Level = tier.Level,
		Stars = stars,
		Stats = stats,
		Hp = stats.HP,
		MaxHp = stats.HP,
		Moves = moves,
		Stages = freshStages(),
		Status = nil,
		StatusTurns = 0,
		PassiveId = Characters.PassiveIdOf(bossId, stars >= 4 and Characters.HasAwakening(bossId)),
		Shield = 0,
		MaxShield = tier.ShieldBars,
		PhasesTriggered = { false, false },
		Stunned = false,
		Protected = false,
	}
end

function RaidEngine.New(config)
	assert(typeof(config) == "table", "RaidEngine.New exige tabela de configuracao")
	local stars = config.Stars or 3
	local tier = assert(Raids.Tiers[stars], "Estrela de Raid invalida: " .. tostring(stars))
	local bossId = config.BossId or tier.Bosses[1]
	local seed = config.Seed or os.time()

	local self = setmetatable({
		Stars = stars,
		Tier = tier,
		SlotKey = config.SlotKey or "",
		Turn = 0,
		MaxTurns = config.MaxTurns or Raids.MaxTurns,
		State = "WaitingForInput", -- "WaitingForInput" | "Resolving" | "Ended"
		Winner = nil, -- "Players" | "Boss"
		EndReason = nil, -- "BossDefeated" | "AllHumansDefeated" | "TurnLimit"
		MvpSlot = nil,
		DamageRanking = {},
		Rng = Random.new(seed),
		Boss = newBoss(bossId, stars),
		Slots = {},
	}, RaidEngine)

	local rawSlots = config.Slots or {}
	local npcPool = tier.NpcAllies or { "Itadori", "Nobara", "Rukia", "Piccolo" }
	local npcCursor = 0
	for i = 1, Raids.MaxPlayers do
		local entry = rawSlots[i]
		if entry then
			self.Slots[i] = newAllySlot(i, entry)
		else
			npcCursor += 1
			local npcId = npcPool[((npcCursor - 1) % #npcPool) + 1]
			-- Evita clonar o proprio Boss como aliado NPC se houver alternativa
			if npcId == bossId and #npcPool > 1 then
				npcId = npcPool[(npcCursor % #npcPool) + 1]
			end
			self.Slots[i] = newAllySlot(i, {
				CharacterId = npcId,
				Level = math.max(10, tier.Level - 3),
				IsNpc = true,
			})
		end
	end

	return self
end

function RaidEngine:IsAlive(slotIndex: number): boolean
	local s = self.Slots[slotIndex]
	return s ~= nil and s.Hp > 0 and not s.Out
end

function RaidEngine:LivingAllySlots(): { number }
	local list = {}
	for i = 1, #self.Slots do
		if self:IsAlive(i) then
			table.insert(list, i)
		end
	end
	return list
end

function RaidEngine:AllHumansEliminated(): boolean
	local anyHuman = false
	for _, s in ipairs(self.Slots) do
		if not s.IsNpc then
			anyHuman = true
			if not s.Out then
				return false
			end
		end
	end
	return anyHuman
end

function RaidEngine:ConvertPlayerToAi(slotIndex: number)
	local s = self.Slots[slotIndex]
	if s and not s.IsNpc then
		s.ConvertedToAi = true
	end
end

-- Escolhe automaticamente o melhor golpe disponivel com PP (para NPCs, timeout de 20s e jogadores desconectados)
function RaidEngine:PickAutoAction(slotIndex: number)
	local s = self.Slots[slotIndex]
	if not s then
		return { MoveIndex = 1 }
	end
	local bestIdx = 1
	local bestScore = -1
	for i, m in ipairs(s.Moves) do
		if m.Pp > 0 then
			local mv = Moves.Get(m.Id)
			if mv and mv.Category == "Damage" then
				local score = DamageCalc.ExpectedDamage(s, self.Boss, mv, 1)
				if self.Boss.Shield > 0 and TypeChart.Multiplier(mv.Type, self.Boss.Type) > 1 then
					score *= 1.45
				end
				if score > bestScore then
					bestScore = score
					bestIdx = i
				end
			elseif bestScore < 0 then
				bestIdx = i
				bestScore = 0
			end
		end
	end
	return { MoveIndex = bestIdx }
end

local function applyStageChange(target, stat: string, delta: number, events, targetKind: string, slotIdx: number?)
	if not target or not target.Stages or not STAT_NAMES[stat] then
		return
	end
	local eff = passiveEffect(target)
	if delta < 0 and eff and (eff.ImmuneStatDrops or (stat == "Accuracy" and eff.ImmuneAccuracyDrop)) then
		return
	end
	local prev = target.Stages[stat] or 0
	local nextVal = math.clamp(prev + delta, DamageCalc.MIN_STAGE, DamageCalc.MAX_STAGE)
	if nextVal == prev then
		return
	end
	target.Stages[stat] = nextVal
	table.insert(events, {
		Kind = "StatStage",
		TargetKind = targetKind,
		Slot = slotIdx,
		TargetName = target.Name,
		Stat = stat,
		Delta = nextVal - prev,
		Stage = nextVal,
	})
end

local function tryApplyStatus(target, status: string, rng: Random, events, targetKind: string, slotIdx: number?)
	if not target or target.Hp <= 0 or target.Status ~= nil then
		return
	end
	-- Bosses de Raid resistem a Sono e Congelamento para nao perderem a luta por stun-lock
	if targetKind == "Boss" and (status == "Sleep" or status == "Freeze") then
		table.insert(events, {
			Kind = "Text",
			Text = target.Name .. " resistiu ao controle de " .. (if status == "Sleep" then "Sono" else "Congelamento") .. "!",
		})
		return
	end
	local eff = passiveEffect(target)
	if eff and (eff.ImmuneAllStatus or (eff.ImmuneStatus and eff.ImmuneStatus[status])) then
		return
	end
	target.Status = status
	target.StatusTurns = if status == "Sleep" then rng:NextInteger(1, 2) else 0
	table.insert(events, {
		Kind = "Status",
		TargetKind = targetKind,
		Slot = slotIdx,
		TargetName = target.Name,
		Status = status,
	})
end

function RaidEngine:_CheckActionStatus(actor, actorKind: string, slotIdx: number?, events): boolean
	if actor.Status == "Sleep" then
		if actor.StatusTurns <= 0 then
			actor.Status = nil
			table.insert(events, { Kind = "Text", Text = actor.Name .. " acordou!" })
		else
			actor.StatusTurns -= 1
			table.insert(events, { Kind = "StatusBlock", ActorKind = actorKind, Slot = slotIdx, Status = "Sleep", Text = actor.Name .. " est\u{e1} dormindo!" })
			return false
		end
	elseif actor.Status == "Freeze" then
		if self.Rng:NextNumber() < DamageCalc.STATUS.Freeze.ThawChance then
			actor.Status = nil
			table.insert(events, { Kind = "Text", Text = actor.Name .. " descongelou!" })
		else
			table.insert(events, { Kind = "StatusBlock", ActorKind = actorKind, Slot = slotIdx, Status = "Freeze", Text = actor.Name .. " est\u{e1} congelado!" })
			return false
		end
	elseif actor.Status == "Paralysis" then
		if self.Rng:NextNumber() < DamageCalc.STATUS.Paralysis.SkipChance then
			table.insert(events, { Kind = "StatusBlock", ActorKind = actorKind, Slot = slotIdx, Status = "Paralysis", Text = actor.Name .. " est\u{e1} paralisado e n\u{e3}o conseguiu agir!" })
			return false
		end
	end
	return true
end

function RaidEngine:_HandleAllyFaint(slot, events)
	if slot.Hp > 0 then
		return
	end
	slot.Hp = 0
	slot.Status = nil
	slot.Stages = freshStages()
	if not slot.IsNpc then
		slot.Lives = math.max(0, slot.Lives - 1)
		if slot.Lives > 0 then
			slot.RespawnIn = Raids.RespawnTurns
		else
			slot.Out = true
			slot.RespawnIn = 0
		end
	else
		-- Aliados NPCs nunca gastam vidas humanas; voltam apos 2 turnos
		slot.RespawnIn = Raids.RespawnTurns
	end
	table.insert(events, {
		Kind = "AllyFaint",
		Slot = slot.Slot,
		Name = slot.Name,
		OwnerName = slot.OwnerName,
		IsNpc = slot.IsNpc,
		Lives = slot.Lives,
		MaxLives = slot.MaxLives,
		RespawnIn = slot.RespawnIn,
		Out = slot.Out,
	})
end

function RaidEngine:_CheckBossPhases(events)
	local boss = self.Boss
	if boss.Hp <= 0 or boss.Shield > 0 then
		return
	end
	local ratio = boss.Hp / math.max(1, boss.MaxHp)
	for pIdx, thresh in ipairs(Raids.ShieldThresholds) do
		if not boss.PhasesTriggered[pIdx] and ratio <= thresh then
			boss.PhasesTriggered[pIdx] = true
			-- Pulso de Anulacao: limpa debuffs do Boss e buffs positivos dos aliados
			for stat, v in pairs(boss.Stages) do
				if v < 0 then
					boss.Stages[stat] = 0
				end
			end
			boss.Status = nil
			for _, s in ipairs(self.Slots) do
				for stat, v in pairs(s.Stages) do
					if v > 0 then
						s.Stages[stat] = 0
					end
				end
			end
			table.insert(events, {
				Kind = "PhasePulse",
				Phase = pIdx,
				Threshold = thresh,
				BossName = boss.Name,
				Text = boss.Name .. " liberou um Pulso de Anula\u{e7}\u{e3}o! Buffs do grupo e debuffs do Boss foram limpos!",
			})

			boss.Shield = boss.MaxShield
			boss.Stunned = false
			table.insert(events, {
				Kind = "ShieldUp",
				Phase = pIdx,
				Shield = boss.Shield,
				MaxShield = boss.MaxShield,
				Text = boss.Name .. " ergueu um Escudo de Fase (" .. boss.MaxShield .. " barras)!",
			})
			break
		end
	end
end

function RaidEngine:_ExecuteAllyMove(slot, moveIndex: number, events)
	if slot.Hp <= 0 or slot.Out or self.Boss.Hp <= 0 then
		return
	end
	if not self:_CheckActionStatus(slot, "Ally", slot.Slot, events) then
		return
	end
	local entry = slot.Moves[moveIndex]
	if not entry or entry.Pp <= 0 then
		-- fallback para primeiro golpe com PP
		for _, m in ipairs(slot.Moves) do
			if m.Pp > 0 then
				entry = m
				break
			end
		end
	end
	if not entry then
		return
	end
	local move = Moves.Get(entry.Id)
	if not move then
		return
	end
	entry.Pp = math.max(0, entry.Pp - 1)

	table.insert(events, {
		Kind = "Move",
		ActorKind = "Ally",
		Slot = slot.Slot,
		ActorName = slot.Name,
		MoveId = entry.Id,
		MoveName = move.Name,
		MoveType = move.Type,
		TargetKind = if move.Target == "Self" or move.Target == "AllAllies" then "Ally" else "Boss",
	})

	local boss = self.Boss
	if move.Category == "Status" then
		local eff = move.Effect
		if eff then
			if eff.Kind == "Protect" then
				slot.Protected = true
				table.insert(events, { Kind = "Text", Text = slot.Name .. " se protegeu!" })
			elseif eff.Kind == "Heal" then
				local frac = eff.Fraction or 0.45
				local targets = if move.Target == "AllAllies" then self:LivingAllySlots() else { slot.Slot }
				for _, tIdx in ipairs(targets) do
					local ts = self.Slots[tIdx]
					local gain = math.max(1, math.floor(ts.MaxHp * frac + 0.5))
					local prev = ts.Hp
					ts.Hp = math.min(ts.MaxHp, ts.Hp + gain)
					if ts.Hp > prev then
						table.insert(events, { Kind = "Heal", TargetKind = "Ally", Slot = tIdx, Amount = ts.Hp - prev, Hp = ts.Hp, MaxHp = ts.MaxHp })
					end
				end
			elseif eff.Kind == "StatStage" then
				if eff.Target == "Self" then
					local targets = if move.Target == "AllAllies" then self:LivingAllySlots() else { slot.Slot }
					for _, tIdx in ipairs(targets) do
						applyStageChange(self.Slots[tIdx], eff.Stat, eff.Stages, events, "Ally", tIdx)
					end
				else
					applyStageChange(boss, eff.Stat, eff.Stages, events, "Boss", nil)
				end
			elseif eff.Kind == "MultiStat" and typeof(eff.Changes) == "table" then
				for _, ch in ipairs(eff.Changes) do
					applyStageChange(slot, ch.Stat, ch.Stages, events, "Ally", slot.Slot)
				end
			elseif eff.Kind == "Status" and eff.Status then
				tryApplyStatus(boss, eff.Status, self.Rng, events, "Boss", nil)
			elseif eff.Kind == "MalevolentShrine" then
				-- Na Raid, Santuario Malevolente aplica dano imediato de 10% do HP do Boss (cap justo) + quebra 2 barras de escudo
				local burst = math.max(1, math.floor(boss.MaxHp * 0.10 + 0.5))
				if boss.Shield > 0 then
					burst = math.max(1, math.floor(burst * Raids.ShieldDamageMult + 0.5))
				end
				boss.Hp = math.max(0, boss.Hp - burst)
				slot.TotalDamage += burst
				table.insert(events, {
					Kind = "Damage",
					TargetKind = "Boss",
					AttackerSlot = slot.Slot,
					Amount = burst,
					Crit = false,
					Eff = 1,
					Shielded = boss.Shield > 0,
					Hp = boss.Hp,
					MaxHp = boss.MaxHp,
				})
				if boss.Shield > 0 then
					local broken = math.min(boss.Shield, 2)
					boss.Shield -= broken
					table.insert(events, { Kind = "ShieldHit", BarsBroken = broken, Shield = boss.Shield, MaxShield = boss.MaxShield })
				end
				self:_CheckBossPhases(events)
			end
		end
		return
	end

	-- Precisao
	if move.Accuracy ~= nil then
		local accStage = DamageCalc.StageMultiplier(slot.Stages.Accuracy or 0)
		local aEff = passiveEffect(slot)
		local accBonus = if aEff and aEff.AccuracyBonus then aEff.AccuracyBonus else 0
		local hitChance = math.clamp((move.Accuracy / 100) * accStage + accBonus, 0.05, 1)
		if self.Rng:NextNumber() > hitChance then
			table.insert(events, { Kind = "Miss", ActorKind = "Ally", Slot = slot.Slot, Text = slot.Name .. " errou " .. move.Name .. "!" })
			return
		end
	end

	local res = DamageCalc.Compute(slot, boss, move, self.Rng, 1, 1, { IsSpread = false })
	local dmg = res.Damage
	local wasShielded = boss.Shield > 0
	if wasShielded and dmg > 0 then
		dmg = math.max(1, math.floor(dmg * Raids.ShieldDamageMult + 0.5))
	end
	boss.Hp = math.max(0, boss.Hp - dmg)
	slot.TotalDamage += dmg

	table.insert(events, {
		Kind = "Damage",
		TargetKind = "Boss",
		AttackerSlot = slot.Slot,
		Amount = dmg,
		Crit = res.Crit,
		Eff = res.TypeMultiplier,
		Shielded = wasShielded,
		Hp = boss.Hp,
		MaxHp = boss.MaxHp,
	})

	-- Efeitos secundarios do golpe
	local eff = move.Effect
	if eff and dmg > 0 then
		local aEff = passiveEffect(slot)
		local chance = (eff.Chance or 100) * (if aEff and aEff.SecondaryChanceMult then aEff.SecondaryChanceMult else 1)
		if eff.Kind == "Drain" then
			local heal = math.max(1, math.floor(dmg * (eff.Fraction or 0.35) + 0.5))
			local prev = slot.Hp
			slot.Hp = math.min(slot.MaxHp, slot.Hp + heal)
			if slot.Hp > prev then
				table.insert(events, { Kind = "Heal", TargetKind = "Ally", Slot = slot.Slot, Amount = slot.Hp - prev, Hp = slot.Hp, MaxHp = slot.MaxHp })
			end
		elseif self.Rng:NextNumber(0, 100) <= chance then
			if eff.Kind == "Status" and eff.Status and boss.Hp > 0 then
				tryApplyStatus(boss, eff.Status, self.Rng, events, "Boss", nil)
			elseif eff.Kind == "StatStage" then
				if eff.Target == "Self" then
					applyStageChange(slot, eff.Stat, eff.Stages, events, "Ally", slot.Slot)
				elseif boss.Hp > 0 then
					applyStageChange(boss, eff.Stat, eff.Stages, events, "Boss", nil)
				end
			end
		end
	end

	-- Quebra de Escudo de Fase
	if wasShielded and dmg > 0 and boss.Hp > 0 then
		local barsBroken = if (res.TypeMultiplier > 1 or res.Crit) then 2 else 1
		boss.Shield = math.max(0, boss.Shield - barsBroken)
		table.insert(events, {
			Kind = "ShieldHit",
			AttackerSlot = slot.Slot,
			BarsBroken = barsBroken,
			Shield = boss.Shield,
			MaxShield = boss.MaxShield,
		})
		if boss.Shield == 0 then
			boss.Stunned = true
			applyStageChange(boss, "Defense", Raids.ShieldBreakDefDrop, events, "Boss", nil)
			local burst = math.max(1, math.floor(boss.MaxHp * Raids.ShieldBreakBurstFrac + 0.5))
			boss.Hp = math.max(0, boss.Hp - burst)
			slot.TotalDamage += burst
			table.insert(events, {
				Kind = "ShieldBreak",
				AttackerSlot = slot.Slot,
				Burst = burst,
				Hp = boss.Hp,
				MaxHp = boss.MaxHp,
				Text = "ESCUDO QUEBRADO! " .. boss.Name .. " foi atordoado e perdeu Defesa!",
			})
		end
	end

	self:_CheckBossPhases(events)
end

function RaidEngine:_PickBossMoves(): (string, string)
	local singlePool = {}
	local aoePool = {}
	for _, m in ipairs(self.Boss.Moves) do
		local mv = Moves.Get(m.Id)
		if mv and mv.Category == "Damage" then
			if mv.Target == "AllEnemies" then
				table.insert(aoePool, m.Id)
			else
				table.insert(singlePool, m.Id)
			end
		end
	end
	local singleId = if #singlePool > 0 then singlePool[self.Rng:NextInteger(1, #singlePool)] else self.Boss.Moves[1].Id
	local aoeId = if #aoePool > 0 then aoePool[self.Rng:NextInteger(1, #aoePool)] else (Raids.ClassAoeMove[self.Boss.Type] or singleId)
	return singleId, aoeId
end

function RaidEngine:_ExecuteBossTurn(events)
	local boss = self.Boss
	if boss.Hp <= 0 then
		return
	end
	if boss.Stunned then
		boss.Stunned = false
		table.insert(events, {
			Kind = "BossStunned",
			BossName = boss.Name,
			Text = boss.Name .. " est\u{e1} atordoado pela quebra do Escudo e perdeu as a\u{e7}\u{f5}es!",
		})
		return
	end

	local living = self:LivingAllySlots()
	if #living == 0 then
		return
	end

	local singleId, aoeId = self:_PickBossMoves()

	-- Acao 1 do Boss: Golpe de alvo unico
	if self:_CheckActionStatus(boss, "Boss", nil, events) then
		local move = Moves.Get(singleId)
		if move then
			local targetSlotIdx = living[self.Rng:NextInteger(1, #living)]
			local target = self.Slots[targetSlotIdx]
			table.insert(events, {
				Kind = "Move",
				ActorKind = "Boss",
				ActionIndex = 1,
				ActorName = boss.Name,
				MoveId = singleId,
				MoveName = move.Name,
				MoveType = move.Type,
				TargetKind = "Ally",
				TargetSlot = targetSlotIdx,
				TargetSlots = { targetSlotIdx },
			})
			if target.Protected and not move.BreaksProtect then
				table.insert(events, { Kind = "Text", Text = target.Name .. " bloqueou " .. move.Name .. "!" })
			else
				local res = DamageCalc.Compute(boss, target, move, self.Rng, 1, 1, { IsSpread = false })
				local dmg = res.Damage
				-- Passiva Firmeza (Sturdy)
				local dEff = passiveEffect(target)
				if dEff and dEff.SurviveLethalAtFullHp and target.Hp >= target.MaxHp and dmg >= target.Hp then
					dmg = target.Hp - 1
				end
				target.Hp = math.max(0, target.Hp - dmg)
				table.insert(events, {
					Kind = "Damage",
					TargetKind = "Ally",
					Slot = targetSlotIdx,
					Amount = dmg,
					Crit = res.Crit,
					Eff = res.TypeMultiplier,
					Hp = target.Hp,
					MaxHp = target.MaxHp,
				})
				if target.Hp <= 0 then
					self:_HandleAllyFaint(target, events)
				elseif move.Effect and move.Effect.Kind == "Status" and move.Effect.Status then
					if self.Rng:NextNumber(0, 100) <= (move.Effect.Chance or 100) then
						tryApplyStatus(target, move.Effect.Status, self.Rng, events, "Ally", targetSlotIdx)
					end
				end
			end
		end
	end

	-- Acao 2 do Boss: Golpe em Area (atinge todos os aliados de pe)
	living = self:LivingAllySlots()
	if #living == 0 or boss.Hp <= 0 then
		return
	end
	local aoeMove = Moves.Get(aoeId)
	if aoeMove then
		table.insert(events, {
			Kind = "Move",
			ActorKind = "Boss",
			ActionIndex = 2,
			ActorName = boss.Name,
			MoveId = aoeId,
			MoveName = aoeMove.Name,
			MoveType = aoeMove.Type,
			TargetKind = "AllAllies",
			TargetSlots = living,
		})
		local spread = if #living >= 2 then DamageCalc.SPREAD_MULTIPLIER else 1
		for _, sIdx in ipairs(living) do
			local target = self.Slots[sIdx]
			if target.Hp > 0 then
				if target.Protected and not aoeMove.BreaksProtect then
					table.insert(events, { Kind = "Text", Text = target.Name .. " bloqueou " .. aoeMove.Name .. "!" })
				else
					local res = DamageCalc.Compute(boss, target, aoeMove, self.Rng, spread, 1, { IsSpread = #living >= 2 })
					local dmg = res.Damage
					local dEff = passiveEffect(target)
					if dEff and dEff.SurviveLethalAtFullHp and target.Hp >= target.MaxHp and dmg >= target.Hp then
						dmg = target.Hp - 1
					end
					target.Hp = math.max(0, target.Hp - dmg)
					table.insert(events, {
						Kind = "Damage",
						TargetKind = "Ally",
						Slot = sIdx,
						Amount = dmg,
						Crit = res.Crit,
						Eff = res.TypeMultiplier,
						Hp = target.Hp,
						MaxHp = target.MaxHp,
					})
					if target.Hp <= 0 then
						self:_HandleAllyFaint(target, events)
					end
				end
			end
		end
	end
end

function RaidEngine:_BuildRanking()
	local list = {}
	local bestSlot = nil
	local bestDmg = -1
	for _, s in ipairs(self.Slots) do
		table.insert(list, {
			Slot = s.Slot,
			UserId = s.UserId,
			OwnerName = s.OwnerName,
			CharacterId = s.Id,
			CharacterName = s.Name,
			IsNpc = s.IsNpc,
			TotalDamage = s.TotalDamage,
		})
		if not s.IsNpc and s.TotalDamage > bestDmg then
			bestDmg = s.TotalDamage
			bestSlot = s.Slot
		end
	end
	table.sort(list, function(a, b)
		if a.TotalDamage ~= b.TotalDamage then
			return a.TotalDamage > b.TotalDamage
		end
		return a.Slot < b.Slot
	end)
	self.DamageRanking = list
	self.MvpSlot = bestSlot
end

function RaidEngine:_Finish(winner: string, reason: string, events)
	self.State = "Ended"
	self.Winner = winner
	self.EndReason = reason
	self:_BuildRanking()
	table.insert(events, {
		Kind = "End",
		Winner = winner,
		Reason = reason,
		MvpSlot = self.MvpSlot,
		DamageRanking = self.DamageRanking,
	})
end

function RaidEngine:ResolveTurn(actionsBySlot: { [number]: { MoveIndex: number? } }?)
	assert(self.State == "WaitingForInput", "Raid nao esta aguardando acoes (estado: " .. tostring(self.State) .. ")")
	self.State = "Resolving"
	actionsBySlot = actionsBySlot or {}

	local events = {}
	self.Turn += 1
	table.insert(events, { Kind = "TurnStart", Turn = self.Turn, MaxTurns = self.MaxTurns })

	-- 1. Limpa Protect anterior e processa revives automaticos (apos 2 turnos)
	self.Boss.Protected = false
	for _, s in ipairs(self.Slots) do
		s.Protected = false
		if s.Hp <= 0 and not s.Out and s.RespawnIn > 0 then
			s.RespawnIn -= 1
			if s.RespawnIn == 0 then
				s.Hp = s.MaxHp
				s.Status = nil
				s.Stages = freshStages()
				table.insert(events, {
					Kind = "AllyRevive",
					Slot = s.Slot,
					Name = s.Name,
					OwnerName = s.OwnerName,
					Lives = s.Lives,
					MaxLives = s.MaxLives,
					Hp = s.Hp,
					MaxHp = s.MaxHp,
				})
			end
		end
	end

	-- 2. Ordena acoes dos aliados vivos + Boss por prioridade e velocidade
	local queue = {}
	for i, s in ipairs(self.Slots) do
		if s.Hp > 0 and not s.Out then
			local act = if (not s.IsNpc and not s.ConvertedToAi and actionsBySlot[i])
				then actionsBySlot[i]
				else self:PickAutoAction(i)
			local moveIdx = math.clamp(math.floor(tonumber(act and act.MoveIndex) or 1), 1, #s.Moves)
			local mv = Moves.Get(s.Moves[moveIdx].Id)
			table.insert(queue, {
				Kind = "Ally",
				Slot = i,
				MoveIndex = moveIdx,
				Priority = if mv and typeof(mv.Priority) == "number" then mv.Priority else 0,
				Speed = DamageCalc.EffectiveStat(s, "Speed", false),
				Tie = self.Rng:NextNumber(),
			})
		end
	end
	table.insert(queue, {
		Kind = "Boss",
		Priority = 0,
		Speed = DamageCalc.EffectiveStat(self.Boss, "Speed", false),
		Tie = self.Rng:NextNumber(),
	})

	table.sort(queue, function(a, b)
		if a.Priority ~= b.Priority then
			return a.Priority > b.Priority
		end
		if a.Speed ~= b.Speed then
			return a.Speed > b.Speed
		end
		return a.Tie > b.Tie
	end)

	-- 3. Executa fila do turno
	for _, entry in ipairs(queue) do
		if self.Boss.Hp <= 0 then
			break
		end
		if entry.Kind == "Ally" then
			self:_ExecuteAllyMove(self.Slots[entry.Slot], entry.MoveIndex, events)
		else
			self:_ExecuteBossTurn(events)
		end
		if self.Boss.Hp <= 0 then
			self:_Finish("Players", "BossDefeated", events)
			return events
		end
		if self:AllHumansEliminated() then
			self:_Finish("Boss", "AllHumansDefeated", events)
			return events
		end
	end

	-- 4. Dano de status de fim de turno (Burn / Poison) + cura de Regeneracao
	if self.Boss.Hp > 0 and (self.Boss.Status == "Burn" or self.Boss.Status == "Poison") then
		local rawFrac = if self.Boss.Status == "Burn" then DamageCalc.STATUS.Burn.TickFraction else DamageCalc.STATUS.Poison.TickFraction
		local capFrac = math.min(rawFrac, Raids.BossDotCapFrac)
		local dot = math.max(1, math.floor(self.Boss.MaxHp * capFrac + 0.5))
		self.Boss.Hp = math.max(0, self.Boss.Hp - dot)
		table.insert(events, {
			Kind = "StatusTick",
			TargetKind = "Boss",
			Status = self.Boss.Status,
			Amount = dot,
			Hp = self.Boss.Hp,
			MaxHp = self.Boss.MaxHp,
		})
		if self.Boss.Hp <= 0 then
			self:_Finish("Players", "BossDefeated", events)
			return events
		end
		self:_CheckBossPhases(events)
	end

	for _, s in ipairs(self.Slots) do
		if s.Hp > 0 and not s.Out then
			local eff = passiveEffect(s)
			if s.Status == "Burn" or s.Status == "Poison" then
				local frac = if s.Status == "Burn" then DamageCalc.STATUS.Burn.TickFraction else DamageCalc.STATUS.Poison.TickFraction
				if eff and eff.DotDamageMult then
					frac *= eff.DotDamageMult
				end
				local dot = math.max(1, math.floor(s.MaxHp * frac + 0.5))
				s.Hp = math.max(0, s.Hp - dot)
				table.insert(events, {
					Kind = "StatusTick",
					TargetKind = "Ally",
					Slot = s.Slot,
					Status = s.Status,
					Amount = dot,
					Hp = s.Hp,
					MaxHp = s.MaxHp,
				})
				if s.Hp <= 0 then
					self:_HandleAllyFaint(s, events)
				end
			elseif eff and eff.EndTurnHealFrac and s.Hp < s.MaxHp then
				local heal = math.max(1, math.floor(s.MaxHp * eff.EndTurnHealFrac + 0.5))
				s.Hp = math.min(s.MaxHp, s.Hp + heal)
				table.insert(events, { Kind = "Heal", TargetKind = "Ally", Slot = s.Slot, Amount = heal, Hp = s.Hp, MaxHp = s.MaxHp })
			end
		end
	end

	if self:AllHumansEliminated() then
		self:_Finish("Boss", "AllHumansDefeated", events)
		return events
	end
	if self.Turn >= self.MaxTurns then
		self:_Finish("Boss", "TurnLimit", events)
		return events
	end

	self.State = "WaitingForInput"
	return events
end

-- Snapshot leve enviado aos clientes
function RaidEngine:Snapshot()
	local slots = {}
	for i, s in ipairs(self.Slots) do
		local moves = {}
		for j, m in ipairs(s.Moves) do
			local mv = Moves.Get(m.Id)
			moves[j] = {
				Id = m.Id,
				Name = mv and mv.Name or m.Id,
				Type = mv and mv.Type or s.Type,
				Power = mv and mv.Power or 0,
				Category = mv and mv.Category or "Damage",
				Pp = m.Pp,
				MaxPp = m.MaxPp,
				Eff = if mv and mv.Category == "Damage" then TypeChart.Multiplier(mv.Type, self.Boss.Type) else 1,
			}
		end
		slots[i] = {
			Slot = s.Slot,
			IsNpc = s.IsNpc,
			ConvertedToAi = s.ConvertedToAi,
			UserId = s.UserId,
			OwnerName = s.OwnerName,
			CharacterId = s.Id,
			Name = s.Name,
			Type = s.Type,
			Level = s.Level,
			Hp = s.Hp,
			MaxHp = s.MaxHp,
			Status = s.Status,
			Stages = table.clone(s.Stages),
			Lives = s.Lives,
			MaxLives = s.MaxLives,
			RespawnIn = s.RespawnIn,
			Out = s.Out,
			TotalDamage = s.TotalDamage,
			Moves = moves,
		}
	end
	return {
		Stars = self.Stars,
		Turn = self.Turn,
		MaxTurns = self.MaxTurns,
		State = self.State,
		Winner = self.Winner,
		EndReason = self.EndReason,
		MvpSlot = self.MvpSlot,
		DamageRanking = self.DamageRanking,
		Boss = {
			Id = self.Boss.Id,
			Name = self.Boss.Name,
			Type = self.Boss.Type,
			Rarity = self.Boss.Rarity,
			Level = self.Boss.Level,
			Hp = self.Boss.Hp,
			MaxHp = self.Boss.MaxHp,
			Shield = self.Boss.Shield,
			MaxShield = self.Boss.MaxShield,
			Stunned = self.Boss.Stunned,
			Status = self.Boss.Status,
			Stages = table.clone(self.Boss.Stages),
		},
		Slots = slots,
	}
end

return RaidEngine
