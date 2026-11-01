# STRIKE LEGENDS ADDENDUM 6

Read first: CLAUDE.md, GAME_DESIGN.md, STRIKE_LEGENDS_ADDENDUM_5.md. This addendum builds on Addendum 5 and wins wherever the two conflict.

This was written without seeing the current code. Where it names a system, setting or file that does not exist or is called something else, find the real equivalent and say so in your stage report.

## Context

The owner played about 35 minutes straight on the current build: first 10 balls and bags, a few pets, rebirth, repeat. It held his attention the whole time. That loop is the product. Do not slow it down, add friction to it, or change Zone 1 pacing unless a stage below says so.

The whole game is now outdoors, bright, sunny and vibrant. Not cute, not dark, no night scenes, no neon-on-black. The old zones (back alley, neon, bowling alley) are dead. Leave them switched off, do not delete them.

## Working rules

- Work in stages. Stop after Stage 2 so the owner can playtest. After that, do not stop between stages, but write a short plain-language report after each one: what changed, what you could not verify.
- The owner does not code. Reports must be plain English, no code talk.
- Keep every tuning number (prices, multipliers, pin counts, rebirth costs) in one config module so it can be tuned in one place.
- Verify visual work with Studio screenshots through the MCP. Do not call a visual fix done without looking at it.
- Placeholders are fine for any art that does not exist yet. Tag each placeholder so it can be found and replaced later.

---

## STAGE 1: Fixes

### 1.1 Multipliers do nothing

Coin multipliers from potions and from bought multipliers have no visible effect. Pet boosts and rebirth boosts may have the same problem, so check every boost source, for coins and for pins.

1. Find every place coins are paid out (selling pins, anything else). Find every place pins per swing are calculated.
2. Replace them with one function each: GetCoinMultiplier(player) and GetPinMultiplier(player). Nothing else is allowed to compute a multiplier.
3. Stacking rule, as a starting point: permanent sources (pets plus rebirth) add together as 1 + sum. That total is then multiplied by the potion multiplier, then by the gamepass multiplier. Put the formula in the config module.
4. Make it visible. The HUD shows the current total coin multiplier (for example x3.4). Tapping it shows a breakdown by source. Every sell popup shows the multiplier it used.
5. Potions show a countdown on the HUD while active.
6. Add a Studio-only test command that prints the full breakdown for the local player, and test each source on its own: sell with no boosts, sell with only a potion, only a bought multiplier, only a pet, only rebirth, then all together.
7. In your report, say what the actual cause was.

### 1.2 Lane is too bright

Ball effects wash out against the lane. The fix is not dimming the world, because the game stays bright and vibrant.

1. Make the lane surface a mid-dark, saturated color (deep teal, navy or dark stained wood, whatever fits the zone) with a non-reflective material. Keep the lane edge lines and gutters bright so the lane still reads as a lane.
2. Check lighting settings that can wash out effects: sun and ambient brightness, exposure, bloom intensity and threshold, color correction, any neon or glossy parts on the lane.
3. Test with the strongest ball effect in the brightest part of the day cycle, if there is one. Take a screenshot. Effects must be clearly readable against the lane. Zones 2 to 4 follow the same rule.

---

## STAGE 2: Shop

### 2.1 Tabs

The buy station UI gets tabs: Balls, Bags, Rebirth. Build it so more tabs can be added (a Gamepasses tab comes in Stage 8). Purchases still only happen at the buy station, as in Addendum 5.

### 2.2 Buy any ball or bag you can afford

Balls and bags are still one linear ladder in order of power. But a player can buy any ball or bag above their current best, as long as they can afford it and its zone is unlocked. They never have to buy the one before it.

- Stats always come from the best ball (and best bag) owned.
- Skipped items stay buyable at their normal price, marked "Skipped". Buying one only unlocks its look. The player can equip any owned ball for its look, but the pins per swing always use the best owned ball.
- Add a "Buy Best" button that buys the highest item the player can afford, and make the next item in the ladder visually highlighted.

### 2.3 Unowned balls are blacked out

In the Balls tab, every ball the player does not own is a solid black silhouette. The name shows as "???". The player sees only the stat improvement (pins per swing gained) and the price. The effect, the real model look and the name stay hidden until bought.

- Show the full ladder as silhouettes so the player can see the chase, including balls from zones not yet unlocked (price shown greyed out, with a lock).
- Buying a ball plays a short reveal: flash, the silhouette color pops in, the name appears, the ball's effect plays once. Keep it under 2 seconds.
- Do the same for bags: silhouette until owned, stat and price visible.

### 2.4 Rebirth names

Rebirth ranks use the names of the old rank ladder from the original v1 design. Read the rank list in GAME_DESIGN.md and use those names in order. If there are more rebirth tiers than old ranks, extend the list with names in the same style.

The Rebirth tab shows: the player's current rank, the next rank name, the cost, what gets reset (coins, balls, bags, zones, pins), what is kept (pets, gamepasses, rank), and the boost gained. Rebirth needs a hold-to-confirm button, not a single tap. The rank shows on the player's overhead nameplate and on the leaderboard.

### 2.5 Small additions

- A "Next goal" bar on the HUD: shows the next thing worth buying, its price, and a progress bar toward it.
- Number formatting through quadrillions everywhere (K, M, B, T, Qa), with the same style on HUD, shop and popups.

**STOP here and report. The owner will playtest before anything else starts.**

---

## STAGE 3: Zone framework and eggs

### 3.1 The four zones

Zone 1 is the current rooftop. Zones 2 to 4 are new. Each is a big shared lane, one per map, with a personal view so each player only sees and counts the pins they knocked (Addendum 5). Each zone has a sell station, a buy station, an egg stand and a gate to the next zone.

