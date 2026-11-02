# Addendum 6 report

## Stage 1: Fixes (2026-11-01, code tag `restore-a6-s1-before`)

### 1.1 Multipliers
**What was wrong:** Coins went into the bag *after* the boosts were added, and the bag has a size limit. A potion, a game pass, the Robux COIN BOOST, friends and a pet's coin bonus only made the bag fill faster. Once you have a few balls the bag fills in about one throw, so the sale was the same size with or without them. Rebirth was the only boost that really paid, because it was added at the sell.

**What changed:**
- The bag now holds **pins**. Selling pays pins × the coin multiplier, so every coin boost shows on every sale.
- There is one coin multiplier and one pin multiplier, with one formula in the config: (1 + pets + rebirth + friends) × potion × game passes × COIN BOOST. Pins use the same formula: (1 + pets + rebirth) × pin potion × pin passes (neither of those exists yet, so both stay at ×1 for now).
- The gold **×N badge** next to your coins is back. Tapping it opens the COIN MULTIPLIER card with every source, plus the pins-a-swing multiplier.
- Every sale pop shows the multiplier it used ("×23.5 BOOST"), including ×1.
- Potions already had a countdown at the bottom left. It still shows on the roof.
- The PROFILE → BOOSTS page shows the same sources.
- There's a new **BOOSTS** button in the Studio TEST panel (EVENTS section). It prints the whole breakdown in Output.
- The bag shop now says "Holds 60 pins" instead of coins.

**Tested in Studio, one source at a time (a bag of 100 pins each time):**

| Test | Sold for |
|---|---|
| No boosts | 100 |
| Coin potion only | 200 |
| COIN BOOST step 1 only | 200 |
| 2X COINS pass only | 200 |
| Pet only (Splitz +35%) | 135 |
| 1 rebirth only | 200 |
| All together | 2,350 (= ×23.5) |

**Worth knowing:**
- A player with no boosts earns exactly what they did before, so Zone 1 pacing is unchanged.
- Players with boosts now earn more, because their boosts finally pay.
- A rebirth and a pet's pin bonus now **add** together instead of multiplying, which is slightly less for players who have both. Stage 7 tunes rebirth.
- The economy simulator still uses the old bag maths. Stage 9 updates it.
- Bags in old saves keep their number, which now counts as pins. At most that's one bag's worth.

### 1.2 Lane too bright
- The mega lane changed from pale cream wood to **deep matte teal** (non-shiny wood). The pin deck is a slightly lighter teal.
- Bright cream edge lines now run down both outer sides. The gold lines between spots, the gold arrows and the gutters stay bright.
- The rooftop lighting already has weak bloom (0.08, only very bright things glow) and only slightly raised exposure (+0.1), so I didn't touch the lighting and the world stays bright.
- On contrast: white and pale pink effects on the old cream wood had a contrast ratio of about 1.5:1, so they were washed out. On the new teal it's about 8:1.

**Not verified by eye:** Studio's 3D view came back blank white in every capture, in Play and in Edit (the same problem as the Addendum 5 night). The request to look at the Studio window directly was declined, so I couldn't take the screenshot of the strongest effect on the lane. Please check it in your playtest.

## Stage 2: Shop (2026-11-01, code tag `restore-a6-s2-before`)

### 2.1 Tabs
- The shop window now has three tabs: **Balls**, **Bags** and **Rebirth**. The order lives in the config, and a Gamepasses tab (Stage 8) is one more entry in that list.
- The PET SLOTS row (from Addendum 5) is now at the bottom of the Bags tab.
- You can still only buy while standing at the shop. Away from it the window is a price list with a GO TO SHOP button. The HUD BALLS button opens the Balls tab and the HUD REBIRTH button opens the Rebirth tab.

### 2.2 Buy any ball or bag
- You can buy any ball or bag above your best one, as long as you can pay for it and its zone is open. You don't have to buy the ones in between.
- Pins per throw always come from your best ball, and bag room from your best bag.
- Balls and bags you jumped over are marked **SKIPPED**. You can still buy them at their normal price, but only for the look. Every ball you own has an **EQUIP** button for its look (its trail and its effect come with it). Pins don't change.
- **BUY BEST** (bottom right) buys the most expensive one you can pay for on that tab. It shows what it would add and the price. When you can't afford anything it turns grey and shows the next price.
- The next one up is highlighted with a coral outline, a NEXT tag, and its silhouette slowly turns.
- After a rebirth, everything you bought goes back to the start (ball 1, bag 1, no extra looks).

### 2.3 Silhouettes
- Every ball and bag you don't own is a solid black shape named **???**. It shows only what it would add ("+70 pins a throw") and the price. Its rarity colour stays hidden too.
- The list shows the whole ladder. Rows from zones you haven't opened will show greyed out with a lock and the zone number. Right now only Zone 1 exists, so you won't see any locked rows until Stage 3 adds zones.
- Buying one plays a 1.6 second reveal: a white flash, the colour pops in, the name appears, and a burst in the ball's effect colour.
- Names are also hidden in other places: the "you can afford" note now says "A NEW BALL AT THE SHOP", the next-goal bar says "Next ball (+4 pins a throw)", the first-30-seconds guide says "Buy a new ball", and the display cases on the plaza stay "???" until you own that ball.

### 2.4 Rebirth ranks
- Ranks use the old Pro Tier names from the first design: Rookie (no rebirth yet), Amateur, Regular, Club, Semi-Pro, Pro, Elite, Master, Legend, Hall of Famer. I added Superstar, Icon, Champion, World Champion, Immortal, Titan and Bowling God. After that come Bowling God II, III and so on. Each rank has its own colour.
- The ranks replace the old BRONZE/SILVER/GOLD tiers. Your pin rings and throw spot now use your rank's colour.
- The Rebirth tab shows your rank, the next rank, the price with a coins bar, what goes back to the start (coins, balls, bags, zones, pins) and what you keep (pets, gamepasses, rank), plus the boost: "+100% coins, +100% pins a throw". Those numbers stay until Stage 7 tunes them.
- To rebirth you **hold** the button for 1.5 seconds. It fills up while you hold, and letting go early cancels.
- Your rank now shows over your head (for example "★ AMATEUR"; before your first rebirth it says "ROOKIE"). On the leaderboard walls it shows after each player's name in its colour.

