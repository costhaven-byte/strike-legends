# Step C (rebirth) playtest log (2026-11-01, Studio Play)

Studio had been restarted by the owner (it froze on a heavy EconomySim run). All 22 scripts that differed from git
were pushed with the http trick (python http.server 35991 + ScriptEditorService:UpdateSourceAsync): this step's 18
files plus 4 that only differed in comments/formatting (CrateKitAssets, ZoneShopController, CrateKit, SunKit). The
earlier steps A1-B2 were already in the place. Start mode: Studio fresh player. Studio gives the test passes free
(x2.5 coins, triple hatch, +2 pet slots), which shows in the coin numbers below.

## Before rebirth (real throws, ball 1, no pets)
- 12 throws: 6.08 pins a throw on average, 2.53 coins a pin, bag 60 full. Sell: CoreSold(60, 1), coins 0 -> 60.
- Ladder prices at rebirth 0 / 1 (CoreLadder.BallPrice / BagPrice): ball 2 50/150, ball 3 500/1.5K, ball 4 950/2.9K,
  ball 5 1.9K/5.8K, ball 6 10K/30K, ball 7 21K/64K, ball 8 45K/140K, ball 9 99K/300K, ball 10 220K/670K;
  bag 2 240/730, bag 3 600/1.8K, bag 4 990/3K, bag 5 5.2K/16K, bag 6 11K/33K (x3.03 = 2^1.6).
- Set up for the reset check: 2 pets (Pinny, Gus), ball 4, bag 3, 1 pet slot bought (MascotSlots 6).

## Rebirth
- TEST > READY TO REBIRTH: coins 10M. Rebirth remote away from the shop: "Rebirth at the ball shop".
- Gold REBIRTH! button glows with a red dot (1). Window away from the shop: GO TO SHOP + "AT THE BALL SHOP" (2).
- GO TO SHOP teleports onto the shop circle. BUG FOUND: the shop window popped open over the rebirth window. FIXED:
  the shop doesn't auto-open while the rebirth window is open (RebirthWindowUI attribute Open).
- BUG FOUND: the PRICE line was half under the buttons. FIXED: window 20 px taller (PRICE ends y 466, buttons y 478).
- At the shop: REBIRTH! (3), first tap TAP AGAIN TO REBIRTH (4), second tap within 3 s -> REBIRTH! moment with
  x2 COINS / x2 PINS / BRONZE TIER chips (5). (A 2nd tap after 3 s only asks again, as designed.)
- After: Coins 0, Bag 0, BagLevel 1, BallStep 1, EquippedBall Tangerine (ball 1), Rebirths 1, RebirthMultiplier 2,
  PinsMultiplier 2, BagSize 60; pets Gus + Pinny still equipped, PetSlotsBought 1, MascotSlots 6 kept.
  ThrowSpeedLevel resets to 0 in CoreLoopService.ResetForRebirth (read in code; no shop item sells it today).
- HUD after: button "x2 › x3", goal "Next: Rubber Bouncer 0/150" (x3 price), AUTO shows FREE! (free slow auto
  after rebirth 1, old Config rule).

## After rebirth (real throws)
- 8 throws: 12.25 pins a throw (x2 of 6.08). A 60-coin bag sold for 120: CoreSold(120, 2).

## Looks (checked by numbers: the 3D view did not draw in Play captures this session)
- Head tag "★ REBIRTH 1" in Bronze (222, 140, 70).
- Own throw spot Ring: Bronze, Neon; a free spot keeps its blue SmoothPlastic.
- BUG FOUND: pins kept their gold band (the tint looked for RingTop/RingBottom/Neck; the roof pins are Body + Band).
  FIXED: "Band" added; a new rack's bands come out Bronze (222, 140, 70) after rebirth 1.
- Leaderboard: MOST REBIRTHS panel (old Streak slot) shows the player with 1.
- Phone layout (Config.Ui.CompactHeight = 5000 in Studio only, restored after): BUG FOUND: the "x1 › x2" line sat on
  the coins bar. FIXED: phone button 52 tall (text ends y 35, bar y 37), PC spacing tightened by 3 px. Window on
  the phone: PRICE line fits, no overlap. (Mouse + capture tools timed out late in the session, so the phone moment
  was not captured.)

## Output
No errors. Old notes only (CrateShop.Counter / EggPad / CrateShop not found, an old asset id type warning).
