-- Mascot (pet) rules shared by the server and the client: lookups, bonuses, slots, eggs, and the text format
-- the server uses to publish a player's mascots in attributes.
-- Data: Config.Mascots (each mascot), Config.EggLooks, Config.Economy.Eggs and Config.Economy.Mascots (numbers).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Currency = require(script.Parent.Currency)
local Zones = require(script.Parent.Zones)

local ECONOMY = Config.Economy.Mascots
local STATS = Config.PetStats

local Mascots = {}

local byId = {}
for _, mascot in Config.Mascots do
	byId[mascot.Id] = mascot
end

-- Addendum 5 B2: the roof's egg ladder (Config.CoreLoop.Eggs) replaces the zone eggs in the core loop: same Ids
-- (Alley, Arcade, Skyline, Volcano), their own Price, Odds and Pets, no zone gate
local CORE_EGGS = Config.CoreLoop.Enabled and Config.CoreLoop.Eggs and Config.CoreLoop.Eggs.Enabled
local eggById = {}
for _, egg in Config.Economy.Eggs do
	eggById[egg.Id] = egg
end
local corePools: { [string]: { any } } = {}
if CORE_EGGS then
	for tier, row in Config.CoreLoop.Eggs.List do
		local egg = table.clone(row)
		egg.Tier = tier
		eggById[row.Id] = egg
	end
end

-- Rarity names, commonest first
Mascots.Rarities = {}
for _, rarity in Config.Rarities do
	table.insert(Mascots.Rarities, rarity.Name)
end

local rarityIndex = {}
for index, name in Mascots.Rarities do
	rarityIndex[name] = index
end

-- Shiny mascots (step 8b): ShinyMerge copies of one mascot merge into its Shiny version, saved under its own Id
-- ("Pinny_Shiny") in the same Mascots table, so old saves need no change. Bonus x ShinyMultiplier.
local SHINY_SUFFIX = "_Shiny"

function Mascots.ShinyId(id: string): string
	return id .. SHINY_SUFFIX
end

for _, mascot in Config.Mascots do
	local shiny = table.clone(mascot)
	shiny.Id = Mascots.ShinyId(mascot.Id)
	shiny.Name = "Shiny " .. mascot.Name
	shiny.Shiny = true
	shiny.Base = mascot
	byId[shiny.Id] = shiny
end

function Mascots.Get(id: any)
	return if type(id) == "string" then byId[id] else nil
end

-- How many copies merge into a Shiny, or nil when this mascot can't merge (it's already Shiny)
function Mascots.MergeCost(mascot): number?
	return if mascot.Shiny then nil else ECONOMY.ShinyMerge
end

function Mascots.GetEgg(id: any)
	return if type(id) == "string" then eggById[id] else nil
end

function Mascots.RarityIndex(name: string): number
	return rarityIndex[name] or 1
end

function Mascots.RarityColor(name: string): Color3
	return Config.Rarities[Mascots.RarityIndex(name)].Color
end

-- Addendum 5 B2: the roof's egg ladder is on (Config.CoreLoop.Eggs)
function Mascots.CoreEggsOn(): boolean
	return CORE_EGGS == true
end

-- The roof eggs in price order (Config.CoreLoop.Eggs.List rows with Tier), or {} when off
function Mascots.CoreEggs(): { any }
	local list = {}
	if CORE_EGGS then
		for _, row in Config.CoreLoop.Eggs.List do
			table.insert(list, eggById[row.Id])
		end
	end
	return list
end

-- The rarity odds of an egg: its own Odds on the roof (B2), else the shared Config.Economy.Mascots.Odds
function Mascots.EggOdds(eggId: string): { [string]: number }
	local egg = eggById[eggId]
	return if CORE_EGGS and egg and egg.Odds then egg.Odds else ECONOMY.Odds
end

-- B2: where LUCKY passes start for this egg (Store.LuckyOdds from): on the roof every rarity but the egg's commonest;
-- nil = Config.Monetization.LuckFrom (the zone eggs)
function Mascots.LuckFrom(eggId: string): string?
	local egg = eggById[eggId]
	if not CORE_EGGS or not egg or not egg.Odds then
		return nil
	end
	local found = 0
	for _, rarity in Config.Rarities do
		if (egg.Odds[rarity.Name] or 0) > 0 then
			found += 1
			if found == 2 then
				return rarity.Name
			end
		end
	end
	return nil
end