### 2.5 Small additions
- The next-goal bar already existed. It now shows what the next ball or bag adds, its price and your progress ("Next ball (+4 pins a throw) 0 / 150").
- Number style: every number already went through one formatter (K, M, B, T, Qa ...). Two places showed long numbers instead: the profile stats (up to a million) and the display case pin counts. They now use the same short style.

### What was tested (Studio Play test)
- Buying ball 5 straight from ball 1 worked, and balls 2 to 4 showed SKIPPED.
- Buying skipped ball 3 equipped its look and left pins on ball 5.
- Buying ball 3 again was refused ("You own it"). Equipping a ball you don't own was refused, and buying away from the shop was refused.
- Buy Best on bags jumped to bag 6, the most I could pay for. Bag room went to 3,700.
- Clicking a price in the window bought the ball and played the reveal.
- A rebirth reset coins, balls, bags and looks, gave rank Amateur, put "★ AMATEUR" in orange over the head and showed it on the leaderboard.
- Screenshots of the Balls and Rebirth tabs looked right. No errors in Output.

**Not verified:** I can't press and hold from here, so the hold-to-rebirth button was checked by reading the code. The rebirth itself was tested straight through the server. The full-screen REBIRTH! moment after a hold wasn't seen. Please hold the button in your playtest.

**Save change:** save version 37 adds which balls and bags you own, and the ball look you've equipped. Old saves count every ball and bag up to their best as owned, so nobody loses anything.

## Stage 3: Zone framework and eggs (2026-11-01, code tag `restore-a6-s3-before`)

