# STRIKE LEGENDS: MASTER PLAN (Milestones 10 to 20)

Hand this whole file to Claude Code. It replaces the earlier MILESTONES_HOOK.md (milestones 10 to 13). Everything in that file is folded in here.

---

## 0. READ THIS FIRST (rules for Claude Code)

### Who you are working for
Selim has no coding knowledge. Explain everything in plain language. No jargon unless you explain it in one sentence. He is busy, so keep reports short.

### Before you change anything
1. Read GAME_DESIGN.md, CLAUDE.md and ASSET_PROMPTS.md fully.
2. Inspect the current game through the Roblox Studio MCP server: every script, every system, every UI.
3. Write a short "State of the game" summary (max 25 lines): what exists, what each system does, what is built through milestone 9.5.
4. Map every system in this plan to what already exists. Extend existing systems. Do not rewrite or delete something that works. If something must be replaced, tell Selim why and wait for a yes.
5. Show Selim your plan for Milestone 10 in 5 to 8 lines and start.

### How to work
- One milestone at a time. Never start the next one until Selim says he playtested and approves.
- After each milestone, send a hand-off report in this format:
  - What changed (plain language, 5 lines max)
  - What to playtest (a short checklist of things Selim should do in the game)
  - What feels uncertain or may need tuning
  - Any decision you need from him
- Update the changelog section of GAME_DESIGN.md after each milestone. Keep CLAUDE.md short and current.
- Back up before every milestone (save a copy of the place file or commit if version control is set up).
- Never delete player data fields, never rename saved data keys without a migration step that keeps old saves working.

### The core idea in one paragraph
The game currently feels like realistic bowling with a thin reward layer. It is fun for about 5 minutes. The best Roblox simulators work differently: the action itself is simple, and the fun is that every purchase makes everything bigger, louder and faster, with several systems stacking multipliers on each other. So we turn Strike Legends into a simulator where bowling is the "swing". Realism is gone. Pins explode, numbers pop, lanes get bigger, balls get absurd, mascots multiply earnings, boss pins demand better balls, and rebirth resets you for a permanent boost. Crates and pets add surprise on top of a strong spine of guaranteed progress.

---

## 1. DESIGN PILLARS (judge every decision against these)

1. **Every purchase must change how the next throw looks, sounds and pays.** If a purchase only changes a number in a menu, it fails.
2. **Always one goal within reach.** At any moment the player must see something they can reach in roughly 10 to 30 throws early on, growing longer later.
3. **Deterministic spine plus random spice.** Buying the next ball tier is guaranteed (like buying the next katana). Crates, mascots and lucky throws are random bonuses on top.
4. **Many loops at different time scales.** Seconds (throw), minutes (buy next ball, hatch mascot), tens of minutes (boss pin, new zone), hours (rebirth), days (daily streak, featured ball).
5. **Juice over realism.** Big, readable, satisfying. Think cartoon arcade.
6. **Skill is a bonus, not a chore.** A perfect throw pays a crit. A sloppy throw still pays well.
7. **Never trap the player.** No fake scarcity, no countdown pressure on purchases, no dark patterns. The player should leave feeling like they made progress, and want to come back.
8. **Server decides results.** Clients only show visuals.

---

## 2. TARGET PLAYER TIMELINE (what we are tuning toward)

These are targets for a brand new player. The economy simulator (Milestone 10) must be used to check them.

| Time in game | What should happen |
|---|---|
| 0:00 to 0:30 | Player spawns, sees one arrow pointing at the lane, throws. No tutorial screen, no wall of text. |
| 0:30 | First throw is assisted and clears all pins: a big STRIKE with full juice. |
| 1:30 to 2:00 | Player can afford the first crate and the second ball tier. First crate always gives Rare or better. |
| 4:00 to 5:00 | Rank 3. First mascot egg affordable. Player sees the locked Zone 2 and the rank needed. |
| 8:00 to 10:00 | Rank 5. Zone 2 unlocks (30 pins). Feels like a big jump. |
| 15:00 to 20:00 | First boss pin appears and is beatable with a ball the player just bought. |
| 30:00 to 45:00 | Zone 3 (100 pins). Collection book has visible gaps. Daily reward shown with Day 7 prize visible. |
| 60:00 to 90:00 | First rebirth becomes available. This is the moment where the player thinks "restart for a permanent boost?" |
| Day 2 | Daily reward, 3 daily quests, featured ball reason to return. |

