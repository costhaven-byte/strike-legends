-- Zone milestones on screen (Phase X Part 1, Config.Milestones): the challenge tracker (left side, under the
-- Power Level button) while you bowl in the challenge's zone, the "next level reward" preview under it, and the
-- popup when a level reward or a challenge pays out (then the crate opens). Built in code. The server decides
-- everything (MilestoneService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local Currency = require(Shared.Modules.Currency)
local LaneUtil = require(Shared.Modules.LaneUtil)
local CrateController = require(script.Parent.CrateController)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules:WaitForChild("Sfx"))
local UiFx = require(Modules:WaitForChild("UiFx"))

local player = Players.LocalPlayer

local MILESTONES = Config.Milestones

local FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local BODY_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local INK = Color3.fromHex("06060F")
local PANEL = Color3.fromRGB(18, 12, 38)
local PINK = Color3.fromRGB(255, 60, 210)
local CYAN = Color3.fromRGB(70, 230, 255)
local GOLD = Color3.fromRGB(255, 200, 40)
local GREY = Color3.fromRGB(150, 140, 180)

-- Computers: right side, under the streak box and the free-crate bar (the left column holds the Power Level button
-- and, in Studio, its TEST buttons). Phones: left column under the Power Level button (ScreenLayout's compact spots).
local TRACKER_NORMAL =
	{ Anchor = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 378), Size = UDim2.fromOffset(222, 74) }
local TRACKER_COMPACT =
	{ Anchor = Vector2.new(0, 0), Position = UDim2.fromOffset(12, 250), Size = UDim2.fromOffset(150, 60) }

local MilestoneController = {}

