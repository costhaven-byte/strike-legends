-- Draws every player's equipped mascots following them around, bobbing in the air behind them.
-- Each client draws them itself from the EquippedMascots Player attribute (the server sets it), so movement is
-- smooth and costs the server nothing. Players further than Config.MascotFx.ShowDistance away aren't drawn.
-- Step 8b: when a player strikes, their mascots dash down to the gutter edges in front of the pins (where the
-- thrower's camera is looking), celebrate one after another (Hop, Spin, Flip or Wiggle, from each mascot's
-- Reaction in Config.Mascots; Shiny ones also burst gold sparkles), then fly back as the camera returns.
-- Real pet models (2026-10-21) play their design's idle pose (Shared.Config.PetIdle, Modules.PetIdle): walkers stay on
-- the ground, floaters (Floats) hover at Config.MascotFx.Hover.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Mascots = require(Shared.Modules.Mascots)
local MascotView = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("MascotView"))
local PetIdle = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("PetIdle"))

local FX = Config.MascotFx
local IDLE = Config.PetIdle
local PER_ROW = 3

local MascotFollowController = {}

type Pet = {
	Model: Model,
	Id: string,
	Rig: PetIdle.Rig?,
	Position: Vector3?,
	Phase: number,
	ReactAt: number?,
	ReactsLeft: number?,
}
local pets: { [Player]: { Pet } } = {}
-- A strike cheer in progress: where each mascot stands (by index) and when it starts and ends (os.clock)
type Cheer = { From: number, Until: number, Spots: { CFrame } }
local cheers: { [Player]: Cheer } = {}
local folder: Folder

local function clear(player: Player)
	for _, pet in pets[player] or {} do
		pet.Model:Destroy()
	end
	pets[player] = nil
	cheers[player] = nil
end

-- Rebuilds a player's mascots when their equipped list changes (keeps the ones that didn't change)
local function refresh(player: Player)
	local ids = Mascots.DecodeEquipped(player:GetAttribute("EquippedMascots"))
	local old = pets[player] or {}
	local list: { Pet } = {}
	for index, id in ids do
		local mascot = Mascots.Get(id)
		if mascot then
			local reuse = old[index]
			if reuse and reuse.Id == id then
				old[index] = nil
				table.insert(list, reuse)
			else
				local model = MascotView.Mascot(mascot, FX.Size)
				model.Name = player.Name .. "_" .. id
				local rig = PetIdle.Rig(model, (mascot.Base or mascot).Id, 1)
				model.Parent = folder
				table.insert(list, { Model = model, Id = id, Rig = rig, Position = nil, Phase = index * 1.7 })
			end
		end
	end
	for _, pet in old do
		pet.Model:Destroy()
	end
	pets[player] = list
end

-- Starts every mascot of this player celebrating, `delay` seconds from now
local function react(player: Player, delay: number)
	local now = os.clock()
	for index, pet in pets[player] or {} do
		local startAt = now + delay + (index - 1) * FX.ReactStagger
		pet.ReactAt = startAt
		pet.ReactsLeft = FX.ReactRepeats
		local mascot = Mascots.Get(pet.Id)
		if mascot and mascot.Shiny then
			task.delay(startAt - now, function()
				local shimmer = pet.Model.Parent and pet.Model:FindFirstChild("Shimmer", true) :: ParticleEmitter?
				if shimmer then
					shimmer:Emit(20)
				end
			end)
		end
	end
end

-- Where a reaction has the mascot `p` of the way through it (0 to 1): lift in studs, and a turn
local function reactionPose(reaction: string?, p: number): (number, CFrame)
	local arc = math.sin(math.pi * p)
	if reaction == "Spin" then
		local eased = 1 - (1 - p) ^ 3
		return arc * FX.ReactHeight * 0.5, CFrame.Angles(0, eased * math.pi * 2, 0)
	elseif reaction == "Flip" then
		return arc * FX.ReactHeight * 0.8, CFrame.Angles(-p * math.pi * 2, 0, 0)
	elseif reaction == "Wiggle" then
		return arc * FX.ReactHeight * 0.3, CFrame.Angles(0, 0, math.sin(p * math.pi * 6) * math.rad(28) * (1 - p))
	end
	-- Hop (and anything unknown): straight up with a happy squash at the top
	return arc * FX.ReactHeight, CFrame.Angles(math.rad(-15) * arc, 0, 0)
end

