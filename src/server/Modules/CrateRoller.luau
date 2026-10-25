-- Picks which ball a crate gives, using the crate's odds and the pity rules. Pure math, no side effects.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local Store = require(Shared.Modules.Store)
local Zones = require(Shared.Modules.Zones)

local CrateRoller = {}

-- Rolls a rarity from the crate's odds, only counting rarities at or above minIndex.
-- If the crate has nothing that rare (a guarantee above its best rarity), its best rarity is used.
-- odds: the crate's odds, with the player's luck already applied (Store.LuckyOdds)
local function rollRarity(crate, odds: { [string]: number }, minIndex: number): string
	local best = 1
	for index, rarity in Config.Rarities do
		if (odds[rarity.Name] or 0) > 0 then
			best = index
		end
	end
	minIndex = math.min(minIndex, best)

	local total = 0
	for index, rarity in Config.Rarities do
		if index >= minIndex then
			total += odds[rarity.Name] or 0
		end
	end
	local roll = math.random() * total
	for index, rarity in Config.Rarities do
		local chance = odds[rarity.Name] or 0
		if index >= minIndex and chance > 0 then
			roll -= chance
			if roll <= 0 then
				return rarity.Name
			end
		end
	end
	return Config.Rarities[best].Name
end

-- pity: the player's pity counts for this crate ({ Basic_Rare = 3 }) BEFORE this pull (Balls.PityRows keys).
-- minRarity: optional, this roll gives at least this rarity (the first crate ever).
-- exactRarity: optional, this roll gives exactly this rarity, odds and pity aside (the first bought crate, the gift).
-- luck: optional, the player's luck from the LUCKY game passes (1 = none, Store.LuckyOdds).
-- Returns the ball, the new counts for this crate's pity rows, and true if a pity guarantee decided it.
function CrateRoller.Roll(crate, pity: { [string]: number }, minRarity: string?, exactRarity: string?, luck: number?)
	local baseIndex = if minRarity then Balls.RarityIndex(minRarity) else 1
	local minIndex = baseIndex
	local rows = Balls.PityRows(crate.Id)
	-- A guarantee kicks in when this pull would be number After in a row without that rarity
	for _, row in rows do
		if (pity[row.Key] or 0) + 1 >= row.After then
			minIndex = math.max(minIndex, Balls.RarityIndex(row.Rarity))
		end
	end

	local rarity = exactRarity or rollRarity(crate, Store.LuckyOdds(crate.Odds, luck or 1), minIndex)
	if exactRarity then
		minIndex = baseIndex -- not a pity pull
	end
	local pool = {}
	for _, ball in Config.Balls do
		if ball.Rarity == rarity and Zones.BallInCrate(ball, crate) then
			table.insert(pool, ball)
		end
	end
	if #pool == 0 then
		-- This crate has no ball of that rarity (a guarantee above its pool): its best ball instead
		for _, other in Config.Balls do
			if
				Zones.BallInCrate(other, crate)
				and (#pool == 0 or Balls.RarityIndex(other.Rarity) > Balls.RarityIndex(pool[1].Rarity))
			then
				pool = { other }
			end
		end
		rarity = pool[1].Rarity
	end
	local ball = Balls.PickFromPool(pool, crate) -- this week's featured ball is likelier (Config.Featured)

	local got = Balls.RarityIndex(rarity)
	local newCounts = {}
	for _, row in rows do
		newCounts[row.Key] = if got >= Balls.RarityIndex(row.Rarity) then 0 else (pity[row.Key] or 0) + 1
	end
	return ball, newCounts, minIndex > baseIndex
end

return CrateRoller
