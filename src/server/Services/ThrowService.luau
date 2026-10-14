-- Receives aim/power from players, validates it, works out the result and tells every client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local LaneUtil = require(Shared.Modules.LaneUtil)
local Modifiers = require(Shared.Modules.Modifiers)
local Progression = require(Shared.Modules.Progression)
local Analytics = require(script.Parent.Analytics)
local BallService = require(script.Parent.BallService)
local GoldenPinService = require(script.Parent.GoldenPinService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressionService = require(script.Parent.ProgressionService)
local TrialService = require(script.Parent.TrialService)
local ThrowResolver = require(script.Parent.Parent.Modules.ThrowResolver)
local RewardResolver = require(script.Parent.Parent.Modules.RewardResolver)

local GOLDEN = Config.GoldenPin

local ThrowService = {}

local TIER_TEXT = {
	Gutter = "GUTTER",
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

local function onThrowRequest(player: Player, aim: any, power: any)
	if not isValidNumber(aim) or not isValidNumber(power) then
		return
	end
	aim = math.clamp(aim, -1, 1)
	power = math.clamp(power, 0, 1)

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

	local ball = BallService.GetEquipped(player)
	local modifier = Modifiers.Current()
	local result = ThrowResolver.Resolve(aim, power, ball, {
		RackOffset = function(rollTime: number)
			return Modifiers.RackOffset(modifier, now + rollTime)
		end,
		AimBonus = modifier and modifier.AimBonus,
	})
	local isStrike = result.Tier == "Strike" or result.Tier == "PerfectStrike"
	local streak, saved = ProgressionService.NextStreak(player, isStrike, Balls.TraitValue(ball, "StreakSaver"))
	local goldenPin = GoldenPinService.Get(lane)
	local goldenHit = goldenPin > 0 and table.find(result.Pins, goldenPin) ~= nil
	local reward = RewardResolver.Calculate(
		result.Count,
		result.Tier,
		getCoinMultipliers(player, ball, streak, modifier, goldenHit),
		getXpMultipliers(streak),
		Balls.TraitValue(ball, "GemHunter")
	)

	-- Surprise bonuses: Golden Pin gems and free crate, and the Bonus Gems lane modifier
	local golden = { Pin = goldenPin, Hit = goldenHit, Gems = 0, Crate = false }
	if goldenHit then
		if math.random() < GOLDEN.GemChance then
			golden.Gems = GOLDEN.GemAmount
		end
		golden.Crate = math.random() < GOLDEN.CrateChance
	end
	local modifierGems = 0
	if isStrike and modifier and modifier.StrikeGemChance and math.random() < modifier.StrikeGemChance then
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
	lane:SetAttribute("ReadyAt", now + result.RollTime + Config.Lane.PinResetDelay + Config.Throw.CooldownBuffer)

	ThrowService.Remotes.ThrowResult:FireAllClients({
		Lane = lane,
		UserId = player.UserId,
		BallId = ball.Id,
		Aim = aim,
		Power = power,
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
	})

	BallService.HideHeldBall(player, result.RollTime + Config.Lane.PinResetDelay)
	setStatus(lane, "ROLLING...")
	task.delay(result.RollTime, function()
		-- Paid when the ball reaches the pins, so the HUD ticks up in sync with the hit
		if player.Parent then
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
	task.delay(result.RollTime + Config.Lane.PinResetDelay, GoldenPinService.Roll, lane)
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
	self.Remotes = { ThrowRequest = request, ThrowResult = resultEvent }

	for _, lane in LaneUtil.GetLanes() do
		lane:SetAttribute("ReadyAt", 0)
		setStatus(lane, "READY")
	end

	request.OnServerEvent:Connect(onThrowRequest)
end

return ThrowService
