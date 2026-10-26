# Asset prompts (rewritten 2026-10-27)

Everything in the game that is still a placeholder, and a ready-to-paste prompt for each. Launch = zones 1 to 4.
Old prompts that are finished (zone 1/3/4 worlds, Back Alley balls/pins/crate, Rizzo, Store, HUD, Ball Book, Crate Kit) are in git history.

**How to use:** paste the zone's Style block first, then the prompt, into Claude Design (one design project per prompt). Bring the result back to Claude Code; Claude rebuilds it in the game. Sounds and music can't be made in Claude Design (see part 5).

**Rule for every 3D model** (it is already in each prompt): low-poly, export .fbx or .glb, pivot at the bottom centre (balls: centre), flat colours or one small texture, no text, no real brands. Scripts can't upload meshes: you import them in Studio (File > Import 3D), then tell Claude.

---

## Part 0: the zone styles (the rule everything follows)

Every ball, crate, pet, egg, pin and booth must look like it came from its zone. These blocks are written from the zones as they are built now. Paste the right one first.

### Style: Zone 1 Back Alley

```
ZONE STYLE - BACK ALLEY (zone 1, the start): a run-down outdoor city alley at night. Cracked lanes, brick walls with original graffiti, trash cans, pallets, a flickering pink "LANES" neon sign, fog. Things here are made from junk and street stuff: duct tape, rust, scuffed paint, bungee cords, spray paint, hubcaps, chipped enamel. Colours: muted greys, brick red, rust orange, dirty off-white, with small pops of pink neon (#FF4FB0) and cold blue (#2BE4FF). Feels scrappy, funny and hopeful, never gross or scary.
```

### Style: Zone 2 Neon Lanes

```
ZONE STYLE - NEON LANES (zone 2): an indoor night-time bowling club, dark purple-black walls, glowing pink and cyan neon tubes, chrome, black-light glow, synthwave. Things here are sleek and glowing: neon edges, glowing cracks, chrome trim, holographic shine. Colours: near-black #0E0D1A and navy #1A1C52, hot pink #FF4FB0, cyan #2BE4FF, violet #AA3CFF, a little gold. Feels like a cool club for teens.
```

### Style: Zone 3 Main Street Lanes

```
ZONE STYLE - MAIN STREET LANES (zone 3): a classic, real-life indoor bowling centre in daylight-warm light. Polished light-wood lanes with arrow markings, ball returns, a shoe rental counter, a snack bar, plastic bench seats, patterned retro carpet (navy with orange and red confetti shapes), cream walls with a red and royal-blue stripe. Things here are classic and well made: glossy enamel, marble swirls, polished wood, chrome, red vinyl, league patches, trophies, varsity letters. Colours: warm wood #C8915A, cream #F2E6CF, deep red #C21E37, royal blue #2A4FB8, orange #F08A24, a touch of gold #E2B24A. Feels like a friendly hometown league night: warm, bright, retro, no neon.
```

### Style: Zone 4 Skyline Lanes

```
ZONE STYLE - SKYLINE LANES (zone 4, the top at launch): open-air lanes on the roof of a huge skyscraper at night. Navy-black starry sky, the city's lights far below, pearl-white floor and lanes, gold railings and trim, floodlights on poles, a helipad. Things here are rich and premium: pearl, polished gold, crystal, glass, starlight, clouds, a little moonlight silver. Colours: night navy #0B1030, pearl white #F4F1EA, gold #FFC93A, sky blue #8FD3FF, soft lilac #B9A6FF. Feels like you made it: expensive, calm, glittering, high up.
```

---

## Part 1: what is still a placeholder (checklist)

Real already (keep): zone 1-4 worlds, zone 1 balls/pins/Alley Crate/Rizzo, zone 2 balls (9) + Neon Egg + its 6 pets + egg stand, zone 3 and 4 pins, the crate kiosk, the power meter, result text, payout pop, Store Kit, HUD Kit, Ball Book + multiplier card, Crate Kit (shop, odds, reel, reveal, pull banner).

