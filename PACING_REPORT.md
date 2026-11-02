# Pacing report (Addendum 6 Stage 9, 2026-11-02)

A pretend playthrough of the whole game (zones 1 to 4, gates, eggs, pets, rebirths), worked out by the pacing
simulator, not played in real time. It reads the real numbers straight from the game's config. Re-run it any time
with `python tools/pacing_sim.py stage9` (about a minute).

**The pretend player:** brand new, no game passes, no potions, no friends. They always buy the cheapest useful thing
next (next ball, next bag, gate, pet slot, or an egg), hatch each zone's egg 3 times a run, keep their best pets out,
and rebirth the moment a rebirth is the next thing to buy. A sell trip counts as 6 seconds. Pet luck changes the
times, so every number is the middle result of 9 different pet-luck runs (the range is shown where it helps).

"Run" = how many rebirths the player has done by then (run 0 = before the first rebirth).
"New-ball gap" = minutes from the last time the player got a ball they'd never had, to the next one (after a
rebirth, counted from the moment they are back at their best ball). This is the number that says whether a zone
"feels like zone 1".

## The tables (after the Stage 9 changes)

**Zone 1, Skyline Rooftop** (unchanged, all in run 0)

| | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Ball at | start | 0:13 | 2:12 | 6:51 | 8:27 | 12:06 | 15:47 | 18:14 | 19:14 | 21:06 |
| Bag at | start | 1:01 | 3:12 | 7:30 | 10:47 | 13:10 | 17:51 | 18:37 | 20:01 | 22:21 |
| New-ball gap (min) | - | 0.2 | 2.0 | 4.6 | 1.6 | 3.6 | 3.7 | 2.5 | 1.0 | 1.8 |

(Balls 8-10 come fast because the zone 2 gate opens at 17:15 and pins sell for 6x there.)

**Zone 2, Sunset Boardwalk** (ball 1 in run 0, balls 2-7 in run 1, balls 8-10 in run 2)

| | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Ball at | 27:56 | 43:04 | 45:20 | 49:29 | 51:04 | 54:13 | 57:39 | 1:16 | 1:17 | 1:19 |
| Bag at | 30:26 | 44:07 | 46:16 | 50:09 | 52:11 | 55:54 | 59:52 | 1:16 | 1:18 | 1:20 |
| New-ball gap (min) | 6.8 | 2.0 | 2.1 | 4.4 | 2.1 | 4.1 | 4.5 | 2.2 | 1.7 | 1.9 |

**Zone 3, Jungle Falls** (balls 1-2 in run 2, balls 3-10 in run 3)

| | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Ball at | 1:22 | 1:25 | 1:46 | 1:48 | 1:53 | 1:56 | 2:01 | 2:04 | 2:06 | 2:08 |
| Bag at | 1:23 | 1:26 | 1:47 | 1:49 | 1:54 | 1:58 | 2:03 | 2:05 | 2:06 | 2:09 |
| New-ball gap (min) | 2.7 | 3.0 | 2.2 | 2.5 | 4.2 | 3.5 | 4.3 | 2.9 | 1.5 | 1.8 |

**Zone 4, Canyon Oasis** (balls 1-3 in run 4, 4-6 in run 5, 7-10 in run 6)

| | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Ball at | 2:41 | 2:45 | 2:48 | 3:18 | 3:21 | 3:27 | 3:55 | 4:00 | 4:06 | 4:13 |
| Bag at | 2:43 | 2:46 | 2:50 | 3:19 | 3:26 | 3:29 | 3:57 | 4:03 | 4:09 | 4:16 |
| New-ball gap (min) | 3.0 | 3.7 | 3.3 | 2.9 | 3.3 | 6.9 | 3.4 | 4.8 | 5.0 | 4.9 |

(Zone 4 ball 6's 6.9 min includes three Skyline Egg hatches.)

**Gates:** zone 2 at 17:15 (run 0), zone 3 at 59:07 (run 1), zone 4 at 2:03 (run 3).

**Rebirths** (and the time to get back to where you were)

| Rebirth | At (played) [range] | Where | Saving for it | Price | Back to the run before's best ball | Share of the run before |
|---|---|---|---|---|---|---|
| 1 | 32:56 [26:00-35:12] | zone 1 done, zone 2 ball 1 | 2.5 min | 5.4M | 7:26 into run 1 | 23% |
| 2 | 1:01 [0:53-1:09] | zone 2 ball 7 (middle) | 1.8 min | 3.8B | 12:45 into run 2 | 40% |
| 3 | 1:28 [1:20-1:39] | zone 3 ball 2 (start) | 1.5 min | 120B | 15:46 into run 3 | 59% |
| 4 | 2:12 [2:01-2:27] | zone 3 ball 10 (end) | 2.9 min | 200T | 24:05 into run 4 | 58% |
| 5 | 2:52 [2:36-3:09] | zone 4 ball 3 | 2.2 min | 1.2Qa | 24:15 into run 5 | 64% |
| 6 | 3:32 | zone 4 ball 6 | 2.8 min | 14Qa | 23:09 | 56% |
| 7 | 4:20 | zone 4 done | 3.0 min | 220Qa | 31:15 | 61% |
| 8 | 5:00 | zone 4 done | 6.1 min | 660Qa | 24:20 | 63% |

Rebirth 1 costs about 4 minutes of income at the moment zone 1's ladder is finished (3.1 to 4.8 across the 9
runs), as the addendum asks.

