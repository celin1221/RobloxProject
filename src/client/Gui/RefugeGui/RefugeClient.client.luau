--[[
	RefugeClient (GDD secao 14 - Refugio)
	- Tela da Forja: nivel, chances atuais e do proximo nivel lado a lado (sempre visiveis), custo,
	  requisitos com progresso e marca de feito; MELHORAR so ativo com tudo cumprido.
	- Tela do Bau: itens guardados e "Coletar tudo".
	- Brilho do Bau quando tem itens e efeito/som da melhoria da Forja (so visual).
	O servidor (RefugeService) valida e calcula tudo.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local gui = script.Parent
local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Data = ReplicatedStorage:WaitForChild("Data")
local Refuge = require(Data:WaitForChild("Refuge"))
local Summon = require(Data:WaitForChild("Summon"))
local UI = require(ReplicatedStorage:WaitForChild("UI"))
local ClientSettings = require(ReplicatedStorage:WaitForChild("ClientSettings"))
local T = UI.Theme

local canvas = UI.screen(gui)
gui.DisplayOrder = 9

local RARITY_COLOR = { Comum = "comum", Raro = "raro", Epico = "epico", Lendario = "lendario", Secreto = "secreto" }
local ITEM_ICON = { Pocao = "potion", Superpocao = "potion", CuraStatus = "heal", SeloContrato = "seal_basic", SeloSuperior = "seal_superior", Eter = "potion", Ore = "ore", DoceComum = "doce_comum", DoceRaro = "doce_raro", DoceEpico = "doce_epico" }

local function pct(x: number): string
	local s = string.format("%.1f", x):gsub("%.0$", "")
	return s .. "%"
end

local function mmss(sec: number): string
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

--------------------------------------------------------------------
-- Janela da Forja
--------------------------------------------------------------------
local forge = UI.window(canvas, { Name = "ForjaWindow", Title = "FORJA", Icon = "pickaxe", HeaderColor = "orange", Size = UDim2.fromScale(0.92, 0.86), Aspect = 1.95 })
local fbody = forge.Body

local top, topFace = UI.panel(fbody, { Name = "Top", Size = UDim2.fromScale(1, 0.15), Color = "slot", Corner = 0.2, Shadow = false })
UI.clampHeight(top, 44, 70)
local levelLabel = UI.text(topFace, "", { Name = "Level", Size = UDim2.fromScale(0.24, 0.7), Position = UDim2.fromScale(0.02, 0.15), Role = "Heading", Color = "gold", AlignX = Enum.TextXAlignment.Left })
local fieldLabel = UI.text(topFace, "", { Name = "Field", Size = UDim2.fromScale(0.47, 0.68), Position = UDim2.fromScale(0.27, 0.16), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.4 })
local _, gemsLabel = UI.pill(topFace, "gem", "gems", { Name = "Gems", Size = UDim2.fromScale(0.2, 0.7), Position = UDim2.fromScale(0.98, 0.15), AnchorPoint = Vector2.new(1, 0), Aspect = 3.2, Role = "Body" })

-- chances: agora e proximo nivel
local cols = UI.frame(fbody, { Name = "Chances", Size = UDim2.fromScale(1, 0.35), Position = UDim2.fromScale(0, 0.165) })
local function chanceColumn(name: string, x: number)
	local holder, face = UI.panel(cols, { Name = name, Size = UDim2.fromScale(0.49, 1), Position = UDim2.fromScale(x, 0), Color = "panelAlt", Corner = 0.08, Shadow = false })
	local title = UI.text(face, "", { Name = "Title", Size = UDim2.fromScale(0.94, 0.18), Position = UDim2.fromScale(0.03, 0.02), Role = "Body", AlignX = Enum.TextXAlignment.Left })
	local rows = {}
	for i, r in ipairs(Refuge.RarityOrder) do
		-- grade 2 x 2 (Comum | Raro / Epico | Lendario): cabe no celular pequeno
		local gx, gy = (i - 1) % 2, (i - 1) // 2
		local row, rf = UI.panel(face, { Name = "Rate_" .. r, Size = UDim2.fromScale(0.455, 0.26), Position = UDim2.fromScale(0.03 + gx * 0.485, 0.22 + gy * 0.3), Color = RARITY_COLOR[r], Corner = T.Corner.Pill, Shadow = false })
		UI.text(rf, UI.upper(Summon.RarityName[r] or r), { Name = "Name", Size = UDim2.fromScale(0.52, 0.72), Position = UDim2.fromScale(0.05, 0.14), Role = "Small", AlignX = Enum.TextXAlignment.Left })
		local v = UI.text(rf, "", { Name = "Value", Size = UDim2.fromScale(0.36, 0.72), Position = UDim2.fromScale(0.95, 0.14), AnchorPoint = Vector2.new(1, 0), Role = "Small", AlignX = Enum.TextXAlignment.Right })
		if r == "Lendario" then
			UI.shine(row)
		end
		rows[r] = v
	end
	local extra = UI.text(face, "", { Name = "Extra", Size = UDim2.fromScale(0.94, 0.16), Position = UDim2.fromScale(0.03, 0.82), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.4 })
	return { Holder = holder, Title = title, Rows = rows, Extra = extra }
end
local nowCol = chanceColumn("Now", 0)
local nextCol = chanceColumn("Next", 0.51)

local bar = UI.frame(fbody, { Name = "Actions", Size = UDim2.fromScale(1, 0.12), Position = UDim2.fromScale(0, 1), AnchorPoint = Vector2.new(0, 1) })
UI.clampHeight(bar, T.TouchMin, 50)
local costHolder, costLabel = UI.pill(bar, "gem", "gems", { Name = "Cost", Size = UDim2.fromScale(0.22, 1), Aspect = 3.2, Role = "Body" })
local fmsg = UI.text(bar, "", { Name = "Message", Size = UDim2.fromScale(0.44, 1), Position = UDim2.fromScale(0.25, 0), Role = "Small", Color = "gold", AlignX = Enum.TextXAlignment.Left })
local upgradeButton = UI.button(bar, { Name = "Upgrade", Text = "MELHORAR", Icon = "plus", Layout = "row", Color = "green", Size = UDim2.fromScale(0.28, 1), Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(1, 0), Role = "Body", Sound = false })

local reqs = UI.scroll(fbody, { Name = "Reqs", Size = UDim2.fromScale(1, 0.24), Position = UDim2.fromScale(0, 0.59) })

local function layoutForge()
	local H = fbody.AbsoluteSize.Y
	if H < 40 then
		return
	end
	local topH = math.max(44, math.floor(top.AbsoluteSize.Y))
	local barH = math.max(T.TouchMin, math.floor(bar.AbsoluteSize.Y))
	local gap = 6
	local colsY = topH + gap
	local avail = math.max(80, H - colsY - barH - gap * 2)
	local colsH = math.clamp(math.floor(avail * 0.54), 76, math.floor(H * 0.40))
	cols.Position = UDim2.fromOffset(0, colsY)
	cols.Size = UDim2.new(1, 0, 0, colsH)
	local reqY = colsY + colsH + gap
	local reqH = math.max(36, H - reqY - barH - gap)
	reqs.Position = UDim2.fromOffset(0, reqY)
	reqs.Size = UDim2.new(1, 0, 0, reqH)
end
fbody:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutForge)
top:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutForge)
bar:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutForge)
task.defer(layoutForge)

