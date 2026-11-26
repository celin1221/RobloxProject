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
local RunService = game:GetService("RunService")
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

--============================================================================
-- 5. AUDIO & LEGENDA TERMICA DE 6 FASES DO FUGA (JJK Temporada 2)
--   0.00s: Filtro Equalizer Low-Pass instantaneo (vacuo tenso)
--   0.35s: Voz "Fuga" + Legenda minimalista 「 竈  ·  FUGA 」 com glitch/tremor termico
--   0.50s: Estalo seco de ignicao + rugido grave de fornalha abrindo
--   1.45s: Pressao crescente de turbina/fornalha comprimida + corda incandescente esticando
--   3.30s: Sonic boom + rugido de jato de fogo cortando o ar (efeito Doppler)
--   3.85s: Silencio subito de 0.12s (apenas sub-grave abafado na implosao de vacuo)
--   4.05s: Estrondo termobarico ensurdecedor em 4 camadas (sub-bass, crack seco, tempestade de fogo, estalos)
--============================================================================
function SoundManager.ShowFugaSubtitle(holdDuration: number)
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

	local sg = Instance.new("ScreenGui")
	sg.Name = "SukunaFugaThermalSubtitle"
	sg.DisplayOrder = 25
	sg.IgnoreGuiInset = true
	sg.ResetOnSpawn = false
	sg.Parent = pg
	jan:Add(sg)

	local holder = Instance.new("Frame")
	holder.Name = "ThermalLegendFrame"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.81)
	holder.Size = UDim2.fromScale(0.42, 0.082)
	holder.BackgroundColor3 = Color3.fromRGB(10, 6, 6)
	holder.BackgroundTransparency = 0.28
	holder.BorderSizePixel = 0
	holder.Parent = sg

	local sizeCon = Instance.new("UISizeConstraint")
	sizeCon.MaxSize = Vector2.new(560, 76)
	sizeCon.MinSize = Vector2.new(260, 48)
	sizeCon.Parent = holder

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.18, 0)
	corner.Parent = holder

	local stroke = Instance.new("UIStroke")
	stroke.Color = Config.Colors.ThermalCoreEnd
	stroke.Thickness = 1.6
	stroke.Transparency = 0.22
	stroke.Parent = holder

	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(36, 12, 6)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(12, 6, 6)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(36, 12, 6)),
	})
	grad.Parent = holder

	-- Linha incandescente fina superior
	local emberLine = Instance.new("Frame")
	emberLine.AnchorPoint = Vector2.new(0.5, 0)
	emberLine.Position = UDim2.fromScale(0.5, 0.06)
	emberLine.Size = UDim2.fromScale(0.04, 0.035)
	emberLine.BackgroundColor3 = Config.Colors.ThermalFlameStart
	emberLine.BorderSizePixel = 0
	emberLine.Parent = holder

	-- Sombra fantasma cromatica laranja para efeito de distorcao/glitch termico sutil
	local ghostLbl = Instance.new("TextLabel")
	ghostLbl.Name = "ThermalGhost"
	ghostLbl.AnchorPoint = Vector2.new(0.5, 0.5)
	ghostLbl.Position = UDim2.fromScale(0.5, 0.44)
	ghostLbl.Size = UDim2.fromScale(0.92, 0.52)
	ghostLbl.BackgroundTransparency = 1
	ghostLbl.Font = Enum.Font.GothamBlack
	ghostLbl.Text = "\u{300c} \u{7ac8}  \u{b7}  FUGA \u{300d}"
	ghostLbl.TextColor3 = Config.Colors.ThermalFlameStart
	ghostLbl.TextScaled = true
	ghostLbl.TextTransparency = 0.62
	ghostLbl.Parent = holder

	local mainLbl = Instance.new("TextLabel")
	mainLbl.Name = "MainTitle"
	mainLbl.AnchorPoint = Vector2.new(0.5, 0.5)
	mainLbl.Position = UDim2.fromScale(0.5, 0.44)
	mainLbl.Size = UDim2.fromScale(0.92, 0.52)
	mainLbl.BackgroundTransparency = 1
	mainLbl.Font = Enum.Font.GothamBlack
	mainLbl.Text = "\u{300c} \u{7ac8}  \u{b7}  FUGA \u{300d}"
	mainLbl.TextColor3 = Config.Colors.ThermalCoreStart
	mainLbl.TextScaled = true
	mainLbl.TextTransparency = 1
	mainLbl.Parent = holder

	local mainStroke = Instance.new("UIStroke")
	mainStroke.Color = Color3.fromRGB(14, 4, 2)
	mainStroke.Thickness = 2.4
	mainStroke.Transparency = 1
	mainStroke.Parent = mainLbl

	local subLbl = Instance.new("TextLabel")
	subLbl.Name = "SubCaption"
	subLbl.AnchorPoint = Vector2.new(0.5, 0.5)
	subLbl.Position = UDim2.fromScale(0.5, 0.80)
	subLbl.Size = UDim2.fromScale(0.86, 0.25)
	subLbl.BackgroundTransparency = 1
	subLbl.Font = Enum.Font.GothamBold
	subLbl.Text = "CHAMA DIVINA  \u{b7}  ABRIR"
	subLbl.TextColor3 = Config.Colors.ThermalCoreEnd
	subLbl.TextScaled = true
	subLbl.TextTransparency = 1
	subLbl.Parent = holder

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 0.90
	uiScale.Parent = holder

	jan:Add(TweenService:Create(uiScale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.0 })):Play()
	jan:Add(TweenService:Create(emberLine, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.fromScale(0.80, 0.035) })):Play()
	jan:Add(TweenService:Create(mainLbl, TweenInfo.new(0.12), { TextTransparency = 0 })):Play()
	jan:Add(TweenService:Create(mainStroke, TweenInfo.new(0.12), { Transparency = 0 })):Play()
	jan:Add(TweenService:Create(subLbl, TweenInfo.new(0.18), { TextTransparency = 0.08 })):Play()

	-- Glitch / tremor termico sutil em tempo real (primeiros 0.22s mais intensos, depois reverberacao de calor suave)
	local t0 = os.clock()
	if RunService:IsClient() then
		jan:Connect(RunService.RenderStepped, function()
			if not holder.Parent then
				return
			end
			local el = os.clock() - t0
			local burst = if el < 0.22 then (1 - el / 0.22) * 3.2 else 0.75
			local jx = math.noise(el * 36, 4.2, 0) * 0.006 * burst
			local jy = math.noise(el * 42, 11.7, 0) * 0.018 * burst
			ghostLbl.Position = UDim2.fromScale(0.5 + jx * 1.9, 0.44 + jy * 1.6)
			mainLbl.Position = UDim2.fromScale(0.5 + jx * 0.45, 0.44 + jy * 0.45)
			stroke.Color = Config.Colors.ThermalCoreEnd:Lerp(Config.Colors.ThermalFlameStart, 0.5 + 0.5 * math.noise(el * 16, 1.3, 0))
		end)
	end

	local fadeAt = math.max(0.25, holdDuration - 0.28)
	jan:Delay(fadeAt, function()
		if not sg.Parent then
			return
		end
		jan:Add(TweenService:Create(holder, TweenInfo.new(0.26), { BackgroundTransparency = 1 })):Play()
		jan:Add(TweenService:Create(stroke, TweenInfo.new(0.26), { Transparency = 1 })):Play()
		jan:Add(TweenService:Create(emberLine, TweenInfo.new(0.26), { BackgroundTransparency = 1 })):Play()
		jan:Add(TweenService:Create(ghostLbl, TweenInfo.new(0.26), { TextTransparency = 1 })):Play()
		jan:Add(TweenService:Create(subLbl, TweenInfo.new(0.26), { TextTransparency = 1 })):Play()
		jan:Add(TweenService:Create(mainLbl, TweenInfo.new(0.26), { TextTransparency = 1 })):Play()
		local endTw = jan:Add(TweenService:Create(mainStroke, TweenInfo.new(0.26), { Transparency = 1 }))
		endTw:Play()
		endTw.Completed:Once(function()
			if subtitleJanitor == jan then
				subtitleJanitor = nil
			end
			jan:Cleanup()
		end)
	end)
