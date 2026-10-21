# First 5 Minutes Report (2026-10-19)

Read-only audit of the current build (git 459909e). All numbers are from `src/shared/Config` and the server code unless marked **GUESS**.

## Bottom line

The first 2:30 is in decent shape (the scripted onboarding does its job). After about 2:30 the game goes quiet: the next Power Level costs 9 times the last one, the first rank-up hides behind a trial that most new players fail, and the free strike crate takes about 15 strikes. We hit 2 of the 5 targets cleanly, and we reach 8 reward moments only if Golden Pins and lucky streaks happen to land.

## Targets

| Target | Our estimate | Result |
|---|---|---|
| 0:30 first new ball | 1:05 if the player walks to the kiosk and buys a Basic crate. 1:45 to 2:05 (the gift crate) if they stay on the lane, which is what the HUD steers them to | **MISS** |
| 2:00 first crate opened | 1:05 (bought) or 1:45 to 2:05 (gift) | **HIT** (only just, on the lane-only path) |
| 2:00 first permanent stat upgrade | 0:12 to 0:15 (Power Level 2) | **HIT** |
| 3:00 new lane, zone or tier | Zones aren't built yet (Phase 3), and all 6 lanes are the same zone. The only "tier" is the first rank-up: median about 4:30 | **MISS** |
| 5:00 at least 8 moments across at least 4 types | 7 sure moments (8 if the rank-up lands in time) plus about 4 to 6 random ones (Golden Pins, streaks). Plenty of types | **BORDERLINE**: hit on average, missed by an unlucky player |

## The arithmetic

**Assumptions**
- 3 seconds per throw (`Config.Economy.Sim.ThrowSeconds`, measured in Studio).
- **GUESS:** 15% of throws are Perfect. This is the simulator's number (`Sim.PerfectShare`); the live game has no measured rate. Almost every result below depends on it.
- **GUESS:** a missed Perfect knocks about 5 pins at Level 1 and about 7 from Level 2. The code gives 3 + (most pins − 3) × bar fill, ±1, and I assumed the player lets go around 70% fill.
- **GUESS:** 10 seconds to walk to the crate kiosk and 10 seconds back. Not in the code.

**Coins per throw** (pins × 10 × Power Level value × ball multiplier; a Perfect is 10 pins × 2)
- Level 1, Rookie ball: miss = 5 × 10 = 50, Perfect = 10 × 10 × 2 = 200. Average = 0.85 × 50 + 0.15 × 200 = **about 73**.
- Level 2 (value 1.25): miss = 7 × 10 × 1.25 = 88, Perfect = 250. Average **about 112**.
- Level 2 with a Rare ball (average multiplier 2.1): **about 238**.
- Level 3 (value 1.5) with a Rare ball: miss = 223, Perfect = 638. Average **about 285**.

**XP per throw**: a miss = pins × 1.5, a Perfect = 30. Average is about 11 at Level 1 and about 13 from Level 2. The first rank (Amateur) needs 300 XP: 30 (first throw) + 4 × 11 + 17 × 13 ≈ 300, so the **XP bar fills around throw 22 (about 1:10 to 1:20)**.

**The first Rank Trial**: 2 strikes within 6 throws. Only Perfects strike, so at 15% the chance of passing one try is 1 − (0.85⁶ + 6 × 0.15 × 0.85⁵) ≈ **22%**. A failed try costs about 18 seconds plus a 60-second cooldown. That puts the median at 3 tries, so the **rank-up lands around 4:30**, anywhere from about 1:30 to beyond 6:30. At a 30% Perfect rate the pass chance rises to 58% and the rank-up comes around 2:00.

**Power Level prices**: Level 2 costs 400, about 3 throws after the first throw's 200 coins. Level 3 costs 3,000. **Level 4 costs 27,000**, about 95 throws (4:45) after Level 3. That puts it near 8:30, or 6:40 on the lane-only path.

**Free strike crate**: 15 strikes. The assisted first throw counts as 1, and the other 14 at 15% take about 93 throws, so it comes **around 4:45 to 5:00**.

**Golden Pin**: a 1 in 15 chance per rack. It pays when its pin falls, which is about 75% of throws (every strike, and about 7 of 10 pins otherwise). That's about 5% of throws, so **roughly one every 60 seconds, at random**.

## Reward moments in the first 5 minutes

The audit's path (buy the cheapest upgrade each time, walk to the kiosk):

