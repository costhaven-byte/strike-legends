-- The zone 4 boss event: the Pin Titan (owner's milestone 2026-10-26, Config.Boss holds every number).
-- One event for the whole server every EverySeconds: countdown + siren in the zone 4 lobby, BoardingSeconds to board
-- the helicopter on the Skyline roof, then everyone who boarded flies to the sky arena (Workspace.TitanArena) and
-- throws at the Titan with the normal hold-and-release throw (ThrowService hands boss throws to BossService.Throw).
-- Phases: ARMOR (plates) -> CORE (glowing core open) -> FINALE (damage fills the team meter) -> GIANT (every player's
-- next throw is a giant ball; together they finish it). FightSeconds is a hard cap: if the giant balls haven't
-- started by then, the Titan ESCAPES and the players lose (owner 2026-10-26; Config.Boss.LossRewardShare).
-- Then rewards by damage tier (+ top damage bonus + the boss-only drop), the results screen and the ride back.
-- Shared state for every client: attributes on ReplicatedStorage.BossEvent (State, OpensAt, BoardingEndsAt,
-- FightEndsAt, GiantEndsAt, Phase, Health, MaxHealth, Plates, Meter, MeterGoal, Fighters).
-- Per player: BossBoarded, BossFighting, BossSpot (the arena throw spot's name), BossDamage, BossGiant.
-- Nobody can touch anyone else's throw: each player has their own spot, ReadyAt and gold.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local Mascots = require(Shared.Modules.Mascots)
local ThrowRules = require(Shared.Modules.ThrowRules)
local Zones = require(Shared.Modules.Zones)
local Analytics = require(script.Parent.Analytics)
local BallService = require(script.Parent.BallService)
local MascotService = require(script.Parent.MascotService)
local MilestoneService = require(script.Parent.MilestoneService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RateLimit = require(script.Parent.Parent.Modules.RateLimit)
local SessionLog = require(script.Parent.Parent.Modules.SessionLog)

local BOSS = Config.Boss
local ATTACKS = BOSS.Attacks
local THROW = Config.Throw
local SWAY_WINDOW = 0.35 -- same as ThrowService: a release counts if it was in the gold this many seconds back

local BossService = {}

type Fighter = {
	Spot: Model,
	Damage: number,
	Hits: number,
	Streak: number,
	Giant: boolean, -- has a giant ball waiting
	GiantUsed: boolean,
	HitsTaken: number, -- times the Titan's attacks hit you
	SafeUntil: number, -- can't be hit again before this server time
}

local state: Folder
local eventRemote: RemoteEvent -- server -> client: Takeoff, Return, Throw, Hit, Plate, Results
local boarders: { [Player]: boolean } = {}
local fighters: { [Player]: Fighter } = {}
local phase = "None" -- None, Intro, Armor, Core, Finale, Giant, Defeated
local health, maxHealth, meter, meterGoal = 0, 0, 0, 0
local giantsInFlight = 0
local firstSlot = true

local function now(): number
	return Workspace:GetServerTimeNow()
end

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

local function padPart(): BasePart?
	local pad = find(BOSS.Helipad)
	return pad and (pad:FindFirstChild("Pad") or pad:FindFirstChildWhichIsA("BasePart", true)) :: BasePart?
end

local function setPhase(name: string)
	phase = name
	state:SetAttribute("Phase", name)
end

local function toFighters(kind: string, data: { [string]: any }?)
	for player in fighters do
		eventRemote:FireClient(player, kind, data)
	end
end

-- ===== The helicopter on the roof: only there while boarding =====
local heliParts: { [BasePart]: number } = {} -- each part's normal transparency
-- The code-built placeholder keeps its helicopter parts loose in the Helipad model: group them into a
-- "Helicopter" model the first time (a Studio-made Helicopter model is used as it is)
local LOOSE_PARTS = { Body = true, Glass = true, Tail = true, Rotor = true, Rotor2 = true, Skid = true }
local function helicopter(): Model?
	local pad = find(BOSS.Helipad)
	if not pad then
		return nil
	end
	local heli = pad:FindFirstChild("Helicopter") :: Model?
	if not heli then
		local loose = {}
		for _, child in pad:GetChildren() do
			if child:IsA("BasePart") and LOOSE_PARTS[child.Name] then
				table.insert(loose, child)
			end
		end
		if #loose == 0 then
			return nil
		end
		heli = Instance.new("Model")
		heli.Name = "Helicopter"
		for _, p in loose do
			p.Parent = heli
		end
		heli.Parent = pad
	end
	return heli
end

local function showHelicopter(on: boolean)
	local heli = helicopter()
	if not heli then
		return
	end
	for _, p in heli:GetDescendants() do
		if p:IsA("BasePart") then
			if heliParts[p] == nil then
				heliParts[p] = p.Transparency
			end
			p.Transparency = if on then heliParts[p] else 1
			p.CanCollide = on and p.Name == "Body"
		elseif p:IsA("Decal") or p:IsA("Texture") then
			p.Transparency = if on then 0 else 1
		end
	end
end

-- The helicopter lifts off and flies away (then hides and drops back onto the pad, unseen)
local function flyAway()
	local heli = helicopter()
	if not heli then
		return
	end
	local start = heli:GetPivot()
	local steps = math.max(1, math.floor(BOSS.FlightSeconds * 30))
	for i = 1, steps do
		local t = i / steps
		heli:PivotTo(
			start * CFrame.new(0, 40 * t * t, -120 * t * t * t) * CFrame.Angles(-0.25 * math.min(1, t * 3), 0, 0)
		)
		task.wait(1 / 30)
	end
	showHelicopter(false)
	heli:PivotTo(start)
end

-- ===== The arena and the Titan =====
local function arena(): Instance?
	return find(BOSS.Arena)
end

local function arenaSpots(): { Model }
	local folder = arena() and (arena() :: Instance):FindFirstChild("Spots")
	local list = {}
	for _, spot in if folder then folder:GetChildren() else {} do
		if spot:IsA("Model") and spot:FindFirstChild("BallStart") then
			table.insert(list, spot)
		end
	end
	table.sort(list, function(a, b)
		return (tonumber(a.Name:match("%d+")) or 0) < (tonumber(b.Name:match("%d+")) or 0)
	end)
	return list
end

local function titan(): Model?
	local a = arena()
	return a and a:FindFirstChild("Titan") :: Model?
end

local titanHome: CFrame? = nil
local plateLooks: { [BasePart]: number } = {}

local function plates(): { BasePart }
	local t = titan()
	local folder = t and t:FindFirstChild("Plates")
	local list = {}
	for _, p in if folder then folder:GetChildren() else {} do
		if p:IsA("BasePart") then
			table.insert(list, p)
		end
	end
	table.sort(list, function(a, b)
		return (tonumber(a.Name:match("%d+")) or 0) < (tonumber(b.Name:match("%d+")) or 0)
	end)
	return list
end

local function setCore(open: boolean)
	local t = titan()
	local core = t and t:FindFirstChild("Core") :: BasePart?
	if core then
		core.Transparency = if open then 0 else 0.6
		local light = core:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = open
		end
	end
end

-- Titan back to full: standing, every plate on, core closed
local function resetTitan()
	local t = titan()
	if not t then
		return
	end
	titanHome = titanHome or t:GetPivot()
	t:PivotTo(titanHome :: CFrame)
	for _, p in plates() do
		if plateLooks[p] == nil then
			plateLooks[p] = p.Transparency
		end
		p.Transparency = plateLooks[p]
	end
	setCore(false)
end

-- How many plates are still on at this health
local function platesLeft(): number
	local count = BOSS.Plates
	local coreLine = maxHealth * (1 - BOSS.ArmorShare)
	local per = maxHealth * BOSS.ArmorShare / count
	return math.clamp(math.ceil((health - coreLine) / per - 1e-6), 0, count)
end

local function updatePlates()
	local left = platesLeft()
	local list = plates()
	-- The model may have a different number of plates than Config: hide the same share of them
	local keep = math.ceil(#list * left / math.max(1, BOSS.Plates))
	for i, p in list do
		if i > keep and p.Transparency < 1 then
			p.Transparency = 1
			toFighters("Plate", { Position = p.Position })
		end
	end
	state:SetAttribute("Plates", left)
end

-- The Titan falls over backwards
local function topple()
	local t = titan()
	if not t then
		return
	end
	local start = t:GetPivot()
	local _, size = t:GetBoundingBox()
	local foot = start * CFrame.new(0, -size.Y / 2, 0)
	for i = 1, 45 do
		local k = i / 45
		local angle = math.rad(85) * k * k
		t:PivotTo(foot * CFrame.Angles(-angle, 0, 0) * foot:ToObjectSpace(start))
		task.wait(1 / 30)
	end
end

-- ===== Moving players =====
local function standOn(player: Player, spot: Model)
	local start = spot:FindFirstChild("BallStart") :: BasePart
	local pad = spot:FindFirstChild("Pad") :: BasePart?
	local at = (if pad then pad.Position else start.Position) + Vector3.new(0, 4, 0)
	local character = player.Character
	local root = rootOf(player)
	if character and root then
		root.AssemblyLinearVelocity = Vector3.zero
		local look = start.CFrame.LookVector * Vector3.new(1, 0, 1)
		character:PivotTo(CFrame.lookAt(at, at + look))
	end
end

local function backToRoof(player: Player, index: number)
	local pad = padPart()
	local character = player.Character
	if pad and character then
		local angle = index * 2.4
		local at = pad.Position + Vector3.new(math.cos(angle) * 10, 4, math.sin(angle) * 10)
		character:PivotTo(CFrame.new(at))
	end
end

local function inArena(player: Player): boolean
	local a = arena()
	local floor = a and a:FindFirstChild("Floor") :: BasePart?
	local root = rootOf(player)
	if not floor or not root then
		return false
	end
	local offset = root.Position - floor.Position
	local radius = math.max(floor.Size.Y, floor.Size.Z) / 2 + 10
	return Vector2.new(offset.X, offset.Z).Magnitude <= radius and offset.Y > -8 and offset.Y < 80
end

local function clearPlayer(player: Player)
	player:SetAttribute("BossBoarded", nil)
	player:SetAttribute("BossFighting", nil)
	player:SetAttribute("BossSpot", nil)
	player:SetAttribute("BossDamage", nil)
	player:SetAttribute("BossGiant", nil)
	player:SetAttribute("BossDazedUntil", nil)
	player:SetAttribute("BossStreak", nil)
end

-- ===== Damage =====
local function powerBonus(player: Player): number
	local level = ThrowRules.Level(PlayerDataService.Get(player, "PowerLevel"))
	return math.min(1 + BOSS.PowerBonusPerLevel * (level - 1), BOSS.PowerBonusMax)
end

local function streakBonus(streak: number): number
	return math.min(1 + BOSS.StreakBonus * math.max(streak - 1, 0), BOSS.StreakMax)
end

local function startGiant()
	if phase == "Giant" or phase == "Defeated" then
		return
	end
	setPhase("Giant")
	meter = meterGoal
	state:SetAttribute("Meter", meter)
	state:SetAttribute("GiantEndsAt", now() + BOSS.GiantSeconds)
	for player, f in fighters do
		f.Giant = true
		player:SetAttribute("BossGiant", true)
		local spot = f.Spot
		spot:SetAttribute("ReadyAt", 0) -- the giant ball is ready right away
	end
end

local function giantsLeft(): number
	local count = 0
	for _, f in fighters do
		if f.Giant and not f.GiantUsed then
			count += 1
		end
	end
	return count
end

-- Out of time: the Titan leaps off into the sky and the players lose
local function escape()
	if phase == "Defeated" or phase == "Escaped" then
		return
	end
	setPhase("Escaped")
	task.spawn(function()
		local t = titan()
		if not t then
			return
		end
		local start = t:GetPivot()
		for i = 1, 60 do
			local k = i / 60
			t:PivotTo(start + Vector3.new(0, 260 * k * k, -120 * k * k))
			task.wait(1 / 30)
		end
	end)
end

local function defeat()
	if phase == "Defeated" then
		return
	end
	health = 0
	state:SetAttribute("Health", 0)
	setPhase("Defeated")
	task.spawn(topple)
end

-- A ball reaches the Titan: apply the damage under the phase rules at that moment
local function land(player: Player, f: Fighter, base: number, kind: string)
	if phase == "Defeated" or fighters[player] ~= f then
		return
	end
	local damage = base
	if kind == "Giant" then
		-- Each giant ball takes its share of what's left; the last one finishes it
		damage = health / math.max(1, giantsLeft() + 1)
	elseif phase == "Armor" then
		if kind == "Normal" then
			damage *= BOSS.ArmorNormalShare
		end
	elseif phase == "Core" then
		if kind == "Perfect" then
			damage *= BOSS.CorePerfectBonus
		end
	end
	damage = math.floor(damage + 0.5)

	if kind == "Giant" then
		health = math.max(0, health - damage)
	elseif phase == "Armor" or phase == "Core" then
		local floor = maxHealth * BOSS.FinaleAt
		health = math.max(floor, health - damage)
		if phase == "Armor" and health <= maxHealth * (1 - BOSS.ArmorShare) then
			setPhase("Core")
			setCore(true)
		end
		if health <= floor then
			setPhase("Finale")
		end
		updatePlates()
	elseif phase == "Finale" then
		meter = math.min(meterGoal, meter + damage)
		state:SetAttribute("Meter", meter)
		if meter >= meterGoal then
			startGiant()
		end
	end
	state:SetAttribute("Health", health)

	f.Damage += damage
	f.Hits += 1
	player:SetAttribute("BossDamage", f.Damage)
	toFighters("Hit", { UserId = player.UserId, Damage = damage, Kind = kind })
	if kind == "Giant" and (health <= 0 or giantsLeft() == 0) then
		defeat()
	end
end

-- Called by ThrowService instead of a lane throw while the player is in the fight. charge: 0 to 1 of the bar.
function BossService.Throw(player: Player, charge: number)
	local f = fighters[player]
	if not f or not (phase == "Armor" or phase == "Core" or phase == "Finale" or phase == "Giant") then
		return
	end
	-- Throw from anywhere on the platform (the spot only keeps your cooldown and gold), never while DAZED
	local spot = f.Spot
	local root = rootOf(player)
	if not root or not inArena(player) then
		return
	end
	local t = now()
	if t < (player:GetAttribute("BossDazedUntil") or 0) then
		return
	end
	if t < (spot:GetAttribute("ReadyAt") or 0) or not RateLimit.Allow(player, "Throw") then
		return
	end

	local ball = BallService.GetEquipped(player)
	local kind, base
	if phase == "Giant" then
		if not f.Giant or f.GiantUsed then
			return
		end
		f.GiantUsed = true
		player:SetAttribute("BossGiant", nil)
		giantsInFlight += 1
		kind, base = "Giant", 0
	else
		local center = spot:GetAttribute("GoldCenter")
		local perfect = ThrowRules.WasInSpot(charge, ball, nil, t, SWAY_WINDOW, nil, center, f.Streak)
			or (
				Balls.TraitValue(ball, "Curve") > 0
				and ThrowRules.WasInSpot(charge, ball, nil, t, SWAY_WINDOW, true, center, f.Streak)
			)
		local multiplier = 1
		if perfect then
			kind, multiplier = "Perfect", BOSS.PerfectMultiplier
		elseif ThrowRules.InOvercharge(charge) then
			if math.random() < THROW.Overcharge.SuccessChance then
				kind, multiplier = "Blast", BOSS.OverchargeMultiplier
			else
				kind, multiplier = "Wasted", 0
			end
		else
			kind = "Normal"
		end
		f.Streak = if kind == "Perfect" or kind == "Blast" then f.Streak + 1 else 0
		local chargeFactor = BOSS.WeakestShare + (1 - BOSS.WeakestShare) * math.clamp(charge, 0, 1)
		if kind ~= "Normal" then
			chargeFactor = 1
		end
		base = BOSS.BaseDamage * chargeFactor * multiplier * powerBonus(player) * streakBonus(f.Streak)
		spot:SetAttribute("GoldCenter", ThrowRules.NextGoldCenter(center))
	end
	spot:SetAttribute("ReadyAt", t + THROW.ReleaseDelay + BOSS.BallTravel + BOSS.ThrowCooldown)
	player:SetAttribute("BossStreak", f.Streak)

	task.wait(THROW.ReleaseDelay) -- the arm swings down first
	if fighters[player] ~= f then
		return
	end
	toFighters("Throw", {
		UserId = player.UserId,
		Spot = spot.Name,
		From = root.Position + Vector3.new(0, 1.5, 0), -- the ball leaves from where you stand
		BallId = ball.Id,
		PowerLevel = ThrowRules.Level(PlayerDataService.Get(player, "PowerLevel")),
		Kind = kind,
		Streak = f.Streak,
		Travel = BOSS.BallTravel,
	})
	task.delay(BOSS.BallTravel, function()
		if kind == "Giant" then
			giantsInFlight -= 1
		end
		if kind ~= "Wasted" then
			land(player, f, base, kind)
		elseif fighters[player] == f then
			toFighters("Hit", { UserId = player.UserId, Damage = 0, Kind = kind })
		end
	end)
end

function BossService.InFight(player: Player): boolean
	return fighters[player] ~= nil
end

-- ===== The Titan attacks (Config.Boss.Attacks): it throws pins and rolls giant balls; the server checks the hits =====
local HIT = BOSS.Hit
local FIGHTING_PHASES = { Armor = true, Core = true, Finale = true, Giant = true }

-- The platform: its centre, its radius and the height of its top
local function floorInfo(): (Vector3, number, number)
	local a = arena()
	local floor = a and a:FindFirstChild("Floor") :: BasePart?
	if not floor then
		return Vector3.zero, 0, 0
	end
	local size = floor.Size
	local thickness = math.min(size.X, size.Y, size.Z)
	return floor.Position, math.max(size.X, size.Y, size.Z) / 2, floor.Position.Y + thickness / 2
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- The Titan turns to face where it's throwing
local function faceTitan(position: Vector3)
	local t = titan()
	local home = titanHome
	if not t or not home or phase == "Defeated" then
		return
	end
	local dir = flat(position - home.Position)
	if dir.Magnitude < 1 then
		return
	end
	local yaw = math.atan2(-dir.X, -dir.Z)
	local goal = CFrame.new(home.Position) * CFrame.Angles(0, yaw, 0) * home.Rotation
	local start = t:GetPivot()
	for i = 1, 6 do
		if phase == "Defeated" then
			return
		end
		t:PivotTo(start:Lerp(goal, i / 6))
		task.wait(1 / 30)
	end
end

-- Where the Titan's throws leave from (above its head)
local function throwFrom(): Vector3
	local center = floorInfo()
	local t = titan()
	local head = t and t:FindFirstChild("Head") :: BasePart?
	return if head then head.Position + Vector3.new(0, 8, 0) else center + Vector3.new(0, 60, 0)
end

-- Fighters standing in the arena, with their roots
local function targets(): { { Player: Player, Root: BasePart } }
	local list = {}
	for player in fighters do
		local root = rootOf(player)
		if root and inArena(player) then
			table.insert(list, { Player = player, Root = root })
		end
	end
	return list
end

-- A hit: knocked back (the player's own client does the shove), DAZED, PERFECT streak gone
local function struck(player: Player, from: Vector3)
	local f = fighters[player]
	local t = now()
	if not f or t < f.SafeUntil then
		return
	end
	f.SafeUntil = t + HIT.SafeSeconds
	f.HitsTaken += 1
	f.Streak = 0
	player:SetAttribute("BossStreak", 0)
	player:SetAttribute("BossDazedUntil", t + HIT.DazedSeconds)
	eventRemote:FireClient(player, "Struck", { From = from, Knockback = HIT.Knockback, Seconds = HIT.DazedSeconds })
end

-- Pins land on red circles after the warning; anyone inside a circle is hit
local function pins(spots: { Vector3 }, cfg)
	local impactAt = now() + cfg.Warning
	toFighters("Attack", {
		Kind = "Pins",
		Spots = spots,
		Radius = cfg.Radius,
		From = throwFrom(),
		ImpactAt = impactAt,
		Warning = cfg.Warning,
	})
	task.spawn(faceTitan, spots[1])
	task.wait(cfg.Warning)
	if not FIGHTING_PHASES[phase] then
		return
	end
	for _, entry in targets() do
		for _, spot in spots do
			if flat(entry.Root.Position - spot).Magnitude <= cfg.Radius - HIT.Leniency then
				struck(entry.Player, spot)
				break
			end
		end
	end
end

local function attack(kind: string)
	local list = targets()
	if #list == 0 then
		return
	end
	local center, radius, top = floorInfo()
	local function onFloor(v: Vector3): Vector3
		return Vector3.new(v.X, top, v.Z)
	end
	-- shuffle, so every player gets picked
	for i = #list, 2, -1 do
		local j = math.random(i)
		list[i], list[j] = list[j], list[i]
	end

	if kind == "PinToss" then
		local cfg = BOSS.PinToss
		local spots = {}
		for i = 1, math.max(1, math.ceil(#list / cfg.PlayersPerPin)) do
			table.insert(spots, onFloor(list[i].Root.Position))
		end
		pins(spots, cfg)
	elseif kind == "PinRain" then
		local cfg = BOSS.PinRain
		local spots = {}
		for i = 1, cfg.Count + cfg.PerPlayer * #list do
			local near = list[(i - 1) % #list + 1]
			local at
			if i <= #list then
				-- one close to each player (not right on top: they get a moment to see it)
				local angle = math.random() * math.pi * 2
				at = near.Root.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * math.random(0, 6)
			else
				local angle = math.random() * math.pi * 2
				local r = 20 + math.random() * (radius - 26)
				at = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * r
			end
			table.insert(spots, onFloor(at))
		end
		pins(spots, cfg)
	elseif kind == "BallRoll" then
		-- A giant ball rolls along a straight line across the platform, through the picked player's spot and
		-- around the Titan (never through it)
		local cfg = BOSS.BallRoll
		local rel = flat(list[1].Root.Position - center)
		local angle = math.random() * math.pi * 2
		local radial = if rel.Magnitude > 1 then rel.Unit else Vector3.new(math.cos(angle), 0, math.sin(angle))
		local r = math.clamp(rel.Magnitude, 22, radius - 8)
		local reach = math.sqrt(math.max(0, (radius - 2) ^ 2 - r * r))
		local tangent = radial:Cross(Vector3.yAxis) * (if math.random() < 0.5 then 1 else -1)
		local mid = center + radial * r
		local from = onFloor(mid - tangent * reach)
		local to = onFloor(mid + tangent * reach)
		local duration = (to - from).Magnitude / cfg.Speed
		local startsAt = now() + cfg.Warning
		toFighters("Attack", {
			Kind = "Roll",
			From = from,
			To = to,
			Width = cfg.Width,
			StartsAt = startsAt,
			Duration = duration,
			Warning = cfg.Warning,
		})
		task.spawn(faceTitan, from)
		task.wait(cfg.Warning)
		while FIGHTING_PHASES[phase] do
			local k = (now() - startsAt) / duration
			if k > 1 then
				break
			end
			local ball = from:Lerp(to, math.max(k, 0))
			for _, entry in targets() do
				if flat(entry.Root.Position - ball).Magnitude <= cfg.Width / 2 + 1 - HIT.Leniency then
					struck(entry.Player, ball)
				end
			end
			task.wait(0.05)
		end
	end
end

-- ===== Rewards =====
local function giveDrop(player: Player, rank: number)
	local drop = BOSS.Drop
	if not drop then
		return nil
	end
	local chance = if rank == 1 and drop.TopChance then drop.TopChance else drop.Chance
	if math.random() >= chance then
		return nil
	end
	if drop.Kind == "Pet" then
		local mascot = Mascots.Get(drop.Id)
		if mascot and MascotService.GiveMascot(player, drop.Id) ~= nil then
			return { Kind = "Pet", Id = drop.Id, Name = mascot.Name }
		end
	elseif drop.Kind == "Ball" then
		local ball = Balls.Get(drop.Id)
		if ball then
			BallService.GiveBall(player, drop.Id)
			return { Kind = "Ball", Id = drop.Id, Name = ball.Name }
		end
	elseif drop.Kind == "Crate" then
		local crate = Balls.GetCrate(drop.Id)
		if crate then
			return { Kind = "Crate", Id = drop.Id, Name = crate.Name, Crate = BallService.GiveCrate(player, crate) }
		end
	end
	return nil
end

local function payRewards(won: boolean)
	local list = {}
	local total = 0
	for player, f in fighters do
		if player.Parent then
			table.insert(list, { Player = player, F = f })
			total += f.Damage
		end
	end
	table.sort(list, function(a, b)
		return a.F.Damage > b.F.Damage
	end)
	local fair = math.max(1, total / math.max(1, #list))
	local rows = {}
	for rank, entry in list do
		table.insert(rows, {
			Name = entry.Player.DisplayName,
			UserId = entry.Player.UserId,
			Damage = entry.F.Damage,
			Rank = rank,
		})
	end
	local mines = {}
	for rank, entry in list do
		local player, f = entry.Player, entry.F
		local mine = { Rank = rank, Damage = f.Damage, Coins = 0, HitsTaken = f.HitsTaken }
		if f.Hits >= BOSS.MinHits and PlayerDataService.IsLoaded(player) then
			local share = f.Damage / fair
			local tier = BOSS.Tiers[1]
			for _, row in BOSS.Tiers do
				if share >= row.MinShare then
					tier = row
				end
			end
			mine.Tier = tier.Name
			-- A loss pays only LossRewardShare of the tier's coins: no crate, no top bonus, no drop
			local reward = tier.Reward
			if not won then
				local cut = BOSS.LossRewardShare
				reward = {
					Coins = (reward.Coins or 0) * cut,
					LevelShare = if reward.LevelShare then reward.LevelShare * cut else nil,
				}
			end
			local shown = if won or BOSS.LossRewardShare > 0
				then MilestoneService.Give(player, reward, "Boss")
				else { Coins = 0 }
			mine.Coins += shown.Coins or 0
			mine.Potions = shown.Potions
			mine.CrateId, mine.Crate = shown.CrateId, shown.Crate
			local top = BOSS.TopBonus[rank]
			if top and won then
				local bonus = MilestoneService.Give(player, top, "BossTop")
				mine.Coins += bonus.Coins or 0
				mine.TopBonus = bonus.Coins or 0
			end
			mine.Drop = if won then giveDrop(player, rank) else nil
			if mine.Drop then
				SessionLog.Moment(player, "Boss drop: " .. mine.Drop.Id)
				Analytics.Event(player, "BossDrop", 1, { mine.Drop.Id })
			end
			Analytics.Event(player, if won then "BossWon" else "BossLost", 1, { tier.Name })
			SessionLog.Moment(
				player,
				("Boss %s: %d damage, rank %d, %s"):format(if won then "won" else "over", f.Damage, rank, tier.Name)
			)
		end
		rows[rank].Tier = mine.Tier
		mine.Rows = rows
		mine.Won = won
		mines[player] = mine
	end
	-- Sent after every tier is known, so everyone's table is complete
	for player, mine in mines do
		eventRemote:FireClient(player, "Results", mine)
	end
end

-- ===== One event =====
local function runFight(list: { Player })
	local spotList = arenaSpots()
	if #spotList == 0 then
		warn("[BossService] no throw spots in the arena")
		return
	end
	resetTitan()
	for i, player in list do
		local spot = spotList[(i - 1) % #spotList + 1]
		spot:SetAttribute("ReadyAt", 0)
		spot:SetAttribute("GoldCenter", ThrowRules.NextGoldCenter())
		fighters[player] = {
			Spot = spot,
			Damage = 0,
			Hits = 0,
			Streak = 0,
			Giant = false,
			GiantUsed = false,
			HitsTaken = 0,
			SafeUntil = 0,
		}
		player:SetAttribute("BossDazedUntil", nil)
		player:SetAttribute("BossBoarded", nil)
		player:SetAttribute("BossFighting", true)
		player:SetAttribute("BossSpot", spot.Name)
		player:SetAttribute("BossDamage", 0)
		player:SetAttribute("BossStreak", 0)
		SessionLog.Moment(player, "Boss trip")
		Analytics.Event(player, "BossTrip", 1)
	end
	local count = #list
	maxHealth = math.max(BOSS.MinHealth, BOSS.HealthPerPlayer * count)
	health, meter, meterGoal = maxHealth, 0, BOSS.MeterPerPlayer * count
	giantsInFlight = 0
	state:SetAttribute("MaxHealth", maxHealth)
	state:SetAttribute("Health", health)
	state:SetAttribute("Meter", 0)
	state:SetAttribute("MeterGoal", meterGoal)
	state:SetAttribute("Plates", BOSS.Plates)
	state:SetAttribute("Fighters", count)
	state:SetAttribute("GiantEndsAt", nil)

	-- Take off: screens fade, the helicopter lifts away, everyone lands at their spot
	state:SetAttribute("State", "Fight")
	setPhase("Intro")
	toFighters("Takeoff", { Seconds = BOSS.FlightSeconds })
	task.spawn(flyAway)
	task.wait(BOSS.FlightSeconds)
	for player, f in fighters do
		standOn(player, f.Spot)
	end
	state:SetAttribute("FightEndsAt", now() + BOSS.IntroSeconds + BOSS.FightSeconds)
	task.wait(BOSS.IntroSeconds)
	setPhase("Armor")

	local outside: { [Player]: number } = {}
	local nextAttack = now() + ATTACKS.FirstAfter
	while phase ~= "Defeated" and phase ~= "Escaped" do
		task.wait(0.25)
		for player, f in fighters do
			if not player.Parent then
				fighters[player] = nil
			elseif not inArena(player) then
				-- Fell off, respawned or teleported away: back to your spot (after a moment, for a respawn)
				outside[player] = (outside[player] or 0) + 0.25
				if outside[player] >= 1 then
					outside[player] = 0
					standOn(player, f.Spot)
				end
			else
				outside[player] = nil
			end
		end
		if next(fighters) == nil then
			break -- everyone left the game
		end
		local t = now()
		-- The Titan attacks (not during the giant balls)
		local pattern = ATTACKS[phase]
		if pattern and t >= nextAttack then
			nextAttack = t + pattern.Every * (0.85 + math.random() * 0.3)
			local kind = pattern.Kinds[math.random(#pattern.Kinds)]
			task.spawn(function()
				local ok, err = pcall(attack, kind)
				if not ok then
					warn("[BossService] attack failed: " .. tostring(err))
				end
			end)
		end
		if phase ~= "Giant" and t >= (state:GetAttribute("FightEndsAt") or math.huge) then
			escape() -- out of time before the giant balls: the Titan gets away
		end
		if
			phase == "Giant"
			and giantsInFlight == 0
			and (giantsLeft() == 0 or t >= (state:GetAttribute("GiantEndsAt") or math.huge))
		then
			defeat()
		end
	end

	if next(fighters) ~= nil then
		task.wait(2.5) -- watch it fall (or fly off)
		state:SetAttribute("State", "Results")
		payRewards(phase == "Defeated")
		task.wait(BOSS.ResultsSeconds)
		toFighters("Return", { Seconds = BOSS.FlightSeconds })
		task.wait(BOSS.FlightSeconds * 0.6)
	end
	local index = 0
	for player in fighters do
		index += 1
		if player.Parent then
			backToRoof(player, index)
			clearPlayer(player)
		end
	end
	table.clear(fighters)
	setPhase("None")
	state:SetAttribute("FightEndsAt", nil)
	state:SetAttribute("GiantEndsAt", nil)
	task.delay(1, resetTitan)
end

-- The next event's opening time: on the EverySeconds clock (the same on every server)
local function nextSlot(): number
	local t = now()
	if firstSlot and RunService:IsStudio() and BOSS.StudioFirstEventIn > 0 then
		firstSlot = false
		return t + BOSS.StudioFirstEventIn + BOSS.SirenSeconds
	end
	firstSlot = false
	return math.ceil((t + 1) / BOSS.EverySeconds) * BOSS.EverySeconds
end

local function waitUntil(at: number)
	while now() < at do
		task.wait(math.min(1, math.max(0.05, at - now())))
	end
end

local function eventLoop()
	showHelicopter(false)
	while true do
		local opensAt = nextSlot()
		state:SetAttribute("State", "Waiting")
		state:SetAttribute("OpensAt", opensAt)
		state:SetAttribute("BoardingEndsAt", opensAt + BOSS.BoardingSeconds)
		waitUntil(opensAt)

		table.clear(boarders)
		state:SetAttribute("State", "Boarding")
		showHelicopter(true)
		waitUntil(opensAt + BOSS.BoardingSeconds)

		-- Boarding closes: who is still here and still by the helicopter?
		local pad = padPart()
		local list = {}
		for player in boarders do
			local root = rootOf(player)
			local near = pad
				and root
				and ((root.Position - pad.Position) * Vector3.new(1, 0, 1)).Magnitude <= BOSS.UseRange * 2
			if player.Parent and near then
				table.insert(list, player)
			else
				player:SetAttribute("BossBoarded", nil)
			end
		end
		table.clear(boarders)
		if #list < BOSS.MinPlayers then
			showHelicopter(false)
			for _, player in list do
				player:SetAttribute("BossBoarded", nil)
			end
			continue -- nobody came: try the next slot
		end
		local ok, err = pcall(runFight, list)
		if not ok then
			warn("[BossService] boss fight failed: " .. tostring(err))
			for player in fighters do
				if player.Parent then
					backToRoof(player, 1)
					clearPlayer(player)
				end
			end
			table.clear(fighters)
			setPhase("None")
		end
		showHelicopter(false)
	end
end

local function board(player: Player)
	if not BOSS.Enabled or not PlayerDataService.IsLoaded(player) then
		return { Ok = false, Error = "Not now" }
	end
	if not RateLimit.Allow(player, "RideHelicopter") then
		return { Ok = false, Error = "Slow down!" }
	end
	if state:GetAttribute("State") ~= "Boarding" then
		return { Ok = false, Error = "Boarding is closed" }
	end
	if not Zones.Unlocked(PlayerDataService.Get(player, "RankLevel"), BOSS.Zone) then
		return { Ok = false, Error = "Unlocks in " .. Zones.Name(BOSS.Zone) }
	end
	if boarders[player] then
		return { Ok = true }
	end
	local count = 0
	for _ in boarders do
		count += 1
	end
	if count >= BOSS.MaxPlayers then
		return { Ok = false, Error = "The helicopter is full" }
	end
	local pad = padPart()
	local root = rootOf(player)
	if not pad or not root then
		return { Ok = false, Error = "The helicopter isn't here" }
	end
	if ((root.Position - pad.Position) * Vector3.new(1, 0, 1)).Magnitude > BOSS.UseRange then
		return { Ok = false, Error = "Walk up to the helicopter" }
	end
	boarders[player] = true
	player:SetAttribute("BossBoarded", true)
	return { Ok = true }
end

function BossService:Start()
	state = Instance.new("Folder")
	state.Name = "BossEvent"
	state:SetAttribute("State", "Waiting")
	state:SetAttribute("Phase", "None")
	state.Parent = ReplicatedStorage

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	eventRemote = Instance.new("RemoteEvent")
	eventRemote.Name = "BossEvent"
	eventRemote.Parent = remotes
	local remote = Instance.new("RemoteFunction")
	remote.Name = "BoardHelicopter"
	remote.OnServerInvoke = function(player)
		local ok, result = pcall(board, player)
		if not ok then
			warn("[BossService] " .. tostring(result))
			return { Ok = false, Error = "Something went wrong" }
		end
		return result
	end
	remote.Parent = remotes

	Players.PlayerRemoving:Connect(function(player)
		boarders[player] = nil
		fighters[player] = nil
	end)
	if BOSS.Enabled then
		-- The arena is built at server start (PlaceholderWorldService); give it a moment
		task.delay(2, eventLoop)
	end
end

return BossService
