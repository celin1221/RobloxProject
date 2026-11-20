--[[
	Encounters (GDD secao 3: 4 zonas de encontro entre a praca e as bases; secao 4: chance por raridade)
	Personagens selvagens aparecem nas zonas; o jogador chega perto e enfrenta.
	Raridade sorteada por Characters.Rarities[...].EncounterChance (Comum 60%, Raro 28%, Epico 10%, Lendario 2%).
	Captura pela formula da secao 7 (Characters.CaptureChance). Fuga permitida (modo "Wild").

	Valores que o GDD nao define (registrados em PROGRESSO.md): niveis por zona, 3 selvagens por zona,
	reaparecimento em 20 s, IA Facil.
	As zonas ficam entre os caminhos das bases (que saem a 15 + 30k graus), a 140 studs do centro.
]]

local Encounters = {}

Encounters.Zones = {
	{ Id = "Leste", Name = "Campo das Lib\u{e9}lulas", Center = Vector3.new(140, 0, 0), Radius = 24, MinLevel = 3, MaxLevel = 6, Spawns = 3 },
	{ Id = "Sul", Name = "Bosque das Lanternas", Center = Vector3.new(0, 0, 140), Radius = 24, MinLevel = 6, MaxLevel = 10, Spawns = 3 },
	{ Id = "Oeste", Name = "Vale da N\u{e9}voa", Center = Vector3.new(-140, 0, 0), Radius = 24, MinLevel = 10, MaxLevel = 15, Spawns = 3 },
	{ Id = "Norte", Name = "Colina dos Ventos", Center = Vector3.new(0, 0, -140), Radius = 24, MinLevel = 15, MaxLevel = 20, Spawns = 3 },
}

Encounters.RespawnTime = 20
Encounters.AI = "Facil"

return Encounters
