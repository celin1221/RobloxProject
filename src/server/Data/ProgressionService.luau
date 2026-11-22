--[[
	ProgressionService (GDD secoes 4 e 7)
	- Escolha do personagem inicial na primeira entrada (comuns marcados Starter em Data/Characters).
	- XP por vitoria, niveis 1 a 50, golpes aprendidos pelo Learnset, escolha dos 4 golpes ativos.
	- Monta o time salvo para a batalha (gancho do BattleService).
	Tudo no servidor; o cliente so pede (remotes validados aqui).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = ReplicatedStorage:WaitForChild("Data")
local Characters = require(Data.Characters)
local Moves = require(Data.Moves)
local Progression = require(Data.Progression)
local Genetics = require(Data:WaitForChild("Genetics"))
local PlayerDataService = require(script.Parent.PlayerDataService)
local AlbumService = require(script.Parent.AlbumService)
local Summon = require(Data.Summon)
local Benefits = require(Data.Benefits)
local Retention = require(Data:WaitForChild("Retention"))
local Clock = require(script.Parent:WaitForChild("Clock"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local ProgressionService = {}
ProgressionService.Listeners = {} -- function(player, battle, result) no fim de cada batalha (missoes)

local MAX_TEAM = 6
local lastCall = {} -- limite de pedidos por jogador
local rng = Random.new()

local function throttled(player: Player): boolean
	local now = os.clock()
	if lastCall[player] and now - lastCall[player] < 0.3 then
		return true
	end
	lastCall[player] = now
	return false
end

-- Cria um personagem na colecao (usado pelo inicial; invocacao e captura usarao o mesmo)
-- Retorna uid e mensagens do album (premios de tipo/raridade completos)
function ProgressionService.AddCharacter(player: Player, characterId: string, level: number, toTeam: boolean?, variant: string?, geneticsOverride)
	local data = assert(PlayerDataService.Get(player), "Perfil nao carregado")
	local def = assert(Characters.Get(characterId), "Personagem desconhecido: " .. tostring(characterId))
	level = math.clamp(math.floor(level), 1, Progression.MaxLevel)
	local uid = PlayerDataService.NewUid(player)
	local genetics = if typeof(geneticsOverride) == "table" then Genetics.SanitizeTable(geneticsOverride) else Genetics.Roll(def.Rarity, rng)
	data.Collection[uid] = {
		Uid = uid,
		CharacterId = characterId,
		Level = level,
		Xp = 0,
		Learned = Characters.LearnedAt(characterId, level),
		Active = Characters.DefaultActive(characterId, level),
		Variant = variant,
		Stars = 0,
		Genetics = genetics,
		Training = Genetics.ZeroTable(),
		ObtainedAt = os.time(),
	}
	if toTeam and #data.Team < MAX_TEAM then
		table.insert(data.Team, uid)
	end
	local albumLines = AlbumService.Record(data, characterId, variant)
	return uid, albumLines
end

-- Soma XP, sobe niveis e aprende golpes. Retorna mensagens para o log.
function ProgressionService.AddXp(player: Player, uid: string, amount: number)
	local data = PlayerDataService.Get(player)
	local m = data and data.Collection[uid]
	if not m or amount <= 0 then
		return {}
	end
	local def = Characters.Get(m.CharacterId)
	local lines = {}
	if m.Level >= Progression.MaxLevel then
		return lines
	end
	m.Xp += math.floor(amount)
	table.insert(lines, def.Name .. " ganhou " .. math.floor(amount) .. " de XP.")
	while m.Level < Progression.MaxLevel and m.Xp >= Progression.XpToNext(m.Level) do
		m.Xp -= Progression.XpToNext(m.Level)
		m.Level += 1
		table.insert(lines, def.Name .. " subiu para o n\u{ed}vel " .. m.Level .. "!")
		for _, moveId in ipairs(Characters.NewMovesAt(m.CharacterId, m.Level)) do
			if not table.find(m.Learned, moveId) then
				table.insert(m.Learned, moveId)
				local moveName = Moves.Get(moveId).Name
				if #m.Active < Progression.MaxActiveMoves then
					table.insert(m.Active, moveId)
					table.insert(lines, def.Name .. " aprendeu " .. moveName .. "!")
				else
					table.insert(lines, def.Name .. " aprendeu " .. moveName .. ". Troque os golpes no menu Time.")
				end
			end
		end
	end
	if m.Level >= Progression.MaxLevel then
		m.Xp = 0
	end
	return lines
end

-- Escolha dos 4 golpes ativos (1 a 4, sem repetir, so golpes aprendidos)
function ProgressionService.SetActiveMoves(player: Player, uid: string, list): (boolean, string?)
	local data = PlayerDataService.Get(player)
	local m = data and typeof(uid) == "string" and data.Collection[uid]
	if not m then
		return false, "Personagem n\u{e3}o encontrado."
	end
	if typeof(list) ~= "table" or #list < 1 or #list > Progression.MaxActiveMoves then
		return false, "Escolha de 1 a 4 golpes."
	end
	local clean = {}
	for i = 1, #list do
		local id = list[i]
		if typeof(id) ~= "string" or not table.find(m.Learned, id) or table.find(clean, id) then
			return false, "Golpe inv\u{e1}lido."
		end
		table.insert(clean, id)
	end
	m.Active = clean
	PlayerDataService.MarkChanged(player)
	return true
end

function ProgressionService.ChooseStarter(player: Player, characterId): (boolean, string?)
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Dados ainda carregando."
	end
	if data.StarterChosen then
		return false, "Voc\u{ea} j\u{e1} escolheu seu personagem inicial."
	end
	if typeof(characterId) ~= "string" or not table.find(Characters.Starters(), characterId) then
		return false, "Personagem inicial inv\u{e1}lido."
	end
	ProgressionService.AddCharacter(player, characterId, Progression.StarterLevel, true)
	data.StarterChosen = true
	-- Kit inicial (gold + pocoes + selos, sem gemas) para evitar "vale seco" nos primeiros minutos
	local kit = Progression.StarterKit
	if kit then
		if kit.Gold and kit.Gold > 0 then
			data.Gold += kit.Gold
		end
		for itemId, qty in pairs(kit.Items or {}) do
			if qty > 0 then
				data.Bag[itemId] = math.min(99, (data.Bag[itemId] or 0) + qty)
			end
		end
	end
	-- Desbloqueia automaticamente o banner do anime do personagem inicial escolhido (Luffy/Naruto/Ichigo)
	local def = Characters.Get(characterId)
	if def and def.Anime and def.Anime ~= "Generico" then
		data.UnlockedBanners = data.UnlockedBanners or {}
		data.UnlockedBanners[def.Anime] = true
	end
	PlayerDataService.MarkChanged(player)
	task.spawn(PlayerDataService.SaveNow, player) -- evento importante: salva ja
	return true
end

-- Time salvo no formato do BattleService. nil se ainda nao tem time.
function ProgressionService.TeamFor(player: Player)
	local data = PlayerDataService.Get(player)
	if not data or #data.Team == 0 then
		return nil
	end
	local team = {}
	local anyAlive = false
	for _, uid in ipairs(data.Team) do
		local m = data.Collection[uid]
		if m then
			-- estrelas (+5% cada) e bonus da variante (GDD secoes 4 e 13); HP, status e PP salvos
			local hp = Progression.CurrentHp(m)
			if hp > 0 then
				anyAlive = true
			end
			table.insert(team, {
				CharacterId = m.CharacterId,
				Level = m.Level,
				Moves = table.clone(m.Active),
				Uid = uid,
				StatMultiplier = Progression.MemberMultiplier(m),
				StatMultipliers = Genetics.MultipliersFor(m.Genetics, m.Training),
				Genetics = m.Genetics,
				Training = m.Training,
				Hp = m.Hp,
				Status = m.Status,
				StatusTurns = m.StatusTurns,
				Pp = if m.Pp then table.clone(m.Pp) else nil,
			})
		end
	end
	if #team == 0 then
		return nil, "Escolha seu personagem inicial primeiro."
	end
	if not anyAlive then
		return nil, "Seu time est\u{e1} desmaiado. Cure no centro de cura ou use um Reviver."
	end
	return team
end

-- Mochila salva para a batalha (copia)
function ProgressionService.BagFor(player: Player)
	local data = PlayerDataService.Get(player)
	if not data then
		return nil
	end
	local bag = {}
	for id, n in pairs(data.Bag) do
		if typeof(n) == "number" and n > 0 then
			bag[id] = n
		end
	end
	return bag
end

-- Guarda no perfil o que mudou na batalha: mochila, HP, status e PP do time
function ProgressionService.WriteBack(player: Player, battle)
	local data = PlayerDataService.Get(player)
	if not data or not battle then
		return
	end
	if battle.Bag then
		local bag = {}
		for id, n in pairs(battle.Bag) do
			if n > 0 then
				bag[id] = n
			end
		end
		data.Bag = bag
	end
	for _, b in ipairs(battle.Sides.Player.Team) do
		local m = b.Uid and data.Collection[b.Uid]
		if m then
			m.Hp = if b.Hp >= b.MaxHp then nil else b.Hp
			m.Status = b.Status
			m.StatusTurns = if b.Status == "Sleep" then b.StatusTurns else nil
			local pp = nil
			for _, slot in ipairs(b.Moves) do
				if slot.Pp < slot.MaxPp then
					pp = pp or {}
					pp[slot.Id] = slot.Pp
				end
			end
			m.Pp = pp
		end
	end
end

-- Cura Automatica (secao 9): time curado apos cada batalha fora da torre
local function autoHeal(player: Player, battle, lines)
	local data = PlayerDataService.Get(player)
	if not data or battle.Mode == "Tower" or not Benefits.Has(data, "CuraAutomatica") then
		return
	end
	for _, uid in ipairs(data.Team) do
		local m = data.Collection[uid]
		if m then
			m.Hp = nil
			m.Status = nil
			m.StatusTurns = nil
			m.Pp = nil
		end
	end
	table.insert(lines, "Cura Autom\u{e1}tica: time curado.")
end

-- Fim da batalha: XP para quem entrou em campo, so na vitoria (Modo Treino nao altera perfil nem da XP)
function ProgressionService.OnBattleFinished(player: Player, battle, result: string)
	if battle and battle.Mode == "Practice" then
		return {}
	end
	ProgressionService.WriteBack(player, battle)
	PlayerDataService.MarkChanged(player)
	for _, fn in ipairs(ProgressionService.Listeners) do
		task.spawn(fn, player, battle, result)
	end
	if result ~= "Win" then
		local healed = {}
		autoHeal(player, battle, healed)
		PlayerDataService.MarkChanged(player)
		return healed
	end
	local data = PlayerDataService.Get(player)
	if not data then
		return {}
	end
	local levels = {}
	for _, e in ipairs(battle.Sides.Enemy.Team) do
		table.insert(levels, e.Level)
	end
	local xp = Progression.VictoryXp(levels, Benefits.Has(data, "XpEmDobro"))
	local lines = {}
	local eventMult = Retention.XpMultiplier(Clock.Now())
	if eventMult > 1 then
		xp = math.floor(xp * eventMult)
		table.insert(lines, "Evento de fim de semana: " .. Retention.EventNames.Xp .. ".")
	end
	local benchXp = math.floor(xp * (Progression.BenchXpRatio or 0.40) + 0.5)
	local benchLeveled = {}
	local benchCount = 0
	for _, b in ipairs(battle.Sides.Player.Team) do
		if b.Uid then
			if b.Participated then
				for _, line in ipairs(ProgressionService.AddXp(player, b.Uid, xp)) do
					table.insert(lines, line)
				end
			elseif (b.Hp or 0) > 0 and benchXp > 0 then
				local m = data.Collection[b.Uid]
				if m and m.Level < Progression.MaxLevel then
					benchCount += 1
					local subLines = ProgressionService.AddXp(player, b.Uid, benchXp)
					-- Mostra subidas de nivel/golpes novos do banco sem poluir com 5 linhas de "+X XP"
					for i = 2, #subLines do
						table.insert(benchLeveled, subLines[i])
					end
				end
			end
		end
	end
	if benchCount > 0 then
		table.insert(lines, string.format("Banco vivo ganhou +%d XP compartilhado (%d).", benchXp, benchCount))
		for _, line in ipairs(benchLeveled) do
			table.insert(lines, line)
		end
	end
	autoHeal(player, battle, lines)
	PlayerDataService.MarkChanged(player)
	return lines
end

function ProgressionService.Init(BattleService)
	Remotes.GetProfile.OnServerInvoke = function(player)
		return PlayerDataService.WaitFor(player, 20)
	end
	Remotes.ChooseStarter.OnServerInvoke = function(player, characterId)
		if throttled(player) then
			return false, "Aguarde."
		end
		return ProgressionService.ChooseStarter(player, characterId)
	end
	Remotes.SetActiveMoves.OnServerInvoke = function(player, uid, list)
		if throttled(player) then
			return false, "Aguarde."
		end
		if BattleService.IsInBattle(player) then
			return false, "N\u{e3}o d\u{e1} para trocar golpes durante a batalha."
		end
		return ProgressionService.SetActiveMoves(player, uid, list)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastCall[player] = nil
	end)
	-- perfis antigos: album recebe o que ja esta na colecao
	PlayerDataService.Loaded:Connect(function(player)
		-- BindableEvent copia tabelas: usa o perfil vivo
		local data = PlayerDataService.Get(player)
		if data and #AlbumService.Backfill(data) > 0 then
			PlayerDataService.MarkChanged(player)
		end
	end)
	BattleService.SetHooks({
		TeamFor = ProgressionService.TeamFor,
		BagFor = ProgressionService.BagFor,
		OnFinished = ProgressionService.OnBattleFinished,
		OnCancelled = function(player, battle)
			ProgressionService.WriteBack(player, battle)
			PlayerDataService.MarkChanged(player)
		end,
	})
end

return ProgressionService
