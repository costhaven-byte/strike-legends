-- Camera shake: Add() a kick, then apply Offset() to the camera every frame. It dies down by itself.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Settings = require(script.Parent:WaitForChild("Settings"))

local CameraShake = {}

local strength = 0
local clock = 0
local direction = Vector2.new(0, 1) -- (Polish v2 D6: shakes ring out along one direction)

function CameraShake.Add(amount: number)
	if not Settings.Get("Shake") then -- SETTINGS: SCREEN SHAKE off
		return
	end
	if amount > strength then
		clock = 0
		direction = Vector2.new((math.random() - 0.5) * 0.8, 1).Unit
	end
	strength = math.min(strength + amount, 1.5)
end

-- A small wobble (in studs and degrees) to multiply onto the camera CFrame
function CameraShake.Offset(dt: number): CFrame
	clock += dt
	strength = math.max(0, strength - strength * Config.Juice.ShakeDecay * dt - 0.01 * dt)
	if strength <= 0.001 then
		return CFrame.identity
	end
	local s = strength * strength -- small kicks stay gentle, big ones really shake
	local swing = math.sin(clock * Config.Juice.ShakeFreq * 2 * math.pi) * s
	local jitter = Config.Juice.ShakeJitter * s
	local x = direction.X * swing + math.noise(clock * 25, 0.5) * jitter
	local y = direction.Y * swing + math.noise(clock * 25, 10.5) * jitter
	local roll = direction.X * swing * 3
	return CFrame.new(x, y, 0) * CFrame.Angles(0, 0, math.rad(roll))
end

return CameraShake
