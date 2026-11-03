-- Builds the game pieces from ServerStorage.V2Zone2Kit (painted, flat; v2_zone2/paint.luau): station kits, Sunset
-- Egg stand + egg, 5 pets, hero props (ferris wheel / lifeguard tower / lighthouse, placed by ZoneMaps at start)
local SS, RS = game.ServerStorage, game.ReplicatedStorage
local KIT = SS.V2Zone2Kit
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
local z2 = kits:FindFirstChild("Zone2")
if z2 then z2:Destroy() end
z2 = Instance.new("Folder")
z2.Name = "Zone2"
z2.Parent = kits
kitModel("Z2_SellStall", "Sell").Parent = z2
kitModel("Z2_ShopStall_BallsBags", "Shop").Parent = z2
local gate = kitModel("Z2_Gate_closed", "Gate")
local locks = 0
for _, p in gate:GetChildren() do
	local g = p:GetAttribute("Group")
	if g == "Door_L" or g == "Door_R" or g == "Barrier_Closed" then
		p:SetAttribute("GateLock", true)
		locks += 1
	end
end
gate.Parent = z2
log("gate lock parts " .. locks)

-- 2. Egg stand + egg (egg = the glb's "Egg" group)
local eggSrc = KIT.Z2_SunsetEgg_full:Clone()
local eggParts, standParts = {}, {}
for _, p in eggSrc:GetChildren() do
	if p:GetAttribute("Group") == "Egg" then table.insert(eggParts, p) else table.insert(standParts, p) end
end
local lo, hi = Vector3.one * 1e9, Vector3.one * -1e9
for _, p in eggParts do
	local h = p.Size / 2
	lo = lo:Min(p.Position - h)
	hi = hi:Max(p.Position + h)
end
local eggCentre, eggSize = (lo + hi) / 2, hi - lo
local eggModel = Instance.new("Model")
eggModel.Name = "Egg_Alley"
eggModel:SetAttribute("Design", "SL_Z2_SunsetEgg")
for _, p in eggParts do p.Parent = eggModel end
rootAt(eggModel, "Root", eggCentre, 0.35)
local stand = Instance.new("Model")
stand.Name = "SunsetEgg"
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
stand.Parent = z2
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

-- 3. Pets: split the lineup by each pet's own materials, the shared ones (eyes, blush, pearl) go to the nearest pet.
-- Lineup left to right = rarity: Pinch, Gully (Uncommon), Jellybop, Shellby (Rare), Surf Otter (Epic)
local PETS = {
	{ Id = "Pinny", Name = "Pinch", Mats = { "^crab_" } },
	{ Id = "LanePup", Name = "Gully", Mats = { "^gull_" } },
	{ Id = "Strikey", Name = "Jellybop", Mats = { "^jelly_" } },
	{ Id = "Splitz", Name = "Shellby", Mats = { "^hermit_" } },
	{ Id = "Hambone", Name = "SurfOtter", Mats = { "^otter_", "^visor_", "^necklace", "^shell_bead", "^sun_gold", "^surf_" } },
}
local line = KIT.Z2_Pets_Lineup:Clone()
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
	m:SetAttribute("Design", "SL_Z2_" .. pet.Name)
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
local oldEgg = pm:FindFirstChild("Egg_Alley")
if oldEgg then
	if not backup:FindFirstChild("Egg_Alley") then oldEgg.Parent = backup else oldEgg:Destroy() end
end
eggModel.Parent = pm

-- 4. Hero props, sized to the part-built ones they replace (ZoneMaps places them: ZoneKits.Zone2.<name>)
-- Ferris wheel x2 (~55 tall like the old one); its turning part = Wheel (rims, spokes, ties, bulbs, hub, sun) with
-- one Gondola model per cabin (they stay upright; client ZonePropsController turns them)
local wheel = kitModel("Z2_Hero_FerrisWheel", "FerrisWheel", 2)
local turning = Instance.new("Model")
turning.Name = "Wheel"
local bars = {}
for _, p in wheel:GetChildren() do
	if p:GetAttribute("Group") == "Wheel" and p.Name:match("^gondola_bar") then table.insert(bars, p) end
end
local gondolas = {}
for i, bar in bars do
	local g = Instance.new("Model")
	g.Name = "Gondola" -- (hangs from its gondola_bar, which rides round the rim)
	gondolas[i] = g
end
for _, p in wheel:GetChildren() do
	if p:IsA("BasePart") and p:GetAttribute("Group") == "Wheel" then
		local name = p.Name:gsub("%d+$", "")
		local isCabin = p.Name:match("^gondola_bar") or p.Name:match("^hanger_") or name == "roof" or name == "cabin"
			or name == "trim" or name == "floor"
		if isCabin then
			local best, bd = nil, math.huge
			for i, bar in bars do
				local d = (p.Position - bar.Position).Magnitude
				if d < bd then best, bd = i, d end
			end
			p.Parent = gondolas[best]
		else
			p.Parent = turning
		end
	end
end
for _, g in gondolas do g.Parent = turning end
game:GetService("CollectionService"):AddTag(turning, "SpinWheel")
turning:SetAttribute("Spin", 0.06) -- radians a second (one turn ~105 s), round the hub along the Root's look
turning.Parent = wheel
wheel.Parent = z2
log(("ferris: wheel %d parts, %d gondolas"):format(#turning:GetChildren() - #gondolas, #gondolas))

kitModel("Z2_Hero_LifeguardTower", "Lifeguard", 1.2).Parent = z2
kitModel("Z2_Hero_Lighthouse", "Lighthouse", 3.2).Parent = z2
for _, n in { "FerrisWheel", "Lifeguard", "Lighthouse" } do
	local _, s = z2[n]:GetBoundingBox()
	log(n .. " size " .. tostring(s))
end
return table.concat(report, "\n")
