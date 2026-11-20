--[[
	TypeChart (GDD secao 5 - Tipos)
	Ids de tipo sem acento; o nome mostrado na tela fica em DisplayName.
	Chart[tipoDoGolpe][tipoDoAlvo] = multiplicador. Qualquer combinacao fora da tabela = x1.
]]

local TypeChart = {}

TypeChart.Types = { "Fogo", "Agua", "Natureza", "Raio", "Luz", "Trevas", "Neutro" }

TypeChart.DisplayName = {
	Fogo = "Fogo",
	Agua = "Água",
	Natureza = "Natureza",
	Raio = "Raio",
	Luz = "Luz",
	Trevas = "Trevas",
	Neutro = "Neutro",
}

-- Cor de cada tipo (botoes de golpe e particulas de impacto)
TypeChart.Color = {
	Fogo = Color3.fromRGB(240, 110, 40),
	Agua = Color3.fromRGB(60, 140, 235),
	Natureza = Color3.fromRGB(80, 180, 80),
	Raio = Color3.fromRGB(245, 200, 40),
	Luz = Color3.fromRGB(240, 230, 170),
	Trevas = Color3.fromRGB(110, 70, 150),
	Neutro = Color3.fromRGB(150, 150, 150),
}

-- Valores exatos do GDD: x2 com vantagem, x0,5 com desvantagem
TypeChart.Chart = {
	Fogo = { Natureza = 2, Agua = 0.5 },
	Agua = { Fogo = 2, Natureza = 0.5, Raio = 0.5 },
	Natureza = { Agua = 2, Raio = 2, Fogo = 0.5 },
	Raio = { Agua = 2, Natureza = 0.5 },
	Luz = { Trevas = 2, Luz = 0.5 },
	Trevas = { Luz = 2, Trevas = 0.5 },
	Neutro = {},
}

-- Multiplicador de tipo de um golpe contra um alvo
function TypeChart.Multiplier(attackType: string, defenseType: string): number
	local row = TypeChart.Chart[attackType]
	return (row and row[defenseType]) or 1
end

return TypeChart
