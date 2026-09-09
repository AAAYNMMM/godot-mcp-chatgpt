# Development Plan

## 1. Product definition

`godot-mcp-chatgpt` is a Godot Editor addon for direct Web ChatGPT control through remote MCP.

The project intentionally **does not keep the upstream local-MCP architecture**. There is no user-facing stdio MCP server, no Node process launched beside Godot, no localhost MCP bridge, and no local MCP client configuration.

Final user flow:

```text
Godot Editor
  -> install/enable addon
  -> enter Tunnel ID
  -> enter API Key
  -> Connect
```

Everything else is internal.

## 2. Target architecture

```text
Web ChatGPT
    |
    | MCP over HTTPS / Streamable HTTP
    v
Web MCP relay
    |
    | authenticated tunnel routing
    | tunnel_id + api_key
    v
Godot addon outbound WSS client
    |
    | direct command dispatch
    v
Godot Editor API
```

The relay is the MCP server seen by Web ChatGPT. The Godot addon is an outbound tunnel client and command executor.

The old upstream path is explicitly removed:

```text
Codex/Claude/Cursor
  -> stdio MCP server
  -> Node bridge
  -> localhost WebSocket
  -> Godot addon
```

We do not preserve that path for compatibility.

## 3. User-facing scope

The normal control panel should expose only:

- Tunnel ID
- API Key
- Connect / Disconnect
- connection status
- concise diagnostics

The relay URL is not a normal user setting. Release builds provide it internally. Development builds may override it with `GODOT_MCP_CHATGPT_RELAY_URL` or `godot_mcp_chatgpt/relay_url`.

## 4. Components

### 4.1 Godot control panel

Responsibilities:

- accept Tunnel ID and API Key;
- save them in editor-local settings, never the project repository;
- start/stop the remote connection;
- show connection/auth/reconnect state;
- avoid logging the API key.

### 4.2 Web MCP client script

Responsibilities:

- create an outbound WSS connection to the relay;
- authenticate with Tunnel ID + API Key;
- reconnect after transient disconnects;
- publish the Godot tool catalogue to the relay;
- receive remote tool calls;
- execute them through the local command registry;
- return structured tool results/errors;
- answer relay heartbeat messages.

### 4.3 Godot command registry

Responsibilities:

- define command names, descriptions, JSON input schemas, annotations and handlers;
- expose a compact catalogue for remote MCP `tools/list`;
- validate/routinely guard Godot operations;
- execute calls in a deterministic order where mutations require serialization.

### 4.4 Web MCP relay

Responsibilities:

- expose the MCP endpoint Web ChatGPT connects to;
- authenticate the caller using Tunnel ID + API Key;
- map a tunnel to exactly one connected Godot addon instance;
- translate MCP `tools/list` to the catalogue registered by that Godot instance;
- translate MCP `tools/call` to tunnel `tool_call` messages;
- correlate `tool_result` messages with the original MCP request;
- enforce request size/time/rate limits;
- never route requests between tunnels.

The relay can be implemented later without changing the editor UX or command layer because the addon uses a small versioned tunnel protocol.

## 5. Tunnel protocol v1

Addon registration:

```json
{
  "type": "register",
  "protocol": "godot-mcp-chatgpt/1",
  "tunnel_id": "godot_xxx",
  "api_key": "gdmcp_xxx",
  "client": {
    "plugin_version": "0.1.0",
    "godot_version": "4.7.2",
    "project_name": "Example"
  },
  "tools": []
}
```

Relay acknowledgement:

```json
{"type":"registered"}
```

Tool call:

```json
{
  "type": "tool_call",
  "request_id": "...",
  "name": "project.get_info",
  "arguments": {}
}
```

Tool result:

```json
{
  "type": "tool_result",
  "request_id": "...",
  "ok": true,
  "result": {}
}
```

Heartbeat:

```json
{"type":"ping","ts":123}
{"type":"pong","ts":123}
```

Fatal authentication errors use an `error` frame with `fatal: true` and must stop automatic reconnect until the user changes credentials or reconnects manually.

## 6. Upstream migration policy

Repositories evaluated:

- `NPGameDev/godot-mcp-toolkit` — MIT
- `NPGameDev/godot-mcp-server` — MIT