local function stroke(parent: Instance, color: Color3, thickness: number, border: boolean?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = if border then Enum.ApplyStrokeMode.Border else Enum.ApplyStrokeMode.Contextual
	s.Parent = parent
	return s
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function text(parent: Instance, name: string, font: Font, color: Color3, position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.FontFace = font
	label.TextScaled = true
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Position = position
	label.Size = size
	label.Parent = parent
	stroke(label, INK, 1.5)
	return label
end

local function potionName(id: string): string
	for _, potion in Config.Potions.List do
		if potion.Id == id then
			return potion.Name
		end
	end
	return "POTION"
end

-- "+50K COINS", "2 COIN POTIONS", "BRONZE CRATE"
local function rewardLines(reward, coins: number?): { string }
	local lines = {}
	local shownCoins = coins or reward.Coins
	if shownCoins and shownCoins > 0 then
		table.insert(lines, ("+%s COINS"):format(Currency.Format(shownCoins)))
	end
	for _, potion in reward.Potions or {} do
		local count = potion.Count or 1
		table.insert(lines, ("%d %s%s"):format(count, potionName(potion.Id), if count > 1 then "S" else ""))
	end
	local crate = reward.CrateId or reward.Crate
	if type(crate) == "string" then
		local row = Balls.GetCrate(crate)
		table.insert(lines, string.upper(if row then row.Name else crate))
	end
	return lines
end

-- The next level reward above this level, or nil
local function nextLevelReward(level: number)
	local best = nil
	for _, row in MILESTONES.LevelRewards do
		if row.Level > level and (best == nil or row.Level < best.Level) then
			best = row
		end
	end
	return best
end

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

function MilestoneController:Start()
	if not MILESTONES.Enabled then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "MilestoneUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 4
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Challenge tracker
	local tracker = Instance.new("Frame")
	tracker.Name = "Tracker"
	tracker.BackgroundColor3 = PANEL
	tracker.BackgroundTransparency = 0.15
	tracker.Visible = false
	tracker.Parent = gui
	corner(tracker, 10)
	stroke(tracker, PINK, 2, true)
	local title = text(tracker, "Title", FONT, PINK, UDim2.new(0, 8, 0, 4), UDim2.new(1, -16, 0.22, 0))
	local goal =
		text(tracker, "Goal", BODY_FONT, Color3.new(1, 1, 1), UDim2.new(0, 8, 0.26, 0), UDim2.new(1, -16, 0.2, 0))
	local dots = Instance.new("Frame")
	dots.Name = "Dots"
	dots.BackgroundTransparency = 1
	dots.Position = UDim2.new(0, 8, 0.5, 0)
	dots.Size = UDim2.new(1, -16, 0.2, 0)
	dots.Parent = tracker
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, 4)
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Parent = dots
	local prize = text(tracker, "Prize", BODY_FONT, GOLD, UDim2.new(0, 8, 0.74, 0), UDim2.new(1, -16, 0.2, 0))

	-- Next level reward preview, under the tracker (also shown on its own outside the challenge's zone)
	local preview = Instance.new("Frame")
	preview.Name = "Preview"
	preview.BackgroundColor3 = PANEL
	preview.BackgroundTransparency = 0.15
	preview.Visible = false
	preview.Parent = gui
	corner(preview, 8)
	stroke(preview, CYAN, 1.5, true)
	local previewText = text(preview, "Text", BODY_FONT, CYAN, UDim2.new(0, 8, 0, 3), UDim2.new(1, -16, 1, -6))

	-- Reward popup (centre of the screen)
	local popup = Instance.new("Frame")
	popup.Name = "Popup"
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.Position = UDim2.fromScale(0.5, 0.42)
	popup.Size = UDim2.fromOffset(360, 170)
	popup.BackgroundColor3 = PANEL
	popup.Visible = false
	popup.Parent = gui
	corner(popup, 16)
	stroke(popup, GOLD, 3, true)
	local popupTitle = text(popup, "Title", FONT, GOLD, UDim2.new(0, 14, 0, 10), UDim2.new(1, -28, 0, 44))
	popupTitle.TextXAlignment = Enum.TextXAlignment.Center
	local popupLines =
		text(popup, "Lines", BODY_FONT, Color3.new(1, 1, 1), UDim2.new(0, 14, 0, 62), UDim2.new(1, -28, 0, 96))
	popupLines.TextXAlignment = Enum.TextXAlignment.Center
	popupLines.TextScaled = false
	popupLines.TextSize = 22
	popupLines.TextWrapped = true

	local function layout()
		local camera = Workspace.CurrentCamera
		local compact = camera ~= nil and camera.ViewportSize.Y < Config.Ui.CompactHeight
		local spot = if compact then TRACKER_COMPACT else TRACKER_NORMAL
		tracker.AnchorPoint = spot.Anchor
		preview.AnchorPoint = spot.Anchor
		tracker.Position = spot.Position
		tracker.Size = spot.Size
		local below = spot.Position + UDim2.fromOffset(0, spot.Size.Y.Offset + 6)
		preview.Size = UDim2.fromOffset(spot.Size.X.Offset, if compact then 20 else 24)
		popup.Size = if compact then UDim2.fromOffset(300, 140) else UDim2.fromOffset(360, 170)
		return spot.Position, below
	end

	local function currentZone(): number
		local lane = LaneUtil.GetOwnedLane(player.UserId)
		return if lane then LaneUtil.ZoneOf(lane) else 1
	end

	local shownDots = -1
	local function setDots(count: number, goalCount: number)
		if shownDots == count * 100 + goalCount then
			return
		end
		shownDots = count * 100 + goalCount
		for _, child in dots:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for i = 1, goalCount do
			local dot = Instance.new("Frame")
			dot.Size = UDim2.new(0, 14, 0, 14)
			dot.BackgroundColor3 = if i <= count then GOLD else Color3.fromRGB(60, 50, 90)
			dot.Parent = dots
			corner(dot, 7)
			stroke(dot, INK, 1.5)
		end
	end

	local function refresh()
		local top, below = layout()
		local zone = currentZone()
		local now = Workspace:GetServerTimeNow()
		local active = nil
		for _, challenge in MILESTONES.Challenges do
			if challenge.Zone == nil or challenge.Zone == zone then
				active = challenge
				break
			end
		end
		tracker.Visible = active ~= nil
		if active then
			local readyAt = player:GetAttribute("ChallengeReady_" .. active.Id) or 0
			local count = player:GetAttribute("Challenge_" .. active.Id) or 0
			title.Text = "CHALLENGE"
			goal.Text = active.Text:format(active.Goal)
			if now < readyAt then
				setDots(active.Goal, active.Goal)
				prize.Text = "DONE! AGAIN IN " .. clock(readyAt - now)
				prize.TextColor3 = GREY
			else
				setDots(math.min(count, active.Goal), active.Goal)
				prize.Text = active.RewardText
				prize.TextColor3 = GOLD
			end
		end

		local nextRow = if MILESTONES.Preview then nextLevelReward(player:GetAttribute("RankLevel") or 1) else nil
		-- Only from zone 2 on: in the Back Alley the next goal bar already points the way
		preview.Visible = nextRow ~= nil and zone >= 2
		if nextRow then
			previewText.Text = ("NEXT: LV %d = %s"):format(nextRow.Level, table.concat(rewardLines(nextRow), " + "))
			preview.Position = if active then below else top
		end
	end

	-- Popups play one after another
	local queue = {}
	local showing = false
	local function showNext()
		if showing or #queue == 0 then
			return
		end
		showing = true
		local data = table.remove(queue, 1)
		popupTitle.Text = if data.Kind == "Level"
			then ("LEVEL %d REWARD!"):format(data.Level)
			elseif data.Kind == "Boss" then "BOSS DEFEATED!"
			else "CHALLENGE DONE!"
		popupLines.Text = table.concat(rewardLines(data, data.Coins), "\n")
		Sfx.Play("Reveal")
		UiFx.Open(popup)
		UiFx.Confetti(nil, 30)
		task.delay(MILESTONES.PopupTime, function()
			UiFx.Close(popup)
			local crate = Balls.GetCrate(data.CrateId)
			if crate and data.Crate and CrateController.PlayOpening then
				task.wait(0.3)
				CrateController.PlayOpening(crate, data.Crate)
			end
			showing = false
			showNext()
		end)
	end

	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MilestoneReward").OnClientEvent:Connect(function(data)
		table.insert(queue, data)
		showNext()
		refresh()
	end)

	task.spawn(function()
		while true do
			refresh()
			task.wait(0.5)
		end
	end)
end

return MilestoneController
