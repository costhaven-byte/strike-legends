# Bug hunt report (Polish v2 T1 + T2, 2026-11-03)

Played from zero in Studio (fresh save) through the real remotes and real clicks: throw > bag > sell, shop at the
stall, eggs, gates 1 > 2 > 3, rebirth at the zone 3 shop, daily, gifts, potions, settings, fusion, every HUD window.
Studio note: the place owner owns every game pass in Studio (x2.5 coins, luck x8), so Studio pacing runs fast;
Monetization is ON (commit 7ba3d33 "Store on for launch").

## Checked and fine
- Sell math: 53 pins x PinValue 1 x 2.5 = 133 coins (+30 tutorial reward) exactly; pins/throw 5.9 avg for ball 1 (6 +-20%).
- Shop: BUY BEST ball 2 (50) + tutorial +120, bag 2 (240); owned / locked zone ("Open zone 2 first") / no coins refused.
- Eggs: free tutorial egg hatched; triple hatch charged 3 x 750; hatch rate limit 1 s; PetsFound fills; equip best.
- Gates: must stand at the gate; zone 2 = 22K (intended, Stage 9), zone 3 = 320M; travel lands in the new zone.
- Rebirth at the zone 3 shop: coins 0, ball/bag 1, zones closed, back to zone 1, x3 rebirth bonus, pets kept.
- Daily day 1 (700 coins, second claim refused), playtime gift, potions (use, used-up, bad id), settings save.
- Fusion at the roof machine: 3 Kite Pup -> Shiny Kite Pup.
- Old save upgrade (v38 -> v40 through the real SaveStore code): tutorial counted done, PetsFound filled (Shiny counts
  its plain pet), coins/ball/bag/rebirths kept. Fresh save: tutorial 0, nothing found.
- Console: only the known warnings (203785492 avatar asset, ShowcaseController zone 4 slots).

## Bugs found -> fixed (T2, commit below)
1. Small (abuse only): CoreBuy / CoreEquip with a NaN step slipped past the range check and errored (caught). Fixed.
2. Small: a REBIRTH try away from the shop used up the 3 s rate limit, so a real try right after at the shop said
   "That didn't work. Try again". Shop check now comes first; the rate-limit answer says "Too fast, wait a sec".
3. Looks wrong: GIFTS window tile titles (NOW, 15 MIN ...) were black blobs: in the sunny look the label colour is ink
   and UiKit.Text still gave it an ink outline. Dark text now drops its outline (UiKit.Text, follows recolours).
4. Looks wrong: the tutorial strip + hand drew over GIFTS / DAILY / PROFILE / SETTINGS. It now hides under any
   window with a dimmed backdrop.
5. Small: STORE header chip showed "XP x1" though there are no levels. XP part hidden when NoLevels.
6. Small: PETS window close X covered the NEW sort button's red count. The count sits top-left of NEW now.

## Not fixed / notes
- Spin wheel: no button in the core loop; its remote still answers "Unlocks in Neon Lanes" (old zone name). Unreachable.
- Not tested: 2 players on the shared lane at once (Studio MCP runs one player), a real phone, product purchases.
- PROFILE / SETTINGS / GIFTS / DAILY are still the cream look (U4 restyles them).