end

function SoundManager.PlayFugaVoice(emitterPart: Instance, jan: Janitor.JanitorInstance?)
	SoundManager.ShowFugaSubtitle(1.35)
	local customVoice = if Config.Assets.Fuga and Config.HasCustomAsset(Config.Assets.Fuga.VoiceId)
		then Config.Assets.Fuga.VoiceId
		else Config.Assets.FugaVoiceId

	if Config.HasCustomAsset(customVoice) then
		local voice = createSound(emitterPart, Config.ResolveAsset(customVoice, ""), 1.25, 1.0, jan)
		local rev = Instance.new("ReverbSoundEffect")
		rev.DecayTime = 1.35
		rev.WetLevel = -8
		rev.DryLevel = 0
		rev.Parent = voice
		voice:Play()
	else
		local cue = createSound(emitterPart, Config.Fallbacks.SfxCharge, 0.38, 0.54, jan)
		cue:Play()
	end
end

function SoundManager.PlayFugaIgniteFurnace(emitterPart: Instance, jan: Janitor.JanitorInstance?): Sound
	local ignId = Config.ResolveFugaAsset(
		Config.Assets.Fuga and Config.Assets.Fuga.IgniteSfxId,
		Config.Assets.FireIgniteSfxId,
		Config.Fallbacks.SfxImpact
	)
	local furId = Config.ResolveFugaAsset(
		Config.Assets.Fuga and Config.Assets.Fuga.FurnaceLoopSfxId,
		Config.Assets.FireIgniteSfxId,
		Config.Fallbacks.SfxCharge
	)
	-- Estalo seco de ignicao
	createSound(emitterPart, ignId, 0.58, 1.52, jan):Play()
	-- Rugido grave de fornalha abrindo
	local furnace = createSound(emitterPart, furId, 0.62, 0.62, jan)
	furnace:Play()
	return furnace
