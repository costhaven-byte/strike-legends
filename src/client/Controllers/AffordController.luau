-- "YOU CAN NOW AFFORD X" (final changes item 8, batch B2; settings in Config.AffordNote): the moment your coins
-- first reach something you couldn't buy before, a navy note fades in at the top centre and fades out. Things:
-- every crate and egg of a zone you have open, the next Power Level, the next rebirth. One note per thing a
-- session; things you could already afford when you joined get none. Skipped where a bigger moment already says it:
-- the first crate (RIZZO HAS A CRATE FOR YOU!), the first egg (BUY YOUR FIRST PET EGG!), Power Level 2 (the BUY callout), the first rebirth (REBIRTH IS READY!).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local Currency = require(Shared.Modules.Currency)
local Mascots = require(Shared.Modules.Mascots)
local PowerLevels = require(Shared.Modules.PowerLevels)
local Rebirth = require(Shared.Modules.Rebirth)
local Zones = require(Shared.Modules.Zones)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local CrateKit = require(Modules.CrateKit)
local HudKit = require(Modules.HudKit)
local Sfx = require(Modules.Sfx)
local UiKit = require(Modules.UiKit)
local ThrowController = require(script.Parent.ThrowController)

local player = Players.LocalPlayer
local SETTINGS = Config.AffordNote
local C = UiKit.C
local K = HudKit.C

local AffordController = {}

-- Everything there is to afford right now: { Key, Name, Price, Icon (HudKit icon), Color, Ok (extra rule) }
local function things(): { { [string]: any } }
	local list = {}
	local zonesOpen = player:GetAttribute("ZonesOpen") or 1
	local cratesBought = player:GetAttribute("CratesBought") or 0
	for _, row in Config.Crates do
		local crate = Balls.GetCrate(row.Id)
		if crate and crate.Price and Zones.CrateUnlocked(crate, zonesOpen) then
			-- the first crate on sale has Rizzo's own callout
			local first = cratesBought == 0 and crate.Id == Config.Onboarding.FirstCrateGoal
			table.insert(list, {
				Key = "Crate" .. crate.Id .. (if first then "First" else ""),
				Name = crate.Name:upper(),
				Price = Balls.CratePrice(crate, cratesBought),
				Icon = "Crate",
				Color = crate.Color or K.Cyan,
				Ok = not first,
			})
		end
	end
	for _, stand in Config.EggStands do
		local egg = Mascots.GetEgg(stand.Egg)
		local look = Config.EggLooks[stand.Egg]
		if egg and look and Mascots.EggReady(egg.Id) and Zones.Unlocked(zonesOpen, egg.Zone or 1) then
			-- the first egg has its own BUY YOUR FIRST PET EGG! popup (Config.EggPrompt)
			local first = Config.EggPrompt.Enabled
				and egg.Id == Config.EggPrompt.Egg
				and (player:GetAttribute("EggsHatched") or 0) == 0
			table.insert(list, {
				Key = "Egg" .. egg.Id .. (if first then "First" else ""),
				Name = look.Name:upper(),
				Price = egg.Price,
				Icon = "Paw",
				Color = look.Color,
				Ok = not first,
			})
		end
	end
	local nextLevel = PowerLevels.Next(player:GetAttribute("PowerLevel") or 1)
	if nextLevel then
		table.insert(list, {
			Key = "Power" .. nextLevel.Level,
			-- with its coin payoff (batch D2): "POWER LV 5 = x2.5 COINS"
			Name = ("POWER LV %d = %s COINS"):format(nextLevel.Level, Currency.FormatMultiplier(nextLevel.Value)),
			Price = nextLevel.Price,
			Icon = "Bolt",
			Color = K.Pink,
			Ok = nextLevel.Level > 2,
		})
	end
	local done = player:GetAttribute("Rebirths") or 0
	if Config.Economy.Rebirth.Enabled and not Config.CoreLoop.Enabled then
		table.insert(list, {
			Key = "Rebirth" .. done,
			Name = ("REBIRTH %d"):format(done + 1),
			-- not affordable until the level is there too
			Price = if (player:GetAttribute("RankLevel") or 1) >= Rebirth.Level(done)
				then Rebirth.Cost(done)
				else math.huge,
			Icon = "Rebirth",
			Color = K.Lime,
			Ok = done > 0,
		})
	end
	return list
end

