# Phase X report

Built 2026-10-22 overnight, in the plan's order: audit, 8A, parts 1 to 7, then 8B. Restore point: git tag `restore-phaseX-before` (code). The world changes are only in the Studio place: save it (File > Save to Roblox) after checking.

## Audit (Step 0)
AUDIT_PHASE_X.md. Surprises: zone 2 has 19 balls (not about 13); no fusion and no rebirth code exist yet. Pets boost coins and XP by the same amount (kept working).

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
- Pet bonus follows the egg it's in now, so Kingpin/Blaze (+60% to +240%) and Cosmo/Perfecto (+150% to +1050%) got stronger for anyone who already owns them. Shiny merge works for every egg. Pet coin and XP boosts work as before.
- Egg prices (Main Street 6.3M, Skyline 1.5B) were already in the data; placeholders for the economy pass.
- Tested in Studio: zone 3 hatch at its stand (Chrome Bat), hatching away from a stand refused, League Crate opened (Pearl Pro), Champion refused without coins.

## Part 6: zone 3 and 4 scaffolding (one new system per zone)
- Zone 3 Main Street Lanes (back walkway, west to east): Main Street Egg stand, CRATES counter (League + Champion), PET FUSION station. Fusion is a PLACEHOLDER: no fusion design exists, so the station opens the PETS panel where the existing Shiny merge (3 copies = Shiny) lives (`Config.Fusion`). The level 12 popup now lists the Main Street Egg, both crates and the best zone 3 balls.
- Zone 4 Skyline roof (east of the lanes): Skyline Egg stand, SKY CRATES counter, REBIRTH station, and a helipad with a placeholder helicopter. Level 22 popup lists the egg, 3 crates and the zone 4 balls.
- Boss loop (`Config.Boss`, BossService): hold the helicopter prompt, fly to the stub arena (Workspace.BossArena, a floating platform with a giant placeholder pin), stay on it for 20 s = win, reward popup "BOSS DEFEATED!" (PLACEHOLDER reward: 1B coins or 25% of your next Power Level, + a Sky Bronze Crate), then the helicopter brings you back. Every 45 minutes per player, saved (save v18 `BossNextAt`); the helipad sign counts down. The fight lives alone in `server/Modules/BossStub` so the real boss can replace it.
- Rebirth stub (`Config.Economy.Rebirth`, RebirthService): **OFF** (`Enabled = false`, you flip it). Needs level 22 (zone 4's level) +3 per rebirth after, and 4B coins (x1.6 each time). Rebirth = level 1, Power Level 1, 0 coins; balls, pets, gems, potions stay. Gives x1.5 coins (+50% each) and +100% XP per rebirth, shown as REBIRTH in the multiplier panel; rebirth 1 adds a pet slot (`SlotRebirths`). Save v18 `Rebirths`. The station says COMING SOON while it's off. Not built: the "cheap Power Levels after a rebirth" discount from the old plan.
- Tested in Studio: helicopter ride, fight, reward and return, cooldown refusal; rebirth (switched on for the test only); fusion prompt.
- Watch: the pet panel showed x27 coins from pets on your test save, because your Cosmo/Perfecto/Kingpin/Blaze moved to stronger eggs (Part 5).

## Part 7: display cases (balls and pets)
- One case-set builder for every zone (`Config.Showcase.Sets`: zone, slots, pet shelf, egg, theme). Each case = 3 layers: base structure (`Config.Showcase.Themes`: the zone's colours and materials), rarity accent and rarity FX (`Config.Showcase.Styles`, shared by all zones, keyed by rarity; a new tier only needs a row).
- Zone 2 (lobby Vault): now the 9 Neon Lanes balls (Uncommon to Epic); the Legendary and Mythic cases are gone (their 3 slots stand empty). Pet shelf: only the Neon Egg's 6 pets.
- Zone 3 (Main Street back walkway, east part): 7 cases + a wood wall shelf with the Main Street Egg's 4 pets. Zone 4 (roof, east of the lanes): 6 cases facing the elevator walkway + a glass shelf with the Skyline Egg's 4 pets. Both use PLACEHOLDER themes (zone 3 wood, chrome, warm light; zone 4 white, sky blue, bright light) on the zone 2 case shape.
- Not owned = dark silhouette, padlock, "???", no glow; owned = lit up. Reads your real inventory and updates the moment you get the ball/pet.
- Structure differences by rarity (for the designer): Legendary and Mythic swap the black corner posts for gold and add diamonds on the roof (`Posts`, `Gems`); Mythic also darkens the case (`Shade`). Everything else per rarity is accent colour + FX. So one base design per zone covers Common to Epic; Legendary/Mythic need the gold-post + roof-diamond variant.
- Swap-in for the final art: replace the base pieces' colours/materials in Themes (or the case shape in ShowcaseController's PIECES) without touching item or ownership logic.
- Zone 3 booths moved to make room: fusion station x 100, crates x 112 (was 140 / 104).
- Safety net: every Phase X placeholder world piece (zone 3/4 stands, booths, case slots, shelves, helipad, boss arena) is also built from code (`server/Modules/PlaceholderWorld`) when it's missing from the place, because Studio closed the place once during my tests tonight. Pieces saved in the place win.

## Part 8B: rarity power curve
`Config.RarityPower` (tune here). Ball = a typical ball's coin multiplier; Pet = a pet's coin AND XP bonus before its egg's scale (the Neon Egg x0.1, Main Street x0.4, Skyline x0.7). Step = the measured growth per tier from Common to Mythic, used for the reserved tiers.

| Rarity | Ball | Pet (coins + XP) |
|---|---|---|
| Common | x1.13 | +20% |
| Uncommon | x1.45 | +50% |
| Rare | x2.13 | +100% |
| Epic | x4.0 | +250% |
| Legendary | x8.5 | +600% |
| Mythic | x22.5 | +1,500% |
| Cosmic (reserved) | x41.0 | +3,555% |
| Celestial (reserved) | x74.5 | +8,425% |
| Eternal (reserved) | x135.6 | +19,968% |
| Step per tier | x1.82 | x2.37 |

- Pet bonuses now come from this table (same numbers as before). Every existing ball keeps its own Multiplier (variation inside a rarity); a new ball row may leave Multiplier out to get the table's value.
- Real steps between tiers are uneven (balls x1.29, x1.47, x1.88, x2.13, x2.65): the top tiers jump much more. Worth a look in the economy pass.

## Placeholders still needing art or a decision
- Art: 13 placeholder balls (7 zone 3, 6 zone 4, borrowed models), 4 placeholder pets (Wood Pup, Chrome Bat, Cloud Bumper, Sunny), Main Street and Skyline egg models (drawn as spotted eggs), 5 new crate models (borrow Bronze/Silver/Gold), zone 3 and 4 egg stands (repainted Neon stand), crate counters, fusion station, rebirth station, helicopter, boss arena and boss, zone 3 and 4 case themes (one hero case per zone; Legendary/Mythic variant with gold posts + roof diamonds).
- Decisions: boss gameplay (BossStub), boss reward, fusion rules (station = Shiny merge for now), rebirth numbers and whether it unlocks at zone 3 (Addendum 2 note) or zone 4 (Phase X; I used zone 4, `Config.Economy.Rebirth.Zone`), zone 3/4 crate and egg prices, challenge cooldown (3 min), level 7/9 rewards, SECRET BALL/PET now Epic, the pet bonus jump for moved pets, zone 4 daylight (plan) vs night (built).
- Shop screen lists all 10 crates in one scrolling row; the zone 3/4 counters open the same screen (no per-zone filter yet).

## Restore and test
- Code restore point: git tag `restore-phaseX-before`. Studio: File > Save to Roblox As first if you want a copy, then Save to Roblox once you're happy (the zone 3/4 booths, cases, helipad and arena are in the place, and also rebuilt from code if missing).
- Commits: 3c14d77 (8A), 8f97b24 (Part 1), 79bb451 (Parts 2-5), 7200a0b (Part 6), ee554e1 (Part 7), 8B in the last commit.

## What is left of the original milestones (9b onward) and how Phase X changes each
| Milestone (Addendum 2) | Status now | How Phase X changes it |
|---|---|---|
| 9b boss (already changed 2026-10-22 to: zone 4 only, helicopter, every 45 min) | Loop scaffolding built with a stub fight | Left: the real fight in BossStub, a flight animation, arena and boss art, reward numbers. |
| 9 economy pass (end cleanly at zone 4) | Not done | Bigger now: price the 5 new zone 3/4 crates and 2 eggs, re-check zone 2 crates (no Commons, no Legendaries any more), balance the moved pets (+240% to +1,050%), add level rewards, the challenge and boss rewards to the simulator, make the simulator buy only zone crates/eggs, keep level 60 reachable without zones 5-6. The Neon crate and Gold crate "homes" are partly answered: each zone now has its own crates. |
| 10 rebirth | Stub built, OFF | Left: final cost/level/bonus, zone 3 or 4 unlock, the cheap-Power-Level discount, a celebration screen, simulator check. |
| Pet fusing (2026-10-22 note) | Station built (Shiny merge placeholder) | Left: the real fusion rules, if they should be more than Shiny merge. |
| 11 return loops: daily (exists), "while you were away" coins, friend bonus, weekly featured ball, server banner on Legendary/Mythic pulls, rarity glow on equipped balls | Daily done; rest not built | Featured ball must come from a zone's own pool. Legendary/Mythic only exist in zones 3-4 now, so zone 2 players would never trigger the banner (suggest Epic+ in zone 2). Away coins and the friend bonus go through Currency and MultiplierService (the Rebirth slot shows the pattern). |
| 12 monetization (behind MonetizationEnabled = false), final sounds, full models, thumbnail | Not built | 2x Coins / More Mascot Slots plug into MultiplierService and Mascots.Slots. Starter Pack "a Rare ball" needs a zone choice (Rare exists in zones 1-3). Prices use the K/M/B format. The art list grew by everything in "Placeholders" above. |