### What changed
- **Four zones now exist.** Zone 1 is the rooftop. Zones 2 (Sunset Boardwalk), 3 (Jungle Falls) and 4 (Canyon Oasis) are each a big shared lane with their own sell pad, shop, egg stand, gates and throw spots. All the zone settings (name, where it sits, pin value, gate price, colours) are in one table in the config.
- **Zones 2 to 4 are placeholders for now.** Each is a flat, bright ground in its zone's colours (sand and turquoise, green and aqua, terracotta and turquoise) with gutters, a back wall, a few umbrella-style props and a big board with the zone's name. Every placeholder part is tagged "Placeholder" so Stages 4 to 6 can find and replace them with the real maps in the same spot.
- **Gates.** On the roof's west edge, behind the spawn, there's a gate to Zone 2. Every zone has a gate to the next one, and zones 2 to 4 also have a free gate back. Hold E (or tap) at a gate. A closed zone shows its price on the sign (green when you can pay, coral when you can't) and opens for that price, once. After that the gate is free. Zones open in order. You arrive on your own throw spot in the new zone.
- **Gate prices** (about the zone before's ball 7, as the addendum asks): Zone 2 = 22K, Zone 3 = 190M, Zone 4 = 240B. They rise after rebirths the same way ball prices do.
- **Pins sell for more in later zones:** ×1, ×6, ×36, ×216. A pin is worth what the sell pad you stand on pays, so you sell in the zone you're in.
- **40 balls and 40 bags.** Each zone has 10 balls and 10 bags. You can only buy a zone's balls and bags once that zone is open. In the shop they show greyed out with a lock until then, as Stage 2 built.
- **Zone 2 balls** use 10 of the original 20 designs (Ocean, Sunset, Electric, Toxic, Magma, Galaxy, Thunder, Plasma, Nebula, Golden). **Zone 3 and 4 balls** use other existing ball models for now. All 30 new balls borrow a Zone 1 effect until their zone's stage gives them their own. They're marked as placeholders in the config.
- **Ball and bag prices for zones 2 to 4** copy Zone 1's shape: about 3 minutes to the zone's first ball, then 2, 2, 2, 2, 5, 5, 5, 5, 5 minutes. Pins go up about ×1.7 a ball. Zone 4's last ball costs about 1.4 Qa (quadrillion). These are starting numbers. Stage 9 tunes them with the pacing sim.
- **You come back where you left.** If you leave in Zone 3, you rejoin in Zone 3. If you reset your character, you respawn in the zone you're in.
- **A rebirth closes zones 2 to 4 again** and takes you back to the roof (the Stage 2 rebirth tab already said zones reset).
- **TEST panel:** JUMP TO ZONE 2 / 3 / 4 now opens every zone up to that one for free and takes you there (Studio tests only).

### Eggs (3.3)
- The roof's row of 4 eggs is gone. **Each zone has one egg:**
  - Zone 1: **Speckled Egg**, 750 coins (about minute 3 to 5): Gutter Gus and Pebble (Common), Bumper and Breezy (Uncommon), Sunspot (Rare).
  - Zone 2: **Neon Egg**, 19M: its original 6 pets, Pinny, Lane Pup (Uncommon), Strikey, Splitz (Rare), Hambone, Neon Bat (Epic).
  - Zone 3: **Main Street Egg**, 23B: Wood Pup (Rare), Chrome Bat (Epic), Kingpin, Blaze (Legendary).
  - Zone 4: **Skyline Egg**, 28T: Cloud Bumper (Epic), Sunny Ham (Legendary), Cosmo, Perfecto (Mythic).
- Each later egg's pets are clearly stronger. The pet fusion machine (3 copies make a Shiny) stays on the roof.
- **Placeholders:** the Speckled Egg and its stand are the Neon ones repainted sand and sky blue. Pebble, Breezy and Sunspot borrow the Gus, Lane Pup and Strikey models in new colours. Titan Jr. stays the boss's pet. The Volcano Egg is out of the list. Everyone keeps every pet they already own.

### Where the addendum didn't match the game
- **"Pins per lane 100 / 250 / 600 / 1500":** the game has no pins-per-lane number. Since Addendum 5, the pins a throw knocks come from your ball (6 up to 3,200 in Zone 1), and only 40 pins are drawn on screen. So the zones' "more pins" is in the ball ladder: Zone 2 balls knock about 5K to 650K a throw, Zone 3 1M to 130M, Zone 4 220M to 26B. The rack you see stays at 40 pins in every zone, to keep phones smooth.
- **Gate 2 at 22K** is very cheap next to Zone 2's first ball (4.8M). A player can open Zone 2 around minute 15 and finish Zone 1's last three balls faster there, because pins sell for ×6. That speeds the end of Zone 1 up; it never slows it. I kept the addendum's rule. Stage 9 can raise the gate price if you want Zone 1 to stay as it is.
- **Very big numbers:** coins in Zone 4 with big boosts can pass 9 Qa, where the game's number type starts losing exact precision (it still works, the last digits just round). I left a note for Stage 9.

### Tested (Studio Play test, by numbers)
- All four zones built: lane, sell pad, shop, egg stand, gates and placeholder ground in each. No errors in Output.
- Gate from far away: refused ("Walk to the gate"). At the gate with 100K coins: Zone 2 opened for 22K and I landed on a throw spot in Zone 2.
- Zone 3 gate with too few coins: "Not enough coins". The prompt said "Open for 190M".
- Back gate took me to the roof. The Shop button took me to the roof's shop.
- Throws in Zone 2 filled the bag. Selling 100 pins on Zone 2's pad paid 1,500 (100 × 6 × the 2.5 boost I had).
- Zone 3's ball 21 couldn't be bought ("Open zone 3 first"). Zone 1's ball 7 bought normally.
- Resetting my character in Zone 2 respawned me in Zone 2.
- A rebirth closed the zones, put me back on the roof's lane and reset my ball.
- TEST panel jumps to Zones 4 and 3 worked.

### Not verified
- **No screenshots.** Studio's 3D view was frozen the whole session (the Studio window was hidden or minimized, 0 frames drawn), so I couldn't look at the placeholder zones, the gates or the new egg. Please look at them in your playtest: the gate is on the roof's west edge, behind the spawn.
- I didn't hatch a Speckled Egg or press the gate prompt by hand. The gate was tested through the same request the prompt sends.

**Save change:** save version 38 adds which zones you've opened and the zone you were last in. Both start at 1, so old saves need nothing.

## Stage 4: Zone 2, Sunset Boardwalk (2026-11-01, code tag `restore-a6-s4-before`)

### What changed
- **Zone 2 has a real map now** in place of the flat placeholder. It's a wooden pier over a real turquoise sea:
  - Warm plank deck with railings (coral top rail), lamp posts and pier legs going into the water.
  - The lane is **deep sea navy** (matt), with bright turquoise gutters and coral walls, so effects stand out (the rule from 1.2).
  - A striped back wall behind the pins and a big **SUNSET BOARDWALK** arch with two red-and-white towers.
  - Bunting (coral, yellow, turquoise, white flags) over the lane.
  - To the east, a **sand beach** with striped umbrellas and towels, palm trees, five pastel beach huts, a lifeguard tower, surfboards, a sandcastle and a volleyball net.
  - A **ferris wheel** on the beach, a red-and-white **lighthouse** on a rock island past the pins, sailboats and buoys on the sea, and kites in the sky.
  - The sell pad and the shop got **striped beach-hut awnings**.
- The map is built from simple parts when the server starts. It's all tagged "ZoneArt", so designed 3D models can replace it later.
- **10 new ball effects, one for each zone 2 ball**, all different. They're sea and beach themed, and they get bigger the more pins you knock:
  - 11 Seashell Spinner: a pearly shell spiral, and pearls scatter.
  - 12 Beach Ball: one big hop onto the pins, then beach-ball colour panels and bounce rings.
  - 13 Kite Flyer: rainbow kites with tails lift off the pins and fly away.
  - 14 Tide Turner: a wave of splashes rolls across the pins from one side.
  - 15 Coral Crusher: coral spikes burst up out of the lane around the pins.
  - 16 Surf Rider: a curling wave arches over the pins and crashes in foam.
  - 17 Sunset Splash: a tall sunset-coloured water column, with a rainbow in the mist.
  - 18 Pier Pounder: a giant pier post drops out of the sky onto the pins.
  - 19 Tsunami: a towering wave rises behind the pins and crashes over them (screen flash).
  - 20 Lighthouse Beam: a golden beam sweeps the pins, then a pillar of light blasts up. A spotlight follows the ball down the lane.
  - On the way down the lane: sea spray behind the water balls, pearls, kite sparkles, sunset drops, dust, or the lighthouse spotlight.
- Zone 2's balls are no longer marked as placeholders. They use the original ball designs plus their own effect.
- **Egg (3.3):** the Neon Egg already moved to zone 2 in Stage 3. Its stand is on the pier, next to the lane.

### Bugs found and fixed on the way
- **Zones 2 to 4 had night lighting.** The zone lighting only knew the rooftop, so anyone standing in a new zone got the place's default night look. Each new zone now gets the rooftop's sunny daytime look.
- **The Neon Egg (and the zone 3/4 eggs) wouldn't hatch until you'd rebirthed.** The egg lock still checked the old "zones open by rebirths" rule instead of the zones you open at the gates. Now an egg opens with its zone, and a locked stand says "REACH ZONE 3" (not "REACH 1 REBIRTH").
- **Brand-new players could get a stuck camera.** The join screen moved the camera to the old Back Alley for its fly-over, but that fly-over is switched off now, so the camera never came back. New players now start on the roof with the normal camera.
- **You could see the rooftop's city from the beach.** It's about 8,000 studs away across the open sea. While you stand in zones 2 to 4, your screen now hides the far-away rooftop city, its ground and tower, and the old switched-off alley zones. Nothing changes for other players or on the roof.

### Checklist (3.4)
- Map: lane, sell, shop, egg stand, gate and spawn all on the bright outdoor pier: **done**
- Lane passes the effect-readability test: **done** (navy lane, all 10 effects checked on it)
- 10 balls with their own effects: **done**. 10 bags: **already there** (bags 11 to 20 from Stage 3; bags have no look of their own)
- One egg with its own pets: **done** (Neon Egg, Stage 3)
- Gate wired in, price in the config: **done** (Stage 3, 22K)
- Silhouette shop rows for zone 2: **done** (Stage 2/3)
- Screenshots: **done**, in `screenshots/addendum6-stage4/` (the lane from your spot, sell + shop + gate, egg + beach, and one of each effect)

### Tested (Studio Play test, with screenshots)
- Jumped to zone 2 with the TEST panel as a brand-new player. The camera followed me, the lighting was sunny, the far city was hidden and the lane view looked right.
- Played each of the 10 effects on a zone 2 throw spot and looked at it: all are clearly readable on the navy lane. Three of them got fixes after looking: the coral spikes came out as small balls, the Tsunami splash was too small, and the Beach Ball panels were all one colour.
- Each zone 2 ball points at its own effect. The Neon Egg stand shows "19M COINS" once zone 2 is open. No new errors in Output.

### Not verified
- I didn't throw a zone 2 ball by hand (Studio can't hold the throw button from here). The effects were played straight on the lane, the same way a throw calls them.
- I didn't hatch a Neon Egg by hand. The server's lock now uses the same rule as the stand label I checked.
- Sounds: there are no water sounds in the game yet, so the sea effects borrow the whoosh, thud and boss-hit sounds. New sound slots would make them better (placeholder).
- **Placeholders still in use:** the map is simple part art (tagged "ZoneArt"). The Neon Egg stand is still the old neon-on-dark design, which doesn't fit the sunny rule, so it needs a beach-style stand. The effects use borrowed sounds.

## Stage 5: Zone 3, Jungle Falls (2026-11-02, code tag `restore-a6-s5-before`)

### What changed
- **Zone 3 has a real map now** in place of the flat placeholder. It's a sunny green jungle valley:
  - Grass ground with a dirt clearing round the sell pad, shop, egg stand and gates.
  - The lane is **deep mahogany** (matt), with aqua gutters and mossy stone walls with an orange cap, so the green, gold and water effects stand out (the rule from 1.2).
  - A bamboo back wall behind the pins and a carved stone **JUNGLE FALLS** sign with vines and big leaves on top.
  - Flower garlands over the lane (orange, pink, yellow and green) on bamboo poles.
  - Past the pins: a pool with lily pads and rocks, and a tall cliff with **four waterfalls** pouring into it (moving water, foam at the bottom), leafy ledges, hanging vines, trees along the top and **two high rope bridges** across the cliff face.
  - To the east: a river with a **rope bridge you can walk across** to a **temple ruin** (stepped stone, a stair, moss, vines, a gold sun on top, two stone statues).
  - Jungle trees, palms, giant leafy plants, flowers and mossy boulders all round the edges. Lower cliffs close the valley in on the other sides.
  - The sell pad and shop got bamboo stalls with straw roofs.
- The map is built from simple parts and terrain when the server starts, all tagged "ZoneArt" so designed models can replace it later.
- **10 new ball effects, one for each zone 3 ball**, all different and jungle themed:
  - 21 Vine Swinger: vines whip down and lash across the pins, leaves fly.
  - 22 Coconut: coconuts rain onto the pins and crack open in white splashes.
  - 23 Toucan Roll: a big toucan swoops down through the pins and flies off, rainbow feathers burst.
  - 24 Leaf Storm: a whirl of giant leaves spins round the pins, then blows outward.
  - 25 Waterfall: a waterfall pours out of the sky onto the pins, big splash, mist and a rainbow.
  - 26 Jaguar: yellow eyes flash, then three glowing claw marks rip across the pins, spots burst.
  - 27 Rope Bridge: a rope bridge swings in over the pins, snaps, and the planks crash down.
  - 28 Temple Stone: carved stones with gold glyphs circle the pins and slam together, gold sunburst.
  - 29 Monsoon: a dark storm cloud rolls over, heavy rain, then one huge lightning strike.
  - 30 Jungle King: a giant gold crown with gems slams onto the pins, gold and green shock rings, leaves and flowers everywhere.
  - On the way down the lane: falling leaves, feathers, water spray, dust, gold dust or gold sparkles, depending on the ball.
  - Effects that drop something (coconuts, crown, bridge planks...) make the pins wait up to 0.2 seconds for it to land, same as zone 2's Pier Pounder.
- Standing in one outdoor zone now also hides the other outdoor zones' maps on your screen (they're 2,500 studs apart, but you could see them far off).
- The egg stand (Main Street Egg) and the gate were already in from Stage 3.

