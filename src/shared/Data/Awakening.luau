--[[
	Awakening (Camada 1 - Data): sistema de Despertar / Evolucao de Epicos na Maquina Secreta.
	- Exige Nivel 35+, Gold (10.000) e combinacao de Materiais de Despertar (Essencias de Classe +
	  Fragmentos de Anime + Nucleo do Despertar).
	- Materiais ficam salvos em data.Materials (sem ocupar os 30 slots da mochila de batalha).
	- Ao despertar: desbloqueia a Passiva Secreta Unica, selo "DESPERTO", aura 3D minimalista em
	  particulas e +10% nos atributos finais.
]]

local Awakening = {}

Awakening.StatBonus = 0.10 -- +10% em todos os atributos finais quando Desperto
Awakening.MinLevel = 35
Awakening.MaxMaterialStack = 999
Awakening.SecretHint = "Desbloqueie no Nv. 35 em uma passagem secreta nos montes..."

-- Mapeamento automatico de classe/anime -> material correspondente (escala para futuros personagens)
Awakening.ClassEssence = {
	Espadachim = "EssenciaLamina",
	Lutador = "EssenciaPunho",
	Mago = "EssenciaArcana",
	Atirador = "EssenciaPrecisao",
}

Awakening.AnimeFragment = {
	Naruto = "FragmentoFolha",
	OnePiece = "FragmentoMares",
	Bleach = "FragmentoAlmas",
}

Awakening.MaterialOrder = {
	"EssenciaLamina",
	"EssenciaPunho",
	"EssenciaArcana",
	"EssenciaPrecisao",
	"FragmentoFolha",
	"FragmentoMares",
	"FragmentoAlmas",
	"NucleoDespertar",
}

Awakening.Materials = {
	EssenciaLamina = {
		Id = "EssenciaLamina",
		Name = "Essência da Lâmina",
		Short = "Ess. Lâmina",
		Category = "Essencia",
		Rarity = "Raro",
		Color = Color3.fromRGB(235, 82, 92),
		Icon = "classe_espadachim",
		Source = "Torre e selvagens Espadachins no Refúgio",
		Description = "Essência concentrada do estilo Espadachim usada no Altar do Despertar.",
	},
	EssenciaPunho = {
		Id = "EssenciaPunho",
		Name = "Essência do Punho",
		Short = "Ess. Punho",
		Category = "Essencia",
		Rarity = "Raro",
		Color = Color3.fromRGB(248, 152, 52),
		Icon = "classe_lutador",
		Source = "Torre e selvagens Lutadores no Refúgio",
		Description = "Essência concentrada do estilo Lutador usada no Altar do Despertar.",
	},
	EssenciaArcana = {
		Id = "EssenciaArcana",
		Name = "Essência Arcana",
		Short = "Ess. Arcana",
		Category = "Essencia",
		Rarity = "Raro",
		Color = Color3.fromRGB(168, 108, 255),
		Icon = "classe_mago",
		Source = "Torre e selvagens Magos no Refúgio",
		Description = "Essência concentrada do estilo Mago usada no Altar do Despertar.",
	},
	EssenciaPrecisao = {
		Id = "EssenciaPrecisao",
		Name = "Essência da Precisão",
		Short = "Ess. Precisão",
		Category = "Essencia",
		Rarity = "Raro",
		Color = Color3.fromRGB(70, 212, 148),
		Icon = "classe_atirador",
		Source = "Torre e selvagens Atiradores no Refúgio",
		Description = "Essência concentrada do estilo Atirador usada no Altar do Despertar.",
	},
	FragmentoFolha = {
		Id = "FragmentoFolha",
		Name = "Fragmento da Folha",
		Short = "Frag. Folha",
		Category = "Fragmento",
		Rarity = "Epico",
		Color = Color3.fromRGB(255, 138, 43),
		Icon = "insignia_naruto",
		Source = "Ginásio da Folha",
		Description = "Relíquia espiritual obtida ao vencer o Ginásio da Folha.",
	},
	FragmentoMares = {
		Id = "FragmentoMares",
		Name = "Fragmento dos Mares",
		Short = "Frag. Mares",
		Category = "Fragmento",
		Rarity = "Epico",
		Color = Color3.fromRGB(56, 178, 255),
		Icon = "insignia_onepiece",
		Source = "Ginásio dos Mares",
		Description = "Relíquia espiritual obtida ao vencer o Ginásio dos Mares.",
	},
	FragmentoAlmas = {
		Id = "FragmentoAlmas",
		Name = "Fragmento das Almas",
		Short = "Frag. Almas",
		Category = "Fragmento",
		Rarity = "Epico",
		Color = Color3.fromRGB(56, 224, 238),
		Icon = "insignia_bleach",
		Source = "Ginásio das Almas",
		Description = "Relíquia espiritual obtida ao vencer o Ginásio das Almas.",
	},
	NucleoDespertar = {
		Id = "NucleoDespertar",
		Name = "Núcleo do Despertar",
		Short = "Núcleo Despertar",
		Category = "Nucleo",
		Rarity = "Lendario",
		Color = Color3.fromRGB(255, 208, 72),
		Icon = "gem",
		Source = "Torre Difícil, Chefes do Infinito e Forja Nv. 6+",
		Description = "Catalisador lendário necessário para despertar a Passiva Secreta de personagens Épicos.",
	},
}

