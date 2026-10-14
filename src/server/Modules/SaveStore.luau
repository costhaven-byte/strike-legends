-- Loads and saves one player's data in a DataStore, safely.
-- Each save holds a "session lock" naming the server using it, so two servers never overwrite each other.
-- Saved record: { Version = number, Data = { Coins = ..., ... }, Lock = { JobId = string, Time = number }? }
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local DATA = Config.Data

local SaveStore = {}

local okStore, store = pcall(function()
	return DataStoreService:GetDataStore(DATA.StoreName)
end)
-- False in Studio when the place is not published; then nothing is saved.
SaveStore.Enabled = okStore

local function keyFor(userId: number): string
	return "Player_" .. userId
end

-- Calls fn, retrying with a growing wait if Roblox's DataStore errors.
local function withRetries(label: string, fn: () -> ()): boolean
	for attempt = 1, DATA.MaxRetries do
		local ok, err = pcall(fn)
		if ok then
			return true
		end
		warn(("[SaveStore] %s failed (attempt %d/%d): %s"):format(label, attempt, DATA.MaxRetries, tostring(err)))
		local message = tostring(err):lower()
		if message:find("studioaccesstoapisnotallowed") or message:find("studio access to apis is not allowed") then
			-- Studio without API access: retrying will never work, so switch saving off for this session
			SaveStore.Enabled = false
			return false
		end
		if attempt < DATA.MaxRetries then
			task.wait(DATA.RetryDelay * attempt)
		end
	end
	return false
end

-- Turns a saved record (any version, or nil for a new player) into current-format data.
local function migrate(saved: any): { [string]: number }
	local data = table.clone(Config.StartingData)
	if type(saved) == "table" and type(saved.Data) == "table" then
		-- Upgrade steps go here when SchemaVersion changes, e.g. if saved.Version < 2 then ... end
		for key, value in saved.Data do
			data[key] = value
		end
	end
	return data
end

-- Returns the player's data and takes the session lock, or nil if the DataStore could not be reached.
function SaveStore.Load(userId: number): { [string]: number }?
	if not SaveStore.Enabled then
		return nil
	end
	for lockTry = 1, DATA.LockWaitTries + 1 do
		local result: any = nil
		local locked = false
		local ok = withRetries("Load " .. userId, function()
			store:UpdateAsync(keyFor(userId), function(saved)
				saved = if type(saved) == "table" then saved else {}
				local lock = saved.Lock
				local now = os.time()
				local heldElsewhere = lock and lock.JobId ~= game.JobId and now - lock.Time < DATA.LockTimeout
				if heldElsewhere and lockTry <= DATA.LockWaitTries then
					locked = true
					return nil -- leave the record untouched, try again shortly
				end
				locked = false
				result = saved
				saved.Version = saved.Version or DATA.SchemaVersion
				saved.Lock = { JobId = game.JobId, Time = now }
				return saved
			end)
		end)
		if not ok then
			return nil
		end
		if not locked then
			return migrate(result)
		end
		task.wait(DATA.LockWaitDelay)
	end
	return nil
end

-- Saves data. release = true also gives up the session lock (player left or server closing).
-- Returns false if saving failed or another server has taken over this player.
function SaveStore.Save(userId: number, data: { [string]: number }, release: boolean): boolean
	if not SaveStore.Enabled then
		return false
	end
	local snapshot = table.clone(data)
	local lostLock = false
	local ok = withRetries("Save " .. userId, function()
		store:UpdateAsync(keyFor(userId), function(saved)
			saved = if type(saved) == "table" then saved else {}
			if saved.Lock and saved.Lock.JobId ~= game.JobId then
				lostLock = true
				return nil -- another server owns this player now; never overwrite its data
			end
			lostLock = false
			saved.Version = DATA.SchemaVersion
			saved.Data = snapshot
			saved.Lock = if release then nil else { JobId = game.JobId, Time = os.time() }
			return saved
		end)
	end)
	if lostLock then
		warn(("[SaveStore] Skipped save for %d: another server has this player's data"):format(userId))
	end
	return ok and not lostLock
end

return SaveStore
