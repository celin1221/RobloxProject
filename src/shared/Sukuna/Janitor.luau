--!strict
--[[
	ReplicatedStorage/Sukuna/Janitor.luau
	Gerenciador de ciclo de vida e limpeza deterministica para todos os efeitos,
	conexoes, tweens, threads e estados globais (Camera, Lighting, Sky e Atmosphere)
	do Ryomen Sukuna e do Santuario Malevolente.
]]

local Lighting = game:GetService("Lighting")

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

local function cleanSingle(item: Cleanable)
	local kind = typeof(item)
	if kind == "Instance" then
		local inst = item :: Instance
		pcall(function()
			inst:Destroy()
		end)
	elseif kind == "RBXScriptConnection" then
		local conn = item :: RBXScriptConnection
		if conn.Connected then
			conn:Disconnect()
		end
	elseif kind == "function" then
		pcall(item :: () -> ())
	elseif kind == "thread" then
		local th = item :: thread
		if coroutine.running() ~= th then
			pcall(task.cancel, th)
		end
	elseif kind == "table" then
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
		cleanSingle(item :: any)
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
	return self:Add(signal:Connect(fn))
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

-- Captura e garante restauracao exata de Lighting, Atmosphere e Sky pre-existentes
function Janitor.SnapshotLighting(self: JanitorInstance)
	local snapAmbient = Lighting.Ambient
	local snapOutdoor = Lighting.OutdoorAmbient
	local snapBrightness = Lighting.Brightness
	local snapExposure = Lighting.ExposureCompensation
	local snapShiftTop = Lighting.ColorShift_Top
	local snapShiftBottom = Lighting.ColorShift_Bottom
	local snapClockTime = Lighting.ClockTime

	local existingAtmos = Lighting:FindFirstChildOfClass("Atmosphere")
	local atmosState = if existingAtmos
		then {
			Density = existingAtmos.Density,
			Offset = existingAtmos.Offset,
			Color = existingAtmos.Color,
			Decay = existingAtmos.Decay,
			Glare = existingAtmos.Glare,
			Haze = existingAtmos.Haze,
		}
		else nil

	local existingSky = Lighting:FindFirstChildOfClass("Sky")
	local savedSkyParent = if existingSky then existingSky.Parent else nil

	self:Add(function()
		Lighting.Ambient = snapAmbient
		Lighting.OutdoorAmbient = snapOutdoor
		Lighting.Brightness = snapBrightness
		Lighting.ExposureCompensation = snapExposure
		Lighting.ColorShift_Top = snapShiftTop
		Lighting.ColorShift_Bottom = snapShiftBottom
		Lighting.ClockTime = snapClockTime

		if existingAtmos and atmosState and existingAtmos.Parent then
			existingAtmos.Density = atmosState.Density
			existingAtmos.Offset = atmosState.Offset
			existingAtmos.Color = atmosState.Color
			existingAtmos.Decay = atmosState.Decay
			existingAtmos.Glare = atmosState.Glare
			existingAtmos.Haze = atmosState.Haze
		end
		if existingSky and savedSkyParent then
			existingSky.Parent = savedSkyParent
		end
	end)

	return existingAtmos, existingSky
end

function Janitor.IsCleaned(self: JanitorInstance): boolean
	return self._cleaned
end

function Janitor.Cleanup(self: JanitorInstance)
	if self._cleaned then
		return
	end
	self._cleaned = true
	local tasks = self._tasks
	self._tasks = {}
	for i = #tasks, 1, -1 do
		cleanSingle(tasks[i])
	end
end

function Janitor.Destroy(self: JanitorInstance)
	self:Cleanup()
end

return Janitor
