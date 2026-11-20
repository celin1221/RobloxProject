--[[
	BattleMain
	Liga o BattleService e vigia a entrada da torre.
	GDD secao 3: gatilho de proximidade com raio de 12 studs na entrada.
	O raio vem do atributo TriggerRadius da peca Tower/EntrancePoint.
]]

local Players = game:GetService("Players")
local BattleService = require(script.Parent.BattleService)
local TowerService = require(game:GetService("ServerScriptService"):WaitForChild("Tower"):WaitForChild("TowerService"))

BattleService.Init()
TowerService.Init()
require(script.Parent.PvPService).Init()

local entrance = workspace:WaitForChild("Tower"):WaitForChild("EntrancePoint")
local CHECK_INTERVAL = 0.2

while true do
	task.wait(CHECK_INTERVAL)
	local radius = entrance:GetAttribute("TriggerRadius") or 12
	for _, player in ipairs(Players:GetPlayers()) do
		if not BattleService.IsInBattle(player) and not TowerService.IsRunning(player) then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 then
				local inside = (root.Position - entrance.Position).Magnitude <= radius
				if not inside then
					-- depois de uma batalha, o jogador precisa sair do raio antes de abrir outra
					BattleService.MarkOutsideTrigger(player)
				elseif BattleService.CanTrigger(player) then
					-- abre a tela da torre (GDD secao 6)
					task.spawn(TowerService.OnTrigger, player)
				end
			end
		end
	end
end
