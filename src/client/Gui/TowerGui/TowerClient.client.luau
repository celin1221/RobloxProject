--[[
	TowerClient (GDD secoes 6 e 10 - tela da Torre)
	Modos (Facil, Medio, Dificil, Infinito) com recompensa e botao Entrar; placar da temporada (servidor e global).
	Abre quando o servidor manda TowerOpen (gatilho da entrada da torre).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local gui = script.Parent
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Tower = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("Tower"))
local Items = require(ReplicatedStorage.Data:WaitForChild("Items"))
local UI = require(ReplicatedStorage:WaitForChild("UI"))
local T = UI.Theme

local MODE_COLOR = { Facil = "green", Medio = "orange", Dificil = "red", Infinito = "purple" }

local canvas = UI.screen(gui)
gui.DisplayOrder = 8
local win = UI.window(canvas, { Name = "TowerWindow", Title = "TORRE", Icon = "tower", HeaderColor = "purple", Size = UDim2.fromScale(0.92, 0.86), Aspect = 1.95,
	OnClose = function()
		Remotes.TowerClose:FireServer()
	end,
})
local body = win.Body
local msg = UI.text(body, "", { Name = "Message", Size = UDim2.fromScale(0.6, 0.07), Position = UDim2.fromScale(0, 0.94), Role = "Small", Color = "hpLow", AlignX = Enum.TextXAlignment.Left })

local modes = UI.frame(body, { Name = "Modes", Size = UDim2.fromScale(0.64, 0.92) })
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0.025, 0)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = modes

local function rewardText(m)
	if m.Battles == nil then
		return string.format("%d gold por andar, +%d a cada %d", m.GoldPerFloor, m.BonusGold, m.BonusEvery)
	end
	local parts = { m.Reward.Gold .. " gold" }
	for _, id in ipairs(m.Reward.Items) do
		table.insert(parts, Items.Get(id).Name)
	end
	if m.Reward.DailyGems then
		table.insert(parts, m.Reward.DailyGems .. " gemas/dia")
	end
	return table.concat(parts, ", ")
end

local rows = {}
for i, id in ipairs(Tower.Order) do
	local m = Tower.Modes[id]
	local row, face = UI.panel(modes, { Name = "Row_" .. id, Size = UDim2.fromScale(1, 0.23), Color = "panelAlt", Corner = 0.22, LayoutOrder = i })
	UI.stroke(face, UI.pair(MODE_COLOR[id]), 1.2)
	UI.text(face, UI.upper(m.Name), { Name = "Name", Size = UDim2.fromScale(0.5, 0.36), Position = UDim2.fromScale(0.03, 0.08), Role = "Heading", Color = select(2, UI.pair(MODE_COLOR[id])), AlignX = Enum.TextXAlignment.Left })
	local desc
	if m.Battles then
		desc = string.format("%d lutas \u{b7} %d por NPC \u{b7} nv. %d-%d \u{b7} sem cura", m.Battles, m.TeamSize, m.MinLevel, m.MaxLevel)
	else
		desc = string.format("%d por NPC \u{b7} nv. %d +%d/andar \u{b7} cura 30%%", m.TeamSize, m.BaseLevel, m.LevelPerFloor)
	end
	UI.text(face, desc, { Name = "Info", Size = UDim2.fromScale(0.73, 0.24), Position = UDim2.fromScale(0.03, 0.44), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.4 })
	UI.icon(face, "trophy", { Size = UDim2.fromScale(0.04, 0.26), Position = UDim2.fromScale(0.03, 0.7) })
	UI.text(face, rewardText(m), { Name = "Reward", Size = UDim2.fromScale(0.68, 0.24), Position = UDim2.fromScale(0.075, 0.71), Role = "Small", Color = "gold", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.5 })
	local b = UI.button(face, { Name = "Enter_" .. id, Text = "ENTRAR", Color = MODE_COLOR[id], Size = UDim2.fromScale(0.2, 0.66), Position = UDim2.fromScale(0.97, 0.5), AnchorPoint = Vector2.new(1, 0.5), Role = "Body" })
	local lockIcon = UI.icon(b.Face, "lock", { Name = "Lock", Size = UDim2.fromScale(0.5, 0.78), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Visible = false })
	rows[id] = { Button = b, Lock = lockIcon, Open = false }
	b.Activated:Connect(function()
		if not rows[id].Open then
			msg.Text = "Conclua o modo anterior para desbloquear."
			return
		end
		msg.Text = ""
		local ok, err = Remotes.TowerStart:InvokeServer(id)
		if ok then
			win.Close(true)
		else
			msg.Text = err or "N\u{e3}o foi poss\u{ed}vel entrar."
			UI.play("error")
		end
	end)
