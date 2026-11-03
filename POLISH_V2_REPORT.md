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

## U3 part 2: the egg board like the reference picture (615df90, tag restore-pl-U3-2-before)
- `Config.EggBoard.Grid = true` (false = the V6 row board): over each egg, buff lines (x2/x4/x8 LUCK, TRIPLE HATCH),
  the egg's name on a gold tab, a white card with the pets 3 across (chance on top, the pet turning in 3D on a tile
  in its rarity colour, rarity name under it; never found = black, rarest unfound = ???), the price pill right of the
  card (green / red when you can't pay / FREE xN), and 4 round buttons under it: AUTO-DELETE (gear), AUTO (T),
  OPEN 3 (R), OPEN 1 (E). Key letters on computers; phones show OFF/ON, x3, x1 instead.
- OPEN 3 without the TRIPLE HATCH pass = the pass prompt (Robux badge on the button). OPEN 1 now opens one egg even
  when you own TRIPLE HATCH (server: HatchEgg takes an optional count 1). AUTO still opens as many as your passes give.
- R and T only work while the board is up and you're not typing. E is still the stand's hold prompt.
- The PET EGGS sign now sits above the board instead of covering it.
- `Config.EggBoard.GridHeight` = how high the board floats over the egg.
- Self-test (zone 1, computer): board matches the picture; R opened 3 (2,250 coins), T auto-hatched until coins ran
  out, OPEN 1 through the remote charged 750 with TRIPLE HATCH on; found pets turned coloured and ??? moved to the
  next rarest. Console clean. Not tested by a real tap (Studio's mouse tool can't click 3D billboards): the four
  buttons and E; in the owner playtest. Zones 2-4 boards not looked at yet.

## L2 zone 1 colours + lighting (b7a976c, tag restore-pl-L2-before)
- Zone 1's day paint now comes from one named palette taken from the owner's zone 1 stalls (sky-blue steel, warm
  wood, cream, slate, gold): `Config.CoreLoop.Zone1Palette` + `Zone1Paint` (old place colour -> palette name). The
  old one-off picks (sky-blue/mint/coral/sand city) are written in the comment.
  - Roof floor: lilac grey -> warm mid concrete (8F8B85), so the teal lane and the stalls pop.
  - Bowlers' approach: khaki -> warm maple (A88A66; lighter shades glared white in the sun).
  - Tower walls: lilac white -> cream stone; tower glass -> the stalls' sky glass.
  - Far city blocks: cream stone, sand, warm brick, a darker stall-blue (so they don't melt into the sky); ground
    below: richer park green; helipad + gutters: the stalls' dark slate; helicopter: stall blue.
- Light (zone 1 Look row): sun later in the day (ClockTime 15.3: longer shadows on the lane, the tower's front in
  shade), Brightness 2, sky-blue fill in the shadows (was grey), exposure -0.05 (cream and white no longer blow
  out), contrast 0.14, thinner haze (0.26 / 0.35), bloom 0.06. Old values in the Config comment.
- Night leftovers: the lit windows, fill lights and helipad lamp were already off (DayNeon / DayLightsOff); the
  small string-light bulbs on props stay (they're decor).
- Zones 2-4 still borrow this look until L3 gives each its own row.
- Shots: screenshots/polish_v2/before/zone1_*.jpg vs after/zone1_*.jpg.

## L3 lighting for zones 2-4 (9c7cbaa, tag restore-pl-L3-before)
- Each outdoor zone has its own light now (its `LookChanges` in Config.CoreLoop.Zones.List; before, zones 2-3 borrowed
  the rooftop's look):
  - Sunset Boardwalk: late golden sun (16.8), peach haze, warm shadow fill.
  - Jungle Falls: high sun through a light green haze, green shadow fill.
  - Canyon Oasis: hot and golden (bright sun, warm sand fill, a little less exposure so the sand doesn't blow out).
- The lighting recipe (allowed ranges for Brightness, Exposure, Ambient, Haze, Bloom...) is written in Config.Zones
  above LookBlend, so later work stays consistent.
- Self-test: TEST panel jumps 2 -> 3 -> 4, each zone takes its own look, lane readable in all of them (shots in
  screenshots/polish_v2/after/zone2-4_lane.jpg). Console: only the two known warnings.
- Not checked: the 0.6 s fade itself frame by frame, effects (trails, hatch, fever) under each light, phone graphics
  level. In the owner playtest.

## L4 pads that match their zone (d58d354, tag restore-pl-L4-before)
- Every sell / shop pad is dressed like its zone's stalls (`Config.CoreLoop.PadStyles`, CoreLoopService `dressPad`):
  - Zone 1 rooftop: painted metal floor plate (diamond plate) with 8 gold bolts, dark slate rim.
  - Zone 2 boardwalk: round plank deck with a rope rim.
  - Zone 3 jungle: carved stone disc with moss patches over the rim.
  - Zone 4 canyon: sandstone tile with a carved, notched edge.
- Green (sell) / blue (shop) stays as a ring inlay, so players still know what each pad does. Same size, and the
  server's stand check (a distance) is unchanged. The sell coin sits on the new plate.
- PadStyles = nil brings the plain white-rim circles back.
- Self-test: zones 1 and 2 looked at (screenshots/polish_v2/after/zone1_pads.jpg, zone2_pads.jpg); zones 3-4 built
  without errors but not looked at. Selling / opening the shop by standing on a pad not re-tried (the check code
  didn't change).
- Not done from L4: egg stand rings, gate landings, rebirth spot, display case bases, per-zone hint beams, one
  style for every station billboard.

## Q3 part 1: small decor stops casting shadows (tag restore-pl-Q3-before)
- New `Config.Perf` + client `PerfController`: anchored parts in the four zones whose longest side is under 3 studs
  no longer cast shadows (string-light bulbs, bolts, leaves, small trims). Pins, balls, pets and players aren't
  anchored decor, so they keep their shadows. Enabled = false turns it off.
- Self-test: 7,087 zone parts without shadows, 4,305 still with; 60 fps on this PC; no errors.
- Still to do from Q3: move the old loop's areas (MainStreetLanes, BackAlley, NeonAlley, Hub, Showcase, ~5,500 parts
  nobody can reach) out of Workspace (careful: old services still look for them), phone-size frame rate per zone.

## Q3 part 2: the old areas leave the screen
- The old loop's areas (MainStreetLanes, BackAlley, NeonAlley, Hub, Showcase) sit by the map's middle, 3,700+ studs
  from every zone, and nobody can reach them. 12 s after joining, each player's screen moves them into a hidden
  folder (Config.Perf.HideOld, PerfController). Client only: the server keeps them, nothing is deleted, the old
  scripts that look them up already turned themselves off in the core loop or fail safely.
- Measured: parts on screen 17,244 -> 11,586 (a third fewer). 60 fps on this PC before and after; no new errors.
- Not done: a real phone fps number per zone (Studio on a PC can't measure a phone; do it in the owner playtest on a
  phone) and StreamingEnabled (bigger change, needs its own careful pass; recommended after launch if phones lag).
- Undo: Config.Perf.HideOld = false.

## D2 (AN2 core loop motion): started, one piece done
- Checked what item 5 (pins -> bag -> sell -> coins) already has: gains fly "+25" into the bag and the bag pops;
  a sell shows the green +amount tag and coins fly one by one into the coin pill with a rising "ding" and a bump
  per coin. Missing was the arc: they flew in straight lines.
- Done: every coin / gem fly (HudController flyIcons) now swoops home on a curve, bowed out to alternate sides, so
  a sell sprays out of the tag and swoops into the pill (Config.Juice.FlyBow / FlyBowMax; 0 = straight again).
  Shot: screenshots/polish_v2/after/sell_coins_arc.jpg.
- Done: the "+25" pin gains fly into the bag on a curve too (Config.CoreLoop.Gains.Bow); the bag already pops on
  each catch. Shot: screenshots/polish_v2/after/gain_arc.jpg.
- Not done in part 1: items 1-3 of AN2 (done in part 2 below) and a true squash of the bag (kept the even pop:
  resizing HUD icons fights HudKit's layout).

## D2 part 2: the throw, the hit, the pins (af1f33b, tag restore-pl-D2-2-before)
What the core loop really shows was measured first: while you hold THROW the camera sits at the pins, the power
meter is hidden (no charge in hold-to-throw) and there are no strikes (LUCKY! is the big moment). So:
- The swing: every hold-to-throw throw now winds up first (0.1 s: weight rocks back, arm swings back), swings down
  and slides forward into the lunge, then the follow-through swings a little past its pose and settles
  (Config.Throw.WindUpTime, FollowOvershoot). Low ball steps still throw "scuffed" on purpose (stiff, wobbly).
  Other players see your swing, and their ball leaves their hand at the release too.
- Your ball waits for your swing: it leaves the hand at the bottom of the down-swing instead of appearing the moment
  you press (ThrowPose.Lead, ~0.15 s in Studio, less with real ping); the pin counter and "+25" wait the same.
- The hit: a soft puff in the zone's ground colour where the ball meets the pins (rooftop concrete dust, boardwalk
  sand, jungle spray, canyon sand; Config.Throw.ImpactDust), a softer second clatter as the pins land.
- LUCKY!: a hit-stop (the ball and pins freeze for 0.05 s before the burst), a camera punch, and the bowler hops.
- Pins tumble end over end along their flight (Config.Throw.PinTumble 0.75) instead of spinning on a random axis.
- Not done (no meter / no strikes in the core loop): meter spring, "STRIKE!" letter slam, ball hook and lane glint
  (the ball only enters the pin camera for its last ~0.05 s, so a hook can't be seen).
- Self-test: held THROW ~2 s, sampled the arm joint: wind-up back, release, follow-through, ball appeared at the
  release; console clean (client + server). The LUCKY freeze wasn't caught live (random roll).

## Console notes for T1 (seen on every join)
- "rbxassetid://203785492 failed due to: Asset type does not match requested type" x4.
- "[ShowcaseController] zone 4: 10 balls to show but only 6 slots".
- The 203785492 warning is not any property in the game (searched every instance): most likely the Studio test
  avatar's clothing. Nothing to fix in the place.

## T1 found early: BUY BEST "second tap does nothing"
- Checked with real clicks and click counters: every tap reaches the button, and a second tap in the same spot
  buys again when there is something to buy. Not a tap bug.
- What it really was: once you own every ball of your open zones, BUY BEST goes grey and showed the NEXT ball's
  price (e.g. 4.8M for zone 2's first ball). A player holding 35M reads that as "I can afford it" and the tap
  only shakes. Fixed (ShopV2 fillFooter): the grey button now says OPEN ZONE 2 (no coin icon) when the next one
  is in a closed zone. Shot: screenshots/polish_v2/after/shop_buybest_locked.jpg.

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

## T1 early abuse checks (server side, through the remotes)
- 8 BUY BEST calls at once: 1 handled, 7 refused "Too fast, wait a sec"; no double charge, no double step.
- Buying away from the stall: refused "Buy it at the shop". Bad buy arguments: refused safely ("That didn't work").
- 3 SELL teleports on an empty bag: no sell counted, coins unchanged.

## T1 + T2 full bug hunt and fixes (d1582c3, tag restore-pl-T2-before)
- Whole loop played from zero in Studio through the real remotes and clicks; every finding is in BUG_HUNT_REPORT.md.
- 6 bugs fixed: NaN buy/equip guard, REBIRTH try away from the shop used up the rate limit, GIFTS tile titles were
  black blobs (dark text lost its ink outline), tutorial strip drew over windows, STORE showed "XP x1", PETS NEW
  count hid under the close X.
- Not tested (Studio limits): two players on the shared lane, a real phone, real Robux purchases.

## U4 last windows in the V2 look (tag restore-pl-U4-before)
- `Config.Ui.WindowsV2 = true`: the older window kits (UiKit, HudKit, RewardKit) take the SHOP / STORE look: navy
  window, navy cards, white text, SlKit button paints. One switch, so GIFTS, PROFILE (boosts, stats, achievements),
  SETTINGS and every other window built with those kits changed together. false = the cream windows come back.
- Window titles GIFTS / SETTINGS / TELEPORT are gold like SHOP and STORE; PROFILE idle tabs are navy tiles.
- Roof leaderboard wall: navy backdrop, tile panels, darker rows, ink rings, gradients off, light text (was cream on
  sky). Lane scoreboards use the same paint.
- Away coins line ("You made X coins while you were gone") uses Fredoka One with an ink outline.
- Decisions: re-skin, not rebuild (same reason as U2: keeps every working button and claim). TELEPORT window and the
  spin wheel are switched off in the core loop (unreachable), so they only got the palette, not a visual check.
- Checked in Play: SETTINGS, GIFTS, PROFILE x3 tabs (screenshots), leaderboard colours read back (3D view not drawing
  in captures this session). Console: only the known warnings.

## U5 moments + popups (tag restore-pl-U5-before)
- Opening a zone at its gate is now a big moment: the gold slam banner "ZONE 2 OPEN!" with the zone's name on a navy
  chip, the map-pin icon and confetti (was a small note). "Welcome to ..." on a return trip stays the small note.
- Fixed: after opening zone 2 a CHALLENGE card asked for "3 STRIKES IN A ROW" for a free crate. The core loop has
  no strikes, so it could never be done; strike challenges are hidden while the core loop is on.
- Fixed: tapping the dim background behind a window shrank the background itself (the press effect every button
  gets), uncovering a bright strip at the right and bottom of the screen. Screen-sized backdrops don't shrink now.
- Checked in Play, already in the V2 look through U4's palette: FEVER! and lane event banners (orange / gold plate +
  navy chip), REBIRTH! moment (navy chips, green CONTINUE), toasts, area signs (HudKit paints), chat tag.
- Only one window at a time: tapping a HUD button while a window is open closes the window first (backdrop).
- Not live in the core loop (no strikes): fever, lane events, strike challenges, the spin wheel, TELEPORT window.
  They keep working through the TEST panel and use the new palette, but a player never sees them.
- Not done: a real phone-size check (Studio can't change the screen size from here). Windows and moments shrink
  to fit any screen by code (RewardKit.Window / MomentKit stage fit).

## D1 Motion module + HUD buttons, windows, dots, toasts (tag restore-pl-D1-before)
- New `Modules/Motion` (numbers in `Config.Motion`): springs for anything you touch, so a new target bends the motion
  already running and a fast tap can't leave a button stuck half-pressed. Named presets used everywhere: Snap
  (buttons down), Pop (buttons back up with a small kick, small rewards, red dots), Window (opening, ~8% overshoot),
  Slam (big moments), Shut (closing), Float (idle bob), Drift (soft fades). Stagger 0.05 s.
- Windows grow out of the button you pressed and shrink back into it: GIFTS, PROFILE, SETTINGS, DAILY, PETS, STORE
  and every window built on the shared kits. Opened with no button (the SHOP on its stall pad) = pops in place.
  Fixes an old quirk too: the kit windows used to grow from their top-left corner.
- Every button press (UiFx, SlKit, HUD hover) is on springs; red dots and count badges pop in on a spring when they
  appear; SlKit pulses stack smoothly; idle bobs (hint bubbles, ready cards) move on a small curve, not a line.
- Toasts drop on a spring and settle; two toasts at once stack instead of covering each other.
- Not done here: new-item glints (moved to D3/D4 where the new items are).
- Checked in Play: GIFTS caught mid-flight coming out of its button, settles at the same spot as before; close /
  re-open / fast open-close taps on PETS end clean (hidden, scale 1, at rest); STORE, PROFILE; held THROW and
  4 s of throws; console = only the known avatar warning.
