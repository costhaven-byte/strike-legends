-- The ball showcase in the lobby ("The Vault"): a glowing display case for every ball of
-- Config.Showcase.MinRarity or better, built from Config.Balls on the slots in Workspace.Showcase.Slots.
-- Each case spins the ball with its trails and trait sparkles, and its sign says LOCKED or OWNED for you.
-- Built on each player's own screen, so the animation costs the server nothing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)

local SHOW = Config.Showcase
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FONT = "rbxasset://fonts/families/GothamSSm.json"
local DARK = Color3.fromRGB(28, 18, 48)
local LOCKED_COLOR = Color3.fromRGB(255, 90, 110)
local OWNED_COLOR = Color3.fromRGB(90, 230, 110)

local PEDESTAL = Vector3.new(5, 3.2, 5)
local GLASS = Vector3.new(4.4, 5, 4.4)
local BALL_SIZE = 2.4
local ORBIT_RADIUS = 1.75 -- studs from the ball centre

local player = Players.LocalPlayer

local ShowcaseController = {}

local function part(props: { [string]: any }, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.FontFace = Font.new(FONT, Enum.FontWeight.Bold)
	for key, value in props do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

-- One display case. Returns what the animation loop and the LOCKED/OWNED sign need.
local function buildCase(slot: BasePart, ball, parent: Instance)
	local rarity = Balls.GetRarity(ball.Rarity)
	local base = slot.CFrame * CFrame.new(0, -slot.Size.Y / 2, 0)
	local model = Instance.new("Model")
	model.Name = ball.Id

	-- Stand with a glowing edge, a glass case with glowing corner posts, and a cap
	local pedestal = part({
		Name = "Pedestal",
		Size = PEDESTAL,
		CFrame = base * CFrame.new(0, PEDESTAL.Y / 2, 0),
		Color = DARK,
		Material = Enum.Material.SmoothPlastic,
	})
	pedestal.Parent = model
	-- Neon bands just wider than the stand and the cap, so only a thin glowing edge shows
	for _, y in { PEDESTAL.Y - 0.12, PEDESTAL.Y + GLASS.Y + 0.05 } do
		part({
			Name = "Rim",
			Size = Vector3.new(PEDESTAL.X + 0.15, 0.14, PEDESTAL.Z + 0.15),
			CFrame = base * CFrame.new(0, y, 0),
			Color = rarity.Color,
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, model)
	end
	local glass = part({
		Name = "Glass",
		Size = GLASS,
		CFrame = base * CFrame.new(0, PEDESTAL.Y + GLASS.Y / 2, 0),
		Color = Color3.fromRGB(190, 210, 255),
		Material = Enum.Material.SmoothPlastic, -- not Glass: Glass hides the trails and sparkles behind it
		Reflectance = 0.15,
		Transparency = 0.88,
	})
	glass.Parent = model
	for _, corner in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) } do
		part({
			Name = "Post",
			Size = Vector3.new(0.18, GLASS.Y, 0.18),
			CFrame = base * CFrame.new(corner * (GLASS.X / 2) + Vector3.new(0, PEDESTAL.Y + GLASS.Y / 2, 0)),
			Color = rarity.Color,
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, model)
	end
	part({
		Name = "Cap",
		Size = Vector3.new(PEDESTAL.X, 0.3, PEDESTAL.Z),
		CFrame = base * CFrame.new(0, PEDESTAL.Y + GLASS.Y + 0.27, 0),
		Color = DARK,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	}, model)

	-- The ball itself, lit in its rarity colour, with sparkles for each of its traits
	local center = base * CFrame.new(0, PEDESTAL.Y + GLASS.Y / 2, 0)
	local ballPart = part({
		Name = "Ball",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * BALL_SIZE,
		CFrame = center,
		Color = ball.Color,
		Material = ball.Material,
		CanCollide = false,
	})
	ballPart.Parent = model
	local light = Instance.new("PointLight")
	light.Color = rarity.Color
	light.Range = 12
	light.Brightness = 2.5
	light.Parent = ballPart
	-- A glowing outline in the rarity colour, so even dark balls (like The Void) stand out
	local outline = Instance.new("Highlight")
	outline.FillTransparency = 1
	outline.OutlineColor = rarity.Color
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Adornee = ballPart
	outline.Parent = ballPart
	for _, entry in Balls.GetTraits(ball) do
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Texture = SPARKLE
		sparkles.Color = ColorSequence.new(entry.Trait.Color)
		sparkles.LightEmission = 1
		sparkles.Size = NumberSequence.new(0.35, 0)
		sparkles.Lifetime = NumberRange.new(1, 1.6)
		sparkles.Speed = NumberRange.new(0.6, 1.4)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Rate = SHOW.SparkleRate
		sparkles.Parent = ballPart
	end

	-- Glowing trails circling the ball: more for rarer balls
	local orbits = {}
	local orbitCount = math.max(1, Balls.RarityIndex(ball.Rarity) - SHOW.OrbitsFromRarity)
	for i = 1, orbitCount do
		local orb = part({
			Name = "Orbit",
			Size = Vector3.one * 0.2,
			Transparency = 1,
			CanCollide = false,
		})
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.3, 0)
		a0.Parent = orb
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.3, 0)
		a1.Parent = orb
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(ball.Trail, rarity.Color)
		trail.Transparency = NumberSequence.new(0, 1)
		trail.LightEmission = 1
		trail.Lifetime = 0.7
		trail.FaceCamera = true
		trail.WidthScale = NumberSequence.new(1, 0.2)
		trail.Parent = orb
		orb.Parent = model
		table.insert(orbits, { Part = orb, Offset = (i - 1) / orbitCount, Tilt = (i - 1) * 0.9 + 0.35 })
	end

	-- Sign on the front of the stand
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.Parent = pedestal
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = gui
	label(gui, {
		Name = "BallName",
		Size = UDim2.fromScale(1, 0.24),
		Text = ball.Name:upper(),
		TextColor3 = rarity.Color,
		FontFace = Font.new(FONT, Enum.FontWeight.Heavy),
	})
	label(gui, {
		Name = "Rarity",
		Position = UDim2.fromScale(0, 0.25),
		Size = UDim2.fromScale(1, 0.13),
		Text = ("%s  ·  x%g COINS"):format(ball.Rarity:upper(), ball.Multiplier),
	})
	local traits = Balls.DescribeTraits(ball, false, true)
	label(gui, {
		Name = "Traits",
		Position = UDim2.fromScale(0, 0.41),
		Size = UDim2.fromScale(1, 0.34),
		Text = if traits == "" then "No special trait" else traits,
		RichText = true,
		TextWrapped = true,
	})
	local status = label(gui, {
		Name = "Status",
		Position = UDim2.fromScale(0, 0.8),
		Size = UDim2.fromScale(1, 0.2),
		FontFace = Font.new(FONT, Enum.FontWeight.Heavy),
	})

	model.Parent = parent
	return {
		Id = ball.Id,
		Center = center,
		Ball = ballPart,
		Glass = glass,
		Orbits = orbits,
		Status = status,
		Phase = math.random() * math.pi * 2,
	}
