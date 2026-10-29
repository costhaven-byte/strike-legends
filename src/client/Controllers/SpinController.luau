-- The daily spin wheel in Neon Lanes (owner 2026-10-22, Config.Spin): a big neon wheel on a stand at the far end of
-- the east walkway, a "DAILY SPIN" sign over it and a SPIN prompt in front. Built in code on this player's screen
-- only (so it lives in git, and everyone sees their own wheel turn). The server (SpinService) picks the prize; the
-- wheel just slows onto that slice, then the prize shows (potion/egg message, crate opening, or the pet card).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local Calendar = require(Shared.Modules.Calendar)
local Mascots = require(Shared.Modules.Mascots)
local Zones = require(Shared.Modules.Zones)
local CrateController = require(script.Parent.CrateController)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local MascotView = require(Modules:WaitForChild("MascotView"))
local Sfx = require(Modules:WaitForChild("Sfx"))
local UiFx = require(Modules:WaitForChild("UiFx"))
local RewardKit = require(Modules:WaitForChild("RewardKit"))
local MomentKit = require(Modules:WaitForChild("MomentKit"))

local player = Players.LocalPlayer

local SPIN = Config.Spin
local R = SPIN.Radius
local COUNT = #SPIN.Slices
local STEP = 2 * math.pi / COUNT

local FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local INK = Color3.fromHex("06060F")
local NAVY = Color3.fromRGB(14, 10, 34)
local PINK = Color3.fromRGB(255, 60, 210)
local CYAN = Color3.fromRGB(70, 230, 255)
local GOLD = Color3.fromRGB(255, 200, 40)
local LIME = Color3.fromRGB(125, 255, 60)
local WHITE = Color3.new(1, 1, 1)
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local SpinController = {}

