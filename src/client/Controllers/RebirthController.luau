-- REBIRTH button on the HUD (owner 2026-10-25: a button, not a station in the world), right of the level bar at the
-- top of the screen. Owner 2026-10-27: rebirths open the zones, so it shows from zone 1 once the first 3 minutes are
-- done (Onboarding 3). Tapping it opens the rebirth window: what you go back to, what you keep, the boost you get
-- forever (and the zone it opens) and what the next rebirth needs. REBIRTH needs a second tap to confirm.
-- Built in code (not in Studio), so it lives in git. The server decides everything (RebirthService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Currency = require(Shared.Modules.Currency)
local Rebirth = require(Shared.Modules.Rebirth)
local Zones = require(Shared.Modules.Zones)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules:WaitForChild("Sfx"))
local UiFx = require(Modules:WaitForChild("UiFx"))
local HudKit = require(Modules:WaitForChild("HudKit"))

local player = Players.LocalPlayer

local REBIRTH = Config.Economy.Rebirth
local FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local BODY_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local INK = Color3.fromHex("06060F")
local PANEL = Color3.fromRGB(18, 12, 38)
local GOLD = Color3.fromRGB(255, 200, 40)
local LIME = Color3.fromRGB(125, 255, 60)
local RED = Color3.fromRGB(255, 90, 90)
local GREY = Color3.fromRGB(120, 110, 150)
local SOFT = Color3.fromRGB(200, 190, 230)
local CONFIRM_SECONDS = 3

local RebirthController = {}

local function corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = if radius then UDim.new(0, radius) else UDim.new(1, 0)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number, border: boolean?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = if border then Enum.ApplyStrokeMode.Border else Enum.ApplyStrokeMode.Contextual
	s.Parent = parent
	return s
end

