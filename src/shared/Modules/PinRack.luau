-- Builds a rack of 10 pins, knocks them flying and resets them. Used by the client for throw visuals.
-- Lane surprises change the rack too: a Golden Pin, bigger pins (Giant Pins) and sliding pins (Moving Pins), and
-- lane events (Config.LaneEvents): every pin gold (GoldenRack), only pins 7 and 10 (Split) or one gem pin (GemPin).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Parent.Config)

local LANE = Config.Lane

local PinRack = {}
PinRack.__index = PinRack

-- Cylinders in Roblox lie along their X axis; this stands them upright.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local function makePart(name: string, shape: Enum.PartType, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CustomPhysicalProperties = PhysicalProperties.new(LANE.PinDensity, 0.4, 0.3)
	return part
end

-- One pin: wide body, thin neck with a neon stripe, round head. Base is the root part.
local function buildPin(baseCFrame: CFrame, scale: number): Model
	local h, w = LANE.PinHeight * scale, LANE.PinWidth * scale
	local bodyH, neckH = h * 0.58, h * 0.2
	local headD = w * 0.7

	local pin = Instance.new("Model")
	pin.Name = "Pin"

	local white = Color3.fromRGB(245, 245, 250)
	local body = makePart("Body", Enum.PartType.Cylinder, Vector3.new(bodyH, w, w), white, Enum.Material.SmoothPlastic)
	body.CFrame = baseCFrame * CFrame.new(0, bodyH / 2, 0) * UPRIGHT
	body.Parent = pin

	local neck = makePart(
		"Neck",
		Enum.PartType.Cylinder,
		Vector3.new(neckH, w * 0.5, w * 0.5),
		Color3.fromRGB(255, 40, 120),
		Enum.Material.Neon
	)
	neck.CFrame = baseCFrame * CFrame.new(0, bodyH + neckH / 2, 0) * UPRIGHT
	neck.Parent = pin

	local head =
		makePart("Head", Enum.PartType.Ball, Vector3.new(headD, headD, headD), white, Enum.Material.SmoothPlastic)
	head.CFrame = baseCFrame * CFrame.new(0, bodyH + neckH + headD / 2 - 0.05, 0)
	head.Parent = pin

	for _, part in { neck, head } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = part
		weld.Parent = body
	end

	pin.PrimaryPart = body
	return pin
end

-- Designed pins: mesh templates in ReplicatedStorage.PinModels (StandardPin, GoldenPin, GoldenStar).
-- Until those are uploaded, the simple part pins above are used instead.
-- Neck rings from the designs: height and width are fractions of the pin's height and width.
local STANDARD_RINGS = {
	{ Name = "RingBottom", Height = 0.621, Width = 0.63, Color = Color3.fromRGB(34, 242, 255) },
	{ Name = "RingTop", Height = 0.707, Width = 0.63, Color = Color3.fromRGB(255, 43, 214) },
}
local GOLDEN_RINGS = {
	{ Name = "BandLower", Height = 0.625, Width = 0.44, Color = Color3.fromRGB(255, 244, 176) },
	{ Name = "BandUpper", Height = 0.685, Width = 0.39, Color = Color3.fromRGB(255, 244, 176) },
}
local GOLD_BODY = Color3.fromRGB(255, 207, 74)
local GOLD_AURA = Color3.fromRGB(255, 226, 138)
local GOLD_STAR = Color3.fromRGB(255, 246, 194)

-- A part that rides along with the pin: welded, weightless, never collides
local function attach(body: BasePart, part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = part
	weld.Parent = part
	part.Parent = body.Parent
end

-- Zone pin sets: ReplicatedStorage.PinModels.<zone folder> holds StandardPin and GoldenPin models (several
-- coloured MeshParts, PrimaryPart "Body"; stood on their bottom, any pivot). Back Alley's beat-up pins come from the
-- owner's design; the Golden Pin bonus uses the design's Golden Star pin.
local function buildZonePin(set: Instance, baseCFrame: CFrame, scale: number, golden: boolean): Model?
	local template = set:FindFirstChild(if golden then "GoldenPin" else "StandardPin")
	if not (template and template:IsA("Model") and template.PrimaryPart) then
		return nil
	end
	local h = LANE.PinHeight * scale
	local pin = template:Clone()
	local _, size = pin:GetBoundingBox()
	pin:ScaleTo(h / size.Y)
	-- Stand it on its bottom whatever the template's pivot is (the designed pins pivot at their middle)
	local box = pin:GetBoundingBox()
	local lift = pin:GetPivot().Position.Y - (box.Position.Y - h / 2)
	pin:PivotTo(baseCFrame * CFrame.new(0, lift, 0))
	local body = pin.PrimaryPart :: BasePart
	body.CustomPhysicalProperties = PhysicalProperties.new(LANE.PinDensity, 0.4, 0.3)
	for _, part in pin:GetDescendants() do
		if part:IsA("BasePart") and part ~= body then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = part
			weld.Parent = part
		end
	end
	if golden then
		-- Glow on the deck under the pin, like the lobby set's Golden Pin. Not welded, so it stays put.
		local w = LANE.PinWidth * scale
		local glow = Instance.new("Part")
		glow.Name = "FloorGlow"
		glow.Shape = Enum.PartType.Cylinder
		glow.Size = Vector3.new(0.04, w * 2.8, w * 2.8)
		glow.CFrame = baseCFrame * CFrame.new(0, 0.03, 0) * UPRIGHT
		glow.Color = GOLD_AURA
		glow.Material = Enum.Material.Neon
		glow.Transparency = 0.6
		glow.Anchored = true
		glow.CanCollide = false
		glow.CanQuery = false
		glow.CanTouch = false
		glow.CastShadow = false
		glow.Parent = pin
	end
	return pin
end

local function buildMeshPin(baseCFrame: CFrame, scale: number, golden: boolean, zone: string?): Model?
	local models = ReplicatedStorage:FindFirstChild("PinModels")
	local set = models and zone and models:FindFirstChild(zone)
	if set then
		local pin = buildZonePin(set, baseCFrame, scale, golden)
		if pin then
			return pin
		end
	end
	local template = models and models:FindFirstChild(if golden then "GoldenPin" else "StandardPin")
	if not template then
		return nil
	end
	local h, w = LANE.PinHeight * scale, LANE.PinWidth * scale

	local pin = Instance.new("Model")
	pin.Name = "Pin"
	local body = template:Clone() :: MeshPart
	body.Name = "Body"
	body.Size = Vector3.new(w, h, w)
	body.CFrame = baseCFrame * CFrame.new(0, h / 2, 0)
	body.CustomPhysicalProperties = PhysicalProperties.new(LANE.PinDensity, 0.4, 0.3)
	body.Parent = pin
	pin.PrimaryPart = body

	for _, ring in if golden then GOLDEN_RINGS else STANDARD_RINGS do
		local part = Instance.new("Part")
		part.Name = ring.Name
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(h * 0.03, w * ring.Width, w * ring.Width)
		part.CFrame = baseCFrame * CFrame.new(0, h * ring.Height, 0) * UPRIGHT
		part.Color = ring.Color
		part.Material = Enum.Material.Neon
		attach(body, part)
	end

	if golden then
		body.Color = GOLD_BODY
		body.Material = Enum.Material.Foil

		-- The design's three glow shells, merged into one see-through shell
		local aura = template:Clone() :: MeshPart
		aura.Name = "Aura"
		aura.Size = Vector3.new(w * 1.38, h * 1.09, w * 1.38)
		aura.CFrame = body.CFrame
		aura.Color = GOLD_AURA
		aura.Material = Enum.Material.Neon
		aura.Transparency = 0.82
		attach(body, aura)

		local starTemplate = models:FindFirstChild("GoldenStar") :: MeshPart?
		if starTemplate then
			local star = starTemplate:Clone()
			star.Name = "Star"
			star.Size = starTemplate.Size * scale
			star.CFrame = baseCFrame * CFrame.new(0, h * 1.22, 0)
			star.Color = GOLD_STAR
			star.Material = Enum.Material.Neon
			attach(body, star)
		end

		-- Glow on the deck under the pin. Not welded, so it stays put when the pin flies.
		local glow = Instance.new("Part")
		glow.Name = "FloorGlow"
		glow.Shape = Enum.PartType.Cylinder
		glow.Size = Vector3.new(0.04, w * 2.8, w * 2.8)
		glow.CFrame = baseCFrame * CFrame.new(0, 0.03, 0) * UPRIGHT
		glow.Color = GOLD_AURA
		glow.Material = Enum.Material.Neon
		glow.Transparency = 0.6
		glow.Anchored = true
		glow.CanCollide = false
		glow.CanQuery = false
		glow.CanTouch = false
		glow.CastShadow = false
		glow.Parent = pin
	end
	return pin
end

-- Addendum 4 core loop rack (Config.CoreLoop.Rack): a Rows-row triangle minus the Remove pins, numbered row by row
-- from the head pin, left to right. Worked out once.
local coreOffsets: { Vector3 }? = nil
local function coreRack(): { Vector3 }
	if coreOffsets then
		return coreOffsets
	end
	local rack = Config.CoreLoop.Rack
	local removed = {}
	for _, spot in rack.Remove do
		removed[spot[1] .. ":" .. spot[2]] = true
	end
	local offsets = {}
	local rowDepth = rack.Spacing * math.sqrt(3) / 2
	for row = 1, rack.Rows do
		for place = 1, row do
			if not removed[row .. ":" .. place] then
				local x = (place - 1 - (row - 1) / 2) * rack.Spacing
				table.insert(offsets, Vector3.new(x, 0, -(row - 1) * rowDepth))
			end
		end
	end
	coreOffsets = offsets
	return offsets
end

-- Pins in one rack (40 in the core loop, else Config.Lane.PinCount)
function PinRack.Count(): number
	return if Config.CoreLoop.Enabled then #coreRack() else LANE.PinCount
end

-- Distance between neighbouring pins in the rack in use
function PinRack.Spacing(): number
	return if Config.CoreLoop.Enabled then Config.CoreLoop.Rack.Spacing else LANE.PinSpacing
end

-- Standard triangle: row 0 has the head pin, row 3 has four pins (the core loop's rack when that is on).
-- Offsets are relative to the head pin; -Z points down the lane.
function PinRack.Offsets(): { Vector3 }
	if Config.CoreLoop.Enabled then
		return coreRack()
	end
	local offsets = {}
	local rowDepth = LANE.PinSpacing * math.sqrt(3) / 2
	for row = 0, 3 do
		for i = 0, row do
			local x = (i - row / 2) * LANE.PinSpacing
			table.insert(offsets, Vector3.new(x, 0, -row * rowDepth))
		end
	end
	return offsets
end

-- headPinCFrame: on the deck surface, facing down the lane (away from the bowler).
function PinRack.new(headPinCFrame: CFrame, parent: Instance)
	local self = setmetatable({}, PinRack)
	self.HeadPinCFrame = headPinCFrame
	self.Folder = Instance.new("Folder")
	self.Folder.Name = "Pins"
	self.Folder.Parent = parent
	self.Pins = {}
	self.Scale = 1 -- pin size (Giant Pins)
	self.Offset = 0 -- studs the rack has slid sideways (Moving Pins)
	self.Golden = 0 -- which pin is golden (0 = none)
	self.Event = "" -- the lane event on this rack ("" = none)
	self.EventPin = 0 -- the GemPin event's pin
	self.TimeScale = 1 -- below 1 during strike slow motion
	-- Addendum 4 core loop: pins are pooled and knocked pins fly on as capped debris while the next rack stands
	self.Core = Config.CoreLoop.Enabled
	self.Pool = {} -- spare pin models (parented to nothing)
	self.Debris = {} -- { Pin = Model, At = os.clock() } knocked pins still flying, oldest first
	if self.Core then
		self.Scale = Config.CoreLoop.Rack.PinScale
	end
	-- Which zone the lane is in (its Workspace lane folder), for that zone's pin set
	for _, folder in Config.Zones.LaneFolders do
		if parent:FindFirstAncestor(folder) then
			self.Zone = folder
			break
		end
	end
	self:Reset()
	return self
end

-- Golden Pin look: shiny gold, glowing and sparkling. soft = one of a GOLDEN RACK's ten (dimmer, fewer sparkles)
local function makeGolden(pin: Model, soft: boolean?)
	local gold = Config.GoldenPin.Color
	local rack = Config.LaneEvents.GoldenRack
	-- Simple part pins only; the designed golden pin already has its own colours
	local neck = pin:FindFirstChild("Neck") :: BasePart?
	if neck then
		neck.Color = Color3.new(1, 1, 1)
		for _, name in { "Body", "Head" } do
			local part = pin:FindFirstChild(name) :: BasePart
			part.Color = gold
			part.Material = Enum.Material.Foil
		end
	end
	local body = pin.PrimaryPart :: BasePart
	local light = Instance.new("PointLight")
	light.Color = gold
	light.Range = if soft then 6 else 10
	light.Brightness = if soft then rack.PinLight else 3
	light.Parent = body
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(gold, Color3.new(1, 1, 1))
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new(0.45, 0)
	sparkles.Lifetime = NumberRange.new(0.6, 1.1)
	sparkles.Speed = NumberRange.new(1, 2.5)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Rate = if soft then rack.PinSparkles else 14
	sparkles.Parent = body
end

-- GEM PIN look: the pin turns crystal cyan, glows and sparkles, with a gem spinning over its head
local function makeGem(pin: Model)
	local events = Config.LaneEvents
	local color = events.GemColor
	local body = pin.PrimaryPart :: BasePart
	for _, part in pin:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "FloorGlow" then
			-- the body is cyan crystal, every other piece (head, rings) a paler glowing cyan
			part.Color = if part == body then color else color:Lerp(Color3.new(1, 1, 1), 0.4)
			part.Material = if part == body then Enum.Material.Glass else Enum.Material.Neon
			if part:IsA("MeshPart") then
				part.TextureID = ""
			end
			local look = part:FindFirstChildOfClass("SurfaceAppearance")
			if look then
				look:Destroy()
			end
		end
	end
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 9
	light.Brightness = events.GemLight
	light.Parent = body
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new(0.4, 0)
	sparkles.Lifetime = NumberRange.new(0.6, 1.1)
	sparkles.Speed = NumberRange.new(1, 2.5)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Rate = 12
	sparkles.Parent = body
	-- The gem: a small neon diamond floating over the pin (welded, so it flies with it)
	local box, size = pin:GetBoundingBox()
	local gem = Instance.new("Part")
	gem.Name = "Gem"
	gem.Size = Vector3.one * LANE.PinWidth * 0.55
	gem.Color = color
	gem.Material = Enum.Material.Neon
	gem.CFrame = CFrame.new(body.Position.X, box.Position.Y + size.Y / 2 + gem.Size.Y, body.Position.Z)
		* CFrame.Angles(math.rad(45), 0, math.rad(45))
	attach(body, gem)
end

-- Where pin `index` stands, including the Moving Pins slide
function PinRack:SpotFor(index: number): CFrame
	return self.HeadPinCFrame * CFrame.new(PinRack.Offsets()[index] + Vector3.new(self.Offset, 0, 0))
end

-- Slides every standing pin sideways (Moving Pins). Knocked pins are left to fly.
function PinRack:SetOffset(offset: number)
	local delta = offset - self.Offset
	if math.abs(delta) < 0.001 then
		return
	end
	self.Offset = offset
	local shift = self.HeadPinCFrame.RightVector * delta
	for _, pin in self.Pins do
		local body = pin.PrimaryPart
		if body and body.Anchored then
			pin:PivotTo(pin:GetPivot() + shift)
		end
	end
end

-- ===== Addendum 4 core loop: pooled pins and capped debris =====
-- A pin taken back from the debris: no trail, no pull, standing and anchored, out of the world
local function cleanPin(pin: Model)
	local body = pin.PrimaryPart :: BasePart
	body.Anchored = true
	for _, child in body:GetChildren() do
		if child:IsA("Trail") or child:IsA("Attachment") or child:IsA("VectorForce") then
			child:Destroy()
		end
	end
	for _, part in pin:GetDescendants() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = 0
		end
	end
	pin:SetAttribute("Down", nil)
	pin.Parent = nil
end

-- A standing pin at spot `index`, from the pool when there is one
function PinRack:_takePin(index: number): Model
	local spot = self:SpotFor(index)
	local pin = table.remove(self.Pool)
	if pin then
		pin:PivotTo(spot * (pin:GetAttribute("Stand") :: CFrame? or CFrame.identity))
	else
		pin = buildMeshPin(spot, self.Scale, false, self.Zone) or buildPin(spot, self.Scale)
		-- how the pin's pivot sits on its spot, so a pooled pin stands the same way again
		pin:SetAttribute("Stand", spot:ToObjectSpace(pin:GetPivot()))
		-- Addendum 5 A3: on the shared lane your pins are yours alone: they never touch players or balls
		local shared = Config.CoreLoop.SharedLane
		if self.Core and shared and shared.Enabled then
			for _, part in pin:GetDescendants() do
				if part:IsA("BasePart") then
					part.CollisionGroup = shared.Groups.Pins
				end
			end
		end
	end
	pin.Name = "Pin" .. index
	pin.PrimaryPart.Anchored = true
	pin.Parent = self.Folder
	return pin
end

-- Debris older than DebrisLife (or over DebrisCap, oldest first) goes back into the pool
function PinRack:_sweep()
	local core = Config.CoreLoop
	local now = os.clock()
	while #self.Debris > 0 and (#self.Debris > core.DebrisCap or now - self.Debris[1].At >= core.DebrisLife) do
		local item = table.remove(self.Debris, 1)
		cleanPin(item.Pin)
		table.insert(self.Pool, item.Pin)
	end
end

-- The instant refill: every knocked pin becomes debris (it keeps flying) and a fresh pin stands in its spot
function PinRack:Refill()
	self.TimeScale = 1
	local now = os.clock()
	for index, pin in self.Pins do
		local body = pin.PrimaryPart
		if not body or not body.Anchored or pin:GetAttribute("Down") then
			pin.Name = "Debris"
			table.insert(self.Debris, { Pin = pin, At = now })
			self.Pins[index] = self:_takePin(index)
		end
	end
	self:_sweep()
	if #self.Debris > 0 and not self.Sweeping then
		-- keep sweeping until the last debris is gone
		self.Sweeping = true
		task.spawn(function()
			while #self.Debris > 0 and self.Folder.Parent do
				task.wait(0.2)
				self:_sweep()
			end
			self.Sweeping = false
		end)
	end
end

-- Other players' lanes: a light scripted knockdown (no physics). The pin tips over away from `from`, slides back
-- and fades while it falls; it stays anchored the whole time.
function PinRack:Topple(index: number, from: Vector3)
	local pin = self.Pins[index]
	local body = pin and pin.PrimaryPart
	if not body or not body.Anchored or pin:GetAttribute("Down") then
		return
	end
	pin:SetAttribute("Down", true)
	local start = pin:GetPivot()
	local away = (body.Position - from) * Vector3.new(1, 0, 1)
	if away.Magnitude < 0.05 then
		away = self.HeadPinCFrame.LookVector
	end
	away = (away.Unit + self.HeadPinCFrame.LookVector).Unit
	local axis = Vector3.yAxis:Cross(away).Unit
	local slide = away * (1.5 + math.random() * 2.5)
	local lie = math.rad(80 + math.random() * 20)
	local parts = {}
	for _, part in pin:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(parts, part)
		end
	end
	local began = os.clock()
	local TIME = 0.35
	task.spawn(function()
		while pin.Parent == self.Folder or pin.Name == "Debris" do
			local t = math.min((os.clock() - began) / TIME, 1)
			local k = 1 - (1 - t) * (1 - t) -- ease out
			pin:PivotTo(CFrame.fromAxisAngle(axis, lie * k) * start.Rotation + start.Position + slide * k)
			if t >= 0.6 then
				for _, part in parts do
					part.LocalTransparencyModifier = (t - 0.6) / 0.4
				end
			end
			if t >= 1 or not pin:GetAttribute("Down") then
				break
			end
			task.wait()
		end
	end)
end

-- Puts all 10 pins back, standing and anchored (they only move when knocked).
function PinRack:Reset()
	self.TimeScale = 1
	if self.Core then
		-- core loop: every pin goes back into the pool and the whole rack stands again from it
		for _, pin in self.Pins do
			cleanPin(pin)
			table.insert(self.Pool, pin)
		end
		for _, item in self.Debris do
			cleanPin(item.Pin)
			table.insert(self.Pool, item.Pin)
		end
		table.clear(self.Debris)
		table.clear(self.Pins)
		for index in PinRack.Offsets() do
			self.Pins[index] = self:_takePin(index)
		end
		return
	end
	self.Folder:ClearAllChildren()
	table.clear(self.Pins)

	local allGold = self.Event == "GoldenRack"
	local only = if self.Event == "Split" then Config.LaneEvents.Split.Pins else nil
	for index in PinRack.Offsets() do
		if only and not table.find(only, index) then
			continue -- the 7-10 split: only the back corners stand
		end
		local golden = index == self.Golden or allGold
		local gem = self.Event == "GemPin" and index == self.EventPin
		local pin = buildMeshPin(self:SpotFor(index), self.Scale, golden, self.Zone)
		if not pin then
			pin = buildPin(self:SpotFor(index), self.Scale)
		end
		if golden then
			makeGolden(pin, allGold)
		elseif gem then
			makeGem(pin)
		end
		pin.Name = "Pin" .. index
		pin.PrimaryPart.Anchored = true
		pin.Parent = self.Folder
		self.Pins[index] = pin
	end
end

-- A short glowing streak behind a flying pin
local function addTrail(body: BasePart)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.3, 0)
	a0.Parent = body
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.3, 0)
	a1.Parent = body
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 40, 120))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.LightEmission = 0.6
	trail.Lifetime = 0.25
	trail.FaceCamera = true
	trail.Parent = body
