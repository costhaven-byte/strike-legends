-- Adds each player's ball effects (sparkles, rings, glow) to the ball in their hand.
-- The server makes the held ball (BallService) and tags it with BallId; effects are client-only
-- so the rings can turn smoothly every frame.
-- SETTINGS: EFFECTS off also switches off (on this screen only) the trail and sparkle aura the server puts on the
-- held ball (BallService BallTrail + BallAura); the server's own on/off (hiding the ball) is put back when it's on.
-- OTHER PLAYERS' EFFECTS off does the same for every other player's held ball.
local Players = game:GetService("Players")

local Modules = script.Parent.Parent:WaitForChild("Modules")
local BallFx = require(Modules:WaitForChild("BallFx"))
local Settings = require(Modules:WaitForChild("Settings"))

local BallFxController = {}

-- Server-made held-ball effects: { [effect] = the server's Enabled }
local serverFx: { [Trail | ParticleEmitter]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local othersFx: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- on another player
local applying = false

local function applyServerFx(effect: Trail | ParticleEmitter)
	applying = true
	effect.Enabled = serverFx[effect] and Settings.Get("Vfx") and (not othersFx[effect] or Settings.Get("OthersVfx"))
	applying = false
end

local function watchServerFx(effect: Instance, others: boolean)
	if not ((effect:IsA("Trail") and effect.Name == "BallTrail") or (effect:IsA("ParticleEmitter") and effect.Name == "BallAura")) then
		return
	end
	local fx = effect :: Trail | ParticleEmitter
	serverFx[fx] = fx.Enabled
	othersFx[fx] = others or nil
	fx:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not applying then
			serverFx[fx] = fx.Enabled -- the server changed it
			applyServerFx(fx)
		end
	end)
	applyServerFx(fx)
end

local function watchHeld(held: BasePart, others: boolean)
	local fx = BallFx.Attach(held, held:GetAttribute("BallId"), "Held", nil, { Others = others })
	local function refresh()
		fx:SetEnabled(not held:GetAttribute("Hidden"))
	end
	held:GetAttributeChangedSignal("Hidden"):Connect(refresh)
	refresh()
end

local function watchCharacter(character: Model, others: boolean)
	character.DescendantAdded:Connect(function(item)
		watchServerFx(item, others)
	end)
	for _, item in character:GetDescendants() do
		watchServerFx(item, others)
	end
	character.ChildAdded:Connect(function(child)
		if child.Name == "EquippedBallFx" then
			local held = child:WaitForChild("HeldBall", 5)
			if held and held:IsA("BasePart") then
				watchHeld(held, others)
			end
		end
	end)
	local folder = character:FindFirstChild("EquippedBallFx")
	local held = folder and folder:FindFirstChild("HeldBall")
	if held and held:IsA("BasePart") then
		watchHeld(held, others)
	end
end

local function watchPlayer(player: Player)
	local others = player ~= Players.LocalPlayer
	player.CharacterAdded:Connect(function(character)
		watchCharacter(character, others)
	end)
	if player.Character then
		watchCharacter(player.Character, others)
	end
end

function BallFxController:Start()
	local function refresh()
		for effect in serverFx do
			if effect.Parent then
				applyServerFx(effect)
			end
		end
	end
	Settings.Changed("Vfx", refresh)
	Settings.Changed("OthersVfx", refresh)
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
end

return BallFxController
