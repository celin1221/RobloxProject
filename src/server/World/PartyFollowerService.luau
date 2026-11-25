--[[
	PartyFollowerService
	Faz o primeiro personagem com vida positiva (HP > 0) da party (data.Team)
	acompanhar o jogador pelo mundo (praca, esteira, base e Refugio).
	- Se o 1o do time desmaiar (HP = 0), assume automaticamente o proximo com HP > 0.
	- Se todos estiverem desmaiados ou o jogador estiver em batalha (Arena), o acompanhante fica oculto.
	- O movimento liso a 60 FPS e a alternancia entre as animacoes Walk e Idle rodam no cliente
	  (NpcWalkClient + BaseClient); o servidor gerencia qual boneco esta ativo e sincroniza a posicao
	  base para o StreamingEnabled.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")

local Data = ReplicatedStorage:WaitForChild("Data")
local Characters = require(Data:WaitForChild("Characters"))
local Progression = require(Data:WaitForChild("Progression"))
local VariantController = require(ReplicatedStorage:WaitForChild("VariantController"))

local PlayerDataService = require(ServerScriptService:WaitForChild("Data"):WaitForChild("PlayerDataService"))
local CharacterLibrary = require(ServerScriptService:WaitForChild("CharacterLibrary"))
local BattleService = require(ServerScriptService:WaitForChild("Battle"):WaitForChild("BattleService"))

local PartyFollowerService = {}

local FOLLOW_OFFSET = CFrame.new(2.4, 0, 4.2)
local FOLLOWER_GROUP = "PartyFollower"
local followers = {} -- [Player] = { Model: Model, Key: string, Uid: string }

local function ensureCollisionGroup()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(FOLLOWER_GROUP)
		for _, info in ipairs(PhysicsService:GetRegisteredCollisionGroups()) do
			PhysicsService:CollisionGroupSetCollidable(FOLLOWER_GROUP, info.name, false)
		end
	end)
end

local function makePartIntangible(inst: Instance)
	if inst:IsA("BasePart") then
		inst.CanCollide = false
		inst.CanQuery = false
		inst.CanTouch = false
		inst.Massless = true
		inst.CollisionGroup = FOLLOWER_GROUP
	end
end

local function makeModelIntangible(model: Model)
	ensureCollisionGroup()
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		-- Desativa o state machine para o Humanoid nao reativar CanCollide nos membros a cada tick
		hum.EvaluateStateMachine = false
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	for _, d in ipairs(model:GetDescendants()) do
		makePartIntangible(d)
	end
	model.DescendantAdded:Connect(function(d)
		makePartIntangible(d)
		if d:IsA("Humanoid") then
			d.EvaluateStateMachine = false
			d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			d.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		end
	end)
end

local function container(): Folder
	local f = workspace:FindFirstChild("PartyFollowers")
	if not f then
		f = Instance.new("Folder")
		f.Name = "PartyFollowers"
		f.Parent = workspace
	end
	return f
end

-- Retorna (uid, member, def) do primeiro personagem da party com HP > 0
function PartyFollowerService.FirstAliveInParty(data)
	if not data or not data.StarterChosen or typeof(data.Team) ~= "table" or typeof(data.Collection) ~= "table" then
		return nil, nil, nil
	end
	for _, uid in ipairs(data.Team) do
		local m = data.Collection[uid]
		local def = m and Characters.Get(m.CharacterId)
		if m and def then
			local curHp = Progression.CurrentHp(m)
			if curHp > 0 then
				return uid, m, def
			end
		end
	end
	return nil, nil, nil
end

local function computeStandCFrame(ownerChar: Model, followerModel: Model): CFrame?
	local ownerRoot = ownerChar:FindFirstChild("HumanoidRootPart")
	local ownerHum = ownerChar:FindFirstChildOfClass("Humanoid")
	local root = followerModel:FindFirstChild("HumanoidRootPart")
	local hum = followerModel:FindFirstChildOfClass("Humanoid")
	if not ownerRoot or not root then
		return nil
	end
	local ownerLegs = if ownerHum and ownerHum.RigType == Enum.HumanoidRigType.R6 then 2 else (ownerHum and ownerHum.HipHeight or 2)
	local floorY = ownerRoot.Position.Y - ownerRoot.Size.Y / 2 - ownerLegs
	local followerLegs = if hum and hum.RigType == Enum.HumanoidRigType.R6 then 2 else (hum and hum.HipHeight or 2.12)
	local y = floorY + followerLegs + root.Size.Y / 2

	local slotPos = (ownerRoot.CFrame * FOLLOW_OFFSET).Position
	local look = ownerRoot.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	flatLook = if flatLook.Magnitude > 0.01 then flatLook.Unit else Vector3.new(0, 0, -1)
	local pos = Vector3.new(slotPos.X, y, slotPos.Z)
	return CFrame.lookAt(pos, pos + flatLook)
end

local function clearFollower(player: Player)
	local entry = followers[player]
	if entry then
		followers[player] = nil
		if entry.Model and entry.Model.Parent then
			entry.Model:Destroy()
		end
	end
end

function PartyFollowerService.Refresh(player: Player)
	if not player or not player.Parent then
		clearFollower(player)
		return
	end
	if BattleService.IsInBattle(player) then
		clearFollower(player)
		return
	end
	local ownerChar = player.Character
	local ownerRoot = ownerChar and ownerChar:FindFirstChild("HumanoidRootPart")
	local ownerHum = ownerChar and ownerChar:FindFirstChildOfClass("Humanoid")
	if not ownerChar or not ownerRoot or not ownerHum or ownerHum.Health <= 0 then
		clearFollower(player)
		return
	end

	local data = PlayerDataService.Get(player)
	local uid, member, def = PartyFollowerService.FirstAliveInParty(data)
	if not uid or not member or not def then
		clearFollower(player)
		return
	end

	local key = def.ModelName .. "|" .. tostring(member.Variant or "") .. "|" .. tostring(member.Awakened == true)
	local current = followers[player]
	if current and current.Model and current.Model.Parent and current.Key == key then
		current.Uid = uid
		current.Model:SetAttribute("Uid", uid)
		current.Model:SetAttribute("Level", member.Level or 1)
		current.Model:SetAttribute("Awakened", member.Awakened == true)
		return
	end

	clearFollower(player)

	local model = CharacterLibrary.Spawn(def.ModelName, nil, nil)
	model.Name = "Follower_" .. player.Name
	if member.Variant then
		pcall(VariantController.Apply, model, member.CharacterId, member.Variant)
	end

	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = true
	end
	makeModelIntangible(model)

	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Uid", uid)
	model:SetAttribute("CharacterId", member.CharacterId)
	model:SetAttribute("Variant", member.Variant)
	model:SetAttribute("Awakened", member.Awakened == true)
	model:SetAttribute("Level", member.Level or 1)
	model:SetAttribute("Moving", false)

	local cf = computeStandCFrame(ownerChar, model)
	if cf then
		model:PivotTo(cf)
	end

	CollectionService:AddTag(model, "PartyFollower")
	model.Parent = container()
	followers[player] = {
		Model = model,
		Key = key,
		Uid = uid,
	}
end

function PartyFollowerService.GetModel(player: Player): Model?
	local entry = followers[player]
	return entry and entry.Model or nil
end

local function hookPlayer(player: Player)
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.2)
		if player.Parent then
			PartyFollowerService.Refresh(player)
		end
	end)
	if player.Character then
		task.spawn(PartyFollowerService.Refresh, player)
	end
end

function PartyFollowerService.Init()
	ensureCollisionGroup()
	container()
	PlayerDataService.Loaded:Connect(PartyFollowerService.Refresh)
	PlayerDataService.OnChanged(PartyFollowerService.Refresh)

	Players.PlayerAdded:Connect(hookPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		hookPlayer(p)
	end
	Players.PlayerRemoving:Connect(clearFollower)

	-- Loop leve para sincronizar estado de batalha e manter posicao base perto do dono (StreamingEnabled)
	task.spawn(function()
		while true do
			task.wait(0.4)
			for _, p in ipairs(Players:GetPlayers()) do
				PartyFollowerService.Refresh(p)
				local entry = followers[p]
				local ownerChar = p.Character
				if entry and entry.Model and entry.Model.Parent and ownerChar then
					local ownerRoot = ownerChar:FindFirstChild("HumanoidRootPart")
					local root = entry.Model:FindFirstChild("HumanoidRootPart")
					if ownerRoot and root and (ownerRoot.Position - root.Position).Magnitude > 45 then
						local cf = computeStandCFrame(ownerChar, entry.Model)
						if cf then
							root.CFrame = cf
						end
					end
				end
			end
		end
	end)
end

return PartyFollowerService
