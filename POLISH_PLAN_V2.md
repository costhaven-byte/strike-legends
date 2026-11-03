# Polish plan v2 (2026-11-03)

The last big pass before launch. The new UI (V0-V8) and the new 3D models are in. This pass makes the whole game look like **one game** and then makes every piece of it move well. After that we play the whole game from zero to find bugs and fix them.

Order of authority: this plan builds on ADDENDUM_6 (core loop), UI_OVERHAUL_PLAN.md (the V2 look), ANIMATION_POLISH_PLAN.md (motion rules, folded in here as stage group D) and the owner's notes below. Launch = zones 1-4.

## Owner's asks (2026-11-03), and where each one lands

| Ask | Step |
|---|---|
| Fix zone 1 colours and lighting | L2 |
| Check the lighting everywhere | L1 (audit), L3 |
| Make everything match its zone (the sell pad you step on doesn't match the sell stall, etc.) | L4, L5 |
| New egg odds board like the reference picture; pets you haven't found = black | U3 |
| Take SHOP off the HUD, keep the other buttons | U1 |
| Take PASSES out of the SHOP; passes only in the STORE | U1, U2 |
| Full polish of the game, all animations included | groups U, D, Q |
| A full playtest only to test the loop and hunt bugs | T1, T2 |

## How this runs: ONE step, one chat (owner 2026-11-03)

The owner wants the whole plan done in **one go**, in one chat, without stopping between stages for a PASSED (like the 2026-10-29 overnight run). So:

1. **One restore point before starting:** git tag `restore-polish-v2-before` + the owner does **File > Save to Roblox As** a copy (the real game is cloud place 94254609600041; the .rbxl on disk is stale). Each stage also gets its own tag `restore-pl-<stage>-before`, so any one stage can be rolled back alone.
2. **Work through every stage in the build order without waiting.** The builder is its own tester: after each stage, check it in Play mode (screenshots computer + phone size, console clean on client and server), fix what it finds, commit, then move on. Never leave a stage half-built to start the next.
3. **Decisions the plan gives to the owner are made by the builder** with the safest choice, and written down in the report so the owner can reverse them (e.g. unused display cases, keeping the HUD PASSES button).
4. **Stop and ask only** if something would delete saved data, delete or rewrite a system that works, or turn monetization on.
5. Long run: use subagents for wide searches and audits to keep the main chat's context free; write progress into `POLISH_V2_REPORT.md` after every stage (so a context reset loses nothing) and keep PROJECT_STATE.md short.
6. **At the end, one report** `POLISH_V2_REPORT.md`: per stage what changed, the commit, the tag, decisions made, placeholders still in use; then **one combined playtest for the owner** (about 10 minutes, grouped by zone, with the expected result and the usual silent failures for each part). The owner says PASSED once, or lists what to change.
7. Screenshots before and after for every look stage in `screenshots/polish_v2/` (Studio MCP `screen_capture`), so the owner can compare.

### Working notes for the builder (read before any step)

- Read PROJECT_STATE.md and the memory notes it points to. Gotchas that bite in this pass: Rojo is often connected but not applying (use the http sync trick); never run stylua on Config (duplicate instances); `ScaleTo` is absolute; pet viewports on Workspace billboards don't draw (use PlayerGui + Adornee); ColorSequence max 20 points; Global ZIndex on ScreenGuis; particles only animate in Play mode; Studio unfocused = 15 fps (don't judge speed then); fresh meshes and textures need Roblox processing time before they show.
- Look rules (owner): **no gradients, no purple panels**, flat vivid solid colours, Fredoka One, 3 px #10172E outline, darker lip, lighter top strip (SlKit). New UI is built with `Modules/SlKit`, never by hand.
- Keep the V2 switches (`Config.Ui.*V2`). Don't delete old code paths, old models or ServerStorage backups without asking. Save changes need a SchemaVersion bump + an upgrade step in SaveStore.
- All tunable numbers go in Config. Server stays in charge of coins, pins, pets and saving.
- Measure first. Each step starts by reading the code it changes and capturing the current look; no guessing at colours or positions.

