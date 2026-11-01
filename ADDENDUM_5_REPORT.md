# Addendum 5 overnight report (2026-11-01/02, owner asleep)

One section per step (plan: ADDENDUM_5_PLAN.md). Each: what changed, restore tag, commit, 2-minute test, choices made for you.
At the end: one combined morning playtest.

## Step 0: audit (2026-11-01)
- No game changes. Wrote `AUDIT_ADDENDUM_5.md`: the ball and bag ladders, how buying, selling, pins, pets, levels and rebirth work today, the save fields (v34), and a plan for the one shared lane.
- Main findings: the BALLS button opens the shop with BUY buttons, and buying works from anywhere because the server never checks where you stand. The SELL button only shows a beam; it doesn't teleport you yet. Pins are capped at 40 and a full clear pays x2. Pets only boost coins, every egg is locked behind zones on the roof, and Shiny merge only works at the zone 3 machine, so you can't reach pets or merge from the roof. Rebirth is switched off while the core loop is on. Throw poses follow rank level, so if levels go away everyone would be stuck on the first pose.
- Shared lane plan: one 98-stud-wide lane in the same spot as the 6 old lanes, with 12 throw spots 8 studs apart. It gets built from code when the server starts and the old lanes are moved to ServerStorage. Each player only sees their own 40-pin rack, other players' balls are drawn light, and new collision groups stop pins hitting players.
- Nothing to test. Restore tag: none (nothing changed).

## Step 1 (A1): pins are a number, no levels (2026-11-01)
**What changed**
- Each throw now counts the real number of pins, with no 40 cap. Only the 40 rack pins are drawn: a strong ball knocks all 40 on screen while the counter says e.g. "3.2K". The counter and the coin pops use the big-number format (K, M, B...). The old "12/40" is gone.
- No more full clear and no more x2 for it.
- The +-20% luck roll stays. When it rolls in the best quarter (+10% to +20%), a tilted gold LUCKY! tag pops on the pin counter, the counter number turns gold, and the coin pop gets a gold LUCKY! label. Lucky throws with a strong ball also shake the camera and play the big crash.
- Steeper pins per ball: 6, 10, 18, 35, 70, 140, 300, 650, 1.4K, 3.2K (was 6, 9, 12 ... 43). Bag sizes and prices were scaled with it, so every step still takes the same time (EconomySim: ball 10 at 47 min, last bag at 51 min, same as before). Step A2 will split balls and bags into two ladders.
- No levels: throws give no XP, the XP bar is hidden, no "LV 12 PRO" over heads, no level-reward preview, rebirth asks for no level (coins only), eggs ignore any level, the profile drops LEVEL and the level/full-clear rows, the store hides XP BOOST (card and HUD pill) and calls the 2X pass "2X COINS". Gifts that gave an XP potion give the coin potion of the same size. All the old code is still there: `Config.CoreLoop.NoLevels = false` brings levels back.
- The throw animation now follows your ball (ball 1 = scuffed, ball 8 = clean, ball 10 = the biggest pro throw), not your level.
- Leaderboard numbers are clamped so huge pin counts can't break the save.

**Restore tag:** `restore-a5-A1-before`. **Commit:** 5ced992.

**2-minute test**
1. Play. Hold THROW on your lane. Expected: the counter shows "5" or "6" (no "/40"); about 1 throw in 4 shows a gold LUCKY! tag on the counter for under a second.
2. TEST panel > COINS x10 a few times, then buy balls at the shop up to ball 5 (Gust). Expected: all 40 pins fall every throw, the counter shows about 56 to 84, the pop over the pins shows the coins.
3. Look at the top of the screen: no XP / level bar. Look at your avatar: no "LV 1 ROOKIE" tag.
4. Open STORE: BOOSTS has only COIN BOOST; the pass says 2X COINS.
- Silent failures to watch for: the counter stuck on "0"; LUCKY! never showing; the throw pose not getting cleaner after new balls; something still saying "LEVEL" or "XP".

**Choices made for you**
- LUCKY = the best 25% of rolls (`Config.CoreLoop.LuckyFrom = 0.25`).
- Pins curve about x2 per ball, and bag sizes/prices scaled to keep the old pacing (A2 re-paces).
- Pose per ball: `Config.CoreLoop.Poses = {1,2,3,4,5,6,7,9,10,12}`.
- XP potions in gifts swapped for coin potions; XP BOOST hidden from the store (the Roblox product still exists, just not shown).
- The full-clear cheer/confetti/gold flash is gone (it would fire every throw now); camera shake + crash only on LUCKY throws with 24+ drawn pins.
- Left as is: the Studio-only TEST panel still has +1 LEVEL / PASS TRIAL buttons; pet "strike" hops no longer happen (no strikes); the PIN CRUSHER achievement goals (1K..500K pins) will now be reached quickly (step E can retune).

**Playtest note:** Studio's 3D view was frozen on an old frame all session (screenshots timed out; restoring the window didn't help, and I didn't restart Studio in case the place has unsaved work). Checked by numbers instead: `screenshots/addendum5/A1/PLAYTEST_LOG.md` (ball 10 = 2.7K-3.8K pins per throw, 40 drawn, counter "3.2K", pose 12, XP stays 0, no errors). Later steps may also be unable to take screenshots until Studio is restarted.

**Placeholders:** none new.

