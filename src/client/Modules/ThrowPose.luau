-- The bowling throw animation, made in code (no uploaded animation needed): it bends the character's joints
-- on top of the normal idle animation. While you charge, the arm swings back as far as the meter is full;
-- letting go swings it down and through into a lunge, then relaxes. Numbers for timing live in Config.Throw.
-- The pose is seen on this screen only; LaneVisuals plays the release on other players' characters too.
-- The thrower's pose level (from rank level, Config.Throw.RankStyle) changes the throw: low levels throw stiff, wobbly and flailing (the SCUFFED poses),
-- every level is a bit cleaner, and from Config.Throw.PoseCleanLevel up it is clean and gets bigger each level.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local THROW = Config.Throw
local EXAGGERATE = THROW.PoseExaggeration or 1 -- cartoon-sized: every bend is this much bigger

local ThrowPose = {}

-- Joint angles in degrees (x = swing forward/back, y = twist, z = out to the side), oy = how far the hips drop
type Pose = { [string]: { x: number?, y: number?, z: number?, oy: number? } }

local JOINTS = { "Arm", "Elbow", "LeftArm", "Waist", "Root", "RightHip", "RightKnee", "LeftHip", "LeftKnee" }

local REST: Pose = {}
-- Meter empty: ball held in front, knees soft
local ADDRESS: Pose = {
	Arm = { x = 40 },
	Elbow = { x = 30 },
	LeftArm = { x = 25, z = -10 },
	Waist = { x = -10 },
	Root = { oy = -0.15 },
	RightHip = { x = 10 },
	RightKnee = { x = -15 },
	LeftHip = { x = 15 },
	LeftKnee = { x = -20 },
}
-- Meter full: arm swung all the way back, shoulders turned, crouched
local TOP: Pose = {
	Arm = { x = -115, z = 8 },
	LeftArm = { x = 45, z = -55 },
	Waist = { x = -22, y = -18 },
	Root = { oy = -0.3 },
	RightHip = { x = 5 },
	RightKnee = { x = -25 },
	LeftHip = { x = 30 },
	LeftKnee = { x = -35 },
}
-- The moment the ball leaves the hand: deep lunge, back leg out behind
local RELEASE: Pose = {
	Arm = { x = 15 },
	Elbow = { x = 5 },
	LeftArm = { x = 10, z = -75 },
	Waist = { x = -32, y = 8 },
	Root = { oy = -0.65 },
	RightHip = { x = -45 },
	RightKnee = { x = -20 },
	LeftHip = { x = 60 },
	LeftKnee = { x = -70 },
}
-- Follow-through: arm high in front, pointing at the pins
local FOLLOW: Pose = {
	Arm = { x = 155 },
	Elbow = { x = 25 },
	LeftArm = { x = 0, z = -80 },
	Waist = { x = -18, y = 18 },
	Root = { oy = -0.55 },
	RightHip = { x = -40 },
	RightKnee = { x = -25 },
	LeftHip = { x = 55 },
	LeftKnee = { x = -65 },
}

-- The same four moments, thrown badly (lowest level): stiff knees, chicken-wing arm, the free arm flailing
local SCUFFED_ADDRESS: Pose = {
	Arm = { x = 20 },
	Elbow = { x = 55 }, -- clutching the ball against the body
	LeftArm = { x = 5, z = -30 },
	Waist = { x = 5 }, -- leaning back
	Root = { oy = -0.02 },
	RightKnee = { x = -3 },
	LeftKnee = { x = -5 },
}
local SCUFFED_TOP: Pose = {
	Arm = { x = -55, z = 35 }, -- short backswing, elbow sticking out
	Elbow = { x = 70 },
	LeftArm = { x = 80, z = -20 },
	Waist = { x = 8, y = -35 }, -- over-twisted
	Root = { oy = -0.05 },
	RightKnee = { x = -5 },
	LeftHip = { x = 5 },
	LeftKnee = { x = -8 },
}
local SCUFFED_RELEASE: Pose = {
	Arm = { x = -10, z = 25 },
	Elbow = { x = 50 },
	LeftArm = { x = 120, z = -40 },
	Waist = { x = -5, y = 25 },
	Root = { oy = -0.15 },
	RightHip = { x = -10 },
	RightKnee = { x = -5 },
	LeftHip = { x = 20 },
	LeftKnee = { x = -15 },
}
local SCUFFED_FOLLOW: Pose = {
	Arm = { x = 70, z = 30 }, -- floppy follow-through
	Elbow = { x = 60 },
	LeftArm = { x = 150, z = -60 }, -- both arms up, off balance
	Waist = { x = 12, y = 30 }, -- falling back
	Root = { oy = -0.1 },
	RightHip = { x = 15 },
	RightKnee = { x = -40 }, -- one foot kicks up
	LeftHip = { x = 10 },
	LeftKnee = { x = -10 },
}

