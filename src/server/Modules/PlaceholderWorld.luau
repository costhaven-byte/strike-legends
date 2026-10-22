-- Phase X placeholder world pieces, built in code so they live in git (2026-10-22: Studio closed the place during a
-- test before they were saved). PlaceholderWorldService builds each one at server start ONLY if it isn't already in
-- the place, so a real design saved in Studio under the same name always wins.
--   Zone 3 (Workspace.MainStreetLanes): EggPad (Main Street Egg stand), FusionStation, CrateShop, Showcase (7 case
--   slots + pet shelf). Zone 4 (Workspace.SkylineLanes): EggPad (Skyline Egg stand), CrateShop, RebirthStation,
--   Helipad (+ helicopter), Showcase (6 slots + pet shelf). Workspace.BossArena (stub arena + giant pin).
local Workspace = game:GetService("Workspace")

local PlaceholderWorld = {}

local TITLE_FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- Text on both faces of a sign part
local function signText(p: BasePart, text: string, color: Color3)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextScaled = true
		label.FontFace = TITLE_FONT
		label.TextColor3 = color
		label.Parent = gui
		gui.Parent = p
	end
end

-- A counter with two posts and a lit sign; the client puts its prompt on "Counter"
local function booth(
	parent: Instance,
	name: string,
	pos: Vector3,
	width: number,
	color: Color3,
	accent: Color3,
	title: string,
	crates: boolean?
): Model
	local m = Instance.new("Model")
	m.Name = name
	local base = CFrame.new(pos)
	local counter = part(m, "Counter", Vector3.new(width, 4, 3), base * CFrame.new(0, 2, 0), color, Enum.Material.Wood)
	part(m, "Top", Vector3.new(width + 0.6, 0.4, 3.6), base * CFrame.new(0, 4.2, 0), accent, Enum.Material.Metal)
	for _, x in { -(width / 2 - 0.4), width / 2 - 0.4 } do
		part(m, "Post", Vector3.new(0.6, 8, 0.6), base * CFrame.new(x, 8, 0.8), accent, Enum.Material.Metal)
	end
	local sign =
		part(m, "Sign", Vector3.new(width, 2.4, 0.4), base * CFrame.new(0, 12.6, 0.8), Color3.fromRGB(25, 20, 35))
	signText(sign, title, accent)
	local light = Instance.new("PointLight")
	light.Color = accent
	light.Range = 14
	light.Brightness = 1.2
	light.Parent = sign
	if crates then
		for i, x in { -3, 0, 3 } do
			local crate = part(
				m,
				"Crate" .. i,
				Vector3.new(2, 2, 2),
				base * CFrame.new(x, 5.4, 0) * CFrame.Angles(0, math.rad(15 * i), 0),
				accent,
				Enum.Material.Metal
			)
			crate.CanCollide = false
		end
	end
	m.PrimaryPart = counter
	m.Parent = parent
	return m
end

-- A copy of the lobby's egg stand (Workspace.Hub.EggPad), repainted: pinks to colour A, blues to colour B
local function eggStand(parent: Instance, pos: Vector3, colorA: Color3, colorB: Color3, title: string)
	local hub = Workspace:FindFirstChild("Hub")
	local source = hub and hub:FindFirstChild("EggPad")
	if not source then
		warn("[PlaceholderWorld] Workspace.Hub.EggPad is missing, so the " .. title .. " stand can't be copied")
		return
	end
	local pad = source:Clone()
	pad.Name = "EggPad"
	pad:PivotTo(CFrame.new(pos) * source:GetPivot().Rotation)
	for _, d in pad:GetDescendants() do
		if d:IsA("BasePart") then
			local h, s, v = d.Color:ToHSV()
			if s > 0.35 and v > 0.3 then
				d.Color = if h > 0.75 or h < 0.1 then colorA else colorB
			end
		elseif d:IsA("TextLabel") then
			d.Text = title
		elseif d:IsA("Light") then
			d.Color = colorA
		end
	end
	pad.Parent = parent
end

-- Invisible case slots (Order = best ball first) and a pet shelf, for ShowcaseController
local function showcase(
	parent: Instance,
	slotCFrames: { CFrame },
	shelfCFrame: CFrame,
	shelfColor: Color3,
	shelfMaterial: Enum.Material
)
	local folder = Instance.new("Folder")
	folder.Name = "Showcase"
	local slots = Instance.new("Folder")
	slots.Name = "Slots"
	slots.Parent = folder
	for i, cf in slotCFrames do
		local slot = part(slots, "Slot" .. i, Vector3.new(5, 0.2, 5), cf, Color3.new(1, 1, 1))
		slot.Transparency = 1
		slot.CanCollide = false
		slot.CanQuery = false
		slot.CanTouch = false
		slot:SetAttribute("Order", i)
	end
	part(folder, "MascotShelf", Vector3.new(14, 0.4, 1.6), shelfCFrame, shelfColor, shelfMaterial)
	folder.Parent = parent
end

