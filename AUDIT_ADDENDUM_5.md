# Addendum 5 audit (step 0, 2026-11-01)

Read-only audit of the game as of commit 59b4669 (Addendum 4 Stages 1-3d built). Later step sessions: read this
instead of re-reading the code. Paths are under `src/`. "Config" = `src/shared/Config/init.luau` (5,293 lines;
over 200K chars, so Studio sync of Config needs `UpdateSourceAsync`, and never run stylua on it).
Everything below is live only while `Config.CoreLoop.Enabled = true` (it is); false brings the old zone game back.

## 1. Ball ladder (Config.CoreLoop.Balls, Config line ~54)
| Step | Ball (Config.Balls Id = model + VFX) | Name on screen | Pins | Price |
|---|---|---|---|---|
| 1 | Tangerine | Beach Roller | 6 | 0 |
| 2 | Bubblegum | Rubber Bouncer | 9 | 50 |
| 3 | Lime | Confetti Popper | 12 | 530 |
| 4 | Sunburst | Sunspike | 15 | 1,900 |
| 5 | Frostbite | Gust | 19 | 2,400 |
| 6 | CloudSwirl | Cloud Roll | 23 | 3,200 |
| 7 | Crystal | Rainbow Arc | 27 | 3,900 |
| 8 | Lightning | Sunbolt | 31 | 4,700 |
| 9 | SolidGold | Tornado | 35 | 8,800 |
| 10 | Daybreak | Sonic Boom | 43 | 18,000 |
- Models: the `Ball` Id points at a normal `Config.Balls` row (line ~2394; models in ReplicatedStorage, looks in
  `Config.BallVfx.Balls`, `Shared.Modules.Balls`, `Shared.Modules.BallLook`, client `Modules/BallFx`, `TraitFx`).
- Save: `BallStep` (v34). `CoreLoopService.equipLadderBall` gives + equips `Balls[BallStep].Ball` on load and on buy
  (EquippedBall is forced; Ball Book stays shut). `CoreLoopService.PinsAverage(player)` = `Balls[step].Pins`.
- In-world: zone 4 case row = one case per ladder ball (`Config.Showcase` set with `Ladder = true`,
  `Config.CoreLoop.Plaza.Cases`, ShowcaseController ~963 uses `CoreLadder.BallStep`); locked = "Buy it at the ball shop".
- Pacing comment: 2, 2, 5, 5, 5, 5, 5, 8, 12 min targets, ~53 min full ladder (`tools/EconomySim.luau` `.CoreLadder()`).

## 2. Bag ladder
- `Config.CoreLoop.BagSizes = {60,130,200,300,440,600,780,990,1500,2700}`, `BagPrices = {0,170,700,930,1200,1600,1900,3600,7200,13000}`.
- Save: `BagLevel` (v33), `Bag` (coins in the bag, a Currency value, v33). Server: `CoreLoopService.BagSize`,
  `AddToBag(player, coins, delay)` (promises room via `pending[player]`, adds after RollTime; full = pays 0),
  `IsFull`. Player attributes `Bag`, `BagSize`, `ThrowCooldown` (published on load + on BagLevel/ThrowSpeedLevel change).
- NOTE: the bag holds COINS (pins x PinValue x multipliers), not pins. A5 says "pins go into the bag"; the counter
  shows pins, the bag shows coins. Keep it coin-based (bag size = coins) unless step A1/A2 decides otherwise.

## 3. How they alternate (to be replaced in step 2)
- `src/shared/Modules/CoreLadder.luau`: `CoreLadder.Next(ballStep, bagLevel)` returns the ONE next buy: Bag if
  `bag < ball`, else Ball, else Bag. `IncomePerMinute` (uses PinsSpread, 40 cap and FullClearMultiplier - must change
  with A1), `GiftCoins(minutes, ...)` (daily/playtime/level/crate gifts), `Name(kind, step)`, `BallStep`, `BagLevel` clamps.
