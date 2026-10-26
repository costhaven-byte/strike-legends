-- Lane skins (Addendum 2 step 12b, Config.Cosmetics LaneSkin): repaints each lane's floor (Config.Cosmetics
-- LaneParts) in the skin its owner wears, on this screen, so everyone sees everyone's lane skin. The lane goes back
-- to its own look when the owner takes the skin off or leaves the lane.
-- Trails, pin blasts and strike banners are drawn with the throw (LaneVisuals).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Cosmetics = require(Shared.Modules.Cosmetics)
local LaneUtil = require(Shared.Modules.LaneUtil)

local LOOKS = Config.Cosmetics
local SKIN_KEY = Cosmetics.AttributeFor("LaneSkin")

local LookController = {}

-- The lane's own look, kept so a skin can be taken off: { [BasePart] = { Color, Material } }
local originals: { [BasePart]: { Color: Color3, Material: Enum.Material } } = {}
local watched: { [Player]: RBXScriptConnection } = {}

local function skinParts(lane: Model): { BasePart }
	local parts = {}
	for _, child in lane:GetChildren() do
		if child:IsA("BasePart") and table.find(LOOKS.LaneParts, child.Name) then
			table.insert(parts, child)
		end
	end
	return parts
end

local function paint(lane: Model)
	local ownerId = lane:GetAttribute("OwnerId")
	local owner = if type(ownerId) == "number" then Players:GetPlayerByUserId(ownerId) else nil
	local skin = owner and Cosmetics.Worn(owner, "LaneSkin")
	for _, part in skinParts(lane) do
		if not originals[part] then
			originals[part] = { Color = part.Color, Material = part.Material }
		end
		local own = originals[part]
		part.Color = if skin then skin.Colors[1] else own.Color
		part.Material = if skin then skin.Material or own.Material else own.Material
	end
end

function LookController:Start()
	if LOOKS.Enabled ~= true then
		return
	end
	task.spawn(function()
		local lanes = LaneUtil.GetLanes()
		local function paintAll()
			for _, lane in lanes do
				paint(lane)
			end
		end
		for _, lane in lanes do
			lane:GetAttributeChangedSignal("OwnerId"):Connect(function()
				paint(lane)
			end)
		end
		-- A player putting on or taking off a skin (or buying VIP) repaints their lanes
		local function watch(player: Player)
			watched[player] = player.AttributeChanged:Connect(function(name)
				if name == SKIN_KEY or name == "Cosmetics" or name == "Passes" then
					paintAll()
				end
			end)
		end
		for _, player in Players:GetPlayers() do
			watch(player)
		end
		Players.PlayerAdded:Connect(watch)
		Players.PlayerRemoving:Connect(function(player)
			if watched[player] then
				watched[player]:Disconnect()
				watched[player] = nil
			end
			task.defer(paintAll)
		end)
		paintAll()
	end)
end

return LookController
