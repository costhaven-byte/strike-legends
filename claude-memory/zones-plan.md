---
name: zones-plan
description: "Step 9 zones plan (2026-10-20) - new Back Alley zone 1, current NeonAlley = zone 2, designs come from Claude Design projects; later each zone gets its own balls and mascots"
metadata:
  node_type: memory
  type: project
  originSessionId: c0f6efbd-4176-4521-8b3d-1d693416c551
  modified: 2026-10-22T03:03:20.678Z
---

Step 9 split: 9a zones, 9b boss pins. Owner gives one Claude Design project per zone (read with DesignSync get_file; zone 1 = project 63ef99c5-db0e-4a92-a1ee-8cb9302d304f, "Bowling Alley Zone 1.html", a three.js procedural prop set in studs). Prompts for the rest in ASSET_PROMPTS.md.

- Zone 1 = new run-down "Back Alley / Back-Lot Lanes" where new players start; today's alley (Workspace.NeonAlley) becomes zone 2 Neon Lanes (30 pins, rank level 5).
- Owner wants NEW BALLS and NEW MASCOTS for each zone too, but LATER ("start with the zones only").

**Why:** owner's direction 2026-10-20.
**How to apply:** build only zones now; propose per-zone balls/mascots as later steps. Related: [[addendum-2]], [[place-location]].

2026-10-20 (later): owner said "implement all Back Alley designs". Done (test pending): Rizzo crate dealer + cart, Alley Crate look for Basic, taped Back Alley pins (PinModels.BackAlley), 4 zone-1 balls added to the Basic crate pool (owner picked this over an alley-only pool). Design projects are readable in the built-in browser at claude.ai/design (chat text via document.body.innerText; page content is a cross-origin iframe, so read it by screenshots / End key).
Import gotcha: Studio's 3D import queue can upload fine but fail to insert ("content representation is being generated"); the uploaded AuxScene model ids show in Asset Manager and load with InsertService:LoadAsset. Imports lose colours: read baseColorFactor from the .glb (Documents/Strike Legends Assets) and repaint by part name. Rizzo files were exported in meters (scale 1/0.28).

- 2026-10-21 lag gotcha: the Studio import queue later dropped 7 stray "AuxScene" copies (765 UNANCHORED meshes) into Workspace = big lag. After imports, check Workspace for AuxScene and move them out. Edit-mode screen captures of the alley lighting were unreliable (stayed dark whatever the lights); judge lighting from a play-mode capture.

- 2026-10-21 zone gate fed4c8b (test PENDING, tag restore-zone2-gate-before): owner wants per-zone crates: zone 1 = Alley Crate with ONLY alley balls (ball Zone=1), every other crate blacked out "UNLOCKS IN <zone>" until that zone opens; zone 2 crate changes only when zone 3 is built. Zone 2 = level 5, claim lane by stepping on it, kept until leaving zone. Unlock = popup window with 3D crates/balls. Zone 2 has no mascots yet (Neon egg empty) - told owner.
- Sync without Rojo: HttpService.HttpEnabled is off in this place; the execute_luau sync must flip it on, GetAsync from python http.server, then restore it.

