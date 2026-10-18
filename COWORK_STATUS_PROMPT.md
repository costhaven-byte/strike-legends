# Prompt for Cowork: Strike Legends status report (2026-10-18), please write ADDENDUM 2

Hi. I'm Selim, owner of Strike Legends, a Roblox bowling game that's being turned into a simulator. I don't write code; Claude Code builds everything (scripts through Rojo, map and UI straight in Roblox Studio). You wrote (or helped write) `STRIKE_LEGENDS_MASTER_PLAN.md` (milestones 10 to 20) and `STRIKE_LEGENDS_ADDENDUM_1.md`. A lot has changed since then. Below is the real state of the game today. Please read it and write **STRIKE_LEGENDS_ADDENDUM_2.md**, which:

1. Updates the plan to match what's actually built (especially the new throw, which replaces most of Milestone 11).
2. Settles the conflicts listed in section 9.
3. Says which milestone to resume with and what changes in each remaining milestone.
4. Uses the same style as Addendum 1: plain language, tables for numbers, "this file wins where it disagrees".

Order of authority right now: Addendum 1 > Master Plan > GAME_DESIGN.md. Addendum 2 would sit on top.

---

## 1. Where we are

- Milestones 1 to 9.5 from GAME_DESIGN.md are done and committed.
- **Master Plan Milestone 10 (Foundation) is done and committed.**
- **Milestones 11 to 20 are PAUSED.** Playtests showed the throw was boring and felt too realistic, so I asked Claude Code to rebuild only the throw, first in a separate test place (the "Throw Lab"), then in the real game. That throw is now in the game and I've approved it.
- There have also been a lot of visual passes (lobby, kiosk, display cases, balls, trails, HUD, trait effects) built from my Claude Design renders and handoffs.
- The place is published (private), with saving, leaderboards, analytics and a Friends-only playtest kit (PLAYTEST.md).

---

## 2. What's in the game (systems that work today)

| System | What it does today |
|---|---|
| Lanes | 6 lanes, one auto-assigned per player. Rebuilt from my alley designs. 10 pins per rack, real physics pins (mesh pins: Standard, Golden, Golden Star). |
| Throw | New one-input throw (see section 3). Server decides the result; the client only sends timing. |
| Rewards | Coins = pins × 10 × ball mult × rank mult × streak mult × modifier/golden pin, +50% on a Strike, +150% on a Perfect Strike. XP = 1.5 per pin (15 per Strike, 30 per Perfect) × streak XP mult. 10% chance of 1 gem on a Perfect Strike. |
| Streaks | Double (2) x1.5, Turkey (3) x2, Hambone (4) x2.5, Wild Turkey (5) x3, Streak Master (7) x4, PERFECT RUN (10) x5. Same numbers multiply XP. A non-strike resets. On screen the throw calls out STRIKE / DOUBLE / TURKEY / HAMBONE / WILD TURKEY / SIX PACK / SEVEN UP, then "8 IN A ROW!" and so on; fireworks at 3 and 5. |
| Ranks | Still 10 Pro Tiers, not the 60 levels from Addendum 1 yet. XP needed: Rookie 0, Amateur 300, Regular 600, Club 2K, Semi-Pro 6K, Pro 18K, Elite 50K, Master 140K, Legend 400K, Hall of Famer 1M. Coin mults 1.0 to 10.0. Gems on rank-up 5 to 100. A Rank Trial (strikes, streak or perfects in X throws) gates every tier; 60s cooldown after failing. Rank is saved. |
| Balls | The exact 20-ball roster from Addendum 1 (names, rarities, mults, traits unchanged). Every ball now has its own 3D model (from my .glb/.obj files, recoloured, shells painted) plus its own particles, rings, halos and layered moving trails. |
| Traits | Curve, Blast, Streak Saver, Lucky, Gem Hunter, Heavy, each with its own effect built from my "Trait Effects" design handoff. Retuned to fire much more often (see 3.4). |
| Crates | Still only 2 crates, still the OLD numbers: Basic 500 coins (60/25/10/4/0.9/0.1), Neon 2,500 (35/35/20/8/1.75/0.25). Pity: Rare at 20 crates, Epic at 100 (shared counter). Free crate every 15 strikes. Reel with crate intro. Lobby kiosk with 2 stations, hold-to-buy. Addendum 1's 5 crates, new odds and pity are NOT built yet. |
| Duplicates | Duplicate balls sell for coins by rarity (100 / 250 / 750 / 2.5K / 10K / 50K). Polish Points are NOT built yet. |
| Golden Pin | 1 in 15 racks has a golden pin: x5 coins, 30% chance of 2 gems, 10% chance of a free crate. |
| Lane modifiers | One alley-wide modifier every 90s: Double Coins; Moving Gold (renamed from Moving Pins, the gold zone slides on the meter); Bonus Gems (20% gem per strike); Giant Pins (bigger pins, gold zone 50% wider, x0.6 coins). |
| Gems | On (`Config.Gems.Enabled`). Earned from Perfects, Golden Pins, Gem Hunter, Bonus Gems, rank-ups, daily rewards. **Nothing to spend them on yet.** Approved sink: buying Polish levels with gems. |
| Daily reward | 7-day calendar: 250, 500 coins, 5 gems, 1K, 1.5K, 10 gems, Neon crate + 15 gems. Missing a day resets to day 1. |
| Leaderboards | One wall screen in the lobby: Most Pins, Best Streak, Weekly Coins, plus a "You" row. |
| Lobby | Hub room around the lanes (from my OBJ), crate kiosk, leaderboard wall, "Vault" showcase wall with 11 display cases (Rare and up). Locked balls show as a solid black silhouette of their real model with a padlock; owned balls show the full model and effects. |
| HUD | Simulator layout: XP/rank bar alone at the top, coins/gems and menu buttons on the left, streak, modifier and free-crate goal on the right, meters at the bottom. Separate compact layout for phones. |
| Saving | DataStore with session lock, retries, autosave every 60s, save on leave. Save format v6 (v2 balls, v3 daily/leaderboards, v4 rank, v5 free crates, v6 play time). Old saves migrate. |
| Safety | Server rate limits: throw 1.5s, equip 0.25s, crate 1s, daily 1s, trial 1s. |
| Analytics | Onboarding funnel, custom events, economy events, session length and last action before leaving. Event names for future systems already listed. |
| Sounds | Creator Store placeholders. |

