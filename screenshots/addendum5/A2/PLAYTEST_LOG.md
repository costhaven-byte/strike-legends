# A2 playtest log (2026-11-01, Studio Play, numbers only)

Studio's 3D view was still frozen (viewport 1x1, RenderStepped 0/s, Heartbeat 60/s, tweens stuck, screen_capture
times out), so no screenshots. Everything below was read from the Client / Server data models.

## EconomySim.CoreLadder() (two ladders, player buys the cheaper next step)
```
  0.2 min  ball 2 Rubber Bouncer (50)       |  1.0 min  bag 2 (240)
  2.2 min  ball 3 Confetti Popper (500)     |  3.2 min  bag 3 (600)
  4.4 min  ball 4 Sunspike (950)            |  5.2 min  bag 4 (990)
  6.4 min  ball 5 Gust (1.9K)               |  8.4 min  bag 5 (5.2K)
 11.4 min  ball 6 Cloud Roll (10K)          | 13.4 min  bag 6 (11K)
 16.4 min  ball 7 Rainbow Arc (21K)         | 18.4 min  bag 7 (24K)
 21.4 min  ball 8 Sunbolt (45K)             | 23.4 min  bag 8 (54K)
 26.4 min  ball 9 Tornado (99K)             | 28.4 min  bag 9 (120K)
 31.5 min  ball 10 Sonic Boom (220K)        | 34.5 min  bag 10 (420K)
```
Gaps between balls: 0.2, 2.0, 2.2, 2.0, 5.0, 5.1, 5.0, 5.0, 5.1 min.

## Play checks
- CoreBuy from the lane: "Buy it at the shop" (0 coins and with 10K coins). Bag never changes.
- CoreGoTo "Shop": lands at (-17, 852.6, -3415) on the blue circle; the shop window opens in buy mode
  ("You're at the shop. Tap a price to buy", GO TO SHOP hidden). Coins pill "10K".
- At the shop: Bag, Bag, Ball, Ball, Ball, Bag all bought in that order (independent); bad kind "Thing" refused;
  EquippedBall follows (Sunburst at ball 4). Rows: older = Owned, current = Using/Yours (sky blue), next = price,
  the rest = veiled prices.
- Walking off the circle closes it (backdrop off; the close tween can't finish while Studio is frozen).
- BALLS price list (Studio TestOpen hook): "Price list. You can only buy at the shop", GO TO SHOP shown, next ball
  = gold price tag. GO TO SHOP teleports and the open list turns into buy mode (next = grey when you can't afford).
- Fresh player: 4 throws fill bag 1 (60), CoreBuy from lane refused, SELL teleport -> pad (-37, 852.6, -3415),
  bag 60 -> 0, coins 60; GO TO SHOP + buy ball 2 at 8.4 s. A spammed second SELL within 1.5 s is ignored.
- Buy distance: 7 studs from the circle centre OK, 9 and 14 refused (Radius 4.5 + BuySlack 4).
- BuyPowerLevel refused in the core loop ("Buy at the shop").
- Output: no errors (only the old "CrateShop.Counter not found" / "EggPad ... not found" notes for hidden stations).
- Not verifiable while frozen: the guide card text/colours and button bounce (they run on RenderStepped).
