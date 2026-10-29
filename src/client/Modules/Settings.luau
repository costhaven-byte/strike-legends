-- The player's SETTINGS window switches (Config.Settings): Get("Vfx") is true unless the player turned it off.
-- Read from the Settings attribute the server publishes from the save ("Music=0;Vfx=0" = the switches that are off).
-- Set changes the switch here at once (so sound and effects react straight away) and asks the server to save it
-- (remote SetSetting, SettingsService); if the server's copy still disagrees a moment later, it asks again.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local Settings = {}

local local_: { [string]: boolean } = {} -- switches changed on this screen and not yet confirmed by the server
local listeners: { [string]: { (boolean) -> () } } = {}
local last: { [string]: boolean } = {} -- what the listeners were last told

local function saved(key: string): boolean
	local text = player:GetAttribute("Settings")
	return not (type(text) == "string" and (";" .. text .. ";"):find(";" .. key .. "=0;", 1, true) ~= nil)
end

function Settings.Get(key: string): boolean
	local value = local_[key]
	if value == nil then
		return saved(key)
	end
	return value
end

-- Calls fn(on) every time the switch changes (not now)
function Settings.Changed(key: string, fn: (boolean) -> ())
	listeners[key] = listeners[key] or {}
	if last[key] == nil then
		last[key] = Settings.Get(key)
	end
	table.insert(listeners[key], fn)
end

local function fire(key: string, on: boolean)
	last[key] = on
	for _, fn in listeners[key] or {} do
		task.spawn(fn, on)
	end
end

local function send(key: string, on: boolean)
	local remote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("SetSetting") :: RemoteEvent?
	if remote then
		remote:FireServer(key, on)
	end
	task.delay(0.6, function()
		if local_[key] == on and saved(key) ~= on then
			send(key, on) -- the server dropped it (tapped too fast): try again
		elseif local_[key] == on then
			local_[key] = nil -- confirmed: the attribute is the truth again
		end
	end)
end

function Settings.Set(key: string, on: boolean)
	if Settings.Get(key) == on then
		return
	end
	local_[key] = on
	fire(key, on)
	send(key, on)
end

-- A switch changed by the save loading (or another device): tell the listeners
player:GetAttributeChangedSignal("Settings"):Connect(function()
	for key in listeners do
		local now = Settings.Get(key)
		if last[key] ~= now then
			fire(key, now)
		end
	end
end)

return Settings
