-- Zone rules both server and client use: which zones a rank level has unlocked, which crates you can open
-- there, and which balls a crate can give. Unlock levels: Config.Economy.Zones Rank (a rank level, 1-60).
local Config = require(script.Parent.Parent.Config)

local Zones = {}

-- The rank level a zone opens at (zone 1 is always open)
function Zones.UnlockLevel(zone: number): number
	local row = Config.Economy.Zones[zone]
	return if row then row.Rank else math.huge
end

function Zones.Name(zone: number): string
	local row = Config.Economy.Zones[zone]
	return if row then row.Name else ("Zone %d"):format(zone)
end

function Zones.Unlocked(rankLevel: number?, zone: number): boolean
	return zone <= 1 or (rankLevel or 1) >= Zones.UnlockLevel(zone)
end

-- Highest zone this rank level has opened, counting only zones that are built (Config.Zones.BuiltZones)
function Zones.Highest(rankLevel: number?): number
	local highest = 1
	for zone = 2, Config.Zones.BuiltZones do
		if Zones.Unlocked(rankLevel, zone) then
			highest = zone
		end
	end
	return highest
end

-- A crate can be opened once its zone (Config.Crates Zone) is unlocked
function Zones.CrateUnlocked(crate, rankLevel: number?): boolean
	return Zones.Unlocked(rankLevel, crate.Zone or 1)
end

-- Can this crate give this ball? ZoneBallsOnly crates (the Alley Crate) only give their own zone's balls
-- (Config.Balls Zone); the other crates give any crate ball, as before.
function Zones.BallInCrate(ball, crate): boolean
	if ball.InCrates == false or ball.Retired then
		return false -- the starter ball, and balls Phase X took out of their zone (owners keep them)
	end
	if crate and crate.ZoneBallsOnly then
		return ball.Zone == crate.Zone
	end
	return true
end

-- The crate a reward really gives: a crate from a zone you haven't unlocked yet becomes your zone's crate
-- (the day 7 Gold Crate is an Alley Crate until Neon Lanes opens)
function Zones.RewardCrateId(crateId: string?, rankLevel: number?): string?
	if not crateId then
		return nil
	end
	for _, crate in Config.Crates do
		if crate.Id == crateId then
			if Zones.CrateUnlocked(crate, rankLevel) then
				return crateId
			end
			break
		end
	end
	return Config.Rizzo.CrateId
end

-- Is this rarity inside the zone's range (Config.ZoneRarity)? Zones without a range allow anything.
function Zones.RarityAllowed(zone: number, rarityName: string): boolean
	local range = Config.ZoneRarity[zone]
	if not range then
		return true
	end
	local index, low, high = 0, 0, 0
	for i, rarity in Config.Rarities do
		if rarity.Name == rarityName then
			index = i
		end
		if rarity.Name == range.Min then
			low = i
		end
		if rarity.Name == range.Max then
			high = i
		end
	end
	return index >= low and index <= high
end

-- True if the position is inside an Area box ({ Center, Size })
function Zones.InArea(area, position: Vector3): boolean
	local offset = position - area.Center
	local half = area.Size / 2
	return math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z
end

return Zones
