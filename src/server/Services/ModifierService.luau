-- Lane modifiers: every Config.LaneModifiers.Interval seconds the server picks a new one for the whole alley
-- (Double Coins, Moving Pins, ...). Clients read it from Workspace attributes and show the banner and timer.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Modifiers = require(Shared.Modules.Modifiers)

local ModifierService = {}

-- The modifier running right now, or nil
function ModifierService.Current()
	return Modifiers.Current()
end

function ModifierService:Start()
	if Config.CoreLoop.Enabled then
		return -- (no lane modifiers in the Addendum 4 core loop: they change the 10-pin rack)
	end
	task.spawn(function()
		local previous = nil
		while true do
			local modifier = Modifiers.PickNext(previous)
			previous = modifier.Id
			Workspace:SetAttribute("LaneModifierEnds", Workspace:GetServerTimeNow() + Config.LaneModifiers.Interval)
			Workspace:SetAttribute("LaneModifier", modifier.Id)
			task.wait(Config.LaneModifiers.Interval)
		end
	end)
end

return ModifierService
