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

-- Addendum 5 step C: ball and bag prices x (rebirth multiplier) ^ LadderPower after rebirths (Config.CoreLoop.Rebirth),
-- rounded to 2 figures. rebirths nil / 0 = the Config price.
function CoreLadder.Price(price: number, rebirths: any): number
	local done = math.max(0, math.floor(tonumber(rebirths) or 0))
	local rebirth = CORE.Rebirth
	if done == 0 or price <= 0 or not rebirth or not rebirth.Enabled or (rebirth.LadderPower or 0) == 0 then
		return price
	end
	local scaled = price * (1 + rebirth.Bonus * done) ^ rebirth.LadderPower
	local unit = 10 ^ math.max(math.floor(math.log10(scaled)) - 1, 0)
	return math.floor(scaled / unit + 0.5) * unit
end

-- The price of ball `step` / bag `level` after `rebirths` rebirths
function CoreLadder.BallPrice(step: number, rebirths: any): number
	return CoreLadder.Price(CORE.Balls[step].Price, rebirths)
end

function CoreLadder.BagPrice(level: number, rebirths: any): number
	return CoreLadder.Price(CORE.BagPrices[level], rebirths)
end

-- The next ball on the ball ladder (step, price), or nil when every ball is bought
function CoreLadder.NextBall(ballStep: any, rebirths: any): (number?, number)
	local step = CoreLadder.BallStep(ballStep) + 1
	if step > #CORE.Balls then
		return nil, 0
	end
	return step, CoreLadder.BallPrice(step, rebirths)
end

-- The next bag on the bag ladder (level, price), or nil when every bag is bought
function CoreLadder.NextBag(bagLevel: any, rebirths: any): (number?, number)
	local level = CoreLadder.BagLevel(bagLevel) + 1
	if level > #CORE.BagSizes then
		return nil, 0
	end
	return level, CoreLadder.BagPrice(level, rebirths)
end

-- What the shop can sell of `kind` right now ("Ball" / "Bag"): its step and price, nil = can't (bought them all,
-- or, with the old alternating ladder, the other kind comes first)
function CoreLadder.Buyable(kind: string, ballStep: any, bagLevel: any, rebirths: any): (number?, number)
	if not CORE.Ladders.Independent then
		local want, step, price = CoreLadder.Next(ballStep, bagLevel, rebirths)
		if want == kind then
			return step, price
		end
		return nil, 0
	end
	if kind == "Ball" then
		return CoreLadder.NextBall(ballStep, rebirths)
	elseif kind == "Bag" then
		return CoreLadder.NextBag(bagLevel, rebirths)
	end
	return nil, 0
end

-- The next goal: "Ball" or "Bag", its step and price; nil = everything bought. Addendum 5 A2 (Ladders.Independent):
-- the cheaper of the next ball and the next bag (a tie = the ball). Addendum 4: they alternate ball 2, bag 2, ball 3,
-- bag 3 ... ball 10, bag 10.
function CoreLadder.Next(ballStep: any, bagLevel: any, rebirths: any): (string?, number, number)
	local ball = CoreLadder.BallStep(ballStep)
	local bag = CoreLadder.BagLevel(bagLevel)
	if CORE.Ladders.Independent then
		local ballNext, ballPrice = CoreLadder.NextBall(ball, rebirths)
		local bagNext, bagPrice = CoreLadder.NextBag(bag, rebirths)
		if ballNext and (not bagNext or ballPrice <= bagPrice) then
			return "Ball", ballNext, ballPrice
		elseif bagNext then
			return "Bag", bagNext, bagPrice
		end
		return nil, 0, 0
	end
	if bag < ball and bag < #CORE.BagSizes then
		return "Bag", bag + 1, CoreLadder.BagPrice(bag + 1, rebirths)
	elseif ball < #CORE.Balls then
		return "Ball", ball + 1, CoreLadder.BallPrice(ball + 1, rebirths)
	elseif bag < #CORE.BagSizes then
		return "Bag", bag + 1, CoreLadder.BagPrice(bag + 1, rebirths)
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

-- A gift worth `minutes` of that income, rounded to 2 figures (at least 10). Addendum 5 F: x the rebirth price
-- growth (CoreLadder.Price), so a gift stays the same share of what the shop asks after a rebirth.
function CoreLadder.GiftCoins(minutes: number, ballStep: any, bagLevel: any, rebirths: any): number
	local coins = math.max(CoreLadder.Price(minutes * CoreLadder.IncomePerMinute(ballStep, bagLevel), rebirths), 10)
	local unit = 10 ^ math.max(math.floor(math.log10(coins)) - 1, 0)
	return math.floor(coins / unit + 0.5) * unit
end

-- "Rubber Bouncer" / "Bag 3" (what a step is called on screen)
function CoreLadder.Name(kind: string, step: number): string
	return if kind == "Ball" then CORE.Balls[step].Name else ("Bag %d"):format(step)
end

return CoreLadder
