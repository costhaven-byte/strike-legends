-- Holds each player's coins, gems and XP on the server.
-- Values are mirrored to Player attributes so the HUD can read them; only the server changes them.
-- (Saving to a DataStore comes in Milestone 5; for now progress resets when you leave.)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local PlayerDataService = {}

local profiles: { [Player]: { [string]: number } } = {}

local function onPlayerAdded(player: Player)
	if profiles[player] then
		return
	end
	local data = table.clone(Config.StartingData)
	profiles[player] = data
	for key, value in data do
		player:SetAttribute(key, value)
	end
end

function PlayerDataService.Get(player: Player, key: string): number?
	local data = profiles[player]
	return data and data[key]
end

-- Adds (or with a negative amount, removes) a currency. Returns false if the player has no data yet.
function PlayerDataService.Add(player: Player, key: string, amount: number): boolean
	local data = profiles[player]
	if not data or data[key] == nil then
		return false
	end
	data[key] += amount
	player:SetAttribute(key, data[key])
	return true
end

function PlayerDataService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		profiles[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return PlayerDataService
