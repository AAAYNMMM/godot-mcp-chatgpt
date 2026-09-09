# Development Progress

## Project

- Repository: `AAAYNMMM/godot-mcp-chatgpt`
- Branch: `main`
- Visibility: public
- Target: Godot 4.7.2 Standard x64 / GDScript
- Production dependency: Godot editor only
- Runtime architecture: direct OpenAI Secure MCP Tunnel protocol

## Current state — 2026-09-09

The project is at **Phase 4: real OpenAI control-plane / ChatGPT test**.

All work that can be completed without the user's real OpenAI Tunnel ID and Runtime API Key has been exercised locally.

## Completed architecture pivot

Earlier in development a custom remote MCP Relay was implemented:

```text
ChatGPT -> Streamable HTTP relay -> WSS -> Godot
```

That implementation successfully controlled a real Godot editor, but it is no longer the production architecture.

After reviewing the public `openai/tunnel-client` project and wire protocol, the final path became:

```text
ChatGPT
  -> OpenAI Secure MCP Tunnel
  -> secure_tunnel_client.gd
  -> CommandRegistry
  -> Godot Editor
```

The custom relay runtime was removed. Do not bring it back by default.

## Production addon implemented

Key files:

```text
addons/godot_mcp_chatgpt/plugin.cfg
addons/godot_mcp_chatgpt/plugin.gd
addons/godot_mcp_chatgpt/ui/connection_dock.gd
addons/godot_mcp_chatgpt/web/secure_tunnel_client.gd
addons/godot_mcp_chatgpt/core/command_registry.gd
addons/godot_mcp_chatgpt/core/builtin_commands.gd
```

The dock accepts only:

- OpenAI Tunnel ID
- Runtime API Key

The production client defaults to:

```text
https://api.openai.com
```

A local control-plane override exists only through:

```text
GODOT_MCP_CHATGPT_CONTROL_PLANE_URL
```

for automated protocol testing.

## Secure Tunnel protocol behavior implemented

- bearer auth on every request;
- `X-Tunnel-Client-Name`;
- `X-Tunnel-Client-Version`;
- `X-Tunnel-Client-Wire-Protocol-Version: 2026-08-25`;
- per-process `X-Tunnel-Client-Instance-Id`;
- `X-Tunnel-MCP-Server-Info` main channel with `proc_affinity: true`;
- tunnel metadata check;
- long polling `/poll`;
- posting `/response`;
- `X-Tunnel-Shard-Token` correlation;
- sequential command processing;
- bounded exponential retry with jitter;
- 401/403 -> authentication failure state;
- 404 tunnel-not-found handling;
- `response_timeout` parsing and expired-command drop;
- session termination ACK;
- notification ACK.

## MCP behavior implemented in-process

- `initialize`;
- `ping`;
- `tools/list`;
- `tools/call`;
- JSON-RPC method-not-found / invalid-request handling;
- no-ID notification handling.

## Current tools

13 tools are exposed and have been exercised through the tunnel protocol:

```text
godot.get_status
project.get_info
scene.get_tree
scene.create
scene.save
node.create
node.set_property
node.delete
script.read
script.write
script.attach
editor.run_project
editor.stop
```

Notable safety behavior:

- `scene.create` requires explicit `overwrite: true` when target exists;
- script/file paths are constrained to `res://` and reject `..` traversal;
- scene root deletion is denied;
- destructive annotations are emitted to MCP.

## Bugs found by real Godot testing

### Plugin silently not instantiating

Root cause: `plugin.cfg` had a UTF-8 BOM from an early PowerShell write. Godot scanned/loaded scripts but did not instantiate the EditorPlugin correctly.

Fix: addon/config files are UTF-8 without BOM.

### False-positive script validation

`godot --editor --quit` did not force compile every plugin dependency. A dedicated `.local-test/check_scripts.gd` loader now forces all addon scripts to compile under Godot 4.7.2.

This caught and fixed:

