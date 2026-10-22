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
