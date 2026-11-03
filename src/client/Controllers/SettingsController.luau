-- SETTINGS (owner 2026-10-29, Config.Settings): a grey HUD Kit button under GIFTS in the top-right corner (in the MORE
-- menu on phones) with a drawn gear, opening a kit window with one ON/OFF switch per Config.Settings option (a 0-100%
-- slider for Kind = "Slider" rows, like MUSIC). The choices live in Modules/Settings (saved by SettingsService); the
-- sound, music and effect code reads them. Kit look: RewardKit window + cover, UiKit boxes, a chunky switch (lime ON /
-- grey OFF, white knob, ink outlines); the slider = dark track, lime fill, the same white knob, gold percent.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local HudKit = require(Modules:WaitForChild("HudKit"))
local UiKit = require(Modules:WaitForChild("UiKit"))
local RewardKit = require(Modules:WaitForChild("RewardKit"))
local Settings = require(Modules:WaitForChild("Settings"))
local Sfx = require(Modules:WaitForChild("Sfx"))

local SETTINGS = Config.Settings
local player = Players.LocalPlayer
local C = UiKit.C
local make = UiKit.Make

local SettingsController = {}

local ROW_H, ROW_GAP = 78, 10
local W = 620
local H = 100 + #SETTINGS.Options * (ROW_H + ROW_GAP) + 18
local TRACK_W, TRACK_H, KNOB = 112, 50, 38
local SLIDER_W, SLIDER_H = 176, 26 -- slider track; its percent sits right of it

-- A white gear with the kit's ink outline, filling parent (an ink copy a little bigger sits under the white one)
local function drawGear(parent: Instance)
	local gear = make("Frame", { Name = "Gear", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, parent)
	local function piece(w: number, h: number, rotation: number, color: Color3, z: number, round: boolean)
		local frame = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(w, h),
			Rotation = rotation,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z,
		}, gear)
		make("UICorner", { CornerRadius = if round then UDim.new(0.5, 0) else UDim.new(0.25, 0) }, frame)
	end
	for _, layer in { { C.Ink, 0.08, 5 }, { C.White, 0, 6 } } do
		local color, grow, z = layer[1], layer[2], layer[3]
		for i = 0, 3 do -- 4 bars across = 8 teeth
			piece(0.2 + grow * 1.6, 0.9 + grow, i * 45, color, z, false)
		end
		piece(0.66 + grow * 1.6, 0.66 + grow * 1.6, 0, color, z, true)
	end
	piece(0.36, 0.36, 0, C.Ink, 7, true) -- the hole: an ink ring around the button's grey
	piece(0.2, 0.2, 0, HudKit.C.Grey, 8, true)
	return gear
end

-- One ON/OFF switch. Returns the button and set(on, animate).
local function makeSwitch(parent: Instance): (TextButton, (boolean, boolean) -> ())
	local button = make("TextButton", {
		Name = "Switch",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(TRACK_W, TRACK_H),
	}, parent) :: TextButton
	local track = UiKit.Box(button, "Track", C.Lime, TRACK_H / 2)
	UiKit.Place(track, 0, 0, TRACK_W, TRACK_H)
	local word = UiKit.Text(track, "ON", UiKit.Head, 22, C.White, 2)
	word.Name = "Word"
	local knob = UiKit.Box(track, "Knob", C.White, KNOB / 2)
	knob.AnchorPoint = Vector2.new(0, 0.5)
	knob.Size = UDim2.fromOffset(KNOB - 6, KNOB - 6)
	knob.ZIndex = 3
	local inner = TRACK_W - 6 -- the track's width inside its outline
	local function set(on: boolean, animate: boolean)
		local goals = {
			Position = UDim2.new(0, if on then inner - KNOB else 6, 0.5, 0),
		}
		track.BackgroundColor3 = if on then C.Lime else C.Grey
		word.Text = if on then "ON" else "OFF"
		word.TextColor3 = if on then C.White else C.LockedText
		word.Position = UDim2.fromOffset(if on then 10 else KNOB + 4, 0)
		word.Size = UDim2.new(1, -(KNOB + 14), 1, 0)
		if animate then
			TweenService:Create(knob, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), goals):Play()
		else
			knob.Position = goals.Position
		end
	end
	return button, set
end