Both licenses were verified in-repository on 2026-09-09. Upstream branding/artwork is excluded from the MIT grant and must not be copied.

### Keep/migrate from `godot-mcp-toolkit`

Primarily editor-side behavior:

- command implementations;
- command contracts/schemas;
- safe scene operations;
- path/security guards;
- playtest/editor diagnostics;
- selected command-registry behavior;
- selected dock UX ideas when useful.

### Do not migrate from `godot-mcp-server` as runtime architecture

The following are intentionally obsolete for this project:

- `StdioServerTransport` startup path;
- local Node MCP process;
- localhost bridge client;
- editor port scanning/discovery;
- local token files used only for Node-to-Godot auth;
- local `.mcp.json` client setup;
- local MCP compatibility machinery.

Server-side tool schemas/metadata can still be consulted when they help define the Web tool catalogue, but the local server itself is not a product component.

## 7. Current repository layout

```text
godot-mcp-chatgpt/
├─ addons/
│  └─ godot_mcp_chatgpt/
│     ├─ plugin.cfg
│     ├─ plugin.gd
│     ├─ core/
│     │  ├─ command_registry.gd
│     │  └─ builtin_commands.gd
│     ├─ ui/
│     │  └─ connection_dock.gd
│     └─ web/
│        └─ web_mcp_client.gd
├─ docs/
│  ├─ DEVELOPMENT_PLAN.md
│  └─ PROGRESS.md
├─ project.godot
└─ README.md
```

The repository root is also a minimal Godot development project so the addon can be loaded and validated directly with Godot CLI.

## 8. Development phases

### Phase 0 — repository + continuity docs

Status: complete.

### Phase 1 — direct Web client skeleton

Deliverables:

- addon loads in Godot 4.7.2;
- Tunnel ID/API Key dock;
- credentials stored editor-locally;
- outbound WSS connection;
- reconnect state machine;
- tool catalogue registration;
- tool-call/result framing;
- minimal command registry;
- at least two read-only test commands.

Status: implemented; relay end-to-end test remains.

### Phase 2 — migrate useful Godot commands

Migrate/reimplement the editor operations that matter most:

1. scene inspect/open/save;
2. node create/update/delete/query;
3. script create/read/update/attach;
4. play/stop and errors;
5. resources and project settings;
6. ClassDB lookup.

Do not blindly copy the full upstream surface. Prefer a smaller Web-GPT-friendly catalogue and add advanced categories after the core path works.

### Phase 3 — Web MCP relay

Implement the public relay that exposes Streamable HTTP MCP and translates to the v1 WSS tunnel protocol.

Acceptance:

- Web MCP client sees tools supplied by the connected Godot instance;
- valid Tunnel ID + API Key invokes `godot.get_status` and `project.get_info`;
- invalid credentials fail;
- two tunnels cannot cross-route requests.

### Phase 4 — integration + hardening

- cancellation/timeouts;
- request size limits;
- API key rotation;
- heartbeat timeout;
- permission profile if needed;
- safe path enforcement;
- mutation serialization;
- relay deployment/package docs;
- tests.

## 9. Security boundary

- Godot opens **no public listening socket**.
- Godot makes only an outbound WSS connection.
- API key must never be printed or included in diagnostics.
- Tunnel ID is an identifier, not a secret.
- Project-changing commands need argument validation and project-path guards.
- The relay must use TLS and isolate tunnel sessions.
- Current prototype stores credentials in Godot EditorSettings; before a hardened public release, review whether OS-backed secret storage is practical.

## 10. Performance model

A normal operation should be:

```text
ChatGPT MCP tools/call
 -> relay lookup
 -> one WSS tool_call
 -> one Godot command execution
 -> one WSS tool_result
 -> MCP result
```

No shell spawn, no local Node process, no localhost bridge hop.

## 11. Next development task

Continue from Phase 1/2 boundary:

1. create a fake/local relay integration test for the v1 frames;
2. prove `register -> registered -> tool_call -> tool_result` end to end;
3. migrate the first practical scene/node command slice from the upstream MIT addon;
4. add third-party notices only when upstream source is actually copied;
5. keep `docs/PROGRESS.md` updated after every meaningful milestone.
