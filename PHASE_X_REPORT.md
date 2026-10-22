# Phase X report

Built 2026-10-22 overnight, in the plan's order: audit, 8A, parts 1 to 7, then 8B. Restore point: git tag `restore-phaseX-before` (code). The world changes are only in the Studio place: save it (File > Save to Roblox) after checking.

## Audit (Step 0)
AUDIT_PHASE_X.md. Surprises: zone 2 has 19 balls (not about 13); pets give coins only, no XP boost (nothing to keep working there); no fusion and no rebirth code exist yet.

## Part 8A: big numbers
- `Shared.Modules.Currency`: the one place for coin math (Add, Sub, Scale, Mul, Round, Compare, CanAfford), save/load (Encode/Decode) and display (Format, FormatFull, FormatMultiplier).
- Suffixes in `Config.Numbers.Suffixes`: K, M, B, T, Qa, Qi, Sx, Sp, Oc, No, Dc, Ud, Dd, Td, Qad, Qid (then scientific). 1-2 decimals, zeros trimmed: 1.5K, 12.34M, 123.4M.
- Precision guard: any coin value at 1e15 or more logs a warning once per place (`Config.Numbers.WarnAt`); the hard limit is about 9e15.
- PlayerDataService: Coins, Gems and WeeklyCoins go through Currency; new `CanAfford` and `Spend`. Crate, egg and Power Level buying use them. SaveStore loads and saves money through Currency (the place for a future migration).
- Every on-screen number formatter (9 copies) now calls Currency.Format.
- Visible change: prices under 1M now show as 15K / 75K / 750K instead of 15,000 / 75,000 / 750,000 (the plan's short format). `Config.Numbers.ShortFrom` = 1000 sets where short format starts.
- Not converted (fine for now): Analytics and SessionLog lines still print raw numbers; leaderboards (OrderedDataStore) store whole numbers, which top out at 9.2 quintillion; a mantissa/exponent format later would need a log-scaled leaderboard score.

## Part 1: zone 2 progression hooks
- `Config.Milestones`. Level rewards: level 7 = 50K coins (or 10% of your next Power Level, whichever is more) + a Bronze Crate; level 9 = 150K (or 15%) + 2 Coin Potions. Popup "LEVEL 7 REWARD!", then the crate opens. Only paid when you reach the level from now on (no back-dated rewards for players already past it).
- Challenge: "GET 3 STRIKES IN A ROW" while bowling on a Neon Lanes lane = FREE BRONZE CRATE, then 3 minutes before it can be done again (`Cooldown`, my guess to stop it from flooding Bronze crates; tune it). Tracker on the right side under the free-crate bar (phones: left, under the Power Level button). Progress is per visit.
- Preview: a line under the tracker, "NEXT: LV 9 = +150K COINS + 2 COIN POTIONS", from zone 2 on, until level 9.
- New code: MilestoneService (server), MilestoneController (screen), ProgressionService.OnLevel, LaneUtil.ZoneOf.
- Tested in Studio: level reward paid + popup; challenge paid a Bronze Crate and went on cooldown.

## Part 2: rarity ranges per zone
- The ladder is `Config.Rarities` (Common to Mythic). Zone ranges: `Config.ZoneRarity` = zone 1 Common-Rare, zone 2 Uncommon-Epic, zone 3 Rare-Legendary, zone 4 Epic-Mythic. Crate odds (Part 4) and pets read it; Output warns if a ball or pet sits outside its zone's range.
- Zone 2's 4 Commons (Bubblegum, Lime Twist, Tangerine, Deep Ocean) moved to zone 1 (the Alley Crate), numbers unchanged. Re-rating them to Uncommon would have pushed zone 2 to 13 balls.
- Pets: Pinny re-rated Common to Uncommon (stays in the Neon Egg, keeps its +2%). Gutter Gus left the egg (holding list, keeps +2%).
- New tiers above Mythic: add a row to Config.Rarities. Reserved names in `Config.ReservedRarities` (Cosmic, Celestial, Eternal).

## Part 3: balls per zone (nothing deleted)
| Zone | Balls | Count |
|---|---|---|
| 1 Back Alley | Duct Tape, Rust Bucket, Bubblegum, Lime Twist, Tangerine, Deep Ocean (C), Hubcap (U), Dumpster Diamond (R) | 8 |
| 2 Neon Lanes | Electric Blue, Toxic Slime, Sunset Strip (U), Magma Core, Galaxy, Thunderstrike (R), Plasma Orb, Nebula, Inferno (E) | 9 |
| 3 Main Street | League Black, Cherry Swirl, Blue Marble (R), Pearl Pro, Tiger Swirl (E), Championship, Perfect 300 (L) | 7 new |
| 4 Skyline | Cloud Swirl, Crystal (E), Sunburst, Solid Gold (L), Lightning, Daybreak (M) | 6 new |
- Retired (still in the data, out of every crate; owners keep and can equip them; the book only shows them to owners): Frostbite, Phantom (to get zone 2 to 9), Golden Strike, Dragon's Eye, The Void, Supernova (too rare for zone 2; zone 4's Sunburst, Solid Gold, Lightning and Daybreak reuse their models and numbers).
- Placeholder looks: zone 3 balls borrow a model painted one plain colour (`Model`, `Tint`, `PlainModel`); zone 4 balls borrow a model and its effects, recoloured. Swap in real models by adding `ReplicatedStorage.BallModels.<Id>` (no code change).
- Zone 4 note: the plan says zone 4 is daylight, but the built Skyline Lanes is a night rooftop (purple city). The placeholder colours (sun, cloud, lightning, gold, crystal) follow the plan; check them against the night look.
- Owner's spin wheel: SECRET BALL and SECRET PET now give an Epic (zone 2's best), not a Legendary, because zone 2 now stops at Epic. Change `Config.Spin` back if you want Legendary there.

