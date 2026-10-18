# Project state (max 40 lines, read at the start of every session, update at the end)

Rules: STRIKE_LEGENDS_ADDENDUM_2.md > MASTER_PLAN.md > GAME_DESIGN.md (Addendum 2 replaces Addendum 1).

**Current milestone:** Phase 1 step 1 (Foundation close-out), APPROVED by Selim 2026-10-18, not started yet.
Scope: restore point first; server times the hold (client sends hold-start/release only, server clamps + rate limits from the measured cycle); simple session log (join, leave, throws, crates, level); measure real throw time in Studio; economy sheet (short table of time per upgrade) re-run with the new throw. Then a 2-minute test for Selim.
**Weekly hour budget (optional):** not set yet. **Hours used this week:** 0.

## Exists and works
- 6 lanes, real physics pins (Standard/Golden/Golden Star meshes), lobby hub, kiosk, leaderboard wall, Vault (11 cases).
- New hold-and-release throw with a gold Perfect zone (jumps each throw, shrinks per strike). Only Perfects strike.
- Throw animation per ball level; strike juice (hit-stop, slow motion, number pops, payout pop, shake).
- 20-ball roster with real 3D models (light meshes, 51k triangles total), per-ball VFX and trails, 6 traits with effects.
- 10 ranks + rank trials, named streak tiers, Golden Pin, 4 lane modifiers, gems (earned only), daily reward, leaderboards.
- Saving (save v6, old saves migrate), rate limits, analytics, Config with every number, economy simulator (tools/EconomySim.luau).

## Placeholder
- All sounds (Creator Store picks). Crates: only Basic and Neon, old odds and pity.
- Ball "level" comes from rarity until real Power Levels exist.

## Not built yet (from Addendum 2)
- Server-timed hold (today the client sends how full the bar was), overcharge flag, assisted first throw.
- Session log + economy sheet re-run with the new throw. AssetSlots module.
- Power Levels, first 3 minutes script, 5 crates + Polish Points + collection book, 60 rank levels.
- Mascots, zones 2-6, bosses, rebirth, return loops, monetization (off switch).

## Parked
- Tournaments, ghost replays, spectator lanes, challenge lane. Master plan M11-M20 replaced by Addendum 2 phases.

## Off-git (saved only in the Studio place file)
- Map, UI, ball/pin/crate models. Selim must save the place after Studio work.

## Last session
- 2026-10-18: read Addendum 2, checked the throw against it, ran the policy check, made this file.
