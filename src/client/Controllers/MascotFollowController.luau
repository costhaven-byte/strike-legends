-- Draws every player's equipped mascots following them around, bobbing in the air behind them.
-- Each client draws them itself from the EquippedMascots Player attribute (the server sets it), so movement is
-- smooth and costs the server nothing. Players further than Config.MascotFx.ShowDistance away aren't drawn.
-- Step 8b: when a player strikes, their mascots dash down to the gutter edges in front of the pins (where the
-- thrower's camera is looking), celebrate one after another (Hop, Spin, Flip or Wiggle, from each mascot's
-- Reaction in Config.Mascots; Shiny ones also burst gold sparkles), then fly back as the camera returns.
-- Real pet models (2026-10-21) play their design's idle pose (Shared.Config.PetIdle, Modules.PetIdle): walkers stay on
-- the ground, floaters (Floats) hover at Config.MascotFx.Hover.
-- Polish v2 D4 (Config.PetMotion): pets follow on a spring (lag, a small overshoot when you stop), face where they go,
-- lean into turns, flyers dip their nose, walkers hop as they move; they watch the lane while your ball rolls, cheer
-- on a LUCKY hit, doze when you stand still for a while (z z z), and a new pet hops out of you.
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
local MOTION = Config.PetMotion
local PER_ROW = 3

local MascotFollowController = {}

type Pet = {
	Model: Model,
	Id: string,
	Rig: PetIdle.Rig?,
	Position: Vector3?,
	Velocity: Vector3,
	Yaw: number?,
	Bank: number,
	Hop: number,
	HopAmp: number,
	Zs: BillboardGui?,
	Air: number?, -- upward speed while hopping out of you (studs/second), nil once landed
	AirY: number,
	Phase: number,
	ReactAt: number?,
	ReactsLeft: number?,
}
local pets: { [Player]: { Pet } } = {}
-- What each owner is doing: last time they moved or threw, and the lane spot their pets watch while a ball rolls
type Owner = { Active: number, LookAt: Vector3?, LookUntil: number, Sleep: number }
local owners: { [Player]: Owner } = {}
local built: { [Player]: boolean } = {}
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
	owners[player] = nil
	built[player] = nil
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
				MascotView.Soften(model)
				model.Name = player.Name .. "_" .. id
				local rig = PetIdle.Rig(model, (mascot.Base or mascot).Model or (mascot.Base or mascot).Id, 1)
				model.Parent = folder
				local pet: Pet = {
					Model = model,
					Id = id,
					Rig = rig,
					Position = nil,
					Velocity = Vector3.zero,
					Bank = 0,
					Hop = 0,
					HopAmp = 0,
					AirY = 0,
					Phase = index * 1.7,
				}
				-- (Polish v2 D4) a pet equipped now (not the ones you joined with) hops out of you
				local root = built[player] and player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					pet.Position = root.Position
					pet.Air = MOTION.EquipKick
				end
				table.insert(list, pet)
			end
		end
	end
	for _, pet in old do
		pet.Model:Destroy()
	end
	pets[player] = list
	built[player] = true
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
	return PetIdle.ReactionPose(reaction, p, FX.ReactHeight)
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

