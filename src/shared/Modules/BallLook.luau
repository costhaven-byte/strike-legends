-- Dresses a plain ball part in its 3D model from ReplicatedStorage.BallModels (named by ball Id).
-- The part keeps doing the moving; the model is welded on top and the part turns invisible.
-- Balls without a model keep their plain colour and material.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BallLook = {}

function BallLook.Apply(part: BasePart, ballId: string?): boolean
	local models = ReplicatedStorage:FindFirstChild("BallModels")
	local source = models and ballId and models:FindFirstChild(ballId)
	if not source then
		return false
	end

	local model = source:Clone()
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
