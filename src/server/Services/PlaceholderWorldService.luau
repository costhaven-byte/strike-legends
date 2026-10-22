-- Builds the Phase X placeholder world pieces (server/Modules/PlaceholderWorld) that aren't saved in the place yet,
-- as soon as the server starts, so the zone 3 and 4 stands, booths, cases, helipad and boss arena always exist.
-- Pieces saved in Studio under the same names are left alone.
local PlaceholderWorld = require(script.Parent.Parent.Modules.PlaceholderWorld)

local PlaceholderWorldService = {}

function PlaceholderWorldService:Start()
	local built = PlaceholderWorld.Build()
	if #built > 0 then
		print("[PlaceholderWorldService] built placeholders: " .. table.concat(built, ", "))
	end
end

return PlaceholderWorldService
