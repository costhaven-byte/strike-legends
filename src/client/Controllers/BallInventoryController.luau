-- The BALLS button (shows your equipped ball) and the inventory where you pick which ball to throw.
-- The UI itself (StarterGui.BallsUI) is built in Studio; this script fills it in.
-- Ownership comes from Player attributes the server sets: OwnedBalls and EquippedBall.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local UiFx = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("UiFx"))

local player = Players.LocalPlayer

local LOCKED_COLOR = Color3.fromRGB(70, 60, 100)

local BallInventoryController = {}

-- Fills one tile (used here and by the crate reel)
function BallInventoryController.FillTile(tile: GuiObject, ball, owned: boolean)
	local rarity = Balls.GetRarity(ball.Rarity)
	local swatch = tile:FindFirstChild("Swatch") :: Frame
	local outline = tile:FindFirstChildOfClass("UIStroke") :: UIStroke
	local glow = tile:FindFirstChild("Glow") :: Frame

	tile.Rarity.Text = ball.Rarity:upper()
	tile.Rarity.TextColor3 = rarity.Color
	outline.Color = rarity.Color
	glow.BackgroundColor3 = rarity.Color
	tile.Lock.Visible = not owned
	-- Traits show on locked balls too, so you know what you're chasing
	local trait = tile:FindFirstChild("Trait") :: TextLabel?
	if trait then
		local text = Balls.DescribeTraits(ball, true, true)
		trait.Text = if text == "" then "NO TRAIT" else text
		trait.TextTransparency = if text == "" then 0.6 else 0
	end
	if owned then
		tile.BallName.Text = ball.Name
		swatch.BackgroundColor3 = ball.Color
		local goldBonus = math.floor(ball.Forgiveness * Config.Throw.ForgivenessScale * 100 + 0.5)
		tile.Stats.Text = if goldBonus > 0
			then ("x%g coins · gold +%d%%"):format(ball.Multiplier, goldBonus)
			else ("x%g coins"):format(ball.Multiplier)
		tile.BackgroundTransparency = 0
	else
		tile.BallName.Text = "???"
		swatch.BackgroundColor3 = LOCKED_COLOR
		tile.Stats.Text = "Find it in crates"
		tile.BackgroundTransparency = 0.4
	end
end

function BallInventoryController:Start()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("BallsUI")
	-- Balls, crates and crate openings draw above the DAILY, trial and event layers
	-- (on phones these screens fill the display, so nothing should poke through)
	gui.DisplayOrder = 8
	local menu = gui:WaitForChild("Menu")
	local ballsButton = menu:WaitForChild("BallsButton") :: TextButton
	local buttonSwatch = ballsButton:WaitForChild("Swatch") :: Frame
	local panel = gui:WaitForChild("Inventory") :: Frame
	local grid = panel:WaitForChild("Grid") :: ScrollingFrame
	local countLabel = panel:WaitForChild("Count") :: TextLabel
	local detail = panel:WaitForChild("Detail") :: TextLabel
	local template = panel:WaitForChild("TileTemplate") :: TextButton
	local equipRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EquipBall") :: RemoteEvent

	-- The detail line: full trait description of the ball you point at (or tapped), else the equipped one
	local function showDetail(ball)
		ball = ball or Balls.Get(player:GetAttribute("EquippedBall")) or Config.Balls[1]
		local owned = Balls.DecodeOwned(player:GetAttribute("OwnedBalls"))[ball.Id] == true
		local rarity = Balls.GetRarity(ball.Rarity)
		local name = if owned then ball.Name else "??? " .. ball.Rarity:lower() .. " ball"
		local traits = Balls.DescribeTraits(ball, false, true)
		detail.Text = ('<font color="#%s">%s</font>   %s'):format(
			rarity.Color:ToHex(),
			name:upper(),
			if traits == "" then "No special trait" else (traits:gsub("\n", "   "))
		)
	end

	-- One tile per ball, made once
	local tiles = {}
	for _, ball in Config.Balls do
		local tile = template:Clone()
		tile.Name = ball.Id
		tile.Visible = true
		tile.Parent = grid
		tiles[ball.Id] = tile
		tile.Activated:Connect(function()
			showDetail(ball)
			if Balls.DecodeOwned(player:GetAttribute("OwnedBalls"))[ball.Id] then
				equipRemote:FireServer(ball.Id)
			end
		end)
		tile.MouseEnter:Connect(function()
			showDetail(ball)
		end)
		tile.MouseLeave:Connect(function()
			showDetail(nil)
		end)
	end

	local function refresh()
		local owned = Balls.DecodeOwned(player:GetAttribute("OwnedBalls"))
		local equipped = player:GetAttribute("EquippedBall")

		local ownedCount = 0
		for order, ball in Balls.Sorted() do
			local isOwned = owned[ball.Id] == true
			local tile = tiles[ball.Id]
			BallInventoryController.FillTile(tile, ball, isOwned)
			tile.Tag.Visible = ball.Id == equipped
			-- Owned balls first, best first; locked ones after, so there's always something to chase
			tile.LayoutOrder = if isOwned then order else order + 100
			if isOwned then
				ownedCount += 1
			end
		end
		countLabel.Text = ("%d / %d COLLECTED  ·  TAP A BALL TO EQUIP"):format(ownedCount, #Config.Balls)

		local current = Balls.Get(equipped) or Config.Balls[1]
		buttonSwatch.BackgroundColor3 = current.Color
		local outline = buttonSwatch:FindFirstChildOfClass("UIStroke")
		if outline then
			outline.Color = Balls.GetRarity(current.Rarity).Color
		end
	end

	player:GetAttributeChangedSignal("OwnedBalls"):Connect(refresh)
	showDetail(nil)
	player:GetAttributeChangedSignal("EquippedBall"):Connect(function()
		refresh()
		local tile = tiles[player:GetAttribute("EquippedBall")]
		local scale = tile and tile:FindFirstChildOfClass("UIScale")
		if scale then
			scale.Scale = 1.15
			TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end
	end)
	refresh()

	local function setOpen(open: boolean)
		if open then
			gui.Shop.Visible = false
			UiFx.Open(panel)
		else
			UiFx.Close(panel)
		end
	end

	ballsButton.Activated:Connect(function()
		setOpen(not panel.Visible)
	end)
	panel:WaitForChild("Close").Activated:Connect(function()
		setOpen(false)
	end)
	panel.Active = true -- taps on the panel don't fall through to the throw meter
	panel.Visible = false
end

return BallInventoryController
