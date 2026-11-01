# Strike Legends: Addendum 4 (Core Loop Rework, Zone 4 Launch)

**Purpose:** the game is published but the core loop is not fun or addictive. This addendum reworks the loop into a classic simulator loop: throw, pins into a bag, sell, buy a better ball, rebirth. Nobody has played the live game, so there are no saves or live economy to protect. Change what needs changing.

**Launch zone:** the bright daytime sky rooftop (current zone 4) becomes the one and only launch zone, and doubles as the hub. Zones 1 to 3 are switched off for this release.

**Rules for Claude Code**
- Where this conflicts with Addendum 2 or 3 or the milestone economy (crates, loot odds, old throw timing), this addendum wins for the loop. Everything else (pets, UI shell, sound) stays.
- The Addendum 3 story layer (homeless bowler, crate dealer, mentor) is disabled for this release. A simple tutorial NPC replaces it.
- Style: this is a simulator. Everything the player sees in the launch zone must read as bright, sunny and vibrant: daytime lighting, saturated colors, no dark or neon-nighttime looks. Audit the UI colors and report anything that clashes. Do not redesign UI without Selim's approval.
- Before Stage 1, audit the existing code and report what you will reuse. Reuse existing ball models, pin models, effects and sounds. Do not generate new art.
- Keep all tuning numbers in one config table (prices, pins per ball, cooldowns, bag sizes, pacing targets).
- Build in Studio only. Do not publish until Stage 3 passes Selim's own playtest, so new players never see a half-built loop.
- Zones 1 to 3 and the helicopter boss arena are switched off. Disable the portals, teleports and level gates that lead to them, so players cannot reach them. Do not delete anything: keep their maps, assets, display cases and code on disk, because later addenda rebuild each zone on the new loop (bigger lane, more and pricier pins, its own 10 balls). Save data: keep all old fields and add the new ones (bag, ball ladder) alongside them.
- Build one stage at a time. After each stage, stop, summarize in under 10 lines, and wait for Selim. He decides whether to continue.

**Stage 1: Core loop**
- Layout: a shared plaza in the middle (sell station, ball shop, showcase, leaderboard, tutorial NPC) with each player's lane along the edges. Build on whatever the rooftop already has. Report what exists first.
- One lane per player with a 40-pin layout: a 9-row triangle with the 5 back corner pins removed. Pin count and layout live in config so later zones can use bigger layouts. On-screen counter "12/40" updating live.
- Lane count: keep 6 lanes if the 9-row triangle fits with modest widening or smaller pin spacing. Server capacity matters for the alive feel, so do not cut to 4 wide lanes without reporting the footprint problem and options to Selim first.
- Performance: full physics only on the owning player's lane. Other players' lanes show a lighter scripted knockdown. Pool pins, cap debris, and if frame time suffers, raise the cooldown floor (config) from 0.4s.
- Hold the throw button to keep throwing. Start cooldown 1.0s, and throw speed is an upgradable stat that drops toward 0.4s. Lane refills instantly after each throw. The Perfect timing window is disabled while holding.
- Every pin knocked down becomes coins into a bag. A full clear (strike) pays double.
- Bag has a capacity. When full, pins still fall but pay nothing and a clear "BAG FULL, SELL" prompt shows.
- Sell station in the plaza, within a few seconds of any lane, plus a sell button. One currency only.
- Add pin pop numbers (+coins), small camera shake and a sound on big clears.
- Done when: Selim can throw, fill the bag, sell and see the coin total go up, with no waiting between throws.

