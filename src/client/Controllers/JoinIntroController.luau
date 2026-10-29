-- Join intro (batch B, Config.JoinIntro): brand new players only (first join, before their first throw) see a short
-- fly-over of the Back Alley with big captions and Rizzo's wave. It starts on a title card (name, tip, LOADING) that
-- covers the first seconds while Roblox loads textures and builds up the lighting, then fades into the shots. A SKIP button
-- shows after a second. Every other screen and Roblox's own menus hide while it plays and throws can't start; at the
-- end (or on SKIP) the camera glides back behind your character and everything comes back.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Zones = require(Shared.Modules.Zones)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules.Sfx)
local UiKit = require(Modules.UiKit)
local CrateKit = require(Modules.CrateKit)
local LaneVisuals = require(script.Parent.LaneVisuals)
local RizzoController = require(script.Parent.RizzoController)
local ThrowController = require(script.Parent.ThrowController)

local INTRO = Config.JoinIntro
local player = Players.LocalPlayer

local JoinIntroController = {}
-- True while the intro holds the screen
JoinIntroController.Playing = false

local function ease(t: number): number
	return t * t * (3 - 2 * t) -- smoothstep: soft start and stop
end

-- Is this a brand new player who hasn't thrown yet? Waits for the save to load (the server mirrors it to attributes)
local function isNewPlayer(): boolean
	local waited = 0
	while player:GetAttribute("Onboarding") == nil and waited < INTRO.WaitForData do
		waited += task.wait(0.1)
	end
	return player:GetAttribute("Onboarding") == 0 and (player:GetAttribute("OnboardThrows") or 0) == 0
end

local function buildScreen()
	local gui = Instance.new("ScreenGui")
	gui.Name = "JoinIntro"
	gui.DisplayOrder = 1000
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- SKIP (ZIndex 10) draws over the title card

	-- Letterbox bars: the cinematic look
	local bars = {}
	for i, y in { 0, 1 } do
		bars[i] = UiKit.Make("Frame", {
			Name = "Bar",
			AnchorPoint = Vector2.new(0, y),
			Position = UDim2.fromScale(0, y),
			Size = UDim2.fromScale(1, 0.1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
		}, gui)
	end

	-- The caption: the kit headline font, white with a thick ink outline, pops in
	local caption = UiKit.Make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.26),
		Size = UDim2.fromScale(0.9, 0.15),
		BackgroundTransparency = 1,
		FontFace = UiKit.Head,
		TextColor3 = UiKit.C.White,
		TextScaled = true,
		TextWrapped = true,
		Text = "",
	}, gui) :: TextLabel
	UiKit.Make("UITextSizeConstraint", { MaxTextSize = 80 }, caption)
	UiKit.Make("UIStroke", { Color = UiKit.C.Ink, Thickness = 4 }, caption)
	local captionScale = UiKit.ScaleOf(caption)

	-- SKIP: a small grey kit button bottom-right, above the bottom bar
	local skip = UiKit.Block(gui, {
		Name = "Skip",
		Size = Vector2.new(150, 58),
		Fill = UiKit.C.Grey,
		Lip = UiKit.C.GreyLip,
		Radius = 16,
		Button = true,
	})
	skip.Holder.AnchorPoint = Vector2.new(1, 1)
	skip.Holder.Position = UDim2.new(1, -24, 0.9, -16)
	skip.Holder.ZIndex = 10 -- above the title card
	skip.Holder.Visible = false
	UiKit.Text(skip.Face, "SKIP  >>", UiKit.Head, 28, UiKit.C.White, 2.5)

	local function show(text: string?)
		caption.Text = text or ""
		caption.Visible = text ~= nil and text ~= ""
		captionScale.Scale = 1.35
		UiKit.Tween(captionScale, 0.18, Enum.EasingStyle.Back, { Scale = 1 })
	end
	return gui, show, skip, bars
end

