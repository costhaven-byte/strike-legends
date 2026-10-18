-- Picks which ball a crate gives, using the crate's odds and the pity rules. Pure math, no side effects.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)

local CrateRoller = {}

-- Rolls a rarity from the crate's odds, only counting rarities at or above minIndex.
local function rollRarity(crate, minIndex: number): string
	local total = 0
	for index, rarity in Config.Rarities do
		if index >= minIndex then
			total += crate.Odds[rarity.Name] or 0
		end
	end
	local roll = math.random() * total
	for index, rarity in Config.Rarities do
		if index >= minIndex then
			roll -= crate.Odds[rarity.Name] or 0
			if roll <= 0 then
				return rarity.Name
			end
		end
	end
	return Config.Rarities[#Config.Rarities].Name
end

-- counters: the player's pity counters ({ CratesSinceRare = 3, ... }) BEFORE this crate.
-- minRarity: optional, this roll gives at least this rarity (the first-3-minutes gift crate).
-- Returns the ball and the new counter values.
function CrateRoller.Roll(crate, counters: { [string]: number }, minRarity: string?)
	-- A pity kicks in when this crate would be number N in a row without that rarity
	local minIndex = if minRarity then Balls.RarityIndex(minRarity) else 1
	for _, pity in Config.Pity do
		if (counters[pity.Counter] or 0) + 1 >= pity.Crates then
			minIndex = math.max(minIndex, Balls.RarityIndex(pity.Rarity))
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
	local newCounters = {}
	for _, pity in Config.Pity do
		newCounters[pity.Counter] = if got >= Balls.RarityIndex(pity.Rarity)
			then 0
			else (counters[pity.Counter] or 0) + 1
	end
	return ball, newCounters, minIndex > 1 and not minRarity
end

return CrateRoller
