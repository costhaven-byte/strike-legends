-- SETTINGS window switches (Config.Settings): the client asks to turn one on or off (remote SetSetting, rate
-- limited); the server keeps them in the save (field Settings, v27) as the switches that are OFF, "Music=0;Vfx=0",
-- and the player's Settings attribute shows the same text. A missing key = on, so new switches start on.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RateLimit = require(script.Parent.Parent.Modules.RateLimit)

local SETTINGS = Config.Settings

local SettingsService = {}

local function known(key: any): boolean
	for _, option in SETTINGS.Options do
		if option.Key == key then
			return true
		end
	end
	return false
end

local function onSet(player: Player, key: any, on: any)
	if type(key) ~= "string" or type(on) ~= "boolean" or not known(key) then
		return
	end
	if not RateLimit.Allow(player, "SetSetting") or not PlayerDataService.IsLoaded(player) then
		return
	end
	local off = {}
	local saved = PlayerDataService.Get(player, "Settings")
	for name in tostring(saved or ""):gmatch("([^;=]+)=0") do
		if known(name) then
			off[name] = true
		end
	end
	off[key] = not on or nil
	local parts = {}
	for _, option in SETTINGS.Options do -- Config order, so the text is the same for the same switches
		if off[option.Key] then
			table.insert(parts, option.Key .. "=0")
		end
	end
	PlayerDataService.Set(player, "Settings", table.concat(parts, ";"))
end

function SettingsService:Start()
	if not SETTINGS or not SETTINGS.Enabled then
		return
	end
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local remote = Instance.new("RemoteEvent")
	remote.Name = "SetSetting"
	remote.OnServerEvent:Connect(onSet)
	remote.Parent = remotes
end

return SettingsService
