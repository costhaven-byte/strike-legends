# First 5 Minutes Audit

## Why this exists

A competitor game (+1 Bowling Roll) got a tester hooked inside 3 minutes. Their opening gives a new reward roughly every 30 to 120 seconds, and the rewards come in several different kinds at once, so something is always about to pay off. Strike Legends playtests showed the opposite: fun for about 5 minutes, but few rewards beyond coins and XP.

This audit checks how our current build's first 5 minutes compares. It is a read-only audit. Do not change any game code or design docs while doing it.

## Target timeline for a brand new player

| Time since first spawn | What should have happened |
|---|---|
| 0:30 | First new ball unlocked or equipped |
| 2:00 | First crate or pet hatch opened |
| 2:00 | First permanent stat upgrade bought |
| 3:00 | First new lane, zone or tier reached |
| 5:00 | At least 8 distinct reward moments total, across at least 4 different reward types |

Reward types means things like: new ball, crate or pet, permanent stat upgrade, new lane or zone, rank-up, cosmetic, streak bonus, Golden Pin or trial moment.

## What to do

1. Read GAME_DESIGN.md, CLAUDE.md and the current milestone code for the new-player flow.
2. Trace what a brand new player does from first spawn, assuming they throw continuously and spend currency on the cheapest available upgrade each time.
3. Estimate, from the actual economy numbers in code (coin per throw, prices, XP thresholds, crate costs), at what time each target above would be hit. Show the arithmetic.
4. List every reward moment that happens in the first 5 minutes, with its estimated timestamp and reward type.
5. Check for dead stretches: any gap longer than 45 seconds with no reward, unlock or visible progress step.
6. Check whether the player can always see what they are saving for next (a visible next goal on screen).

## Report format

Keep it short and plain. No code talk beyond what is needed.

- A table: each target from the timeline, our estimated time, hit or miss
- The full list of first-5-minute reward moments with timestamps
- The 3 longest dead stretches
- The top 3 changes that would close the biggest gaps, each with a one-sentence reason and a rough size (small, medium, large)
- Anything in the economy numbers that looks inconsistent or that you had to guess

## Rules

- Do not edit any files except the report itself.
- If a number is not in the code, say so instead of inventing one.
- Do not suggest removing the pin and strike moment, the Perfect timing window, ball traits or lane modifiers. Those are what separate Strike Legends from the competitor. Fit the faster reward pacing around them.
- Save the report as FIRST_5_MINUTES_REPORT.md in the project root.
