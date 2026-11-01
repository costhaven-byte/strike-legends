-- Rebirth (Phase X Part 6; Config.Economy.Rebirth, OFF until the owner sets Enabled = true). From the REBIRTH button
-- on the HUD (owner 2026-10-25: no station), once your level and coins are high enough: back to Power Level 1,
-- 0 coins AND rank level 1 / 0 XP / the first tier (owner 2026-10-29 batch D1 "full reset"; balls, pets, gems,
-- potions and zones stay) for a permanent coin and XP boost (Shared.Modules.Rebirth).
-- Owner 2026-10-27: rebirths open the zones (zone 2 = 1 rebirth, zone 3 = 3, zone 4 = 5; save ZonesOpen), and
-- open zones never lock again. Saved: Rebirths, ZonesOpen.
-- Addendum 5 step C (core loop, Config.CoreLoop.Rebirth): coins only, bought at the ball shop booth. Resets coins, the
-- bag (coins + level), the ball ladder and throw speed; keeps pets, pet slots and the count; the rebirth multiplier
-- lifts pins per swing and what a sell pays (CoreLoopService). Also: the REBIRTH tag over your head and your throw
-- spot's ring in the rebirth tier's colour (Config.CoreLoop.Rebirth Tiers), seen by everyone.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Currency = require(Shared.Modules.Currency)
local Rebirth = require(Shared.Modules.Rebirth)
local Zones = require(Shared.Modules.Zones)
local Analytics = require(script.Parent.Analytics)
local AwayService = require(script.Parent.AwayService)
local CoreLoopService = require(script.Parent.CoreLoopService)
local MascotService = require(script.Parent.MascotService)
local LaneUtil = require(Shared.Modules.LaneUtil)
local Players = game:GetService("Players")
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressionService = require(script.Parent.ProgressionService)
local RateLimit = require(script.Parent.Parent.Modules.RateLimit)
local SessionLog = require(script.Parent.Parent.Modules.SessionLog)

local REBIRTH = Config.Economy.Rebirth

local RebirthService = {}

-- ===== Addendum 5 step C: the core loop rebirth =====
local function coreRebirth(player: Player)
	if not PlayerDataService.IsLoaded(player) or not RateLimit.Allow(player, "Rebirth") then
		return { Ok = false, Error = "That didn't work. Try again" }
	end
	if not CoreLoopService.AtShop(player) then
		return { Ok = false, Error = "Rebirth at the ball shop" }
	end
	local done = PlayerDataService.Get(player, "Rebirths") or 0
	local price = Rebirth.CorePrice(done)
	if not PlayerDataService.CanAfford(player, "Coins", price) then
		return { Ok = false, Error = ("Need %s coins"):format(Currency.Format(price)) }
	end
	local before = PlayerDataService.Get(player, "Coins") or 0
	-- Start over: every coin goes (the price is part of them), the bag and both ladders go back to the start.
	-- Pets, Shiny pets, equipped pets and pet slots stay (KeepPetSlots), and the rebirth count goes up.
	PlayerDataService.Set(player, "Coins", Currency.Zero())
	CoreLoopService.ResetForRebirth(player)
	MascotService.ResetForRebirth(player)
	PlayerDataService.Set(player, "Rebirths", done + 1)
	AwayService.Reset(player)
	Analytics.Event(player, "Rebirth", done + 1)
	Analytics.Currency(player, "Coins", -price, "Shop", ("Rebirth%d"):format(done + 1))
	SessionLog.Moment(
		player,
		("Rebirth %d (paid %s, had %s, now x%s)"):format(
			done + 1,
			Currency.Format(price),
			Currency.Format(before),
			tostring(Rebirth.CoreMultiplier(done + 1))
		)
	)
	return { Ok = true, Rebirths = done + 1, Multiplier = Rebirth.CoreMultiplier(done + 1) }
end

-- The REBIRTH tag over a player's head (everyone sees it): "REBIRTH 3" in the tier's colour, nothing before rebirth 1
local function updateTag(player: Player)
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not head then
		return
	end
	local done = player:GetAttribute("Rebirths") or 0
	local tier = Rebirth.Tier(done)
	local tag = head:FindFirstChild("RebirthTag") :: BillboardGui?
	if not tier then
		if tag then
			tag:Destroy()
		end
		return
	end
	if not tag then
		local gui = Instance.new("BillboardGui")
		gui.Name = "RebirthTag"
		gui.Size = UDim2.fromOffset(170, 34)
		gui.StudsOffset = Vector3.new(0, 2.7, 0)
		gui.MaxDistance = 90
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Name = "Title"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(46, 36, 66)
		stroke.Thickness = 3
		stroke.Parent = label
		gui.Parent = head
		tag = gui
	end
	local label = (tag :: BillboardGui).Title :: TextLabel
	label.Text = ("★ REBIRTH %d"):format(done)
	label.TextColor3 = tier.Color
