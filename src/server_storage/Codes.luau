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

	-- Codigos de Dev — Tag: Naruto (Repeatable = true)
	SAKURA = { Character = "Sakura", Level = 10, Repeatable = true },
	DEVSAKURA = { Character = "Sakura", Level = 10, Repeatable = true },

	SHIKAMARU = { Character = "Shikamaru", Level = 10, Repeatable = true },
	DEVSHIKAMARU = { Character = "Shikamaru", Level = 10, Repeatable = true },

	KAKASHI = { Character = "Kakashi", Level = 10, Repeatable = true },
	DEVKAKASHI = { Character = "Kakashi", Level = 10, Repeatable = true },

	SASUKE = { Character = "Sasuke", Level = 10, Repeatable = true },
	DEVSASUKE = { Character = "Sasuke", Level = 10, Repeatable = true },

	NARUTO = { Character = "Naruto", Level = 10, Repeatable = true },
	DEVNARUTO = { Character = "Naruto", Level = 10, Repeatable = true },

	SARUTOBI = { Character = "Sarutobi", Level = 10, Repeatable = true },
	DEVSARUTOBI = { Character = "Sarutobi", Level = 10, Repeatable = true },
	SARUTOBI50 = { Character = "Sarutobi", Level = 50, Repeatable = true },
	DEVSARUTOBI50 = { Character = "Sarutobi", Level = 50, Repeatable = true },

	KONOHA = {
		Characters = { "Sakura", "Shikamaru", "Kakashi", "Sasuke", "Naruto", "Sarutobi" },
		Level = 10,
		Repeatable = true,
	},
	DEVKONOHA = {
		Characters = { "Sakura", "Shikamaru", "Kakashi", "Sasuke", "Naruto", "Sarutobi" },
		Level = 10,
		Repeatable = true,
	},

	-- Codigos de Dev — Tag: Bleach (Repeatable = true)
	CHAD = { Character = "Chad", Level = 10, Repeatable = true },
	DEVCHAD = { Character = "Chad", Level = 10, Repeatable = true },

	URYU = { Character = "Uryu", Level = 10, Repeatable = true },
	DEVURYU = { Character = "Uryu", Level = 10, Repeatable = true },

	RUKIA = { Character = "Rukia", Level = 10, Repeatable = true },
	DEVRUKIA = { Character = "Rukia", Level = 10, Repeatable = true },

	RENJI = { Character = "Renji", Level = 10, Repeatable = true },
	DEVRENJI = { Character = "Renji", Level = 10, Repeatable = true },

	ICHIGO = { Character = "Ichigo", Level = 10, Repeatable = true },
	DEVICHIGO = { Character = "Ichigo", Level = 10, Repeatable = true },

	BYAKUYA = { Character = "Byakuya", Level = 10, Repeatable = true },
	DEVBYAKUYA = { Character = "Byakuya", Level = 10, Repeatable = true },

	BLEACH = {
		Characters = { "Chad", "Uryu", "Rukia", "Renji", "Ichigo", "Byakuya" },
		Level = 10,
		Repeatable = true,
	},
	DEVBLEACH = {
		Characters = { "Chad", "Uryu", "Rukia", "Renji", "Ichigo", "Byakuya" },
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
	SETERO50 = { Character = "Setero", Level = 50, Repeatable = true },
	GOJO50 = { Character = "Setero", Level = 50, Repeatable = true },
	DEVSETERO50 = { Character = "Setero", Level = 50, Repeatable = true },

	-- Codigos de Dev — Secreto: Sukuna (Normal Nv. 10 e Nivel Maximo Nv. 50)
	SUKUNA = { Character = "Sukuna", Level = 10, Repeatable = true },
	DEVSUKUNA = { Character = "Sukuna", Level = 10, Repeatable = true },
	SUKUNA50 = { Character = "Sukuna", Level = 50, Repeatable = true },
	SUKUNAMAX = { Character = "Sukuna", Level = 50, Repeatable = true },
	DEVSUKUNA50 = { Character = "Sukuna", Level = 50, Repeatable = true },

	KAEN = { Character = "Kaen", Level = 10, Repeatable = true },
	DEVKAEN = { Character = "Kaen", Level = 10, Repeatable = true },

	RAIKO = { Character = "Raiko", Level = 10, Repeatable = true },
	DEVRAIKO = { Character = "Raiko", Level = 10, Repeatable = true },

	YOMOGI = { Character = "Yomogi", Level = 10, Repeatable = true },
	DEVYOMOGI = { Character = "Yomogi", Level = 10, Repeatable = true },

	-- Codigo de Dev para testar o Altar Secreto do Despertar (materiais + 10.000 Gold + iniciais Nv. 35)
	DESPERTAR = {
		Gold = 10000,
		Materials = {
			EssenciaLamina = 10,
			EssenciaPunho = 10,
			EssenciaArcana = 10,
			EssenciaPrecisao = 10,
			FragmentoFolha = 6,
			FragmentoMares = 6,
			FragmentoAlmas = 6,
			NucleoDespertar = 4,
		},
		Repeatable = true,
	},
	DEVDESPERTAR = {
		Gold = 10000,
		Materials = {
			EssenciaLamina = 10,
			EssenciaPunho = 10,
			EssenciaArcana = 10,
			EssenciaPrecisao = 10,
			FragmentoFolha = 6,
			FragmentoMares = 6,
			FragmentoAlmas = 6,
			NucleoDespertar = 4,
		},
		Repeatable = true,
	},

	-- Codigo de Dev para receber todos os personagens principais de uma vez
	DEVALL = {
		Characters = {
			"Nami", "Usopp", "Zoro", "Sanji", "Luffy", "BarbaBranca",
			"Sakura", "Shikamaru", "Kakashi", "Sasuke", "Naruto", "Sarutobi",
			"Chad", "Uryu", "Rukia", "Renji", "Ichigo", "Byakuya",
			"San", "Setero", "Sukuna", "Kaen", "Raiko", "Yomogi",
		},
		Level = 10,
		Repeatable = true,
	},
}
