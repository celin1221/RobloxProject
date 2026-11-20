--[[
	Codigos (GDD secao 13): divulgados em atualizacoes; pagam gold, invocacoes ou personagens (Dev).
	Fica no ServerStorage para o cliente nao ver codigos ainda nao divulgados.
	Chave em MAIUSCULAS. Expires = os.time() UTC opcional (depois disso o codigo nao vale mais).
	Cada jogador resgata cada codigo 1 vez (perfil.Codes), exceto codigos de Dev com Repeatable = true.
]]
return {
	-- Codigos publicos de lancamento
	LANCAMENTO = { Gold = 500, Tickets = { Comum = 1 } },
	BEMVINDO = { Gold = 300 },
	PORTAL3 = { Tickets = { Comum = 3 } },

	-- Codigos de Dev — Tag: One Piece (Repeatable = true)
	LUFFY = { Character = "Luffy", Level = 10, Repeatable = true },
	DEVLUFFY = { Character = "Luffy", Level = 10, Repeatable = true },

	NAMI = { Character = "Nami", Level = 10, Repeatable = true },
	DEVNAMI = { Character = "Nami", Level = 10, Repeatable = true },

	USOPP = { Character = "Usopp", Level = 10, Repeatable = true },
	DEVUSOPP = { Character = "Usopp", Level = 10, Repeatable = true },

	ZORO = { Character = "Zoro", Level = 10, Repeatable = true },
	DEVZORO = { Character = "Zoro", Level = 10, Repeatable = true },

	SANJI = { Character = "Sanji", Level = 10, Repeatable = true },
	DEVSANJI = { Character = "Sanji", Level = 10, Repeatable = true },

	BARBABRANCA = { Character = "BarbaBranca", Level = 10, Repeatable = true },
	DEVBARBABRANCA = { Character = "BarbaBranca", Level = 10, Repeatable = true },

	ONEPIECE = {
		Characters = { "Nami", "Usopp", "Zoro", "Sanji", "Luffy", "BarbaBranca" },
		Level = 10,
		Repeatable = true,
	},
	DEVONEPIECE = {
		Characters = { "Nami", "Usopp", "Zoro", "Sanji", "Luffy", "BarbaBranca" },
		Level = 10,
		Repeatable = true,
	},

	-- Outros personagens (Repeatable = true)
	SAN = { Character = "San", Level = 10, Repeatable = true },
	GOKU = { Character = "San", Level = 10, Repeatable = true },
	DEVSAN = { Character = "San", Level = 10, Repeatable = true },

	SETERO = { Character = "Setero", Level = 10, Repeatable = true },
	GOJO = { Character = "Setero", Level = 10, Repeatable = true },
	DEVSETERO = { Character = "Setero", Level = 10, Repeatable = true },

	KAEN = { Character = "Kaen", Level = 10, Repeatable = true },
	DEVKAEN = { Character = "Kaen", Level = 10, Repeatable = true },

	RAIKO = { Character = "Raiko", Level = 10, Repeatable = true },
	DEVRAIKO = { Character = "Raiko", Level = 10, Repeatable = true },

	YOMOGI = { Character = "Yomogi", Level = 10, Repeatable = true },
	DEVYOMOGI = { Character = "Yomogi", Level = 10, Repeatable = true },

	-- Codigo de Dev para receber todos os personagens principais de uma vez
	DEVALL = {
		Characters = { "Nami", "Usopp", "Zoro", "Sanji", "Luffy", "BarbaBranca", "San", "Setero", "Kaen", "Raiko", "Yomogi" },
		Level = 10,
		Repeatable = true,
	},
}
