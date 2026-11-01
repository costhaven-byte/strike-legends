-- Power Levels: upgrades bought with coins, one at a time and in order (Config.Economy.PowerLevels).
-- The level is saved as PowerLevel and mirrored to the player's PowerLevel attribute; ThrowService reads it
-- for Power (pins) and Value (payout), and every client draws the ball with Config.Throw.Levels.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local PowerLevels = require(Shared.Modules.PowerLevels)
local Currency = require(Shared.Modules.Currency)
local Analytics = require(script.Parent.Analytics)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RateLimit = require(script.Parent.Parent.Modules.RateLimit)
local SessionLog = require(script.Parent.Parent.Modules.SessionLog)

local PowerLevelService = {}

local function currentLevel(player: Player): number
	return math.clamp(math.floor(tonumber(PlayerDataService.Get(player, "PowerLevel")) or 1), 1, PowerLevels.Max)
end

-- Buys the next Power Level. Returns what the client shows.
local function onBuy(player: Player)
	if not PlayerDataService.IsLoaded(player) or not RateLimit.Allow(player, "BuyPowerLevel") then
		return { Ok = false, Error = "That didn't work. Try again" }
	end
	if Config.CoreLoop.Enabled then
		-- Addendum 5 A2: the core loop sells nothing away from the shop booth (Power Levels don't count there anyway)
		return { Ok = false, Error = "Buy at the shop" }
	end
	local level = currentLevel(player)
	local nextRow = PowerLevels.Next(level)
	if not nextRow then
		return { Ok = false, Error = "MAX LEVEL" }
	end
	if not PlayerDataService.Spend(player, "Coins", nextRow.Price) then
		return { Ok = false, Error = "Not enough coins" }
	end
	PlayerDataService.Set(player, "PowerLevel", nextRow.Level)
	Analytics.Currency(player, "Coins", -nextRow.Price, "Shop", "PowerLevel" .. nextRow.Level)
	Analytics.Purchase(player, "PowerLevel", tostring(nextRow.Level))
	Analytics.Step(player, "Bought Power Level")
	SessionLog.Moment(player, ("Power Level %d bought (%d coins)"):format(nextRow.Level, nextRow.Price))
	return { Ok = true, Level = nextRow.Level }
end

-- Studio only (never in the live game): coins for the next Power Level, so every level can be tested quickly
local function onTestCoins(player: Player)
	if not RunService:IsStudio() or not PlayerDataService.IsLoaded(player) then
		return
	end
	local nextRow = PowerLevels.Next(currentLevel(player))
	local coins = PlayerDataService.Get(player, "Coins") or 0
	if nextRow and not Currency.CanAfford(coins, nextRow.Price) then
		PlayerDataService.Add(player, "Coins", Currency.Sub(nextRow.Price, coins))
	end
end

function PowerLevelService:Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local buy = Instance.new("RemoteFunction")
	buy.Name = "BuyPowerLevel"
	buy.Parent = remotes
	buy.OnServerInvoke = onBuy

	if RunService:IsStudio() then
		local test = Instance.new("RemoteEvent")
		test.Name = "TestCoins"
		test.Parent = remotes
		test.OnServerEvent:Connect(onTestCoins)

		-- Studio only: prints this player's session report (PERFECT rate + first-5-minutes timeline) in Output
		local report = Instance.new("RemoteEvent")
		report.Name = "TestReport"
		report.Parent = remotes
		report.OnServerEvent:Connect(function(player)
			print(SessionLog.Report(player))
		end)
	end

	PlayerDataService.OnLoaded(function(player)
		-- Repair a broken saved level
		local level = currentLevel(player)
		if PlayerDataService.Get(player, "PowerLevel") ~= level then
			PlayerDataService.Set(player, "PowerLevel", level)
		end
	end)
end

return PowerLevelService
