# Addendum 5 overnight report (2026-11-01/02, owner asleep)

One section per step (plan: ADDENDUM_5_PLAN.md). Each: what changed, restore tag, commit, 2-minute test, choices made for you.
At the end: one combined morning playtest.

## Step 0: audit (2026-11-01)
- No game changes. Wrote `AUDIT_ADDENDUM_5.md`: the ball and bag ladders, how buying, selling, pins, pets, levels and rebirth work today, the save fields (v34), and a plan for the one shared lane.
- Main findings: the BALLS button opens the shop with BUY buttons, and buying works from anywhere because the server never checks where you stand. The SELL button only shows a beam; it doesn't teleport you yet. Pins are capped at 40 and a full clear pays x2. Pets only boost coins, every egg is locked behind zones on the roof, and Shiny merge only works at the zone 3 machine, so you can't reach pets or merge from the roof. Rebirth is switched off while the core loop is on. Throw poses follow rank level, so if levels go away everyone would be stuck on the first pose.
- Shared lane plan: one 98-stud-wide lane in the same spot as the 6 old lanes, with 12 throw spots 8 studs apart. It gets built from code when the server starts and the old lanes are moved to ServerStorage. Each player only sees their own 40-pin rack, other players' balls are drawn light, and new collision groups stop pins hitting players.
- Nothing to test. Restore tag: none (nothing changed).

## Step 1 (A1): pins are a number, no levels (2026-11-01)
**What changed**
- Each throw now counts the real number of pins, with no 40 cap. Only the 40 rack pins are drawn: a strong ball knocks all 40 on screen while the counter says e.g. "3.2K". The counter and the coin pops use the big-number format (K, M, B...). The old "12/40" is gone.
- No more full clear and no more x2 for it.
- The +-20% luck roll stays. When it rolls in the best quarter (+10% to +20%), a tilted gold LUCKY! tag pops on the pin counter, the counter number turns gold, and the coin pop gets a gold LUCKY! label. Lucky throws with a strong ball also shake the camera and play the big crash.
- Steeper pins per ball: 6, 10, 18, 35, 70, 140, 300, 650, 1.4K, 3.2K (was 6, 9, 12 ... 43). Bag sizes and prices were scaled with it, so every step still takes the same time (EconomySim: ball 10 at 47 min, last bag at 51 min, same as before). Step A2 will split balls and bags into two ladders.
- No levels: throws give no XP, the XP bar is hidden, no "LV 12 PRO" over heads, no level-reward preview, rebirth asks for no level (coins only), eggs ignore any level, the profile drops LEVEL and the level/full-clear rows, the store hides XP BOOST (card and HUD pill) and calls the 2X pass "2X COINS". Gifts that gave an XP potion give the coin potion of the same size. All the old code is still there: `Config.CoreLoop.NoLevels = false` brings levels back.
- The throw animation now follows your ball (ball 1 = scuffed, ball 8 = clean, ball 10 = the biggest pro throw), not your level.
- Leaderboard numbers are clamped so huge pin counts can't break the save.

**Restore tag:** `restore-a5-A1-before`. **Commit:** 5ced992.

**2-minute test**
1. Play. Hold THROW on your lane. Expected: the counter shows "5" or "6" (no "/40"); about 1 throw in 4 shows a gold LUCKY! tag on the counter for under a second.
2. TEST panel > COINS x10 a few times, then buy balls at the shop up to ball 5 (Gust). Expected: all 40 pins fall every throw, the counter shows about 56 to 84, the pop over the pins shows the coins.
3. Look at the top of the screen: no XP / level bar. Look at your avatar: no "LV 1 ROOKIE" tag.
4. Open STORE: BOOSTS has only COIN BOOST; the pass says 2X COINS.
- Silent failures to watch for: the counter stuck on "0"; LUCKY! never showing; the throw pose not getting cleaner after new balls; something still saying "LEVEL" or "XP".

**Choices made for you**
- LUCKY = the best 25% of rolls (`Config.CoreLoop.LuckyFrom = 0.25`).
- Pins curve about x2 per ball, and bag sizes/prices scaled to keep the old pacing (A2 re-paces).
- Pose per ball: `Config.CoreLoop.Poses = {1,2,3,4,5,6,7,9,10,12}`.
- XP potions in gifts swapped for coin potions; XP BOOST hidden from the store (the Roblox product still exists, just not shown).
- The full-clear cheer/confetti/gold flash is gone (it would fire every throw now); camera shake + crash only on LUCKY throws with 24+ drawn pins.
- Left as is: the Studio-only TEST panel still has +1 LEVEL / PASS TRIAL buttons; pet "strike" hops no longer happen (no strikes); the PIN CRUSHER achievement goals (1K..500K pins) will now be reached quickly (step E can retune).

