-- Mascot eggs, hatching and equipping (Addendum 2 Phase 3 step 8). The server rolls every hatch.
-- Saved: Mascots ({ Id = count }, Shiny versions as "Pinny_Shiny"), EquippedMascots ({ Id, ... } one per slot), EggsHatched.
-- Published to everyone as Player attributes (each client draws every player's mascots from them):
--   Mascots "Pinny=2,Gus=1", EquippedMascots "Pinny,Gus", MascotSlots, MascotBonus (0.04 = +4% coins).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Mascots = require(Shared.Modules.Mascots)
local Progression = require(Shared.Modules.Progression)
local Analytics = require(script.Parent.Analytics)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressionService = require(script.Parent.ProgressionService)
local RateLimit = require(script.Parent.Parent.Modules.RateLimit)
local SessionLog = require(script.Parent.Parent.Modules.SessionLog)

local ODDS = Config.Economy.Mascots.Odds

local MascotService = {}

local busy: { [Player]: boolean } = {}

local function getOwned(player: Player): { [string]: number }
	return PlayerDataService.Get(player, "Mascots") or {}
end

local function getEquipped(player: Player): { string }
	return PlayerDataService.Get(player, "EquippedMascots") or {}
end

local function slots(player: Player): number
	return Mascots.Slots(PlayerDataService.Get(player, "RankLevel") or 1, 0) -- rebirths come in step 10
end

-- Zones 2 to 6 come in step 9: everyone is in zone 1 for now
local function zone(_player: Player): number
	return 1
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

local function publish(player: Player)
	repairEquipped(player)
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
local function roll(eggId: string)
	local total = 0
	for _, name in Mascots.Rarities do
		total += ODDS[name] or 0
	end
	local pick = math.random() * total
	local rarity = Mascots.Rarities[1]
	for _, name in Mascots.Rarities do
		local odds = ODDS[name] or 0
		if odds > 0 then
			pick -= odds
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

local function hatch(player: Player, eggId: any)
	local egg = Mascots.GetEgg(eggId)
	if not egg or not Mascots.EggReady(egg.Id) then
		return { Ok = false, Error = "Coming soon" }
	end
	if not PlayerDataService.IsLoaded(player) then
		return { Ok = false, Error = "Still loading" }
	end
	local unlocked, why = Mascots.EggUnlocked(egg, PlayerDataService.Get(player, "RankLevel") or 1, zone(player))
	if not unlocked then
		return { Ok = false, Error = "Unlocks at " .. tostring(why) }
	end
	if (PlayerDataService.Get(player, "Coins") or 0) < egg.Price then
		return { Ok = false, Error = "Not enough coins" }
	end
	if not RateLimit.Allow(player, "HatchEgg") then
		return { Ok = false, Error = "Slow down!" }
	end

	PlayerDataService.Add(player, "Coins", -egg.Price)
	PlayerDataService.Add(player, "EggsHatched", 1)
	local mascot = roll(egg.Id)
	local owned = getOwned(player)
	local isNew = (owned[mascot.Id] or 0) == 0
	owned[mascot.Id] = (owned[mascot.Id] or 0) + 1

	-- A free slot gets the new mascot straight away, so the bonus shows on the very next throw
	local equipped = getEquipped(player)
	local autoEquipped = #equipped < slots(player)
	if autoEquipped then
		table.insert(equipped, mascot.Id)
	end
	publish(player)

	local hatched = PlayerDataService.Get(player, "EggsHatched") or 0
	Analytics.Currency(player, "Coins", -egg.Price, "Shop", egg.Id .. "Egg")
	Analytics.Purchase(player, "Egg", egg.Id)
	Analytics.Event(player, "MascotHatched", hatched, { egg.Id, mascot.Rarity, mascot.Id })
	Analytics.Step(player, "Hatched Mascot")
	SessionLog.Moment(
		player,
		("Egg hatched: %s -> %s (%s, %s)"):format(
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
	}
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
			if egg.Rank and (PlayerDataService.Get(player, "RankLevel") or 1) < egg.Rank then
				local xp = PlayerDataService.Get(player, "XP") or 0
				ProgressionService.AddXP(player, math.max(Progression.LevelXP(egg.Rank) - xp, 1))
			end
			PlayerDataService.Add(player, "Coins", egg.Price)
		end)
		test.Parent = remotes
	end

	PlayerDataService.OnLoaded(function(player)
		publish(player)
		-- New slots open with rank levels
		player:GetAttributeChangedSignal("RankLevel"):Connect(function()
			if PlayerDataService.IsLoaded(player) then
				publish(player)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return MascotService
