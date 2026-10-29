-- Every art and sound slot in the game, by name. Id = the Roblox asset ID, or nil for "not picked yet".
-- A nil sound plays its StandIn sound (at StandInPitch) until a real one is picked, so nothing is ever silent.
-- To swap a sound: pick it in Studio's Toolbox, copy its ID, and put it here (or tell Claude the ID).
-- Art slots (crates, coin and gem icons, rank badges, mascots) get added here as each one is built.
local AssetSlots = {}

-- Sounds: the owner's ElevenLabs set (2026-10-29; files + prompts in sounds/, IDs in sounds/ROBLOX_IDS.md).
-- Loop = plays over and over until the script fades it out.
AssetSlots.Sounds = {
	Click = { Id = 111105231579514, Volume = 0.4 }, -- any UI button
	Tap = { Id = 139743078905221, Volume = 0.7 }, -- locking aim / power
	Charge = { Id = 120120078758355, Volume = 0.5 }, -- start holding to charge a throw
	Throw = { Id = 104076971025647, Volume = 0.5 }, -- ball released
	Roll = { Id = 118092173758117, Volume = 0.6, Loop = true }, -- ball rolling down the lane
	PinHit = { Id = 121697729389332, Volume = 0.9 }, -- a few pins fall
	SpareCrash = { Id = 79797686349596, Volume = 0.9 }, -- many pins fall, not a strike
	StrikeCrash = { Id = 78482121025550, Volume = 1 },
	Gutter = { Id = 79077809460563, Volume = 0.7 }, -- the ball drops into the gutter (OVERCOOKED)
	PerfectSting = { Id = 75353849205345, Volume = 0.6 },
	Cheer = { Id = 74787266452233, Volume = 0.45 },
	Firework = { Id = 95416260870081, Volume = 0.6 },
	Coin = { Id = 95823226142935, Volume = 0.3 },
	Gem = { Id = 111321128431923, Volume = 0.5 }, -- gems land in the counter
	StreakUp = { Id = 89967815137441, Volume = 0.6 },
	StreakLost = { Id = 89388883632064, Volume = 0.45 },
	RankUp = { Id = 130336123058265, Volume = 0.8 },
	Error = { Id = 136546858016306, Volume = 0.5 }, -- can't afford / locked / not ready
	ReelTick = { Id = 136775071015216, Volume = 0.6 },
	Reveal = { Id = 87435513163005, Volume = 0.6 },
	RevealBig = { Id = 113977607440678, Volume = 0.8 },
	ReelHeartbeat = { Id = 113632872596468, Volume = 0.8 }, -- A2: crate reel's last stretch
	CrateLand = { Id = 94072269988764, Volume = 0.8 }, -- crate drops onto the table
	CrateOpen = { Id = 81078172763461, Volume = 0.9 }, -- crate lid bursts open
	-- Overcharge (Config.Throw.Overcharge)
	OverchargeWarn = { Id = 78771638964613, Volume = 0.5 }, -- bar enters the red cap
	OverchargeBlast = { Id = 127389674894251, Volume = 1 }, -- the gamble paid off
	Overcooked = { Id = 102742249534842, Volume = 0.6 }, -- the gamble failed: gutter
	-- Power Levels (Config.Economy.PowerLevels), potions, Polish
	PowerUp = { Id = 104161497318477, Volume = 0.8 },
	-- Egg hatch (Client Modules/HatchScene) and pets
	HatchCharge = { Id = 121968440644366, Volume = 0.5 }, -- stand flares under the wobbles
	HatchCrack = { Id = 138849108315949, Volume = 0.8 }, -- each crack snaps open
	HatchFanfare = { Id = 92794458062978, Volume = 0.6 }, -- Legendary + Mythic reveal
	HatchBurst = { Id = 134496704617360, Volume = 0.9 }, -- the shell bursts
	PetMerge = { Id = 89938171982610, Volume = 0.8 }, -- MERGE 3 > SHINY and the fusion machine
	PetEquip = { Id = 89644116931382, Volume = 0.6 }, -- equip a pet / EQUIP BEST
	-- Travel and daily
	ElevatorDing = { Id = 110142896366970, Volume = 0.6 }, -- elevator doors open (zone 3 <-> roof)
	Teleport = { Id = 87901239569367, Volume = 0.6 },
	SpinWin = { Id = 129206082776131, Volume = 0.7 }, -- daily spin wheel stops
	-- Pin Titan boss event (Config.Boss)
	BossSiren = { Id = 133762462987543, Volume = 0.7 }, -- 30 s before boarding opens
	BossHit = { Id = 93860193669146, Volume = 0.9 }, -- a ball hits the Titan
	BossPlate = { Id = 85050805902504, Volume = 1 }, -- an armor plate breaks off
	BossRoar = { Id = 108036280127607, Volume = 1 }, -- fight starts, core opens, Titan falls
	Helicopter = { Id = 99034521898306, Volume = 0.6, Loop = true }, -- takeoff and landing
}

