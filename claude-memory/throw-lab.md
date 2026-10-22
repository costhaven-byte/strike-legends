---
name: throw-lab
description: Milestones 10-20 paused 2026-10-18; Throw Lab throw approved and ported into the main game (d497c48); how to sync without Rojo
metadata:
  node_type: memory
  type: project
  originSessionId: cfc7fba5-4a52-4c89-ac74-52b4b3bfef24
  modified: 2026-10-18T15:27:39.724Z
---

2026-10-18: owner stopped milestones 10-20 and asked to rebuild only the throw feel in an isolated test place, the Throw Lab (commit f0c991a; backup tag `backup-before-throw-rebuild` + `backups/` copy of the main .rbxl).

- Code: `throwlab/` (client-only) + `throwlab/shared/ThrowSettings.luau`. Build: `rojo build throwlab.project.json -o ThrowLab.rbxl` (servePort 34873, never point it at the main place).
- Syncing edits into an open Studio without Rojo: run `python -m http.server 34999` in the source folder, then MCP execute_luau (Edit) toggles HttpService.HttpEnabled on, GetAsync each file into .Source (create new ModuleScripts by hand), toggles it off. Worked for both places.
- MCP mouse input arrives ~2s after the call, so time captures with an in-game logger (_G table) instead of screenshots. Play-mode screen captures of the 3D view come out white.

- Owner approved the Lab feel (fe3bf2a, then 80fa741 12 Power Levels).
- 2026-10-18: ported into the main game, commit d497c48; owner playtested it in-game and said it feels good. Hold-to-charge replaces aim+power; server still decides (ThrowResolver + shared ThrowRules). Feel numbers in Config.Throw. Choices made without asking: ball rarity stands in for Lab Power Level (Config.Throw.RarityLevel) until real Power Levels; Heavy/Forgiveness/Giant Pins widen the gold zone (cap SweetSpotMax 0.22); Curve = extra strike chance on near misses; Moving Pins became "Moving Gold" (gold zone slides); pin gravity via per-pin VectorForce, not Workspace.Gravity; no Gutter tier anymore. Perfects are much more common than the old Perfect Strike, so the economy sim was not re-checked.

- 2026-10-18 d5004d7: owner said Rookie felt the same as Mythics and traits never showed; asked for "1000x more fun", traits more often, gold harder. Done: gold 8% + hit-stop on PERFECT, per-ball Lab level (size/sparks/fire/rainbow, ThrowRules.Level = rarity level +1 for the better half), payout pop with multiplier, Curve always hooks + hook band counts as PERFECT, Blast rolls every throw, Heavy on every strike. Rewards formula unchanged; economy sim still not re-run.

- 2026-10-18 (uncommitted until owner confirms): throw animation in code (src/client/Modules/ThrowPose.luau) — the avatar uses AnimationConstraints, not Motor6D; changing C0/Attachment0.CFrame does nothing, the pose must be written to .Transform in RunService.PreSimulation (after the Animator). Half-circle power arc beside the bowler replaces AimBar; gold jumps to a new spot every throw (lane attribute GoldCenter, server picks) and shrinks 10% per strike in a row (player Streak attribute); ball leaves from the hand; FireServer delayed by ReleaseDelay for the down-swing. Studio screen_capture in play mode worked fine this time.

- 2026-10-18 (uncommitted, owner testing): owner called the throw animation perfect, asked for a bit more exaggeration → Config.Throw.PoseExaggeration = 1.3 (arm clamped -150..175). Trial: Config.Throw.MeterStyle = "Side" = the half circle standing up like ")" right of the bowler (owner meant this, NOT a straight bar); "Arc" = original flat half circle.
- 2026-10-18 committed 05d4e34 (with the ThrowPose/meter/gold-jump work above): throw animation scales with ThrowRules.Level: SCUFFED_* poses blended into clean ones up to Config.Throw.PoseCleanLevel 9, noise wobble (PoseWobble) at low levels, PoseFlairPerLevel bigger swing above 9. Strikes ONLY from gold: StrikeChanceWithoutPerfect = 0 and Blast capped at 9 pins on a miss (Blast 100% on a 9-pin full bar was the "max it out = strike" bug). Curve hook band still counts as PERFECT (kept, told owner).

**Why:** owner said playtests showed the throw was boring/too realistic; the goal is one throw that feels great in 30 seconds.
**How to apply:** don't resume [[master-plan]] milestones until the owner says so.
