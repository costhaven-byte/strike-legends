# Overnight run report (2026-10-29, owner asleep)

One section per step. Each step: what changed, restore point, the 2-minute test, and any choice Claude made for you.
At the end: one combined 2-minute playtest.

## B4 rewards (commit below, restore tag `restore-batchB4-before`)
- PROFILE claim rewards (achievements) now pay 5, 10, 15, 20 gems by tier (was 1, 3, 6, 12).
- GIFTS: the first gift is ready the moment you join, then one every 15 minutes (12 gifts, last at 2:45).
  One set a day: your gift timer and claimed gifts are saved, so leaving and rejoining the same day carries on;
  a new day (midnight UTC, same as the daily reward) gives a fresh set. Save v29.
- Gifts grow with progress: join gift + 2:15 gift are coins (based on your zone, Power Level and income),
  potions come 2 at a time from zone 3 on, the egg is your zone's egg, crates are your zone's low/mid/best crate.
- Test (Studio, TEST panel FROM ZERO): open GIFTS -> first tile says JOIN GIFT and is ready -> CLAIM gives 500 coins.
  TEST: +15 MIN -> 2nd gift ready. TEST panel JUMP TO ZONE 4 -> tiles change to Skyline Egg / Sky crates / 2x potions.
  Silent failure to watch: the GIFTS button not showing a "1" badge right after joining.
- Choices made for you: dropped the old 2:15 XP potion to keep 12 tiles; join gift = coins (500 for a new player);
  zone 1's best gift stays a Gold Crate like the old 3-hour gift.

## C1 pet slots + first egg prompt (commit 006e1e1, restore tag `restore-batchC1-before`)
- Pet slots (item 7): everyone starts with 3, gets a 4th at 5 rebirths, and the +2 PET SLOTS pass adds 2 on top.
  The old +1 at levels 15 and 30 (and at 1 rebirth) is gone. Old saves keep every slot they already had
  (save v30 PetSlotsKept, worked out from the old rules once), so no equipped pet comes off. The pets panel's
  locked slots now say "5 REBIRTHS" and "ROBUX PASS" (pass slots only show while the store is on).