- invalid two-argument `EditorSettings.get_setting()` usage;
- a strict type inference issue in the dock.

### Godot scanning Node dependencies

Root cause: repository development project saw `server/node_modules` as project resources.

Fix: `server/.gdignore`. Upstream audit clones are also hidden from Godot scanning locally.

### Recreating an already-open scene

Root cause: writing a scene file then calling `open_scene_from_path()` on the same already-open path did not refresh the in-memory editor tab. Repeated smoke tests produced duplicate/generated node names.

Fix:

- default deny overwrite;
- explicit `overwrite: true`;
- close the open target scene tab on Godot 4.5+;
- reopen the freshly written scene deferred by one editor frame.

Repeated real-Godot smoke runs then passed.

## Automated validation completed

### Godot script compilation

Godot 4.7.2 successfully loads:

```text
plugin.gd
command_registry.gd
builtin_commands.gd
connection_dock.gd
secure_tunnel_client.gd
```

with no parse/compile errors.

### Test-harness build/unit test

```text
cd server
npm run build
npm test
```

Passes contract checks for:

- authorization;
- required tunnel client headers;
- server-info declaration;
- command queueing;
- request/shard correlation;
- response delivery.

### Real Godot GUI + Secure Tunnel protocol smoke

A real Godot 4.7.2 GUI editor connected to the local OpenAI Tunnel protocol simulator and successfully executed:

1. tunnel metadata validation;
2. long poll;
3. MCP initialize;
4. initialized notification ACK;
5. tools/list;
6. godot.get_status;
7. scene.create;
8. node.create;
9. node.set_property Vector3;
10. script.write;
11. script.read;
12. script.attach;
13. scene.save;
14. scene.get_tree readback;
15. tunnel session termination;
16. `response_timeout: 0s` drop with no late response.

Latest smoke result:

```json
{
  "ok": true,
  "transport": "openai-secure-mcp-tunnel-protocol",
  "godot": "4.7.2-stable (official)",
  "tools": 13,
  "scene": "res://.mcp-smoke/secure-generated.tscn",
  "player": {
    "__godot_type": "Vector3",
    "x": 4,
    "y": 5,
    "z": 6
  }
}
```

## Development-only test harness

`server/` now contains only a local Secure Tunnel control-plane simulator and tests. It is not production runtime code.


## Validated implementation baseline

Validated implementation commit:

```text
628dceee2a19bcc3768c86c7d09cc6147816755d
```

This commit passed Godot 4.7.2 script compilation, Secure Tunnel contract tests, and a real Godot GUI Secure Tunnel protocol smoke test before commit.

## Next exact task — requires user operation

Perform the first real OpenAI control-plane test.

The user must supply/use their own real credentials through the UI; do not request that they paste the Runtime API Key into chat.

Steps:

1. Create/select a tunnel at OpenAI Platform Tunnels management.
2. Create a restricted Runtime API Key with Tunnels Read + Use.
3. Open the test Godot project/plugin.
4. Paste Tunnel ID + Runtime API Key into the Godot dock locally and press Connect.
5. Confirm dock becomes `connected`.
6. Open ChatGPT connector settings.
7. Choose `Connection: Tunnel` and select/paste the same tunnel ID.
8. Let ChatGPT discover the tools.
9. First call `godot.get_status`.
10. Then create a disposable scene and node to verify a visible write action.

See `docs/SECURE_TUNNEL.md`.

## After real test passes

- remove any protocol incompatibility found against the live service;
- expand high-value Godot tools;
- evaluate optional OS-keychain integration without ever falling back to plaintext API-key persistence;
- package an installable addon release;
- add compatibility tests for additional Godot 4.x versions.

## MCPcoding continuation

Repository:

```text
https://github.com/AAAYNMMM/godot-mcp-chatgpt
```

Branch:

```text
main
```

Do not work in DragonSouls for this project.

Temporary upstream audit clones live in `.upstream/` and are gitignored.
