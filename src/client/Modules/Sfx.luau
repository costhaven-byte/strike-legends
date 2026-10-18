-- Plays the sound effects listed in Config.Sounds (Shared.AssetSlots).
-- Play = a flat sound for this player only. PlayAt = a sound coming from a spot in the world.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Sfx = {}

local folder = Instance.new("Folder")
folder.Name = "Sfx"
folder.Parent = SoundService

local templates: { [string]: Sound } = {}

local function getTemplate(name: string): Sound?
	if templates[name] then
		return templates[name]
	end
	local info = Config.Sounds[name]
	if not info then
		warn("[Sfx] No sound called " .. name)
		return nil
	end
	-- Not picked yet: borrow the stand-in sound at its own pitch
	local standIn = if info.Id then nil else Config.Sounds[info.StandIn]
	local id = info.Id or (standIn and standIn.Id)
	if not id then
		warn("[Sfx] No sound picked for " .. name)
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = "rbxassetid://" .. id
	sound.Volume = info.Volume or 0.5
	sound:SetAttribute("Pitch", if standIn then info.StandInPitch or 1 else 1)
	sound.Parent = folder
	templates[name] = sound
	return sound
end

local function start(name: string, parent: Instance, pitch: number?, volumeScale: number?): Sound?
	local template = getTemplate(name)
	if not template then
		return nil
	end
	local sound = template:Clone()
	sound.PlaybackSpeed = (pitch or 1) * (template:GetAttribute("Pitch") or 1)
	sound.Volume = template.Volume * (volumeScale or 1)
	sound.Parent = parent
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	return sound
end

function Sfx.Play(name: string, pitch: number?, volumeScale: number?): Sound?
	return start(name, folder, pitch, volumeScale)
end

-- Heard louder the closer your camera is to it. parent: a part or attachment.
function Sfx.PlayAt(name: string, parent: Instance, pitch: number?, volumeScale: number?): Sound?
	local sound = start(name, parent, pitch, volumeScale)
	if sound then
		sound.RollOffMinDistance = 20
		sound.RollOffMaxDistance = 120
	end
	return sound
end

-- Fades a playing sound out, then removes it
function Sfx.FadeOut(sound: Sound?, time: number)
	if not sound or not sound.Parent then
		return
	end
	local tween = TweenService:Create(sound, TweenInfo.new(time), { Volume = 0 })
	tween.Completed:Once(function()
		sound:Destroy()
	end)
	tween:Play()
end

-- Loads every sound in the background so the first play isn't silent
function Sfx.Preload()
	local list = {}
	for name in Config.Sounds do
		local template = getTemplate(name)
		if template then
			table.insert(list, template)
		end
	end
	task.spawn(ContentProvider.PreloadAsync, ContentProvider, list)
end

return Sfx
