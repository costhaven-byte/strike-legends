-- Looks up balls, rarities and crates from the tables in Config. Used by both server and client.
local Config = require(script.Parent.Parent.Config)

local Balls = {}

local ballsById = {}
for _, ball in Config.Balls do
	ballsById[ball.Id] = ball
end

local rarityIndex = {}
for index, rarity in Config.Rarities do
	rarityIndex[rarity.Name] = index
end

local cratesById = {}
for _, crate in Config.Crates do
	cratesById[crate.Id] = crate
end

function Balls.Get(id: string?)
	return id and ballsById[id]
end

-- Rarity table for a name, e.g. Balls.GetRarity("Epic").Color
function Balls.GetRarity(name: string)
	return Config.Rarities[rarityIndex[name] or 1]
end

-- 1 = Common ... 6 = Mythic
function Balls.RarityIndex(name: string): number
	return rarityIndex[name] or 1
end

function Balls.GetCrate(id: string?)
	return id and cratesById[id]
end

-- Every ball, best first (highest rarity, then highest multiplier)
function Balls.Sorted()
	local list = table.clone(Config.Balls)
	table.sort(list, function(a, b)
		local ra, rb = rarityIndex[a.Rarity], rarityIndex[b.Rarity]
		if ra ~= rb then
			return ra > rb
		end
		return a.Multiplier > b.Multiplier
	end)
	return list
end

-- The server sends owned balls as "Rookie,Galaxy,..." in a Player attribute
function Balls.EncodeOwned(owned: { [string]: boolean }): string
	local ids = {}
	for id in owned do
		table.insert(ids, id)
	end
	table.sort(ids)
	return table.concat(ids, ",")
end

function Balls.DecodeOwned(text: string?): { [string]: boolean }
	local owned = {}
	for id in (text or ""):gmatch("[^,]+") do
		owned[id] = true
	end
	return owned
end

return Balls
