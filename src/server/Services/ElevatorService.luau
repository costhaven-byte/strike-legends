-- The elevators between Main Street Lanes and the Skyline Lanes roof (owner 2026-10-22, Config.Elevators).
-- The cars are built on each screen (ElevatorController); a ride asks the server, which checks you have the
-- zone open and stand by that car's doors, tells your screen to play the ride, and moves you while it's dark.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Zones = require(Shared.Modules.Zones)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RateLimit = require(script.Parent.Parent.Modules.RateLimit)

local ELEVATORS = Config.Elevators

local ElevatorService = {}

local riding: { [Player]: boolean } = {}

local function carById(id: string)
	for _, car in ELEVATORS.Cars do
		if car.Id == id then
			return car
		end
	end
	return nil
end

local function nearDoor(player: Player, car): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local offset = root.Position - car.Door.Position
	return math.abs(offset.Y) < 12 and (offset * Vector3.new(1, 0, 1)).Magnitude <= ELEVATORS.UseRange
end

local function ride(remote: RemoteEvent, player: Player, carId: any)
	if typeof(carId) ~= "string" or riding[player] or not PlayerDataService.IsLoaded(player) then
		return
	end
	if Config.CoreLoop.Enabled then
		return -- (Addendum 4 core loop: the rooftop is the only zone, the elevator is switched off)
	end
	if not RateLimit.Allow(player, "RideElevator") then
		return
	end
	local car = carById(carId)
	local target = car and carById(car.To)
	if not (car and target) or not nearDoor(player, car) then
		return
	end
	if not Zones.Unlocked(PlayerDataService.Get(player, "ZonesOpen"), ELEVATORS.Zone) then
		return
	end
	riding[player] = true
	remote:FireClient(player, car.Id, target.Id)
	task.wait(ELEVATORS.RideSeconds / 2)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if character and root and player.Parent then
		local spot = target.Arrive
		character:PivotTo(CFrame.lookAt(spot, spot + target.Door.LookVector))
		root.AssemblyLinearVelocity = Vector3.zero
	end
	riding[player] = nil
end

function ElevatorService:Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local remote = Instance.new("RemoteEvent")
	remote.Name = "RideElevator"
	remote.OnServerEvent:Connect(function(player, carId)
		ride(remote, player, carId)
	end)
	remote.Parent = remotes

	Players.PlayerRemoving:Connect(function(player)
		riding[player] = nil
	end)
end

return ElevatorService
