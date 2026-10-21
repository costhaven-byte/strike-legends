-- Playtime rewards (owner 2026-10-22, Config.Playtime): a free gift every 15 minutes of play, 3 hours' worth.
-- Nothing is saved: the clock and the claimed gifts start over on every visit (owner's choice).
-- Clients see two Player attributes: PlaytimeStart (workspace:GetServerTimeNow() when this visit's clock started)
-- and PlaytimeClaimed ("1,2,4": the gifts claimed this visit, by number).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local Zones = require(Shared.Modules.Zones)
local Analytics = require(script.Parent.Analytics)
local PlayerDataService = require(script.Parent.PlayerDataService)
local BallService = require(script.Parent.BallService)
local MascotService = require(script.Parent.MascotService)
local PotionService = require(script.Parent.PotionService)
local RateLimit = require(script.Parent.Parent.Modules.RateLimit)
local SessionLog = require(script.Parent.Parent.Modules.SessionLog)

local PLAYTIME = Config.Playtime

local PlaytimeService = {}

local started: { [Player]: number } = {} -- server time this visit's clock started
local claimed: { [Player]: { [number]: boolean } } = {}
local busy: { [Player]: boolean } = {}

local function publish(player: Player)
	local list = {}
	for index in claimed[player] or {} do
		table.insert(list, index)
	end
	table.sort(list)
	player:SetAttribute("PlaytimeStart", started[player])
	player:SetAttribute("PlaytimeClaimed", table.concat(list, ","))
end

local function startClock(player: Player, at: number)
	started[player] = at
	claimed[player] = {}
	publish(player)
end

local function claim(player: Player, index: any)
	local reward = type(index) == "number" and PLAYTIME.Rewards[index]
	if not PLAYTIME.Enabled or not reward or not started[player] or not PlayerDataService.IsLoaded(player) then
		return { Ok = false, Error = "Something went wrong" }
	end
	if claimed[player][index] then
		return { Ok = false, Error = "Already claimed" }
	end
	local played = Workspace:GetServerTimeNow() - started[player]
	if played < reward.Minutes * 60 - 1 then -- 1 second of slack for the client's clock
		return { Ok = false, Error = "Not yet!" }
	end
	claimed[player][index] = true

	local kind, item = nil, nil
	local result: { [string]: any } = { Ok = true }
	if reward.Potion then
		kind, item = "Potion", reward.Potion
		PotionService.Give(player, reward.Potion, 1)
		result.Potion = reward.Potion
	elseif reward.Egg then
		kind, item = "Egg", reward.Egg
		MascotService.GiveFreeEgg(player, reward.Egg, 1)
		result.Egg = reward.Egg
	elseif reward.Crate then
		-- A crate from a zone you haven't reached comes as your zone's crate (unless Exact)
		local crateId = if reward.Exact
			then reward.Crate
			else Zones.RewardCrateId(reward.Crate, PlayerDataService.Get(player, "RankLevel"))
		local crate = Balls.GetCrate(crateId)
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
		return { Ok = false, Error = "Slow down!" }
	end
	busy[player] = true
	local ok, result = pcall(claim, player, index)
	busy[player] = nil
	if not ok then
		warn("[PlaytimeService] Claim failed: " .. tostring(result))
		return { Ok = false, Error = "Something went wrong" }
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
				publish(player)
			end
		end)
		test.Parent = remotes
	end

	PlayerDataService.OnLoaded(function(player)
		startClock(player, Workspace:GetServerTimeNow())
	end)
	Players.PlayerRemoving:Connect(function(player)
		started[player] = nil
		claimed[player] = nil
		busy[player] = nil
	end)
end

return PlaytimeService