**Waits over about 8 minutes with nothing new to buy:** none before rebirth 8 (about 5 hours in). The longest
stretch without a new purchase before that is under 7 minutes. After rebirth 8 the player owns everything and only
rebirths are left, and each costs x3 the last: about 10-15 minutes to save for rebirth 9, ~20-35 for rebirth 10,
~1-2 hours for rebirth 11. That is the end-game wall (see "for the owner" below).

## Does rebirthing at once pay? (addendum rule 4)

Played time to first reach each ball (middle of 9 runs):

| Player | ball 15 | ball 20 | ball 25 | ball 30 | ball 35 | ball 40 |
|---|---|---|---|---|---|---|
| rebirths at once | 51:04 | 1:19 | 1:53 | 2:08 | 3:21 | 4:13 |
| waits 5 min | 57:54 | 1:30 | 2:08 | 2:23 | 3:18 | 4:46 |
| waits 10 min | 1:01 | 1:18 | 1:53 | 2:32 | 3:25 | 4:57 |
| waits 20 min | 1:10 | 1:24 | 2:11 | 2:56 | 3:56 | 5:13 |
| never rebirths | 1:01 | 1:50 | 2:59 | 4:50 | 6:27 | 7:05 |

Rebirthing at once is first or within 3 minutes of first at every mark, and finishes the game 33-60 minutes ahead.
Never rebirthing takes about 3 hours longer.

## Players who hatch a lot (the pet snowball check)

