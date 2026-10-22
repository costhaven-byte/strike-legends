---
name: strike-legends-setup
description: "Strike Legends Roblox game — Claude does ALL building (code + maps/UI); user only gives prompts/designs. Rojo for code, Studio MCP for building."
metadata:
  node_type: memory
  type: project
  originSessionId: 6e3660b0-c55c-4f92-bb69-0b2926ca2f62
  modified: 2026-10-13T23:09:42.862Z
---

Strike Legends (Roblox game), set up 2026-10-14. The user hands off prompts and designs; Claude does all the building (scripts, maps, models, UI) and the user watches the changes appear live in Roblox Studio.

Tooling: Rokit (~/.rokit/bin, may need adding to PATH), Rojo 7.7.1, Wally, Selene, StyLua, VS Code + Luau LSP. Roblox's built-in Studio MCP server is registered in the project's .mcp.json as `Roblox_Studio` (cmd /c %LOCALAPPDATA%\Roblox\mcp.bat). The user has to turn it on in Studio: Assistant → … → Manage MCP Servers → Enable Studio as MCP server.

Split: code lives in src/ and syncs through Rojo (git-tracked). Rojo only manages ServerScriptService.Server, StarterPlayerScripts.Client, ReplicatedStorage.Shared/Packages and ServerStorage.ServerPackages. Maps, lighting, models and UI get built directly in Studio through the MCP (execute_luau, insert_asset, generate_*), then checked with screen_capture.

**Why:** Rojo overwrites anything in the folders it manages, so script edits made through the MCP inside those folders would be lost.
**How to apply:** edit Rojo-managed scripts as files, never through MCP multi_edit. Build the world through the MCP. Server modules go in src/server/Services and client modules in src/client/Controllers, each returning a table with a Start method (the init scripts auto-load them). Remind the user to save the place in Studio, since map work isn't in git.
