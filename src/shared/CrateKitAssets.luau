-- Icons from the owner's Crate Kit (claude.ai/design 'Strike Legends Crate Design', 2026-10-26: crate shop, odds,
-- opening reel, reveal, pull banner). Files in assets/crate_icons (transparent PNGs; outline baked in). White ones
-- (confetti, rays, shine) are tinted with ImageColor3. Kept apart from AssetSlots.Images and UiKitAssets, which hold
-- other kits' icons of the same names (different drawings).
local CrateKitAssets = {}

CrateKitAssets.Images = {
	Check = 109255213566358, -- owned, equipped
	Close = 77590379591268, -- the X on the red close button
	Clover = 73313342902537, -- LUCKY x1.5 note
	Coin = 132380064897099,
	ConfettiDot = 93123279508426,
	ConfettiRect = 83807077722995,
	Gem = 112796583385977,
	Lock = 81959903184791,
	Odds = 94169591225307,
	Rays = 130467070787072, -- reveal rays
	ReelMarker = 114111983867546, -- reel centre marker (rotate 180 for the bottom one)
	Shine = 132630258855917, -- banner shine sweep
	Sparkle = 103556942355895,
	Star = 135962388569080,
}

-- "rbxassetid://..." for an icon
function CrateKitAssets.Image(name: string): string
	local id = CrateKitAssets.Images[name]
	return if id then "rbxassetid://" .. id else ""
end

return CrateKitAssets
