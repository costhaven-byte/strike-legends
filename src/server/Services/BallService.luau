-- Ball inventory, equipping and crate opening. The server decides every drop.
-- Clients see their balls through Player attributes: EquippedBall (an Id) and OwnedBalls ("Rookie,Galaxy,...").
-- Everyone sees each player's equipped ball on their character: in their hand, as a trail, and (Rare+) an aura.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local ThrowRules = require(Shared.Modules.ThrowRules)
local BallLook = require(Shared.Modules.BallLook)
local Store = require(Shared.Modules.Store)
local Zones = require(Shared.Modules.Zones)
local Analytics = require(script.Parent.Analytics)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CrateRoller = require(script.Parent.Parent.Modules.CrateRoller)
local RateLimit = require(script.Parent.Parent.Modules.RateLimit)
local SessionLog = require(script.Parent.Parent.Modules.SessionLog)

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local BallService = {}

local pullBannerEvent: RemoteEvent? = nil -- Epic+ pull banners for the whole server (Config.PullBanner)
-- Set by StoreService: told about every crate ball (it offers a trail after a rare pull, Config.Monetization.Offers)
BallService.OnCratePull = nil :: ((Player, any) -> ())?

local busy: { [Player]: boolean } = {}

local function getOwned(player: Player): { [string]: boolean }
	return PlayerDataService.Get(player, "OwnedBalls") or {}
end

local function publishOwned(player: Player)
	player:SetAttribute("OwnedBalls", Balls.EncodeOwned(getOwned(player)))
end

-- The ball this player throws with (falls back to the starter ball if anything is off)
function BallService.GetEquipped(player: Player)
	return Balls.Get(PlayerDataService.Get(player, "EquippedBall")) or Balls.Get(Config.StartingData.EquippedBall)
end