### Checklist (3.4)
- Map: lane, sell, shop, egg stand, gate and spawn all in the bright outdoor valley: **done**
- Lane passes the effect-readability test: **done** (mahogany lane, all 10 effects checked on it)
- 10 balls with their own effects: **done**. 10 bags: **already there** (bags 21 to 30 from Stage 3)
- One egg with its own pets: **done** (Main Street Egg, Stage 3)
- Gate wired in, price in the config: **done** (Stage 3, 190M)
- Silhouette shop rows for zone 3: **done** (Stage 2/3)
- Screenshots: **done**, in `screenshots/addendum6-stage5/` (the lane from the spawn in Play, the falls, the river + temple, a top view, and one of each effect)

### Tested (Studio, with screenshots)
- Jumped to zone 3 in a Play test: sunny look, map and lane all there, stations sit under their stalls, no new errors in Output.
- Played each of the 10 effects on a zone 3 throw spot and looked at it. Five got fixes after looking: Vine was too thin, Jaguar's claw marks were too faint (now solid glowing marks), Rope Bridge planks vanished before you could see them, Temple Stone showed a wrong picture on the floor, Monsoon's storm cloud was off screen and too faint.
- Map fixes after looking: the waterfalls were hidden inside the cliff rock, the cliff was bare grey (now leafy ledges, vines, trees on top, warmer rock), the temple stair stuck out over the river.

