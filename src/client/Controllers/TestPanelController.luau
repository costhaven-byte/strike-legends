-- Studio only (never in the live game): the TEST panel for play testing (server: TestPanelService).
-- A small purple TEST tab on the left edge opens a list of buttons: how the next play test starts (from zero, or your
-- save with everything unlocked), jump to a zone, and give coins, gems, levels, crates, eggs and potions.
-- It only appears when the server made Remotes.TestPanel, which it does only in Studio. Plain dev look on purpose.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local TestPanelController = {}

local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local PURPLE = Color3.fromRGB(110, 60, 200)
local DARK = Color3.fromRGB(28, 26, 40)
local BUTTON = Color3.fromRGB(60, 58, 84)
local W = 260

local SECTIONS = {
	{
		Title = "NEXT PLAY TEST STARTS",
		Buttons = {
			{ Text = "FROM ZERO", Action = "Mode", Mode = "Zero" },
			{ Text = "MY SAVE + ALL", Action = "Mode", Mode = "Mine" },
		},
	},
	{
		Title = "JUMP TO ZONE",
		Buttons = {
			{ Text = "ZONE 2", Action = "Zone2" },
			{ Text = "ZONE 3", Action = "Zone3" },
			{ Text = "ZONE 4", Action = "Zone4" },
		},
	},
	{
		Title = "GIVE",
		Buttons = {
			{ Text = "COINS x10", Action = "Coins" },
			{ Text = "+100 GEMS", Action = "Gems" },
			{ Text = "+1 LEVEL", Action = "Level" },
			{ Text = "PASS TRIAL", Action = "Trial" },
			{ Text = "READY TO REBIRTH", Action = "Rebirth" },
			{ Text = "FREE CRATE", Action = "Crate" },
			{ Text = "FREE EGG", Action = "Egg" },
			{ Text = "GIVE PET", Action = "Pet" }, -- (Addendum 5 B1: the next pet in the list, with its stats)
			{ Text = "ALL POTIONS", Action = "Potions" },
		},
	},
	{
		Title = "EVENTS",
		Buttons = {
			{ Text = "BOSS NOW", Action = "Boss" },
			{ Text = "FEVER NOW", Action = "Fever" },
			{ Text = "GOLDEN RACK", Action = "GoldenRack" },
			{ Text = "7-10 SPLIT", Action = "Split" },
			{ Text = "GEM PIN", Action = "GemPin" },
		},
	},
}

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		instance[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local function corner(parent: Instance, radius: number)
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function label(parent: Instance, text: string, height: number, color: Color3)
	return make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
		FontFace = FONT,
		Text = text,
		TextColor3 = color,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, parent)
end

function TestPanelController:Start()
	if not RunService:IsStudio() then
		return
	end
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TestPanel", 15) :: RemoteFunction?
	if not remote then
		return
	end

	local gui = make("ScreenGui", {
		Name = "TestPanel",
		ResetOnSpawn = false,
		DisplayOrder = 50,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))

	local tab = make("TextButton", {
		Name = "Tab",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.62, 0),
		Size = UDim2.fromOffset(34, 74),
		BackgroundColor3 = PURPLE,
		FontFace = FONT,
		Text = "T\nE\nS\nT",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 13,
		AutoButtonColor = true,
	}, gui)
	corner(tab, 8)

	local panel = make("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 40, 0.5, 0),
		Size = UDim2.new(0, W, 0.86, 0),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.05,
		Visible = false,
	}, gui)
	corner(panel, 10)
	make("UIStroke", { Color = PURPLE, Thickness = 2 }, panel)
	make("UISizeConstraint", { MaxSize = Vector2.new(W, 560) }, panel)

	local list = make("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 1, -20),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		BorderSizePixel = 0,
	}, panel)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local header = label(list, "TEST PANEL (Studio only)", 18, Color3.fromRGB(200, 170, 255))
	header.TextSize = 15
	header.LayoutOrder = nextOrder()
	local startLine = label(list, "", 16, Color3.fromRGB(170, 170, 190))
	startLine.LayoutOrder = nextOrder()
	local function refreshStart()
		local start = player:GetAttribute("StudioStart")
		startLine.Text = "This test: "
			.. (if start == "Zero" then "FROM ZERO" elseif start == "Mine" then "MY SAVE + ALL" else "...")
			.. ", nothing is saved"
	end
	refreshStart()
	player:GetAttributeChangedSignal("StudioStart"):Connect(refreshStart)

	local status = label(list, "Tap a button. Answers show here.", 34, Color3.fromRGB(255, 220, 120))
	status.LayoutOrder = nextOrder()
	local busy = false

	for _, section in SECTIONS do
		label(list, section.Title, 16, Color3.fromRGB(170, 170, 190)).LayoutOrder = nextOrder()
		local grid = make("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = nextOrder(),
		}, list)
		make("UIGridLayout", {
			CellSize = UDim2.new(0.5, -3, 0, 32),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, grid)
		for index, info in section.Buttons do
			local button = make("TextButton", {
				LayoutOrder = index,
				BackgroundColor3 = if info.Action == "Mode" then PURPLE else BUTTON,
				FontFace = FONT,
				Text = info.Text,
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 12,
				TextWrapped = true,
			}, grid)
			corner(button, 6)
			button.Activated:Connect(function()
				if busy then
					return
				end
				busy = true
				status.Text = "..."
				local ok, result = pcall(function()
					return remote:InvokeServer(info.Action, info.Mode)
				end)
				busy = false
				if ok and type(result) == "table" then
					status.Text = tostring(result.Text)
					status.TextColor3 = if result.Ok then Color3.fromRGB(140, 240, 140) else Color3.fromRGB(255, 140, 120)
				else
					status.Text = "No answer from the server"
					status.TextColor3 = Color3.fromRGB(255, 140, 120)
				end
			end)
		end
	end

	tab.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
end

return TestPanelController
