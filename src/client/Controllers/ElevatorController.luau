-- The elevators to the Skyline Lanes roof (owner 2026-10-22, Config.Elevators). Each car is built in code on this
-- screen (so it lives in git): a doorway with sliding steel doors, a lit cabin behind them, a sign with where it
-- goes and a RIDE prompt. The roof car also gets a little elevator house around it. The prompt only shows once
-- zone 4 is open (the zone gate's wall covers the Main Street doors until then). A ride: the server checks it,
-- the doors open, the screen goes dark ("GOING UP..."), the server moves you, and the doors at the top open.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Zones = require(Shared.Modules.Zones)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules:WaitForChild("Sfx"))

local player = Players.LocalPlayer

local ELEVATORS = Config.Elevators

local FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local INK = Color3.fromHex("06060F")
local DARK = Color3.fromRGB(46, 42, 74) -- the roof design's helipad_dark
local STEEL = Color3.fromRGB(150, 156, 172)
local CABIN = Color3.fromRGB(255, 214, 150)
local GOLD = Color3.fromRGB(245, 184, 46)
local SIGN = Color3.fromRGB(14, 10, 34)

local DOOR_W, DOOR_H = 8, 11
local DOOR_SLIDE = 3.8
local DOOR_TIME = 0.45

local ElevatorController = {}

