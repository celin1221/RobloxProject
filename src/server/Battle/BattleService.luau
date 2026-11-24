--[[
	BattleService (GDD secoes 5 e 10)
	Orquestrador de sessoes de batalha no servidor:
	- Usa `ReplicatedStorage/Core/BattleEngine` para toda a maquina de estados pura do turno
	- Usa `ServerScriptService/Battle/ArenaManager` para alocacao de arenas, rigs e posicionamento 3D
	- Gerencia comunicacao pelos Remotes (StartBattle, SubmitAction, BattleUpdate, BattleEnd), timers de PvP e hooks de recompensa
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")

local Data = ReplicatedStorage:WaitForChild("Data")
local Moves = require(Data:WaitForChild("Moves"))
local TypeChart = require(Data:WaitForChild("TypeChart"))

local Core = ReplicatedStorage:WaitForChild("Core")
local BattleEngine = require(Core:WaitForChild("BattleEngine"))

local Config = require(script.Parent.BattleConfig)
local ArenaManager = require(script.Parent.ArenaManager)
local CharacterLibrary = require(ServerScriptService:WaitForChild("CharacterLibrary"))

local BattleService = {}

-- Re-exporta BattleEngine e NewBattle para manter compatibilidade com qualquer chamador ou teste existente
BattleService.Battle = BattleEngine
BattleService.NewBattle = BattleEngine.New

local SIDES = BattleEngine.SIDES
local otherSide = BattleEngine.OtherSide

-- Ganchos externos (ProgressionService): TeamFor(player), BagFor(player), OnFinished(player, battle, result), OnCancelled(player, battle)
local hooks = {}
function BattleService.SetHooks(h)
	hooks = h or {}
end

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local StartBattleRE = Remotes:WaitForChild("StartBattle")
local SubmitActionRE = Remotes:WaitForChild("SubmitAction")
local BattleUpdateRE = Remotes:WaitForChild("BattleUpdate")
local BattleEndRE = Remotes:WaitForChild("BattleEnd")

local sessions = {} -- [Player] = sessao ativa
local cooldownUntil = {} -- [Player] = os.clock() liberado
local mustLeaveTrigger = {} -- [Player] = true ate sair do raio da torre

function BattleService.IsInBattle(player: Player): boolean
	return sessions[player] ~= nil
end

function BattleService.CanTrigger(player: Player): boolean
	return sessions[player] == nil and not mustLeaveTrigger[player] and os.clock() >= (cooldownUntil[player] or 0)
end

function BattleService.MarkOutsideTrigger(player: Player)
	mustLeaveTrigger[player] = nil
end

function BattleService.RequireLeaveTrigger(player: Player)
	mustLeaveTrigger[player] = true
end

BattleService.ReturnToPlaza = ArenaManager.ReturnToPlaza

local function modelFor(session, side: string?, fieldSlot: number?): Model?
	if not side then
		return nil
	end
	local slot = fieldSlot or 1
	local bySide = session.SlotModels and session.SlotModels[side]
	if bySide and bySide[slot] then
		return bySide[slot]
	end
	if slot == 1 then
		return session.Models and session.Models[side]
	end
	return nil
end

local function destroyAllModels(session)
	local destroyed = {}
	if session.SlotModels then
		for _, slots in pairs(session.SlotModels) do
			for _, m in pairs(slots) do
				if m and m.Parent and not destroyed[m] then
					destroyed[m] = true
					m:Destroy()
				end
			end
		end
	end
	for _, m in pairs(session.Models or {}) do
		if m and m.Parent and not destroyed[m] then
			destroyed[m] = true
			m:Destroy()
		end
	end
end

-- Empacota modelos ativos por slot com chaves de string ("Slot1", "Slot2") para evitar buracos na rede
local function buildClientModels(session, view: string)
	local mySide = view
	local foeSide = otherSide(view)
	local function packSide(side: string)
		local t = {}
		local m1 = modelFor(session, side, 1)
		local m2 = modelFor(session, side, 2)
		if m1 then
			t.Slot1 = m1
		end
		if m2 then
			t.Slot2 = m2
		end
		return t
	end
	return {
		Player = modelFor(session, mySide, 1),
		Enemy = modelFor(session, foeSide, 1),
	}, {
		Player = packSide(mySide),
		Enemy = packSide(foeSide),
	}
end

local function activeNamesText(battle, side: string): string
	local names = {}
	for fs = 1, battle.SlotsPerSide do
		local b = battle:ActiveAt(side, fs)
		if b and b.Hp > 0 then
			table.insert(names, b.Name)
		end
	end
	if #names >= 2 then
		return names[1] .. " e " .. names[2]
	end
	return names[1] or (battle:Active(side) and battle:Active(side).Name) or ""
end

local function playVictoryModels(session, winnerSide: string?)
	if winnerSide ~= "Player" and winnerSide ~= "Enemy" then
		return
	end
	local battle = session.Battle
	for fs = 1, battle.SlotsPerSide do
		local b = battle:ActiveAt(winnerSide, fs)
		local model = if b and b.Hp > 0 then modelFor(session, winnerSide, fs) else nil
		if model and model.Parent then
			model:SetAttribute("Victory", true)
			local folder = model:FindFirstChild("Animations")
			if folder and folder:FindFirstChild("Victory") then
				CharacterLibrary.Stop(model)
				CharacterLibrary.Play(model, "Victory")
			end
		end
	end
end

-- PvP: quem le do lado Enemy ve tudo espelhado (o lado dele vira "Player")
local function mirrorEvent(ev)
	local m = table.clone(ev)
	if ev.Side then
		m.Side = otherSide(ev.Side)
	end
	if ev.TargetSide then
		m.TargetSide = otherSide(ev.TargetSide)
	end
	if typeof(ev.Targets) == "table" then
		local mirrored = {}
		for i, t in ipairs(ev.Targets) do
			mirrored[i] = { Side = if t.Side then otherSide(t.Side) else nil, FieldSlot = t.FieldSlot }
		end
		m.Targets = mirrored
	end
	if ev.TextEnemy then
		m.Text = ev.TextEnemy
	end
	if ev.MemberEnemyView then
		m.Member = ev.MemberEnemyView
	end
	m.TextEnemy = nil
	m.MemberEnemyView = nil
	return m
end

local function viewerOf(session, side: string): Player?
	local p = if side == "Player" then session.Player else session.Opponent
	if p and p.Parent and not (session.Gone and session.Gone[p]) then
		return p
	end
	return nil
end

-- Envia a cada jogador da sessao (no PvP o lado Enemy recebe espelhado)
local function fireViewers(session, remote, makePayload)
	for _, side in ipairs(SIDES) do
		local p = viewerOf(session, side)
		if p and (side == "Player" or session.PvP) then
			local payload = makePayload(side)
			if payload ~= nil then
				remote:FireClient(p, session.Id, payload)
			end
		end
	end
end

local function sessionAlive(session): boolean
	if session.PvP then
		return not session.Closed
	end
	return sessions[session.Player] == session
end

-- Envia os eventos ao cliente um a um, tocando as animacoes
local function present(session, events)
	local clientMove = nil
	local primaryTargetSide = nil
	local primaryTargetSlot = nil
	for _, ev in ipairs(events) do
		if not sessionAlive(session) then
			return
		end
		local payload = ev
		if ev.Kind == "Switch" then
			local model = ArenaManager.SpawnActive(session, ev.Side, ev.ToIndex, ev.FieldSlot or 1)
			payload = table.clone(ev)
			payload.Model = model
		elseif ev.Kind == "UseMove" then
			payload = table.clone(ev)
			payload.Model = modelFor(session, ev.Side, ev.FieldSlot)
			payload.TargetModel = ev.TargetSide and modelFor(session, ev.TargetSide, ev.TargetFieldSlot)
			if typeof(ev.Targets) == "table" and #ev.Targets > 1 then
				local tModels = {}
				for _, t in ipairs(ev.Targets) do
					local tm = modelFor(session, t.Side, t.FieldSlot)
					if tm then
						table.insert(tModels, tm)
					end
				end
				payload.TargetModels = tModels
			end
		end
		fireViewers(session, BattleUpdateRE, function(side)
			if side == "Enemy" then
				return { Event = mirrorEvent(payload) }
			end
			if payload.TextEnemy or payload.MemberEnemyView then
				local clean = table.clone(payload)
				clean.TextEnemy = nil
				clean.MemberEnemyView = nil
				return { Event = clean }
			end
			return { Event = payload }
		end)
		local model = ev.Side and modelFor(session, ev.Side, ev.FieldSlot)
		local delay = Config.EventDelay[ev.Kind] or Config.EventDelay.Default
		if ev.Kind == "ClearSlot" then
			ArenaManager.ClearSlot(session, ev.Side, ev.FieldSlot or 1)
			delay = 0.25
		elseif ev.Kind == "UseMove" then
			local mv = Moves.Get(ev.MoveId)
			clientMove = if mv and mv.Anim and mv.Vfx then mv else nil
			primaryTargetSide = ev.TargetSide
			primaryTargetSlot = ev.TargetFieldSlot or 1
			if clientMove then
				delay = math.max(delay, (clientMove.Timing and clientMove.Timing.Impact or 0) + 0.05)
			elseif model then
				CharacterLibrary.Play(model, "Attack")
			end
		elseif ev.Kind == "Damage" and model then
			CharacterLibrary.Play(model, "Hit")
			local isSecondarySpreadHit = clientMove ~= nil and (ev.Side ~= primaryTargetSide or (ev.FieldSlot or 1) ~= primaryTargetSlot)
			if not clientMove or isSecondarySpreadHit then
				ArenaManager.ImpactBurst(model, TypeChart.Color[ev.MoveType] or Color3.new(1, 1, 1))
			end
		elseif ev.Kind == "StatusDamage" and model then
			CharacterLibrary.Play(model, "Hit")
			ArenaManager.ImpactBurst(model, if ev.Status == "Burn" then Color3.fromRGB(255, 110, 40) else Color3.fromRGB(160, 70, 200))
		elseif ev.Kind == "Faint" and model then
			model:SetAttribute("Fainted", true)
			CharacterLibrary.Stop(model)
			CharacterLibrary.Play(model, "Faint")
		elseif ev.Kind == "Capture" and ev.Success and model then
			CharacterLibrary.Stop(model)
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					d.Transparency = 1
				end
			end
		end
		task.wait(delay * (Config.TimeScale or 1))
	end
end

local pvpOnTimeout

local function sendAwait(session)
	local battle = session.Battle
	if session.PvP then
		session.Choices = {}
		session.TurnToken = (session.TurnToken or 0) + 1
		local token = session.TurnToken
		local turnTime = Config.PvPTurnTime or 30
		session.Deadline = workspace:GetServerTimeNow() + turnTime
		fireViewers(session, BattleUpdateRE, function(side)
			local state = battle:Snapshot(side)
			if battle.State == "WaitingForReplacement" then
				if battle.PendingReplace[side] then
					return { AwaitReplacement = true, State = state, Deadline = session.Deadline }
				end
				return { Waiting = "O advers\u{e1}rio est\u{e1} escolhendo o pr\u{f3}ximo...", State = state, Deadline = session.Deadline }
			end
			return { Await = true, State = state, Deadline = session.Deadline }
		end)
		task.delay(turnTime, function()
			if session.TurnToken == token and not session.Closed and not session.Busy then
				pvpOnTimeout(session)
			end
		end)
		return
	end
	if battle.State == "WaitingForReplacement" then
		BattleUpdateRE:FireClient(session.Player, session.Id, { AwaitReplacement = true, State = battle:Snapshot() })
	else
		BattleUpdateRE:FireClient(session.Player, session.Id, { Await = true, State = battle:Snapshot() })
	end
end

-- Encerra a sessao: apaga os lutadores, libera a arena e devolve o jogador a praca
local function cleanup(session, returnPlayer: boolean)
	if session.PvP then
		if session.Closed then
			return
		end
		session.Closed = true
		session.TurnToken = (session.TurnToken or 0) + 1
		destroyAllModels(session)
		if session.Arena and session.Arena.Parent then
			ArenaManager.ConfigureAltars(session.Arena, false)
			session.Arena:SetAttribute("InUse", false)
		end
		for _, p in ipairs({ session.Player, session.Opponent }) do
			if sessions[p] == session then
				sessions[p] = nil
			end
			cooldownUntil[p] = os.clock() + Config.TriggerCooldown
			if returnPlayer and p.Parent and not session.Gone[p] then
				ArenaManager.ReturnToPlaza(p)
			end
		end
		return
	end
	if sessions[session.Player] ~= session then
		return
	end
	sessions[session.Player] = nil
	destroyAllModels(session)
	if session.Arena and session.Arena.Parent then
		ArenaManager.ConfigureAltars(session.Arena, false)
		session.Arena:SetAttribute("InUse", false)
	end
	cooldownUntil[session.Player] = os.clock() + Config.TriggerCooldown
	mustLeaveTrigger[session.Player] = true

	if returnPlayer then
		ArenaManager.ReturnToPlaza(session.Player)
	end
	if session.Opts and session.Opts.OnClosed then
		task.spawn(session.Opts.OnClosed, session.Result or "Cancelled")
	end
	if session.Result == nil and hooks.OnCancelled and not (session.Opts and session.Opts.NoWriteBack) then
		local ok, err = pcall(hooks.OnCancelled, session.Player, session.Battle)
		if not ok then
			warn("[BattleService] OnCancelled: " .. tostring(err))
		end
	end
end

local function finish(session)
	local battle = session.Battle
	if session.PvP then
		if session.Closed or session.Finishing then
			return
		end
		session.Finishing = true
		session.TurnToken += 1
		fireViewers(session, BattleEndRE, function(side)
			local r = if battle.Winner == side then "Win" elseif battle.Winner == "None" then "Fled" else "Lose"
			return { Result = r, Reason = battle.EndReason }
		end)
		playVictoryModels(session, battle.Winner)
		if session.OnPvPEnd then
			task.spawn(session.OnPvPEnd, battle.Winner, battle.EndReason)
		end
		task.wait(Config.EndScreenTime * (Config.TimeScale or 1))
		cleanup(session, true)
		return
	end
	local result = if battle.Winner == "Player" then "Win" elseif battle.Winner == "Enemy" then "Lose" else "Fled"
	if hooks.OnFinished and not (session.Opts and session.Opts.NoWriteBack) then
		local ok, lines = pcall(hooks.OnFinished, session.Player, battle, result)
		if not ok then
			warn("[BattleService] OnFinished: " .. tostring(lines))
		elseif typeof(lines) == "table" and #lines > 0 then
			local events = {}
			for _, text in ipairs(lines) do
				table.insert(events, { Kind = "Message", Text = text })
			end
			present(session, events)
		end
	end
	if session.Opts and session.Opts.OnEnd then
		local ok, lines = pcall(session.Opts.OnEnd, battle, result)
		if not ok then
			warn("[BattleService] OnEnd: " .. tostring(lines))
		elseif typeof(lines) == "table" and #lines > 0 then
			local events = {}
			for _, text in ipairs(lines) do
				table.insert(events, { Kind = "Message", Text = text })
			end
			present(session, events)
		end
	end
	session.Result = result
	if sessions[session.Player] ~= session then
		return
	end
	BattleEndRE:FireClient(session.Player, session.Id, { Result = result, Reason = battle.EndReason })
	playVictoryModels(session, battle.Winner)
	task.wait(Config.EndScreenTime * (Config.TimeScale or 1))
	cleanup(session, not (session.Opts and session.Opts.KeepPlayer))
end

function BattleService.StartBattle(player: Player, opts): boolean
	opts = opts or {}
	if sessions[player] then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	local arena = ArenaManager.FindFreeArena()
	if not arena then
		warn("[BattleService] Nenhuma arena livre")
		return false
	end
	arena:SetAttribute("InUse", true)

	local playerTeam = opts.PlayerTeam
	if not playerTeam then
		playerTeam = if hooks.TeamFor then hooks.TeamFor(player) else Config.PlayerTeam
	end
	if not playerTeam then
		arena:SetAttribute("InUse", false)
		return false
	end

	local okNew, battle = pcall(BattleEngine.New, {
		Player = { Team = playerTeam },
		Enemy = { Team = opts.EnemyTeam or Config.EnemyTeam, AI = opts.EnemyAI or Config.EnemyAI },
		Format = opts.Format,
		Mode = opts.Mode or Config.Mode,
		CanFlee = opts.CanFlee,
		CaptureBlocked = opts.CaptureBlocked,
		Bag = opts.Bag or (hooks.BagFor and hooks.BagFor(player)) or Config.StartingBag,
	})
	if not okNew then
		warn("[BattleService] Time invalido: " .. tostring(battle))
		arena:SetAttribute("InUse", false)
		return false
	end
	local session = {
		Id = HttpService:GenerateGUID(false),
		Player = player,
		Battle = battle,
		Arena = arena,
		Opts = opts,
		Models = {},
		SlotModels = { Player = {}, Enemy = {} },
		Busy = true,
	}
	sessions[player] = session

	local ok, err = pcall(function()
		session.FloorY = ArenaManager.GetFloorY(arena)
		ArenaManager.ConfigureAltars(arena, battle:IsDouble())
		local actors = arena:FindFirstChild("BattleActors") or Instance.new("Folder")
		actors.Name = "BattleActors"
		actors.Parent = arena
		session.Actors = actors
		for fs = 1, battle.SlotsPerSide do
			if battle:ActiveAt("Player", fs) then
				ArenaManager.SpawnActive(session, "Player", nil, fs)
			end
			if battle:ActiveAt("Enemy", fs) then
				ArenaManager.SpawnActive(session, "Enemy", nil, fs)
			end
		end
		ArenaManager.PlaceViewer(session, player, arena.PlayerPoint, battle:IsDouble())
	end)
	if not ok then
		warn("[BattleService] Falha ao montar a batalha: " .. tostring(err))
		cleanup(session, true)
		return false
	end

	local models, slotModels = buildClientModels(session, "Player")
	StartBattleRE:FireClient(player, session.Id, {
		Camera = ArenaManager.BattleCamera(arena, battle.Format),
		Models = models,
		SlotModels = slotModels,
		State = battle:Snapshot(),
	})

	task.spawn(function()
		local intro = {}
		local defaultIntro = if battle:IsDouble()
			then "Batalha em Dupla (2x2)! O advers\u{e1}rio tem " .. #battle.Sides.Enemy.Team .. " personagens."
			else "Voc\u{ea} foi desafiado! O advers\u{e1}rio tem " .. #battle.Sides.Enemy.Team .. " personagens."
		for _, text in ipairs(opts.Intro or { defaultIntro }) do
			table.insert(intro, { Kind = "Message", Text = text })
		end
		table.insert(intro, { Kind = "Message", Text = "Vai, " .. activeNamesText(battle, "Player") .. "!" })
		present(session, intro)
		if sessions[player] == session then
			session.Busy = false
			sendAwait(session)
		end
	end)
	return true
end

function BattleService.StartForPlayer(player: Player): boolean
	return BattleService.StartBattle(player, nil)
end

--==================================================================
-- PvP (GDD secao 5)
--==================================================================
local function sideOf(session, player: Player): string?
	if session.Player == player then
		return "Player"
	elseif session.Opponent == player then
		return "Enemy"
	end
	return nil
end

local function pvpAfter(session, events)
	present(session, events)
	while session.PendingEvents and not session.Closed do
		local pending = session.PendingEvents
		session.PendingEvents = nil
		present(session, pending)
	end
	if session.Closed then
		return
	end
	if session.Battle.State == "Ended" then
		finish(session)
	else
		session.Busy = false
		sendAwait(session)
	end
end

local function pvpTryResolve(session, timedOut: boolean?)
	local battle = session.Battle
	if session.Busy or session.Closed or battle.State == "Ended" then
		return
	end
	local prefix = {}
	if battle.State == "WaitingForReplacement" then
		for side in pairs(battle.PendingReplace) do
			if not session.Choices[side] then
				if not timedOut then
					return
				end
				local auto = battle:AutoReplacement(side)
				session.Choices[side] = {
					Kind = "Replace",
					Index = if typeof(auto) == "number" then auto else nil,
					Replacements = if typeof(auto) == "table" then auto else nil,
					Auto = true,
				}
			end
		end
		session.Busy = true
		local events = {}
		for _, side in ipairs(SIDES) do
			local c = session.Choices[side]
			if c and battle.PendingReplace[side] then
				if c.Auto then
					table.insert(events, { Kind = "Message", Text = if side == "Player" then "Tempo esgotado! Escolha autom\u{e1}tica." else "O advers\u{e1}rio n\u{e3}o escolheu a tempo.", TextEnemy = if side == "Enemy" then "Tempo esgotado! Escolha autom\u{e1}tica." else "O advers\u{e1}rio n\u{e3}o escolheu a tempo." })
				end
				for _, ev in ipairs(battle:ResolveReplacement(side, c.Replacements or c.Index)) do
					table.insert(events, ev)
				end
			end
		end
		pvpAfter(session, events)
		return
	end
	if battle.State ~= "WaitingForInput" then
		return
	end
	for _, side in ipairs(SIDES) do
		if not session.Choices[side] then
			if not timedOut then
				return
			end
			session.Choices[side] = battle:AutoAction(side)
			table.insert(prefix, { Kind = "Message", Text = if side == "Player" then "Tempo esgotado! A\u{e7}\u{e3}o autom\u{e1}tica." else "O advers\u{e1}rio n\u{e3}o escolheu a tempo.", TextEnemy = if side == "Enemy" then "Tempo esgotado! A\u{e7}\u{e3}o autom\u{e1}tica." else "O advers\u{e1}rio n\u{e3}o escolheu a tempo." })
		end
	end
	session.Busy = true
	local events = battle:ResolveTurn(session.Choices.Player, session.Choices.Enemy, prefix)
	pvpAfter(session, events)
end

pvpOnTimeout = function(session)
	pvpTryResolve(session, true)
end

local function pvpSubmit(session, player: Player, action)
	local side = sideOf(session, player)
	local battle = session.Battle
	if not side or session.Closed or battle.State == "Ended" then
		return
	end
	if session.Busy then
		BattleUpdateRE:FireClient(player, session.Id, { Error = "Aguarde o fim do turno." })
		return
	end
	if session.Choices[side] then
		BattleUpdateRE:FireClient(player, session.Id, { Error = "Voc\u{ea} j\u{e1} escolheu. Aguardando o advers\u{e1}rio." })
		return
	end
	if action.Kind == "Flee" and battle.State == "WaitingForInput" then
		session.Busy = true
		pvpAfter(session, battle:Forfeit(side))
		return
	end
	local ok, err = battle:ValidateAction(side, action)
	if not ok then
		local payload = { Error = err, State = battle:Snapshot(side), Deadline = session.Deadline }
		BattleUpdateRE:FireClient(player, session.Id, payload)
		return
	end
	session.Choices[side] = action
	BattleUpdateRE:FireClient(player, session.Id, { Waiting = "Aguardando o advers\u{e1}rio...", Deadline = session.Deadline })
	pvpTryResolve(session, false)
end

local function pvpDrop(session, player: Player)
	if session.Closed then
		return
	end
	session.Gone[player] = true
	local side = sideOf(session, player)
	local battle = session.Battle
	if sessions[player] == session then
		sessions[player] = nil
	end
	if battle.State == "Ended" then
		return
	end
	local events = battle:Forfeit(side, "Disconnect")
	if session.Busy then
		session.PendingEvents = events
		return
	end
	session.Busy = true
	task.spawn(pvpAfter, session, events)
end

function BattleService.StartPvP(playerA: Player, playerB: Player, teamA, teamB, onEnd, opts)
	opts = opts or {}
	local format = if opts.Format == "2x2" then "2x2" else "1x1"
	if sessions[playerA] or sessions[playerB] then
		return false, "Algu\u{e9}m j\u{e1} est\u{e1} em batalha."
	end
	for _, p in ipairs({ playerA, playerB }) do
		local ch = p.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 or not ch:FindFirstChild("HumanoidRootPart") then
			return false, p.DisplayName .. " n\u{e3}o est\u{e1} pronto."
		end
	end
	if format == "2x2" then
		if typeof(teamA) ~= "table" or #teamA < 2 then
			return false, playerA.DisplayName .. " precisa de pelo menos 2 personagens no time para 2x2."
		end
		if typeof(teamB) ~= "table" or #teamB < 2 then
			return false, playerB.DisplayName .. " precisa de pelo menos 2 personagens no time para 2x2."
		end
	end
	local arena = ArenaManager.FindFreeArena()
	if not arena then
		return false, "Nenhuma arena livre agora. Tente de novo em instantes."
	end
	local okNew, battle = pcall(BattleEngine.New, {
		Player = { Team = teamA },
		Enemy = { Team = teamB },
		Format = format,
		Mode = "PvP",
		EnemyHuman = true,
		Bag = {},
	})
	if not okNew then
		warn("[BattleService] PvP invalido: " .. tostring(battle))
		return false, "Time inv\u{e1}lido."
	end
	arena:SetAttribute("InUse", true)
	local session = {
		Id = HttpService:GenerateGUID(false),
		Player = playerA,
		Opponent = playerB,
		PvP = true,
		Battle = battle,
		Arena = arena,
		Opts = opts,
		Models = {},
		SlotModels = { Player = {}, Enemy = {} },
		Gone = {},
		Choices = {},
		TurnToken = 0,
		Busy = true,
		OnPvPEnd = onEnd,
	}
	sessions[playerA] = session
	sessions[playerB] = session

	local ok, err = pcall(function()
		session.FloorY = ArenaManager.GetFloorY(arena)
		ArenaManager.ConfigureAltars(arena, battle:IsDouble())
		local actors = arena:FindFirstChild("BattleActors") or Instance.new("Folder")
		actors.Name = "BattleActors"
		actors.Parent = arena
		session.Actors = actors
		for fs = 1, battle.SlotsPerSide do
			if battle:ActiveAt("Player", fs) then
				ArenaManager.SpawnActive(session, "Player", nil, fs)
			end
			if battle:ActiveAt("Enemy", fs) then
				ArenaManager.SpawnActive(session, "Enemy", nil, fs)
			end
		end
		ArenaManager.PlaceViewer(session, playerA, arena.PlayerPoint, battle:IsDouble())
		ArenaManager.PlaceViewer(session, playerB, arena.EnemyPoint, battle:IsDouble())
	end)
	if not ok then
		warn("[BattleService] Falha ao montar o PvP: " .. tostring(err))
		cleanup(session, true)
		return false, "Falha ao montar a arena."
	end

	local cam = ArenaManager.BattleCamera(arena, battle.Format)
	local modelsA, slotModelsA = buildClientModels(session, "Player")
	local modelsB, slotModelsB = buildClientModels(session, "Enemy")
	StartBattleRE:FireClient(playerA, session.Id, {
		Camera = cam,
		Models = modelsA,
		SlotModels = slotModelsA,
		State = battle:Snapshot("Player"),
		OpponentName = playerB.DisplayName,
	})
	StartBattleRE:FireClient(playerB, session.Id, {
		Camera = ArenaManager.MirroredCamera(arena, cam),
		Models = modelsB,
		SlotModels = slotModelsB,
		State = battle:Snapshot("Enemy"),
		OpponentName = playerA.DisplayName,
	})

	task.spawn(function()
		local modeTitle = if battle:IsDouble() then "PvP 2x2 (Em Dupla)" else "PvP 1x1"
		local intro = {
			{
				Kind = "Message",
				Text = modeTitle .. " contra " .. playerB.DisplayName .. "! N\u{ed}veis igualados em 50, sem itens.",
				TextEnemy = modeTitle .. " contra " .. playerA.DisplayName .. "! N\u{ed}veis igualados em 50, sem itens.",
			},
			{
				Kind = "Message",
				Text = "Vai, " .. activeNamesText(battle, "Player") .. "!",
				TextEnemy = "Vai, " .. activeNamesText(battle, "Enemy") .. "!",
			},
		}
		pvpAfter(session, intro)
	end)
	return true
end

-- Sanitiza acao vinda do cliente (nunca confiar em tabelas cruas do cliente)
local function sanitizeSingleAction(raw, allowItems: boolean)
	if typeof(raw) ~= "table" or typeof(raw.Kind) ~= "string" then
		return nil
	end
	local kind = raw.Kind
	if kind == "Flee" then
		return { Kind = "Flee" }
	elseif kind == "Move" then
		return {
			Kind = "Move",
			Index = if typeof(raw.Index) == "number" then raw.Index else nil,
			TargetSide = if raw.TargetSide == "Enemy" or raw.TargetSide == "Ally" then raw.TargetSide else nil,
			TargetSlot = if typeof(raw.TargetSlot) == "number" then raw.TargetSlot else nil,
		}
	elseif kind == "Switch" then
		return {
			Kind = "Switch",
			Index = if typeof(raw.Index) == "number" then raw.Index else nil,
		}
	elseif kind == "Item" and allowItems then
		return {
			Kind = "Item",
			ItemId = if typeof(raw.ItemId) == "string" then raw.ItemId else nil,
			TargetIndex = if typeof(raw.TargetIndex) == "number" then raw.TargetIndex else nil,
		}
	end
	return nil
end

local function sanitizeAction(raw, allowItems: boolean)
	if typeof(raw) ~= "table" or typeof(raw.Kind) ~= "string" then
		return nil
	end
	if raw.Kind == "Replace" then
		local out = {
			Kind = "Replace",
			Index = if typeof(raw.Index) == "number" then raw.Index else nil,
		}
		if typeof(raw.Replacements) == "table" then
			local list = {}
			for i = 1, math.min(2, #raw.Replacements) do
				local entry = raw.Replacements[i]
				if typeof(entry) == "table" and typeof(entry.Index) == "number" then
					table.insert(list, {
						FieldSlot = if typeof(entry.FieldSlot) == "number" then entry.FieldSlot else nil,
						Index = entry.Index,
					})
				end
			end
			out.Replacements = list
		end
		return out
	elseif raw.Kind == "Double" then
		if typeof(raw.Actions) ~= "table" then
			return nil
		end
		local list = {}
		local count = 0
		for k, entry in pairs(raw.Actions) do
			count += 1
			if count > 4 then
				break
			end
			local sub = sanitizeSingleAction(entry, allowItems)
			if sub and sub.Kind ~= "Flee" then
				sub.FieldSlot = if typeof(entry.FieldSlot) == "number" then entry.FieldSlot elseif typeof(k) == "number" then k else nil
				table.insert(list, sub)
			end
		end
		return { Kind = "Double", Actions = list }
	end
	return sanitizeSingleAction(raw, allowItems)
end

function BattleService.Init()
	local lastSubmit = {}
	SubmitActionRE.OnServerEvent:Connect(function(player, battleId, action)
		local t = os.clock()
		if lastSubmit[player] and t - lastSubmit[player] < 0.15 then
			return
		end
		lastSubmit[player] = t
		local session = sessions[player]
		if not session or session.Id ~= battleId then
			return
		end
		local clean = sanitizeAction(action, not session.PvP)
		if not clean then
			return
		end
		if session.PvP then
			pvpSubmit(session, player, clean)
			return
		end
		if session.Busy then
			BattleUpdateRE:FireClient(player, session.Id, { Error = "Aguarde o fim do turno." })
			return
		end
		local battle = session.Battle
		local ok, err = battle:ValidateAction("Player", clean)
		if not ok then
			BattleUpdateRE:FireClient(player, session.Id, { Error = err, State = battle:Snapshot() })
			return
		end

		session.Busy = true
		local events
		if clean.Kind == "Replace" then
			events = battle:ResolveReplacement("Player", clean.Replacements or clean.Index)
		else
			events = battle:ResolveTurn(clean)
		end
		present(session, events)
		if sessions[player] ~= session then
			return
		end
		if battle.State == "Ended" then
			finish(session)
		else
			session.Busy = false
			sendAwait(session)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]
		if session and session.PvP then
			pvpDrop(session, player)
		elseif session then
			cleanup(session, false)
		end
		cooldownUntil[player] = nil
		mustLeaveTrigger[player] = nil
		lastSubmit[player] = nil
	end)

	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			local session = sessions[player]
			if session and session.PvP then
				BattleEndRE:FireClient(player, session.Id, { Result = "Lose", Reason = "Disconnect" })
				pvpDrop(session, player)
			elseif session then
				BattleEndRE:FireClient(player, session.Id, { Result = "Cancelled" })
				cleanup(session, false)
			end
		end)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
end

return BattleService
