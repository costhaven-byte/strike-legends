-- Rebirth (Phase X Part 6, numbers from economy pass E3a; Config.Economy.Rebirth, OFF until the owner sets
-- Enabled = true). From the REBIRTH button on the HUD (owner 2026-10-25: no station), once your level and coins are high enough, start over at level 1, Power Level 1 and
-- 0 coins (balls, pets, gems, potions and seen zones stay) for a permanent coin and XP boost (Shared.Modules.Rebirth).
-- Zones lock again after a rebirth (owner 2026-10-25). Saved: Rebirths.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Currency = require(Shared.Modules.Currency)
local Rebirth = require(Shared.Modules.Rebirth)
local Analytics = require(script.Parent.Analytics)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressionService = require(script.Parent.ProgressionService)
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

	-- Start over (the cost is part of the coins that go)
	PlayerDataService.Set(player, "Coins", Currency.Zero())
	PlayerDataService.Set(player, "XP", 0)
	PlayerDataService.Set(player, "Rank", 1)
	PlayerDataService.Set(player, "RankLevel", 1)
	PlayerDataService.Set(player, "PowerLevel", 1)
	PlayerDataService.Set(player, "Rebirths", done + 1)
	ProgressionService.RefreshRankUpReady(player)
	Analytics.Event(player, "Rebirth", done + 1)
	SessionLog.Moment(player, ("Rebirth %d"):format(done + 1))
	task.delay(1, function()
		if player.Parent then
			player:LoadCharacter() -- back to the start, out of the zones the reset level no longer opens
		end
	end)
	return { Ok = true, Rebirths = done + 1 }
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
