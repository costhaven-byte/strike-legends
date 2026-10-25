-- The Multiplier panel (master plan steps 13.1 and 14.6, built in Addendum 2 step 8b): a gold "x2.3" badge beside
-- the coin counter shows every coin multiplier added up; tapping it opens a card listing each source (Power Level,
-- ball, mascots, rank, streak, lane event) and the ones that only count on a special throw (PERFECT and so on).
-- When anything changes, the badge pops and the total ticks to the new number.
-- Numbers come from the CoinMultipliers Player attribute (MultiplierService, the same numbers that pay throws).
-- Also: the AUTO button, only when Config.AutoBowl.Enabled (off until monetization).
-- Built in code (not in Studio), so it lives in git.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Currency = require(Shared.Modules.Currency)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local UiFx = require(Modules:WaitForChild("UiFx"))

local player = Players.LocalPlayer

local FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local BODY_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local GOLD = Color3.fromRGB(255, 200, 40)
local CARD = Color3.fromRGB(30, 20, 60)
local INK = Color3.fromHex("06060F")
local DIM = Color3.fromRGB(150, 140, 180)
local LIME = Color3.fromRGB(125, 255, 60)

-- Each source in the panel, in order: attribute key -> name on screen
local SOURCES = {
	{ Key = "Zone", Name = "ZONE" },
	{ Key = "PowerLevel", Name = "POWER LEVEL" },
	{ Key = "Ball", Name = "BALL + POLISH" },
	{ Key = "Mascots", Name = "PETS" },
	{ Key = "Potion", Name = "COIN POTION" },
	{ Key = "Rank", Name = "RANK" },
	{ Key = "Rebirth", Name = "REBIRTH" },
	{ Key = "Friends", Name = "FRIENDS" },
	{ Key = "Streak", Name = "STREAK" },
	{ Key = "Modifier", Name = "LANE EVENT" },
}

local MultiplierController = {}

-- 2.345 -> "x2.35", 3 -> "x3", 1500 -> "x1,500"
local format = Currency.FormatMultiplier

local function decode(text: any): { [string]: number }
	local values = {}
	if type(text) == "string" then
		for key, value in text:gmatch("([^;=]+)=([^;]+)") do
			values[key] = tonumber(value) or 1
		end
	end
	return values
end

local function corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = if radius then UDim.new(0, radius) else UDim.new(0.5, 0)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number, border: boolean?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	if border then
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	s.Parent = parent
end

