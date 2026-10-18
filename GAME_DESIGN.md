# STRIKE LEGENDS (working title) - Game Design Doc, v1

Roblox bowling simulator. Neon arcade look, fast dopamine loop, skill-based throws, collectible balls, rank ladder, competitive leaderboards. No stealing or sabotage between players.

---

## 1. Design pillars (every decision should pass these)

1. **Feel first.** Every throw and every strike must feel amazing. Juice (sound, camera, particles, numbers) is not optional polish, it is the product.
2. **Always a next goal within 2-3 minutes.** The player should always see something close: next rank, next ball, next streak tier, next daily reward.
3. **Skill matters, grind helps.** Better timing gives better results, but progression upgrades make everyone feel stronger over time (the Ninja Legends feeling: instant feedback, visible rank, a new world to chase).
4. **Never pay-to-win on competition.** Money buys time-saving and style, never exclusive ranking power.
5. **Simple to read.** A new player understands the game in 10 seconds. No confusing systems in v1.

Tone: colorful, saturated, arcade neon, bowling alley at night. Not cute.

---

## 2. Core loop (about 30 seconds per cycle)

1. Player stands at a lane in their alley.
2. Meter 1 sweeps left and right. Tap/click to lock **Aim**.
3. Meter 2 fills up and down. Tap/click to lock **Power**.
4. Ball rolls, pins explode, coins and XP pop out.
5. Consecutive strikes build a **Streak** that multiplies rewards.
6. Coins buy ball crates and upgrades. XP raises **Pro Tier** (rank). New ranks unlock new worlds and perks.
7. Repeat. Auto-bowl (later, a gamepass) repeats throws without the player tapping.

---

## 3. Throw mechanic (important, read carefully)

**Hybrid approach: result is calculated, visuals use physics.** Do NOT rely on pure physics for scoring, it will be inconsistent, laggy and unbalanceable.

- Client sends only: aim value (-1 to 1) and power value (0 to 1). Nothing else.
- Server validates (clamp values, enforce throw cooldown) and calculates the result:
  - Accuracy = how close aim is to center (0 offset = perfect). Ball trait "Forgiveness" widens the effective sweet spot.
  - Power quality = how close power is to the sweet zone (around 0.8 to 0.95 is ideal; too low = weak hit, too high = loses control).
  - Pins knocked = formula of accuracy, power quality, ball trait, plus a small random factor (about 10% variance) so it is never robotic. A perfect throw always strikes.
  - Outcome tiers: Gutter, Weak, Good, Spare-like (9 pins), Strike, **Perfect Strike** (perfect aim and power, extra rewards and effects).
- Server tells the client the result. The client plays the roll and uses real physics impulses on the pins for the explosion visuals, then cleans up and resets the pins.
- Pins reset quickly (target under 2 seconds from impact to next throw ready).
- No 10-frame scoring in v1. Every throw is its own reward event. (Classic frames/scoring can be a competitive mode later.)

Meter tuning: meters get slightly faster at higher ranks. Put speeds in the Config module.

---

## 4. Economy and progression

All numbers below are **starting placeholders**. Put every tunable in one Config module so they can be changed without touching logic.

### Currencies
- **Coins**: soft currency. Earned from throws. Spent on crates and ball upgrades.
- **Gems**: premium and rare currency. Earned slowly in-game (Perfect Strikes, daily rewards, leaderboard prizes), also sold for Robux later. In v1 only the earn side and the balance display exist.

### Rewards per throw
`coins = pinsKnocked * baseCoinsPerPin * ballCoinMultiplier * rankMultiplier * streakMultiplier`

- baseCoinsPerPin = 10
- Strike bonus: +50% of that throw's coins
- Perfect Strike: +150% and a small chance of a gem drop
- XP per throw = pinsKnocked (strike = 10 XP, perfect = 20 XP)

