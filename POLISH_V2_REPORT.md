# Polish v2 report (run started 2026-11-03)

Restore point for the whole run: git tag `restore-polish-v2-before` (+ owner's File > Save to Roblox As copy).
Each stage has its own tag `restore-pl-<stage>-before`.

Budget note: the run started with the weekly usage at 87%, so the stages are done in the plan's "must finish
first" order where they're small and sure, and a handoff note (POLISH_V2_HANDOFF.md) is kept up to date after
every stage for the next account.

## L0 zone 4 models
Already done before this run (ffe84c0).

## U1 HUD: no SHOP button, passes only in the STORE (tag restore-pl-U1-before)
- SHOP (balls + bags) button hidden on computer and phone (`Config.Ui.ShopButton = false`; true brings it back).
- The left button grid closes up: PETS, STORE / DAILY, PROFILE / PASSES, TELEPORT (TELEPORT last, because it stays
  hidden until zone 2). GIFTS + SETTINGS slide into the top-right corner.
- NEXT GOAL card is now a button: tap it = go to the BALLS & BAGS stall (same teleport as GO TO SHOP).
- SHOP window has 3 tabs: BALLS / BAGS / REBIRTH (`Config.CoreLoop.Shop.Tabs`, "Gamepasses" removed).
- PASSES button opens the STORE scrolled to GAME PASSES (`StoreController.OpenOn`).
- The world beams (shop/sell pointers) still guide new players to the stalls.
- Decision (owner can reverse): "remove shop" read as the SHOP button, not STORE. PASSES button kept, moved into the grid.
- Placeholders: STORE still in the older Store Kit look (U2 restyles it).
