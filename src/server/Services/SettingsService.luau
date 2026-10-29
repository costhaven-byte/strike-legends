-- SETTINGS window choices (Config.Settings): the client asks to change one (remote SetSetting, rate limited): a switch
-- with true/false, a slider (Kind = "Slider") with 0..1. The server keeps them in the save (field Settings, v27) as only
-- what differs from the start, "Vfx=0;Music=0.45", and the player's Settings attribute shows the same text.
-- A missing key = the start (switches on, sliders at Default), so new options need nothing in old saves.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RateLimit = require(script.Parent.Parent.Modules.RateLimit)

local SETTINGS = Config.Settings

local SettingsService = {}

local function optionFor(key: any)
	for _, option in SETTINGS.Options do
		if option.Key == key then
			return option
		end
	end
	return nil
end

local function snap(value: number): number
	local step = SETTINGS.SliderStep
	return math.clamp(math.floor(value / step + 0.5) * step, 0, 1)
end

local function onSet(player: Player, key: any, value: any)
	local option = optionFor(key)
	if not option then
		return
	end
	local slider = option.Kind == "Slider"
	if slider and (type(value) ~= "number" or value ~= value) then
		return
	elseif not slider and type(value) ~= "boolean" then
		return
	end
	if not RateLimit.Allow(player, "SetSetting") or not PlayerDataService.IsLoaded(player) then
		return
	end
	local values = {}
	local saved = PlayerDataService.Get(player, "Settings")
	for name, text in tostring(saved or ""):gmatch("([^;=]+)=([%d%.]+)") do
		if optionFor(name) and tonumber(text) then
			values[name] = tonumber(text)
		end
	end
	values[key] = if slider then snap(value) elseif value then 1 else 0
	local parts = {}
	for _, row in SETTINGS.Options do -- Config order, so the text is the same for the same choices
		local start = if row.Kind == "Slider" then row.Default else 1
		local now = values[row.Key]
		if now and math.abs(now - start) > 1e-3 then
			table.insert(parts, ("%s=%s"):format(row.Key, if row.Kind == "Slider" then ("%.2f"):format(now) else "0"))
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
