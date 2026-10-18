# STRIKE LEGENDS: ADDENDUM 1 (art status, placeholders, and fixes to the master plan)

Give this to Claude Code together with STRIKE_LEGENDS_MASTER_PLAN.md. Where the two disagree, this file wins.

The master plan was written before we saw what Selim had actually built and designed. This file fixes the conflicts so you do not build against the wrong assumptions.

---

## 1. Art status (as of Oct 18)

Designed and exported, in Selim's "Strike Legends Assets" folder:
- Lane and alley: neon-alley, StrikeLegends_MainLane, sl_ball_return, sl_lane_scoreboard
- Pins: StandardPin, golden_pin, plus low-poly "Roblox Upload" versions of the standard, golden and golden star pins
- Lobby: strike-legends-lobby-hub, display_case, crate-shop-kiosk (shows 2 crates), leaderboard board screenshots
- All 20 balls (see section 3)

Not designed yet: crate models, coin and gem art, rank badges, trait and modifier icons, effect specs, UI screens, mascots and eggs, zones 2 to 6, boss pins, sounds, marketing.

Unknown: which of the designed groups (lane/pins, lobby, balls) are already handed off into the game. Ask Selim in your first message. If they are not in yet, they are a visual-only job and go first (section 7 explains why the balls need a reduction step before import).

---

## 2. The placeholder rule (applies to every milestone)

Never wait for art. If a milestone needs art that does not exist:
1. Build the system fully with a placeholder (plain colored Parts, plain UI frames in the neon palette from the design system).
2. Create one module, `AssetSlots`, that maps every art slot name to a Roblox asset ID or nil. Nil means placeholder. When Selim supplies final art, only this table changes.
3. Procedural effects (particles, camera shake, beams, glows) are built in code now. They are not "art we are waiting for".
4. At the end of each milestone, report a short "Placeholders still in use" list.

Selim designs in Claude Design in parallel while you build. He hands finished art over with the handoff prompt (visual change only, no logic changes).

---

## 3. The ball roster (overrides master plan sections 3.3 and 3.4)

There are exactly 20 balls. Keep names, rarities, multipliers and traits as built. Do not rename or retune them.

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

Six rarities, not five: Common (5 balls), Uncommon (4), Rare (4), Epic (3), Legendary (2), Mythic (2).

### Changes to the master plan

1. **Section 3.3 becomes "Power Levels", not 12 balls.** Keep the same 12 rows, prices, Power and value mult as starting values. A Power Level is an upgrade the player buys with coins, in order. It sets Power (pins per throw) and a payout multiplier. The equipped ball supplies its own mult and trait on top.
   - Ball mult (up to x25) and Power Level mult (up to x75) multiply together. Check this in the simulator so growth is not too fast. Tune the Power Level mult down if needed. Do not touch the ball mults.
   - Each Power Level changes how the equipped ball looks and sounds, built in code: scale, glow ring, trail, impact effect, sound. Level 1 is plain. Level 12 is absurd. No new ball models are needed. The upgrade must be visible on the very next throw.
2. **Section 3.4 crate changes.** Remove the "Ball Power band" column and the rarity value bonus (the balls already have their own mult). Crates only drop balls from the 20-ball roster. Replace the odds table with this one (every row sums to 100):

| Crate | Common | Uncommon | Rare | Epic | Legendary | Mythic |
|---|---|---|---|---|---|---|
| Basic | 70 | 25 | 5 | 0 | 0 | 0 |
| Bronze | 45 | 35 | 17 | 3 | 0 | 0 |
| Silver | 20 | 35 | 32 | 11 | 2 | 0 |
| Gold | 0 | 20 | 45 | 28 | 6.5 | 0.5 |
| Neon | 0 | 0 | 40 | 38 | 18 | 4 |

   Within a rarity every ball has an equal chance (except a featured ball). The odds screen shows odds per rarity and per ball.
