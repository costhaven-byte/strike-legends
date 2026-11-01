-- Mascot eggs, hatching and equipping (Addendum 2 Phase 3 step 8). The server rolls every hatch.
-- Saved: Mascots ({ Id = count }, Shiny versions as "Pinny_Shiny"), EquippedMascots ({ Id, ... } one per slot), EggsHatched,
-- FreeEggs ({ Alley = 1 }: free hatches from playtime gifts, used before coins), AutoDelete ({ Pinny = true }: pets X'd
-- on the egg odds boards, not kept when hatched; batch C3, Config.AutoDelete).
-- Published to everyone as Player attributes (each client draws every player's mascots from them):
--   Mascots "Pinny=2,Gus=1", EquippedMascots "Pinny,Gus", MascotSlots, MascotBonus (0.04 = +4% coins),
--   MascotStats "Coins=0.5,Pins=0.2" (Addendum 5 B1: the equipped pets' stats added up, Config.PetStats),
--   FreeEgg_<egg Id> (free hatches waiting), AutoDelete "Pinny,Gus" (X'd pets).
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
		PlayerDataService.Get(player, "Rebirths") or 0,
		Store.PetSlots(player),
		PlayerDataService.Get(player, "PetSlotsKept") or 0,
		PlayerDataService.Get(player, "PetSlotsBought") or 0 -- (Addendum 5 B1: coin slots from the shop)
	)
end

-- The highest zone the player has open (eggs with a Zone unlock there)
local function zone(player: Player): number
	return Zones.Highest(PlayerDataService.Get(player, "ZonesOpen"))
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

local function getAutoDelete(player: Player): { [string]: boolean }
	local value = PlayerDataService.Get(player, "AutoDelete")
	return if type(value) == "table" then value else {}
end

-- Batch C3: can this pet be X'd on an egg board? Egg pets only (not Shinies), never rarer than Config.AutoDelete.MaxRarity
local function deletable(mascot): boolean
	return mascot ~= nil
		and not mascot.Shiny
		and Mascots.GetEgg(mascot.Egg) ~= nil
		and Mascots.RarityIndex(mascot.Rarity) <= Mascots.RarityIndex(Config.AutoDelete.MaxRarity)
end

-- Is this hatched pet auto-deleted? X'd, still allowed, and (KeepFirst) the player already owns it or its Shiny
local function autoDeletes(player: Player, mascot): boolean
	local rules = Config.AutoDelete
	if not rules.Enabled or not getAutoDelete(player)[mascot.Id] or not deletable(mascot) then
		return false
	end
	if rules.KeepFirst then
		local owned = getOwned(player)
		return (owned[mascot.Id] or 0) > 0 or (owned[Mascots.ShinyId(mascot.Id)] or 0) > 0
	end
	return true
end

local function publish(player: Player)
	repairEquipped(player)
	local marked = {}
	for id in getAutoDelete(player) do
		table.insert(marked, id)
	end
	table.sort(marked)
	player:SetAttribute("AutoDelete", table.concat(marked, ","))
	local free = getFreeEggs(player)
	for _, egg in Config.Economy.Eggs do
		player:SetAttribute("FreeEgg_" .. egg.Id, free[egg.Id] or 0)
	end
	local equipped = getEquipped(player)
	player:SetAttribute("Mascots", Mascots.EncodeOwned(getOwned(player)))
	player:SetAttribute("EquippedMascots", Mascots.EncodeEquipped(equipped))
	player:SetAttribute("MascotSlots", slots(player))
	local stats = Mascots.TotalStats(equipped)
	player:SetAttribute("MascotBonus", stats.Coins or 0)
	local parts = {}
	for _, name in Config.PetStats.Order do
		table.insert(parts, ("%s=%s"):format(name, tostring(stats[name] or 0)))
	end
	player:SetAttribute("MascotStats", table.concat(parts, ","))
end

-- Coin multiplier from the equipped mascots: 1 + their coin bonuses added together (B1: 1 + the Coins stat total,
-- Config.PetStats.Stacking)
function MascotService.GetMultiplier(player: Player): number
	return 1 + (Mascots.TotalStats(getEquipped(player)).Coins or 0)
end

-- Addendum 5 B1 (for step C's rebirth): Config.PetStats.KeepPetSlots = false takes the bought slots away
function MascotService.ResetForRebirth(player: Player)
	if not Config.PetStats.KeepPetSlots and PlayerDataService.IsLoaded(player) then
		PlayerDataService.Set(player, "PetSlotsBought", 0)
		publish(player)
	end
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

-- Polish P2: the chance one hatch of this egg gives exactly this pet (same maths as roll), shown as "1 in X".
-- P3: the maths lives in Mascots.Chance so the stand's odds bubbles show the very same numbers.
local function chance(eggId: string, mascot, luck: number): number
	return Mascots.Chance(eggId, mascot, Store.LuckyOdds(ODDS, luck))
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
		return { Ok = false, Error = "Hang on, still loading" }
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
		return { Ok = false, Error = "Too fast, wait a sec" }
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
	-- Batch C3: X'd pets are not kept (still shown on the card with an AUTO-DELETED stamp, still eggs hatched)
	local deleted = autoDeletes(player, mascot)
	local isNew, autoEquipped = false, false
	if not deleted then
		isNew, autoEquipped = addMascot(player, mascot)
	end
	local extraResults = {}
	local deletedCount = if deleted then 1 else 0
	for _, other in extras do
		if autoDeletes(player, other) then
			deletedCount += 1
			table.insert(extraResults, { MascotId = other.Id, IsNew = false, Deleted = true })
		else
			local otherNew = addMascot(player, other)
			table.insert(extraResults, { MascotId = other.Id, IsNew = otherNew })
		end
	end

	-- A Legendary or Mythic pet: the crate pull banner for everyone in the server (Config.PullBanner), after the reveal
	local banner = Config.PullBanner
	if banner.Enabled and banner.PetRarities[mascot.Rarity] then
		local remote = ReplicatedStorage:FindFirstChild("Remotes")
		local event = remote and remote:FindFirstChild("PullBanner")
		if event and event:IsA("RemoteEvent") then
			task.delay(banner.PetDelay, function()
				event:FireAllClients({ Name = player.DisplayName, PetId = mascot.Id })
			end)
		end
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
		("Egg hatched%s: %s -> %s (%s, %s)%s"):format(
			if free then " (free)" else "",
			egg.Id,
			mascot.Id,
			mascot.Rarity,
			if deleted then "auto-deleted" elseif isNew then "new" else "duplicate",
			if deletedCount > 0 then (", %d auto-deleted"):format(deletedCount) else ""
		)
	)
	return {
		Ok = true,
		MascotId = mascot.Id,
		IsNew = isNew,
		Equipped = autoEquipped,
		Deleted = if deleted then true else nil,
		Chance = chance(egg.Id, mascot, luck),
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
		return { Ok = false, Error = "Too fast, wait a sec" }
	end
	busy[player] = true
	local ok, result = pcall(hatch, player, eggId)
	busy[player] = nil
	if not ok then
		warn("[MascotService] Hatch failed: " .. tostring(result))
		return { Ok = false, Error = "That didn't work. Try again" }
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

-- Batch C2: merges only happen at zone 3's PET FUSION machine (Config.Fusion): zone 3 open and standing by it
local function atFusionMachine(player: Player): boolean
	local FUSION = Config.Fusion
	if not FUSION.Enabled or not Zones.Unlocked(PlayerDataService.Get(player, "ZonesOpen"), FUSION.Zone) then
		return false
	end
	local node: Instance? = Workspace
	for _, name in FUSION.Path do
		node = node and node:FindFirstChild(name)
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not node or not root then
		return false
	end
	local offset = (root.Position - (node :: any):GetPivot().Position) * Vector3.new(1, 0, 1)
	return offset.Magnitude <= FUSION.Range
end

-- Step 8b: ShinyMerge copies of one mascot become one Shiny version (bonus x ShinyMultiplier).
-- Merged copies leave their slots, and the Shiny goes into a free slot if there is one.
local function onMerge(player: Player, mascotId: any)
	if not PlayerDataService.IsLoaded(player) or not RateLimit.Allow(player, "EquipMascot") then
		return { Ok = false, Error = "That didn't work. Try again" }
	end
	if not atFusionMachine(player) then
		return { Ok = false, Error = "Fuse pets at the PET FUSION machine" }
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

-- Batch C3: X a pet out on an egg odds board (on = true) or take the X off (on = false). One list across all eggs.
local function onAutoDelete(player: Player, mascotId: any, on: any)
	if not Config.AutoDelete.Enabled or type(on) ~= "boolean" then
		return
	end
	if not PlayerDataService.IsLoaded(player) or not RateLimit.Allow(player, "AutoDelete") then
		return
	end
	local mascot = Mascots.Get(mascotId)
	if not mascot or (on and not deletable(mascot)) then
		return
	end
	local list = PlayerDataService.Get(player, "AutoDelete")
	if type(list) ~= "table" then
		return
	end
	list[mascot.Id] = if on then true else nil
	publish(player)
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
	-- Polish P4: the pointing hand on EQUIP BEST has done its job (Config.EquipBestHint)
	if PlayerDataService.Get(player, "EquipBestHinted") ~= 1 then
		PlayerDataService.Set(player, "EquipBestHinted", 1)
	end
end

function MascotService:Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")

	-- Batch C1: the BUY YOUR FIRST PET EGG! popup was shown (Config.EggPrompt); it never shows again
	local eggPrompted = Instance.new("RemoteEvent")
	eggPrompted.Name = "EggPrompted"
	eggPrompted.OnServerEvent:Connect(function(player)
		if PlayerDataService.IsLoaded(player) and PlayerDataService.Get(player, "EggPrompted") ~= 1 then
			PlayerDataService.Set(player, "EggPrompted", 1)
		end
	end)
	eggPrompted.Parent = remotes

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

	local autoDeleteRemote = Instance.new("RemoteEvent")
	autoDeleteRemote.Name = "SetAutoDelete"
	autoDeleteRemote.OnServerEvent:Connect(onAutoDelete)
	autoDeleteRemote.Parent = remotes

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
			local level = egg.Rank or 1
			if egg.Zone and (PlayerDataService.Get(player, "ZonesOpen") or 1) < egg.Zone then
				PlayerDataService.Set(player, "ZonesOpen", egg.Zone) -- Studio test only: opens the egg's zone
			end
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
		-- New slots open with rebirths (and the +2 PET SLOTS pass, Passes); RankLevel still locks eggs with a Rank
		for _, key in { "Rebirths", "RankLevel", "Passes", "PetSlotsBought" } do
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
