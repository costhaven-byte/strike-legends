-- Ball inventory, equipping and crate opening. The server decides every drop.
-- Clients see their balls through Player attributes: EquippedBall (an Id) and OwnedBalls ("Rookie,Galaxy,...").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CrateRoller = require(script.Parent.Parent.Modules.CrateRoller)

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
	end)

	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
		lastOpen[player] = nil
	end)
end

return BallService
