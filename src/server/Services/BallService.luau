-- Ball inventory, equipping and crate opening. The server decides every drop.
-- Clients see their balls through Player attributes: EquippedBall (an Id) and OwnedBalls ("Rookie,Galaxy,...").
-- Everyone sees each player's equipped ball on their character: in their hand, as a trail, and (Rare+) an aura.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CrateRoller = require(script.Parent.Parent.Modules.CrateRoller)

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local CRATE_COOLDOWN = 1 -- seconds between crate opens, so spam-clicking can't flood the server

local BallService = {}

local busy: { [Player]: boolean } = {}
local lastOpen: { [Player]: number } = {}

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
local function refreshCharacterBall(player: Player)
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
	local folder = Instance.new("Folder")
	folder.Name = "EquippedBallFx"

	-- The ball, held in the right hand
	local held = Instance.new("Part")
	held.Name = "HeldBall"
	held.Shape = Enum.PartType.Ball
	held.Size = Vector3.one * fx.HeldSize
	held.Color = ball.Color
	held.Material = ball.Material
	held.CanCollide = false
	held.CanQuery = false
	held.CanTouch = false
	held.Massless = true
	held.CFrame = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2 - fx.HeldSize * 0.35, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = held
	weld.Parent = held
	local glow = Instance.new("PointLight")
	glow.Color = ball.Trail
	glow.Range = 6
	glow.Brightness = 1
	glow.Parent = held
	held.Parent = folder

	-- The ball's trail streaming behind you as you move
	local top = Instance.new("Attachment")
	top.Name = "BallTrailTop"
	top.Position = Vector3.new(0, -0.4, 0.4)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "BallTrailBottom"
	bottom.Position = Vector3.new(0, -2.2, 0.4)
	bottom.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(ball.Trail)
	trail.Transparency = NumberSequence.new(0.35, 1)
	trail.LightEmission = 0.4
	trail.Lifetime = fx.TrailLifetime
	trail.Parent = folder
	-- The attachments live on the root part, so tidy them up together with the folder
	folder.Destroying:Connect(function()
		top:Destroy()
		bottom:Destroy()
	end)

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
end

-- Hides the ball in the player's hand while it rolls down the lane
function BallService.HideHeldBall(player: Player, seconds: number)
	local fx = player.Character and player.Character:FindFirstChild("EquippedBallFx")
	local held = fx and fx:FindFirstChild("HeldBall") :: BasePart?
	if not held then
		return
	end
	held.Transparency = 1
	held.PointLight.Enabled = false
	task.delay(seconds, function()
		if held.Parent then
			held.Transparency = 0
			held.PointLight.Enabled = true
		end
	end)
end

local function onEquip(player: Player, ballId: any)
	if typeof(ballId) ~= "string" or not Balls.Get(ballId) then
		return
	end
	if not getOwned(player)[ballId] then
		return
	end
	PlayerDataService.Set(player, "EquippedBall", ballId)
end

-- Gives the player one crate's ball (no charge): rolls with pity, adds the ball or sells a duplicate.
-- Used for bought crates and free ones (like the daily reward). Returns the result the client shows.
function BallService.GiveCrate(player: Player, crate)
	local counters = {}
	for _, pity in Config.Pity do
		counters[pity.Counter] = PlayerDataService.Get(player, pity.Counter) or 0
	end
	local ball, newCounters, fromPity = CrateRoller.Roll(crate, counters)

	for counter, value in newCounters do
		PlayerDataService.Set(player, counter, value)
	end

	local owned = getOwned(player)
	local isNew = not owned[ball.Id]
	local sellCoins = 0
	if isNew then
		owned[ball.Id] = true
		publishOwned(player)
	else
		-- Duplicate: sold automatically
		sellCoins = Balls.GetRarity(ball.Rarity).SellCoins
		PlayerDataService.Add(player, "Coins", sellCoins)
	end

	return {
		Ok = true,
		BallId = ball.Id,
		IsNew = isNew,
		SellCoins = sellCoins,
		FromPity = fromPity,
	}
end

local function openCrate(player: Player, crateId: any)
	local crate = typeof(crateId) == "string" and Balls.GetCrate(crateId)
	if not crate then
		return { Ok = false, Error = "Unknown crate" }
	end
	if not PlayerDataService.IsLoaded(player) then
		return { Ok = false, Error = "Still loading" }
	end
	if os.clock() - (lastOpen[player] or 0) < CRATE_COOLDOWN then
		return { Ok = false, Error = "Slow down!" }
	end
	if (PlayerDataService.Get(player, "Coins") or 0) < crate.Price then
		return { Ok = false, Error = "Not enough coins" }
	end
	lastOpen[player] = os.clock()

	PlayerDataService.Add(player, "Coins", -crate.Price)
	return BallService.GiveCrate(player, crate)
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

	local equip = Instance.new("RemoteEvent")
	equip.Name = "EquipBall"
	equip.Parent = remotes

	local open = Instance.new("RemoteFunction")
	open.Name = "OpenCrate"
	open.Parent = remotes

	equip.OnServerEvent:Connect(onEquip)
	open.OnServerInvoke = onOpenCrate

	PlayerDataService.OnLoaded(function(player)
		-- Repair saves that point at a ball that no longer exists or isn't owned
		local owned = getOwned(player)
		owned[Config.StartingData.EquippedBall] = true
		local equipped = PlayerDataService.Get(player, "EquippedBall")
		if not Balls.Get(equipped) or not owned[equipped] then
			PlayerDataService.Set(player, "EquippedBall", Config.StartingData.EquippedBall)
		end
		publishOwned(player)

		player:GetAttributeChangedSignal("EquippedBall"):Connect(function()
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
			refreshCharacterBall(player)
		end)
		refreshCharacterBall(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
		lastOpen[player] = nil
	end)
end

return BallService
