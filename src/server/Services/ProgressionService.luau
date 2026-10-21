-- Tracks strike streaks, Pro Tier ranks and rank levels 1-60. Hands out rank-up and level-up rewards and shows
-- each player's level and rank above their head.
-- Rank (the tier) is saved on its own. Levels inside a tier come from XP; enough XP for the next tier only unlocks
-- its Rank Trial (TrialService). Tiers without a trial in Config.Trials are given straight away.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local Progression = require(Shared.Modules.Progression)
local Analytics = require(script.Parent.Analytics)
local BallService = require(script.Parent.BallService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local SessionLog = require(script.Parent.Parent.Modules.SessionLog)

local ProgressionService = {}

local streaks: { [Player]: number } = {}
local lastSaved: { [Player]: number } = {} -- when Streak Saver last kept this player's streak (os.clock)
local rankUpEvent: RemoteEvent
local levelUpEvent: RemoteEvent
local LEVELS = Config.Economy.Ranks

-- Floating title above the player's head, e.g. "PRO"
local function updateBadge(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local rank = Progression.GetRank(player:GetAttribute("Rank") or 1)
	local level = player:GetAttribute("RankLevel") or 1

	local badge = head:FindFirstChild("RankBadge") :: BillboardGui?
	if not badge then
		local gui = Instance.new("BillboardGui")
		gui.Name = "RankBadge"
		gui.Size = UDim2.fromOffset(160, 30)
		gui.StudsOffset = Vector3.new(0, 2.6, 0)
		gui.MaxDistance = 80
		gui.AlwaysOnTop = false

		local label = Instance.new("TextLabel")
		label.Name = "Title"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
		label.TextScaled = true
		label.Parent = gui

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(20, 10, 40)
		stroke.Thickness = 2
		stroke.Parent = label

		gui.Parent = head
		badge = gui
	end
	local label = (badge :: BillboardGui).Title :: TextLabel
	label.Text = ("LV %d  %s"):format(level, rank.Name:upper())
	label.TextColor3 = rank.Color
end

-- Call once the throw is decided. Returns the new streak (so its multiplier can apply to this throw),
-- and true if the Streak Saver trait kept a streak that a miss would have broken.
-- saverCooldown: the ball's Streak Saver strength (seconds between saves), or 0.
-- The cooldown follows the player, not the ball, so swapping balls can't skip it.
function ProgressionService.NextStreak(player: Player, isStrike: boolean, saverCooldown: number?): (number, boolean)
	local current = streaks[player] or 0
	if isStrike then
		streaks[player] = current + 1
		return current + 1, false
	end
	local saver = Balls.GetTrait("StreakSaver")
	local cooldown = saverCooldown or 0
	if
		cooldown > 0
		and current >= (saver and saver.MinStreak or 1)
		and os.clock() - (lastSaved[player] or -math.huge) >= cooldown
	then
		lastSaved[player] = os.clock()
		return current, true
	end
	streaks[player] = 0
	return 0, false
end

-- Call when the ball hits the pins, so the streak display changes at the right moment.
function ProgressionService.ShowStreak(player: Player, streak: number)
	player:SetAttribute("Streak", streak)
	if streak > (PlayerDataService.Get(player, "BestStreak") or 0) then
		PlayerDataService.Set(player, "BestStreak", streak)
		Analytics.Event(player, "StreakRecord", streak)
	end
end

function ProgressionService.GetCurrentRankIndex(player: Player): number
	return math.clamp(PlayerDataService.Get(player, "Rank") or 1, 1, #Config.Ranks)
end

-- The rank this player is working toward, or nil at the top rank
function ProgressionService.GetNextRank(player: Player)
	return Config.Ranks[ProgressionService.GetCurrentRankIndex(player) + 1]
end

-- True when the XP bar is full and the next rank only needs its trial
function ProgressionService.IsRankUpReady(player: Player): boolean
	local nextRank = ProgressionService.GetNextRank(player)
	return nextRank ~= nil
		and (PlayerDataService.Get(player, "XP") or 0)
			>= Progression.TierXP(ProgressionService.GetCurrentRankIndex(player) + 1)
end

-- Gives every rank level the player's XP has reached (inside their tier) and its reward:
-- LevelGems for a level inside a tier (a tier's first level gets the tier's Gems in PromoteRank instead),
-- and a free crate every FreeCrateEvery levels (nil = none).
local function refreshLevel(player: Player)
	local done = PlayerDataService.Get(player, "RankLevel") or 1
	local level =
		Progression.LevelFromXP(PlayerDataService.Get(player, "XP") or 0, ProgressionService.GetCurrentRankIndex(player))
	if level <= done or not PlayerDataService.Set(player, "RankLevel", level) then
		return
	end
	local gems, crates, inTier = 0, 0, false
	for reached = done + 1, level do
		if (reached - 1) % LEVELS.LevelsPerTier ~= 0 then
			inTier = true
			gems += if Config.Gems.Enabled then LEVELS.LevelGems else 0
		end
		if LEVELS.FreeCrateEvery and reached % LEVELS.FreeCrateEvery == 0 then
			crates += 1
		end
		Analytics.Event(player, "LevelUp", reached)
		SessionLog.Moment(player, ("Level %d"):format(reached))
	end
	if gems > 0 then
		PlayerDataService.Add(player, "Gems", gems)
		Analytics.Currency(player, "Gems", gems, "Gameplay", "LevelUp")
	end
	updateBadge(player)
	if inTier then
		levelUpEvent:FireClient(player, { Level = level, Gems = gems, Crates = crates })
	end
	-- Crates last, so the level popup shows before the FREE CRATE popup
	for _ = 1, crates do
		BallService.GiveFreeCrate(player)
	end
end

-- Gives the next rank, its gem reward and the celebration. Called by TrialService when a trial is passed.
function ProgressionService.PromoteRank(player: Player)
	local index = ProgressionService.GetCurrentRankIndex(player) + 1
	if index > #Config.Ranks or not PlayerDataService.Set(player, "Rank", index) then
		return
	end
	local rank = Progression.GetRank(index)
	local gems = if Config.Gems.Enabled then rank.Gems else 0
	if gems > 0 then
		PlayerDataService.Add(player, "Gems", gems)
		Analytics.Currency(player, "Gems", gems, "Gameplay", "RankUp")
	end
	Analytics.Event(player, "RankUp", index, { rank.Name })
	Analytics.Step(player, "Ranked Up")
	SessionLog.Moment(player, ("Rank-up: %s"):format(rank.Name))
	refreshLevel(player)
	updateBadge(player)
	rankUpEvent:FireAllClients({
		UserId = player.UserId,
		DisplayName = player.DisplayName,
		Rank = index,
		Level = PlayerDataService.Get(player, "RankLevel"),
		Gems = gems,
	})
	ProgressionService.RefreshRankUpReady(player)
end

-- Publishes RankUpReady for the HUD, and gives ranks that have no trial right away
function ProgressionService.RefreshRankUpReady(player: Player)
	local ready = ProgressionService.IsRankUpReady(player)
	local nextRank = ProgressionService.GetNextRank(player)
	if ready and nextRank and not Config.Trials.Ranks[nextRank.Name] then
		ProgressionService.PromoteRank(player)
		return
	end
	player:SetAttribute("RankUpReady", ready)
end

function ProgressionService.AddXP(player: Player, amount: number)
	if PlayerDataService.Add(player, "XP", amount) then
		refreshLevel(player)
		ProgressionService.RefreshRankUpReady(player)
	end
end

function ProgressionService:Start()
	rankUpEvent = Instance.new("RemoteEvent")
	rankUpEvent.Name = "RankUp"
	rankUpEvent.Parent = ReplicatedStorage:WaitForChild("Remotes")
	levelUpEvent = Instance.new("RemoteEvent")
	levelUpEvent.Name = "LevelUp"
	levelUpEvent.Parent = ReplicatedStorage:WaitForChild("Remotes")

	-- Studio only (never in the live game): XP to reach the next rank level, so levels can be tested quickly
	if RunService:IsStudio() then
		local test = Instance.new("RemoteEvent")
		test.Name = "TestXP"
		test.Parent = ReplicatedStorage.Remotes
		test.OnServerEvent:Connect(function(player)
			if PlayerDataService.IsLoaded(player) then
				local level = PlayerDataService.Get(player, "RankLevel") or 1
				local xp = PlayerDataService.Get(player, "XP") or 0
				ProgressionService.AddXP(player, math.max(Progression.LevelXP(level + 1) - xp, 1))
			end
		end)
	end

	PlayerDataService.OnLoaded(function(player)
		player:SetAttribute("Streak", 0)
		refreshLevel(player)
		ProgressionService.RefreshRankUpReady(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 5)
			updateBadge(player)
		end)
		updateBadge(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		streaks[player] = nil
		lastSaved[player] = nil
	end)
end

return ProgressionService
