--[[
	MonetizationService (GDD secoes 9 e 13)
	- Game Passes: conferidos a cada entrada (UserOwnsGamePassAsync) e na compra (PromptGamePassPurchaseFinished).
	  Perfil: Benefits[id] = "Pass". Passe que o jogador nao tem mais e retirado na entrada.
	- Beneficios por gemas (Mochila Ampliada, Gold em Dobro, Cura Automatica): Benefits[id] = "Gems".
	- Pacotes de gemas (Developer Products) por ProcessReceipt: entrega uma vez por PurchaseId
	  (Receipts no perfil) e so confirma depois de salvar; sem perfil ou sem salvar = NotProcessedYet (o Roblox tenta de novo).
	- PolicyService: atributo PaidRandomRestricted no jogador (true onde itens aleatorios pagos sao restritos;
	  sem resposta conta como restrito). O Portal Premium e recusado com ele (SummonService).
	IDs do painel: ReplicatedStorage/Data/ProductIds (0 = ainda nao criado).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")

local Data = ReplicatedStorage:WaitForChild("Data")
local Benefits = require(Data.Benefits)
local ProductIds = require(Data.ProductIds)

local PlayerDataService = require(ServerScriptService:WaitForChild("Data"):WaitForChild("PlayerDataService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local MonetizationService = {}

local MAX_RECEIPTS = 100
local busy = {}
local onBenefitsChanged = {} -- funcoes chamadas quando um beneficio entra ou sai (base VIP etc.)

local function notify(player: Player, text: string)
	Remotes.Notify:FireClient(player, text)
end

local function fmt(n: number): string
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", ""))
end

-- IDs lidos na hora (0 = vazio)
local function benefitForPass(passId: number): string?
	for benefitId, id in pairs(ProductIds.GamePasses) do
		if id ~= 0 and id == passId then
			return benefitId
		end
	end
	return nil
end

local function packForProduct(productId: number): string?
	for packId, id in pairs(ProductIds.DevProducts) do
		if id ~= 0 and id == productId then
			return packId
		end
	end
	return nil
end

function MonetizationService.OnBenefitsChanged(fn)
	table.insert(onBenefitsChanged, fn)
end

local function applyEffects(player: Player)
	local data = PlayerDataService.Get(player)
	if not data then
		return
	end
	player:SetAttribute("VIP", Benefits.Has(data, "VIP")) -- tag no chat (cliente)
	for _, fn in ipairs(onBenefitsChanged) do
		task.spawn(fn, player)
	end
end

local function grant(player: Player, benefitId: string, source: string): boolean
	local data = PlayerDataService.Get(player)
	if not data or not Benefits.List[benefitId] then
		return false
	end
	if data.Benefits[benefitId] == nil then
		data.Benefits[benefitId] = source
	end
	PlayerDataService.MarkChanged(player)
	task.spawn(PlayerDataService.SaveNow, player)
	applyEffects(player)
	return true
end

--------------------------------------------------------------------
-- Game Passes
--------------------------------------------------------------------
function MonetizationService.RefreshPasses(player: Player)
	local data = PlayerDataService.Get(player)
	if not data then
		return
	end
	local changed = false
	for benefitId, passId in pairs(ProductIds.GamePasses) do
		if passId ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
			if ok then
				if owns and data.Benefits[benefitId] == nil then
					data.Benefits[benefitId] = "Pass"
					changed = true
				elseif not owns and data.Benefits[benefitId] == "Pass" then
					data.Benefits[benefitId] = nil
					changed = true
				end
			else
				warn("[Monetization] Falha ao conferir o passe " .. benefitId .. ": " .. tostring(owns))
			end
		end
	end
	if changed then
		PlayerDataService.MarkChanged(player)
	end
	applyEffects(player)
end

function MonetizationService.OnPassPurchased(player: Player, passId: number, purchased: boolean)
	if not purchased then
		return false
	end
	-- seguranca: nao confia so no evento; confere a posse no Roblox
	local okOwn, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
	if not okOwn or not owns then
		warn("[Monetization] Compra de passe nao confirmada: " .. tostring(passId))
		return false
	end
	local benefitId = benefitForPass(passId)
	if not benefitId then
		warn("[Monetization] Passe desconhecido: " .. tostring(passId))
		return false
	end
	if grant(player, benefitId, "Pass") then
		notify(player, Benefits.List[benefitId].Name .. " ativado!")
		return true
	end
	return false
end

--------------------------------------------------------------------
-- Beneficio comprado com gemas
--------------------------------------------------------------------
function MonetizationService.BuyWithGems(player: Player, benefitId)
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Dados ainda carregando."
	end
	local def = typeof(benefitId) == "string" and Benefits.List[benefitId]
	if not def then
		return false, "Benef\u{ed}cio inv\u{e1}lido."
	end
	if not def.Gems then
		return false, def.Name .. " s\u{f3} \u{e9} vendido em Robux."
	end
	if Benefits.Has(data, benefitId) then
		return false, "Voc\u{ea} j\u{e1} tem " .. def.Name .. "."
	end
	if data.Gems < def.Gems then
		return false, "Gemas insuficientes (precisa de " .. fmt(def.Gems) .. ")."
	end
	data.Gems -= def.Gems
	grant(player, benefitId, "Gems")
	return true, def.Name .. " ativado por " .. fmt(def.Gems) .. " gemas!"
end

--------------------------------------------------------------------
-- Pacotes de gemas (Developer Products)
--------------------------------------------------------------------
local function pruneReceipts(receipts)
	local list = {}
	for id, t in pairs(receipts) do
		table.insert(list, { id, t })
	end
	if #list <= MAX_RECEIPTS then
		return
	end
	table.sort(list, function(a, b)
		return a[2] < b[2]
	end)
	for i = 1, #list - MAX_RECEIPTS do
		receipts[list[i][1]] = nil
	end
end

function MonetizationService.ProcessReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = PlayerDataService.WaitFor(player, 15)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local key = tostring(receiptInfo.PurchaseId)
	if data.Receipts[key] then
		-- ja entregue: confirma so se o perfil estiver salvo
		return if PlayerDataService.SaveNow(player) then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local packId = packForProduct(receiptInfo.ProductId)
	local pack = packId and Benefits.GemPacks[packId]
	if not pack then
		warn("[Monetization] Produto desconhecido: " .. tostring(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	data.Gems += pack.Gems
	data.Receipts[key] = os.time()
	pruneReceipts(data.Receipts)
	if not PlayerDataService.SaveNow(player) then
		-- nao salvou: mantem as gemas e o recibo no perfil (sem entregar de novo) e deixa o Roblox tentar outra vez
		PlayerDataService.MarkChanged(player)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	PlayerDataService.MarkChanged(player)
	notify(player, "+" .. fmt(pack.Gems) .. " gemas! Obrigado pela compra.")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

--------------------------------------------------------------------
-- PolicyService: itens aleatorios pagos (Portal Premium)
--------------------------------------------------------------------
function MonetizationService.CheckPolicy(player: Player)
	player:SetAttribute("PaidRandomRestricted", true) -- ate confirmar
	local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	local restricted = not ok or info == nil or info.ArePaidRandomItemsRestricted == true
	if not ok then
		warn("[Monetization] PolicyService falhou para " .. player.Name .. ": " .. tostring(info))
	end
	if player.Parent then
		player:SetAttribute("PaidRandomRestricted", restricted)
	end
	return restricted
end

--------------------------------------------------------------------
function MonetizationService.Init()
	MarketplaceService.ProcessReceipt = MonetizationService.ProcessReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		MonetizationService.OnPassPurchased(player, passId, purchased)
	end)
	Remotes.BuyBenefit.OnServerInvoke = function(player, benefitId)
		if busy[player] then
			return false, "Aguarde."
		end
		busy[player] = true
		local ok, a, b = pcall(MonetizationService.BuyWithGems, player, benefitId)
		busy[player] = nil
		if not ok then
			warn("[Monetization] " .. tostring(a))
			return false, "Erro no servidor."
		end
		return a, b
	end

	local function onPlayer(player: Player)
		task.spawn(MonetizationService.CheckPolicy, player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayer(p)
	end
	PlayerDataService.Loaded:Connect(function(player)
		MonetizationService.RefreshPasses(player)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		if PlayerDataService.Get(p) then
			task.spawn(MonetizationService.RefreshPasses, p)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return MonetizationService
