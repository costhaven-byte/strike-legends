-- One simple line per play session: when the player joined and left, throws, PERFECT throws, crates opened and
-- the highest throw level reached. Saved with the player (the newest Config.SessionLog.Keep sessions)
-- and printed in the Output window when they leave. Numbers update live, so a crash still keeps them.
-- A brand new player's first session also gets a timeline of every reward moment in the first
-- Config.SessionLog.First5Seconds seconds (First5), printed in Output when that time is up.
-- SessionLog.Report(player) gives both as text (Studio: the TEST: REPORT button prints it).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Analytics = require(script.Parent.Parent.Services.Analytics)
local PlayerDataService = require(script.Parent.Parent.Services.PlayerDataService)

local SETTINGS = Config.SessionLog

local SessionLog = {}

type Moment = { T: number, What: string }
type Entry = {
	Join: number,
	Leave: number,
	Throws: number,
	Perfects: number?, -- PERFECT throws, not counting the assisted first throw (older entries don't have it)
	Assisted: number?, -- assisted throws (the onboarding first throw)
	Crates: number,
	Level: number,
	First5: { Moment }?, -- only in a new player's first session
	-- Addendum 4 core loop instrumentation (seconds into this session; nil = didn't happen this session)
	Sells: number?,
	FirstThrowAt: number?, -- the player's first throw ever
	TenthThrowAt: number?, -- the player's 10th throw ever
	FirstSellAt: number?, -- the player's first sell ever
	Balls: { string }?, -- "Galaxy@312" for every ball bought this session (with the session second)
	LastActionAt: number?, -- the last throw or sell
	LastAction: string?,
}

local current: { [Player]: Entry } = {}
local started: { [Player]: number } = {} -- os.clock() at join

local function stamp(time: number): string
	return os.date("%Y-%m-%d %H:%M", time) :: string
end

local function clock(seconds: number): string
	seconds = math.floor(seconds)
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

-- PERFECT throws as a share of the throws that weren't assisted (nil before any)
function SessionLog.PerfectRate(entry: Entry): number?
	local throws = entry.Throws - (entry.Assisted or 0)
	return if throws > 0 then (entry.Perfects or 0) / throws else nil
end

-- Text version of one session, for the Output window
function SessionLog.Describe(entry: Entry): string
	local leave = if entry.Leave > 0 then entry.Leave else os.time()
	local rate = SessionLog.PerfectRate(entry)
	local core = ""
	if Config.CoreLoop.Enabled then
		local function at(seconds: number?): string
			return if seconds then clock(seconds) else "-"
		end
		core = (", %d sells, first throw %s, 10th throw %s, first sell %s, balls bought [%s], last action %s at %s"):format(
			entry.Sells or 0,
			at(entry.FirstThrowAt),
			at(entry.TenthThrowAt),
			at(entry.FirstSellAt),
			table.concat(entry.Balls or {}, ", "),
			entry.LastAction or "-",
			at(entry.LastActionAt)
		)
	end
	return ("joined %s, left %s (%d min), %d throws, %d PERFECT (%s), %d crates, Power Level %d" .. core):format(
		stamp(entry.Join),
		if entry.Leave > 0 then stamp(entry.Leave) else "still playing",
		math.floor((leave - entry.Join) / 60 + 0.5),
		entry.Throws,
		entry.Perfects or 0,
		if rate then ("%d%%"):format(math.floor(rate * 100 + 0.5)) else "-",
		entry.Crates,
		entry.Level
	)
end

-- The first-5-minutes timeline as lines of text
function SessionLog.DescribeFirst5(entry: Entry): string
	if not entry.First5 then
		return "(no first-5-minutes timeline: not a brand new player's first session)"
	end
	local lines = {}
	for _, moment in entry.First5 do
		table.insert(lines, ("  %s  %s"):format(clock(moment.T), moment.What))
	end
	if #lines == 0 then
		return "  (no reward moments yet)"
	end
	return table.concat(lines, "\n")
end

-- Everything for this player's current session, ready to print
function SessionLog.Report(player: Player): string
	local entry = current[player]
	if not entry then
		return ("[SessionLog] %s: no session yet"):format(player.Name)
	end
	local played = os.clock() - (started[player] or os.clock())
	return ("[SessionLog] %s at %s: %s\nFirst 5 minutes (reward moments):\n%s"):format(
		player.Name,
		clock(played),
		SessionLog.Describe(entry),
		SessionLog.DescribeFirst5(entry)
	)
end

-- level: the Power Level (1-12) the player just threw at. perfect: it was a PERFECT. assisted: the onboarding throw.
function SessionLog.Throw(player: Player, level: number, perfect: boolean?, assisted: boolean?)
	local entry = current[player]
	if entry then
		entry.Throws += 1
		entry.Level = math.max(entry.Level, level)
		if assisted then
			entry.Assisted = (entry.Assisted or 0) + 1
		elseif perfect then
			entry.Perfects = (entry.Perfects or 0) + 1
		end
	end
end

-- ===== Addendum 4 core loop instrumentation (Config.CoreLoop) =====
-- Seconds into this session
local function now(player: Player): number
	return math.floor((os.clock() - (started[player] or os.clock())) * 10) / 10
end

local function acted(player: Player, entry: Entry, what: string)
	entry.LastActionAt = now(player)
	entry.LastAction = what
end

-- A once-per-player moment: an onboarding funnel step plus a CoreMilestone event (value = seconds played in total)
local function milestone(player: Player, entry: Entry, field: string, step: string, label: string)
	(entry :: any)[field] = now(player)
	Analytics.Step(player, step)
	Analytics.Event(player, "CoreMilestone", math.floor(Analytics.MinutesPlayed(player) * 60), { label })
	print(("[SessionLog] %s: %s at %s into the session"):format(player.Name, label, clock(now(player))))
end

-- A core loop throw. throwsEver = the player's core throws ever, counting this one.
function SessionLog.CoreThrow(player: Player, throwsEver: number)
	local entry = current[player]
	if not entry then
		return
	end
	entry.Throws += 1
	acted(player, entry, "Throw")
	if throwsEver == 1 then
		milestone(player, entry, "FirstThrowAt", "First Throw", "FirstThrow")
	elseif throwsEver == 10 then
		milestone(player, entry, "TenthThrowAt", "Tenth Throw", "TenthThrow")
	end
end

-- A sell at the sell station. sellsEver = sells ever, counting this one.
function SessionLog.Sell(player: Player, coins: number, sellsEver: number)
	local entry = current[player]
	if not entry then
		return
	end
	entry.Sells = (entry.Sells or 0) + 1
	acted(player, entry, "Sell")
	Analytics.Event(player, "Sell", coins, { tostring(sellsEver), tostring(now(player)) })
	if sellsEver == 1 then
		milestone(player, entry, "FirstSellAt", "First Sell", "FirstSell")
	end
end

-- A ball bought (how = "Crate" today, the Stage 2 shop later)
function SessionLog.BallBought(player: Player, ballId: string, how: string)
	local entry = current[player]
	if not entry then
		return
	end
	entry.Balls = entry.Balls or {}
	table.insert(entry.Balls :: { string }, ("%s@%s"):format(ballId, clock(now(player))))
	Analytics.Step(player, "Bought Ball")
	Analytics.Event(player, "BallBought", math.floor(Analytics.MinutesPlayed(player) * 60), { ballId, how })
end

function SessionLog.Crate(player: Player)
	local entry = current[player]
	if entry then
		entry.Crates += 1
	end
end

-- A reward moment (ball unlocked, crate opened, Power Level, rank-up, free crate, Golden Pin...).
-- Only kept in a new player's first session, during the first First5Seconds seconds.
function SessionLog.Moment(player: Player, what: string)
	local entry = current[player]
	local at = started[player]
	if not entry or not entry.First5 or not at then
		return
	end
	local t = os.clock() - at
	if t <= SETTINGS.First5Seconds then
		table.insert(entry.First5, { T = math.floor(t * 10) / 10, What = what })
	end
end

PlayerDataService.OnLoaded(function(player)
	local log = PlayerDataService.Get(player, "SessionLog")
	if type(log) ~= "table" then
		return
	end
	-- Brand new player: nothing logged before and still at the very start of the first 3 minutes
	local isNew = #log == 0 and (PlayerDataService.Get(player, "Onboarding") or 3) == 0
	local entry: Entry = {
		Join = os.time(),
		Leave = 0,
		Throws = 0,
		Perfects = 0,
		Assisted = 0,
		Crates = 0,
		Level = 0,
		First5 = if isNew then {} else nil,
	}
	table.insert(log, entry)
	while #log > SETTINGS.Keep do
		table.remove(log, 1)
	end
	current[player] = entry
	started[player] = os.clock()

	if isNew and SETTINGS.Print then
		task.delay(SETTINGS.First5Seconds, function()
			if current[player] == entry then
				print(SessionLog.Report(player))
			end
		end)
	end
end)

-- Runs just before the final save
PlayerDataService.OnRelease(function(player)
	local entry = current[player]
	local at = started[player]
	current[player] = nil
	started[player] = nil
	if not entry then
		return
	end
	entry.Leave = os.time()
	if Config.CoreLoop.Enabled and entry.LastActionAt and at then
		-- time of last action: how long they stayed after their last throw or sell
		Analytics.Event(
			player,
			"LastAction",
			math.floor(os.clock() - at - entry.LastActionAt),
			{ entry.LastAction or "-" }
		)
	end
	local rate = SessionLog.PerfectRate(entry)
	if rate then
		Analytics.Event(player, "PerfectRate", math.floor(rate * 100 + 0.5), {
			tostring(entry.Throws - (entry.Assisted or 0)),
			tostring(entry.Perfects or 0),
		})
	end
	if SETTINGS.Print then
		print(("[SessionLog] %s: %s"):format(player.Name, SessionLog.Describe(entry)))
		if entry.First5 then
			print("[SessionLog] First 5 minutes (reward moments):\n" .. SessionLog.DescribeFirst5(entry))
		end
	end
end)

return SessionLog
