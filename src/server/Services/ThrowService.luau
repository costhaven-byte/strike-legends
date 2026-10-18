-- Times each player's hold on the charge bar, validates the release, works out the result and tells every client.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local LaneUtil = require(Shared.Modules.LaneUtil)
local Modifiers = require(Shared.Modules.Modifiers)
local Progression = require(Shared.Modules.Progression)
local ThrowRules = require(Shared.Modules.ThrowRules)
local Analytics = require(script.Parent.Analytics)
local BallService = require(script.Parent.BallService)
local GoldenPinService = require(script.Parent.GoldenPinService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressionService = require(script.Parent.ProgressionService)
local TrialService = require(script.Parent.TrialService)
local ThrowResolver = require(script.Parent.Parent.Modules.ThrowResolver)
local RewardResolver = require(script.Parent.Parent.Modules.RewardResolver)
local RateLimit = require(script.Parent.Parent.Modules.RateLimit)
local SessionLog = require(script.Parent.Parent.Modules.SessionLog)

local GOLDEN = Config.GoldenPin
local THROW = Config.Throw

-- A sliding gold zone counts as hit if the release was in it at any moment this many seconds back
-- (covers the time the release takes to reach the server)
local SWAY_WINDOW = 0.35

local ThrowService = {}

-- When each player started holding (server clock). A release only counts if a hold started first.
local holdStarts: { [Player]: number } = {}

local TIER_TEXT = {
	Gutter = "OVERCOOKED!", -- only a failed overcharge ends in the gutter
	Weak = "%d PINS",
	Good = "%d PINS",
	Nine = "SO CLOSE! 9",
	Strike = "STRIKE!",
	PerfectStrike = "PERFECT!",
}

local function setStatus(lane: Model, text: string)
	local board = lane:FindFirstChild("Scoreboard")
	local label = board and board:FindFirstChild("Status", true)
	if label then
		label.Text = text
	end
end

-- Every coin multiplier for this throw.
-- Future gamepasses and boosts get added here as new entries.
local function getCoinMultipliers(player: Player, ball, streak: number, modifier, goldenHit: boolean)
	return {
		Ball = ball.Multiplier,
		Rank = Progression.GetRank(ProgressionService.GetCurrentRankIndex(player)).Multiplier,
		Streak = Progression.GetStreakMultiplier(streak),
		Modifier = modifier and modifier.CoinMultiplier or 1,
		GoldenPin = if goldenHit then GOLDEN.CoinMultiplier else 1,
	}
end

-- Every XP multiplier for this player. Future boosts (like a 2x XP gamepass) get added here.
local function getXpMultipliers(streak: number): { [string]: number }
	return {
		Streak = Progression.GetStreakXpMultiplier(streak),
	}
end

local function isValidNumber(value: any): boolean
	return typeof(value) == "number" and value == value and math.abs(value) ~= math.huge
end

local function onHoldStart(player: Player)
	if RateLimit.Allow(player, "ThrowHold") then
		holdStarts[player] = os.clock()
	end
end

-- How long the hold really was. The server's own timing decides; the client's number (which has no
-- internet lag in it) is only used to smooth that out, within Config.Throw.HoldTolerance seconds.
local function measuredHold(player: Player, clientHold: number): number?
	local started = holdStarts[player]
	holdStarts[player] = nil
	if not started then
		return nil
	end
	local serverHold = os.clock() - started
	local hold = math.clamp(clientHold, serverHold - THROW.HoldTolerance, serverHold + THROW.HoldTolerance)
	return math.clamp(hold, 0, THROW.MaxHoldTime)
end

local function onThrowRequest(player: Player, clientHold: any)
	if not isValidNumber(clientHold) then
		return
	end
	local hold = measuredHold(player, clientHold)
	if not hold then
		return
	end
	local charge = ThrowRules.ChargeAt(hold, ProgressionService.GetCurrentRankIndex(player))

	-- No throws until the player's save has loaded, so rewards always have somewhere to go
	if not PlayerDataService.IsLoaded(player) then
		return
	end

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	-- Players can only throw on their own lane, while standing on it
	local lane = LaneUtil.GetOwnedLane(player.UserId)
	if not lane or not LaneUtil.IsInThrowZone(lane, root.Position) then
		return
	end

	-- One throw at a time per lane; ReadyAt is in server time so clients can read it too.
	local now = Workspace:GetServerTimeNow()
	if now < (lane:GetAttribute("ReadyAt") or 0) then
		return
	end
	if not RateLimit.Allow(player, "Throw") then
		return
	end

	local ball = BallService.GetEquipped(player)
	local modifier = Modifiers.Current()
	-- The gold sits where the lane says and shrinks with the streak (the client draws it the same way)
	local goldCenter = lane:GetAttribute("GoldCenter")
	local shownStreak = player:GetAttribute("Streak") or 0
	local perfect = ThrowRules.WasInSpot(charge, ball, modifier, now, SWAY_WINDOW, nil, goldCenter, shownStreak)
	local hook = ThrowRules.HookWidth(ball)
	local hooked = not perfect
		and hook > 0
		and ThrowRules.WasInSpot(charge, ball, modifier, now, SWAY_WINDOW, hook, goldCenter, shownStreak)
	local overcharged = ThrowRules.InOvercharge(charge)
	-- The next throw's gold is somewhere else on the arc
	lane:SetAttribute("GoldCenter", ThrowRules.NextGoldCenter(goldCenter))
	local forward = lane.BallStart.CFrame.LookVector
	local distance = (lane.PinSpot.Position - lane.BallStart.Position):Dot(forward)
	local result = ThrowResolver.Resolve(charge, perfect, hooked, overcharged, ball, distance)
	local isStrike = result.Tier == "Strike" or result.Tier == "PerfectStrike"
	local streak, saved = ProgressionService.NextStreak(player, isStrike, Balls.TraitValue(ball, "StreakSaver"))
	local goldenPin = GoldenPinService.Get(lane)
	local goldenHit = goldenPin > 0 and table.find(result.Pins, goldenPin) ~= nil
	local multipliers = getCoinMultipliers(player, ball, streak, modifier, goldenHit)
	if result.Overcharge == "Blast" then
		multipliers.Overcharge = THROW.Overcharge.CoinMultiplier
	end
	local reward = RewardResolver.Calculate(
		result.Count,
		result.Tier,
		multipliers,
		getXpMultipliers(streak),
		Balls.TraitValue(ball, "GemHunter")
	)

	-- Surprise bonuses: Golden Pin gems and free crate, and the Bonus Gems lane modifier
	local golden = { Pin = goldenPin, Hit = goldenHit, Gems = 0, Crate = false }
	if goldenHit then
		if Config.Gems.Enabled and math.random() < GOLDEN.GemChance then
			golden.Gems = GOLDEN.GemAmount
		end
		golden.Crate = math.random() < GOLDEN.CrateChance
	end
	local modifierGems = 0
	if
		Config.Gems.Enabled
		and isStrike
		and modifier
		and modifier.StrikeGemChance
		and math.random() < modifier.StrikeGemChance
	then
		modifierGems = modifier.StrikeGemAmount or 1
	end
	reward.Gems += golden.Gems + modifierGems

	local trialAttempt = TrialService.GetAttemptId(player)

	-- Every trait that kicked in on this throw, so clients can play its effect
	local traits = table.clone(result.Traits)
	if saved then
		table.insert(traits, "StreakSaver")
	end
	if reward.GemHunter then
		table.insert(traits, "GemHunter")
	end
	-- The arm swings down before the ball leaves the hand
	task.wait(THROW.ReleaseDelay)
	if not player.Parent then
		return
	end
	now += THROW.ReleaseDelay

	-- Strikes wait for their slow motion too (the client resets the pins after the same time)
	local resetDelay = Config.Lane.PinResetDelay
		+ (if isStrike then THROW.SlowMotionStartsAfter + THROW.SlowMotionLength else 0)
	lane:SetAttribute("ReadyAt", now + result.RollTime + resetDelay + THROW.CooldownBuffer)

	ThrowService.Remotes.ThrowResult:FireAllClients({
		Lane = lane,
		UserId = player.UserId,
		BallId = ball.Id,
		Charge = charge,
		Power = result.Strength, -- how hard it was thrown (above 1 for a PERFECT)
		Perfect = result.Perfect,
		ResetDelay = resetDelay,
		Count = result.Count,
		Tier = result.Tier,
		Pins = result.Pins,
		HitX = result.HitX,
		Gutter = result.Gutter,
		RollTime = result.RollTime,
		CurveFromX = result.CurveFromX,
		Traits = traits,
		Reward = reward,
		Streak = streak,
		Golden = golden,
		ModifierGems = modifierGems,
		Overcharge = result.Overcharge,
	})

	SessionLog.Throw(player, ThrowRules.Level(ball))
	BallService.HideHeldBall(player, result.RollTime + resetDelay)
	setStatus(lane, "ROLLING...")
	task.delay(result.RollTime, function()
		-- Paid when the ball reaches the pins, so the HUD ticks up in sync with the hit
		if player.Parent then
			local firstCoins = reward.Coins > 0 and (PlayerDataService.Get(player, "LifetimePins") or 0) == 0
			PlayerDataService.Add(player, "Coins", reward.Coins)
			if reward.Gems > 0 then
				PlayerDataService.Add(player, "Gems", reward.Gems)
			end
			ProgressionService.ShowStreak(player, streak)
			ProgressionService.AddXP(player, reward.XP)
			LeaderboardService.RecordThrow(player, result.Count, reward.Coins)
			TrialService.OnThrow(player, trialAttempt, result.Tier, saved)
			if isStrike then
				BallService.AddCrateStrike(player)
			end
			if golden.Crate then
				BallService.GiveFreeCrate(player)
			end

			Analytics.Currency(player, "Coins", reward.Coins, "Gameplay", "Throw")
			Analytics.Currency(player, "Gems", reward.Gems, "Gameplay", "Throw")
			Analytics.Event(player, "Throw", result.Count, { result.Tier, ball.Id })
			Analytics.Step(player, "First Throw")
			if firstCoins then
				Analytics.Event(player, "FirstCoins", reward.Coins)
			end
			if isStrike then
				Analytics.Step(player, "First Strike")
			end
			if streak >= 2 then
				Analytics.Step(player, "Double Strike")
			end
		end
		setStatus(lane, if result.Count == 1 then "1 PIN" else TIER_TEXT[result.Tier]:format(result.Count))
	end)
	-- Roll the next rack's Golden Pin as the pins reset
	task.delay(result.RollTime + resetDelay, GoldenPinService.Roll, lane)
end

function ThrowService:Start()
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"

	local request = Instance.new("RemoteEvent")
	request.Name = "ThrowRequest"
	request.Parent = folder

	local resultEvent = Instance.new("RemoteEvent")
	resultEvent.Name = "ThrowResult"
	resultEvent.Parent = folder

	folder.Parent = ReplicatedStorage
	local hold = Instance.new("RemoteEvent")
	hold.Name = "ThrowHold"
	hold.Parent = folder

	self.Remotes = { ThrowRequest = request, ThrowResult = resultEvent, ThrowHold = hold }

	for _, lane in LaneUtil.GetLanes() do
		lane:SetAttribute("ReadyAt", 0)
		lane:SetAttribute("GoldCenter", ThrowRules.NextGoldCenter())
		setStatus(lane, "READY")
	end

	hold.OnServerEvent:Connect(onHoldStart)
	request.OnServerEvent:Connect(onThrowRequest)
	Players.PlayerRemoving:Connect(function(player)
		holdStarts[player] = nil
	end)
end

return ThrowService
