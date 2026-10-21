-- The owner's "Throw result text" design (UI 1.3): Tier 1 STRIKE (hot pink + white on a starburst),
-- Tier 2 PERFECT (metallic gold on a dark plate) and OVERCOOKED (red heat, split crack, smoke, embers),
-- Tier 3 "x PINS" (navy pill). Each call fills a host (ResultText.Host) and pops it in, holds, fades out.
local TweenService = game:GetService("TweenService")

local SlUi = require(script.Parent.SlUi)

local C = SlUi.Colors
local hex = SlUi.Hex

local ResultText = {}

local STAR_ANGLES = { 0, 30, 60 } -- three squares turned 30 degrees apart = a 12-point star

-- A 12-point star (three turned squares) of the given outer radius
local function star(parent: Instance, radius: number, color: Color3, turn: number, z: number, stops: { any }?): Frame
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(radius * 2, radius * 2)
	holder.BackgroundTransparency = 1
	holder.Rotation = turn
	holder.ZIndex = z
	holder.Parent = parent
	local side = radius * math.sqrt(2)
	for _, angle in STAR_ANGLES do
		local square = Instance.new("Frame")
		square.AnchorPoint = Vector2.new(0.5, 0.5)
		square.Position = UDim2.fromScale(0.5, 0.5)
		square.Size = UDim2.fromOffset(side, side)
		square.Rotation = angle + 45
		square.BackgroundColor3 = color
		square.BorderSizePixel = 0
		square.ZIndex = z
		square.Parent = holder
		if stops then
			local gradient = SlUi.Gradient(square, stops)
			gradient.Rotation = 90 - square.Rotation -- same top-to-bottom shading on every square
		end
	end
	return holder
end

-- Thin pink rays from the middle, fading out toward the ends
local function rays(parent: Instance, radius: number, color: Color3, z: number): Frame
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(radius * 2, radius * 2)
	holder.BackgroundTransparency = 1
	holder.ZIndex = z
	holder.Parent = parent
	for i = 0, 11 do
		local ray = Instance.new("Frame")
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.fromOffset(radius * 2, math.max(4, radius * 0.09))
		ray.Rotation = i * 15 + 4
		ray.BackgroundColor3 = color
		ray.BorderSizePixel = 0
		ray.ZIndex = z
		ray.Parent = holder
		local fade = Instance.new("UIGradient")
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.32, 0.45),
			NumberSequenceKeypoint.new(0.5, 0.45),
			NumberSequenceKeypoint.new(0.68, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		})
		fade.Parent = ray
	end
	return holder
end

-- A dark plate with a glowing border behind a Tier 2 word
local function plate(parent: Instance, width: number, height: number, fill: Color3, border: Color3, z: number): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(width, height)
	frame.BackgroundColor3 = fill
	frame.ZIndex = z
	frame.Parent = parent
	SlUi.Corner(frame, UDim.new(0, height * 0.18))
	SlUi.Stroke(frame, border, math.max(2, height * 0.04), 0, true)
	-- soft glow around it
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.new(1, height * 0.3, 1, height * 0.3)
	glow.BackgroundTransparency = 1
	glow.ZIndex = z - 1
	glow.Parent = frame
	SlUi.Corner(glow, UDim.new(0, height * 0.3))
	SlUi.Stroke(glow, border, height * 0.12, 0.6, true)
	-- the drop shadow under it
	local shadow = frame:Clone()
	shadow:ClearAllChildren()
	SlUi.Corner(shadow, UDim.new(0, height * 0.18))
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.Position = UDim2.new(0.5, 0, 0.5, height * 0.09)
	shadow.ZIndex = z - 2
	shadow.Parent = parent
	return frame
end

local function wordWidth(text: string, size: number): number
	return #text * size * 0.74
end

---------------------------------------------------------------------------
-- Builders (draw into a frame centred on the spot)
---------------------------------------------------------------------------

