--!strict
--[[
	ReplicatedStorage/Sukuna/SoundManager.luau
	Direcao de Audio, Abafamento Low-Pass (EqualizerSoundEffect), SFX Multicamadas
	e Vozes Sincronizadas com Legendas Cinematograficas Estilizadas na Tela:
	  - "Ryōiki Tenkai..."
	  - "Fukuma Mizushi"
	  - "Fuga"
	Respeita 100% a regra de Zero Emojis / Zero Simbolos Proibidos na UI.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(script.Parent:WaitForChild("Config"))
local Janitor = require(script.Parent:WaitForChild("Janitor"))

local SoundManager = {}

local subtitleJanitor: Janitor.JanitorInstance? = nil
local muffleJanitor: Janitor.JanitorInstance? = nil

local function createSound(
	parent: Instance,
	soundId: string,
	volume: number,
	pitch: number,
	jan: Janitor.JanitorInstance?
): Sound
	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume = volume
	s.PlaybackSpeed = pitch
	s.RollOffMaxDistance = 260
	s.RollOffMinDistance = 18
	s.Parent = parent
	if jan then
		jan:Add(s)
	else
		Debris:AddItem(s, 6.5)
	end
	return s
end

-- Abafamento momentaneo do som ambiente (Low-Pass via EqualizerSoundEffect) antes das vozes e explosoes
function SoundManager.MuffleAmbient(duration: number, strength: number?)
	if muffleJanitor then
		muffleJanitor:Cleanup()
		muffleJanitor = nil
	end
	local jan = Janitor.new()
	muffleJanitor = jan

	local intensity = math.clamp(strength or 1.0, 0.2, 1.25)
	local eq = Instance.new("EqualizerSoundEffect")
	eq.Name = "SukunaLowPassMuffle"
	eq.LowGain = 2.5 * intensity
	eq.MidGain = 0
	eq.HighGain = 0
	eq.Priority = 10
	eq.Parent = SoundService
	jan:Add(eq)

	local inTween = TweenService:Create(
		eq,
		TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			MidGain = -18.0 * intensity,
			HighGain = -34.0 * intensity,
		}
	)
	jan:Add(inTween)
	inTween:Play()

	local holdTime = math.max(0.06, duration - 0.24)
	jan:Delay(holdTime, function()
		if not eq.Parent then
			return
		end
		local outTween = TweenService:Create(
			eq,
			TweenInfo.new(0.24, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{
				LowGain = 0,
				MidGain = 0,
				HighGain = 0,
			}
		)
		jan:Add(outTween)
		outTween:Play()
		outTween.Completed:Once(function()
			if muffleJanitor == jan then
				muffleJanitor = nil
			end
			jan:Cleanup()
		end)
	end)
end

-- Legenda cinematografica estilizada na parte inferior-central da tela (sem emojis/simbolos proibidos)
function SoundManager.ShowSubtitle(primaryLine: string, subCaption: string?, holdDuration: number, accentColor: Color3?)
	local player = Players.LocalPlayer
	local pg = player and player:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return
	end

	if subtitleJanitor then
		subtitleJanitor:Cleanup()
		subtitleJanitor = nil
	end
	local jan = Janitor.new()
	subtitleJanitor = jan

	local accent = accentColor or Config.Colors.CrimsonBright

	local sg = Instance.new("ScreenGui")
	sg.Name = "SukunaCinematicSubtitle"
	sg.DisplayOrder = 24
	sg.IgnoreGuiInset = true
	sg.ResetOnSpawn = false
	sg.Parent = pg
	jan:Add(sg)

	local container = Instance.new("Frame")
	container.Name = "SubtitleBar"
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Position = UDim2.fromScale(0.5, 0.80)
	container.Size = UDim2.fromScale(0.46, 0.088)
	container.BackgroundColor3 = Color3.fromRGB(10, 6, 12)
	container.BackgroundTransparency = 0.22
	container.BorderSizePixel = 0
	container.Parent = sg

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MaxSize = Vector2.new(640, 82)
	sizeConstraint.MinSize = Vector2.new(280, 52)
	sizeConstraint.Parent = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.22, 0)
	corner.Parent = container

	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 1.8
	stroke.Transparency = 0.18
	stroke.Parent = container

	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 8, 14)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(12, 6, 12)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(28, 8, 14)),
	})
	grad.Rotation = 0
	grad.Parent = container

	local topHairline = Instance.new("Frame")
	topHairline.Name = "AccentLine"
	topHairline.AnchorPoint = Vector2.new(0.5, 0)
	topHairline.Position = UDim2.fromScale(0.5, 0.08)
	topHairline.Size = UDim2.fromScale(0.05, 0.035)
	topHairline.BackgroundColor3 = accent
	topHairline.BorderSizePixel = 0
	topHairline.Parent = container

	local mainLbl = Instance.new("TextLabel")
	mainLbl.Name = "VoiceLine"
	mainLbl.AnchorPoint = Vector2.new(0.5, 0.5)
	mainLbl.Position = UDim2.fromScale(0.5, if subCaption then 0.43 else 0.52)
	mainLbl.Size = UDim2.fromScale(0.92, if subCaption then 0.50 else 0.64)
	mainLbl.BackgroundTransparency = 1
	mainLbl.Font = Enum.Font.GothamBlack
	mainLbl.Text = primaryLine
	mainLbl.TextColor3 = Color3.fromRGB(255, 246, 246)
	mainLbl.TextScaled = true
	mainLbl.TextTransparency = 1
	mainLbl.Parent = container

	local mainStroke = Instance.new("UIStroke")
	mainStroke.Color = Color3.fromRGB(8, 3, 6)
	mainStroke.Thickness = 2.4
	mainStroke.Transparency = 1
	mainStroke.Parent = mainLbl

	local subLbl: TextLabel? = nil
	local subStroke: UIStroke? = nil
	if subCaption and #subCaption > 0 then
		local sl = Instance.new("TextLabel")
		sl.Name = "SubCaption"
		sl.AnchorPoint = Vector2.new(0.5, 0.5)
		sl.Position = UDim2.fromScale(0.5, 0.79)
		sl.Size = UDim2.fromScale(0.88, 0.27)
		sl.BackgroundTransparency = 1
		sl.Font = Enum.Font.GothamBold
		sl.Text = string.upper(subCaption)
		sl.TextColor3 = accent
		sl.TextScaled = true
		sl.TextTransparency = 1
		sl.Parent = container
		local ss = Instance.new("UIStroke")
		ss.Color = Color3.fromRGB(8, 3, 6)
		ss.Thickness = 1.6
		ss.Transparency = 1
		ss.Parent = sl
		subLbl = sl
		subStroke = ss
	end

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 0.88
	uiScale.Parent = container

	jan:Add(TweenService:Create(uiScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.0 })):Play()
	jan:Add(TweenService:Create(topHairline, TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.fromScale(0.76, 0.035) })):Play()
	jan:Add(TweenService:Create(mainLbl, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 })):Play()
	jan:Add(TweenService:Create(mainStroke, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 0 })):Play()
	if subLbl and subStroke then
		jan:Add(TweenService:Create(subLbl, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0.08 })):Play()
		jan:Add(TweenService:Create(subStroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 0.15 })):Play()
	end

	local fadeStart = math.max(0.20, holdDuration - 0.24)
	jan:Delay(fadeStart, function()
		if not sg.Parent then
			return
		end
		jan:Add(TweenService:Create(uiScale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.94 })):Play()
		jan:Add(TweenService:Create(container, TweenInfo.new(0.22), { BackgroundTransparency = 1 })):Play()
		jan:Add(TweenService:Create(stroke, TweenInfo.new(0.22), { Transparency = 1 })):Play()
		jan:Add(TweenService:Create(topHairline, TweenInfo.new(0.22), { BackgroundTransparency = 1 })):Play()
		jan:Add(TweenService:Create(mainLbl, TweenInfo.new(0.22), { TextTransparency = 1 })):Play()
		local endTw = jan:Add(TweenService:Create(mainStroke, TweenInfo.new(0.22), { Transparency = 1 }))
		endTw:Play()
		if subLbl and subStroke then
			jan:Add(TweenService:Create(subLbl, TweenInfo.new(0.22), { TextTransparency = 1 })):Play()
			jan:Add(TweenService:Create(subStroke, TweenInfo.new(0.22), { Transparency = 1 })):Play()
		end
		endTw.Completed:Once(function()
			if subtitleJanitor == jan then
				subtitleJanitor = nil
			end
			jan:Cleanup()
		end)
	end)
