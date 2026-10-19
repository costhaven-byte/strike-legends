# Project state (max 40 lines, read at the start of every session, update at the end)
Rules: STRIKE_LEGENDS_ADDENDUM_2.md > MASTER_PLAN.md > GAME_DESIGN.md (Addendum 2 replaces Addendum 1).
**Current milestone:** Phase 3 step 8a (mascots) PASSED 2026-10-19. Next 8b (shiny merge, strike reactions, lobby showcase, multiplier panel, AUTO_BOWL flag).
Restore point: git tag restore-step8a-before. Real game = cloud place 94254609600041.
**Weekly hour budget (optional):** not set yet. **Hours used this week:** 0.
## Exists and works
- 6 lanes, real physics pins (Standard/Golden/Golden Star meshes), lobby hub, kiosk, leaderboard wall, Vault (11 cases).
- New hold-and-release throw with a gold Perfect zone (jumps each throw, shrinks per strike). Only Perfects strike.
- Throw animation per ball level; strike juice (hit-stop, slow motion, number pops, payout pop, shake).
- 20-ball roster with real 3D models (light meshes, 51k triangles total), per-ball VFX and trails, 6 traits with effects.
- Rank levels 1-60 (save v12 RankLevel; Selim chose the plan's curve Config.Economy.Ranks, L2 = 180 XP, L60 = 382M): 6 levels per Pro Tier (Rookie 1-6 ... Hall of Famer 55-60), tier XP = its first level's XP (Progression.TierXP). Level-up = 2 gems + free Basic crate every 3rd level + popup; new tier = trial + RankUpUI. Old saves keep their tier (XP raised to it). Later levels need zone 2-6 XP. Studio-only remote TestXP (next level).
- 10 ranks + rank trials, named streak tiers, Golden Pin, 4 lane modifiers, gems (earned only), daily reward, leaderboards.
- Saving (save v7, old saves migrate), rate limits, analytics, Config with every number, economy simulator (tools/EconomySim.luau).
- Server times the hold (ThrowHold + ThrowRequest(holdSeconds), Config.Throw.HoldTolerance 0.1s); throw rate limit 2s.
- Session log (server/Modules/SessionLog): throws + PERFECT rate, printed on leave; new player's first session also logs a first-5-min reward timeline (printed at 5:00; Studio TEST: REPORT button). Analytics event PerfectRate.
- Rank trials: Amateur = 1 strike in 6; Amateur + Regular have no retry cooldown (row Cooldown = 0).
- Economy sheet: require(game.ServerStorage.Tools.EconomySim).Sheet(). Measured throw = about 3s (lane free 2.2s after release).
- Overcharge (Config.Throw.Overcharge, Enabled = true): red cap at the top of the arc (from 0.94); release there = 50% OVERCHARGE strike (x2 a Perfect, harder hit) or OVERCOOKED gutter (0 pins, streak over). Gold never enters the red.
- AssetSlots (Shared.AssetSlots): every sound slot; nil Id = borrows a stand-in sound. Strike slow motion 0.2s, hit-stop 0.05s (Addendum spec).
- Power Levels (save v8 PowerLevel; PowerLevelService + PowerUI button built in code): Config.Economy.PowerLevels live (sim units x10 = real coins). Power caps pins on non-PERFECT throws (LV1 = 6); PERFECT still strikes. Value multiplies coins. Looks per level: Config.Throw.Levels (size, power trail, sparks, fire, mega crash, aura, rainbow, deeper sounds, cleaner pose). Perfect now pays x2. Studio-only TEST +COINS button.
- First 3 minutes (OnboardingService/Controller, Config.Onboarding, save v9 Onboarding + OnboardThrows; old saves skip it): assisted first PERFECT (whole arc gold), BUY LV 2 callout, first bought crate 1,000 + exactly Uncommon, gift crate (exactly Rare, EQUIP button) at throw 65, camera swing to a locked showcase ball at throw 68, daily popup held until then. "Next goal" bar = closest of Power Level / gift / Basic crate (until CratesBought > 0, save v11; gold beam to the kiosk when affordable; after that first paid crate, BALLS button glows + arrow at the new ball's EQUIP) / free crate. Studio: Config.Onboarding.StudioNewPlayer = true (fresh, unsaved player each test).
- Curve (Addendum 2 spec): Curve X% = PERFECT window X% wider (ThrowRules.HookWidth(ball, size)); magenta edges on the gold. Heavy and Forgiveness also widen the gold (reported to Selim).
- Collection book (CollectionBookController, built in code): the BALLS button opens it (old Inventory grid retired, kept hidden as a template), one page per rarity, owned balls spin in 3D with EQUIP buttons, missing = silhouette + traits.
- DAILY button: grey + lock + throws-left countdown during onboarding; server refuses claims until Onboarding stage 3.
- 5 crates (Basic 1.6K, Bronze 9.2K, Silver 1M, Gold 87M, Neon 5.9B; Config.Economy.Crates), pity per crate (save v10 CratePity, attributes Pity_<Crate>_<Rarity>), first crate ever Rare+ (CratesOpened), ODDS button per shop card = every ball's chance. Duplicates = Polish (save Polish, +5% mult per level, max 10, then coins); book shows POLISH n/10. Gem sink (7b): book POLISH button buys the next level with gems (Config.Economy.Polish.GemPrice x level; Common 4..40), remote BuyPolish.
- Mascots 8a (save v13 Mascots {Id=count}, EquippedMascots, EggsHatched; MascotService, MascotController/FollowController, Shared.Modules.Mascots, Config.Mascots/EggLooks/MascotFx): Alley Egg 3,700 at rank level 3 (Config.Economy.Eggs), 12 mascots (2 per rarity), bonus = rarity bonus x egg BonusScale (Alley 0.1: Common +2% .. Mythic +150%), coins x (1 + total). 3 slots (+1 at levels 15, 30), EQUIP BEST, new mascot fills a free slot. PETS button (right of DAILY, shows from level 3) opens the panel (egg + ODDS, slots, all 12 with silhouettes). Lobby: old daily pad = Workspace.Hub.EggPad (pink, "MASCOT EGGS"), hold-to-hatch egg on the plinth. Daily stays on the DAILY button. Studio: TEST: EGG button in the panel.
## Placeholder
- Mascots = coloured balls with eyes; egg = spotted ellipsoid; hatch sounds borrow ReelTick/Reveal. All sounds (Creator Store picks); 3 overcharge stand-ins; PowerUp = RankUp stand-in. Bronze/Silver/Gold crate models = recoloured Basic; kiosk has Basic + Neon stations only. Gold/Neon and Levels 5-12 need zones 2+ (TEST button).
## Not built yet (from Addendum 2)
- Mascot 8b items, zones 2-6 (Neon..Volcano eggs locked until then), bosses, rebirth, return loops, monetization (off switch).
## Parked: Tournaments, ghost replays, spectator lanes, challenge lane (M11-M20 replaced by Addendum 2).
## Off-git (saved only in the Studio place file)
- Map, UI, ball/pin/crate models. Selim must save the place after Studio work.
## Last session
- 2026-10-19: Phase 2 done. Step 8 split 8a/8b; 8a built and checked in Studio (hatch, equip, Equip Best, follow, egg stand); owner asked to replace the daily pad with the new thing -> egg stand. Code synced into Studio by the http trick (Rojo not connected). PASSED.
- 2026-10-19: Step 7c: on-screen streak names = spec tiers (STREAK MASTER at 7, PERFECT RUN at 10, "6 IN A ROW!" between); overcook always ends the streak (Streak Saver no longer covers it); EconomySim plays live rules (PERFECT-only strikes, Config.Streaks, lane modifiers, Golden Pin; plan's StreakPerStrike + Lucky Throw removed) -> mid game slower (PL8 56 min, PL9 never in 150). Moving Pins shows as MOVING GOLD (slides the gold). Gold shrinks 5% per strike, never below 75%. PASSED.
- 2026-10-19: 7a retest treated as passed (owner said start 7b). Step 7b built (gems buy Polish in the book), PASSED.