local function play()
	JoinIntroController.Playing = true
	ThrowController.Blocked = true
	local camera = Workspace.CurrentCamera
	local rizzo = RizzoController.Cinematic
	local gui, caption, skip, bars = buildScreen()
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Hide every other screen (also ones that appear while it plays) and Roblox's own menus
	local hidden = {}
	local function hideOthers()
		for _, other in player.PlayerGui:GetChildren() do
			if other:IsA("ScreenGui") and other ~= gui and other.Enabled then
				other.Enabled = false
				table.insert(hidden, other)
			end
		end
	end
	hideOthers()
	local core = {}
	for _, kind in Enum.CoreGuiType:GetEnumItems() do
		if kind ~= Enum.CoreGuiType.All then
			core[kind] = StarterGui:GetCoreGuiEnabled(kind)
		end
	end
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)

	local oldFov = camera.FieldOfView
	LaneVisuals.CameraHeld = true
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = INTRO.FieldOfView

	local skipped = false
	local started = os.clock()
	skip.Holder.Activated:Connect(function()
		if not skipped then
			skipped = true
			Sfx.Play("Click")
		end
	end)

	local function showSkip()
		if not skip.Holder.Visible and os.clock() - started >= INTRO.SkipAfter then
			skip.Holder.Visible = true
			UiKit.ScaleOf(skip.Holder).Scale = 0.3
			UiKit.Tween(UiKit.ScaleOf(skip.Holder), 0.25, Enum.EasingStyle.Back, { Scale = 1 })
		end
	end

	-- Title card while the game loads: the game's name, a tip and LOADING dots on a dark navy screen. It stays at
	-- least MinLoad seconds (Roblox builds the lighting up over the first seconds after joining and no script can
	-- tell when it's done), until the Back Alley's textures are in and you stand on your lane with the zone's lighting
	-- faded in, but never longer than LoadLimit. The camera already sits on the first shot behind it.
	local cover = UiKit.Make("CanvasGroup", {
		Name = "Loading",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, gui) :: CanvasGroup
	-- (the gradient sits on its own layer: on the CanvasGroup itself it would tint the words too)
	local backdrop = UiKit.Make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UiKit.C.White,
		BorderSizePixel = 0,
	}, cover)
	UiKit.Make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(UiKit.C.Page, UiKit.C.Ink),
	}, backdrop)
	local card = UiKit.Make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(900, 300),
		BackgroundTransparency = 1,
	}, cover)
	local fit = UiKit.Make("UIScale", {}, card) :: UIScale
	local function refit()
		local area = gui.AbsoluteSize
		if area.X > 0 then
			fit.Scale = math.min(1, (area.X - 32) / 900, area.Y / 420)
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	refit()
	local titleBox = UiKit.Make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 120),
	}, card)
	local title = CrateKit.Title(titleBox, "STRIKE LEGENDS", 104, UiKit.C.Gold, 6, 8)
	local titleScale = UiKit.ScaleOf(titleBox)
	titleScale.Scale = 0.6
	UiKit.Tween(titleScale, 0.45, Enum.EasingStyle.Back, { Scale = 1 })
	title.TextXAlignment = Enum.TextXAlignment.Center
	local tip = UiKit.Text(card, INTRO.Tips[math.random(1, #INTRO.Tips)], UiKit.Body, 26, UiKit.C.Label, 0)
	tip.Position = UDim2.fromOffset(0, 150)
	tip.Size = UDim2.new(1, 0, 0, 70)
	tip.TextWrapped = true
	local loadingText = UiKit.Text(card, "LOADING", UiKit.Head, 34, UiKit.C.Cyan, 2.5)
	loadingText.Position = UDim2.fromOffset(0, 240)
	loadingText.Size = UDim2.new(1, 0, 0, 44)
	local first = INTRO.Shots[1]
	if first then
		camera.CFrame = CFrame.lookAt(first.From.Pos, first.From.Look)
	end
	local loaded = false
	task.spawn(function()
		if not game:IsLoaded() then
			game.Loaded:Wait()
		end
		local alley = Workspace:FindFirstChild(Config.Zones.AssignFolder)
		if alley then
			pcall(ContentProvider.PreloadAsync, ContentProvider, { alley })
		end
		loaded = true
	end)
	local alleyWorld = Config.Zones.Worlds[1]
	local inAlleySince = nil
	repeat
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local inside = root ~= nil and alleyWorld ~= nil and Zones.InArea(alleyWorld.Area, root.Position)
		if inside then
			inAlleySince = inAlleySince or os.clock()
		end
		local lit = inAlleySince ~= nil and os.clock() - inAlleySince >= Config.Zones.LookBlend + INTRO.LightSettle
		local waited = os.clock() - started
		loadingText.Text = "LOADING" .. string.rep(".", math.floor(os.clock() * 3) % 4)
		showSkip()
		hideOthers()
		RunService.RenderStepped:Wait()
	until skipped or (loaded and lit and waited >= INTRO.MinLoad) or waited >= INTRO.LoadLimit
	UiKit.Tween(cover, INTRO.FadeIn, Enum.EasingStyle.Sine, { GroupTransparency = 1 })
	task.delay(INTRO.FadeIn, cover.Destroy, cover)

	for _, shot in INTRO.Shots do
		if skipped then
			break
		end
		caption(shot.Text)
		if rizzo then
			rizzo.ShowDeal(shot.Deal == true)
			if shot.Rizzo then
				rizzo.Say(shot.Rizzo)
				rizzo.Wave()
			else
				rizzo.Hush()
			end
		end
		local start = os.clock()
		repeat
			local t = ease(math.clamp((os.clock() - start) / shot.Time, 0, 1))
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = CFrame.lookAt(shot.From.Pos:Lerp(shot.To.Pos, t), shot.From.Look:Lerp(shot.To.Look, t))
			showSkip()
			hideOthers()
			RunService.RenderStepped:Wait()
		until skipped or os.clock() - start >= shot.Time
	end

	-- Glide back behind your character (the bars slide away), then hand the camera back
	caption(nil)
	skip.Holder.Visible = false
	if rizzo then
		rizzo.Hush()
		rizzo.ShowDeal(false)
	end
	for i, bar in bars do
		UiKit.Tween(
			bar,
			INTRO.GlideBack,
			Enum.EasingStyle.Sine,
			{ Position = UDim2.fromScale(0, if i == 1 then -0.1 else 1.1) }
		)
	end
	local from = camera.CFrame
	local glide = os.clock()
	repeat
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			break
		end
		local home =
			CFrame.lookAt((root.CFrame * CFrame.new(0, 4, 11)).Position, root.Position + root.CFrame.LookVector * 20)
		local t = ease(math.clamp((os.clock() - glide) / INTRO.GlideBack, 0, 1))
		camera.CFrame = from:Lerp(home, t)
		camera.FieldOfView = INTRO.FieldOfView + (oldFov - INTRO.FieldOfView) * t
		hideOthers()
		RunService.RenderStepped:Wait()
	until os.clock() - glide >= INTRO.GlideBack

	camera.FieldOfView = oldFov
	camera.CameraType = Enum.CameraType.Custom
	LaneVisuals.CameraHeld = false
	for kind, on in core do
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, kind, on)
	end
	for _, other in hidden do
		if other.Parent then
			other.Enabled = true
		end
	end
	gui:Destroy()
	ThrowController.Blocked = false
	JoinIntroController.Playing = false
end

function JoinIntroController:Start()
	if not (INTRO and INTRO.Enabled) then
		return
	end
	if not isNewPlayer() then
		return
	end
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	play()
end

return JoinIntroController