local function newPart(
	parent: Instance,
	name: string,
	size: Vector3,
	color: Color3,
	cf: CFrame,
	material: Enum.Material?,
	solid: boolean?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = solid == true
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = cf
	p.Parent = parent
	return p
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Parent = parent
end

local function label(parent: Instance, value: string, color: Color3, y: number, height: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = FONT
	l.TextScaled = true
	l.Text = value
	l.TextColor3 = color
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, y)
	l.Size = UDim2.fromScale(0.92, height)
	l.Parent = parent
	stroke(l, INK, 2)
	return l
end

-- One car. Local space: x across the doorway, y up, out = toward where you stand
local function build(folder: Instance, car)
	local model = Instance.new("Model")
	model.Name = car.Id
	local function at(x: number, y: number, out: number): CFrame
		return car.Door * CFrame.new(x, y, -out)
	end

	if car.Housing then
		-- The little elevator house on the open roof, with a gold band round the top
		newPart(model, "House", Vector3.new(20, 16, 14), DARK, at(0, 8, -7), nil, true)
		newPart(model, "HouseCap", Vector3.new(20.6, 0.8, 14.6), GOLD, at(0, 16.2, -7))
		newPart(model, "HouseGlow", Vector3.new(20.8, 0.25, 14.8), GOLD, at(0, 15.6, -7), Enum.Material.Neon)
		newPart(model, "HouseBase", Vector3.new(20.6, 0.6, 14.6), GOLD, at(0, 0.3, -7))
	end

	-- The cabin you see through the open doors
	local cabin = newPart(model, "Cabin", Vector3.new(DOOR_W + 0.2, DOOR_H, 0.2), CABIN, at(0, DOOR_H / 2, 0.1))
	local glow = Instance.new("SurfaceLight")
	glow.Face = Enum.NormalId.Front
	glow.Color = CABIN
	glow.Brightness = 2
	glow.Range = 10
	glow.Enabled = false -- on only while the doors are open
	glow.Parent = cabin
	newPart(model, "Handrail", Vector3.new(DOOR_W - 1, 0.3, 0.3), GOLD, at(0, 3.6, 0.3))

	local doors = {}
	for side = -1, 1, 2 do
		local closed = at(side * DOOR_W / 4, DOOR_H / 2, 0.35)
		local door = newPart(
			model,
			if side < 0 then "DoorL" else "DoorR",
			Vector3.new(DOOR_W / 2, DOOR_H, 0.3),
			STEEL,
			closed,
			Enum.Material.Metal,
			true
		)
		table.insert(doors, { Part = door, Closed = closed, Open = closed * CFrame.new(side * DOOR_SLIDE, 0, 0) })
	end

	-- The frame (wide side posts hide the doors when they slide open)
	for side = -1, 1, 2 do
		newPart(
			model,
			"Post",
			Vector3.new(4, DOOR_H + 2, 0.8),
			DARK,
			at(side * (DOOR_W / 2 + 2), (DOOR_H + 2) / 2, 0.75),
			nil,
			true
		)
		newPart(
			model,
			"PostGlow",
			Vector3.new(0.25, DOOR_H, 0.85),
			GOLD,
			at(side * (DOOR_W / 2 + 0.1), DOOR_H / 2, 0.75),
			Enum.Material.Neon
		)
	end
	newPart(model, "Header", Vector3.new(DOOR_W + 8, 2, 0.8), DARK, at(0, DOOR_H + 1, 0.75), nil, true)
	newPart(
		model,
		"HeaderGlow",
		Vector3.new(DOOR_W + 0.2, 0.25, 0.85),
		GOLD,
		at(0, DOOR_H + 0.1, 0.75),
		Enum.Material.Neon
	)

	-- Where it goes
	local sign = newPart(model, "Sign", Vector3.new(11, 2.6, 0.3), SIGN, at(0, DOOR_H + 3.4, 0.75))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = sign
	label(gui, "ELEVATOR", Color3.new(1, 1, 1), 0.27, 0.36)
	label(gui, car.Arrow .. " " .. car.Sign, GOLD, 0.7, 0.44)

	-- Call button beside the door
	newPart(model, "CallPlate", Vector3.new(1.2, 2, 0.2), DARK, at(DOOR_W / 2 + 4.8, 4.5, 0.1))
	newPart(model, "CallButton", Vector3.new(0.6, 0.6, 0.3), GOLD, at(DOOR_W / 2 + 4.8, 4.5, 0.2), Enum.Material.Neon)

	-- The RIDE prompt, in front of the doors at walking height
	local spot = newPart(model, "PromptSpot", Vector3.one, CABIN, at(0, 3, 3))
	spot.Transparency = 1
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = car.Action
	prompt.ObjectText = "ELEVATOR"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = ELEVATORS.PromptRange
	prompt.RequiresLineOfSight = false
	prompt.Parent = spot

	model.Parent = folder
	return { Doors = doors, Prompt = prompt, Model = model, Light = glow }
end

local function moveDoors(car, open: boolean)
	if open then
		car.Light.Enabled = true
	else
		task.delay(DOOR_TIME, function()
			car.Light.Enabled = false
		end)
	end
	local info = TweenInfo.new(DOOR_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	for _, door in car.Doors do
		TweenService:Create(door.Part, info, { CFrame = if open then door.Open else door.Closed }):Play()
	end
end

function ElevatorController:Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local remote = remotes:WaitForChild("RideElevator") :: RemoteEvent

	local folder = Instance.new("Folder")
	folder.Name = "Elevators"
	folder.Parent = Workspace
	local cars = {}
	for _, info in ELEVATORS.Cars do
		local car = build(folder, info)
		car.Info = info
		cars[info.Id] = car
		car.Prompt.Triggered:Connect(function()
			remote:FireServer(info.Id)
		end)
	end

	-- The prompts only show once the roof is open to you
	local function refresh()
		local open = Zones.Unlocked(player:GetAttribute("ZonesOpen"), ELEVATORS.Zone)
		for _, car in cars do
			car.Prompt.Enabled = open
		end
	end
	refresh()
	player:GetAttributeChangedSignal("ZonesOpen"):Connect(refresh)

	-- The dark ride screen
	local gui = Instance.new("ScreenGui")
	gui.Name = "ElevatorUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 60
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local shade = Instance.new("Frame")
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = SIGN
	shade.BackgroundTransparency = 1
	shade.Parent = gui
	local rideText = Instance.new("TextLabel")
	rideText.BackgroundTransparency = 1
	rideText.FontFace = FONT
	rideText.TextScaled = true
	rideText.TextColor3 = GOLD
	rideText.TextTransparency = 1
	rideText.AnchorPoint = Vector2.new(0.5, 0.5)
	rideText.Position = UDim2.fromScale(0.5, 0.5)
	rideText.Size = UDim2.fromScale(0.6, 0.09)
	rideText.Parent = shade
	local textStroke = Instance.new("UIStroke")
	textStroke.Color = INK
	textStroke.Thickness = 3
	textStroke.Transparency = 1
	textStroke.Parent = rideText

	local function fade(dark: boolean, time: number)
		local info = TweenInfo.new(time, Enum.EasingStyle.Quad)
		local t = if dark then 0 else 1
		TweenService:Create(shade, info, { BackgroundTransparency = t }):Play()
		TweenService:Create(rideText, info, { TextTransparency = t }):Play()
		TweenService:Create(textStroke, info, { Transparency = t }):Play()
	end

	remote.OnClientEvent:Connect(function(fromId: string, toId: string)
		local from, to = cars[fromId], cars[toId]
		if not (from and to) then
			return
		end
		moveDoors(from, true)
		Sfx.Play("ElevatorDing", 1)
		rideText.Text = from.Info.RideText
		gui.Enabled = true
		fade(true, 0.35)
		task.wait(ELEVATORS.RideSeconds)
		moveDoors(from, false)
		moveDoors(to, true)
		fade(false, 0.4)
		Sfx.Play("ElevatorDing", 1.2)
		task.wait(0.45)
		gui.Enabled = false
		task.wait(1.2)
		moveDoors(to, false)
	end)
end

return ElevatorController
