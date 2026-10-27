-- Rebirth (Phase X Part 6; Config.Economy.Rebirth, OFF until the owner sets Enabled = true). From the REBIRTH button
-- on the HUD (owner 2026-10-25: no station), once your level and coins are high enough: back to Power Level 1 and
-- 0 coins (level, rank, balls, pets, gems and potions stay) for a permanent coin and XP boost (Shared.Modules.Rebirth).
-- Owner 2026-10-27: rebirths open the zones (zone 2 = 1 rebirth, zone 3 = 3, zone 4 = 5; save ZonesOpen), and
-- open zones never lock again. Saved: Rebirths, ZonesOpen.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Currency = require(Shared.Modules.Currency)
local Rebirth = require(Shared.Modules.Rebirth)
local Zones = require(Shared.Modules.Zones)
local Analytics = require(script.Parent.Analytics)
local AwayService = require(script.Parent.AwayService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RateLimit = require(script.Parent.Parent.Modules.RateLimit)
local SessionLog = require(script.Parent.Parent.Modules.SessionLog)

local REBIRTH = Config.Economy.Rebirth

local RebirthService = {}

local function rebirth(player: Player)
	if not REBIRTH.Enabled then
		return { Ok = false, Error = "Rebirth is coming soon" }
	end
	if not PlayerDataService.IsLoaded(player) or not RateLimit.Allow(player, "Rebirth") then
		return { Ok = false, Error = "Try again" }
	end
	local done = PlayerDataService.Get(player, "Rebirths") or 0
	if (PlayerDataService.Get(player, "RankLevel") or 1) < Rebirth.Level(done) then
		return { Ok = false, Error = ("Reach level %d first"):format(Rebirth.Level(done)) }
	end
	local cost = Rebirth.Cost(done)
	if not PlayerDataService.CanAfford(player, "Coins", cost) then
		return { Ok = false, Error = ("Need %s coins"):format(Currency.Format(cost)) }
	end

	-- Start over (the cost is part of the coins that go). Level, rank and XP stay (owner 2026-10-27).
	PlayerDataService.Set(player, "Coins", Currency.Zero())
	PlayerDataService.Set(player, "PowerLevel", 1)
	PlayerDataService.Set(player, "Rebirths", done + 1)
	local opened = Rebirth.OpensZone(done)
	PlayerDataService.Set(
		player,
		"ZonesOpen",
		math.max(PlayerDataService.Get(player, "ZonesOpen") or 1, Zones.ForRebirths(done + 1))
	)
	AwayService.Reset(player)
	Analytics.Event(player, "Rebirth", done + 1)
	SessionLog.Moment(player, ("Rebirth %d"):format(done + 1))
	return { Ok = true, Rebirths = done + 1, Zone = opened }
end

function RebirthService:Start()
	local remote = Instance.new("RemoteFunction")
	remote.Name = "Rebirth"
	remote.OnServerInvoke = function(player)
		local ok, result = pcall(rebirth, player)
		if not ok then
			warn("[RebirthService] " .. tostring(result))
			return { Ok = false, Error = "Something went wrong" }
		end
		return result
	end
	remote.Parent = ReplicatedStorage:WaitForChild("Remotes")
end

return RebirthService
