-- Lights up each player's alley as their strike streak grows (everyone sees it), with a new layer
-- for every tier: colour, then sparkles, then glow, then pulsing. Plays the streak sounds for your own streak.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LaneUtil = require(Shared.Modules.LaneUtil)
local Progression = require(Shared.Modules.Progression)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local LaneFx = require(Modules.LaneFx)
local Sfx = require(Modules.Sfx)

local localPlayer = Players.LocalPlayer

local StreakFx = {}

local shownTier: { [Model]: number } = {}

local function setLaneTier(lane: Model, tier: number)
	if shownTier[lane] ~= tier then
		shownTier[lane] = tier
		LaneFx.SetStreakTier(lane, tier)
	end
end

local function watch(player: Player)
	local previous = player:GetAttribute("Streak") or 0

	player:GetAttributeChangedSignal("Streak"):Connect(function()
		local streak = player:GetAttribute("Streak") or 0
		local tier = Progression.GetStreakTierIndex(streak)
		local reachedTier = tier > Progression.GetStreakTierIndex(previous)
		local broken = streak == 0 and previous >= 2
		previous = streak

		local lane = LaneUtil.GetOwnedLane(player.UserId)
		if lane then
			setLaneTier(lane, tier)
			if reachedTier and tier >= 3 then
				LaneFx.Fireworks(lane, tier - 2) -- Turkey and up: more fireworks every tier
			end
		end

		if player ~= localPlayer then
			return
		end
		if reachedTier and tier >= 2 then
			Sfx.Play("StreakUp", 0.85 + tier * 0.07, 0.8 + tier * 0.1) -- higher and louder every tier
		elseif broken then
			Sfx.Play("StreakLost")
		end
	end)
end

function StreakFx:Start()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)

	-- A lane goes back to normal when its owner leaves or it changes hands
	for _, lane in LaneUtil.GetLanes() do
		lane:GetAttributeChangedSignal("OwnerId"):Connect(function()
			setLaneTier(lane, 0)
		end)
	end
end

return StreakFx
