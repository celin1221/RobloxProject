-- UITheme: gerado de C:\Blender\UI\tema.json (fonte unica). Nao editar a mao: edite o JSON e gere de novo.
-- Cores com dois valores = degrade vertical (topo, base).
local T = {}

T.Font = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular)
T.Outline = Color3.fromRGB(26, 18, 51)
T.ShadowOffset = 0.06 -- sombra embaixo dos botoes, fracao da altura
T.Palette = {
	panel = { Color3.fromRGB(79, 63, 163), Color3.fromRGB(44, 34, 102) },
	panelAlt = { Color3.fromRGB(98, 80, 194), Color3.fromRGB(61, 48, 136) },
	slot = { Color3.fromRGB(42, 32, 96), Color3.fromRGB(30, 23, 72) },
	header = { Color3.fromRGB(255, 139, 208), Color3.fromRGB(194, 64, 154) },
	gold = Color3.fromRGB(255, 212, 71),
	gems = Color3.fromRGB(255, 79, 163),
	ore = Color3.fromRGB(224, 123, 44),
	comum = Color3.fromRGB(154, 163, 181),
	raro = Color3.fromRGB(61, 139, 255),
	epico = Color3.fromRGB(168, 85, 247),
	lendario = Color3.fromRGB(255, 176, 32),
	green = Color3.fromRGB(56, 204, 99),
	red = Color3.fromRGB(255, 77, 94),
	blue = Color3.fromRGB(61, 139, 255),
	orange = Color3.fromRGB(255, 138, 43),
	purple = Color3.fromRGB(168, 85, 247),
	teal = Color3.fromRGB(34, 196, 184),
	grey = Color3.fromRGB(125, 130, 160),
	hpHigh = Color3.fromRGB(75, 224, 122),
	hpMid = Color3.fromRGB(255, 201, 60),
	hpLow = Color3.fromRGB(255, 77, 94),
	track = Color3.fromRGB(22, 15, 51),
	ink = Color3.fromRGB(26, 18, 51),
	inkSoft = Color3.fromRGB(184, 178, 224),
	onDark = Color3.fromRGB(255, 255, 255),
}
T.Types = {
	Fogo = Color3.fromRGB(255, 106, 61),
	Agua = Color3.fromRGB(61, 165, 255),
	Natureza = Color3.fromRGB(76, 203, 90),
	Raio = Color3.fromRGB(255, 210, 61),
	Luz = Color3.fromRGB(255, 242, 168),
	Trevas = Color3.fromRGB(123, 79, 201),
	Neutro = Color3.fromRGB(185, 180, 201),
}
T.Currency = { Gold = T.Palette.gold, Gems = T.Palette.gems, Ore = T.Palette.ore }
T.Rarity = { Comum = T.Palette.comum, Raro = T.Palette.raro, Epico = T.Palette.epico, Lendario = T.Palette.lendario }
T.Text = {
	Title = { Scale = 0.075, Min = 20, Max = 46 },
	Heading = { Scale = 0.055, Min = 16, Max = 34 },
	Body = { Scale = 0.043, Min = 13, Max = 26 },
	Small = { Scale = 0.034, Min = 11, Max = 20 },
}
T.Corner = { Panel = 0.08, Button = 0.22, Pill = 0.5, Card = 0.14 }
T.StrokeByHeight = { { 360, 3 }, { 500, 4 }, { 800, 5 } } -- altura da tela -> espessura (px)
T.TouchMin = 44
T.Safe = { Top = 0.16, Thumbstick = { 0.0, 0.62, 0.3, 1.0 }, Jump = { 0.76, 0.68, 1.0, 1.0 } }
T.Motion = {
	HoverScale = 1.05, HoverTime = 0.12,
	PressScale = 0.88, PressTime = 0.06,
	ReleaseTime = 0.32, ReleaseStyle = Enum.EasingStyle.Back,
	OpenFrom = 0.6, OpenTime = 0.32, OpenSlide = 0.08,
	CountTime = 0.6, ShinePeriod = 2.2,
}

-- Espessura do contorno para a altura atual da tela
function T.StrokeFor(height: number): number
	local s = T.StrokeByHeight[1][2]
	for _, e in ipairs(T.StrokeByHeight) do
		if height >= e[1] then
			s = e[2]
		end
	end
	return s
end

return T
