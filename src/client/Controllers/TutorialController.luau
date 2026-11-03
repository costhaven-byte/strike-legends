-- Polish v2 tutorial (owner 2026-11-03: "really concise, more show not tell, reward the player with each step").
-- Shows only; TutorialService decides and pays. Two pieces:
-- * a strip of reward tiles top-centre (under PINS DOWN), one per step, showing what each step pays: done = green
--   tick, the current one bobs with a gold rim
-- * a hand on what to press now (THROW: press and hold, SELL: tap, NEXT GOAL card: tap = go to the shop) with one
--   word over it (Config.Tutorial Steps Word). It hides while you throw, while a window is open and in cut-scenes.
-- When a step is done its tile pops, the reward rises off it and the next tile lights up; after the last one the strip
-- slides away.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Currency = require(Shared.Modules.Currency)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local HudKit = require(Modules.HudKit)
local SlKit = require(Modules.SlKit)
local RewardKit = require(Modules.RewardKit)
local Sfx = require(Modules.Sfx)
local ThrowController = require(script.Parent.ThrowController)
local ShopV2 = require(Modules.ShopV2)

local PetsV2 = require(Modules.PetsV2)
local StoreController = require(script.Parent.StoreController)

-- (each IsOpen exists once that window is built)
local function isOpen(module: any): boolean
	return module.IsOpen ~= nil and module.IsOpen() == true
end
local function shopOpen(): boolean
	return isOpen(ShopV2)
end

local TUTORIAL = Config.Tutorial
local STEPS = TUTORIAL.Steps
local C = SlKit.C
local GREEN = SlKit.Paints.Green[1]

local player = Players.LocalPlayer

local TutorialController = {}

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local object = Instance.new(className)
	for key, value in props do
		(object :: any)[key] = value
	end
	object.Parent = parent
	return object
end

local function rewardText(reward): string
	if reward.Coins then
		return "+" .. Currency.Format(reward.Coins)
	elseif reward.Gems then
		return "+" .. reward.Gems
	end
	return "FREE"
end

