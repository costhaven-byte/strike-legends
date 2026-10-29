-- Profile panel stats + achievements (Polish P5, Config.Profile). The server owns every number: it reads the lifetime
-- counters from the save (TotalThrows, LifetimePins, EggsHatched ...), works out which achievement tiers are ready,
-- and pays the gems when the player taps CLAIM (remote ClaimAchievement, rate limited).
-- Published to the client as Player attributes:
--   ProfileStats       "Throws=120;Strikes=40;..."   (Config.Profile.Stats keys)
--   AchievementTiers   "Throws=1;Pins=0;..."         tiers claimed per achievement Id
--   AchievementsReady  number of tiers ready to claim (the red badge on the PROFILE button)
-- Saved: AchievementTiers ({ Id = tiers claimed }, v26). The counters themselves are counted where they happen
-- (ThrowService, BossService, PlayerDataService for coins earned).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Analytics = require(script.Parent.Analytics)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RateLimit = require(script.Parent.Parent.Modules.RateLimit)
local SessionLog = require(script.Parent.Parent.Modules.SessionLog)

local PROFILE = Config.Profile

local AchievementService = {}

local function count(set: any, distinct: boolean?): number
	local n = 0
	local seen = {}
	if type(set) ~= "table" then
		return 0
	end
	for key, value in set do
		if value and (type(value) ~= "number" or value > 0) then
			if distinct then
				-- "Pinny_Shiny" counts as Pinny: a pet found once
				local base = tostring(key):gsub("_Shiny$", "")
				if not seen[base] then
					seen[base] = true
					n += 1
				end
			else
				n += 1
			end
		end
	end
	return n
end

local function num(player: Player, key: string): number
	return tonumber(PlayerDataService.Get(player, key)) or 0
end

-- Every Config.Profile stat for this player
function AchievementService.Stats(player: Player): { [string]: number }
	return {
		Throws = num(player, "TotalThrows"),
		Strikes = num(player, "TotalStrikes"),
		Perfects = num(player, "TotalPerfects"),
		Pins = num(player, "LifetimePins"),
		BestStreak = num(player, "BestStreak"),
		Coins = num(player, "LifetimeCoins"),
		Eggs = num(player, "EggsHatched"),
		Crates = num(player, "CratesOpened"),
		Balls = count(PlayerDataService.Get(player, "OwnedBalls")),
		Pets = count(PlayerDataService.Get(player, "Mascots"), true),
		Rebirths = num(player, "Rebirths"),
		BossWins = num(player, "BossWins"),
		Level = num(player, "BestLevel"), -- best ever: rebirths reset the level (batch D1)
		Zones = num(player, "ZonesOpen"),
		PlayTime = num(player, "PlayTime"),
	}
end

local function byId(id: any)
	if type(id) ~= "string" then
		return nil
	end
	for _, row in PROFILE.Achievements do
		if row.Id == id then
			return row
		end
	end
	return nil
end

local function claimedOf(player: Player): { [string]: number }?
	local tiers = PlayerDataService.Get(player, "AchievementTiers")
	return if type(tiers) == "table" then tiers else nil
end

-- Tiers ready to claim right now, over every achievement
local function readyCount(stats: { [string]: number }, claimed: { [string]: number }): number
	local ready = 0
	for _, row in PROFILE.Achievements do
		local done = claimed[row.Id] or 0
		for tier = done + 1, #row.Tiers do
			if (stats[row.Stat] or 0) >= row.Tiers[tier].Goal then
				ready += 1
			else
				break
			end
		end
	end
	return ready
end

local function publish(player: Player)
	local claimed = claimedOf(player)
	if not claimed then
		return
	end
	local stats = AchievementService.Stats(player)
	local parts = {}
	for _, stat in PROFILE.Stats do
		table.insert(parts, ("%s=%s"):format(stat.Key, tostring(stats[stat.Key] or 0)))
	end
	local statText = table.concat(parts, ";")
	local tierParts = {}
	for _, row in PROFILE.Achievements do
		table.insert(tierParts, ("%s=%d"):format(row.Id, claimed[row.Id] or 0))
	end
	local tierText = table.concat(tierParts, ";")
	if player:GetAttribute("ProfileStats") ~= statText then
		player:SetAttribute("ProfileStats", statText)
	end
	if player:GetAttribute("AchievementTiers") ~= tierText then
		player:SetAttribute("AchievementTiers", tierText)
	end
	local ready = readyCount(stats, claimed)
	if player:GetAttribute("AchievementsReady") ~= ready then
		player:SetAttribute("AchievementsReady", ready)
	end
end

-- CLAIM: pays the next tier of one achievement if its goal is reached
local function onClaim(player: Player, id: any)
	if not RateLimit.Allow(player, "ClaimAchievement") then
		return { Ok = false, Error = "Slow down!" }
	end
	if not PlayerDataService.IsLoaded(player) then
		return { Ok = false, Error = "Still loading" }
	end
	local row = byId(id)
	local claimed = claimedOf(player)
	if not row or not claimed then
		return { Ok = false, Error = "Something went wrong" }
	end
	local done = claimed[row.Id] or 0
	local tier = row.Tiers[done + 1]
	if not tier then
		return { Ok = false, Error = "All done!" }
	end
	local value = AchievementService.Stats(player)[row.Stat] or 0
	if value < tier.Goal then
		return { Ok = false, Error = "Not yet!" }
	end
	claimed[row.Id] = done + 1
	local gems = if Config.Gems.Enabled then tier.Gems or 0 else 0
	if gems > 0 then
		PlayerDataService.Add(player, "Gems", gems)
		Analytics.Currency(player, "Gems", gems, "Gameplay", "Achievement_" .. row.Id)
	end
	Analytics.Event(player, "Achievement", done + 1, { row.Id })
	SessionLog.Moment(player, ("Achievement %s tier %d"):format(row.Id, done + 1))
	publish(player)
	return { Ok = true, Id = row.Id, Tier = done + 1, Gems = gems }
end

function AchievementService:Start()
	if not PROFILE or not PROFILE.Enabled then
		return
	end
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local remote = Instance.new("RemoteFunction")
	remote.Name = "ClaimAchievement"
	remote.OnServerInvoke = function(player, id)
		local ok, result = pcall(onClaim, player, id)
		if not ok then
			warn("[AchievementService] Claim failed: " .. tostring(result))
			return { Ok = false, Error = "Something went wrong" }
		end
		return result
	end
	remote.Parent = remotes

	PlayerDataService.OnLoaded(publish)
	task.spawn(function()
		while true do
			task.wait(PROFILE.PublishEvery or 1)
			for _, player in Players:GetPlayers() do
				if PlayerDataService.IsLoaded(player) then
					local ok, err = pcall(publish, player)
					if not ok then
						warn("[AchievementService] " .. tostring(err))
					end
				end
			end
		end
	end)
end

return AchievementService
