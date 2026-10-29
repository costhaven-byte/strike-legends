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
