-- DESATIVADO no mapa v2 (sem zonas de encontro). Guardado para a feature futura de captura.
-- Animacao parada dos personagens selvagens das zonas de encontro (so no cliente, REGRAS)
local CollectionService = game:GetService("CollectionService")

local function play(model: Instance)
	local hum = model:WaitForChild("Humanoid", 10)
	local animator = hum and hum:WaitForChild("Animator", 10)
	local folder = model:WaitForChild("Animations", 10)
	local idle = folder and folder:FindFirstChild("Idle")
	if not (animator and idle) then
		return
	end
	local ok, track = pcall(function()
		return animator:LoadAnimation(idle)
	end)
	if ok and track then
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Idle
		track:Play()
	end
end

CollectionService:GetInstanceAddedSignal("WildCharacter"):Connect(function(m)
	task.spawn(play, m)
end)
for _, m in CollectionService:GetTagged("WildCharacter") do
	task.spawn(play, m)
end
