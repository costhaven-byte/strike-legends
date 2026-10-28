-- Polish P4: big floating signs over every station (EGGS, CRATES, FUSION...) so you always know where to go, even
-- from far away or on a phone. Each sign is a HUD Kit pill (the kit's face + darker lip, ink outline, icon and word in
-- Luckiest Guy) on a BillboardGui sized in studs plus a few pixels per stud, so it reads the same on every screen and
-- never shrinks to nothing far away. Built from code over the station found at runtime (Config.AreaSigns), so it
-- needs no Studio work. Client only: nothing here touches the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local HudKit = require(Modules:WaitForChild("HudKit"))

local SIGNS = Config.AreaSigns
local C = HudKit.C

local AreaSignController = {}

type Sign = { Gui: BillboardGui, Strokes: { UIStroke }, Base: Vector3, Phase: number, Px: number }
local live: { Sign } = {}

local function find(path: { string }): Instance?
	local node: Instance? = Workspace
	for _, name in path do
		node = node and node:WaitForChild(name, 60)
	end
	return node
end

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local object = Instance.new(className)
	for key, value in props do
		(object :: any)[key] = value
	end
	object.Parent = parent
	return object
end

-- The word's width in studs when it is `height` studs tall (measured in the kit's heading font)
local function wordWidth(text: string, height: number): number
	local params = Instance.new("GetTextBoundsParams")
	params.Text = text
	params.Font = HudKit.Head
	params.Size = 100
	params.Width = 1e5
	local ok, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
	local ratio = if ok then bounds.X / 100 else #text * 0.7
	return ratio * height
end

-- Highest point of an egg stand's odds bubbles (Polish P3), so the sign stays clear of them
local function bubbleTop(station: Instance): number?
	local board: BillboardGui? = nil
	local waited = 0
	while not board and waited < 20 do
		board = station:FindFirstChild("EggOdds", true) :: BillboardGui?
		if not board then
			waited += task.wait(0.5)
		end
	end
	local shell = board and board.Parent
	if not board or not shell or not shell:IsA("BasePart") then
		return nil
	end
	return shell.Position.Y + board.StudsOffset.Y + board.Size.Y.Scale / 2
end