| # | Placeholder now | What it is today | Prompt |
|---|---|---|---|
| 1 | 7 zone 3 balls (League Black, Cherry Swirl, Blue Marble, Pearl Pro, Tiger Swirl, Championship, Perfect 300) | zone 1/2 ball models painted one colour | 2A |
| 2 | 6 zone 4 balls (Cloud Swirl, Crystal, Sunburst, Solid Gold, Lightning, Daybreak) | zone 2 models recoloured | 2B |
| 3 | 4 zone 1 commons (Bubblegum, Lime Twist, Tangerine, Deep Ocean) + Rookie Ball | real, but neon-era looks that don't match the alley | 2C (optional) |
| 4 | Bronze, Silver, Gold crates (zone 2) | recoloured copies of one model | 3A |
| 5 | League + Champion crates (zone 3) | borrowed model | 3B |
| 6 | Sky Bronze, Sky Silver, Sky Gold crates (zone 4) | borrowed model | 3C |
| 7 | Zone 3 + zone 4 crate counters | plain booths built from parts | 3B, 3C |
| 8 | Main Street Egg + its stand (zone 3) | no model, plain pad | 4B |
| 9 | Skyline Egg + its stand (zone 4) | no model, plain pad | 4C |
| 10 | Wood Pup, Chrome Bat (zone 3 pets) | Lane Pup / Neon Bat repainted | 4B |
| 11 | Cloud Bumper, Moony (zone 4 pets) | Bumper / Hambone repainted | 4C |
| 12 | Kingpin, Blaze (in zone 3's egg) + Cosmo, Perfecto (in zone 4's egg) | real, but designed for Neon Lanes; owner chose to restyle them | 4B, 4C |
| 13 | Titan Jr. (boss reward pet) | Pinny repainted dark | 4D |
| 14 | Zone 3 + 4 ball display cases | the zone 2 case recoloured | 6A |
| 15 | Pet fusion station (zone 3) | plain booth | 6B |
| 16 | Pin Titan boss, its floating arena, the helicopter, the thrown pin | big plain pin, round platform, part-built chopper | 6C |
| 17 | Cosmetic store pictures (trails, strike banners, pin blasts, lane skins) | Claude's made-up icons/textures | 7G |
| 18 | 2D UI: pets panel + hatch card, daily calendar, gifts panel, spin wheel, level/rank-up, rank trial, zone unlocked, milestones, lane popups, first-3-minutes callouts, teleport, rebirth, toasts, Rizzo bubble, boss screens, offer popups | Claude's own design | 7A-7F |
| 19 | Fonts | Montserrat Heavy Italic stands in for Rubik, Fredoka One for Lilita One | 7 (style block) |
| 20 | All 31 sound slots (18 Creator Store picks + 13 borrowed stand-ins) | see Part 5 | 5 |
| 21 | Background music | none at all | 5 |
| 22 | Game icon, thumbnails, final title | none | 8 |

Not for launch (skip): zones 5-6, the old Neon crate (removed).

---

## Part 2: balls

Ball rules for every ball prompt: 1.8 studs across, under 2,500 triangles, a smooth round sphere (decoration in paint and very flat detail, nothing sticking out more than 0.05 studs), the 3 finger holes, pivot at the centre. The game adds the glow, trail and sparkles itself, by rarity (Common grey, Uncommon green, Rare blue, Epic purple, Legendary gold, Mythic red-pink).

### 2A. Zone 3 balls (7): paste Style Zone 3 first

```
Design 7 bowling balls for MAIN STREET LANES, zone 3 of a Roblox bowling simulator for kids and teens. These are classic league balls, the kind real bowlers own, made beautiful: glossy enamel, marble and swirl resin, pearl finishes, league patches. Each must be recognisable from 20 studs away by its colour pattern alone, and each must clearly beat the zone 2 neon balls in "realness" while staying fun.

Rules: 1.8 studs across (Roblox studs), under 2,500 triangles each, a smooth round sphere (decoration in paint and very flat detail, nothing sticking out more than 0.05 studs), keep the 3 finger holes, pivot at the centre, one small texture or flat colours, no text, no real brands, no real logos.

The 7 balls (rarity in brackets; better rarity = more special):
1. "League Black" (Rare): the classic jet-black league ball, deep gloss, a thin red pinstripe ring and one small round league patch shape (no text).
2. "Cherry Swirl" (Rare): deep cherry-red and cream marble swirl, like a soda-fountain sundae.
3. "Blue Marble" (Rare): royal blue and white marble veins, like polished stone.
4. "Pearl Pro" (Epic): pearl-white with a soft rainbow pearl shimmer and a gold ring around the finger holes.
5. "Tiger Swirl" (Epic): bold orange and black tiger stripes in glossy resin, a little amber see-through depth.
6. "Championship" (Legendary): a trophy made into a ball: polished gold with a royal-blue band, laurel leaves engraved around it.
7. "Perfect 300" (Legendary): the perfect-game ball: deep red with 12 small gold strike marks (X shapes) circling it and a gold crown shape over the finger holes.

For each ball also suggest a trail colour and one short effect idea when it rolls.

Please give me:
1. All 7 side by side, then each one from the front (finger holes visible).
2. Hex codes for each ball's colours and suggested trail colour.
3. The triangle count of each model.
```

### 2B. Zone 4 balls (6): paste Style Zone 4 first