-- ===== The note =====
local function buildNote(): (string, string, Color3) -> ()
	local gui = Instance.new("ScreenGui")
	gui.Name = "AffordNoteUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 45
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local W, H = 440, 66
	local group = Instance.new("CanvasGroup")
	group.Name = "Note"
	group.BackgroundTransparency = 1
	group.AnchorPoint = Vector2.new(0.5, 0)
	group.Size = UDim2.fromOffset(W, H + 6)
	group.GroupTransparency = 1
	group.Visible = false
	group.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = group

	local pill = UiKit.Block(group, {
		Name = "Pill",
		Size = UDim2.fromScale(1, 1),
		Fill = C.Cover,
		Lip = C.Ink,
		LipPx = 5,
		Radius = 30,
		Outline = 3,
	})
	pill.Holder.Parent = group
	local face = pill.Face
	local ring = Instance.new("UIStroke")
	ring.Thickness = 2
	ring.Transparency = 0.35
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Parent = face
	local icon = HudKit.Image(face, "Crate", 46, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
	})
	local small = UiKit.Text(face, "YOU CAN NOW AFFORD", UiKit.Head, 17, C.Gold, 2)
	small.TextXAlignment = Enum.TextXAlignment.Left
	small.Position = UDim2.fromOffset(68, 6)
	small.Size = UDim2.new(1, -84, 0, 20)
	local name = UiKit.Text(face, "", UiKit.Head, 28, C.White, 2.5)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Position = UDim2.fromOffset(68, 26)
	name.Size = UDim2.new(1, -84, 0, 32)

	return function(text: string, iconName: string, color: Color3)
		-- the pill grows with the name
		local textW = math.max(CrateKit.TextWidth(text, UiKit.Head, 28), CrateKit.TextWidth(small.Text, UiKit.Head, 17))
		local width = math.clamp(textW + 68 + 26, 300, 600)
		group.Size = UDim2.fromOffset(width, H + 6)
		name.Text = text
		name.TextColor3 = color
		ring.Color = color
		icon.Image = HudKit.Icon(iconName)
		-- under the after-throw line, above the middle of the lane (phones: smaller, higher)
		local phone = HudKit.Phone()
		local top = if phone then 64 else 120
		scale.Scale = if phone then 0.66 else 1
		group.Position = UDim2.new(0.5, 0, 0, top + 12)
		group.GroupTransparency = 1
		group.Visible = true
		local inInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(group, inInfo, { GroupTransparency = 0, Position = UDim2.new(0.5, 0, 0, top) }):Play()
		Sfx.Play("Coin", 1.6, 0.5)
		task.wait(0.35 + SETTINGS.Seconds)
		local out = TweenService:Create(group, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { GroupTransparency = 1 })
		out:Play()
		out.Completed:Wait()
		group.Visible = false
	end
end

function AffordController:Start()
	if not SETTINGS.Enabled then
		return
	end
	local show = buildNote()

	-- Wait for the save to arrive, then remember everything already affordable (no notes for those)
	while player:GetAttribute("Coins") == nil do
		task.wait(0.5)
	end
	task.wait(2)
	local known: { [string]: boolean } = {}
	local queue: { { [string]: any } } = {}
	local function check()
		local coins = player:GetAttribute("Coins")
		for _, thing in things() do
			if not known[thing.Key] and Currency.CanAfford(coins, thing.Price) then
				known[thing.Key] = true
				if thing.Ok then
					table.insert(queue, thing)
				end
			end
		end
	end
	check()
	table.clear(queue)

	-- One note at a time; a thing you can't afford any more by its turn (you bought something) is dropped
	task.spawn(function()
		while true do
			task.wait(0.25)
			local thing = table.remove(queue, 1)
			if thing then
				while ThrowController.Blocked do -- the join intro
					task.wait(0.25)
				end
				local still = false
				for _, now in things() do
					if now.Key == thing.Key then
						still = Currency.CanAfford(player:GetAttribute("Coins"), now.Price)
					end
				end
				if still then
					show(thing.Name, thing.Icon, thing.Color)
					task.wait(SETTINGS.Gap)
				end
			end
		end
	end)

	local pending = false
	local function soon()
		if not pending then
			pending = true
			task.delay(0.3, function()
				pending = false
				check()
			end)
		end
	end
	for _, key in { "Coins", "ZonesOpen", "PowerLevel", "Rebirths", "RankLevel", "CratesBought" } do
		player:GetAttributeChangedSignal(key):Connect(soon)
	end
end

return AffordController
