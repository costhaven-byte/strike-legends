# Strike Legends: Addendum 5 (Pet Core and Rebirth)

**Purpose:** Addendum 4 Stages 1 to 3 are built and stay as they are. This addendum replaces everything after Stage 3 (old Stage 4 ball effects and old Stage 5 minimal rebirth) and changes parts of Stage 2. The game is now a Ninja Legends style simulator where pets are the permanent, main progression and everything else resets on rebirth.

**Rules for Claude Code**
- Where this conflicts with Addendum 4, this addendum wins. Everything else in Addendum 4 (launch zone, performance rules, no new art, config table, Studio only, do not publish until Selim says) still applies.
- Before Stage A, audit and report what exists: current ball ladder, bag ladder, pet egg and pets, rank/XP/level systems, save fields. Reuse existing assets. Do not generate new art.
- All tuning numbers live in the one config table.
- Build one stage at a time. After each stage, stop, summarize in under 10 lines, and wait for Selim.

## Locked design

**Loop:** swing, pins go into the bag, sell for coins, spend coins on balls, bags and pets, rebirth when ready.

**One shared lane per map (replaces per-player lanes).**
- Remove player-specific lanes and plots. The map has one big lane that all players throw down at the same time. Spread throw spots across the lane width so players are not stacked on one point.
- Pins are a personal view only. When a player's ball hits, the close-up shows that player's own pins falling, rendered locally for that player. Other players' throws never change what a player sees or what they get counted. Counting is per player and server side, never based on what is physically knocked down.
- Balls from different players must not collide with each other or with other players' pin views (use collision groups). Other players' balls can show as light visuals or not at all, whichever is cheaper.
- This overrides the Addendum 4 layout (lane per player, 6 or 4 lanes) and its rule that full physics runs only on the owning player's lane. Since pins are local and cosmetic now, the performance goal is the same: no more than one player's pin set simulated per client. Report the footprint and any problems before rebuilding the old lane area, and do not delete the old lane assets.

**Selling and buying only happen at stations.**
- The Sell button (HUD) teleports the player to the sell station, where the bag is sold. Selling does not happen anywhere else.
- The ball shop on the left of the HUD becomes display only. It shows what exists and what is next, but cannot buy anything.
- All purchases (balls, bags, eggs, pet slots, rebirth) happen only at the buy station. If the HUD ball list currently has buy buttons, remove or disable them.
- Ball and bag upgrades are independent. A player can buy the next ball or the next bag in any order, and neither blocks the other. Replace the alternating ball, bag, ball, bag ladder from Addendum 4 Stage 2 with two separate ladders, each with its own pacing in config.

**Pins are a number, not objects.**
- The lane keeps the 40-pin layout built in Stage 1 as the visual. The counted pins per swing can be far higher than what is shown falling. Never spawn more than the visual layout.
- The counter and pop-ups show the real number (for example "+15", later "+1.2M"). Use the existing big-number module.
- Remove the old cap of 40 pins per throw. Remove the full-clear double pay (there is no full clear anymore).
- Keep the roughly plus or minus 20 percent luck roll per throw, shown as a brief "lucky" pop when it rolls high.

**Balls change pins per swing only.**
- Ball tier sets the base pins per swing. Bags set capacity only. Neither changes anything else.
- Ball effects (magic arms, black hole, burning, exploding and so on) are visual and feel only. They never change numbers. Their intensity scales with the pin count so a stronger ball looks and feels stronger even when the visual lane only has 40 pins.
- Keep the linear ball ladder and pacing from Addendum 4 Stage 2, now separate from the bag ladder (balls: 2 min each for the first 3, 5 min each for the next 5, then longer). Replace its pins-per-ball targets with a steeper curve in config, since pins are now abstract.

**Pets are the main thing.**
- Pets give stat boosts. Stat types: Coins, Pins, Bag size, Throw speed. Each pet has one or two stats.
- Stacking rule (config, default): boosts of the same stat from equipped pets add together, and that total multiplies with the rebirth multiplier.
- Players equip a limited number of pets. Start with 3 slots, more slots bought with coins.
- Pets come from eggs bought with coins. Multiple eggs in a price ladder, each with its own pet pool, so spending more gets rarer pets. Reuse the existing Neon Egg and pets and re-rate rarity as needed. Show odds on every egg.
- Keep the Shiny merge (3 copies into one Shiny, stronger boost).
- Pet inventory UI with equip best, and clear stat labels.

**No levels.**
- Remove the level, XP and rank gating from the loop: no XP bar, no level gates, no rank requirements on anything. Disable the UI and checks, do not delete the code.
- Everything is gated by coin price only, including rebirth.

**Rebirth.**
- Available whenever the player has enough coins for the rebirth price. Never forced.
- Resets: coins, bag contents, bag size and ladder position, ball ladder position, anything bought with coins except pets.
- Keeps only: pets (full inventory, equipped, Shiny) and the rebirth count. Pet slots are kept by default (config flag, Selim to confirm).
- Gives: a permanent rebirth multiplier to both coins gained and pins per swing. Each rebirth costs more than the last (config scaling, default roughly 3x).
- It must hurt like a classic simulator: the player restarts with the weakest ball and smallest bag. It must also pay off: tune so a rebirthed player returns to their previous income in about a quarter of the time it took the first time, then passes it. A player who never rebirths should visibly fall behind players who do.
- Rebirth count shows on the nameplate and leaderboard. Each rebirth tier changes something visible and cheap using existing assets (for example the lane or pin skin).

## Stages

**Stage A: Pins become a number.** Decouple counted pins from visual pins, remove the 40 cap and the full-clear bonus, switch the counter and pop-ups to the big-number display, remove level, XP and rank gating, and rescale the ball ladder curve. Also in this stage: the one shared lane with personal pin views, the Sell button teleport, buy-station-only purchasing (HUD ball list becomes display only), and separate ball and bag ladders. Done when: a ball swing shows a large pin number while only the normal 40-pin layout animates, several players can throw down the same lane without affecting each other's pins or counts, nothing in the game asks for a level, and nothing can be bought away from the buy station.

**Stage B: Pets as the core.** Equip slots, stat boosts applied to coins, pins, bag and speed, the egg price ladder, pet inventory UI, Shiny merge. Done when: Selim can buy an egg, equip the pet, and see income change by the stated amount.

**Stage C: Rebirth.** Rebirth button gated by coins, the reset and keep rules above, the multiplier, nameplate and leaderboard display, the visible tier change. Done when: Selim can rebirth, restart weak, and recover noticeably faster than the first time.

**Stage D: Ball effects.** One distinct visual effect per ball, mapped to existing models and effects, with intensity scaling to pin count. No numeric changes.

**Stage E: Pacing and logging.** Log time to each ball, each egg, first rebirth and second rebirth, and income before and after rebirth, to a place Selim can read. Report where pacing breaks.

## Open items for Selim
- Does rebirth keep pet slots, or reset them to 3?
- Should pet boosts include Bag size and Throw speed, or only Coins and Pins?
- Number of egg tiers at launch (default 4).
