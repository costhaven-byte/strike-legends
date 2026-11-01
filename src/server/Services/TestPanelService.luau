-- Studio only (never in the live game): the TEST panel's server side (client: TestPanelController).
-- Pick how the next play test starts (from zero / your save with everything unlocked), jump to a zone, and give
-- coins, gems, levels, crates, eggs and potions to test any part of the game quickly.
-- Changes only work in a test session that is never saved (PlayerDataService.IsTestSession), so a real save can't
-- be changed by these buttons.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Currency = require(Shared.Modules.Currency)
local Mascots = require(Shared.Modules.Mascots)
local Progression = require(Shared.Modules.Progression)
local Rebirth = require(Shared.Modules.Rebirth)
local Zones = require(Shared.Modules.Zones)
local StudioTestMode = require(script.Parent.Parent.Modules.StudioTestMode)
local BallService = require(script.Parent.BallService)
local BossService = require(script.Parent.BossService)
local FeverService = require(script.Parent.FeverService)
local LaneEventService = require(script.Parent.LaneEventService)
local MascotService = require(script.Parent.MascotService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PotionService = require(script.Parent.PotionService)
local ProgressionService = require(script.Parent.ProgressionService)

local TestPanelService = {}

local nextPet: { [Player]: number } = {} -- GIVE PET goes down Config.Mascots one pet per press
local nextEgg: { [Player]: number } = {} -- (B2) FREE EGG goes down the roof egg row one egg per press

local function reply(ok: boolean, text: string)
	return { Ok = ok, Text = text }
end

-- Puts the player at this rank level (and the rank it belongs to), with no popups or level rewards
local function setLevel(player: Player, level: number)
	if (PlayerDataService.Get(player, "RankLevel") or 1) >= level then
		return
	end
	local tier = math.ceil(level / Config.Economy.Ranks.LevelsPerTier)
	PlayerDataService.Set(player, "Rank", math.max(PlayerDataService.Get(player, "Rank") or 1, tier))
	local xp = PlayerDataService.Get(player, "XP") or 0
	PlayerDataService.Set(player, "XP", math.max(xp, Progression.LevelXP(level)))
	PlayerDataService.Set(player, "RankLevel", level)
	-- Jumped-over levels and tiers count as rewarded, like a real player's (BestLevel / BestRank, batch D1)
	PlayerDataService.Set(player, "BestLevel", math.max(PlayerDataService.Get(player, "BestLevel") or 1, level))
	PlayerDataService.Set(player, "BestRank", math.max(PlayerDataService.Get(player, "BestRank") or 1, tier))
	ProgressionService.RefreshRankUpReady(player)
end

-- Rebirths, level and open zones of a player who just reached this zone (first 3 minutes done)
local function jumpToZone(player: Player, zone: number)
	if zone > Config.Zones.BuiltZones then
		return reply(false, Zones.Name(zone) .. " isn't built")
	end
	local rebirths = math.max(PlayerDataService.Get(player, "Rebirths") or 0, Zones.UnlockRebirths(zone))
	PlayerDataService.Set(player, "Rebirths", rebirths)
	PlayerDataService.Set(player, "ZonesOpen", math.max(PlayerDataService.Get(player, "ZonesOpen") or 1, zone))
	local row = Config.Economy.Zones[zone]
	setLevel(player, math.max(row and row.Rank or 1, if rebirths > 0 then Rebirth.Level(rebirths - 1) else 1))
	PlayerDataService.Set(player, "Onboarding", math.max(PlayerDataService.Get(player, "Onboarding") or 0, 3))
	PlayerDataService.Set(player, "CratesBought", math.max(PlayerDataService.Get(player, "CratesBought") or 0, 1))
	return reply(true, ("%s open (%d rebirths). Use TELEPORT to go there"):format(Zones.Name(zone), rebirths))
end

local ACTIONS: { [string]: (Player) -> any } = {
	Zone2 = function(player)
		return jumpToZone(player, 2)
	end,
	Zone3 = function(player)
		return jumpToZone(player, 3)
	end,
	Zone4 = function(player)
		return jumpToZone(player, 4)
	end,
	Coins = function(player)
		local coins = PlayerDataService.Get(player, "Coins") or 0
		local add = Currency.Max(Currency.Mul(coins, 9), 10000)
		PlayerDataService.Add(player, "Coins", add)
		return reply(true, "Coins x10 (+" .. Currency.Format(add) .. ")")
	end,
	Gems = function(player)
		PlayerDataService.Add(player, "Gems", 100)
		return reply(true, "+100 gems")
	end,
	Level = function(player)
		if player:GetAttribute("RankUpReady") then
			return reply(false, "Pass the rank trial first (or press PASS TRIAL)")
		end
		local level = PlayerDataService.Get(player, "RankLevel") or 1
		local xp = PlayerDataService.Get(player, "XP") or 0
		ProgressionService.AddXP(player, math.max(Progression.LevelXP(level + 1) - xp, 1))
		if player:GetAttribute("RankUpReady") then
			return reply(true, "Rank trial is ready (play it, or press PASS TRIAL)")
		end
		return reply(true, "Level " .. tostring(PlayerDataService.Get(player, "RankLevel")))
	end,
	Trial = function(player)
		if not player:GetAttribute("RankUpReady") then
			return reply(false, "No rank trial yet: press +1 LEVEL until one is ready")
		end
		ProgressionService.PromoteRank(player)
		return reply(true, "Rank trial passed")
	end,
	Rebirth = function(player)
		local done = PlayerDataService.Get(player, "Rebirths") or 0
		if Rebirth.CoreOn() then
			-- Addendum 5 step C: just the coins (rebirth is bought at the ball shop)
			local price = Rebirth.CorePrice(done)
			local have = PlayerDataService.Get(player, "Coins") or 0
			if not Currency.CanAfford(have, price) then
				PlayerDataService.Add(player, "Coins", Currency.Sub(price, have))
			end
			return reply(true, "Ready: rebirth at the ball shop")
		end
		setLevel(player, Rebirth.Level(done))
		local cost = Rebirth.Cost(done)
		local coins = PlayerDataService.Get(player, "Coins") or 0
		if not Currency.CanAfford(coins, cost) then
			PlayerDataService.Add(player, "Coins", Currency.Sub(cost, coins))
		end
		return reply(true, "Ready: press the REBIRTH button")
	end,
	Crate = function(player)
		BallService.GiveFreeCrate(player)
		return reply(true, "+1 free crate: open it at a crate shop")
	end,
	Egg = function(player)
		-- Addendum 5 B2: on the roof, a free hatch of the next egg of the egg row each press
		if Mascots.CoreEggsOn() then
			local eggs = Mascots.CoreEggs()
			local index = (nextEgg[player] or 0) % #eggs + 1
			nextEgg[player] = index
			local egg = eggs[index]
			if not egg or not MascotService.GiveFreeEgg(player, egg.Id, 1) then
				return reply(false, "No egg to give")
			end
			return reply(true, ("+1 free %s: hatch it at its stand on the egg row"):format(Config.EggLooks[egg.Id].Name))
		end
		local zone = math.max(Zones.Highest(PlayerDataService.Get(player, "ZonesOpen")), 2)
		local pick = nil
		for _, egg in Config.Economy.Eggs do
			if (egg.Zone or 1) <= zone and (not pick or (egg.Zone or 1) > (pick.Zone or 1)) then
				pick = egg
			end
		end
		if not pick or not MascotService.GiveFreeEgg(player, pick.Id, 1) then
			return reply(false, "No egg to give")
		end
		return reply(true, "+1 free hatch: use it at the " .. Zones.Name(pick.Zone or 2) .. " egg stand")
	end,
	-- Addendum 5 B1: one pet (the next one in Config.Mascots each press), straight into a free slot if there is one
	Pet = function(player)
		local index = (nextPet[player] or 0) % #Config.Mascots + 1
		nextPet[player] = index
		local mascot = Config.Mascots[index]
		if MascotService.GiveMascot(player, mascot.Id) == nil then
			return reply(false, "No pet to give")
		end
		return reply(
			true,
			("+1 %s (%s): %s. Open PETS"):format(mascot.Name, mascot.Rarity, Mascots.StatText(Mascots.Stats(mascot)))
		)
	end,
	Potions = function(player)
		for _, potion in Config.Potions.List do
			PotionService.Give(player, potion.Id, 1)
		end
		return reply(true, "One of every potion (PETS > ITEMS)")
	end,
	Boss = function(player)
		if not BossService.TestOpenNow() then
			return reply(false, "The boss event is already on (or the boss is off)")
		end
		return reply(true, "Helicopter boarding is open now (zone 4 roof)")
	end,
	Fever = function(player)
		if not Config.Fever.Enabled then
			return reply(false, "Fever is off (Config.Fever.Enabled)")
		end
		FeverService.Begin(player, 0)
		return reply(true, "FEVER MODE for " .. Config.Fever.Seconds .. " s: throw now")
	end,
	-- Lane events (Config.LaneEvents, batch D5) on your lane now
	GoldenRack = function(player)
		return reply(LaneEventService.Force(player, "GoldenRack"))
	end,
	Split = function(player)
		return reply(LaneEventService.Force(player, "Split"))
	end,
	GemPin = function(player)
		return reply(LaneEventService.Force(player, "GemPin"))
	end,
}

local function onRequest(player: Player, action: any, mode: any)
	if action == "Mode" then
		if not StudioTestMode.Set(player.UserId, mode) then
			return reply(false, "Couldn't save the choice (Studio API access must be on)")
		end
		local text = if mode == "Zero" then "next test: START FROM ZERO" else "next test: MY SAVE, ALL UNLOCKED"
		return reply(true, "Saved. Press Stop, then Play: " .. text)
	end
	local run = type(action) == "string" and ACTIONS[action]
	if not run or not PlayerDataService.IsLoaded(player) then
		return reply(false, "Not ready yet")
	end
	if not PlayerDataService.IsTestSession(player) then
		return reply(false, "Only in a test that isn't saved: pick a start mode, then Stop and Play")
	end
	return run(player)
end

function TestPanelService:Start()
	if not RunService:IsStudio() then
		return -- the panel never exists in the live game
	end
	local remote = Instance.new("RemoteFunction")
	remote.Name = "TestPanel"
	remote.OnServerInvoke = function(player, action, mode)
		local ok, result = pcall(onRequest, player, action, mode)
		if not ok then
			warn("[TestPanelService] " .. tostring(result))
			return reply(false, "Something went wrong (see Output)")
		end
		return result
	end
	remote.Parent = ReplicatedStorage:WaitForChild("Remotes")
end

return TestPanelService