end

-- Toca linha de voz customizada (quando preenchida em Config.Assets) + presenca dramatica + legenda sincronizada
function SoundManager.PlayVoiceCue(
	parent: Instance,
	voiceSlotId: string?,
	subtitleText: string,
	subCaption: string?,
	holdDuration: number,
	accentColor: Color3?,
	jan: Janitor.JanitorInstance?
)
	SoundManager.ShowSubtitle(subtitleText, subCaption, holdDuration, accentColor)
	if Config.HasCustomAsset(voiceSlotId) then
		local resolved = Config.ResolveAsset(voiceSlotId, "")
		local voice = createSound(parent, resolved, 1.15, 1.0, jan)
		local rev = Instance.new("ReverbSoundEffect")
		rev.DecayTime = 1.4
		rev.WetLevel = -9
		rev.DryLevel = 0
		rev.Parent = voice
		voice:Play()
	else
		-- Presenca grave amaldicoada sutil quando o slot de voz ainda estiver ""
		local cue = createSound(parent, Config.Fallbacks.SfxCharge, 0.36, 0.58, jan)
		cue:Play()
	end
end

-- 1. SFX Desmantelar: lamina rasgando o ar + estalo metalico seco
function SoundManager.PlayDesmantelarCharge(emitterPart: Instance, jan: Janitor.JanitorInstance?)
	createSound(emitterPart, Config.Fallbacks.SfxCharge, 0.34, 1.32, jan):Play()