local function build(row)
	local station = find(row.Path)
	if not station then
		warn(("[AreaSignController] %s not found"):format(table.concat(row.Path, ".")))
		return
	end
	local cf, size
	if station:IsA("Model") then
		cf, size = station:GetBoundingBox()
	elseif station:IsA("BasePart") then
		cf, size = station.CFrame, station.Size
	else
		return
	end

	local H = SIGNS.Height
	-- Bottom edge: Lift above the station's top, moved by Offset; above an egg stand's odds bubbles
	local bottom = cf.Position.Y + size.Y / 2 + (row.Lift or SIGNS.Lift)
	local spot = Vector3.new(cf.Position.X, 0, cf.Position.Z) + (row.Offset or Vector3.zero)
	bottom += (row.Offset or Vector3.zero).Y
	if row.Egg then
		local top = bubbleTop(station)
		if top then
			bottom = math.max(bottom, top + SIGNS.EggGap)
		end
	end
	-- Never into a ceiling right above it
	-- (from the station's middle height; see-through parts like zone triggers don't count)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = { station }
	params.FilterDescendantsInstances = skip
	local from = Vector3.new(spot.X, cf.Position.Y, spot.Z)
	local hit = Workspace:Raycast(from, Vector3.new(0, 200, 0), params)
	local tries = 0
	while hit and hit.Instance.Transparency >= 0.95 and tries < 10 do
		table.insert(skip, hit.Instance)
		params.FilterDescendantsInstances = skip
		hit = Workspace:Raycast(from, Vector3.new(0, 200, 0), params)
		tries += 1
	end
	if hit then
		bottom = math.min(bottom, hit.Position.Y - SIGNS.CeilingGap - H - SIGNS.Bob)
	end
	local center = Vector3.new(spot.X, bottom + H / 2, spot.Z)

	-- Layout in studs: [pad][icon][gap][word][pad]
	local pad, iconSize, gap = H * 0.32, H * 0.78, H * 0.14
	local wordH = H * 0.62
	local wordW = wordWidth(row.Text, wordH) + H * 0.12 -- + the outline
	local W = pad + iconSize + gap + wordW + pad
	local px = SIGNS.MinPixels

	local anchor = make("Part", {
		Name = "AreaSign_" .. row.Text,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 1,
		Size = Vector3.one * 0.2,
		CFrame = CFrame.new(center),
	}, nil)
	local gui = make("BillboardGui", {
		Name = "Sign",
		LightInfluence = 0,
		AlwaysOnTop = false,
		MaxDistance = SIGNS.MaxDistance,
		Size = UDim2.new(W, W * px, H, H * px),
		ResetOnSpawn = false,
	}, anchor)
	local face, lip = C[row.Paint] or C.Gold, C[row.Paint .. "Lip"] or C.GoldLip
	-- the lip (darker, full size, ink outline) with the face on top of it, leaving the lip showing underneath
	local lipFrame = make("Frame", {
		Name = "Lip",
		BackgroundColor3 = lip,
		Size = UDim2.fromScale(1, 1),
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, lipFrame)
	local strokes = {}
	table.insert(
		strokes,
		make(
			"UIStroke",
			{ Color = C.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round },
			lipFrame
		)
	)
	local faceFrame = make("Frame", {
		Name = "Face",
		BackgroundColor3 = face,
		Size = UDim2.fromScale(1, 0.86),
	}, lipFrame)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, faceFrame)
	local shine = make("Frame", {
		Name = "Shine",
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.7,
		Position = UDim2.fromScale(pad / W, 0.1),
		Size = UDim2.fromScale(1 - 2 * pad / W, 0.16),
	}, faceFrame)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, shine)
	make("ImageLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Image = HudKit.Icon(row.Icon),
		ScaleType = Enum.ScaleType.Fit,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(pad / W, 0.5),
		Size = UDim2.fromScale(iconSize / W, iconSize / H / 0.86),
	}, faceFrame)
	local word = make("TextLabel", {
		Name = "Word",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale((pad + iconSize + gap) / W, 0.52),
		Size = UDim2.fromScale(wordW / W, wordH / H / 0.86),
		FontFace = HudKit.Head,
		Text = row.Text,
		TextScaled = true,
		TextColor3 = C.White,
	}, faceFrame)
	table.insert(strokes, make("UIStroke", { Color = C.Ink, LineJoinMode = Enum.LineJoinMode.Round }, word))
	anchor.Parent = Workspace

	-- Step aside while the station's own marker is on (Rizzo's GO HERE! sits in the same spot)
	if row.HideWhile then
		task.spawn(function()
			local other = station:FindFirstChild(row.HideWhile, true)
			local waited = 0
			while not other and waited < 60 do
				waited += task.wait(1)
				other = station:FindFirstChild(row.HideWhile, true)
			end
			if other and other:IsA("BillboardGui") then
				local function sync()
					gui.Enabled = not other.Enabled
				end
				other:GetPropertyChangedSignal("Enabled"):Connect(sync)
				sync()
			end
		end)
	end

	local sign: Sign = { Gui = gui, Strokes = strokes, Base = center, Phase = #live * 0.7, Px = -1 }
	table.insert(live, sign)
end

function AreaSignController:Start()
	if not SIGNS.Enabled then
		return
	end
	for _, row in SIGNS.Signs do
		task.spawn(build, row)
	end
	-- Bob, and keep the outlines in step with the sign's size on screen (UIStroke widths are pixels)
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, sign in live do
			local tall = sign.Gui.AbsoluteSize.Y
			local width = math.max(1, math.floor(tall * 0.07 + 0.5))
			if width ~= sign.Px then
				sign.Px = width
				for _, stroke in sign.Strokes do
					stroke.Thickness = width
				end
			end
			sign.Gui.StudsOffsetWorldSpace =
				Vector3.new(0, math.sin((t * SIGNS.BobSpeed + sign.Phase) * math.pi * 2) * SIGNS.Bob, 0)
		end
	end)
end

return AreaSignController
