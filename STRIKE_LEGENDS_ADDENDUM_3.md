# STRIKE LEGENDS: ADDENDUM 3 (STORY LAYER)

For Claude Code. Read this after STRIKE_LEGENDS_ADDENDUM_2.md is fully built and working. Do not start any of this until Addendum 2 is done. Addendum 3 does not replace anything. It sits on top of GAME_DESIGN.md, Addendum 2 and the master plan for milestones 10 to 20.

Also read HANDOFF_FIRST_5_MINUTES.md and FIRST_5_MINUTES_REPORT.md before building anything. Whether or not that handoff has already been applied, its changes are the baseline for the first 5 minutes and this addendum must not undo or delay them (details in section 2B).

Selim is not a coder. Explain what you did in plain language, never assume he reads code, and keep your reports short.

---

## 1. What this is

A thin story skin over the existing core loop. The loop does not change: throw, earn, buy crates, rank up, unlock zones, collect balls and pets, rebirth.

One gameplay change rides along with it: a throw speed ladder (S0). The weak starting player throws visibly slower, and each upgrade increment makes the throw faster. That is core gameplay, not story, and it is built first.

The pitch in one line: a broke bowler with a beat-up ball bowls in a raggedy city alley, and a mentor pushes him to prove himself worthy of the big leagues.

Why it exists: playtesting said the game is fun for about 5 minutes but not addictive. A clear goal and a reason to care about each rank-up gives progression emotional pull. It is packaging and a goal system, not a content project.

Important honesty note: story does not fix a flat loop on its own. If the throw or the reward feel is weak, fix that first. This layer should make good progression feel meaningful, not hide bad progression.

---

## 2. Hard rules (do not break these)

1. The throw loop is sacred. Nothing in the story layer (S1 to S7) may delay a throw, block throw input, or sit between a throw and its reward. The only deliberate slowdown is the speed ladder in S0, and it only affects ball travel and throw animation pace.
2. No cutscene before the player's first throw. The first throw happens within seconds of spawning.
3. Everything story-related is skippable or dismissible with one tap or click, and never repeats on routine actions.
4. All story text is 2 sentences maximum per line. Short words, readable by a 9 year old.
5. No custom character animation. Use Roblox default animations and emotes only. Ambient animation (idle loops, flickering lights, steam) is fine and cheap.
6. Do not use the word "homeless" in any in-game text. Use wording like "broke", "down on his luck", "nothing but a beat-up ball". Keep everything within Roblox community standards for younger players.
7. Do not rename or renumber existing milestones. Slot this work in around milestones 10 to 20 where it fits, and map story beats onto the ranks and zones that already exist.
8. Do not stop to ask Selim for approval between steps. Build S0 to S7 in order, check your own work in Studio, and report once at the end of each step. Only stop and ask for a decision that cannot be undone or that is genuinely ambiguous.
9. Budget cap: story work (S1 to S7) should stay at roughly 15 percent of total remaining effort. If usage is running tight, cut in the order listed in section 8. S0 is core gameplay and does not count toward the cap.
10. Never push any first-5-minute reward later than the baseline in section 2B. If a story element or the speed ladder would delay one, change the story element or the ladder, not the reward.

---

## 2B. First 5 minutes baseline (from HANDOFF_FIRST_5_MINUTES.md)

Selim already gave Claude Code a first-5-minutes handoff after an audit showed the early game going quiet. Its changes are the baseline. Keep them exactly as they are:
- The first rank trial (Amateur) needs 1 strike in a 6 throw window, and there is no cooldown after a failed trial for the first two ranks.
- The free gift crate arrives at about 10 throws, landing around 0:30 to 0:45, and the first crate ever keeps its guaranteed Rare behavior.
- The Basic crate (1,600 coins) is an eligible target on the existing "next goal" HUD bar until the player has bought their first crate.
- Logging for the real Perfect rate and the reward timeline is part of that handoff.
- Pricing for Power Level 3 and 4 is deliberately deferred until that data exists. Do not change prices or reprice anything in this addendum.

