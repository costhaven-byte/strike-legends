-- Addendum 4 core loop (Config.CoreLoop), the server half: the coin bag, the sell station on the rooftop, the rooftop
-- spawn and the hold-to-throw cooldown. Pins knocked fill the bag (ThrowService calls AddToBag); standing on the green
-- sell pad sells the whole bag for Coins. There is no remote sell: the SELL button only shows the way to the pad.
-- The server owns the bag: clients only see it through the Bag / BagSize player attributes.
-- Stage 2: the ball and bag ladders (Config.CoreLoop Balls / BagSizes / BagPrices), bought through the CoreBuy remote;
-- you throw the last ball you bought. Crates no longer give balls here.
-- Addendum 5 A2: two independent ladders (any order), bought ONLY while standing at the shop booth (server distance
-- check); the SELL / GO TO SHOP buttons teleport you onto the sell pad / shop circle (CoreGoTo remote).
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
local Mascots = require(Shared.Modules.Mascots)
local Rebirth = require(Shared.Modules.Rebirth)
local Analytics = require(script.Parent.Analytics)
local BallService = require(script.Parent.BallService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RateLimit = require(script.Parent.Parent.Modules.RateLimit)
local Pacing = require(script.Parent.Parent.Modules.Pacing)
local SessionLog = require(script.Parent.Parent.Modules.SessionLog)

local CORE = Config.CoreLoop
local SELL = CORE.Sell
local SHOP = CORE.Shop

local CoreLoopService = {}

-- Coins already promised to the bag by throws whose ball hasn't reached the pins yet
local pending: { [Player]: number } = {}
-- Addendum 5 step C: bumped by a rebirth, so coins still on their way don't land in the fresh bag
local epoch: { [Player]: number } = {}
local soldRemote: RemoteEvent

-- Addendum 5 B1: the equipped pets' stats added up (Config.PetStats; { Coins, Pins, Bag, Speed }, 0.5 = +50%)
function CoreLoopService.PetStats(player: Player): { [string]: number }
	if not Mascots.StatsOn() then
		return { Coins = 0, Pins = 0, Bag = 0, Speed = 0 }
	end
	return Mascots.TotalStats(PlayerDataService.Get(player, "EquippedMascots") or {})
end

-- How many coins the bag holds (Config.CoreLoop.BagSizes, by the saved BagLevel), x (1 + the pets' Bag stat)
function CoreLoopService.BagSize(player: Player): number
	local size = CORE.BagSizes[CoreLadder.BagLevel(PlayerDataService.Get(player, "BagLevel"))]
	return math.floor(size * (1 + CoreLoopService.PetStats(player).Bag) + 0.5)
end

-- The rebirth multiplier (Addendum 5 step C, Config.CoreLoop.Rebirth): pins per swing AND what a sell pays
function CoreLoopService.RebirthMultiplier(player: Player): number
	if not Rebirth.CoreOn() then
		return 1
	end
	return Rebirth.CoreMultiplier(PlayerDataService.Get(player, "Rebirths"))
end

-- Pins per swing multiplier: 1 + the pets' Pins stat (Addendum 5 B1), x the rebirth multiplier (step C)
function CoreLoopService.PinsMultiplier(player: Player): number
	return (1 + CoreLoopService.PetStats(player).Pins) * CoreLoopService.RebirthMultiplier(player)
end

-- The ball ladder step the player throws with (Config.CoreLoop.Balls)
function CoreLoopService.BallStep(player: Player): number
	return CoreLadder.BallStep(PlayerDataService.Get(player, "BallStep"))
end

-- Average pins per throw with the player's ball (x the pets' Pins stat, PinsMultiplier)
function CoreLoopService.PinsAverage(player: Player): number
	return CORE.Balls[CoreLoopService.BallStep(player)].Pins * CoreLoopService.PinsMultiplier(player)
end

-- The throw animation level: follows the ball step (Addendum 5 A1; it used to follow the rank level)
function CoreLoopService.Pose(player: Player): number
	return CoreLadder.Pose(PlayerDataService.Get(player, "BallStep"))
end

-- What the shop can sell of `kind` now (step, price; nil = nothing)
local function nextBuy(player: Player, kind: string): (number?, number)
	return CoreLadder.Buyable(
		kind,
		PlayerDataService.Get(player, "BallStep"),
		PlayerDataService.Get(player, "BagLevel"),
		PlayerDataService.Get(player, "Rebirths") -- (step C: prices rise each rebirth)
	)
end

-- Addendum 5 A2: is the player standing at the shop booth (its blue circle + BuySlack)? Every coin buy checks this.
function CoreLoopService.AtShop(player: Player): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local offset = root.Position - SHOP.Position
	return Vector2.new(offset.X, offset.Z).Magnitude <= SHOP.Radius + (SHOP.BuySlack or 0)
		and offset.Y > -4
		and offset.Y < 10
end

-- Owns and equips the ladder ball of the player's step (model, trail and look come from Config.Balls)
local function equipLadderBall(player: Player)
	local id = CORE.Balls[CoreLoopService.BallStep(player)].Ball
	BallService.GiveBall(player, id) -- (already owned = nothing changes)
	if PlayerDataService.Get(player, "EquippedBall") ~= id then
		PlayerDataService.Set(player, "EquippedBall", id)
	end
end

-- Addendum 5 B1: buys the next pet equip slot with coins (Config.PetStats.SlotPrices). Slots an old save keeps
-- (PetSlotsKept) count as bought, so every slot bought is a new one.
local function buyPetSlot(player: Player)
	if not Mascots.StatsOn() then
		return { Ok = false, Error = "That didn't work. Try again" }
	end
	local start = Config.Economy.Mascots.StartSlots
	local bought = math.max(
		math.floor(tonumber(PlayerDataService.Get(player, "PetSlotsBought")) or 0),
		(PlayerDataService.Get(player, "PetSlotsKept") or 0) - start
	)
	local price = Mascots.NextSlotPrice(bought)
	if not price then
		return { Ok = false, Error = "You've got every slot" }
	end
	if not PlayerDataService.Spend(player, "Coins", price) then
		return { Ok = false, Error = "Not enough coins" }
	end
	PlayerDataService.Set(player, "PetSlotsBought", bought + 1)
	Analytics.Currency(player, "Coins", -price, "Shop", ("PetSlot%d"):format(start + bought + 1))
	Analytics.Purchase(player, "PetSlot", tostring(start + bought + 1))
	SessionLog.Moment(player, ("Pet slot %d bought"):format(start + bought + 1))
	Pacing.Slot(player, start + bought + 1)
	return { Ok = true, Kind = "PetSlot", Step = start + bought + 1 }
end

-- Buys the next step of the ball or bag ladder (kind "Ball" / "Bag"; B1: or "PetSlot"), only at the shop booth
local function buy(player: Player, kind: any)
	if not PlayerDataService.IsLoaded(player) then
		return { Ok = false, Error = "Hang on, still loading" }
	end
	if kind ~= "Ball" and kind ~= "Bag" and kind ~= "PetSlot" then
		return { Ok = false, Error = "That didn't work. Try again" }
	end
	if not RateLimit.Allow(player, "CoreBuy", 0.3) then
		return { Ok = false, Error = "Too fast, wait a sec" }
	end
	if not CoreLoopService.AtShop(player) then
		return { Ok = false, Error = "Buy it at the shop" }
	end
	if kind == "PetSlot" then
		return buyPetSlot(player)
	end
	local want = kind
	local step, price = nextBuy(player, kind)
	if not step then
		local all = if kind == "Ball" then CoreLadder.NextBall(PlayerDataService.Get(player, "BallStep")) == nil
			else CoreLadder.NextBag(PlayerDataService.Get(player, "BagLevel")) == nil
		return {
			Ok = false,
			Error = if all then "You've got them all"
				elseif kind == "Bag" then "Get the next ball first"
				else "Get the next bag first",
		}
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
		Pacing.Ball(player, step)
	else
		PlayerDataService.Set(player, "BagLevel", step)
		Analytics.Purchase(player, "Bag", tostring(step))
		SessionLog.Moment(player, ("Bag %d bought"):format(step))
		Pacing.Bag(player, step)
	end
	return { Ok = true, Kind = want, Step = step }
end

-- Seconds between hold-to-throw throws (Cooldown, minus the saved throw speed upgrades), divided by 1 + the pets'
-- Speed stat (B1: +25% Speed = 25% more throws), never below CooldownFloor (the server's ThrowRate is under it too)
function CoreLoopService.Cooldown(player: Player): number
	local level = math.max(0, tonumber(PlayerDataService.Get(player, "ThrowSpeedLevel")) or 0)
	local seconds = (CORE.Cooldown - level * CORE.CooldownStep) / (1 + CoreLoopService.PetStats(player).Speed)
	return math.max(CORE.CooldownFloor, math.floor(seconds * 1000 + 0.5) / 1000)
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
	local was = epoch[player]
	task.delay(delay, function()
		if epoch[player] ~= was then
			return -- (a rebirth happened while the ball rolled: the fresh bag starts empty)
		end
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

-- Addendum 5 step C: a rebirth empties the bag and puts the ball, the bag and the throw speed back to the start
-- (RebirthService does the coins, pets and the count). Coins still on their way are dropped.
function CoreLoopService.ResetForRebirth(player: Player)
	epoch[player] = (epoch[player] or 0) + 1
	pending[player] = nil
	PlayerDataService.Set(player, "Bag", Currency.Zero())
	PlayerDataService.Set(player, "BagLevel", 1)
	PlayerDataService.Set(player, "BallStep", 1)
	PlayerDataService.Set(player, "ThrowSpeedLevel", 0)
	equipLadderBall(player)
end

-- Sells the whole bag for Coins (only ever called while the player stands on the sell pad). Step C: it pays the
-- bag's coins x the rebirth multiplier.
local function sell(player: Player)
	local bag = PlayerDataService.Get(player, "Bag") or 0
	if bag <= 0 then
		return
	end
	local multiplier = CoreLoopService.RebirthMultiplier(player)
	local paid = Currency.Round(Currency.Scale(bag, multiplier))
	PlayerDataService.Set(player, "Bag", Currency.Zero())
	PlayerDataService.Add(player, "Coins", paid)
	PlayerDataService.Add(player, "CoreSells", 1)
	LeaderboardService.RecordThrow(player, 0, paid) -- (COINS THIS WEEK counts sold coins)
	Analytics.Currency(player, "Coins", paid, "Gameplay", "Sell")
	SessionLog.Sell(player, paid, PlayerDataService.Get(player, "CoreSells") or 1)
	Pacing.Sold(player, paid)
	soldRemote:FireClient(player, paid, multiplier)
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

-- The rooftop crate kiosk sold balls by luck, which the ladder replaces, and the egg stand needs rebirths (Stage 5):
-- kept, but moved out of the world (Config.CoreLoop.HiddenStations)
local function hideCrateShop()
	local roof = Workspace:FindFirstChild(CORE.Folder)
	for _, name in CORE.HiddenStations do
		local station = roof and roof:FindFirstChild(name, true)
		if station then
			local store = ServerStorage:FindFirstChild("CoreLoopHidden") or Instance.new("Folder")
			store.Name = "CoreLoopHidden"
			store.Parent = ServerStorage
			station.Parent = store
		end
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

-- Addendum 5 B2: hue-shifts every colour in a copy (Config.CoreLoop.Eggs.Tints): parts, lights, beams and particles
local function tint(root: Instance, name: string)
	local rules = CORE.Eggs.Tints[name]
	if not rules then
		return
	end
	local function shift(color: Color3): Color3
		local h, sat, v = color:ToHSV()
		if sat < 0.15 then
			return color -- whites, greys and chrome stay
		end
		for _, rule in rules do
			if h >= rule.From and h <= rule.To then
				return Color3.fromHSV(rule.Hue, sat, v * (rule.Dark or 1))
			end
		end
		return color
	end
	local function shiftSequence(sequence: ColorSequence): ColorSequence
		local points = {}
		for _, point in sequence.Keypoints do
			table.insert(points, ColorSequenceKeypoint.new(point.Time, shift(point.Value)))
		end
		return ColorSequence.new(points)
	end
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			d.Color = shift(d.Color)
		elseif d:IsA("Light") then
			d.Color = shift(d.Color)
		elseif d:IsA("Beam") or d:IsA("ParticleEmitter") or d:IsA("Trail") then
			d.Color = shiftSequence(d.Color)
		elseif d:IsA("SurfaceAppearance") then
			d.Color = shift(d.Color)
		end
	end
end

-- B2: a stand or machine to copy: the path from Workspace, else (hidden at start) ServerStorage.CoreLoopHidden
local function source(path: { string }): Instance?
	local node: Instance? = Workspace
	for _, name in path do
		node = node and node:FindFirstChild(name)
	end
	if not node then
		local hidden = ServerStorage:FindFirstChild("CoreLoopHidden")
		node = hidden and hidden:FindFirstChild(path[#path])
	end
	return node
end

-- B2: puts a copy's pivot (its pad) on the floor at `at` (raycast), turned `turn` degrees, its lowest point on the floor
local function placeOnFloor(copy: Model, at: Vector3, turn: number?, skip: { Instance })
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = skip
	local floorY = at.Y
	local hit = Workspace:Raycast(at + Vector3.new(0, 25, 0), Vector3.new(0, -40, 0), params)
	if hit and math.abs(hit.Position.Y - at.Y) < 4 then
		floorY = hit.Position.Y
	end
	local pivot = copy:GetPivot()
	copy:PivotTo(CFrame.new(at.X, floorY, at.Z) * CFrame.Angles(0, math.rad(turn or 0), 0) * pivot.Rotation)
	-- the lowest point in world space (a model's bounding box follows its pivot part, and the pads are turned
	-- cylinders, so its "bottom" can be a side)
	local bottom = math.huge
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local cf, s = d.CFrame, d.Size
			local half = (math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z)
				/ 2
			bottom = math.min(bottom, cf.Position.Y - half)
		end
	end
	if bottom < math.huge then
		copy:PivotTo(copy:GetPivot() + Vector3.new(0, floorY - bottom, 0))
	end
end

-- B2: a clean, anchored copy (no scripts or prompts: the client adds its own)
local function copyOf(node: Instance): Model?
	if not node:IsA("Model") then
		return nil
	end
	local copy = node:Clone()
	for _, d in copy:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("ProximityPrompt") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	return copy
end

-- Addendum 5 B2: the EGG ROW next to the shop (Config.CoreLoop.Eggs): a copy of an existing stand per egg in
-- <Folder>.EggRow.<egg Id> (MascotController hatches there, MascotService checks you stand by it), the 4th egg's
-- model as a re-tinted copy of the Neon Egg, and a copy of the PET FUSION machine for the Shiny merge
local function buildEggRow()
	local EGGS = CORE.Eggs
	local roof = Workspace:FindFirstChild(CORE.Folder)
	if not EGGS or not EGGS.Enabled or not roof then
		return
	end
	-- the egg models first (clients build their stand eggs from PetModels)
	local petModels = ReplicatedStorage:FindFirstChild("PetModels")
	for id, look in Config.EggLooks do
		local from = petModels and look.Copy and petModels:FindFirstChild("Egg_" .. look.Copy)
		if from and not petModels:FindFirstChild("Egg_" .. id) then
			local egg = from:Clone()
			egg.Name = "Egg_" .. id
			if look.Tint then
				tint(egg, look.Tint)
			end
			egg.Parent = petModels
		end
	end

	for _, name in { "EggRow", EGGS.Fusion.Name } do
		local old = roof:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local row = Instance.new("Model")
	row.Name = "EggRow"
	local skip: { Instance } = { row }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(skip, player.Character)
		end
	end
	for _, egg in EGGS.List do
		local node = source(egg.From)
		local copy = node and copyOf(node)
		if not copy then
			warn(("[CoreLoopService] egg row: %s is missing (%s egg)"):format(table.concat(egg.From, "."), egg.Id))
			continue
		end
		copy.Name = egg.Id
		copy:SetAttribute("Egg", egg.Id)
		placeOnFloor(copy, egg.At, egg.Turn, skip)
		if egg.Tint then
			tint(copy, egg.Tint)
		end
		local sign = copy:FindFirstChild("Sign")
		if egg.Sign and sign then
			for _, d in sign:GetDescendants() do
				if d:IsA("TextLabel") then
					d.Text = egg.Sign
				end
			end
		end
		copy.Parent = row
	end
	row.Parent = roof

	local fusion = source(EGGS.Fusion.From)
	local machine = fusion and copyOf(fusion)
	if machine then
		machine.Name = EGGS.Fusion.Name
		placeOnFloor(machine, EGGS.Fusion.At, EGGS.Fusion.Turn, skip)
		machine.Parent = roof
	else
		warn("[CoreLoopService] egg row: no fusion machine to copy (" .. table.concat(EGGS.Fusion.From, ".") .. ")")
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
			return { Ok = false, Error = "That didn't work. Try again" }
		end
		return result
	end
	buyRemote.Parent = soldRemote.Parent

	-- Addendum 5 A2: SELL / GO TO SHOP teleport you onto that pad (the pad loop below sells; the shop opens itself)
	local goRemote = Instance.new("RemoteEvent")
	goRemote.Name = "CoreGoTo"
	goRemote.OnServerEvent:Connect(function(player, where)
		local target = if where == "Sell"
			then SELL
			elseif where == "Shop" then SHOP
			elseif where == "Eggs" and CORE.Eggs and CORE.Eggs.Enabled then { Position = CORE.Eggs.GoTo } -- (B2)
			else nil
		if not target or not PlayerDataService.IsLoaded(player) then
			return
		end
		if not RateLimit.Allow(player, "CoreGoTo", CORE.Teleport.Cooldown) then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not humanoid or humanoid.Health <= 0 then
			return
		end
		humanoid.Sit = false
		-- land a little up (feet clear of the rim): on the sell pad facing the lanes (-Z), on the shop circle
		-- facing the booth's counter (+Z), in front of the first egg facing it (-Z, B2)
		local at = target.Position + Vector3.new(0, humanoid.HipHeight + CORE.Teleport.Height, 0)
		local look = if where == "Shop" then Vector3.new(0, 0, 1) else Vector3.new(0, 0, -1)
		character:PivotTo(CFrame.lookAt(at, at + look))
		SessionLog.Moment(player, "Teleported to " .. where)
	end)
	goRemote.Parent = soldRemote.Parent

	buildSpawn()
	buildStation()
	buildShop()
	buildPlaza()
	hideCrateShop()
	buildEggRow() -- (after hideCrateShop: the roof's own Skyline stand is copied from its hiding place)

	-- The bag size and throw cooldown the HUD shows (B1: and the pins multiplier, PinsMultiplier)
	local function publish(player: Player)
		player:SetAttribute("BagSize", CoreLoopService.BagSize(player))
		player:SetAttribute("ThrowCooldown", CoreLoopService.Cooldown(player))
		player:SetAttribute("PinsMultiplier", CoreLoopService.PinsMultiplier(player))
		player:SetAttribute("RebirthMultiplier", CoreLoopService.RebirthMultiplier(player)) -- (step C)
	end
	PlayerDataService.OnLoaded(function(player)
		equipLadderBall(player)
		publish(player)
		for _, key in { "BagLevel", "ThrowSpeedLevel", "EquippedMascots", "Rebirths" } do -- (B1: pets change bag + speed; C: rebirths)
			player:GetAttributeChangedSignal(key):Connect(function()
				publish(player)
			end)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
		epoch[player] = nil
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