### Not verified
- I didn't throw a zone 3 ball by hand. The effects were played straight on the lane, the same way a throw calls them.
- Studio's 3D view froze at the start of the session, so some map pictures (02 to 04) were taken in edit mode with the zone's daytime lighting switched on just for the picture (all put back after). In one of those, part of the north cliff didn't draw, though the cliff is there. The Play-test picture (01) is the real in-game look.
- Rock and leafy-grass colours in the game are shared across every zone, so zone 2's lighthouse rocks are now the same warm green-grey stone.
- Sounds: still borrowed (whoosh, thud, boss hit, crate land). Jungle sounds (birds, rain, roar) would need new sound slots (placeholder).
- **Placeholders still in use:** the map is simple part art (tagged "ZoneArt"). The Main Street Egg stand is still the old Main Street design and doesn't match the jungle. Zone 3's balls still use the old ball models (only their effects are new). Borrowed sounds.

## Stage 6: Zone 4, Canyon Oasis (2026-11-02, code tag `restore-a6-s6-before`)

### What changed
- **Zone 4 has a real map now** in place of the flat placeholder. It's a sunny red-rock canyon:
  - Warm sand floor with light packed paths to the sell pad, shop, egg stand, gates and the oasis.
  - The lane is **deep plum** (matt), with turquoise gutters and terracotta stone walls with a gold cap, so sand, gold, fire and turquoise effects all stand out (the rule from 1.2).
  - An adobe back wall with a turquoise and gold tile band, and a carved **CANYON OASIS** sign on banded pillars with gold suns on top.
  - Pennants over the lane (terracotta, gold, turquoise, white). Striped market awnings over the sell pad and the shop.
  - Past the pins: a **turquoise lake** with a **huge natural stone arch** standing in it, rock towers (hoodoos) along the shore and palms at the water's edge.
  - Tall **red canyon walls in terracotta and peach bands** on every side, with a gap at the far end that shows distant flat-topped buttes.
  - To the east: a **palm oasis** with a pond (lily pads, reeds, a little wooden dock), market tents with rugs and clay pots, and a **golden sphinx** on a stone plinth.
  - Adobe houses with turquoise doors and chilli strings, saguaro cacti (some with pink flowers), boulders, desert flowers, and **five striped hot-air balloons** in the sky.
- The map is built from simple parts and terrain when the server starts, all tagged "ZoneArt" so designed models can replace it later.
- A warmer golden haze in the sky for this zone only.
- **10 new ball effects, one for each zone 4 ball**, all different and desert themed:
  - 31 Dust Devil: a whirling column of dust sweeps across the pins, tumbleweeds bounce out.
  - 32 Cactus Roller: saguaro cacti burst up through the pins, spines fly, pink flowers pop on top.
  - 33 Mesa Smash: a red flat-topped mesa drops out of the sky onto the pins, rock chunks and rings.
  - 34 Sandstorm: a towering wall of sand sweeps across the pins from the side (the screen goes orange for a moment on big hits).
  - 35 Oasis Spring: a turquoise spring shoots up out of the pins, palm fronds fan open round it, water rains down.
  - 36 Scorpion: a giant scorpion tail curls over from beside the pins and stings the middle, a burst of hot venom.
  - 37 Sun Disc: a blazing gold sun disc appears over the pins and burns rays down into them.
  - 38 Canyon Echo: two red rock walls burst up beside the pins and the hit bounces between them three times.
  - 39 Mirage: see-through copies of the ball close in from all round, merge, and the air ripples turquoise.
  - 40 Golden Sphinx: a giant golden sphinx head rises behind the pins, its eyes fire beams into them, a glowing pyramid outline and a gold blast.
  - On the way down the lane: sand dust, turquoise droplets or sparkles, gold sparkles with a warm glow, or sound rings, depending on the ball.
  - Effects that drop or swing something in (mesa, scorpion tail, sphinx...) make the pins wait up to 0.2 seconds for it, same as zones 2 and 3.
- The Skyline Egg stand and the gate were already in from Stage 3.

### Checklist (3.4)
- Map: lane, sell, shop, egg stand, gate and spawn all in the bright outdoor canyon: **done**
- Lane passes the effect-readability test: **done** (plum lane, all 10 effects checked on it)
- 10 balls with their own effects: **done**. 10 bags: **already there** (bags 31 to 40 from Stage 3)
- One egg with its own pets: **done** (Skyline Egg, Stage 3)
- Gate wired in, price in the config: **done** (Stage 3, 240B)
- Silhouette shop rows for zone 4: **done** (Stage 2/3)
- Screenshots: **done**, in `screenshots/addendum6-stage6/` (the lane from the spawn in Play, the lake and arch, the oasis, the sphinx, and one of each effect)

### Tested (Studio Play test, with screenshots)
- Stood in zone 4 in a Play test: sunny look, map and lane all there, stations in place, no new errors in Output.
- Played each of the 10 effects on the zone 4 lane and looked at it. Five got fixes after looking: the cacti were square posts (now round saguaros with arms), the sandstorm was too thin, the scorpion tail was hidden edge-on and then ended under the floor (now a clear curl from the side), the sun disc was too high and lying flat (now faces you, with an orange rim), the echo was hard to see (now a glowing wave crosses between the walls).
- Map fixes after looking: the dirt paths near the spawn were too dark, and the gold sphinx, sign suns, tents and balloons looked dull (metal and fabric looks darken colours in this lighting; now plain bright).