-- The mascots an egg can hatch (B2, roof eggs: the egg's Pets list)
function Mascots.InEgg(eggId: string): { any }
	if CORE_EGGS then
		local egg = eggById[eggId]
		if not egg or not egg.Pets then
			return {}
		end
		if not corePools[eggId] then
			local pool = {}
			for _, id in egg.Pets do
				if byId[id] then
					table.insert(pool, byId[id])
				end
			end
			corePools[eggId] = pool
		end
		return table.clone(corePools[eggId])
	end
	local list = {}
	for _, mascot in Config.Mascots do
		if mascot.Egg == eggId then
			table.insert(list, mascot)
		end
	end
	return list
end

-- B2: is this pet in any egg (so it can be X'd on that egg's board)?
function Mascots.FromEgg(mascot): boolean
	if CORE_EGGS then
		local id = if mascot.Shiny then mascot.Base.Id else mascot.Id
		for _, row in Config.CoreLoop.Eggs.List do
			if table.find(row.Pets, id) then
				return true
			end
		end
		return false
	end
	return eggById[mascot.Egg] ~= nil
end

-- Every pet in an egg must sit inside its egg's zone rarity range (Config.ZoneRarity): say so in Output if not
-- (B2: on the roof every egg needs a pet of each rarity it has odds for instead)
if CORE_EGGS then
	for _, row in Config.CoreLoop.Eggs.List do
		for rarity, chance in row.Odds do
			local found = false
			for _, id in row.Pets do
				local mascot = byId[id]
				if not mascot then
					warn(("[Mascots] %s egg: no pet %s (Config.Mascots)"):format(row.Id, id))
				elseif mascot.Rarity == rarity then
					found = true
				end
			end
			if chance > 0 and not found then
				warn(("[Mascots] %s egg has %s odds but no %s pet"):format(row.Id, rarity, rarity))
			end
		end
	end
end
for _, mascot in Config.Mascots do
	if CORE_EGGS then
		break
	end
	local egg = mascot.Egg and eggById[mascot.Egg]
	if egg and egg.Zone and not Zones.RarityAllowed(egg.Zone, mascot.Rarity) then
		warn(
			("[Mascots] %s is %s, outside zone %d's range (Config.ZoneRarity)"):format(
				mascot.Id,
				mascot.Rarity,
				egg.Zone
			)
		)
	end
end

-- The chance one hatch of this egg gives exactly this pet, from rarity odds (already with any luck applied, see
-- Store.LuckyOdds). Only rarities the egg has pets of count; pets of one rarity are equally likely. The server's
-- roll uses the same maths; the hatch card ("1 IN X", Polish P2) and the stand's odds bubbles (P3) show it.
function Mascots.Chance(eggId: string, mascot, odds: { [string]: number }): number
	local present = {}
	local same = 0
	for _, other in Mascots.InEgg(eggId) do
		present[other.Rarity] = true
		if other.Rarity == mascot.Rarity then
			same += 1
		end
	end
	local total = 0
	for _, rarity in Config.Rarities do
		total += if present[rarity.Name] then odds[rarity.Name] or 0 else 0
	end
	if total <= 0 or same == 0 then
		return 0
	end
	return (odds[mascot.Rarity] or 0) / total / same
end

-- An egg has mascots to hatch (eggs for zones 2 to 5 get theirs later)
function Mascots.EggReady(eggId: string): boolean
	return #Mascots.InEgg(eggId) > 0
end

-- Addendum 5 B1: pets give stat boosts (Config.PetStats) in the core loop
function Mascots.StatsOn(): boolean
	return Config.CoreLoop.Enabled and STATS.Enabled == true
end

-- This pet's stats { Coins = 0.5, Pins = 0.2 } (0.5 = +50%), Shiny = every stat x ShinyMultiplier.
-- With stats off: { Coins = its old coin bonus }.
function Mascots.Stats(mascot): { [string]: number }
	if not Mascots.StatsOn() then
		return { Coins = Mascots.Bonus(mascot) }
	end
	local stats = {}
	local base = if mascot.Shiny then mascot.Base else mascot
	for name, value in base.Stats or {} do
		stats[name] = if mascot.Shiny then value * ECONOMY.ShinyMultiplier else value
	end
	return stats
end

-- Every stat of an equipped list (Config.PetStats.Stacking: "Add" adds the same stat up; "Multiply" multiplies each
-- pet's 1 + value). Every stat in Config.PetStats.Order is in the result (0 = none).
function Mascots.TotalStats(list: { string }): { [string]: number }
	local multiply = STATS.Stacking == "Multiply"
	local total = {}
	for _, name in STATS.Order do
		total[name] = if multiply then 1 else 0
	end
	for _, id in list do
		local mascot = byId[id]
		if mascot then
			for name, value in Mascots.Stats(mascot) do
				if multiply then
					total[name] = (total[name] or 1) * (1 + value)
				else
					total[name] = (total[name] or 0) + value
				end
			end
		end
	end
	if multiply then
		for name, value in total do
			total[name] = value - 1
		end
	end
	return total
end

-- "+50%" (0.5), "+1.2K%" for huge ones (Currency format)
function Mascots.PercentText(value: number): string
	local percent = math.floor(value * 100 + 0.5)
	return "+" .. (if percent >= 10000 then Currency.Format(percent) else tostring(percent)) .. "%"
end

-- The stat lines of a stats table, in Config.PetStats.Order: { { Name = "Coins", Text = "+50% Coins", Color } }
function Mascots.StatLines(stats: { [string]: number }): { { Name: string, Text: string, Color: Color3 } }
	local lines = {}
	for _, name in STATS.Order do
		local value = stats[name]
		if value and value > 0 then
			local kind = STATS.Types[name]
			table.insert(lines, {
				Name = name,
				Text = Mascots.PercentText(value) .. " " .. kind.Label,
				Color = kind.Color,
			})
		end
	end
	return lines
end

-- One line of text for a pet or a stats table: "+50% Coins  +20% Pins" (sep between)
function Mascots.StatText(stats: { [string]: number }, sep: string?): string
	local parts = {}
	for _, line in Mascots.StatLines(stats) do
		table.insert(parts, line.Text)
	end
	return if #parts > 0 then table.concat(parts, sep or "  ") else "NO BOOST"
end

-- What a pet gives, in capitals for the pet cards: "+50% COINS  +20% PINS" (stats off: "X1.5 COINS")
function Mascots.BoostText(mascot, sep: string?): string
	if Mascots.StatsOn() then
		return string.upper(Mascots.StatText(Mascots.Stats(mascot), sep))
	end
	return Mascots.BonusText(Mascots.Bonus(mascot)) .. " COINS"
end

-- How good a pet is for EQUIP BEST: its stats added up, each x its Config.PetStats.Types Best weight
function Mascots.Score(mascot): number
	if not Mascots.StatsOn() then
		return Mascots.Bonus(mascot)
	end
	local score = 0
	for name, value in Mascots.Stats(mascot) do
		local kind = STATS.Types[name]
		score += value * (if kind then kind.Best else 1)
	end
	return score
end

-- This mascot's COIN bonus: its rarity's bonus x its egg's BonusScale (0.02 = +2% coins).
-- Phase X: BaseBonus replaces the rarity's bonus (a re-rated pet keeps its old power) and BonusEgg the egg whose
-- BonusScale counts (pets cut from an egg keep that egg's).
-- Addendum 5 B1: with pet stats on it is the pet's Coins stat (0 when it has none).
function Mascots.Bonus(mascot): number
	if Mascots.StatsOn() then
		return Mascots.Stats(mascot).Coins or 0
	end
	local egg = eggById[mascot.BonusEgg or mascot.Egg]
	local bonus = (mascot.BaseBonus or ECONOMY.Bonus[mascot.Rarity] or 0) * (egg and egg.BonusScale or 1)
	return if mascot.Shiny then bonus * ECONOMY.ShinyMultiplier else bonus
end

-- Batch C2 (owner 2026-10-29): a pet bonus shows as the coin multiplier it gives, x(1 + bonus): 0.02 -> "x1.02",
-- 1.5 -> "x2.5" (same format as the multiplier card). Display only; the coin maths still adds the bonuses up and
-- pays x (1 + total).
function Mascots.BonusText(bonus: number): string
	return Currency.FormatMultiplier(1 + bonus)
end

-- Equip slots: StartSlots, +1 for each of SlotRebirths reached, never fewer than kept (save PetSlotsKept: what an
-- old save had under the old rank-level rule), up to MaxSlots, plus extra (the +2 PET SLOTS game pass,
-- Config.Monetization) on top of that
-- Addendum 5 B1 (pet stats on): StartSlots + slots bought with coins (bought), no rebirth slots.
function Mascots.Slots(rebirths: number, extra: number?, kept: number?, bought: number?): number
	if Mascots.StatsOn() then
		local count = ECONOMY.StartSlots + math.clamp(math.floor(bought or 0), 0, #STATS.SlotPrices)
		return math.max(count, kept or 0) + (extra or 0)
	end
	local count = ECONOMY.StartSlots
	for _, needed in ECONOMY.SlotRebirths do
		if rebirths >= needed then
			count += 1
		end
	end
	return math.min(math.max(count, kept or 0), ECONOMY.MaxSlots) + (extra or 0)
end

-- Why each slot past the open ones is still locked ("5 REBIRTHS"), slot by slot; open = slots open without the
-- pass. Rebirth slots an old save already has count as open.
-- (Addendum 5 B1, pet stats on: every slot still to buy shows its coin price, "2.5K")
function Mascots.SlotLocks(rebirths: number, open: number): { string }
	local list = {}
	if Mascots.StatsOn() then
		for i, price in STATS.SlotPrices do
			if ECONOMY.StartSlots + i > open then
				table.insert(list, Currency.Format(price))
			end
		end
		return list
	end
	local count = ECONOMY.StartSlots
	for _, needed in ECONOMY.SlotRebirths do
		count += 1
		if rebirths < needed and count > open then
			table.insert(list, if needed == 1 then "REBIRTH" else ("%d REBIRTHS"):format(needed))
		end
	end
	return list
end

-- Addendum 5 B1: the price of the next coin slot after `bought` slots, or nil when every slot is bought
function Mascots.NextSlotPrice(bought: number?): number?
	return STATS.SlotPrices[math.floor(bought or 0) + 1]
end

-- Can this player hatch the egg? Returns false and the reason ("LEVEL 3", "1 REBIRTH") when locked.
-- zone = the player's highest open zone (Zones.Highest).
function Mascots.EggUnlocked(egg, rankLevel: number, zone: number): (boolean, string?)
	local noLevels = Config.CoreLoop.Enabled and Config.CoreLoop.NoLevels -- (Addendum 5 A1: no level gates)
	if egg.Rank and rankLevel < egg.Rank and not noLevels then
		return false, ("LEVEL %d"):format(egg.Rank)
	end
	if egg.Zone and zone < egg.Zone then
		return false, if egg.Tier then ("ZONE %d"):format(egg.Zone) else Zones.NeedText(egg.Zone)
	end
	return true, nil
end

-- Addendum 6 Stage 4: the zone number EggUnlocked checks. The zone eggs (Config.CoreLoop.Eggs) open with the zones you
-- opened at the gates (CoreZonesOpen), not the old rebirth zones (ZonesOpen)
function Mascots.EggZone(zonesOpen: any, coreZonesOpen: any): number
	if CORE_EGGS and Config.CoreLoop.Zones and Config.CoreLoop.Zones.Enabled then
		return math.max(1, math.floor(tonumber(coreZonesOpen) or 1))
	end
	return Zones.Highest(zonesOpen)
end

-- Owned counts <-> "Pinny=2,Gus=1"
function Mascots.EncodeOwned(owned: { [string]: number }): string
	local parts = {}
	for id, count in owned do
		if count > 0 then
			table.insert(parts, id .. "=" .. count)
		end
	end
	table.sort(parts)
	return table.concat(parts, ",")
end

function Mascots.DecodeOwned(text: any): { [string]: number }
	local owned = {}
	if type(text) == "string" then
		for id, count in text:gmatch("([^,=]+)=(%d+)") do
			owned[id] = tonumber(count)
		end
	end
	return owned
end

-- Equipped list <-> "Pinny,Pinny,Gus"
function Mascots.EncodeEquipped(list: { string }): string
	return table.concat(list, ",")
end

function Mascots.DecodeEquipped(text: any): { string }
	local list = {}
	if type(text) == "string" then
		for id in text:gmatch("[^,]+") do
			table.insert(list, id)
		end
	end
	return list
end

-- Total bonus of an equipped list
function Mascots.TotalBonus(list: { string }): number
	local total = 0
	for _, id in list do
		local mascot = byId[id]
		if mascot then
			total += Mascots.Bonus(mascot)
		end
	end
	return total
end

-- The best mascots to equip from what's owned (biggest bonus first, by Id on a tie), up to slots
-- Addendum 5 F: what EQUIP BEST needs to know about a player to rank pets by real income (Mascots.Income), read from
-- the attributes the server publishes (works on the server and the client). nil = not in the core loop.
function Mascots.BestContext(player: Player): { [string]: number }?
	local core = Config.CoreLoop
	if not Mascots.StatsOn() or not STATS.BestByIncome then
		return nil
	end
	local bagLevel = math.clamp(math.floor(tonumber(player:GetAttribute("BagLevel")) or 1), 1, #core.BagSizes)
	local step = math.clamp(math.floor(tonumber(player:GetAttribute("BallStep")) or 1), 1, #core.Balls)
	-- Addendum 6 1.1: everything but the pets from the one coin / pin multiplier's sources (CoinBoosts / PinBoosts,
	-- formula Config.CoreLoop.Boosts): the other Add bonuses and the Times multipliers
	local function split(kind: string, attribute: string): (number, number)
		local text = tostring(player:GetAttribute(attribute) or "")
		local add, times = 1, 1
		for name, value in text:gmatch("([^;=]+)=([^;]+)") do
			local number = tonumber(value)
			if number and name ~= "Pets" then
				if table.find(core.Boosts[kind].Add, name) then
					add += number
				else
					times *= number
				end
			end
		end
		return add, times
	end
	local coinAdd, coinTimes = split("Coins", "CoinBoosts")
	local pinAdd, pinTimes = split("Pins", "PinBoosts")
	local level = math.max(0, tonumber(player:GetAttribute("ThrowSpeedLevel")) or 0)
	return {
		Bag = core.BagSizes[bagLevel],
		Pins = core.Balls[step].Pins * pinTimes, -- pins a throw before the Add bonuses
		PinAdd = pinAdd,
		CoinAdd = coinAdd,
		PerPin = core.PinValue * coinTimes, -- coins a pin before the Add bonuses
		Cooldown = core.Cooldown - level * core.CooldownStep,
		Floor = core.CooldownFloor,
		Trip = STATS.SellTrip,
	}
end

-- Coins a second a set of pet stats earns for this player (Mascots.BestContext): throw until the bag (in pins) is
-- full, then the sell trip (SELL teleport + walk back) earns nothing; the sell pays pins x the coin multiplier.
-- Pets' Coins and Pins stats add into the Add groups of Config.CoreLoop.Boosts (Addendum 6 1.1).
function Mascots.Income(stats: { [string]: number }, ctx: { [string]: number }): number
	local bag = ctx.Bag * (1 + (stats.Bag or 0))
	local cooldown = math.max(ctx.Floor, ctx.Cooldown / (1 + (stats.Speed or 0)))
	local rate = ctx.Pins * (ctx.PinAdd + (stats.Pins or 0)) / cooldown
	if rate <= 0 then
		return 0
	end
	return bag / (bag / rate + ctx.Trip) * ctx.PerPin * (ctx.CoinAdd + (stats.Coins or 0))
end

-- The pets EQUIP BEST puts out. With a context (Mascots.BestContext): one slot at a time, the pet that raises real
-- income most (so bag pets come out exactly when the bag is what holds you back). Without: by Mascots.Score.
function Mascots.Best(owned: { [string]: number }, slots: number, ctx: { [string]: number }?): { string }
	if ctx then
		local left = table.clone(owned)
		local list = {}
		for _ = 1, slots do
			local pick, best = nil, -1
			for id, count in left do
				if count > 0 and byId[id] then
					table.insert(list, id)
					local income = Mascots.Income(Mascots.TotalStats(list), ctx)
					table.remove(list)
					if income > best + 1e-9 or (math.abs(income - best) <= 1e-9 and pick and id < pick) then
						pick, best = id, income
					end
				end
			end
			if not pick then
				break
			end
			table.insert(list, pick)
			left[pick] -= 1
		end
		return list
	end
	local pool = {}
	for id, count in owned do
		local mascot = byId[id]
		if mascot then
			for _ = 1, count do
				table.insert(pool, mascot)
			end
		end
	end
	table.sort(pool, function(a, b)
		local ba, bb = Mascots.Score(a), Mascots.Score(b) -- (B1: all stats count)
		if ba ~= bb then
			return ba > bb
		end
		return a.Id < b.Id
	end)
	local list = {}
	for i = 1, math.min(slots, #pool) do
		table.insert(list, pool[i].Id)
	end
	return list
end

return Mascots
