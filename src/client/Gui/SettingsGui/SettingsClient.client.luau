--[[
	SettingsClient (GDD secao 10 - Configuracoes)
	Abre pelo botao de engrenagem do HUD (UI.open("Settings")).
	- Musica: liga/desliga e volume.
	- Efeitos sonoros: liga/desliga e volume.
	- Efeitos do mapa: particulas, luzes decorativas e animacoes de cenario (PC fraco e celular).
	Aplica na hora (ClientSettings) e salva no perfil (servidor valida em SettingsService).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local gui = script.Parent
local UI = require(ReplicatedStorage:WaitForChild("UI"))
local CS = require(ReplicatedStorage:WaitForChild("ClientSettings"))
local T = UI.Theme

CS.start()

local canvas = UI.screen(gui)
gui.DisplayOrder = 10
local win = UI.window(canvas, { Name = "SettingsWindow", Title = "CONFIGURA\u{c7}\u{d5}ES", Icon = "gear", HeaderColor = "grey", Size = UDim2.fromScale(0.8, 0.84), Aspect = 1.7, MaxSize = Vector2.new(900, 600) })
local body = win.Body
local list = UI.frame(body, { Name = "Rows", Size = UDim2.fromScale(1, 1) })
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0.03, 0)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local refreshers = {}

local function toggleButton(face, key)
	local b
	b = UI.button(face, { Name = "Toggle", Text = "LIGADO", Color = "green", Size = UDim2.fromScale(0.19, 0.62), Position = UDim2.fromScale(0.975, 0.5), AnchorPoint = Vector2.new(1, 0.5), Role = "Small",
		OnClick = function()
			CS.set(key, not CS.Current[key])
		end,
	})
	UI.clampHeight(b, T.TouchMin, 50)
	table.insert(refreshers, function()
		local on = CS.Current[key]
		UI.setText(b, if on then "LIGADO" else "DESLIGADO")
		UI.paint(b, if on then "green" else "grey")
	end)
	return b
end

local function row(order, icon, title, desc, color)
	local holder, face = UI.panel(list, { Name = "Row" .. order, Size = UDim2.fromScale(1, 0.225), Color = "panelAlt", Corner = 0.22, LayoutOrder = order })
	UI.icon(face, icon, { Name = "Icon", Size = UDim2.fromScale(0.12, 0.8), Position = UDim2.fromScale(0.015, 0.1), AspectAxis = Enum.DominantAxis.Height })
	UI.text(face, title, { Name = "Title", Size = UDim2.fromScale(0.3, 0.4), Position = UDim2.fromScale(0.14, 0.1), Role = "Body", AlignX = Enum.TextXAlignment.Left })
	UI.text(face, desc, { Name = "Desc", Size = UDim2.fromScale(0.3, 0.34), Position = UDim2.fromScale(0.14, 0.56), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.4, Wrap = true })
	return face
end

local function volumeRow(order, icon, title, desc, onKey, volKey, color)
	local face = row(order, icon, title, desc, color)
	local pct = UI.text(face, "", { Name = "Percent", Size = UDim2.fromScale(0.09, 0.42), Position = UDim2.fromScale(0.77, 0.5), AnchorPoint = Vector2.new(1, 0.5), Role = "Small", AlignX = Enum.TextXAlignment.Center })
	local _, setSlider = UI.slider(face, { Name = "Volume", Size = UDim2.fromScale(0.22, 0.5), Position = UDim2.fromScale(0.665, 0.5), AnchorPoint = Vector2.new(1, 0.5), Color = color }, function(v, done)
		pct.Text = math.floor(v * 100 + 0.5) .. "%"
		CS.set(volKey, v * 100)
		if done then
			UI.play("click")
		end
	end)
	toggleButton(face, onKey)
	table.insert(refreshers, function()
		local v = CS.Current[volKey] / 100
		setSlider(v)
		pct.Text = CS.Current[volKey] .. "%"
	end)
end

volumeRow(1, "music", "M\u{fa}sica", "Mapa e batalha", "MusicOn", "MusicVolume", "gems")
volumeRow(2, "speaker", "Efeitos sonoros", "Golpes e bot\u{f5}es", "SfxOn", "SfxVolume", "blue")
local fxFace = row(3, "sparkle", "Efeitos do mapa", "Part\u{ed}culas, luzes e anima\u{e7}\u{f5}es do cen\u{e1}rio. Desligue em PC fraco ou celular.", "purple")
fxFace.Desc.Size = UDim2.fromScale(0.6, 0.42)
toggleButton(fxFace, "MapFx")

local auraFace = row(4, "star", "Auras dos personagens", "Auras, raios e efeitos ao redor dos personagens. Desative para mais FPS ou visual limpo.", "gold")
auraFace.Desc.Size = UDim2.fromScale(0.6, 0.42)
toggleButton(auraFace, "CharacterAuras")

local function refresh()
	for _, fn in ipairs(refreshers) do
		fn()
	end
end
CS.Changed:Connect(function()
	if win.IsOpen() then
		refresh()
	end
end)

UI.onOpen("Settings", function()
	if win.IsOpen() then
		win.Close()
		return
	end
	refresh()
	win.Open()
end)

UI.onBattle(function(inBattle)
	if inBattle then
		win.Close(true)
	end
end)
