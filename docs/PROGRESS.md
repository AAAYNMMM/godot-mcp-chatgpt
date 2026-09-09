# Development Progress

## Project

- Repository: `AAAYNMMM/godot-mcp-chatgpt`
- Branch: `main`
- Visibility: public
- Target editor: Godot 4.7.2 Standard x64 / GDScript
- Goal: Web ChatGPT -> remote MCP -> Godot Editor
- Finished product must not depend on CWapi.

## Current architecture decision

On 2026-09-09 the architecture was simplified.

**Do not preserve the upstream local MCP connection path.**

Current target:

```text
Web ChatGPT
  -> Streamable HTTP MCP relay
  -> Tunnel ID + API Key routing
  -> outbound WSS from Godot addon
  -> direct Godot command registry
  -> Godot Editor APIs
```

Normal users should only enter:

1. Tunnel ID
2. API Key

The release build owns the relay URL internally.

## Completed

### Repository bootstrap

- Public repository created.
- Continuity/development docs created.
- MCPcoding durable workspace established.
- Windows global `gh` login reuse was verified earlier.

### Upstream audit

Inspected on 2026-09-09:

- `NPGameDev/godot-mcp-toolkit`
- `NPGameDev/godot-mcp-server`

Both contain MIT licenses with copyright `2026 NPGameDev` and an explicit note that project logo/banner/name branding is not licensed for reuse.

Decision:

- reuse/migrate selected Godot editor command behavior from toolkit as needed;
- do not migrate the local stdio MCP/Node/localhost bridge architecture;
- create third-party notices when source code is actually copied.

### Direct Web client skeleton

Created:

- `addons/godot_mcp_chatgpt/plugin.cfg`
- `addons/godot_mcp_chatgpt/plugin.gd`
- `addons/godot_mcp_chatgpt/ui/connection_dock.gd`
- `addons/godot_mcp_chatgpt/web/web_mcp_client.gd`
- `addons/godot_mcp_chatgpt/core/command_registry.gd`
- `addons/godot_mcp_chatgpt/core/builtin_commands.gd`
- root `project.godot` development fixture
- `.gitignore` excluding `.upstream/` and `.godot/`

Implemented behavior:

- Godot dock with Tunnel ID and masked API Key fields;
- Connect/Disconnect button and connection state;
- editor-local credential persistence;
- relay URL hidden from normal UI;
- dev relay URL override through `GODOT_MCP_CHATGPT_RELAY_URL` or ProjectSettings;
- outbound `WebSocketPeer` connection;
- automatic reconnect after transient disconnect;
- registration frame containing tool catalogue;
- `registered`, `tool_call`, `tool_result`, `ping/pong`, fatal error handling;
- serial request queue;
- two minimal read-only commands: `godot.get_status` and `project.get_info`.

### Godot validation

Command run successfully:

```text
C:\Users\11830\AppData\Local\Programs\Godot\4.7.2\godot.exe --headless --editor --path . --quit
```

Result:

- exit code 0;
- plugin initialized during editor startup;
- no GDScript parse/startup error was emitted.

## Important design details

- No local MCP server is planned.
- No stdio transport is planned.
- No local Node bridge is planned.
- No Godot localhost listener is planned for the editor-control path.
- The addon connects outward to the relay.
- The relay is the MCP server that Web ChatGPT sees.
- Tool schemas are supplied by the connected Godot addon during registration.

## Current limitations / not yet implemented

- No public relay exists yet in this repository.
- No end-to-end WSS integration test yet.
- Only two minimal test commands exist.
- Upstream Godot command modules have not yet been copied/migrated.
- API key is currently stored in editor-local EditorSettings; release security storage needs review.
- No cancellation/request timeout protocol yet.

## Next exact task

1. Build a small fake WSS relay test harness.
2. Start the addon against it using `GODOT_MCP_CHATGPT_RELAY_URL`.
3. Verify full frame flow:
   - register
   - registered
   - tool_call `godot.get_status`
   - tool_result
4. Then migrate/reimplement scene and node commands from the upstream toolkit.
5. Add attribution files when the first upstream source is copied.

## MCPcoding continuation notes

Repository URL for coding workspace:

```text
https://github.com/AAAYNMMM/godot-mcp-chatgpt
```

Target ref:

```text
main
```

Do not work in `DragonSouls` for this project.

If `gh` inside MCPcoding does not see the user's normal Windows login, the user's global GitHub CLI config was previously found at:

```text
C:\Users\11830\AppData\Roaming\GitHub CLI
```

The temporary upstream audit clones live under `.upstream/` and are intentionally gitignored.
