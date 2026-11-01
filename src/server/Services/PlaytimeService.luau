-- Playtime rewards (owner 2026-10-22, Config.Playtime): a gift on joining, then a free gift every 15 minutes of play.
-- Batch B4 (2026-10-29): one set a day. The clock and the claimed gifts are saved per day (PlaytimeDay,
-- PlaytimeSeconds, PlaytimeGot): coming back the same day carries on, a new day (midnight UTC) starts a fresh set,
-- even mid-visit. What a gift gives grows with progress (Shared.Modules.PlaytimeRewards).
-- Clients see two Player attributes: PlaytimeStart (workspace:GetServerTimeNow() minus the seconds already played
-- today) and PlaytimeClaimed ("1,2,4": today's claimed gifts, by number).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local Calendar = require(Shared.Modules.Calendar)
local PlaytimeRewards = require(Shared.Modules.PlaytimeRewards)
local Analytics = require(script.Parent.Analytics)
local PlayerDataService = require(script.Parent.PlayerDataService)
local BallService = require(script.Parent.BallService)
local MascotService = require(script.Parent.MascotService)
local PotionService = require(script.Parent.PotionService)
local RateLimit = require(script.Parent.Parent.Modules.RateLimit)
local SessionLog = require(script.Parent.Parent.Modules.SessionLog)

local PLAYTIME = Config.Playtime

local PlaytimeService = {}

local started: { [Player]: number } = {} -- server time today's clock would have started (now - seconds played today)
local claimed: { [Player]: { [number]: boolean } } = {}
local busy: { [Player]: boolean } = {}

local function claimedText(player: Player): string
	local list = {}
	for index in claimed[player] or {} do
		table.insert(list, index)
	end
	table.sort(list)
	return table.concat(list, ",")
end

local function publish(player: Player)
	player:SetAttribute("PlaytimeStart", started[player])
	player:SetAttribute("PlaytimeClaimed", claimedText(player))
end

-- Writes today's clock into the save (PlaytimeSeconds), so leaving and coming back the same day carries on
local function saveClock(player: Player)
	if started[player] then
		PlayerDataService.Set(player, "PlaytimeSeconds", math.floor(Workspace:GetServerTimeNow() - started[player]))
	end
end

-- A fresh set of gifts for today: the clock at 0, nothing claimed
local function newDay(player: Player, day: number)
	started[player] = Workspace:GetServerTimeNow()
	claimed[player] = {}
	PlayerDataService.Set(player, "PlaytimeDay", day)
	PlayerDataService.Set(player, "PlaytimeSeconds", 0)
	PlayerDataService.Set(player, "PlaytimeGot", "")
	publish(player)
end

-- Joining: today's saved clock and claimed gifts, or a fresh set if the save is from another day
local function load(player: Player)
	local day = Calendar.Day()
	if PlayerDataService.Get(player, "PlaytimeDay") ~= day then
		newDay(player, day)
		return
	end
	local seconds = tonumber(PlayerDataService.Get(player, "PlaytimeSeconds")) or 0
	started[player] = Workspace:GetServerTimeNow() - seconds
	claimed[player] = {}
	for number in tostring(PlayerDataService.Get(player, "PlaytimeGot") or ""):gmatch("%d+") do
		claimed[player][tonumber(number) :: number] = true
	end
	publish(player)
end

local function claim(player: Player, index: any)
	local reward = type(index) == "number" and PLAYTIME.Rewards[index]
	if not PLAYTIME.Enabled or not reward or not started[player] or not PlayerDataService.IsLoaded(player) then
		return { Ok = false, Error = "That didn't work. Try again" }
	end
	if claimed[player][index] then
		return { Ok = false, Error = "You already got this one" }
	end
	local played = Workspace:GetServerTimeNow() - started[player]
	if played < reward.Minutes * 60 - 1 then -- 1 second of slack for the client's clock
		return { Ok = false, Error = "Not yet" }
	end
	claimed[player][index] = true
	PlayerDataService.Set(player, "PlaytimeGot", claimedText(player))

	local gift = PlaytimeRewards.Resolve(index, {
		PowerLevel = PlayerDataService.Get(player, "PowerLevel"),
		ZonesOpen = PlayerDataService.Get(player, "ZonesOpen"),
		AwayRate = PlayerDataService.Get(player, "AwayRate"),
		BallStep = PlayerDataService.Get(player, "BallStep"),
		BagLevel = PlayerDataService.Get(player, "BagLevel"),
	})
	local kind, item = nil, nil
	local result: { [string]: any } = { Ok = true }
	if gift.Coins then
		kind, item = "Coins", tostring(gift.Coins)
		PlayerDataService.Add(player, "Coins", gift.Coins)
		Analytics.Currency(player, "Coins", gift.Coins, "TimedReward", "Playtime")
		result.Coins = gift.Coins
	elseif gift.Potion then
		kind, item = "Potion", gift.Potion
		PotionService.Give(player, gift.Potion, gift.Count or 1)
		result.Potion = gift.Potion
		result.Count = gift.Count or 1
	elseif gift.Egg then
		kind, item = "Egg", gift.Egg
		MascotService.GiveFreeEgg(player, gift.Egg, 1)
		result.Egg = gift.Egg
	elseif gift.Crate then
		local crate = Balls.GetCrate(gift.Crate)
		if crate then
			kind, item = "Crate", crate.Id
			result.CrateId = crate.Id
			result.Crate = BallService.GiveCrate(player, crate)
		end
	end
	publish(player)
	Analytics.Event(player, "PlaytimeClaimed", reward.Minutes, { kind or "?", item or "?" })
	SessionLog.Moment(player, ("Playtime gift %d (%d min) claimed: %s"):format(index, reward.Minutes, item or "?"))
	return result
end

local function onClaim(player: Player, index: any)
	if busy[player] or not RateLimit.Allow(player, "ClaimPlaytime") then
		return { Ok = false, Error = "Too fast, wait a sec" }
	end
	busy[player] = true
	local ok, result = pcall(claim, player, index)
	busy[player] = nil
	if not ok then
		warn("[PlaytimeService] Claim failed: " .. tostring(result))
		return { Ok = false, Error = "That didn't work. Try again" }
	end
	return result
end

function PlaytimeService:Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local remote = Instance.new("RemoteFunction")
	remote.Name = "ClaimPlaytime"
	remote.OnServerInvoke = onClaim
	remote.Parent = remotes

	-- Studio only (never in the live game): jump the clock 15 minutes ahead
	if RunService:IsStudio() then
		local test = Instance.new("RemoteEvent")
		test.Name = "TestPlaytime"
		test.OnServerEvent:Connect(function(player)
			if started[player] then
				started[player] -= 15 * 60
				saveClock(player)
				publish(player)
			end
		end)
		test.Parent = remotes
	end

	PlayerDataService.OnLoaded(load)
	PlayerDataService.OnRelease(saveClock)
	-- Save the clock now and then (a server crash keeps most of today's time) and start a fresh set at midnight UTC
	task.spawn(function()
		while true do
			task.wait(PLAYTIME.SaveEvery or 30)
			local day = Calendar.Day()
			for player in started do
				if PlayerDataService.IsLoaded(player) then
					if PlayerDataService.Get(player, "PlaytimeDay") ~= day then
						newDay(player, day)
					else
						saveClock(player)
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		started[player] = nil
		claimed[player] = nil
		busy[player] = nil
	end)
end

return PlaytimeService
