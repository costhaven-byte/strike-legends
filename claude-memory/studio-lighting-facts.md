---
name: studio-lighting-facts
description: This Studio has no Lighting.Technology option (unified lighting); don't ask the owner about it; play-mode screen_capture can come back white
metadata:
  type: project
---

Lighting.Technology does not exist; its replacement is **Lighting.LightingStyle** (Soft/Realistic) + PrioritizeLightingQuality. LightingStyle was Soft (flat light, weak shadows) and was the real cause of weak shadows; set to Realistic 2026-10-15 (Old_Shadow_LightingStyle attr). Also: near-black surfaces hide shadows, so big surfaces were lifted to ~56,42,96. Original note: Technology does not exist in the owner's Studio (unified lighting; scripts can't even read it). Owner was annoyed at being asked again (2026-10-15). Shadow strength has to come from Ambient/OutdoorAmbient, EnvironmentDiffuseScale, ShadowSoftness, light Shadows flags, fewer Neon surfaces.

Play-mode screen_capture returned pure white frames repeatedly on 2026-10-15 and the retries made Studio lag; owner interrupted. Don't loop on retries: after one white capture, stop play and use edit-mode captures.

**Why:** owner said "we've discussed this, there isn't a technology option" and "you lagged".
**How to apply:** never ask about Technology; keep screenshots few. See [[strike-legends-progress]].

2026-10-15: owner said the shadow pass "was reversed" after a play test, but the Edit DataModel still had every change. Likely cause: my test captures forced settings().Rendering.QualityLevel=Level21 on the client only, while the owner's Studio was on Automatic (low) quality, which drops local-light shadows and makes Realistic look flat. Set settings().Rendering QualityLevel + EditQualityLevel = Level21 from Edit, and Lighting.PrioritizeLightingQuality = true. Always verify looks at the owner's actual quality, not a forced one.

2026-10-22: dimmed per owner ("a tad too bright"): Exposure 0.15->0, bloom 0.3, lights x0.85 (Old_*_20261022 attrs), Config.BallVfx.Dim 0.8 for ball effects. Play-mode screen_capture showed GUI over plain grey: no 3D world and NO ViewportFrame contents, so crate/ball viewports can't be checked by capture; verify numerically and let the owner look.
