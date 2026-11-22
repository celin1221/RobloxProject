--[[
	RefugeService (GDD secao 14 - Refugio)
	- Cada base tem uma caverna; so o dono entra e vai para o seu Refugio (area privada fora do mapa).
	- Selvagens surgem no campo pela tabela da Forja (raridade e nivel sorteados aqui), um a cada intervalo,
	  ate o maximo simultaneo. O contador corre com o jogador fora (ate o maximo).
	- Tocar ou clicar num selvagem abre batalha Wild na arena normal: fuga, Selos (formula da secao 7),
	  derrota da gold e XP, captura poe na colecao. Cada derrotado ou capturado tem 30% de deixar item no Bau.
	- Forja: melhoria com gemas + todos os requisitos, conferidos aqui com os dados do perfil.
	Tudo no servidor; o cliente so pede e mostra.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Data = ReplicatedStorage:WaitForChild("Data")
local Refuge = require(Data:WaitForChild("Refuge"))
local Characters = require(Data.Characters)
local Items = require(Data.Items)
local Summon = require(Data.Summon)
local Benefits = require(Data.Benefits)
local Base = require(Data.Base)
local Tower = require(Data.Tower)
local Encounters = require(Data.Encounters)
local Genetics = require(Data:WaitForChild("Genetics"))

local PlayerDataService = require(ServerScriptService:WaitForChild("Data"):WaitForChild("PlayerDataService"))
local ProgressionService = require(ServerScriptService.Data:WaitForChild("ProgressionService"))
local BattleService = require(ServerScriptService:WaitForChild("Battle"):WaitForChild("BattleService"))
local TowerService = require(ServerScriptService:WaitForChild("Tower"):WaitForChild("TowerService"))
local BaseService = require(ServerScriptService:WaitForChild("Economy"):WaitForChild("BaseService"))
local CharacterLibrary = require(ServerScriptService:WaitForChild("CharacterLibrary"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local RefugeService = {}

local MAX_TEAM = 6
local TICK = 2
local WALK_SPEED = 5
local clockOffset = 0 -- so testes no Studio
local rng = Random.new()
local busy = {}
local wildModels = {} -- [Player] = { [entryId] = Model }
local walkers = {} -- [Model] = { Field, Next, Moving }
local fighting = {} -- [Player] = entryId em batalha

local function now(): number
	return os.time() + clockOffset
end

local function notify(player: Player, text: string)
	Remotes.Notify:FireClient(player, text)
end

local function changed(player: Player, saveNow: boolean?)
	PlayerDataService.MarkChanged(player)
	if saveNow then
		task.spawn(PlayerDataService.SaveNow, player)
	end
end

local function refugeData(data)
	local r = data.Refuge
	if typeof(r) ~= "table" then
		r = { Forja = 1, WildDefeated = 0, Captures = 0, Bau = {}, Pending = {}, LastSpawn = 0, NextId = 1 }
		data.Refuge = r
	end
	r.Bau = r.Bau or {}
	r.Pending = r.Pending or {}
	return r
end

--------------------------------------------------------------------
-- Sorteio (raridade pela tabela da Forja, respeitando banners desbloqueados)
--------------------------------------------------------------------
local function rosterFor(unlockedBanners)
	local byRarity = {}
	local any = false
	for id, def in pairs(Characters.List) do
		if not def.Prototype then -- prototipos de teste nunca surgem no Refugio
			local anime = def.Anime
			local allowed = (not anime) or anime == "Generico" or (typeof(unlockedBanners) == "table" and unlockedBanners[anime] == true)
			if allowed then
				byRarity[def.Rarity] = byRarity[def.Rarity] or {}
				table.insert(byRarity[def.Rarity], id)
				any = true
			end
		end
	end
	if not any then
		-- Fallback seguro caso perfil legado nao tenha nenhum anime desbloqueado
		for id, def in pairs(Characters.List) do
			if not def.Prototype and (not def.Anime or def.Anime == "Generico") then
				byRarity[def.Rarity] = byRarity[def.Rarity] or {}
				table.insert(byRarity[def.Rarity], id)
			end
		end
	end
	for _, list in pairs(byRarity) do
		table.sort(list)
	end
	return byRarity
end

function RefugeService.RollRarity(level: number, r: Random): string
	local chances = Refuge.Levels[level].Chances
	local x = r:NextNumber() * 100
	local acc = 0
	for _, id in ipairs(Refuge.RarityOrder) do
		acc += chances[id] or 0
		if x < acc then
			return id
		end
	end
	return "Comum"
end

-- Retorna { CharacterId, Level, Rarity (sorteada), Genetics }
-- Respeita data.UnlockedBanners para nao vazar personagens de Ginasios ainda trancados!
function RefugeService.Roll(level: number, r: Random?, unlockedBanners)
	r = r or rng
	local info = Refuge.Levels[level]
	local rarity = RefugeService.RollRarity(level, r)
	local lists = rosterFor(unlockedBanners)
	local idx = table.find(Refuge.RarityOrder, rarity) or 1
	local charId
	-- sem personagem da raridade no pool liberado: cai para raridade abaixo mais proxima (ou sobe se so houver acima)
	for i = idx, 1, -1 do
		local list = lists[Refuge.RarityOrder[i]]
		if list and #list > 0 then
			charId = list[r:NextInteger(1, #list)]
			break
		end
	end
	if not charId then
		for i = idx + 1, #Refuge.RarityOrder do
			local list = lists[Refuge.RarityOrder[i]]
			if list and #list > 0 then
				charId = list[r:NextInteger(1, #list)]
				break
			end
		end
	end
	local actualDef = charId and Characters.Get(charId)
	return {
		CharacterId = charId,
		Level = r:NextInteger(info.MinLevel, info.MaxLevel),
		Rarity = rarity,
		Genetics = Genetics.Roll(actualDef and actualDef.Rarity or rarity, r),
	}
end

--------------------------------------------------------------------
-- Surgimento (com o jogador fora tambem, ate o maximo)
--------------------------------------------------------------------
local function accrue(data): number
	local r = refugeData(data)
	local info = Refuge.Levels[r.Forja] or Refuge.Levels[1]
	local t = now()
	if (r.LastSpawn or 0) <= 0 or r.LastSpawn > t + 5 then
		-- primeiro acesso: ja deixa 2 selvagens prontos para acao imediata no Refugio
		local initialCount = math.min(2, info.Max)
		r.LastSpawn = t - info.Interval * initialCount
	end
	if #r.Pending >= info.Max then
		r.LastSpawn = t -- cheio: o contador fica parado no maximo
		return 0
	end
	local n = math.floor((t - r.LastSpawn) / info.Interval)
	if n <= 0 then
		return 0
	end
	local add = math.min(n, info.Max - #r.Pending)
	for _ = 1, add do
		local roll = RefugeService.Roll(r.Forja, nil, data.UnlockedBanners)
		if roll.CharacterId then
			table.insert(r.Pending, { Id = r.NextId, CharacterId = roll.CharacterId, Level = roll.Level, Rarity = roll.Rarity, Genetics = roll.Genetics })
			r.NextId += 1
		end
	end
	if #r.Pending >= info.Max then
		r.LastSpawn = t
	else
		r.LastSpawn += n * info.Interval
	end
	return add
end
RefugeService.Accrue = accrue

local function nextSpawnIn(data): number?
	local r = refugeData(data)
	local info = Refuge.Levels[r.Forja]
	if #r.Pending >= info.Max then
		return nil
	end
	return math.max(0, info.Interval - (now() - r.LastSpawn))
end

--------------------------------------------------------------------
-- Areas
--------------------------------------------------------------------
local function plotOf(player: Player): Model?
	return BaseService.PlotOf(player)
end

local function refugeModel(id: number): Model?
	local folder = workspace:FindFirstChild("Refugios")
	return folder and folder:FindFirstChild(string.format("Refugio%02d", id))
end

local function refugeOf(player: Player): Model?
	local plot = plotOf(player)
	return plot and refugeModel(plot:GetAttribute("PlotId"))
end
RefugeService.RefugeOf = refugeOf

-- Em qual Refugio esta este ponto (id ou nil)
local function refugeAt(pos: Vector3): number?
	local folder = workspace:FindFirstChild("Refugios")
	if not folder then
		return nil
	end
	for _, m in ipairs(folder:GetChildren()) do
		local c = m:GetAttribute("Center")
		local h = (m:GetAttribute("Half") or 40) + 6
		if c and math.abs(pos.X - c.X) <= h and math.abs(pos.Z - c.Z) <= h and pos.Y < c.Y + 120 then
			return m:GetAttribute("RefugeId")
		end
	end
	return nil
end
RefugeService.RefugeAt = refugeAt

local function inOwnRefuge(player: Player): boolean
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local plot = plotOf(player)
	return root ~= nil and plot ~= nil and refugeAt(root.Position) == plot:GetAttribute("PlotId")
end

-- Visual da Forja pelo nivel (troca nos niveis 4, 7 e 10)
local FIRE_TEX = "rbxassetid://93633042519778"
local function decorateForge(model: Model)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p:GetAttribute("Label") == "Fire" then
			local l = Instance.new("PointLight")
			l.Name = "Luz"
			l.Color = Color3.fromRGB(255, 140, 60)
			l.Range = 18
			l.Brightness = 2
			l.Shadows = false
			l.Parent = p
			CollectionService:AddTag(l, "MapFx")
			CollectionService:AddTag(p, "Lanterna")
			local a = Instance.new("Attachment")
			a.Name = "Fx"
			a.Parent = p
			local e = Instance.new("ParticleEmitter")
			e.Name = "Brasas"
			e.Texture = FIRE_TEX
			e.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 90, 40))
			e.LightEmission = 1
			e.Rate = 6
			e.Lifetime = NumberRange.new(1, 1.8)
			e.Speed = NumberRange.new(3, 6)
			e.SpreadAngle = Vector2.new(25, 25)
			e.EmissionDirection = Enum.NormalId.Top
			e.Acceleration = Vector3.new(0, 2, 0)
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
			e.Transparency = NumberSequence.new(0, 1)
			e.Parent = a
			CollectionService:AddTag(e, "MapFx")
		end
	end
end

local function setForgeLook(refuge: Model, level: number)
	local want = Refuge.ForgeModel(level)
	local old = refuge:FindFirstChild("Forja")
	if old and old:GetAttribute("Look") == want and old:GetAttribute("Decorated") then
		return
	end
	local kit = ServerStorage:FindFirstChild("MapaV2Kit")
	local src = kit and kit:FindFirstChild(want)
	if not src then
		return
	end
	local pivot = old and old:GetPivot()
	local m = src:Clone()
	m.Name = "Forja"
	m:SetAttribute("Look", want)
	m:SetAttribute("Decorated", true)
	if pivot then
		m:PivotTo(pivot)
	end
	decorateForge(m)
	if old then
		old:Destroy()
	end
	m.Parent = refuge
end

local function bauCount(r): number
	return #r.Bau
end

local function updateBau(player: Player)
	local refuge = refugeOf(player)
	local data = PlayerDataService.Get(player)
	if refuge and data then
		local r = refugeData(data)
		local bau = refuge:FindFirstChild("Bau")
		if bau then
			bau:SetAttribute("Count", bauCount(r))
			bau:SetAttribute("Capacity", Refuge.BauCapacity(r.Forja))
		end
		refuge:SetAttribute("OwnerUserId", player.UserId)
		refuge:SetAttribute("ForjaLevel", r.Forja)
	end
end

--------------------------------------------------------------------
-- Selvagens no campo
--------------------------------------------------------------------
local startWild

local function fieldOf(refuge: Model): BasePart?
	return refuge and refuge:FindFirstChild("Field")
end

local function groundCFrame(model: Model, pos: Vector3, look: Vector3?): CFrame
	local root = model:FindFirstChild("HumanoidRootPart")
	local hum = model:FindFirstChildOfClass("Humanoid")
	local y = 8 + (hum and hum.HipHeight or 2) + (root and root.Size.Y / 2 or 1)
	local p = Vector3.new(pos.X, y, pos.Z)
	local target = if look then Vector3.new(look.X, y, look.Z) else p + Vector3.new(0, 0, -1)
	if (target - p).Magnitude < 0.01 then
		target = p + Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(p, target)
end

local function randomFieldPoint(field: BasePart): Vector3
	local hx, hz = field.Size.X / 2 - 2, field.Size.Z / 2 - 2
	return (field.CFrame * CFrame.new(rng:NextNumber(-hx, hx), 0, rng:NextNumber(-hz, hz))).Position
end

local function spawnModel(player: Player, refuge: Model, entry)
	local def = Characters.Get(entry.CharacterId)
	if not def then
		return nil
	end
	local field = fieldOf(refuge)
	local model = CharacterLibrary.Spawn(def.ModelName, nil, nil)
	model.Name = def.Name
	local root = model:FindFirstChild("HumanoidRootPart")
	root.Anchored = true
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	root.CanTouch = true
	model:PivotTo(groundCFrame(model, randomFieldPoint(field), nil))
	model:SetAttribute("EntryId", entry.Id)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("CharacterId", entry.CharacterId)
	model:SetAttribute("Level", entry.Level)
	model:SetAttribute("Rarity", def.Rarity)
	-- nome, nivel e raridade
	local head = model:FindFirstChild("Head") or root
	local bb = Instance.new("BillboardGui")
	bb.Name = "WildTag"
	bb.Size = UDim2.fromOffset(170, 46)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.MaxDistance = 70
	bb.Parent = head
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextStrokeTransparency = 0.2
	t.TextColor3 = Summon.RarityColor[def.Rarity] or Color3.new(1, 1, 1)
	t.Text = string.format("%s  Nv. %d\n%s selvagem", def.Name, entry.Level, Summon.RarityName[def.Rarity] or def.Rarity)
	t.Parent = bb
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WildPrompt"
	prompt.ActionText = "Enfrentar"
	prompt.ObjectText = def.Name .. " Nv. " .. entry.Level
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(p)
		startWild(p, entry.Id)
	end)
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 40
	click.Parent = root
	click.MouseClick:Connect(function(p)
		startWild(p, entry.Id)
	end)
	local touchDebounce = 0
	root.Touched:Connect(function(hit)
		if os.clock() < touchDebounce then
			return
		end
		local p = Players:GetPlayerFromCharacter(hit.Parent)
		if p then
			touchDebounce = os.clock() + 1
			startWild(p, entry.Id)
		end
	end)
	CollectionService:AddTag(model, "RefugeWild")
	model.Parent = refuge:FindFirstChild("Wild")
	walkers[model] = { Field = field, Next = os.clock() + rng:NextNumber(0.5, 2), Moving = false }
	return model
end

-- Deixa no campo exatamente os pendentes (menos o que esta em batalha)
local function syncWild(player: Player)
	local data = PlayerDataService.Get(player)
	local refuge = refugeOf(player)
	if not data or not refuge then
		return
	end
	local r = refugeData(data)
	local models = wildModels[player] or {}
	wildModels[player] = models
	local want = {}
	for _, e in ipairs(r.Pending) do
		want[e.Id] = e
	end
	for id, m in pairs(models) do
		if not want[id] or not m.Parent and fighting[player] ~= id then
			walkers[m] = nil
			m:Destroy()
			models[id] = nil
		end
	end
	for id, e in pairs(want) do
		if not models[id] and fighting[player] ~= id then
			models[id] = spawnModel(player, refuge, e)
		end
	end
end
RefugeService.SyncWild = syncWild

local function clearWild(player: Player)
	for _, m in pairs(wildModels[player] or {}) do
		walkers[m] = nil
		m:Destroy()
	end
	wildModels[player] = nil
end

-- Desempenho: o cliente anda liso (NpcWalkClient); o servidor acerta a posicao 2 vezes por segundo
local WALK_SYNC = 0.5
local function walkStep()
	local t = os.clock()
	for model, w in pairs(walkers) do
		local root = model:FindFirstChild("HumanoidRootPart")
		if w.Moving then
			-- termina o passo mesmo fora do campo (em batalha), para voltar no lugar certo
			local a = (t - w.Start) / w.Dur
			if a >= 1 then
				if root then
					root.CFrame = w.To
				end
				w.Moving = false
				w.Next = t + rng:NextNumber(1.5, 4)
				model:SetAttribute("Moving", false)
			elseif root and model.Parent and t - w.Synced >= WALK_SYNC then
				w.Synced = t
				root.CFrame = w.From:Lerp(w.To, a)
			end
		elseif not model.Parent then
			if model:GetAttribute("EntryId") == nil then
				walkers[model] = nil
			end
		elseif t >= w.Next and w.Field and w.Field.Parent and root then
			local goal = groundCFrame(model, randomFieldPoint(w.Field), nil)
			local from = root.Position
			local face = CFrame.lookAt(from, Vector3.new(goal.X, from.Y, goal.Z))
			local dur = math.max(0.5, (goal.Position - from).Magnitude / WALK_SPEED)
			root.CFrame = face
			w.From, w.To, w.Start, w.Dur, w.Synced = face, face.Rotation + goal.Position, t, dur, t
			w.Moving = true
			model:SetAttribute("WalkFrom", w.From)
			model:SetAttribute("WalkTo", w.To)
			model:SetAttribute("WalkDur", dur)
			model:SetAttribute("WalkT0", workspace:GetServerTimeNow())
			model:SetAttribute("Moving", true)
		end
	end
end

--------------------------------------------------------------------
-- Entrar e sair
--------------------------------------------------------------------
local function teleportTo(player: Player, cf: CFrame)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	pcall(function()
		player:RequestStreamAroundAsync(cf.Position, 5)
	end)
	char:PivotTo(cf + Vector3.new(0, 3, 0))
	root.Anchored = false
	return true
end

function RefugeService.Enter(player: Player, plot: Model?)
	local own = plotOf(player)
	if not own or (plot and plot ~= own) or (plot and plot:GetAttribute("OwnerUserId") ~= player.UserId) then
		return false, "S\u{f3} o dono da base pode entrar neste Ref\u{fa}gio."
	end
	if BattleService.IsInBattle(player) or TowerService.IsRunning(player) then
		return false, "N\u{e3}o d\u{e1} durante a batalha."
	end
	local data = PlayerDataService.Get(player)
	local refuge = refugeModel(own:GetAttribute("PlotId"))
	if not data or not refuge then
		return false, "Ref\u{fa}gio indispon\u{ed}vel."
	end
	accrue(data)
	setForgeLook(refuge, refugeData(data).Forja)
	updateBau(player)
	syncWild(player)
	teleportTo(player, refuge.SpawnPoint.CFrame)
	player:SetAttribute("InRefuge", own:GetAttribute("PlotId"))
	return true
end

function RefugeService.Leave(player: Player)
	player:SetAttribute("InRefuge", nil)
	return BaseService.TeleportHome(player)
end

--------------------------------------------------------------------
-- Batalha contra selvagem
--------------------------------------------------------------------
local function rollDrop(r)
	if rng:NextNumber() >= Refuge.DropChance then
		return nil
	end
	if bauCount(r) >= Refuge.BauCapacity(r.Forja) then
		return "full"
	end
	local pool = Refuge.DropPool(r.Forja)
	local id = pool[rng:NextInteger(1, #pool)]
	local qty = if id == "Ore" then rng:NextInteger(Refuge.OreMin, Refuge.OreMax) else 1
	table.insert(r.Bau, { Id = id, Qty = qty })
	return id, qty
end
RefugeService.RollDrop = rollDrop

-- Doce de XP: sorteio separado do item do Bau; no maximo 1 por selvagem.
-- Um numero so, do mais raro para o mais comum: Epico 1%, Raro 4%, Comum 12% (17% de chance de algum doce).
function RefugeService.RollCandyId(r: Random?): string?
	local x = (r or rng):NextNumber()
	local acc = 0
	for _, c in ipairs(Items.Candies) do
		acc += c.Chance
		if x < acc then
			return c.Id
		end
	end
	return nil
end

local function rollCandy(r)
	local id = RefugeService.RollCandyId()
	if not id then
		return nil
	end
	if bauCount(r) >= Refuge.BauCapacity(r.Forja) then
		return "full"
	end
	table.insert(r.Bau, { Id = id, Qty = 1 })
	return id
end
RefugeService.RollCandy = rollCandy

local function itemName(id: string): string
	if id == "Ore" then
		return "Min\u{e9}rio"
	end
	local it = Items.Get(id)
	return it and it.Name or id
end

local function removePending(r, entryId)
	for i, e in ipairs(r.Pending) do
		if e.Id == entryId then
			table.remove(r.Pending, i)
			return e
		end
	end
	return nil
end

startWild = function(player: Player, entryId)
	if busy[player] or fighting[player] then
		return false
	end
	local data = PlayerDataService.Get(player)
	if not data or not data.StarterChosen then
		return false
	end
	if not inOwnRefuge(player) then
		return false
	end
	if BattleService.IsInBattle(player) or TowerService.IsRunning(player) then
		return false
	end
	local r = refugeData(data)
	local entry
	for _, e in ipairs(r.Pending) do
		if e.Id == entryId then
			entry = e
		end
	end
	if not entry then
		return false
	end
	local team, reason = ProgressionService.TeamFor(player)
	if not team then
		notify(player, reason or "Monte um time primeiro.")
		return false
	end
	busy[player] = true
	local model = wildModels[player] and wildModels[player][entryId]
	fighting[player] = entryId
	if model then
		model.Parent = nil -- some do campo durante a batalha
	end
	local def = Characters.Get(entry.CharacterId)
	if not Genetics.HasAllKeys(entry.Genetics) then
		entry.Genetics = Genetics.Roll(def and def.Rarity or entry.Rarity or "Comum", rng)
	end
	local outcome = nil
	local ok = BattleService.StartBattle(player, {
		EnemyTeam = { {
			CharacterId = entry.CharacterId,
			Level = entry.Level,
			Genetics = entry.Genetics,
			Training = Genetics.ZeroTable(),
			StatMultipliers = Genetics.MultipliersFor(entry.Genetics, nil),
		} },
		EnemyAI = Encounters.AI,
		Mode = "Wild",
		CaptureBlocked = if Benefits.CollectionCount(data) >= Benefits.CollectionMax(data) then "Dep\u{f3}sito de personagens cheio (" .. Benefits.CollectionMax(data) .. "). Venda ou funda repetidos." else nil,
		Intro = { "Um " .. def.Name .. " selvagem (" .. (Summon.RarityName[def.Rarity] or def.Rarity) .. ", n\u{ed}vel " .. entry.Level .. ") apareceu no Ref\u{fa}gio!" },
		KeepPlayer = true,
		OnEnd = function(battle, result)
			local lines = {}
			local profile = PlayerDataService.Get(player)
			if not profile then
				return lines
			end
			local rr = refugeData(profile)
			if battle.Captured then
				local toTeam = #profile.Team < MAX_TEAM
				local _, albumLines = ProgressionService.AddCharacter(player, battle.Captured.CharacterId, battle.Captured.Level, toTeam, nil, battle.Captured.Genetics)
				table.insert(lines, def.Name .. " entrou para " .. (if toTeam then "o seu time." else "a sua cole\u{e7}\u{e3}o."))
				for _, l in ipairs(albumLines or {}) do
					table.insert(lines, l)
				end
				rr.Captures += 1
				outcome = "Captured"
			elseif result == "Win" then
				local gold = Refuge.GoldPerLevel * entry.Level
				profile.Gold += gold
				table.insert(lines, "+" .. gold .. " gold.")
				rr.WildDefeated += 1
				outcome = "Defeated"
			end
			if outcome then
				removePending(rr, entryId)
				local id, qty = rollDrop(rr)
				local candy = rollCandy(rr)
				if id == "full" or candy == "full" then
					table.insert(lines, "O Ba\u{fa} est\u{e1} cheio: colete para receber itens.")
				end
				if id and id ~= "full" then
					table.insert(lines, "Algo caiu no Ba\u{fa}: " .. (if qty > 1 then qty .. " de " else "") .. itemName(id) .. "!")
				end
				if candy and candy ~= "full" then
					table.insert(lines, "Um " .. itemName(candy) .. " caiu no Ba\u{fa}!")
				end
			end
			changed(player, true)
			return lines
		end,
		OnClosed = function(result)
			fighting[player] = nil
			busy[player] = nil
			local refuge = refugeOf(player)
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root and result ~= "Cancelled" and refuge then
				teleportTo(player, refuge.SpawnPoint.CFrame)
			elseif root then
				root.Anchored = false
			end
			if outcome and model then
				walkers[model] = nil
				model:Destroy()
				if wildModels[player] then
					wildModels[player][entryId] = nil
				end
			elseif model and refuge then
				model.Parent = refuge:FindFirstChild("Wild")
			end
			updateBau(player)
			syncWild(player)
		end,
	})
	if not ok then
		fighting[player] = nil
		busy[player] = nil
		local refuge = refugeOf(player)
		if model and refuge then
			model.Parent = refuge:FindFirstChild("Wild")
		end
	end
	return ok
end
RefugeService.StartWild = startWild

--------------------------------------------------------------------
-- Forja: requisitos e melhoria
--------------------------------------------------------------------
local function towerRank(mode: string): number
	return table.find(Tower.Order, mode) or 0
end

-- Progresso de um requisito: tem, precisa (aceita Torre 1x1 ou 2x2 + Insignias de Ginasio)
function RefugeService.Progress(data, req): (number, number)
	local r = refugeData(data)
	if req.Kind == "TowerWin" then
		-- vencer um modo (1x1 ou 2x2) libera o seguinte
		local bestRank = math.max(
			towerRank(data.Tower and data.Tower.Unlocked or "Facil"),
			towerRank(data.Tower2x2 and data.Tower2x2.Unlocked or "Facil")
		)
		local won = bestRank > towerRank(req.Mode)
		return if won then 1 else 0, 1
	elseif req.Kind == "WildDefeated" then
		return r.WildDefeated, req.Count
	elseif req.Kind == "Captures" then
		return r.Captures, req.Count
	elseif req.Kind == "CharLevel" then
		local n = 0
		for _, m in pairs(data.Collection) do
			if (m.Level or 1) >= req.Level then
				n += 1
			end
		end
		return n, req.Count
	elseif req.Kind == "InfinitoFloor" then
		local bestFloor = math.max(
			(data.Tower and data.Tower.BestInfiniteFloor) or 0,
			(data.Tower2x2 and data.Tower2x2.BestInfiniteFloor) or 0
		)
		return bestFloor, req.Floor
	elseif req.Kind == "Stars" then
		local n = 0
		for _, m in pairs(data.Collection) do
			if (m.Stars or 0) >= req.Stars then
				n += 1
			end
		end
		return n, req.Count
	elseif req.Kind == "LegendaryLevel" then
		for _, m in pairs(data.Collection) do
			local def = Characters.Get(m.CharacterId)
			if def and def.Rarity == "Lendario" and (m.Level or 1) >= req.Level then
				return 1, 1
			end
		end
		return 0, 1
	elseif req.Kind == "GymBadges" then
		local n = 0
		for _, cleared in pairs(data.GymsCleared or {}) do
			if cleared == true then
				n += 1
			end
		end
		return n, req.Count
	end
	return 0, 1
end

function RefugeService.State(player: Player)
	local data = PlayerDataService.Get(player)
	if not data then
		return nil
	end
	accrue(data)
	local r = refugeData(data)
	local L = r.Forja
	local nextUp = Refuge.Upgrades[L + 1]
	local reqs, all = {}, nextUp ~= nil
	if nextUp then
		for _, req in ipairs(nextUp.Req) do
			local have, need = RefugeService.Progress(data, req)
			local done = have >= need
			all = all and done
			table.insert(reqs, { Text = Refuge.ReqText(req), Have = math.min(have, need), Need = need, Done = done })
		end
	end
	local bau = {}
	for _, e in ipairs(r.Bau) do
		table.insert(bau, { Id = e.Id, Name = itemName(e.Id), Qty = e.Qty })
	end
	return {
		Level = L,
		MaxLevel = Refuge.MaxLevel,
		Info = Refuge.Levels[L],
		Next = Refuge.Levels[L + 1],
		Cost = nextUp and nextUp.Gems,
		Gems = data.Gems,
		Reqs = reqs,
		CanUpgrade = all and nextUp ~= nil and data.Gems >= nextUp.Gems,
		ReqsDone = all,
		Bau = bau,
		BauCount = #r.Bau,
		BauCap = Refuge.BauCapacity(L),
		Pending = #r.Pending,
		NextSpawnIn = nextSpawnIn(data),
		WildDefeated = r.WildDefeated,
		Captures = r.Captures,
	}
end

function RefugeService.Upgrade(player: Player)
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Dados ainda carregando."
	end
	local r = refugeData(data)
	local nextUp = Refuge.Upgrades[r.Forja + 1]
	if not nextUp then
		return false, "A Forja j\u{e1} est\u{e1} no n\u{ed}vel m\u{e1}ximo."
	end
	for _, req in ipairs(nextUp.Req) do
		local have, need = RefugeService.Progress(data, req)
		if have < need then
			return false, "Falta: " .. Refuge.ReqText(req) .. " (" .. math.min(have, need) .. "/" .. need .. ")."
		end
	end
	if data.Gems < nextUp.Gems then
		return false, "Gemas insuficientes (precisa de " .. nextUp.Gems .. ")."
	end
	accrue(data) -- fecha o contador no nivel antigo
	data.Gems -= nextUp.Gems
	r.Forja += 1
	changed(player, true)
	local refuge = refugeOf(player)
	if refuge then
		setForgeLook(refuge, r.Forja)
	end
	updateBau(player)
	Remotes.RefugeFx:FireClient(player, "Upgrade", r.Forja)
	return true, "Forja melhorada para o n\u{ed}vel " .. r.Forja .. "!"
end

-- Coleta tudo do Bau (o que nao cabe fica)
function RefugeService.Collect(player: Player)
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Dados ainda carregando."
	end
	local r = refugeData(data)
	if #r.Bau == 0 then
		return false, "O Ba\u{fa} est\u{e1} vazio."
	end
	local slots = Benefits.BagSlots(data, Items.BagSlots)
	local got, left = {}, {}
	for _, e in ipairs(r.Bau) do
		local take = 0
		if e.Id == "Ore" then
			take = math.min(e.Qty, math.max(0, Base.OreMax - data.Ore))
			data.Ore += take
		elseif Items.Get(e.Id) then
			take = math.min(e.Qty, Items.SpaceFor(data.Bag, e.Id, slots))
			if take > 0 then
				data.Bag[e.Id] = (data.Bag[e.Id] or 0) + take
			end
		end
		if take > 0 then
			got[e.Id] = (got[e.Id] or 0) + take
		end
		if take < e.Qty then
			table.insert(left, { Id = e.Id, Qty = e.Qty - take })
		end
	end
	r.Bau = left
	changed(player, true)
	updateBau(player)
	local parts = {}
	for id, n in pairs(got) do
		table.insert(parts, n .. "x " .. itemName(id))
	end
	table.sort(parts)
	if #parts == 0 then
		return false, "Mochila ou dep\u{f3}sito cheio: nada coube."
	end
	local text = "Coletou: " .. table.concat(parts, ", ") .. "."
	if #left > 0 then
		text ..= " " .. #left .. " item(ns) n\u{e3}o couberam e ficaram no Ba\u{fa}."
	end
	return true, text
end

--------------------------------------------------------------------
-- Testes (so no Studio)
--------------------------------------------------------------------
function RefugeService.Dev(player: Player, cmd: string, ...)
	if not RunService:IsStudio() then
		return nil
	end
	local data = player and PlayerDataService.Get(player)
	local r = data and refugeData(data)
	if cmd == "set" then
		for k, v in pairs((...)) do
			r[k] = v
		end
		changed(player)
		local refuge = refugeOf(player)
		if refuge then
			setForgeLook(refuge, r.Forja)
		end
		updateBau(player)
		syncWild(player)
		return true
	elseif cmd == "force" then
		-- prepara requisitos de teste: torre, andar do Infinito, estrelas e gemas
		local f = (...)
		if f.Unlocked then
			data.Tower.Unlocked = f.Unlocked
		end
		if f.BestFloor then
			data.Tower.BestInfiniteFloor = f.BestFloor
		end
		if f.Gems then
			data.Gems = f.Gems
		end
		if f.Stars then
			local _, m = next(data.Collection)
			if m then
				m.Stars = math.max(m.Stars or 0, f.Stars)
			end
		end
		if f.Legend then
			-- o elenco ainda nao tem Lendario: marca um personagem como Lendario so neste servidor de teste
			local def = Characters.Get(f.Legend)
			if def then
				def.Rarity = "Lendario"
			end
			for _, m in pairs(data.Collection) do
				if m.CharacterId == f.Legend then
					m.Level = 50
					break
				end
			end
		end
		changed(player)
		return true
	elseif cmd == "get" then
		return r
	elseif cmd == "state" then
		return RefugeService.State(player)
	elseif cmd == "simulate" then
		-- n sorteios por nivel: contagem por raridade sorteada e faixa de nivel
		local n = (...)
		local out = {}
		local sim = Random.new(12345)
		for level = 1, Refuge.MaxLevel do
			local counts = { Comum = 0, Raro = 0, Epico = 0, Lendario = 0 }
			local lo, hi = math.huge, -math.huge
			for _ = 1, n do
				local roll = RefugeService.Roll(level, sim)
				counts[roll.Rarity] += 1
				lo = math.min(lo, roll.Level)
				hi = math.max(hi, roll.Level)
			end
			out[level] = { Counts = counts, MinLevel = lo, MaxLevel = hi }
		end
		return out
	elseif cmd == "clock" then
		clockOffset += (...)
		local added = accrue(data)
		changed(player)
		syncWild(player)
		return { Added = added, Pending = #r.Pending, Offset = clockOffset }
	elseif cmd == "start" then
		local e = r.Pending[(...) or 1]
		return e and startWild(player, e.Id)
	elseif cmd == "drop" then
		return rollDrop(r)
	elseif cmd == "candysim" then
		local n = (...)
		local sim = Random.new(777)
		local counts = { DoceComum = 0, DoceRaro = 0, DoceEpico = 0, Nenhum = 0 }
		for _ = 1, n do
			local id = RefugeService.RollCandyId(sim)
			counts[id or "Nenhum"] += 1
		end
		return counts
	elseif cmd == "enter" then
		return RefugeService.Enter(player, (...))
	elseif cmd == "upgrade" then
		return RefugeService.Upgrade(player)
	elseif cmd == "collect" then
		return RefugeService.Collect(player)
	end
	return nil
end

--------------------------------------------------------------------
local function guarded(fn)
	return function(player, ...)
		if busy[player] then
			return false, "Aguarde."
		end
		busy[player] = true
		local ok, a, b = pcall(fn, player, ...)
		busy[player] = nil
		if not ok then
			warn("[Refugio] " .. tostring(a))
			return false, "Erro no servidor."
		end
		return a, b
	end
end

local function ensureRemote(name: string, class: string)
	local r = Remotes:FindFirstChild(name)
	if not r then
		r = Instance.new(class)
		r.Name = name
		r.Parent = Remotes
	end
	return r
end

-- Caverna de cada base: prompt para o dono entrar
local function setupCaves()
	for _, plot in ipairs(workspace:WaitForChild("Plots"):GetChildren()) do
		local cave = plot:FindFirstChild("Cave")
		if cave and not cave:FindFirstChild("CavePoint") then
			local cf, size = cave:GetBoundingBox()
			local look = plot:FindFirstChild("Floor") and (plot.Floor.Position - cf.Position) * Vector3.new(1, 0, 1)
			local p = Instance.new("Part")
			p.Name = "CavePoint"
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Transparency = 1
			p.Size = Vector3.new(1, 1, 1)
			p.CFrame = CFrame.new(cf.Position.X, 11, cf.Position.Z) + (if look and look.Magnitude > 0 then look.Unit * (size.Z / 2) else Vector3.zero)
			p.Parent = cave
			local pr = Instance.new("ProximityPrompt")
			pr.Name = "RefugioPrompt"
			pr.ActionText = "Entrar no Ref\u{fa}gio"
			pr.ObjectText = "Caverna"
			pr.HoldDuration = 0
			pr.MaxActivationDistance = 12
			pr.RequiresLineOfSight = false
			pr.Parent = p
			pr.Triggered:Connect(function(player)
				local ok, text = RefugeService.Enter(player, plot)
				if not ok and text then
					notify(player, text)
				end
			end)
		end
	end
end

local function setupExits()
	for _, refuge in ipairs(workspace:WaitForChild("Refugios"):GetChildren()) do
		local ep = refuge:FindFirstChild("ExitPoint")
		local pr = ep and ep:FindFirstChild("ExitPrompt")
		if pr then
			pr.Triggered:Connect(function(player)
				if refugeAt(ep.Position) == player:GetAttribute("InRefuge") or inOwnRefuge(player) then
					RefugeService.Leave(player)
				end
			end)
		end
	end
end

-- Ninguem fica no Refugio de outro jogador (teleporte, queda, exploit): volta para a propria base
local function guardStep()
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and not BattleService.IsInBattle(player) then
			local id = refugeAt(root.Position)
			local plot = plotOf(player)
			local mine = plot and plot:GetAttribute("PlotId")
			if id and id ~= mine then
				player:SetAttribute("InRefuge", nil)
				if not (plot and BaseService.TeleportHome(player)) then
					BattleService.ReturnToPlaza(player)
				end
				notify(player, "Esse Ref\u{fa}gio n\u{e3}o \u{e9} seu.")
			elseif not id and player:GetAttribute("InRefuge") then
				player:SetAttribute("InRefuge", nil)
			end
		end
	end
end

local function onLoaded(player: Player)
	local data = PlayerDataService.Get(player)
	if not data then
		return
	end
	-- espera o terreno ser atribuido (BaseService)
	for _ = 1, 20 do
		if plotOf(player) then
			break
		end
		task.wait(0.25)
	end
	accrue(data)
	changed(player)
	local refuge = refugeOf(player)
	if refuge then
		setForgeLook(refuge, refugeData(data).Forja)
	end
	updateBau(player)
	syncWild(player)
end

function RefugeService.Init()
	ensureRemote("RefugeState", "RemoteFunction").OnServerInvoke = function(player)
		return RefugeService.State(player)
	end
	ensureRemote("RefugeUpgrade", "RemoteFunction").OnServerInvoke = guarded(RefugeService.Upgrade)
	ensureRemote("RefugeCollect", "RemoteFunction").OnServerInvoke = guarded(RefugeService.Collect)
	ensureRemote("RefugeFx", "RemoteEvent")

	setupCaves()
	setupExits()

	PlayerDataService.Loaded:Connect(function(p)
		task.spawn(onLoaded, p)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		if PlayerDataService.Get(p) then
			task.spawn(onLoaded, p)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		local refuge = refugeOf(player)
		clearWild(player)
		if refuge then
			refuge:SetAttribute("OwnerUserId", 0)
			local bau = refuge:FindFirstChild("Bau")
			if bau then
				bau:SetAttribute("Count", 0)
			end
			setForgeLook(refuge, 1)
		end
		busy[player] = nil
		fighting[player] = nil
	end)

	-- surgimento com o jogador online
	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = PlayerDataService.Get(player)
				if data and accrue(data) > 0 then
					changed(player)
					syncWild(player)
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			walkStep()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			guardStep()
		end
	end)
end

return RefugeService