local state = nil
local stateAt = 0

local function show(msgLabel, ok: boolean, text: string?, sound: string?)
	msgLabel.TextColor3 = if ok then T.Palette.gold else T.Palette.hpLow
	msgLabel.Text = text or ""
	if not ok then
		UI.play("error")
	elseif sound then
		UI.play(sound)
	end
end

local function fillColumn(col, level: number?, info)
	if not info then
		col.Title.Text = "N\u{cd}VEL M\u{c1}XIMO"
		for _, v in pairs(col.Rows) do
			v.Text = "MAX"
		end
		col.Extra.Text = ""
		return
	end
	for r, v in pairs(col.Rows) do
		v.Text = pct(info.Chances[r] or 0)
	end
	col.Extra.Text = string.format("Selvagens nv. %d a %d \u{b7} at\u{e9} %d \u{b7} a cada %s", info.MinLevel, info.MaxLevel, info.Max, mmss(info.Interval))
end

local function refreshForgeNow()
	if not state then
		return
	end
	levelLabel.Text = string.format("N\u{cd}VEL %d/%d", state.Level, state.MaxLevel)
	local left = state.NextSpawnIn and math.max(0, state.NextSpawnIn - (os.clock() - stateAt))
	fieldLabel.Text = string.format("Selvagens no campo: %d/%d \u{b7} %s", state.Pending, state.Info.Max, if left then "pr\u{f3}ximo em " .. mmss(left) else "campo cheio")
	gemsLabel.Text = UI.fmt(state.Gems or 0)
	nowCol.Title.Text = "AGORA (N\u{cd}VEL " .. state.Level .. ")"
	fillColumn(nowCol, state.Level, state.Info)
	if state.Next then
		nextCol.Title.Text = "PR\u{d3}XIMO (N\u{cd}VEL " .. (state.Level + 1) .. ")"
	end
	fillColumn(nextCol, state.Level + 1, state.Next)
	costHolder.Visible = state.Cost ~= nil
	costLabel.Text = if state.Cost then UI.fmt(state.Cost) else ""
	UI.setDisabled(upgradeButton, not state.CanUpgrade, "green")
	UI.clear(reqs)
	if #state.Reqs == 0 then
		UI.text(reqs, "A Forja est\u{e1} no n\u{ed}vel m\u{e1}ximo.", { Name = "Done", Size = UDim2.fromScale(1, 0), Aspect = 12, Role = "Small", Color = "gold", LayoutOrder = 1 })
	end
	for i, rq in ipairs(state.Reqs) do
		local row, face = UI.panel(reqs, { Name = "Req" .. i, Size = UDim2.fromScale(0.98, 0), Aspect = 11, RowMax = 52, Color = if rq.Done then "green" else "panelAlt", Corner = 0.3, Shadow = false, LayoutOrder = i })
		UI.text(face, rq.Text, { Name = "Text", Size = UDim2.fromScale(0.60, 0.7), Position = UDim2.fromScale(0.03, 0.15), Role = "Small", AlignX = Enum.TextXAlignment.Left })
		UI.text(face, string.format("%s/%s", UI.fmt(rq.Have), UI.fmt(rq.Need)), { Name = "Progress", Size = UDim2.fromScale(0.21, 0.7), Position = UDim2.fromScale(0.87, 0.15), AnchorPoint = Vector2.new(1, 0), Role = "Small", AlignX = Enum.TextXAlignment.Right })
		if rq.Done then
			UI.icon(row, "tick", { Name = "Tick", Size = UDim2.fromScale(0.1, 0.9), Position = UDim2.fromScale(0.985, 0.5), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 3 })
		else
			UI.icon(row, "lock", { Name = "Lock", Size = UDim2.fromScale(0.1, 0.8), Position = UDim2.fromScale(0.985, 0.5), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 3 })
		end
	end
