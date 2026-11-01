-- Addendum 6 Stages 4-6: the real maps of zones 2-4, built from code at server start (Claude can't save the
-- Studio place). Each map is built in ZONE 1's layout (the lane, sell pad, shop, egg stand, gates and spawn sit at
-- Config positions) and SharedLane moves it by the zone's Offset. The stations themselves come from CoreLoopService;
-- a map only dresses around them. Every part is tagged "ZoneArt" (CollectionService) and the map model carries
-- BuiltFromCode = true: all of it is simple part art that a designed model can replace later.
-- Config.CoreLoop.Zones List[z].Map picks the builder ("Boardwalk" = zone 2, Sunset Boardwalk).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local CORE = Config.CoreLoop
local LANE = CORE.SharedLane

local ZoneMaps = {}

local TOP = 848.65 -- the floor top in zone 1's layout
local WHITE = Color3.fromRGB(252, 250, 244)
local INK = Color3.fromRGB(46, 36, 66)

-- The map being built (parts go into a sub-model of it)
local current: Model

local function group(name: string): Model
	local m = current:FindFirstChild(name) :: Model?
	if not m then
		m = Instance.new("Model")
		m.Name = name
		m.Parent = current
	end
	return m :: Model
end

-- One anchored part. o: Shape, Material, Collide (default true), Class ("WedgePart"), Transparency, Shadow
local function add(groupName: string, name: string, size: Vector3, cframe: CFrame, color: Color3, o: any?): BasePart
	o = o or {}
	local p = Instance.new(o.Class or "Part") :: BasePart
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = o.Material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if o.Shape then
		(p :: Part).Shape = o.Shape
	end
	if o.Collide == false then
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end
	if o.Transparency then
		p.Transparency = o.Transparency
	end
	if o.Shadow == false then
		p.CastShadow = false
	end
	CollectionService:AddTag(p, "ZoneArt")
	p.Parent = group(groupName)
	return p
end

-- A cylinder standing up (Roblox cylinders run along X)
local UP = CFrame.Angles(0, 0, math.rad(90))
local function post(groupName: string, name: string, at: Vector3, height: number, radius: number, color: Color3, o: any?): BasePart
	o = o or {}
	o.Shape = Enum.PartType.Cylinder
	return add(groupName, name, Vector3.new(height, radius * 2, radius * 2), CFrame.new(at + Vector3.new(0, height / 2, 0)) * UP, color, o)
end

-- Chunky white text with a dark outline (the simulator look)
local function label(parent: Instance, text: string, size: UDim2, position: UDim2, color: Color3?): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = size
	t.Position = position
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Font = Enum.Font.FredokaOne
	t.Text = text
	t.TextScaled = true
	t.TextColor3 = color or Color3.new(1, 1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 4
	stroke.Parent = t
	t.Parent = parent
	return t
end

---------------------------------------------------------------------------------------------------------------
-- Beach props
---------------------------------------------------------------------------------------------------------------

-- A striped beach umbrella: pole, a round canopy and four stripes across it, a little tilted
local function umbrella(at: Vector3, a: Color3, b: Color3, tilt: number?)
	local g = "Umbrellas"
	post(g, "Pole", at, 8.4, 0.18, WHITE)
	local canopyAt = CFrame.new(at + Vector3.new(0, 8.2, 0)) * CFrame.Angles(math.rad(tilt or 6), math.rad((at.X * 7) % 90), 0)
	add(g, "Canopy", Vector3.new(0.4, 9, 9), canopyAt * UP, a, { Shape = Enum.PartType.Cylinder })
	for i = 0, 3 do
		add(g, "Stripe", Vector3.new(9, 0.42, 1.3), canopyAt * CFrame.Angles(0, math.rad(i * 45), 0), b, { Collide = false })
	end
	add(g, "Tip", Vector3.one * 0.7, canopyAt * CFrame.new(0, 0.35, 0), b, { Shape = Enum.PartType.Ball, Collide = false })
end

-- A palm tree: a gently curved trunk, seven drooping leaves and three coconuts
local function palm(at: Vector3, height: number, lean: number)
	local g = "Palms"
	local trunk = Color3.fromRGB(176, 128, 82)
	local segments = 6
	local pos = at
	local dir = CFrame.Angles(0, math.rad(lean), 0)
	for i = 1, segments do
		local bend = math.rad(4 + i * 2.2)
		local step = height / segments
		local cf = CFrame.new(pos) * dir * CFrame.Angles(bend, 0, 0)
		add(g, "Trunk", Vector3.new(step + 0.3, 1.5 - i * 0.08, 1.5 - i * 0.08), cf * CFrame.new(0, step / 2, 0) * UP, if i % 2 == 0 then trunk else trunk:Lerp(Color3.new(0, 0, 0), 0.12), { Shape = Enum.PartType.Cylinder })
		pos = (cf * CFrame.new(0, step, 0)).Position
	end
	local leaf = { Color3.fromRGB(70, 176, 74), Color3.fromRGB(96, 198, 80) }
	for i = 1, 7 do
		local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(i * 360 / 7 + lean), 0) * CFrame.Angles(math.rad(-28 - (i % 2) * 8), 0, 0)
		add(g, "Leaf", Vector3.new(1.8, 0.3, 8), cf * CFrame.new(0, 0, -4), leaf[i % 2 + 1], { Collide = false })
		add(g, "LeafTip", Vector3.new(1.2, 0.3, 3), cf * CFrame.new(0, -1.1, -8.6) * CFrame.Angles(math.rad(-25), 0, 0), leaf[(i + 1) % 2 + 1], { Collide = false })
	end
	for i = 1, 3 do
		local a = math.rad(i * 120)
		add(g, "Coconut", Vector3.one * 0.9, CFrame.new(pos + Vector3.new(math.cos(a) * 0.7, -0.6, math.sin(a) * 0.7)), Color3.fromRGB(112, 76, 44), { Shape = Enum.PartType.Ball, Collide = false })
	end