## Part 4: crates (final odds)
| Crate | Zone | Price | Odds |
|---|---|---|---|
| Alley Crate | 1 | 15K (first 1K) | Common 70, Uncommon 25, Rare 5 (unchanged) |
| Bronze | 2 | 75K | Uncommon 75, Rare 25 |
| Silver | 2 | 750K | Uncommon 35, Rare 55, Epic 10 |
| Gold | 2 | 65M | Rare 70, Epic 30 |
| League Crate | 3 | 25M | Rare 75, Epic 25 |
| Champion Crate | 3 | 1B | Epic 70, Legendary 30 |
| Sky Bronze | 4 | 5B | Epic 75, Legendary 25 |
| Sky Silver | 4 | 50B | Epic 35, Legendary 55, Mythic 10 |
| Sky Gold | 4 | 500B | Legendary 70, Mythic 30 |
- Shape in `Config.CrateTiers`, shifted by each zone's lowest rarity. A rarity with no balls in a crate passes its share to the nearest rarity that has some.
- Pity: Bronze Rare after 10; Silver/Gold Epic after 20; League Epic after 10; Champion Legendary after 20; Sky Bronze Legendary after 10; Sky Silver Mythic after 40; Sky Gold Mythic after 20. Gold left the old Legendary-after-80 row.
- Zone 3 and 4 crates are bought from new crate counters in those zones (placeholder booths, `Config.ZoneShops`) that open the crate shop screen. Prices for zones 3 and 4 are placeholders for the economy pass.

## Part 5: pet eggs
| Egg | Zone | Pets |
|---|---|---|
| Neon Egg | 2 | Pinny, Lane Pup (U), Strikey, Splitz (R), Hambone, Neon Bat (E): 6 |
| Main Street Egg (code Id Arcade) | 3 | Wood Pup* (R), Chrome Bat* (E), Kingpin, Blaze (L) |
| Skyline Egg | 4 | Cloud Bumper* (E), Sunny* (L), Cosmo, Perfecto (M) |
- * = placeholder pet that borrows another pet's model, repainted. Holding list (in no egg, owners keep them): Gutter Gus, Bumper.
- Each egg hatches at its own stand (`Config.EggStands`): lobby (Neon), Main Street Lanes back walkway (west end), Skyline roof east of the lanes. The zone 3/4 stands are repainted copies of the Neon stand. Eggs only roll the rarities they hold.
- Pet bonus follows the egg it's in now, so Kingpin/Blaze (+60% to +240%) and Cosmo/Perfecto (+150% to +1050%) got stronger for anyone who already owns them. Shiny merge works for every egg. Pets still give coins only (no XP boost exists).
- Egg prices (Main Street 6.3M, Skyline 1.5B) were already in the data; placeholders for the economy pass.
- Tested in Studio: zone 3 hatch at its stand (Chrome Bat), hatching away from a stand refused, League Crate opened (Pearl Pro), Champion refused without coins.
