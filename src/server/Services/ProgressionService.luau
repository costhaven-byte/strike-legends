-- Tracks strike streaks and Pro Tier ranks. Hands out rank-up rewards and shows each player's rank above their head.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Progression = require(Shared.Modules.Progression)
local PlayerDataService = require(script.Parent.PlayerDataService)

local ProgressionService = {}

local streaks: { [Player]: number } = {}
local rankUpEvent: RemoteEvent

-- Floating title above the player's head, e.g. "PRO"
local function updateBadge(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local rank = Progression.GetRank(player:GetAttribute("Rank") or 1)

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
	label.Text = rank.Name:upper()
	label.TextColor3 = rank.Color
end

-- Call once the throw is decided. Returns the new streak (so its multiplier can apply to this throw).
function ProgressionService.NextStreak(player: Player, isStrike: boolean): number
	local streak = if isStrike then (streaks[player] or 0) + 1 else 0
	streaks[player] = streak
	return streak
end

-- Call when the ball hits the pins, so the streak display changes at the right moment.
function ProgressionService.ShowStreak(player: Player, streak: number)
	player:SetAttribute("Streak", streak)
	if streak > (PlayerDataService.Get(player, "BestStreak") or 0) then
		PlayerDataService.Set(player, "BestStreak", streak)
	end
end

function ProgressionService.GetCurrentRankIndex(player: Player): number
	return Progression.GetRankIndex(PlayerDataService.Get(player, "XP") or 0)
end

-- Adds XP and handles any rank-ups it causes (can skip several ranks at once).
function ProgressionService.AddXP(player: Player, amount: number)
	local before = ProgressionService.GetCurrentRankIndex(player)
	if not PlayerDataService.Add(player, "XP", amount) then
		return
	end
	local after = ProgressionService.GetCurrentRankIndex(player)
	if after <= before then
		return
	end

	local gems = 0
	for index = before + 1, after do
		gems += Progression.GetRank(index).Gems
	end
	if gems > 0 then
		PlayerDataService.Add(player, "Gems", gems)
	end
	player:SetAttribute("Rank", after)
	updateBadge(player)
	rankUpEvent:FireAllClients({
		UserId = player.UserId,
		DisplayName = player.DisplayName,
		Rank = after,
		Gems = gems,
	})
end

function ProgressionService:Start()
	rankUpEvent = Instance.new("RemoteEvent")
	rankUpEvent.Name = "RankUp"
	rankUpEvent.Parent = ReplicatedStorage:WaitForChild("Remotes")

	PlayerDataService.OnLoaded(function(player)
		player:SetAttribute("Rank", ProgressionService.GetCurrentRankIndex(player))
		player:SetAttribute("Streak", 0)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 5)
			updateBadge(player)
		end)
		updateBadge(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		streaks[player] = nil
	end)
end

return ProgressionService
