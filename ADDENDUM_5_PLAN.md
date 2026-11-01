# Addendum 5 overnight build plan (2026-11-01, owner asleep)

Owner's words: "finish everything you can in that addendum, each new step in a new chat, playtest each step with
screenshots and fix what is wrong, make everything very cool and very Roblox simulator like, you have full
permission, don't ask me any questions." So the addendum's "stop after each stage and wait for Selim" is waived for
this run only. Owner tests everything in the morning from ADDENDUM_5_REPORT.md.

## Answers to the addendum's open items (Claude's choice, owner can change in Config)
- Rebirth keeps pet slots: YES (config flag `KeepPetSlots = true`, the addendum's default).
- Pet stats: all four (Coins, Pins, Bag size, Throw speed). Each pet 1 or 2 stats.
- Egg tiers at launch: 4 (Neon Egg reused as tier 1, then 3 more using existing egg models: Main Street, Skyline,
  and one more existing egg model re-tinted/named). No new art.

## Steps (one session each, in this order; Studio is shared so never two at once)
0. AUDIT - write `AUDIT_ADDENDUM_5.md`: ball ladder, bag ladder, eggs + pets (models, ids, bonuses), rank/XP/level
   systems and every place they gate something, save fields, the 6 lanes + plots + PinRack physics, the HUD ball list
   (does it buy?), sell pad + SELL button, buy booth. Footprint plan for the one shared lane. No game changes.
1. A1 - pins are a number: counted pins decoupled from the 40 visual pins, no 40 cap, no full-clear x2, counter +
   pops use the big-number format (Currency), luck roll about +-20% with a LUCKY! pop on high rolls, steeper ball
   pins curve in Config. Remove level/XP/rank gating (hide XP bar, gates, rank requirements; keep code).
2. A2 - two independent ladders (balls + bags, own pacing in Config: balls 2 min x3, 5 min x5, then longer),
   ALL buying only at the buy station (HUD ball list display only: what exists + what's next), SELL button
   teleports the player to the sell pad and sells there.
3. A3 - one shared lane per map, throw spots spread across its width, personal local pin views, collision groups so
   balls never hit other players' balls/pins, other players' balls light or hidden, max one pin set simulated per
   client. Old lane assets kept (hidden / moved to storage), never deleted. Test with 2+ players (Studio
   multi-client test if possible, else a fake second thrower).
4. B1 - pet stats: Coins, Pins, Bag size, Throw speed; same-stat boosts add, total x rebirth multiplier; 3 slots,
   more slots bought with coins at the buy station; stat labels everywhere a pet shows.
5. B2 - egg ladder (4 eggs bought with coins at the buy station area, own pools, odds on every egg), pet inventory
   UI with EQUIP BEST + clear stat labels, Shiny merge (3 -> 1) reachable on the roof.
6. C - rebirth: coin price only (x~3 each), resets/keeps per addendum, permanent multiplier on coins + pins, tune
   (EconomySim) so rebirthed players recover in ~1/4 of the time and pass it, rebirth count on nameplate +
   leaderboard, visible cheap tier change per rebirth (lane/pin skin from existing assets).
7. D - ball effects: one distinct effect per ladder ball from existing models/VFX, intensity scales with pin count,
   no number changes.
8. E - pacing + logging: log time to each ball, each egg, rebirth 1 and 2, income before/after rebirth, readable
   by Selim (SessionLog print + DataStore/Analytics + a doc). Run EconomySim; report where pacing breaks and fix
   what is clearly broken.
9. F - simulator polish pass (see style notes) over everything new + one combined 2-minute morning playtest.

## Rules for every step session
- Read CLAUDE.md, PROJECT_STATE.md, STRIKE_LEGENDS_ADDENDUM_5.md, this file, AUDIT_ADDENDUM_5.md (after step 0),
  and the last sections of ADDENDUM_5_REPORT.md first.
- Git tag `restore-a5-<step>-before` before changing anything. Commit when done (attribution line).
- All numbers in Config. Never delete/rename save fields without a migration. Disable, don't delete.
- Prefer world changes built from code at runtime (like CoreLoopService builds the plaza): Claude cannot save the
  Studio place (computer-use was denied before), so Studio-only edits are lost unless the owner saves.
  List any Studio-only edit in the report.
- Sync: Rojo may not be running; use the http trick from memory (python http.server + UpdateSourceAsync).
- PLAYTEST: start Play in Studio, drive it (execute_luau on the client: teleport to the lane, fire throw remotes,
  give test coins through the TestPanel remote), take screen_capture screenshots, LOOK at them, fix what's wrong,
  repeat. Save the useful screenshots in `screenshots/addendum5/<step>/`. Check the Output for errors.
- Append a section to `ADDENDUM_5_REPORT.md`: what changed (plain English, short), restore tag, commit, a
  2-minute test with expected result + silent failures, choices made for the owner, placeholders.
- Update PROJECT_STATE.md (keep it short) and the memory file `addendum-5.md` (+ MEMORY.md line).
- If something blocks the step, do the safe part, write the blocker in the report, and finish.

## Simulator style notes (research + well-known front-page simulators: Pet Simulator 99, Bubble Gum Simulator,
## Ninja Legends, Muscle Legends, Bee Swarm, Arm Wrestle Simulator)
Keep the owner's approved look (sunny palette, SunKit, HudKit, Fredoka One + Builder Sans). Add simulator juice on top:
- Currency pills top/left with an icon, big bold number, thick dark text stroke (UIStroke 2-3 px), a green "+"
  that jumps to the store/buy station. Numbers tick up (count-up tween), never just snap.
- Left column of square icon buttons with a short label under each (PETS, SHOP, REBIRTH...), red badge dots when
  something is claimable/affordable. Bottom-center = main action. Keep clear of Roblox's top bar, the phone
  thumbstick (bottom-left) and jump button (bottom-right).
- Every button: UICorner, top-to-bottom UIGradient (lighter top), dark UIStroke, a darker "lip" under it,
  press = scale 0.92 then bounce back (Back easing), hover = 1.05.
- Text: chunky rounded font, white with a thick dark stroke, a dark copy offset 2-3 px down behind headline text.
- Popups bounce in (scale 0 -> 1.1 -> 1), close with a red X top-right, dim the screen behind.
- Rarity colours everywhere (Common grey, Uncommon green, Rare blue, Epic purple, Legendary gold/orange, Mythic
  pink/red rainbow gradient that rotates). Pet cards: rarity-coloured frame, pet viewport, stat line "x1.5 Coins",
  equipped tick, Shiny = rotating gradient + star.
- Gains: floating "+1.2M" numbers that fly from the hit to the counter, coin burst icons, small screen pulse on big
  gains, LUCKY! / x2 pops. Bag full = shaking red bag + SELL bouncing.
- Egg: odds board over the egg with every pet's chance, hatch = egg shake, crack, flash, pet reveal with rarity
  burst. EQUIP BEST and AUTO buttons.
- Rebirth: big gold button, "x2 -> x3" multiplier preview, confirm, full-screen flash moment.
- Everything readable on a phone (test 375 px wide).