-- Tier 1: STRIKE, streak names, OVERCHARGE. palette "Pink" (the design) or "Red" (the overcharge gamble paid off)
function ResultText.Strike(parent: Frame, text: string, size: number, palette: string?)
	local red = palette == "Red"
	local main = if red then C.Red else C.HotPink
	local deep = if red then hex("7A0810") else hex("1A0016")
	local radius = size * 1.05
	local spin = rays(parent, radius * 1.15, main, 2)
	star(parent, radius, C.White, 7, 3)
	star(parent, radius * 0.95, main, 7, 4, if red
		then { { 0, hex("FFB13A") }, { 0.5, C.Red }, { 1, hex("7A0810") } }
		else { { 0, hex("FF8CC6") }, { 0.5, C.HotPink }, { 1, hex("B0006A") } })
	local inner = star(parent, radius * 0.67, deep, -8, 5)
	for _, square in inner:GetChildren() do
		(square :: Frame).BackgroundTransparency = 0.45
	end
	local words = Instance.new("Frame")
	words.AnchorPoint = Vector2.new(0.5, 0.5)
	words.Position = UDim2.fromScale(0.5, 0.5)
	words.Size = UDim2.fromOffset(wordWidth(text, size) + size, size * 1.3)
	words.BackgroundTransparency = 1
	words.Rotation = -5
	words.ZIndex = 10
	words.Parent = parent
	SlUi.Layered(words, text, SlUi.Heavy, size, {
		{ Color = deep, Width = size * 0.057, Offset = Vector2.new(0, size * 0.05) }, -- drop shadow
		{ Color = deep, Width = size * 0.057 },
		{ Color = main, Width = size * 0.027 },
		{ Color = C.White, Width = size * 0.007, Stroke = C.White },
		{
			Color = C.White,
			Gradient = if red
				then { { 0, C.White }, { 0.52, C.White }, { 0.54, hex("FFE2A0") }, { 1, hex("FF9A2A") } }
				else { { 0, C.White }, { 0.52, C.White }, { 0.54, hex("FFD0E8") }, { 1, hex("FF9CCD") } },
		},
	})
	-- the burst slowly turns behind the word
	TweenService:Create(spin, TweenInfo.new(6, Enum.EasingStyle.Linear), { Rotation = 90 }):Play()
end

-- Tier 2: PERFECT (gold), or the same plate in another colour (HOOK! PERFECT! in the hook pink)
function ResultText.Perfect(parent: Frame, text: string, size: number, border: Color3?)
	local edge = border or C.GoldBright
	local width = wordWidth(text, size) + size * 0.5
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(width, size * 1.2)
	holder.BackgroundTransparency = 1
	holder.Rotation = -3
	holder.Parent = parent
	plate(holder, width, size * 0.75, hex("0B0F24"), edge, 3)
	local labels = SlUi.Layered(holder, text, SlUi.Heavy, size, {
		{ Color = hex("140B00"), Width = size * 0.073, Offset = Vector2.new(0, size * 0.06) },
		{ Color = hex("140B00"), Width = size * 0.073 },
		{ Color = hex("FFF1A8"), Width = size * 0.03 },
		{ Color = hex("8A5200"), Width = size * 0.01 },
		{
			Color = C.White,
			Gradient = {
				{ 0, hex("FFFBE6") },
				{ 0.28, hex("FFE066") },
				{ 0.5, hex("F7A600") },
				{ 0.51, hex("FFCF3A") },
				{ 0.68, hex("FFF2A6") },
				{ 1, hex("D98A00") },
			},
		},
		{ Color = C.White }, -- the shine that sweeps across once
	})
	if border then
		labels[3].TextColor3 = border:Lerp(C.White, 0.6)
	end
	local shine = labels[#labels]
	local band = Instance.new("UIGradient")
	band.Rotation = 20
	band.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.47, 0.05),
		NumberSequenceKeypoint.new(0.52, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	band.Offset = Vector2.new(-1, 0)
	band.Parent = shine
	TweenService:Create(band, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Offset = Vector2.new(1, 0),
	}):Play()
	-- glint sparks at the corners
	for _, spark in { { 0, 0, size * 0.17, 0.6, 1.4 }, { 1, 1, size * 0.13, 1.4, 0.6 }, { 0.85, 0, size * 0.08, 1, 1 } } do
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale(spark[1], spark[2])
		dot.Size = UDim2.fromOffset(spark[3] * spark[4], spark[3] * spark[5])
		dot.Rotation = 45
		dot.BackgroundColor3 = hex("FFF6C2")
		dot.BorderSizePixel = 0
		dot.ZIndex = 20
		dot.Parent = holder
		SlUi.Stroke(dot, hex("FFE066"), 2, 0.4, true)
	end
