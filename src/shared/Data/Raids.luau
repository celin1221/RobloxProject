--[[
	Raids (Camada 1 - Data): Evento Global de Raid Cooperativa 4x1 (estilo Pokemon Raid).
	- Relogio global sincronizado via UTC: abre a cada 1 hora (:00 UTC) por 15 minutos.
	- Todos os servidores sorteiam de forma deterministica a mesma estrela (3* a 6*) e o mesmo Boss.
	- Combate 4x1 por turnos: 1 a 4 jogadores reais + Aliados NPCs completando 4 lutadores.
	- Cada jogador leva 1 personagem (nivel real), 2 vidas individuais (2 turnos para reviver),
	  somente os 4 golpes (sem Mochila e sem Torcida), timer de 20s por turno, limite de 10 turnos.
	- Boss gigante: Escudo de Fase (65% e 30% HP), 2 acoes por turno (1 alvo + 1 area) e Pulso de Anulacao.
	- Recompensas (sem Gemas e sem Materiais de Despertar): Gold, XP de Conta, XP de Personagem,
	  Minerios de Treino + bonus de MVP (+25% Gold/XP) + Captura Pos-Raid com Selos reais da mochila
	  (5* Lendario e 6* Sukuna aceitam SOMENTE SeloSuperior; Sukuna 6* = 1% exato).
]]

local Raids = {}

-- Calendario global UTC (deterministico em todos os servidores)
Raids.IntervalSeconds = 3600 -- a cada 1 hora (:00 UTC)
Raids.OpenDurationSeconds = 900 -- janela de 15 minutos aberta
Raids.AnnounceLeadSeconds = 120 -- banner de contagem regressiva quando faltar <= 2 min (ou sempre mostra proximo horario)

-- Regras de combate cooperativo 4x1
Raids.MaxPlayers = 4
Raids.MaxTurns = 10
Raids.TurnTimer = 20 -- segundos por turno
Raids.LobbyCountdown = 30 -- segundos de espera no lobby antes de iniciar sozinho
Raids.CaptureWindowSeconds = 40 -- tempo maximo na tela de captura pos-raid antes de voltar a praca
Raids.PlayerLives = 2 -- vidas individuais por jogador humano (2/2 -> 1/2 -> 0/2)
Raids.RespawnTurns = 2 -- turnos de espera para reviver automaticamente apos desmaiar
Raids.MvpBonus = 0.25 -- +25% Gold e XP para o jogador humano com maior dano

-- Mecanicas de Boss
Raids.ShieldThresholds = { 0.65, 0.30 } -- ativa Escudo de Fase + Pulso de Anulacao aos 65% e 30% HP
Raids.ShieldDamageMult = 0.35 -- dano reduzido enquanto o Escudo esta ativo
Raids.ShieldBreakDefDrop = -2 -- -2 estagios de Defesa ao quebrar o Escudo (alem de atordoar)
Raids.ShieldBreakBurstFrac = 0.04 -- dano extra de 4% do HP maximo quando o Escudo estilhaca
Raids.BossDotCapFrac = 0.025 -- teto de dano de Queimadura/Veneno no Boss (2,5% HP max por turno)

-- Ordem de estrelas
Raids.StarOrder = { 3, 4, 5, 6 }

