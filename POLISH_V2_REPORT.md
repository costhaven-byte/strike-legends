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

## D3 shop, rebirth, gates, teleports (tag restore-pl-D3-before)
- The SHOP window now grows out of the stall you walked onto (its spot on screen), not just in place, and the ball /
  bag cards pop in one after another, top row first.
- REBIRTH! moment: the whole card slams in on a spring (overshoots, settles), the arrows land with a wobble before
  they start turning, and the name, each chip (coins, pins, rank) and CONTINUE pop in one by one with a tick.
- Every teleport (SELL, the shop card, GO TO SHOP, gates, rebirth, TEST jumps) hides its cut behind a navy band
  that covers the screen on the frame you land and sweeps off to the right (0.38 s, `Config.Motion.Wipe`). It
  reacts to the character jumping more than 40 studs in one frame, so any future teleport gets it for free.
- Gates keep U5's ZONE n OPEN! banner. No camera fly-through: the plan's idea, but taking the camera away right
  after you choose to travel felt like a cutscene you can't skip; the wipe + banner do the job.
- Checked in Play: the wipe band (23 frames, covered then gone) on a zone 2 jump; shop window flies from the stall
  (837,407 -> 335,1, overshoot 1.07 -> 1.00); all 10 cards back at full size; rebirth held through the SHOP's
  REBIRTH tab -> moment shows, pop and chips at 1.00; console = only the known avatar warning.

## D4 pets + eggs (tag restore-pl-D4-before)
- Pets follow you on a spring (`Config.PetMotion`): a little lag, a small overshoot when you stop, they face where
  they're going, lean into turns (flyers more than walkers), flyers dip their nose at speed, walkers hop along as
  they walk. A teleport still puts them straight next to you.
- Every throw: your pets turn to watch the ball down the lane, then look back. A LUCKY hit makes them cheer (their
  own Hop / Spin / Flip / Wiggle) right where they are; the core loop has no strikes, so that's the big moment.
- Stand still for 30 s (no moving, no throwing): your pets doze off: they stop their idle wiggle, flyers sink a
  little, they lean over and a "z" floats up. Move or throw and they wake at once.
- A pet you equip hops out of you (starts at your middle, arcs ~2 studs up, lands at its spot).
- PETS window: the green EQUIPPED tick pops on.
- Eggs on their stands rock on their base every ~4 s (like something inside wants out); they rest while a hatch
  plays.
- Egg board: a pet found for the first time flips over from black to colour (edge-on in the middle), one after
  another, rarest last. Found during a hatch (the board hides), it flips when the board shows again.
- Left as they were: the hatch (V7, already on the owner's storyboard) and the FUSE window (V6, bouncing FUSE).
  Crates aren't in the core loop (the crate shop is hidden), so no crate work.
- Checked in Play: walking hop 0.55 studs, none standing; pets face the pins during a throw (dot 1.00) and back
  after (0.04); doze + z after 33 s still; egg rocks up to 5 degrees and settles back exactly (0.000 drift); board
  flip after a real hatch (Breezy: 100 px black -> 3 px -> 100 px colour); equip hop peaks ~2.3 studs over its
  start (tested with a Heartbeat copy: Studio stopped drawing frames when its window was hidden). Console clean.

## L6 ball effect colours (tag restore-pl-L6-before)
- Every ladder ball's effect (trail, sparkles, light, floor streak) now takes its colour from its v2 paint:
  `Config.BallVfx.V2Paint` (40 rows from assets/v2_balls/spec.json: Main = the ball's most vivid colour, dark ones
  lifted so a trail still glows; Accent = its gem / insert). BallFx turns each look to the paint's hue and pulls its
  colours close to it (`V2Spread` 0.3), keeping each colour's lightness, so white cores stay white. The Rainbow Arc
  and Confetti Popper keep all their colours.
- The plain `Trail` colour of the 40 balls (pin bursts, lane follow lights) is the paint too (old value in a comment).
- Trail styles were matched to the OLD ball names (the ids stayed when the v2 balls came in): the Coral Crusher
  trailed fire, the Tide Turner toxic goo, the Golden Sphinx a galaxy. Re-matched to the v2 themes: Sky for Cloud
  Roll / Gust / Tornado / Kite Flyer / Dust Devil / Sandstorm, Storm for Sunbolt / Monsoon, Solar for Sunspike /
  Sun Disc, Gold for Lighthouse / Temple Stone / Jungle King / Golden Sphinx, Galaxy for Sonic Boom, Dawn for Sunset
  Splash, Toxic (venom) for Scorpion; the rest draw Stardust in their own colours.
- Kept on purpose: each ball's signature hit effect keeps its theme colour (the lighthouse beam is yellow light, the
  waterfall blue water), and the themed styles keep their own colours (fire is orange).