end

function ShowcaseController:Start()
	local showcase = Workspace:WaitForChild("Showcase", 30)
	local slotFolder = showcase and showcase:WaitForChild("Slots", 10)
	if not slotFolder then
		warn("[ShowcaseController] Workspace.Showcase.Slots is missing, so the lobby showcase is off")
		return
	end

	local slots = slotFolder:GetChildren()
	table.sort(slots, function(a, b)
		return (a:GetAttribute("Order") or 0) < (b:GetAttribute("Order") or 0)
	end)

	-- Best balls first, so Mythics get the first slots
	local minRarity = Balls.RarityIndex(SHOW.MinRarity)
	local shown = {}
	for _, ball in Balls.Sorted() do
		if Balls.RarityIndex(ball.Rarity) >= minRarity then
			table.insert(shown, ball)
		end
	end
	if #shown > #slots then
		warn(
			("[ShowcaseController] %d balls to show but only %d slots: add slots in Workspace.Showcase.Slots"):format(
				#shown,
				#slots
			)
		)
	end

	local cases = Instance.new("Folder")
	cases.Name = "Cases"
	cases.Parent = showcase
	local built = {}
	for i, ball in shown do
		local slot = slots[i]
		if slot and slot:IsA("BasePart") then
			table.insert(built, buildCase(slot, ball, cases))
		end
	end

	-- LOCKED / OWNED, from the balls the server says you own
	local function refreshOwned()
		local owned = Balls.DecodeOwned(player:GetAttribute("OwnedBalls"))
		for _, case in built do
			local isOwned = owned[case.Id] == true
			case.Status.Text = if isOwned then "OWNED" else "LOCKED  ·  FIND IT IN CRATES"
			case.Status.TextColor3 = if isOwned then OWNED_COLOR else LOCKED_COLOR
			case.Glass.Transparency = if isOwned then 0.92 else 0.88
		end
	end
	player:GetAttributeChangedSignal("OwnedBalls"):Connect(refreshOwned)
	refreshOwned()

	-- Spin, float and orbit, only while you're close enough to see it
	local middle = Vector3.zero
	for _, case in built do
		middle += case.Center.Position / math.max(#built, 1)
	end
	RunService.Heartbeat:Connect(function()
		local camera = Workspace.CurrentCamera
		if #built == 0 or not camera or (camera.CFrame.Position - middle).Magnitude > SHOW.AnimateDistance then
			return
		end
		local t = os.clock()
		for _, case in built do
			local float = case.Center * CFrame.new(0, math.sin(t * 1.6 + case.Phase) * SHOW.BobHeight, 0)
			case.Ball.CFrame = float * CFrame.Angles(0.3, t * SHOW.SpinSpeed * math.pi * 2, 0)
			for _, orbit in case.Orbits do
				local angle = (t * SHOW.OrbitSpeed + orbit.Offset) * math.pi * 2
				orbit.Part.CFrame = float * CFrame.Angles(orbit.Tilt, angle, 0) * CFrame.new(ORBIT_RADIUS, 0, 0)
			end
		end
	end)
end

return ShowcaseController