---

## 3. The new throw (replaces most of Master Plan Milestone 11)

Built in the Throw Lab (`throwlab/`, its own test place), approved by me, then moved into the real game. All feel numbers live in `Config.Throw`.

### 3.1 How it plays
- **One input: hold to charge, let go to throw.** Aim and power meters are gone. The ball aims itself at the pins.
- The meter is a **half circle standing up beside the bowler** (shaped like ")"). The bar fills in 0.75s, and gets 5% faster per rank above Rookie.
- A **gold zone** on the meter is the sweet spot. Letting go inside it = **PERFECT**: 1.5x power, always a strike, a short 0.07s freeze before the pins explode (hit-stop).
- **Strikes only come from the gold.** Outside the gold you never strike (the chance is 0) and you always knock at least 3 pins. Blast is capped at 9 pins on a miss. There is no gutter ball any more.
- Gold zone is 8% of the bar (max 14% with ball bonuses). **After every throw the gold jumps to a new spot** (between 45% and 92% of the bar, always moving at least 15%), so players can't repeat the same timing. **Every strike in a row makes the gold 10% narrower** (down to 4%), so streaks get tense.
- Ball speed 80 studs/s, so there's little waiting. Throws are rate-limited at 1.5s.

### 3.2 The crash
- Pins blast up and back, spin, and knock each other over. All hit pins take off together (no stragglers). Pins use lighter gravity than normal so they hang in the air.
- Coin numbers pop out of each pin, plus one big total ("+12.5K") that grows with the payout and shows the multiplier.
- Camera punch toward the pins + short shake. 0.4s slow motion on strikes only (after a split second of full speed).
- Streak call-outs grow 15% bigger per strike in a row (up to 8).

### 3.3 Throw animation
- The bowler's arm swings back while charging, down-swings on release, and holds a follow-through. The ball leaves from the hand. Exaggerated 1.3x for a cartoon feel.
- **The animation depends on the ball's level:** weak balls throw stiff, wobbly and clumsy; it gets cleaner each level, fully clean at level 9 (Legendary); above that the swing gets bigger and flashier.

