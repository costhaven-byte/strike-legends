# Pacing report (Addendum 5 step E, 2026-11-01)

How fast the new loop goes, where it breaks, and what I changed. Numbers come from the economy simulator
(`EconomySim.CorePacing` in Studio, plus a Python copy with the same rules that ran 20 different pet-luck seeds; the
tables show the middle result). The simulator plays the real rules: two ladders, pet slots, the four roof eggs, pets
with 4 stats, EQUIP BEST, Shiny merges, the bag cap, a 6-second sell trip, rebirth x2/x3/x4... on pins AND on the
sell, and ladder prices x (multiplier)^1.6 after a rebirth.

Two pretend players:
- **Rebirther**: always buys the cheapest next thing (ball, bag, pet slot, next egg), hatches the Volcano Egg 3 extra
  times each run, then saves and rebirths as soon as it can pay.
- **Never rebirths**: same start, never rebirths, and after the ladders keeps hatching the Volcano Egg.

## Where you can read the real players' pacing (new in this step)
- **Output window**: when a player leaves, `[Pacing] <name>: ...` prints every run: when each ball, bag, egg and pet
  slot came (minutes of play into the run), when the rebirth came, the income (coins a minute) at the top of the run,
  5 minutes in, just before the rebirth, and how long the next run took to get back to that income. Each buy also
  prints one line as it happens (`[Pacing] Selim: Ball3 at 2:58 into run 0`).
- **Studio TEST panel > EVENTS > PACING**: prints the same report any time.
- **Saved with the player** (`Pacing`, save v36, newest 8 runs), so a run over several sessions still adds up (the clock
  is total play time).
- **Creator Dashboard (Analytics)**: custom event `Pacing` (value = seconds into the run; labels = Ball3 / Bag2 / Slot4 /
  Egg_Alley / Rebirth1 / BackToIncome, R<rebirths>, minutes played in total), `PacingIncome` (coins a minute just
  before each rebirth), and a funnel called **Run** (step 1 run start, steps 2-10 balls 2-10, step 11 rebirth; one
  funnel pass per run), so you can see where players stop climbing.

## The table (after my changes)

**First run (new player), minutes of play:**

| Ball | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|
| reached at | 0:13 | 3:05 | 5:08 | 7:00 | 11:14 | 15:20 | 20:18 | 25:15 | 30:04 |
| gap | | 2.9 | 2.0 | 1.9 | 4.2 | 4.1 | 5.0 | 5.0 | 4.8 |

| Bag | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|
| reached at | 1:01 | 4:01 | 5:54 | 9:46 | 13:18 | 18:27 | 22:14 | 27:21 | 33:23 |

Eggs: Neon 1:58, Main Street 12:21, Skyline 23:44, Volcano 36:19. Pet slots 4-8: 7:53, 16:47, 26:09, 31:36, 38:02.

**Rebirths:**

| | Run length (ladders + eggs) | Top income | Save for the rebirth | Rebirth at (played) | Back to the last run's top |
|---|---|---|---|---|---|
| Run 0 (new player) | 40:09 | 2.98M/min | 3:21 for 10M | **43:31** (rebirth 1) | - |
| Run 1 (x2) | 7:09 | 6.59M/min | 3:47 for 25M | **55:22** (rebirth 2) | 15% of run 0's time |
| Run 2 (x3) | 8:28 | 10.1M/min | 5:58 for 60M | **1:10:54** (rebirth 3) | 19% |
| Run 3 (x4) | 9:49 | 13.0M/min | 9:15 for 120M | 1:29:56 | 22% |
| Run 4 (x5) | 11:31 | 16.2M/min | 13:34 for 220M | 1:55:00 | 26% |
| Run 5 (x6) | 12:46 | 17.5M/min | 21:56 for 380M | 2:29:11 | 31% |
| Run 6 (x7) | 15:41 | 18.2M/min | 31:20 for 570M | 3:15:40 | 35% |
| Run 7 (x8) | 18:51 | 20.8M/min | 41:07 for 855M | 4:15:39 | 40% |

Income before / after each rebirth: run 0 tops at 2.98M a minute; right after rebirth 1 you earn a few hundred coins a
minute again (ball 1, bag 1), are back at 2.98M after ~6 minutes, and finish run 1 at 6.59M. Each later run does the
same at a higher level.

**Rebirther vs never rebirths (best coins a minute so far):**

| Minute | 15 | 30 | 45 | 60 | 90 | 120 | 180 | 240 |
|---|---|---|---|---|---|---|---|---|
| Rebirther | 7.8K | 169K | 2.94M | 6.59M | 13.5M | 16.9M | 22.7M | 23.6M |
| Never rebirths | 10.8K | 218K | 3.22M | 2.59M | 1.3M | 1.3M | 1.3M | 1.3M |

The player who never rebirths falls far behind after the first hour (x10 to x18), as the addendum wants.

## Where pacing breaks (and what I did)

1. **Pets pulled balls 7-10 in too close** (FIXED). Step A2 timed the ladders without pets; with the eggs and slots of
   B1/B2 balls 7-10 came 2.4-4.3 minutes apart (ball 10 at 27:31) instead of ~5. Balls 6-10 and bags 6-10 are
   re-priced: balls 6-10 now 4.2 / 4.1 / 5.0 / 5.0 / 4.8 min apart, ball 10 at ~30 min. Balls 2-5 are unchanged
   (ball 3 takes 2.9 min because the Neon Egg at 400 coins is bought first, which is the point of the egg).
