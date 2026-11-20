--[[
	InventoryService (GDD secoes 3 e 7)
	- Mochila: 30 espacos (+20 com Mochila Ampliada), pilhas de 99 (Data/Items.SpaceFor).
	- Uso fora de batalha: so Pocoes e Reviver (Items.OutsideBattle). Os demais so em batalha.
	- Loja de itens em gold (Workspace/Map/Shop) e centro de cura (Workspace/Map/HealingCenter):
	  o centro restaura HP, PP e status de todos os personagens do jogador, de graca.
	Tudo validado no servidor; o perfil e salvo na hora depois de compra, uso e cura.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Data = ReplicatedStorage:WaitForChild("Data")
local Items = require(Data.Items)
local Characters = require(Data.Characters)
local Progression = require(Data.Progression)
local Benefits = require(Data.Benefits)

local PlayerDataService = require(ServerScriptService:WaitForChild("Data"):WaitForChild("PlayerDataService"))
local BattleService = require(ServerScriptService:WaitForChild("Battle"):WaitForChild("BattleService"))
local TowerService = require(ServerScriptService:WaitForChild("Tower"):WaitForChild("TowerService"))
local RetentionService = require(ServerScriptService:WaitForChild("Data"):WaitForChild("RetentionService"))
local ProgressionService = require(ServerScriptService.Data:WaitForChild("ProgressionService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local InventoryService = {}

local busy = {}
local MAX_BUY = 99

local function notify(player: Player, text: string)
	Remotes.Notify:FireClient(player, text)
end
InventoryService.Notify = notify

local function blocked(player: Player): string?
	if BattleService.IsInBattle(player) or TowerService.IsRunning(player) then
		return "N\u{e3}o d\u{e1} durante a batalha ou a corrida da torre."
	end
	return nil
end

local function changed(player: Player)
	PlayerDataService.MarkChanged(player)
	task.spawn(PlayerDataService.SaveNow, player)
end

-- Compra na loja
function InventoryService.Buy(player: Player, itemId, qty)
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Dados ainda carregando."
	end
	local item = typeof(itemId) == "string" and Items.Get(itemId)
	if not item or not item.Price then
		return false, "Item inv\u{e1}lido."
	end
	if typeof(qty) ~= "number" or qty ~= qty or qty % 1 ~= 0 or qty < 1 or qty > MAX_BUY then
		return false, "Quantidade inv\u{e1}lida."
	end
	local slots = Benefits.BagSlots(data, Items.BagSlots)
	local space = Items.SpaceFor(data.Bag, itemId, slots)
	if space <= 0 then
		return false, if (data.Bag[itemId] or 0) > 0 then "Pilha cheia (" .. Items.StackLimit .. ")." else "Mochila cheia (" .. slots .. " espa\u{e7}os)."
	end
	qty = math.min(qty, space)
	local cost = item.Price * qty
	if data.Gold < cost then
		return false, "Gold insuficiente (precisa de " .. cost .. ")."
	end
	data.Gold -= cost
	data.Bag[itemId] = (data.Bag[itemId] or 0) + qty
	changed(player)
	RetentionService.Track(player, "BuyItem", qty)
	return true, "Comprou " .. qty .. "x " .. item.Name .. " por " .. cost .. " gold."
end

-- Uso fora de batalha (Pocoes e Reviver) em um personagem da colecao
function InventoryService.Use(player: Player, itemId, uid)
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Dados ainda carregando."
	end
	local why = blocked(player)
	if why then
		return false, why
	end
	local item = typeof(itemId) == "string" and Items.Get(itemId)
	if not item then
		return false, "Item inv\u{e1}lido."
	end
	if item.Kind == "XpCandy" then
		return InventoryService.UseCandy(player, data, item, uid)
	end
	if not item.OutsideBattle then
		return false, item.Name .. " s\u{f3} pode ser usado em batalha."
	end
	if (data.Bag[itemId] or 0) <= 0 then
		return false, "Voc\u{ea} n\u{e3}o tem " .. item.Name .. "."
	end
	local m = typeof(uid) == "string" and data.Collection[uid]
	if not m then
		return false, "Personagem inv\u{e1}lido."
	end
	local name = Characters.Get(m.CharacterId).Name
	local hp, max = Progression.CurrentHp(m)
	local text
	if item.Kind == "HealHP" then
		if hp <= 0 then
			return false, name .. " est\u{e1} desmaiado. Use um Reviver."
		end
		if hp >= max then
			return false, name .. " j\u{e1} est\u{e1} com o HP cheio."
		end
		local new = math.min(max, hp + item.Amount)
		m.Hp = if new >= max then nil else new
		text = name .. " recuperou " .. (new - hp) .. " de HP (" .. new .. "/" .. max .. ")."
	elseif item.Kind == "Revive" then
		if hp > 0 then
			return false, name .. " n\u{e3}o est\u{e1} desmaiado."
		end
		local new = math.max(1, math.floor(max * item.Percent))
		m.Hp = new
		m.Status = nil
		m.StatusTurns = nil
		text = name .. " voltou com " .. new .. " de HP."
	else
		return false, item.Name .. " s\u{f3} pode ser usado em batalha."
	end
	data.Bag[itemId] -= 1
	if data.Bag[itemId] <= 0 then
		data.Bag[itemId] = nil
	end
	changed(player)
	return true, "Usou " .. item.Name .. ". " .. text
end

-- Doce de XP (secao 14): fora de batalha, num personagem abaixo do nivel 50.
-- Comum: 25% do XP do nivel atual. Raro/Epico: sobe 1/3 niveis inteiros (o XP que ja tinha no nivel fica).
function InventoryService.UseCandy(player: Player, data, item, uid)
	if (data.Bag[item.Id] or 0) <= 0 then
		return false, "Voc\u{ea} n\u{e3}o tem " .. item.Name .. "."
	end
	local m = typeof(uid) == "string" and data.Collection[uid]
	if not m then
		return false, "Personagem inv\u{e1}lido."
	end
	local name = Characters.Get(m.CharacterId).Name
	if m.Level >= Progression.MaxLevel then
		return false, name .. " j\u{e1} est\u{e1} no n\u{ed}vel m\u{e1}ximo."
	end
	local amount = 0
	if item.XpPercent then
		amount = math.max(1, math.floor(Progression.XpToNext(m.Level) * item.XpPercent))
	else
		local target = math.min(Progression.MaxLevel, m.Level + item.Levels)
		for lv = m.Level, target - 1 do
			amount += Progression.XpToNext(lv)
		end
		-- quem chega ao 50 perde a sobra; quem nao chega mantem o XP do nivel (sem pular nivel extra)
		if target < Progression.MaxLevel then
			m.Xp = math.min(m.Xp, Progression.XpToNext(target) - 1)
		end
	end
	local before = m.Level
	data.Bag[item.Id] -= 1
	if data.Bag[item.Id] <= 0 then
		data.Bag[item.Id] = nil
	end
	local lines = ProgressionService.AddXp(player, uid, amount)
	changed(player)
	Remotes.CandyFx:FireClient(player, item.Id, uid, m.Level - before)
	return true, table.concat(lines, " ")
end

-- Centro de cura: HP, PP e status de todos os personagens
function InventoryService.HealAll(player: Player)
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Dados ainda carregando."
	end
	local why = blocked(player)
	if why then
		return false, why
	end
	local healed = 0
	for _, m in pairs(data.Collection) do
		if m.Hp ~= nil or m.Status ~= nil or m.Pp ~= nil then
			healed += 1
		end
		m.Hp = nil
		m.Status = nil
		m.StatusTurns = nil
		m.Pp = nil
	end
	changed(player)
	return true, if healed > 0 then "Seu time foi curado! HP, PP e status restaurados." else "Seu time j\u{e1} est\u{e1} em plena forma."
end

local function guarded(fn)
	return function(player, ...)
		if busy[player] then
			return false, "Aguarde."
		end
		busy[player] = true
		local ok, a, b = pcall(fn, player, ...)
		busy[player] = nil
		if not ok then
			warn("[Inventory] " .. tostring(a))
			return false, "Erro no servidor."
		end
		return a, b
	end
end

local function addPrompt(model: Instance?, name: string, action: string, object: string)
	local point = model and model:FindFirstChild("InteractPoint")
	if not point then
		warn("[Inventory] InteractPoint nao encontrado em " .. tostring(model))
		return nil
	end
	local old = point:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Parent = point
	return p
end

function InventoryService.Init()
	Remotes.BuyItem.OnServerInvoke = guarded(InventoryService.Buy)
	Remotes.UseItem.OnServerInvoke = guarded(InventoryService.Use)
	if not Remotes:FindFirstChild("CandyFx") then
		local ev = Instance.new("RemoteEvent")
		ev.Name = "CandyFx"
		ev.Parent = Remotes
	end
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
	local map = workspace:WaitForChild("Map")
	-- Loja: o cliente abre a tela (ShopGui) pelo prompt
	addPrompt(map:FindFirstChild("Shop"), "ShopPrompt", "Abrir loja", "Loja")
	-- Centro de cura: cura na hora
	local heal = addPrompt(map:FindFirstChild("HealingCenter"), "HealPrompt", "Curar time", "Centro de cura")
	if heal then
		heal.Triggered:Connect(function(player)
			local ok, text = guarded(InventoryService.HealAll)(player)
			notify(player, text)
		end)
	end
end

return InventoryService
