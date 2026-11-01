# Step F playtest log (2026-11-01, Studio Play, START FROM ZERO)

Studio was running hidden again: viewport 1x1, no rendered frames (RenderStepped and tweens frozen), screen_capture
timed out in Play and in Edit. So the join loading screen never finished and the HUD stayed behind it; everything
below was checked by numbers through the remotes and the client's own GUI objects. No screenshots.

## Full loop from zero (run 1, before the fixes)
- 14 throws on the shared lane spot 6: 5-7 pins each, bag 60/60.
- SELL (CoreGoTo "Sell"): teleported onto the sell pad, bag 0, coins 60.
- Buy away from the shop: "Buy it at the shop". TEST > COINS, GO TO SHOP: ball 2 (Rubber Bouncer), bag 2 (140), pet
  slot 4 all bought there.
- Eggs: CoreGoTo "Eggs" lands at the Neon Egg; hatch x3 (Studio gives the triple pass) Pinny, Lane Pup, Pinny; 3 more
  hatches; pets auto-equip; stats attribute moves (Coins 0.4, Bag 0.15, Speed 0.1).
- Merge refused at the eggs ("Fuse pets at the PET FUSION machine"), works at the roof machine: 3 Lane Pup -> 1 Lane
  Pup Shiny.
- TEST > READY TO REBIRTH (10M), rebirth at the shop: coins 0, ball 1, bag 1, rebirths 1, pins x2, pets + 6 slots
  kept. 6 throws after: 10-13 pins (was 5-7).
- Output: no errors. Old warnings: SkylineLanes.CrateShop.Counter / EggPad / CrateShop not found.

## Clashes found and fixed
1. EQUIP BEST put out 4 Bumpers (+30% bag each) and left Strikey and Pinny in the box (step E's Bag weight 8). Now it
   ranks by the coins a minute each set really earns (Mascots.Income). Re-test: ball 1 / bag 1 -> Hambone first
   (+100% coins); ball 7 / bag 1 (bag fills in one throw) -> the bag pets Bumper and Lane Pup first.
2. Gift coins (daily, playtime gifts, milestones, the coin store pack) didn't grow after a rebirth while every shop
   price went x3. Now they grow with the same price factor: a 5-minute gift at ball 1 = 1.1K / 3.4K / 6.5K / 10K at
   rebirth 0 / 1 / 2 / 3 (ball 2 costs 50 / 150 / 290 / 460).
3. "YOU CAN NOW AFFORD" notes on the roof talked about crates and Power Levels (both gone) and never about the shop.
   Now: next ball, next bag, next pet slot (all "AT THE SHOP"), the roof eggs and the rebirth.
4. PROFILE > BOOSTS listed ZONE x64, POWER LV, BALL, RANK, STREAK (none pay on the roof) and multiplied them into the
   total; REBIRTHS showed x1 after a rebirth. Now: PETS, COIN POTION, REBIRTHS (the real sell bonus), FRIENDS, GAME
   PASSES, COIN BOOST. The COIN BOOSTS button (old multiplier card) is hidden on the roof; the note says where the
   other pet stats are. Re-test: rows = Mascots, Potion, Rebirth, Friends, Passes, RobuxBoost.
5. The two "not found" warnings: the roof's hidden crate kiosk/egg pad rows are dropped from Config.AreaSigns and
   Config.ZoneShops in the core loop. Re-test: Output clean.

## Polish added (checked by numbers)
- Each throw: a "+87" gold/white number spawns under the pin counter and flies into the bag icon (seen: "+87" made
  at the counter; the flight itself only runs with frames).
- SELL: coins fly from the sold pop into the coin counter (3 + 2 per x10 coins, max 14).
- Full bag shakes (rotation wobble every frame while full).
- BALLS button red dot while the shop has a ball, bag or pet slot you can pay for (seen: Dot visible at 969K coins).
