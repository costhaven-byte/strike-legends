-- Brings a real pet model to life (Config.PetIdle): welds its parts to its Root so the whole pet moves as one, then
-- each frame moves its parts the way its design's idle pose does (wings flap, tails wag, eyes blink, halos turn,
-- planets orbit, glows pulse) and gives back the whole-body bob, sway and hop for whoever is placing it.
-- Only for models in the world: ViewportFrames don't run welds, so pets in the UI stay in their still pose.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local PetIdle = {}

export type Rig = {
	Root: BasePart,
	Floats: boolean,
	HalfHeight: number, -- studs from the Root down to the pet's feet
	Step: (self: Rig, now: number, animate: boolean) -> (),
	Body: (self: Rig, now: number) -> (number, CFrame), -- lift in studs, and a tilt
}

local function matches(name: string, patterns: { string }): boolean
	for _, pattern in patterns do
		if name:match(pattern) then
			return true
		end
	end
	return false
end

-- Where a group of parts turns around (in Root space): "Inner" = the point of their box nearest the pet's middle
local function pivotOf(parts: { BasePart }, root: BasePart, mode: string?): Vector3
	if mode == "Root" then
		return Vector3.zero
	end
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, part in parts do
		local center = root.CFrame:PointToObjectSpace(part.Position)
		local half = part.Size / 2
		low = low:Min(center - half)
		high = high:Max(center + half)
	end
	if mode == "Center" then
		return (low + high) / 2
	end
	return Vector3.new(math.clamp(0, low.X, high.X), math.clamp(0, low.Y, high.Y), math.clamp(0, low.Z, high.Z))
end

-- A wave from 0 to 1 and back, `speed` times per second
local function wave(now: number, speed: number, phase: number): number
	return 0.5 - 0.5 * math.cos((now * speed + phase) * math.pi * 2)
end

-- One group of parts moving together
type Group = { Parts: { BasePart }, Move: any, Pivot: Vector3, Axis: Vector3?, Sign: number, Phase: number }

local function addParticles(model: Model, root: BasePart, list: { any }, scale: number)
	for _, row in list do
		local at: BasePart? = root
		if row.At ~= "Root" then
			at = nil
			for _, part in model:GetChildren() do
				if part:IsA("BasePart") and part.Name:match(row.At) then
					at = part
					break
				end
			end
		end
		if at then
			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = "IdleParticles"
			emitter.Texture = SPARKLE
			emitter.Color = ColorSequence.new(row.Colors[1], row.Colors[2] or row.Colors[1])
			emitter.LightEmission = 1
			emitter.Size = NumberSequence.new(row.Size * scale, 0)
			emitter.Transparency = NumberSequence.new(0, 1)
			emitter.Lifetime = NumberRange.new(row.Life * 0.7, row.Life * 1.2)
			emitter.Speed = NumberRange.new(row.Speed * 0.5 * scale, row.Speed * scale)
			emitter.SpreadAngle = Vector2.new(180, 180)
			emitter.Rate = row.Rate
			emitter.Acceleration = Vector3.new(0, (row.Up or 0) * scale, 0)
			if row.Back then
				-- Drift out of the back of the pet (parts are lined up with the Root, so Back = behind the pet)
				emitter.EmissionDirection = Enum.NormalId.Back
				emitter.SpreadAngle = Vector2.new(25, 25)
				emitter.Speed = NumberRange.new(row.Back * 0.6 * scale, row.Back * scale)
				emitter.Drag = 1.5
			end
			emitter.LockedToPart = false
			emitter.Parent = at
		end
	end
end

