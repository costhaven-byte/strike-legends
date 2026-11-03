-- Studio-only helper for builders (never required by the game): pulls changed source files from a local
-- "python -m http.server 35311 --bind 127.0.0.1" in the project folder when Rojo is connected but not applying.
-- Edit mode: require(game.ServerStorage.Tools.DevSync)({ "src/client/Modules/X.luau", ... }) -> report text.
return function(FILES: { string }, port: number?): string
	local HttpService = game:GetService("HttpService")
	local SES = game:GetService("ScriptEditorService")
	local ROOTS = {
		["src/shared/"] = game.ReplicatedStorage.Shared,
		["src/server/"] = game.ServerScriptService.Server,
		["src/client/"] = game.StarterPlayer.StarterPlayerScripts.Client,
	}
	local was = HttpService.HttpEnabled
	HttpService.HttpEnabled = true
	local out = {}
	for _, rel in FILES do
		local ok, err = pcall(function()
			local src = HttpService:GetAsync("http://127.0.0.1:" .. (port or 35311) .. "/" .. rel .. "?t=" .. os.clock(), true)
			local root, rest
			for prefix, r in ROOTS do
				if rel:sub(1, #prefix) == prefix then
					root, rest = r, rel:sub(#prefix + 1)
				end
			end
			local parts = rest:split("/")
			local inst = root
			for i, p in parts do
				if i == #parts then
					local name = p:gsub("%.server%.luau$", ""):gsub("%.client%.luau$", ""):gsub("%.luau$", "")
					if name ~= "init" then
						local found = inst:FindFirstChild(name)
						if not found then
							found = Instance.new("ModuleScript")
							found.Name = name
							found.Parent = inst
							table.insert(out, "CREATED " .. rel)
						end
						inst = found
					end
				else
					inst = inst:FindFirstChild(p)
				end
				assert(inst, "missing " .. p)
			end
			SES:UpdateSourceAsync(inst, function()
				return src
			end)
			assert(inst.Source == (src:gsub(string.char(13), "")), "source mismatch")
			table.insert(out, "ok " .. rel .. " (" .. #src .. ")")
		end)
		if not ok then
			table.insert(out, "FAIL " .. rel .. ": " .. tostring(err))
		end
	end
	HttpService.HttpEnabled = was
	return table.concat(out, "\n")
end
