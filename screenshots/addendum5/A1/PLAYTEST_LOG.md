# A1 playtest (2026-11-01, Studio Play, fresh player)

No screenshots: Studio's 3D view was frozen on an old frame (viewport 1x1, RenderStepped not firing, screen_capture
timed out in Edit and Play; restoring/maximizing the window did not wake it). Restarting Studio was not done because
the place may hold unsaved Studio-only work. Checked by numbers from the client instead.

Ball 1: count 5-6, drawn pins 5-6, paid 13-15 (Studio owner has passes), pose 1, tier Good.
Ball 10 (all bought with TEST coins, ladder in order):
count 3207 shown 40 paid 8018 lucky false pose 12
count 3711 shown 40 paid 9278 lucky true  pose 12
count 3571 shown 40 paid 8928 lucky true  pose 12
count 3335 shown 40 paid 8338 lucky false pose 12
count 2859 shown 40 paid 7148 lucky false pose 12
HUD counter read: 3.2K, 3.71K, 3.57K, 3.33K, 2.85K, 2.73K, 3.28K, 3.45K, 2.74K, 3.8K
LUCKY! badge: made visible on each lucky roll (its pop tween needs rendering, so not seen animating here).
Levels: no RankBadge over the head, HUD RankBar hidden, XP 0 -> 0 after throws, HUD quick pills = QuickCoins only.
EconomySim.CoreLadder(): ball 10 at 47.2 min, bag 10 at 51.3 min (same pacing as before).
Output: no errors (only the old "CrateShop/EggPad not found" warnings from the hidden stations).
