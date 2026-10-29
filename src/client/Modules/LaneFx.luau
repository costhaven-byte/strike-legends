-- 3D effects in the alley: lights that run along the lane with the ball, confetti, fireworks,
-- sparks on impact and "+coins" numbers popping out of the pins. Everything cleans itself up.
-- SETTINGS: EFFECTS off = no run lights, sparks, confetti or firework bursts (their sounds and the numbers stay).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Sfx = require(script.Parent.Sfx)
local Settings = require(script.Parent.Settings)

local SQUARE = "rbxasset://textures/particles/SquareParticle.png"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local NEON_COLORS = {
	Color3.fromRGB(255, 60, 210),
	Color3.fromRGB(60, 230, 255),
	Color3.fromRGB(255, 240, 90),
	Color3.fromRGB(120, 255, 120),
}

local LaneFx = {}

-- An invisible anchored point to hang effects on; removed after `life` seconds
local function anchor(position: Vector3, life: number): Part
	local part = Instance.new("Part")
	part.Name = "Fx"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.2
	part.Position = position
	part.Parent = Workspace
	task.delay(life, part.Destroy, part)
	return part
end

-- Where the confetti and fireworks go: above the pins, a little toward the bowler
local function abovePins(lane: Model, up: number): Vector3
	local pinSpot = lane:FindFirstChild("PinSpot") :: BasePart
	return pinSpot.Position + Vector3.new(0, up, 0) - pinSpot.CFrame.LookVector * 4
end

-- Two glowing runners on the lane's side strips that keep pace with the ball
function LaneFx.FollowLights(lane: Model, color: Color3)
	if not Settings.Get("Vfx") then
		return { Update = function() end, Destroy = function() end }
	end
	local runners = {}
	for _, strip in lane:GetChildren() do
		if strip.Name == "CapStrip" and strip:IsA("BasePart") then
			local runner = Instance.new("Part")
			runner.Name = "Runner"
			runner.Anchored = true
			runner.CanCollide = false
			runner.CanQuery = false
			runner.CanTouch = false
			runner.Material = Enum.Material.Neon
			runner.Color = color
			runner.Transparency = 0.45 -- 2026-10-26 owner: effects too bright (was a solid neon block, light 3)
			runner.Size = Vector3.new(strip.Size.X + 0.1, strip.Size.Y + 0.06, 5)
			local light = Instance.new("PointLight")
			light.Color = color
			light.Range = 8
			light.Brightness = 1.5 * Config.BallVfx.Dim
			light.Parent = runner
			runner.Parent = lane
			table.insert(runners, { Part = runner, Strip = strip })
		end
	end

	local handle = {}
	function handle.Update(position: Vector3)
		for _, runner in runners do
			local strip = runner.Strip :: BasePart
			local z = math.clamp(strip.CFrame:PointToObjectSpace(position).Z, -strip.Size.Z / 2, strip.Size.Z / 2)
			runner.Part.CFrame = strip.CFrame * CFrame.new(0, 0, z)
		end
	end
	function handle.Destroy()
		for _, runner in runners do
			local part = runner.Part
			TweenService:Create(part, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			TweenService:Create(part.PointLight, TweenInfo.new(0.3), { Brightness = 0 }):Play()
			task.delay(0.3, part.Destroy, part)
		end
	end
	return handle
end

-- Bright sparks bursting out where the ball hits
function LaneFx.Sparks(position: Vector3, amount: number)
	if not Settings.Get("Vfx") then
		return
	end
	local part = anchor(position + Vector3.new(0, 1, 0), 2)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 240, 160), Color3.fromRGB(255, 80, 200))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(0.8, 0)
	emitter.Lifetime = NumberRange.new(0.3, 0.6)
	emitter.Speed = NumberRange.new(15, 30)
	emitter.SpreadAngle = Vector2.new(70, 70)
	emitter.Drag = 4
	emitter.Enabled = false
	emitter.Parent = part
	emitter:Emit(amount)
end

