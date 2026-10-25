-- Every art and sound slot in the game, by name. Id = the Roblox asset ID, or nil for "not picked yet".
-- A nil sound plays its StandIn sound (at StandInPitch) until a real one is picked, so nothing is ever silent.
-- To swap a sound: pick it in Studio's Toolbox, copy its ID, and put it here (or tell Claude the ID).
-- Art slots (crates, coin and gem icons, rank badges, mascots) get added here as each one is built.
local AssetSlots = {}

-- Sounds: the current Ids are placeholders from the Creator Store
AssetSlots.Sounds = {
	Click = { Id = 114782931135220, Volume = 0.4 }, -- any UI button
	Tap = { Id = 127036696152728, Volume = 0.7 }, -- locking aim / power
	Charge = { Id = 127036696152728, Volume = 0.5 }, -- start holding to charge a throw
	Throw = { Id = 9114156499, Volume = 0.5 }, -- ball released
	Roll = { Id = 9118661490, Volume = 0.6 }, -- ball rolling down the lane
	PinHit = { Id = 9113559266, Volume = 0.9 },
	StrikeCrash = { Id = 4692687595, Volume = 1 },
	PerfectSting = { Id = 1840076509, Volume = 0.6 },
	Cheer = { Id = 9120974378, Volume = 0.45 },
	Firework = { Id = 134947109312227, Volume = 0.6 },
	Coin = { Id = 135483737426662, Volume = 0.3 },
	StreakUp = { Id = 112485797063762, Volume = 0.6 },
	StreakLost = { Id = 97861773515321, Volume = 0.45 },
	RankUp = { Id = 1841488866, Volume = 0.8 },
	ReelTick = { Id = 88442833509532, Volume = 0.6 },
	Reveal = { Id = 6079105785, Volume = 0.6 },
	RevealBig = { Id = 128460880879263, Volume = 0.8 },
	-- Overcharge (Config.Throw.Overcharge). Not picked yet: they borrow other sounds.
	OverchargeWarn = { Id = nil, Volume = 0.5, StandIn = "Charge", StandInPitch = 1.8 }, -- bar enters the red cap
	OverchargeBlast = { Id = nil, Volume = 1, StandIn = "StrikeCrash", StandInPitch = 0.55 }, -- the gamble paid off
	Overcooked = { Id = nil, Volume = 0.6, StandIn = "StreakLost", StandInPitch = 0.7 }, -- the gamble failed: gutter
	-- Power Levels (Config.Economy.PowerLevels). Not picked yet.
	PowerUp = { Id = nil, Volume = 0.8, StandIn = "RankUp", StandInPitch = 1.25 }, -- bought a Power Level
	-- Egg hatch (Client Modules/HatchScene). Not picked yet.
	HatchCharge = { Id = nil, Volume = 0.6, StandIn = "Charge", StandInPitch = 1.3 }, -- stand flares, charge climbs
	HatchCrack = { Id = nil, Volume = 0.8, StandIn = "PinHit", StandInPitch = 1.6 }, -- each crack snaps open
	HatchBurst = { Id = nil, Volume = 0.9, StandIn = "StrikeCrash", StandInPitch = 1.3 }, -- the shell bursts
	ElevatorDing = { Id = nil, Volume = 0.6, StandIn = "Coin", StandInPitch = 0.6 }, -- elevator doors open (zone 3 <-> roof)
}

-- Images: the owner's store kit icons (claude.ai/design 'Strike Legends Store', 2026-10-25; files in
-- assets/store_icons). Robux is the one R$ price mark: swap it here to change every price.
AssetSlots.Images = {
	Robux = 80208245592445,
	StoreBag = 119226308483229,
	Coin = 92524999373079,
	Gem = 103711559718524,
	XpStar = 107396472935904,
	BoostCoin = 90447434891553,
	BoostXp = 95906571584466,
	Boost15 = 115844450036931,
	Pass2x = 121415610421171,
	PassVip = 118878841892191,
	PassAuto = 114442555890368,
	PassLucky = 85937808730956,
	PassSuperLucky = 87885062897128,
	PassTriple = 130744482024430,
	PassPets = 70856062563570,
	Gems60 = 73610984970518,
	Gems300 = 81381495615677,
	Gems1500 = 106361366840877,
	BallDumpster = 95552734682799,
	Gift = 123387103603228,
	Shine = 132724742675090, -- the idle shine stripe on the STORE button and boost pills
	Halftone = 77494663967744, -- one dot, tiled for the halftone texture on cards and pills
}

-- "rbxassetid://..." for an Images slot
function AssetSlots.Image(name: string): string
	local id = AssetSlots.Images[name]
	return if id then "rbxassetid://" .. id else ""
end

return AssetSlots
