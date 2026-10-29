-- Golden Pins: before each rack, the server rolls whether one pin is golden (Config.GoldenPin).
-- Clients read it from lane attributes: GoldenPin (pin number 1-10, 0 = none) and GoldenLucky
-- (true when only the owner's Lucky ball trait made it appear, so the client can show "LUCKY!").
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local LaneUtil = require(Shared.Modules.LaneUtil)
local Players = game:GetService("Players")
local BallService = require(script.Parent.BallService)

local GOLDEN = Config.GoldenPin

local GoldenPinService = {}

-- Rolls the golden pin for the lane's next rack, using its owner's equipped ball
function GoldenPinService.Roll(lane: Model)
	local ownerId = lane:GetAttribute("OwnerId")
	local owner = ownerId and Players:GetPlayerByUserId(ownerId)
	-- No Golden Pin on a lane event rack (Config.LaneEvents)
	if not owner or (lane:GetAttribute("LaneEvent") or "") ~= "" then
		lane:SetAttribute("GoldenPin", 0)
		lane:SetAttribute("GoldenLucky", false)
		return
	end
	local lucky = Balls.TraitValue(BallService.GetEquipped(owner), "Lucky")
	local chance = math.min(GOLDEN.Chance * (1 + lucky), GOLDEN.MaxChance)
	local roll = math.random()
	local golden = roll < chance
	lane:SetAttribute("GoldenLucky", golden and roll >= GOLDEN.Chance) -- only there thanks to Lucky
	lane:SetAttribute("GoldenPin", if golden then math.random(1, Config.Lane.PinCount) else 0)
end

-- The golden pin number on this lane right now (0 = none)
function GoldenPinService.Get(lane: Model): number
	return lane:GetAttribute("GoldenPin") or 0
end

function GoldenPinService:Start()
	for _, lane in LaneUtil.GetLanes() do
		lane:SetAttribute("GoldenPin", 0)
		lane:SetAttribute("GoldenLucky", false)
		-- A new owner gets a fresh roll for their first rack
		lane:GetAttributeChangedSignal("OwnerId"):Connect(function()
			task.defer(GoldenPinService.Roll, lane)
		end)
	end
end

return GoldenPinService
