# PHASE X PLAN: Zone Structure, Rarity Rebalance, Progression Hooks

Hand this to Claude Code. Build one part at a time, in order. Keep everything data-driven (config tables, not hardcoded values) so numbers can be tuned later without code changes.

## Goal

Fix three problems found in design review:
1. Zone 2 is boring between level 5 and level 12.
2. Zone 2 has too many balls (about 13) and too many pets (12 in one egg), so rarity feels diluted and the expensive crates feel useless.
3. Zones 3 and 4 are not implemented, and the rarity ceiling for each zone is not defined.

## Current state (as the designer describes it)

- Zone 1, Back Alley: trashy theme. Player throws, gets 1000 coins, buys a crate with a guaranteed uncommon ball, is prompted to equip it. Back Alley balls drop only here.
- Level 5: popup showing everything in zone 2, with a teleport button.
- Zone 2, neon theme: daily spin wheel, one pet egg (12 pets), three crates (bronze, silver, gold). Zone 2 balls drop only here, ranging common to mythic. Takes about 25+ minutes to reach level 12.
- Level 12: zone 3. Not implemented properly.
- Level 22: zone 4. Not implemented properly.
- Already built, do not break: playtime gift system, XP and coin potions, pets that give XP boosts alongside coin boosts.

## Level gates

- Zone 1 to 2: level 5 (existing)
- Zone 2 to 3: level 12
- Zone 3 to 4: level 22
Put these in one config table.

## Step 0: Audit (read only)

Before changing anything, inspect the project and write AUDIT_PHASE_X.md listing:
- Every ball: name, rarity, zone, theme, where it drops.
- Every pet and egg: name, rarity, which egg.
- Every crate: price, drop table.
- Where level gates and zone teleports are defined.
Then continue to Part 1 without waiting. Use the audit as the source of truth for the redistribution rules below.

## Part 1: Zone 2 progression hooks

Goal: give the 25 minutes between level 5 and 12 some beats, without adding a new system that needs heavy art.

1. **Level milestone rewards in zone 2.** At levels 7 and 9 (configurable), pay out a small reward (coins plus a crate or potion). Show a clear popup. These are in addition to the level 5 and 12 transitions.
2. **Short challenge.** Add a simple repeatable challenge in zone 2, for example "get 3 strikes in a row" for a free bronze crate. Show it in a small HUD tracker. Make the challenge definition data-driven so more can be added later.
3. **Next-reward preview (lowest priority, do last).** A small progress bar or locked icon in the HUD showing the next milestone reward. Skip if it complicates the HUD.

## Part 2: Rarity ceilings per zone

Rarity ceilings are the main rule of this phase:
- Zone 1: back alley balls only, low rarities (common and similar).
- Zone 2: uncommon to epic.
- Zone 3: rare to legendary.
- Zone 4: epic to mythic.

Future zones 5 to 7 will push higher, so define the rarity ladder in one config list (common, uncommon, rare, epic, legendary, mythic) built so new tiers above mythic can be added later without refactoring. Zone ranges, crate odds and case accents must all read from this list.

Zone 2 currently has common balls and pets. Those do not fit the new range. In the audit, list them. Re-rate each one up to uncommon, or move it to zone 1 if it fits that theme. Keep each item's actual power values unchanged when re-rating, so balance does not shift.

Apply this to both balls and pets. Put the rarity ranges in config.

## Part 3: Ball redistribution (do not delete any assets)

The zone 2 neon balls are being split. Use the audit.

- **Stay in zone 2:** the lowest-rarity neon balls plus the strongest few top-end neon balls. Target 8 to 9 balls total in zone 2.
- **Move to zone 4:** the remaining higher-rarity neon balls. Zone 4 is set in daylight, so neon looks do not fit. For now, create them as new zone 4 ball entries that reuse the existing models, with a placeholder color and effect (sunburst, cloud swirl, lightning, gold, crystal). Real re-skinning happens later in Claude Design.
- **Zone 3 (real-life bowling alley):** add placeholder entries for new classic-style balls (marble, swirl, league style). Target 6 to 8 balls. Models can reuse existing ones with plain materials until proper assets exist.
- **Zone rule stays:** each zone's balls drop only in that zone.
- Target total is about 6 to 9 balls per zone. Keep every removed or moved ball in the data so nothing is lost. Never delete a model or asset.