function TutorialController:Start()
	if not TUTORIAL.Enabled or not Config.CoreLoop.Enabled then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("HUD") :: ScreenGui
	if not player:GetAttribute("DataLoaded") then
		player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end
	local function done(): number
		return tonumber(player:GetAttribute("Tutorial")) or #STEPS
	end
	if done() >= #STEPS then
		return
	end

	local gui = make("ScreenGui", {
		Name = "TutorialUI",
		ResetOnSpawn = false,
		DisplayOrder = 25, -- (over the shop window, ShopV2UI 20: in the shop the hand points at BUY BEST)
		IgnoreGuiInset = hud.IgnoreGuiInset,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)

	-- ===== Reward strip =====
	local strip = make("Frame", {
		Name = "Strip",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 0, 104),
	}, gui)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, strip)
	local tiles = {}
	for i, step in STEPS do
		local holder = make("Frame", { Name = "Step" .. i, BackgroundTransparency = 1, LayoutOrder = i }, strip)
		local tile = make("Frame", {
			Name = "Tile",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = C.Window,
		}, holder)
		make("UICorner", { CornerRadius = UDim.new(0.24, 0) }, tile)
		local rim = make("UIStroke", { Color = C.Ink, Thickness = 3 }, tile)
		local scale = make("UIScale", {}, tile)
		local iconSlot = make("Frame", {
			Name = "IconSlot",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.06),
			Size = UDim2.fromScale(0.62, 0.62),
			ZIndex = 3,
		}, tile)
		local reward = step.Reward
		if reward.Egg then
			RewardKit.Egg(iconSlot, reward.Egg)
		else
			SlKit.Image(iconSlot, if reward.Gems then "cur_gem" else "cur_coin", 10, { Size = UDim2.fromScale(1, 1) })
		end
		local amount = SlKit.Text(tile, rewardText(reward), 16, C.White, {
			Name = "Amount",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -3),
			Size = UDim2.fromScale(1, 0.32),
			ZIndex = 5,
		})
		local tick = SlKit.Text(tile, "\u{2714}", 30, C.White, {
			Name = "Tick",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromScale(1, 0.6),
			Visible = false,
			ZIndex = 6,
		})
		tiles[i] = { Holder = holder, Tile = tile, Rim = rim, Scale = scale, Icon = iconSlot, Amount = amount, Tick = tick }
	end

	-- ===== Hand + word =====
	local hand = SlKit.Text(gui, TUTORIAL.Hand, 56, C.White, {
		Name = "Hand",
		AnchorPoint = Vector2.new(0.3, 0),
		Size = UDim2.fromOffset(70, 70),
		Visible = false,
		ZIndex = 30,
	})
	local word = SlKit.Text(gui, "", 30, C.Header, {
		Name = "Word",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(240, 40),
		Visible = false,
		ZIndex = 30,
	})

	local phoneNow = false
	HudKit.OnLayout(function(phone)
		phoneNow = phone
		local side = if phone then 40 else 64
		for _, t in tiles do
			t.Holder.Size = UDim2.fromOffset(side, side)
			t.Amount.TextSize = if phone then 11 else 16
			t.Tick.TextSize = if phone then 20 else 30
		end
		strip.Size = UDim2.fromOffset((side + 10) * #STEPS, side)
		strip.Position = UDim2.new(0.5, 0, 0, if phone then 88 else 104)
		hand.TextSize = if phone then 34 else 56
		hand.Size = UDim2.fromOffset(if phone then 42 else 70, if phone then 42 else 70)
		word.TextSize = if phone then 18 else 30
	end)

	local function paintTiles(count: number)
		for i, t in tiles do
			local isDone = i <= count
			local isNow = i == count + 1
			t.Tile.BackgroundColor3 = if isDone then GREEN else C.Window
			t.Rim.Color = if isNow then C.Header else C.Ink
			t.Rim.Thickness = if isNow then 4 else 3
			t.Tick.Visible = isDone
			t.Icon.Visible = not isDone
			t.Amount.Visible = not isDone
		end
	end
	paintTiles(done())

	-- What the hand points at, found again when it's missing (screens are built by other controllers)
	local targets: { [string]: GuiObject? } = {}
	local function target(name: string): GuiObject?
		local found = targets[name]
		if found and found.Parent then
			return found
		end
		if name == "Throw" then
			local throwUi = playerGui:FindFirstChild("ThrowUI")
			found = throwUi and throwUi:FindFirstChild("ThrowButton", true) :: GuiObject?
		elseif name == "Sell" then
			local core = playerGui:FindFirstChild("CoreHUD")
			found = core and core:FindFirstChild("Sell") :: GuiObject?
		elseif name == "Goal" then
			local core = playerGui:FindFirstChild("CoreHUD")
			found = core and core:FindFirstChild("NextGoal") :: GuiObject?
		elseif name == "BuyBest" then
			local shop = playerGui:FindFirstChild("ShopV2UI")
			found = shop and shop:FindFirstChild("BuyBest", true) :: GuiObject?
		end
		targets[name] = found
		return found
	end
	local function shown(object: GuiObject): boolean
		local node: Instance? = object
		while node and node:IsA("GuiObject") do
			if not node.Visible then
				return false
			end
			node = node.Parent
		end
		return not node or not node:IsA("ScreenGui") or node.Enabled
	end
	-- a big window or a cut-scene is up: the hand and the strip wait (the shop has its own spot, BUY BEST)
	-- Polish v2 T2: any window with a dimmed Backdrop counts too (GIFTS, DAILY, PROFILE, SETTINGS ...), checked a
	-- few times a second instead of every frame
	local backdropAt, backdropUp = 0, false
	local function anyBackdrop(): boolean
		local now = os.clock()
		if now - backdropAt < 0.25 then
			return backdropUp
		end
		backdropAt, backdropUp = now, false
		for _, screen in playerGui:GetChildren() do
			if screen:IsA("ScreenGui") and screen.Enabled and screen ~= gui then
				local backdrop = screen:FindFirstChild("Backdrop", true)
				if backdrop and backdrop:IsA("GuiObject") and shown(backdrop) then
					backdropUp = true
					break
				end
			end
		end
		return backdropUp
	end
	local function busy(): boolean
		local camera = Workspace.CurrentCamera
		if camera and camera.CameraType == Enum.CameraType.Scriptable then
			return true
		end
		if shopOpen() or isOpen(StoreController) or isOpen(PetsV2) then
			return true
		end
		for _, name in { "CoreShopUI", "StoreUI", "PetsV2UI", "FuseV2UI", "HatchV2UI" } do
			local screen = playerGui:FindFirstChild(name)
			local window = screen and screen:FindFirstChild("Window", true)
			if window and window:IsA("GuiObject") and window.Visible and screen:IsA("ScreenGui") and screen.Enabled then
				return true
			end
		end
		return anyBackdrop()
	end

	-- ===== A step is done: the tile pops, the reward rises off it, the next one lights up =====
	local finished = false
	local stepRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TutorialStep") :: RemoteEvent
	stepRemote.OnClientEvent:Connect(function(count: number, reward)
		local t = tiles[count]
		if not t then
			return
		end
		paintTiles(count)
		Sfx.Play("SpinWin", 1.15, 0.6)
		t.Scale.Scale = 1.45
		SlKit.Tween(t.Scale, 0.35, "Over", { Scale = 1 })
		local pop = SlKit.Text(gui, if reward and reward.Egg then "FREE EGG!" else rewardText(reward or {}), if phoneNow then 22 else 34, C.Value, {
			Name = "RewardPop",
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.fromOffset(200, 40),
			Position = UDim2.fromOffset(
				t.Tile.AbsolutePosition.X + t.Tile.AbsoluteSize.X / 2,
				t.Tile.AbsolutePosition.Y + t.Tile.AbsoluteSize.Y + 4
			),
			ZIndex = 40,
		})
		SlKit.Tween(pop, 1.1, "Soft", { Position = pop.Position + UDim2.fromOffset(0, 46), TextTransparency = 1 })
		task.delay(1.2, pop.Destroy, pop)
		local next = tiles[count + 1]
		if next then
			task.delay(0.35, function()
				next.Scale.Scale = 0.7
				SlKit.Tween(next.Scale, 0.3, "Over", { Scale = 1 })
			end)
		else
			finished = true
			task.delay(TUTORIAL.DoneSeconds, function()
				SlKit.Tween(strip, 0.4, "Snap", { Position = strip.Position - UDim2.fromOffset(0, 220) })
				task.delay(0.45, gui.Destroy, gui)
			end)
		end
	end)

	-- ===== Every frame: the hand on the current step's target =====
	RunService.RenderStepped:Connect(function()
		if not gui.Parent then
			return
		end
		local count = done()
		local step = STEPS[count + 1]
		local inShop = step ~= nil and step.Target == "Goal" and shopOpen()
		local object = step and not finished and target(if inShop then "BuyBest" else step.Target)
		local blocked = busy()
		strip.Visible = not blocked
		local on = object ~= nil
			and shown(object :: GuiObject)
			and (inShop or not blocked)
			and not (step.Target == "Throw" and ThrowController.State() == "Charging")
		hand.Visible = on
		word.Visible = on
		local now = os.clock()
		-- the current tile bobs
		local current = tiles[count + 1]
		if current and current.Scale.Scale <= 1.001 then
			current.Tile.Position = UDim2.new(0.5, 0, 0.5, math.sin(now * 5) * 3)
		end
		if not on then
			return
		end
		local pos, size = (object :: GuiObject).AbsolutePosition, (object :: GuiObject).AbsoluteSize
		local cx, cy = pos.X + size.X / 2, pos.Y + size.Y / 2 - (if phoneNow then 8 else 16)
		local push: number
		if step.Target == "Throw" then
			-- press and hold: down, stay, up (the HOLD motion)
			local phase = (now % 1.6) / 1.6
			push = if phase < 0.15 then 1 - phase / 0.15 elseif phase < 0.75 then 0 else (phase - 0.75) / 0.25
			push *= 14
		else
			push = math.abs(math.sin(now * 4)) * 12 -- a tap
		end
		hand.Position = UDim2.fromOffset(cx, cy + push)
		word.Text = step.Word
		word.Position = UDim2.fromOffset(cx, pos.Y - 6 - math.abs(math.sin(now * 3)) * 4)
	end)
end

return TutorialController
