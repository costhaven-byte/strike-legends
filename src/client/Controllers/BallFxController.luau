-- Adds each player's ball effects (sparkles, rings, glow) to the ball in their hand.
-- The server makes the held ball (BallService) and tags it with BallId; effects are client-only
-- so the rings can turn smoothly every frame.
local Players = game:GetService("Players")

local BallFx = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("BallFx"))

local BallFxController = {}

local function watchHeld(held: BasePart)
	local fx = BallFx.Attach(held, held:GetAttribute("BallId"), "Held")
	local function refresh()
		fx:SetEnabled(not held:GetAttribute("Hidden"))
	end
	held:GetAttributeChangedSignal("Hidden"):Connect(refresh)
	refresh()
end

local function watchCharacter(character: Model)
	character.ChildAdded:Connect(function(child)
		if child.Name == "EquippedBallFx" then
			local held = child:WaitForChild("HeldBall", 5)
			if held and held:IsA("BasePart") then
				watchHeld(held)
			end
		end
	end)
	local folder = character:FindFirstChild("EquippedBallFx")
	local held = folder and folder:FindFirstChild("HeldBall")
	if held and held:IsA("BasePart") then
		watchHeld(held)
	end
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
end

function BallFxController:Start()
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
end

return BallFxController
