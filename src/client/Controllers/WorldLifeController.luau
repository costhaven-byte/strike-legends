-- Polish v2 D7 (Config.WorldLife): the living world, client only and cheap. Only the zone your camera is in moves,
-- Rate times a second, with one BulkMoveTo per kind of thing:
-- palm leaves (Map.Palms Leaf + LeafTip) bob on their crown, bunting flags (Map.Bunting Flag) flutter on their rope,
-- kites (Map.Kites) and the hot-air balloon (Map.Balloon) float, waterfall sheets (Map.Waterfalls Sheet) flow with a
-- scrolling vapour texture and foam at their feet (Foam), and the shop / sell pads pulse when you step on them.
-- SETTINGS > EFFECTS off = nothing moves (the pad pulse stays: it's feedback).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CoreLadder = require(Shared.Modules.CoreLadder)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Settings = require(Modules:WaitForChild("Settings"))
local Sfx = require(Modules:WaitForChild("Sfx"))

local LIFE = Config.WorldLife
local IMAGES = Config.BallVfx.Images

local player = Players.LocalPlayer

local WorldLifeController = {}

-- A group of parts that move together around one pivot: their rest CFrames relative to it
type Group = { Pivot: CFrame, Parts: { BasePart }, Offsets: { CFrame }, Phase: number, Axis: Vector3 }
type Zone = {
	Middle: Vector3,
	Leaves: { Group },
	Flags: { Group },
	Floaters: { { Group: Group, Bob: number, Roll: number, Speed: number } },
	Sheets: { Texture },
}

local function group(pivot: CFrame, parts: { BasePart }, phase: number, axis: Vector3): Group
	local offsets = {}
	for i, part in parts do
		offsets[i] = pivot:ToObjectSpace(part.CFrame)
	end
	return { Pivot = pivot, Parts = parts, Offsets = offsets, Phase = phase, Axis = axis }
end

local function childrenNamed(folder: Instance, name: string): { BasePart }
	local list = {}
	for _, child in folder:GetChildren() do
		if child.Name == name and child:IsA("BasePart") then
			table.insert(list, child)
		end
	end
	return list
end

local function nearest(list: { BasePart }, to: Vector3): BasePart?
	local best, bestDistance = nil, math.huge
	for _, part in list do
		local distance = (part.Position - to).Magnitude
		if distance < bestDistance then
			best, bestDistance = part, distance
		end
	end
	return best
end

-- Palm leaves: each leaf (with the tip nearest its far end) bobs around the end nearest its palm's coconuts
local function palms(folder: Instance, out: { Group })
	local leaves = childrenNamed(folder, "Leaf")
	local tips = childrenNamed(folder, "LeafTip")
	local crowns = childrenNamed(folder, "Coconut")
	if #crowns == 0 then
		crowns = childrenNamed(folder, "Trunk")
	end
	local tipOf: { [BasePart]: { BasePart } } = {}
	for _, leaf in leaves do
		tipOf[leaf] = {}
	end
	for _, tip in tips do
		local best, bestDistance = nil, math.huge
		for _, leaf in leaves do
			local half = leaf.CFrame.LookVector * leaf.Size.Z / 2
			local distance = math.min((leaf.Position + half - tip.Position).Magnitude, (leaf.Position - half - tip.Position).Magnitude)
			if distance < bestDistance then
				best, bestDistance = leaf, distance
			end
		end
		if best then
			table.insert(tipOf[best], tip)
		end
	end
	for _, leaf in leaves do
		local half = leaf.CFrame.LookVector * leaf.Size.Z / 2
		local crown = nearest(crowns, leaf.Position)
		local base = leaf.Position + half
		if crown and (leaf.Position - half - crown.Position).Magnitude < (base - crown.Position).Magnitude then
			base = leaf.Position - half
		end
		local outward = (leaf.Position - base) * Vector3.new(1, 0, 1)
		local axis = if outward.Magnitude > 0.01 then outward.Unit:Cross(Vector3.yAxis) else Vector3.xAxis
		local parts = { leaf }
		for _, tip in tipOf[leaf] do
			table.insert(parts, tip)
		end
		-- (one palm's leaves move almost together: the phase follows the crown)
		local phase = if crown then (crown.Position.X * 0.13 + crown.Position.Z * 0.07) + math.random() * 0.6 else math.random() * 6
		table.insert(out, group(CFrame.new(base), parts, phase, axis))
	end
end

-- Bunting flags: each swings around its top edge, along the rope; the phase runs along the rope like a wave
local function bunting(folder: Instance, out: { Group })
	for _, flag in childrenNamed(folder, "Flag") do
		local up = flag.CFrame.UpVector
		if up.Y < 0 then
			up = -up
		end
		local top = flag.Position + up * flag.Size.Y / 2
		-- the rope runs along the flag's plane, sideways: the flag's look (its long flat side) flattened
		local along = flag.CFrame.LookVector * Vector3.new(1, 0, 1)
		local axis = if along.Magnitude > 0.01 then along.Unit else Vector3.zAxis
		table.insert(out, group(CFrame.new(top), { flag }, (top.X + top.Z) * 0.35, axis))
	end
end

-- Kites: each kite with its halves and bows floats around its own middle
local function kites(folder: Instance, out: { any })
	local cores = childrenNamed(folder, "Kite")
	local members: { [BasePart]: { BasePart } } = {}
	for _, core in cores do
		members[core] = { core }
	end
	for _, name in { "KiteHalf", "Bow" } do
		for _, part in childrenNamed(folder, name) do
			local core = nearest(cores, part.Position)
			if core then
				table.insert(members[core], part)
			end
		end
	end
	local KITE = LIFE.Kite
	for _, core in cores do
		table.insert(out, {
			Group = group(core.CFrame, members[core], math.random() * 6, core.CFrame.LookVector),
			Bob = KITE.Bob,
			Roll = KITE.Roll,
			Speed = KITE.Speed,
		})
	end
end

local function balloon(model: Instance, out: { any })
	local parts = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(parts, part)
		end
	end
	if #parts == 0 then
		return
	end
	local centre = Vector3.zero
	for _, part in parts do
		centre += part.Position
	end
	centre /= #parts
	local BALLOON = LIFE.Balloon
	table.insert(out, {
		Group = group(CFrame.new(centre), parts, 0, Vector3.xAxis),
		Bob = BALLOON.Bob,
		Roll = 1.5,
		Speed = BALLOON.Speed,
	})
end

-- Waterfall sheets: a vapour texture scrolling down both faces, foam puffing at the feet
local function waterfalls(folder: Instance, sheets: { Texture })
	local WATER = LIFE.Waterfall
	for _, sheet in childrenNamed(folder, "Sheet") do
		-- (the sheet's big flat faces: the two faces across its thinnest side)
		local size = sheet.Size
		local faces = if size.X <= size.Y and size.X <= size.Z
			then { Enum.NormalId.Left, Enum.NormalId.Right }
			elseif size.Z <= size.Y then { Enum.NormalId.Front, Enum.NormalId.Back }
			else { Enum.NormalId.Top, Enum.NormalId.Bottom }
		for _, face in faces do
			local texture = Instance.new("Texture")
			texture.Name = "Flow"
			texture.Texture = IMAGES.TrailWisp
			texture.Face = face
			texture.StudsPerTileU = WATER.Tile
			texture.StudsPerTileV = WATER.Tile * 1.5
			texture.Transparency = WATER.Transparency
			texture.Color3 = Color3.new(1, 1, 1)
			texture.Parent = sheet
			table.insert(sheets, texture)
		end
	end
	for _, foam in childrenNamed(folder, "Foam") do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "FoamMist"
		emitter.Texture = IMAGES.Smoke
		emitter.Color = ColorSequence.new(Color3.new(1, 1, 1))
		emitter.LightInfluence = 0.6
		emitter.Rate = WATER.Foam
		emitter.Lifetime = NumberRange.new(0.8, 1.4)
		emitter.Speed = NumberRange.new(1.5, 3)
		emitter.SpreadAngle = Vector2.new(60, 20)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4) })
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-30, 30)
		emitter.Parent = foam
	end
