# Project: Strike Legends (working title), a Roblox bowling simulator

Full design is in GAME_DESIGN.md. Read it before starting any milestone or making any design decision.

Quick rules:
- Build one milestone at a time (see section 9 of GAME_DESIGN.md). Test in Studio play mode after each, then wait for confirmation.
- Server is authoritative for coins, XP, pins, drops and saving. Clients only send inputs and UI requests.
- All tunable numbers live in one Config module. Balls, ranks, worlds and crates are data tables.
- Stay inside the v1 scope. Do not add pets, trading, extra worlds, or purchases yet.
- The owner does not write code. Keep explanations short and in plain language.
- If the design conflicts with how Roblox works, say so and propose a fix.
