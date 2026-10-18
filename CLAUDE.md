# Project: Strike Legends (working title), a Roblox bowling simulator

Full design is in GAME_DESIGN.md. From Milestone 10 on, MASTER_PLAN.md is the roadmap: it turns the game into a simulator (milestones 10 to 20). Read both before starting any milestone or making any design decision. STRIKE_LEGENDS_ADDENDUM_1.md corrects the plan (Power Levels instead of a ball shop, the 20-ball roster stays, crate odds, ranks as levels inside the 10 tiers, gems kept). Order of authority: addendum, then MASTER_PLAN.md, then GAME_DESIGN.md.

Quick rules:
- Build one milestone at a time (see section 4 of MASTER_PLAN.md). Test in Studio play mode after each, then wait for confirmation.
- Server is authoritative for coins, XP, pins, drops and saving. Clients only send inputs and UI requests.
- All tunable numbers live in one Config module (src/shared/Config). Balls, ranks, zones, crates and mascots are data tables. Config.Economy holds the plan's economy; check changes with the simulator (tools/EconomySim.luau).
- Extend systems that work; don't rewrite or delete them without asking first.
- Never delete or rename saved data fields without a migration that keeps old saves working.
- No monetization, trading or gifting. Only add what MASTER_PLAN.md lists.
- The owner does not write code. Keep explanations short and in plain language.
- If the design conflicts with how Roblox works, say so and propose a fix.
