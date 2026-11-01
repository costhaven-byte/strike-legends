-- Brightness pass (POLISH_PLAN.md, 2026-10-28): lights up the play area without repainting the zones. Each lane gets
-- a soft light strip above it (approach to pins), and your own character carries a small fill light, so lanes,
-- pins, balls and players stand out while the moody backgrounds stay dark. Colour saturation is pushed in each
-- zone's Look (Config.Zones.Worlds) and the place's NeonColor. Numbers in Config.Brightness; lights are client-only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local LaneUtil = require(Shared.Modules.LaneUtil)

local BRIGHT = Config.Brightness
local player = Players.LocalPlayer

local BrightnessController = {}

-- An invisible strip above the lane, shining down on it from the approach to the pin deck
local function lightLane(lane: Model)
	local look = BRIGHT.LaneLight[LaneUtil.ZoneOf(lane)]
	if not look or lane:FindFirstChild("PlayLight") then
		return
	end
	local start = (lane :: any).BallStart.Position
	local pins = (lane :: any).PinSpot.Position
	local forward = Vector3.new(pins.X - start.X, 0, pins.Z - start.Z).Unit
	local from = start - forward * BRIGHT.BehindStart
	local to = pins + forward * BRIGHT.PastPins
	local length = (to - from).Magnitude
	local strip = Instance.new("Part")
	strip.Name = "PlayLight"
	strip.Anchored = true
	strip.CanCollide = false
	strip.CanQuery = false
	strip.CanTouch = false
	strip.CastShadow = false
	strip.Transparency = 1
	strip.Size = Vector3.new(BRIGHT.Width, 0.2, length)
	local middle = (from + to) / 2 + Vector3.new(0, BRIGHT.Height, 0)
	strip.CFrame = CFrame.lookAt(middle, middle + forward)
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = BRIGHT.Angle
	light.Range = BRIGHT.Height + 6
	light.Brightness = look.Brightness
	light.Color = look.Color
	light.Shadows = false
	light.Parent = strip
	strip.Parent = lane
end

-- A soft light on your character, so you never melt into a dark zone
local function lightCharacter(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or root:FindFirstChild("FillLight") then
		return
	end
	local fill = BRIGHT.PlayerFill
	local light = Instance.new("PointLight")
	light.Name = "FillLight"
	light.Brightness = fill.Brightness
	light.Range = fill.Range
	light.Color = fill.Color
	light.Shadows = false
	light.Parent = root
end

function BrightnessController:Start()
	if not BRIGHT.Enabled then
		return
	end
	-- (Addendum 5 A3: the shared lane brings its own few wide lights, SharedLane.Visuals.PlayLight)
	if not LaneUtil.Shared() then
		for _, lane in LaneUtil.GetLanes() do
			lightLane(lane)
		end
	end
	if player.Character then
		task.spawn(lightCharacter, player.Character)
	end
	player.CharacterAdded:Connect(lightCharacter)
end

return BrightnessController
