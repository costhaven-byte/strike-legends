-- Looks up lane modifiers from Config.LaneModifiers. Used by both server and client.
-- The current modifier lives in Workspace attributes the server sets:
--   LaneModifier (an Id, or nothing) and LaneModifierEnds (server time when it ends).
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Parent.Config)

local Modifiers = {}

local byId = {}
for _, modifier in Config.LaneModifiers.List do
	byId[modifier.Id] = modifier
end

function Modifiers.Get(id: string?)
	return id and byId[id]
end

-- The modifier running right now, or nil
function Modifiers.Current()
	return byId[Workspace:GetAttribute("LaneModifier") or ""]
end

-- How far (studs, sideways) Moving Pins has slid the rack at a given server time.
-- Server and clients use the same clock, so the pins they see are where the server scores them.
function Modifiers.RackOffset(modifier, serverTime: number): number
	if not modifier or not modifier.PinSway then
		return 0
	end
	return modifier.PinSway * math.sin(serverTime / (modifier.SwayPeriod or 3) * math.pi * 2)
end

-- A random modifier by Weight, never the same one twice in a row
function Modifiers.PickNext(previousId: string?)
	local pool, total = {}, 0
	for _, modifier in Config.LaneModifiers.List do
		if modifier.Id ~= previousId or #Config.LaneModifiers.List == 1 then
			table.insert(pool, modifier)
			total += modifier.Weight or 1
		end
	end
	local roll = math.random() * total
	for _, modifier in pool do
		roll -= modifier.Weight or 1
		if roll <= 0 then
			return modifier
		end
	end
	return pool[#pool]
end

return Modifiers
