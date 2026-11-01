-- Addendum 4 core loop (Config.CoreLoop), the server half: the coin bag, the sell station on the rooftop, the rooftop
-- spawn and the hold-to-throw cooldown. Pins knocked fill the bag (ThrowService calls AddToBag); standing on the green
-- sell pad sells the whole bag for Coins. There is no remote sell: the SELL button only shows the way to the pad.
-- The server owns the bag: clients only see it through the Bag / BagSize player attributes.
-- Stage 2: the ball and bag ladders (Config.CoreLoop Balls / BagSizes / BagPrices), bought in turn (ball, bag, ball,
-- bag) through the CoreBuy remote; you throw the last ball you bought. Crates no longer give balls here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local AssetSlots = require(Shared.AssetSlots)
local Balls = require(Shared.Modules.Balls)
local CoreLadder = require(Shared.Modules.CoreLadder)
local Currency = require(Shared.Modules.Currency)
local Analytics = require(script.Parent.Analytics)
local BallService = require(script.Parent.BallService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RateLimit = require(script.Parent.Parent.Modules.RateLimit)
local SessionLog = require(script.Parent.Parent.Modules.SessionLog)

local CORE = Config.CoreLoop
local SELL = CORE.Sell
local SHOP = CORE.Shop

local CoreLoopService = {}

-- Coins already promised to the bag by throws whose ball hasn't reached the pins yet
local pending: { [Player]: number } = {}
local soldRemote: RemoteEvent

-- How many coins the bag holds (Config.CoreLoop.BagSizes, by the saved BagLevel)
function CoreLoopService.BagSize(player: Player): number
	return CORE.BagSizes[CoreLadder.BagLevel(PlayerDataService.Get(player, "BagLevel"))]
end

-- The ball ladder step the player throws with (Config.CoreLoop.Balls)
function CoreLoopService.BallStep(player: Player): number
	return CoreLadder.BallStep(PlayerDataService.Get(player, "BallStep"))
end

-- Average pins per throw with the player's ball
function CoreLoopService.PinsAverage(player: Player): number
	return CORE.Balls[CoreLoopService.BallStep(player)].Pins
end

-- What the shop sells next ("Ball" / "Bag", step, price; nil = everything bought)
local function nextBuy(player: Player): (string?, number, number)
	return CoreLadder.Next(PlayerDataService.Get(player, "BallStep"), PlayerDataService.Get(player, "BagLevel"))
end

-- Owns and equips the ladder ball of the player's step (model, trail and look come from Config.Balls)
local function equipLadderBall(player: Player)
	local id = CORE.Balls[CoreLoopService.BallStep(player)].Ball
	BallService.GiveBall(player, id) -- (already owned = nothing changes)
	if PlayerDataService.Get(player, "EquippedBall") ~= id then
		PlayerDataService.Set(player, "EquippedBall", id)
	end
end

-- Buys the next step of the ladder. kind must be what the shop sells next (the client shows the same order).
local function buy(player: Player, kind: any)
	if not PlayerDataService.IsLoaded(player) then
		return { Ok = false, Error = "Still loading" }
	end
	if not RateLimit.Allow(player, "CoreBuy", 0.3) then
		return { Ok = false, Error = "Slow down" }
	end
	local want, step, price = nextBuy(player)
	if not want then
		return { Ok = false, Error = "You have everything" }
	end
	if kind ~= want then
		return { Ok = false, Error = if want == "Bag" then "Get the next bag first" else "Get the next ball first" }
	end
	if not PlayerDataService.Spend(player, "Coins", price) then
		return { Ok = false, Error = "Not enough coins" }
	end
	Analytics.Currency(player, "Coins", -price, "Shop", ("Core%s%d"):format(want, step))
	if want == "Ball" then
		PlayerDataService.Set(player, "BallStep", step)
		equipLadderBall(player)
		local id = CORE.Balls[step].Ball
		Analytics.Purchase(player, "Ball", id)
		SessionLog.BallBought(player, id, "Shop")
	else
		PlayerDataService.Set(player, "BagLevel", step)
		Analytics.Purchase(player, "Bag", tostring(step))
		SessionLog.Moment(player, ("Bag %d bought"):format(step))
	end
	return { Ok = true, Kind = want, Step = step }
end

-- Seconds between hold-to-throw throws (Cooldown, minus the saved throw speed upgrades, never below CooldownFloor)
function CoreLoopService.Cooldown(player: Player): number
	local level = math.max(0, tonumber(PlayerDataService.Get(player, "ThrowSpeedLevel")) or 0)
	return math.max(CORE.CooldownFloor, CORE.Cooldown - level * CORE.CooldownStep)
end

-- Promises up to `coins` to the bag and drops them in after `delay` seconds (when the ball reaches the pins).
-- Returns the coins that fit (0 = the bag is full: pins still fall but pay nothing).
function CoreLoopService.AddToBag(player: Player, coins: number, delay: number): number
	local room = CoreLoopService.BagSize(player) - (PlayerDataService.Get(player, "Bag") or 0) - (pending[player] or 0)
	local paid = math.clamp(math.floor(coins), 0, math.max(0, room))
	if paid <= 0 then
		return 0
	end
	pending[player] = (pending[player] or 0) + paid
	task.delay(delay, function()
		if pending[player] then
			pending[player] -= paid
		end
		PlayerDataService.Add(player, "Bag", paid)
	end)
	return paid
end

-- Is the bag full (counting coins on their way)?
function CoreLoopService.IsFull(player: Player): boolean
	return (PlayerDataService.Get(player, "Bag") or 0) + (pending[player] or 0) >= CoreLoopService.BagSize(player)
end

-- A core throw happened (instrumentation: first and 10th throw ever, last action)
function CoreLoopService.OnThrow(player: Player)
	PlayerDataService.Add(player, "CoreThrows", 1)
	SessionLog.CoreThrow(player, PlayerDataService.Get(player, "CoreThrows") or 1)
end

-- Sells the whole bag for Coins (only ever called while the player stands on the sell pad)
local function sell(player: Player)
	local bag = PlayerDataService.Get(player, "Bag") or 0
	if bag <= 0 then
		return
	end
	PlayerDataService.Set(player, "Bag", Currency.Zero())
	PlayerDataService.Add(player, "Coins", bag)
	PlayerDataService.Add(player, "CoreSells", 1)
	Analytics.Currency(player, "Coins", bag, "Gameplay", "Sell")
	SessionLog.Sell(player, bag, PlayerDataService.Get(player, "CoreSells") or 1)
	soldRemote:FireClient(player, bag)
end

local function onPad(position: Vector3): boolean
	local offset = position - SELL.Position
	return Vector2.new(offset.X, offset.Z).Magnitude <= SELL.Radius and offset.Y > -2 and offset.Y < 8
end

-- ===== The sell station (built from parts at server start, nothing new to upload) =====
local function part(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.CastShadow = false
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylinders lie along X; this stands them up

-- Mixed-case rounded bold text with a thin dark outline (the owner's simulator refs, Addendum 4)
local function label(parent: Instance, text: string, size: UDim2, position: UDim2, color: Color3, stroke: number)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = size
	t.Position = position
	t.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
	t.Text = text
	t.TextScaled = true
	t.TextColor3 = color
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(28, 36, 48)
	outline.Thickness = stroke
	outline.Parent = t
	t.Parent = parent
	return t
end

local function buildStation(): Model?
	local roof = Workspace:FindFirstChild(CORE.Folder)
	if not roof then
		return nil
	end
	local old = roof:FindFirstChild("SellStation")
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "SellStation"
	local base = SELL.Position
	local r = SELL.Radius
	-- The pad: a thick white rim with the coin-green circle on it
	part({
		Name = "Rim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, r * 2 + 1.2, r * 2 + 1.2),
		CFrame = CFrame.new(base + Vector3.new(0, 0.15, 0)) * UPRIGHT,
		Color = Color3.fromRGB(250, 248, 240),
		CanCollide = false,
	}, model)
	local pad = part({
		Name = "Pad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.34, r * 2, r * 2),
		CFrame = CFrame.new(base + Vector3.new(0, 0.17, 0)) * UPRIGHT,
		Color = SELL.Color,
		CanCollide = false,
	}, model)
	-- A small coin in the middle of the green circle
	local top = Instance.new("SurfaceGui")
	top.Face = Enum.NormalId.Right -- (the cylinder's +X end faces up)
	top.LightInfluence = 0.3
	top.CanvasSize = Vector2.new(200, 200)
	top.Parent = pad
	local coin = Instance.new("ImageLabel")
	coin.BackgroundTransparency = 1
	coin.AnchorPoint = Vector2.new(0.5, 0.5)
	coin.Position = UDim2.fromScale(0.5, 0.5)
	coin.Size = UDim2.fromScale(0.36, 0.36)
	coin.Image = "rbxassetid://" .. AssetSlots.Images.HudCoin
	coin.Parent = top
	-- The booth behind the pad (away from the lanes): a counter and a sign facing the lanes
	local back = base + Vector3.new(0, 0, r + 2.2)
	part({
		Name = "Counter",
		Size = Vector3.new(10, 3.2, 2.4),
		CFrame = CFrame.new(back + Vector3.new(0, 1.6, 0)),
		Color = Color3.fromRGB(255, 196, 64),
	}, model)
	part({
		Name = "CounterTop",
		Size = Vector3.new(10.6, 0.4, 3),
		CFrame = CFrame.new(back + Vector3.new(0, 3.4, 0)),
		Color = Color3.fromRGB(250, 248, 240),
	}, model)
	for _, x in { -4.6, 4.6 } do
		part({
			Name = "Post",
			Size = Vector3.new(0.5, 9, 0.5),
			CFrame = CFrame.new(back + Vector3.new(x, 4.5, 0.6)),
			Color = Color3.fromRGB(250, 248, 240),
		}, model)
	end
	local sign = part({
		Name = "Sign",
		Size = Vector3.new(10.4, 3.4, 0.4),
		CFrame = CFrame.lookAt(back + Vector3.new(0, 8.2, 0.6), back + Vector3.new(0, 8.2, -10)),
		Color = SELL.Color,
	}, model)
	local outline = part({
		Name = "SignBack",
		Size = Vector3.new(11, 4, 0.3),
		CFrame = sign.CFrame * CFrame.new(0, 0, 0.3),
		Color = Color3.fromRGB(28, 36, 48),
	}, model)
	outline.CanCollide = false
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.LightInfluence = 0
	surface.Parent = sign
	label(surface, "Sell", UDim2.fromScale(0.8, 0.62), UDim2.fromScale(0.1, 0.04), Color3.new(1, 1, 1), 5)
	label(
		surface,
		"Stand on the green circle",
		UDim2.fromScale(0.86, 0.26),
		UDim2.fromScale(0.07, 0.68),
		Color3.fromRGB(255, 240, 160),
		3
	)
	-- The point the SELL button's guide leads to
	local beacon = Instance.new("Attachment")
	beacon.Name = "Beacon"
	beacon.Parent = pad
	model.PrimaryPart = pad
	model.Parent = roof
	return model
end

-- The ball shop booth: a sky-blue circle with a counter and a sign behind it (standing on the circle opens the shop
-- on that player's screen, CoreShopController)
local function buildShop()
	local roof = Workspace:FindFirstChild(CORE.Folder)
	if not roof then
		return
	end
	local old = roof:FindFirstChild("BallShop")
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "BallShop"
	local base = SHOP.Position
	local r = SHOP.Radius
	part({
		Name = "Rim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, r * 2 + 1.2, r * 2 + 1.2),
		CFrame = CFrame.new(base + Vector3.new(0, 0.15, 0)) * UPRIGHT,
		Color = Color3.fromRGB(250, 248, 240),
		CanCollide = false,
	}, model)
	local pad = part({
		Name = "Pad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.34, r * 2, r * 2),
		CFrame = CFrame.new(base + Vector3.new(0, 0.17, 0)) * UPRIGHT,
		Color = SHOP.Color,
		CanCollide = false,
	}, model)
	local back = base + Vector3.new(0, 0, r + 2.2)
	part({
		Name = "Counter",
		Size = Vector3.new(9, 3.2, 2.4),
		CFrame = CFrame.new(back + Vector3.new(0, 1.6, 0)),
		Color = Color3.fromRGB(255, 196, 64),
	}, model)
	part({
		Name = "CounterTop",
		Size = Vector3.new(9.6, 0.4, 3),
		CFrame = CFrame.new(back + Vector3.new(0, 3.4, 0)),
		Color = Color3.fromRGB(250, 248, 240),
	}, model)
	for _, x in { -4.1, 4.1 } do
		part({
			Name = "Post",
			Size = Vector3.new(0.5, 9, 0.5),
			CFrame = CFrame.new(back + Vector3.new(x, 4.5, 0.6)),
			Color = Color3.fromRGB(250, 248, 240),
		}, model)
	end
	-- Balls 1, 5 and 10 of the ladder on the counter, in their colours
	for i, step in { 1, 5, 10 } do
		local ball = Balls.Get(CORE.Balls[step].Ball)
		part({
			Name = "Ball",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.6,
			CFrame = CFrame.new(back + Vector3.new((i - 2) * 2.6, 4.4, 0)),
			Color = if ball then ball.Color else Color3.new(1, 1, 1),
			CanCollide = false,
		}, model)
	end
	local sign = part({
		Name = "Sign",
		Size = Vector3.new(9.4, 3.4, 0.4),
		CFrame = CFrame.lookAt(back + Vector3.new(0, 8.2, 0.6), back + Vector3.new(0, 8.2, -10)),
		Color = SHOP.Color,
	}, model)
	local outline = part({
		Name = "SignBack",
		Size = Vector3.new(10, 4, 0.3),
		CFrame = sign.CFrame * CFrame.new(0, 0, 0.3),
		Color = Color3.fromRGB(28, 36, 48),
	}, model)
	outline.CanCollide = false
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.LightInfluence = 0
	surface.Parent = sign
	label(surface, "Balls & Bags", UDim2.fromScale(0.86, 0.62), UDim2.fromScale(0.07, 0.04), Color3.new(1, 1, 1), 5)
	label(
		surface,
		"Stand on the blue circle",
		UDim2.fromScale(0.86, 0.26),
		UDim2.fromScale(0.07, 0.68),
		Color3.fromRGB(220, 240, 255),
		3
	)
	-- The point the first-30-seconds guide leads to (CoreHudController)
	local beacon = Instance.new("Attachment")
	beacon.Name = "Beacon"
	beacon.Parent = pad
	model.PrimaryPart = pad
	model.Parent = roof
end

-- The rooftop crate kiosk sold balls by luck, which the ladder replaces: kept, but moved out of the world
local function hideCrateShop()
	local roof = Workspace:FindFirstChild(CORE.Folder)
	local kiosk = roof and roof:FindFirstChild("CrateShop", true)
	if kiosk then
		local store = ServerStorage:FindFirstChild("CoreLoopHidden") or Instance.new("Folder")
		store.Name = "CoreLoopHidden"
		store.Parent = ServerStorage
		kiosk.Parent = store
	end
end

-- Stage 3b: the plaza props (copies of existing models, Config.CoreLoop.Plaza) and one display case slot per ladder
-- ball (ShowcaseController builds the cases on each screen)
local function buildPlaza()
	local roof = Workspace:FindFirstChild(CORE.Folder)
	local plaza = CORE.Plaza
	if not roof or not plaza then
		return
	end
	local old = roof:FindFirstChild("Plaza")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Plaza"
	for i, prop in plaza.Props do
		local node: Instance? = Workspace
		for _, name in prop.From do
			node = node and node:FindFirstChild(name)
		end
		if not node or not node:IsA("Model") then
			warn(("[CoreLoopService] plaza prop %d: %s is missing"):format(i, table.concat(prop.From, ".")))
			continue
		end
		local copy = node:Clone()
		for _, d in copy:GetDescendants() do
			if d:IsA("BaseScript") or d:IsA("ProximityPrompt") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		-- Middle of the model on the floor point, turned around Y
		local box, size = copy:GetBoundingBox()
		local offset = box:ToObjectSpace(copy:GetPivot())
		local target = CFrame.new(prop.At + Vector3.new(0, size.Y / 2, 0))
			* CFrame.Angles(0, math.rad(prop.Turn or 0), 0)
			* box.Rotation
		copy:PivotTo(target * offset)
		copy.Parent = folder
	end
	folder.Parent = roof

	local slots = roof:FindFirstChild("Showcase") and roof.Showcase:FindFirstChild("Slots")
	local cases = plaza.Cases
	if not slots or not cases then
		return
	end
	local list = slots:GetChildren()
	table.sort(list, function(a, b)
		return (a:GetAttribute("Order") or 0) < (b:GetAttribute("Order") or 0)
	end)
	local template = list[1]
	if not template or not template:IsA("BasePart") then
		return
	end
	for i = 1, #CORE.Balls do
		local slot = list[i] or template:Clone()
		slot.Name = "Slot" .. i
		slot:SetAttribute("Order", i)
		local floor = cases.First + cases.Step * (i - 1)
		-- (slots keep their own height and facing; only X and Z move)
		slot.CFrame = template.CFrame.Rotation + Vector3.new(floor.X, template.Position.Y, floor.Z)
		slot.Parent = slots
	end
end

-- The rooftop spawn (the lobby spawn is switched off, not removed)
local function buildSpawn()
	for _, spawn in Workspace:GetDescendants() do
		if spawn:IsA("SpawnLocation") and spawn.Name ~= "CoreSpawn" then
			spawn.Enabled = false
		end
	end
	local roof = Workspace:FindFirstChild(CORE.Folder)
	if not roof or roof:FindFirstChild("CoreSpawn") then
		return
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CoreSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 0.4, 8)
	spawn.Position = CORE.Spawn
	spawn.Color = Color3.fromRGB(250, 248, 240)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Neutral = true
	spawn.Duration = 0 -- no force field bubble
	spawn.CanCollide = true
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawn.Parent = roof
end

function CoreLoopService:Start()
	if not CORE.Enabled then
		return
	end
	soldRemote = Instance.new("RemoteEvent")
	soldRemote.Name = "CoreSold"
	soldRemote.Parent = ReplicatedStorage:WaitForChild("Remotes")

	local buyRemote = Instance.new("RemoteFunction")
	buyRemote.Name = "CoreBuy"
	buyRemote.OnServerInvoke = function(player, kind)
		local ok, result = pcall(buy, player, kind)
		if not ok then
			warn("[CoreLoopService] Buy failed: " .. tostring(result))
			return { Ok = false, Error = "Something went wrong" }
		end
		return result
	end
	buyRemote.Parent = soldRemote.Parent

	buildSpawn()
	buildStation()
	buildShop()
	buildPlaza()
	hideCrateShop()

	-- The bag size and throw cooldown the HUD shows
	local function publish(player: Player)
		player:SetAttribute("BagSize", CoreLoopService.BagSize(player))
		player:SetAttribute("ThrowCooldown", CoreLoopService.Cooldown(player))
	end
	PlayerDataService.OnLoaded(function(player)
		equipLadderBall(player)
		publish(player)
		for _, key in { "BagLevel", "ThrowSpeedLevel" } do
			player:GetAttributeChangedSignal(key):Connect(function()
				publish(player)
			end)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)

	-- Who stands on the sell pad
	task.spawn(function()
		while true do
			task.wait(0.2)
			for _, player in Players:GetPlayers() do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and PlayerDataService.IsLoaded(player) and onPad(root.Position) then
					sell(player)
				end
			end
		end
	end)
end

return CoreLoopService
