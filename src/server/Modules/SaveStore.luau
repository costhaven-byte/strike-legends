-- Loads and saves one player's data in a DataStore, safely.
-- Each save holds a "session lock" naming the server using it, so two servers never overwrite each other.
-- Saved record: { Version = number, Data = { Coins = ..., OwnedBalls = { ... }, ... }, Lock = { JobId = string, Time = number }? }
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Progression = require(Shared.Modules.Progression)
local CoreLadder = require(Shared.Modules.CoreLadder)
local Currency = require(Shared.Modules.Currency)
local Zones = require(Shared.Modules.Zones)

local DATA = Config.Data

local SaveStore = {}

local okStore, store = pcall(function()
	return DataStoreService:GetDataStore(DATA.StoreName)
end)
-- False in Studio when the place is not published; then nothing is saved.
SaveStore.Enabled = okStore

-- Copies nested tables too, so players never share a table and saves never see later changes
local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in value :: any do
		copy[key] = deepCopy(inner)
	end
	return copy :: any
end
SaveStore.DeepCopy = deepCopy

-- Fresh starting data for a new player
function SaveStore.DefaultData(): { [string]: any }
	return deepCopy(Config.StartingData)
end

local function keyFor(userId: number): string
	return "Player_" .. userId
end

-- Calls fn, retrying with a growing wait if Roblox's DataStore errors.
local function withRetries(label: string, fn: () -> ()): boolean
	for attempt = 1, DATA.MaxRetries do
		local ok, err = pcall(fn)
		if ok then
			return true
		end
		warn(("[SaveStore] %s failed (attempt %d/%d): %s"):format(label, attempt, DATA.MaxRetries, tostring(err)))
		local message = tostring(err):lower()
		if message:find("studioaccesstoapisnotallowed") or message:find("studio access to apis is not allowed") then
			-- Studio without API access: retrying will never work, so switch saving off for this session
			SaveStore.Enabled = false
			return false
		end
		if attempt < DATA.MaxRetries then
			task.wait(DATA.RetryDelay * attempt)
		end
	end
	return false
end

-- Rank XP thresholds before v4. Kept frozen here so old saves are upgraded with the rules they were earned under.
local V3_RANK_XP = { 0, 100, 350, 1000, 3000, 9000, 25000, 70000, 200000, 550000 }

-- Pet slot rules before v30, frozen the same way: 3 slots, +1 at rank levels 15 and 30, +1 at 1 rebirth, max 6
local V29_SLOTS = { Start = 3, Ranks = { 15, 30 }, Rebirths = { 1 }, Max = 6 }

