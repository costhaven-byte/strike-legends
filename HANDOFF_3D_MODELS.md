# Handoff: put the owner's new 3D models in the game (2026-10-28)

The owner (Selim) designed every remaining 3D placeholder. The files are in `C:\Users\Selim\Documents\Strike Legends Assets` (outside the repo). Your job: swap each placeholder in the game for the real model, one small step at a time.

## Read first
1. CLAUDE.md (rules), PROJECT_STATE.md (where things are), ASSET_PROMPTS.md (Part 1 "Models ready" table = the full list).
2. Memory notes: `C:\Users\Selim\.claude\projects\C--Users-Selim-Documents-Strike-Legends\memory\` (if your account can't see them, the older copies are in `claude-memory/`). Most useful: place-location, ball-model-weight, rojo-sync-gotchas, zones-plan, perf-gotchas, crate-kit, pin-titan-boss, studio-mcp-stdio-workaround, feedback-literal-specs.

## Facts you need
- The real game is the cloud place 94254609600041 (open via My Games > Strike Legends), NOT `Strike Legends.rbxl`. Restore point = File > Save to Roblox As, or version history.
- Code syncs with Rojo (`rojo serve`, ~/.rokit/bin). World/model work goes through the Roblox Studio MCP (execute_luau etc.).
- Scripts can't upload meshes. Each .glb must be imported by the owner in Studio (File > Import 3D). Ask for several files at once to save rounds. Textures/images can be uploaded with upload_image.
- The importer turns .glb models 180 degrees about Y; fix with CFrame.Angles(0, math.pi, 0). Keep raw imports in ServerStorage, put the cleaned models where the game reads them.
- Size models with GetBoundingBox / ScaleTo (ScaleTo is absolute, not relative). Keep the sizes the current placeholders use.
- Pets: IDs stay the same (Wood Pup, Chrome Bat, Kingpin, Blaze, Cloud Bumper, Moony, Cosmo, Perfecto, Titan Jr.), so owners get the new look automatically. Idle moves come from separate named parts (PetIdle). Never write weld C0 every frame (lag); use BulkMoveTo (see perf-gotchas).
- Crates: the lid must be a separate piece hinged at the back edge (the game flips it). Crate art on shop cards uses the 3D model.
- Pin Titan: plate_1..plate_6, core_door and the arms are separate pieces the boss code animates; keep the boss hooks working.
- Never delete or rename saved data fields. Don't rewrite systems that work.
- Keep the triangle count low (phones). Check with SceneAnalysisService in Play mode if unsure.

## Suggested order (one step each, owner tests between steps)
1. Crates: zone 2 Bronze/Silver/Gold, zone 3 League + Champion + counter, zone 4 Sky Bronze/Silver/Gold + counter.
2. Zone 3 egg + stand + 4 pets.
3. Zone 4 egg + stand + 4 pets, Titan Jr.
4. Display cases zone 3 (one per rarity) and zone 4.
5. Pet fusion machine.
6. Pin Titan (normal + broken), arena, helicopter, thrown stone pin.

## Every step
- Before: tell the owner how to save a restore point (Save to Roblox As).
- After: a 2-minute plain-English test (what they should see + common silent failures) and a "Placeholders still in use" list. Wait for "passed".
- The owner doesn't write code: short, plain language.
- At the end of the session: update PROJECT_STATE.md (max 40 lines) and ASSET_PROMPTS.md (remove rows from "Models ready" once they're in the game).
