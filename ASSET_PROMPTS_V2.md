# Asset prompts v2 (2026-11-02, after Addendum 6)

Replaces ASSET_PROMPTS.md (that one still talks about Back Alley / Neon Lanes, which are gone).
Everything below is **placeholder or made by Claude**. The real art you designed (rooftop zone 1 models, crates, Pin Titan set, display cases, fusion machine, loading screen, HUD/Store/UI/Crate Kit icons, Looks icons) stays.

**How to use:** 7 Claude Design projects (U1-U4, I1, B, Z). Paste the style block first, then the prompt. Big prompts say "one part per message": send the prompt, then type `next` for the next part. Bring results back here and Claude puts them in the game (UI = image uploads + rebuild; 3D = you import the .glb in Studio, then tell Claude).

---

## 1. Why the game reads as "AI-made" (what the research + your screenshots show)

Web sources on this are thin (no study lists "AI tells"); what they do agree on: **style drift between screens**, default-looking styling, small unreadable text, and no consistent design language are what make a game look cheap ([DevForum UI guide](https://devforum.roblox.com/t/the-ultimate-ui-design-guide/1236916), [DevForum simulator UI feedback](https://devforum.roblox.com/t/feedback-on-my-simulator-ui/1553479), [itch.io comment on shifting art style](https://itch.io/post/13100681)). Checking our own screenshots against your 5 reference images, these are the 10 concrete problems:

| # | Problem in our game now | What hit simulators do (your refs) |
|---|---|---|
| 1 | 3-4 fonts fighting (outlined bubble heading, grey Gotham body, Fredoka numbers, italic) | 1 font family, 2 weights, same dark outline everywhere |
| 2 | Sentences in the UI ("Rebirth is bought at the ball s…", "Stand on the green circle", "Rebirth boost now: coins +0% > +200%…") | Icon + number. 1-3 words max |
| 3 | Text clipping and wrapping inside pills | Text always fits its box, never wraps in a button |
| 4 | Cards are text only (rebirth tab = 5 text boxes) | Item art fills ~60% of every card (ref 3), text sits under it |
| 5 | Cream panels with grey text = low contrast, flat, no light | Bright saturated solid colours, strong outlines, flat light rays behind items (no gradients) |
| 6 | Every popup uses the same "Back" bounce (131 of ~390 tweens), all the same speed | Different motion per job: fast snap for buttons, slow overshoot for rewards, staggered lists |
| 7 | Things don't match their name/zone: "Seashell Spinner" is a galaxy ball, the Neon Egg (night club) stands on a sunny pier, jungle egg = Main Street egg, 3 pets are recolours | Every item looks like its name and its zone |
| 8 | Maps built from plain blocks: same sizes, perfect grid spacing, no wear, flat signs with plain text | Hand-placed hero props, varied sizes, worn edges, chunky carved signs |
| 9 | Icons in mixed styles (some flat, some 3D-rendered, different outline widths, different light directions) | One icon style: rendered 3D look, light from top-left, same outline |
| 10 | Permanent tutorial banners ("Throw > Sell > Buy / Hold Throw to bowl") stay on screen | Hints show once, at the moment they're needed, then leave |

**The rule all prompts below follow:** one font, short words, art first, one icon style, every item matches its zone, imperfect hand-made worlds, and the motion described per element.

---

## 2. What is placeholder or made by Claude (complete list)

| Area | What it is today | Prompt |
|---|---|---|
| **2D UI, all windows** | Claude's restyle (Addendum 4/5/6): HUD (coins, gems, bag + SELL, pins-down counter, Throw>Sell>Buy banner, next-ball bar, x2.5/AUTO, REBIRTH button), Shop (Balls/Bags/Rebirth/Passes tabs + BUY BEST + ??? silhouettes + buy reveal), rebirth hold button + REBIRTH! moment, PETS/ITEMS panel, hatch card, fusion window, egg odds boards, daily calendar, gifts, spin wheel, level/zone unlocked, fever + lane event banners, toasts, callouts, afford notes, profile/achievements, settings, teleport, gate signs, station signs | U1-U4 |
| **Fonts** | Stand-ins mixed (Luckiest-style outlined heading, Gotham, Fredoka, Montserrat italic) | U1 |
| **Icons** | 2X PINS pass (borrows the pin icon), bag icon (one store picture tinted for all 40 bags), 17 rebirth rank colours with no badges, potion/pass icons in mixed styles | I1 |
| **Balls** | All 40 ball looks. Zone 1 + 2 use the old 20 designs under new names (e.g. "Tornado" is the Solid Gold ball). Zone 3 + 4 borrow those same models again (tagged Placeholder in Config) | B |
| **Bags** | No art of their own: 1 icon recoloured 40 times | I1 (icons) |
| **Zone 1 (Skyline Rooftop)** | Shop + sell stalls and the gate to zone 2 = Claude's parts. Speckled Egg + stand = Neon Egg recoloured. Pebble, Breezy, Sunspot = recoloured old pets | Z part 1 |
| **All 19 egg pets** | Designed for zones that no longer exist (neon club, Main Street, night skyline) or recoloured; all get new names + designs | Z (renames below) |
| **Zone 2 Sunset Boardwalk** | Whole map = Claude's parts (pier, beach, huts, ferris wheel, lighthouse, arch). Neon Egg + stand = night-club design on a sunny pier | Z part 2 |
| **Zone 3 Jungle Falls** | Whole map = Claude's parts + terrain (cliff, 4 waterfalls, temple, rope bridges). Main Street Egg + stand = indoor bowling-alley design | Z part 3 |
| **Zone 4 Canyon Oasis** | Whole map = Claude's parts + terrain (arch, hoodoos, sphinx, balloons, adobe). Skyline Egg + stand = night/cloud design. Zone 3/4 display case themes = zone 2 recoloured | Z part 4 |
| **Ball effects (40)** | Made by Claude in code from parts + particles (coconuts, toucan, sphinx head, mesa…) | Animation plan (they get the motion pass; the big props come from Z) |
| **Sounds** | Zones 2-4 effects borrow whoosh / thud / boss-hit; no sea, jungle or desert ambience | Part 5 (ElevenLabs, not Claude Design) |
| **Thumbnails + icon prompts** | THUMBNAIL_ICON_PROMPTS.md shows Back Alley + Neon Lanes, which are no longer in the game (misleading thumbnails get games flagged and players leave) | T |

### Renames (owner 2026-11-02: nothing keeps its old name)

Every egg and every pet gets a new name and a new design that fits its zone (prompt Z). Rarities and boosts stay the same. Only the name players see changes; the hidden save Ids stay, so **nobody loses a pet** (Claude changes the display names in Config when the designs go in). Ball names were already new in Addendum 6.

| Zone | Old egg → new | Old pets → new (same rarity, same order) |
|---|---|---|
| 1 | Speckled Egg → **Rooftop Egg** | Gutter Gus → Pidge, Pebble → Gravel, Bumper → Vent Puff, Breezy → Kite Pup, Sunspot → Solar Cat |
| 2 | Neon Egg → **Shell Egg** | Pinny → Sandy Crab, Lane Pup → Gull Buddy, Strikey → Otter Pop, Splitz → Sea Star, Hambone → Puffer, Neon Bat → Surf Seal |
| 3 | Main Street Egg → **Jungle Egg** | Wood Pup → Tree Frog, Chrome Bat → Toucan Tom, Kingpin → Temple Monkey, Blaze → Jaguar Cub |
| 4 | Skyline Egg → **Sun Egg** | Cloud Bumper → Fennec, Sunny Ham → Cactus Pal, Cosmo → Scarab, Perfecto → Sphinx Kitten |

Not in any egg (check before launch): Titan Jr. (old boss pet) and the old Volcano Egg; tell Claude whether to rename or retire them.

---

## 3. Style blocks (paste first)

### UI style block (every U and I prompt)

```
GAME: "Strike Legends", a Roblox bowling simulator for ages 9-15. Loop: throw a ball down a big lane, pins fill your bag, sell pins for coins, buy better balls and bags, hatch pets, rebirth, unlock 4 outdoor zones (Skyline Rooftop, Sunset Boardwalk, Jungle Falls, Canyon Oasis).

GOAL: players said the old UI looked "clearly AI-generated" and "not polished". Make it look like a top-10 Roblox simulator made by a professional UI artist. Rules:
- ONE font family for everything: Fredoka One (headings, buttons, numbers). Builder Sans Bold only for tiny labels under 14 px. No other fonts. No italics. No giant chunky letters: headings max 1.6x the button text size.
- Every text and icon has the same dark outline: 2.5 px #10172E (1.5 px under 18 px text). Text is white or one accent colour, never grey on cream.
- Words: max 3 words per label, numbers with K/M/B. Never a sentence inside a window. Use an icon + number instead of explaining.
- Art first: every card is mostly item art (60% of the card) on a flat two-tone light-ray burst (solid wedges, no blur) in the card's rarity/category colour, text below.
- NO GRADIENTS ANYWHERE and NO PURPLE/VIOLET panels (that look reads as AI-made). Every fill is one solid flat colour. Vibrancy comes from bright saturated solid colours next to each other and the dark outline, not from blends. Depth = a solid darker "lip" under buttons/cards (6 px, offset straight down) and a solid 3 px outline, never a soft glow or shadow blur.
- Panels: window body solid deep ocean blue #17345C, cards solid #22477A, header plate solid sunny yellow #FFC93A with a solid #E59A00 lip, 3 px dark outline, 16 px corner radius, a 3 px solid lighter strip along the top edge for shine (a flat band, not a gradient).
- Action colours (solid), always the same meaning: green #3CCB3F (lip #1F8F27) = buy/claim/go, blue #2E9BFF (lip #1666C4) = info/secondary, pink #FF4FA3 (lip #C42A78) = gems/premium, red #FF3B4E (lip #B81E30) = close X and "not enough", gold #FFC93A = rewards/rebirth. Robux price buttons are green with the Robux glyph.
- Rarity colours: Common #B8C2CC, Uncommon #4BE07A, Rare #3AA8FF, Epic #B45CFF, Legendary #FFC93A, Mythic #FF4F8B (Mythic cards get a striped edge of solid rarity colours, no rainbow blend).
- Icons: one style only - cartoon look with cel shading (one solid highlight shape + one solid shadow shape per colour, no gradients, no airbrush), light from top-left, 3 px dark outline, transparent PNG, 256x256.
- States are shown with more than colour: locked = dark + padlock, done = tick, ready = glow + bounce, new = red dot with a number.
- Screens: computer 1920x1080 and phone sideways 844x390 (top 36 px = Roblox bar; bottom-left = thumbstick, keep it empty). Tap targets at least 44 px on phone.

DELIVER: full-screen mockups for both screens; each component alone with size in px, radius, outline, font size and hex codes; every state (normal, pressed, locked, ready, done); every icon/image as a separate transparent PNG; and a MOTION NOTE per element (what moves, how far, how long in seconds, ease: snap / overshoot / soft) - only scale, position, rotation, transparency and colour. Where a 3D ball, pet or egg will spin, leave a box labelled "3D SLOT".
```

### World style block (every B and Z prompt)

```
GAME: "Strike Legends", Roblox bowling simulator for ages 9-15, bright sunny cartoon style like the top Roblox simulators. Players said the old world "looked AI-generated": plain blocks, same sizes, perfect grid spacing, flat signs. Make everything look hand-crafted:
- Chunky stylised low-poly shapes with bevelled edges, slight tilts and uneven sizes, never perfect cubes in a grid.
- Wear and story: chipped paint, scuffs, cracks, moss or sand in corners, rope wraps, nails, stickers (no real brands, no readable text except names I give).
- Big readable silhouettes from 60 studs away; detail goes where the player stands.
- Flat colours or one small texture per part, hand-painted shading (light top, darker bottom), warm sunlight from one side.
- Roblox limits: low-poly (numbers per item below), export .glb, pivot at bottom centre (balls: centre), real-world scale in studs (1 stud = 28 cm; a player is 5 studs tall), no text baked in except the sign names given, no transparent glass bigger than a window.
ZONE PALETTES (lane colours are fixed, the art must make them stand out):
- Zone 1 SKYLINE ROOFTOP: sunny city rooftop, warm concrete, sky blue, white, gold trim; lane matte deep teal with cream edges.
- Zone 2 SUNSET BOARDWALK: wooden pier over a turquoise sea, sand #F0D696, turquoise #40CED6, coral #FF7864, red-and-white stripes, pastel huts; lane deep sea navy.
- Zone 3 JUNGLE FALLS: green jungle valley, grass #60B854, aqua water #46D2DC, orange #FF9632, mossy stone, bamboo, carved temple stone with gold; lane deep mahogany.
- Zone 4 CANYON OASIS: red-rock desert canyon, terracotta #D67C54, peach bands, turquoise #38C8C8, gold #FFC846, adobe, palms; lane deep plum.
```

---

## 4. Prompts

### U1. UI system + main HUD (do this first: everything else copies it)

```
Design the full UI SYSTEM and the main HUD (the screen you see while playing).

PART A - the kit (one board): the window frame (header plate, close X, body, tabs active/idle), buttons in all 5 action colours x 3 sizes with normal/pressed/disabled, the price button (coin / gem / Robux versions), the item card (art area, rarity edge, name, value line, button), a progress bar, a counter pill (icon + number), a red notification dot, a toast, a tooltip arrow bubble, a "???" locked silhouette card, a tick and a padlock badge. Show the spacing grid (8 px) and the type scale (only 4 sizes).

PART B - HUD, computer + phone:
- Top-left: COINS pill (coin icon, "1.47M", small "+95K/min" under it), GEMS pill, a small gold "x23.5" multiplier chip on the coin pill (tap = boost list).
- Left column, square icon buttons with a short label under each: SHOP, PETS, STORE, DAILY, PROFILE, TELEPORT; a wide gold REBIRTH button with a mini progress bar.
- Top-right: GIFTS (with red count dot), SETTINGS, PASSES.
- Bottom-left: the BAG: bag icon + "540/700 PINS" bar that turns orange at 80% and red + shaking "FULL" at 100%, and a big green SELL button next to it.
- Bottom-centre: the THROW button (big, hold to charge) with the power meter arc above it (keep the gold PERFECT zone + red OVERCHARGE cap idea, restyled).
- Top-centre: PINS DOWN counter (big number, small label) that pops on each throw.
- Right side: NEXT GOAL card: 3D SLOT for the next ball, "+40 PINS" and a progress bar with "12K/50K".
- Potion timers bottom-left above the bag: small round icons with a countdown ring.
- Remove the permanent "Throw > Sell > Buy" banner; instead design a ONE-TIME hint bubble with an arrow ("SELL HERE!") that points at a button.
MOTION NOTES I need: button press (squash 0.92 for 0.06 s, spring back with overshoot), counters rolling up digit by digit, coin icon pulses when coins are added, bag bar fill with a bump, "+25" pin chips flying from the pins counter into the bag, red dot pop-in, REBIRTH button shine sweep every 6 s when ready.
```

### U2. Shop, sell, rebirth, gates (the core loop screens)

```
Design the core loop screens, copying my UI system exactly.
1. SHOP window (opened at the shop stall or from SHOP): tabs BALLS, BAGS, REBIRTH, PASSES. BALLS/BAGS = a scrolling grid of item cards: 3D SLOT, name, "+70 PINS" (balls) or "HOLDS 3.7K" (bags), price button. States: OWNED (tick + EQUIP), BEST (gold edge + "BEST"), NEXT (glowing coral edge + "NEXT" tag), SKIPPED (small grey "SKIPPED" chip, still buyable), LOCKED ZONE (dark, padlock, "ZONE 3"), UNKNOWN (solid black silhouette, "???", only "+70 PINS" and price shown). A big green BUY BEST button bottom-right showing "+340 PINS" and the price; grey with the next price when unaffordable. A small zone switcher (zone 1-4 icons) at the top of the grid.
2. BUY REVEAL (1.6 s, over the card): silhouette flashes white, colour floods in, name drops in, burst in the rarity colour, "NEW!" stamp.
3. REBIRTH tab: left = your rank badge big (3D-look badge, rank colour) with arrow to the next rank badge; right = 2 big reward tiles with icons "x3 COINS" and "x2 PINS"; under them two icon rows: RESETS (coin, ball, bag, zone, pin icons, red tint) and KEEPS (pet, pass, rank icons, green tint). Bottom: price bar "5.4M / 5.4M" and a big gold HOLD TO REBIRTH button that fills left to right while held (1.5 s). Away from the shop the button becomes blue GO TO SHOP. No sentences.
4. REBIRTH! moment (full screen, 3 s): screen whites out, the new rank badge slams in with a shockwave ring, rays spin behind, "REBIRTH!" title, the 2 reward tiles fly in one after another, CONTINUE.
5. SELL: the sell pad pop when you sell: "+1.2M" coin burst number with "x23.5 BOOST" chip under it, coins arcing from the bag button into the coin pill.
6. WORLD SIGNS (SurfaceGui, seen from 40 studs): shop stall sign "BALLS & BAGS", sell stall sign "SELL", and the GATE sign: zone name, zone picture, price button (green when affordable, red when not), "OPEN" state after buying. Signs use icons, no instructions.
7. PASSES tab: 8 pass cards (2X COINS, 2X PINS, VIP, AUTO BOWL, LUCKY, SUPER LUCKY, +2 PET SLOTS, TRIPLE HATCH) with big icon art on light rays (like a speed-shop grid), green Robux buttons, "OWNED" state.
```

### U3. Pets, eggs, hatch, fusion

```
Design the pet screens, copying my UI system exactly. Players always see "PETS".
1. PETS window: tabs PETS / ITEMS. Top strip: equipped slots (3D SLOT circles, locked slots show a padlock and "5 REBIRTHS" or a Robux icon), the total boost shown with icons ("x14.5 coins icon", "x26 pins icon"), green EQUIP BEST. Grid of pet cards: 3D SLOT big, rarity edge, name, boost chips with icons (coin "+120%", pin "+100%"), count "x3", tick when equipped, SHINY = gold crown + sparkle edge. Sort chips: BEST / RARITY / NEW. Empty state: an egg icon + "NO PETS YET".
2. ITEMS tab: potion cards (coin, pins, XP, luck potions, normal + MEGA), art first, "x2  5:00", owned "x4", USE button.
3. EGG ODDS BOARD (floats over each egg in the world, 3D-space billboard): egg name, price button, pet row (3D SLOTs) with % under each, tap a pet = red X auto-delete toggle, buttons HATCH (E), AUTO, x3 (pass).
4. HATCH sequence frames (I need every frame drawn): egg shakes 3 times, each harder; cracks appear; light leaks out of the cracks in the rarity colour; white flash; pet pops up with rays and confetti; card below: rarity chip, name, boost chips, "NEW!" or "x2" stamp, OK + AUTO. Triple hatch = 3 cards side by side, the rarest one in the middle and bigger. Mythic version: screen darkens, red-pink lightning, longer wait.
5. FUSION window: 3 slots filling, arrow, shiny result 3D SLOT with gold crown, FUSE button / "NEED 1 MORE" state.
```

### U4. Rewards, moments, small stuff

```
Design these screens and moments, copying my UI system exactly. Short words, art first.
1. DAILY REWARD calendar: 7 day tiles (day 7 big gold tile), states CLAIMED/TODAY/LOCKED, big CLAIM button that becomes a countdown "18:22:05".
2. FREE GIFTS: 12 gift boxes (growing from small pink to big gold), states READY (bouncing)/COUNTING "12:34"/CLAIMED (open box + what it gave)/LOCKED.
3. DAILY SPIN wheel: 9 prize slices with icons, pointer, SPIN button, "NEXT SPIN 23:10:00"; YOU WON card.
4. ZONE UNLOCKED (full screen): zone picture card (I'll give 4 zone screenshots), zone name, "x6 PIN VALUE" chip, TAKE ME THERE / LATER.
5. FEVER MODE: top banner "FEVER x3", a 15 s bar, screen-edge flame glow frame (as a 9-slice PNG).
6. LANE EVENTS banner (top-centre): GOLDEN RACK x5, 7-10 SPLIT, GEM PIN - each with its own icon and colour.
7. TOASTS (top-centre, stack of 3), AFFORD NOTE ("NEW BALL!" + 3D SLOT + arrow to SHOP), ACHIEVEMENT unlocked toast, LEVEL-UP is no longer in the game - skip it.
8. PROFILE window: avatar slot, rank badge, 6 big stat tiles with icons (pins knocked, coins earned, rebirths, pets hatched, strikes, play time), ACHIEVEMENTS tab = rows with icon, name, progress bar, gem reward, CLAIM.
9. SETTINGS: 4 toggles (SOUND, EFFECTS, SHAKE, OTHERS' EFFECTS) with icons + MUSIC slider.
10. TELEPORT: 4 zone picture cards, GO / YOU ARE HERE / padlock + price.
11. AWAY COINS on join: "WHILE YOU WERE AWAY" coin pile art, "+4.2M", CLAIM / x2 with Robux.
```

### I1. Icon + badge sheet

```
Using my UI style block, make one ICON SHEET, every icon a separate 256x256 transparent PNG, all the same style (cel-shaded cartoon, solid colours only, no gradients, top-left light, 3 px #10172E outline):
1. HUD: shop, pets (paw), store (gift bag), daily (calendar gift), profile (crown), teleport (portal), gifts, settings, passes (ticket), rebirth (circular arrow + star), sell (coin bag), throw (ball + motion lines).
2. Currencies: coin, coin pile (small/medium/big), gem, gem pile, pin, pin pile, XP star.
3. Bags: 10 bag tiers as a ladder (pouch, sack, backpack, duffel, sports bag, rolling case, treasure sack, safe, vault bag, cosmic bag), each clearly bigger and fancier, neutral colours (the game tints them per zone).
4. Passes: 2X COINS, 2X PINS (pins with a big "2X"), VIP, AUTO BOWL, LUCKY (clover), SUPER LUCKY (gold clover), +2 PET SLOTS, TRIPLE HATCH.
5. Potions: coin, pins, XP, luck - normal and MEGA (MEGA = bigger bottle, gold cap, sparkles).
6. 17 REBIRTH RANK BADGES, shape gets grander each rank, each in its own colour: Rookie, Amateur, Regular, Club, Semi-Pro, Pro, Elite, Master, Legend, Hall of Famer, Superstar, Icon, Champion, World Champion, Immortal, Titan, Bowling God (plus a "II/III" roman-numeral plate that sits on top).
7. Lane events + fever: golden rack, 7-10 split, gem pin, fever flame.
8. Small: lock, tick, close X, red dot, arrow, info i, star, sparkle, light-rays background (512 px), confetti pieces (6 shapes).
```

### B. All 40 balls (one project, one zone per message)

```
Using my world style block: design 40 bowling balls for Strike Legends, 10 per zone, sent ONE ZONE PER MESSAGE (start with zone 1; I'll type "next"). Every ball must look exactly like its name and its zone, and each ball in a zone must look clearly fancier than the one before (rarity: Common plain, Uncommon 2 colours, Rare pattern, Epic glowing pattern, Legendary gold/metal + gems, Mythic animated-looking energy).
Rules: 1.8 studs across, under 2,500 triangles, smooth round sphere (paint and very flat details only, nothing sticking out more than 0.05 studs, so it rolls right), 3 finger holes, pivot centre, export .glb with colours/one texture. For each: front + back render, hex codes, triangle count, and one sentence describing its trail colour so the game can match the trail.
ZONE 1 SKYLINE ROOFTOP (sunny city roof): Beach Roller (C), Rubber Bouncer (C), Confetti Popper (U), Sunspike (U), Gust (R), Cloud Roll (R), Rainbow Arc (E), Sunbolt (E), Tornado (L), Sonic Boom (M).
ZONE 2 SUNSET BOARDWALK: Seashell Spinner (U), Beach Ball (U), Kite Flyer (U), Tide Turner (R), Coral Crusher (R), Surf Rider (R), Sunset Splash (E), Pier Pounder (E), Tsunami (E), Lighthouse Beam (L).
ZONE 3 JUNGLE FALLS: Vine Swinger (R), Coconut (R), Toucan Roll (R), Leaf Storm (E), Waterfall (E), Jaguar (E), Rope Bridge (L), Temple Stone (L), Monsoon (L), Jungle King (M).
ZONE 4 CANYON OASIS: Dust Devil (E), Cactus Roller (E), Mesa Smash (E), Sandstorm (L), Oasis Spring (L), Scorpion (L), Sun Disc (L), Canyon Echo (M), Mirage (M), Golden Sphinx (M).
(C Common, U Uncommon, R Rare, E Epic, L Legendary, M Mythic.)
```

### Z. Zone kits (one project, one zone per message)

```
Using my world style block: design the hand-made art kit for each zone of Strike Legends, ONE ZONE PER MESSAGE (I'll type "next"). Each zone has a huge shared bowling lane (the lane, gutters and pins already exist - don't redesign them). For every item: a render, size in studs, triangle count (under 6,000 per item unless I say), hex codes, .glb.

Every zone needs the same 6 "station" pieces, built in the zone's own materials:
 a) SHOP STALL "BALLS & BAGS" (12 wide, 12 tall): counter with balls and bags on display, awning/roof, a carved name sign.
 b) SELL STALL "SELL" (12 wide): counter with a big coin scale or coin chute, a sign.
 c) GATE to the next zone (20 wide, 18 tall): an arch with a price-sign board slot (blank board, the game draws on it), closed state (barrier) + open state.
 d) EGG + EGG STAND: the egg (2.4 studs tall, rounded, a pattern that fits the zone) on a stand (8 wide) that has a glowing hatch ring; the stand should look built for this zone.
 g) THE ZONE'S PETS (all new designs, nothing reused): cute, round, chunky, 2-3 studs, under 3,000 triangles each, front + side + idle pose. Each pet must look clearly stronger/fancier than the one before it (rarity: Common plain, Uncommon 2 colours, Rare a pattern or accessory, Epic glowing parts, Legendary gold/gems + aura shape, Mythic energy/floating parts). Make them a matching family for the zone.
 e) DISPLAY CASE for showing a ball (4 wide, 7 tall), 6 rarity versions (only the trim/glow colour changes).
 f) 3 big HERO PROPS that make the zone recognisable from far away (under 15,000 triangles each).

ZONE 1 SKYLINE ROOFTOP (sunny daytime city roof): stalls from rooftop stuff (AC units, water tower wood, steel beams, string lights); gate = a rooftop sky-bridge door to "SUNSET BOARDWALK". Egg = ROOFTOP EGG (cream with sky-blue speckles and a little brick pattern) on a stand made like a rooftop water tank base. Pets: PIDGE (chubby rooftop pigeon, Common), GRAVEL (little pebble creature with a hard hat, Common), VENT PUFF (fluffy puff blown out of an AC vent, Uncommon), KITE PUP (puppy with a windsock tail, Uncommon), SOLAR CAT (tiny cat with a solar-panel back and sun-ray mane, Rare). Hero props: rooftop water tower, billboard frame (blank), pigeon coop with pigeons.

ZONE 2 SUNSET BOARDWALK (pier over a turquoise sea): stalls = striped beach huts with surfboards and life rings; gate = a carved driftwood arch to "JUNGLE FALLS". Egg = SHELL EGG: a seashell-and-coral patterned egg on a sandcastle stand with a starfish ring. Pets: SANDY CRAB (Uncommon), GULL BUDDY (seagull with a tiny sailor hat, Uncommon), OTTER POP (otter holding a shell, Rare), SEA STAR (starfish with a glowing centre, Rare), PUFFER (pufferfish that glows when puffed, Epic), SURF SEAL (seal on a tiny glowing surfboard, Epic). Hero props: ferris wheel (50 tall, slow-turning wheel as its own part), red-and-white lighthouse on a rock, pastel beach huts (3 variations), lifeguard tower.

ZONE 3 JUNGLE FALLS (jungle valley with waterfalls): stalls = bamboo + thatch huts with carved wooden signs and hanging lanterns; gate = a vine-covered stone temple doorway to "CANYON OASIS". Egg = JUNGLE EGG: leafy, mossy egg on a carved stone altar with glowing glyphs. Pets: TREE FROG (Rare), TOUCAN TOM (Epic), TEMPLE MONKEY (monkey with a gold temple crown, Legendary), JAGUAR CUB (spotted cub with glowing gold spots, Legendary). Hero props: stepped temple ruin with a gold sun, rope bridge (walkable plank set), waterfall cliff piece (stacked mossy ledges, the game adds the water), giant jungle tree.

ZONE 4 CANYON OASIS (red-rock desert): stalls = adobe market stalls with striped rugs, clay pots, chilli strings; gate = a banded sandstone arch with gold suns (last zone: make it a "back to rooftop" arch). Egg = SUN EGG: sun-gold egg with turquoise tile pattern on a sandstone pedestal with a gold sun disc. Pets: FENNEC (big-eared desert fox, Epic), CACTUS PAL (round cactus buddy with a pink flower, Legendary), SCARAB (gold-and-turquoise beetle with floating wing shards, Mythic), SPHINX KITTEN (tiny golden sphinx cat with glowing eyes and a floating headdress, Mythic). Hero props: natural stone arch (rock, 60 wide), golden sphinx on a plinth, hoodoo rock towers (3 variations), striped hot-air balloon.
```

### T. Thumbnails + game icon (refresh)

```
Using my world style block, make the Roblox GAME ICON (512x512) and 3 THUMBNAILS (1920x1080) for "Strike Legends". Show only what is really in the game: the sunny Skyline Rooftop lane, the Sunset Boardwalk pier, Jungle Falls, Canyon Oasis, a giant glowing ball smashing a huge pile of pins, coin explosions, a pet next to the player. Thumbnail 1 = the strike moment close up (ball + pins exploding + "x23.5" style number art, no extra text), 2 = the 4 zones as a split collage, 3 = hatching a Mythic pet with friends watching. Icon = one ball smashing pins with a big glow, readable at 50x50. Logo "STRIKE LEGENDS" as a separate transparent PNG. No fake UI, no things that aren't in the game.
```

---

## 5. Sounds (ElevenLabs, not Claude Design)

Borrowed now: zone 2-4 ball effects reuse whoosh / thud / boss-hit. Suggested (each under 2 s unless marked):
- **Ambience loops (20-40 s, seamless):** pier sea waves + gulls; jungle birds + distant waterfall; desert wind + light chimes.
- **Sea:** big water splash, wave crash with foam hiss, wooden pier thud.
- **Jungle:** vine whip crack, coconut bonk + crack, toucan call, leaf whoosh, stone slab slam, thunder crack + heavy rain burst.
- **Desert:** sand whoosh, rock-wall rumble rising, scorpion hiss + sting, sun-disc magical burn, mirage shimmer, sphinx stone grind + roar.
- **UI (to match the new motion):** soft pop for button press, rising sparkle for counter roll, coin chime chain (3 pitches), bag-full warning thud, silhouette reveal "whoomp".
