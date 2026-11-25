--[[
	CharacterLibrary
	Unico ponto que conhece onde os personagens ficam.
	Os scripts pedem o personagem SO PELO NOME ("Kaen", "Raiko").

	Contrato que todo modelo em ServerStorage/Characters precisa seguir
	(vale para o provisorio e para o modelo final importado do FBX):
	  - Model com o nome do personagem, PrimaryPart = HumanoidRootPart
	  - Humanoid (R15) com Animator dentro
	  - Pasta "Animations" com Animation chamadas: Idle, Attack, Hit, Faint
	    (opcionais: Walk, Special, Victory)

	Uso:
	  local Characters = require(game.ServerScriptService.CharacterLibrary)
	  local kaen = Characters.Spawn("Kaen", arena.PlayerPoint.CFrame)
	  Characters.Play(kaen, "Attack")
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local PROCEDURAL_IDLE_TAGS = { "BattleCharacter", "BaseCharacter", "RefugeWild", "PartyFollower", "CapsuleCharacter" }

local Characters = {}

local FOLDER = ServerStorage:WaitForChild("Characters")
local charactersData = nil
local function getCharactersData()
	if charactersData == nil then
		local dataFolder = ReplicatedStorage:FindFirstChild("Data")
		local mod = dataFolder and dataFolder:FindFirstChild("Characters")
		if mod then
			charactersData = require(mod)
		end
	end
	return charactersData
end
local LOOPED = { Idle = true, Walk = true }
-- Animacoes que congelam no ultimo quadro (caido depois de desmaiar, pose de vitoria)
local HOLD_LAST_FRAME = { Faint = true, Victory = true }

local tracksByModel = setmetatable({}, { __mode = "k" })

local function applyPlaceholderColors(model: Model, colors)
	if typeof(colors) ~= "table" then
		return
	end
	local torsoParts = { UpperTorso = true, LowerTorso = true }
	local armParts = { LeftUpperArm = true, LeftLowerArm = true, RightUpperArm = true, RightLowerArm = true }
	local legParts = { LeftUpperLeg = true, LeftLowerLeg = true, RightUpperLeg = true, RightLowerLeg = true, LeftFoot = true, RightFoot = true }
	for _, ch in ipairs(model:GetChildren()) do
		if ch:IsA("BasePart") then
			if torsoParts[ch.Name] and colors.Torso then
				ch.Color = colors.Torso
			elseif armParts[ch.Name] and colors.Accent then
				ch.Color = colors.Accent
			elseif legParts[ch.Name] and colors.Legs then
				ch.Color = colors.Legs
			end
		end
	end
end

-- Cria um clone bruto do modelo (ou usa um rig provisorio colorido se o modelo ainda nao existe em ServerStorage/Characters)
function Characters.CloneSource(name: string): Model
	local source = FOLDER:FindFirstChild(name)
	if source and source:IsA("Model") then
		return source:Clone()
	end
	local fallback = FOLDER:FindFirstChild("ProtoRaro") or FOLDER:FindFirstChild("Kaen")
	assert(fallback and fallback:IsA("Model"), "Personagem nao encontrado em ServerStorage/Characters: " .. tostring(name))
	local model = fallback:Clone()
	model.Name = name
	model:SetAttribute("PlaceholderModel", true)
	local visor = model:FindFirstChild("Acc_Visor")
	if visor then
		visor:Destroy()
	end
	local cdata = getCharactersData()
	local def = cdata and cdata.Get(name)
	if def and def.PlaceholderColors then
		applyPlaceholderColors(model, def.PlaceholderColors)
	end
	-- Aplica animacoes padrao da classe (espada, punho, magia, disparo) nos modelos provisorios
	if def then
		local animFolder = model:FindFirstChild("Animations")
		local movesMod = ReplicatedStorage:FindFirstChild("Data") and ReplicatedStorage.Data:FindFirstChild("Moves")
		local Moves = movesMod and require(movesMod)
		local classAnims = Moves and Moves.ClassDefaultAnimations and Moves.ClassDefaultAnimations[def.Type]
		if animFolder and classAnims then
			for key, animId in pairs(classAnims) do
				local a = animFolder:FindFirstChild(key)
				if not a then
					a = Instance.new("Animation")
					a.Name = key
					a.Parent = animFolder
				end
				if a:IsA("Animation") then
					a.AnimationId = "rbxassetid://" .. tostring(animId)
				end
			end
		end
	end
	return model
end

function Characters.Exists(name: string): boolean
	if FOLDER:FindFirstChild(name) ~= nil then
		return true
	end
	local cdata = getCharactersData()
	return cdata ~= nil and cdata.Get(name) ~= nil and (FOLDER:FindFirstChild("ProtoRaro") ~= nil or FOLDER:FindFirstChild("Kaen") ~= nil)
end

function Characters.List(): { string }
	local names = {}
	for _, m in ipairs(FOLDER:GetChildren()) do
		if m:IsA("Model") then
			table.insert(names, m.Name)
		end
	end
	return names
end

-- Cria uma copia do personagem e coloca no mundo.
function Characters.Spawn(name: string, cframe: CFrame?, parent: Instance?): Model
	local model = Characters.CloneSource(name)
	local cdata = getCharactersData()
	if cdata then
		local animeId = cdata.AnimeOf(name)
		model:SetAttribute("Anime", animeId)
		model:SetAttribute("GenericCharacter", if cdata.IsGeneric(name) then true else nil)
	end
	if cframe then
		model:PivotTo(cframe)
	end
	model.Parent = parent or workspace
	return model
end

local function getAnimator(model: Model): Animator
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	assert(humanoid, model.Name .. " nao tem Humanoid")
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	return animator
end

-- Toca uma animacao pelo nome (Idle, Attack, Hit, Faint). Retorna o AnimationTrack.
function Characters.Play(model: Model, animName: string, fadeTime: number?): AnimationTrack?
	if animName == "Idle" or animName == "Walk" then
		for _, tag in ipairs(PROCEDURAL_IDLE_TAGS) do
			if CollectionService:HasTag(model, tag) then
				return nil -- BaseClient anima Idle/Walk proceduralmente a 60 FPS
			end
		end
	end
	local folder = model:FindFirstChild("Animations")
	local anim = folder and folder:FindFirstChild(animName)
	if not anim and folder then
		anim = folder:FindFirstChild("Attack")
		if anim then
			animName = "Attack"
		end
	end
	if not anim then
		warn("Animacao '" .. animName .. "' nao encontrada em " .. model.Name)
		return nil
	end
	local cache = tracksByModel[model]
	if not cache then
		cache = {}
		tracksByModel[model] = cache
	end
	local track = cache[animName]
	if not track then
		track = getAnimator(model):LoadAnimation(anim)
		track.Looped = LOOPED[animName] == true
		if animName == "Faint" or animName == "Victory" then
			track.Priority = Enum.AnimationPriority.Action4
		elseif animName ~= "Idle" then
			track.Priority = Enum.AnimationPriority.Action
		else
			track.Priority = Enum.AnimationPriority.Idle
		end
		cache[animName] = track
	end
	track:Play(fadeTime or 0.1)
	track:AdjustSpeed(1)
	if HOLD_LAST_FRAME[animName] then
		task.spawn(function()
			local t0 = os.clock()
			while track.Length == 0 and os.clock() - t0 < 3 do
				task.wait()
			end
			task.wait(math.max(0, track.Length - 0.05))
			if track.IsPlaying then
				track:AdjustSpeed(0)
			end
		end)
	end
	return track
end

function Characters.Stop(model: Model, animName: string?, fadeTime: number?)
	local cache = tracksByModel[model]
	if not cache then
		return
	end
	for name, track in pairs(cache) do
		if animName == nil or name == animName then
			track:Stop(fadeTime or 0.1)
		end
	end
end

return Characters
