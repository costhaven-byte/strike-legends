-- Zone rules both server and client use: which zones a player has open, which crates you can open there, and
-- which balls a crate can give. Zones open by REBIRTHS (owner 2026-10-27: Config.Economy.Zones Rebirths, zone 2 =
-- 1 rebirth, zone 3 = 3, zone 4 = 5). The save keeps the highest open zone (ZonesOpen, v24), so the zone
-- functions below take that number, not a rank level.
local Config = require(script.Parent.Parent.Config)

local Zones = {}

-- Rebirths a zone opens at (zone 1 is always open)
function Zones.UnlockRebirths(zone: number): number
	local row = Config.Economy.Zones[zone]
	return if zone <= 1 then 0 elseif row and row.Rebirths then row.Rebirths else math.huge
end

-- "1 REBIRTH" / "3 REBIRTHS": what a locked zone needs, for signs and cards
function Zones.NeedText(zone: number): string
	local need = Zones.UnlockRebirths(zone)
	return ("%d REBIRTH%s"):format(need, if need == 1 then "" else "S")
end

-- Highest built zone this many rebirths opens
function Zones.ForRebirths(rebirths: number?): number
	local highest = 1
	for zone = 2, Config.Zones.BuiltZones do
		if (rebirths or 0) >= Zones.UnlockRebirths(zone) then
			highest = zone
		end
	end
	return highest
end

-- How much more a throw pays in this zone than in zone 1 (Config.Economy.Zones CoinPay / XpPay, economy pass E2)
function Zones.CoinPay(zone: number): number
	local row = Config.Economy.Zones[zone]
	return row and row.CoinPay or 1
end

function Zones.XpPay(zone: number): number
	local row = Config.Economy.Zones[zone]
	return row and row.XpPay or 1
end

function Zones.Name(zone: number): string
	local row = Config.Economy.Zones[zone]
	return if row then row.Name else ("Zone %d"):format(zone)
end

-- zonesOpen = the player's ZonesOpen (saved; attribute on the client)
function Zones.Unlocked(zonesOpen: number?, zone: number): boolean
	return zone <= (zonesOpen or 1)
end

-- Highest open zone, counting only zones that are built (Config.Zones.BuiltZones)
function Zones.Highest(zonesOpen: number?): number
	return math.clamp(zonesOpen or 1, 1, Config.Zones.BuiltZones)
end

-- A crate can be opened once its zone (Config.Crates Zone) is unlocked
function Zones.CrateUnlocked(crate, zonesOpen: number?): boolean
	return Zones.Unlocked(zonesOpen, crate.Zone or 1)
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
function Zones.RewardCrateId(crateId: string?, zonesOpen: number?): string?
	if not crateId then
		return nil
	end
	for _, crate in Config.Crates do
		if crate.Id == crateId then
			if Zones.CrateUnlocked(crate, zonesOpen) then
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
