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