Session length goal: 20 to 45 minutes. If the average session is under 10 minutes, something in the first hour is failing.

---

## 3. STARTING NUMBERS (all go in one config file)

All numbers below are starting values. They live in ONE config module (call it `GameConfig`) so Selim and Claude Code can tune them without touching game logic. Nothing in this table may be hardcoded elsewhere.

### 3.1 Core formula

```
pinsHit        = min(lanePinCount, ballPower * throwQuality)
baseCoins      = pinsHit * zonePinValue
totalMultiplier= ballValueMult
                 * (1 + sum(equippedMascotBonuses))
                 * (1 + 0.03 * rank)
                 * (1 + 0.5  * rebirths)
                 * strikeStreakMult
                 * activeBoostMult
                 * critMult
coinsEarned    = floor(baseCoins * totalMultiplier)
xpEarned       = floor(pinsHit * zoneXpPerPin)
```

- `throwQuality` ranges from 0.6 (bad timing) to 1.0 (good). A Perfect throw sets 1.0 and triggers critMult 2.0.
- A **Strike** means all pins cleared (pinsHit == lanePinCount).
- `strikeStreakMult` = 1 + 0.1 * consecutive strikes, capped at 3.0. A non-strike resets it to 1.0 (breaks hard).
- Show the total multiplier on screen at all times as a clear "x" number that visibly goes up when something stacks.

### 3.2 Zones

| Zone | Name | Pins | Pin value | XP per pin | Rank needed |
|---|---|---|---|---|---|
| 1 | Starter Alley | 10 | 1 | 1 | 1 |
| 2 | Neon Lanes | 30 | 5 | 2 | 5 |
| 3 | Arcade Arena | 100 | 25 | 4 | 12 |
| 4 | Skyline Lanes | 300 | 125 | 8 | 22 |
| 5 | Volcano Strike | 1,000 | 600 | 16 | 35 |
| 6 | Cosmic Alley | 3,000 | 3,000 | 32 | 50 |

Each zone has its own theme, music, pin look and background. (Use existing assets where possible; request new ones from Claude Design via ASSET_PROMPTS.md.)

### 3.3 Ball Shop ladder (guaranteed progression spine)

| Tier | Price (coins) | Power (pins per throw) | Value mult |
|---|---|---|---|
| 1 Starter | 0 | 6 | x1.0 |
| 2 | 100 | 10 | x1.5 |
| 3 | 500 | 16 | x2.0 |
| 4 | 2,500 | 30 | x3.0 |
| 5 | 12,000 | 50 | x4.5 |
| 6 | 60,000 | 100 | x7.0 |
| 7 | 300,000 | 180 | x10 |
| 8 | 1,500,000 | 350 | x15 |
| 9 | 7,000,000 | 700 | x22 |
| 10 | 35,000,000 | 1,400 | x33 |
| 11 | 175,000,000 | 2,800 | x50 |
| 12 | 1,000,000,000 | 5,000 | x75 |

Design intent: a ball needs Power >= pin count to strike a lane. So you cannot strike Zone 3 (100 pins) before Tier 6. That is the soft gate that makes each zone feel earned. A weaker ball still earns coins on a big lane, just without strikes.

Each tier is visibly different: size, glow, trail, impact effect, sound. Tier 8 and above must look absurd and powerful.

### 3.4 Crate balls (random spice, collectible)

Crates drop special balls with Rarity, a Trait, and a bonus on top of the tier power spine. Crate balls are sidegrades or upgrades, never required to progress.

| Crate | Price | Ball Power band |
|---|---|---|
| Basic | 100 | 6 to 16 |
| Bronze | 1,000 | 16 to 50 |
| Silver | 15,000 | 50 to 180 |
| Gold | 250,000 | 180 to 700 |
| Neon | 5,000,000 | 700 to 3,000 |

Odds per crate (must be shown on screen, see section 6):

