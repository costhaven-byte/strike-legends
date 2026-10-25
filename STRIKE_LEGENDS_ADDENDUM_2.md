# STRIKE LEGENDS: ADDENDUM 2 (final, revised after council and Selim feedback)

Give this to Claude Code together with STRIKE_LEGENDS_MASTER_PLAN.md. It REPLACES STRIKE_LEGENDS_ADDENDUM_1.md. Everything still valid from Addendum 1 is carried forward in section 9, so you need only this file plus the master plan. Where this file and the master plan disagree, this file wins.

Selim has no coding knowledge and cannot read your code. Explain everything in plain language. Keep reports short.

---

## 0. What changed since Addendum 1

1. **The throw is rebuilt.** Hold and release, auto-aim, no aim meter, no separate power meter. Curve is redefined (section 4). An optional "overcharge" second decision is built behind a config flag.
2. **Selim builds to a near-finished game before any outside testing.** There are no gates that block the build. Outside testing is a set of soft checkpoints you only remind him about, once, in one line (section 5). Do not slow or stop the build because no outside tester has played yet.
3. **The build is ordered by what matters most,** so the riskiest and most important parts (throw feel, first 3 minutes, visible upgrades) come first and the nice-to-haves come last (section 5).
4. **New verification rules for you.** Every milestone ends with a 2 minute plain-English test Selim can run. Nothing starts until the last one passes. Save a restore point before each milestone (section 3). This is because Selim cannot read code and Studio changes can break things silently.
5. **Solo playtest protocol** so Selim can judge the game honestly with nobody else to test it (section 5).
6. **Monetization is designed and built behind an off switch,** and Selim turns it on himself (section 7).
7. **Added:** a one sentence fantasy, a Roblox policy check as step zero, and a rule that fixing weak retention means fixing the first minutes, not adding systems.
8. **Cut or parked:** tournaments, ghost replays, spectator lanes and the challenge lane (section 8).
---

## 1. Status as of Oct 18

Built: milestones 1 to 9 plus 9.5 (ball traits, lobby showcase, rank trials, Golden Pin, rotating lane modifiers). New throw rebuilt. Only Selim has tested it and his own verdict is not evidence.
The master plan milestones 10 to 20 were handed to Claude Code. It may already have started Milestone 10. If so, say so in your first message and fold these changes in rather than redoing work. Do not start any new milestone from the master plan until Selim says so.
Art done in Claude Design: lane and alley, pins (including low-poly upload versions), lobby, all 20 balls (heavy files). Not designed: crates, coin and gem art, rank badges, icons, UI screens, mascots, zones 2 to 6, boss pins, sounds, marketing.
Playtest history: fun for about 5 minutes, too easy, too predictable, old throw too realistic.

---

## 2. The game, the goal and the guardrails

**Fantasy (draft, Selim edits):** You are a bowling legend rising from a dusty alley to a neon stadium, and every upgrade makes your ball and your strikes more ridiculous.

**Goal:** a throw that feels great in 30 seconds, and a loop that always has a next visible change within reach. Players stay, come back, and later choose to spend Robux to go further and look cooler.

**Guardrails (not optional):**
- Many players are children. Hook them with fun, progress, surprise and flexing, never pressure, guilt or tricks.
- No fake scarcity or fake countdowns. No guilt UI. No purchase prompts during throwing.
- Every paid random item shows its odds on screen. Robux sales stay off until Selim switches them on (section 7).
- No pay-to-win on skill measures. A free player can reach everything.
- No stealing or sabotage between players. Colorful but not cute.
- Progress is never lost. Old saves always load.

---

## 3. Working rules for Claude Code (verification)

Selim cannot read code, so you must make your work checkable.
1. **One small milestone at a time.** Keep each small enough to finish inside one session on a Claude Pro plan. If you think it will not fit, split it and tell Selim.
2. **Every milestone ends with a plain-English acceptance test** of 2 minutes or less that Selim can run in Studio ("press Play, throw 3 times, you should see X, Y, Z"). Write it, include the expected result, and include the common ways it could silently fail. Do not start the next milestone until Selim says it passed.
3. **Restore point before each milestone.** Tell Selim exactly how to save a copy of the place (or use version history) and name it. If a milestone breaks the game, roll back instead of patching on top.
4. **Keep PROJECT_STATE.md** (max 40 lines): what exists, what is placeholder, what is parked, the current milestone, the optional weekly hour budget, and hours used this week. Read it at the start of every session and update it at the end.
5. **Selim's weekly hour budget** (optional, he sets it) lives in PROJECT_STATE.md. He has time for this project, so do not nag about it. Just keep each session's plan realistic for what he said he has.
6. Report "Placeholders still in use" at the end of each milestone.

