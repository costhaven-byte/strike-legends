-- Icons from the owner's UI Kit (claude.ai/design 'Strike Legends UI Kit', 2026-10-26: Ball Book + Multiplier card).
-- Files in assets/uikit_icons (256x256, outline and lip baked in). Kept apart from AssetSlots.Images, which holds
-- the HUD Kit's icons of the same names (different drawings).
local UiKitAssets = {}

UiKitAssets.Images = {
	ArrowRight = 96630238505009, -- page arrow; rotate 180 for left
	Ball = 111665233772808,
	Close = 117022905006415, -- the whole red X button
	Coin = 127507897790610,
	Gem = 79557851291699,
	Lock = 122363382777585,
	Pets = 110295160436431,
	Polish = 104754893234644, -- polish sparkle, MAX POLISH
	StoreBoost = 102255640037428,
	Tick = 137761335837576, -- EQUIPPED
	Power = 119351756091406,
	Rank = 87572697734245,
	Streak = 122630974618695,
	Zone = 138740736086859,
	LaneEvent = 85092572263175,
	Perfect = 108357074424146,
	Overcharge = 138108443983813,
	GoldenPin = 125701777756248,
}

-- "rbxassetid://..." for an icon
function UiKitAssets.Image(name: string): string
	local id = UiKitAssets.Images[name]
	return if id then "rbxassetid://" .. id else ""
end

return UiKitAssets