end

function SoundManager.PlayDesmantelarRelease(emitterPart: Instance, jan: Janitor.JanitorInstance?)
	local slashId = Config.ResolveAsset(Config.Assets.SlashSfxId, Config.Fallbacks.SfxRelease)
	createSound(emitterPart, slashId, 0.52, 1.36, jan):Play()
	createSound(emitterPart, slashId, 0.36, 1.72, jan):Play()
end

function SoundManager.PlayDesmantelarImpact(emitterPart: Instance, jan: Janitor.JanitorInstance?)
	local hitId = Config.ResolveAsset(Config.Assets.SlashSfxId, Config.Fallbacks.SfxImpact)
	createSound(emitterPart, hitId, 0.56, 1.24, jan):Play()
	createSound(emitterPart, Config.Fallbacks.SfxRelease, 0.38, 1.65, jan):Play()
end

-- 2. SFX Clivar: impacto grave de palma -> zumbido tenso da teia -> rajada frenetica de cortes em estereo
function SoundManager.PlayClivarPalmAndWeb(emitterPart: Instance, jan: Janitor.JanitorInstance?)
	createSound(emitterPart, Config.Fallbacks.SfxImpactHeavy, 0.48, 0.72, jan):Play()
	local webHum = createSound(emitterPart, Config.Fallbacks.SfxCharge, 0.44, 0.68, jan)
	webHum:Play()
end

function SoundManager.PlayClivarFlurry(emitterPart: Instance, slashCount: number, interval: number, jan: Janitor.JanitorInstance?)
	local heavyId = Config.ResolveAsset(Config.Assets.HeavySlashSfxId, Config.Fallbacks.SfxImpactHeavy)
	local bladeId = Config.ResolveAsset(Config.Assets.SlashSfxId, Config.Fallbacks.SfxRelease)
	createSound(emitterPart, heavyId, 0.62, 0.94, jan):Play()
	for i = 1, math.min(slashCount, 10) do
		local delaySec = (i - 1) * interval
		local function fireSlice()
			if not emitterPart.Parent then
				return
			end
			local pitch = 1.12 + ((i % 4) * 0.14)
			createSound(emitterPart, bladeId, 0.32, pitch, jan):Play()
		end
		if jan then
			jan:Delay(delaySec, fireSlice)
		else
			task.delay(delaySec, fireSlice)
		end
	end
end

-- 3. SFX Fortificacao: grave crescente + explosao densa de pressao espiritual
function SoundManager.PlayFortificacaoCharge(emitterPart: Instance, jan: Janitor.JanitorInstance?)
	createSound(emitterPart, Config.Fallbacks.SfxCharge, 0.46, 0.64, jan):Play()
end

function SoundManager.PlayFortificacaoBurst(emitterPart: Instance, jan: Janitor.JanitorInstance?)
	createSound(emitterPart, Config.Fallbacks.SfxReleaseHeavy, 0.58, 0.76, jan):Play()
	createSound(emitterPart, Config.Fallbacks.SfxImpactHeavy, 0.44, 0.62, jan):Play()
end

-- 4. SFX Santuario Malevolente: Parte A ("Ryōiki Tenkai..."), Parte B ("Fukuma Mizushi" + sino/sub-bass), Parte C (cortes 3D)
function SoundManager.PlaySantuarioPartA(emitterPart: Instance, jan: Janitor.JanitorInstance?)
	SoundManager.MuffleAmbient(0.95, 1.0)
	SoundManager.PlayVoiceCue(
		emitterPart,
		Config.Assets.RyoikiTenkaiVoiceId,
		"Ry\u{014d}iki Tenkai...",
		"Expans\u{e3}o de Dom\u{ed}nio",
		0.92,
		Config.Colors.CrimsonBright,
		jan
	)
end

