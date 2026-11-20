--[[
	SettingsService (GDD secao 10 - Configuracoes)
	Salva no perfil: musica (liga e volume), efeitos sonoros (liga e volume) e efeitos do mapa.
	Valida tudo o que vem do cliente: so chaves conhecidas, booleanos e volumes inteiros de 0 a 100.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataService = require(script.Parent.PlayerDataService)
local Audio = require(ReplicatedStorage.Data.Audio)

local SettingsService = {}

local KINDS = { MusicOn = "boolean", MusicVolume = "number", SfxOn = "boolean", SfxVolume = "number", MapFx = "boolean" }
local lastSave = {} -- [Player] = os.clock()

function SettingsService.Apply(player: Player, incoming): (boolean, string?)
	if typeof(incoming) ~= "table" then
		return false, "Pedido inv\u{e1}lido."
	end
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Perfil ainda carregando."
	end
	local now = os.clock()
	if lastSave[player] and now - lastSave[player] < 0.4 then
		return false, "Aguarde um instante."
	end
	lastSave[player] = now
	data.Settings = data.Settings or table.clone(Audio.DefaultSettings)
	for key, kind in pairs(KINDS) do
		local v = incoming[key]
		if v ~= nil then
			if typeof(v) ~= kind then
				return false, "Valor inv\u{e1}lido."
			end
			if kind == "number" then
				if v ~= v then
					return false, "Valor inv\u{e1}lido."
				end
				v = math.clamp(math.floor(v + 0.5), 0, 100)
			end
			data.Settings[key] = v
		end
	end
	PlayerDataService.MarkChanged(player)
	return true
end

function SettingsService.Init()
	local remote = ReplicatedStorage.Remotes:WaitForChild("SaveSettings")
	remote.OnServerInvoke = function(player, incoming)
		return SettingsService.Apply(player, incoming)
	end
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		lastSave[p] = nil
	end)
end

return SettingsService
