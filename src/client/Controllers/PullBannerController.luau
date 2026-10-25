-- Server banner for Legendary and Mythic crate pulls (Addendum 2 step 11b, Config.PullBanner): "SAM PULLED THE VOID
-- (MYTHIC)!" in the rarity's colour, just under the level bar, one at a time. The server sends it (BallService,
-- remote PullBanner) to everyone in the server. Built in code (not in Studio), so it lives in git.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)

local player = Players.LocalPlayer

local BANNER = Config.PullBanner
local FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local CARD = Color3.fromRGB(30, 20, 60)
local INK = Color3.fromHex("06060F")
local GAP = 8 -- pixels between the level bar and the banner

local PullBannerController = {}

function PullBannerController:Start()
	local playerGui = player:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("HUD") :: ScreenGui
	local rankBar = hud:WaitForChild("RankBar") :: GuiObject

	local gui = Instance.new("ScreenGui")
	gui.Name = "PullBannerUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = hud.DisplayOrder + 5
	gui.IgnoreGuiInset = hud.IgnoreGuiInset
	gui.Parent = playerGui

	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.BackgroundColor3 = CARD
	banner.BackgroundTransparency = 0.05
	banner.Visible = false
	banner.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = banner
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = banner
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.04, 0.14)
	label.Size = UDim2.fromScale(0.92, 0.72)
	label.FontFace = FONT
	label.TextScaled = true
	label.Parent = banner
	local textStroke = Instance.new("UIStroke")
	textStroke.Color = INK
	textStroke.Thickness = 2
	textStroke.Parent = label

	-- Under the level bar, as wide as it (the bar moves and shrinks on phones, ScreenLayout)
	local function place()
		local barPos, barSize = rankBar.AbsolutePosition, rankBar.AbsoluteSize
		local guiTop = gui.AbsolutePosition
		local height = math.clamp(math.floor(barSize.Y * 1.4), 28, 40)
		banner.Position = UDim2.fromOffset(barPos.X - guiTop.X + barSize.X / 2, barPos.Y - guiTop.Y + barSize.Y + GAP)
		banner.Size = UDim2.fromOffset(math.max(barSize.X, 300), height)
	end
	rankBar:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
	rankBar:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	place()

	local queue = {}
	local showing = false
	local function showNext()
		if showing or #queue == 0 then
			return
		end
		showing = true
		local data = table.remove(queue, 1)
		local ball = Balls.Get(data.BallId)
		local rarity = ball and Balls.GetRarity(ball.Rarity)
		if not ball or not rarity then
			showing = false
			showNext()
			return
		end
		label.Text = BANNER.Text:format(tostring(data.Name):upper(), ball.Name:upper(), ball.Rarity:upper())
		label.TextColor3 = rarity.Color
		stroke.Color = rarity.Color
		place()
		local target = banner.Position
		banner.Position = target - UDim2.fromOffset(0, 20)
		banner.Visible = true
		TweenService:Create(banner, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Position = target }):Play()
		task.delay(BANNER.Seconds, function()
			banner.Visible = false
			showing = false
			showNext()
		end)
	end

	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PullBanner").OnClientEvent:Connect(function(data)
		if type(data) == "table" then
			table.insert(queue, data)
			showNext()
		end
	end)
end

return PullBannerController
