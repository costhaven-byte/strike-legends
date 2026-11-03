# Polish v2 handoff (for the next account)

Updated after every stage. If you're picking this up: read CLAUDE.md, PROJECT_STATE.md, POLISH_PLAN_V2.md,
POLISH_V2_REPORT.md (what's done), then this file (where it stopped).

## Where it stands (2026-11-03, end of first session: weekly usage ~92%, context nearly full)
- Run started with weekly usage at 87%. Stop rule from the owner: stop at 95% of the 5-hour limit or 98% weekly.
- DONE: L0 (before the run, ffe84c0), U1 (492a81d), TUT tutorial (7346708; owner's extra ask mid-run: "really
  concise tutorial, show not tell, reward each step" = Config.Tutorial, TutorialService, TutorialController, save v39).
- DONE: U3 part 1 = PetsFound save v40 + black unfound pets + ??? (see report).
- SKIPPED FOR NOW: L2 zone 1 colours + lighting (tag restore-pl-L2-before): Studio's 3D view was not drawing in
  screen captures (window minimized?), so lighting can't be judged. Ask the owner to keep Studio visible, then do it.
- DONE (findings only): Q2 quick live scan, Q3 measurements (see report: old areas = 1/3 of all parts, streaming off).
- BUY BEST bug from the tutorial test: NOT reproducible through the CoreBuy remote (bought ball 6 fine). Re-check the
  real tap in T1.
- DONE: U2 STORE in V2 look (re-skin, Config.Ui.StoreV2).
- DONE: T1 early abuse checks (buy/sell spam safe), owner playtest for the done stages written in the report.
- DONE: U3 part 1b = rarity names under board pets + AUTO-DELETE gear mode (see report).
- NEXT: U3 part 2 (reference picture = Documents/Strike Legends Assets/refforpethatch.png: small white card of 3-across
  pet tiles with % on top + rarity name under, price pill right of it, round AUTO-DELETE / T AUTO / R OPEN 3 /
  E OPEN 1 buttons under it, buff lines above), then L2/L3/L4 (needs Studio visible), D2, Q3 fixes, T1-T3.
- T1 suspect: second BUY BEST tap with 10K coins ("+140 5.3K") bought nothing (CoreBuy remote works directly).
- NOT STARTED: L1, L3-L6, U4-U5, D1-D7, Q1-Q3, T1-T3. Must-finish order from the plan: L2, L3, L4, U2, U3, D2, Q3, T1-T3.
- Saves: v39 Tutorial, v40 PetsFound. Next save change = v41.

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
