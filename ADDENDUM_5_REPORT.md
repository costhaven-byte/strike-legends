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