local function lerpPose(a: Pose, b: Pose, t: number): Pose
	local out = {}
	for _, joint in JOINTS do
		local from, to = a[joint] or {}, b[joint] or {}
		out[joint] = {
			x = (from.x or 0) + ((to.x or 0) - (from.x or 0)) * t,
			y = (from.y or 0) + ((to.y or 0) - (from.y or 0)) * t,
			z = (from.z or 0) + ((to.z or 0) - (from.z or 0)) * t,
			oy = (from.oy or 0) + ((to.oy or 0) - (from.oy or 0)) * t,
		}
	end
	return out
end

-- A joint is an old-style Motor6D or a newer AnimationConstraint. Both take the pose through Transform,
-- written right after Roblox's own animation each frame, so the pose adds on top of the idle animation.
type Joint = Motor6D | AnimationConstraint

-- The joint's resting offset inside its parent part (rotations are turned into this joint's own directions)
local function readC0(joint: Joint): CFrame?
	if joint:IsA("Motor6D") then
		return joint.C0
	end
	local attachment = (joint :: AnimationConstraint).Attachment0
	return attachment and attachment.CFrame
end

-- The joints of an R15 or R6 character (R6 has no knees, elbows or waist; its root joint bends instead)
local function findMotors(character: Model): { [string]: Joint }?
	local function motor(partName: string, name: string): Joint?
		local part = character:FindFirstChild(partName)
		local found = part and part:FindFirstChild(name)
		return if found and (found:IsA("Motor6D") or found:IsA("AnimationConstraint")) then found :: Joint else nil
	end
	local motors = {}
	if character:FindFirstChild("UpperTorso") then
		motors.Arm = motor("RightUpperArm", "RightShoulder")
		motors.Elbow = motor("RightLowerArm", "RightElbow")
		motors.LeftArm = motor("LeftUpperArm", "LeftShoulder")
		motors.Waist = motor("UpperTorso", "Waist")
		motors.Root = motor("LowerTorso", "Root")
		motors.RightHip = motor("RightUpperLeg", "RightHip")
		motors.RightKnee = motor("RightLowerLeg", "RightKnee")
		motors.LeftHip = motor("LeftUpperLeg", "LeftHip")
		motors.LeftKnee = motor("LeftLowerLeg", "LeftKnee")
	elseif character:FindFirstChild("Torso") then
		motors.Arm = motor("Torso", "Right Shoulder")
		motors.LeftArm = motor("Torso", "Left Shoulder")
		motors.Waist = motor("HumanoidRootPart", "RootJoint")
		motors.Root = motors.Waist
		motors.RightHip = motor("Torso", "Right Hip")
		motors.LeftHip = motor("Torso", "Left Hip")
	else
		return nil
	end
	return if motors.Arm then motors else nil
end

local baseC0: { [Joint]: CFrame } = setmetatable({}, { __mode = "k" }) :: any

type State = {
	Motors: { [string]: Joint },
	Current: Pose,
	Mode: string, -- Charge, Release, Rest
	Charge: number,
	From: Pose,
	Clock: number,
	Level: number,
	Seed: number, -- makes every scuffed throw wobble a little differently
	Wobble: number, -- seconds since the throw started, for the wobble
}
local states: { [Model]: State } = {}