### Streak multiplier (consecutive strikes)
| Streak | Multiplier | Name |
|---|---|---|
| 1 | x1.0 | |
| 2 | x1.5 | Double |
| 3 | x2.0 | Turkey |
| 4 | x2.5 | Hambone |
| 5 | x3.0 | Wild Turkey |
| 7 | x4.0 | Streak Master |
| 10 | x5.0 (cap) | PERFECT RUN |

Missing a strike breaks the streak. Escalate effects with each tier (louder sound, bigger screen effects, more particles, the player's alley lights up). A streak resets to 0 on non-strike. A streak display is always visible.

### Pro Tiers (rank, driven by lifetime XP)
Rookie, Amateur, Regular, Club, Semi-Pro, Pro, Elite, Master, Legend, Hall of Famer.
- Each rank gives a permanent coin multiplier (rankMultiplier) and a visible badge/title above the player's head and on the leaderboard.
- XP thresholds grow roughly 3x per rank early on. Tune so Rookie to Club takes about 15-20 minutes for a new player.
- Rank-up is a **big moment**: fanfare, screen effect, a reward (gems or a free crate), announcement to the server.

### Worlds (alleys)
Structure the code so worlds are data-driven (a table of world configs: name, rank required, theme, pin type, rewards multiplier).
- **v1 ships World 1 only: Neon Alley** (Rookie and up).
- Planned later: Candy Lanes, Volcano Lanes, Space Station, etc. Higher worlds pay more per pin and unlock at higher ranks.

### Balls
Each ball has: name, rarity, coin multiplier, forgiveness (aim sweet spot width), and a visual trail/effect. v1 ships about 20 balls across 6 rarities.

| Rarity | Crate drop odds | Ball coin multiplier range |
|---|---|---|
| Common | 60% | 1.0 - 1.2 |
| Uncommon | 25% | 1.3 - 1.6 |
| Rare | 10% | 1.8 - 2.5 |
| Epic | 4% | 3 - 5 |
| Legendary | 0.9% | 7 - 12 |
| Mythic | 0.1% | 20+ |

- Players own many balls and equip one at a time. A player starts with one basic Common ball.
- **Crates**: bought with coins. v1 has two tiers (Basic Crate, Neon Crate with better odds and a higher price). Opening a crate is a hype moment: spinning reel or reveal animation, rarity-colored lights, sound escalation, a special reveal for Epic or better.
- Duplicates in v1: auto-sell for coins (simple). 
- **Pity system**: guaranteed Rare or better every 20 crates, guaranteed Epic or better every 100. This keeps the game feeling fair.
- Odds must be visible to the player in the crate UI.

### Daily reward
7-day streak calendar: coins, gems, a free crate on day 7. Login popup on join. Missing a day resets the streak (consider a grace period later).

### Leaderboards (competitive layer, v1 minimum)
- Global: Most lifetime pins, Best strike streak.
- Weekly: Best coins earned this week (resets weekly).
- Show top 10 on a physical board in the lobby plus the player's own position.
- Use OrderedDataStores. Cache and refresh every 60-120 seconds, never per throw.

---

## 5. v1 scope (what to build, and ONLY this)

1. One lane in a Neon Alley with 10 pins, a throw meter UI (aim and power), a ball roll, and pin explosions
2. Server-authoritative throw result and reward calculation
3. Coins, XP, Pro Tiers 1-10 with badges
4. Streak system with escalating effects
5. Ball inventory, equip system, 20 balls, 2 crate types with odds and pity
6. Daily reward
7. Global and weekly leaderboards
8. Data saving (DataStore) for everything above
9. Core HUD (coins, gems, rank/XP bar, streak, current ball) and shop/inventory UI
10. Mobile-friendly controls (this is mostly a mobile audience)

**Explicitly NOT in v1:** pets, trading, multiple worlds, battle pass, duels, tournaments, rebirth, gamepasses and purchases (design for them, do not build them yet), chat features, social features.

---

## 6. Juice checklist (build this progressively, it is as important as the mechanics)

- Throw: tap feedback sound, ball whoosh, lane lights follow the ball
- Impact: slow-motion for about 0.3s on a strike, camera shake scaled to pins hit, pins flying with trails
- Strike: fireworks or confetti in the alley, big "STRIKE!" text with scale and tween animation, screen flash
- Rewards: numbers pop out of pins, coins visibly fly to the HUD counter with a sound pitch rising per coin
- Streak: each tier adds a new layer of sound, lighting, and particles. A broken streak gets a short, noticeable (not punishing) sound
- Rank-up: full-screen celebration moment
- Crates: anticipation (shake, glow), rarity-colored reveal, special effects for high rarity
- UI: everything tweens in and out, buttons have press feedback, no instant pop-in

Use free sounds and effects from the Creator Store as placeholders, replace later.

---

## 7. UI list (designs come after the first build, but plan for these)

HUD, throw meters, streak display, rank/XP bar, shop (crates), inventory (balls), crate opening screen, rank-up popup, daily reward popup, leaderboard board, settings.
Mobile first: large touch targets, nothing important under the thumbs or screen corners.

---

## 8. Technical rules for the build

- **Server authoritative.** The client never decides coins, XP, pins, or drops. Clients only send aim/power inputs and UI requests (equip, open crate).
- Validate everything on the server: input ranges, throw cooldown, can the player afford this, do they own this ball.
- One **Config** module for all tunable numbers (rewards, odds, thresholds, meter speeds).
- Balls, worlds, ranks and crates are **data tables**, not hard-coded logic. Adding content should mean adding a row.
- **Data saving**: DataStore with a versioned schema (a `version` field), save on leave, on an interval (about every 60-120s), and on server shutdown. Handle failures with retries. Never lose a player's progress.
- Keep scripts small and organized into modules (server services, shared modules, client controllers). Avoid one giant script.
- Performance: pins cleaned up or reset after each throw, no per-frame heavy loops, no unbounded particle spam. Test on a mobile-sized viewport.
- Leave clear places to plug in future gamepasses, developer products and a battle pass (for example, a `multiplier` pipeline that gamepasses can later add to).

---

## 9. Build order (one milestone at a time, test before moving on)

1. **Lane + pins**: a lane, 10 pins, a ball, pins reset. Test: ball can hit pins and they fall and reset.
2. **Meters + throw**: aim and power meters, input sent to server, result calculated, ball plays out. Test: perfect input strikes, bad input gutters.
3. **Rewards**: coins and XP given server-side, HUD shows them.
4. **Streaks + rank**: streak multiplier and display, rank thresholds, rank-up moment.
5. **Saving**: all progress persists across leaving and rejoining. Test thoroughly.
6. **Balls + crates**: data tables, inventory, equip, crate opening with odds and pity.
7. **Daily reward + leaderboards.**
8. **Juice pass**: go through section 6 item by item.
9. **Mobile pass and bug pass**: play on a phone-size viewport, fix input and UI scaling.
10. **Playtest with real people** before any monetization is added.

After each milestone: run a play test in Studio, report what works and what is broken, then wait for confirmation before the next milestone.

---

## 10. Post-v1 roadmap (do not build yet)

1. Monetization: 2x coins gamepass, auto-bowl gamepass, VIP, gem packs, extra crate bundles, ball and trail cosmetics, limited event bundles. Rule: sell time-saving and style, never exclusive ranking power. Players should never feel forced to pay.
2. More worlds (Candy Lanes first), with new pin types and themes
3. Rebirth (reset for a permanent multiplier and a prestige badge)
4. Pets/mascots that stand at the lane and boost earnings
5. Weekly leagues (Bronze to Legend) with promotion and demotion, 1v1 duels, 4-player lane races
6. Battle pass and seasonal events (Halloween, winter)
7. Trading (only after the economy is stable, and with moderation and anti-exploit design)

Live-ops plan: after launch, plan an update about every week or two. Games that stop updating decay quickly.

---

## 11. Rules for Claude Code when working on this project

- Work on one milestone at a time. Do not jump ahead.
- Keep it simple. If something can be a table row, make it a table row.
- Before big changes, say what you plan to do in 3-4 lines. After, say what changed and how to test it.
- If something in this doc seems wrong or conflicts with how Roblox works, say so and propose a fix instead of silently deviating.
- Do not add features that are not in the v1 scope.
- The owner does not write code. Explain things in plain language, no jargon.

---

## 12. Changelog

From Milestone 10 on, MASTER_PLAN.md (plus STRIKE_LEGENDS_ADDENDUM_1.md) is the roadmap. Each milestone logs what changed and why.

### Milestone 10: Foundation (2026-10-18)
- **Simulator economy in Config.** Every number from the plan's section 3 (with Addendum 1 on top) now lives in `Config.Economy`: formula, zones, Power Levels, crate tiers and odds, pity, Polish, eggs and mascots, ranks, rebirth, the target timeline and the pretend player. The live game does not use these tables yet; each system moves onto them in its own milestone. (The plan's `GameConfig` is the existing `Config` module, not a second file.)
- **Economy simulator** in `ServerStorage.Tools.EconomySim` (file `tools/EconomySim.luau`). Run it from Studio's command bar in edit mode: `require(game.ServerStorage.Tools.EconomySim).Run()`. It also checks that crate odds add up to 100 and that every ball is in some crate.
- **Tuning done with the simulator** (the plan's numbers made a new player reach the first rebirth in 14 minutes instead of 60-90):
  - Rank XP: base 50 → 180, growth 1.35 → 1.42.
  - Power Level prices: 0, 160, 460, 2.7K, 84K, 420K, 10M, 150M, 820M, 4.1B, 21B, 120B (big jumps right after Zones 2 and 3 open, because a new zone pays far more per throw).
  - Power Level multipliers lowered from up to x75 to up to x12, because ball multipliers (up to x25) stack on top (Addendum 1 asked for this check).
  - Crate prices follow the Power Level next to them: 160, 920, 100K, 8.7M, 590M. Egg prices: 370, 42K, 630K, 150M, 3.5B.
  - New: each egg tier scales its mascots' bonuses (Alley x0.1 up to Volcano x1). In the plan every egg gave the same bonuses, so 8 cheap eggs multiplied coins by 5 by minute 7 and expensive eggs were pointless.
  - New: rebirth gives +100% XP per rebirth (proposed for Milestone 17). Without it a second run to Zone 3 takes 93% as long as the first; with it, 47% (plan wants about 40%).
  - First rebirth costs 400M coins at rank 20.
- **Server safety.** New `RateLimit` module: throws (1.5s), ball equips, crate opens, daily claims and trial starts are ignored if sent too fast.
- **Saving.** Autosave every 60s (was 90). Save format v6 adds `PlayTime` (total seconds played); old saves load with it at 0.
- **Analytics.** Every event name is listed in `Config.Analytics.Events` (stubs for later systems included). New: session start/end with session length and the last thing the player did before leaving, first coins, streak records, and crate purchases with total minutes played.
- **Gems switch.** `Config.Gems.Enabled` turns gems on or off in one place (on, per Addendum 1). Off hides the gem counter, stops gem drops and makes Gem Hunter pay bonus coins ("Coin Hunter").
- **Moved into Config:** pins per rack, the "Good throw" share, crate reel spin time, HUD count-up time, rank-up screen time and confetti, the crate-open cooldown.
- **Owner decisions (2026-10-18):** gems stay on; the gem sink will be buying Polish levels with gems (earned only). Per-egg bonus scaling approved. Rebirth +100% XP approved for Milestone 17.
