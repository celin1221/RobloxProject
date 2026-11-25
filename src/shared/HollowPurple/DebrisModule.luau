--!strict
--[[
	ReplicatedStorage/HollowPurple/DebrisModule.luau
	Sistema procedural de destrocos, pedras levitando, rastro de chao rasgado (Ground Carving)
	e crateras circulares, copiando exatamente Color e Material do piso/terreno via Raycast.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(script.Parent:WaitForChild("Config"))
local Janitor = require(script.Parent:WaitForChild("Janitor"))

export type GroundSample = {
	Hit: boolean,
	Position: Vector3,
	Normal: Vector3,
	Color: Color3,
	Material: Enum.Material,
}

export type LevitateRingHandle = {
	BlastOutward: (origin: Vector3, forwardDir: Vector3) -> (),
}

local DebrisModule = {}

local rng = Random.new()

local function buildGroundRayParams(extraIgnore: { Instance }?): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true

	local ignore: { Instance } = {}
	local vfxFolder = workspace:FindFirstChild(Config.WorkspaceFolderName)
	if vfxFolder then
		table.insert(ignore, vfxFolder)
	end
	local battleVfx = workspace:FindFirstChild("BattleVfx")
	if battleVfx then
		table.insert(ignore, battleVfx)
	end
	local followers = workspace:FindFirstChild("PartyFollowers")
	if followers then
		table.insert(ignore, followers)
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			table.insert(ignore, plr.Character)
		end
	end
	if extraIgnore then
		for _, inst in ipairs(extraIgnore) do
			table.insert(ignore, inst)
		end
	end
	params.FilterDescendantsInstances = ignore
	return params
end

function DebrisModule.SampleGround(worldPos: Vector3, maxDepth: number?, extraIgnore: { Instance }?): GroundSample
	local depth = maxDepth or 32.0
	local params = buildGroundRayParams(extraIgnore)
	local origin = worldPos + Vector3.new(0, 4.5, 0)
	local result = workspace:Raycast(origin, Vector3.new(0, -(depth + 4.5), 0), params)

	if result and result.Instance then
		local col = Color3.fromRGB(115, 110, 105)
		local mat = result.Material
		if result.Instance:IsA("Terrain") then
			local ok, terrainCol = pcall(function()
				return workspace.Terrain:GetMaterialColor(mat)
			end)
			if ok and typeof(terrainCol) == "Color3" then
				col = terrainCol
			end
		elseif result.Instance:IsA("BasePart") then
			col = result.Instance.Color
			mat = result.Instance.Material
		end
		if mat == Enum.Material.Air or mat == Enum.Material.ForceField or mat == Enum.Material.Neon then
			mat = Enum.Material.Slate
		end
		return {
			Hit = true,
			Position = result.Position,
			Normal = result.Normal,
			Color = col,
			Material = mat,
		}
	end

	return {
		Hit = false,
		Position = worldPos - Vector3.new(0, 3.0, 0),
		Normal = Vector3.yAxis,
		Color = Color3.fromRGB(108, 102, 98),
		Material = Enum.Material.Slate,
	}
end

local function makeRockPart(
	parent: Instance,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	useWedge: boolean
): BasePart
	local p: BasePart
	if useWedge then
		local w = Instance.new("WedgePart")
		w.Parent = parent
		p = w
	else
		local b = Instance.new("Part")
		b.TopSurface = Enum.SurfaceType.Smooth
		b.BottomSurface = Enum.SurfaceType.Smooth
		b.Parent = parent
		p = b
	end
	p.Name = "DebrisRock"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Size = size
	p.Color = color
	p.Material = material
	return p
end

-- Fase 1: Pequenas pedras e poeira subindo lentamente abaixo da esfera Azul
function DebrisModule.SpawnSuctionPebbles(
	parent: Instance,
	sphereCenter: Vector3,
	count: number,
	duration: number,
	janitor: Janitor.JanitorInstance
)
	local sample = DebrisModule.SampleGround(sphereCenter, 24.0)
	if not sample.Hit then
		return
	end

	-- Poeira ascendente na cor do solo
	local dustAnchor = Instance.new("Part")
	dustAnchor.Name = "BlueGroundDust"
	dustAnchor.Anchored = true
	dustAnchor.CanCollide = false
	dustAnchor.CanQuery = false
	dustAnchor.CanTouch = false
	dustAnchor.CastShadow = false
	dustAnchor.Massless = true
	dustAnchor.Transparency = 1
	dustAnchor.Size = Vector3.new(4.5, 0.2, 4.5)
	dustAnchor.CFrame = CFrame.new(sample.Position + Vector3.new(0, 0.15, 0))
	dustAnchor.Parent = parent
	janitor:Add(dustAnchor)

	local pe = Instance.new("ParticleEmitter")
	pe.Texture = Config.ResolveTexture("Smoke")
	pe.Color = ColorSequence.new(sample.Color, Config.Colors.BlueLight)
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.6, 1.8),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe.Lifetime = NumberRange.new(0.55, 0.95)
	pe.Rate = 22
	pe.Speed = NumberRange.new(2.5, 6.0)
	pe.SpreadAngle = Vector2.new(24, 24)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.LightEmission = 0.25
	pe.Parent = dustAnchor

	janitor:Delay(math.max(0.1, duration - 0.2), function()
		pe.Enabled = false
	end)

	for _ = 1, count do
		local ang = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0.6, 4.2)
		local startPos = sample.Position + Vector3.new(math.cos(ang) * r, 0.1, math.sin(ang) * r)
		local sz = Vector3.new(
			rng:NextNumber(0.28, 0.72),
			rng:NextNumber(0.24, 0.62),
			rng:NextNumber(0.28, 0.72)
		)
		local rock = makeRockPart(parent, sz, sample.Color, sample.Material, rng:NextNumber() < 0.35)
		rock.CFrame = CFrame.new(startPos) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6))
		janitor:Add(rock)

		local riseDur = rng:NextNumber(duration * 0.65, duration)
		local targetPos = startPos:Lerp(sphereCenter, 0.78) + Vector3.new(0, rng:NextNumber(0.4, 1.4), 0)
		local tw = TweenService:Create(
			rock,
			TweenInfo.new(riseDur, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				CFrame = CFrame.new(targetPos) * CFrame.Angles(rng:NextNumber(0, 12), rng:NextNumber(0, 12), rng:NextNumber(0, 12)),
				Size = sz * 0.18,
				Transparency = 1,
			}
		)
		janitor:Add(tw)
		tw:Play()
	end
