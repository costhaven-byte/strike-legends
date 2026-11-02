# Animation polish plan (2026-11-02)

Goal: every animation in the game gets cooler, smoother and more real-feeling. **Built after the new designs (ASSET_PROMPTS_V2.md) are in the game**, so motion is made once, on the final art. One stage at a time, a restore point before each, a 2-minute test after.

## What's wrong with the motion now (measured in the code)

- Almost every UI motion is a tween with the same two curves: **Quad (163 uses) and Back "boing" (131)**, often at the same speeds. Pop-ups, toasts, buttons and rewards all move the same way, which reads as machine-made.
- Tweens can't be interrupted cleanly (tap a button fast and it can get stuck half-pressed). Only 1 spring in the whole game.
- Things appear all at once instead of one after another (no stagger).
- No anticipation (nothing winds up before it moves) and little follow-through (things stop dead).
- The throw pose is made in code by bending joints; it has no weight shift, no approach steps and no slide.
- The 40 ball effects are made from parts and particles that pop in at full size and vanish; big props (mesa, sphinx, crown, coconuts) drop without squash or impact dust.

## The rules every animation will follow

1. **One Motion module** (shared, client): springs for anything you touch (buttons, cards, counters, panels), tweens only for one-shot moments. Named presets so the whole game feels like one game: `Snap` (buttons, 0.08 s), `Pop` (small rewards, gentle overshoot), `Slam` (big moments, heavy overshoot + shake), `Float` (idle bob), `Drift` (soft fades).
2. **Anticipation → action → follow-through** on every big moment: shrink or pull back a little first, move fast, overshoot, settle.
3. **Stagger** lists and reward rows: 0.04-0.06 s between items (cards, prize tiles, coins).
4. **Weight by importance**: a toast moves 0.2 s; a Mythic hatch takes 4 s. Small things never shake the camera.
5. **Impact = freeze + shake + particles + sound together** (hit-stop 0.03-0.08 s by size).
6. **Squash and stretch** only on bouncy things (eggs, pets, coins, buttons 3-8%); balls and pins stay rigid (they're "real").
7. Everything respects SETTINGS (effects off / shake off) and keeps phones at 60 fps (particle caps, no per-frame welds, BulkMoveTo).

## Everything that animates today, and what it becomes

| # | Group (current systems) | Upgrade |
|---|---|---|
| 1 | **Throw** (ThrowPose, ThrowController, ThrowFx, power meter) | Real 4-step bowling approach: weight shift back, arm swing pendulum that follows the meter, slide on the last step, release with follow-through arm up, small hop on PERFECT. Meter: needle has spring lag, gold zone breathes, overcharge red shakes harder the deeper you go. |
| 2 | **Ball roll + lane** (LaneVisuals, BallFx, trails) | Ball spin matches its real speed (rolls, doesn't slide), slight hook curve, wobble on the first 0.2 s, lane boards reflect a glint that travels with the ball, trail thins as it fades, small dust/water/sand puffs where it lands per zone. Camera follows with soft lag, then eases to a pin-cam on big throws. |
| 3 | **Pins + strike** (pin physics, hit-stop, slow-mo, shake, number pops, ResultText) | Pins tumble with real mass (heavier bottoms, spin damping), fly in arcs not straight lines, clatter sound by impact speed. Strike: 0.05 s freeze, 0.2 s slow-mo, directional shake (toward the pins), chromatic flash ring, "STRIKE!" letters slam in one by one with stagger. |
| 4 | **40 ball signature effects** (BallSignature, zone 2-4 effects) | Each effect gets anticipation (a shadow or glow grows before the prop arrives), props scale from 0 with squash on landing, impact dust rings, debris that bounces and settles, then fades instead of vanishing. Uses the Z-kit props where they exist (sphinx, mesa, coconuts). |
| 5 | **Pins → bag → sell → coins** (CoreHudController fly chips, sell pop, counters) | Pin chips fly on curved paths with stagger into the bag; bag squashes on each catch; bag bar fills with a bump; full bag shakes and blinks. SELL: coins burst from the bag in an arc into the coin pill one by one (stagger), coin pill bumps per coin, number rolls digit by digit, "x23.5" chip slams in under it. |
| 6 | **Shop** (CoreShopController, buy reveal, BUY BEST, NEXT tag, silhouette spin) | Window opens from the stall's direction (not just a pop), cards stagger in, NEXT card breathes, buy = button squash → card flips → silhouette cracks white → colour floods → 3D ball spins up with a burst; bought cards settle with a small bounce. |
| 7 | **Rebirth** (hold button, REBIRTH! moment, RebirthController) | Hold fills with a rising glow + the screen edges pulling in; release = white-out, rank badge slams in with shockwave, reward tiles stagger, coins/balls "suck" out of the HUD into the badge (shows the reset), zone fade back to the roof. |
| 8 | **Eggs + hatch** (HatchScene, egg stand, odds board, auto hatch) | Egg wobbles idle on its stand; hatch: 3 shakes that speed up, cracks grow in stages, light leaks from the cracks in the rarity colour, rare+ adds a pause and a camera push-in, shell pieces fly with physics, pet springs out with squash and lands. Triple hatch: 3 eggs crack in sequence, rarest last. Auto hatch uses a faster short version. |
| 9 | **Pets** (MascotFollowController, PetIdle, reactions) | Pets follow with spring lag and banking on turns, walkers hop with squash on landing, flyers bob and tilt, they look at the ball while it rolls, cheer differently per rarity on a strike, and sleep (zzz) when you're AFK. Equip = pet pops out of a ring of sparkles beside you. |
| 10 | **Fusion** (fusion machine, PET FUSION window) | 3 pets get pulled into the machine one by one, the machine shakes and glows faster, lid pops, shiny pet floats down with a crown spin. |
| 11 | **Crates** (CrateKit reel/reveal, crate intro hops) | Reel slows with real friction and a final tick-over tease (only honest teases), reveal with rarity-scaled build-up. |
| 12 | **Gates + zones** (ZoneGateController, teleport, zone unlocked) | Gate barrier breaks apart / doors swing with weight, light pours through, camera flies through the arch into the new zone; teleport = quick swirl wipe instead of a cut. |
| 13 | **HUD buttons, windows, toasts, callouts** (HudKit, UiFx, MomentKit, RewardKit, Afford, Onboarding) | Spring presses on every button, windows scale from the button that opened them and close back into it, toasts slide + settle and stack, red dots pop, hint arrows bob on a curve, new-item glints sweep across. |
| 14 | **Rewards** (daily, gifts, spin wheel, achievements, away coins, playtime) | Day tiles flip when claimed, gift boxes wobble then lids pop, spin wheel has real momentum and a slowing tick with a pointer flick, reward icons fly into their HUD counter. |
| 15 | **Fever + lane events** (FeverController, EventController) | Fever: flames grow from the screen edges, music and lane pulse on the beat, banner flickers like fire. Events: golden rack rises with a shine, split pins spotlight, gem pin spins and glints. |
| 16 | **Camera + intro** (JoinIntro fly-over, loading screen, CameraShake) | Smoother camera curves (no linear moves), depth-of-field on moments, loading screen elements drift in with stagger. One shared shake with direction and falloff. |
| 17 | **Boss** (Pin Titan, if still used after Addendum 4-6) | Heavier wind-ups, plate breaks with debris physics, core opening with light leak. (Check first whether the boss is still in the live loop.) |

## Build order (after the designs are in)

- **AN1 Motion module + HUD/windows/buttons (13)**: the base everything else uses.
- **AN2 Core loop (1, 2, 3, 5)**: throw, roll, pins, bag, sell. The thing players do 1,000 times.
- **AN3 Shop + rebirth + gates (6, 7, 12)**.
- **AN4 Eggs, pets, fusion, crates (8, 9, 10, 11)**.
- **AN5 40 ball effects (4)**, one zone per session.
- **AN6 Rewards, fever/events, camera, boss (14, 15, 16, 17)**.

Each stage: restore point first, then a 2-minute test (computer + phone view) and a placeholder list, then wait for PASSED.
