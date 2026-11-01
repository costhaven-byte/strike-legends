-- Every coin multiplier in one place (master plan steps 13.1 and 14.6, built in Addendum 2 step 8b).
-- ThrowService pays each throw with Coins(); the Multiplier panel on the HUD shows the same numbers, which the
-- server publishes as the Player attribute CoinMultipliers ("PowerLevel=2;Ball=1.1;Mascots=1.04;...").
-- Only multipliers that are always on go in the panel; PERFECT (x2), overcharge and the Golden Pin only count
-- on the throw that earns them (the panel lists them as "on a PERFECT" and so on).
-- It also publishes CoinsPerMinute (polish P1, the green "+12K/min" under the coin counter; AwayService.PerMinute).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local LaneUtil = require(Shared.Modules.LaneUtil)
local Modifiers = require(Shared.Modules.Modifiers)
local PowerLevels = require(Shared.Modules.PowerLevels)
local Progression = require(Shared.Modules.Progression)
local Rebirth = require(Shared.Modules.Rebirth)
local Store = require(Shared.Modules.Store)
local ThrowRules = require(Shared.Modules.ThrowRules)
local Zones = require(Shared.Modules.Zones)
local AwayService = require(script.Parent.AwayService)
local BallService = require(script.Parent.BallService)
local FeverService = require(script.Parent.FeverService)
local FriendService = require(script.Parent.FriendService)
local MascotService = require(script.Parent.MascotService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PotionService = require(script.Parent.PotionService)
local ProgressionService = require(script.Parent.ProgressionService)

local REFRESH = 0.5 -- seconds between checks for a changed multiplier

-- The order the panel lists them in
local ORDER = {
	"Zone",
	"PowerLevel",
	"Ball",
	"Mascots",
	"Potion",
	"Rank",
	"Rebirth",
	"Friends",
	"Passes",
	"RobuxBoost",
	"Streak",
	"Modifier",
	"Fever",
}

local MultiplierService = {}

-- Every coin multiplier for a throw. Future gamepasses, boosts and rebirth get added here as new entries
-- (and to ORDER, and to the panel's names in HudController).
-- zone: the zone of the lane the throw was on (Zone = that zone's CoinPay, economy pass E2)
function MultiplierService.Coins(player: Player, ball, level, streak: number, modifier, goldenHit: boolean, zone: number)
	return {
		Zone = Zones.CoinPay(zone),
		PowerLevel = level.Value,
		Ball = BallService.GetMultiplier(player, ball), -- Polish included
		Mascots = MascotService.GetMultiplier(player), -- 1 + equipped mascots' bonuses (Shiny x2)
		Potion = PotionService.Multiplier(player, "Coins"), -- Coin Potion x2 / Mega Coin Potion x4 (Config.Potions)
		Rank = Progression.GetRank(ProgressionService.GetCurrentRankIndex(player)).Multiplier,
		Rebirth = Rebirth.CoinMultiplier(PlayerDataService.Get(player, "Rebirths")), -- Phase X rebirth stub
		Friends = FriendService.Multiplier(player), -- +10% per friend in the server (Config.Friends, step 11a)
		Passes = Store.CoinMultiplier(player), -- 2X COINS + 2X XP and VIP game passes (Config.Monetization, step 12a)
		RobuxBoost = Store.BoostMultiplier(player), -- the COIN BOOST ladder bought with Robux (up to x2)
		Streak = Progression.GetStreakMultiplier(streak),
		Modifier = modifier and modifier.CoinMultiplier or 1,
		Fever = FeverService.Multiplier(player), -- FEVER MODE x3 for 15 s (Config.Fever; ThrowService sets 1 on auto throws)
		GoldenPin = if goldenHit then Config.GoldenPin.CoinMultiplier else 1,
	}
end

-- Every XP multiplier for a throw (moved here from ThrowService in Polish P5 so the Profile panel lists the same
-- numbers that pay; published as the Player attribute XpMultipliers). Pets boost XP by the same amount they boost
-- coins (owner 2026-10-22).
local XP_ORDER = { "Zone", "Pets", "Potion", "Rebirth", "Passes", "XpBoost", "Streak" }
function MultiplierService.Xp(player: Player, streak: number, zone: number): { [string]: number }
	return {
		Zone = Zones.XpPay(zone), -- later zones pay more XP (Config.Economy.Zones XpPay, economy pass E2)
		Streak = Progression.GetStreakXpMultiplier(streak),
		Pets = MascotService.GetMultiplier(player),
		Potion = PotionService.Multiplier(player, "XP"), -- XP Potion x2 / Mega XP Potion x4 (Config.Potions)
		Rebirth = Rebirth.XpMultiplier(PlayerDataService.Get(player, "Rebirths")), -- Phase X rebirth stub
		Passes = Store.XpMultiplier(player), -- 2X COINS + 2X XP and VIP game passes (Config.Monetization)
		XpBoost = Store.XpBoostMultiplier(player), -- the XP BOOST ladder bought with Robux (up to x2)
	}
end

local function encode(all: { [string]: number }, order: { string }): string
	local parts = {}
	for _, name in order do
		table.insert(parts, ("%s=%s"):format(name, tostring(math.floor((all[name] or 1) * 1000 + 0.5) / 1000)))
	end
	return table.concat(parts, ";")
end

-- Multipliers that are on between throws (everything in ORDER but Streak and lane Modifier), multiplied together.
-- Coins per minute takes these out of past throws and puts today's back in, so an upgrade shows at once.
local NOT_STEADY = { Streak = true, Modifier = true, Fever = true }
function MultiplierService.Steady(all): number
	local product = 1
	if Config.CoreLoop.Enabled then
		-- (Addendum 4 core loop: pins pay only these multipliers, ThrowService coreThrow)
		for _, name in Config.CoreLoop.Multipliers do
			product *= all[name] or 1
		end
		return product
	end
	for _, name in ORDER do
		if not NOT_STEADY[name] then
			product *= all[name] or 1
		end
	end
	return product
end

-- The zone of each player's last lane, so the rate doesn't drop while you walk around between lanes
local lastZone: { [Player]: number } = {}

local function publish(player: Player)
	local ball = BallService.GetEquipped(player)
	if not ball then
		return
	end
	local level = PowerLevels.Get(ThrowRules.Level(PlayerDataService.Get(player, "PowerLevel")))
	local lane = LaneUtil.GetOwnedLane(player.UserId)
	local zone = if lane then LaneUtil.ZoneOf(lane) else lastZone[player] or 1
	lastZone[player] = zone
	local all = MultiplierService.Coins(
		player,
		ball,
		level,
		player:GetAttribute("Streak") or 0,
		Modifiers.Current(),
		false,
		zone
	)
	local text = encode(all, ORDER)
	if player:GetAttribute("CoinMultipliers") ~= text then
		player:SetAttribute("CoinMultipliers", text)
	end
	-- XP sources for the Profile panel (Polish P5)
	local xpText = encode(MultiplierService.Xp(player, player:GetAttribute("Streak") or 0, zone), XP_ORDER)
	if player:GetAttribute("XpMultipliers") ~= xpText then
		player:SetAttribute("XpMultipliers", xpText)
	end
	if Config.Income.Enabled then
		local perMinute = AwayService.PerMinute(player, MultiplierService.Steady(all))
		if player:GetAttribute("CoinsPerMinute") ~= perMinute then
			player:SetAttribute("CoinsPerMinute", perMinute)
		end
	end
end

function MultiplierService:Start()
	Players.PlayerRemoving:Connect(function(player)
		lastZone[player] = nil
	end)
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				if PlayerDataService.IsLoaded(player) then
					local ok, err = pcall(publish, player)
					if not ok then
						warn("[MultiplierService] " .. tostring(err))
					end
				end
			end
			task.wait(REFRESH)
		end
	end)
end

return MultiplierService