### 3.4 Ball "levels" (a stand-in for Power Levels)
- The Lab had 12 Power Levels (+/- buttons): each level makes the ball bigger and brighter, pins fly harder, numbers bigger. Sparkles from level 3, fire from 5, mega crash from 7, rainbow from 11.
- **Real Power Levels (buyable upgrades from Addendum 1) are NOT built yet.** For now **ball rarity sets the level**: Common 1, Uncommon 3, Rare 5, Epic 7, Legendary 9, Mythic 11, and the better half of each rarity gets +1. So Rookie looks and throws weak, Supernova looks absurd.
- Traits now fire often so they're actually visible: Curve always hooks (and a magenta "hook band" next to the gold also counts as PERFECT), Blast rolls every throw, Heavy shows on every strike.
- Heavy, Forgiveness and Giant Pins widen the gold zone (capped). Moving Gold slides it.

### 3.5 What's NOT built from Milestone 11
- Assisted first throw (guaranteed Perfect + Strike for a brand new player).
- Coin vacuum to the HUD with rising pitch (partly there from Milestone 8: coins fly to the counter with rising dings).
- Proper audio pass (release, roll, impact by pins, perfect sting, streak break). Sounds are still placeholders; I need to pick them in the Toolbox.
- Visual-only pins for big racks (no zones yet, so still 10 real pins).

### 3.6 Not re-checked
**The economy simulator has NOT been re-run since the new throw.** Perfects are now far more common than the old "Perfect Strike", and strikes only happen on Perfects, so payouts, XP speed and streak lengths have changed. This needs to happen before Milestone 12.

---

## 4. Milestone 10 results (done)