- Server buy: `CoreLoopService` local `buy(player, kind)` via RemoteFunction `Remotes.CoreBuy` (kind "Ball"/"Bag");
  refuses when kind ~= Next. **No position check: buying works from anywhere.**
- Client shop: `client/Controllers/CoreShopController.luau` (412 lines): window with a 10-dot ball strip + 2 cards
  (BallCard, BagCard, each with a green BUY button -> `tryBuy` -> CoreBuy). Opens from the HUD **BALLS button**
  (`PlayerGui.BallsUI.Menu.BallsButton`, left column) OR by standing on the blue circle at the booth
  (`Config.CoreLoop.Shop.Position = (-17, 848.65, -3415)`, Radius 4.5; booth built by `CoreLoopService.buildShop`).
- Other readers of `CoreLadder.Next`: `EventController` ~555 goal bar ("Next: <name> x / y", "tap BALLS to buy"),
  `MilestoneController` ~54 (gift preview), `AffordController`.
- **"HUD ball list on the left" = the BALLS button -> CoreShopController window. It HAS buy buttons and buys from
  anywhere.** Step 2: when opened from the HUD (not on the booth circle), show it display-only (no BUY, "Buy at the
  shop booth" + beam), and add a server distance check in `buy` (same `Shop.Position/Radius` + slack).
  Goal-bar text "tap BALLS to buy" must change too.

## 4. Sell pad + SELL button
- Pad: `Config.CoreLoop.Sell.Position = (-37, 848.65, -3415)`, Radius 6, built by `CoreLoopService.buildStation`
  (model "SellStation"). Server loop every 0.2 s: anyone `onPad` -> `sell(player)` (whole bag -> Coins,
  CoreSells+1, LeaderboardService.RecordThrow(0, bag) for COINS THIS WEEK, SessionLog.Sell, `Remotes.CoreSold`).
- SELL button: `CoreHudController` ~140 (`plate(gui,"Sell",CORAL)`, place key "Sell"); `Activated` only turns on the
  green beam pointer to SellStation for 20 s (`guideUntil`). **No teleport today.** Step 2: add a RemoteEvent
  (e.g. `CoreSellTeleport`), server PivotTo the pad (rate-limited), and the existing pad loop sells.
- Spawn: `CoreSpawn` at `Config.CoreLoop.Spawn = (-37, 849.2, -3398)` (just behind the pad).

## 5. Buy booth
- Blue circle + booth: `CoreLoopService.buildShop()` (model `SkylineLanes.BallShop`, rebuilt every start), at
  `Config.CoreLoop.Shop`. Plaza props around it: `Config.CoreLoop.Plaza.Props` (ball racks copied from Main Street).
- Old stations hidden at server start: `Config.CoreLoop.HiddenStations = {"CrateShop","EggPad"}` -> moved by
  `hideCrateShop()` to `ServerStorage.CoreLoopHidden` (runtime only; in Edit mode they are still at
  SkylineLanes.CrateShop (97,859,-3418) and SkylineLanes.EggPad (91,859,-3448), east rail).
- Step 4/5 need: egg buys, pet slot buys, rebirth all "at the buy station" -> extend the booth (or a 2nd booth next
  to it for eggs) and make every buy remote check distance.

## 6. Counted pins today (step 1 target)
- Client holds THROW -> `ThrowController` ~1020 fires `Remotes.CoreThrow` every cooldown while on own lane.
- Server `ThrowService` local `coreThrow(player)` (~372): checks loaded, own lane (`LaneUtil.GetOwnedLane`),
  `LaneUtil.IsInThrowZone`, lane attribute `ReadyAt`, `RateLimit "CoreThrow"` (`CORE.ThrowRate` 0.33),
  cooldown = `CoreLoopService.Cooldown` (1.0 - 0.1 x ThrowSpeedLevel, floor 0.4).
- Count: `server/Modules/ThrowResolver.luau` `ResolveCore(average, spread)`: `wanted = avg x (1 +/- rand x 0.2)`,
  **`count = clamp(round(wanted), 1, PinRack.Count())` (40 cap)**, `Tier = "Strike"` if count >= 40,
  `Pins = pickPins(count)` (which rack indices fall).
- Coins: `count x PinValue(1) x (FullClearMultiplier 2 if clear) x product(CORE.Multipliers)` where Multipliers =
  {Mascots, Potion, Rebirth, Friends, Passes, RobuxBoost} from `MultiplierService.Coins(...)`; `Currency.Scale/Round`.
- XP: `count x XpPerPin x CORE.XpMultipliers` -> `ProgressionService.AddXP` (in the task.delay after RollTime).
  Also LeaderboardService.RecordThrow(count) -> LifetimePins, TotalThrows, TotalStrikes (clear), Analytics "Throw".
- `ThrowResult:FireAllClients({Core=true, Lane, UserId, BallId, PowerLevel, Pose, Count, Tier, Pins, RollTime,
  Coins, Paid, BagFull, Cooldown, ResetDelay, ...})`.
- Client pins: `client/Controllers/LaneVisuals.luau` builds `racks[lane] = PinRack.new(...)` for EVERY lane on
  every client (~937; 6 x 40 pins). `playCoreThrow` (~405): own throw = `rack:Knock` real physics (unanchored pins),
  others = `rack:Topple` (scripted). `ThrowFx.NumberPop` per pin (up to `PopsPerThrow` 8, value = paid/count) +
  a total pop (`paid`). `BigClear` 24 pins = shake + crash. `data.Pins` = list of rack indices, so `#data.Pins` is
  used as count -> **must stay <= 40 visual; send the real count separately** (`Count` already exists).
- `Shared.Modules.PinRack` (710 lines): core rack = 9 rows minus 5 = 40 (`Config.CoreLoop.Rack`), `PinRack.Count()`,
  pooled pins (`self.Pool`), `_takePin`, `_sweep` (debris `DebrisLife` 0.9 s, `DebrisCap` 60), `Refill`, `Topple`,
  `Knock`, `Reset`. Pins are client-only parts in the `Default` collision group.
- HUD counter: `CoreHudController.showCount(count, clear, full)` (~87) prints `"%d/%d"` with `PinRack.Count()`
  ("12/40") and "Cleared it! x2". Step 1: show `Currency.Format(count)` ("+1.2M"), drop "/40" and x2 text.
- Luck roll already +/-20% (`CORE.PinsSpread = 0.2`); there is no LUCKY! pop yet. Traits/Lucky trait FX exist in
  `Config.TraitFx.Lucky` + `Modules/TraitFx` (reusable look).
- Big numbers: `Shared.Modules.Currency` (`Format`, `Scale`, `Round`, `Zero`, `FormatMultiplier`; suffixes K..Qid,
  `Config.Numbers.Currencies` = Coins, Gems, WeeklyCoins, LifetimeCoins, Bag are Currency values). LifetimePins is
  a plain number - fine up to ~9e15, then precision loss (risk if pins go astronomic).

## 7. Eggs + pets
- Pets: `Config.Mascots` (line ~3312), 17 rows. Models: `ReplicatedStorage.PetModels` (Blaze, Bumper, ChromeBat,
  CloudBumper, Cosmo, Gus, Hambone, Kingpin, LanePup, NeonBat, Perfecto, Pinny, Splitz, Strikey, SunnyHam (shows
  "Moony"), TitanJr, WoodPup) + eggs `Egg_Alley`, `Egg_Arcade`, `Egg_Skyline` + `NeonStand`. Idle anim rows:
  `client/Modules/PetIdle.luau`. Views: `client/Modules/MascotView.luau`, hatch: `client/Modules/HatchScene.luau`.

| Egg (Config.Economy.Eggs, ~5094) | Shows as | Price | Zone gate | BonusScale | Pets (Egg =) |
|---|---|---|---|---|---|
| Alley | Neon Egg | 50K | 2 | 0.1 | Pinny (Unc, BaseBonus 0.2), LanePup (Unc), Strikey (Rare), Splitz (Rare), Hambone (Epic), NeonBat (Epic) |
| Neon | Neon Egg | 420K | 2 | 0.2 | none (EggReady false) |
| Arcade | Main Street Egg | 20M | 3 | 0.4 | WoodPup (Rare), ChromeBat (Epic), Kingpin (Leg), Blaze (Leg) |
| Skyline | Skyline Egg | 1.5B | 4 | 0.7 | CloudBumper (Epic), SunnyHam/Moony (Leg), Cosmo (Myth), Perfecto (Myth) |
| Volcano | Volcano Egg | 35B | 5 | 1.0 | none |
  No-egg pets: Gus (Common), Bumper (Unc) (cut, `BonusEgg = "Alley"`), TitanJr (Leg, boss drop, BonusEgg Skyline).
  `Config.EggLooks` has colours for Alley/Neon/Arcade/Skyline/Volcano (Volcano has NO model -> 4th egg = re-tint
  Egg_Alley/Neon id as the plan says). `Config.EggStands`: Alley -> Hub.EggPad, Arcade -> MainStreetLanes.EggPad,
  Skyline -> SkylineLanes.EggPad.
- Odds: `Config.Economy.Mascots.Odds` (Common 60 / Unc 25 / Rare 10 / Epic 4 / Leg 0.9 / Myth 0.1), rolled by rarity
  then a pet of that rarity in the egg (closest commoner if none). `Mascots.Chance(eggId, mascot, odds)`; LUCKY
  passes via `Store.Luck`/`Store.LuckyOdds`.
- Bonus: `Mascots.Bonus(mascot)` = (BaseBonus or `Economy.Mascots.Bonus[rarity]` = `Config.RarityPower[r].Pet`:
  Common 0.2, Unc 0.5, Rare 1.0, Epic 2.5, Leg 6, Myth 15) x egg BonusScale, x2 if Shiny. **Coins only**:
  `MascotService.GetMultiplier = 1 + Mascots.TotalBonus(equipped)` -> `MultiplierService.Coins().Mascots`
  (also counted for XP as "Pets"). No Pins/Bag/Speed stats exist. `Mascots.BonusText` = "x1.02" style.
- Shiny: `Economy.Mascots.ShinyMerge = 3`, `ShinyMultiplier = 2`; saved as `"<Id>_Shiny"` in `Mascots`
  (`Mascots.ShinyId`). Merge = `Remotes.MergeMascot` -> `MascotService.onMerge`, **only at the zone 3 fusion machine**
  (`atFusionMachine`: needs ZonesOpen >= `Config.Fusion.Zone` 3 and within 20 studs of MainStreetLanes.FusionStation).
  PETS panel has no MERGE button since batch C2 -> **merge is unreachable in the core loop**.
- Slots: `Mascots.Slots(rebirths, passExtra, kept)` = StartSlots 3, +1 at `SlotRebirths {5}`, min `PetSlotsKept`,
  max `MaxSlots` 6, + `Store.PetSlots` (+2 pass). Attribute `MascotSlots`. No coin-bought slots.
- Hatch: `Remotes.HatchEgg` (RemoteFunction) -> `MascotService.hatch`: `atEggStand` (Config.MascotFx.HatchRange 18 studs),
  `Mascots.EggUnlocked(egg, RankLevel, zone)` (egg.Rank / egg.Zone; **zone = Zones.Highest(ZonesOpen) = 1 in the
  core loop -> every egg is locked**), free eggs first (`FreeEggs`), TRIPLE HATCH pass, auto-delete (`AutoDelete`,
  `Config.AutoDelete`, `Remotes.SetAutoDelete`). Other remotes: `EquipMascot`, `EquipBestMascots`, `EggPrompted`,
  Studio `TestEgg`. `Mascots.Best(owned, slots)` = EQUIP BEST.
- Client: `MascotController.luau` (2,066 lines: PETS panel PETS/ITEMS tabs, slot strip with lock reasons, pet
  cards, hatch card, odds boards over stands `Config.EggOdds`, stand prompts), `MascotFollowController` (BulkMoveTo
  followers; perf fix 333e00e), `EggPromptController` (first egg prompt at 50K in zone 2 - zone-gated, off on roof).
- Hidden on the roof: `SkylineLanes.EggPad` (Skyline egg stand) and `CrateShop` (to `ServerStorage.CoreLoopHidden`).
  Egg gifts (daily/playtime) pay `CrateMinutes` coins instead. Pets panel text says pets come later.

## 8. Rank / XP / level systems and every gate or display
Data: save `XP`, `Rank` (tier 1-10), `RankLevel` (1-60), `BestLevel`, `BestRank`. Rules: `Shared.Modules.Progression`
(`LevelXP`, `LevelFromXP`, `GetRank`, `TierXP`), `Config.Economy.Ranks`, `Config.Ranks` (tier names, colours,
Multiplier), `Config.Trials`. Server: `ProgressionService` (`AddXP`, `refreshLevel` -> level-up gems
(`LevelGems` 2), `OnLevel` callbacks, `updateBadge`, `ResetForRebirth`, `PromoteRank`, `IsRankUpReady`),
`TrialService`, `MilestoneService` (level rewards via `ProgressionService.OnLevel`, `Config.Milestones`).
Where levels/XP/rank GATE or SHOW something (all need disabling in step 1, keep code):
- XP earned: `ThrowService.coreThrow` -> `ProgressionService.AddXP` (Config.CoreLoop.XpPerPin/XpMultipliers).
- HUD level bar: `HudController` ~230-310 (`rankBar`, HudKit place key `LevelBar`, "LV n" + XP fill, level-up pop
  `MomentKit.LevelUp`). Rank-up screen: `RankUpController` + `MomentKit.RankUp` (chat line too).
- Nameplate: `ProgressionService.updateBadge` = BillboardGui `Head.RankBadge` "LV 12  PRO" (rank colour).
- Throw pose: `ThrowRules.Style(RankLevel).Pose` (`Config.Throw.RankStyle`) in ThrowService ~144/~415 and
  ThrowController ~881/1053/1155 -> with no levels everyone stays at Pose 1 (scuffed). Suggest: pose from BallStep.
- Meter speed by rank: `ThrowRules.ChargeAt(t, Rank)` (old throw only, not core).
- Coin multiplier `Rank` (tier Multiplier) - already left out of `CORE.Multipliers`.
- Eggs: `Mascots.EggUnlocked` (egg.Rank) - no egg has Rank now; MascotService Studio TEST egg gives XP.
- Rebirth: `Rebirth.Level(rebirths)` (`Config.Economy.Rebirth.Levels {3,8,13,21,24}`) checked in
  `RebirthService.rebirth`, `RebirthController` ~409, `AffordController` ~88.
- Level rewards: `MilestoneService` (OnLevel) + `MilestoneController` ~301 next-level preview (`Config.Milestones`).
- Playtime/daily: `PlaytimeController` ~428 (egg unlock text uses RankLevel), daily/playtime scale by CoreLadder.
- Profile: `ProfileController` ~120/200/529 (level, XP sources), `AchievementService` ~66 (`BestLevel` achievement).
- Store: XP BOOST ladder + 2X COINS+XP pass texts (`StoreController` ~673/1126/1457), XP potions (`PotionService`,
  `Config.Potions` Boost "XP"; SpinController/RewardKit show XP potions).
- Kiosk (`KioskController` ~260/502, crate shop hidden), `MascotController` ~124/1736/1828 (lock reasons),
  `EggPromptController` (waits for RankUpKitUI), `LaneVisuals` ~901 (rank colour on lane/scoreboard),
  `LeaderboardService` ~206 (XP present check), Studio `TestPanelService` (+1 LEVEL, PASS TRIAL), Trial UI
  (`TrialController`, TrialService off via core).

## 9. Rebirth today
- `server/Services/RebirthService.luau`: `Remotes.Rebirth` RemoteFunction -> `rebirth(player)` **returns "Rebirth is
  coming soon" while CoreLoop.Enabled** (off). Old logic: needs `Rebirth.Level` + `Rebirth.Cost`; resets Coins,
  PowerLevel, `ProgressionService.ResetForRebirth`; Rebirths+1; ZonesOpen; `AwayService.Reset`; Analytics/SessionLog.
  Does NOT touch Bag, BagLevel, BallStep, ThrowSpeedLevel (step 6 must add).
- `Shared.Modules.Rebirth`: `Cost(n)` (`Config.Economy.Rebirth.Costs {15K,500K,4M,200M,1.5B}`, then x`CostGrowth` 3),
  `Level(n)`, `OpensZone`, `CoinMultiplier = 1 + Config.Economy.Formula.RebirthBonus(0.5) x n`, `XpMultiplier`.
  Rebirth multiplier is in `CORE.Multipliers` (coins) but NOT applied to pins.
- `RebirthController` (534 lines, REBIRTH window: 3 blocks go-back/keep/get, tap twice, full-screen moment) returns
  early in the core loop; HUD place key `Rebirth`. `Config.Economy.Rebirth.Enabled = true`.
- Pet slots by rebirth: `SlotRebirths {5}`. Free slow AUTO after rebirth 1 (`Config.AutoBowl.FreeAfterRebirths`).

## 10. Save fields + version
- `Config.Data.StoreName = "PlayerData_A4"`, `SchemaVersion = 34`, migrations in `server/Modules/SaveStore.luau`
  `migrate` (~74-200). Defaults = `Config.StartingData` (~344-420). `PlayerDataService` (Get/Set/Add/Spend/
  CanAfford/IsLoaded/OnLoaded; mirrors fields to player attributes).
- Core fields: Coins, Gems, Bag, BagLevel, BallStep, ThrowSpeedLevel, CoreThrows, CoreSells, Rebirths, Mascots,
  EquippedMascots, EggsHatched, FreeEggs, AutoDelete, PetSlotsKept, EggPrompted, LifetimePins, LifetimeCoins,
  WeeklyCoins(+Week), TotalThrows/Strikes/Perfects, PlayTime, SessionLog, Potions, Boosts, Purchases,
  CoinBoostLevel, XpBoostLevel, StarterPack, Cosmetics/EquippedCosmetics, Settings, daily/playtime/spin fields.
- Level fields (to keep, unused): XP, Rank, RankLevel, BestLevel, BestRank, BestStreak, PowerLevel, ZonesOpen,
  ZoneSeen, ZoneVisited, Onboarding, OnboardThrows, CratePity, Polish, OwnedBalls, EquippedBall, CratesOpened/Bought.
- New fields A5 will need (bump to v35+, start values, no migration of old data): e.g. `PetSlotsBought` (coin slots),
  per-milestone timing for logging, maybe `BestIncome`. `Mascots` is a dictionary {Id=count} (Shiny = "_Shiny" key).

## 11. The 6 lanes, lane hand-out, plots
- Studio (SkylineLanes): Lane1..Lane6 models, each 14.5 x 150 studs, 17 children (PitBack, Kickback x2, GutterCap x2,
  FoulLine, BallStart, Gutter x2, LaneFloor, Scoreboard, PinSpot, PitFloor, LaneBase, Approach, PinDeck, OwnerSign).
  Centres x = -78.5, -61.7, -44.9, -28.1, -11.3, 5.5 (16.8 apart). BallStart z -3451.7 (look -Z), PinSpot
  z -3568.2 (lane ~117 studs), Approach centre z -3441, size 13.4 x 19.4, floor y 848.65. Also `LaneLines`
  (x -37, z -3431, 101 wide), `Gantry` (x -37, z -3459, 108 wide, 23 high sign), `Edge` (roof edge 210 x 226 at
  (0,-3500)), `Leaderboards` wall (101,858,-3514), Design.lanes (owner's model).
- `server/Services/LaneService.luau`: on PlayerAdded `assignLane` = first lane with no `OwnerId` attribute in
  `CoreLoop.Folder`; sets `OwnerSign` text "LANE n · NAME"; places the character on the Approach on every spawn;
  releases on leave. **7th player gets no lane and cannot throw** (MaxPlayers shows 60 in Studio; check the live
  server size). No "plots" beyond lanes.
- `Shared.Modules.LaneUtil`: `GetLanes` (Lane* models with PinSpot + BallStart in the folder), `GetOwnedLane(userId)`
  (OwnerId attribute), `IsInThrowZone(lane, pos)` (Approach box + `Config.Lane.ThrowZoneMargin`), `GetLaneAt`, `ZoneOf`.
- Per-lane state on the lane model: `OwnerId`, `ReadyAt`, `GoldCenter`, status, `LaneEvent`/`LaneEventPin`,
  Golden Pin, modifiers, lane skin (LookController). Users of OwnerId/GetOwnedLane: ThrowService, LaneEventService,
  GoldenPinService, MultiplierService, LaneService, and clients ThrowController, LaneVisuals, EventController,
  FeverController, LookController, MilestoneController, RankUpController, StreakFx, TeleportController.
  `ReadyAt` users: ThrowService, ThrowController, LaneEventService, BossService.
- Collision groups: only `Default` registered. Balls are client-made, Anchored + CanCollide/Query/Touch false
  (`LaneVisuals.makeBall`), so balls already never collide. Pins (client PinRack) are Default and unanchor on Knock.

### Footprint proposal: ONE shared lane (step 3)
- Where: over the existing 6 lanes, x -86 .. 13 (98 studs wide), z -3431 (approach front) .. -3581 (pit),
  same floor y 848.65. Nothing moves in the plaza (sell pad, shop, spawn, cases, lounges are all at z > -3431 or
  x > 13). The Gantry sign (x -37, z -3459) already spans the full width - keep it as the lane's arch.
- Build from code at server start (`CoreLoopService`-style `buildSharedLane()`), model `SkylineLanes.SharedLane`:
  one wide `LaneFloor` plate (reuse the zone 4 lane wood colour/material + lane-skin plate logic), 2 outer gutters,
  one PinDeck/PitBack, an `Approach` 98 x 19.4, and a `Spots` folder of throw spots (12 spots, 8 studs apart,
  x = -81 .. +7, z -3441, each a small coloured ring with a number). Each spot = a `BallStart` + `PinSpot` pair
  (same x, z -3451.7 / -3568.2) so all lane code that needs "a lane" can get one per spot.
- Old lanes: move `Lane1..Lane6` + `LaneLines` into `ServerStorage.A5OldLanes` at runtime (never delete; Enabled flag
  `Config.CoreLoop.SharedLane.Enabled` brings them back). Studio edit file keeps them.
- Hand-out: server gives each player a spot index on join (`player:SetAttribute("ThrowSpot", n)`, least-used spot,
  spots can be shared once > 12 players); places the character there on spawn. Throw zone = the whole Approach
  (anyone standing anywhere on it throws from their own spot / nearest spot).
- Per-player instead of per-lane: `ReadyAt`, lane events, Golden Pin, fever, lane skin move to player attributes.
  Easiest path: keep `LaneUtil.GetOwnedLane(userId)` as the API but return the shared lane, and add
  `LaneUtil.SpotOf(player)` for positions. ThrowResult carries `Spot` (x offset) so clients draw others' balls at
  the right spot.
- Personal pin view: each client builds ONE PinRack (40 pins) at its own spot's PinSpot (not 6 racks). Others'
  throws: light ball only (or hidden per Settings "OTHER PLAYERS' EFFECTS"), no pins, no topple. Your own rack only
  reacts to your ThrowResult. That meets "max one pin set simulated per client".
- Collision groups (register on server + they replicate): `PinView` (local pins) collides with `PinView` + lane
  floor (Default) only, NOT with `Players`/characters; `Balls` collides with nothing; characters in `Players`
  group (set on CharacterAdded). Set `PhysicsService:CollisionGroupSetCollidable` on the server at start;
  client parts just set `.CollisionGroup = "PinView"`.
- Camera: `Config.CoreLoop.CameraBack/Height/Look` already frame "the head pin" - point them at your spot's rack.
- Width check: 12 spots x 8 studs; a 40-pin rack is 9 rows x 1.5 spacing = ~12 studs wide, so neighbouring racks
  overlap visually if both were drawn - fine, because each client only draws its own. Other players' balls roll
  down their own spot line through "empty" lane on your screen.

## 12. Nameplate + leaderboard
- Nameplate: only `Head.RankBadge` (ProgressionService.updateBadge) "LV n RANK". No rebirth display anywhere.
  Roblox player list hidden (`Config.Ui.HidePlayerList = true`, no leaderstats). VIP chat tag is drawn on the client (StoreController, TextChatService).
- Leaderboards: `server/Services/LeaderboardService.luau` (OrderedDataStores, `Config.Leaderboards`, StoreSuffix
  "_A4"; boards Pins (LifetimePins), Streak slot = MOST COINS EARNED (LifetimeCoins), Weekly (WeeklyCoins)); results
  in `ReplicatedStorage.Leaderboards` attributes; drawn by `client/Controllers/LeaderboardController.luau` on
  `SkylineLanes.Leaderboards` (east rail, x 101, z -3514); repainted sunny by SunKit.Board. Add a REBIRTHS board
  (Stat "Rebirths", Store "LB_Rebirths") and/or rebirth column, plus "R3" on the badge in step 6.

## 13. Risks / conflicts with how Roblox works
1. **Buying from anywhere**: CoreBuy has no distance check; any exploiter (or the HUD BALLS window) buys away from
   the booth. Every buy remote (CoreBuy, HatchEgg, slot buy, Rebirth) needs a server distance check.
2. **Remote throw rate**: with uncapped pins, one CoreThrow pays a lot - keep `RateLimit` + `ReadyAt`; move ReadyAt
   to the player when lanes are shared, or two players on one lane block each other.
3. **Number size**: pins can pass 2^53 if the curve is steep x rebirths x pets. Coins/Bag go through Currency (fine);
   `LifetimePins` and OrderedDataStore values must be integers < 2^63 - clamp or store log-scaled for leaderboards.
4. **Shared lane + >6 players**: today the 7th player has no lane. Shared lane fixes it; spots must allow sharing.
5. **Local pins vs other avatars**: unanchored local pins in Default can hit other players' characters on your
   screen (and your own avatar) -> PinView collision group. Characters must be put in a group server-side.
6. **Many balls on screen**: 12+ players throwing every 0.4 s = 30 balls/s per client; make others' balls a single
   anchored part with no VFX (Settings switch already exists) and cap how many are drawn.
7. **Pets unreachable**: eggs are zone-gated (ZonesOpen 1) and the stand/fusion are off-roof; step 5 must drop the
   zone gate in the core loop, put stands at the booth area, and move merge off the fusion machine (or bring a
   machine copy to the roof, like the plaza props).
8. **Rebirth multiplier currently coins only and off**; level gate in Rebirth.Level must go (coin only).
9. **Throw pose follows RankLevel**: with no levels, everyone uses pose 1 forever; map pose to BallStep.
10. **Studio place not saved by Claude**: build all world changes from code at runtime; old lanes moved, not deleted.
11. **Config size** (>200K chars): sync with UpdateSourceAsync; avoid stylua on Config (duplicate instances).
12. **Bag = coins vs "pins into the bag"**: decide in step 2; changing to pins would need a save migration (Bag is
    saved as coins).
13. Pet "Bag size"/"Throw speed" stats: throw speed is capped by `CooldownFloor` 0.4 s and RateLimit 0.33 s - a
    speed pet must still respect the floor; bag size bonus must apply in `CoreLoopService.BagSize` (published
    attribute BagSize) so HUD and server agree.
