-- Addendum 4 Stage 2: the ball and bag ladders (Config.CoreLoop Balls / BagSizes / BagPrices). Shared so the server
-- (CoreLoopService sells them) and the screens (shop, next-goal bar) agree on what comes next.
local Config = require(script.Parent.Parent.Config)

local CORE = Config.CoreLoop

local CoreLadder = {}

-- Clamped steps from the saved / attribute values
function CoreLadder.BallStep(value: any): number
	return math.clamp(math.floor(tonumber(value) or 1), 1, #CORE.Balls)
end

function CoreLadder.BagLevel(value: any): number
	return math.clamp(math.floor(tonumber(value) or 1), 1, #CORE.BagSizes)
end

-- What the shop sells next: "Ball" or "Bag", its step and price. They alternate: ball 2, bag 2, ball 3, bag 3 ...
-- ball 10, bag 10. nil = everything bought.
function CoreLadder.Next(ballStep: any, bagLevel: any): (string?, number, number)
	local ball = CoreLadder.BallStep(ballStep)
	local bag = CoreLadder.BagLevel(bagLevel)
	if bag < ball and bag < #CORE.BagSizes then
		return "Bag", bag + 1, CORE.BagPrices[bag + 1]
	elseif ball < #CORE.Balls then
		return "Ball", ball + 1, CORE.Balls[ball + 1].Price
	elseif bag < #CORE.BagSizes then
		return "Bag", bag + 1, CORE.BagPrices[bag + 1]
	end
	return nil, 0, 0
end

-- Coins per minute with this ball and bag: the ball's average throw (a full clear pays FullClearMultiplier) every
-- Cooldown, with a sell trip (Gifts.TripSeconds) each time the bag fills. No multipliers. Same rule as
-- EconomySim.CoreLadder.
function CoreLadder.IncomePerMinute(ballStep: any, bagLevel: any): number
	local pins = CORE.Balls[CoreLadder.BallStep(ballStep)].Pins
	local total, n = 0, 200
	for i = 1, n do
		local wanted = pins * (1 + ((i - 0.5) / n * 2 - 1) * CORE.PinsSpread)
		local count = math.clamp(math.floor(wanted + 0.5), 1, 40)
		total += count * (if count >= 40 then CORE.FullClearMultiplier else 1)
	end
	local rate = total / n * CORE.PinValue / CORE.Cooldown
	local size = CORE.BagSizes[CoreLadder.BagLevel(bagLevel)]
	return 60 * size / (size / rate + CORE.Gifts.TripSeconds)
end

-- A gift worth `minutes` of that income, rounded to 2 figures (at least 10)
function CoreLadder.GiftCoins(minutes: number, ballStep: any, bagLevel: any): number
	local coins = math.max(minutes * CoreLadder.IncomePerMinute(ballStep, bagLevel), 10)
	local unit = 10 ^ math.max(math.floor(math.log10(coins)) - 1, 0)
	return math.floor(coins / unit + 0.5) * unit
end

-- "Rubber Bouncer" / "Bag 3" (what a step is called on screen)
function CoreLadder.Name(kind: string, step: number): string
	return if kind == "Ball" then CORE.Balls[step].Name else ("Bag %d"):format(step)
end

return CoreLadder
