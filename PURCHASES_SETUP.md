# How to set up the in-game purchases (2026-10-29)

The store is already built. It just needs real Roblox IDs, then you flip one switch.
Right now every ID in `Config.Monetization` is 0 ("not made yet") and `Enabled = false`, so nobody can buy anything.

You make 2 kinds of things on the Roblox website:
- **Game passes** = bought once, kept forever (7 of them).
- **Developer products** = can be bought again (15 of them).

Time needed: about 30-40 minutes. You do steps 1-4, Claude does step 5, you do 6-8.

---

## Step 0: restore point
In Studio: **File > Save to Roblox As...** a copy named `restore-before-purchases`. (Same as always.)

## Step 1: open the game's Monetization page
1. Go to **create.roblox.com** > **Creations** (top left) > click the Strike Legends game (place 94254609600041).
2. In the left menu open **Monetization**. You will see **Passes** and **Developer Products**.

## Step 2: make the 7 game passes
For each row: **Passes > Create a Pass** > upload the picture > type the name and text > **Create Pass**.
Then click the new pass > **Sales** (or "Pricing") > turn **Item for Sale** on > type the price > **Save**.
Then copy the pass **ID** (the number in the page address, or "Copy Asset ID" on the ... menu) into the last column.

| # | Name | Price (R$) | Picture (in `assets/store_icons/`) | Description to paste | Pass ID |
|---|------|-----------:|---------|------|------|
| 1 | 2X COINS + 2X XP | 399 | pass-2x.png | Every throw pays double coins AND double XP. Stacks with potions. | |
| 2 | VIP | 799 | pass-vip.png | +25% coins and XP, 25 free gems every day, a gold ball trail and a [VIP] chat tag. | |
| 3 | AUTO BOWL | 499 | pass-auto.png | The game bowls for you and every throw is a STRIKE. | |
| 4 | LUCKY | 199 | pass-lucky.png | x2 luck: Rare and better balls and pets come more often. | |
| 5 | SUPER LUCKY | 399 | pass-superlucky.png | x4 luck. Stacks with LUCKY for x8. | |
| 6 | TRIPLE HATCH | 399 | pass-triple.png | Open 3 eggs or crates at once. | |
| 7 | +2 PET SLOTS | 399 | pass-pets.png | Two more pets follow you. | |

## Step 3: make the 15 developer products
**Developer Products > Create a Developer Product** > picture, name, description, price > **Create**.
Copy each product **ID** into the last column.

| # | Name | Price (R$) | Picture | Description | Product ID |
|---|------|-----------:|---------|------|------|
| 1 | STARTER PACK | 199 | ball-dumpster.png | Dumpster Diamond (Rare ball), 30 min of 2X COINS and 100 gems. Once only. | |
| 2 | COIN BOOST x2 | 10 | boost-coin.png | Coins x2 forever. | |
| 3 | COIN BOOST x3 | 20 | boost-coin.png | Coins x3 forever. | |
| 4 | COIN BOOST x4 | 50 | boost-coin.png | Coins x4 forever. | |
| 5 | XP BOOST x2 | 15 | boost-xp.png | XP x2 forever. | |
| 6 | XP BOOST x3 | 30 | boost-xp.png | XP x3 forever. | |
| 7 | XP BOOST x4 | 75 | boost-xp.png | XP x4 forever. | |
| 8 | 2X COINS - 15 MIN | 49 | boost-15min.png | Double coins for 15 minutes of play. | |
| 9 | 60 GEMS | 99 | gems-60.png | A handful of gems. | |
| 10 | 300 GEMS | 399 | gems-300.png | A bag of gems. | |
| 11 | 1,500 GEMS | 1599 | gems-1500.png | A chest of gems. | |
| 12 | GALAXY TRAIL | 149 | ../look_icons/GalaxyTrail.png | Twinkling stars and nebula clouds behind your ball. | |
| 13 | LEGEND BANNER | 149 | ../look_icons/LegendBanner.png | Black and gold LEGEND flag on every strike. | |
| 14 | GALAXY BLAST | 149 | ../look_icons/GalaxyBlast.png | A burst of stars when your ball hits the pins. | |
| 15 | GOLD LANE | 149 | ../look_icons/GoldLane.png | Your lane turns pure shiny gold. | |

**The price on Roblox must be the same as the price column.** The game shows the price from its own Config; if they
differ, players see one price in the store and another in Roblox's buy window. Want a different price? Tell Claude and
it changes both lists.

## Step 4: send Claude the IDs
Paste the two filled tables (or just "pass 1 = 123456789, ...") into a new chat.

## Step 5 (Claude): put the IDs in
Claude puts every ID into `Config.Monetization` (PassId / ProductId) and pushes it into Studio. `Enabled` stays false.

## Step 6: test in Studio (2 minutes)
1. Ask Claude to set `Enabled = true` for the test (don't publish yet), then press **Play**.
2. Open the STORE, press BUY on 2X COINS. Roblox's real buy window opens and says **"This is a test purchase"**
   - Studio purchases are free and fake, your Robux is never taken.
3. Buy it: coins per throw should double. Buy COIN BOOST x2: the store should now offer x3.
- Expected: Roblox's window, the right name and price, the item works straight away.
- Common silent failures: BUY does nothing + Output says "has no PassId yet" = an ID is missing or 0; the window
  shows a different price = the Roblox price doesn't match the table; "item not for sale" = Item for Sale is off.

## Step 7: go live
1. Tell Claude "turn the store on": `Enabled = true` (and Claude pushes it).
2. **File > Publish to Roblox** (the real place). The store now works for everyone.

## Step 8: check on the live game (with a second account or a friend)
Join the live game, open the STORE, and look (don't buy) that each price matches. Real purchases cost real Robux,
even for you as the owner (you get 70% back as earnings), so if you want one real test buy the cheapest item
(COIN BOOST x2, 10 R$).

---

## Good to know
- **Your earnings:** Roblox keeps 30%; you get 70% of each sale as Robux, held for a few days before it's spendable.
  To turn Robux into real money later you need DevEx (13+, ID check, 30,000+ earned Robux).
- **Rules:** crates and eggs cost coins, not Robux, so the game is not a "paid random item" game. Robux only buys sure
  things. LUCKY passes change odds, and the ODDS screens already show the boosted chances. Keep it this way.
- **Gifting / trading** stays off (project rule).
- **Prices can be changed any time** on the website, but tell Claude so Config matches.
- **Robux on the Roblox store page:** Roblox also lists your passes on the game page under "Store". Nothing to do.
