# godot-mcp-chatgpt

Web ChatGPT control for the Godot editor through **OpenAI Secure MCP Tunnel**.

The user-facing flow is intentionally small: enable the Godot addon, enter an OpenAI **Tunnel ID** and **Runtime API Key**, then press **Connect**.

## Runtime architecture

```text
Web ChatGPT
    |
    | MCP JSON-RPC through OpenAI Secure MCP Tunnel
    v
OpenAI tunnel service
    |
    v
official tunnel-client.exe (bundled child process)
    |
    | Streamable HTTP MCP on 127.0.0.1
    v
Godot MCP ChatGPT addon
    |
    | in-process command dispatch
    v
Godot Editor API
```

This is intentionally the same connection pattern that is already proven in CWapi: the project does **not** reimplement OpenAI's tunnel wire protocol. The official `tunnel-client` owns the tunnel/control-plane behavior and forwards MCP to a loopback Streamable HTTP server hosted by the Godot addon.

There is no custom public relay, no stdio MCP runtime, no Node bridge in production, and no localhost WebSocket bridge.

## Current status

Development version: `0.3.0`

Current development target:

- Windows x64
- Godot `4.7.2 Standard x64`
- GDScript
- Compatibility Renderer fixture
- bundled OpenAI `tunnel-client` `0.0.10+105e17a79a36e4e5c897fd698ed2b8dbf935b144`

Current tool set (13 tools):

- `godot.get_status`
- `project.get_info`
- `scene.create`
- `scene.get_tree`
- `scene.save`
- `node.create`
- `node.set_property`
- `node.delete`
- `script.write`
- `script.read`
- `script.attach`
- `editor.run_project`
- `editor.stop`

The production path has passed a real Godot 4.7.2 GUI smoke test using the same official `tunnel-client.exe` used by the user's working CWapi installation. The test covered `server/discover`, MCP initialization, tool discovery, tool calls, scene/node/script mutations, save/readback, and session termination.

## Install

Copy this folder into a Godot project:

```text
addons/godot_mcp_chatgpt/
```

Enable **Godot MCP ChatGPT** under **Project > Project Settings > Plugins**.

A bottom panel named **MCP ChatGPT** appears next to Godot's Output/Debugger panels. It contains:

- Tunnel ID
- Runtime API Key
- Connect / Disconnect
- connection status/log message

The Windows development build already contains the required official `tunnel-client.exe`; users do not need CWapi, Node.js, Codex, or another MCP client to run the addon.

## Real OpenAI Tunnel setup

1. Create or select an OpenAI Secure MCP Tunnel.
2. Create a restricted Runtime API Key with the required tunnel permissions.
3. Enter the Tunnel ID and Runtime API Key in the Godot **MCP ChatGPT** panel.
4. Press **Connect**.
5. In ChatGPT, create/configure a connector using **Connection: Tunnel** and the same Tunnel ID.
6. Discover and call the Godot tools while the editor remains open.

See [`docs/SECURE_TUNNEL.md`](docs/SECURE_TUNNEL.md) for the real-test handoff.

## Security notes

- The addon persists only the Tunnel ID in Godot `EditorSettings`.
- The Runtime API Key is not written into the generated tunnel profile; the profile references `env:CONTROL_PLANE_API_KEY`.
- The key is injected only for starting the official tunnel-client child process and is then removed from the Godot process environment.
- The local MCP server binds only to `127.0.0.1`, chooses a random high port, and uses a random per-run URL path.
- File tools are constrained to `res://` and reject path traversal.
- `scene.create` refuses to overwrite an existing scene unless `overwrite: true` is explicitly supplied.
- Use a dedicated restricted runtime key rather than an admin key.

## Bundled third-party runtime

The addon bundles the official OpenAI `tunnel-client` Windows executable under:

```text
addons/godot_mcp_chatgpt/bin/windows/tunnel-client.exe
```

The corresponding Apache-2.0 license and NOTICE are kept beside the addon runtime under `addons/godot_mcp_chatgpt/bin/`. See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

## Repository layout

```text
addons/godot_mcp_chatgpt/
  core/                     Godot command registry + tools
  ui/                       connection panel
  web/local_mcp_server.gd   loopback Streamable HTTP MCP server
  web/tunnel_client_runner.gd
                             official tunnel-client process/profile manager
  bin/                      bundled tunnel-client + license notices

docs/                       architecture, plan, progress, real-test docs
server/                     development-only control-plane test harness
```

`server/` is ignored by Godot and is not required by end users.

## Development checks

```text
cd server
npm install
npm run build
npm test
```

The production smoke additionally launches a real Godot GUI editor and routes the simulated control plane through the bundled official tunnel-client before calling the real Godot tools.

Before continuing development in another ChatGPT window, read [`docs/PROGRESS.md`](docs/PROGRESS.md).