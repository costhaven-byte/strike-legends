-- Crate counters in zones 3 and 4 (Phase X, Config.ZoneShops): a prompt on each counter opens the crate shop screen.
-- The booths are placeholders built in Studio; buying still goes through CrateController and the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Zones = require(Shared.Modules.Zones)
local CrateController = require(script.Parent.CrateController)

local player = Players.LocalPlayer

local ZoneShopController = {}

local function hook(row)
	local node: Instance? = Workspace
	for _, name in row.Path do
		node = node and node:WaitForChild(name, 30)
	end
	local counter = node and node:FindFirstChild("Counter")
	if not counter then
		warn(("[ZoneShopController] %s.Counter not found"):format(table.concat(row.Path, ".")))
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ObjectText = "CRATES"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
	local function refresh()
		local open = Zones.Unlocked(player:GetAttribute("ZonesOpen"), row.Zone)
		prompt.ActionText = if open then "Open crate shop" else ("Needs " .. Zones.NeedText(row.Zone):lower())
		prompt.Enabled = open
	end
	player:GetAttributeChangedSignal("ZonesOpen"):Connect(refresh)
	refresh()
	prompt.Triggered:Connect(function()
		if CrateController.OpenShop then
			CrateController.OpenShop(row.Zone)
		end
	end)
end

function ZoneShopController:Start()
	for _, row in Config.ZoneShops do
		task.spawn(hook, row)
	end
end

return ZoneShopController
