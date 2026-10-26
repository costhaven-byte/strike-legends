-- Server banner for Epic and better crate pulls (Addendum 2 step 11b, Config.PullBanner): "SAM PULLED THE VOID
-- (MYTHIC)!" just under the level bar, one at a time. The server sends it (BallService, remote PullBanner) to everyone
-- in the server. Look = the owner's Crate Kit PULL BANNER (2026-10-26): dark pill with an inner line in the rarity
-- colour, sparkles both sides, the player's name in white and the rest in the rarity colour, a shine sweep.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local CrateKit = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("CrateKit"))

local player = Players.LocalPlayer

local BANNER = Config.PullBanner
local C = CrateKit.C
local make = CrateKit.Make
local tween = CrateKit.Tween

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

	-- PC 520x44 / phone 420x34, 12 px under the level bar
	local function size(): (boolean, number, number)
		local phone = CrateKit.Phone(gui)
		return phone, if phone then 420 else 520, if phone then 34 else 44
	end
	local function target(): UDim2
		local _, _, h = size()
		local barPos, barSize = rankBar.AbsolutePosition, rankBar.AbsoluteSize
		local guiTop = gui.AbsolutePosition
		return UDim2.fromOffset(barPos.X - guiTop.X + barSize.X / 2, barPos.Y - guiTop.Y + barSize.Y + 12 + h / 2)
	end

	-- Builds one banner (a CanvasGroup, so it fades out as a whole)
	local function build(data, ball)
		local phone, w, h = size()
		local rc = CrateKit.RarityColor(ball.Rarity)
		local o = if phone then 2 else 3
		local holder = make("Frame", {
			Name = "PullBanner",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(w, h + (if phone then 3 else 4)),
		}, gui)
		local shadow = make("Frame", {
			Name = "Shadow",
			BackgroundColor3 = C.Ink,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, if phone then 3 else 4),
			Size = UDim2.fromOffset(w, h),
		}, holder)
		CrateKit.Corner(shadow, h / 2)
		local pill = make("CanvasGroup", {
			Name = "Pill",
			BackgroundColor3 = C.Ink,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(w, h),
		}, holder)
		CrateKit.Corner(pill, h / 2)
		local face = make("Frame", {
			Name = "Face",
			BackgroundColor3 = C.Panel,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(o, o),
			Size = UDim2.new(1, -o * 2, 1, -o * 2),
		}, pill)
		CrateKit.Corner(face, h / 2 - o)
		-- Inner line in the rarity colour
		local line = make("Frame", {
			Name = "Line",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.new(1, -4, 1, -4),
		}, face)
		CrateKit.Stroke(line, rc, 2)
		CrateKit.Corner(line, h / 2 - o - 2)

		local shine = make("ImageLabel", {
			Name = "Shine",
			BackgroundTransparency = 1,
			Image = CrateKit.Image("Shine"),
			ImageTransparency = 0.5,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, -60, 0.5, 0),
			Size = UDim2.fromOffset(if phone then 28 else 40, if phone then 70 else 92),
			Rotation = 20,
			ZIndex = 3,
		}, pill)

		local row =
			make("Frame", { Name = "Row", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, pill)
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, if phone then 6 else 10),
		}, row)
		local sparkle = if phone then 18 else 26
		CrateKit.Icon(row, "Sparkle", sparkle).ZIndex = 2
		local text = CrateKit.Text(
			row,
			BANNER.Text:format(
				('<font color="#FFFFFF">%s</font>'):format(tostring(data.Name):upper()),
				ball.Name:upper(),
				ball.Rarity:upper()
			),
			CrateKit.Head,
			if phone then 16 else 22,
			rc,
			if phone then 1.5 else 2.5
		)
		text.LayoutOrder = 2
		text.ZIndex = 2
		-- Long names shrink: max 22 / 16, min 16 / 12
		local maxText = w - sparkle * 2 - (if phone then 12 else 20) - 24
		text.Size = UDim2.new(0, maxText, 1, -(if phone then 8 else 12))
		text.TextScaled = true
		make(
			"UITextSizeConstraint",
			{ MaxTextSize = if phone then 16 else 22, MinTextSize = if phone then 12 else 16 },
			text
		)
		make("UIPadding", { PaddingTop = UDim.new(0, if phone then 2 else 3) }, text)
		local right = CrateKit.Icon(row, "Sparkle", sparkle)
		right.LayoutOrder = 3
		right.ZIndex = 2
		return holder, pill, shine
	end

	local queue = {}
	local showing = false
	local function showNext()
		if showing or #queue == 0 then
			return
		end
		showing = true
		local data = table.remove(queue, 1)
		local ball = Balls.Get(data.BallId)
		if not ball then
			showing = false
			showNext()
			return
		end
		local holder, pill, shine = build(data, ball)
		local _, w = size()
		local rest = target()
		-- Enter: Position y -50 -> under the level bar, 0.30 Back Out
		holder.Position = rest - UDim2.fromOffset(0, 50)
		tween(holder, 0.3, Enum.EasingStyle.Back, { Position = rest })
		-- Shine sweeps across twice (0.6 Quad InOut, 0.8 apart)
		task.spawn(function()
			task.wait(0.3)
			for _ = 1, 2 do
				shine.Position = UDim2.new(0, -60, 0.5, 0)
				tween(
					shine,
					0.6,
					Enum.EasingStyle.Quad,
					{ Position = UDim2.new(0, w + 60, 0.5, 0) },
					Enum.EasingDirection.InOut
				)
				task.wait(0.6 + 0.8)
			end
		end)
		task.delay(BANNER.Seconds, function()
			-- Exit: fades out while rising 10 px (0.25)
			tween(pill, 0.25, Enum.EasingStyle.Quad, { GroupTransparency = 1 })
			tween(holder:FindFirstChild("Shadow"), 0.25, Enum.EasingStyle.Quad, { BackgroundTransparency = 1 })
			tween(holder, 0.25, Enum.EasingStyle.Quad, { Position = holder.Position - UDim2.fromOffset(0, 10) })
			task.wait(0.25)
			holder:Destroy()
			showing = false
			showNext()
		end)
	end

	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PullBanner").OnClientEvent:Connect(function(data)
		if type(data) == "table" and #queue < (BANNER.MaxWaiting or 3) then
			table.insert(queue, data)
			showNext()
		end
	end)
end

return PullBannerController
