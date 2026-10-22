---
name: master-plan
description: "Owner's MASTER_PLAN.md (milestones 10-20) + STRIKE_LEGENDS_ADDENDUM_1.md turn Strike Legends into a simulator; authority order, M10 status, how tuning works"
metadata:
  node_type: memory
  type: project
  originSessionId: 0177a33e-d12b-4081-8636-fc43e1c21635
  modified: 2026-10-18T08:18:39.401Z
---

On 2026-10-18 the owner handed over STRIKE_LEGENDS_MASTER_PLAN.md (copied into the repo as MASTER_PLAN.md): bowling becomes the "swing" of a Roblox simulator (zones 10-3,000 pins, mascots, bosses, 5 crate tiers, rebirth "Go Pro Tour", daily quests, economy simulator). A few hours later STRIKE_LEGENDS_ADDENDUM_1.md appeared in the repo root (dropped in by the owner, never mentioned in chat). Authority: addendum > MASTER_PLAN.md > GAME_DESIGN.md (CLAUDE.md says so).

Addendum key points: the 20-ball roster stays untouched (names, mults, traits); the plan's 12-tier ball shop becomes 12 "Power Levels" (power + mult, ball mult stacks on top); crates drop only roster balls with new odds and pity (Basic/Bronze Rare@10, Silver/Gold Epic@20, Gold/Neon Legendary@80); ranks = 60 levels inside the 10 named tiers, trials only at tier changes, migrate saves; gems KEPT and a gem sink must be proposed (overrode the owner's chat answer "remove gems"; gems left ON behind Config.Gems.Enabled, asked owner to confirm); streak tier names are the M13 drop thresholds; AssetSlots module + placeholder rule for art; ball meshes are 22K-134K triangles (counted from the .glb files in Documents/Strike Legends Assets), target 1.5-3K.

Owner's kickoff answers: ranks become ~60 numbered levels (yes); Uncommon folded into crate odds (superseded by the addendum's odds).

M10 built 2026-10-18 (uncommitted, awaiting the owner's playtest OK): Config.Economy (sim-only tables), tools/EconomySim.luau mapped to ServerStorage.Tools (default.project.json), RateLimit module, Config.Gems switch, PlayTime field (save v6), analytics event list + session/last-action logging, autosave 60s. Tuning results are in the GAME_DESIGN.md changelog (section 12). The plan's raw numbers were ~5x too fast; big drivers were the rank curve, cheap eggs (fixed with per-egg BonusScale) and crates. Added unplanned XpBonus per rebirth (proposed). Big price jumps right after each zone opens are inherent to the stacked multipliers; accepted.

Tuning trick: Studio edit-mode execute_luau can't see unsynced files, so serve the repo with `python -m http.server 8768 --bind 127.0.0.1`, fetch with HttpService (enable, fetch, disable) into temp ModuleScripts, and require Clone()s so edits are re-read. Bisect prices per level against target minutes.

Owner approved 2026-10-18: gems stay on with the gem sink = buying Polish levels with gems; per-egg BonusScale; rebirth XpBonus +100%. M10 playtested by the owner and COMMITTED 55a5a86 (2026-10-18). Next: Milestone 11 (throw feel), in a new chat.

Pending (owner said 2026-10-18 "ask me later"): the lighter ball models job (addendum section 7, proposal card task_621c387d). Bring it up again at the next natural break, e.g. after M10 is confirmed.

**Why:** the owner wants these files remembered as the roadmap.
**How to apply:** check the addendum first, then the plan; one milestone per chat ([[strike-legends-setup]], [[strike-legends-progress]]).
