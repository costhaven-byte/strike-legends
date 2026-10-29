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