3. **Pity values (starting, in GameConfig):** Basic and Bronze: Rare or better every 10 pulls. Silver and Gold: Epic or better every 20 pulls. Gold and Neon: Legendary or better every 80 pulls.
4. **Duplicates.** With only 20 balls, duplicates arrive fast. Keep Polish Points (each level +5% of that ball's mult, max level 10). Once a ball is maxed, extra duplicates give coins instead. No pull is ever wasted.
5. **First crate ever** is Rare or better (overrides the odds above for that one pull).
6. **Collection book** is 20 balls, one page per rarity. Completing a page gives the small permanent bonus described in Milestone 16.
7. Every ball must be obtainable from at least one crate. Verify this when you wire the odds.

---

## 4. Crates

Two crates exist in the game (Basic and Neon) and the lobby kiosk shows two. The plan has five (Basic, Bronze, Silver, Gold, Neon).
- Keep the existing two crates. Prices and odds come from GameConfig (this file and the master plan win over what is currently hardcoded).
- Add Bronze, Silver and Gold using recolored copies of the existing crate model until final models exist.
- The 3D kiosk stays as is for now. The shop screen (2D) lists all five.

---

## 5. Ranks

The game already has 10 named Pro Tiers: Rookie, Amateur, Regular, Club, Semi-Pro, Pro, Elite, Master, Legend, Hall of Famer. Report the real current rank count and XP curve before changing anything.
- Keep the 10 tier names as the visible rank and badge.
- The master plan's levels 1 to 60 become levels inside those tiers (about 6 per tier). The badge changes when the tier changes. Zone gates use the level number.
- Rank trials from milestone 9.5 stay, but only at tier changes (9 trials), not at every level.
- Never reset or wipe existing player rank progress. Migrate it.

---

## 6. Things that already exist and must keep working

Confirm each against the real build and report differences:
- **Gems.** The Gem Hunter trait and the Bonus Gems lane modifier give gems. The master plan has no gem use. In your Milestone 10 plan, propose one simple sink for gems (for example Polish Points or crate keys). Gems are earned only. Nothing is sold for Robux in these milestones.
- **Streak tiers:** Double (2), Turkey (3), Hambone (4), Wild Turkey (5), Streak Master (7), PERFECT RUN (10). Keep these names and use them as the thresholds for the streak bonus drops in Milestone 13, instead of 3, 5, 10, 20, 50.
- **Lane modifiers:** Double Coins, Moving Pins, Bonus Gems, Giant Pins. Keep.
- **Traits:** Curve, Blast, Streak Saver, Lucky, Gem Hunter, Heavy. Keep.
- **Golden Pin and the lobby showcase** from 9.5. Keep and extend, do not duplicate.

---

## 7. Ball model weight (do this before the balls go into Roblox)

I counted polygons in Selim's exported files. Each ball is built from many pieces and totals about 21,000 to 134,000 triangles (Dragon's Eye is about 134,000, Golden Strike about 82,000, Supernova about 47,000). Roblox limits a single mesh to roughly 20,000 triangles, and phones need far less when several balls are on screen.

The pins already got this treatment: StandardPin was 16,800 faces and its "Roblox Upload" version is 736.

Do the same for the balls:
- Target roughly 1,500 to 3,000 triangles per ball, with glow parts as separate meshes.
- Tell Selim what you can reduce yourself and what he needs to ask Claude Design to re-export. If you cannot reduce meshes with the tools you have, say so plainly in your first message.
- Test with 10 balls and 30 pins visible on a phone-size viewport.

The Void and Supernova were exported as .obj, the rest as .glb, and the 5 Common balls are in one file (common-balls.glb). Note this for the import step.

---

## 8. Which milestones need art, and what to do

| Milestone | Art needed | What to do |
|---|---|---|
| 10 Foundation | None | Build now |
| 11 Throw feel | Sounds only | Build effects with built-in particles and camera effects. In your hand-off, list the sounds needed (name, what it should sound like, length). Selim picks them in Studio's Toolbox under Audio. Leave silent slots until he does. You cannot listen to sounds, so do not pick IDs yourself. |
| 12 Zones and Power Levels | Zones 2 to 6 | Zone 1 is the existing Neon Alley (rename it if the zone names clash). Build zones 2 to 6 from the same alley with a `ZoneTheme` config (palette, lighting, sign text, pin tint). Real zone art swaps in later. Power Level visuals are code. |
| 13 Multipliers and streaks | UI look | Plain frames in design system colors |
| 14 Mascots | About 12 mascot models, 1 egg model | Placeholder: a colored sphere with eyes per rarity, egg recolored per zone. Mascot data and behavior are finished, only models swap. Shiny is a gold material swap in code. |
| 15 Boss pins | Boss pin models | StandardPin scaled up with a zone tint, cracks as the health drops, plus a health bar |
| 16 Crates, ranks, book | 3 crate models, 5-crate kiosk, opening animation art, collection book UI, tier badges, icons | Recolored crate model, plain 2D book, text labels for rewards |
| 17 Rebirth | Rebirth screen, rebirth badges | Plain UI, number text for the badge |
| 18 Daily and quests | Daily reward popup, quest panel | Plain UI |
| 19 and 20 | None | |

Selim's playtest answers for milestones 14 and 16 will be skewed by placeholder art. Mention this in the hand-off report for those two milestones.

---

## 9. Add this to your first message to Selim

1. Which art groups are already imported into the game.
2. The real current rank count and XP curve, how gems work today, and the real streak tier and lane modifier names.
3. How you plan to reduce the ball models, or that you cannot.