end

local function fetch()
	local ok, s = pcall(function()
		return Remotes:WaitForChild("RefugeState"):InvokeServer()
	end)
	if ok and s then
		state = s
		stateAt = os.clock()
	end
	return state
end

upgradeButton.Activated:Connect(function()
	if upgradeButton:GetAttribute("Disabled") then
		show(fmsg, false, if state and not state.ReqsDone then "Cumpra todos os requisitos." else "Gemas insuficientes.")
		return
	end
	local ok, text = Remotes.RefugeUpgrade:InvokeServer()
	show(fmsg, ok, text, "reward")
	fetch()
	UI.keepScroll(reqs, refreshForgeNow)
end)

--------------------------------------------------------------------
-- Janela do Bau
--------------------------------------------------------------------
local chest = UI.window(canvas, { Name = "BauWindow", Title = "BA\u{da}", Icon = "chest", HeaderColor = "purple", Size = UDim2.fromScale(0.8, 0.8), Aspect = 1.7 })
local cbody = chest.Body
local ctop, ctopFace = UI.panel(cbody, { Name = "Top", Size = UDim2.fromScale(1, 0.14), Color = "slot", Corner = 0.2, Shadow = false })
UI.clampHeight(ctop, 40, 64)
local capLabel = UI.text(ctopFace, "", { Name = "Capacity", Size = UDim2.fromScale(0.34, 0.7), Position = UDim2.fromScale(0.03, 0.15), Role = "Body", AlignX = Enum.TextXAlignment.Left })
local hint = UI.text(ctopFace, "30% de chance por selvagem derrotado ou capturado", { Name = "Hint", Size = UDim2.fromScale(0.58, 0.66), Position = UDim2.fromScale(0.97, 0.17), AnchorPoint = Vector2.new(1, 0), Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Right, StrokeMult = 0.4 })
local cbar = UI.frame(cbody, { Name = "Actions", Size = UDim2.fromScale(1, 0.13), Position = UDim2.fromScale(0, 1), AnchorPoint = Vector2.new(0, 1) })
UI.clampHeight(cbar, T.TouchMin, 50)
local cmsg = UI.text(cbar, "", { Name = "Message", Size = UDim2.fromScale(0.6, 1), Role = "Small", Color = "gold", AlignX = Enum.TextXAlignment.Left })
local collectButton = UI.button(cbar, { Name = "Collect", Text = "COLETAR TUDO", Icon = "chest", Layout = "row", Color = "green", Size = UDim2.fromScale(0.36, 1), Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(1, 0), Role = "Body", Sound = false })
local grid = UI.scroll(cbody, { Name = "Items", Size = UDim2.fromScale(1, 0.6), Position = UDim2.fromScale(0, 0.17), Columns = 4, CellAspect = 1.25 })
UI.fillBetween(grid, ctop, cbar, 6)