-- Rebuilds the equipped-ball look on the player's character (made on the server so every player sees it)
local refreshCharacterBall
refreshCharacterBall = function(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hand = character
		and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")) :: BasePart?
	if not character or not root or not hand then
		return
	end
	local old = character:FindFirstChild("EquippedBallFx")
	if old then
		old:Destroy()
	end

	local ball = BallService.GetEquipped(player)
	local rarity = Balls.GetRarity(ball.Rarity)
	local fx = Config.BallFx
	-- The ball in your hand grows with your Power Level, like the one that rolls
	local heldSize = fx.HeldSize
		* Config.Throw.Levels[ThrowRules.Level(PlayerDataService.Get(player, "PowerLevel"))].Size
	local folder = Instance.new("Folder")
	folder.Name = "EquippedBallFx"

	-- The ball, held in the right hand
	local held = Instance.new("Part")
	held.Name = "HeldBall"
	held.Shape = Enum.PartType.Ball
	held.Size = Vector3.one * heldSize
	held.Color = ball.Color
	held.Material = ball.Material
	held.CanCollide = false
	held.CanQuery = false
	held.CanTouch = false
	held.Massless = true
	held.CFrame = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2 - heldSize * 0.35, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = held
	weld.Parent = held
	local glow = Instance.new("PointLight")
	glow.Color = ball.Trail
	glow.Range = 6
	glow.Brightness = 1
	glow.Parent = held
	held:SetAttribute("BallId", ball.Id) -- each client adds the ball's effects (BallFxController)
	held.Parent = folder
	BallLook.Apply(held, ball.Id)

	-- The ball's trail streaming behind the ball in your hand as you move
	local top = Instance.new("Attachment")
	top.Name = "BallTrailTop"
	top.Position = Vector3.new(0, heldSize * 0.45, 0)
	top.Parent = held
	local bottom = Instance.new("Attachment")
	bottom.Name = "BallTrailBottom"
	bottom.Position = Vector3.new(0, -heldSize * 0.45, 0)
	bottom.Parent = held
	local trail = Instance.new("Trail")
	trail.Name = "BallTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(ball.Trail)
	trail.Transparency = NumberSequence.new(0.35, 1)
	trail.WidthScale = NumberSequence.new(1, 0.1)
	trail.LightEmission = 0.4
	trail.Lifetime = fx.TrailLifetime
	trail.Parent = held

	-- Rare and better: a sparkle aura in the rarity colour, denser for rarer balls
	local steps = Balls.RarityIndex(ball.Rarity) - Balls.RarityIndex("Uncommon")
	if Balls.RarityIndex(ball.Rarity) >= Balls.RarityIndex(fx.AuraFromRarity) and steps > 0 then
		local aura = Instance.new("ParticleEmitter")
		aura.Name = "BallAura"
		aura.Texture = SPARKLE
		aura.Color = ColorSequence.new(rarity.Color, ball.Trail)
		aura.LightEmission = 1
		aura.Size = NumberSequence.new(0.5, 0)
		aura.Lifetime = NumberRange.new(0.8, 1.4)
		aura.Speed = NumberRange.new(1, 3)
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Rate = steps * fx.AuraRatePerRarity
		aura.Parent = root
		folder.Destroying:Connect(function()
			aura:Destroy()
		end)
	end

	folder.Parent = character

	-- Avatars finish loading after spawning and swap in a new hand, which drops the ball:
	-- put it back in the new hand (and if it ever goes missing on its own)
	local rebuilding = false
	local function rebuild()
		if rebuilding or not folder.Parent then
			return
		end
		rebuilding = true
		task.defer(function()
			if folder.Parent and player.Character == character then
				refreshCharacterBall(player)
			end
		end)
	end
	local handAdded = character.ChildAdded:Connect(function(child)
		if child.Name == hand.Name and child:IsA("BasePart") then
			rebuild()
		end
	end)
	local heldGone = held.AncestryChanged:Connect(function()
		if not held:IsDescendantOf(folder) then
			rebuild()
		end
	end)
	folder.Destroying:Connect(function()
		handAdded:Disconnect()
		heldGone:Disconnect()
	end)
end

-- Hides the ball in the player's hand while it rolls down the lane
function BallService.HideHeldBall(player: Player, seconds: number)
	local fx = player.Character and player.Character:FindFirstChild("EquippedBallFx")
	local held = fx and fx:FindFirstChild("HeldBall") :: BasePart?
	if not held or held:GetAttribute("Hidden") then
		return
	end
	-- Balls with a 3D model keep the plain part invisible; the model (and the client effects) hide instead
	local look = held:FindFirstChild("Look")
	held.Transparency = 1
	held.PointLight.Enabled = false
	held:SetAttribute("Hidden", true)
	held.BallTrail.Enabled = false
	if look then
		look.Parent = nil
	end
	task.delay(seconds, function()
		if held.Parent then
			held.Transparency = if look then 1 else 0
			held.PointLight.Enabled = true
			held:SetAttribute("Hidden", false)
			held.BallTrail.Enabled = true
			if look then
				look.Parent = held
			end
		end
	end)
end

local function onEquip(player: Player, ballId: any)
	if typeof(ballId) ~= "string" or not Balls.Get(ballId) or not RateLimit.Allow(player, "EquipBall") then
		return
	end
	if not getOwned(player)[ballId] then
		return
	end
	if PlayerDataService.Get(player, "EquippedBall") ~= ballId then
		PlayerDataService.Set(player, "EquippedBall", ballId)
		Analytics.Step(player, "Equipped Ball")
	end
end

local POLISH = Config.Economy.Polish

local function publishPolish(player: Player)
	player:SetAttribute("Polish", Balls.EncodePolish(PlayerDataService.Get(player, "Polish") or {}))
end

local function publishPity(player: Player)
	local pity = PlayerDataService.Get(player, "CratePity") or {}
	for _, crate in Config.Crates do
		for _, row in Balls.PityRows(crate.Id) do
			player:SetAttribute("Pity_" .. row.Key, pity[row.Key] or 0)
		end
	end
end

-- The ball's coin multiplier for this player, Polish included (used for every throw's payout)
function BallService.GetMultiplier(player: Player, ball): number
	local polish = PlayerDataService.Get(player, "Polish") or {}
	return Balls.Multiplier(ball, Balls.PolishLevel(polish[ball.Id]))
end

