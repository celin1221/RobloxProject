--[[
	LeaderboardMain (GDD secao 3 - Placares)
	Dois rankings globais em OrderedDataStore: mais gold e maior andar da torre (Infinito).
	A cada 3 minutos grava o valor de quem esta online e redesenha os 2 paineis da praca
	(posicao, nome e valor; top 3 em destaque).
]]
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataService = require(ServerScriptService:WaitForChild("Data"):WaitForChild("PlayerDataService"))

local INTERVAL = 180
local TOP = 10
local BOARDS = {
	{ Store = "Ranking_Gold_v1", Model = "PlacarGold", Value = function(d) return d.Gold or 0 end, Suffix = "" },
	{ Store = "Ranking_Torre_v1", Model = "PlacarTorre", Value = function(d) return d.Tower and d.Tower.BestInfiniteFloor or 0 end, Suffix = "" },
}

local names = {}
local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local p = Players:GetPlayerByUserId(userId)
	if p then
		names[userId] = p.DisplayName
		return p.DisplayName
	end
	local ok, n = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	if ok and n then
		names[userId] = n
		return n
	end
	return "Jogador " .. userId
end

local function fmt(n: number): string
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", ""))
end

local function draw(board, entries)
	local folder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Leaderboards")
	local model = folder and folder:FindFirstChild(board.Model)
	local list = model and model:FindFirstChild("Screen") and model.Screen.Board.Bg.List
	if not list then
		return
	end
	for i = 1, TOP do
		local row = list:FindFirstChild("Row" .. i)
		local e = entries[i]
		if row then
			row:FindFirstChild("Name").Text = if e then nameOf(e.key) else "\u{2014}"
			row:FindFirstChild("Value").Text = if e then fmt(e.value) .. board.Suffix else ""
		end
	end
end

local stores = {}
for _, b in ipairs(BOARDS) do
	local ok, s = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, b.Store)
	stores[b] = ok and s or nil
end

local function cycle()
	for _, b in ipairs(BOARDS) do
		local store = stores[b]
		if store then
			for _, p in ipairs(Players:GetPlayers()) do
				local d = PlayerDataService.Get(p)
				if d then
					local v = math.max(0, math.floor(b.Value(d)))
					pcall(store.SetAsync, store, tostring(p.UserId), v)
				end
			end
			local ok, pages = pcall(store.GetSortedAsync, store, false, TOP)
			if ok and pages then
				local entries = {}
				for _, e in ipairs(pages:GetCurrentPage()) do
					table.insert(entries, { key = tonumber(e.key) or 0, value = e.value })
				end
				draw(b, entries)
			else
				warn("[Placar] nao foi possivel ler " .. b.Store)
			end
		end
	end
end

task.wait(8) -- deixa os perfis carregarem
while true do
	cycle()
	task.wait(INTERVAL)
end
