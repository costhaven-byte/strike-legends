---
name: rojo-sync-gotchas
description: "Rojo pitfalls hit on Strike Legends — script injection permission, and duplicate instances after bulk file rewrites"
metadata:
  node_type: memory
  type: project
  originSessionId: 4354561b-4c3e-4403-8df3-317c374bb8d1
  modified: 2026-10-13T23:56:21.632Z
---

Two Rojo problems seen 2026-10-14 on Strike Legends ([[strike-legends-setup]]):

1. Plugin "Rojo" needs Script Injection permission (Plugins → Manage Plugins → Rojo). Without it, sync silently half-applies; the error shows in get_console_output.
2. Creating a NEW .luau file (with the Write tool) while Rojo is connected creates a duplicate ModuleScript in Studio — happened every time, not just after stylua. Editing existing files is fine. Fix: user clicks Disconnect → Connect in the Rojo panel. Creating files via Bash heredoc does NOT avoid it (tested 2026-10-14, M3: 2 of 3 new files duplicated). Best plan: create all new files first, then ask for one reconnect. Faster fix that worked 2026-10-14 (M9.5b): destroy the extra copy via MCP execute_luau in Edit mode; Rojo keeps syncing the remaining one (verified by editing the file).

**Why:** duplicates would make the server start services twice.
**How to apply:** use `stylua --check` while connected (or format before the user connects), and after code changes list the descendants of Shared/Server/Client in Studio to check for duplicates before play-testing. The user can't run Rojo themselves, so start `rojo serve` (~/.rokit/bin) in the background each session and ask them to click Connect.

3. 2026-10-22: old `python -m http.server 34999` processes from earlier sessions stay running and answer for the wrong folder (404s). Use a fresh port (35123 worked) for the http sync trick.