```
Design 6 bowling balls for SKYLINE LANES, zone 4 and the top zone of a Roblox bowling simulator for kids and teens. These are the rarest balls in the game: premium, glittering and high-up: pearl, gold, crystal, clouds, starlight, storm. They must look clearly better than the zone 3 league balls.

Rules: 1.8 studs across (Roblox studs), under 2,500 triangles each, a smooth round sphere (decoration in paint and very flat detail, nothing sticking out more than 0.05 studs), keep the 3 finger holes, pivot at the centre, one small texture or flat colours, no text, no real brands.

The 6 balls:
1. "Cloud Swirl" (Epic): soft white clouds swirling over sky blue, like looking down from a plane.
2. "Crystal" (Epic): faceted see-through ice-blue crystal with light glinting inside.
3. "Sunburst" (Legendary): polished gold with orange-gold rays bursting out from the finger holes.
4. "Solid Gold" (Legendary): a heavy solid-gold bar made round, mirror shine, a few engraved lines, a tiny diamond set in the thumb hole rim.
5. "Lightning" (Mythic): a night-navy storm ball with bright yellow-white lightning cracks across it that look like they glow from inside.
6. "Daybreak" (Mythic): the night sky turning to sunrise across the ball: navy with stars on one side, pink-orange dawn on the other, a thin gold line where they meet.

For each ball also suggest a trail colour and one short effect idea when it rolls.

Please give me:
1. All 6 side by side, then each one from the front (finger holes visible).
2. Hex codes for each ball's colours and suggested trail colour.
3. The triangle count of each model.
```

### 2C. Zone 1 commons re-skin (optional): paste Style Zone 1 first

These 5 are real models already, but they were made before the Back Alley existed and look like clean neon balls. Re-skinning keeps their names and nobody loses anything.

```
Re-skin 5 common bowling balls so they fit BACK ALLEY, zone 1 of a Roblox bowling simulator for kids and teens. They are the very first balls a new player sees, made from junk and street stuff but still fun. Keep their names.

Rules: 1.8 studs across, under 2,500 triangles each, smooth round sphere (paint and very flat detail only, nothing sticking out more than 0.05 studs), keep the 3 finger holes, pivot at the centre, no text, no real brands.

1. "Rookie Ball" (Common, the starter ball everyone has): a scuffed old house ball, faded blue-grey, a chipped white number-plate shape (no number).
2. "Bubblegum" (Common): pink ball with blobs of chewed gum stuck on it and one gum bubble shape painted flat.
3. "Lime Twist" (Common): a lime-green spray-painted ball with drippy spray-paint swirls.
4. "Tangerine" (Common): traffic-cone orange with a white reflective stripe, like it was made from a road cone.
5. "Deep Ocean" (Common): a dark blue ball with rain-puddle reflections and a little oil-slick rainbow.

Please give me: all 5 side by side, each from the front, hex codes, triangle counts.
```

---

## Part 3: crates

Crate rules for every crate prompt: about 3 studs wide, under 1,500 triangles, the lid a separate piece hinged at the back edge (the game flips it open), pivot at the bottom centre, no text. Inside each zone, the crates go up in value: the cheapest looks plain, the dearest looks amazing.

### 3A. Zone 2 crates: Bronze, Silver, Gold: paste Style Zone 2 first

```
Design 3 loot crates for NEON LANES, zone 2 of a Roblox bowling simulator for kids and teens: BRONZE CRATE, SILVER CRATE and GOLD CRATE. Same family, clearly different tiers: Bronze = dark chrome box with copper-pink neon edges; Silver = brushed silver with cyan neon edges and a glowing bowling-pin shape on the front; Gold = black-and-gold with hot pink and gold neon, a holographic panel on the lid and small gold pin shapes on each corner. Each should look worth more than the one before at a glance.

Rules: about 3 studs wide (Roblox studs), under 1,500 triangles each, the lid a separate piece hinged at the back edge so the game can flip it open, pivot at the bottom centre, flat colours or one small texture, no text, no real brands. Neon parts as separate pieces so the game can make them glow.

Please give me: the 3 side by side, each closed and open with light spilling out, hex codes, triangle counts.
```

### 3B. Zone 3 crates: League + Champion, and the crate counter: paste Style Zone 3 first

```
Design 2 loot crates and 1 counter for MAIN STREET LANES, zone 3 of a Roblox bowling simulator for kids and teens.

1. "LEAGUE CRATE": a sturdy bowling-bag-meets-wooden-crate: polished wood with red and royal-blue painted stripes, brass corners, a leather strap and buckle across the lid.
2. "CHAMPION CRATE" (the better one): a trophy case crate: royal blue with gold trim, a glass window on the front with a small gold trophy shape inside, a gold star on the lid.
Rules for both: about 3 studs wide, under 1,500 triangles, the lid a separate piece hinged at the back edge, pivot at the bottom centre, no text, no real brands.

3. THE CRATE COUNTER where players buy these crates: the bowling centre's prize counter. About 10 studs wide, 4 studs deep, 4 studs tall, glass-front display with the two crates inside, a red and cream striped awning, a little bell on the counter, a spot in front where the player stands. Under 3,000 triangles. Pivot at the bottom centre.

Please give me: both crates closed and open, the counter from the front and 3/4, hex codes, triangle counts.
```

### 3C. Zone 4 crates: Sky Bronze, Sky Silver, Sky Gold, and the crate counter: paste Style Zone 4 first

