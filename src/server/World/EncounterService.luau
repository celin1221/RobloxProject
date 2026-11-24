--[[
	EncounterService (GDD secoes 3, 4, 5 e 7)
	- 4 zonas de encontro (Workspace/Map/EncounterZones) com personagens selvagens visiveis.
	- Raridade do selvagem pela chance em encontro da secao 4; personagem sorteado do elenco.
	  Sem personagem daquela raridade no elenco, vem um da raridade abaixo mais proxima.
	- Chegar perto e apertar "Enfrentar" abre uma batalha 1x1 no modo Wild: fuga permitida,
	  Selos funcionam (formula da secao 7 em Characters.CaptureChance).
	- A mochila usada e a mochila salva do jogador; o que for gasto sai do perfil (ProgressionService.WriteBack).
	- Capturado entra na colecao (time se houver vaga) e o perfil e salvo na hora.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

local Data = ReplicatedStorage:WaitForChild("Data")
local Characters = require(Data.Characters)
local Encounters = require(Data.Encounters)
local Summon = require(Data.Summon)
local Benefits = require(Data.Benefits)
local Genetics = require(Data:WaitForChild("Genetics"))

local BattleService = require(ServerScriptService:WaitForChild("Battle"):WaitForChild("BattleService"))
local CharacterLibrary = require(ServerScriptService:WaitForChild("CharacterLibrary"))
local PlayerDataService = require(ServerScriptService:WaitForChild("Data"):WaitForChild("PlayerDataService"))
local ProgressionService = require(ServerScriptService.Data:WaitForChild("ProgressionService"))
local TowerService = require(ServerScriptService:WaitForChild("Tower"):WaitForChild("TowerService"))

local EncounterService = {}

local MAX_TEAM = 6
local rng = Random.new()
local wild = {} -- [Model] = { Zone, CharacterId, Level, Rarity, Busy }

local function zoneFolder(zoneId: string)
	return workspace.Map.EncounterZones:FindFirstChild(zoneId)
end

-- Raridade pela chance em encontro (secao 4) e personagem do elenco
local function rollWild()
	local r = rng:NextNumber()
	local acc, rarity = 0, "Comum"
	for _, id in ipairs(Summon.RarityOrder) do
		acc += Characters.Rarities[id].EncounterChance
		if r < acc then
			rarity = id
			break
		end
	end
	local byRarity = {}
	for id, def in pairs(Characters.List) do
		if not def.Prototype then
			byRarity[def.Rarity] = byRarity[def.Rarity] or {}
			table.insert(byRarity[def.Rarity], id)
		end
	end
	local idx = table.find(Summon.RarityOrder, rarity) or 1
	for i = idx, 1, -1 do
		local list = byRarity[Summon.RarityOrder[i]]
		if list and #list > 0 then
			table.sort(list)
			return list[rng:NextInteger(1, #list)], rarity
		end
	end
	return nil, rarity
end
EncounterService.RollWild = rollWild

local startEncounter

local function spawnWild(zone)
	local folder = zoneFolder(zone.Id)
	if not folder then
		return
	end
	local charId = rollWild()
	if not charId then
		return
	end
	local def = Characters.Get(charId)
	local level = rng:NextInteger(zone.MinLevel, zone.MaxLevel)
	-- ponto livre dentro da zona
	local pos
	for _ = 1, 12 do
		local a = rng:NextNumber() * math.pi * 2
		local r = math.sqrt(rng:NextNumber()) * (zone.Radius - 5)
		local p = zone.Center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local ok = true
		for m, info in pairs(wild) do
			if info.Zone == zone and m.PrimaryPart and (m.PrimaryPart.Position - p) * Vector3.new(1, 0, 1) ~= Vector3.zero and ((m.PrimaryPart.Position - p) * Vector3.new(1, 0, 1)).Magnitude < 8 then
				ok = false
			end
		end
		if ok then
			pos = p
			break
		end
	end
	pos = pos or zone.Center
	local model = CharacterLibrary.Spawn(def.ModelName, nil, nil)
	model.Name = def.ModelName
	local root = model:FindFirstChild("HumanoidRootPart")
	root.Anchored = true
	local hum = model:FindFirstChildOfClass("Humanoid")
	local gy = folder:GetAttribute("GroundY") or 0
	local y = gy + (hum and hum.HipHeight or 2) + root.Size.Y / 2
	model:PivotTo(CFrame.new(pos.X, y, pos.Z) * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0))
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	model:SetAttribute("CharacterId", charId)
	model:SetAttribute("Level", level)
	model:SetAttribute("Rarity", def.Rarity)
	-- nome, nivel e raridade
	local head = model:FindFirstChild("Head") or root
	local bb = Instance.new("BillboardGui")
	bb.Name = "WildTag"
	bb.Size = UDim2.fromOffset(160, 44)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.MaxDistance = 60
	bb.AlwaysOnTop = true
	bb.Parent = head
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.TextStrokeTransparency = 0.3
	t.TextColor3 = Summon.RarityColor[def.Rarity] or Color3.new(1, 1, 1)
	t.Text = string.format("%s  Nv. %d\n%s selvagem", def.Name, level, Summon.RarityName[def.Rarity] or def.Rarity)
	t.Parent = bb
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WildPrompt"
	prompt.ActionText = "Enfrentar"
	prompt.ObjectText = def.Name .. " Nv. " .. level
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	local genetics = Genetics.Roll(def.Rarity, rng)
	wild[model] = { Zone = zone, CharacterId = charId, Level = level, Rarity = def.Rarity, Genetics = genetics, Busy = false, Folder = folder.Wild }
	CollectionService:AddTag(model, "WildCharacter")
	prompt.Triggered:Connect(function(player)
		startEncounter(player, model)
	end)
	model.Parent = folder.Wild
	return model
end

local function removeWild(model: Model, respawn: boolean)
	local info = wild[model]
	wild[model] = nil
	model:Destroy()
	if respawn and info then
		task.delay(Encounters.RespawnTime, spawnWild, info.Zone)
	end
end

local function cleanBag(bag)
	local out = {}
	for id, n in pairs(bag) do
		if typeof(n) == "number" and n > 0 then
			out[id] = math.floor(n)
		end
	end
	return out
end

startEncounter = function(player: Player, model: Model)
	local info = wild[model]
	if not info or info.Busy then
		return
	end
	local data = PlayerDataService.Get(player)
	if not data or not data.StarterChosen then
		return
	end
	if BattleService.IsInBattle(player) or TowerService.IsRunning(player) then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local team, reason = ProgressionService.TeamFor(player)
	if not team then
		ReplicatedStorage.Remotes.Notify:FireClient(player, reason)
		return
	end
	info.Busy = true
	local returnTo = character:GetPivot()
	model.Parent = nil -- some da zona enquanto a batalha acontece
	local def = Characters.Get(info.CharacterId)
	local ok = BattleService.StartBattle(player, {
		EnemyTeam = { {
			CharacterId = info.CharacterId,
			Level = info.Level,
			Genetics = info.Genetics,
			Training = Genetics.ZeroTable(),
			StatMultipliers = Genetics.MultipliersFor(info.Genetics, nil),
		} },
		EnemyAI = Encounters.AI,
		Mode = "Wild",
		-- deposito de personagens cheio: selos recusados (secao 9, Deposito Ampliado)
		CaptureBlocked = if Benefits.CollectionCount(data) >= Benefits.CollectionMax(data) then "Dep\u{f3}sito de personagens cheio (" .. Benefits.CollectionMax(data) .. "). Venda ou funda repetidos." else nil,
		Intro = { "Um " .. def.Name .. " selvagem (" .. (Summon.RarityName[def.Rarity] or def.Rarity) .. ", n\u{ed}vel " .. info.Level .. ") apareceu!" },
		KeepPlayer = true,
		OnEnd = function(battle, result)
			local lines = {}
			local profile = PlayerDataService.Get(player)
			if not profile then
				return lines
			end
			if battle.Captured then
				local toTeam = #profile.Team < MAX_TEAM
				local _, albumLines = ProgressionService.AddCharacter(player, battle.Captured.CharacterId, battle.Captured.Level, toTeam, nil, battle.Captured.Genetics, { Source = "Capture" })
				table.insert(lines, def.Name .. " entrou para " .. (if toTeam then "o seu time." else "a sua cole\u{e7}\u{e3}o (base)."))
				for _, l in ipairs(albumLines or {}) do
					table.insert(lines, l)
				end
				info.Outcome = "Captured"
			elseif result == "Win" then
				info.Outcome = "Defeated"
			else
				info.Outcome = result
			end
			PlayerDataService.MarkChanged(player)
			task.spawn(PlayerDataService.SaveNow, player)
			return lines
		end,
		OnClosed = function(result)
			-- devolve o jogador onde estava
			local char = player.Character
			local r = char and char:FindFirstChild("HumanoidRootPart")
			if r and result ~= "Cancelled" then
				char:PivotTo(returnTo)
			end
			if r then
				r.Anchored = false
			end
			if info.Outcome == "Captured" or info.Outcome == "Defeated" then
				removeWild(model, true)
			else
				info.Busy = false
				info.Outcome = nil
				model.Parent = info.Folder
			end
		end,
	})
	if not ok then
		info.Busy = false
		model.Parent = info.Folder
	end
end

function EncounterService.Init()
	for _, zone in ipairs(Encounters.Zones) do
		for _ = 1, zone.Spawns do
			spawnWild(zone)
		end
	end
end

return EncounterService
