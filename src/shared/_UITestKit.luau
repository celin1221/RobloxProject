-- Ferramentas de teste da interface (so Studio; apagar antes de publicar)
local GuiService = game:GetService("GuiService")
local K = {}
local pg = game.Players.LocalPlayer:WaitForChild("PlayerGui")
local hook = pg:WaitForChild("_UITest", 10)
function K.ui(...) return hook:Invoke(...) end
local function visibleChain(o)
	while o and not o:IsA("ScreenGui") do
		if o:IsA("GuiObject") and not o.Visible then return false end
		o = o.Parent
	end
	return o and o.Enabled
end
function K.audit()
	local issues = {}
	for _, g in ipairs(pg:GetChildren()) do
		local c = g:IsA("ScreenGui") and g:FindFirstChild("Canvas")
		if c then
			local cp, cs = c.AbsolutePosition, c.AbsoluteSize
			for _, o in ipairs(c:GetDescendants()) do
				if o:IsA("GuiObject") and visibleChain(o) then
					local sf = o:FindFirstAncestorWhichIsA("ScrollingFrame")
					local p, s = o.AbsolutePosition, o.AbsoluteSize
					local nm = o:GetFullName():gsub("^.-PlayerGui%.", "")
					if s.X > 2 and s.Y > 2 then
						if not sf and o.Name ~= "Shadow" and (p.X < cp.X - 2 or p.Y < cp.Y - 2 or p.X + s.X > cp.X + cs.X + 2 or p.Y + s.Y > cp.Y + cs.Y + 2) then
							table.insert(issues, "OUT " .. nm .. " " .. tostring(p) .. " " .. tostring(s))
						end
						local clipped = sf and (p.Y + s.Y < sf.AbsolutePosition.Y or p.Y > sf.AbsolutePosition.Y + sf.AbsoluteSize.Y)
						if not clipped and o:IsA("GuiButton") and o.Active and o.Name ~= "Scrim" and (s.X < 43.5 or s.Y < 43.5) then
							table.insert(issues, "SMALL " .. nm .. " " .. math.floor(s.X) .. "x" .. math.floor(s.Y))
						end
						if not clipped and (o:IsA("TextLabel") or o:IsA("TextBox")) and o.Text ~= "" and o.TextBounds.Y > 0 and o.TextBounds.Y < 9 then
							table.insert(issues, "TINY " .. nm .. " " .. math.floor(o.TextBounds.Y))
						end
					end
				end
			end
		end
	end
	if #issues > 30 then
		local n = #issues
		issues = { table.unpack(issues, 1, 30) }
		table.insert(issues, "... total " .. n)
	end
	return table.concat(issues, "\n")
end
function K.clickText(root, text)
	for _, o in ipairs(root:GetDescendants()) do
		if o:IsA("TextButton") then
			local l = o:FindFirstChild("Label", true)
			if l and l.Text == text then return K.ui("click", o) end
		end
	end
	return "notfound"
end
function K.closeAll()
	for _, g in ipairs(pg:GetChildren()) do
		local c = g:FindFirstChild("Canvas")
		if c then
			for _, w in ipairs(c:GetChildren()) do
				local b = w:IsA("GuiObject") and w.Visible and w:FindFirstChild("Panel") and w.Panel:FindFirstChild("Close")
				if b and b.Visible then K.ui("click", b) end
			end
		end
	end
	task.wait(0.5)
end
function K.fov(base)
	local cam = workspace.CurrentCamera
	local d = require(game.ReplicatedStorage.UI).Devices[pg:GetAttribute("DeviceEmu")]
	K.savedFov = K.savedFov or cam.FieldOfView
	cam.FieldOfView = math.min(120, math.deg(2 * math.atan(math.tan(math.rad(base / 2)) * cam.ViewportSize.Y / d.H)))
end
function K.unfov()
	if K.savedFov then
		workspace.CurrentCamera.FieldOfView = K.savedFov
		K.savedFov = nil
	end
end
function K.rect()
	local c = pg.HudGui.Canvas
	local d = require(game.ReplicatedStorage.UI).Devices[pg:GetAttribute("DeviceEmu")]
	local ins = GuiService:GetGuiInset()
	return math.floor(c.AbsolutePosition.X + ins.X - d.Side + 0.5) .. " " .. math.floor(c.AbsolutePosition.Y + ins.Y - d.Top + 0.5) .. " " .. d.W .. " " .. d.H
end
function K.lastVisible(sf)
	sf.CanvasPosition = Vector2.new(0, 1e6)
	task.wait(0.25)
	local last
	for _, c in ipairs(sf:GetChildren()) do
		if c:IsA("GuiObject") and (not last or c.AbsolutePosition.Y > last.AbsolutePosition.Y) then last = c end
	end
	if not last then return "vazio" end
	local bottom = last.AbsolutePosition.Y + last.AbsoluteSize.Y
	local sfb = sf.AbsolutePosition.Y + sf.AbsoluteSize.Y
	return string.format("%s lista=%.0fpx folga=%.0f %s", last.Name, sf.AbsoluteSize.Y, sfb - bottom, (bottom <= sfb + 0.5) and "INTEIRO" or "CORTADO")
end
function K.device(dev)
	pg:SetAttribute("DeviceEmu", dev)
	task.wait(0.6)
end
return K