```
Design 3 loot crates and 1 counter for SKYLINE LANES, zone 4 and the top zone of a Roblox bowling simulator for kids and teens. These are the most expensive crates in the game and must look it.

1. "SKY BRONZE CRATE": pearl-white case with rose-bronze trim and a small cloud shape on the lid.
2. "SKY SILVER CRATE": pearl-white and moonlight silver, a ring of small stars around the lid.
3. "SKY GOLD CRATE": a floating-looking pearl and gold vault, small gold wings on the sides (flat, close to the body), a crystal set in the lid.
Rules for all 3: about 3 studs wide, under 1,500 triangles, the lid a separate piece hinged at the back edge, pivot at the bottom centre, no text, no real brands.

4. THE CRATE COUNTER on the roof: a luxury concierge desk. About 10 studs wide, 4 deep, 4 tall, pearl-white with gold trim, a glass display holding the 3 crates, two small gold lamps, a spot in front where the player stands. Under 3,000 triangles. Pivot at the bottom centre.

Please give me: the 3 crates closed and open, the counter from the front and 3/4, hex codes, triangle counts.
```

---

## Part 4: pets and eggs

Players see "PETS". Every pet is about 1.6 studs across, follows the player, stands on the ground (or floats if it flies), and has a simple idle move the game animates from separate parts (wings, tails, ears, rings).

**What exists:** the Neon Egg (zone 2) and its 6 pets are real and fit Neon Lanes: Pinny, Lane Pup, Strikey, Splitz, Hambone, Neon Bat.

**The problem in zones 3 and 4:** each egg has 4 pets, and none of them were designed for that zone:
- Main Street Egg (zone 3): Wood Pup (Rare) and Chrome Bat (Epic) are repainted Lane Pup / Neon Bat. Kingpin and Blaze (Legendary) are real models, but they were designed as Neon Egg pets and moved here.
- Skyline Egg (zone 4): Cloud Bumper (Epic) and Moony (Legendary, was Sunny) are repainted Bumper / Hambone. Cosmo and Perfecto (Mythic) are real, but also from the Neon Egg.
- Neither egg has its own egg model or stand.
- Titan Jr. (boss reward) is a repainted Pinny.

**Decided (owner 2026-10-27):** all 8 zone 3 and 4 pets get new zone-style looks as below, plus each zone gets its own egg and stand. The pet IDs stay the same, so anyone who owns a pet gets the new look automatically and loses nothing. Sunny is renamed Moony (already renamed in the game).

| Zone 3 Main Street Egg | Today | Proposed new look |
|---|---|---|
| Wood Pup (Rare) | repainted Lane Pup | a puppy carved from polished lane wood, arrow markings on its back, a red bandana |
| Chrome Bat (Epic) | repainted Neon Bat | a retro diner bat: chrome body, red vinyl wings, a little jukebox-light belly |
| Kingpin (Legendary) | neon-era model | a classic white pin with red stripes, a gold crown and a red velvet cape: the king of league night |
| Blaze (Legendary) | neon-era fire fox | a fox in a 1950s bowling-shirt flame pattern (painted flames, not real fire), a cream and red jacket |

| Zone 4 Skyline Egg | Today | Proposed new look |
|---|---|---|
| Cloud Bumper (Epic) | repainted Bumper | a fluffy cloud puff with little gold bumper rails like lane guards |
| Moony (Legendary, was Sunny) | repainted Hambone | a sleepy moon-cat curled in a silver crescent |
| Cosmo (Mythic) | neon-era model | a star creature made of a small constellation, gold star joints, a navy body full of tiny stars |
| Perfecto (Mythic) | neon-era model | a pearl and gold perfect-game spirit: a floating 300 trophy with wings and a halo |

Titan Jr.: a chibi Pin Titan: a small stone-grey pin with cracked armour plates and one glowing core eye.

### 4A. Neon Egg (zone 2): nothing to do. Already real.

### 4B. Main Street Egg + stand + 4 pets: paste Style Zone 3 first

```
Design a pet egg, its hatching stand and 4 pets for MAIN STREET LANES, zone 3 of a Roblox bowling simulator for kids and teens. Pets follow the player around and must be cute, chunky and readable from far away, never scary.

Pet rules: about 1.6 studs across (Roblox studs), under 2,000 triangles each, pivot at the bottom centre, each moving part a separate named piece so the game can animate it (wing_L, wing_R, tail, ear_L, ear_R, cape, crown...), big readable eyes, flat colours or one small texture, no text, no real brands. Say which pets walk and which fly.

The egg: "MAIN STREET EGG", 2.5 studs tall, cream with a red and royal-blue bowling-shirt stripe and a gold pin shape. Under 1,000 triangles.
The stand: a round prize-counter pedestal about 6 studs across, polished wood and chrome, a red velvet top where the egg sits, a little scoreboard shape behind it (no text). Under 2,500 triangles.

The 4 pets (rarity in brackets):
1. "Wood Pup" (Rare): a puppy carved from polished lane wood, arrow markings on its back, a red bandana. Walks. Idle: wags its tail.
2. "Chrome Bat" (Epic): a retro diner bat, chrome body, red vinyl wings, a glowing jukebox-light belly. Flies. Idle: slow wing flaps.
3. "Kingpin" (Legendary): a classic white bowling pin with red stripes, a gold crown and a short red velvet cape, little arms. Walks. Idle: adjusts its crown.
4. "Blaze" (Legendary): a fox wearing a 1950s bowling-shirt flame pattern (painted, not real fire), cream and red. Walks. Idle: swishes its big tail.

Please give me: all 4 pets side by side next to the egg, each pet front + side, the egg, the stand with the egg on it, hex codes, triangle counts.
```

