# Addendum 6 report

## Stage 1: Fixes (2026-11-01, code tag `restore-a6-s1-before`)

### 1.1 Multipliers
**What was wrong:** Coins went into the bag *after* the boosts were added, and the bag has a size limit. A potion, a game pass, the Robux COIN BOOST, friends and a pet's coin bonus only made the bag fill faster. Once you have a few balls the bag fills in about one throw, so the sale was the same size with or without them. Rebirth was the only boost that really paid, because it was added at the sell.

**What changed:**
- The bag now holds **pins**. Selling pays pins × the coin multiplier, so every coin boost shows on every sale.
- There is one coin multiplier and one pin multiplier, with one formula in the config: (1 + pets + rebirth + friends) × potion × game passes × COIN BOOST. Pins use the same formula: (1 + pets + rebirth) × pin potion × pin passes (neither of those exists yet, so both stay at ×1 for now).
- The gold **×N badge** next to your coins is back. Tapping it opens the COIN MULTIPLIER card with every source, plus the pins-a-swing multiplier.
- Every sale pop shows the multiplier it used ("×23.5 BOOST"), including ×1.
- Potions already had a countdown at the bottom left. It still shows on the roof.
- The PROFILE → BOOSTS page shows the same sources.
- There's a new **BOOSTS** button in the Studio TEST panel (EVENTS section). It prints the whole breakdown in Output.
- The bag shop now says "Holds 60 pins" instead of coins.

**Tested in Studio, one source at a time (a bag of 100 pins each time):**

| Test | Sold for |
|---|---|
| No boosts | 100 |
| Coin potion only | 200 |
| COIN BOOST step 1 only | 200 |
| 2X COINS pass only | 200 |
| Pet only (Splitz +35%) | 135 |
| 1 rebirth only | 200 |
| All together | 2,350 (= ×23.5) |

**Worth knowing:**
- A player with no boosts earns exactly what they did before, so Zone 1 pacing is unchanged.
- Players with boosts now earn more, because their boosts finally pay.
- A rebirth and a pet's pin bonus now **add** together instead of multiplying, which is slightly less for players who have both. Stage 7 tunes rebirth.
- The economy simulator still uses the old bag maths. Stage 9 updates it.
- Bags in old saves keep their number, which now counts as pins. At most that's one bag's worth.

### 1.2 Lane too bright
- The mega lane changed from pale cream wood to **deep matte teal** (non-shiny wood). The pin deck is a slightly lighter teal.
- Bright cream edge lines now run down both outer sides. The gold lines between spots, the gold arrows and the gutters stay bright.
- The rooftop lighting already has weak bloom (0.08, only very bright things glow) and only slightly raised exposure (+0.1), so I didn't touch the lighting and the world stays bright.
- On contrast: white and pale pink effects on the old cream wood had a contrast ratio of about 1.5:1, so they were washed out. On the new teal it's about 8:1.

**Not verified by eye:** Studio's 3D view came back blank white in every capture, in Play and in Edit (the same problem as the Addendum 5 night). The request to look at the Studio window directly was declined, so I couldn't take the screenshot of the strongest effect on the lane. Please check it in your playtest.

## Stage 2: Shop (2026-11-01, code tag `restore-a6-s2-before`)

### 2.1 Tabs
- The shop window now has three tabs: **Balls**, **Bags** and **Rebirth**. The order lives in the config, and a Gamepasses tab (Stage 8) is one more entry in that list.
- The PET SLOTS row (from Addendum 5) is now at the bottom of the Bags tab.
- You can still only buy while standing at the shop. Away from it the window is a price list with a GO TO SHOP button. The HUD BALLS button opens the Balls tab and the HUD REBIRTH button opens the Rebirth tab.

