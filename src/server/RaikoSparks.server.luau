-- Coloca as faiscas do Raiko em toda peca cujo nome contem "Gauntlet" (manoplas).
local template = game:GetService("ReplicatedStorage"):WaitForChild("RaikoFX"):WaitForChild("Sparks")
local function attach(part)
	if part:IsA("BasePart") and part.Name:find("Gauntlet") and not part:FindFirstChild("Sparks") then
		template:Clone().Parent = part
	end
end
for _, d in ipairs(workspace:GetDescendants()) do attach(d) end
workspace.DescendantAdded:Connect(attach)
