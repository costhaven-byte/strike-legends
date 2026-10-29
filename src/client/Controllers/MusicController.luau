-- Background music and zone ambience (Shared.AssetSlots.Music). Every 0.5 s it checks where your
-- character stands (the Config.Zones.Gated areas = zones 2-4, anywhere else = zone 1, the Pin Titan
-- fight = Boss) and cross-fades the music and the ambience loop to that place's tracks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local AssetSlots = require(Shared.AssetSlots)

local MUSIC = AssetSlots.Music
local player = Players.LocalPlayer

local MusicController = {}

local folder = Instance.new("Folder")
folder.Name = "Music"
folder.Parent = SoundService

local function inArea(area, position: Vector3): boolean
	local offset = position - area.Center
	local half = area.Size / 2
	return math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z
end

-- Which tracks should play right now
local function currentSpot()
	if player:GetAttribute("BossFighting") or player:GetAttribute("BossBoarded") then
		return MUSIC.Boss
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local position = if root then root.Position else Workspace.CurrentCamera.CFrame.Position
	for _, gate in Config.Zones.Gated do
		if inArea(gate.Area, position) then
			return MUSIC.Zones[gate.Zone] or MUSIC.Zones[1]
		end
	end
	return MUSIC.Zones[1]
end

-- One layer (music or ambience): the playing loop fades out while the new one fades in
local function layer(name: string, volume: number)
	local playing: Sound? = nil
	local playingId: number? = nil
	return function(id: number?)
		if id == playingId then
			return
		end
		playingId = id
		local info = TweenInfo.new(MUSIC.Fade, Enum.EasingStyle.Sine)
		if playing then
			local old = playing
			local tween = TweenService:Create(old, info, { Volume = 0 })
			tween.Completed:Once(function()
				old:Destroy()
			end)
			tween:Play()
			playing = nil
		end
		if id then
			local sound = Instance.new("Sound")
			sound.Name = name
			sound.SoundId = "rbxassetid://" .. id
			sound.Looped = true
			sound.Volume = 0
			sound.Parent = folder
			sound:Play()
			TweenService:Create(sound, info, { Volume = volume }):Play()
			playing = sound
		end
	end
end

function MusicController:Start()
	local setMusic = layer("Music", MUSIC.Volume)
	local setAmbience = layer("Ambience", MUSIC.AmbienceVolume)
	while true do
		local spot = currentSpot()
		setMusic(spot.Music)
		setAmbience(spot.Ambience)
		task.wait(0.5)
	end
end

return MusicController
