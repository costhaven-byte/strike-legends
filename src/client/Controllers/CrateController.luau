-- The crate shop (prices, visible odds, pity counter, the "next unlock" goal) and the crate opening reel.
-- The shop screen opens from the lobby kiosk (KioskController); there's no menu button for it.
-- The UI itself (StarterGui.BallsUI) is built in Studio; this script fills it in and animates it.
-- The server picks the ball; the reel only shows what the server already decided.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Currency = require(Shared.Modules.Currency)
local Balls = require(Shared.Modules.Balls)
local Zones = require(Shared.Modules.Zones)
local BallInventoryController = require(script.Parent.BallInventoryController)
local CollectionBookController = require(script.Parent.CollectionBookController)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)
local BallView = require(Modules.BallView)

local player = Players.LocalPlayer

local REEL_TILES = 42 -- tiles on the reel
local REEL_WIN_INDEX = 36 -- the tile that holds the real result
local TILE_WIDTH = 112
local TILE_GAP = 8
local SPIN_TIME = Config.CrateShop.SpinTime
local CAN_AFFORD = Color3.fromRGB(90, 230, 110)
local CANT_AFFORD = Color3.fromRGB(110, 100, 130)
local EPIC_INDEX = 4 -- Epic and better get the extra-special reveal
local LEGENDARY_INDEX = 5 -- Legendary and better get even more

local CrateController = {}
-- Fires (crate, result) after a bought crate finished its opening (Rizzo reacts to rare pulls)
CrateController.Opened = Instance.new("BindableEvent")

-- What this crate costs you right now (the first crate you buy is cheaper: Balls.CratePrice)
function CrateController.Price(crate): number
	return Balls.CratePrice(crate, player:GetAttribute("CratesBought"))
end

-- How much off this crate is for you right now (93 = 93% off: your first crate), or nil at the normal price
function CrateController.Discount(crate): number?
	local price = CrateController.Price(crate)
	if price >= crate.Price or crate.Price <= 0 then
		return nil
	end
	return math.floor((1 - price / crate.Price) * 100 + 0.5)
end

-- Every number on screen uses the shared formatter (Config.Numbers)
local formatNumber = Currency.Format

