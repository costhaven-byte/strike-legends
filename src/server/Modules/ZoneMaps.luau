-- Addendum 6 Stages 4-6: the real maps of zones 2-4, built from code at server start (Claude can't save the
-- Studio place). Each map is built in ZONE 1's layout (the lane, sell pad, shop, egg stand, gates and spawn sit at
-- Config positions) and SharedLane moves it by the zone's Offset. The stations themselves come from CoreLoopService;
-- a map only dresses around them. Every part is tagged "ZoneArt" (CollectionService) and the map model carries
-- BuiltFromCode = true: all of it is simple part art that a designed model can replace later.
-- Config.CoreLoop.Zones List[z].Map picks the builder ("Boardwalk" = zone 2, Sunset Boardwalk).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
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

-- 2026-11-03 v2 models: the owner's designed prop (ServerStorage.ZoneKits.Zone<zone>.<name>, pivot at its bottom
-- centre, front -Z) put in the group at the floor point `at`, turned `turn` degrees. False = no design: build parts.
local function design(zone: number, name: string, at: Vector3, turn: number): boolean
	local folder = ServerStorage:FindFirstChild("ZoneKits")
	folder = folder and folder:FindFirstChild("Zone" .. zone)
	local kit = folder and folder:FindFirstChild(name)
	if not kit or not kit:IsA("Model") then
		return false
	end
	local copy = kit:Clone()
	copy.Name = "Design"
	copy:PivotTo(CFrame.new(at) * CFrame.Angles(0, math.rad(turn), 0))
	copy.Parent = group(name)
	return true
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
	-- lifeguard tower (the owner's SL_Z2_Hero_LifeguardTower x1.2 since 2026-11-03, facing the pier)
	local tower = Vector3.new(170, TOP, -3530)
	if not design(2, "Lifeguard", tower, 90) then
		for _, o in { { -2, -2 }, { 2, -2 }, { -2, 2 }, { 2, 2 } } do
			add("Lifeguard", "Leg", Vector3.new(0.5, 8, 0.5), CFrame.new(tower + Vector3.new(o[1], 4, o[2])), WHITE)
		end
		add("Lifeguard", "Platform", Vector3.new(6, 0.5, 6), CFrame.new(tower + Vector3.new(0, 8, 0)), Color3.fromRGB(240, 70, 70))
		add("Lifeguard", "Cabin", Vector3.new(5, 4, 5), CFrame.new(tower + Vector3.new(0, 10.3, 0.4)), Color3.fromRGB(240, 70, 70))
		add("Lifeguard", "CabinRoof", Vector3.new(6.4, 0.5, 6.4), CFrame.new(tower + Vector3.new(0, 12.5, 0.4)), WHITE)
		add("Lifeguard", "Ramp", Vector3.new(2, 0.4, 10), CFrame.new(tower + Vector3.new(0, 4, -7)) * CFrame.Angles(math.rad(-48), 0, 0), WHITE)
		post("Lifeguard", "FlagPole", tower + Vector3.new(2.6, 12.6, 2.6), 5, 0.12, WHITE)
		add("Lifeguard", "Flag", Vector3.new(0.1, 1.6, 2.4), CFrame.new(tower + Vector3.new(2.6, 16.6, 1.4)), Color3.fromRGB(255, 220, 60), { Collide = false })
	end
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

	-- The ferris wheel on the beach, south-east, facing the lane (seen over the right side of the arch). Since
	-- 2026-11-03 the owner's SL_Z2_Hero_FerrisWheel x2 (its wheel turns: client ZonePropsController)
	local hub = Vector3.new(140, TOP + 30, -3628)
	if not design(2, "FerrisWheel", Vector3.new(hub.X, TOP, hub.Z), 180) then
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
	end

	-- The lighthouse on a rocky island past the pit (rocks are Terrain, see ZoneMaps.Terrain). Since 2026-11-03 the
	-- owner's SL_Z2_Hero_Lighthouse x3.2 (its own rocks at the foot), door toward the bowlers
	local light = LIGHTHOUSE
	if not design(2, "Lighthouse", light, 180) then
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
	end

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

---------------------------------------------------------------------------------------------------------------
-- Jungle props
---------------------------------------------------------------------------------------------------------------

-- A big flat leaf (a squashed sphere with a pale midrib) from `base`, pointing `yaw` degrees round and `droop` down
local function leaf(groupName: string, base: Vector3, length: number, yaw: number, droop: number, color: Color3)
	local cf = CFrame.new(base) * CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(math.rad(-droop), 0, 0)
	local p = add(groupName, "Leaf", Vector3.new(length * 0.42, 0.3, length), cf * CFrame.new(0, 0, -length / 2), color, { Collide = false })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	add(groupName, "Midrib", Vector3.new(0.18, 0.34, length * 0.9), cf * CFrame.new(0, 0.04, -length / 2), color:Lerp(Color3.new(1, 1, 0.8), 0.35), { Collide = false, Shadow = false })
end

local GREENS = { Color3.fromRGB(46, 150, 64), Color3.fromRGB(72, 178, 70), Color3.fromRGB(34, 122, 58), Color3.fromRGB(104, 196, 78) }

-- A giant leafy plant: a fan of huge leaves from the ground
local function bigPlant(at: Vector3, size: number, seed: number)
	local count = 6 + seed % 3
	for i = 1, count do
		leaf("Plants", at + Vector3.new(0, 0.6 + (i % 3) * 0.5, 0), size * (0.75 + (i % 3) * 0.15), i * 360 / count + seed * 17, 18 + (i % 4) * 12, GREENS[(i + seed) % #GREENS + 1])
	end
end

-- A flower: a yellow middle and five petals (orange or pink)
local function flower(at: Vector3, color: Color3, size: number)
	local g = "Flowers"
	post(g, "Stem", at, size * 1.6, 0.08, GREENS[3], { Collide = false })
	local top = at + Vector3.new(0, size * 1.6, 0)
	for i = 1, 5 do
		local cf = CFrame.new(top) * CFrame.Angles(0, math.rad(i * 72), 0) * CFrame.Angles(math.rad(-20), 0, 0)
		local p = add(g, "Petal", Vector3.new(size * 0.6, 0.12, size), cf * CFrame.new(0, 0, -size * 0.45), color, { Collide = false, Shadow = false })
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	add(g, "Centre", Vector3.one * size * 0.45, CFrame.new(top + Vector3.new(0, 0.1, 0)), Color3.fromRGB(255, 220, 60), { Shape = Enum.PartType.Ball, Collide = false })
end

-- A jungle tree: a tall trunk with root flares and a canopy of round leaf clumps
local function jungleTree(at: Vector3, height: number, seed: number)
	local g = "Trees"
	local bark = Color3.fromRGB(120, 86, 58)
	post(g, "Trunk", at, height, 1.6 + height * 0.03, bark, { Material = Enum.Material.Wood })
	for i = 1, 4 do
		local a = math.rad(i * 90 + seed * 23)
		add(g, "Root", Vector3.new(1.2, 3, 4.5), CFrame.new(at + Vector3.new(math.cos(a) * 2, 1.2, math.sin(a) * 2)) * CFrame.Angles(0, -a, 0) * CFrame.Angles(math.rad(-30), math.rad(90), 0), bark, { Material = Enum.Material.Wood })
	end
	local top = at + Vector3.new(0, height, 0)
	for i = 1, 5 do
		local a = math.rad(i * 72 + seed * 31)
		local r = if i == 5 then 0 else 5 + (i % 2) * 2
		local s = 11 + (i + seed) % 3 * 3
		add(g, "Canopy", Vector3.one * s, CFrame.new(top + Vector3.new(math.cos(a) * r, (i % 3) * 2 - 1 + (if i == 5 then 3 else 0), math.sin(a) * r)), GREENS[(i + seed) % #GREENS + 1], { Shape = Enum.PartType.Ball, Material = Enum.Material.Grass, Collide = false })
	end
end

-- A hanging vine (a green curved Beam) between two points, with a few leaves along it
local function vine(from: Vector3, to: Vector3, sag: number)
	local foot = add("Vines", "VineEnd", Vector3.one * 0.3, CFrame.new(from), GREENS[3], { Collide = false, Transparency = 1 })
	local tip = add("Vines", "VineEnd", Vector3.one * 0.3, CFrame.new(to), GREENS[3], { Collide = false, Transparency = 1 })
	local a0 = Instance.new("Attachment")
	a0.Parent = foot
	local a1 = Instance.new("Attachment")
	a1.Parent = tip
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Width0 = 0.35
	b.Width1 = 0.25
	b.Color = ColorSequence.new(Color3.fromRGB(58, 140, 52))
	b.LightInfluence = 1
	b.FaceCamera = true
	b.Segments = 14
	b.CurveSize0 = -sag
	b.CurveSize1 = sag
	b.Parent = foot
	for k = 1, 4 do
		local at = from:Lerp(to, k / 5) - Vector3.new(0, math.sin(k / 5 * math.pi) * sag * 0.55, 0)
		add("Vines", "VineLeaf", Vector3.new(0.9, 0.12, 1.6), CFrame.new(at) * CFrame.Angles(math.rad(40), math.rad(k * 70), 0), GREENS[k % #GREENS + 1], { Collide = false, Shadow = false })
	end
end

-- A mossy boulder
local function boulder(at: Vector3, size: number)
	add("Rocks", "Boulder", Vector3.new(size * 1.3, size, size * 1.1), CFrame.new(at + Vector3.new(0, size * 0.3, 0)) * CFrame.Angles(0, math.rad(at.X * 13 % 90), 0), Color3.fromRGB(134, 138, 128), { Shape = Enum.PartType.Ball, Material = Enum.Material.Slate })
	add("Rocks", "Moss", Vector3.new(size * 1.1, size * 0.4, size * 0.9), CFrame.new(at + Vector3.new(0, size * 0.72, 0)), Color3.fromRGB(86, 160, 66), { Shape = Enum.PartType.Ball, Material = Enum.Material.Grass, Collide = false })
end

-- A rope bridge between two points: planks with a sag, rope rails (Beams) and posts at both ends
local function ropeBridge(from: Vector3, to: Vector3, sag: number, walkable: boolean)
	local g = "RopeBridges"
	local length = (to - from).Magnitude
	local dir = (to - from).Unit
	local look = CFrame.lookAt(Vector3.zero, dir)
	local side = dir:Cross(Vector3.yAxis).Unit
	local planks = math.floor(length / 1.6)
	local wood = { Color3.fromRGB(176, 128, 78), Color3.fromRGB(156, 110, 66) }
	for i = 0, planks do
		local k = i / planks
		local at = from:Lerp(to, k) - Vector3.new(0, math.sin(k * math.pi) * sag, 0)
		add(g, "Plank", Vector3.new(5, 0.35, 1.3), CFrame.new(at) * look * CFrame.Angles(0, 0, math.rad(((i * 7) % 5) - 2)), wood[i % 2 + 1], { Material = Enum.Material.WoodPlanks, Collide = walkable })
	end
	for _, s in { -1, 1 } do
		local ends = {}
		for _, at in { from, to } do
			local p = post(g, "BridgePost", at + side * s * 2.8 - Vector3.new(0, 1, 0), 5, 0.3, Color3.fromRGB(120, 86, 58), { Material = Enum.Material.Wood })
			local a = Instance.new("Attachment")
			a.Position = Vector3.new(2.3, 0, 0) -- (the post's top: cylinders run along X)
			a.Parent = p
			table.insert(ends, a)
		end
		local rope = Instance.new("Beam")
		rope.Attachment0 = ends[1]
		rope.Attachment1 = ends[2]
		rope.Width0 = 0.2
		rope.Width1 = 0.2
		rope.Color = ColorSequence.new(Color3.fromRGB(214, 180, 120))
		rope.FaceCamera = true
		rope.Segments = 16
		rope.CurveSize0 = -sag * 1.3
		rope.CurveSize1 = sag * 1.3
		rope.Parent = ends[1].Parent
	end
	if walkable then
		-- invisible rails so nobody falls off the walkable bridge
		for _, s in { -1, 1 } do
			local mid = (from + to) / 2 + side * s * 2.8 + Vector3.new(0, 1.5 - sag * 0.6, 0)
			add(g, "BridgeRail", Vector3.new(0.4, 4 + sag, length), CFrame.new(mid) * look, WHITE, { Transparency = 1 })
		end
	end
end

-- A waterfall: a sheet of falling water (scrolling Beam) from `top` down to `bottomY`, with foam where it lands
local function waterfall(top: Vector3, bottomY: number, width: number)
	local g = "Waterfalls"
	local height = top.Y - bottomY
	local sheet = add(g, "Sheet", Vector3.new(width, height, 0.6), CFrame.new(top.X, bottomY + height / 2, top.Z), Color3.fromRGB(150, 228, 244), { Collide = false, Transparency = 0.1, Shadow = false })
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, height / 2, 0.5)
	a0.Parent = sheet
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -height / 2, 0.5)
	a1.Parent = sheet
	local flow = Instance.new("Beam")
	flow.Attachment0 = a0
	flow.Attachment1 = a1
	flow.Width0 = width
	flow.Width1 = width * 1.1
	flow.Texture = Config.BallVfx.Images.TrailWisp
	flow.TextureMode = Enum.TextureMode.Wrap
	flow.TextureLength = 10
	flow.TextureSpeed = -1.4
	flow.Color = ColorSequence.new(WHITE, Color3.fromRGB(200, 244, 255))
	flow.LightEmission = 0.4
	flow.Transparency = NumberSequence.new(0.05)
	flow.Segments = 4
	flow.Parent = sheet
	-- the lip of the fall and the foam cloud at its foot
	add(g, "Lip", Vector3.new(width + 1, 0.8, 2.4), CFrame.new(top + Vector3.new(0, 0.2, 0.6)), Color3.fromRGB(220, 248, 255), { Collide = false })
	local foam = add(g, "Foam", Vector3.new(width, 1, 4), CFrame.new(top.X, bottomY + 0.5, top.Z + 2), WHITE, { Collide = false, Transparency = 1 })
	local e = Instance.new("ParticleEmitter")
	e.Texture = Config.BallVfx.Images.Smoke
	e.Color = ColorSequence.new(WHITE, Color3.fromRGB(220, 246, 255))
	e.LightEmission = 0.15
	e.Size = NumberSequence.new(width * 0.25, width * 0.5)
	e.Transparency = NumberSequence.new(0.35, 1)
	e.Lifetime = NumberRange.new(1.2, 2)
	e.Speed = NumberRange.new(3, 6)
	e.SpreadAngle = Vector2.new(50, 50)
	e.Rate = 6 + width * 0.6
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-20, 20)
	e.Parent = foam
end

---------------------------------------------------------------------------------------------------------------
-- Zone 3: Jungle Falls
---------------------------------------------------------------------------------------------------------------
local JUNGLE = {
	Ground = { X0 = -150, X1 = 168, Z0 = -3596, Z1 = -3330 }, -- the grass valley floor (zone 1's layout)
	EastBank = { X0 = 196, X1 = 270, Z0 = -3596, Z1 = -3330 }, -- across the river: the temple
	PoolTop = 846.4, -- the waterfall pool and the river, 2.25 studs under the grass
	CliffZ = -3640, -- the cliff face behind the pool
	CliffTop = 848.65 + 70,
	Grass = Color3.fromRGB(96, 184, 84),
	Dirt = Color3.fromRGB(196, 158, 104),
	Stone = Color3.fromRGB(150, 156, 132),
	Orange = Color3.fromRGB(255, 150, 50),
	Aqua = Color3.fromRGB(70, 210, 220),
	Pink = Color3.fromRGB(255, 104, 150),
	Thatch = Color3.fromRGB(222, 184, 104),
	Bamboo = { Color3.fromRGB(176, 206, 96), Color3.fromRGB(214, 222, 110) },
}

local function buildJungle(info: any)
	local palette = info.Palette
	local gr = JUNGLE.Ground

	-- The valley floor: grass, with a dirt clearing round the stations and the spawn
	add("Ground", "Grass", Vector3.new(gr.X1 - gr.X0, 6, gr.Z1 - gr.Z0), CFrame.new((gr.X0 + gr.X1) / 2, TOP - 3, (gr.Z0 + gr.Z1) / 2), JUNGLE.Grass, { Material = Enum.Material.Grass })
	add("Ground", "Clearing", Vector3.new(118, 0.1, 50), CFrame.new(-34, TOP + 0.03, -3410), JUNGLE.Dirt, { Material = Enum.Material.Ground, Collide = false })
	add("Ground", "PathToEgg", Vector3.new(40, 0.1, 10), CFrame.new(18, TOP + 0.03, -3436), JUNGLE.Dirt, { Material = Enum.Material.Ground, Collide = false })
	add("Ground", "PathToGates", Vector3.new(12, 0.1, 40), CFrame.new(-96, TOP + 0.03, -3410), JUNGLE.Dirt, { Material = Enum.Material.Ground, Collide = false })
	add("Ground", "PathToBridge", Vector3.new(96, 0.1, 8), CFrame.new(120, TOP + 0.03, -3470), JUNGLE.Dirt, { Material = Enum.Material.Ground, Collide = false })
	local e = JUNGLE.EastBank
	add("Ground", "EastBank", Vector3.new(e.X1 - e.X0, 6, e.Z1 - e.Z0), CFrame.new((e.X0 + e.X1) / 2, TOP - 3, (e.Z0 + e.Z1) / 2), JUNGLE.Grass, { Material = Enum.Material.Grass })
	-- an invisible fence round the edges you could fall off (the pool's edge, the river banks)
	local function fence(size: Vector3, at: Vector3)
		add("Ground", "EdgeFence", size, CFrame.new(at), WHITE, { Transparency = 1 })
	end
	fence(Vector3.new(gr.X1 - gr.X0, 8, 1), Vector3.new((gr.X0 + gr.X1) / 2, TOP + 4, gr.Z0 - 0.5))
	fence(Vector3.new(1, 8, gr.Z1 - gr.Z0), Vector3.new(gr.X1 + 0.5, TOP + 4, (gr.Z0 + gr.Z1) / 2 + 12)) -- (gap at the bridge)
	fence(Vector3.new(1, 8, gr.Z1 - gr.Z0), Vector3.new(e.X0 - 0.5, TOP + 4, (gr.Z0 + gr.Z1) / 2 + 12))
	fence(Vector3.new(e.X1 - e.X0, 8, 1), Vector3.new((e.X0 + e.X1) / 2, TOP + 4, e.Z0 - 0.5))

	-- The lane: aqua gutters, mossy stone walls with a wood cap, the pit and a bamboo back wall
	local length = LANE.FoulZ - LANE.EndZ
	local midZ = (LANE.FoulZ + LANE.EndZ) / 2
	for _, side in { -1, 1 } do
		add("Lane", "Gutter", Vector3.new(2.4, 0.3, length), CFrame.new(LANE.Centre + side * (LANE.Width / 2 + 1.2), TOP + 0.05, midZ), palette.Edge)
		add("Lane", "GutterWall", Vector3.new(0.9, 1.6, length + 10), CFrame.new(LANE.Centre + side * (LANE.Width / 2 + 2.8), TOP + 0.8, midZ - 5), JUNGLE.Stone, { Material = Enum.Material.Slate })
		add("Lane", "GutterCap", Vector3.new(1.1, 0.3, length + 10), CFrame.new(LANE.Centre + side * (LANE.Width / 2 + 2.8), TOP + 1.75, midZ - 5), JUNGLE.Orange)
	end
	add("Lane", "Pit", Vector3.new(LANE.Width + 6, 0.3, 8), CFrame.new(LANE.Centre, TOP + 0.02, LANE.EndZ - 4), Color3.fromRGB(52, 70, 44))
	local backZ = LANE.EndZ - 8.6
	local wallWidth = LANE.Width + 6.4
	local canes = math.floor(wallWidth / 1.4)
	for i = 1, canes do
		local sx = LANE.Centre - wallWidth / 2 + wallWidth * (i - 0.5) / canes
		post("Lane", "Bamboo", Vector3.new(sx, TOP, backZ), 8 + (i % 3) * 0.6, 0.7, JUNGLE.Bamboo[i % 2 + 1])
	end
	add("Lane", "BambooTie", Vector3.new(wallWidth, 0.4, 1.7), CFrame.new(LANE.Centre, TOP + 2.5, backZ), Color3.fromRGB(150, 104, 60), { Collide = false })
	add("Lane", "BambooTie", Vector3.new(wallWidth, 0.4, 1.7), CFrame.new(LANE.Centre, TOP + 6, backZ), Color3.fromRGB(150, 104, 60), { Collide = false })

	-- The JUNGLE FALLS sign behind the pit: two carved stone pillars wrapped in vines, a wooden board
	local signZ = backZ - 3
	for _, side in { -1, 1 } do
		local sx = LANE.Centre + side * 36
		for k = 0, 4 do
			add("Arch", "Pillar", Vector3.new(4.6 - k * 0.2, 4.8, 4.6 - k * 0.2), CFrame.new(sx, TOP + 2.4 + k * 4.8, signZ), if k % 2 == 0 then JUNGLE.Stone else JUNGLE.Stone:Lerp(Color3.new(0, 0, 0), 0.12), { Material = Enum.Material.Slate })
			add("Arch", "Glyph", Vector3.new(2, 2, 0.3), CFrame.new(sx, TOP + 2.4 + k * 4.8, signZ + 2.3), if k % 2 == 0 then JUNGLE.Orange else JUNGLE.Aqua, { Collide = false })
		end
		add("Arch", "PillarTop", Vector3.new(6, 1.4, 6), CFrame.new(sx, TOP + 24.7, signZ), Color3.fromRGB(120, 126, 104), { Material = Enum.Material.Slate })
		bigPlant(Vector3.new(sx, TOP + 25.4, signZ), 5, side + 3)
		vine(Vector3.new(sx - 2.4, TOP + 24, signZ + 2.4), Vector3.new(sx + 2.4, TOP + 6, signZ + 2.4), 2)
	end
	local board = add("Arch", "NameBoard", Vector3.new(64, 11, 1), CFrame.new(LANE.Centre, TOP + 19, signZ), Color3.fromRGB(166, 116, 66), { Material = Enum.Material.WoodPlanks })
	add("Arch", "NameBoardTrim", Vector3.new(66, 13, 0.6), CFrame.new(LANE.Centre, TOP + 19, signZ - 0.5), Color3.fromRGB(110, 76, 44), { Material = Enum.Material.Wood })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- (faces the bowlers, +Z)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	gui.Parent = board
	local title = label(gui, "JUNGLE FALLS", UDim2.fromScale(0.94, 0.62), UDim2.fromScale(0.5, 0.4), Color3.new(1, 1, 1))
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(200, 255, 110), Color3.fromRGB(255, 170, 60))
	gradient.Rotation = 90
	gradient.Parent = title
	label(gui, "ZONE 3", UDim2.fromScale(0.3, 0.26), UDim2.fromScale(0.5, 0.83), JUNGLE.Aqua)
	for i = 1, 6 do
		leaf("Arch", Vector3.new(LANE.Centre - 32 + (i - 1) * 12.8, TOP + 24.4, signZ - 0.4), 6, 180 + (i % 2) * 20 - 10, -30, GREENS[i % #GREENS + 1])
	end

	-- Flower garlands over the lane (in place of zone 2's bunting), on bamboo poles at the gutter walls
	local garland = { JUNGLE.Orange, GREENS[2], JUNGLE.Pink, Color3.fromRGB(255, 220, 60), GREENS[4] }
	for _, bz in { -3470, -3505, -3540 } do
		for _, side in { -1, 1 } do
			post("Garlands", "GarlandPole", Vector3.new(LANE.Centre + side * (LANE.Width / 2 + 2.8), TOP + 1.9, bz), 17, 0.4, JUNGLE.Bamboo[1])
		end
		bunting(Vector3.new(LANE.Centre - LANE.Width / 2 - 2.8, TOP + 18.4, bz), Vector3.new(LANE.Centre + LANE.Width / 2 + 2.8, TOP + 18.4, bz), garland)
	end

	-- Thatched leaf roofs over the sell pad and the shop, on bamboo posts
	local function thatch(back: Vector3, width: number)
		for _, s in { -1, 1 } do
			post("Huts", "HutPost", back + Vector3.new(s * (width / 2 - 0.3), 0, -3.4), 10.6, 0.35, JUNGLE.Bamboo[1], { Collide = false })
		end
		local strips = math.floor(width / 1.8)
		for i = 1, strips do
			local x = -width / 2 + width * (i - 0.5) / strips
			add("Huts", "Thatch", Vector3.new(width / strips + 0.4, 0.5, 5.6), CFrame.new(back + Vector3.new(x, 11, -1.2)) * CFrame.Angles(math.rad(-18), 0, math.rad((i % 2) * 4 - 2)), if i % 2 == 0 then JUNGLE.Thatch else JUNGLE.Thatch:Lerp(Color3.new(1, 1, 1), 0.15), { Collide = false })
			leaf("Huts", back + Vector3.new(x, 10.2, -3.6), 2.4, 180, 70, GREENS[i % #GREENS + 1])
		end
	end
	local sell, shop = CORE.Sell, CORE.Shop
	thatch(sell.Position + Vector3.new(0, 0, sell.Radius + 2.2), 12)
	thatch(shop.Position + Vector3.new(0, 0, shop.Radius + 2.2), 11)

	-- The pool under the falls and the cliff behind it are Terrain (ZoneMaps.Terrain); three waterfalls pour into it
	local pool = JUNGLE.PoolTop
	local fallZ = JUNGLE.CliffZ + 4.5 -- (in front of the rock: Terrain rounds to 4-stud cells)
	waterfall(Vector3.new(-104, JUNGLE.CliffTop, fallZ), pool, 14)
	waterfall(Vector3.new(-36, JUNGLE.CliffTop, fallZ), pool, 26)
	waterfall(Vector3.new(44, JUNGLE.CliffTop, fallZ), pool, 12)
	waterfall(Vector3.new(130, JUNGLE.CliffTop, fallZ), pool, 10)
	-- trees and giant plants along the cliff top, leafy ledges and vines down its face
	for i = 0, 13 do
		local x = -190 + i * 34 + (i % 3) * 5
		if math.abs(x + 104) > 12 and math.abs(x + 36) > 18 and math.abs(x - 44) > 10 and math.abs(x - 130) > 10 then
			jungleTree(Vector3.new(x, JUNGLE.CliffTop + 2, JUNGLE.CliffZ - 10 - (i % 2) * 8), 14 + (i % 3) * 5, i)
		end
		bigPlant(Vector3.new(x + 15, JUNGLE.CliffTop + 2, JUNGLE.CliffZ - 3), 7, i)
	end
	for i = 0, 22 do
		local x = -180 + i * 15
		vine(Vector3.new(x, JUNGLE.CliffTop + 1, fallZ - 1), Vector3.new(x + 2, JUNGLE.CliffTop - 14 - (i * 7) % 24, fallZ - 0.5), 1)
	end
	-- rocks round the pool, and lily pads on it
	for i, at in { { -140, -3604 }, { -120, -3628 }, { 8, -3630 }, { 80, -3606 }, { 150, -3624 }, { 176, -3600 } } do
		boulder(Vector3.new(at[1], pool - 1.5, at[2]), 5 + i % 3 * 2)
	end
	for i = 1, 14 do
		local at = Vector3.new(-140 + (i * 23) % 300, pool + 0.1, -3602 - (i * 11) % 30)
		add("Pool", "LilyPad", Vector3.new(0.15, 3 + i % 3, 3 + i % 3), CFrame.new(at) * UP, GREENS[i % #GREENS + 1], { Shape = Enum.PartType.Cylinder, Collide = false })
		if i % 3 == 0 then
			flower(at, JUNGLE.Pink, 0.8)
		end
	end
	-- a high rope bridge across the cliff face, between the falls (seen over the sign)
	ropeBridge(Vector3.new(-92, TOP + 42, JUNGLE.CliffZ + 8), Vector3.new(-50, TOP + 42, JUNGLE.CliffZ + 8), 3, false)
	ropeBridge(Vector3.new(-22, TOP + 38, JUNGLE.CliffZ + 8), Vector3.new(36, TOP + 38, JUNGLE.CliffZ + 8), 4, false)
	for _, at in { { -92, 42 }, { -50, 42 }, { -22, 38 }, { 36, 38 } } do
		add("RopeBridges", "Ledge", Vector3.new(8, 2, 8), CFrame.new(at[1], TOP + at[2] - 1.2, JUNGLE.CliffZ + 7), Color3.fromRGB(120, 124, 110), { Material = Enum.Material.Slate })
	end

	-- The river along the east side (Terrain water) with a walkable rope bridge to the temple bank
	ropeBridge(Vector3.new(gr.X1 - 2, TOP + 0.2, -3470), Vector3.new(e.X0 + 2, TOP + 0.2, -3470), 1.2, true)

	-- The temple ruin on the east bank: four stepped stone tiers, a stair, a gold sun on top, moss and vines
	local temple = Vector3.new(240, TOP, -3500)
	local S = 1.3 -- (the whole ruin's scale)
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(temple + Vector3.new(x, y, z) * S)
	end
	for k = 0, 3 do
		local w = 30 - k * 7
		add("Temple", "Tier", Vector3.new(w, 6, w) * S, at(0, 3 + k * 6, 0), if k % 2 == 0 then JUNGLE.Stone else JUNGLE.Stone:Lerp(Color3.new(0, 0, 0), 0.1), { Material = Enum.Material.Slate })
		add("Temple", "Moss", Vector3.new(w + 0.2, 0.6, w * 0.6) * S, at(0, 6 + k * 6, w * 0.15), Color3.fromRGB(96, 168, 70), { Material = Enum.Material.Grass, Collide = false })
	end
	add("Temple", "Stair", Vector3.new(7, 24, 16) * S, at(-15 - 8, 12, 0) * CFrame.Angles(0, math.rad(90), 0), JUNGLE.Stone:Lerp(Color3.new(1, 1, 1), 0.1), { Class = "WedgePart", Material = Enum.Material.Slate })
	add("Temple", "Shrine", Vector3.new(8, 7, 8) * S, at(0, 27.5, 0), Color3.fromRGB(128, 134, 112), { Material = Enum.Material.Slate })
	add("Temple", "Door", Vector3.new(0.4, 4.5, 3.4) * S, at(-4.1, 26.3, 0), Color3.fromRGB(40, 46, 36), { Collide = false })
	add("Temple", "Sun", Vector3.new(0.6, 5, 5) * S, at(0, 36, 0), Color3.fromRGB(255, 200, 60), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal })
	add("Temple", "SunStand", Vector3.new(1.4, 4, 1.4) * S, at(0, 32, 0), Color3.fromRGB(128, 134, 112), { Material = Enum.Material.Slate })
	for i = 1, 4 do
		vine((at(-15 + i * 2, 22 - i * 2, -15 + i * 6)).Position, (at(-15.4, 4, -15 + i * 6.5)).Position, 1.4)
	end
	for _, o in { { -21, -16 }, { -21, 16 } } do
		add("Temple", "Statue", Vector3.new(3, 6, 3) * S, at(o[1], 3, o[2]), JUNGLE.Stone, { Material = Enum.Material.Slate })
		add("Temple", "StatueHead", Vector3.new(3.6, 3.2, 3.6) * S, at(o[1], 7.6, o[2]), JUNGLE.Stone:Lerp(Color3.new(0, 0, 0), 0.15), { Material = Enum.Material.Slate })
		add("Temple", "StatueEyes", Vector3.new(0.3, 0.6, 2.4) * S, at(o[1] - 1.85, 8, o[2]), JUNGLE.Aqua, { Collide = false })
	end

	-- Trees, palms, giant plants and flowers all round the edges (the play area stays open)
	local trees = {
		{ -136, -3340, 34 }, { -140, -3380, 28 }, { -138, -3470, 32 }, { -132, -3540, 30 }, { -140, -3580, 36 },
		{ -108, -3338, 26 }, { 30, -3336, 30 }, { 80, -3340, 34 }, { 128, -3338, 28 }, { 156, -3380, 30 },
		{ 156, -3560, 32 }, { 210, -3340, 32 }, { 262, -3360, 36 }, { 262, -3430, 30 }, { 210, -3580, 34 }, { 262, -3580, 30 },
	}
	for i, t in trees do
		jungleTree(Vector3.new(t[1], TOP, t[2]), t[3], i)
	end
	for _, p in { { 60, -3390, 15, 40 }, { 112, -3420, 17, 200 }, { 140, -3500, 14, 300 }, { 100, -3570, 16, 120 }, { -120, -3430, 15, 80 } } do
		palm(Vector3.new(p[1], TOP, p[2]), p[3], p[4])
	end
	local plants = {
		{ -126, -3360 }, { -120, -3500 }, { -124, -3560 }, { -100, -3590 }, { 30, -3590 }, { 60, -3460 }, { 84, -3520 },
		{ 120, -3584 }, { 150, -3440 }, { 76, -3360 }, { -70, -3344 }, { 0, -3346 }, { 220, -3440 }, { 250, -3560 },
	}
	for i, p in plants do
		bigPlant(Vector3.new(p[1], TOP, p[2]), 6 + i % 3 * 2, i)
	end
	local flowerColors = { JUNGLE.Orange, JUNGLE.Pink, Color3.fromRGB(255, 120, 60) }
	for i = 1, 36 do
		local x = if i % 2 == 0 then 22 + (i * 37) % 140 else -140 + (i * 29) % 46
		local z = -3340 - (i * 53) % 250
		flower(Vector3.new(x, TOP, z), flowerColors[i % #flowerColors + 1], 0.9 + (i % 3) * 0.3)
	end
	for _, b in { { -128, -3410, 4 }, { 64, -3420, 3 }, { 140, -3540, 5 }, { -110, -3520, 3 }, { 100, -3350, 4 } } do
		boulder(Vector3.new(b[1], TOP, b[2]), b[3])
	end
end

---------------------------------------------------------------------------------------------------------------
-- Canyon props
---------------------------------------------------------------------------------------------------------------
local CANYON = {
	Ground = { X0 = -150, X1 = 280, Z0 = -3596, Z1 = -3330 }, -- the sandy canyon floor (zone 1's layout)
	Pond = { X0 = 196, X1 = 256, Z0 = -3536, Z1 = -3464 }, -- the palm oasis pond, east of the lane
	LakeTop = 846.4, -- the turquoise lake past the pit and the pond, 2.25 studs under the sand
	Sand = Color3.fromRGB(236, 182, 124),
	Path = Color3.fromRGB(246, 208, 162),
	Terracotta = Color3.fromRGB(206, 104, 70),
	RedRock = Color3.fromRGB(184, 84, 58),
	Peach = Color3.fromRGB(240, 178, 132),
	Turquoise = Color3.fromRGB(40, 196, 196),
	Gold = Color3.fromRGB(255, 196, 64),
	Adobe = Color3.fromRGB(228, 162, 112),
	Cactus = { Color3.fromRGB(86, 158, 82), Color3.fromRGB(70, 140, 74) },
	Palm = { Color3.fromRGB(70, 176, 74), Color3.fromRGB(110, 200, 80) },
}

-- A rock stack (a hoodoo or a butte): blocks in red / peach bands, a wider cap rock on top
local function hoodoo(at: Vector3, height: number, width: number, seed: number)
	local g = "Rocks"
	local bands = math.max(3, math.floor(height / 5))
	local step = height / bands
	for i = 0, bands - 1 do
		local w = width * (1 - i * 0.05) * (if i % 2 == 0 then 1 else 0.92)
		local turn = math.rad((seed * 37 + i * 11) % 30 - 15)
		add(g, "Band", Vector3.new(w, step + 0.2, w * 0.9), CFrame.new(at + Vector3.new(0, step * (i + 0.5), 0)) * CFrame.Angles(0, turn, 0), if i % 2 == 0 then CANYON.RedRock else CANYON.Terracotta, { Material = Enum.Material.Sandstone })
	end
	add(g, "CapRock", Vector3.new(width * 1.15, step * 0.7, width * 1.05), CFrame.new(at + Vector3.new(0, height + step * 0.3, 0)) * CFrame.Angles(0, math.rad(seed * 13 % 40), 0), CANYON.Peach, { Material = Enum.Material.Sandstone })
end

-- A saguaro cactus: a trunk, one or two bent arms, round tops, sometimes a pink flower
local function cactus(at: Vector3, height: number, seed: number)
	local g = "Cacti"
	local color = CANYON.Cactus[seed % 2 + 1]
	local r = 0.9 + height * 0.03
	post(g, "Trunk", at, height, r, color, { Material = Enum.Material.Grass })
	add(g, "Top", Vector3.one * r * 2, CFrame.new(at + Vector3.new(0, height, 0)), color, { Shape = Enum.PartType.Ball, Material = Enum.Material.Grass })
	for _, s in { -1, 1 } do
		if (seed + (s + 1)) % 3 ~= 0 then
			local armY = height * (0.4 + ((seed + s) % 3) * 0.1)
			local out = 2.2 + seed % 2
			local turn = CFrame.Angles(0, math.rad(seed * 40), 0)
			local base = CFrame.new(at) * turn
			add(g, "Arm", Vector3.new(out, r * 1.5, r * 1.5), base * CFrame.new(s * out / 2, armY, 0), color, { Material = Enum.Material.Grass })
			local up = height * 0.3
			add(g, "Arm", Vector3.new(r * 1.5, up, r * 1.5), base * CFrame.new(s * out, armY + up / 2, 0), color, { Material = Enum.Material.Grass })
			add(g, "ArmTop", Vector3.one * r * 1.5, base * CFrame.new(s * out, armY + up, 0), color, { Shape = Enum.PartType.Ball, Material = Enum.Material.Grass })
		end
	end
	if seed % 3 == 0 then
		add(g, "Flower", Vector3.one * r * 0.9, CFrame.new(at + Vector3.new(0, height + r * 0.8, 0)), Color3.fromRGB(255, 110, 170), { Shape = Enum.PartType.Ball, Collide = false })
	end
end

-- A hot-air balloon high up: a striped envelope (sphere slices, narrower at the bottom), ropes and a basket
local function balloon(at: Vector3, stripes: { Color3 })
	local g = "Balloons"
	local R = 9
	for i = -5, 4 do
		local y = i * 1.9
		local r = R * math.sqrt(math.max(0.05, 1 - (y / (R + 0.6)) ^ 2))
		if i < 0 then
			r *= 1 + i * 0.06 -- (a teardrop: narrower toward the basket)
		end
		add(g, "Envelope", Vector3.new(2, r * 2, r * 2), CFrame.new(at + Vector3.new(0, y, 0)) * UP, stripes[(i + 5) % #stripes + 1], { Shape = Enum.PartType.Cylinder, Collide = false })
	end
	local basket = at - Vector3.new(0, R + 6, 0)
	add(g, "Basket", Vector3.new(3, 2.4, 3), CFrame.new(basket), Color3.fromRGB(150, 100, 60), { Collide = false, Material = Enum.Material.WoodPlanks })
	for _, o in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local from = basket + Vector3.new(o[1] * 1.4, 1.2, o[2] * 1.4)
		local to = at + Vector3.new(o[1] * 3.2, -R + 0.5, o[2] * 3.2)
		add(g, "Rope", Vector3.new(0.12, 0.12, (to - from).Magnitude), CFrame.lookAt((from + to) / 2, to), Color3.fromRGB(90, 70, 50), { Collide = false, Shadow = false })
	end
	add(g, "Burner", Vector3.one * 0.9, CFrame.new(basket + Vector3.new(0, 2.6, 0)), Color3.fromRGB(255, 160, 60), { Shape = Enum.PartType.Ball, Collide = false, Material = Enum.Material.Neon })
end

-- An adobe house: rounded clay walls, a parapet, wooden roof beams poking out, a turquoise door and window
local function adobe(at: Vector3, size: Vector3, face: number)
	local g = "Adobe"
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(face), 0)
	add(g, "Walls", size, base * CFrame.new(0, size.Y / 2, 0), CANYON.Adobe, { Material = Enum.Material.Sand })
	add(g, "Parapet", Vector3.new(size.X + 0.6, 1, size.Z + 0.6), base * CFrame.new(0, size.Y + 0.3, 0), CANYON.Adobe:Lerp(Color3.new(1, 1, 1), 0.12), { Material = Enum.Material.Sand })
	for k = -2, 2 do
		add(g, "Viga", Vector3.new(0.6, 0.6, 1.6), base * CFrame.new(k * size.X / 5.5, size.Y - 1, -size.Z / 2 - 0.6), Color3.fromRGB(120, 80, 50), { Material = Enum.Material.Wood, Collide = false })
	end
	add(g, "Door", Vector3.new(2.6, 4.4, 0.3), base * CFrame.new(-size.X * 0.2, 2.2, -size.Z / 2 - 0.1), CANYON.Turquoise)
	add(g, "Window", Vector3.new(1.8, 1.8, 0.3), base * CFrame.new(size.X * 0.25, size.Y * 0.6, -size.Z / 2 - 0.1), CANYON.Turquoise:Lerp(Color3.new(0, 0, 0), 0.25))
	-- a string of red chillies by the door
	for k = 0, 4 do
		add(g, "Chilli", Vector3.new(0.5, 0.9, 0.5), base * CFrame.new(-size.X * 0.2 + 2, 4 - k * 0.8, -size.Z / 2 - 0.4), Color3.fromRGB(220, 40, 40), { Collide = false, Shadow = false })
	end
end

-- A peaked market tent: four posts and a striped canopy (two slopes), open on every side
local function tent(at: Vector3, width: number, a: Color3, b: Color3, turn: number)
	local g = "Tents"
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(turn), 0)
	local half = width / 2
	for _, o in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		post(g, "TentPost", (base * CFrame.new(o[1] * (half - 0.3), 0, o[2] * (half - 0.3))).Position, 7.5, 0.2, Color3.fromRGB(150, 100, 60), { Collide = false })
	end
	local strips = math.max(3, math.floor(width / 1.6))
	for i = 1, strips do
		local x = -half + width * (i - 0.5) / strips
		for _, s in { -1, 1 } do
			add(g, "Canopy", Vector3.new(width / strips, 0.25, half * 1.16), base * CFrame.new(x, 8.6, s * half * 0.5) * CFrame.Angles(math.rad(s * 30), 0, 0), if i % 2 == 0 then a else b, { Collide = false })
		end
	end
	add(g, "Ridge", Vector3.new(width + 0.4, 0.4, 0.4), base * CFrame.new(0, 9.9, 0), CANYON.Gold, { Collide = false })
end

local function canyonPalm(at: Vector3, height: number, lean: number)
	palm(at, height, lean)
end

---------------------------------------------------------------------------------------------------------------
-- Zone 4: Canyon Oasis
---------------------------------------------------------------------------------------------------------------
local function buildCanyon(info: any)
	local palette = info.Palette
	local gr, pond = CANYON.Ground, CANYON.Pond

	-- The canyon floor: warm sand slabs round the oasis pond (a hole for its Terrain water), packed paths
	local function slab(x0: number, x1: number, z0: number, z1: number)
		add("Ground", "Sand", Vector3.new(x1 - x0, 6, z1 - z0), CFrame.new((x0 + x1) / 2, TOP - 3, (z0 + z1) / 2), CANYON.Sand, { Material = Enum.Material.Sand })
	end
	slab(gr.X0, pond.X0, gr.Z0, gr.Z1)
	slab(pond.X0, gr.X1, pond.Z1, gr.Z1)
	slab(pond.X0, gr.X1, gr.Z0, pond.Z0)
	slab(pond.X1, gr.X1, pond.Z0, pond.Z1)
	add("Ground", "Clearing", Vector3.new(118, 0.1, 50), CFrame.new(-34, TOP + 0.03, -3410), CANYON.Path, { Material = Enum.Material.Sand, Collide = false })
	add("Ground", "PathToEgg", Vector3.new(40, 0.1, 10), CFrame.new(18, TOP + 0.03, -3436), CANYON.Path, { Material = Enum.Material.Sand, Collide = false })
	add("Ground", "PathToGates", Vector3.new(12, 0.1, 40), CFrame.new(-96, TOP + 0.03, -3410), CANYON.Path, { Material = Enum.Material.Sand, Collide = false })
	add("Ground", "PathToOasis", Vector3.new(150, 0.1, 9), CFrame.new(112, TOP + 0.03, -3440), CANYON.Path, { Material = Enum.Material.Sand, Collide = false })
	-- turquoise tiles round the pond's edge, and an invisible fence round the lake and the pond
	for _, e in {
		{ Vector3.new(pond.X1 - pond.X0 + 2, 0.4, 1.4), Vector3.new((pond.X0 + pond.X1) / 2, TOP + 0.2, pond.Z0 - 0.7) },
		{ Vector3.new(pond.X1 - pond.X0 + 2, 0.4, 1.4), Vector3.new((pond.X0 + pond.X1) / 2, TOP + 0.2, pond.Z1 + 0.7) },
		{ Vector3.new(1.4, 0.4, pond.Z1 - pond.Z0), Vector3.new(pond.X0 - 0.7, TOP + 0.2, (pond.Z0 + pond.Z1) / 2) },
		{ Vector3.new(1.4, 0.4, pond.Z1 - pond.Z0), Vector3.new(pond.X1 + 0.7, TOP + 0.2, (pond.Z0 + pond.Z1) / 2) },
	} do
		add("Ground", "PondTiles", e[1], CFrame.new(e[2]), CANYON.Turquoise, { Material = Enum.Material.Slate })
		add("Ground", "EdgeFence", Vector3.new(e[1].X, 6, e[1].Z), CFrame.new(e[2] + Vector3.new(0, 3, 0)), WHITE, { Transparency = 1 })
	end
	add("Ground", "EdgeFence", Vector3.new(gr.X1 - gr.X0, 8, 1), CFrame.new((gr.X0 + gr.X1) / 2, TOP + 4, gr.Z0 - 0.5), WHITE, { Transparency = 1 })

	-- The lane: turquoise gutters, sandstone walls with a gold cap, the pit and an adobe back wall with a tile band
	local length = LANE.FoulZ - LANE.EndZ
	local midZ = (LANE.FoulZ + LANE.EndZ) / 2
	for _, side in { -1, 1 } do
		add("Lane", "Gutter", Vector3.new(2.4, 0.3, length), CFrame.new(LANE.Centre + side * (LANE.Width / 2 + 1.2), TOP + 0.05, midZ), palette.Edge)
		add("Lane", "GutterWall", Vector3.new(0.9, 1.6, length + 10), CFrame.new(LANE.Centre + side * (LANE.Width / 2 + 2.8), TOP + 0.8, midZ - 5), CANYON.Terracotta, { Material = Enum.Material.Sandstone })
		add("Lane", "GutterCap", Vector3.new(1.1, 0.3, length + 10), CFrame.new(LANE.Centre + side * (LANE.Width / 2 + 2.8), TOP + 1.75, midZ - 5), CANYON.Gold)
	end
	add("Lane", "Pit", Vector3.new(LANE.Width + 6, 0.3, 8), CFrame.new(LANE.Centre, TOP + 0.02, LANE.EndZ - 4), Color3.fromRGB(96, 52, 40))
	local backZ = LANE.EndZ - 8.6
	local wallWidth = LANE.Width + 6.4
	add("Lane", "BackWall", Vector3.new(wallWidth, 8, 1.4), CFrame.new(LANE.Centre, TOP + 4, backZ), CANYON.Adobe, { Material = Enum.Material.Sand })
	local tiles = 24
	for i = 1, tiles do
		local sx = LANE.Centre - wallWidth / 2 + wallWidth * (i - 0.5) / tiles
		add("Lane", "Tile", Vector3.new(wallWidth / tiles - 0.3, 1.6, 0.2), CFrame.new(sx, TOP + 5.4, backZ + 0.75), if i % 2 == 0 then CANYON.Turquoise else CANYON.Gold, { Collide = false })
	end
	add("Lane", "BackWallCap", Vector3.new(wallWidth + 1, 0.8, 2), CFrame.new(LANE.Centre, TOP + 8.3, backZ), CANYON.Terracotta, { Material = Enum.Material.Sandstone })

	-- The CANYON OASIS sign behind the pit: two banded sandstone pillars with gold suns, a carved board
	local signZ = backZ - 3
	for _, side in { -1, 1 } do
		local sx = LANE.Centre + side * 36
		for k = 0, 4 do
			add("Arch", "Pillar", Vector3.new(4.8 - k * 0.2, 4.8, 4.8 - k * 0.2), CFrame.new(sx, TOP + 2.4 + k * 4.8, signZ), if k % 2 == 0 then CANYON.Terracotta else CANYON.Peach, { Material = Enum.Material.Sandstone })
		end
		add("Arch", "PillarTop", Vector3.new(6, 1.4, 6), CFrame.new(sx, TOP + 24.7, signZ), CANYON.RedRock, { Material = Enum.Material.Sandstone })
		add("Arch", "Sun", Vector3.new(0.6, 5, 5), CFrame.new(sx, TOP + 28.4, signZ) * CFrame.Angles(0, math.rad(90), 0), CANYON.Gold, { Shape = Enum.PartType.Cylinder })
		for r = 0, 7 do
			add("Arch", "SunRay", Vector3.new(0.5, 1.6, 0.4), CFrame.new(sx, TOP + 28.4, signZ) * CFrame.Angles(0, 0, math.rad(r * 45)) * CFrame.new(0, 3.4, 0), CANYON.Gold, { Collide = false })
		end
		add("Arch", "SunStand", Vector3.new(1.2, 2, 1.2), CFrame.new(sx, TOP + 25.6, signZ), CANYON.RedRock, { Material = Enum.Material.Sandstone })
	end
	local board = add("Arch", "NameBoard", Vector3.new(64, 11, 1), CFrame.new(LANE.Centre, TOP + 19, signZ), CANYON.Peach, { Material = Enum.Material.Sandstone })
	add("Arch", "NameBoardTrim", Vector3.new(66, 13, 0.6), CFrame.new(LANE.Centre, TOP + 19, signZ - 0.5), CANYON.Turquoise)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- (faces the bowlers, +Z)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	gui.Parent = board
	local title = label(gui, "CANYON OASIS", UDim2.fromScale(0.94, 0.62), UDim2.fromScale(0.5, 0.4), Color3.new(1, 1, 1))
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(255, 226, 110), Color3.fromRGB(255, 120, 70))
	gradient.Rotation = 90
	gradient.Parent = title
	label(gui, "ZONE 4", UDim2.fromScale(0.3, 0.26), UDim2.fromScale(0.5, 0.83), CANYON.Turquoise)

	-- Pennants over the lane, on carved posts at the gutter walls
	local flags = { CANYON.Terracotta, CANYON.Gold, CANYON.Turquoise, WHITE }
	for _, bz in { -3470, -3505, -3540 } do
		for _, side in { -1, 1 } do
			post("Bunting", "BuntingPole", Vector3.new(LANE.Centre + side * (LANE.Width / 2 + 2.8), TOP + 1.9, bz), 17, 0.4, Color3.fromRGB(150, 100, 60), { Material = Enum.Material.Wood })
		end
		bunting(Vector3.new(LANE.Centre - LANE.Width / 2 - 2.8, TOP + 18.4, bz), Vector3.new(LANE.Centre + LANE.Width / 2 + 2.8, TOP + 18.4, bz), flags)
	end

	-- Striped market awnings over the sell pad and the shop
	local sell, shop = CORE.Sell, CORE.Shop
	awning(sell.Position + Vector3.new(0, 0, sell.Radius + 2.2), 12, CANYON.Terracotta, CANYON.Peach)
	awning(shop.Position + Vector3.new(0, 0, shop.Radius + 2.2), 11, CANYON.Turquoise, WHITE)

	-- Past the pit: the turquoise lake (Terrain), a huge natural stone arch standing in it, hoodoos at its shores,
	-- the red canyon walls behind with a gap to far-off buttes (ZoneMaps.Terrain)
	local lake = CANYON.LakeTop
	local archZ = -3662
	local xL, xR = LANE.Centre - 54, LANE.Centre + 54
	local spring = TOP + 18
	local rr, rh = (xR - xL) / 2, 34
	for _, x in { xL, xR } do
		local bands = 7
		local h = spring - (lake - 8)
		for k = 0, bands - 1 do
			add("StoneArch", "Leg", Vector3.new(14 - k * 0.3, h / bands + 0.2, 14), CFrame.new(x, lake - 8 + h / bands * (k + 0.5), archZ), if k % 2 == 0 then CANYON.RedRock else CANYON.Terracotta, { Material = Enum.Material.Sandstone })
		end
	end
	local pieces = 22
	for i = 0, pieces do
		local a = math.pi * i / pieces
		local at = Vector3.new(LANE.Centre - math.cos(a) * rr, spring + math.sin(a) * rh, archZ)
		local na = math.pi * (i + 1) / pieces
		local nextAt = Vector3.new(LANE.Centre - math.cos(na) * rr, spring + math.sin(na) * rh, archZ)
		local tangent = (nextAt - at).Unit
		local thick = 12 - math.sin(a) * 4 -- (thinner at the top)
		add("StoneArch", "Span", Vector3.new(9, thick, 13), CFrame.fromMatrix(at, tangent, Vector3.new(-tangent.Y, tangent.X, 0)), if i % 3 == 0 then CANYON.Terracotta else CANYON.RedRock, { Material = Enum.Material.Sandstone })
	end
	for i, h in { { -130, -3640, 34, 10 }, { -112, -3690, 46, 12 }, { 60, -3640, 30, 9 }, { 92, -3680, 52, 13 }, { 150, -3630, 26, 8 }, { -150, -3615, 22, 7 } } do
		hoodoo(Vector3.new(h[1], lake - 6, h[2]), h[3], h[4], i)
	end
	-- the lake's shore: sand banks with palms and reeds where the floor meets the water
	for i, p in { { -140, -3604, 15, 40 }, { -100, -3606, 13, 120 }, { 40, -3606, 14, 200 }, { 120, -3606, 16, 300 }, { 170, -3604, 13, 250 } } do
		canyonPalm(Vector3.new(p[1], TOP, p[2] + 6), p[3], p[4] + i * 10)
	end

	-- The palm oasis east of the lane: the pond (Terrain), palms all round, reeds, a little dock, market tents
	for i, p in {
		{ 190, -3456, 17, 30 }, { 210, -3452, 15, 110 }, { 246, -3456, 18, 200 }, { 264, -3480, 14, 260 },
		{ 266, -3520, 16, 290 }, { 240, -3548, 15, 340 }, { 204, -3548, 17, 20 }, { 186, -3500, 14, 80 },
	} do
		canyonPalm(Vector3.new(p[1], TOP, p[2]), p[3], p[4] + i * 7)
	end
	for i = 1, 18 do
		local a = i / 18 * math.pi * 2
		local at = Vector3.new((pond.X0 + pond.X1) / 2 + math.cos(a) * 28, lake + 1.2, (pond.Z0 + pond.Z1) / 2 + math.sin(a) * 33)
		post("Oasis", "Reed", at, 3 + (i % 3), 0.15, CANYON.Palm[i % 2 + 1], { Collide = false })
	end
	for i = 1, 6 do
		local at = Vector3.new(pond.X0 + 8 + (i * 17) % 44, lake + 0.1, pond.Z0 + 10 + (i * 23) % 52)
		add("Oasis", "LilyPad", Vector3.new(0.15, 3 + i % 2, 3 + i % 2), CFrame.new(at) * UP, CANYON.Palm[i % 2 + 1], { Shape = Enum.PartType.Cylinder, Collide = false })
	end
	-- the dock: planks out over the pond from its west edge
	for k = 0, 6 do
		add("Oasis", "DockPlank", Vector3.new(1.6, 0.4, 6), CFrame.new(pond.X0 + 1 + k * 1.7, TOP - 0.2, -3500), if k % 2 == 0 then Color3.fromRGB(176, 128, 78) else Color3.fromRGB(156, 110, 66), { Material = Enum.Material.WoodPlanks })
	end
	for _, z in { -3502.6, -3497.4 } do
		post("Oasis", "DockPost", Vector3.new(pond.X0 + 11.5, lake - 3, z), 4.4, 0.3, Color3.fromRGB(120, 86, 58), { Material = Enum.Material.Wood })
	end
	tent(Vector3.new(150, TOP, -3410), 10, CANYON.Terracotta, WHITE, 0)
	tent(Vector3.new(170, TOP, -3392), 9, CANYON.Turquoise, CANYON.Gold, 20)
	tent(Vector3.new(232, TOP, -3420), 11, CANYON.Gold, CANYON.Terracotta, -10)
	tent(Vector3.new(160, TOP, -3570), 9, CANYON.Turquoise, WHITE, 30)
	-- rugs and clay pots under the tents
	for i, r in { { 150, -3410 }, { 232, -3420 } } do
		add("Tents", "Rug", Vector3.new(7, 0.1, 5), CFrame.new(r[1], TOP + 0.06, r[2]), if i == 1 then Color3.fromRGB(200, 60, 60) else CANYON.Turquoise, { Collide = false })
		add("Tents", "RugBand", Vector3.new(7.02, 0.12, 1), CFrame.new(r[1], TOP + 0.07, r[2]), CANYON.Gold, { Collide = false })
	end
	for i, p in { { 146, -3404 }, { 155, -3415 }, { 228, -3414 }, { 238, -3426 }, { 166, -3566 } } do
		post("Pots", "Pot", Vector3.new(p[1], TOP, p[2]), 2 + i % 2, 0.9 + (i % 3) * 0.2, CANYON.Terracotta, { Material = Enum.Material.Sand })
		add("Pots", "PotBand", Vector3.new(0.3, 2.2 + (i % 3) * 0.4, 2.2 + (i % 3) * 0.4), CFrame.new(p[1], TOP + 1.2, p[2]) * UP, CANYON.Turquoise, { Shape = Enum.PartType.Cylinder, Collide = false })
	end

	-- The golden sphinx on its plinth at the oasis, looking at the lane
	local sphinx = Vector3.new(232, TOP, -3384)
	local S = 1.6
	local function sp(x: number, y: number, z: number): CFrame
		return CFrame.new(sphinx + Vector3.new(x, y, z) * S)
	end
	local gold, goldDark = CANYON.Gold, Color3.fromRGB(214, 150, 50)
	add("Sphinx", "Plinth", Vector3.new(10, 3, 18) * S, sp(0, 1.5, 0), CANYON.Peach, { Material = Enum.Material.Sandstone })
	add("Sphinx", "PlinthBand", Vector3.new(10.2, 0.8, 18.2) * S, sp(0, 2.6, 0), CANYON.Turquoise)
	add("Sphinx", "Body", Vector3.new(6, 4.6, 11) * S, sp(0, 5.3, 2), gold)
	for _, s in { -1, 1 } do
		add("Sphinx", "Paw", Vector3.new(1.6, 1.6, 6) * S, sp(s * 2, 3.8, -5.6), gold)
	end
	add("Sphinx", "Chest", Vector3.new(5, 6, 3) * S, sp(0, 6.5, -2.6), gold)
	add("Sphinx", "Head", Vector3.new(3.4, 3.8, 3.2) * S, sp(0, 10.6, -3.4), gold)
	for k = 0, 4 do
		for _, s in { -1, 1 } do
			add("Sphinx", "Headdress", Vector3.new(0.6, 1, 3) * S, sp(s * 2, 12 - k * 1, -3), if k % 2 == 0 then CANYON.Turquoise else goldDark)
		end
	end
	add("Sphinx", "HeaddressTop", Vector3.new(4.6, 0.8, 3.6) * S, sp(0, 12.8, -3.2), CANYON.Turquoise)
	for _, s in { -1, 1 } do
		add("Sphinx", "Eye", Vector3.new(0.7, 0.4, 0.2) * S, sp(s * 0.8, 11.2, -5.05), CANYON.Turquoise, { Material = Enum.Material.Neon, Collide = false })
	end
	add("Sphinx", "Beard", Vector3.new(0.8, 1.8, 0.6) * S, sp(0, 8.2, -4.8), CANYON.Turquoise)

	-- Adobe houses along the north edge and the west side, saguaros, boulders and desert flowers all round
	for _, h in {
		{ -130, -3352, Vector3.new(12, 9, 10), 0 }, { -104, -3346, Vector3.new(10, 7, 8), 0 },
		{ 60, -3348, Vector3.new(14, 10, 10), 0 }, { 90, -3352, Vector3.new(10, 8, 9), 0 },
		{ -136, -3470, Vector3.new(10, 8, 12), -90 }, { -136, -3530, Vector3.new(12, 10, 12), -90 },
	} do
		adobe(Vector3.new(h[1], TOP, h[2]), h[3], h[4])
	end
	local cacti = {
		{ -120, -3400, 12 }, { -126, -3440, 9 }, { -118, -3570, 14 }, { -84, -3348, 10 }, { 30, -3352, 13 },
		{ 46, -3470, 11 }, { 72, -3520, 15 }, { 100, -3420, 10 }, { 120, -3480, 13 }, { 110, -3560, 9 },
		{ 140, -3360, 14 }, { 186, -3370, 11 }, { 266, -3360, 15 }, { 268, -3580, 12 }, { 130, -3590, 10 },
	}
	for i, c in cacti do
		cactus(Vector3.new(c[1], TOP, c[2]), c[3], i)
	end
	for i, b in { { -128, -3420, 4 }, { 60, -3380, 3 }, { 140, -3530, 5 }, { -110, -3500, 3 }, { 100, -3350, 4 }, { 270, -3440, 5 } } do
		add("Rocks", "Boulder", Vector3.new(b[3] * 1.3, b[3], b[3] * 1.1), CFrame.new(b[1], TOP + b[3] * 0.3, b[2]) * CFrame.Angles(0, math.rad(i * 37), 0), if i % 2 == 0 then CANYON.Terracotta else CANYON.RedRock, { Shape = Enum.PartType.Ball, Material = Enum.Material.Sandstone })
	end
	local blooms = { Color3.fromRGB(255, 110, 170), Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 130, 60) }
	for i = 1, 26 do
		local x = if i % 2 == 0 then 30 + (i * 37) % 140 else -140 + (i * 29) % 46
		local z = -3340 - (i * 53) % 250
		add("Flowers", "Bloom", Vector3.one * (0.8 + i % 3 * 0.3), CFrame.new(x, TOP + 0.4, z), blooms[i % #blooms + 1], { Shape = Enum.PartType.Ball, Collide = false })
		add("Flowers", "Shrub", Vector3.new(2.4, 1, 2.4), CFrame.new(x + 0.6, TOP + 0.3, z + 0.4), Color3.fromRGB(138, 160, 90), { Shape = Enum.PartType.Ball, Collide = false, Material = Enum.Material.Grass })
	end

	-- Hot-air balloons drifting over the canyon (seen over the arch and the walls)
	balloon(Vector3.new(-120, TOP + 74, -3700), { CANYON.Terracotta, CANYON.Gold, WHITE })
	balloon(Vector3.new(40, TOP + 92, -3760), { CANYON.Turquoise, WHITE, CANYON.Gold })
	balloon(Vector3.new(160, TOP + 66, -3640), { Color3.fromRGB(255, 110, 150), CANYON.Gold, CANYON.Turquoise })
	balloon(Vector3.new(220, TOP + 84, -3330), { CANYON.Gold, CANYON.Terracotta, CANYON.Turquoise })
	balloon(Vector3.new(-170, TOP + 70, -3380), { CANYON.Turquoise, CANYON.Terracotta, WHITE })
end

local BUILDERS = { Boardwalk = buildBoardwalk, Jungle = buildJungle, Canyon = buildCanyon }

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
	elseif name == "Jungle" then
		-- (the water look is shared by every zone's water: zone 2's turquoise fits the jungle's aqua too)
		local o = offset
		local pool = JUNGLE.PoolTop
		local gr, e = JUNGLE.Ground, JUNGLE.EastBank
		local function block(x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, material: Enum.Material)
			terrain:FillBlock(CFrame.new(Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2) + o), Vector3.new(x1 - x0, y1 - y0, z1 - z0), material)
		end
		-- the bed under everything, then the waterfall pool (south) and the river (east) on it
		block(-260, 360, pool - 16, pool - 6, -3760, -3220, Enum.Material.Mud)
		block(-200, 300, pool - 6, pool, JUNGLE.CliffZ, gr.Z0, Enum.Material.Water)
		block(gr.X1, e.X0, pool - 6, pool, gr.Z0, gr.Z1 + 40, Enum.Material.Water)
		-- the cliff behind the pool, grass on top; lower cliffs round the west, north and east so the valley is closed
		block(-260, 360, pool - 6, JUNGLE.CliffTop, JUNGLE.CliffZ - 80, JUNGLE.CliffZ, Enum.Material.Rock)
		block(-260, 360, JUNGLE.CliffTop, JUNGLE.CliffTop + 4, JUNGLE.CliffZ - 80, JUNGLE.CliffZ - 2, Enum.Material.LeafyGrass)
		block(-240, gr.X0, pool - 6, TOP + 34, -3720, -3240, Enum.Material.Rock)
		block(-240, gr.X0 - 2, TOP + 34, TOP + 38, -3720, -3240, Enum.Material.LeafyGrass)
		block(-240, 360, pool - 6, TOP + 22, -3300, -3220, Enum.Material.Rock)
		block(-240, 360, TOP + 22, TOP + 26, -3298, -3220, Enum.Material.LeafyGrass)
		block(e.X1, 360, pool - 6, TOP + 30, -3720, -3240, Enum.Material.Rock)
		block(e.X1 + 2, 360, TOP + 30, TOP + 34, -3720, -3240, Enum.Material.LeafyGrass)
		-- the gaps between the ground slabs and the cliffs (north and west) filled with grass, level with the floor
		block(-240, 360, pool - 6, TOP, gr.Z1, -3300, Enum.Material.Grass)
		block(gr.X0 - 2, gr.X0, pool - 6, TOP, -3720, -3240, Enum.Material.Grass)
		-- leafy ledges across the cliff face, and the jungle's rock and grass colours (Terrain colours are shared by
		-- every zone: zone 2's island rocks take the warm stone too)
		for _, y in { 18, 36, 52 } do
			block(-260, 360, TOP + y, TOP + y + 3, JUNGLE.CliffZ - 2, JUNGLE.CliffZ + 2, Enum.Material.LeafyGrass)
		end
		terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(104, 114, 92))
		terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(88, 170, 64))
		-- rocky outcrops on the cliff face (between the falls)
		for i, at in { { -70, 30, 14 }, { 0, 48, 12 }, { 90, 22, 16 }, { -150, 40, 15 }, { 170, 50, 13 } } do
			terrain:FillBall(Vector3.new(at[1], TOP + at[2], JUNGLE.CliffZ + 1) + o, at[3] - i % 2 * 2, Enum.Material.Rock)
		end
	elseif name == "Canyon" then
		local o = offset
		local lake = CANYON.LakeTop
		local gr, pond = CANYON.Ground, CANYON.Pond
		local function block(x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, material: Enum.Material)
			terrain:FillBlock(CFrame.new(Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2) + o), Vector3.new(x1 - x0, y1 - y0, z1 - z0), material)
		end
		-- red canyon wall: Sandstone (terracotta) and Limestone (peach) bands, 8 studs each, from the lake bed up
		local function wall(x0: number, x1: number, z0: number, z1: number, top: number)
			local y = lake - 6
			local k = 0
			while y < top do
				local y1 = math.min(y + 8, top)
				block(x0, x1, y, y1, z0, z1, if k % 3 == 1 then Enum.Material.Limestone else Enum.Material.Sandstone)
				y = y1
				k += 1
			end
		end
		-- the bed under everything, the lake past the pit (and the oasis pond), sand level with the floor elsewhere
		block(-300, 400, lake - 16, lake - 6, -4000, -3200, Enum.Material.Mud)
		block(-260, 360, lake - 6, lake, -3800, gr.Z0, Enum.Material.Water)
		block(pond.X0, pond.X1, lake - 6, lake, pond.Z0, pond.Z1, Enum.Material.Water)
		block(-240, 380, lake - 6, TOP, gr.Z1, -3290, Enum.Material.Sand)
		block(gr.X0 - 4, gr.X0, lake - 6, TOP, -3740, -3240, Enum.Material.Sand)
		block(gr.X1, gr.X1 + 4, lake - 6, TOP, -3740, -3240, Enum.Material.Sand)
		-- the walls: tall on both sides of the south end, a low gap in the middle that shows far buttes; lower walls
		-- close the west, north and east
		wall(-280, -112, -3800, -3712, TOP + 86)
		wall(40, 380, -3800, -3712, TOP + 86)
		wall(-112, 40, -3880, -3800, TOP + 16)
		wall(-260, gr.X0 - 4, -3740, -3240, TOP + 52)
		wall(-260, 380, -3290, -3200, TOP + 44)
		wall(gr.X1 + 4, 380, -3740, -3240, TOP + 60)
		-- far buttes through the gap (faded by the haze) and rocky bulges along the wall faces
		wall(-160, -90, -4060, -4000, TOP + 60)
		wall(-40, 30, -4120, -4060, TOP + 74)
		wall(60, 140, -4000, -3950, TOP + 48)
		for i, at in { { -200, 30, -3712, 14 }, { -140, 60, -3712, 12 }, { 80, 40, -3712, 15 }, { 180, 64, -3712, 13 }, { 300, 24, -3712, 16 }, { -152, 20, -3420, 12 }, { -152, 38, -3560, 11 }, { 284, 30, -3400, 13 }, { 284, 46, -3600, 12 } } do
			terrain:FillBall(Vector3.new(at[1], TOP + at[2], at[3]) + o, at[4] - i % 2 * 2, Enum.Material.Sandstone)
		end
		-- (Terrain colours are shared by every zone; only this canyon uses Sandstone, Limestone and Sand)
		terrain:SetMaterialColor(Enum.Material.Sandstone, Color3.fromRGB(196, 96, 64))
		terrain:SetMaterialColor(Enum.Material.Limestone, Color3.fromRGB(236, 168, 120))
		terrain:SetMaterialColor(Enum.Material.Sand, CANYON.Sand)
	end
end

return ZoneMaps