| Crate | Common | Rare | Epic | Legendary | Mythic |
|---|---|---|---|---|---|
| Basic | 80% | 17% | 3% | 0% | 0% |
| Bronze | 60% | 30% | 9% | 1% | 0% |
| Silver | 40% | 40% | 17% | 3% | 0% |
| Gold | 20% | 45% | 28% | 7% | 0% |
| Neon | 0% | 40% | 45% | 14% | 1% |

Rarity gives a value bonus on top of the power band: Common x1.0, Rare x1.2, Epic x1.5, Legendary x2.0, Mythic x3.0. Each ball has one Trait (use the traits already built in 9.5, add more).

Pity: guaranteed Epic or better after 20 pulls of a tier without one. Guaranteed Legendary or better after 80 pulls in Gold and Neon. Counter shown to player.

Duplicates convert into Polish Points. Polish Points upgrade any owned ball by levels (each level +5% value, max level 10). No pull is ever wasted.

### 3.5 Mascots (pets)

Mascots are small companions that follow the player and add to the multiplier. Hatched from Mascot Eggs bought with coins.

| Egg | Price | Unlock |
|---|---|---|
| Alley Egg | 400 | Rank 3 |
| Neon Egg | 6,000 | Zone 2 |
| Arcade Egg | 90,000 | Zone 3 |
| Skyline Egg | 1,500,000 | Zone 4 |
| Volcano Egg | 30,000,000 | Zone 5 |

Rarity odds: Common 60, Uncommon 25, Rare 10, Epic 4, Legendary 0.9, Mythic 0.1.
Bonus when equipped (additive pool): Common +0.2, Uncommon +0.5, Rare +1.0, Epic +2.5, Legendary +6, Mythic +15.
Equip slots: start with 3, expand with ranks and rebirths up to 6.
A "Equip Best" button.
Duplicates can be merged: 3 of the same mascot make a Shiny version with 2x bonus.
Each mascot has a small unique idle animation and a reaction when the player strikes.

### 3.6 Ranks

- Rank XP curve: `xpToNext = floor(50 * 1.35 ^ (rank - 1))` through rank 30, then a flatter curve so ranks 30 to 60 feel steady.
- Ranks 1 to 10 should come fast. Early density of rewards matters more than late density.
- Every rank-up grants a concrete reward (see Milestone 16). A rank-up with only coins and XP is not allowed.

### 3.7 Rebirth

- Name it "Go Pro Tour" (a rebirth is one tour). Tune the name later.
- Available at rank 20 for the first one. Each rebirth needs a higher rank and a coin cost that grows by about 1.6x.
- Resets: coins, rank, zone progress, ball shop tier. Keeps: collected crate balls, mascots, Polish Points, cosmetics, collection book, achievements.
- Grants: permanent +0.5 to the rebirth multiplier, plus one new unlock per rebirth (extra mascot slot, new crate tier, new trail, new title).
- Also adds a permanent "start faster" perk: after rebirth, the first 5 ball tiers can be re-bought at 10% of their price.

---

## 4. MILESTONES

Each milestone has steps, a "done when" check and a "playtest question" for Selim.

---

### MILESTONE 10: Foundation (config, server authority, economy simulator)

Goal: make the game tunable and trustworthy before adding features.

Steps:
1. Create `GameConfig` containing every number from section 3. Refactor existing hardcoded numbers (coin payouts, XP, crate prices, odds, rank costs) to read from it.
2. Make sure all earnings, purchases, crate rolls and rank changes are computed on the server. Clients send "I threw" with timing data only. Validate and rate-limit throws (max about 1 throw per 1.5 seconds per player).
3. Make saving robust: retry on failure, save on leaving, auto-save every 60 seconds. Add new data fields with defaults so old saves still load.
4. Build an **economy simulator**: a script (run in Studio or outside it) that simulates an average player using the config. It should print: time to buy each ball tier, time to each rank, time to unlock each zone, time to first rebirth, assuming 1 throw every 4 seconds and 70% of throws being good timing. Compare against the timeline in section 2 and report mismatches.
5. Adjust config values until the simulator matches the section 2 timeline. Report the final numbers to Selim in a short table.
6. Add a simple analytics layer (see section 7) with events stubbed, so later milestones can log to it.

