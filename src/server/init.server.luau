-- Server entry point: loads every ModuleScript in Services and starts it.
local Services = script:WaitForChild("Services")

for _, module in Services:GetChildren() do
	if module:IsA("ModuleScript") then
		local service = require(module)
		if type(service) == "table" and service.Start then
			task.spawn(service.Start, service)
		end
	end
end

print("[Strike Legends] Server started")
