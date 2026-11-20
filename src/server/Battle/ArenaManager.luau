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

-- Cria (pelo nome do modelo nos dados) o personagem em campo de um lado.
-- index = posicao no time (padrao: quem esta em campo agora)
function ArenaManager.SpawnActive(session, side: string, index: number?): Model
	local arena = session.Arena
	local sideState = session.Battle.Sides[side]
	local member = sideState.Team[index or sideState.Active]
	local point = if side == "Player" then arena.PlayerPoint else arena.EnemyPoint
	local model = CharacterLibrary.Spawn(member.ModelName, nil, session.Actors)
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	model.HumanoidRootPart.Anchored = true
	ArenaManager.StandAt(model, point.CFrame, session.FloorY)
	CollectionService:AddTag(model, "BattleCharacter")
	local old = session.Models[side]
	if old then
		old:Destroy()
	end
	session.Models[side] = model
	return model
end

-- Coloca o personagem do jogador atras do seu lutador
function ArenaManager.PlaceViewer(session, player: Player, point: BasePart)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	pcall(function()
		player:RequestStreamAroundAsync(point.Position, 5)
	end)
	local spot = point.CFrame * CFrame.new(-5, 0, 8)
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
