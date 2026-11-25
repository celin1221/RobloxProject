--[[
	Training (GDD secao 8 - Maquina de Treinamento / Cupula e 4 Minerios de Atributo)
	Dados estaticos e calculos puros. Nao guarda estado e nao chama APIs de servidor.

	Regras:
	- Aumenta os atributos de Treino (0 a 100%) de 20 em 20 (passos de +20).
	- 1 minerio especifico por atributo (separados por raridade):
	    HP         -> Minerio Vital      (Comum)    desbloqueio: Mineracao Nv. 1
	    Defense    -> Minerio Ferreo     (Raro)     desbloqueio: Mineracao Nv. 2
	    Speed      -> Minerio Veloz      (Epico)    desbloqueio: Mineracao Nv. 4
	    Attack     -> Minerio Rubro      (Lendario) desbloqueio: Mineracao Nv. 6 (o mais raro)
	- Pode treinar multiplos atributos na mesma sessao, com acrescimo no custo de crafting.
	- Personagens mais raros custam mais minerio e levam um pouco mais de tempo.
	- Melhorar o nivel da maquina (gold) aumenta a eficiencia (reduz o tempo por ponto).
	- Tempo base no nivel 1 da maquina, personagem Comum, 1 passo (+20): 60 s (1 minuto).
]]

local Genetics = require(script.Parent:WaitForChild("Genetics"))

local Training = {}

Training.Stats = { "HP", "Attack", "Defense", "Speed" }
Training.StatLabels = Genetics.StatLabels

Training.Step = 20
Training.Max = 100
Training.BaseStepSeconds = 60 -- 1 min no basico (Comum, Maquina Nv. 1) para subir +20 uma vez
Training.MaxOrePerType = 9999
Training.MaxLevel = 10
Training.CancelRefundRatio = 0.5

-- Ordem de exibicao (do comum ao mais raro)
Training.OreOrder = { "HP", "Defense", "Speed", "Attack" }

Training.Ores = {
	HP = {
		Stat = "HP",
		Id = "MinerioHP",
		Icon = "ore_hp",
		Name = "Min\u{e9}rio Vital",
		Short = "Vital (HP)",
		StatName = "HP",
		Rarity = "Comum",
		UnlockMiningLevel = 1,
		Color = Color3.fromRGB(75, 224, 122),
		BaseStepCost = 8,
	},
	Defense = {
		Stat = "Defense",
		Id = "MinerioDefesa",
		Icon = "ore_def",
		Name = "Min\u{e9}rio F\u{e9}rreo",
		Short = "F\u{e9}rreo (DEF)",
		StatName = "Defesa",
		Rarity = "Raro",
		UnlockMiningLevel = 2,
		Color = Color3.fromRGB(61, 165, 255),
		BaseStepCost = 6,
	},
	Speed = {
		Stat = "Speed",
		Id = "MinerioVelocidade",
		Icon = "ore_vel",
		Name = "Min\u{e9}rio Veloz",
		Short = "Veloz (VEL)",
		StatName = "Velocidade",
		Rarity = "Epico",
		UnlockMiningLevel = 4,
		Color = Color3.fromRGB(168, 85, 247),
		BaseStepCost = 5,
	},
	Attack = {
		Stat = "Attack",
		Id = "MinerioAtaque",
		Icon = "ore_atq",
		Name = "Min\u{e9}rio Rubro",
		Short = "Rubro (ATQ)",
		StatName = "Ataque",
		Rarity = "Lendario",
		UnlockMiningLevel = 6,
		Color = Color3.fromRGB(255, 96, 64),
		BaseStepCost = 4,
	},
}

-- Multiplicador de custo e tempo conforme a raridade do personagem
Training.RarityCostMult = {
	Comum = 1.00,
	Raro = 1.50,
	Epico = 2.25,
	Lendario = 3.50,
	Secreto = 4.50,
}

Training.RarityTimeMult = {
	Comum = 1.00,
	Raro = 1.20,
	Epico = 1.40,
	Lendario = 1.65,
	Secreto = 1.90,
}

-- Adicional de custo por treinar varios atributos juntos na mesma sessao
Training.MultiStatCostMult = {
	[1] = 1.00,
	[2] = 1.25,
	[3] = 1.50,
	[4] = 1.80,
}

-- Niveis da Maquina de Treinamento (upgrade com gold -> eficiencia = reducao de tempo)
Training.Levels = {
	[1] = { SpeedMult = 1.00, UpgradeGold = nil },
	[2] = { SpeedMult = 1.15, UpgradeGold = 500 },
	[3] = { SpeedMult = 1.30, UpgradeGold = 1500 },
	[4] = { SpeedMult = 1.50, UpgradeGold = 4000 },
	[5] = { SpeedMult = 1.75, UpgradeGold = 10000 },
	[6] = { SpeedMult = 2.00, UpgradeGold = 22000 },
	[7] = { SpeedMult = 2.35, UpgradeGold = 45000 },
	[8] = { SpeedMult = 2.75, UpgradeGold = 85000 },
	[9] = { SpeedMult = 3.25, UpgradeGold = 140000 },
	[10] = { SpeedMult = 4.00, UpgradeGold = 220000 },
}

