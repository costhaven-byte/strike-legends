-- Receives aim/power from players, validates it, works out the result and tells every client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local LaneUtil = require(Shared.Modules.LaneUtil)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ThrowResolver = require(script.Parent.Parent.Modules.ThrowResolver)
local RewardResolver = require(script.Parent.Parent.Modules.RewardResolver)

local ThrowService = {}

local TIER_TEXT = {
	Gutter = "GUTTER",
	Weak = "%d PINS",
	Good = "%d PINS",
	Nine = "SO CLOSE! 9",
	Strike = "STRIKE!",
	PerfectStrike = "PERFECT!",
}

local function setStatus(lane: Model, text: string)
	local board = lane:FindFirstChild("Scoreboard")
	local label = board and board:FindFirstChild("Status", true)
	if label then
		label.Text = text
	end
end

-- Every coin multiplier for this player. Milestone 4 fills in Rank and Streak, Milestone 6 the Ball.
-- Future gamepasses and boosts get added here as new entries.
local function getCoinMultipliers(_player: Player): { [string]: number }
	return {
		Ball = 1,
		Rank = 1,
		Streak = 1,
	}
end

local function isValidNumber(value: any): boolean
	return typeof(value) == "number" and value == value and math.abs(value) ~= math.huge
end

local function onThrowRequest(player: Player, aim: any, power: any)
	if not isValidNumber(aim) or not isValidNumber(power) then
		return
	end
	aim = math.clamp(aim, -1, 1)
	power = math.clamp(power, 0, 1)

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	-- Players can only throw on their own lane, while standing on it
	local lane = LaneUtil.GetOwnedLane(player.UserId)
	if not lane or not LaneUtil.IsInThrowZone(lane, root.Position) then
		return
	end

	-- One throw at a time per lane; ReadyAt is in server time so clients can read it too.
	local now = Workspace:GetServerTimeNow()
	if now < (lane:GetAttribute("ReadyAt") or 0) then
		return
	end

	local result = ThrowResolver.Resolve(aim, power)
	local reward = RewardResolver.Calculate(result.Count, result.Tier, getCoinMultipliers(player))
	lane:SetAttribute("ReadyAt", now + result.RollTime + Config.Lane.PinResetDelay + Config.Throw.CooldownBuffer)

	ThrowService.Remotes.ThrowResult:FireAllClients({
		Lane = lane,
		UserId = player.UserId,
		Aim = aim,
		Power = power,
		Count = result.Count,
		Tier = result.Tier,
		Pins = result.Pins,
		HitX = result.HitX,
		Gutter = result.Gutter,
		RollTime = result.RollTime,
		Reward = reward,
	})

	setStatus(lane, "ROLLING...")
	task.delay(result.RollTime, function()
		-- Paid when the ball reaches the pins, so the HUD ticks up in sync with the hit
		if player.Parent then
			for key, amount in reward do
				if amount > 0 then
					PlayerDataService.Add(player, key, amount)
				end
			end
		end
		setStatus(lane, if result.Count == 1 then "1 PIN" else TIER_TEXT[result.Tier]:format(result.Count))
	end)
end

function ThrowService:Start()
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"

	local request = Instance.new("RemoteEvent")
	request.Name = "ThrowRequest"
	request.Parent = folder

	local resultEvent = Instance.new("RemoteEvent")
	resultEvent.Name = "ThrowResult"
	resultEvent.Parent = folder

	folder.Parent = ReplicatedStorage
	self.Remotes = { ThrowRequest = request, ThrowResult = resultEvent }

	for _, lane in LaneUtil.GetLanes() do
		lane:SetAttribute("ReadyAt", 0)
		setStatus(lane, "READY")
	end

	request.OnServerEvent:Connect(onThrowRequest)
end

return ThrowService
