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
	-- While gems are off (Config.Gems), traits that pay gems use their coin wording instead
	if not Config.Gems.Enabled and trait.NoGemsText then
		trait.Name = trait.NoGemsName or trait.Name
		trait.Text = trait.NoGemsText
		trait.Short = trait.NoGemsShort or trait.Short
		trait.Popup = trait.NoGemsPopup or trait.Popup
	end
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

-- Polish (Config.Economy.Polish): duplicates give a ball Polish Points; every PointsPerLevel points = one level
local POLISH = Config.Economy.Polish

function Balls.PolishLevel(points: number?): number
	return math.min(math.floor((points or 0) / POLISH.PointsPerLevel), POLISH.MaxLevel)
end

-- The ball's coin multiplier with its Polish level on top (+5% of the ball's own Multiplier per level)
function Balls.Multiplier(ball, polishLevel: number?): number
	return ball.Multiplier * (1 + POLISH.ValuePerLevel * (polishLevel or 0))
end

-- The server sends Polish Points as "Galaxy:3,Rookie:1" in a Player attribute
function Balls.EncodePolish(polish: { [string]: number }): string
	local parts = {}
	for id, points in polish do
		table.insert(parts, id .. ":" .. points)
	end
	table.sort(parts)
	return table.concat(parts, ",")
end

function Balls.DecodePolish(text: string?): { [string]: number }
	local polish = {}
	for id, points in (text or ""):gmatch("([^,:]+):(%d+)") do
		polish[id] = tonumber(points)
	end
	return polish
end

-- Pity per crate: the rows of Config.Economy.CratePity that count for this crate, each with its save key
-- ("Basic_Rare"). Clients see the count as the Player attribute "Pity_" .. Key.
function Balls.PityRows(crateId: string)
	local rows = {}
	for _, row in Config.Economy.CratePity do
		if row.Crates[crateId] then
			table.insert(rows, { Rarity = row.Rarity, After = row.After, Key = crateId .. "_" .. row.Rarity })
		end
	end
	return rows
end

-- Each ball's real chance (percent) in a crate: rarity odds shared equally by the balls of that rarity
function Balls.CrateBallOdds(crate): { { Ball: any, Chance: number } }
	local list = {}
	for _, rarity in Config.Rarities do
		local pool = {}
		for _, ball in Config.Balls do
			if ball.Rarity == rarity.Name and ball.InCrates ~= false then
				table.insert(pool, ball)
			end
		end
		local odds = crate.Odds[rarity.Name] or 0
		if odds > 0 then
			for _, ball in pool do
				table.insert(list, { Ball = ball, Chance = odds / #pool })
			end
		end
	end
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
