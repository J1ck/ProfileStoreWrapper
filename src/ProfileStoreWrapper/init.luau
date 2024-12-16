local RunService = game:GetService("RunService")

if RunService:IsClient() then
	local Module = script:WaitForChild("Client")
	
	return require(Module)
else
	local Module = script:WaitForChild("Server")
	Module.Parent = game:GetService("ServerStorage")
	
	return require(Module)
end