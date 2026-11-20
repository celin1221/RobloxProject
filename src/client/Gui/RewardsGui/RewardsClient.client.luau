--[[
	RewardsClient (GDD secao 13 - retorno)
	Tela Premios: Login (7 dias), Baus (tempo online), Missoes (3 diarias e 5 semanais),
	Temporada do Infinito e Codigos. Abre pelo botao Premios do HUD (UI.open("Rewards")) e sozinha
	quando a recompensa do dia esta pendente. Marca no PlayerGui: RewardsBadge (ponto vermelho no HUD)
	e WeekendEvent (aviso do evento no HUD).
	O cliente so mostra e pede; o servidor valida e entrega (RetentionService).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local gui = script.Parent
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Data = ReplicatedStorage:WaitForChild("Data")
local Retention = require(Data:WaitForChild("Retention"))
local Items = require(Data:WaitForChild("Items"))
local UI = require(ReplicatedStorage:WaitForChild("UI"))
local T = UI.Theme

local profile = nil
local receivedAt = os.clock()

local function now(): number
	return os.time() + (ReplicatedStorage:GetAttribute("RetentionOffset") or 0)
end

local function fmtTime(s: number): string
	s = math.max(0, math.floor(s))
	local d, h, m = s // 86400, (s % 86400) // 3600, (s % 3600) // 60
	if d > 0 then
		return d .. "d " .. h .. "h"
	elseif h > 0 then
		return h .. "h " .. m .. "min"
	end
	return string.format("%d:%02d", m, s % 60)
end

-- Texto e icone de uma recompensa
local function rewardText(r): string
	local parts = {}
	if r.Gold then
		table.insert(parts, UI.fmt(r.Gold) .. " gold")
	end
	if r.Gems then
		table.insert(parts, r.Gems .. " gemas")
	end
	local ids = {}
	for id in pairs(r.Items or {}) do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local item = Items.Get(id)
		table.insert(parts, r.Items[id] .. "x " .. (if item then item.Name else id))
	end
	for kind, n in pairs(r.Tickets or {}) do
		table.insert(parts, n .. " invoca\u{e7}\u{e3}o " .. (if kind == "Premium" then "Premium" else "Comum"))
	end
	if r.Xp then
		table.insert(parts, r.Xp .. " XP")
	end
	return table.concat(parts, " + ")
end

local function rewardIcon(r): string
	if r.Tickets then
		return "ticket"
	elseif r.Gems then
		return "gem"
	elseif r.Items and not r.Gold then
		local id = next(r.Items)
		return if id and string.find(id, "Selo") then "seal" else "potion"
	end
	return "coin"
end

--------------------------------------------------------------------
-- Estado calculado a partir do perfil
--------------------------------------------------------------------
local function loginState()
	local today = Retention.Day(now())
	local L = profile.DailyLogin or { LastDay = 0, Streak = 0 }
	local claimed = L.LastDay == today
	local current = if claimed then L.Streak elseif L.LastDay == today - 1 and L.Streak < #Retention.Login then L.Streak + 1 else 1
	return current, claimed
end

local function sessionSeconds(): number
	local s = profile.Session
	if not s or s.Day ~= Retention.Day(now()) then
		return 0
	end
	return s.Seconds + (os.clock() - receivedAt)
end

local function chestClaimed(i: number): boolean
	local s = profile.Session
	return s ~= nil and s.Day == Retention.Day(now()) and s.Claimed ~= nil and s.Claimed["c" .. i] == true
end

local function anythingToClaim(): boolean
	if not profile or not profile.StarterChosen then
		return false
	end
	local _, claimed = loginState()
	if not claimed then
		return true
	end
	local secs = sessionSeconds()
	for i, c in ipairs(Retention.Chests) do
		if not chestClaimed(i) and secs >= c.Minutes * 60 then
			return true
		end
	end
	return false
end

--------------------------------------------------------------------
-- Janela
--------------------------------------------------------------------
local canvas = UI.screen(gui)
gui.DisplayOrder = 9
local win = UI.window(canvas, { Name = "RewardsWindow", Title = "PR\u{ca}MIOS", Icon = "gift", HeaderColor = "purple", Size = UDim2.fromScale(0.92, 0.86), Aspect = 1.95 })
local body = win.Body
local content = UI.frame(body, { Name = "Content", Size = UDim2.fromScale(1, 0.72), Position = UDim2.fromScale(0, 0.205) })
local msg = UI.text(body, "", { Name = "Message", Size = UDim2.fromScale(1, 0.07), Position = UDim2.fromScale(0, 0.935), Role = "Small", Color = "gold" })

local function show(ok, text)
	msg.TextColor3 = if ok then T.Palette.gold else T.Palette.hpLow
	msg.Text = text or ""
	UI.play(if ok then "reward" else "error")
end

local tab = "Login"
local timers = {} -- funcoes que atualizam textos de tempo a cada segundo
local render
local selectTab, tabButtons = UI.tabs(body, {
	{ Id = "Login", Text = "LOGIN" },
	{ Id = "Baus", Text = "BA\u{da}S" },
	{ Id = "Missoes", Text = "MISS\u{d5}ES" },
	{ Id = "Temporada", Text = "TEMPORADA" },
	{ Id = "Codigos", Text = "C\u{d3}DIGOS" },
}, { Size = UDim2.fromScale(1, 0.11), ActiveColor = "purple" }, function(id)
	tab = id
	msg.Text = ""
	render()
end)
UI.fillBetween(content, body:FindFirstChild("Tabs"), msg, 6)

local function ask(action, arg)
	local ok, text = Remotes.Rewards:InvokeServer(action, arg)
	show(ok, text)
end

-- Login: 7 cartas
local function renderLogin()
	local current, claimed = loginState()
	local row = UI.frame(content, { Name = "Days", Size = UDim2.fromScale(1, 0.57) })
	for i, r in ipairs(Retention.Login) do
		local done = i < current or (i == current and claimed)
		local ready = i == current and not claimed
		local card, face = UI.panel(row, { Name = "Day" .. i, Size = UDim2.fromScale(0.13, 1), Position = UDim2.fromScale((i - 1) * 0.145, 0), Color = if i == 7 then "purple" elseif done then "slot" else "panelAlt", Corner = T.Corner.Card })
		if ready then
			UI.stroke(face, T.Palette.gold, 1.4)
			UI.shine(card)
		end
		UI.text(face, "DIA " .. i, { Name = "Day", Size = UDim2.fromScale(0.9, 0.16), Position = UDim2.fromScale(0.05, 0.04), Role = "Small" })
		UI.icon(face, rewardIcon(r), { Name = "Icon", Size = UDim2.fromScale(0.75, 0.32), Position = UDim2.fromScale(0.5, 0.24), AnchorPoint = Vector2.new(0.5, 0) })
		UI.text(face, rewardText(r), { Name = "Reward", Size = UDim2.fromScale(0.9, if r.Tickets then 0.28 else 0.2), Position = UDim2.fromScale(0.05, if r.Tickets then 0.55 else 0.58), Role = "Small", Color = if r.Tickets then "gems" else "gold" })
		if done then
			UI.icon(face, "tick", { Name = "Done", Size = UDim2.fromScale(0.5, if r.Tickets then 0.14 else 0.18), Position = UDim2.fromScale(0.5, if r.Tickets then 0.84 else 0.8), AnchorPoint = Vector2.new(0.5, 0) })
		elseif ready then
			UI.text(face, "HOJE", { Name = "Today", Size = UDim2.fromScale(0.9, 0.14), Position = UDim2.fromScale(0.05, if r.Tickets then 0.84 else 0.82), Role = "Small", Color = "gold" })
		end
	end
	if claimed then
		local l = UI.text(content, "", { Name = "Info", Size = UDim2.fromScale(1, 0.14), Position = UDim2.fromScale(0, 0.64), Role = "Body", Color = "inkSoft" })
		table.insert(timers, function()
			l.Text = "Recompensa de hoje recebida. Pr\u{f3}xima em " .. fmtTime((Retention.Day(now()) + 1) * 86400 - now()) .. "."
		end)
	else
		UI.button(content, { Name = "Claim", Text = "RECEBER DIA " .. current, Icon = "gift", Layout = "row", Color = "green", Size = UDim2.fromScale(0.36, 0.24), Position = UDim2.fromScale(0.5, 0.61), AnchorPoint = Vector2.new(0.5, 0), Role = "Body", Sound = false,
			OnClick = function()
				ask("Login")
			end,
		})
	end
	UI.text(content, "Entre todo dia: se pular um dia, volta para o dia 1.", { Name = "Rule", Size = UDim2.fromScale(1, 0.09), Position = UDim2.fromScale(0, 0.91), Role = "Small", Color = "inkSoft", StrokeMult = 0.4 })
end

-- Baus por tempo online no dia
local function renderChests()
	local clock = UI.text(content, "", { Name = "Clock", Size = UDim2.fromScale(1, 0.1), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left })
	table.insert(timers, function()
		clock.Text = "Tempo de jogo hoje: " .. fmtTime(sessionSeconds()) .. "  \u{b7}  os ba\u{fa}s voltam todo dia (00:00 UTC)"
	end)
	for i, c in ipairs(Retention.Chests) do
		local card, face = UI.panel(content, { Name = "Chest" .. i, Size = UDim2.fromScale(0.235, 0.86), Position = UDim2.fromScale((i - 1) * 0.255, 0.13), Color = "panelAlt", Corner = T.Corner.Card })
		UI.text(face, c.Minutes .. " MIN", { Name = "Time", Size = UDim2.fromScale(0.9, 0.12), Position = UDim2.fromScale(0.05, 0.04), Role = "Body" })
		UI.icon(face, "chest", { Name = "Icon", Size = UDim2.fromScale(0.62, 0.3), Position = UDim2.fromScale(0.5, 0.17), AnchorPoint = Vector2.new(0.5, 0) })
		UI.text(face, rewardText(c), { Name = "Reward", Size = UDim2.fromScale(0.9, 0.18), Position = UDim2.fromScale(0.05, 0.5), Role = "Small", Color = "gold" })
		local b = UI.button(face, { Name = "Open", Text = "", Color = "grey", Size = UDim2.fromScale(0.86, 0.22), Position = UDim2.fromScale(0.07, 0.74), Role = "Body", Sound = false,
			OnClick = function()
				ask("Chest", i)
			end,
		})
		local wasReady = nil
		table.insert(timers, function()
			local ready
			if chestClaimed(i) then
				UI.setText(b, "ABERTO \u{2713}")
				ready = false
			else
				local left = c.Minutes * 60 - sessionSeconds()
				ready = left <= 0
				UI.setText(b, if ready then "ABRIR" else fmtTime(left))
			end
			if ready ~= wasReady then
				UI.paint(b, if ready then "green" else "grey")
				if ready then
					UI.shine(card)
				end
				wasReady = ready
			end
		end)
	end
end

-- Missoes
local function missionRow(list, order, text, progress, goal, reward, done)
	local row, face = UI.panel(list, { Name = "M" .. order, Size = UDim2.fromScale(0.98, 0), Aspect = 9.5, Color = if done then "green" else "panelAlt", Corner = 0.3, LayoutOrder = order })
	UI.text(face, text, { Name = "Text", Size = UDim2.fromScale(0.56, 0.46), Position = UDim2.fromScale(0.03, 0.08), Role = "Small", AlignX = Enum.TextXAlignment.Left })
	if reward ~= "" then
		UI.text(face, reward, { Name = "Reward", Size = UDim2.fromScale(0.56, 0.34), Position = UDim2.fromScale(0.03, 0.58), Role = "Small", Color = "gold", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.5 })
	end
	if done then
		UI.text(face, "CONCLU\u{cd}DA", { Name = "Done", Size = UDim2.fromScale(0.3, 0.5), Position = UDim2.fromScale(0.97, 0.25), AnchorPoint = Vector2.new(1, 0), Role = "Small", AlignX = Enum.TextXAlignment.Right })
	else
		local bar = UI.bar(face, { Name = "Progress", Size = UDim2.fromScale(0.26, 0.26), Position = UDim2.fromScale(0.62, 0.37), FillColor = "gold" })
		UI.setBar(bar, if goal > 0 then progress / goal else 0, "gold", true)
		UI.text(face, progress .. "/" .. goal, { Name = "Progress", Size = UDim2.fromScale(0.08, 0.5), Position = UDim2.fromScale(0.98, 0.25), AnchorPoint = Vector2.new(1, 0), Role = "Small", AlignX = Enum.TextXAlignment.Right })
	end
end

local function header(list, order, text, timerFn)
	local l = UI.text(list, text, { Name = "H" .. order, Size = UDim2.fromScale(0.98, 0), Aspect = 16, Role = "Small", Color = "purple", AlignX = Enum.TextXAlignment.Left, LayoutOrder = order })
	l.TextColor3 = Color3.fromRGB(215, 175, 255)
	if timerFn then
		table.insert(timers, function()
			l.Text = text .. "  \u{b7}  renovam em " .. fmtTime(timerFn())
		end)
	end
end

local function renderMissions()
	local list = UI.scroll(content, { Name = "List", Size = UDim2.fromScale(1, 1), Gap = 0.012 })
	local m = profile.Missions or {}
	local today = Retention.Day(now())
	local week = Retention.Week(now())
	header(list, 1, "DI\u{c1}RIAS", function()
		return (Retention.Day(now()) + 1) * 86400 - now()
	end)
	if m.Day == today then
		local done = 0
		for i, e in ipairs(m.Daily or {}) do
			local def = Retention.Daily.Pool[e.Id]
			if def then
				if e.Done then
					done += 1
				end
				missionRow(list, 1 + i, string.format(def.Text, def.Goal), e.Progress, def.Goal, rewardText(Retention.Daily.Reward), e.Done)
			end
		end
		missionRow(list, 9, "Completar as 3 di\u{e1}rias", done, #(m.Daily or {}), rewardText(Retention.Daily.AllReward), m.AllDone)
	else
		header(list, 2, "Carregando as miss\u{f5}es de hoje...")
	end
	header(list, 10, "SEMANAIS", function()
		return Retention.WeekEnd(now()) - now()
	end)
	if m.Week == week then
		local done = 0
		for i, w in ipairs(Retention.Weekly.List) do
			local e = (m.Weekly or {})[w.Id] or { Progress = 0, Done = false }
			if e.Done then
				done += 1
			end
			missionRow(list, 10 + i, string.format(w.Text, w.Goal), e.Progress, w.Goal, "", e.Done)
		end
		missionRow(list, 19, "Completar as 5 semanais", done, #Retention.Weekly.List, rewardText(Retention.Weekly.AllReward), m.WeeklyDone)
	end
end

-- Temporada do Infinito
local function renderSeason()
	local t = now()
	local id = Retention.SeasonId(t)
	local s = profile.Season or {}
	local best = if s.Id == id then s.Best or 0 else 0
	local title = UI.text(content, "", { Name = "Title", Size = UDim2.fromScale(0.6, 0.1), Position = UDim2.fromScale(0, 0.01), Role = "Body", AlignX = Enum.TextXAlignment.Left })
	table.insert(timers, function()
		title.Text = "Temporada " .. id .. "  \u{b7}  zera em " .. fmtTime(Retention.SeasonEnd(now()) - now())
	end)
	UI.text(content, "Seu melhor andar: " .. best, { Name = "Best", Size = UDim2.fromScale(0.6, 0.08), Position = UDim2.fromScale(0, 0.11), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left })
	for i, tier in ipairs(Retention.Season.Tiers) do
		local reached = best >= tier.Floor
		local row, face = UI.panel(content, { Name = "Tier" .. tier.Floor, Size = UDim2.fromScale(0.58, 0.13), Position = UDim2.fromScale(0, 0.22 + (i - 1) * 0.155), Color = if reached then "green" else "panelAlt", Corner = T.Corner.Pill })
		UI.text(face, "Andar " .. tier.Floor .. "+", { Name = "T", Size = UDim2.fromScale(0.45, 0.7), Position = UDim2.fromScale(0.05, 0.15), Role = "Body", AlignX = Enum.TextXAlignment.Left })
		UI.icon(face, "gem", { Size = UDim2.fromScale(0.12, 0.9), Position = UDim2.fromScale(0.6, 0.05) })
		UI.text(face, tier.Gems .. " gemas", { Name = "G", Size = UDim2.fromScale(0.25, 0.7), Position = UDim2.fromScale(0.95, 0.15), AnchorPoint = Vector2.new(1, 0), Role = "Body", Color = "gems", AlignX = Enum.TextXAlignment.Right })
	end
	local side, sface = UI.panel(content, { Name = "Top", Size = UDim2.fromScale(0.39, 0.78), Position = UDim2.fromScale(1, 0.22), AnchorPoint = Vector2.new(1, 0), Color = "slot", Corner = 0.1, Shadow = false })
	UI.icon(sface, "trophy", { Size = UDim2.fromScale(0.36, 0.34), Position = UDim2.fromScale(0.5, 0.04), AnchorPoint = Vector2.new(0.5, 0) })
	UI.text(sface, "Os " .. Retention.Season.TopCount .. " primeiros do placar global ganham a apar\u{ea}ncia " .. Retention.Season.TopTag .. " (t\u{ed}tulo e tag no chat).", { Name = "Top", Size = UDim2.fromScale(0.9, 0.3), Position = UDim2.fromScale(0.05, 0.4), Role = "Small", StrokeMult = 0.5 })
	local lines = {}
	if s.Last then
		table.insert(lines, string.format("Temporada %s: andar %d, %d gemas%s.", s.Last.Id, s.Last.Best or 0, s.Last.Gems or 0, if s.Last.Rank then ", " .. s.Last.Rank .. "\u{ba} lugar" else ""))
	end
	local top = profile.Cosmetics and profile.Cosmetics.InfinitoTop
	if top then
		table.insert(lines, "Apar\u{ea}ncia " .. Retention.Season.TopTag .. " (" .. top.Season .. ") ativa.")
	end
	UI.text(sface, table.concat(lines, "\n"), { Name = "Last", Size = UDim2.fromScale(0.9, 0.24), Position = UDim2.fromScale(0.05, 0.73), Role = "Small", Color = "gold", StrokeMult = 0.5 })
end

-- Codigos
local function renderCodes()
	UI.icon(content, "ticket", { Size = UDim2.fromScale(0.2, 0.26), Position = UDim2.fromScale(0.5, 0.02), AnchorPoint = Vector2.new(0.5, 0) })
	UI.text(content, "C\u{f3}digos s\u{e3}o divulgados nas atualiza\u{e7}\u{f5}es do jogo.", { Name = "Info", Size = UDim2.fromScale(1, 0.1), Position = UDim2.fromScale(0, 0.31), Role = "Small", Color = "inkSoft" })
	local boxHolder, boxFace = UI.panel(content, { Name = "CodeBox", Size = UDim2.fromScale(0.6, 0.26), Position = UDim2.fromScale(0.5, 0.42), AnchorPoint = Vector2.new(0.5, 0), Color = "slot", Corner = T.Corner.Pill, Shadow = false })
	local box = Instance.new("TextBox")
	box.Name = "Input"
	box.Size = UDim2.fromScale(0.9, 0.7)
	box.Position = UDim2.fromScale(0.05, 0.15)
	box.BackgroundTransparency = 1
	box.TextColor3 = Color3.new(1, 1, 1)
	box.PlaceholderText = "Digite o c\u{f3}digo"
	box.PlaceholderColor3 = T.Palette.inkSoft
	box.FontFace = T.Font
	box.TextScaled = true
	box.ClearTextOnFocus = false
	box.Text = ""
	box.Parent = boxFace
	UI.button(content, { Name = "Redeem", Text = "RESGATAR", Icon = "gift", Layout = "row", Color = "green", Size = UDim2.fromScale(0.32, 0.22), Position = UDim2.fromScale(0.5, 0.72), AnchorPoint = Vector2.new(0.5, 0), Role = "Body", Sound = false,
		OnClick = function()
			ask("Code", box.Text)
		end,
	})
end

render = function()
	UI.clear(content)
	table.clear(timers)
	if not profile then
		return
	end
	if tab == "Login" then
		renderLogin()
	elseif tab == "Baus" then
		renderChests()
	elseif tab == "Missoes" then
		renderMissions()
	elseif tab == "Temporada" then
		renderSeason()
	elseif tab == "Codigos" then
		renderCodes()
	end
	for _, fn in ipairs(timers) do
		fn()
	end
end

local function applyProfile(p)
	profile = p
	receivedAt = os.clock()
	if win.IsOpen() and tab ~= "Codigos" then
		render()
	end
end

Remotes:WaitForChild("ProfileUpdated").OnClientEvent:Connect(applyProfile)

UI.onOpen("Rewards", function(startTab)
	if win.IsOpen() and not startTab then
		win.Close()
		return
	end
	win.Open()
	selectTab(startTab or tab)
end)

-- Atualiza tempos, aviso do evento (HUD) e o ponto vermelho
task.spawn(function()
	local pg = player:WaitForChild("PlayerGui")
	local lastDay = nil
	while true do
		if profile then
			if win.IsOpen() then
				for _, fn in ipairs(timers) do
					fn()
				end
			end
			pg:SetAttribute("RewardsBadge", anythingToClaim())
			-- "!" em cima de cada aba com recompensa para pegar
			if profile.StarterChosen then
				local _, loginClaimed = loginState()
				UI.badge(tabButtons.Login, not loginClaimed)
				local secs, chest = sessionSeconds(), false
				for i, c in ipairs(Retention.Chests) do
					if not chestClaimed(i) and secs >= c.Minutes * 60 then
						chest = true
					end
				end
				UI.badge(tabButtons.Baus, chest)
			end
			local ev = Retention.EventAt(now())
			pg:SetAttribute("WeekendEvent", if ev then "FIM DE SEMANA: " .. UI.upper(Retention.EventNames[ev]) else "")
			local day = Retention.Day(now())
			if lastDay and day ~= lastDay and win.IsOpen() then
				render()
			end
			lastDay = day
		end
		task.wait(1)
	end
end)

-- Primeira carga: abre no Login se houver recompensa do dia
task.spawn(function()
	local ok, p = pcall(function()
		return Remotes:WaitForChild("GetProfile"):InvokeServer()
	end)
	if ok and p then
		applyProfile(p)
	end
	local t0 = os.clock()
	while os.clock() - t0 < 120 and not (profile and profile.StarterChosen) do
		task.wait(1)
	end
	if profile and profile.StarterChosen and not UI.inBattle() then
		local _, claimed = loginState()
		if not claimed then
			UI.open("Rewards", "Login")
		end
	end
end)

UI.onBattle(function(inBattle)
	if inBattle then
		win.Close(true)
	end
end)
