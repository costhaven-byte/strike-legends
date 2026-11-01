-- Server entry point: loads every ModuleScript in Services and starts it.
local Services = script:WaitForChild("Services")

-- Addendum 5 A3: the one shared rooftop lane is built before any service looks for lanes
require(script:WaitForChild("Modules"):WaitForChild("SharedLane")).Build()

for _, module in Services:GetChildren() do
	if module:IsA("ModuleScript") then
		local service = require(module)
		if type(service) == "table" and service.Start then
			task.spawn(service.Start, service)
		end
	end
end

print("[Strike Legends] Server started")