Done when: changing a number in `GameConfig` changes the game without touching other scripts, old saves still load, and the simulator output matches the timeline within about 20%.

Playtest question: "Does the game still play the same as before?" (nothing should visibly change yet).

---

### MILESTONE 11: Throw Feel and Juice

Goal: make a single throw feel great even with zero progression. This is the biggest fix for "the throw isn't fun."

Steps:
1. **Speed up the throw cycle.** Aim and power meters should resolve in under 3 seconds total. Option: single timing meter instead of two. Keep skill, cut waiting.
2. **Perfect window.** A visible sweet spot on the meter. Hitting it = Perfect (crit x2.0, small slow-motion, bright flash, sound sting). Window gets slightly wider with higher ball tier.
3. **Assisted first throw.** The first throw of a brand new player is guaranteed Perfect and a Strike.
4. **Pin destruction.** Pins fly, spin and bounce. For lanes with more than 30 pins, only up to 30 pins are real physics parts. The rest are visual only (fade-out, particle burst, or prebuilt pin-wall chunks that blow apart). Never simulate hundreds of physics pins.
5. **Impact feel.** Hit-stop (freeze for about 0.05 seconds), camera shake scaled to pins hit, a shockwave ring, debris particles, and a dust puff.
6. **Number popups.** Coin numbers pop above the pins hit, scaled by size of the payout. Big payouts get bigger text, colors and a short bounce.
7. **Coin vacuum.** Coins fly to the HUD counter and the counter ticks up quickly with a rising pitch sound.
8. **Strike moment.** Big "STRIKE!" banner, screen flash, confetti, and a short slow-motion on the last pin. Streak counter animates and each consecutive strike raises the pitch of the celebration sound.
9. **Audio pass.** Distinct sounds for: release, roll, impact (scaled by pins), strike, perfect, coin pickup, streak up, streak break (a sad sting). Pitch rises with streak.
10. **Remove realism.** Ball speed, lane friction and physics should be tuned for fun, not for realistic bowling.

Done when: throwing 20 times in a row, even with only the starter ball, feels satisfying and has clear feedback every time.

Playtest question: "Is a single throw fun by itself? Would you throw just to see it again?"

---

### MILESTONE 12: Pin Scaling, Zones and Ball Shop Ladder

Goal: the core "buy the next katana, hit harder" loop.

Steps:
1. Implement the 6 zones from section 3.2. Each has a different pin count layout (arrangement scaled up for bigger lanes), look, music and background.
2. Implement pin count scaling and the pinsHit formula from section 3.1. Large lanes use the visual-only destruction approach from Milestone 11.
3. Implement the 12-tier Ball Shop ladder from section 3.3. Each tier has a distinct look, glow, trail, sound and impact effect.
4. Show a "next ball" panel in the HUD: name, price, and a progress bar toward affording it.
5. Show "strike requirement" info on a zone: "You need Power 100 to strike this lane." Also show current Power.
6. Zones are gated by rank. Locked zones are visible with their rank requirement shown so the player always sees what is next.
7. Zone travel: a clean portal or teleport pad system. Moving between zones takes under 3 seconds.
8. Coin payouts scale with zone pin value so every new zone feels like a big jump up.

Done when: a player can buy ball tier 2 within roughly 2 minutes, unlock Zone 2 within roughly 10, and visibly see each new zone and ball as an upgrade.

Playtest question: "When you buy a new ball, do you feel it on the very next throw?"

---

### MILESTONE 13: Multipliers HUD, Streaks and Lucky Throws

Goal: stack multipliers visibly and add variable rewards inside the throw loop.

Steps:
1. Build a **Multiplier panel** that shows each source: ball, mascots, rank, rebirth, streak, boosts, crit. Total is displayed in large text. When any source changes, the total flashes and ticks.
2. Implement the strike streak from 3.1. Show a streak flame icon with a count. Breaking a streak plays a clear "streak lost" effect.
3. **Streak thresholds** at 3, 5, 10, 20, 50. Each gives a surprise bonus drop (random pick from: coin burst, free crate key, 60 second boost, Polish Points). Randomness here is deliberate.
4. **Lucky Throw:** 3% chance on any throw. The ball turns gold, the camera pushes in, payout is x5. Make this rare and spectacular. Reuse and integrate the Golden Pin from 9.5 where it fits (do not build two overlapping systems).
5. **Streak shield:** a rare drop that protects one broken streak. Shows as a small icon.
6. Keep rotating lane modifiers from 9.5. Make sure they stack clearly with the new multipliers and are shown in the Multiplier panel.

