---
name: ball-model-weight
description: "Ball mesh reduction job (addendum §7) — light balls swapped in 2026-10-18, awaiting owner OK; how meshes can/can't get into Studio"
metadata:
  node_type: memory
  type: project
  originSessionId: 47b4138a-8b6a-4e4c-adce-7343f0fc588a
  modified: 2026-10-21T21:43:08.761Z
---

2026-10-18: all 20 balls reduced from 580k to 51k triangles (Dragon 129k→4.4k, most 1.1k–3k). Files in `Documents/Strike Legends Assets/Roblox Upload/BallsLight/` (decimate.py, per-ball JSON, SL_BallsLight.glb). Owner imported the glb; Claude swapped the light meshes into ReplicatedStorage.BallModels (backup ServerStorage.BallModels_Heavy, raw import in ServerStorage.SL_BallsLight_Import). Phone test measured: 10 balls + 30 pins went 436k→53k tris, 168→52 draws. Studio-only change (nothing in src/), awaiting the owner's OK; owner must save the place. Full hand-over in the side-session notes folder (ball-weight/HANDOVER.md).

Facts learned:
- Scripts can't upload meshes: AssetService:CreateAssetAsync → "not available yet". New meshes need Studio's 3D importer (owner clicks, or computer use).
- The 3D importer turns glb meshes 180° about Y (x and z negated, UVs intact); undo with CFrame.Angles(0, math.pi, 0).
- EditableMesh works in Edit via execute_luau (good for reading triangle counts / geometry of any MeshId) but is blocked at runtime by the place security setting.
- EditableMesh MeshParts are not re-centred on their bbox; centre vertices first. MeshPart:ApplyMesh wipes TextureID.
- SceneAnalysisService:GetTriangleCompositionAsync (play mode) gives real triangle + draw-call counts per view.
- Lime Twist / Bubblegum / Ocean stripes z-fought with the shell in the originals (thin lines); light versions show them wide.

2026-10-22: owner's real Void/Supernova .obj files finally imported (test pending): light glb from scratchpad lighten.py (copy in Assets/Roblox Upload/VoidSupernovaLight), owner ran Import 3D, Claude placed pieces with CFrame.Angles(0, pi, 0). Floating pieces (disk, rings, shards, stars) live in ReplicatedStorage.BallFxPieces and hang on the BallFx rig so they don't tumble when the ball rolls. Thin rings look invisible in far/unlit captures; check close up in the lobby.

**Why:** phones; addendum says 1.5k–3k tris per ball.
**How to apply:** if the owner rejects the look, restore from ServerStorage.BallModels_Heavy. See [[strike-legends-progress]], [[throw-lab]].

2026-10-19: balls looked the wrong colour (Magma blue) because each tier's models share template parts: Rare rare_glow_outer/inner + rare_insert (blue 45,140,255 neon, T 0.86-0.93) and Uncommon edge_glow (green) wrap the shell and tint it. Recoloured per ball theme in BallModels (not in BallModels_Heavy backup); Inferno/Plasma got added theme_glow_inner/outer shells. Source textures in the .glb files were correct all along.
