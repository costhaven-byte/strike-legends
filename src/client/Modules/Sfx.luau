-- Plays the sound effects listed in Config.Sounds (Shared.AssetSlots). Music + ambience: MusicController.
-- Play = a flat sound for this player only. PlayAt = a sound coming from a spot in the world.
-- Every effect plays through the "EffectsVolume" SoundGroup, which the SETTINGS switch SOUND EFFECTS mutes.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Settings = require(script.Parent:WaitForChild("Settings"))

local Sfx = {}

local folder = Instance.new("Folder")
folder.Name = "Sfx"
folder.Parent = SoundService

local group = Instance.new("SoundGroup")
group.Name = "EffectsVolume"
group.Volume = if Settings.Get("Sfx") then 1 else 0
group.Parent = SoundService
Settings.Changed("Sfx", function(on)
	group.Volume = if on then 1 else 0
end)

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
	sound.Looped = info.Loop == true -- a looped sound plays until it is faded out or its parent goes
	sound.SoundGroup = group -- copies keep it
	sound:SetAttribute("Pitch", if standIn then info.StandInPitch or 1 else 1)
	sound.Parent = folder
	templates[name] = sound
	return sound
end

-- Polish v2 Q1: when each sound last started in each place, so the same sound in the same place can't start again
-- within Config.Juice.SameSoundGap (fast taps, count-ups that tick every frame) and pile up into one loud blast
local lastStarted: { [Instance]: { [string]: number } } = setmetatable({}, { __mode = "k" }) :: any

local function start(name: string, parent: Instance, pitch: number?, volumeScale: number?): Sound?
	local template = getTemplate(name)
	if not template then
		return nil
	end
	if not template.Looped then
		local now = os.clock()
		local started = lastStarted[parent]
		if not started then
			started = {}
			lastStarted[parent] = started
		end
		if now - (started[name] or -math.huge) < Config.Juice.SameSoundGap then
			return nil
		end
		started[name] = now
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