How this addendum fits on top of it:
- The story reuses these moments. It does not add new ones in front of them and it does not delay them.
- The existing "next goal" bar is the goal line. Extend it, do not build a second one (see S2).
- Rank trials are the mentor's tests. The mentor speaks at a trial, once, and never again on a retry (see S5).
- Rizzo, the dealer, delivers the gift crate and dresses the Basic crate kiosk (see S4).
- Do not build a second logger. Add any new events to the logging that handoff already created (see section 5).
- Because the throw is slower at the start (S0), throw-count thresholds like the gift crate at 10 throws must be re-checked against real seconds so the 0:30 to 0:45 target still holds.

---

## 3. Story spine (draft, adapt to the real ranks and zones)

First, read GAME_DESIGN.md and the milestone 10 to 20 plan to find the actual number of ranks and zones, and their current names. Map the beats below onto them. If the real count is different from 8, keep the same arc and stretch or compress it. Rename ranks and zones in code to the story names only if it is a clean rename with no behavior change.

Working character names (Selim can change these later, keep them in one config table so renaming is one edit):
- Mentor: Old Pete. Gruff, dry, secretly proud of the player.
- Crate dealer: Rizzo. Fast talker, sells crates from a rusty cart, has a catchphrase ("Luck's a lane, kid.").
- Player: unnamed, just "kid" or "champ" in dialogue.

Beat list (draft zone and rank names, replace with the real ones where they exist):

| # | Rank (draft) | Zone (draft) | Story beat | Mentor line (draft) |
|---|---|---|---|---|
| 1 | Alley Rat | Back Alley | Start. One cracked lane, trash cans, a flickering sign. Rizzo sells the first crate. | "Nice arm, kid. Let's see if it's worth anything." |
| 2 | Pin Hustler | Corner Lanes | First real lane. Old Pete appears and sets the goal. | "Big leagues don't take strangers. Prove yourself." |
| 3 | Lane Local | Neon Row | Neighborhood starts to notice you. First rival named. | "They're talking about you. Don't let it go to your head." |
| 4 | Corner League | Rooftop Rolls | First league night. Crowd appears. | "Real pressure now. Breathe, then throw." |
| 5 | City Circuit | Downtown Arena | Bigger crowds, better lane, new gear. | "You look like a bowler now. Act like one." |
| 6 | Regional Pro | Chrome Hall | Sponsor logos appear (fictional only). | "Money follows winners. Stay hungry." |
| 7 | National Contender | Grand Stadium | Spotlights, announcer voice lines as text. | "One more step. Do not blink." |
| 8 | Big League Legend | The Big League | Final tier. Pete finally says he is proud. | "Told you you'd make it. Now go be a legend." |

Rebirth ("The Comeback"): the player goes back to the alley with a permanent boost. Frame it as a comeback, not a loss. Draft line: "Start over, come back stronger. You know the game now."

Pets: if the first pet is obtained early, frame it as a stray that followed the player out of the alley. Optional dressing, one line of text only.

---

## 4. Systems to build (in this order)

Each step has acceptance criteria. Build it, test it in Studio yourself, then move on.

### S0. Throw speed ladder (core gameplay, build this first)

Selim wants the weak starting player to very obviously throw the ball slower than the current Addendum 2 throw, and to get faster with each upgrade increment. This is a gameplay change, not story. It is built before S1, it does not count toward the 15 percent story budget, and it is never cut.

What "speed" means here:
- How fast the ball travels down the lane, and the pace of the throw animation (Roblox default animation with adjusted playback speed).
- It does NOT change the hold-and-release input, the Perfect timing window, auto-aim, or how pins react. Skill and outcomes are identical at every tier. Pin reset and strike celebration timings do not slow down either.

Draft ladder (keep it all in Config so it is easy to tune). The top tier equals the current Addendum 2 throw speed:

| Tier | Ball and animation speed (relative to Addendum 2 speed) |
|---|---|
| 0 (start) | 0.50x |
| 1 | 0.62x |
| 2 | 0.75x |
| 3 | 0.88x |
| 4 | 1.00x (current Addendum 2 speed) |

Do not add tiers above 1.00x now. If Selim wants faster-than-current tiers for rebirth later, he will ask.

Make the difference obvious, not subtle:
- Ball travel time and throw animation pace change at every tier.
- Add a ball trail and roll sound pitch that scale with the tier: nothing fancy at tier 0, a visibly stronger trail and higher pitch at each step. Placeholders are fine, real art comes later.
- Selim should be able to tell the tier from watching one throw with the sound off.

