-- Client entry point: loads every ModuleScript in Controllers and starts it.
local Controllers = script:WaitForChild("Controllers")

for _, module in Controllers:GetChildren() do
	if module:IsA("ModuleScript") then
		local controller = require(module)
		if type(controller) == "table" and controller.Start then
			task.spawn(controller.Start, controller)
		end
	end
end

print("[Strike Legends] Client started")
