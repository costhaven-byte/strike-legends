-- Builds the placeholder looks for mascots and eggs (Addendum 2 section 9.7: a coloured ball with eyes per rarity).
-- Used by the mascots that follow players, the PETS panel and the hatching moment.
-- Every part is anchored and never collides; the front of a mascot (its eyes) faces the model's -Z.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Mascots = require(Shared.Modules.Mascots)

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local MascotView = {}

local function part(model: Model, name: string, size: Vector3, color: Color3, offset: CFrame, root: BasePart?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Ball
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.CFrame = if root then root.CFrame * offset else offset
	p.Parent = model
	return p
end

-- A mascot: body ball, two eyes with pupils, a tuft on top and two cheeks in its accent colour.
-- Rare and up glow in their rarity colour; Legendary and up also sparkle. effects = false skips glow and sparkles
-- (for small UI views).
function MascotView.Mascot(mascot, size: number, effects: boolean?): Model
	local model = Instance.new("Model")
	model.Name = mascot.Id
	local body = part(model, "Body", Vector3.one * size, mascot.Color, CFrame.new())
	model.PrimaryPart = body
	local s = size
	for _, side in { -1, 1 } do
		part(
			model,
			"Eye",
			Vector3.one * s * 0.32,
			Color3.new(1, 1, 1),
			CFrame.new(side * s * 0.19, s * 0.1, -s * 0.36),
			body
		)
		part(
			model,
			"Pupil",
			Vector3.one * s * 0.16,
			Color3.fromRGB(15, 10, 25),
			CFrame.new(side * s * 0.19, s * 0.1, -s * 0.5),
			body
		)
		part(
			model,
			"Cheek",
			Vector3.one * s * 0.13,
			mascot.Accent,
			CFrame.new(side * s * 0.32, -s * 0.12, -s * 0.38),
			body
		)
	end
	part(model, "Tuft", Vector3.one * s * 0.3, mascot.Accent, CFrame.new(0, s * 0.52, 0), body)

	local rarity = Mascots.RarityIndex(mascot.Rarity)
	if effects ~= false and rarity >= Mascots.RarityIndex("Rare") then
		local light = Instance.new("PointLight")
		light.Color = Mascots.RarityColor(mascot.Rarity)
		light.Range = 5 + rarity
		light.Brightness = 1.2
		light.Parent = body
		if rarity >= Mascots.RarityIndex("Legendary") then
			local sparkle = Instance.new("ParticleEmitter")
			sparkle.Texture = SPARKLE
			sparkle.Color = ColorSequence.new(Mascots.RarityColor(mascot.Rarity), mascot.Accent)
			sparkle.LightEmission = 1
			sparkle.Size = NumberSequence.new(0.3, 0)
			sparkle.Lifetime = NumberRange.new(0.6, 1)
			sparkle.Speed = NumberRange.new(0.5, 1.5)
			sparkle.SpreadAngle = Vector2.new(180, 180)
			sparkle.Rate = if rarity >= Mascots.RarityIndex("Mythic") then 14 else 8
			sparkle.Parent = body
		end
	end
	return model
end

-- An egg: a stretched ball with coloured spots. height = studs tall.
function MascotView.Egg(eggId: string, height: number): Model
	local look = Config.EggLooks[eggId] or Config.EggLooks.Alley
	local model = Instance.new("Model")
	model.Name = eggId .. "Egg"
	local shell = Instance.new("Part")
	shell.Name = "Shell"
	shell.Size = Vector3.new(height * 0.78, height, height * 0.78)
	shell.Color = look.Color
	shell.Material = Enum.Material.SmoothPlastic
	shell.Anchored = true
	shell.CanCollide = false
	shell.CanQuery = false
	shell.CanTouch = false
	shell.CastShadow = false
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = shell
	shell.Parent = model
	model.PrimaryPart = shell
	-- Spots on the surface (an egg is an ellipsoid: radius r sideways, h up)
	local r, h = height * 0.39, height * 0.5
	local spots = {
		{ 0, 0.25, 0.1 },
		{ 2.1, -0.1, 0.13 },
		{ 4.2, 0.35, 0.09 },
		{ 1.1, -0.45, 0.08 },
		{ 3.3, 0.05, 0.11 },
		{ 5.3, -0.35, 0.1 },
	}
	for _, spot in spots do
		local angle, y, scale = spot[1], spot[2], spot[3]
		local ring = math.sqrt(1 - y * y)
		local position = Vector3.new(math.cos(angle) * r * ring, y * h, math.sin(angle) * r * ring)
		part(model, "Spot", Vector3.one * height * scale * 2, look.Spots, CFrame.new(position), shell)
	end
	return model
end

-- Points a ViewportFrame camera at a model so it fills `fill` of the view (1 = touching the edges)
function MascotView.FrameCamera(camera: Camera, model: Model, fill: number?)
	local cf, size = model:GetBoundingBox()
	local radius = size.Magnitude / 2
	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) / (fill or 0.9)
	-- Looking at the front (-Z) of the model, a little from above
	local direction = Vector3.new(0, 0.25, -1).Unit
	camera.CFrame = CFrame.lookAt(cf.Position + direction * distance, cf.Position)
end

-- A ViewportFrame showing a model, already framed. Returns the frame and its camera.
function MascotView.Viewport(parent: Instance, model: Model, fill: number?): (ViewportFrame, Camera)
	local view = Instance.new("ViewportFrame")
	view.BackgroundTransparency = 1
	view.Ambient = Color3.fromRGB(190, 190, 210)
	view.LightColor = Color3.new(1, 1, 1)
	view.LightDirection = Vector3.new(-1, -1.5, -1)
	view.Size = UDim2.fromScale(1, 1)
	view.Active = false
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = view
	view.CurrentCamera = camera
	model:PivotTo(CFrame.new())
	model.Parent = view
	MascotView.FrameCamera(camera, model, fill)
	view.Parent = parent
	return view, camera
end

return MascotView
