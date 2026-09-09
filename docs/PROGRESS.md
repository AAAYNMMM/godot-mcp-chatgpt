# Development Progress / Handoff

Last updated: 2026-09-09

Repository: `AAAYNMMM/godot-mcp-chatgpt`

Branch: `main`

Current release candidate: `0.3.0`

## Current architecture — DO NOT MISS THIS

The production connection path is now:

```text
Web ChatGPT
  -> OpenAI Secure MCP Tunnel
  -> official bundled OpenAI tunnel-client.exe
  -> Godot loopback Streamable HTTP MCP
  -> Godot CommandRegistry
  -> Godot Editor API
```

This replaced the earlier direct GDScript `/poll` + `/response` implementation.

Reason: the earlier direct implementation reached `Status: connected` but ChatGPT connector creation failed. The user's working CWapi installation was inspected and showed that CWapi does **not** implement the tunnel wire protocol itself. CWapi launches the official `tunnel-client` and points it at a localhost Streamable HTTP MCP server. Version 0.3.0 adopts the same proven pattern.

Do not restore the old direct tunnel client without explicitly revisiting this decision.

## Current user experience

Godot bottom panel: **MCP ChatGPT**

User enters only:

```text
Tunnel ID
Runtime API Key
```

Then presses **Connect**.

The addon automatically:

1. starts a loopback MCP server on `127.0.0.1` using a random high port;
2. generates a random MCP path token;
3. writes a tunnel-client profile;
4. references the key as `env:CONTROL_PLANE_API_KEY` in that profile;
5. starts the bundled official tunnel-client;
6. clears the key from the parent Godot process environment after child creation.

Only Tunnel ID is persisted in Godot EditorSettings.

## Bundled official runtime

Windows executable:

```text
addons/godot_mcp_chatgpt/bin/windows/tunnel-client.exe
```

Runtime identity:

```text
0.0.10+105e17a79a36e4e5c897fd698ed2b8dbf935b144
```

SHA-256:

```text
D893D8127EEE35070D265C1BE29BFE008F8D9FCB476E7FEBF56C8FDC6C0615C8
```

This is the same tunnel-client binary currently used by the user's functioning CWapi installation during validation.

Apache-2.0 LICENSE and NOTICE are included under `addons/godot_mcp_chatgpt/bin/`.

## Current Godot tools

13 tools are implemented:

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

## Important implementation files

```text
addons/godot_mcp_chatgpt/plugin.gd
addons/godot_mcp_chatgpt/ui/connection_dock.gd
addons/godot_mcp_chatgpt/web/tunnel_client_runner.gd
addons/godot_mcp_chatgpt/web/local_mcp_server.gd
addons/godot_mcp_chatgpt/core/command_registry.gd
addons/godot_mcp_chatgpt/core/builtin_commands.gd
```

Development-only control-plane simulator:

```text
server/
```

The old production `secure_tunnel_client.gd` direct-wire client was removed for 0.3.0.

## Tests already passed during 0.3.0 work

### 1. Godot 4.7.2 script compilation

All addon scripts loaded successfully under:

```text
C:\Users\11830\AppData\Local\Programs\Godot\4.7.2\godot.exe
```

### 2. Godot local MCP direct test

The loopback server handled:

```text
server/discover
initialize
tools/list
tools/call
```

### 3. Go MCP SDK 1.7 compatibility

A real `github.com/modelcontextprotocol/go-sdk v1.7.0` client connected to the Godot loopback MCP and successfully listed/called a tool.

Result:

```text
GO_SDK_SMOKE_OK
```

### 4. Official tunnel-client bridge test

A local control-plane stub routed requests through the same official `tunnel-client.exe` used by CWapi into Godot MCP.

Result:

```text
OFFICIAL_TUNNEL_BRIDGE=PASS
```

The returned result confirmed Godot `4.7.2-stable (official)`.

### 5. Production plugin smoke

A real Godot 4.7.2 GUI editor loaded the production addon with the bundled official tunnel-client. The simulated OpenAI control plane then executed:

```text
server/discover
initialize
notifications/initialized
tools/list
godot.get_status
scene.create
node.create
node.set_property
script.write
script.read
script.attach
scene.save
scene.get_tree
session termination
```

Result:

```text
PRODUCTION_PLUGIN_SMOKE=PASS
```

13 tools were discovered. The test created a disposable scene and verified `Player.position == Vector3(4, 5, 6)`.

## Compatibility details discovered

- Official tunnel-client performs an OAuth `WWW-Authenticate` probe against the local MCP URL. An empty POST during startup is therefore not necessarily an MCP JSON request.
- Official Go MCP SDK 1.7 probes `server/discover` before legacy initialize.
- Local Streamable HTTP session termination arrives as HTTP `DELETE` and must return success; the stateless Godot MCP returns 204.
- Notifications sent through the official tunnel path preserve the local MCP HTTP acknowledgement rather than the old direct-wire test assumptions.
- The bundled 0.0.10 tunnel-client predates some newer tunnel client headers. The development control-plane stub must remain backward compatible rather than requiring only the newest wire headers.

## Current blocker

No automated/local blocker remains for the 0.3.0 architecture.

The next meaningful test requires the user's real OpenAI Tunnel ID / Runtime API Key and ChatGPT connector UI.

## Exact next task

After the 0.3.0 commit is pushed:

1. reopen the Godot development project;
2. user enters the real Runtime API Key again (it is intentionally not persisted);
3. confirm `Status: connected` / official tunnel-client running;
4. create the ChatGPT connector with the same Tunnel ID;
5. verify connector creation succeeds;
6. from ChatGPT call `godot.get_status`;
7. then create a disposable visible scene/node through the real connector.

If connector creation still fails, inspect the official tunnel-client health/readiness/log output before changing architecture again.

## Repository/workspace notes

- Work only in `AAAYNMMM/godot-mcp-chatgpt` for this project.
- Do not modify CWapi; it was inspected read-only to understand the known-good tunnel integration pattern.
- The user's global GitHub CLI authentication is under their Windows user profile and can be reused if MCPcoding does not inherit it automatically.
- Godot development target is currently Windows + Godot 4.7.2 Standard + GDScript.