---

## Before anything: step L0, zone 4 models

Zone 4 (Canyon Oasis) still has the part-built sell/shop booths and gate; `assets/v2_zone4` is started but not committed. Finish it the same way as zones 1-3 (ZoneKits.Zone4, Config.CoreLoop.Kits[4], zone 4 egg + stand, pets, hero props) so every look step below works on final models. **Done when** all 4 zones use the owner's stalls, gates and eggs.

---

## Group L: one look for the whole world

### L1 Look audit (no changes, a report)
Walk every zone in Play mode (TEST panel jumps) and write `LOOK_AUDIT.md`:
- Fixed camera spots per zone (spawn, lane from behind the bowler, sell stall, shop stall, egg, gate, a wide shot), computer + phone, saved to `screenshots/polish_v2/before/`.
- The lighting numbers each zone really ends up with (Lighting, Atmosphere, ColorCorrection, Bloom, Sky, sun, shadows), read live, next to what Config says.
- Leftovers from old zones that still touch the new ones. Known suspects to check:
  - `Config.Brightness.LaneLight` rows are still named for Back Alley / Neon / Main Street / Skyline; with the shared lane, which row does each zone really get?
  - `Config.CoreLoop.DayColors` repaints the **night** rooftop into day in code. Zone 1's odd colours most likely come from here (sky-blue city, coral, mint, sand chosen as hex swaps, not designed together).
  - Zones 2-4 reuse the rooftop look unless their row has `LookChanges`.
  - Neon parts, PointLights and SurfaceLights left over from the night look; the per-player fill light.
- A list of every piece that doesn't match its zone: pads, rims, signs, beams, billboards, fonts, part-built leftovers, z-fighting, floating or sunk parts, holes, invisible walls, things players can't walk on but look walkable.
- A short "palette" per zone (5-6 colours) taken from the owner's models, so later steps paint to it.

**Done when** the report is written; the builder picks what to fix from it (everything that breaks the "one look" rule) and L2-L5 work through that list.

### L2 Zone 1 colours + lighting
- Repaint zone 1 to its palette from L1 instead of the hex swaps: city blocks, rooftop floor, rails, helipad, pit, gutters, far ground. Move the paint into the place file or a clear Config table with named colours (not hex-to-hex).
- Lighting: one sunny look that matches the owner's stalls and pets (sun angle that gives readable shadows on the lane, ambient not grey, exposure so white parts don't blow out, bloom low so UI and neon don't haze).
- The lane must read first: lane, pins, ball and player brighter and more saturated than the background.
- Night leftovers off (neon windows, fill lights, helipad lamp) unless the audit says keep.
**Test:** spawn in zone 1, compare with the before shots: colours fit the stalls, lane pops, nothing glows white.

