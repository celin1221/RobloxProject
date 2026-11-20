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

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

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

function Characters.Exists(name: string): boolean
	return FOLDER:FindFirstChild(name) ~= nil
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
	local source = FOLDER:FindFirstChild(name)
	assert(source and source:IsA("Model"), "Personagem nao encontrado em ServerStorage/Characters: " .. tostring(name))
	local model = source:Clone()
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
	local folder = model:FindFirstChild("Animations")
	local anim = folder and folder:FindFirstChild(animName)
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