### Not verified
- I didn't throw a zone 4 ball by hand. The effects were played straight on the lane, the same way a throw calls them.
- Some effect pictures are "frozen" copies of the effect at its key moment, because the picture tool kept landing after the effect had ended (scorpion, echo).
- Sounds: still borrowed (whoosh, thud, boss hit, power-up). Desert sounds (wind, rattle, roar) would need new sound slots (placeholder).
- **Placeholders still in use:** the map is simple part art (tagged "ZoneArt"). The Skyline Egg stand is still the old cloud/night design and doesn't match the canyon. Zone 4's balls still use the old ball models (only their effects are new). Borrowed sounds.

## Stage 7: Rebirth pacing (2026-11-02, code tag `restore-a6-s7-before`)

### What I found
- The old pacing tool only knew one zone, so I built a new one that plays all four zones, gates, eggs, pets and rebirths (`tools/pacing_sim.py`). Stage 9 will use it too.
- **With the old rebirth numbers, rebirthing as soon as you could was a trap.** Rebirth was so cheap that you rebirthed every ~20 minutes and never got past the start of Zone 2. A player who waited got all the way to Zone 4. That breaks rule 4.
- **"Cost x3 each rebirth" can't work with four zones.** Each new zone makes about 100 times more money than the one before (pins sell for x6 and the balls are bigger). A price that only triples gets cheap very fast, so rebirths could never come "deeper into the zones". So I set each rebirth's price by **where** it should come, as the addendum asks. The x3 rule is used after that (rebirth 8 on).
- **The +50% coins / +25% pins starting boost was too small.** With it, waiting 20 minutes before rebirthing was faster than rebirthing straight away. The addendum says: raise the boost, don't lower the price. So I raised it.

### What changed (numbers only, all in the config)
- **Boost per rebirth: +200% coins and +100% pins** (was +100% / +100%). After rebirth 1 you earn x3 coins and x2 pins.
- **Rebirth prices:** 5.4M, 450M, 88B, 2T, 7.1Qa, 60Qa, 400Qa, then x3 each.
- **Shop prices after a rebirth rise less:** balls, bags and gates cost x1.6 after rebirth 1, x2.0 after 2, x2.3 after 3 (before: x3.0, x5.8, x9.2).

### What the sim shows (a player who rebirths as soon as they can)
| Rebirth | Comes at (played) | Where | Addendum target |
|---|---|---|---|
| 1 | ~35 min | Zone 1 done, first balls of Zone 2 (price = ~4.5 min of income when Zone 1 is done) | end of Zone 1, 4-5 min of income |
| 2 | ~56 min | Zone 2, ball 7 | middle of Zone 2 |
| 3 | ~1h11 | Zone 3, ball 5 | start of Zone 3 |
| 4 | ~1h20 | Zone 3, ball 9 | end of Zone 3 |
| 5-7 | 1h28 to 1h37 | Zone 4 | later ones in Zone 4 |

- **Getting back to where you were (rule 2):** 23% of the run before after rebirth 1, then 44%, 53%, 59%, 47%, 47%. So about half, except the first comeback, which is faster (pets plus x3 coins). I left that, it makes the first rebirth feel great.
- **Rebirth now vs wait (rule 4, 6 pet-luck seeds):** rebirthing at once reaches rebirths 1 to 4 first (for example rebirth 4 at 1h10 vs 1h18 for someone who waits 20 minutes each time), and is level (within a minute) at rebirths 5 to 7. From rebirth 8 on, a player who waits 20 minutes is about 4 to 28 minutes ahead.

### Not verified / for Stage 9
- **Zone 4 pets are very strong.** Once a player has a few Skyline Egg pets, Zone 4 takes only minutes and rebirths 5 to 8 come minutes apart. Then the x3 price takes over and rebirth 10, 11... get slow (a wall at about 2 hours). That's why waiting wins at rebirth 8+. This is an egg and pet strength problem, not a rebirth one. Stage 9 (pacing pass) will fix it, then I'll re-check rule 4.
- The sim's player buys the cheapest thing first and hatches each egg 3 times per run. Real players will differ.
- Checked in Studio (Play test): the game uses the new prices and boosts (rebirths 0 to 9 printed), and the shop's Rebirth tab shows "+200% coins, +100% pins a throw" and "5.4M coins" (`screenshots/addendum6-stage7-rebirth-tab.jpg`). I didn't play a whole run by hand.
- **Placeholders still in use:** none new.

---

## Stage 8: Gamepasses (2026-11-02, code tag `restore-a6-s8-before`)