### 4C. Skyline Egg + stand + 4 pets: paste Style Zone 4 first

```
Design a pet egg, its hatching stand and 4 pets for SKYLINE LANES, zone 4 and the top zone of a Roblox bowling simulator for kids and teens. These are the rarest pets in the game: glittering and magical, still cute and chunky.

Pet rules: about 1.6 studs across (Roblox studs), under 2,000 triangles each, pivot at the bottom centre, each moving part a separate named piece (wing_L, wing_R, tail, ring, halo...), big readable eyes, flat colours or one small texture, no text, no real brands. Say which pets walk and which fly.

The egg: "SKYLINE EGG", 2.5 studs tall, pearl-white with a gold band and a small night-sky window showing stars. Under 1,000 triangles.
The stand: a floating gold ring pedestal about 6 studs across over a pearl base, small cloud puffs around the bottom. Under 2,500 triangles.

The 4 pets:
1. "Cloud Bumper" (Epic): a fluffy cloud puff with little gold bumper rails along its sides. Floats. Idle: puffs up and down.
2. "Moony" (Legendary): a sleepy moon-cat curled in a silver crescent moon, soft lilac and moonlight silver, a tiny gold star on its collar. Floats. Idle: the crescent rocks slowly like a cradle and its eyes blink.
3. "Cosmo" (Mythic): a little star creature made of a constellation, navy body full of tiny stars, gold star joints. Floats. Idle: its stars twinkle.
4. "Perfecto" (Mythic): a pearl and gold perfect-game spirit: a small floating trophy with wings and a halo. Floats. Idle: wings beat, halo turns.

Please give me: all 4 pets side by side next to the egg, each pet front + side, the egg, the stand with the egg on it, hex codes, triangle counts.
```

### 4D. Titan Jr. (boss reward pet): paste Style Zone 4 first

```
Design one pet for a Roblox bowling simulator for kids and teens: "Titan Jr." (Legendary), the reward for beating the Pin Titan boss on the Skyline Lanes roof. A chibi version of the boss: a short, chunky stone-grey bowling pin with cracked armour plates, gold rivets, one big glowing gold core eye and tiny stubby arms. Cute, proud, not scary. About 1.6 studs across, under 2,000 triangles, pivot at the bottom centre, arms as separate pieces (arm_L, arm_R). Walks. Idle: flexes. Give me front + side, hex codes and the triangle count.
```

---

## Part 5: sounds and music (outside Claude Design)

Claude can't listen to sound, so you pick these. Easiest: Roblox Studio > Toolbox > Audio (Creator Store, free), or an AI sound tool, then upload. Send Claude the IDs and it puts each one in place. Short and punchy is best (under 1 second unless marked).

**Never picked, playing a borrowed sound now (13):** OverchargeWarn (meter enters the red, rising warning), OverchargeBlast (risky throw paid off, huge boom), Overcooked (risky throw failed, sad trombone-ish gutter), PowerUp (bought a Power Level, power-up whoosh), HatchCharge (egg stand charging up, 2-3 s rising hum), HatchCrack (egg crack snap), HatchBurst (shell bursts, magic pop), ElevatorDing (elevator doors open), BossSiren (boss is coming, 2-3 s), BossHit (ball hits the stone titan), BossPlate (armour plate breaks off), BossRoar (titan roar, 1-2 s), Helicopter (takeoff/landing, 3-4 s loop).

**Picked quickly from the Creator Store, worth checking (18):** Click, Tap, Charge, Throw, Roll, PinHit, StrikeCrash, PerfectSting, Cheer, Firework, Coin, StreakUp, StreakLost, RankUp, ReelTick, Reveal, RevealBig.

**Missing completely: music.** Suggested one loop per zone (1-3 minutes, loops cleanly, quiet under the sound effects):
- Back Alley: lo-fi hip-hop beat with vinyl crackle.
- Neon Lanes: upbeat synthwave.
- Main Street Lanes: bright retro surf / 60s jukebox rock.
- Skyline Lanes: smooth night-time funk / city-pop with sparkle.
- Boss fight: fast, heavy drums and brass (1 loop).
Roblox has a free licensed music library in the Toolbox (filter: Music); those tracks are safe to use.

---

## Part 6: zone pieces still placeholder

### 6A. Display cases for zones 3 and 4: paste the zone's Style first (one project each)

