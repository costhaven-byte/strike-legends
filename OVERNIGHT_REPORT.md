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
