-- Liga o salvamento (PlayerDataService) e a progressao (ProgressionService)
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressionService = require(script.Parent.ProgressionService)
local BattleService = require(ServerScriptService:WaitForChild("Battle"):WaitForChild("BattleService"))

PlayerDataService.Init()
ProgressionService.Init(BattleService)
require(ServerScriptService:WaitForChild("Economy"):WaitForChild("SummonService")).Init()
require(ServerScriptService.Economy:WaitForChild("InventoryService")).Init()
local BaseService = require(ServerScriptService.Economy:WaitForChild("BaseService"))
BaseService.Init()
local MonetizationService = require(ServerScriptService.Economy:WaitForChild("MonetizationService"))
MonetizationService.OnBenefitsChanged(BaseService.RefreshLook)
MonetizationService.Init()
local RetentionService = require(script.Parent:WaitForChild("RetentionService"))
RetentionService.Init()
require(script.Parent:WaitForChild("SettingsService")).Init()
local RefugeService = require(ServerScriptService:WaitForChild("World"):WaitForChild("RefugeService"))
RefugeService.Init()
local TeamService = require(script.Parent:WaitForChild("TeamService"))
TeamService.Init()
local PartyFollowerService = require(ServerScriptService.World:WaitForChild("PartyFollowerService"))
PartyFollowerService.Init()
local Clock = require(script.Parent:WaitForChild("Clock"))

-- So no Studio: ponte para testes pela barra de comando (o require dela cria outra copia dos modulos)
if RunService:IsStudio() then
	local bridge = Instance.new("BindableFunction")
	bridge.Name = "_DevData"
	bridge.OnInvoke = function(action, player, ...)
		if action == "refuge" then
			return RefugeService.Dev(player, ...)
		elseif action == "get" then
			return PlayerDataService.Get(player)
		elseif action == "addxp" then
			local lines = ProgressionService.AddXp(player, ...)
			PlayerDataService.MarkChanged(player)
			return lines
		elseif action == "save" then
			return PlayerDataService.SaveNow(player)
		elseif action == "backup" then
			-- guarda uma copia do perfil para restaurar depois do teste
			local data = PlayerDataService.Get(player)
			return game:GetService("HttpService"):JSONEncode(data)
		elseif action == "restore" then
			local data = PlayerDataService.Get(player)
			local saved = game:GetService("HttpService"):JSONDecode((...))
			table.clear(data)
			for k, v in pairs(saved) do
				data[k] = v
			end
			PlayerDataService.MarkChanged(player)
			return PlayerDataService.SaveNow(player)
		elseif action == "testteam" then
			-- time de teste: lista { {CharacterId, Level}, ... } vira o time do jogador
			local data = PlayerDataService.Get(player)
			data.Team = {}
			for _, e in ipairs((...)) do
				ProgressionService.AddCharacter(player, e[1], e[2], true)
			end
			data.StarterChosen = true
			PlayerDataService.MarkChanged(player)
			return #data.Team
		elseif action == "unlock" then
			PlayerDataService.Get(player).Tower.Unlocked = (...)
			PlayerDataService.MarkChanged(player)
			return true
		elseif action == "additem" then
			local data = PlayerDataService.Get(player)
			local id, n = ...
			data.Bag[id] = math.min(99, (data.Bag[id] or 0) + n)
			PlayerDataService.MarkChanged(player)
			return data.Bag[id]
		elseif action == "setstate" then
			-- prepara um personagem para teste: HP, status e PP salvos
			local data = PlayerDataService.Get(player)
			local uid, st = ...
			local m = data.Collection[uid]
			m.Hp = st.Hp
			m.Status = st.Status
			m.Pp = st.Pp
			PlayerDataService.MarkChanged(player)
			return true
		elseif action == "addgold" then
			local data = PlayerDataService.Get(player)
			data.Gold += (...)
			PlayerDataService.MarkChanged(player)
			return data.Gold
		elseif action == "clock" then
			-- adianta o relogio (segundos) como se o jogador tivesse ficado fora
			return BaseService.AdvanceClock(player, (...))
		elseif action == "base" then
			-- chama uma acao da base direto: "SetState", "Collect", "UpgradeSlots", "SellOre"
			local fn, a, b = ...
			return BaseService[fn](player, a, b)
		elseif action == "setid" then
			-- ID temporario so nesta sessao (testa compra sem o painel): "GamePasses"|"DevProducts", chave, id
			local kind, key, id = ...
			require(game:GetService("ReplicatedStorage").Data.ProductIds)[kind][key] = id
			return true
		elseif action == "monet" then
			-- "ProcessReceipt" (recibo), "OnPassPurchased" (passId, true), "BuyWithGems" (beneficio)
			local fn, a, b = ...
			if fn == "ProcessReceipt" then
				return MonetizationService.ProcessReceipt(a).Name
			end
			return MonetizationService[fn](player, a, b)
		elseif action == "policy" then
			player:SetAttribute("PaidRandomRestricted", (...))
			return true
		elseif action == "retclock" then
			-- adianta o relogio do retorno (segundos) e recalcula dia, semana e temporada do jogador
			Clock.Advance((...))
			if player then
				RetentionService.Prepare(player)
			end
			return Clock.Now()
		elseif action == "playtime" then
			return RetentionService.AddPlaytime(player, (...))
		elseif action == "ret" then
			-- "ClaimLogin", "ClaimChest" (n), "Redeem" (codigo), "Track" (evento, n), "OnInfiniteFloor" (andar)
			local fn, a, b = ...
			return RetentionService[fn](player, a, b)
		elseif action == "checktop" then
			return RetentionService._checkTop(player)
		elseif action == "team" then
			-- muda o time como o remote SetTeam (mesma validacao)
			return TeamService.Apply(player, (...))
		elseif action == "addchar" then
			-- adiciona um personagem a colecao (fora do time): id, nivel, variante?
			local id, level, variant = ...
			local uid = ProgressionService.AddCharacter(player, id, level, false, variant)
			PlayerDataService.MarkChanged(player)
			return uid
		elseif action == "timescale" then
			require(ServerScriptService.Battle.BattleConfig).TimeScale = (...)
			return true
		end
	end
	bridge.Parent = game:GetService("ServerStorage")
end
