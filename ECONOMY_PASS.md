# Economy pass (Addendum 2 step 9, zones 1-4)

Owner 2026-10-25: later zones pay more per pin. Split: E1 simulator = live game, E2 zone pay, E3 prices.

## E1 (done): the simulator plays the real game
`tools/EconomySim.luau` now copies the live rules: 10 pins everywhere, Config.Rewards pay, rank tier multipliers,
each zone's own crates/eggs/pets, pity, first crate 1,000, gift crate, level 7/9 rewards, 3-strike challenge, boss,
playtime gifts + potions, free crate every 250 throws, day 1 daily, one spin. Not simulated: overcharge, ball traits,
gems, the gold shrinking with the streak (PERFECT = flat 15% of throws, a guess: check it against a real session log).
New Config fields `Config.Economy.Zones[n].CoinPay / XpPay` (all 1 = today's live game; nothing live reads them yet).
Studio command bar: `require(game.ServerStorage.Tools.EconomySim).Run()` (about 1 second).

### Today's game (10 hours, median of 40 players)
| | Simulated | Note |
|---|---|---|
| Zone 2 opens | 4 min | plan wants 8-10 min |
| Zone 3 opens | 46 min | plan 30-45 |
| Zone 4 opens | 9h46 (only 35% of players in 10 h) | far too slow |
| Power Level 7 (100M) | same as zone 4 | levels 9-12 never |
| Main Street Egg 6.3M | 4h | |
| Skyline Egg 1.5B, Sky Silver/Gold crates | never (2% for the egg) | |
| Rank level 60 | never (level 21 after 10 h) | |
| Coins/min | zone 2 14K, zone 3 47K, zone 4 850K | zone 4 jump is from Power Level 7, not the zone |

## Trial zone pay (20 hours, same players)
| Coins z1/z2/z3/z4 | XP z1/z2/z3/z4 | Zone 3 | Zone 4 | Power Level 12 | Skyline Egg | Level after 20 h |
|---|---|---|---|---|---|---|
| 1/1/1/1 (today) | 1/1/1/1 | 46m | 11h30 | never | 13h47 | 25 |
| 1/3/10/40 | 1/2/4/10 | 25m | 1h44 | 17h | 2h30 | 36 |
| 1/4/20/100 | 1/2/5/15 | 25m | 1h33 | 10h39 | 2h18 | 41 |
| 1/5/25/125 | 1/2/4/8 | 25m | 1h39 | 10h | 2h24 | 36 |
Level 60 is never reached in 20 h with any of them: that needs the XP curve (E3), not just zone XP.

## E2 (PASSED 2026-10-25): zone pay in the live game
- MultiplierService: ZONE coin multiplier = the CoinPay of the zone of the lane you throw on (LaneUtil.ZoneOf);
  ThrowService XP multipliers get ZONE = XpPay. Multiplier panel: new ZONE row (panel 20 px taller). Back Alley x1.
- Numbers: coins x1 / x4 / x16 / x64, XP x1 / x1.2 / x2.5 / x6 (zones 1-4).
- Timeline rows: first crate = the 1,000 sale crate (0:30-1:30), first pet egg 9-14 min (pets open with zone 2),
  new Zone 4 row 2-3 h (owner to confirm), rebirth row skipped while rebirth is off.
- Studio check: a PERFECT on a Main Street lane paid 37,393,920 = every multiplier x ZONE 16, XP 2,029 = 30 x 2.5 x pets.

| 10 h simulated | E1 (x1) | E2 |
|---|---|---|
| Zone 3 / zone 4 | 46 min / 9h46 (35%) | 40 min / 2h29 |
| Power Level 8 / 10 / 12 | 9h21 (5%) / never / never | 2h40 / 7h01 / 9h58 (2%) |
| Main Street Egg / Skyline Egg | 4h / never | 47 min / 3h16 |
| Sky Silver / Sky Gold crate | never / never | 7h31 / never |
| Rank level after 10 h | 21 | 30 (level 60 still never) |
Still off (E3): zone 2 at 4 min (plan 8-10), Gold Crate 65M now comes after the zone 3 crates (1h58 vs League 1h01).

## E3a (built, test pending): rebirth numbers
Owner 2026-10-25: rebirth should be fast (not a long prestige grind), open at zone 3, and zones lock again after it.
- Config.Economy.Rebirth: Zone 3 (level 12), FirstCost 20M, CostGrowth x2, +1 level per rebirth; boosts unchanged
  (+50% coins, +100% XP per rebirth); still Enabled = false (owner flips it). Unused FirstRank removed.
- REBIRTH station moved from the Skyline roof to the east end of Main Street's back walkway (164, 1, 44), facing
  west (moved in Studio, attr Moved_20261025; PlaceholderWorld builds it there if missing).
- Simulator: goals also timed over the whole session ("Ever..."), TOTAL PLAY TIME line, Sim.Rebirths = 10.
- Studio check (rebirth switched on for the test only): 3 zone 3 throws = 125M, rebirth at the new station ->
  coins 0, level 1, Power Level 1, REBIRTH x1.5.

| Simulated (rebirth as soon as possible) | |
|---|---|
| First rebirth | 1h00 (zone 3 at 40 min + 20M) |
| Rebirths 2-15 | every 10-50 min (zone 3 back in 4.5 min after rebirth 1, under 30 s by rebirth 9) |
| Zone 4 / boss / Skyline Egg (total play) | 3h24 / 3h25 / 3h53 (run 4, then every run from about run 7) |
| Rebirths 17+ | 1.5-3 hours each: the level each rebirth needs outgrows the XP curve (fix in E3b) |
| Level 60 | never in 25 h |
Tried and dropped: +2 levels per rebirth (zone 4 3h03 but rebirths slow down sooner), cost x1.6 (little change).

## E3b (after E3a passes)
XP curve (zone 2 at 4 min vs the plan's 8-10, late rebirths, level 60), Gold Crate 65M and zone 3/4 crate and egg
prices, Power Levels 8-12, moved-pet bonuses, boss reward.