Done when: a player can look at the screen and understand why they just earned what they earned, and streaks create real tension.

Playtest question: "Do you feel nervous about breaking a streak?"

---

### MILESTONE 14: Mascots (Pets)

Goal: the second multiplier loop, collectible and random.

Steps:
1. Implement Mascot Eggs and the hatching experience from section 3.5. Hatching has a short suspense animation (egg shakes, cracks, light grows) with a near-miss feel: sometimes the light turns the color of a higher rarity then settles. This is allowed because the odds are shown honestly.
2. Mascots follow the player and idle on the lane edge. Each reacts when a strike happens.
3. Equip slots (3 to start, more via rank and rebirth). "Equip Best" button.
4. Mascot inventory with sorting by rarity and bonus. Locked slots show what unlocks them.
5. Merge 3 duplicates into a Shiny version (2x bonus).
6. Show the total mascot bonus in the Multiplier panel.
7. Mascots appear in the lobby showcase (extend the 9.5 lobby showcase).
8. **Auto Bowl feature:** build it behind a config flag `AUTO_BOWL_ENABLED`, default OFF. Do not expose it to players yet. It is reserved for the monetization phase.

Done when: hatching a mascot is exciting, equipping one visibly raises the multiplier, and players have a reason to hatch again.

Playtest question: "Do you want to hatch just one more egg?"

---

### MILESTONE 15: Boss Pins

Goal: the "soft block" equivalent. A big obstacle that demands a stronger ball and pays big.

Steps:
1. A **Boss Pin** is a giant pin with health. It appears on the lane every 15 throws, or on a timer, or after a streak (pick one and make it config-driven, default every 15 throws).
2. Each throw damages it equal to `ballPower * throwQuality`. Health bar shown on screen. Boss health scales by zone.
3. Defeating it grants a large coin payout, a crate key or Polish Points, and a short celebration.
4. Bosses are designed so that the current ball tier can beat them with 3 to 6 good throws, but a ball one tier up beats them noticeably faster. A boss that is too hard is a gate, not a goal. Balance with the simulator.
5. Boss variants per zone with unique looks and a unique death animation.
6. If the player fails (leaves or switches), the boss is not penalized or lost; it respawns next cycle.

Done when: a player sees a boss and immediately thinks "I need a better ball to break this faster."

Playtest question: "Did killing the boss feel like a payoff?"

---

### MILESTONE 16: Crate Overhaul, Rank Rewards and Collection Book

Goal: the random spice layer and the "always one thing close" layer.

Steps:
1. Expand crates to 5 tiers from section 3.4. Each tier has a distinct crate model and opening animation.
2. **Opening animation:** reel slows down near rarer results, sometimes stopping just short of a higher rarity. Rarity color beams and sounds. Keep openings under 5 seconds, with a skip after the first reveal.
3. **Odds screen:** a clearly accessible "Odds" button on every crate showing every possible outcome and its actual numeric odds (see section 6).
4. Implement duplicates to Polish Points and ball leveling.
5. Implement pity counters and show them ("12 pulls until a guaranteed Epic or better").
6. The first crate ever opened always gives Rare or better.
7. **Rank rewards.** Every rank-up gives something concrete: a crate key, an egg, a ball slot, a trail, a title, a zone unlock, a mascot slot, or a boost. Build a reward table in `GameConfig`. The rank-up screen shows what was unlocked and previews the next reward.
8. **Collection book.** Grid of every ball and every mascot. Owned items lit, missing items shown as silhouettes with rarity color and where they come from. Completing a page gives a bonus (permanent small multiplier).
9. HUD "next goal" element: always shows one close goal (next ball tier, next crate, next rank, next collection slot).
10. Weekly **featured ball:** one crate ball has boosted odds in one tier for the week, clearly labeled with its new odds shown on the odds screen.