-- Receitas de Despertar (Epicos Iniciais; extensivel para novos Epicos no futuro)
Awakening.RecipeOrder = { "Luffy", "Naruto", "Ichigo" }

Awakening.Recipes = {
	Luffy = {
		CharacterId = "Luffy",
		MinLevel = 35,
		Gold = 10000,
		SecretPassive = "VontadeDeD",
		Title = "Desperto",
		AuraColor = Color3.fromRGB(255, 205, 85),
		AuraSecondary = Color3.fromRGB(255, 95, 65),
		Materials = {
			{ Id = "EssenciaPunho", Qty = 8 },
			{ Id = "FragmentoMares", Qty = 5 },
			{ Id = "NucleoDespertar", Qty = 2 },
		},
	},
	Naruto = {
		CharacterId = "Naruto",
		MinLevel = 35,
		Gold = 10000,
		SecretPassive = "MantoDaRaposa",
		Title = "Desperto",
		AuraColor = Color3.fromRGB(255, 148, 38),
		AuraSecondary = Color3.fromRGB(255, 228, 96),
		Materials = {
			{ Id = "EssenciaPunho", Qty = 6 },
			{ Id = "EssenciaArcana", Qty = 2 },
			{ Id = "FragmentoFolha", Qty = 5 },
			{ Id = "NucleoDespertar", Qty = 2 },
		},
	},
	Ichigo = {
		CharacterId = "Ichigo",
		MinLevel = 35,
		Gold = 10000,
		SecretPassive = "DespertarHollow",
		Title = "Desperto",
		AuraColor = Color3.fromRGB(235, 52, 74),
		AuraSecondary = Color3.fromRGB(72, 214, 255),
		Materials = {
			{ Id = "EssenciaLamina", Qty = 8 },
			{ Id = "FragmentoAlmas", Qty = 5 },
			{ Id = "NucleoDespertar", Qty = 2 },
		},
	},
}

-- Taxas de drop por modo de jogo (usadas pelo servidor em TowerService e RefugeService)
Awakening.Drops = {
	Gym = {
		FirstFragmentQty = 2,
		RepeatFragmentQty = 1,
		FirstEssenceQty = 2,
		RepeatEssenceChance = 0.60,
	},
	Tower = {
		Facil = { EssenceChance = 0.65, EssenceQty = 1, CoreChance = 0 },
		Medio = { EssenceChance = 1.00, EssenceQty = 1, ExtraEssenceChance = 0.45, CoreChance = 0 },
		Dificil = { EssenceChance = 1.00, EssenceQty = 2, CoreChance = 0.50, DailyGuaranteedCore = true },
		Infinito = {
			FloorEssenceChance = 0.25,
			BossEssenceQty = 1,
			BossCoreBase = 0.35, -- Andar 5 = 35%, Andar 10 = 60%, Andar 15+ = 85% (100% a cada 15 andares)
			BossCoreStep = 0.25,
			BossCoreMax = 0.90,
		},
	},
	Refuge = {
		WildEssenceChance = 0.28, -- 28% por selvagem derrotado/capturado (da classe do selvagem)
		ForgeHighCoreLevel = 6,
		ForgeHighCoreChance = 0.12, -- 12% no bau de drop quando Forja >= 6
	},
}

