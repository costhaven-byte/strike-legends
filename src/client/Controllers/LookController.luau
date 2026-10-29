-- Lane skins (Addendum 2 step 12b, Config.Cosmetics LaneSkin): lays the skin its owner wears over each lane's floor
-- (Config.Cosmetics LaneParts), on this screen, so everyone sees everyone's lane skin. The lane shows its own look
-- again when the owner takes the skin off or leaves the lane.
-- In most zones the LaneFloor/PinDeck/Approach parts are invisible and the floor you see is the zone's design
-- meshes, so the skin is a thin plate laid just on top of the visible floor (2026-10-26: repainting the hidden
-- parts only worked in zone 2).
-- Skins add a little decor on their plates (Config.Cosmetics Decor / Glow, 2026-10-29).
-- Trails, pin blasts and strike banners are drawn with the throw (LaneVisuals).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetSlots = require(Shared.AssetSlots)
local Config = require(Shared.Config)
local Cosmetics = require(Shared.Modules.Cosmetics)
local LaneUtil = require(Shared.Modules.LaneUtil)

local LOOKS = Config.Cosmetics
local SKIN_KEY = Cosmetics.AttributeFor("LaneSkin")

local LookController = {}

local PLATE_THICKNESS = 0.05
local LIFT = 0.012 -- studs the skin sits above the highest floor piece under it
local NEAR = 0.12 -- floor pieces whose top is this close to the lane part's top count as visible floor

