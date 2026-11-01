# B1 playtest log (2026-11-01, Studio Play, numbers only)

Studio's 3D view was still frozen (screen_capture timed out), so no screenshots. Code pushed with the http trick
(python http.server 35641 + ScriptEditorService:UpdateSourceAsync). Test start mode: START FROM ZERO (nothing saved).
Studio gives the +2 PET SLOTS pass for free (StudioPreview), so the server shows 3 + 2 = 5 slots at the start.

## Stats reach the server numbers (attributes after equipping)
- No pets: BagSize 60, ThrowCooldown 1, PinsMultiplier 1, CoinMultipliers Mascots=1.
- TEST > GIVE PET x3 (Pinny +25% Coins, Gus +10% Coins, Lane Pup +15% Bag +10% Speed), auto-equipped:
  MascotStats Coins=0.35 Bag=0.15 Speed=0.1 -> BagSize 69 (60 x 1.15), ThrowCooldown 0.909 (1 / 1.1), Mascots=1.35.

## Real throws (client fires CoreThrow every 0.03-0.05 s on its own spot; ThrowResult measured)
| Equipped | Stats | throws | avg pins | coins per pin | interval | cooldown | bag |
|---|---|---|---|---|---|---|---|
| none | - | 13 in 12 s | 5.92 (ball 6) | 2.532 | 0.971 | 1 | 60 |
| Pinny, Gus, Lane Pup | C .35 B .15 S .1 | 14 | 6.21 | 3.391 (x1.34) | 0.888 | 0.909 | 69 |
| + Bumper, Strikey | C .35 P .5 B .45 S .1 | 14 | 8.86 (6 x 1.5 = 9) | 3.371 | 0.870 | 0.909 | 87 |
| Perfecto, Blaze, Neon Bat, Cloud Bumper, Lane Pup | C 1.5 P 5.6 B 1.35 S 1.55 | 28 in 10 s | 40.57 (6 x 6.6 = 39.6) | 6.253 (2.5 x 2.5) | 0.365 | **0.4 = floor** (1/2.55 = 0.39) | 141 |
| EQUIP BEST: Cosmo, Perfecto, Titan Jr, Moony, Kingpin | C 9 P 12.5 B 1.5 S 0.6 | 14 in 8 s | 82.43 (6 x 13.5 = 81) | 25.000 (2.5 x 10) | 0.596 | 0.625 (1/1.6) | 150 |
- Base coins per pin 2.5 = the Studio pass multipliers (Passes 2.5); pets multiply on top (same-stat boosts add).
- Drawn pins never above 40 (max 40) while the count went to 80+.
- Speed floor holds: 0.4 s cooldown; measured interval 0.365 = the old 0.05 s timing slack, RateLimit 0.33 below it.

## Pet slots (coins, shop only)
- CoreBuy("PetSlot") away from the shop: refused "Buy it at the shop".
- At the shop (CoreGoTo Shop): slots 4..8 bought for 2,500 / 25,000 / 150,000 / 600,000 / 2.5M (coins went down by
  exactly that), PetSlotsBought 1..5, MascotSlots 6..10 (with the Studio pass); 6th try: "You've got every slot".
- Shop window PET SLOTS row: "Pet slots / All 8 slots bought: 8 pets out at once".

## Labels (read from the PETS panel GUI)
- Strip: PET BOOSTS, +900% COINS / +1250% PINS / +150% BAG / +60% SPEED (14 px, fits).
- Cards: Cosmo "+600% COINS" (gold) + "+300% PINS" (pink); Strikey "+50% PINS"; Lane Pup "+15% BAG" + "+10% SPEED";
  Shiny Gus card "+20% COINS" (x2). PETS page open (no "later update" lock).

## Output
No errors. Only the old notes for the hidden rooftop egg stand / crate shop.

## Not checked (needs a working 3D view)
How the cards, the 2x2 totals and the shop's PET SLOTS row look; the hatch card stat count-up (no egg on the roof
until B2).
