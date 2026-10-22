-- Mascot (pet) rules shared by the server and the client: lookups, bonuses, slots, eggs, and the text format
-- the server uses to publish a player's mascots in attributes.
-- Data: Config.Mascots (each mascot), Config.EggLooks, Config.Economy.Eggs and Config.Economy.Mascots (numbers).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Zones = require(script.Parent.Zones)

local ECONOMY = Config.Economy.Mascots

local Mascots = {}

local byId = {}
for _, mascot in Config.Mascots do
	byId[mascot.Id] = mascot
end

local eggById = {}
for _, egg in Config.Economy.Eggs do
	eggById[egg.Id] = egg
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

-- The mascots an egg can hatch
function Mascots.InEgg(eggId: string): { any }
	local list = {}
	for _, mascot in Config.Mascots do
		if mascot.Egg == eggId then
			table.insert(list, mascot)
		end
	end
	return list
end

-- Every pet in an egg must sit inside its egg's zone rarity range (Config.ZoneRarity): say so in Output if not
for _, mascot in Config.Mascots do
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

-- An egg has mascots to hatch (eggs for zones 2 to 5 get theirs later)
function Mascots.EggReady(eggId: string): boolean
	return #Mascots.InEgg(eggId) > 0
end

-- This mascot's bonus: its rarity's bonus x its egg's BonusScale (0.02 = +2% coins).
-- Phase X: BaseBonus replaces the rarity's bonus (a re-rated pet keeps its old power) and BonusEgg the egg whose
-- BonusScale counts (pets cut from an egg keep that egg's).
function Mascots.Bonus(mascot): number
	local egg = eggById[mascot.BonusEgg or mascot.Egg]
	local bonus = (mascot.BaseBonus or ECONOMY.Bonus[mascot.Rarity] or 0) * (egg and egg.BonusScale or 1)
	return if mascot.Shiny then bonus * ECONOMY.ShinyMultiplier else bonus
end

-- "+2%", "+150%"
function Mascots.BonusText(bonus: number): string
	return ("+%d%%"):format(math.floor(bonus * 100 + 0.5))
end

-- Equip slots: StartSlots, +1 for each of SlotRanks reached (rank level) and SlotRebirths, up to MaxSlots
function Mascots.Slots(rankLevel: number, rebirths: number): number
	local count = ECONOMY.StartSlots
	for _, rank in ECONOMY.SlotRanks do
		if rankLevel >= rank then
			count += 1
		end
	end
	for _, needed in ECONOMY.SlotRebirths do
		if rebirths >= needed then
			count += 1
		end
	end
	return math.min(count, ECONOMY.MaxSlots)
end

-- The next locked slot's unlock, as text ("RANK LEVEL 15"), or nil when all slots are open
function Mascots.NextSlotText(rankLevel: number): string?
	for _, rank in ECONOMY.SlotRanks do
		if rankLevel < rank then
			return ("LEVEL %d"):format(rank)
		end
	end
	if #ECONOMY.SlotRebirths > 0 then
		return "REBIRTH"
	end
	return nil
end

-- Can this player hatch the egg? Returns false and the reason ("LEVEL 3", "ZONE 2") when locked.
-- Zones 2 to 6 aren't built yet, so zone eggs stay locked for now.
function Mascots.EggUnlocked(egg, rankLevel: number, zone: number): (boolean, string?)
	if egg.Rank and rankLevel < egg.Rank then
		return false, ("LEVEL %d"):format(egg.Rank)
	end
	if egg.Zone and zone < egg.Zone then
		return false, ("LEVEL %d"):format(Zones.UnlockLevel(egg.Zone))
	end
	return true, nil
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

-- The best mascots to equip from what's owned (biggest bonus first, rarer first on a tie), up to slots
function Mascots.Best(owned: { [string]: number }, slots: number): { string }
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
		local ba, bb = Mascots.Bonus(a), Mascots.Bonus(b)
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
