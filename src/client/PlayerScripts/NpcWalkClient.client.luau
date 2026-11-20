--[[
	NpcWalkClient (cliente) - movimento liso a 60 FPS:
	  1. Personagens das bases (tag BaseCharacter) e selvagens do Refugio (tag RefugeWild):
	     interpola os atributos WalkFrom, WalkTo, WalkT0, WalkDur no relogio do servidor.
	  2. Acompanhante da party (tag PartyFollower):
	     segue o jogador dono com histerese suave, ajuste de altura do piso e atributo Moving
	     para alternar automaticamente entre a animacao de andar (Walk) e a parada (Idle).
	So visual: nada aqui muda estado de jogo.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local MAX_DIST = 300 -- longe da camera nao precisa animar quadro a quadro
local FOLLOW_OFFSET = CFrame.new(2.4, 0, 4.2)

local active = {} -- [Model] = true enquanto anda (BaseCharacter / RefugeWild)
local followers = {} -- [Model] = estado local do acompanhante (PartyFollower)

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local watched = setmetatable({}, { __mode = "k" })

local function watchNpc(m: Instance)
	if not m:IsA("Model") then
		return
	end
	local function update()
		if m:GetAttribute("Moving") == true and m:GetAttribute("WalkT0") ~= nil then
			active[m] = true
		else
			active[m] = nil
		end
	end
	if not watched[m] then
		watched[m] = true
		m:GetAttributeChangedSignal("Moving"):Connect(update)
		m:GetAttributeChangedSignal("WalkT0"):Connect(update)
	end
	update()
end

for _, tag in ipairs({ "BaseCharacter", "RefugeWild" }) do
	for _, m in ipairs(CollectionService:GetTagged(tag)) do
		watchNpc(m)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(watchNpc)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(m)
		active[m] = nil
	end)
end

local function makeClientIntangible(inst: Instance)
	if inst:IsA("BasePart") then
		inst.CanCollide = false
		inst.CanQuery = false
		inst.CanTouch = false
		inst.Massless = true
	elseif inst:IsA("Humanoid") then
		inst.EvaluateStateMachine = false
	end
end

local function watchFollower(m: Instance)
	if not m:IsA("Model") then
		return
	end
	for _, d in ipairs(m:GetDescendants()) do
		makeClientIntangible(d)
	end
	m.DescendantAdded:Connect(makeClientIntangible)
	followers[m] = { initialized = false }
end

for _, m in ipairs(CollectionService:GetTagged("PartyFollower")) do
	watchFollower(m)
end
CollectionService:GetInstanceAddedSignal("PartyFollower"):Connect(watchFollower)
CollectionService:GetInstanceRemovedSignal("PartyFollower"):Connect(function(m)
	followers[m] = nil
end)

local function flatUnit(v: Vector3, fallback: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude > 0.005 then
		return f.Unit
	end
	return fallback
end

local function stepFollowers(dt: number, camPos: Vector3)
	for m, st in pairs(followers) do
		if not m.Parent then
			followers[m] = nil
			continue
		end
		local root = m:FindFirstChild("HumanoidRootPart")
		local hum = m:FindFirstChildOfClass("Humanoid")
		local ownerId = m:GetAttribute("OwnerUserId")
		local owner = ownerId and Players:GetPlayerByUserId(ownerId)
		local ownerChar = owner and owner.Character
		local ownerRoot = ownerChar and ownerChar:FindFirstChild("HumanoidRootPart")
		local ownerHum = ownerChar and ownerChar:FindFirstChildOfClass("Humanoid")
		if not root or not ownerRoot then
			continue
		end
		if (ownerRoot.Position - camPos).Magnitude > MAX_DIST then
			continue
		end

		local ownerLegs = if ownerHum and ownerHum.RigType == Enum.HumanoidRigType.R6 then 2 else (ownerHum and ownerHum.HipHeight or 2)
		local ownerFloorY = ownerRoot.Position.Y - ownerRoot.Size.Y / 2 - ownerLegs
		local ownerLook = flatUnit(ownerRoot.CFrame.LookVector, Vector3.new(0, 0, -1))
		local slotPos = (ownerRoot.CFrame * FOLLOW_OFFSET).Position

		if not st.initialized then
			st.initialized = true
			st.pos = Vector3.new(slotPos.X, 0, slotPos.Z)
			st.floorY = ownerFloorY
			st.look = ownerLook
			st.moving = false
			st.stopHold = 0
		end

		local deltaXZ = Vector3.new(slotPos.X - st.pos.X, 0, slotPos.Z - st.pos.Z)
		local dist = deltaXZ.Magnitude

		if dist > 34 then
			-- Teleporte (ida a base, Refugio ou retorno de batalha): acompanha na hora
			st.pos = Vector3.new(slotPos.X, 0, slotPos.Z)
			st.floorY = ownerFloorY
			st.look = ownerLook
			st.moving = false
			st.stopHold = 0
		elseif dist > 0.80 or (st.moving and dist > 0.24) then
			st.moving = true
			st.stopHold = 0.12
			local speed = math.clamp(16 + math.max(0, dist - 1.5) * 2.2, 14, 26)
			local step = math.min(dist, speed * dt)
			local moveDir = deltaXZ.Unit
			st.pos += moveDir * step
			local wantLook = if dist > 1.1 then moveDir else flatUnit(moveDir:Lerp(ownerLook, 0.5), ownerLook)
			st.look = flatUnit(st.look:Lerp(wantLook, math.min(1, dt * 12)), wantLook)
		else
			st.stopHold = math.max(0, (st.stopHold or 0) - dt)
			if st.stopHold <= 0 then
				st.moving = false
			end
			st.look = flatUnit(st.look:Lerp(ownerLook, math.min(1, dt * 8)), ownerLook)
		end

		-- Altura do piso sob o acompanhante (esteira, varanda da base, terreno do Refugio)
		local filter = { m, ownerChar }
		local pf = workspace:FindFirstChild("PartyFollowers")
		if pf then
			table.insert(filter, pf)
		end
		local bv = workspace:FindFirstChild("BattleVfx")
		if bv then
			table.insert(filter, bv)
		end
		rayParams.FilterDescendantsInstances = filter
		local hit = workspace:Raycast(Vector3.new(st.pos.X, ownerRoot.Position.Y + 3.5, st.pos.Z), Vector3.new(0, -10, 0), rayParams)
		local targetFloorY = ownerFloorY
		if hit and math.abs(hit.Position.Y - ownerFloorY) < 5 then
			targetFloorY = hit.Position.Y
		end
		st.floorY += (targetFloorY - st.floorY) * math.min(1, dt * 18)

		local followerLegs = if hum and hum.RigType == Enum.HumanoidRigType.R6 then 2 else (hum and hum.HipHeight or 2.12)
		local y = st.floorY + followerLegs + root.Size.Y / 2
		local p = Vector3.new(st.pos.X, y, st.pos.Z)
		root.CFrame = CFrame.lookAt(p, p + st.look)

		if m:GetAttribute("Moving") ~= st.moving then
			m:SetAttribute("Moving", st.moving)
		end
	end
end

RunService.RenderStepped:Connect(function(dt)
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero

	if next(active) ~= nil then
		local now = workspace:GetServerTimeNow()
		for m in pairs(active) do
			local root = m.Parent and m:FindFirstChild("HumanoidRootPart")
			local from, to = m:GetAttribute("WalkFrom"), m:GetAttribute("WalkTo")
			local t0, dur = m:GetAttribute("WalkT0"), m:GetAttribute("WalkDur")
			if not root or typeof(from) ~= "CFrame" or typeof(to) ~= "CFrame" or not t0 or not dur then
				active[m] = nil
			else
				local a = math.clamp((now - t0) / math.max(dur, 0.05), 0, 1)
				if (root.Position - camPos).Magnitude < MAX_DIST then
					root.CFrame = from:Lerp(to, a)
				end
				if a >= 1 then
					active[m] = nil
				end
			end
		end
	end

	if next(followers) ~= nil then
		stepFollowers(math.clamp(dt, 1 / 240, 0.1), camPos)
	end
end)