---

## 4. The new throw (replaces master plan Milestone 11 steps 1 and 2)

Assumed spec. Verify against the real build, report differences, and do not revert the new throw to the old one.
- Press and hold to charge, release to throw. Auto-aim toward the pins. No aim meter, no separate power meter.
- The client sends only "hold started" and "released". The server times the hold, clamps it, and rate limits throws based on the measured minimum throw cycle.
- A visible Perfect window on the hold bar. Release inside it for Perfect (crit x2.0). `throwQuality` still runs 0.6 to 1.0. If the real throw has no skill element left, tell Selim.
- Strike chance depends on Power versus pin count and release quality.
- Strike moments stay short: banner under 1 second, slow motion at most 0.2 seconds, hit-stop about 0.05 seconds. The next throw is possible almost immediately.
- Cyan aiming arrows are decoration only.

**Curve is redefined.** Curve X% now makes the Perfect window X% wider (not a dice roll). This keeps skill as skill and makes the trait easy to see and feel. Report how Heavy, Blast and Streak Saver behave under the new throw.

**Skill measures rule:** traits that change skill outcomes (Curve, Streak Saver) never count toward any skill leaderboard. Skill leaderboards, if built later, are separate from coins and rank.

**Second decision: overcharge (build it now, behind a config flag).** Holding past the Perfect window gives a bigger blast (more pins hit, bigger payout) but raises the chance of a wasted throw. Safe release versus greedy release is one real decision per throw. Selim can flip the flag to compare the two versions. Report how it feels with the economy numbers, and keep the flag so he can choose which version ships.

Onboarding: the first throw is assisted, a guaranteed Perfect and Strike, with a short prompt for hold and release.

---

## 5. Build order and checkpoints

**Step 0. Policy check (before any crate work).** Search for the current Roblox rules on paid random items, odds disclosure, age and region limits, chat and child safety, and monetization limits for younger players, plus the platform cut and payout (DevEx) requirements and verification. Give Selim a plain summary of what applies to this game. If you cannot verify something, say so and tell Selim to check.

**Build order.** One milestone at a time, each with its own 2 minute test (section 3). Importance first:

**Phase 1: Core feel (most important).**
1. Foundation, small: `GameConfig` (every number in one place), server authority for earnings, reliable saving with old saves still loading, and one simple session log (join time, leave time, throws, crates opened, Power Level reached). Also a plain "economy sheet": a script that prints, in a short table, how long each upgrade takes to reach using the measured throw time. Hand-tune numbers from it.
2. Throw feel and juice (Milestone 11): pin destruction, impact, number pops, coin vacuum, strike moment, audio slots, plus the overcharge flag.
3. Power Levels 1 to 12 in zone 1. Each level visibly and audibly changes the ball (scale, glow, trail, impact, sound), and the change shows on the very next throw.
4. The first 3 minutes script and onboarding (section 6). Do this early because it is cheap and it decides whether anyone stays.

**Phase 2: The chase.**
5. All 20 balls with placeholder visuals (colored spheres with a rarity glow), traits working under the new throw, collection book.
6. All 5 crate tiers, pity, odds screen, duplicates and Polish Points (section 9.4).
7. Ranks, rank trials, existing streaks, lane modifiers and the Golden Pin extended (section 9.5).

**Phase 3: The long loop.**
8. Mascots (pets) as multipliers.
9. Zones 2 to 4 as `ZoneTheme` configs, then boss pins. (Changed 2026-10-22, see "Launch with 4 zones" below.)
10. Rebirth.

