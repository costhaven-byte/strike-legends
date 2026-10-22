# Phase X audit (Step 0, read only) - 2026-10-22

Source of truth for Phase X. Everything below was read from the code (`src/shared/Config/init.luau` unless noted), not from the design docs.

## Balls (Config.Balls) - 24 total

"Mult" = coin multiplier while equipped (the ball's power value). "Forg" = how much wider the gold zone is.

| Ball (Id) | Rarity | Zone | Theme | Drops from | Mult | Forg | Traits |
|---|---|---|---|---|---|---|---|
| Rookie Ball (Rookie) | Common | - | starter | never (InCrates = false) | 1.0 | 0 | - |
| Duct Tape (DuctTape) | Common | 1 | Back Alley junk | Alley Crate | 1.1 | 0 | Lucky 5% |
| Rust Bucket (RustBucket) | Common | 1 | Back Alley junk | Alley Crate | 1.15 | 0 | Heavy 3% |
| Hubcap (Hubcap) | Uncommon | 1 | Back Alley junk | Alley Crate | 1.4 | 0.01 | Curve 6% |
| Dumpster Diamond (DumpsterDiamond) | Rare | 1 | Back Alley junk | Alley Crate | 2.0 | 0.02 | Blast 20% |
| Bubblegum (Bubblegum) | Common | 2 | plain colour (not neon) | Bronze/Silver | 1.05 | 0 | Lucky 10% |
| Lime Twist (Lime) | Common | 2 | plain colour | Bronze/Silver | 1.1 | 0 | Curve 5% |
| Tangerine (Tangerine) | Common | 2 | plain colour | Bronze/Silver | 1.15 | 0 | Heavy 5% |
| Deep Ocean (Ocean) | Common | 2 | plain colour | Bronze/Silver | 1.2 | 0.005 | GemHunter 1% |
| Electric Blue (Electric) | Uncommon | 2 | neon | Bronze/Silver/Gold | 1.3 | 0.01 | Curve 12% |
| Toxic Slime (Toxic) | Uncommon | 2 | neon | Bronze/Silver/Gold | 1.4 | 0.01 | Blast 15% |
| Sunset Strip (Sunset) | Uncommon | 2 | neon | Bronze/Silver/Gold | 1.5 | 0.015 | Lucky 30% |
| Frostbite (Frostbite) | Uncommon | 2 | ice | Bronze/Silver/Gold | 1.6 | 0.015 | Heavy 15% |
| Magma Core (Magma) | Rare | 2 | lava | Bronze/Silver/Gold | 1.8 | 0.02 | Blast 35% |
| Galaxy (Galaxy) | Rare | 2 | neon space | Bronze/Silver/Gold | 2.0 | 0.02 | Lucky 75% |
| Thunderstrike (Thunder) | Rare | 2 | neon | Bronze/Silver/Gold | 2.2 | 0.025 | StreakSaver 60s |
| Phantom (Phantom) | Rare | 2 | ghost | Bronze/Silver/Gold | 2.5 | 0.025 | Curve 25% |
| Plasma Orb (Plasma) | Epic | 2 | neon | Bronze/Silver/Gold | 3.0 | 0.03 | Heavy 40%, GemHunter 6% |
| Nebula (Nebula) | Epic | 2 | neon space | Bronze/Silver/Gold | 4.0 | 0.035 | Lucky 125%, GemHunter 8% |
| Inferno (Inferno) | Epic | 2 | neon fire | Bronze/Silver/Gold | 5.0 | 0.035 | Blast 50%, Curve 35% |
| Golden Strike (Golden) | Legendary | 2 | gold foil | Silver/Gold | 7.0 | 0.04 | Lucky 200%, GemHunter 15% |
| Dragon's Eye (Dragon) | Legendary | 2 | neon | Silver/Gold | 10.0 | 0.045 | Blast 75%, StreakSaver 45s |
| The Void (Void) | Mythic | 2 | neon | Gold | 20.0 | 0.05 | Curve 60%, StreakSaver 30s |
| Supernova (Supernova) | Mythic | 2 | neon | Gold | 25.0 | 0.05 | Blast 100%, Heavy 80% |

Zone 2 has **19 balls** (the plan guessed about 13): 4 Common, 4 Uncommon, 4 Rare, 3 Epic, 2 Legendary, 2 Mythic.
Every crate is zone-only (`ZoneBallsOnly`), so a ball only drops from its own zone's crates. Zone 3 and 4 have no balls.
Also: SECRET BALL on the daily spin = a random Legendary from the Gold crate pool (SpinService).

**Zone 2 Commons that don't fit "uncommon to epic"** (Part 2): Bubblegum, Lime Twist, Tangerine, Deep Ocean. They are plain-colour balls, not neon, and not junk either, so they don't fit the Back Alley theme. Decision: re-rate them to Uncommon, keep their numbers.

## Pets and eggs

One egg in the game: **Neon Egg** (code Id `Alley`, 50K coins, opens with zone 2, BonusScale 0.1). 12 pets, 2 per rarity:

| Pet (Id) | Rarity | Egg | Coin bonus (rarity bonus x 0.1) |
|---|---|---|---|
| Pinny, Gutter Gus (Gus) | Common | Neon Egg | +2% |
| Lane Pup (LanePup), Bumper | Uncommon | Neon Egg | +5% |
| Strikey, Splitz | Rare | Neon Egg | +10% |
| Hambone, Neon Bat (NeonBat) | Epic | Neon Egg | +25% |
| Kingpin, Blaze | Legendary | Neon Egg | +60% |
| Cosmo, Perfecto | Mythic | Neon Egg | +150% |

Hatch odds (Config.Economy.Mascots.Odds): Common 60, Uncommon 25, Rare 10, Epic 4, Legendary 0.9, Mythic 0.1.
Shiny merge: 3 copies = Shiny (x2 bonus). Slots: 3, +1 at levels 15 and 30 (max 6).
Data-only eggs (no pets, not in the game): Neon 420K, Arcade 6.3M (zone 3), Skyline 1.5B (zone 4), Volcano 35B (zone 5).
SECRET PET on the spin = a random Legendary from the Neon Egg.

**Pets give coins only, not XP.** The plan says pets already give XP boosts; the code has no pet XP bonus (only potions boost XP). Nothing to keep working there; reported, not invented.

## Crates (Config.Crates + Config.Economy.Crates)

| Crate | Name | Price | Zone | Odds |
|---|---|---|---|---|
| Basic | Alley Crate | 15K (first one 1,000) | 1 | Common 70, Uncommon 25, Rare 5 |
| Bronze | Bronze Crate | 75K | 2 | Common 45, Uncommon 35, Rare 17, Epic 3 |
| Silver | Silver Crate | 750K | 2 | Common 20, Uncommon 35, Rare 32, Epic 11, Legendary 2 |
| Gold | Gold Crate | 65M | 2 | Uncommon 20, Rare 45, Epic 28, Legendary 6.5, Mythic 0.5 |
| Neon | (removed) | 5.9B | - | simulator row only |

Pity: Basic/Bronze Rare after 10; Silver/Gold Epic after 20; Gold Legendary after 80. Duplicates = Polish.
If a rolled rarity has no ball in the pool, CrateRoller (`src/server/Modules/CrateRoller.luau`) gives the crate's best ball instead (Part 4 wants the nearest rarity).

## Level gates and zone teleports

- Gate levels: `Config.Economy.Zones[n].Rank` (zone 2 = 5, zone 3 = 12, zone 4 = 22, 5 = 35, 6 = 50). Read by `Shared.Modules.Zones`.
- How many zones exist: `Config.Zones.BuiltZones`.
- Walls, kick-out spot and teleport spot ("TAKE ME THERE"): `Config.Zones.Gated` (Walls, KickTo, Arrival). Server: `LaneService`; client: `ZoneGateController`.
- The unlock popup's contents: `Config.ZoneUnlock[zone]`.

## Currency math today (for Part 8A)

- Coins/Gems live in PlayerDataService (`Add`, `Get`, `Set`), mirrored to Player attributes.
- Coin changes: ThrowService (throw pay), BallService (crate buy, duplicate coins), PowerLevelService, MascotService (egg buy/refund), DailyRewardService, SpinService/PlaytimeService (via Add).
- Display: 8 separate `formatNumber` copies (Crate, Daily, Hud, Kiosk, Leaderboard, Mascot, Rizzo controllers + SlUi.Format) and MultiplierController's own.
- Saves: SaveStore saves `Data.Coins` as a plain number.

## Power by rarity (for Part 8B)

| Rarity | Ball Mult (avg, zone 2) | Pet coin bonus (Economy.Mascots.Bonus, before egg scale) | Pet XP |
|---|---|---|---|
| Common | 1.13 | 0.2 | none |
| Uncommon | 1.45 | 0.5 | none |
| Rare | 2.13 | 1.0 | none |
| Epic | 4.0 | 2.5 | none |
| Legendary | 8.5 | 6 | none |
| Mythic | 22.5 | 15 | none |

Step ratios: ball about x1.3, x1.5, x1.9, x2.1, x2.6 (average about x1.85); pet x2.5, x2, x2.5, x2.4, x2.5 (average about x2.4).

## Other facts the plan relies on

- **Fusion**: no fusion system exists. The only merge is Shiny (3 of the same pet).
- **Rebirth**: numbers exist (`Config.Economy.Rebirth`, sim only); no rebirth code in the game.
- **Display cases**: lobby "Vault" (ShowcaseController) = one case per ball of Rare or better (12 slots, Workspace.Showcase.Slots); rarity look comes from `Config.Showcase.Styles` (already accent + FX only, same base case for every rarity). Pets = a mascot shelf (one stand per pet, coloured when owned), not cases.
- **Boss**: nothing built (owner said not to start boss gameplay).
