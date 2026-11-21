--[[
	EquipeClient (GDD secao 10 - tela de Equipe)
	- Em cima: os 6 espacos do time (mesmos cartoes 3D da barra, maiores). Embaixo: a colecao em grade com rolagem,
	  selo "No time" em quem ja esta no time. Filtros por raridade e tipo; ordem por raridade, nivel ou mais recente.
	- Trocar: tocar no espaco e depois no personagem (ou o contrario), ou arrastar da colecao para o espaco
	  (segurar 0,3 s e arrastar). Arrastar entre espacos troca a ordem; o 1o espaco entra primeiro na batalha.
	- Remover: tocar no espaco e no botao vermelho. Minimo de 1 personagem.
	- Tudo vai ao servidor pelo RemoteEvent SetTeam; a tela so mostra o time que o servidor confirmou.
	- Desempenho: a grade so cria os cartoes que aparecem na rolagem (reaproveita os que saem); ao fechar,
	  os modelos da grade sao apagados. Nada gira aqui (o giro fica so na barra).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local gui = script.Parent
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Data = ReplicatedStorage:WaitForChild("Data")
local Characters = require(Data:WaitForChild("Characters"))
local Genetics = require(Data:WaitForChild("Genetics"))
local CharacterFilter = require(ReplicatedStorage:WaitForChild("CharacterFilter"))
local UI = require(ReplicatedStorage:WaitForChild("UI"))
local TeamCards = require(ReplicatedStorage:WaitForChild("TeamCards"))
local T = UI.Theme

local MAX = 6

local profile = nil
local picker = nil -- modo seletor visual para maquinas/base/mochila (UI.pickCharacter)
local pickerUid = nil
local pickerBusy = false

local canvas = UI.screen(gui)
gui.DisplayOrder = 8

local onWindowClose
local win = UI.window(canvas, {
	Name = "EquipeWindow",
	Title = "EQUIPE",
	Icon = "team",
	HeaderColor = "blue",
	Size = UDim2.fromScale(0.92, 0.88),
	MaxSize = Vector2.new(1120, 580),
	OnClose = function(silent)
		if onWindowClose then
			onWindowClose(silent)
		end
	end,
})
local body = win.Body

local function applyHeader(title: string, color: string, iconName: string)
	win.Title.Text = title
	UI.paint(win.Header, color)
	local hi = win.Header:FindFirstChild("Icon")
	if hi and hi:IsA("ImageLabel") then
		UI.setIcon(hi, iconName)
	end
end

-- topo (modo seletor): barra contextual com Voltar, resumo do personagem e botao da funcao
local pickerBar, pickerFace = UI.panel(body, { Name = "PickerBar", Color = "slot", Corner = 0.22, Shadow = false, Visible = false, ZIndex = 4 })
local onPickerBack, onPickerConfirm
local pickerBackBtn = UI.button(pickerFace, {
	Name = "PickerBack", Text = "VOLTAR", Color = "grey", Role = "Small", Corner = 0.28, ZIndex = 5,
	OnClick = function()
		if onPickerBack then
			onPickerBack()
		end
	end,
})
local pickerInfo = UI.text(pickerFace, "", { Name = "PickerInfo", Role = "Small", Rich = true, AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.45, ZIndex = 5 })
local pickerActionBtn = UI.button(pickerFace, {
	Name = "PickerConfirm", Text = "SELECIONAR", Color = "green", Role = "Small", Corner = 0.28, Sound = false, ZIndex = 5,
	OnClick = function()
		if onPickerConfirm then
			onPickerConfirm()
		end
	end,
})

-- topo: 6 espacos
local slotsRow = UI.frame(body, { Name = "Slots" })
local slots = {}
for i = 1, MAX do
	slots[i] = TeamCards.new(slotsRow, { Name = "Slot" .. i, ZIndex = 3 })
end
local removeBtn = UI.button(slotsRow, { Name = "RemoveSlot", Icon = "minus", Color = "red", Layout = "icon", Size = UDim2.fromOffset(44, 44), Corner = 0.5, ZIndex = 9, Visible = false })
local inspectSlotBtn = UI.button(slotsRow, { Name = "InspectSlot", Icon = "star", Color = "teal", Layout = "icon", Size = UDim2.fromOffset(44, 44), Corner = 0.5, ZIndex = 9, Visible = false,
	OnClick = function()
		if not profile or not selectedSlot then
			return
		end
		local uid = profile.Team[selectedSlot]
		if uid then
			UI.open("CharacterDetail", uid)
		end
	end,
})

-- filtros (busca por nome, anime, raridade, tipo e ordenacao por status)
local filterRow = UI.frame(body, { Name = "Filters" })
local filterState = CharacterFilter.CreateState()
local searchBox, animeBtn, rarityBtn, typeBtn, sortBtn, inspectBtn
local inspectMode = false
local message = UI.text(filterRow, "", { Name = "Message", Size = UDim2.fromScale(0.38, 1), Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(1, 0), Role = "Small", Color = "gold", AlignX = Enum.TextXAlignment.Right })

-- grade
local grid = Instance.new("ScrollingFrame")
grid.Name = "Collection"
grid.BackgroundTransparency = 1
grid.BorderSizePixel = 0
grid.ScrollBarThickness = 6
grid.ScrollBarImageColor3 = Color3.fromRGB(200, 190, 255)
grid.ScrollingDirection = Enum.ScrollingDirection.Y
grid.CanvasSize = UDim2.new()
grid.Parent = body

local selectedSlot, pickedUid = nil, nil
local pending, pendingAt = false, 0
local list = {} -- uids filtrados e ordenados
local cell, gap, cols = 60, 6, 6
local active = {} -- [uid] = card visivel na grade
local free = {}

local function setMessage(text, ok)
	message.Text = text or ""
	message.TextColor3 = if ok == false then T.Palette.hpLow else T.Palette.gold
end

--------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------
local updateGrid
local lastLayoutW, lastLayoutH, lastLayoutPicker = 0, 0, nil
local function layout(forceLayout)
	local rawW, rawH = UI.unscaledSize(body)
	local W, H = math.floor(rawW + 0.5), math.floor(rawH + 0.5)
	if W < 10 or H < 10 then
		return
	end
	local isPick = picker ~= nil
	if not forceLayout and W == lastLayoutW and H == lastLayoutH and lastLayoutPicker == isPick then
		return
	end
	lastLayoutW, lastLayoutH, lastLayoutPicker = W, H, isPick
	local twoRows = W < 820
	local g = math.max(4, math.floor(W * 0.01))
	local bh = T.TouchMin
	local fy

	if isPick then
		slotsRow.Visible = false
		pickerBar.Visible = true
		local pbh = math.max(bh, math.min(54, math.floor(H * 0.14)))
		pickerBar.Size = UDim2.fromOffset(W, pbh)
		pickerBar.Position = UDim2.fromOffset(0, 0)
		local by = math.floor((pbh - bh) / 2)
		local backW = math.clamp(math.floor(W * 0.14), 84, 114)
		local actW = math.clamp(math.floor(W * 0.28), 136, 224)
		pickerBackBtn.Position = UDim2.fromOffset(4, by)
		pickerBackBtn.Size = UDim2.fromOffset(backW, bh)
		pickerActionBtn.AnchorPoint = Vector2.new(1, 0)
		pickerActionBtn.Position = UDim2.fromOffset(W - 4, by)
		pickerActionBtn.Size = UDim2.fromOffset(actW, bh)
		local ix = backW + 12
		pickerInfo.Position = UDim2.fromOffset(ix, 2)
		pickerInfo.Size = UDim2.fromOffset(math.max(60, W - ix - actW - 12), pbh - 4)
		fy = pbh + g
	else
		pickerBar.Visible = false
		slotsRow.Visible = true
		local s = math.min(math.floor(H * (if twoRows then 0.29 else 0.28)), math.floor((W - g * (MAX - 1)) / MAX))
		s = math.max(s, if twoRows then 64 else T.TouchMin)
		local rowW = s * MAX + g * (MAX - 1)
		slotsRow.Size = UDim2.fromOffset(W, s + 6)
		slotsRow.Position = UDim2.fromOffset(0, 0)
		for i, c in ipairs(slots) do
			c.Root.Size = UDim2.fromOffset(s, s)
			c.Root.Position = UDim2.fromOffset(math.floor((W - rowW) / 2) + (i - 1) * (s + g), 0)
		end
		fy = s + 6 + g
	end

	local fh = if twoRows then (bh * 2 + 4) else bh
	filterRow.Size = UDim2.fromOffset(W, fh)
	filterRow.Position = UDim2.fromOffset(0, fy)

	if animeBtn and rarityBtn and typeBtn and sortBtn and searchBox and inspectBtn then
		if twoRows then
			local sw = math.floor(W * 0.42)
			local iw = math.max(92, math.floor(W * 0.18))
			searchBox.Root.Size = UDim2.fromOffset(sw, bh)
			searchBox.Root.Position = UDim2.fromOffset(0, 0)
			inspectBtn.Size = UDim2.fromOffset(iw, bh)
			inspectBtn.Position = UDim2.fromOffset(sw + g, 0)
			message.AnchorPoint = Vector2.new(1, 0)
			message.Size = UDim2.fromOffset(math.max(40, W - sw - iw - g * 2), bh)
			message.Position = UDim2.fromOffset(W, 0)

			local bg = g
			local avail = W - bg * 3
			local wA = math.floor(avail * 0.28)
			local wR = math.floor(avail * 0.21)
			local wT = math.floor(avail * 0.21)
			local wS = avail - wA - wR - wT
			local y2 = bh + 4
			animeBtn.Size = UDim2.fromOffset(wA, bh)
			animeBtn.Position = UDim2.fromOffset(0, y2)
			rarityBtn.Size = UDim2.fromOffset(wR, bh)
			rarityBtn.Position = UDim2.fromOffset(wA + bg, y2)
			typeBtn.Size = UDim2.fromOffset(wT, bh)
			typeBtn.Position = UDim2.fromOffset(wA + wR + bg * 2, y2)
			sortBtn.Size = UDim2.fromOffset(wS, bh)
			sortBtn.Position = UDim2.fromOffset(wA + wR + wT + bg * 3, y2)
		else
			local bg = g
			local avail = W - bg * 6
			local wSearch = math.floor(avail * 0.18)
			local wA = math.floor(avail * 0.145)
			local wR = math.floor(avail * 0.115)
			local wT = math.floor(avail * 0.115)
			local wS = math.floor(avail * 0.165)
			local wI = math.max(96, math.floor(avail * 0.115))
			local wMsg = avail - wSearch - wA - wR - wT - wS - wI
			local x = 0
			searchBox.Root.Size = UDim2.fromOffset(wSearch, bh)
			searchBox.Root.Position = UDim2.fromOffset(x, 0)
			x += wSearch + bg
			animeBtn.Size = UDim2.fromOffset(wA, bh)
			animeBtn.Position = UDim2.fromOffset(x, 0)
			x += wA + bg
			rarityBtn.Size = UDim2.fromOffset(wR, bh)
			rarityBtn.Position = UDim2.fromOffset(x, 0)
			x += wR + bg
			typeBtn.Size = UDim2.fromOffset(wT, bh)
			typeBtn.Position = UDim2.fromOffset(x, 0)
			x += wT + bg
			sortBtn.Size = UDim2.fromOffset(wS, bh)
			sortBtn.Position = UDim2.fromOffset(x, 0)
			x += wS + bg
			inspectBtn.Size = UDim2.fromOffset(wI, bh)
			inspectBtn.Position = UDim2.fromOffset(x, 0)
			message.AnchorPoint = Vector2.new(1, 0)
			message.Size = UDim2.fromOffset(math.max(60, wMsg), bh)
			message.Position = UDim2.fromOffset(W, 0)
		end
	end

	local gy = fy + fh + math.max(8, g * 2)
	grid.Position = UDim2.fromOffset(0, gy)
	grid.Size = UDim2.fromOffset(W, math.max(T.TouchMin, H - gy))
	-- colunas: no maximo 7 por linha para manter poucos ViewportFrames simultaneos (evita cartoes 3D em branco)
	local gw = W - grid.ScrollBarThickness - 4
	gap = g
	cols = math.clamp(math.floor((gw + gap) / (92 + gap)), 4, 7)
	cell = math.floor((gw - gap * (cols - 1)) / cols)
	if updateGrid then
		updateGrid(true)
	end
end
body:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	layout(false)
end)

--------------------------------------------------------------------
-- Lista da colecao
--------------------------------------------------------------------
local function buildList()
	if not profile then
		list = {}
		return
	end
	list = filterState.Apply(profile.Collection)
end

local function release(uid)
	local c = active[uid]
	if c then
		active[uid] = nil
		c.Clear()
		c.Root.Visible = false
		table.insert(free, c)
	end
end

local function releaseAll()
	for uid in pairs(active) do
		release(uid)
	end
end

local onCardTap, beginTrack
updateGrid = function(force)
	if not win.IsOpen() then
		return
	end
	local step = cell + gap
	local rows = math.ceil(#list / cols)
	grid.CanvasSize = UDim2.fromOffset(0, math.max(0, rows * step - gap + 8))
	local _, gridH = UI.unscaledSize(grid)
	local y0 = grid.CanvasPosition.Y
	-- virtualiza estritamente as linhas visiveis (evita estourar o orcamento de ViewportFrames do Roblox)
	local first = math.max(0, math.floor(y0 / step))
	local last = math.max(first, math.floor((y0 + math.max(1, gridH) - 1) / step))
	local want = {}
	for r = first, last do
		for c = 0, cols - 1 do
			local idx = r * cols + c + 1
			local uid = list[idx]
			if uid then
				want[uid] = idx
			end
		end
	end
	for uid in pairs(active) do
		if not want[uid] then
			release(uid)
		end
	end
	for uid, idx in pairs(want) do
		local card = active[uid]
		if not card then
			card = table.remove(free)
			if not card then
				card = TeamCards.new(grid, { Name = "Card", ZIndex = 3 })
				card.Root.Activated:Connect(function()
					if card.Uid then
						onCardTap(card.Uid)
					end
				end)
				card.Root.InputBegan:Connect(function(input)
					if card.Uid then
						beginTrack("card", card.Uid, input, card.Root)
					end
				end)
			end
			active[uid] = card
			card.Root.Visible = true
			card.Set(uid, profile.Collection[uid])
		elseif force then
			card.Set(uid, profile.Collection[uid])
		end
		card.Root.Name = "Card_" .. uid
		local i0 = idx - 1
		card.Root.Size = UDim2.fromOffset(cell, cell)
		card.Root.Position = UDim2.fromOffset((i0 % cols) * step, (i0 // cols) * step)
		if picker then
			local m = profile.Collection[uid]
			local def = m and Characters.Get(m.CharacterId)
			if picker.GetBadge and m and def then
				local bText, bColor = picker.GetBadge(uid, m, def, profile)
				card.SetBadge(bText, bColor)
			else
				card.SetInTeam(table.find(profile.Team, uid) ~= nil)
			end
			local eligible = true
			if picker.IsEligible and m and def then
				local okElig = picker.IsEligible(uid, m, def, profile)
				eligible = okElig ~= false
			end
			card.SetDimmed(not eligible)
			card.SetSelected(pickerUid == uid)
		else
			card.SetDimmed(false)
			card.SetInTeam(table.find(profile.Team, uid) ~= nil)
			card.SetSelected(pickedUid == uid)
		end
	end
end
grid:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
	updateGrid(false)
end)

local function refreshPickerBar()
	if not picker or not profile then
		return
	end
	local actionLabel = picker.ActionLabel or "SELECIONAR"
	local actionColor = picker.ActionColor or "green"
	UI.setText(pickerActionBtn, actionLabel)

	if pickerUid and not profile.Collection[pickerUid] then
		pickerUid = nil
	end

	local sub = if picker.SubtitleFn then picker.SubtitleFn(profile) else (picker.Subtitle or "Toque em um personagem abaixo.")
	if not pickerUid then
		pickerInfo.Text = sub
		pickerInfo.TextColor3 = T.Palette.inkSoft
		UI.setDisabled(pickerActionBtn, true, actionColor)
		return
	end

	local m = profile.Collection[pickerUid]
	local def = m and Characters.Get(m.CharacterId)
	if not m or not def then
		pickerInfo.Text = sub
		pickerInfo.TextColor3 = T.Palette.inkSoft
		UI.setDisabled(pickerActionBtn, true, actionColor)
		return
	end

	local eligible, reason = true, nil
	if picker.IsEligible then
		eligible, reason = picker.IsEligible(pickerUid, m, def, profile)
		eligible = eligible ~= false
	end

	local infoStr
	if picker.FormatSelected then
		infoStr = picker.FormatSelected(pickerUid, m, def, profile)
	else
		local genAvg = math.floor(Genetics.Average(m.Genetics) + 0.5)
		local trnAvg = math.floor(Genetics.Average(m.Training) + 0.5)
		infoStr = string.format("<b>%s</b> Nv.%d · GEN %d%% · TRN %d%%", def.Name, m.Level or 1, genAvg, trnAvg)
	end

	if not eligible and reason then
		pickerInfo.Text = infoStr .. string.format("  <font color='#FF6B7A'>(%s)</font>", reason)
		pickerInfo.TextColor3 = T.Palette.onDark
		UI.setDisabled(pickerActionBtn, true, actionColor)
	else
		local extra = if sub and sub ~= "" then ("  <font color='#B8B2E0'>· " .. sub .. "</font>") else ""
		pickerInfo.Text = infoStr .. extra
		pickerInfo.TextColor3 = T.Palette.onDark
		UI.setDisabled(pickerActionBtn, pickerBusy, actionColor)
	end
end

local function refreshSlots()
	if not profile then
		return
	end
	if picker then
		for i = 1, MAX do
			slots[i].Clear()
		end
		removeBtn.Visible = false
		inspectSlotBtn.Visible = false
		refreshPickerBar()
		return
	end
	for i = 1, MAX do
		local uid = profile.Team[i]
		slots[i].Set(uid, uid and profile.Collection[uid] or nil)
		slots[i].SetSelected(selectedSlot == i)
	end
	local sel = selectedSlot and slots[selectedSlot]
	local rowW = UI.unscaledSize(body)
	removeBtn.Visible = sel ~= nil and sel.Uid ~= nil and #profile.Team > 1
	inspectSlotBtn.Visible = sel ~= nil and sel.Uid ~= nil
	if sel and sel.Uid then
		local r = sel.Root
		if removeBtn.Visible then
			removeBtn.Position = UDim2.fromOffset(math.min(math.max(0, rowW - 44), r.Position.X.Offset + r.Size.X.Offset - 30), -4)
		end
		inspectSlotBtn.Position = UDim2.fromOffset(math.max(0, r.Position.X.Offset - 14), -4)
	end
end

local function refreshAll()
	buildList()
	refreshSlots()
	updateGrid(true)
end

--------------------------------------------------------------------
-- Pedidos ao servidor
--------------------------------------------------------------------
local function send(team)
	if pending and os.clock() - pendingAt < 3 then
		setMessage("Aguarde...", false)
		return
	end
	pending, pendingAt = true, os.clock()
	Remotes:WaitForChild("SetTeam"):FireServer(team)
end

local function proposePlace(uid: string, s: number)
	local team = table.clone(profile.Team)
	local k = table.find(team, uid)
	if k then
		s = math.min(s, #team)
		team[k], team[s] = team[s], team[k]
	elseif s <= #team then
		team[s] = uid
	else
		table.insert(team, uid)
	end
	return team
end

local function proposeSwap(a: number, b: number)
	local team = table.clone(profile.Team)
	if not team[a] then
		return nil
	end
	b = math.min(b, #team)
	team[a], team[b] = team[b], team[a]
	return team
end

local function selectSlot(i)
	selectedSlot = i
	refreshSlots()
end

local function finishPicker(returnTo: string?)
	picker = nil
	pickerUid = nil
	pickerBusy = false
	win.Close(true)
	if returnTo then
		task.defer(function()
			UI.open(returnTo)
		end)
	end
end

onPickerBack = function()
	if not picker then
		win.Close()
		return
	end
	local activePicker = picker
	picker = nil
	pickerUid = nil
	pickerBusy = false
	win.Close(true)
	if activePicker.OnCancel then
		activePicker.OnCancel()
	end
	if activePicker.ReturnTo then
		task.defer(function()
			UI.open(activePicker.ReturnTo)
		end)
	end
end

onPickerConfirm = function()
	if not picker or not profile or not pickerUid or pickerBusy then
		return
	end
	local activePicker = picker
	local uid = pickerUid
	local m = profile.Collection[uid]
	local def = m and Characters.Get(m.CharacterId)
	if not m or not def then
		return
	end
	if activePicker.IsEligible then
		local okElig, reason = activePicker.IsEligible(uid, m, def, profile)
		if okElig == false then
			setMessage(reason or "Indispon\u{ed}vel.", false)
			UI.play("error")
			return
		end
	end
	if not activePicker.OnPick then
		finishPicker(activePicker.ReturnTo)
		return
	end
	pickerBusy = true
	refreshPickerBar()
	local ok, feedback, shouldClose = activePicker.OnPick(uid, m, def)
	pickerBusy = false
	if picker ~= activePicker then
		return
	end
	if ok == false then
		setMessage(feedback or "N\u{e3}o foi poss\u{ed}vel.", false)
		UI.play("error")
		refreshPickerBar()
		updateGrid(false)
		return
	end
	if activePicker.Sound ~= false then
		UI.play(activePicker.Sound or "click")
	end
	local closeNow = if shouldClose ~= nil then shouldClose else (not activePicker.KeepOpen)
	if closeNow then
		finishPicker(activePicker.ReturnTo)
	else
		if feedback and feedback ~= "" then
			setMessage(feedback, true)
		end
		refreshPickerBar()
		updateGrid(false)
	end
end

onCardTap = function(uid)
	if not profile then
		return
	end
	if inspectMode then
		UI.play("click")
		UI.open("CharacterDetail", uid)
		return
	end
	if picker then
		UI.play("click")
		if pickerUid == uid then
			local m = profile.Collection[uid]
			local def = m and Characters.Get(m.CharacterId)
			local eligible = true
			if picker.IsEligible and m and def then
				local okElig = picker.IsEligible(uid, m, def, profile)
				eligible = okElig ~= false
			end
			if eligible then
				onPickerConfirm()
				return
			end
		end
		pickerUid = uid
		setMessage("")
		refreshPickerBar()
		updateGrid(false)
		return
	end
	UI.play("click")
	if selectedSlot then
		local s = selectedSlot
		selectedSlot, pickedUid = nil, nil
		send(proposePlace(uid, s))
		refreshSlots()
		updateGrid(false)
	else
		pickedUid = if pickedUid == uid then nil else uid
		setMessage(if pickedUid then "Toque num espa\u{e7}o do time." else "")
		updateGrid(false)
	end
end

local function onSlotTap(i)
	if not profile then
		return
	end
	if inspectMode and profile.Team[i] then
		UI.play("click")
		UI.open("CharacterDetail", profile.Team[i])
		return
	end
	UI.play("click")
	if pickedUid then
		local uid = pickedUid
		pickedUid, selectedSlot = nil, nil
		send(proposePlace(uid, i))
		updateGrid(false)
		refreshSlots()
		return
	end
	if selectedSlot == i then
		selectSlot(nil)
		setMessage("")
	elseif selectedSlot and profile.Team[selectedSlot] and (profile.Team[i] or i > #profile.Team) then
		-- dois toques em espacos: troca a ordem
		local a = selectedSlot
		selectSlot(nil)
		local team = proposeSwap(a, i)
		if team then
			send(team)
		end
	else
		selectSlot(i)
		setMessage("Escolha um personagem da cole\u{e7}\u{e3}o.")
	end
end

removeBtn.Activated:Connect(function()
	if not profile or not selectedSlot then
		return
	end
	local uid = profile.Team[selectedSlot]
	if not uid then
		return
	end
	if #profile.Team <= 1 then
		setMessage("O time precisa de pelo menos 1.", false)
		UI.play("error")
		return
	end
	local team = {}
	for _, u in ipairs(profile.Team) do
		if u ~= uid then
			table.insert(team, u)
		end
	end
	selectSlot(nil)
	send(team)
end)

--------------------------------------------------------------------
-- Arrastar
--------------------------------------------------------------------
local drag = nil
local suppressUntil = 0
local ghost = TeamCards.new(canvas, { Name = "DragGhost", ZIndex = 60 })
ghost.Root.Visible = false
ghost.Root.Active = false

local function toCanvas(pos: Vector2, offset: Vector2): Vector2
	return pos + offset - canvas.AbsolutePosition
end

local function slotAt(pos: Vector2, offset: Vector2): number?
	local p = pos + offset
	for i, c in ipairs(slots) do
		local a, s = c.Root.AbsolutePosition, c.Root.AbsoluteSize
		if p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y then
			return i
		end
	end
	return nil
end

local function startDrag(pos: Vector2)
	if not drag or drag.Started then
		return
	end
	drag.Started = true
	grid.ScrollingEnabled = false
	local uid = if drag.Kind == "card" then drag.Value else profile.Team[drag.Value]
	ghost.Set(uid, profile.Collection[uid])
	local size = slots[1].Root.AbsoluteSize.X
	ghost.Root.Size = UDim2.fromOffset(size, size)
	ghost.Root.AnchorPoint = Vector2.new(0.5, 0.5)
	local p = toCanvas(pos, drag.Offset)
	ghost.Root.Position = UDim2.fromOffset(p.X, p.Y)
	ghost.Root.Visible = true
	ghost.SetSelected(true)
end

beginTrack = function(kind: string, value, input: InputObject, rootObj: GuiObject)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	if not profile or pending or picker then
		return
	end
	local pos = Vector2.new(input.Position.X, input.Position.Y)
	-- calibra o espaco de coordenadas do toque com o da interface (barra do Roblox)
	local a, s = rootObj.AbsolutePosition, rootObj.AbsoluteSize
	local offset = Vector2.zero
	local inset = GuiService:GetGuiInset()
	local function inside(p)
		return p.X >= a.X - 2 and p.X <= a.X + s.X + 2 and p.Y >= a.Y - 2 and p.Y <= a.Y + s.Y + 2
	end
	if not inside(pos) and inside(pos - inset) then
		offset = -inset
	end
	drag = { Kind = kind, Value = value, Start = pos, Offset = offset, Started = false, Moved = false }
	local d = drag
	if kind == "card" then
		task.delay(0.3, function()
			if drag == d and not d.Started and not d.Moved then
				startDrag(d.Start)
			end
		end)
	end
end

for i, c in ipairs(slots) do
	c.Root.Activated:Connect(function()
		if os.clock() < suppressUntil then
			return
		end
		onSlotTap(i)
	end)
	c.Root.InputBegan:Connect(function(input)
		if c.Uid then
			beginTrack("slot", i, input, c.Root)
		end
	end)
end

UserInputService.InputChanged:Connect(function(input)
	if not drag then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local pos = Vector2.new(input.Position.X, input.Position.Y)
	if drag.Started then
		local p = toCanvas(pos, drag.Offset)
		ghost.Root.Position = UDim2.fromOffset(p.X, p.Y)
		local over = slotAt(pos, drag.Offset)
		for i, c in ipairs(slots) do
			c.SetSelected(i == over)
		end
	elseif (pos - drag.Start).Magnitude > 10 then
		if drag.Kind == "slot" then
			startDrag(pos)
		else
			drag.Moved = true -- e rolagem, nao arraste
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if not drag then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local d = drag
	drag = nil
	grid.ScrollingEnabled = true
	if not d.Started then
		return
	end
	suppressUntil = os.clock() + 0.15
	ghost.Root.Visible = false
	ghost.Clear()
	local pos = Vector2.new(input.Position.X, input.Position.Y)
	local target = slotAt(pos, d.Offset)
	selectedSlot, pickedUid = nil, nil
	refreshSlots()
	if not target or not profile then
		updateGrid(false)
		return
	end
	local team
	if d.Kind == "slot" then
		if target ~= d.Value then
			team = proposeSwap(d.Value, target)
		end
	else
		team = proposePlace(d.Value, target)
	end
	if team then
		send(team)
	end
	updateGrid(false)
end)

--------------------------------------------------------------------
-- Filtros
--------------------------------------------------------------------
local function filterText()
	UI.setText(animeBtn, CharacterFilter.LabelFor("Anime", filterState.Anime()))
	UI.setText(rarityBtn, CharacterFilter.LabelFor("Rarity", filterState.Rarity()))
	UI.setText(typeBtn, CharacterFilter.LabelFor("Type", filterState.Type()))
	UI.setText(sortBtn, CharacterFilter.LabelFor("Sort", filterState.Sort()))
end

local function applyFilterChange()
	filterText()
	grid.CanvasPosition = Vector2.zero
	releaseAll()
	refreshAll()
end

searchBox = UI.searchBox(filterRow, {
	Name = "SearchBox",
	Placeholder = "Buscar nome...",
	Role = "Small",
	OnChanged = function(text)
		filterState.SetSearch(text)
		grid.CanvasPosition = Vector2.zero
		releaseAll()
		refreshAll()
	end,
})

animeBtn = UI.button(filterRow, { Name = "AnimeFilter", Text = "ANIME: TODOS", Icon = "book", Layout = "row", Color = "blue", Size = UDim2.fromOffset(120, T.TouchMin), Role = "Small",
	OnClick = function()
		filterState.NextAnime()
		applyFilterChange()
	end,
})
rarityBtn = UI.button(filterRow, { Name = "RarityFilter", Text = "TODAS", Icon = "star", Layout = "row", Color = "purple", Size = UDim2.fromOffset(100, T.TouchMin), Role = "Small",
	OnClick = function()
		filterState.NextRarity()
		applyFilterChange()
	end,
})
typeBtn = UI.button(filterRow, { Name = "TypeFilter", Text = "TODOS", Icon = "tipo_fogo", Layout = "row", Color = "teal", Size = UDim2.fromOffset(100, T.TouchMin), Role = "Small",
	OnClick = function()
		local nextType = filterState.NextType()
		local ti = UI.TypeIcon[nextType]
		local icon = typeBtn.Face:FindFirstChild("Icon")
		if icon then
			UI.setIcon(icon, ti or "tipo_fogo")
			icon.ImageTransparency = if ti then 0 else 0.5
		end
		applyFilterChange()
	end,
})
sortBtn = UI.button(filterRow, { Name = "Sort", Text = "RARIDADE", Icon = "arrow", Layout = "row", Color = "orange", Size = UDim2.fromOffset(120, T.TouchMin), Role = "Small",
	OnClick = function()
		filterState.NextSort()
		applyFilterChange()
	end,
})
local function updateInspectBtn()
	local c = if inspectMode then "teal" else "panelAlt"
	UI.paint(inspectBtn, c)
	inspectBtn:SetAttribute("BaseColor", c)
	UI.setText(inspectBtn, if inspectMode then "INFO: ON" else "VER INFO")
end
inspectBtn = UI.button(filterRow, { Name = "InspectMode", Text = "VER INFO", Icon = "star", Layout = "row", Color = "panelAlt", Size = UDim2.fromOffset(96, T.TouchMin), Role = "Small",
	OnClick = function()
		inspectMode = not inspectMode
		pickedUid = nil
		selectSlot(nil)
		updateInspectBtn()
		setMessage(if inspectMode then "Toque para ver atributos." else "")
		updateGrid(false)
	end,
})
do
	local icon = typeBtn.Face:FindFirstChild("Icon")
	if icon then
		icon.ImageTransparency = 0.5
	end
end

--------------------------------------------------------------------
-- Abrir, fechar e dados
--------------------------------------------------------------------
onWindowClose = function(silent)
	selectedSlot, pickedUid = nil, nil
	if picker then
		local activePicker = picker
		picker = nil
		pickerUid = nil
		pickerBusy = false
		if not silent then
			if activePicker.OnCancel then
				activePicker.OnCancel()
			end
			if activePicker.ReturnTo then
				task.defer(function()
					UI.open(activePicker.ReturnTo)
				end)
			end
		end
	end
end

UI.onOpen("Equipe", function(slot)
	if not profile or not profile.StarterChosen then
		return
	end
	if UI.inBattle() then
		return
	end
	if win.IsOpen() and slot == nil and not picker then
		win.Close()
		return
	end
	picker = nil
	pickerUid = nil
	pickerBusy = false
	applyHeader("EQUIPE", "blue", "team")
	pickedUid = nil
	inspectMode = false
	updateInspectBtn()
	selectedSlot = if typeof(slot) == "number" and slot >= 1 and slot <= MAX then slot else nil
	setMessage(if selectedSlot then "Escolha um personagem da cole\u{e7}\u{e3}o." else "")
	if not win.IsOpen() then
		win.Open()
	end
	task.defer(function()
		layout(true)
		refreshAll()
	end)
end)

UI.onPickCharacter(function(opts)
	if not profile or not profile.StarterChosen or typeof(opts) ~= "table" then
		return
	end
	if UI.inBattle() then
		return
	end
	picker = opts
	pickerUid = if typeof(opts.SelectedUid) == "string" and profile.Collection[opts.SelectedUid] then opts.SelectedUid else nil
	pickerBusy = false
	selectedSlot, pickedUid = nil, nil
	inspectMode = false
	updateInspectBtn()
	if searchBox and searchBox.Get() ~= "" then
		searchBox.Clear()
	end
	applyHeader(opts.Title or "ESCOLHER PERSONAGEM", opts.HeaderColor or "teal", opts.Icon or "team")
	setMessage("")
	grid.CanvasPosition = Vector2.zero
	if not win.IsOpen() then
		win.Open()
	end
	task.defer(function()
		layout(true)
		refreshAll()
	end)
end)

-- ao fechar, a grade solta os modelos (so os 6 espacos ficam)
win.CloseButton.Activated:Connect(function()
	selectedSlot, pickedUid = nil, nil
end)
task.spawn(function()
	while true do
		task.wait(0.5)
		if not win.IsOpen() and next(active) then
			releaseAll()
		end
	end
end)

UI.onBattle(function(on)
	if on and win.IsOpen() then
		picker = nil
		pickerUid = nil
		pickerBusy = false
		win.Close(true)
	end
end)

Remotes:WaitForChild("ProfileUpdated").OnClientEvent:Connect(function(p)
	if typeof(p) == "table" then
		profile = p
		if win.IsOpen() then
			refreshAll()
		end
	end
end)
task.spawn(function()
	local ok, p = pcall(function()
		return Remotes:WaitForChild("GetProfile"):InvokeServer()
	end)
	if ok and typeof(p) == "table" then
		profile = p
	end
end)
task.spawn(function()
	Remotes:WaitForChild("TeamResult").OnClientEvent:Connect(function(r)
		pending = false
		if typeof(r) ~= "table" then
			return
		end
		if profile and typeof(r.Team) == "table" then
			profile.Team = r.Team -- o time oficial do servidor
		end
		if win.IsOpen() then
			setMessage(r.Message or (if r.Ok then "Time salvo." else ""), r.Ok)
			if r.Ok then
				UI.play("click")
			end
			refreshAll()
		end
	end)
end)

-- Os 6 espacos de cima ficam parados (de frente): com a grade aberta o Roblox limita a atualizacao das
-- previas 3D, e as que giravam ficavam em branco. O giro fica so na barra (no maximo 6 previas).