- Every plan number (with Addendum 1 on top) is in `Config.Economy`. The live game doesn't use those tables yet; each system moves onto them in its own milestone.
- Economy simulator: `tools/EconomySim.luau` (runs in Studio). Also checks crate odds add up to 100 and every ball is in some crate.
- Tuning from the simulator (the plan's numbers got a new player to the first rebirth in 14 minutes instead of 60 to 90):
  - Rank XP curve: base 50 → 180, growth 1.35 → 1.42.
  - Power Level prices: 0, 160, 460, 2.7K, 84K, 420K, 10M, 150M, 820M, 4.1B, 21B, 120B.
  - Power Level mults lowered from max x75 to max x12 (ball mults up to x25 stack on top).
  - Crate prices: 160, 920, 100K, 8.7M, 590M. Egg prices: 370, 42K, 630K, 150M, 3.5B.
  - New (approved): each egg tier scales its mascots' bonus (Alley x0.1 up to Volcano x1).
  - New (approved): +100% XP per rebirth, so the second run to Zone 3 takes 47% of the first (plan wants about 40%).
  - First rebirth: 400M coins at rank 20.
- Rate limits, autosave 60s, save v6 with PlayTime, analytics layer, gems on/off switch.
- My decisions: gems stay; gem sink = buying Polish levels with gems (earned only); per-egg bonus scaling yes; rebirth XP bonus yes.

---

## 5. Art status (updates Addendum 1 section 1)

| Art | Status |
|---|---|
| Lanes, alley, pins (Standard, Golden, Golden Star) | In the game |
| Lobby hub, crate kiosk, leaderboard wall | In the game |
| Display cases (one design, tinted per rarity, from my renders) | In the game, 11 cases (Rare and up) |
| All 20 ball models | In the game, coloured and painted. Void and Supernova had no model files, so they were built in Studio. Every ball has code-built VFX and trails from my renders. |
| Ball mesh weight (Addendum 1 section 7) | Light versions made: all 20 balls went from 580K to 51K triangles total (most 1.1K to 3K, Dragon 4.4K). Scripts can't upload meshes to Roblox, so they need a manual import through Studio's 3D importer. I've made the models lighter in another session; still to be confirmed it's the final state. Phone test (10 balls + 30 pins) not done yet. |
| Trait effects | In the game, from my Claude Design handoff |
| Crate models | 2 (Basic, Neon). Bronze/Silver/Gold not made. |
| Not designed yet | Mascots, eggs, zones 2 to 6, boss pins, rank badges, Power Level visuals beyond code, collection book UI, rebirth UI, quest UI, real sounds |
| AssetSlots module (Addendum 1 section 2) | Not built yet |

---

## 6. Lighting and look

Look pass done area by area against my renders: real shadows (LightingStyle Realistic), darker ambient, haze, bloom, neon trims made thinner and dimmer (they were too aggressive), glossy reflective lanes, carpet texture, rounded edges. All old values are saved so they can be undone.

---

## 7. What Addendum 1 asked for vs. what exists

| Addendum 1 item | Status |
|---|---|
| 20-ball roster unchanged | Yes |
| Power Levels (12 buyable upgrades) | Numbers in Config.Economy only. Ball rarity stands in for the level today. |
| 5 crates with new odds, new pity, first crate Rare+ | Not built. Still 2 crates with old odds and pity. |
| Polish Points (+5% per level, max 10) | Not built. Duplicates sell for coins. |
| Collection book | Not built. The Vault wall shows Rare+ balls. |
| Ranks as ~60 levels inside 10 tiers, trials only at tier changes | Not built. Still 10 ranks, trial at every rank (which is every tier, so trials already match). |
| Gems kept + gem sink | Gems kept. Sink approved (Polish with gems), not built. |
| Streak tier names as drop thresholds | Names kept. Drops not built (Milestone 13). |
| Lane modifiers, traits, Golden Pin, showcase kept | Yes (Moving Pins became "Moving Gold") |
| AssetSlots + placeholder rule | Not built |
| Ball mesh reduction | Done, waiting on import/confirmation |

---

## 8. Owner preferences learned along the way

- Skill-based: strikes should feel earned. Don't make it easier unless I ask.
- Effects should be STRONG, not subtle. No plain white in trails.
- When I send a render, match it 1:1, but only on the item it was made for.
- One milestone at a time; I playtest and approve before the next.
- Short, plain-language reports.

---

## 9. Conflicts and questions for Addendum 2 to settle

1. **Throw vs. Master Plan formula.** The plan has `pinsHit = min(lanePinCount, ballPower × throwQuality)` with throwQuality 0.6 to 1.0 and "a sloppy throw still pays well". Today strikes ONLY come from the gold, and a miss knocks 3 to 9 pins. How should Power (pins per throw) and big racks (30 to 3,000 pins) work with a gold-only strike rule?
2. **Perfect crit.** Plan: Perfect = crit x2. Today: Perfect = Strike +150% coins. Which one, or both?
3. **Streak multiplier.** Plan: 1 + 0.1 per strike, capped at 3. Today: named tiers x1.5 to x5 (also on XP), plus the gold shrinks 10% per strike. Keep ours, or switch?
4. **Lucky Throw (Milestone 13, 3% chance x5)** vs. the existing Golden Pin (1 in 15 racks, x5). Merge them?
5. **Power Levels in the new throw.** Today the "level" comes from ball rarity and drives size, force, sparkles/fire/rainbow and the throw animation. When real Power Levels arrive, does the level come from the Power Level, the ball, or both combined?
6. **Gold zone and Power Level.** Plan says the perfect window gets wider with higher ball tier. Today it gets narrower with streaks and jumps every throw. How should Power Levels affect it?
7. **Assisted first throw**: still wanted with the new throw?
8. **Ranks to 60 levels**: does each level need a reward (plan says every rank-up must give something concrete)? What about the existing trial at every tier?
9. **Crate prices**: old live prices (500 / 2,500) vs. simulator prices (160 / 920 / 100K / 8.7M / 590M). Switch when 5 crates arrive?
10. **Economy**: everything must be re-simulated with the new throw before Milestone 12. Should the simulator model "share of throws that are Perfect" as its own number?
11. **Which milestone next?** My suggestion: treat Milestone 11 as mostly done (finish the assisted first throw, audio slots and the coin vacuum), then Milestone 12 (zones + real Power Levels).
12. **Sounds**: list every sound slot needed so I can pick them in the Toolbox.

Please answer these inside Addendum 2 with clear decisions (or a short question back to me where only I can decide), and keep the format Claude Code can follow directly.