local function text(parent: Instance, name: string, font: Font, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.FontFace = font
	label.TextColor3 = color
	label.TextScaled = true
	label.Parent = parent
	stroke(label, INK, 2)
	return label
end

function MultiplierController:Start()
	local playerGui = player:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("HUD") :: ScreenGui
	local bar = hud:WaitForChild("Bar") :: Frame

	-- The badge: right of the coin counter, as tall as it. It sits in the HUD (the bar stacks its children) and
	-- follows the bar when phones switch to the compact layout (ScreenLayout).
	local badge = Instance.new("TextButton")
	badge.Name = "Multiplier"
	badge.Text = ""
	badge.AutoButtonColor = false
	badge.BackgroundColor3 = CARD
	badge.BackgroundTransparency = 0.1
	badge.Parent = hud
	corner(badge, 10)
	stroke(badge, GOLD, 2, true)
	local badgeText = text(badge, "Total", FONT, GOLD)
	badgeText.Position = UDim2.fromScale(0.08, 0.12)
	badgeText.Size = UDim2.fromScale(0.84, 0.76)
	UiFx.Press(badge)
	local autoButton: TextButton? = nil
	local function follow()
		local x = bar.Position.X.Offset + bar.Size.X.Offset + 6
		local y = bar.Position.Y.Offset + 2
		local height = math.floor(bar.Size.Y.Offset * 0.42)
		badge.Position = UDim2.new(bar.Position.X.Scale, x, bar.Position.Y.Scale, y)
		badge.Size = UDim2.fromOffset(66, height)
		if autoButton then
			autoButton.Position = UDim2.new(bar.Position.X.Scale, x, bar.Position.Y.Scale, y + height + 6)
			autoButton.Size = UDim2.fromOffset(66, height)
		end
	end
	bar:GetPropertyChangedSignal("Position"):Connect(follow)
	bar:GetPropertyChangedSignal("Size"):Connect(follow)
	follow()

	-- The card (centre of the screen; tap anywhere on it to close)
	local gui = Instance.new("ScreenGui")
	gui.Name = "MultiplierUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = hud.DisplayOrder + 5
	gui.Parent = playerGui
	local panel = Instance.new("TextButton")
	panel.Name = "Panel"
	panel.Text = ""
	panel.AutoButtonColor = false
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(300, 380) -- 20 taller for each of the ZONE (E2) and FRIENDS (step 11a) rows
	panel.BackgroundColor3 = CARD
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 14)
	stroke(panel, GOLD, 3, true)
	local panelScale = Instance.new("UIScale")
	panelScale.Parent = panel
	local function fitScreen()
		local height = gui.AbsoluteSize.Y
		panelScale.Scale = if height > 0 then math.min(1, (height - 20) / 340) else 1
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitScreen)
	fitScreen()

	local title = text(panel, "Title", FONT, Color3.new(1, 1, 1))
	title.Text = "COIN MULTIPLIER"
	title.Position = UDim2.fromOffset(12, 10)
	title.Size = UDim2.new(1, -24, 0, 22)
	local bigTotal = text(panel, "Total", FONT, GOLD)
	bigTotal.Position = UDim2.fromOffset(12, 34)
	bigTotal.Size = UDim2.new(1, -24, 0, 50)

	local list = Instance.new("Frame")
	list.Name = "Sources"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(16, 92)
	list.Size = UDim2.new(1, -32, 1, -100)
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 3)
	layout.Parent = list

	local function row(order: number, name: string, color: Color3): (TextLabel, TextLabel)
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = order
		frame.Size = UDim2.new(1, 0, 0, 20)
		frame.Parent = list
		local left = text(frame, "Name", BODY_FONT, color)
		left.Text = name
		left.TextXAlignment = Enum.TextXAlignment.Left
		left.Size = UDim2.fromScale(0.7, 1)
		local right = text(frame, "Value", FONT, color)
		right.TextXAlignment = Enum.TextXAlignment.Right
		right.Position = UDim2.fromScale(0.7, 0)
		right.Size = UDim2.fromScale(0.3, 1)
		return left, right
	end

	local rows = {}
	for index, source in SOURCES do
		local left, right = row(index, source.Name, Color3.new(1, 1, 1))
		rows[source.Key] = { Name = left, Value = right }
	end
	-- Only on the throw that earns them
	local divider = text(list, "OnlySome", BODY_FONT, DIM)
	divider.LayoutOrder = 50
	divider.Size = UDim2.new(1, 0, 0, 16)
	divider.Text = "ONLY ON SOME THROWS"
	local extras = {
		{ "ON A PERFECT", 1 + Config.Rewards.PerfectStrikeBonus },
		{ "OVERCHARGE BLAST", if Config.Throw.Overcharge.Enabled then Config.Throw.Overcharge.CoinMultiplier else nil },
		{ "GOLDEN PIN HIT", Config.GoldenPin.CoinMultiplier },
	}
	for index, extra in extras do
		if extra[2] then
			local _, right = row(50 + index, extra[1], LIME)
			right.Text = format(extra[2])
		end
	end

	-- Fill in, and tick the total when it changes
	local shownTotal = Instance.new("NumberValue")
	local currentTotal: number? = nil
	shownTotal.Changed:Connect(function(value)
		badgeText.Text = format(value)
		bigTotal.Text = format(value)
	end)
	local function refresh()
		local values = decode(player:GetAttribute("CoinMultipliers"))
		local total = 1
		for _, source in SOURCES do
			local value = values[source.Key] or 1
			total *= value
			local r = rows[source.Key]
			r.Value.Text = format(value)
			local color = if value > 1 then GOLD elseif value < 1 then Color3.fromRGB(255, 90, 90) else DIM
			r.Value.TextColor3 = color
			r.Name.TextColor3 = if value ~= 1 then Color3.new(1, 1, 1) else DIM
		end
		if currentTotal == nil then
			shownTotal.Value = total
			badgeText.Text = format(total)
			bigTotal.Text = format(total)
		elseif math.abs(total - currentTotal) > 1e-6 then
			TweenService:Create(shownTotal, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Value = total,
			}):Play()
			UiFx.Pop(badge, 1.35, 0.35)
			if panel.Visible then
				UiFx.Pop(bigTotal, 1.3, 0.35)
			end
			if total > currentTotal then
				-- A quick gold flash on the badge
				badge.BackgroundColor3 = GOLD
				TweenService:Create(badge, TweenInfo.new(0.5), { BackgroundColor3 = CARD }):Play()
			end
		end
		currentTotal = total
	end
	player:GetAttributeChangedSignal("CoinMultipliers"):Connect(refresh)
	refresh()

	badge.Activated:Connect(function()
		if panel.Visible then
			UiFx.Close(panel)
		else
			refresh()
			UiFx.Open(panel)
		end
	end)
	panel.Activated:Connect(function()
		UiFx.Close(panel)
	end)

	-- Auto Bowl (Config.AutoBowl): only when switched on; the server makes the remote only then
	if Config.AutoBowl.Enabled then
		local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SetAutoBowl", 10) :: RemoteEvent?
		if remote then
			local auto = Instance.new("TextButton")
			auto.Name = "AutoBowl"
			auto.Text = ""
			auto.AutoButtonColor = false
			auto.BackgroundColor3 = CARD
			auto.Parent = hud
			autoButton = auto
			follow()
			corner(auto, 10)
			stroke(auto, LIME, 2, true)
			local label = text(auto, "Label", FONT, LIME)
			label.Position = UDim2.fromScale(0.08, 0.15)
			label.Size = UDim2.fromScale(0.84, 0.7)
			local function show()
				local on = player:GetAttribute("AutoBowl") == true
				label.Text = if on then "AUTO ON" else "AUTO"
				auto.BackgroundColor3 = if on then Color3.fromRGB(40, 90, 30) else CARD
			end
			player:GetAttributeChangedSignal("AutoBowl"):Connect(show)
			show()
			auto.Activated:Connect(function()
				remote:FireServer(player:GetAttribute("AutoBowl") ~= true)
			end)
			UiFx.Press(auto)
		end
	end
end

return MultiplierController
