---
name: ui-batch-1
description: Owner's first batch of 2D UI designs (power meter, charge zones, result text, payout pop) and how they were pulled in
metadata:
  type: project
---
2026-10-22: owner said "first batch of UIs available, pull them in from your browser tab". No tab was actually open; the designs were the newest projects at claude.ai/design (list shows them; DesignSync list_files/get_file reads them even though they aren't design-system projects). Batch 1 = Strike Legends power meter (170d4434...), charge meter zones (b7ef8d25...), result text (ed303fe4...), Payout Pop (4e2d793e...; components PayoutBadge, FloatNumber). Built in code as commit e73edd0 (restore tag restore-ui-batch1-before), test pending.

Gotchas: Roblox has no Rubik / Lilita One / JetBrains Mono (stand-ins Montserrat Heavy Italic, Fredoka One, Roboto Mono). CSS -webkit-text-stroke with paint-order is centred, so a UIStroke should be HALF the design's stroke width. Expect more batches; same pipeline ([[feedback-literal-specs]]).

2026-10-22: owner PASSED batch 1 but said texts overlapped on strikes. 082f763 shrank them (ResultSizes, PayoutPopScale 0.75, NumberPopSize 22, NumberPopRise 60, trait popups 30) and moved ResultText up / RewardPopup down in StarterGui. Rojo was not connected; synced with the http.server trick. Studio play captures do not show the 3D pin-number billboards.