## Part 4: Crates

Make the three crate tiers differ by rarity floor, not just price. Starting values for zone 2 balls (tunable in config):

- **Bronze:** uncommon 75%, rare 25%. Cannot give epic.
- **Silver:** uncommon 35%, rare 55%, epic 10%.
- **Gold:** rare 70%, epic 30%. Cannot give uncommon.

Use the same structure for zone 3 (rare to legendary) and zone 4 (epic to mythic) crates, shifted up one rarity per zone: bronze gives the zone's two lowest rarities, silver the middle with a small shot at the top, gold the upper rarities with a real chance at the zone's top tier. If a rarity has no balls in that zone's pool, redistribute its weight to the nearest rarity rather than failing.

## Part 5: Pet eggs

- Cut the zone 2 egg from 12 pets down to 5 or 6. Keep the best-looking pet per rarity within zone 2's ceiling. Move the other pets to a holding list in data (for use in zone 3 and 4 eggs later). Do not delete them.
- Zone 3: add 1 to 2 eggs (placeholders are fine), pets within zone 3's ceiling.
- Zone 4: add 1 egg, pets within zone 4's ceiling, including mythic.
- Keep the Shiny merge (3 copies) working across all eggs.
- Keep pet XP and coin boosts working.

## Part 6: Zone 3 and zone 4 scaffolding

Build the structure now, keep the content light.

- **Zone 3:** fusion station where players fuse pets (use the existing fusion logic if it exists), 1 to 2 pet eggs, 2 crates, new balls and pets from Parts 3 and 5. Teleport popup at level 12 listing what the zone offers, same style as the level 5 popup.
- **Zone 4 (daytime rooftop):** normal bowling, plus a helicopter prompt that teleports the player to a boss arena, available every 45 minutes (cooldown shown in UI). Boss gameplay is not decided yet. Build a stub arena and a placeholder reward so the loop works end to end, and keep the boss logic isolated so it can be replaced.
- **Rebirth:** place the rebirth system in zone 4. If a rebirth system already exists in code, wire it to unlock at the zone 4 level. If it does not exist, create a minimal stub (reset level and progress, give a permanent multiplier) behind a flag, and keep it simple.
- One new system per zone: zone 2 has crates, egg and wheel, zone 3 has fusion, zone 4 has the boss and rebirth. Do not add more systems than this.

## Part 7: Display cases (balls and pets)

Zone 2 already has finished display cases for balls (rare to mythic) and the same design for pets. Rework them as a reusable, per-zone component.

1. **Zone 2 balls:** remove the legendary and mythic cases. Fill the cases with every ball that can drop in zone 2 (after Part 3). A ball the player has not unlocked shows dimmed out (dark silhouette material, no glow). Once owned, the case lights up normally.
2. **Zone 2 pets:** same behavior. After the egg is cut to 5 or 6 pets (Part 5), show only those pets in zone 2 cases, dimmed until owned. Do not delete the extra cases or models. Pets moved out of zone 2 go to zone 3 and 4 eggs, so their cases get reused there.
3. **Build the case set as one data-driven component.** Inputs: zone id, list of items, zone theme, and rarity accent. The zone 2 cases are color coded by rarity, so split each case design into two layers:
   - **Base structure** (frame, shape, details), which is the zone's look.
   - **Rarity accent** (trim, glow, lights, accent colors), which comes from a rarity color table shared by all zones.
   - **Rarity FX** (particle effects and stage lighting). Epic cases have particles. Legendary and mythic cases have particles and stage lighting. Build these as reusable FX presets keyed by rarity, attached to whatever base case is used, so they work in any zone and for any future rarity tier.
   Inspect the existing zone 2 cases and extract the rarity coding into the accent and FX layers. If a rarity only changes accent colors and FX, one base design per zone covers every rarity. If a rarity changes the structure itself (different shapes or extra pieces), note which ones in the report so a separate variant can be designed for those rarities only.
