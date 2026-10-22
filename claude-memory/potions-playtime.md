---
name: potions-playtime
description: "Owner's 2026-10-22 request — potions (built edfbc27) then playtime rewards; owner's exact answers on reset, egg timing, gold crate"
metadata:
  node_type: memory
  type: project
  originSessionId: 6d02903a-b5d7-4409-99fd-adddc0cf4eb7
  modified: 2026-10-21T23:37:41.339Z
---

2026-10-22 the owner asked for two new things (not in Addendum 2; owner's call): playtime rewards and coin/XP potions. Split into two milestones.

1. Potions: built + committed edfbc27 (tag restore-potions-before), test PENDING. Coin/XP potions, small x2 (common) and MEGA x4 (rarer), both 15 min. The owner also said "with the xp multiplier increases, add them to pets too", so pets now boost XP by the same amount as coins (ThrowService getXpMultipliers). Sim: zone 4 at 55 min instead of 1h46.
2. Playtime rewards (next, after potions pass): every 15 min up to 3 h (12 rewards), RESETS EVERY VISIT (owner's choice, not daily). Rewards are potions, a pet egg and guaranteed crates. The egg comes at the 30-minute reward (owner says zone 2 is surely open by then). The final reward is exactly a Gold Crate, with no zone downgrade (owner: players are in zone 3 by 3 h). Also RAISE the Neon Egg price (3,700 is "too cheap"); no number was given, so propose one and check it with the sim.

**Why:** the owner chose these in an AskUserQuestion on 2026-10-22.
**How to apply:** build step 2 only after the owner passes step 1. Related: [[addendum-2]], [[feedback-literal-specs]], [[zones-plan]].

2026-10-22 later: step 2 BUILT adeb2a2 (tag restore-playtime-before, test PENDING). Owner set prices: Alley Crate 15K, Bronze 75K, Silver 750K, Gold 65M, Neon Egg 50K (final 2026-10-22; playtime + first-crate discount PASSED) ("too easy to get"). Egg gift = saved FreeEggs (v16), hatched free at the stand. First Alley Crate still 1,000 (onboarding).

2026-10-22 (later): owner asked for a HUD move + daily overhaul + daily spin, split into 3 milestones. A) HUD move BUILT e583961 (tag restore-hud-move-before, test PENDING): potions = ITEMS tab in PETS panel, DAILY top-right (Roblox player list hidden, Config.Ui.HidePlayerList), potion timers bottom-left as bottles. B) next: daily rewards much more valuable (owner examples: D1 15K coins, D2 3x x2 potions, D3 500K) - Claude picks the rest with the sim. C) after: walkable daily spin wheel in zone 2 (empty space behind the lanes): potions, crates, eggs, 0.5% legendary ball labelled "SECRET BALL", 1% legendary pet labelled "SECRET PET".
2026-10-22: HUD move PASSED; then owner: GIFTS to top-right, DAILY back in the row; TAKE ME THERE lands on the lobby spawn circle (Hub.SpawnPad). Big dailies built (test pending, tag restore-dailies-before): owner's numbers kept as the minimum, coin days also pay a share of the next Power Level (fixed coins become worthless within an hour: sim income 4K/min at 4 min, 2.5B/min at 60 min). Next: daily spin wheel.
2026-10-22: daily spin wheel BUILT 79add4d (tag restore-spin-before), PASSED. Placed at the far end of the EAST walkway beside the zone 2 lanes (owner said "behind the lanes" but the back wall is right behind the pins). Built in code (SpinController), 1 free spin/day, save v17 SpinDay. Big dailies test was still pending when owner said "do the spin".
