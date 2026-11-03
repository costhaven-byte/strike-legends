-- Builds the game pieces from ServerStorage.V2Zone3Kit (painted, flat; v2_zone3/paint.luau): station kits, Jungle
-- Egg altar + egg, 4 pets (one file each), hero props (temple ruin / rope bridge / giant tree / waterfall cliff,
-- placed by ZoneMaps at start). The display case is not used: only zone 1 has cases.
local SS, RS = game.ServerStorage, game.ReplicatedStorage
local KIT = SS.V2Zone3Kit
local report = {}
local function log(s) table.insert(report, s) end

local function rootAt(model: Model, name: string, at: Vector3, size: number?)
	local r = Instance.new("Part")
	r.Name = name
	r.Size = Vector3.one * (size or 0.4)
	r.Transparency = 1
	r.Anchored = true
	r.CanCollide = false
	r.CanQuery = false
	r.CanTouch = false
	r.CastShadow = false
	r.CFrame = CFrame.new(at)
	r.Parent = model
	model.PrimaryPart = r
	return r
end
-- small bits never block anyone
local function tidy(model: Model)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			if math.max(p.Size.X, p.Size.Y, p.Size.Z) < 1.5 or p.Transparency > 0.5 then
				p.CanCollide = false
				p.CanTouch = false
			end
		end
	end
end
-- copy with its pivot (a "Root" at the bottom centre, front -Z), moved to the origin, x scale
local function kitModel(src: string, newName: string, scale: number?): Model
	local m = KIT[src]:Clone()
	m.Name = newName
	local cf, s = m:GetBoundingBox()
	rootAt(m, "Root", Vector3.new(cf.X, cf.Y - s.Y / 2, cf.Z))
	m:PivotTo(CFrame.new())
	if scale and scale ~= 1 then
		m:ScaleTo(m:GetScale() * scale) -- (ScaleTo is absolute)
	end
	tidy(m)
	return m
end

-- 1. Station kits + hero props (server only)
local kits = SS:FindFirstChild("ZoneKits") or Instance.new("Folder")
kits.Name = "ZoneKits"
kits.Parent = SS
local z3 = kits:FindFirstChild("Zone3")
if z3 then z3:Destroy() end
z3 = Instance.new("Folder")
z3.Name = "Zone3"
z3.Parent = kits
kitModel("Z3_SellStall", "Sell").Parent = z3
kitModel("Z3_ShopStall_BallsAndBags", "Shop").Parent = z3
-- the closed doors (planks + studs + ring) and the barrier log hide once the gate is open
local gate = kitModel("Z3_Gate_CanyonOasis_Closed", "Gate")
local locks = 0
for _, p in gate:GetChildren() do
	if p.Name:match("^plank") or p.Name:match("^door_") or p.Name:match("^barrier_") then
		p:SetAttribute("GateLock", true)
		locks += 1
	end
end
gate.Parent = z3
log("gate lock parts " .. locks)

-- 2. Egg altar + egg (egg = egg_* parts except the dais, + the flower on top)
local eggSrc = KIT.Z3_Egg_JungleEgg_OnStand:Clone()
local eggParts, standParts = {}, {}
for _, p in eggSrc:GetChildren() do
	local isEgg = (p.Name:match("^egg_") and not p.Name:match("^egg_dais")) or p:GetAttribute("Group") == "egg_flower"
	if isEgg then table.insert(eggParts, p) else table.insert(standParts, p) end
end
local lo, hi = Vector3.one * 1e9, Vector3.one * -1e9
for _, p in eggParts do
	local h = p.Size / 2
	lo = lo:Min(p.Position - h)
	hi = hi:Max(p.Position + h)
