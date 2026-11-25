-- UITheme: gerado de C:\Blender\UI\tema.json (fonte unica). Nao editar a mao: edite o JSON e gere de novo.
-- Cores com dois valores = degrade vertical (topo, base).
local T = {}

T.Font = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular)
T.Outline = Color3.fromRGB(11, 14, 34)
T.ShadowOffset = 0.065 -- sombra fisica embaixo dos paineis e botoes
T.Palette = {
	panel = { Color3.fromRGB(39, 48, 102), Color3.fromRGB(22, 27, 61) },
	panelAlt = { Color3.fromRGB(54, 66, 138), Color3.fromRGB(33, 40, 89) },
	slot = { Color3.fromRGB(25, 30, 66), Color3.fromRGB(15, 18, 43) },
	header = { Color3.fromRGB(59, 158, 255), Color3.fromRGB(27, 100, 216) },
	gold = Color3.fromRGB(255, 216, 74),
	gems = Color3.fromRGB(255, 79, 168),
	ore = Color3.fromRGB(240, 130, 40),
	comum = Color3.fromRGB(158, 168, 188),
	raro = Color3.fromRGB(56, 152, 255),
	epico = Color3.fromRGB(176, 92, 255),
	lendario = Color3.fromRGB(255, 180, 31),
	secreto = Color3.fromRGB(16, 16, 22),
	green = Color3.fromRGB(46, 224, 110),
	red = Color3.fromRGB(255, 71, 87),
	blue = Color3.fromRGB(46, 144, 255),
	orange = Color3.fromRGB(255, 140, 36),
	purple = Color3.fromRGB(168, 85, 247),
	teal = Color3.fromRGB(26, 209, 197),
	grey = Color3.fromRGB(110, 117, 153),
	hpHigh = Color3.fromRGB(60, 230, 123),
	hpMid = Color3.fromRGB(255, 204, 56),
	hpLow = Color3.fromRGB(255, 71, 87),
	track = Color3.fromRGB(11, 14, 34),
	ink = Color3.fromRGB(11, 14, 34),
	inkSoft = Color3.fromRGB(184, 194, 240),
	onDark = Color3.fromRGB(255, 255, 255),
}
T.Types = {
	Espadachim = Color3.fromRGB(235, 78, 86),
	Lutador = Color3.fromRGB(248, 138, 42),
	Mago = Color3.fromRGB(152, 82, 245),
	Atirador = Color3.fromRGB(48, 186, 128),
	Universal = Color3.fromRGB(155, 162, 185),
	-- fallback de cores antigas caso alguma UI/log antigo referencie
	Fogo = Color3.fromRGB(255, 106, 61),
	Agua = Color3.fromRGB(56, 168, 255),
	Natureza = Color3.fromRGB(66, 212, 98),
	Raio = Color3.fromRGB(255, 212, 56),
	Luz = Color3.fromRGB(255, 242, 168),
	Trevas = Color3.fromRGB(130, 84, 216),
	Neutro = Color3.fromRGB(185, 180, 201),
}
T.Currency = { Gold = T.Palette.gold, Gems = T.Palette.gems, Ore = T.Palette.ore }
T.Rarity = { Comum = T.Palette.comum, Raro = T.Palette.raro, Epico = T.Palette.epico, Lendario = T.Palette.lendario, Secreto = T.Palette.secreto }
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