Done when: no rank-up is just coins and XP, every crate opening has visible reward even on duplicates, and the player can always see a close goal.

Playtest question: "Is there always something you want that feels close?"

---

### MILESTONE 17: Rebirth (Go Pro Tour)

Goal: the long-term hours-scale loop.

Steps:
1. Implement rebirth from section 3.7. Rebirth button appears when requirements are met, with a clear preview of what resets, what is kept, and what is gained.
2. Add a confirmation step that spells out exactly what will reset.
3. Post-rebirth: the "start faster" perk (first 5 ball tiers at 10% price) applies, and the new unlock for that rebirth tier is granted.
4. Rebirth count is shown next to the player name and on leaderboards, with a visible badge that changes look every few rebirths.
5. Each rebirth unlocks a new cosmetic and a new title.
6. Make sure the second run through zones 1 to 3 is noticeably faster and feels powerful (use the simulator: second run to zone 3 should take about 40 percent of the first run).

Done when: a player who rebirths feels stronger, not punished.

Playtest question: "After rebirthing once, do you want to rebirth again?"

---

### MILESTONE 18: Daily Loops and Social

Goal: reasons to return tomorrow and play with friends.

Steps:
1. **Daily reward** with a 7-day streak. Day 7 reward is displayed prominently from the first day (aspirational). Rewards grow each day. A missed day resets the streak, with one free streak save per week.
2. **3 daily quests** (examples: hit 5 strikes in a row, defeat 2 boss pins, open 1 crate, reach 100 perfect throws). Quests refresh each day. Completing all 3 gives a bonus crate key.
3. **Lane party bonus:** +10% coins per friend in the same server, capped at +50%. Show it in the Multiplier panel.
4. **Leaderboards:** friends board plus global board for total pins, rebirths and best streak. Keep the lobby showcase from 9.5 and let players display their rarest ball and mascots.
5. **Gifting is out of scope.** Trading is out of scope (v3 idea).
6. **Event framework:** a config-driven system for limited-time events (double coins, featured mascot, special lane modifier). Build the framework only. Do not schedule events yet.

Done when: a player has a reason to open the game tomorrow, and playing with a friend is visibly better.

Playtest question: "Would you open the game tomorrow just for the daily reward?"

---

### MILESTONE 19: Onboarding and First Five Minutes

Goal: nail the first impression. Most players decide within five minutes.

Steps:
1. No tutorial screens, no cutscene, no long loading. Player spawns near the lane with one arrow and one short line of text ("Throw!").
2. First throw is assisted and a guaranteed Strike (see Milestone 11).
3. First 2 minutes: give a tangible reward. First crate is affordable at about the 1:30 mark and always gives Rare or better.
4. Use contextual hints that appear only when needed (for example, when the player can afford a ball: "New ball available!"). Hints disappear after the first use.
5. Within the first 5 minutes the player should have: thrown 20 or more times, bought ball tier 2, opened a crate, ranked up at least twice, seen the next zone locked with its rank requirement.
6. The player must never be forced to buy anything with Robux in the first session.
7. Audit the first 5 minutes with a stopwatch script or step log and report time between: join, first throw, first coins, first purchase, first crate, first rank-up. Every second of dead time must be justified.

Done when: a brand new tester reaches a purchase within 2 minutes without help.

Playtest question: "Hand the game to a friend who has never seen it. Where do they get confused or stop?"

---

### MILESTONE 20: Tuning, Polish and Playtest Protocol

Goal: make it feel perfect.

Steps:
1. Run the economy simulator again with all systems on. Fix any place where progression stalls for more than 5 minutes without a visible reward.
2. Performance pass: test the 3,000-pin zone on a low-end mobile device or the Studio emulator. Target stable frame rate. Reduce particle counts and physics parts if needed.
3. Mobile pass: all buttons large enough for thumbs, meters usable by tap, UI readable on small screens.
4. Exploit pass: try duplicating coins, spamming throws, opening crates faster than allowed, rebirth glitches. Fix what breaks.
5. Sound and visual consistency pass across all zones.
6. Prepare a playtest script for 5 real players: watch them for 20 minutes without helping. Note the exact moment each one stops. Report patterns to Selim.
7. Write a "Known issues and tuning ideas" list at the end of GAME_DESIGN.md.

