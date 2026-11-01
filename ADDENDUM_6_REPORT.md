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
