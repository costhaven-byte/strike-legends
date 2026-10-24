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

## E2 (built, test pending): zone pay in the live game
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

## E3 (after E2 passes)
Zone 3/4 crate and egg prices, Power Levels 8-12, moved-pet bonuses, XP curve so level 60 is reachable with zones
1-4, zone 2 at 4 min vs the plan's 8-10, rebirth cost, boss reward.
