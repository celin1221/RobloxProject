--[[
	ArenaManager
	Responsavel por gerenciar as Arenas 3D em Workspace.Arenas:
	- Encontrar e reservar/liberar uma arena livre
	- Posicionar modelos R15 e personagens dos jogadores no piso da arena
	- Instanciar/trocar os modelos ativos de cada lado (Player / Enemy)
	- Tocar particulas de impacto e calcular camera espelhada para PvP
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local CharacterLibrary = require(ServerScriptService:WaitForChild("CharacterLibrary"))

local ArenaManager = {}

-- Deslocamento lateral (studs) dos slots 1 (esquerda) e 2 (direita) em batalhas 2x2
ArenaManager.DOUBLE_LATERAL = 5.2
-- Escala horizontal dos altares/escudos de chao no 2x2 (mantem ~2.3 studs de agua livre entre os dois altares)
local DOUBLE_ALTAR_SCALE = 0.78

local altarCacheByArena: { [Model]: { Single: Folder, Double: Folder, CurrentDouble: boolean } } = {}

local function getAltarsCacheRoot(): Folder
	local root = ServerStorage:FindFirstChild("_ArenaAltarsCache")
	if root and root:IsA("Folder") then
		return root
	end
	local f = Instance.new("Folder")
	f.Name = "_ArenaAltarsCache"
	f.Parent = ServerStorage
	return f
end

local function scaleNumberSequence(seq: NumberSequence, factor: number): NumberSequence
	local kps = {}
	for _, kp in ipairs(seq.Keypoints) do
		table.insert(kps, NumberSequenceKeypoint.new(kp.Time, kp.Value * factor, kp.Envelope * factor))
	end
	return NumberSequence.new(kps)
end

-- Clona um AltarCombate (1x1) e gera um altar individual compacto centralizado exatamente em targetPos (preservando Y do piso)
local function cloneScaledAltar(template: Model, origCenter: Vector3, targetPos: Vector3, rotY: number, scaleXZ: number, name: string): Model
	local clone = template:Clone()
	clone.Name = name
	local ox, oz = origCenter.X, origCenter.Z
	local tx, tz = targetPos.X, targetPos.Z
	local cosR = math.cos(rotY)
	local sinR = math.sin(rotY)

	local function mapXZ(p: Vector3): Vector3
		local dx = (p.X - ox) * scaleXZ
		local dz = (p.Z - oz) * scaleXZ
		if rotY ~= 0 then
			dx, dz = dx * cosR + dz * sinR, -dx * sinR + dz * cosR
		end
		return Vector3.new(tx + dx, p.Y, tz + dz)
	end

	for _, child in ipairs(clone:GetChildren()) do
		if child:IsA("BasePart") then
			local newPos = mapXZ(child.Position)
			local rotOnly = child.CFrame - child.CFrame.Position
			if child:IsA("Part") and child.Shape == Enum.PartType.Cylinder then
				-- Cilindros verticais da arena tem altura em Size.X e diametro em Size.Y/Z
				child.Size = Vector3.new(child.Size.X, child.Size.Y * scaleXZ, child.Size.Z * scaleXZ)
				child.CFrame = CFrame.new(newPos) * rotOnly
			elseif child.Name == "SeloAmaldicoado" then
				child.Size = Vector3.new(child.Size.X * scaleXZ, child.Size.Y, child.Size.Z * scaleXZ)
				child.CFrame = CFrame.new(newPos) * CFrame.Angles(0, rotY, 0) * rotOnly
			elseif child.Name:sub(1, 11) == "TravaTemplo" then
				child.Size = Vector3.new(child.Size.X * 0.86, child.Size.Y, child.Size.Z * 0.86)
				child.CFrame = CFrame.new(newPos) * CFrame.Angles(0, rotY, 0) * rotOnly
			else
				child.CFrame = CFrame.new(newPos) * rotOnly
				for _, desc in ipairs(child:GetDescendants()) do
					if desc:IsA("ParticleEmitter") then
						desc.Size = scaleNumberSequence(desc.Size, scaleXZ)
					elseif desc:IsA("PointLight") then
						desc.Brightness = desc.Brightness * 0.72
						desc.Range = desc.Range * 0.88
					end
				end
			end
		elseif child:IsA("Model") then
			-- Cranios decorativos ao redor da base do altar
			local origCF = child:GetBoundingBox()
			local origPos = origCF.Position
			local newCenter = mapXZ(origPos)
			child:ScaleTo(child:GetScale() * 0.85)
			local nowCF = child:GetBoundingBox()
			local pivotNow = child:GetPivot()
			local offsetFromCenter = nowCF:ToObjectSpace(pivotNow)
			local targetCenterCF = CFrame.new(newCenter.X, origPos.Y, newCenter.Z)
				* CFrame.Angles(0, rotY, 0)
				* (nowCF - nowCF.Position)
			child:PivotTo(targetCenterCF * offsetFromCenter)
		end
	end
	return clone
end

-- Reposiciona um AltarApoio do treinador sem alterar escala (apenas translada XZ para o ponto 2x2 do jogador)
local function cloneViewerAltar(template: Model, origCenter: Vector3, targetPos: Vector3, rotY: number, name: string): Model
	local clone = template:Clone()
	clone.Name = name
	local ox, oz = origCenter.X, origCenter.Z
	local tx, tz = targetPos.X, targetPos.Z
	local cosR = math.cos(rotY)
	local sinR = math.sin(rotY)

	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then
			local dx = d.Position.X - ox
			local dz = d.Position.Z - oz
			if rotY ~= 0 then
				dx, dz = dx * cosR + dz * sinR, -dx * sinR + dz * cosR
			end
			local rotOnly = d.CFrame - d.CFrame.Position
			if d.Name == "SeloAmaldicoado" then
				d.CFrame = CFrame.new(tx + dx, d.Position.Y, tz + dz) * CFrame.Angles(0, rotY, 0) * rotOnly
			else
				d.CFrame = CFrame.new(tx + dx, d.Position.Y, tz + dz) * rotOnly
			end
		end
	end
	return clone
end

local function ensureAltarPair(arena: Model)
	local cached = altarCacheByArena[arena]
	if cached and cached.Single.Parent and cached.Double.Parent then
		return cached
	end
	local decor = arena:FindFirstChild("DomainDecor")
	local pp = arena:FindFirstChild("PlayerPoint")
	local ep = arena:FindFirstChild("EnemyPoint")
	if not (decor and pp and ep and pp:IsA("BasePart") and ep:IsA("BasePart")) then
		return nil
	end
	local cacheRoot = getAltarsCacheRoot()
	local arenaCache = cacheRoot:FindFirstChild(arena.Name)
	if not arenaCache then
		arenaCache = Instance.new("Folder")
		arenaCache.Name = arena.Name
		arenaCache.Parent = cacheRoot
	end

	local single = decor:FindFirstChild("AltaresPersonagens") or arenaCache:FindFirstChild("AltaresPersonagens")
	if not (single and single:IsA("Folder")) then
		return nil
	end

	local doubleFolder = decor:FindFirstChild("AltaresPersonagens2x2") or arenaCache:FindFirstChild("AltaresPersonagens2x2")
	if not (doubleFolder and doubleFolder:IsA("Folder")) then
		-- Seleciona o AltarCombate do lado Player (mais proximo de PlayerPoint) como molde
		local combatTemplate: Model? = nil
		local combatCenter: Vector3? = nil
		local bestDist = math.huge
		local viewerTemplate: Model? = nil
		local viewerCenter: Vector3? = nil
		local bestViewerDist = math.huge

		for _, child in ipairs(single:GetChildren()) do
			if child:IsA("Model") then
				local topo = child:FindFirstChild("TopoAltar")
				if topo and topo:IsA("BasePart") then
					local d = (Vector3.new(topo.Position.X, 0, topo.Position.Z) - Vector3.new(pp.Position.X, 0, pp.Position.Z)).Magnitude
					if child.Name == "AltarCombate" and d < bestDist then
						bestDist = d
						combatTemplate = child
						combatCenter = topo.Position
					elseif child.Name == "AltarApoio" and d < bestViewerDist then
						bestViewerDist = d
						viewerTemplate = child
						viewerCenter = topo.Position
					end
				end
			end
		end
		if not (combatTemplate and combatCenter) then
			return nil
		end

		local f2 = Instance.new("Folder")
		f2.Name = "AltaresPersonagens2x2"
		for _, sideCfg in ipairs({
			{ side = "Player", rotY = 0, point = pp },
			{ side = "Enemy", rotY = math.pi, point = ep },
		}) do
			for slot = 1, 2 do
				local slotCF = ArenaManager.SlotCFrame(arena, sideCfg.side, slot, true)
				local altar = cloneScaledAltar(
					combatTemplate,
					combatCenter,
					slotCF.Position,
					sideCfg.rotY,
					DOUBLE_ALTAR_SCALE,
					string.format("AltarCombate_%s_%d", sideCfg.side, slot)
				)
				altar.Parent = f2
			end
			-- Reposiciona o pequeno altar de apoio do treinador no ponto 2x2 de PlaceViewer
			if viewerTemplate and viewerCenter then
				local viewerSpot = (sideCfg.point.CFrame * CFrame.new(-3, 0, 16)).Position
				local vAltar = cloneViewerAltar(
					viewerTemplate,
					viewerCenter,
					viewerSpot,
					sideCfg.rotY,
					"AltarApoio_" .. sideCfg.side
				)
				vAltar.Parent = f2
			end
		end
		f2.Parent = arenaCache
		doubleFolder = f2
	end

	local entry = {
		Single = single :: Folder,
		Double = doubleFolder :: Folder,
		CurrentDouble = (doubleFolder :: Instance).Parent == decor,
	}
	altarCacheByArena[arena] = entry
	return entry
end

-- Alterna os escudos/altares de chao da arena entre 1x1 (1 altar central por lado) e 2x2 (2 altares individuais por lado)
function ArenaManager.ConfigureAltars(arena: Model?, isDouble: boolean)
	if not arena or not arena.Parent then
		return
	end
	local decor = arena:FindFirstChild("DomainDecor")
	if not decor then
		return
	end
	local pair = ensureAltarPair(arena)
	if not pair then
		return
	end
	local arenaCache = getAltarsCacheRoot():FindFirstChild(arena.Name)
	if isDouble then
		if pair.Single.Parent ~= arenaCache then
			pair.Single.Parent = arenaCache
		end
		if pair.Double.Parent ~= decor then
			pair.Double.Parent = decor
		end
		pair.CurrentDouble = true
	else
		if pair.Double.Parent ~= arenaCache then
			pair.Double.Parent = arenaCache
		end
		if pair.Single.Parent ~= decor then
			pair.Single.Parent = decor
		end
		pair.CurrentDouble = false
	end
end

function ArenaManager.FindFreeArena(): Model?
	local folder = workspace:FindFirstChild("Arenas")
	if not folder then
		return nil
	end
	for _, arena in ipairs(folder:GetChildren()) do
		if arena:IsA("Model") and not arena:GetAttribute("InUse")
			and arena:FindFirstChild("PlayerPoint") and arena:FindFirstChild("EnemyPoint") then
			return arena
		end
	end
	return nil
end

function ArenaManager.GetFloorY(arena: Model): number
	local floor = arena:FindFirstChild("FloorMid")
	if floor then
		return floor.Position.Y + floor.Size.Y / 2
	end
	return arena.PlayerPoint.Position.Y - 3
end

-- Poe um modelo com Humanoid em pe sobre o chao, no ponto e direcao de "spot"
function ArenaManager.StandAt(model: Model, spot: CFrame, floorY: number)
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local legs = if humanoid.RigType == Enum.HumanoidRigType.R6 then 2 else humanoid.HipHeight
	local pos = Vector3.new(spot.Position.X, floorY + legs + root.Size.Y / 2, spot.Position.Z)
	local look = spot.LookVector * Vector3.new(1, 0, 1)
	model:PivotTo(CFrame.lookAt(pos, pos + look))
end

-- Particulas de impacto na cor do tipo
function ArenaManager.ImpactBurst(model: Model?, color: Color3)
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local att = Instance.new("Attachment")
	att.Parent = root
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(color)
	pe.LightEmission = 1
	pe.LightInfluence = 0
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(0.3, 0.6)
	pe.Speed = NumberRange.new(8, 16)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Drag = 4
	pe.Rate = 0
	pe.Parent = att
	pe:Emit(30)
	Debris:AddItem(att, 1.5)
end

-- Ponto 3D do lutador em um slot (1x1 = centro do ponto; 2x2 = esquerda/direita)
function ArenaManager.SlotCFrame(arena: Model, side: string, fieldSlot: number?, isDouble: boolean?): CFrame
	local point = if side == "Player" then arena.PlayerPoint else arena.EnemyPoint
	if not isDouble then
		return point.CFrame
	end
	local xOff = if (fieldSlot or 1) == 1 then -ArenaManager.DOUBLE_LATERAL else ArenaManager.DOUBLE_LATERAL
	return point.CFrame * CFrame.new(xOff, 0, 0)
end

-- Camera da arena: 1x1 usa CameraPoint original; 2x2 usa angulo 3/4 elevado e lateralizado para separar os 4 lutadores sem sobreposicao e sem colisoes com a HUD
function ArenaManager.BattleCamera(arena: Model, format: string?): CFrame?
	if format ~= "2x2" then
		local cameraPoint = arena:FindFirstChild("CameraPoint")
		return cameraPoint and cameraPoint.CFrame
	end
	local pp = arena:FindFirstChild("PlayerPoint")
	local ep = arena:FindFirstChild("EnemyPoint")
	if not (pp and ep) then
		local cameraPoint = arena:FindFirstChild("CameraPoint")
		return cameraPoint and cameraPoint.CFrame
	end
	local center = (pp.Position + ep.Position) / 2
	local camPos = (pp.CFrame * CFrame.new(21.5, 10.2, 14.5)).Position
	local lookAt = center + pp.CFrame.RightVector * 3.2 + Vector3.new(0, -0.3, 0)
	return CFrame.lookAt(camPos, lookAt)
end

-- Cria (pelo nome do modelo nos dados) o personagem em campo de um lado/slot.
-- index = posicao no time (padrao: quem esta em campo nesse slot agora)
-- fieldSlot = 1 (padrao) ou 2 (em batalhas 2x2)
function ArenaManager.SpawnActive(session, side: string, index: number?, fieldSlot: number?): Model?
	local arena = session.Arena
	local sideState = session.Battle.Sides[side]
	local slot = fieldSlot or 1
	local isDouble = session.Battle.IsDouble and session.Battle:IsDouble()
	local teamIdx = index or (sideState.ActiveSlots and sideState.ActiveSlots[slot]) or sideState.Active
	local member = teamIdx and sideState.Team[teamIdx]
	if not member then
		return nil
	end
	local spot = ArenaManager.SlotCFrame(arena, side, slot, isDouble)
	local model = CharacterLibrary.Spawn(member.ModelName, nil, session.Actors)
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	model.HumanoidRootPart.Anchored = true
	ArenaManager.StandAt(model, spot, session.FloorY)
	model:SetAttribute("CharacterId", member.Id)
	model:SetAttribute("Awakened", member.Awakened == true)
	CollectionService:AddTag(model, "BattleCharacter")

	session.SlotModels = session.SlotModels or { Player = {}, Enemy = {} }
	session.SlotModels[side] = session.SlotModels[side] or {}
	local old = session.SlotModels[side][slot]
	if old and old.Parent then
		old:Destroy()
	end
	session.SlotModels[side][slot] = model
	if slot == 1 then
		session.Models[side] = model
	end
	return model
end

-- Remove o modelo 3D de um slot que ficou vazio (ex.: 2x1 quando o banco acabou)
function ArenaManager.ClearSlot(session, side: string, fieldSlot: number)
	if session.SlotModels and session.SlotModels[side] then
		local old = session.SlotModels[side][fieldSlot]
		if old and old.Parent then
			old:Destroy()
		end
		session.SlotModels[side][fieldSlot] = nil
	end
	if fieldSlot == 1 then
		session.Models[side] = nil
	end
end

-- Coloca o personagem do jogador atras do(s) seu(s) lutador(es)
function ArenaManager.PlaceViewer(session, player: Player, point: BasePart, isDouble: boolean?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	pcall(function()
		player:RequestStreamAroundAsync(point.Position, 5)
	end)
	local spot = if isDouble then point.CFrame * CFrame.new(-3, 0, 16) else point.CFrame * CFrame.new(-5, 0, 8)
	root.Anchored = true
	ArenaManager.StandAt(character, CFrame.lookAt(spot.Position, spot.Position + point.CFrame.LookVector), session.FloorY)
end

-- Camera do lado Enemy: a do lado Player girada 180 graus em volta do centro da arena
function ArenaManager.MirroredCamera(arena: Model, cam: CFrame?): CFrame?
	if not cam then
		return nil
	end
	local center = (arena.PlayerPoint.Position + arena.EnemyPoint.Position) / 2
	local pivot = CFrame.new(center)
	return pivot * CFrame.Angles(0, math.pi, 0) * pivot:ToObjectSpace(cam)
end

-- Devolve o jogador a praca e solta o personagem
function ArenaManager.ReturnToPlaza(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		local map = workspace:FindFirstChild("Map")
		local spawn = map and map:FindFirstChild("SpawnLocation")
		local target = if spawn then spawn.CFrame + Vector3.new(0, 4, 0) else CFrame.new(40, 6, 0)
		character:PivotTo(target)
		root.Anchored = false
	end
end

return ArenaManager
