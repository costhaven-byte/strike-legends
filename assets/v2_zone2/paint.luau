-- Flattens + repaints the zone 2 kit imports (ServerStorage.V2Zone2Imports_Raw) into ServerStorage.V2Zone2Kit (from v2_zone1/paint.luau; + each part's glb group as attribute Group)
local Http = game:GetService("HttpService")
local was = Http.HttpEnabled
Http.HttpEnabled = true
local ok, body = pcall(function() return Http:GetAsync("http://127.0.0.1:35211/z2nodes.json") end)
Http.HttpEnabled = was
if not ok then return "http fail " .. tostring(body) end
local data = Http:JSONDecode(body)
local raw = game.ServerStorage.V2Zone2Imports_Raw
local kit = game.ServerStorage:FindFirstChild("V2Zone2Kit")
if kit then kit:Destroy() end
kit = Instance.new("Folder")
kit.Name = "V2Zone2Kit"
local report = {}
for file, info in data do
	local src = raw:FindFirstChild(file)
	if not src then table.insert(report, file .. " MISSING") continue end
	local parts = {}
	for _, d in src:GetDescendants() do if d:IsA("BasePart") then table.insert(parts, d) end end
	-- centres: glb overall box vs Roblox overall box
	local gl, gh = Vector3.one * 1e9, Vector3.one * -1e9
	for _, n in info.nodes do local c = Vector3.new(n.c[1], n.c[2], n.c[3]); gl = gl:Min(c); gh = gh:Max(c) end
	local rl, rh = Vector3.one * 1e9, Vector3.one * -1e9
	for _, p in parts do rl = rl:Min(p.Position); rh = rh:Max(p.Position) end
	local gc, rc = (gl + gh) / 2, (rl + rh) / 2
	local best, bestErr, bestMap
	for _, flip in { 1, -1 } do
		local used, map, err, miss = {}, {}, 0, 0
		-- pass 1: exact node names; pass 2: Roblox's duplicate suffix (name2, name3..) = node name + digits
		for pass = 1, 2 do
			for _, p in parts do
				if map[p] then continue end
				local rel = p.Position - rc
				rel = Vector3.new(rel.X * flip, rel.Y, rel.Z * flip)
				local pick, pd = nil, math.huge
				for i, n in info.nodes do
					local same = if pass == 1 then n.n == p.Name else (p.Name:sub(1, #n.n) == n.n and p.Name:sub(#n.n + 1):match("^%d+$") ~= nil)
					if same and not used[i] then
						local d = (Vector3.new(n.c[1], n.c[2], n.c[3]) - gc - rel).Magnitude
						if d < pd then pick, pd = i, d end
					end
				end
				if pick then used[pick] = true; map[p] = info.nodes[pick]; err += pd end
			end
		end
		for _, p in parts do if not map[p] then miss += 1 end end
		if not best or err < bestErr then best, bestErr, bestMap = flip, err, map end
		bestMap.miss = miss
	end
	local model = Instance.new("Model")
	model.Name = (file:gsub("^SL_Z2_", "Z2_"))
	local unmatched = {}
	for _, p in parts do
		local n = bestMap[p]
		local c = p:Clone()
		for _, ch in c:GetChildren() do ch:Destroy() end
		c.Anchored = true
		if n then
			local m = info.mats[n.m + 1]
			c.Color = Color3.fromHex(m.hex)
			c.Reflectance = 0
			c.Transparency = 0
			if m.tex then
				c.Material = Enum.Material.SmoothPlastic
				c:SetAttribute("SignTexture", m.name)
			elseif m.a < 0.5 then
				c.Material = Enum.Material.Glass
				c.Transparency = math.clamp(1 - m.a, 0.3, 0.85)
			elseif m.glow and m.ei >= 1.2 then
				c.Material = Enum.Material.Neon
			elseif m.metal >= 0.35 then
				c.Material = Enum.Material.SmoothPlastic
				c.Reflectance = 0.1
			else
				c.Material = Enum.Material.SmoothPlastic
			end
			c:SetAttribute("Mat", m.name)
			if n.g ~= "" then
				c:SetAttribute("Group", n.g)
			end
		else
			table.insert(unmatched, p.Name)
		end
		c.Parent = model
	end
	model.Parent = kit
	table.insert(report, string.format("%s parts %d flip %d err %.3f unmatched %d %s", model.Name, #parts, best, bestErr, #unmatched, table.concat(unmatched, ",", 1, math.min(#unmatched, 8))))
end
kit.Parent = game.ServerStorage
return table.concat(report, "\n")
