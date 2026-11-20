--[[
	TeamBarClient (GDD secao 10 - barra do time)
	- Barra fixa embaixo, no centro (entre a zona do analogico e a do pulo), com os 6 espacos do time na ordem.
	- Visivel no mapa e na base; some na batalha, no Refugio e com qualquer tela cheia aberta.
	- Espaco ocupado: cartao 3D (TeamCards); toque abre o cartao do personagem (atributos, golpes, Trocar, Golpes, Remover).
	- Espaco vazio: "+" abre a tela de Equipe nesse espaco.
	- Tamanho: 6 espacos cabem na faixa livre; cada um com no minimo 44 px.
	- Os modelos balancam devagar so com "Efeitos do mapa" ligado e a barra visivel.
	O time mostrado e sempre o do servidor (ProfileUpdated / TeamResult).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local gui = script.Parent
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Data = ReplicatedStorage:WaitForChild("Data")
local Characters = require(Data:WaitForChild("Characters"))
local Moves = require(Data:WaitForChild("Moves"))
local Progression = require(Data:WaitForChild("Progression"))
local UI = require(ReplicatedStorage:WaitForChild("UI"))
local TeamCards = require(ReplicatedStorage:WaitForChild("TeamCards"))
local T = UI.Theme

local MAX = 6
local SAFE_LEFT, SAFE_RIGHT = T.Safe.Thumbstick[3], T.Safe.Jump[1] -- faixa livre entre analogico e pulo

local profile = nil
local canvas = UI.screen(gui)
gui.DisplayOrder = 6 -- acima do HUD (5): o cartao do personagem fica por cima do menu

--------------------------------------------------------------------
-- Barra
--------------------------------------------------------------------
local bar, barFace = UI.panel(canvas, { Name = "TeamBar", Color = "slot", Transparency = 0.25, Corner = 0.3, Shadow = false, AnchorPoint = Vector2.new(0.5, 1) })
local slots = {}
for i = 1, MAX do
	local c = TeamCards.new(barFace, { Name = "Slot" .. i, ZIndex = 3 })
	slots[i] = c
end

local function layoutBar()
	local W, H = canvas.AbsoluteSize.X, canvas.AbsoluteSize.Y
	if W < 10 then
		return
	end
	local free = (SAFE_RIGHT - SAFE_LEFT) * W
	-- espaco = o maior que cabe (s*6 + gap*5 + pad*2 <= faixa livre), entre 44 px e 80 px
	local s = math.floor(free / (MAX + (MAX - 1) * 0.14 + 0.32))
	s = math.clamp(s, T.TouchMin, math.min(80, math.floor(H * 0.2)))
	-- o que sobra vira espaco entre os cartoes e margem (no celular pequeno fica justo)
	local rest = math.max(0, free - s * MAX)
	local gap = math.clamp(math.floor(rest * 0.7 / (MAX - 1)), 2, math.floor(s * 0.14))
	local pad = math.clamp(math.floor((rest - gap * (MAX - 1)) / 2), 2, math.floor(s * 0.16))
	local w = s * MAX + gap * (MAX - 1) + pad * 2
	bar.Size = UDim2.fromOffset(w, s + pad * 2)
	bar.Position = UDim2.new((SAFE_LEFT + SAFE_RIGHT) / 2, 0, 1, -math.floor(H * 0.02))
	for i, c in ipairs(slots) do
		c.Root.Size = UDim2.fromOffset(s, s)
		c.Root.Position = UDim2.fromOffset(pad + (i - 1) * (s + gap), pad)
	end
end
canvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutBar)
task.defer(layoutBar)

--------------------------------------------------------------------
-- Cartao do personagem (toque num espaco ocupado)
--------------------------------------------------------------------
local catcher = Instance.new("TextButton")
catcher.Name = "PopupCatcher"
catcher.Text = ""
catcher.BackgroundTransparency = 1
catcher.Size = UDim2.fromScale(3, 3)
catcher.Position = UDim2.fromScale(-1, -1)
catcher.ZIndex = 9
catcher.Visible = false
catcher.Parent = canvas

local pop, popFace = UI.panel(canvas, { Name = "MemberCard", Size = UDim2.fromScale(0.48, 0.62), AnchorPoint = Vector2.new(0.5, 1), Color = "panel", Corner = 0.08, Aspect = 1.62, AspectAxis = Enum.DominantAxis.Height, ZIndex = 10, Visible = false, MaxSize = Vector2.new(520, 324) })
local popName = UI.text(popFace, "", { Name = "Name", Size = UDim2.fromScale(0.62, 0.15), Position = UDim2.fromScale(0.04, 0.04), Role = "Heading", AlignX = Enum.TextXAlignment.Left, ZIndex = 11 })
local popInfo = UI.text(popFace, "", { Name = "Info", Size = UDim2.fromScale(0.34, 0.12), Position = UDim2.fromScale(0.96, 0.055), AnchorPoint = Vector2.new(1, 0), Role = "Small", AlignX = Enum.TextXAlignment.Right, ZIndex = 11, Rich = true })
local statsRow = UI.frame(popFace, { Name = "Stats", Size = UDim2.fromScale(0.92, 0.15), Position = UDim2.fromScale(0.04, 0.22), ZIndex = 11 })
local statLabels = {}
for i, st in ipairs({ { "HP", "HP" }, { "Attack", "ATQ" }, { "Defense", "DEF" }, { "Speed", "VEL" } }) do
	local box, bf = UI.panel(statsRow, { Name = st[1], Size = UDim2.fromScale(0.235, 1), Position = UDim2.fromScale((i - 1) * 0.255, 0), Color = "slot", Corner = 0.3, Shadow = false, ZIndex = 11 })
	statLabels[st[1]] = UI.text(bf, "", { Name = "Value", Size = UDim2.fromScale(0.9, 0.8), Position = UDim2.fromScale(0.05, 0.1), Role = "Small", ZIndex = 12, Rich = true })
	statLabels[st[1]]:SetAttribute("Short", st[2])
end
local movesBox = UI.frame(popFace, { Name = "Moves", Size = UDim2.fromScale(0.92, 0.3), Position = UDim2.fromScale(0.04, 0.4), ZIndex = 11 })
local moveChips = {}
for i = 1, 4 do
	local col, row = (i - 1) % 2, (i - 1) // 2
	local chip, cf = UI.panel(movesBox, { Name = "Move" .. i, Size = UDim2.fromScale(0.49, 0.46), Position = UDim2.fromScale(col * 0.51, row * 0.54), Color = "slot", Corner = 0.4, Shadow = false, ZIndex = 11 })
	moveChips[i] = { Holder = chip, Face = cf, Text = UI.text(cf, "", { Name = "Text", Size = UDim2.fromScale(0.9, 0.8), Position = UDim2.fromScale(0.05, 0.1), Role = "Small", ZIndex = 12 }) }
end
local btnRow = UI.frame(popFace, { Name = "Buttons", Size = UDim2.fromScale(0.92, 0.2), Position = UDim2.fromScale(0.04, 0.76), ZIndex = 11 })
local popUid, popSlot = nil, nil

local function closePop()
	pop.Visible = false
	catcher.Visible = false
	popUid, popSlot = nil, nil
	for _, c in ipairs(slots) do
		c.SetSelected(false)
	end
end
catcher.Activated:Connect(closePop)

local function sendTeam(list)
	Remotes:WaitForChild("SetTeam"):FireServer(list)
end

UI.button(btnRow, { Name = "Details", Text = "STATUS", Color = "teal", Role = "Small", Size = UDim2.fromScale(0.235, 1), Position = UDim2.fromScale(0, 0), ZIndex = 12,
	OnClick = function()
		local uid = popUid
		closePop()
		UI.open("CharacterDetail", uid)
	end,
})
UI.button(btnRow, { Name = "Swap", Text = "TROCAR", Color = "blue", Role = "Small", Size = UDim2.fromScale(0.235, 1), Position = UDim2.fromScale(0.255, 0), ZIndex = 12,
	OnClick = function()
		local s = popSlot
		closePop()
		UI.open("Equipe", s)
	end,
})
UI.button(btnRow, { Name = "Moves", Text = "GOLPES", Color = "purple", Role = "Small", Size = UDim2.fromScale(0.235, 1), Position = UDim2.fromScale(0.51, 0), ZIndex = 12,
	OnClick = function()
		local uid = popUid
		closePop()
		UI.open("Team", uid)
	end,
})
UI.button(btnRow, { Name = "Remove", Text = "REMOVER", Color = "red", Role = "Small", Size = UDim2.fromScale(0.235, 1), Position = UDim2.fromScale(0.765, 0), ZIndex = 12,
	OnClick = function()
		if not profile or not popUid then
			return
		end
		if #profile.Team <= 1 then
			UI.toast("O time precisa de pelo menos 1 personagem.", "error")
			UI.play("error")
			return
		end
		local list = {}
		for _, uid in ipairs(profile.Team) do
			if uid ~= popUid then
				table.insert(list, uid)
			end
		end
		closePop()
		sendTeam(list)
	end,
})

local function typeColor(t)
	return T.Types[t] or T.Palette.grey
end

local function openPop(i: number)
	local uid = profile and profile.Team[i]
	local m = uid and profile.Collection[uid]
	local def = m and Characters.Get(m.CharacterId)
	if not def then
		return
	end
	popUid, popSlot = uid, i
	local rarity = Characters.Rarities[def.Rarity]
	popName.Text = def.Name
	popName.TextColor3 = T.Rarity[def.Rarity] or T.Palette.onDark
	local stars = if (m.Stars or 0) > 0 then (" \u{b7} " .. m.Stars .. "\u{2605}") else ""
	popInfo.Text = (rarity and rarity.Name or def.Rarity) .. " \u{b7} Nv " .. m.Level .. stars .. (if m.Variant then " \u{b7} " .. m.Variant else "")
	local stats = Progression.MemberStats(m)
	local cur = Progression.CurrentHp(m)
	for key, l in pairs(statLabels) do
		local v = if key == "HP" then (cur .. "/" .. stats.HP) else tostring(stats[key])
		l.Text = l:GetAttribute("Short") .. " " .. v
	end
	for k = 1, 4 do
		local id = m.Active and m.Active[k]
		local mv = id and Moves.Get(id)
		local chip = moveChips[k]
		chip.Holder.Visible = mv ~= nil
		if mv then
			chip.Text.Text = mv.Name
			local c = typeColor(mv.Type)
			chip.Face.Fill.Color = ColorSequence.new(c, c:Lerp(Color3.new(0, 0, 0), 0.35))
		end
	end
	-- acima do espaco tocado, sem sair da tela
	local slotRoot = slots[i].Root
	local cx = slotRoot.AbsolutePosition.X + slotRoot.AbsoluteSize.X / 2 - canvas.AbsolutePosition.X
	pop.Visible = true
	catcher.Visible = true
	local w = pop.AbsoluteSize.X
	local x = math.clamp(cx, w / 2 + 4, canvas.AbsoluteSize.X - w / 2 - 4)
	pop.Position = UDim2.new(0, x, 0, bar.AbsolutePosition.Y - canvas.AbsolutePosition.Y - 8)
	for k, c in ipairs(slots) do
		c.SetSelected(k == i)
	end
end

for i, c in ipairs(slots) do
	c.Root.Activated:Connect(function()
		if not profile then
			return
		end
		UI.play("click")
		if c.Uid then
			if popSlot == i then
				closePop()
			else
				openPop(i)
			end
		else
			closePop()
			UI.open("Equipe", i)
		end
	end)
end

--------------------------------------------------------------------
-- Dados e visibilidade
--------------------------------------------------------------------
local function refresh()
	if not profile then
		return
	end
	for i = 1, MAX do
		local uid = profile.Team[i]
		slots[i].Set(uid, uid and profile.Collection[uid] or nil)
	end
	if popUid and not table.find(profile.Team, popUid) then
		closePop()
	elseif popSlot then
		openPop(popSlot)
	end
end

local inBattle = false
local function updateVisible()
	local show = profile ~= nil and profile.StarterChosen == true and not inBattle and not UI.anyWindowOpen() and not player:GetAttribute("InRefuge")
	bar.Visible = show
	if not show then
		closePop()
	end
end

UI.onBattle(function(on)
	inBattle = on
	updateVisible()
end)
UI.onWindows(updateVisible)
player:GetAttributeChangedSignal("InRefuge"):Connect(updateVisible)

Remotes:WaitForChild("ProfileUpdated").OnClientEvent:Connect(function(p)
	if typeof(p) == "table" then
		profile = p
		refresh()
		updateVisible()
	end
end)
task.spawn(function()
	local ok, p = pcall(function()
		return Remotes:WaitForChild("GetProfile"):InvokeServer()
	end)
	if ok and typeof(p) == "table" then
		profile = p
		refresh()
		updateVisible()
	end
end)
task.spawn(function()
	local res = Remotes:WaitForChild("TeamResult")
	res.OnClientEvent:Connect(function(r)
		if typeof(r) ~= "table" then
			return
		end
		if r.Message then
			UI.toast(r.Message, if r.Ok then nil else "error")
		end
		if not r.Ok then
			UI.play("error")
		end
	end)
end)

--------------------------------------------------------------------
-- Giro devagar (so com a barra visivel e "Efeitos do mapa" ligado)
--------------------------------------------------------------------
local t0, acc = 0, 0
RunService.RenderStepped:Connect(function(dt)
	if not bar.Visible then
		return
	end
	local pg = player:FindFirstChildOfClass("PlayerGui")
	if pg and pg:GetAttribute("MapFx") == false then
		-- efeitos do mapa desligados: modelos parados, de frente
		if t0 ~= 0 then
			t0 = 0
			for _, c in ipairs(slots) do
				c.SetAngle(0)
			end
		end
		return
	end
	t0 += dt
	acc += dt
	if acc < 1 / 30 then
		return
	end
	acc = 0
	for i, c in ipairs(slots) do
		if c.Uid then
			c.SetAngle(math.sin(t0 * 0.7 + i * 0.9) * 0.5)
		end
	end
end)