local function cleanInt(v: number?, maxVal: number?): number
	if typeof(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
		return 0
	end
	return math.clamp(math.floor(v), 0, maxVal or Training.MaxOrePerType)
end

function Training.ZeroOres()
	return { HP = 0, Attack = 0, Defense = 0, Speed = 0 }
end

function Training.SanitizeOres(tbl, maxVal: number?)
	local out = Training.ZeroOres()
	if typeof(tbl) ~= "table" then
		return out
	end
	for _, stat in ipairs(Training.Stats) do
		out[stat] = cleanInt(tbl[stat], maxVal)
	end
	return out
end

function Training.MachineLevelOf(data): number
	local lvl = data and data.TrainingMachine and data.TrainingMachine.Level
	return math.clamp(cleanInt(lvl, Training.MaxLevel), 1, Training.MaxLevel)
end

function Training.NextMachineCost(level: number): number?
	local nextLv = Training.Levels[(level or 1) + 1]
	return nextLv and nextLv.UpgradeGold or nil
end

function Training.SpeedMultiplier(level: number): number
	local info = Training.Levels[math.clamp(math.floor(level or 1), 1, Training.MaxLevel)]
	return info and info.SpeedMult or 1
end

-- Valida e normaliza tabela de incremento desejado ({ HP = 20, Attack = 0, ... }).
-- Apenas multiplos de 20 que nao ultrapassem Training.Max (100).
function Training.ValidateTargets(member, rawTargets): ({ [string]: number }?, number, number, number, string?)
	if not member or typeof(rawTargets) ~= "table" then
		return nil, 0, 0, 0, "Pedido de treino inv\u{e1}lido."
	end
	local current = Genetics.SanitizeTable(member.Training)
	local clean = Training.ZeroOres()
	local selectedCount, totalSteps, maxSteps = 0, 0, 0
	for _, stat in ipairs(Training.Stats) do
		local raw = rawTargets[stat] or 0
		if typeof(raw) ~= "number" or raw ~= raw or raw < 0 or raw ~= math.floor(raw) then
			return nil, 0, 0, 0, "Quantidade inv\u{e1}lida."
		end
		if raw > 0 then
			if raw % Training.Step ~= 0 then
				return nil, 0, 0, 0, "O treino s\u{f3} pode ser feito de 20 em 20."
			end
			if current[stat] + raw > Training.Max then
				return nil, 0, 0, 0, string.format("%s j\u{e1} atingiu o m\u{e1}ximo (%d%%).", Genetics.StatLabels[stat].Name, Training.Max)
			end
			clean[stat] = raw
			local steps = raw // Training.Step
			selectedCount += 1
			totalSteps += steps
			if steps > maxSteps then
				maxSteps = steps
			end
		end
	end
	if selectedCount == 0 then
		return nil, 0, 0, 0, "Escolha pelo menos +20 em um atributo."
	end
	return clean, selectedCount, totalSteps, maxSteps, nil
end

-- Calcula custo em minerios para os incrementos validados (com raridade e taxa multi-atributo)
function Training.CalculateCost(rarity: string?, cleanTargets)
	local cost = Training.ZeroOres()
	local selectedCount = 0
	for _, stat in ipairs(Training.Stats) do
		if (cleanTargets[stat] or 0) > 0 then
			selectedCount += 1
		end
	end
	if selectedCount == 0 then
		return cost, 0, 1
	end
	local rMult = Training.RarityCostMult[rarity or "Comum"] or 1
	local mMult = Training.MultiStatCostMult[math.clamp(selectedCount, 1, 4)] or 1
	for _, stat in ipairs(Training.Stats) do
		local addVal = cleanTargets[stat] or 0
		if addVal > 0 then
			local steps = addVal // Training.Step
			local baseCost = Training.Ores[stat].BaseStepCost
			cost[stat] = math.max(1, math.ceil(baseCost * steps * rMult * mMult))
		end
	end
	return cost, selectedCount, mMult
end

-- Tempo total (em segundos) dentro da capsula:
-- 1 passo (+20) em Comum no Nv.1 = 60s; multiplos atributos rodam em paralelo (+20% por passo extra).
function Training.CalculateDuration(machineLevel: number, rarity: string?, cleanTargets): number
	local totalSteps, maxSteps = 0, 0
	for _, stat in ipairs(Training.Stats) do
		local steps = math.floor((cleanTargets[stat] or 0) / Training.Step)
		if steps > 0 then
			totalSteps += steps
			if steps > maxSteps then
				maxSteps = steps
			end
		end
	end
	if maxSteps <= 0 then
		return 0
	end
	local effectiveSteps = maxSteps + 0.20 * (totalSteps - maxSteps)
	local rTime = Training.RarityTimeMult[rarity or "Comum"] or 1
	local speed = Training.SpeedMultiplier(machineLevel)
	return math.max(5, math.floor(Training.BaseStepSeconds * effectiveSteps * rTime / speed + 0.5))
end

return Training