2. **Rebirth prices hit a wall** (FIXED). With x3 a rebirth, rebirth 5 needed a 2-hour save, rebirth 6 five hours and
   rebirth 7 thirteen hours. The reason: once pets and the multiplier fill the bag in a throw or two, income only
   grows about x(n+1)/n per rebirth, not x3. New prices: 10M, 25M, 60M, 120M, 220M, 380M, then x1.5 each. Saves now
   grow slowly (4, 6, 9, 14, 22, 31, 41 min) and every run still ends higher than the last.
3. **EQUIP BEST could halve your income** (FIXED as far as Config can). Once the bag fills almost at once, a bigger bag
   is the only stat that still raises income, but EQUIP BEST counted Bag at 0.6, so Shiny Volcano pets (Coins/Pins)
   pushed the bag pets out and income fell from ~13M to ~6.5M a minute (rebirther from rebirth 4, never-rebirther at
   ~1 hour). Bag now counts 8 in EQUIP BEST: the rebirther keeps its bag pets through rebirth 8 (first run unchanged).
   The never-rebirther still drops from ~3.2M to ~1.3M after ~200 Volcano hatches; only a code change fixes that
   (see "for the owner" below).
4. **PIN CRUSHER achievement went too fast** (FIXED). Pins are a big number now (16K-40K a throw at ball 10 with pets),
   so the old goals 1K / 10K / 100K / 500K were all done in the first ~30 minutes. Core loop goals now 10K (~15 min),
   1M (~35 min), 10M (~4-5 h), 100M (long-term). The other achievements are fine: MONEY MAKER 100K (~20 min) / 10M
   (~40 min) / 1B (~3-4 h) / 1T (long), EGG HUNTER 1/10/50/200, BOWLER throws, REBORN 1/3/5/10.
5. **Gift coins vs rebirth prices** (NOT fixed, needs code). Daily, playtime and level gifts pay 2 minutes (crates 5) of
   the *bare* ladder income: no pets, no rebirth. At ball 10 that is ~330K, about 10 seconds of a real first-run
   player's income, and after a rebirth it is almost nothing next to 25M+ prices. They are a token now. Fix idea:
   pay gift coins from the player's real income (the new `Pacing.Income`, coins a minute over the last 3 minutes).
6. **Eggs get cheap after rebirth** (NOT changed, your call). The Volcano Egg (1.5M) is ~10-15 seconds of income from
   rebirth 2 on, so players can hatch hundreds; egg prices don't grow with rebirths. That is normal for a simulator,
   but it makes the Shiny Mythics come fast and there is no 5th egg to chase. Options: a 5th egg tier (no new art:
   another re-tint) or egg prices x (rebirth multiplier)^something.
7. **The bag is the real cap** (design note, needs code). From rebirth 1 on the bag fills in under a throw, so balls,
   the Coins and Pins pet stats and the pins multiplier hardly raise income; the bag size, the Bag pet stat and the
   rebirth sell multiplier do. That is why later runs grow slowly. Fix idea: bag size x the rebirth multiplier (like
   the sell), or pay the Coins pet stat on the sell instead of into the bag. Not done: Config-only step.
8. **Pins number overflow**: no problem. Pins a throw peak ~1.1M at rebirth 7 (never-rebirther ~360K); coins earned ever
   ~2.5B after 5 hours; the precision limit is 1,000,000,000,000,000. With the old x3 rebirth prices, rebirth 18 would
   have cost over that limit (and the COSMIC tier at rebirth 20 was past it); with x1.5 that is past rebirth 40.
9. **Long waits**: none in the first two hours. The longest single wait in run 0 is ~5 min (balls 8-10). After rebirth
   7 the save is 40+ minutes, then longer (the "then longer" part).

## Every Config change (step E)
| Where | Was | Now |
|---|---|---|
| `CoreLoop.Balls` prices, balls 6-10 | 10K, 21K, 45K, 99K, 220K | 5.3K, 22K, 44K, 150K, 590K |
| `CoreLoop.BagPrices`, bags 6-10 | 11K, 24K, 54K, 120K, 420K | 7.4K, 29K, 75K, 200K, 690K |
| `CoreLoop.Rebirth.Prices` / `Growth` | {10M} then x3 | {10M, 25M, 60M, 120M, 220M, 380M} then x1.5 |
| `PetStats.Types.Bag.Best` (EQUIP BEST weight) | 0.6 | 8 |
| PIN CRUSHER goals (core loop only, end of Config) | 1K / 10K / 100K / 500K | 10K / 1M / 10M / 100M |
| `Config.Pacing` (new) | - | Enabled, Print, KeepRuns 8, IncomeWindow 180 s |

Unchanged on purpose: `Rebirth.LadderPower` 1.6 (1.4 made recovery 13-25%, 1.8 made it 17-55%; 1.6 gives 15-40%
around the addendum's "about a quarter"), egg prices, pet stats, slot prices, Bonus 1.

## How to re-run
- Studio command bar (edit mode): `print(require(game.ServerStorage.Tools.EconomySim).CorePacing())`
  (optional: `CorePacing(nil, seed, runs, hatchesPerRun)`). Takes well under a second.