Where the tiers come from (Selim's decision, 2026-10-20):
- Rank decides the throw, not balls and not Power Level. The player's rank (Config.Ranks Pro Tiers: Rookie, Amateur, Regular ... Hall of Famer, 6 rank levels each, 60 in all) sets the throw animation (pose and pace) and the ball's travel speed. The equipped ball never changes throw speed or the throw animation; a ball only changes its own look (model, trail, VFX), its coin multiplier and its traits.
- Power Level keeps what it does today (pins on non-PERFECT throws, coin value, and its ball looks in Config.Throw.Levels: size, trail, sparks, fire), but it no longer picks the throw pose. Today the pose follows Power Level (ThrowRules.Level(PowerLevel) in ThrowController); move that to rank. Ball speed is one fixed number today (Config.Throw.BallSpeed); make it come from rank. Check that no ball overrides speed or pose, and remove any that does.
- Each Pro Tier gets its own throw animation (a Rookie throw looks weak and clumsy, a Hall of Famer throw looks like a pro). Keep it in a Config table, one row per Pro Tier.
- Timing problem to solve: Amateur starts at rank level 7, which comes after zone 2 opens (level 5), several minutes in. That breaks "first speed jump within about 90 seconds" below. Default fix (Selim can change it): the speed also rises a small step at every rank level inside Rookie (levels 2 to 6; level 2 arrives at 180 XP, about a minute), and each new Pro Tier brings the new animation plus a bigger speed jump. Speed reaches tier 4 (today's speed) at a rank Selim picks; suggest one in the report.
- Do not change any prices, XP needs or what ranks unlock beyond this throw effect. Pricing is deferred pending data.
- In your report, say exactly which ranks and rank levels change the throw and what each one now looks like.

Protect the first 5 minutes (this is the risk of a slow start):
- A slower start means fewer throws per minute. Measure first-5-minute rewards in seconds, not throw counts. Recompute throw-count thresholds (for example the gift crate at about 10 throws) against the real cycle time at tier 0 and adjust the counts so the baseline in section 2B still holds. Gift crate by about 0:30 to 0:45, first rank-up reliable.
- The first speed increment must be reachable within about 90 seconds, so the player feels the jump early. That jump is itself a first-5-minutes reward moment.
- Slow must not mean tedious. If a full throw cycle at tier 0 feels like a wait, soften the start (for example 0.65x instead of 0.50x) and report it. Tier 0 should still feel like a weak but real throw.

Acceptance:
- Tier 0 looks and sounds clearly slower than tier 4, and each tier in between is noticeably faster than the last.
- Perfect timing, auto-aim and pin results behave identically at every tier.
- The first-5-minutes reward timings from section 2B still land on time at tier 0.

### S1. Story config table
- One module that holds all story data: character names, every dialogue line, rank and zone story names, banner text.
- All text in one place so Selim can edit it without touching logic.
- Acceptance: changing a line in the table changes it in game with no other edits.

### S2. Always-on goal line (extend the existing goal bar)
- The game already has a "next goal" HUD bar (the first-5-minutes handoff made the Basic crate eligible on it). Do not build a second goal line. Extend that bar so its text uses the story names and plain words, for example "Next: reach Pin Hustler".
- Keep its existing logic for picking the goal with the highest progress. Only change the wording and the rank and zone names it shows.
- Must never cover the throw controls or lane.
- Acceptance: visible from the first second, always correct, updates on rank-up and zone unlock, and the Basic crate target still appears until the first crate is bought.

### S3. Dialogue bubble module
- A reusable speech bubble for the mentor and the dealer. Triggered by a ProximityPrompt or by a story event.
- No camera changes, no input lock. The player can keep throwing while a bubble is up.
- Tap or click to dismiss, and it auto-dismisses after a few seconds.
- Each line shows once per player and is remembered in saved data so it never repeats after a rejoin.
- Acceptance: bubbles never block a throw, skipping works on desktop and mobile, shown lines are saved.

### S4. Dealer NPC and first-crate scene
- Place Rizzo and his cart in the starting alley using existing or simple placeholder models. Real art comes later.
- Rizzo delivers the free gift crate. It still arrives at the throw count the first-5-minutes handoff set (about 10 throws, re-checked for the slower start in S0), so the reward does not move. He appears, says one short line, and the crate opens using the existing crate opening flow. No extra clicks before the reward.
- Dress the existing crate kiosk (where the Basic crate at 1,600 is bought) as Rizzo's cart. The kiosk's behavior and pricing do not change.
- Acceptance: a new player gets the gift crate on time through Rizzo, can buy the Basic crate at his cart, and returning players are not forced through it again.

### S5. Mentor NPC and rank-up beats
- Place Old Pete using a simple placeholder model. He shows up in the alley and at each zone entrance.
- On each rank-up or zone unlock, show a rank-up banner with one mentor line. Banner is non-modal (the game keeps running), dismissible with a tap, and auto-dismisses in 3 to 5 seconds.
- Frame rebirth as "The Comeback" with its own banner line.
- Rank trials are the mentor's tests. When a trial starts, Old Pete says one short line (for example "Show me one strike."). On a retry he stays quiet. The easier first trial and the no-cooldown rule for the first two ranks from the first-5-minutes handoff stay exactly as they are.
- The first time the player gets a speed tier increase (S0), show one mentor bubble (for example "Arm's getting faster, kid."). Do not add banners for later speed tiers.
- Acceptance: every rank-up shows its line exactly once, never delays rewards, never blocks play.

### S6. Rename and light environment progression
- Apply the story names to ranks and zones (clean rename only).
- Make the starting alley look rough and each later zone look visibly nicer by swapping or adding props, lighting and colors from assets that already exist. Do not request new art for this step. If an asset is missing, use a clearly marked placeholder and list it in the report.
- Acceptance: a player can tell the zones apart at a glance and the climb from alley to arena is visible.

### S7. Ambient life (last)
- Cheap ambient loops only: flickering sign, steam vents, idle NPCs, small particles. Roblox default animations for NPC idling.
- No new cutscenes. If a camera move is ever used, it is one short skippable beat at zone unlock, 3 seconds max, never at first spawn.
- Acceptance: no measurable drop in frame rate or throw responsiveness.

---

## 5. Telemetry (no testers needed)

Selim has no testers and does not want blocking test gates, so build simple measurement instead.

The first-5-minutes handoff already added logging for the real Perfect rate and the reward timeline. Reuse that logger and add to it. Do not build a second one.

Log these events with Roblox's built-in analytics (verify the current AnalyticsService API before using it) or, if that is not available, simple saved counters Selim can read in plain language:
- throw speed tier over time, and time spent at each tier, so Selim can see whether the slow start hurts early retention
- session length per player
- time to first throw
- highest rank and zone reached
- last rank or zone before leaving (quit point)
- how many story lines were viewed vs dismissed quickly (to see if anyone reads them)
- first crate purchase completed or not

Deliver a short plain-language summary Selim can read, for example a print in Output or a simple dev-only stats panel. No dashboards, no complexity.

---

## 6. Kill rule

After a small build is live and there is real player data, compare sessions with the story layer against the earlier baseline. If rank-ups with story beats do not lengthen sessions or improve return rate, stop spending on story work and tell Selim plainly. Do not defend the story layer for its own sake.

---

## 7. Out of scope (do not build)

- Long cutscenes, voice acting, custom character animation
- Branching dialogue, quests, story chapters, seasonal story content
- Rival characters with their own systems (a rival name in a line of text is fine)
- Anything that changes the core loop, economy, pricing or ranking rules, apart from the speed ladder in S0 (which changes ball and animation speed only)
- Redoing or reverting anything from HANDOFF_FIRST_5_MINUTES.md
- Monetization (still deferred until the game proves fun)
- Any new art requests. Art for this layer is made later in Claude Design using STORY_ASSET_PROMPTS.md. Use placeholders now.

---

## 8. If usage runs short, cut in this order

1. S7 ambient life
2. S6 environment progression (keep renames only)
3. Mentor NPC model (keep the text banners)
4. Dealer NPC model (keep the speech bubble)

Never cut S0, S1, S2, S3 or the rank-up banner in S5. S0 is core gameplay and the rest are the core of the story layer.

---

## 9. Report format

After each step, report in plain language, 3 to 5 lines max:
- what you built
- what you checked and how
- anything that is a placeholder or needs art later
- anything you were unsure about and what you chose

At the end, give one short summary and a list of every placeholder that needs real art, so Selim can hand the list to Claude Design later.
