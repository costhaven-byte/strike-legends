-- Holds each player's coins, gems, XP, balls and more on the server, and saves them with SaveStore.
-- Number and text values are mirrored to Player attributes so the HUD can read them; only the server changes them.
-- Table values (like OwnedBalls) are not mirrored; the service that owns them publishes them itself.
-- Saves: when the player leaves, every Config.Data.AutosaveInterval seconds, and when the server shuts down.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local SaveStore = require(script.Parent.Parent.Modules.SaveStore)

local PlayerDataService = {}

type Profile = {
	Data: { [string]: any },
	Saving: boolean, -- a save is in progress
	Released: boolean, -- final save started; no more changes
}

local profiles: { [Player]: Profile } = {}
local loadedCallbacks: { (Player) -> () } = {}
local pendingReleases = 0

local function save(player: Player, profile: Profile, release: boolean)
	while profile.Saving do
		task.wait() -- let an autosave finish first so saves never overlap
	end
	profile.Saving = true
	SaveStore.Save(player.UserId, profile.Data, release)
	profile.Saving = false
end

-- Final save when a player leaves (or the server closes). Safe to call more than once.
local function saveAndRelease(player: Player)
	local profile = profiles[player]
	if not profile or profile.Released then
		return
	end
	profile.Released = true
	pendingReleases += 1
	save(player, profile, true)
	pendingReleases -= 1
	profiles[player] = nil
end

local function onPlayerAdded(player: Player)
	if profiles[player] then
		return
	end

	local data = SaveStore.Load(player.UserId)
	if not data then
		if SaveStore.Enabled or not RunService:IsStudio() then
			-- Never start from zero when we could not read the save: that would overwrite real progress.
			player:Kick("We couldn't load your save right now. Please rejoin - your progress is safe.")
			return
		end
		warn("[PlayerDataService] Saving is OFF in Studio. Publish the place and turn on Studio API access.")
		data = SaveStore.DefaultData()
	end

	if player.Parent == nil then
		-- Left while loading: just hand the lock back
		SaveStore.Save(player.UserId, data, true)
		return
	end

	profiles[player] = { Data = data, Saving = false, Released = false }
	for key, value in data do
		if type(value) ~= "table" then
			player:SetAttribute(key, value)
		end
	end
	player:SetAttribute("DataLoaded", true)
	for _, callback in loadedCallbacks do
		task.spawn(callback, player)
	end
end

-- Runs callback for every player whose data is ready, now and in the future.
function PlayerDataService.OnLoaded(callback: (Player) -> ())
	table.insert(loadedCallbacks, callback)
	for player in profiles do
		task.spawn(callback, player)
	end
end

function PlayerDataService.IsLoaded(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and not profile.Released
end

-- Returns the live value. Table values are the real table: change them, then publish to the client yourself.
function PlayerDataService.Get(player: Player, key: string): any
	local profile = profiles[player]
	return profile and profile.Data[key]
end

-- Adds (or with a negative amount, removes) a currency. Returns false if the player's data isn't ready.
function PlayerDataService.Add(player: Player, key: string, amount: number): boolean
	local profile = profiles[player]
	if not profile or profile.Released or profile.Data[key] == nil then
		return false
	end
	profile.Data[key] += amount
	player:SetAttribute(key, profile.Data[key])
	return true
end

function PlayerDataService.Set(player: Player, key: string, value: number | string): boolean
	local profile = profiles[player]
	if not profile or profile.Released or profile.Data[key] == nil then
		return false
	end
	profile.Data[key] = value
	player:SetAttribute(key, value)
	return true
end

function PlayerDataService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(saveAndRelease)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Autosave
	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveInterval)
			for player, profile in profiles do
				if not profile.Released then
					task.spawn(save, player, profile, false)
				end
			end
		end
	end)

	-- Server shutting down: save everyone and wait (Roblox allows up to 30 seconds)
	game:BindToClose(function()
		for player in profiles do
			task.spawn(saveAndRelease, player)
		end
		local waited = 0
		while pendingReleases > 0 and waited < 25 do
			waited += task.wait()
		end
	end)
end

return PlayerDataService