-- A small "z" floating up over a dozing pet (made the first time it dozes, lives in the pet's model)
local function zsOf(pet: Pet): BillboardGui?
	local zs = pet.Zs
	if zs and zs.Parent then
		return zs
	end
	local rig = pet.Rig
	local adornee = (if rig then rig.Root else pet.Model.PrimaryPart) :: BasePart?
	if not adornee then
		return nil
	end
	local board = Instance.new("BillboardGui")
	board.Name = "Zs"
	board.Size = UDim2.fromOffset(40, 40)
	board.LightInfluence = 0
	board.MaxDistance = 60
	board.Adornee = adornee
	board.Enabled = false
	local label = Instance.new("TextLabel")
	label.Name = "Z"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "z"
	label.TextScaled = true
	label.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.fromRGB(16, 23, 46)
	label.TextStrokeTransparency = 0
	label.Parent = board
	board.Parent = pet.Model
	pet.Zs = board
	return board
end

-- Wraps an angle into -pi..pi
local function wrap(angle: number): number
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

local function step(dt: number)
	dt = math.min(dt, 0.1)
	local camera = Workspace.CurrentCamera
	local now = os.clock()
	local alpha = 1 - math.exp(-FX.FollowSpeed * dt)
	local w = 2 * math.pi * MOTION.Freq
	local springSteps = math.max(1, math.ceil(dt * 120))
	local h = dt / springSteps
	local faceAlpha = 1 - math.exp(-MOTION.Face * dt)
	local leanAlpha = 1 - math.exp(-8 * dt)
	for player, list in pets do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local far = not root or (camera and (root.Position - camera.CFrame.Position).Magnitude > FX.ShowDistance)
		local owner = owners[player]
		if not owner then
			owner = { Active = now, LookUntil = 0, Sleep = 0 }
			owners[player] = owner
		end
		if root and (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude > 0.5 then
			owner.Active = now
		end
		local dozing = now - owner.Active > MOTION.SleepAfter
		owner.Sleep = math.clamp(owner.Sleep + (if dozing then dt / 1.5 else -dt / 0.3), 0, 1)
		local sleep = owner.Sleep
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
			local rig = pet.Rig
			local floats = not rig or rig.Floats
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
				local height = if not rig
					then FX.Hover
					elseif rig.Floats then math.max(FX.Hover, rig.HalfHeight + 0.3)
					else rig.HalfHeight
				if floats then
					height -= MOTION.SleepSink * sleep
				end
				target = Vector3.new(target.X, ground + height, target.Z)
				-- (while your ball rolls they watch the lane)
				local lookAt = owner.LookAt
				if lookAt and now < owner.LookUntil then
					local toward = (lookAt - target) * Vector3.new(1, 0, 1)
					if toward.Magnitude > 1 then
						look = toward.Unit
					end
				end
			end
			-- Polish v2 D4: a spring towards the spot (up/down without overshoot, so walkers never sink into the floor)
			local position = pet.Position
			local velocity = pet.Velocity
			if position and pet.Air and pet.AirY == 0 and not spot then
				-- (just equipped: it starts at your middle; the follow keeps its own height and the hop carries the rest)
				pet.AirY = math.max(0, position.Y - target.Y)
				position = Vector3.new(position.X, target.Y, position.Z)
			end
			if not position or (target - position).Magnitude > MOTION.Snap or spot then
				if position and spot then
					position = position:Lerp(target, alpha)
				else
					position = target
				end
				velocity = Vector3.zero
			else
				local x, v = position, velocity
				for _ = 1, springSteps do
					local pull = target - x
					local accel = Vector3.new(
						pull.X * w * w - v.X * 2 * MOTION.Damp * w,
						pull.Y * w * w - v.Y * 2 * w,
						pull.Z * w * w - v.Z * 2 * MOTION.Damp * w
					)
					v += accel * h
					x += v * h
				end
				position, velocity = x, v
			end
			pet.Position = position
			pet.Velocity = velocity

			-- Face where it's going when it moves; otherwise the way you (or the lane) face
			local flat = velocity * Vector3.new(1, 0, 1)
			local speed = flat.Magnitude
			local want = if speed > 1.5 and not spot then flat.Unit else look
			local wantYaw = math.atan2(-want.X, -want.Z)
			local yaw = pet.Yaw or wantYaw
			local turn = wrap(wantYaw - yaw) * faceAlpha
			yaw = wrap(yaw + turn)
			pet.Yaw = yaw
			-- lean into the turn (walkers half as much), flyers dip their nose with speed
			local yawRate = math.deg(turn) / math.max(dt, 1 / 240)
			local maxBank = if floats then MOTION.MaxBank else MOTION.MaxBank / 2
			local bankTarget = math.clamp(yawRate * MOTION.Bank, -maxBank, maxBank)
			pet.Bank += (bankTarget - pet.Bank) * leanAlpha
			local pitch = if floats then -math.min(speed * MOTION.Pitch, MOTION.MaxPitch) else 0
			-- walkers hop along while they move
			local hop = 0
			if not floats then
				pet.HopAmp += ((if speed > 1 then 1 else 0) - pet.HopAmp) * leanAlpha
				pet.Hop += speed * MOTION.HopRate * dt
				hop = math.abs(math.sin(pet.Hop * math.pi)) * MOTION.Hop * pet.HopAmp
			end

			local bob, idleTurn = 0, CFrame.identity
			if rig then
				bob, idleTurn = rig:Body(now)
			else
				bob = math.sin((now + pet.Phase) * FX.BobSpeed * math.pi * 2) * FX.BobHeight
			end
			bob *= 1 - 0.7 * sleep
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
					idleTurn *= pose
				end
			end
			-- (hopping out of you on equip: up and back down under gravity, on top of the follow)
			local air = pet.Air
			if air then
				pet.AirY += air * dt
				pet.Air = air - MOTION.EquipGravity * dt
				if pet.AirY <= 0 and air < 0 then
					pet.AirY, pet.Air = 0, nil
				end
			end
			local at = position + Vector3.new(0, bob + hop + pet.AirY, 0)
			local placed = CFrame.new(at)
				* CFrame.Angles(0, yaw, 0)
				* CFrame.Angles(math.rad(pitch), 0, math.rad(pet.Bank + MOTION.SleepTilt * sleep))
				* idleTurn
			local near = camera ~= nil and (position - camera.CFrame.Position).Magnitude <= IDLE.ShowDistance
			if rig then
				-- Moves the whole pet and plays its idle pose (only near your camera; a dozing pet keeps still)
				rig:Step(now, near and sleep < 0.6, placed)
			else
				pet.Model:PivotTo(placed)
			end
			if not pet.Model.Parent then
				pet.Model.Parent = folder
			end
			-- z z z over a dozing pet
			local zs = if sleep > 0.5 and near then zsOf(pet) else pet.Zs
			if zs then
				zs.Enabled = sleep > 0.5 and near
				if zs.Enabled then
					local p = ((now + pet.Phase) / MOTION.SleepZ) % 1
					zs.StudsOffset = Vector3.new(0.4 + p * 0.6, 1.2 + p * 1.6, 0)
					zs.Size = UDim2.fromOffset(16 + p * 22, 16 + p * 22)
					local label = zs:FindFirstChild("Z") :: TextLabel?
					if label then
						local fade = math.max(0, (p - 0.6) / 0.4)
						label.TextTransparency = fade
						label.TextStrokeTransparency = fade
					end
				end
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
		if type(data) ~= "table" then
			return
		end
		local thrower = Players:GetPlayerByUserId(data.UserId)
		local list = thrower and pets[thrower]
		if not thrower or not list or #list == 0 then
			return
		end
		local now = os.clock()
		local rollTime = data.RollTime or 0
		-- (Polish v2 D4) every throw: the pets watch the ball down the lane and stay awake
		local owner = owners[thrower]
		if owner then
			owner.Active = now
			local pinSpot = typeof(data.Lane) == "Instance" and data.Lane:FindFirstChild("PinSpot") :: BasePart?
			if pinSpot then
				owner.LookAt = pinSpot.Position
				owner.LookUntil = now + rollTime + MOTION.LookPins
			end
		end
		-- the core loop has no strikes: a LUCKY hit gets the cheer, right where the pets are
		if data.Core then
			if data.Lucky then
				react(thrower, rollTime + FX.ReactDelay)
			end
			return
		end
		if data.Tier ~= "Strike" and data.Tier ~= "PerfectStrike" then
			return
		end
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