local function newPart(parent: Instance, name: string, size: Vector3, color: Color3, cf: CFrame, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.CFrame = cf
	p.Parent = parent
	return p
end

-- A flat triangle (a, b, c) made of two wedges, `thickness` deep (the usual Roblox two-wedge trick)
local function triangle(parent: Instance, a: Vector3, b: Vector3, c: Vector3, color: Color3, thickness: number)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	for _, half in { { a, b, right, back, ab }, { a, c, -right, -back, ac } } do
		local w = Instance.new("WedgePart")
		w.Name = "Slice"
		w.Size = Vector3.new(thickness, height, math.abs(half[5]:Dot(back)))
		w.CFrame = CFrame.fromMatrix((half[1] + half[2]) / 2, half[3], up, half[4])
		w.Color = color
		w.Material = Enum.Material.SmoothPlastic
		w.Anchored = true
		w.CanCollide = false
		w.CanQuery = false
		w.CanTouch = false
		w.CastShadow = false
		w.Parent = parent
	end
end

local function stroke(parent: Instance, color: Color3, thickness: number, border: boolean?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = if border then Enum.ApplyStrokeMode.Border else Enum.ApplyStrokeMode.Contextual
	s.Parent = parent
	return s
end

local function text(parent: Instance, value: string, color: Color3, position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = FONT
	label.TextScaled = true
	label.Text = value
	label.TextColor3 = color
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = position
	label.Size = size
	label.Parent = parent
	stroke(label, INK, 2)
	return label
end

local function potionById(id: string)
	for _, potion in Config.Potions.List do
		if potion.Id == id then
			return potion
		end
	end
	return nil
end

-- Which way slice i points from the middle, in the wheel's own flat coordinates (slice 1 points up)
local function direction(angle: number): Vector3
	return Vector3.new(-math.sin(angle), math.cos(angle), 0)
end

-- Builds the wheel. Returns the folder, the rotor (the part that turns), the slice parts by slice number,
-- the sign's status label and the prompt.
local function build()
	local base = CFrame.lookAt(SPIN.Center, SPIN.Center + SPIN.Facing) -- -Z (the front) faces the players
	local folder = Instance.new("Folder")
	folder.Name = "DailySpinWheel"

	-- Stand: a dark base plate, two legs up to the middle, neon edges
	local floorY = SPIN.Center.Y - R - 3 -- the walkway floor (top at y 1)
	local floorCf = base - base.Position + Vector3.new(SPIN.Center.X, floorY, SPIN.Center.Z)
	local plate = newPart(folder, "Base", Vector3.new(10, 0.6, 4.5), NAVY, floorCf * CFrame.new(0, 0.3, 0.6))
	plate.CanCollide = true
	newPart(folder, "BaseGlow", Vector3.new(10.2, 0.15, 4.7), PINK, floorCf * CFrame.new(0, 0.62, 0.6), Enum.Material.Neon)
	for _, side in { -1, 1 } do
		local foot = (floorCf * CFrame.new(side * 3.6, 0.6, 1.1)).Position
		local top = (base * CFrame.new(0, 0, 1.1)).Position
		local length = (top - foot).Magnitude
		-- lookAt points -Z along the leg; the turn lays the part's height (Y) along it
		local legCf = CFrame.lookAt((foot + top) / 2, top, base.LookVector) * CFrame.Angles(-math.pi / 2, 0, 0)
		local leg = newPart(folder, "Leg", Vector3.new(0.9, length, 0.9), NAVY, legCf)
		newPart(folder, "LegGlow", Vector3.new(0.25, length, 0.95), CYAN, leg.CFrame * CFrame.new(0, 0, -0.1), Enum.Material.Neon)
	end

	-- The round back: a neon rim and a dark disc (cylinders lie along X, so turn them to face the players)
	local faceOn = CFrame.Angles(0, math.pi / 2, 0)
	newPart(folder, "Rim", Vector3.new(0.6, (R + 0.65) * 2, (R + 0.65) * 2), CYAN, base * CFrame.new(0, 0, 0.35) * faceOn, Enum.Material.Neon).Shape =
		Enum.PartType.Cylinder
	newPart(folder, "Disc", Vector3.new(0.5, (R + 0.3) * 2, (R + 0.3) * 2), NAVY, base * CFrame.new(0, 0, 0.1) * faceOn).Shape =
		Enum.PartType.Cylinder

	-- The rotor: slices, labels, pegs and the hub, all turning around the middle
	local rotor = Instance.new("Model")
	rotor.Name = "Rotor"
	local pivot = newPart(rotor, "Pivot", Vector3.one * 0.2, WHITE, base)
	pivot.Transparency = 1
	rotor.PrimaryPart = pivot
	local slices: { { BasePart } } = {}
	local labels: { BasePart } = {}
	for index, slice in SPIN.Slices do
		local angle = (index - 1) * STEP
		local holder = Instance.new("Folder")
		holder.Name = "Slice" .. index
		holder.Parent = rotor
		-- Glowing slices (the room is dark), every other one a darker shade so neighbours never blend.
		-- SECRET slices are black with gold writing and sparkles.
		local color = if slice.Secret then INK else slice.Color:Lerp(INK, if index % 2 == 0 then 0.55 else 0.35)
		local middle = (base * CFrame.new(0, 0, -0.25)).Position
		local a = (base * CFrame.new(direction(angle - STEP / 2) * R - Vector3.new(0, 0, 0.25))).Position
		local b = (base * CFrame.new(direction(angle + STEP / 2) * R - Vector3.new(0, 0, 0.25))).Position
		triangle(holder, middle, a, b, color, 0.3)
		local parts = {}
		for _, w in holder:GetChildren() do
			local wedge = w :: BasePart
			if not slice.Secret then
				wedge.Material = Enum.Material.Neon
			end
			table.insert(parts, wedge)
		end
		slices[index] = parts

		-- The label reads along the slice
		local labelCf = base * CFrame.Angles(0, 0, angle) * CFrame.new(0, R * 0.6, -0.45) * CFrame.Angles(0, 0, math.pi / 2)
		local board = newPart(holder, "Label", Vector3.new(R * 0.72, R * STEP * 0.42, 0.05), WHITE, labelCf)
		board.Transparency = 1
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = 0
		gui.PixelsPerStud = 60
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.Parent = board
		local label = text(gui, slice.Label, if slice.Secret then GOLD else WHITE, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.96, 0.9))
		label.TextWrapped = true
		label.UIStroke.Thickness = 3
		table.insert(labels, board)
		if slice.Secret then
			local sparkle = Instance.new("ParticleEmitter")
			sparkle.Texture = SPARKLE
			sparkle.Color = ColorSequence.new(GOLD, WHITE)
			sparkle.LightEmission = 1
			sparkle.Size = NumberSequence.new(0.35, 0)
			sparkle.Lifetime = NumberRange.new(0.6, 1)
			sparkle.Rate = 6
			sparkle.Speed = NumberRange.new(0.3, 0.8)
			sparkle.SpreadAngle = Vector2.new(180, 180)
			sparkle.Parent = board
		end

		-- A peg between this slice and the next
		local peg = newPart(rotor, "Peg", Vector3.one * 0.55, WHITE, base * CFrame.new(direction(angle + STEP / 2) * (R - 0.15) - Vector3.new(0, 0, 0.55)), Enum.Material.Neon)
		peg.Shape = Enum.PartType.Ball
	end
	newPart(rotor, "Hub", Vector3.new(0.5, 2.8, 2.8), GOLD, base * CFrame.new(0, 0, -0.55) * faceOn, Enum.Material.Neon).Shape =
		Enum.PartType.Cylinder
	newPart(rotor, "HubCap", Vector3.new(0.5, 1.6, 1.6), PINK, base * CFrame.new(0, 0, -0.75) * faceOn, Enum.Material.Neon).Shape =
		Enum.PartType.Cylinder
	rotor.Parent = folder

	-- The pointer at the top: a white diamond dipping into the wheel, with a pink ball on it
	newPart(folder, "Pointer", Vector3.new(1.3, 1.3, 0.5), WHITE, base * CFrame.new(0, R + 0.35, -0.85) * CFrame.Angles(0, 0, math.pi / 4), Enum.Material.Neon)
	newPart(folder, "PointerBall", Vector3.one * 1, PINK, base * CFrame.new(0, R + 1.1, -0.85), Enum.Material.Neon).Shape = Enum.PartType.Ball

	-- The sign over the wheel
	local sign = newPart(folder, "Sign", Vector3.new(13, 3.6, 0.3), NAVY, base * CFrame.new(0, R + 3.6, 0.2))
	newPart(folder, "SignGlow", Vector3.new(13.4, 4, 0.2), PINK, sign.CFrame * CFrame.new(0, 0, 0.12), Enum.Material.Neon)
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.LightInfluence = 0
	signGui.PixelsPerStud = 40
	signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	signGui.Parent = sign
	local title = text(signGui, "DAILY SPIN", GOLD, UDim2.fromScale(0.5, 0.36), UDim2.fromScale(0.9, 0.56))
	title.UIStroke.Color = PINK
	title.UIStroke.Thickness = 3
	local status = text(signGui, "", LIME, UDim2.fromScale(0.5, 0.8), UDim2.fromScale(0.9, 0.3))

	-- The SPIN prompt, in front of the stand at walking height
	local promptPart = newPart(folder, "PromptSpot", Vector3.one, WHITE, base * CFrame.new(0, -R + 1, -3))
	promptPart.Transparency = 1
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "SPIN!"
	prompt.ObjectText = "DAILY SPIN"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = SPIN.PromptRange
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart

	folder.Parent = Workspace
	return folder, rotor, base, slices, labels, status, prompt
end

function SpinController:Start()
	if not SPIN.Enabled then
		return
	end
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local spinRemote = remotes:WaitForChild("SpinWheel") :: RemoteFunction
	local testRemote = remotes:FindFirstChild("TestSpin") :: RemoteEvent? -- Studio only
	local playerGui = player:WaitForChild("PlayerGui")

	local wheel, rotor, base, slices, labels, status, prompt = build()
	local angle = 0
	local spinning = false

	-- Labels turn with the wheel; one that would read upside down flips over (as it passes upright, so it never jumps)
	local viewRight = (-SPIN.Facing):Cross(Vector3.yAxis).Unit
	local function uprightLabels()
		for _, board in labels do
			-- A Front-face SurfaceGui writes along the part's -X
			if (-board.CFrame.XVector):Dot(viewRight) < -0.05 then
				board.CFrame *= CFrame.Angles(0, 0, math.pi)
			end
		end
	end
	uprightLabels()

	-- Screen bits in the owner's kit style (RewardKit, UI pass batch 1): a toast and the YOU WON! prize card
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpinUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 30
	gui.Parent = playerGui

	local toast = RewardKit.Toast(gui)
	local function showToast(message: string, seconds: number?, color: Color3?)
		toast(message, nil, nil, color, seconds)
	end

	local prizeCard = RewardKit.PrizeCard(gui)
	local turning: RBXScriptConnection? = nil
	prizeCard.Window.Closed.Event:Connect(function()
		if turning then
			turning:Disconnect()
			turning = nil
		end
	end)

	-- SECRET PET: the pet turns on the card's rays
	local function showPet(pet)
		local mascot = pet and Mascots.Get(pet.MascotId)
		if not mascot then
			return
		end
		prizeCard:Show({
			Title = "SECRET PET!",
			Name = string.upper(mascot.Name),
			NameColor = Mascots.RarityColor(mascot.Rarity),
			Sub = ("%s  ·  %s COINS%s"):format(
				string.upper(mascot.Rarity),
				Mascots.BonusText(Mascots.Bonus(mascot)),
				if pet.Equipped then "  ·  EQUIPPED!" else ""
			),
			Big = true,
			Fill = function(slot: Frame)
				local model = MascotView.Mascot(mascot, 2)
				MascotView.Viewport(slot, model, 1.15)
				local start = os.clock()
				if turning then
					turning:Disconnect()
				end
				turning = RunService.RenderStepped:Connect(function()
					model:PivotTo(CFrame.Angles(0, math.sin((os.clock() - start) * 1.2) * 0.6, 0))
				end)
			end,
		})
	end

	-- Sign + prompt follow whether today's spin is waiting
	local function refresh()
		local ready = player:GetAttribute("SpinReady") == true
		if spinning then
			status.Text = "GOOD LUCK!"
			status.TextColor3 = GOLD
		elseif ready then
			status.Text = "FREE SPIN READY!"
			status.TextColor3 = LIME
		else
			local left = Calendar.SecondsUntilNextDay(math.floor(Workspace:GetServerTimeNow()))
			status.Text = "NEXT FREE SPIN IN " .. Calendar.FormatCountdown(left)
			status.TextColor3 = CYAN
		end
		prompt.Enabled = not spinning and (ready or testRemote ~= nil)
		prompt.ActionText = if ready or not testRemote then "SPIN!" else "TEST: SPIN AGAIN"
	end
	player:GetAttributeChangedSignal("SpinReady"):Connect(refresh)

	-- Batch B3: tell players about the wheel. A FREE SPIN! marker over it while today's spin waits (zone open), and a
	-- toast the first time a session you come near it
	local marker = MomentKit.WorldMarker(SPIN.MarkerText, PINK)
	marker.Name = "SpinMarker"
	local markerSpot = newPart(wheel, "MarkerSpot", Vector3.one, WHITE, CFrame.new(SPIN.Center + Vector3.new(0, R + 8, 0)))
	markerSpot.Transparency = 1
	marker.Adornee = markerSpot
	marker.MaxDistance = SPIN.MarkerRange
	marker.Enabled = false
	marker.Parent = playerGui
	local toasted = false
	local function refreshHint()
		local open = Zones.Unlocked(player:GetAttribute("ZonesOpen"), SPIN.Zone)
		local waiting = SPIN.Marker and open and not spinning and player:GetAttribute("SpinReady") == true
		marker.Enabled = waiting
		if not waiting or toasted then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and ((root.Position - SPIN.Center) * Vector3.new(1, 0, 1)).Magnitude <= SPIN.ToastRange then
			toasted = true
			toast(SPIN.ToastText, nil, nil, PINK, 4)
		end
	end

	task.spawn(function()
		while true do
			refresh()
			refreshHint()
			task.wait(1)
		end
	end)

	-- Turns the wheel so slice `index` stops under the pointer
	local function turnTo(index: number)
		local jitter = (math.random() - 0.5) * STEP * 0.7
		local target = -(index - 1) * STEP + jitter
		while target > angle do
			target -= 2 * math.pi
		end
		target -= 2 * math.pi * SPIN.Turns
		local from = angle
		local started = os.clock()
		local lastTick = math.floor(from / STEP + 0.5)
		while true do
			local u = math.min((os.clock() - started) / SPIN.SpinSeconds, 1)
			angle = from + (target - from) * TweenService:GetValue(u, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			rotor:PivotTo(base * CFrame.Angles(0, 0, angle))
			uprightLabels()
			local tick = math.floor(angle / STEP + 0.5)
			if tick ~= lastTick then
				lastTick = tick
				Sfx.Play("ReelTick", 1 + (1 - u) * 0.3, 0.6)
			end
			if u >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		angle %= 2 * math.pi
		rotor:PivotTo(base * CFrame.Angles(0, 0, angle))
		uprightLabels()
	end

	-- The winning slice blinks
	local function blink(index: number)
		local parts = slices[index]
		local before = {}
		for _, p in parts do
			before[p] = { p.Color, p.Material }
			p.Material = Enum.Material.Neon
		end
		for i = 1, 6 do
			for _, p in parts do
				p.Color = if i % 2 == 1 then WHITE else before[p][1]
			end
			task.wait(0.14)
		end
		for _, p in parts do
			p.Color, p.Material = before[p][1], before[p][2]
		end
	end

	local function reveal(slice, result)
		if result.Potion then
			local potion = potionById(result.Potion)
			UiFx.Flash(slice.Color, 0.3, 0.4)
			prizeCard:Show({
				Name = if potion then potion.Name else "POTION",
				NameColor = slice.Color,
				Sub = if potion
					then ("x%d %s FOR %d:00  ·  IN YOUR ITEMS"):format(
						potion.Multiplier,
						if potion.Boost == "XP" then "XP" else "COINS",
						potion.Minutes
					)
					else "IN YOUR ITEMS",
				Kind = "Potion",
				Value = result.Potion,
			})
		elseif result.Pet then
			UiFx.Flash(GOLD, 0.6, 0.6)
			showPet(result.Pet)
		elseif result.Egg then
			UiFx.Flash(slice.Color, 0.3, 0.4)
			local look = Config.EggLooks[result.Egg]
			prizeCard:Show({
				Name = "FREE " .. string.upper(if look then look.Name else "EGG"),
				NameColor = if look then look.Color else slice.Color,
				Sub = "HATCH IT AT THE EGG STAND",
				Kind = "Egg",
				Value = result.Egg,
			})
		end
		local crate = Balls.GetCrate(result.CrateId)
		if crate and result.Crate and CrateController.PlayOpening then
			if slice.Ball then
				UiFx.Flash(GOLD, 0.6, 0.6)
				Sfx.Play("RevealBig")
				showToast("SECRET BALL!! A LEGENDARY BALL!", 2, GOLD)
				UiFx.Confetti(nil, 60)
				task.wait(1.4)
			else
				UiFx.Confetti(nil, 30)
				task.wait(0.4)
			end
			CrateController.PlayOpening(crate, result.Crate)
		end
	end

	prompt.Triggered:Connect(function()
		if spinning then
			return
		end
		if player:GetAttribute("SpinReady") ~= true then
			if testRemote then
				testRemote:FireServer() -- Studio: today's spin back
			end
			return
		end
		spinning = true
		refresh()
		local okCall, result = pcall(spinRemote.InvokeServer, spinRemote, nil)
		if not okCall or type(result) ~= "table" or not result.Ok then
			spinning = false
			refresh()
			showToast(if okCall and type(result) == "table" and result.Error then result.Error else "Something went wrong")
			return
		end
		local slice = SPIN.Slices[result.Slice]
		turnTo(result.Slice)
		Sfx.Play("SpinWin")
		blink(result.Slice)
		spinning = false
		refresh()
		if slice then
			reveal(slice, result)
		end
	end)
end

return SpinController