local watched: { [Player]: RBXScriptConnection } = {}
-- Visible flat parts per lane folder (each zone's design meshes), found once
local floorPieces: { [Instance]: { BasePart } } = {}
-- Where each lane part's plate goes: { CFrame, Size }, worked out once
local plateSpots: { [BasePart]: { CFrame: CFrame, Size: Vector3 } } = {}

local function piecesIn(folder: Instance): { BasePart }
	if floorPieces[folder] then
		return floorPieces[folder]
	end
	local list = {}
	for _, item in folder:GetDescendants() do
		if item:IsA("BasePart") and item.Transparency < 0.9 then
			table.insert(list, item)
		end
	end
	floorPieces[folder] = list
	return list
end

-- The plate for one lane part: its footprint grown to cover the visible floor pieces lying on it,
-- just above the highest of them
local function plateSpot(lane: Model, part: BasePart)
	if plateSpots[part] then
		return plateSpots[part]
	end
	local half = part.Size / 2
	local top = half.Y
	local minX, maxX, minZ, maxZ = -half.X, half.X, -half.Z, half.Z
	local highest = top
	for _, piece in piecesIn(lane.Parent :: Instance) do
		if piece == part or (piece:IsDescendantOf(lane) and table.find(LOOKS.LaneParts, piece.Name)) then
			continue
		end
		local centre = part.CFrame:PointToObjectSpace(piece.Position)
		-- The piece's box in the lane part's space
		local extent = Vector3.zero
		local box = piece.CFrame
		for _, axis in
			{ box.RightVector * piece.Size.X / 2, box.UpVector * piece.Size.Y / 2, box.LookVector * piece.Size.Z / 2 }
		do
			local along = part.CFrame:VectorToObjectSpace(axis)
			extent += Vector3.new(math.abs(along.X), math.abs(along.Y), math.abs(along.Z))
		end
		-- A piece lying on this part, or one big floor piece under the whole spot (a zone-wide approach mesh)
		local inside = math.abs(centre.X) <= half.X and math.abs(centre.Z) <= half.Z
		local under = math.abs(centre.X) <= extent.X and math.abs(centre.Z) <= extent.Z
		local pieceTop = centre.Y + extent.Y
		if not (inside or under) or math.abs(pieceTop - top) > NEAR then
			continue
		end
		highest = math.max(highest, pieceTop)
		if not inside then
			continue
		end
		-- Grow sideways a little at most (never over the gutters); along the lane it keeps the part's own length,
		-- so the floor, pin deck and approach skins never overlap
		minX = math.max(math.min(minX, centre.X - extent.X), -half.X - 1)
		maxX = math.min(math.max(maxX, centre.X + extent.X), half.X + 1)
	end
	local surface = highest + LIFT
	local spot = {
		CFrame = part.CFrame * CFrame.new((minX + maxX) / 2, surface - PLATE_THICKNESS / 2, (minZ + maxZ) / 2),
		Size = Vector3.new(maxX - minX, PLATE_THICKNESS, maxZ - minZ),
	}
	plateSpots[part] = spot
	return spot
end

local function texture(plate: BasePart, image: string, tile: number, transparency: number?)
	local tex = Instance.new("Texture")
	tex.Transparency = transparency or 0
	tex.Texture = AssetSlots.Image(image)
	tex.Face = Enum.NormalId.Top
	tex.StudsPerTileU = tile
	tex.StudsPerTileV = tile
	tex.Parent = plate
end

local function bit(holder: Instance, name: string, cframe: CFrame, size: Vector3): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CastShadow = false
	piece.Transparency = 1
	piece.CFrame = cframe
	piece.Size = size
	piece.Parent = holder
	return piece
end

-- Decor on a skin's plates (Config.Cosmetics Decor): picture layers on every plate; on the lane itself an
-- optional strip along each edge and a chevron of little pictures near the foul line (the spot real lanes have
-- their arrows). Candy = swirls + sprinkles, candy cane edges, peppermints; Ice = cracks, frost edges,
-- snowflakes; Lava = glowing seams, molten edges.
local function addDecor(lane: Model, part: BasePart, plate: BasePart, holder: Instance, decor)
	for _, layer in decor.Textures or {} do
		texture(plate, layer.Image, layer.Tile, layer.Transparency)
	end
	if part.Name ~= "LaneFloor" then
		return
	end
	local size = plate.Size
	local top = size.Y / 2 + LIFT
	local edge = decor.Edge
	if edge then
		for _, side in { -1, 1 } do
			local strip = bit(
				holder,
				"EdgeStrip",
				plate.CFrame * CFrame.new(side * (size.X - edge.Width) / 2, top, 0),
				Vector3.new(edge.Width, PLATE_THICKNESS, size.Z)
			)
			if edge.Color then -- a solid strip (lava glows with Neon); else only the picture shows
				strip.Transparency = 0
				strip.Color = edge.Color
				strip.Material = edge.Material or Enum.Material.SmoothPlastic
			end
			if edge.Image then
				texture(strip, edge.Image, edge.Tile, edge.Transparency)
			end
		end
	end
	local arrows = decor.Arrows
	if not arrows then
		return
	end
	-- The foul line is the end nearest the approach
	local approach = lane:FindFirstChild("Approach")
	local foul = if approach and plate.CFrame:PointToObjectSpace(approach.Position).Z < 0 then -1 else 1
	local count = arrows.Count
	local d = arrows.Size
	for i = 1, count do
		local across = (i - (count + 1) / 2) / count * size.X * 0.8
		local back = (count + 1) / 2 - math.abs(i - (count + 1) / 2) -- middle one furthest out, like lane arrows
		local z = foul * (size.Z / 2 - arrows.FromFoul - back * d * 0.9)
		local spot = bit(holder, "Arrow", plate.CFrame * CFrame.new(across, top, z), Vector3.new(d, PLATE_THICKNESS, d))
		local decal = Instance.new("Decal")
		decal.Texture = AssetSlots.Image(arrows.Image)
		decal.Face = Enum.NormalId.Top
		decal.Parent = spot
	end
end

-- Glow (Gold, Ice, Lava): a barely-there aura, a soft upright glow band along each lane edge (unturned
-- attachments make the beam stand up) and the odd glint (lava: rising embers)
local function addGlow(part: BasePart, plate: BasePart, glow)
	local size = plate.Size
	for _, side in { -1, 1 } do
		local x = side * (size.X / 2 - glow.Inset)
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(x, glow.Height, size.Z / 2)
		a0.Parent = plate
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(x, glow.Height, -size.Z / 2)
		a1.Parent = plate
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Texture = AssetSlots.Image("GlowSoft")
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.Width0 = glow.EdgeWidth
		beam.Width1 = glow.EdgeWidth
		beam.Color = ColorSequence.new(glow.Color)
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.08, glow.EdgeTransparency),
			NumberSequenceKeypoint.new(0.92, glow.EdgeTransparency),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.LightEmission = 1
		beam.Brightness = glow.Brightness
		beam.Segments = 10 -- transparency only changes between segments; 1 segment = only the faded ends
		beam.Parent = plate
	end
	if part.Name ~= "LaneFloor" then
		return
	end
	local glints = Instance.new("ParticleEmitter")
	glints.Texture = glow.GlintTexture or "rbxasset://textures/particles/sparkles_main.dds"
	glints.Color = ColorSequence.new(glow.Color)
	glints.LightEmission = 1
	glints.Rate = glow.Glints
	local life = glow.GlintLife or { 0.8, 1.4 }
	local speed = glow.GlintSpeed or { 0.2, 0.5 }
	glints.Lifetime = NumberRange.new(life[1], life[2])
	glints.Speed = NumberRange.new(speed[1], speed[2])
	glints.EmissionDirection = Enum.NormalId.Top
	glints.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.4, glow.GlintSize),
		NumberSequenceKeypoint.new(1, 0),
	})
	glints.Transparency = NumberSequence.new(0.35)
	glints.Parent = plate