-- Locked crates (their zone isn't open yet) show blacked out and can't be opened
function CrateController.Locked(crate): boolean
	return not Zones.CrateUnlocked(crate, player:GetAttribute("RankLevel"))
end

-- "UNLOCKS IN NEON LANES" + the rank level it opens at
function CrateController.LockText(crate): (string, string)
	local zone = crate.Zone or 1
	return ("UNLOCKS IN %s"):format(Zones.Name(zone):upper()),
		("ZONE %d  ·  REACH LEVEL %d"):format(zone, Zones.UnlockLevel(zone))
end

-- A random ball using the crate's odds, for the filler tiles on the reel
local function randomBall(crate)
	local roll = math.random() * 100
	local rarityName = Config.Rarities[1].Name
	for _, rarity in Config.Rarities do
		roll -= crate.Odds[rarity.Name] or 0
		if roll <= 0 then
			rarityName = rarity.Name
			break
		end
	end
	local pool = {}
	for _, ball in Config.Balls do
		if ball.Rarity == rarityName and Zones.BallInCrate(ball, crate) then
			table.insert(pool, ball)
		end
	end
	if #pool == 0 then
		for _, ball in Config.Balls do
			if Zones.BallInCrate(ball, crate) then
				table.insert(pool, ball)
			end
		end
	end
	return pool[math.random(#pool)]
end

function CrateController:Start()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("BallsUI")
	local panel = gui:WaitForChild("Shop") :: Frame
	local cards = panel:WaitForChild("Cards") :: ScrollingFrame
	local cardTemplate = panel:WaitForChild("CardTemplate") :: Frame
	local pityLabel = panel:WaitForChild("Pity") :: TextLabel
	local tileTemplate = gui:WaitForChild("Inventory"):WaitForChild("TileTemplate") :: TextButton
	local toast = gui:WaitForChild("Toast") :: TextLabel

	local opening = gui:WaitForChild("Opening") :: Frame
	local window = opening:WaitForChild("Window") :: Frame
	local strip = window:WaitForChild("Strip") :: Frame
	local status = opening:WaitForChild("Status") :: TextLabel
	local reveal = opening:WaitForChild("Reveal") :: Frame
	local revealScale = reveal:WaitForChild("UIScale") :: UIScale
	local flash = opening:WaitForChild("Flash") :: Frame
	local continueButton = reveal:WaitForChild("Continue") :: TextButton

	local openCrate = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("OpenCrate") :: RemoteFunction
	local equipRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EquipBall") :: RemoteEvent

	local busy = false
	local toastToken = 0
	local showOdds: (crate: any) -> () -- the odds screen, built further down

	local function showToast(text: string)
		toastToken += 1
		local token = toastToken
		toast.Text = text:upper()
		toast.Visible = true
		toast.Rotation = 0
		for _, angle in { -4, 4, -2, 2, 0 } do
			TweenService:Create(toast, TweenInfo.new(0.05), { Rotation = angle }):Play()
			task.wait(0.05)
		end
		task.delay(1.5, function()
			if token == toastToken then
				toast.Visible = false
			end
		end)
	end

	local function setOpen(open: boolean)
		if open then
			gui.Inventory.Visible = false
			local book = gui:FindFirstChild("Book")
			if book then
				book.Visible = false
			end
			UiFx.Open(panel)
		else
			UiFx.Close(panel)
		end
	end

	-- Top line: the first crate's promise, then how pity works (each crate counts its own pulls)
	local function refreshPity()
		pityLabel.Text = if (player:GetAttribute("CratesBought") or 0) == 0
			then ("YOUR FIRST CRATE IS A GUARANTEED %s!"):format(Config.Onboarding.FirstBoughtRarity:upper())
			else "EVERY CRATE HAS A GUARANTEE  ·  TAP ODDS FOR EVERY BALL'S CHANCE"
	end

	-- Pulls left (this one included) until a pity row of a crate guarantees its rarity
	local function pullsLeft(row): number
		return math.max(row.After - (player:GetAttribute("Pity_" .. row.Key) or 0), 1)
	end

	-- The "NEXT UNLOCK" card: the cheapest pity guarantee (in coins) that can still give you a ball you don't own,
	-- how many crates and coins away it is, and which balls it could be. Display only; the server rolls crates.
	local goal = cards:WaitForChild("Goal") :: Frame
	local goalList = goal:WaitForChild("List") :: Frame
	local goalRow = goalList:WaitForChild("RowTemplate") :: Frame

	local function lockedBalls(minRarity: number, owned, crate)
		local list = {}
		for _, ball in Balls.Sorted() do
			if
				(if crate then Zones.BallInCrate(ball, crate) else ball.InCrates ~= false)
				and not owned[ball.Id]
				and Balls.RarityIndex(ball.Rarity) >= minRarity
				and (not crate or (crate.Odds[ball.Rarity] or 0) > 0)
			then
				table.insert(list, ball)
			end
		end
		return list
	end

	local function refreshGoal()
		local owned = Balls.DecodeOwned(player:GetAttribute("OwnedBalls"))
		local coins = player:GetAttribute("Coins") or 0

		-- Cheapest guarantee that still has locked balls behind it
		local best, bestCrate, bestLeft, bestCost, bestLocked = nil, nil, 0, math.huge, nil
		for _, crate in Config.Crates do
			if CrateController.Locked(crate) then
				continue -- its zone isn't open yet
			end
			for _, row in Balls.PityRows(crate.Id) do
				local locked = lockedBalls(Balls.RarityIndex(row.Rarity), owned, crate)
				local left = pullsLeft(row)
				local cost = left * crate.Price
				if #locked > 0 and cost < bestCost then
					best, bestCrate, bestLeft, bestCost, bestLocked = row, crate, left, cost, locked
				end
			end
		end

		for _, child in goalList:GetChildren() do
			if child:IsA("Frame") and child ~= goalRow then
				child:Destroy()
			end
		end

		local target, bar, sub, coinsLabel = goal.Target, goal.Bar, goal.Sub, goal.Coins
		if not best then
			local anyLocked = {}
			for _, crate in Config.Crates do
				if not CrateController.Locked(crate) then
					for _, ball in lockedBalls(1, owned, crate) do
						if not table.find(anyLocked, ball) then
							table.insert(anyLocked, ball)
						end
					end
				end
			end
			target.Text = if #anyLocked == 0 then "ALL BALLS!" else "NEW BALLS"
			target.TextColor3 = Color3.fromRGB(255, 240, 90)
			sub.Text = if #anyLocked == 0 then "You own every ball" else "Keep opening crates"
			bar.Visible = false
			coinsLabel.Text = ""
			bestLocked = anyLocked
		else
			local rarity = Balls.GetRarity(best.Rarity)
			local done = best.After - bestLeft
			target.Text = best.Rarity:upper() .. "+"
			target.TextColor3 = rarity.Color
			sub.Text = ("guaranteed in %d %s%s"):format(bestLeft, bestCrate.Name, if bestLeft == 1 then "" else "s")
			bar.Visible = true
			bar.Fill.BackgroundColor3 = rarity.Color
			bar.Fill.Size = UDim2.fromScale(math.clamp(done / best.After, 0.03, 1), 1)
			bar.Count.Text = ("%d / %d CRATES"):format(done, best.After)
			coinsLabel.Text = if coins >= bestCost
				then "You can afford it now!"
				else ("%s coins to go"):format(formatNumber(bestCost - coins))
		end

		goal.CouldBe.Visible = #bestLocked > 0
		for i = 1, math.min(#bestLocked, 4) do
			local ball = bestLocked[#bestLocked - i + 1] -- the most likely ones (lowest rarity) first
			local row = goalRow:Clone()
			row.Name = ball.Id
			row.LayoutOrder = i
			row.Visible = true
			BallView.Put(row.Dot, ball, { Margin = 0.95 })
			row.BallName.Text = ('%s  <font color="#%s">%s</font>'):format(
				ball.Name,
				Balls.GetRarity(ball.Rarity).Color:ToHex(),
				ball.Rarity:upper()
			)
			row.Parent = goalList
		end
	end
	-- Centre the cards when they fit; when they don't (phones), line them up from the left so you can scroll
	local cardLayout = cards:WaitForChild("UIListLayout") :: UIListLayout
	local function alignCards()
		local fits = cardLayout.AbsoluteContentSize.X <= cards.AbsoluteSize.X
		cardLayout.HorizontalAlignment = if fits then Enum.HorizontalAlignment.Center else Enum.HorizontalAlignment.Left
	end
	cardLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(alignCards)
	cards:GetPropertyChangedSignal("AbsoluteSize"):Connect(alignCards)
	alignCards()

	for _, crate in Config.Crates do
		for _, row in Balls.PityRows(crate.Id) do
			player:GetAttributeChangedSignal("Pity_" .. row.Key):Connect(refreshGoal)
		end
	end
	player:GetAttributeChangedSignal("OwnedBalls"):Connect(refreshGoal)
	player:GetAttributeChangedSignal("Coins"):Connect(refreshGoal)
	player:GetAttributeChangedSignal("RankLevel"):Connect(refreshGoal)
	refreshGoal()

	-- Intro (Config.CrateShop.Intro): the crate (ReplicatedStorage.CrateModels, the kiosk designs) slams down,
	-- does a few funky hops with the lid peeking open and light leaking out, then the lid blasts off
	-- with a beam of light. Spinning rays and a glow ring dance behind it to the beat.
	local INTRO = Config.CrateShop.Intro
	local crateModels = ReplicatedStorage:WaitForChild("CrateModels", 10)

	local introStage = Instance.new("Frame")
	introStage.Name = "CrateIntro"
	introStage.AnchorPoint = Vector2.new(0.5, 0.5)
	introStage.Position = UDim2.fromScale(0.5, 0.55)
	introStage.Size = UDim2.fromScale(0.6, 0.6)
	introStage.BackgroundTransparency = 1
	introStage.Visible = false
	introStage.ZIndex = 5
	local stageAspect = Instance.new("UIAspectRatioConstraint")
	stageAspect.Parent = introStage
	introStage.Parent = opening

	-- Glow ring behind the crate
	local introGlow = Instance.new("Frame")
	introGlow.Name = "Glow"
	introGlow.AnchorPoint = Vector2.new(0.5, 0.5)
	introGlow.Position = UDim2.fromScale(0.5, 0.5)
	introGlow.Size = UDim2.fromScale(0.5, 0.5)
	introGlow.BorderSizePixel = 0
	introGlow.ZIndex = 5
	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(0.5, 0)
	glowCorner.Parent = introGlow
	local glowStroke = Instance.new("UIStroke")
	glowStroke.Thickness = 6
	glowStroke.Parent = introGlow
	introGlow.Parent = introStage

	-- Light rays: each spoke is a full-height bar (two rays, one each way) so it turns around the centre
	local introRays = Instance.new("Frame")
	introRays.Name = "Rays"
	introRays.AnchorPoint = Vector2.new(0.5, 0.5)
	introRays.Position = UDim2.fromScale(0.5, 0.5)
	introRays.Size = UDim2.fromScale(1, 1)
	introRays.BackgroundTransparency = 1
	introRays.ZIndex = 5
	introRays.Parent = introStage
	local rayBars = {}
	for i = 1, INTRO.Rays do
		local spoke = Instance.new("Frame")
		spoke.AnchorPoint = Vector2.new(0.5, 0.5)
		spoke.Position = UDim2.fromScale(0.5, 0.5)
		spoke.Size = UDim2.fromScale(INTRO.RayWidth, 1)
		spoke.Rotation = (i - 1) * 180 / INTRO.Rays
		spoke.BackgroundTransparency = 1
		spoke.ZIndex = 5
		spoke.Parent = introRays
		for _, top in { true, false } do
			local ray = Instance.new("Frame")
			ray.Size = UDim2.fromScale(1, 0.5)
			ray.Position = UDim2.fromScale(0, if top then 0 else 0.5)
			ray.BorderSizePixel = 0
			ray.ZIndex = 5
			local fade = Instance.new("UIGradient")
			fade.Rotation = if top then 90 else -90 -- bright at the centre, gone at the tip
			fade.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.6, 0.55),
				NumberSequenceKeypoint.new(1, 0.15),
			})
			fade.Parent = ray
			ray.Parent = spoke
			table.insert(rayBars, { Ray = ray, Even = i % 2 == 0 })
		end
	end
	local raysScale = Instance.new("UIScale")
	raysScale.Parent = introRays

	local introView = Instance.new("ViewportFrame")
	introView.Name = "Crate"
	introView.AnchorPoint = Vector2.new(0.5, 0.5)
	introView.Position = UDim2.fromScale(0.5, 0.5)
	introView.Size = UDim2.fromScale(1, 1)
	introView.BackgroundTransparency = 1
	introView.Ambient = Color3.fromRGB(200, 200, 220)
	introView.LightColor = Color3.new(1, 1, 1)
	introView.LightDirection = Vector3.new(-1, -1.5, -1)
	introView.ZIndex = 6
	local introCamera = Instance.new("Camera")
	introCamera.FieldOfView = 40
	introCamera.Parent = introView
	introView.CurrentCamera = introCamera
	introView.Parent = introStage

	local function easeOut(k: number): number
		return 1 - (1 - k) ^ 3
	end

	local CORNERS = {}
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				table.insert(CORNERS, Vector3.new(x, y, z))
			end
		end
	end

	-- The lid's bottom back edge (model space, front = +Z): it swings open around this line
	local function lidHinge(model: Model, lid: Model): CFrame
		local pivot = model:GetPivot()
		local lowY, backZ = math.huge, math.huge
		for _, part in lid:GetDescendants() do
			if part:IsA("BasePart") then
				for _, corner in CORNERS do
					local point = pivot:PointToObjectSpace(part.CFrame:PointToWorldSpace(part.Size / 2 * corner))
					lowY = math.min(lowY, point.Y)
					backZ = math.min(backZ, point.Z)
				end
			end
		end
		return CFrame.new(0, lowY, backZ)
	end

	local function playIntro(crate)
		local template = crateModels and crateModels:FindFirstChild(crate.Id)
		if not template then
			return
		end
		local model = template:Clone() :: Model
		local _, size = model:GetBoundingBox()
		model:ScaleTo(model:GetScale() * INTRO.CrateSize / math.max(size.X, size.Z))
		model:PivotTo(CFrame.new())
		local _, scaled = model:GetBoundingBox()
		model.Parent = introView

		-- Hinged lid (every crate model has a Lid): peeks open on each hop, blasts off at the end
		local lid = model:FindFirstChild("Lid") :: Model?
		local hinge, lidHome
		if lid then
			hinge = lidHinge(model, lid)
			lidHome = hinge:Inverse() * lid:GetPivot()
		end
		local hingeY = if hinge then hinge.Y else scaled.Y * 0.2
		-- Light inside the crate, seen through the gap under the lid (the Alley Crate has its own Loot_Glow)
		local core = Instance.new("Part")
		core.Material = Enum.Material.Neon
		core.Color = crate.Color:Lerp(Color3.new(1, 1, 1), 0.35)
		core.Size = Vector3.new(scaled.X * 0.8, scaled.Y * 0.25, scaled.Z * 0.8)
		core.Transparency = 1
		core.Parent = model
		local beam = Instance.new("Part")
		beam.Shape = Enum.PartType.Cylinder
		beam.Material = Enum.Material.Neon
		beam.Color = crate.Color:Lerp(Color3.new(1, 1, 1), 0.5)
		beam.Transparency = 1
		beam.Parent = model
		local lootGlow = model:FindFirstChild("Loot_Glow", true)

		local color = crate.Color
		local white = Color3.new(1, 1, 1)
		introGlow.BackgroundColor3 = color
		glowStroke.Color = color:Lerp(white, 0.5)
		for _, bar in rayBars do
			bar.Ray.BackgroundColor3 = if bar.Even then color else color:Lerp(white, 0.6)
		end
		introView.ImageColor3 = white
		introView.ImageTransparency = 1
		introRays.Visible = false
		introGlow.Visible = false
		introStage.Visible = true
		status.Visible = true
		status.Text = crate.Name:upper()
		status.TextColor3 = color
		UiFx.Pop(status, 1.4, 0.3)

		local turn = math.rad(INTRO.HopTurn)
		local hopsEnd = INTRO.DropTime + INTRO.Hops * INTRO.HopTime
		local total = hopsEnd + INTRO.BlastTime
		local start = os.clock()
		local lastFrame = start
		local hop, landed, blasted = 0, false, false
		local kick = 0 -- camera punch-in on every landing, fades out
		local shake = 0
		local raysAngle = 0
		while true do
			local now = os.clock()
			local t = now - start
			local dt = now - lastFrame
			lastFrame = now
			if t >= total then
				break
			end
			local lift, spin, tilt, lidAngle, lidLift, lidSpin = 0, 0, 0, 0, 0, 0
			local heat = 0 -- 0..1 how worked up the crate is (ray speed, glow)
			if t < INTRO.DropTime then
				-- Slams down from above, spinning in
				local k = t / INTRO.DropTime
				lift = INTRO.DropHeight * (1 - k * k)
				spin = -INTRO.DropSpin * 2 * math.pi * (1 - easeOut(k))
				introView.ImageTransparency = 1 - math.min(k * 3, 1)
			elseif t < hopsEnd then
				introView.ImageTransparency = 0
				if not landed then
					landed = true
					kick, shake = 1, 1
					Sfx.Play("PinHit", 0.7, 1.2)
					UiFx.Pop(introGlow, 1.6, 0.3)
				end
				-- Hops: each one higher, a quarter turn each, a little wiggle in the air
				local h = (t - INTRO.DropTime) / INTRO.HopTime
				local index = math.floor(h)
				local k = h - index
				if index + 1 ~= hop then
					hop = index + 1
					Sfx.Play("ReelTick", 0.9 + hop * 0.2)
					if index > 0 then
						-- landed the previous hop: thump
						kick, shake = 0.6 + index * 0.2, 0.5 + index * 0.25
						UiFx.Pop(introGlow, 1.3 + index * 0.15, 0.25)
						raysScale.Scale = 1.2 + index * 0.1
					end
				end
				heat = (index + k) / INTRO.Hops
				local height = INTRO.HopHeight * (1 + index * INTRO.HopGrow)
				lift = height * 4 * k * (1 - k)
				spin = (index + easeOut(k)) * turn
				tilt = math.sin(k * math.pi * 2) * math.rad(INTRO.HopWiggle) * (if index % 2 == 0 then 1 else -1)
				-- The lid flaps while airborne and rests a little more open after each hop
				lidAngle = INTRO.LidPeek * (index + math.sin(k * math.pi) * 1.5)
			else
				-- Blast: crouch and rattle, then the lid rockets off and a beam of light shoots out
				local k = (t - hopsEnd) / INTRO.BlastTime
				spin = INTRO.Hops * turn
				heat = 1
				if k < INTRO.CrouchShare then
					local c = k / INTRO.CrouchShare
					lift = -0.15 * c
					shake = math.max(shake, 0.6 + c)
					tilt = (math.random() - 0.5) * 0.1 * c
					lidAngle = INTRO.LidPeek * INTRO.Hops * (1 - c * 0.7)
				else
					local b = (k - INTRO.CrouchShare) / (1 - INTRO.CrouchShare)
					if not blasted then
						blasted = true
						kick, shake = 1.6, 1.4
						Sfx.Play("StrikeCrash", 1.35, 0.8)
						Sfx.Play("Firework", 1.1, 0.7)
						UiFx.Flash(color, 0.5, 0.3)
						UiFx.Confetti(opening, INTRO.Confetti, { color, white, color:Lerp(white, 0.5) })
						UiFx.Pop(introGlow, 2.2, 0.4)
					end
					lidLift = INTRO.LidFly * easeOut(b)
					lidSpin = INTRO.LidSpin * 2 * math.pi * b
					lidAngle = 70
					local beamHeight = INTRO.BeamHeight * easeOut(math.min(b * 2, 1))
					local beamWidth = scaled.X * 0.55 * (1 - b * 0.6)
					beam.Size = Vector3.new(math.max(beamHeight, 0.05), beamWidth, beamWidth)
					beam.Transparency = 0.25 + b * 0.75
					introView.ImageColor3 = white:Lerp(color:Lerp(white, 0.4), b)
				end
			end

			-- Beat-driven extras: the rays turn faster as it heats up, alternate colours swap on every beat
			raysAngle += dt * 360 * (INTRO.RaySpin + heat * INTRO.RaySpinHot)
			introRays.Rotation = raysAngle
			local rayTarget = if blasted then 1.9 else 1 + heat * 0.25
			raysScale.Scale += (rayTarget - raysScale.Scale) * math.min(dt * 8, 1)
			local beat = (hop + (if blasted then 1 else 0)) % 2 == 0
			for _, bar in rayBars do
				bar.Ray.BackgroundTransparency = 0.15 + (if bar.Even == beat then 0 else 0.4) * (1 - heat * 0.5)
			end
			introRays.Visible = landed
			introGlow.Visible = landed
			introGlow.BackgroundTransparency = 0.78 - heat * 0.25
			kick = math.max(kick - dt * 5, 0)
			shake = math.max(shake - dt * 4, 0)
			introStage.Position =
				UDim2.new(0.5, (math.random() - 0.5) * 16 * shake, 0.55, (math.random() - 0.5) * 16 * shake)

			local cf = CFrame.new(0, lift, 0) * CFrame.Angles(0, math.rad(INTRO.FaceAngle) + spin, tilt)
			model:PivotTo(cf)
			if lid and hinge and lidHome then
				lid:PivotTo(
					cf
						* CFrame.new(0, lidLift, -lidLift * 0.3)
						* hinge
						* CFrame.Angles(-math.rad(lidAngle) - lidSpin, 0, 0)
						* lidHome
				)
			end
			core.CFrame = cf * CFrame.new(0, hingeY - core.Size.Y / 2, 0)
			beam.CFrame = cf * CFrame.new(0, hingeY + beam.Size.X / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
			local leak = math.clamp(lidAngle / 25, 0, 1)
			core.Transparency = 1 - leak * 0.9
			if lootGlow and lootGlow:IsA("BasePart") then
				lootGlow.Transparency = 1 - leak * 0.9
			end
			local distance = INTRO.CameraDistance * (1 - kick * INTRO.Kick)
			introCamera.CFrame =
				CFrame.lookAt(Vector3.new(0, distance * 0.3, distance), Vector3.new(0, scaled.Y * 0.35, 0))
			RunService.RenderStepped:Wait()
		end
		introStage.Visible = false
		introStage.Position = UDim2.fromScale(0.5, 0.55)
		introView.ImageColor3 = Color3.new(1, 1, 1)
		raysScale.Scale = 1
		model:Destroy()
	end

	-- Plays the crate intro, the reel, then the reveal. Returns when the player taps Continue.
	-- equipPrompt: the button says EQUIP! and equips the new ball (the first-3-minutes gift crate)
	local function playOpening(crate, result, equipPrompt: boolean?)
		local ball = Balls.Get(result.BallId)
		local rarity = Balls.GetRarity(ball.Rarity)
		local rarityIndex = Balls.RarityIndex(ball.Rarity)

		opening.Visible = true
		reveal.Visible = false
		window.Visible = false
		playIntro(crate)

		strip:ClearAllChildren()
		for i = 1, REEL_TILES do
			local tile = tileTemplate:Clone()
			tile.Visible = true
			tile.Active = false
			tile.Position = UDim2.fromOffset((i - 1) * (TILE_WIDTH + TILE_GAP), 12)
			tile.Tag.Visible = false
			local shown = if i == REEL_WIN_INDEX then ball else randomBall(crate)
			BallInventoryController.FillTile(tile, shown, true)
			tile.Parent = strip
		end

		opening.Visible = true
		reveal.Visible = false
		window.Visible = true
		status.Visible = true
		status.Text = crate.Name:upper()
		status.TextColor3 = crate.Color
		window.UIStroke.Color = crate.Color

		-- Line the winning tile up under the marker, landing a little off-centre so it feels natural.
		-- Measured before the pop-in below, which briefly shrinks the window and would throw this off.
		local center = window.AbsoluteSize.X / 2
		UiFx.Pop(window, 0.6, 0.3)
		local winCenter = (REEL_WIN_INDEX - 1) * (TILE_WIDTH + TILE_GAP) + TILE_WIDTH / 2
		local jitter = (math.random() - 0.5) * TILE_WIDTH * 0.7
		strip.Position = UDim2.fromOffset(center - TILE_WIDTH * 2, 0)
		local spin =
			TweenService:Create(strip, TweenInfo.new(SPIN_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				Position = UDim2.fromOffset(center - winCenter + jitter, 0),
			})
		spin:Play()

		-- A tick every time a tile passes the marker, slightly higher as it slows down
		local lastTile = nil
		local tick = RunService.RenderStepped:Connect(function()
			local tile = math.floor((center - strip.Position.X.Offset) / (TILE_WIDTH + TILE_GAP))
			if tile ~= lastTile then
				lastTile = tile
				Sfx.Play("ReelTick", 0.9 + math.clamp(tile / REEL_WIN_INDEX, 0, 1) * 0.4)
			end
		end)

		-- Anticipation: the window shakes harder and glows brighter as the reel slows down
		local stroke = window.UIStroke :: UIStroke
		local normalThickness = stroke.Thickness
		task.delay(SPIN_TIME * 0.6, function()
			TweenService:Create(stroke, TweenInfo.new(SPIN_TIME * 0.4), { Thickness = normalThickness * 3 }):Play()
			for i = 1, 10 do
				window.Rotation = (if i % 2 == 0 then 1 else -1) * (0.4 + i * 0.08)
				task.wait(0.05)
			end
			window.Rotation = 0
		end)
		spin.Completed:Wait()
		tick:Disconnect()
		task.wait(0.35)
		stroke.Thickness = normalThickness

		-- Reveal
		window.Visible = false
		status.Text = if rarityIndex >= EPIC_INDEX then ball.Rarity:upper() .. "!!" else ""
		status.TextColor3 = rarity.Color
		BallView.Put(reveal.Swatch, ball, { Spin = true })
		reveal.Glow.BackgroundColor3 = rarity.Color
		reveal.Rarity.Text = ball.Rarity:upper()
		reveal.Rarity.TextColor3 = rarity.Color
		reveal.BallName.Text = ball.Name
		reveal.BallName.TextColor3 = if rarityIndex >= EPIC_INDEX then rarity.Color else Color3.new(1, 1, 1)
		if result.IsNew then
			reveal.Info.Text = ('<font color="#5AE66E">NEW!</font>   x%g coins'):format(ball.Multiplier)
		elseif result.PolishLevel then
			-- Duplicate: the ball got polished (+5% of its multiplier per level)
			reveal.Info.Text = ('Duplicate - <font color="#FFE15A">POLISH %d/%d</font>   x%g coins'):format(
				result.PolishLevel,
				Config.Economy.Polish.MaxLevel,
				math.floor(Balls.Multiplier(ball, result.PolishLevel) * 100 + 0.5) / 100
			)
		else
			reveal.Info.Text = ('Fully polished - sold for <font color="#FFC828">+%s coins</font>'):format(
				formatNumber(result.SellCoins)
			)
		end
		if result.FromPity then
			reveal.Info.Text ..= '   <font color="#5AE66E">GUARANTEED!</font>'
		end
		local traits = Balls.DescribeTraits(ball, false, true)
		reveal.Trait.Text = if traits == "" then "No special trait" else traits
		reveal.Visible = true
		continueButton.Visible = false

		local big = rarityIndex >= EPIC_INDEX
		Sfx.Play(if big then "RevealBig" else "Reveal")
		if big then
			UiFx.Confetti(
				opening,
				if rarityIndex >= LEGENDARY_INDEX then 80 else 40,
				{ rarity.Color, Color3.new(1, 1, 1) }
			)
		end
		if rarityIndex >= LEGENDARY_INDEX then
			-- Legendary and Mythic: a second flash and a firework bang
			task.delay(0.4, function()
				UiFx.Flash(rarity.Color, 0.5, 0.6)
				Sfx.Play("Firework")
			end)
		end
		flash.BackgroundColor3 = if big then rarity.Color else Color3.new(1, 1, 1)
		flash.BackgroundTransparency = if big then 0 else 0.5
		TweenService:Create(flash, TweenInfo.new(if big then 0.9 else 0.4), { BackgroundTransparency = 1 }):Play()
		revealScale.Scale = 0.2
		TweenService:Create(
			revealScale,
			TweenInfo.new(if big then 0.8 else 0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
		reveal.Glow.Size = UDim2.fromOffset(120, 120)
		TweenService:Create(reveal.Glow, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {
			Size = UDim2.fromOffset(if big then 260 else 190, if big then 260 else 190),
		}):Play()

		-- Epic and up: the glow keeps pulsing until you continue
		local pulse
		if big then
			pulse = TweenService:Create(
				reveal.Glow,
				TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ BackgroundTransparency = 0.2 }
			)
			task.delay(0.6, function()
				pulse:Play()
			end)
		end

		task.wait(if big then 1.2 else 0.6)
		local continueText = continueButton.Text
		if equipPrompt then
			continueButton.Text = "EQUIP IT!"
			UiFx.Pop(continueButton, 1.25)
		end
		continueButton.Visible = true
		continueButton.Activated:Wait()
		continueButton.Text = continueText
		if equipPrompt then
			equipRemote:FireServer(ball.Id)
			Sfx.Play("StreakUp", 1.2)
		end
		if pulse then
			pulse:Cancel()
			reveal.Glow.BackgroundTransparency = 0.5
		end
		UiFx.Close(reveal)
		task.wait(0.15)
		opening.Visible = false
		strip:ClearAllChildren()
	end
	-- Lets other screens (like the daily reward) play a crate the server already opened
	CrateController.PlayOpening = function(crate, result, equipPrompt: boolean?)
		busy = true
		setOpen(false)
		playOpening(crate, result, equipPrompt)
		busy = false
	end

	-- Free crates (from strikes and Golden Pins) are used before coins on their crate type
	local function hasFree(crate): boolean
		return crate.Id == Config.FreeCrates.CrateId and (player:GetAttribute("FreeCrates") or 0) > 0
	end

	-- backToShop: reopen the shop afterwards (when bought from the shop screen, not the kiosk)
	local function buy(crate, backToShop: boolean?)
		if busy then
			return
		end
		if CrateController.Locked(crate) then
			task.spawn(showToast, (CrateController.LockText(crate)))
			return
		end
		if not hasFree(crate) and (player:GetAttribute("Coins") or 0) < CrateController.Price(crate) then
			task.spawn(showToast, "Not enough coins")
			return
		end
		busy = true
		local firstBought = not hasFree(crate) and (player:GetAttribute("CratesBought") or 0) == 0
		local ok, result = pcall(openCrate.InvokeServer, openCrate, crate.Id)
		if not ok or not result or not result.Ok then
			busy = false
			task.spawn(showToast, if ok and result and result.Error then result.Error else "Try again")
			return
		end
		setOpen(false)
		playOpening(crate, result)
		busy = false
		CrateController.Opened:Fire(crate, result)
		if firstBought and result.IsNew then
			-- The first crate bought with coins: arrows show how to equip its new ball (BALLS button, then EQUIP)
			CollectionBookController.GuideEquip(result.BallId)
			return
		end
		if backToShop ~= false then
			setOpen(true) -- straight back to the shop for the next one
		end
	end
	-- For the lobby kiosk: its buy buttons open a crate right away, its joystick opens the shop screen
	CrateController.Buy = function(crate)
		buy(crate, false)
	end
	CrateController.OpenShop = function()
		setOpen(true)
	end
	CrateController.HasFree = hasFree

	-- Odds screen: every ball a crate can give with its real chance, plus this crate's guarantees (Roblox wants
	-- every outcome and its numeric odds shown; built now so paid packs later are already covered)
	local oddsScreen = Instance.new("Frame")
	oddsScreen.Name = "OddsScreen"
	oddsScreen.AnchorPoint = Vector2.new(0.5, 0.5)
	oddsScreen.Position = UDim2.fromScale(0.5, 0.5)
	oddsScreen.Size = UDim2.new(0.9, 0, 1, -20)
	oddsScreen.BackgroundColor3 = Color3.fromRGB(28, 18, 48)
	oddsScreen.Active = true
	oddsScreen.Visible = false
	oddsScreen.ZIndex = 20
	local oddsSizeLimit = Instance.new("UISizeConstraint")
	oddsSizeLimit.MaxSize = Vector2.new(460, math.huge)
	oddsSizeLimit.Parent = oddsScreen
	local screenCorner = Instance.new("UICorner")
	screenCorner.CornerRadius = UDim.new(0, 14)
	screenCorner.Parent = oddsScreen
	local screenStroke = Instance.new("UIStroke")
	screenStroke.Thickness = 3
	screenStroke.Parent = oddsScreen
	local font = panel.Title.FontFace

	local function oddsText(name: string, props): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.FontFace = font
		l.TextScaled = true
		l.RichText = true
		l.TextColor3 = Color3.new(1, 1, 1)
		l.ZIndex = 21
		for key, value in props do
			(l :: any)[key] = value
		end
		return l
	end

	local oddsTitle = oddsText("Title", { Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -76, 0, 30) })
	oddsTitle.TextXAlignment = Enum.TextXAlignment.Left
	oddsTitle.Parent = oddsScreen
	local oddsClose = Instance.new("TextButton")
	oddsClose.Name = "Close"
	oddsClose.AnchorPoint = Vector2.new(1, 0)
	oddsClose.Position = UDim2.new(1, -10, 0, 8)
	oddsClose.Size = UDim2.fromOffset(40, 40)
	oddsClose.BackgroundColor3 = Color3.fromRGB(255, 70, 110)
	oddsClose.FontFace = font
	oddsClose.Text = "X"
	oddsClose.TextScaled = true
	oddsClose.TextColor3 = Color3.new(1, 1, 1)
	oddsClose.ZIndex = 21
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 10)
	closeCorner.Parent = oddsClose
	oddsClose.Parent = oddsScreen
	local oddsPity = oddsText("Pity", { Position = UDim2.fromOffset(16, 46), Size = UDim2.new(1, -32, 0, 40) })
	oddsPity.TextWrapped = true
	oddsPity.TextColor3 = Color3.fromRGB(200, 190, 230)
	oddsPity.Parent = oddsScreen
	local oddsList = Instance.new("ScrollingFrame")
	oddsList.Name = "List"
	oddsList.Position = UDim2.fromOffset(12, 92)
	oddsList.Size = UDim2.new(1, -24, 1, -102)
	oddsList.BackgroundTransparency = 1
	oddsList.BorderSizePixel = 0
	oddsList.ScrollBarThickness = 6
	oddsList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	oddsList.CanvasSize = UDim2.new()
	oddsList.ZIndex = 21
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 2)
	listLayout.Parent = oddsList
	oddsList.Parent = oddsScreen
	oddsScreen.Parent = panel

	showOdds = function(crate)
		oddsTitle.Text = crate.Name:upper() .. "  ODDS"
		oddsTitle.TextColor3 = crate.Color
		screenStroke.Color = crate.Color
		local pityParts = {}
		for _, row in Balls.PityRows(crate.Id) do
			table.insert(
				pityParts,
				("%s or better guaranteed within %d pulls (%d to go)"):format(row.Rarity, row.After, pullsLeft(row))
			)
		end
		if (player:GetAttribute("CratesBought") or 0) == 0 then
			table.insert(
				pityParts,
				("Your first bought crate: a guaranteed %s"):format(Config.Onboarding.FirstBoughtRarity)
			)
		end
		oddsPity.Text = table.concat(pityParts, "\n")

		for _, child in oddsList:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local owned = Balls.DecodeOwned(player:GetAttribute("OwnedBalls"))
		local order = 0
		local lastRarity = nil
		for _, entry in Balls.CrateBallOdds(crate) do
			local ball = entry.Ball
			local rarity = Balls.GetRarity(ball.Rarity)
			if ball.Rarity ~= lastRarity then
				-- Rarity header with that rarity's total chance
				lastRarity = ball.Rarity
				order += 1
				local header = oddsText(ball.Rarity, {
					LayoutOrder = order,
					Size = UDim2.new(1, -8, 0, 24),
					Text = ("%s  ·  %g%%"):format(ball.Rarity:upper(), crate.Odds[ball.Rarity]),
					TextColor3 = rarity.Color,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
				header.Parent = oddsList
			end
			order += 1
			local row = oddsText(ball.Id, {
				LayoutOrder = order,
				Size = UDim2.new(1, -8, 0, 28),
				Text = ('%s%s  <font color="#%s">%.4g%%</font>'):format(
					ball.Name,
					if owned[ball.Id] then "" else '  <font color="#8C82A0">(new)</font>',
					rarity.Color:ToHex(),
					entry.Chance
				),
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			-- The ball itself, in 3D, at the start of its row
			local rowPad = Instance.new("UIPadding")
			rowPad.PaddingLeft = UDim.new(0, 40)
			rowPad.PaddingTop = UDim.new(0, 4)
			rowPad.PaddingBottom = UDim.new(0, 4)
			rowPad.Parent = row
			local ballView = BallView.New(ball, { Margin = 0.95 })
			ballView.AnchorPoint = Vector2.new(0, 0.5)
			ballView.Position = UDim2.new(0, -32, 0.5, 0)
			ballView.Size = UDim2.fromOffset(28, 28)
			ballView.ZIndex = 22
			ballView.Parent = row
			row.Parent = oddsList
		end
		oddsList.CanvasPosition = Vector2.zero
		UiFx.Open(oddsScreen)
	end
	oddsClose.Activated:Connect(function()
		UiFx.Close(oddsScreen)
	end)

	-- One card per crate, odds shown straight from Config
	for order, crate in Config.Crates do
		local card = cardTemplate:Clone()
		card.Name = crate.Id
		card.LayoutOrder = order
		card.Visible = true
		card.CrateName.Text = crate.Name:upper()
		card.CrateName.TextColor3 = crate.Color
		card.UIStroke.Color = crate.Color

		-- Rows share the odds box evenly (20px tall at most) so every rarity fits on small screens too
		local rowTemplate = card.OddsRowTemplate
		rowTemplate.Size = UDim2.new(1, 0, 1 / #Config.Rarities, -2)
		local rowLimit = Instance.new("UISizeConstraint")
		rowLimit.MaxSize = Vector2.new(math.huge, 20)
		rowLimit.Parent = rowTemplate
		for _, label in { rowTemplate.Rarity, rowTemplate.Chance } do
			local textLimit = Instance.new("UITextSizeConstraint")
			textLimit.MaxTextSize = label.TextSize
			textLimit.Parent = label
			label.TextScaled = true
		end
		for index, rarity in Config.Rarities do
			local row = rowTemplate:Clone()
			row.Name = rarity.Name
			row.LayoutOrder = index
			row.Visible = true
			row.Rarity.Text = rarity.Name
			row.Rarity.TextColor3 = rarity.Color
			row.Chance.Text = ("%g%%"):format(crate.Odds[rarity.Name] or 0)
			row.Chance.TextColor3 = rarity.Color
			row.Parent = card.Odds
		end
		rowTemplate:Destroy()

		-- Room under the odds for this crate's guarantee line, and an ODDS button for every ball's chance
		card.Odds.Size = UDim2.new(1, -28, 1, -136)
		local pityLine = Instance.new("TextLabel")
		pityLine.Name = "PityLine"
		pityLine.BackgroundTransparency = 1
		pityLine.AnchorPoint = Vector2.new(0, 1)
		pityLine.Position = UDim2.new(0, 12, 1, -70)
		pityLine.Size = UDim2.new(1, -24, 0, 22)
		pityLine.FontFace = card.CrateName.FontFace
		pityLine.TextScaled = true
		pityLine.RichText = true
		pityLine.TextColor3 = Color3.fromRGB(200, 190, 230)
		pityLine.Parent = card
		local function refreshPityLine()
			local parts = {}
			for _, row in Balls.PityRows(crate.Id) do
				table.insert(
					parts,
					('<font color="#%s">%s+</font> in %d'):format(
						Balls.GetRarity(row.Rarity).Color:ToHex(),
						row.Rarity:upper(),
						pullsLeft(row)
					)
				)
			end
			pityLine.Text = table.concat(parts, "  ·  ")
		end
		for _, row in Balls.PityRows(crate.Id) do
			player:GetAttributeChangedSignal("Pity_" .. row.Key):Connect(refreshPityLine)
		end
		refreshPityLine()

		local oddsButton = Instance.new("TextButton")
		oddsButton.Name = "OddsButton"
		oddsButton.AnchorPoint = Vector2.new(1, 0)
		oddsButton.Position = UDim2.new(1, -8, 0, 8)
		oddsButton.Size = UDim2.fromOffset(52, 24)
		oddsButton.BackgroundColor3 = crate.Color
		oddsButton.FontFace = card.CrateName.FontFace
		oddsButton.Text = "ODDS"
		oddsButton.TextScaled = true
		oddsButton.TextColor3 = Color3.fromRGB(25, 15, 40)
		local oddsCorner = Instance.new("UICorner")
		oddsCorner.CornerRadius = UDim.new(0, 6)
		oddsCorner.Parent = oddsButton
		oddsButton.Parent = card
		card.CrateName.Size = UDim2.new(1, -76, 0, 26)
		oddsButton.Activated:Connect(function()
			showOdds(crate)
		end)

		local buyButton = card.Buy :: TextButton
		buyButton.Price.Text = formatNumber(CrateController.Price(crate))
		buyButton.Activated:Connect(function()
			buy(crate)
		end)

		local coinIcon = buyButton:FindFirstChild("Coin") or buyButton:FindFirstChild("Icon")
		-- The first crate you buy is on discount: a pink tag over the button and the old price crossed out
		local dealTag = Instance.new("TextLabel")
		dealTag.Name = "DealTag"
		dealTag.AnchorPoint = Vector2.new(0.5, 1)
		dealTag.Position = UDim2.new(0.5, 0, 0, -4)
		dealTag.Size = UDim2.new(1, 0, 0, 20)
		dealTag.BackgroundColor3 = Color3.fromRGB(255, 70, 170)
		dealTag.FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
		dealTag.TextScaled = true
		dealTag.TextColor3 = Color3.new(1, 1, 1)
		dealTag.ZIndex = buyButton.ZIndex + 2
		dealTag.Visible = false
		local dealCorner = Instance.new("UICorner")
		dealCorner.CornerRadius = UDim.new(1, 0)
		dealCorner.Parent = dealTag
		local dealStroke = Instance.new("UIStroke")
		dealStroke.Color = Color3.fromHex("06060F")
		dealStroke.Thickness = 1.5
		dealStroke.Parent = dealTag
		dealTag.Parent = buyButton
		buyButton.Price.RichText = true
		local function refreshAfford()
			local free = hasFree(crate)
			local canAfford = free or (player:GetAttribute("Coins") or 0) >= CrateController.Price(crate)
			local discount = not free and CrateController.Discount(crate)
			buyButton.BackgroundColor3 = if canAfford then CAN_AFFORD else CANT_AFFORD
			dealTag.Visible = discount ~= nil
			pityLine.Visible = discount == nil -- the deal tag takes its spot until the first crate is bought
			dealTag.Text = if discount then ("FIRST CRATE %d%% OFF!"):format(discount) else ""
			buyButton.Price.Text = if free
				then ("OPEN FREE (%d)"):format(player:GetAttribute("FreeCrates"))
				elseif discount then ('<s><font transparency="0.45">%s</font></s> %s'):format(
					formatNumber(crate.Price),
					formatNumber(CrateController.Price(crate))
				)
				else formatNumber(CrateController.Price(crate))
			if coinIcon and coinIcon:IsA("GuiObject") then
				coinIcon.Visible = not free
			end
		end
		player:GetAttributeChangedSignal("Coins"):Connect(refreshAfford)
		player:GetAttributeChangedSignal("FreeCrates"):Connect(refreshAfford)
		player:GetAttributeChangedSignal("CratesBought"):Connect(refreshAfford)
		refreshAfford()

		-- Blacked out with "UNLOCKS IN <ZONE>" until its zone opens
		local lock = Instance.new("TextButton") -- a button, so taps on it don't reach the card underneath
		lock.Name = "ZoneLock"
		lock.AutoButtonColor = false
		lock.Text = ""
		lock.Size = UDim2.fromScale(1, 1)
		lock.BackgroundColor3 = Color3.fromRGB(4, 3, 10)
		lock.BackgroundTransparency = 0.06
		lock.ZIndex = 10
		local lockCorner = card:FindFirstChildOfClass("UICorner")
		if lockCorner then
			lockCorner:Clone().Parent = lock
		end
		local function lockLabel(name: string, text: string, color: Color3, y: number, height: number): TextLabel
			local l = Instance.new("TextLabel")
			l.Name = name
			l.BackgroundTransparency = 1
			l.AnchorPoint = Vector2.new(0.5, 0.5)
			l.Position = UDim2.fromScale(0.5, y)
			l.Size = UDim2.new(0.86, 0, 0, height)
			l.FontFace = card.CrateName.FontFace
			l.TextScaled = true
			l.TextWrapped = true
			l.Text = text
			l.TextColor3 = color
			l.ZIndex = 11
			l.Parent = lock
			return l
		end
		local lockTitle, lockSub = CrateController.LockText(crate)
		lockLabel("Padlock", "🔒", Color3.new(1, 1, 1), 0.3, 54)
		lockLabel("CrateName", crate.Name:upper(), Color3.fromRGB(90, 85, 110), 0.47, 22)
		lockLabel("Title", lockTitle, crate.Color, 0.62, 40)
		lockLabel("Sub", lockSub, Color3.fromRGB(170, 160, 200), 0.78, 18)
		lock.Parent = card
		local function refreshLock()
			lock.Visible = CrateController.Locked(crate)
		end
		player:GetAttributeChangedSignal("RankLevel"):Connect(refreshLock)
		refreshLock()

		card.Parent = cards
	end

	player:GetAttributeChangedSignal("CratesBought"):Connect(refreshPity)
	refreshPity()

	panel:WaitForChild("Close").Activated:Connect(function()
		setOpen(false)
	end)
	panel.Active = true -- taps on the panel don't fall through to the throw meter
	panel.Visible = false
	opening.Visible = false
end

return CrateController
