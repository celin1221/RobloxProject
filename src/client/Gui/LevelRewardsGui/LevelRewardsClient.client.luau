--[[
	LevelRewardsClient: HUD de Recompensas de Nivel da Conta.
	- Abre ao interagir (E) com os baus de ouro embaixo da Grande Arvore perto da Torre ("LevelRewardsPrompt")
	  ou via UI.open("LevelRewards") (ou clicando no cartao de Nivel da Conta no HUD).
	- Mostra progresso atual (Nivel, barra de XP, total acumulado, proximo marco, botao RESGATAR TUDO)
	  e a lista completa de recompensas para TODOS os niveis (1..50+, expandindo conforme o jogador sobe).
	- 100% autoritativo no servidor: o cliente apenas exibe e solicita via Remotes.ClaimLevelReward.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local gui = script.Parent
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Data = ReplicatedStorage:WaitForChild("Data")
local AccountLevel = require(Data:WaitForChild("AccountLevel"))
local Items = require(Data:WaitForChild("Items"))
local UI = require(ReplicatedStorage:WaitForChild("UI"))
local T = UI.Theme

local ClaimRF = Remotes:WaitForChild("ClaimLevelReward") :: RemoteFunction

local profile = nil
local busy = false
local pendingScrollLevel: number? = nil

--------------------------------------------------------------------
-- Formatacao de recompensas
--------------------------------------------------------------------
local function rewardText(r: AccountLevel.LevelReward): string
	local parts = {}
	if r.Gold and r.Gold > 0 then
		table.insert(parts, UI.fmt(r.Gold) .. " Gold")
	end
	if r.Gems and r.Gems > 0 then
		table.insert(parts, UI.fmt(r.Gems) .. " Gemas")
	end
	if r.Tickets then
		if r.Tickets.Premium and r.Tickets.Premium > 0 then
			table.insert(parts, r.Tickets.Premium .. "x Invoca\u{e7}\u{e3}o Premium")
		end
		if r.Tickets.Comum and r.Tickets.Comum > 0 then
			table.insert(parts, r.Tickets.Comum .. "x Invoca\u{e7}\u{e3}o Comum")
		end
	end
	if r.Items then
		local ids = {}
		for id in pairs(r.Items) do
			table.insert(ids, id)
		end
		table.sort(ids)
		for _, id in ipairs(ids) do
			local qty = r.Items[id]
			if qty and qty > 0 then
				local def = Items.Get(id)
				table.insert(parts, qty .. "x " .. (if def then def.Name else id))
			end
		end
	end
	return table.concat(parts, "  +  ")
end

local function rewardIcon(r: AccountLevel.LevelReward): string
	if r.Tickets then
		return "ticket"
	end
	if r.Gems and r.Gems > 0 then
		return "gem"
	end
	if r.Items then
		local id = next(r.Items)
		if id == "DoceEpico" then
			return "doce_epico"
		elseif id == "DoceRaro" then
			return "doce_raro"
		elseif id == "DoceComum" then
			return "doce_comum"
		elseif id == "SeloSuperior" then
			return "seal_superior"
		elseif id == "SeloContrato" then
			return "seal_basic"
		elseif id and string.find(id, "Pocao") then
			return "potion"
		end
	end
	return "coin"
end

local function nextMilestoneLevel(curLv: number): number
	local m = math.floor(curLv / 5) * 5 + 5
	return math.max(5, m)
end

local function countClaimed(acc: any): number
	if typeof(acc) ~= "table" or typeof(acc.Claimed) ~= "table" then
		return 0
	end
	local n = 0
	for _, v in pairs(acc.Claimed) do
		if v == true then
			n += 1
		end
	end
	return n
end

--------------------------------------------------------------------
-- Janela principal
--------------------------------------------------------------------
local canvas = UI.screen(gui)
gui.DisplayOrder = 9

local win = UI.window(canvas, {
	Name = "LevelRewardsWindow",
	Title = "RECOMPENSAS DE N\u{cd}VEL",
	Icon = "chest",
	HeaderColor = "lendario",
	Size = UDim2.fromScale(0.90, 0.86),
	Aspect = 1.85,
})
-- Alarga um pouco a pilula do titulo para caber "RECOMPENSAS DE NIVEL" com folga
win.Header.Size = UDim2.fromScale(0.64, 0.15)

local body = win.Body

-- Cartao resumo no topo (Nivel atual, barra de XP, proximo marco, botao RESGATAR TUDO)
local summary, sumFace = UI.panel(body, {
	Name = "SummaryCard",
	Size = UDim2.fromScale(1, 0.21),
	Position = UDim2.fromScale(0, 0),
	Color = "slot",
	Corner = 0.22,
	Shadow = false,
})
UI.clampHeight(summary, 78, 114)

local sumBadge, sumBadgeFace = UI.panel(sumFace, {
	Name = "LevelMedal",
	Size = UDim2.fromScale(0.16, 0.82),
	Position = UDim2.fromScale(0.015, 0.5),
	AnchorPoint = Vector2.new(0, 0.5),
	Color = "lendario",
	Corner = 0.28,
	Shadow = false,
})
UI.icon(sumBadgeFace, "star", {
	Name = "Star",
	Size = UDim2.fromScale(0.36, 0.44),
	Position = UDim2.fromScale(0.5, 0.06),
	AnchorPoint = Vector2.new(0.5, 0),
})
local sumLevelTxt = UI.text(sumBadgeFace, "NV. 1", {
	Name = "LevelText",
	Size = UDim2.fromScale(0.92, 0.48),
	Position = UDim2.fromScale(0.04, 0.48),
	Role = "Heading",
})

local sumHeadline = UI.text(sumFace, "N\u{ed}vel da Conta  \u{b7}  Nunca diminui", {
	Name = "Headline",
	Size = UDim2.fromScale(0.49, 0.28),
	Position = UDim2.fromScale(0.19, 0.07),
	Role = "Small",
	Color = "gold",
	AlignX = Enum.TextXAlignment.Left,
})

local sumBar = UI.bar(sumFace, {
	Name = "XpBar",
	Size = UDim2.fromScale(0.49, 0.26),
	Position = UDim2.fromScale(0.19, 0.39),
	FillColor = "blue",
})
local sumBarTxt = UI.text(sumBar, "0 / 129 XP", {
	Name = "XpLabel",
	Size = UDim2.fromScale(0.96, 0.92),
	Position = UDim2.fromScale(0.02, 0.04),
	Role = "Small",
	StrokeMult = 0.6,
	ZIndex = 4,
})

local sumStats = UI.text(sumFace, "XP Total: 0  \u{b7}  Resgatados: 0", {
	Name = "Stats",
	Size = UDim2.fromScale(0.49, 0.24),
	Position = UDim2.fromScale(0.19, 0.70),
	Role = "Small",
	Color = "inkSoft",
	AlignX = Enum.TextXAlignment.Left,
	StrokeMult = 0.45,
})

-- Mensagem de retorno no rodape
local msg = UI.text(body, "", {
	Name = "Message",
	Size = UDim2.fromScale(1, 0.065),
	Position = UDim2.fromScale(0, 0.935),
	Role = "Small",
	Color = "gold",
})

-- Lista rolavel de niveis entre SummaryCard e Message
local list = UI.scroll(body, {
	Name = "RewardList",
	Size = UDim2.fromScale(1, 0.70),
	Position = UDim2.fromScale(0, 0.22),
	Gap = 0.014,
})
UI.fillBetween(list, summary, msg, 6)

local function showMsg(ok: boolean, text: string?)
	msg.TextColor3 = if ok then T.Palette.gold else T.Palette.hpLow
	msg.Text = text or ""
	UI.play(if ok then "reward" else "error")
end

local function invokeClaim(arg: any)
	if busy then
		return
	end
	busy = true
	local callOk, resOk, resMsg = pcall(function()
		return ClaimRF:InvokeServer(arg)
	end)
	busy = false
	if not callOk then
		showMsg(false, "Erro de conex\u{e3}o ao resgatar. Tente novamente.")
		return
	end
	showMsg(resOk == true, tostring(resMsg or ""))
end

local claimAllBtn = UI.button(sumFace, {
	Name = "ClaimAll",
	Text = "RESGATAR TUDO",
	Icon = "chest",
	Layout = "row",
	Color = "green",
	Size = UDim2.fromScale(0.285, 0.78),
	Position = UDim2.fromScale(0.985, 0.5),
	AnchorPoint = Vector2.new(1, 0.5),
	Role = "Small",
	Sound = false,
	OnClick = function()
		invokeClaim("All")
	end,
})
local claimAllShine = UI.shine(claimAllBtn)

--------------------------------------------------------------------
-- Renderizacao da lista
--------------------------------------------------------------------
local function scrollToLevel(targetLv: number)
	task.defer(function()
		task.wait(0.05)
		if not win.IsOpen() then
			return
		end
		local row = list:FindFirstChild("Lv" .. targetLv)
		if row and row:IsA("GuiObject") then
			local relY = row.AbsolutePosition.Y - list.AbsolutePosition.Y + list.CanvasPosition.Y
			local maxY = math.max(0, list.AbsoluteCanvasSize.Y - list.AbsoluteWindowSize.Y)
			local desired = math.clamp(relY - 12, 0, maxY)
			list.CanvasPosition = Vector2.new(0, desired)
		end
	end)
end

local function rebuildRows(acc: any)
	UI.clear(list)
	local curLv = math.max(1, math.floor(tonumber(acc.Level) or 1))
	local displayMax = math.max(AccountLevel.DefaultDisplayMax, curLv + 10)

	for lv = 1, displayMax do
		local r = AccountLevel.RewardFor(lv)
		local unlocked = lv <= curLv
		local claimed = AccountLevel.IsClaimed(acc, lv)
		local ready = unlocked and not claimed
		local isLeg = r.Tier == "Lendario"
		local isEpic = r.Tier == "Epico"

		local rowColor = if ready
			then (if isLeg then "lendario" elseif isEpic then "purple" else "panelAlt")
			elseif claimed then "slot"
			elseif isLeg then "panelAlt"
			elseif isEpic then "panelAlt"
			else "slot"

		local row, face = UI.row(list, {
			Name = "Lv" .. lv,
			Size = UDim2.fromScale(0.985, 0),
			Aspect = 7.4,
			RowMax = 80,
			Color = rowColor,
			Corner = 0.24,
			Shadow = ready or isLeg,
			LayoutOrder = lv,
		})

		if ready then
			UI.stroke(face, T.Palette.gold, 1.25)
			if isLeg or isEpic then
				UI.shine(row)
			end
		elseif isLeg then
			UI.stroke(face, T.Palette.gold, 1.0)
		elseif isEpic then
			UI.stroke(face, T.Palette.epico, 0.95)
		end

		-- Badge do nivel
		local badgeColor = if isLeg then "lendario" elseif isEpic then "epico" elseif unlocked then "blue" else "grey"
		local badge, bface = UI.panel(face, {
			Name = "LvBadge",
			Size = UDim2.fromScale(0.115, 0.72),
			Position = UDim2.fromScale(0.015, 0.5),
			AnchorPoint = Vector2.new(0, 0.5),
			Color = badgeColor,
			Corner = 0.32,
			Shadow = false,
		})
		local _ = badge
		UI.text(bface, "NV. " .. lv, {
			Name = "Num",
			Size = UDim2.fromScale(0.92, 0.76),
			Position = UDim2.fromScale(0.04, 0.12),
			Role = "Small",
		})

		-- Icone da recompensa
		UI.icon(face, rewardIcon(r), {
			Name = "RewardIcon",
			Size = UDim2.fromScale(0.075, 0.74),
			Position = UDim2.fromScale(0.145, 0.5),
			AnchorPoint = Vector2.new(0, 0.5),
			AspectAxis = Enum.DominantAxis.Height,
		})

		-- Titulo e itens da recompensa (com icone trophy/star real para marcos, zero simbolo Unicode)
		local titleColor = if isLeg and not ready then "gold" elseif isEpic and not ready then "epico" else "onDark"
		local titleX = 0.23
		local titleW = 0.50
		if isLeg or isEpic then
			UI.icon(face, if isLeg then "trophy" else "star", {
				Name = "MilestoneIcon",
				Size = UDim2.fromScale(0.038, 0.38),
				Position = UDim2.fromScale(0.23, 0.11),
				AspectAxis = Enum.DominantAxis.Height,
			})
			titleX = 0.272
			titleW = 0.458
		end
		UI.text(face, r.Title, {
			Name = "Title",
			Size = UDim2.fromScale(titleW, 0.40),
			Position = UDim2.fromScale(titleX, 0.10),
			Role = "Small",
			Color = titleColor,
			AlignX = Enum.TextXAlignment.Left,
		})
		UI.text(face, rewardText(r), {
			Name = "Items",
			Size = UDim2.fromScale(0.50, 0.40),
			Position = UDim2.fromScale(0.23, 0.52),
			Role = "Small",
			Color = if ready and isLeg then "onDark" else "gold",
			AlignX = Enum.TextXAlignment.Left,
			StrokeMult = 0.55,
		})

		-- Coluna direita: Botao RESGATAR / RESGATADO / BLOQUEADO
		if ready then
			UI.button(face, {
				Name = "ClaimBtn",
				Text = "RESGATAR",
				Icon = "gift",
				Layout = "row",
				Color = "green",
				Size = UDim2.fromScale(0.225, 0.78),
				Position = UDim2.fromScale(0.985, 0.5),
				AnchorPoint = Vector2.new(1, 0.5),
				Role = "Small",
				Sound = false,
				OnClick = function()
					invokeClaim(lv)
				end,
			})
		elseif claimed then
			local doneBox, dface = UI.panel(face, {
				Name = "ClaimedTag",
				Size = UDim2.fromScale(0.225, 0.66),
				Position = UDim2.fromScale(0.985, 0.5),
				AnchorPoint = Vector2.new(1, 0.5),
				Color = "slot",
				Corner = 0.35,
				Shadow = false,
			})
			local _2 = doneBox
			UI.icon(dface, "tick", {
				Name = "Tick",
				Size = UDim2.fromScale(0.20, 0.62),
				Position = UDim2.fromScale(0.07, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				AspectAxis = Enum.DominantAxis.Height,
			})
			UI.text(dface, "RESGATADO", {
				Name = "Label",
				Size = UDim2.fromScale(0.66, 0.74),
				Position = UDim2.fromScale(0.30, 0.13),
				Role = "Small",
				Color = "hpHigh",
				AlignX = Enum.TextXAlignment.Left,
				StrokeMult = 0.5,
			})
		else
			local lockBox, lface = UI.panel(face, {
				Name = "LockedTag",
				Size = UDim2.fromScale(0.225, 0.66),
				Position = UDim2.fromScale(0.985, 0.5),
				AnchorPoint = Vector2.new(1, 0.5),
				Color = "track",
				Corner = 0.35,
				Shadow = false,
			})
			local _3 = lockBox
			UI.icon(lface, "lock", {
				Name = "Lock",
				Size = UDim2.fromScale(0.20, 0.60),
				Position = UDim2.fromScale(0.08, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				AspectAxis = Enum.DominantAxis.Height,
				Tint = T.Palette.inkSoft,
			})
			UI.text(lface, "N\u{cd}VEL " .. lv, {
				Name = "Label",
				Size = UDim2.fromScale(0.64, 0.74),
				Position = UDim2.fromScale(0.32, 0.13),
				Role = "Small",
				Color = "inkSoft",
				AlignX = Enum.TextXAlignment.Left,
				StrokeMult = 0.45,
			})
		end
	end
end

local function render(preserveScroll: boolean)
	if not profile then
		return
	end
	local acc = profile.Account or { Level = 1, Xp = 0, TotalXp = 0, Claimed = {} }
	local curLv = math.max(1, math.floor(tonumber(acc.Level) or 1))
	local curXp = math.max(0, math.floor(tonumber(acc.Xp) or 0))
	local totalXp = math.max(0, math.floor(tonumber(acc.TotalXp) or 0))
	local needed = AccountLevel.XpToNext(curLv)
	local frac = math.clamp(if needed > 0 then curXp / needed else 0, 0, 1)
	local unclaimed = AccountLevel.CountUnclaimed(acc)
	local claimedCount = countClaimed(acc)
	local nextMile = nextMilestoneLevel(curLv)
	local mileLabel = if nextMile % 10 == 0 then "Marco Lend\u{e1}rio" else "Marco \u{c9}pico"

	sumLevelTxt.Text = "NV. " .. curLv
	sumHeadline.Text = "N\u{ed}vel da Conta  \u{b7}  Pr\u{f3}x. " .. mileLabel .. ": Nv. " .. nextMile
	UI.setBar(sumBar, frac, "blue", not preserveScroll)
	sumBarTxt.Text = UI.fmt(curXp) .. " / " .. UI.fmt(needed) .. " XP"
	sumStats.Text = "XP Total: " .. UI.fmt(totalXp) .. "  \u{b7}  Resgatados: " .. claimedCount .. "/" .. curLv

	if unclaimed > 0 then
		UI.setDisabled(claimAllBtn, false, "green")
		UI.setText(claimAllBtn, "RESGATAR TUDO (" .. unclaimed .. ")")
		claimAllShine.Visible = true
	else
		UI.setDisabled(claimAllBtn, true)
		UI.setText(claimAllBtn, "TUDO RESGATADO")
		claimAllShine.Visible = false
	end

	if preserveScroll then
		UI.keepScroll(list, function()
			rebuildRows(acc)
		end)
	else
		rebuildRows(acc)
		local target = pendingScrollLevel or AccountLevel.FirstUnclaimedLevel(acc) or curLv
		pendingScrollLevel = nil
		scrollToLevel(target)
	end
end

local function openWindow()
	if UI.inBattle() then
		return
	end
	if not profile then
		local ok, p = pcall(function()
			return Remotes:WaitForChild("GetProfile"):InvokeServer()
		end)
		if ok and typeof(p) == "table" then
			profile = p
		end
	end
	if not profile then
		return
	end
	msg.Text = ""
	win.Open()
	render(false)
end

--------------------------------------------------------------------
-- Eventos: ProximityPrompt (E nos baus), UI.open, ProfileUpdated, Batalha
--------------------------------------------------------------------
ProximityPromptService.PromptTriggered:Connect(function(prompt, triggerPlayer)
	if triggerPlayer ~= player then
		return
	end
	if prompt.Name == "LevelRewardsPrompt" then
		openWindow()
	end
end)

UI.onOpen("LevelRewards", function()
	openWindow()
end)

UI.onBattle(function(on)
	if on then
		win.Close(true)
	end
end)

Remotes:WaitForChild("ProfileUpdated").OnClientEvent:Connect(function(p)
	if typeof(p) == "table" then
		profile = p
		if win.IsOpen() then
			render(true)
		end
	end
end)

task.spawn(function()
	local ok, p = pcall(function()
		return Remotes:WaitForChild("GetProfile"):InvokeServer()
	end)
	if ok and typeof(p) == "table" then
		profile = p
		if win.IsOpen() then
			render(true)
		end
	end
end)
