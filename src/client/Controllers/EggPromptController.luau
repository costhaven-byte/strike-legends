-- First egg prompt (final changes item 6, batch C1; numbers in Config.EggPrompt): the first time your coins reach
-- EggPrompt.Coins while you stand in zone EggPrompt.Zone, a big kit popup says BUY YOUR FIRST PET EGG!, and a gold
-- beam from you plus a GO HERE! marker over the stand lead to that zone's egg (like Rizzo's first-crate guide). The
-- beam stays until you hatch an egg, your coins drop under the egg's price or you leave the zone. The popup shows
-- once ever (the server saves EggPrompted); players who already hatched an egg never get any of it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Mascots = require(Shared.Modules.Mascots)
local Zones = require(Shared.Modules.Zones)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local MomentKit = require(Modules:WaitForChild("MomentKit"))
local Sfx = require(Modules:WaitForChild("Sfx"))

local PROMPT = Config.EggPrompt
local GOLD = Color3.fromRGB(255, 200, 40)

local player = Players.LocalPlayer

local EggPromptController = {}

-- The area of the prompt's zone (Config.Zones.Gated), or nil
local function zoneArea()
	for _, gate in Config.Zones.Gated do
		if gate.Zone == PROMPT.Zone then
			return gate.Area
		end
	end
	return nil
end

-- The stand's folder (Workspace.Hub.EggPad) and its egg spot, waiting for the world to stream in
local function findStand(): (Instance?, BasePart?)
	for _, row in Config.EggStands do
		if row.Egg == PROMPT.Egg then
			local pad: Instance? = Workspace
			for _, name in row.Path do
				pad = pad and pad:WaitForChild(name, 30)
			end
			local stand = pad and pad:WaitForChild("NeonStand", 10)
			local spot = stand and stand:WaitForChild("EggSpot", 10)
			return pad, if spot and spot:IsA("BasePart") then spot else nil
		end
	end
	return nil, nil
end

function EggPromptController:Start()
	if not PROMPT.Enabled then
		return
	end
	local egg = Mascots.GetEgg(PROMPT.Egg)
	local area = zoneArea()
	if not egg or not area then
		return
	end
	local pad, spot = findStand()
	if not pad or not spot then
		warn("[EggPromptController] egg stand not found: no first egg prompt")
		return
	end
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EggPrompted") :: RemoteEvent
	if not player:GetAttribute("DataLoaded") then
		player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end

	-- GO HERE! over the stand (the EGGS area sign steps aside while it shows: Config.AreaSigns HideWhile)
	local marker = MomentKit.WorldMarker(PROMPT.Marker, GOLD)
	marker.Name = "EggCallMarker"
	marker.Adornee = spot
	marker.StudsOffsetWorldSpace = Vector3.new(0, PROMPT.MarkerHeight, 0)
	marker.Enabled = false
	marker.Parent = pad

	-- The gold beam, the same soft band + sparkles as Rizzo's first-crate guide
	local beamTo = Instance.new("Attachment")
	beamTo.Name = "EggBeamTo"
	beamTo.Parent = spot
	local beamFrom: Attachment? = nil
	local beams: { Beam } = {}
	local function setBeam(on: boolean)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if on and root and beamFrom and beamFrom.Parent == root then
			return
		end
		for _, beam in beams do
			beam:Destroy()
		end
		table.clear(beams)
		if beamFrom then
			beamFrom:Destroy()
			beamFrom = nil
		end
		if not on or not root then
			return
		end
		local from = Instance.new("Attachment")
		from.Name = "EggBeamFrom"
		from.Position = Vector3.new(0, -1.5, 0)
		from.Parent = root
		beamFrom = from
		for i = 1, 2 do
			local beam = Instance.new("Beam")
			beam.Name = "EggGuide"
			beam.Attachment0 = from
			beam.Attachment1 = beamTo
			beam.Color = ColorSequence.new(GOLD)
			beam.LightEmission = 1
			beam.FaceCamera = true
			beam.Segments = 1
			if i == 1 then
				beam.Width0 = 1.6
				beam.Width1 = 1.6
				beam.Brightness = 2
				beam.Transparency = NumberSequence.new(0.55)
			else
				beam.Width0 = 2.4
				beam.Width1 = 2.4
				beam.Brightness = 5
				beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				beam.TextureMode = Enum.TextureMode.Wrap
				beam.TextureLength = 3
				beam.TextureSpeed = 2.5
			end
			beam.Parent = root
			table.insert(beams, beam)
		end
	end

	local popup = MomentKit.Popup(MomentKit.Layer("EggPromptUI", 44))
	local prompted = (player:GetAttribute("EggPrompted") or 0) == 1
	local guiding = false
	local pending = false

	-- Big windows that own the screen (ZONE UNLOCKED!, rank up, a crate opening): the popup waits for them to close
	local function windowOpen(): boolean
		local playerGui = player:FindFirstChildOfClass("PlayerGui")
		for _, path in { { "ZoneUnlockUI", "Screen" }, { "RankUpKitUI", "Screen" }, { "BallsUI", "Opening" } } do
			local screen = playerGui and playerGui:FindFirstChild(path[1])
			local frame = screen and screen:FindFirstChild(path[2])
			if
				screen
				and screen:IsA("ScreenGui")
				and screen.Enabled
				and frame
				and frame:IsA("GuiObject")
				and frame.Visible
			then
				return true
			end
		end
		return false
	end
	local function inZone(): boolean
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		return root ~= nil and Zones.InArea(area, root.Position)
	end
	local function ready(): boolean
		return (player:GetAttribute("EggsHatched") or 0) == 0
			and Zones.Unlocked(player:GetAttribute("ZonesOpen"), PROMPT.Zone)
			and (player:GetAttribute("Coins") or 0) >= PROMPT.Coins
			and inZone()
	end
	local function refresh()
		if not prompted and not pending and ready() then
			-- the first time: the popup (once ever), then the guide
			pending = true
			task.delay(PROMPT.Delay, function()
				while windowOpen() do
					task.wait(0.5)
				end
				pending = false
				if prompted or not ready() then
					return
				end
				prompted = true
				remote:FireServer()
				Sfx.Play("Reveal")
				popup({ Text = PROMPT.Title, Color = GOLD, Sub = PROMPT.Sub, Big = true, Icon = "Hud:Paw" })
				guiding = true
				marker.Enabled = true
				setBeam(true)
			end)
		end
		-- the guide (this session only) ends once you hatch, can't pay any more or leave the zone
		if guiding and not (ready() and (player:GetAttribute("Coins") or 0) >= egg.Price) then
			guiding = false
			marker.Enabled = false
			setBeam(false)
		end
	end
	for _, key in { "Coins", "EggsHatched", "ZonesOpen" } do
		player:GetAttributeChangedSignal(key):Connect(refresh)
	end
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		setBeam(guiding)
	end)
	-- walking into the zone (or out of it) is not an attribute change: check now and then
	task.spawn(function()
		while true do
			refresh()
			task.wait(0.5)
		end
	end)
end

return EggPromptController