```
Design one ball display case for [MAIN STREET LANES / SKYLINE LANES] in a Roblox bowling simulator for kids and teens. A row of these shows every ball in the zone: owned balls float lit up inside, missing ones are dark silhouettes. Main Street version: a wooden trophy cabinet with a glass front, brass trim, a red velvet pedestal and a small blank plaque. Skyline version: a pearl and gold glass column with a floating ring pedestal and a soft light from above.
About 4 studs wide, 4 deep, 8 tall. Under 2,500 triangles. Glass as a separate piece. The ball (1.8 studs) floats in the middle, so leave the space empty. Pivot at the bottom centre. Also show how the case changes by rarity: a coloured band at the base (Rare blue, Epic purple, Legendary gold, Mythic red-pink), plus gold posts and a diamond on top for Legendary and Mythic.
Please give me: the case alone, a row of 4 with different rarity bands, hex codes, triangle count.
```

### 6B. Pet fusion station (zone 3): paste Style Zone 3 first

```
Design a "PET FUSION" machine for MAIN STREET LANES in a Roblox bowling simulator for kids and teens: players put 3 copies of a pet in and get a shiny one. Make it a retro ball-polishing machine crossed with a claw machine: cream and red body, chrome, 3 round glass pods on top where pets sit, a big lever, a sign shape on top with room for the words "PET FUSION" (the game adds the text). About 8 studs wide, 5 deep, 9 tall. Under 3,000 triangles. Pivot at the bottom centre. The pods and lever as separate pieces. Give me front and 3/4 views, hex codes and the triangle count.
```

### 6C. Pin Titan boss, arena, helicopter: paste Style Zone 4 first

```
Design a boss and its arena for a Roblox bowling simulator for kids and teens. Every so often players fly by helicopter from the Skyline Lanes roof to a floating platform in the night sky and bowl at a giant boss together.

1. "THE PIN TITAN": a giant stone bowling pin, 30 studs tall, cracked grey stone body with gold rivets, 6 armour plates that break off one by one (each a separate piece: plate_1..plate_6), a core in its chest that opens (core_door separate) to show a glowing gold core, two big stubby arms (separate) that slam the ground, angry but cartoon-funny eyes. Under 10,000 triangles.
2. The arena: a round floating platform 120 studs across, pearl-white and gold edge, gold lane markings radiating to the middle, rocks and clouds under it. Under 6,000 triangles.
3. The helicopter: a chunky cartoon chopper, white and gold, room for 4 players, rotor as a separate piece. About 20 studs long. Under 4,000 triangles.
4. The pin it throws: a 3-stud stone pin with a gold band. Under 400 triangles.
Pivot at the bottom centre for all. Please give me: the Titan front and side, the Titan with plates broken off and core open, the arena from above and at an angle with the Titan on it, the helicopter, hex codes, triangle counts.
```

---

## Part 7: 2D screens still in Claude's design

Done and kept: power meter, result text, payout pop, Store Kit, HUD Kit, Ball Book + multiplier card, Crate Kit. Paste the shared UI style block first, then one prompt (one design project each).

### Shared UI style block (paste first, every time)

```
Game: "Strike Legends", a Roblox bowling simulator for kids and teens (ages 9 to 15). Match my existing HUD Kit, Store Kit and Crate Kit designs exactly: dark navy panels (#070B1E, cards #1E143C), thick dark ink outlines (#04061A) around every text and button, chunky rounded corners with a darker bottom lip so buttons look pressable, bright neon accents: gold #FFC93A, cyan #2BE4FF, hot pink #FF4FB0, lime #7DFF3C, red #FF2D4A. Big bold cartoon headings, short punchy words, all caps. Rarity colours: Common grey, Uncommon green, Rare blue, Epic purple, Legendary gold, Mythic red-pink. Only fonts Roblox has: Luckiest Guy (headings and buttons), Fredoka One (numbers), Gotham Bold / Black (small text). Exciting and generous, never pushy: no fake timers, every popup has an obvious way to close it.

Design for a computer (1920x1080) and a phone held sideways (844x390; the top 36 px are Roblox's own bar and the bottom-left corner has the movement thumbstick, keep tappable things out of it). Every tappable thing is at least 44x44 px on the phone.

Please give me: full-screen mockups on both screens; each piece on its own with sizes in px, corner radius, outline thickness, font, font size and hex code for every colour; every state (normal, pressed, locked, ready, done); simple animation notes using only scale, position, rotation and transparency tweens; and every icon as a separate transparent PNG so I can upload it. Where a 3D ball, pet or crate will spin, leave an empty slot and label it "3D SLOT".
```

### 7A. Pets panel and hatch card

