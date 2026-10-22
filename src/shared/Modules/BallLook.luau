-- Dresses a plain ball part in its 3D model from ReplicatedStorage.BallModels (named by ball Id).
-- The part keeps doing the moving; the model is welded on top and the part turns invisible.
-- Balls without a model keep their plain colour and material.
-- Placeholder balls (Phase X) borrow another ball's model (Config.Balls Model) and repaint it (Tint; PlainModel =
-- one flat colour and material) until their real art exists.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balls = require(script.Parent.Balls)

local TINT_MIX = 0.7 -- how far a tinted model's colours move toward the Tint (1 = all the Tint)

local BallLook = {}

-- The model a ball uses from ReplicatedStorage.BallModels (its own, or the one it borrows), or nil
function BallLook.Template(ballId: string?): Instance?
	local models = ReplicatedStorage:FindFirstChild("BallModels")
	if not models or not ballId then
		return nil
	end
	local ball = Balls.Get(ballId)
	return models:FindFirstChild(ballId) or (ball and ball.Model and models:FindFirstChild(ball.Model))
end

-- Repaints a copy of a borrowed model for a placeholder ball (no change for balls without a Tint)
function BallLook.Paint(model: Instance, ballId: string?)
	local ball = Balls.Get(ballId)
	if not ball or not ball.Tint then
		return
	end
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") then
			local _, _, v = piece.Color:ToHSV()
			local dark = v < 0.15 -- finger holes stay dark
			if ball.PlainModel then
				piece.Color = if dark then piece.Color else ball.Tint
				piece.Material = if dark then piece.Material else (ball.Material or Enum.Material.SmoothPlastic)
			elseif not dark then
				piece.Color = piece.Color:Lerp(ball.Tint, TINT_MIX)
			end
			if piece:IsA("MeshPart") and not dark then
				piece.TextureID = ""
			end
		end
	end
end

function BallLook.Apply(part: BasePart, ballId: string?): boolean
	local source = BallLook.Template(ballId)
	if not source then
		return false
	end

	local model = source:Clone()
	BallLook.Paint(model, ballId)
	model.Name = "Look"
	-- Models are stored with a 1-stud-wide shell and the pivot at the shell's centre,
	-- so scale straight to the ball's size and drop it onto the part
	model:ScaleTo(model:GetScale() * part.Size.X)
	model:PivotTo(part.CFrame)
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.Anchored = false
			-- A Weld (not a WeldConstraint) keeps this exact offset even if the ball is moved
			-- before it enters the world, as the lane ball is
			local weld = Instance.new("Weld")
			weld.Part0 = part
			weld.Part1 = piece
			weld.C0 = part.CFrame:ToObjectSpace(piece.CFrame)
			weld.Parent = piece
		end
	end
	model.Parent = part
	part.Transparency = 1
	return true
end

return BallLook
