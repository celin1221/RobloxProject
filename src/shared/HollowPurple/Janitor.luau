--!strict
--[[
	ReplicatedStorage/HollowPurple/Janitor.luau
	Utilitario leve estilo Janitor/Maid para rastreamento e limpeza absoluta de
	Instances, RBXScriptConnections, Tweens, threads (task.delay/spawn) e callbacks.
	Garante zero vazamento de memoria mesmo disparando 50+ vezes seguidas.
]]

export type Cleanable =
	Instance
	| RBXScriptConnection
	| Tween
	| thread
	| (() -> ())
	| { Destroy: (any) -> () }
	| { Cleanup: (any) -> () }

local Janitor = {}
Janitor.__index = Janitor

export type JanitorInstance = typeof(setmetatable(
	{} :: {
		_tasks: { Cleanable },
		_cleaned: boolean,
	},
	Janitor
))

function Janitor.new(): JanitorInstance
	return setmetatable({
		_tasks = {},
		_cleaned = false,
	}, Janitor)
end

local function cleanOne(item: Cleanable)
	local t = typeof(item)
	if t == "Instance" then
		local inst = item :: Instance
		if inst.Parent ~= nil then
			pcall(function()
				inst:Destroy()
			end)
		else
			pcall(function()
				inst:Destroy()
			end)
		end
	elseif t == "RBXScriptConnection" then
		local conn = item :: RBXScriptConnection
		if conn.Connected then
			conn:Disconnect()
		end
	elseif t == "function" then
		pcall(item :: () -> ())
	elseif t == "thread" then
		local th = item :: thread
		if coroutine.running() ~= th then
			pcall(task.cancel, th)
		end
	elseif t == "table" then
		local tbl = item :: any
		if typeof(tbl.Cancel) == "function" then
			pcall(function()
				tbl:Cancel()
			end)
		end
		if typeof(tbl.Cleanup) == "function" then
			pcall(function()
				tbl:Cleanup()
			end)
		elseif typeof(tbl.Destroy) == "function" then
			pcall(function()
				tbl:Destroy()
			end)
		end
	end
end

function Janitor.Add<T>(self: JanitorInstance, item: T): T
	if self._cleaned then
		cleanOne(item :: any)
		return item
	end
	if typeof(item) == "Instance" and (item :: Instance):IsA("Tween") then
		table.insert(self._tasks, function()
			pcall(function()
				(item :: Tween):Cancel()
			end)
			pcall(function()
				(item :: Tween):Destroy()
			end)
		end)
		return item
	end
	table.insert(self._tasks, item :: any)
	return item
end

function Janitor.Connect(self: JanitorInstance, signal: RBXScriptSignal, fn: (...any) -> ()): RBXScriptConnection
	local conn = signal:Connect(fn)
	return self:Add(conn)
end

function Janitor.Delay(self: JanitorInstance, seconds: number, fn: () -> ()): thread
	local th = task.delay(seconds, function()
		if not self._cleaned then
			fn()
		end
	end)
	return self:Add(th)
end

function Janitor.Spawn(self: JanitorInstance, fn: () -> ()): thread
	local th = task.spawn(function()
		if not self._cleaned then
			fn()
		end
	end)
	return self:Add(th)
end

function Janitor.IsCleaned(self: JanitorInstance): boolean
	return self._cleaned
end

function Janitor.Cleanup(self: JanitorInstance)
	if self._cleaned then
		return
	end
	self._cleaned = true
	local list = self._tasks
	self._tasks = {}
	-- Limpa na ordem inversa de criacao (callbacks de restauracao primeiro, containers por ultimo)
	for i = #list, 1, -1 do
		cleanOne(list[i])
	end
end

function Janitor.Destroy(self: JanitorInstance)
	self:Cleanup()
end

return Janitor