end

-- Fase 3 -> Fase 4: Anel de 16-24 pedras levitando em orbita lenta e explodindo para fora no Disparo!
function DebrisModule.SpawnLevitatingRing(
	parent: Instance,
	centerGetter: () -> Vector3,
	count: number,
	ringRadius: number,
	janitor: Janitor.JanitorInstance
): LevitateRingHandle
	local origin = centerGetter()
	local sample = DebrisModule.SampleGround(origin, 28.0)
	local groundY = sample.Position.Y

	type OrbitRock = {
		part: BasePart,
		baseAngle: number,
		radius: number,
		targetHeight: number,
		curPos: Vector3,
		vel: Vector3,
		rotAxis: Vector3,
		rotSpeed: number,
		rotAngle: number,
	}

	local rocks: { OrbitRock } = {}
	for i = 1, count do
		local baseAng = ((i - 1) / math.max(1, count)) * math.pi * 2 + rng:NextNumber(-0.14, 0.14)
		local r = ringRadius * rng:NextNumber(0.72, 1.25)
		local spawnPos = Vector3.new(origin.X + math.cos(baseAng) * r, groundY - 0.4, origin.Z + math.sin(baseAng) * r)
		local sz = Vector3.new(
			rng:NextNumber(0.75, 1.85),
			rng:NextNumber(0.55, 1.45),
			rng:NextNumber(0.75, 1.85)
		)
		local part = makeRockPart(parent, sz, sample.Color, sample.Material, i % 3 == 0)
		part.CFrame = CFrame.new(spawnPos)
		janitor:Add(part)

		local axisRaw = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
		table.insert(rocks, {
			part = part,
			baseAngle = baseAng,
			radius = r,
			targetHeight = rng:NextNumber(1.4, 5.2),
			curPos = spawnPos,
			vel = Vector3.zero,
			rotAxis = if axisRaw.Magnitude > 0.05 then axisRaw.Unit else Vector3.xAxis,
			rotSpeed = rng:NextNumber(1.2, 3.4),
			rotAngle = rng:NextNumber(0, math.pi * 2),
		})
	end

	local blasted = false
	local blastElapsed = 0.0
	local orbitElapsed = 0.0

	janitor:Connect(RunService.Heartbeat, function(dt: number)
		local step = math.min(dt, 0.05)
		if not blasted then
			orbitElapsed += step
			local riseAlpha = math.clamp(orbitElapsed / 0.55, 0, 1)
			local easedRise = 1 - (1 - riseAlpha) ^ 3
			local c = centerGetter()
			for _, rk in ipairs(rocks) do
				if rk.part.Parent then
					local ang = rk.baseAngle + orbitElapsed * 0.85
					local bob = math.sin(orbitElapsed * 2.6 + rk.baseAngle * 2) * 0.28
					local targetP = Vector3.new(
						c.X + math.cos(ang) * rk.radius,
						groundY + rk.targetHeight * easedRise + bob,
						c.Z + math.sin(ang) * rk.radius
					)
					rk.curPos = rk.curPos:Lerp(targetP, math.clamp(step * 10.0, 0, 1))
					rk.rotAngle += rk.rotSpeed * step
					rk.part.CFrame = CFrame.new(rk.curPos) * CFrame.fromAxisAngle(rk.rotAxis, rk.rotAngle)
				end
			end
		else
			blastElapsed += step
			for _, rk in ipairs(rocks) do
				if rk.part.Parent then
					rk.vel += Vector3.new(0, -68.0 * step, 0)
					rk.curPos += rk.vel * step
					if rk.curPos.Y < groundY + 0.35 then
						rk.curPos = Vector3.new(rk.curPos.X, groundY + 0.35, rk.curPos.Z)
						rk.vel = Vector3.new(rk.vel.X * 0.62, math.abs(rk.vel.Y) * 0.32, rk.vel.Z * 0.62)
					end
					rk.rotAngle += rk.rotSpeed * 2.4 * step
					rk.part.CFrame = CFrame.new(rk.curPos) * CFrame.fromAxisAngle(rk.rotAxis, rk.rotAngle)
					if blastElapsed > 1.1 then
						rk.part.Transparency = math.clamp((blastElapsed - 1.1) / 0.65, 0, 1)
					end
				end
			end
		end
	end)

	return {
		BlastOutward = function(blastOrigin: Vector3, forwardDir: Vector3)
			if blasted then
				return
			end
			blasted = true
			local fwd = if forwardDir.Magnitude > 0.01 then forwardDir.Unit else -Vector3.zAxis
			for _, rk in ipairs(rocks) do
				local radial = rk.curPos - blastOrigin
				local radialDir = if radial.Magnitude > 0.1 then radial.Unit else Vector3.xAxis
				rk.vel = radialDir * rng:NextNumber(34, 62) + fwd * rng:NextNumber(28, 54) + Vector3.new(0, rng:NextNumber(14, 28), 0)
			end
			janitor:Delay(1.85, function()
				for _, rk in ipairs(rocks) do
					if rk.part.Parent then
						rk.part:Destroy()
					end
				end
			end)
		end,
	}
