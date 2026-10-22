-- All coin and currency math and display (Phase X Part 8A). Every system adds, spends, compares, multiplies,
-- saves and shows coins through here, so the number type can change later (for example to mantissa + exponent
-- for numbers past 9 quadrillion) without touching anything else. Today values are plain Luau numbers (doubles).
-- Settings: Config.Numbers (suffix list, decimals, the precision guard).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local NUMBERS = Config.Numbers

local Currency = {}

-- Precision guard: doubles stop counting whole coins exactly at about 9e15. Warn (once per call site) when a
-- value reaches Config.Numbers.WarnAt, so it is caught long before it causes bugs.
local warned: { [string]: boolean } = {}
function Currency.Guard(value: number, where: string?): number
	if value ~= value then -- NaN never reaches a save
		warn(("[Currency] NaN at %s, using 0"):format(where or "?"))
		return 0
	end
	if math.abs(value) >= NUMBERS.WarnAt then
		local key = where or "?"
		if not warned[key] then
			warned[key] = true
			warn(
				("[Currency] %s reached %s (precision limit about %s): time to switch Currency to big numbers"):format(
					key,
					Currency.Format(value),
					Currency.Format(NUMBERS.SafeMax)
				)
			)
		end
	end
	return value
end

function Currency.Zero(): number
	return 0
end

-- a + b
function Currency.Add(a: number, b: number, where: string?): number
	return Currency.Guard(a + b, where)
end

-- a - b
function Currency.Sub(a: number, b: number, where: string?): number
	return Currency.Guard(a - b, where)
end

-- An amount times a multiplier (boosts, payouts), rounded to whole coins
function Currency.Mul(amount: number, multiplier: number, where: string?): number
	return Currency.Guard(math.floor(amount * multiplier + 0.5), where)
end

-- An amount times a multiplier, not rounded yet (for a payout built from several boosts; Round it at the end)
function Currency.Scale(amount: number, multiplier: number): number
	return amount * multiplier
end

-- Rounded to whole coins
function Currency.Round(amount: number): number
	return math.floor(amount + 0.5)
end

-- -1, 0 or 1
function Currency.Compare(a: number, b: number): number
	return if a < b then -1 elseif a > b then 1 else 0
end

-- Can this balance pay this price?
function Currency.CanAfford(balance: number?, price: number): boolean
	return (balance or 0) >= price
end

function Currency.Max(a: number, b: number): number
	return math.max(a, b)
end

function Currency.Min(a: number, b: number): number
	return math.min(a, b)
end

-- How a value goes into the save, and how a saved value comes back (plain numbers today; a future representation
-- can read both the old plain numbers and its own format here, which is the save migration)
function Currency.Encode(amount: number): any
	return amount
end

function Currency.Decode(saved: any): number
	return if type(saved) == "number" and saved == saved then saved else 0
end

-- "999", "1.5K", "12.34M", "4B", "1.2Qa": short suffix format (Config.Numbers.Suffixes), 1-2 decimals, trailing
-- zeros trimmed. Below Config.Numbers.ShortFrom the whole number shows with commas ("9,500").
function Currency.Format(amount: number): string
	local negative = amount < 0
	local n = math.abs(amount)
	local text
	if n < NUMBERS.ShortFrom then
		text = Currency.FormatFull(n)
	else
		local tier = math.floor(math.log10(n) / 3)
		local suffixes = NUMBERS.Suffixes
		if tier > #suffixes then
			text = ("%.2e"):format(n) -- past the last suffix: scientific
		else
			local scaled = n / 10 ^ (tier * 3)
			-- 2 decimals under 100 (12.34M), 1 decimal above (123.4M); cut, never rounded up to the next unit
			local decimals = if scaled < 100 then NUMBERS.Decimals else math.max(NUMBERS.Decimals - 1, 0)
			local step = 10 ^ decimals
			scaled = math.floor(scaled * step + 1e-6) / step
			text = ("%." .. decimals .. "f"):format(scaled)
			if decimals > 0 then
				text = text:gsub("0+$", ""):gsub("%.$", "")
			end
			text ..= suffixes[tier]
		end
	end
	return if negative then "-" .. text else text
end

-- Whole number with commas: "1,234,567" (for exact amounts)
function Currency.FormatFull(amount: number): string
	local text = tostring(math.floor(amount + 0.5))
	if text:find("e") then
		return Currency.Format(amount)
	end
	repeat
		local count
		text, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return text
end

-- A multiplier: "x1.25", "x40", "x1.2K"
function Currency.FormatMultiplier(value: number): string
	if value >= NUMBERS.ShortFrom then
		return "x" .. Currency.Format(value)
	end
	local text = ("%.2f"):format(value):gsub("0+$", ""):gsub("%.$", "")
	return "x" .. text
end

return Currency
