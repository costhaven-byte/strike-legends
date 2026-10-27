-- Gives each player their own Back Alley lane when they join and puts them on it every time they spawn.
-- Later zones (Config.Zones.Gated): locked players get walked back out; unlocked players claim an OPEN lane by
-- stepping onto it and keep it until they leave the zone.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LaneUtil = require(Shared.Modules.LaneUtil)
local Zones = require(Shared.Modules.Zones)
local Config = require(Shared.Config)
local PlayerDataService = require(script.Parent.PlayerDataService)

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
		if lane.Parent.Name == Config.Zones.AssignFolder and lane:GetAttribute("OwnerId") == nil then
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

local function release(lane: Model)
	lane:SetAttribute("OwnerId", nil)
	setSign(lane, nil)
end

local function onPlayerRemoving(player: Player)
	for _, lane in LaneUtil.GetLanes() do
		if lane:GetAttribute("OwnerId") == player.UserId then
			release(lane)
		end
	end
end

-- The lane this player claimed inside a gated zone, if any
local function claimedIn(gate, userId: number): Model?
	local folder = workspace:FindFirstChild(gate.Folder)
	if not folder then
		return nil
	end
	for _, lane in folder:GetChildren() do
		if lane:IsA("Model") and lane:GetAttribute("OwnerId") == userId then
			return lane
		end
	end
	return nil
end

local outsideSince: { [Player]: { [number]: number } } = {}

-- One look at where everyone stands: keep locked players out, hand out lanes, free lanes of players who left
local function checkGates()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local zonesOpen = PlayerDataService.Get(player, "ZonesOpen")
		local away = outsideSince[player] or {}
		outsideSince[player] = away
		for index, gate in Config.Zones.Gated do
			local inside = root ~= nil and Zones.InArea(gate.Area, root.Position)
			local claimed = claimedIn(gate, player.UserId)
			if inside and not Zones.Unlocked(zonesOpen, gate.Zone) then
				-- The wall on their screen should stop them; this catches anyone who got past it
				(player.Character :: Model):PivotTo(CFrame.new(gate.KickTo))
			elseif inside then
				away[index] = nil
				if not claimed then
					local lane = LaneUtil.GetLaneAt(root.Position)
					if lane and lane.Parent.Name == gate.Folder and lane:GetAttribute("OwnerId") == nil then
						lane:SetAttribute("OwnerId", player.UserId)
						setSign(lane, player.DisplayName)
					end
				end
			elseif claimed then
				away[index] = away[index] or now
				if now - away[index] >= gate.LeaveGrace then
					away[index] = nil
					release(claimed)
				end
			end
		end
	end
end

function LaneService:Start()
	for _, lane in LaneUtil.GetLanes() do
		lane:SetAttribute("OwnerId", nil)
		setSign(lane, nil)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		outsideSince[player] = nil
		onPlayerRemoving(player)
	end)
	-- The client showed the "ZONE UNLOCKED" window for this zone: don't show it again
	local zoneSeen = Instance.new("RemoteEvent")
	zoneSeen.Name = "ZoneSeen"
	zoneSeen.Parent = ReplicatedStorage:WaitForChild("Remotes")
	zoneSeen.OnServerEvent:Connect(function(player, zone)
		if not PlayerDataService.IsLoaded(player) or type(zone) ~= "number" then
			return
		end
		local highest = Zones.Highest(PlayerDataService.Get(player, "ZonesOpen"))
		local seen = PlayerDataService.Get(player, "ZoneSeen") or 1
		zone = math.clamp(math.floor(zone), 1, highest)
		if zone > seen then
			PlayerDataService.Set(player, "ZoneSeen", zone)
		end
	end)

	-- Studio only: the Day 1 video intro (Config.IntroCinematic) moves you onto its Back Alley lane and makes your
	-- next throw an assisted PERFECT (ThrowService reads IntroAssist); false switches the assist off again
	local intro = Config.IntroCinematic
	if RunService:IsStudio() and intro and intro.Enabled then
		local introRemote = Instance.new("RemoteEvent")
		introRemote.Name = "IntroCinematic"
		introRemote.Parent = ReplicatedStorage:WaitForChild("Remotes")
		introRemote.OnServerEvent:Connect(function(player, on)
			player:SetAttribute("IntroAssist", if on == true then true else nil)
			local alley = workspace:FindFirstChild(Config.Zones.AssignFolder)
			local lane = alley and alley:FindFirstChild(intro.Lane)
			local owner = lane and lane:GetAttribute("OwnerId")
			if on ~= true or not lane or not player.Character or (owner and owner ~= player.UserId) then
				return
			end
			for _, other in alley:GetChildren() do
				if other ~= lane and other:IsA("Model") and other:GetAttribute("OwnerId") == player.UserId then
					release(other)
				end
			end
			lane:SetAttribute("OwnerId", player.UserId)
			setSign(lane, player.DisplayName)
			placeOnLane(player.Character, lane)
		end)
	end

	task.spawn(function()
		while true do
			task.wait(Config.Zones.ClaimCheck)
			checkGates()
		end
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return LaneService
