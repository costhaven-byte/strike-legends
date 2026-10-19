-- The first 3 minutes (Addendum 2 section 6, settings in Config.Onboarding): one scripted path for new players.
-- Saved as Onboarding (the stage) and OnboardThrows; both are mirrored to Player attributes for the client.
--   0 = the next throw is an assisted PERFECT strike
--   1 = playing toward the gift crate (after GiftAfterThrows throws)
--   2 = gift given; the camera shows a locked showcase ball after LegendsAfterThrows more throws
--   3 = done
-- The client shows each moment when the server sends it on Remotes.Onboarding ({ Kind = "Gift" | "Legends" }).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local Analytics = require(script.Parent.Analytics)
local BallService = require(script.Parent.BallService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local SessionLog = require(script.Parent.Parent.Modules.SessionLog)

local SETTINGS = Config.Onboarding
local DONE = 3

local OnboardingService = {}

local remote: RemoteEvent? = nil

local function stage(player: Player): number
	return tonumber(PlayerDataService.Get(player, "Onboarding")) or DONE
end

-- Is this player's next throw the assisted first throw?
function OnboardingService.IsAssisted(player: Player): boolean
	return SETTINGS.Enabled and stage(player) == 0
end

-- Called the moment an assisted throw is accepted, so it can only ever happen once
function OnboardingService.UseAssist(player: Player)
	if stage(player) == 0 then
		PlayerDataService.Set(player, "Onboarding", 1)
	end
end

-- After every throw. delay: seconds until the lane has reset (moments wait for it, so they never cover a throw)
function OnboardingService.OnThrow(player: Player, delay: number)
	local current = stage(player)
	if not SETTINGS.Enabled or current >= DONE then
		return
	end
	PlayerDataService.Add(player, "OnboardThrows", 1)
	local throws = PlayerDataService.Get(player, "OnboardThrows") or 0

	if current <= 1 and throws >= SETTINGS.GiftAfterThrows then
		local crate = Balls.GetCrate(SETTINGS.GiftCrateId)
		if not crate then
			warn("[OnboardingService] Config.Onboarding.GiftCrateId is not a crate: " .. tostring(SETTINGS.GiftCrateId))
			PlayerDataService.Set(player, "Onboarding", 2)
			return
		end
		-- The ball is given now (so leaving early never loses it); the client shows the opening once the lane resets
		PlayerDataService.Set(player, "Onboarding", 2)
		SessionLog.Moment(player, "Gift crate given (next line is its ball)")
		local result = BallService.GiveCrate(player, crate, Config.Economy.FirstCrateMin)
		Analytics.Step(player, "Gift Crate")
		task.delay(delay, function()
			if player.Parent and remote then
				remote:FireClient(player, { Kind = "Gift", CrateId = crate.Id, Result = result })
			end
		end)
	elseif current == 2 and throws >= SETTINGS.GiftAfterThrows + SETTINGS.LegendsAfterThrows then
		PlayerDataService.Set(player, "Onboarding", DONE)
		Analytics.Step(player, "Saw Legends")
		task.delay(delay, function()
			if player.Parent and remote then
				remote:FireClient(player, { Kind = "Legends" })
			end
		end)
	end
end

function OnboardingService:Start()
	local event = Instance.new("RemoteEvent")
	event.Name = "Onboarding"
	event.Parent = ReplicatedStorage:WaitForChild("Remotes")
	remote = event
end

return OnboardingService
