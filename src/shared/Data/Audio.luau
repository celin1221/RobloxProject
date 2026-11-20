--[[
	Audio (GDD secao 10 - Som). Faixas da Creator Store, gratis, conferidas no Studio
	(IsLoaded = true e TimeLength medido) pela skill roblox-sfx. Para trocar, mude o Id.
]]
local Audio = {}

Audio.Music = {
	Map = { Id = 140728100397638, Name = "Kyoto Arpeggios", Length = 230.9, Volume = 0.5 },
	Battle = { Id = 81047137733428, Name = "Japanese Shamisen Battle Samurai Rising Blade", Length = 177.3, Volume = 0.55 },
}

-- Alternativas tambem conferidas (carregam e tem a duracao medida)
Audio.Alternatives = {
	Map = {
		{ Id = 82061470648013, Name = "Hidden Lotus Pond", Length = 233.3 },
		{ Id = 1844961896, Name = "Asian Adventure (APM)", Length = 121.1 },
		{ Id = 126770507384889, Name = "Lofi Garden Breeze", Length = 209.7 },
		{ Id = 114993170766267, Name = "Winter Sparrow Koto Ambient", Length = 158.7 },
		{ Id = 137172521077350, Name = "Biwa Lake Fog", Length = 290.0 },
	},
	Battle = {
		{ Id = 122341436199468, Name = "Epic Anime Battle Music", Length = 212.9 },
		{ Id = 117269121454292, Name = "Colosseum Clash", Length = 211.1 },
		{ Id = 9042798478, Name = "Defender Of Men (APM)", Length = 116.4 },
		{ Id = 9045159025, Name = "Legend Rising Outro (APM)", Length = 94.3 },
	},
}

Audio.Fade = 1.5 -- segundos da transicao mapa <-> batalha

-- Configuracoes padrao (iguais ao perfil novo; volumes de 0 a 100)
Audio.DefaultSettings = { MusicOn = true, MusicVolume = 50, SfxOn = true, SfxVolume = 80, MapFx = true }

return Audio
