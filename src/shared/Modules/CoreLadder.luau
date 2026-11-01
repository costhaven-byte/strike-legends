-- Addendum 4 Stage 2: the ball and bag ladders (Config.CoreLoop Balls / BagSizes / BagPrices). Shared so the server
-- (CoreLoopService sells them) and the screens (shop, next-goal bar) agree on what comes next.
-- Addendum 5 A2: two independent ladders (Config.CoreLoop.Ladders.Independent).
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

-- Addendum 5 A1: the throw animation level (Config.Throw pose levels) for a ball step, so the throw gets cleaner as
-- you buy balls (levels are gone)
function CoreLadder.Pose(ballStep: any): number
	return CORE.Poses[CoreLadder.BallStep(ballStep)] or 1
end

-- The next ball on the ball ladder (step, price), or nil when every ball is bought
function CoreLadder.NextBall(ballStep: any): (number?, number)
	local step = CoreLadder.BallStep(ballStep) + 1
	if step > #CORE.Balls then
		return nil, 0
	end
	return step, CORE.Balls[step].Price
end

-- The next bag on the bag ladder (level, price), or nil when every bag is bought
function CoreLadder.NextBag(bagLevel: any): (number?, number)
	local level = CoreLadder.BagLevel(bagLevel) + 1
	if level > #CORE.BagSizes then
		return nil, 0
	end
	return level, CORE.BagPrices[level]
end

-- What the shop can sell of `kind` right now ("Ball" / "Bag"): its step and price, nil = can't (bought them all,
-- or, with the old alternating ladder, the other kind comes first)
function CoreLadder.Buyable(kind: string, ballStep: any, bagLevel: any): (number?, number)
	if not CORE.Ladders.Independent then
		local want, step, price = CoreLadder.Next(ballStep, bagLevel)
		if want == kind then
			return step, price
		end
		return nil, 0
	end
	if kind == "Ball" then
		return CoreLadder.NextBall(ballStep)
	elseif kind == "Bag" then
		return CoreLadder.NextBag(bagLevel)
	end
	return nil, 0
end

-- The next goal: "Ball" or "Bag", its step and price; nil = everything bought. Addendum 5 A2 (Ladders.Independent):
-- the cheaper of the next ball and the next bag (a tie = the ball). Addendum 4: they alternate ball 2, bag 2, ball 3,
-- bag 3 ... ball 10, bag 10.
function CoreLadder.Next(ballStep: any, bagLevel: any): (string?, number, number)
	local ball = CoreLadder.BallStep(ballStep)
	local bag = CoreLadder.BagLevel(bagLevel)
	if CORE.Ladders.Independent then
		local ballNext, ballPrice = CoreLadder.NextBall(ball)
		local bagNext, bagPrice = CoreLadder.NextBag(bag)
		if ballNext and (not bagNext or ballPrice <= bagPrice) then
			return "Ball", ballNext, ballPrice
		elseif bagNext then
			return "Bag", bagNext, bagPrice
		end
		return nil, 0, 0
	end
	if bag < ball and bag < #CORE.BagSizes then
		return "Bag", bag + 1, CORE.BagPrices[bag + 1]
	elseif ball < #CORE.Balls then
		return "Ball", ball + 1, CORE.Balls[ball + 1].Price
	elseif bag < #CORE.BagSizes then
		return "Bag", bag + 1, CORE.BagPrices[bag + 1]
	end
	return nil, 0, 0
end

-- Coins per minute with this ball and bag: the ball's average throw every Cooldown, with a sell trip
-- (Gifts.TripSeconds) each time the bag fills. No multipliers. Same rule as EconomySim.CoreLadder.
function CoreLadder.IncomePerMinute(ballStep: any, bagLevel: any): number
	local pins = CORE.Balls[CoreLadder.BallStep(ballStep)].Pins
	local total, n = 0, 200
	for i = 1, n do
		local wanted = pins * (1 + ((i - 0.5) / n * 2 - 1) * CORE.PinsSpread)
		total += math.max(math.floor(wanted + 0.5), 1) -- (Addendum 5 A1: no 40 cap, no full-clear x2)
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
