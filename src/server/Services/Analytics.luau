-- Playtest analytics: thin wrappers around Roblox's AnalyticsService so other services log with one line.
-- Results show in the Creator Dashboard (Analytics → Funnels, Economy, Custom events). Session length
-- and retention are tracked by Roblox automatically. Every call is wrapped so analytics can never break gameplay.
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local PlayerDataService = require(script.Parent.PlayerDataService)

local SETTINGS = Config.Analytics
local FIELD_KEYS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
}

local Analytics = {}

local loggedSteps: { [Player]: { [string]: boolean } } = {}
local sessionStart: { [Player]: number } = {}
local lastAction: { [Player]: string } = {} -- for "where do players stop": logged with SessionEnd
local playTimeCounted: { [Player]: number } = {} -- os.clock() up to which PlayTime has been saved
local knownEvents = {}
for _, name in SETTINGS.Events do
	knownEvents[name] = true
end
local warned = {}

local function try(fn, ...)
	if not SETTINGS.Enabled then
		return
	end
	local ok, err = pcall(fn, AnalyticsService, ...)
	if not ok then
		warn("[Analytics] " .. tostring(err))
	end
end

-- Up to 3 text labels (e.g. tier, crate id) for breaking an event down in the dashboard
local function toFields(labels: { string }?)
	if not labels then
		return nil
	end
	local fields = {}
	for i, label in labels do
		if FIELD_KEYS[i] then
			fields[FIELD_KEYS[i]] = tostring(label)
		end
	end
	return fields
end

-- Marks a first-session funnel step (a name from Config.Analytics.OnboardingSteps)
function Analytics.Step(player: Player, stepName: string)
	local index = table.find(SETTINGS.OnboardingSteps, stepName)
	local logged = loggedSteps[player]
	if not index or not logged or logged[stepName] then
		return
	end
	logged[stepName] = true
	try(AnalyticsService.LogOnboardingFunnelStepEvent, player, index, stepName)
end

-- Something worth counting, like a throw or a crate opened. eventName must be on Config.Analytics.Events.
function Analytics.Event(player: Player, eventName: string, value: number?, labels: { string }?)
	if not knownEvents[eventName] and not warned[eventName] and RunService:IsStudio() then
		warned[eventName] = true
		warn("[Analytics] '" .. eventName .. "' is not in Config.Analytics.Events")
	end
	if eventName ~= "SessionEnd" then
		lastAction[player] = eventName
	end
	try(AnalyticsService.LogCustomEvent, player, eventName, value or 1, toFields(labels))
end

-- Adds the play time since it was last counted to the saved PlayTime
local function countPlayTime(player: Player)
	local since = playTimeCounted[player]
	if not since then
		return
	end
	local now = os.clock()
	playTimeCounted[player] = now
	PlayerDataService.Add(player, "PlayTime", now - since)
end

-- Total minutes this player has played, all sessions together
function Analytics.MinutesPlayed(player: Player): number
	local unsaved = if playTimeCounted[player] then os.clock() - playTimeCounted[player] else 0
	return math.floor(((PlayerDataService.Get(player, "PlayTime") or 0) + unsaved) / 6) / 10
end

-- Anything bought: kind = "Crate", "Ball", "Egg"...; logged with the player's total minutes played
function Analytics.Purchase(player: Player, kind: string, item: string)
	Analytics.Event(player, "Purchase", Analytics.MinutesPlayed(player), { kind, item })
end

-- Coins or Gems coming in (amount > 0) or going out (amount < 0). Call after the balance has changed.
-- kind is an Enum.AnalyticsEconomyTransactionType name: "Gameplay", "Shop", "TimedReward"...
function Analytics.Currency(player: Player, currency: string, amount: number, kind: string, item: string)
	if amount == 0 then
		return
	end
	local flow = if amount > 0 then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink
	local balance = PlayerDataService.Get(player, currency) or 0
	try(AnalyticsService.LogEconomyEvent, player, flow, currency, math.abs(amount), balance, kind, item)
end

function Analytics:Start()
	PlayerDataService.OnLoaded(function(player)
		loggedSteps[player] = loggedSteps[player] or {}
		sessionStart[player] = os.clock()
		playTimeCounted[player] = os.clock()
		Analytics.Step(player, "Joined")
		Analytics.Event(player, "SessionStart")
	end)
	Players.PlayerRemoving:Connect(function(player)
		countPlayTime(player) -- may miss the final save; at most PlayTimeInterval seconds are lost
		if sessionStart[player] then
			local minutes = math.floor((os.clock() - sessionStart[player]) / 6) / 10
			Analytics.Event(player, "SessionEnd", minutes, {
				lastAction[player] or "None",
				tostring(Analytics.MinutesPlayed(player)),
			})
		end
		loggedSteps[player] = nil
		sessionStart[player] = nil
		lastAction[player] = nil
		playTimeCounted[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(SETTINGS.PlayTimeInterval)
			for player in playTimeCounted do
				countPlayTime(player)
			end
		end
	end)
end

return Analytics