-- A 0-100% slider for option.Key. Dragging is heard at once (Settings.Preview); letting go saves (Settings.Set).
-- Returns set(value).
local function makeSlider(parent: Instance, key: string): (number) -> ()
	local area = make("TextButton", {
		Name = "Slider",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(SLIDER_W + 96, 50),
	}, parent) :: TextButton
	local track = UiKit.Box(area, "Track", C.Slot, SLIDER_H / 2)
	UiKit.Place(track, KNOB / 2 - 3, (50 - SLIDER_H) / 2, SLIDER_W, SLIDER_H)
	local fill = make("Frame", {
		Name = "Fill",
		BackgroundColor3 = C.Lime,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0.5, 1),
		ZIndex = 2,
	}, track)
	UiKit.Corner(fill, (SLIDER_H - 6) / 2)
	local knob = UiKit.Box(track, "Knob", C.White, KNOB / 2)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(KNOB - 6, KNOB - 6)
	knob.ZIndex = 3
	local percent = UiKit.Text(area, "70%", UiKit.Num, 24, C.Gold, 2.5)
	percent.Name = "Percent"
	percent.TextXAlignment = Enum.TextXAlignment.Right
	percent.AnchorPoint = Vector2.new(1, 0)
	percent.Position = UDim2.fromScale(1, 0)
	percent.Size = UDim2.new(0, 62, 1, 0)

	local function set(value: number)
		fill.Size = UDim2.fromScale(value, 1)
		fill.Visible = value > 0
		knob.Position = UDim2.fromScale(value, 0.5)
		percent.Text = ("%d%%"):format(math.floor(value * 100 + 0.5))
		percent.TextColor3 = if value > 0 then C.Gold else C.LockedText
	end

	local dragging = false
	local function valueAt(x: number): number
		return math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
	end
	area.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			Settings.Preview(key, valueAt(input.Position.X))
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			Settings.Preview(key, valueAt(input.Position.X))
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			Settings.Set(key, Settings.Value(key))
			Sfx.Play("Click")
		end
	end)
	return set
end

function SettingsController:Start()
	if not SETTINGS or not SETTINGS.Enabled then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("HUD") :: ScreenGui

	local gui = make("ScreenGui", {
		Name = "SettingsUI",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		IgnoreGuiInset = hud.IgnoreGuiInset,
	}, playerGui) :: ScreenGui

	-- ===== The button: grey square, drawn gear, SETTINGS =====
	local kit = HudKit.Square(gui, { Name = "SettingsButton", Paint = "Grey", Icon = "Close", Key = "Settings" })
	kit.Icon.Visible = false
	drawGear(kit.Slot)
	kit:SetCaption("SETTINGS", nil, nil, 9)
	local openButton = kit.Holder :: TextButton

	-- ===== The window =====
	local windowGui = make("ScreenGui", {
		Name = "SettingsWindowUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 12,
	}, playerGui) :: ScreenGui
	local win = RewardKit.Window(windowGui, W, H)
	local cover, closeX = RewardKit.Cover(win.Panel, W, H, "SETTINGS", "SAVED FOR NEXT TIME", if UiKit.V2 then C.Gold else C.White)
	closeX.Activated:Connect(function()
		win:Close()
	end)

	local refreshers: { () -> () } = {}
	for index, option in SETTINGS.Options do
		local y = 100 + (index - 1) * (ROW_H + ROW_GAP)
		local slider = option.Kind == "Slider"
		local textW = W - 52 - (if slider then 310 else 170)
		local row = UiKit.Box(cover, option.Key, C.Page, 16)
		UiKit.Place(row, 26, y, W - 52, ROW_H)
		local name = RewardKit.Label(row, option.Name, UiKit.Head, 26, C.White, 2.5, 18, 8, textW, 34)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local info = RewardKit.Label(row, option.Info, UiKit.Body, 14, C.Label, 0, 18, 42, textW, 22)
		info.TextXAlignment = Enum.TextXAlignment.Left
		if slider then
			local set = makeSlider(row, option.Key)
			set(Settings.Value(option.Key))
			Settings.Changed(option.Key, set)
			table.insert(refreshers, function()
				set(Settings.Value(option.Key))
			end)
		else
			local switch, set = makeSwitch(row)
			set(Settings.Get(option.Key), false)
			switch.Activated:Connect(function()
				Settings.Set(option.Key, not Settings.Get(option.Key))
				Sfx.Play("Click") -- after the switch, so turning SOUND EFFECTS on clicks and off stays quiet
			end)
			Settings.Changed(option.Key, function(on)
				set(on, true)
			end)
			table.insert(refreshers, function()
				set(Settings.Get(option.Key), false)
			end)
		end
	end

	openButton.Activated:Connect(function()
		if win:IsOpen() then
			win:Close()
		else
			for _, refresh in refreshers do
				refresh()
			end
			win:Open()
		end
	end)
end

return SettingsController
