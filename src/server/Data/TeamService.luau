--[[
	TeamService (GDD secao 10 - Time e Equipe)
	Toda mudanca do time vem pelo RemoteEvent SetTeam com a lista completa proposta (1 a 6 uids, na ordem).
	O servidor valida: personagem e do jogador, sem repetido, de 1 a 6, fora de batalha e de corrida da torre.
	Quem entra no time e estava na base (Passeando ou Minerando) sai da base, com aviso.
	Resposta pelo RemoteEvent TeamResult { Ok, Message, Team } (o time oficial); o perfil vai pelo ProfileUpdated.
	Limite: 1 pedido a cada 0,2 s e no maximo 10 a cada 5 s. O perfil e salvo 4 s depois da ultima mudanca.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataService = require(script.Parent.PlayerDataService)
local Characters = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("Characters"))

local TeamService = {}

local MAX_TEAM = 6
local MIN_INTERVAL = 0.2
local BURST, WINDOW = 10, 5
local SAVE_DELAY = 4

local calls = {} -- [Player] = { Last, Start, Count }
local savePending = {}

local function limited(player: Player): boolean
	local t = os.clock()
	local c = calls[player]
	if not c then
		calls[player] = { Last = t, Start = t, Count = 1 }
		return false
	end
	if t - c.Last < MIN_INTERVAL then
		return true
	end
	if t - c.Start > WINDOW then
		c.Start, c.Count = t, 0
	end
	if c.Count >= BURST then
		return true
	end
	c.Last = t
	c.Count += 1
	return false
end

local function scheduleSave(player: Player)
	if savePending[player] then
		return
	end
	savePending[player] = true
	task.delay(SAVE_DELAY, function()
		savePending[player] = nil
		if player.Parent then
			PlayerDataService.SaveNow(player)
		end
	end)
end

-- Lista limpa (so uids do jogador, sem repetir, 1 a 6) ou nil + motivo
function TeamService.Validate(data, list)
	if typeof(list) ~= "table" then
		return nil, "Pedido inv\u{e1}lido."
	end
	local n = 0
	for _ in pairs(list) do
		n += 1
		if n > MAX_TEAM then
			return nil, "O time tem no m\u{e1}ximo " .. MAX_TEAM .. " personagens."
		end
	end
	if n < 1 then
		return nil, "O time precisa de pelo menos 1 personagem."
	end
	if #list ~= n then
		return nil, "Pedido inv\u{e1}lido."
	end
	local clean, seen = {}, {}
	for i = 1, n do
		local uid = list[i]
		if typeof(uid) ~= "string" or not data.Collection[uid] then
			return nil, "Esse personagem n\u{e3}o \u{e9} seu."
		end
		if seen[uid] then
			return nil, "O mesmo personagem n\u{e3}o pode ocupar dois espa\u{e7}os."
		end
		seen[uid] = true
		clean[i] = uid
	end
	return clean
end

function TeamService.Apply(player: Player, list): (boolean, string?)
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Dados ainda carregando."
	end
	if not data.StarterChosen then
		return false, "Escolha seu personagem inicial primeiro."
	end
	local BattleService = require(ServerScriptService.Battle.BattleService)
	local TowerService = require(ServerScriptService.Tower.TowerService)
	if BattleService.IsInBattle(player) or TowerService.IsRunning(player) then
		return false, "N\u{e3}o d\u{e1} para mudar o time durante a batalha."
	end
	local clean, why = TeamService.Validate(data, list)
	if not clean then
		return false, why
	end
	-- quem entra no time sai da base
	local left = {}
	local BaseService = require(ServerScriptService.Economy.BaseService)
	for _, uid in ipairs(clean) do
		if not table.find(data.Team, uid) and data.Base and data.Base.Active[uid] then
			BaseService.SetState(player, uid, "None")
			local def = Characters.Get(data.Collection[uid].CharacterId)
			table.insert(left, def and def.Name or uid)
		end
	end
	data.Team = clean
	PlayerDataService.MarkChanged(player)
	scheduleSave(player)
	if #left > 0 then
		return true, table.concat(left, ", ") .. (if #left > 1 then " sa\u{ed}ram" else " saiu") .. " da base para entrar no time."
	end
	return true, nil
end

function TeamService.Init()
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	local setTeam = Remotes:FindFirstChild("SetTeam") or Instance.new("RemoteEvent")
	setTeam.Name = "SetTeam"
	setTeam.Parent = Remotes
	local result = Remotes:FindFirstChild("TeamResult") or Instance.new("RemoteEvent")
	result.Name = "TeamResult"
	result.Parent = Remotes

	setTeam.OnServerEvent:Connect(function(player, list)
		local ok, a, b
		if limited(player) then
			ok, a, b = true, false, "Aguarde um instante."
		else
			ok, a, b = pcall(TeamService.Apply, player, list)
			if not ok then
				warn("[Team] " .. tostring(a))
				a, b = false, "Erro no servidor."
			end
		end
		local data = PlayerDataService.Get(player)
		result:FireClient(player, { Ok = a == true, Message = b, Team = data and table.clone(data.Team) or {} })
	end)
	Players.PlayerRemoving:Connect(function(player)
		calls[player] = nil
		savePending[player] = nil
	end)
end

return TeamService