end

-- Fase 4: Rasgo continuo no chao enquanto o Vazio Roxo viaja proximo ao solo
function DebrisModule.CarveGroundStep(
	parent: Instance,
	projectilePos: Vector3,
	forwardDir: Vector3,
	sphereRadius: number,
	reducedDetail: boolean,
	janitor: Janitor.JanitorInstance
)
	local sample = DebrisModule.SampleGround(projectilePos, Config.Scales.GroundRayDepth)
	if not sample.Hit then
		return
	end

	local hitPos = sample.Position
	local fwd = Vector3.new(forwardDir.X, 0, forwardDir.Z)
	fwd = if fwd.Magnitude > 0.01 then fwd.Unit else -Vector3.zAxis
	local right = fwd:Cross(Vector3.yAxis).Unit
	local trenchWidth = math.clamp(sphereRadius * 1.15, 5.5, 15.0)

	-- 1) Fissura ardente roxo-escura no chao que esfria e desaparece em 3s
	local scorchOuter = Instance.new("Part")
	scorchOuter.Name = "VoidGroundScorch"
	scorchOuter.Anchored = true
	scorchOuter.CanCollide = false
	scorchOuter.CanQuery = false
	scorchOuter.CanTouch = false
	scorchOuter.CastShadow = false
	scorchOuter.Massless = true
	scorchOuter.Material = Enum.Material.Slate
	scorchOuter.Color = Config.Colors.VoidScorch
	scorchOuter.Size = Vector3.new(trenchWidth, 0.18, 9.5)
	scorchOuter.CFrame = CFrame.lookAt(hitPos + Vector3.new(0, 0.06, 0), hitPos + Vector3.new(0, 0.06, 0) + fwd)
	scorchOuter.Parent = parent
	janitor:Add(scorchOuter)

	local seam = Instance.new("Part")
	seam.Name = "VoidGroundSeam"
	seam.Anchored = true
	seam.CanCollide = false
	seam.CanQuery = false
	seam.CanTouch = false
	seam.CastShadow = false
	seam.Massless = true
	seam.Material = Enum.Material.Neon
	seam.Color = Config.Colors.VoidMain
	seam.Transparency = 0.08
	seam.Size = Vector3.new(trenchWidth * 0.42, 0.22, 9.2)
	seam.CFrame = scorchOuter.CFrame * CFrame.new(0, 0.03, 0)
	seam.Parent = parent
	janitor:Add(seam)

	local seamTw = TweenService:Create(
		seam,
		TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Color = Config.Colors.VoidAbyss, Transparency = 1, Size = Vector3.new(0.25, 0.18, 9.2) }
	)
	seamTw:Play()

	janitor:Delay(1.4, function()
		if scorchOuter.Parent then
			local outTw = TweenService:Create(
				scorchOuter,
				TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Transparency = 1 }
			)
			outTw:Play()
		end
	end)
	janitor:Delay(3.05, function()
		if seam.Parent then
			seam:Destroy()
		end
		if scorchOuter.Parent then
			scorchOuter:Destroy()
		end
	end)

	-- 2) Fumaca escura densa + poeira violeta subindo do rastro
	local smokePart = Instance.new("Part")
	smokePart.Name = "TrenchSmoke"
	smokePart.Anchored = true
	smokePart.CanCollide = false
	smokePart.CanQuery = false
	smokePart.CanTouch = false
	smokePart.CastShadow = false
	smokePart.Massless = true
	smokePart.Transparency = 1
	smokePart.Size = Vector3.new(trenchWidth * 0.8, 0.2, 6.0)
	smokePart.CFrame = scorchOuter.CFrame
	smokePart.Parent = parent
	janitor:Add(smokePart)

	local dust = Instance.new("ParticleEmitter")
	dust.Texture = Config.ResolveTexture("Smoke")
	dust.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Config.Colors.VoidMagenta),
		ColorSequenceKeypoint.new(0.35, sample.Color),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 16, 30)),
	})
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.8),
		NumberSequenceKeypoint.new(0.5, 4.6),
		NumberSequenceKeypoint.new(1, 7.2),
	})
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.32),
		NumberSequenceKeypoint.new(0.65, 0.58),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Lifetime = NumberRange.new(0.75, 1.35)
	dust.Speed = NumberRange.new(6, 16)
	dust.SpreadAngle = Vector2.new(65, 65)
	dust.RotSpeed = NumberRange.new(-90, 90)
	dust.Rotation = NumberRange.new(0, 360)
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Rate = 0
	dust.Parent = smokePart
	dust:Emit(if reducedDetail then 4 else 9)

	janitor:Delay(1.5, function()
		if smokePart.Parent then
			smokePart:Destroy()
		end
	end)

	if reducedDetail then
		return
	end

	-- 3) Pedras arrancadas e arremessadas lateralmente para esquerda e direita
	for side = -1, 1, 2 do
		local spawnP = hitPos + right * (side * trenchWidth * 0.42) + Vector3.new(0, 0.4, 0)
		local sz = Vector3.new(
			rng:NextNumber(0.9, 2.2),
			rng:NextNumber(0.7, 1.7),
			rng:NextNumber(0.9, 2.2)
		)
		local rock = makeRockPart(parent, sz, sample.Color, sample.Material, rng:NextNumber() < 0.45)
		rock.CFrame = CFrame.new(spawnP)
		janitor:Add(rock)

		local vel = right * (side * rng:NextNumber(22, 42))
			+ fwd * rng:NextNumber(8, 24)
			+ Vector3.new(0, rng:NextNumber(20, 38), 0)
		local axisRaw = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
		local axis = if axisRaw.Magnitude > 0.05 then axisRaw.Unit else Vector3.xAxis
		local rotSpd = rng:NextNumber(5.0, 11.0)
		local curP = spawnP
		local curRot = 0.0
		local age = 0.0
		local conn: RBXScriptConnection? = nil
		conn = janitor:Connect(RunService.Heartbeat, function(dt: number)
			local s = math.min(dt, 0.05)
			age += s
			vel += Vector3.new(0, -82.0 * s, 0)
			curP += vel * s
			if curP.Y <= hitPos.Y + 0.35 then
				curP = Vector3.new(curP.X, hitPos.Y + 0.35, curP.Z)
				vel = Vector3.new(vel.X * 0.58, math.abs(vel.Y) * 0.28, vel.Z * 0.58)
			end
			curRot += rotSpd * s
			rock.CFrame = CFrame.new(curP) * CFrame.fromAxisAngle(axis, curRot)
			if age > 0.85 then
				rock.Transparency = math.clamp((age - 0.85) / 0.45, 0, 1)
			end
			if age >= 1.32 then
				if conn and conn.Connected then
					conn:Disconnect()
				end
				if rock.Parent then
					rock:Destroy()
				end
			end
		end)
	end
