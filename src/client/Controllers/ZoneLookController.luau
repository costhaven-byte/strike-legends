-- Gives each zone its own mood on your screen (Config.Zones.Worlds Look): while your character stands
-- inside a zone's Area box, the lighting, haze, colour and bloom fade to that zone's look; anywhere else
-- (the lobby, Neon Lanes) they fade back to the place's normal Lighting. Also flickers broken neon letters.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local ZONES = Config.Zones
local localPlayer = Players.LocalPlayer

local ZoneLookController = {}

local haze = Lighting:FindFirstChildOfClass("Atmosphere")
local color = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
local bloom = Lighting:FindFirstChildOfClass("BloomEffect")

-- The place's own lighting, read once, so leaving a zone puts it back exactly
local function readLook()
	return {
		ClockTime = Lighting.ClockTime,
		Brightness = Lighting.Brightness,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		Exposure = Lighting.ExposureCompensation,
		Saturation = color and color.Saturation,
		Contrast = color and color.Contrast,
		Tint = color and color.TintColor,
		HazeColor = haze and haze.Color,
		HazeDecay = haze and haze.Decay,
		HazeDensity = haze and haze.Density,
		Haze = haze and haze.Haze,
		Bloom = bloom and bloom.Intensity,
	}
end

local function applyLook(look)
	local info = TweenInfo.new(ZONES.LookBlend, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, { Ambient = look.Ambient, OutdoorAmbient = look.OutdoorAmbient }):Play()
	-- (only the Addendum 4 daytime rooftop sets the sun; the place itself is night)
	if look.ClockTime then
		Lighting.ClockTime = look.ClockTime
		TweenService:Create(Lighting, info, { Brightness = look.Brightness or Lighting.Brightness }):Play()
	end
	if look.Exposure then
		TweenService:Create(Lighting, info, { ExposureCompensation = look.Exposure }):Play()
	end
	if color and look.Saturation then
		TweenService:Create(color, info, { Saturation = look.Saturation, Contrast = look.Contrast, TintColor = look.Tint }):Play()
	end
	if haze and look.HazeColor then
		TweenService:Create(haze, info, { Color = look.HazeColor, Decay = look.HazeDecay, Density = look.HazeDensity, Haze = look.Haze }):Play()
	end
	if bloom and look.Bloom then
		TweenService:Create(bloom, info, { Intensity = look.Bloom }):Play()
	end
end

local function inArea(area, position: Vector3): boolean
	local offset = position - area.Center
	local half = area.Size / 2
	return math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z
end

local function currentWorld()
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local position = if root then root.Position else Workspace.CurrentCamera.CFrame.Position
	for _, world in ZONES.Worlds do
		if world.Area and inArea(world.Area, position) then
			return world
		end
	end
	return nil
end

-- A broken neon letter: mostly dead, with short random bursts of light
local function flicker(world)
	local spec = world.Flicker
	local node: Instance? = Workspace:WaitForChild(world.Folder, 30)
	for _, name in spec.Path do
		node = node and node:WaitForChild(name, 30)
	end
	if not node then
		return
	end
	local tubes = {}
	for _, part in node:GetDescendants() do
		-- only the dead tubes (the loose wire keeps its own colour)
		if part:IsA("BasePart") and part.Color:ToHex() == spec.Dim:ToHex() then
			table.insert(tubes, part)
		end
	end
	local function set(on: boolean)
		for _, part in tubes do
			part.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
			part.Color = if on then spec.Color else spec.Dim
		end
	end
	task.spawn(function()
		while true do
			task.wait(math.random(15, 45) / 10)
			for _ = 1, math.random(2, 5) do
				set(true)
				task.wait(math.random(3, 12) / 100)
				set(false)
				task.wait(math.random(3, 15) / 100)
			end
			if math.random() < 0.3 then
				set(true)
				task.wait(math.random(4, 10) / 10)
				set(false)
			end
		end
	end)
end

-- Addendum 4 core loop: the night rooftop repainted for daytime on this screen (Config.CoreLoop DayColors/DayNeon/
-- DayLightsOff). The place file keeps the night colours.
local function daylight()
	local core = Config.CoreLoop
	local roof = Workspace:WaitForChild(core.Folder, 30)
	if not roof then
		return
	end
	local lightsOff = {}
	for _, name in core.DayLightsOff do
		lightsOff[name] = true
	end
	local function repaint(object: Instance)
		if object:IsA("BasePart") then
			local hex = object.Color:ToHex()
			local neon = object.Material == Enum.Material.Neon and core.DayNeon[hex]
			if neon then
				object.Material = neon.Material
				object.Color = neon.Color
			elseif core.DayColors[hex] then
				object.Color = core.DayColors[hex]
			end
		elseif object:IsA("Light") and (lightsOff[object.Name] or lightsOff[object.Parent and object.Parent.Name or ""]) then
			object.Enabled = false
		end
	end
	local count = 0
	for _, object in roof:GetDescendants() do
		repaint(object)
		count += 1
		if count % 2000 == 0 then
			task.wait()
		end
	end
	-- (parts that stream in later get the same paint)
	roof.DescendantAdded:Connect(repaint)
end

function ZoneLookController:Start()
	if Config.CoreLoop.Enabled then
		task.spawn(daylight)
	end
	local base = readLook()
	for _, world in ZONES.Worlds do
		if world.Flicker then
			task.spawn(flicker, world)
		end
	end
	local shown = nil
	while true do
		local world = currentWorld()
		if world ~= shown then
			shown = world
			applyLook(if world then world.Look else base)
		end
		task.wait(0.25)
	end
end

return ZoneLookController
