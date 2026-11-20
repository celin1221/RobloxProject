-- Relogio das mecanicas de retorno (login, baus, missoes, temporada, eventos).
-- O adiantamento so existe no Studio (ponte de teste); no jogo publicado e sempre os.time().
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Clock = {}
local offset = 0

function Clock.Now(): number
	return os.time() + offset
end

function Clock.Advance(seconds: number): number
	if not RunService:IsStudio() then
		return offset
	end
	offset += seconds
	ReplicatedStorage:SetAttribute("RetentionOffset", offset) -- o cliente mostra o dia certo
	return offset
end

function Clock.Offset(): number
	return offset
end

return Clock