-- Gem sink (step 7b): buys the next Polish level of a ball the player owns with gems
-- (price: Balls.PolishGemPrice, from Config.Economy.Polish.GemPrice). Returns what the client shows.
local function onBuyPolish(player: Player, ballId: any)
	if not PlayerDataService.IsLoaded(player) or not RateLimit.Allow(player, "BuyPolish") then
		return { Ok = false, Error = "Try again" }
	end
	local ball = type(ballId) == "string" and Balls.Get(ballId)
	if not ball or not getOwned(player)[ball.Id] then
		return { Ok = false, Error = "You don't own that ball" }
	end
	local polish = PlayerDataService.Get(player, "Polish")
	if not polish then
		return { Ok = false, Error = "Try again" }
	end
	local level = Balls.PolishLevel(polish[ball.Id])
	local price = Balls.PolishGemPrice(ball, level)
	if not price then
		return { Ok = false, Error = "FULLY POLISHED" }
	end
	if (PlayerDataService.Get(player, "Gems") or 0) < price then
		return { Ok = false, Error = "Not enough gems" }
	end
	PlayerDataService.Add(player, "Gems", -price)
	polish[ball.Id] = (level + 1) * POLISH.PointsPerLevel
	publishPolish(player)
	if PlayerDataService.Get(player, "PolishHinted") ~= 1 then
		PlayerDataService.Set(player, "PolishHinted", 1) -- the Ball Book stops pointing at POLISH (Config.PolishHint)
	end
	Analytics.Currency(player, "Gems", -price, "Shop", "Polish" .. ball.Id)
	Analytics.Purchase(player, "Polish", ball.Id)
	Analytics.Event(player, "PolishLevel", level + 1, { ball.Id })
	SessionLog.Moment(player, ("Polish bought: %s level %d (%d gems)"):format(ball.Id, level + 1, price))
	return { Ok = true, Level = level + 1 }
end

-- Adds a ball to the player's collection, or turns a duplicate into Polish Points (coins once that ball is fully
-- polished). Returns isNew, the coins a sold duplicate paid, and the new Polish level (when a duplicate polished it).
local function addBall(player: Player, ball): (boolean, number, number?)
	local owned = getOwned(player)
	local isNew = not owned[ball.Id]
	local sellCoins = 0
	local polishLevel = nil
	if isNew then
		owned[ball.Id] = true
		publishOwned(player)
	else
		local polish = PlayerDataService.Get(player, "Polish") or {}
		local before = polish[ball.Id] or 0
		if Balls.PolishLevel(before) < POLISH.MaxLevel then
			-- Duplicate: Polish Points for this ball (+5% of its multiplier per level)
			polish[ball.Id] = before + POLISH.PointsPerDuplicate
			polishLevel = Balls.PolishLevel(polish[ball.Id])
			publishPolish(player)
			Analytics.Event(player, "PolishLevel", polishLevel, { ball.Id })
		else
			-- Fully polished already: sold for coins
			sellCoins = Balls.GetRarity(ball.Rarity).SellCoins
			PlayerDataService.Add(player, "Coins", sellCoins)
			Analytics.Currency(player, "Coins", sellCoins, "Gameplay", "DuplicateSold")
		end
	end
	return isNew, sellCoins, polishLevel
end

-- Gives one exact ball (no crate roll, no pity): the Robux Starter Pack. Returns isNew.
function BallService.GiveBall(player: Player, ballId: string): boolean
	local ball = Balls.Get(ballId)
	if not ball then
		return false
	end
	local isNew = addBall(player, ball)
	if isNew then
		SessionLog.Moment(player, ("Ball unlocked: %s (%s)"):format(ball.Id, ball.Rarity))
	end
	return isNew
end

