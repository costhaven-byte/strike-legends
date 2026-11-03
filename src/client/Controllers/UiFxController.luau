-- Gives every button on screen press feedback (shrink and spring back) and a click sound,
-- including buttons added later. Also starts loading all the sound effects.
local Players = game:GetService("Players")

local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)

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

local function setup(object: Instance)
	-- OwnPress: the button animates and clicks by itself (the store's chunky buttons)
	if object:IsA("GuiButton") and not object:GetAttribute("OwnPress") and not screenSized(object) then
		UiFx.Press(object, SILENT_BUTTONS[object.Name] == true)
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