### What changed
- **New PASSES tab in the shop window** (after Balls, Bags, Rebirth). One card per pass: picture, name, what it does, and a green Robux price button, or a grey OWNED when you have it. The top line says how many you own. Passes can be bought from anywhere, not only at the shop pad (they're Robux, not coins).
- **Small gold PASSES button on the HUD**, right of PROFILE (on phones: right of STORE). It opens the PASSES tab.
- **One new pass: 2X PINS** (double pins every swing, forever). It feeds the "Passes" slot of the pin multiplier, the same way 2X COINS feeds the coin one.
- **The HUD multiplier card now shows the passes for pins too**: under PIN MULTIPLIER there's a GAME PASSES chip next to PINS A SWING. Coins already had a GAME PASSES row.
- **Studio TEST panel: a GAME PASSES section** with one button per pass. Tap = on / off for this test only (green = on). Nothing is saved and it never exists in the live game.
- A pass with no Creator Hub ID yet is **hidden in the live game** (in the shop tab and in the old STORE window). In Studio it shows with a red NO ID YET, and BUY gives it free for the test.

### The addendum's list, mapped onto the passes you already have
| Addendum asks for | Pass in the game | Status |
|---|---|---|
| 2x Coins | 2X COINS (DoubleCoins) | already live |
| 2x Pins | **2X PINS (DoublePins)** | **new, needs creating** |
| Lucky Eggs | LUCKY (x2 luck) + SUPER LUCKY (x4) | already live (eggs and crates) |
| Triple Hatch | TRIPLE HATCH | already live |
| Auto Swing | AUTO BOWL | already live (an AUTO button that keeps throwing while you stand on your lane) |
| +2 Pet Slots | +2 PET SLOTS | already live |
| (extra) | VIP | already live, kept in the tab |

Note: everyone gets a free AUTO after their first rebirth (same speed). So AUTO BOWL mostly helps before rebirth 1. Tell me if you want the free one slower or gone.

### What you need to create in Creator Hub (only one thing)
1. Creator Hub > your game > Monetization > **Passes** > Create a Pass.
2. Name: **2X PINS**. Description: "Double pins every swing, forever. Stacks with potions." Picture: any for now (see placeholders).
3. Turn on **Item for Sale**, price **399 Robux** (or what you like; then tell me the price too).
4. Copy the pass ID (the number in its page link) and send it to me.
5. Where it goes: the config file, `Config.Monetization.Passes`, the row `Id = "DoublePins"`, in `PassId = 0` (0 becomes your number). Until then 2X PINS simply doesn't show in the live game.

### Tested (Studio Play test, with screenshots in `screenshots/addendum6-stage8/`)
- PASSES button shows right of PROFILE and the PASSES tab opens with all 8 passes; your account owns the 7 real ones (OWNED), 2X PINS shows NO ID YET + R$ 399 (`hud-passes-button.jpg`, `gamepasses-tab.jpg`).
- Bought 2X PINS (Studio, free): pin multiplier went x1 -> x2, and the card turned OWNED.
- TEST panel: 2X COINS off -> coin multiplier x2.5 -> x1.25 (only VIP left); back on -> x2.5.
- HUD card shows GAME PASSES x2.5 for coins and GAME PASSES x2 for pins (`breakdown-2x-pins.jpg`).
- No errors in Output from the new code.

### Not verified
- I didn't throw by hand to watch the pin count double. The throw uses the same pin number I checked (x2), so it should.
- The phone layout of the PASSES button wasn't looked at on a phone-sized screen.
- The real Robux buy prompt for 2X PINS can't be tested until the pass exists.

### 2-minute test
1. Press Play. Next to PROFILE there's a gold **PASSES** button. Tap it: the shop opens on the **Passes** tab. Expected: 8 cards, your 7 owned ones say OWNED, 2X PINS says NO ID YET with R$ 399.
2. Tap 2X PINS's price. Expected: a "2X PINS is yours" message and the card turns OWNED (free, Studio only).
3. Tap the **x2.5** badge under your coins. Expected: under PIN MULTIPLIER, PINS A SWING x2 and GAME PASSES x2.
4. Open the purple **TEST** tab > GAME PASSES, tap 2X COINS (it goes grey). Expected: the badge drops to x1.25. Tap again: back to x2.5.
5. Throw a few times with 2X PINS on vs off (TEST panel). Expected: about twice the pins.
- **Silent failures to watch:** the PASSES button missing (the shop window didn't load), the tab showing no cards (store switched off), or 2X PINS showing in the live game before you add its ID (it shouldn't).

### Placeholders still in use
- **2X PINS picture**: uses the HUD pin icon (`Pass2xPins` in AssetSlots, tagged PLACEHOLDER). A real 2X PINS icon in the store kit style would replace it.
- **2X PINS pass ID**: 0 until you create it (above).

---

## Stage 9: Pacing pass (2026-11-02, code tag `restore-a6-s9-before`)

Built while you were asleep. Every decision is mine and written down here. The full tables are in
`PACING_REPORT.md` (time to every ball and bag in all 4 zones, gates, rebirths, waits, comebacks).

### What I found (simulated playthrough, fresh player, no passes)
- **Zone 1 is fine and untouched**: ball 10 at ~21 min, zone 2 gate at ~17 min, rebirth 1 at ~33 min, costing
  ~4 minutes of income when zone 1's ladder is done.
- **Zones 3 and 4 flew by.** A new zone 3 ball came every 6-50 seconds, and the whole zone 4 ladder took about
  2 minutes. Their prices were set for a player with no rebirths, but you get there with 2-4 rebirths and strong pets.
- **Zone 4 pets snowballed** (the known problem). By rebirth 5, pets alone multiplied income ~16x (~50x for someone
  who hatches a lot), mostly through the Bag stat. Eggs don't get pricier after a rebirth, so later hatches were
  almost free.
- **Rebirths 3 to 8 came minutes apart** and cost under 20 seconds of income, and the game was "done" at ~1h20.
  After that, rebirth 10 took ~2h and rebirth 12 another 5-10 hours.

### What changed (config numbers only, no systems)
- **Zone 2 balls 2-10, zone 3 and zone 4 balls:** re-priced so each new ball comes about as far apart as in zone 1
  (2-3 min early in a zone, 4-5 min later, quick after a gate opens). Examples: zone 2 ball 2 5.4M -> 9.3M, zone 3
  ball 1 5.9B -> 28B, zone 3 ball 10 1.2T -> 19T, zone 4 ball 1 7.1T -> 110T, zone 4 ball 10 1.4Qa -> 41Qa.
- **Bags 12-40:** re-priced with the balls (each still sits between two balls). E.g. zone 4's last bag 1.9Qa -> 56Qa.
- **Gates:** zone 3 190M -> 320M, zone 4 240B -> 1.5T (still "the zone before's ball 7").
- **Eggs:** Neon 19M -> 33M, Main Street 23B -> 360B, Skyline 28T -> 2.9Qa. A hatch now costs about 1 minute of
  income when you first reach each egg (the Speckled Egg costs the same in zone 1).
- **Rebirth prices 2-7:** 450M -> 3.8B, 88B -> 120B, 2T -> 200T, 7.1Qa -> 1.2Qa, 60Qa -> 14Qa, 400Qa -> 220Qa (then
  x3 each, as before). Rebirth 1 stays 5.4M. They now come at: 2 = middle of zone 2 (~1h01), 3 = start of zone 3
  (~1h28), 4 = end of zone 3 (~2h12), 5 = zone 4 ball 3 (~2h52), 6 = zone 4 ball 6 (~3h32), 7 = zone 4 done
  (~4h20). Each takes 2-3 minutes to save for.
- **Zone 3 pets (Main Street Egg) weaker:** Wood Pup Bag +0.6 -> +0.3; Chrome Bat Coins +1.2 -> +0.6, Bag +1 -> +0.4;
  Kingpin Pins +2.5 -> +1.2; Blaze Coins +4 -> +1.5, Speed +0.4 -> +0.3.
- **Zone 4 pets (Skyline Egg) weaker:** Cloud Bumper Bag +1.5 -> +0.5, Pins +0.8 -> +0.6; Moony Coins +2.5 -> +1.5,
  Bag +2 -> +0.7; Cosmo Coins +12 -> +3, Pins +6 -> +2; Perfecto Pins +10 -> +3, Speed +0.6 -> +0.5. Each zone's best
  pet is still clearly stronger than the zone before's. Players who already own these pets keep them; they just
  give less.
- **Not changed:** all of zone 1, the zone 2 gate, rebirth 1, the rebirth boost (+200% coins, +100% pins), how much
  prices rise after a rebirth, pet slots, pin values, the Neon Egg's pets.
- The pacing tool got the Stage 9 measures (`python tools/pacing_sim.py stage9`).

### What the sim shows now
- **Rebirth comebacks (rule 2):** back to where you were in 23% of the run before after rebirth 1, then 40-64%.
  "About half", with the first comeback faster (as in Stage 7).
- **Rebirth now vs wait (rule 4):** rebirthing at once is first, or within 3 minutes of first, at every point
  checked, and finishes all 40 balls 33-60 minutes before players who wait 5-20 minutes each time. Never
  rebirthing is ~3 hours slower. To get there I moved rebirth 4 to the end of zone 3 and rebirth 7 to the end of
  zone 4. When they came one ball earlier, waiting 5 minutes won (the last ball was cheap). Raising the boost
  didn't help, so the boost stays as it is.
- **No waits over 8 minutes** with nothing to buy until about 5 hours in (rebirth 8). After that, only rebirths are
  left and they cost x3 each: ~10-15 min for rebirth 9, ~30 for 10, 1-2 hours for 11. That's the end-game wall
  until a 5th zone exists. If you want it gentler, say so: rebirth Growth 3 -> 2 is one number.
- **Heavy hatchers** (15 hatches of each egg a run) finish ~30% faster (2h56 vs 4h13) and it levels off. Before,
  they finished in about an hour.
- **Whole game for the pretend player:** zone 1 ~22 min, zone 2 done ~1h20, zone 3 done ~2h08, zone 4 done ~4h13.

### Checked in Studio (Play test, synced with the http trick + UpdateSourceAsync; the config is over 200K)
- The server uses the new numbers: zone 2 ball 2 9.3M, zone 3 ball 1 28B, zone 4 ball 10 41Qa (110Qa after 6
  rebirths), gates 320M / 1.5T, eggs 33M / 360B / 2.9Qa, rebirths 5.4M, 3.8B, 120B, 200T, 1.2Qa, 14Qa, 220Qa, 660Qa,
  1.98Qi, and the new pet stats (Cosmo Coins 3 Pins 2, etc.).
- The shop's Balls tab shows every new price, from 4.8M (zone 2 ball 1) to 41Qa (zone 4 ball 10).
- No errors in Output.

### Not verified
- **I didn't sell by hand after the change.** My test tool couldn't fill the bag. The sell code and pin values
  weren't touched, so payouts only change through the weaker zone 3/4 pets.
- I didn't play the game for hours. Everything above comes from the simulator. Real players will hatch more than
  3 times a run once eggs are cheap, so the real game may run up to ~30% faster than the tables.
- The place in Studio has the new config but is **not saved to Roblox** (as asked). Save it when the test passes.

### 2-minute test
1. Press Play (TEST panel: START FROM ZERO is fine). Walk onto the blue shop circle. Balls tab, scroll down.
   Expected: zone 2 ball 2 = **9.3M**, zone 3 ball 1 = **28B**, zone 4 ball 10 = **41Qa** (all greyed with a lock).
2. Rebirth tab. Expected: rebirth 1 still **5.4M**. TEST panel > READY TO REBIRTH, rebirth, and the tab now asks
   **3.8B** for rebirth 2 (it was 450M).
3. TEST panel > JUMP TO ZONE 4, go to the egg stand. Expected: the Skyline Egg costs **2.9Qa**. Hatch with FREE EGG and
   open the PETS panel. Expected: Cosmo / Perfecto / Moony / Cloud Bumper show the smaller bonuses (Cosmo x4 coins,
   x3 pins).
4. Throw a few times and sell. Expected: the sell popup's number = pins x the zone's pin value x your multiplier,
   as before.
- **Silent failures to watch:** old prices still showing (Studio has an old config: Rojo or the sync didn't run),
  zone 1 prices changed (they mustn't: ball 10 = 590K, bag 10 = 690K, Speckled Egg 750), or a pet showing its old
  big bonus.

### Placeholders still in use
- None new. Still from earlier stages: zone 3/4 ball models are re-used existing balls; the zone 4 egg stand is the
  old cloud design; the 2X PINS picture and pass ID (Stage 8); some borrowed sounds (Stage 6).
