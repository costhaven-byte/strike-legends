# Strike Legends: sound effects list (for owner approval)

Made with ElevenLabs (`eleven_text_to_sound_v2`, sfx node). Each prompt is 450 characters or less. Takes come out about 2 seconds.

- **Slot** = the sound's name in the game (`src/shared/AssetSlots.luau`). "NEW" = the game has no slot for it yet; adding it is a small code change after the sounds are made.
- **LOOP** = plays over and over (the end must flow back into the start).
- **OFTEN** = plays many times a minute: kept short, soft and not tiring.
- **No bowling or pin words** (2026-10-29): ElevenLabs adds pin clatter whenever a prompt says bowling, pins or alley, even with "no pins". Only prompts that should have pin sounds use those words: StrikeCrash, SpareCrash, PinHit, OverchargeBlast and the three indoor zone ambiences + Skyline (faint far-off pin crashes).

## 1. Throw, pins and results

| File | Slot | Where it plays | ElevenLabs prompt |
|---|---|---|---|
| `strike_crash.mp3` | StrikeCrash | Every strike (also the extra boom on the strongest balls). **APPROVED, already made** (owner's pick 2026-10-29, made on the ElevenLabs site from the spare crash prompt; replaces the old `test/strike_C.mp3`, which is now the spare crash) | Real bowling alley, close mic. A bowling ball hits the side of the rack and knocks down four or five hard maple wooden pins: one solid wooden crack, then a short hollow woody clatter as a few pins tip, bounce and roll on the wooden pin deck. Smaller and lighter than a full strike, a few standing pins left. Wood only, not metal or glass. Indoor alley echo, quick settle. |
| `spare_crash.mp3` | NEW (SpareCrash; now uses PinHit) | A non-strike hit that knocks down several pins. **APPROVED, already made** (owner 2026-10-29: the old strike take `test/strike_C.mp3`) | Real bowling alley strike, close mic. A heavy bowling ball slams into ten hard maple wooden pins: sharp loud wooden crack, then a burst of hollow woody clatter as pins knock into each other, tumble, bounce and spin on the wooden pin deck and rattle against the side boards. Distinct pin-on-pin clacks. Wood only, not metal or glass. Indoor alley echo, last few pins rolling and settling. |
| `pin_hit.mp3` | PinHit (OFTEN) | Each single pin knocking into another pin or the floor (up to 10 per throw, pitched up and down) | Close mic, one single hard maple wooden bowling pin knocks into another wooden pin: one short, dry, hollow woody clack with a tiny bounce, then silence. Very short and clean, one hit only. Wood only, no metal, no glass, no ball rolling, no crowd. Small indoor alley room tone, tiny natural echo. |
| `gutter_drop.mp3` | NEW (Gutter; now silent) | Ball falls in the gutter (normal miss and OVERCOOKED) | Close mic. A heavy solid ball drops a few centimeters into a long, hollow, curved plastic trough: one dull soft thunk, then a smooth hollow rumbling roll along the trough that slowly fades into the distance. Only one ball rolling, nothing else is hit. Slightly sad and flat. No wood clatter, no crash, no metal, no glass, no music, no voices. Large quiet indoor room echo. |
| `ball_throw.mp3` | Throw (OFTEN) | Ball leaves the hand and lands on the lane | Close mic, a single heavy solid resin ball, about seven kilograms, is swung low by one arm and released onto a smooth polished hardwood floor: a short soft whoosh of the swing, then one deep muffled thud as the ball touches down, then quiet. One impact only, smooth, round and punchy, nothing else in the scene makes a sound. Quiet large indoor hall, soft room tone. |
| `ball_roll.mp3` | Roll (LOOP) | Ball rolling down the lane until it reaches the pins | Steady loopable sound of a heavy solid resin ball rolling fast along a long polished hardwood floor, recorded beside it. Deep smooth low rumble with a soft even whirr of the ball spinning, constant speed and volume from start to end so it loops cleanly. Only the rolling ball makes a sound. No impacts, no thuds, no clatter, no metal, no voices, no music. Large quiet indoor hall, soft room tone. |
| `charge_hold.mp3` | Charge (OFTEN) | Player starts holding to charge a throw | Short soft rising power-up whoosh for a game, like air being drawn in and energy building. Smooth airy swell that climbs gently in pitch over one second and stops cleanly. Light and pleasant, not harsh or screechy. No music, no melody, no voices, no metal clanks. Clean close mic, dry, no room echo. |
| `tap_lock.mp3` | Tap (OFTEN) | Release / lock tap; also small ticks in the hatch scene | Very short soft game interface tap: a single rounded wooden-ish knock mixed with a tiny soft pop, like tapping a smooth toy button. Gentle, warm and quick, one tap only. No ring, no metal, no glass, no music, no voices. Close mic, dry, no room echo. |
| `perfect_sting.mp3` | PerfectSting (OFTEN) | Release in the gold PERFECT zone | Bright short magical success sting for a mobile game: one sparkling bell-like shimmer with a quick upward sweep of twinkles, like a coin of light. Happy and clean, under one second, ends with a soft sparkle tail. Not a melody or song, no drums, no voices. Close mic, dry, slight airy reverb. |
| `overcharge_warn.mp3` | OverchargeWarn | Power bar enters the red cap at the top | Short tense warning for a game: a fast electric crackle and a rising buzzing hum, like energy about to overload, with two quick soft beeps on top. Urgent but not painful, under one second. No sirens, no music, no voices, no explosions. Close mic, dry, no room echo. |
| `overcharge_blast.mp3` | OverchargeBlast | The OVERCHARGE gamble pays off: huge strike | Massive powered-up bowling strike for a game: a deep booming electric blast and low thump, then a huge hollow wooden explosion of ten maple pins scattering, clattering and bouncing on a wooden pin deck. Heavier and more epic than a normal strike, with a short crackle of energy. No metal, no glass, no music, no voices. Big indoor alley echo, pins settling. |
| `overcooked.mp3` | Overcooked | The OVERCHARGE gamble fails: ball fizzles into the gutter | Short funny fail sound for a game: an electric power fizzle that sputters out, a deflating descending whine, then a soft dull plastic clunk. Comic and light, not scary, about one second. No music, no trombone, no voices, no explosions. Close mic, dry, no room echo. |
| `crowd_cheer.mp3` | Cheer (OFTEN) | After strikes; also trials and rank-ups | Small friendly indoor crowd cheering after a great winning moment in a game: a short burst of happy whoops, claps and a few excited yells, rising quickly then fading. About fifteen people, mixed ages, no clear words. Short, under two seconds. Only the crowd, no other sounds. No music, no announcer, no whistles. Recorded in a large indoor hall, natural room echo. |
| `firework.mp3` | Firework | Strike streak celebrations, crate and hatch reveals | Single small celebration firework for a game: a quick whistling launch, a bright pop, then a crackling sparkle shower that fades. Cheerful, not loud like a war explosion, under two seconds. No music, no voices, no crowd. Outdoor open air, slight distant echo. |
| `streak_up.mp3` | StreakUp (OFTEN) | Strike streak goes up (pitched higher each tier); also reel steps | Short rising combo sound for a mobile game: three quick bright ascending plucked chimes in one upward sweep with a soft sparkle on top, like a combo meter filling. Upbeat and clean, under one second. Not a song, no drums, no voices. Close mic, dry, slight airy reverb. |
| `streak_lost.mp3` | StreakLost | Strike streak broken; trial failed | Short soft disappointed sound for a game: two gentle descending muted chimes and a light deflating whoosh, like a combo meter draining. Sad but friendly, not harsh, under one second. No buzzer, no trombone, no music, no voices. Close mic, dry, no room echo. |

## 2. Coins, gems and progress

| File | Slot | Where it plays | ElevenLabs prompt |
|---|---|---|---|
| `coin.mp3` | Coin (OFTEN) | Coins land in the counter after a throw; lucky/gem traits; crate reel coins | Single small gold game coin collect sound: one bright short metallic ting with a tiny sparkle, like a coin dropping into a pile in a cartoon game. Very short and clean, under half a second, pleasant to hear many times. No music, no voices, no clinking pile. Close mic, dry, no room echo. |
| `gem.mp3` | NEW (Gem; now uses Coin) | Earning gems (level-ups, gem drops, daily) | Single crystal gem pickup sound for a game: a clear glassy high chime with a quick shimmering sparkle, like a small diamond being collected. Brighter and more precious than a coin, under one second. No music, no voices, no smashing. Close mic, dry, slight airy reverb. |
| `level_up.mp3` | RankUp | Level up popup, new rank, REBIRTH | Big triumphant level up sound for a mobile game: a bold rising brass-like swell into a bright magical chime burst with sparkles, like a hero powering up. Exciting and proud, about two seconds. No melody or song, no drums loop, no voices. Close mic, clean, roomy reverb tail. |
| `power_up.mp3` | PowerUp | Buy a Power Level, drink a potion, buy Polish | Short punchy power-up for a game: a quick rising energy zap and a warm thump, then a bright sparkle, like a ball getting stronger. Satisfying and snappy, about one second. No music, no voices, no explosions, no metal clanks. Close mic, dry, slight airy reverb. |
| `reveal.mp3` | Reveal | Normal reward card appears (daily, gifts, milestones, store buy, teleport) | Short pleasant reward reveal for a game: a soft whoosh in and a gentle magical chime with light sparkles, like a prize card flipping open. Friendly and clean, about one second. Not a song, no drums, no voices. Close mic, dry, slight airy reverb. |
| `reveal_big.mp3` | RevealBig | Big reward: Epic+ ball or pet, zone unlocked, spin jackpot | Big exciting reward reveal for a game: a rising shimmering swell, then a bright magical burst of bells and sparkles with a deep warm boom underneath, like a treasure chest bursting with light. Epic and joyful, about two seconds. Not a song, no voices, no crowd. Close mic, clean, big airy reverb tail. |
| `error.mp3` | Error (slot is missing in the game, so it is silent today) | Can't afford / locked / not ready | Short soft "no" sound for a game interface: two quick low muted wooden bonks going down in pitch, gentle and friendly, not a harsh buzzer. Under half a second. No music, no voices, no metal, no beeps. Close mic, dry, no room echo. |

## 3. Crates

| File | Slot | Where it plays | ElevenLabs prompt |
|---|---|---|---|
| `reel_tick.mp3` | ReelTick (OFTEN) | Crate reel passing each ball; spin wheel ticks; pet panel counters | Single short click of a prize wheel peg hitting a flexible plastic flapper: one crisp light tick, very short, clean attack, no tail. Like a game show wheel ticking once. No music, no voices, no metal ring. Close mic, dry, no room echo. |
| `reel_heartbeat.mp3` | ReelHeartbeat | Crate reel's slow last stretch before it stops | Tense suspense heartbeat for a game: two deep low muffled thumps, a heartbeat "lub-dub", with a faint low hum under it. Dramatic and soft, about one second. No music, no voices, no clicks. Close mic, dry, no room echo. |
| `crate_open.mp3` | NEW (CrateOpen; now uses StrikeCrash) | Crate lid bursts open at the reveal | Treasure crate bursting open in a game: a heavy wooden lid pops up with a wooden crack and creak, then a bright whoosh of light and a shower of magical sparkles. Exciting and punchy, under two seconds. Wood and magic only, no metal chains, no music, no voices. Close mic, small room echo. |
| `crate_land.mp3` | NEW (CrateLand; now uses PinHit) | Crate drops onto the table before opening | A heavy wooden crate drops onto a wooden table: one solid deep wooden thud with a short rattle of the lid, then still. Short and weighty, under one second. Wood only, no metal, no glass, no music, no voices. Close mic, small indoor room. |

## 4. Eggs, pets and fusion

| File | Slot | Where it plays | ElevenLabs prompt |
|---|---|---|---|
| `hatch_charge.mp3` | HatchCharge | Hatch stand lights up while the egg wobbles | Magical charging sound for a game egg hatch: soft sparkling chimes and a gently rising shimmering hum, building anticipation, with tiny twinkles. Warm and mysterious, about two seconds, ends at its peak. Not a melody, no drums, no voices, no cracks. Close mic, clean, airy reverb. |
| `hatch_crack.mp3` | HatchCrack | Each crack in the egg shell (3 times, pitched up) | A single crunchy egg shell crack for a game: one sharp short crack of a big hard eggshell splitting, crisp and satisfying, with a tiny crumbly tail. One crack only, under half a second. No liquid, no metal, no glass, no music, no voices. Close mic, dry, no room echo. |
| `hatch_burst.mp3` | HatchBurst (now uses StrikeCrash) | Egg shell bursts and the pet pops out | Big magical egg burst for a game: the eggshell shatters into pieces with a crunchy pop, then a bright whoosh of light and a cheerful sparkle shower. Joyful and punchy, under two seconds. Shell and magic only, no glass, no metal, no music, no voices. Close mic, airy reverb. |
| `hatch_fanfare.mp3` | HatchFanfare | Legendary or Mythic pet hatched | Short winning fanfare sting for a game: a bright triumphant brass-like rise into a shining chord burst with bells and sparkles, like hitting a jackpot. Epic and happy, about two seconds. No singing, no voices, no crowd, no drums loop. Close mic, clean, big reverb tail. |
| `pet_merge.mp3` | NEW (PetMerge; now uses RevealBig) | MERGE 3 > SHINY and the fusion machine's FUSE | Magical fusion for a game: three soft sparkly whooshes swirl together faster and faster, then join in one bright shimmering chime burst with a warm hum, like creatures merging into a shiny one. About two seconds. Not a song, no voices, no metal clanks, no explosions. Close mic, clean, airy reverb. |
| `pet_equip.mp3` | NEW (PetEquip; now uses Click) | Equip a pet / EQUIP BEST | Short cute game sound of a small pet joining you: a soft bouncy boing-pop with a tiny happy sparkle chime. Playful and light, under half a second. No animal noises, no voices, no music. Close mic, dry, no room echo. |

## 5. Travel, rebirth and daily

| File | Slot | Where it plays | ElevenLabs prompt |
|---|---|---|---|
| `elevator_ding.mp3` | ElevatorDing | Elevator doors open (zone 3 to roof and back) | Classic elevator arrival bell, close mic inside the elevator car: one clear soft "ding" of a small brass bell, then a short smooth slide of sliding doors opening. Clean and pleasant, under two seconds. No music, no voices, no motor grind. Small enclosed space. |
| `teleport.mp3` | NEW (Teleport; now uses Reveal) | TELEPORT to another zone | Game teleport whoosh: a quick rising magical swirl of air and shimmer that pulls in, then a soft bright pop as you vanish. Smooth and clean, about one second. No music, no voices, no explosions, no sci-fi lasers. Close mic, dry, slight airy reverb. |
| `spin_win.mp3` | NEW (SpinWin; now uses Reveal) | Daily spin wheel stops on a prize | Short game prize win: the wheel clicks to a stop with one last tick, then a cheerful bright chime and a little coin sparkle burst. Happy and quick, about one second. Not a song, no voices, no crowd. Close mic, dry, slight airy reverb. |

## 6. Pin Titan boss (zone 4)

| File | Slot | Where it plays | ElevenLabs prompt |
|---|---|---|---|
| `boss_siren.mp3` | BossSiren | 30 s before boarding the helicopter opens | Short game alarm warning a boss is coming: a deep pulsing two-tone horn wail rising once, with a low rumble under it, like a giant monster alert on a city rooftop. Dramatic, not painfully loud, about two seconds. No voices, no music, no gunshots. Outdoor rooftop, wide wind echo. |
| `boss_hit.mp3` | BossHit (OFTEN in the fight) | A ball hits the Titan | A heavy solid ball smashes into a giant stone statue: a deep solid rocky thump with a crunchy stone crack and a few small pebbles falling. Punchy and short, under one second. Stone only, no metal, no glass, no music, no voices. Outdoor rooftop, open air echo. |
| `boss_plate.mp3` | BossPlate | An armor plate breaks off the Titan | Giant stone armor plate breaking off a monster: a loud cracking split of thick stone, a grinding scrape, then a heavy crash as the slab hits the ground and rubble scatters. Epic and weighty, about two seconds. Stone only, no metal, no glass, no music, no voices. Outdoor rooftop, open air echo. |
| `boss_roar.mp3` | BossRoar | Fight starts, core opens, Titan falls | Giant stone golem monster roar: a deep rumbling growl that rises into a huge booming bellow, with grinding stone and rocks shaking loose. Scary but fun for a kids game, about two seconds. No human voice or words, no music, no metal. Outdoor rooftop, big open air echo. |
| `helicopter.mp3` | Helicopter (LOOP) | Helicopter takeoff and landing on the roof | Steady loopable helicopter hovering close by: fast rhythmic thumping rotor blades chopping the air and a smooth turbine whine, constant speed and volume from start to end so it loops cleanly. No radio chatter, no voices, no music, no gunfire. Outdoor rooftop, open air, light wind. |

## 7. Buttons

| File | Slot | Where it plays | ElevenLabs prompt |
|---|---|---|---|
| `click.mp3` | Click (OFTEN) | Every UI button | Very short soft game button click: one rounded plastic toy-button press with a tiny pop, crisp and clean, about a tenth of a second. Pleasant to hear hundreds of times. No ring, no metal, no glass, no music, no voices. Close mic, dry, no room echo. |

## 8. Zone ambience (NEW, all LOOP, play quietly in the background)

| File | Slot | Where it plays | ElevenLabs prompt |
|---|---|---|---|
| `amb_back_alley.mp3` | NEW (AmbBackAlley) | Zone 1, Back Alley | Steady loopable background ambience of a small old bowling alley in a city back alley at night: soft hum of old lights, distant bowling balls rolling and faint pin clatter far away, light murmur of a few people, a far-off car passing. Calm, even volume start to end so it loops. No music, no clear words, no loud hits. Wide indoor room tone. |
| `amb_neon_alley.mp3` | NEW (AmbNeonAlley) | Zone 2, Neon Alley | Steady loopable ambience of a busy neon-lit bowling hall: electric buzz of neon signs, distant balls rolling and soft pin crashes far away, a lively murmur of a crowd, faint arcade machine bleeps. Upbeat but calm, even volume start to end so it loops. No music, no clear words, no loud hits. Big indoor room tone. |
| `amb_main_street.mp3` | NEW (AmbMainStreet) | Zone 3, Main Street Lanes | Steady loopable ambience of a big modern bowling center: warm crowd murmur, many lanes with distant balls rolling and soft pin crashes far away, ball return machines whirring, light footsteps. Busy and cheerful, even volume start to end so it loops. No music, no clear words, no loud hits. Large indoor hall echo. |
| `amb_skyline.mp3` | NEW (AmbSkyline) | Zone 4, Skyline Lanes rooftop | Steady loopable ambience of a bowling lane on a skyscraper rooftop: soft steady high-altitude wind, faint city traffic hum far below, a distant soft pin crash now and then. Airy and wide, even volume start to end so it loops. No music, no voices, no sirens, no helicopter. Outdoor open air. |

## Notes

- Not given their own sound (they reuse ones above, which works fine): golden pin, lane modifiers, trait effects, milestones, playtime gifts, store buys, potions, zone unlock, rank trials.
- Loops (roll, helicopter, 4 ambiences) work better a bit longer than 2 s; I can ask ElevenLabs for longer takes (may cost more credits per take) and mark them "loop" in the generator.
- After the owner approves: generate 2 takes each into `sounds/`, the owner picks, then Bulk Import in Studio and I put the IDs in `AssetSlots`.