function Awakening.GetMaterial(id: string?)
	if typeof(id) ~= "string" then
		return nil
	end
	return Awakening.Materials[id]
end

function Awakening.RecipeFor(characterId: string?)
	if typeof(characterId) ~= "string" then
		return nil
	end
	return Awakening.Recipes[characterId]
end

function Awakening.SanitizeMaterials(tbl): { [string]: number }
	local out = {}
	if typeof(tbl) == "table" then
		for _, id in ipairs(Awakening.MaterialOrder) do
			local v = math.floor(tonumber(tbl[id]) or 0)
			if v > 0 then
				out[id] = math.min(Awakening.MaxMaterialStack, v)
			end
		end
	end
	return out
end

function Awakening.MaterialCount(data, materialId: string): number
	if typeof(data) ~= "table" or typeof(data.Materials) ~= "table" then
		return 0
	end
	return math.max(0, math.floor(tonumber(data.Materials[materialId]) or 0))
end

-- Verifica se um membro salvo pode despertar agora. Retorna (ok, reason, checks)
function Awakening.CanAwaken(data, uid: string): (boolean, string?, { any }?)
	if typeof(data) ~= "table" or typeof(data.Collection) ~= "table" then
		return false, "Dados indisponíveis.", nil
	end
	local m = data.Collection[uid]
	if not m then
		return false, "Personagem não encontrado.", nil
	end
	local recipe = Awakening.RecipeFor(m.CharacterId)
	if not recipe then
		return false, "Este personagem não possui Despertar.", nil
	end
	if m.Awakened == true then
		return false, "Este personagem já está Desperto.", nil
	end

	local checks = {}
	local firstReason = nil

	local reqLv = recipe.MinLevel or Awakening.MinLevel
	local curLv = math.floor(tonumber(m.Level) or 1)
	local lvOk = curLv >= reqLv
	table.insert(checks, { Kind = "Level", Label = "Nível " .. reqLv .. "+", Have = curLv, Need = reqLv, Ok = lvOk })
	if not lvOk and not firstReason then
		firstReason = "Precisa estar no Nível " .. reqLv .. " (atual: Nv. " .. curLv .. ")."
	end

	local curGold = math.floor(tonumber(data.Gold) or 0)
	local goldOk = curGold >= recipe.Gold
	table.insert(checks, { Kind = "Gold", Label = "Gold", Have = curGold, Need = recipe.Gold, Ok = goldOk })
	if not goldOk and not firstReason then
		firstReason = "Gold insuficiente (precisa de " .. recipe.Gold .. ")."
	end

	for _, req in ipairs(recipe.Materials) do
		local mat = Awakening.Materials[req.Id]
		local have = Awakening.MaterialCount(data, req.Id)
		local okMat = have >= req.Qty
		table.insert(checks, {
			Kind = "Material",
			Id = req.Id,
			Label = if mat then mat.Name else req.Id,
			Have = have,
			Need = req.Qty,
			Ok = okMat,
		})
		if not okMat and not firstReason then
			firstReason = "Faltam " .. (req.Qty - have) .. "x " .. (if mat then mat.Name else req.Id) .. "."
		end
	end

	return firstReason == nil, firstReason, checks
end

-- Resumo legivel da receita (usado na UI e na planilha Excel)
function Awakening.FormatRecipe(characterId: string): string
	local r = Awakening.RecipeFor(characterId)
	if not r then
		return "-"
	end
	local parts = { "Nv. " .. (r.MinLevel or Awakening.MinLevel) .. "+" }
	for _, req in ipairs(r.Materials) do
		local mat = Awakening.Materials[req.Id]
		table.insert(parts, req.Qty .. "x " .. (if mat then mat.Name else req.Id))
	end
	table.insert(parts, tostring(r.Gold) .. " Gold")
	return table.concat(parts, " + ")
end

return Awakening
