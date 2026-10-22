-- Every coin multiplier in one place (master plan steps 13.1 and 14.6, built in Addendum 2 step 8b).
-- ThrowService pays each throw with Coins(); the Multiplier panel on the HUD shows the same numbers, which the
-- server publishes as the Player attribute CoinMultipliers ("PowerLevel=2;Ball=1.1;Mascots=1.04;...").
-- Only multipliers that are always on go in the panel; PERFECT (x2), overcharge and the Golden Pin only count
-- on the throw that earns them (the panel lists them as "on a PERFECT" and so on).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Modifiers = require(Shared.Modules.Modifiers)
local PowerLevels = require(Shared.Modules.PowerLevels)
local Progression = require(Shared.Modules.Progression)
local Rebirth = require(Shared.Modules.Rebirth)
local ThrowRules = require(Shared.Modules.ThrowRules)
local BallService = require(script.Parent.BallService)
local MascotService = require(script.Parent.MascotService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PotionService = require(script.Parent.PotionService)
local ProgressionService = require(script.Parent.ProgressionService)

local REFRESH = 0.5 -- seconds between checks for a changed multiplier

-- The order the panel lists them in
local ORDER = { "PowerLevel", "Ball", "Mascots", "Potion", "Rank", "Rebirth", "Streak", "Modifier" }

local MultiplierService = {}

-- Every coin multiplier for a throw. Future gamepasses, boosts and rebirth get added here as new entries
-- (and to ORDER, and to the panel's names in HudController).
function MultiplierService.Coins(player: Player, ball, level, streak: number, modifier, goldenHit: boolean)
	return {
		PowerLevel = level.Value,
		Ball = BallService.GetMultiplier(player, ball), -- Polish included
		Mascots = MascotService.GetMultiplier(player), -- 1 + equipped mascots' bonuses (Shiny x2)
		Potion = PotionService.Multiplier(player, "Coins"), -- Coin Potion x2 / Mega Coin Potion x4 (Config.Potions)
		Rank = Progression.GetRank(ProgressionService.GetCurrentRankIndex(player)).Multiplier,
		Rebirth = Rebirth.CoinMultiplier(PlayerDataService.Get(player, "Rebirths")), -- Phase X rebirth stub
		Streak = Progression.GetStreakMultiplier(streak),
		Modifier = modifier and modifier.CoinMultiplier or 1,
		GoldenPin = if goldenHit then Config.GoldenPin.CoinMultiplier else 1,
	}
end

local function publish(player: Player)
	local ball = BallService.GetEquipped(player)
	if not ball then
		return
	end
	local level = PowerLevels.Get(ThrowRules.Level(PlayerDataService.Get(player, "PowerLevel")))
	local all =
		MultiplierService.Coins(player, ball, level, player:GetAttribute("Streak") or 0, Modifiers.Current(), false)
	local parts = {}
	for _, name in ORDER do
		table.insert(parts, ("%s=%s"):format(name, tostring(math.floor((all[name] or 1) * 1000 + 0.5) / 1000)))
	end
	local text = table.concat(parts, ";")
	if player:GetAttribute("CoinMultipliers") ~= text then
		player:SetAttribute("CoinMultipliers", text)
	end
end

function MultiplierService:Start()
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
