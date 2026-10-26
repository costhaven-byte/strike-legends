-- Times each player's hold on the charge bar, validates the release, works out the result and tells every client.
-- Auto Bowl (Config.AutoBowl, OFF until monetization): the server throws for players who switched it on, slower
-- than by hand and never a PERFECT.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local LaneUtil = require(Shared.Modules.LaneUtil)
local Modifiers = require(Shared.Modules.Modifiers)
local Store = require(Shared.Modules.Store)
local PowerLevels = require(Shared.Modules.PowerLevels)
local Progression = require(Shared.Modules.Progression)
local Rebirth = require(Shared.Modules.Rebirth)
local ThrowRules = require(Shared.Modules.ThrowRules)
local Zones = require(Shared.Modules.Zones)
local Analytics = require(script.Parent.Analytics)
local AwayService = require(script.Parent.AwayService)
local BallService = require(script.Parent.BallService)
local BossService = require(script.Parent.BossService)
local GoldenPinService = require(script.Parent.GoldenPinService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local MascotService = require(script.Parent.MascotService)
local MilestoneService = require(script.Parent.MilestoneService)
local MultiplierService = require(script.Parent.MultiplierService)
local OnboardingService = require(script.Parent.OnboardingService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PotionService = require(script.Parent.PotionService)
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

-- Every XP multiplier for this player. Future boosts (like a 2x XP gamepass) get added here.
-- Pets boost XP by the same amount they boost coins (owner 2026-10-22).
local function getXpMultipliers(player: Player, streak: number, zone: number): { [string]: number }
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

-- One throw at `charge` (0 to 1 of the bar). auto = an Auto Bowl throw: never a PERFECT, hook or overcharge.
-- With the AUTO BOWL game pass every auto throw is a plain strike (no PERFECT x2); auto throws never change the streak
-- and never count for rank trials or the 3-strike challenge.
local function throwBall(player: Player, charge: number, auto: boolean)
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
	local powerLevel = ThrowRules.Level(PlayerDataService.Get(player, "PowerLevel"))
	local level = PowerLevels.Get(powerLevel)
	local modifier = Modifiers.Current()
	-- The gold sits where the lane says and shrinks with the streak (the client draws it the same way)
	local goldCenter = lane:GetAttribute("GoldCenter")
	local shownStreak = player:GetAttribute("Streak") or 0
	-- A brand new player's first throw is an assisted PERFECT (Config.Onboarding; the client shows the whole arc gold)
	local assisted = not auto and OnboardingService.IsAssisted(player)
	if assisted then
		OnboardingService.UseAssist(player)
	end
	local perfect = assisted
		or (not auto and ThrowRules.WasInSpot(charge, ball, modifier, now, SWAY_WINDOW, nil, goldCenter, shownStreak))
	local hooked = not perfect
		and not auto
		and Balls.TraitValue(ball, "Curve") > 0
		and ThrowRules.WasInSpot(charge, ball, modifier, now, SWAY_WINDOW, true, goldCenter, shownStreak)
	local overcharged = not assisted and not auto and ThrowRules.InOvercharge(charge)
	-- The next throw's gold is somewhere else on the arc
	lane:SetAttribute("GoldCenter", ThrowRules.NextGoldCenter(goldCenter))
	local forward = lane.BallStart.CFrame.LookVector
	local distance = (lane.PinSpot.Position - lane.BallStart.Position):Dot(forward)
	local autoStrike = auto and Store.Owns(player, "AutoBowl")
	local result = ThrowResolver.Resolve(charge, perfect, hooked, overcharged, ball, distance, level.Power, autoStrike)
	local isStrike = result.Tier == "Strike" or result.Tier == "PerfectStrike"
	-- An overcooked throw always ends the streak: Streak Saver never covers the greedy red
	local saverCooldown = if result.Overcharge == "Wasted" then 0 else Balls.TraitValue(ball, "StreakSaver")
	local streak, saved = shownStreak, false
	if not auto then
		streak, saved = ProgressionService.NextStreak(player, isStrike, saverCooldown)
	end
	local goldenPin = GoldenPinService.Get(lane)
	local goldenHit = goldenPin > 0 and table.find(result.Pins, goldenPin) ~= nil
	local zone = LaneUtil.ZoneOf(lane)
	local multipliers = MultiplierService.Coins(player, ball, level, streak, modifier, goldenHit, zone)
	if result.Overcharge == "Blast" then
		multipliers.Overcharge = THROW.Overcharge.CoinMultiplier
	end
	local reward = RewardResolver.Calculate(
		result.Count,
		result.Tier,
		multipliers,
		getXpMultipliers(player, streak, zone),
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
		PowerLevel = powerLevel, -- how the ball looks, sounds and hits (Config.Throw.Levels)
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

	SessionLog.Throw(player, powerLevel, result.Perfect, assisted)
	BallService.HideHeldBall(player, result.RollTime + resetDelay)
	setStatus(lane, "ROLLING...")
	task.delay(result.RollTime, function()
		-- Paid when the ball reaches the pins, so the HUD ticks up in sync with the hit
		if player.Parent then
			local firstCoins = reward.Coins > 0 and (PlayerDataService.Get(player, "LifetimePins") or 0) == 0
			PlayerDataService.Add(player, "Coins", reward.Coins)
			AwayService.OnCoins(player, reward.Coins)
			if reward.Gems > 0 then
				PlayerDataService.Add(player, "Gems", reward.Gems)
			end
			ProgressionService.ShowStreak(player, streak)
			ProgressionService.AddXP(player, reward.XP)
			LeaderboardService.RecordThrow(player, result.Count, reward.Coins)
			if not auto then
				TrialService.OnThrow(player, trialAttempt, result.Tier, saved)
			end
			MilestoneService.OnThrow(player, LaneUtil.ZoneOf(lane), isStrike and not auto, saved)
			BallService.AddCrateThrow(player)
			if goldenHit then
				SessionLog.Moment(player, "Golden Pin hit")
			end
			if golden.Crate then
				BallService.GiveFreeCrate(player)
			end
			OnboardingService.OnThrow(player, resetDelay)

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

local function onThrowRequest(player: Player, clientHold: any)
	if not isValidNumber(clientHold) then
		return
	end
	local hold = measuredHold(player, clientHold)
	if not hold then
		return
	end
	-- In the Pin Titan fight the same throw goes at the Titan instead of down a lane
	if BossService.InFight(player) then
		BossService.Throw(player, ThrowRules.ChargeAt(hold, ProgressionService.GetCurrentRankIndex(player)))
		return
	end
	throwBall(player, ThrowRules.ChargeAt(hold, ProgressionService.GetCurrentRankIndex(player)), false)
end

-- Auto Bowl: players who switched it on (Player attribute AutoBowl) get a throw every Config.AutoBowl.Interval
-- seconds while standing on their lane. throwBall still checks the lane, the cooldown and the rate limit.
local autoNext: { [Player]: number } = {}
local function startAutoBowl(remotes: Folder)
	local AUTO = Config.AutoBowl
	local toggle = Instance.new("RemoteEvent")
	toggle.Name = "SetAutoBowl"
	toggle.OnServerEvent:Connect(function(player, on)
		-- Free for everyone only while Config.AutoBowl.Enabled; otherwise it needs the AUTO BOWL game pass
		local allowed = AUTO.Enabled or Store.Owns(player, "AutoBowl")
		player:SetAttribute("AutoBowl", on == true and allowed)
	end)
	toggle.Parent = remotes
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				if player:GetAttribute("AutoBowl") and now >= (autoNext[player] or 0) then
					local lane = LaneUtil.GetOwnedLane(player.UserId)
					local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
					local ready = lane
						and root
						and LaneUtil.IsInThrowZone(lane, root.Position)
						and Workspace:GetServerTimeNow() >= (lane:GetAttribute("ReadyAt") or 0)
					if ready then
						autoNext[player] = now + AUTO.Interval
						task.spawn(
							throwBall,
							player,
							AUTO.ChargeMin + math.random() * (AUTO.ChargeMax - AUTO.ChargeMin),
							true
						)
					end
				end
			end
		end
	end)
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
	if Config.AutoBowl.Enabled or Store.Active() then
		startAutoBowl(folder)
	end
	Players.PlayerRemoving:Connect(function(player)
		holdStarts[player] = nil
		autoNext[player] = nil
	end)
end

return ThrowService
