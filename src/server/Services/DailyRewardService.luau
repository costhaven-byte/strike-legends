-- The 7-day daily reward calendar. The server decides which day you're on and hands out the reward.
-- Clients see two Player attributes: DailyNext (the calendar day to claim, or just claimed today)
-- and DailyClaimable (true if today's reward is waiting).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Calendar = require(Shared.Modules.Calendar)
local Balls = require(Shared.Modules.Balls)
local Zones = require(Shared.Modules.Zones)
local Analytics = require(script.Parent.Analytics)
local PlayerDataService = require(script.Parent.PlayerDataService)
local BallService = require(script.Parent.BallService)
local RateLimit = require(script.Parent.Parent.Modules.RateLimit)
local SessionLog = require(script.Parent.Parent.Modules.SessionLog)

local DAILY = Config.Daily

local DailyRewardService = {}

local busy: { [Player]: boolean } = {}

-- Which calendar day the player is on today, and whether they can still claim it.
local function getState(player: Player): (number, boolean)
	local lastDay = PlayerDataService.Get(player, "DailyDay") or 0
	local lastClaim = PlayerDataService.Get(player, "DailyLastClaim") or 0
	local today = Calendar.Day()
	if lastDay > 0 and lastClaim == today then
		return lastDay, false -- already claimed today
	elseif lastDay > 0 and lastClaim == today - 1 then
		return lastDay % #DAILY.Rewards + 1, true -- came back the next day: streak continues
	end
	return 1, true -- first time, or missed a day: back to day 1
end

local function publish(player: Player)
	if not PlayerDataService.IsLoaded(player) then
		return
	end
	local day, claimable = getState(player)
	player:SetAttribute("DailyNext", day)
	player:SetAttribute("DailyClaimable", claimable)
end

local function claim(player: Player)
	if not PlayerDataService.IsLoaded(player) then
		return { Ok = false, Error = "Still loading" }
	end
	-- The calendar unlocks once the first 3 minutes are done (stage 3, see OnboardingService)
	if Config.Onboarding.Enabled and (tonumber(PlayerDataService.Get(player, "Onboarding")) or 3) < 3 then
		return { Ok = false, Error = "Keep bowling!" }
	end
	local day, claimable = getState(player)
	if not claimable then
		return { Ok = false, Error = "Come back tomorrow!" }
	end
	local reward = DAILY.Rewards[day]

	PlayerDataService.Set(player, "DailyDay", day)
	PlayerDataService.Set(player, "DailyLastClaim", Calendar.Day())
	if reward.Coins then
		PlayerDataService.Add(player, "Coins", reward.Coins)
		Analytics.Currency(player, "Coins", reward.Coins, "TimedReward", "Daily")
	end
	if reward.Gems and Config.Gems.Enabled then
		PlayerDataService.Add(player, "Gems", reward.Gems)
		Analytics.Currency(player, "Gems", reward.Gems, "TimedReward", "Daily")
	end
	Analytics.Event(player, "DailyClaimed", day)
	SessionLog.Moment(player, ("Daily reward day %d claimed"):format(day))
	local crateResult
	-- A crate from a zone you haven't unlocked yet comes as your zone's crate
	local crate = Balls.GetCrate(Zones.RewardCrateId(reward.Crate, PlayerDataService.Get(player, "RankLevel")))
	if crate then
		crateResult = BallService.GiveCrate(player, crate)
	end
	publish(player)

	return { Ok = true, Day = day, CrateId = crate and crate.Id, Crate = crateResult }
end

local function onClaim(player: Player)
	if busy[player] or not RateLimit.Allow(player, "ClaimDaily") then
		return { Ok = false, Error = "Slow down!" }
	end
	busy[player] = true
	local ok, result = pcall(claim, player)
	busy[player] = nil
	if not ok then
		warn("[DailyRewardService] Claim failed: " .. tostring(result))
		return { Ok = false, Error = "Something went wrong" }
	end
	return result
end

function DailyRewardService:Start()
	local remote = Instance.new("RemoteFunction")
	remote.Name = "ClaimDaily"
	remote.Parent = ReplicatedStorage:WaitForChild("Remotes")
	remote.OnServerInvoke = onClaim

	PlayerDataService.OnLoaded(publish)
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)

	-- Unlock the next reward for anyone still playing when the day changes
	task.spawn(function()
		while true do
			task.wait(DAILY.CheckInterval)
			for _, player in Players:GetPlayers() do
				publish(player)
			end
		end
	end)
end

return DailyRewardService
