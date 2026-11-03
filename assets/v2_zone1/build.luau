-- Builds the game pieces from ServerStorage.V2Zone1Kit (painted, flat): station kits, pets, egg, display case, hero props
local SS, RS = game.ServerStorage, game.ReplicatedStorage
local KIT = SS.V2Zone1Kit
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
-- copy with its pivot (a "Root" at the bottom centre, front -Z), moved to the origin
local function kitModel(src: string, newName: string): Model
	local m = KIT[src]:Clone()
	m.Name = newName
	local cf, s = m:GetBoundingBox()
	local bottom = Vector3.new(cf.X, cf.Y - s.Y / 2, cf.Z)
	rootAt(m, "Root", bottom)
	m:PivotTo(CFrame.new())
	tidy(m)
	return m
end

-- 1. Station kits (server only: CoreLoopService clones them into zone 1's stations)
local kits = SS:FindFirstChild("ZoneKits") or Instance.new("Folder")
kits.Name = "ZoneKits"
local z1 = kits:FindFirstChild("Zone1")
if z1 then z1:Destroy() end
z1 = Instance.new("Folder")
z1.Name = "Zone1"
z1.Parent = kits
kits.Parent = SS
kitModel("Z1_SellStall", "Sell").Parent = z1
kitModel("Z1_ShopStall_BallsBags", "Shop").Parent = z1
local gate = kitModel("Z1_Gate_closed", "Gate")
local locks = 0
for _, p in gate:GetChildren() do
	local n = p.Name
	if n:match("^lock_") or n:match("^chain_") or n:match("^boom_seg") then
		p:SetAttribute("GateLock", true)
		locks += 1
	end
end
gate.Parent = z1
log("gate lock parts " .. locks)

-- 2. Egg stand + egg (egg parts = egg_* materials)
local eggSrc = KIT.Z1_RooftopEgg_full:Clone()
local eggParts, standParts = {}, {}
for _, p in eggSrc:GetChildren() do
	local mat = p:GetAttribute("Mat") or ""
	if mat:match("^egg_") then table.insert(eggParts, p) else table.insert(standParts, p) end
end
local lo, hi = Vector3.one * 1e9, Vector3.one * -1e9
for _, p in eggParts do
	local h = p.Size / 2
	lo = lo:Min(p.Position - h)
	hi = hi:Max(p.Position + h)
end
local eggCentre, eggSize = (lo + hi) / 2, hi - lo
local eggModel = Instance.new("Model")
eggModel.Name = "Egg_Speckled"
for _, p in eggParts do p.Parent = eggModel end
rootAt(eggModel, "Root", eggCentre, 0.35)
local stand = Instance.new("Model")
stand.Name = "RooftopEgg"
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
stand.Parent = z1
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
log(("egg size %s, stand %s"):format(tostring(eggSize), tostring(ss)))

-- 3. Pets: split the lineup by each pet's own materials, the shared ones (eyes, blush) go to the nearest pet
local PETS = {
	{ Id = "Gus", Name = "Pidge", Mats = { "^pidge_" } },
	{ Id = "Pebble", Name = "Gravel", Mats = { "^gravel_", "^hardhat_" } },
	{ Id = "Bumper", Name = "VentPuff", Mats = { "^puff_" } },
	{ Id = "Breezy", Name = "KitePup", Mats = { "^pup_" } },
	{ Id = "Sunspot", Name = "SolarCat", Mats = { "^cat_", "^sun_", "^solar_" } },
}
local line = KIT.Z1_Pets_Lineup:Clone()
local owner = {}
local sums = {}
for _, p in line:GetChildren() do
	local mat = p:GetAttribute("Mat") or ""
	for i, pet in PETS do
		for _, pat in pet.Mats do
			if mat:match(pat) then
				owner[p] = i
				sums[i] = sums[i] or { 0, 0 }
				sums[i][1] += p.Position.X
				sums[i][2] += 1
			end
		end
	end
end
local centres = {}
for i, s in sums do centres[i] = s[1] / s[2] end
for _, p in line:GetChildren() do
	if not owner[p] then
		local best, bd = 1, math.huge
		for i, x in centres do
			if math.abs(p.Position.X - x) < bd then best, bd = i, math.abs(p.Position.X - x) end
		end
		owner[p] = best
	end
end
local pm = RS.PetModels
local backup = SS:FindFirstChild("PetModels_Backup_20261103") or Instance.new("Folder")
backup.Name = "PetModels_Backup_20261103"
backup.Parent = SS
for i, pet in PETS do
	local m = Instance.new("Model")
	m.Name = pet.Id
	m:SetAttribute("Design", "SL_Z1_" .. pet.Name)
	local n = 0
	for p, who in owner do
		if who == i then
			p.Parent = m
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			p.CastShadow = true
			n += 1
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
	log(("pet %s (%s) parts %d size %s"):format(pet.Id, pet.Name, n, tostring(sz)))
end
line:Destroy()
local oldEgg = pm:FindFirstChild("Egg_Speckled")
if oldEgg then oldEgg:Destroy() end
eggModel.Parent = pm

-- 4. Display case (x 4/3 = the old roof case's 5.6 studs wide), pivot bottom centre, front -Z
local cases = RS.ShowcaseModels
local case = KIT.Z1_DisplayCase_Common:Clone()
case.Name = "Rooftop"
local ccf, cs = case:GetBoundingBox()
rootAt(case, "Root", Vector3.new(ccf.X, ccf.Y - cs.Y / 2, ccf.Z))
case:PivotTo(CFrame.new())
case:ScaleTo(case:GetScale() * (5.6 / cs.X))
case.Root:Destroy()
local slot = case:FindFirstChild("Ball_Slot")
if slot then slot.Name = "preview_ball" end
for _, p in case:GetChildren() do
	if p.Name:match("^glass_") then
		p.Material = Enum.Material.SmoothPlastic
		p.Transparency = 0.82
		p.Reflectance = 0.1
		p.CastShadow = false
	end
	p.Anchored = true
end
case.WorldPivot = CFrame.new()
local oldCase = cases:FindFirstChild("Rooftop")
if oldCase then oldCase:Destroy() end
case.Parent = cases
local _, csz = case:GetBoundingBox()
log("case size " .. tostring(csz))

-- 5. Hero props on the roof (Workspace.SkylineLanes.V2Props), floor top 848.65
local roof = workspace.SkylineLanes
local props = roof:FindFirstChild("V2Props")
if props then props:Destroy() end
props = Instance.new("Model")
props.Name = "V2Props"
local TOP = 848.65
local function place(src, name, x, z, turn)
	local m = kitModel(src, name)
	m:PivotTo(CFrame.new(x, TOP, z) * CFrame.Angles(0, math.rad(turn), 0))
	m.Parent = props
end
place("Z1_Hero_WaterTower", "WaterTower", 86, -3594, 180) -- behind the helipad, front toward the plaza
place("Z1_Hero_Billboard", "Billboard", -97, -3522, -90) -- west rail, its face toward the lane (+X)
place("Z1_Hero_PigeonCoop", "PigeonCoop", 84, -3397, 0) -- south-east corner of the plaza, front toward the lounges
props.Parent = roof
return table.concat(report, "\n")