### 2.2 Buy any ball or bag
- You can buy any ball or bag above your best one, as long as you can pay for it and its zone is open. You don't have to buy the ones in between.
- Pins per throw always come from your best ball, and bag room from your best bag.
- Balls and bags you jumped over are marked **SKIPPED**. You can still buy them at their normal price, but only for the look. Every ball you own has an **EQUIP** button for its look (its trail and its effect come with it). Pins don't change.
- **BUY BEST** (bottom right) buys the most expensive one you can pay for on that tab. It shows what it would add and the price. When you can't afford anything it turns grey and shows the next price.
- The next one up is highlighted with a coral outline, a NEXT tag, and its silhouette slowly turns.
- After a rebirth, everything you bought goes back to the start (ball 1, bag 1, no extra looks).

### 2.3 Silhouettes
- Every ball and bag you don't own is a solid black shape named **???**. It shows only what it would add ("+70 pins a throw") and the price. Its rarity colour stays hidden too.
- The list shows the whole ladder. Rows from zones you haven't opened will show greyed out with a lock and the zone number. Right now only Zone 1 exists, so you won't see any locked rows until Stage 3 adds zones.
- Buying one plays a 1.6 second reveal: a white flash, the colour pops in, the name appears, and a burst in the ball's effect colour.
- Names are also hidden in other places: the "you can afford" note now says "A NEW BALL AT THE SHOP", the next-goal bar says "Next ball (+4 pins a throw)", the first-30-seconds guide says "Buy a new ball", and the display cases on the plaza stay "???" until you own that ball.

### 2.4 Rebirth ranks
- Ranks use the old Pro Tier names from the first design: Rookie (no rebirth yet), Amateur, Regular, Club, Semi-Pro, Pro, Elite, Master, Legend, Hall of Famer. I added Superstar, Icon, Champion, World Champion, Immortal, Titan and Bowling God. After that come Bowling God II, III and so on. Each rank has its own colour.
- The ranks replace the old BRONZE/SILVER/GOLD tiers. Your pin rings and throw spot now use your rank's colour.
- The Rebirth tab shows your rank, the next rank, the price with a coins bar, what goes back to the start (coins, balls, bags, zones, pins) and what you keep (pets, gamepasses, rank), plus the boost: "+100% coins, +100% pins a throw". Those numbers stay until Stage 7 tunes them.
- To rebirth you **hold** the button for 1.5 seconds. It fills up while you hold, and letting go early cancels.
- Your rank now shows over your head (for example "★ AMATEUR"; before your first rebirth it says "ROOKIE"). On the leaderboard walls it shows after each player's name in its colour.

### 2.5 Small additions
- The next-goal bar already existed. It now shows what the next ball or bag adds, its price and your progress ("Next ball (+4 pins a throw) 0 / 150").
- Number style: every number already went through one formatter (K, M, B, T, Qa ...). Two places showed long numbers instead: the profile stats (up to a million) and the display case pin counts. They now use the same short style.

### What was tested (Studio Play test)
- Buying ball 5 straight from ball 1 worked, and balls 2 to 4 showed SKIPPED.
- Buying skipped ball 3 equipped its look and left pins on ball 5.
- Buying ball 3 again was refused ("You own it"). Equipping a ball you don't own was refused, and buying away from the shop was refused.
- Buy Best on bags jumped to bag 6, the most I could pay for. Bag room went to 3,700.
- Clicking a price in the window bought the ball and played the reveal.
- A rebirth reset coins, balls, bags and looks, gave rank Amateur, put "★ AMATEUR" in orange over the head and showed it on the leaderboard.
- Screenshots of the Balls and Rebirth tabs looked right. No errors in Output.

**Not verified:** I can't press and hold from here, so the hold-to-rebirth button was checked by reading the code. The rebirth itself was tested straight through the server. The full-screen REBIRTH! moment after a hold wasn't seen. Please hold the button in your playtest.

**Save change:** save version 37 adds which balls and bags you own, and the ball look you've equipped. Old saves count every ball and bag up to their best as owned, so nobody loses anything.
