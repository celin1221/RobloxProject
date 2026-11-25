--!strict
--[[
	ServerScriptService/HollowPurpleServer.server.luau
	Servidor autoritativo do sistema "Vazio Roxo" (Hollow Purple - Gojo Satoru / Setero):
	  - Cria/gerencia ReplicatedStorage/HollowPurpleRemote
	  - Valida cooldown, estado vivo e protege sistemas de turnos/NPCs do mapa
	  - Orienta/trava suavemente o personagem durante a conjuracao (se configurado)
	  - Executa hitboxes seguras com workspace:Spherecast (paredes) e workspace:GetPartBoundsInRadius (alvos),
	    NUNCA usando .Touched
	  - Aplica dano continuo + explosao final e knockback via LinearVelocity em Dummies/inimigos validos
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local HollowPurpleFolder = ReplicatedStorage:WaitForChild("HollowPurple")
local Config = require(HollowPurpleFolder:WaitForChild("Config"))

-- Garante a existencia da pasta de VFX e do RemoteEvent
local vfxContainer = workspace:FindFirstChild(Config.WorkspaceFolderName)
if not vfxContainer then
	local f = Instance.new("Folder")
	f.Name = Config.WorkspaceFolderName
	f.Parent = workspace
	vfxContainer = f
end

local remote = ReplicatedStorage:FindFirstChild(Config.RemoteName) :: RemoteEvent?
if not remote or not remote:IsA("RemoteEvent") then
	local r = Instance.new("RemoteEvent")
	r.Name = Config.RemoteName
	r.Parent = ReplicatedStorage
	remote = r
end
local hollowRemote = remote :: RemoteEvent

local lastCastByUserId: { [number]: number } = {}
local activeCastByUserId: { [number]: boolean } = {}
local castSerial = 0

-- Pastas protegidas do RPG que nao devem tomar dano nem knockback do teste livre (tecla R)
local PROTECTED_ANCESTOR_NAMES = {
	PartyFollowers = true,
	BaseCharacters = true,
	Plots = true,
	Bases = true,
	SummonShowcaseModels = true,
	Arenas = true,
	Map = true,
}

local function isProtectedModel(model: Model): boolean
	if CollectionService:HasTag(model, "HollowPurpleTarget") or model.Name:find("Dummy") ~= nil or model.Name:find("Rig") ~= nil then
		return false
	end
	local cur: Instance? = model.Parent
	while cur and cur ~= workspace do
		if PROTECTED_ANCESTOR_NAMES[cur.Name] then
			return true
		end
		if cur.Name:match("^Arena%d+") or cur.Name:match("^Plot%d+") then
			return true
		end
		cur = cur.Parent
	end
	return false
end

local function isValidDamageTarget(casterModel: Model, candidateModel: Model): boolean
	if candidateModel == casterModel then
		return false
	end
	local hum = candidateModel:FindFirstChildOfClass("Humanoid")
	local hrp = candidateModel:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not hrp or hum.Health <= 0 then
		return false
	end
	local targetPlayer = Players:GetPlayerFromCharacter(candidateModel)
	if targetPlayer and not Config.AllowPvPFreeRoam then
		return false
	end
	if isProtectedModel(candidateModel) then
		return false
	end
	return true
end

local function buildWallRaycastParams(casterModel: Model): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true

	local ignore: { Instance } = { casterModel }
	local vf = workspace:FindFirstChild(Config.WorkspaceFolderName)
	if vf then
		table.insert(ignore, vf)
	end
	local bvf = workspace:FindFirstChild("BattleVfx")
	if bvf then
		table.insert(ignore, bvf)
	end
	local pf = workspace:FindFirstChild("PartyFollowers")
	if pf then
		table.insert(ignore, pf)
	end
	for _, ch in ipairs(workspace:GetChildren()) do
		if ch:IsA("Model") and ch:FindFirstChildOfClass("Humanoid") then
			table.insert(ignore, ch)
		end
	end
	params.FilterDescendantsInstances = ignore
	return params
end

local function buildHitboxOverlapParams(casterModel: Model): OverlapParams
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { casterModel }
	local vf = workspace:FindFirstChild(Config.WorkspaceFolderName)
	if vf then
		table.insert(ignore, vf)
	end
	local pf = workspace:FindFirstChild("PartyFollowers")
	if pf then
		table.insert(ignore, pf)
	end
	params.FilterDescendantsInstances = ignore
	return params
end

local function applyKnockback(targetHrp: BasePart, velocity: Vector3)
	if targetHrp.Anchored then
		return
	end
	-- Limpa eventual LinearVelocity anterior do Vazio Roxo
	local prevAtt = targetHrp:FindFirstChild("HP_KnockbackAtt")
	if prevAtt then
		prevAtt:Destroy()
	end

	local att = Instance.new("Attachment")
	att.Name = "HP_KnockbackAtt"
	att.Parent = targetHrp

	local lv = Instance.new("LinearVelocity")
	lv.Name = "HP_KnockbackVel"
	lv.Attachment0 = att
	lv.MaxForce = 180000.0
	lv.VectorVelocity = velocity
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = att

	Debris:AddItem(att, 0.22)
end

local function sanitizeAimDirection(rawDir: any, fallbackCF: CFrame): Vector3
	if typeof(rawDir) ~= "Vector3" then
		return fallbackCF.LookVector
	end
	local v = rawDir :: Vector3
	if v.X ~= v.X or v.Y ~= v.Y or v.Z ~= v.Z or v.Magnitude < 0.001 then
		return fallbackCF.LookVector
	end
	return v.Unit
end

local function executeServerCast(player: Player, initialAim: Vector3)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and (char:FindFirstChild("HumanoidRootPart") :: BasePart?)
	if not char or not hum or not hrp or hum.Health <= 0 then
		return
	end

	local userId = player.UserId
	local now = os.clock()
	local prev = lastCastByUserId[userId] or -999.0
	if (now - prev) < Config.Cooldown or activeCastByUserId[userId] then
		return
	end

	lastCastByUserId[userId] = now
	activeCastByUserId[userId] = true

	castSerial += 1
	local castId = string.format("U%d_%d", userId, castSerial)
	local aimDir = sanitizeAimDirection(initialAim, hrp.CFrame)

	-- Salva e reduz movimento durante a conjuracao (0.00s -> 4.15s)
	local origWalkSpeed = hum.WalkSpeed
	local origAutoRotate = hum.AutoRotate
	local windupRestored = false

	local function restoreCasterMobility()
		if windupRestored then
			return
		end
		windupRestored = true
		if hum.Parent and hum.Health > 0 then
			hum.WalkSpeed = origWalkSpeed
			hum.AutoRotate = origAutoRotate
		end
	end

	if Config.LockCasterDuringWindup then
		hum.WalkSpeed = Config.WindupWalkSpeed
		if Config.OrientCasterToAim then
			hum.AutoRotate = false
			local flatLook = Vector3.new(aimDir.X, 0, aimDir.Z)
			if flatLook.Magnitude > 0.01 and not hrp.Anchored then
				hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + flatLook.Unit)
			end
		end
	end

	-- Notifica imediatamente todos os clientes para iniciar as Fases 1-3
	hollowRemote:FireAllClients("StartCast", {
		CastId = castId,
		CasterModel = char,
		AimDir = aimDir,
	})

	-- Aguarda o instante exato do Disparo (Fase 4: 4.15s)
	task.delay(Config.Timing.Phase4LaunchTime, function()
		restoreCasterMobility()

		if not char.Parent or not hrp.Parent or hum.Health <= 0 then
			activeCastByUserId[userId] = false
			return
		end

		local flatAim = Vector3.new(aimDir.X, 0, aimDir.Z)
		local baseCF = if flatAim.Magnitude > 0.01
			then CFrame.lookAt(hrp.Position, hrp.Position + flatAim.Unit)
			else hrp.CFrame
		local launchOrigin = (baseCF * Config.Offsets.ConvergenceLocal).Position
		local launchDir = aimDir.Unit

		-- Determina alcance maximo ate parede solida indestrutivel via Spherecast (ignorando personagens)
		local wallParams = buildWallRaycastParams(char)
		local wallHit = workspace:Spherecast(
			launchOrigin,
			Config.Combat.WallSpherecastRadius,
			launchDir * Config.Combat.MaxRange,
			wallParams
		)
		local maxTravelDist = Config.Combat.MaxRange
		if wallHit and wallHit.Instance and wallHit.Instance.CanCollide then
			maxTravelDist = math.max(8.0, wallHit.Distance)
		end

		-- Sincroniza origem, direcao e alcance autoritativos com todos os clientes
		hollowRemote:FireAllClients("LaunchSync", {
			CastId = castId,
			LaunchOrigin = launchOrigin,
			LaunchDir = launchDir,
			MaxTravelDist = maxTravelDist,
		})

		-- Loop de hitbox seguro com GetPartBoundsInRadius (NUNCA .Touched!)
		local overlapParams = buildHitboxOverlapParams(char)
		local lastHitPerModel: { [Model]: number } = {}
		local flightElapsed = 0.0
		local hitConn: RBXScriptConnection? = nil

		local function damageModelsInSphere(center: Vector3, radius: number, damage: number, kbHoriz: number, kbVert: number, ignoreCooldown: boolean)
			local parts = workspace:GetPartBoundsInRadius(center, radius, overlapParams)
			local seenThisStep: { [Model]: boolean } = {}
			local stepClock = os.clock()

			for _, part in ipairs(parts) do
				local m = part:FindFirstAncestorOfClass("Model")
				if m and not seenThisStep[m] then
					seenThisStep[m] = true
					if isValidDamageTarget(char, m) then
						local lastHit = lastHitPerModel[m] or 0.0
						if ignoreCooldown or (stepClock - lastHit) >= Config.Combat.HitTickCooldownPerTarget then
							lastHitPerModel[m] = stepClock
							local targetHum = m:FindFirstChildOfClass("Humanoid")
							local targetHrp = m:FindFirstChild("HumanoidRootPart") :: BasePart?
							if targetHum and targetHrp and targetHum.Health > 0 then
								targetHum:TakeDamage(damage)
								local pushDir = (targetHrp.Position - center)
								local horiz = Vector3.new(pushDir.X, 0, pushDir.Z)
								local kbUnit = if horiz.Magnitude > 0.1 then (horiz.Unit * 0.55 + launchDir * 0.45).Unit else launchDir
								applyKnockback(targetHrp, kbUnit * kbHoriz + Vector3.new(0, kbVert, 0))
								hollowRemote:FireAllClients("HitTarget", {
									CastId = castId,
									HitPos = targetHrp.Position,
								})
							end
						end
					end
				end
			end
		end

		hitConn = RunService.Heartbeat:Connect(function(dt: number)
			flightElapsed += math.min(dt, 0.05)
			local traveled = Config.Combat.ProjectileSpeed * flightElapsed
			local alpha = math.clamp(traveled / math.max(1.0, maxTravelDist), 0, 1)
			local curPos = launchOrigin + launchDir * math.min(traveled, maxTravelDist)
			local curRadius = Config.Scales.ProjectileStartRadius
				+ (Config.Scales.ProjectileEndRadius - Config.Scales.ProjectileStartRadius) * math.sqrt(alpha)
				+ Config.Combat.HitboxRadiusPadding

			damageModelsInSphere(
				curPos,
				curRadius,
				Config.Combat.TickDamage,
				Config.Combat.KnockbackHorizontal,
				Config.Combat.KnockbackVertical,
				false
			)

			if traveled >= maxTravelDist or flightElapsed >= Config.Timing.Phase4MaxFlight then
				if hitConn and hitConn.Connected then
					hitConn:Disconnect()
				end
				-- Apos a implosao de 0.12s, aplica o impacto massivo da Detonacao Final (Fase 5)
				task.delay(Config.Timing.Phase5ImplodeDuration, function()
					damageModelsInSphere(
						curPos,
						Config.Combat.FinalExplosionHitRadius,
						Config.Combat.FinalExplosionDamage,
						Config.Combat.FinalKnockbackHorizontal,
						Config.Combat.FinalKnockbackVertical,
						true
					)
					activeCastByUserId[userId] = false
				end)
			end
		end)
	end)
end

hollowRemote.OnServerEvent:Connect(function(player: Player, action: any, payload: any)
	if action == "CastRequest" then
		local char = player.Character
		local hrp = char and (char:FindFirstChild("HumanoidRootPart") :: BasePart?)
		if not hrp then
			return
		end
		local aimDir = sanitizeAimDirection(payload, hrp.CFrame)
		executeServerCast(player, aimDir)
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastCastByUserId[player.UserId] = nil
	activeCastByUserId[player.UserId] = nil
end)

--------------------------------------------------------------------
-- Dummy de Teste Automatico no Studio (pronto para testar em 10s!)
--------------------------------------------------------------------
if RunService:IsStudio() and Config.SpawnStudioTestDummy then
	local DUMMY_HOME = CFrame.new(0, 11.5, 42)

	local function spawnTestDummy()
		local existing = workspace:FindFirstChild("HollowPurpleDummy")
		if existing then
			existing:Destroy()
		end

		local dummy = Instance.new("Model")
		dummy.Name = "HollowPurpleDummy"
		CollectionService:AddTag(dummy, "HollowPurpleTarget")

		local hrp = Instance.new("Part")
		hrp.Name = "HumanoidRootPart"
		hrp.Size = Vector3.new(2, 2, 1)
		hrp.Transparency = 1
		hrp.CanCollide = false
		hrp.CFrame = DUMMY_HOME
		hrp.Parent = dummy
		dummy.PrimaryPart = hrp

		local torso = Instance.new("Part")
		torso.Name = "UpperTorso"
		torso.Size = Vector3.new(2.0, 2.0, 1.0)
		torso.Color = Color3.fromRGB(58, 62, 82)
		torso.Material = Enum.Material.SmoothPlastic
		torso.CFrame = DUMMY_HOME
		torso.Parent = dummy

		local head = Instance.new("Part")
		head.Name = "Head"
		head.Size = Vector3.new(1.2, 1.2, 1.2)
		head.Color = Color3.fromRGB(235, 205, 178)
		head.Material = Enum.Material.SmoothPlastic
		head.CFrame = DUMMY_HOME * CFrame.new(0, 1.65, 0)
		head.Parent = dummy

		local lLeg = Instance.new("Part")
		lLeg.Name = "LeftLeg"
		lLeg.Size = Vector3.new(0.95, 2.0, 0.95)
		lLeg.Color = Color3.fromRGB(36, 40, 56)
		lLeg.CFrame = DUMMY_HOME * CFrame.new(-0.52, -2.0, 0)
		lLeg.Parent = dummy

		local rLeg = Instance.new("Part")
		rLeg.Name = "RightLeg"
		rLeg.Size = Vector3.new(0.95, 2.0, 0.95)
		rLeg.Color = Color3.fromRGB(36, 40, 56)
		rLeg.CFrame = DUMMY_HOME * CFrame.new(0.52, -2.0, 0)
		rLeg.Parent = dummy

		local lArm = Instance.new("Part")
		lArm.Name = "LeftArm"
		lArm.Size = Vector3.new(0.9, 2.0, 0.9)
		lArm.Color = Color3.fromRGB(235, 205, 178)
		lArm.CFrame = DUMMY_HOME * CFrame.new(-1.5, 0, 0)
		lArm.Parent = dummy

		local rArm = Instance.new("Part")
		rArm.Name = "RightArm"
		rArm.Size = Vector3.new(0.9, 2.0, 0.9)
		rArm.Color = Color3.fromRGB(235, 205, 178)
		rArm.CFrame = DUMMY_HOME * CFrame.new(1.5, 0, 0)
		rArm.Parent = dummy

		for _, part in ipairs({ torso, head, lLeg, rLeg, lArm, rArm }) do
			local wc = Instance.new("WeldConstraint")
			wc.Part0 = hrp
			wc.Part1 = part
			wc.Parent = part
		end

		local hum = Instance.new("Humanoid")
		hum.MaxHealth = 500
		hum.Health = 500
		hum.DisplayName = "Alvo Vazio Roxo [R]"
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		hum.Parent = dummy

		dummy.Parent = workspace

		-- Respawn automatico 4s apos ser derrotado ou cair do mapa
		hum.Died:Connect(function()
			task.delay(4.0, function()
				spawnTestDummy()
			end)
		end)
	end

	task.defer(spawnTestDummy)
end
