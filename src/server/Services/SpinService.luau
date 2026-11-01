-- The daily spin wheel in Neon Lanes (owner 2026-10-22, Config.Spin): one free spin a day. The server checks you
-- stand by the wheel, rolls the slice, saves the day (SpinDay) and hands out the prize; the client only turns the wheel.
-- Clients see the Player attribute SpinReady (true when today's free spin is waiting).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local Calendar = require(Shared.Modules.Calendar)
local Zones = require(Shared.Modules.Zones)
local Analytics = require(script.Parent.Analytics)
local PlayerDataService = require(script.Parent.PlayerDataService)
local BallService = require(script.Parent.BallService)
local MascotService = require(script.Parent.MascotService)
local PotionService = require(script.Parent.PotionService)
local RateLimit = require(script.Parent.Parent.Modules.RateLimit)
local SessionLog = require(script.Parent.Parent.Modules.SessionLog)

local SPIN = Config.Spin

local SpinService = {}

local busy: { [Player]: boolean } = {}

local function isReady(player: Player): boolean
	return (PlayerDataService.Get(player, "SpinDay") or 0) ~= Calendar.Day()
end

local function publish(player: Player)
	if PlayerDataService.IsLoaded(player) then
		player:SetAttribute("SpinReady", isReady(player))
	end
end

local function nearWheel(player: Player): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local offset = (root.Position - SPIN.Center) * Vector3.new(1, 0, 1)
	return offset.Magnitude <= SPIN.UseRange
end

-- Picks a slice number with the Chance weights
local function roll(): number
	local total = 0
	for _, slice in SPIN.Slices do
		total += slice.Chance
	end
	local pick = math.random() * total
	for index, slice in SPIN.Slices do
		pick -= slice.Chance
		if pick <= 0 then
			return index
		end
	end
	return 1
end

local function spin(player: Player)
	if not SPIN.Enabled or not PlayerDataService.IsLoaded(player) then
		return { Ok = false, Error = "That didn't work. Try again" }
	end
	local zonesOpen = PlayerDataService.Get(player, "ZonesOpen")
	if not Zones.Unlocked(zonesOpen, SPIN.Zone) then
		return { Ok = false, Error = "Unlocks in " .. Zones.Name(SPIN.Zone) }
	end
	if not nearWheel(player) then
		return { Ok = false, Error = "Walk up to the wheel!" }
	end
	if not isReady(player) then
		return { Ok = false, Error = "Already got today's. Come back tomorrow" }
	end

	local index = roll()
	local slice = SPIN.Slices[index]
	PlayerDataService.Set(player, "SpinDay", Calendar.Day())

	local kind, item = "?", "?"
	local result: { [string]: any } = { Ok = true, Slice = index }
	if slice.Potion then
		kind, item = "Potion", slice.Potion
		PotionService.Give(player, slice.Potion, 1)
		result.Potion = slice.Potion
	elseif slice.Pet then
		kind = "Pet"
		local pet = MascotService.GivePet(player, slice.Egg, slice.Pet)
		item = if pet then pet.MascotId else "?"
		result.Pet = pet
	elseif slice.Egg then
		kind, item = "Egg", slice.Egg
		MascotService.GiveFreeEgg(player, slice.Egg, 1)
		result.Egg = slice.Egg
	elseif slice.Crate then
		-- SECRET BALL = exactly that rarity from that crate; a plain crate from a later zone comes as your zone's
		local crate = Balls.GetCrate(if slice.Ball then slice.Crate else Zones.RewardCrateId(slice.Crate, zonesOpen))
		if crate then
			kind = if slice.Ball then "Ball" else "Crate"
			result.CrateId = crate.Id
			result.Crate = BallService.GiveCrate(player, crate, nil, slice.Ball)
			item = if slice.Ball then result.Crate.BallId else crate.Id
		end
	end
	publish(player)
	Analytics.Event(player, "SpinWheel", index, { kind, item })
	SessionLog.Moment(player, ("Daily spin: slice %d %s -> %s"):format(index, slice.Label, tostring(item)))
	return result
end

local function onSpin(player: Player)
	if busy[player] or not RateLimit.Allow(player, "SpinWheel") then
		return { Ok = false, Error = "Too fast, wait a sec" }
	end
	busy[player] = true
	local ok, result = pcall(spin, player)
	busy[player] = nil
	if not ok then
		warn("[SpinService] Spin failed: " .. tostring(result))
		return { Ok = false, Error = "That didn't work. Try again" }
	end
	return result
end

function SpinService:Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local remote = Instance.new("RemoteFunction")
	remote.Name = "SpinWheel"
	remote.OnServerInvoke = onSpin
	remote.Parent = remotes

	-- Studio only (never in the live game): today's free spin back
	if RunService:IsStudio() then
		local test = Instance.new("RemoteEvent")
		test.Name = "TestSpin"
		test.OnServerEvent:Connect(function(player)
			if PlayerDataService.IsLoaded(player) then
				PlayerDataService.Set(player, "SpinDay", 0)
				publish(player)
			end
		end)
		test.Parent = remotes
	end

	PlayerDataService.OnLoaded(publish)
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)

	-- A new day gives anyone still playing their free spin back
	task.spawn(function()
		while true do
			task.wait(SPIN.CheckInterval)
			for _, player in Players:GetPlayers() do
				publish(player)
			end
		end
	end)
end

return SpinService
