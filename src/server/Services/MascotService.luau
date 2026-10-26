-- Mascot eggs, hatching and equipping (Addendum 2 Phase 3 step 8). The server rolls every hatch.
-- Saved: Mascots ({ Id = count }, Shiny versions as "Pinny_Shiny"), EquippedMascots ({ Id, ... } one per slot), EggsHatched,
-- FreeEggs ({ Alley = 1 }: free hatches from playtime gifts, used before coins).
-- Published to everyone as Player attributes (each client draws every player's mascots from them):
--   Mascots "Pinny=2,Gus=1", EquippedMascots "Pinny,Gus", MascotSlots, MascotBonus (0.04 = +4% coins),
--   FreeEgg_<egg Id> (free hatches waiting).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Mascots = require(Shared.Modules.Mascots)
local Zones = require(Shared.Modules.Zones)
local Progression = require(Shared.Modules.Progression)
local Store = require(Shared.Modules.Store)
local Analytics = require(script.Parent.Analytics)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressionService = require(script.Parent.ProgressionService)
local RateLimit = require(script.Parent.Parent.Modules.RateLimit)
local SessionLog = require(script.Parent.Parent.Modules.SessionLog)

local ODDS = Config.Economy.Mascots.Odds
local HATCH_RANGE = Config.MascotFx.HatchRange

local MascotService = {}

local busy: { [Player]: boolean } = {}

local function getOwned(player: Player): { [string]: number }
	return PlayerDataService.Get(player, "Mascots") or {}
end

local function getEquipped(player: Player): { string }
	return PlayerDataService.Get(player, "EquippedMascots") or {}
end

local function slots(player: Player): number
	return Mascots.Slots(
		PlayerDataService.Get(player, "RankLevel") or 1,
		PlayerDataService.Get(player, "Rebirths") or 0,
		Store.PetSlots(player)
	)
end

-- The highest zone the player's rank level has opened (eggs with a Zone unlock there)
local function zone(player: Player): number
	return Zones.Highest(PlayerDataService.Get(player, "RankLevel"))
end

-- Keeps the equipped list valid: real mascots, never more copies than owned, never more than the slots
local function repairEquipped(player: Player)
	local owned = getOwned(player)
	local equipped = getEquipped(player)
	local used = {}
	for i = #equipped, 1, -1 do
		local id = equipped[i]
		used[id] = (used[id] or 0) + 1
		if not Mascots.Get(id) or used[id] > (owned[id] or 0) then
			table.remove(equipped, i)
			used[id] -= 1
		end
	end
	while #equipped > slots(player) do
		table.remove(equipped)
	end
end

local function getFreeEggs(player: Player): { [string]: number }
	local value = PlayerDataService.Get(player, "FreeEggs")
	return if type(value) == "table" then value else {}
end

local function publish(player: Player)
	repairEquipped(player)
	local free = getFreeEggs(player)
	for _, egg in Config.Economy.Eggs do
		player:SetAttribute("FreeEgg_" .. egg.Id, free[egg.Id] or 0)
	end
	local equipped = getEquipped(player)
	player:SetAttribute("Mascots", Mascots.EncodeOwned(getOwned(player)))
	player:SetAttribute("EquippedMascots", Mascots.EncodeEquipped(equipped))
	player:SetAttribute("MascotSlots", slots(player))
	player:SetAttribute("MascotBonus", Mascots.TotalBonus(equipped))
end

-- Coin multiplier from the equipped mascots: 1 + their bonuses added together
function MascotService.GetMultiplier(player: Player): number
	return 1 + Mascots.TotalBonus(getEquipped(player))
end

-- Rolls a rarity with the plan's odds, then a mascot of that rarity from this egg (all equally likely).
-- If the egg has no mascot of the rolled rarity, the closest commoner one it has is used.
local function roll(eggId: string, luck: number)
	-- Phase X: only the rarities this egg has pets of count (zone 3 and 4 eggs start at Rare and Epic)
	local present = {}
	for _, mascot in Mascots.InEgg(eggId) do
		present[mascot.Rarity] = true
	end
	local odds = Store.LuckyOdds(ODDS, luck) -- LUCKY game passes (Config.Monetization)
	local total = 0
	for _, name in Mascots.Rarities do
		total += if present[name] then odds[name] or 0 else 0
	end
	local pick = math.random() * total
	local rarity = Mascots.Rarities[1]
	for _, name in Mascots.Rarities do
		local chance = if present[name] then odds[name] or 0 else 0
		if chance > 0 then
			pick -= chance
			if pick <= 0 then
				rarity = name
				break
			end
		end
	end
	local inEgg = Mascots.InEgg(eggId)
	for index = Mascots.RarityIndex(rarity), 1, -1 do
		local pool = {}
		for _, mascot in inEgg do
			if Mascots.RarityIndex(mascot.Rarity) == index then
				table.insert(pool, mascot)
			end
		end
		if #pool > 0 then
			return pool[math.random(#pool)]
		end
	end
	return inEgg[1]
end

-- Adds one mascot to the player's pets. A free slot gets it straight away, so the bonus shows on the very next throw.
-- Returns whether it's new and whether it was equipped.
local function addMascot(player: Player, mascot): (boolean, boolean)
	local owned = getOwned(player)
	local isNew = (owned[mascot.Id] or 0) == 0
	owned[mascot.Id] = (owned[mascot.Id] or 0) + 1
	local equipped = getEquipped(player)
	local autoEquipped = #equipped < slots(player)
	if autoEquipped then
		table.insert(equipped, mascot.Id)
	end
	publish(player)
	return isNew, autoEquipped
end

-- Eggs hatch only at their own egg stand (Config.EggStands; the Neon Egg's is Workspace.Hub.EggPad in the lobby):
-- the player must be standing by it
local function standFor(eggId: string): Instance?
	for _, row in Config.EggStands do
		if row.Egg == eggId then
			local node: Instance? = Workspace
			for _, name in row.Path do
				node = node and node:FindFirstChild(name)
			end
			return node
		end
	end
	return nil
end

local function atEggStand(player: Player, eggId: string): boolean
	local pad = standFor(eggId) :: any
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not pad or not root then
		return false
	end
	local offset = (root.Position - pad:GetPivot().Position) * Vector3.new(1, 0, 1)
	return offset.Magnitude <= HATCH_RANGE
end

local function hatch(player: Player, eggId: any)
	local egg = Mascots.GetEgg(eggId)
	if not egg or not Mascots.EggReady(egg.Id) then
		return { Ok = false, Error = "Coming soon" }
	end
	if not PlayerDataService.IsLoaded(player) then
		return { Ok = false, Error = "Still loading" }
	end
	if not atEggStand(player, egg.Id) then
		return { Ok = false, Error = "Hatch it at the egg stand" }
	end
	local unlocked, why = Mascots.EggUnlocked(egg, PlayerDataService.Get(player, "RankLevel") or 1, zone(player))
	if not unlocked then
		return { Ok = false, Error = "Unlocks at " .. tostring(why) }
	end
	local freeEggs = getFreeEggs(player)
	local free = (freeEggs[egg.Id] or 0) > 0 -- a free hatch from a playtime gift goes first
	if not free and not PlayerDataService.CanAfford(player, "Coins", egg.Price) then
		return { Ok = false, Error = "Not enough coins" }
	end
	if not RateLimit.Allow(player, "HatchEgg") then
		return { Ok = false, Error = "Slow down!" }
	end

	-- TRIPLE HATCH game pass: 3 at once when the player can pay for all 3 (free hatches go one at a time)
	local count = Store.HatchCount(player)
	if free or not PlayerDataService.CanAfford(player, "Coins", egg.Price * count) then
		count = 1
	end
	if free then
		freeEggs[egg.Id] -= 1
		if freeEggs[egg.Id] <= 0 then
			freeEggs[egg.Id] = nil
		end
	else
		PlayerDataService.Spend(player, "Coins", egg.Price * count)
	end
	PlayerDataService.Add(player, "EggsHatched", count)
	local luck = Store.Luck(player)
	local mascot = roll(egg.Id, luck)
	-- The rarest pet plays the hatch; the others come along as Extras ({ MascotId, IsNew })
	local extras = {}
	for _ = 2, count do
		local other = roll(egg.Id, luck)
		if Mascots.RarityIndex(other.Rarity) > Mascots.RarityIndex(mascot.Rarity) then
			other, mascot = mascot, other
		end
		table.insert(extras, other)
	end
	local isNew, autoEquipped = addMascot(player, mascot)
	local extraResults = {}
	for _, other in extras do
		local otherNew = addMascot(player, other)
		table.insert(extraResults, { MascotId = other.Id, IsNew = otherNew })
	end

	local hatched = PlayerDataService.Get(player, "EggsHatched") or 0
	if not free then
		Analytics.Currency(player, "Coins", -egg.Price * count, "Shop", egg.Id .. "Egg")
		Analytics.Purchase(player, "Egg", egg.Id)
	end
	Analytics.Event(player, "MascotHatched", hatched, { egg.Id, mascot.Rarity, mascot.Id })
	Analytics.Step(player, "Hatched Mascot")
	SessionLog.Moment(
		player,
		("Egg hatched%s: %s -> %s (%s, %s)"):format(
			if free then " (free)" else "",
			egg.Id,
			mascot.Id,
			mascot.Rarity,
			if isNew then "new" else "duplicate"
		)
	)
	return {
		Ok = true,
		MascotId = mascot.Id,
		IsNew = isNew,
		Equipped = autoEquipped,
		Extras = if #extraResults > 0 then extraResults else nil,
	}
end

-- Adds free hatches of an egg (playtime gifts); they wait at the egg stand until used
function MascotService.GiveFreeEgg(player: Player, eggId: string, count: number?): boolean
	if not Mascots.GetEgg(eggId) or not PlayerDataService.IsLoaded(player) then
		return false
	end
	local freeEggs = PlayerDataService.Get(player, "FreeEggs")
	if type(freeEggs) ~= "table" then
		return false
	end
	freeEggs[eggId] = (freeEggs[eggId] or 0) + (count or 1)
	publish(player)
	return true
end

-- Gives one exact pet (no egg): the boss-only drop (Config.Boss.Drop). Returns isNew, or nil if there's no such pet.
function MascotService.GiveMascot(player: Player, mascotId: string): boolean?
	local mascot = Mascots.Get(mascotId)
	if not mascot or not PlayerDataService.IsLoaded(player) then
		return nil
	end
	local isNew = addMascot(player, mascot)
	SessionLog.Moment(player, ("Pet given: %s (%s)"):format(mascot.Id, mascot.Rarity))
	return isNew
end

-- Gives a pet of exactly this rarity from this egg, no hatching (the daily spin wheel's SECRET PET)
function MascotService.GivePet(player: Player, eggId: string, rarity: string)
	if not PlayerDataService.IsLoaded(player) then
		return nil
	end
	local pool = {}
	for _, mascot in Mascots.InEgg(eggId) do
		if mascot.Rarity == rarity then
			table.insert(pool, mascot)
		end
	end
	if #pool == 0 then
		-- No pet of that rarity in this egg: its rarest one instead
		for _, other in Mascots.InEgg(eggId) do
			if #pool == 0 or Mascots.RarityIndex(other.Rarity) > Mascots.RarityIndex(pool[1].Rarity) then
				pool = { other }
			end
		end
	end
	local mascot = pool[math.random(math.max(1, #pool))]
	if not mascot then
		return nil
	end
	local isNew, autoEquipped = addMascot(player, mascot)
	Analytics.Event(
		player,
		"MascotHatched",
		PlayerDataService.Get(player, "EggsHatched") or 0,
		{ eggId, mascot.Rarity, mascot.Id }
	)
	SessionLog.Moment(
		player,
		("Pet given: %s (%s, %s)"):format(mascot.Id, mascot.Rarity, if isNew then "new" else "duplicate")
	)
	return { MascotId = mascot.Id, IsNew = isNew, Equipped = autoEquipped }
end

local function onHatch(player: Player, eggId: any)
	if busy[player] then
		return { Ok = false, Error = "Slow down!" }
	end
	busy[player] = true
	local ok, result = pcall(hatch, player, eggId)
	busy[player] = nil
	if not ok then
		warn("[MascotService] Hatch failed: " .. tostring(result))
		return { Ok = false, Error = "Something went wrong" }
	end
	return result
end

-- equip = true puts one more of this mascot in a free slot; false takes one out
local function onEquip(player: Player, mascotId: any, equip: any)
	if not PlayerDataService.IsLoaded(player) or not RateLimit.Allow(player, "EquipMascot") then
		return
	end
	local mascot = Mascots.Get(mascotId)
	if not mascot then
		return
	end
	local equipped = getEquipped(player)
	if equip == true then
		local inUse = 0
		for _, id in equipped do
			if id == mascot.Id then
				inUse += 1
			end
		end
		if inUse >= (getOwned(player)[mascot.Id] or 0) or #equipped >= slots(player) then
			return
		end
		table.insert(equipped, mascot.Id)
	else
		local index = table.find(equipped, mascot.Id)
		if not index then
			return
		end
		table.remove(equipped, index)
	end
	publish(player)
end

-- Step 8b: ShinyMerge copies of one mascot become one Shiny version (bonus x ShinyMultiplier).
-- Merged copies leave their slots, and the Shiny goes into a free slot if there is one.
local function onMerge(player: Player, mascotId: any)
	if not PlayerDataService.IsLoaded(player) or not RateLimit.Allow(player, "EquipMascot") then
		return { Ok = false, Error = "Try again" }
	end
	local mascot = Mascots.Get(mascotId)
	local cost = mascot and Mascots.MergeCost(mascot)
	if not mascot or not cost then
		return { Ok = false, Error = "Can't merge that" }
	end
	local owned = getOwned(player)
	local have = owned[mascot.Id] or 0
	if have < cost then
		return { Ok = false, Error = ("Need %d to merge"):format(cost) }
	end
	local shinyId = Mascots.ShinyId(mascot.Id)
	owned[mascot.Id] = have - cost
	if owned[mascot.Id] == 0 then
		owned[mascot.Id] = nil
	end
	owned[shinyId] = (owned[shinyId] or 0) + 1

	-- Equipped copies beyond what's left: the first becomes the Shiny, the rest leave their slots
	local equipped = getEquipped(player)
	local left = owned[mascot.Id] or 0
	local swapped = false
	for i = #equipped, 1, -1 do
		if equipped[i] == mascot.Id then
			if left > 0 then
				left -= 1
			else
				table.remove(equipped, i)
			end
		end
	end
	-- Put the Shiny in if there's room (it's better than anything it replaced)
	if #equipped < slots(player) then
		table.insert(equipped, shinyId)
		swapped = true
	end
	publish(player)

	Analytics.Event(player, "MascotMerged", 1, { mascot.Id, mascot.Rarity })
	SessionLog.Moment(player, ("Mascot merged: %d x %s -> Shiny"):format(cost, mascot.Id))
	return { Ok = true, MascotId = shinyId, Equipped = swapped }
end

local function onEquipBest(player: Player)
	if not PlayerDataService.IsLoaded(player) or not RateLimit.Allow(player, "EquipMascot") then
		return
	end
	local best = Mascots.Best(getOwned(player), slots(player))
	local equipped = getEquipped(player)
	table.clear(equipped)
	for _, id in best do
		table.insert(equipped, id)
	end
	publish(player)
end

function MascotService:Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")

	local hatchRemote = Instance.new("RemoteFunction")
	hatchRemote.Name = "HatchEgg"
	hatchRemote.OnServerInvoke = onHatch
	hatchRemote.Parent = remotes

	local equipRemote = Instance.new("RemoteEvent")
	equipRemote.Name = "EquipMascot"
	equipRemote.OnServerEvent:Connect(onEquip)
	equipRemote.Parent = remotes

	local mergeRemote = Instance.new("RemoteFunction")
	mergeRemote.Name = "MergeMascot"
	mergeRemote.OnServerInvoke = onMerge
	mergeRemote.Parent = remotes

	local bestRemote = Instance.new("RemoteEvent")
	bestRemote.Name = "EquipBestMascots"
	bestRemote.OnServerEvent:Connect(onEquipBest)
	bestRemote.Parent = remotes

	-- Studio only (never in the live game): reach the first egg's rank level and get its price in coins
	if RunService:IsStudio() then
		local test = Instance.new("RemoteEvent")
		test.Name = "TestEgg"
		test.OnServerEvent:Connect(function(player)
			if not PlayerDataService.IsLoaded(player) then
				return
			end
			local egg = Config.Economy.Eggs[1]
			local level = math.max(egg.Rank or 1, if egg.Zone then Zones.UnlockLevel(egg.Zone) else 1)
			if (PlayerDataService.Get(player, "RankLevel") or 1) < level then
				local xp = PlayerDataService.Get(player, "XP") or 0
				ProgressionService.AddXP(player, math.max(Progression.LevelXP(level) - xp, 1))
			end
			PlayerDataService.Add(player, "Coins", egg.Price)
		end)
		test.Parent = remotes
	end

	PlayerDataService.OnLoaded(function(player)
		publish(player)
		-- New slots open with rank levels (and the +2 PET SLOTS pass, Passes)
		for _, key in { "RankLevel", "Passes" } do
			player:GetAttributeChangedSignal(key):Connect(function()
				if PlayerDataService.IsLoaded(player) then
					publish(player)
				end
			end)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return MascotService
