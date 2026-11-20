-- Re-exporta ReplicatedStorage.Core.DamageCalc para compatibilidade
local ReplicatedStorage = game:GetService("ReplicatedStorage")
return require(ReplicatedStorage:WaitForChild("Core"):WaitForChild("DamageCalc"))