### L3 Lighting for zones 2-4 + moving between zones
- Each zone gets its own Look row (no more borrowing the rooftop's): boardwalk sunset warm, jungle green and soft with light haze, canyon hot and golden. Same rules as L2.
- One lighting recipe written into Config comments: allowed ranges for Brightness, Exposure, Ambient, Bloom, Haze, so later work stays consistent.
- Blends between zones (gates, teleport, rebirth back to zone 1) fade cleanly, with no flash of the old night look.
- Effects check under every zone's light: ball signatures, trails, fever flames, hatch, crate reveal, pet auras. Nothing blinding, nothing invisible.
- Phone check: lower graphics level still looks right (no pitch-black areas when shadows drop).
**Test:** walk 1→2→3→4 through the gates and teleport back: each zone has its own mood, no flash, lane always readable.

### L4 Pads and stations that match their zone
Today every zone has the same plain white-rim green circle (sell) and blue circle (shop) in front of the owner's designed stalls (`CoreLoopService.buildStation` / `buildShop`). Replace them with pads that belong to each stall:
- Zone 1 rooftop: a painted metal floor plate with bolts + a stencilled coin / ball, same trims as the stall.
- Zone 2 boardwalk: a round plank deck with a rope rim.
- Zone 3 jungle: a carved stone disc with moss and the stall's bamboo trim.
- Zone 4 canyon: a sandstone tile with carved edge and the stall's colours.
- Keep the colour meaning (green = sell, blue = shop) as an inlay or glow ring so players still know what it does, and keep the same size and trigger area (the server's stand-check radius doesn't change).
- Same treatment for the other things you walk to: egg stand floor rings, gate landing, the rebirth spot at the shop, display case bases, hint beams/arrows (colour + style per zone, not one generic beam).
- Billboards and signs over stations (SELL, BALLS & BAGS, egg name, gate price) all in one style: same font, outline, plate shape, size by distance.
- Built as models in `ServerStorage.ZoneKits.Zone<n>` (Kits[n].SellPad / ShopPad), placed by `placeKit`; the plain circle stays as the fallback.
**Test:** in each zone, the pad looks like part of its stall; standing on it still sells / opens the shop.

### L5 World clean-up sweep
Fix the rest of the L1 list zone by zone: part-built leftovers next to designed models, hero prop scale, gaps, z-fighting, floating parts, collisions (can't get stuck, can't fall off the map, no invisible walls where it looks open), unused display cases in zones 2-3 (builder decides, noted in the report), fresh textures that never finished processing, old names on signs. One pass per zone if the list is long (L5a-L5d).
**Test:** walk every edge of each zone; nothing looks unfinished, nothing traps you.

### L6 Ball effect colours
`Config.BallVfx` and the trails still use the old ball designs' colours. Re-pick each ball's trail, glow and signature colours from its new v2 paint (assets/v2_balls/spec.json) so the effect matches the ball. One table pass, then a look at all 40 in the TEST panel.
**Test:** throw 5 balls per zone: the effect colour matches the ball.

---

## Group U: HUD, store, egg board, the last old screens

### U1 HUD: no SHOP button; passes leave the SHOP
- Remove the **SHOP** button (balls + bags window) from the HUD on computer and phone; the grid closes up with no hole (PETS, STORE, DAILY, PROFILE, TELEPORT and the rest stay). The shop then only opens at the BALLS & BAGS stall. *(Assumed: "shop" = the SHOP button, not STORE, since passes move into STORE. Flag it in the report.)*
- Everything that pointed at the SHOP button points at the stall instead: onboarding arrows, NEXT GOAL card taps, red dots, afford hints ("GO TO SHOP" walks you there with the beam).
- Remove the **PASSES** tab from the SHOP window (ShopV2 and the old CoreShopController window). The SHOP keeps BALLS / BAGS / REBIRTH.
- The small HUD PASSES button stays but opens the STORE on its passes section (owner can say remove it).
**Test:** no SHOP button; tapping things that used to open it now guides you to the stall; SHOP has 3 tabs; PASSES opens the STORE.

### U2 STORE in the V2 look, with all passes
The STORE is still the older Store Kit window. Rebuild it with SlKit (same window, tabs, cards and price buttons as the SHOP): PASSES (the 8 pass cards from ShopV2, moved here), BOOSTS (coin/XP ladders), GEMS, OFFERS (starter pack, 2x 15 min). Robux price / OWNED / NO ID YET states, buy prompt unchanged, still behind `MonetizationEnabled = false`. Phone layout.
**Test:** STORE opens in the new look, every pass is there, buying works in Studio preview.

### U3 New egg odds board (owner's reference picture)
Replace the board over each egg stand (`Modules/EggV2`) with the reference layout:
- A clean card over the egg: a grid of square pet tiles (3 across), each tile = the pet in 3D, **chance on top** ("24%"), **rarity name under it** in the rarity colour (Common / Uncommon / Rare / Epic / Legendary / Mythic).
- **Pets you haven't found yet are blacked out**: a black silhouette (viewport lit pure black), name hidden; the rarest unfound one shows "???". Chance still shows (honest odds).
- Price pill next to the board (coin icon + price; red when you can't afford; FREE xN when you have free eggs).
- Round button row under the board, like the reference: **AUTO-DELETE** (gear: turns on delete mode, then tapping tiles marks them X; off = tapping tiles does nothing, so no accidental deletes), **AUTO (T)**, **OPEN 3 (R)**, **OPEN 1 (E)**. Key letters show on computers only; check R and T don't clash with other keys first.
- Buff lines above the board when active (LUCKY x2, TRIPLE HATCH owned, potions), like the reference's "2X LUCK".
- Our look, not the reference's: flat SlKit colours, ink outlines, no gradients, no purple.
- Save: new field `PetsFound` (every pet ever hatched, kept after fusing or deleting), SchemaVersion 39, upgrade step fills it from the pets each save owns now. The hatch card's NEW! uses it too.
**Test:** at each egg: board matches the picture, unfound pets are black, hatch a new one and it turns coloured on the board, buttons and keys work, auto-delete only in delete mode.

### U4 + U5 Last screens in the V2 look
Restyle the screens UI_OVERHAUL_PLAN.md lists as "not designed yet" with SlKit (same window, cards, buttons, fonts), split in two steps:
- **U4:** gifts / playtime, spin wheel, profile + achievements, settings, teleport, away coins, leaderboards.
- **U5:** toasts + afford hints, zone unlocked, rebirth moment, fever banner, lane events, level-up / milestone popups, starter pack / offers, area signs, chat tags.
Also check every screen on a phone (nothing off-screen, buttons big enough to tap, text fits without overflow) and that no window can open on top of another and get stuck.
**Test:** open each screen once on computer and phone: all the same look, no old style left.

---

## Group D: animations (ANIMATION_POLISH_PLAN.md, now unblocked)

The designs are in, so the motion plan can run. Its rules stay (one Motion module with springs + named presets Snap / Pop / Slam / Float / Drift, anticipation → action → follow-through, stagger, weight by importance, impact = freeze + shake + particles + sound together, squash only on bouncy things, respects SETTINGS, phones at 60 fps). Its 17 groups, in this order:

- **D1 = AN1:** Motion module + every HUD button, window open/close (from and back into the button that opened it), toasts, red dots, hint arrows, new-item glints. Retune SlKit's motion helpers onto it so all V2 screens share it.
- **D2 = AN2:** the core loop: throw approach (4 steps, swing follows the meter, slide, follow-through), meter feel, ball roll + hook + lane glint, pins with weight, strike moment, pins → bag chips, bag squash, SELL coin burst into the coin pill.
- **D3 = AN3:** shop open/cards/buy reveal, rebirth hold + moment, gates opening + camera fly-through, teleport wipe.
- **D4 = AN4:** egg idle wobble on the stand, U3 board appear/tile flip when a pet is found, hatch (already V7; check it against the rules), pets follow with spring + banking, hop/bob, look at the ball, strike cheers, AFK sleep, equip pop, fusion, crates.
- **D5 = AN5:** the 40 ball effects, one zone per chat (D5a-D5d).
- **D6 = AN6:** rewards (daily tiles, gifts, spin wheel momentum), fever, lane events, camera (smooth curves, one directional shake), loading screen, boss (check first if the boss is still in the live loop).
- **D7 (new): living world.** Things that should move but don't: water and waves (boardwalk sea, jungle river + waterfall, canyon lake), flags/cloth/palm leaves swaying, birds/pigeons, clouds drifting, ferris wheel already turns, station idles (coin bobbing on the sell stall, ball turning on the shop stall, egg glow pulsing), pad step-on feedback (ring pulse + sound when you step on a pad). All client-side, cheap, capped on phones.

Each D step: a before/after clip description in the test, and frame rate checked on phone size.

---

## Group Q: sound, words, speed

### Q1 Sound pass
Every new button, window, pad, board and animation from L/U/D has a sound (AssetSlots; borrow a stand-in if none fits and list it as a placeholder). Volume balance between music, ambience and effects; zone music fades on gate/teleport/rebirth; no sound plays twice at once on fast taps; SETTINGS sliders work on all of it.

### Q2 Words + names pass
Search all player-facing text: old names (Back Alley, Neon Egg, Main Street, Alley, Skyline where it's now something else), typos, inconsistent caps, number formats (1.2K / 3.4M / Qa), cut-off text on phones. Fix them; the full before → after list goes in the report.

### Q3 Speed + phone pass
Measure on a phone-size test: frame rate in each zone with 6 pets out and effects on, part and triangle counts per zone, particle counts at peak (strike + fever + hatch), memory, join time. Fix the worst offenders (merge static parts, anchor, CastShadow off on small decor, cap emitters, stream far zones). Target: 60 fps on a mid phone in normal play, no hitch on strike or hatch.

---

## Group T: full playtest + bug hunt (owner's ask)

### T1 Full loop playtest, only to find bugs (no fixes in this step)
Play the whole game from zero, as a new player, through the real loop: no gives from the TEST panel except where a step would take hours (and those are listed). Done with Studio MCP in Play mode (inputs + checks), plus a local 2-player test server for anything shared.
Covers, in order:
1. Join: loading screen, intro, first throw, first-minutes guides (with the SHOP button gone).
2. Core loop many times: throw (PERFECT, normal, gutter, overcharge), pins into the bag, bag full, sell on every zone's new pad, coins add up right (check the server math against the payout shown).
3. Shop at every stall: buy each ball/bag step, BUY BEST, can't-afford states, equipped look.
4. Eggs at every stand: single, triple, auto, auto-delete, free eggs, pets found turning coloured, equip best, pet slots, fusion.
5. Gates zone 1→4, zone music + lighting, teleport, rebirth (hold, what resets, what stays), rebirth ranks, zones open by rebirths.
6. Daily, gifts, playtime, spin, away coins, potions, fever, lane events, achievements, leaderboards, settings switches.
7. STORE + passes in Studio preview (buy, owned state, effects of each pass), Monetization still off.
8. Saving: leave and rejoin at several points (mid-bag, mid-hatch, right after rebirth); an old save from before this pass still loads (SchemaVersion 39 upgrade).
9. Abuse checks: spam taps, sell spam, hatch spam, standing on two pads, leaving during a hatch, two players on the shared lane at once, fast remote calls (server refuses, nothing duplicates).
10. Phone size the whole way through.
Output: `BUG_HUNT_REPORT.md` = every bug with steps to repeat, what happened vs. what should, how bad (breaks the game / wrong numbers / looks wrong / small), and the console errors and warnings from client and server. Plus a pacing check against PACING_REPORT.md (do real times match the sim?).

### T2 Bug fixes
Fix the T1 list, worst first, in batches (T2a, T2b...), a commit each. Each batch: re-run the exact repeat steps for its bugs plus a short loop check. Anything not fixed stays in the report with why.

### T3 Final check + the owner's playtest
A short replay of T1 parts 1-2, 5 and 8 on the finished game, zero console errors on join. Then finish `POLISH_V2_REPORT.md` with the one combined owner playtest (see "How this runs") and the launch list still left for the owner: 2X PINS pass ID, `MonetizationEnabled` (owner flips), thumbnail + icon, Save to Roblox, publish.

---

## Build order (all in this one run)

L0 → L1 → L2 → L3 → L4 → L5 → L6 → U1 → U2 → U3 → U4 → U5 → D1 → D2 → D3 → D4 → D5a-d → D6 → D7 → Q1 → Q2 → Q3 → T1 → T2 → T3

Why this order: looks first so animation is made once on the final look (same reason as the motion plan); U1 early because it's small and changes the HUD every later stage tests on; sound and speed after the things that make sound and cost frames; the bug hunt last so it tests the finished game, then fixes, then a final check.

If the run has to be cut short, these come first and must be finished: L0, L2, L3, L4, U1, U2, U3, D2, Q3, T1, T2, T3. Say in the report which stages were skipped.

## Prompt to start the run

> Read CLAUDE.md, PROJECT_STATE.md and POLISH_PLAN_V2.md. Run the whole polish plan in this one chat, stage by stage in the build order, testing each stage yourself and not waiting for me between stages. I've saved a restore copy to Roblox. Write POLISH_V2_REPORT.md as you go and give me the combined playtest at the end.
