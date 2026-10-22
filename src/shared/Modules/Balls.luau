-- Looks up balls, rarities and crates from the tables in Config. Used by both server and client.
local Config = require(script.Parent.Parent.Config)
local Zones = require(script.Parent.Zones)

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

-- Phase X Part 4: a rarity a crate has no balls of gives its odds to the nearest rarity that has some (a tie goes
-- to the commoner one), so every crate's odds only point at balls it can really give
for _, crate in Config.Crates do
	local has = {}
	for _, ball in Config.Balls do
		if Zones.BallInCrate(ball, crate) then
			has[rarityIndex[ball.Rarity] or 1] = true
		end
	end
	local odds = {}
	for name, percent in crate.Odds do
		local index = rarityIndex[name] or 1
		local target = nil
		for distance = 0, #Config.Rarities do
			if has[index - distance] then
				target = index - distance
				break
			elseif has[index + distance] then
				target = index + distance
				break
			end
		end
		if target then
			local targetName = Config.Rarities[target].Name
			odds[targetName] = (odds[targetName] or 0) + percent
		end
	end
	crate.Odds = odds
end

-- Every crate ball must sit inside its zone's rarity range (Config.ZoneRarity): say so in Output if one doesn't
for _, ball in Config.Balls do
	if
		ball.Zone
		and ball.InCrates ~= false
		and not ball.Retired
		and not Zones.RarityAllowed(ball.Zone, ball.Rarity)
	then
		warn(("[Balls] %s is %s, outside zone %d's range (Config.ZoneRarity)"):format(ball.Id, ball.Rarity, ball.Zone))
	end
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

-- What this crate costs a player who has bought cratesBought crates with coins so far: the first
-- Config.Onboarding.FirstCrateGoal crate is cheaper (Config.Onboarding.FirstCratePrice), every other one is the normal price
function Balls.CratePrice(crate, cratesBought: number?): number
	local onboard = Config.Onboarding
	if (cratesBought or 0) == 0 and crate.Id == onboard.FirstCrateGoal and onboard.FirstCratePrice then
		return math.min(onboard.FirstCratePrice, crate.Price)
	end
	return crate.Price
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

-- Gems for this ball's next Polish level (nil once it's fully polished). See Config.Economy.Polish.GemPrice
function Balls.PolishGemPrice(ball, polishLevel: number?): number?
	local level = (polishLevel or 0) + 1
	if level > POLISH.MaxLevel then
		return nil
	end
	return (POLISH.GemPrice[ball.Rarity] or POLISH.GemPrice.Common) * level
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
			if ball.Rarity == rarity.Name and Zones.BallInCrate(ball, crate) then
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
