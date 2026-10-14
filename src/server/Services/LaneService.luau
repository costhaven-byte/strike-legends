-- Gives each player their own lane when they join and puts them on it every time they spawn.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LaneUtil = require(Shared.Modules.LaneUtil)

local LaneService = {}

local function setSign(lane: Model, ownerName: string?)
	local sign = lane:FindFirstChild("OwnerSign")
	local label = sign and sign:FindFirstChild("Owner", true)
	if label then
		local number = lane.Name:match("%d+") or "?"
		label.Text = ("LANE %s · %s"):format(number, ownerName or "OPEN")
	end
end

-- Stand the character on the approach, facing the pins.
local function placeOnLane(character: Model, lane: Model)
	local approach = lane:FindFirstChild("Approach") :: BasePart?
	if not approach then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local height = if humanoid then humanoid.HipHeight + 2 else 3
	character:PivotTo(approach.CFrame * CFrame.new(0, approach.Size.Y / 2 + height, 0))
end

local function assignLane(player: Player): Model?
	for _, lane in LaneUtil.GetLanes() do
		if lane:GetAttribute("OwnerId") == nil then
			lane:SetAttribute("OwnerId", player.UserId)
			setSign(lane, player.DisplayName)
			return lane
		end
	end
	return nil -- alley is full; the player can still walk around and watch
end

local function onPlayerAdded(player: Player)
	local lane = assignLane(player)

	local function onCharacter(character: Model)
		if lane then
			-- Wait a moment so Roblox finishes spawning before we move the character
			task.spawn(function()
				character:WaitForChild("HumanoidRootPart", 5)
				task.wait(0.1)
				placeOnLane(character, lane)
			end)
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	local lane = LaneUtil.GetOwnedLane(player.UserId)
	if lane then
		lane:SetAttribute("OwnerId", nil)
		setSign(lane, nil)
	end
end

function LaneService:Start()
	for _, lane in LaneUtil.GetLanes() do
		lane:SetAttribute("OwnerId", nil)
		setSign(lane, nil)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return LaneService
