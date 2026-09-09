# godot-mcp-chatgpt

Direct Web ChatGPT control for the Godot editor through **OpenAI Secure MCP Tunnel**.

The normal user experience is intentionally small: install the Godot addon, enable it, then enter an OpenAI **Tunnel ID** and **Runtime API Key** in the Godot dock.

## Runtime architecture

```text
Web ChatGPT
    |
    | MCP JSON-RPC
    v
OpenAI Secure MCP Tunnel
    |
    | outbound HTTPS long-poll + response POST
    v
Godot MCP ChatGPT addon
    |
    | direct in-process command dispatch
    v
Godot Editor API
```

There is **no local MCP server**, **no stdio transport**, **no Node bridge**, **no localhost WebSocket listener**, and **no project-hosted public relay** in the production path.

## Current status

Development version: `0.2.2`

Validated with:

- Godot `4.7.2 Standard x64`
- GDScript
- Compatibility Renderer development fixture
- OpenAI Secure MCP Tunnel wire contract `2026-08-25`
- real Godot GUI editor process, not only headless parsing

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

The direct tunnel path has passed a local control-plane simulation that performs MCP `initialize`, `notifications/initialized`, `tools/list`, `tools/call`, scene/node/script mutations, save/readback, session termination, protocol-header validation, correlation validation, and response-deadline handling against a real Godot 4.7.2 editor.

## Install for development

Copy or place this addon in a Godot project:

```text
addons/godot_mcp_chatgpt/
```

Then enable **Godot MCP ChatGPT** under **Project > Project Settings > Plugins**.

A bottom panel named **MCP ChatGPT** appears alongside Godot’s Output/Debugger panels. It opens automatically in the development fixture and contains only:

- Tunnel ID
- Runtime API Key
- Connect / Disconnect
- connection status

## Real OpenAI Tunnel setup

1. Create or select a tunnel in OpenAI Platform Tunnels management.
2. Create a **Restricted Runtime API Key** with Tunnels **Read + Use** permissions.
3. Enter the Tunnel ID and Runtime API Key in the Godot dock and press **Connect**.
4. In ChatGPT connector settings, choose **Connection: Tunnel** and select/paste the same tunnel ID.
5. Scan/use the tools from ChatGPT while the Godot editor remains open.

See [`docs/SECURE_TUNNEL.md`](docs/SECURE_TUNNEL.md) for the exact test flow and current OpenAI setup links.

> Availability of custom/full MCP and Tunnel connection UI depends on the OpenAI product, plan, workspace permissions, and rollout state.

## Security notes

- The Runtime API Key is sent only to the configured OpenAI control-plane host (`https://api.openai.com` by default).
- The addon does not expose an inbound network listener.
- Use a dedicated restricted runtime key, not an admin key.
- The addon stores only the Tunnel ID in Godot `EditorSettings`. The Runtime API Key is kept in memory for the current editor session and is not persisted by the addon.
- Tool file operations are currently constrained to `res://` and reject `..` traversal.
- `scene.create` refuses to overwrite an existing scene unless `overwrite: true` is explicitly supplied.

## Repository layout

```text
addons/godot_mcp_chatgpt/   Production Godot addon
  core/                     Godot command registry + tools
  ui/                       Tunnel control dock
  web/secure_tunnel_client.gd
                             Direct OpenAI Secure MCP Tunnel client

docs/                       Architecture, plan, progress, setup docs
server/                     Local protocol test harness ONLY
                             (ignored by Godot via .gdignore)
```

`server/` is not required by end users and is not part of the production connection path.

## Development checks

TypeScript test-harness checks:

```text
cd server
npm install
npm run build
npm test
```

Real Godot tunnel-protocol smoke testing additionally runs a Godot GUI editor against the local Secure Tunnel protocol stub and then executes:

```text
npm run test:secure-godot
```

See [`docs/PROGRESS.md`](docs/PROGRESS.md) before continuing development in another ChatGPT window.
