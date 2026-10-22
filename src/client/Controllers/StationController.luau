-- Zone 3 and 4 stations (Phase X Part 6), all placeholder booths built in Studio:
--   Fusion station (Main Street Lanes, Config.Fusion): opens the PETS panel, where MERGE makes Shinies.
--   Helicopter (Skyline roof, Config.Boss): flies you to the boss arena; its sign counts down the 45 minutes.
--   Rebirth station (Skyline roof, Config.Economy.Rebirth): shows what the next rebirth needs; COMING SOON while off.
-- The server decides everything (BossService, RebirthService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Currency = require(Shared.Modules.Currency)
local Rebirth = require(Shared.Modules.Rebirth)
local Zones = require(Shared.Modules.Zones)
local MascotController = require(script.Parent.MascotController)

local player = Players.LocalPlayer

local FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local INK = Color3.fromHex("06060F")
local GOLD = Color3.fromRGB(255, 200, 40)
local PINK = Color3.fromRGB(255, 79, 139)
local GREY = Color3.fromRGB(170, 160, 200)

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

local function stroke(parent: Instance, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = INK
	s.Thickness = thickness
	s.Parent = parent
end

local function sign(parent: BasePart, height: number): TextLabel
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(280, 64)
	board.StudsOffset = Vector3.new(0, height, 0)
	board.MaxDistance = 80
	board.LightInfluence = 0
	board.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = FONT
	label.TextScaled = true
	label.TextColor3 = GOLD
	label.Parent = board
	stroke(label, 2)
	return label
end

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

-- A short message at the top of the screen
local toastLabel: TextLabel? = nil
local function toast(text: string)
	if not toastLabel then
		local gui = Instance.new("ScreenGui")
		gui.Name = "StationToast"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 6
		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.new(0.5, 0, 0, 120)
		label.Size = UDim2.fromOffset(520, 40)
		label.BackgroundTransparency = 1
		label.FontFace = FONT
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Parent = gui
		stroke(label, 2)
		gui.Parent = player:WaitForChild("PlayerGui")
		toastLabel = label
	end
	local label = toastLabel :: TextLabel
	label.Text = text
	label.Visible = true
	task.delay(2.5, function()
		if label.Text == text then
			label.Visible = false
		end
	end)
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
		p.Enabled = Zones.Unlocked(player:GetAttribute("RankLevel"), FUSION.Zone)
	end
	player:GetAttributeChangedSignal("RankLevel"):Connect(refresh)
	refresh()
	p.Triggered:Connect(function()
		if MascotController.OpenPets then
			MascotController.OpenPets()
		end
	end)
end

local function helicopter()
	local BOSS = Config.Boss
	local pad = find(BOSS.Helipad)
	local part = pad and anchorOf(pad)
	if not part or not BOSS.Enabled then
		return
	end
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RideHelicopter") :: RemoteFunction
	local p = prompt(part, "HELICOPTER", 1)
	p.ActionText = "Fly to the boss"
	local label = sign(part, 16)

	-- The fight timer at the top of the screen
	local gui = Instance.new("ScreenGui")
	gui.Name = "BossUI"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	local banner = Instance.new("TextLabel")
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 70)
	banner.Size = UDim2.fromOffset(560, 46)
	banner.BackgroundTransparency = 1
	banner.FontFace = FONT
	banner.TextScaled = true
	banner.TextColor3 = PINK
	banner.Parent = gui
	stroke(banner, 2.5)
	gui.Parent = player:WaitForChild("PlayerGui")

	p.Triggered:Connect(function()
		local ok, result = pcall(remote.InvokeServer, remote)
		if not ok or not result or not result.Ok then
			toast(if ok and result and result.Error then result.Error else "Try again")
		end
	end)
	while true do
		local open = Zones.Unlocked(player:GetAttribute("RankLevel"), BOSS.Zone)
		local left = (player:GetAttribute("BossNextAt") or 0) - Workspace:GetServerTimeNow()
		local fighting = player:GetAttribute("BossFighting") == true
		if not open then
			label.Text = "BOSS: REACH " .. Zones.Name(BOSS.Zone):upper()
			label.TextColor3 = GREY
		elseif left > 0 then
			label.Text = "NEXT BOSS FLIGHT IN " .. clock(left)
			label.TextColor3 = GREY
		else
			label.Text = "FLY TO THE BOSS!"
			label.TextColor3 = GOLD
		end
		p.Enabled = open and left <= 0 and not fighting
		gui.Enabled = fighting
		local fightLeft = player:GetAttribute("BossFightLeft")
		banner.Text = if fightLeft then ("BOSS FIGHT (PLACEHOLDER): STAY ON %ds"):format(fightLeft) else "BOSS FIGHT"
		task.wait(0.5)
	end
end

local function rebirthStation()
	local REBIRTH = Config.Economy.Rebirth
	local station = find(REBIRTH.Station)
	local part = station and anchorOf(station)
	if not part then
		return
	end
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Rebirth") :: RemoteFunction
	local p = prompt(part, "REBIRTH", 2)
	p.ActionText = "Rebirth (back to level 1)"
	local label = sign(part, 14)
	local function refresh()
		if not REBIRTH.Enabled then
			label.Text = "REBIRTH: COMING SOON"
			label.TextColor3 = GREY
			p.Enabled = false
			return
		end
		local done = player:GetAttribute("Rebirths") or 0
		local level, cost = Rebirth.Level(done), Rebirth.Cost(done)
		local ready = (player:GetAttribute("RankLevel") or 1) >= level
			and Currency.CanAfford(player:GetAttribute("Coins"), cost)
		label.Text = ("REBIRTH %d: LV %d + %s COINS = %s COINS FOREVER"):format(
			done + 1,
			level,
			Currency.Format(cost),
			Currency.FormatMultiplier(Rebirth.CoinMultiplier(done + 1))
		)
		label.TextColor3 = if ready then GOLD else GREY
		p.Enabled = ready
	end
	for _, key in { "RankLevel", "Coins", "Rebirths" } do
		player:GetAttributeChangedSignal(key):Connect(refresh)
	end
	refresh()
	p.Triggered:Connect(function()
		local ok, result = pcall(remote.InvokeServer, remote)
		toast(if ok and result and result.Ok then "REBIRTH!" elseif ok and result then result.Error else "Try again")
	end)
end

function StationController:Start()
	task.spawn(fusion)
	task.spawn(helicopter)
	task.spawn(rebirthStation)
end

return StationController