end

-- A beach hut: a pastel box, white trim, a two-sided roof and a door facing `face` (degrees about Y)
local function hut(at: Vector3, color: Color3, face: number)
	local g = "Huts"
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(face), 0)
	add(g, "Walls", Vector3.new(7, 7, 7), base * CFrame.new(0, 3.5, 0), color, { Material = Enum.Material.WoodPlanks })
	add(g, "Floor", Vector3.new(8, 0.5, 8), base * CFrame.new(0, 0.25, 0), WHITE)
	for _, s in { -1, 1 } do
		add(g, "Roof", Vector3.new(8.4, 0.5, 5.4), base * CFrame.new(s * 2.2, 8.2, 0) * CFrame.Angles(0, 0, math.rad(-s * 35)) * CFrame.Angles(0, math.rad(90), 0), WHITE)
		add(g, "Trim", Vector3.new(0.4, 7, 0.4), base * CFrame.new(s * 3.5, 3.5, -3.5), WHITE)
	end
	add(g, "Gable", Vector3.new(0.3, 2.6, 6), base * CFrame.new(0, 8.3, -3.5) * CFrame.Angles(0, math.rad(90), 0), color, { Class = "WedgePart", Collide = false })
	add(g, "Door", Vector3.new(2.6, 4.6, 0.2), base * CFrame.new(0, 2.8, -3.55), color:Lerp(Color3.new(0, 0, 0), 0.25))
	add(g, "Window", Vector3.new(1.6, 1.6, 0.2), base * CFrame.new(2.2, 4.4, -3.55), Color3.fromRGB(190, 236, 255), { Material = Enum.Material.Glass })
end

-- A beach towel lying on the sand, in two stripes
local function towel(at: Vector3, a: Color3, b: Color3, turn: number)
	local cf = CFrame.new(at + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, math.rad(turn), 0)
	add("Towels", "Towel", Vector3.new(3, 0.1, 6), cf, a, { Collide = false })
	for _, z in { -1.6, 0, 1.6 } do
		add("Towels", "TowelStripe", Vector3.new(3.02, 0.12, 0.6), cf * CFrame.new(0, 0, z), b, { Collide = false })
	end
end

-- A surfboard stuck upright in the sand
local function surfboard(at: Vector3, color: Color3, turn: number)
	local p = add("Surfboards", "Surfboard", Vector3.new(1, 1, 1), CFrame.new(at + Vector3.new(0, 3, 0)) * CFrame.Angles(math.rad(-8), math.rad(turn), 0), color)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(2, 7.4, 0.35)
	mesh.Parent = p
	p.Size = Vector3.new(2, 7.4, 0.35)
	add("Surfboards", "Stripe", Vector3.new(0.25, 6.6, 0.38), p.CFrame, WHITE, { Collide = false })
end

-- A small sailboat on the water (hull, two bow wedges, mast, sail)
local function boat(at: Vector3, turn: number, hull: Color3, sail: Color3)
	local g = "Boats"
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(turn), 0)
	add(g, "Hull", Vector3.new(5, 2.6, 12), base, hull)
	add(g, "Bow", Vector3.new(5, 2.6, 4), base * CFrame.new(0, 0, -8) * CFrame.Angles(math.rad(180), 0, 0), hull, { Class = "WedgePart" })
	add(g, "Deck", Vector3.new(4.6, 0.3, 11.6), base * CFrame.new(0, 1.35, 0), Color3.fromRGB(214, 170, 120))
	add(g, "Stripe", Vector3.new(5.05, 0.5, 12.05), base * CFrame.new(0, 0.6, 0), WHITE, { Collide = false })
	post(g, "Mast", (base * CFrame.new(0, 1.4, -1)).Position, 16, 0.25, WHITE)
	add(g, "Sail", Vector3.new(0.2, 14, 8), base * CFrame.new(0, 9, 3) * CFrame.Angles(0, math.rad(180), 0), sail, { Class = "WedgePart", Collide = false })
end