-- Where each mascot stands while cheering: on the gutter edges in front of the pins, both sides in turn,
-- facing back up the lane (towards the thrower's camera)
local function cheerSpots(lane: Instance, count: number): { CFrame }?
	local pinSpot = lane:FindFirstChild("PinSpot") :: BasePart?
	local ballStart = lane:FindFirstChild("BallStart") :: BasePart?
	if not pinSpot or not ballStart then
		return nil
	end
	local along = (pinSpot.Position - ballStart.Position) * Vector3.new(1, 0, 1)
	if along.Magnitude < 1 then
		return nil
	end
	local forward = along.Unit
	local right = forward:Cross(Vector3.yAxis)
	local spots = {}
	for index = 1, count do
		local side = if index % 2 == 1 then 1 else -1
		local back = FX.CheerBeforePins + math.floor((index - 1) / 2) * FX.Spacing
		local position = pinSpot.Position
			- forward * back
			+ right * side * FX.CheerSide
			+ Vector3.yAxis * FX.CheerHeight
		table.insert(spots, CFrame.lookAt(position, position - forward))
	end
	return spots
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("EquippedMascots"):Connect(function()
		refresh(player)
	end)
	refresh(player)
end

-- Where mascot number `index` (of `count`) sits behind the player: rows of 3, fanned out sideways
local function slotOffset(index: number, count: number): Vector3
	local row = math.floor((index - 1) / PER_ROW)
	local inRow = math.min(PER_ROW, count - row * PER_ROW)
	local column = (index - 1) % PER_ROW
	local x = (column - (inRow - 1) / 2) * FX.Spacing
	return Vector3.new(x, 0, FX.FollowDistance + row * FX.Spacing)
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	local now = os.clock()
	local alpha = 1 - math.exp(-FX.FollowSpeed * dt)
	for player, list in pets do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local far = not root or (camera and (root.Position - camera.CFrame.Position).Magnitude > FX.ShowDistance)
		for index, pet in list do
			if far then
				if pet.Model.Parent then
					pet.Model.Parent = nil
				end
				pet.Position = nil
				continue
			end
			local rootPart = root :: BasePart
			-- Flat facing, so mascots stay level when the player jumps or tilts
			local look = rootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
			look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
			local target: Vector3
			local cheer = cheers[player]
			local spot = cheer and now >= cheer.From and now < cheer.Until and cheer.Spots[index]
			if spot then
				-- Cheering by the pins
				target = spot.Position
				look = spot.LookVector
			else
				local basis = CFrame.lookAt(rootPart.Position, rootPart.Position + look)
				local ground = rootPart.Position.Y - rootPart.Size.Y / 2 - (humanoid and humanoid.HipHeight or 2)
				local offset = slotOffset(index, #list)
				target = (basis * CFrame.new(offset)).Position
				-- Real pets: walkers stand on the ground, floaters hover (never low enough to touch it)
				local rig = pet.Rig
				local height = if not rig
					then FX.Hover
					elseif rig.Floats then math.max(FX.Hover, rig.HalfHeight + 0.3)
					else rig.HalfHeight
				target = Vector3.new(target.X, ground + height, target.Z)
			end
			local position = if pet.Position then pet.Position:Lerp(target, alpha) else target
			pet.Position = position
			local bob, turn = 0, CFrame.identity
			local rig = pet.Rig
			if rig then
				bob, turn = rig:Body(now)
				local near = camera and (position - camera.CFrame.Position).Magnitude <= IDLE.ShowDistance
				rig:Step(now, near == true)
			else
				bob = math.sin((now + pet.Phase) * FX.BobSpeed * math.pi * 2) * FX.BobHeight
			end
			local reactAt = pet.ReactAt
			if reactAt and now >= reactAt then
				local p = (now - reactAt) / FX.ReactTime
				if p >= 1 then
					-- Again (Config.MascotFx.ReactRepeats times in all), after a short breath
					pet.ReactsLeft = (pet.ReactsLeft or 1) - 1
					pet.ReactAt = if pet.ReactsLeft > 0 then now + 0.15 else nil
				else
					local mascot = Mascots.Get(pet.Id)
					local lift, pose = reactionPose(mascot and mascot.Reaction, p)
					bob += lift
					turn *= pose
				end
			end
			local at = position + Vector3.new(0, bob, 0)
			local placed = CFrame.lookAt(at, at + look) * turn
			if rig then
				-- The rest of the pet is welded to its Root
				rig.Root.CFrame = placed
			else
				pet.Model:PivotTo(placed)
			end
			if not pet.Model.Parent then
				pet.Model.Parent = folder
			end
		end
	end
end

function MascotFollowController:Start()
	folder = Instance.new("Folder")
	folder.Name = "Mascots"
	folder.Parent = Workspace

	for _, player in Players:GetPlayers() do
		task.spawn(watch, player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)
	RunService.RenderStepped:Connect(step)

	-- Strikes (anyone's): their mascots celebrate as the pins fly
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes:WaitForChild("ThrowResult").OnClientEvent:Connect(function(data)
		if type(data) ~= "table" or (data.Tier ~= "Strike" and data.Tier ~= "PerfectStrike") then
			return
		end
		local thrower = Players:GetPlayerByUserId(data.UserId)
		local list = thrower and pets[thrower]
		if not thrower or not list or #list == 0 then
			return
		end
		local now = os.clock()
		local rollTime = data.RollTime or 0
		local spots = typeof(data.Lane) == "Instance" and cheerSpots(data.Lane, #list)
		if spots then
			-- Dash down as the ball arrives; fly back as the pins reset (the camera comes back then too)
			cheers[thrower] = {
				From = now + math.max(0, rollTime - FX.CheerLead),
				Until = now + rollTime + (data.ResetDelay or 1.5) - 0.2,
				Spots = spots,
			}
		end
		react(thrower, rollTime + FX.ReactDelay)
	end)
end

return MascotFollowController
