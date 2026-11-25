--[[
	AwakeningService (Camada 3 - Server):
	- Gerencia o inventario de Materiais de Despertar (data.Materials).
	- Valida e executa o Despertar / Evolucao de Epicos Nv. 35+ no Altar Secreto da Floresta.
	- Conecta o ProximityPrompt `AwakeningPrompt` em `Workspace.Map.SecretAwakeningAltar`.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Data = ReplicatedStorage:WaitForChild("Data")
local Awakening = require(Data:WaitForChild("Awakening"))
local Characters = require(Data:WaitForChild("Characters"))
local Passives = require(Data:WaitForChild("Passives"))

local PlayerDataService = require(ServerScriptService:WaitForChild("Data"):WaitForChild("PlayerDataService"))
local AccountLevelService = require(ServerScriptService.Data:WaitForChild("AccountLevelService"))
local BattleService = require(ServerScriptService:WaitForChild("Battle"):WaitForChild("BattleService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local AwakeningService = {}

local busy = {}
local wiredPrompts = setmetatable({}, { __mode = "k" })

local function ensureRemotes()
	if not Remotes:FindFirstChild("AwakeningOpen") then
		local re = Instance.new("RemoteEvent")
		re.Name = "AwakeningOpen"
		re.Parent = Remotes
	end
	if not Remotes:FindFirstChild("AwakenCharacter") then
		local rf = Instance.new("RemoteFunction")
		rf.Name = "AwakenCharacter"
		rf.Parent = Remotes
	end
end

-- Adiciona um material de Despertar ao perfil (sem ocupar slots da mochila de batalha)
function AwakeningService.AddMaterial(data, materialId: string, qty: number): number
	if typeof(data) ~= "table" or not Awakening.GetMaterial(materialId) then
		return 0
	end
	local add = math.max(0, math.floor(tonumber(qty) or 0))
	if add <= 0 then
		return 0
	end
	data.Materials = Awakening.SanitizeMaterials(data.Materials)
	local have = data.Materials[materialId] or 0
	local room = math.max(0, Awakening.MaxMaterialStack - have)
	local given = math.min(add, room)
	if given > 0 then
		data.Materials[materialId] = have + given
	end
	return given
end

-- Executa o Despertar de um personagem Epico Nv. 35+ (validado 100% no servidor)
function AwakeningService.Awaken(player: Player, uid: any)
	if busy[player] then
		return false, "Aguarde um instante."
	end
	if typeof(uid) ~= "string" then
		return false, "Personagem inv\u{e1}lido."
	end
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Dados ainda carregando."
	end
	if BattleService.IsInBattle(player) then
		return false, "N\u{e3}o \u{e9} poss\u{ed}vel despertar durante uma batalha."
	end
	if data.TrainingMachine and data.TrainingMachine.Job and data.TrainingMachine.Job.Uid == uid then
		return false, "Retire o personagem da C\u{e1}psula de Treino antes de despertar."
	end

	local ok, reason = Awakening.CanAwaken(data, uid)
	if not ok then
		return false, reason or "Requisitos n\u{e3}o atendidos."
	end

	local member = data.Collection[uid]
	local recipe = Awakening.RecipeFor(member.CharacterId)
	local def = Characters.Get(member.CharacterId)
	if not member or not recipe or not def then
		return false, "Receita indispon\u{ed}vel."
	end

	busy[player] = true
	data.Gold -= recipe.Gold
	data.Materials = Awakening.SanitizeMaterials(data.Materials)
	for _, req in ipairs(recipe.Materials) do
		local nextQty = math.max(0, (data.Materials[req.Id] or 0) - req.Qty)
		data.Materials[req.Id] = if nextQty > 0 then nextQty else nil
	end
	member.Awakened = true

	-- Atualiza HP salvo se estava cheio para manter proporcao limpa
	if member.Hp ~= nil and member.Hp > 0 then
		member.Hp = nil -- despertar restaura o folego ao maximo
	end

	AccountLevelService.AddXp(player, 250, "Despertar Secreto", true)
	PlayerDataService.MarkChanged(player)
	task.spawn(PlayerDataService.SaveNow, player)
	busy[player] = nil

	local passive = Passives.Get(recipe.SecretPassive)
	local pName = if passive then passive.Name else recipe.SecretPassive
	return true, {
		Uid = uid,
		CharacterId = member.CharacterId,
		Name = def.Name,
		PassiveId = recipe.SecretPassive,
		PassiveName = pName,
		PassiveDesc = passive and passive.Description or "",
		Message = def.Name .. " despertou! Nova Passiva Secreta: " .. pName .. " (+10% Atributos)!",
	}
end

local function wirePrompt(inst: Instance)
	if not inst:IsA("ProximityPrompt") or inst.Name ~= "AwakeningPrompt" then
		return
	end
	if wiredPrompts[inst] then
		return
	end
	wiredPrompts[inst] = true
	inst.Triggered:Connect(function(player: Player)
		if not player or not player.Parent then
			return
		end
		if BattleService.IsInBattle(player) then
			return
		end
		local re = Remotes:FindFirstChild("AwakeningOpen")
		if re and re:IsA("RemoteEvent") then
			re:FireClient(player)
		end
	end)
end

local function scanAltar()
	local map = workspace:FindFirstChild("Map")
	local altar = map and map:FindFirstChild("SecretAwakeningAltar")
	if altar then
		for _, d in ipairs(altar:GetDescendants()) do
			wirePrompt(d)
		end
	end
end

function AwakeningService.Init()
	ensureRemotes()
	Remotes.AwakenCharacter.OnServerInvoke = function(player: Player, uid: any)
		local ok, a, b = pcall(AwakeningService.Awaken, player, uid)
		if not ok then
			warn("[AwakeningService] " .. tostring(a))
			return false, "Erro no servidor."
		end
		return a, b
	end

	scanAltar()
	local map = workspace:FindFirstChild("Map")
	if map then
		map.DescendantAdded:Connect(function(d)
			if d.Name == "AwakeningPrompt" then
				wirePrompt(d)
			end
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return AwakeningService