- Checked in Play, all 40 balls built through BallFx: every ball's effect is 65-100% on its paint's hue (Scorpion
  55%: its green venom style). Before: 18 balls were mostly another colour.

## D5 the 40 ball effects (tag restore-pl-D5-before)
- The 40 signature hits were already built (Addendum 5 D + Addendum 6 stages 4-6), each with its own roll trail,
  hit, pin push and sound; L6 just gave their trails the ball's v2 colours.
- Fixed the plan's "impact = freeze + shake + particles + sound together" rule: effects whose falling part lands a
  moment after the ball (Coconut, Toucan, Waterfall, Rope Bridge, Temple Stone, Monsoon, Jungle King, Mesa, Cactus,
  Scorpion, Sun Disc, Mirage, Golden Sphinx, Oasis, Pier Pounder) shook the camera when the ball arrived, before the
  hit. The shake now lands with the falling part, its sound and its burst.
- Checked in Play: every one of the 40 played (roll + hit) at full strength on the real lane, with a copy that runs
  their animated parts on Heartbeat (Studio wasn't drawing frames): no errors, console clean.
- Not done (needs eyes on the 3D view, which Studio wasn't drawing this session): judging each effect's look one by
  one, the plan's "one zone per chat" review. It's in the owner playtest: throw each zone's balls 1, 5 and 10.

## D6 rewards, camera, loading screen (tag restore-pl-D6-before)
- Camera shakes (throws, ball hits, big moments) now ring out along one direction (mostly up-down, a little
  sideways, 11 swings a second, `Config.Juice.ShakeFreq`) with a little jitter on top (`ShakeJitter`), instead of
  random jitter. SETTINGS > SCREEN SHAKE off still turns them all off.
- DAILY: the reward icons now swoop into the HUD on a curve bowed to alternate sides (like the sell coins), shrinking
  as they go.
- Already in good shape, left as is: GIFTS claims (tile jump, tick stamp, confetti, flash), the loading screen's exit
  (logo lifts, pins scatter, everything fades over 0.6 s) and the join fly-over's eased glide back.
- Not live in the core loop, so not touched: spin wheel, fever, lane events, the boss (`Config.Boss.Enabled` is off
  while the core loop is on).
- Checked in Play: throw shake x/y movement 89% along one line, 11 swings in 0.5 s, dying out; the bigger shake rings
  out the same way. The DAILY curve wasn't watched live (Studio wasn't drawing frames); it uses the same curve maths
  as the sell coins, checked in D2.

## D7 living world (tag restore-pl-D7-before)
- New `WorldLifeController` (numbers in `Config.WorldLife`), client only: only the zone your camera is in moves, 30
  updates a second, one BulkMoveTo per frame; leaving a zone puts everything back exactly.
  - Palm leaves (zones 2-4) bob up and down on their crown, each palm a little out of step with the next.
  - Bunting flags (zones 2-4) flutter on their rope, the movement running along the rope like a wave.
  - Zone 2's kites and zone 4's hot-air balloon float up and down with a slow roll.
  - Zone 3's waterfall sheets flow: a vapour texture scrolls down both faces, and mist puffs up from the foam.
  - The shop and sell pads pulse a ring in their colour with a soft tap the moment you step on (every zone).
- SETTINGS > EFFECTS off stops the world moving (the pad pulse stays: it's feedback).
- Already moving, not touched: the ferris wheel, the egg rock (D4), pets. Not done: water surfaces/waves (the
  boardwalk has no sea part to move; the jungle pool and oasis are flat parts), birds and clouds (there's one pigeon
  coop prop and no bird models: adding new birds is new art, so it's on the list for the owner, not invented here),
  stall idles (the stalls' coins and balls are welded into the owner's models).
- Checked in Play (zone 2, a Heartbeat copy because Studio wasn't drawing frames): a palm leaf swings 9 degrees end
  to end, a flag 0.2 studs, a kite 1.2 studs; 9 waterfall sheets got their flow; stepping on the sell pad made the
  ring. Console clean (one parse error came from a broken test copy of mine, not the game).

## L5 world clean-up (tag restore-pl-L5-before)
- Checked by code (Studio wasn't drawing the 3D view this session, so no eye-check): zones 2-4 stand on terrain, so
  stepping off their edges lands you on ground. Zone 1 is a roof ~1,300 studs up: glass rails close most sides, but
  some sides (behind the lanes) open straight into the void, where you fell to your death and waited to respawn.
- New fall rescue (`Config.WorldLife.FallRescue` = 80): fall more than 80 studs below where you last stood and you're
  put back there (the D3 wipe hides the jump). Teleports (shop, sell, gates, rebirth) don't count as falls.
- Checked in Play: stepped off the roof edge, dropped to 776, was put back on the roof alive; zone 2 travel right
  after landed in zone 2 (not pulled back).
- Not done (needs eyes on the 3D view): part-built leftovers next to designed models, hero prop scale, gaps,
  z-fighting, unused display cases in zones 2-3. These go to the owner's playtest walk-around (each zone's edges).

## Q1 sounds (tag restore-pl-Q1-before)
- Bug found: the zone music still followed the OLD building areas, so the roof (zone 1) played the old zone 4 track
  and all three outdoor zones played the same track. Now music follows today's zones
  (`AssetSlots.Music.CoreZones`): zone 1 roof = Rooftop Triumph + roof wind (as before), Sunset Boardwalk = Vinyl
  Cradle (as before), Jungle Falls = Neon Arcade Run, Canyon Oasis = Jukebox Lanes. Outdoor zones play music only:
  the 4 ambiences are indoor halls and city roof wind, which don't fit a beach, jungle or canyon (a new ambience id
  can go in each zone's `Ambience` slot). Music still cross-fades over 2 s on teleports and rebirths.
- The same sound in the same place can't start twice within `Config.Juice.SameSoundGap` (0.05 s): fast taps and
  count-ups that ticked every frame (crate coin count-up) no longer pile up into one loud blast. Pin hits on
  different pins still all play; looping sounds are never skipped.
- Falling off the roof and being put back (L5) now plays the soft teleport whoosh.
- Checked in Play: 5 clicks in one frame = 1 sound, another 0.06 s later plays; Coin + Tap together both play;
  zone 1 -> zone 2 switched Rooftop Triumph to Vinyl Cradle; MUSIC slider at 30% sets the music group to 0.3;
  SOUND EFFECTS off sets the effects group to 0 and back on to 1.
- Volumes left as they are: frequent sounds are quiet (Click 0.4, Coin 0.3), big moments loud (strike, boss 1.0),
  music 0.22 under the 70% slider.
- New things from this run all have sounds (pad pulse Tap, zone open Cheer, tutorial SpinWin, board flip Reveal,
  rebirth ticks, fall rescue Teleport).

## Q2 words, the rest (no changes needed)
- Scanned every text in every screen a player can open today, the 4 zones' signs and prompts, and the code of the
  windows that are built only when opened (shop, pets, eggs, daily, store, profile, rebirth, tutorial, settings).
- Old names (Neon Egg, Main Street, Back Alley, Rizzo, crates, LEVEL, POWER LV) only live in the old screens that
  are switched off in today's game (old ball book, trials, events, rank-up, the pre-core rebirth window). Players
  can't reach them. "Skyline Rooftop" is zone 1's real name, so "Back to Skyline Rooftop" is right.
- Numbers: one format everywhere (1K, 1.23K, 999.9K, 1.5M, 2.45B, 1T, 3.3Qa, x1.25); it rounds down, so it never
  shows "1000K".
- Not checked: cut-off text. Studio wasn't drawing its window (screen size 1x1), so text sizes can't be measured.
  It's in the playtest below (computer + phone size).

## T3 final check (tag restore-pl-Q1-before covers it; nothing changed in T3)
- Join: zero errors and zero warnings in the console (the old avatar-asset and showcase warnings are gone too).
- Core loop replayed through the game's own remotes: 28 throw presses -> 14 throws (the cooldown, as designed), bag
  filled 0 -> 60, SELL paid 930 coins, then at the shop ball 2 and bag 2 bought (950 -> 780 coins).
- Every stage of this run was checked live as it was built (see each section). What only eyes can check is in the
  playtest below.

## FINAL owner playtest (about 10 minutes, covers the whole run)
Before: File > Save to Roblox As a copy. Restore for code = git tag `restore-polish-v2-before`. Keep the Studio
window visible. TEST panel: START FROM ZERO.
1. Join (1 min): loading screen, then the roof. Music = Rooftop Triumph with soft wind. HUD: PETS, STORE / DAILY,
   PROFILE / PASSES, GIFTS + SETTINGS top-right, no SHOP button. Silent failure: a gap in the button grid.
2. Tutorial (2 min): hand on THROW -> throw (ball winds up, slides, dust on hit, pins tumble, +20 off the first tile)
   -> SELL (+30, coins fly on a curve) -> NEXT GOAL (screen wipe, you land at the shop, the shop grows out of the
   stall, cards pop in one by one) -> BUY BEST (+120) -> one more buy = FREE EGG. Silent failure: a reward paid twice.
3. Pets (1.5 min): walk to the Rooftop Egg (it rocks every few seconds). Hatch: the board pet flips from black to
   colour. Equip: the pet hops out of you, follows on a spring, leans in turns, watches the lane while your ball
   rolls. Stand still 30 s: it dozes with a small "z". Silent failure: a pet sinking into the floor.
4. Windows (1 min): every window grows from its button and is navy (no cream, no purple, no gradients). DAILY: the
   reward flies home on a curve.
5. Zones (2 min): TEST panel Zone2. ZONE 2 OPEN! gold banner, wipe, Sunset Boardwalk: music changes to Vinyl Cradle
   over 2 s. Palms sway, flags flutter, kites float, the sell/shop pad pulses when you step on it. Zone3 = Jungle
   Falls (waterfalls flow, music Neon Arcade Run), Zone4 = Canyon Oasis (music Jukebox Lanes). Silent failure: the
   same song in every zone, or the music cutting instead of fading.
6. Ball effects (1 min): TEST panel gives -> throw a few balls: effect colours match each ball's paint; big hits shake
   up-down along one line (not random jitter); falling-part effects shake when the part lands.
7. Rebirth (1 min): TEST panel Rebirth (or coins + rebirth at the shop): the celebration springs in, chips pop one by
   one with ticks, wipe back to the roof, music back to Rooftop Triumph.
8. Edges (30 s): walk off the open roof edge behind the lanes: you're put back on the roof with a soft whoosh.
9. Fast taps (15 s): tap a button 5 times fast: clicks never stack into one loud blast.
10. Phone size (Studio device emulator, 1 min): repeat 1, 2 and 4. Look for text that is cut off or runs out of its
   box (the one thing that couldn't be checked by code this run).

## Launch list (owner)
1. 2X PINS game pass: make it on the Creator Hub and put its ID in Config (`PassId` is still 0, so the pass is hidden in the live game).
2. Monetization: already ON (owner flipped it, 7ba3d33). Check one test purchase of each kind in Studio.
3. Thumbnail + icon: from THUMBNAIL_ICON_PROMPTS.md / assets/thumbnail_art.
4. File > Save to Roblox (the place is not saved since the v2 model batches; every change of this run is synced into
   Studio).
5. Publish, then play once on a real phone.
6. Optional: beach / jungle / canyon ambience sounds for zones 2-4 (`AssetSlots.Music.CoreZones[n].Ambience`).
