-- Playtest analytics: thin wrappers around Roblox's AnalyticsService so other services log with one line.
-- Results show in the Creator Dashboard (Analytics → Funnels, Economy, Custom events). Session length
-- and retention are tracked by Roblox automatically. Every call is wrapped so analytics can never break gameplay.
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

-- Something worth counting, like a throw or a crate opened
function Analytics.Event(player: Player, eventName: string, value: number?, labels: { string }?)
	try(AnalyticsService.LogCustomEvent, player, eventName, value or 1, toFields(labels))
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
		Analytics.Step(player, "Joined")
	end)
	Players.PlayerRemoving:Connect(function(player)
		loggedSteps[player] = nil
	end)
end

return Analytics