Raids.Tiers = {
	[3] = {
		Stars = 3,
		Name = "Raid 3 Estrelas",
		Short = "3 ESTRELAS",
		RarityLabel = "Raro / \u{c9}pico",
		Weight = 40,
		Level = 25,
		RecommendedLevel = 20,
		HpMult = 4.5,
		AtkMult = 0.72,
		ShieldBars = 4,
		BossScale = 1.75,
		Color = Color3.fromRGB(63, 168, 255),
		AccentColor = Color3.fromRGB(165, 224, 255),
		HeaderColor = "blue",
		Rewards = {
			Gold = 1500,
			AccountXp = 60,
			CharXp = 180,
			OrePerStat = 4,
		},
		Capture = {
			SuperiorOnly = false,
			SeloContrato = 0.35,
			SeloSuperior = 0.525,
		},
		Bosses = { "Freeza", "Zoro", "Kakashi", "Sasuke", "Renji", "Fushiguro", "Vegeta", "Gohan" },
		NpcAllies = { "Itadori", "Nobara", "Rukia", "Piccolo", "Todo", "Kuririn" },
	},
	[4] = {
		Stars = 4,
		Name = "Raid 4 Estrelas",
		Short = "4 ESTRELAS",
		RarityLabel = "\u{c9}pico",
		Weight = 33,
		Level = 35,
		RecommendedLevel = 32,
		HpMult = 5.5,
		AtkMult = 0.78,
		ShieldBars = 5,
		BossScale = 1.85,
		Color = Color3.fromRGB(168, 85, 247),
		AccentColor = Color3.fromRGB(224, 182, 255),
		HeaderColor = "purple",
		Rewards = {
			Gold = 3000,
			AccountXp = 110,
			CharXp = 340,
			OrePerStat = 8,
		},
		Capture = {
			SuperiorOnly = false,
			SeloContrato = 0.25,
			SeloSuperior = 0.375,
		},
		Bosses = { "Luffy", "Naruto", "Ichigo", "Nanami", "Freeza" },
		NpcAllies = { "Zoro", "Kakashi", "Sasuke", "Vegeta", "Gohan", "Fushiguro" },
	},
	[5] = {
		Stars = 5,
		Name = "Raid 5 Estrelas",
		Short = "5 ESTRELAS",
		RarityLabel = "Lend\u{e1}rio",
		Weight = 22,
		Level = 45,
		RecommendedLevel = 42,
		HpMult = 6.5,
		AtkMult = 0.84,
		ShieldBars = 6,
		BossScale = 1.95,
		Color = Color3.fromRGB(255, 200, 48),
		AccentColor = Color3.fromRGB(255, 242, 168),
		HeaderColor = "gold",
		Rewards = {
			Gold = 6000,
			AccountXp = 180,
			CharXp = 550,
			OrePerStat = 14,
		},
		Capture = {
			SuperiorOnly = true,
			SeloContrato = 0,
			SeloSuperior = 0.08,
		},
		Bosses = { "BarbaBranca", "Setero", "Sarutobi", "Byakuya", "San" },
		NpcAllies = { "Luffy", "Naruto", "Ichigo", "Nanami", "Freeza", "Vegeta" },
	},
	[6] = {
		Stars = 6,
		Name = "Raid 6 Estrelas (Secreta)",
		Short = "6 ESTRELAS \u{b7} SECRETA",
		RarityLabel = "Secreto",
		Weight = 5,
		Level = 50,
		RecommendedLevel = 48,
		HpMult = 6.2,
		AtkMult = 0.72,
		ShieldBars = 7,
		BossScale = 2.05,
		Color = Color3.fromRGB(18, 18, 26),
		AccentColor = Color3.fromRGB(235, 42, 74),
		HeaderColor = "dark",
		Rewards = {
			Gold = 12000,
			AccountXp = 300,
			CharXp = 900,
			OrePerStat = 24,
		},
		Capture = {
			SuperiorOnly = true,
			SeloContrato = 0,
			SeloSuperior = 0.01, -- 1% exato no Sukuna!
		},
		Bosses = { "Sukuna" },
		NpcAllies = { "Setero", "BarbaBranca", "Byakuya", "Sarutobi", "San" },
	},
}

-- Golpe em area padrao de Boss por classe (garante que todo Boss tenha pelo menos 1 golpe AoE!)
Raids.ClassAoeMove = {
	Espadachim = "TempestadeDeCortes",
	Lutador = "OndaDeImpacto",
	Mago = "ExplosaoAstral",
	Atirador = "ChuvaDeProjeteis",
}

-- Overrides especificos de kit de Boss para assinaturas epicas
Raids.BossMoves = {
	Sukuna = { "Desmantelar", "Clivar", "OndaArcana", "Fuga" },
	Setero = { "Atracao", "EsferaArcana", "ExplosaoAstral", "TudoRoxo" },
	BarbaBranca = { "CorteCruzado", "TempestadeDeCortes", "PosturaDaLamina", "CeuETerra" },
	Byakuya = { "Senbonzakura", "CorteCruzado", "TempestadeDeCortes", "SenbonzakuraKageyoshi" },
	Sarutobi = { "DotonMuralhaTerrestre", "KatonDragaoDeFogo", "SuitonDragaoDeAgua", "FutonTempestadeCeleste" },
	San = { "ComboMarcial", "OndaDeImpacto", "PosturaDeCombate", "GenkiDama" },
}

-- Indice inteiro da hora UTC (identico em todos os servidores do Roblox)
function Raids.SlotId(utcNow: number): number
	return math.floor(utcNow) // Raids.IntervalSeconds
end

-- Chave de string persistida no perfil para impedir duplicacao de recompensa na mesma hora UTC
function Raids.SlotKey(slotId: number): string
	return "h_" .. tostring(slotId)
end

