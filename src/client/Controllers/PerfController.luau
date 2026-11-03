-- Polish v2 Q3: cheap speed wins on this screen (Config.Perf). Small anchored decor in the four zones (string-light
-- bulbs, bolts, leaves, rails' little bits) stops casting shadows: on a phone each shadow caster costs, and shadows
-- that small don't read anyway. Pins, balls, pets and players are never anchored decor, so they keep theirs.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local PERF = Config.Perf
local CORE_ON = Config.CoreLoop ~= nil and Config.CoreLoop.Enabled == true

local PerfController = {}

local function trim(part: Instance)
	if part:IsA("BasePart") and part.Anchored and part.CastShadow then
		local size = part.Size
		if math.max(size.X, size.Y, size.Z) < PERF.NoShadowBelow then
			part.CastShadow = false
		end
	end
end

function PerfController:Start()
	if not PERF or not PERF.Enabled then
		return
	end
	task.spawn(function()
		for _, name in PERF.Folders do
			local folder = Workspace:WaitForChild(name, 30)
			if folder then
				local count = 0
				for _, object in folder:GetDescendants() do
					trim(object)
					count += 1
					if count % 2000 == 0 then
						task.wait()
					end
				end
				-- (parts built or streamed in later get the same)
				folder.DescendantAdded:Connect(trim)
			end
		end
	end)
	-- Q3 part 2: the old loop's areas leave this screen (a local move into a client-only folder: nothing is
	-- deleted, the server still has them; the old controllers have found them or turned themselves off by then)
	if CORE_ON and PERF.HideOld then
		task.delay(PERF.HideOldAfter or 12, function()
			local holder = Instance.new("Folder")
			holder.Name = "PerfHiddenAreas"
			holder.Parent = ReplicatedStorage
			for _, name in PERF.HideOld do
				local area = Workspace:FindFirstChild(name)
				if area then
					area.Parent = holder
				end
			end
		end)
	end
end

return PerfController
