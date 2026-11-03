# Polish v2 handoff (for the next account)

Updated after every stage. If you're picking this up: read CLAUDE.md, PROJECT_STATE.md, POLISH_PLAN_V2.md,
POLISH_V2_REPORT.md (what's done), then this file (where it stopped).

## Where it stands (2026-11-03, STOPPED at weekly usage 97%: next step too big for the last 1%)
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
- DONE (second session, 2026-11-03): U3 part 2 = grid egg board (615df90, Config.EggBoard.Grid).
- DONE: L2 zone 1 colours + lighting (b7a976c).
- DONE: L3 zones 2-4 own light (9c7cbaa).
- DONE: L4 sell/shop pads per zone (d58d354). Left from L4: egg rings, gate landings, beams, sign style.
- DONE: Q3 part 1 small-decor shadows off (Config.Perf, PerfController).
- DONE (third stretch, weekly 96%): T1 BUY BEST "second tap" = not a tap bug; the grey button showed the next
  locked-zone price. Now says OPEN ZONE n (2eb2064). Q3 part 2: old areas leave each screen 12 s after join,
  client only (5822616, 17,244 -> 11,586 parts). D2 started: coin/gem flies + pin gains swoop on a curve.
- NEXT: D2 rest (AN2 items 1-3: throw approach, meter spring, ball hook + glint, pin weight, strike letters; item 5
  bag squash), then T1 full bug hunt -> BUG_HUNT_REPORT.md, T2 fixes, T3 final check.
  Studio is visible: screen_capture draws the 3D world. To see a sell without pins: Server execute
  `Remotes.CoreSold:FireClient(player, 125000, 2.5, {})` (no data change).
- Testing tricks: TEST panel remote `ReplicatedStorage.Remotes.TestPanel:InvokeServer("Coins")` (x10 coins) and
  `("Pass", "TripleHatch")` (toggle a pass). Camera: RunService:BindToRenderStep at Last+10 setting cam.CFrame.
  Studio's mouse tool can't click buttons on 3D billboards; simulated E doesn't fire ProximityPrompts.
  Studio play = fresh save each time (Config.Onboarding.StudioNewPlayer); shop buys need standing on the
  zone 1 shop pad (-17, 853, -3415).
- NOT STARTED: L1, L5, L6, U4, U5, D1, D3-D7, Q1. Must-finish left: D2 (rest), T1, T2, T3.
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
