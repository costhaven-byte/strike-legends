-- Economy simulator (MASTER_PLAN.md Milestone 10, with Addendum 1). Plays pretend players on the numbers in
-- Config.Economy (plus the ball roster in Config.Balls) and prints when they reach each Power Level, rank, zone and
-- rebirth, checked against Config.Economy.Timeline.
-- Never runs in the game. To use it, paste this in Studio's command bar (edit mode, not play mode):
--   require(game.ServerStorage.Tools.EconomySim).Run()
-- Simulated like the live game: PERFECT-only strikes, streak tiers, lane modifiers, Golden Pins (coins only).
-- Not simulated yet: boss pins, daily rewards and quests, gems, Golden Pin free crates, Streak Saver.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomySim = {}

type State = {
	Coins: number,
	XP: number,
	Rank: number,
	Level: number, -- Power Level
	Zone: number,
	Rebirths: number,
	Streak: number,
	Owned: { [string]: number }, -- ball Id -> Polish level
	Mascots: { number },
	EggCount: { [string]: number },
	CrateCount: { [string]: number },
	Pity: { [string]: number }, -- "<crate>:<rarity>" -> pulls since that rarity or better
	OpenedCrate: boolean,
	RunStart: number, -- seconds when the current run (after the last rebirth) started
}

local RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
local RARITY_INDEX = {}
for i, name in RARITIES do
	RARITY_INDEX[name] = i
end

local function loadConfig()
	-- A fresh copy every run, so edits to Config are always picked up
	return require(ReplicatedStorage.Shared.Config:Clone() :: any)
end

-- XP to go from rank r to r + 1
local function xpToNext(E, rank: number): number
	local R = E.Ranks
	if rank <= R.LateFrom then
		return math.floor(R.Base * R.Growth ^ (rank - 1))
	end
	return math.floor(R.Base * R.Growth ^ (R.LateFrom - 1) * R.LateGrowth ^ (rank - R.LateFrom))
end

local function rollRarity(rng: Random, odds: { [string]: number }, minIndex: number): string
	local total = 0
	for name, weight in odds do
		if RARITY_INDEX[name] >= minIndex then
			total += weight
		end
	end
	if total <= 0 then
		return RARITIES[minIndex]
	end
	local roll = rng:NextNumber() * total
	for _, name in RARITIES do
		local weight = odds[name]
		if weight and RARITY_INDEX[name] >= minIndex then
			roll -= weight
			if roll <= 0 then
				return name
			end
		end
	end
	return RARITIES[minIndex]
end

local function slots(E, s: State): number
	local M = E.Mascots
	local count = M.StartSlots
	for _, rank in M.SlotRanks do
		if s.Rank >= rank then
			count += 1
		end
	end
	for _, rebirths in M.SlotRebirths do
		if s.Rebirths >= rebirths then
			count += 1
		end
	end
	return math.min(count, M.MaxSlots)
end