end

-- Tier 2 danger: OVERCOOKED (cracked in two, smoking), with a small line under it ("GUTTER", "STREAK OVER")
function ResultText.Overcooked(parent: Frame, text: string, size: number, note: string?)
	local width = wordWidth(text, size) + size * 0.4
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(width, size * 1.3)
	holder.BackgroundTransparency = 1
	holder.Rotation = 2.5
	holder.Parent = parent
	-- smoke behind
	for _, puff in { { 0.78, -0.35, 1.3 }, { 0.62, -0.55, 1 }, { 0.22, -0.3, 1.1 } } do
		local cloud = Instance.new("Frame")
		cloud.AnchorPoint = Vector2.new(0.5, 0.5)
		cloud.Position = UDim2.fromScale(puff[1], puff[2] + 0.5)
		cloud.Size = UDim2.fromOffset(size * puff[3], size * puff[3] * 0.7)
		cloud.BackgroundColor3 = hex("6E6E7D")
		cloud.BackgroundTransparency = 0.55
		cloud.ZIndex = 1
		cloud.Parent = holder
		SlUi.Corner(cloud)
		TweenService:Create(cloud, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(puff[1], puff[2]),
			BackgroundTransparency = 0.85,
		}):Play()
	end
	plate(holder, width, size * 0.78, hex("140405"), hex("FF3B2F"), 3)
	local heat = { { 0, hex("FFE2A0") }, { 0.32, hex("FF9A2A") }, { 0.55, hex("FF5A1A") }, { 0.8, hex("E0141F") }, { 1, hex("7A0810") } }
	-- the word, split in two along the crack: the bottom half knocked down and right
	for half = 0, 1 do
		local clip = Instance.new("Frame")
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.ZIndex = 10
		clip.Size = UDim2.fromScale(1, 0.5)
		clip.Position = UDim2.new(0, half * size * 0.05, half * 0.5, half * size * 0.05)
		clip.Parent = holder
		local inner = Instance.new("Frame")
		inner.BackgroundTransparency = 1
		inner.Size = UDim2.fromScale(1, 2)
		inner.Position = UDim2.fromScale(0, -half)
		inner.Parent = clip
		SlUi.Layered(inner, text, SlUi.Heavy, size, {
			{ Color = hex("1A0505"), Width = size * 0.078 },
			{ Color = hex("FF3B2F"), Width = size * 0.031 },
			{ Color = C.White, Gradient = heat },
		})
	end
	-- embers drifting up
	for _, ember in { { 0.18, 10 }, { 0.46, 7 }, { 0.78, 9 }, { 0.94, 6 } } do
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale(ember[1], 0.1)
		dot.Size = UDim2.fromOffset(ember[2], ember[2])
		dot.BackgroundColor3 = hex("FFB13A")
		dot.ZIndex = 20
		dot.Parent = holder
		SlUi.Corner(dot)
		SlUi.Stroke(dot, hex("FF7A1A"), 2, 0.3, true)
		TweenService:Create(dot, TweenInfo.new(1 + math.random() * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(ember[1] + (math.random() - 0.5) * 0.1, -0.4),
			BackgroundTransparency = 1,
		}):Play()
	end
	if note then
		local line = SlUi.Label(holder, note, SlUi.Heavy, size * 0.32, C.White)
		line.Position = UDim2.new(0.5, 0, 1, size * 0.2)
		line.Size = UDim2.new(1, 0, 0, size * 0.4)
		line.ZIndex = 30
		SlUi.Stroke(line, hex("1A0505"), size * 0.06)
	end