local function refreshChestNow()
	if not state then
		return
	end
	capLabel.Text = string.format("Itens: %d/%d", state.BauCount, state.BauCap)
	UI.setDisabled(collectButton, state.BauCount == 0, "green")
	UI.clear(grid)
	if state.BauCount == 0 then
		UI.text(grid, "Vazio. Derrote ou capture selvagens para ganhar itens.", { Name = "Empty", Size = UDim2.fromScale(1, 0), Aspect = 10, Role = "Small", Color = "inkSoft", LayoutOrder = 1 })
		return
	end
	for i, e in ipairs(state.Bau) do
		local cell, face = UI.panel(grid, { Name = "Item" .. i, Color = if e.Id == "SeloSuperior" or e.Id == "DoceEpico" then "purple" elseif e.Id == "DoceRaro" then "blue" elseif e.Id == "Ore" then "ore" else "panelAlt", Corner = T.Corner.Card, LayoutOrder = i })
		UI.icon(face, ITEM_ICON[e.Id] or "bag", { Name = "Icon", Size = UDim2.fromScale(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.06), AnchorPoint = Vector2.new(0.5, 0) })
		UI.text(face, e.Name, { Name = "Name", Size = UDim2.fromScale(0.92, 0.2), Position = UDim2.fromScale(0.04, 0.58), Role = "Small" })
		UI.text(face, "x" .. UI.fmt(e.Qty), { Name = "Qty", Size = UDim2.fromScale(0.92, 0.18), Position = UDim2.fromScale(0.04, 0.79), Role = "Small", Color = "gold" })
	end
end

collectButton.Activated:Connect(function()
	if collectButton:GetAttribute("Disabled") then
		return
	end
	local ok, text = Remotes.RefugeCollect:InvokeServer()
	show(cmsg, ok, text, "coin")
	fetch()
	refreshChestNow()
end)

--------------------------------------------------------------------
-- Abrir pelos prompts do Refugio
--------------------------------------------------------------------
local function openForge()
	if UI.inBattle() then
		return
	end
	chest.Close(true)
	fmsg.Text = ""
	fetch()
	refreshForgeNow()
	forge.Open()
	task.defer(layoutForge)
