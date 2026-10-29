-- The player's SETTINGS window choices (Config.Settings). Switches: Get("Vfx") is true unless the player turned it
-- off. Sliders (Kind = "Slider", e.g. MUSIC): Value("Music") is 0..1, the option's Default until moved; Get = above 0.
-- Read from the Settings attribute the server publishes from the save ("Vfx=0;Music=0.45" = only what differs from
-- the start). Set changes it here at once (so sound and effects react straight away) and asks the server to save it
-- (remote SetSetting, SettingsService); if the server's copy still disagrees a moment later, it asks again.
-- Preview changes it here only (while a slider is dragged); Set on release saves it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer

local Settings = {}

local options = {}
for _, option in Config.Settings.Options do
	options[option.Key] = option
end

local local_: { [string]: number } = {} -- values changed on this screen and not yet confirmed by the server
local listeners: { [string]: { (any) -> () } } = {}
local last: { [string]: number } = {} -- what the listeners were last told

local function isSlider(key: string): boolean
	return options[key] ~= nil and options[key].Kind == "Slider"
end

-- Sliders snap to Config.Settings.SliderStep (5%), so the saved and shown values always match
function Settings.Snap(value: number): number
	local step = Config.Settings.SliderStep
	return math.clamp(math.floor(value / step + 0.5) * step, 0, 1)
end

local function saved(key: string): number
	local text = player:GetAttribute("Settings")
	if type(text) == "string" then
		local value = (";" .. text):match(";" .. key .. "=([%d%.]+)")
		if value and tonumber(value) then
			return Settings.Snap(tonumber(value) :: number)
		end
	end
	return if isSlider(key) then options[key].Default else 1
end

function Settings.Value(key: string): number
	return local_[key] or saved(key)
end

function Settings.Get(key: string): boolean
	return Settings.Value(key) > 0
end

-- What a listener is given: a switch's on/off, a slider's 0..1
local function shown(key: string, value: number): any
	return if isSlider(key) then value else value > 0
end

-- Calls fn(on) (sliders: fn(value)) every time it changes (not now)
function Settings.Changed(key: string, fn: (any) -> ())
	listeners[key] = listeners[key] or {}
	if last[key] == nil then
		last[key] = Settings.Value(key)
	end
	table.insert(listeners[key], fn)
end

local function fire(key: string, value: number)
	last[key] = value
	for _, fn in listeners[key] or {} do
		task.spawn(fn, shown(key, value))
	end
end

local function send(key: string, value: number)
	local remote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("SetSetting") :: RemoteEvent?
	if remote then
		remote:FireServer(key, if isSlider(key) then value else value > 0)
	end
	task.delay(0.6, function()
		if local_[key] == value and saved(key) ~= value then
			send(key, value) -- the server dropped it (tapped too fast): try again
		elseif local_[key] == value then
			local_[key] = nil -- confirmed: the attribute is the truth again
		end
	end)
end

local function change(key: string, value: number)
	local_[key] = value
	if last[key] ~= value then
		fire(key, value)
	end
end

-- A switch: true/false. A slider: 0..1.
function Settings.Set(key: string, value: boolean | number)
	local number = if type(value) == "number" then Settings.Snap(value) elseif value then 1 else 0
	change(key, number)
	if saved(key) ~= number then
		send(key, number)
	else
		local_[key] = nil
	end
end

-- Slider being dragged: heard straight away, saved by the Set on release
function Settings.Preview(key: string, value: number)
	change(key, Settings.Snap(value))
end

-- Loaded from the save (or changed by another device): tell the listeners
player:GetAttributeChangedSignal("Settings"):Connect(function()
	for key in listeners do
		local now = Settings.Value(key)
		if last[key] ~= now then
			fire(key, now)
		end
	end
end)

return Settings
