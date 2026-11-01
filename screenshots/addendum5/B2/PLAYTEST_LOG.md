# B2 playtest log (2026-11-01, Studio Play)

Studio's 3D view worked again for the last part of this step, so there are screenshots (1-6 here). Code pushed with
the http trick (python http.server 35777 + ScriptEditorService:UpdateSourceAsync). Start mode: Studio fresh player.
Studio gives the test passes for free: TRIPLE HATCH (3 eggs per press), LUCKY x8 (odds boards say "LUCKY x8 ODDS"),
+2 PET SLOTS, x2.5 coins. Live players without passes hatch 1 egg at normal odds.

## Egg row (server, built at start)
- SkylineLanes.EggRow: Alley (Neon Egg) x26, Arcade (Main Street) x46, Skyline x69, Volcano x90, all z -3438, all
  bottoms on the roof floor (848.0), signs facing the shop side. PetFusion at (96, -3418) facing west.
- ReplicatedStorage.PetModels.Egg_Volcano made from Egg_Alley (orange/red, screenshot 3).
- First try put two stands 2.2 studs off the floor (the pads are turned cylinders, so the model box was sideways);
  fixed by measuring the lowest point in world space.

## Buying (coins only, at the stand)
- Hatch away from the stands: "Hatch it at the egg stand". Arcade from the Neon stand: refused the same way.
- Neon Egg at its stand: 1,200 coins taken (3 x 400, triple pass), 3 pets, auto-equipped into free slots.
- Main Street 3 x 6,500, Skyline 3 x 80,000, Volcano 3 x 1.5M taken exactly. "Neon" (no roof egg): "Coming soon".
- Odds boards: Neon Gus/Pinny/Bumper/LanePup/Strikey, Main Street Splitz/WoodPup/Hambone/NeonBat, Skyline
  ChromeBat/CloudBumper/Kingpin/Moony, Volcano Blaze/TitanJr/Cosmo/Perfecto. Hatch card "1 IN X" = same maths.
- Luck fix: before, LUCKY only boosted Rare and up, which did nothing on eggs 2-4. Now it boosts every rarity but the
  egg's commonest (Neon Egg with x8: Pinny 26.7% = what the server reported).

## Income changes by the stated amount (real throws, 8 s each, ball 1)
| Pets | stats | coins per pin | interval | cooldown | bag |
|---|---|---|---|---|---|
| none | - | 2.537 | 0.981 | 1.000 | 60 |
| Pinny, Bumper, Lane Pup | +20% Coins, +45% Bag, +10% Speed | 3.000 (x1.2) | 0.900 | 0.909 | 87 |
| EQUIP BEST: Cosmo, Blaze x2, Moony x2 | +2500% Coins, +600% Pins, +400% Bag, +80% Speed | 65.0 (2.5 x 26) | - | 0.556 | 300 |
- Pins x7: 44.4 average (6 x 7 = 42, +-20% roll); never more than 40 drawn.

## Shiny merge
- 3 Bumpers, merge at the egg row: "Fuse pets at the PET FUSION machine".
- At the roof fusion machine: Bumper_Shiny (+60% Bag, x2), went into a free slot. Bag total 1.35 as expected.
- FUSE! badge shows on a card with 3+ copies; PETS button red dot on.

## Other
- No pets: the PETS window shows GO TO EGGS; it lands you at (26, -3430) facing the Neon Egg.
- First-egg prompt: fresh player, +10K coins -> after 1.5 s the BUY YOUR FIRST PET EGG! popup, GO HERE! marker over
  the Neon Egg and the gold beam (EggPrompted saved 1).
- Area signs PET EGGS and FUSION built over the row and the machine.
- Hatch on the roof stand with the E prompt: full hatch scene (shake, flash, EPIC!, stat card, extras, AUTO).
- Output: no errors. "MascotMerged not in Config.Analytics.Events" fixed. Old notes only (hidden CrateShop/EggPad).

## Sim (EconomySim.CoreEggs, one of each egg, cheapest next thing)
Egg 1 at 2.0 min, egg 2 at 11.0, egg 3 at 23.0, egg 4 at 31.5; ball 10 at 26.4 (was 31.5 without pets).
