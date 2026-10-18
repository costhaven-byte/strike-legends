-- Rank Trials: once the XP bar is full, the next rank needs a short trial (Config.Trials).
-- The server runs everything: starting, counting throws, passing and failing, and the retry cooldown.
-- Clients see the trial through Player attributes:
--   TrialState ("None", "Ready", "Active", "Cooldown"), TrialProgress, TrialThrowsLeft, TrialCooldownEnd (server time).
-- Trials are not saved: leaving during a trial just cancels it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Analytics = require(script.Parent.Analytics)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressionService = require(script.Parent.ProgressionService)
local RateLimit = require(script.Parent.Parent.Modules.RateLimit)

local TRIALS = Config.Trials

local TrialService = {}

type Attempt = {
	Id: number,
	Trial: any, -- the row from Config.Trials.Ranks
	Type: any, -- the row from Config.Trials.Types
	Progress: number,
	ThrowsLeft: number,
}

local attempts: { [Player]: Attempt } = {}
local cooldownEnds: { [Player]: number } = {} -- server time when the player can try again
local nextAttemptId = 0
local resultEvent: RemoteEvent

-- The trial for the rank this player is working toward, or nil
local function getTrial(player: Player)
	local nextRank = ProgressionService.GetNextRank(player)
	return nextRank and TRIALS.Ranks[nextRank.Name], nextRank
end

local function publish(player: Player)
	local attempt = attempts[player]
	local now = Workspace:GetServerTimeNow()
	local state = "None"
	if attempt then
		state = "Active"
	elseif ProgressionService.IsRankUpReady(player) and getTrial(player) then
		state = if (cooldownEnds[player] or 0) > now then "Cooldown" else "Ready"
	end
	player:SetAttribute("TrialState", state)
	player:SetAttribute("TrialProgress", if attempt then attempt.Progress else 0)
	player:SetAttribute("TrialThrowsLeft", if attempt then attempt.ThrowsLeft else 0)
	player:SetAttribute("TrialCooldownEnd", cooldownEnds[player] or 0)
end

local function finish(player: Player, passed: boolean)
	attempts[player] = nil
	if passed then
		cooldownEnds[player] = nil
	else
		cooldownEnds[player] = Workspace:GetServerTimeNow() + TRIALS.Cooldown
		-- Flip back to "Ready" once the cooldown is over
		task.delay(TRIALS.Cooldown + 0.1, function()
			if player.Parent and not attempts[player] then
				publish(player)
			end
		end)
	end
	resultEvent:FireClient(player, { Passed = passed })
	Analytics.Event(player, "TrialFinished", 1, { if passed then "Passed" else "Failed" })
	if passed then
		ProgressionService.PromoteRank(player) -- the existing rank-up celebration
	end
	publish(player)
end

local function startTrial(player: Player)
	if not RateLimit.Allow(player, "StartTrial") then
		return { Ok = false, Error = "Slow down!" }
	end
	if not PlayerDataService.IsLoaded(player) then
		return { Ok = false, Error = "Still loading" }
	end
	if attempts[player] then
		return { Ok = false, Error = "Trial already running" }
	end
	local trial = getTrial(player)
	if not trial or not ProgressionService.IsRankUpReady(player) then
		return { Ok = false, Error = "Fill your XP bar first" }
	end
	if (cooldownEnds[player] or 0) > Workspace:GetServerTimeNow() then
		return { Ok = false, Error = "Wait for the cooldown" }
	end
	local trialType = TRIALS.Types[trial.Type]
	if not trialType then
		warn("[TrialService] Unknown trial type: " .. tostring(trial.Type))
		return { Ok = false, Error = "Something went wrong" }
	end

	nextAttemptId += 1
	attempts[player] = {
		Id = nextAttemptId,
		Trial = trial,
		Type = trialType,
		Progress = 0,
		ThrowsLeft = trial.Throws,
	}
	publish(player)
	return { Ok = true }
end

-- ThrowService calls this when a throw is requested; the id ties the throw to the attempt running then,
-- so a ball already rolling when a trial starts never counts toward it.
function TrialService.GetAttemptId(player: Player): number?
	local attempt = attempts[player]
	return attempt and attempt.Id
end

-- ThrowService calls this when the ball reaches the pins.
-- streakSaved = the Streak Saver trait kept the player's streak on this miss.
function TrialService.OnThrow(player: Player, attemptId: number?, tier: string, streakSaved: boolean)
	local attempt = attempts[player]
	if not attempt or attempt.Id ~= attemptId then
		return
	end
	local isStrike = tier == "Strike" or tier == "PerfectStrike"
	local counts = if attempt.Type.Counts == "Perfect" then tier == "PerfectStrike" else isStrike

	attempt.ThrowsLeft -= 1
	if counts then
		attempt.Progress += 1
	elseif attempt.Type.InARow and not (streakSaved and attempt.Type.Counts == "Strike") then
		attempt.Progress = 0 -- a miss breaks a "in a row" trial (unless Streak Saver kept the streak)
	end

	local needed = attempt.Trial.Goal - attempt.Progress
	if needed <= 0 then
		finish(player, true)
	elseif needed > attempt.ThrowsLeft then
		finish(player, false) -- can't be done any more with the throws left
	else
		publish(player)
	end
end

--------------------------------------------------------------------------------------------------
-- Future purchase hooks. NOT connected to anything: v1 sells nothing.
-- When purchases are added, call these from the purchase handler after a confirmed receipt.

-- "Skip Trial": gives the rank as if the trial was passed. Returns false if there is no trial to skip.
function TrialService.SkipTrial(player: Player): boolean
	if not getTrial(player) or not ProgressionService.IsRankUpReady(player) then
		return false
	end
	finish(player, true)
	return true
end

-- "Retry Now": ends the cooldown after a failed trial. Returns false if there is no cooldown.
function TrialService.RetryNow(player: Player): boolean
	if attempts[player] or (cooldownEnds[player] or 0) <= Workspace:GetServerTimeNow() then
		return false
	end
	cooldownEnds[player] = nil
	publish(player)
	return true
end
--------------------------------------------------------------------------------------------------

function TrialService:Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")

	local start = Instance.new("RemoteFunction")
	start.Name = "StartTrial"
	start.Parent = remotes

	resultEvent = Instance.new("RemoteEvent")
	resultEvent.Name = "TrialResult"
	resultEvent.Parent = remotes

	start.OnServerInvoke = startTrial

	PlayerDataService.OnLoaded(function(player)
		publish(player)
		-- The XP bar filling up or a new rank can change what the player sees
		player:GetAttributeChangedSignal("RankUpReady"):Connect(function()
			publish(player)
		end)
		player:GetAttributeChangedSignal("Rank"):Connect(function()
			publish(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		attempts[player] = nil
		cooldownEnds[player] = nil
	end)
end

return TrialService