end

-- Fase 5: Anel de cratera circular gigante no epicentro da detonacao
function DebrisModule.SpawnCraterRing(
	parent: Instance,
	epicenter: Vector3,
	radius: number,
	rockCount: number,
	lingerDuration: number,
	janitor: Janitor.JanitorInstance
)
	local sample = DebrisModule.SampleGround(epicenter, 36.0)
	local center = if sample.Hit then sample.Position else (epicenter - Vector3.new(0, 2.0, 0))

	-- Cratera queimada central
	local floorBurn = Instance.new("Part")
	floorBurn.Name = "CraterScorch"
	floorBurn.Shape = Enum.PartType.Cylinder
	floorBurn.Anchored = true
	floorBurn.CanCollide = false
	floorBurn.CanQuery = false
	floorBurn.CanTouch = false
	floorBurn.CastShadow = false
	floorBurn.Massless = true
	floorBurn.Material = Enum.Material.Slate
	floorBurn.Color = Config.Colors.VoidScorch
	floorBurn.Size = Vector3.new(0.24, radius * 1.85, radius * 1.85)
	floorBurn.CFrame = CFrame.new(center + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90))
	floorBurn.Parent = parent
	janitor:Add(floorBurn)

	local rocks: { BasePart } = {}
	for i = 1, rockCount do
		local ang = ((i - 1) / math.max(1, rockCount)) * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local r = radius * rng:NextNumber(0.86, 1.08)
		local pos = center + Vector3.new(math.cos(ang) * r, -1.6, math.sin(ang) * r)
		local sz = Vector3.new(
			rng:NextNumber(3.4, 6.2),
			rng:NextNumber(2.2, 4.6),
			rng:NextNumber(2.8, 5.2)
		)
		local rock = makeRockPart(parent, sz, sample.Color, sample.Material, i % 2 == 0)
		local lookIn = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z))
		local tilt = CFrame.Angles(math.rad(rng:NextNumber(22, 42)), math.rad(rng:NextNumber(-14, 14)), math.rad(rng:NextNumber(-12, 12)))
		rock.CFrame = lookIn * tilt
		janitor:Add(rock)
		table.insert(rocks, rock)

		local targetPos = Vector3.new(pos.X, center.Y + sz.Y * 0.26, pos.Z)
		local popTw = TweenService:Create(
			rock,
			TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ CFrame = CFrame.lookAt(targetPos, Vector3.new(center.X, targetPos.Y, center.Z)) * tilt }
		)
		popTw:Play()
	end

	janitor:Delay(math.max(0.3, lingerDuration - 0.65), function()
		if floorBurn.Parent then
			TweenService:Create(floorBurn, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
		end
		for _, rk in ipairs(rocks) do
			if rk.Parent then
				TweenService:Create(
					rk,
					TweenInfo.new(0.58, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ Position = rk.Position - Vector3.new(0, 3.2, 0), Transparency = 1 }
				):Play()
			end
		end
	end)
end

return DebrisModule