end

-- Lab numbers were tuned on bigger pins; this scales speeds and gravity so flights look the same here
local function labScale(): number
	return PinRack.Spacing() / Config.Throw.LabPinSpacing
end

-- Flying pins fall with Config.Throw.PinGravity (lighter than the world's, for floatier flights) without
-- changing the world's gravity for players. A slow-motion timeScale weakens it to match.
function PinRack:_pullFor(body: BasePart): number
	local scale = self.TimeScale
	local wanted = Config.Throw.PinGravity * labScale() * scale * scale
	return body.AssemblyMass * (workspace.Gravity - wanted)
end

-- Sends one pin flying away from `from` (the Throw Lab explosion: mostly back, partly sideways, some luck).
-- force: how hard (1 = a normal ball at full strength).
-- Returns the force it actually flew with (or nil if it was already down).
function PinRack:Knock(index: number, from: Vector3, force: number): number?
	local pin = self.Pins[index]
	local body = pin and pin.PrimaryPart
	if not body or not body.Anchored then
		return nil
	end
	local T = Config.Throw
	local k = labScale()
	local forward = self.HeadPinCFrame.LookVector -- down the lane
	local right = self.HeadPinCFrame.RightVector

	local away = body.Position - from
	away = Vector3.new(away.X, 0, away.Z)
	if away.Magnitude < 0.05 then
		away = forward
	end
	local direction = (away.Unit + forward * 0.6 + right * ((math.random() - 0.5) * 0.8)).Unit
	local f = force * (0.85 + math.random() * 0.3)
	local velocity = direction * T.PinLaunchForce * k * f
		-- upward grows a bit slower than sideways, so pins from the strongest balls still come back into view
		+ Vector3.new(0, T.PinLaunchUpward * k * f ^ 0.7 * (0.8 + math.random() * 0.4), 0)
	local spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit
		* T.PinSpin
		* math.sqrt(f)
		* (0.7 + math.random() * 0.6)

	addTrail(body)
	body.Anchored = false
	local attachment = Instance.new("Attachment")
	attachment.Name = "Pull"
	attachment.Parent = body
	local pull = Instance.new("VectorForce")
	pull.Name = "Pull"
	pull.Attachment0 = attachment
	pull.RelativeTo = Enum.ActuatorRelativeTo.World
	pull.ApplyAtCenterOfMass = true
	pull.Force = Vector3.new(0, self:_pullFor(body), 0)
	pull.Parent = body
	body.AssemblyLinearVelocity = velocity * self.TimeScale
	body.AssemblyAngularVelocity = spin * self.TimeScale
	return f
end

-- A pin that stays standing gives a little wobble when the ball grazes it
function PinRack:Wobble(index: number)
	local pin = self.Pins[index]
	local body = pin and pin.PrimaryPart
	if not body or not body.Anchored or pin:GetAttribute("Wobbling") then
		return
	end
	pin:SetAttribute("Wobbling", true)
	local start = pin:GetPivot()
	local axis = self.HeadPinCFrame.RightVector
	task.spawn(function()
		for i = 1, 6 do
			if not body.Parent or not body.Anchored then
				return
			end
			local tilt = math.rad(9) * (1 - i / 6) * (if i % 2 == 0 then 1 else -1)
			pin:PivotTo(CFrame.fromAxisAngle(axis, tilt) * start.Rotation + start.Position)
			task.wait(0.04)
		end
		if body.Parent and body.Anchored then
			pin:PivotTo(start)
		end
		pin:SetAttribute("Wobbling", nil)
	end)
end

-- Slow motion: every flying pin (and its pull) runs at `scale` of normal speed. 1 = back to normal.
function PinRack:SetTimeScale(scale: number)
	local factor = scale / self.TimeScale
	self.TimeScale = scale
	for _, pin in self.Pins do
		local body = pin.PrimaryPart
		if body and not body.Anchored then
			body.AssemblyLinearVelocity *= factor
			body.AssemblyAngularVelocity *= factor
			local pull = body:FindFirstChild("Pull") :: VectorForce?
			if pull and pull:IsA("VectorForce") then
				pull.Force = Vector3.new(0, self:_pullFor(body), 0)
			end
		end
	end
end

function PinRack:Destroy()
	self.Folder:Destroy()
	for _, pin in self.Pool do
		pin:Destroy()
	end
	for _, item in self.Debris do
		item.Pin:Destroy()
	end
end

return PinRack