-- Gives the player one crate's ball (no charge): rolls with this crate's pity, adds the ball, or turns a duplicate
-- into Polish Points (coins once that ball is fully polished).
-- Used for bought crates and free ones (like the daily reward). Returns the result the client shows.
-- minRarity: optional, the ball is at least this rare. exactRarity: optional, the ball is exactly this rarity (the gift
-- crate, the first bought crate). Without either, the very first crate a player ever opens is at least
-- Config.Economy.FirstCrateMin
function BallService.GiveCrate(player: Player, crate, minRarity: string?, exactRarity: string?)
	if not minRarity and not exactRarity and (PlayerDataService.Get(player, "CratesOpened") or 0) == 0 then
		minRarity = Config.Economy.FirstCrateMin
	end
	local pity = PlayerDataService.Get(player, "CratePity") or {}
	local ball, newCounts, fromPity = CrateRoller.Roll(crate, pity, minRarity, exactRarity, Store.Luck(player))
	for key, value in newCounts do
		pity[key] = value
		player:SetAttribute("Pity_" .. key, value)
	end
	PlayerDataService.Add(player, "CratesOpened", 1)
	-- An Epic or better pull: a banner for everyone in the server (Config.PullBanner), after the reveal
	local banner = Config.PullBanner
	if banner.Enabled and banner.Rarities[ball.Rarity] and pullBannerEvent then
		task.delay(banner.Delay, function()
			pullBannerEvent:FireAllClients({ Name = player.DisplayName, BallId = ball.Id })
		end)
	end

	local isNew, sellCoins, polishLevel = addBall(player, ball)
	if BallService.OnCratePull then
		task.spawn(BallService.OnCratePull, player, ball)
	end
	SessionLog.Crate(player)
	SessionLog.Moment(
		player,
		("Crate opened: %s -> %s (%s, %s)"):format(
			crate.Id,
			ball.Id,
			ball.Rarity,
			if isNew then "new" elseif polishLevel then "duplicate, Polish " .. polishLevel else "duplicate, sold"
		)
	)
	if isNew then
		SessionLog.Moment(player, ("Ball unlocked: %s (%s)"):format(ball.Id, ball.Rarity))
	end
	Analytics.Event(player, "CrateOpened", 1, { crate.Id, ball.Rarity, if isNew then "New" else "Duplicate" })
	if fromPity then
		Analytics.Event(player, "PityHit", 1, { crate.Id, ball.Rarity })
	end
	Analytics.Step(player, "Opened Crate")

	return {
		Ok = true,
		BallId = ball.Id,
		IsNew = isNew,
		SellCoins = sellCoins,
		PolishLevel = polishLevel, -- set when a duplicate polished the ball
		FromPity = fromPity,
	}
end

-- Free crates (Config.FreeCrates): saved as a count and opened from the shop whenever the player likes
function BallService.GiveFreeCrate(player: Player)
	PlayerDataService.Add(player, "FreeCrates", 1)
	SessionLog.Moment(player, "Free crate earned")
end

-- Counts a throw toward the next free crate (saved in the old CrateStrikes field). Returns true when this throw earned one.
function BallService.AddCrateThrow(player: Player): boolean
	local throws = (PlayerDataService.Get(player, "CrateStrikes") or 0) + 1
	local earned = throws >= Config.FreeCrates.ThrowsPerCrate
	PlayerDataService.Set(player, "CrateStrikes", if earned then 0 else throws)
	if earned then
		BallService.GiveFreeCrate(player)
	end
	return earned
end

