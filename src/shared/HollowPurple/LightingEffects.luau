--!strict
--[[
	ReplicatedStorage/HollowPurple/LightingEffects.luau
	Controlador cinematografico de pos-processamento para Impact Frames estilo anime
	(preto e branco de alto contraste / invertido), pulsos de Bloom, atmosfera roxa
	e restauracao 100% segura por contagem de sessoes (zero vazamento no Lighting).
]]

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local CameraEffects = require(script.Parent:WaitForChild("CameraEffects"))

local LightingEffects = {}

local CC_NAME = "HollowPurple_ColorCorrection"
local BLOOM_NAME = "HollowPurple_Bloom"
local BLUR_NAME = "HollowPurple_Blur"

local activeSessions: { [string]: boolean } = {}
local sessionCount = 0
local sequenceToken = 0

local function getOrCreateStack(): (ColorCorrectionEffect, BloomEffect, BlurEffect)
	local cc = Lighting:FindFirstChild(CC_NAME) :: ColorCorrectionEffect?
	if not cc or not cc:IsA("ColorCorrectionEffect") then
		local newCC = Instance.new("ColorCorrectionEffect")
		newCC.Name = CC_NAME
		newCC.Brightness = 0
		newCC.Contrast = 0
		newCC.Saturation = 0
		newCC.TintColor = Color3.new(1, 1, 1)
		newCC.Enabled = true
		newCC.Parent = Lighting
		cc = newCC
	end

	local bloom = Lighting:FindFirstChild(BLOOM_NAME) :: BloomEffect?
	if not bloom or not bloom:IsA("BloomEffect") then
		local newBloom = Instance.new("BloomEffect")
		newBloom.Name = BLOOM_NAME
		newBloom.Intensity = 0
		newBloom.Size = 24
		newBloom.Threshold = 0.95
		newBloom.Enabled = true
		newBloom.Parent = Lighting
		bloom = newBloom
	end

	local blur = Lighting:FindFirstChild(BLUR_NAME) :: BlurEffect?
	if not blur or not blur:IsA("BlurEffect") then
		local newBlur = Instance.new("BlurEffect")
		newBlur.Name = BLUR_NAME
		newBlur.Size = 0
		newBlur.Enabled = true
		newBlur.Parent = Lighting
		blur = newBlur
	end

	return cc :: ColorCorrectionEffect, bloom :: BloomEffect, blur :: BlurEffect
end

function LightingEffects.BeginSession(sessionId: string)
	if not activeSessions[sessionId] then
		activeSessions[sessionId] = true
		sessionCount += 1
	end
	getOrCreateStack()
end

-- Pulso leve de Bloom durante conjuracao Azul/Vermelho
function LightingEffects.PulseBloom(intensity: number, duration: number, epicenter: Vector3?)
	local factor = CameraEffects.DistanceAttenuation(epicenter)
	if factor <= 0.05 then
		return
	end
	local _, bloom, _ = getOrCreateStack()
	bloom.Intensity = math.max(bloom.Intensity, intensity * factor)
	TweenService:Create(
		bloom,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Intensity = 0.25 * factor }
	):Play()
end

