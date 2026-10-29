-- Studio only: how the next Studio play test starts, picked on the TEST panel (TestPanelService).
-- "Zero" = a brand new player (nothing saved), "Mine" = your save with everything unlocked (nothing saved).
-- Kept in its own DataStore so it survives pressing Stop and Play; it never touches anyone's real save.
-- No choice yet (or saving off in Studio) = Config.Onboarding.StudioNewPlayer decides, as before.
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local StudioTestMode = {}

local store = nil
if RunService:IsStudio() then
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("StudioTestPanel")
	end)
	store = if ok then result else nil
end

local function key(userId: number): string
	return "Mode_" .. userId
end

-- "Zero", "Mine" or nil (no choice made). Always nil outside Studio.
function StudioTestMode.Get(userId: number): string?
	if not store then
		return nil
	end
	local ok, mode = pcall(function()
		return store:GetAsync(key(userId))
	end)
	return if ok and (mode == "Zero" or mode == "Mine") then mode else nil
end

-- Saves the choice for the next play test. True when it was saved.
function StudioTestMode.Set(userId: number, mode: string): boolean
	if not store or (mode ~= "Zero" and mode ~= "Mine") then
		return false
	end
	local ok = pcall(function()
		store:SetAsync(key(userId), mode)
	end)
	return ok
end

return StudioTestMode
