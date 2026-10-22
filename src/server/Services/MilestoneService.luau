-- Zone milestones (Phase X Part 1, Config.Milestones): one-time level rewards (levels 7 and 9 in Neon Lanes) and
-- repeatable challenges with a HUD tracker ("3 strikes in a row" = a free Bronze Crate).
-- Challenge progress lives only for the visit (not saved). The server decides everything; the client only shows it
-- (attributes Challenge_<Id> = progress, ChallengeReady_<Id> = server time it can be done again).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local PowerLevels = require(Shared.Modules.PowerLevels)
local Zones = require(Shared.Modules.Zones)
local Analytics = require(script.Parent.Analytics)
local BallService = require(script.Parent.BallService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PotionService = require(script.Parent.PotionService)
local ProgressionService = require(script.Parent.ProgressionService)
local SessionLog = require(script.Parent.Parent.Modules.SessionLog)

local MILESTONES = Config.Milestones

local MilestoneService = {}

local rewardEvent: RemoteEvent
local progress: { [Player]: { [string]: number } } = {}

-- Gives one reward row ({ Coins, LevelShare, Potions, Crate }) and returns what the client needs to show it
local function give(player: Player, reward, source: string)
	local shown = { Coins = 0, Potions = reward.Potions }
	if reward.Coins then
		local coins = PowerLevels.DailyCoins(reward, PlayerDataService.Get(player, "PowerLevel"))
		PlayerDataService.Add(player, "Coins", coins)
		Analytics.Currency(player, "Coins", coins, "Gameplay", source)
		shown.Coins = coins
	end
	for _, potion in reward.Potions or {} do
		PotionService.Give(player, potion.Id, potion.Count)
	end
	-- A crate from a zone you haven't unlocked yet comes as your zone's crate
	local crate = Balls.GetCrate(Zones.RewardCrateId(reward.Crate, PlayerDataService.Get(player, "RankLevel")))
	if crate then
		shown.CrateId = crate.Id
		shown.Crate = BallService.GiveCrate(player, crate)
	end
	return shown
end

local function onLevel(player: Player, level: number)
	if not MILESTONES.Enabled then
		return
	end
	for _, row in MILESTONES.LevelRewards do
		if row.Level == level then
			task.wait(1.5) -- after the level-up / rank-up popup
			if not PlayerDataService.IsLoaded(player) then
				return
			end
			local shown = give(player, row, "LevelReward")
			shown.Kind = "Level"
			shown.Level = level
			SessionLog.Moment(player, ("Level %d reward"):format(level))
			Analytics.Event(player, "LevelReward", level)
			rewardEvent:FireClient(player, shown)
		end
	end
end

local function challengeKey(challenge): string
	return "Challenge_" .. challenge.Id
end

-- Called by ThrowService when a throw is paid. zone = the lane's zone; saved = Streak Saver kept the streak.
function MilestoneService.OnThrow(player: Player, zone: number, isStrike: boolean, saved: boolean)
	if not MILESTONES.Enabled or not PlayerDataService.IsLoaded(player) then
		return
	end
	local mine = progress[player]
	if not mine then
		mine = {}
		progress[player] = mine
	end
	local now = Workspace:GetServerTimeNow()
	for _, challenge in MILESTONES.Challenges do
		if challenge.Zone and challenge.Zone ~= zone then
			continue
		end
		if now < (player:GetAttribute("ChallengeReady_" .. challenge.Id) or 0) then
			continue
		end
		if challenge.Kind == "StrikeStreak" then
			if isStrike then
				mine[challenge.Id] = (mine[challenge.Id] or 0) + 1
			elseif not saved then
				mine[challenge.Id] = 0
			end
		end
		if (mine[challenge.Id] or 0) >= challenge.Goal then
			mine[challenge.Id] = 0
			player:SetAttribute("ChallengeReady_" .. challenge.Id, now + (challenge.Cooldown or 0))
			local shown = give(player, challenge.Reward, "Challenge")
			shown.Kind = "Challenge"
			shown.Id = challenge.Id
			SessionLog.Moment(player, ("Challenge %s done"):format(challenge.Id))
			Analytics.Event(player, "ChallengeDone", 1, { challenge.Id })
			rewardEvent:FireClient(player, shown)
		end
		player:SetAttribute(challengeKey(challenge), mine[challenge.Id] or 0)
	end
end

function MilestoneService:Start()
	rewardEvent = Instance.new("RemoteEvent")
	rewardEvent.Name = "MilestoneReward"
	rewardEvent.Parent = ReplicatedStorage:WaitForChild("Remotes")

	ProgressionService.OnLevel(onLevel)
	Players.PlayerRemoving:Connect(function(player)
		progress[player] = nil
	end)
end

return MilestoneService
