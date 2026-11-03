-- Builds the game pieces from ServerStorage.V2Zone4Kit (painted, flat; v2_zone4/paint.luau): station kits, the
-- sandstone arch (zone 4's BACK gate: zone 4 is the last zone), Sun Egg pedestal + egg, 4 pets (one file each), hero
-- props (stone arch / golden sphinx / hoodoo / hot-air balloon, placed by ZoneMaps at start). The display case is not
-- used: only zone 1 has cases.
local SS, RS = game.ServerStorage, game.ReplicatedStorage
local KIT = SS.V2Zone4Kit
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

-- 1. Station kits (server only)
local kits = SS:FindFirstChild("ZoneKits") or Instance.new("Folder")
kits.Name = "ZoneKits"
kits.Parent = SS
local z4 = kits:FindFirstChild("Zone4")
if z4 then z4:Destroy() end
z4 = Instance.new("Folder")
z4.Name = "Zone4"
z4.Parent = kits
kitModel("Z4_SellStall", "Sell").Parent = z4
kitModel("Z4_ShopStall_BallsAndBags", "Shop").Parent = z4
-- the arch is the way back to zone 3 (always open): its turquoise doors, studs, straps and bar never show. The dark
-- strip on the destination board is blank in the file: hidden, the game writes JUNGLE FALLS on the board
local gate = kitModel("Z4_Gate_Closed", "Gate")
local locks = 0
for _, p in gate:GetChildren() do
	local n = p.Name
	if n:match("^door_") or n:match("^gold_stud") or n:match("^paint_chip") or n:match("^hinge_strap") or n:match("^barrier_") or n:match("^bar_bracket") then
		p:SetAttribute("GateLock", true)
		locks += 1
	elseif n == "sign_destination_text" then
		p:Destroy()
	end
end
gate.Parent = z4
log("gate lock parts " .. locks)

-- 2. Sun Egg pedestal + egg (the egg = sun_egg; the gold cup and claws stay on the pedestal)
local eggSrc = KIT.Z4_SunEgg_Eggonstand:Clone()
local eggParts, standParts = {}, {}
for _, p in eggSrc:GetChildren() do
	if p.Name == "sun_egg" then table.insert(eggParts, p) else table.insert(standParts, p) end
end
local lo, hi = Vector3.one * 1e9, Vector3.one * -1e9
for _, p in eggParts do
	local h = p.Size / 2
	lo = lo:Min(p.Position - h)
	hi = hi:Max(p.Position + h)
end
local eggCentre, eggSize = (lo + hi) / 2, hi - lo
local eggModel = Instance.new("Model")
eggModel.Name = "Egg_Skyline"
eggModel:SetAttribute("Design", "SL_Z4_SunEgg")
for _, p in eggParts do p.Parent = eggModel end
rootAt(eggModel, "Root", eggCentre, 0.35)
local stand = Instance.new("Model")
stand.Name = "SunEgg"
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
stand.Parent = z4
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

-- 3. Pets (one file each), same rarity and order as ASSET_PROMPTS_V2: Fennec (Epic) = CloudBumper, Cactus Pal
-- (Legendary) = SunnyHam, Scarab (Mythic) = Cosmo, Sphinx Kitten (Mythic) = Perfecto
local PETS = {
	{ Id = "CloudBumper", Src = "Z4_Pet_Fennec", Name = "Fennec" },
	{ Id = "SunnyHam", Src = "Z4_Pet_CactusPal", Name = "CactusPal" },
	{ Id = "Cosmo", Src = "Z4_Pet_Scarab", Name = "Scarab" },
	{ Id = "Perfecto", Src = "Z4_Pet_SphinxKitten", Name = "SphinxKitten" },
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
local oldEgg = pm:FindFirstChild("Egg_Skyline")
if oldEgg then
	if not backup:FindFirstChild("Egg_Skyline") then oldEgg.Parent = backup else oldEgg:Destroy() end
end
eggModel.Parent = pm

-- 4. Hero props at scale 1 (ZoneMaps places and sizes them: ZoneKits.Zone4.<name>)
kitModel("Z4_Hero_StoneArch", "StoneArch").Parent = z4
kitModel("Z4_Hero_GoldenSphinx", "GoldenSphinx").Parent = z4
kitModel("Z4_Hero_Hoodoo_A", "Hoodoo").Parent = z4
kitModel("Z4_Hero_HotAirBalloon", "Balloon").Parent = z4
for _, n in { "StoneArch", "GoldenSphinx", "Hoodoo", "Balloon" } do
	local _, s = z4[n]:GetBoundingBox()
	log(n .. " size " .. tostring(s))
end
-- where the sphinx's head is (its front) and the balloon envelope's middle (ZoneMaps hangs it from there)
local sph = z4.GoldenSphinx
log("sphinx head " .. tostring(sph.head.Position - sph.Root.Position))
local env = Vector3.zero
local gores = 0
for _, p in z4.Balloon:GetChildren() do
	if p.Name:match("^gore") then env += p.Position; gores += 1 end
end
log("balloon envelope centre " .. tostring(env / gores - z4.Balloon.Root.Position))
return table.concat(report, "\n")
