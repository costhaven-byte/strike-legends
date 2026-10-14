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

local function setup(object: Instance)
	if object:IsA("GuiButton") then
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
