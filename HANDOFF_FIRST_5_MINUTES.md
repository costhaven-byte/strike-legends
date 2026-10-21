# Handoff: First 5 Minutes Fixes (Phase 1)

Read GAME_DESIGN.md, CLAUDE.md and FIRST_5_MINUTES_REPORT.md first. This handoff implements changes 1 and 2 from that report, plus Perfect-rate logging. Do not touch Power Level 3 or 4 pricing or what they unlock. That is a later decision.

Build this as one milestone. Keep the changes small and mostly Config-level. Do not refactor anything outside what is listed.

## Task 1: Make the first rank-up reliable

Problem: the first Rank Trial needs 2 strikes in 6 throws, and about 78% of new players fail it, then wait out a 60 second cooldown.

Do this:
- First rank trial (Amateur) needs 1 strike instead of 2. Keep the 6 throw window.
- Remove the 60 second cooldown after a failed trial for the first two ranks only. Later ranks keep their current cooldown.
- Keep the trial feeling like a moment: same UI, same rank-up reward, same sounds and effects.
- Update the stale comment in Config.Ranks that says the first rank-up comes "after ~1-2 minutes" so it matches reality.

## Task 2: Bring the first new ball forward and point the player at the kiosk

Problem: the first new ball arrives at 1:45 or later on the path the HUD steers players toward, and nothing points at the Basic crate (1,600 coins), which is the most exciting early buy.

Do this:
- Move the free gift crate from 35 throws to about 10 throws, so it lands around 0:30 to 0:45. It keeps the guaranteed Rare behavior for the first crate ever.
- Add the Basic crate (1,600) as a possible target on the "next goal" HUD bar, with its price shown. The bar should still pick the goal with the highest progress, but the Basic crate must be eligible until the player has bought their first crate.
- When the Basic crate is the current goal, give the player a clear way to find the kiosk (a simple arrow or beam is enough, reuse an existing guidance effect if there is one).
- Make sure the gift crate and the first bought crate do not both guarantee a Rare in a way that makes the second one feel worthless. If they do, report it and propose a fix instead of changing it silently.

## Task 3: Log the real Perfect rate

The report's numbers depend on a guessed 15% Perfect rate. Replace the guess with data.

Do this:
- Log, per session and per player, total throws and total Perfect throws, using the existing SessionLog or analytics setup.
- Also log, for the first 5 minutes of a new player's first session only: the timestamp of each reward moment (ball unlocked, crate opened, stat upgrade bought, rank-up, free crate, Golden Pin hit).
- Add a short debug command or output that prints the current session's Perfect rate and the first-5-minutes timeline, so it can be read after a playtest without digging through logs.

## Rules

- Do not remove or weaken the pin and strike moment, the Perfect timing window, ball traits or lane modifiers.
- Do not change monetization, gem sinks or the daily reward.
- If a number you need is not in the code, say so instead of guessing.
- Run EconomySim after the changes if it covers any of the numbers you touched, and say what it showed. If it cannot cover them (the report says it uses a different rank system), say that instead.

## When done, report back in plain language

- What changed, file by file, in one line each
- The new estimated timeline for the first 5 minutes, using the same targets table as the report, with the assumptions stated
- Anything you changed that was not listed here, and why
- Anything that looked wrong or inconsistent that you left alone
- Exactly how to read the Perfect rate and the first-5-minutes timeline after a playtest
