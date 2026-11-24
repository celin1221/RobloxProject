--[[
	ArenaManager
	Responsavel por gerenciar as Arenas 3D em Workspace.Arenas:
	- Encontrar e reservar/liberar uma arena livre
	- Posicionar modelos R15 e personagens dos jogadores no piso da arena
	- Instanciar/trocar os modelos ativos de cada lado (Player / Enemy)
	- Tocar particulas de impacto e calcular camera espelhada para PvP
]]

local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local CharacterLibrary = require(ServerScriptService:WaitForChild("CharacterLibrary"))

local ArenaManager = {}

-- Deslocamento lateral (studs) dos slots 1 (esquerda) e 2 (direita) em batalhas 2x2
ArenaManager.DOUBLE_LATERAL = 5.2

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
