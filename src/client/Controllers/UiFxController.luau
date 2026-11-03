-- Gives every button on screen press feedback (shrink and spring back) and a click sound,
-- including buttons added later. Also starts loading all the sound effects.
local Players = game:GetService("Players")

local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)
local Motion = require(Modules.Motion)

-- These play their own sound when pressed
local SILENT_BUTTONS = {
	ThrowButton = true,
}

local UiFxController = {}

-- Full-screen dim layers behind windows (and other screen-sized tap catchers) are buttons too, but shrinking one
-- uncovers the screen's edges (Polish v2 U5)
local function screenSized(button: GuiButton): boolean
	return button.Name == "Backdrop" or (button.Size.X.Scale >= 0.95 and button.Size.Y.Scale >= 0.95)
end

-- Polish v2 D1: red dots and count badges pop in on a spring whenever they show up
local function popWhenShown(object: GuiObject)
	object:GetPropertyChangedSignal("Visible"):Connect(function()
		if object.Visible then
			local scale = object:FindFirstChildOfClass("UIScale") -- (one UIScale per object: reuse the kit's)
			if not scale then
				scale = Instance.new("UIScale")
				scale.Parent = object
			end
			Motion.PopIn(scale :: UIScale, 0.2)
		end
	end)
end

local function setup(object: Instance)
	if object:IsA("GuiButton") and not screenSized(object) then
		-- every press is remembered, so a window it opens grows out of it (Motion.WindowOpen); THROW is held all the
		-- time, so a popup that shows up while throwing doesn't fly out of it
		if not SILENT_BUTTONS[object.Name] then
			object.MouseButton1Down:Connect(function()
				Motion.NotePress(object)
			end)
		end
		-- OwnPress: the button animates and clicks by itself (the store's chunky buttons)
		if not object:GetAttribute("OwnPress") then
			UiFx.Press(object, SILENT_BUTTONS[object.Name] == true)
		end
	elseif object:IsA("Frame") and (object.Name == "Dot" or object.Name == "Badge") then
		popWhenShown(object)
	end
end

function UiFxController:Start()
	Sfx.Preload()
	UiFx.Layer()

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, object in playerGui:GetDescendants() do
		setup(object)
	end
	playerGui.DescendantAdded:Connect(setup)
end

return UiFxController
