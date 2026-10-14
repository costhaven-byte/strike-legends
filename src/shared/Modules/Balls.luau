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

local traitsById = {}
for _, trait in Config.Traits do
	traitsById[trait.Id] = trait
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

function Balls.GetTrait(id: string?)
	return id and traitsById[id]
end

-- This ball's strength for a trait, or 0 if it doesn't have it
function Balls.TraitValue(ball, traitId: string): number
	return ball and ball.Traits and ball.Traits[traitId] or 0
end

-- The ball's traits in Config.Traits order: { { Trait = <row>, Value = number }, ... }
function Balls.GetTraits(ball)
	local list = {}
	for _, trait in Config.Traits do
		local value = Balls.TraitValue(ball, trait.Id)
		if value > 0 then
			table.insert(list, { Trait = trait, Value = value })
		end
	end
	return list
end

-- Fills a trait's Text or Short template with the ball's strength, e.g. "BLAST +2"
function Balls.FormatTrait(trait, value: number, short: boolean?): string
	local shown = math.floor(value * trait.Display + 0.5)
	return ((if short then trait.Short else trait.Text) :: string):format(tostring(shown))
end

-- All of a ball's traits: one line each, or short = the compact tile version on one line. Empty text if it has none.
-- rich = colour each trait with its own colour (for labels with RichText on).
function Balls.DescribeTraits(ball, short: boolean?, rich: boolean?): string
	local parts = {}
	for _, entry in Balls.GetTraits(ball) do
		local text = Balls.FormatTrait(entry.Trait, entry.Value, short)
		if not short then
			text = entry.Trait.Name:upper() .. ": " .. text
		end
		if rich then
			text = ('<font color="#%s">%s</font>'):format(entry.Trait.Color:ToHex(), text)
		end
		table.insert(parts, text)
	end
	return table.concat(parts, if short then " · " else "\n")
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
