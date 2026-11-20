-- UIKit: pecas de interface comuns (paineis, textos, botoes) no estilo do jogo
local UIKit = {}

UIKit.BG = Color3.fromRGB(28, 30, 40)
UIKit.PANEL = Color3.fromRGB(38, 41, 54)
UIKit.WHITE = Color3.fromRGB(240, 240, 245)
UIKit.MUTED = Color3.fromRGB(160, 165, 180)
UIKit.GOLD = Color3.fromRGB(255, 215, 90)
UIKit.GREEN = Color3.fromRGB(60, 150, 90)
UIKit.GREY = Color3.fromRGB(90, 90, 105)
UIKit.OFF = Color3.fromRGB(70, 70, 80)

function UIKit.corner(o, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = o
end

function UIKit.stroke(o, color, t)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = t or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = o
	return s
end

function UIKit.frame(name, parent, size, pos, color)
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = pos or UDim2.new()
	f.BackgroundColor3 = color or UIKit.PANEL
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

function UIKit.label(name, parent, text, size, pos, color, align, font)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = size
	l.Position = pos or UDim2.new()
	l.BackgroundTransparency = 1
	l.Font = font or Enum.Font.GothamBold
	l.TextScaled = true
	l.TextWrapped = true
	l.TextColor3 = color or UIKit.WHITE
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Text = text
	l.Parent = parent
	return l
end

function UIKit.button(name, parent, text, size, pos, color)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = size
	b.Position = pos or UDim2.new()
	b.BackgroundColor3 = color or Color3.fromRGB(70, 110, 200)
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.TextColor3 = UIKit.WHITE
	b.Text = text
	b.Parent = parent
	UIKit.corner(b, 10)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 5)
	pad.PaddingBottom = UDim.new(0, 5)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = b
	return b
end

function UIKit.scroll(name, parent, size, pos)
	local s = Instance.new("ScrollingFrame")
	s.Name = name
	s.Size = size
	s.Position = pos
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 6
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.new()
	s.Parent = parent
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, 6)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = s
	return s
end

function UIKit.clear(container)
	for _, c in container:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

return UIKit
