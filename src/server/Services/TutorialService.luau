-- Polish v2 tutorial (owner 2026-11-03): four short steps for a new player (Config.Tutorial). The server checks each
-- step against the saved stats (throws, sells, ball, bag), pays its reward once and saves how many are done in
-- Tutorial (attribute too, so the client's hand moves on). The client only shows; it never asks for a reward.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Analytics = require(script.Parent.Analytics)
local PlayerDataService = require(script.Parent.PlayerDataService)
local MascotService = require(script.Parent.MascotService)
local SessionLog = require(script.Parent.Parent.Modules.SessionLog)

local TUTORIAL = Config.Tutorial
local STEPS = TUTORIAL.Steps

local TutorialService = {}

local stepDone: RemoteEvent

local function statTotal(player: Player, step): number
	local total = 0
	for _, stat in step.Stats do
		total += tonumber(PlayerDataService.Get(player, stat)) or 0
	end
	return total
end

local function pay(player: Player, step)
	local reward = step.Reward
	if reward.Coins then
		PlayerDataService.Add(player, "Coins", reward.Coins)
		Analytics.Currency(player, "Coins", reward.Coins, "TimedReward", "Tutorial")
	end
	if reward.Gems then
		PlayerDataService.Add(player, "Gems", reward.Gems)
		Analytics.Currency(player, "Gems", reward.Gems, "TimedReward", "Tutorial")
	end
	if reward.Egg then
		MascotService.GiveFreeEgg(player, reward.Egg, 1)
	end
end

-- Pays every step whose stats are reached, in order (a step only counts once the one before it is done)
local function check(player: Player)
	if not TUTORIAL.Enabled or not PlayerDataService.IsLoaded(player) then
		return
	end
	local done = tonumber(PlayerDataService.Get(player, "Tutorial")) or #STEPS
	while done < #STEPS do
		local step = STEPS[done + 1]
		if statTotal(player, step) < step.AtLeast then
			return
		end
		done += 1
		PlayerDataService.Set(player, "Tutorial", done)
		pay(player, step)
		stepDone:FireClient(player, done, step.Reward)
		Analytics.Event(player, "TutorialStep", done, { step.Id })
		SessionLog.Moment(player, ("Tutorial step %d (%s) done"):format(done, step.Id))
	end
end

local function watch(player: Player)
	local stats = {}
	for _, step in STEPS do
		for _, stat in step.Stats do
			stats[stat] = true
		end
	end
	for stat in stats do
		player:GetAttributeChangedSignal(stat):Connect(function()
			check(player)
		end)
	end
	check(player)
end

function TutorialService:Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	stepDone = Instance.new("RemoteEvent")
	stepDone.Name = "TutorialStep"
	stepDone.Parent = remotes

	local function onPlayer(player: Player)
		if player:GetAttribute("DataLoaded") then
			watch(player)
		else
			player:GetAttributeChangedSignal("DataLoaded"):Once(function()
				watch(player)
			end)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
end

return TutorialService