end
local eggCentre, eggSize = (lo + hi) / 2, hi - lo
local eggModel = Instance.new("Model")
eggModel.Name = "Egg_Arcade"
eggModel:SetAttribute("Design", "SL_Z3_JungleEgg")
for _, p in eggParts do p.Parent = eggModel end
rootAt(eggModel, "Root", eggCentre, 0.35)
local stand = Instance.new("Model")
stand.Name = "JungleEgg"
local neon = Instance.new("Model")
neon.Name = "NeonStand" -- (the name every egg stand keeps: clients look for NeonStand.EggSpot)
for _, p in standParts do p.Parent = neon end
local spot = Instance.new("Part")
spot.Name = "EggSpot"
spot.Size = eggSize
spot.CFrame = CFrame.new(eggCentre)
spot.Transparency = 1
spot.Anchored = true
spot.CanCollide = false
spot.CanQuery = false
spot.CanTouch = false
spot.Parent = neon
neon.Parent = stand
local scf, ss = neon:GetBoundingBox()
local pad = rootAt(stand, "Pad", Vector3.new(scf.X, scf.Y - ss.Y / 2 + 0.1, scf.Z))
pad.Size = Vector3.new(ss.X, 0.2, ss.Z)
tidy(stand)
stand:PivotTo(CFrame.new())
stand.Parent = z3
eggModel:PivotTo(CFrame.new(0, 20, 0))
for _, p in eggModel:GetDescendants() do
	if p:IsA("BasePart") then
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end
end
eggSrc:Destroy()
log(("egg parts %d size %s, stand %s"):format(#eggParts, tostring(eggSize), tostring(ss)))

-- 3. Pets (one file each), matched by rarity to the Jungle Egg's Ids:
-- Tree Frog (Rare) = WoodPup, Toucan Tom (Epic) = ChromeBat, Temple Monkey (Legendary, crown) = Kingpin,
-- Jaguar Cub (Legendary, sun aura) = Blaze
local PETS = {
	{ Id = "WoodPup", Src = "PET_TreeFrog_Rare", Name = "TreeFrog" },
	{ Id = "ChromeBat", Src = "PET_ToucanTom_Epic", Name = "ToucanTom" },
	{ Id = "Kingpin", Src = "PET_TempleMonkey_Legendary", Name = "TempleMonkey" },
	{ Id = "Blaze", Src = "PET_JaguarCub_Legendary", Name = "JaguarCub" },
}
local pm = RS.PetModels
local backup = SS:FindFirstChild("PetModels_Backup_20261103") or Instance.new("Folder")
backup.Name = "PetModels_Backup_20261103"
backup.Parent = SS
for _, pet in PETS do
	local m = KIT[pet.Src]:Clone()
	m.Name = pet.Id
	m:SetAttribute("Design", "PET_" .. pet.Name)
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			p.CastShadow = true
		end
	end
	local cf = m:GetBoundingBox()
	rootAt(m, "Root", cf.Position, 0.36)
	m:PivotTo(CFrame.new(0, 20, 0))
	local old = pm:FindFirstChild(pet.Id)
	if old then
		if not backup:FindFirstChild(pet.Id) then old.Parent = backup else old:Destroy() end
	end
	m.Parent = pm
	local _, sz = m:GetBoundingBox()
	log(("pet %s (%s) parts %d size %s"):format(pet.Id, pet.Name, #m:GetChildren() - 1, tostring(sz)))
end
local oldEgg = pm:FindFirstChild("Egg_Arcade")
if oldEgg then
	if not backup:FindFirstChild("Egg_Arcade") then oldEgg.Parent = backup else oldEgg:Destroy() end
end
eggModel.Parent = pm

-- 4. Hero props, sized to the part-built ones they replace (ZoneMaps places them: ZoneKits.Zone3.<name>)
kitModel("Z3_Hero_TempleRuin", "TempleRuin", 1.25).Parent = z3
kitModel("Z3_Hero_GiantJungleTree", "GiantTree", 1.3).Parent = z3
kitModel("Z3_Hero_WaterfallCliff", "WaterfallCliff", 1.5).Parent = z3
-- the river bridge is walked on: its planks collide (rails are invisible parts ZoneMaps adds)
local bridge = kitModel("Z3_Hero_RopeBridge", "RopeBridge", 1)
local planks = 0
for _, p in bridge:GetChildren() do
	if p:IsA("BasePart") and p.Name:match("plank") then
		p.CanCollide = true
		p.CanTouch = true
		planks += 1
	end
end
bridge.Parent = z3
log("bridge walk planks " .. planks)
for _, n in { "TempleRuin", "GiantTree", "WaterfallCliff", "RopeBridge" } do
	local _, s = z3[n]:GetBoundingBox()
	log(n .. " size " .. tostring(s))
end
return table.concat(report, "\n")
