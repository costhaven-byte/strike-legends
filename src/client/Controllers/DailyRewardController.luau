-- The daily reward calendar popup. Opens by itself on join when a reward is waiting,
-- and from the DAILY button any time. The server decides the day and gives the reward.
-- The UI itself (StarterGui.DailyUI) is built in Studio; this script fills it in and animates it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Calendar = require(Shared.Modules.Calendar)
local Balls = require(Shared.Modules.Balls)
local CrateController = require(script.Parent.CrateController)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)

local player = Players.LocalPlayer

local READY_COLOR = Color3.fromRGB(90, 230, 110)
local WAIT_COLOR = Color3.fromRGB(110, 100, 130)
local TODAY_STROKE = Color3.fromRGB(255, 200, 40)
local CLAIMED_STROKE = Color3.fromRGB(90, 230, 110)
local LOCKED_STROKE = Color3.fromRGB(80, 70, 110)

local DailyRewardController = {}

local function formatNumber(n: number): string
	local text = tostring(math.floor(n))
	repeat
		local count
		text, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return text
end

-- "1,000 coins" / "5 gems" / "Neon Crate + 15 gems"
local function rewardText(reward): string
	local parts = {}
	local crate = Balls.GetCrate(reward.Crate)
	if crate then
		table.insert(parts, crate.Name:upper())
	end
	if reward.Coins then
		table.insert(parts, formatNumber(reward.Coins))
	end
	if reward.Gems then
		table.insert(parts, formatNumber(reward.Gems) .. (if crate then " GEMS" else ""))
	end
	return table.concat(parts, "\n+")
end

function DailyRewardController:Start()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("DailyUI")
	local openButton = gui:WaitForChild("DailyButton") :: TextButton
	local dot = openButton:WaitForChild("Dot") :: Frame
	local popup = gui:WaitForChild("Popup") :: Frame
	local days = popup:WaitForChild("Days") :: Frame
	local tileTemplate = popup:WaitForChild("TileTemplate") :: Frame
	local claimButton = popup:WaitForChild("Claim") :: TextButton
	local claimLabel = claimButton:WaitForChild("Label") :: TextLabel
	local closeButton = popup:WaitForChild("Close") :: TextButton

	local claimDaily = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ClaimDaily") :: RemoteFunction

	local busy = false
	local errorText: string? = nil

	-- One tile per day, straight from Config.Daily
	local tiles = {}
	for day, reward in Config.Daily.Rewards do
		local tile = tileTemplate:Clone()
		tile.Name = "Day" .. day
		tile.LayoutOrder = day
		tile.Visible = true
		tile.DayLabel.Text = "DAY " .. day
		tile.Amount.Text = rewardText(reward)
		tile.Icons.Coin.Visible = reward.Coins ~= nil and reward.Crate == nil
		tile.Icons.Gem.Visible = reward.Gems ~= nil and reward.Crate == nil
		tile.Icons.Crate.Visible = reward.Crate ~= nil
		local crate = Balls.GetCrate(reward.Crate)
		if crate then
			tile.Icons.Crate.BackgroundColor3 = crate.Color
		end
		tile.Parent = days
		tiles[day] = tile
	end
	tileTemplate.Visible = false

	local function refresh()
		local nextDay = player:GetAttribute("DailyNext") or 1
		local claimable = player:GetAttribute("DailyClaimable") == true
		dot.Visible = claimable

		for day, tile in tiles do
			local claimed = day < nextDay or (day == nextDay and not claimable)
			local isToday = day == nextDay
			tile.Check.Visible = claimed
			tile.UIStroke.Color = if isToday and claimable
				then TODAY_STROKE
				elseif claimed then CLAIMED_STROKE
				else LOCKED_STROKE
			tile.UIStroke.Thickness = if isToday then 4 else 2
			tile.BackgroundTransparency = if claimed then 0.4 else 0
		end

		if errorText then
			claimLabel.Text = errorText:upper()
			claimButton.BackgroundColor3 = WAIT_COLOR
		elseif claimable then
			claimLabel.Text = "CLAIM DAY " .. nextDay .. "!"
			claimButton.BackgroundColor3 = READY_COLOR
		else
			local wait = Calendar.SecondsUntilNextDay(Workspace:GetServerTimeNow())
			claimLabel.Text = "NEXT REWARD IN " .. Calendar.FormatCountdown(wait):upper()
			claimButton.BackgroundColor3 = WAIT_COLOR
		end
	end

	local function setOpen(open: boolean)
		if open then
			refresh()
			UiFx.Open(popup)
		else
			UiFx.Close(popup)
		end
	end

	-- Today's tile does a little hop when you claim it
	local function celebrate(day: number)
		local tile = tiles[day]
		if not tile then
			return
		end
		local scale = tile:FindFirstChildOfClass("UIScale")
		if scale then
			scale.Scale = 1.3
			TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end
	end

	local function claim()
		if busy or player:GetAttribute("DailyClaimable") ~= true then
			return
		end
		busy = true
		local ok, result = pcall(claimDaily.InvokeServer, claimDaily)
		if not ok or not result or not result.Ok then
			errorText = if ok and result and result.Error then result.Error else "Try again"
			refresh()
			task.delay(1.5, function()
				errorText = nil
				refresh()
			end)
			busy = false
			return
		end

		refresh()
		celebrate(result.Day)
		Sfx.Play("Reveal")
		UiFx.Confetti(nil, 30)
		local crate = Balls.GetCrate(result.CrateId)
		if crate and result.Crate and CrateController.PlayOpening then
			task.wait(0.8)
			UiFx.Close(popup)
			openButton.Visible = false -- don't sit on top of the crate screen
			CrateController.PlayOpening(crate, result.Crate)
			openButton.Visible = true
		else
			task.wait(1.2)
			UiFx.Close(popup)
		end
		busy = false
	end

	openButton.Activated:Connect(function()
		setOpen(not popup.Visible)
	end)
	closeButton.Activated:Connect(function()
		setOpen(false)
	end)
	claimButton.Activated:Connect(claim)
	popup.Active = true -- taps on the popup don't fall through to the throw meter

	player:GetAttributeChangedSignal("DailyNext"):Connect(refresh)
	player:GetAttributeChangedSignal("DailyClaimable"):Connect(refresh)
	popup.Visible = false
	refresh()

	-- Keep the countdown ticking while the popup is open
	task.spawn(function()
		while true do
			task.wait(1)
			if popup.Visible and not busy then
				refresh()
			end
		end
	end)

	-- Login popup: open once on join if a reward is waiting
	local waited = 0
	while player:GetAttribute("DailyClaimable") == nil and waited < 30 do
		waited += task.wait(0.5)
	end
	if player:GetAttribute("DailyClaimable") == true then
		task.wait(1.5) -- let the game load in first
		setOpen(true)
	end
end

return DailyRewardController
