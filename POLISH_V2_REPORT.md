# Polish v2 report (run started 2026-11-03)

Restore point for the whole run: git tag `restore-polish-v2-before` (+ owner's File > Save to Roblox As copy).
Each stage has its own tag `restore-pl-<stage>-before`.

Budget note: the run started with the weekly usage at 87%, so the stages are done in the plan's "must finish
first" order where they're small and sure, and a handoff note (POLISH_V2_HANDOFF.md) is kept up to date after
every stage for the next account.

## L0 zone 4 models
Already done before this run (ffe84c0).

## U1 HUD: no SHOP button, passes only in the STORE (tag restore-pl-U1-before)
- SHOP (balls + bags) button hidden on computer and phone (`Config.Ui.ShopButton = false`; true brings it back).
- The left button grid closes up: PETS, STORE / DAILY, PROFILE / PASSES, TELEPORT (TELEPORT last, because it stays
  hidden until zone 2). GIFTS + SETTINGS slide into the top-right corner.
- NEXT GOAL card is now a button: tap it = go to the BALLS & BAGS stall (same teleport as GO TO SHOP).
- SHOP window has 3 tabs: BALLS / BAGS / REBIRTH (`Config.CoreLoop.Shop.Tabs`, "Gamepasses" removed).
- PASSES button opens the STORE scrolled to GAME PASSES (`StoreController.OpenOn`).
- The world beams (shop/sell pointers) still guide new players to the stalls.
- Decision (owner can reverse): "remove shop" read as the SHOP button, not STORE. PASSES button kept, moved into the grid.
- Placeholders: STORE still in the older Store Kit look (U2 restyles it).

## TUT Tutorial (owner's extra ask mid-run, 2026-11-03; tag restore-pl-TUT-before)
"A really concise tutorial, more show not tell, reward the player with each step."
- 4 steps, in order: THROW (+20 coins) > SELL (+30 coins) > NEW BALL (+120 coins) > UPGRADE = one more ball or bag
  (FREE Rooftop Egg). Numbers in `Config.Tutorial` (Enabled = false turns it off).
- Show, not tell: a row of 4 reward tiles top-centre shows what each step pays (current one bobs with a gold rim,
  done = green tick). A hand presses the thing to press (press-and-hold on THROW, tap on SELL, tap on the NEXT GOAL
  card; inside the shop it moves onto BUY BEST) with one word over it (HOLD / SELL / NEW BALL / UPGRADE).
- Each step done: the tile pops, the reward rises off it (+20, FREE EGG!) with a sound; after the last step the strip
  slides away. Hidden in cut-scenes and while other windows are open.
- Server pays (TutorialService watches the saved throws/sells/ball/bag); new save field `Tutorial`, SchemaVersion 39.
  Old saves that already sold, bought or rebirthed count as done (no rewards). Analytics event TutorialStep.
- Self-test (Studio, fresh player): all 4 steps paid (coins 20 > 63 after sell > +120 after ball 2; step 4 gave the
  free egg). Not checked: phone size, the egg tile's 3D egg (viewports don't show in play captures).
- Found while testing (for T1): a second BUY BEST tap (10K coins, "+140 5.3K") bought nothing; the buy remote
  itself works. Needs a look in the bug hunt.

## U3 part 1: pets you haven't found are black (tag restore-pl-U3-before)
- New save field `PetsFound` (every pet ever hatched or given; kept after fusing or auto-delete), SchemaVersion 40.
  Old saves: filled from the pets they own (a Shiny counts its plain pet too).
- Every egg board: pets never found = black silhouette, chance still shown (honest odds); the rarest unfound pet on
  each board shows "???". Getting a pet turns it back to colour with a pop.
- The hatch card's NEW! now means "never found before" (was "none owned right now").
- Self-test: fresh player = all 18 board pets black, ??? on Sunspot / Surf Otter / Temple Monkey / Scarab; test
  pet Pinch -> Pinny's tile turned coloured. Not seen on screen (Studio's 3D view wasn't drawing in captures).
- NOT DONE (U3 part 2, for the next account): the reference layout (3-across square tiles with rarity name, price
  pill, round AUTO-DELETE / AUTO (T) / OPEN 3 (R) / OPEN 1 (E) buttons, buff lines). Needs the owner's reference
  picture; the current V6 board layout stays.

## Q2 words (quick pass, live scan only)
- Scanned every text players can see in a live game (HUD, windows, world signs). No old names (Neon Egg, Main
  Street, Back Alley, Rizzo, crates) anywhere a player can reach: all hits are in the old lobby areas (Hub,
  MainStreetLanes, NeonAlley, BackAlley, old spin wheel) ~3,500 studs from zone 1, plus old hidden panels.
- Old strings still in code (not shown in the core loop): MascotController "HATCH THE NEON EGG...", BossController
  "GO TO THE SKYLINE HELIPAD", Config.ZoneUnlock / Config.Economy.Zones old zone names. Not changed.