-- Paper confetti shooting up over the pins
function LaneFx.Confetti(lane: Model, amount: number)
	if not Settings.Get("Vfx") then
		return
	end
	local part = anchor(abovePins(lane, 1), 4)
	for _, color in NEON_COLORS do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = SQUARE
		emitter.Color = ColorSequence.new(color)
		emitter.LightEmission = 0.4
		emitter.Size = NumberSequence.new(0.35)
		emitter.Lifetime = NumberRange.new(2, 3)
		emitter.Speed = NumberRange.new(18, 30)
		emitter.SpreadAngle = Vector2.new(35, 35)
		emitter.Acceleration = Vector3.new(0, -22, 0)
		emitter.Drag = 1.8
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-300, 300)
		emitter.Enabled = false
		emitter.Parent = part
		emitter:Emit(math.ceil(amount / #NEON_COLORS))
	end
end

-- Firework bursts in the air above the lane, one after another
function LaneFx.Fireworks(lane: Model, bursts: number)
	for i = 1, bursts do
		task.delay((i - 1) * 0.3, function()
			local offset = Vector3.new((math.random() - 0.5) * 8, math.random() * 3, (math.random() - 0.5) * 6)
			local part = anchor(abovePins(lane, 9) + offset, 2.5)
			local color = NEON_COLORS[math.random(#NEON_COLORS)]
			if not Settings.Get("Vfx") then
				Sfx.PlayAt("Firework", part, 0.9 + math.random() * 0.3)
				return
			end

			local emitter = Instance.new("ParticleEmitter")
			emitter.Texture = SPARKLE
			emitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
			emitter.LightEmission = 1
			emitter.Size = NumberSequence.new(0.9, 0)
			emitter.Lifetime = NumberRange.new(0.8, 1.3)
			emitter.Speed = NumberRange.new(14, 20)
			emitter.SpreadAngle = Vector2.new(180, 180)
			emitter.Drag = 2.5
			emitter.Acceleration = Vector3.new(0, -6, 0)
			emitter.Enabled = false
			emitter.Parent = part
			emitter:Emit(45)

			local light = Instance.new("PointLight")
			light.Color = color
			light.Range = 30
			light.Brightness = 5
			light.Parent = part
			TweenService:Create(light, TweenInfo.new(0.8), { Brightness = 0 }):Play()

			Sfx.PlayAt("Firework", part, 0.9 + math.random() * 0.3)
		end)
	end
end

-- "+12" floating up from a spot (a knocked pin)
function LaneFx.Number(position: Vector3, text: string, color: Color3)
	local part = anchor(position, 1.2)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(110, 36)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(40, 20, 0)
	stroke.Thickness = 2
	stroke.Parent = label

	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = label
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	TweenService:Create(gui, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0),
	}):Play()
	local fade = TweenInfo.new(0.4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0.7)
	TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
end

-- A burst effect (the Golden Pin uses it; ball traits have their own looks in TraitFx).
-- trait = { Fx, FxSize, Color, Sound, Pitch }; Fx picks the look:
-- Swirl (sparkles spinning off the ball), Ring (a shockwave across the lane),
-- Dome (a shield bubble over the pins), Burst (sparkles shooting up).
-- position: where it happens. ball: the rolling ball, for effects that ride along with it.
function LaneFx.Trait(trait, position: Vector3, ball: BasePart?)
	local color = trait.Color
	local holder: BasePart = if trait.Fx == "Swirl" and ball then ball else anchor(position, 2.5)

	if trait.Fx == "Ring" then
		local size = trait.FxSize or 16
		local ring = Instance.new("Part")
		ring.Name = "Shockwave"
		ring.Shape = Enum.PartType.Cylinder
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.Material = Enum.Material.Neon
		ring.Color = color
		ring.Transparency = 0.15
		ring.Size = Vector3.new(0.15, 2, 2)
		ring.CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Parent = holder
		local grow = TweenInfo.new(0.55, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		TweenService:Create(ring, grow, { Size = Vector3.new(0.15, size, size), Transparency = 1 }):Play()
	elseif trait.Fx == "Dome" then
		local dome = Instance.new("Part")
		dome.Name = "Shield"
		dome.Shape = Enum.PartType.Ball
		dome.Anchored = true
		dome.CanCollide = false
		dome.CanQuery = false
		dome.CanTouch = false
		dome.Material = Enum.Material.ForceField
		dome.Color = color
		dome.Size = Vector3.one * 3
		dome.Position = position
		dome.Parent = holder
		TweenService:Create(dome, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = Vector3.one * 14,
		}):Play()
		TweenService:Create(dome, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.2), {
			Transparency = 1,
		}):Play()
	end

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE
	emitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(if trait.Fx == "Swirl" then 0.6 else 1, 0)
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Enabled = false
	if trait.Fx == "Swirl" then
		emitter.Speed = NumberRange.new(4, 8)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.RotSpeed = NumberRange.new(-400, 400)
		emitter.Drag = 3
	elseif trait.Fx == "Burst" then
		emitter.Speed = NumberRange.new(12, 22)
		emitter.SpreadAngle = Vector2.new(30, 30)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Acceleration = Vector3.new(0, -15, 0)
	else
		emitter.Speed = NumberRange.new(8, 16)
		emitter.SpreadAngle = Vector2.new(80, 80)
		emitter.Drag = 2
	end
	emitter.Parent = holder
	emitter:Emit(if trait.Fx == "Swirl" then 30 else 40)
	task.delay(1.5, emitter.Destroy, emitter)

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 18
	light.Brightness = 4
	light.Parent = holder
	TweenService:Create(light, TweenInfo.new(0.7), { Brightness = 0 }):Play()
	task.delay(0.8, light.Destroy, light)

	if trait.Sound then
		Sfx.PlayAt(trait.Sound, holder, trait.Pitch)
	end
end

-- The Golden Pin going down: a gold shockwave, a shower of gold sparkles, fireworks and a big bang
function LaneFx.GoldenBurst(lane: Model, position: Vector3)
	local gold = Config.GoldenPin.Color
	LaneFx.Trait({ Fx = "Ring", FxSize = 34, Color = gold, Sound = "RevealBig", Pitch = 1 }, position)
	local part = anchor(position + Vector3.new(0, 1.5, 0), 3)
	if not Settings.Get("Vfx") then
		Sfx.PlayAt("Firework", part, 0.8)
		LaneFx.Fireworks(lane, 4)
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE
	emitter.Color = ColorSequence.new(gold, Color3.new(1, 1, 1))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(1.3, 0)
	emitter.Lifetime = NumberRange.new(0.8, 1.6)
	emitter.Speed = NumberRange.new(18, 34)
	emitter.SpreadAngle = Vector2.new(70, 70)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Acceleration = Vector3.new(0, -20, 0)
	emitter.Drag = 1.5
	emitter.Enabled = false
	emitter.Parent = part
	emitter:Emit(120)
	local light = Instance.new("PointLight")
	light.Color = gold
	light.Range = 40
	light.Brightness = 8
	light.Parent = part
	TweenService:Create(light, TweenInfo.new(1.5), { Brightness = 0 }):Play()
	Sfx.PlayAt("Firework", part, 0.8)
	LaneFx.Fireworks(lane, 4)
end

-- Glow of the colour of the current streak tier on each of the lane's light strips (0 = back to normal)
local streakState: { [Model]: any } = {}

local function lightParts(lane: Model): { BasePart }
	local parts = {}
	for _, part in lane:GetChildren() do
		if part:IsA("BasePart") and table.find({ "CapStrip", "HoodStrip", "FrameTop", "FrameBottom" }, part.Name) then
			table.insert(parts, part)
		end
	end
	return parts
end

function LaneFx.SetStreakTier(lane: Model, tier: number)
	local state = streakState[lane]
	if not state then
		state = { Parts = lightParts(lane), Colors = {}, Extras = {}, Pulses = {} }
		for _, part in state.Parts do
			state.Colors[part] = part.Color
		end
		streakState[lane] = state
	end

	for _, pulse in state.Pulses do
		pulse:Cancel()
	end
	table.clear(state.Pulses)
	for _, extra in state.Extras do
		extra:Destroy()
	end
	table.clear(state.Extras)

	local info = Config.Streaks[tier]
	for _, part in state.Parts do
		-- Layer 1 (Double and up): the strips switch to the streak colour
		local color = if info and tier >= 2 then info.Color else state.Colors[part]
		TweenService:Create(part, TweenInfo.new(0.4), { Color = color }):Play()
		if not info or tier < 2 then
			continue
		end

		-- Layer 2 (Turkey and up): sparkles rising off the strips, more for every tier
		if tier >= 3 and part.Name == "CapStrip" then
			local sparkles = Instance.new("ParticleEmitter")
			sparkles.Texture = SPARKLE
			sparkles.Color = ColorSequence.new(info.Color)
			sparkles.LightEmission = 1
			sparkles.Size = NumberSequence.new(0.5, 0)
			sparkles.Lifetime = NumberRange.new(0.8, 1.4)
			sparkles.Speed = NumberRange.new(2, 5)
			sparkles.SpreadAngle = Vector2.new(15, 15)
			sparkles.EmissionDirection = Enum.NormalId.Top
			sparkles.Rate = (tier - 2) * Config.Juice.StreakSparkleRate
			sparkles.Parent = part
			table.insert(state.Extras, sparkles)
		end

		-- Layer 3 (Hambone and up): the strips light up the lane around them
		if tier >= 4 and part.Name ~= "FrameBottom" then
			local light = Instance.new("SurfaceLight")
			light.Face = if part.Name == "CapStrip" then Enum.NormalId.Top else Enum.NormalId.Bottom
			light.Color = info.Color
			light.Brightness = 0.6 + (tier - 4) * 0.4
			light.Range = 10
			light.Angle = 150
			light.Parent = part
			table.insert(state.Extras, light)
		end

		-- Layer 4 (Wild Turkey and up): the strips pulse, faster for higher tiers
		if tier >= 5 then
			local speed = 0.5 - (tier - 5) * 0.12
			local pulse = TweenService:Create(
				part,
				TweenInfo.new(speed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, 0.4),
				{ Color = info.Color:Lerp(Color3.new(1, 1, 1), 0.6) }
			)
			pulse:Play()
			table.insert(state.Pulses, pulse)
		end
	end
end

return LaneFx
