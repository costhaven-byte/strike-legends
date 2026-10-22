-- The zone 4 boss loop (Phase X Part 6, Config.Boss): the helicopter on the Skyline roof flies a player to the boss
-- arena once every CooldownMinutes (saved as BossNextAt), the fight runs (server/Modules/BossStub, a PLACEHOLDER),
-- a win pays Config.Boss.Reward (shown with the reward popup), then the helicopter brings the player back.
-- Attributes: BossNextAt (os.time the helicopter is ready), BossFighting (true during a trip), BossFightLeft.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Zones = require(Shared.Modules.Zones)
local Analytics = require(script.Parent.Analytics)
local MilestoneService = require(script.Parent.MilestoneService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local BossStub = require(script.Parent.Parent.Modules.BossStub)
local RateLimit = require(script.Parent.Parent.Modules.RateLimit)
local SessionLog = require(script.Parent.Parent.Modules.SessionLog)

local BOSS = Config.Boss

local BossService = {}

local fighting: { [Player]: boolean } = {}

local function find(path: { string }): Instance?
	local node: Instance? = Workspace
	for _, name in path do
		node = node and node:FindFirstChild(name)
	end
	return node
end

local function rootOf(player: Player): BasePart?
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function moveTo(player: Player, part: BasePart?)
	local root = rootOf(player)
	if root and part then
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = part.CFrame + Vector3.new(0, 4, 0)
	end
end

local function ride(player: Player)
	if not BOSS.Enabled or fighting[player] or not PlayerDataService.IsLoaded(player) then
		return { Ok = false, Error = "Not now" }
	end
	if not RateLimit.Allow(player, "RideHelicopter") then
		return { Ok = false, Error = "Slow down!" }
	end
	if not Zones.Unlocked(PlayerDataService.Get(player, "RankLevel"), BOSS.Zone) then
		return { Ok = false, Error = "Unlocks in " .. Zones.Name(BOSS.Zone) }
	end
	local pad = find(BOSS.Helipad)
	local arena = find(BOSS.Arena)
	local root = rootOf(player)
	local padPart = pad and (pad:FindFirstChild("Pad") or pad:FindFirstChildWhichIsA("BasePart", true)) :: BasePart?
	if not padPart or not arena or not root then
		return { Ok = false, Error = "The helicopter isn't here" }
	end
	if ((root.Position - padPart.Position) * Vector3.new(1, 0, 1)).Magnitude > BOSS.UseRange then
		return { Ok = false, Error = "Walk up to the helicopter" }
	end
	local now = os.time()
	local nextAt = PlayerDataService.Get(player, "BossNextAt") or 0
	if now < nextAt then
		return { Ok = false, Error = "The helicopter is refuelling" }
	end

	PlayerDataService.Set(player, "BossNextAt", now + BOSS.CooldownMinutes * 60)
	fighting[player] = true
	player:SetAttribute("BossFighting", true)
	SessionLog.Moment(player, "Boss trip")
	Analytics.Event(player, "BossTrip", 1)
	task.spawn(function()
		moveTo(player, arena:FindFirstChild("Spawn") :: BasePart?)
		local ok, won = pcall(BossStub.Run, player, arena)
		if not ok then
			warn("[BossService] boss fight failed: " .. tostring(won))
			won = false
		end
		if player.Parent and won then
			MilestoneService.Reward(player, BOSS.Reward, "Boss", "Boss")
			Analytics.Event(player, "BossWon", 1)
		end
		task.wait(BOSS.ReturnDelay)
		if player.Parent then
			moveTo(player, padPart)
			player:SetAttribute("BossFighting", false)
			player:SetAttribute("BossFightLeft", nil)
		end
		fighting[player] = nil
	end)
	return { Ok = true }
end

function BossService:Start()
	local remote = Instance.new("RemoteFunction")
	remote.Name = "RideHelicopter"
	remote.OnServerInvoke = function(player)
		local ok, result = pcall(ride, player)
		if not ok then
			warn("[BossService] " .. tostring(result))
			return { Ok = false, Error = "Something went wrong" }
		end
		return result
	end
	remote.Parent = ReplicatedStorage:WaitForChild("Remotes")
	Players.PlayerRemoving:Connect(function(player)
		fighting[player] = nil
	end)
end

return BossService
