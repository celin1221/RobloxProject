--!strict
--[[
	StarterPlayer/StarterPlayerScripts/HollowPurpleClient.client.luau
	Cliente do sistema "Vazio Roxo" (Hollow Purple - Gojo Satoru / Setero):
	  - Captura a tecla R (ignorando chat/UI com gameProcessedEvent e telas de batalha por turnos)
	  - Calcula direcao 3D precisa da camera/mouse ignorando pastas de VFX e seguidores
	  - Envia CastRequest ao servidor e escuta StartCast / LaunchSync / HitTarget para todos os jogadores
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HollowPurpleFolder = ReplicatedStorage:WaitForChild("HollowPurple")
local Config = require(HollowPurpleFolder:WaitForChild("Config"))
local HollowPurpleVFX = require(HollowPurpleFolder:WaitForChild("HollowPurpleVFX"))

local localPlayer = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild(Config.RemoteName) :: RemoteEvent

local lastClientRequest = -999.0

local function isInTurnBasedBattle(): boolean
	local pg = localPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return false
	end
	local bg = pg:FindFirstChild("BattleGui")
	if bg and bg:IsA("ScreenGui") and bg.Enabled then
		-- Verifica se o container principal da batalha esta visivel
		for _, child in ipairs(bg:GetChildren()) do
			if child:IsA("GuiObject") and child.Visible then
				return true
			end
		end
	end
	return false
end

local function computeAimDirection(casterModel: Model): Vector3
	local cam = workspace.CurrentCamera
	local hrp = (casterModel:FindFirstChild("HumanoidRootPart") or casterModel.PrimaryPart) :: BasePart?
	if not cam then
		return if hrp then hrp.CFrame.LookVector else -Vector3.zAxis
	end

	local mousePos = UserInputService:GetMouseLocation()
	local unitRay = cam:ViewportPointToRay(mousePos.X, mousePos.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true

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

	local hit = workspace:Raycast(unitRay.Origin, unitRay.Direction * 600.0, params)
	local targetPoint = if hit then hit.Position else (unitRay.Origin + unitRay.Direction * 600.0)

	local originPos = if hrp
		then (hrp.Position + Vector3.new(0, 1.5, 0))
		else unitRay.Origin
	local delta = targetPoint - originPos
	-- Evita angulos extremos para baixo/cima que enterrariam o projetil logo na saida
	local flatMag = Vector3.new(delta.X, 0, delta.Z).Magnitude
	if flatMag > 0.5 then
		local clampedY = math.clamp(delta.Y, -flatMag * 0.35, flatMag * 0.45)
		return Vector3.new(delta.X, clampedY, delta.Z).Unit
	end
	return unitRay.Direction.Unit
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end
	if input.KeyCode ~= Config.ActivationKey then
		return
	end
	if isInTurnBasedBattle() then
		return
	end

	local now = os.clock()
	if (now - lastClientRequest) < Config.Cooldown then
		return
	end

	local char = localPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not hum or hum.Health <= 0 then
		return
	end

	lastClientRequest = now
	local aimDir = computeAimDirection(char)
	remote:FireServer("CastRequest", aimDir)
end)

remote.OnClientEvent:Connect(function(eventType: string, data: any)
	if typeof(data) ~= "table" then
		return
	end
	if eventType == "StartCast" then
		local casterModel = data.CasterModel :: Model?
		local castId = data.CastId :: string?
		local aimDir = data.AimDir :: Vector3?
		if casterModel and casterModel.Parent and typeof(castId) == "string" and typeof(aimDir) == "Vector3" then
			HollowPurpleVFX.PlayCast({
				CastId = castId,
				CasterModel = casterModel,
				AimDirection = aimDir,
				TimeScale = 1.0,
				EnableCameraAndLighting = true,
			})
		end
	elseif eventType == "LaunchSync" then
		local castId = data.CastId :: string?
		local launchOrigin = data.LaunchOrigin :: Vector3?
		local launchDir = data.LaunchDir :: Vector3?
		local maxDist = data.MaxTravelDist :: number?
		if
			typeof(castId) == "string"
			and typeof(launchOrigin) == "Vector3"
			and typeof(launchDir) == "Vector3"
			and typeof(maxDist) == "number"
		then
			HollowPurpleVFX.SyncLaunch(castId, launchOrigin, launchDir, maxDist)
		end
	elseif eventType == "HitTarget" then
		local hitPos = data.HitPos :: Vector3?
		if typeof(hitPos) == "Vector3" then
			HollowPurpleVFX.PlayHitImpact(hitPos)
		end
	end
end)