| Hatches of each egg a run | Rebirth 3 | Rebirth 5 | Rebirth 7 | Ball 30 | Ball 40 | Zone 4 new-ball gap |
|---|---|---|---|---|---|---|
| 3 (the report's player) | 1:28 | 2:52 | 4:20 | 2:08 | 4:13 | 3.9 min |
| 8 | 1:14 | 2:11 | 3:18 | 1:40 | 3:15 | 2.5 min |
| 15 | 1:09 | 2:02 | 2:58 | 1:37 | 2:56 | 1.8 min |
| 30 | 1:12 | 2:07 | 3:07 | 1:41 | 3:05 | 1.3 min |

Hatching more still pays (up to ~30% faster), but it levels off: a full team of the best pets is the cap. Before
this pass, with the old numbers, a 15-hatch player finished the whole game in ~1 hour and zone 4 balls came every
few seconds.

## What was wrong before (the old numbers, same pretend player)

- **Zones 3 and 4 flew by.** Zone 3's new balls came every 0.1-0.8 minutes, and the whole zone 4 ladder took about
  2 minutes (ball 31 at 1:17, ball 40 at 1:19). The zone prices were set for a player with no rebirths, but by the
  time you reach those zones you have 2-4 rebirths and strong pets, so income was 10-40x what the prices expected.
- **Zone 4 pets snowballed.** By rebirth 5 the pets alone multiplied income ~16x (~50x for a heavy hatcher), mostly
  through the Bag stat. Eggs don't get pricier after a rebirth, so later hatches were nearly free.
- **Rebirths 3-8 came 4-9 minutes apart** and cost almost nothing (under 20 seconds of income), so they didn't feel
  like goals. All 40 balls were done at ~1h20, then a wall: rebirth 10 at ~2h, rebirth 12 after 5-10 hours.
- Zone 1, the zone 2 gate and rebirth 1 were fine and are untouched.

## Every config change (Stage 9)

| What | Was | Now |
|---|---|---|
| Zone 2 ball prices, balls 2-10 | 5.4M, 9.3M, 16M, 27M, 110M, 190M, 330M, 550M, 960M | 9.3M, 15M, 23M, 61M, 220M, 320M, 2.9B, 4.3B, 8.2B |
| Zone 3 ball prices, balls 1-10 | 5.9B, 6.7B, 11B, 19B, 33B, 140B, 240B, 410B, 680B, 1.2T | 28B, 35B, 76B, 140B, 180B, 850B, 1.5T, 4.5T, 9.1T, 19T |
| Zone 4 ball prices, balls 1-10 | 7.1T, 8T, 14T, 23T, 40T, 160T, 280T, 480T, 830T, 1.4Qa | 110T, 140T, 230T, 570T, 980T, 2Qa, 6.6Qa, 15Qa, 25Qa, 41Qa |
| Zone 2 bag prices, bags 2-10 | 6.7M, 12M, 20M, 47M, 140M, 240M, 400M, 690M, 1.3B | 11M, 18M, 36M, 100M, 260M, 920M, 3.3B, 5.6B, 8.2B |
| Zone 3 bag prices, bags 1-10 | 6.2B, 8.2B, 14B, 24B, 59B, 170B, 300B, 500B, 850B, 1.6T | 31B, 49B, 99B, 150B, 330B, 1T, 2.5T, 6.1T, 12T, 25T |
| Zone 4 bag prices, bags 1-10 | 7.4T, 10T, 17T, 29T, 70T, 200T, 350T, 600T, 1Qa, 1.9Qa | 120T, 170T, 340T, 710T, 1.2Qa, 3.4Qa, 9.4Qa, 18Qa, 30Qa, 56Qa |
| Gate to zone 3 / zone 4 | 190M / 240B | 320M / 1.5T (still = the zone before's ball 7) |
| Neon Egg / Main Street Egg / Skyline Egg | 19M / 23B / 28T | 33M / 360B / 2.9Qa (~1 min of income the first time you reach each) |
| Rebirth prices 2-7 | 450M, 88B, 2T, 7.1Qa, 60Qa, 400Qa | 3.8B, 120B, 200T, 1.2Qa, 14Qa, 220Qa (then x3 each, unchanged) |
| Main Street pets | Wood Pup Bag +0.6 Coins +0.15; Chrome Bat Coins +1.2 Bag +1; Kingpin Pins +2.5; Blaze Coins +4 Speed +0.4 | Wood Pup Bag +0.3 Coins +0.15; Chrome Bat Coins +0.6 Bag +0.4; Kingpin Pins +1.2; Blaze Coins +1.5 Speed +0.3 |
| Skyline pets | Cloud Bumper Pins +0.8 Bag +1.5; Moony Coins +2.5 Bag +2; Cosmo Coins +12 Pins +6; Perfecto Pins +10 Speed +0.6 | Cloud Bumper Pins +0.6 Bag +0.5; Moony Coins +1.5 Bag +0.7; Cosmo Coins +3 Pins +2; Perfecto Pins +3 Speed +0.5 |

Unchanged on purpose: everything in zone 1 (balls, bags, Speckled Egg, its pets), zone 2 ball 1 and bag 1, the
zone 2 gate, rebirth 1 (5.4M), the rebirth boost (+200% coins, +100% pins a rebirth), how much shop prices rise
after a rebirth, pet slot prices, pin values per zone, the Neon Egg's pets. Pets are still stronger every zone
(best pet: zone 1 Coins +0.25, zone 2 Coins +1, zone 3 Coins +1.5, zone 4 Coins +3 Pins +2).

## How the numbers were picked
- Each zone 2-4 ball's price was tuned in the simulator until its new-ball gap matched zone 1's rhythm (about 2-3
  minutes for the early balls, 4-5 minutes for the later ones, quick after a gate opens). Bags kept their place
  between two balls. Gates stayed at "the zone before's ball 7", as the addendum says.
- Each rebirth's price was set a little under the next ball's price at the spot the addendum names, so the rebirth
  becomes the next thing to buy right there and takes 2-3 minutes to save for.
- I first tried rebirth 4 after zone 3 ball 9 and rebirth 7 after zone 4 ball 9. Then a player who waited 5 minutes
  got to balls 30 and 40 first (the next ball was cheap). Moving them to the end of each ladder fixed it. Raising the
  boost (tried +250% and +300% coins, +150% pins) didn't help, so the boost stays.
- The pet cut and the pricier eggs were tested against players who hatch 3, 8, 15 and 30 times a run. With only the
  prices changed, a heavy hatcher finished about 1.8x faster. With the cut it's about 1.4x and it levels off.

## For the owner (not changed, your call)
1. **End-game wall after ~5 hours.** Once all 40 balls are bought, only rebirths are left and each costs x3 the last
   (the addendum's number). Saving takes ~10 min for rebirth 9, ~30 for 10, 1-2 hours for 11. That's normal for a
   simulator before the next zone (Alpine Peaks) comes. If you want it gentler: rebirth Growth 3 -> 2 in the config.
2. **Real players hatch more than 3 times a run** once eggs are cheap, so expect the real game to run up to ~30%
   faster than these tables. The in-game pacing log (Output window `[Pacing]` lines, TEST panel > PACING, and the
   `Pacing` analytics events) shows real players' times to compare.
3. **Very big numbers:** zone 4 prices and rebirths 5+ go past 1 quadrillion. The game handles them, but the
   "precision" warning in Output (once per place) will show. The weekly coins leaderboard caps at ~9 quadrillion.