-- A kite high in the sky: a diamond with cross sticks, a bow tail and a string down to the sand
local function kite(at: Vector3, anchor: Vector3, a: Color3, b: Color3)
	local g = "Kites"
	local face = CFrame.lookAt(at, anchor) * CFrame.Angles(math.rad(-60), 0, 0)
	local body = add(g, "Kite", Vector3.new(5, 5, 0.15), face * CFrame.Angles(0, 0, math.rad(45)), a, { Collide = false, Shadow = false })
	add(g, "KiteHalf", Vector3.new(2.5, 2.5, 0.17), face * CFrame.Angles(0, 0, math.rad(45)) * CFrame.new(1.25, 1.25, 0), b, { Collide = false, Shadow = false })
	add(g, "KiteHalf", Vector3.new(2.5, 2.5, 0.17), face * CFrame.Angles(0, 0, math.rad(45)) * CFrame.new(-1.25, -1.25, 0), b, { Collide = false, Shadow = false })
	for i = 1, 5 do
		add(g, "Bow", Vector3.new(0.9, 0.5, 0.1), face * CFrame.new(math.sin(i) * 0.6, -3.5 - i * 1.3, 0) * CFrame.Angles(0, 0, math.rad(i * 30)), if i % 2 == 0 then a else b, { Collide = false, Shadow = false })
	end
	local foot = add(g, "KiteStake", Vector3.new(0.3, 0.6, 0.3), CFrame.new(anchor + Vector3.new(0, 0.3, 0)), WHITE, { Collide = false })
	local a0 = Instance.new("Attachment")
	a0.Parent = body
	local a1 = Instance.new("Attachment")
	a1.Parent = foot
	local string = Instance.new("Beam")
	string.Attachment0 = a0
	string.Attachment1 = a1
	string.Width0 = 0.06
	string.Width1 = 0.06
	string.Color = ColorSequence.new(WHITE)
	string.FaceCamera = true
	string.CurveSize0 = -6
	string.Segments = 12
	string.Parent = body
end

