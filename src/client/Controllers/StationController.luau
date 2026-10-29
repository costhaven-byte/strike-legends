-- Zone 3 and 4 stations (Phase X Part 6), placed in Studio:
--   Fusion station (Main Street Lanes, Config.Fusion): opens the PET FUSION window (UI pass batch 5), which merges
--   3 of a pet into a Shiny like the MERGE button in the PETS panel.
-- The helicopter (Pin Titan boss event) lives in BossController. Rebirth is a HUD button now (RebirthController).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Zones = require(Shared.Modules.Zones)
local MascotController = require(script.Parent.MascotController)

local player = Players.LocalPlayer

local StationController = {}

local function find(path: { string }): Instance?
	local node: Instance? = Workspace
	for _, name in path do
		node = node and node:WaitForChild(name, 30)
	end
	return node
end

-- The part a prompt and sign hang on: the station's Counter or Pad part, else its first part
local function anchorOf(station: Instance): BasePart?
	local part = station:FindFirstChild("Counter") or station:FindFirstChild("Pad")
	if part and part:IsA("BasePart") then
		return part
	end
	return station:FindFirstChildWhichIsA("BasePart", true)
end

local function prompt(parent: BasePart, objectText: string, hold: number?): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ObjectText = objectText
	p.HoldDuration = hold or 0
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

local function fusion()
	local FUSION = Config.Fusion
	local station = find(FUSION.Path)
	local part = station and anchorOf(station)
	if not part or not FUSION.Enabled then
		return
	end
	local p = prompt(part, "PET FUSION")
	p.ActionText = "Merge 3 pets into a Shiny"
	local function refresh()
		p.Enabled = Zones.Unlocked(player:GetAttribute("ZonesOpen"), FUSION.Zone)
	end
	player:GetAttributeChangedSignal("ZonesOpen"):Connect(refresh)
	refresh()
	p.Triggered:Connect(function()
		if MascotController.OpenFusion then
			MascotController.OpenFusion()
		end
	end)
end

function StationController:Start()
	task.spawn(fusion)
end

return StationController
