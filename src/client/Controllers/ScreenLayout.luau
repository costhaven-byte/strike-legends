-- Switches the UI to a compact layout on short screens (phones held sideways) and back again.
-- The normal layout is what's built in Studio; the table below only lists what changes on a phone.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local player = Players.LocalPlayer

-- Path inside PlayerGui ("*" = every child) -> properties to use on a compact screen.
-- Phone screen is roughly 670-930 wide and 320-340 tall here (below Roblox's top bar).
local COMPACT = {
	-- Top: coins/gems, rank bar
	["HUD.Bar"] = { Position = UDim2.new(0.5, 0, 0, 4) },
	["HUD.RankBar"] = { Position = UDim2.new(0.5, 0, 0, 52), Size = UDim2.new(0.6, 0, 0, 22) },

	-- Top-left: streak, with the Balls / Daily buttons in one row under it (clear of the thumbstick)
	["HUD.Streak"] = { AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromOffset(12, 4) },
	["BallsUI.Menu"] = { Position = UDim2.fromOffset(12, 128) },
	["DailyUI.DailyButton"] = { Position = UDim2.fromOffset(75, 128) },

	-- Throw meters: a shorter panel so the lane stays visible, power meter kept above the jump button
	["ThrowUI.Panel"] = { Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(0.5, 0, 0, 118) },
	["ThrowUI.Panel.Hint"] = { Size = UDim2.new(1, 0, 0, 22) },
	["ThrowUI.Panel.AimBar"] = { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 28) },
	["ThrowUI.Panel.ThrowButton"] = { Size = UDim2.new(0.6, 0, 0, 56) },
	["ThrowUI.PowerBar"] = { Position = UDim2.new(1, -36, 0, 140), Size = UDim2.fromOffset(36, 130) },
	["ThrowUI.PowerBar.Label"] = { Size = UDim2.fromOffset(80, 22) },
	["ThrowUI.ResultText"] = { Position = UDim2.new(0.5, 0, 0, 84), Size = UDim2.new(0.45, 0, 0, 40) },
	["HUD.RewardPopup"] = { Position = UDim2.new(0.5, 0, 0, 132), Size = UDim2.new(0.7, 0, 0, 30) },
	["ThrowUI.TraitPopups"] = { Position = UDim2.new(0.5, 0, 0, 166) },

	-- Rank Trial: on phones the ready button and a compact tracker (no goal line, smaller dots) share the
	-- top-right corner, the only spot clear of the meters and result text. On computers that corner holds
	-- Roblox's player list, so there the tracker sits top-left instead.
	["TrialUI.TrialButton"] = {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 6),
		Size = UDim2.fromOffset(140, 40),
	},
	["TrialUI.Tracker"] = {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 4),
		Size = UDim2.fromOffset(140, 46),
	},
	["TrialUI.Tracker.Title"] = { Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 0, 13) },
	["TrialUI.Tracker.Goal"] = { Visible = false },
	["TrialUI.Tracker.Dots"] = { Position = UDim2.fromOffset(6, 19), Size = UDim2.new(1, -12, 0, 13) },
	["TrialUI.Tracker.Dots.*"] = { Size = UDim2.fromOffset(13, 13) },
	["TrialUI.Tracker.ThrowsLeft"] = { Position = UDim2.fromOffset(6, 33), Size = UDim2.new(1, -12, 0, 10) },
	-- Lane modifier pill and the "almost there" bar: small, on the left under the menu buttons
	["EventUI.ModifierPill"] = {
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(12, 192),
		Size = UDim2.fromOffset(150, 24),
	},
	["EventUI.AlmostBar"] = {
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(12, 220),
		Size = UDim2.fromOffset(150, 22),
	},
	["EventUI.Popup"] = { Position = UDim2.new(0.5, 0, 0, 150), Size = UDim2.new(0.7, 0, 0, 44) },
	["EventUI.Banner"] = { Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.new(0.8, 0, 0, 90) },

	["TrialUI.Intro"] = { Size = UDim2.fromScale(0.9, 0.92) },

	-- Popups use most of the screen
	["BallsUI.Shop"] = { Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.94, 0.94) },
	["BallsUI.Inventory"] = { Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.94, 0.94) },
	["DailyUI.Popup"] = { Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.94, 0.94) },
	["BallsUI.Shop.Cards.*.Buy"] = { Size = UDim2.new(1, -24, 0, 44) },
	["BallsUI.Shop.Cards.*.Odds"] = { Size = UDim2.new(1, -28, 1, -96) },
}

local ScreenLayout = {}

local playerGui: PlayerGui
local compact = false
local originals: { [Instance]: { [string]: any } } = setmetatable({}, { __mode = "k" }) :: any
local watched: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function setProps(object: Instance, props: { [string]: any })
	local saved = originals[object]
	if not saved then
		saved = {}
		originals[object] = saved
	end
	for prop, value in props do
		if saved[prop] == nil then
			saved[prop] = (object :: any)[prop]
		end
		(object :: any)[prop] = if compact then value else saved[prop]
	end
end

-- Calls fn on every instance matching the path. Containers passed through "*" are watched,
-- so things added later (like the crate cards) get the layout too.
local function resolve(parent: Instance, parts: { string }, index: number, fn: (Instance) -> ())
	if index > #parts then
		fn(parent)
		return
	end
	if parts[index] == "*" then
		if not watched[parent] then
			watched[parent] = true
			parent.ChildAdded:Connect(function()
				task.defer(ScreenLayout.Apply)
			end)
		end
		for _, child in parent:GetChildren() do
			if child:IsA("GuiObject") then -- skip layouts, corners and the like
				resolve(child, parts, index + 1, fn)
			end
		end
	else
		local child = parent:FindFirstChild(parts[index])
		if child then
			resolve(child, parts, index + 1, fn)
		end
	end
end

function ScreenLayout.Apply()
	for path, props in COMPACT do
		resolve(playerGui, path:split("."), 1, function(object)
			setProps(object, props)
		end)
	end
end

function ScreenLayout:Start()
	playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local hud = playerGui:WaitForChild("HUD") :: ScreenGui
	for _, name in { "ThrowUI", "BallsUI", "DailyUI", "TrialUI", "EventUI" } do
		playerGui:WaitForChild(name)
	end

	local function update()
		local isCompact = hud.AbsoluteSize.Y > 0 and hud.AbsoluteSize.Y < Config.Ui.CompactHeight
		if isCompact ~= compact then
			compact = isCompact
			ScreenLayout.Apply()
		end
	end
	hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	update()
end

return ScreenLayout