-- 1 + the best equipped mascots' bonuses
local function mascotMultiplier(E, s: State): number
	table.sort(s.Mascots, function(a, b)
		return a > b
	end)
	local bonus = 0
	for i = 1, math.min(slots(E, s), #s.Mascots) do
		bonus += s.Mascots[i]
	end
	return 1 + bonus
end

-- The equipped ball: the owned ball with the best Multiplier after Polish
local function ballMultiplier(config, s: State): number
	local best = 1
	for _, ball in config.Balls do
		local polish = s.Owned[ball.Id]
		if polish then
			best = math.max(best, ball.Multiplier * (1 + config.Economy.Polish.ValuePerLevel * polish))
		end
	end
	return best
end

local function levelPrice(E, s: State, level: number): number
	local price = E.PowerLevels[level].Price
	if s.Rebirths > 0 and level <= E.Rebirth.DiscountLevels then
		price *= E.Rebirth.DiscountPrice
	end
	return price
end

local function rebirthNeeds(E, s: State): (number, number)
	local R = E.Rebirth
	return R.FirstRank + R.RankStep * s.Rebirths, R.FirstCost * R.CostGrowth ^ s.Rebirths
end

local function eggUnlocked(egg, s: State): boolean
	return (egg.Rank == nil or s.Rank >= egg.Rank) and (egg.Zone == nil or s.Zone >= egg.Zone)
end

-- Balls in crates, by rarity
local function crateBallsByRarity(config): { [string]: { any } }
	local byRarity = {}
	for _, ball in config.Balls do
		if ball.InCrates ~= false then
			byRarity[ball.Rarity] = byRarity[ball.Rarity] or {}
			table.insert(byRarity[ball.Rarity], ball)
		end
	end
	return byRarity
end

local function openCrate(config, s: State, rng: Random, crate, byRarity)
	local E = config.Economy
	local minIndex = 1
	if not s.OpenedCrate then
		minIndex = RARITY_INDEX[E.FirstCrateMin]
	end
	for _, pity in E.CratePity do
		local key = crate.Id .. ":" .. pity.Rarity
		if pity.Crates[crate.Id] and (s.Pity[key] or 0) + 1 >= pity.After then
			minIndex = math.max(minIndex, RARITY_INDEX[pity.Rarity])
		end
	end
	local rarity = rollRarity(rng, crate.Odds, minIndex)
	for _, pity in E.CratePity do
		if pity.Crates[crate.Id] then
			local key = crate.Id .. ":" .. pity.Rarity
			s.Pity[key] = if RARITY_INDEX[rarity] >= RARITY_INDEX[pity.Rarity] then 0 else (s.Pity[key] or 0) + 1
		end
	end
	s.OpenedCrate = true

	local pool = byRarity[rarity]
	local ball = pool[rng:NextInteger(1, #pool)]
	local polish = s.Owned[ball.Id]
	if polish == nil then
		s.Owned[ball.Id] = 0
	elseif polish < E.Polish.MaxLevel then
		-- Duplicate: Polish Points straight onto that ball (coins once it's maxed are not counted)
		s.Owned[ball.Id] = math.min(E.Polish.MaxLevel, polish + E.Polish.PointsPerDuplicate / E.Polish.PointsPerLevel)
	end
end

-- Coin multiplier of the streak tier reached (Config.Streaks), like Progression.GetStreakMultiplier
local function streakMultiplier(config, streak: number): number
	local multiplier = 1
	for _, tier in config.Streaks do
		if streak >= tier.Streak then
			multiplier = tier.Multiplier
		end
	end
	return multiplier
end

-- A lane modifier by Weight, like Modifiers.PickNext (Bonus Gems sits out while gems are off)
local function pickModifier(config, rng: Random)
	local pool, total = {}, 0
	for _, modifier in config.LaneModifiers.List do
		if config.Gems.Enabled or not modifier.NeedsGems then
			table.insert(pool, modifier)
			total += modifier.Weight or 1
		end
	end
	local roll = rng:NextNumber() * total
	for _, modifier in pool do
		roll -= modifier.Weight or 1
		if roll <= 0 then
			return modifier
		end
	end
	return pool[#pool]
end

-- Plays one pretend player. Returns { [goal] = seconds } for every goal reached.
function EconomySim.RunOne(config, seed: number): { [string]: number }
	local E = config.Economy
	local F, S = E.Formula, E.Sim
	local rng = Random.new(seed)
	local byRarity = crateBallsByRarity(config)
	local reached: { [string]: number } = {}
	local s: State = {
		Coins = 0,
		XP = 0,
		Rank = 1,
		Level = 1,
		Zone = 1,
		Rebirths = 0,
		Streak = 0,
		Owned = {},
		Mascots = {},
		EggCount = {},
		CrateCount = {},
		Pity = {},
		OpenedCrate = false,
		RunStart = 0,
	}
	for _, ball in config.Balls do
		if ball.InCrates == false then
			s.Owned[ball.Id] = 0 -- the starter ball
		end
	end
	local time = 0
	local modifier, modifierEnds = {}, 0

	-- Goals after a rebirth get "@R1", "@R2"... so each run is timed on its own (from the rebirth)
	local function mark(goal: string)
		local key = if s.Rebirths > 0 then goal .. "@R" .. s.Rebirths else goal
		if not reached[key] then
			reached[key] = time - s.RunStart
		end
	end

	local function buy()
		-- 1. Next Power Level, as soon as it's affordable
		while s.Level < #E.PowerLevels and s.Coins >= levelPrice(E, s, s.Level + 1) do
			s.Coins -= levelPrice(E, s, s.Level + 1)
			s.Level += 1
			mark("Level" .. s.Level)
		end
		local nextPrice = if s.Level < #E.PowerLevels then levelPrice(E, s, s.Level + 1) else math.huge
		local budget = nextPrice * S.SpendShare
		-- 2. Eggs and crates that are cheap next to the next Power Level, best first
		for i = #E.Eggs, 1, -1 do
			local egg = E.Eggs[i]
			while
				eggUnlocked(egg, s)
				and egg.Price <= budget
				and s.Coins >= egg.Price
				and (s.EggCount[egg.Id] or 0) < S.MaxEggs
			do
				s.Coins -= egg.Price
				s.EggCount[egg.Id] = (s.EggCount[egg.Id] or 0) + 1
				local rarity = rollRarity(rng, E.Mascots.Odds, 1)
				table.insert(s.Mascots, E.Mascots.Bonus[rarity] * (egg.BonusScale or 1))
				mark("FirstMascot")
			end
		end
		for i = #E.Crates, 1, -1 do
			local crate = E.Crates[i]
			while crate.Price <= budget and s.Coins >= crate.Price and (s.CrateCount[crate.Id] or 0) < S.MaxCrates do
				s.Coins -= crate.Price
				s.CrateCount[crate.Id] = (s.CrateCount[crate.Id] or 0) + 1
				openCrate(config, s, rng, crate, byRarity)
				mark("FirstCrateOpened")
			end
		end
	end

	local function zoneUnlocks()
		for index, zone in E.Zones do
			if s.Rank >= zone.Rank and index > s.Zone then
				s.Zone = index
				mark("Zone" .. index)
			end
		end
	end

	while time < S.Minutes * 60 do
		time += S.ThrowSeconds
		local zone = E.Zones[s.Zone]
		local level = E.PowerLevels[s.Level]
		local ball = ballMultiplier(config, s)

		local roll = rng:NextNumber()
		local perfect = roll < S.PerfectShare
		local quality
		if perfect then
			quality = F.QualityMax
		elseif roll < S.GoodShare then
			quality = S.GoodQuality[1] + rng:NextNumber() * (S.GoodQuality[2] - S.GoodQuality[1])
		else
			quality = S.BadQuality[1] + rng:NextNumber() * (S.BadQuality[2] - S.BadQuality[1])
		end
		quality = math.clamp(quality, F.QualityMin, F.QualityMax)

		local pinsHit = math.min(zone.Pins, math.floor(level.Power * quality))
		-- Live rules: only a PERFECT strikes, the streak tier sets the multiplier (Config.Streaks), the lane modifier
		-- changes every Config.LaneModifiers.Interval seconds, and a Golden Pin pays when one of the pins hit is golden
		local strike = perfect and pinsHit >= zone.Pins
		s.Streak = if strike then s.Streak + 1 else 0
		if time >= modifierEnds then
			modifier = pickModifier(config, rng)
			modifierEnds = time + config.LaneModifiers.Interval
		end
		local golden = rng:NextNumber() < config.GoldenPin.Chance and rng:NextInteger(1, 10) <= pinsHit
		local multiplier = level.Value
			* ball
			* mascotMultiplier(E, s)
			* (1 + F.RankBonus * s.Rank)
			* (1 + F.RebirthBonus * s.Rebirths)
			* streakMultiplier(config, s.Streak)
			* (if perfect then F.PerfectCrit else 1)
			* (modifier.CoinMultiplier or 1)
			* (if golden then config.GoldenPin.CoinMultiplier else 1)
		s.Coins += math.floor(pinsHit * zone.PinValue * multiplier)
		-- Pets boost XP by the same amount they boost coins (owner 2026-10-22)
		s.XP +=
			math.floor(pinsHit * zone.XpPerPin * mascotMultiplier(E, s) * (1 + (E.Rebirth.XpBonus or 0) * s.Rebirths))
		if S.Trace then -- tuning scripts can watch every throw
			S.Trace(time, s, { Ball = ball, Mascots = mascotMultiplier(E, s), Pins = pinsHit, Multiplier = multiplier })
		end

		while s.Rank < E.Ranks.MaxRank and s.XP >= xpToNext(E, s.Rank) do
			s.XP -= xpToNext(E, s.Rank)
			s.Rank += 1
			mark("Rank" .. s.Rank)
		end
		zoneUnlocks()

		if s.Coins >= E.Crates[1].Price then
			mark("FirstCrate")
		end
		if eggUnlocked(E.Eggs[1], s) and s.Coins >= E.Eggs[1].Price then
			mark("FirstEgg")
		end

		local needRank, needCoins = rebirthNeeds(E, s)
		if s.Rank >= needRank and s.Coins >= needCoins then
			mark("RebirthReady")
			if s.Rebirths < S.Rebirths then
				s.Rebirths += 1
				s.RunStart = time
				s.Coins, s.XP, s.Rank, s.Level, s.Zone, s.Streak = 0, 0, 1, 1, 1, 0
				mark("Start") -- marks 0 for the new run
				continue
			end
		end
		buy()
	end
	return reached
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
	for _, unit in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if n >= unit[1] then
			return ("%g%s"):format(math.floor(n / unit[1] * 10 + 0.5) / 10, unit[2])
		end
	end
	return tostring(n)
end

-- Runs Config.Economy.Sim.Runs players and returns { [goal] = { Median = seconds?, Share = 0..1 } }.
-- config: leave out to use the current Config (tuning scripts pass an edited copy).
function EconomySim.Simulate(config: any?)
	config = config or loadConfig()
	local S = config.Economy.Sim
	local all: { [string]: { number } } = {}
	for run = 1, S.Runs do
		for goal, seconds in EconomySim.RunOne(config, run) do
			all[goal] = all[goal] or {}
			table.insert(all[goal], seconds)
		end
	end
	local results = {}
	for goal, list in all do
		results[goal] = { Median = median(list), Share = #list / S.Runs }
	end
	return results, config
end

-- Checks the content rules that don't need a simulation. Returns a list of problems (empty = fine).
function EconomySim.CheckRules(config): { string }
	local problems = {}
	local E = config.Economy
	local byRarity = crateBallsByRarity(config)
	for _, crate in E.Crates do
		local total = 0
		for rarity, weight in crate.Odds do
			total += weight
			if weight > 0 and not byRarity[rarity] then
				table.insert(
					problems,
					("%s crate can roll %s, but no ball of that rarity is in crates"):format(crate.Id, rarity)
				)
			end
		end
		if math.abs(total - 100) > 1e-6 then
			table.insert(problems, ("%s crate odds add up to %g, not 100"):format(crate.Id, total))
		end
	end
	-- Every crate ball must be reachable from at least one crate (Addendum 1)
	for _, ball in config.Balls do
		if ball.InCrates ~= false then
			local found = false
			for _, crate in E.Crates do
				if (crate.Odds[ball.Rarity] or 0) > 0 then
					found = true
				end
			end
			if not found then
				table.insert(problems, ball.Name .. " is not in any crate")
			end
		end
	end
	return problems
end

-- Prints (and returns) the report: the plan's timeline first, then every Power Level, rank, zone and rebirth.
function EconomySim.Run(config: any?): string
	local results
	results, config = EconomySim.Simulate(config)
	local E = config.Economy
	local lines = {}
	local function add(text: string)
		table.insert(lines, text)
	end
	local function get(goal: string): number?
		return results[goal] and results[goal].Median
	end

	add(
		("ECONOMY SIMULATOR - %d players, 1 throw every %ds, %d%% good timing"):format(
			E.Sim.Runs,
			E.Sim.ThrowSeconds,
			E.Sim.GoodShare * 100
		)
	)
	for _, problem in EconomySim.CheckRules(config) do
		add("RULE PROBLEM: " .. problem)
	end
	add("")
	add("PLAN TIMELINE                     target        simulated   check")
	local mismatches = 0
	for _, row in E.Timeline do
		local seconds = get(row.Goal)
		local minutes = seconds and seconds / 60
		local tolerance = E.Sim.ToleranceShare
		local check
		if not minutes then
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
	add("POWER LEVELS (first run)")
	for level = 2, #E.PowerLevels do
		local share = results["Level" .. level] and results["Level" .. level].Share or 0
		add(
			("  Level %-2d  %-9s  price %-6s%s"):format(
				level,
				clock(get("Level" .. level)),
				short(E.PowerLevels[level].Price),
				if share > 0 and share < 1 then ("  (%d%% of players)"):format(share * 100) else ""
			)
		)
	end
	add("RANKS (first run)")
	local rankLine = {}
	for _, rank in { 2, 3, 5, 8, 10, 12, 15, 20, 22, 25, 30, 35, 40, 50, 60 } do
		table.insert(rankLine, ("r%d %s"):format(rank, clock(get("Rank" .. rank))))
	end
	add("  " .. table.concat(rankLine, " | "))
	add("ZONES (first run)")
	for index = 2, #E.Zones do
		add(("  Zone %d %-15s %s"):format(index, E.Zones[index].Name, clock(get("Zone" .. index))))
	end
	add(("FIRST MASCOT %s   FIRST CRATE OPENED %s"):format(clock(get("FirstMascot")), clock(get("FirstCrateOpened"))))
	add("REBIRTHS")
	add(("  First rebirth ready  %s"):format(clock(get("RebirthReady"))))
	for n = 1, E.Sim.Rebirths do
		local tag = "@R" .. n
		if results["Start" .. tag] then
			local zone3 = get("Zone3" .. tag)
			local firstZone3 = get("Zone3")
			add(
				("  Run %d: Zone 2 %s, Zone 3 %s (%s of the first run; plan wants about 40%%), next rebirth %s"):format(
					n + 1,
					clock(get("Zone2" .. tag)),
					clock(zone3),
					if zone3 and firstZone3 then ("%d%%"):format(zone3 / firstZone3 * 100) else "?",
					clock(get("RebirthReady" .. tag))
				)
			)
		end
	end

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
	row("First crate (Basic)", E.Crates[1].Price, "FirstCrate")
	previous = 0 -- the crate is a side purchase; Power Level waits count from the start
	for level = 2, #E.PowerLevels do
		row("Power Level " .. level, E.PowerLevels[level].Price, "Level" .. level)
	end
	local zones = {}
	for index = 2, #E.Zones do
		table.insert(zones, ("%d at %s"):format(index, clock(at("Zone" .. index))))
	end
	add("Zones open: " .. table.concat(zones, ", "))
	add("First rebirth ready: " .. clock(at("RebirthReady")))
	local report = table.concat(lines, "\n")
	print(report)
	return report
end

return EconomySim
