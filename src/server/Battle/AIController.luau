-- Re-exporta ReplicatedStorage.Core.AIController para compatibilidade
local ReplicatedStorage = game:GetService("ReplicatedStorage")
return require(ReplicatedStorage:WaitForChild("Core"):WaitForChild("AIController"))