- 2026-10-21 9158362 (test PENDING): owner says PETS not mascots (player-facing text only). Zone popup shows Neon Egg + 3 '?' pet cards; TAKE ME THERE = teleport to Gated.Arrival (owner said the beam didn't work). Rizzo '!' without text + own beam. Testing tip: faking RankLevel by attribute gets you kicked out by LaneService (it reads saved data) - use the TestXP remote instead.

- 2026-10-21 501c4bc (test PENDING, tag restore-zone2-lock-before): owner chose zone 2 = the WHOLE building (lobby too). Gate wall now plugs the Back Alley door (54,7,56); KickTo (54,4,63). Pets locked until zone 2 (Alley Egg Zone=2). Kiosk = Bronze + Silver (Studio swap, backup ServerStorage.KioskDisplays_Backup_20261021); Gold only in shop screen. Neon crate removed from Config.Crates (owner will rename it and put it in zone 3-4+ once the new economy exists, ~5B); day 7 = Gold. Owner may add a 4th crate design later (bronze/silver/gold reshuffle).

- 2026-10-21 pets (test PENDING, tag restore-pet-models-before, NOT committed yet): 12 pet designs + Neon Egg/stand imported by owner (15 AuxScene in Workspace -> ServerStorage.PetImports_Raw). Built ReplicatedStorage.PetModels (flat parts + Root, scale 1/0.28, repainted from .glb via http.server JSON). Gotchas: Model:ScaleTo is ABSOLUTE (use GetScale()*k); glb transforms are baked (all parts rot 0) and import = 180deg about Y (x,z flip) - get axes from the .glb with numpy; Roblox Part names = glTF NODE names (duplicates get 2,3 suffix); semi-transparent shells nearly vanish next to Neon -> use Glass; aura shells need >=0.93 transparency. Hatch storyboard (6 frames, 3s) not built yet - next step.

- 2026-10-22 crate kiosk 4deea33 (test PENDING, tag restore-kiosk-before): owner's "Roblox Bowling Crate Kiosk" design (claude.ai/design 40e64f71, crate_kiosk.glb) built in Hub.CrateShop at scale 2.4. Gotchas: textured .glb labels render dark/flipped -> SurfaceGui ImageLabel (LightInfluence 0) on a card part with ImageRectSize (w,-h) to flip V; Neon lime/white looks YELLOW under the lobby ColorGrading -> use saturated hues; crate PointLights > ~6 studs tint the neighbour crates; play captures work (camera via BindToRenderStep Scriptable); execute_luau require() gives fresh module copies -> use TestXP/TestCoins remotes from Client.

- 2026-10-22 PLAN CHANGE (owner): publish with zones 1-4 only (Back Alley, Neon Lanes, Arcade Arena, Skyline Lanes); owner can't do 6 zones now. Zones 5-6 stay in the data tables, locked/hidden, maybe a later update. Order: 9a zones 3+4, 9b boss pins, economy pass so ranks to 60 / eggs / crates all fit inside zone 4, then rebirth (requirement = zone 4). Written into Addendum 2 under step 9.
- 2026-10-22 later: zone 3 = "Main Street Lanes", a regular real-life bowling alley (Arcade Arena dropped, too close to Neon Lanes); prompt rewritten in ASSET_PROMPTS.md. Rebirth unlocks at zone 3. Owner asked zone 3 = L15, zone 4 = L25; sim (4 zones, no rebirth): today L12/L22 = zone 3 at 23 min, zone 4 at 106 min; L15/L25 = 54 min / 290 min; L14/L23 = 40 / 155; L15/L22 = 54 / 132. Rebirth readiness is held back by its 4B coin cost, not the level. Levels 40+ never reached in 10 h with 4 zones.
- Owner then chose to KEEP zone 3 = L12, zone 4 = L22.
- 2026-10-22: zone 3 + 4 designs are ready in claude.ai/design (copy 1:1 via built-in browser); owner imports the files into Studio. NOT started. Boss redesign (written in Addendum 2 step 9): boss unlocks at zone 4, separate area reached by helicopter flight from zone 4, spawns every 45 min - owner said don't work on it yet. Pet fusing = walk-up station like the spin wheel, unlocks at zone 3.
- 2026-10-22 zone 3 PASSED. Then owner had the shoe rental + snack bar removed (ServerStorage.Zone3_RemovedForKiosk) to free the back strip behind the bench rail (world x 73-167, z ~37-56) for a kiosk, display cases and the pet FUSION machine (not built yet).
- 2026-10-22 zone 3 BUILT (tag restore-zone3-before): Workspace.MainStreetLanes east of the lobby, door in lobby east wall z 8-16. Gotchas: design .glb exports can MISS groups hidden in the design's cutaway view (ceiling, near wall) - read the design HTML (DesignSync get_file) and rebuild them; the full three.js source gives exact coords/colours. Repaint by POSITION match against the .glb (scratchpad glbmats.py idea: node bbox centres, import = 180deg about Y around the import pivot), colours from the HTML hex (glb factors are linear). PinModels templates must be model scale 1 (resize parts, not ScaleTo) or pins come out tiny. Gate lock sign needs SignFace when the door doesn't face +Z. Rank trials block TestXP past level 6: test unlocked zones by temporarily lowering Economy.Zones Rank in Studio's Config copy only. Zone 4 raw import (Skyline, anchored) in ServerStorage.Zone4Imports_Raw.