-- What we wrote last frame and the animation underneath it, per joint: if the animation didn't
-- overwrite the joint this frame, reuse the old animation value instead of stacking the pose twice
local written: { [Joint]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
local animated: { [Joint]: CFrame } = setmetatable({}, { __mode = "k" }) :: any

-- Bends every joint: rotations are in the parent part's directions, around the joint
local function apply(state: State, pose: Pose, exaggerate: number)
	local offsets: { [Joint]: CFrame } = {}
	for joint, motor in state.Motors do
		local angles = pose[joint] or {} -- a joint the pose leaves out goes back to normal
		local x, y, z = (angles.x or 0) * exaggerate, (angles.y or 0) * exaggerate, (angles.z or 0) * exaggerate
		if joint == "Arm" then
			x = math.clamp(x, -150, 175) -- bigger, but the arm never swings through the head
		end
		local rotation = CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
		offsets[motor] = (offsets[motor] or CFrame.identity)
			* CFrame.new(0, (angles.oy or 0) * exaggerate, 0)
			* rotation
	end
	for motor, offset in offsets do
		local base = baseC0[motor]
		if base and motor.Parent then
			local anim = motor.Transform
			if written[motor] and anim == written[motor] then
				anim = animated[motor] or anim
			end
			animated[motor] = anim
			-- the offset is in the parent part's directions; Transform works in the joint's own directions
			local value = base.Rotation:Inverse() * offset * base.Rotation * anim
			motor.Transform = value
			written[motor] = value
		end
	end
end

local function getState(character: Model?): State?
	if not character then
		return nil
	end
	local state = states[character]
	if state and state.Motors.Arm.Parent then
		return state
	end
	local motors = findMotors(character)
	if not motors then
		return nil
	end
	for _, motor in motors do
		baseC0[motor] = baseC0[motor] or readC0(motor)
	end
	state = {
		Motors = motors,
		Current = REST,
		Mode = "Rest",
		Charge = 0,
		From = REST,
		Clock = 0,
		Level = #THROW.Levels,
		Seed = 0,
		Wobble = 0,
	}
	states[character] = state
	character.Destroying:Connect(function()
		states[character] = nil
	end)
	return state
end

local function ease(t: number): number
	return t * t * (3 - 2 * t)
end

-- How well a level throws: 0 = scuffed (level 1), 1 = clean (PoseCleanLevel and up)
local function skillOf(level: number): number
	return math.clamp((level - 1) / math.max(THROW.PoseCleanLevel - 1, 1), 0, 1)
end

-- Clean levels go bigger: every level above PoseCleanLevel adds PoseFlairPerLevel to the exaggeration
local function exaggerationOf(level: number): number
	return EXAGGERATE * (1 + math.max(level - THROW.PoseCleanLevel, 0) * THROW.PoseFlairPerLevel)
end

-- One moment of the throw at this level: the scuffed version blended into the clean one
local function at(scuffed: Pose, clean: Pose, level: number): Pose
	return lerpPose(scuffed, clean, skillOf(level))
end

local function startWobble(state: State)
	state.Seed = math.random() * 100
	state.Wobble = 0
end

-- While charging: call every frame with the meter (0-1) and the ball's level (1-12); the arm follows it
function ThrowPose.Charge(character: Model?, charge: number, level: number?)
	local state = getState(character)
	if state then
		if state.Mode ~= "Charge" then
			startWobble(state)
		end
		state.Mode = "Charge"
		state.Charge = charge
		state.Level = level or state.Level
	end
end

-- Let go: down-swing, release, follow-through, relax
function ThrowPose.Release(character: Model?, level: number?)
	local state = getState(character)
	if state then
		if state.Mode ~= "Charge" then
			startWobble(state) -- someone else's throw: we never saw them charge
		end
		state.Mode = "Release"
		state.From = state.Current
		state.Clock = 0
		state.Level = level or state.Level
	end
end

-- Back to standing normally (e.g. walked off the lane mid-charge)
function ThrowPose.Stop(character: Model?)
	local state = character and states[character]
	if state and state.Mode == "Charge" then
		state.Mode = "Release"
		state.From = state.Current
		-- skip straight to relaxing
		state.Clock = THROW.DownSwingTime + THROW.FollowThroughTime + THROW.PoseHoldTime
	end
end

-- True while the throw animation is still moving
function ThrowPose.IsBusy(character: Model?): boolean
	local state = character and states[character]
	return state ~= nil and state.Mode ~= "Rest"
end

-- Low levels shake: jittery arms, a twitchy waist and the whole body tipping side to side (a stumble)
local WOBBLE_JOINTS = { Arm = 1, Elbow = 0.6, LeftArm = 1.4, Waist = 0.7, Root = 0.35 }
local function wobble(state: State, pose: Pose): Pose
	local amount = THROW.PoseWobble * (1 - skillOf(state.Level))
	if amount <= 0 then
		return pose
	end
	local out = table.clone(pose)
	local t = state.Wobble * THROW.PoseWobbleSpeed
	local i = 0
	for joint, scale in WOBBLE_JOINTS do
		i += 1
		local angles = table.clone(out[joint] or {})
		local size = amount * scale
		angles.x = (angles.x or 0) + math.noise(t, state.Seed, i) * size * 2
		angles.y = (angles.y or 0) + math.noise(t, state.Seed, i + 10) * size * 2
		angles.z = (angles.z or 0) + math.noise(t, state.Seed, i + 20) * size * 2
		out[joint] = angles
	end
	return out
end

RunService.PreSimulation:Connect(function(dt)
	for character, state in states do
		local level = state.Level
		state.Wobble += dt
		if state.Mode == "Charge" then
			local target = lerpPose(at(SCUFFED_ADDRESS, ADDRESS, level), at(SCUFFED_TOP, TOP, level), ease(state.Charge))
			state.Current = lerpPose(state.Current, target, 1 - math.exp(-dt * 22))
		elseif state.Mode == "Release" then
			state.Clock += dt
			local t = state.Clock
			local down, follow, hold = THROW.DownSwingTime, THROW.FollowThroughTime, THROW.PoseHoldTime
			if t < down then
				-- Accelerates down like a pendulum
				local s = t / down
				state.Current = lerpPose(state.From, at(SCUFFED_RELEASE, RELEASE, level), s * s)
			elseif t < down + follow then
				local s = (t - down) / follow
				local follows = at(SCUFFED_FOLLOW, FOLLOW, level)
				state.Current = lerpPose(at(SCUFFED_RELEASE, RELEASE, level), follows, 1 - (1 - s) ^ 2)
			elseif t < down + follow + hold then
				state.Current = at(SCUFFED_FOLLOW, FOLLOW, level)
				state.From = state.Current
			else
				local s = math.min((t - down - follow - hold) / THROW.PoseRelaxTime, 1)
				state.Current = lerpPose(state.From, REST, ease(s))
				if s >= 1 then
					state.Mode = "Rest"
					state.Current = REST
				end
			end
		end
		apply(state, if state.Mode == "Rest" then state.Current else wobble(state, state.Current), exaggerationOf(level))
		if state.Mode == "Rest" then
			states[character] = nil
		end
	end
end)

return ThrowPose
