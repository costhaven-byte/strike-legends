# UI overhaul v2 plan (2026-11-02)

Source: the owner's designs in `Documents/Strike Legends Assets/` (answers to ASSET_PROMPTS_V2.md U1-U3 + daily from U4):
- `Strike Legends UI.html` = U1: kit (window, 5 button colours, price buttons, pills, progress bar, item card x6 rarities, states, badges, toast, tooltip, colours), HUD computer (B1) + phone (B2), motion notes (M), icon slots.
- `Strike Legends Screens.html` = U2: SHOP window with tabs BALLS / BAGS / REBIRTH / PASSES (desktop + phone), BUY BEST, zone switcher, card states, HOLD TO REBIRTH / GO TO SHOP, tap bag = sell.
- `Strike Legends Pets UI.html` = U3: PETS + ITEMS window, empty state, egg odds board, fusion, hatch result, full hatch sequence (single 2.4 s, triple 2.8 s, mythic 4.2 s), component specs.
- `Strike Legends - Daily Reward.html` = U4 part 1: daily reward calendar.
- `Strike Legends UI Overhaul.pdf` = icon sheet, 86 icons.

Rules from the designs: one font (Fredoka One), 4 text sizes, flat solid colours, 3 px #10172E outline, 6 px darker lip, 3 px lighter top strip, no gradients, no glow. Balls, pets and eggs on cards = 3D (ViewportFrame), not PNGs. Card rays = `V2_bg_rays` (16 white wedges) tinted per rarity over a solid rarity fill.

## Steps (one per chat; restore point before each, 2-minute test after)
- **V0 icons** - DONE 2026-11-02: 86 icons cut from the PDF (transparent 256 px) into `assets/ui_v2/icons`, uploaded, ids in `AssetSlots.Images` as `V2_<file name>`. Nothing visible changed.
- **V1 kit** - BUILT 2026-11-02 (test pending): `src/client/Modules/SlKit.luau` = colours, Fredoka One + Builder Sans 13, Block (outline, lip, top strip), Button (Green/Blue/Pink/Red/Gold x XS/S/M/L/XL, press spring, disabled + padlock), PriceButton (coin/gem/Robux/not enough), Pill, ProgressBar (green/orange/red FULL!), Window (header plate, close X, open/close motion), Well, Tabs, Card (6 rarities, Mythic stripes, states Normal/Locked/Done/Ready/New/Unknown), Dot/Tick/Padlock, Toast, Bubble, motion helpers, AutoScale. Ray art `V2_bg_rays`. Studio preview: TEST panel > UI KIT V2 (`Modules/SlKitPreview`). Nothing in the game uses it yet.
- **V2 HUD** - BUILT 2026-11-03 (test pending; Config.Ui.HudV2 = true, false = old HUD): coin/gem pills + x multiplier chip, left button grid (SHOP PETS STORE DAILY PROFILE TELEPORT) + REBIRTH bar, GIFTS/SETTINGS/PASSES top-right, PINS DOWN top-centre, NEXT GOAL card, potion timers, bag bar + SELL, THROW button + arc, one-time SELL HERE! hint; phone layout; HUD motion notes.
- **V3 SHOP balls + bags**: tabs, zone switcher, card grid with all states, BUY BEST, buy reveal.
- **V4 SHOP rebirth + passes**: rank badge (rank_01..17) to next, x3 COINS / x2 PINS tiles, RESETS/KEEPS rows, HOLD TO REBIRTH / GO TO SHOP; 8 pass cards.
- **V5 PETS window**: slot strip, totals, EQUIP BEST, sort BEST/RARITY/NEW, pet cards, empty state, ITEMS potion cards.
- **V6 egg board + fusion**: world billboard (odds row, auto-delete X, HATCH E / AUTO / x3), FUSE PETS window.
- **V7 hatch sequence**: frames F1-F9, triple (rarest in the middle), mythic version.
- **V8 daily reward**: 7 day calendar in the new look.
- Not designed yet (keep current look until the owner sends them): gifts, spin, zone unlocked, fever, lane events, toasts/afford, profile, settings, teleport, away coins, rebirth moment. The new icons can still go on them.
