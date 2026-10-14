-- Day and week numbers in UTC, so every server (and the client) agrees when a new day or week starts.
local Calendar = {}

local DAY = 86400
local WEEK = DAY * 7
local FIRST_MONDAY = 4 * DAY -- 1 Jan 1970 was a Thursday; 5 Jan 1970 was the first Monday

-- Days since 1 Jan 1970 (UTC). Goes up by one at midnight UTC.
function Calendar.Day(time: number?): number
	return (time or os.time()) // DAY
end

-- Weeks since the first Monday of 1970 (UTC). Goes up by one every Monday 00:00 UTC.
function Calendar.Week(time: number?): number
	return ((time or os.time()) - FIRST_MONDAY) // WEEK
end

function Calendar.SecondsUntilNextDay(time: number?): number
	local now = time or os.time()
	return (Calendar.Day(now) + 1) * DAY - now
end

function Calendar.SecondsUntilNextWeek(time: number?): number
	local now = time or os.time()
	return FIRST_MONDAY + (Calendar.Week(now) + 1) * WEEK - now
end

-- 93784 -> "1d 2h", 7260 -> "2h 1m", 59 -> "0m"
function Calendar.FormatCountdown(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local days = seconds // DAY
	local hours = (seconds % DAY) // 3600
	local minutes = (seconds % 3600) // 60
	if days > 0 then
		return ("%dd %dh"):format(days, hours)
	end
	return ("%dh %dm"):format(hours, minutes)
end

return Calendar