end

function SoundManager.PlayFugaBowTension(emitterPart: Instance, duration: number, jan: Janitor.JanitorInstance?): (Sound, Sound)
	local bowId = Config.ResolveFugaAsset(
		Config.Assets.Fuga and Config.Assets.Fuga.BowTensionSfxId,
		nil,
		Config.Fallbacks.SfxCharge
	)
	-- Turbina/fornalha comprimida
	local turbine = createSound(emitterPart, bowId, 0.42, 0.74, jan)
	turbine.Looped = true
	turbine:Play()
	TweenService:Create(turbine, TweenInfo.new(duration, Enum.EasingStyle.Exponential, Enum.EasingDirection.In), {
		PlaybackSpeed = 1.68,
		Volume = 0.78,
	}):Play()

	-- Corda incandescente esticando no limite
	local stringStretch = createSound(emitterPart, Config.Fallbacks.SfxRelease, 0.30, 1.15, jan)
	stringStretch:Play()
	TweenService:Create(stringStretch, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		PlaybackSpeed = 1.92,
		Volume = 0.56,
	}):Play()
	return turbine, stringStretch
end

function SoundManager.PlayFugaSonicLaunch(emitterPart: Instance, flightDuration: number, jan: Janitor.JanitorInstance?): Sound
	local launchId = Config.ResolveFugaAsset(
		Config.Assets.Fuga and Config.Assets.Fuga.SonicLaunchSfxId,
		Config.Assets.FireArrowLaunchSfxId,
		Config.Fallbacks.SfxReleaseHeavy
	)
	-- Sonic boom agudo + grave
	createSound(emitterPart, Config.Fallbacks.SfxImpactHeavy, 0.76, 1.38, jan):Play()
	createSound(emitterPart, launchId, 0.80, 1.18, jan):Play()

	-- Rugido de jato de fogo cortando o ar com efeito Doppler rapido!
	local jet = createSound(emitterPart, Config.Fallbacks.SfxRelease, 0.68, 1.82, jan)
	jet.Looped = true
	jet:Play()
	TweenService:Create(jet, TweenInfo.new(flightDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		PlaybackSpeed = 0.88,
		Volume = 0.52,
	}):Play()
	return jet