- Not done: zones 2-4 signs read on site, number formats, phone cut-offs.

## Q3 speed (measured, nothing changed yet)
- In a live game the client holds 17,422 parts and 71 particle emitters; 60 fps and ~3.2 GB Studio memory on this PC.
- StreamingEnabled is OFF, so every player loads all 4 zones at once: Jungle Falls 3,627 parts, Skyline Rooftop
  3,095, Sunset Boardwalk 2,495, Canyon Oasis 2,360.
- About 5,500 parts (a third) are the OLD loop's areas nobody can reach any more: MainStreetLanes 1,823, BackAlley
  1,799, NeonAlley 1,190, Hub 477, Showcase 371. Moving them out of Workspace (to ServerStorage, not deleting) is
  the biggest easy win, but some old services still look for them (spin wheel, Rizzo, showcase, leaderboard walls),
  so it needs a careful pass + test. Second win: StreamingEnabled or hiding the zones you're not in on the client.
- ~1,900 small parts (under 3 studs) cast shadows; turning CastShadow off on small decor is a cheap phone win.

## U2 STORE in the V2 look (tag restore-pl-U2-before)
- `Config.Ui.StoreV2 = true`: the STORE window uses the SHOP's look: navy window + tiles, ink outlines, SlKit paints
  (green / gold / pink / red / blue), Fredoka One everywhere, flat cards (the fading colour tint and dot fades are
  off; only the faint icon watermark stays). Same layout, tabs (BOOSTS / PASSES / LOOKS / GEMS), cards, prices,
  OWNED / NO ID YET states and buy prompts; still behind `MonetizationEnabled`.
- All passes live here (U1 took them out of the SHOP); the HUD PASSES button opens it on GAME PASSES.
- Daylight text-darkening is skipped for the STORE (its text is white on navy now).
- The tutorial hides while the STORE or PETS window is open.
- Decision: a re-skin of the working STORE, not a rebuild with SlKit blocks (cheaper and keeps every buy path).
  StoreV2 = false brings the cream look back. Not checked: phone size.

## U3 part 1b: two pieces of the reference board
- Each pet on the egg boards now shows its rarity name under its chance, in the rarity colour (COMMON / RARE ...).
- AUTO-DELETE gear (blue, left of the note line): tapping pets marks them X only while the gear is on (red); off =
  taps do nothing (no accidental deletes). Note line says GEAR = AUTO-DELETE / TAP PETS TO AUTO-DELETE THEM.
- Self-test: all 4 boards build with the gear + rarity names, no errors. Tapping on a board not tried (Studio 3D view
  not drawing); in the owner playtest.
- Still left from the reference (U3 part 2): 3-across square tile grid, price pill beside the card, round
  T AUTO / R OPEN 3 / E OPEN 1 buttons with key letters, buff lines above (2X LUCK...). Reference picture:
  Documents/Strike Legends Assets/refforpethatch.png.

## Console notes for T1 (seen on every join)
- "rbxassetid://203785492 failed due to: Asset type does not match requested type" x4.
- "[ShowcaseController] zone 4: 10 balls to show but only 6 slots".

## Owner playtest for what's done so far (about 5 minutes)
Before: File > Save to Roblox As a copy (restore = git tag `restore-polish-v2-before`). TEST panel: START FROM ZERO.
1. HUD (computer): no SHOP button. Left grid = PETS, STORE / DAILY, PROFILE / PASSES (+ TELEPORT once zone 2 opens).
   GIFTS + SETTINGS top-right. Silent failure: a gap in the grid, or PASSES missing.
2. Tutorial: a row of 4 reward tiles under PINS DOWN (+20, +30, +120, egg). A hand presses THROW with HOLD over it.
   Throw once: the first tile turns green with a tick, +20 rises off it, coins go up by 20.
3. Hand moves to SELL: tap it, +30. Hand moves to the NEXT GOAL card: tap it = you land at the shop, shop opens, the
   hand sits on BUY BEST with NEW BALL: buy, +120. Buy one more thing (ball or bag): FREE EGG!, the strip slides away.
   Silent failures: the hand covering a window (it should hide while STORE / PETS are open), rewards paid twice.
4. SHOP: only BALLS / BAGS / REBIRTH tabs.
5. PASSES button: STORE opens scrolled to GAME PASSES. STORE is navy like the SHOP (no cream, no fading tints).
6. Walk to the Rooftop Egg: every pet on the board is black, the rarest says ???, each pet shows its rarity name.
   Hatch the free egg: that pet turns coloured. Tap a pet: nothing. Tap the blue gear (turns red), then tap a pet:
   red X. Gear off again: taps do nothing.
7. Phone size (Studio device emulator): same checks 1, 2, 5.
