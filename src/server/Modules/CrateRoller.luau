-- Picks which ball a crate gives, using the crate's odds and the pity rules. Pure math, no side effects.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)

local CrateRoller = {}

-- Rolls a rarity from the crate's odds, only counting rarities at or above minIndex.
-- If the crate has nothing that rare (a guarantee above its best rarity), its best rarity is used.
local function rollRarity(crate, minIndex: number): string
	local best = 1
	for index, rarity in Config.Rarities do
		if (crate.Odds[rarity.Name] or 0) > 0 then
			best = index
		end
	end
	minIndex = math.min(minIndex, best)

	local total = 0
	for index, rarity in Config.Rarities do
		if index >= minIndex then
			total += crate.Odds[rarity.Name] or 0
		end
	end
	local roll = math.random() * total
	for index, rarity in Config.Rarities do
		local odds = crate.Odds[rarity.Name] or 0
		if index >= minIndex and odds > 0 then
			roll -= odds
			if roll <= 0 then
				return rarity.Name
			end
		end
	end
	return Config.Rarities[best].Name
end

-- pity: the player's pity counts for this crate ({ Basic_Rare = 3 }) BEFORE this pull (Balls.PityRows keys).
-- minRarity: optional, this roll gives at least this rarity (the first crate ever, the gift crate).
-- Returns the ball, the new counts for this crate's pity rows, and true if a pity guarantee decided it.
function CrateRoller.Roll(crate, pity: { [string]: number }, minRarity: string?)
	local baseIndex = if minRarity then Balls.RarityIndex(minRarity) else 1
	local minIndex = baseIndex
	local rows = Balls.PityRows(crate.Id)
	-- A guarantee kicks in when this pull would be number After in a row without that rarity
	for _, row in rows do
		if (pity[row.Key] or 0) + 1 >= row.After then
			minIndex = math.max(minIndex, Balls.RarityIndex(row.Rarity))
		end
	end

	local rarity = rollRarity(crate, minIndex)
	local pool = {}
	for _, ball in Config.Balls do
		if ball.Rarity == rarity and ball.InCrates ~= false then
			table.insert(pool, ball)
		end
	end
	local ball = pool[math.random(#pool)]

	local got = Balls.RarityIndex(rarity)
	local newCounts = {}
	for _, row in rows do
		newCounts[row.Key] = if got >= Balls.RarityIndex(row.Rarity) then 0 else (pity[row.Key] or 0) + 1
	end
	return ball, newCounts, minIndex > baseIndex
end

return CrateRoller
