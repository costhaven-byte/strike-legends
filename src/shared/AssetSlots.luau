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
	-- Egg hatch (Client Modules/HatchScene). A1 2026-10-28: Creator Store stand-ins (Pro Sound Effects, APM)
	HatchCharge = { Id = 9125635442, Volume = 0.5 }, -- stand flares: magical sparkling chimes under the wobbles
	HatchCrack = { Id = 9113959343, Volume = 0.8 }, -- each crack snaps open (crunchy egg crack)
	HatchFanfare = { Id = 1846251701, Volume = 0.6 }, -- Legendary + Mythic reveal (game show "win" sting)
	HatchBurst = { Id = nil, Volume = 0.9, StandIn = "StrikeCrash", StandInPitch = 1.3 }, -- the shell bursts
	ElevatorDing = { Id = nil, Volume = 0.6, StandIn = "Coin", StandInPitch = 0.6 }, -- elevator doors open (zone 3 <-> roof)
	-- Pin Titan boss event (Config.Boss). Not picked yet.
	BossSiren = { Id = nil, Volume = 0.7, StandIn = "Charge", StandInPitch = 0.6 }, -- 30 s before boarding opens
	BossHit = { Id = nil, Volume = 0.9, StandIn = "PinHit", StandInPitch = 0.55 }, -- a ball hits the Titan
	BossPlate = { Id = nil, Volume = 1, StandIn = "StrikeCrash", StandInPitch = 1.4 }, -- an armor plate breaks off
	BossRoar = { Id = nil, Volume = 1, StandIn = "StrikeCrash", StandInPitch = 0.4 }, -- fight starts, core opens, Titan falls
	Helicopter = { Id = nil, Volume = 0.6, StandIn = "Roll", StandInPitch = 1.6 }, -- takeoff and landing
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
	-- The owner's HUD Kit icons (claude.ai/design 'Strike Legends HUD Kit', 2026-10-26; files in assets/hud_icons)
	HudCoin = 124598335657525,
	HudCoins2 = 135300865220602,
	HudGem = 104618081407768,
	HudXp = 101918311174505,
	HudBall = 121251895958946,
	HudPaw = 105932963584698,
	HudStore = 95452699528378,
	HudBolt = 86616155538115,
	HudGiftPink = 128822494284495,
	HudGiftDaily = 72613042452687,
	HudLock = 71724857225595,
	HudRebirth = 82349544141230,
	HudPortal = 104702285368865,
	HudFlame = 98282114790053,
	HudPotionCoin = 130322782559457,
	HudPotionXp = 110385668789086,
	HudPotionLuck = 79037484496408,
	HudPin = 124362099981289,
	HudCrate = 131700039861753,
	HudClover = 112463627711081,
	HudClose = 83174793991131,
	HudCheck = 105468984575166,
}

-- "rbxassetid://..." for an Images slot
function AssetSlots.Image(name: string): string
	local id = AssetSlots.Images[name]
	return if id then "rbxassetid://" .. id else ""
end

return AssetSlots
