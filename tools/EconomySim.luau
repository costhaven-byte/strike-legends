-- Economy simulator. Plays pretend players on the numbers in Config and prints when they reach each Power Level,
-- rank level, zone, crate, egg and rebirth, checked against Config.Economy.Timeline.
-- Never runs in the game. To use it, paste this in Studio's command bar (edit mode, not play mode):
--   require(game.ServerStorage.Tools.EconomySim).Run()
-- Economy pass E1 (2026-10-25): plays the LIVE rules, not the old plan's formula:
--   pins     a PERFECT knocks all 10; any other throw knocks fewer, never more than the Power Level's Power
--   coins    pins x Config.Rewards.BaseCoinsPerPin x zone CoinPay x every MultiplierService multiplier
--            (Power Level, ball + Polish, pets, potion, rank tier, rebirth, streak, lane modifier, Golden Pin),
--            PERFECT x2 (Rewards.PerfectStrikeBonus)
--   xp       pins x Rewards.XpPerPin (a PERFECT: Rewards.PerfectStrikeXp) x zone XpPay x streak x pets x potion x rebirth
--   ranks    rank levels 1-60 (Config.Economy.Ranks); the rank tier (Config.Ranks, 6 levels each) sets the coin
--            multiplier; rank trials are assumed passed straight away
--   zones    open by rebirths (Config.Economy.Zones Rebirths, built zones only; owner 2026-10-27); the player
--            always bowls in the newest zone. A rebirth resets coins, Power Level and rank level + XP (batch D1,
--            owner 2026-10-29 "full reset"); level rewards still pay once ever
--   crates   only the crates of open zones (Config.Crates), each gives only its zone's balls (Zones.BallInCrate),
--            odds moved like Shared.Modules.Balls does, pity, first bought crate 1,000 + Uncommon, gift crate
--   eggs     only eggs with pets, in open zones; hatch odds like MascotService (only rarities the egg has);
--            pet bonus like Mascots.Bonus; equip best; 3 copies merge into a Shiny
--   extras   level rewards + the 3-strike challenge (Config.Milestones), the zone 4 boss (Config.Boss), playtime
--            gifts (Config.Playtime, potions drunk at once), a free crate every Config.FreeCrates throws, day 1's
--            daily reward, one daily spin
-- Not simulated: overcharge gambles, Blast/Curve/Heavy/Lucky traits, gems and gem Polish, the gold zone shrinking
-- with the streak (PERFECTs are a flat Sim.PerfectShare), walking between zones and shops, the weekly featured ball
-- (Config.Featured only changes which ball of a rarity you get, not the rarity).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomySim = {}

local function loadConfig()
	-- A fresh copy every run, so edits to Config are always picked up
	return require(ReplicatedStorage.Shared.Config:Clone() :: any)
end