4. **Placeholder first, final art later.**
   - Placeholder (build now): zone 3 and zone 4 cases reuse the zone 2 base structure with a different theme (zone 3: wood, chrome, warm lighting; zone 4: clean, bright, sky tones) plus the rarity accent colors. Done with materials and colors in code or Studio. Do not generate new art assets.
   - Final (designer does later in Claude Design): one hero case design per zone at the same quality as zone 2, built to the base plus rarity accent split above. When that design arrives, swap it in for the placeholder base without changing any item or ownership logic. Zone 3 needs rarity accents and FX for rare to legendary, zone 4 for epic to mythic.
5. **Do this part last**, after Parts 1 to 6 are working. The cases are presentation only and must not block gameplay work.
6. Ownership state (owned or not owned) must read from the player's real inventory data so the dimmed state updates immediately on unlock.

## Part 8: Big numbers and rarity power curve

**Order note: do Part 8A right after Step 0, before Part 1.** It is numbered last, but the other parts touch the economy, so build the foundation first.

The game is meant to reach the billions, trillions, quadrillions and beyond. Roblox numbers are doubles, which stop being exact at about 9 quadrillion (9e15). Retrofitting this later would touch every system, so set it up now.

### 8A: Number foundation

1. **Shared number formatter.** One utility used everywhere a number is shown on screen (coins, prices, rewards, boosts, leaderboards, popups). Short suffix format: K, M, B, T, Qa, Qi, Sx, Sp, Oc, No, Dc, and so on. Keep the suffix list in config so more can be added. Show 1 to 2 decimals, trim trailing zeros.
2. **One economy module.** All coin and currency math (add, subtract, multiply by boosts, compare, price checks) goes through a single module. Other systems must not do raw arithmetic on currency. This lets the number representation be swapped later (for example to a mantissa and exponent format) without touching other systems.
3. **Precision guard.** For now values can stay as regular numbers inside the module. Add a clear guard and a logged warning if a value approaches 9e15, so it is caught before it causes bugs.
4. **Save and load.** Make sure currency saves and loads through the same module, so a future change in representation can include a safe data migration.
5. Replace existing raw currency math and display code with the module and formatter. List any places that could not be converted in the report.

### 8B: Rarity power curve

1. Extend the rarity ladder config with reserved names for future tiers above mythic: Cosmic, Celestial, Eternal. Do not build content or art for them now. They are names in the config only.
2. In the audit, record the current power value (ball power, pet coin boost, pet XP boost) for each existing rarity.
3. Define power per rarity as a config table, not as values scattered across items. Derive the growth ratio between existing rarities from the audit, and use that same ratio as the default step for each new tier. Items can still have small individual variation within a rarity.
4. Report the resulting table (power by rarity, including the reserved tiers) in PHASE_X_REPORT.md so the designer can tune it.

## Rules for Claude Code

- Part 8A is done first, right after the audit.
- Work one part at a time. After each part, make sure the game still runs before moving on.
- Everything numeric (odds, level gates, cooldowns, rewards) goes in config tables.
- Do not delete existing assets, balls, pets or models. Move them or mark them.
- Do not touch the playtime gift system, potions, or existing pet boosts except to keep them working.
- Anything undecided (boss gameplay, final zone 3 and 4 art, final rebirth numbers) gets a clearly marked placeholder, not an invented design.

## Final report

When done, write a short PHASE_X_REPORT.md with: what was built, what was moved where (balls and pets per zone with counts), the final crate odds, and a list of placeholders that still need real art or design decisions.