```
Design the pet screens (players always see "PETS").
1. THE PETS PANEL, opened by the PETS button. About 820x560, tabs PETS and ITEMS. PETS tab: a row of equipped slots at the top (3 open slots, then locked slots "LV 15" and "LV 30", plus 2 more with the +2 PET SLOTS pass), an EQUIP BEST button, the total bonus "+186% COINS", then a grid of owned pet cards: 3D SLOT, name, rarity colour frame, bonus "+12%", count "x3", EQUIP / UNEQUIP, and a MERGE button when you own 3 ("MERGE 3 > SHINY"). Shiny pets get a gold crown and a sparkle frame. Empty state: "NO PETS YET - HATCH THE NEON EGG". ITEMS tab: potion cards (COIN POTION, MEGA COIN POTION, XP POTION, MEGA XP POTION) with an icon, "x2 COINS FOR 5:00", how many you own "x4" and a DRINK button.
2. THE HATCH CARD (after the egg cracks): the pet big in the middle (3D SLOT) with rays in its rarity colour, rarity name, pet name, "+12% COINS", "NEW!" and OK; a triple-hatch version with 3 cards side by side.
3. THE FUSION WINDOW (zone 3 station): 3 pet slots filling up, an arrow, the Shiny result (3D SLOT with a gold crown), a FUSE button and "NEED 1 MORE".
```

### 7B. Daily rewards, gifts, spin wheel

```
Design four reward windows.
1. DAILY REWARDS calendar (on join when a reward is waiting, and from the DAILY button). About 760x460. Title "DAILY REWARD", line "Come back every day for bigger rewards", 7 day tiles "DAY 1".."DAY 7" with a reward icon and text ("300B COINS", "3x COIN POTION", "FREE NEON EGG +10 GEMS", "GOLD CRATE +2x MEGA COIN POTION +25 GEMS"). States: CLAIMED (dimmed, tick), TODAY (glowing, bigger), LOCKED (dark). Day 7 is a big gold tile. A big lime "CLAIM DAY 1!" button, which becomes "COME BACK IN 18:22:05", and a small line "MISS A DAY? YOU GET 1 GRACE DAY". Close X.
2. PLAYTIME GIFTS panel (GIFTS button). About 760x500. Title "FREE GIFTS", line "A NEW GIFT EVERY FEW MINUTES YOU PLAY", a 4x3 grid of 12 gift boxes. States: READY (bouncing, lime CLAIM), COUNTING ("12:34" under a closed box), CLAIMED (open box, tick, what it gave), LOCKED. Boxes grow from small pink to big gold toward gift 12.
3. THE DAILY SPIN WHEEL: a big wheel with 9 prize slices: COIN POTION, NEON EGG, XP POTION, BRONZE CRATE, MEGA COIN, MEGA XP, SILVER CRATE, and two thin gold slices SECRET BALL and SECRET PET, a pointer at the top, a SPIN button, "FREE SPIN IN 23:10:00" when used.
4. SPIN PRIZE CARD: about 360x240, "YOU WON!", the prize icon and text, OK button.
```

### 7C. Big moments

```
Design the celebration popups. They show for 2-4 seconds unless they have a button.
1. LEVEL UP: a centre burst "LEVEL UP!" with "LV 37" and the rewards under it ("+2 GEMS").
2. RANK UP (full screen): "RANK UP!" with the new tier badge and name. Give each tier its own badge shape and colour: Rookie, Amateur, Regular, Club, Semi-Pro, Pro, Elite, Master, Legend, Hall of Famer. Confetti and a CONTINUE button. Also give me the 10 badges as separate PNGs.
3. RANK TRIAL: a pulsing "RANK TRIAL READY" button (140x40); the intro popup "PRO TRIAL - GET 3 STRIKES IN 10 THROWS" with START and LATER; a small live tracker (one dot per strike needed, "6 THROWS LEFT"); a big "PASSED!" banner (lime) and "FAILED" banner (red, "TRY AGAIN IN 2:00").
4. ZONE UNLOCKED window: "ZONE UNLOCKED!", the zone name ("MAIN STREET LANES"), "x16 COINS · 100 PINS", a row of 3D SLOTs for what's new there (balls, crate, egg), "TAKE ME THERE" and CLOSE.
5. MILESTONES: a small tracker under the POWER LV button ("CHALLENGE: 3 STRIKES IN A ROW 1/3"), a "NEXT LEVEL REWARD: LV 9 - SILVER CRATE" card, and the payout popup "CHALLENGE DONE!".
6. LANE POPUPS near the top centre: "GOLDEN PIN!" (gold, x5), "LUCKY!" (lime clover), "+5 BONUS GEMS" (cyan), "FREE CRATE!" (pink); the lane event banner "DOUBLE COINS FOR 2 MINUTES!" (others: GIANT PINS, MOVING GOLD, LUCKY LANE).
7. FIRST-3-MINUTES CALLOUTS: "HOLD... THEN LET GO!" over the meter on the first throw, a bouncing "BUY POWER LV 2!" bubble with an arrow at the POWER LV button, "TRY YOUR NEW BALL!" arrow at an EQUIP button, a floating "GO HERE" marker over the crate kiosk.
```

### 7D. Teleport, rebirth, toasts, Rizzo

