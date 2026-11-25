--[[
	AwakeningClient (StarterGui/AwakeningGui/AwakeningClient)
	Tela secreta da Maquina/Altar do Despertar escondida na Gruta Norte-Oeste da floresta.
	- Aberta pelo servidor via Remotes.AwakeningOpen ao pressionar E no Altar Secreto.
	- Permite despertar personagens Epicos Nv. 35+ (Luffy, Naruto, Ichigo...) usando Gold + Materiais de Crafting.
	- Anima suavemente o nucleo flutuante da Maquina Secreta quando o jogador se aproxima.
	- Segue rigorosamente o tema Midnight-Blue Anime e zero emojis (100% UI.Icons).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local gui = script.Parent
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Data = ReplicatedStorage:WaitForChild("Data")
local Characters = require(Data:WaitForChild("Characters"))
local Passives = require(Data:WaitForChild("Passives"))
local Awakening = require(Data:WaitForChild("Awakening"))
local UI = require(ReplicatedStorage:WaitForChild("UI"))
local TeamCards = require(ReplicatedStorage:WaitForChild("TeamCards"))
local T = UI.Theme

local profile = nil
local selectedUid: string? = nil
local busy = false
local listCards = {}

local function fmtNum(n: number): string
	local s = tostring(math.floor(n + 0.5))
	while true do
		local nextS, k = s:gsub("^(-?%d+)(%d%d%d)", "%1.%2")
		s = nextS
		if k == 0 then
			break
		end
	end
	return s
end

local canvas = UI.screen(gui)
gui.DisplayOrder = 14

local win = UI.window(canvas, {
	Name = "AwakeningWindow",
	Title = "ALTAR SECRETO DO DESPERTAR",
	Icon = "sparkle",
	HeaderColor = "purple",
	Size = UDim2.fromScale(0.92, 0.88),
	MaxSize = Vector2.new(1080, 580),
})
local body = win.Body

-- Painel esquerdo: personagens elegiveis (Epicos com receita de Despertar)
local leftPanel, leftFace = UI.panel(body, { Name = "Left", Color = "slot", Corner = 0.06, Shadow = false, ZIndex = 2 })
local leftTitle = UI.text(leftFace, "PERSONAGENS DESPERT\u{c1}VEIS", {
	Name = "Title", Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.45, ZIndex = 3,
})
local charScroll = UI.scroll(leftFace, { Name = "CharList", Gap = 0.025, Flat = true })

-- Painel direito: detalhes do Despertar, Passiva Secreta e receita de Crafting
local rightPanel, rightFace = UI.panel(body, { Name = "Right", Color = "slot", Corner = 0.06, Shadow = false, ZIndex = 2 })

local topCard, topFace = UI.panel(rightFace, { Name = "PreviewCard", Color = "panelAlt", Corner = 0.10, Shadow = false, ZIndex = 3 })
local previewPortrait = TeamCards.new(topFace, { Name = "Portrait", CompactPortrait = true, ZIndex = 4 })
previewPortrait.Root.Active = false
previewPortrait.Root.Selectable = false
local previewName = UI.text(topFace, "", { Name = "CharName", Role = "Body", AlignX = Enum.TextXAlignment.Left, Rich = true, ZIndex = 4 })
local previewBonus = UI.text(topFace, "", { Name = "Bonus", Role = "Small", Color = "gold", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.45, ZIndex = 4 })
local curPassLabel = UI.text(topFace, "", { Name = "CurPassive", Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, Rich = true, StrokeMult = 0.35, ZIndex = 4 })
local secPassTitle = UI.text(topFace, "", { Name = "SecTitle", Role = "Small", AlignX = Enum.TextXAlignment.Left, Rich = true, StrokeMult = 0.45, ZIndex = 4 })
local secPassDesc = UI.text(topFace, "", { Name = "SecDesc", Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, AlignY = Enum.TextYAlignment.Top, Wrap = true, StrokeMult = 0.35, ZIndex = 4 })

local reqTitle = UI.text(rightFace, "REQUISITOS E MATERIAIS DE CRAFTING", {
	Name = "ReqTitle", Role = "Small", Color = "inkSoft", AlignX = Enum.TextXAlignment.Left, StrokeMult = 0.45, ZIndex = 3,
})
local reqScroll = UI.scroll(rightFace, { Name = "ReqList", Gap = 0.028, Flat = true })

local statusMsg = UI.text(rightFace, "", { Name = "Message", Role = "Small", Color = "gold", StrokeMult = 0.45, ZIndex = 4 })
local awakenBtn = UI.button(rightFace, {
	Name = "AwakenButton",
	Text = "DESPERTAR PERSONAGEM",
	Icon = "sparkle",
	Layout = "row",
	Color = "purple",
	Role = "Body",
	Corner = 0.24,
	ZIndex = 5,
	Sound = false,
})

local function layout()
	local rawW, rawH = UI.unscaledSize(body)
	local W, H = math.floor(rawW + 0.5), math.floor(rawH + 0.5)
	if W < 20 or H < 20 then
		return
	end
	local gap = math.max(8, math.floor(W * 0.014))
	local leftW = math.floor(W * 0.36)
	local rightW = math.max(180, W - leftW - gap)

	leftPanel.Position = UDim2.fromOffset(0, 0)
	leftPanel.Size = UDim2.fromOffset(leftW, H)
	rightPanel.Position = UDim2.fromOffset(leftW + gap, 0)
	rightPanel.Size = UDim2.fromOffset(rightW, H)

	-- Esquerda
	local pad = 8
	local hdrH = 20
	leftTitle.Position = UDim2.fromOffset(pad, 6)
	leftTitle.Size = UDim2.fromOffset(leftW - pad * 2, hdrH)
	charScroll.Position = UDim2.fromOffset(pad, 6 + hdrH + 4)
	charScroll.Size = UDim2.fromOffset(leftW - pad * 2, math.max(40, H - hdrH - 16))

	-- Direita
	local rw = rightW - pad * 2
	local btnH = math.max(T.TouchMin + 4, math.min(54, math.floor(H * 0.11)))
	local msgH = 18
	local topH = math.clamp(math.floor(H * 0.36), 126, 185)

	topCard.Position = UDim2.fromOffset(pad, 6)
	topCard.Size = UDim2.fromOffset(rw, topH)

	local portS = math.min(topH - 16, math.floor(rw * 0.24))
	previewPortrait.Root.Position = UDim2.fromOffset(8, math.floor((topH - portS) / 2))
	previewPortrait.Root.Size = UDim2.fromOffset(portS, portS)

	local tx = 8 + portS + 10
	local tw = math.max(80, rw - tx - 8)
	local y = 6
	local hName = math.max(20, math.floor(topH * 0.18))
	local hBonus = math.max(16, math.floor(topH * 0.14))
	local hCur = math.max(16, math.floor(topH * 0.14))
	local hSecT = math.max(18, math.floor(topH * 0.16))
	local hSecD = math.max(26, topH - (hName + hBonus + hCur + hSecT + 14))

	previewName.Position = UDim2.fromOffset(tx, y)
	previewName.Size = UDim2.fromOffset(tw, hName)
	y += hName + 1
	previewBonus.Position = UDim2.fromOffset(tx, y)
	previewBonus.Size = UDim2.fromOffset(tw, hBonus)
	y += hBonus + 2
	curPassLabel.Position = UDim2.fromOffset(tx, y)
	curPassLabel.Size = UDim2.fromOffset(tw, hCur)
	y += hCur + 2
	secPassTitle.Position = UDim2.fromOffset(tx, y)
	secPassTitle.Size = UDim2.fromOffset(tw, hSecT)
	y += hSecT + 1
	secPassDesc.Position = UDim2.fromOffset(tx, y)
	secPassDesc.Size = UDim2.fromOffset(tw, hSecD)

	local reqTop = 6 + topH + 8
	reqTitle.Position = UDim2.fromOffset(pad, reqTop)
	reqTitle.Size = UDim2.fromOffset(rw, 18)

	local btnY = H - btnH - 6
	awakenBtn.Position = UDim2.fromOffset(pad, btnY)
	awakenBtn.Size = UDim2.fromOffset(rw, btnH)

	statusMsg.Position = UDim2.fromOffset(pad, btnY - msgH - 3)
	statusMsg.Size = UDim2.fromOffset(rw, msgH)

	local scrollY = reqTop + 22
	reqScroll.Position = UDim2.fromOffset(pad, scrollY)
	reqScroll.Size = UDim2.fromOffset(rw, math.max(40, (btnY - msgH - 6) - scrollY))
end
body:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

local function collectEligible(): { { Uid: string, Member: any, Def: any } }
	local out = {}
	if not profile or not profile.Collection then
		return out
	end
	for uid, m in pairs(profile.Collection) do
		if Awakening.RecipeFor(m.CharacterId) then
			local def = Characters.Get(m.CharacterId)
			if def then
				table.insert(out, { Uid = uid, Member = m, Def = def })
			end
		end
	end
	table.sort(out, function(a, b)
		if (a.Member.Awakened == true) ~= (b.Member.Awakened == true) then
			return a.Member.Awakened ~= true -- nao despertos primeiro
		end
		if (a.Member.Level or 1) ~= (b.Member.Level or 1) then
			return (a.Member.Level or 1) > (b.Member.Level or 1)
		end
		return a.Def.Name < b.Def.Name
	end)
	return out
end

local refresh

local function refreshRight()
	UI.clear(reqScroll)
	local m = profile and selectedUid and profile.Collection and profile.Collection[selectedUid]
	local def = m and Characters.Get(m.CharacterId)
	local recipe = m and Awakening.RecipeFor(m.CharacterId)

	if not m or not def or not recipe then
		previewPortrait.Clear()
		previewName.Text = "Nenhum personagem selecionado"
		previewBonus.Text = "Consiga um \u{c9}pico despert\u{e1}vel (Luffy, Naruto ou Ichigo)."
		curPassLabel.Text = ""
		secPassTitle.Text = ""
		secPassDesc.Text = ""
		awakenBtn.Face.Label.Text = "INDISPON\u{cd}VEL"
		UI.paint(awakenBtn, "grey")
		awakenBtn:SetAttribute("BaseColor", "grey")
		return
	end

	local awakened = m.Awakened == true
	previewPortrait.Set(selectedUid, m)
	previewName.Text = string.format("<b>%s</b>  <font color='#C9C4E8'>Nv. %d</font>%s",
		def.Name, m.Level or 1, if awakened then "  <font color='#F578FF'>[DESPERTO]</font>" else "")
	previewBonus.Text = "Despertar concede: Passiva Secreta \u{da}nica + Aura 3D + +10% Atributos"

	local basePass = Characters.PassiveOf(def.Id, false)
	local secPass = Passives.Get(recipe.SecretPassive)
	curPassLabel.Text = "Passiva Base: <font color='#76C8FF'>" .. (basePass and basePass.Name or "-") .. "</font>"
	secPassTitle.Text = "<font color='#F578FF'><b>PASSIVA SECRETA: " .. (secPass and secPass.Name or recipe.SecretPassive) .. "</b></font>"
	secPassDesc.Text = secPass and secPass.Description or ""

	if awakened then
		UI.text(reqScroll, "Este personagem j\u{e1} despertou sua Passiva Secreta e recebeu +10% em todos os atributos!", {
			Name = "Done", Size = UDim2.fromScale(0.98, 0), Aspect = 8.5, Role = "Small", Color = "gold", Wrap = true,
		})
		awakenBtn.Face.Label.Text = "J\u{c1} DESPERTO"
		UI.paint(awakenBtn, "teal")
		awakenBtn:SetAttribute("BaseColor", "teal")
		return
	end

	local canDo, reason, checks = Awakening.CanAwaken(profile, selectedUid :: string)
	for i, chk in ipairs(checks or {}) do
		local _, rface = UI.panel(reqScroll, {
			Name = "Req_" .. i,
			Color = if chk.Ok then "panelAlt" else "slot",
			Size = UDim2.fromScale(0.98, 0),
			Aspect = 9.5,
			RowMax = 48,
			LayoutOrder = i,
			Corner = 0.22,
			Shadow = false,
			StrokeColor = if chk.Ok then T.Palette.hpHigh else T.Palette.hpLow,
			StrokeMult = 0.65,
		})
		local iconKey = "star"
		local subText = ""
		if chk.Kind == "Gold" then
			iconKey = "coin"
		elseif chk.Kind == "Material" and chk.Id then
			local mat = Awakening.GetMaterial(chk.Id)
			if mat then
				iconKey = mat.Icon or "sparkle"
				subText = mat.Source or ""
			end
		end
		UI.icon(rface, iconKey, {
			Name = "Icon",
			Size = UDim2.fromScale(0.08, 0.68),
			Position = UDim2.fromScale(0.025, 0.16),
		})
		UI.text(rface, chk.Label, {
			Name = "Label",
			Size = UDim2.fromScale(0.56, if #subText > 0 then 0.50 else 0.78),
			Position = UDim2.fromScale(0.12, if #subText > 0 then 0.06 else 0.11),
			Role = "Small",
			AlignX = Enum.TextXAlignment.Left,
		})
		if #subText > 0 then
			UI.text(rface, subText, {
				Name = "Sub",
				Size = UDim2.fromScale(0.58, 0.38),
				Position = UDim2.fromScale(0.12, 0.54),
				Role = "Small",
				Color = "inkSoft",
				AlignX = Enum.TextXAlignment.Left,
				StrokeMult = 0.3,
			})
		end
		local haveStr = if chk.Kind == "Gold" then fmtNum(chk.Have) else tostring(chk.Have)
		local needStr = if chk.Kind == "Gold" then fmtNum(chk.Need) else tostring(chk.Need)
		UI.text(rface, haveStr .. " / " .. needStr, {
			Name = "Count",
			Size = UDim2.fromScale(0.26, 0.72),
			Position = UDim2.fromScale(0.97, 0.14),
			AnchorPoint = Vector2.new(1, 0),
			Role = "Small",
			Color = if chk.Ok then "hpHigh" else "hpLow",
			AlignX = Enum.TextXAlignment.Right,
		})
	end

	if canDo then
		awakenBtn.Face.Label.Text = "DESPERTAR " .. string.upper(def.Name)
		UI.paint(awakenBtn, "purple")
		awakenBtn:SetAttribute("BaseColor", "purple")
	else
		awakenBtn.Face.Label.Text = "REQUISITOS INCOMPLETOS"
		UI.paint(awakenBtn, "grey")
		awakenBtn:SetAttribute("BaseColor", "grey")
		if statusMsg.Text == "" and reason then
			statusMsg.TextColor3 = T.Palette.inkSoft
			statusMsg.Text = reason
		end
	end
end

refresh = function()
	for _, c in ipairs(listCards) do
		c.Clear()
	end
	table.clear(listCards)
	UI.clear(charScroll)

	local list = collectEligible()
	if #list == 0 then
		selectedUid = nil
		UI.text(charScroll, "Nenhum personagem despert\u{e1}vel na cole\u{e7}\u{e3}o.", {
			Name = "Empty", Size = UDim2.fromScale(0.96, 0), Aspect = 6, Role = "Small", Color = "inkSoft", Wrap = true,
		})
		refreshRight()
		return
	end

	local stillValid = false
	for _, entry in ipairs(list) do
		if entry.Uid == selectedUid then
			stillValid = true
			break
		end
	end
	if not stillValid then
		selectedUid = list[1].Uid
	end

	for i, entry in ipairs(list) do
		local m = entry.Member
		local def = entry.Def
		local isSel = entry.Uid == selectedUid
		local awakened = m.Awakened == true
		local canDo = (not awakened) and Awakening.CanAwaken(profile, entry.Uid)

		local _, face = UI.button(charScroll, {
			Name = "Char_" .. entry.Uid,
			Color = if isSel then "blue" else "panelAlt",
			Size = UDim2.fromScale(0.98, 0),
			Aspect = 4.2,
			RowMax = 76,
			LayoutOrder = i,
			Corner = 0.20,
			Shadow = false,
			StrokeColor = if isSel then T.Palette.gold elseif awakened then Color3.fromRGB(245, 110, 255) else nil,
			StrokeMult = if isSel then 1.1 else 0.75,
			OnClick = function()
				selectedUid = entry.Uid
				statusMsg.Text = ""
				refresh()
			end,
		})

		local card = TeamCards.new(face, {
			Name = "Thumb",
			CompactPortrait = true,
			Size = UDim2.fromScale(0.22, 0.84),
			Position = UDim2.fromScale(0.03, 0.08),
			ZIndex = 4,
		})
		card.Root.Active = false
		card.Root.Selectable = false
		card.Set(entry.Uid, m)
		table.insert(listCards, card)

		UI.text(face, def.Name .. "  Nv." .. tostring(m.Level or 1), {
			Name = "Name",
			Size = UDim2.fromScale(0.70, 0.44),
			Position = UDim2.fromScale(0.28, 0.08),
			Role = "Small",
			AlignX = Enum.TextXAlignment.Left,
		})
		local badgeText, badgeCol
		if awakened then
			badgeText, badgeCol = "DESPERTO", "purple"
		elseif canDo then
			badgeText, badgeCol = "PRONTO PARA DESPERTAR!", "gold"
		else
			local reqLv = Awakening.RecipeFor(m.CharacterId).MinLevel or Awakening.MinLevel
			badgeText = if (m.Level or 1) < reqLv then ("Falta Nv. " .. reqLv) else "Faltam materiais/Gold"
			badgeCol = "inkSoft"
		end
		UI.text(face, badgeText, {
			Name = "State",
			Size = UDim2.fromScale(0.70, 0.36),
			Position = UDim2.fromScale(0.28, 0.54),
			Role = "Small",
			Color = badgeCol,
			AlignX = Enum.TextXAlignment.Left,
			StrokeMult = 0.35,
		})
	end

	refreshRight()
end

awakenBtn.Activated:Connect(function()
	if busy or not selectedUid or not profile then
		return
	end
	local canDo, reason = Awakening.CanAwaken(profile, selectedUid)
	if not canDo then
		statusMsg.TextColor3 = T.Palette.hpLow
		statusMsg.Text = reason or "Requisitos incompletos."
		UI.play("error")
		return
	end
	busy = true
	local rf = Remotes:WaitForChild("AwakenCharacter") :: RemoteFunction
	local ok, res = rf:InvokeServer(selectedUid)
	busy = false
	if ok and typeof(res) == "table" then
		statusMsg.TextColor3 = T.Palette.gold
		statusMsg.Text = res.Message or "Personagem Desperto!"
		UI.play("summon_legendary")
		local okP, fresh = pcall(function()
			return Remotes:WaitForChild("GetProfile"):InvokeServer()
		end)
		if okP and typeof(fresh) == "table" then
			profile = fresh
		end
		refresh()
	else
		statusMsg.TextColor3 = T.Palette.hpLow
		statusMsg.Text = tostring(res or "N\u{e3}o foi poss\u{ed}vel despertar.")
		UI.play("error")
	end
end)

win.CloseButton.Activated:Connect(function()
	previewPortrait.Clear()
	for _, c in ipairs(listCards) do
		c.Clear()
	end
	table.clear(listCards)
end)

local function openAltar()
	local ok, p = pcall(function()
		return Remotes:WaitForChild("GetProfile"):InvokeServer()
	end)
	if ok and typeof(p) == "table" then
		profile = p
	end
	statusMsg.Text = ""
	if not win.IsOpen() then
		win.Open()
	end
	layout()
	refresh()
	task.defer(layout)
end

UI.onOpen("Awakening", openAltar)
Remotes:WaitForChild("AwakeningOpen").OnClientEvent:Connect(openAltar)

UI.onBattle(function(on)
	if on and win.IsOpen() then
		previewPortrait.Clear()
		win.Close(true)
	end
end)

Remotes:WaitForChild("ProfileUpdated").OnClientEvent:Connect(function(p)
	if typeof(p) == "table" then
		profile = p
		if win.IsOpen() then
			refresh()
		end
	end
end)

-- Animacao leve do nucleo flutuante dentro da Gruta Secreta quando o jogador esta perto
local coreBaseCF: CFrame? = nil
local coreInnerBaseCF: CFrame? = nil
local coreT = 0
RunService.RenderStepped:Connect(function(dt: number)
	coreT += dt
	local map = workspace:FindFirstChild("Map")
	local altar = map and map:FindFirstChild("SecretAwakeningAltar")
	if not altar then
		return
	end
	local core = altar:FindFirstChild("AwakeningCore")
	local inner = altar:FindFirstChild("AwakeningCoreInner")
	if not (core and core:IsA("BasePart")) then
		return
	end
	if not coreBaseCF then
		coreBaseCF = core.CFrame
		coreInnerBaseCF = if inner and inner:IsA("BasePart") then inner.CFrame else nil
	end
	local cam = workspace.CurrentCamera
	if cam and (cam.CFrame.Position - coreBaseCF.Position).Magnitude > 95 then
		return
	end
	local bob = Vector3.new(0, math.sin(coreT * 2.1) * 0.28, 0)
	core.CFrame = (coreBaseCF + bob) * CFrame.Angles(0, coreT * 0.9, 0)
	if inner and inner:IsA("BasePart") and coreInnerBaseCF then
		inner.CFrame = (coreInnerBaseCF + bob) * CFrame.Angles(0, -coreT * 1.4, coreT * 0.6)
	end
end)
