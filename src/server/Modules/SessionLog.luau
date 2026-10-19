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
	return ("joined %s, left %s (%d min), %d throws, %d PERFECT (%s), %d crates, Power Level %d"):format(
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
	current[player] = nil
	started[player] = nil
	if not entry then
		return
	end
	entry.Leave = os.time()
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
