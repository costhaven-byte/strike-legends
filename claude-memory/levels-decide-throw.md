---
name: levels-decide-throw
description: Owner rule 2026-10-20 - rank (Rookie, Amateur... Pro Tiers / rank levels), not the ball or Power Level, decides throw animation and ball speed; in Addendum 3 S0
metadata:
  type: project
---

"Levels" here means rank level-ups (Rookie, Amateur, Regular ... Hall of Famer), NOT Power Levels. Rank decides the throw animation (pose and pace) and the ball's travel speed. The equipped ball never changes either; balls only change look, coin multiplier and traits. Power Level keeps pins/value/ball looks but stops picking the pose. Written into STRIKE_LEGENDS_ADDENDUM_3.md S0 "Where the tiers come from", with a default fix for the 90-second first-jump rule (small speed steps at rank levels 2-6 inside Rookie, new animation + bigger jump per Pro Tier).

**Why:** owner said levels deciding this makes more sense than balls; clarified "level ups (rookie, amateur, etc.)" 2026-10-20. I first wrongly assumed Power Level.
**How to apply:** when building S0 or adding balls, never give a ball its own speed or pose; move the pose from ThrowRules.Level(PowerLevel) to rank. Related: [[addendum-2]], [[zones-plan]].