**Launch with 4 zones (Selim, 2026-10-22). This overrides every "zones 2 to 6" / "6 zones" in this file and the master plan.**
- The game publishes with zones 1 to 4 only: Back Alley (1), Neon Lanes (2), Main Street Lanes (3, a regular real-life bowling alley; replaces Arcade Arena, Selim 2026-10-22), Skyline Lanes (4). Zones 5 (Volcano Strike) and 6 (Cosmic Alley) are not built for launch; they can come later as an update if Selim asks.
- Step 9 order: 9a zones 3 and 4 (Selim's designs, then build), 9b boss pins in zones 1 to 4.
- Then an economy pass (part of step 9, before rebirth) so the game ends cleanly at zone 4 (and rebirth's coin cost fits a zone 3 player): rank levels up to 60 must be reachable without zone 5 and 6 XP; the Volcano Egg (zone 5) is hidden or moved; the removed Neon crate and the Gold crate get a home in zones 3 or 4; prices checked with the simulator.
- Step 10 rebirth: available once the player reaches zone 3 (Selim 2026-10-22). Zone 3 and 4 entry levels stay 12 and 22 (Selim 2026-10-22, after the simulator showed 15/25 = zone 4 at about 5 hours).
- Nothing about zones 5 and 6 is deleted from the data tables; they just stay locked and hidden (Config.Zones.BuiltZones).
- Boss change (Selim 2026-10-22, NOT started, wait for go): bosses are not on every zone's lane. The boss unlocks at zone 4 and lives in its own separate area, reached by helicopter from zone 4 (zone 4 already has a helicopter; needs a flight animation). The boss appears every 45 minutes. This replaces "9b boss pins in zones 1 to 4" and master plan M15's "every 15 throws".
- Pet fusing (Selim 2026-10-22): a walk-up station in the world like the daily spin wheel, unlocking at zone 3. Not started.

**Phase 4: Return loops and social.**
11. Daily reward (7 days with a grace day), "while you were away" coins (capped at 8 hours), friend coin bonus (10 percent per friend, capped at 50 percent), weekly featured ball in crates (odds shown), server banner on Legendary or Mythic pulls, rarity glow on the equipped ball visible to others.

**Phase 5: Money and polish.**
12. The monetization layer behind the off switch (section 7), final sounds, full ball models after mesh reduction (section 9.6), thumbnail and title.

**Soft checkpoints (never block the build).** At the end of Phase 1, Phase 2 and before turning monetization on, tell Selim once, in one line, that watching anyone play for 10 minutes without helping would be worth more than another day of building. Then carry on. Do not repeat it.

**Solo playtest protocol (Selim, with nobody else to test).** Play fresh sessions of 20 minutes with a stopwatch and a phone note: write down the exact minute you first feel bored or tempted to quit, and what you were doing. Screen record one session and watch it back, because replays show things you miss while playing. Ask: did I want another throw right after a strike, did the last upgrade feel different, do I know my next goal. Use Studio's multi client test to check that two players do not break each other (this checks that the code works, not whether the game is fun). When he is ready, any 10 minutes with anyone he knows, watching without helping, beats all of the above.

**Launch (Selim decides when).** Soft launch with a proper thumbnail and title. Retention numbers below about 100 players are noise, so seed it through friends, Discord groups and short clips of the throw. Target day 1 retention of 20 percent or better and session length trending up. If retention is weak, fix the first minutes and the throw feel before adding any system.
---

## 6. The first 3 minutes (highest priority content)

One scripted path, not a system:
- 0:00 The player lands on a lane. No menus. Prompt: hold and release. The first throw is an assisted Perfect Strike with full juice.
- 0:20 to 1:00 Power Level 2 is affordable after about 6 throws, with a glowing BUY prompt. Buying it visibly and audibly changes the ball on the next throw.
- About 2:00 the free first crate, Rare or better, with a short opening animation and an equip prompt.
- About 2:30 Power Level 3 or 4 within reach, with a "next goal" bar always on the HUD.
- By 3:00 the player has seen a locked rare ball in the lobby display case (the chase) and has a clear next goal.
Rules: fewer, bigger, visible changes beat frequent small numbers. Every purchase must change what the player sees and hears. Juice is the headline, numbers are the footnote.
Surprise, kept small in Phase 1: the Golden Pin and existing lane modifiers, plus honest near-miss feedback (show the real outcome clearly, never rig it). A Jackpot Pin (about 1 throw in 40, x10 coins) is allowed if it is a small change.
Optional if trivial: other players can see your equipped ball with its rarity glow.

---

## 7. Monetization (built behind `MonetizationEnabled = false`, Selim flips it)

Principle: Robux buys speed, convenience and looks. Skill measures cannot be bought. A free player is never blocked.

**Owner changes (Selim, 2026-10-25, step 12a rework; these override the lists below):**
- Two doubling ladders, bought in order, each step doubles, top = x16 (owner, later the same day): COIN BOOST x2/x4/x8/x16 for 3/8/15/30 R$, XP BOOST x2/x4/x8/x16 for 15/30/50/100 R$ (saved CoinBoostLevel / XpBoostLevel, save v22).
- Auto Bowl (499 R$): every auto throw is a strike, without the PERFECT x2; auto throws never change the streak and never count for rank trials or the 3-strike challenge. This relaxes "skill cannot be bought" for Auto Bowl only (Selim's call).
- Passes: 2X COINS + 2X XP (stacks with potions), bigger VIP (+25% coins and XP, 25 daily gems, gold ball trail, chat tag), LUCKY x1.5 and SUPER LUCKY x2 (stack to x3; Rare and better; odds screens show the boosted odds), TRIPLE HATCH (3 eggs or crates at once), +2 PET SLOTS. Numbers in Config.Monetization.

Gamepasses (prices are placeholders in `GameConfig`):
- 2x Coins.
- Auto Bowl: the game throws for you at a slower pace than manual, with no Perfect bonus.
- VIP: small coin bonus, chat tag, exclusive trail.
- More Mascot Slots.

Developer products (repeatable): timed 2x coin boost (15 minutes), gem packs in three sizes, and a one time Starter Pack (a Rare ball, a 30 minute boost and gems), shown once after the player's first 10 minutes.

Cosmetics (gems or Robux, no stat effect): trails, strike banners, pin explosion effects, lane skins.

Suggested price ladder: 49, 99, 199, 399, 799, 1599 Robux.

Where spending feels natural: at a hard stop ("next zone needs Power Level 8", with an optional boost), and after a good moment such as a rare pull (a cosmetic offer for the new ball).

Rules that always apply: no prompts mid-throw, none in the first 10 minutes except the Starter Pack, at most one soft prompt per 5 minutes and always dismissible, no fake timers, no guilt UI, odds on every paid random item. Re-check the Step 0 policy summary before turning any sale on. Selim note: payouts have age and ID verification requirements and Roblox takes a share, so check the current numbers before counting on income.
---

## 8. Parking lot (not planned, only if Selim asks)

Weekly skill tournaments, ghost replays, spectator lanes, a challenge-a-friend lane. If Claude Pro limits force cuts, cut Phase 4 items before Phases 1 to 3.
---

## 9. Carried forward from Addendum 1

### 9.1 The placeholder rule
Never wait for art. Build every system with plain placeholders (colored Parts, plain UI frames in the neon palette). Create one module, `AssetSlots`, mapping every art slot name to an asset ID or nil (nil means placeholder). Procedural effects (particles, camera shake, beams, glows) are built in code now.

### 9.2 The ball roster (the full 20, as built, do not rename or retune)

| Ball | Rarity | Mult | Trait |
|---|---|---|---|
| Rookie Ball | Common | 1.0 | none (starter) |
| Bubblegum | Common | 1.05 | Lucky 10% |
| Lime Twist | Common | 1.1 | Curve 5% |
| Tangerine | Common | 1.15 | Heavy 5% |
| Deep Ocean | Common | 1.2 | Gem Hunter 1% |
| Electric Blue | Uncommon | 1.3 | Curve 12% |
| Toxic Slime | Uncommon | 1.4 | Blast 15% |
| Sunset Strip | Uncommon | 1.5 | Lucky 30% |
| Frostbite | Uncommon | 1.6 | Heavy 15% |
| Magma Core | Rare | 1.8 | Blast 35% |
| Galaxy | Rare | 2.0 | Lucky 75% |
| Thunderstrike | Rare | 2.2 | Streak Saver (every 60s) |
| Phantom | Rare | 2.5 | Curve 25% |
| Plasma Orb | Epic | 3.0 | Heavy 40%, Gem Hunter 6% |
| Nebula | Epic | 4.0 | Lucky 125%, Gem Hunter 8% |
| Inferno | Epic | 5.0 | Blast 50%, Curve 35% |
| Golden Strike | Legendary | 7.0 | Lucky 200%, Gem Hunter 15% |
| Dragon's Eye | Legendary | 10.0 | Blast 75%, Streak Saver (every 45s) |
| The Void | Mythic | 20.0 | Curve 60%, Streak Saver (every 30s) |
| Supernova | Mythic | 25.0 | Blast 100%, Heavy 80% |

Six rarities: Common (5), Uncommon (4), Rare (4), Epic (3), Legendary (2), Mythic (2).

### 9.3 Power Levels (master plan section 3.3 becomes Power Levels, not 12 balls)
Same 12 rows, prices, Power and value mult as starting values. A Power Level is an upgrade bought with coins, in order. It sets Power (pins per throw) and a payout multiplier. The equipped ball supplies its own mult and trait on top. Ball mult (up to x25) and Power Level mult (up to x75) multiply, so tune the Power Level mult down if growth is too fast, and never touch ball mults. Each level changes how the equipped ball looks and sounds, in code. The change must show on the very next throw.

### 9.4 Full crate odds (every row sums to 100)

| Crate | Common | Uncommon | Rare | Epic | Legendary | Mythic |
|---|---|---|---|---|---|---|
| Basic | 70 | 25 | 5 | 0 | 0 | 0 |
| Bronze | 45 | 35 | 17 | 3 | 0 | 0 |
| Silver | 20 | 35 | 32 | 11 | 2 | 0 |
| Gold | 0 | 20 | 45 | 28 | 6.5 | 0.5 |
| Neon | 0 | 0 | 40 | 38 | 18 | 4 |

Equal chance within a rarity. Pity: Basic and Bronze Rare or better every 10 pulls, Silver and Gold Epic or better every 20, Gold and Neon Legendary or better every 80. Duplicates become Polish Points (each level +5 percent of that ball's mult, max level 10), then coins once maxed. The first crate ever is Rare or better. The collection book is 20 balls, one page per rarity. Every ball must be obtainable from at least one crate. The odds screen shows odds per rarity and per ball. Existing crates are Basic and Neon, and the other three start as recolored copies.

### 9.5 Ranks and existing systems
- 10 named Pro Tiers: Rookie, Amateur, Regular, Club, Semi-Pro, Pro, Elite, Master, Legend, Hall of Famer. Report the real XP curve before changing anything. Levels 1 to 60 sit inside the tiers (about 6 each). Rank trials stay at tier changes only (9 trials). Never reset rank progress.
- Gems (Gem Hunter trait, Bonus Gems modifier) are earned only for now. Propose one simple gem sink (Polish Points or crate keys).
- Streak tiers: Double (2), Turkey (3), Hambone (4), Wild Turkey (5), Streak Master (7), PERFECT RUN (10).
- Lane modifiers: Double Coins, Moving Pins, Bonus Gems, Giant Pins.
- Traits: Curve, Blast, Streak Saver, Lucky, Gem Hunter, Heavy.
- Golden Pin and the lobby showcase from 9.5. Extend, do not duplicate.

### 9.6 Ball model weight
The 20 ball files are about 21,000 to 134,000 triangles each (Dragon's Eye about 134,000, Golden Strike about 82,000, Supernova about 47,000). Roblox limits a single mesh to roughly 20,000 triangles and phones need far less. Pins were already reduced (StandardPin from 16,800 faces to 736). Target 1,500 to 3,000 triangles per ball. Tell Selim what you can reduce and what Claude Design must re-export. If you cannot reduce meshes, say so. Until then use placeholder balls. The Void and Supernova are .obj, the rest .glb, and the 5 Common balls are in one file (common-balls.glb).

### 9.7 Art and placeholders by milestone
| Milestone | Art needed | What to do |
|---|---|---|
| 10 Foundation | None | Build now (small version) |
| 11 Throw feel | Sounds only | Effects in code. List the sounds needed (name, feel, length). Selim picks them in Studio's Toolbox. Do not pick sound IDs yourself. |
| 12 Zones and Power Levels | Zones 2 to 4 (launch; 5 and 6 later) | Zone 1 is the existing Neon Alley. Others are `ZoneTheme` configs later. |
| 13 Streaks | UI look | Plain frames |
| 14 Mascots | About 12 plus an egg | Colored sphere with eyes per rarity (later phase) |
| 15 Boss pins | Boss models | Scaled StandardPin with a health bar (later phase) |
| 16 Crates, ranks, book | 3 crates, kiosk, book, badges, icons | Recolored crate, plain 2D book (later phase) |
| 17 to 20 | Rebirth, daily, quest UI | Plain UI (later phase) |

Playtests of placeholder art will be skewed. Say so in each hand-off report.

---

## 10. First message to Selim (before building anything)

1. Has Milestone 10 or later already started? What exists?
2. Confirm the new throw spec in section 4, including whether the Perfect window exists, and report differences.
3. The real measured time per throw.
4. Which art groups are already imported into the game.
5. The real rank count and XP curve, how gems work today, and the real streak and lane modifier names.
6. How you plan to reduce the ball models, or that you cannot.
7. The Step 0 policy summary.
8. Create PROJECT_STATE.md and ask Selim for his optional weekly hour budget.
