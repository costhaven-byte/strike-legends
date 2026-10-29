-- Holds each player's coins, gems, XP, balls and more on the server, and saves them with SaveStore.
-- Number and text values are mirrored to Player attributes so the HUD can read them; only the server changes them.
-- Table values (like OwnedBalls) are not mirrored; the service that owns them publishes them itself.
-- Saves: when the player leaves, every Config.Data.AutosaveInterval seconds, and when the server shuts down.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Progression = require(Shared.Modules.Progression)
local Currency = require(Shared.Modules.Currency)
local SaveStore = require(script.Parent.Parent.Modules.SaveStore)
local StudioTestMode = require(script.Parent.Parent.Modules.StudioTestMode)

local PlayerDataService = {}

-- Money keys (Config.Numbers.Currencies): their math goes through Shared.Modules.Currency
local CURRENCY = {}
for _, key in Config.Numbers.Currencies do
	CURRENCY[key] = true
end

type Profile = {
	Data: { [string]: any },
	Saving: boolean, -- a save is in progress
	Released: boolean, -- final save started; no more changes
	NoSave: boolean?, -- Studio new-player test: never loaded or saved
	Untouched: { [string]: any }?, -- Studio unlock-all test: the save as loaded, written back unchanged on leaving
}

local profiles: { [Player]: Profile } = {}
local loadedCallbacks: { (Player) -> () } = {}
local releaseCallbacks: { (Player) -> () } = {}
local pendingReleases = 0

local function save(player: Player, profile: Profile, release: boolean): boolean
	if profile.NoSave then
		return true
	end
	if profile.Untouched then
		-- Studio unlock-all test: only hand the lock back, with the save exactly as it was loaded
		if release then
			SaveStore.Save(player.UserId, profile.Untouched, true)
		end
		return true
	end
	while profile.Saving do
		task.wait() -- let an autosave finish first so saves never overlap
	end
	profile.Saving = true
	local ok = SaveStore.Save(player.UserId, profile.Data, release)
	profile.Saving = false
	return ok
end

-- Final save when a player leaves (or the server closes). Safe to call more than once.
local function saveAndRelease(player: Player)
	local profile = profiles[player]
	if not profile or profile.Released then
		return
	end
	for _, callback in releaseCallbacks do
		pcall(callback, player) -- last changes before the final save; never blocks saving
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

	-- Studio test mode (Config.Onboarding.StudioNewPlayer): a brand new player every time, nothing saved.
	-- The TEST panel's START FROM ZERO / MY SAVE choice (StudioTestMode) wins over the Config switch.
	local studioMode = if RunService:IsStudio() then StudioTestMode.Get(player.UserId) else nil
	local noSave = RunService:IsStudio()
		and (studioMode == "Zero" or (studioMode == nil and Config.Onboarding.StudioNewPlayer == true))
	player:SetAttribute("StudioStart", if RunService:IsStudio() then (if noSave then "Zero" else "Mine") else nil)
	local data = if noSave then SaveStore.DefaultData() else SaveStore.Load(player.UserId)
	if noSave then
		warn(
			"[PlayerDataService] Studio new-player test: fresh start, nothing is saved (Config.Onboarding.StudioNewPlayer)"
		)
	end
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
		if not noSave then
			SaveStore.Save(player.UserId, data, true)
		end
		return
	end

	-- Studio test with your real save, every built zone open and everything owned (Config.Onboarding.StudioUnlockAll)
	local untouched = nil
	if not noSave and RunService:IsStudio() and Config.Onboarding.StudioUnlockAll == true and SaveStore.Enabled then
		untouched = SaveStore.DeepCopy(data)
		local built = Config.Zones.BuiltZones
		local level = Config.Economy.Zones[built].Rank -- a mid-game level, so level-locked things open too
		local tier = math.ceil(level / Config.Economy.Ranks.LevelsPerTier)
		data.Rank = math.max(data.Rank or 1, tier)
		data.RankLevel = math.max(data.RankLevel or 1, level)
		data.XP = math.max(data.XP or 0, Progression.LevelXP(data.RankLevel))
		data.ZonesOpen = math.max(data.ZonesOpen or 1, built)
		data.ZoneVisited = math.max(data.ZoneVisited or 1, built)
		data.ZoneSeen = math.max(data.ZoneSeen or 1, built)
		data.Onboarding = math.max(data.Onboarding or 0, 3)
		data.CratesBought = math.max(data.CratesBought or 0, 1)
		data.Coins = math.max(data.Coins or 0, Config.Onboarding.StudioUnlockCoins or 0)
		data.Gems = math.max(data.Gems or 0, Config.Onboarding.StudioUnlockGems or 0)
		for _, ball in Config.Balls do
			data.OwnedBalls[ball.Id] = true
		end
		for _, mascot in Config.Mascots do
			data.Mascots[mascot.Id] = math.max(data.Mascots[mascot.Id] or 0, 1)
		end
		for _, item in Config.Cosmetics.Items do
			data.Cosmetics[item.Id] = true
		end
		warn(("[PlayerDataService] Studio unlock-all test: your save, at level %d (zones 1-%d open). Nothing from this test is saved (Config.Onboarding.StudioUnlockAll)"):format(data.RankLevel, built))
	end

	profiles[player] = { Data = data, Saving = false, Released = false, NoSave = noSave, Untouched = untouched }
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

-- Saves this player's data right now (Robux purchases). True when it was written (or this test never saves).
function PlayerDataService.SaveNow(player: Player): boolean
	local profile = profiles[player]
	if not profile or profile.Released then
		return false
	end
	return save(player, profile, false)
end

-- Runs callback for every player whose data is ready, now and in the future.
function PlayerDataService.OnLoaded(callback: (Player) -> ())
	table.insert(loadedCallbacks, callback)
	for player in profiles do
		task.spawn(callback, player)
	end
end

-- Runs callback for a player just before their final save (leaving, or the server closing).
-- It must not wait: the save starts right after.
function PlayerDataService.OnRelease(callback: (Player) -> ())
	table.insert(releaseCallbacks, callback)
end

-- True for a Studio test session whose progress is never saved (new-player or unlock-all test)
function PlayerDataService.IsTestSession(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and (profile.NoSave == true or profile.Untouched ~= nil)
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
	if CURRENCY[key] then
		profile.Data[key] = Currency.Add(profile.Data[key], amount, key)
	else
		profile.Data[key] += amount
	end
	player:SetAttribute(key, profile.Data[key])
	-- Coins earned ever (Profile panel stats + MONEY MAKER achievement, Polish P5): every coin that comes in counts
	if key == "Coins" and amount > 0 and profile.Data.LifetimeCoins ~= nil then
		profile.Data.LifetimeCoins = Currency.Add(profile.Data.LifetimeCoins, amount, "LifetimeCoins")
		player:SetAttribute("LifetimeCoins", profile.Data.LifetimeCoins)
	end
	return true
end

-- Can the player pay this price in this currency right now?
function PlayerDataService.CanAfford(player: Player, key: string, price: number): boolean
	local profile = profiles[player]
	return profile ~= nil and not profile.Released and Currency.CanAfford(profile.Data[key], price)
end

-- Takes the price if the player can pay it. Returns true if it was paid.
function PlayerDataService.Spend(player: Player, key: string, price: number): boolean
	if not PlayerDataService.CanAfford(player, key, price) then
		return false
	end
	return PlayerDataService.Add(player, key, -price)
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