end

local function build(folder: Instance): Zone?
	local map = folder:FindFirstChild("Map")
	if not map then
		return nil
	end
	local zone: Zone = { Middle = Vector3.zero, Leaves = {}, Flags = {}, Floaters = {}, Sheets = {} }
	local palmFolder = map:FindFirstChild("Palms")
	if palmFolder then
		palms(palmFolder, zone.Leaves)
	end
	local flagFolder = map:FindFirstChild("Bunting")
	if flagFolder then
		bunting(flagFolder, zone.Flags)
	end
	local kiteFolder = map:FindFirstChild("Kites")
	if kiteFolder then
		kites(kiteFolder, zone.Floaters)
	end
	local balloonModel = map:FindFirstChild("Balloon")
	if balloonModel then
		balloon(balloonModel, zone.Floaters)
	end
	local waterFolder = map:FindFirstChild("Waterfalls")
	if waterFolder then
		waterfalls(waterFolder, zone.Sheets)
	end
	-- (the zone's middle: the average of everything that moves)
	local sum, count = Vector3.zero, 0
	for _, list in { zone.Leaves, zone.Flags } do
		for _, g in list do
			sum += g.Pivot.Position
			count += 1
		end
	end
	for _, f in zone.Floaters do
		sum += f.Group.Pivot.Position
		count += 1
	end
	for _, texture in zone.Sheets do
		sum += (texture.Parent :: BasePart).Position
		count += 1
	end
	zone.Middle = if count > 0 then sum / count else Vector3.zero
	return zone
end

-- Turns a group around its pivot by `angle` (radians) about its axis, plus a lift; collects parts + CFrames
local function place(g: Group, rotation: CFrame, parts: { BasePart }, cframes: { CFrame })
	local pivot = g.Pivot * rotation
	for i, part in g.Parts do
		table.insert(parts, part)
		table.insert(cframes, pivot * g.Offsets[i])
	end
end

local function animate(zone: Zone, now: number)
	local parts, cframes = {}, {}
	local PALM, FLAG = LIFE.Palm, LIFE.Bunting
	for _, g in zone.Leaves do
		local angle = math.rad(PALM.Angle) * math.sin(now * PALM.Speed * 2 * math.pi + g.Phase)
		local axis = g.Pivot:VectorToObjectSpace(g.Axis)
		place(g, CFrame.fromAxisAngle(axis, angle), parts, cframes)
	end
	for _, g in zone.Flags do
		local swing = math.sin(now * FLAG.Speed * 2 * math.pi + g.Phase)
		local angle = math.rad(FLAG.Angle) * (0.6 * swing + 0.4 * math.sin(now * FLAG.Speed * 5.3 + g.Phase * 2))
		local axis = g.Pivot:VectorToObjectSpace(g.Axis)
		place(g, CFrame.fromAxisAngle(axis, angle), parts, cframes)
	end
	for _, f in zone.Floaters do
		local g = f.Group
		local t = now * f.Speed * 2 * math.pi + g.Phase
		local lift = math.sin(t) * f.Bob
		local roll = math.rad(f.Roll) * math.sin(t * 0.7 + 1.3)
		local axis = g.Pivot:VectorToObjectSpace(g.Axis)
		local rotation = CFrame.new(g.Pivot:VectorToObjectSpace(Vector3.new(0, lift, 0))) * CFrame.fromAxisAngle(axis, roll)
		place(g, rotation, parts, cframes)
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
	local WATER = LIFE.Waterfall
	for _, texture in zone.Sheets do
		texture.OffsetStudsV = (now * WATER.Speed) % (WATER.Tile * 1.5)
	end
end

local function rest(zone: Zone)
	local parts, cframes = {}, {}
	for _, list in { zone.Leaves, zone.Flags } do
		for _, g in list do
			place(g, CFrame.identity, parts, cframes)
		end
	end
	for _, f in zone.Floaters do
		place(f.Group, CFrame.identity, parts, cframes)
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- The shop / sell pad you step on: a flat ring in its colour rushes out and fades, with a soft tap
local function pulse(at: Vector3, radius: number, color: Color3)
	local PULSE = LIFE.PadPulse
	local ring = Instance.new("Part")
	ring.Name = "PadPulse"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.35
	ring.Size = Vector3.new(0.08, radius * 2, radius * 2)
	ring.CFrame = CFrame.new(at + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = Workspace
	local info = TweenInfo.new(PULSE.Time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ring, info, {
		Size = Vector3.new(0.08, radius * 2 * PULSE.Grow, radius * 2 * PULSE.Grow),
		Transparency = 1,
	}):Play()
	task.delay(PULSE.Time + 0.05, function()
		ring:Destroy()
	end)
	Sfx.Play(PULSE.Sound, 1.1, 0.5)
end

local function watchPads()
	local CORE = Config.CoreLoop
	if not CORE.Enabled then
		return
	end
	local pads = {
		{ Spot = CORE.Shop.Position, Radius = CORE.Shop.Radius, Color = CORE.Shop.Color },
		{ Spot = CORE.Sell.Position, Radius = CORE.Sell.Radius, Color = CORE.Sell.Color },
	}
	local on: { [any]: boolean } = {}
	task.spawn(function()
		while true do
			task.wait(0.1)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			for _, pad in pads do
				local here = false
				local centre = pad.Spot
				if root then
					centre = pad.Spot + CoreLadder.ZoneOffset(CoreLadder.ZoneAt(root.Position))
					local offset = root.Position - centre
					here = Vector2.new(offset.X, offset.Z).Magnitude <= pad.Radius and offset.Y > -2 and offset.Y < 8
				end
				if here and not on[pad] then
					pulse(centre, pad.Radius, pad.Color)
				end
				on[pad] = here
			end
		end
	end)
end

-- Polish v2 L5: falling far below where you last stood puts you back there (the D3 wipe covers the jump)
local function watchFalls()
	local lastSafe: CFrame? = nil
	local lastAt: Vector3? = nil
	local JUMP = Config.Motion.Wipe.Jump
	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 then
			lastSafe, lastAt = nil, nil
			return
		end
		-- (a teleport — shop, sell, gates, rebirth — isn't a fall: start over from the new spot)
		if lastAt and (root.Position - lastAt).Magnitude > JUMP then
			lastSafe = nil
		end
		lastAt = root.Position
		if humanoid.FloorMaterial ~= Enum.Material.Air then
			lastSafe = root.CFrame
		elseif lastSafe and root.Position.Y < lastSafe.Position.Y - LIFE.FallRescue then
			root.AssemblyLinearVelocity = Vector3.zero
			character:PivotTo(lastSafe + Vector3.new(0, 3, 0))
		end
	end)
end

function WorldLifeController:Start()
	if not LIFE.Enabled then
		return
	end
	watchPads()
	watchFalls()
	task.spawn(function()
		task.wait(3) -- (the zones are built by then)
		local zones: { Zone } = {}
		for _, folder in Workspace:GetChildren() do
			if folder:IsA("Folder") or folder:IsA("Model") then
				local ok, zone = pcall(build, folder)
				if ok and zone and (#zone.Leaves + #zone.Flags + #zone.Floaters + #zone.Sheets) > 0 then
					table.insert(zones, zone)
				elseif not ok then
					warn("[WorldLifeController] " .. folder.Name .. ": " .. tostring(zone))
				end
			end
		end
		local active: Zone? = nil
		local last = 0
		RunService.RenderStepped:Connect(function()
			local now = os.clock()
			if now - last < 1 / LIFE.Rate then
				return
			end
			last = now
			local camera = Workspace.CurrentCamera
			local at = camera and camera.CFrame.Position or Vector3.zero
			local want: Zone? = nil
			if Settings.Get("Vfx") then
				for _, zone in zones do
					if ((zone.Middle - at) * Vector3.new(1, 0, 1)).Magnitude <= LIFE.Near then
						want = zone
						break
					end
				end
			end
			if active and active ~= want then
				rest(active)
			end
			active = want
			if want then
				animate(want, now)
			end
		end)
	end)
end

return WorldLifeController
