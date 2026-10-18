# Project state (max 40 lines, read at the start of every session, update at the end)

Rules: STRIKE_LEGENDS_ADDENDUM_2.md > MASTER_PLAN.md > GAME_DESIGN.md (Addendum 2 replaces Addendum 1).

**Current milestone:** Phase 1 step 1 (Foundation close-out) DONE 2026-10-18, Selim's 2-minute test passed (4 throws logged as 4).
Restore point: cloud copy place 93792316689717 + git tag restore-phase1-step1. Real game = cloud place 94254609600041 (NOT Strike Legends.rbxl, that file is from Oct 14).
Next after it passes: Phase 1 step 2 (throw juice + overcharge flag), only when Selim says go.
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

## Placeholder
- All sounds (Creator Store picks). Crates: only Basic and Neon, old odds and pity.
- Ball "level" comes from rarity until real Power Levels exist.

## Not built yet (from Addendum 2)
- Overcharge flag, assisted first throw. AssetSlots module.
- Economy tuning for the first 3 minutes: sheet says Level 2 after 26 throws (1:18); Addendum wants about 6 throws.
- Power Levels, first 3 minutes script, 5 crates + Polish Points + collection book, 60 rank levels.
- Mascots, zones 2-6, bosses, rebirth, return loops, monetization (off switch).

## Parked
- Tournaments, ghost replays, spectator lanes, challenge lane. Master plan M11-M20 replaced by Addendum 2 phases.

## Off-git (saved only in the Studio place file)
- Map, UI, ball/pin/crate models. Selim must save the place after Studio work.

## Last session
- 2026-10-18: read Addendum 2, checked the throw against it, ran the policy check, made this file.
- 2026-10-18: built Phase 1 step 1 (server-timed hold, session log, measured throw time, economy sheet). Test passed.