**Playtest note:** Studio's 3D view was frozen on an old frame all session (screenshots timed out; restoring the window didn't help, and I didn't restart Studio in case the place has unsaved work). Checked by numbers instead: `screenshots/addendum5/A1/PLAYTEST_LOG.md` (ball 10 = 2.7K-3.8K pins per throw, 40 drawn, counter "3.2K", pose 12, XP stays 0, no errors). Later steps may also be unable to take screenshots until Studio is restarted.

**Placeholders:** none new.

## Step 2 (A2): two ladders, buy only at the shop, SELL teleports (2026-11-01)
**What changed**
- Balls and bags are now two separate ladders. You can buy the next ball or the next bag in any order; neither waits for the other. A small bag still holds your income back (a throw that doesn't fit only pays what fits), so bags still matter.
- New prices (EconomySim, a player who buys whichever is cheaper): ball 2 in the first ~15 s, balls 3, 4, 5 about 2 min apart, balls 6 to 10 about 5 min apart (ball 10 at ~31 min, last bag at ~35 min). Balls: 50, 500, 950, 1.9K, 10K, 21K, 45K, 99K, 220K. Bags: 240, 600, 990, 5.2K, 11K, 24K, 54K, 120K, 420K. Pins and bag sizes didn't change.
- Buying only works at the shop booth. The server checks you stand on (or right next to) the blue circle; from anywhere else it answers "Buy it at the shop". Power Levels can't be bought in this game any more either.
- The BALLS button now opens a price list: every ball and bag, what you have, what's next and its price, but no buying. Its blue GO TO SHOP button teleports you onto the shop circle, and the list turns into the real shop.
- SELL teleports you onto the green sell pad, and the bag sells there (nowhere else). The guide card now says "Tap Sell", then "Buy the Rubber Bouncer at the shop".
- New shop window: a gold tilted SHOP tab, red X, a coin pill that counts up, two lists (Balls with 3D balls, Bags) with rarity-coloured stripes (grey, green, blue, purple, gold, and a turning rainbow for Sonic Boom). Your current one says USING (blue), older ones OWNED, the next one has its price (green when you can buy it, grey while saving), later ones are faded. Buttons squash when pressed and bounce back; a buy throws confetti and pops the next row.
- Goal bar: "Next: <whichever is cheaper>", and "buy it at the shop" when you can afford it.

**Restore tag:** `restore-a5-A2-before`. **Commit:** 3bb2a95.

**2-minute test**
1. Play. Hold THROW until the bag is full. Tap SELL. Expected: you jump onto the green pad, the bag empties, coins go up.
2. Tap BALLS. Expected: the price list with all 10 balls and 10 bags, the next ones with a gold price, a blue GO TO SHOP button, no way to buy.
3. Tap GO TO SHOP. Expected: you land on the blue circle and the window says "You're at the shop"; Rubber Bouncer has a green 50 button. Buy it.
4. TEST panel > COINS. At the shop buy two bags in a row, then a ball. Expected: all three work (no "get the ball first").
5. Walk a few steps off the circle. Expected: the shop closes.
- Silent failures to watch for: SELL doing nothing (no jump), the shop opening but every button grey even with coins, the price list letting you buy, the window staying tiny or stuck half open, the guide card stuck on "Sell" after selling.

**Choices made for you**
- Ball pacing taken literally: balls 3-5 ~2 min each, balls 6-10 ~5 min each (the ladder has only 10 balls, so nothing comes "after" yet). Ball 2 stays the first-30-seconds buy (50 coins).
- Bag pacing: each bag lands about 40% of the way between two balls (bag 2 ~1 min, then 2 min, then 5 min apart).
- `Config.CoreLoop.Ladders.Independent = true` (false = the old alternating order back). Buy range = circle radius 4.5 + `Shop.BuySlack` 4 studs.
- GO TO SHOP teleports (like SELL), so the price list gets you to the shop in one tap. Teleports have a 1.5 s cooldown (`Config.CoreLoop.Teleport`).
- You land on the sell pad facing the lanes and on the shop circle facing the counter. You walk back to your lane yourself.
- "Using" badge is sky blue so it can't be mistaken for a green BUY button.
- Ball rows show each ball's rarity colour from a new `Rarity` field on `Config.CoreLoop.Balls`; bags use the colour of the ball at the same step.
- Left as is: gem buys in the STORE (cosmetics) and Robux items still work from the store window (they are not coin buys of the ladder). Eggs/pet slots/rebirth get the same shop check in their own steps.
- A Studio-only `TestOpen` attribute on CoreShopUI opens the price list (for tests; does nothing in the live game).

**Playtest note:** Studio's 3D view was still frozen (viewport 1x1, no RenderStepped, screen_capture timed out), so no screenshots again. All checks were done with numbers: `screenshots/addendum5/A2/PLAYTEST_LOG.md`. Not checked live: the guide card colours and the button bounce (they only run when Studio draws frames). Restarting Studio should fix the frozen view.

**Placeholders:** none new (bag icon = the existing store bag image).
