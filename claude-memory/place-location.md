---
name: place-location
description: "The real Strike Legends place is a Roblox cloud place (94254609600041), NOT the stale Strike Legends.rbxl file; restore points are cloud copies"
metadata:
  node_type: memory
  type: project
  originSessionId: e89be932-79bf-4c04-9308-cb2491c59eac
  modified: 2026-10-18T17:08:36.863Z
---

The main game lives on Roblox as a published place, ID 94254609600041 (universe 10770746660). Studio saves it with "Save to Roblox". `Strike Legends.rbxl` in the repo is a stale copy from Oct 14 (old aim and power meters). Opening it confused the owner on 2026-10-18.

Restore point for Phase 1 step 1: the owner used Save As, which published a new game, place 93792316689717 (universe 10771768481).

To find out what Studio has open, read the logs in %LOCALAPPDATA%\Roblox\logs. Look for "placeid:" / PlaceSessionId, StudioSavePlaceToCloud, and PublishToDifferentGame.

**Why:** a wrong file looks like lost work, and a restore point saved to disk would be stale.
**How to apply:** restore-point steps for the owner = File → Save to Roblox As (copy), or Roblox version history. Never point the owner at the .rbxl. Open the game via My Games → Strike Legends. Related: [[addendum-2]], [[strike-legends-setup]].