end

-- Your throw spot's ring (front spots have one) in your rebirth tier's colour; back to its own colour when you leave
local function paintSpots()
	for _, lane in LaneUtil.GetLanes() do
		local ring = lane:FindFirstChild("Ring") :: BasePart?
		if ring then
			if ring:GetAttribute("BaseColor") == nil then
				ring:SetAttribute("BaseColor", ring.Color)
			end
			local owner = Players:GetPlayerByUserId(lane:GetAttribute("OwnerId") or 0)
			local tier = owner and Rebirth.Tier(owner:GetAttribute("Rebirths"))
			ring.Color = if tier then tier.Color else ring:GetAttribute("BaseColor")
			ring.Material = if tier then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
end

local function startCore()
	local function watch(player: Player)
		player:GetAttributeChangedSignal("Rebirths"):Connect(function()
			updateTag(player)
			paintSpots()
		end)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			updateTag(player)
		end)
		if player.Character then
			updateTag(player)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	PlayerDataService.OnLoaded(function(player)
		updateTag(player)
		paintSpots()
	end)
	task.spawn(function()
		for _, lane in LaneUtil.GetLanes() do
			lane:GetAttributeChangedSignal("OwnerId"):Connect(paintSpots)
		end
		paintSpots()
	end)
end

local function rebirth(player: Player)
	if Rebirth.CoreOn() then
		return coreRebirth(player)
	end
	if not REBIRTH.Enabled or Config.CoreLoop.Enabled then -- (Addendum 4: the old zone rebirth is off; Stage 5 rebuilds it)
		return { Ok = false, Error = "Rebirth is coming soon" }
	end
	if not PlayerDataService.IsLoaded(player) or not RateLimit.Allow(player, "Rebirth") then
		return { Ok = false, Error = "That didn't work. Try again" }
	end
	if player:GetAttribute("TrialState") == "Active" then
		return { Ok = false, Error = "Finish your rank trial first" }
	end
	local done = PlayerDataService.Get(player, "Rebirths") or 0
	if (PlayerDataService.Get(player, "RankLevel") or 1) < Rebirth.Level(done) then
		return { Ok = false, Error = ("Reach level %d first"):format(Rebirth.Level(done)) }
	end
	local cost = Rebirth.Cost(done)
	if not PlayerDataService.CanAfford(player, "Coins", cost) then
		return { Ok = false, Error = ("Need %s coins"):format(Currency.Format(cost)) }
	end

	-- Start over (the cost is part of the coins that go). Level, XP and rank go too (owner 2026-10-29, batch D1;
	-- was kept since 2026-10-27); best-ever level and rank stay, so no level reward pays twice.
	PlayerDataService.Set(player, "Coins", Currency.Zero())
	PlayerDataService.Set(player, "PowerLevel", 1)
	ProgressionService.ResetForRebirth(player)
	PlayerDataService.Set(player, "Rebirths", done + 1)
	local opened = Rebirth.OpensZone(done)
	PlayerDataService.Set(
		player,
		"ZonesOpen",
		math.max(PlayerDataService.Get(player, "ZonesOpen") or 1, Zones.ForRebirths(done + 1))
	)
	AwayService.Reset(player)
	Analytics.Event(player, "Rebirth", done + 1)
	SessionLog.Moment(player, ("Rebirth %d"):format(done + 1))
	return { Ok = true, Rebirths = done + 1, Zone = opened }
end

function RebirthService:Start()
	local remote = Instance.new("RemoteFunction")
	remote.Name = "Rebirth"
	remote.OnServerInvoke = function(player)
		local ok, result = pcall(rebirth, player)
		if not ok then
			warn("[RebirthService] " .. tostring(result))
			return { Ok = false, Error = "That didn't work. Try again" }
		end
		return result
	end
	remote.Parent = ReplicatedStorage:WaitForChild("Remotes")
	if Rebirth.CoreOn() then
		startCore()
	end
end

return RebirthService
