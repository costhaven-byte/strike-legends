-- Camera shake: Add() a kick, then apply Offset() to the camera every frame. It dies down by itself.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Settings = require(script.Parent:WaitForChild("Settings"))

local CameraShake = {}

local strength = 0
local clock = 0

function CameraShake.Add(amount: number)
	if not Settings.Get("Shake") then -- SETTINGS: SCREEN SHAKE off
		return
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
	local x = math.noise(clock * 25, 0.5) * s
	local y = math.noise(clock * 25, 10.5) * s
	local roll = math.noise(clock * 20, 20.5) * s * 4
	return CFrame.new(x, y, 0) * CFrame.Angles(0, 0, math.rad(roll))
end

return CameraShake