-- Bunting: a row of triangle flags hanging between two points
local function bunting(from: Vector3, to: Vector3, colors: { Color3 })
	local g = "Bunting"
	local count = math.floor((to - from).Magnitude / 2.4)
	local across = (to - from).Unit
	local look = CFrame.lookAt(Vector3.zero, across)
	for i = 0, count do
		local k = i / count
		local sag = math.sin(k * math.pi) * 2.2
		local at = from:Lerp(to, k) - Vector3.new(0, sag, 0)
		add(g, "Flag", Vector3.new(0.08, 1.3, 1.3), CFrame.new(at) * look * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(45)), colors[i % #colors + 1], { Collide = false, Shadow = false })
	end
	local mid = (from + to) / 2 - Vector3.new(0, 1.4, 0)
	add(g, "Rope", Vector3.new(0.08, 0.08, (to - from).Magnitude), CFrame.lookAt(mid, mid + across), WHITE, { Collide = false, Shadow = false })
end

-- A striped awning over a station's counter (its back at `back`, width `width`)
local function awning(back: Vector3, width: number, a: Color3, b: Color3)
	local g = "Awnings"
	local strips = math.floor(width / 1.6)
	local w = width / strips
	for i = 1, strips do
		local x = -width / 2 + w * (i - 0.5)
		add(g, "Awning", Vector3.new(w, 0.3, 5), CFrame.new(back + Vector3.new(x, 11, -1.2)) * CFrame.Angles(math.rad(-16), 0, 0), if i % 2 == 0 then a else b, { Collide = false })
		-- scalloped front edge
		add(g, "Scallop", Vector3.new(w * 0.9, 0.9, 0.2), CFrame.new(back + Vector3.new(x, 10.0, -3.6)), if i % 2 == 0 then a else b, { Collide = false, Shadow = false })
	end
	for _, s in { -1, 1 } do
		post(g, "AwningPost", back + Vector3.new(s * (width / 2 - 0.2), 0, -3.4), 10.4, 0.18, WHITE, { Collide = false })
	end
end

---------------------------------------------------------------------------------------------------------------
-- Zone 2: Sunset Boardwalk
---------------------------------------------------------------------------------------------------------------
local BOARD = {
	Deck = { X0 = -112, X1 = 64, Z0 = -3604, Z1 = -3382 }, -- the pier deck (zone 1's layout)
	Beach = { X0 = 64, X1 = 214, Z0 = -3660, Z1 = -3360 },
	WaterTop = 845.6, -- 3 studs under the deck
	Sand = Color3.fromRGB(246, 222, 160),
	Planks = { Color3.fromRGB(222, 184, 132), Color3.fromRGB(208, 168, 116) },
	Turquoise = Color3.fromRGB(48, 200, 206),
	Coral = Color3.fromRGB(255, 118, 96),
	Yellow = Color3.fromRGB(255, 212, 84),
	Rail = Color3.fromRGB(255, 118, 96),
}

-- the lighthouse's foot, on its rocky island south-east of the pit (seen to the right of the arch)
local LIGHTHOUSE = Vector3.new(44, TOP - 1, -3700)

local function buildBoardwalk(info: any)
	local d = BOARD.Deck
	local palette = info.Palette

	-- The pier deck: plank strips across the whole play area, in two warm wood tones
	local strip = 8
	local x = d.X0
	local n = 0
	while x < d.X1 do
		local w = math.min(strip, d.X1 - x)
		n += 1
		add("Deck", "Planks", Vector3.new(w, 2, d.Z1 - d.Z0), CFrame.new(x + w / 2, TOP - 1, (d.Z0 + d.Z1) / 2), BOARD.Planks[n % 2 + 1], { Material = Enum.Material.WoodPlanks })
		x += w
	end
	-- a darker beam all round the deck's edge, and the pier legs down into the water
	local edge = Color3.fromRGB(150, 108, 70)
	add("Deck", "EdgeBeam", Vector3.new(d.X1 - d.X0, 1.4, 1.2), CFrame.new((d.X0 + d.X1) / 2, TOP - 2.4, d.Z0 + 0.6), edge, { Material = Enum.Material.Wood })
	add("Deck", "EdgeBeam", Vector3.new(d.X1 - d.X0, 1.4, 1.2), CFrame.new((d.X0 + d.X1) / 2, TOP - 2.4, d.Z1 - 0.6), edge, { Material = Enum.Material.Wood })
	add("Deck", "EdgeBeam", Vector3.new(1.2, 1.4, d.Z1 - d.Z0), CFrame.new(d.X0 + 0.6, TOP - 2.4, (d.Z0 + d.Z1) / 2), edge, { Material = Enum.Material.Wood })
	for lx = d.X0 + 2, d.X1, 16 do
		for _, lz in { d.Z0 + 1.5, d.Z1 - 1.5 } do
			post("Deck", "PierLeg", Vector3.new(lx, TOP - 16, lz), 14, 0.9, edge, { Material = Enum.Material.Wood })
		end
	end
	for lz = d.Z0 + 16, d.Z1 - 8, 16 do
		post("Deck", "PierLeg", Vector3.new(d.X0 + 1.5, TOP - 16, lz), 14, 0.9, edge, { Material = Enum.Material.Wood })
	end

	-- Railings round the pier (the east side opens onto the beach): white posts, coral top rail, white mid rail
	local function rail(from: Vector3, to: Vector3)
		local length = (to - from).Magnitude
		local dir = (to - from).Unit
		local look = CFrame.lookAt(Vector3.zero, dir)
		for k = 0, math.floor(length / 6) do
			local at = from + dir * math.min(k * 6, length)
			add("Railings", "RailPost", Vector3.new(0.5, 3.6, 0.5), CFrame.new(at + Vector3.new(0, 1.8, 0)), WHITE)
		end
		local mid = (from + to) / 2
		add("Railings", "TopRail", Vector3.new(0.7, 0.45, length), CFrame.new(mid + Vector3.new(0, 3.7, 0)) * look, BOARD.Rail)
		add("Railings", "MidRail", Vector3.new(0.3, 0.3, length), CFrame.new(mid + Vector3.new(0, 1.9, 0)) * look, WHITE, { Collide = false })
	end
	local y = TOP
	rail(Vector3.new(d.X0 + 0.5, y, d.Z1 - 0.5), Vector3.new(d.X1, y, d.Z1 - 0.5)) -- north
	rail(Vector3.new(d.X0 + 0.5, y, d.Z0 + 0.5), Vector3.new(d.X0 + 0.5, y, d.Z1 - 0.5)) -- west
	rail(Vector3.new(d.X0 + 0.5, y, d.Z0 + 0.5), Vector3.new(d.X1, y, d.Z0 + 0.5)) -- south

	-- Lamp posts along the north and west rails (cream lanterns: daytime, no glow)
	for lx = d.X0 + 12, d.X1 - 4, 24 do
		post("Lamps", "LampPost", Vector3.new(lx, y, d.Z1 - 2), 10, 0.25, Color3.fromRGB(60, 120, 140))
		add("Lamps", "Lantern", Vector3.new(1.4, 1.8, 1.4), CFrame.new(lx, y + 10.8, d.Z1 - 2), Color3.fromRGB(255, 244, 214), { Material = Enum.Material.Glass, Transparency = 0.15 })
		add("Lamps", "LampCap", Vector3.new(1.8, 0.4, 1.8), CFrame.new(lx, y + 11.9, d.Z1 - 2), Color3.fromRGB(60, 120, 140))
	end

	-- The lane's gutters (bright turquoise), low coral walls outside them, the pit and a striped back wall
	local length = LANE.FoulZ - LANE.EndZ
	local midZ = (LANE.FoulZ + LANE.EndZ) / 2
	for _, side in { -1, 1 } do
		add("Lane", "Gutter", Vector3.new(2.4, 0.3, length), CFrame.new(LANE.Centre + side * (LANE.Width / 2 + 1.2), TOP + 0.05, midZ), palette.Edge)
		add("Lane", "GutterWall", Vector3.new(0.8, 1.6, length + 10), CFrame.new(LANE.Centre + side * (LANE.Width / 2 + 2.8), TOP + 0.8, midZ - 5), palette.Accent)
		add("Lane", "GutterCap", Vector3.new(1, 0.25, length + 10), CFrame.new(LANE.Centre + side * (LANE.Width / 2 + 2.8), TOP + 1.7, midZ - 5), WHITE)
	end
	add("Lane", "Pit", Vector3.new(LANE.Width + 6, 0.3, 8), CFrame.new(LANE.Centre, TOP + 0.02, LANE.EndZ - 4), Color3.fromRGB(32, 70, 96))
	local backZ = LANE.EndZ - 8.6
	local wallWidth = LANE.Width + 6.4
	local stripes = 16
	for i = 1, stripes do
		local sx = LANE.Centre - wallWidth / 2 + wallWidth * (i - 0.5) / stripes
		add("Lane", "BackWall", Vector3.new(wallWidth / stripes, 8, 1.2), CFrame.new(sx, TOP + 4, backZ), if i % 2 == 0 then BOARD.Turquoise else WHITE)
	end
	add("Lane", "BackWallCap", Vector3.new(wallWidth + 1, 0.8, 1.8), CFrame.new(LANE.Centre, TOP + 8.3, backZ), BOARD.Coral)

	-- The big SUNSET BOARDWALK arch behind the pit (two striped towers and a board), facing the bowlers
	local signZ = backZ - 3
	for _, side in { -1, 1 } do
		local sx = LANE.Centre + side * 36
		for k = 0, 5 do
			add("Arch", "Tower", Vector3.new(4, 4, 4), CFrame.new(sx, TOP + 2 + k * 4, signZ), if k % 2 == 0 then BOARD.Coral else WHITE)
		end
		add("Arch", "TowerTop", Vector3.new(5, 1, 5), CFrame.new(sx, TOP + 24.5, signZ), BOARD.Yellow)
		add("Arch", "TowerBall", Vector3.one * 3, CFrame.new(sx, TOP + 26.5, signZ), BOARD.Turquoise, { Shape = Enum.PartType.Ball })
	end
	local board = add("Arch", "NameBoard", Vector3.new(64, 11, 1), CFrame.new(LANE.Centre, TOP + 19, signZ), Color3.fromRGB(255, 248, 232))
	add("Arch", "NameBoardTrim", Vector3.new(66, 13, 0.6), CFrame.new(LANE.Centre, TOP + 19, signZ - 0.5), BOARD.Turquoise)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- (faces the bowlers, +Z)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	gui.Parent = board
	local title = label(gui, "SUNSET BOARDWALK", UDim2.fromScale(0.94, 0.62), UDim2.fromScale(0.5, 0.4), Color3.new(1, 1, 1))
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(255, 214, 90), Color3.fromRGB(255, 110, 96))
	gradient.Rotation = 90
	gradient.Parent = title
	label(gui, "ZONE 2", UDim2.fromScale(0.3, 0.26), UDim2.fromScale(0.5, 0.83), BOARD.Turquoise)

	-- Bunting over the lane, between poles on the gutter walls
	local flags = { BOARD.Coral, BOARD.Yellow, BOARD.Turquoise, WHITE }
	for _, bz in { -3470, -3505, -3540 } do
		for _, side in { -1, 1 } do
			post("Bunting", "BuntingPole", Vector3.new(LANE.Centre + side * (LANE.Width / 2 + 2.8), TOP + 1.6, bz), 17, 0.22, WHITE)
		end
		bunting(
			Vector3.new(LANE.Centre - LANE.Width / 2 - 2.8, TOP + 18.4, bz),
			Vector3.new(LANE.Centre + LANE.Width / 2 + 2.8, TOP + 18.4, bz),
			flags
		)
	end

	-- Beach-hut awnings over the sell and shop counters, and a striped umbrella or two on the deck
	local sell, shop = CORE.Sell, CORE.Shop
	awning(sell.Position + Vector3.new(0, 0, sell.Radius + 2.2), 12, BOARD.Coral, WHITE)
	awning(shop.Position + Vector3.new(0, 0, shop.Radius + 2.2), 11, BOARD.Turquoise, WHITE)
	umbrella(Vector3.new(-56, TOP, -3404), BOARD.Yellow, WHITE)
	umbrella(Vector3.new(4, TOP, -3404), BOARD.Coral, WHITE)
	umbrella(Vector3.new(38, TOP, -3420), BOARD.Turquoise, WHITE)
	palm(Vector3.new(40, TOP, -3452), 15, 200)
	palm(Vector3.new(-104, TOP, -3390), 14, 130)
	palm(Vector3.new(56, TOP, -3392), 16, 30)

	-- The beach to the east: a sand slab level with the deck, sloping into the sea on its open sides
	local b = BOARD.Beach
	add("Beach", "Sand", Vector3.new(b.X1 - b.X0, 6, b.Z1 - b.Z0), CFrame.new((b.X0 + b.X1) / 2, TOP - 3, (b.Z0 + b.Z1) / 2), BOARD.Sand, { Material = Enum.Material.Sand })
	-- slopes: east (down toward +X), north (+Z) and south (-Z)
	add("Beach", "Slope", Vector3.new(b.Z1 - b.Z0, 6, 26), CFrame.new(b.X1 + 13, TOP - 3, (b.Z0 + b.Z1) / 2) * CFrame.Angles(0, math.rad(-90), 0), BOARD.Sand, { Class = "WedgePart", Material = Enum.Material.Sand })
	add("Beach", "Slope", Vector3.new(b.X1 - b.X0, 6, 22), CFrame.new((b.X0 + b.X1) / 2, TOP - 3, b.Z1 + 11) * CFrame.Angles(0, math.rad(180), 0), BOARD.Sand, { Class = "WedgePart", Material = Enum.Material.Sand })
	add("Beach", "Slope", Vector3.new(b.X1 - b.X0, 6, 22), CFrame.new((b.X0 + b.X1) / 2, TOP - 3, b.Z0 - 11), BOARD.Sand, { Class = "WedgePart", Material = Enum.Material.Sand })
	-- a strip of wet sand where the deck meets the beach
	add("Beach", "DeckStep", Vector3.new(2, 0.2, d.Z1 - d.Z0), CFrame.new(d.X1 + 1, TOP + 0.02, (d.Z0 + d.Z1) / 2), Color3.fromRGB(200, 160, 110), { Material = Enum.Material.WoodPlanks })

	-- beach umbrellas and towels in rows, palms, huts, a lifeguard tower, surfboards, a sandcastle, a volleyball net
	local umbrellaColors = { { BOARD.Coral, WHITE }, { BOARD.Turquoise, WHITE }, { BOARD.Yellow, BOARD.Coral }, { Color3.fromRGB(120, 200, 255), WHITE } }
	local k = 0
	for ux = 84, 176, 23 do
		for uz = -3612, -3396, 36 do
			k += 1
			if (k * 7) % 5 == 0 then
				continue -- (gaps, so it isn't a grid)
			end
			local c = umbrellaColors[k % #umbrellaColors + 1]
			local jitter = Vector3.new(((k * 13) % 7) - 3, 0, ((k * 5) % 9) - 4)
			umbrella(Vector3.new(ux, TOP, uz) + jitter, c[1], c[2], 4 + (k % 4) * 3)
			towel(Vector3.new(ux + 3.5, TOP, uz + 2) + jitter, c[2], c[1], (k * 23) % 40 - 20)
		end
	end
	for _, p in { { 74, -3378, 15, 20 }, { 200, -3376, 17, 250 }, { 206, -3470, 14, 300 }, { 202, -3560, 16, 220 }, { 196, -3640, 15, 280 }, { 74, -3646, 13, 60 } } do
		palm(Vector3.new(p[1], TOP, p[2]), p[3], p[4])
	end
	local hutColors = { Color3.fromRGB(255, 160, 150), Color3.fromRGB(130, 214, 220), Color3.fromRGB(255, 222, 120), Color3.fromRGB(170, 220, 150), Color3.fromRGB(200, 180, 240) }
	for i, hz in { -3400, -3420, -3440, -3460, -3480 } do
		hut(Vector3.new(196, TOP, hz), hutColors[i], -90)
	end
	-- lifeguard tower
	local tower = Vector3.new(170, TOP, -3530)
	for _, o in { { -2, -2 }, { 2, -2 }, { -2, 2 }, { 2, 2 } } do
		add("Lifeguard", "Leg", Vector3.new(0.5, 8, 0.5), CFrame.new(tower + Vector3.new(o[1], 4, o[2])), WHITE)
	end
	add("Lifeguard", "Platform", Vector3.new(6, 0.5, 6), CFrame.new(tower + Vector3.new(0, 8, 0)), Color3.fromRGB(240, 70, 70))
	add("Lifeguard", "Cabin", Vector3.new(5, 4, 5), CFrame.new(tower + Vector3.new(0, 10.3, 0.4)), Color3.fromRGB(240, 70, 70))
	add("Lifeguard", "CabinRoof", Vector3.new(6.4, 0.5, 6.4), CFrame.new(tower + Vector3.new(0, 12.5, 0.4)), WHITE)
	add("Lifeguard", "Ramp", Vector3.new(2, 0.4, 10), CFrame.new(tower + Vector3.new(0, 4, -7)) * CFrame.Angles(math.rad(-48), 0, 0), WHITE)
	post("Lifeguard", "FlagPole", tower + Vector3.new(2.6, 12.6, 2.6), 5, 0.12, WHITE)
	add("Lifeguard", "Flag", Vector3.new(0.1, 1.6, 2.4), CFrame.new(tower + Vector3.new(2.6, 16.6, 1.4)), Color3.fromRGB(255, 220, 60), { Collide = false })
	for i, sx in { 160, 163, 166, 169 } do
		surfboard(Vector3.new(sx, TOP, -3548), ({ BOARD.Coral, BOARD.Turquoise, BOARD.Yellow, Color3.fromRGB(180, 140, 255) })[i], 10 * i)
	end
	-- sandcastle
	local castle = Vector3.new(120, TOP, -3460)
	add("Sandcastle", "Base", Vector3.new(6, 2, 6), CFrame.new(castle + Vector3.new(0, 1, 0)), Color3.fromRGB(232, 200, 130), { Material = Enum.Material.Sand })
	for _, o in { { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } } do
		post("Sandcastle", "Turret", castle + Vector3.new(o[1], 0, o[2]), 4, 1.1, Color3.fromRGB(232, 200, 130), { Material = Enum.Material.Sand })
	end
	post("Sandcastle", "Keep", castle, 5, 1.6, Color3.fromRGB(232, 200, 130), { Material = Enum.Material.Sand })
	post("Sandcastle", "FlagPole", castle + Vector3.new(0, 5, 0), 2.4, 0.06, WHITE)
	add("Sandcastle", "Flag", Vector3.new(0.05, 0.8, 1.2), CFrame.new(castle + Vector3.new(0, 7, 0.6)), BOARD.Coral, { Collide = false })
	-- volleyball net
	local net = Vector3.new(130, TOP, -3420)
	for _, s in { -9, 9 } do
		post("Volleyball", "NetPole", net + Vector3.new(s, 0, 0), 8, 0.2, WHITE)
	end
	add("Volleyball", "Net", Vector3.new(18, 3, 0.1), CFrame.new(net + Vector3.new(0, 6, 0)), WHITE, { Transparency = 0.45, Material = Enum.Material.Fabric })
	add("Volleyball", "NetTop", Vector3.new(18, 0.3, 0.15), CFrame.new(net + Vector3.new(0, 7.6, 0)), BOARD.Coral)
	for i, at in { Vector3.new(124, 0, -3428), Vector3.new(112, 0, -3530), Vector3.new(150, 0, -3600) } do
		add("Beach", "BeachBall", Vector3.one * 2.2, CFrame.new(Vector3.new(at.X, TOP + 1.1, at.Z)), ({ BOARD.Coral, BOARD.Yellow, BOARD.Turquoise })[i], { Shape = Enum.PartType.Ball })
	end

	-- The ferris wheel on the beach, south-east, facing the lane (seen over the right side of the arch)
	local hub = Vector3.new(140, TOP + 30, -3628)
	local R = 24
	local spokes = 16
	local wheelColor = { WHITE, BOARD.Coral }
	for side, dz in { -1.6, 1.6 } do
		local centre = CFrame.new(hub + Vector3.new(0, 0, dz))
		for i = 0, spokes - 1 do
			local a = math.rad(i * 360 / spokes)
			add("FerrisWheel", "Spoke", Vector3.new(0.35, R, 0.35), centre * CFrame.Angles(0, 0, a) * CFrame.new(0, R / 2, 0), WHITE, { Collide = false })
			local mid = a + math.pi / spokes
			local seg = 2 * R * math.sin(math.pi / spokes)
			add("FerrisWheel", "Rim", Vector3.new(seg + 0.4, 0.8, 0.8), centre * CFrame.Angles(0, 0, mid) * CFrame.new(0, R * math.cos(math.pi / spokes), 0), wheelColor[side], { Collide = false })
		end
	end
	add("FerrisWheel", "Hub", Vector3.new(5, 4, 4), CFrame.new(hub) * CFrame.Angles(0, math.rad(90), 0) * UP, BOARD.Yellow, { Shape = Enum.PartType.Cylinder, Collide = false })
	local cabins = { BOARD.Coral, BOARD.Turquoise, BOARD.Yellow, Color3.fromRGB(180, 140, 255) }
	for i = 0, spokes - 1, 2 do
		local a = math.rad(i * 360 / spokes)
		local at = (CFrame.new(hub) * CFrame.Angles(0, 0, a) * CFrame.new(0, R, 0)).Position
		add("FerrisWheel", "Cabin", Vector3.new(3, 3, 3.6), CFrame.new(at - Vector3.new(0, 2.4, 0)), cabins[(i // 2) % #cabins + 1], { Collide = false })
		add("FerrisWheel", "CabinRoof", Vector3.new(3.6, 0.4, 4.2), CFrame.new(at - Vector3.new(0, 0.7, 0)), WHITE, { Collide = false })
	end
	for _, s in { -1, 1 } do
		for _, dz in { -4, 4 } do
			local foot = Vector3.new(hub.X + s * 14, TOP, hub.Z + dz)
			local topAt = hub + Vector3.new(0, 0, dz * 0.5)
			local mid = (foot + topAt) / 2
			add("FerrisWheel", "Leg", Vector3.new(1.2, 1.2, (topAt - foot).Magnitude), CFrame.lookAt(mid, topAt), WHITE)
		end
	end

	-- The lighthouse on a rocky island past the pit (rocks are Terrain, see ZoneMaps.Terrain)
	local light = LIGHTHOUSE
	local rings = 8
	for i = 0, rings - 1 do
		local r = 9 - i * 0.5
		post("Lighthouse", "Ring", light + Vector3.new(0, i * 8, 0), 8, r, if i % 2 == 0 then Color3.fromRGB(236, 64, 64) else WHITE)
	end
	local topY = light.Y + rings * 8
	post("Lighthouse", "Gallery", Vector3.new(light.X, topY, light.Z), 1, 6.6, Color3.fromRGB(40, 50, 64))
	post("Lighthouse", "Lamp", Vector3.new(light.X, topY + 1, light.Z), 6, 4, Color3.fromRGB(255, 236, 160), { Material = Enum.Material.Glass, Transparency = 0.2 })
	post("Lighthouse", "LampCore", Vector3.new(light.X, topY + 2.4, light.Z), 3, 1.8, Color3.fromRGB(255, 220, 110), { Material = Enum.Material.Neon })
	post("Lighthouse", "Cap", Vector3.new(light.X, topY + 7, light.Z), 2, 4.8, Color3.fromRGB(236, 64, 64))
	add("Lighthouse", "Spire", Vector3.one * 2.6, CFrame.new(light.X, topY + 10.2, light.Z), BOARD.Yellow, { Shape = Enum.PartType.Ball })
	add("Lighthouse", "Door", Vector3.new(3.4, 6, 0.4), CFrame.new(light.X, light.Y + 3, light.Z + 8.8), Color3.fromRGB(40, 50, 64))

	-- Boats and buoys on the water, kites over the beach and the sea
	local water = BOARD.WaterTop
	boat(Vector3.new(-150, water + 0.5, -3500), 20, WHITE, BOARD.Coral)
	boat(Vector3.new(-90, water + 0.5, -3700), -40, Color3.fromRGB(60, 140, 220), WHITE)
	boat(Vector3.new(-40, water + 0.5, -3740), 75, BOARD.Coral, Color3.fromRGB(255, 236, 160))
	boat(Vector3.new(-170, water + 0.5, -3330), -100, BOARD.Yellow, WHITE)
	for i, at in { Vector3.new(-128, 0, -3420), Vector3.new(-130, 0, -3560), Vector3.new(-40, 0, -3640), Vector3.new(40, 0, -3660) } do
		add("Buoys", "Buoy", Vector3.one * 2, CFrame.new(at.X, water + 0.4, at.Z), if i % 2 == 0 then BOARD.Coral else WHITE, { Shape = Enum.PartType.Ball })
	end
	kite(Vector3.new(110, TOP + 58, -3560), Vector3.new(118, TOP, -3500), BOARD.Coral, BOARD.Yellow)
	kite(Vector3.new(150, TOP + 70, -3460), Vector3.new(150, TOP, -3400), BOARD.Turquoise, WHITE)
	kite(Vector3.new(-70, TOP + 64, -3650), Vector3.new(-60, TOP, -3590), BOARD.Yellow, BOARD.Coral)
	kite(Vector3.new(30, TOP + 52, -3640), Vector3.new(36, TOP, -3590), Color3.fromRGB(180, 140, 255), WHITE)
	kite(Vector3.new(190, TOP + 62, -3600), Vector3.new(180, TOP, -3560), BOARD.Coral, BOARD.Turquoise)
end

local BUILDERS = { Boardwalk = buildBoardwalk }

-- Builds a zone's map in zone 1's layout (SharedLane moves it by the zone's Offset and parents it)
function ZoneMaps.Build(name: string, zone: number, info: any): Model
	current = Instance.new("Model")
	current.Name = "Map"
	current:SetAttribute("Map", name)
	current:SetAttribute("Zone", zone)
	current:SetAttribute("BuiltFromCode", true)
	local builder = BUILDERS[name]
	if builder then
		builder(info)
	else
		warn("ZoneMaps: no builder for", name)
	end
	return current
end

-- The Terrain parts of a map (water, island rocks), placed at the zone's real position
function ZoneMaps.Terrain(name: string, info: any)
	local terrain = Workspace.Terrain
	local offset = info.Offset or Vector3.zero
	if name == "Boardwalk" then
		-- a turquoise sea round the whole pier, out to the horizon
		local top = BOARD.WaterTop
		terrain:FillBlock(CFrame.new(Vector3.new(-20, top - 6, -3480) + offset), Vector3.new(1400, 12, 1400), Enum.Material.Water)
		-- the lighthouse island and a few rocks by the beach
		local isle = Vector3.new(LIGHTHOUSE.X, top, LIGHTHOUSE.Z)
		terrain:FillBall(isle + Vector3.new(0, -17, 0) + offset, 19, Enum.Material.Rock)
		terrain:FillBall(isle + Vector3.new(14, -14, 8) + offset, 12, Enum.Material.Rock)
		terrain:FillBall(isle + Vector3.new(-14, -13, -6) + offset, 11, Enum.Material.Rock)
		terrain:FillBall(Vector3.new(232, top - 5, -3420) + offset, 6, Enum.Material.Rock)
		terrain:FillBall(Vector3.new(-128, top - 5, -3612) + offset, 5, Enum.Material.Rock)
		-- the sea's look (only this zone has water)
		terrain.WaterColor = Color3.fromRGB(36, 196, 206)
		terrain.WaterTransparency = 0.55
		terrain.WaterReflectance = 0.35
		terrain.WaterWaveSize = 0.18
		terrain.WaterWaveSpeed = 8
	end
end

return ZoneMaps
