-- "While you were away" coins (Addendum 2 step 11a, Config.Away). While you play, the coins your throws earn are
-- measured over your last RateMinutes of throwing (idle time doesn't lower it); that rate is saved as AwayRate, and
-- LastOnline is kept up to date. Coming back after at least MinMinutes pays Share x AwayRate for every second away
-- (up to MaxHours), shown in a WELCOME BACK popup (MilestoneService reward popup, Kind "Away").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Currency = require(Shared.Modules.Currency)
local MilestoneService = require(script.Parent.MilestoneService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local AWAY = Config.Away
local TICK = 60 -- seconds between LastOnline / AwayRate updates (so a crashed server loses at most a minute)

local AwayService = {}

-- Coins earned per throw this visit: { { Time, Coins } }, oldest first, only the last RateMinutes of throwing
local earned: { [Player]: { { number } } } = {}

-- Coins per second over the last RateMinutes of throwing, or nil if there's too little to measure
local function measure(player: Player): number?
	local list = earned[player]
	if not list or #list < 2 then
		return nil
	end
	local total = Currency.Zero()
	for _, entry in list do
		total = Currency.Add(total, entry[2])
	end
	local span = math.max(list[#list][1] - list[1][1], 60)
	return Currency.Scale(total, 1 / span)
end

local function update(player: Player)
	if not PlayerDataService.IsLoaded(player) then
		return
	end
	local rate = measure(player)
	if rate then
		PlayerDataService.Set(player, "AwayRate", rate)
	end
	PlayerDataService.Set(player, "LastOnline", os.time())
end

-- Called by ThrowService when a throw pays coins
function AwayService.OnCoins(player: Player, coins: number)
	local list = earned[player]
	if not list then
		list = {}
		earned[player] = list
	end
	local now = os.clock()
	table.insert(list, { now, coins })
	while #list > 0 and list[1][1] < now - AWAY.RateMinutes * 60 do
		table.remove(list, 1)
	end
end

-- Called by RebirthService: income from before the rebirth doesn't count for away coins
function AwayService.Reset(player: Player)
	earned[player] = {}
	PlayerDataService.Set(player, "AwayRate", 0)
end

local function welcome(player: Player)
	local last = tonumber(PlayerDataService.Get(player, "LastOnline")) or 0
	local rate = tonumber(PlayerDataService.Get(player, "AwayRate")) or 0
	PlayerDataService.Set(player, "LastOnline", os.time())
	local test = AWAY.StudioTest
	if test and RunService:IsStudio() then
		last = os.time() - test.Hours * 3600
		rate = math.max(rate, test.Rate)
	end
	if not AWAY.Enabled or last <= 0 or rate <= 0 then
		return
	end
	local away = os.time() - last
	if away < AWAY.MinMinutes * 60 then
		return
	end
	local seconds = math.min(away, AWAY.MaxHours * 3600)
	local coins = Currency.Mul(rate, seconds * AWAY.Share, "AwayCoins")
	if coins <= 0 then
		return
	end
	task.wait(AWAY.PopupDelay)
	if PlayerDataService.IsLoaded(player) then
		MilestoneService.Reward(player, { Coins = coins }, "Away", "Away")
	end
end

function AwayService:Start()
	PlayerDataService.OnLoaded(welcome)
	PlayerDataService.OnRelease(update)
	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			earned[player] = nil
		end)
	end)
	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, player in Players:GetPlayers() do
				update(player)
			end
		end
	end)
end

return AwayService