local function text(parent: Instance, name: string, font: Font, color: Color3, position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.FontFace = font
	label.TextScaled = true
	label.TextColor3 = color
	label.Position = position
	label.Size = size
	label.Parent = parent
	stroke(label, INK, 1.5)
	return label
end

function RebirthController:Start()
	local playerGui = player:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("HUD") :: ScreenGui
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Rebirth") :: RemoteFunction

	local gui = Instance.new("ScreenGui")
	gui.Name = "RebirthUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.IgnoreGuiInset = hud.IgnoreGuiInset -- same coordinates as the level bar it sits beside
	gui.Parent = playerGui

	-- ===== The button =====
	-- Right of the level bar (owner's HUD Kit): lime; ready = a glow, a red dot and the arrows turning
	local rebirthKit = HudKit.Square(gui, { Name = "RebirthButton", Paint = "Lime", Icon = "Rebirth", Key = "Rebirth" })
	local openButton = rebirthKit.Holder :: TextButton
	openButton.Visible = false
	local kitState = ""
	local stopSpin: (() -> ())? = nil
	local glowPulse = TweenService:Create(
		rebirthKit.GlowRing,
		TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.7 }
	)
	local function setLook(newState: string)
		if newState == kitState then
			return
		end
		kitState = newState
		rebirthKit:Paint("Lime")
		rebirthKit:SetIcon("Rebirth")
		rebirthKit:SetCaption("REBIRTH", nil, nil, 10)
		local ready = newState == "Ready"
		rebirthKit:SetGlow(if ready then HudKit.C.Lime else nil)
		rebirthKit:SetDot(ready)
		if ready then
			rebirthKit.GlowRing.Transparency = 0.3
			glowPulse:Play()
			stopSpin = HudKit.Spin(rebirthKit.Slot, 3)
		else
			glowPulse:Cancel()
			if stopSpin then
				stopSpin()
				stopSpin = nil
			end
		end
	end

	-- ===== The window =====
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.53)
	panel.Size = UDim2.fromOffset(460, 330)
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Active = true -- taps on the panel don't fall through to the throw meter
	panel.Parent = gui
	corner(panel, 18)
	stroke(panel, GOLD, 4, true)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(460, 330)
	sizeLimit.Parent = panel

	local title = text(panel, "Title", FONT, GOLD, UDim2.new(0, 20, 0, 12), UDim2.new(1, -80, 0, 38))
	title.TextXAlignment = Enum.TextXAlignment.Left
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Text = "X"
	close.FontFace = FONT
	close.TextScaled = true
	close.TextColor3 = Color3.new(1, 1, 1)
	close.BackgroundColor3 = Color3.fromRGB(255, 70, 90)
	close.AutoButtonColor = false
	close.Position = UDim2.new(1, -54, 0, 12)
	close.Size = UDim2.fromOffset(42, 42)
	close.Parent = panel
	corner(close, 10)
	stroke(close, INK, 2, true)
	UiFx.Press(close)

	-- Four rows: heading on the left, what it means on the right
	local rows = {}
	for i, heading in { "BACK TO", "YOU KEEP", "FOREVER", "NEEDS" } do
		local y = 62 + (i - 1) * 42
		local head = text(panel, "Head" .. i, FONT, SOFT, UDim2.new(0, 20, 0, y), UDim2.new(0, 110, 0, 22))
		head.Text = heading
		head.TextXAlignment = Enum.TextXAlignment.Left
		local body =
			text(panel, "Body" .. i, BODY_FONT, Color3.new(1, 1, 1), UDim2.new(0, 136, 0, y), UDim2.new(1, -156, 0, 22))
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.RichText = true
		rows[i] = body
	end
	rows[1].Text = "POWER LEVEL 1 AND 0 COINS"
	rows[2].Text = "LEVEL, BALLS, PETS, GEMS, POTIONS AND ZONES"

	local go = Instance.new("TextButton")
	go.Name = "Go"
	go.FontFace = FONT
	go.TextScaled = true
	go.TextColor3 = INK
	go.AutoButtonColor = false
	go.AnchorPoint = Vector2.new(0.5, 1)
	go.Position = UDim2.new(0.5, 0, 1, -18)
	go.Size = UDim2.new(0.62, 0, 0, 56)
	go.Parent = panel
	corner(go, 12)
	stroke(go, INK, 2, true)
	local goPad = Instance.new("UIPadding")
	goPad.PaddingTop = UDim.new(0, 8)
	goPad.PaddingBottom = UDim.new(0, 8)
	goPad.Parent = go
	UiFx.Press(go)

	local confirmUntil = 0
	local busy = false

	local function state()
		local done = player:GetAttribute("Rebirths") or 0
		local level = player:GetAttribute("RankLevel") or 1
		local needLevel, cost = Rebirth.Level(done), Rebirth.Cost(done)
		local hasLevel = level >= needLevel
		local hasCoins = Currency.CanAfford(player:GetAttribute("Coins"), cost)
		return done, needLevel, cost, hasLevel, hasCoins
	end

	local function hex(color: Color3): string
		return "#" .. color:ToHex()
	end

	local function refresh()
		local done, needLevel, cost, hasLevel, hasCoins = state()
		openButton.Visible = done > 0 or (player:GetAttribute("Onboarding") or 0) >= 3
		local ready = REBIRTH.Enabled and hasLevel and hasCoins
		setLook(if ready then "Ready" else "Normal")

		-- The window
		title.Text = if done > 0 then ("REBIRTH %d"):format(done + 1) else "REBIRTH"
		local opens = Rebirth.OpensZone(done)
		rows[3].Text = (if opens then ("OPENS %s!  "):format(Zones.Name(opens):upper()) else "")
			.. ("COINS %s  ->  %s,  XP %s  ->  %s"):format(
			Currency.FormatMultiplier(Rebirth.CoinMultiplier(done)),
			Currency.FormatMultiplier(Rebirth.CoinMultiplier(done + 1)),
			Currency.FormatMultiplier(Rebirth.XpMultiplier(done)),
			Currency.FormatMultiplier(Rebirth.XpMultiplier(done + 1))
		)
		rows[4].Text = ('<font color="%s">LEVEL %d</font>  +  <font color="%s">%s COINS</font>'):format(
			hex(if hasLevel then LIME else RED),
			needLevel,
			hex(if hasCoins then LIME else RED),
			Currency.Format(cost)
		)
		if not REBIRTH.Enabled then
			go.Text = "COMING SOON"
		elseif not hasLevel then
			go.Text = ("REACH LEVEL %d"):format(needLevel)
		elseif not hasCoins then
			go.Text = ("NEED %s COINS"):format(Currency.Format(cost))
		elseif os.clock() < confirmUntil then
			go.Text = "TAP AGAIN TO REBIRTH"
		else
			go.Text = "REBIRTH!"
		end
		go.BackgroundColor3 = if ready then GOLD else GREY
	end

	local function setOpen(open: boolean)
		if open then
			confirmUntil = 0
			refresh()
			UiFx.Open(panel)
		else
			UiFx.Close(panel)
		end
	end

	openButton.Activated:Connect(function()
		setOpen(not panel.Visible)
	end)
	close.Activated:Connect(function()
		setOpen(false)
	end)
	go.Activated:Connect(function()
		local _, _, _, hasLevel, hasCoins = state()
		if busy or not (REBIRTH.Enabled and hasLevel and hasCoins) then
			return
		end
		-- A rebirth can't be undone: the first tap asks, the second (within a few seconds) does it
		if os.clock() >= confirmUntil then
			confirmUntil = os.clock() + CONFIRM_SECONDS
			refresh()
			UiFx.Pop(go, 1.1, 0.25)
			task.delay(CONFIRM_SECONDS, refresh)
			return
		end
		busy = true
		local ok, result = pcall(remote.InvokeServer, remote)
		busy = false
		confirmUntil = 0
		if ok and result and result.Ok then
			setOpen(false)
			UiFx.Flash(GOLD, 0.7, 0.6)
			UiFx.Confetti(nil, 60, { GOLD, Color3.new(1, 1, 1), LIME })
			Sfx.Play("RankUp", 1)
		else
			go.Text = if ok and result and result.Error then result.Error:upper() else "TRY AGAIN"
			task.delay(2, refresh)
		end
	end)

	for _, key in { "RankLevel", "Coins", "Rebirths", "Onboarding" } do
		player:GetAttributeChangedSignal(key):Connect(refresh)
	end
	refresh()
end

return RebirthController
