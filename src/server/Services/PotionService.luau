-- Potions (owner 2026-10-22, Config.Potions): timed x2 / x4 boosts for coins or XP.
-- Saved: Potions = how many of each are waiting, Boosts = seconds left on each one drunk (only ticks while playing).
-- Clients see two Player attributes: Potions ("CoinSmall=2;XpBig=1") and Boosts ("CoinSmall=840;...", every
-- potion with time left; the one that counts for its kind is the strongest, see Config.Potions).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Analytics = require(script.Parent.Analytics)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RateLimit = require(script.Parent.Parent.Modules.RateLimit)
local SessionLog = require(script.Parent.Parent.Modules.SessionLog)

local POTIONS = Config.Potions

local byId = {}
for _, potion in POTIONS.List do
	byId[potion.Id] = potion
end

local PotionService = {}

local function getTable(player: Player, key: string): { [string]: number }
	local value = PlayerDataService.Get(player, key)
	return if type(value) == "table" then value else {}
end

local function encode(values: { [string]: number }): string
	local parts = {}
	for _, potion in POTIONS.List do -- always in the same order, so the text only changes when a number does
		local value = math.ceil(tonumber(values[potion.Id]) or 0)
		if value > 0 then
			table.insert(parts, ("%s=%d"):format(potion.Id, value))
		end
	end
	return table.concat(parts, ";")
end

local function publish(player: Player)
	player:SetAttribute("Potions", encode(getTable(player, "Potions")))
	player:SetAttribute("Boosts", encode(getTable(player, "Boosts")))
end

-- The strongest potion of this kind ("Coins" or "XP") with time left, or nil
local function strongest(player: Player, kind: string)
	local boosts = getTable(player, "Boosts")
	local best = nil
	for _, potion in POTIONS.List do
		if
			potion.Boost == kind
			and (boosts[potion.Id] or 0) > 0
			and (not best or potion.Multiplier > best.Multiplier)
		then
			best = potion
		end
	end
	return best
end

-- The boost multiplier of this kind ("Coins" or "XP") right now: 1 with no potion running
function PotionService.Multiplier(player: Player, kind: string): number
	local potion = strongest(player, kind)
	return if potion then potion.Multiplier else 1
end

-- Adds potions to the player's stash (playtime rewards and the Studio test button)
function PotionService.Give(player: Player, potionId: string, count: number?): boolean
	if not byId[potionId] or not PlayerDataService.IsLoaded(player) then
		return false
	end
	local potions = PlayerDataService.Get(player, "Potions")
	if type(potions) ~= "table" then
		return false
	end
	potions[potionId] = (potions[potionId] or 0) + (count or 1)
	publish(player)
	return true
end

-- Runs a potion's boost this many seconds longer straight away, past MaxMinutes (Robux boosts, Config.Monetization)
function PotionService.AddBoost(player: Player, potionId: string, seconds: number): boolean
	local boosts = PlayerDataService.Get(player, "Boosts")
	if not byId[potionId] or type(boosts) ~= "table" then
		return false
	end
	boosts[potionId] = (boosts[potionId] or 0) + seconds
	publish(player)
	return true
end

local function use(player: Player, potionId: any)
	if not RateLimit.Allow(player, "UsePotion") then
		return { Ok = false, Error = "Slow down!" }
	end
	local potion = type(potionId) == "string" and byId[potionId]
	if not potion or not PlayerDataService.IsLoaded(player) then
		return { Ok = false, Error = "Something went wrong" }
	end
	local potions = PlayerDataService.Get(player, "Potions")
	local boosts = PlayerDataService.Get(player, "Boosts")
	if type(potions) ~= "table" or type(boosts) ~= "table" or (potions[potion.Id] or 0) < 1 then
		return { Ok = false, Error = "You don't have that potion" }
	end
	local left = boosts[potion.Id] or 0
	if left + potion.Minutes * 60 > POTIONS.MaxMinutes * 60 then
		return { Ok = false, Error = "That potion is already full!" }
	end
	potions[potion.Id] -= 1
	if potions[potion.Id] <= 0 then
		potions[potion.Id] = nil
	end
	boosts[potion.Id] = left + potion.Minutes * 60
	publish(player)
	Analytics.Event(player, "PotionUsed", math.floor(boosts[potion.Id] / 60), { potion.Id })
	SessionLog.Moment(player, ("%s drunk"):format(potion.Name))
	return { Ok = true }
end

-- Counts down the strongest running potion of each kind (the weaker ones wait their turn)
local function tick(player: Player, seconds: number)
	local boosts = PlayerDataService.Get(player, "Boosts")
	if type(boosts) ~= "table" then
		return
	end
	local kinds = {}
	for _, potion in POTIONS.List do
		kinds[potion.Boost] = true
	end
	local changed = false
	for kind in kinds do
		local potion = strongest(player, kind)
		if potion then
			boosts[potion.Id] -= seconds
			if boosts[potion.Id] <= 0 then
				boosts[potion.Id] = nil
			end
			changed = true
		end
	end
	if changed then
		publish(player)
	end
end

function PotionService:Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local remote = Instance.new("RemoteFunction")
	remote.Name = "UsePotion"
	remote.Parent = remotes
	remote.OnServerInvoke = function(player, potionId)
		local ok, result = pcall(use, player, potionId)
		if not ok then
			warn("[PotionService] " .. tostring(result))
			return { Ok = false, Error = "Something went wrong" }
		end
		return result
	end

	-- Studio only (never in the live game): one of every potion
	if RunService:IsStudio() then
		local test = Instance.new("RemoteEvent")
		test.Name = "TestPotions"
		test.Parent = remotes
		test.OnServerEvent:Connect(function(player)
			for _, potion in POTIONS.List do
				PotionService.Give(player, potion.Id, 1)
			end
		end)
	end

	PlayerDataService.OnLoaded(publish)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(POTIONS.Tick)
			local now = os.clock()
			local seconds = now - last
			last = now
			for _, player in Players:GetPlayers() do
				if PlayerDataService.IsLoaded(player) then
					local ok, err = pcall(tick, player, seconds)
					if not ok then
						warn("[PotionService] " .. tostring(err))
					end
				end
			end
		end
	end)
end

return PotionService
