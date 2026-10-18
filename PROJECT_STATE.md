# Project state (max 40 lines, read at the start of every session, update at the end)
Rules: STRIKE_LEGENDS_ADDENDUM_2.md > MASTER_PLAN.md > GAME_DESIGN.md (Addendum 2 replaces Addendum 1).

**Current milestone:** Phase 2 step 5 BUILT 2026-10-19, waiting for Selim's 2-minute test (Curve fix + collection book).
Restore point: git tag restore-phase2-step5-before + Studio "Save to Roblox As" "Before Phase 2 step 5". Real game = cloud place 94254609600041.
Next: Phase 2 step 6 (5 crate tiers, pity, odds screen, Polish Points), only when Selim says go.
**Weekly hour budget (optional):** not set yet. **Hours used this week:** 0.

## Exists and works
- 6 lanes, real physics pins (Standard/Golden/Golden Star meshes), lobby hub, kiosk, leaderboard wall, Vault (11 cases).
- New hold-and-release throw with a gold Perfect zone (jumps each throw, shrinks per strike). Only Perfects strike.
- Throw animation per ball level; strike juice (hit-stop, slow motion, number pops, payout pop, shake).
- 20-ball roster with real 3D models (light meshes, 51k triangles total), per-ball VFX and trails, 6 traits with effects.
- 10 ranks + rank trials, named streak tiers, Golden Pin, 4 lane modifiers, gems (earned only), daily reward, leaderboards.
- Saving (save v7, old saves migrate), rate limits, analytics, Config with every number, economy simulator (tools/EconomySim.luau).
- Server times the hold (ThrowHold + ThrowRequest(holdSeconds), Config.Throw.HoldTolerance 0.1s); throw rate limit 2s.
- Session log (server/Modules/SessionLog): printed in Output on leave, last 10 saved in SessionLog.
- Economy sheet: require(game.ServerStorage.Tools.EconomySim).Sheet(). Measured throw = about 3s (lane free 2.2s after release).
- Overcharge (Config.Throw.Overcharge, Enabled = true): red cap at the top of the arc (from 0.94); release there = 50% OVERCHARGE strike (x2 a Perfect, harder hit) or OVERCOOKED gutter (0 pins, streak over). Gold never enters the red.
- AssetSlots (Shared.AssetSlots): every sound slot; nil Id = borrows a stand-in sound. Strike slow motion 0.2s, hit-stop 0.05s (Addendum spec).
- Power Levels (save v8 PowerLevel; PowerLevelService + PowerUI button built in code): Config.Economy.PowerLevels live (sim units x10 = real coins). Power caps pins on non-PERFECT throws (LV1 = 6); PERFECT still strikes. Value multiplies coins. Looks per level: Config.Throw.Levels (size, power trail, sparks, fire, mega crash, aura, rainbow, deeper sounds, cleaner pose). Perfect now pays x2. Studio-only TEST +COINS button.
- First 3 minutes (OnboardingService/Controller, Config.Onboarding, save v9 Onboarding + OnboardThrows; old saves skip it): assisted first PERFECT (whole arc gold), BUY LV 2 callout, gift crate (Rare+, EQUIP button) after 35 throws, camera swing to a locked showcase ball 6 throws later, daily popup held until then. "Next goal" bar = closest of Power Level / gift / free crate. Studio: Config.Onboarding.StudioNewPlayer = true (fresh, unsaved player each test).
- Curve (Addendum 2 spec): Curve X% = PERFECT window X% wider (ThrowRules.HookWidth(ball, size)); magenta edges on the gold. Heavy and Forgiveness also widen the gold (reported to Selim).
- Collection book (CollectionBookController, built in code): BOOK button in the BALLS panel, one page per rarity, owned balls spin in 3D, missing = silhouette + traits.
## Placeholder
- All sounds (Creator Store picks); 3 overcharge sounds not picked (stand-ins). Crates: only Basic and Neon, old odds and pity.
- PowerUp sound (stand-in RankUp). Levels 5-12 unreachable without zones 2+ (Phase 3); use TEST button.

## Not built yet (from Addendum 2)
- 5 crates + Polish Points, 60 rank levels.
- Mascots, zones 2-6, bosses, rebirth, return loops, monetization (off switch).

## Parked
- Tournaments, ghost replays, spectator lanes, challenge lane. Master plan M11-M20 replaced by Addendum 2 phases.

## Off-git (saved only in the Studio place file)
- Map, UI, ball/pin/crate models. Selim must save the place after Studio work.

## Last session
- 2026-10-18/19: Addendum 2 kickoff, Phase 1 steps 1-4 passed. 2026-10-19: Phase 2 step 5 built (Curve + book), owner test pending.