end

-- Tier 3: "7 PINS" in a navy pill ("1 PIN"), with an optional small line under it ("SO CLOSE", "STREAK OVER")
function ResultText.Pins(parent: Frame, count: number, size: number, note: string?)
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(0, size * 1.25)
	holder.AutomaticSize = Enum.AutomaticSize.X
	holder.BackgroundColor3 = hex("0B1228")
	holder.Rotation = -2
	holder.Parent = parent
	SlUi.Corner(holder)
	SlUi.Stroke(holder, hex("22E6FF"), 3, 0, true)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, size * 0.32)
	pad.PaddingRight = UDim.new(0, size * 0.4)
	pad.Parent = holder
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, size * 0.18)
	list.Parent = holder
	local function part(text: string, textSize: number, color: Color3, stroke: Color3, width: number)
		local label = SlUi.Label(holder, text, SlUi.Heavy, textSize, color)
		label.AnchorPoint = Vector2.zero
		label.Size = UDim2.fromOffset(0, size)
		label.AutomaticSize = Enum.AutomaticSize.X
		label.ZIndex = 5
		SlUi.Stroke(label, stroke, width)
		return label
	end
	part(tostring(count), size, C.White, hex("0A5F80"), size * 0.0625)
	part(if count == 1 then "PIN" else "PINS", size * 0.56, hex("22E6FF"), hex("04121F"), size * 0.047)
	if note then
		local line = SlUi.Label(parent, note, SlUi.Heavy, size * 0.42, C.White)
		line.Position = UDim2.new(0.5, 0, 0.5, size * 1.15)
		line.Size = UDim2.new(1, 0, 0, size * 0.5)
		SlUi.Stroke(line, C.Ink, size * 0.07)
	end
end

---------------------------------------------------------------------------
-- Host: a CanvasGroup that pops a piece in, holds it, then fades it out
---------------------------------------------------------------------------
export type Host = { Group: CanvasGroup, Scale: UIScale, Token: number }

function ResultText.Host(parent: Instance, name: string, size: Vector2): Host
	local group = Instance.new("CanvasGroup")
	group.Name = name
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Size = UDim2.fromOffset(size.X, size.Y)
	group.BackgroundTransparency = 1
	group.Visible = false
	group.Parent = parent
	local scale = Instance.new("UIScale")
	scale.Parent = group
	return { Group = group, Scale = scale, Token = 0 }
end

-- Clears the host and gives back a fresh frame to draw into
function ResultText.Clear(host: Host): Frame
	for _, child in host.Group:GetChildren() do
		if not child:IsA("UIScale") then
			child:Destroy()
		end
	end
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = host.Group
	return frame
end

-- In big (Throw Lab pop), settle, hold `time`, then grow a touch and fade
function ResultText.Pop(host: Host, time: number)
	host.Token += 1
	local token = host.Token
	local group, scale = host.Group, host.Scale
	group.Visible = true
	group.GroupTransparency = 0
	group.Rotation = (math.random() - 0.5) * 6
	scale.Scale = 0.3
	TweenService:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.12 }):Play()
	task.delay(0.14, function()
		if token == host.Token then
			TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
		end
	end)
	task.delay(time * 0.65, function()
		if token ~= host.Token then
			return
		end
		local out = TweenInfo.new(time * 0.35)
		TweenService:Create(scale, out, { Scale = 1.08 }):Play()
		TweenService:Create(group, out, { GroupTransparency = 1 }):Play()
		task.wait(time * 0.35)
		if token == host.Token then
			group.Visible = false
		end
	end)
end

return ResultText
