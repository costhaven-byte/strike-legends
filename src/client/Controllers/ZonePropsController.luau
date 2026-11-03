-- 2026-11-03 v2 models: moving bits of the owner's zone props. The zone 2 ferris wheel (ZoneMaps, a "Wheel" model
-- tagged SpinWheel with a Spin attribute in radians a second): rims, spokes and bulbs turn round its hub along the
-- design's Root look; each Gondola model rides round with its gondola_bar and stays upright. Only near the camera.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local NEAR = 700 -- studs: further away than this the wheel waits (nobody sees it turn)

local ZonePropsController = {}

type Wheel = {
	model: Model,
	centre: Vector3,
	axis: Vector3,
	speed: number,
	angle: number,
	parts: { BasePart },
	base: { CFrame }, -- each turning part's start CFrame
	cabins: { { parts: { BasePart }, base: { CFrame }, hang: Vector3 } },
}

local wheels: { [Model]: Wheel } = {}

local function setup(model: Instance)
	if not model:IsA("Model") or wheels[model] then
		return
	end
	local root = model.Parent and (model.Parent :: Model).PrimaryPart
	local hub = model:FindFirstChild("hub")
	if not root or not hub or not hub:IsA("BasePart") then
		return
	end
	local wheel: Wheel = {
		model = model,
		centre = hub.Position,
		axis = root.CFrame.LookVector,
		speed = model:GetAttribute("Spin") or 0.06,
		angle = 0,
		parts = {},
		base = {},
		cabins = {},
	}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(wheel.parts, child)
			table.insert(wheel.base, child.CFrame)
		elseif child:IsA("Model") and child.Name == "Gondola" then
			local bar
			for _, p in child:GetChildren() do
				if p.Name:match("^gondola_bar") then
					bar = p
				end
			end
			if bar and bar:IsA("BasePart") then
				local cabin = { parts = {}, base = {}, hang = bar.Position }
				for _, p in child:GetDescendants() do
					if p:IsA("BasePart") then
						table.insert(cabin.parts, p)
						table.insert(cabin.base, p.CFrame)
					end
				end
				table.insert(wheel.cabins, cabin)
			end
		end
	end
	wheels[model] = wheel
end

function ZonePropsController:Start()
	CollectionService:GetInstanceAddedSignal("SpinWheel"):Connect(setup)
	CollectionService:GetInstanceRemovedSignal("SpinWheel"):Connect(function(model)
		wheels[model :: Model] = nil
	end)
	for _, model in CollectionService:GetTagged("SpinWheel") do
		setup(model)
	end

	RunService.RenderStepped:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		if not camera or next(wheels) == nil then
			return
		end
		for model, w in wheels do
			if not model.Parent then
				wheels[model] = nil
				continue
			end
			if (camera.CFrame.Position - w.centre).Magnitude > NEAR then
				continue
			end
			w.angle = (w.angle + w.speed * dt) % (math.pi * 2)
			local turn = CFrame.fromAxisAngle(w.axis, w.angle)
			local about = CFrame.new(w.centre) * turn * CFrame.new(-w.centre)
			local parts, cfs = table.clone(w.parts), table.create(#w.parts + 64)
			for i, base in w.base do
				cfs[i] = about * base
			end
			for _, cabin in w.cabins do
				local shift = (about * cabin.hang) - cabin.hang
				for i, p in cabin.parts do
					table.insert(parts, p)
					table.insert(cfs, cabin.base[i] + shift)
				end
			end
			Workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return ZonePropsController