end

-- Placar da temporada do Infinito
local board, boardFace = UI.panel(body, { Name = "Board", Size = UDim2.fromScale(0.34, 0.92), Position = UDim2.fromScale(0.66, 0), Color = "slot", Corner = 0.06, Shadow = false })
local boardTitle = UI.text(boardFace, "Placar do Infinito", { Name = "Title", Size = UDim2.fromScale(0.9, 0.16), Position = UDim2.fromScale(0.05, 0.02), Role = "Small", AlignX = Enum.TextXAlignment.Left, Wrap = true })
local best = UI.text(boardFace, "", { Name = "Best", Size = UDim2.fromScale(0.94, 0.08), Position = UDim2.fromScale(0.03, 0.18), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.4 })
local tab = "Server"
local boardData = nil
local listBox = UI.scroll(boardFace, { Name = "List", Size = UDim2.fromScale(0.94, 0.5), Position = UDim2.fromScale(0.03, 0.48), Gap = 0.015 })

local function renderBoard()
	UI.clear(listBox)
	local list = boardData and boardData[tab] or {}
	if #list == 0 then
		UI.text(listBox, "Ningu\u{e9}m no placar ainda.", { Name = "Empty", Size = UDim2.fromScale(1, 0), Aspect = 6, Role = "Small", Color = "inkSoft" })
		return
	end
	for i, e in ipairs(list) do
		local color = if i == 1 then "lendario" elseif i == 2 then "comum" elseif i == 3 then "orange" else "panelAlt"
		local row, f = UI.panel(listBox, { Name = "Entry" .. i, Size = UDim2.fromScale(1, 0), Aspect = 6, Color = color, Corner = T.Corner.Pill, Shadow = false, LayoutOrder = i })
		UI.text(f, i .. ". " .. e.Name, { Name = "Name", Size = UDim2.fromScale(0.62, 0.7), Position = UDim2.fromScale(0.05, 0.15), Role = "Small", AlignX = Enum.TextXAlignment.Left })
		UI.text(f, "andar " .. e.Floor, { Name = "Floor", Size = UDim2.fromScale(0.3, 0.7), Position = UDim2.fromScale(0.95, 0.15), AnchorPoint = Vector2.new(1, 0), Role = "Small", AlignX = Enum.TextXAlignment.Right })
	end
end

local selectTab = UI.tabs(boardFace, { { Id = "Server", Text = "SERVIDOR" }, { Id = "Global", Text = "GLOBAL" } }, { Size = UDim2.fromScale(0.9, 0.18), Position = UDim2.fromScale(0.05, 0.28), MaxWidth = 0.49, ActiveColor = "purple" }, function(id)
	tab = id
	renderBoard()
end)

local function applyInfo(info)
	if not info then
		return
	end
	if info.Season then
		local days = math.max(0, math.ceil(((info.SeasonEnd or 0) - (os.time() + (ReplicatedStorage:GetAttribute("RetentionOffset") or 0))) / 86400))
		boardTitle.Text = "Temporada " .. info.Season .. " \u{b7} zera em " .. days .. " dia" .. (if days == 1 then "" else "s")
		best.Text = "Temporada: " .. (info.SeasonBest or 0) .. " \u{b7} Recorde: " .. (info.BestFloor or 0)
	else
		best.Text = "Seu recorde: andar " .. (info.BestFloor or 0)
	end
	for id, r in pairs(rows) do
		local open = Tower.IsUnlocked(info.Unlocked, id)
		r.Open = open
		UI.setText(r.Button, if open then "ENTRAR" else "")
		UI.setDisabled(r.Button, not open, MODE_COLOR[id])
		r.Lock.Visible = not open
	end
end

local function open(info)
	if UI.inBattle() then
		return
	end
	msg.Text = ""
	applyInfo(info)
	win.Open()
	selectTab(tab)
	task.spawn(function()
		local ok, data = pcall(function()
			return Remotes.TowerBoard:InvokeServer()
		end)
		if ok and data then
			boardData = data
			applyInfo(data.Info)
			renderBoard()
		end
	end)
end

Remotes:WaitForChild("TowerOpen").OnClientEvent:Connect(open)
