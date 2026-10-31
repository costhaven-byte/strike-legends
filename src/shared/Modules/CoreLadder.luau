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

-- "Rubber Bouncer" / "Bag 3" (what a step is called on screen)
function CoreLadder.Name(kind: string, step: number): string
	return if kind == "Ball" then CORE.Balls[step].Name else ("Bag %d"):format(step)
end

return CoreLadder
