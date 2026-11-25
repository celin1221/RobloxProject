--[[
	Gyms (Data/Gyms - Ginasios de Anime dentro da Torre)
	So dados; a logica da corrida e recompensas fica em ServerScriptService/Tower/TowerService.

	Cada Ginasio representa uma colecao de anime com uma mini-trilha de 3 lutas (1x1 ou 2x2):
	  1. Desafio 1 (2 personagens)
	  2. Desafio 2 (4 personagens)
	  3. Lider do Ginasio (elenco completo de 6 personagens do anime)

	Ao vencer o Lider:
	  - Conquista permanentemente a Insignia do Ginasio (`data.GymsCleared[gymId] = true`).
	  - Desbloqueia o Banner daquele anime no Portal de Invocacao (`data.UnlockedBanners[anime] = true`).
	  - Se o jogador ja desbloqueou o banner pelo personagem inicial (Luffy / Naruto / Ichigo),
	    vencer o ginasio entrega a Insignia + recompensa de primeira vitoria (Gold e Gemas).
]]

local Gyms = {}

Gyms.Order = { "Naruto", "OnePiece", "Bleach" }

Gyms.List = {
	Naruto = {
		Id = "Naruto",
		Tier = 1,
		Anime = "Naruto",
		BannerId = "Naruto",
		Name = "Gin\u{e1}sio de Konoha",
		AnimeName = "Naruto",
		LeaderName = "Mestre Sarutobi",
		BadgeName = "Ins\u{ed}gnia da Folha",
		BadgeIcon = "insignia_naruto",
		Color = "orange",
		Accent = Color3.fromRGB(255, 138, 43),
		RecommendedLevel = 16,
		FirstReward = { Gold = 2500, Gems = 8, Items = { "DoceRaro" } },
		RepeatReward = { Gold = 1200 },
		Stages = {
			{
				Title = "Disc\u{ed}pulo Genin",
				AI = "Facil",
				Level = 12,
				Team = { "Sakura", "Shikamaru" },
			},
			{
				Title = "Capit\u{e3}o Jounin",
				AI = "Medio",
				Level = 14,
				Team = { "Sakura", "Shikamaru", "Kakashi", "Sasuke" },
			},
			{
				Title = "L\u{ed}der de Konoha",
				AI = "Dificil",
				Level = 16,
				Team = { "Sarutobi", "Naruto", "Sasuke", "Kakashi", "Shikamaru", "Sakura" },
			},
		},
	},
	OnePiece = {
		Id = "OnePiece",
		Tier = 2,
		Anime = "OnePiece",
		BannerId = "OnePiece",
		Name = "Gin\u{e1}sio da Grand Line",
		AnimeName = "One Piece",
		LeaderName = "Barba Branca",
		BadgeName = "Ins\u{ed}gnia dos Mares",
		BadgeIcon = "insignia_onepiece",
		Color = "blue",
		Accent = Color3.fromRGB(56, 178, 255),
		RecommendedLevel = 20,
		FirstReward = { Gold = 4500, Gems = 12, Items = { "DoceRaro" } },
		RepeatReward = { Gold = 2200 },
		Stages = {
			{
				Title = "Tripulante Novato",
				AI = "Facil",
				Level = 16,
				Team = { "Nami", "Usopp" },
			},
			{
				Title = "Imediato dos Mares",
				AI = "Medio",
				Level = 18,
				Team = { "Nami", "Usopp", "Zoro", "Sanji" },
			},
			{
				Title = "L\u{ed}der dos Yonkou",
				AI = "Dificil",
				Level = 20,
				Team = { "BarbaBranca", "Luffy", "Zoro", "Sanji", "Usopp", "Nami" },
			},
		},
	},
	Bleach = {
		Id = "Bleach",
		Tier = 3,
		Anime = "Bleach",
		BannerId = "Bleach",
		Name = "Gin\u{e1}sio da Soul Society",
		AnimeName = "Bleach",
		LeaderName = "Capit\u{e3}o Byakuya",
		BadgeName = "Ins\u{ed}gnia Ceifadora",
		BadgeIcon = "insignia_bleach",
		Color = "teal",
		Accent = Color3.fromRGB(48, 212, 232),
		RecommendedLevel = 24,
		FirstReward = { Gold = 7500, Gems = 15, Items = { "DoceEpico" } },
		RepeatReward = { Gold = 3500 },
		Stages = {
			{
				Title = "Oficial da Divis\u{e3}o",
				AI = "Facil",
				Level = 20,
				Team = { "Chad", "Uryu" },
			},
			{
				Title = "Tenente Shinigami",
				AI = "Medio",
				Level = 22,
				Team = { "Chad", "Uryu", "Rukia", "Renji" },
			},
			{
				Title = "L\u{ed}der da Soul Society",
				AI = "Dificil",
				Level = 24,
				Team = { "Byakuya", "Ichigo", "Renji", "Rukia", "Uryu", "Chad" },
			},
		},
	},
}

function Gyms.Get(id: string?)
	return if typeof(id) == "string" then Gyms.List[id] else nil
end

function Gyms.ByAnime(animeId: string?)
	if typeof(animeId) ~= "string" then
		return nil
	end
	for _, id in ipairs(Gyms.Order) do
		local g = Gyms.List[id]
		if g and g.Anime == animeId then
			return g
		end
	end
	return nil
end

-- Retorna o Ginasio necessario para desbloquear um banner (nil se o banner nao exige ginasio)
function Gyms.ForBanner(bannerId: string?)
	if typeof(bannerId) ~= "string" or bannerId == "Todos" then
		return nil
	end
	for _, id in ipairs(Gyms.Order) do
		local g = Gyms.List[id]
		if g and (g.BannerId == bannerId or g.Anime == bannerId) then
			return g
		end
	end
	return nil
end

return Gyms
