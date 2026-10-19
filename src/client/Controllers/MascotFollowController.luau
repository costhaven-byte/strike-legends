-- Draws every player's equipped mascots following them around, bobbing in the air behind them.
-- Each client draws them itself from the EquippedMascots Player attribute (the server sets it), so movement is
-- smooth and costs the server nothing. Players further than Config.MascotFx.ShowDistance away aren't drawn.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Mascots = require(Shared.Modules.Mascots)
local MascotView = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("MascotView"))

local FX = Config.MascotFx
local PER_ROW = 3

local MascotFollowController = {}

type Pet = { Model: Model, Id: string, Position: Vector3?, Phase: number }
local pets: { [Player]: { Pet } } = {}
local folder: Folder

local function clear(player: Player)
	for _, pet in pets[player] or {} do
		pet.Model:Destroy()
	end
	pets[player] = nil
end

-- Rebuilds a player's mascots when their equipped list changes (keeps the ones that didn't change)
local function refresh(player: Player)
	local ids = Mascots.DecodeEquipped(player:GetAttribute("EquippedMascots"))
	local old = pets[player] or {}
	local list: { Pet } = {}
	for index, id in ids do
		local mascot = Mascots.Get(id)
		if mascot then
			local reuse = old[index]
			if reuse and reuse.Id == id then
				old[index] = nil
				table.insert(list, reuse)
			else
				local model = MascotView.Mascot(mascot, FX.Size)
				model.Name = player.Name .. "_" .. id
				model.Parent = folder
				table.insert(list, { Model = model, Id = id, Position = nil, Phase = index * 1.7 })
			end
		end
	end
	for _, pet in old do
		pet.Model:Destroy()
	end
	pets[player] = list
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("EquippedMascots"):Connect(function()
		refresh(player)
	end)
	refresh(player)
end

-- Where mascot number `index` (of `count`) sits behind the player: rows of 3, fanned out sideways
local function slotOffset(index: number, count: number): Vector3
	local row = math.floor((index - 1) / PER_ROW)
	local inRow = math.min(PER_ROW, count - row * PER_ROW)
	local column = (index - 1) % PER_ROW
	local x = (column - (inRow - 1) / 2) * FX.Spacing
	return Vector3.new(x, 0, FX.FollowDistance + row * FX.Spacing)
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	local now = os.clock()
	local alpha = 1 - math.exp(-FX.FollowSpeed * dt)
	for player, list in pets do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local far = not root or (camera and (root.Position - camera.CFrame.Position).Magnitude > FX.ShowDistance)
		for index, pet in list do
			if far then
				if pet.Model.Parent then
					pet.Model.Parent = nil
				end
				pet.Position = nil
				continue
			end
			local rootPart = root :: BasePart
			-- Flat facing, so mascots stay level when the player jumps or tilts
			local look = rootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
			look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
			local basis = CFrame.lookAt(rootPart.Position, rootPart.Position + look)
			local ground = rootPart.Position.Y - rootPart.Size.Y / 2 - (humanoid and humanoid.HipHeight or 2)
			local offset = slotOffset(index, #list)
			local target = (basis * CFrame.new(offset)).Position
			target = Vector3.new(target.X, ground + FX.Hover, target.Z)
			local position = if pet.Position then pet.Position:Lerp(target, alpha) else target
			pet.Position = position
			local bob = math.sin((now + pet.Phase) * FX.BobSpeed * math.pi * 2) * FX.BobHeight
			pet.Model:PivotTo(
				CFrame.lookAt(position + Vector3.new(0, bob, 0), position + Vector3.new(0, bob, 0) + look)
			)
			if not pet.Model.Parent then
				pet.Model.Parent = folder
			end
		end
	end
end

function MascotFollowController:Start()
	folder = Instance.new("Folder")
	folder.Name = "Mascots"
	folder.Parent = Workspace

	for _, player in Players:GetPlayers() do
		task.spawn(watch, player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)
	RunService.RenderStepped:Connect(step)
end

return MascotFollowController
