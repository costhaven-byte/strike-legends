-- One simple line per play session: when the player joined and left, throws, crates opened and the
-- highest throw level reached. Saved with the player (the newest Config.SessionLog.Keep sessions)
-- and printed in the Output window when they leave. Numbers update live, so a crash still keeps them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local PlayerDataService = require(script.Parent.Parent.Services.PlayerDataService)

local SETTINGS = Config.SessionLog

local SessionLog = {}

type Entry = { Join: number, Leave: number, Throws: number, Crates: number, Level: number }

local current: { [Player]: Entry } = {}

local function stamp(time: number): string
	return os.date("%Y-%m-%d %H:%M", time) :: string
end

-- Text version of one session, for the Output window
function SessionLog.Describe(entry: Entry): string
	local leave = if entry.Leave > 0 then entry.Leave else os.time()
	return ("joined %s, left %s (%d min), %d throws, %d crates, level %d"):format(
		stamp(entry.Join),
		if entry.Leave > 0 then stamp(entry.Leave) else "still playing",
		math.floor((leave - entry.Join) / 60 + 0.5),
		entry.Throws,
		entry.Crates,
		entry.Level
	)
end

-- level: the throw level (1-12) the player just threw at
function SessionLog.Throw(player: Player, level: number)
	local entry = current[player]
	if entry then
		entry.Throws += 1
		entry.Level = math.max(entry.Level, level)
	end
end

function SessionLog.Crate(player: Player)
	local entry = current[player]
	if entry then
		entry.Crates += 1
	end
end

PlayerDataService.OnLoaded(function(player)
	local log = PlayerDataService.Get(player, "SessionLog")
	if type(log) ~= "table" then
		return
	end
	local entry: Entry = { Join = os.time(), Leave = 0, Throws = 0, Crates = 0, Level = 0 }
	table.insert(log, entry)
	while #log > SETTINGS.Keep do
		table.remove(log, 1)
	end
	current[player] = entry
end)

-- Runs just before the final save
PlayerDataService.OnRelease(function(player)
	local entry = current[player]
	current[player] = nil
	if not entry then
		return
	end
	entry.Leave = os.time()
	if SETTINGS.Print then
		print(("[SessionLog] %s: %s"):format(player.Name, SessionLog.Describe(entry)))
	end
end)

return SessionLog