-- Turns a still pet model (anchored parts, a Root at its middle) into a moving one. `scale` = how big it is
-- compared to the stored model (1 for pets following players).
function PetIdle.Rig(model: Model, id: string, scale: number): Rig?
	local root = model:FindFirstChild("Root") :: BasePart?
	if not root then
		return nil
	end
	local data = Config.PetIdle[id] or {}
	local body = data.Body or {}
	local parts: { BasePart } = {}
	local welds: { [BasePart]: Weld } = {}
	local baseC0: { [BasePart]: CFrame } = {}
	local baseTransparency: { [BasePart]: number } = {}
	local baseSize: { [BasePart]: Vector3 } = {}
	local baseColor: { [BasePart]: Color3 } = {}
	local bottom = 0
	root.Anchored = true
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part ~= root then
			if data.Hide and matches(part.Name, data.Hide) then
				part.Transparency = 1
			end
			local offset = root.CFrame:ToObjectSpace(part.CFrame)
			bottom = math.min(bottom, offset.Position.Y - part.Size.Y / 2)
			local weld = Instance.new("Weld")
			weld.Part0 = root
			weld.Part1 = part
			weld.C0 = offset
			weld.Parent = part
			part.Anchored = false
			part.Massless = true
			table.insert(parts, part)
			welds[part] = weld
			baseC0[part] = offset
			baseTransparency[part] = part.Transparency
			baseSize[part] = part.Size
			baseColor[part] = part.Color
		end
	end
	if data.Particles then
		addParticles(model, root, data.Particles, scale)
	end

	-- Sort every move's parts into groups (Mirror splits them into the pet's left and right)
	local groups: { Group } = {}
	local partGroups: { [BasePart]: { Group } } = {}
	for _, move in data.Moves or {} do
		local matched = {}
		for _, part in parts do
			if matches(part.Name, move.Parts) then
				table.insert(matched, part)
			end
		end
		if #matched == 0 then
			continue
		end
		local sets = { { Parts = matched, Sign = 1 } }
		if move.Mirror then
			local left, right = {}, {}
			for _, part in matched do
				table.insert(if root.CFrame:PointToObjectSpace(part.Position).X >= 0 then right else left, part)
			end
			sets = { { Parts = right, Sign = 1 }, { Parts = left, Sign = -1 } }
		end
		for _, set in sets do
			if #set.Parts == 0 then
				continue
			end
			local group: Group = {
				Parts = set.Parts,
				Move = move,
				Pivot = pivotOf(set.Parts, root, move.Pivot),
				Axis = if move.Axis then move.Axis.Unit * set.Sign else nil,
				Sign = set.Sign,
				Phase = move.Phase or 0,
			}
			table.insert(groups, group)
			for _, part in set.Parts do
				partGroups[part] = partGroups[part] or {}
				table.insert(partGroups[part], group)
			end
		end
	end
	-- Twinkles: each part gets its own offset in the cycle
	local twinkle: { [BasePart]: number } = {}
	for index, part in parts do
		twinkle[part] = (index * 0.618) % 1
	end

	-- Each pet runs a little out of step with the others (blinks, hops)
	local seed = math.random() * 10

	local rig = {
		Root = root,
		Floats = data.Floats == true,
		HalfHeight = -bottom,
	}

	function rig:Step(now: number, animate: boolean)
		if not animate then
			return
		end
		now += seed
		-- Each group's offset this frame
		local offsets: { [Group]: CFrame } = {}
		for _, group in groups do
			local move = group.Move
			local kind = move.Kind
			if kind == "Swing" then
				local angle = math.sin((now * move.Speed + group.Phase) * math.pi * 2) * math.rad(move.Angle)
				offsets[group] = CFrame.new(group.Pivot)
					* CFrame.fromAxisAngle(group.Axis :: Vector3, angle)
					* CFrame.new(-group.Pivot)
			elseif kind == "Spin" then
				local angle = now * move.Speed * math.pi * 2
				offsets[group] = CFrame.new(group.Pivot)
					* CFrame.fromAxisAngle(group.Axis :: Vector3, angle)
					* CFrame.new(-group.Pivot)
			elseif kind == "Lift" then
				local up = math.max(0, math.sin((now * move.Speed + group.Phase) * math.pi * 2)) * move.Height * scale
				offsets[group] = CFrame.new(0, up, 0)
			end
		end
		for part, list in partGroups do
			local transform = CFrame.identity
			local fade, hasFade = 1, false
			for _, group in list do
				local move = group.Move
				local kind = move.Kind
				local offset = offsets[group]
				if offset then
					transform *= offset
				elseif kind == "Slide" then
					local side = if baseC0[part].Position.X >= 0 then 1 else -1
					transform *= CFrame.new(side * wave(now, move.Speed, 0) * move.Outward * scale, 0, 0)
				elseif kind == "Pulse" or kind == "Twinkle" then
					local phase = if kind == "Twinkle" then twinkle[part] else group.Phase
					fade *= move.Min + (move.Max - move.Min) * wave(now, move.Speed, phase)
					hasFade = true
				elseif kind == "Blink" then
					-- Shut for a tenth of a second every Every seconds
					local t = (now + group.Phase) % move.Every
					local shut = if t < 0.12 then math.sin(t / 0.12 * math.pi) else 0
					part.Size = baseSize[part] * Vector3.new(1, 1 - 0.9 * shut, 1)
				elseif kind == "Rainbow" then
					local h, s, v = baseColor[part]:ToHSV()
					part.Color = Color3.fromHSV((h + now * move.Speed) % 1, s, v)
				end
			end
			welds[part].C0 = transform * baseC0[part]
			if hasFade and baseTransparency[part] < 1 then
				part.Transparency = 1 - (1 - baseTransparency[part]) * fade
			end
		end
	end

	function rig:Body(now: number): (number, CFrame)
		now += seed
		local lift = 0
		if body.Bob then
			lift += math.sin(now * (body.BobSpeed or 1) * math.pi * 2) * body.Bob * scale
		end
		local hop = body.Hop
		if hop then
			local t = now % hop.Every
			if t < hop.Time then
				lift += math.sin(t / hop.Time * math.pi) * hop.Height * scale
			end
		end
		local tilt = CFrame.identity
		if body.Sway then
			tilt = CFrame.Angles(0, 0, math.sin(now * (body.SwaySpeed or 1) * math.pi * 2) * math.rad(body.Sway))
		end
		return lift, tilt
	end

	return rig :: any
end

return PetIdle