-- Background music and zone ambience (Client Controllers/MusicController). Both loop and cross-fade
-- when you walk into another zone. Zone = the Config.Zones.Worlds / Gated area you stand in; Boss = the
-- Pin Titan fight. Outside every area (the street) counts as zone 1.
AssetSlots.Music = {
	Volume = 0.22, -- music under everything
	AmbienceVolume = 0.3,
	Fade = 2, -- seconds to cross-fade
	Zones = {
		[1] = { Music = 114039983553092, Ambience = 84278958761402 }, -- Back Alley: Vinyl Cradle
		[2] = { Music = 139456294570935, Ambience = 128085468850703 }, -- Neon Alley: Neon Arcade Run
		[3] = { Music = 123751743815421, Ambience = 111551983188757 }, -- Main Street Lanes: Jukebox Lanes
		[4] = { Music = 85041686095962, Ambience = 132852478973411 }, -- Skyline Lanes: Rooftop Triumph
	},
	Boss = { Music = 119351362768094 }, -- Pin Titan fight: Final Stand
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
	-- The owner's LOOKS icons (claude.ai/design 'Strike Legends Store Looks', Looks Icons Sheet, 2026-10-29; files in
	-- assets/look_icons). Look<Config.Cosmetics Id>; a look without one shows a colour swatch on its store card.
	LookFireTrail = 99667527769047,
	LookIceTrail = 71400205635025,
	LookToxicTrail = 75322072368091,
	LookGalaxyTrail = 96879499483388,
	LookVipGold = 107365444718862, -- VipGoldTrail.png
	LookBoomBanner = 132535889047133,
	LookEasyBanner = 92798652067744, -- TooEasyBanner.png
	LookCrushedBanner = 125776190574560,
	LookLegendBanner = 121592540336011,
	LookConfettiBlast = 72232310268465,
	LookFrostBlast = 104283104156008,
	LookToxicBlast = 75545458260109,
	LookGalaxyBlast = 102168598343723,
	LookCandyLane = 87493091852079,
	LookIceLane = 112971816146344,
	LookLavaLane = 116429696023059,
	LookGoldLane = 99913758403619,
	-- Lane skin decor (assets/lane_skins, 2026-10-29)
	CandySprinkles = 118352835502175,
	CandySwirl = 86335112452694,
	CandyCane = 73637543597936,
	CandyPeppermint = 85641172487164,
	GlowSoft = 109547705047240,
	IceCracks = 103856261486313,
	IceFrost = 140456217740254,
	IceSnowflake = 131560215097857,
	LavaCracks = 123963634666568,
	LavaFlow = 118539503182657, -- the TrailSoft texture of the soft-glow beams (batch A2)
}

-- "rbxassetid://..." for an Images slot
function AssetSlots.Image(name: string): string
	local id = AssetSlots.Images[name]
	return if id then "rbxassetid://" .. id else ""
end

return AssetSlots