| Time | Moment | Type |
|---|---|---|
| 0:03 | Assisted first throw: PERFECT strike, +200 coins | Strike moment (scripted) |
| 0:15 | Buy Power Level 2 (400), and the ball looks different | Stat upgrade |
| 1:05 | Basic crate (1,600) at the kiosk, guaranteed Rare (first crate ever) | Crate + new ball |
| ~1:20 | XP bar full, Rank Trial unlocked | Progress step (not a reward) |
| 1:53 | Power Level 3 (3,000), sparks | Stat upgrade |
| 2:08 | Gift crate after 35 throws, guaranteed Rare (a 1 in 4 chance it's a duplicate, which becomes Polish +5% instead) | Crate + new ball |
| 2:26 | Camera swings to a locked showcase ball | Chase (not a reward) |
| 2:30 | Daily unlocks: day 1 = 250 coins | Daily reward |
| 3:45 | Bronze crate (9,200), usually a ball weaker than the one equipped (only a 20% chance of Rare or better) | Crate |
| ~4:30 | Rank-up to Amateur (median): coins ×1.25, 5 gems | Rank-up |
| ~5:00 | Free crate from 15 strikes (just inside or just outside) | Crate |
| random | About 4 to 5 Golden Pin hits (×5 coins, 30% chance of 2 gems, 10% chance of a free crate) | Golden Pin |
| random | About 1 to 2 DOUBLE streaks (2 Perfects in a row: about 2% of throws) | Streak bonus |

The lane-only path (the player follows the "next goal" bar and never visits the kiosk): 0:03 assisted strike, 0:12 Level 2, 1:33 Level 3, 1:45 gift crate (**first new ball**), 2:03 showcase pan, 2:10 daily 250 coins, about 4:00 rank-up (median), about 4:45 free crate, plus the random Golden Pins. That's 7 moments, so it misses the 8 target unless luck helps.

## The 3 longest dead stretches (no reward or unlock)

1. **After Level 3 (about 2:30 to 4:30, and past 5:00 there's a wall).** The only sure things left are the rank-up, which most new players fail at first, and the free crate at about 5:00. Level 4 sits 4 to 7 minutes away. On the lane-only path this gap runs about 110 seconds.
2. **Level 2 to Level 3 on the lane-only path (0:12 to 1:33, 81 seconds).** Coins only tick up. On the kiosk path the gap shrinks to about 50 seconds (0:15 to 1:05), which is still over 45.
3. **The daily reward to the Bronze crate on the kiosk path (2:30 to 3:45, 75 seconds).** And the Bronze ball is usually worse than the one equipped, so it feels like a non-reward.

Random Golden Pins (about one a minute) often break these gaps up, but nothing guarantees it.

## Can the player always see the next goal?

**Mostly yes, but the goal is often far away or the wrong one.**
- The "next goal" bar always shows one of three things: the next Power Level, the gift crate, or the free crate. It picks whichever has the highest progress.
- It never shows a crate price. The Basic crate (1,600) is cheaper than Level 3 and is the most exciting buy in the first 2 minutes, but nothing points at the kiosk.
- After about 2:00 both goals on the bar are far away (Level 4 is about 5 minutes off, the free crate about 3), so the bar barely moves.
- The showcase pan shows a locked Rare+ ball but not how to get one (Basic and Bronze crates can roll Rare, but nothing says so at that moment).
- The rank trial has its own HUD rank bar, so that part is visible.

## Top 3 changes

1. **Make the first rank-up reliable (small).** Reason: it's the only "tier" we can offer before 3:00, and today about 78% of first tries fail with a 60-second cooldown. Options include a 1-strike first trial, an assisted first Perfect inside the trial, or no 60-second cooldown for the first two ranks. These are Config numbers only.
2. **Bring the first new ball forward and point at the kiosk (small to medium).** Reason: the 0:30 ball target and the 0:12 to 1:33 gap are both caused by the first ball arriving at 1:45 or later. Move the gift crate to about 10 throws (0:30), then add the Basic crate (1,600) to the "next goal" bar so the first bought crate lands around 1:30 to 2:00.
3. **Close the Level 3 to Level 4 wall (medium, re-check with EconomySim).** Reason: Level 4 costs 9 times Level 3 and adds no pins (see below), so 2:30 to 5:00 has nothing to buy. Lower Level 4 to about 9,000 to 10,000. Also make the first free strike crate cheaper (for example 6 to 8 strikes instead of 15) so a free crate lands around 2:30 to 3:00.

None of these touch the pin and strike moment, the Perfect window, ball traits or lane modifiers.

## Inconsistencies and guesses

- **Power Levels 3 and 4 add no pins in Starter Alley.** A missed Perfect is capped at 9 pins, and that cap is already reached at Level 2 (Power 10). So Level 3 (Power 16) and Level 4 (Power 30) only raise the coin value (1.25 → 1.5 → 2) and the looks.
- **First rank-up timing doesn't match its own comment.** `Config.Ranks` says the first rank-up comes "after ~1-2 minutes". That's true for the XP, but the trial pushes the actual rank-up to about 4 to 5 minutes.
- **Two rank systems.** The live game uses `Config.Ranks` (10 ranks, trials). The simulator's `Economy.Ranks` (60 ranks, no trials) and `Economy.Timeline` ("Rank 3 at 4-5 min", "Zone 2 at rank 5, 8-10 min") describe ranks that aren't live yet. So EconomySim can't check the live first-5-minutes ranking.
- **The cheapest-upgrade rule loops on Basic crates.** A Basic crate (1,600) is always cheaper than Level 3 (3,000). I treated a crate as an upgrade only while it can beat the equipped ball.
- **Not in the code:** the live Perfect rate, where players usually let go when they miss, and the walk time to the kiosk. All three are guesses above. A session log from a real new player (SessionLog, analytics) would replace them.
- **Gems pile up with nothing to spend them on yet** (rank-up gems, Perfect drops, Golden Pin gems), so they read as a weak reward in the first 5 minutes. The gem sink is already on the Not Built list.
- **The day 7 daily gives a Neon crate** (a 5.9 billion coin crate, 4% Mythic). Not part of the first 5 minutes, but worth checking that this is intended.
