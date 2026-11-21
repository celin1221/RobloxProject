--[[
	ClientSettings (cliente) - aplica as configuracoes do jogador
	- Musica e efeitos sonoros: volume dos SoundGroups SoundService.Musica e SoundService.Efeitos.
	- Efeitos do mapa: liga/desliga tudo com a tag "MapFx" (particulas, luzes decorativas, brilhos);
	  animacoes de cenario leem ClientSettings.Current.MapFx ou o atributo MapFx do PlayerGui.
	O valor salvo vem do perfil (servidor valida em SettingsService); a tela muda na hora e salva
	com um pequeno atraso para nao mandar um pedido por movimento do controle.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local CollectionService = game:GetService("CollectionService")

local Audio = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("Audio"))

local CS = {}
CS.Current = table.clone(Audio.DefaultSettings)
local changed = Instance.new("BindableEvent")
CS.Changed = changed.Event

local FX = {
	ParticleEmitter = true, Beam = true, Trail = true, PointLight = true, SpotLight = true,
	SurfaceLight = true, Fire = true, Sparkles = true, Smoke = true,
}

local function group(name)
	return SoundService:FindFirstChild(name)
end

local function setOne(d: Instance, on: boolean)
	if FX[d.ClassName] or d:IsA("LayerCollector") then
		(d :: any).Enabled = on
	elseif d:IsA("Decal") then
		if d:GetAttribute("FxT") == nil then
			d:SetAttribute("FxT", d.Transparency)
		end
		d.Transparency = if on then d:GetAttribute("FxT") else 1
	end
end

local function setFx(inst: Instance, on: boolean)
	-- modelo escondido localmente (ex.: Portal Premium restrito) fica apagado
	local model = inst:FindFirstAncestorOfClass("Model")
	if model and model:GetAttribute("HiddenLocal") then
		on = false
	end
	setOne(inst, on)
	for _, d in ipairs(inst:GetDescendants()) do
		setOne(d, on)
	end
end

function CS.applySound()
	local s = CS.Current
	local m, e = group("Musica"), group("Efeitos")
	if m then
		m.Volume = if s.MusicOn then s.MusicVolume / 100 else 0
	end
	if e then
		e.Volume = if s.SfxOn then s.SfxVolume / 100 else 0
	end
end

function CS.applyMapFx()
	local on = CS.Current.MapFx
	for _, inst in ipairs(CollectionService:GetTagged("MapFx")) do
		setFx(inst, on)
	end
	local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if pg then
		pg:SetAttribute("MapFx", on)
	end
end

function CS.applyCharacterAuras()
	local on = CS.Current.CharacterAuras ~= false
	local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if pg then
		pg:SetAttribute("CharacterAuras", on)
	end
end

local function applyAll()
	CS.applySound()
	CS.applyMapFx()
	CS.applyCharacterAuras()
	changed:Fire(CS.Current)
end

-- salvar no servidor (atrasado; o ultimo valor vence)
local saveToken = 0
local pendingLocal = false
local function scheduleSave()
	saveToken += 1
	local token = saveToken
	pendingLocal = true
	task.delay(0.8, function()
		if token ~= saveToken then
			return
		end
		local ok = pcall(function()
			return ReplicatedStorage.Remotes.SaveSettings:InvokeServer(CS.Current)
		end)
		if token == saveToken then
			pendingLocal = false
		end
		if not ok then
			warn("[Configuracoes] nao foi possivel salvar agora")
		end
	end)
end

-- Muda uma configuracao pela tela (aplica ja e salva)
function CS.set(key: string, value)
	if CS.Current[key] == nil or typeof(value) ~= typeof(CS.Current[key]) then
		return
	end
	if typeof(value) == "number" then
		value = math.clamp(math.floor(value + 0.5), 0, 100)
	end
	CS.Current[key] = value
	applyAll()
	scheduleSave()
end

-- Valores salvos (perfil). Ignora enquanto ha mudanca local esperando para salvar.
function CS.load(saved)
	if typeof(saved) ~= "table" or pendingLocal then
		return
	end
	for k, v in pairs(Audio.DefaultSettings) do
		if typeof(saved[k]) == typeof(v) then
			CS.Current[k] = saved[k]
		end
	end
	applyAll()
end

local started = false
function CS.start()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceAddedSignal("MapFx"):Connect(function(inst)
		setFx(inst, CS.Current.MapFx)
	end)
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	Remotes:WaitForChild("ProfileUpdated").OnClientEvent:Connect(function(p)
		CS.load(p and p.Settings)
	end)
	task.spawn(function()
		local ok, p = pcall(function()
			return Remotes:WaitForChild("GetProfile"):InvokeServer()
		end)
		if ok and p then
			CS.load(p.Settings)
		end
	end)
	applyAll()
end

return CS