end

function SoundManager.PlayFugaVacuumImplosion(emitterPart: Instance, jan: Janitor.JanitorInstance?)
	-- Silencio subito de 0.12s com filtro Low-Pass profundo + zumbido sub-grave abafado
	SoundManager.MuffleAmbient(0.20, 1.25)
	local subId = Config.ResolveFugaAsset(
		Config.Assets.Fuga and Config.Assets.Fuga.VacuumSubSfxId,
		nil,
		Config.Fallbacks.SfxImpactHeavy
	)
	local subHum = createSound(emitterPart, subId, 0.44, 0.34, jan)
	local eq = Instance.new("EqualizerSoundEffect")
	eq.LowGain = 6
	eq.MidGain = -24
	eq.HighGain = -48
	eq.Parent = subHum
	subHum:Play()
end

function SoundManager.PlayFugaThermobaricDetonation(
	emitterPart: Instance,
	roarDuration: number,
	jan: Janitor.JanitorInstance?
)
	local boomId = Config.ResolveFugaAsset(
		Config.Assets.Fuga and Config.Assets.Fuga.ThermobaricBoomSfxId,
		Config.Assets.ThermobaricExplosionSfxId,
		Config.Fallbacks.SfxImpactHeavy
	)
	local stormId = Config.ResolveFugaAsset(
		Config.Assets.Fuga and Config.Assets.Fuga.FirestormRoarSfxId,
		nil,
		Config.Fallbacks.SfxReleaseHeavy
	)

	-- Camada 1: Sub-bass termobarico profundo com reverberacao colossal
	local subBoom = createSound(emitterPart, boomId, 0.96, 0.44, jan)
	subBoom.RollOffMaxDistance = 420
	local rev = Instance.new("ReverbSoundEffect")
	rev.DecayTime = 3.8
	rev.Density = 1.0
	rev.WetLevel = -2
	rev.Parent = subBoom
	subBoom:Play()

	-- Camada 2: Explosao seca aguda rasgando o silencio
	local crackBoom = createSound(emitterPart, Config.Fallbacks.SfxImpact, 0.84, 1.22, jan)
	crackBoom.RollOffMaxDistance = 380
	crackBoom:Play()

	-- Camada 3: Impacto medio-grave encorpado
	local midBoom = createSound(emitterPart, boomId, 0.88, 0.82, jan)
	midBoom.RollOffMaxDistance = 380
	midBoom:Play()

	-- Camada 4: Rugido continuo de tempestade de fogo + estalos de destruicao
	local storm = createSound(emitterPart, stormId, 0.72, 0.56, jan)
	storm.Looped = true
	storm.RollOffMaxDistance = 360
	storm:Play()

	if jan then
		for i = 1, 5 do
			jan:Delay(0.28 * i, function()
				if emitterPart.Parent then
					createSound(emitterPart, Config.Fallbacks.SfxImpact, 0.34, 0.72 + (i % 3) * 0.22, jan):Play()
				end
			end)
		end
		jan:Delay(math.max(0.5, roarDuration - 1.3), function()
			if storm.Parent then
				local fadeTw = TweenService:Create(storm, TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
					Volume = 0,
					PlaybackSpeed = 0.38,
				})
				jan:Add(fadeTw)
				fadeTw:Play()
			end
		end)
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
