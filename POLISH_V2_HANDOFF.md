# Polish v2 handoff (for the next account)

Updated after every stage. If you're picking this up: read CLAUDE.md, PROJECT_STATE.md, POLISH_PLAN_V2.md,
POLISH_V2_REPORT.md (what's done), then this file (where it stopped).

## Where it stands (2026-11-03)
- Run started with weekly usage at 87%. Stop rule from the owner: stop at 95% of the 5-hour limit or 98% weekly.
- DONE: L0 (before the run, ffe84c0), U1 (492a81d).
- IN PROGRESS: TUT = owner's extra ask mid-run (2026-11-03): "a really concise tutorial, more show not tell, but a
  tutorial nonetheless, reward the player with each step". Tag `restore-pl-TUT-before`.
  Plan: 4 steps THROW > SELL > BUY BALL > BUY BAG, shown with a ghost hand / world beams, one word each, a reward
  pop per step (coins / gems / free egg). Server gives rewards (new save field, SchemaVersion bump). Builds on the
  existing V2 guidance in CoreHudController (guideStep, sellGuide/shopGuide beams, SELL HERE! bubble).
- NOT STARTED: L1-L6, U2-U5, D1-D7, Q1-Q3, T1-T3. Must-finish order from the plan: L2, L3, L4, U2, U3, D2, Q3, T1-T3.
- Note: U3 (egg board PetsFound) planned SchemaVersion 39; if TUT takes 39, U3 uses the next one.

## How to sync code into Studio (Rojo is often not applying)
1. In the project folder: `python -m http.server 35311 --bind 127.0.0.1` (pick a fresh port if 35311 answers 404).
2. Studio MCP execute_luau (Edit): flip HttpService.HttpEnabled on, GetAsync each changed file, write it with
   ScriptEditorService:UpdateSourceAsync (Config is >200K chars, Source= fails), flip HttpEnabled back.
   Paths: src/shared -> ReplicatedStorage.Shared, src/server -> ServerScriptService.Server,
   src/client -> StarterPlayer.StarterPlayerScripts.Client (init.luau = the folder's own ModuleScript).
3. Play-mode screenshots miss the 3D world (UI only). Clicks: Studio MCP user_mouse_input with instance_path.

## Not saved to Roblox
Studio has every change synced, but the place is NOT saved to Roblox since the v2 model batches. Owner: File > Save
to Roblox when happy.