Done when: 5 testers play at least 15 minutes without being asked to continue, and at least 3 say they would come back.

---

## 5. TECHNICAL RULES

- **Server authoritative:** coins, XP, ranks, rebirths, crate results and mascot results are computed on the server. Clients only display.
- **Big numbers:** values will get huge (billions and beyond). Use a number formatter (1.2K, 3.4M, 5.6B, then scientific). Make sure arithmetic never overflows or loses precision in a way that breaks purchases.
- **Performance:** cap real physics pins at about 30 per throw. Everything beyond is visual. Pool and reuse effect objects. Limit particle counts based on device quality.
- **Data:** every new field has a safe default, saves are versioned, and old saves are migrated, never wiped.
- **UI:** build all UI in a consistent style following the arcade neon direction. Use assets from Claude Design when available.
- **Config:** every number in section 3 lives in `GameConfig`. No magic numbers in game logic.

---

## 6. POLICY AND ETHICS RULES (non-negotiable)

1. **Odds are always shown.** Roblox requires showing all possible outcomes and their actual numeric odds for paid random items bought with Robux or with any currency that can be bought with Robux. Right now crates are opened with earned coins, but monetization will later add coin and gem packs. Build the odds screen from the start so that when packs arrive the game is already compliant. If an item changes the odds (a luck boost or featured ball), the odds screen must update to show the real current odds.
2. **No pay-to-win on competitive ranking.** Leaderboards must not be won by spending.
3. **No dark patterns.** No fake countdown timers on purchases, no fake scarcity, no confusing currency math, no guilt-tripping text.
4. **Kid-friendly.** A large part of Roblox players are children. Keep language, visuals and mechanics appropriate. No gambling-style imagery (slot machines, casino chips, card suits).
5. **Monetization is deferred.** Do not add gamepasses, gem packs or developer products in these milestones. Stubs behind config flags are allowed (for example `AUTO_BOWL_ENABLED`). Nothing purchasable with Robux ships until Selim decides after the game proves fun.
6. **No stealing or sabotage between players** (existing rule).

---

## 7. ANALYTICS (stub in Milestone 10, fill as systems arrive)

Log these events (use Roblox AnalyticsService custom events and funnels):

- Session start, session length
- First throw, first strike, first coins earned
- Each purchase (ball tier, crate, egg), with the player's time-in-game
- Each rank-up
- Zone unlocks
- Boss pin defeated
- Crate opened (tier, rarity), pity hit
- Mascot hatched (rarity)
- Rebirth
- Daily reward claimed, quest completed
- Streak records
- Player quit points (last action before leaving)

Reports Selim cares about: Day 1 and Day 7 return rate, average session length, and where new players leave in the first 10 minutes.

---

## 8. TUNING PROTOCOL

When a number feels wrong, do not guess. Process:
1. Change the value in `GameConfig`.
2. Re-run the economy simulator.
3. Check against the timeline in section 2.
4. Playtest.
5. Log the change in the changelog of GAME_DESIGN.md with the reason.

Rules of thumb:
- Early purchases (first hour): reachable in 10 to 30 throws.
- Mid game: 30 to 100 throws.
- Late game: 100 to 300 throws, but with surprises in between (lucky throws, boss drops, streak bonuses).
- If any purchase takes more than 5 minutes with no visible reward in between, add a reward or a closer goal.

---

## 9. DO NOT

- Do not add monetization.
- Do not rewrite systems that work. Extend them.
- Do not hardcode numbers.
- Do not simulate hundreds of physics pins.
- Do not add tutorials that block gameplay.
- Do not add features not listed here without asking Selim.
- Do not skip the playtest checkpoint between milestones.
- Do not describe things as "done" until the done-when check passes.

---

## 10. FIRST MESSAGE CLAUDE CODE SHOULD SEND

After reading all project files and inspecting the game, send Selim:
1. The "State of the game" summary (max 25 lines).
2. A list of anything in this plan that conflicts with what already exists.
3. Your 5 to 8 line plan for Milestone 10.
Then wait for a yes before changing anything.
