# Step D (ball effects) playtest log (2026-11-01, Studio Play)

Pushed with the http trick (python http.server 36211 + ScriptEditorService:UpdateSourceAsync): new ModuleScript
StarterPlayerScripts.Client.Modules.BallSignature (created in Studio Edit, one copy), LaneVisuals, CoreHudController,
Config. Studio's Play captures drew only the HUD (3D white), so the looks were checked by numbers, not by eye.

## Fake throws (server FireClient ThrowResult on the player's own spot, Lane6), client sampler per throw
| Ball (step) | pins | what was counted at the rack |
|---|---|---|
| Tangerine (1) Sand | 6 | 1 holder, 1 emitter (sand puff) + floor shockwave |
| Bubblegum (2) Bounce | 10 | ball hopped up to 1.13 studs; bubble puff, floor ring, glow (2 guis) |
| Lime (3) Confetti | 18 | confetti puff + 2 bursts + confetti cannon |
| Sunburst (4) Burn | 35 | ball on Fire while rolling; 7 holders / 6 emitters (flames, embers, burning pins), light |
| Frostbite (5) Frost | 70 | snow + frost streak emitters, snowflake floor ring |
| CloudSwirl (6) Arms | 140 | 2 beams (cloud arms), cloud puffs |
| Crystal (7) Prism | 300 | 6 rainbow floor rings, shards, rainbow arc beam, light |
| Lightning (8) Bolt | 650 | 6 lightning beams pin to pin, sparks, light |
| SolidGold (9) Tornado | 1.4K | 3 spiral strands + spiral sprite + gold dust |
| Daybreak (10) BlackHole | 3.2K | black hole, inward stars, then boom (11 holders, 9 guis), sonic rings while rolling |
| Daybreak | 1M | 13 holders, 11 guis (more sonic rings, bigger) |
Strength: 6 -> 0.00, 18 -> 0.09, 140 -> 0.26, 650 -> 0.39, 3.2K -> 0.52, 30K -> 0.71, 1M+ -> 1.00.

## Settings
- Settings attribute "Vfx=0;Shake=0": Sunburst + Daybreak 100K throws made 0 effect parts, 0 emitters, no Fire.
  Restored after.

## Real throws (CoreThrow remote, ball 1)
- 6 throws, 5-7 pins, Sand signature each time (1-2 holders), counter updated, no errors.

## Stress
- Daybreak at 1M pins every 0.4 s for 8 s: at most 26 effect holders / 78 descendants at once, 0 left 2 s later,
  0 Terrain attachments left (beams cleaned).

## Output
No errors (old notes only: CrateShop.Counter / EggPad / CrateShop not found, an old asset id type warning).
