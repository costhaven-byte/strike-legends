-- Rizzo, the Back Alley crate dealer (Workspace.BackAlley.RizzoStand, built in Studio from the owner's design).
-- Hold the prompt on his pink buy pad to open the zone's crate, or browse the full shop. He bobs while idle,
-- waves and says hi when you walk up, cheers rare pulls and says bye when you leave. His turntable spins.
-- Buying still goes through CrateController and the server; Rizzo is just another way in, like the kiosk.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Currency = require(Shared.Modules.Currency)
local Balls = require(Shared.Modules.Balls)
local CrateController = require(script.Parent.CrateController)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local UiKit = require(Modules:WaitForChild("UiKit"))
local MomentKit = require(Modules:WaitForChild("MomentKit"))

local RIZZO = Config.Rizzo
local GOLD = Color3.fromRGB(255, 200, 40)
local WAVE_PARTS = { "RightUpperArm_Node", "RightLowerArm_Node", "RightHand_Node", "Acc_SleeveR", "Acc_GloveR" }

local player = Players.LocalPlayer

local RizzoController = {}

-- Every number on screen uses the shared formatter (Config.Numbers)
local formatNumber = Currency.Format

-- A speech bubble over his head that types each line out: the kit's comic bubble (UI pass batch 3) - white, a
-- thick ink outline, a tail pointing down at him, ink letters
local function buildBubble(head: BasePart)
	local C = UiKit.C
	local gui = Instance.new("BillboardGui")
	gui.Name = "RizzoBubble"
	gui.Adornee = head
	gui.Size = UDim2.fromScale(9, 3.1)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
	gui.MaxDistance = 60
	gui.AlwaysOnTop = true -- never hidden behind the shop or walls
	gui.LightInfluence = 0
	gui.Enabled = false
	local BUBBLE = 0.78 -- the bubble's share of the height; the tail hangs under it
	-- tail: a white diamond with an ink edge, half hidden under the bubble
	local tail = Instance.new("Frame")
	tail.Name = "Tail"
	tail.AnchorPoint = Vector2.new(0.5, 0.5)
	tail.Position = UDim2.fromScale(0.5, BUBBLE - 0.04)
	tail.Size = UDim2.fromScale(0.3, 0.3)
	tail.SizeConstraint = Enum.SizeConstraint.RelativeYY
	tail.Rotation = 45
	tail.BackgroundColor3 = C.White
	tail.ZIndex = 1
	tail.Parent = gui
	UiKit.Outline(tail, C.Ink, 3)
	local frame = Instance.new("Frame")
	frame.Name = "Bubble"
	frame.Size = UDim2.fromScale(1, BUBBLE)
	frame.BackgroundColor3 = C.White
	frame.ZIndex = 2
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = frame
	UiKit.Outline(frame, C.Ink, 3)
	-- a white patch hides the bubble's outline where the tail joins it
	local patch = Instance.new("Frame")
	patch.Name = "Join"
	patch.AnchorPoint = Vector2.new(0.5, 0.5)
	patch.Position = UDim2.fromScale(0.5, BUBBLE)
	patch.Size = UDim2.new(0.3, 0, 0, 9)
	patch.SizeConstraint = Enum.SizeConstraint.RelativeYY
	patch.BackgroundColor3 = C.White
	patch.BorderSizePixel = 0
	patch.ZIndex = 3
	patch.Parent = gui
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.88, 0.8)
	label.Position = UDim2.fromScale(0.06, 0.1)
	label.BackgroundTransparency = 1
	label.FontFace = UiKit.Num
	label.TextColor3 = C.Ink
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = ""
	label.ZIndex = 4
	label.Parent = frame
	gui.Parent = player:WaitForChild("PlayerGui")

	local token = 0
	local function hush()
		token += 1
		gui.Enabled = false
	end
	local function say(text: string)
		token += 1
		local mine = token
		gui.Enabled = true
		label.Text = text
		label.MaxVisibleGraphemes = 0
		task.spawn(function()
			local shown = 0
			while shown < #text and mine == token do
				shown += math.max(1, math.floor(RIZZO.TypeSpeed * task.wait()))
				label.MaxVisibleGraphemes = shown
			end
			label.MaxVisibleGraphemes = -1
			task.wait(RIZZO.BubbleTime)
			if mine == token then
				gui.Enabled = false
			end
		end)
	end
	return say, hush
end

