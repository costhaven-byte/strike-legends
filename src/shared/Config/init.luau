-- All tunable numbers live here. Change values, not logic.
local Config = {}

-- Lane and pin sizes (studs). Arcade scale: bigger than real life so pins read well on mobile.
Config.Lane = {
	PinHeight = 2.8,
	PinWidth = 0.9,
	PinSpacing = 2.3, -- distance between neighbouring pins
	PinDensity = 0.35,
	BallDiameter = 1.8,
	PinCount = 10, -- pins in one rack (bigger racks per zone arrive in Milestone 12, see Config.Economy.Zones)

	LaneHalfWidth = 4, -- playable wood, centre to edge
	GutterOffset = 4.7, -- centre of the gutter, from lane centre
	GutterDepth = 0.6, -- how far below the lane surface the gutter is

	-- How hard knocked pins fly (studs per second)
	PinKnockSpeedMin = 14,
	PinKnockSpeedMax = 28,
	PinKnockUpSpeed = 10,

	-- Seconds from the ball reaching the pins until they reset
	PinResetDelay = 0.9, -- (strikes add the slow-motion time on top)

	-- How far (studs) a player can be from the lane's approach and still throw
	ThrowZoneMargin = 0.7, -- small, so it never reaches a neighbouring lane
}

-- ADDENDUM 4 CORE LOOP (Stage 1, 2026-11-01): throw, pins into a bag, sell at the sell station, buy, rebirth.
-- Enabled = true: the Skyline rooftop (zone 4) is the only zone and the hub; zones 1-3, the boss helicopter, the
-- elevator, teleports, zone gates and the story layer (Rizzo, join fly-over, first-3-minutes) are switched off but
-- kept. false = the old game comes back exactly as it was. Every Stage 1 tuning number is in this one table.
Config.CoreLoop = {
	Enabled = true,
	Folder = "SkylineLanes", -- the one zone (its Workspace model); lanes are handed out here
	-- The rack: a Rows-row triangle (row 1 = the head pin) with the listed { row, place } pins taken out.
	-- 9 rows = 45 pins, minus 5 back corners = 40. Later zones can use bigger layouts.
	Rack = {
		Rows = 9,
		Remove = { { 9, 1 }, { 9, 9 }, { 8, 1 }, { 8, 8 }, { 9, 5 } },
		Spacing = 1.5, -- studs between neighbouring pins (the old 10-pin rack is 2.3)
		PinScale = 0.65, -- pin size against Config.Lane PinHeight/PinWidth
		HeadPinForward = 1.5, -- the head pin stands this many studs closer to the bowler than the lane's PinSpot
	},
	-- Pins per throw: the ball's Pins (Balls below) rolls within +/- PinsSpread of it. Addendum 5 A1: pins are a
	-- number, no cap: the counter and pops show the real count, only up to the 40 rack pins fall on screen.
	PinsSpread = 0.2,
	-- A roll in the top LuckyFrom share of the spread (0.25 = the best quarter, +10% to +20%) pops LUCKY!
	LuckyFrom = 0.25,
	-- Addendum 5 A1: no levels in the loop: throws give no XP, the level bar, level-up and rank screens, level
	-- rewards and the nameplate level are off, nothing asks for a level (code kept; false = Addendum 4 levels back)
	NoLevels = true,
	-- Throw animation level per ball step (Config.Throw pose levels: 1 = scuffed .. 9 = clean .. 12 = biggest)
	Poses = { 1, 2, 3, 4, 5, 6, 7, 9, 10, 12 },
	-- Stage 2 ladders (Addendum 4): balls and bags are bought in a fixed order, alternating ball, bag, ball, bag
	-- (ball 2, bag 2, ball 3, bag 3 ... ball 10, bag 10). Crates no longer give balls. Ball = the existing ball model
	-- it borrows (Config.Balls Id; Stage 4 picks the final ones and adds the effects), Pins = average pins per throw.
	-- Prices: income per minute with the ball you have x the target minutes to the next ball (2, 2, 5, 5, 5, 5, 5, 8,
	-- 12), with the bag in between taking about 30% of that time. Sell trips counted at 6 s; check with
	-- require(game.ServerStorage.Tools.EconomySim).CoreLadder(). Full ladder ~51 min of play.
	-- Addendum 5 A1: steeper pins curve (about x2 a ball; was 6, 9, 12 .. 43).
	-- Addendum 5 A2: balls and bags are TWO ladders (Ladders.Independent): buy the next ball or the next bag in any
	-- order, neither blocks the other. Ball pacing (minutes between balls for a player who always buys the cheaper
	-- of the two next steps, bags included): ball 2 in the first ~15 s (the Throw > Sell > Buy guide), balls 3-5
	-- about 2 min each, balls 6-10 about 5 min each (ball 10 at ~31 min). Check with
	-- require(game.ServerStorage.Tools.EconomySim).CoreLadder(). Rarity = the colour its row shows in the shop.
	-- Addendum 5 E (pacing pass, EconomySim.CorePacing with pets + eggs + slots): the pets had pulled balls 7-10 in to
	-- 2.4-4.3 min apart (ball 10 at ~27 min), so balls 6-10 were re-priced to ~5 min apart again (ball 10 at ~30 min).
	-- Was ball 6-10: 10K, 21K, 45K, 99K, 220K.
	Balls = {
		{ Ball = "Tangerine", Name = "Beach Roller", Fx = "Sand", Pins = 6, Price = 0, Rarity = "Common" },
		{ Ball = "Bubblegum", Name = "Rubber Bouncer", Fx = "Bounce", Pins = 10, Price = 50, Rarity = "Common" }, -- one bag: bought in the first 30 s (Stage 3)
		{ Ball = "Lime", Name = "Confetti Popper", Fx = "Confetti", Pins = 18, Price = 500, Rarity = "Uncommon" },
		{ Ball = "Sunburst", Name = "Sunspike", Fx = "Burn", Pins = 35, Price = 950, Rarity = "Uncommon" },
		{ Ball = "Frostbite", Name = "Gust", Fx = "Frost", Pins = 70, Price = 1900, Rarity = "Rare" },
		{ Ball = "CloudSwirl", Name = "Cloud Roll", Fx = "Arms", Pins = 140, Price = 5300, Rarity = "Rare" },
		{ Ball = "Crystal", Name = "Rainbow Arc", Fx = "Prism", Pins = 300, Price = 22000, Rarity = "Epic" },
		{ Ball = "Lightning", Name = "Sunbolt", Fx = "Bolt", Pins = 650, Price = 44000, Rarity = "Epic" },
		{ Ball = "SolidGold", Name = "Tornado", Fx = "Tornado", Pins = 1400, Price = 150000, Rarity = "Legendary" },
		{ Ball = "Daybreak", Name = "Sonic Boom", Fx = "BlackHole", Pins = 3200, Price = 590000, Rarity = "Mythic" },
		-- Addendum 6 Stage 3: zones 2-4, 10 balls each (Zone = the zone that must be open to buy it). Zones 2-4 have their
		-- own effects. 2026-11-03: all 40 looks = the owner's new ball designs (ReplicatedStorage.BallModels, assets/v2_balls);
		-- Scorpion, Canyon Echo and Mirage got their own Ids (they shared Crystal / Lightning / SolidGold with zone 1).
		-- Numbers: pins x1.7 a ball from ball 10 of the zone before; price = income with the ball before (pins x the
		-- zone's PinValue x 84 throws a minute, zone 1's late pace with pets) x Zone 1's gaps (3, 2, 2, 2, 2, 5, 5, 5, 5, 5
		-- min). Stage 9 tunes them from the pacing sim.
		-- Addendum 6 Stage 9 (pacing pass, python tools/pacing_sim.py stage9): balls 12-40 re-priced for the income a
		-- player who rebirths as soon as they can really has when each ball is new to them (rebirths and pets
		-- included), so every zone's new balls come ~1.5-5 min apart like zone 1's. Before, zone 3's came every
		-- ~30 s and the whole zone 4 ladder took ~2 min. Zone 1 and zone 2 ball 1 unchanged.
		{ Ball = "Ocean", Name = "Seashell Spinner", Fx = "Shell", Pins = 5400, Price = 4800000, Rarity = "Uncommon", Zone = 2 },
		{ Ball = "Sunset", Name = "Beach Ball", Fx = "BeachBall", Pins = 9200, Price = 9300000, Rarity = "Uncommon", Zone = 2 },
		{ Ball = "Electric", Name = "Kite Flyer", Fx = "Kite", Pins = 16000, Price = 15000000, Rarity = "Uncommon", Zone = 2 },
		{ Ball = "Toxic", Name = "Tide Turner", Fx = "Tide", Pins = 27000, Price = 23000000, Rarity = "Rare", Zone = 2 },
		{ Ball = "Magma", Name = "Coral Crusher", Fx = "Coral", Pins = 45000, Price = 61000000, Rarity = "Rare", Zone = 2 },
		{ Ball = "Galaxy", Name = "Surf Rider", Fx = "Surf", Pins = 77000, Price = 220000000, Rarity = "Rare", Zone = 2 },
		{ Ball = "Thunder", Name = "Sunset Splash", Fx = "Splash", Pins = 130000, Price = 320000000, Rarity = "Epic", Zone = 2 },
		{ Ball = "Plasma", Name = "Pier Pounder", Fx = "Pound", Pins = 220000, Price = 2900000000, Rarity = "Epic", Zone = 2 },
		{ Ball = "Nebula", Name = "Tsunami", Fx = "Tsunami", Pins = 380000, Price = 4300000000, Rarity = "Epic", Zone = 2 },
		{ Ball = "Golden", Name = "Lighthouse Beam", Fx = "Lighthouse", Pins = 650000, Price = 8200000000, Rarity = "Legendary", Zone = 2 },
		{ Ball = "LeagueBlack", Name = "Vine Swinger", Fx = "Vine", Pins = 1100000, Price = 28000000000, Rarity = "Rare", Zone = 3 },
		{ Ball = "CherrySwirl", Name = "Coconut", Fx = "Coconut", Pins = 1900000, Price = 35000000000, Rarity = "Rare", Zone = 3 },
		{ Ball = "BlueMarble", Name = "Toucan Roll", Fx = "Toucan", Pins = 3200000, Price = 76000000000, Rarity = "Rare", Zone = 3 },
		{ Ball = "Phantom", Name = "Leaf Storm", Fx = "LeafStorm", Pins = 5400000, Price = 140000000000, Rarity = "Epic", Zone = 3 },
		{ Ball = "PearlPro", Name = "Waterfall", Fx = "Waterfall", Pins = 9200000, Price = 180000000000, Rarity = "Epic", Zone = 3 },
		{ Ball = "TigerSwirl", Name = "Jaguar", Fx = "Jaguar", Pins = 16000000, Price = 850000000000, Rarity = "Epic", Zone = 3 },
		{ Ball = "Inferno", Name = "Rope Bridge", Fx = "Bridge", Pins = 27000000, Price = 1500000000000, Rarity = "Legendary", Zone = 3 },
		{ Ball = "Championship", Name = "Temple Stone", Fx = "Temple", Pins = 45000000, Price = 4500000000000, Rarity = "Legendary", Zone = 3 },
		{ Ball = "Dragon", Name = "Monsoon", Fx = "Monsoon", Pins = 77000000, Price = 9100000000000, Rarity = "Legendary", Zone = 3 },
		{ Ball = "Void", Name = "Jungle King", Fx = "JungleKing", Pins = 130000000, Price = 19000000000000, Rarity = "Mythic", Zone = 3 },
		{ Ball = "Hubcap", Name = "Dust Devil", Fx = "DustDevil", Pins = 220000000, Price = 110000000000000, Rarity = "Epic", Zone = 4 },
		{ Ball = "DumpsterDiamond", Name = "Cactus Roller", Fx = "Cactus", Pins = 380000000, Price = 140000000000000, Rarity = "Epic", Zone = 4 },
		{ Ball = "DuctTape", Name = "Mesa Smash", Fx = "Mesa", Pins = 640000000, Price = 230000000000000, Rarity = "Epic", Zone = 4 },
		{ Ball = "RustBucket", Name = "Sandstorm", Fx = "Sandstorm", Pins = 1100000000, Price = 570000000000000, Rarity = "Legendary", Zone = 4 },
		{ Ball = "Rookie", Name = "Oasis Spring", Fx = "Oasis", Pins = 1800000000, Price = 980000000000000, Rarity = "Legendary", Zone = 4 },
		{ Ball = "Scorpion", Name = "Scorpion", Fx = "Scorpion", Pins = 3100000000, Price = 2000000000000000, Rarity = "Legendary", Zone = 4 },
		{ Ball = "Perfect300", Name = "Sun Disc", Fx = "SunDisc", Pins = 5300000000, Price = 6600000000000000, Rarity = "Legendary", Zone = 4 },
		{ Ball = "CanyonEcho", Name = "Canyon Echo", Fx = "Echo", Pins = 9100000000, Price = 15000000000000000, Rarity = "Mythic", Zone = 4 },
		{ Ball = "Mirage", Name = "Mirage", Fx = "Mirage", Pins = 15000000000, Price = 25000000000000000, Rarity = "Mythic", Zone = 4 },
		{ Ball = "Supernova", Name = "Golden Sphinx", Fx = "Sphinx", Pins = 26000000000, Price = 41000000000000000, Rarity = "Mythic", Zone = 4 },
	},
	-- Addendum 5 D: each ladder ball's own signature effect (Fx on its row above; client Modules/BallSignature).
	-- Visual and feel only, never a number. Strength 0..1 grows with the REAL pin count of the throw on a log scale:
	-- 0 at From pins, 1 at Full pins (so ball 10 with pets and rebirths keeps getting bigger even though only the 40
	-- rack pins fall). It scales particles, rings, flashes, camera shake, the crash volume and the coin pop.
	-- Only your own throws play it; other players' balls stay plain (SharedLane.OtherBalls). SETTINGS: EFFECTS off =
	-- no signature visuals (sounds stay), SCREEN SHAKE off = no shake. Big bits (screen flash, black hole pull,
	-- confetti cannon) play at most once every BigGap seconds so holding THROW never turns into a strobe.
	-- Effects: Force = how hard the drawn pins fly (x the normal knock), KnockFrom = where they fly away from
	-- ("Ball" = the hit point, "Center" = the middle of the rack: blast outward, "Side" = blown sideways, "Under" =
	-- lifted from the middle), Shake = camera shake at full strength, Color = its main colour.
	BallEffects = {
		Enabled = true,
		From = 6, -- pins at strength 0 (ball 1)
		Full = 1000000, -- pins at strength 1
		BigGap = 1.2, -- seconds between big bits
		PopGrow = 0.6, -- the total coin pop is up to this much bigger at strength 1
		CounterGrow = 0.3, -- the HUD pin counter punches up to this much more at strength 1
		CrashLoud = 0.6, -- the crash is up to this much louder at strength 1 (strength 0 = as before)
		CrashBig = 0.35, -- from this strength on the hit plays the big strike crash
		Effects = {
			Sand = { Force = 1, KnockFrom = "Ball", Shake = 0.15, Color = Color3.fromHex("F2C27A") }, -- sand puff
			Bounce = { Force = 1.05, KnockFrom = "Ball", Shake = 0.2, Color = Color3.fromHex("FF7AC8"), Hops = 3, HopHeight = 1.4 }, -- hops down the lane, bubble burst
			Confetti = { Force = 1.1, KnockFrom = "Ball", Shake = 0.25, Color = Color3.fromHex("9BE84A") }, -- confetti cannon
			Burn = { Force = 1.15, KnockFrom = "Ball", Shake = 0.3, Color = Color3.fromHex("FF8A1E") }, -- rolls on fire, flame burst, pins burn
			Frost = { Force = 1.2, KnockFrom = "Side", Shake = 0.3, Color = Color3.fromHex("8FDCFF") }, -- icy gust blows the pins sideways
			Arms = { Force = 1.25, KnockFrom = "Ball", Shake = 0.35, Color = Color3.fromHex("CFEBFF") }, -- two cloud arms sweep the rack
			Prism = { Force = 1.3, KnockFrom = "Center", Shake = 0.4, Color = Color3.fromHex("B48CFF") }, -- rainbow rings + arc
			Bolt = { Force = 1.35, KnockFrom = "Ball", Shake = 0.5, Color = Color3.fromHex("FFE45A") }, -- lightning chains pin to pin
			Tornado = { Force = 1.4, KnockFrom = "Under", Shake = 0.55, Color = Color3.fromHex("FFD45A") }, -- gold twister lifts the rack
			BlackHole = { Force = 1.7, KnockFrom = "Center", Shake = 0.75, Color = Color3.fromHex("B45CFF") }, -- black hole pulls in, then a sonic boom
			-- Zone 2, Sunset Boardwalk (Addendum 6 Stage 4)
			Shell = { Force = 1.2, KnockFrom = "Ball", Shake = 0.3, Color = Color3.fromHex("FFC6DD") }, -- pearly shell spiral, pearls scatter
			BeachBall = { Force = 1.25, KnockFrom = "Ball", Shake = 0.35, Color = Color3.fromHex("FF4D4D"), Hops = 1, HopHeight = 3.2 }, -- one big hop, beach-ball panels burst
			Kite = { Force = 1.25, KnockFrom = "Under", Shake = 0.3, Color = Color3.fromHex("4FD8E0") }, -- kites with rainbow tails lift off the rack
			Tide = { Force = 1.3, KnockFrom = "Side", Shake = 0.4, Color = Color3.fromHex("3CC8E6") }, -- a wave rolls across the rack
			Coral = { Force = 1.35, KnockFrom = "Center", Shake = 0.45, Color = Color3.fromHex("FF7A60") }, -- coral spikes burst out of the deck
			Surf = { Force = 1.4, KnockFrom = "Ball", Shake = 0.45, Color = Color3.fromHex("7FE8FF") }, -- a curling wave arches over and crashes
			Splash = { Force = 1.45, KnockFrom = "Under", Shake = 0.55, Color = Color3.fromHex("FF9A5A") }, -- sunset water column + rainbow
			Pound = { Force = 1.5, KnockFrom = "Center", Shake = 0.65, Color = Color3.fromHex("C8945A") }, -- a pier post drops out of the sky
			Tsunami = { Force = 1.6, KnockFrom = "Ball", Shake = 0.7, Color = Color3.fromHex("2AA8E0") }, -- a towering wave crashes over the rack
			Lighthouse = { Force = 1.7, KnockFrom = "Center", Shake = 0.75, Color = Color3.fromHex("FFE27A") }, -- lighthouse beam sweep, light pillar
			-- Zone 3, Jungle Falls (Addendum 6 Stage 5)
			Vine = { Force = 1.3, KnockFrom = "Side", Shake = 0.35, Color = Color3.fromHex("5CD65C") }, -- vines whip down and lash the rack
			Coconut = { Force = 1.35, KnockFrom = "Ball", Shake = 0.4, Color = Color3.fromHex("A8743E") }, -- coconuts rain down and crack open
			Toucan = { Force = 1.35, KnockFrom = "Under", Shake = 0.4, Color = Color3.fromHex("FF9A2E") }, -- a toucan swoops through, feathers burst
			LeafStorm = { Force = 1.4, KnockFrom = "Center", Shake = 0.45, Color = Color3.fromHex("6CF06C") }, -- a whirl of giant leaves blows out
			Waterfall = { Force = 1.45, KnockFrom = "Under", Shake = 0.5, Color = Color3.fromHex("7FE8FF") }, -- a waterfall pours onto the rack
			Jaguar = { Force = 1.5, KnockFrom = "Ball", Shake = 0.55, Color = Color3.fromHex("FFB020") }, -- three claw slashes rip across
			Bridge = { Force = 1.5, KnockFrom = "Side", Shake = 0.55, Color = Color3.fromHex("D6A060") }, -- a rope bridge snaps over the rack
			Temple = { Force = 1.6, KnockFrom = "Center", Shake = 0.65, Color = Color3.fromHex("FFC83C") }, -- glyph stones slam in, a gold sunburst
			Monsoon = { Force = 1.65, KnockFrom = "Center", Shake = 0.7, Color = Color3.fromHex("9BC8FF") }, -- storm cloud, rain, one huge lightning strike
			JungleKing = { Force = 1.8, KnockFrom = "Center", Shake = 0.8, Color = Color3.fromHex("FFD23C") }, -- a giant gold crown slams down, jungle roar
			-- Zone 4, Canyon Oasis (Addendum 6 Stage 6)
			DustDevil = { Force = 1.4, KnockFrom = "Side", Shake = 0.45, Color = Color3.fromHex("E8B878") }, -- a dust devil whirls across the rack
			Cactus = { Force = 1.45, KnockFrom = "Under", Shake = 0.5, Color = Color3.fromHex("5CC85C") }, -- saguaros burst up through the rack
			Mesa = { Force = 1.5, KnockFrom = "Center", Shake = 0.6, Color = Color3.fromHex("D2643C") }, -- a red mesa slams down from the sky
			Sandstorm = { Force = 1.55, KnockFrom = "Side", Shake = 0.55, Color = Color3.fromHex("F0B464") }, -- a wall of sand sweeps across
			Oasis = { Force = 1.6, KnockFrom = "Under", Shake = 0.6, Color = Color3.fromHex("3CDCD2") }, -- a turquoise spring erupts, palm fronds
			Scorpion = { Force = 1.65, KnockFrom = "Center", Shake = 0.65, Color = Color3.fromHex("FF7A3C") }, -- a giant scorpion tail stings the rack
			SunDisc = { Force = 1.7, KnockFrom = "Center", Shake = 0.7, Color = Color3.fromHex("FFD23C") }, -- a gold sun disc burns rays into it
			Echo = { Force = 1.75, KnockFrom = "Center", Shake = 0.75, Color = Color3.fromHex("FF9A5A") }, -- rock walls rise, the hit echoes x3
			Mirage = { Force = 1.8, KnockFrom = "Center", Shake = 0.75, Color = Color3.fromHex("7AF0E6") }, -- shimmering ghost balls converge
			Sphinx = { Force = 1.9, KnockFrom = "Center", Shake = 0.85, Color = Color3.fromHex("FFC83C") }, -- a golden sphinx rises, eye beams
		},
	},
	-- Bags: BagSizes[BagLevel] pins fit (Addendum 6: the bag holds pins, a sell turns them into coins); BagPrices[n] buys bag n (bag 1 is free). Bag n fills in ~10 throws (bag 1)
	-- to ~40 throws (bag 10) with ball n. Bag pacing (A2): its own ladder, each bag lands about 40% of the way
	-- between two balls (bag 2 ~1 min, bags 3-4 ~2 min apart, then ~5 min apart, bag 10 ~3 min after ball 10).
	-- A small bag caps your income (a throw that doesn't fit pays only what fits), so bags matter as much as balls.
	-- Addendum 6 Stage 3: bags 11-40 = zones 2-4 (Ladders.BagZones); each holds ~40 throws of its zone's ball, its price
	-- lands ~40% of the way to the next ball. Addendum 6 Stage 9: bags 12-40 re-priced with the balls (same share of the
	-- way between two balls as before; bags 1-11 unchanged).
	BagSizes = { 60, 140, 300, 700, 1600, 3700, 8700, 21000, 50000, 130000,
		220000, 370000, 640000, 1100000, 1800000, 3100000, 5200000, 8800000, 15000000, 26000000, 44000000, 76000000, 130000000, 220000000, 370000000, 640000000, 1100000000, 1800000000, 3100000000, 5200000000, 8800000000, 15000000000, 26000000000, 44000000000, 72000000000, 120000000000, 210000000000, 360000000000, 600000000000, 1000000000000 },
	-- Addendum 5 E: bags 6-10 re-priced with balls 6-10 (still ~40% of the way between two balls). Was 11K, 24K,
	-- 54K, 120K, 420K.
	BagPrices = { 0, 240, 600, 990, 5200, 7400, 29000, 75000, 200000, 690000,
		5000000, 11000000, 18000000, 36000000, 100000000, 260000000, 920000000, 3300000000, 5600000000, 8200000000, 31000000000, 49000000000, 99000000000, 150000000000, 330000000000, 1000000000000, 2500000000000, 6100000000000, 12000000000000, 25000000000000, 120000000000000, 170000000000000, 340000000000000, 710000000000000, 1200000000000000, 3400000000000000, 9400000000000000, 18000000000000000, 30000000000000000, 56000000000000000 },
	Ladders = {
		Independent = true, -- Addendum 5 A2: two ladders (false = Addendum 4's ball, bag, ball, bag order)
		-- Addendum 6 2.2: buy ANY ball or bag above your best one that you can pay for, in an open zone (no need to
		-- buy the one before). Pins per throw always come from the best ball you own, bag room from the best bag.
		-- Balls / bags below your best that you never bought are "Skipped": still for sale at their normal price, for
		-- the look only (owned balls can be equipped for their look; the pins stay the best ball's). false = only
		-- the next one is for sale (Addendum 5).
		BuyAny = true,
		-- The zone a ball / bag belongs to: a Balls row's Zone (no Zone = 1), bags BagZones[level] (none = 1). Rows
		-- of zones you haven't opened show in the shop greyed out with a lock. Today only zone 1 exists (Stage 3+).
		BagZones = { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4 },
	},
	-- Gifts in the core loop (owner 2026-11-01: scale to income): daily, playtime and level rewards pay CoreMinutes
	-- (on each reward row; RewardMinutes when a row has none) of the income your ball + bag make now (ladder income,
	-- sell trips of TripSeconds counted, no multipliers). A crate in a reward pays CrateMinutes of it instead, since
	-- crates no longer give balls. Away coins measure your real throws.
	-- Addendum 5 F: each throw's coins fly as a "+25" from the pin counter into the bag (CoreHudController)
	Gains = { Enabled = true, Max = 6, Bow = 0.3 }, -- Max = at most this many in the air at once; Bow = curve (0 = straight)
	Gifts = {
		TripSeconds = 6,
		RewardMinutes = 2,
		CrateMinutes = 5,
	},
	-- The ball shop booth in the plaza: stand on its blue circle to open the shop. Addendum 5 A2: everything is
	-- bought here only. The server refuses a buy unless you stand within Radius + BuySlack studs (flat) of the
	-- circle; the HUD BALLS window is a price list only (its GO TO SHOP button takes you here).
	Shop = {
		Position = Vector3.new(-17, 848.65, -3415),
		Radius = 4.5,
		BuySlack = 4, -- extra studs for lag (walking off while the buy is on its way)
		Color = Color3.fromRGB(64, 160, 236), -- sky blue
		-- Addendum 6 2.1: the shop window's tabs, left to right (CoreShopController builds one page per Id it
		-- knows; Stage 8 added "Gamepasses" here). The PET SLOTS row sits at the bottom of the Bags tab.
		-- Polish v2 U1 (owner 2026-11-03): passes are sold only in the STORE, so "Gamepasses" is out of this list
		-- (put it back to bring the shop's PASSES tab back).
		Tabs = { "Balls", "Bags", "Rebirth" },
		-- Addendum 6 Stage 8: the Gamepasses tab's cards, in order (Ids of Config.Monetization.Passes; the pass rows
		-- hold the IDs, prices and words). A pass whose PassId is still 0 is hidden in the live game (Studio shows
		-- it as NO ID YET). The small HUD PASSES button opens this tab; Robux buys work anywhere, not only at the booth.
		-- Addendum list -> pass: 2x Coins = DoubleCoins, 2x Pins = DoublePins, Lucky Eggs = Lucky + SuperLucky,
		-- Triple Hatch = TripleHatch, Auto Swing = AutoBowl, +2 Pet Slots = PetSlots (VIP is an extra, kept).
		Gamepasses = { "DoubleCoins", "DoublePins", "Lucky", "SuperLucky", "TripleHatch", "AutoBowl", "PetSlots", "VIP" },
		RebirthTab = true, -- the HUD REBIRTH button opens the shop's Rebirth tab (false = the old rebirth window)
		HoldSeconds = 1.5, -- Addendum 6 2.4: hold the REBIRTH button this long to rebirth
		RevealSeconds = 1.6, -- Addendum 6 2.3: the reveal after buying a ball / bag (flash, colour, name, effect); under 2
	},
	-- Addendum 5 A2: the SELL and GO TO SHOP buttons teleport you onto the pad (once every Cooldown seconds)
	Teleport = {
		Cooldown = 1.5,
		Height = 3, -- studs above the pad floor the character lands
	},
	-- Stage 3b plaza props: copies of existing models (the originals stay where they are), placed at server start in
	-- <Folder>.Plaza. From = path from Workspace, At = floor point under the model's middle, Turn = degrees around Y.
	-- Main Street's models face +Z with Turn 0 (sofas face -Z). Cases = the zone 4 display case row, one case per
	-- ladder ball (Config.Showcase set with Ladder = true): First = floor point of case 1, Step = to the next.
	-- 2026-11-03 v2 models: a zone's own designed station pieces (models in ServerStorage.ZoneKits.Zone<n>, pivot at
	-- their bottom centre, front -Z; CoreLoopService placeKit). Sell / Shop stand behind their circle (the circles
	-- stay), Gate = the NEXT gate (turned to face the plaza; GateShift moves it off the roof rail, GateBoard = the
	-- blank board the price goes on). A missing kit or zone = the plain part-built booth.
	Kits = {
		[1] = { Sell = "Sell", Shop = "Shop", Gate = "Gate", GateShift = Vector3.new(0, 0, -1.6), GateBoard = "PriceBoard_Blank" },
		-- zone 2 (owner's SL_Z2 beach-hut stalls + driftwood arch; GateSign = its blank board that names the next zone)
		[2] = { Sell = "Sell", Shop = "Shop", Gate = "Gate", GateBoard = "PriceBoard_Blank", GateSign = "DestinationSign_Blank" },
		-- zone 3 (owner's SL_Z3 bamboo + stone stalls and the carved Canyon Oasis gate, its name already on it)
		[3] = { Sell = "Sell", Shop = "Shop", Gate = "Gate", GateBoard = "price_board_slot_BLANK" },
		-- zone 4 (owner's SL_Z4 adobe market stalls; the last zone, so its banded sandstone arch is the BACK gate,
		-- doors always open, JUNGLE FALLS on its destination board)
		[4] = { Sell = "Sell", Shop = "Shop", BackGate = "Gate", GateBoard = "price_board_blank", GateSign = "sign_destination_board" },
	},
	Plaza = {
		Props = {
			-- (the two ball racks either side of the ball shop went 2026-11-03: the designed shop stall shows its balls)
			-- lounges in the open half (Addendum 5 B2: moved out of the egg row's way, two behind the row and one
			-- facing the eggs; were (40, -3418), (76, -3418), (58, -3450), all Turn 180)
			{ From = { "MainStreetLanes", "Design", "Seating", "BowlerArea1" }, At = Vector3.new(36, 848.65, -3463), Turn = 0 },
			{ From = { "MainStreetLanes", "Design", "Seating", "BowlerArea2" }, At = Vector3.new(70, 848.65, -3463), Turn = 0 },
			{ From = { "MainStreetLanes", "Design", "Seating", "BowlerArea3" }, At = Vector3.new(58, 848.65, -3404), Turn = 0 },
			-- a ball rack between the lanes and the lounges
			{ From = { "MainStreetLanes", "Design", "HouseBallRacks", "HouseBallRack3" }, At = Vector3.new(22, 848.65, -3452), Turn = 90 },
		},
		Cases = {
			First = Vector3.new(24.5, 848.65, -3393),
			Step = Vector3.new(7.5, 0, 0),
		},
	},
	-- Addendum 5 B2: the EGG ROW next to the shop. Four eggs in a price ladder, bought with coins only (a hatch only
	-- works standing at that egg's stand: Config.MascotFx.HatchRange, server check). Each egg has its own pets and its
	-- own rarity odds (Odds = chance per rarity; pets of one rarity share it), so a pricier egg hatches rarer pets.
	-- The stands are copies of the existing stands, built at server start in <Folder>.EggRow (one Model per egg,
	-- named by its Id; the originals stay where they are). From = the stand to copy (path from Workspace; the roof's
	-- own Skyline stand is hidden first, so it is copied from ServerStorage.CoreLoopHidden), At = floor point under
	-- its pad, Turn = degrees around Y so its sign faces the shop side (+Z), Tint = hue-shift the copy's colours
	-- (the 4th egg re-uses the Neon stand + Neon Egg model in volcano colours, no new art), Sign = text on its sign.
	-- Prices: checked with require(game.ServerStorage.Tools.EconomySim).CoreEggs() against the A2 ladders: the first
	-- egg at ~2 min, then ~11 min, ~23 min and ~31 min (a player buying the cheapest next thing, one of each egg; its
	-- pets pull ball 10 in from ~31 to ~26 min, so extra hatches and rebirth (step C) have room).
	-- Pets: Config.Mascots rows (Stats there). Each egg needs one pet per rarity it has odds for.
	Eggs = {
		Enabled = true, -- false = the old zone eggs (and their zone gates) back
		-- Addendum 6 3.3: ONE egg per zone, bought with coins at that zone's stand (Zone = the zone it stands in; At is in
		-- zone 1's layout and moves with the zone's Offset, Config.CoreLoop.Zones). Zone 1 = the new cheap Speckled Egg
		-- (PLACEHOLDER: the Neon stand + Neon Egg re-tinted, 3 new pets on borrowed models); the Neon Egg moved to zone 2
		-- (its original 6 pets, Uncommon to Epic); zone 3 = the Main Street Egg (Rare to Legendary), zone 4 = the Skyline
		-- Egg (Epic to Mythic). The Volcano Egg is out of the list (its pets went to zones 3/4; owners keep every pet).
		-- Prices: zone 1 ~minute 3-5 (ball 4-5 income); zones 2-4 ~4 min of income with that zone's ball 2.
		-- Addendum 6 Stage 9: zones 2-4 x their ball 2's re-price, zone 3 x3 and zone 4 x6 more on top (egg prices
		-- don't grow with rebirths, so later hatches were almost free and zone 4 pets snowballed). A hatch costs
		-- ~1 min of income the first time you reach each egg. Was Neon 19M, Main Street 23B, Skyline 28T.
		List = {
			{
				Id = "Speckled", -- the Rooftop Egg (zone 1 starter; Id kept from the Speckled Egg so saves keep working)
				Zone = 1,
				Price = 750,
				-- 2026-11-03: the owner's water-tank stand (SL_Z1_RooftopEgg_full; was the Neon stand re-tinted)
				From = { "ServerStorage", "ZoneKits", "Zone1", "RooftopEgg" },
				At = Vector3.new(26, 848.65, -3438),
				Turn = 90, -- its steps face west, toward the shop
				Odds = { Common = 65, Uncommon = 30, Rare = 5 },
				Pets = { "Gus", "Pebble", "Bumper", "Breezy", "Sunspot" },
			},
			{
				Id = "Alley", -- the Sunset Egg (was the Neon Egg; Id kept so saves keep working)
				Zone = 2,
				Price = 33000000,
				-- 2026-11-03: the owner's pier-post stand (SL_Z2_SunsetEgg_full; was the Hub's Neon stand, sign NEON EGG)
				From = { "ServerStorage", "ZoneKits", "Zone2", "SunsetEgg" },
				At = Vector3.new(26, 848.65, -3438),
				Turn = 90, -- its steps face west, toward the shop
				Odds = { Uncommon = 60, Rare = 33, Epic = 7 },
				-- (Neon Bat left 2026-11-03: the zone 2 designs are 5 pets; owners keep it)
				Pets = { "Pinny", "LanePup", "Strikey", "Splitz", "Hambone" },
			},
			{
				Id = "Arcade", -- the Jungle Egg (was the Main Street Egg; Id kept so saves keep working)
				Zone = 3,
				Price = 360000000000,
				-- 2026-11-03: the owner's stone altar (SL_Z3_Egg_JungleEgg_OnStand; was MainStreetLanes.EggPad)
				From = { "ServerStorage", "ZoneKits", "Zone3", "JungleEgg" },
				At = Vector3.new(26, 848.65, -3438),
				Turn = 90, -- its front faces west, toward the shop
				Odds = { Rare = 60, Epic = 33, Legendary = 7 },
				Pets = { "WoodPup", "ChromeBat", "Kingpin", "Blaze" },
			},
			{
				Id = "Skyline", -- the Sun Egg (was the Skyline Egg; Id kept so saves keep working)
				Zone = 4,
				Price = 2900000000000000,
				-- 2026-11-03: the owner's sandstone pedestal with its gold sun (SL_Z4_SunEgg_Eggonstand; was SkylineLanes.EggPad)
				From = { "ServerStorage", "ZoneKits", "Zone4", "SunEgg" },
				At = Vector3.new(26, 848.65, -3438),
				Turn = 90, -- its front faces west, toward the shop (the sun disc behind the egg)
				Odds = { Epic = 62, Legendary = 33, Mythic = 5 },
				Pets = { "CloudBumper", "SunnyHam", "Cosmo", "Perfecto" }, -- (Titan Jr. stays the boss pet)
			},
		},
		-- Hue shifts for Tint (hue 0..1 ranges -> new hue; saturation and brightness kept, dark colours darker)
		Tints = {
			-- Addendum 6 3.3 PLACEHOLDER: the Speckled Egg + its stand, every colour turned warm sand / sky
			Speckled = {
				{ From = 0.4, To = 0.72, Hue = 0.55 }, -- cyan / blue / purple -> sky blue
				{ From = 0.72, To = 1.0, Hue = 0.1, Dark = 1.1 }, -- magenta / pink -> sand
				{ From = 0.0, To = 0.4, Hue = 0.1, Dark = 1.1 },
			},
			Volcano = {
				{ From = 0.72, To = 1.0, Hue = 0.045 }, -- magenta / pink -> orange
				{ From = 0.0, To = 0.04, Hue = 0.045 },
				{ From = 0.4, To = 0.6, Hue = 0.12 }, -- cyan -> gold
				{ From = 0.6, To = 0.72, Hue = 0.0, Dark = 0.7 }, -- blue / purple -> deep red
			},
		},
		-- The Shiny merge on the roof: a copy of zone 3's PET FUSION machine at the end of the egg row (Config.Fusion
		-- points at it while Enabled). Its prompt opens the PET FUSION window (3 copies -> 1 Shiny).
		Fusion = {
			From = { "MainStreetLanes", "FusionStation" },
			Name = "PetFusion",
			At = Vector3.new(96, 848.65, -3418),
			Turn = 90, -- faces west, toward the shop
		},
		-- GO TO EGGS (PETS window, no pets yet): CoreGoTo "Eggs" lands you here, facing the first egg
		GoTo = Vector3.new(26, 848.65, -3430),
	},
	-- Addendum 6 Stage 3: the FOUR ZONES. Each is one big shared lane with its own sell pad, ball shop, egg stand,
	-- spawn and gates, all built from code in zone 1's layout (Sell, Shop, Spawn, SharedLane, Eggs At) moved by the
	-- zone's Offset. Zone 1 = the rooftop (SkylineLanes). Zones 2-4 have no maps yet: Placeholder = true builds a flat
	-- ground in the zone's palette (every part tagged "Placeholder") until Stages 4-6 build the real maps there.
	-- PinValue = coins a pin sells for at that zone's sell pad (x6 a zone). Price = coins to open the zone at its gate
	-- (about the zone before's ball 7, x the rebirth price growth like the ladder). A rebirth closes every zone but 1.
	-- Pins per throw still come from your best ball (the ladder's Pins); only 40 pins are drawn per throw in every zone.
	Zones = {
		Enabled = true,
		List = {
			{ Name = "Skyline Rooftop", Folder = "SkylineLanes", Offset = Vector3.zero, PinValue = 1, Price = 0 },
			{
				Name = "Sunset Boardwalk",
				Folder = "SunsetBoardwalk",
				Offset = Vector3.new(0, -800, 8000),
				PinValue = 6,
				Price = 22000,
				-- Stage 4: the real map (server/Modules/ZoneMaps "Boardwalk"): a wooden pier over Terrain water, a sand
				-- beach with umbrellas, palms and huts to the east, a lighthouse past the pit, kites, boats, a ferris wheel
				Map = "Boardwalk",
				Palette = { Ground = Color3.fromRGB(240, 214, 150), Edge = Color3.fromRGB(64, 206, 214), Accent = Color3.fromRGB(255, 120, 100) },
				-- the lane in deep sea navy (matt), so the beach effects (foam, coral, gold) read on it (Addendum 6 1.2)
				Lane = { Wood = { Color3.fromRGB(26, 50, 96), Color3.fromRGB(22, 44, 86) }, Deck = Color3.fromRGB(32, 60, 110) },
				-- Polish v2 L3: its own warm late-afternoon look (low golden sun, peach haze, warm shadow fill)
				LookChanges = {
					ClockTime = 16.8,
					Brightness = 1.8,
					Ambient = Color3.fromRGB(118, 104, 98),
					OutdoorAmbient = Color3.fromRGB(160, 140, 150),
					Exposure = 0,
					Saturation = 0.22,
					Tint = Color3.fromRGB(255, 238, 220),
					HazeColor = Color3.fromHex("FFD9B8"),
					HazeDecay = Color3.fromHex("FFA77E"),
					HazeDensity = 0.28,
					Haze = 0.6,
				},
			},
			{
				Name = "Jungle Falls",
				Folder = "JungleFalls",
				Offset = Vector3.new(2500, -800, 8000),
				PinValue = 36,
				Price = 320000000,
				-- Stage 5: the real map (server/Modules/ZoneMaps "Jungle"): a grass valley, a waterfall pool and Terrain
				-- cliffs past the pit (four falls, high rope bridges), a river with a rope bridge to a temple ruin
				Map = "Jungle",
				Palette = { Ground = Color3.fromRGB(96, 184, 84), Edge = Color3.fromRGB(70, 210, 220), Accent = Color3.fromRGB(255, 150, 50) },
				-- the lane in deep mahogany (matt), so the green, gold and water effects read on it (Addendum 6 1.2)
				Lane = { Wood = { Color3.fromRGB(78, 40, 34), Color3.fromRGB(70, 36, 30) }, Deck = Color3.fromRGB(88, 48, 40) },
				-- Polish v2 L3: its own soft green look (high sun through a light jungle haze, green shadow fill)
				LookChanges = {
					ClockTime = 13.5,
					Brightness = 1.8,
					Ambient = Color3.fromRGB(100, 112, 96),
					OutdoorAmbient = Color3.fromRGB(122, 150, 128),
					Exposure = 0,
					Saturation = 0.22,
					Contrast = 0.1,
					Tint = Color3.fromRGB(244, 255, 238),
					HazeColor = Color3.fromHex("CFEBC8"),
					HazeDecay = Color3.fromHex("EEF4CC"),
					HazeDensity = 0.32,
					Haze = 1,
				},
			},
			{
				Name = "Canyon Oasis",
				Folder = "CanyonOasis",
				Offset = Vector3.new(5000, -800, 8000),
				PinValue = 216,
				Price = 1500000000000,
				-- Stage 6: the real map (server/Modules/ZoneMaps "Canyon"): a sandy canyon floor, a turquoise lake past
				-- the pit with a huge stone arch and hoodoos, banded red Terrain walls with a gap to far buttes, a palm
				-- oasis pond with market tents and a golden sphinx to the east, adobe houses, saguaros, hot-air balloons
				Map = "Canyon",
				Palette = { Ground = Color3.fromRGB(214, 124, 84), Edge = Color3.fromRGB(56, 200, 200), Accent = Color3.fromRGB(255, 200, 70) },
				-- the lane in deep plum (matt), so the sand, gold, fire and turquoise effects read on it (Addendum 6 1.2)
				Lane = { Wood = { Color3.fromRGB(66, 34, 62), Color3.fromRGB(58, 30, 56) }, Deck = Color3.fromRGB(76, 40, 70) },
				-- a warmer, golden desert haze than the rooftop's sky blue; Polish v2 L3: hot and golden (bright high sun,
				-- warm sand fill in the shadows, a touch less exposure so the pale sand doesn't blow out)
				LookChanges = {
					ClockTime = 14.5,
					Brightness = 2.3,
					Ambient = Color3.fromRGB(128, 110, 92),
					OutdoorAmbient = Color3.fromRGB(176, 150, 124),
					Exposure = -0.12,
					Saturation = 0.2,
					Tint = Color3.fromRGB(255, 242, 218),
					HazeColor = Color3.fromHex("FFE6C4"),
					HazeDecay = Color3.fromHex("FFC08A"),
					HazeDensity = 0.24,
					Haze = 0.5,
				},
			},
		},
		-- The gates, in zone 1's layout (moved by each zone's Offset): Next = the gate to the next zone (pay once to open,
		-- then free), Back = the free gate to the zone before. Hold the prompt to use one; Radius = the server's distance check.
		Gates = {
			Next = Vector3.new(-96, 848, -3398), -- (the roof's west edge, behind the spawn)
			Back = Vector3.new(-96, 848, -3421),
			Radius = 12,
		},
		-- Placeholder ground for zones 2-4: this big a slab around the layout (centre in zone 1's layout), top at its Y
		Ground = { Centre = Vector3.new(-10, 848.65, -3480), Size = Vector3.new(260, 4, 300) },
	},
	-- Addendum 5 step C: REBIRTH, bought with coins only at the ball shop (server distance check, like every buy),
	-- whenever you can pay; never forced. It resets coins, the bag (its coins and its level), the ball ladder and the
	-- throw speed upgrades; it keeps pets (all of them, equipped, Shiny), pet slots (Config.PetStats.KeepPetSlots)
	-- and the rebirth count. Each rebirth adds Bonus to the coin boost and PinBonus to the pin boost (Addendum 6
	-- 1.1 Boosts: the Add group, with the pets). Price n = Prices[n], then the last one x Growth each.
	-- Addendum 6 Stage 7 numbers and the sim below (the Addendum 5 notes on EconomySim.CoreRebirth were for one zone).
	-- Ranks (Addendum 6 2.4; were Tiers): what each rebirth count changes in the world, from existing parts
	-- only: your own pins' rings, the ring of your throw spot (everyone sees it) and the REBIRTH tag over your head.
	Rebirth = {
		Enabled = true, -- false = no rebirth in the core loop (button hidden, server refuses)
		-- Addendum 6 Stage 7 (rebirth pacing, tuned with tools/pacing_sim.py, the four-zone sim; run
		-- python tools/pacing_sim.py): the four zones grow income ~x100 or more a zone, so a price that only
		-- grows x3 a rebirth trapped players who rebirth as soon as they can in zone 2 for good (rebirth every
		-- ~20 min, never deeper; waiting got much further). Prices are now set by WHERE each rebirth should come
		-- (addendum 7.3), each about 4-5 minutes of the income you have when you get there:
		--   1 = Zone 1 ladder done (5.4M, ~4.5 min of income then; sim: rebirth at ~35 min, in zone 2's first balls)
		--   2 = middle of Zone 2 (sim ~56 min), 3 = start of Zone 3 (~1h11), 4 = end of Zone 3 (~1h20),
		--   5-7 = Zone 4, then x Growth (3, as the addendum says) each.
		-- Was Prices { 10M, 25M, 60M, 120M, 220M, 380M }, Growth 1.5 (Addendum 5 E).
		-- Addendum 6 Stage 9 (pacing pass, with the re-priced zones 2-4): each rebirth from 2 on costs a bit less than
		-- the next ball at its spot, so it comes there and takes ~2-3 min to save: 2 = after zone 2 ball 7 (sim ~1h01),
		-- 3 = zone 3 ball 2 (~1h28), 4 = zone 3 ball 10 (~2h12), 5 = zone 4 ball 3 (~2h52), 6 = zone 4 ball 6 (~3h32),
		-- 7 = zone 4 done (~4h20). Was 5.4M, 450M, 88B, 2T, 7.1Qa, 60Qa, 400Qa.
		Prices = { 5400000, 3800000000, 120000000000, 200000000000000, 1200000000000000, 14000000000000000, 220000000000000000 }, -- rebirth 1, 2, 3... (then the last one x Growth each)
		Growth = 3,
		-- Stage 7 boost: the addendum's starting point (+50% coins, +25% pins) lost to waiting (a player who waited
		-- 20 min after a rebirth was ready got further than one who rebirthed at once), so it is raised (7.4: raise the
		-- boost, never lower the price) until rebirthing at once is as fast or faster: +200% coins, +100% pins a rebirth.
		-- After rebirth n: coins x (1 + 2n + pets ...), pins x (1 + n + pets ...). Was 1 / 1 (Addendum 6 Stage 1).
		Bonus = 2, -- coins: +200% a rebirth, added into the Add group of Boosts.Coins (Addendum 6 1.1)
		PinBonus = 1, -- pins per swing: +100% a rebirth (Boosts.Pins)
		-- Ball, bag and gate prices x (1 + Bonus x rebirths) ^ LadderPower after a rebirth (x1.6 after 1, x2.0 after 2,
		-- x2.3 after 3 ...), so the climb back takes about half the run before (7.2; sim: 23% after rebirth 1, then
		-- 44-59%). Was 1.6 (Addendum 5 C).
		LadderPower = 0.4,
		-- Addendum 6 2.4: rebirth RANKS, the old Pro Tier names from GAME_DESIGN.md in order (Rookie = no rebirth yet,
		-- rank n+1 = after rebirth n), then more in the same style. Past the list: the last name II, III ... The rank
		-- shows in the shop's Rebirth tab, over your head and on the leaderboards; its colour paints your pins' rings
		-- and your throw spot from rebirth 1 on. (Was Tiers BRONZE 1, SILVER 2, GOLD 3, EMERALD 5, DIAMOND 8,
		-- RUBY 12, COSMIC 20.)
		Ranks = {
			{ Name = "Rookie", Color = Color3.fromRGB(235, 235, 240) },
			{ Name = "Amateur", Color = Color3.fromRGB(222, 140, 70) },
			{ Name = "Regular", Color = Color3.fromRGB(200, 222, 240) },
			{ Name = "Club", Color = Color3.fromRGB(255, 205, 60) },
			{ Name = "Semi-Pro", Color = Color3.fromRGB(70, 230, 130) },
			{ Name = "Pro", Color = Color3.fromRGB(110, 225, 255) },
			{ Name = "Elite", Color = Color3.fromRGB(84, 132, 255) },
			{ Name = "Master", Color = Color3.fromRGB(190, 110, 255) },
			{ Name = "Legend", Color = Color3.fromRGB(255, 70, 100) },
			{ Name = "Hall of Famer", Color = Color3.fromRGB(255, 180, 40) },
			{ Name = "Superstar", Color = Color3.fromRGB(255, 120, 200) },
			{ Name = "Icon", Color = Color3.fromRGB(80, 240, 220) },
			{ Name = "Champion", Color = Color3.fromRGB(255, 225, 90) },
			{ Name = "World Champion", Color = Color3.fromRGB(255, 150, 60) },
			{ Name = "Immortal", Color = Color3.fromRGB(170, 255, 120) },
			{ Name = "Titan", Color = Color3.fromRGB(150, 170, 255) },
			{ Name = "Bowling God", Color = Color3.fromRGB(255, 240, 160) },
		},
	},
	-- Stage 3 first 30 seconds: until ball 2 is bought a card under the pin counter says Throw > Sell > Buy and beams
	-- lead to the sell pad, then to the shop. The join daily window waits until then too.
	Guide = {
		Enabled = true,
		DoneSeconds = 3, -- the "done" card stays this long after ball 2
	},
	FullClearMultiplier = 2, -- (Addendum 4 only: every pin down paid double; Addendum 5 A1 has no full clear, unused)
	-- Coins: each pin = PinValue coins x these multipliers (MultiplierService.Coins names; zone, power, rank, streak
	-- and ball are left out on purpose, Stage 2 prices balls on pins per throw)
	PinValue = 1,
	-- (Addendum 5 step C: "Rebirth" left out: the rebirth multiplier pays on the SELL instead, CoreLoop.Rebirth)
	-- (Addendum 6 1.1: no longer used to pay: Boosts below is the only formula. Kept for the old loop's code.)
	Multipliers = { "Mascots", "Potion", "Friends", "Passes", "RobuxBoost" },
	-- Addendum 6 1.1: the ONE coin multiplier and the ONE pin multiplier (MultiplierService.GetCoinMultiplier /
	-- GetPinMultiplier; nothing else computes one). The bag holds PINS; a sell pays pins x PinValue x the coin
	-- multiplier, so every coin boost shows on every sell (before, boosts went in before the bag's limit and a full bag
	-- swallowed them). Total = (1 + every Add source's bonus added up) x every Times source, in order.
	-- Add: Pets = the equipped pets' Coins / Pins stat (0.5 = +50%), Rebirth = Config.CoreLoop.Rebirth Bonus / PinBonus
	-- x rebirths, Friends = +10% a friend in the server (Config.Friends).
	-- Times: Potion = the strongest running potion of that kind (Config.Potions), Passes = owned game passes' Coins /
	-- Pins (Config.Monetization), CoinBoost = the COIN BOOST ladder bought with Robux.
	Boosts = {
		Coins = { Add = { "Pets", "Rebirth", "Friends" }, Times = { "Potion", "Passes", "CoinBoost" } },
		Pins = { Add = { "Pets", "Rebirth" }, Times = { "Potion", "Passes" } },
	},
	-- Stage 3c: XP per throw = pins x XpPerPin x these (MultiplierService.Xp names; zone and streak left out), so levels,
	-- level rewards and ranks move again. Ranks come with levels: no rank trials in the core loop.
	XpPerPin = 1,
	XpMultipliers = { "Potion", "Rebirth", "Passes", "XpBoost" },
	-- Stage 3c: profile stats (Config.Profile.Stats Key) and achievements (their Stat) the rooftop can't move; hidden
	-- Rooftop stations moved to ServerStorage.CoreLoopHidden (Stage 2 crate kiosk; Stage 3c egg stand, pets wait for Stage 5)
	HiddenStations = { "CrateShop", "EggPad" },
	HideProfile = { "Perfects", "BestStreak", "Eggs", "Crates", "Pets", "BossWins", "Zones", "Level", "Strikes" },
	-- (Addendum 5 step C: "Rebirths" shows again; rebirth is back in the core loop)
	-- (Addendum 5 A1: "Level" and "Strikes" too: no levels, no full clears)
	-- Hold to keep throwing: seconds between throws = Cooldown - ThrowSpeedLevel x CooldownStep, never below
	-- CooldownFloor (raise the floor if frame time suffers). ThrowSpeedLevel is saved; the upgrade shop is Stage 2.
	Cooldown = 1.0,
	CooldownStep = 0.1,
	CooldownFloor = 0.4,
	RollTime = 0.45, -- seconds from release to the pins (a fast arcade roll down the 117-stud lane)
	RefillDelay = 0.25, -- seconds after the ball hits until the fresh rack stands (keep under CooldownFloor)
	-- Pins: the new rack stands the moment the ball has hit; knocked pins fly on as debris for DebrisLife seconds
	-- (at most DebrisCap per lane, oldest go first), then go back into the pool.
	DebrisLife = 0.9,
	DebrisCap = 60,
	PopsPerThrow = 8, -- coin numbers over pins per throw (one per pin up to this many; the total pops too)
	BigClear = 24, -- drawn pins a LUCKY throw needs for the camera shake + crash sound (Addendum 5 A1)
	-- Bag: pins go here (Addendum 6: pins, not coins), not to your coins (BagSizes above, bought in the shop).
	-- Selling only happens at the sell station (owner 2026-11-01); the SELL button teleports you onto its pad
	-- (Addendum 5 A2, Teleport above), where the bag sells.
	-- A "sell anywhere" pass or upgrade can come later.
	Sell = {
		-- floor centre of the pad, in the strip behind the lane approaches (lanes 1 and 6 are ~2.7 s away; the middle
		-- ball return is just in front of it, the lounge sofas just behind the booth)
		Position = Vector3.new(-37, 848.65, -3415),
		Radius = 6, -- studs (flat) from the centre that count as standing on it
		Color = Color3.fromRGB(64, 196, 92), -- coin green
	},
	Spawn = Vector3.new(-37, 849.2, -3395), -- the rooftop spawn, just behind the sell stall (was z -3398 until the 2026-11-03 stall)
	CameraBack = 9, -- while you throw, the camera hovers this far before the head pin...
	CameraHeight = 5.5, -- ...this high
	CameraLook = 6, -- looking this far past the head pin
	CameraBlend = 0.35, -- seconds to glide into (and out of) the throw camera
	-- Addendum 5 A3: ONE shared lane on the roof (built from code at server start by server/Modules/SharedLane, model
	-- <Folder>.SharedLane). Everyone throws down it at once, each from their own throw spot across its width. Each
	-- spot is a small invisible "lane" model (BallStart, PinSpot, Approach, LaneFloor, PinDeck, Stand) in
	-- SharedLane.Spots, so cooldowns (ReadyAt), lane skins and the throw camera stay per player. Your pins are drawn
	-- only on your own screen (one 40-pin rack per client); counting stays on the server. The old 6 lanes, their
	-- approach lines and the 6-lane floor decor (Hide) move to ServerStorage.A5OldLanes at start (never deleted;
	-- the place file keeps them). Enabled = false brings the 6 lanes back.
	SharedLane = {
		Enabled = true,
		Centre = -36.54, -- x of the lane's middle (the old 6 lanes' middle)
		Width = 99.4, -- wood between the two outer gutter walls (the old outer dividers stay)
		FloorY = 848.655, -- top of the wood (the pins stand here)
		FoulZ = -3451, -- the lane starts here (the gold foul line) ...
		DeckZ = -3562, -- ... the pin deck starts here ...
		EndZ = -3581.2, -- ... and the wood ends at the pit
		BallStartZ = -3451.72, -- where every ball starts rolling
		PinSpotZ = -3568.25, -- the head pin spot of every rack (same as the old lanes)
		ApproachZ = -3441, -- middle of each spot's throw box (Approach), ApproachDepth deep
		ApproachDepth = 19.4,
		ApproachTop = 848.7, -- top of the approach floor
		StandZ = -3444, -- where you stand on your spot (its ring)
		Spots = 12, -- throw spots across the width, Spacing studs apart, handed out middle first
		Spacing = 8,
		-- More players than spots: spot 13+ sit halfway between two spots (Shift), then a row further back (Back)
		MaxSpots = 60, -- (the place allows 60 players)
		Shift = 4,
		Back = 3,
		OtherBalls = 8, -- most other players' balls drawn at once (one plain anchored ball, no effects); 0 = none
		Groups = { Pins = "SL_PinView", Players = "SL_Players", Balls = "SL_Balls" }, -- collision groups
		-- spot ring colours (rainbow, spot 1 = left)
		Colors = {
			Color3.fromRGB(255, 99, 99), Color3.fromRGB(255, 146, 76), Color3.fromRGB(255, 196, 60),
			Color3.fromRGB(176, 222, 64), Color3.fromRGB(84, 206, 110), Color3.fromRGB(48, 204, 180),
			Color3.fromRGB(64, 184, 240), Color3.fromRGB(84, 132, 240), Color3.fromRGB(140, 110, 236),
			Color3.fromRGB(190, 100, 230), Color3.fromRGB(244, 104, 190), Color3.fromRGB(255, 120, 140),
		},
		-- Addendum 6 1.2: a mid-dark saturated lane (deep teal, matt) so ball effects read; the world stays bright.
		-- Was Wood { 240,204,150 / 230,188,132 }, Deck 248,222,176 (pale wood washed the effects out).
		Wood = { Color3.fromRGB(24, 82, 102), Color3.fromRGB(20, 72, 92) }, -- the two strip tones, alternating
		Deck = Color3.fromRGB(30, 96, 118),
		LaneMaterial = Enum.Material.Wood, -- matt (Reflectance 0)
		EdgeLine = { Color = Color3.fromRGB(255, 250, 238), Width = 0.6 }, -- bright lines down both outer edges
		Lights = 5, -- soft lights over the lane (across), each SurfaceLight at Brightness
		LightBrightness = 0.65,
		-- moved to ServerStorage.A5OldLanes at start: paths from <Folder>
		Hide = {
			{ "Lane1" }, { "Lane2" }, { "Lane3" }, { "Lane4" }, { "Lane5" }, { "Lane6" }, { "LaneLines" },
			{ "Design", "lanes", "lane_1" }, { "Design", "lanes", "lane_2" }, { "Design", "lanes", "lane_3" },
			{ "Design", "lanes", "lane_4" }, { "Design", "lanes", "lane_5" }, { "Design", "lanes", "lane_6" },
			{ "Design", "lanes", "divider_1_Node" }, { "Design", "lanes", "divider_2_Node" },
			{ "Design", "lanes", "divider_3_Node" }, { "Design", "lanes", "divider_4_Node" },
			{ "Design", "lanes", "divider_5_Node" }, { "Design", "lanes", "divider_1_gold_Node" },
			{ "Design", "lanes", "divider_2_gold_Node" }, { "Design", "lanes", "divider_3_gold_Node" },
			{ "Design", "lanes", "divider_4_gold_Node" }, { "Design", "lanes", "divider_5_gold_Node" },
			{ "Design", "lanes", "ball_return_1" }, { "Design", "lanes", "ball_return_2" },
			{ "Design", "lanes", "ball_return_3" },
		},
		Sign = { Title = "MEGA LANE", Sub = "EVERYONE BOWLS TOGETHER!" }, -- the big sign on the gantry
	},
	-- Daytime repaint of the night rooftop, on every screen (the place file keeps the night colours, so Enabled =
	-- false brings them back): old colour hex -> new colour for SkylineLanes parts; Neon parts in DayNeon colours
	-- (lit windows, floodlight heads) turn into plain glass/plastic; lights in DayLightsOff switch off.
	-- Polish v2 L2: the colours come from Zone1Palette (taken from the owner's zone 1 stalls: sky-blue steel, warm
	-- wood, cream, slate, gold) instead of one-off hex picks. Was: city sky blue 150,205,240 / sand 236,206,158 /
	-- coral 242,160,122 / mint 160,222,190 / cream 246,236,212, ground 150,178,120, gutters 70,120,190, helipad
	-- 96,104,120, pit 80,86,104, helicopter 40,80,150; roof floor 76707e, tower walls e4ddf0, glass b0d6f0 and the
	-- approach 968474 kept the place's own colours.
	DayColors = {}, -- (filled from Zone1Paint just below)
	Zone1Palette = {
		Sky = Color3.fromHex("4FB3EC"), -- the stalls' steel and canvas
		SkyDeep = Color3.fromHex("2C86C9"),
		SkyGlass = Color3.fromHex("A9DDF8"),
		Wood = Color3.fromHex("B8743E"),
		WoodLight = Color3.fromHex("D08F52"),
		Cream = Color3.fromHex("F7F3EA"),
		Sand = Color3.fromHex("D8C6AC"),
		Slate = Color3.fromHex("8A97A4"),
		SlateDark = Color3.fromHex("59646F"),
		Gold = Color3.fromHex("F5B82E"),
		-- the big surfaces, mixed from the ones above
		Concrete = Color3.fromHex("8F8B85"), -- the roof floor: warm mid concrete, so the teal lane and the stalls pop
		Approach = Color3.fromHex("A88A66"), -- the bowlers' approach: warm maple (lighter glared white in the sun)
		Stone = Color3.fromHex("ECE3D2"), -- tower walls and far blocks: cream stone (white would blow out in the sun)
		Brick = Color3.fromHex("C9855A"), -- far blocks: warm brick (between Wood and WoodLight)
		CitySky = Color3.fromHex("6FA9D6"), -- far blocks: the stalls' sky blue, a step darker so it isn't the sky
		Park = Color3.fromHex("8CC06A"), -- the ground far below
		Pit = Color3.fromHex("4A505C"),
	},
	-- old colour hex (place file) -> Zone1Palette name
	Zone1Paint = {
		["7a5aa8"] = "Stone", -- city blocks (the most of them)
		["5a3e8c"] = "Sand",
		["3f2f6e"] = "Brick",
		["6b4ba0"] = "CitySky",
		["8a64b0"] = "Cream",
		["1c1630"] = "Park", -- the ground far below
		["3b2f6b"] = "SlateDark", -- gutters
		["2e2a4a"] = "SlateDark", -- helipad deck
		["221a3d"] = "Pit",
		["090f30"] = "SkyDeep", -- helicopter body
		["76707e"] = "Concrete", -- the roof floor (was lilac grey)
		["e4ddf0"] = "Stone", -- the tower's walls (were lilac white)
		["b0d6f0"] = "SkyGlass", -- the tower's glass
		["968474"] = "Approach", -- the bowlers' approach (was khaki)
	},
	DayNeon = {
		["ffc65a"] = { Color = Color3.fromRGB(196, 228, 248), Material = Enum.Material.Glass }, -- lit city windows
		["bf9443"] = { Color = Color3.fromRGB(176, 214, 240), Material = Enum.Material.Glass }, -- tower windows
		["e0d6bc"] = { Color = Color3.fromRGB(235, 235, 230), Material = Enum.Material.SmoothPlastic }, -- floodlight heads
		["d8d8d8"] = { Color = Color3.fromRGB(230, 230, 230), Material = Enum.Material.SmoothPlastic },
	},
	DayLightsOff = { "FillLight", "HeliLight" }, -- the night fill lights over the lanes and the helipad lamp
	-- Polish v2 L4: the sell / shop pads dressed like each zone's stalls (CoreLoopService dressPad), one row per zone.
	-- The pad's colour (green = sell, blue = shop) stays as a Ring-studs-wide inlay round a Plate in the zone's
	-- material; Rim = the outer edge; Trim + Detail = small bits (Bolts / Planks / Moss / Notches). Colours are hex,
	-- materials Enum.Material names. Size and the server's stand check don't change. PadStyles = nil = plain circles.
	PadStyles = {
		{ Rim = { "59646F", "DiamondPlate" }, Plate = { "8A97A4", "DiamondPlate" }, Trim = { "F5B82E", "Metal" }, Detail = "Bolts" }, -- rooftop: painted metal floor plate, gold bolts
		{ Rim = { "D8B47A", "Fabric" }, Plate = { "B57A45", "WoodPlanks" }, Trim = { "7A4A28", "Wood" }, Detail = "Planks" }, -- boardwalk: round plank deck, rope rim
		{ Rim = { "8C8A80", "Slate" }, Plate = { "A9A699", "Slate" }, Trim = { "5E8C3A", "Grass" }, Detail = "Moss" }, -- jungle: carved stone disc with moss
		{ Rim = { "B0703E", "Sandstone" }, Plate = { "D9A066", "Sandstone" }, Trim = { "8F5530", "Sandstone" }, Detail = "Notches" }, -- canyon: sandstone tile, carved edge
	},
	ThrowRate = 0.33, -- the server never takes core throws faster than this (CooldownFloor is the real limit)
}

-- Polish v2 L2: zone 1's day paint by palette name (Config.CoreLoop.Zone1Paint -> Zone1Palette)
for oldHex, name in Config.CoreLoop.Zone1Paint do
	Config.CoreLoop.DayColors[oldHex] = Config.CoreLoop.Zone1Palette[name]
end

-- The throw (from the Throw Lab, approved 2026-10-18): hold to charge, let go in the gold.
-- Lab sizes were bigger than the alley's, so pin speeds and pin gravity are scaled down to match automatically.
Config.Throw = {
	-- Charging
	ChargeTime = 0.75, -- seconds for the bar to fill. Lower = faster bar = harder
	MeterSpeedPerRank = 0.05, -- the bar gets 5% faster for every rank above Rookie
	-- The server times every hold itself (the client only says "started holding" and "let go").
	-- Internet lag makes the two clocks differ a little, so the client's own hold time is trusted
	-- only within this many seconds of the server's. Bigger = kinder to laggy players, easier to cheat.
	HoldTolerance = 0.1,
	MaxHoldTime = 30, -- holds longer than this count as this long
	SweetSpotCenter = 0.86, -- where the gold zone sits before a lane's first throw (0 = empty, 1 = full)
	SweetSpotSize = 0.08, -- how wide the gold zone is (share of the bar). Narrow on purpose: a PERFECT should feel earned
	SweetSpotMax = 0.14, -- ball bonuses never make the gold zone wider than this
	-- After every throw the gold jumps to a new spot on the arc, so you can't just repeat the same timing
	GoldSpotLowest = 0.45, -- lowest spot the gold can jump to (centre of the zone)
	GoldSpotHighest = 0.92, -- highest
	GoldSpotMinJump = 0.15, -- it always moves at least this far from where it was
	-- Every strike in a row makes the gold this much narrower (0.05 = 5%), but never below GoldSmallestShare
	-- of its normal size (0.75 = 75%). Was 10% down to 0.04 of the bar until 2026-10-19 (too hard to streak).
	GoldShrinkPerStrike = 0.05,
	GoldSmallestShare = 0.75,
	-- The throw animation: the arm swings back as the meter fills
	ReleaseDelay = 0.1, -- seconds from letting go until the ball leaves the hand (the down-swing)
	DownSwingTime = 0.13,
	FollowThroughTime = 0.2,
	PoseHoldTime = 0.35, -- holds the follow-through pose this long, then relaxes
	PoseRelaxTime = 0.35,
	PoseExaggeration = 1.3, -- every bend of the throw animation is this much bigger (1 = the original pose)
	-- Polish v2 D2: a throw with no charge first (hold-to-throw, other players' throws) winds up for this long (weight
	-- back, arm back), then swings down and slides forward; your own ball leaves the hand at the release
	-- (ThrowPose.Lead). 0 = no wind-up (the ball goes the moment you throw).
	WindUpTime = 0.1,
	FollowOvershoot = 1.1, -- the follow-through swings this much past its pose and settles back (0 = stops dead)
	LuckyHop = { Height = 0.55, Time = 0.34 }, -- a LUCKY throw: the bowler hops (studs up, seconds); nil = no hop
	-- Low pose levels throw worse: level 1 is stiff, wobbly and flailing, and it gets cleaner every level. The pose
	-- level comes from your RANK LEVEL (RankStyle below; batch D1, owner 2026-10-29), not from Power Level.
	PoseCleanLevel = 9, -- from this pose level the throw is fully clean
	PoseWobble = 14, -- how far (degrees) a level 1 throw shakes; none at PoseCleanLevel
	PoseWobbleSpeed = 4, -- how fast the shaking is
	PoseFlairPerLevel = 0.06, -- each level above PoseCleanLevel swings this much bigger (level 12 = +18%)
	-- Batch D1 (owner 2026-10-29, Addendum 3 S0): your CURRENT rank level decides the throw animation and how fast the
	-- ball rolls (a rebirth resets it, on purpose). Each row starts at a rank level: Pose = the throw animation level
	-- (1 = scuffed .. PoseCleanLevel = clean .. 12 = biggest), Speed = ball speed x (1 = Config BallSpeed, never slower
	-- than before D1). Small steps every Rookie level (level 2 comes about a minute in), a bigger jump every Pro Tier.
	RankStyle = {
		{ Level = 1, Pose = 1, Speed = 1 }, -- Rookie
		{ Level = 2, Pose = 2, Speed = 1.02 },
		{ Level = 3, Pose = 3, Speed = 1.04 },
		{ Level = 4, Pose = 4, Speed = 1.06 },
		{ Level = 5, Pose = 5, Speed = 1.08 },
		{ Level = 6, Pose = 6, Speed = 1.1 },
		{ Level = 7, Pose = 7, Speed = 1.15 }, -- Amateur
		{ Level = 10, Pose = 8, Speed = 1.18 },
		{ Level = 13, Pose = 9, Speed = 1.22 }, -- Regular: fully clean
		{ Level = 19, Pose = 10, Speed = 1.26 }, -- tier 4
		{ Level = 31, Pose = 11, Speed = 1.31 }, -- tier 6
		{ Level = 43, Pose = 12, Speed = 1.36 }, -- tier 8 and up: the biggest pro throw
	},
	MeterStyle = "Side", -- "Side" = half circle standing up right of your bowler; "Arc" = lying flat
	HandBlendDistance = 10, -- the rolling ball drops from the hand onto the lane over this many studs
	ForgivenessScale = 6, -- a ball's Forgiveness 0.05 = gold zone 30% wider
	HitStop = 0.05, -- a PERFECT freezes the crash for this many seconds before the pins explode (makes it feel heavy)
	PerfectPowerBonus = 1.5, -- a PERFECT release is this much stronger than a full bar
	WeakestThrow = 0.35, -- strength of a quick tap (0 to 1)

	-- What gets knocked down. A PERFECT release is always a strike, and only a PERFECT can strike.
	StrikeChanceWithoutPerfect = 0, -- strike chance with a full bar outside the gold (0 = strikes only in the gold)
	-- also counts as PERFECT ("HOOK!"). Mythic Curve 0.6 = 6% of the bar on each side.
	FewestPinsKnocked = 3, -- fewest pins any throw knocks down
	GoodShare = 0.7, -- knocking down at least this share of the rack reads as a "Good" throw (7 of 10)

	-- The ball (studs per second at full strength). Higher = less waiting before the crash.
	BallSpeed = 80,

	-- Pin explosion (Throw Lab numbers)
	PinLaunchForce = 55, -- backwards and sideways
	PinLaunchUpward = 42, -- up into the air
	PinSpin = 30,
	PinTumble = 0.75, -- Polish v2 D2: share of the spin that tumbles the pin end over end along its flight (0 = random axis)
	-- Polish v2 D2: the puff where the ball meets the pins (core loop, your own throws), in each zone's ground colour
	-- (zone number -> colour). Size / Speed / Count grow up to x2 with the throw's strength; ClatterFrom = drawn pins
	-- from which a second, softer clatter plays as the pins land.
	ImpactDust = {
		Colors = {
			Color3.fromHex("B9B2A8"), -- rooftop concrete dust
			Color3.fromHex("E8CFA0"), -- boardwalk sand
			Color3.fromHex("CDEFF5"), -- jungle spray
			Color3.fromHex("E2A66C"), -- canyon sand
		},
		Size = 1.4,
		Speed = 9,
		Count = 7,
		ClatterFrom = 6,
	},
	PinSpreadTime = 0.05, -- seconds between the first and last pin taking off
	PinGravity = 90, -- pull on flying pins (normal is 196); characters keep normal gravity
	LabPinSpacing = 2.9, -- pin spacing in the Lab, used to scale the numbers above to this alley

	-- Power Levels 1-12 (bought with coins, see Config.Economy.PowerLevels): how the equipped ball looks,
	-- sounds and hits at each level. Every level adds something you can see on the very next throw.
	-- Size = rolling ball size (1 = normal; trimmed about 10% on 2026-10-18, owner: a tiny bit too big), Force = how hard pins fly, New = what the shop says this level adds
	Levels = {
		{ Size = 0.8, Force = 0.6, New = "" },
		{ Size = 0.95, Force = 0.8, New = "POWER TRAIL" },
		{ Size = 1.1, Force = 0.95, New = "SPARKS" },
		{ Size = 1.25, Force = 1.1, New = "BIGGER BALL" },
		{ Size = 1.4, Force = 1.3, New = "ON FIRE" },
		{ Size = 1.5, Force = 1.5, New = "HUGE TRAIL" },
		{ Size = 1.65, Force = 1.7, New = "MEGA CRASH" },
		{ Size = 1.8, Force = 1.9, New = "POWER AURA" },
		{ Size = 1.95, Force = 2.1, New = "CLEAN THROW" },
		{ Size = 2.15, Force = 2.3, New = "GIANT BALL" },
		{ Size = 2.35, Force = 2.5, New = "RAINBOW FIRE" },
		{ Size = 2.6, Force = 2.8, New = "MAXIMUM POWER" },
	},
	-- How loud the level effects are (owner 2026-10-18: "exaggerate them a bit more"). Bigger = stronger.
	LevelFx = {
		-- 2026-10-25 owner: ball light too bright (was range 8 + 2/level, brightness 1 + 0.45/level = 6.4 at level 12)
		GlowRange = 8, -- the ball's light: range in studs...
		GlowRangePerLevel = 1.5,
		GlowBrightness = 0.7, -- ...and brightness
		GlowBrightnessPerLevel = 0.2,
		SparkRate = 14, -- sparks per second at SparklesFromLevel (+ per level) (2026-10-26: was 35 + 25, too busy)
		SparkRatePerLevel = 8,
		SparkSize = 0.5, -- spark size in studs, plus this share of the ball
		FireSize = 1, -- flames, times the ball size (2026-10-26: was 1.5)
		AuraFill = 0.75, -- 0 = solid glow, 1 = no glow (was 0.45 before 2026-10-25, 0.6 before 2026-10-26)
		ReleaseBurst = 12, -- burst of the level's colour from the hand on release: sparks per level...
		ReleaseRingFromLevel = 4, -- ...plus a shockwave ring from this level
		LevelSoundDrop = 0.05, -- every level the ball sounds this much deeper...
		LevelSoundLoud = 0.08, -- ...and this much louder
	},
	PowerTrailFromLevel = 2, -- the ball's trail grows from this level (Config.BallVfx.TrailPerLevel; no separate streak since 2026-10-26)
	SparklesFromLevel = 3, -- sparks pour off the rolling ball
	FireFromLevel = 5, -- the ball is on fire
	MegaCrashFromLevel = 7, -- double shockwave, big flash, deep extra boom
	AuraFromLevel = 8, -- the ball glows with an outline in its own colour
	RainbowFromLevel = 11, -- rainbow flames and sparks
	CrashGrowthPerLevel = 0.25, -- each level makes the crash 25% bigger

	-- Camera
	CameraShakeStrength = 0.5,
	CameraShakeTime = 0.25,
	CameraPunch = 4, -- how far the camera jolts toward the pins on impact

	-- Strike slow motion
	SlowMotionStartsAfter = 0.12, -- full-speed explosion first, so the hit feels instant
	SlowMotionLength = 0.2, -- Addendum 2: at most 0.2 seconds, so the next throw comes quickly
	SlowMotionSpeed = 0.3,

	-- Number pops out of each pin (coins earned); better balls make them bigger (owner's design: SM 32, MD 52, CRIT 92)
	NumberPopSize = 22, -- 2026-10-22 owner: smaller so the pin numbers don't pile up (design was 32)
	NumberPopTime = 1.4, -- design: gone at 1.4 s
	NumberPopRise = 60, -- pixels it floats up (design 130; 2026-10-22 owner: less, so it stays out of the strike text)
	-- The "+480 COINS" payout pop (owner's design UI 1.4): fixed on the screen above the lane
	PayoutPopPosition = UDim2.fromScale(0.5, 0.56), -- under the result text and the XP line, above the throw button
	PayoutPopScale = 0.75, -- 2026-10-22 owner: smaller than the design so it doesn't overlap the strike text
	PayoutPopTime = 2.3, -- design: idle until 2.0 s, exit by 2.3 s
	-- Throw result text (owner's design UI 1.3): text sizes in pixels at 720 px screen height
	-- 2026-10-22 owner: all smaller so they don't overlap (design was Strike 92, Perfect 50, Overcooked 44, Pins 40)
	ResultSizes = { Strike = 62, Perfect = 36, Overcooked = 32, Pins = 28 },
	StreakGrowCap = 1.2, -- streak text never grows past this (was 1.35)

	-- Strike streak text on screen: "STRIKE!", then each Config.Streaks tier name the moment you reach it
	-- (DOUBLE! TURKEY! HAMBONE! WILD TURKEY! STREAK MASTER! PERFECT RUN!), "6 IN A ROW!" and so on in between
	SpecialStreaks = { 3, 5, 7, 10 }, -- extra-special celebration
	StreakGrowth = 0.15, -- each strike in a row celebrates 15% bigger...
	StreakGrowthStopsAt = 8, -- ...up to this many
	CelebrationTime = 0.8,

	-- Server waits this long after a roll before the lane takes another throw
	CooldownBuffer = 0.3,

	-- Overcharge: the greedy release. The top of the power bar is a red cap (the gold never goes there).
	-- Let go in the red and it's a gamble: either a huge OVERCHARGE strike that pays extra,
	-- or the ball overcooks into the gutter (0 pins, streak over). Safe gold or greedy red, every throw.
	Overcharge = {
		Enabled = true, -- false = no red cap, the bar works like before
		From = 0.94, -- the red cap starts here (0 = empty bar, 1 = full)
		SuccessChance = 0.5, -- chance a red release pays off
		CoinMultiplier = 2, -- an OVERCHARGE strike pays this many times a PERFECT
		PowerMultiplier = 1.5, -- and hits this much harder (pins fly further, bigger crash)
		GoldGap = 0.01, -- the gold zone always ends at least this far below the red cap
	},
}

-- What a player starts with the first time they join
Config.StartingData = {
	Coins = 0,
	Gems = 0,
	XP = 0,
	Rank = 1, -- index into Config.Ranks (1 = Rookie); raised by passing Rank Trials
	RankLevel = 1, -- current rank level (1-60); a rebirth puts it back to 1 (batch D1)
	BestLevel = 1, -- highest rank level ever reached: level-up gems, free crates and level rewards pay only above it (v32)
	BestRank = 1, -- highest rank tier ever passed: a tier won before comes back without a trial and without gems (v32)
	BestStreak = 0,
	EquippedBall = "Rookie",
	OwnedBalls = { Rookie = true }, -- set of ball Ids
	CratesSinceRare = 0, -- old shared pity counters (before v10), no longer used; kept so old saves stay valid
	CratesSinceEpic = 0,
	CratePity = {}, -- pity per crate (Config.Economy.CratePity): { ["Basic_Rare"] = pulls in a row without Rare+ }
	Polish = {}, -- Polish Points per ball from duplicates (Config.Economy.Polish): { Galaxy = 3 }
	CratesOpened = 0, -- crates opened ever (the first one is Config.Economy.FirstCrateMin or better)
	CratesBought = 0, -- crates bought with coins (not gift, free or daily crates); v11
	LifetimePins = 0, -- leaderboard: Most Pins
	WeeklyCoins = 0, -- leaderboard: coins earned from throws this week...
	WeeklyCoinsWeek = 0, -- ...and which week that was (see Calendar.Week)
	DailyDay = 0, -- last daily reward day claimed (1-7), 0 = never
	DailyLastClaim = 0, -- the day number (see Calendar.Day) it was claimed on
	CrateStrikes = 0, -- throws toward the next free crate (see Config.FreeCrates; was strikes before 2026-10-21)
	FreeCrates = 0, -- free crates waiting to be opened in the shop
	PlayTime = 0, -- total seconds played, for analytics ("bought ball tier 3 after 12 minutes")
	PowerLevel = 1, -- Power Level bought so far (Config.Economy.PowerLevels)
	SessionLog = {}, -- the last few play sessions (see Config.SessionLog), newest last
	Onboarding = 0, -- first 3 minutes (Config.Onboarding): 0 = first throw next, 1 = before the gift, 2 = gift given, 3 = done
	OnboardThrows = 0, -- throws counted toward the first-3-minutes moments
	Mascots = {}, -- mascots owned, by Id: { Pinny = 2 } (v13)
	EquippedMascots = {}, -- Ids following the player, one per slot (the same Id can fill two slots if owned twice)
	EggsHatched = 0, -- eggs hatched ever
	ZoneSeen = 1, -- highest zone whose "ZONE UNLOCKED" window was shown (v14)
	Potions = {}, -- potions waiting to be drunk, by Id: { CoinSmall = 2 } (Config.Potions; v15)
	Boosts = {}, -- seconds left on each drunk potion, by Id: { CoinSmall = 840 } (only ticks while playing; v15)
	FreeEggs = {}, -- free hatches waiting at the egg stand, by egg Id: { Alley = 1 } (Config.Playtime; v16)
	SpinDay = 0, -- the day number (see Calendar.Day) of the last free spin on the daily spin wheel (Config.Spin; v17)
	BossNextAt = 0, -- os.time() when the zone 4 helicopter can fly you to the boss again (Config.Boss; v18)
	Rebirths = 0, -- rebirths done (Config.Economy.Rebirth; v18)
	LastOnline = 0, -- os.time() when the player last left, for "while you were away" coins (Config.Away; v19)
	AwayRate = 0, -- coins per second earned from throws near the end of the last visit (Config.Away; v19)
	Purchases = {}, -- the last Robux purchase ids handed out, so one is never given twice (Config.Monetization; v20)
	StarterPack = 0, -- 1 = the one-time Starter Pack was bought (v20)
	StarterOffered = 0, -- 1 = the Starter Pack popup was shown (it only shows once; v20)
	RobuxBoost = 0, -- v21 only (the old adding COIN BOOST); v22 turns it into CoinBoostLevel and it stays 0
	CoinBoostLevel = 0, -- COIN BOOST ladder steps bought with Robux: coins x 2^this forever (Config.Monetization; v22)
	XpBoostLevel = 0, -- XP BOOST ladder steps: XP x 2^this forever (v22)
	VipGiftDay = 0, -- the day number (see Calendar.Day) the VIP daily gems were last given (v21)
	Cosmetics = {}, -- looks owned (Config.Cosmetics), by Id: { FireTrail = true } (v23)
	EquippedCosmetics = {}, -- the look worn per kind: { Trail = "FireTrail", LaneSkin = "CandyLane" } (v23)
	ZonesOpen = 1, -- highest zone open (zones open by rebirths, Config.Economy.Zones Rebirths; v24). Never goes down
	ZoneVisited = 1, -- highest zone stood in; the walk guide's gold beam leads to an open zone above it (v24)
	EquipBestHinted = 0, -- 1 = the pointing hand on EQUIP BEST was used (Polish P4, Config.EquipBestHint; v25)
	-- Profile panel (Polish P5, Config.Profile; v26): lifetime counters that had no save field yet, all start at 0
	TotalThrows = 0, -- lane throws ever (auto throws too; not boss throws)
	TotalStrikes = 0, -- strikes ever
	TotalPerfects = 0, -- PERFECT throws ever
	LifetimeCoins = 0, -- coins earned ever, from anything (never goes down: spending and rebirths don't touch it)
	BossWins = 0, -- Pin Titan fights won (with enough hits to get a reward)
	AchievementTiers = {}, -- achievement tiers claimed, by Config.Profile.Achievements Id: { Throws = 2 }
	Settings = "", -- SETTINGS window choices that differ from the start, "Vfx=0;Music=0.45" (Config.Settings; v27)
	PolishHinted = 0, -- 1 = a POLISH was bought with gems, so the Ball Book stops teaching it (Config.PolishHint; v28)
	-- Playtime gifts once a day (batch B4, Config.Playtime; v29)
	PlaytimeDay = 0, -- the day number (see Calendar.Day) the saved gift clock belongs to
	PlaytimeSeconds = 0, -- seconds played that day (the gift clock)
	PlaytimeGot = "", -- gifts claimed that day, by number: "1,2,4"
	EggPrompted = 0, -- 1 = the BUY YOUR FIRST PET EGG! popup was shown (Config.EggPrompt; v30)
	PetSlotsKept = 0, -- pet slots an old save had under the old rules (rank levels 15/30 + 1 rebirth); never fewer (v30)
	AutoDelete = {}, -- pets X'd on the egg odds boards: { Pinny = true }; hatched ones are not kept (Config.AutoDelete; v31)
	-- Addendum 4 core loop (Config.CoreLoop; v33)
	Bag = 0, -- pins waiting in the bag (coins before Addendum 6, same field); sold for Coins at the sell station
	BagLevel = 1, -- Config.CoreLoop.BagSizes step (bag capacity)
	BallStep = 1, -- Config.CoreLoop.Balls step: your BEST ball (pins per throw come from it) (v34)
	-- Addendum 6 2.2 (v37): balls / bags owned, one bit per step (step n = 2^(n-1); 1 = only the first). Skipped
	-- steps below your best have no bit. CoreLook = the ball step you throw for its look (0 = your best ball).
	CoreBallsOwned = 1,
	CoreBagsOwned = 1,
	CoreLook = 0,
	CoreZonesOpen = 1, -- Addendum 6 Stage 3: zones opened at the gates (1 = only zone 1; a rebirth sets it back to 1; v38)
	CoreZone = 1, -- the zone you were in last (you come back there; v38)
	PetSlotsBought = 0, -- pet equip slots bought with coins at the shop (Config.PetStats.SlotPrices; v35)
	ThrowSpeedLevel = 0, -- throw speed upgrades: each takes CooldownStep off the hold-to-throw cooldown
	CoreThrows = 0, -- core loop throws ever (first and 10th throw are logged once per player)
	CoreSells = 0, -- sells ever (the first is logged once per player)
	Tutorial = 0, -- Polish v2: tutorial steps done (Config.Tutorial; each pays once; v39)
	PetsFound = {}, -- Polish v2 U3: { [petId] = true } for every pet ever hatched or given (kept after fusing or deleting); egg boards black out the rest (v40)
	Pacing = {}, -- Addendum 5 step E: time to each ball / bag / egg / rebirth and income per run (Config.Pacing; v36)
}

-- Saving (DataStore)
Config.Data = {
	-- "PlayerData_A4": every account starts from zero for the Addendum 4 loop (owner 2026-11-01). The old saves are
	-- still in "PlayerData" (set it back to bring them back).
	StoreName = "PlayerData_A4",
	SchemaVersion = 40, -- v40 PetsFound (Polish v2 U3; filled from the pets each save owns). v39 Tutorial (Polish v2 tutorial steps done; old saves that already sold or bought count as done, no rewards). v38 CoreZonesOpen + CoreZone (Addendum 6 Stage 3 zones; start at 1, nothing to upgrade). v37 CoreBallsOwned + CoreBagsOwned + CoreLook (Addendum 6 2.2 buy any ball / bag; old saves own every step up to their best, look = best). v36 Pacing (Addendum 5 E pacing record; starts empty, nothing to upgrade). v35 PetSlotsBought (Addendum 5 B1 coin pet slots; starts at 0, nothing to upgrade). v34 BallStep (Addendum 4 Stage 2 ball ladder; starts at 1, nothing to upgrade). v33 Bag, BagLevel, ThrowSpeedLevel, CoreThrows, CoreSells (Addendum 4 core loop; start at 0/1, every old field kept, nothing to upgrade). v32 BestLevel + BestRank (batch D1 rebirth resets levels; old saves start at their RankLevel / Rank). v31 AutoDelete (batch C3 X'd pets on the egg odds boards; starts empty, nothing to upgrade or delete). v30 PetSlotsKept + EggPrompted (batch C1 pet slots by rebirths; old saves keep the slots the old rank-level rule gave them; EggPrompted starts at 0). v29 PlaytimeDay/PlaytimeSeconds/PlaytimeGot (batch B4 playtime gifts once a day; start at 0 / empty = a fresh day, nothing to upgrade). v28 PolishHinted (batch B3; starts at 0, nothing to upgrade). v27 Settings (SETTINGS window switches; starts empty = all on, nothing to upgrade). v26 TotalThrows/TotalStrikes/TotalPerfects/LifetimeCoins/BossWins/AchievementTiers (Polish P5 profile; start at 0 / empty, nothing to upgrade). v25 EquipBestHinted (Polish P4; starts at 0, nothing to upgrade). v24 ZonesOpen + ZoneVisited (zones open by rebirths, owner 2026-10-27; old saves keep the zones they reached). v23 Cosmetics + EquippedCosmetics (step 12b). v22 CoinBoostLevel + XpBoostLevel (doubling ladders, owner). v21 RobuxBoost + VipGiftDay (step 12a rework). v20 Purchases + StarterPack + StarterOffered (Addendum 2 step 12a). v19 LastOnline + AwayRate (Addendum 2 step 11a). v18 BossNextAt + Rebirths (Phase X). v2 added balls and crates, v3 daily reward and leaderboard stats, v4 saved Rank (Rank Trials), v5 free crates, v6 PlayTime, v7 SessionLog, v8 PowerLevel, v9 Onboarding, v10 5 crates (CratePity, Polish, CratesOpened), v11 CratesBought, v12 RankLevel (60 levels), v13 Mascots/EquippedMascots/EggsHatched, v14 ZoneSeen, v15 Potions/Boosts, v16 FreeEggs, v17 SpinDay. Bump when the save format changes, and add an upgrade step in SaveStore
	AutosaveInterval = 60, -- seconds between automatic saves
	MaxRetries = 5, -- attempts per load/save before giving up
	RetryDelay = 2, -- seconds; waits longer after each failed attempt
	LockTimeout = 300, -- a session lock older than this belongs to a crashed server and can be taken
	LockWaitTries = 6, -- if another server still holds the lock, wait and retry this many times...
	LockWaitDelay = 5, -- ...this many seconds apart, then take over
}

-- The first 3 minutes (Addendum 2 section 6): one scripted path for brand new players.
-- 1. The first throw is an assisted PERFECT strike (the whole arc turns gold).
-- 2. A big "BUY" callout points at the Power Level button the moment Level 2 is affordable.
-- 3. The first crate bought with coins (FirstCrateGoal) costs FirstCratePrice, so it's affordable inside the first
--    minute, and gives exactly a FirstBoughtRarity ball. Only that one purchase; crate odds and prices stay the same otherwise.
-- 4. After GiftAfterThrows throws (about 1 minute): a free gift crate, opened right there (GiftRarity nil = normal odds),
--    with an EQUIP button.
-- 5. LegendsAfterThrows throws later: the camera swings to a locked ball in the lobby showcase (the chase).
-- The "next goal" bar on the HUD always shows the closest goal (next Power Level, the gift, the next free crate,
-- and the FirstCrateGoal crate until the player has bought a crate; when that crate is the goal and affordable,
-- a beam leads to its kiosk station).
Config.Onboarding = {
	Enabled = not Config.CoreLoop.Enabled, -- the first-3-minutes story is off while the Addendum 4 core loop is on
	GiftAfterThrows = 20, -- about 1:00-1:15, after the first bought crate (owner 2026-10-29, final changes batch B2: was 65, about 4:00)
	GiftCrateId = "Basic", -- the gift opens as this crate
	GiftRarity = nil, -- nil = the gift crate rolls normal odds (owner 2026-10-21: only the first crate is guaranteed)
	FirstCrateGoal = "Basic", -- this crate is a "next goal" until the first crate bought with coins (CratesBought)
	FirstCratePrice = 1000, -- the first FirstCrateGoal crate a player buys costs this (normal price after), ~0:45
	FirstBoughtRarity = "Uncommon", -- the first crate a player buys with coins always gives this rarity
	LegendsAfterThrows = 3, -- throws after the gift: the camera shows a locked showcase ball, then the daily unlocks
	LegendsPanTime = 3.5, -- seconds the camera looks at the locked ball
	-- Rebirth teaser (batch B2): once a session, this many seconds after joining, a player who has never rebirthed
	-- (and is past the steps above) sees "REBIRTH = NEW ZONE + PETS!" with what it still needs, and a TAP arrow
	-- under the REBIRTH button for RebirthTeaserArrow seconds. Skipped when the rebirth is already ready (that has
	-- its own REBIRTH IS READY! popup). nil = off.
	RebirthTeaserAt = 150,
	RebirthTeaserArrow = 8,
	-- Studio testing: every play test starts as a brand new player and nothing is saved (your real save is untouched).
	-- Never affects the live game. Set to false to test with your saved progress.
	StudioNewPlayer = false,
	-- Studio testing with your saved progress (StudioNewPlayer = false): every built zone is open (rank level raised
	-- to the last built zone's level, its popups marked seen, first-3-minutes done) for the test only. Nothing from
	-- the test is saved: your real save is handed back exactly as it was loaded. Never affects the live game.
	-- It also owns every ball, pet (one each) and cosmetic, and tops coins/gems up to these (owner 2026-10-27).
	StudioUnlockAll = true,
	StudioUnlockCoins = 1e15,
	StudioUnlockGems = 100000,
}

-- Session log: one line per play session (join, leave, throws, crates, level), printed in Output
-- when the player leaves and saved with the player (only the newest Keep sessions).
-- Also counts PERFECT throws (the assisted first throw is counted apart), and for a brand new player's first
-- session writes a timeline of every reward moment in the first First5Seconds seconds.
-- Read it after a playtest: the Output window prints it at 5:00 and when you leave; in Studio the
-- TEST: REPORT button (under the Power Level button) prints it any time.
Config.SessionLog = {
	Keep = 10,
	Print = true,
	First5Seconds = 300,
}

-- Addendum 5 step E: the pacing record (server Modules/Pacing). Per run (start or rebirth to the next rebirth): when
-- each ball, bag, pet slot and egg was first bought (minutes of play into the run), the rebirth, and the income
-- (coins sold a minute over the last IncomeWindow seconds) at the top, before the rebirth, 5 min into the next run
-- and when it got back to the old income. Printed in Output when the player leaves and by TEST > PACING (Studio),
-- saved with the player (newest KeepRuns runs), and sent to Analytics (event "Pacing", funnel "Run").
Config.Pacing = {
	Enabled = true,
	Print = true,
	KeepRuns = 8,
	IncomeWindow = 180,
}

-- Requests a player can't send faster than this (seconds). Extra ones are ignored by the server.
Config.RateLimits = {
	Throw = 2, -- the fastest real throw cycle measured 2026-10-18 is 2.2s (lane free again after letting go)
	ThrowHold = 0.1, -- "started holding" messages
	EquipBall = 0.25,
	OpenCrate = 1,
	ClaimDaily = 1,
	StartTrial = 1,
	BuyPowerLevel = 0.5,
	BuyPolish = 0.3,
	HatchEgg = 1,
	EquipMascot = 0.15,
	UsePotion = 0.3,
	ClaimPlaytime = 0.5,
	SpinWheel = 1,
	RideElevator = 2,
	RideHelicopter = 2,
	Rebirth = 3,
	StoreBuy = 1,
	BuyCosmetic = 0.5,
	EquipCosmetic = 0.2,
	OfferAsk = 3,
	ClaimAchievement = 0.4, -- Profile panel CLAIM (Polish P5)
	SetSetting = 0.15, -- SETTINGS window switch
	AutoDelete = 0.15, -- tapping a pet on an egg odds board to X it out / back in (batch C3)
}

-- Gems on/off switch. Addendum 1 keeps gems (earned only, a gem sink comes later); set Enabled = false to hide them.
-- While off: no gem drops, the HUD hides the gem counter, and Gem Hunter pays bonus coins instead.
-- Saved gem balances are kept untouched either way, so switching loses nothing.
Config.Gems = {
	Enabled = true,
	HunterCoinBonus = 1, -- while gems are off, a Gem Hunter hit adds this share of the throw's coins (1 = +100%)
}

-- Strike streaks: the highest row you have reached sets the coin multiplier (Multiplier) and the XP multiplier
-- (XpMultiplier). A non-strike resets to 0.
-- Color tints the streak display and the player's alley lights.
Config.Streaks = {
	{ Streak = 1, Multiplier = 1.0, XpMultiplier = 1.0, Name = "", Color = Color3.fromRGB(255, 255, 255) },
	{ Streak = 2, Multiplier = 1.5, XpMultiplier = 1.5, Name = "DOUBLE", Color = Color3.fromRGB(60, 230, 255) },
	{ Streak = 3, Multiplier = 2.0, XpMultiplier = 2.0, Name = "TURKEY", Color = Color3.fromRGB(120, 255, 120) },
	{ Streak = 4, Multiplier = 2.5, XpMultiplier = 2.5, Name = "HAMBONE", Color = Color3.fromRGB(255, 200, 40) },
	{ Streak = 5, Multiplier = 3.0, XpMultiplier = 3.0, Name = "WILD TURKEY", Color = Color3.fromRGB(255, 130, 30) },
	{ Streak = 7, Multiplier = 4.0, XpMultiplier = 4.0, Name = "STREAK MASTER", Color = Color3.fromRGB(255, 60, 210) },
	{ Streak = 10, Multiplier = 5.0, XpMultiplier = 5.0, Name = "PERFECT RUN", Color = Color3.fromRGB(255, 240, 90) },
}

-- FEVER MODE (final changes batch D4, item 16 "spice", owner picked 2026-10-29): StreakNeeded strikes in a row by
-- hand = Seconds of x CoinMultiplier coins and faster throws (FeverService; the multiplier card lists FEVER while it
-- runs). It starts again at 10, 15 ... in a row if it has run out by then. Auto Bowl throws never start or use it.
Config.Fever = {
	Enabled = true,
	StreakNeeded = 5,
	Seconds = 15,
	CoinMultiplier = 3, -- on top of every other multiplier (streak, PERFECT x2 ...)
	StrikeAddsSeconds = 1, -- each strike during fever adds this, never above Seconds left; a miss doesn't end it
	-- Faster throws: the lane resets quicker (Config.Lane.PinResetDelay x ResetScale, strike slow motion kept) and
	-- the server allows a throw every ThrowRateLimit seconds (Config.RateLimits.Throw outside fever)
	ResetScale = 0.5,
	CooldownBuffer = 0.1, -- instead of Config.Throw.CooldownBuffer
	ThrowRateLimit = 1.4,
	MusicSpeed = 1.15, -- the zone music plays this much faster (MusicController)
	-- Looks (FeverController; kept warm and soft, never blinding)
	Color = Color3.fromRGB(255, 122, 26),
	EdgeGlow = 0.62, -- transparency of the screen-edge glow at its strongest (1 = none); pulses up to EdgeGlowPulse
	EdgeGlowPulse = 0.78,
	EdgeGlowSize = 0.16, -- share of the screen height each edge glow reaches in
	EndWarning = 3, -- the bar blinks in its last seconds
	LaneFlameRate = 6, -- soft flame wisps per second off each lane light strip
	BallFlameRate = 30, -- flame wisps per second behind the ball
}

-- LANE EVENTS (final changes batch D5; LaneEventService, looks in PinRack + EventController): about every Interval
-- seconds of bowling by hand, your lane's next rack is a short event (one throw), picked by Weight:
--   GoldenRack = every pin is gold; a strike on it pays x StrikeMultiplier coins
--   Split      = only pins 7 and 10 stand (the 7-10 split); both down = StrikeValues x what a PERFECT strike pays
--                you right now, plus Gems[zone] gems. A PERFECT always clears it; other throws have a small chance.
--                The split throw never breaks or adds to your strike streak.
--   GemPin     = one pin (from Pins) is a gem pin; knock it down for Gems[zone] gems
-- No events during the first minutes (Config.Onboarding, the bowling clock starts when it ends), FEVER MODE, a rank
-- trial, the boss fight or while AUTO BOWL is on; a waiting event comes on the first rack after. Auto throws never
-- move the clock or win an event. Studio: TEST panel GOLDEN RACK / 7-10 SPLIT / GEM PIN.
Config.LaneEvents = {
	Enabled = true,
	Interval = 120, -- seconds of bowling between events...
	Jitter = 20, -- ...give or take this many
	MaxGap = 10, -- a pause longer than this between two throws only counts this many seconds (idle time doesn't count)
	Weights = { GoldenRack = 40, Split = 30, GemPin = 30 },
	GoldenRack = {
		StrikeMultiplier = 5, -- replaces FEVER's x3 if both are on (never x15)
		PinLight = 0.9, -- each gold pin's glow (the single Golden Pin uses 3): soft, ten of them
		PinSparkles = 3, -- sparkles per second per pin
	},
	Split = {
		Pins = { 7, 10 }, -- the back corners
		StrikeValues = 12, -- the prize = this many PERFECT strikes' coins (with every multiplier you have now)
		Gems = { 2, 3, 3, 4 }, -- by zone
		BothChance = 0.12, -- a throw that isn't a PERFECT knocks both down this often...
		OneChance = 0.5, -- ...and one of them this often (else neither)
	},
	GemPin = {
		Pins = { 2, 3, 4, 6, 7, 8, 9, 10 }, -- never the head pin or the middle pin (those fall on every throw)
		Gems = { 3, 4, 4, 5 }, -- by zone
	},
	Looks = {
		GoldenRack = { Name = "GOLDEN RACK", Sub = "STRIKE IT FOR x%d COINS", Paint = "Gold", Icon = "GoldenPin" },
		Split = { Name = "7-10 SPLIT", Sub = "KNOCK DOWN BOTH FOR A BIG PRIZE", Paint = "Pink", Icon = "Hud:Pin" },
		GemPin = { Name = "GEM PIN", Sub = "HIT THE GEM PIN FOR +%d GEMS", Paint = "Cyan", Icon = "Gem" },
	},
	GemColor = Color3.fromRGB(70, 230, 255),
	GemLight = 1.2,
}

-- Pro Tiers. Each tier holds 6 of the 60 rank levels (Config.Economy.Ranks: levels 1-6 Rookie, 7-12 Amateur ...
-- 55-60 Hall of Famer). Levels inside a tier come straight from XP; a tier's first level needs its Rank Trial
-- (see Config.Trials) once the XP is there. Coin multiplier is permanent; gems are a one-time tier reward.
-- A tier's XP is the XP of its first level (Progression.TierXP), so it follows the level curve.
-- (Before step 7a the tiers had their own XP: 0, 300, 600, 2000, 6000, 18000, 50000, 140000, 400000, 1000000.)
Config.Ranks = {
	{ Name = "Rookie", Multiplier = 1.0, Gems = 0, Color = Color3.fromRGB(200, 200, 210) },
	{ Name = "Amateur", Multiplier = 1.25, Gems = 5, Color = Color3.fromRGB(120, 230, 120) },
	{ Name = "Regular", Multiplier = 1.5, Gems = 10, Color = Color3.fromRGB(80, 200, 255) },
	{ Name = "Club", Multiplier = 2.0, Gems = 15, Color = Color3.fromRGB(60, 120, 255) },
	{ Name = "Semi-Pro", Multiplier = 2.5, Gems = 20, Color = Color3.fromRGB(170, 90, 255) },
	{ Name = "Pro", Multiplier = 3.0, Gems = 30, Color = Color3.fromRGB(255, 60, 210) },
	{ Name = "Elite", Multiplier = 4.0, Gems = 40, Color = Color3.fromRGB(255, 70, 70) },
	{ Name = "Master", Multiplier = 5.0, Gems = 50, Color = Color3.fromRGB(255, 150, 30) },
	{ Name = "Legend", Multiplier = 7.0, Gems = 75, Color = Color3.fromRGB(255, 220, 60) },
	{ Name = "Hall of Famer", Multiplier = 10.0, Gems = 100, Color = Color3.fromRGB(255, 255, 255) },
}

-- Rank Trials: the test you pass to reach a rank once your XP bar is full.
-- Types: what a trial counts. Counts = which throws count ("Strike" includes Perfect Strikes, "Perfect" only those).
-- InARow = they must come one after another (a miss starts the count again).
-- Text: %d = Goal, then Throws.
-- Ranks: one trial per rank you are trying to reach. A rank with no row here is given straight away.
Config.Trials = {
	Cooldown = 60, -- seconds to wait after failing before you can try again (a rank row's own Cooldown wins)
	Types = {
		Strikes = { Counts = "Strike", InARow = false, Text = "Get %d strikes in %d throws" },
		Streak = { Counts = "Strike", InARow = true, Text = "Get %d strikes in a row within %d throws" },
		Perfects = { Counts = "Perfect", InARow = false, Text = "Hit %d Perfect Strikes in %d throws" },
		PerfectRow = { Counts = "Perfect", InARow = true, Text = "Hit %d Perfect Strikes in a row within %d throws" },
	},
	Ranks = {
		-- The first two ranks have no cooldown, and Amateur needs only 1 strike, so the first rank-up is reliable
		Amateur = { Type = "Strikes", Goal = 1, Throws = 6, Cooldown = 0 },
		Regular = { Type = "Strikes", Goal = 3, Throws = 8, Cooldown = 0 },
		Club = { Type = "Streak", Goal = 2, Throws = 8 },
		["Semi-Pro"] = { Type = "Strikes", Goal = 4, Throws = 8 },
		Pro = { Type = "Streak", Goal = 3, Throws = 10 },
		Elite = { Type = "Perfects", Goal = 2, Throws = 10 },
		Master = { Type = "Streak", Goal = 4, Throws = 10 },
		Legend = { Type = "PerfectRow", Goal = 2, Throws = 12 },
		["Hall of Famer"] = { Type = "Streak", Goal = 6, Throws = 12 },
	},
}

-- Rewards per throw:
-- coins = pins * BaseCoinsPerPin * (every multiplier: ball, rank, streak, future boosts), plus tier bonus
Config.Rewards = {
	BaseCoinsPerPin = 10,
	StrikeBonus = 0.5, -- +50% coins on a Strike
	PerfectStrikeBonus = 1, -- +100% coins on a Perfect Strike (Addendum 2: crit x2), instead of the Strike bonus

	-- XP = (pins * XpPerPin, or the Strike / Perfect Strike amount) * every XP multiplier (streak, future boosts)
	XpPerPin = 1.5, -- was 1 before 9.5c
	StrikeXp = 15, -- was 10
	PerfectStrikeXp = 30, -- was 20

	PerfectGemChance = 0.1, -- chance a Perfect Strike also drops gems
	PerfectGemAmount = 1,
}

-- Camera that follows your own ball down the lane
Config.Camera = {
	FollowDistance = 10, -- studs behind the ball
	FollowHeight = 5,
	LookAhead = 20,
	StopBeforePins = 16, -- camera stops this far before the head pin
	Smoothness = 8, -- higher = snappier
}

-- Effects ("juice"). Only changes how things look and sound, never rewards.
Config.Juice = {
	SlowMoScale = 0.25, -- strike slow-motion speed (1 = normal speed)
	SlowMoTime = 0.3, -- seconds of slow-motion when your ball hits the pins for a strike
	SlowMoFov = 58, -- the camera zooms in a little during slow-motion (normal is 70)

	ShakePerPin = 0.05, -- camera shake strength for each pin knocked
	ShakeStrikeBonus = 0.35, -- extra shake on a strike
	ShakeDecay = 3, -- how fast the shake dies down (higher = shorter)
	-- Polish v2 D6: shakes ring out along one direction (mostly up-down, a little sideways) like a real knock, instead
	-- of random jitter: ShakeFreq swings per second, ShakeJitter = the share of leftover jitter on top
	ShakeFreq = 11,
	ShakeJitter = 0.25,
	-- Polish v2 Q1: seconds before the same sound (in the same place) can start again, so fast taps and per-frame
	-- count-ups never stack one sound into a loud blast (pin hits on different pins still all play)
	SameSoundGap = 0.05,

	ConfettiAmount = 60, -- confetti pieces in the alley on a strike
	PerfectFireworks = 3, -- firework bursts on a Perfect Strike

	CoinIconsMin = 3, -- coins that fly to the counter after a throw...
	CoinIconsMax = 14,
	CoinsPerIcon = 30, -- ...one icon per this many coins earned, between Min and Max
	SellIconsPerTen = 2, -- (Addendum 5 F) a core-loop sell flies Min + this many icons per x10 coins (100 = 7, 1M = 15 -> Max)
	CoinPitchStep = 0.05, -- each coin's "ding" is this much higher than the last
	-- Polish v2 D2 (AN2 item 5): flying coins / gems home on a curve, bowed out to alternate sides by this share of
	-- the trip (at most FlyBowMax pixels), so a sell sprays out and swoops in. 0 = straight lines.
	FlyBow = 0.25,
	FlyBowMax = 140,

	StreakSparkleRate = 4, -- sparkles per second on your alley's light strips, per streak tier from Turkey up

	ResultSlamScale = 1.5, -- STRIKE! text starts this much bigger and shrinks into place (kept small so the pins stay visible)
	ResultStrikeTime = 1.2, -- seconds a STRIKE! stays up (other results: ResultTime)
	ResultTime = 0.9,
}

-- Screen layout
-- Polish v2 D1: Modules/Motion, one motion feel for every screen. Springs: Freq = how fast (Hz), Damp = 1 no bounce,
-- lower = more bounce. One-shots: Time (s) + easing.
Config.Motion = {
	Presets = {
		Snap = { Freq = 8, Damp = 1 }, -- buttons going down
		Pop = { Freq = 3.4, Damp = 0.5 }, -- small rewards, buttons coming back up, red dots
		Window = { Freq = 3.2, Damp = 0.62 }, -- windows opening
		Slam = { Freq = 2.6, Damp = 0.38 }, -- big moments
		Shut = { Time = 0.14, Style = Enum.EasingStyle.Quad, Dir = Enum.EasingDirection.In }, -- closing
		Float = { Time = 1.2, Style = Enum.EasingStyle.Sine, Dir = Enum.EasingDirection.InOut }, -- idle loops
		Drift = { Time = 0.35, Style = Enum.EasingStyle.Sine, Dir = Enum.EasingDirection.InOut }, -- soft fades
	},
	Stagger = 0.05, -- seconds between items in a list / reward row
	PressMemory = 0.5, -- a window opening this soon after a button press grows out of that button
	FromButtonScale = 0.12, -- window size at the button (it grows to 1 on the way out)
	InPlaceScale = 0.85, -- window opened with no button (a stall pad): pops in place from this size
	CloseScale = 0.85, -- window closed with no button: shrinks in place to this size
	FloatSway = 0.25, -- idle bob: sideways sway as a share of the bob height (a curve, not a line)
	ButtonDown = 0.92, -- button press scale
	ButtonKick = 1.6, -- spring kick on release (the little overshoot past full size)
	ToastGap = 8, -- px between stacked toasts
	-- Polish v2 D3: any teleport (shop, sell, gates, rebirth) hides its cut behind a navy band that sweeps off the
	-- screen. A jump is the character moving more than Jump studs in one frame.
	Wipe = { Jump = 40, Time = 0.38, Tilt = 10, Color = Color3.fromRGB(23, 52, 92), Edge = Color3.fromRGB(16, 23, 46) },
}

Config.Ui = {
	CompactHeight = 500, -- screens shorter than this (phones held sideways) use the compact phone layout
	-- Addendum 4 Stage 3d: the sunny look (Modules/SunKit palette + 2 fonts, no gloss, light panels with dark text).
	-- false = the old night HUD Kit colours and fonts come back.
	Sunny = true,
	-- UI overhaul V2 (UI_OVERHAUL_PLAN.md, owner's 'Strike Legends UI.html' B1/B2): the new HUD (navy tile buttons,
	-- coin/gem pills, PINS DOWN, NEXT GOAL card, round potion timers, bag bar + SELL, green THROW) in the design's
	-- spots. false = the sunny HUD comes back as it was.
	HudV2 = true,
	-- UI overhaul V3 (owner's 'Strike Legends Screens.html' 1a/1b): the SHOP window's BALLS and BAGS tabs in the new
	-- look (left tab column, zone switcher, card grid, BUY BEST, buy reveal). REBIRTH and PASSES still open the old
	-- window until V4. false = the old shop window for every tab.
	ShopV2 = true,
	-- How many steps past your NEXT ball / bag show their real look and name; further ones are "???" silhouettes
	-- (the design: 3). 0 = only the NEXT one shows; skipped and owned ones always show.
	ShopV2Ahead = 3,
	-- UI overhaul V5 (owner's 'Strike Legends Pets UI.html' D1-D3): the PETS window in the new look (PETS / ITEMS
	-- tabs, BEST / RARITY / NEW sort, slot strip with total boosts + EQUIP BEST, pet cards, potion cards).
	-- false = the old pets panel comes back.
	PetsV2 = true,
	-- UI overhaul V6 (owner's 'Strike Legends Pets UI.html' D4-D6): the egg odds board over every egg stand (price,
	-- odds, auto-delete X, HATCH / AUTO / x3; sizes in Config.EggBoard) and the FUSE PETS window in the new look.
	-- false = the old odds bubbles + price line and the old PET FUSION window come back.
	EggV2 = true,
	-- UI overhaul V7 (owner's 'Strike Legends Pets UI.html' hatch frames F1-F9, T1, M1-M5): every hatch plays the new
	-- screen sequence (egg pops in, 3 shakes, cracks, light leak, flash, pet + card with NEW! / x2, OK + AUTO; triple =
	-- rarest in the middle; Mythic = dark screen + lightning, 4.2 s). false = the old hatch on the 3D stand comes back.
	HatchV2 = true,
	-- UI overhaul V8 (owner's 'Strike Legends - Daily Reward.html' 1A/1B): the DAILY REWARDS calendar in the new look
	-- (6 day tiles + big day 7, CLAIM -> blue countdown, reward flies to the HUD). false = the old calendar comes back.
	DailyV2 = true,
	-- Polish v2 U1 (owner 2026-11-03): no SHOP (balls + bags) button on the HUD; the shop opens at the BALLS & BAGS
	-- stall and the NEXT GOAL card takes you there. The grid closes up and the PASSES button (opens the STORE on its
	-- passes) takes the last grid spot. true = the SHOP button comes back.
	ShopButton = false,
	-- Polish v2 U2: the STORE window in the V2 look (navy, SlKit paints, Fredoka One, flat cards); false = the cream
	-- Store Kit look
	StoreV2 = true,
	-- Polish v2 U4: the last windows built with the older kits (GIFTS, PROFILE, SETTINGS, TELEPORT, potions, the
	-- spin card, toasts...) take the V2 look of the SHOP and STORE: navy window and cards, white text, SlKit paints.
	-- false = the cream sunny windows come back.
	WindowsV2 = true,
	HatchV2Quick = 2, -- AUTO HATCH (and after Config.MascotFx.Hatch.AutoSkipAfter hatches) plays it this many times faster; Mythic never
	-- Tuck while bowling (owner 2026-10-28: on phones the HUD hid the lane): from the moment you start a throw, these
	-- HUD pieces slide off the nearest screen edge; IdleSeconds after your last throw they slide back (Time = slide
	-- seconds). Coins, the level bar, POWER, the streak and the goal bar always stay, except POWER tucks too once it
	-- shows MAX POWER! (key "PowerMax"; nothing left to buy). Touch = phones + tablets, Computer = mouse + keyboard.
	-- Never during the first 3 minutes.
	Tuck = {
		Enabled = true,
		Touch = true,
		Computer = false,
		IdleSeconds = 4,
		Time = 0.25,
		Keys = { "Boosts", "Income", "Gems", "Balls", "Pets", "Store", "Daily", "Profile", "Gifts", "Settings", "Teleport", "Rebirth", "Potions", "More", "PowerMax" },
	},
	-- Phone MORE menu (owner 2026-10-28: the phone HUD was still too busy). On phones (short screens) the buttons in
	-- Keys leave the HUD and fold into one MORE button in the top-right corner; tapping it slides them out in a column
	-- under it (in this order; hidden ones skip their place), and the lane event + goal bar step aside while it is open.
	-- A red dot on MORE = one of them has news. HideZeroStreak = the streak panel only shows from 1 strike on phones.
	-- Computers keep every button where it is.
	-- The gold xN multiplier badge right of the coins (owner 2026-10-28: removed on computer + phone). The breakdown
	-- card still opens from PROFILE.
	MultiplierBadge = true, -- (Addendum 6 1.1: back on: the HUD shows the total coin multiplier, tap = breakdown)
	PhoneMenu = {
		Enabled = false, -- (V2 HUD: phones show every button, as designed; true = fold them into MORE again)
		Keys = { "Daily", "Gifts", "Teleport", "Profile", "Settings" },
		Aside = { "Modifier", "Goal" },
		Gap = 52, -- px between buttons in the open column
		HideZeroStreak = true,
	},
	CountTime = 0.6, -- seconds for a HUD number to tick up to its new value
	RankUpShowTime = 4, -- seconds before the rank-up screen closes by itself
	RankUpConfetti = 40, -- confetti pieces on the rank-up screen
	-- Roblox's own player list sits in the top-right corner on computers, where the GIFTS button is now (owner 2026-10-22).
	-- The game shows no stats in it (no leaderstats), so it is hidden; set false to bring it back.
	HidePlayerList = true,
}

-- Big numbers (Phase X Part 8A). Every number on screen goes through Shared.Modules.Currency.Format and all coin
-- math through Currency (add, spend, boosts, compare, save/load), so the number type can change later.
Config.Numbers = {
	-- 1K = 1,000, 1M = 1,000,000 ... each suffix is 1,000 times the one before. Add more at the end for bigger numbers.
	Suffixes = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad", "Qid" },
	ShortFrom = 1000, -- smaller numbers show whole, with commas ("950")
	Decimals = 2, -- "12.34M"; numbers of 100 or more in a unit get one less ("123.4M"); trailing zeros are trimmed
	Currencies = { "Coins", "Gems", "WeeklyCoins", "LifetimeCoins", "Bag" }, -- saved values that are money: they go through Currency
	-- Precision guard: plain Roblox numbers stop counting whole coins exactly at about 9 quadrillion (9e15).
	-- Any coin value at WarnAt or above logs a warning (once per place in the code), long before that limit.
	SafeMax = 9e15,
	WarnAt = 1e15,
}

-- Sound effects: every sound slot and its asset ID lives in Shared.AssetSlots
-- (tools/EconomySim requires a parentless copy of this module, hence the fallback)
local shared = script.Parent or game:GetService("ReplicatedStorage"):WaitForChild("Shared")
Config.Sounds = require(shared:WaitForChild("AssetSlots") :: any).Sounds

-- Ball traits: special powers that change how a ball plays. Adding a trait = adding a row here
-- (and, for a brand-new kind of power, a few lines where the server applies it).
-- A ball's strength number means something different per trait, see Value below.
-- Text: full description (%s = the strength, already scaled by Display). Short: the tag on inventory tiles.
-- Popup: the text that flashes on screen when the trait kicks in (PopupColor if set, else Color).
-- Colours come from the design system. The effect itself lives in Config.TraitFx (client TraitFx module).
-- Sound: a name from Config.Sounds, played at Pitch.
Config.Traits = {
	{
		Id = "Curve", -- Value: how much wider the PERFECT window gets (0.25 = 25% wider), shown as magenta edges on the gold
		Name = "Curve",
		Text = "PERFECT window %s%% wider (the magenta edges count as PERFECT), and every throw hooks",
		Short = "CURVE %s%%",
		Display = 100,
		Popup = "HOOK!",
		Color = Color3.fromHex("FF2BD6"), -- magenta
		Sound = "Throw",
		Pitch = 1.5,
		HookSide = 1, -- 1 = aims right of centre hook back in, -1 = left
	},
	{
		Id = "Blast", -- Value: chance (0-1) per throw of a blast: ExtraPins more on a miss, a huge explosion on a strike
		Name = "Blast",
		Text = "%s%% chance per throw to BLAST: an extra pin, or a giant explosion on strikes",
		Short = "BLAST %s%%",
		Display = 100,
		ExtraPins = 1,
		Popup = "BLAST!",
		Color = Color3.fromHex("FFE600"), -- yellow
		Sound = "StrikeCrash",
		Pitch = 0.7,
	},
	{
		Id = "StreakSaver", -- Value: seconds between saves
		Name = "Streak Saver",
		Text = "A miss won't break your streak (once every %ss)",
		Short = "SAVER %ss",
		Display = 1,
		Popup = "STREAK SAVED!",
		Color = Color3.fromHex("19E3FF"), -- cyan (the shield bubble)
		PopupColor = Color3.fromHex("7CFF3A"), -- lime
		Sound = "StreakUp",
		Pitch = 1.3,
		MinStreak = 2, -- only saves streaks of at least this many strikes
	},
	{
		Id = "Lucky", -- Value: extra Golden Pin chance (1 = twice as likely)
		Name = "Lucky",
		Text = "+%s%% Golden Pin chance",
		Short = "LUCKY +%s%%",
		Display = 100,
		Popup = "LUCKY!",
		Color = Color3.fromHex("7CFF3A"), -- lime
		Sound = "Coin",
		Pitch = 1.2,
	},
	{
		Id = "GemHunter", -- Value: extra chance of a gem on a Perfect Strike (0.1 = +10%)
		Name = "Gem Hunter",
		Text = "+%s%% gem chance on Perfect Strikes",
		Short = "GEMS +%s%%",
		Display = 100,
		Popup = "+%d GEM", -- %d = gems paid
		-- Used while Config.Gems.Enabled is false: the same chance pays bonus coins
		NoGemsName = "Coin Hunter",
		NoGemsText = "+%s%% chance of bonus coins on Perfect Strikes",
		NoGemsShort = "COINS +%s%%",
		NoGemsPopup = "+%s COINS", -- %s = coins paid
		Color = Color3.fromHex("19E3C0"), -- gem
		Sound = "Gem",
		Pitch = 1,
	},
	{
		Id = "Heavy", -- Value: how much wider the gold zone on the charge bar gets (0.5 = 50% wider). Every strike hits HEAVY.
		Name = "Heavy",
		Text = "Gold zone %s%% wider, and every strike lands a HEAVY HIT",
		Short = "HEAVY +%s%%",
		Display = 100,
		Popup = "HEAVY HIT!",
		Color = Color3.fromHex("FF3B5C"), -- red
		Sound = "PinHit",
		Pitch = 0.6,
	},
}

-- Trait trigger effects, from the owner's "Trait Effects" handoff sheet (times in seconds).
-- Sizes on the sheet are drawn next to a 26px ball, so here they're in studs (ball = 1.8 studs).
local INK = Color3.fromHex("06060F")
Config.TraitFx = {
	Ink = INK,
	PixelsPerStud = 40, -- detail of the flat effects drawn on the lane (rings, cracks)
	Brightness = 2.5, -- how hard the flat effects glow
	FloorLift = 0.04, -- flat effects sit this far above the lane so they don't flicker
	-- Popup text for every trait: Luckiest Guy, ink drop shadow, a glow in the trait colour
	Popup = {
		TextSize = 30, -- pixels on a 1080p screen, scaled with the screen (was 40 before 2026-10-22)
		MinTextSize = 20,
		Shadow = 4, -- ink drop shadow, pixels down
		GlowTransparency = 0.6,
		PopFrom = 0.6, -- pops in from this size (ease-pop overshoots to ~1.08)
		PopTime = 0.36,
		HoldTime = 0.9,
		ExitTime = 0.14,
		Rise = 12, -- pixels it rises while fading out
		StackGap = 48, -- each extra popup sits this far above the last
		Margin = 64, -- keep out of the screen corners...
		BottomMargin = 180, -- ...and the thumb area at the bottom
	},
	Curve = {
		Core = Color3.fromHex("FFFFFF"),
		Glow = Color3.fromHex("FF2BD6"),
		Tail = Color3.fromHex("B3109A"),
		Width = 1.25, -- glow ribbon width at the ball (tapers to 0 at the tail)
		CoreWidth = 0.28,
		Lifetime = 0.6, -- each piece of ribbon fades over this
		MaxLength = 1 / 3, -- share of the lane
		FadeOut = 0.3, -- whole trail fades after the ball hits the pins
		Brightness = 3,
	},
	Blast = {
		Flash = Color3.fromHex("FFFFFF"),
		Ring1 = Color3.fromHex("FFE600"),
		Ring2 = Color3.fromHex("FF2BD6"),
		FlashSize = 2.2, -- 1.2x the ball
		FlashTime = 0.12,
		RingRadius = 3, -- in pin spacings
		RingTime = 0.5,
		Ring2Delay = 0.08,
		StrokeStart = 0.42, -- ring line thickness in studs, thinning as it grows
		StrokeEnd = 0.07,
		Shake = 0.35,
	},
	StreakSaver = {
		Bubble = Color3.fromHex("19E3FF"),
		Rim = Color3.fromHex("0A8FB8"),
		Size = 1.4, -- bubble width vs the streak counter
		Tint = 0.8, -- how clear the middle of the bubble is
		PopFrom = 0.4,
		PopTime = 0.36,
		JoltAt = 0.24, -- the counter gets knocked sideways near the end of the pop
		Jolt = 6, -- pixels
		JoltTime = 0.12,
		WobbleTime = 0.2, -- 0.94 -> 1.03 -> 1
		HoldTime = 0.6,
		ExitTime = 0.24, -- grows to ExitScale and fades, bursting into sparkles
		ExitScale = 1.25,
		Sparkles = 10,
	},
	Lucky = {
		Clover = Color3.fromHex("7CFF3A"),
		Shade = Color3.fromHex("3DAA10"),
		Sparkles = { Color3.fromHex("FFE600"), Color3.fromHex("FFFFFF") },
		CloverSize = 64, -- pixels
		Ledge = 4, -- ink ledge under the clover, pixels
		Tilt = 15, -- degrees it settles at (spins in from -30)
		PopTime = 0.36,
		HoldTime = 0.6,
		ExitTime = 0.14,
		SparkleCount = 6,
		SparkleSize = { 16, 24 }, -- pixels
		SparkleTime = 0.45,
		SparkleStagger = 0.14,
		RingScale = 1.2, -- sparkle ring vs the rack's width
	},
	GemHunter = {
		Sparkle = Color3.fromHex("19E3FF"),
		Gem = Color3.fromHex("19E3C0"),
		Interval = 0.06, -- one sparkle this often behind the ball
		Jitter = 0.55, -- studs either side
		Size = 0.7, -- studs, +-SizeRange
		SizeRange = 0.27,
		Lifetime = 0.5,
		GemSize = 48, -- payout gem, pixels
		PopTime = 0.36,
		FlyTime = 0.24,
		Bump = 1.15, -- the HUD gem counter bumps to this
	},
	Heavy = {
		Ink = INK,
		Glow = Color3.fromHex("FF3B5C"),
		Deep = Color3.fromHex("B3132F"),
		Dust = Color3.fromHex("A9A3D6"),
		FlashTime = 0.1,
		Shake = 0.55,
		Branches = { 5, 7 },
		Length = { 4.2, 8.3 }, -- studs per crack branch
		InkWidth = 0.21,
		GlowWidth = 0.62,
		DrawTime = 0.2,
		HoldTime = 1.5,
		FadeTime = 0.4, -- glow cools to Deep and fades
		DustTime = 0.5,
		DustGrow = 1.6,
	},
}

-- Golden Pin: sometimes one pin in your rack is golden. Knock it down for a big bonus on that throw.
-- The Lucky ball trait raises the chance: Chance * (1 + Lucky strength).
Config.GoldenPin = {
	Chance = 1 / 15, -- chance for each new rack
	MaxChance = 0.5, -- never more than this, however lucky
	CoinMultiplier = 5, -- that throw's coins are multiplied by this
	GemChance = 0.3, -- chance of gems too...
	GemAmount = 2,
	CrateChance = 0, -- ...and chance of a free crate (owner 2026-10-21: no random free crates; see Config.FreeCrates)
	Color = Color3.fromRGB(255, 200, 40),
}

-- Free crates: one every ThrowsPerCrate throws (owner 2026-10-21: rare, so they feel valuable; no random ones).
-- They wait at Rizzo's cart / the Crate Shop until the player opens them.
-- The count is saved in the old CrateStrikes field (now counts throws, not strikes).
Config.FreeCrates = {
	CrateId = "Basic", -- which crate a free crate is
	ThrowsPerCrate = 250, -- about 12-15 minutes of play
}

-- The "almost there" bar above the throw meter: always shows the nearest reward.
Config.AlmostThere = {
	PulseAt = 0.8, -- the bar pulses once you are this far (80%) toward the reward
}

-- First egg prompt (final changes item 6, batch C1; EggPromptController): the first time you have Coins while standing
-- in zone Zone (open by then), a big popup says to buy your first pet egg, and a gold beam + GO HERE! marker lead to
-- that zone's egg stand until you hatch an egg (or leave the zone, or the session ends). The popup shows once ever
-- (save EggPrompted, v30); players who already hatched an egg never see it. The YOU CAN NOW AFFORD note skips that
-- egg while this applies.
Config.EggPrompt = {
	Enabled = true,
	Coins = 50000, -- owner 2026-10-29: at 50K coins (the Neon Egg's price)
	Zone = 2, -- eggs open with Neon Lanes; you must be standing in it (Config.Zones.Gated Area)
	Egg = "Alley", -- the stand the beam leads to (Config.EggStands; "Alley" = the Neon Egg)
	Title = "BUY YOUR FIRST PET EGG!",
	Sub = "FOLLOW THE GOLD BEAM TO THE EGG STAND",
	Marker = "GO HERE!", -- the word over the stand
	MarkerHeight = 14, -- studs above the egg (over its odds bubbles, Config.EggOdds Height)
	Delay = 1.5, -- seconds after the coins arrive before the popup (lets the payout pop finish)
}

-- "YOU CAN NOW AFFORD X" (final changes item 8, batch B2): a note fades in at the top centre and fades out when your
-- coins first reach something: a crate or egg of a zone you have open, the next Power Level, the next rebirth.
-- One note per thing a session; what you could already afford when you joined gets none. Skipped where a bigger
-- moment already says it (the first crate's 93% OFF, BUY LV 2, the first REBIRTH IS READY!). AffordController.
Config.AffordNote = {
	Enabled = true,
	Seconds = 2.6, -- how long a note stays (plus 0.35 s fading in and 0.6 s fading out)
	Gap = 3, -- seconds between two notes (more wait in a queue)
}

-- Lane modifiers: every Interval seconds the server picks a new one for the whole alley.
-- Adding a modifier = adding a row. Each row can use any of these (leave out what it doesn't need):
--   CoinMultiplier  coins on every throw are multiplied by this
--   StrikeGemChance / StrikeGemAmount  every strike has this chance of gems
--   SweetSway / SwayPeriod  the gold zone slides down the charge bar by up to this much and back, every SwayPeriod seconds
--   PinScale / SweetBonus  bigger pins (looks), and the gold zone gets this share wider (0.5 = 50%)
-- Weight: how often it is picked compared to the others.
Config.LaneModifiers = {
	Interval = 90,
	List = {
		{
			Id = "DoubleCoins",
			Name = "DOUBLE COINS",
			Text = "Every throw pays x2 coins!",
			Color = Color3.fromRGB(255, 200, 40),
			Weight = 1,
			CoinMultiplier = 2,
		},
		{
			Id = "MovingPins",
			Name = "MOVING GOLD",
			Text = "The gold zone slides! Let go when the bar meets it",
			Color = Color3.fromRGB(60, 230, 255),
			Weight = 1,
			SweetSway = 0.25,
			SwayPeriod = 3,
		},
		{
			Id = "BonusGems",
			Name = "BONUS GEMS",
			Text = "Every strike has a 20% chance of a gem!",
			Color = Color3.fromRGB(255, 90, 200),
			Weight = 1,
			StrikeGemChance = 0.2,
			StrikeGemAmount = 1,
			NeedsGems = true, -- left out of the rotation while Config.Gems.Enabled is false
		},
		{
			Id = "GiantPins",
			Name = "GIANT PINS",
			Text = "Huge pins are easier to hit, but pay x0.6 coins",
			Color = Color3.fromRGB(120, 255, 120),
			Weight = 1,
			PinScale = 1.4,
			SweetBonus = 0.5,
			CoinMultiplier = 0.6,
		},
	},
}

-- Display cases (Phase X Part 7): one data-driven case set per zone. Each set shows every ball that drops in its zone
-- (Config.Balls Zone, not Retired) on its Slots (parts under Workspace, ordered by their Order attribute, best ball
-- first) and its egg's pets on its Shelf. Not owned = dark silhouette, no glow; owned = lit up.
-- Owner 2026-10-29: no pet shelves in any zone (Shelf left out; the shelf parts are in ServerStorage.PetShelves_Backup).
-- A case = three layers: Base structure (Themes: the zone's look, colours + materials), rarity Accent (Styles
-- Accent: bands, padlock, sign border) and rarity FX (Styles: rings, halo, dots, beam, aura, motes). Styles are
-- shared by every zone and keyed by rarity, so a new zone or a new rarity only needs a Themes or Styles row.
-- Legendary and Mythic also change the structure a little (gold posts and diamonds on the roof: Posts, Gems).
-- Zone 3 and 4 themes are PLACEHOLDERS (the zone 2 base recoloured) until their hero case designs arrive.
Config.Showcase = {
	Sets = {
		{
			Zone = 2,
			Slots = { "Showcase", "Slots" },
			Egg = "Alley",
			Theme = "Neon",
		},
		{
			Zone = 3,
			Slots = { "MainStreetLanes", "Showcase", "Slots" },
			Egg = "Arcade",
			Theme = "MainStreet",
		},
		{
			Zone = 4,
			Slots = { "SkylineLanes", "Showcase", "Slots" },
			Egg = "Skyline",
			Theme = "Rooftop", -- 2026-11-03 (was "Skyline"): the roof is zone 1, the owner's SL_Z1_DisplayCase
			Ladder = true, -- core loop on: shows the 10 shop balls (Config.CoreLoop.Balls), owned once bought
		},
	},
	-- Base structure colours per zone (Navy = the case body, NavyTop = roof, BlueCap = base top, Pedestal = the
	-- ball's stand, SignBg = the sign, CaseLight = the light inside). Materials: optional, per colour name.
	-- Design: the owner's 3D case (ReplicatedStorage.ShowcaseModels.<Design>_<Rarity>, else <Design>) replaces the
	-- built case; the colours above then only paint the sign and finger holes. Bands: its parts that glow
	-- ("Glow" = Neon in the design's colour, "Accent" = Neon in the rarity's accent colour).
	Themes = {
		Neon = { -- the owner's display_case design
			Ink = Color3.fromRGB(14, 13, 26),
			Navy = Color3.fromRGB(26, 28, 82),
			NavyTop = Color3.fromRGB(30, 34, 118),
			BlueCap = Color3.fromRGB(58, 48, 176),
			Pedestal = Color3.fromRGB(24, 24, 66),
			Glass = Color3.fromRGB(191, 232, 255),
			SignBg = Color3.fromRGB(22, 20, 62),
			SignTop = Color3.fromRGB(58, 48, 128),
			CaseLight = Color3.fromRGB(190, 205, 255),
		},
		MainStreet = { -- the owner's ballcase_mainstreet designs (one per rarity)
			Design = "MainStreet",
			Bands = { rarity_band = "Glow" },
			Ink = Color3.fromRGB(34, 22, 14),
			Navy = Color3.fromRGB(110, 70, 40),
			NavyTop = Color3.fromRGB(84, 52, 30),
			BlueCap = Color3.fromRGB(196, 198, 206),
			Pedestal = Color3.fromRGB(150, 152, 160),
			Glass = Color3.fromRGB(255, 240, 220),
			SignBg = Color3.fromRGB(46, 30, 20),
			SignTop = Color3.fromRGB(120, 80, 46),
			CaseLight = Color3.fromRGB(255, 220, 170),
			Materials = {
				Navy = Enum.Material.Wood,
				NavyTop = Enum.Material.Wood,
				BlueCap = Enum.Material.Metal,
				Pedestal = Enum.Material.Metal,
			},
		},
		-- 2026-11-03: the owner's zone 1 case (SL_Z1_DisplayCase_Common, x4/3 to the old 5.6-stud case): one design for
		-- every rarity; its gem + glow disc glow in the rarity's colour, its trims take that colour (Tint = no Neon)
		Rooftop = {
			Design = "Rooftop",
			Bands = {
				crest_gem = "Accent",
				glow_disc = "Accent",
				trim_band_low = "Tint",
				trim_band_top = "Tint",
				cap_trim = "Tint",
				post_glow_0 = "Tint",
				post_glow_1 = "Tint",
				post_glow_2 = "Tint",
				post_glow_3 = "Tint",
			},
			Ink = Color3.fromRGB(46, 36, 30),
			Navy = Color3.fromRGB(247, 243, 234),
			NavyTop = Color3.fromRGB(79, 179, 236),
			BlueCap = Color3.fromRGB(79, 179, 236),
			Pedestal = Color3.fromRGB(79, 179, 236),
			Glass = Color3.fromRGB(216, 241, 255),
			SignBg = Color3.fromRGB(44, 134, 201),
			SignTop = Color3.fromRGB(245, 184, 46),
			CaseLight = Color3.fromRGB(255, 244, 220),
		},
		Skyline = { -- the owner's skyline_ball_case design (one for every rarity, bands in the rarity colour)
			Design = "Skyline",
			Bands = { band_common = "Accent", pedestal_glow = "Accent" },
			Ink = Color3.fromRGB(40, 50, 84),
			Navy = Color3.fromRGB(232, 240, 255),
			NavyTop = Color3.fromRGB(205, 222, 250),
			BlueCap = Color3.fromRGB(120, 182, 255),
			Pedestal = Color3.fromRGB(196, 212, 240),
			Glass = Color3.fromRGB(220, 240, 255),
			SignBg = Color3.fromRGB(34, 46, 90),
			SignTop = Color3.fromRGB(90, 140, 220),
			CaseLight = Color3.fromRGB(235, 242, 255),
		},
	},
	SparkleRate = 4, -- trait sparkles per second, per trait
	AnimateDistance = 110, -- only animate while your camera is this close (saves phone battery)

	-- Every case uses the owner's display case design (navy case, glass, pedestal, sign).
	Case = {
		CaseScale = 4.5, -- studs per unit of the display_case design (4.5 = 5.6 studs wide, 11 tall)
		SpinSpeed = 0.35, -- ball turns per second
		BobHeight = 0.25, -- studs the ball floats up and down (it never dips into its pedestal)
		RingSpeed = 0.4, -- turns per second for the rings around the ball
		RingRadius = 0.38, -- ring size, in case design units (the glass is 0.47 from the middle)
		RingWidth = 0.14, -- studs
		GemSpinSpeed = 0.25, -- turns per second for the diamond on top
		MoteSpeed = 0.12, -- turns per second for the specks circling the case
		BeamHeight = 9, -- studs above the case where the light beam starts
		GlowTexture = "rbxassetid://123280301429602", -- soft round glow dot (sl_glow_dot.png)
	},

	-- Rarity accent + FX layers, from the owner's renders (shared by every zone). Leave a line out to turn that effect off.
	-- A new rarity tier needs a row here (missing rows fall back to Common).
	-- Accent: glowing bands, padlock, sign border. Posts: "Gold" or "Black". Gems: diamonds on top (colour).
	-- Beam: light from above (colour). Light: how bright the case lights are (1 = normal, lower = moodier).
	-- Rings: rings orbiting the ball. Halo: soft glow sphere around the ball. InnerGlow: light behind the ball.
	-- Dots: floating glow dots { colours, per second, size, spread in case units }. Motes: specks circling the case.
	-- Aura: a faint glow around the whole case (colour). Shade: darkens the whole case (1 = normal).
	Styles = {
		Common = { Accent = Color3.fromRGB(225, 228, 240), Posts = "Black" },
		Uncommon = { Accent = Color3.fromRGB(120, 235, 165), Posts = "Black" },
		Rare = { Accent = Color3.fromRGB(105, 175, 255), Posts = "Black" },
		Epic = {
			Accent = Color3.fromRGB(170, 100, 255),
			Posts = "Black",
			Rings = 1,
			Halo = true,
			InnerGlow = Color3.fromRGB(170, 90, 255),
			Dots = { Colors = { Color3.fromRGB(210, 160, 255) }, Rate = 3, Size = 0.15, Spread = 0.8 },
		},
		Legendary = {
			Accent = Color3.fromRGB(255, 222, 140),
			Posts = "Gold",
			Gems = Color3.fromRGB(255, 180, 50),
			Beam = Color3.fromRGB(255, 170, 80),
			Light = 0.8,
			Rings = 2,
			Halo = true,
			InnerGlow = Color3.fromRGB(255, 170, 60),
			Dots = { Colors = { Color3.fromRGB(255, 200, 90) }, Rate = 8, Size = 0.2, Spread = 2.2 },
			Aura = Color3.fromRGB(255, 180, 60),
		},
		Mythic = {
			Accent = Color3.fromRGB(235, 240, 255),
			Posts = "Gold",
			Gems = Color3.fromRGB(235, 240, 255),
			Beam = Color3.fromRGB(190, 205, 255),
			Light = 0.4, -- more shadowy than the others (owner's request)
			Shade = 0.7, -- darker case and bands too
			Rings = 3,
			RingColors = { Color3.fromRGB(235, 240, 255), Color3.fromRGB(70, 230, 255), Color3.fromRGB(255, 70, 190) },
			Halo = true,
			InnerGlow = Color3.fromRGB(150, 120, 255),
			Dots = {
				Colors = { Color3.fromRGB(70, 230, 255), Color3.fromRGB(255, 70, 190) },
				Rate = 9,
				Size = 0.4,
				Spread = 1.8,
			},
			Motes = 16,
			Aura = Color3.fromRGB(255, 50, 120),
			SignGradient = true, -- pink-to-cyan sign border and name, like the render
		},
	},
}

-- Your equipped ball, shown on your character so everyone can see it
Config.BallFx = {
	HeldSize = 1.1, -- the ball in your right hand (studs)
	TrailLifetime = 0.35, -- the ball's trail behind you while you move
	AuraFromRarity = "Rare", -- this rarity and better also get a sparkle aura...
	AuraRatePerRarity = 3, -- ...with this many sparkles per second for every rarity step above Uncommon
}

-- Ball effects (trail, sparkles, orbit rings, glow) copied from the owner's ball renders and videos.
-- Played on the lane ball, the ball in your hand and the Vault cases (BallFx module on the client).
-- Every size is in ball widths (1 = the ball's diameter), so one look fits every place the ball shows up.
--   Trails:    comet streaks behind a rolling ball. Colors run from the ball back to the tail.
--              Glow (0-1): how additive the body is; lower keeps strong colours from washing out to white.
--              BodyTexture: an image name whose own colours replace the body's (Supernova's rainbow).
--              Each row is drawn in the layers of TrailLayers below.
--   Particles: Image, Colors, Rate (per second), Size, Life, Speed, Rise (pull upward),
--              Radius (spawn on a shell this far out), Twinkle (grow then shrink), Spin (degrees/second)
--   Rings:     thin glowing orbit rings. Tilt = { x, z } degrees, Spin = turns per second around the ball
--   Disk:      a flat glowing disk around the ball. Spin in degrees per second
--   Pieces:    the ball's own model pieces that float around it without rolling (ReplicatedStorage.BallFxPieces.<Id>,
--              built in Studio from the owner's files). { PieceName = degrees per second it turns round the up axis }
--   Halos:     camera-facing glows around the ball. Ground: glowing rings on the floor under the ball
--   Badge:     the trait icon floating above Rare balls. Light: the glow the ball throws around it
-- A ball without a row gets a simple trail in its Trail colour.
local WHITE = Color3.fromRGB(255, 255, 255)
Config.BallVfx = {
	Dim = 0.8, -- every ball effect's glow (lights, trails, sparkles) is this bright; lower = dimmer (owner 2026-10-22: a tad too bright)
	LightDim = 0.6, -- the ball's own lights on top of Dim (owner 2026-10-25: light from the ball too bright)
	HeldRate = 0.5, -- the ball in your hand uses this share of the sparkles (no trail, floor rings or badge)
	Images = {
		Ring = "rbxassetid://132592068787018",
		Disk = "rbxassetid://108350014126813",
		Star = "rbxassetid://77287225484408",
		Diamond = "rbxassetid://113877677543813",
		Bolt = "rbxassetid://95198117224211",
		Flame = "rbxassetid://92245452670752",
		Dot = "rbxassetid://123280301429602",
		Shield = "rbxassetid://124964835477907",
		Spiral = "rbxassetid://135987951766702",
		Clover = "rbxassetid://78517109940877",
		Burst = "rbxassetid://71546142790002",
		TrailSoft = "rbxassetid://109547705047240", -- soft falloff across the width (SL_Trail_Soft)
		TrailCore = "rbxassetid://135350987657237", -- tight bright line (SL_Trail_Core)
		TrailWisp = "rbxassetid://124462490268355", -- flowing vapour strands, tiles along the trail (SL_Trail_Wisp)
		TrailRainbow = "rbxassetid://109513255032556", -- rainbow bands across the width + vapour (SL_Trail_Rainbow)
		-- Trail style bits (assets/trail_fx, made by gen_trail_fx.py, 2026-10-26)
		Snowflake = "rbxassetid://135281416700469",
		Bubble = "rbxassetid://96411811936869",
		Smoke = "rbxassetid://82362520183746",
		Ember = "rbxassetid://127817510408135",
		FlameTongue = "rbxassetid://76542934270567",
		Goo = "rbxassetid://88920115975171",
		Coin = "rbxassetid://96789932966178", -- already gold: use white Colors so it keeps its own
	},
	-- Every trail row is drawn as these layers so it reads as real light: a soft glow, a wispy body that
	-- spreads out and thins as it ages, and a short hot core in the row's colours (lightened).
	-- Width/Lifetime multiply the row's. Fade = extra see-through on top of the row's Transparency.
	-- Spread = width at the ball -> width at the tail. Emission = how additive (1 = pure glow); the body
	-- uses the row's Glow if set. Repeat = ball widths per repeat of a tiling texture (it stays put in the
	-- world as the ball rolls on, like vapour left behind). Rows with their own Texture (Bolt) stay one layer.
	-- Motion: Twist = turns per second the ribbon spirals around the ball's path (+/- = direction, Phase = its
	-- starting angle), Wobble = how far it sways (ball widths), Shimmer = how much its brightness flickers.
	-- FromRarity = the layer only shows on balls of this rarity and up (1 Common .. 6 Mythic), so better balls
	-- get a visibly richer trail. Only a ball's first trail row gets every layer; extra rows add just the core.
	-- 2026-10-26 owner: trails too bright, too square, too many at once (was 5 layers on every ball, emission
	-- up to 0.8, plus a flat power streak and the cosmetic streak on top). Now one trail, tiered by rarity.
	TrailLayers = {
		{
			Texture = "TrailSoft",
			Width = 1.4,
			Lifetime = 1.1,
			Fade = 0.85,
			Spread = { 0.9, 1.2 },
			Emission = 0.45,
			Wobble = 0.08,
		},
		{
			Texture = "TrailWisp",
			Body = true, -- a row's BodyTexture replaces this layer's texture, and its Glow its Emission
			Width = 1,
			Lifetime = 1,
			Fade = 0.3,
			Spread = { 0.8, 1.2 },
			Emission = 0.35,
			Repeat = 2.5,
			Wobble = 0.05,
		},
		{
			Texture = "TrailCore",
			Core = true,
			Width = 0.25,
			Lifetime = 0.35,
			Fade = 0.35,
			Spread = { 1, 0.1 },
			Emission = 0.4,
			Lighten = 0.1,
		},
		-- Epic and up: a streamer spirals around the path
		{
			Texture = "TrailWisp",
			Body = true,
			FromRarity = 4,
			Width = 0.7,
			Lifetime = 0.9,
			Fade = 0.4,
			Spread = { 0.7, 1.2 },
			Emission = 0.45,
			Repeat = 3,
			Twist = 2.5,
		},
		-- Legendary and up: a second streamer the other way round
		{
			Texture = "TrailWisp",
			Body = true,
			FromRarity = 5,
			Width = 0.7,
			Lifetime = 0.9,
			Fade = 0.4,
			Spread = { 0.7, 1.2 },
			Emission = 0.45,
			Repeat = 3,
			Twist = -2,
			Phase = 90,
		},
	},
	-- How big a ball's trail is, by its rarity (1 Common .. 6 Mythic): Width and Lifetime multiply the trail row's,
	-- Bright multiplies its glow. Common is a short thin streak; Mythic a long, wide, full one.
	TrailTiers = {
		{ Width = 0.65, Lifetime = 0.6, Bright = 0.7 },
		{ Width = 0.75, Lifetime = 0.75, Bright = 0.8 },
		{ Width = 0.85, Lifetime = 0.9, Bright = 0.9 },
		{ Width = 1, Lifetime = 1.15, Bright = 1 },
		{ Width = 1.15, Lifetime = 1.45, Bright = 1.05 },
		{ Width = 1.3, Lifetime = 1.8, Bright = 1.1 },
	},
	CosmeticTrailTier = 4, -- a worn cosmetic trail (Config.Cosmetics) is drawn at least this rich (4 = Epic)
	-- Power Level grows the trail a little (the ball itself already grows each level, and the trail with it):
	-- every level from Config.Throw.PowerTrailFromLevel adds these shares of width and length
	TrailPerLevel = { Width = 0.02, Lifetime = 0.05 },
	-- Soft puffs in the trail's colours that peel off behind the ball, drift up, grow, turn and fade.
	-- Size = ball widths at birth -> at death (times the row's Width). Rise = upward pull. Spin = degrees/second
	-- Only Legendary and Mythic balls (FromRarity) leave them.
	TrailWisps = {
		Image = "Dot",
		FromRarity = 5,
		Rate = 18,
		Size = { 0.4, 1.4 },
		Life = { 0.5, 0.9 },
		Speed = { 0.3, 1 },
		Rise = 0.8,
		Transparency = 0.55,
		Spin = 40,
		Emission = 0.4,
	},
	-- Trail styles (2026-10-26 owner: trails must look like their name and get cooler with rarity).
	-- A style adds real things the ball leaves behind on top of its trail ribbons: flames and smoke, snowflakes
	-- and a frozen lane, bubbles and dripping goo, stars and nebula clouds, coins, sparks and arcs.
	--   Bits:   particles left hanging in the world behind the ball. Image, Colors (nil = the trail's own colours),
	--           Rate (per second at Legendary power), Size = { birth, biggest, death } in ball widths,
	--           Life, Speed, Rise (pull up; minus = falls), Drag, Spin, Twinkle (blinks), Emission (0-1 glow),
	--           Transparency (at its most solid), Radius (spawn shell), FromRarity (1 Common .. 6 Mythic),
	--           Bright (glow strength, default 1), Upright (no random turn: flames point up).
	--   Floor:  a streak painted on the lane under the ball (frozen lane, goo, scorch). Width in ball widths,
	--           Lifetime in seconds, FromRarity.
	--   Flicker: how much the trail's brightness flickers (fire, electric). Light: a glow following the ball,
	--           Flicker makes it flicker too.
	-- Power: how strong a style is at each rarity (multiplies Rate; Size grows a little with it).
	-- Ball styles: BallStyles below. A ball without one gets Stardust (its own colours). Cosmetic trails name their
	-- style and tier in Config.Cosmetics (Style, Tier).
	StylePower = { 0.35, 0.5, 0.65, 0.8, 1, 1.25 },
	TrailStyles = {
		Stardust = {
			Bits = {
				{ Image = "Ember", FromRarity = 2, Rate = 30, Size = { 0.05, 0.12, 0 }, Life = { 0.5, 1 },
					Speed = { 0.1, 0.4 }, Rise = 0.3, Twinkle = true, Emission = 0.7, Transparency = 0.15, Radius = 0.4 },
				{ Image = "Star", FromRarity = 3, Rate = 14, Size = { 0, 0.22, 0 }, Life = { 0.5, 0.9 },
					Speed = { 0, 0.15 }, Spin = 90, Twinkle = true, Emission = 0.8, Transparency = 0.1, Radius = 0.5 },
			},
			Floor = { FromRarity = 4, Width = 0.7, Lifetime = 0.7, Transparency = 0.55, Emission = 0.6 },
		},
		Fire = {
			Flicker = 0.35,
			Bits = {
				{ Image = "FlameTongue", Rate = 70, Upright = true, Bright = 2,
					Colors = { Color3.fromRGB(255, 245, 170), Color3.fromRGB(255, 160, 30), Color3.fromRGB(230, 50, 10) },
					Size = { 0.55, 0.8, 0.15 }, Life = { 0.25, 0.5 }, Speed = { 0.2, 0.6 }, Rise = 6, Drag = 2,
					Emission = 1, Transparency = 0, Radius = 0.35 },
				{ Image = "FlameTongue", FromRarity = 3, Rate = 30, Upright = true, Bright = 1.5,
					Colors = { Color3.fromRGB(255, 120, 20), Color3.fromRGB(180, 20, 0) },
					Size = { 0.9, 1.2, 0.3 }, Life = { 0.3, 0.55 }, Speed = { 0.1, 0.3 }, Rise = 4, Drag = 2,
					Emission = 0.9, Transparency = 0.2, Radius = 0.3 },
				{ Image = "Ember", Rate = 25, Colors = { Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 90, 20) },
					Size = { 0.08, 0.1, 0 }, Life = { 0.6, 1.2 }, Speed = { 0.8, 2 }, Rise = 3, Drag = 1.5, Twinkle = true,
					Emission = 1, Transparency = 0, Radius = 0.4 },
				{ Image = "Smoke", FromRarity = 3, Rate = 10, Colors = { Color3.fromRGB(70, 55, 50), Color3.fromRGB(35, 30, 30) },
					Size = { 0.4, 1, 1.6 }, Life = { 0.8, 1.3 }, Speed = { 0.2, 0.5 }, Rise = 2, Spin = 40,
					Emission = 0, Transparency = 0.55, Radius = 0.3 },
			},
			Floor = { FromRarity = 2, Width = 0.6, Lifetime = 0.6, Transparency = 0.35, Emission = 0.9,
				Colors = { Color3.fromRGB(255, 170, 40), Color3.fromRGB(180, 30, 0) } },
			Light = { Color = Color3.fromRGB(255, 130, 40), Brightness = 2.5, Range = 7, Flicker = 0.5 },
		},
		Ice = {
			Bits = {
				{ Image = "Snowflake", Rate = 22, Colors = { Color3.fromRGB(240, 252, 255), Color3.fromRGB(150, 220, 255) },
					Size = { 0.12, 0.28, 0.1 }, Life = { 0.9, 1.6 }, Speed = { 0.3, 0.9 }, Rise = -0.7, Drag = 1.5, Spin = 70,
					Emission = 0.6, Transparency = 0, Radius = 0.45 },
				{ Image = "Smoke", Rate = 12, Colors = { Color3.fromRGB(220, 245, 255), Color3.fromRGB(140, 200, 255) },
					Size = { 0.4, 0.9, 1.4 }, Life = { 0.6, 1 }, Speed = { 0.1, 0.3 }, Rise = -0.2, Spin = 30,
					Emission = 0.3, Transparency = 0.7, Radius = 0.3 },
				{ Image = "Diamond", FromRarity = 3, Rate = 12, Colors = { Color3.fromRGB(230, 250, 255), Color3.fromRGB(90, 200, 255) },
					Size = { 0.1, 0.16, 0 }, Life = { 0.5, 0.9 }, Speed = { 0.6, 1.5 }, Rise = -2, Spin = 200,
					Twinkle = true, Emission = 0.8, Transparency = 0, Radius = 0.45 },
			},
			Floor = { FromRarity = 1, Width = 0.8, Lifetime = 1.6, Transparency = 0.35, Emission = 0.35,
				Colors = { Color3.fromRGB(235, 250, 255), Color3.fromRGB(120, 200, 255) } },
			Light = { Color = Color3.fromRGB(150, 220, 255), Brightness = 1.5, Range = 6 },
		},
		Toxic = {
			Bits = {
				{ Image = "Bubble", Rate = 18, Colors = { Color3.fromRGB(200, 255, 120), Color3.fromRGB(90, 230, 40) },
					Size = { 0.05, 0.3, 0.38 }, Life = { 0.6, 1.2 }, Speed = { 0.2, 0.5 }, Rise = 1.5, Drag = 1,
					Emission = 0.55, Transparency = 0.05, Radius = 0.45 },
				{ Image = "Goo", Rate = 14, Colors = { Color3.fromRGB(170, 255, 60), Color3.fromRGB(60, 200, 20) },
					Size = { 0.14, 0.18, 0.1 }, Life = { 0.4, 0.7 }, Speed = { 0.1, 0.4 }, Rise = -8,
					Emission = 0.6, Transparency = 0, Radius = 0.45 },
				{ Image = "Smoke", FromRarity = 3, Rate = 10, Colors = { Color3.fromRGB(150, 255, 80), Color3.fromRGB(40, 120, 20) },
					Size = { 0.4, 1, 1.5 }, Life = { 0.7, 1.2 }, Speed = { 0.1, 0.4 }, Rise = 1, Spin = 30,
					Emission = 0.4, Transparency = 0.65, Radius = 0.3 },
			},
			Floor = { FromRarity = 1, Width = 0.75, Lifetime = 1.3, Transparency = 0.25, Emission = 0.6,
				Colors = { Color3.fromRGB(180, 255, 70), Color3.fromRGB(50, 170, 20) } },
			Light = { Color = Color3.fromRGB(130, 255, 60), Brightness = 1.5, Range = 6 },
		},
		Galaxy = {
			Bits = {
				{ Image = "Star", Rate = 30,
					Colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 150, 230), Color3.fromRGB(130, 210, 255) },
					Size = { 0, 0.22, 0 }, Life = { 0.8, 1.6 }, Speed = { 0, 0.2 }, Spin = 60, Twinkle = true,
					Emission = 1, Transparency = 0, Radius = 0.5 },
				{ Image = "Smoke", Rate = 14,
					Colors = { Color3.fromRGB(160, 70, 255), Color3.fromRGB(255, 80, 200), Color3.fromRGB(60, 160, 255) },
					Size = { 0.5, 1.1, 1.8 }, Life = { 0.8, 1.4 }, Speed = { 0.1, 0.3 }, Spin = 25,
					Emission = 0.7, Transparency = 0.6, Radius = 0.3 },
				{ Image = "Ember", FromRarity = 4, Rate = 30, Colors = { Color3.fromRGB(200, 230, 255), Color3.fromRGB(200, 120, 255) },
					Size = { 0.03, 0.07, 0 }, Life = { 0.6, 1.2 }, Speed = { 0.3, 0.8 }, Drag = 2, Twinkle = true,
					Emission = 1, Transparency = 0, Radius = 0.55 },
			},
			Floor = { FromRarity = 2, Width = 0.8, Lifetime = 1, Transparency = 0.45, Emission = 0.8,
				Colors = { Color3.fromRGB(150, 70, 255), Color3.fromRGB(60, 120, 255) } },
			Light = { Color = Color3.fromRGB(180, 110, 255), Brightness = 1.5, Range = 6 },
		},
		Gold = {
			Flicker = 0.15,
			Bits = {
				{ Image = "Coin", Rate = 12, Colors = { Color3.fromRGB(255, 255, 255) }, Bright = 1.5,
					Size = { 0.3, 0.34, 0.26 }, Life = { 0.6, 1 }, Speed = { 2, 3.5 }, Rise = -10, Spin = 360,
					Emission = 0.3, Transparency = 0, Radius = 0.5 },
				{ Image = "Star", Rate = 26, Colors = { Color3.fromRGB(255, 250, 200), Color3.fromRGB(255, 200, 40) },
					Size = { 0, 0.2, 0 }, Life = { 0.5, 1 }, Speed = { 0, 0.3 }, Spin = 120, Twinkle = true,
					Emission = 1, Transparency = 0, Radius = 0.5 },
				{ Image = "Ember", FromRarity = 3, Rate = 20, Colors = { Color3.fromRGB(255, 230, 120) },
					Size = { 0.04, 0.08, 0 }, Life = { 0.5, 1 }, Speed = { 0.2, 0.6 }, Rise = 0.5, Twinkle = true,
					Emission = 1, Transparency = 0, Radius = 0.45 },
			},
			Floor = { FromRarity = 2, Width = 0.7, Lifetime = 0.9, Transparency = 0.4, Emission = 0.8,
				Colors = { Color3.fromRGB(255, 230, 120), Color3.fromRGB(230, 150, 20) } },
			Light = { Color = Color3.fromRGB(255, 200, 70), Brightness = 2, Range = 6 },
		},
		Electric = {
			Flicker = 0.6,
			Bits = {
				{ Image = "Ember", Rate = 40, Colors = { Color3.fromRGB(240, 250, 255), Color3.fromRGB(80, 200, 255) },
					Size = { 0.06, 0.08, 0 }, Life = { 0.15, 0.35 }, Speed = { 3, 6 }, Drag = 5,
					Emission = 1, Transparency = 0, Radius = 0.45 },
				{ Image = "Bolt", Rate = 12, Colors = { Color3.fromRGB(230, 245, 255), Color3.fromRGB(90, 190, 255) },
					Size = { 0.5, 0.7, 0.4 }, Life = { 0.07, 0.15 }, Speed = { 0, 0.2 }, Spin = 0,
					Emission = 1, Transparency = 0, Radius = 0.55 },
				{ Image = "Smoke", FromRarity = 4, Rate = 8, Colors = { Color3.fromRGB(120, 200, 255), Color3.fromRGB(60, 80, 200) },
					Size = { 0.4, 0.8, 1.2 }, Life = { 0.4, 0.7 }, Speed = { 0.1, 0.3 }, Spin = 40,
					Emission = 0.6, Transparency = 0.7, Radius = 0.3 },
			},
			Floor = { FromRarity = 3, Width = 0.35, Lifetime = 0.5, Transparency = 0.3, Emission = 1,
				Colors = { Color3.fromRGB(220, 245, 255), Color3.fromRGB(60, 160, 255) } },
			Light = { Color = Color3.fromRGB(110, 200, 255), Brightness = 2, Range = 6, Flicker = 0.8 },
		},
		-- Skyline Lanes styles (zone 4 balls, 2026-10-27)
		Sky = { -- puffy clouds left hanging in the air, wind streaks and sky sparkles
			Bits = {
				{ Image = "Smoke", Rate = 22, Colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 232, 255) },
					Size = { 0.5, 1.1, 1.7 }, Life = { 0.9, 1.5 }, Speed = { 0.2, 0.6 }, Rise = 0.4, Drag = 1.5, Spin = 25,
					Emission = 0.15, Transparency = 0.25, Radius = 0.35, Bright = 1.2 },
				{ Image = "Star", Rate = 26, Colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 200, 255) },
					Size = { 0, 0.2, 0 }, Life = { 0.5, 1 }, Speed = { 0.1, 0.4 }, Spin = 120, Twinkle = true,
					Emission = 1, Transparency = 0, Radius = 0.55 },
				{ Image = "Dot", FromRarity = 4, Rate = 30, Colors = { Color3.fromRGB(220, 240, 255) },
					Size = { 0.03, 0.06, 0 }, Life = { 0.4, 0.8 }, Speed = { 1.5, 3 }, Drag = 3,
					Emission = 1, Transparency = 0.1, Radius = 0.5 },
			},
			Floor = { FromRarity = 2, Width = 0.8, Lifetime = 1, Transparency = 0.45, Emission = 0.6,
				Colors = { Color3.fromRGB(230, 245, 255), Color3.fromRGB(90, 170, 240) } },
			Light = { Color = Color3.fromRGB(170, 220, 255), Brightness = 1.5, Range = 6 },
		},
		Storm = { -- gold lightning: bolts crackling round the ball, sparks flying off, dark storm cloud behind
			Flicker = 0.7,
			Bits = {
				{ Image = "Bolt", Rate = 22, Colors = { Color3.fromRGB(255, 255, 230), Color3.fromRGB(255, 220, 60) }, Bright = 2,
					Size = { 0.6, 0.9, 0.5 }, Life = { 0.06, 0.14 }, Speed = { 0, 0.2 },
					Emission = 1, Transparency = 0, Radius = 0.6 },
				{ Image = "Ember", Rate = 55, Colors = { Color3.fromRGB(255, 255, 220), Color3.fromRGB(255, 200, 40) },
					Size = { 0.06, 0.09, 0 }, Life = { 0.15, 0.4 }, Speed = { 3, 7 }, Drag = 5,
					Emission = 1, Transparency = 0, Radius = 0.45 },
				{ Image = "Smoke", Rate = 14, Colors = { Color3.fromRGB(40, 45, 110), Color3.fromRGB(15, 18, 50) },
					Size = { 0.5, 1.1, 1.6 }, Life = { 0.6, 1.1 }, Speed = { 0.1, 0.3 }, Rise = 0.5, Spin = 40,
					Emission = 0, Transparency = 0.45, Radius = 0.3 },
			},
			Floor = { FromRarity = 1, Width = 0.4, Lifetime = 0.6, Transparency = 0.2, Emission = 1,
				Colors = { Color3.fromRGB(255, 250, 200), Color3.fromRGB(255, 190, 30) } },
			Light = { Color = Color3.fromRGB(255, 220, 90), Brightness = 2.5, Range = 7, Flicker = 0.9 },
		},
		Solar = { -- a little sun: flares licking up, glowing embers, flashes of sunlight and a burning lane
			Flicker = 0.25,
			Bits = {
				{ Image = "FlameTongue", Rate = 45, Upright = true, Bright = 1.8,
					Colors = { Color3.fromRGB(255, 250, 200), Color3.fromRGB(255, 190, 40), Color3.fromRGB(255, 110, 20) },
					Size = { 0.45, 0.7, 0.1 }, Life = { 0.25, 0.45 }, Speed = { 0.2, 0.5 }, Rise = 5, Drag = 2,
					Emission = 1, Transparency = 0, Radius = 0.4 },
				{ Image = "Ember", Rate = 35, Colors = { Color3.fromRGB(255, 240, 160), Color3.fromRGB(255, 150, 30) },
					Size = { 0.06, 0.1, 0 }, Life = { 0.6, 1.2 }, Speed = { 0.8, 2 }, Rise = 2, Drag = 1.5, Twinkle = true,
					Emission = 1, Transparency = 0, Radius = 0.45 },
				{ Image = "Burst", FromRarity = 5, Rate = 6, Colors = { Color3.fromRGB(255, 230, 140), Color3.fromRGB(255, 160, 40) },
					Size = { 0.3, 0.9, 1.3 }, Life = { 0.4, 0.6 }, Speed = { 0, 0.1 }, Spin = 60,
					Emission = 1, Transparency = 0.5, Radius = 0.2 },
			},
			Floor = { FromRarity = 1, Width = 0.7, Lifetime = 0.8, Transparency = 0.3, Emission = 0.9,
				Colors = { Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 120, 20) } },
			Light = { Color = Color3.fromRGB(255, 180, 60), Brightness = 2.5, Range = 7, Flicker = 0.3 },
		},
		Dawn = { -- night turning to sunrise: twinkling stars, pink-gold sun sparks and a warm glow on the lane
			Bits = {
				{ Image = "Star", Rate = 30, Colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 210, 255) },
					Size = { 0, 0.2, 0 }, Life = { 0.8, 1.5 }, Speed = { 0, 0.2 }, Spin = 60, Twinkle = true,
					Emission = 1, Transparency = 0, Radius = 0.55 },
				{ Image = "Smoke", Rate = 16,
					Colors = { Color3.fromRGB(255, 150, 190), Color3.fromRGB(255, 170, 90), Color3.fromRGB(60, 50, 150) },
					Size = { 0.5, 1.1, 1.8 }, Life = { 0.8, 1.4 }, Speed = { 0.1, 0.3 }, Rise = 0.3, Spin = 25,
					Emission = 0.6, Transparency = 0.55, Radius = 0.3 },
				{ Image = "Ember", Rate = 35, Colors = { Color3.fromRGB(255, 230, 150), Color3.fromRGB(255, 120, 150) },
					Size = { 0.05, 0.09, 0 }, Life = { 0.6, 1.1 }, Speed = { 0.6, 1.6 }, Rise = 1.5, Drag = 1.5, Twinkle = true,
					Emission = 1, Transparency = 0, Radius = 0.45 },
			},
			Floor = { FromRarity = 1, Width = 0.85, Lifetime = 1.1, Transparency = 0.35, Emission = 0.8,
				Colors = { Color3.fromRGB(255, 210, 120), Color3.fromRGB(255, 120, 160), Color3.fromRGB(70, 60, 170) } },
			Light = { Color = Color3.fromRGB(255, 160, 130), Brightness = 2, Range = 7 },
		},
	},
	-- Which balls draw which style (ball Id -> TrailStyles name), matched to the ball's name.
	-- Polish v2 L6: re-matched to the v2 balls (the ids kept their old names: Magma is now the Coral Crusher, so it
	-- lost its fire; Dragon is the Monsoon = Storm). Balls not listed draw Stardust in their own repainted colours.
	-- Was: Electric/Thunder/Plasma = Electric, Toxic = Toxic, Frostbite/DumpsterDiamond/Crystal = Ice,
	-- Magma/Inferno/Dragon = Fire, Galaxy/Nebula/Void/Supernova = Galaxy, SolidGold = Gold.
	BallStyles = {
		CloudSwirl = "Sky", -- Cloud Roll
		Frostbite = "Sky", -- Gust
		Lightning = "Storm", -- Sunbolt
		Sunburst = "Solar", -- Sunspike
		Daybreak = "Galaxy", -- Sonic Boom (its signature is a black hole + boom)
		SolidGold = "Sky", -- Tornado
		Electric = "Sky", -- Kite Flyer
		Golden = "Gold", -- Lighthouse Beam
		Thunder = "Dawn", -- Sunset Splash
		Void = "Gold", -- Jungle King
		Dragon = "Storm", -- Monsoon
		Championship = "Gold", -- Temple Stone
		Hubcap = "Sky", -- Dust Devil
		RustBucket = "Sky", -- Sandstorm
		Scorpion = "Toxic", -- Scorpion (venom)
		Perfect300 = "Solar", -- Sun Disc
		Supernova = "Gold", -- Golden Sphinx
	},
	-- Mythic balls also send glowing shock rings across the lane in their trail's colours
	MythicShockwave = { Rate = 4, Size = { 0.6, 3.5 }, Life = 0.7, Transparency = 0.35, Emission = 0.8 },
	-- Polish v2 L6: each ladder ball's v2 paint (from assets/v2_balls/spec.json: Main = its most vivid colour, dark ones
	-- lifted so a trail still glows; Accent = its gem / insert colour). Every effect colour of the ball (trail, sparkles,
	-- light, rings) is turned to Main's hue keeping its own lightness, so whites stay white (BallFx.lookFor). The trail
	-- styles with a theme of their own (Fire, Solar...) keep their colours. V2Spread: how much of each colour's distance
	-- round the colour wheel from the look's average it keeps (0 = all one hue, 1 = only turned); Spread on a row
	-- overrides it (the rainbow and confetti balls keep all their colours).
	V2Spread = 0.3,
	V2Paint = {
		Tangerine = { Main = Color3.fromHex("F9C66D"), Accent = Color3.fromHex("E0A24C") }, -- Z1_beach_roller
		CloudSwirl = { Main = Color3.fromHex("73C6FD"), Accent = Color3.fromHex("FFD66B") }, -- Z1_cloud_roll
		Lime = { Main = Color3.fromHex("F587AF"), Accent = Color3.fromHex("FF4FA3"), Spread = 1 }, -- Z1_confetti_popper
		Frostbite = { Main = Color3.fromHex("49B7F8"), Accent = Color3.fromHex("8BD4FF") }, -- Z1_gust
		Crystal = { Main = Color3.fromHex("FFA13F"), Accent = Color3.fromHex("FFC07F"), Spread = 1 }, -- Z1_rainbow_arc
		Bubblegum = { Main = Color3.fromHex("FC5746"), Accent = Color3.fromHex("C7362A") }, -- Z1_rubber_bouncer
		Daybreak = { Main = Color3.fromHex("2A82B5"), Accent = Color3.fromHex("FF4FD8") }, -- Z1_sonic_boom
		Lightning = { Main = Color3.fromHex("FFA332"), Accent = Color3.fromHex("FFE45C") }, -- Z1_sunbolt
		Sunburst = { Main = Color3.fromHex("FF7916"), Accent = Color3.fromHex("FF7A1A") }, -- Z1_sunspike
		SolidGold = { Main = Color3.fromHex("83B9EF"), Accent = Color3.fromHex("5FD4FF") }, -- Z1_tornado
		Sunset = { Main = Color3.fromHex("FF735E"), Accent = Color3.fromHex("FFAA9E") }, -- Z2_beach_ball
		Magma = { Main = Color3.fromHex("FE7460"), Accent = Color3.fromHex("F0D696") }, -- Z2_coral_crusher
		Electric = { Main = Color3.fromHex("3ACEDA"), Accent = Color3.fromHex("F0D696") }, -- Z2_kite_flyer
		Golden = { Main = Color3.fromHex("D02934"), Accent = Color3.fromHex("40CED6") }, -- Z2_lighthouse_beam
		Plasma = { Main = Color3.fromHex("C87154"), Accent = Color3.fromHex("40CED6") }, -- Z2_pier_pounder
		Ocean = { Main = Color3.fromHex("D28674"), Accent = Color3.fromHex("E39A88") }, -- Z2_seashell_spinner
		Thunder = { Main = Color3.fromHex("FF9A4C"), Accent = Color3.fromHex("FFD86B") }, -- Z2_sunset_splash
		Galaxy = { Main = Color3.fromHex("F03931"), Accent = Color3.fromHex("40CED6") }, -- Z2_surf_rider
		Toxic = { Main = Color3.fromHex("34CDD5"), Accent = Color3.fromHex("7CF5FB") }, -- Z2_tide_turner
		Nebula = { Main = Color3.fromHex("6DDCE3"), Accent = Color3.fromHex("A6F5F7") }, -- Z2_tsunami
		CherrySwirl = { Main = Color3.fromHex("D98541"), Accent = Color3.fromHex("FFBF8D") }, -- Z3_coconut
		TigerSwirl = { Main = Color3.fromHex("FF9630"), Accent = Color3.fromHex("FFB670") }, -- Z3_jaguar
		Void = { Main = Color3.fromHex("FFC93A"), Accent = Color3.fromHex("B6F05A") }, -- Z3_jungle_king
		Phantom = { Main = Color3.fromHex("C8BA58"), Accent = Color3.fromHex("B6F05A") }, -- Z3_leaf_storm
		Dragon = { Main = Color3.fromHex("58CAD9"), Accent = Color3.fromHex("46D2DC") }, -- Z3_monsoon
		Inferno = { Main = Color3.fromHex("CEAA5B"), Accent = Color3.fromHex("FF9632") }, -- Z3_rope_bridge
		Championship = { Main = Color3.fromHex("5DBA51"), Accent = Color3.fromHex("3FD07A") }, -- Z3_temple_stone
		BlueMarble = { Main = Color3.fromHex("FB952E"), Accent = Color3.fromHex("FF9632") }, -- Z3_toucan_roll
		LeagueBlack = { Main = Color3.fromHex("77D96A"), Accent = Color3.fromHex("60B854") }, -- Z3_vine_swinger
		PearlPro = { Main = Color3.fromHex("53D7E1"), Accent = Color3.fromHex("46D2DC") }, -- Z3_waterfall
		DumpsterDiamond = { Main = Color3.fromHex("FF8CBD"), Accent = Color3.fromHex("FF6FA8") }, -- Z4_cactus_roller
		CanyonEcho = { Main = Color3.fromHex("77AFD9"), Accent = Color3.fromHex("38C8C8") }, -- Z4_canyon_echo
		Hubcap = { Main = Color3.fromHex("E49665"), Accent = Color3.fromHex("FFC846") }, -- Z4_dust_devil
		Supernova = { Main = Color3.fromHex("FFCC51"), Accent = Color3.fromHex("38C8C8") }, -- Z4_golden_sphinx
		DuctTape = { Main = Color3.fromHex("DB794F"), Accent = Color3.fromHex("38C8C8") }, -- Z4_mesa_smash
		Mirage = { Main = Color3.fromHex("4CC0D4"), Accent = Color3.fromHex("B79CFF") }, -- Z4_mirage
		Rookie = { Main = Color3.fromHex("EFB65A"), Accent = Color3.fromHex("38C8C8") }, -- Z4_oasis_spring
		RustBucket = { Main = Color3.fromHex("DC9A4D"), Accent = Color3.fromHex("FFC846") }, -- Z4_sandstorm
		Scorpion = { Main = Color3.fromHex("CEA145"), Accent = Color3.fromHex("E8423A") }, -- Z4_scorpion
		Perfect300 = { Main = Color3.fromHex("E3A329"), Accent = Color3.fromHex("38C8C8") }, -- Z4_sun_disc
	},
	Balls = {
		-- Back Alley balls: effects from the design notes (tape scraps, rust sparks, chrome glint, crystal shards)
		DuctTape = {
			Particles = {
				{
					Image = "Diamond",
					Colors = { Color3.fromHex("C0C4C9"), Color3.fromHex("E2579B") },
					Rate = 6,
					Size = 0.08,
					Life = { 0.3, 0.6 },
					Speed = { 0.3, 0.8 },
					Radius = 0.45,
				},
			},
		},
		RustBucket = {
			Particles = {
				{
					Image = "Star",
					Colors = { Color3.fromHex("FFB060"), Color3.fromHex("D2692A") },
					Rate = 10,
					Size = 0.07,
					Life = { 0.2, 0.5 },
					Speed = { 0.6, 1.4 },
					Radius = 0.45,
				},
			},
		},
		Hubcap = {
			Trails = {
				{
					Colors = { Color3.fromHex("E9EEF3"), Color3.fromHex("7DF0A6") },
					Width = 0.8,
					Lifetime = 0.25,
				},
			},
			Particles = {
				{
					Image = "Star",
					Colors = { WHITE, Color3.fromHex("7DF0A6") },
					Rate = 4,
					Size = 0.2,
					Life = { 0.2, 0.35 },
					Speed = { 0, 0.1 },
					Radius = 0.5,
				},
			},
		},
		DumpsterDiamond = {
			Trails = {
				{
					Colors = { Color3.fromHex("9FE6FF"), Color3.fromHex("38C6FF"), Color3.fromHex("1565C0") },
					Width = 1,
					Lifetime = 0.35,
				},
			},
			Particles = {
				{
					Image = "Diamond",
					Colors = { Color3.fromHex("E8FCFF"), Color3.fromHex("3CC8FF") },
					Rate = 25,
					Size = 0.1,
					Life = { 0.4, 0.8 },
					Speed = { 0.2, 0.6 },
					Radius = 0.45,
				},
			},
			Badge = { Image = "Burst", Size = 0.5, Height = 0.95 },
			Light = { Color = Color3.fromHex("3CC8FF"), Brightness = 2, Range = 4 },
		},
		-- Uncommon: a soft streak in the ball's colour
		Electric = {
			Trails = {
				{
					Colors = { Color3.fromRGB(138, 222, 255), Color3.fromRGB(60, 200, 255) },
					Width = 0.8,
					Lifetime = 0.25,
				},
			},
		},
		Toxic = {
			Trails = {
				{
					Colors = { Color3.fromRGB(174, 255, 138), Color3.fromRGB(120, 255, 60) },
					Width = 0.8,
					Lifetime = 0.25,
				},
			},
		},
		Sunset = {
			Trails = {
				{
					Colors = { Color3.fromRGB(255, 240, 80), Color3.fromRGB(255, 80, 200) },
					Width = 0.8,
					Lifetime = 0.25,
				},
			},
		},
		Frostbite = {
			Trails = {
				{
					Colors = { Color3.fromRGB(192, 234, 255), Color3.fromRGB(150, 220, 255) },
					Width = 0.8,
					Lifetime = 0.25,
				},
			},
		},

		-- Rare: blue comet trail with sparkles, plus the trait icon floating above
		Magma = {
			Trails = {
				{
					Colors = {
						Color3.fromRGB(150, 204, 255),
						Color3.fromRGB(80, 170, 255),
						Color3.fromRGB(40, 80, 255),
					},
					Width = 1,
					Lifetime = 0.35,
				},
			},
			Particles = {
				{
					Image = "Star",
					Colors = { WHITE, Color3.fromRGB(255, 150, 50) },
					Rate = 30,
					Size = 0.12,
					Life = { 0.4, 0.8 },
					Speed = { 0.2, 0.6 },
					Radius = 0.45,
				},
			},
			Badge = { Image = "Burst", Size = 0.5, Height = 0.95 },
			Light = { Color = Color3.fromRGB(255, 120, 40), Brightness = 2, Range = 4 },
		},
		Galaxy = {
			Trails = {
				{
					Colors = {
						Color3.fromRGB(192, 186, 255),
						Color3.fromRGB(150, 140, 255),
						Color3.fromRGB(60, 70, 255),
					},
					Width = 1,
					Lifetime = 0.35,
				},
			},
			Particles = {
				{
					Image = "Star",
					Colors = { WHITE, Color3.fromRGB(200, 180, 255) },
					Rate = 30,
					Size = 0.12,
					Life = { 0.4, 0.8 },
					Speed = { 0.2, 0.6 },
					Radius = 0.45,
				},
			},
			Badge = { Image = "Clover", Size = 0.45, Height = 0.95 },
			Light = { Color = Color3.fromRGB(140, 120, 255), Brightness = 2, Range = 4 },
		},
		Thunder = {
			Trails = {
				{
					Colors = {
						Color3.fromRGB(126, 228, 255),
						Color3.fromRGB(40, 210, 255),
						Color3.fromRGB(30, 110, 255),
					},
					Width = 1,
					Lifetime = 0.35,
				},
			},
			Particles = {
				{
					Image = "Star",
					Colors = { WHITE, Color3.fromRGB(255, 230, 60) },
					Rate = 30,
					Size = 0.12,
					Life = { 0.4, 0.8 },
					Speed = { 0.2, 0.6 },
					Radius = 0.45,
				},
			},
			Badge = { Image = "Shield", Size = 0.55, Height = 1 },
			Light = { Color = Color3.fromRGB(60, 200, 255), Brightness = 2, Range = 4 },
		},
		Phantom = {
			Trails = {
				{
					Colors = {
						Color3.fromRGB(192, 228, 255),
						Color3.fromRGB(150, 210, 255),
						Color3.fromRGB(70, 130, 255),
					},
					Width = 1,
					Lifetime = 0.35,
				},
			},
			Particles = {
				{
					Image = "Star",
					Colors = { WHITE, Color3.fromRGB(210, 230, 255) },
					Rate = 30,
					Size = 0.12,
					Life = { 0.4, 0.8 },
					Speed = { 0.2, 0.6 },
					Radius = 0.45,
				},
			},
			Badge = { Image = "Spiral", Size = 0.45, Height = 0.95 },
			Light = { Color = Color3.fromRGB(150, 200, 255), Brightness = 2, Range = 4 },
		},

		-- Epic: a column of glowing dots rising off the ball
		Plasma = {
			Trails = {
				{
					Colors = {
						Color3.fromRGB(150, 234, 255),
						Color3.fromRGB(80, 220, 255),
						Color3.fromRGB(140, 60, 255),
					},
					Width = 0.9,
					Lifetime = 0.3,
				},
			},
			Particles = {
				{
					Image = "Dot",
					Colors = { Color3.fromRGB(90, 230, 255), Color3.fromRGB(200, 160, 255), WHITE },
					Rate = 40,
					Size = 0.14,
					Life = { 1, 1.8 },
					Speed = { 0.2, 0.5 },
					Rise = 0.8,
					Radius = 0.4,
					Twinkle = true,
				},
			},
			Halos = { { Image = "Dot", Color = Color3.fromRGB(140, 90, 255), Size = 2.2, Transparency = 0.6 } },
			Light = { Color = Color3.fromRGB(150, 90, 255), Brightness = 3, Range = 5 },
		},
		Nebula = {
			Trails = {
				{
					Colors = {
						Color3.fromRGB(255, 156, 228),
						Color3.fromRGB(255, 90, 210),
						Color3.fromRGB(90, 130, 255),
					},
					Width = 0.9,
					Lifetime = 0.3,
				},
			},
			Particles = {
				{
					Image = "Dot",
					Colors = {
						Color3.fromRGB(255, 90, 210),
						Color3.fromRGB(80, 200, 255),
						Color3.fromRGB(120, 110, 255),
					},
					Rate = 40,
					Size = 0.14,
					Life = { 1, 1.8 },
					Speed = { 0.2, 0.5 },
					Rise = 0.8,
					Radius = 0.4,
					Twinkle = true,
				},
				{
					Image = "Star",
					Colors = { Color3.fromRGB(255, 220, 90) },
					Rate = 14,
					Size = 0.14,
					Life = { 0.4, 0.8 },
					Speed = { 0.1, 0.4 },
					Radius = 0.5,
					Twinkle = true,
				},
			},
			Halos = { { Image = "Dot", Color = Color3.fromRGB(220, 80, 255), Size = 2.2, Transparency = 0.6 } },
			Light = { Color = Color3.fromRGB(220, 80, 255), Brightness = 3, Range = 5 },
		},
		Inferno = {
			Trails = {
				{
					Colors = {
						Color3.fromRGB(255, 156, 234),
						Color3.fromRGB(255, 90, 220),
						Color3.fromRGB(255, 200, 60),
					},
					Width = 0.9,
					Lifetime = 0.3,
				},
			},
			Particles = {
				{
					Image = "Dot",
					Colors = {
						Color3.fromRGB(255, 80, 220),
						Color3.fromRGB(255, 200, 60),
						Color3.fromRGB(190, 90, 255),
					},
					Rate = 40,
					Size = 0.14,
					Life = { 1, 1.8 },
					Speed = { 0.2, 0.5 },
					Rise = 0.8,
					Radius = 0.4,
					Twinkle = true,
				},
			},
			Halos = { { Image = "Dot", Color = Color3.fromRGB(255, 70, 220), Size = 2.2, Transparency = 0.6 } },
			Light = { Color = Color3.fromRGB(255, 80, 220), Brightness = 3, Range = 5 },
		},

		-- Legendary
		Golden = {
			Trails = {
				{
					Colors = { Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 190, 40) },
					Width = 0.6,
					Lifetime = 0.45,
					Texture = "Bolt",
				},
				{
					Colors = { Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 150, 30) },
					Width = 1,
					Lifetime = 0.2,
					Transparency = 0.6,
				},
			},
			Particles = {
				{
					Image = "Diamond",
					Colors = { Color3.fromRGB(190, 255, 245), Color3.fromRGB(120, 240, 230) },
					Rate = 6,
					Size = 0.16,
					Life = { 1.2, 2 },
					Speed = { 0.05, 0.2 },
					Radius = 0.85,
					Twinkle = true,
				},
				{
					Image = "Dot",
					Colors = { Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 170, 60) },
					Rate = 35,
					Size = 0.07,
					Life = { 0.8, 1.6 },
					Speed = { 0.1, 0.4 },
					Rise = 0.3,
					Radius = 0.7,
					Twinkle = true,
				},
			},
			Halos = { { Image = "Dot", Color = Color3.fromRGB(255, 190, 60), Size = 2.4, Transparency = 0.55 } },
			Ground = {
				{ Color = Color3.fromRGB(255, 235, 30), Radius = 0.9, Transparency = 0 },
				{ Color = Color3.fromRGB(255, 170, 40), Radius = 1.15, Transparency = 0.6 },
			},
			Light = { Color = Color3.fromRGB(255, 190, 60), Brightness = 3, Range = 6 },
		},
		Dragon = {
			Trails = {
				{
					Colors = { Color3.fromRGB(255, 230, 150), Color3.fromRGB(255, 140, 40) },
					Width = 0.5,
					Lifetime = 0.4,
					Texture = "Bolt",
				},
				{
					Colors = {
						Color3.fromRGB(255, 220, 120),
						Color3.fromRGB(255, 110, 20),
						Color3.fromRGB(200, 40, 10),
					},
					Width = 1.1,
					Lifetime = 0.3,
					Transparency = 0.2,
				},
			},
			Particles = {
				{
					Image = "Flame",
					Colors = {
						Color3.fromRGB(255, 220, 110),
						Color3.fromRGB(255, 120, 30),
						Color3.fromRGB(200, 40, 20),
					},
					Rate = 60,
					Size = 0.5,
					Life = { 0.35, 0.7 },
					Speed = { 0.3, 0.8 },
					Rise = 3,
					Radius = 0.4,
					Spin = 60,
				},
				{
					Image = "Dot",
					Colors = { Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 120, 30) },
					Rate = 25,
					Size = 0.06,
					Life = { 0.8, 1.6 },
					Speed = { 0.4, 1 },
					Rise = 1.2,
					Radius = 0.5,
					Twinkle = true,
				},
			},
			Ground = {
				{ Color = Color3.fromRGB(255, 130, 20), Radius = 0.85, Transparency = 0 },
				{ Color = Color3.fromRGB(255, 80, 20), Radius = 1.2, Transparency = 0.5 },
			},
			Light = { Color = Color3.fromRGB(255, 120, 30), Brightness = 4, Range = 6 },
		},

		-- Mythic
		Void = {
			Trails = {
				{
					Colors = {
						Color3.fromRGB(255, 120, 240),
						Color3.fromRGB(200, 40, 220),
						Color3.fromRGB(90, 20, 160),
					},
					Width = 1.2,
					Lifetime = 0.45,
				},
				{
					Colors = { Color3.fromRGB(255, 156, 240), Color3.fromRGB(255, 90, 230) },
					Width = 0.35,
					Lifetime = 0.3,
				},
			},
			Particles = {
				{
					Image = "Diamond",
					Colors = { Color3.fromRGB(255, 90, 220), Color3.fromRGB(255, 160, 240) },
					Rate = 14,
					Size = 0.1,
					Life = { 0.8, 1.5 },
					Speed = { 0.2, 0.6 },
					Radius = 0.9,
					Twinkle = true,
					Spin = 90,
				},
			},
			-- the owner's accretion disk, photon ring and shards (the-void-ball.obj)
			Halos = {
				{ Image = "Dot", Color = Color3.fromRGB(190, 40, 255), Size = 2.6, Transparency = 0.45 },
			},
			Light = { Color = Color3.fromRGB(230, 60, 255), Brightness = 4, Range = 7 },
		},
		Supernova = {
			Trails = {
				{
					-- full-strength rainbow from the ball to the tail; no white, and a low Glow so the
					-- colours don't add up to white under bloom
					Colors = {
						Color3.fromRGB(255, 40, 60),
						Color3.fromRGB(255, 140, 0),
						Color3.fromRGB(255, 230, 0),
						Color3.fromRGB(40, 230, 60),
						Color3.fromRGB(0, 180, 255),
						Color3.fromRGB(90, 60, 255),
						Color3.fromRGB(200, 40, 255),
					},
					Width = 1.3,
					Lifetime = 0.5,
					Transparency = 0.15,
					Glow = 0.25,
					-- the body carries the rainbow as bands across its width, so the follow camera (which only
					-- sees the front of the trail) still sees every colour
					BodyTexture = "TrailRainbow",
				},
			},
			Particles = {
				{
					Image = "Star",
					Colors = { Color3.fromRGB(255, 220, 40), Color3.fromRGB(255, 120, 30) },
					Rate = 16,
					Size = 0.2,
					Life = { 0.6, 1.2 },
					Speed = { 0.05, 0.2 },
					Radius = 0.95,
					Twinkle = true,
					Spin = 45,
				},
				{
					Image = "Dot",
					Colors = {
						Color3.fromRGB(255, 60, 120),
						Color3.fromRGB(60, 200, 255),
						Color3.fromRGB(120, 255, 90),
						Color3.fromRGB(190, 80, 255),
					},
					Rate = 40,
					Size = 0.05,
					Life = { 0.5, 1 },
					Speed = { 0.2, 0.6 },
					Radius = 0.5,
					Twinkle = true,
				},
			},
			-- the owner's three rings and mini stars (supernova-ball.obj)
			-- tinted glow and light: a white glow reflects off the shiny lane as a white streak behind the ball
			Halos = { { Image = "Dot", Color = Color3.fromRGB(150, 70, 255), Size = 2.4, Transparency = 0.6 } },
			Light = { Color = Color3.fromRGB(255, 70, 190), Brightness = 2.5, Range = 6 },
		},

		-- Main Street Lanes balls (owner's claude.ai/design 'Main Street Lanes Bowling Balls', 2026-10-27):
		-- trail colours and roll effects from the design notes
		LeagueBlack = {
			Trails = { { Colors = { Color3.fromHex("E0465C"), Color3.fromHex("C21E37") }, Width = 1, Lifetime = 0.35 } },
			-- a thin red ring ripples around the ball as it spins
			Rings = { { Radius = 0.62, Width = 0.05, Color = Color3.fromHex("C21E37"), Tilt = { 90, 0 }, Spin = 0.6 } },
			Badge = { Image = "Burst", Size = 0.5, Height = 0.95 },
			Light = { Color = Color3.fromHex("C21E37"), Brightness = 1.5, Range = 4 },
		},
		CherrySwirl = {
			Trails = { { Colors = { Color3.fromHex("F2E6CF"), Color3.fromHex("E85A6E"), Color3.fromHex("C21E37") }, Width = 1, Lifetime = 0.35 } },
			-- little whipped-cream puffs
			Particles = {
				{ Image = "Dot", Colors = { Color3.fromHex("FFF8EC"), Color3.fromHex("F2E6CF") }, Rate = 14, Size = 0.14,
					Life = { 0.4, 0.8 }, Speed = { 0.1, 0.4 }, Rise = 0.3, Radius = 0.45 },
			},
			Badge = { Image = "Burst", Size = 0.5, Height = 0.95 },
			Light = { Color = Color3.fromHex("E85A6E"), Brightness = 1.5, Range = 4 },
		},
		BlueMarble = {
			Trails = { { Colors = { Color3.fromHex("F4F6FB"), Color3.fromHex("8FB0EA"), Color3.fromHex("6E93E8") }, Width = 1, Lifetime = 0.35 } },
			-- a polished glint and tiny stone chips
			Particles = {
				{ Image = "Star", Colors = { Color3.fromHex("FFFFFF") }, Rate = 3, Size = 0.25, Life = { 0.15, 0.3 },
					Speed = { 0, 0.1 }, Radius = 0.5 },
				{ Image = "Diamond", Colors = { Color3.fromHex("F4F6FB"), Color3.fromHex("8FB0EA") }, Rate = 16, Size = 0.07,
					Life = { 0.3, 0.6 }, Speed = { 0.5, 1.2 }, Radius = 0.45 },
			},
			Badge = { Image = "Burst", Size = 0.5, Height = 0.95 },
			Light = { Color = Color3.fromHex("6E93E8"), Brightness = 1.5, Range = 4 },
		},
		PearlPro = {
			Trails = {
				{ Colors = { Color3.fromHex("F2B9CC"), Color3.fromHex("D2C2F0"), Color3.fromHex("B8D2F2") }, Width = 1.1,
					Lifetime = 0.45, Texture = "TrailRainbow" },
			},
			-- rainbow bubbles drift up behind it
			Particles = {
				{ Image = "Ring", Colors = { Color3.fromHex("F2B9CC"), Color3.fromHex("B9E6D2"), Color3.fromHex("B8D2F2"), Color3.fromHex("D2C2F0") },
					Rate = 12, Size = 0.16, Life = { 0.8, 1.4 }, Speed = { 0.05, 0.2 }, Rise = 0.6, Radius = 0.55, Twinkle = true },
			},
			Halos = { { Image = "Dot", Color = Color3.fromHex("F6F1E7"), Size = 2.2, Transparency = 0.7 } },
			Light = { Color = Color3.fromHex("F2D9E6"), Brightness = 2, Range = 5 },
		},
		TigerSwirl = {
			Trails = { { Colors = { Color3.fromHex("FFB347"), Color3.fromHex("F08A24"), Color3.fromHex("A8480C") }, Width = 1.1, Lifetime = 0.4 } },
			-- glowing scratch sparks that fade out
			Particles = {
				{ Image = "Bolt", Colors = { Color3.fromHex("FFB347"), Color3.fromHex("F08A24") }, Rate = 6, Size = 0.35,
					Life = { 0.3, 0.5 }, Speed = { 0, 0.2 }, Radius = 0.55 },
				{ Image = "Ember", Colors = { Color3.fromHex("FFB347"), Color3.fromHex("F08A24") }, Rate = 20, Size = 0.06,
					Life = { 0.3, 0.7 }, Speed = { 0.3, 0.8 }, Radius = 0.45 },
			},
			Halos = { { Image = "Dot", Color = Color3.fromHex("F08A24"), Size = 2.2, Transparency = 0.65 } },
			Light = { Color = Color3.fromHex("F08A24"), Brightness = 2, Range = 5 },
		},
		Championship = {
			Trails = {
				{ Colors = { Color3.fromHex("F2CF72"), Color3.fromHex("E2B24A"), Color3.fromHex("B8892E") }, Width = 1.1, Lifetime = 0.45 },
				{ Colors = { Color3.fromHex("2A4FB8") }, Width = 0.45, Lifetime = 0.4 }, -- royal-blue core
			},
			-- gold confetti and laurel leaves
			Particles = {
				{ Image = "Diamond", Colors = { Color3.fromHex("F2CF72"), Color3.fromHex("E2B24A"), Color3.fromHex("2A4FB8") }, Rate = 30,
					Size = 0.08, Life = { 0.8, 1.4 }, Speed = { 0.3, 0.8 }, Rise = -0.4, Radius = 0.6, Twinkle = true },
				{ Image = "Star", Colors = { Color3.fromHex("FFF4CC"), Color3.fromHex("E2B24A") }, Rate = 10, Size = 0.18,
					Life = { 0.4, 0.8 }, Speed = { 0, 0.2 }, Radius = 0.5, Twinkle = true },
			},
			Halos = { { Image = "Dot", Color = Color3.fromHex("E2B24A"), Size = 2.4, Transparency = 0.55 } },
			Ground = {
				{ Color = Color3.fromHex("F2CF72"), Radius = 0.9, Transparency = 0 },
				{ Color = Color3.fromHex("2A4FB8"), Radius = 1.15, Transparency = 0.6 },
			},
			Light = { Color = Color3.fromHex("E2B24A"), Brightness = 3, Range = 6 },
		},
		Perfect300 = {
			Trails = {
				{ Colors = { Color3.fromHex("E0465C"), Color3.fromHex("C21E37"), Color3.fromHex("7A0E1F") }, Width = 1.1, Lifetime = 0.45 },
			},
			-- gold X sparks pop off it
			Particles = {
				{ Image = "Star", Colors = { Color3.fromHex("FFE9A8"), Color3.fromHex("E2B24A") }, Rate = 24, Size = 0.16,
					Life = { 0.4, 0.8 }, Speed = { 0.4, 1 }, Spin = 180, Radius = 0.55, Twinkle = true },
				{ Image = "Ember", Colors = { Color3.fromHex("E2B24A") }, Rate = 20, Size = 0.06,
					Life = { 0.4, 0.8 }, Speed = { 0.3, 0.7 }, Rise = 0.3, Radius = 0.5 },
			},
			Halos = { { Image = "Dot", Color = Color3.fromHex("C21E37"), Size = 2.4, Transparency = 0.55 } },
			Ground = {
				{ Color = Color3.fromHex("E2B24A"), Radius = 0.9, Transparency = 0 },
				{ Color = Color3.fromHex("C21E37"), Radius = 1.15, Transparency = 0.6 },
			},
			Light = { Color = Color3.fromHex("E0465C"), Brightness = 3, Range = 6 },
		},

		-- Skyline Lanes balls (owner's claude.ai/design 'Skyline Lanes' set, 2026-10-27). Built to look better than
		-- anything below them: every one has moving rings, a breathing glow and its own sky effect.
		-- Halos: Spin = degrees per second the image turns, Pulse = { times per second, how much it grows }.
		-- Light Flicker = how much the ball's own glow flickers.
		CloudSwirl = {
			Trails = { { Colors = { Color3.fromHex("FFFFFF"), Color3.fromHex("BFE4FF"), Color3.fromHex("5AAEE8") }, Width = 1.1, Lifetime = 0.45 } },
			-- little clouds puff off the ball and wind sparkles whirl round it
			Particles = {
				{ Image = "Smoke", Colors = { Color3.fromHex("FFFFFF"), Color3.fromHex("DDF0FF") }, Rate = 10, Size = 0.4,
					Life = { 0.6, 1.1 }, Speed = { 0.1, 0.3 }, Rise = 0.3, Radius = 0.5, Spin = 30 },
				{ Image = "Star", Colors = { Color3.fromHex("FFFFFF"), Color3.fromHex("8FD0FF") }, Rate = 14, Size = 0.14,
					Life = { 0.4, 0.8 }, Speed = { 0.1, 0.3 }, Radius = 0.6, Twinkle = true, Spin = 90 },
			},
			-- two wind rings at crossed tilts, turning opposite ways
			Rings = {
				{ Radius = 0.68, Width = 0.035, Color = Color3.fromHex("E8F6FF"), Tilt = { 70, 15 }, Spin = 0.5 },
				{ Radius = 0.76, Width = 0.025, Color = Color3.fromHex("7CC4F5"), Tilt = { 110, -20 }, Spin = -0.35 },
			},
			Halos = { { Image = "Dot", Color = Color3.fromHex("BFE4FF"), Size = 2.3, Transparency = 0.6, Pulse = { 0.6, 0.12 } } },
			Light = { Color = Color3.fromHex("BFE4FF"), Brightness = 1.5, Range = 4 },
		},
		Crystal = {
			Trails = { { Colors = { Color3.fromHex("E8FCFF"), Color3.fromHex("8FE0FF"), Color3.fromHex("2F8FE0") }, Width = 1.1, Lifetime = 0.45 } },
			Particles = {
				{ Image = "Diamond", Colors = { Color3.fromHex("FFFFFF"), Color3.fromHex("8FE0FF"), Color3.fromHex("4AB8FF") }, Rate = 24,
					Size = 0.11, Life = { 0.5, 1 }, Speed = { 0.3, 0.8 }, Radius = 0.55, Twinkle = true, Spin = 200 },
				{ Image = "Star", Colors = { Color3.fromHex("FFFFFF") }, Rate = 5, Size = 0.3, Life = { 0.15, 0.3 },
					Speed = { 0, 0.05 }, Radius = 0.48 },
			},
			Rings = { { Radius = 0.7, Width = 0.03, Color = Color3.fromHex("B8F0FF"), Tilt = { 90, 0 }, Spin = 0.4 } },
			Halos = {
				{ Image = "Dot", Color = Color3.fromHex("6CCBFF"), Size = 2.2, Transparency = 0.55, Pulse = { 0.8, 0.15 } },
				{ Image = "Diamond", Color = Color3.fromHex("DDF8FF"), Size = 1.5, Transparency = 0.75, Spin = 20 },
			},
			Light = { Color = Color3.fromHex("6CCBFF"), Brightness = 2, Range = 4 },
		},
		Sunburst = {
			Trails = {
				{ Colors = { Color3.fromHex("FFF4C2"), Color3.fromHex("FFB52E"), Color3.fromHex("FF7A1A") }, Width = 1.2, Lifetime = 0.5 },
				{ Colors = { Color3.fromHex("FFFBE6") }, Width = 0.4, Lifetime = 0.35 }, -- white-hot core
			},
			-- sun rays turning behind the ball, solar flares and sparks
			Halos = {
				{ Image = "Burst", Color = Color3.fromHex("FFE6A0"), Size = 2.4, Transparency = 0.78, Spin = 30, Pulse = { 1, 0.1 } },
				{ Image = "Dot", Color = Color3.fromHex("FF9A2E"), Size = 2.4, Transparency = 0.55, Pulse = { 0.7, 0.15 } },
			},
			Particles = {
				{ Image = "Flame", Colors = { Color3.fromHex("FFF0A0"), Color3.fromHex("FFB52E"), Color3.fromHex("FF6A1A") }, Rate = 30,
					Size = 0.35, Life = { 0.3, 0.6 }, Speed = { 0.3, 0.8 }, Rise = 2, Radius = 0.45, Spin = 60 },
				{ Image = "Ember", Colors = { Color3.fromHex("FFE9A0"), Color3.fromHex("FFA030") }, Rate = 25, Size = 0.07,
					Life = { 0.6, 1.2 }, Speed = { 0.4, 1 }, Rise = 1, Radius = 0.5, Twinkle = true },
			},
			Rings = { { Radius = 0.72, Width = 0.04, Color = Color3.fromHex("FFD45A"), Tilt = { 90, 0 }, Spin = 0.7 } },
			Ground = {
				{ Color = Color3.fromHex("FFD45A"), Radius = 0.9, Transparency = 0 },
				{ Color = Color3.fromHex("FF7A1A"), Radius = 1.2, Transparency = 0.5 },
			},
			Light = { Color = Color3.fromHex("FFB52E"), Brightness = 2.5, Range = 5, Flicker = 0.2 },
		},
		SolidGold = {
			Trails = {
				{ Colors = { Color3.fromHex("FFF0B0"), Color3.fromHex("FFD45A"), Color3.fromHex("C98A10") }, Width = 1.2, Lifetime = 0.5 },
				{ Colors = { Color3.fromHex("D8F4FF") }, Width = 0.35, Lifetime = 0.3 }, -- diamond-white core
			},
			-- a gold gyroscope: two crossed rings spinning opposite ways, diamond glints and gold dust
			Rings = {
				{ Radius = 0.7, Width = 0.045, Color = Color3.fromHex("FFD45A"), Tilt = { 60, 0 }, Spin = 0.6 },
				{ Radius = 0.7, Width = 0.045, Color = Color3.fromHex("FFE9A0"), Tilt = { 120, 0 }, Spin = -0.6 },
			},
			Particles = {
				{ Image = "Diamond", Colors = { Color3.fromHex("FFFFFF"), Color3.fromHex("BFEFFF") }, Rate = 10, Size = 0.14,
					Life = { 0.8, 1.4 }, Speed = { 0.05, 0.2 }, Radius = 0.85, Twinkle = true, Spin = 120 },
				{ Image = "Dot", Colors = { Color3.fromHex("FFE9A0"), Color3.fromHex("FFC030") }, Rate = 40, Size = 0.06,
					Life = { 0.8, 1.6 }, Speed = { 0.1, 0.4 }, Rise = 0.3, Radius = 0.7, Twinkle = true },
			},
			Halos = {
				{ Image = "Dot", Color = Color3.fromHex("FFC030"), Size = 2.4, Transparency = 0.55, Pulse = { 0.8, 0.1 } },
			},
			Ground = {
				{ Color = Color3.fromHex("FFE07A"), Radius = 0.9, Transparency = 0 },
				{ Color = Color3.fromHex("C98A10"), Radius = 1.2, Transparency = 0.5 },
			},
			Light = { Color = Color3.fromHex("FFC94A"), Brightness = 2.5, Range = 5 },
		},
		Lightning = {
			Trails = {
				{ Colors = { Color3.fromHex("FFFBE0"), Color3.fromHex("FFE45A") }, Width = 0.6, Lifetime = 0.45, Texture = "Bolt" },
				{ Colors = { Color3.fromHex("FFF6B0"), Color3.fromHex("FFD020"), Color3.fromHex("2A2F8F") }, Width = 1.25, Lifetime = 0.5 },
			},
			-- bolts crackle all round it, sparks spit off, and storm rings whip round fast
			Particles = {
				{ Image = "Bolt", Colors = { Color3.fromHex("FFFFFF"), Color3.fromHex("FFE45A") }, Rate = 18, Size = 0.55,
					Life = { 0.05, 0.12 }, Speed = { 0, 0.1 }, Radius = 0.62, Spin = 0 },
				{ Image = "Ember", Colors = { Color3.fromHex("FFFFFF"), Color3.fromHex("FFD020") }, Rate = 40, Size = 0.06,
					Life = { 0.15, 0.35 }, Speed = { 2, 4 }, Radius = 0.5 },
			},
			Rings = {
				{ Radius = 0.7, Width = 0.035, Color = Color3.fromHex("FFE45A"), Tilt = { 75, 20 }, Spin = 1.6 },
				{ Radius = 0.78, Width = 0.03, Color = Color3.fromHex("FFF6B0"), Tilt = { 105, -25 }, Spin = -1.2 },
				{ Radius = 0.86, Width = 0.02, Color = Color3.fromHex("6A7BFF"), Tilt = { 90, 0 }, Spin = 0.8 },
			},
			Halos = {
				{ Image = "Dot", Color = Color3.fromHex("FFD020"), Size = 2.6, Transparency = 0.5, Pulse = { 2.5, 0.15 } },
				{ Image = "Bolt", Color = Color3.fromHex("FFF6B0"), Size = 1.9, Transparency = 0.6, Spin = 90 },
			},
			Light = { Color = Color3.fromHex("FFD84A"), Brightness = 2.5, Range = 5, Flicker = 0.9 },
		},
		Daybreak = {
			Trails = {
				{
					-- night to sunrise along the trail
					Colors = { Color3.fromHex("FFE9A0"), Color3.fromHex("FF9C7A"), Color3.fromHex("FF7AB0"), Color3.fromHex("3A3A9A") },
					Width = 1.3,
					Lifetime = 0.55,
				},
				{ Colors = { Color3.fromHex("FFF6D8") }, Width = 0.4, Lifetime = 0.35 },
			},
			-- a rising sun behind it (turning rays), stars twinkling round the night side, sun sparks
			Halos = {
				{ Image = "Burst", Color = Color3.fromHex("FFE0B0"), Size = 2.5, Transparency = 0.8, Spin = 18, Pulse = { 0.5, 0.12 } },
				{ Image = "Dot", Color = Color3.fromHex("FF7AB0"), Size = 2.5, Transparency = 0.55, Pulse = { 0.5, 0.1 } },
			},
			Rings = {
				{ Radius = 0.74, Width = 0.04, Color = Color3.fromHex("FFD27A"), Tilt = { 80, 10 }, Spin = 0.5 },
				{ Radius = 0.84, Width = 0.03, Color = Color3.fromHex("FF8FC0"), Tilt = { 100, -15 }, Spin = -0.4 },
			},
			Particles = {
				{ Image = "Star", Colors = { Color3.fromHex("FFFFFF"), Color3.fromHex("FFE9A0"), Color3.fromHex("C8C8FF") }, Rate = 22,
					Size = 0.17, Life = { 0.6, 1.2 }, Speed = { 0.05, 0.2 }, Radius = 0.9, Twinkle = true, Spin = 45 },
				{ Image = "Dot", Colors = { Color3.fromHex("FFD27A"), Color3.fromHex("FF7AB0"), Color3.fromHex("8A7AFF") }, Rate = 40,
					Size = 0.05, Life = { 0.5, 1 }, Speed = { 0.2, 0.6 }, Radius = 0.5, Twinkle = true },
			},
			Ground = {
				{ Color = Color3.fromHex("FFD27A"), Radius = 0.9, Transparency = 0 },
				{ Color = Color3.fromHex("FF7AB0"), Radius = 1.2, Transparency = 0.5 },
			},
			Light = { Color = Color3.fromHex("FFA88A"), Brightness = 2.5, Range = 5 },
		},
	},
}

-- THE RARITY LADDER (Phase X Part 2), lowest first: zone ranges, crate odds, case accents and pets all read it.
-- SellCoins = coins paid when a crate gives a ball you already own.
-- To add a tier above Mythic: add a row at the end (and a Config.Showcase.Styles accent, a Config.Economy.Polish
-- GemPrice, a Config.Economy.Mascots Odds/Bonus and a Config.RarityPower row); nothing else needs code changes.
Config.Rarities = {
	{ Name = "Common", Color = Color3.fromRGB(200, 200, 210), SellCoins = 100 },
	{ Name = "Uncommon", Color = Color3.fromRGB(90, 230, 110), SellCoins = 250 },
	{ Name = "Rare", Color = Color3.fromRGB(60, 160, 255), SellCoins = 750 },
	{ Name = "Epic", Color = Color3.fromRGB(180, 80, 255), SellCoins = 2500 },
	{ Name = "Legendary", Color = Color3.fromRGB(255, 190, 40), SellCoins = 10000 },
	{ Name = "Mythic", Color = Color3.fromRGB(255, 50, 120), SellCoins = 50000 },
}
-- Reserved names for future tiers above Mythic (Phase X Part 8B). Names only: no content, art or odds yet.
-- Move one into Config.Rarities (with a colour and SellCoins) to switch it on.
Config.ReservedRarities = { "Cosmic", "Celestial", "Eternal" }

-- Power per rarity (Phase X Part 8B), the one table to tune rarity strength:
--   Ball = a typical ball's coin multiplier at that rarity (the zone 2 averages from the audit). Balls keep their own
--          Multiplier (small differences inside a rarity); a new ball row can leave Multiplier out to get this one.
--   Pet  = a pet's coin AND XP bonus before its egg's BonusScale (Config.Economy.Mascots.Bonus fills from this).
-- Step = how much stronger each rarity is than the one below, measured from Common to Mythic (balls x1.82, pets
-- x2.37 per tier); reserved tiers (Config.ReservedRarities) get Mythic x Step, x Step^2 ... automatically.
Config.RarityPower = {
	Step = { Ball = 1.82, Pet = 2.37 },
	Common = { Ball = 1.13, Pet = 0.2 },
	Uncommon = { Ball = 1.45, Pet = 0.5 },
	Rare = { Ball = 2.13, Pet = 1.0 },
	Epic = { Ball = 4.0, Pet = 2.5 },
	Legendary = { Ball = 8.5, Pet = 6 },
	Mythic = { Ball = 22.5, Pet = 15 },
}
do
	-- Reserved tiers above the last real one: the previous tier x Step (Cosmic 41 / 35.6, Celestial 74.6 / 84.4,
	-- Eternal 135.8 / 200)
	local last = Config.RarityPower[Config.Rarities[#Config.Rarities].Name]
	for _, name in Config.ReservedRarities do
		if not Config.RarityPower[name] then
			last = { Ball = last.Ball * Config.RarityPower.Step.Ball, Pet = last.Pet * Config.RarityPower.Step.Pet }
			Config.RarityPower[name] = last
		end
	end
end

-- Which rarities each zone's balls and pets can be (Phase X Part 2). Zone crates and eggs only hold items in their
-- zone's range; crate odds below are built from it (Config.CrateTiers). Zones 5+ are not built (launch = zones 1-4).
Config.ZoneRarity = {
	[1] = { Min = "Common", Max = "Rare" }, -- Back Alley: junk balls, low rarities
	[2] = { Min = "Uncommon", Max = "Epic" }, -- Neon Lanes
	[3] = { Min = "Rare", Max = "Legendary" }, -- Main Street Lanes
	[4] = { Min = "Epic", Max = "Mythic" }, -- Skyline Lanes
}

-- Every ball in the game. Adding a ball = adding a row.
-- Multiplier: coin multiplier while equipped. Forgiveness: widens the gold zone (x Config.Throw.ForgivenessScale, 0.05 = 50%).
-- Color/Material: the ball itself. Trail: the streak it leaves down the lane.
-- Traits: { TraitId = strength } using the rows in Config.Traits. Leave it out for no trait.
-- Keep each trait on a ladder so higher rarities are always clearly stronger:
--   Curve      Common 5%   Uncommon 12%  Rare 25%   Epic 35%   Mythic 60%
--   Blast      Uncommon 15%  Rare 35%  Epic 50%  Legendary 75%  Mythic 100%
--   Heavy      Common 5%   Uncommon 15%  Epic 40%   Mythic 80%
--   Lucky      Common 10%  Uncommon 30%  Rare 75%   Epic 125%  Legendary 200%
--   GemHunter  Common 1%   Epic 6-8%     Legendary 15%
--   StreakSaver (seconds between saves, lower = better)  Rare 60  Legendary 45  Mythic 30
-- Epic and up get two traits.
-- InCrates = false keeps a ball out of crates (the starter ball).
-- Zone = the zone's own crate (Config.Crates ZoneBallsOnly) gives only that zone's balls (owner 2026-10-21: every
-- crate is zone-only now). Zone 1 (Back Alley) balls have weaker traits than zone 2 (Neon Lanes) balls of the same
-- rarity, about half (owner 2026-10-21): Common Lucky 5% / Heavy 3%, Uncommon Curve 6%, Rare Blast 20%.
Config.Balls = {
	-- Common
	{
		Id = "Rookie",
		Name = "Rookie Ball",
		Rarity = "Common",
		Multiplier = 1.0,
		Forgiveness = 0,
		Color = Color3.fromRGB(0, 220, 255),
		Material = Enum.Material.Neon,
		Trail = Color3.fromHex("EFB65A"), -- (Polish v2 L6: its v2 paint; was Color3.fromRGB(0, 220, 255))
		InCrates = false,
	},
	{
		Id = "Bubblegum",
		Zone = 1, -- moved from Neon Lanes to the Back Alley (Phase X: zone 2 starts at Uncommon), numbers unchanged
		Name = "Bubblegum",
		Rarity = "Common",
		Multiplier = 1.05,
		Forgiveness = 0,
		Color = Color3.fromRGB(255, 130, 200),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromHex("FC5746"), -- (Polish v2 L6: its v2 paint; was Color3.fromRGB(255, 170, 220))
		Traits = { Lucky = 0.1 },
	},
	{
		Id = "Lime",
		Zone = 1, -- moved from Neon Lanes to the Back Alley (Phase X: zone 2 starts at Uncommon), numbers unchanged
		Name = "Lime Twist",
		Rarity = "Common",
		Multiplier = 1.1,
		Forgiveness = 0,
		Color = Color3.fromRGB(160, 255, 60),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromHex("F587AF"), -- (Polish v2 L6: its v2 paint; was Color3.fromRGB(190, 255, 120))
		Traits = { Curve = 0.05 },
	},
	{
		Id = "Tangerine",
		Zone = 1, -- moved from Neon Lanes to the Back Alley (Phase X: zone 2 starts at Uncommon), numbers unchanged
		Name = "Tangerine",
		Rarity = "Common",
		Multiplier = 1.15,
		Forgiveness = 0,
		Color = Color3.fromRGB(255, 150, 40),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromHex("F9C66D"), -- (Polish v2 L6: its v2 paint; was Color3.fromRGB(255, 190, 90))
		Traits = { Heavy = 0.05 },
	},
	{
		Id = "Ocean",
		Zone = 1, -- moved from Neon Lanes to the Back Alley (Phase X: zone 2 starts at Uncommon), numbers unchanged
		Name = "Deep Ocean",
		Rarity = "Common",
		Multiplier = 1.2,
		Forgiveness = 0.005,
		Color = Color3.fromRGB(30, 90, 200),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromHex("D28674"), -- (Polish v2 L6: its v2 paint; was Color3.fromRGB(60, 140, 255))
		Traits = { GemHunter = 0.01 },
	}, -- Back Alley balls (owner's "Back Alley Bowling Assets" design, 2026-10-20): junk turned into prizes
	{
		Id = "DuctTape",
		Zone = 1, -- a Back Alley ball: the Alley Crate only gives these
		Name = "Duct Tape",
		Rarity = "Common",
		Multiplier = 1.1,
		Forgiveness = 0,
		Color = Color3.fromHex("C0C4C9"),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromHex("DB794F"), -- (Polish v2 L6: its v2 paint; was Color3.fromHex("C7CCD2"))
		Traits = { Lucky = 0.05 },
	},
	{
		Id = "RustBucket",
		Zone = 1, -- a Back Alley ball: the Alley Crate only gives these
		Name = "Rust Bucket",
		Rarity = "Common",
		Multiplier = 1.15,
		Forgiveness = 0,
		Color = Color3.fromHex("D2692A"),
		Material = Enum.Material.Metal,
		Trail = Color3.fromHex("DC9A4D"), -- (Polish v2 L6: its v2 paint; was Color3.fromHex("D2692A"))
		Traits = { Heavy = 0.03 },
	},

	-- Uncommon
	{
		Id = "Electric",
		Zone = 2, -- a Neon Lanes ball: the zone 2 crates only give these
		Name = "Electric Blue",
		Rarity = "Uncommon",
		Multiplier = 1.3,
		Forgiveness = 0.01,
		Color = Color3.fromRGB(40, 120, 255),
		Material = Enum.Material.Neon,
		Trail = Color3.fromHex("3ACEDA"), -- (Polish v2 L6: its v2 paint; was Color3.fromRGB(120, 200, 255))
		Traits = { Curve = 0.12 },
	},
	{
		Id = "Toxic",
		Zone = 2, -- a Neon Lanes ball: the zone 2 crates only give these
		Name = "Toxic Slime",
		Rarity = "Uncommon",
		Multiplier = 1.4,
		Forgiveness = 0.01,
		Color = Color3.fromRGB(90, 255, 40),
		Material = Enum.Material.Neon,
		Trail = Color3.fromHex("34CDD5"), -- (Polish v2 L6: its v2 paint; was Color3.fromRGB(140, 255, 60))
		Traits = { Blast = 0.15 },
	},
	{
		Id = "Sunset",
		Zone = 2, -- a Neon Lanes ball: the zone 2 crates only give these
		Name = "Sunset Strip",
		Rarity = "Uncommon",
		Multiplier = 1.5,
		Forgiveness = 0.015,
		Color = Color3.fromRGB(255, 90, 60),
		Material = Enum.Material.Neon,
		Trail = Color3.fromHex("FF735E"), -- (Polish v2 L6: its v2 paint; was Color3.fromRGB(255, 200, 60))
		Traits = { Lucky = 0.3 },
	},
	{
		Id = "Frostbite",
		Zone = 2,
		Retired = true, -- Phase X: cut from Neon Lanes to bring it to 9 balls. Out of every crate; owners keep it
		Name = "Frostbite",
		Rarity = "Uncommon",
		Multiplier = 1.6,
		Forgiveness = 0.015,
		Color = Color3.fromRGB(180, 240, 255),
		Material = Enum.Material.Ice,
		Trail = Color3.fromHex("49B7F8"), -- (Polish v2 L6: its v2 paint; was Color3.fromRGB(200, 250, 255))
		Traits = { Heavy = 0.15 },
	},
	{
		Id = "Hubcap",
		Zone = 1, -- a Back Alley ball: the Alley Crate only gives these
		Name = "Hubcap",
		Rarity = "Uncommon",
		Multiplier = 1.4,
		Forgiveness = 0.01,
		Color = Color3.fromHex("E9EEF3"),
		Material = Enum.Material.Metal,
		Trail = Color3.fromHex("E49665"), -- (Polish v2 L6: its v2 paint; was Color3.fromHex("7DF0A6"))
		Traits = { Curve = 0.06 },
	},

	-- Rare
	{
		Id = "Magma",
		Zone = 2, -- a Neon Lanes ball: the zone 2 crates only give these
		Name = "Magma Core",
		Rarity = "Rare",
		Multiplier = 1.8,
		Forgiveness = 0.02,
		Color = Color3.fromRGB(255, 70, 20),
		Material = Enum.Material.CrackedLava,
		Trail = Color3.fromHex("FE7460"), -- (Polish v2 L6: its v2 paint; was Color3.fromRGB(255, 120, 30))
		Traits = { Blast = 0.35 },
	},
	{
		Id = "Galaxy",
		Zone = 2, -- a Neon Lanes ball: the zone 2 crates only give these
		Name = "Galaxy",
		Rarity = "Rare",
		Multiplier = 2.0,
		Forgiveness = 0.02,
		Color = Color3.fromRGB(90, 40, 180),
		Material = Enum.Material.Neon,
		Trail = Color3.fromHex("F03931"), -- (Polish v2 L6: its v2 paint; was Color3.fromRGB(200, 120, 255))
		Traits = { Lucky = 0.75 },
	},
	{
		Id = "Thunder",
		Zone = 2, -- a Neon Lanes ball: the zone 2 crates only give these
		Name = "Thunderstrike",
		Rarity = "Rare",
		Multiplier = 2.2,
		Forgiveness = 0.025,
		Color = Color3.fromRGB(255, 240, 60),
		Material = Enum.Material.Neon,
		Trail = Color3.fromHex("FF9A4C"), -- (Polish v2 L6: its v2 paint; was Color3.fromRGB(255, 255, 160))
		Traits = { StreakSaver = 60 },
	},
	{
		Id = "Phantom",
		Zone = 2,
		Retired = true, -- Phase X: cut from Neon Lanes to bring it to 9 balls. Out of every crate; owners keep it
		Name = "Phantom",
		Rarity = "Rare",
		Multiplier = 2.5,
		Forgiveness = 0.025,
		Color = Color3.fromRGB(220, 220, 255),
		Material = Enum.Material.ForceField,
		Trail = Color3.fromHex("C8BA58"), -- (Polish v2 L6: its v2 paint; was Color3.fromRGB(180, 180, 255))
		Traits = { Curve = 0.25 },
	},
	{
		Id = "DumpsterDiamond",
		Zone = 1, -- a Back Alley ball: the Alley Crate only gives these
		Name = "Dumpster Diamond",
		Rarity = "Rare",
		Multiplier = 2.0,
		Forgiveness = 0.02,
		Color = Color3.fromHex("3CC8FF"),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromHex("FF8CBD"), -- (Polish v2 L6: its v2 paint; was Color3.fromHex("38C6FF"))
		Traits = { Blast = 0.2 },
	},

	-- Epic
	{
		Id = "Plasma",
		Zone = 2, -- a Neon Lanes ball: the zone 2 crates only give these
		Name = "Plasma Orb",
		Rarity = "Epic",
		Multiplier = 3.0,
		Forgiveness = 0.03,
		Color = Color3.fromRGB(255, 40, 220),
		Material = Enum.Material.Neon,
		Trail = Color3.fromHex("C87154"), -- (Polish v2 L6: its v2 paint; was Color3.fromRGB(255, 120, 240))
		Traits = { Heavy = 0.4, GemHunter = 0.06 },
	},
	{
		Id = "Nebula",
		Zone = 2, -- a Neon Lanes ball: the zone 2 crates only give these
		Name = "Nebula",
		Rarity = "Epic",
		Multiplier = 4.0,
		Forgiveness = 0.035,
		Color = Color3.fromRGB(120, 60, 255),
		Material = Enum.Material.Neon,
		Trail = Color3.fromHex("6DDCE3"), -- (Polish v2 L6: its v2 paint; was Color3.fromRGB(255, 90, 200))
		Traits = { Lucky = 1.25, GemHunter = 0.08 },
	},
	{
		Id = "Inferno",
		Zone = 2, -- a Neon Lanes ball: the zone 2 crates only give these
		Name = "Inferno",
		Rarity = "Epic",
		Multiplier = 5.0,
		Forgiveness = 0.035,
		Color = Color3.fromRGB(255, 100, 0),
		Material = Enum.Material.Neon,
		Trail = Color3.fromHex("CEAA5B"), -- (Polish v2 L6: its v2 paint; was Color3.fromRGB(255, 40, 0))
		Traits = { Blast = 0.5, Curve = 0.35 },
	},
	-- Legendary
	{
		Id = "Golden",
		Zone = 2,
		Retired = true, -- Phase X: too rare for Neon Lanes; zone 4's Sunburst reuses its model. Out of every crate; owners keep it
		Name = "Golden Strike",
		Rarity = "Legendary",
		Multiplier = 7.0,
		Forgiveness = 0.04,
		Color = Color3.fromRGB(255, 200, 40),
		Material = Enum.Material.Foil,
		Trail = Color3.fromHex("D02934"), -- (Polish v2 L6: its v2 paint; was Color3.fromRGB(255, 230, 120))
		Traits = { Lucky = 2.0, GemHunter = 0.15 },
	},
	{
		Id = "Dragon",
		Zone = 2,
		Retired = true, -- Phase X: too rare for Neon Lanes; zone 4's Solid Gold reuses its model. Out of every crate; owners keep it
		Name = "Dragon's Eye",
		Rarity = "Legendary",
		Multiplier = 10.0,
		Forgiveness = 0.045,
		Color = Color3.fromRGB(200, 20, 40),
		Material = Enum.Material.Neon,
		Trail = Color3.fromHex("58CAD9"), -- (Polish v2 L6: its v2 paint; was Color3.fromRGB(255, 160, 0))
		Traits = { Blast = 0.75, StreakSaver = 45 },
	},
	-- Mythic
	{
		Id = "Void",
		Zone = 2,
		Retired = true, -- Phase X: too rare for Neon Lanes; zone 4's Lightning reuses its model. Out of every crate; owners keep it
		Name = "The Void",
		Rarity = "Mythic",
		Multiplier = 20.0,
		Forgiveness = 0.05,
		Color = Color3.fromRGB(15, 0, 30),
		Material = Enum.Material.Neon,
		Trail = Color3.fromHex("FFC93A"), -- (Polish v2 L6: its v2 paint; was Color3.fromRGB(150, 0, 255))
		Traits = { Curve = 0.6, StreakSaver = 30 },
	},
	{
		Id = "Supernova",
		Zone = 2,
		Retired = true, -- Phase X: too rare for Neon Lanes; zone 4's Daybreak reuses its model. Out of every crate; owners keep it
		Name = "Supernova",
		Rarity = "Mythic",
		Multiplier = 25.0,
		Forgiveness = 0.05,
		Color = Color3.fromRGB(255, 255, 255),
		Material = Enum.Material.Neon,
		Trail = Color3.fromHex("FFCC51"), -- (Polish v2 L6: its v2 paint; was Color3.fromRGB(255, 220, 120))
		Traits = { Blast = 1, Heavy = 0.8 },
	},
	-- Main Street Lanes (zone 3, Phase X): classic league balls (marble, swirl, league). Real models from the owner's
	-- claude.ai/design 'Main Street Lanes Bowling Balls' (2026-10-27): ReplicatedStorage.BallModels, one shared mesh +
	-- a texture each (assets/zone3_balls). Numbers follow the Neon Lanes ladder.
	{
		Id = "LeagueBlack",
		Zone = 3,
		Name = "League Black",
		Rarity = "Rare",
		Multiplier = 2.0,
		Forgiveness = 0.02,
		Color = Color3.fromHex("1A1A22"),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromHex("77D96A"), -- (Polish v2 L6: its v2 paint; was Color3.fromHex("C21E37"))
		Traits = { Curve = 0.25 },
	},
	{
		Id = "CherrySwirl",
		Zone = 3,
		Name = "Cherry Swirl",
		Rarity = "Rare",
		Multiplier = 2.2,
		Forgiveness = 0.02,
		Color = Color3.fromHex("C21E37"),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromHex("D98541"), -- (Polish v2 L6: its v2 paint; was Color3.fromHex("E85A6E"))
		Traits = { Lucky = 0.75 },
	},
	{
		Id = "BlueMarble",
		Zone = 3,
		Name = "Blue Marble",
		Rarity = "Rare",
		Multiplier = 2.4,
		Forgiveness = 0.025,
		Color = Color3.fromHex("2A4FB8"),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromHex("FB952E"), -- (Polish v2 L6: its v2 paint; was Color3.fromHex("6E93E8"))
		Traits = { Blast = 0.35 },
	},
	{
		Id = "PearlPro",
		Zone = 3,
		Name = "Pearl Pro",
		Rarity = "Epic",
		Multiplier = 3.5,
		Forgiveness = 0.03,
		Color = Color3.fromHex("F6F1E7"),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromHex("53D7E1"), -- (Polish v2 L6: its v2 paint; was Color3.fromHex("F2B9CC"))
		Traits = { Curve = 0.35, GemHunter = 0.06 },
	},
	{
		Id = "TigerSwirl",
		Zone = 3,
		Name = "Tiger Swirl",
		Rarity = "Epic",
		Multiplier = 4.5,
		Forgiveness = 0.035,
		Color = Color3.fromHex("F08A24"),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromHex("FF9630"), -- (Polish v2 L6: its v2 paint; was Color3.fromHex("F08A24"))
		Traits = { Blast = 0.5, Lucky = 1.25 },
	},
	{
		Id = "Championship",
		Zone = 3,
		Name = "Championship",
		Rarity = "Legendary",
		Multiplier = 8.0,
		Forgiveness = 0.04,
		Color = Color3.fromHex("E2B24A"),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromHex("5DBA51"), -- (Polish v2 L6: its v2 paint; was Color3.fromHex("E2B24A"))
		Traits = { Lucky = 2, GemHunter = 0.15 },
	},
	{
		Id = "Perfect300",
		Zone = 3,
		Name = "Perfect 300",
		Rarity = "Legendary",
		Multiplier = 9.0,
		Forgiveness = 0.045,
		Color = Color3.fromHex("C21E37"),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromHex("E3A329"), -- (Polish v2 L6: its v2 paint; was Color3.fromHex("C21E37"))
		Traits = { Blast = 0.75, StreakSaver = 45 },
	},
	-- Skyline Lanes (zone 4, Phase X): sky, sun and storm balls. Real models from the owner's claude.ai/design
	-- 'Skyline Lanes' set (2026-10-27): ReplicatedStorage.BallModels, one shared mesh + a texture each
	-- (assets/zone4_balls); Crystal's glowing core is a BallFxPieces piece. Numbers unchanged.
	{
		Id = "CloudSwirl",
		Zone = 4,
		Name = "Cloud Swirl",
		Rarity = "Epic",
		Multiplier = 4.0,
		Forgiveness = 0.035,
		Color = Color3.fromHex("5AAEE8"),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromHex("73C6FD"), -- (Polish v2 L6: its v2 paint; was Color3.fromHex("BFE4FF"))
		Traits = { Lucky = 1.25, GemHunter = 0.08 },
	},
	{
		Id = "Crystal",
		Zone = 4,
		Name = "Crystal",
		Rarity = "Epic",
		Multiplier = 3.0,
		Forgiveness = 0.03,
		Color = Color3.fromHex("8FE0FF"),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromHex("FFA13F"), -- (Polish v2 L6: its v2 paint; was Color3.fromHex("8FE0FF"))
		Traits = { Heavy = 0.4, GemHunter = 0.06 },
	},
	{
		Id = "Sunburst",
		Zone = 4,
		Name = "Sunburst",
		Rarity = "Legendary",
		Multiplier = 7.0,
		Forgiveness = 0.04,
		Color = Color3.fromHex("FFB52E"),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromHex("FF7916"), -- (Polish v2 L6: its v2 paint; was Color3.fromHex("FFB52E"))
		Traits = { Lucky = 2, GemHunter = 0.15 },
	},
	{
		Id = "SolidGold",
		Zone = 4,
		Name = "Solid Gold",
		Rarity = "Legendary",
		Multiplier = 10.0,
		Forgiveness = 0.045,
		Color = Color3.fromHex("F0B530"),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromHex("83B9EF"), -- (Polish v2 L6: its v2 paint; was Color3.fromHex("FFD45A"))
		Traits = { Blast = 0.75, StreakSaver = 45 },
	},
	{
		Id = "Lightning",
		Zone = 4,
		Name = "Lightning",
		Rarity = "Mythic",
		Multiplier = 20.0,
		Forgiveness = 0.05,
		Color = Color3.fromHex("141A4A"),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromHex("FFA332"), -- (Polish v2 L6: its v2 paint; was Color3.fromHex("FFE45A"))
		Traits = { Curve = 0.6, StreakSaver = 30 },
	},
	-- 2026-11-03: zone 4 ladder balls that used to share a zone 1 ball's Id (numbers copied from that ball)
	{
		Id = "Scorpion",
		Zone = 4,
		Name = "Scorpion",
		Rarity = "Legendary",
		Multiplier = 3.0,
		Forgiveness = 0.03,
		Color = Color3.fromHex("8C2C2C"),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromHex("CEA145"), -- (Polish v2 L6: its v2 paint; was Color3.fromHex("E8423A"))
		Traits = { Heavy = 0.4, GemHunter = 0.06 },
		InCrates = false,
	},
	{
		Id = "CanyonEcho",
		Zone = 4,
		Name = "Canyon Echo",
		Rarity = "Mythic",
		Multiplier = 20.0,
		Forgiveness = 0.05,
		Color = Color3.fromHex("3A233A"),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromHex("77AFD9"), -- (Polish v2 L6: its v2 paint; was Color3.fromHex("38C8C8"))
		Traits = { Curve = 0.6, StreakSaver = 30 },
		InCrates = false,
	},
	{
		Id = "Mirage",
		Zone = 4,
		Name = "Mirage",
		Rarity = "Mythic",
		Multiplier = 10.0,
		Forgiveness = 0.045,
		Color = Color3.fromHex("B4A5B9"),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromHex("4CC0D4"), -- (Polish v2 L6: its v2 paint; was Color3.fromHex("B79CFF"))
		Traits = { Blast = 0.75, StreakSaver = 45 },
		InCrates = false,
	},
	{
		Id = "Daybreak",
		Zone = 4,
		Name = "Daybreak",
		Rarity = "Mythic",
		Multiplier = 25.0,
		Forgiveness = 0.05,
		Color = Color3.fromHex("FF9C7A"),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromHex("2A82B5"), -- (Polish v2 L6: its v2 paint; was Color3.fromHex("FF9C7A"))
		Traits = { Blast = 1, Heavy = 0.8 },
	},
}

-- Crates, bought with coins: name and colour here, cheapest first. Price and Odds come from Config.Economy.Crates
-- (filled in below it), pity from Config.Economy.CratePity, duplicates from Config.Economy.Polish.
-- Looks: ReplicatedStorage.CrateModels has one model per Id (the owner's crate designs, 2026-10-28).
-- Zone = the zone that must be unlocked to open it (locked crates show blacked out: "UNLOCKS IN <zone>").
-- ZoneBallsOnly = gives only balls with that Zone (Config.Balls). Owner 2026-10-21: zone 1 = the Alley Crate with
-- the Back Alley balls only; the zone 2 crates (Bronze, Silver, Gold) give only the Neon Lanes balls.
Config.Crates = {
	{ Id = "Basic", Name = "Alley Crate", Color = Color3.fromRGB(60, 200, 255), Zone = 1, ZoneBallsOnly = true },
	{
		Id = "Bronze",
		Name = "Bronze Crate",
		Color = Color3.fromRGB(215, 135, 70),
		Zone = 2,
		ZoneBallsOnly = true,
		Tier = "Bronze",
	},
	{
		Id = "Silver",
		Name = "Silver Crate",
		Color = Color3.fromRGB(200, 215, 235),
		Zone = 2,
		ZoneBallsOnly = true,
		Tier = "Silver",
	},
	{
		Id = "Gold",
		Name = "Gold Crate",
		Color = Color3.fromRGB(255, 200, 40),
		Zone = 2,
		ZoneBallsOnly = true,
		Tier = "Gold",
	},
	-- Phase X: zone 3 has 2 crates, zone 4 has 3. Model = the CrateModels look used if the crate's own model is missing.
	{
		Id = "League",
		Name = "League Crate",
		Color = Color3.fromRGB(176, 112, 60),
		Zone = 3,
		ZoneBallsOnly = true,
		Tier = "Bronze",
		Model = "Bronze",
	},
	{
		Id = "Champion",
		Name = "Champion Crate",
		Color = Color3.fromRGB(224, 165, 38),
		Zone = 3,
		ZoneBallsOnly = true,
		Tier = "Gold",
		Model = "Gold",
	},
	{
		Id = "SkyBronze",
		Name = "Sky Bronze Crate",
		Color = Color3.fromRGB(240, 160, 110),
		Zone = 4,
		ZoneBallsOnly = true,
		Tier = "Bronze",
		Model = "Bronze",
	},
	{
		Id = "SkySilver",
		Name = "Sky Silver Crate",
		Color = Color3.fromRGB(190, 220, 255),
		Zone = 4,
		ZoneBallsOnly = true,
		Tier = "Silver",
		Model = "Silver",
	},
	{
		Id = "SkyGold",
		Name = "Sky Gold Crate",
		Color = Color3.fromRGB(255, 79, 139),
		Zone = 4,
		ZoneBallsOnly = true,
		Tier = "Gold",
		Model = "Gold",
	},
	-- The Neon Crate (5.9B) is out of the game for now (owner 2026-10-21): it gets a new name and a later zone once
	-- the new economy is in. Its Config.Economy.Crates row stays for the simulator; old saves keep its pity.
}

-- Pet fusion station in zone 3 (Phase X Part 6): the only place the Shiny merge happens (3 copies of a pet = its Shiny).
-- Its prompt opens the PET FUSION window. Batch C2 (owner 2026-10-29): the PETS panel has no MERGE button any more,
-- and the server refuses a merge unless zone 3 is open and the player stands within Range of the machine.
-- Look = the owner's pet_fusion_machine design (2026-10-29), with an invisible Counter part for the prompt.
Config.Fusion = {
	Enabled = true,
	Zone = 3,
	Path = { "MainStreetLanes", "FusionStation" }, -- owner's fusion machine, placed in Studio
	Range = 20, -- studs (flat) from the machine; the prompt opens at 12, a little extra so a small step back still fuses
}
-- Addendum 5 B2: in the core loop the merge happens at the roof's copy of the machine (Config.CoreLoop.Eggs.Fusion),
-- open to everyone (no zone)
if Config.CoreLoop.Enabled and Config.CoreLoop.Eggs.Enabled then
	Config.Fusion.Zone = 1
	Config.Fusion.Path = { Config.CoreLoop.Folder, Config.CoreLoop.Eggs.Fusion.Name }
end

-- Zone 4 boss event: the Pin Titan (owner's milestone 2026-10-26). Every EverySeconds the whole server gets one event:
-- a countdown in the zone 4 lobby, a siren SirenSeconds before boarding opens, then BoardingSeconds to walk up to the
-- helicopter on the Skyline roof. Everyone who boarded flies to the sky arena (Workspace.TitanArena) and fights the
-- Titan with the normal hold-and-release throw (auto-aimed). Fight: ARMOR (plates) -> CORE (glowing core open) ->
-- FINALE (hits fill one team meter; full = every player's next throw is a GIANT BALL that finishes the Titan).
-- FightSeconds is a hard cap: at 0 the Titan escapes and the players lose (owner 2026-10-26). Then the results
-- screen and the ride back to the roof. Art is PLACEHOLDER (a big plain pin, a round floating platform): a model saved in Studio
-- as Workspace.TitanArena wins over the code-built one (keep the part names: Floor, Spots, Titan.Plates/Core/Body).
-- All numbers below are safe to tune; nothing else needs changing.
Config.Boss = {
	Enabled = not Config.CoreLoop.Enabled, -- the helicopter + Pin Titan arena are switched off in the Addendum 4 core loop
	Zone = 4, -- you need this zone unlocked to board
	EverySeconds = 45 * 60, -- an event every 45 minutes (on the clock: :00 and :45 slots, same on every server)
	StudioFirstEventIn = 25, -- Studio only: the first event opens this many seconds after you press Play (0 = off)
	SirenSeconds = 30, -- the siren warning starts this long before boarding opens
	BoardingSeconds = 60, -- how long the helicopter waits for players
	MinPlayers = 1, -- fewer boarders than this = the event is cancelled (next 45-minute slot)
	MaxPlayers = 16, -- seats on the helicopter (= throw spots around the arena)
	Helipad = { "SkylineLanes", "Design", "helipad" }, -- the real helipad on the roof (owner's design; the old code-built
	-- "SkylineLanes.Helipad" placeholder is only used if this is missing)
	Helicopter = "helicopter", -- the helicopter model inside it: players hold E on it to board (always parked there)
	PadPart = "helipad_deck", -- the pad part inside it: boarding range, landing spots and the sign sit on this
	Arena = { "TitanArena" }, -- the sky arena (built in code if missing)
	UseRange = 26, -- studs from the helipad the server accepts boarding from
	LobbyArea = { Center = Vector3.new(0, 870, -3500), Size = Vector3.new(220, 60, 236) }, -- the roof: the countdown and siren show here
	FlightSeconds = 2.5, -- the fade-out while the helicopter takes off (and on the way back)

	-- The fight
	FightSeconds = 180, -- hard timer: if the giant balls haven't started by then, the Titan ESCAPES (players lose)
	LossRewardShare = 0.25, -- a loss still pays this share of your tier's coins (no crate, top bonus or drop; 0 = nothing)
	IntroSeconds = 4, -- "PIN TITAN!" intro before the first throw counts
	HealthPerPlayer = 10000, -- the Titan's health = this x players in the arena when the fight starts...
	MinHealth = 10000, -- ...but never less than this (so a fight never ends in seconds)
	ArmorShare = 0.33, -- the first third of its health is armor plates
	Plates = 6, -- how many plates the armor is split into (the owner's Titan has 6)
	FinaleAt = 0.15, -- the finale starts when its health falls to this share
	MeterPerPlayer = 1500, -- team meter size = this x players (filled by damage during the finale)
	GiantSeconds = 12, -- after the meter fills, players have this long to throw their giant ball
	ResultsSeconds = 10, -- the results screen, then the ride back
	ThrowCooldown = 2.2, -- seconds after a throw lands before your next one
	BallTravel = 0.7, -- seconds the ball flies to the Titan (damage lands when it hits)

	-- Damage per throw = BaseDamage x charge factor x kind x power x streak (x phase rule)
	BaseDamage = 100, -- a full-power normal throw
	WeakestShare = 0.5, -- an empty-bar tap does this share of BaseDamage
	PerfectMultiplier = 3, -- a PERFECT (gold, or a Curve ball's hook)
	OverchargeMultiplier = 6, -- a red-cap gamble that pays off (fails half the time like on the lanes: 0 damage)
	StreakBonus = 0.15, -- each PERFECT in a row adds this much (x1.15, x1.3, ...)
	StreakMax = 2.5, -- streak bonus cap
	PowerBonusPerLevel = 0.02, -- each Power Level adds this much damage...
	PowerBonusMax = 1.5, -- ...up to this (so low levels still matter)
	ArmorNormalShare = 0.2, -- armor: a non-PERFECT throw only chips the plates (strikes break them)
	CorePerfectBonus = 1.5, -- core open: PERFECT hits do this much more on top

	-- The Titan fights back (owner 2026-10-26): it throws pins at players and rolls giant balls across the arena.
	-- Players walk freely and throw from anywhere on the platform (the throw is still auto-aimed); standing still to
	-- charge makes you an easy target. A red circle or stripe on the floor warns where it lands; get out of it.
	-- Hit = knocked back, DAZED (no throwing) and your PERFECT streak is gone.
	Attacks = {
		-- per phase: seconds between attacks (+-15% random) and which attacks it picks from
		Armor = { Every = 4, Kinds = { "PinToss", "PinToss", "BallRoll" } },
		Core = { Every = 3.2, Kinds = { "PinToss", "BallRoll", "PinRain" } },
		Finale = { Every = 2.4, Kinds = { "PinRain", "BallRoll", "PinToss" } },
		FirstAfter = 2, -- seconds after the fight starts before the first attack
	},
	PinToss = { Warning = 1.4, Radius = 8, PlayersPerPin = 2 }, -- a pin at a player (1 pin per 2 players, at least 1)
	PinRain = { Warning = 1.5, Radius = 7, Count = 4, PerPlayer = 1 }, -- many pins: Count + PerPlayer x players
	BallRoll = { Warning = 1.4, Width = 12, Speed = 75 }, -- a giant ball rolls across the arena along a red stripe
	Hit = {
		DazedSeconds = 2, -- no throwing for this long after a hit
		SafeSeconds = 2.5, -- can't be hit again this soon
		Knockback = 70, -- how hard a hit shoves you (studs per second)
		Leniency = 2, -- the hit area is this many studs smaller than the red warning (the server sees you a moment late)
	},

	-- Rewards. Tier by your damage compared to a fair share (total damage / players). Same row format as
	-- Config.Milestones rewards: Coins (or LevelShare of your next Power Level's price, whichever is more), Potions, Crate.
	MinHits = 1, -- throws you need to land to get a reward (stand still = nothing)
	Tiers = {
		{ Name = "BRONZE", MinShare = 0, Reward = { Coins = 1000000000, LevelShare = 0.2 } },
		{ Name = "SILVER", MinShare = 0.5, Reward = { Coins = 2000000000, LevelShare = 0.3, Crate = "SkyBronze" } },
		{ Name = "GOLD", MinShare = 1, Reward = { Coins = 5000000000, LevelShare = 0.5, Crate = "SkyBronze" } },
		{ Name = "TITAN", MinShare = 1.5, Reward = { Coins = 8000000000, LevelShare = 0.7, Crate = "SkySilver" } },
	},
	TopBonus = { -- extra for the top damage dealers (rank 1, 2, 3)
		{ Coins = 3000000000, LevelShare = 0.3 },
		{ Coins = 1500000000, LevelShare = 0.15 },
		{ Coins = 750000000, LevelShare = 0.1 },
	},
	-- The boss-only drop. Kind = "Pet" (a Config.Mascots Id), "Ball" (a Config.Balls Id) or "Crate" (a crate Id).
	Drop = { Kind = "Pet", Id = "TitanJr", Chance = 0.1, TopChance = 0.25 }, -- TopChance = rank 1's chance
}

-- Crate counters in zones 3 and 4 (Phase X; the owner's counter designs, put in Studio 2026-10-28): walk up and the prompt opens the crate
-- shop screen, which lists every crate (each zone's crates unlock with the zone). Path = the booth under Workspace.
Config.ZoneShops = {
	{ Path = { "MainStreetLanes", "CrateShop" }, Zone = 3 },
	{ Path = { "SkylineLanes", "CrateShop" }, Zone = 4 },
}

-- Rizzo, the Back Alley crate dealer (owner's "Rizzo's Crate Cart" design), at Workspace.BackAlley.RizzoStand.
-- His cart's pink BuyPad sells the zone's crate; his lines come from the design.
Config.Rizzo = {
	CrateId = "Basic", -- the Alley Crate
	GreetDistance = 16, -- studs from the buy pad: Rizzo says hi
	ByeDistance = 24, -- walk this far away again: goodbye
	BubbleTime = 3.5, -- seconds a line stays up
	TypeSpeed = 45, -- letters per second
	TurntableSpin = 0.15, -- turns per second
	AnimateDistance = 90, -- only animate while your camera is this close
	Bob = 0.06, -- studs he bobs while idle
	WaveTime = 1.4, -- seconds a wave lasts
	RareFrom = "Rare", -- pulls of this rarity or better get the "something rare" line
	Lines = {
		Greeting = "Psst, kid, over here! Rizzo's got crates full of surprises.",
		Opening = "Luck's a lane, kid. Let's see where yours rolls!",
		Rare = "Whoa, a rare one! Shh, don't tell anyone where you got it.",
		CantAfford = "Aw, not enough coins yet? Knock down some pins and come right back!",
		Goodbye = "See ya, kid! Keep it out of the gutter.",
		CallOver = "Psst! You got the coins now, kid. Your first crate's on discount, come get it!", -- your first crate is affordable
	},
	FirstCrateMarker = true, -- a bouncing "!" over Rizzo (seen through walls) while your first crate waits for you
}

-- Day 1 video intro (Studio only, never in the live game): press Key in Play mode and the camera flies through the
-- Back Alley in 4 hard-cut shots, about 10 s, with the HUD hidden, then you throw a strike and it ends behind the
-- pins and cuts to black (Throw). Record the window (resize it tall for 9:16).
-- Each shot moves the camera From -> To (Pos = where it is, Look = what it looks at) over Time seconds.
-- Text = big caption, Rizzo = his speech bubble line (he waves too), Deal = show the FIRST CRATE % OFF sign.
Config.IntroCinematic = {
	Enabled = not Config.CoreLoop.Enabled, -- (Studio-only video intro in the Back Alley; off in the core loop)
	Key = Enum.KeyCode.K,
	Lane = "Lane3", -- your character stands on this Back Alley lane's approach, facing the pins
	FieldOfView = 70,
	Shots = {
		{ -- hook: low drift through the junk at the back of the alley
			Time = 2.2,
			From = { Pos = Vector3.new(-26, 2.6, 206), Look = Vector3.new(-8, 3, 140) },
			To = { Pos = Vector3.new(-18, 3.4, 190), Look = Vector3.new(-6, 3, 140) },
			Text = "POV: you're a homeless bowler",
		},
		{ -- slow push down to you, standing at a beat-up lane
			Time = 3,
			From = { Pos = Vector3.new(6, 6.5, 172), Look = Vector3.new(-7, 3.5, 146) },
			To = { Pos = Vector3.new(-1, 4.6, 157), Look = Vector3.new(-7, 3.5, 145) },
			Text = "0 coins.",
		},
		{ -- Rizzo waves from his cart
			Time = 3,
			From = { Pos = Vector3.new(12, 5.5, 158), Look = Vector3.new(14, 6.5, 176) },
			To = { Pos = Vector3.new(13.2, 6, 161.5), Look = Vector3.new(14, 6.5, 176) },
			Rizzo = "You? A bowler? Prove it.",
		},
		{ -- snap to the first crate deal
			Time = 2,
			From = { Pos = Vector3.new(13, 7, 160), Look = Vector3.new(14, 7, 170) },
			To = { Pos = Vector3.new(13.8, 7.2, 163), Look = Vector3.new(14, 7, 170) },
			Text = "Day 1.",
			Deal = true,
		},
	},
	-- After the shots: you throw for real (ThrowUI only, the whole arc gold, any release is a PERFECT strike). Just
	-- before the ball reaches the pins the camera cuts behind the pins, then the screen cuts to black and it ends.
	Throw = {
		Text = nil, -- caption while you throw (nil = none; the throw bar says HOLD... THEN LET GO!)
		WaitLimit = 30, -- seconds to wait for your throw before the intro gives up
		CutBefore = 0.35, -- seconds before the ball reaches the pins that the pin camera cuts in (a roll takes about 0.6 s)
		Hold = 2.2, -- seconds on the pin camera after the hit (the strike slow motion plays inside this)
		Black = 1.5, -- seconds of black at the very end
		-- Pin camera, measured from the lane's PinSpot: Back = studs behind the pins, Up = height, Side = to the
		-- right (seen from the bowler), LookAt = studs up the lane it looks at
		PinCam = { Back = 6, Up = 2.2, Side = 1.2, LookAt = 14, LookUp = 0.8 },
	},
}

-- Join intro (batch B, 2026-10-29): a short fly-over of the Back Alley for brand new players only (first join,
-- before the first throw), in the live game too. Covers asset loading and shows what the game is in 7 seconds.
-- SKIP shows after SkipAfter seconds. Shots work like Config.IntroCinematic's (camera From -> To, a caption, an
-- optional Rizzo line, Deal = his first crate deal sign). Then the camera glides back behind your character.
-- Studio: TEST panel > NEXT PLAY TEST STARTS FROM ZERO shows it (a saved player never sees it).
Config.JoinIntro = {
	Enabled = true,
	SkipAfter = 1,
	-- Title card before the shots (owner 2026-10-29: the first join was dark while textures and lights loaded; in
	-- Studio Roblox takes ~8-9 s to build the lighting after joining, live servers are usually faster, and no script
	-- can tell when it's done). Stays at least MinLoad seconds, until the Back Alley's textures are in and you have
	-- stood on your lane LightSettle seconds (after the zone look's fade); never longer than LoadLimit. Fades over FadeIn.
	MinLoad = 5,
	LoadLimit = 9,
	LightSettle = 0.6,
	FadeIn = 0.6,
	Tips = { -- one at random on the title card
		"TIP: Hold the throw button. You don't have to tap.",
		"TIP: A full bag pays nothing. Sell before it fills.",
		"TIP: Every new ball knocks down more pins.",
		"TIP: A bigger bag means fewer walks to sell.",
	},
	FieldOfView = 70,
	GlideBack = 1.4, -- seconds for the camera to crane back down behind you at the end (or after SKIP)
	WaitForData = 12, -- seconds to wait for your save to load before giving up on the intro
	-- Close shots first, the wide one last: Roblox is still building the lighting in the first seconds, and the wide
	-- shot needs the most light. It ends high over the alley and the camera cranes down behind you.
	Shots = {
		{ -- low run down a lane to the pins
			Time = 2.4,
			From = { Pos = Vector3.new(-7, 5, 152), Look = Vector3.new(-7, 2, 78) },
			To = { Pos = Vector3.new(-7, 3.2, 104), Look = Vector3.new(-7, 1.6, 78) },
			Text = "STRIKES = COINS",
		},
		{ -- Rizzo waves from his cart with the first crate deal
			Time = 2.4,
			From = { Pos = Vector3.new(10, 6.5, 156), Look = Vector3.new(14, 6.5, 175) },
			To = { Pos = Vector3.new(13, 7, 162), Look = Vector3.new(14, 7, 172) },
			Text = "OPEN CRATES. FIND LEGENDS.",
			Rizzo = "Fresh bowler? Show me a strike!",
			Deal = true,
		},
		{ -- high over the back of the alley, drifting in towards the lanes
			Time = 2.6,
			From = { Pos = Vector3.new(0, 34, 238), Look = Vector3.new(0, 2, 112) },
			To = { Pos = Vector3.new(0, 22, 200), Look = Vector3.new(0, 2, 100) },
			Text = "BECOME A LEGEND!",
		},
	},
}

-- The crate shop kiosk in the lobby (Workspace.Hub.CrateShop, built in Studio). Crate looks live in
-- ReplicatedStorage.CrateModels, one model per crate Id.
-- Weekly featured ball (Addendum 2 step 11b): each week (Monday 00:00 UTC) every zone features one of its crate balls
-- from its TopRarities best rarities (Shared.Modules.Balls.Featured; rotates through them, same on every server).
-- Inside its rarity the featured ball is WeightBoost times likelier than the others; the rarity odds never change.
-- Shown as FEATURED on the crate cards and in the ODDS list (with its real chance).
Config.Featured = {
	Enabled = true,
	WeightBoost = 3,
	TopRarities = 2,
}

-- Server banner (Addendum 2 step 11b): when anyone pulls one of these rarities from a crate, everyone in the server
-- sees a banner at the top. Delay = seconds after the pull (so it doesn't spoil the puller's own reveal).
Config.PullBanner = {
	Enabled = true,
	Rarities = { Epic = true, Legendary = true, Mythic = true }, -- Crate Kit 2026-10-26: Epic and up (was Legendary + Mythic)
	MaxWaiting = 3, -- banners waiting their turn; more are dropped
	Delay = 4,
	Seconds = 4, -- each banner stays this long; more pulls wait their turn
	Text = "%s PULLED %s (%s)!", -- player's display name, ball name, rarity
	-- A1 (2026-10-28): pets too, from the egg hatch (MascotService); after the hatch's reveal
	PetRarities = { Legendary = true, Mythic = true },
	PetDelay = 3.5,
	PetText = "%s HATCHED %s (%s)!",
}

Config.CrateShop = {
	PromptDistance = 10, -- studs from the buy button where "Open" shows up
	HoldDuration = 0.4, -- seconds to hold the buy button, so nobody spends coins by accident
	CrateSpin = 0.12, -- turns per second for the crates on display
	CrateBob = 0.25, -- studs the display crates float up and down
	SparkleOrbit = 0.08, -- turns per second the gold sparkles drift around the crate
	SparkleRadius = 1.7, -- studs from the crate centre (more would poke into the kiosk's back wall)
	SparkleDrift = 0.2, -- studs the sparkles drift in and out
	SparkleFloat = 0.35, -- studs the sparkles float up and down
	OpenSign = { -- the flickering "OPEN" neon on top of the kiosk
		Color = Color3.fromRGB(255, 70, 150), -- tube colour when lit
		OnText = Color3.fromRGB(255, 225, 235),
		OffText = Color3.fromRGB(70, 60, 72), -- dead tube: grey glass
		OffGlow = Color3.fromRGB(80, 30, 55),
		LightRange = 9,
		LightBrightness = 1.2,
		CalmMin = 1.5, -- seconds it stays steady between flickers
		CalmMax = 5,
		DropoutChance = 0.35, -- chance a flicker ends with the sign going dark for a moment
	},
	AnimateDistance = 90, -- only animate while your camera is this close (saves phone battery)
	Intro = { -- the crate on screen before the reel: slams down, hops to the beat, lid blasts off (about 2 s)
		CrateSize = 4.3, -- studs wide on screen (every crate model is fitted to this)
		FaceAngle = -25, -- degrees the crate is turned from facing you straight on
		CameraDistance = 13,
		Kick = 0.12, -- camera punches in by this share on every landing
		DropTime = 0.35, -- seconds to slam down from above
		DropHeight = 7, -- studs it falls
		DropSpin = 1, -- turns while falling
		Hops = 4, -- same for every crate and prize (item 13: nothing hints the rarity before the reel)
		RainbowSpeed = 0.9, -- loops per second through all the rarity colours while it hops and blasts
		HopTime = 0.3, -- seconds per hop
		HopHeight = 0.6, -- studs of the first hop
		HopGrow = 0.45, -- each next hop this much higher
		HopTurn = 90, -- degrees turned per hop
		HopWiggle = 10, -- degrees of side wiggle in the air
		LidPeek = 9, -- degrees the lid rests more open after each hop
		BlastTime = 0.6, -- seconds of crouch + lid blast
		CrouchShare = 0.3, -- share of BlastTime spent crouching and rattling
		LidFly = 9, -- studs the lid rockets up
		LidSpin = 1.5, -- turns the lid tumbles while flying off
		BeamHeight = 14, -- studs of the light beam out of the crate
		Rays = 8, -- light spokes behind the crate (each = 2 rays)
		RayWidth = 0.06, -- spoke width (share of the stage)
		RaySpin = 0.1, -- turns per second when calm
		RaySpinHot = 0.6, -- extra turns per second when it's about to blow
		Confetti = 35, -- pieces at the blast
		RingTime = 0.45, -- seconds a ring of light spreads out on each step up
	},
	-- A2 crate opening juice (2026-10-28). Honest: the reel only ever slows down to the real prize.
	Juice = {
		Streaks = 9, -- speed lines over the reel while it's fast
		StreakFrom = 400, -- design px per second where they start to show
		StreakFull = 2500, -- ... and are fully on
		StreakAlpha = 0.55, -- how see-through they are at full speed (0 = invisible, 1 = solid)
		HeartbeatFrom = 1.8, -- seconds before the reel stops that the heartbeat starts
		HeartbeatEvery = 0.45, -- seconds between beats at first
		HeartbeatSpeedUp = 0.35, -- beats come this share faster by the end
		BeatPunch = 0.025, -- the reel jumps this much bigger on each beat
		ZoomIn = 0.08, -- the reel slowly zooms in by this share during the heartbeat
		ShockwaveTime = 0.5, -- seconds the landing ring spreads out
		ShockwaveSize = 2.2, -- ring size in tile widths (+0.6 per rarity step)
		Shake = 10, -- design px the reel shakes on landing (more for rarer)
		ShakeTime = 0.3,
		CountUp = 0.6, -- seconds the COINS number on the reveal counts up
		Confetti = { Common = 14, Uncommon = 20, Rare = 30, Epic = 40, Legendary = 60, Mythic = 80 },
	},
	SpinTime = 4.5, -- seconds the crate reel spins before it stops on the result
	-- Owner's Crate Kit (2026-10-26): reel and shop timings
	SpinTimeBig = 5.5, -- reel spin when the prize is Legendary or Mythic
	ReelJitter = 60, -- the reel first stops up to this many design px off centre, then nudges to the exact centre
	ReelSettle = 0.3, -- seconds of that last nudge
	ReelHold = 0.4, -- seconds the landed tile stays before the reveal
	WalkAwayDistance = 20, -- studs you walk from where you opened the crate shop before it closes by itself
	ScreenBrightness = 1.15, -- glow of the kiosk screens (marquee, odds, prices); higher = more vibrant
	-- The owner's Crate Kiosk design (2026-10-21): Bronze, Silver, Gold stations
	PriceShineEvery = 3, -- seconds between shine sweeps across a price plate
	RingSpin = 0.15, -- turns per second of Silver's light ring
	ButtonPulse = 1.6, -- BUY button glow pulses per second
	Hover = { -- while you stand close enough to buy
		Lift = 0.5, -- studs the crate rises
		Tilt = 14, -- degrees the crate leans toward you
		ButtonSwell = 1.12, -- BUY button grows to this size
		LightBoost = 1.8, -- station lights get this much brighter
		Speed = 8, -- how fast it eases in and out
	},
	Purchase = { -- plays on the kiosk when you buy, before the crate screen opens
		ShakeTime = 0.45, -- seconds the crate shakes before the lid flashes
		ShakeAngle = 9, -- degrees
		FlashTime = 0.15, -- seconds the lid stays white
		Rays = 10, -- light rays out of the crate
		Coins = 18, -- coins sprayed out
		CoinSpeed = 16, -- studs per second
		CoinLife = 2.2, -- seconds before the coins fade
		RingGrow = 5, -- studs the light ring grows to
		BurstTime = 0.7, -- seconds the rays and ring take to fade
	},
}

-- Mascots (pets, Addendum 2 Phase 3 step 8): small buddies that follow you and add to your coins.
-- Hatched from eggs (Config.Economy.Eggs: price, unlock, BonusScale). A mascot's bonus =
-- Config.Economy.Mascots.Bonus[its rarity] x its egg's BonusScale; equipped bonuses add up: coins x (1 + total).
-- Placeholder looks (Addendum 2 section 9.7): a coloured ball with eyes. Color = body, Accent = tuft and cheeks.
-- Egg = which egg hatches it. Only the Neon Egg (Id "Alley", sold in zone 2) has mascots so far; the others come with zones 2 to 5.
-- Adding a mascot = adding a row. Each egg needs at least one mascot per rarity in Config.Economy.Mascots.Odds.
Config.Mascots = {
	{
		Id = "Pinny",
		Stats = { Coins = 0.2 }, -- Addendum 5 B1 (Config.PetStats); B2 re-rated for the egg ladder
		Name = "Pinch", -- was "Pinny" (2026-11-03: zone 2 design SL_Z2_Pet_PINCH; Id kept)
		Egg = "Alley",
		Rarity = "Uncommon", -- Phase X: was Common (zone 2 starts at Uncommon); BaseBonus keeps its old +2%
		BaseBonus = 0.2,
		Color = Color3.fromHex("FF6B4E"),
		Accent = Color3.fromHex("FFE2C6"),
		Reaction = "Wiggle",
	},
	{
		Id = "Gus",
		Stats = { Coins = 0.1 }, -- Addendum 5 B1 (Config.PetStats); B2 re-rated for the egg ladder
		Name = "Pidge", -- was "Gutter Gus" (2026-11-03: zone 1 design SL_Z1_Pet_PIDGE; Id kept)
		Egg = nil, -- Phase X holding list: cut from the Neon Egg (6 pets now); owners keep it. Was Egg = "Alley"
		BonusEgg = "Alley", -- its bonus stays the Neon Egg's (owners' pets don't change)
		Rarity = "Common",
		Color = Color3.fromRGB(140, 140, 155),
		Accent = Color3.fromRGB(90, 200, 255),
		Reaction = "Wiggle",
	},
	{
		Id = "LanePup",
		Stats = { Bag = 0.15, Speed = 0.1 }, -- Addendum 5 B1 (Config.PetStats); B2 re-rated for the egg ladder
		Name = "Gully", -- was "Lane Pup" (2026-11-03: zone 2 design SL_Z2_Pet_GULLY; Id kept)
		Egg = "Alley",
		Rarity = "Uncommon",
		Color = Color3.fromHex("F7F5F0"),
		Accent = Color3.fromHex("FFC233"),
		Reaction = "Hop",
	},
	{
		Id = "Bumper",
		Stats = { Bag = 0.3 }, -- Addendum 5 B1 (Config.PetStats); B2 re-rated for the egg ladder
		Name = "Vent Puff", -- was "Bumper" (2026-11-03: zone 1 design SL_Z1_Pet_VENTPUFF; Id kept)
		Egg = nil, -- Phase X holding list: cut from the Neon Egg (6 pets now); owners keep it. Was Egg = "Alley"
		BonusEgg = "Alley", -- its bonus stays the Neon Egg's (owners' pets don't change)
		Rarity = "Uncommon",
		Color = Color3.fromRGB(190, 255, 70),
		Accent = Color3.fromRGB(255, 90, 200),
		Reaction = "Spin",
	},
	{
		Id = "Strikey",
		Stats = { Pins = 0.4 }, -- Addendum 5 B1 (Config.PetStats); B2 re-rated for the egg ladder
		Name = "Jellybop", -- was "Strikey" (2026-11-03: zone 2 design SL_Z2_Pet_JELLYBOP; Id kept)
		Egg = "Alley",
		Rarity = "Rare",
		Color = Color3.fromHex("FF9FCB"),
		Accent = Color3.fromHex("C493FF"),
		Reaction = "Hop",
	},
	{
		Id = "Splitz",
		Stats = { Coins = 0.35, Pins = 0.25 }, -- Addendum 5 B1 (Config.PetStats); B2 re-rated for the egg ladder
		Name = "Shellby", -- was "Splitz" (2026-11-03: zone 2 design SL_Z2_Pet_SHELLBY; Id kept)
		Egg = "Alley",
		Rarity = "Rare",
		Color = Color3.fromHex("FFB47E"),
		Accent = Color3.fromHex("B79BE8"),
		Reaction = "Wiggle",
	},
	{
		Id = "Hambone",
		Stats = { Coins = 1 }, -- Addendum 5 B1 (Config.PetStats); B2 re-rated for the egg ladder
		Name = "Surf Otter", -- was "Hambone" (2026-11-03: zone 2 design SL_Z2_Pet_SURFOTTER; Id kept)
		Egg = "Alley",
		Rarity = "Epic",
		Color = Color3.fromHex("A8714A"),
		Accent = Color3.fromHex("FF8FB1"),
		Reaction = "Flip",
	},
	{
		Id = "NeonBat",
		Stats = { Pins = 0.6, Speed = 0.25 }, -- Addendum 5 B1 (Config.PetStats); B2 re-rated for the egg ladder
		Name = "Neon Bat",
		Egg = nil, -- 2026-11-03: out of the Sunset Egg (zone 2 designs = 5 pets); owners keep it. Was Egg = "Alley"
		BonusEgg = "Alley", -- its bonus stays the Neon Egg's (owners' pets don't change)
		Rarity = "Epic",
		Color = Color3.fromRGB(110, 40, 200),
		Accent = Color3.fromRGB(60, 255, 220),
		Reaction = "Flip",
	},
	{
		Id = "Kingpin",
		Stats = { Pins = 1.2 }, -- Addendum 6 Stage 9 (pacing pass): was Pins = 2.5
		Name = "Temple Monkey", -- was "Kingpin" (2026-11-03: zone 3 design PET_TempleMonkey_Legendary; Id kept)
		Egg = "Arcade", -- Phase X: moved from the Neon Egg to zone 3's Main Street Egg
		Rarity = "Legendary",
		Color = Color3.fromHex("9C5F35"),
		Accent = Color3.fromHex("FFC43D"),
		Reaction = "Spin",
	},
	{
		Id = "Blaze",
		Stats = { Coins = 1.5, Speed = 0.3 }, -- Addendum 6 Stage 9 (pacing pass): was Coins = 4, Speed = 0.4
		Name = "Jaguar Cub", -- was "Blaze" (2026-11-03: zone 3 design PET_JaguarCub_Legendary; Id kept)
		Egg = "Arcade", -- Phase X: moved from the Neon Egg to zone 3's Main Street Egg
		Rarity = "Legendary",
		Color = Color3.fromHex("F2A43A"),
		Accent = Color3.fromHex("5A3420"),
		Reaction = "Flip",
	},
	{
		Id = "Cosmo",
		Stats = { Coins = 3, Pins = 2 }, -- Addendum 6 Stage 9 (pacing pass): was Coins = 12, Pins = 6
		Name = "Scarab", -- was "Cosmo" (2026-11-03: zone 4 design SL_Z4_Pet_Scarab; Id kept)
		Egg = "Skyline", -- Phase X: moved from the Neon Egg to zone 4's Skyline (now Sun) Egg
		Rarity = "Mythic",
		Color = Color3.fromHex("FFC846"),
		Accent = Color3.fromHex("1FB5B8"),
		Reaction = "Spin",
	},
	{
		Id = "Perfecto",
		Stats = { Pins = 3, Speed = 0.5 }, -- Addendum 6 Stage 9 (pacing pass): was Pins = 10, Speed = 0.6
		Name = "Sphinx Kitten", -- was "Perfecto" (2026-11-03: zone 4 design SL_Z4_Pet_SphinxKitten; Id kept)
		Egg = "Skyline", -- Phase X: moved from the Neon Egg to zone 4's Skyline (now Sun) Egg
		Rarity = "Mythic",
		Color = Color3.fromHex("FFC846"),
		Accent = Color3.fromHex("38C8C8"),
		Reaction = "Flip",
	},
	-- Phase X: zone 3 (Main Street Egg) and zone 4 (Skyline Egg) pets (owner's designs since 2026-10-28/29)
	{
		Id = "WoodPup",
		Stats = { Bag = 0.3, Coins = 0.15 }, -- Addendum 6 Stage 9 (pacing pass): was Bag = 0.6, Coins = 0.15
		Name = "Tree Frog", -- was "Wood Pup" (2026-11-03: zone 3 design PET_TreeFrog_Rare; Id kept)
		Egg = "Arcade",
		Rarity = "Rare",
		Color = Color3.fromHex("63C94A"),
		Accent = Color3.fromHex("FF9632"),
		Reaction = "Hop",
	},
	{
		Id = "ChromeBat",
		Stats = { Coins = 0.6, Bag = 0.4 }, -- Addendum 6 Stage 9 (pacing pass): was Coins = 1.2, Bag = 1
		Name = "Toucan Tom", -- was "Chrome Bat" (2026-11-03: zone 3 design PET_ToucanTom_Epic; Id kept)
		Egg = "Arcade",
		Rarity = "Epic",
		Color = Color3.fromHex("2E3552"),
		Accent = Color3.fromHex("FF8A2A"),
		Reaction = "Flip",
	},
	{
		Id = "CloudBumper",
		Stats = { Pins = 0.6, Bag = 0.5 }, -- Addendum 6 Stage 9 (pacing pass): was Pins = 0.8, Bag = 1.5
		Name = "Fennec", -- was "Cloud Bumper" (2026-11-03: zone 4 design SL_Z4_Pet_Fennec; Id kept)
		Egg = "Skyline",
		Rarity = "Epic",
		Color = Color3.fromHex("F2BE84"),
		Accent = Color3.fromHex("5FF2EE"),
		Reaction = "Hop",
	},
	{
		Id = "SunnyHam",
		Stats = { Coins = 1.5, Bag = 0.7 }, -- Addendum 6 Stage 9 (pacing pass): was Coins = 2.5, Bag = 2
		Name = "Cactus Pal", -- was "Moony" (2026-11-03: zone 4 design SL_Z4_Pet_CactusPal; Id stays SunnyHam)
		Egg = "Skyline",
		Rarity = "Legendary",
		Color = Color3.fromHex("5CBF5E"),
		Accent = Color3.fromHex("FF7FB8"),
		Reaction = "Hop",
	},
	-- Boss-only pet (Config.Boss.Drop): no egg hatches it, only the Pin Titan drops it
	{
		Id = "TitanJr",
		Stats = { Pins = 4, Coins = 1.5 }, -- Addendum 5 B1 (Config.PetStats); B2 re-rated for the egg ladder
		Name = "Titan Jr.",
		Egg = nil,
		BonusEgg = "Skyline", -- its bonus counts like a Skyline Egg pet
		Rarity = "Legendary",
		Color = Color3.fromRGB(70, 60, 80),
		Accent = Color3.fromRGB(255, 50, 80),
		Reaction = "Flip", -- own model since 2026-10-29 (owner's titan_jr.glb)
	},
	-- Addendum 6 3.3: zone 1's Rooftop Egg pets (Weakest pets in the game, zone 1, Common to Rare). Own models since
	-- 2026-11-03 (owner's SL_Z1_Pets_Lineup; were other pets' models re-tinted); Ids kept, names new.
	{
		Id = "Pebble",
		Stats = { Pins = 0.1 },
		Name = "Gravel", -- was "Pebble"
		Egg = "Speckled",
		Rarity = "Common",
		Color = Color3.fromRGB(168, 156, 140),
		Accent = Color3.fromRGB(255, 194, 51),
		Reaction = "Wiggle",
	},
	{
		Id = "Breezy",
		Stats = { Coins = 0.12, Speed = 0.06 },
		Name = "Kite Pup", -- was "Breezy"
		Egg = "Speckled",
		Rarity = "Uncommon",
		Color = Color3.fromRGB(245, 221, 176),
		Accent = Color3.fromRGB(73, 179, 238),
		Reaction = "Hop",
	},
	{
		Id = "Sunspot",
		Stats = { Coins = 0.25, Pins = 0.15 },
		Name = "Solar Cat", -- was "Sunspot"
		Egg = "Speckled",
		Rarity = "Rare",
		Color = Color3.fromRGB(255, 169, 77),
		Accent = Color3.fromRGB(255, 194, 51),
		Reaction = "Flip",
	},
}

-- Auto Bowl (master plan step 14.8, the plan's AUTO_BOWL_ENABLED): the game throws for you, slower than manual and
-- never a PERFECT (so no strikes past your Power Level's pin cap, no x2). Reserved for the monetization phase
-- (Addendum 2 section 7: an Auto Bowl gamepass). OFF: nothing is shown and the server ignores it. When on, an AUTO
-- button appears on the HUD for everyone (the gamepass check comes with monetization).
-- FREE SLOW AUTO BOWL (final changes batch D6): after FreeAfterRebirths rebirths everyone gets the AUTO button too,
-- but slower (FreeInterval) and never a strike (auto throws are never PERFECT and only PERFECTs strike, so the pins
-- are capped by your Power Level). The AUTO BOWL pass stays the strong one: Interval and a strike every throw.
-- Auto throws never move the streak, fever, lane events, rank trials or the 3-strike challenge.
Config.AutoBowl = {
	Enabled = false, -- true = the free auto for everyone from the start (Studio tests)
	Interval = 4.5, -- seconds between auto throws with the AUTO BOWL pass (a manual throw takes about 3)
	FreeAfterRebirths = 1, -- the free slow auto opens at this many rebirths (0 = never)
	FreeInterval = 7, -- seconds between free auto throws
	ChargeMin = 0.4, -- each auto throw's power is picked between these (0 to 1 of the bar, never the red)
	ChargeMax = 0.85,
}

-- Egg names and colours (prices, unlocks and odds: Config.Economy.Eggs / Config.Economy.Mascots)
Config.EggLooks = {
	-- 2026-11-03: the owner's Sunset Egg (PetModels.Egg_Alley, SL_Z2_SunsetEgg_full); was the Neon Egg #ff3ad0 / #3ff0ff
	Alley = { Name = "Sunset Egg", Color = Color3.fromRGB(255, 226, 198), Spots = Color3.fromRGB(255, 122, 92) },
	Neon = { Name = "Neon Egg", Color = Color3.fromRGB(80, 230, 255), Spots = Color3.fromRGB(255, 60, 210) },
	-- 2026-11-03: the owner's Jungle Egg (PetModels.Egg_Arcade, SL_Z3_Egg_JungleEgg); was the Main Street Egg #e0a526 / #961e28
	Arcade = { Name = "Jungle Egg", Color = Color3.fromHex("7CC65A"), Spots = Color3.fromHex("FF9632") },
	-- 2026-11-03: the owner's Sun Egg (PetModels.Egg_Skyline, SL_Z4_SunEgg); was the Skyline Egg #ff4f8b / #f5b82e
	Skyline = { Name = "Sun Egg", Color = Color3.fromHex("FFC846"), Spots = Color3.fromHex("38C8C8") },
	-- Addendum 5 B2: the 4th roof egg. No model of its own: the server copies PetModels.Egg_<Copy> as Egg_Volcano in
	-- Config.CoreLoop.Eggs.Tints[Tint] colours at start
	-- Addendum 6 3.3 PLACEHOLDER: zone 1's starter egg, the Neon Egg model re-tinted at start (no model of its own yet)
	-- 2026-11-03: the owner's Rooftop Egg (PetModels.Egg_Speckled, SL_Z1_RooftopEgg_full); was the Neon Egg re-tinted
	Speckled = { Name = "Rooftop Egg", Color = Color3.fromRGB(246, 235, 210), Spots = Color3.fromRGB(93, 189, 240) },
	Volcano = { Name = "Volcano Egg", Color = Color3.fromRGB(255, 100, 40), Spots = Color3.fromRGB(60, 20, 20), Copy = "Alley", Tint = "Volcano" },
}

-- Where each egg is hatched (Phase X: one stand per zone). Path = the stand's folder under Workspace; it holds a
-- NeonStand model with an EggSpot part (the lobby's stand is the owner's design; zone 3's is the owner's Main Street
-- hatch stand since 2026-10-28, zone 4's the owner's Skyline stand since 2026-10-29, both still named NeonStand). You hatch an egg only within Config.MascotFx.HatchRange of its stand.
Config.EggStands = {
	{ Egg = "Alley", Path = { "Hub", "EggPad" } },
	{ Egg = "Arcade", Path = { "MainStreetLanes", "EggPad" } },
	{ Egg = "Skyline", Path = { "SkylineLanes", "EggPad" } },
}
-- Addendum 5 B2: in the core loop the eggs hatch at the roof's EGG ROW instead (Config.CoreLoop.Eggs, stands built
-- from code at server start as <Folder>.EggRow.<egg Id>); the zone stands above are left alone
if Config.CoreLoop.Enabled and Config.CoreLoop.Eggs.Enabled then
	Config.EggStands = {}
	for _, row in Config.CoreLoop.Eggs.List do
		local zones = Config.CoreLoop.Zones
		local zone = zones and zones.Enabled and zones.List[row.Zone or 1]
		local folder = if zone then zone.Folder else Config.CoreLoop.Folder
		table.insert(Config.EggStands, { Egg = row.Id, Path = { folder, "EggRow", row.Id } })
	end
end

-- Polish P3: odds bubbles float over each egg stand when you walk near: every pet the egg can hatch (3D) and its
-- chance (LUCKY passes included, same maths as the hatch: Mascots.Chance). Sizes are in studs so they look the same
-- on a phone and a computer. Client only (MascotController).
Config.EggOdds = {
	ShowDistance = 24, -- studs (flat) from the stand: closer than this, the bubbles fade in
	HideDistance = 30, -- further than this, they fade out (the gap stops flicker at the edge)
	FadeTime = 0.35, -- seconds to fade fully in or out
	Height = 8.8, -- studs from the egg's middle up to the bubbles' bottom edge (clears the stand's PET EGGS sign)
	CardSize = 2.2, -- studs: each pet's bubble is this wide (and a little taller for its %)
	Gap = 0.3, -- studs between bubbles
	PerRow = 6, -- bubbles per row (more pets wrap onto a second row)
	PetFill = 0.85, -- how much of its bubble the pet fills
	Spin = 30, -- degrees per second the pets turn in their bubbles (0 = still)
}

-- UI overhaul V6 (Config.Ui.EggV2): the new egg board, one per stand, in studs so it is the same size on every screen
-- (Modules/EggV2). It shows when you walk near and hides while a hatch plays.
Config.EggBoard = {
	Width = 12, -- studs wide (the design's 720 x 440 board; height follows)
	Height = 8.8, -- studs from the egg's middle up to the board's bottom edge (its pointer)
	ShowDistance = 16, -- studs (flat) from the stand: closer = the board pops up (inside the server's HatchRange 18)
	HideDistance = 18, -- further = it hides (the gap stops flicker at the edge)
	PetFill = 0.8, -- how much of its round slot the pet fills
	Spin = 30, -- degrees per second the pets turn (0 = still)
	-- Polish v2 U3 part 2 (owner's reference picture): buff lines, a white card with the pets 3 across, the price
	-- pill beside it and round AUTO-DELETE / AUTO (T) / OPEN 3 (R) / OPEN 1 (E) buttons under it (EggV2.GridBoard).
	-- false = the V6 board above (one row of round slots, HATCH / AUTO / x3).
	Grid = true,
	GridHeight = 2.6, -- studs from the egg's middle up to the grid board's bottom edge (its button labels)
}

-- Batch C3 (final changes 11b): tap a pet on an egg's odds board to X it out; X'd pets you hatch are auto-deleted
-- (not kept; the hatch card still shows them with an AUTO-DELETED stamp and they count as eggs hatched). Tap again
-- to undo. One list per player across all eggs, saved (AutoDelete), the server owns it (MascotService).
Config.AutoDelete = {
	Enabled = true, -- false = no X on the boards and nothing is auto-deleted (saved X's are kept for later)
	MaxRarity = "Legendary", -- the rarest pet that can be X'd; rarer ones (Mythic) can never be auto-deleted
	KeepFirst = true, -- true = a pet you own none of (nor its Shiny) is always kept, even when X'd
	XColor = Color3.fromRGB(255, 45, 74), -- the big X over an X'd pet's bubble
	Hint = "TAP A PET TO AUTO-DELETE IT", -- the line under the bubbles
	TooRare = "%s PETS CAN'T BE AUTO-DELETED", -- toast when a pet rarer than MaxRarity is tapped (%s = rarity)
}

-- Polish P4: big floating signs over every station so you always know where to go, even from far away or on a phone
-- (AreaSignController, client only, built from code over the station found at Path under Workspace). The sign sits
-- Lift studs above the station's top, moved by Offset (world studs), never into a ceiling above it, and over an egg
-- stand always above that egg's odds bubbles (Config.EggOdds). Paint = a HUD Kit colour pair (HudKit.Paints),
-- Icon = a HUD Kit icon (AssetSlots.Images Hud<Icon>), HideWhile = a BillboardGui in the station that takes over
-- while it is on. The spin wheel, elevators and the boss helicopter keep their own signs; Power Level and Rebirth
-- are HUD buttons (no spot in the world to put a sign on).
Config.AreaSigns = {
	Enabled = true,
	Height = 3.4, -- studs: how tall a sign is (its width follows the word)
	Lift = 2.5, -- studs between the station's top and the sign's bottom edge
	CeilingGap = 0.4, -- studs kept clear under a ceiling
	EggGap = 0.5, -- studs kept clear above an egg stand's odds bubbles
	MinPixels = 4, -- extra screen pixels per stud, so far-away signs never shrink to nothing
	MaxDistance = 320, -- studs: further than this, the sign is hidden
	Bob = 0.25, -- studs up and down
	BobSpeed = 1.6, -- bobs per second (x 2 pi)
	Signs = {
		{ Text = "CRATES", Paint = "Gold", Icon = "Crate", Path = { "BackAlley", "RizzoStand" }, Lift = 6, HideWhile = "CallMarker" }, -- over Rizzo; hidden while his GO HERE! marker shows
		{ Text = "CRATES", Paint = "Gold", Icon = "Crate", Path = { "Hub", "CrateShop" }, Offset = Vector3.new(-11, -6, 0) }, -- in front of the kiosk (it reaches the ceiling)
		{ Text = "EGGS", Paint = "Pink", Icon = "Paw", Path = { "Hub", "EggPad" }, Egg = "Alley", HideWhile = "EggCallMarker" }, -- hidden while the first-egg GO HERE! shows (Config.EggPrompt)
		{ Text = "EGGS", Paint = "Pink", Icon = "Paw", Path = { "MainStreetLanes", "EggPad" }, Egg = "Arcade" },
		{ Text = "FUSION", Paint = "Purple", Icon = "Paw", Path = { "MainStreetLanes", "FusionStation" } },
		{ Text = "CRATES", Paint = "Gold", Icon = "Crate", Path = { "MainStreetLanes", "CrateShop" } },
		{ Text = "EGGS", Paint = "Pink", Icon = "Paw", Path = { "SkylineLanes", "EggPad" }, Egg = "Skyline" },
		{ Text = "CRATES", Paint = "Gold", Icon = "Crate", Path = { "SkylineLanes", "CrateShop" } },
	},
}

-- Addendum 5 B2: signs over the roof's egg row and fusion machine (Config.CoreLoop.Eggs)
if Config.CoreLoop.Enabled and Config.CoreLoop.Eggs.Enabled then
	local roof = Config.CoreLoop.Folder
	table.insert(Config.AreaSigns.Signs, { Text = "PET EGGS", Paint = "Pink", Icon = "Paw", Path = { roof, "EggRow" }, Lift = if Config.Ui.EggV2 then 8 else 4, Egg = Config.Ui.EggV2 and Config.EggBoard.Grid }) -- (V6: clears the taller egg board; grid board: sits above it)
	table.insert(Config.AreaSigns.Signs, { Text = "FUSION", Paint = "Purple", Icon = "Paw", Path = { roof, Config.CoreLoop.Eggs.Fusion.Name } })
end
-- Addendum 5 F: the roof's own crate kiosk and egg pad are moved away in the core loop (CoreLoop.HiddenStations), so
-- their sign and crate-counter rows go too (they only printed "not found" warnings)
if Config.CoreLoop.Enabled then
	local hidden = {}
	for _, name in Config.CoreLoop.HiddenStations do
		hidden[name] = true
	end
	local function onRoof(path)
		return path[1] == Config.CoreLoop.Folder and hidden[path[2]] == true
	end
	for i = #Config.AreaSigns.Signs, 1, -1 do
		if onRoof(Config.AreaSigns.Signs[i].Path) then
			table.remove(Config.AreaSigns.Signs, i)
		end
	end
	for i = #Config.ZoneShops, 1, -1 do
		if onRoof(Config.ZoneShops[i].Path) then
			table.remove(Config.ZoneShops, i)
		end
	end
end
-- Batch B3 (2026-10-29, teach the first minutes): what the game points out the first times
-- Ball Book: a gold bubble points at the POLISH button of the ball you throw, every time the book opens, until you buy
-- a POLISH once (save PolishHinted). Tapping the bubble hides it until the next session.
Config.PolishHint = {
	Enabled = true,
	Text = "POLISH = MORE COINS!",
	Sub = "EVERY LEVEL BOOSTS THIS BALL", -- shown when you have the gems
	SubNoGems = "COSTS GEMS - LEVEL UP TO EARN THEM", -- shown when you can't pay yet
}
-- Rank trial button: the label flips between "RANK TRIAL READY!" and TapText, and a hand bobs next to it
-- Polish v2 (owner 2026-11-03): a really short show-not-tell tutorial for new players. The steps go in order; a hand
-- shows what to press (Target: Throw = THROW button, Sell = SELL button, Goal = NEXT GOAL card, which takes you to
-- the shop), one word says it, and a strip of reward tiles at the top shows what each step pays. A step is done when
-- the saved Stats add up to AtLeast; TutorialService pays its Reward right then (Coins, Gems or a free Egg) and saves
-- the count in Tutorial (v39). Players who rebirthed or sold before v39 skip it. Enabled = false = no tutorial.
Config.Tutorial = {
	Enabled = true,
	Hand = "\u{1F446}", -- (pointing-up hand, drawn under the target)
	DoneSeconds = 2.5, -- the strip stays this long after the last step, then slides away
	Steps = {
		{ Id = "Throw", Word = "HOLD", Target = "Throw", Stats = { "CoreThrows" }, AtLeast = 1, Reward = { Coins = 20 } },
		{ Id = "Sell", Word = "SELL", Target = "Sell", Stats = { "CoreSells" }, AtLeast = 1, Reward = { Coins = 30 } },
		{ Id = "Ball", Word = "NEW BALL", Target = "Goal", Stats = { "BallStep" }, AtLeast = 2, Reward = { Coins = 120 } },
		-- one more buy (ball 3 or bag 2): BallStep + BagLevel start at 1 + 1
		{ Id = "Upgrade", Word = "UPGRADE", Target = "Goal", Stats = { "BallStep", "BagLevel" }, AtLeast = 4, Reward = { Egg = "Speckled" } },
	},
}

Config.TrialHint = {
	Enabled = true,
	TapText = "TAP TO START!",
	FlipSeconds = 1.2, -- seconds each label stays
	Hand = "👉",
	Bob = 8, -- px the hand moves toward the button and back
}

-- Polish P4: a pointing hand on EQUIP BEST in the PETS panel, shown the first time EQUIP BEST would change your pets.
-- It stays until you tap EQUIP BEST once (save EquipBestHinted).
Config.EquipBestHint = {
	Enabled = true,
	Hand = "👉", -- the pointing hand (an emoji, drawn left of the button)
	Bob = 8, -- px the hand moves toward the button and back
}

-- How mascots look and move, and the hatching moment
Config.MascotFx = {
	Size = 1.6, -- studs across
	-- Pets out in the world (following you, on the shelf, hatching) glow less (owner 2026-10-25: too bright):
	-- their Neon parts' colour times NeonDim (Neon glows as bright as its colour), their lights times LightDim
	NeonDim = 0.7,
	LightDim = 0.5,
	FollowDistance = 4.5, -- studs behind the player (the first row; more mascots fan out to the sides)
	Spacing = 2.6, -- studs between mascots side by side
	FollowSpeed = 8, -- how fast they catch up (higher = snappier)
	Hover = 2.2, -- studs above the ground
	BobHeight = 0.35, -- studs they bob up and down
	BobSpeed = 2.4, -- bobs per second (each mascot is a little out of step)
	ShowDistance = 120, -- mascots of players further away than this aren't drawn (saves phone battery)
	-- The egg stand in the lobby (Workspace.Hub.EggPad, the old daily-reward pad)
	PromptDistance = 10,
	HoldDuration = 0.4, -- seconds to hold "Hatch", so nobody spends coins by accident
	HatchRange = 18, -- eggs only hatch at the stand: the server refuses players further than this (studs, flat)
	-- Hatching away from the stand (fallback when the stand model is missing): the egg shakes harder and harder
	-- while its glow flicks through rarity colours, then cracks
	ShakeTime = 2.4,
	RevealTime = 2.6, -- seconds the new mascot stays on screen before the panel can be closed
	TeaseChance = 0.35, -- chance the glow flashes a rarer colour near the end before settling (odds are shown honestly)
	MergeTime = 1.6, -- seconds the copies shake together before the Shiny pops out (step 8b)
	-- The hatch on the real Neon stand (owner's Hatch Storyboard, about 3s; Client Modules/HatchScene).
	-- Frames: Idle 0.30 · Activation 0.40 · Shake 0.75 · Crack 0.40 (incl. the hold) · Burst 0.35 · Reveal 0.80
	Hatch = {
		CameraFov = 50,
		CameraFill = 0.62, -- egg + stand fill this much of the screen's height (sign kept on screen)
		CameraHeight = 1.2, -- studs the camera sits above the stand's middle
		CameraIn = 0.35, -- seconds the camera takes to swing in
		Idle = 0.3,
		Activation = 0.4,
		Wobbles = { -- each hit: tilt (degrees), seconds, core brightness, Hop = studs the egg jumps (item 14: bigger)
			{ Angle = 15, Time = 0.3, Core = 1.3, Hop = 0.25 },
			{ Angle = 19, Time = 0.27, Core = 1.7, Hop = 0.4 },
			{ Angle = 24, Time = 0.24, Core = 2.2, Hop = 0.55 },
		},
		HitShake = 0.05, -- studs the camera jolts on each wobble (x the wobble number)
		BurstShake = 0.3, -- studs the camera shakes when the shell blows (x the tier's Flash)
		CrackTime = 0.4, -- cracks + overload + arch flash, the last Hold seconds stand still
		Hold = 0.1,
		BeamLength = 3.5, -- studs the light beams out of each crack
		PillarHeight = 40,
		BurstTime = 0.35,
		ShardDistance = 9, -- studs the shell shards fly
		RingTime = 0.45,
		RingWidth = 1.6, -- the energy ring spreads to 1.6x the platform's width
		RevealTime = 0.8,
		PetSize = 0.85, -- the pet's size compared to the egg
		PetLift = 0.6, -- studs above the egg's middle where the pet settles
		PetRise = 1, -- studs it rises out of the light
		PetSettle = 0.5, -- seconds to settle (with a little overshoot)
		CardAt = 0.3, -- seconds into the reveal the name card pops in
		SkipFrom = 0.7, -- tap to skip from this many seconds in
		AutoSkipAfter = 5, -- after this many hatches in one session (and on AUTO HATCH) it plays the quick version
		-- A1 hatch upgrade (2026-10-28): rising tease, mood, camera push, rays + reaction on the reveal
		ExtraWobbles = { -- rarer pets keep shaking: Epic 4 wobbles, Legendary 5, Mythic 6 (one rarity colour per wobble)
			{ Angle = 27, Time = 0.22, Core = 2.5, Hop = 0.65 },
			{ Angle = 30, Time = 0.21, Core = 2.8, Hop = 0.75 },
			{ Angle = 33, Time = 0.2, Core = 3.2, Hop = 0.85 },
		},
		DimBrightness = -0.15, -- the world darkens while the egg hatches (0 = off)
		DimTint = Color3.fromRGB(200, 205, 255),
		DimTime = 0.5,
		Spotlight = 5, -- brightness of the light shining down on the egg (in the climbing rarity colour)
		Motes = 14, -- floating light specks per second around the stand
		Push = 0.14, -- the camera creeps this share of the way to the stand during the wobbles
		Punch = 0.32, -- ... and snaps in this far at the crack, then pulls back for the burst
		RaysSize = 4.2, -- turning rays behind the pet, x the pet's size (Legendary + Mythic get a 2nd layer)
		ReactLift = 0.6, -- the pet's own reaction (Hop/Spin/Flip/Wiggle) on the reveal lifts it this x its size
		ReactDelay = 0.15, -- seconds after settling before it reacts (twice)
		QuickPace = 0.5, -- the quick version plays the tease at this speed (times x 0.5)
		CountUp = 0.7, -- seconds the COINS bonus on the card counts up
		Confetti = { Common = 25, Uncommon = 35, Rare = 50, Epic = 80, Legendary = 110, Mythic = 150 },
		AutoNextDelay = 1.2, -- Polish P2: AUTO HATCH waits this long on the finished card before the next egg
		-- Burst grows with rarity, colours stay cyan/magenta. Extra = added seconds (pillar beat), Hold = stand-still
		TierOf = { Epic = "Epic", Legendary = "Legendary", Mythic = "Mythic" }, -- everything else = Base
		Tiers = {
			Base = { Shards = 16, Sparks = 40, Rings = 2, Flash = 1.15, Sparkles = 24, SparksPerHit = 6 },
			Epic = {
				Shards = 22,
				Sparks = 56,
				Rings = 2,
				Flash = 1.25,
				Sparkles = 32,
				SparksPerHit = 8,
				DoubleFlash = true,
			},
			Legendary = {
				Shards = 28,
				Sparks = 72,
				Rings = 2,
				Flash = 1.5,
				Sparkles = 44,
				SparksPerHit = 11,
				CrackSteps = 3,
				Pillar = true,
				CamShake = 0.1,
				Extra = 0.15,
			},
			Mythic = {
				Shards = 34,
				Sparks = 96,
				Rings = 3,
				Flash = 1.8,
				Sparkles = 60,
				SparksPerHit = 14,
				CrackSteps = 3,
				Pillar = true,
				CamShake = 0.1,
				EdgePulse = true,
				Extra = 0.3,
				Hold = 0.25,
			},
		},
	},
	-- Strike reactions (step 8b): when their owner strikes, each mascot does its Reaction (Config.Mascots row):
	-- Hop (jump), Spin (twirl), Flip (somersault) or Wiggle (shake side to side). Shiny ones also burst gold sparkles.
	ReactDelay = 0.25, -- seconds after the pins are hit
	ReactTime = 0.7, -- seconds a reaction lasts
	ReactHeight = 2.2, -- studs a reaction lifts the mascot at its top
	ReactStagger = 0.08, -- seconds between each mascot starting, so they go one after another
	ReactRepeats = 2, -- how many times each mascot does its reaction per strike
	-- On a strike the thrower's camera rides down the lane, so mascots dash down to cheer where it's looking:
	CheerBeforePins = 15, -- studs in front of the head pin (more mascots line up further back)
	CheerSide = 4.5, -- studs either side of the lane's middle (just inside the gutters)
	CheerHeight = 3, -- studs above the lane
	CheerLead = 0.5, -- they set off this many seconds before the ball reaches the pins
	-- The mascot shelf in the lobby Vault (step 8b): every mascot on a glowing stand, yours lit, missing ones dark.
	-- It sits along Workspace.Showcase.MascotShelf (a part you can move in Studio; the mascots face its front).
	ShelfSize = 2.2, -- studs across each mascot on the shelf
	ShelfHover = 1.6, -- studs above the shelf (placeholder pets and pets that fly: Config.PetIdle Floats); walkers stand on it
}

-- Polish v2 D7: the living world (client only, WorldLifeController). Only the zone your camera is in moves, updated
-- Rate times a second. Palm leaves bob, bunting flags flutter, kites and the hot-air balloon float, waterfall sheets
-- flow (a scrolling vapour texture) with foam at their feet, and the shop / sell pads pulse when you step on them.
Config.WorldLife = {
	Enabled = true,
	Rate = 30, -- updates per second
	Near = 450, -- studs from a zone's middle (flat) for its things to move
	Palm = { Angle = 4, Speed = 0.8 }, -- degrees a leaf bobs, swings per second
	Bunting = { Angle = 12, Speed = 1.4 },
	Kite = { Bob = 0.8, Roll = 8, Speed = 0.5 }, -- studs up/down, degrees of roll
	Balloon = { Bob = 1.5, Speed = 0.3 },
	Waterfall = { Speed = 10, Tile = 8, Transparency = 0.45, Foam = 10 }, -- studs/second down, foam puffs/second
	PadPulse = { Grow = 1.8, Time = 0.5, Sound = "Tap" },
	-- Polish v2 L5: fall more than this many studs below where you last stood (off the zone 1 roof into the void) and
	-- you're put back there (the teleport wipe hides it) instead of dying and waiting to respawn
	FallRescue = 80,
}

-- Polish v2 D4: how pets move (MascotFollowController, the egg stands, the egg board)
Config.PetMotion = {
	Freq = 2.4, -- follow spring (per second): a little lag behind you and a small overshoot when you stop
	Damp = 0.72, -- (1 = no overshoot)
	Snap = 40, -- studs: further than this from its spot (a teleport) = the pet jumps straight there
	Bank = 0.16, -- leaning into turns: degrees of lean per degree/second of turning...
	MaxBank = 24, -- ...at most this (walkers lean half as much)
	Pitch = 1.4, -- flyers dip their nose when flying fast: degrees per stud/second...
	MaxPitch = 14, -- ...at most this
	Hop = 0.55, -- walkers hop while they move: studs high...
	HopRate = 0.32, -- ...hops per stud travelled
	Face = 7, -- how fast pets turn to face where they're going
	LookPins = 0.8, -- seconds after the ball reaches the pins that pets keep watching the lane
	SleepAfter = 30, -- seconds without moving or throwing: pets doze (stop their idle, sink, tilt, z z z)
	SleepSink = 0.5, -- studs flyers sink while asleep
	SleepTilt = 12, -- degrees a dozing pet leans over
	SleepZ = 1.8, -- seconds for each z to float up
	EquipKick = 16, -- a new pet hops out of you at this upward speed (studs/second)...
	EquipGravity = 55, -- ...and falls back under this (studs/second/second): about 2.3 studs high
	EggWobble = { Every = 4, Time = 0.75, Angle = 6, Rocks = 2 }, -- eggs on their stands rock now and then
	BoardFlip = 0.5, -- seconds a pet found for the first time takes to flip from black to colour on the egg board
}

-- Real pet models (the owner's Claude Design pets, 2026-10-21): ReplicatedStorage.PetModels.<mascot Id> (and Egg_<egg Id>),
-- built in Studio from the imported .glb files and repainted from their colours. Sized for Config.MascotFx.Size; a
-- mascot without a model falls back to the placeholder ball. Each pet's idle motion follows its design's idle pose.
-- Body = the whole pet: Bob (studs) at BobSpeed (per second), Sway (degrees of side-to-side roll) at SwaySpeed,
-- Hop = { Every = seconds, Height = studs, Time = seconds in the air }. Floats = hovers at Config.MascotFx.Hover;
-- otherwise it walks on the ground.
-- Moves = parts moving on their own (Parts = name patterns). Kinds:
--   Swing (rock Angle degrees around Axis, Speed per second), Spin (Speed turns per second around Axis),
--   Lift (feet stepping up Height studs), Slide (move Outward studs away from the middle and back), Blink (eyes shut
--   every Every seconds), Pulse (glow dims to Min and back to Max), Twinkle (Pulse, each part out of step),
--   Rainbow (colours cycle Speed times per second).
--   Pivot: "Inner" (default) = the end nearest the pet's middle (wing roots, tail bases, necks), "Center", or "Root"
--   (the pet's middle). Mirror = true: parts on the pet's left and right swing opposite ways (two wings).
-- Hide = static sparkle shapes from the design files, replaced by real particles (Particles: At = a part name
-- pattern, or "Root"; Colors; Rate per second; Size, Life, Speed; Up = how fast they rise; Back = drift backwards).
local PET_CYAN = Color3.fromRGB(40, 230, 255)
local PET_VIOLET = Color3.fromRGB(170, 60, 255)
Config.PetIdle = {
	ShowDistance = 60, -- studs: pets further from your camera than this keep still (saves phone battery)
	Pinny = { -- Pinch (zone 2 design, 2026-11-03)
		Body = { Sway = 6, SwaySpeed = 0.9 },
		Moves = {
			{ Kind = "Swing", Parts = { "^arm", "^claw", "^pincer" }, Axis = Vector3.xAxis, Angle = 14, Speed = 1.2, Mirror = true },
			{ Kind = "Lift", Parts = { "^leg_L" }, Height = 0.08, Speed = 2 },
			{ Kind = "Lift", Parts = { "^leg_R" }, Height = 0.08, Speed = 2, Phase = 0.5 },
			{ Kind = "Swing", Parts = { "^stalk", "^eye" }, Axis = Vector3.zAxis, Angle = 8, Speed = 0.7, Mirror = true },
			{ Kind = "Blink", Parts = { "^eye" }, Every = 3.3 },
		},
	},
	-- 2026-11-03: zone 1's own designs (SL_Z1 pets; Gus = Pidge, Pebble = Gravel, Bumper = Vent Puff, Breezy = Kite
	-- Pup, Sunspot = Solar Cat)
	Gus = {
		Body = { Bob = 0.05, BobSpeed = 0.9, Hop = { Every = 2.6, Height = 0.35, Time = 0.3 } },
		Moves = {
			{ Kind = "Swing", Parts = { "^wing" }, Axis = Vector3.zAxis, Angle = 14, Speed = 1.6, Mirror = true },
			{ Kind = "Swing", Parts = { "^skull", "^beak", "^cere", "^eye_", "^blush" }, Axis = Vector3.yAxis, Angle = 12, Speed = 0.45 },
			{ Kind = "Blink", Parts = { "^eye_" }, Every = 3.4 },
		},
	},
	Pebble = {
		Body = { Sway = 5, SwaySpeed = 0.6 },
		Moves = {
			{ Kind = "Swing", Parts = { "^arm_" }, Axis = Vector3.xAxis, Angle = 18, Speed = 0.9, Mirror = true },
			{ Kind = "Lift", Parts = { "^foot_R" }, Height = 0.1, Speed = 1.2 },
			{ Kind = "Lift", Parts = { "^foot_L" }, Height = 0.1, Speed = 1.2, Phase = 0.5 },
			{ Kind = "Blink", Parts = { "^eye_" }, Every = 3.8 },
		},
	},
	Breezy = {
		Body = { Bob = 0.06, BobSpeed = 0.8, Hop = { Every = 3, Height = 0.5, Time = 0.4 } },
		Moves = {
			{ Kind = "Swing", Parts = { "^sock" }, Axis = Vector3.yAxis, Angle = 24, Speed = 1.8 },
			{ Kind = "Swing", Parts = { "^ear" }, Axis = Vector3.zAxis, Angle = 12, Speed = 1.4, Mirror = true },
			{ Kind = "Blink", Parts = { "^eye_L", "^eye_R", "^eye_shine" }, Every = 3.5 },
		},
	},
	Sunspot = {
		Body = { Bob = 0.06, BobSpeed = 0.6, Sway = 4, SwaySpeed = 0.4 },
		Moves = {
			{ Kind = "Spin", Parts = { "^ray_", "^mane_ring" }, Axis = Vector3.zAxis, Speed = 0.12, Pivot = "Center" },
			{ Kind = "Swing", Parts = { "^tail" }, Axis = Vector3.yAxis, Angle = 22, Speed = 0.8 },
			{ Kind = "Blink", Parts = { "^eye_" }, Every = 4 },
		},
	},
	LanePup = { -- Gully (zone 2 design, 2026-11-03)
		Body = { Bob = 0.05, BobSpeed = 0.9, Hop = { Every = 2.8, Height = 0.35, Time = 0.3 } },
		Moves = {
			{ Kind = "Swing", Parts = { "^wing" }, Axis = Vector3.zAxis, Angle = 16, Speed = 1.6, Mirror = true },
			{ Kind = "Swing", Parts = { "^skull", "^beak", "^eye_", "^blush" }, Axis = Vector3.yAxis, Angle = 12, Speed = 0.45 },
			{ Kind = "Blink", Parts = { "^eye_" }, Every = 3.4 },
		},
	},
	Bumper = { -- Vent Puff
		Body = { Bob = 0.12, BobSpeed = 0.5, Sway = 3, SwaySpeed = 0.35 },
		Moves = {
			{ Kind = "Lift", Parts = { "^wisp_" }, Height = 0.18, Speed = 0.9 },
			{ Kind = "Blink", Parts = { "^eye_" }, Every = 3 },
		},
	},
	Strikey = { -- Jellybop (zone 2 design, 2026-11-03)
		Floats = true,
		Body = { Bob = 0.25, BobSpeed = 0.7 },
		Moves = {
			{ Kind = "Swing", Parts = { "^tentacle" }, Axis = Vector3.xAxis, Angle = 14, Speed = 1.4 },
			{ Kind = "Blink", Parts = { "^eye_" }, Every = 3.6 },
		},
	},
	Splitz = { -- Shellby (zone 2 design, 2026-11-03)
		Body = { Sway = 4, SwaySpeed = 0.6 },
		Moves = {
			{ Kind = "Swing", Parts = { "^claw", "^pincer" }, Axis = Vector3.xAxis, Angle = 16, Speed = 0.9 },
			{ Kind = "Lift", Parts = { "^leg_L" }, Height = 0.08, Speed = 1.6 },
			{ Kind = "Lift", Parts = { "^leg_R" }, Height = 0.08, Speed = 1.6, Phase = 0.5 },
			{ Kind = "Swing", Parts = { "^stalk", "^eye" }, Axis = Vector3.zAxis, Angle = 8, Speed = 0.6 },
			{ Kind = "Blink", Parts = { "^eye" }, Every = 3.8 },
		},
	},
	Hambone = { -- Surf Otter (zone 2 design, 2026-11-03)
		Body = { Bob = 0.06, BobSpeed = 0.8, Sway = 5, SwaySpeed = 0.5 },
		Moves = {
			{ Kind = "Swing", Parts = { "^tail" }, Axis = Vector3.yAxis, Angle = 22, Speed = 1 },
			{ Kind = "Swing", Parts = { "^arm", "^paw" }, Axis = Vector3.xAxis, Angle = 12, Speed = 0.8, Mirror = true },
			{ Kind = "Swing", Parts = { "^sun_charm", "^bead", "^necklace" }, Axis = Vector3.xAxis, Angle = 10, Speed = 1.2 },
			{ Kind = "Blink", Parts = { "^eye_" }, Every = 4 },
		},
	},
	NeonBat = {
		Floats = true,
		Body = { Bob = 0.25, BobSpeed = 0.6, Sway = 4, SwaySpeed = 0.4 },
		Moves = {
			{ Kind = "Swing", Parts = { "^wing_" }, Axis = Vector3.zAxis, Angle = 28, Speed = 2.2, Mirror = true },
			{
				Kind = "Swing",
				Parts = { "^head", "^snout", "^eye_", "^fang_", "^ear_" },
				Axis = Vector3.zAxis,
				Angle = 6,
				Speed = 0.3,
			},
		},
		Hide = { "^spark" },
		Particles = {
			{
				At = "^wing_edge_trail_4_L$",
				Colors = { PET_VIOLET, PET_CYAN },
				Rate = 10,
				Size = 0.14,
				Life = 0.8,
				Speed = 0.3,
				Back = 2,
			},
			{
				At = "^wing_edge_trail_4_R$",
				Colors = { PET_VIOLET, PET_CYAN },
				Rate = 10,
				Size = 0.14,
				Life = 0.8,
				Speed = 0.3,
				Back = 2,
			},
		},
	},
	-- Zone 3 pets, the owner's Jungle Falls designs (2026-11-03; WoodPup = Tree Frog, ChromeBat = Toucan Tom, Kingpin
	-- = Temple Monkey, Blaze = Jaguar Cub). Old Main Street rows went with their models (PetModels_Backup_20261103)
	WoodPup = { -- Tree Frog
		Body = { Bob = 0.04, BobSpeed = 0.7, Hop = { Every = 2.6, Height = 0.5, Time = 0.35 } },
		Moves = {
			{ Kind = "Swing", Parts = { "^hat_" }, Axis = Vector3.zAxis, Angle = 8, Speed = 0.5 },
			{ Kind = "Pulse", Parts = { "^cheek" }, Speed = 0.5, Min = 0.7, Max = 1 },
			{ Kind = "Blink", Parts = { "^eye_white", "^pupil", "^eye_sparkle" }, Every = 3.4 },
		},
	},
	ChromeBat = { -- Toucan Tom
		Floats = true,
		Body = { Bob = 0.22, BobSpeed = 0.6, Sway = 4, SwaySpeed = 0.4 },
		Moves = {
			{ Kind = "Swing", Parts = { "^wing_" }, Axis = Vector3.zAxis, Angle = 26, Speed = 2, Mirror = true },
			{ Kind = "Swing", Parts = { "^tail_" }, Axis = Vector3.xAxis, Angle = 10, Speed = 0.8 },
			{ Kind = "Twinkle", Parts = { "^crest_glow", "^wing_tip_glow", "^tail_tip_glow" }, Speed = 1.5, Min = 0.6, Max = 1 },
			{ Kind = "Blink", Parts = { "^eye$", "^eye_0", "^eye%d", "^eye_sparkle" }, Every = 3.2 },
		},
	},
	Kingpin = { -- Temple Monkey (its gold aura turns slowly behind it)
		Body = { Bob = 0.05, BobSpeed = 0.5, Sway = 3, SwaySpeed = 0.35 },
		Moves = {
			{ Kind = "Spin", Parts = { "^aura_ray" }, Axis = Vector3.zAxis, Speed = 0.08, Pivot = "Center" },
			{ Kind = "Pulse", Parts = { "^aura" }, Speed = 0.5, Min = 0.6, Max = 1 },
			{ Kind = "Swing", Parts = { "^arm_shape", "^hand", "^gold_armband" }, Axis = Vector3.xAxis, Angle = 12, Speed = 0.6, Mirror = true },
			{ Kind = "Swing", Parts = { "^tail" }, Axis = Vector3.zAxis, Angle = 14, Speed = 0.7 },
			{ Kind = "Twinkle", Parts = { "^crown_gem" }, Speed = 1.2, Min = 0.6, Max = 1 },
			{ Kind = "Blink", Parts = { "^eye$", "^eye_0", "^eye%d", "^eye_sparkle" }, Every = 3.8 },
		},
	},
	Blaze = { -- Jaguar Cub (its sun aura turns behind it, the inner rays the other way)
		Body = { Bob = 0.04, BobSpeed = 0.6, Hop = { Every = 3.4, Height = 0.35, Time = 0.35 } },
		Moves = {
			{ Kind = "Spin", Parts = { "^aura_ray" }, Axis = Vector3.zAxis, Speed = 0.07, Pivot = "Center" },
			{ Kind = "Spin", Parts = { "^aura_inner_ray" }, Axis = -Vector3.zAxis, Speed = 0.1, Pivot = "Center" },
			{ Kind = "Pulse", Parts = { "^aura_ring", "^aura_ground_ring" }, Speed = 0.5, Min = 0.6, Max = 1 },
			{ Kind = "Swing", Parts = { "^tail" }, Axis = Vector3.yAxis, Angle = 20, Speed = 0.9 },
			{ Kind = "Twinkle", Parts = { "^spot_glow", "^collar_gem" }, Speed = 1.2, Min = 0.6, Max = 1 },
			{ Kind = "Blink", Parts = { "^eye$", "^eye_0", "^eye%d", "^eye_sparkle" }, Every = 3.6 },
		},
	},
	-- Zone 4 pets, the owner's Canyon Oasis designs (2026-11-03; CloudBumper = Fennec, SunnyHam = Cactus Pal, Cosmo =
	-- Scarab, Perfecto = Sphinx Kitten). Old Skyline rows went with their models (PetModels_Backup_20261103)
	CloudBumper = { -- Fennec
		Body = { Bob = 0.04, BobSpeed = 0.6, Hop = { Every = 3, Height = 0.45, Time = 0.35 } },
		Moves = {
			{ Kind = "Swing", Parts = { "^ear" }, Axis = Vector3.zAxis, Angle = 10, Speed = 1.2, Mirror = true },
			{ Kind = "Swing", Parts = { "^tail" }, Axis = Vector3.yAxis, Angle = 22, Speed = 1 },
			{ Kind = "Twinkle", Parts = { "_glow$" }, Speed = 1.2, Min = 0.6, Max = 1 },
			{ Kind = "Blink", Parts = { "^eye" }, Every = 3.4 },
		},
	},
	SunnyHam = { -- Cactus Pal (the gold sun spikes behind it turn slowly)
		Body = { Bob = 0.04, BobSpeed = 0.5, Hop = { Every = 3.6, Height = 0.35, Time = 0.35 } },
		Moves = {
			{ Kind = "Spin", Parts = { "^aura_spike" }, Axis = Vector3.zAxis, Speed = 0.08, Pivot = "Center" },
			{ Kind = "Pulse", Parts = { "^aura_ring" }, Speed = 0.5, Min = 0.6, Max = 1 },
			{ Kind = "Swing", Parts = { "^arm" }, Axis = Vector3.zAxis, Angle = 12, Speed = 0.7, Mirror = true },
			{ Kind = "Swing", Parts = { "^flower_" }, Axis = Vector3.zAxis, Angle = 6, Speed = 0.5 },
			{ Kind = "Blink", Parts = { "^eye" }, Every = 3.6 },
		},
	},
	Cosmo = { -- Scarab (wing shards float and flutter, the sun orb turns)
		Body = { Bob = 0.05, BobSpeed = 0.6, Sway = 3, SwaySpeed = 0.35 },
		Moves = {
			{ Kind = "Swing", Parts = { "^wing_shard" }, Axis = Vector3.zAxis, Angle = 14, Speed = 1.6, Mirror = true },
			{ Kind = "Twinkle", Parts = { "^wing_shard" }, Speed = 1.4, Min = 0.6, Max = 1 },
			{ Kind = "Spin", Parts = { "^sun_orb_ring" }, Axis = Vector3.yAxis, Speed = 0.2, Pivot = "Center" },
			{ Kind = "Pulse", Parts = { "^sun_orb_core", "^energy_ring" }, Speed = 0.6, Min = 0.6, Max = 1 },
			{ Kind = "Swing", Parts = { "^antenna" }, Axis = Vector3.xAxis, Angle = 10, Speed = 0.9 },
			{ Kind = "Blink", Parts = { "^eye" }, Every = 3.8 },
		},
	},
	Perfecto = { -- Sphinx Kitten (its headdress floats over its head, sparkles turn round it)
		Body = { Bob = 0.04, BobSpeed = 0.5, Sway = 2, SwaySpeed = 0.3 },
		Moves = {
			{ Kind = "Lift", Parts = { "^headdress", "^circlet", "^uraeus", "^sun_disc" }, Height = 0.12, Speed = 0.5 },
			{ Kind = "Spin", Parts = { "^sparkle" }, Axis = Vector3.yAxis, Speed = 0.15, Pivot = "Root" },
			{ Kind = "Twinkle", Parts = { "^sparkle", "^uraeus_gem" }, Speed = 1.2, Min = 0.3, Max = 1 },
			{ Kind = "Pulse", Parts = { "^aura_ground_ring", "^sun_disc" }, Speed = 0.5, Min = 0.6, Max = 1 },
			{ Kind = "Swing", Parts = { "^tail" }, Axis = Vector3.yAxis, Angle = 18, Speed = 0.8 },
			{ Kind = "Blink", Parts = { "^pupil", "^eye_glow" }, Every = 3.5 },
		},
	},
	TitanJr = {
		Body = { Bob = 0.04, BobSpeed = 0.5, Sway = 2, SwaySpeed = 0.3 },
		Moves = {
			{ Kind = "Swing", Parts = { "^arm_" }, Axis = Vector3.xAxis, Angle = 14, Speed = 0.6, Mirror = true },
			{ Kind = "Lift", Parts = { "^foot_R" }, Height = 0.08, Speed = 0.9 },
			{ Kind = "Lift", Parts = { "^foot_L" }, Height = 0.08, Speed = 0.9, Phase = 0.5 },
			{ Kind = "Pulse", Parts = { "^crack_", "^core_eye" }, Speed = 0.6, Min = 0.55, Max = 1 },
		},
	},
	-- The Neon Egg on its stand: the core pulses on a 1.6s beat (glow 60 to 100%), the lines breathe 15%
	-- (hatch storyboard frame 1, Idle)
	Egg_Alley = {
		Moves = {
			{ Kind = "Pulse", Parts = { "^core" }, Speed = 1 / 1.6, Min = 0.6, Max = 1 },
			{ Kind = "Pulse", Parts = { "^circuit_" }, Speed = 1 / 1.6, Min = 0.85, Max = 1 },
		},
	},
}

Config.PetIdle.Egg_Volcano = Config.PetIdle.Egg_Alley -- (Addendum 5 B2: the re-tinted Neon Egg pulses the same)

-- Daily reward: a 7-day calendar. Claim once per day (days change at midnight UTC).
-- One missed day is forgiven (GraceDays, Addendum 2 step 11); missing more starts you back at day 1. After day 7 it
-- loops back to day 1.
-- Each day can give Coins, Gems, Potions ({ Id, Count } from Config.Potions), a free Egg hatch (an egg Id, hatched at the
-- egg stand) and/or a free Crate (a crate Id from Config.Crates).
-- Owner 2026-10-22: make them very valuable (day 1 15K, day 2 three x2 potions, day 3 500K...). Coin income grows
-- thousands of times over the first hour (sim: ~4K a minute at 4 min, ~100M at 40 min, ~2.5B at 60 min), so a fixed
-- number stops mattering fast: Coins is the least you get, LevelShare = or that share of your next Power Level's
-- price if it's more (PowerLevels.DailyCoins). Sim with ~30 min of play a day: day 1 = ~4 min of bowling, day 3 =
-- ~11 min, day 6 = ~35 min.
-- Owner 2026-10-28: daily rewards follow the player's progress (Shared.Modules.DailyRewards; playtime gifts don't):
--   Coins = the biggest of: Coins x your highest zone's coin pay (x1/4/16/64), LevelShare of your next Power Level,
--   or Minutes of your own bowling income (AwayRate: coins per second over your last 10 minutes of throwing).
--   Egg / Crate = "Zone": your highest open zone's egg / best crate (ByZone). Gems x your zone's Gems.
--   Potions stay the same (a x2 potion already pays more the more you earn).
Config.Daily = {
	Rewards = {
		{ Coins = 15000, LevelShare = 0.25, Minutes = 5, CoreMinutes = 2 },
		{ Potions = { { Id = "CoinSmall", Count = 3 } } },
		{ Coins = 500000, LevelShare = 0.5, Minutes = 12, Gems = 5, CoreMinutes = 4 },
		{ Egg = "Zone", Gems = 10 }, -- a free hatch of your zone's egg at its egg stand
		{ Potions = { { Id = "CoinBig", Count = 1 }, { Id = "XpBig", Count = 1 } } },
		{ Coins = 5000000, LevelShare = 0.5, Minutes = 30, Gems = 15, CoreMinutes = 8 },
		{ Crate = "Zone", Potions = { { Id = "CoinBig", Count = 2 } }, Gems = 25 },
	},
	-- By your highest open zone (ZonesOpen). Zone 1 gets the Neon Egg too (pets open with zone 2; it waits at the stand).
	ByZone = {
		{ Egg = "Alley", Crate = "Basic", Gems = 1 },
		{ Egg = "Alley", Crate = "Gold", Gems = 1.5 },
		{ Egg = "Arcade", Crate = "Champion", Gems = 2 },
		{ Egg = "Skyline", Crate = "SkyGold", Gems = 3 },
	},
	CheckInterval = 30, -- seconds between checks for a new day while playing
	GraceDays = 1, -- days you can skip without losing your place in the 7 days
}

-- Zone milestones (Phase X Part 1): beats between the zone 2 (level 5) and zone 3 (level 12) unlocks.
-- LevelRewards: reaching Level pays its reward once, with a popup (players already past it get nothing back-dated).
--   Coins is the least you get; LevelShare = or that share of your next Power Level's price if it's more (like the
--   daily rewards). Potions = { { Id, Count } } (Config.Potions), Crate = a Config.Crates Id (opened right away).
-- Challenges: repeatable goals shown in a small HUD tracker while you bowl in that Zone (nil Zone = any zone).
--   Kind "StrikeStreak" = Goal strikes in a row (a miss starts it over). Cooldown = seconds before it can be done
--   again after a win (0 = straight away). Reward = like LevelRewards. Add rows to add challenges.
-- Preview: the tracker also shows the next level reward (Phase X Part 1.3).
-- "While you were away" coins (Addendum 2 step 11a): coming back pays Share of the coins per second you were earning
-- from throws over your last RateMinutes of play, for every second away, up to MaxHours (Addendum: capped at 8 hours).
-- Nothing under MinMinutes away. A rebirth starts the measuring again (so pre-rebirth income can't be paid after it).
Config.Away = {
	Enabled = true,
	Share = 0.25, -- a quarter of your playing income per second away (8 hours away = about 2 hours of play)
	MaxHours = 8,
	MinMinutes = 5,
	RateMinutes = 10, -- income measured over this much of the end of your last visit
	PopupDelay = 4, -- seconds after joining before the WELCOME BACK popup (after the daily and zone popups start)
	-- Studio only (Studio tests never save, so you'd never be "away"): every test pretends you were away this long,
	-- earning at least Rate coins per second. nil = off.
	StudioTest = { Hours = 2, Rate = 5000 },
}

-- Brightness pass (POLISH_PLAN.md, 2026-10-28; BrightnessController, client-only lights): the play area gets
-- brighter, the backgrounds keep their mood. A light strip above every lane (from BehindStart studs behind the ball
-- spot to PastPins past the pins, Height up, shining down) + a fill light on your own character. Zone 2 (Neon Lanes)
-- uses the place's Lighting, whose NeonColor saturation went 0.12 -> 0.22 in Studio (Old_Saturation_20261028 attr).
Config.Brightness = {
	Enabled = true,
	Height = 14,
	Width = 12,
	Angle = 70,
	BehindStart = 10,
	PastPins = 4,
	-- per zone (Config.Zones.LaneFolders order); brighter where the zone is darker
	LaneLight = {
		{ Brightness = 1.1, Color = Color3.fromRGB(255, 236, 214) }, -- Back Alley (darkest)
		{ Brightness = 0.7, Color = Color3.fromRGB(236, 230, 255) }, -- Neon Lanes
		{ Brightness = 0.6, Color = Color3.fromRGB(255, 240, 220) }, -- Main Street (already warm and lit)
		{ Brightness = 0.65, Color = Color3.fromRGB(240, 232, 255) }, -- Skyline Lanes (batch A3 2026-10-29, was 0.8)
	},
	PlayerFill = { Brightness = 0.8, Range = 12, Color = Color3.fromRGB(255, 244, 230) },
}

-- Polish v2 Q3: cheap speed wins on every screen (PerfController). Anchored parts in these folders whose longest
-- side is under NoShadowBelow studs stop casting shadows (~1,900 small decor parts measured 2026-11-03).
Config.Perf = {
	Enabled = true,
	NoShadowBelow = 3, -- studs
	Folders = { "SkylineLanes", "SunsetBoardwalk", "JungleFalls", "CanyonOasis" },
	-- Q3 part 2: the old loop's areas (~5,500 parts by the map's middle, 3,700+ studs from every zone, nobody can
	-- get there in the core loop) leave each player's screen HideOldAfter seconds after joining. Client only: the
	-- server keeps them, so old services that look them up still work. false = keep them.
	HideOld = { "MainStreetLanes", "BackAlley", "NeonAlley", "Hub", "Showcase" },
	HideOldAfter = 12, -- seconds
}

-- Coins per minute under the coin counter (polish P1, the green "+12K/min"). Server: AwayService.PerMinute.
-- = coins of your throws in the last WindowMinutes, with the always-on multipliers taken out, x the ones on now
-- (so buying a Power Level or a pet raises it at once). Fewer than MinThrows throws = a guess from a typical throw.
Config.Income = {
	Enabled = true,
	WindowMinutes = 3,
	MinThrows = 3,
	MinSpanSeconds = 20, -- never divide by less than this (a fast first few throws don't spike it)
	GuessPinsPerThrow = 6, -- the guess: 6 pins a throw (Power LV 1's cap) at about 17 throws a minute
	GuessThrowsPerMinute = 17,
}

-- Friend coin bonus (Addendum 2 step 11a): +BonusPerFriend coins for each Roblox friend in your server, up to MaxBonus
-- (FRIENDS row in the multiplier panel)
Config.Friends = {
	Enabled = true,
	BonusPerFriend = 0.1,
	MaxBonus = 0.5,
}

-- Monetization (Addendum 2 section 7, step 12a). Enabled is the MonetizationEnabled switch: the owner flips it.
-- OFF: no STORE button, no popups, no pass perks, nothing can be bought. Robux buys speed, convenience and looks,
-- never skill (PERFECTs can't be bought) and a free player is never blocked.
-- Before switching on: make each game pass and developer product on the Creator Dashboard (Monetization page),
-- paste its number into PassId / ProductId below (0 = not made yet, can't be bought), and set Robux to the price you
-- picked there (the button only shows this number; Roblox charges what the Dashboard says).
-- StudioPreview: in Studio only, the STORE shows even while Enabled is off and every BUY is free and instant
-- (nothing real, and Studio tests don't save). It never does anything in the live game.
Config.Monetization = {
	Enabled = true,
	StudioPreview = true,
	-- Game passes: bought once, kept forever (owner 2026-10-25: more giving than plain 2x coins).
	-- Coins / Xp: multiply every throw's coins / XP (they stack with potions: 2X pass + Mega potion = x8).
	-- Luck: rarer crate balls and pets (see Luck below; the ODDS screens show the boosted chances).
	-- PetSlots: more pets follow you. Hatch: eggs and crates open this many at once when you can pay for them all.
	-- DailyGems: a gift once a day (VIP). Trail: a gold streak behind your rolling ball that everyone sees.
	Passes = {
		{
			Id = "DoubleCoins", -- Id kept from 12a
			PassId = 2058239949,
			Robux = 399,
			-- (Addendum 5 A1: no XP in the loop, so the screen names only the coins)
			Name = if Config.CoreLoop.NoLevels then "2X COINS" else "2X COINS + 2X XP",
			Text = if Config.CoreLoop.NoLevels
				then "Double coins forever. Stacks with potions."
				else "Double coins and XP. Stacks with potions.",
			Coins = 2,
			Xp = 2,
		},
		{
			Id = "VIP",
			PassId = 2061664560,
			Robux = 799,
			Name = "VIP",
			Text = "+25% coins and XP, 25 gems a day, gold trail, [VIP] chat tag.",
			Coins = 1.25,
			Xp = 1.25,
			DailyGems = 25,
			Trail = true,
		},
		{
			Id = "AutoBowl",
			PassId = 2058863916,
			Robux = 499,
			Name = "AUTO BOWL",
			Text = if Config.CoreLoop.Enabled
				then "An AUTO button: it throws for you while you stand on your lane."
				else "An AUTO button: the game bowls for you and every throw is a STRIKE. No PERFECT x2, no streak.",
		},
		{
			Id = "Lucky",
			PassId = 2061610571,
			Robux = 199,
			Name = "LUCKY",
			Text = "x2 luck: Rare and better balls and pets come more often.",
			Luck = 2,
		},
		{
			Id = "SuperLucky",
			PassId = 2060945099,
			Robux = 399,
			Name = "SUPER LUCKY",
			Text = "x4 luck. Stacks with LUCKY for x8.",
			Luck = 4,
		},
		{
			Id = "TripleHatch",
			PassId = 2062270254,
			Robux = 399,
			Name = "TRIPLE HATCH",
			Text = "Hatch 3 eggs at once (if you can pay for 3).",
			Hatch = 3,
		},
		{
			-- Addendum 6 Stage 8: pins per swing x2 (the "Passes" Times slot of Config.CoreLoop.Boosts.Pins).
			-- PassId 0 = not made in Creator Hub yet: hidden in the live game until the owner puts the real ID here.
			Id = "DoublePins",
			PassId = 0,
			Robux = 399,
			Name = "2X PINS",
			Text = "Double pins every swing, forever. Stacks with potions.",
			Pins = 2,
		},
		{
			Id = "PetSlots",
			PassId = 2057495968,
			Robux = 399,
			Name = "+2 PET SLOTS",
			Text = "2 more pets out at once.",
			PetSlots = 2,
		},
	},
	-- Developer products: can be bought again and again (Once = one time only)
	-- Boost = { Potion, Minutes }: that potion's boost runs this much longer, straight away (Config.Potions)
	-- Ball = a ball Id given (a duplicate polishes it, like a crate). Gems = gems given.
	Products = {
		{
			Id = "StarterPack",
			ProductId = 3723601057,
			Robux = 199,
			Name = "STARTER PACK",
			-- (Addendum 4 core loop: you only throw shop balls, so the pack's ball becomes CoreCoinMinutes of ladder income)
			Text = if Config.CoreLoop.Enabled
				then "10 minutes of coins, 30 min of 2X COINS and 100 gems. Once only."
				else "Dumpster Diamond (Rare ball), 30 min of 2X COINS and 100 gems. Once only.",
			Once = true,
			Ball = if Config.CoreLoop.Enabled then nil else "DumpsterDiamond",
			CoreCoinMinutes = 10,
			Boost = { Potion = "CoinSmall", Minutes = 30 },
			Gems = 100,
		},
		-- Boost ladders (owner 2026-10-25; toned down 2026-10-26, owner: x16 for 30 R$ made the passes useless):
		-- 2026-10-28 owner: 3 steps, x2 / x3 / x4; coins 10 / 20 / 50 R$, XP 15 / 30 / 75 R$ (was 4 steps x1.25-x2; the step-4 rows are gone, a player saved
		-- at level 4 just stays MAXED at x4). Bought in order, up to the last step (then MAXED). Ladder = "Coins"
		-- or "Xp", Step = 1-3: the player's saved CoinBoostLevel / XpBoostLevel becomes Step, worth Mult forever
		-- (the step's own Mult, not added up). The store only offers each ladder's next step.
		{ Id = "CoinLadder1", ProductId = 3723601233, Robux = 10, Ladder = "Coins", Step = 1, Mult = 2 },
		{ Id = "CoinLadder2", ProductId = 3723601347, Robux = 20, Ladder = "Coins", Step = 2, Mult = 3 },
		{ Id = "CoinLadder3", ProductId = 3723601535, Robux = 50, Ladder = "Coins", Step = 3, Mult = 4 },
		{ Id = "XpLadder1", ProductId = 3723601619, Robux = 15, Ladder = "Xp", Step = 1, Mult = 2 },
		{ Id = "XpLadder2", ProductId = 3723601701, Robux = 30, Ladder = "Xp", Step = 2, Mult = 3 },
		{ Id = "XpLadder3", ProductId = 3723601776, Robux = 75, Ladder = "Xp", Step = 3, Mult = 4 },
		{
			Id = "CoinBoost", -- Id kept from 12a (the timed boost)
			ProductId = 3723601922,
			Robux = 49,
			Name = "2X COINS - 15 MIN",
			Text = "Double coins for 15 min of play.",
			Boost = { Potion = "CoinSmall", Minutes = 15 },
		},
		{ Id = "GemsSmall", ProductId = 3723602054, Robux = 99, Name = "60 GEMS", Text = "A handful of gems.", Gems = 60 },
		{ Id = "GemsMedium", ProductId = 3723602173, Robux = 399, Name = "300 GEMS", Text = "A bag of gems.", Gems = 300 },
		{ Id = "GemsLarge", ProductId = 3723602254, Robux = 1599, Name = "1,500 GEMS", Text = "A chest of gems.", Gems = 1500 },
		-- Robux looks (step 12b): Cosmetic = the Config.Cosmetics item it unlocks (bought once; looks only)
		{ Id = "LookGalaxyTrail", ProductId = 3723602449, Robux = 149, Name = "GALAXY TRAIL", Cosmetic = "GalaxyTrail" },
		{ Id = "LookLegendBanner", ProductId = 3723602590, Robux = 149, Name = "LEGEND BANNER", Cosmetic = "LegendBanner" },
		{ Id = "LookGalaxyBlast", ProductId = 3723602682, Robux = 149, Name = "GALAXY BLAST", Cosmetic = "GalaxyBlast" },
		{ Id = "LookGoldLane", ProductId = 3723602758, Robux = 149, Name = "GOLD LANE", Cosmetic = "GoldLane" },
	},
	-- Luck (LUCKY passes): every rarity from LuckFrom up gets its chance multiplied by the player's luck, then all
	-- chances are scaled back to 100% (so commons drop a little). Pity and exact guarantees don't change.
	LuckFrom = "Rare",
	StarterMissStreak = 6, -- the Starter Pack popup shows once, only after this many throws in a row with no strike...
	QuietSeconds = 3, -- ...at a quiet moment: this long after the player's last throw (never mid-throw)
	-- Offer popups (Addendum 2 section 7, step 12b-2): a soft offer at a natural moment, always with NO THANKS.
	-- HardStop: you walk up to a locked zone (its glowing wall or the elevator): the next XP BOOST step to reach the
	-- level sooner (or the 2X COINS + 2X XP pass once the ladder is maxed); once per zone per visit.
	-- RarePull: a crate ball this rare or better: a trail look for it (one matching the ball's style first, then the
	-- cheapest you don't own; gem looks only when you can pay for them).
	-- Rules for both: none in the first AfterMinutes of play in total, none during onboarding, at most one popup per
	-- GapSeconds (the Starter Pack popup counts too), at a quiet moment (QuietSeconds after a throw, no crate opening).
	Offers = {
		Enabled = true,
		AfterMinutes = 10,
		GapSeconds = 300,
		HardStop = true,
		HardStopRange = 14, -- studs from a locked zone's wall that count as walking up to it
		RarePull = "Rare",
		PullDelay = 5, -- seconds after the pull before the offer is sent (the crate reveal plays first)
	},
	ChatTag = "[VIP]", -- before VIP owners' names in chat (gold)
	TrailColor = Color3.fromRGB(255, 200, 40), -- old VIP gold trail colour (since 12b the VIP GOLD look in Config.Cosmetics)
	KeepPurchaseIds = 50, -- how many recent purchase ids each save remembers
}

-- Cosmetics (Addendum 2 section 7, step 12b): looks only, they never change coins, XP or throws.
-- Bought with gems (Gems = price) or Robux (Product = a Config.Monetization.Products Id), kept forever, one worn per
-- kind. They live in the store's LOOKS section, so they show while the store is on (Config.Monetization).
-- Kinds: Trail = a streak behind your rolling ball, Banner = a flag over your pins when you strike,
-- PinFx = an extra blast when your ball hits the pins, LaneSkin = your own lane's floor. Everyone sees them.
-- Colors: the look's colours (trails and blasts blend through them; a banner uses 1 = fill, 2 = text);
-- Word = a banner's text; Material = a lane skin's floor material. Style + Tier (trails) = the Config.BallVfx.TrailStyles
-- style it draws and how rich (4 Epic .. 6 Mythic; pricier = richer). Vip = comes with the VIP pass (can't be bought).
-- A VIP who wears no trail gets the VIP gold trail.
Config.Cosmetics = {
	Enabled = true,
	Kinds = {
		{ Id = "Trail", Name = "TRAILS", Label = "TRAIL" },
		{ Id = "Banner", Name = "STRIKE BANNERS", Label = "BANNER" },
		{ Id = "PinFx", Name = "PIN BLASTS", Label = "PIN BLAST" },
		{ Id = "LaneSkin", Name = "LANE SKINS", Label = "LANE SKIN" },
	},
	Items = {
		-- Trails
		{ Id = "FireTrail", Kind = "Trail", Name = "FIRE TRAIL", Gems = 40, Style = "Fire", Tier = 4,
			Text = "Real flames, flying embers and smoke, and a burning streak on the lane.",
			Colors = { Color3.fromRGB(255, 220, 60), Color3.fromRGB(255, 70, 20) } },
		{ Id = "IceTrail", Kind = "Trail", Name = "ICE TRAIL", Gems = 120, Style = "Ice", Tier = 5,
			Text = "Snowflakes, frost mist and ice shards. The lane freezes behind your ball.",
			Colors = { Color3.fromRGB(230, 250, 255), Color3.fromRGB(60, 190, 255) } },
		{ Id = "ToxicTrail", Kind = "Trail", Name = "TOXIC TRAIL", Gems = 300, Style = "Toxic", Tier = 5,
			Text = "Bubbling, dripping toxic goo and green fumes, with a slime trail on the lane.",
			Colors = { Color3.fromRGB(200, 255, 80), Color3.fromRGB(40, 200, 40) } },
		{ Id = "GalaxyTrail", Kind = "Trail", Name = "GALAXY TRAIL", Product = "LookGalaxyTrail", Style = "Galaxy", Tier = 6,
			Text = "Twinkling stars and glowing nebula clouds, plus Mythic shock rings.",
			Colors = { Color3.fromRGB(150, 70, 255), Color3.fromRGB(255, 80, 200), Color3.fromRGB(70, 220, 255) } },
		{ Id = "VipGold", Kind = "Trail", Name = "VIP GOLD", Vip = true, Style = "Gold", Tier = 6,
			Text = "Gold coins, glitter and a golden shine. Comes with the VIP pass.",
			Colors = { Color3.fromRGB(255, 240, 160), Color3.fromRGB(255, 200, 40) } },
		-- Strike banners
		{ Id = "BoomBanner", Kind = "Banner", Name = "BOOM! BANNER", Gems = 40, Word = "BOOM!",
			Text = "BOOM! pops over your pins on every clear.",
			Colors = { Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 230, 60) } },
		{ Id = "EasyBanner", Kind = "Banner", Name = "TOO EASY BANNER", Gems = 120, Word = "TOO EASY",
			Text = "A name tag over your head.",
			Colors = { Color3.fromRGB(40, 140, 255), Color3.fromRGB(255, 255, 255) } },
		{ Id = "CrushedBanner", Kind = "Banner", Name = "CRUSHED BANNER", Gems = 300, Word = "CRUSHED!",
			Text = "Pink and purple, loud and proud.",
			Colors = { Color3.fromRGB(170, 60, 255), Color3.fromRGB(255, 120, 220) } },
		{ Id = "LegendBanner", Kind = "Banner", Name = "LEGEND BANNER", Product = "LookLegendBanner", Word = "LEGEND",
			Text = "Black and gold, for legends only.",
			Colors = { Color3.fromRGB(25, 20, 30), Color3.fromRGB(255, 200, 40) } },
		-- Pin blasts
		{ Id = "ConfettiBlast", Kind = "PinFx", Name = "PARTY BLAST", Gems = 40, Text = "Every hit pops like a party.",
			Colors = { Color3.fromRGB(255, 80, 120), Color3.fromRGB(255, 220, 60), Color3.fromRGB(70, 220, 255) } },
		{ Id = "FrostBlast", Kind = "PinFx", Name = "FROST BLAST", Gems = 120, Text = "Pins burst into ice.",
			Colors = { Color3.fromRGB(230, 250, 255), Color3.fromRGB(80, 200, 255) } },
		{ Id = "ToxicBlast", Kind = "PinFx", Name = "TOXIC BLAST", Gems = 300, Text = "A green splash.",
			Colors = { Color3.fromRGB(200, 255, 80), Color3.fromRGB(40, 200, 40) } },
		{ Id = "GalaxyBlast", Kind = "PinFx", Name = "GALAXY BLAST", Product = "LookGalaxyBlast",
			Text = "A burst of stars and space dust.",
			Colors = { Color3.fromRGB(150, 70, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(70, 220, 255) } },
		-- Lane skins
		{ Id = "CandyLane", Kind = "LaneSkin", Name = "CANDY LANE", Gems = 40, Text = "Your lane turns pink.",
			Colors = { Color3.fromRGB(255, 150, 200) }, Material = Enum.Material.SmoothPlastic,
			-- Decor (LookController): picture layers on every plate (Tile = studs per repeat), an Edge strip on
			-- each side of the lane and Arrows = a chevron of pictures near the foul line. Images in AssetSlots.
			Decor = {
				Textures = { { Image = "CandySwirl", Tile = 7, Transparency = 0.45 }, { Image = "CandySprinkles", Tile = 4.5 } },
				Edge = { Image = "CandyCane", Tile = 1.4, Width = 0.35 },
				Arrows = { Image = "CandyPeppermint", Count = 5, Size = 1.3, FromFoul = 12 },
			} },
		{ Id = "IceLane", Kind = "LaneSkin", Name = "ICE LANE", Gems = 120, Text = "Bowl on a frozen lake.",
			Colors = { Color3.fromRGB(170, 225, 255) }, Material = Enum.Material.Ice,
			Decor = {
				Textures = { { Image = "IceCracks", Tile = 9, Transparency = 0.15 } },
				Edge = { Image = "IceFrost", Tile = 2, Width = 0.45 },
				Arrows = { Image = "IceSnowflake", Count = 5, Size = 1.7, FromFoul = 12 },
			},
			Glow = { Color = Color3.fromRGB(170, 230, 255), EdgeWidth = 1.4, EdgeTransparency = 0.6, Height = 0.7,
				Inset = 0.25, Brightness = 2, Glints = 1.5, GlintSize = 0.22 } },
		{ Id = "LavaLane", Kind = "LaneSkin", Name = "LAVA LANE", Gems = 300, Text = "Hot rock under your feet.",
			Colors = { Color3.fromRGB(120, 40, 30) }, Material = Enum.Material.CrackedLava,
			Decor = {
				Textures = { { Image = "LavaCracks", Tile = 8 } },
				Edge = { Image = "LavaFlow", Tile = 3, Width = 0.4, Color = Color3.fromRGB(200, 70, 20), Material = Enum.Material.Neon },
			},
			-- Embers drift up off the lane (GlintSpeed / GlintLife = { min, max })
			Glow = { Color = Color3.fromRGB(255, 120, 40), EdgeWidth = 1.6, EdgeTransparency = 0.55, Height = 0.8,
				Inset = 0.25, Brightness = 2, Glints = 3, GlintSize = 0.2, GlintSpeed = { 1, 2.2 }, GlintLife = { 1.2, 2 } } },
		{ Id = "GoldLane", Kind = "LaneSkin", Name = "GOLD LANE", Product = "LookGoldLane", Text = "Pure shiny gold.",
			Colors = { Color3.fromRGB(255, 195, 60) }, Material = Enum.Material.Foil,
			-- Very faint gold aura (LookController): a soft upright glow band along both edges + a rare glint.
			-- EdgeWidth = band height, Height = its middle above the lane, Inset = studs in from the edge.
			Glow = { Color = Color3.fromRGB(255, 205, 90), EdgeWidth = 1.4, EdgeTransparency = 0.55, Height = 0.7,
				Inset = 0.25, Brightness = 2, Glints = 1.5, GlintSize = 0.22 } },
	},
	LaneParts = { "LaneFloor", "PinDeck", "Approach" }, -- the lane parts a lane skin repaints
	BannerTime = 2.2, -- seconds a strike banner stays up
	BannerHeight = 9, -- studs above the head pin
	BlastSize = 1, -- pin blast strength (1 = about a strike crash's own burst)
}

Config.Milestones = {
	Enabled = true,
	LevelRewards = {
		{ Level = 7, Coins = 50000, LevelShare = 0.3, Crate = "Bronze", CoreMinutes = 2 }, -- D2: shares were 0.1 / 0.15 (Power Levels got ~10x cheaper)
		{ Level = 9, Coins = 150000, LevelShare = 0.5, Potions = { { Id = "CoinSmall", Count = 2 } }, CoreMinutes = 3 },
	},
	Challenges = {
		{
			Id = "NeonStreak3",
			Zone = 2,
			Kind = "StrikeStreak",
			Goal = 3,
			Text = "GET %d STRIKES IN A ROW", -- %d = Goal
			Cooldown = 180,
			Reward = { Crate = "Bronze" },
			RewardText = "FREE BRONZE CRATE",
		},
	},
	Preview = true, -- show "NEXT: LV 9 REWARD" under the challenge (false = hide it)
	PopupTime = 3.5, -- seconds a level reward popup stays up
	WelcomeBackSeconds = 4, -- seconds the small WELCOME BACK text (away coins) stays before it fades out
}

-- Potions (owner 2026-10-22): drink one for a 15 minute boost. Coin potions multiply coins, XP potions multiply XP.
-- Small = x2 and common, Big (MEGA) = x4 and rarer (playtime rewards hand them out; Studio: TEST: POTIONS button).
-- Timers only run while you play (they pause when you leave). Drinking another of the same potion adds its time.
-- Coin and XP boosts multiply together. Within one kind only the strongest running potion counts (x4 beats x2,
-- they never make x8); the weaker one's timer waits until the stronger one runs out, so no minutes are wasted.
Config.Potions = {
	List = {
		{
			Id = "CoinSmall",
			Name = "COIN POTION",
			Boost = "Coins",
			Multiplier = 2,
			Minutes = 15,
			Big = false,
			Color = Color3.fromRGB(255, 200, 40),
		},
		{
			Id = "CoinBig",
			Name = "MEGA COIN POTION",
			Boost = "Coins",
			Multiplier = 4,
			Minutes = 15,
			Big = true,
			Color = Color3.fromRGB(255, 140, 20),
		},
		{
			Id = "XpSmall",
			Name = "XP POTION",
			Boost = "XP",
			Multiplier = 2,
			Minutes = 15,
			Big = false,
			Color = Color3.fromRGB(70, 230, 255),
		},
		{
			Id = "XpBig",
			Name = "MEGA XP POTION",
			Boost = "XP",
			Multiplier = 4,
			Minutes = 15,
			Big = true,
			Color = Color3.fromRGB(190, 90, 255),
		},
	},
	MaxMinutes = 600, -- one potion's timer never stacks past this many minutes
	Tick = 1, -- seconds between timer updates
}

-- Playtime rewards (owner 2026-10-22): a free gift every 15 minutes of play, 12 of them. Tap the GIFTS button and
-- CLAIM a gift once its timer is done.
-- Batch B4 (owner 2026-10-29): the first gift is ready the moment you join (Minutes = 0), then one every 15 minutes.
-- The whole set is ONCE A DAY (days change at midnight UTC, like the daily reward): the clock and the claimed gifts are
-- saved (PlaytimeDay/PlaytimeSeconds/PlaytimeGot, save v29), so leaving and coming back the same day carries on where
-- you were; a new day starts a fresh set. Gifts grow with your progress (Shared.Modules.PlaytimeRewards):
--   Coins = like the daily reward's coins: the biggest of Coins x your zone's coin pay, LevelShare of your next Power
--     Level's price, or IncomeMinutes of your own bowling income (AwayRate).
--   Potion = a Config.Potions Id, x your zone's Potions count (ByZone). Egg = "Zone": your highest zone's egg.
--   Crate = 1, 2 or 3: your highest zone's low / middle / best crate (ByZone Crates), opened right away.
Config.Playtime = {
	Enabled = true,
	Rewards = {
		{ Minutes = 0, Coins = 500, LevelShare = 0.1, IncomeMinutes = 3, CoreMinutes = 1 }, -- the join gift
		{ Minutes = 15, Potion = "CoinSmall" },
		{ Minutes = 30, Egg = "Zone" },
		{ Minutes = 45, Potion = "XpSmall" },
		{ Minutes = 60, Crate = 1 },
		{ Minutes = 75, Potion = "CoinSmall" },
		{ Minutes = 90, Potion = "XpBig" },
		{ Minutes = 105, Crate = 2 },
		{ Minutes = 120, Potion = "CoinBig" },
		{ Minutes = 135, Coins = 50000, LevelShare = 0.5, IncomeMinutes = 15, CoreMinutes = 8 },
		{ Minutes = 150, Potion = "CoinBig" },
		{ Minutes = 165, Crate = 3 },
	},
	-- By your highest open zone (ZonesOpen). Zone 1 gets the Neon Egg (pets open with zone 2; it waits at the stand)
	-- and a Gold Crate as its best gift, like the old 3-hour gift.
	ByZone = {
		{ Egg = "Alley", Crates = { "Basic", "Basic", "Gold" }, Potions = 1 },
		{ Egg = "Alley", Crates = { "Bronze", "Silver", "Gold" }, Potions = 1 },
		{ Egg = "Arcade", Crates = { "Gold", "League", "Champion" }, Potions = 2 },
		{ Egg = "Skyline", Crates = { "SkyBronze", "SkySilver", "SkyGold" }, Potions = 2 },
	},
	SaveEvery = 30, -- seconds between saving the clock (and checking for a new day)
}

-- Daily spin wheel (owner 2026-10-22): a big wheel you walk up to in Neon Lanes (zone 2), at the far end of the east
-- walkway beside the lanes (the back wall leaves no room behind the pins). One free spin a day (days change at
-- midnight UTC, like the daily reward). Built in code on each player's screen (SpinController); the server
-- (SpinService) checks you stand by it, rolls the slice and hands out the prize before the wheel even turns.
-- Slices: Potion (a Config.Potions Id), Egg (a free hatch at the egg stand), Crate (opened right away; a crate from a
-- zone you haven't reached comes as your zone's), Ball = a ball of that rarity from that crate (shown as SECRET
-- BALL), Pet = a pet of that rarity from that egg (shown as SECRET PET). Chance = % (adds up to 100); the slices are
-- drawn the same size whatever their chance, like every simulator wheel.
-- Phase X: SECRET BALL and SECRET PET give an Epic now (was Legendary), the best rarity zone 2 has (Config.ZoneRarity).
Config.Spin = {
	Enabled = true,
	-- Batch B3: tell players about the wheel. While today's spin is waiting (and zone 2 is open) a FREE SPIN! marker
	-- with a bobbing arrow floats over the wheel, seen through walls from MarkerRange studs; the first time a session you
	-- come within ToastRange studs, a toast says so.
	Marker = true,
	MarkerText = "FREE SPIN",
	MarkerRange = 160,
	ToastRange = 90,
	ToastText = "FREE SPIN READY. FOLLOW THE ARROW",
	Zone = 2, -- you need this zone open to use it (it stands inside the zone 2 building anyway)
	Center = Vector3.new(51, 10.5, -73.5), -- the middle of the wheel
	Facing = Vector3.new(0, 0, 1), -- the wheel's face looks this way (south, back toward the lobby)
	Radius = 6.5,
	UseRange = 16, -- studs (flat) from the middle of the wheel the server accepts a spin from
	PromptRange = 12,
	SpinSeconds = 5.5,
	Turns = 6, -- whole turns before it slows onto the prize
	CheckInterval = 30, -- seconds between "is it a new day?" checks while playing
	Slices = {
		{ Label = "COIN POTION", Potion = "CoinSmall", Chance = 24, Color = Color3.fromRGB(255, 190, 40) },
		{ Label = "SUNSET EGG", Egg = "Alley", Chance = 10, Color = Color3.fromRGB(255, 122, 92) }, -- (was NEON EGG until 2026-11-03)
		{ Label = "XP POTION", Potion = "XpSmall", Chance = 22, Color = Color3.fromRGB(60, 220, 255) },
		{ Label = "BRONZE CRATE", Crate = "Bronze", Chance = 16, Color = Color3.fromRGB(205, 125, 60) },
		{ Label = "MEGA COIN", Potion = "CoinBig", Chance = 10, Color = Color3.fromRGB(255, 130, 20) },
		{
			Label = "SECRET BALL",
			Ball = "Epic",
			Crate = "Gold",
			Chance = 0.5,
			Secret = true,
			Color = Color3.fromRGB(255, 215, 60),
		},
		{ Label = "MEGA XP", Potion = "XpBig", Chance = 8, Color = Color3.fromRGB(170, 80, 255) },
		{ Label = "SILVER CRATE", Crate = "Silver", Chance = 8.5, Color = Color3.fromRGB(190, 200, 225) },
		{
			Label = "SECRET PET",
			Pet = "Epic",
			Egg = "Alley",
			Chance = 1,
			Secret = true,
			Color = Color3.fromRGB(255, 215, 60),
		},
	},
}

-- Leaderboards (OrderedDataStores). Boards are read every RefreshInterval and
-- each player's scores are written every WriteInterval and when they leave, never per throw.
-- Stat = the saved player value the board ranks. Weekly boards start fresh every Monday 00:00 UTC.
Config.Leaderboards = {
	-- "_A4": fresh boards for the Addendum 4 reset (owner 2026-11-01); "" brings the old boards back
	StoreSuffix = "_A4",
	RefreshInterval = 90,
	WriteInterval = 120,
	FetchSize = 100, -- how many top scores to read; your position shows as "100+" below this
	ShowTop = 10,
	Boards = {
		{
			Id = "Pins",
			Title = "MOST PINS EVER",
			Column = "PINS",
			Stat = "LifetimePins",
			Store = "LB_LifetimePins",
		},
		{
			-- Stage 3c: the core loop has no strike streaks (was BEST STRIKE STREAK, BestStreak, LB_BestStreak)
			-- Addendum 5 step C: MOST REBIRTHS (was MOST COINS EARNED, LifetimeCoins / LB_LifetimeCoins; that stat is
			-- still saved, and COINS THIS WEEK stays)
			Id = "Streak", -- (the Studio panel is still named Streak)
			Title = "MOST REBIRTHS",
			Column = "REBIRTHS",
			Stat = "Rebirths",
			Store = "LB_Rebirths",
		},
		{
			Id = "Weekly",
			Title = "COINS THIS WEEK",
			Column = "COINS",
			ShowCoin = true, -- coin icon next to the top 3 scores and your own
			Stat = "WeeklyCoins",
			Store = "LB_WeeklyCoins",
			Weekly = true,
		},
	},
}

-- Playtest analytics (Roblox AnalyticsService, results in the Creator Dashboard → Analytics).
-- OnboardingSteps is the first-session funnel, in order; Roblox counts each step once per player.
Config.Analytics = {
	Enabled = true,
	OnboardingSteps = {
		"Joined",
		"First Throw",
		"First Strike",
		"Double Strike",
		"Opened Crate",
		"Equipped Ball",
		"Ranked Up",
		"Bought Power Level",
		"Gift Crate",
		"Saw Legends",
		"Tenth Throw", -- Addendum 4 core loop instrumentation (once per player)
		"First Sell",
		"Bought Ball",
	},
	PlayTimeInterval = 30, -- seconds between adding play time to the save
	-- Every custom event name the game logs (MASTER_PLAN.md section 7). A name not on this list prints a warning in
	-- Studio, so typos get caught. Rows marked "later" are stubs: the milestone that adds the system starts logging them.
	Events = {
		"SessionStart",
		"SessionEnd", -- value = session minutes; labels = last action before leaving, minutes played in total
		"Throw", -- value = pins; labels = tier, ball
		"FirstCoins",
		"TutorialStep", -- Polish v2 tutorial: value = steps done; labels = step Id
		"StreakRecord", -- value = new best strike streak
		"RankUp", -- value = new rank; labels = rank name
		"LevelUp", -- value = new rank level (1-60)
		"CrateOpened", -- labels = crate, rarity, New/Duplicate
		"DailyClaimed", -- value = day
		"TrialFinished",
		"Purchase", -- value = minutes played in total; labels = kind (Crate/Ball/Egg), item  (balls and eggs: later)
		"ZoneUnlocked", -- later (Milestone 12)
		"LuckyThrow", -- later (Milestone 13)
		"MascotHatched", -- value = eggs hatched so far; labels = egg, rarity, mascot
		"MascotMerged", -- (Addendum 5 B2: the roof fusion machine) value = 1; labels = mascot, rarity
		"BossDefeated", -- later (Milestone 15)
		"BossTrip", -- boarded the Pin Titan helicopter (Config.Boss)
		"BossWon", -- labels = reward tier
		"Achievement", -- value = tier claimed; labels = achievement Id (Profile panel, Polish P5)
		"BossDrop", -- the boss-only drop; labels = its Id
		"BossLost", -- the Titan escaped (time ran out); labels = reward tier
		"PityHit", -- labels = crate, rarity
		"PerfectRate", -- value = PERFECT % of the session's throws (assisted first throw left out); labels = throws, perfects
		"OfferShown", -- an offer popup was sent (Config.Monetization.Offers); labels = HardStop/Look, item Id
		"PolishLevel", -- value = new Polish level; labels = ball
		"PotionUsed", -- value = minutes left on that potion after drinking; labels = potion
		"Fever", -- FEVER MODE started (Config.Fever, batch D4); value = streak that started it
		"LaneEvent", -- a lane event was thrown at (Config.LaneEvents, batch D5); value = 1 won / 0 missed; labels = event
		"PlaytimeClaimed", -- value = the gift's minute mark; labels = Potion/Egg/Crate, item
		"SpinWheel", -- value = the slice number; labels = Potion/Egg/Crate/Ball/Pet, item
		"Rebirth", -- later (Milestone 17)
		"QuestCompleted", -- later (Milestone 18)
		-- Addendum 4 core loop instrumentation (Config.CoreLoop)
		"Sell", -- value = coins sold; labels = sells ever, session seconds
		"CoreMilestone", -- value = seconds played in total when it happened; labels = FirstThrow/TenthThrow/FirstSell
		"BallBought", -- value = seconds played in total; labels = ball, how (Crate/Shop/...)
		"LastAction", -- value = seconds from the last throw or sell to leaving; labels = what it was
		-- Addendum 5 step E pacing (Config.Pacing)
		"Pacing", -- value = seconds of play into the run; labels = Ball3/Bag2/Slot4/Egg_Alley/Rebirth1/BackToIncome, R<rebirths>, minutes played in total
		"PacingIncome", -- value = coins a minute just before a rebirth; labels = BeforeRebirth<n>
	},
}

-- ================================================================================================
-- SIMULATOR ECONOMY (MASTER_PLAN.md section 3, with STRIKE_LEGENDS_ADDENDUM_1.md on top). The economy simulator (ServerStorage.Tools.EconomySim)
-- runs on these numbers today. The live game moves onto them one milestone at a time: zones, Power Levels
-- and ranks in Milestone 12, streak/lucky in 13, mascots in 14, bosses in 15, crate tiers in 16 and
-- rebirth in 17. When a table goes live, the old table it replaces (Config.Ranks, Config.Crates, ...) goes.
-- Tuning: change a number here, re-run the simulator, compare with Economy.Timeline (MASTER_PLAN.md section 8).
-- ================================================================================================
-- Zone worlds (step 9a). Each zone is its own 6-lane area in Workspace (Folder = its Model).
-- Zone 1 Back Alley (Workspace.BackAlley, outside behind the lobby) is where everyone bowls for now;
-- Neon Lanes (the old alley inside the building) opens in the next part of step 9a.
-- Look = the lighting your screen uses while your character is inside the zone's Area box
-- (centre + size in studs); anywhere else (the lobby, Neon Lanes) keeps the normal Lighting.
Config.Zones = {
	LaneFolders = { "BackAlley", "NeonAlley", "MainStreetLanes", "SkylineLanes" }, -- every Workspace model that holds lanes, in zone order
	AssignFolder = "BackAlley", -- new lanes are handed out here
	BuiltZones = 4, -- zones that exist in the world so far (crates of later zones stay locked)
	-- Zones you walk into and claim a lane in (zone 2+). Locked (rank level < Config.Economy.Zones Rank): a glowing
	-- wall (Wall boxes, only on your screen) keeps you out, and the server walks you back out to KickTo.
	-- Unlocked: step onto any OPEN lane in the Area to claim it; it's yours until you leave the Area for LeaveGrace
	-- seconds (or leave the game). Your Back Alley lane stays yours the whole time.
	-- Owner 2026-10-21: zone 2 = the whole building (lobby too, with the kiosk, egg stand, leaderboards and vault):
	-- below level 5 you can't even walk in, the wall plugs the Back Alley door.
	Gated = {
		{
			Zone = 2,
			Folder = "NeonAlley",
			Area = { Center = Vector3.new(0, 12, -11.5), Size = Vector3.new(120, 30, 135) }, -- inside the building walls
			Walls = { -- centre + size in studs: the door from the Back Alley into the lobby
				{ Center = Vector3.new(54, 7, 56), Size = Vector3.new(8, 12, 2) },
			},
			WallColor = Color3.fromRGB(255, 60, 210),
			KickTo = Vector3.new(54, 4, 63), -- Back Alley, just outside the door
			Arrival = Vector3.new(0, 5, 36), -- "TAKE ME THERE" puts you here: on the lobby spawn circle (Hub.SpawnPad), facing the lanes
			LeaveGrace = 2,
		},
		-- Zone 3 (2026-10-22): Main Street Lanes, the owner's design built beside the lobby's east wall
		-- (Workspace.MainStreetLanes, same length as the lobby). A door in the lobby's east wall (between the
		-- leaderboards and the crate kiosk) leads down a short hallway into the bowler end.
		{
			Zone = 3,
			Folder = "MainStreetLanes",
			Area = { Center = Vector3.new(120, 12, -11.5), Size = Vector3.new(95, 30, 139) }, -- inside its walls
			Walls = { -- the lobby's east door (just in front of the doorway, on the lobby side)
				{ Center = Vector3.new(59.8, 7, 12), Size = Vector3.new(0.4, 12, 8) },
			},
			SignFace = Enum.NormalId.Left, -- the lock sign faces west, into the lobby
			WallColor = Color3.fromRGB(224, 165, 38),
			KickTo = Vector3.new(52, 4, 12), -- back in the lobby, in front of the door
			Arrival = Vector3.new(120, 4, 42.8), -- behind the bowler seats, facing the lanes
			LeaveGrace = 2,
		},
		-- Zone 4 (2026-10-22): Skyline Lanes, the owner's rooftop design built big (x7 the design's meters) on top of a
		-- tower far north of the lobby (Workspace.SkylineLanes, roof top at y 848). The only way up is the elevator at
		-- the east end of Main Street Lanes' back walkway (Config.Elevators); the wall covers its doors while locked.
		{
			Zone = 4,
			Folder = "SkylineLanes",
			Area = { Center = Vector3.new(0, 870, -3500), Size = Vector3.new(220, 60, 236) }, -- the whole roof
			Walls = { -- in front of the Main Street Lanes elevator doors
				{ Center = Vector3.new(165, 7.5, 46), Size = Vector3.new(0.4, 13, 17) },
			},
			SignFace = Enum.NormalId.Left, -- the lock sign faces west, down the walkway
			WallColor = Color3.fromRGB(255, 79, 139),
			KickTo = Vector3.new(158, 4, 46), -- Main Street Lanes, in front of the elevator
			Arrival = Vector3.new(81, 852, -3412), -- just out of the rooftop elevator, facing the pins
			LeaveGrace = 2,
		},
	},
	ClaimCheck = 0.25, -- seconds between the server's "who stands where" checks
	LookBlend = 0.6, -- seconds to fade between looks
	-- Polish v2 L3 lighting recipe for the outdoor zones (keep new looks inside these ranges): ClockTime 13-17
	-- (shadows that read on the lane), Brightness 1.8-2.4, Exposure -0.15..0 (cream/white/sand must not blow out),
	-- Ambient 90-130 per channel and OutdoorAmbient tinted by the zone's sky (never flat grey), Saturation 0.18-0.25,
	-- Contrast 0.08-0.14, HazeDensity 0.22-0.32, Haze 0.35-1, Bloom 0.05-0.08 (UI and neon must not haze).
	-- The lane, pins, ball and player stay brighter and more saturated than the background.
	Worlds = {
		{
			Id = "StarterAlley",
			Folder = "BackAlley",
			Area = { Center = Vector3.new(0, 20, 152), Size = Vector3.new(132, 60, 190) },
			Look = {
				Ambient = Color3.fromRGB(18, 18, 26),
				OutdoorAmbient = Color3.fromRGB(22, 22, 32),
				Exposure = -0.2, -- Lighting.ExposureCompensation here (place default 0, was 0.15 before 2026-10-22); lower = darker
				Saturation = -0.08, -- brightness pass 2026-10-28: more colour (was -0.22)
				Contrast = 0.06,
				Tint = Color3.fromRGB(214, 218, 240),
				HazeColor = Color3.fromHex("4b4a5c"),
				HazeDecay = Color3.fromHex("3a3936"),
				HazeDensity = 0.32,
				Haze = 1.2,
				Bloom = 0.12,
			},
			Flicker = {
				Path = { "NeonSign", "Letter_N_broken" },
				Color = Color3.fromHex("ff4fb0"),
				Dim = Color3.fromHex("7a3a5e"),
			},
		},
		{
			-- The design's mood: bright, warm and clean indoors, a light warm haze (#FFE9C7), no neon
			Id = "MainStreetLanes",
			Folder = "MainStreetLanes",
			Area = { Center = Vector3.new(120, 12, -11.5), Size = Vector3.new(95, 30, 139) },
			Look = {
				-- 2026-10-25 lighting pass: ceiling was glaring (was Ambient 70,58,46 / Outdoor 60,52,44 / Exposure -0.1;
				-- the 12 ceiling Lamp lights went 0.9 -> 0.65 in Studio, Old_Brightness_20261025 attr)
				Ambient = Color3.fromRGB(56, 46, 37),
				OutdoorAmbient = Color3.fromRGB(48, 42, 35),
				Exposure = -0.25,
				Saturation = 0.2, -- brightness pass 2026-10-28 (was 0.1)
				Contrast = 0.1,
				Tint = Color3.fromRGB(255, 246, 232),
				HazeColor = Color3.fromHex("FFE9C7"),
				HazeDecay = Color3.fromHex("E8C9A0"),
				HazeDensity = 0.03,
				Haze = 0.1,
				Bloom = 0.12,
			},
		},
		{
			-- Addendum 4 (2026-11-01): the launch zone is a bright, sunny, saturated DAYTIME rooftop (was a night
			-- rooftop over a purple city: Ambient 62,56,88 / Outdoor 72,66,102 / Exposure -0.15 / Saturation 0.22 /
			-- Tint 236,228,255 / Haze 5B4A8A>FF9F6B 0.25, 0.5 / Bloom 0.15). ClockTime + Brightness set the sun.
			Id = "SkylineLanes",
			Folder = "SkylineLanes",
			Area = { Center = Vector3.new(0, 870, -3500), Size = Vector3.new(220, 60, 236) },
			-- Polish v2 L2: a later sun (longer shadows that read on the lane, the tower's front in shade), a sky-blue
			-- fill in the shadows instead of grey, less exposure so cream and white don't blow out, more contrast,
			-- a thinner haze. Was ClockTime 14, Brightness 2.4, Ambient 120,128,140, Outdoor 150,160,175, Exposure
			-- 0.1, Saturation 0.25, Contrast 0.08, Haze density 0.22 / 0.6, Bloom 0.08.
			Look = {
				ClockTime = 15.3,
				Brightness = 2,
				Ambient = Color3.fromRGB(112, 110, 106),
				OutdoorAmbient = Color3.fromRGB(136, 156, 190),
				Exposure = -0.05,
				Saturation = 0.2,
				Contrast = 0.14,
				Tint = Color3.fromRGB(255, 252, 240),
				HazeColor = Color3.fromHex("BFE3FF"),
				HazeDecay = Color3.fromHex("FFF1D6"),
				HazeDensity = 0.26,
				Haze = 0.35,
				Bloom = 0.06,
			},
		},
	},
}

-- Addendum 6 Stage 4: the outdoor zones 2-4 get their own sunny look (without a row here a player standing in them got
-- the place's night lighting). Area = the zone's ground round zone 1's layout, moved by its Offset. Look = the
-- rooftop's daytime look unless the zone's Config.CoreLoop.Zones row has its own LookChanges. Hide = models this
-- screen hides (LocalTransparencyModifier, nothing else changes) while you stand there: the rooftop's city, its
-- ground and its tower, and the old switched-off zones, which otherwise show across the open sea.
do
	local roofLook
	for _, world in Config.Zones.Worlds do
		if world.Id == "SkylineLanes" then
			roofLook = world.Look
		end
	end
	local far = {
		{ "SkylineLanes", "City" }, { "SkylineLanes", "Ground" }, { "SkylineLanes", "Design", "roof" },
		{ "SkylineLanes", "Design", "floodlights" }, { "SkylineLanes", "Design", "zone_sign" },
		{ "BackAlley" }, { "NeonAlley" }, { "MainStreetLanes" }, { "Hub" }, { "Leaderboards" },
	}
	for zone, info in Config.CoreLoop.Zones.List do
		if zone > 1 then
			local look = table.clone(roofLook)
			for key, value in info.LookChanges or {} do
				look[key] = value
			end
			-- (Stage 5: and the other outdoor zones' maps, 2,500 studs along)
			local hide = table.clone(far)
			for other, otherInfo in Config.CoreLoop.Zones.List do
				if other > 1 and other ~= zone then
					table.insert(hide, { otherInfo.Folder })
				end
			end
			table.insert(Config.Zones.Worlds, {
				Id = info.Folder,
				Folder = info.Folder,
				Area = { Center = Vector3.new(-10, 870, -3480) + info.Offset, Size = Vector3.new(600, 180, 640) },
				Look = look,
				Hide = hide,
			})
		end
	end
end

-- Elevators (owner 2026-10-22): Skyline Lanes is a rooftop, so you ride up to it. One car at the east end of
-- Main Street Lanes' back walkway, one on the roof. Built in code on each screen (ElevatorController); the server
-- (ElevatorService) checks you have zone 4 open and stand by the car, then moves you while the screen is black.
-- Door = bottom middle of the doorway, looking out (the way you face when you step out).
Config.Elevators = {
	Zone = 4, -- you need this zone open to ride
	UseRange = 16, -- studs (flat) from the doorway the server accepts a ride from
	PromptRange = 10,
	RideSeconds = 1.6, -- how long the screen stays dark (you move halfway through)
	Cars = {
		{
			Id = "MainStreet",
			Door = CFrame.lookAt(Vector3.new(166.5, 1, 46), Vector3.new(160, 1, 46)),
			Arrive = Vector3.new(158, 4, 46),
			To = "Roof",
			Action = "RIDE UP",
			Sign = "SKYLINE LANES",
			Arrow = "▲",
			RideText = "GOING UP...",
		},
		{
			Id = "Roof",
			Door = CFrame.lookAt(Vector3.new(81, 848, -3401.5), Vector3.new(81, 848, -3410)),
			Arrive = Vector3.new(81, 852, -3412),
			To = "MainStreet",
			Action = "RIDE DOWN",
			Sign = "MAIN STREET LANES",
			Arrow = "▼",
			RideText = "GOING DOWN...",
			Housing = true, -- stands on the open roof: build the little elevator house around it
		},
	},
}

-- The "ZONE UNLOCKED" window (ZoneGateController): pops up once when a rebirth opens a zone (save ZoneSeen),
-- with what's waiting there in 3D. Crates = Config.Crates Ids, Balls = Config.Balls Ids (best first).
Config.ZoneUnlock = {
	[2] = {
		Title = "ZONE 2 UNLOCKED!",
		Name = "NEON LANES",
		Tagline = "The bouncer just waved you in. Glowing lanes, pets to hatch, three new crates and the rarest balls in town are waiting inside.",
		Eggs = { "Alley" }, -- Config.EggLooks Ids: shown in 3D on the pets row (pets open with this zone)
		PetsLine = "PETS UNLOCKED: HATCH THEM IN THE LOBBY",
		MysteryPets = 3, -- "?" cards beside the egg (its pets stay a surprise)
		Crates = { "Bronze", "Silver", "Gold" },
		CratesLine = "3 NEW CRATES",
		Balls = { "Inferno", "Nebula", "Plasma", "Galaxy", "Magma", "Electric" }, -- Phase X: zone 2 tops out at Epic
		BallsLine = "%d NEW BALLS TO WIN", -- %d = how many balls those crates can give that you don't own
		Button = "SHOW ME THE WAY!",
		Hint = "Step onto any OPEN lane to claim it.",
		Color = Color3.fromRGB(255, 60, 210),
		Accent = Color3.fromRGB(70, 230, 255),
	},
	[3] = {
		Title = "ZONE 3 UNLOCKED!",
		Name = "MAIN STREET LANES",
		Tagline = "You're a local name now. A real bowling centre with polished wood lanes is open to you, through the new door in the lobby.",
		Eggs = { "Arcade" }, -- Phase X: the Main Street Egg
		PetsLine = "NEW EGG: HATCH IT IN MAIN STREET LANES",
		MysteryPets = 3,
		Crates = { "League", "Champion" },
		CratesLine = "2 NEW CRATES",
		Balls = { "Perfect300", "Championship", "TigerSwirl", "PearlPro", "BlueMarble", "LeagueBlack" },
		BallsLine = "%d NEW BALLS TO WIN",
		Button = "SHOW ME THE WAY!",
		Hint = "Step onto any OPEN lane to claim it.",
		Color = Color3.fromRGB(224, 165, 38),
		Accent = Color3.fromRGB(255, 120, 110),
	},
	[4] = {
		Title = "ZONE 4 UNLOCKED!",
		Name = "SKYLINE LANES",
		Tagline = "The big time. Take the elevator at the end of Main Street Lanes' back walkway up to the rooftop lanes above the city.",
		Eggs = { "Skyline" }, -- Phase X: the Skyline Egg
		PetsLine = "NEW EGG: HATCH IT ON THE ROOF",
		MysteryPets = 3,
		Crates = { "SkyBronze", "SkySilver", "SkyGold" },
		CratesLine = "3 NEW CRATES",
		Balls = { "Daybreak", "Lightning", "SolidGold", "Sunburst", "CloudSwirl", "Crystal" },
		BallsLine = "%d NEW BALLS TO WIN",
		Button = "SHOW ME THE WAY!",
		Hint = "Step onto any OPEN lane to claim it.",
		Color = Color3.fromRGB(255, 79, 139),
		Accent = Color3.fromRGB(245, 184, 46),
	},
}

Config.Economy = {}

-- One throw:
--   pinsHit = min(zone pins, ball power * throw quality)
--   coins   = pinsHit * zone pin value * Power Level value * ball Multiplier (with Polish)
--             * (1 + mascot bonuses) * (1 + RankBonus * rank)
--             * (1 + RebirthBonus * rebirths) * streak tier * crit (Perfect) * lane modifier * Golden Pin
--   xp      = pinsHit * zone XP per pin
Config.Economy.Formula = {
	QualityMin = 0.6, -- the worst timing still knocks down this share of the ball's power
	QualityMax = 1.0,
	PerfectCrit = 2.0, -- a Perfect throw (quality 1.0, sweet spot) pays this much more
	RankBonus = 0.03, -- +3% coins per rank
	RebirthBonus = 0.5, -- +50% coins per rebirth
	-- Streak, lane modifier and Golden Pin multipliers come from the live tables (Config.Streaks,
	-- Config.LaneModifiers, Config.GoldenPin); the plan's StreakPerStrike/StreakMax and Lucky Throw were replaced (step 7c).
}

-- Zones. Rank = rank level needed to enter (Shared.Modules.Zones).
-- CoinPay / XpPay = how much more a throw in this zone pays than the same throw in zone 1 (coins / XP), shown as
-- ZONE in the multiplier panel. Economy pass E2 (owner 2026-10-25: later zones pay more per pin): tuned with the
-- simulator so zone 3 opens at about 40 min and zone 4 at about 2.5 hours (were 46 min and ~10 hours at x1).
-- Pins / PinValue / XpPerPin are the old simulator's numbers (10-3,000 pin racks); nothing reads them since E1.
Config.Economy.Zones = {
	{
		Id = "StarterAlley",
		Name = "Back Alley",
		Pins = 10,
		PinValue = 10,
		XpPerPin = 1,
		Rank = 1, -- old unlock level, only read to upgrade old saves (v24)
		Rebirths = 0, -- rebirths this zone opens at (owner 2026-10-27)
		CoinPay = 1,
		XpPay = 1,
	},
	{
		Id = "NeonLanes",
		Name = "Neon Lanes",
		Pins = 30,
		PinValue = 50,
		XpPerPin = 2,
		Rank = 5, -- old unlock level, only read to upgrade old saves (v24)
		Rebirths = 1, -- rebirths this zone opens at (owner 2026-10-27)
		CoinPay = 4,
		XpPay = 1.2,
	},
	{
		Id = "MainStreetLanes",
		Name = "Main Street Lanes",
		Pins = 100,
		PinValue = 250,
		XpPerPin = 4,
		Rank = 12, -- old unlock level, only read to upgrade old saves (v24)
		Rebirths = 3, -- rebirths this zone opens at (owner 2026-10-27)
		CoinPay = 16,
		XpPay = 2.5,
	}, -- was Arcade Arena (owner 2026-10-22)
	{
		Id = "SkylineLanes",
		Name = "Skyline Lanes",
		Pins = 300,
		PinValue = 1250,
		XpPerPin = 8,
		Rank = 22, -- old unlock level, only read to upgrade old saves (v24)
		Rebirths = 5, -- rebirths this zone opens at (owner 2026-10-27)
		CoinPay = 64,
		XpPay = 6,
	},
	{
		Id = "VolcanoStrike",
		Name = "Volcano Strike",
		Pins = 1000,
		PinValue = 6000,
		XpPerPin = 16,
		Rank = 35, -- old unlock level, only read to upgrade old saves (v24)
		Rebirths = 8, -- rebirths this zone opens at (owner 2026-10-27)
		CoinPay = 1,
		XpPay = 1,
	},
	{
		Id = "CosmicAlley",
		Name = "Cosmic Alley",
		Pins = 3000,
		PinValue = 30000,
		XpPerPin = 32,
		Rank = 50, -- old unlock level, only read to upgrade old saves (v24)
		Rebirths = 12, -- rebirths this zone opens at (owner 2026-10-27)
		CoinPay = 1,
		XpPay = 1,
	},
}

-- Power Levels (LIVE since Addendum 2 Phase 1 step 3; the plan's "Ball Shop"): upgrades bought with coins, in order.
-- Power = pins knocked per throw at quality 1.0 (in the live game: the most pins a non-PERFECT throw can knock down;
-- a PERFECT always strikes the 10-pin Starter Alley). Value = payout multiplier, which multiplies with the equipped
-- ball's own Multiplier (Config.Balls). How each level looks and sounds: Config.Throw.Levels.
-- Tuned with the simulator. Plan prices: 0, 100, 500, 2.5K, 12K, 60K, 300K, 1.5M, 7M, 35M, 175M, 1B; plan values went
-- up to x75, lowered to x12 because ball multipliers (up to x25) stack on top. Prices jump right after each new
-- zone opens (levels 5 and 7), because a new zone pays far more per throw.
-- 2026-10-18: every simulator price and pin value went x10 so they are in real game coins (the live game pays
-- Config.Rewards.BaseCoinsPerPin = 10 per pin in zone 1). Levels 2 and 3 cheaper for Addendum 2's first 3 minutes.
-- Batch D2 (owner 2026-10-29, final changes "Power Levels"): prices cut a lot so they are the cheap, frequent step
-- between rebirths (a rebirth puts you back to Power Level 1). Values (the coin multiplier) unchanged. Sim (10 runs):
-- every run now gets a new Power Level every ~20 s to 3 min at its start (run 0: LV2 0:03, LV3 0:06, LV4 0:49, LV5
-- 1:09, LV6 3:37; zone 2 run: LV6 0:46, LV7 3:36; zone 3 run: LV9 0:16-3:10, LV10 2:10), was 1-2 a run. Level 12
-- stays a long goal in zone 4. Batch D3: level 11 8B -> 1B, the late goal of the run before zone 4 opens.
-- The game shows each level's coin payoff ("x1.5 > x2 COINS": PowerLevels.PayoffText).
Config.Economy.PowerLevels = {
	{ Level = 1, Price = 0, Power = 6, Value = 1.0 },
	{ Level = 2, Price = 100, Power = 10, Value = 1.25 }, -- D2: was 400
	{ Level = 3, Price = 500, Power = 16, Value = 1.5 }, -- was 3,000
	{ Level = 4, Price = 2000, Power = 30, Value = 2 }, -- was 27,000
	{ Level = 5, Price = 7500, Power = 50, Value = 2.5 }, -- was 840,000
	{ Level = 6, Price = 30000, Power = 100, Value = 3 }, -- was 4.2M
	{ Level = 7, Price = 150000, Power = 180, Value = 4 }, -- was 100M
	{ Level = 8, Price = 1000000, Power = 350, Value = 5 }, -- was 1.5B
	{ Level = 9, Price = 10000000, Power = 700, Value = 6 }, -- was 8.2B
	{ Level = 10, Price = 200000000, Power = 1400, Value = 8 }, -- was 41B
	{ Level = 11, Price = 1000000000, Power = 2800, Value = 10 }, -- was 210B; D3: 8B -> 1B (the last buy of a zone 3 run)
	{ Level = 12, Price = 250000000000, Power = 5000, Value = 12 }, -- was 1.2T
}

-- Crate tiers (Addendum 1). Crates drop only the balls in Config.Balls: roll a rarity with these odds, then every
-- ball of that rarity is equally likely. Every row adds up to 100.
-- Prices move with the Power Level they sit next to (plan: 100, 1K, 15K, 250K, 5M).
-- Owner 2026-10-22: Alley Crate 1.6K -> 15K, Bronze 9.2K -> 75K, Silver 1M -> 750K, Gold 87M -> 65M. The very first Alley Crate
-- still costs Config.Onboarding.FirstCratePrice.
Config.Economy.Crates = {
	{ Id = "Basic", Price = 15000, Odds = { Common = 70, Uncommon = 25, Rare = 5 } },
	-- Zone 2 odds come from Config.CrateTiers since Phase X (were: Bronze C45 U35 R17 E3, Silver C20 U35 R32 E11
	-- L2, Gold U20 R45 E28 L6.5 M0.5)
	{ Id = "Bronze", Price = 75000 },
	{ Id = "Silver", Price = 750000 },
	{ Id = "Gold", Price = 3000000 }, -- E3b: 65M -> 3M (at 65M it came after the zone 3 crates, about 2 hours in)
	-- Phase X: zone 3 and 4 crates. Odds come from Config.CrateTiers. E3b: League 25M -> 8M, Champion 1B -> 40M so
	-- both come while you play zone 3 (were after zone 4 opened); zone 4 crate prices kept.
	-- D3 (2026-10-29): League 8M -> 30M, Champion 40M -> 250M so they last through both zone 3 runs (at the old
	-- prices zone 3's shop was bought out early and the run before zone 4 had ~20 minutes with nothing to buy)
	{ Id = "League", Price = 30000000 },
	{ Id = "Champion", Price = 250000000 },
	{ Id = "SkyBronze", Price = 5000000000 },
	{ Id = "SkySilver", Price = 50000000000 },
	{ Id = "SkyGold", Price = 500000000000 },
	{ Id = "Neon", Price = 5900000000, Odds = { Rare = 40, Epic = 38, Legendary = 18, Mythic = 4 } }, -- simulator only (not in Config.Crates)
}
-- Crate tiers (Phase X Part 4): a crate with a Tier gets its odds from its zone's rarity range (Config.ZoneRarity).
-- Keys are steps up from the zone's lowest rarity (0 = lowest), values = percent. Zone 2 (Uncommon to Epic):
-- Bronze = Uncommon 75 / Rare 25, Silver = Uncommon 35 / Rare 55 / Epic 10, Gold = Rare 70 / Epic 30.
-- Zones 3 and 4 shift the same shape up one rarity per zone. A rarity a crate's zone has no balls of gives its
-- share to the nearest rarity that has some (Shared.Modules.Balls).
Config.CrateTiers = {
	Bronze = { [0] = 75, [1] = 25 },
	Silver = { [0] = 35, [1] = 55, [2] = 10 },
	Gold = { [1] = 70, [2] = 30 },
}
-- Pity: a pull of one of these Crates is at least Rarity once that many pulls in a row (of that crate) missed it
Config.Economy.CratePity = {
	{ Crates = { Basic = true, Bronze = true }, Rarity = "Rare", After = 10 },
	{ Crates = { Silver = true, Gold = true }, Rarity = "Epic", After = 20 },
	{ Crates = { Neon = true }, Rarity = "Legendary", After = 80 }, -- Gold left this row in Phase X (no Legendary in zone 2)
	-- Phase X zone 3 and 4 crates: the same idea one and two rarities up
	{ Crates = { League = true }, Rarity = "Epic", After = 10 },
	{ Crates = { Champion = true }, Rarity = "Legendary", After = 20 },
	{ Crates = { SkyBronze = true }, Rarity = "Legendary", After = 10 },
	{ Crates = { SkySilver = true }, Rarity = "Mythic", After = 40 },
	{ Crates = { SkyGold = true }, Rarity = "Mythic", After = 20 },
}
Config.Economy.FirstCrateMin = "Uncommon" -- the very first crate a player opens gives at least this (unless it's the
-- first bought crate or the gift crate, which use Config.Onboarding.FirstBoughtRarity / GiftRarity)
-- Duplicates become Polish Points; Polish levels raise one ball's Multiplier. A maxed ball's duplicates pay coins.
Config.Economy.Polish = {
	ValuePerLevel = 0.05, -- each level adds +5% of that ball's Multiplier
	MaxLevel = 10,
	PointsPerDuplicate = 1, -- starting guess (Milestone 16)...
	PointsPerLevel = 1, -- ...so one duplicate = one level for now
	-- Gem sink (step 7b, owner's choice): gems buy the next Polish level of a ball you own, one level at a time.
	-- Price = GemPrice[rarity] x the level you're buying (Common: 4 for level 1, 8 for level 2 ... 40 for level 10).
	-- Starting guess from gem income (~1 gem/min early: PERFECT drops, 2 per rank level, daily): first Common level
	-- in about 4 minutes of gems, a full Common ball about 220 gems.
	GemPrice = { Common = 4, Uncommon = 6, Rare = 10, Epic = 16, Legendary = 25, Mythic = 40 },
}

-- LIVE since Addendum 2 Phase 2 step 6: the shop crates (Config.Crates) take their price and odds from Economy.Crates
-- (a crate with a Tier and no Odds of its own gets them from Config.CrateTiers + its zone's Config.ZoneRarity)
local function tierOdds(tier: string, zone: number)
	local range = Config.ZoneRarity[zone]
	local shape = Config.CrateTiers[tier]
	if not range or not shape then
		return nil
	end
	local low = 1
	for index, rarity in Config.Rarities do
		if rarity.Name == range.Min then
			low = index
		end
	end
	local odds = {}
	for step, percent in shape do
		local rarity = Config.Rarities[math.min(low + step, #Config.Rarities)]
		odds[rarity.Name] = (odds[rarity.Name] or 0) + percent
	end
	return odds
end
for _, crate in Config.Crates do
	for _, row in Config.Economy.Crates do
		if row.Id == crate.Id then
			crate.Price = row.Price
			crate.Odds = row.Odds or (crate.Tier and tierOdds(crate.Tier, crate.Zone or 1))
			row.Odds = crate.Odds -- the simulator reads Economy.Crates
		end
	end
	assert(crate.Odds, "Config.Crates." .. crate.Id .. " has no row (or odds) in Config.Economy.Crates")
end
-- Phase X 8B: a ball row without its own Multiplier uses its rarity's (Config.RarityPower)
for _, ball in Config.Balls do
	if ball.Multiplier == nil then
		local power = Config.RarityPower[ball.Rarity]
		ball.Multiplier = if power then power.Ball else 1
	end
end

-- Mascots (Milestone 14). Unlock: Rank = rank needed, or Zone = zone number that must be unlocked.
-- BonusScale: this egg's mascots get Mascots.Bonus times this (not in the plan, where every egg gave the same
-- bonuses: cheap eggs made coins explode and expensive eggs were pointless). Plan prices: 400, 6K, 90K, 1.5M, 30M.
Config.Economy.Eggs = {
	{ Id = "Alley", Price = 50000, Zone = 2, BonusScale = 0.1 }, -- owner 2026-10-21: pets open with Neon Lanes; 3,700 -> 50K (owner 2026-10-22)
	{ Id = "Neon", Price = 420000, Zone = 2, BonusScale = 0.2 },
	{ Id = "Arcade", Price = 20000000, Zone = 3, BonusScale = 0.4 }, -- Main Street Egg (Phase X). D3: 6.3M -> 20M (first one ~3 min into zone 3)
	{ Id = "Skyline", Price = 1500000000, Zone = 4, BonusScale = 0.7 }, -- Skyline Egg (Phase X). E3b: price kept (about 3 hours of play)
	{ Id = "Volcano", Price = 35000000000, Zone = 5, BonusScale = 1 },
}
Config.Economy.Mascots = {
	Odds = { Common = 60, Uncommon = 25, Rare = 10, Epic = 4, Legendary = 0.9, Mythic = 0.1 },
	Bonus = {}, -- per rarity, from Config.RarityPower Pet (Common 0.2 ... Mythic 15); added together
	ShinyMerge = 3, -- this many of the same mascot make a Shiny...
	ShinyMultiplier = 2, -- ...with this much more bonus
	StartSlots = 3,
	MaxSlots = 6, -- slots from StartSlots + SlotRebirths (and old saves' PetSlotsKept) stop here; the pass adds on top
	-- Final changes item 7 (owner 2026-10-29): 3 slots, +1 at 5 rebirths, +2 with the +2 PET SLOTS pass. Was +1 at
	-- rank levels 15 and 30 and at 1 rebirth; old saves keep the slots they had (save v30 PetSlotsKept).
	SlotRebirths = { 5 }, -- each of these rebirth counts adds a slot
}
for name, power in Config.RarityPower do
	if name ~= "Step" then
		Config.Economy.Mascots.Bonus[name] = power.Pet
	end
end

-- Addendum 5 B1: pets give STAT boosts (core loop only; Enabled = false = the old coins-only bonus above).
-- Each pet row in Config.Mascots has Stats = { Coins = 0.5, Pins = 0.2 } (0.5 = +50%), one or two stats each.
-- A Shiny has every stat x Config.Economy.Mascots.ShinyMultiplier.
-- Stacking "Add" (the addendum's default): the same stat from every equipped pet adds up (+50% and +30% = +80%),
--   and that total multiplies with the rest (rebirth, potions, passes): coins x (1 + Coins total) x rebirth ...
-- Stacking "Multiply": each pet multiplies on its own (+50% and +30% = x1.5 x1.3 = +95%).
--   Coins = coins per pin (in the coin multiplier, Mascots), Pins = pins per swing (the ball's pins x (1 + total)),
--   Bag = bag size (the bag holds x (1 + total) coins; HUD and server use the same number), Speed = throws per
--   second (seconds between throws / (1 + total), never under Config.CoreLoop.CooldownFloor).
Config.PetStats = {
	Enabled = true,
	Stacking = "Add",
	-- order the stats show in, their label, colour and how much EQUIP BEST counts 1.0 of each (Speed is capped
	-- by the cooldown floor, so it counts a bit less)
	Order = { "Coins", "Pins", "Bag", "Speed" },
	Types = {
		Coins = { Label = "Coins", Color = Color3.fromRGB(255, 205, 50), Best = 1 },
		Pins = { Label = "Pins", Color = Color3.fromRGB(255, 120, 200), Best = 1 },
		-- Addendum 5 E: Bag counts 8 (was 0.6): once pets and rebirths fill the bag in a throw or two, a bigger bag is
		-- the only stat that still raises income, and at 0.6 EQUIP BEST swapped bag pets out for Shiny Volcano pets and
		-- income fell by half (sim: 4 still did it from rebirth 6; 8 keeps them through rebirth 8; run 0 unchanged)
		Bag = { Label = "Bag", Color = Color3.fromRGB(80, 200, 255), Best = 8 },
		Speed = { Label = "Speed", Color = Color3.fromRGB(130, 235, 90), Best = 0.8 },
	},
	-- Equip slots: StartSlots (Config.Economy.Mascots) + slots bought with coins at the shop booth, one at a time,
	-- in this price order (slot 4, 5, 6 ...). The +2 PET SLOTS pass adds on top. Old saves never lose a slot they had
	-- (PetSlotsKept). Bought slots are saved (PetSlotsBought, v35).
	SlotPrices = { 2500, 25000, 150000, 600000, 2500000 },
	KeepPetSlots = true, -- rebirth keeps the bought slots (false = back to StartSlots on rebirth)
	-- Addendum 5 F: EQUIP BEST ranks pets by the coins a minute they really earn you (Mascots.Income: throws until the
	-- bag is full + one sell trip), so bag pets win exactly when the bag holds you back. false = the Best weights above.
	BestByIncome = true,
	SellTrip = 8, -- seconds a sell trip takes (SELL teleport, walk back to your spot)
}

-- Ranks: XP to go from rank r to r+1 = Base * Growth^(r-1) up to rank LateFrom, then it grows by LateGrowth per
-- rank up to EndFrom, then by EndGrowth (nil EndFrom = LateGrowth to the end).
-- Economy pass E3b (2026-10-25): gentle start (zone 2 at about 9 min, was 4), steep middle (zone 4 at about 2 hours of
-- play), flat end so level 60 is reachable (about 10 hours of play, was never). Was Base 180, Growth 1.42, LateFrom 30,
-- LateGrowth 1.06.
Config.Economy.Ranks = {
	MaxRank = 60,
	Base = 570, -- plan: 50
	Growth = 1.2, -- plan: 1.35
	LateFrom = 12,
	LateGrowth = 1.38,
	EndFrom = 30,
	EndGrowth = 1.08,
	-- Live since step 7a (rank levels 1-60; XP per throw is still zone 1's, so later levels wait for zones 2-6)
	LevelsPerTier = 6, -- levels per Pro Tier (Config.Ranks)
	LevelGems = 2, -- gems for a level-up inside a tier (a new tier gives its own Gems instead)
	FreeCrateEvery = nil, -- nil = levels give no free crate (owner 2026-10-21); a number = every Nth level does
}

-- Rebirth ("Go Pro Tour", Milestone 17)
-- Rebirth = back to level 1, Power Level 1 and 0 coins (balls, pets, gems and potions stay; zones lock again, owner
-- 2026-10-25) for a permanent coin and XP boost, from the REBIRTH button on the HUD (owner 2026-10-25: no station;
-- RebirthController). OFF until the owner turns Enabled on.
-- Economy pass E3a (owner 2026-10-25: rebirth should be fast, not a long grind, and open at zone 3). Was: zone 4, 4B
-- coins x1.6, +3 levels each. E3b (new XP curve, cost x1.6): first rebirth about 1h20 in, then one every 5-25 minutes,
-- slowing to 30-60 minutes from about rebirth 22.
Config.Economy.Rebirth = {
	Enabled = true, -- the owner flips this (switched ON by the owner 2026-10-26)
	-- Owner 2026-10-27: zones open by rebirths (Config.Economy.Zones Rebirths), so the first rebirth happens in zone 1.
	-- A rebirth resets coins, Power Level AND rank level, XP and rank tier (owner 2026-10-29, batch D1 "full reset";
	-- was coins + Power Level only). Levels come back faster each rebirth (XpBonus, zone XP pay). Level-up and rank-up
	-- rewards pay once ever (BestLevel / BestRank); ranks won before need no second trial.
	-- Economy pass R2 (2026-10-27, tools/EconomySim): prices below hit the timeline (Config.Economy.Timeline).
	-- Batch D3 economy pass (owner 2026-10-29: rebirth 1 at about 4 min, zone 3 at about 25 min, zone 4 at about 1.5 h).
	-- Each rebirth needs its own rank level (Levels) and coins (Costs). The level comes near the end of each run and
	-- the coins a minute or two after it, so the run is spent buying Power Levels, crates and eggs, not saving.
	-- Sim (40 players): rebirth 1 4:27, 2 12:13, zone 3 26:13, rebirth 4 47:03, zone 4 1h35m; longest wait between
	-- two buys (median) 2:09 / 1:15 / 3:33 / 3:27 / 10:09 in runs 0-4 (was 5:00 / 1:39 / 5:03 / 1:39 / 25:15).
	-- Was: Level 4 + RankStep 2 each, Costs 50K / 700K / 9M / 150M / 4B (zone 2 9:40, zone 3 29:43, zone 4 1h09m).
	Levels = { 3, 8, 13, 21, 24 }, -- rank level for rebirths 1, 2, 3... (D3)...
	Level = 3, -- (used only when Levels is empty: the first rebirth's level...)
	RankStep = 2, -- ...and after the Levels list, this many more levels for each rebirth
	Costs = { 15000, 500000, 4000000, 200000000, 1500000000 }, -- coins for rebirths 1, 2, 3... (D3)
	CostGrowth = 3, -- ...and each one after the list costs the last one times this
	FirstCost = 50000, -- (old single-price rule, kept for anything reading it; Rebirth.Cost uses Costs)
	DiscountLevels = 5, -- NOT BUILT (old plan, nothing reads it): after a rebirth, Power Levels up to this one...
	DiscountPrice = 0.1, -- ...cost this share of their price
	XpBonus = 1, -- +100% XP per rebirth (owner approved). Not in the plan's formula: without it a second run is barely faster
}

-- The timeline the simulator checks (MASTER_PLAN.md section 2), in minutes from a brand new player's first join
Config.Economy.Timeline = {
	{ Goal = "Level2", Text = "Buy Power Level 2", From = 0.3, To = 1 }, -- Addendum 2: about 6 throws
	{ Goal = "FirstCrateOpened", Text = "Open first crate (1,000 sale)", From = 0.5, To = 1.5 }, -- E2: was "afford" at 15K
	{ Goal = "Rank3", Text = "Reach rank 3", From = 4, To = 5 },
	{ Goal = "FirstEgg", Text = "Afford first pet egg", From = 5, To = 9, Ever = true }, -- pets open with zone 2 (1 rebirth)
	-- Owner 2026-10-27: zones open by rebirths (zone 2 = 1, zone 3 = 3, zone 4 = 5); Ever = total play time
	-- Batch D3 (owner 2026-10-29): rebirth 1 about 4 min, zone 3 about 25 min, zone 4 about 1.5 h (aimed a little
	-- slower: fever and lane events, D4/D5, will add coins the simulator doesn't count)
	{ Goal = "RebirthReady", Text = "First rebirth available", From = 4, To = 5.5, Rebirth = true }, -- skipped while rebirth is off
	{ Goal = "Zone2", Text = "Unlock Zone 2 (1 rebirth)", From = 4, To = 5.5, Ever = true },
	{ Goal = "Zone3", Text = "Unlock Zone 3 (3 rebirths)", From = 24, To = 30, Ever = true },
	{ Goal = "Zone4", Text = "Unlock Zone 4 (5 rebirths)", From = 85, To = 100, Ever = true },
}

-- The pretend player the simulator plays as (MASTER_PLAN.md Milestone 10 step 4)
Config.Economy.Sim = {
	Runs = 40, -- players simulated; the report shows the median
	-- One throw this often. Measured in Studio 2026-10-18 with the new throw: the lane is free again 2.2s after
	-- letting go (2.45s after a strike), plus about 0.5s holding and a moment to react = about 3s.
	ThrowSeconds = 3,
	GoodShare = 0.7, -- share of throws with good timing...
	GoodQuality = { 0.9, 1.0 }, -- ...and their quality
	BadQuality = { 0.6, 0.85 }, -- the rest
	PerfectShare = 0.15, -- share of all throws that are Perfect (counted inside the good ones)
	SpendShare = 0.25, -- buys an egg or crate only when it costs at most this share of the next Power Level
	SaveForRebirthAt = 0, -- stops buying eggs/crates once a zone-opening rebirth is this far paid (0 = from its level on, like the goal bar)
	MaxEggs = 8, -- stops hatching an egg type after this many
	MaxCrates = 10, -- stops buying a crate type after this many
	Minutes = 600, -- how long each pretend player plays (one long session: playtime gifts restart each visit)
	Rebirths = 10, -- rebirths as soon as it can, up to this many times (the report shows each run)
	-- Economy pass E1: the simulator plays the live rules (10 pins everywhere, Config.Rewards pay, rank tier
	-- multipliers, zone-only crates and eggs, level rewards, challenge, boss, playtime gifts, free crates)
	BossTripSeconds = 40, -- a boss trip (helicopter, fight, ride back) costs this much throwing time
	SpinAtZone = 2, -- the one daily spin of the session happens when this zone opens
	ToleranceShare = 0.2, -- a result more than 20% outside a timeline window counts as a mismatch
}

-- Profile panel (Polish P5, POLISH_PLAN.md): a PROFILE button on the HUD opens BOOSTS (every coin and XP multiplier,
-- the same numbers that pay throws: MultiplierService), STATS (lifetime numbers) and ACHIEVEMENTS (tiers with progress
-- bars and a small gem reward you CLAIM; the server counts, checks and pays: AchievementService, ProfileController).
-- Stat = which number an achievement counts (Config.Profile.Stats Key). Tiers = { Goal, Gems } in order; add rows or
-- tiers freely (claimed tiers are saved per Id in AchievementTiers, so never rename an Id).
-- Gem check (2026-10-28): everything together pays 317 gems over the whole game. Compare: level-ups 2 gems each
-- (~118 to level 60) + rank tier gems (345) + VIP 25/day; sinks: cosmetics 40/120/300, Polish 4-40 per level.
-- A player's first hour reaches about 8-10 tier-1 rows and a few tier-2 rows = about 20-25 gems (half a 40-gem
-- cosmetic); the big tiers (12 gems) need 10+ hours each. Gem packs: 60 gems = 99 Robux, so this never undercuts them.
-- SETTINGS window (owner 2026-10-29): a grey SETTINGS button under GIFTS (top-right; in the MORE menu on phones)
-- opens switches the player can turn on or off. Saved per player (save field Settings, v27). Everything starts on.
-- Kind = "Slider": a 0-100% slider instead of a switch, starting at Default (owner 2026-10-29: music a bit quieter).
--   Sfx    every sound effect (SoundService SoundGroup "EffectsVolume")
--   Music  zone music + ambience loops volume (SoundGroup "MusicVolume")
--   Vfx    ball trails/sparkles/rings, sparks, confetti, fireworks, shockwave rings, lane run lights
--          (numbers, popups and the hatch/crate screens stay)
--   Shake  camera shake and the camera punch on hits
--   OthersVfx  other players' ball effects + their throw effects (sparks, confetti, trait effects, cosmetic blasts;
--          less lag in full servers; the balls, pins, numbers and sounds stay)
Config.Settings = {
	Enabled = true,
	Options = {
		{ Key = "Sfx", Name = "SOUND EFFECTS", Info = "Pins, coins, buttons" },
		{ Key = "Music", Name = "MUSIC", Info = "Music and rooftop sounds", Kind = "Slider", Default = 0.7 },
		{ Key = "Vfx", Name = "EFFECTS", Info = "Trails, sparks, confetti" },
		{ Key = "Shake", Name = "SCREEN SHAKE", Info = "Camera shake on big hits" },
		{ Key = "OthersVfx", Name = "OTHER PLAYERS' EFFECTS", Info = "Off = less lag in busy servers" },
	},
	SliderStep = 0.05, -- sliders move in 5% steps
}

Config.Profile = {
	Enabled = true,
	-- The STATS page, in order. Format: "Number" (1,234 / 12.5K), "Time" (seconds -> 3h 20m)
	Stats = {
		{ Key = "Throws", Name = "THROWS", Icon = "Ball", Format = "Number" },
		{ Key = "Strikes", Name = "FULL CLEARS", Icon = "Pin", Format = "Number" },
		{ Key = "Perfects", Name = "PERFECTS", Icon = "Xp", Format = "Number" },
		{ Key = "Pins", Name = "PINS DOWN", Icon = "Pin", Format = "Number" },
		{ Key = "BestStreak", Name = "BEST STREAK", Icon = "Flame", Format = "Number" },
		{ Key = "Coins", Name = "COINS EARNED", Icon = "Coin", Format = "Number" },
		{ Key = "Eggs", Name = "EGGS HATCHED", Icon = "Paw", Format = "Number" },
		{ Key = "Crates", Name = "CRATES OPENED", Icon = "Crate", Format = "Number" },
		{ Key = "Balls", Name = "BALLS OWNED", Icon = "Ball", Format = "Number" },
		{ Key = "Pets", Name = "PETS FOUND", Icon = "Paw", Format = "Number" },
		{ Key = "Rebirths", Name = "REBIRTHS", Icon = "Rebirth", Format = "Number" },
		{ Key = "BossWins", Name = "TITAN WINS", Icon = "Bolt", Format = "Number" },
		{ Key = "Level", Name = "BEST LEVEL", Icon = "Xp", Format = "Number" }, -- best ever (rebirths reset levels)
		{ Key = "Zones", Name = "ZONES OPEN", Icon = "Portal", Format = "Number" },
		{ Key = "PlayTime", Name = "TIME PLAYED", Icon = "GiftDaily", Format = "Time" },
	},
	-- 15 achievements, 58 tiers. Gems go 5, 10, 15, 20 by tier (owner batch B4, was 1/3/6/12). Text: %s = the tier's goal; One = the text when the goal is 1.
	Achievements = {
		{ Id = "Throws", Name = "BOWLER", Stat = "Throws", Text = "Throw %s balls", Tiers = {
			{ Goal = 100, Gems = 5 }, { Goal = 1000, Gems = 10 }, { Goal = 5000, Gems = 15 }, { Goal = 25000, Gems = 20 } } },
		{ Id = "Strikes", Name = "STRIKE MACHINE", Stat = "Strikes", Text = "Clear the lane %s times", Tiers = {
			{ Goal = 25, Gems = 5 }, { Goal = 250, Gems = 10 }, { Goal = 2500, Gems = 15 }, { Goal = 10000, Gems = 20 } } },
		{ Id = "Perfects", Name = "PERFECTIONIST", Stat = "Perfects", Text = "Hit %s PERFECTS", Tiers = {
			{ Goal = 10, Gems = 5 }, { Goal = 100, Gems = 10 }, { Goal = 1000, Gems = 15 }, { Goal = 5000, Gems = 20 } } },
		{ Id = "Pins", Name = "PIN CRUSHER", Stat = "Pins", Text = "Knock down %s pins", Tiers = {
			{ Goal = 1000, Gems = 5 }, { Goal = 10000, Gems = 10 }, { Goal = 100000, Gems = 15 }, { Goal = 500000, Gems = 20 } } },
		{ Id = "Streak", Name = "ON FIRE", Stat = "BestStreak", Text = "Get %s strikes in a row", Tiers = {
			{ Goal = 3, Gems = 5 }, { Goal = 5, Gems = 10 }, { Goal = 10, Gems = 15 }, { Goal = 20, Gems = 20 } } },
		{ Id = "Coins", Name = "MONEY MAKER", Stat = "Coins", Text = "Earn %s coins", Tiers = {
			{ Goal = 100000, Gems = 5 }, { Goal = 10000000, Gems = 10 }, { Goal = 1000000000, Gems = 15 }, { Goal = 1000000000000, Gems = 20 } } },
		{ Id = "Eggs", Name = "EGG HUNTER", Stat = "Eggs", Text = "Hatch %s eggs", One = "Hatch your first egg", Tiers = {
			{ Goal = 1, Gems = 5 }, { Goal = 10, Gems = 10 }, { Goal = 50, Gems = 15 }, { Goal = 200, Gems = 20 } } },
		{ Id = "Crates", Name = "CRATE CRACKER", Stat = "Crates", Text = "Open %s crates", One = "Open your first crate", Tiers = {
			{ Goal = 1, Gems = 5 }, { Goal = 10, Gems = 10 }, { Goal = 50, Gems = 15 }, { Goal = 200, Gems = 20 } } },
		{ Id = "Balls", Name = "COLLECTOR", Stat = "Balls", Text = "Own %s different balls", Tiers = {
			{ Goal = 5, Gems = 5 }, { Goal = 12, Gems = 10 }, { Goal = 20, Gems = 15 }, { Goal = 30, Gems = 20 } } },
		{ Id = "Pets", Name = "PET PAL", Stat = "Pets", Text = "Find %s different pets", Tiers = {
			{ Goal = 3, Gems = 5 }, { Goal = 6, Gems = 10 }, { Goal = 10, Gems = 15 }, { Goal = 14, Gems = 20 } } },
		{ Id = "Rebirths", Name = "REBORN", Stat = "Rebirths", Text = "Rebirth %s times", One = "Rebirth for the first time", Tiers = {
			{ Goal = 1, Gems = 5 }, { Goal = 3, Gems = 10 }, { Goal = 5, Gems = 15 }, { Goal = 10, Gems = 20 } } },
		{ Id = "Titan", Name = "TITAN SLAYER", Stat = "BossWins", Text = "Beat the Pin Titan %s times", One = "Beat the Pin Titan", Tiers = {
			{ Goal = 1, Gems = 5 }, { Goal = 5, Gems = 10 }, { Goal = 25, Gems = 15 } } },
		{ Id = "Level", Name = "CLIMBER", Stat = "Level", Text = "Reach level %s", Tiers = {
			{ Goal = 10, Gems = 5 }, { Goal = 25, Gems = 10 }, { Goal = 40, Gems = 15 }, { Goal = 60, Gems = 20 } } },
		{ Id = "Zones", Name = "EXPLORER", Stat = "Zones", Text = "Open zone %s", Tiers = {
			{ Goal = 2, Gems = 5 }, { Goal = 3, Gems = 10 }, { Goal = 4, Gems = 15 } } },
		{ Id = "PlayTime", Name = "DEDICATED", Stat = "PlayTime", Text = "Play for %s", Tiers = {
			{ Goal = 1800, Gems = 5 }, { Goal = 7200, Gems = 10 }, { Goal = 36000, Gems = 15 }, { Goal = 180000, Gems = 20 } } },
	},
	PublishEvery = 1, -- seconds between the server's stat/achievement updates to the panel
}

-- Addendum 5 A1: no XP in the loop, so gifts that gave an XP potion give the coin potion of the same size instead
-- (daily calendar, playtime gifts, spin wheel). The XP potion rows stay in Config.Potions.
if Config.CoreLoop.Enabled and Config.CoreLoop.NoLevels then
	local swap = { XpSmall = "CoinSmall", XpBig = "CoinBig" }
	for _, row in Config.Playtime.Rewards do
		row.Potion = swap[row.Potion] or row.Potion
	end
	for _, row in Config.Daily.Rewards do
		if row.Potions then
			local merged, byId = {}, {}
			for _, potion in row.Potions do
				local id = swap[potion.Id] or potion.Id
				if byId[id] then
					byId[id].Count += potion.Count
				else
					byId[id] = { Id = id, Count = potion.Count }
					table.insert(merged, byId[id])
				end
			end
			row.Potions = merged
		end
	end
	for _, slice in Config.Spin.Slices or {} do
		if swap[slice.Potion] then
			slice.Potion = swap[slice.Potion]
			slice.Label = if slice.Potion == "CoinBig" then "MEGA COINS" else "COIN POTION"
		end
	end
end

-- Addendum 5 E (pacing pass): pins are a big number now (16K+ a throw at ball 10 with pets), so PIN CRUSHER's old goals
-- (1K / 10K / 100K / 500K) all went in the first ~30 minutes. Core loop goals: ~15 min, ~40 min, ~5 h, then long.
if Config.CoreLoop.Enabled then
	for _, achievement in Config.Profile.Achievements do
		if achievement.Id == "Pins" then
			for index, goal in { 10000, 1000000, 10000000, 100000000 } do
				achievement.Tiers[index].Goal = goal
			end
		end
	end
end

return Config
