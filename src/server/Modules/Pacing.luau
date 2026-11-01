-- Addendum 5 step E: the pacing record. For every run (the climb from a fresh start or a rebirth to the next
-- rebirth) it saves when each ball, bag, pet slot and egg was first bought (seconds of play into that run), when the
-- rebirth came, and the income (coins sold a minute over the last Config.Pacing.IncomeWindow seconds): the top of
-- the run, just before the rebirth, 5 minutes into the next run, and when the next run got back to the old income.
-- Saved with the player (Pacing, v36; the newest Config.Pacing.KeepRuns runs), printed in Output when they leave
-- and by the Studio TEST panel's PACING button, and sent to Analytics (custom event "Pacing" + the "Run" funnel).
-- The clock is total play time (PlayTime), so a run over several sessions still adds up.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Currency = require(ReplicatedStorage.Shared.Modules.Currency)
local Analytics = require(script.Parent.Parent.Services.Analytics)
local PlayerDataService = require(script.Parent.Parent.Services.PlayerDataService)

local SETTINGS = Config.Pacing

local Pacing = {}

type Run = {
	R: number, -- rebirths done when the run started
	Start: number, -- play seconds (all sessions) when it started
	Times: { [string]: number }, -- "Ball3" / "Bag2" / "Slot4" / "Egg_Alley" / "Rebirth" = run seconds, first time only
	Top: number?, -- best income (coins a minute) in the run
	Before: number?, -- income just before this run's rebirth
	At5: number?, -- income 5 minutes into the run
	BackAt: number?, -- run seconds when the income got back to the last run's Before
}

local sells: { [Player]: { { number } } } = {} -- { play seconds, coins } in the income window (memory only)