```
Design these windows.
1. TELEPORT window. About 640x460. Title "TELEPORT", one card per zone: BACK ALLEY, NEON LANES, MAIN STREET LANES, SKYLINE LANES, each in its zone's colours (alley grey and pink, neon pink and cyan, main street red and royal blue, skyline navy and gold), a small zone picture, "x4 COINS", a GO button; locked card = lock + "REACH LV 25"; current zone = "YOU ARE HERE". Close X.
2. REBIRTH window. About 560x480. Title "REBIRTH", three blocks: "YOU GO BACK TO" (Back Alley, Power Level 1, 0 coins), "YOU KEEP" (balls, pets, gems, potions), "YOU GET FOREVER" ("x2 COINS" big, "+100% XP"), then "NEXT REBIRTH NEEDS 32M COINS · LV 12". A big REBIRTH button whose second state says "TAP AGAIN TO REBIRTH", a NOT YET button, and a full-screen "REBIRTH!" celebration after.
3. SMALL TOASTS (about 340x56, top centre, 3 s): "NEXT BOSS FLIGHT IN 12:30", "FLY TO THE BOSS!", "GOING UP...", "COMING SOON", "DONE! AGAIN IN 4:59".
4. RIZZO'S SPEECH BUBBLE over the crate dealer (about 260x80, white with an ink outline and a tail): "YO! FIRST CRATE'S 93% OFF!", "NICE PULL!!".
```

### 7E. Pin Titan boss screens

```
Design the boss-fight screens for the Pin Titan event (players fly to a floating arena and bowl at a giant stone pin together).
1. The lobby pill under the level bar: "PIN TITAN IN 0:35", and its "BOARD NOW!" state.
2. The boss health bar at the top during the fight: "PIN TITAN", a big chunky bar, 6 armour-plate pips that break, a timer "1:42".
3. Warning flashes: "DODGE!" (red, when it slams), "CORE OPEN! HIT IT!" (gold).
4. The result screens: "TITAN DOWN!" with the reward ("5B COINS", and a line "TITAN JR. PET: 10% CHANCE, 25% FOR #1") and your damage rank "YOU: #2 · 340 HITS"; and "THE TITAN WON" with "NEXT TRY IN 15:00".
```

### 7F. Offer popups (step 12b-2)

```
Design two small, friendly offer popups. Never pushy: no timers, a big NO THANKS button the same size as the buy button, an X.
1. "STUCK AT THE WALL?": shown when a player stands at a locked zone's glowing wall. About 380x240: the next zone's name, the next XP BOOST step (e.g. "XP BOOST x1.25 gets you there faster") with the boost icon, a lime price button "R$ 29" and NO THANKS.
2. "NICE PULL!": shown 5 s after a Rare+ crate pull. About 380x240: a 3D SLOT with the ball, "Give it a FIRE TRAIL?", a trail preview strip, the price (gems "40" with a gem icon, or "R$ 99"), WEAR IT and NO THANKS.
```

### 7G. Cosmetic pictures for the store's LOOKS tab

```
Make 16 square store pictures (256x256 transparent PNG, chunky cartoon, the same style as my Store Kit icons) for these looks:
Trails: FIRE TRAIL, ICE TRAIL, TOXIC TRAIL, GALAXY TRAIL, VIP GOLD (each = a ball with that trail swooshing behind it).
Strike banners (each = the word in its own big cartoon lettering on a banner shape): "BOOM!", "TOO EASY", "CRUSHED!", "LEGEND".
Pin blasts (each = pins flying apart with that effect): PARTY BLAST (confetti), FROST BLAST (ice shards), TOXIC BLAST (green goo splash), GALAXY BLAST (stars and nebula).
Lane skins (each = a short lane seen from the bowler): CANDY LANE (pink candy stripes), ICE LANE (frozen lake), LAVA LANE (cracked hot rock), GOLD LANE (shiny gold).
Also give me 4 seamless 512x512 lane textures (candy, ice, lava, gold) the game can lay on the lane.
```

---

## Part 8: game icon, thumbnails, title

```
Make the store page art for my Roblox game "Strike Legends" [or the final title], a bowling simulator for kids and teens: roll for rare bowling balls, hatch pets, climb from a back alley to a rooftop over the city.
1. GAME ICON, 512x512 (Roblox crops it to a circle on some screens, so keep the important part in the middle 400x400): a glowing legendary bowling ball smashing through pins with a burst of gold coins, bold "STRIKE LEGENDS" cartoon lettering is optional (it must still read with no text). Bright, high contrast, readable at 100x100.
2. 3 THUMBNAILS, 1920x1080 each, no small text:
   a) a Roblox avatar mid-throw on the Neon Lanes, pins exploding, a huge "x16" coin burst, a MYTHIC ball glowing.
   b) the 4 zones as a climb: Back Alley at the bottom, Neon Lanes, Main Street Lanes, Skyline Lanes on top under the night sky.
   c) pets and the Pin Titan: a crowd of cute pets around a player, the giant stone Pin Titan behind them.
Roblox rules: no real brands, no Robux prices, no misleading claims, no text asking for likes.
```

Title: "Strike Legends" is still the working title. Claude can suggest names any time (keep it short, searchable, "bowling" or "strike" in it helps search).
