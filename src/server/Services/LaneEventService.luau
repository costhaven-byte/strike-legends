-- LANE EVENTS (final changes batch D5, Config.LaneEvents): about every 2 minutes of bowling by hand, a player's lane
-- gets a one-throw event on its next rack: GOLDEN RACK (all pins gold, a strike pays x5), 7-10 SPLIT (only pins 7
-- and 10 stand, both down = a big prize) or GEM PIN (one pin gives gems when it falls).
-- The server owns it: it rolls the event when the pins reset, publishes it as lane attributes LaneEvent (an event
-- Id, "" = none) and LaneEventPin (the gem pin), and ThrowService takes it on the next throw (Take) and pays it.
-- The attributes are only cleared when the pins reset after that throw, so a throw in flight never sees its rack
-- change. Clients draw the rack (LaneVisuals/PinRack) and the announce/marker/result (LaneEventController).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local LaneUtil = require(Shared.Modules.LaneUtil)
local BossService = require(script.Parent.BossService)
local FeverService = require(script.Parent.FeverService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local TrialService = require(script.Parent.TrialService)

local EVENTS = Config.LaneEvents
local ORDER = { "GoldenRack", "Split", "GemPin" }

local LaneEventService = {}

local bowled: { [Player]: number } = {} -- seconds of hand bowling since the last event
local target: { [Player]: number } = {} -- seconds of bowling the next event needs
local lastThrow: { [Player]: number } = {}
local forced: { [Player]: string } = {} -- Studio TEST: this event on the next rack
local taken: { [Model]: boolean } = {} -- the lane's event was thrown at; cleared when the pins reset

local function newTarget(player: Player)
	bowled[player] = 0
	target[player] = EVENTS.Interval + (math.random() * 2 - 1) * EVENTS.Jitter
end

-- First minutes over (Config.Onboarding stage 3; old saves have no stage = done)
local function onboarded(player: Player): boolean
	if not Config.Onboarding.Enabled then
		return true
	end
	return (tonumber(PlayerDataService.Get(player, "Onboarding")) or 3) >= 3
end

-- Events wait while any of these is on
local function busy(player: Player): boolean
	return FeverService.Active(player)
		or TrialService.GetAttemptId(player) ~= nil
		or BossService.InFight(player)
		or player:GetAttribute("AutoBowl") == true
end

local function pick(): string
	local total = 0
	for _, id in ORDER do
		total += EVENTS.Weights[id] or 0
	end
	local roll = math.random() * total
	for _, id in ORDER do
		roll -= EVENTS.Weights[id] or 0
		if roll <= 0 then
			return id
		end
	end
	return ORDER[1]
end

local function set(lane: Model, id: string, pin: number)
	lane:SetAttribute("LaneEventPin", pin)
	lane:SetAttribute("LaneEvent", id)
end

local function begin(lane: Model, player: Player, id: string)
	local pins = EVENTS.GemPin.Pins
	set(lane, id, if id == "GemPin" then pins[math.random(1, #pins)] else 0)
	-- no Golden Pin on an event rack (GoldenPinService checks LaneEvent too)
	lane:SetAttribute("GoldenPin", 0)
	newTarget(player)
end

-- The event on this lane's standing rack ("" = none)
function LaneEventService.Get(lane: Model): string
	return lane:GetAttribute("LaneEvent") or ""
end

-- A throw starts on this lane: returns the event it is thrown at (nil = none) and its pin; the event is used up.
-- auto = an Auto Bowl throw (doesn't move the bowling clock)
function LaneEventService.Take(lane: Model, player: Player, auto: boolean): (string?, number)
	local now = os.clock()
	if auto then
		lastThrow[player] = nil
	else
		if onboarded(player) then
			local gap = now - (lastThrow[player] or now)
			bowled[player] = (bowled[player] or 0) + math.min(gap, EVENTS.MaxGap)
		end
		lastThrow[player] = now
	end
	local id = LaneEventService.Get(lane)
	if id == "" or taken[lane] then
		return nil, 0
	end
	taken[lane] = true
	return id, lane:GetAttribute("LaneEventPin") or 0
end

-- The pins reset after a throw: the old event goes, and the next one starts if it is time
-- (call before GoldenPinService.Roll, which skips event racks)
function LaneEventService.OnReset(lane: Model, player: Player)
	taken[lane] = nil
	set(lane, "", 0)
	if not EVENTS.Enabled or not player.Parent or lane:GetAttribute("OwnerId") ~= player.UserId then
		return
	end
	local id = forced[player]
	if id then
		forced[player] = nil
		begin(lane, player, id)
		return
	end
	if not target[player] then
		newTarget(player)
	end
	if (bowled[player] or 0) >= target[player] and onboarded(player) and not busy(player) then
		begin(lane, player, pick())
	end
end

-- Studio TEST panel: put this event on the player's lane now (or on the next rack if a ball is rolling)
function LaneEventService.Force(player: Player, id: string): (boolean, string)
	if not EVENTS.Weights[id] then
		return false, "Unknown event"
	end
	local lane = LaneUtil.GetOwnedLane(player.UserId)
	if not lane then
		return false, "Get on your lane first"
	end
	if taken[lane] or Workspace:GetServerTimeNow() < (lane:GetAttribute("ReadyAt") or 0) then
		forced[player] = id
		return true, "On the next rack"
	end
	begin(lane, player, id)
	return true, "On your lane now: throw!"
end

-- What a split throw knocks down: a PERFECT (or the paid AUTO BOWL strike) gets both, others a small chance
function LaneEventService.SplitPins(perfect: boolean, gutter: boolean): { number }
	local split = EVENTS.Split
	if gutter then
		return {}
	end
	if perfect then
		return table.clone(split.Pins)
	end
	local roll = math.random()
	if roll < split.BothChance then
		return table.clone(split.Pins)
	elseif roll < split.BothChance + split.OneChance then
		return { split.Pins[math.random(1, #split.Pins)] }
	end
	return {}
end

-- Gems for a zone (the event rows' Gems lists, by zone; the last one for later zones)
function LaneEventService.Gems(list: { number }, zone: number): number
	return list[math.clamp(zone, 1, #list)]
end

function LaneEventService:Start()
	for _, lane in LaneUtil.GetLanes() do
		set(lane, "", 0)
		-- A new owner never inherits the last one's event
		lane:GetAttributeChangedSignal("OwnerId"):Connect(function()
			taken[lane] = nil
			set(lane, "", 0)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		bowled[player] = nil
		target[player] = nil
		lastThrow[player] = nil
		forced[player] = nil
	end)
	-- A waiting event goes away if fever, a trial, the boss or AUTO BOWL starts before it is thrown at
	-- (it comes back on the first rack after, since the bowling clock is still past its time)
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, lane in LaneUtil.GetLanes() do
				if LaneEventService.Get(lane) ~= "" and not taken[lane] then
					local owner = Players:GetPlayerByUserId(lane:GetAttribute("OwnerId") or 0)
					if not owner or busy(owner) then
						set(lane, "", 0)
						if owner then
							bowled[owner] = math.max(bowled[owner] or 0, target[owner] or 0)
						end
					end
				end
			end
		end
	end)
end

return LaneEventService
