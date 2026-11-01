-- Addendum 4 Stage 3d-2: every window, popup and toast gets SunKit.Daylight (white text on the new cream panels
-- turns dark). The HUD, core HUD and core shop were restyled by hand in 3d-1 and are left out. On the rooftop the lane
-- scoreboards and the leaderboard wall get the sunny repaint too (SunKit.Board).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SunKit = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("SunKit"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local SKIP = {
	HUD = true,
	CoreHUD = true,
	CoreShopUI = true,
	ThrowUI = true,
	JoinIntro = true, -- the owner's loading screen design
	TestPanel = true,
	Chat = true,
	BubbleChat = true,
	Freecam = true,
}

local SunnyController = {}

function SunnyController:Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local function add(gui: Instance)
		if gui:IsA("LayerCollector") and not SKIP[gui.Name] then
			SunKit.Daylight(gui)
		end
	end
	for _, gui in playerGui:GetChildren() do
		add(gui)
	end
	playerGui.ChildAdded:Connect(add)

	if Config.CoreLoop.Enabled then
		local roof = workspace:WaitForChild("SkylineLanes", 60)
		local boards = roof and roof:WaitForChild("Leaderboards", 30)
		local wall = boards and boards:FindFirstChild("Board", true)
		if wall and wall:IsA("SurfaceGui") then
			SunKit.Board(wall)
		end
		for _, lane in (roof and roof:GetChildren() or {}) do
			local scoreboard = lane:FindFirstChild("Scoreboard")
			local gui = scoreboard and scoreboard:FindFirstChildWhichIsA("SurfaceGui", true)
			if gui then
				SunKit.Board(gui)
			end
		end
	end
end

return SunnyController
