--!strict
--[[
	ReplicatedStorage/HollowPurple/LightningModule.luau
	Gerador procedural de raios 3D jagged usando Midpoint Displacement recursivo.
	Renderiza cada segmento com nucleo incandescente + casca externa Neon, suporta
	ramificacoes (branches), afilamento e fade-out ultra suave sem vazar instancias.
]]

local TweenService = game:GetService("TweenService")
local Janitor = require(script.Parent:WaitForChild("Janitor"))

export type BoltOptions = {
	InnerColor: Color3?,
	OuterColor: Color3?,
	Thickness: number?,
	Subdivisions: number?, -- 3 = 8 segmentos, 4 = 16 segmentos
	Jitter: number?,
	BranchChance: number?,
	BranchScale: number?,
	Duration: number?,
	OuterTransparency: number?,
}

local LightningModule = {}

local rng = Random.new()

local function makeBoltSegment(
	parent: Instance,
	p0: Vector3,
	p1: Vector3,
	thickness: number,
	color: Color3,
	trans: number
): Part?
	local delta = p1 - p0
	local len = delta.Magnitude
	if len < 0.04 then
		return nil
	end
	local p = Instance.new("Part")
	p.Name = "BoltSeg"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = trans
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = Vector3.new(thickness, thickness, len + thickness * 0.35)
	p.CFrame = CFrame.lookAt((p0 + p1) * 0.5, p1)
	p.Parent = parent
	return p
end

local function computePerpendicularBasis(dir: Vector3): (Vector3, Vector3)
	local unit = if dir.Magnitude > 0.001 then dir.Unit else Vector3.zAxis
	local ref = if math.abs(unit.Y) < 0.92 then Vector3.yAxis else Vector3.xAxis
	local right = unit:Cross(ref).Unit
	local up = right:Cross(unit).Unit
	return right, up
end

local function buildDisplacedPoints(p0: Vector3, p1: Vector3, subdivisions: number, jitterScale: number): { Vector3 }
	local pts: { Vector3 } = { p0, p1 }
	local right, up = computePerpendicularBasis(p1 - p0)
	local curJitter = jitterScale

	for _ = 1, subdivisions do
		local nextPts: { Vector3 } = { pts[1] }
		for i = 1, #pts - 1 do
			local a = pts[i]
			local b = pts[i + 1]
			local mid = (a + b) * 0.5
			local angle = rng:NextNumber(0, math.pi * 2)
			local mag = rng:NextNumber(0.25, 1.0) * curJitter
			local offset = (right * math.cos(angle) + up * math.sin(angle)) * mag
			table.insert(nextPts, mid + offset)
			table.insert(nextPts, b)
		end
		pts = nextPts
		curJitter *= 0.52
	end
	return pts
end

function LightningModule.DrawBolt(
	parent: Instance,
	p0: Vector3,
	p1: Vector3,
	opts: BoltOptions?,
	janitor: Janitor.JanitorInstance?
): Model?
	if not parent or not parent.Parent then
		return nil
	end
	local dist = (p1 - p0).Magnitude
	if dist < 0.15 then
		return nil
	end

	local o: BoltOptions = opts or {}
	local innerCol = o.InnerColor or Color3.fromRGB(245, 235, 255)
	local outerCol = o.OuterColor or Color3.fromRGB(145, 25, 255)
	local thick = o.Thickness or 0.22
	local subdivs = math.clamp(o.Subdivisions or 3, 1, 4)
	local jitter = o.Jitter or math.clamp(dist * 0.14, 0.35, 2.8)
	local branchChance = o.BranchChance or 0.32
	local branchScale = o.BranchScale or 0.45
	local dur = o.Duration or 0.16
	local outerTrans = o.OuterTransparency or 0.32

	local model = Instance.new("Model")
	model.Name = "LightningBolt"
	model.Parent = parent
	if janitor then
		janitor:Add(model)
	end

	local allCore: { Part } = {}
	local allOuter: { Part } = {}

	local function addChain(pts: { Vector3 }, baseThick: number)
		local count = #pts - 1
		for i = 1, count do
			local a = pts[i]
			local b = pts[i + 1]
			-- Afilamento suave nas extremidades
			local u = (i - 0.5) / math.max(1, count)
			local env = 0.65 + 0.35 * math.sin(u * math.pi)
			local segThick = math.max(0.05, baseThick * env)

			local core = makeBoltSegment(model, a, b, segThick, innerCol, 0.02)
			if core then
				table.insert(allCore, core)
			end
			local outer = makeBoltSegment(model, a, b, segThick * 2.15, outerCol, outerTrans)
			if outer then
				table.insert(allOuter, outer)
			end
		end
	end

	local mainPts = buildDisplacedPoints(p0, p1, subdivs, jitter)
	addChain(mainPts, thick)

	-- Ramificacoes (branches)
	if branchChance > 0 and #mainPts >= 5 then
		local mainDir = (p1 - p0).Unit
		local right, up = computePerpendicularBasis(mainDir)
		for i = 2, #mainPts - 2, 2 do
			if rng:NextNumber() < branchChance then
				local startB = mainPts[i]
				local ang = rng:NextNumber(0, math.pi * 2)
				local spread = rng:NextNumber(0.45, 0.95)
				local bDir = (mainDir + (right * math.cos(ang) + up * math.sin(ang)) * spread).Unit
				local bLen = dist * branchScale * rng:NextNumber(0.55, 1.0)
				local endB = startB + bDir * bLen
				local bPts = buildDisplacedPoints(startB, endB, math.max(1, subdivs - 1), jitter * 0.55)
				addChain(bPts, thick * 0.58)
			end
		end
	end

	-- Fade-out e afilamento rapido
	local ti = TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, p in ipairs(allCore) do
		local tw = TweenService:Create(p, ti, {
			Size = Vector3.new(0.02, 0.02, p.Size.Z),
			Transparency = 1,
		})
		tw:Play()
	end
	for _, p in ipairs(allOuter) do
		local tw = TweenService:Create(p, ti, {
			Size = Vector3.new(0.04, 0.04, p.Size.Z),
			Transparency = 1,
		})
		tw:Play()
	end

	if janitor then
		janitor:Delay(dur + 0.05, function()
			if model.Parent then
				model:Destroy()
			end
		end)
	else
		task.delay(dur + 0.05, function()
			if model.Parent then
				model:Destroy()
			end
		end)
	end

	return model
end

-- Dispara multiplos raios radiais ao redor de um ponto (ou puxando de fora para dentro)
function LightningModule.BurstAround(
	parent: Instance,
	center: Vector3,
	innerRadius: number,
	outerRadius: number,
	count: number,
	inward: boolean,
	opts: BoltOptions?,
	janitor: Janitor.JanitorInstance?
)
	for _ = 1, count do
		local theta = rng:NextNumber(0, math.pi * 2)
		local phi = math.acos(rng:NextNumber(-0.85, 0.85))
		local dir = Vector3.new(
			math.sin(phi) * math.cos(theta),
			math.cos(phi),
			math.sin(phi) * math.sin(theta)
		)
		local pInner = center + dir * innerRadius
		local pOuter = center + dir * (outerRadius * rng:NextNumber(0.75, 1.2))
		if inward then
			LightningModule.DrawBolt(parent, pOuter, pInner, opts, janitor)
		else
			LightningModule.DrawBolt(parent, pInner, pOuter, opts, janitor)
		end
	end
end

return LightningModule
