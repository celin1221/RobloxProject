--[[
	TypeChart (Sistema de Classes do jogo)
	Substitui a antiga tipagem elemental estilo Pokemon por Classes de combate:
	  Espadachim, Lutador, Mago, Atirador (+ expansivel para novas classes no futuro).

	Sem multiplicador de vantagem/desvantagem entre classes (sempre 1x):
	a diferenciacao acontece pela identidade de golpes genericos, animacoes de arma/estilo,
	bonus de afinidade de classe (STAB 1.5x) e sinergia em batalhas 1x1 e 2x2.
	Mantem o nome do modulo `TypeChart` e os campos `Types`, `DisplayName`, `Color` e `Multiplier`
	para compatibilidade total com todos os modulos existentes.
]]

local TypeChart = {}

TypeChart.Types = { "Espadachim", "Lutador", "Mago", "Atirador" }
TypeChart.Classes = TypeChart.Types

TypeChart.DisplayName = {
	Espadachim = "Espadachim",
	Lutador = "Lutador",
	Mago = "Mago",
	Atirador = "Atirador",
	Universal = "Universal",
}

TypeChart.ClassInfo = {
	Espadachim = {
		Id = "Espadachim",
		Name = "Espadachim",
		Role = "Cortes precisos, alto cr\u{ed}tico e golpes em arco",
		Color = Color3.fromRGB(235, 78, 86),
	},
	Lutador = {
		Id = "Lutador",
		Name = "Lutador",
		Role = "Combos f\u{ed}sicos r\u{e1}pidos, quebra-guarda e postura",
		Color = Color3.fromRGB(248, 138, 42),
	},
	Mago = {
		Id = "Mago",
		Name = "Mago",
		Role = "Golpes em \u{e1}rea (2x2), status e controle arcano",
		Color = Color3.fromRGB(152, 82, 245),
	},
	Atirador = {
		Id = "Atirador",
		Name = "Atirador",
		Role = "Disparos certeiros e foco em alvo \u{fa}nico \u{e0} dist\u{e2}ncia",
		Color = Color3.fromRGB(48, 186, 128),
	},
	Universal = {
		Id = "Universal",
		Name = "Universal",
		Role = "T\u{e9}cnica geral dispon\u{ed}vel para qualquer classe",
		Color = Color3.fromRGB(155, 162, 185),
	},
}

-- Cor de cada classe (botoes de golpe, selos e particulas de impacto)
TypeChart.Color = {
	Espadachim = Color3.fromRGB(235, 78, 86),
	Lutador = Color3.fromRGB(248, 138, 42),
	Mago = Color3.fromRGB(152, 82, 245),
	Atirador = Color3.fromRGB(48, 186, 128),
	Universal = Color3.fromRGB(155, 162, 185),
}

-- Sem vantagens/desvantagens entre classes: tabela vazia (sempre 1x)
TypeChart.Chart = {}

-- Multiplicador de classe (sempre 1x; mantido por compatibilidade com DamageCalc/AIController)
function TypeChart.Multiplier(attackClass: string?, defenseClass: string?): number
	local row = attackClass and TypeChart.Chart[attackClass]
	return (row and defenseClass and row[defenseClass]) or 1
end

return TypeChart