local function clock(seconds: number?): string
	if not seconds then
		return "-"
	end
	seconds = math.floor(seconds)
	if seconds >= 3600 then
		return ("%d:%02d:%02d"):format(seconds // 3600, seconds % 3600 // 60, seconds % 60)
	end
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

local function record(player: Player): { Runs: { Run } }?
	if not SETTINGS.Enabled or not Config.CoreLoop.Enabled then
		return nil
	end
	local data = PlayerDataService.Get(player, "Pacing")
	if type(data) ~= "table" then
		return nil
	end
	if type(data.Runs) ~= "table" then
		data.Runs = {}
	end
	return data
end

-- The run the player is in now (a new one if the save has none or the rebirth count moved on)
local function run(player: Player): Run?
	local data = record(player)
	if not data then
		return nil
	end
	local rebirths = PlayerDataService.Get(player, "Rebirths") or 0
	local last = data.Runs[#data.Runs]
	if last and last.R == rebirths then
		return last
	end
	local fresh: Run = { R = rebirths, Start = Analytics.SecondsPlayed(player), Times = {} }
	table.insert(data.Runs, fresh)
	while #data.Runs > SETTINGS.KeepRuns do
		table.remove(data.Runs, 1)
	end
	-- Step of the "Run" funnel: 1 = run started, 2..10 = balls 2..10, 11 = rebirth (one funnel session per run)
	Analytics.Funnel(player, "Run", ("%d-R%d"):format(player.UserId, rebirths), 1, "Run start")
	return fresh
end

local function previous(player: Player, current: Run): Run?
	local data = record(player)
	local runs = data and data.Runs or {}
	local index = table.find(runs, current)
	return if index and index > 1 then runs[index - 1] else nil
end

-- Coins sold a minute over the income window (or since the run started, if that is shorter, but at least a minute)
function Pacing.Income(player: Player): number
	local list = sells[player]
	local current = run(player)
	if not list or not current then
		return 0
	end
	local now = Analytics.SecondsPlayed(player)
	local window = math.max(60, math.min(SETTINGS.IncomeWindow, now - current.Start))
	local total = 0
	for _, sale in list do
		if sale[1] >= now - window then
			total += sale[2]
		end
	end
	return total / window * 60
end

-- What = "Ball3", "Bag2", "Slot4", "Egg_Alley"...: kept the first time in this run only
local function mark(player: Player, what: string)
	local current = run(player)
	if not current or current.Times[what] then
		return
	end
	local into = math.floor(Analytics.SecondsPlayed(player) - current.Start)
	current.Times[what] = into
	Analytics.Event(player, "Pacing", into, { what, "R" .. current.R, tostring(Analytics.MinutesPlayed(player)) })
	if SETTINGS.Print then
		print(("[Pacing] %s: %s at %s into run %d"):format(player.Name, what, clock(into), current.R))
	end
end

local function funnel(player: Player, current: Run, step: number, name: string)
	Analytics.Funnel(player, "Run", ("%d-R%d"):format(player.UserId, current.R), step, name)
end

function Pacing.Ball(player: Player, step: number)
	local current = run(player)
	if current and not current.Times["Ball" .. step] then
		funnel(player, current, step, "Ball " .. step)
	end
	mark(player, "Ball" .. step)
end

function Pacing.Bag(player: Player, step: number)
	mark(player, "Bag" .. step)
end

function Pacing.Slot(player: Player, slot: number)
	mark(player, "Slot" .. slot)
end

function Pacing.Egg(player: Player, eggId: string)
	mark(player, "Egg_" .. eggId)
end

-- A sell: updates the income numbers
function Pacing.Sold(player: Player, coins: number)
	local current = run(player)
	if not current then
		return
	end
	local now = Analytics.SecondsPlayed(player)
	local list = sells[player] or {}
	sells[player] = list
	table.insert(list, { now, coins })
	while list[1] and list[1][1] < now - SETTINGS.IncomeWindow do
		table.remove(list, 1)
	end
	local income = Pacing.Income(player)
	current.Top = math.max(current.Top or 0, income)
	local into = now - current.Start
	if not current.At5 and into >= 300 then
		current.At5 = income
	end
	local before = previous(player, current)
	if before and (before.Before or 0) > 0 and not current.BackAt and income >= before.Before then
		current.BackAt = math.floor(into)
		Analytics.Event(
			player,
			"Pacing",
			current.BackAt,
			{ "BackToIncome", "R" .. current.R, tostring(Analytics.MinutesPlayed(player)) }
		)
		if SETTINGS.Print then
			print(
				("[Pacing] %s: back to the last run's %s coins a minute %s into run %d"):format(
					player.Name,
					Currency.Format(before.Before),
					clock(into),
					current.R
				)
			)
		end
	end
end

-- Call after the rebirth count went up (rebirths = the new count). Closes the old run and opens the next one.
function Pacing.Rebirth(player: Player, rebirths: number)
	local data = record(player)
	if not data then
		return
	end
	local last = data.Runs[#data.Runs]
	if last and last.R == rebirths - 1 then
		last.Before = Pacing.Income(player)
		local into = math.floor(Analytics.SecondsPlayed(player) - last.Start)
		last.Times.Rebirth = into
		funnel(player, last, 11, "Rebirth")
		Analytics.Event(
			player,
			"Pacing",
			into,
			{ "Rebirth" .. rebirths, "R" .. last.R, tostring(Analytics.MinutesPlayed(player)) }
		)
		Analytics.Event(player, "PacingIncome", math.floor(last.Before), { "BeforeRebirth" .. rebirths })
	end
	sells[player] = nil
	run(player)
end

-- The whole record as text, ready to print
function Pacing.Report(player: Player): string
	local data = record(player)
	if not data then
		return ("[Pacing] %s: no pacing record (Config.Pacing off or not loaded)"):format(player.Name)
	end
	local lines = {
		("[Pacing] %s: %d rebirths, played %s in total, income now %s a minute"):format(
			player.Name,
			PlayerDataService.Get(player, "Rebirths") or 0,
			clock(Analytics.SecondsPlayed(player)),
			Currency.Format(Pacing.Income(player))
		),
	}
	local first: number? = nil
	for index, current in data.Runs do
		local function list(prefix: string, count: number?): string
			local parts = {}
			if count then
				for step = 2, count do
					local at = current.Times[prefix .. step]
					if at then
						table.insert(parts, ("%d %s"):format(step, clock(at)))
					end
				end
			else
				for key, at in current.Times do
					if key:sub(1, #prefix) == prefix then
						table.insert(parts, { key:sub(#prefix + 1), at })
					end
				end
				table.sort(parts, function(a: any, b: any)
					return a[2] < b[2]
				end)
				for i, part in parts do
					parts[i] = ("%s %s"):format(part[1], clock(part[2]))
				end
			end
			return if #parts > 0 then table.concat(parts, " | ") else "-"
		end
		local ended = current.Times.Rebirth
		if index == 1 then
			first = current.Times.Rebirth
		end
		local back = previous(player, current)
		table.insert(
			lines,
			("run %d (x%g), started at %s played%s"):format(
				current.R,
				1 + Config.CoreLoop.Rebirth.Bonus * current.R,
				clock(current.Start),
				if ended
					then (", rebirth %d after %s (at %s played)"):format(
						current.R + 1,
						clock(ended),
						clock(current.Start + ended)
					)
					else ", still going"
			)
		)
		table.insert(lines, "  balls: " .. list("Ball", #Config.CoreLoop.Balls))
		table.insert(lines, "  bags:  " .. list("Bag", #Config.CoreLoop.BagSizes))
		table.insert(lines, "  eggs:  " .. list("Egg_"))
		table.insert(lines, "  slots: " .. list("Slot"))
		table.insert(
			lines,
			("  income a minute: top %s, 5 min in %s, before rebirth %s%s"):format(
				Currency.Format(current.Top or 0),
				if current.At5 then Currency.Format(current.At5) else "-",
				if current.Before then Currency.Format(current.Before) else "-",
				if back and (back.Before or 0) > 0
					then (", back to the last run's %s after %s%s"):format(
						Currency.Format(back.Before),
						clock(current.BackAt),
						if current.BackAt
								and first
								and first > 0
							then (" (%d%% of the first run)"):format(math.floor(current.BackAt / first * 100 + 0.5))
							else ""
					)
					else ""
			)
		)
	end
	return table.concat(lines, "\n")
end

PlayerDataService.OnLoaded(function(player)
	run(player) -- (opens the first run for a new save)
end)

PlayerDataService.OnRelease(function(player)
	if SETTINGS.Print and record(player) then
		print(Pacing.Report(player))
	end
	sells[player] = nil
end)

return Pacing
