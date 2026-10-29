-- FEVER MODE (final changes batch D4, Config.Fever): Config.Fever.StreakNeeded strikes in a row by hand = Seconds of
-- x CoinMultiplier coins (MultiplierService "Fever") and faster throws (ThrowService: quicker lane reset, looser
-- rate limit). Each strike during fever adds a second (never above the full time); a miss doesn't end it.
-- Auto Bowl throws never change the streak, so they can't start it, and they get neither the pay nor the speed.
-- Publishes the Player attribute FeverEndsAt (server time) for the bar, the music and the lane flames.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Analytics = require(script.Parent.Analytics)
local SessionLog = require(script.Parent.Parent.Modules.SessionLog)

local FEVER = Config.Fever

local FeverService = {}

local endsAt: { [Player]: number } = {}

local function set(player: Player, time: number)
	endsAt[player] = time
	player:SetAttribute("FeverEndsAt", time)
end

function FeverService.Active(player: Player): boolean
	return FEVER.Enabled and Workspace:GetServerTimeNow() < (endsAt[player] or 0)
end

function FeverService.Multiplier(player: Player): number
	return if FeverService.Active(player) then FEVER.CoinMultiplier else 1
end

-- Starts (or refills) fever for the full time; streak = the strikes in a row that started it (Studio TEST: 0)
function FeverService.Begin(player: Player, streak: number)
	set(player, Workspace:GetServerTimeNow() + FEVER.Seconds)
	SessionLog.Moment(player, "FEVER")
	Analytics.Event(player, "Fever", streak)
end

-- A hand throw's ball reached the pins as a strike; streak = the strikes in a row now
function FeverService.OnStrike(player: Player, streak: number)
	if not FEVER.Enabled then
		return
	end
	local now = Workspace:GetServerTimeNow()
	if FeverService.Active(player) then
		set(player, math.min(endsAt[player] + FEVER.StrikeAddsSeconds, now + FEVER.Seconds))
	elseif streak >= FEVER.StreakNeeded and streak % FEVER.StreakNeeded == 0 then
		FeverService.Begin(player, streak)
	end
end

function FeverService:Start()
	Players.PlayerRemoving:Connect(function(player)
		endsAt[player] = nil
	end)
end

return FeverService
