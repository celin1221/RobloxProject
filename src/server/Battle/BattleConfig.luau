--[[
	BattleConfig
	Ajustes do prototipo (GDD secao 2). Tudo que muda o confronto fica aqui;
	o BattleService nao tem nome de personagem escrito no codigo.
]]

return {
	-- Times da batalha da torre (ate 6 por lado). O primeiro da lista entra em campo.
	-- O time do jogador vem do salvamento (ProgressionService); PlayerTeam so e usado sem ele.
	PlayerTeam = {
		{ CharacterId = "Yomogi", Level = 10 },
		{ CharacterId = "Kaen", Level = 10 },
		{ CharacterId = "Raiko", Level = 10 },
	},
	-- Ate a torre do prompt 10: 1 adversario nivel 3 com IA Facil (o jogador comeca so com o inicial, nivel 5)
	EnemyTeam = {
		{ CharacterId = "Raiko", Level = 3 },
	},
	EnemyAI = "Facil", -- "Facil" | "Medio" | "Dificil"

	-- Modo da batalha (GDD secao 5 - Fuga): "Wild" permite fugir;
	-- "Tower" e "PvP" bloqueiam e trocam Fugir por Desistir (conta como derrota)
	Mode = "Tower",

	-- Mochila do prototipo: 1 item, Pocao (quantidade ajustavel)
	StartingBag = { Pocao = 1 },

	-- Tempo (segundos) que cada evento do turno fica na tela antes do proximo
	EventDelay = {
		Default = 1.0,
		UseMove = 0.7,
		Damage = 1.0,
		Faint = 1.4,
	},

	-- Multiplica todas as esperas de apresentacao (1 = normal; testes podem acelerar)
	TimeScale = 1,

	EndScreenTime = 3, -- segundos mostrando Vitoria/Derrota antes de voltar a praca

	-- PvP (GDD secao 5)
	PvPTurnTime = 30, -- segundos por turno; ao estourar, acao automatica
	PvPLevel = 50, -- niveis igualados
	PvPChallengeDistance = 12, -- studs entre os dois para desafiar
	PvPInviteTime = 20, -- segundos para aceitar o desafio
	PlazaRadius = 80, -- (mapa antigo)
	PlazaHalfX = 130, -- mapa v2: praca = retangulo dentro da esteira (GDD secao 3)
	PlazaHalfZ = 90,
	TriggerCooldown = 5, -- segundos sem poder abrir outra batalha depois de voltar
}
