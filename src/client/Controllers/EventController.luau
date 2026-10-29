-- The surprise layer on screen: the lane modifier banner and timer, the "next goal" bar (with the new-player
-- guide: REBIRTH to open the next zone, then a gold beam to its door until you walk in, owner 2026-10-27),
-- and the big popups for Golden Pins, "LUCKY!", bonus gems, level-ups, free crates and arriving in a zone.
-- The UI itself (StarterGui.EventUI) is built in Studio; this script fills it in and animates it.
-- Everything shown comes from attributes and throw results the server sends.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Currency = require(Shared.Modules.Currency)
local Balls = require(Shared.Modules.Balls)
local LaneUtil = require(Shared.Modules.LaneUtil)
local Modifiers = require(Shared.Modules.Modifiers)
local PowerLevels = require(Shared.Modules.PowerLevels)
local Rebirth = require(Shared.Modules.Rebirth)
local Zones = require(Shared.Modules.Zones)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local TraitFx = require(Modules.TraitFx)
local Sfx = require(Modules.Sfx)
local HudKit = require(Modules.HudKit)
local MomentKit = require(Modules.MomentKit)
local K = HudKit.C

local GOLD = Config.GoldenPin.Color
local CRATE_COLOR = Color3.fromRGB(60, 230, 255)
local POWER_COLOR = Color3.fromRGB(255, 43, 214)
local REBIRTH_COLOR = Color3.fromRGB(125, 255, 60) -- the REBIRTH button's lime

local short = Currency.Format -- Config.Numbers

