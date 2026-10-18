-- Draws a ball's real 3D model (ReplicatedStorage.BallModels) inside a ViewportFrame, for any screen that shows a ball:
-- the collection book, the BALLS button, the crate reel and reveal, the odds screen and the "next unlock" card.
-- Balls without a model show as a plain sphere in their colour.
-- Ball meshes download in the background; a ball drawn before its mesh arrived stays blank, so every view
-- made here is drawn again once all ball models have loaded.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SPIN_SPEED = 0.6 -- radians per second for views made with Spin = true
local SILHOUETTE = Color3.fromRGB(28, 22, 48) -- tint for balls shown as locked

local BallView = {}

-- The ball's 3D model, sitting at the origin (or a plain one-stud sphere if it has none)
function BallView.Model(ball): Instance
	local models = ReplicatedStorage:FindFirstChild("BallModels")
	local source = models and models:FindFirstChild(ball.Id)
	if source then
		local model = source:Clone() :: Model
		model:PivotTo(CFrame.new())
		return model
	end
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one
	part.Color = ball.Color
	part.Material = ball.Material or Enum.Material.SmoothPlastic
	part.CFrame = CFrame.new()
	return part
end

-- Points a viewport camera so the whole ball fills the view (models differ a little in size)
function BallView.FrameCamera(camera: Camera, model: Instance, margin: number)
	local size = if model:IsA("Model") then select(2, model:GetBoundingBox()) else (model :: BasePart).Size
	local radius = math.max(size.X, size.Y, size.Z) / 2
	local distance = radius * margin / math.tan(math.rad(camera.FieldOfView / 2))
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.25, 1).Unit * distance, Vector3.zero)
end

function BallView.Turn(model: Instance, turn: CFrame)
	if model:IsA("Model") then
		model:PivotTo(model:GetPivot() * turn)
	elseif model:IsA("BasePart") then
		model.CFrame *= turn
	end
end

type Entry = { Ball: any, Model: Instance?, Camera: Camera, Spin: boolean, Margin: number }
local views: { [ViewportFrame]: Entry } = setmetatable({}, { __mode = "k" }) :: any

local function draw(view: ViewportFrame, entry: Entry)
	if entry.Model then
		entry.Model:Destroy()
	end
	local model = BallView.Model(entry.Ball)
	BallView.FrameCamera(entry.Camera, model, entry.Margin)
	model.Parent = view
	entry.Model = model
end

-- A new ViewportFrame showing the ball. Options:
--   Spin = true: turns slowly while on screen.  Locked = true: a dark silhouette.  Margin: 1 = ball touches the edges.
function BallView.New(ball, options: { Spin: boolean?, Locked: boolean?, Margin: number? }?): ViewportFrame
	local opts = options or {}
	local view = Instance.new("ViewportFrame")
	view.Name = "Ball3D"
	view.BackgroundTransparency = 1
	view.Ambient = Color3.fromRGB(190, 190, 210)
	view.LightColor = Color3.new(1, 1, 1)
	view.LightDirection = Vector3.new(-1, -1.5, -1)
	view.ImageColor3 = if opts.Locked then SILHOUETTE else Color3.new(1, 1, 1)
	view.Active = false
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = view
	view.CurrentCamera = camera
	local entry = { Ball = ball, Model = nil, Camera = camera, Spin = opts.Spin == true, Margin = opts.Margin or 1.05 }
	draw(view, entry)
	views[view] = entry
	return view
end

-- Shows the ball in 3D inside an existing colour-dot frame (a "Swatch"): the dot itself turns see-through and the
-- 3D ball sits on top, a little bigger so it reads at small sizes. Calling it again swaps the ball.
function BallView.Put(holder: GuiObject, ball, options: { Spin: boolean?, Locked: boolean?, Margin: number? }?)
	holder.BackgroundTransparency = 1
	for _, child in holder:GetChildren() do
		if child:IsA("UIStroke") or child:IsA("UIGradient") then
			child.Enabled = false
		end
	end
	local old = holder:FindFirstChild("Ball3D")
	if old then
		views[old :: ViewportFrame] = nil
		old:Destroy()
	end
	local view = BallView.New(ball, options)
	view.AnchorPoint = Vector2.new(0.5, 0.5)
	view.Position = UDim2.fromScale(0.5, 0.5)
	view.Size = UDim2.fromScale(1.25, 1.25)
	view.ZIndex = holder.ZIndex
	view.Parent = holder
	return view
end

-- True when the view is actually on screen (it and every frame above it visible)
local function shown(view: GuiObject): boolean
	local node: Instance? = view
	while node do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		elseif node:IsA("LayerCollector") then
			return node.Enabled and node:IsDescendantOf(game)
		end
		node = node.Parent
	end
	return false
end

RunService.RenderStepped:Connect(function(dt)
	local turn = CFrame.Angles(0, dt * SPIN_SPEED, 0)
	for view, entry in views do
		if entry.Spin and entry.Model and view.Parent and shown(view) then
			BallView.Turn(entry.Model, turn)
		end
	end
end)

-- Once every ball model has downloaded, draw the views made before that again
task.spawn(function()
	local models = ReplicatedStorage:WaitForChild("BallModels", 30)
	if not models then
		return
	end
	pcall(ContentProvider.PreloadAsync, ContentProvider, { models })
	for view, entry in views do
		if view.Parent then
			draw(view, entry)
		end
	end
end)

return BallView