**Stage 2: Linear ball ladder (replaces crates)**
- Balls are bought in fixed order from a shop. Remove crate-based ball acquisition. Keep crate code dormant, do not delete it.
- Bags are bought in a separate linear ladder, alternating ball, bag, ball, bag.
- Price rule: income per minute with the current ball x target minutes to afford the next. Pacing targets: balls 1 to 3 about 2 min each, balls 4 to 8 about 5 min each, balls 9 and 10 about 8 and 12 min.
- Each ball visibly clears more of the 40 pins. Average pins per throw by ball: 6, 9, 12, 15, 19, 23, 27, 31, 35, 43. The counter jumping is the main feel signal.
- Each throw rolls the result within plus or minus 20% of the ball's average, capped at 40. This means ball 9 can occasionally clear the lane (a surprise first-strike moment) and ball 10 clears most of the time. Ball 8 and below never clear.
- Before Stage 2 goes live: the LUCKY and SUPER LUCKY gamepasses boost crate luck, which no longer exists. Selim sets them off sale in the Creator Hub. Do not delete them. They can be repurposed later as pin luck.

**Stage 3: First 30 seconds**
- Tutorial NPC or arrow at spawn: "Throw. Sell. Buy." A new player must be able to buy ball 2 within 30 seconds, so tune the first prices low.
- Fill the plaza with props from existing assets so it never looks empty.
- Rewrite every UI string in a short, rough, human voice. No slogan-style lines. Specific labels only. Send Selim the full list of old and new strings to approve.

**Stage 4: Ball effects (10 balls, a sunny climb from weak to strong)**
Map each to the closest existing ball model, plain-looking balls to the early slots. Each ball adds one new behavior built from trigger + action + element so later balls can reuse the pieces.
1. Beach Roller: plain light roll
2. Rubber Bouncer: ricochets off the lane bumpers
3. Confetti Popper: pins burst into confetti and tumble into neighbors
4. Sunspike: knocked pins fly sideways into their neighbors
5. Gust: wind shoves a whole row sideways
6. Cloud Roll: a cloud trail sweeps the edges of the rack
7. Rainbow Arc: curves and sweeps the corners
8. Sunbolt: lightning arcs from pin to pin
9. Tornado: a spiral lifts pins into the air
10. Sonic Boom: a shockwave ring that clears the whole lane

**Stage 5: Rebirth (minimal)**
- Rebirth resets coins, bag size and balls. Keeps pets, lane skins and a permanent percentage boost to coins from selling. Rebirth must hurt, as in classic sims.
- Gate it behind owning ball 10, not behind a lucky clear.

**UI rules (apply in Stage 3, after Selim approves the plan)**
The UI must not read as AI-generated. Avoid these tells:
- No glowing drop shadows and no glossy neon gradients. Use flat solid fills with at most one hard offset shadow (no blur).
- No single corner radius on everything. Vary corners by element type (chunky buttons, flatter panels, some square or slightly tilted elements).
- No thin inner borders. Use thick outer outlines in a deliberate color, the way classic Roblox simulators do, on buttons and on key text.
- Colors: saturated, sunny, high contrast. Sky blue, sunny yellow, coin green, coral for action buttons, dark text on light panels. Selim approves the final palette.
- Icons come from the game's own assets (balls, pins, coins, pets), not stock icon packs. Never mix icon styles.
- Two fonts at most: one chunky display font for numbers and headers, one plain readable font for body text.
- Build everything as real Roblox UI instances with scale-based sizing, not flat images. Test at phone size and fix any overflow or warped text.
- Style reference: recent hit simulators, mainly Steal An Egg plus 1 or 2 other current top games Selim picks. Do not use Ninja Legends. Selim supplies screenshots of the HUD, shop, purchase and rebirth screens. Use them for structure, weight and proportions only, never copy a layout or asset.
- Before restyling, Claude Code lists every screen and waits for the screenshots. Show its own screenshots of the HUD, shop and sell screens for approval before touching the rest.

**Instrumentation (add in Stage 1)**
Log per player: first throw, 10th throw, first sell, each ball purchase, session length, time of last action. This is how Selim judges the loop once players arrive.

**Do not build yet**
Special pins, rack shapes, rebuilding zones 1 to 3 on the new loop, the boss arena, balls 11 to 40, leagues, new pets. These come after the loop holds players.

**Rebrand (Selim handles, listed so nothing is missed)**
New game name and icon, a bright sunny thumbnail showing a huge lane clear, a description that says it is a simulator, and genre tags. Do this after Stage 3, before spending any money on promotion.