function RizzoController:Start()
	local alley = Workspace:WaitForChild("BackAlley", 30)
	local stand = alley and alley:WaitForChild("RizzoStand", 10)
	local cart = stand and stand:WaitForChild("RizzoCart", 10)
	local rizzo = stand and stand:WaitForChild("Rizzo", 10)
	local pad = cart and cart:WaitForChild("BuyPad", 10)
	if not (cart and rizzo and pad) then
		warn("[RizzoController] Workspace.BackAlley.RizzoStand is missing its cart, Rizzo or BuyPad, so Rizzo is off")
		return
	end
	while not CrateController.Buy do
		task.wait(0.1)
	end
	local crate = Balls.GetCrate(RIZZO.CrateId)
	if not crate then
		return
	end

	local body = rizzo:WaitForChild("Rizzo_R15_Body")
	local head = body:WaitForChild("Head_Node"):FindFirstChildWhichIsA("BasePart", true) :: BasePart
	local say, hush = buildBubble(head)

	-- Prompts sit on an invisible point just above the pad
	local padCFrame = pad:GetBoundingBox()
	local point = Instance.new("Part")
	point.Name = "PromptPoint"
	point.Transparency = 1
	point.Anchored = true
	point.CanCollide = false
	point.CanQuery = false
	point.CanTouch = false
	point.Size = Vector3.one
	point.CFrame = padCFrame + Vector3.new(0, 2.5, 0)
	point.Parent = stand

	local buyPrompt = Instance.new("ProximityPrompt")
	buyPrompt.Name = "BuyPrompt"
	buyPrompt.ObjectText = crate.Name
	buyPrompt.HoldDuration = Config.CrateShop.HoldDuration
	buyPrompt.MaxActivationDistance = Config.CrateShop.PromptDistance
	buyPrompt.RequiresLineOfSight = false
	buyPrompt.Parent = point
	local shopPrompt = Instance.new("ProximityPrompt")
	shopPrompt.Name = "ShopPrompt"
	shopPrompt.ActionText = "Browse"
	shopPrompt.ObjectText = "Crate Shop"
	shopPrompt.KeyboardKeyCode = Enum.KeyCode.F
	shopPrompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	shopPrompt.UIOffset = Vector2.new(0, 60)
	shopPrompt.MaxActivationDistance = Config.CrateShop.PromptDistance
	shopPrompt.RequiresLineOfSight = false
	shopPrompt.Parent = point

	-- The first crate you buy is on discount: a sign over the buy pad with the old price crossed out
	local deal = Instance.new("BillboardGui")
	deal.Name = "FirstCrateDeal"
	deal.Adornee = point
	deal.Size = UDim2.fromOffset(230, 78)
	deal.StudsOffsetWorldSpace = Vector3.new(0, 4.2, 0)
	deal.MaxDistance = 60
	deal.LightInfluence = 0
	deal.Enabled = false
	local dealFrame = Instance.new("Frame")
	dealFrame.Name = "Tag"
	dealFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	dealFrame.Position = UDim2.fromScale(0.5, 0.5)
	dealFrame.Size = UDim2.fromScale(1, 1)
	dealFrame.BackgroundColor3 = UiKit.C.PinkLip -- the kit's lip shows as a darker band under the pink face
	dealFrame.Parent = deal
	local dealFace = Instance.new("Frame")
	dealFace.Name = "Face"
	dealFace.Size = UDim2.new(1, 0, 1, -7)
	dealFace.BackgroundColor3 = UiKit.C.Pink
	dealFace.BorderSizePixel = 0
	dealFace.Parent = dealFrame
	local dealFaceCorner = Instance.new("UICorner")
	dealFaceCorner.CornerRadius = UDim.new(0, 14)
	dealFaceCorner.Parent = dealFace
	local dealCorner = Instance.new("UICorner")
	dealCorner.CornerRadius = UDim.new(0, 14)
	dealCorner.Parent = dealFrame
	local dealStroke = Instance.new("UIStroke")
	dealStroke.Color = Color3.fromHex("06060F")
	dealStroke.Thickness = 3
	dealStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	dealStroke.Parent = dealFrame
	local function dealText(name: string, y: number, height: number, color: Color3): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Position = UDim2.new(0.04, 0, y, 0)
		label.Size = UDim2.new(0.92, 0, height, 0)
		label.FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
		label.TextScaled = true
		label.RichText = true
		label.TextColor3 = color
		label.ZIndex = 2
		local outline = Instance.new("UIStroke")
		outline.Color = Color3.fromHex("06060F")
		outline.Thickness = 2
		outline.Parent = label
		label.Parent = dealFrame
		return label
	end
	local dealTitle = dealText("Title", 0.06, 0.48, Color3.new(1, 1, 1))
	local dealPrice = dealText("Price", 0.5, 0.38, GOLD)
	deal.Parent = stand

	local function refreshPrompt()
		local discount = not CrateController.HasFree(crate) and CrateController.Discount(crate)
		buyPrompt.ActionText = if CrateController.HasFree(crate)
			then "Open FREE"
			elseif discount then ("Open  (%s coins, %d%% OFF!)"):format(
				formatNumber(CrateController.Price(crate)),
				discount
			)
			else ("Open  (%s coins)"):format(formatNumber(CrateController.Price(crate)))
		deal.Enabled = if discount then true else false -- discount is false (not nil) while a free crate waits
		if discount then
			dealTitle.Text = ("FIRST CRATE %d%% OFF!"):format(discount)
			dealPrice.Text = ('<s><font color="#FFFFFF" transparency="0.3">%s</font></s>  %s COINS'):format(
				formatNumber(crate.Price),
				formatNumber(CrateController.Price(crate))
			)
		end
	end
	player:GetAttributeChangedSignal("FreeCrates"):Connect(refreshPrompt)
	player:GetAttributeChangedSignal("CratesBought"):Connect(refreshPrompt)
	refreshPrompt()

	-- Wave: the right arm swings up from the shoulder, then waggles
	local waveParts = {}
	for _, name in WAVE_PARTS do
		local part = rizzo:FindFirstChild(name, true)
		if part then
			table.insert(waveParts, { Model = part, Home = part:GetPivot() })
		end
	end
	local upper = rizzo:FindFirstChild("RightUpperArm_Node", true)
	local shoulder = Vector3.zero
	if upper then
		local cf, size = upper:GetBoundingBox()
		local inward = (body:GetPivot().Position - cf.Position) * Vector3.new(1, 0, 1)
		shoulder = cf.Position + Vector3.new(0, size.Y / 2, 0) + inward.Unit * size.X * 0.5
	end
	-- Positive turns about the forward axis raise an arm on the +X side; flip for the other side
	local raiseSign = if upper and (upper:GetPivot().Position - body:GetPivot().Position).X < 0 then -1 else 1
	local waveStart = -math.huge
	local function wave()
		waveStart = os.clock()
	end

	-- Studio only: the Day 1 video intro (IntroCinematicController) makes him talk, wave and show the deal sign
	if RunService:IsStudio() then
		local firstPrice = Balls.CratePrice(crate, 0)
		RizzoController.Cinematic = {
			Say = say,
			Hush = hush,
			Wave = wave,
			ShowDeal = function(on: boolean)
				if not on then
					refreshPrompt()
					return
				end
				deal.Enabled = true
				dealTitle.Text = ("FIRST CRATE %d%% OFF!"):format(
					math.floor((1 - firstPrice / crate.Price) * 100 + 0.5)
				)
				dealPrice.Text = ('<s><font color="#FFFFFF" transparency="0.3">%s</font></s>  %s COINS'):format(
					formatNumber(crate.Price),
					formatNumber(firstPrice)
				)
			end,
		}
	end

	buyPrompt.Triggered:Connect(function()
		local free = CrateController.HasFree(crate)
		if not free and (player:GetAttribute("Coins") or 0) < CrateController.Price(crate) then
			say(RIZZO.Lines.CantAfford)
			return
		end
		say(RIZZO.Lines.Opening)
		wave()
		task.spawn(CrateController.Buy, crate)
	end)
	shopPrompt.Triggered:Connect(function()
		CrateController.OpenShop()
	end)
	local rareIndex = Balls.RarityIndex(RIZZO.RareFrom)
	CrateController.Opened.Event:Connect(function(_, result)
		local ball = result and Balls.Get(result.BallId)
		if ball and Balls.RarityIndex(ball.Rarity) >= rareIndex then
			say(RIZZO.Lines.Rare)
			wave()
		end
	end)

	-- Your first crate is affordable: a bouncing "!" over his head (seen through walls, from your lane, above his
	-- speech bubble) and a gold beam from you to his buy pad, and he calls you over, until you've bought a crate
	-- (the kit's world marker since UI pass batch 3: a navy GO HERE! pill with a bobbing gold arrow)
	local marker = MomentKit.WorldMarker("GO HERE!", GOLD)
	marker.Name = "CallMarker"
	marker.Adornee = head
	marker.StudsOffsetWorldSpace = Vector3.new(0, 7.4, 0)
	marker.Enabled = false
	local bang = marker:FindFirstChild("Pill") :: GuiObject
	marker.Parent = stand

	local beamTo = Instance.new("Attachment")
	beamTo.Name = "CallBeamTo"
	beamTo.Position = Vector3.new(0, -1.5, 0)
	beamTo.Parent = point
	local beamFrom: Attachment? = nil
	local beams: { Beam } = {}
	local function setBeam(on: boolean)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if on and root and beamFrom and beamFrom.Parent == root then
			return
		end
		for _, beam in beams do
			beam:Destroy()
		end
		table.clear(beams)
		if beamFrom then
			beamFrom:Destroy()
			beamFrom = nil
		end
		if not on or not root then
			return
		end
		local from = Instance.new("Attachment")
		from.Name = "CallBeamFrom"
		from.Position = Vector3.new(0, -1.5, 0)
		from.Parent = root
		beamFrom = from
		-- A soft gold band with sparkles running along it toward Rizzo
		for i = 1, 2 do
			local beam = Instance.new("Beam")
			beam.Name = "RizzoGuide"
			beam.Attachment0 = from
			beam.Attachment1 = beamTo
			beam.Color = ColorSequence.new(GOLD)
			beam.LightEmission = 1
			beam.FaceCamera = true
			beam.Segments = 1 -- a straight line: no sag, and no gaps over long distances
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
	end

	local calling = false
	local function refreshCall()
		local want = RIZZO.FirstCrateMarker
			and Config.Onboarding.FirstCrateGoal == crate.Id
			and (player:GetAttribute("CratesBought") or 0) == 0
			and (player:GetAttribute("Coins") or 0) >= Balls.CratePrice(crate, 0)
		marker.Enabled = want
		setBeam(want)
		if want and not calling then
			say(RIZZO.Lines.CallOver)
			wave()
		end
		calling = want
	end
	player:GetAttributeChangedSignal("Coins"):Connect(refreshCall)
	player:GetAttributeChangedSignal("CratesBought"):Connect(refreshCall)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		setBeam(calling)
	end)
	refreshCall()
	RunService.RenderStepped:Connect(function()
		if calling then
			local t = os.clock()
			bang.Rotation = math.sin(t * 6) * 4
		end
		if deal.Enabled then -- the deal sign breathes and tilts a little
			local t = os.clock()
			local scale = 1 + math.sin(t * 3) * 0.05
			dealFrame.Size = UDim2.fromScale(scale, scale)
			dealFrame.Rotation = math.sin(t * 1.5) * 3
		end
	end)

	-- Hi when you walk up, bye when you leave
	local near = false
	task.spawn(function()
		while true do
			task.wait(0.3)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local distance = (root.Position - padCFrame.Position).Magnitude
				if not near and distance < RIZZO.GreetDistance then
					near = true
					say(RIZZO.Lines.Greeting)
					wave()
				elseif near and distance > RIZZO.ByeDistance then
					near = false
					say(RIZZO.Lines.Goodbye)
				end
			end
		end
	end)

	-- Turntable plate, its neon ring and the crate on it spin; Rizzo bobs and waves
	local turntable = cart:FindFirstChild("Turntable")
	local spinners = {}
	local spinCentre = CFrame.identity
	if turntable then
		local base = turntable:FindFirstChild("Turntable_Base_Node")
		local cf = (base or turntable):GetBoundingBox()
		spinCentre = CFrame.new(cf.Position)
		for _, child in turntable:GetChildren() do
			if child ~= base and child:IsA("PVInstance") then
				table.insert(spinners, { Model = child, Offset = spinCentre:ToObjectSpace(child:GetPivot()) })
			end
		end
	end
	local rizzoHome = rizzo:GetPivot()
	local middle = padCFrame.Position
	local waving = false
	RunService.Heartbeat:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera or (camera.CFrame.Position - middle).Magnitude > RIZZO.AnimateDistance then
			return
		end
		local t = os.clock()
		local spin = CFrame.Angles(0, t * RIZZO.TurntableSpin * math.pi * 2, 0)
		for _, s in spinners do
			s.Model:PivotTo(spinCentre * spin * s.Offset)
		end

		local bob = CFrame.new(0, math.sin(t * 2.2) * RIZZO.Bob, 0)
		rizzo:PivotTo(bob * rizzoHome)
		local w = (t - waveStart) / RIZZO.WaveTime
		if w < 1 then
			waving = true
			-- up fast, waggle, back down
			local lift = math.sin(math.min(w * 4, 1) * math.pi / 2) * (1 - math.max(0, w - 0.8) / 0.2)
			local angle = (math.rad(150) + math.sin(t * 14) * math.rad(18)) * lift * raiseSign
			local turn = CFrame.new(shoulder) * CFrame.Angles(0, 0, angle) * CFrame.new(-shoulder)
			for _, p in waveParts do
				p.Model:PivotTo(bob * turn * p.Home)
			end
		elseif waving then
			waving = false
			for _, p in waveParts do
				p.Model:PivotTo(bob * p.Home)
			end
		end
	end)
end

return RizzoController