end

local function openChest()
	if UI.inBattle() then
		return
	end
	forge.Close(true)
	cmsg.Text = ""
	fetch()
	refreshChestNow()
	chest.Open()
end

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "ForjaPrompt" then
		openForge()
	elseif prompt.Name == "BauPrompt" then
		openChest()
	end
end)
UI.onOpen("Forja", openForge)
UI.onOpen("Bau", openChest)
UI.onBattle(function(inBattle)
	if inBattle then
		forge.Close(true)
		chest.Close(true)
	end
end)

-- contagem do proximo selvagem com a tela aberta
task.spawn(function()
	while true do
		task.wait(1)
		if forge.IsOpen() and state then
			local left = state.NextSpawnIn and state.NextSpawnIn - (os.clock() - stateAt)
			if left and left <= 0 then
				fetch()
				UI.keepScroll(reqs, refreshForgeNow)
			else
				local l = math.max(0, left or 0)
				fieldLabel.Text = string.format("Selvagens no campo: %d/%d \u{b7} %s", state.Pending, state.Info.Max, if state.NextSpawnIn then "pr\u{f3}ximo em " .. mmss(l) else "campo cheio")
			end
		end
	end
end)

--------------------------------------------------------------------
-- Brilho do Bau (so do meu Refugio) e efeito da melhoria
--------------------------------------------------------------------
local function myRefuge(): Model?
	local folder = workspace:FindFirstChild("Refugios")
	if not folder then
		return nil
	end
	for _, m in ipairs(folder:GetChildren()) do
		if m:GetAttribute("OwnerUserId") == player.UserId then
			return m
		end
	end
	return nil
end

RunService.Heartbeat:Connect(function()
	local m = myRefuge()
	local bau = m and m:FindFirstChild("Bau")
	local point = m and m:FindFirstChild("BauPoint")
	if bau and point then
		local fxAttr = player.PlayerGui:GetAttribute("MapFx")
		local on = (bau:GetAttribute("Count") or 0) > 0 and (if fxAttr ~= nil then fxAttr else ClientSettings.Current.MapFx ~= false)
		local l = point:FindFirstChild("Brilho")
		local fx = point:FindFirstChild("Fx")
		local e = fx and fx:FindFirstChild("BrilhoBau")
		if l and l.Enabled ~= on then
			l.Enabled = on
		end
		if e and e.Enabled ~= on then
			e.Enabled = on
		end
	end
end)

Remotes:WaitForChild("RefugeFx").OnClientEvent:Connect(function(kind, level)
	if kind ~= "Upgrade" then
		return
	end
	UI.play("reward")
	UI.toast("Forja n\u{ed}vel " .. tostring(level) .. "!")
	local m = myRefuge()
	local f = m and m:WaitForChild("Forja", 3)
	if not f then
		return
	end
	local cf, size = f:GetBoundingBox()
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = cf
	p.Parent = workspace
	local a = Instance.new("Attachment")
	a.Parent = p
	local function burst(tex, color, n, speed, size)
		local e = Instance.new("ParticleEmitter")
		e.Texture = tex
		e.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
		e.LightEmission = 1
		e.Rate = 0
		e.Lifetime = NumberRange.new(0.8, 1.6)
		e.Speed = NumberRange.new(speed * 0.5, speed)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Drag = 3
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new(0, 1)
		e.Parent = a
		e:Emit(n)
	end
	burst("rbxassetid://117703775594396", Color3.fromRGB(255, 210, 90), 60, 22, 1.4)
	burst("rbxassetid://93633042519778", Color3.fromRGB(255, 120, 50), 50, 14, 0.8)
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 180, 80)
	l.Range = 30
	l.Brightness = 6
	l.Shadows = false
	l.Parent = p
	task.spawn(function()
		for i = 1, 20 do
			l.Brightness = 6 * (1 - i / 20)
			task.wait(0.05)
		end
	end)
	task.delay(2.5, function()
		p:Destroy()
	end)
	if forge.IsOpen() then
		fetch()
		UI.keepScroll(reqs, refreshForgeNow)
	end
end)
