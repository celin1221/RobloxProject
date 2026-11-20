--[[
	PvPService (GDD secao 5 - PvP)
	- Desafio por proximidade na praca: o cliente mostra "Desafiar" perto de outro jogador;
	  o servidor confere praca (raio 80 do centro), distancia, batalha, torre e time.
	- Aceite dos dois lados: quem desafia ja aceitou ao enviar; o desafiado aceita ou recusa (20 s).
	- Times: o time salvo de cada um, todos no nivel 50, HP/PP cheios e sem status (copias: o perfil nao muda).
	- A batalha em si (30 s por turno, itens desativados, Desistir, desconexao) e o BattleService.StartPvP.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Data = ReplicatedStorage:WaitForChild("Data")
local Progression = require(Data.Progression)
local Genetics = require(Data:WaitForChild("Genetics"))

local BattleService = require(script.Parent.BattleService)
local Config = require(script.Parent.BattleConfig)
local PlayerDataService = require(ServerScriptService:WaitForChild("Data"):WaitForChild("PlayerDataService"))
local TowerService = require(ServerScriptService:WaitForChild("Tower"):WaitForChild("TowerService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PvPService = {}

local invites = {} -- [desafiado] = { From = Player, Expires = os.clock() }
local sent = {} -- [quem desafiou] = desafiado
local lastCall = {}

local function notify(player: Player, text: string)
	Remotes.Notify:FireClient(player, text)
end

local function rootOf(player: Player): BasePart?
	local ch = player.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return nil
	end
	return ch:FindFirstChild("HumanoidRootPart")
end

local function inPlaza(player: Player): boolean
	local root = rootOf(player)
	if not root then
		return false
	end
	-- mapa v2: praca = retangulo dentro da esteira
	local p = root.Position
	return math.abs(p.X) <= Config.PlazaHalfX and math.abs(p.Z) <= Config.PlazaHalfZ and p.Y > -20 and p.Y < 60
end

-- Time do PvP: time salvo, nivel 50, cheio
function PvPService.TeamFor(player: Player)
	local data = PlayerDataService.Get(player)
	if not data or not data.StarterChosen or #data.Team == 0 then
		return nil
	end
	local team = {}
	for _, uid in ipairs(data.Team) do
		local m = data.Collection[uid]
		if m then
			table.insert(team, {
				CharacterId = m.CharacterId,
				Level = Config.PvPLevel,
				Moves = table.clone(m.Active),
				StatMultiplier = Progression.MemberMultiplier(m), -- estrelas e variante continuam
				StatMultipliers = Genetics.MultipliersFor(m.Genetics, m.Training),
				Genetics = m.Genetics,
				Training = m.Training,
			})
		end
	end
	return if #team > 0 then team else nil
end

-- Motivo para nao poder entrar em PvP (nil = pode)
local function blocker(player: Player, who: string): string?
	if not player.Parent then
		return who .. " saiu do jogo."
	end
	if BattleService.IsInBattle(player) or TowerService.IsRunning(player) then
		return who .. " est\u{e1} em batalha."
	end
	if not inPlaza(player) then
		return who .. " precisa estar na pra\u{e7}a."
	end
	if not PvPService.TeamFor(player) then
		return who .. " ainda n\u{e3}o tem time."
	end
	return nil
end

local function clearInvite(target: Player)
	local inv = invites[target]
	if inv then
		invites[target] = nil
		if sent[inv.From] == target then
			sent[inv.From] = nil
		end
	end
end

local function throttled(player: Player): boolean
	local t = os.clock()
	if lastCall[player] and t - lastCall[player] < 0.5 then
		return true
	end
	lastCall[player] = t
	return false
end

function PvPService.Challenge(player: Player, targetUserId)
	if throttled(player) then
		return false, "Aguarde."
	end
	local target = typeof(targetUserId) == "number" and Players:GetPlayerByUserId(targetUserId)
	if not target or target == player then
		return false, "Jogador inv\u{e1}lido."
	end
	local why = blocker(player, "Voc\u{ea}") or blocker(target, target.DisplayName)
	if why then
		return false, why
	end
	local a, b = rootOf(player), rootOf(target)
	if (a.Position - b.Position).Magnitude > Config.PvPChallengeDistance + 4 then
		return false, "Chegue mais perto de " .. target.DisplayName .. "."
	end
	if invites[target] and os.clock() < invites[target].Expires then
		return false, target.DisplayName .. " j\u{e1} tem um desafio pendente."
	end
	if sent[player] then
		clearInvite(sent[player])
	end
	if invites[player] and invites[player].From == target then
		-- os dois se desafiaram: vale como aceite
		return PvPService.Respond(player, target.UserId, true)
	end
	invites[target] = { From = player, Expires = os.clock() + Config.PvPInviteTime }
	sent[player] = target
	Remotes.PvPInvite:FireClient(target, { Kind = "Incoming", FromUserId = player.UserId, FromName = player.DisplayName, Seconds = Config.PvPInviteTime })
	Remotes.PvPInvite:FireClient(player, { Kind = "Sent", ToUserId = target.UserId, ToName = target.DisplayName, Seconds = Config.PvPInviteTime })
	local inv = invites[target]
	task.delay(Config.PvPInviteTime, function()
		if invites[target] == inv then
			clearInvite(target)
			if player.Parent then
				Remotes.PvPInvite:FireClient(player, { Kind = "Closed", Text = target.DisplayName .. " n\u{e3}o respondeu." })
			end
			if target.Parent then
				Remotes.PvPInvite:FireClient(target, { Kind = "Closed" })
			end
		end
	end)
	return true, "Desafio enviado para " .. target.DisplayName .. "."
end

function PvPService.Respond(player: Player, challengerUserId, accept)
	local inv = invites[player]
	if not inv or inv.From.UserId ~= challengerUserId or os.clock() > inv.Expires then
		clearInvite(player)
		return false, "Esse desafio n\u{e3}o vale mais."
	end
	local challenger = inv.From
	clearInvite(player)
	if accept ~= true then
		if challenger.Parent then
			Remotes.PvPInvite:FireClient(challenger, { Kind = "Closed", Text = player.DisplayName .. " recusou o desafio." })
		end
		return true, "Desafio recusado."
	end
	-- aceite dos dois lados: confere tudo de novo
	local why = blocker(challenger, challenger.DisplayName) or blocker(player, "Voc\u{ea}")
	if why then
		if challenger.Parent then
			Remotes.PvPInvite:FireClient(challenger, { Kind = "Closed", Text = "PvP cancelado: " .. why })
		end
		return false, why
	end
	local ok, err = BattleService.StartPvP(challenger, player, PvPService.TeamFor(challenger), PvPService.TeamFor(player), function(winnerSide, reason)
		local winner = if winnerSide == "Player" then challenger elseif winnerSide == "Enemy" then player else nil
		if winner then
			print("[PvP] " .. challenger.Name .. " x " .. player.Name .. ": venceu " .. winner.Name .. " (" .. tostring(reason) .. ")")
		end
	end)
	if not ok then
		if challenger.Parent then
			Remotes.PvPInvite:FireClient(challenger, { Kind = "Closed", Text = "PvP cancelado: " .. tostring(err) })
		end
		return false, err
	end
	if challenger.Parent then
		Remotes.PvPInvite:FireClient(challenger, { Kind = "Closed" })
	end
	return true
end

function PvPService.Cancel(player: Player)
	local target = sent[player]
	if not target then
		return false, "Nenhum desafio enviado."
	end
	clearInvite(target)
	if target.Parent then
		Remotes.PvPInvite:FireClient(target, { Kind = "Closed", Text = player.DisplayName .. " cancelou o desafio." })
	end
	return true, "Desafio cancelado."
end

local function guarded(fn)
	return function(player, ...)
		local ok, a, b = pcall(fn, player, ...)
		if not ok then
			warn("[PvP] " .. tostring(a))
			return false, "Erro no servidor."
		end
		return a, b
	end
end

function PvPService.Init()
	Remotes.PvPChallenge.OnServerInvoke = guarded(PvPService.Challenge)
	Remotes.PvPRespond.OnServerInvoke = guarded(PvPService.Respond)
	Remotes.PvPCancel.OnServerInvoke = guarded(PvPService.Cancel)
	Players.PlayerRemoving:Connect(function(player)
		if sent[player] then
			local target = sent[player]
			clearInvite(target)
			if target.Parent then
				Remotes.PvPInvite:FireClient(target, { Kind = "Closed" })
			end
		end
		local inv = invites[player]
		if inv then
			clearInvite(player)
			if inv.From.Parent then
				Remotes.PvPInvite:FireClient(inv.From, { Kind = "Closed", Text = player.DisplayName .. " saiu do jogo." })
			end
		end
		lastCall[player] = nil
	end)
end

return PvPService