| Zone | Name | Setting | Palette |
|---|---|---|---|
| 1 | Skyline Rooftop | Current build. Sunny city rooftop, open sky | Warm concrete, sky blue, white |
| 2 | Sunset Boardwalk | Beach pier and boardwalk, ocean, striped umbrellas, kites | Turquoise, coral, sand yellow |
| 3 | Jungle Falls | Tropical valley, waterfalls, rope bridges, huge leaves | Rich greens, aqua, orange flowers |
| 4 | Canyon Oasis | Red rock canyon with a turquoise lake and palm oasis | Terracotta, turquoise, gold |

Later zones (not in this addendum): Alpine Peaks, Floating Islands, and a cosmic tier above mythic.

### 3.2 Zone rules

- Each zone's lane holds more pins, and each pin sells for more. Starting values: pins per lane about 100 / 250 / 600 / 1500 for zones 1 to 4, pin sell value about 6x higher each zone. Tune from pacing logs.
- Each zone has 10 balls and 10 bags, so the full ladder is 40 balls. Zones 1 and 2 use the 20 ball assets already designed. Zones 3 and 4 use placeholder variants (recolors or rescales of existing models) until new designs exist.
- Every ball has its own unique visual effect (visual only, no stat change). This is the "crazier each ball" promise, so no two effects in a zone should look alike. Zone 1 effects are already done. Effects for each new zone are built in that zone's stage.
- Zones unlock by paying coins at the gate. No levels. Balls and bags from a zone cannot be bought until that zone is unlocked.
- Gate price starting point: about the price of the previous zone's ball 7.
- Pacing shape: measure Zone 1's current ball-to-ball intervals from the pacing log and make Zones 2 to 4 follow the same shape. Do not slow Zone 1.

### 3.3 Eggs move

Eggs are bought with coins and every zone has its own.

1. Remove the current egg stand(s) from Zone 1. The current egg (the Neon Egg) and its pet pool move to Zone 2. That pool already fits Zone 2's rarity range. Players who already own those pets keep them.
2. Zone 1 gets a new cheap starter egg (placeholder model, a plain speckled recolor is fine) with a new pool of common to rare pets. It must be affordable by around minute 3 to 5 so the player has a pet early.
3. Rarity ranges by zone: Zone 1 common to rare, Zone 2 uncommon to epic, Zone 3 rare to legendary, Zone 4 epic to mythic.
4. Keep the existing rule that 3 copies of a pet merge into a Shiny version.
5. Every pet boosts coins, pins or both. Make sure each egg's pool has a sensible mix and that stronger zones give meaningfully stronger pets.

### 3.4 Zone checklist

Use this for each of Stages 4 to 6:

- Map: lane, sell station, buy station, egg stand, gate, spawn, all outdoors and bright
- Lane surface passes the effect-readability test from 1.2
- 10 balls with unique effects, 10 bags
- One egg with its own pet pool
- Gate wired in, with its price in the config
- Silhouette shop entries for the zone's balls and bags
- Screenshot proof of each station and one effect

---

## STAGE 4: Zone 2, Sunset Boardwalk

Build to the zone checklist. Include the egg move from 3.3.

## STAGE 5: Zone 3, Jungle Falls

Build to the zone checklist.

## STAGE 6: Zone 4, Canyon Oasis

Build to the zone checklist. If time or credits run short, finish Zone 3 first and report. Zone 4 can ship as the first update.

---

## STAGE 7: Rebirth pacing

Rebirth is optional, resets everything except pets, and boosts coins and pins. It should still hurt, like a classic simulator, but it must always feel worth it.

Rules:

1. The first rebirth becomes affordable when the player finishes Zone 1's ladder, at a price of roughly 4 to 5 minutes of income at that point. That matches how the owner played it in the 35-minute session.
2. After a rebirth, the player should get back to the point they left in about half the time, thanks to pets and the boost.
3. Rebirth cost grows about 3x each time while the boost grows linearly, so each rebirth is affordable deeper into the zones: second around the middle of Zone 2, third around the start of Zone 3, fourth around the end of Zone 3, later ones in Zone 4.
4. Check the opposite case: a player who rebirths the moment it is affordable must not progress slower than one who waits. If the pacing log shows waiting is faster, raise the boost, do not lower the cost.
5. Starting boost per rebirth: coins +50 percent and pins +25 percent, added into the permanent group from 1.1. Tune in the config.

---

## STAGE 8: Gamepasses

Gamepasses are comfort and speed only. Nothing that makes another player's game worse.

Starting list: 2x Coins, 2x Pins, Lucky Eggs (better rare odds), Triple Hatch, Auto Swing, +2 Pet Slots.

- Add a Gamepasses tab to the buy station and a small HUD button that opens it.
- The owner creates the passes in Creator Hub. Build everything with placeholder IDs kept in one config file, plus a Studio-only toggle to grant each pass for testing.
- 2x Coins and 2x Pins feed the gamepass slot of the multiplier formula in 1.1 and show in the HUD breakdown.
- In your report, list exactly what the owner must create in Creator Hub and where each ID goes.

---

## STAGE 9: Pacing pass

Run a simulated playthrough (not real time) for a fresh player with no passes. Write PACING_REPORT.md with:

- Time to each ball and bag in every zone, time to each gate, time to each of the first five rebirths
- Where the player waits longer than about 8 minutes with nothing new to buy
- Time to return to the previous point after each rebirth

Fix anything that breaks the shapes above by changing config numbers, not systems. Report what you changed.
