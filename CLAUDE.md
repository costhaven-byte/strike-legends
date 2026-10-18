# Project: Strike Legends (working title), a Roblox bowling simulator

Full design is in GAME_DESIGN.md. MASTER_PLAN.md is the simulator roadmap. STRIKE_LEGENDS_ADDENDUM_2.md (2026-10-18) replaces Addendum 1 and sets the build order (phases 1 to 5, importance first), the new throw spec, verification rules and monetization behind an off switch. Order of authority: Addendum 2, then MASTER_PLAN.md, then GAME_DESIGN.md. Read PROJECT_STATE.md at the start of every session and update it at the end (max 40 lines).

**Current focus (2026-10-18):** Addendum 2 replaces master plan milestones 11 to 20 with its phases. Do not start a phase step until the owner says so. The Throw Lab (`throwlab/`, `rojo build throwlab.project.json -o ThrowLab.rbxl`) stays as a test place.

Quick rules:
- Build one small milestone at a time. Before each: tell the owner how to save a named restore point. After each: a plain-English test of 2 minutes or less (expected result + common silent failures) and a "Placeholders still in use" list; wait for the owner to say it passed.
- Server is authoritative for coins, XP, pins, drops and saving. Clients only send inputs and UI requests.
- All tunable numbers live in one Config module (src/shared/Config). Balls, ranks, zones, crates and mascots are data tables. Config.Economy holds the plan's economy; check changes with the simulator (tools/EconomySim.luau).
- Extend systems that work; don't rewrite or delete them without asking first.
- Never delete or rename saved data fields without a migration that keeps old saves working.
- No trading or gifting. Monetization only as Addendum 2 section 7 says, behind `MonetizationEnabled = false` (the owner flips it). Only add what the addendum and plan list.
- The owner does not write code. Keep explanations short and in plain language.
- If the design conflicts with how Roblox works, say so and propose a fix.
