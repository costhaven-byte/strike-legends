-- Addendum 5 A3: the ONE shared lane on the roof (Config.CoreLoop.SharedLane), built from code at server start
-- (Claude can't save the Studio place, so nothing here lives in the place file).
-- Everyone throws down the same wide lane at once, each from their own throw spot. A spot is a small invisible
-- "lane" model (BallStart, PinSpot, Approach, LaneFloor, PinDeck, Stand, OwnerSign) in SharedLane.Spots, so the
-- per-lane code (LaneUtil, LaneService, ThrowService, lane skins, the throw camera) keeps working per player.
-- Pins are drawn on each player's own screen only (LaneVisuals); collision groups keep pins, balls and players apart.
-- The old 6 lanes and the 6-lane floor decor move to ServerStorage.A5OldLanes (never deleted).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CoreLadder = require(ReplicatedStorage.Shared:WaitForChild("Modules"):WaitForChild("CoreLadder"))

local CORE = Config.CoreLoop
local LANE = CORE.SharedLane

local SharedLane = {}

local INK = Color3.fromRGB(46, 36, 66) -- the dark outline/text colour of the sunny UI

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- An invisible marker part (no collisions, no queries)
local function marker(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local p = part(name, size, cframe, Color3.new(1, 1, 1))
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function flat(p: BasePart)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
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
	stroke.Thickness = 3
	stroke.Parent = t
	t.Parent = parent
	return t
end

-- ===== collision groups =====
-- Pins (drawn on each screen) never touch players; balls touch nothing. Pins still land on the floor (Default).
local function setupGroups()
	local G = LANE.Groups
	for _, name in { G.Pins, G.Players, G.Balls } do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(G.Pins, G.Players, false)
	for _, other in { "Default", G.Pins, G.Players, G.Balls } do
		PhysicsService:CollisionGroupSetCollidable(G.Balls, other, false)
	end

	local function onCharacter(character: Model)
		local function put(item: Instance)
			if item:IsA("BasePart") then
				item.CollisionGroup = G.Players
			end
		end
		for _, item in character:GetDescendants() do
			put(item)
		end
		character.DescendantAdded:Connect(put)
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			onCharacter(player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

-- ===== the old lanes go to storage =====
local function hideOld(folder: Instance)
	local store = ServerStorage:FindFirstChild("A5OldLanes") or Instance.new("Folder")
	store.Name = "A5OldLanes"
	store.Parent = ServerStorage
	for _, path in LANE.Hide do
		local node: Instance? = folder
		for _, name in path do
			node = node and node:FindFirstChild(name)
		end
		if node then
			node:SetAttribute("A5From", table.concat(path, "/"))
			node.Parent = store
		end
	end
end

-- Where spot n stands: x across the lane and how far back of the front row (n 1..Spots = the front row,
-- then each round of Spots shifts half a spot and/or goes a row back)
local function spotPlace(n: number): (number, number)
	local round = (n - 1) // LANE.Spots
	local k = (n - 1) % LANE.Spots
	local x = LANE.Centre + (k - (LANE.Spots - 1) / 2) * LANE.Spacing
	if round % 2 == 1 then
		x += LANE.Shift
	end
	return x, (round // 2) * LANE.Back
end

-- Spot numbers in hand-out order: the front row middle first, then outwards, then the extra rounds
local function handOutOrder(): { number }
	local order = {}
	local middle = (LANE.Spots + 1) / 2
	local front = {}
	for k = 1, LANE.Spots do
		table.insert(front, k)
	end
	table.sort(front, function(a, b)
		local da, db = math.abs(a - middle), math.abs(b - middle)
		if da ~= db then
			return da < db
		end
		return a < b
	end)
	for round = 0, math.ceil(LANE.MaxSpots / LANE.Spots) - 1 do
		for _, k in front do
			local n = round * LANE.Spots + k
			if n <= LANE.MaxSpots then
				table.insert(order, n)
			end
		end
	end
	return order
end
SharedLane.HandOutOrder = handOutOrder

-- ===== one spot =====
local function buildSpot(n: number, spots: Instance, visuals: Instance, zone: number)
	local x, back = spotPlace(n)
	local front = n <= LANE.Spots
	local spot = Instance.new("Model")
	spot.Name = "Lane" .. n -- (LaneUtil sorts lanes by their number)
	spot:SetAttribute("Spot", n)
	spot:SetAttribute("Zone", zone) -- (Addendum 6 Stage 3: the zone this spot's lane is in)
	if not front then
		spot:SetAttribute("NoSkin", true) -- (extra spots overlap the front ones: no lane skin plates)
	end
	local floorTop = LANE.FloorY
	local length = LANE.FoulZ - LANE.DeckZ
	local deck = LANE.DeckZ - LANE.EndZ
	local width = LANE.Spacing

	marker("BallStart", Vector3.one, CFrame.new(x, 849.605, LANE.BallStartZ), spot)
	marker("PinSpot", Vector3.new(1, 0.2, 1), CFrame.new(x, floorTop + 0.1, LANE.PinSpotZ), spot)
	marker(
		"Approach",
		Vector3.new(width, 1, LANE.ApproachDepth),
		CFrame.new(x, LANE.ApproachTop - 0.5, LANE.ApproachZ + back),
		spot
	)
	marker("Stand", Vector3.one, CFrame.new(x, LANE.ApproachTop + 0.05, LANE.StandZ + back), spot)
	if front then
		-- (lane skins paint over these; front-row spots tile the wood exactly)
		local edge = if n == 1 or n == LANE.Spots then (LANE.Width - LANE.Spacing * LANE.Spots) / 2 else 0
		local left = if n == 1 then edge else 0
		local right = if n == LANE.Spots then edge else 0
		local mid = x + (right - left) / 2
		marker(
			"LaneFloor",
			Vector3.new(width + left + right, 1, length),
			CFrame.new(mid, floorTop - 0.5, (LANE.FoulZ + LANE.DeckZ) / 2),
			spot
		)
		marker(
			"PinDeck",
			Vector3.new(width + left + right, 1, deck),
			CFrame.new(mid, floorTop - 0.5, (LANE.DeckZ + LANE.EndZ) / 2),
			spot
		)

		-- The wood strip under this spot (two tones, alternating) + its deck
		local wood = part(
			"Wood" .. n,
			Vector3.new(width + left + right, 0.4, length),
			CFrame.new(mid, floorTop - 0.2, (LANE.FoulZ + LANE.DeckZ) / 2),
			LANE.Wood[(n - 1) % 2 + 1],
			LANE.LaneMaterial or Enum.Material.WoodPlanks
		)
		wood.Parent = visuals
		local deckPart = part(
			"Deck" .. n,
			Vector3.new(width + left + right, 0.4, deck),
			CFrame.new(mid, floorTop - 0.2, (LANE.DeckZ + LANE.EndZ) / 2),
			LANE.Deck,
			LANE.LaneMaterial or Enum.Material.WoodPlanks
		)
		deckPart.Parent = visuals

		-- Gold arrow (a chevron pointing down the lane) and two guide dots, like a real lane
		local color = LANE.Colors[(n - 1) % #LANE.Colors + 1]
		for _, side in { -1, 1 } do
			local arm = part(
				"Arrow",
				Vector3.new(0.35, 0.05, 2.6),
				CFrame.new(x + side * 0.55, floorTop + 0.025, -3470) * CFrame.Angles(0, math.rad(side * 28), 0),
				Color3.fromRGB(255, 200, 60),
				Enum.Material.Neon
			)
			flat(arm)
			arm.Parent = visuals
			local dot = part(
				"Dot",
				Vector3.new(0.05, 0.6, 0.6),
				CFrame.new(x + side * 2.2, floorTop + 0.02, -3458) * CFrame.Angles(0, 0, math.rad(90)),
				color,
				Enum.Material.Neon
			)
			dot.Shape = Enum.PartType.Cylinder
			flat(dot)
			dot.Parent = visuals
		end

		-- The coloured ring you stand on, with your spot number
		local ring = part(
			"Ring",
			Vector3.new(0.12, 5.2, 5.2),
			CFrame.new(x, LANE.ApproachTop + 0.06, LANE.StandZ) * CFrame.Angles(0, 0, math.rad(90)),
			color
		)
		ring.Shape = Enum.PartType.Cylinder
		flat(ring)
		ring.Parent = spot
		local inner = part(
			"RingInner",
			Vector3.new(0.13, 4, 4),
			CFrame.new(x, LANE.ApproachTop + 0.065, LANE.StandZ) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(255, 250, 238)
		)
		inner.Shape = Enum.PartType.Cylinder
		flat(inner)
		inner.Parent = spot
		local numberPlate =
			marker("Number", Vector3.new(3.4, 0.05, 3.4), CFrame.new(x, LANE.ApproachTop + 0.08, LANE.StandZ), spot)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.Parent = numberPlate
		label(gui, tostring(n), UDim2.fromScale(0.9, 0.9), UDim2.fromScale(0.5, 0.5), color)

		-- The owner's name painted on the floor just past the foul line ("3 · SELIM"; LaneService fills it)
		local sign = marker(
			"OwnerSign",
			Vector3.new(width - 0.6, 0.05, 2.2),
			CFrame.new(x, floorTop + 0.03, LANE.FoulZ - 2.4),
			spot
		)
		local signGui = Instance.new("SurfaceGui")
		signGui.Face = Enum.NormalId.Top
		signGui.PixelsPerStud = 40
		signGui.LightInfluence = 0
		signGui.Parent = sign
		local owner = label(signGui, ("%d · FREE"):format(n), UDim2.fromScale(0.96, 0.8), UDim2.fromScale(0.5, 0.5))
		owner.Name = "Owner"
	end
	spot.Parent = spots
end

-- ===== the lane itself =====
local function buildLane(folder: Instance, zone: number): Model
	local model = Instance.new("Model")
	model.Name = "SharedLane"
	local visuals = Instance.new("Folder")
	visuals.Name = "Visuals"
	visuals.Parent = model
	local spots = Instance.new("Folder")
	spots.Name = "Spots"

	for n = 1, LANE.MaxSpots do
		buildSpot(n, spots, visuals, zone)
	end

	-- Thin gold lines between the wood strips (one lane, many throw lines)
	for k = 1, LANE.Spots - 1 do
		local x = LANE.Centre + (k - LANE.Spots / 2) * LANE.Spacing
		local line = part(
			"StripLine",
			Vector3.new(0.18, 0.04, LANE.FoulZ - LANE.DeckZ),
			CFrame.new(x, LANE.FloorY + 0.02, (LANE.FoulZ + LANE.DeckZ) / 2),
			Color3.fromRGB(255, 214, 120),
			Enum.Material.SmoothPlastic
		)
		flat(line)
		line.Transparency = 0.25
		line.Parent = visuals
	end

	-- Addendum 6 1.2: bright edge lines down both outer sides, so the dark lane still reads as a lane
	if LANE.EdgeLine then
		for _, side in { -1, 1 } do
			local line = part(
				"EdgeLine",
				Vector3.new(LANE.EdgeLine.Width, 0.04, LANE.FoulZ - LANE.EndZ),
				CFrame.new(
					LANE.Centre + side * (LANE.Width / 2 - LANE.EdgeLine.Width / 2),
					LANE.FloorY + 0.02,
					(LANE.FoulZ + LANE.EndZ) / 2
				),
				LANE.EdgeLine.Color,
				Enum.Material.SmoothPlastic
			)
			flat(line)
			line.Parent = visuals
		end
	end

	-- Soft lights over the lane (bright like a sunny arena; one strip per Width / Lights)
	local across = LANE.Width / LANE.Lights
	for i = 1, LANE.Lights do
		local x = LANE.Centre - LANE.Width / 2 + across * (i - 0.5)
		local strip = marker(
			"PlayLight",
			Vector3.new(across, 0.2, LANE.FoulZ - LANE.EndZ + 14),
			CFrame.new(x, LANE.FloorY + 14, (LANE.FoulZ + LANE.EndZ) / 2 + 7),
			visuals
		)
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Bottom
		light.Angle = 70
		light.Range = 20
		light.Brightness = LANE.LightBrightness
		light.Color = Color3.fromRGB(255, 244, 226)
		light.Shadows = false
		light.Parent = strip
	end

	-- The big MEGA LANE sign hanging from the gantry, with rainbow pennants along its beam
	local gantry = folder:FindFirstChild("Gantry")
	local beam = gantry and gantry:FindFirstChild("Beam") :: BasePart?
	if beam then
		local z = beam.Position.Z
		local bottom = beam.Position.Y - beam.Size.Y / 2
		local board = part(
			"MegaSign",
			Vector3.new(34, 6.4, 0.6),
			CFrame.new(LANE.Centre, bottom - 3.4, z),
			Color3.fromRGB(255, 244, 222)
		)
		flat(board)
		board.Parent = visuals
		local trim = part(
			"MegaSignTrim",
			Vector3.new(35.2, 7.6, 0.4),
			CFrame.new(LANE.Centre, bottom - 3.4, z - 0.15),
			Color3.fromRGB(255, 150, 60)
		)
		flat(trim)
		trim.Parent = visuals
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local gui = Instance.new("SurfaceGui")
			gui.Face = face
			gui.PixelsPerStud = 30
			gui.LightInfluence = 0
			gui.Parent = board
			local gradient = Instance.new("UIGradient")
			local title = label(
				gui,
				LANE.Sign.Title,
				UDim2.fromScale(0.92, 0.62),
				UDim2.fromScale(0.5, 0.38),
				Color3.new(1, 1, 1)
			)
			gradient.Color = ColorSequence.new(Color3.fromRGB(255, 226, 90), Color3.fromRGB(255, 140, 40))
			gradient.Rotation = 90
			gradient.Parent = title
			label(
				gui,
				LANE.Sign.Sub,
				UDim2.fromScale(0.86, 0.26),
				UDim2.fromScale(0.5, 0.82),
				Color3.fromRGB(110, 220, 255)
			)
		end
		local pennants = 26
		local span = beam.Size.X - 4
		for i = 1, pennants do
			local x = beam.Position.X - span / 2 + span * (i - 0.5) / pennants
			if math.abs(x - LANE.Centre) < 18.5 then
				continue -- (behind the sign)
			end
			-- a diamond half hidden in the beam: a triangle hanging down
			local flag = part(
				"Pennant",
				Vector3.new(1.5, 1.5, 0.1),
				CFrame.new(x, bottom, z) * CFrame.Angles(0, 0, math.rad(45)),
				LANE.Colors[(i - 1) % #LANE.Colors + 1]
			)
			flat(flag)
			flag.Parent = visuals
		end
	end

	spots.Parent = model
	model:SetAttribute("SpotCount", LANE.MaxSpots)
	model:SetAttribute("Zone", zone)
	return model
end

-- Addendum 6 Stage 3: moves every part (and so every attachment and light) of a model built in zone 1's layout
local function shift(root: Instance, offset: Vector3)
	if offset.Magnitude < 0.01 then
		return
	end
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame += offset
		end
	end
end
SharedLane.Shift = shift

-- Addendum 6 Stage 3 PLACEHOLDER world for a zone with no map yet (Config.CoreLoop.Zones Placeholder): a flat ground
-- in the zone's palette with the lane's gutters, a pit, a low rim and a few props. Every part is tagged "Placeholder"
-- (CollectionService) so Stages 4-6 can find and replace them.
local function buildPlaceholder(zone: number, info: any): Model
	local model = Instance.new("Model")
	model.Name = "Placeholder"
	model:SetAttribute("Placeholder", true)
	local zones = CORE.Zones
	local palette = info.Palette
	local ground = zones.Ground
	local top = ground.Centre.Y
	local function add(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
		local p = part(name, size, cframe, color, material or Enum.Material.SmoothPlastic)
		CollectionService:AddTag(p, "Placeholder")
		p.Parent = model
		return p
	end
	add("Ground", ground.Size, CFrame.new(ground.Centre - Vector3.new(0, ground.Size.Y / 2, 0)), palette.Ground, Enum.Material.Sand)
	-- a bright rim round the edge so nobody walks off
	local half = ground.Size / 2
	for _, side in { -1, 1 } do
		add("Rim", Vector3.new(2, 3, ground.Size.Z), CFrame.new(ground.Centre + Vector3.new(side * (half.X - 1), 1.5, 0)), palette.Edge)
		add("Rim", Vector3.new(ground.Size.X, 3, 2), CFrame.new(ground.Centre + Vector3.new(0, 1.5, side * (half.Z - 1))), palette.Edge)
	end
	-- gutters down both sides of the lane and a dark pit at its end
	local length = LANE.FoulZ - LANE.EndZ
	local midZ = (LANE.FoulZ + LANE.EndZ) / 2
	for _, side in { -1, 1 } do
		add("Gutter", Vector3.new(2.4, 0.3, length), CFrame.new(LANE.Centre + side * (LANE.Width / 2 + 1.2), top - 0.1, midZ), palette.Edge)
		add("GutterWall", Vector3.new(0.8, 1.6, length), CFrame.new(LANE.Centre + side * (LANE.Width / 2 + 2.8), top + 0.8, midZ), palette.Accent)
	end
	add("Pit", Vector3.new(LANE.Width + 6, 0.3, 8), CFrame.new(LANE.Centre, top - 0.1, LANE.EndZ - 4), Color3.fromRGB(70, 76, 90))
	add("BackWall", Vector3.new(LANE.Width + 6, 8, 1.2), CFrame.new(LANE.Centre, top + 4, LANE.EndZ - 8.6), palette.Accent)
	-- a few props in the palette on the open side (umbrella-like posts with discs)
	for i = 1, 6 do
		local at = Vector3.new(30 + (i % 3) * 30, top, -3500 - (i // 3) * 50)
		add("PropPost", Vector3.new(0.6, 9, 0.6), CFrame.new(at + Vector3.new(0, 4.5, 0)), Color3.fromRGB(250, 248, 240))
		local disc = add(
			"PropTop",
			Vector3.new(0.6, 10, 10),
			CFrame.new(at + Vector3.new(0, 9, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			if i % 2 == 0 then palette.Accent else palette.Edge
		)
		disc.Shape = Enum.PartType.Cylinder
	end
	-- the zone's name on a big board behind the pit
	local board = add("NameBoard", Vector3.new(44, 9, 0.6), CFrame.new(LANE.Centre, top + 13, LANE.EndZ - 9.4), Color3.fromRGB(255, 248, 232))
	board.CanCollide = false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- (faces the bowlers, +Z)
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	gui.Parent = board
	label(gui, string.upper(info.Name), UDim2.fromScale(0.92, 0.6), UDim2.fromScale(0.5, 0.4), palette.Accent)
	label(gui, ("ZONE %d"):format(zone), UDim2.fromScale(0.5, 0.28), UDim2.fromScale(0.5, 0.82), palette.Edge)
	return model
end

-- Builds the shared lane (once, before the services start) and moves the old lanes away
function SharedLane.Build()
	if not (CORE.Enabled and LANE and LANE.Enabled) then
		return
	end
	local folder = Workspace:WaitForChild(CORE.Folder)
	if folder:FindFirstChild("SharedLane") then
		return
	end
	setupGroups()
	hideOld(folder)
	-- Addendum 6 Stage 3: zones 2-4 first (their folders made here, placeholder ground if they have no map), zone 1
	-- last: clients wait for zone 1's Ready, so every lane exists by then
	for zone = 2, CoreLadder.ZoneCount() do
		local info = CoreLadder.ZoneInfo(zone)
		local zoneFolder = Workspace:FindFirstChild(info.Folder)
		if not zoneFolder then
			zoneFolder = Instance.new("Model")
			zoneFolder.Name = info.Folder
			zoneFolder:SetAttribute("Zone", zone)
			zoneFolder.Parent = Workspace
		end
		if info.Placeholder and not zoneFolder:FindFirstChild("Placeholder") then
			local ground = buildPlaceholder(zone, info)
			shift(ground, info.Offset)
			ground.Parent = zoneFolder
		end
		local lane = buildLane(zoneFolder, zone)
		shift(lane, info.Offset)
		lane.Parent = zoneFolder
		lane:SetAttribute("Ready", true)
		task.wait() -- (one zone a frame)
	end
	local model = buildLane(folder, 1)
	model.Parent = folder
	model:SetAttribute("Ready", true) -- (clients wait for this before they look for their spot)
end

return SharedLane
