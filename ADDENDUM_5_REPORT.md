# Addendum 5 overnight report (2026-11-01/02, owner asleep)

One section per step (plan: ADDENDUM_5_PLAN.md). Each: what changed, restore tag, commit, 2-minute test, choices made for you.
At the end: one combined morning playtest.

## Step 0: audit (2026-11-01)
- No game changes. Wrote `AUDIT_ADDENDUM_5.md`: the ball and bag ladders, how buying, selling, pins, pets, levels and rebirth work today, the save fields (v34), and a plan for the one shared lane.
- Main findings: the BALLS button opens the shop with BUY buttons, and buying works from anywhere because the server never checks where you stand. The SELL button only shows a beam; it doesn't teleport you yet. Pins are capped at 40 and a full clear pays x2. Pets only boost coins, every egg is locked behind zones on the roof, and Shiny merge only works at the zone 3 machine, so you can't reach pets or merge from the roof. Rebirth is switched off while the core loop is on. Throw poses follow rank level, so if levels go away everyone would be stuck on the first pose.
- Shared lane plan: one 98-stud-wide lane in the same spot as the 6 old lanes, with 12 throw spots 8 studs apart. It gets built from code when the server starts and the old lanes are moved to ServerStorage. Each player only sees their own 40-pin rack, other players' balls are drawn light, and new collision groups stop pins hitting players.
- Nothing to test. Restore tag: none (nothing changed).