local function openCrate(player: Player, crateId: any)
	local crate = typeof(crateId) == "string" and Balls.GetCrate(crateId)
	if not crate then
		return { Ok = false, Error = "Unknown crate" }
	end
	if not PlayerDataService.IsLoaded(player) then
		return { Ok = false, Error = "Still loading" }
	end
	if not Zones.CrateUnlocked(crate, PlayerDataService.Get(player, "ZonesOpen")) then
		return { Ok = false, Error = ("Unlocks in %s"):format(Zones.Name(crate.Zone)) }
	end
	-- A waiting free crate is used before any coins are spent
	local useFree = crate.Id == Config.FreeCrates.CrateId and (PlayerDataService.Get(player, "FreeCrates") or 0) > 0
	local bought = PlayerDataService.Get(player, "CratesBought") or 0
	local price = Balls.CratePrice(crate, bought)
	if not useFree and not PlayerDataService.CanAfford(player, "Coins", price) then
		return { Ok = false, Error = "Not enough coins" }
	end
	if not RateLimit.Allow(player, "OpenCrate") then
		return { Ok = false, Error = "Slow down!" }
	end

	if useFree then
		PlayerDataService.Add(player, "FreeCrates", -1)
		return BallService.GiveCrate(player, crate)
	end
	-- TRIPLE HATCH game pass: open 3 at once when the player can pay for all 3 (never the first bought crate)
	local count = Store.HatchCount(player)
	if count > 1 and (bought == 0 or not PlayerDataService.CanAfford(player, "Coins", price * count)) then
		count = 1
	end
	PlayerDataService.Spend(player, "Coins", price * count)
	PlayerDataService.Add(player, "CratesBought", count)
	Analytics.Currency(player, "Coins", -price * count, "Shop", crate.Id)
	Analytics.Purchase(player, "Crate", crate.Id)
	-- The first crate bought with coins is exactly Config.Onboarding.FirstBoughtRarity
	local best = BallService.GiveCrate(player, crate, nil, if bought == 0 then Config.Onboarding.FirstBoughtRarity else nil)
	if count == 1 then
		return best
	end
	-- The rarest of the 3 plays the big reveal; the others come along as Extras ({ BallId, IsNew })
	local extras = {}
	for _ = 2, count do
		local result = BallService.GiveCrate(player, crate)
		if Balls.RarityIndex(Balls.Get(result.BallId).Rarity) > Balls.RarityIndex(Balls.Get(best.BallId).Rarity) then
			result, best = best, result
		end
		table.insert(extras, { BallId = result.BallId, IsNew = result.IsNew })
	end
	best.Extras = extras
	return best
end

local function onOpenCrate(player: Player, crateId: any)
	if busy[player] then
		return { Ok = false, Error = "Slow down!" }
	end
	busy[player] = true
	local ok, result = pcall(openCrate, player, crateId)
	busy[player] = nil
	if not ok then
		warn("[BallService] Crate open failed: " .. tostring(result))
		return { Ok = false, Error = "Something went wrong" }
	end
	return result
end

function BallService:Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")

	pullBannerEvent = Instance.new("RemoteEvent")
	pullBannerEvent.Name = "PullBanner"
	pullBannerEvent.Parent = remotes

	local equip = Instance.new("RemoteEvent")
	equip.Name = "EquipBall"
	equip.Parent = remotes

	local open = Instance.new("RemoteFunction")
	open.Name = "OpenCrate"
	open.Parent = remotes

	local buyPolish = Instance.new("RemoteFunction")
	buyPolish.Name = "BuyPolish"
	buyPolish.Parent = remotes

	equip.OnServerEvent:Connect(onEquip)
	open.OnServerInvoke = onOpenCrate
	buyPolish.OnServerInvoke = onBuyPolish

	PlayerDataService.OnLoaded(function(player)
		-- Repair saves that point at a ball that no longer exists or isn't owned
		local owned = getOwned(player)
		owned[Config.StartingData.EquippedBall] = true
		local equipped = PlayerDataService.Get(player, "EquippedBall")
		if not Balls.Get(equipped) or not owned[equipped] then
			PlayerDataService.Set(player, "EquippedBall", Config.StartingData.EquippedBall)
		end
		publishOwned(player)
		publishPolish(player)
		publishPity(player)

		player:GetAttributeChangedSignal("EquippedBall"):Connect(function()
			refreshCharacterBall(player)
		end)
		player:GetAttributeChangedSignal("PowerLevel"):Connect(function()
			refreshCharacterBall(player)
		end)
		player.CharacterAdded:Connect(function(character)
			-- Wait for the root and a right hand (R15) or right arm (R6)
			local waited = 0
			while
				waited < 5
				and not (
					character:FindFirstChild("HumanoidRootPart")
					and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
				)
			do
				waited += task.wait(0.1)
			end
			-- Let the avatar finish loading first (it swaps body parts), up to a few seconds
			while waited < 5 and not player:HasAppearanceLoaded() do
				waited += task.wait(0.1)
			end
			refreshCharacterBall(player)
		end)
		refreshCharacterBall(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return BallService