-- Lane modifier pill look per modifier (owner's HUD Kit): icon and colour
local MODIFIER_LOOKS = {
	MovingPins = { Icon = "Coin", Color = K.Gold, Paint = "Gold" },
	DoubleCoins = { Icon = "Coins2", Color = K.Lime, Paint = "Lime" },
	GiantPins = { Icon = "Pin", Color = K.Pink, Paint = "Pink" },
	BonusGems = { Icon = "Gem", Color = K.Cyan, Paint = "Cyan" },
}

-- Restyles the Studio pill and goal bar in the HUD Kit look, keeping the children EventController fills in
-- (ModName, Timer; Fill, Label). Returns the pill's colour ring, its icon, the goal's icon, and a function that
-- switches the goal between "in progress" and "ready".
local function kitPieces(pill: Frame, bar: Frame)
	-- Pill: dark card, a 2 px ring inside in the modifier's colour, icon, name, time
	for _, child in pill:GetChildren() do
		if child:IsA("UICorner") or child:IsA("UIStroke") or child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	pill.BackgroundTransparency = 1
	local card = HudKit.Block(pill, { Name = "Card", Paint = "Card", Shine = 0, Lip = 4 })
	card.Holder.Size = UDim2.fromScale(1, 1)
	card.Holder.ZIndex = 0
	local ring = Instance.new("UIStroke")
	ring.Name = "Ring"
	ring.Thickness = 2
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local ringFrame = Instance.new("Frame")
	ringFrame.Name = "RingFrame"
	ringFrame.BackgroundTransparency = 1
	ringFrame.Position = UDim2.fromOffset(5, 5)
	ringFrame.Size = UDim2.new(1, -10, 1, -10)
	ringFrame.ZIndex = 3
	ringFrame.Parent = pill
	local ringCorner = HudKit.Corner(ringFrame, 16)
	ring.Parent = ringFrame
	local pillIcon = HudKit.Image(pill, "Coin", 30)
	pillIcon.AnchorPoint = Vector2.new(0, 0.5)
	pillIcon.ZIndex = 5
	local name = pill:WaitForChild("ModName") :: TextLabel
	local timer = pill:WaitForChild("Timer") :: TextLabel
	for _, label in { name, timer } do
		for _, child in label:GetChildren() do
			child:Destroy()
		end
		label.TextScaled = false
		label.ZIndex = 5
		label.AnchorPoint = Vector2.zero
		HudKit.Outline(label, K.Ink, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	end
	name.FontFace = HudKit.Head
	name.TextXAlignment = Enum.TextXAlignment.Left
	timer.FontFace = HudKit.Num
	timer.TextColor3 = K.White
	timer.TextXAlignment = Enum.TextXAlignment.Right

	-- Goal bar: card, crate (or bolt / gift) over the left end, text, a thin purple bar
	for _, child in bar:GetChildren() do
		if child:IsA("UICorner") or child:IsA("UIStroke") then
			child:Destroy()
		end
	end
	bar.BackgroundTransparency = 1
	local goalCard = HudKit.Block(bar, { Name = "Card", Paint = "Card", Shine = 0, Lip = 5 })
	goalCard.Holder.Size = UDim2.fromScale(1, 1)
	goalCard.Holder.ZIndex = 0
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = K.Panel
	track.ZIndex = 4
	track.Parent = bar
	local trackCorner = HudKit.Corner(track, 4)
	HudKit.Outline(track, K.Ink, 2)
	local fill = bar:WaitForChild("Fill") :: Frame
	fill.Parent = track
	fill.BackgroundColor3 = K.Purple
	fill.ZIndex = 5
	local fillCorner = fill:FindFirstChildOfClass("UICorner") or HudKit.Corner(fill, 4)
	local label = bar:WaitForChild("Label") :: TextLabel
	for _, child in label:GetChildren() do
		child:Destroy()
	end
	label.FontFace = HudKit.Head
	label.TextScaled = false
	label.TextColor3 = K.White
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.AnchorPoint = Vector2.zero
	label.ZIndex = 5
	HudKit.Outline(label, K.Ink, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	local goalIcon = HudKit.Image(bar, "Crate", 56)
	goalIcon.ZIndex = 6

	local ready = false
	local phone = false
	local function arrange()
		local p = phone
		-- pill
		card:SetRadius(if p then 15 else 21)
		ringCorner.CornerRadius = UDim.new(0, if p then 10 else 16)
		ringFrame.Position = UDim2.fromOffset(if p then 4 else 5, if p then 4 else 5)
		ringFrame.Size = UDim2.new(1, if p then -8 else -10, 1, if p then -8 else -10)
		local iconSize = if p then 22 else 30
		pillIcon.Size = UDim2.fromOffset(iconSize, iconSize)
		pillIcon.Position = UDim2.new(0, if p then 3 else 5, 0.5, -2)
		local textLeft = iconSize + (if p then 7 else 11)
		name.Position = UDim2.fromOffset(textLeft, 0)
		name.Size = UDim2.new(1, -textLeft - (if p then 44 else 60), 1, -3)
		name.TextSize = if p then 12 else 17
		timer.Position = UDim2.new(1, if p then -50 else -64, 0, 0)
		timer.Size = UDim2.new(0, if p then 40 else 50, 1, -3)
		timer.TextSize = if p then 13 else 17
		-- goal
		goalCard:SetRadius(if p then 11 else 16)
		goalCard:SetLip(if p then 3 else 5)
		local goalIconSize = if p then 38 else 56
		goalIcon.Size = UDim2.fromOffset(goalIconSize, goalIconSize)
		goalIcon.Position = UDim2.fromOffset(if p then -14 else -18, if p then -1 else -2)
		local left = if p then 28 else 44
		local right = if p then 7 else 10
		local textSize = if ready then (if p then 14 else 20) else (if p then 9 else 13)
		label.TextSize = textSize
		label.TextXAlignment = if ready then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
		if ready then
			label.Position = UDim2.fromOffset(left, 0)
			label.Size = UDim2.new(1, -left - right, 1, if p then -3 else -5)
		else
			local barHeight = if p then 8 else 12
			local total = textSize + (if p then 3 else 5) + barHeight
			local height = (if p then 36 else 54) - (if p then 3 else 5)
			local top = math.floor((height - total) / 2 + 0.5)
			label.Position = UDim2.fromOffset(left, top)
			label.Size = UDim2.new(1, -left - right, 0, textSize)
			track.Position = UDim2.fromOffset(left, top + textSize + (if p then 3 else 5))
			track.Size = UDim2.new(1, -left - right, 0, barHeight - 4)
			trackCorner.CornerRadius = UDim.new(0, (barHeight - 4) / 2)
			fillCorner.CornerRadius = UDim.new(0, (barHeight - 4) / 2)
		end
		track.Visible = not ready
	end
	HudKit.OnLayout(function(isPhone)
		phone = isPhone
		arrange()
	end)
	HudKit.Place(pill, "Modifier")
	HudKit.Place(bar, "Goal")

	-- Ready: purple face with a glow, one big line
	local function setReady(on: boolean)
		if on == ready then
			return
		end
		ready = on
		goalCard:Paint(if on then "Purple" else "Card")
		goalCard:SetGlow(if on then K.Purple else nil)
		goalCard.Shine.Visible = on
		arrange()
	end
	return ring, pillIcon, goalIcon, setReady
end

local player = Players.LocalPlayer

local EventController = {}

function EventController:Start()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("EventUI")
	local pill = gui:WaitForChild("ModifierPill") :: Frame
	local banner = gui:WaitForChild("Banner") :: Frame
	local bar = gui:WaitForChild("AlmostBar") :: Frame
	local barScale = bar:WaitForChild("UIScale") :: UIScale
	local pillRing, pillIcon, goalIcon, setGoalReady = kitPieces(pill, bar)
	-- The old Studio popup text and modifier banner stay in EventUI but are never shown: the kit's lane popup and
	-- slam banner (MomentKit, UI pass batch 3) replace them
	gui:WaitForChild("Popup").Visible = false
	banner.Visible = false
	local kitLayer = MomentKit.Layer("LanePopupUI", 44)
	local kitPopup = MomentKit.Popup(kitLayer)
	local kitBanner = MomentKit.Banner(kitLayer, 0.3)

	-- Popups: one at a time, queued so two surprises on one throw both get their moment
	local queue = {}
	local showing = false
	local holdPopupsUntil = 0 -- the LEVEL UP burst has the centre until then
	local function runQueue()
		if showing then
			return
		end
		showing = true
		while os.clock() < holdPopupsUntil do
			task.wait(0.1)
		end
		while #queue > 0 do
			task.wait(kitPopup(table.remove(queue, 1)))
		end
		showing = false
	end
	-- icon = a MomentKit.IconImage name ("GoldenPin", "Hud:Crate")
	local function showPopup(text: string, color: Color3, sub: string?, big: boolean?, subColor: Color3?, icon: string?)
		table.insert(queue, { Text = text, Color = color, Sub = sub, Big = big, SubColor = subColor, Icon = icon })
		task.spawn(runQueue)
	end

	-- Lane modifier: banner when it changes, pill with the time left
	local function onModifier(announce: boolean)
		local modifier = Modifiers.Current()
		local home = HudKit.Spot("Modifier")
		if not modifier then
			-- Out: slides off to the right (0.2 s)
			if pill.Visible then
				local out =
					TweenService:Create(pill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						Position = home + UDim2.fromOffset(260, 0),
					})
				out:Play()
				out.Completed:Once(function()
					if not Modifiers.Current() then
						pill.Visible = false
						pill.Position = home
					end
				end)
			end
			return
		end
		local look = MODIFIER_LOOKS[modifier.Id] or { Icon = "Clover", Color = modifier.Color }
		pill.ModName.Text = modifier.Name
		pill.ModName.TextColor3 = look.Color
		pillRing.Color = look.Color
		pillIcon.Image = HudKit.Icon(look.Icon)
		-- In: slides in from the right (0.3 s Back Out)
		pill.Visible = true
		pill.Position = home + UDim2.fromOffset(260, 0)
		TweenService:Create(pill, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = home,
		}):Play()
		if not announce then
			return
		end
		-- Announce: the kit's slam banner in the modifier's colour, its icon on the disc, what it does on the chip
		kitBanner(modifier.Name:upper(), look.Paint or "Gold", modifier.Text:upper(), "Hud:" .. look.Icon, 3)
		Sfx.Play("StreakUp", 0.9, 1.2)
	end
	Workspace:GetAttributeChangedSignal("LaneModifier"):Connect(function()
		onModifier(true)
	end)
	onModifier(false)

	RunService.Heartbeat:Connect(function()
		if pill.Visible then
			local left =
				math.ceil(math.max(0, (Workspace:GetAttribute("LaneModifierEnds") or 0) - Workspace:GetServerTimeNow()))
			pill.Timer.Text = ("%d:%02d"):format(left // 60, left % 60)
		end
	end)

	-- First crate goal (Config.Onboarding.FirstCrateGoal): when it's the goal and affordable, a beam runs from the
	-- player to Rizzo's buy pad (RizzoController's PromptPoint), or to the crate's kiosk station if Rizzo is missing
	local firstCrate = Balls.GetCrate(Config.Onboarding.FirstCrateGoal)
	local function guideTarget(): BasePart?
		local rizzo = Workspace:FindFirstChild("BackAlley")
			and Workspace.BackAlley:FindFirstChild("RizzoStand")
			and Workspace.BackAlley.RizzoStand:FindFirstChild("PromptPoint")
		if rizzo and Config.Rizzo.CrateId == Config.Onboarding.FirstCrateGoal then
			return rizzo :: BasePart
		end
		local station = Workspace:FindFirstChild("Hub")
			and Workspace.Hub:FindFirstChild("CrateShop")
			and Workspace.Hub.CrateShop:FindFirstChild("Stations")
			and Workspace.Hub.CrateShop.Stations:FindFirstChild(Config.Onboarding.FirstCrateGoal)
		return station and station:FindFirstChild("BuyButton") :: BasePart?
	end
	local guide: { Beams: { Beam }, From: Attachment, Target: BasePart }? = nil
	local function setGuide(stationButton: BasePart?)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not stationButton or not root then
			if guide then
				for _, beam in guide.Beams do
					beam:Destroy()
				end
				guide.From:Destroy()
				guide = nil
			end
			return
		end
		if guide and guide.From.Parent == root and guide.Target == stationButton then
			return
		end
		setGuide(nil)
		local from = Instance.new("Attachment")
		from.Name = "CrateGuideFrom"
		from.Position = Vector3.new(0, -1.5, 0)
		from.Parent = root
		local to = stationButton:FindFirstChild("CrateGuideTo") :: Attachment?
		if not to then
			to = Instance.new("Attachment")
			to.Name = "CrateGuideTo"
			to.Parent = stationButton
		end
		-- A soft gold band with sparkles running along it toward the crate
		local beams = {}
		for i = 1, 2 do
			local beam = Instance.new("Beam")
			beam.Name = "CrateGuide"
			beam.Attachment0 = from
			beam.Attachment1 = to
			beam.Color = ColorSequence.new(GOLD)
			beam.LightEmission = 1
			beam.FaceCamera = true
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
		guide = { Beams = beams, From = from, Target = stationButton }
	end
	local wantGuide: BasePart? = nil
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		setGuide(wantGuide)
	end)

	-- Walking to a newly opened zone (owner 2026-10-27: the first trip is on foot, so new players learn where the
	-- door is). Until you have stood inside it (save ZoneVisited), the beam leads to the next door on the way:
	-- Back Alley -> lobby door -> Main Street Lanes door -> rooftop elevator. A bouncing arrow sits on that door.
	local doorFolder = Instance.new("Folder")
	doorFolder.Name = "ZoneGuide"
	doorFolder.Parent = Workspace
	local doors: { [number]: BasePart } = {}
	local function gateOf(zone: number)
		for _, gate in Config.Zones.Gated do
			if gate.Zone == zone then
				return gate
			end
		end
		return nil
	end
	local function door(zone: number): BasePart?
		if doors[zone] then
			return doors[zone]
		end
		local gate = gateOf(zone)
		if not gate or not gate.Walls[1] then
			return nil
		end
		local part = Instance.new("Part")
		part.Name = "Door" .. zone
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.Size = Vector3.one
		part.Position = gate.Walls[1].Center
		-- the kit's world marker (UI pass batch 3): the zone's name on a navy pill in its colour, a bobbing gold arrow
		local sign = MomentKit.WorldMarker(Zones.Name(zone):upper(), gate.WallColor)
		sign.Name = "Arrow"
		sign.StudsOffset = Vector3.new(0, 7, 0)
		sign.Enabled = false
		sign.Parent = part
		part.Parent = doorFolder
		doors[zone] = part
		return part
	end
	-- The zone the walk guide is leading to (the first open zone not visited yet), or nil
	local function walkZone(): number?
		local visited = player:GetAttribute("ZoneVisited") or 1
		local open = Zones.Highest(player:GetAttribute("ZonesOpen"))
		return if open > visited then visited + 1 else nil
	end
	-- The door to head for now: the next zone's door from the zone you stand in
	local function walkDoor(zone: number): BasePart?
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return nil
		end
		local here = 1
		for _, gate in Config.Zones.Gated do
			if Zones.InArea(gate.Area, root.Position) then
				here = math.max(here, gate.Zone)
			end
		end
		return if here < zone then door(here + 1) else nil
	end

	-- "Next goal": always shows the closest goal (rank progress lives in the HUD rank bar):
	-- the next Power Level, the first-3-minutes gift crate, the first crate to buy (until one is bought),
	-- or the next free crate (ties go to the first one)
	local pulse = TweenService:Create(
		barScale,
		TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.04 } -- HUD Kit: 1 <-> 1.04, 0.8 s
	)
	local pulsing = false
	local calledOut = false
	local rebirthCalledOut = false
	local function refreshBar()
		local options = {}

		-- First trip to a newly opened zone: always the goal until you walk in
		local walking = walkZone()
		if walking then
			table.insert(options, {
				Progress = 1,
				Priority = 2,
				Text = ("WALK TO %s: FOLLOW THE GOLD BEAM!"):format(Zones.Name(walking):upper()),
				Color = GOLD,
				Icon = "Rebirth",
				Door = walking,
			})
		end

		-- Rebirth (it opens the zones): ready = always the goal; one that opens a zone wins once you have its level
		local rebirth = Config.Economy.Rebirth
		if rebirth.Enabled and (player:GetAttribute("Onboarding") or 3) >= 3 then
			local done = player:GetAttribute("Rebirths") or 0
			local needLevel, cost = Rebirth.Level(done), Rebirth.Cost(done)
			local level = player:GetAttribute("RankLevel") or 1
			local coins = player:GetAttribute("Coins") or 0
			local coinPart = math.min(coins / math.max(cost, 1), 1)
			local levelPart = if level >= needLevel then 1 else (level - 1) / math.max(needLevel - 1, 1)
			local progress = math.min(coinPart, levelPart)
			local opens = Rebirth.OpensZone(done)
			local reward = if opens then ("OPENS %s"):format(Zones.Name(opens):upper()) else "MORE COINS FOREVER"
			table.insert(options, {
				Progress = progress,
				Priority = if progress >= 1 or (opens and levelPart >= 1) then 1 else 0,
				Text = if progress >= 1
					then ("REBIRTH NOW: %s!"):format(reward)
					elseif levelPart < 1 then ("NEXT: LEVEL %d TO REBIRTH (%s)"):format(needLevel, reward)
					else ("NEXT: REBIRTH (%s)  %s / %s"):format(reward, short(coins), short(cost)),
				Color = REBIRTH_COLOR,
				Icon = "Rebirth",
				RebirthReady = progress >= 1 and done == 0,
			})
		end

		local nextLevel = PowerLevels.Next(player:GetAttribute("PowerLevel") or 1)
		if nextLevel then
			local coins = player:GetAttribute("Coins") or 0
			table.insert(options, {
				Progress = math.min(coins / math.max(nextLevel.Price, 1), 1),
				Text = if coins >= nextLevel.Price
					then ("NEXT: BUY POWER LV %d NOW!"):format(nextLevel.Level)
					else ("NEXT: POWER LV %d  %s / %s"):format(
						nextLevel.Level,
						short(coins),
						short(nextLevel.Price)
					),
				Color = POWER_COLOR,
				Icon = "Bolt",
			})
		end

		local onboard = Config.Onboarding
		if onboard.Enabled and (player:GetAttribute("Onboarding") or 3) <= 1 then
			local throws = player:GetAttribute("OnboardThrows") or 0
			local giftLeft = math.max(onboard.GiftAfterThrows - throws, 1)
			table.insert(options, {
				Progress = throws / onboard.GiftAfterThrows,
				Text = ("FREE GIFT CRATE IN %d THROW%s"):format(giftLeft, if giftLeft == 1 then "" else "S"),
				Color = GOLD,
				Icon = "GiftPink",
			})
		end

		if firstCrate and (player:GetAttribute("CratesBought") or 0) == 0 then
			local coins = player:GetAttribute("Coins") or 0
			local price = Balls.CratePrice(firstCrate, 0) -- the first bought crate's price (on discount)
			local off = if price < firstCrate.Price
				then (" %d%% OFF"):format(math.floor((1 - price / firstCrate.Price) * 100 + 0.5))
				else ""
			table.insert(options, {
				Progress = math.min(coins / math.max(price, 1), 1),
				Text = if coins >= price
					then if off ~= "" then ("GO SEE RIZZO: FIRST CRATE%s!"):format(off) else "GO SEE RIZZO: NEW BALL!"
					else ("NEXT: NEW BALL (%s%s)  %s / %s"):format(
						firstCrate.Name:upper(),
						off,
						short(coins),
						short(price)
					),
				Color = GOLD,
				Icon = "Crate",
				Guide = coins >= price,
			})
		end

		local per = Config.FreeCrates.ThrowsPerCrate
		local throws = player:GetAttribute("CrateStrikes") or 0
		local left = per - throws
		table.insert(options, {
			Progress = throws / per,
			Text = ("FREE CRATE IN %d THROW%s"):format(left, if left == 1 then "" else "S"),
			Color = CRATE_COLOR,
			Icon = "Crate",
		})

		local best = options[1]
		for _, option in options do
			local priority, bestPriority = option.Priority or 0, best.Priority or 0
			if priority > bestPriority or (priority == bestPriority and option.Progress > best.Progress) then
				best = option
			end
		end
		-- The first rebirth ready: a big callout pointing at the REBIRTH button, once a session
		if best.RebirthReady and not rebirthCalledOut then
			rebirthCalledOut = true
			showPopup(
				"REBIRTH IS READY!",
				REBIRTH_COLOR,
				("TAP REBIRTH AT THE TOP TO OPEN %s"):format(Zones.Name(Rebirth.OpensZone(0) or 2):upper()),
				true,
				nil,
				"Hud:Rebirth"
			)
		end
		-- The moment the first crate is the goal and affordable: a big callout pointing at Rizzo, once a session
		local guideNow = best.Guide == true
		if guideNow and not wantGuide and not calledOut then
			calledOut = true
			showPopup("RIZZO HAS A CRATE FOR YOU!", GOLD, "FOLLOW THE GOLD BEAM TO HIS CART", true, nil, "Hud:Crate")
		end
		-- Rizzo draws his own beam (RizzoController, same moment as his "!"); this one is only the kiosk fallback.
		-- Walking to a new zone: the beam leads to the next door on the way, with its arrow on.
		local target: BasePart? = nil
		if best.Door then
			target = walkDoor(best.Door)
		elseif guideNow and not (guideTarget() and guideTarget().Name == "PromptPoint") then
			target = guideTarget()
		end
		for _, part in doors do
			(part:FindFirstChild("Arrow") :: BillboardGui).Enabled = part == target
		end
		wantGuide = target
		setGuide(wantGuide)
		-- Ready (the goal is reached: buy it / go get it): the purple READY look with the text big
		setGoalReady(best.Progress >= 1)
		bar.Label.Text = best.Text
		goalIcon.Image = HudKit.Icon(best.Icon or "Crate")
		local fill = bar:FindFirstChild("Fill", true) :: Frame
		TweenService:Create(fill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(math.clamp(best.Progress, 0.04, 1), 1),
		}):Play()

		local close = best.Progress >= Config.AlmostThere.PulseAt
		if close and not pulsing then
			pulse:Play()
		elseif not close and pulsing then
			pulse:Cancel()
			barScale.Scale = 1
		end
		pulsing = close
	end
	for _, key in
		{
			"CrateStrikes",
			"Coins",
			"PowerLevel",
			"Onboarding",
			"OnboardThrows",
			"CratesBought",
			"RankLevel",
			"Rebirths",
			"ZonesOpen",
			"ZoneVisited",
		}
	do
		player:GetAttributeChangedSignal(key):Connect(refreshBar)
	end
	refreshBar()
	-- While walking to a new zone, the beam moves on to the next door as you pass through each one
	task.spawn(function()
		while true do
			task.wait(0.5)
			if walkZone() then
				refreshBar()
			end
		end
	end)

	-- Rebirth teaser (batch B2, Config.Onboarding.RebirthTeaserAt): once a session, a player who has never rebirthed
	-- learns what it gives and what it still needs; RebirthController shows its TAP arrow while RebirthTeaser is on
	local teaserAt = Config.Onboarding.RebirthTeaserAt
	if teaserAt and Config.Economy.Rebirth.Enabled then
		task.spawn(function()
			local due = os.clock() + teaserAt
			while true do
				task.wait(1)
				if (player:GetAttribute("Rebirths") or 0) > 0 then
					return
				end
				if os.clock() >= due and (player:GetAttribute("Onboarding") or 3) >= 3 then
					local needLevel, cost = Rebirth.Level(0), Rebirth.Cost(0)
					local level = player:GetAttribute("RankLevel") or 1
					local coins = player:GetAttribute("Coins") or 0
					local hasLevel, hasCoins = level >= needLevel, Currency.CanAfford(coins, cost)
					if hasLevel and hasCoins then
						return -- ready: REBIRTH IS READY! says it
					end
					local needs = if not hasLevel and not hasCoins
						then ("LEVEL %d + %s COINS"):format(needLevel, short(cost))
						elseif not hasLevel then ("REACH LEVEL %d"):format(needLevel)
						else ("%s MORE COINS"):format(short(cost - coins))
					local zone = Zones.Name(Rebirth.OpensZone(0) or 2):upper()
					showPopup(
						"REBIRTH = NEW ZONE + PETS!",
						REBIRTH_COLOR,
						("%s TO OPEN %s  ·  REBIRTH BUTTON AT THE TOP"):format(needs, zone),
						true,
						nil,
						"Hud:Rebirth"
					)
					Sfx.Play("StreakUp", 1, 0.8)
					player:SetAttribute("RebirthTeaser", true)
					task.wait(Config.Onboarding.RebirthTeaserArrow or 8)
					player:SetAttribute("RebirthTeaser", nil)
					return
				end
			end
		end)
	end

	-- Walked into a new zone for the first time: a welcome popup
	local visitedShown = player:GetAttribute("ZoneVisited") or 1
	player:GetAttributeChangedSignal("ZoneVisited"):Connect(function()
		local visited = player:GetAttribute("ZoneVisited") or 1
		if visited > visitedShown then
			local gate = gateOf(visited)
			showPopup(
				("WELCOME TO %s!"):format(Zones.Name(visited):upper()),
				if gate then gate.WallColor else GOLD,
				"STEP ON ANY OPEN LANE TO CLAIM IT",
				true,
				nil,
				"Zone"
			)
			Sfx.Play("RevealBig", 1)
		end
		visitedShown = math.max(visitedShown, visited)
	end)

	-- Free crates: a popup when one is earned (they wait at Rizzo's cart and the Crate Shop kiosk, plaque shows FREE xN)
	local freeCrates = player:GetAttribute("FreeCrates") or 0
	local function refreshBadge()
		local count = player:GetAttribute("FreeCrates") or 0
		if count > freeCrates then
			showPopup("FREE CRATE!", K.Pink, "OPEN IT AT RIZZO'S CART", true, nil, "Hud:Crate")
			Sfx.Play("RevealBig", 1.1)
		end
		freeCrates = count
	end
	player:GetAttributeChangedSignal("FreeCrates"):Connect(refreshBadge)
	refreshBadge()

	-- Rank level-up inside a tier (a new tier gets the full rank-up screen instead): the kit's LEVEL UP burst.
	-- Popups wait for it, so a free crate from the same level shows right after.
	local levelUp = MomentKit.LevelUp()
	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("LevelUp").OnClientEvent:Connect(function(data)
		levelUp(data.Level, data.Gems, player:GetAttribute("Rank") or 1)
		holdPopupsUntil = os.clock() + 2.9
		Sfx.Play("RankUp", 1.15, 0.7)
	end)

	-- Golden Pin on your lane: a heads-up when it appears ("LUCKY!" if your ball's trait made it happen)
	local function watchLane(lane: Model)
		lane:GetAttributeChangedSignal("GoldenPin"):Connect(function()
			if lane:GetAttribute("OwnerId") ~= player.UserId then
				return
			end
			local pin = lane:GetAttribute("GoldenPin") or 0
			if pin == 0 then
				return
			end
			local lucky = lane:GetAttribute("GoldenLucky") == true
			local luckyTrait = Balls.GetTrait("Lucky")
			if lucky and luckyTrait then
				TraitFx.Lucky(lane) -- clover over the pins, sparkles, sound
				showPopup("LUCKY!", K.Lime, "YOUR BALL FOUND A GOLDEN PIN", false, nil, "Hud:Clover")
			else
				showPopup("GOLDEN PIN!", GOLD, "KNOCK IT DOWN FOR A BIG BONUS", false, nil, "GoldenPin")
				Sfx.Play("Coin", 0.8, 1.5)
			end
		end)
	end
	for _, lane in LaneUtil.GetLanes() do
		watchLane(lane)
	end

	-- Your own throw: Golden Pin jackpot and bonus gems
	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ThrowResult").OnClientEvent:Connect(function(data)
		if data.UserId ~= player.UserId then
			return
		end
		task.delay(data.RollTime + 0.6, function() -- just after the STRIKE text lands
			local golden = data.Golden
			if golden and golden.Hit then
				local extras = { ("x%g COINS"):format(Config.GoldenPin.CoinMultiplier) }
				if golden.Gems > 0 then
					table.insert(extras, ("+%d GEMS"):format(golden.Gems))
				end
				if golden.Crate then
					table.insert(extras, "+FREE CRATE")
				end
				showPopup("GOLDEN PIN!", GOLD, table.concat(extras, "  ·  "), true, nil, "GoldenPin")
				Sfx.Play("PerfectSting", 1.1)
				Sfx.Play("Cheer", 1.2)
			end
			if (data.ModifierGems or 0) > 0 then
				local gems = data.ModifierGems
				showPopup(("+%d BONUS GEM%s"):format(gems, if gems == 1 then "" else "S"), K.Cyan, nil, false, nil, "Gem")
				Sfx.Play("Coin", 1.5)
			end
		end)
	end)
end

return EventController
