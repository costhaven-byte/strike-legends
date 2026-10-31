-- Times each player's hold on the charge bar, validates the release, works out the result and tells every client.
-- Auto Bowl (Config.AutoBowl): the server throws for players who switched it on, slower than by hand and never a
-- PERFECT. Free and slow after the first rebirth (batch D6); the AUTO BOWL pass is faster and always strikes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local Currency = require(Shared.Modules.Currency)
local LaneUtil = require(Shared.Modules.LaneUtil)
local Modifiers = require(Shared.Modules.Modifiers)
local Store = require(Shared.Modules.Store)
local PowerLevels = require(Shared.Modules.PowerLevels)
local ThrowRules = require(Shared.Modules.ThrowRules)
local Analytics = require(script.Parent.Analytics)
local AwayService = require(script.Parent.AwayService)
local BallService = require(script.Parent.BallService)
local BossService = require(script.Parent.BossService)
local CoreLoopService = require(script.Parent.CoreLoopService)
local FeverService = require(script.Parent.FeverService)
local GoldenPinService = require(script.Parent.GoldenPinService)
local LaneEventService = require(script.Parent.LaneEventService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local MilestoneService = require(script.Parent.MilestoneService)
local MultiplierService = require(script.Parent.MultiplierService)
local OnboardingService = require(script.Parent.OnboardingService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressionService = require(script.Parent.ProgressionService)
local TrialService = require(script.Parent.TrialService)
local ThrowResolver = require(script.Parent.Parent.Modules.ThrowResolver)
local RewardResolver = require(script.Parent.Parent.Modules.RewardResolver)
local RateLimit = require(script.Parent.Parent.Modules.RateLimit)
local SessionLog = require(script.Parent.Parent.Modules.SessionLog)
local StoreService = require(script.Parent.StoreService)

local FEVER = Config.Fever
local GOLDEN = Config.GoldenPin
local EVENTS = Config.LaneEvents
local THROW = Config.Throw
local CORE = Config.CoreLoop

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
-- (Polish P5: the list lives in MultiplierService.Xp, so the Profile panel shows the same numbers that pay)
local function getXpMultipliers(player: Player, streak: number, zone: number): { [string]: number }
	return MultiplierService.Xp(player, streak, zone)
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
	if CORE.Enabled then
		return -- (the Addendum 4 core loop has its own throw, coreThrow; Auto Bowl is off with it)
	end
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
	-- FEVER MODE (Config.Fever): hand throws come faster (quicker reset below, looser rate limit) and pay more.
	-- Auto Bowl throws get neither.
	local fever = not auto and FeverService.Active(player)
	if not RateLimit.Allow(player, "Throw", if fever then FEVER.ThrowRateLimit else nil) then
		return
	end

	-- LANE EVENTS (Config.LaneEvents): the event on this rack, used up by this throw (auto throws never win one)
	local event, eventPin = LaneEventService.Take(lane, player, auto)
	if auto then
		event = nil
	end

	local ball = BallService.GetEquipped(player)
	local powerLevel = ThrowRules.Level(PlayerDataService.Get(player, "PowerLevel"))
	local level = PowerLevels.Get(powerLevel)
	-- The throw animation and ball speed follow the CURRENT rank level (batch D1; a rebirth resets it)
	local style = ThrowRules.Style(PlayerDataService.Get(player, "RankLevel"))
	local modifier = Modifiers.Current()
	-- The gold sits where the lane says and shrinks with the streak (the client draws it the same way)
	local goldCenter = lane:GetAttribute("GoldCenter")
	local shownStreak = player:GetAttribute("Streak") or 0
	-- A brand new player's first throw is an assisted PERFECT (Config.Onboarding; the client shows the whole arc gold)
	-- (Studio only: the Day 1 video intro's throw is assisted too, LaneService sets IntroAssist)
	local assisted = not auto and (OnboardingService.IsAssisted(player) or player:GetAttribute("IntroAssist") == true)
	if assisted then
		OnboardingService.UseAssist(player)
		player:SetAttribute("IntroAssist", nil)
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
	local result =
		ThrowResolver.Resolve(charge, perfect, hooked, overcharged, ball, distance, level.Power, autoStrike, style.Speed)
	-- 7-10 SPLIT: only pins 7 and 10 stand. A PERFECT clears both, other throws have a small chance.
	local split = event == "Split"
	if split then
		result.Pins = LaneEventService.SplitPins(result.Perfect or autoStrike, result.Gutter)
		result.Count = #result.Pins
		if result.Count == #EVENTS.Split.Pins then
			result.Tier = if result.Perfect then "PerfectStrike" else "Strike"
		elseif not result.Gutter then
			result.Tier = "Weak"
		end
	end
	local isStrike = result.Tier == "Strike" or result.Tier == "PerfectStrike"
	-- An overcooked throw always ends the streak: Streak Saver never covers the greedy red
	local saverCooldown = if result.Overcharge == "Wasted" then 0 else Balls.TraitValue(ball, "StreakSaver")
	local streak, saved = shownStreak, false
	-- (the split throw never breaks or adds to the streak)
	if not auto and not split then
		streak, saved = ProgressionService.NextStreak(player, isStrike, saverCooldown)
	end
	local goldenPin = GoldenPinService.Get(lane)
	local goldenHit = goldenPin > 0 and table.find(result.Pins, goldenPin) ~= nil
	local zone = LaneUtil.ZoneOf(lane)
	local multipliers = MultiplierService.Coins(player, ball, level, streak, modifier, goldenHit, zone)
	if result.Overcharge == "Blast" then
		multipliers.Overcharge = THROW.Overcharge.CoinMultiplier
	end
	multipliers.Fever = if fever then FEVER.CoinMultiplier else 1
	-- GOLDEN RACK: a strike pays x StrikeMultiplier (it replaces fever's x3, never stacks with it)
	local eventWon = false
	if event == "GoldenRack" and isStrike then
		eventWon = true
		multipliers.Fever = 1
		multipliers.LaneEvent = EVENTS.GoldenRack.StrikeMultiplier
	end
	local xpMultipliers = getXpMultipliers(player, streak, zone)
	local reward = RewardResolver.Calculate(
		result.Count,
		result.Tier,
		multipliers,
		xpMultipliers,
		Balls.TraitValue(ball, "GemHunter")
	)
	local eventGems = 0
	if split and isStrike then
		-- Both down: StrikeValues x what a PERFECT strike pays this player right now, plus gems
		eventWon = true
		local perfectPay = RewardResolver.Calculate(Config.Lane.PinCount, "PerfectStrike", multipliers, xpMultipliers)
		reward.Coins = Currency.Round(Currency.Scale(perfectPay.Coins, EVENTS.Split.StrikeValues))
		eventGems = LaneEventService.Gems(EVENTS.Split.Gems, zone)
	elseif event == "GemPin" and table.find(result.Pins, eventPin) then
		eventWon = true
		eventGems = LaneEventService.Gems(EVENTS.GemPin.Gems, zone)
	end
	if not Config.Gems.Enabled then
		eventGems = 0
	end

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
	reward.Gems += golden.Gems + modifierGems + eventGems

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
	local resetDelay = Config.Lane.PinResetDelay * (if fever then FEVER.ResetScale else 1)
		+ (if isStrike then THROW.SlowMotionStartsAfter + THROW.SlowMotionLength else 0)
	local buffer = if fever then FEVER.CooldownBuffer else THROW.CooldownBuffer
	lane:SetAttribute("ReadyAt", now + result.RollTime + resetDelay + buffer)

	ThrowService.Remotes.ThrowResult:FireAllClients({
		Lane = lane,
		UserId = player.UserId,
		BallId = ball.Id,
		PowerLevel = powerLevel, -- how the ball looks, sounds and hits (Config.Throw.Levels)
		Pose = style.Pose, -- the thrower's throw animation level (rank level, Config.Throw.RankStyle)
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
		Fever = fever, -- thrown during FEVER MODE: the ball burns (LaneVisuals)
		-- the lane event this throw was at (EventController shows the result)
		LaneEvent = if event then { Id = event, Pin = eventPin, Won = eventWon, Gems = eventGems } else nil,
	})

	SessionLog.Throw(player, powerLevel, result.Perfect, assisted)
	BallService.HideHeldBall(player, result.RollTime + resetDelay)
	setStatus(lane, "ROLLING...")
	task.delay(result.RollTime, function()
		-- Paid when the ball reaches the pins, so the HUD ticks up in sync with the hit
		if player.Parent then
			local firstCoins = reward.Coins > 0 and (PlayerDataService.Get(player, "LifetimePins") or 0) == 0
			PlayerDataService.Add(player, "Coins", reward.Coins)
			-- (fever's x3 is taken out too, so 15 s of fever don't raise coins per minute or away coins)
			AwayService.OnCoins(player, reward.Coins, MultiplierService.Steady(multipliers) * multipliers.Fever)
			if reward.Gems > 0 then
				PlayerDataService.Add(player, "Gems", reward.Gems)
			end
			ProgressionService.ShowStreak(player, streak)
			if isStrike and not auto and not split then
				FeverService.OnStrike(player, streak)
			end
			ProgressionService.AddXP(player, reward.XP)
			LeaderboardService.RecordThrow(player, result.Count, reward.Coins)
			-- Lifetime counters for the Profile panel (Polish P5)
			PlayerDataService.Add(player, "TotalThrows", 1)
			if isStrike then
				PlayerDataService.Add(player, "TotalStrikes", 1)
			end
			if result.Perfect then
				PlayerDataService.Add(player, "TotalPerfects", 1)
			end
			if not auto then
				TrialService.OnThrow(player, trialAttempt, result.Tier, saved)
				StoreService.OnThrow(player, isStrike)
			end
			MilestoneService.OnThrow(player, LaneUtil.ZoneOf(lane), isStrike and not auto and not split, saved)
			BallService.AddCrateThrow(player)
			if goldenHit then
				SessionLog.Moment(player, "Golden Pin hit")
			end
			if event then
				SessionLog.Moment(player, "Lane event " .. event .. (if eventWon then " won" else " missed"))
				Analytics.Event(player, "LaneEvent", if eventWon then 1 else 0, { event })
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
	-- The next rack as the pins reset: maybe a lane event, else maybe a Golden Pin
	task.delay(result.RollTime + resetDelay, function()
		LaneEventService.OnReset(lane, player)
		GoldenPinService.Roll(lane)
	end)
end

-- ===== Addendum 4 core loop (Config.CoreLoop): hold the button to keep throwing =====
-- No timing, no PERFECT: every throw knocks about Config.CoreLoop.PinsAverage of the 40 pins, each pin pays coins into
-- the bag (a full clear pays double), the lane is ready again after the player's cooldown. The client sends one
-- CoreThrow per throw while the button is held; the server checks the lane, the cooldown and the rate.
local CORE_LEVEL = { Value = 1 } -- (Power Levels play no part in core coins)

local function coreThrow(player: Player)
	if not PlayerDataService.IsLoaded(player) then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local lane = LaneUtil.GetOwnedLane(player.UserId)
	if not root or not lane or not LaneUtil.IsInThrowZone(lane, root.Position) then
		return
	end
	local now = Workspace:GetServerTimeNow()
	-- (a little slack, so a throw sent on the dot of the cooldown isn't lost to timing noise)
	if now < (lane:GetAttribute("ReadyAt") or 0) - 0.05 then
		return
	end
	if not RateLimit.Allow(player, "CoreThrow", CORE.ThrowRate) then
		return
	end
	local cooldown = CoreLoopService.Cooldown(player)
	lane:SetAttribute("ReadyAt", now + cooldown)

	local ball = BallService.GetEquipped(player)
	local result = ThrowResolver.ResolveCore(CORE.PinsAverage, CORE.PinsSpread)
	local clear = result.Tier == "Strike"
	local all = MultiplierService.Coins(player, ball, CORE_LEVEL, 0, nil, false, LaneUtil.ZoneOf(lane))
	local multiplier = 1
	for _, name in CORE.Multipliers do
		multiplier *= all[name] or 1
	end
	local coins = Currency.Round(
		Currency.Scale(result.Count * CORE.PinValue * (if clear then CORE.FullClearMultiplier else 1), multiplier)
	)
	-- Coins land in the bag when the ball reaches the pins; a full bag takes nothing (pins still fall)
	local paid = CoreLoopService.AddToBag(player, coins, result.RollTime)

	ThrowService.Remotes.ThrowResult:FireAllClients({
		Core = true,
		Lane = lane,
		UserId = player.UserId,
		BallId = ball.Id,
		PowerLevel = ThrowRules.Level(PlayerDataService.Get(player, "PowerLevel")), -- how the ball looks
		Pose = ThrowRules.Style(PlayerDataService.Get(player, "RankLevel")).Pose,
		Charge = 1,
		Power = 1,
		Perfect = false,
		ResetDelay = CORE.RefillDelay,
		Count = result.Count,
		Tier = result.Tier, -- "Strike" = every pin down
		Pins = result.Pins,
		HitX = 0,
		Gutter = false,
		RollTime = result.RollTime,
		Traits = {},
		Coins = coins, -- what the pins were worth...
		Paid = paid, -- ...and what fitted in the bag
		BagFull = paid < coins,
		Cooldown = cooldown,
	})

	CoreLoopService.OnThrow(player)
	BallService.HideHeldBall(player, result.RollTime)
	task.delay(result.RollTime, function()
		if player.Parent then
			LeaderboardService.RecordThrow(player, result.Count, 0)
			PlayerDataService.Add(player, "TotalThrows", 1)
			if clear then
				PlayerDataService.Add(player, "TotalStrikes", 1)
			end
			Analytics.Event(player, "Throw", result.Count, { if clear then "Clear" else "Pins", ball.Id })
		end
	end)
end

local function onThrowRequest(player: Player, clientHold: any)
	if CORE.Enabled and not BossService.InFight(player) then
		return -- the core loop throws through CoreThrow only
	end
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
-- seconds with the pass (FreeInterval without) while standing on their lane. throwBall still checks the lane, the
-- cooldown and the rate limit.
local autoNext: { [Player]: number } = {}
local function startAutoBowl(remotes: Folder)
	local AUTO = Config.AutoBowl
	-- The free slow auto: Config.AutoBowl.Enabled (for everyone) or enough rebirths
	local function freeAuto(player: Player): boolean
		local need = AUTO.FreeAfterRebirths or 0
		return AUTO.Enabled or (need > 0 and (PlayerDataService.Get(player, "Rebirths") or 0) >= need)
	end
	local toggle = Instance.new("RemoteEvent")
	toggle.Name = "SetAutoBowl"
	toggle.OnServerEvent:Connect(function(player, on)
		local allowed = freeAuto(player) or Store.Owns(player, "AutoBowl")
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
						autoNext[player] = now
							+ (if Store.Owns(player, "AutoBowl") then AUTO.Interval else AUTO.FreeInterval)
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

	-- Addendum 4 core loop: one throw per message while the button is held (Config.CoreLoop)
	local core = Instance.new("RemoteEvent")
	core.Name = "CoreThrow"
	core.Parent = folder
	if CORE.Enabled then
		core.OnServerEvent:Connect(coreThrow)
	end

	self.Remotes = { ThrowRequest = request, ThrowResult = resultEvent, ThrowHold = hold, CoreThrow = core }

	for _, lane in LaneUtil.GetLanes() do
		lane:SetAttribute("ReadyAt", 0)
		lane:SetAttribute("GoldCenter", ThrowRules.NextGoldCenter())
		setStatus(lane, "READY")
	end

	hold.OnServerEvent:Connect(onHoldStart)
	request.OnServerEvent:Connect(onThrowRequest)
	startAutoBowl(folder) -- (the free slow auto after rebirth 1 needs it even with the store off)
	Players.PlayerRemoving:Connect(function(player)
		holdStarts[player] = nil
		autoNext[player] = nil
	end)
end

return ThrowService