-- Turns a saved record (any version, or nil for a new player) into current-format data.
-- Keys missing from an old save get their starting value, so new fields need no upgrade step.
local function migrate(saved: any): { [string]: any }
	local data = SaveStore.DefaultData()
	if type(saved) == "table" and type(saved.Data) == "table" then
		for key, value in saved.Data do
			data[key] = value
		end

		-- Upgrade steps, oldest first, for fields that changed meaning
		local version = tonumber(saved.Version) or 1
		if version < 4 then
			-- v4: rank is saved on its own (it used to come from XP) and thresholds went up.
			-- Players keep the rank they had already reached, so nobody gets demoted.
			local rank = 1
			for index, xp in V3_RANK_XP do
				if (tonumber(data.XP) or 0) >= xp then
					rank = index
				end
			end
			data.Rank = rank
		end
		-- v5 added CrateStrikes and FreeCrates: new keys start at their starting value (0), nothing to upgrade
		-- v6 added PlayTime: same, it starts at 0
		-- v7 added SessionLog: same, it starts empty
		-- v8 added PowerLevel: same, everyone starts at Power Level 1
		if version < 9 then
			-- v9 added the first-3-minutes path (Onboarding). Players who already played skip it.
			data.Onboarding = 3
		end
		if version < 10 then
			-- v10: 5 crates with pity per crate, Polish Points and CratesOpened (new keys start empty / at 0).
			-- Anyone who already owns a ball besides the starter has opened a crate: no second "first crate".
			local owned = 0
			for _ in (if type(data.OwnedBalls) == "table" then data.OwnedBalls else {}) do
				owned += 1
			end
			if owned > 1 then
				data.CratesOpened = 1
			end
		end
		if version < 11 then
			-- v11 added CratesBought (the "next goal" bar points at the first crate until one is bought).
			-- Players who already opened a crate don't need that pointer.
			if (tonumber(data.CratesOpened) or 0) > 0 then
				data.CratesBought = 1
			end
		end
		if version < 12 then
			-- v12: 60 rank levels; a tier's XP now comes from the level curve. Keep the tier, and raise XP to at
			-- least that tier's XP so nobody drops back. Levels already reached give no back-dated rewards.
			local tier = math.clamp(math.floor(tonumber(data.Rank) or 1), 1, #Config.Ranks)
			data.XP = math.max(tonumber(data.XP) or 0, Progression.TierXP(tier))
			data.RankLevel = Progression.LevelFromXP(data.XP, tier)
		end
		-- v13 added Mascots, EquippedMascots and EggsHatched: new keys start empty / at 0, nothing to upgrade
		-- v14 added ZoneSeen, v15 Potions and Boosts, v16 FreeEggs, v17 SpinDay, v18 BossNextAt and Rebirths,
		-- v19 LastOnline and AwayRate: same, they start at their starting value (0 = no away coins on the first visit)
		-- v20 Purchases, StarterPack and StarterOffered, v21 RobuxBoost and VipGiftDay: same, they start empty / at 0
		-- v23 added Cosmetics and EquippedCosmetics (step 12b): they start empty, nothing to upgrade
		-- v25 added EquipBestHinted (Polish P4): it starts at 0, nothing to upgrade
		-- v26 added TotalThrows, TotalStrikes, TotalPerfects, LifetimeCoins, BossWins and AchievementTiers (Polish P5
		-- profile): they start at 0 / empty and count from now on (pins, eggs, crates, streak, rebirths, play time were
		-- already saved, so those achievements count everything an old player did)
		-- v27 added Settings (SETTINGS window switches): it starts empty = everything on, nothing to upgrade
		-- v28 added PolishHinted (batch B3 POLISH lesson): it starts at 0, nothing to upgrade
		-- v29 added PlaytimeDay, PlaytimeSeconds and PlaytimeGot (batch B4 playtime gifts once a day): they start at 0 /
		-- empty = a fresh day of gifts, nothing to upgrade
		-- v30 added PetSlotsKept (see below) and EggPrompted (first egg popup): EggPrompted starts at 0, and players
		-- who already hatched an egg never see the popup anyway
		-- v31 added AutoDelete (batch C3 X'd pets on the egg odds boards): it starts empty, nothing to upgrade or delete
		-- v32 added BestLevel and BestRank (batch D1: rebirths reset levels): they start at the save's level and tier,
		-- see below, so levels and ranks already rewarded never pay twice
		-- v33 added Bag, BagLevel, ThrowSpeedLevel, CoreThrows and CoreSells (Addendum 4 core loop): they start at
		-- their starting values, every older field stays as it was
		-- v34 added BallStep (Addendum 4 Stage 2 ball ladder): it starts at 1, every older field stays as it was
		-- v35 added PetSlotsBought (Addendum 5 B1 coin pet slots): it starts at 0; slots an old save had (PetSlotsKept)
		-- still count, so nobody loses a slot
		-- v36 added Pacing (Addendum 5 E pacing record): it starts empty, nothing to upgrade
		if version < 37 then
			-- v37 (Addendum 6 2.2): balls and bags are owned one by one now (buy any one above your best). Before,
			-- they could only be bought in order, so an old save owns every ball and bag up to its best; it throws
			-- with its best ball's look (CoreLook 0).
			local ball = math.clamp(math.floor(tonumber(data.BallStep) or 1), 1, #Config.CoreLoop.Balls)
			local bag = math.clamp(math.floor(tonumber(data.BagLevel) or 1), 1, #Config.CoreLoop.BagSizes)
			data.CoreBallsOwned = 2 ^ ball - 1
			data.CoreBagsOwned = 2 ^ bag - 1
			data.CoreLook = 0
		end
		if version < 22 then
			-- v22: the COIN BOOST became a doubling ladder (x2, x4, x8, x16). An old adding boost (coins x (1 +
			-- RobuxBoost)) becomes the highest step it already reached or passed, so nobody loses what they paid for.
			local old = 1 + math.max(0, tonumber(data.RobuxBoost) or 0)
			local level = 0
			while level < 4 and 2 ^ (level + 1) <= old do
				level += 1
			end
			if old > 1 and level == 0 then
				level = 1
			end
			data.CoinBoostLevel = math.max(tonumber(data.CoinBoostLevel) or 0, level)
			data.RobuxBoost = 0
		end
		if version < 24 then
			-- v24: zones open by rebirths now (owner 2026-10-27), not by rank level. Nobody loses a zone they already
			-- reached: the old level rule (Config.Economy.Zones Rank) and every zone's unlock window already seen count.
			local level = tonumber(data.RankLevel) or 1
			local reached = math.max(1, math.floor(tonumber(data.ZoneSeen) or 1))
			for zone = 2, Config.Zones.BuiltZones do
				local row = Config.Economy.Zones[zone]
				if row and row.Rank and level >= row.Rank then
					reached = math.max(reached, zone)
				end
			end
			data.ZonesOpen = math.max(tonumber(data.ZonesOpen) or 1, reached)
			data.ZoneVisited = data.ZonesOpen -- they know the way already: no walk guide for old players
		end
		if version < 30 then
			-- v30: pet slots come from rebirths now (batch C1). Old players keep every slot the old rules gave them,
			-- so no equipped pet is taken off (the +2 PET SLOTS pass still adds on top, as before).
			local level = tonumber(data.RankLevel) or 1
			local rebirths = tonumber(data.Rebirths) or 0
			local kept = V29_SLOTS.Start
			for _, rank in V29_SLOTS.Ranks do
				if level >= rank then
					kept += 1
				end
			end
			for _, needed in V29_SLOTS.Rebirths do
				if rebirths >= needed then
					kept += 1
				end
			end
			data.PetSlotsKept = math.max(tonumber(data.PetSlotsKept) or 0, math.min(kept, V29_SLOTS.Max))
		end
		-- v39 added Tutorial (Polish v2): a save from before it that already sold, bought or rebirthed knows the loop,
		-- so it counts as done (no rewards); one that never sold starts at 0
		if version < 39 then
			local knows = (tonumber(data.CoreSells) or 0) > 0
				or (tonumber(data.BallStep) or 1) >= 2
				or (tonumber(data.Rebirths) or 0) > 0
			data.Tutorial = if knows then #Config.Tutorial.Steps else 0
		end
	end
	-- Rebirths done always keep their zones open (also when a later update moves a zone's rebirth count)
	data.ZonesOpen =
		math.max(math.floor(tonumber(data.ZonesOpen) or 1), Zones.ForRebirths(tonumber(data.Rebirths) or 0))
	data.Rank = math.clamp(math.floor(tonumber(data.Rank) or 1), 1, #Config.Ranks)
	-- Best-ever level and tier are never below the current ones (v32; also covers any later save)
	data.BestLevel = math.max(math.floor(tonumber(data.BestLevel) or 1), math.floor(tonumber(data.RankLevel) or 1))
	data.BestRank = math.clamp(math.max(math.floor(tonumber(data.BestRank) or 1), data.Rank), 1, #Config.Ranks)
	-- Addendum 6 2.2: you always own the first ball / bag and your best one (v37; also covers any later save)
	data.CoreBallsOwned = CoreLadder.WithStep(
		CoreLadder.WithStep(tonumber(data.CoreBallsOwned) or 1, 1),
		CoreLadder.BallStep(data.BallStep)
	)
	data.CoreBagsOwned = CoreLadder.WithStep(
		CoreLadder.WithStep(tonumber(data.CoreBagsOwned) or 1, 1),
		CoreLadder.BagLevel(data.BagLevel)
	)
	-- Addendum 6 Stage 3 (v38 CoreZonesOpen + CoreZone, both start at 1, nothing to upgrade): the zones open always
	-- cover the zones of your best ball and bag, and the zone you come back to is an open one (also any later save)
	data.CoreZonesOpen = math.max(
		CoreLadder.ZonesOpen(data.CoreZonesOpen),
		CoreLadder.Zone("Ball", CoreLadder.BallStep(data.BallStep)),
		CoreLadder.Zone("Bag", CoreLadder.BagLevel(data.BagLevel))
	)
	data.CoreZone = math.min(CoreLadder.ZonesOpen(data.CoreZone), data.CoreZonesOpen)
	-- Polish v2 U3 (v40 PetsFound): every pet you own counts as found (fills it for old saves, and keeps it right for
	-- any later save); a Shiny counts its plain pet too
	if type(data.PetsFound) ~= "table" then
		data.PetsFound = {}
	end
	if type(data.Mascots) == "table" then
		for id, count in data.Mascots do
			if type(id) == "string" and (tonumber(count) or 0) > 0 then
				data.PetsFound[id] = true
				data.PetsFound[(id:gsub("_Shiny$", ""))] = true
			end
		end
	end
	-- Money comes back through Currency, so a future number format can read old plain-number saves here
	for _, key in Config.Numbers.Currencies do
		data[key] = Currency.Decode(data[key])
	end
	return data
end

-- Returns the player's data and takes the session lock, or nil if the DataStore could not be reached.
function SaveStore.Load(userId: number): { [string]: any }?
	if not SaveStore.Enabled then
		return nil
	end
	for lockTry = 1, DATA.LockWaitTries + 1 do
		local result: any = nil
		local locked = false
		local ok = withRetries("Load " .. userId, function()
			store:UpdateAsync(keyFor(userId), function(saved)
				saved = if type(saved) == "table" then saved else {}
				local lock = saved.Lock
				local now = os.time()
				local heldElsewhere = lock and lock.JobId ~= game.JobId and now - lock.Time < DATA.LockTimeout
				if heldElsewhere and lockTry <= DATA.LockWaitTries then
					locked = true
					return nil -- leave the record untouched, try again shortly
				end
				locked = false
				result = saved
				saved.Version = saved.Version or DATA.SchemaVersion
				saved.Lock = { JobId = game.JobId, Time = now }
				return saved
			end)
		end)
		if not ok then
			return nil
		end
		if not locked then
			return migrate(result)
		end
		task.wait(DATA.LockWaitDelay)
	end
	return nil
end

-- Saves data. release = true also gives up the session lock (player left or server closing).
-- Returns false if saving failed or another server has taken over this player.
function SaveStore.Save(userId: number, data: { [string]: any }, release: boolean): boolean
	if not SaveStore.Enabled then
		return false
	end
	local snapshot = deepCopy(data)
	for _, key in Config.Numbers.Currencies do
		if snapshot[key] ~= nil then
			snapshot[key] = Currency.Encode(snapshot[key])
		end
	end
	local lostLock = false
	local ok = withRetries("Save " .. userId, function()
		store:UpdateAsync(keyFor(userId), function(saved)
			saved = if type(saved) == "table" then saved else {}
			if saved.Lock and saved.Lock.JobId ~= game.JobId then
				lostLock = true
				return nil -- another server owns this player now; never overwrite its data
			end
			lostLock = false
			saved.Version = DATA.SchemaVersion
			saved.Data = snapshot
			saved.Lock = if release then nil else { JobId = game.JobId, Time = os.time() }
			return saved
		end)
	end)
	if lostLock then
		warn(("[SaveStore] Skipped save for %d: another server has this player's data"):format(userId))
	end
	return ok and not lostLock
end

return SaveStore