-- Impact Frame completo da Fase 3 (3.50s): 0.07s manga P&B alto contraste + 0.08s flash violeta + atmosfera roxa
function LightingEffects.PlayMergeImpactFrame(epicenter: Vector3?)
	local factor = CameraEffects.DistanceAttenuation(epicenter)
	if factor <= 0.08 then
		return
	end
	sequenceToken += 1
	local myToken = sequenceToken
	local cc, bloom, blur = getOrCreateStack()

	-- Sub-frame invertido instantaneo (0.025s) seguido do alto contraste P&B (total 0.07s)
	cc.Saturation = -1.0 * factor
	cc.Contrast = -2.2 * factor
	cc.Brightness = 0.22 * factor
	cc.TintColor = Color3.new(1, 1, 1)
	bloom.Intensity = 3.5 * factor
	bloom.Threshold = 0.65
	blur.Size = 9.0 * factor

	task.delay(0.025, function()
		if sequenceToken ~= myToken or not cc.Parent then
			return
		end
		cc.Saturation = -1.0 * factor
		cc.Contrast = 2.8 * factor
		cc.Brightness = 0.25 * factor
	end)

	-- Apos 0.07s: Flash violeta intenso (0.08s) -> atmosfera levemente escurecida e arroxeada
	task.delay(0.07, function()
		if sequenceToken ~= myToken or not cc.Parent then
			return
		end
		cc.Saturation = 0.15 * factor
		cc.Contrast = 0.65 * factor
		cc.Brightness = 0.18 * factor
		cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(210, 145, 255), factor)
		blur.Size = 4.0 * factor

		task.delay(0.08, function()
			if sequenceToken ~= myToken or not cc.Parent then
				return
			end
			TweenService:Create(
				cc,
				TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
				{
					Brightness = -0.05 * factor,
					Contrast = 0.22 * factor,
					Saturation = 0.12 * factor,
					TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(228, 200, 255), factor * 0.75),
				}
			):Play()
			TweenService:Create(
				bloom,
				TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
				{ Intensity = 1.15 * factor, Threshold = 0.82 }
			):Play()
			TweenService:Create(
				blur,
				TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = 0 }
			):Play()
		end)
	end)
end

-- Mini Impact Frame proporcional a distancia na Detonacao Final (Fase 5)
function LightingEffects.PlayDetonationFlash(epicenter: Vector3?)
	local factor = CameraEffects.DistanceAttenuation(epicenter)
	if factor <= 0.06 then
		return
	end
	sequenceToken += 1
	local myToken = sequenceToken
	local cc, bloom, blur = getOrCreateStack()

	local flashDur = 0.045 * factor + 0.015
	cc.Saturation = -0.85 * factor
	cc.Contrast = 2.1 * factor
	cc.Brightness = 0.20 * factor
	cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(235, 195, 255), factor)
	bloom.Intensity = 3.2 * factor
	blur.Size = 7.5 * factor

	task.delay(flashDur, function()
		if sequenceToken ~= myToken or not cc.Parent then
			return
		end
		TweenService:Create(
			cc,
			TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{
				Brightness = 0,
				Contrast = 0,
				Saturation = 0,
				TintColor = Color3.new(1, 1, 1),
			}
		):Play()
		TweenService:Create(
			bloom,
			TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ Intensity = 0, Threshold = 0.95 }
		):Play()
		TweenService:Create(
			blur,
			TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = 0 }
		):Play()
	end)
end

function LightingEffects.EndSession(sessionId: string, fadeDuration: number?)
	if activeSessions[sessionId] then
		activeSessions[sessionId] = nil
		sessionCount = math.max(0, sessionCount - 1)
	end
	if sessionCount == 0 then
		sequenceToken += 1
		local myToken = sequenceToken
		local dur = fadeDuration or 0.65
		local cc = Lighting:FindFirstChild(CC_NAME) :: ColorCorrectionEffect?
		local bloom = Lighting:FindFirstChild(BLOOM_NAME) :: BloomEffect?
		local blur = Lighting:FindFirstChild(BLUR_NAME) :: BlurEffect?

		if cc and cc:IsA("ColorCorrectionEffect") then
			TweenService:Create(
				cc,
				TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
				{ Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) }
			):Play()
		end
		if bloom and bloom:IsA("BloomEffect") then
			TweenService:Create(
				bloom,
				TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
				{ Intensity = 0 }
			):Play()
		end
		if blur and blur:IsA("BlurEffect") then
			TweenService:Create(
				blur,
				TweenInfo.new(dur * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = 0 }
			):Play()
		end

		task.delay(dur + 0.08, function()
			if sequenceToken == myToken and sessionCount == 0 then
				if cc and cc.Parent then
					cc:Destroy()
				end
				if bloom and bloom.Parent then
					bloom:Destroy()
				end
				if blur and blur.Parent then
					blur:Destroy()
				end
			end
		end)
	end
end

return LightingEffects