-- Sorteio deterministico de Estrelas + Boss a partir do slot UTC
function Raids.RollForSlot(slotId: number): (number, string, number)
	local seed = (slotId * 2654435761) % 2147483647
	if seed <= 0 then
		seed = 1337
	end
	local rng = Random.new(seed)

	local totalWeight = 0
	for _, st in ipairs(Raids.StarOrder) do
		totalWeight += Raids.Tiers[st].Weight
	end
	local pick = rng:NextNumber(0, totalWeight)
	local acc = 0
	local chosenStars = 3
	for _, st in ipairs(Raids.StarOrder) do
		acc += Raids.Tiers[st].Weight
		if pick <= acc then
			chosenStars = st
			break
		end
	end

	local tier = Raids.Tiers[chosenStars]
	local bossIdx = rng:NextInteger(1, #tier.Bosses)
	local bossId = tier.Bosses[bossIdx]
	return chosenStars, bossId, seed
end

-- Retorna o estado global da Raid no instante utcNow.
-- devOverride (opcional, so no Studio): { Stars = number, BossId = string?, ExpiresAt = number, SlotId = number }
function Raids.StateAt(utcNow: number, devOverride: { [string]: any }?)
	if typeof(devOverride) == "table" and (devOverride.ExpiresAt or 0) > utcNow then
		local stars = if Raids.Tiers[devOverride.Stars] then devOverride.Stars else 6
		local tier = Raids.Tiers[stars]
		local bossId = if typeof(devOverride.BossId) == "string" and #devOverride.BossId > 0
			then devOverride.BossId
			else tier.Bosses[1]
		local slotId = devOverride.SlotId or (Raids.SlotId(utcNow) * 100 + 99)
		return {
			Open = true,
			IsDevOverride = true,
			SlotId = slotId,
			SlotKey = Raids.SlotKey(slotId),
			Stars = stars,
			Tier = tier,
			BossId = bossId,
			ClosesIn = math.max(0, math.floor(devOverride.ExpiresAt - utcNow)),
			NextOpenIn = 0,
			Seed = slotId * 997 + stars,
		}
	end

	local slotId = Raids.SlotId(utcNow)
	local elapsed = math.floor(utcNow) % Raids.IntervalSeconds
	local isOpen = elapsed < Raids.OpenDurationSeconds
	if isOpen then
		local stars, bossId, seed = Raids.RollForSlot(slotId)
		return {
			Open = true,
			IsDevOverride = false,
			SlotId = slotId,
			SlotKey = Raids.SlotKey(slotId),
			Stars = stars,
			Tier = Raids.Tiers[stars],
			BossId = bossId,
			ClosesIn = Raids.OpenDurationSeconds - elapsed,
			NextOpenIn = 0,
			Seed = seed,
		}
	else
		local nextSlot = slotId + 1
		local nextStars, nextBoss, nextSeed = Raids.RollForSlot(nextSlot)
		return {
			Open = false,
			IsDevOverride = false,
			SlotId = nextSlot,
			SlotKey = Raids.SlotKey(nextSlot),
			Stars = nextStars,
			Tier = Raids.Tiers[nextStars],
			BossId = nextBoss,
			ClosesIn = 0,
			NextOpenIn = Raids.IntervalSeconds - elapsed,
			Seed = nextSeed,
		}
	end
end

-- Chance de captura pos-raid para um selo especifico ("SeloContrato" | "SeloSuperior")
-- Retorna (allowed: boolean, chance: number, reason: string?)
function Raids.CaptureChance(stars: number, sealId: string): (boolean, number, string?)
	local tier = Raids.Tiers[stars]
	if not tier then
		return false, 0, "Tier de Raid inv\u{e1}lido."
	end
	if sealId ~= "SeloContrato" and sealId ~= "SeloSuperior" then
		return false, 0, "Selo inv\u{e1}lido."
	end
	if tier.Capture.SuperiorOnly and sealId ~= "SeloSuperior" then
		return false, 0, "Raids 5 e 6 Estrelas aceitam somente Selo Superior!"
	end
	local rate = tier.Capture[sealId] or 0
	if rate <= 0 then
		return false, 0, "Este selo n\u{e3}o pode ser usado nesta Raid."
	end
	return true, rate, nil
end

-- Calcula recompensa final (aplicando +25% Gold e XP se isMvp = true)
function Raids.ComputeRewards(stars: number, isMvp: boolean)
	local tier = Raids.Tiers[stars] or Raids.Tiers[3]
	local mult = if isMvp then (1 + Raids.MvpBonus) else 1
	local r = tier.Rewards
	return {
		Gold = math.floor(r.Gold * mult + 0.5),
		AccountXp = math.floor(r.AccountXp * mult + 0.5),
		CharXp = math.floor(r.CharXp * mult + 0.5),
		OrePerStat = r.OrePerStat,
		IsMvp = isMvp,
	}
end

return Raids