end

local function skinParts(lane: Model): { BasePart }
	local parts = {}
	for _, child in lane:GetChildren() do
		if child:IsA("BasePart") and table.find(LOOKS.LaneParts, child.Name) then
			table.insert(parts, child)
		end
	end
	return parts
end

local function paint(lane: Model)
	local ownerId = lane:GetAttribute("OwnerId")
	local owner = if type(ownerId) == "number" then Players:GetPlayerByUserId(ownerId) else nil
	local skin = owner and Cosmetics.Worn(owner, "LaneSkin")
	local holder = lane:FindFirstChild("LaneSkin")
	if not skin then
		if holder then
			holder:Destroy()
		end
		return
	end
	if holder and holder:GetAttribute("Skin") == skin.Id then
		return
	end
	if holder then
		holder:Destroy()
	end
	holder = Instance.new("Folder")
	holder.Name = "LaneSkin"
	holder:SetAttribute("Skin", skin.Id)
	for _, part in skinParts(lane) do
		local spot = plateSpot(lane, part)
		local plate = Instance.new("Part")
		plate.Name = part.Name .. "Skin"
		plate.Anchored = true
		plate.CanCollide = false
		plate.CanQuery = false
		plate.CanTouch = false
		plate.CastShadow = false
		plate.CFrame = spot.CFrame
		plate.Size = spot.Size
		plate.Color = skin.Colors[1]
		plate.Material = skin.Material or Enum.Material.SmoothPlastic
		plate.TopSurface = Enum.SurfaceType.Smooth
		plate.Parent = holder
		if skin.Decor then
			addDecor(lane, part, plate, holder, skin.Decor)
		end
		if skin.Glow then
			addGlow(part, plate, skin.Glow)
		end
	end
	holder.Parent = lane
end

function LookController:Start()
	if LOOKS.Enabled ~= true then
		return
	end
	task.spawn(function()
		local lanes = LaneUtil.GetLanes()
		local function paintAll()
			for _, lane in lanes do
				paint(lane)
			end
		end
		for _, lane in lanes do
			lane:GetAttributeChangedSignal("OwnerId"):Connect(function()
				paint(lane)
			end)
		end
		-- A player putting on or taking off a skin (or buying VIP) repaints their lanes
		local function watch(player: Player)
			watched[player] = player.AttributeChanged:Connect(function(name)
				if name == SKIN_KEY or name == "Cosmetics" or name == "Passes" then
					paintAll()
				end
			end)
		end
		for _, player in Players:GetPlayers() do
			watch(player)
		end
		Players.PlayerAdded:Connect(watch)
		Players.PlayerRemoving:Connect(function(player)
			if watched[player] then
				watched[player]:Disconnect()
				watched[player] = nil
			end
			task.defer(paintAll)
		end)
		paintAll()
	end)
end

return LookController