local function helipad(parent: Instance, padPos: Vector3)
	local heli = Instance.new("Model")
	heli.Name = "Helipad"
	local dark = Color3.fromRGB(45, 45, 55)
	local up = CFrame.Angles(0, 0, math.rad(90))
	local pad = part(
		heli,
		"Pad",
		Vector3.new(0.4, 22, 22),
		CFrame.new(padPos + Vector3.new(0, 0.2, 0)) * up,
		dark,
		Enum.Material.Concrete,
		Enum.PartType.Cylinder
	)
	part(
		heli,
		"Ring",
		Vector3.new(0.42, 20, 20),
		pad.CFrame,
		Color3.fromRGB(245, 184, 46),
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	part(
		heli,
		"RingCut",
		Vector3.new(0.44, 18.6, 18.6),
		pad.CFrame,
		dark,
		Enum.Material.Concrete,
		Enum.PartType.Cylinder
	)
	for _, bar in { { -3, 1, 8 }, { 3, 1, 8 }, { 0, 6, 1 } } do
		part(
			heli,
			"H",
			Vector3.new(bar[2], 0.1, bar[3]),
			CFrame.new(padPos + Vector3.new(bar[1], 0.45, 0)),
			Color3.new(1, 1, 1),
			Enum.Material.Neon
		)
	end
	local pink = Color3.fromRGB(255, 79, 139)
	local black = Color3.fromRGB(30, 30, 35)
	local look = {
		part(heli, "Body", Vector3.new(6, 5, 11), CFrame.new(padPos + Vector3.new(0, 4.5, 4)), pink),
		part(
			heli,
			"Glass",
			Vector3.new(5.6, 3, 3),
			CFrame.new(padPos + Vector3.new(0, 5.3, -0.5)),
			Color3.fromRGB(150, 220, 255),
			Enum.Material.Glass
		),
		part(heli, "Tail", Vector3.new(1.5, 1.5, 10), CFrame.new(padPos + Vector3.new(0, 5.5, 14)), pink),
		part(
			heli,
			"Rotor",
			Vector3.new(18, 0.3, 1),
			CFrame.new(padPos + Vector3.new(0, 7.6, 4)),
			black,
			Enum.Material.Metal
		),
		part(
			heli,
			"Rotor2",
			Vector3.new(1, 0.3, 18),
			CFrame.new(padPos + Vector3.new(0, 7.6, 4)),
			black,
			Enum.Material.Metal
		),
	}
	for _, x in { -2.5, 2.5 } do
		table.insert(
			look,
			part(
				heli,
				"Skid",
				Vector3.new(0.4, 0.4, 10),
				CFrame.new(padPos + Vector3.new(x, 1.2, 4)),
				black,
				Enum.Material.Metal
			)
		)
	end
	for _, p in look do
		p.CanCollide = p.Name == "Body"
	end
	look[2].Transparency = 0.3
	heli.PrimaryPart = pad
	heli.Parent = parent
end

local function bossArena(center: Vector3)
	local arena = Instance.new("Model")
	arena.Name = "BossArena"
	local floor = part(
		arena,
		"Floor",
		Vector3.new(120, 4, 120),
		CFrame.new(center),
		Color3.fromRGB(40, 30, 60),
		Enum.Material.Slate
	)
	part(
		arena,
		"Edge",
		Vector3.new(124, 1, 124),
		CFrame.new(center - Vector3.new(0, 1.6, 0)),
		Color3.fromRGB(255, 79, 139),
		Enum.Material.Neon
	)
	part(
		arena,
		"Spawn",
		Vector3.new(8, 0.4, 8),
		CFrame.new(center + Vector3.new(0, 2.2, 45)),
		Color3.fromRGB(245, 184, 46),
		Enum.Material.Neon
	).CanCollide =
		false
	-- Placeholder boss: a giant pin with red eyes (no gameplay yet)
	local boss = Instance.new("Model")
	boss.Name = "Boss"
	local white = Color3.fromRGB(245, 245, 250)
	local up = CFrame.Angles(0, 0, math.rad(90))
	local at = center + Vector3.new(0, 0, -20)
	part(
		boss,
		"Body",
		Vector3.new(30, 14, 14),
		CFrame.new(at + Vector3.new(0, 17, 0)) * up,
		white,
		nil,
		Enum.PartType.Cylinder
	)
	part(
		boss,
		"Neck",
		Vector3.new(10, 8, 8),
		CFrame.new(at + Vector3.new(0, 36, 0)) * up,
		white,
		nil,
		Enum.PartType.Cylinder
	)
	part(boss, "Head", Vector3.new(12, 12, 12), CFrame.new(at + Vector3.new(0, 44, 0)), white, nil, Enum.PartType.Ball)
	for _, y in { 31, 34 } do
		part(
			boss,
			"Band",
			Vector3.new(1.2, 10.4, 10.4),
			CFrame.new(at + Vector3.new(0, y, 0)) * up,
			Color3.fromRGB(220, 30, 50),
			nil,
			Enum.PartType.Cylinder
		)
	end
	for _, x in { -2.5, 2.5 } do
		part(
			boss,
			"Eye",
			Vector3.new(2, 2.5, 1),
			CFrame.new(at + Vector3.new(x, 45, 5.8)),
			Color3.fromRGB(255, 50, 80),
			Enum.Material.Neon
		)
	end
	boss.Parent = arena
	local sign =
		part(arena, "Sign", Vector3.new(40, 6, 1), CFrame.new(at + Vector3.new(0, 58, 0)), Color3.fromRGB(25, 20, 35))
	signText(sign, "BOSS (PLACEHOLDER)", Color3.fromRGB(255, 79, 139))
	arena.PrimaryPart = floor
	arena.Parent = Workspace
end

-- Builds whatever is missing. Returns the names it built.
function PlaceholderWorld.Build(): { string }
	local built = {}
	local function need(parent: Instance?, name: string, build: () -> ())
		if parent and not parent:FindFirstChild(name) then
			local ok, err = pcall(build)
			if ok then
				table.insert(built, parent.Name .. "." .. name)
			else
				warn(("[PlaceholderWorld] %s.%s failed: %s"):format(parent.Name, name, tostring(err)))
			end
		end
	end

	-- Zone 3: the back walkway behind the bowler seats (x 73-167, z 37-56, floor y 1)
	local street = Workspace:FindFirstChild("MainStreetLanes")
	need(street, "EggPad", function()
		eggStand(
			street :: Instance,
			Vector3.new(86, 1.2, 47),
			Color3.fromRGB(224, 165, 38),
			Color3.fromRGB(150, 30, 40),
			"MAIN STREET EGG"
		)
	end)
	need(street, "FusionStation", function()
		local m = booth(
			street :: Instance,
			"FusionStation",
			Vector3.new(100, 1, 50),
			8,
			Color3.fromRGB(70, 60, 90),
			Color3.fromRGB(190, 120, 255),
			"PET FUSION"
		)
		part(
			m,
			"Core",
			Vector3.new(1.8, 1.8, 1.8),
			CFrame.new(100, 6.3, 50),
			Color3.fromRGB(200, 140, 255),
			Enum.Material.Neon,
			Enum.PartType.Ball
		).CanCollide =
			false
		for _, x in { -2.6, 2.6 } do
			local pod = part(
				m,
				"Pod",
				Vector3.new(1.6, 2.2, 1.6),
				CFrame.new(100 + x, 5.5, 50) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(160, 220, 255),
				Enum.Material.Glass,
				Enum.PartType.Cylinder
			)
			pod.Transparency = 0.4
			pod.CanCollide = false
		end
	end)
	need(street, "CrateShop", function()
		booth(
			street :: Instance,
			"CrateShop",
			Vector3.new(112, 1, 50),
			10,
			Color3.fromRGB(110, 70, 40),
			Color3.fromRGB(224, 165, 38),
			"CRATES",
			true
		)
	end)
	need(street, "Showcase", function()
		local slots = {}
		for i = 1, 7 do
			slots[i] = CFrame.new(124 + 6 * (i - 1), 1.1, 52.6) -- facing -Z, toward the lanes
		end
		showcase(street :: Instance, slots, CFrame.new(86, 10, 55.2), Color3.fromRGB(110, 70, 40), Enum.Material.Wood)
	end)

	-- Zone 4: the roof east of the lanes (floor y 848; the elevator comes out at x 81, z -3412)
	local skyline = Workspace:FindFirstChild("SkylineLanes")
	need(skyline, "EggPad", function()
		eggStand(
			skyline :: Instance,
			Vector3.new(70, 848.2, -3440),
			Color3.fromRGB(255, 79, 139),
			Color3.fromRGB(245, 184, 46),
			"SKYLINE EGG"
		)
	end)
	need(skyline, "CrateShop", function()
		booth(
			skyline :: Instance,
			"CrateShop",
			Vector3.new(44, 848, -3440),
			10,
			Color3.fromRGB(60, 50, 90),
			Color3.fromRGB(255, 79, 139),
			"SKY CRATES",
			true
		)
	end)
	need(skyline, "RebirthStation", function()
		booth(
			skyline :: Instance,
			"RebirthStation",
			Vector3.new(20, 848, -3440),
			8,
			Color3.fromRGB(40, 30, 60),
			Color3.fromRGB(245, 184, 46),
			"REBIRTH"
		)
	end)
	need(skyline, "Helipad", function()
		helipad(skyline :: Instance, Vector3.new(60, 848, -3485))
	end)
	need(skyline, "Showcase", function()
		local slots = {}
		for i = 1, 6 do
			local pos = Vector3.new(25 + 6 * (i - 1), 848.1, -3420)
			slots[i] = CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1)) -- facing +Z, toward the elevator walkway
		end
		local shelf = Vector3.new(70, 857, -3452)
		showcase(
			skyline :: Instance,
			slots,
			CFrame.lookAt(shelf, shelf + Vector3.new(0, 0, 1)),
			Color3.fromRGB(230, 240, 255),
			Enum.Material.Glass
		)
	end)
	if skyline then
		need(Workspace, "BossArena", function()
			bossArena(Vector3.new(700, 900, -3500))
		end)
	end
	return built
end

return PlaceholderWorld