## Step 2 (A2): two ladders, buy only at the shop, SELL teleports (2026-11-01)
**What changed**
- Balls and bags are now two separate ladders. You can buy the next ball or the next bag in any order; neither waits for the other. A small bag still holds your income back (a throw that doesn't fit only pays what fits), so bags still matter.
- New prices (EconomySim, a player who buys whichever is cheaper): ball 2 in the first ~15 s, balls 3, 4, 5 about 2 min apart, balls 6 to 10 about 5 min apart (ball 10 at ~31 min, last bag at ~35 min). Balls: 50, 500, 950, 1.9K, 10K, 21K, 45K, 99K, 220K. Bags: 240, 600, 990, 5.2K, 11K, 24K, 54K, 120K, 420K. Pins and bag sizes didn't change.
- Buying only works at the shop booth. The server checks you stand on (or right next to) the blue circle; from anywhere else it answers "Buy it at the shop". Power Levels can't be bought in this game any more either.
- The BALLS button now opens a price list: every ball and bag, what you have, what's next and its price, but no buying. Its blue GO TO SHOP button teleports you onto the shop circle, and the list turns into the real shop.
- SELL teleports you onto the green sell pad, and the bag sells there (nowhere else). The guide card now says "Tap Sell", then "Buy the Rubber Bouncer at the shop".
- New shop window: a gold tilted SHOP tab, red X, a coin pill that counts up, two lists (Balls with 3D balls, Bags) with rarity-coloured stripes (grey, green, blue, purple, gold, and a turning rainbow for Sonic Boom). Your current one says USING (blue), older ones OWNED, the next one has its price (green when you can buy it, grey while saving), later ones are faded. Buttons squash when pressed and bounce back; a buy throws confetti and pops the next row.
- Goal bar: "Next: <whichever is cheaper>", and "buy it at the shop" when you can afford it.

**Restore tag:** `restore-a5-A2-before`. **Commit:** 3bb2a95.

**2-minute test**
1. Play. Hold THROW until the bag is full. Tap SELL. Expected: you jump onto the green pad, the bag empties, coins go up.
2. Tap BALLS. Expected: the price list with all 10 balls and 10 bags, the next ones with a gold price, a blue GO TO SHOP button, no way to buy.
3. Tap GO TO SHOP. Expected: you land on the blue circle and the window says "You're at the shop"; Rubber Bouncer has a green 50 button. Buy it.
4. TEST panel > COINS. At the shop buy two bags in a row, then a ball. Expected: all three work (no "get the ball first").
5. Walk a few steps off the circle. Expected: the shop closes.
- Silent failures to watch for: SELL doing nothing (no jump), the shop opening but every button grey even with coins, the price list letting you buy, the window staying tiny or stuck half open, the guide card stuck on "Sell" after selling.

**Choices made for you**
- Ball pacing taken literally: balls 3-5 ~2 min each, balls 6-10 ~5 min each (the ladder has only 10 balls, so nothing comes "after" yet). Ball 2 stays the first-30-seconds buy (50 coins).
- Bag pacing: each bag lands about 40% of the way between two balls (bag 2 ~1 min, then 2 min, then 5 min apart).
- `Config.CoreLoop.Ladders.Independent = true` (false = the old alternating order back). Buy range = circle radius 4.5 + `Shop.BuySlack` 4 studs.
- GO TO SHOP teleports (like SELL), so the price list gets you to the shop in one tap. Teleports have a 1.5 s cooldown (`Config.CoreLoop.Teleport`).
- You land on the sell pad facing the lanes and on the shop circle facing the counter. You walk back to your lane yourself.
- "Using" badge is sky blue so it can't be mistaken for a green BUY button.
- Ball rows show each ball's rarity colour from a new `Rarity` field on `Config.CoreLoop.Balls`; bags use the colour of the ball at the same step.
- Left as is: gem buys in the STORE (cosmetics) and Robux items still work from the store window (they are not coin buys of the ladder). Eggs/pet slots/rebirth get the same shop check in their own steps.
- A Studio-only `TestOpen` attribute on CoreShopUI opens the price list (for tests; does nothing in the live game).

**Playtest note:** Studio's 3D view was still frozen (viewport 1x1, no RenderStepped, screen_capture timed out), so no screenshots again. All checks were done with numbers: `screenshots/addendum5/A2/PLAYTEST_LOG.md`. Not checked live: the guide card colours and the button bounce (they only run when Studio draws frames). Restarting Studio should fix the frozen view.

**Placeholders:** none new (bag icon = the existing store bag image).

## Step 3 (A3): one shared lane (2026-11-01)
**What changed**
- The 6 rooftop lanes are replaced by ONE big lane (99 studs wide, same place, same length). Everyone throws down it at the same time from their own throw spot: 12 coloured, numbered rings across the front of the lane, 8 studs apart. You get the middle free spot when you join (then outwards). With more than 12 players, spots 13-60 fit in between and a row further back, so nobody is ever without a spot (before, the 7th player had no lane).
- Your pins are drawn only on your screen, at your spot (one 40-pin rack per player). Other players' throws show as a plain ball rolling down their spot (no effects, at most 8 at once); their pins are never drawn on your screen. Counting stays on the server, per player.
- Collision groups: your pins never hit players (yours or others'), balls touch nothing.
- Cooldown is yours alone (each spot keeps its own timer).
- Looks (all built from code at server start): two-tone light maple wood strips (one per spot) with thin gold lines between them, a gold arrow and two coloured dots per spot, your name painted near the foul line ("6 · SELIM"), a big cream/orange MEGA LANE sign hanging from the gantry ("EVERYONE BOWLS TOGETHER!") with rainbow pennants along the beam, 5 soft lights over the lane. Your own ring glows gold, and a bouncing "YOUR SPOT" tag floats over it while you're off it.
- Lane skins still work: each player's skin paints their own strip of the lane and approach.
- The old lanes, their approach lines and the 6-lane floor decor are moved to ServerStorage while the game runs (nothing deleted; the Studio place still has them). `Config.CoreLoop.SharedLane.Enabled = false` brings the 6 lanes back.

**Restore tag:** `restore-a5-A3-before`. **Commit:** 5bae379.

**Footprint:** x -86.2 .. 13.2 (between the old outer gutter walls), foul line z -3451, pin decks z -3562 .. -3581, floor top y 848.655 (where the pins stood before). Throw rings at z -3444. Nothing in the plaza moved (sell pad, shop, spawn, cases, lounges). Drawing: `screenshots/addendum5/A3/footprint.svg`.

**2-minute test**
1. Play. Expected: you stand on a coloured numbered ring (the middle one) on one wide wooden lane, your name on the floor in front, MEGA LANE sign above.
2. Hold THROW. Expected: your 40 pins fall at your spot, counter as before.
3. Walk two rings over and hold THROW. Expected: nothing throws; a gold "YOUR SPOT" tag points at your ring. Walk back: throwing works.
4. With a friend (or Studio Test > 2 players): both throw at once. Expected: you see their plain ball roll down their spot but never their pins; each counter/bag only moves with your own throws.
- Silent failures to watch for: standing on the old lane spot instead of a ring, pins missing at your spot, other players' pins showing on your screen, your character getting knocked by pins, the YOUR SPOT tag staying up while you're on your ring, numbers/names on the floor reading upside down.

**Choices made for you**
- 12 front spots 8 studs apart (the old proposal); up to 60 spots so a full 60-player server always fits (`MaxSpots`).
- Your spot's throw box is your ring's strip only, so the ball always leaves from your ring (no throwing from someone else's spot).
- Other players' balls are plain balls (shown even with "other players' effects" off; they cost almost nothing), capped at 8 (`OtherBalls`; 0 hides them).
- Others get a light throw message (no pin list) to save network.
- Extra spots (13+) have no lane-skin plates (they overlap the front strips).
- The old per-lane scoreboards on the gantry left with the old lanes (they showed streak/rank, which no longer exist).

**Playtest note:** Studio's 3D view was still frozen, so no screenshots again; checked by numbers with a fake second thrower (`screenshots/addendum5/A3/PLAYTEST_LOG.md`). The look of the lane (colours, sign, arrows, which way the floor numbers read) is NOT verified; please look at it first in the morning. A real 2-player test was not possible from here.

**Studio-only edits:** a new ModuleScript `ServerScriptService.Server.Modules.SharedLane` was created in the Studio place (same as the repo file; Rojo would create it too). Save the place to keep it, or reconnect Rojo.

**Placeholders:** none new (all parts from code, no new art).

## Step 4 (B1): pet stats + pet slots (2026-11-01)
**What changed**
- Pets now give stat boosts of four kinds: **Coins** (coins per pin), **Pins** (pins per swing), **Bag** (how much the bag holds) and **Speed** (more throws per second). Each pet has one or two (table below, in `Config.Mascots` `Stats`).
- Same-stat boosts from your equipped pets add up (+25% and +10% Coins = +35%), and that total multiplies with everything else (rebirth, potions, passes). `Config.PetStats.Stacking = "Add"` ("Multiply" = each pet multiplies on its own).
- All on the server: Coins in the coin multiplier, Pins in the pins per swing (still only 40 pins fall on screen), Bag in the bag size (the HUD bag bar uses the same number), Speed shortens the time between throws but never below the 0.4 s floor.
- Equip slots: 3 to start, 5 more bought with coins **only at the ball shop** (new PET SLOTS row at the bottom of the shop window: 2.5K, 25K, 150K, 600K, 2.5M). Rebirth keeps them (`KeepPetSlots = true`). The +2 PET SLOTS pass still adds on top. The "5 rebirths" slot is off while pet stats are on.
- Stat labels: every pet card shows one coloured line per stat ("+50% COINS" gold, "+20% PINS" pink, "+30% BAG" blue, "+10% SPEED" green); the slot strip shows PET BOOSTS with all four totals; the hatch card counts the stats up; Shiny, fusion and spin-wheel pet cards show stats too. Locked slots show their coin price.
- The PETS window is open on the roof now (it said "pets come later"). With no pets: "Pets boost your coins, pins, bag and speed. Eggs are coming to the shop" (step B2 adds the eggs).
- TEST panel: new **GIVE PET** button (one pet each press, going down the pet list, with its stats in the message).
- EQUIP BEST counts all stats (Bag x0.6 and Speed x0.8 weight, `Config.PetStats.Types` Best).

| Pet | Rarity | Stats |
|---|---|---|
| Gutter Gus | Common | +10% Coins |
| Pinny | Uncommon | +25% Coins |
| Lane Pup | Uncommon | +15% Bag, +10% Speed |
| Bumper | Uncommon | +30% Bag |
| Strikey | Rare | +50% Pins |
| Splitz | Rare | +30% Coins, +25% Pins |
| Wood Pup | Rare | +60% Bag |
| Hambone | Epic | +100% Coins |
| Neon Bat | Epic | +60% Pins, +25% Speed |
| Chrome Bat | Epic | +50% Coins, +100% Bag |
| Cloud Bumper | Epic | +120% Bag, +20% Speed |
| Kingpin | Legendary | +250% Pins |
| Blaze | Legendary | +150% Coins, +40% Speed |
| Moony | Legendary | +200% Coins, +150% Bag |
| Titan Jr. | Legendary | +200% Pins, +100% Coins |
| Cosmo | Mythic | +600% Coins, +300% Pins |
| Perfecto | Mythic | +500% Pins, +60% Speed |
Shiny = every stat x2.

**Restore tag:** `restore-a5-B1-before`. **Commit:** 3485257. **Save:** v35 adds `PetSlotsBought` (starts at 0); old saves keep every slot they had (`PetSlotsKept` counts as bought).

**2-minute test**
1. Play (TEST panel: START FROM ZERO). Note the bag size on the HUD (60). Open TEST > GIVE PET three times (Pinny, Gus, Lane Pup).
2. Open PETS. Expected: three cards with coloured lines (+25% COINS, +10% COINS, +15% BAG / +10% SPEED); the strip says PET BOOSTS +35% COINS, +0% PINS, +15% BAG, +10% SPEED.
3. Look at the HUD bag: 69 instead of 60. Hold THROW: throws come a bit faster, each pin pays ~35% more.
4. GIVE PET twice more (Bumper, Strikey) and equip them. Expected: about 9 pins a throw instead of 6.
5. TEST > COINS x10, tap BALLS > GO TO SHOP. Expected: a purple PET SLOTS row at the bottom ("Pet slot 4", 2.5K). Buy it: the PETS strip gets one more open slot.
- Silent failures to watch for: bag bar still showing 60 with pets on, cards still saying "x1.25 COINS", the PET SLOTS row overlapping the GO TO SHOP button, the 2x2 totals cut off on a phone, buying a slot away from the shop.

**Checked by numbers** (`screenshots/addendum5/B1/PLAYTEST_LOG.md`): no pets 6 pins / 2.5 coins a pin / 1.0 s / bag 60; +35% Coins +15% Bag +10% Speed -> 3.39 a pin, 0.909 s, bag 69; +50% Pins -> 8.9 pins; +155% Speed -> stops at the 0.4 s floor; EQUIP BEST (+900% Coins, +1250% Pins) -> 82 pins, 25 a pin, 0.625 s, bag 150. Slots bought only at the shop, for the exact prices, the 6th refused. No errors in Output. Studio's 3D view was still frozen: no screenshots, the look is NOT verified.

**Choices made for you**
- Stat sizes by rarity (Common ~+10%, Uncommon ~+25%, Rare ~+50%, Epic ~+100%, Legendary ~+250%, Mythic ~+600%); Speed smaller (max +60%) because the 0.4 s floor caps it at +150% total. All in Config; B2 may re-rate when eggs get their prices.
- "+25% Speed" = 25% more throws (seconds between throws / 1.25), so stacking stays fair near the floor.
- Bag stat makes the bag hold more coins (the bag counts coins, as since Stage 1).
- Slot prices 2.5K / 25K / 150K / 600K / 2.5M (`Config.PetStats.SlotPrices`), max 8 coin slots (+2 with the pass). The old "+1 slot at 5 rebirths" is off while pet stats are on.
- Pins boost is ready for step C: `CoreLoopService.PinsMultiplier` is where the rebirth pins bonus goes; `MascotService.ResetForRebirth` takes bought slots away only if `KeepPetSlots = false`.
- Pet stats only run in the core loop (`Config.PetStats.Enabled`; off = the old coins-only bonus).

**Studio-only edits:** none (scripts pushed into the open Studio; save the place or reconnect Rojo to keep them in the place file).

**Placeholders:** none new (paw icon = the HUD paw image).

## Step 5 (B2): egg ladder, pet inventory, Shiny merge on the roof (2026-11-01)
**What changed**
- **EGG ROW** next to the shop (east of the lanes, facing the shop side): four egg stands in a price ladder, bought with coins only. A hatch only works standing at that egg's own stand (the server checks the distance). Each egg has its own pets and its own odds, so a pricier egg hatches rarer pets:

| Egg | Price | Stand (copy of) | Pets and odds |
|---|---|---|---|
| Neon Egg | 400 | lobby Neon stand | Gus 50% (Common), Pinny / Bumper / Lane Pup 15% each, Strikey 5% (Rare) |
| Main Street Egg | 6.5K | zone 3 stand | Splitz / Wood Pup 42.5% each (Rare), Hambone / Neon Bat 7.5% each (Epic) |
| Skyline Egg | 80K | the roof's own Skyline stand | Chrome Bat / Cloud Bumper 44% each (Epic), Kingpin / Moony 6% each (Legendary) |
| Volcano Egg | 1.5M | Neon stand + Neon Egg re-coloured orange/red | Blaze / Titan Jr. 46% each (Legendary), Cosmo / Perfecto 4% each (Mythic) |

- The stands are built from code when the server starts (copies; the originals stay where they are). Each keeps the full egg juice: odds bubbles over the egg (tap a pet to auto-delete it, as before), price over the stand, hold E to hatch, the full hatch scene, AUTO and triple hatch.
- **Pet re-rating** (stats rise with each egg, Shiny still x2): Gus +10% Coins, Pinny +20% Coins, Bumper +30% Bag, Lane Pup +15% Bag +10% Speed, Strikey +40% Pins; Splitz +35% Coins +25% Pins, Wood Pup +60% Bag +15% Coins, Hambone +100% Coins, Neon Bat +60% Pins +25% Speed; Chrome Bat +120% Coins +100% Bag, Cloud Bumper +80% Pins +150% Bag, Kingpin +250% Pins, Moony +250% Coins +200% Bag; Blaze +400% Coins +40% Speed, Titan Jr. +400% Pins +150% Coins, Cosmo +1200% Coins +600% Pins, Perfecto +1000% Pins +60% Speed.
- **Shiny merge on the roof:** a copy of the PET FUSION machine stands at the end of the egg row (open to everyone, no zone). 3 copies -> 1 Shiny with double stats, same fusion window and animation as before. (I chose the machine over a merge button in the inventory: it reuses the finished fusion window and makes a place to go.)
- **PETS window:** strongest pets first; Mythic cards have a turning rainbow frame and Shiny cards a turning gold frame; coloured stat lines (from B1); BEST ONES OUT is now **EQUIP BEST**; a gold **FUSE!** badge on any pet you have 3+ of (tap = where to fuse); with no pets a pink **GO TO EGGS** button teleports you to the Neon Egg. Red dot on PETS when you can buy your first egg or have 3 copies to fuse.
- **First egg prompt** works on the roof: once you have 400 coins, BUY YOUR FIRST PET EGG! with a gold beam and GO HERE! over the Neon Egg (once ever).
- Signs PET EGGS and FUSION float over the row and the machine. Two lounges moved behind the row, one in front facing the eggs.
- LUCKY passes now help every egg (before, eggs 2-4 had no luck at all because luck started at Rare).
- TEST panel FREE EGG gives a free hatch of the next roof egg each press.

**Restore tag:** `restore-a5-B2-before`. **Commit:** 3d57f7b. **Save:** no new fields.

**Prices (EconomySim.CoreEggs, a player buying the cheapest next thing, one of each egg):** Neon Egg at ~2 min, Main Street ~11 min, Skyline ~23 min, Volcano ~31 min. The pets pull ball 10 in from ~31 to ~26 min, which leaves room for extra hatches (Shinies need 3) and for step C's rebirth.

**2-minute test**
1. Play (TEST: START FROM ZERO). Throw and sell until you have 400 coins. Expected: BUY YOUR FIRST PET EGG! popup and a gold beam to the Neon Egg on the egg row east of the lanes.
2. Walk to the Neon Egg. Expected: odds bubbles with 5 pets, "400 COINS". Hold E. Expected: the hatch scene, the pet card with its stats, the pet follows you.
3. Open PETS. Expected: the pet card with its coloured stat line, PET BOOSTS totals; the HUD bag size / throw speed change by the stated %.
4. TEST > COINS a few times, buy the other three eggs at their stands. Expected: prices 6.5K / 80K / 1.5M, rarer pets; EQUIP BEST puts the strongest out.
5. Hatch Neon Eggs until a pet shows FUSE!. Walk to the FUSION machine at the end of the row, use it. Expected: one Shiny with double stats.
- Silent failures to watch for: a stand floating or sunk into the roof, a stand facing the wrong way, odds bubbles missing on one egg, the Volcano Egg showing as a plain ball instead of the orange Neon Egg, "Hatch it at the egg stand" while standing at it, the fusion prompt missing, cards without stat lines, FUSE! covering the pet badly on a phone.

**Checked** (`screenshots/addendum5/B2/PLAYTEST_LOG.md`, screenshots 1-6): hatch refused away from the stand; exact prices taken; coins per pin x1.2 / bag 60 -> 87 / 1.0 s -> 0.91 s with +20% Coins +45% Bag +10% Speed; with EQUIP BEST (+2500% Coins, +600% Pins, +400% Bag, +80% Speed) 65 coins a pin (2.5 x 26), pins x7, bag 300, 0.556 s; merge refused at the eggs, works at the roof machine; GO TO EGGS; first-egg prompt; no errors. Studio's 3D view worked again for this step, so the row, odds boards, PETS window and hatch were looked at on screen.

**Choices made for you**
- 4th egg = Volcano Egg (its name and colours were already in Config): the Neon stand and Neon Egg re-coloured, no new art.
- Pools don't overlap (17 pets over 4 eggs). Titan Jr. (boss drop, boss is off on the roof) now comes from the Volcano Egg; Gus and Bumper (cut from the old Neon Egg) are back in the Neon Egg.
- Each egg rolls its own rarity odds (pets of one rarity share it), like before; luck boosts every rarity but the egg's commonest.
- Merge = the fusion machine copy (not an inventory button).
- Egg row placed east of the lanes beside the shop (x 26..90, z -3438); stands turned so their signs face the shop side. Main Street's price label sits a little over its sign text (same as in zone 3).
- Old zone eggs and their stands are untouched (`Config.CoreLoop.Eggs.Enabled = false` brings the zone eggs and gates back).

**Studio-only edits:** none (scripts pushed into the open Studio; save the place or reconnect Rojo to keep them in the place file).

**Placeholders:** none new.

## Step 6 (C): rebirth (2026-11-01)
**What changed**
- **REBIRTH is bought at the ball shop, with coins only.** Rebirth 1 costs 10M coins, each next one x3 (30M, 90M...). A big gold **REBIRTH** button sits on the left of the HUD (where POWER LV was) with "x1 › x2" and a bar that fills with your coins; it glows with a red dot when you can afford it.
- Tap it: a window shows **YOU GO BACK TO** (ball 1, bag 1, 0 coins), **YOU KEEP** (all pets, equipped pets, Shiny pets, pet slots, rebirths) and **YOU GET FOREVER** ("x1 › x2" on coins and pins, plus the new tier colour), and the price. Away from the shop the big button says **GO TO SHOP** and takes you there; at the shop it says **REBIRTH!**, and you tap twice (the second tap within 3 seconds) so nobody rebirths by accident. Then a full-screen **REBIRTH!** moment with confetti and x2 COINS / x2 PINS / BRONZE TIER.
- **What a rebirth does:** coins, bag, bag size, ball ladder and throw speed go back to the start (ball 1, bag 1). Pets and pet slots stay. Forever after: **x2 pins every throw and x2 coins on every sell** after rebirth 1, x3 after rebirth 2, x4 after 3 ...
- **The ladders cost more after each rebirth** (x3 after rebirth 1), so the run feels like a fresh climb but faster. Simulator: the first run reaches ball 10 in ~33 min, then saves 6 min for the 10M; after rebirth 1 the player is back at the old top income in ~5.6 min (17% of the first run's time, the goal was about 1/4) and then goes past it (1.6M/min -> 4.2M/min). Rebirths 2/3/4/5 at about 53/74/109/180 min. A player who never rebirths stays at ~1.6M/min.
- **Tier colours** (cheap, from what exists): Bronze (rebirth 1), Silver (2), Gold (3), Emerald (5), Diamond (8), Ruby (12), Cosmic (20). Your tier colours the "★ REBIRTH n" tag over your head (everyone sees it), your throw spot's ring and the band on your pins.
- **MOST REBIRTHS** leaderboard on the roof board (it takes the old BEST STREAK slot; streaks don't exist in the core loop).
- The sold pop shows a gold "x2 REBIRTH" tag; the goal bar points to REBIRTH once the ladders are done; TEST > READY TO REBIRTH gives exactly the coins for the next rebirth.

**Restore tag:** `restore-a5-C-before`. **Commit:** 6c9dd04. **Save:** no new fields (Rebirths already existed).

**2-minute test**
1. Play (TEST: START FROM ZERO). Throw 5 times and look at the pins number (about 6). Sell once and note bag -> coins (same number).
2. TEST > READY TO REBIRTH. Expected: the gold REBIRTH! button glows with a red dot.
3. Tap it on the lane. Expected: the window with GO TO SHOP. Tap GO TO SHOP. Expected: you land on the shop circle, the window stays on top and the button turns gold REBIRTH!. Tap it twice. Expected: the REBIRTH! moment, coins 0, bag 0/60, ball 1, your pets still out, "★ REBIRTH 1" in bronze over your head.
4. Throw 5 times. Expected: about 12 pins a throw (x2), the bag fills twice as fast, a sell pays double what the bag shows with a gold "x2 REBIRTH" tag. The shop's ball 2 costs 150 (was 50), the button now says "x2 › x3".
- Silent failures to watch for: rebirth working away from the shop, pets or bought pet slots gone after a rebirth, the shop window opening over the rebirth window, the price line hidden behind the buttons, pins or sell not doubled, the old prices after a rebirth, no head tag, pins still with gold bands (they should be bronze), MOST REBIRTHS board empty after you rebirthed.

**Checked** (`screenshots/addendum5/C/PLAYTEST_LOG.md`, screenshots 1-5): refused away from the shop; GO TO SHOP teleports; tap twice works; after rebirth coins/bag/BagLevel/BallStep/ball reset, pets + bought slot kept; real throws 6.08 -> 12.25 pins a throw; a 60-coin bag sold for 60 before and 120 after; ladder prices x3.03; head tag, ring and pin bands Bronze; MOST REBIRTHS shows 1; no errors. Fixed during the test: the shop popped open over the rebirth window, the price line overlapped the buttons, the pin colour missed the roof pins (they have a "Band", not rings), the phone button's "x1 › x2" sat on its bar. The 3D view did not draw in Play captures this session, so the colours were checked by their numbers, not by eye.

**Choices made for you**
- The rebirth multiplier is paid on the **sell** (bag coins x2), not per pin, so the bag still fills at the same speed per coin and the HUD bag numbers stay simple. Pins per throw are x2 as well, so the bag does fill faster.
- Ladder prices rise x (rebirth multiplier)^1.6 (x3 after rebirth 1, x5.8 after 2): that's what made "recover in about a quarter of the time, then pass it" come out in the simulator. `Config.CoreLoop.Rebirth.LadderPower` (0 = old prices).
- MOST REBIRTHS took the BEST STREAK board slot (no new board model).
- Tiers at rebirths 1/2/3/5/8/12/20, colours only (no new art).
- Gift coins (daily / playtime gifts) don't grow with rebirth prices; they stay a small help. Worth a look in step E.
- Throw speed still has no shop item; it resets anyway.

**Studio-only edits:** none (scripts pushed into the open Studio; save the place or reconnect Rojo to keep them in the place file).

**Placeholders:** none new.

## Step 7 (D): ball effects (2026-11-01)
**What changed**
- Every ladder ball now has its own effect when it hits your pins. It's all built from the game's own images, particles and sounds (no new art), and it only changes how a throw looks and feels. No numbers change.

| Ball | Effect |
|---|---|
| 1 Beach Roller | kicks up sand dust as it rolls, sand puff + small ring on the hit |
| 2 Rubber Bouncer | hops down the lane (3 bounces, lower each time), bubble-gum pop + pink ring + a "boing" |
| 3 Confetti Popper | sprinkles confetti as it rolls, confetti cannon over the pins with a pop |
| 4 Sunspike | rolls on fire, a burst of flames and embers, the pins it hits burn for a moment |
| 5 Gust | trails snowflakes, an icy gust blows the pins sideways (they fly sideways too), frost ring |
| 6 Cloud Roll | two cloud "magic arms" reach out of the ball and wrap round both sides of the rack |
| 7 Rainbow Arc | six rainbow rings ripple out, crystal shards fly, a rainbow arcs over the rack, pins burst outward |
| 8 Sunbolt | lightning jumps from the ball to a pin, then pin to pin (3 to 12 jumps), a yellow flash on big ones |
| 9 Tornado | a gold twister spins up out of the rack and lifts the pins, gold dust rises |
| 10 Sonic Boom | sonic rings peel off the ball as it rolls; at the pins a black hole opens, sucks in stars, then bursts in a white sonic boom (screen flash, big shake, pins blown outward) |

- **Bigger throws look bigger.** The effect grows with the real pin count of the throw (not the 40 drawn pins): more particles, bigger rings, flashes and fire, more lightning jumps, stronger camera shake, a louder crash (strong balls play the big strike crash), a bigger coin pop over the pins, and a harder punch on the HUD pin counter. Strength: 6 pins = 0, 650 pins (ball 8) = 0.39, 3.2K (ball 10) = 0.52, 30K = 0.71, 1M and up = full. So the same ball keeps getting louder as pets and rebirths push the count up.
- The heavy bits (screen flash, black hole, confetti cannon, rainbow arc) play at most once every 1.2 s (LUCKY throws after 0.6 s), so holding THROW never turns into a strobe. The other throws still show the lighter version.
- Settings: EFFECTS off = none of the visuals (sounds stay); SCREEN SHAKE off = no shake; other players' balls stay plain balls as before (the effects only play on your own throws).

**Restore tag:** `restore-a5-D-before`. **Commit:** 5845187. **Save:** no new fields.

**2-minute test**
1. Play. Hold THROW on your spot with ball 1. Expected: a sand puff on each hit, the counter punches a little.
2. TEST > COINS a few times, go to the shop and buy balls 2, 3, 4 one by one, throwing a few times with each. Expected: ball 2 bounces down the lane with a pink pop, ball 3 throws confetti, ball 4 rolls on fire and the pins flame.
3. TEST > COINS until you can buy up to ball 10, try each. Expected: frost gust (pins fly sideways), cloud arms, rainbow rings + arc, lightning between pins, gold twister, black hole then a white boom with a screen flash.
4. With ball 10, TEST > GIVE PET a few times + EQUIP BEST (more pins). Expected: the boom, shake and crash get visibly bigger.
5. SETTINGS: EFFECTS off and throw. Expected: no effects (ball, pins, numbers and sounds stay). SCREEN SHAKE off: no shake.
- Silent failures to watch for: effects floating off the rack (to one side or under the floor), the cloud arms or rainbow arc going the wrong way, Rubber Bouncer sinking into the lane, the black hole staying black on screen, the screen flash too strong, frame drops while holding THROW with ball 10.

**Checked by numbers** (`screenshots/addendum5/D/PLAYTEST_LOG.md`): every ball's effect fired (parts, emitters, beams, fire, the bounce height counted per throw), more pieces at 1M pins than at 3.2K, nothing with EFFECTS off, real throws work, a 1M-pin Sonic Boom every 0.4 s for 8 s peaks at 26 effect holders and cleans up to 0. No errors. **Not checked by eye:** Studio's Play captures drew only the HUD again (3D white), so how the effects LOOK (sizes, colours, directions) is unverified. Please look at step 3 first.

**Choices made for you**
- Effect names follow the old Addendum 4 Stage 4 ball names where they fit (bouncer, confetti, gust, rainbow, bolt, tornado, sonic boom), plus the addendum's examples: Sunspike = burning, Cloud Roll = magic arms, Sonic Boom = black hole + explosion. Lightning stays on Sunbolt.
- Strength is a log scale from 6 pins (0) to 1M pins (1): `Config.CoreLoop.BallEffects` From/Full. Each effect's shake, pin force and knock direction are in `BallEffects.Effects`; `Fx` on each ball row picks the effect.
- The pins really fly differently per ball (sideways for Gust, outward for Rainbow Arc / Sonic Boom, harder for later balls); the count is untouched. Sonic Boom holds the pins 0.2 s while the black hole pulls, then they blow out.
- Other players' throws: unchanged plain balls (cheapest, and the A3 rule). The old non-shared-lane mode also shows signatures only for your own throws.
- Sounds reused: Tap (boing), Firework (pop), Teleport (gust whoosh), Reveal (rainbow), OverchargeWarn (crackle), PowerUp (twister), OverchargeBlast (boom). They may need swapping by ear.
- Left as is: the balls' existing trails/halos (BallFx) are unchanged; balls 1-3 still have no BallVfx row of their own (plain trail + the new effect).

**Studio-only edits:** a new ModuleScript `StarterPlayer.StarterPlayerScripts.Client.Modules.BallSignature` was created in the open Studio (same as the repo file). Save the place or reconnect Rojo to keep it.

**Placeholders:** none new (all existing images and sounds).

## Step 8 (E): pacing + logging (2026-11-01)
**What changed**
- **Pacing record for every player** (new server module `Modules/Pacing`, `Config.Pacing`). Per run (from the start or
  a rebirth to the next rebirth) it notes when each ball, bag, pet slot and egg was first bought (minutes of play into
  the run), when the rebirth came, and the income (coins a minute over the last 3 minutes): the top of the run, 5
  minutes in, just before the rebirth, and when the next run got back to it.
- **Where to read it:** the Output prints the whole record when a player leaves, plus one line per buy as it happens;
  the Studio TEST panel has a new **PACING** button (EVENTS row) that prints it any time; it is saved with the player
  (newest 8 runs, save v36, nothing old touched); Analytics gets a `Pacing` event, a `PacingIncome` event and a **Run**
  funnel (start, balls 2-10, rebirth) for the Creator Dashboard.
- **Simulator:** `EconomySim.CorePacing()` plays the whole new loop (two ladders, slots, eggs, 4-stat pets, EQUIP BEST,
  Shiny merges, bag cap, rebirth multiplier on pins and sells, ladder power) for a rebirther and a never-rebirther.
- **PACING_REPORT.md**: the full table and every finding. Short version of the Config fixes:
  - balls 6-10 and bags 6-10 re-priced (pets had made balls 7-10 come 2.4-4.3 min apart; now ~5 min, ball 10 at ~30 min)
  - rebirth prices 10M, 25M, 60M, 120M, 220M, 380M then x1.5 (x3 made rebirth 5 a 2-hour save, rebirth 7 a 13-hour one)
  - EQUIP BEST counts the Bag stat 8 instead of 0.6 (it was swapping bag pets out and halving income)
  - PIN CRUSHER goals 10K / 1M / 10M / 100M (the old 1K-500K went in 30 minutes)
- Result: rebirths at ~44 min, 55 min, 1h11, 1h30, 1h55, 2h29; each rebirth gets back to the last top income in
  15-40% of the first run's time and passes it; a never-rebirther stays at 1.3-3.2M a minute while a rebirther is at
  6.6M after an hour and 23M after three.

**Restore tag:** `restore-a5-E-before`. **Commit:** 588d568. **Save:** v36 adds `Pacing` (starts empty).

**2-minute test**
1. Play (TEST: START FROM ZERO). Throw, sell, buy ball 2 at the shop. Expected in Output: `[Pacing] <you>: Ball2 at 0:xx into run 0`.
2. Buy a bag and hatch the Neon Egg. Expected: `Bag2 at ...` and `Egg_Alley at ...` lines.
3. TEST > PACING. Expected: a block with run 0, balls / bags / eggs / slots with times, "income a minute: top ...".
4. TEST > READY TO REBIRTH, rebirth at the shop, buy ball 2 again, press PACING. Expected: run 0 now says "rebirth 1
   after ...", a new run 1 with its own times; the shop's ball 6 costs 16K (5.3K x3) and REBIRTH shows 25M next.
5. Stop. Expected: the same PACING block prints once more as you leave.
- Silent failures to watch for: no `[Pacing]` lines at all (module not in the place: save the place / reconnect Rojo),
  times not restarting after a rebirth, the same ball printed twice in one run, a `[Analytics] 'Pacing' is not in
  Config.Analytics.Events` warning.

**Checked by numbers** (`screenshots/addendum5/E/PLAYTEST_LOG.md`): buys, rebirth, sells (income 397K a minute after 4
x 100K sells), hatch all logged in the right run; PACING prints; analytics calls fire; no errors. One fix during the
test (a run with no sells no longer counts as "got back to its income"). The Lua simulator and its Python twin agree.

**Choices made for you**
- Times are minutes of **play** (all sessions added up), not clock time, so a run spread over days still reads right.
- Income = coins sold in the last 3 minutes (`Config.Pacing.IncomeWindow`), so it is what the player really earned.
- Rebirth price growth eased from x3 to the list above (the addendum's "roughly 3x" holds for rebirth 1 to 2 only):
  with the bag cap, income can't keep up with x3. `LadderPower` stays 1.6 (gives ~1/4 recovery best).
- Bag weight 8 in EQUIP BEST: a stopgap. A real fix (EQUIP BEST by actual income) is code, left for you / step F.
- Not changed, needs code or your call (details in PACING_REPORT.md): gift coins are tiny next to rebirth prices; eggs
  get cheap after rebirth 2 (no 5th egg); from rebirth 1 the bag is the real cap on income.

**Studio-only edits:** new ModuleScript `ServerScriptService.Server.Modules.Pacing` created in the open Studio (same as
the repo file); all changed scripts pushed into Studio. Save the place or reconnect Rojo to keep them.

**Placeholders:** none.