function SoundManager.PlaySantuarioPartB(emitterPart: Instance, jan: Janitor.JanitorInstance?)
	SoundManager.MuffleAmbient(0.75, 0.85)
	SoundManager.PlayVoiceCue(
		emitterPart,
		Config.Assets.FukumaMizushiVoiceId,
		"Fukuma Mizushi",
		"Santu\u{e1}rio Malevolente",
		1.45,
		Config.Colors.SlashWhite,
		jan
	)
	-- Badalar sinistro de templo + sub-bass sismico
	local bellId = Config.ResolveAsset(Config.Assets.ShrineBellSfxId, Config.Fallbacks.SfxImpactHeavy)
	local bell = createSound(emitterPart, bellId, 0.68, 0.46, jan)
	local rev = Instance.new("ReverbSoundEffect")
	rev.DecayTime = 3.2
	rev.Density = 1.0
	rev.WetLevel = -3
	rev.Parent = bell
	bell:Play()
	createSound(emitterPart, Config.Fallbacks.SfxReleaseHeavy, 0.56, 0.52, jan):Play()
end

function SoundManager.PlayDomainSlashVolley(emitterPart: Instance, jan: Janitor.JanitorInstance?)
	local bladeId = Config.ResolveAsset(Config.Assets.SlashSfxId, Config.Fallbacks.SfxRelease)
	local hitId = Config.ResolveAsset(Config.Assets.HeavySlashSfxId, Config.Fallbacks.SfxImpact)
	createSound(emitterPart, hitId, 0.52, 1.04, jan):Play()
	for i = 1, 6 do
		local d = (i - 1) * 0.055
		local function tickBlade()
			if not emitterPart.Parent then
				return
			end
			createSound(emitterPart, bladeId, 0.34, 1.18 + (i % 3) * 0.18, jan):Play()
		end
		if jan then
			jan:Delay(d, tickBlade)
		else
			task.delay(d, tickBlade)
		end
	end
end

-- 5. SFX Fuga: Fase 1 ("Fuga" + ignicao), Fase 2 (tensao do arco), Fase 3 (disparo supersônico), Fase 4 (silencio -> explosao termobarica)
function SoundManager.PlayFugaOpen(emitterPart: Instance, jan: Janitor.JanitorInstance?)
	SoundManager.MuffleAmbient(0.78, 0.95)
	SoundManager.PlayVoiceCue(
		emitterPart,
		Config.Assets.FugaVoiceId,
		"Fuga",
		"Abrir  \u{b7}  Flecha de Fogo",
		1.05,
		Config.Colors.FireGold,
		jan
	)
	local ignId = Config.ResolveAsset(Config.Assets.FireIgniteSfxId, Config.Fallbacks.SfxCharge)
	createSound(emitterPart, ignId, 0.52, 0.88, jan):Play()
end

function SoundManager.PlayFugaBowDraw(emitterPart: Instance, jan: Janitor.JanitorInstance?)
	local drawSnd = createSound(emitterPart, Config.Fallbacks.SfxCharge, 0.54, 1.18, jan)
	drawSnd:Play()
	TweenService:Create(drawSnd, TweenInfo.new(0.72, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { PlaybackSpeed = 1.62, Volume = 0.66 }):Play()
end

function SoundManager.PlayFugaLaunch(emitterPart: Instance, jan: Janitor.JanitorInstance?)
	local launchId = Config.ResolveAsset(Config.Assets.FireArrowLaunchSfxId, Config.Fallbacks.SfxReleaseHeavy)
	createSound(emitterPart, launchId, 0.66, 1.12, jan):Play()
	createSound(emitterPart, Config.Fallbacks.SfxRelease, 0.48, 1.48, jan):Play()
end

function SoundManager.PlayFugaThermobaricImpact(emitterPart: Instance, jan: Janitor.JanitorInstance?)
	-- Fracao de silencio absoluto (0.08s hitstop) seguida pelo estrondo termobarico!
	SoundManager.MuffleAmbient(0.14, 1.2)
	local function detonate()
		if not emitterPart.Parent then
			return
		end
		local expId = Config.ResolveAsset(Config.Assets.ThermobaricExplosionSfxId, Config.Fallbacks.SfxImpactHeavy)
		local boomLow = createSound(emitterPart, expId, 0.82, 0.58, jan)
		local rev = Instance.new("ReverbSoundEffect")
		rev.DecayTime = 2.8
		rev.WetLevel = -4
		rev.Parent = boomLow
		boomLow:Play()

		createSound(emitterPart, expId, 0.72, 0.92, jan):Play()
		createSound(emitterPart, Config.Fallbacks.SfxReleaseHeavy, 0.58, 0.68, jan):Play()
	end
	if jan then
		jan:Delay(0.08, detonate)
	else
		task.delay(0.08, detonate)
	end
end

function SoundManager.Cleanup()
	if subtitleJanitor then
		subtitleJanitor:Cleanup()
		subtitleJanitor = nil
	end
	if muffleJanitor then
		muffleJanitor:Cleanup()
		muffleJanitor = nil
	end
end

return SoundManager