-- Everything the rules need, worked out once per run from a config copy
local function prepare(config)
	local E = config.Economy
	local P = {}
	P.Rarities = {}
	P.RarityIndex = {}
	for index, rarity in config.Rarities do
		P.Rarities[index] = rarity.Name
		P.RarityIndex[rarity.Name] = index
	end

	-- XP needed for each rank level (same curve as Shared.Modules.Progression)
	local R = E.Ranks
	P.LevelXp = { 0 }
	for level = 1, R.MaxRank - 1 do
		local endFrom = R.EndFrom or math.huge
		local late = math.clamp(level - R.LateFrom, 0, endFrom - R.LateFrom)
		local final = math.max(level - endFrom, 0)
		local step = math.floor(
			R.Base * R.Growth ^ (math.min(level, R.LateFrom) - 1) * R.LateGrowth ^ late * (R.EndGrowth or 1) ^ final
		)
		P.LevelXp[level + 1] = P.LevelXp[level] + step
	end

	P.BuiltZones = math.min(config.Zones.BuiltZones, #E.Zones)

	-- Crates: price + odds from Config.Crates, ball pools like Zones.BallInCrate, odds moved to rarities the crate has
	local function ballInCrate(ball, crate): boolean
		if ball.InCrates == false or ball.Retired then
			return false
		end
		if crate.ZoneBallsOnly then
			return ball.Zone == crate.Zone
		end
		return true
	end
	P.Crates = {}
	P.CrateById = {}
	for _, crate in config.Crates do
		local pools = {}
		for _, ball in config.Balls do
			if ballInCrate(ball, crate) then
				local index = P.RarityIndex[ball.Rarity] or 1
				pools[index] = pools[index] or {}
				table.insert(pools[index], ball)
			end
		end
		local odds = {}
		for name, percent in crate.Odds do
			local index = P.RarityIndex[name] or 1
			for distance = 0, #P.Rarities do
				local target = if pools[index - distance]
					then index - distance
					elseif pools[index + distance] then index + distance
					else nil
				if target then
					odds[target] = (odds[target] or 0) + percent
					break
				end
			end
		end
		local row = {
			Id = crate.Id,
			Name = crate.Name,
			Zone = crate.Zone or 1,
			Price = crate.Price,
			Odds = odds,
			Pools = pools,
		}
		table.insert(P.Crates, row)
		P.CrateById[crate.Id] = row
	end
	-- Pity rows per crate
	P.Pity = {}
	for _, pity in E.CratePity do
		for crateId in pity.Crates do
			P.Pity[crateId] = P.Pity[crateId] or {}
			table.insert(P.Pity[crateId], { Rarity = P.RarityIndex[pity.Rarity], After = pity.After })
		end
	end

	-- Eggs: only those with pets (Mascots.EggReady); each pet's bonus like Mascots.Bonus
	local eggById = {}
	for _, egg in E.Eggs do
		eggById[egg.Id] = egg
	end
	P.Eggs = {}
	P.EggById = {}
	P.PetBonus = {}
	for _, pet in config.Mascots do
		local egg = eggById[pet.BonusEgg or pet.Egg]
		P.PetBonus[pet.Id] = (pet.BaseBonus or E.Mascots.Bonus[pet.Rarity] or 0) * (egg and egg.BonusScale or 1)
	end
	for _, egg in E.Eggs do
		local pools = {}
		for _, pet in config.Mascots do
			if pet.Egg == egg.Id then
				local index = P.RarityIndex[pet.Rarity] or 1
				pools[index] = pools[index] or {}
				table.insert(pools[index], pet.Id)
			end
		end
		if next(pools) and (egg.Zone or 1) <= P.BuiltZones then
			local row = { Id = egg.Id, Zone = egg.Zone or 1, Price = egg.Price, Pools = pools }
			table.insert(P.Eggs, row)
			P.EggById[egg.Id] = row
		end
	end

	P.Potions = {}
	for _, potion in config.Potions.List do
		P.Potions[potion.Id] = potion
	end
	return P
end

local function slots(E, s): number
	local M = E.Mascots
	local count = M.StartSlots
	for _, needed in M.SlotRebirths do
		if s.Rebirths >= needed then
			count += 1
		end
	end
	return math.min(count, M.MaxSlots)
end

local function median(values: { number }): number?
	if #values == 0 then
		return nil
	end
	table.sort(values)
	local mid = (#values + 1) / 2
	return (values[math.floor(mid)] + values[math.ceil(mid)]) / 2
end

local function clock(seconds: number?): string
	if not seconds then
		return "never"
	end
	local minutes = math.floor(seconds / 60)
	if minutes >= 60 then
		return ("%dh%02dm"):format(minutes // 60, minutes % 60)
	end
	return ("%d:%02d"):format(minutes, math.floor(seconds % 60))
end

local function short(n: number): string
	for _, unit in { { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if n >= unit[1] then
			return ("%g%s"):format(math.floor(n / unit[1] * 10 + 0.5) / 10, unit[2])
		end
	end
	return tostring(math.floor(n))
end

-- Plays one pretend player. Returns { [goal] = seconds } for every goal reached, and { [goal] = number } extras
-- (coins per minute when each zone opens).
function EconomySim.RunOne(config, seed: number, P): ({ [string]: number }, { [string]: number })
	local E = config.Economy
	local S = E.Sim
	local REWARDS = config.Rewards
	local rng = Random.new(seed)
	local reached: { [string]: number } = {}
	local extras: { [string]: number } = {}
	local s = {
		Coins = 0,
		XP = 0,
		Rank = 1,
		Level = 1, -- Power Level
		Zone = 1,
		Rebirths = 0,
		Streak = 0,
		Throws = 0,
		Owned = {}, -- ball Id -> Polish level
		Pets = {}, -- pet Id (or Id_Shiny) -> count
		EggCount = {},
		CrateCount = {},
		CratesBought = 0,
		CratesOpened = 0,
		Pity = {},
		Potions = { Coins = { [2] = 0, [4] = 0 }, XP = { [2] = 0, [4] = 0 } }, -- seconds left per kind and multiplier
		FreeEggs = {},
		RunStart = 0,
	}
	for _, ball in config.Balls do
		if ball.InCrates == false then
			s.Owned[ball.Id] = 0 -- the starter ball
		end
	end
	local time = 0
	local modifier, modifierEnds = {}, 0
	local ballMult, petMult = 1, 1
	local levelPaid = {}
	local challengeReady, challengeStreak = 0, 0
	local bossAt = math.huge
	local playtimeNext = 1
	local giftGiven, dailyGiven, spinGiven = false, false, false

	-- Each goal is timed per run ("Zone4", "Zone4@R1"...) and once over the whole session, rebirths and all
	-- ("EverZone4" = total play time until the first time it happened)
	local function mark(goal: string)
		local key = if s.Rebirths > 0 then goal .. "@R" .. s.Rebirths else goal
		if not reached[key] then
			reached[key] = time - s.RunStart
		end
		if not reached["Ever" .. goal] then
			reached["Ever" .. goal] = time
		end
	end

	local function refreshBall()
		local best = 1
		for _, ball in config.Balls do
			local polish = s.Owned[ball.Id]
			if polish then
				best = math.max(best, ball.Multiplier * (1 + E.Polish.ValuePerLevel * polish))
			end
		end
		ballMult = best
	end

	local function refreshPets()
		local list = {}
		for id, count in s.Pets do
			local base = id:gsub("_Shiny$", "")
			local bonus = (P.PetBonus[base] or 0) * (if id ~= base then E.Mascots.ShinyMultiplier else 1)
			for _ = 1, count do
				table.insert(list, bonus)
			end
		end
		table.sort(list, function(a, b)
			return a > b
		end)
		local total = 0
		for i = 1, math.min(slots(E, s), #list) do
			total += list[i]
		end
		petMult = 1 + total
	end

	local function nextLevelPrice(): number
		local row = E.PowerLevels[s.Level + 1] or E.PowerLevels[#E.PowerLevels]
		return row.Price
	end

	-- Coins + LevelShare like PowerLevels.DailyCoins
	local function shareCoins(reward): number
		local coins = reward.Coins or 0
		if reward.LevelShare then
			local share = nextLevelPrice() * reward.LevelShare
			if share > coins then
				local unit = 10 ^ math.max(math.floor(math.log10(share)) - 1, 0)
				coins = math.floor(share / unit) * unit
			end
		end
		return coins
	end

	local function rollIndex(odds: { [number]: number }, minIndex: number): number
		local total = 0
		for index, weight in odds do
			if index >= minIndex then
				total += weight
			end
		end
		if total <= 0 then
			return minIndex
		end
		local roll = rng:NextNumber() * total
		for index = 1, #P.Rarities do
			local weight = odds[index]
			if weight and index >= minIndex then
				roll -= weight
				if roll <= 0 then
					return index
				end
			end
		end
		return minIndex
	end

	local function giveBall(ball)
		local polish = s.Owned[ball.Id]
		if polish == nil then
			s.Owned[ball.Id] = 0
		elseif polish < E.Polish.MaxLevel then
			s.Owned[ball.Id] =
				math.min(E.Polish.MaxLevel, polish + E.Polish.PointsPerDuplicate / E.Polish.PointsPerLevel)
		end
		refreshBall()
	end

	-- exactRarity: the first bought crate / spin's secret ball give exactly this rarity
	local function openCrate(crateId: string, exactRarity: string?)
		local crate = P.CrateById[crateId]
		if not crate then
			return
		end
		local index
		if exactRarity then
			index = P.RarityIndex[exactRarity]
		else
			local minIndex = 1
			if s.CratesOpened == 0 then
				minIndex = P.RarityIndex[E.FirstCrateMin] or 1
			end
			for _, pity in P.Pity[crateId] or {} do
				if (s.Pity[crateId .. pity.Rarity] or 0) + 1 >= pity.After then
					minIndex = math.max(minIndex, pity.Rarity)
				end
			end
			index = rollIndex(crate.Odds, minIndex)
		end
		for _, pity in P.Pity[crateId] or {} do
			local key = crateId .. pity.Rarity
			s.Pity[key] = if index >= pity.Rarity then 0 else (s.Pity[key] or 0) + 1
		end
		s.CratesOpened += 1
		local pool = crate.Pools[index]
		if pool then
			giveBall(pool[rng:NextInteger(1, #pool)])
		end
		mark("Crate" .. crateId)
	end

	-- A reward crate from a zone not open yet comes as the Alley Crate (Zones.RewardCrateId)
	local function rewardCrate(crateId: string?, exact: boolean?)
		if not crateId then
			return
		end
		local crate = P.CrateById[crateId]
		if not exact and crate and crate.Zone > s.Zone then
			crateId = config.Rizzo.CrateId
		end
		openCrate(crateId)
	end

	-- exactRarity: the spin's secret pet
	local function hatch(eggId: string, exactRarity: string?)
		local egg = P.EggById[eggId]
		if not egg then
			return
		end
		local index
		if exactRarity then
			index = P.RarityIndex[exactRarity]
		else
			local odds = {}
			for rarityIndex in egg.Pools do
				odds[rarityIndex] = E.Mascots.Odds[P.Rarities[rarityIndex]] or 0
			end
			index = rollIndex(odds, 1)
		end
		while index > 1 and not egg.Pools[index] do
			index -= 1
		end
		local pool = egg.Pools[index]
		if not pool then
			return
		end
		local id = pool[rng:NextInteger(1, #pool)]
		s.Pets[id] = (s.Pets[id] or 0) + 1
		-- Merge 3 copies into a Shiny (players press MERGE)
		if s.Pets[id] >= E.Mascots.ShinyMerge then
			s.Pets[id] -= E.Mascots.ShinyMerge
			local shiny = id .. "_Shiny"
			s.Pets[shiny] = (s.Pets[shiny] or 0) + 1
		end
		refreshPets()
		mark("Egg" .. eggId)
		mark("FirstMascot")
	end

	local function givePotion(id: string, count: number?)
		local potion = P.Potions[id]
		if potion then
			local timers = s.Potions[potion.Boost]
			timers[potion.Multiplier] = (timers[potion.Multiplier] or 0) + potion.Minutes * 60 * (count or 1)
		end
	end

	-- Like MilestoneService.Reward: coins (with LevelShare), potions, a crate
	local function giveReward(reward)
		s.Coins += shareCoins(reward)
		for _, potion in reward.Potions or {} do
			givePotion(potion.Id, potion.Count)
		end
		if reward.Egg then
			s.FreeEggs[reward.Egg] = (s.FreeEggs[reward.Egg] or 0) + 1
		end
		rewardCrate(reward.Crate, reward.Exact)
	end

	local function spin()
		local total = 0
		for _, slice in config.Spin.Slices do
			total += slice.Chance
		end
		local roll = rng:NextNumber() * total
		for _, slice in config.Spin.Slices do
			roll -= slice.Chance
			if roll <= 0 then
				if slice.Potion then
					givePotion(slice.Potion)
				elseif slice.Ball then
					openCrate(slice.Crate, slice.Ball)
				elseif slice.Pet then
					hatch(slice.Egg, slice.Pet)
				elseif slice.Egg then
					s.FreeEggs[slice.Egg] = (s.FreeEggs[slice.Egg] or 0) + 1
				elseif slice.Crate then
					rewardCrate(slice.Crate)
				end
				return
			end
		end
	end

	-- The strongest running potion of a kind counts; it ticks down, the weaker one waits (PotionService)
	local function potionMultiplier(kind: string, seconds: number): number
		local timers = s.Potions[kind]
		for _, multiplier in { 4, 2 } do
			if (timers[multiplier] or 0) > 0 then
				timers[multiplier] = math.max(0, timers[multiplier] - seconds)
				return multiplier
			end
		end
		return 1
	end

	local function eggOpen(egg): boolean
		return egg.Zone <= s.Zone
	end

	-- The next rebirth's level and coins (same rule as Shared.Modules.Rebirth)
	local function rebirthNeed(): (number, number)
		local costs = E.Rebirth.Costs
		local needCoins = if not costs or #costs == 0
			then E.Rebirth.FirstCost * E.Rebirth.CostGrowth ^ s.Rebirths
			elseif s.Rebirths < #costs then costs[s.Rebirths + 1]
			else costs[#costs] * E.Rebirth.CostGrowth ^ (s.Rebirths + 1 - #costs)
		return E.Rebirth.Level + E.Rebirth.RankStep * s.Rebirths, needCoins
	end
	-- Saving up for a rebirth that opens a zone: the goal bar makes it THE goal once it's half way (EventController)
	local function savingForRebirth(): boolean
		if s.Rebirths >= S.Rebirths then
			return false
		end
		local zone = s.Zone + 1
		if zone > P.BuiltZones or (E.Zones[zone].Rebirths or math.huge) ~= s.Rebirths + 1 then
			return false
		end
		local needRank, needCoins = rebirthNeed()
		return s.Rank >= needRank and s.Coins >= needCoins * (S.SaveForRebirthAt or 1)
	end

	local function buy()
		-- 1. Next Power Level, as soon as it's affordable
		while s.Level < #E.PowerLevels and s.Coins >= E.PowerLevels[s.Level + 1].Price do
			s.Coins -= E.PowerLevels[s.Level + 1].Price
			s.Level += 1
			mark("Level" .. s.Level)
		end
		local budget = if s.Level < #E.PowerLevels then nextLevelPrice() * S.SpendShare else math.huge
		if savingForRebirth() then
			budget = 0 -- no eggs or crates (the cut-price first crate still goes)
		end
		-- 2. Free hatches first, then eggs and crates that are cheap next to the next Power Level, best first
		for eggId, count in s.FreeEggs do
			local egg = P.EggById[eggId]
			if egg and eggOpen(egg) and count > 0 then
				for _ = 1, count do
					hatch(eggId)
				end
				s.FreeEggs[eggId] = 0
			end
		end
		for i = #P.Eggs, 1, -1 do
			local egg = P.Eggs[i]
			while
				eggOpen(egg)
				and egg.Price <= budget
				and s.Coins >= egg.Price
				and (s.EggCount[egg.Id] or 0) < S.MaxEggs
			do
				s.Coins -= egg.Price
				s.EggCount[egg.Id] = (s.EggCount[egg.Id] or 0) + 1
				hatch(egg.Id)
			end
		end
		for i = #P.Crates, 1, -1 do
			local crate = P.Crates[i]
			local function price(): number
				if
					s.CratesBought == 0
					and crate.Id == config.Onboarding.FirstCrateGoal
					and config.Onboarding.FirstCratePrice
				then
					return math.min(config.Onboarding.FirstCratePrice, crate.Price)
				end
				return crate.Price
			end
			while
				crate.Zone <= s.Zone
				and (price() <= budget or price() < crate.Price) -- the cut-price first crate is always worth it
				and s.Coins >= price()
				and (s.CrateCount[crate.Id] or 0) < S.MaxCrates
			do
				local first = s.CratesBought == 0
				s.Coins -= price()
				s.CratesBought += 1
				s.CrateCount[crate.Id] = (s.CrateCount[crate.Id] or 0) + 1
				openCrate(crate.Id, if first then config.Onboarding.FirstBoughtRarity else nil)
				mark("FirstCrateOpened")
			end
		end
	end

	local function pickModifier()
		local pool, total = {}, 0
		for _, row in config.LaneModifiers.List do
			if config.Gems.Enabled or not row.NeedsGems then
				table.insert(pool, row)
				total += row.Weight or 1
			end
		end
		local roll = rng:NextNumber() * total
		for _, row in pool do
			roll -= row.Weight or 1
			if roll <= 0 then
				return row
			end
		end
		return pool[#pool]
	end

	local function onRank()
		mark("Rank" .. s.Rank)
		for _, reward in config.Milestones.LevelRewards do
			if s.Rank >= reward.Level and not levelPaid[reward.Level] then
				levelPaid[reward.Level] = true
				giveReward(reward)
			end
		end
		refreshPets() -- more slots at some ranks
	end

	-- Zones open by rebirths (owner 2026-10-27: Config.Economy.Zones Rebirths)
	local function openZones()
		for zone = s.Zone + 1, P.BuiltZones do
			if s.Rebirths >= (E.Zones[zone].Rebirths or math.huge) then
				s.Zone = zone
				mark("Zone" .. zone)
				if config.Boss.Enabled and zone == config.Boss.Zone then
					bossAt = time -- the helicopter is ready the first time you get there
				end
				if not spinGiven and config.Spin.Enabled and zone == S.SpinAtZone then
					spinGiven = true
					spin()
				end
			end
		end
	end

	-- Coins per minute in a zone: its first 100 throws
	local recent, recentIndex = table.create(100, 0), 0
	local zoneOpenedAt = -math.huge

	refreshBall()
	local throwSeconds = S.ThrowSeconds
	while time < S.Minutes * 60 do
		time += throwSeconds
		s.Throws += 1
		local zone = E.Zones[s.Zone]
		local level = E.PowerLevels[s.Level]

		-- The throw (ThrowResolver): PERFECT = all 10 pins; otherwise fewer, capped by Power
		local perfect = rng:NextNumber() < S.PerfectShare
		local pins = config.Lane.PinCount
		if not perfect then
			local charge
			if rng:NextNumber() < S.GoodShare then
				charge = S.GoodQuality[1] + rng:NextNumber() * (S.GoodQuality[2] - S.GoodQuality[1])
			else
				charge = S.BadQuality[1] + rng:NextNumber() * (S.BadQuality[2] - S.BadQuality[1])
			end
			local most = math.clamp(math.floor(level.Power), 2, pins - 1)
			local fewest = math.min(config.Throw.FewestPinsKnocked, most)
			local wanted = fewest + (most - fewest) * charge + (rng:NextNumber() * 2 - 1)
			pins = math.clamp(math.floor(wanted + 0.5), math.min(math.max(fewest, 2), most), most)
		end
		s.Streak = if perfect then s.Streak + 1 else 0

		if time >= modifierEnds then
			modifier = pickModifier()
			modifierEnds = time + config.LaneModifiers.Interval
		end
		local golden = rng:NextNumber() < config.GoldenPin.Chance and rng:NextInteger(1, config.Lane.PinCount) <= pins
		local streakCoins, streakXp = 1, 1
		for _, tier in config.Streaks do
			if s.Streak >= tier.Streak then
				streakCoins, streakXp = tier.Multiplier, tier.XpMultiplier
			end
		end
		local tier = config.Ranks[math.clamp(math.ceil(s.Rank / E.Ranks.LevelsPerTier), 1, #config.Ranks)]
		local coinPotion = potionMultiplier("Coins", throwSeconds)
		local xpPotion = potionMultiplier("XP", throwSeconds)
		local rebirthCoins = 1 + E.Formula.RebirthBonus * s.Rebirths
		local rebirthXp = 1 + (E.Rebirth.XpBonus or 0) * s.Rebirths

		local multiplier = level.Value
			* ballMult
			* petMult
			* coinPotion
			* tier.Multiplier
			* rebirthCoins
			* streakCoins
			* (modifier.CoinMultiplier or 1)
			* (if golden then config.GoldenPin.CoinMultiplier else 1)
			* (if perfect then 1 + REWARDS.PerfectStrikeBonus else 1)
			* (zone.CoinPay or 1)
		local coins = math.floor(pins * REWARDS.BaseCoinsPerPin * multiplier + 0.5)
		s.Coins += coins
		recentIndex = recentIndex % 100 + 1
		recent[recentIndex] = coins
		local xp = if perfect then REWARDS.PerfectStrikeXp else pins * REWARDS.XpPerPin
		s.XP += math.floor(xp * streakXp * petMult * xpPotion * rebirthXp * (zone.XpPay or 1) + 0.5)
		if S.Trace then -- tuning scripts can watch every throw
			S.Trace(time, s, { Ball = ballMult, Mascots = petMult, Pins = pins, Coins = coins })
		end

		while s.Rank < E.Ranks.MaxRank and s.XP >= P.LevelXp[s.Rank + 1] do
			s.Rank += 1
			onRank()
		end
		if s.Throws - zoneOpenedAt == #recent and not extras["CoinsPerMin" .. s.Zone] and s.Zone > 1 then
			local sum = 0
			for _, value in recent do
				sum += value
			end
			extras["CoinsPerMin" .. s.Zone] = sum / #recent * 60 / throwSeconds
		end

		if s.Coins >= P.Crates[1].Price then
			mark("FirstCrate")
		end
		if P.Eggs[1] and eggOpen(P.Eggs[1]) and s.Coins >= P.Eggs[1].Price then
			mark("FirstEgg")
		end

		-- The 3-strike challenge (Config.Milestones.Challenges), while bowling in its zone
		for _, challenge in config.Milestones.Challenges do
			if (challenge.Zone == nil or challenge.Zone == s.Zone) and time >= challengeReady then
				challengeStreak = if perfect then challengeStreak + 1 else 0
				if challengeStreak >= challenge.Goal then
					challengeStreak = 0
					challengeReady = time + (challenge.Cooldown or 0)
					mark("Challenge")
					giveReward(challenge.Reward)
				end
			end
		end

		-- Free crate every Config.FreeCrates.ThrowsPerCrate throws, the onboarding gift crate, day 1's daily reward
		if s.Throws % config.FreeCrates.ThrowsPerCrate == 0 then
			openCrate(config.FreeCrates.CrateId)
		end
		if config.Onboarding.Enabled and not giftGiven and s.Throws >= config.Onboarding.GiftAfterThrows then
			giftGiven = true
			openCrate(config.Onboarding.GiftCrateId, config.Onboarding.GiftRarity)
		end
		if not dailyGiven and s.Throws >= config.Onboarding.GiftAfterThrows + config.Onboarding.LegendsAfterThrows then
			dailyGiven = true
			giveReward(config.Daily.Rewards[1])
		end

		-- Playtime gifts
		local gift = config.Playtime.Enabled and config.Playtime.Rewards[playtimeNext]
		if gift and time - s.RunStart >= gift.Minutes * 60 then
			playtimeNext += 1
			-- gifts grow with progress (batch B4, Shared.Modules.PlaytimeRewards): zone row, income-based coins
			local row = config.Playtime.ByZone[math.clamp(s.Zone, 1, #config.Playtime.ByZone)]
			if gift.Coins then
				s.Coins += shareCoins(gift) * (config.Economy.Zones[s.Zone].CoinPay or 1)
			elseif gift.Potion then
				givePotion(gift.Potion, row.Potions or 1)
			elseif gift.Egg then
				giveReward({ Egg = if gift.Egg == "Zone" then row.Egg else gift.Egg })
			elseif gift.Crate then
				giveReward({
					Crate = if type(gift.Crate) == "number" then row.Crates[gift.Crate] else gift.Crate,
					Exact = true,
				})
			end
		end

		-- The zone 4 boss: a trip every CooldownMinutes once that zone is open
		if time >= bossAt then
			time += S.BossTripSeconds
			bossAt = time + (config.Boss.EverySeconds or 45 * 60) -- one event every 45 minutes (Config.Boss)
			mark("Boss")
			giveReward(config.Boss.Reward or config.Boss.Tiers[3].Reward) -- a GOLD finish (a fair share of the damage)
		end

		-- Rebirth (only while the simulator is told to: Sim.Rebirths)
		-- A rebirth resets coins, Power Level and (batch D1, owner 2026-10-29) rank level + XP, and opens the zones.
		-- Level rewards already paid stay paid (levelPaid), like BestLevel in the game
		local needRank, needCoins = rebirthNeed()
		if s.Rank >= needRank and s.Coins >= needCoins then
			mark("RebirthReady")
			if s.Rebirths < S.Rebirths then
				s.Rebirths += 1
				s.RunStart = time
				mark("Rebirth" .. s.Rebirths)
				s.Coins, s.Level, s.Streak = 0, 1, 0
				s.Rank, s.XP = 1, 0
				local before = s.Zone
				openZones()
				if s.Zone ~= before then
					zoneOpenedAt = s.Throws
				end
				refreshPets()
				mark("Start")
				continue
			end
		end
		buy()
	end
	extras.FinalCoins = s.Coins
	extras.FinalRank = s.Rank
	extras.FinalLevel = s.Level
	extras.FinalPets = petMult
	extras.FinalBall = ballMult
	return reached, extras
end

-- Runs Config.Economy.Sim.Runs players and returns { [goal] = { Median = seconds?, Share = 0..1 } } and the
-- medians of the extras. config: leave out to use the current Config (tuning scripts pass an edited copy).
function EconomySim.Simulate(config: any?)
	config = config or loadConfig()
	local S = config.Economy.Sim
	local P = prepare(config)
	local all: { [string]: { number } } = {}
	local allExtras: { [string]: { number } } = {}
	for run = 1, S.Runs do
		local reached, extras = EconomySim.RunOne(config, run, P)
		for goal, seconds in reached do
			all[goal] = all[goal] or {}
			table.insert(all[goal], seconds)
		end
		for name, value in extras do
			allExtras[name] = allExtras[name] or {}
			table.insert(allExtras[name], value)
		end
	end
	local results = {}
	for goal, list in all do
		results[goal] = { Median = median(list), Share = #list / S.Runs }
	end
	local extras = {}
	for name, list in allExtras do
		extras[name] = median(list)
	end
	return results, config, extras, P
end

-- Checks the content rules that don't need a simulation. Returns a list of problems (empty = fine).
function EconomySim.CheckRules(config, P): { string }
	local problems = {}
	for _, crate in P.Crates do
		local total = 0
		for _, weight in crate.Odds do
			total += weight
		end
		if math.abs(total - 100) > 1e-6 then
			table.insert(problems, ("%s crate odds add up to %g, not 100"):format(crate.Id, total))
		end
		if not next(crate.Pools) then
			table.insert(problems, crate.Id .. " crate has no balls")
		end
	end
	-- Every crate ball must be reachable from at least one crate
	for _, ball in config.Balls do
		if ball.InCrates ~= false and not ball.Retired then
			local found = false
			for _, crate in P.Crates do
				for _, pool in crate.Pools do
					if table.find(pool, ball) then
						found = true
					end
				end
			end
			if not found then
				table.insert(problems, ball.Name .. " is not in any crate")
			end
		end
	end
	return problems
end

-- Prints (and returns) the report: the plan's timeline first, then zones, Power Levels, ranks, crates, eggs.
function EconomySim.Run(config: any?): string
	local results, extras, P
	results, config, extras, P = EconomySim.Simulate(config)
	local E = config.Economy
	local lines = {}
	local function add(text: string)
		table.insert(lines, text)
	end
	-- Total play time (rebirths included) when there is one: rebirths are part of the normal climb now
	local function row(goal: string)
		return results["Ever" .. goal] or results[goal]
	end
	local function get(goal: string): number?
		return row(goal) and row(goal).Median
	end
	local function share(goal: string): string
		local row = row(goal)
		if row and row.Share < 1 then
			return (" (%d%% of players)"):format(row.Share * 100)
		end
		return ""
	end

	local pay = {}
	for zone = 1, P.BuiltZones do
		table.insert(pay, ("z%d x%g/x%g"):format(zone, E.Zones[zone].CoinPay or 1, E.Zones[zone].XpPay or 1))
	end
	add(
		("ECONOMY SIMULATOR - %d players, %g hours each, 1 throw every %gs, PERFECT %d%%; zone pay coins/XP: %s"):format(
			E.Sim.Runs,
			E.Sim.Minutes / 60,
			E.Sim.ThrowSeconds,
			E.Sim.PerfectShare * 100,
			table.concat(pay, ", ")
		)
	)
	for _, problem in EconomySim.CheckRules(config, P) do
		add("RULE PROBLEM: " .. problem)
	end
	add("")
	add("PLAN TIMELINE                     target        simulated   check")
	local mismatches = 0
	for _, row in E.Timeline do
		local seconds = get(if row.Ever then "Ever" .. row.Goal else row.Goal)
		local minutes = seconds and seconds / 60
		local tolerance = E.Sim.ToleranceShare
		local check
		if row.Rebirth and E.Sim.Rebirths == 0 then
			check = "rebirth is off"
		elseif not minutes then
			check = "MISMATCH (never)"
		elseif minutes >= row.From and minutes <= row.To then
			check = "OK"
		elseif minutes >= row.From * (1 - tolerance) and minutes <= row.To * (1 + tolerance) then
			check = "close"
		else
			check = if minutes < row.From then "MISMATCH (too fast)" else "MISMATCH (too slow)"
		end
		if check:sub(1, 8) == "MISMATCH" then
			mismatches += 1
		end
		add(
			("%-32s  %5s-%-6s  %9s   %s"):format(
				row.Text,
				clock(row.From * 60),
				clock(row.To * 60),
				clock(seconds),
				check
			)
		)
	end
	add(("%d mismatch(es)"):format(mismatches))

	add("")
	add("ZONES")
	for zone = 2, P.BuiltZones do
		add(
			("  Zone %d %-18s opens %-8s%s   coins/min (first 5 min there) %s"):format(
				zone,
				E.Zones[zone].Name,
				clock(get("EverZone" .. zone)),
				share("EverZone" .. zone),
				if extras["CoinsPerMin" .. zone] then short(extras["CoinsPerMin" .. zone]) else "-"
			)
		)
	end
	add("POWER LEVELS")
	for level = 2, #E.PowerLevels do
		add(
			("  Level %-2d  price %-7s %-8s%s"):format(
				level,
				short(E.PowerLevels[level].Price),
				clock(get("Level" .. level)),
				share("Level" .. level)
			)
		)
	end
	add("RANK LEVELS (a new tier every 6)")
	local rankLine = {}
	for _, rank in { 5, 7, 12, 13, 19, 22, 25, 31, 37, 43, 49, 55, 60 } do
		table.insert(rankLine, ("L%d %s"):format(rank, clock(get("Rank" .. rank))))
	end
	add("  " .. table.concat(rankLine, " | "))
	add("FIRST OF EACH CRATE (price)")
	for _, crate in P.Crates do
		add(
			("  z%d %-17s %-7s %-8s%s"):format(
				crate.Zone,
				crate.Name,
				short(crate.Price),
				clock(get("Crate" .. crate.Id)),
				share("Crate" .. crate.Id)
			)
		)
	end
	add("FIRST OF EACH EGG (price)")
	for _, egg in P.Eggs do
		add(
			("  z%d %-17s %-7s %-8s%s"):format(
				egg.Zone,
				(config.EggLooks[egg.Id] or {}).Name or egg.Id,
				short(egg.Price),
				clock(get("Egg" .. egg.Id)),
				share("Egg" .. egg.Id)
			)
		)
	end
	add(
		("AFTER %g HOURS: rank level %d, Power Level %d, ball x%.2f, pets x%.2f, %s coins in the bank"):format(
			E.Sim.Minutes / 60,
			extras.FinalRank or 0,
			extras.FinalLevel or 0,
			extras.FinalBall or 1,
			extras.FinalPets or 1,
			short(extras.FinalCoins or 0)
		)
	)
	add(
		("First boss %s, first challenge win %s, first rebirth ready %s"):format(
			clock(get("Boss")),
			clock(get("Challenge")),
			clock(get("RebirthReady"))
		)
	)
	add("TOTAL PLAY TIME TO THE FIRST (rebirths included)")
	local ever = {}
	for _, goal in
		{
			{ "Zone4", "zone 4" },
			{ "Boss", "boss" },
			{ "EggSkyline", "Skyline Egg" },
			{ "CrateSkyGold", "Sky Gold crate" },
			{ "Level12", "Power Level 12" },
			{ "Rank30", "level 30" },
			{ "Rank60", "level 60" },
		}
	do
		table.insert(ever, ("%s %s"):format(goal[2], clock(get("Ever" .. goal[1]))))
	end
	add("  " .. table.concat(ever, " | "))
	local rebirths = {}
	for n = 1, E.Sim.Rebirths do
		if results["EverRebirth" .. n] then
			table.insert(rebirths, ("%d at %s"):format(n, clock(get("EverRebirth" .. n))))
		end
	end
	add("  REBIRTHS (total play time): " .. table.concat(rebirths, " | "))

	local report = table.concat(lines, "\n")
	print(report)
	return report
end

-- The short economy sheet (Addendum 2, Phase 1 step 1): how long each upgrade takes a new player,
-- using the measured time per throw (Config.Economy.Sim.ThrowSeconds). Paste in Studio's command bar (edit mode):
--   require(game.ServerStorage.Tools.EconomySim).Sheet()
function EconomySim.Sheet(config: any?): string
	local results
	results, config = EconomySim.Simulate(config)
	local E = config.Economy
	local S = E.Sim
	local lines = {}
	local function add(text: string)
		table.insert(lines, text)
	end
	local function at(goal: string): number?
		return results[goal] and results[goal].Median
	end
	add(
		("ECONOMY SHEET - 1 throw every %gs, PERFECT on %d%% of throws, median of %d pretend players"):format(
			S.ThrowSeconds,
			S.PerfectShare * 100,
			S.Runs
		)
	)
	add("UPGRADE              PRICE     REACHED   WAIT      THROWS")
	local previous = 0
	local function row(name: string, price: number, goal: string)
		local seconds = at(goal)
		if not seconds then
			add(("%-20s %-9s never"):format(name, short(price)))
			return
		end
		local wait = seconds - previous
		previous = seconds
		add(
			("%-20s %-9s %-9s %-9s %d"):format(
				name,
				short(price),
				clock(seconds),
				clock(wait),
				math.floor(wait / S.ThrowSeconds + 0.5)
			)
		)
	end
	row("First crate (Alley)", config.Onboarding.FirstCratePrice or E.Crates[1].Price, "FirstCrateOpened")
	previous = 0 -- the crate is a side purchase; Power Level waits count from the start
	for level = 2, #E.PowerLevels do
		row("Power Level " .. level, E.PowerLevels[level].Price, "Level" .. level)
	end
	local zones = {}
	for index = 2, math.min(config.Zones.BuiltZones, #E.Zones) do
		table.insert(zones, ("%d at %s"):format(index, clock(at("EverZone" .. index))))
	end
	add("Zones open: " .. table.concat(zones, ", "))
	add("First rebirth ready: " .. clock(at("RebirthReady")))
	local report = table.concat(lines, "\n")
	print(report)
	return report
end

return EconomySim