- First egg prompt (item 6): the first time you have 50K coins while standing inside Neon Lanes (zone 2 open), a big
  popup says BUY YOUR FIRST PET EGG! / FOLLOW THE GOLD BEAM TO THE EGG STAND, and a gold beam + GO HERE! marker lead
  to the Neon Egg stand (same look as Rizzo's first-crate guide; the EGGS sign steps aside meanwhile). It waits for the
  ZONE UNLOCKED window to close. Shown once ever (save v30 EggPrompted); never for players who already hatched an
  egg. The beam goes away once you hatch, drop under 50K or leave the zone. Numbers in Config.EggPrompt.
- Test (Studio, TEST panel FROM ZERO, ~2 min): JUMP TO ZONE 2, close ZONE UNLOCKED, COINS x10 twice (100K) while in
  the lobby -> popup + gold beam to the egg stand + GO HERE! over the egg. Hatch the egg -> beam and marker go.
  Open PETS -> 3 open slots, then locked "5 REBIRTHS", "ROBUX PASS", "ROBUX PASS".
  Silent failures: no beam (popup only) = stand not found (Output warns "[EggPromptController]"); the YOU CAN NOW
  AFFORD NEON EGG note showing at the same time (it should not).
- Tested by Claude in Studio: popup, beam, marker, wait-for-ZONE-UNLOCKED, slot texts, and the old-save upgrade
  (level 16 -> keeps 4 slots, level 31 + 1 rebirth -> keeps 6). No errors in Output.
- Choices made for you: "in zone 2" = standing inside the Neon Lanes building (not just having it open); the popup
  is once ever, the beam is this session only; an old save keeps its slot count but gets no extra slot at 5 rebirths
  if it already has 4 or more (slots never stack past what a new player can get, max 6 + pass).
- Studio: no world edits. One new script (Client.Controllers.EggPromptController) was put into Studio by hand and is
  in git; Studio's copy stays unsaved until you save the place (Rojo/git hold it anyway).

## C2 fusion only at the machine + pet bonuses as multipliers (commit 68c8833, restore tag `restore-batchC2-before`)
- No MERGE in the pets panel (item 15): the "MERGE 3 > SHINY" button on pet cards is gone. Shinies are made only at
  zone 3's PET FUSION machine. The server now refuses any merge unless zone 3 is open AND you stand within 20 studs of
  the machine (Config.Fusion.Range; the prompt itself opens at 12). Message if refused: "Fuse pets at the PET FUSION
  machine". No save change; Shiny pets you already have stay.
- Pet bonuses as multipliers (item 20): every pet bonus now reads x(1 + bonus), same number style as the multiplier
  card: Common Neon pet x1.02 (was +2%), Kingpin x3.4 (was +240%), Shiny Kingpin x5.8. Shown on pet cards, the
  hatch card (counts up from x1), the Shiny reveal ("x5.8 COINS · WAS x3.4"), the fusion window (new line under the
  Shiny's name), the spin wheel's SECRET PET card and the multiplier card's PETS row.
  TOTAL PET BONUS = x(1 + all equipped bonuses added up), e.g. two x1.5 pets = x2 (not x2.25). That is exactly how
  coins are paid today; the coin maths did not change.
- Test (Studio, ~2 min): TEST panel JUMP TO ZONE 3 + FREE EGG a few times, open PETS -> cards say "x1.xx COINS",
  no MERGE button, TOTAL PET BONUS says "x... COINS". Walk to the PET FUSION machine, press E -> the window shows
  the Shiny with its "x... COINS" line under the name; with 3 of one pet FUSE! works as before.
  Silent failures: a card still showing "+N%" (missed text); FUSE! saying "Fuse pets at the PET FUSION machine"
  while you stand at it (range too small: raise Config.Fusion.Range).
- Tested by Claude in Studio: merge refused far away, refused at the machine with zone 3 closed, works at the machine
  with zone 3 open (3 Pinny -> Shiny Pinny, auto-equipped); panel cards + total read x1.02 / x1.04, 0 MERGE buttons;
  no new errors in Output. NOT checked on screen: the fusion window's new bonus line and the multiplier card's PETS
  row (the fusion prompt can't be pressed from a test script); both are one-line text changes.
- Choices made for you: the total shows as one multiplier x(1 + sum), matching how coins are paid; the fusion
  window's subtitle now says "A BIGGER COIN BOOST AND A GOLD CROWN" (the old "x2 BONUS" would read wrong next to
  multipliers, since a Shiny doubles the bonus part: x1.5 -> x2); the egg odds board over each stand shows chances
  only (it never showed bonuses), so nothing changed there.
- Noticed, not fixed: Output warns "'MascotMerged' is not in Config.Analytics.Events" on every fusion (older than
  this step, harmless).
- Studio: no world edits. Code pushed into Studio's scripts (unsaved in the place until you save; git has it).

## C3 X out pets on the egg odds board = auto-delete (commit 4bf55a2, restore tag `restore-batchC3-before`)
- Item 11b: walk up to any egg stand; the floating odds board now has a line under the pets, TAP A PET TO AUTO-DELETE IT.
  Tap a pet's bubble -> a big red X over it. Tap again -> X gone. One list for all eggs, saved (save v31 AutoDelete;
  old saves start with an empty list, nothing deleted). The server keeps the list (new remote SetAutoDelete, checks
  the pet is real and allowed, rate limited).
- Hatching an X'd pet: it is NOT added to your pets, but the hatch card still shows it, with a red AUTO-DELETED stamp
  (and "NOT KEPT" next to the odds). Triple hatch: the small side cards say AUTO-DELETED in red. It still counts as an
  egg hatched (achievements, profile). AUTO hatch keeps going as normal. All numbers/texts in Config.AutoDelete.
- Test (Studio, TEST panel FROM ZERO, ~2 min): JUMP TO ZONE 2, COINS x10 a few times, walk to the Neon Egg stand.
  Tap Pinny and LanePup on the board -> red X on both. Tap LanePup again -> its X goes. Hatch until you get a Pinny
  (the first Pinny is kept, NEW!), then hatch more: the next Pinny shows AUTO-DELETED and PETS still says Pinny x1.
  Silent failures: tapping does nothing (board not taking taps; nothing in Output); an X that comes back after you
  untapped it (server refused; check Output); PETS count going up for an X'd pet you already had.
- Tested by Claude in Studio (server side, 17 hatches incl. 3 triple hatches): X'd pets deleted only once you own one,
  untapped pet kept, eggs-hatched counted every one; the server refused Mythic, Shiny, fake ids and bad values; the
  stamp text fits (shrinks to 16 px). NOT seen on screen: Studio was not drawing frames (RenderStepped stopped), so
  the board taps and the hatch animation with the stamp were not watched live. Please look at those two in your test.
- Choices made for you: (1) Mythic pets can't be X'd at all (tap = "MYTHIC PETS CAN'T BE AUTO-DELETED"), so a chase
  pet is never thrown away; Config.AutoDelete.MaxRarity = "Legendary" changes that. (2) The FIRST copy of a pet is
  always kept even if X'd (KeepFirst = true), so nobody loses a pet they never had; after that X'd copies go.
  (3) Shiny pets can't be X'd (they only come from fusion). (4) A deleted Legendary still shows the server-wide pull
  banner (it was a real pull). (5) Deleted pets give nothing back (no coins), like other simulators.
- Studio: no world edits. Code pushed into Studio's scripts (unsaved in the place until you save; git has it).

## D1 rebirth = full reset + throw follows your rank level (commit 579b13b, restore tag `restore-batchD1-before`)
- Item 18 (rebirth resets levels): a REBIRTH now also puts you back to rank level 1, 0 XP and Rookie, as well as
  Power Level 1 and 0 coins. Balls, pets, gems, potions and zones stay. Old saves keep their level until they rebirth.
  Nothing pays twice: new save fields (v32) BestLevel + BestRank remember your best ever. Level-up gems, the free crate
  every few levels and the level 7/9 rewards only pay for levels above your best; rank-up gems only for a new best rank.
  You still get the level-up popup (without gems) when you climb back. A rank you already won comes back by itself
  (no second rank trial). You can't rebirth in the middle of a rank trial ("Finish your rank trial first").
  REBIRTH window: YOU GO BACK TO = LEVEL 1, POWER LV 1, 0 COINS; LEVEL is gone from YOU KEEP.
  Profile: the CLIMBER achievement and the stats line now use your best level ever (stat renamed BEST LEVEL);
  the subtitle under your name still shows your current level.
- Item 17b (throw follows your level): the throw animation and the ball's rolling speed now come from your CURRENT
  rank level, not Power Level (Config.Throw.RankStyle). Level 1 = the clumsy wobbly throw at today's speed; every
  Rookie level (2-6) a little cleaner and +2% faster; Amateur (level 7) a bigger jump (+15%); level 13 fully clean
  (+22%); levels 19 / 31 / 43 bigger pro throws (up to +36% speed). The server decides it and tells everyone's screen.
  A rebirth takes you back to the clumsy throw (wanted, per your decision).
  Power Level still sets the ball's size, trail, sparks, fire, crash and how many pins a normal throw can knock.
- Economy sim (levels now reset, nothing retuned; that's D3). Total play time, new vs old rule:
  rebirth 1 11:37 (same) | rebirth 2 23:04 (was 21:03) | rebirth 3 / zone 3 48:04 (was 44:10) | rebirth 4 1h25m
  (was 1h17m) | rebirth 5 / zone 4 2h41m (was 2h36m). Zone 2/3/4 coins per minute go down (91K / 2.6M / 945M, was
  126K / 4.7M / 1.3B) because the rank tier's coin bonus resets too. D3 targets (4 min / 25 min / 1.5 h) still need the
  economy pass. The sim doesn't count the faster ball at higher levels (a few % more throws per minute).
- Test (Studio, TEST panel FROM ZERO, ~2 min): throw a few times: the throw looks clumsy. +1 LEVEL x3 -> the throw is
  cleaner and the ball rolls a bit faster. READY TO REBIRTH, open REBIRTH: "YOU GO BACK TO" shows LEVEL 1 / POWER LV 1 /
  0 COINS, "YOU KEEP" has no LEVEL. Press REBIRTH twice -> the level bar says LV 1 ROOKIE, the throw is clumsy again.
  Silent failures: gems going up when you re-reach a level you had (should not; only new levels pay); the REBIRTH
  window's three chips overlapping or cut off on a phone; other players' throws looking the same at every level.
- Tested by Claude in Studio (FROM ZERO): levels 2-4 gave 6 gems; rebirth -> level 1 / XP 0 / Rookie, best level kept;
  climbing back to 4 gave 0 gems, level 5 (new) gave 2; passed the Amateur trial (+5 gems), rebirth, climbed back to
  7 -> Amateur came back with no trial and no gems, level 7 reward not paid again; a real throw sent Pose 7 at level 7
  and Pose 1 after the rebirth, roll time 0.54 s vs 0.62 s (x1.15); old v31 save (level 20, tier 4) -> best 20 / tier 4;
  rebirth window chips fit (443 of 478 px). No errors in Output. NOT watched on screen: the animation itself
  (the same pose levels Power Level used before, now picked by rank).
- Choices made for you: (1) only the animation + ball speed moved to rank; ball size/trail/fire stay on Power Level
  (your Addendum 3 rule, and the Power Level shop sells those looks). (2) Ball speed never goes below today's speed
  (level 1 = today), so nothing feels slower and the economy isn't hurt. (3) Level rewards and rank gems pay once ever.
  (4) Ranks you already won come back without redoing the trial (redoing trials every rebirth would drag the middle).
  (5) The Pin Titan boss's damage bonus stays on Power Level (it's hitting power, not the throw animation).
  (6) The rebirth level needs (level 4, +2 per rebirth) are unchanged; D3 retunes them.
- Studio: no world edits. Code pushed into Studio's scripts (unsaved in the place until you save; git has it).

## D2 Power Levels: much cheaper + the game shows what they pay (commit 83b8d53, restore tag `restore-batchD2-before`)
- Power Level prices cut a lot, so they are the cheap, frequent step between rebirths (a rebirth puts you back to
  Power Level 1). Their coin multiplier (x1.25 ... x12) is unchanged. Old -> new price:
  LV2 400 -> 100 | LV3 3,000 -> 500 | LV4 27K -> 2K | LV5 840K -> 7.5K | LV6 4.2M -> 30K | LV7 100M -> 150K |
  LV8 1.5B -> 1M | LV9 8.2B -> 10M | LV10 41B -> 200M | LV11 210B -> 8B | LV12 1.2T -> 250B.
- The game now says what a Power Level pays: a small gold pill under the POWER LV button "x1.5 > x2 COINS"
  (at MAX: "x12 COINS", white ring); the POWER LEVEL 5! moment has a green line "COINS x2 > x2.5"; the
  "YOU CAN NOW AFFORD" note says "POWER LV 5 = x2.5 COINS". (There is no separate Power Level shop; the button is it.)
- Economy sim (now / before): each rebirth run now gets a new Power Level every ~20 s to 3 min at its start, before
  it was 1-2 per run. First run: LV2 0:03, LV3 0:06, LV4 0:37, LV5 1:09, LV6 3:16 (before: LV4 at 3:12, then nothing).
  Zone 2 run: LV6 0:46, LV7 3:36. Zone 3 runs: LV8-LV10 between 0:06 and 3:10. Zone 4: LV11 ~9 min into the first
  zone 4 run, LV12 ~85 min into the next (long goals on purpose). Because levels are cheaper, coins come faster:
  zone 2 at 9:40 (was 11:37), zone 3 at 29:43 (was 48:04), zone 4 at 1h09m (was 2h41m). D3 (next) retunes rebirths
  to its targets (4 min / 25 min / 1.5 h); zone 4 is now a bit EARLY vs 1.5 h, so D3 will slow the later rebirths.
- Rewards that use "a share of your next Power Level's price" checked: daily rewards and playtime gifts stay sensible
  (they also pay minutes of your own income, which now sets most of them; e.g. zone 2 day 1 = 2.5M, zone 3 day 1 =
  90M); not changed. Level 7 / level 9 rewards would have dropped ~10x, so their shares went 0.1 / 0.15 -> 0.3 / 0.5
  (minimum 50K / 150K unchanged). Pin Titan boss rewards: about the same as before (not changed).
- Test (Studio, TEST panel FROM ZERO, ~2 min): look at the POWER LV button: a gold pill under it says
  "x1 > x1.25 COINS". Throw once or twice -> BUY POWER LV 2! callout -> buy: the POWER LEVEL 2! moment shows
  "COINS x1 > x1.25" in green, the pill now says "x1.25 > x1.5 COINS". Keep throwing: LV 3 and LV 4 come within about a
  minute; a note "YOU CAN NOW AFFORD POWER LV 4 = x2 COINS" shows. Then COINS x10 a few times and keep buying to
  LV 12: the button turns gold MAX POWER! and the pill says "x12 COINS".
  Silent failures: the pill hiding behind DAILY or cut off on a phone (it should sit on the button's bottom edge);
  the BUY POWER LV 2! callout not appearing at 100 coins; the afford notes coming too often for your taste
  (one per Power Level; say so and I'll turn the Power Level ones off).
- Tested by Claude in Studio: pill text at every level 1-12 and at MAX ("x12 COINS", white ring), pill 98x18 px
  between the button and DAILY, buying works (multiplier list shows PowerLevel=1.25 ... 12), level-up and afford
  texts built for every level, daily/playtime coin amounts at 5 progress points. No errors in Output. NOT seen on
  screen: Studio wasn't drawing frames, so the level-up moment, the BUY LV 2 callout and the afford note were not
  watched live (the join intro also waits on frames). Please look at those in your test.
- Choices made for you: (1) multiplier values kept; only prices moved. (2) Levels 11-12 stay expensive so zone 4
  still has Power Level goals. (3) Arrow written as ">" ("x1.5 > x2"), like "MERGE 3 > SHINY", since the game fonts
  may not have an arrow sign. (4) Level 7/9 reward shares raised (above). (5) Daily/playtime shares unchanged.
- Studio: no world edits. Code pushed into Studio's scripts (unsaved in the place until you save; git has it).

## D3 economy pass: faster start, no dead stretches (commit 8f53616, restore tag `restore-batchD3-before`)
- Your targets: rebirth 1 at about 4 min, zone 3 at about 25 min, zone 4 at about 1.5 h. Each rebirth now asks for its
  own level AND its own coins. The level comes near the end of a run and the coins soon after, so most of a run is
  spent buying things, not saving up.
  Rebirth 1: level 3 + 15K (was level 4 + 50K) | 2: level 8 + 500K (was 6 + 700K) | 3 (opens zone 3): level 13 + 4M
  (was 8 + 9M) | 4: level 21 + 200M (was 10 + 150M) | 5 (opens zone 4): level 24 + 1.5B (was 12 + 4B) | after that
  +2 levels and x3 coins each time (rebirth 6 = level 26 + 4.5B).
- Zone 3's shop used to be bought out early, then about 20 minutes with nothing to buy before rebirth 5. It now lasts
  through both zone 3 runs: League crate 8M -> 30M, Champion crate 40M -> 250M, Main Street Egg 6.3M -> 20M, and
  Power Level 11 8B -> 1B (now the last buy before zone 4; Power Level 12 is still the long zone 4 goal).
- Simulator (40 pretend players, total play time; "wait" = median longest time between two buys in that run):

  | | before D3 | after D3 | target |
  |---|---|---|---|
  | rebirth 1 = zone 2 | 9:40 | 4:27 | ~4 min |
  | rebirth 2 | 18:40 | 12:13 | |
  | rebirth 3 = zone 3 | 29:43 | 26:13 | ~25 min |
  | rebirth 4 | 45:24 | 47:03 | |
  | rebirth 5 = zone 4 | 1h09m | 1h35m | ~1.5 h |
  | longest wait, runs 0 / 1 / 2 / 3 / 4 | 5:00 / 1:39 / 5:03 / 1:39 / 25:15 | 2:09 / 1:15 / 3:33 / 3:27 / 10:09 | 1-2 min |

  First things in order: Power Level 2 at 0:03, first crate 0:24, LV4 0:45, LV5 1:09, LV6 3:09, rebirth 1 4:27,
  first pet egg 6:42, Bronze crate 6:30, LV7 7:34, Silver crate 14:01, LV8 13:33, Gold crate 23:28, zone 3 26:13,
  Main Street Egg 29:42, League crate 35:51, LV10 46:36, Champion crate 51:27, LV11 1h23m, zone 4 + boss 1h35m.
  The waits that are still longer than 2 minutes are the last bit of saving before the zone 3 and zone 4 rebirths
  (the goal bar shows REBIRTH: OPENS ... with a progress bar then). Fever (D4) and lane events (D5) come next and
  are NOT in the simulator: they will add coins, so I aimed a little slow (1h35 rather than 1h30).
- New simulator report: `require(game.ServerStorage.Tools.EconomySim).Gaps()` lists each run's longest wait.
  The short Sheet() now counts total play time (it said "never" for Power Level 7+ after rebirths).
- Checked: the rebirth teaser (2:30 in) still comes before the rebirth is ready (4:27), now saying "REACH LEVEL 3";
  "YOU CAN NOW AFFORD" notes and the goal bar read the new rule by themselves. Robux boosts are multipliers (no
  price link). Daily rewards, playtime gifts, away coins and boss rewards pay the biggest of a minimum, minutes of your
  own income, or a share of your next Power Level; only Power Level 11 got cheaper, so at most the share part is lower
  for players saving for level 11, and income minutes cover it. Not changed.
- Test (Studio, TEST panel FROM ZERO, ~2 min): throw until you reach level 3 (about 4 minutes; or +1 LEVEL x2):
  the REBIRTH window says NEEDS LV 3 · 15K COINS, and the goal bar says REBIRTH (OPENS NEON LANES). Rebirth.
  Then READY TO REBIRTH twice more: the window asks for LV 8 + 500K, then LV 13 + 4M (that one opens Main Street).
  Look at the zone 3 kiosk: League 30M, Champion 250M; Main Street Egg 20M.
  Silent failures: rebirth window still saying LV 4 / 50K (old Config in Studio); the rebirth teaser popping up after
  the rebirth is already ready.
- Tested by Claude in Studio (Play, FROM ZERO): READY TO REBIRTH + REBIRTH six times: asked for level 3/8/13/21/24/26
  and 15K/500K/4M/200M/1.5B/4.5B, rebirth 3 opened zone 3, rebirth 5 zone 4. No errors in Output. NOT watched on
  screen (Studio isn't drawing frames for me): the window text and goal bar; please look.
- Choices made for you: (1) each rebirth gets its own level, not "+2 each" (+2 each was the reason the first rebirth
  needed 10 minutes). (2) Rebirth 1 costs 15K, a bit less than Power Level 6 (30K), so a player can rebirth before
  buying LV6; harmless (LV6 comes again in seconds in zone 2). (3) Zone 3 crate/egg prices and Power Level 11 moved
  (above). Cheaper zone 3 egg/crates made zone 4 come at 1h16 with a 20-minute dead stretch; dearer eggs slowed
  everything (pets are the biggest coin boost), so only the crates went up a lot. (4) Zone 4 itself (rebirths 6+,
  Sky crates, Power Level 12) not tuned: it's past your targets; its later waits are long (10-25 min) and could
  be a later pass. (5) Rebirth teaser time (150 s) kept. (6) No save changes.
- Studio: no world edits. Code pushed into Studio's scripts (Config, Rebirth module, EconomySim; unsaved in the place
  until you save; git has it).

## D4 FEVER MODE (commit c37a344, restore tag `restore-batchD4-before`)
- **What it is:** 5 strikes in a row by hand = FEVER MODE for 15 seconds. During fever:
  - every throw pays **x3 coins**, on top of everything else;
  - **throws come faster**: the lane is ready about 1.6 s after you let go, instead of about 2.2 s. The server
    still checks it, allowing one throw every 1.4 s during fever (2 s otherwise);
  - the zone music plays **15% faster**.
- **What you see:** a "FEVER!" banner in the kit look (orange ribbon, flame icon, "x3 COINS · FASTER THROWS"), with a
  small camera kick and a cheer. A draining orange **FEVER x3** bar sits over the power meter, showing the seconds
  left; it blinks in the last 3 seconds. A soft orange glow on the screen edges breathes slowly. Soft flame wisps rise
  off your lane's light strips and trail behind your ball, and other players see them on your lane too. The
  multiplier card and list show a **FEVER x3** row while it runs. All the numbers are in `Config.Fever`
  (`Enabled = false` turns it off).
- **Settings:** EFFECTS off = no edge glow and no flames (the banner and bar stay). OTHER PLAYERS' EFFECTS off = no
  flames on other people's lanes. SCREEN SHAKE off = no camera kick.
- **Simulator:** at the simulator's normal skill (15% PERFECT throws), 5 strikes in a row almost never happens:
  about one fever in 10 hours. Rebirth 1 stays 4:27, zone 3 26:13, zone 4 1h35, so nothing needed tuning down.
  Better players get more: at 35% PERFECT, about 42 fevers in 10 hours and zone 4 at 57:32 (57:34 without fever).
  At 50% PERFECT, zone 4 comes at 39 min (45 without fever). The report now prints "fevers per player".
- **Test (Studio, ~2 min):** press Play, walk onto your lane, open the purple TEST tab and press **FEVER NOW**
  (under EVENTS). Expected: the FEVER! banner, the orange bar over the power meter counting down from 15, a soft
  orange glow on the screen edges, flames on your lane strips, slightly faster music. Throw a few times: the lane
  is ready again noticeably sooner, and the coin pop is about 3x bigger. Tap the coin multiplier badge: a FEVER x3
  row. After 15 s everything goes back to normal. For the real trigger, get 5 PERFECTs in a row.
  Silent failures: the bar never appears (it hides when you're off your lane); the glow too bright for you
  (`Config.Fever.EdgeGlow`, higher = fainter); the music staying fast after fever ends; HOLD! refusing a quick
  throw during fever (rate limit).
- **Tested by Claude in Studio (Play, FROM ZERO):** FEVER NOW gave 15 s of fever and FEVER x3 in the multiplier
  list. 4 throws during fever paid 360 per PERFECT strike (120 before), with the lane ready again 1.55-1.61 s after
  release. After fever: 2.26 s and no fever pay. Lane flames came and went with fever. The banner fired with its
  text. Server rules checked: 4 in a row = nothing; 5 = 15 s; a strike 3 s later = +1 s; more strikes stay capped
  at 15 s. No errors in Output. **NOT seen on screen:** Studio drew no frames for me (0 render frames), so the bar,
  edge glow, banner animation and the music speed-up didn't run where I could see them. Please look at those.
- **Choices made for you:**
  1. Strikes during fever add 1 second each (never above 15). Misses don't end fever early.
  2. Fever comes back at 10, 15, 20... in a row if the last one ran out.
  3. **AUTO BOWL can't start fever** (auto throws never touch the streak), and auto throws during fever get
     neither the x3 nor the speed. Otherwise the pass would be an endless fever.
  4. The throw that makes 5 in a row isn't paid x3; fever starts when its ball hits.
  5. The strike slow motion stays during fever, so strikes still feel big.
  6. Fever's x3 is left out of coins-per-minute and away coins, so a 15 s burst doesn't inflate them.
  7. The 5-in-a-row trigger (your number) is kept. Most players may rarely see fever, because only PERFECTs strike
     and the gold shrinks with the streak. If you want it more often, change `Config.Fever.StreakNeeded`. At the
     simulator's normal skill, 4 in a row = about 5 fevers in 10 hours (zone 4 1h32) and 3 in a row = about 35
     (zone 4 1h24, still inside your 1h20 limit).
- **Studio:** no world edits. The code is pushed into Studio's scripts (two new ones, FeverService and
  FeverController, checked: no duplicates). It is unsaved in the place until you save; git has it.

## D5 LANE EVENTS (commit 26fa5c8, restore tag `restore-batchD5-before`)
- **What it is:** after about 2 minutes of bowling by hand (give or take 20 s; standing around doesn't count), the next
  rack on your lane is a one-throw event, picked at random:
  - **GOLDEN RACK** (40%): all 10 pins are gold. A strike on it pays **x5 coins**.
  - **7-10 SPLIT** (30%): only the two back corner pins stand. Knock both down = **12 PERFECT strikes' worth of coins
    + 2-4 gems** (by zone). A PERFECT always clears it; any other throw has a 12% chance (50% to get one pin).
    The split throw never breaks or adds to your strike streak, and doesn't count for fever or the 3-strike challenge.
  - **GEM PIN** (30%): one pin is a glowing cyan crystal with a gem over it. Knock it down = **+3-5 gems** (by zone).
- **What you see:** a slam banner when the event lands on your lane (GOLDEN RACK / 7-10 SPLIT / GEM PIN, with what to
  do), the rack changes, and after the throw a popup: GOLDEN RACK! x5 COINS, SPLIT CLEARED! +coins +gems, GEM PIN!
  +gems, or "... MISSED · ANOTHER ONE COMES SOON". All numbers are in `Config.LaneEvents` (`Enabled = false` = off).
- **No events:** in the first minutes (onboarding), during FEVER, a rank trial, the boss fight or AUTO BOWL. A waiting
  event comes on the first rack after. Auto throws never win one. No Golden Pin on an event rack.
- **Test (Studio, ~2 min):** Play, walk onto your lane, open the purple TEST tab, EVENTS: press **GOLDEN RACK** ->
  banner + all pins gold -> throw a PERFECT -> about 5x the usual coin pop + GOLDEN RACK! popup. Then **7-10 SPLIT** ->
  only 2 pins -> throw (a PERFECT clears it: SPLIT CLEARED! and a big coin number). Then **GEM PIN** -> one cyan pin
  -> hit it -> +gems popup.
  Silent failures: rack not changing (pins still normal) = the rack didn't refresh; banner missing; the gold rack's
  10 glows too bright for you (`Config.LaneEvents.GoldenRack.PinLight`).
- **Tested by Claude in Studio (Play, FROM ZERO):** GOLDEN RACK strike paid 600 coins (normal ~120), rack back to
  normal after; SPLIT racks had only Pin7 + Pin10; one split cleared by a non-PERFECT (the 12% chance) paid 1,440
  coins (= 12 x 120) + 2 gems with the streak unchanged, two others knocked one pin (6 coins); GEM PIN hit = +3 gems,
  misses = 0; the gem pin had its crystal look. No errors in Output. NOT watched live: the banners and popups (please
  look) and the natural 2-minute timer (only the TEST buttons were used).
- **Economy:** not added to the simulator. Rough sum: events add about 7% coins at the sim's 15% PERFECT rate (most
  from cleared splits), so zone 4 would move from about 1h35 to about 1h29 (target 1.5 h).
- **Choices made for you:** weights 40/30/30; split prize 12 strikes; gems 2-4 / 3-5 by zone; one throw per event;
  golden rack x5 replaces fever's x3 (never x15); gem pin never the head or middle pin (those fall every throw).

## D6 FREE SLOW AUTO BOWL (commit de59de0, restore tag `restore-batchD6-before`)
- After your **first rebirth** the AUTO button appears under the coin multiplier for free (gold "FREE!" tag for a
  minute when a rebirth unlocks it). Free auto throws every **7 s** and never strikes (auto throws are never PERFECT,
  and only PERFECTs strike), so pins are capped by your Power Level. The AUTO BOWL pass stays the strong one: every
  4.5 s and a strike every throw. `Config.AutoBowl.FreeAfterRebirths` / `FreeInterval`.
- **Test (~1 min):** TEST panel FROM ZERO -> no AUTO button. READY TO REBIRTH -> REBIRTH -> AUTO button with FREE!
  under the multiplier badge. Walk onto a lane, tap AUTO -> AUTO ON, a throw every ~7 s, never a strike.
  Silent failure: the button hiding behind something on a phone.
- **Tested by Claude in Studio:** before rebirth the button was hidden and the server refused to switch it on; after
  rebirth 1 it showed with FREE!; auto threw every 7.1-7.2 s: 4, 5, 6, 6 pins, no strikes. No errors.
- **Choices made for you:** 7 s (the pass is 4.5 s, by hand ~3 s); no extra coin cut (no strikes is weak enough).

## E GREEN ROBUX ICON (commit 0e917cf, restore tag `restore-batchE-before`)
- Every Robux price (store cards, HUD quick-buy pills, Starter Pack card + popup, offer windows, Robux LOOKS) now shows
  Roblox's own Robux sign, in green with a dark outline, instead of the gold R$ picture. It's the Robux glyph built
  into every Roblox font (as you said), so it always matches Roblox's. Gem prices keep the gem icon.
  Screenshot: screenshots/batchE_robux_icon.jpg.
- **Test (30 s):** open STORE -> every Robux price has the green Robux sign; the x2 COINS / x2 XP pills top-left too.
- **Tested by Claude in Studio:** 34 Robux signs built with the store open (22 shown; the hidden ones are under gem
  prices or owned items), no gold R$ picture left, seen on screen (Starter Pack 199).
- **Choice made for you:** green 0,176,111 with an ink outline so it reads on the lime buy buttons.

## Combined 2-minute playtest (everything from tonight)
Studio, TEST tab -> START FROM ZERO -> Stop -> Play.
1. GIFTS has a "1" -> claim the JOIN GIFT (B4).
2. Throw a few times: the Power LV pill says "x1 > x1.25 COINS"; buy LV 2 (D2).
3. TEST: EVENTS -> GOLDEN RACK, throw; 7-10 SPLIT, throw; GEM PIN, throw (D5). FEVER NOW -> orange bar + flames (D4).
4. READY TO REBIRTH -> REBIRTH: window says LV 3 + 15K and LEVEL 1 in "go back to" (D1/D3); after it, AUTO + FREE!
   under the multiplier (D6).
5. JUMP TO ZONE 2 -> COINS x10 twice -> egg popup + gold beam (C1). Hatch: on the egg board tap a pet = red X (C3).
6. JUMP TO ZONE 3 -> PETS: cards say "x1.xx COINS", no MERGE (C2); fusion at the machine.
7. STORE -> green Robux signs (E).
Studio note: every script was pushed into Studio's scripts and the place is NOT saved (Save to Roblox when happy).
No world edits tonight in D5-E.
