# Architecture

## Final runtime topology

```text
ChatGPT / supported OpenAI MCP product
              |
              | MCP JSON-RPC
              v
      OpenAI tunnel service
              |
              | GET /v1/tunnels/{id}/poll
              | POST /v1/tunnels/{id}/response
              | Authorization: Bearer <runtime-key>
              v
  secure_tunnel_client.gd
              |
              | direct Callable dispatch
              v
      CommandRegistry
              |
              v
        Godot Editor
```

## Why this architecture

The project originally explored a custom public Streamable HTTP relay plus an outbound Godot WebSocket. That worked end-to-end, but it duplicated infrastructure OpenAI already provides through Secure MCP Tunnel.

The production design now implements the public OpenAI tunnel-client wire contract directly inside the Godot EditorPlugin. This better matches the product goal:

- user enters only Tunnel ID + Runtime API Key;
- no local Node process;
- no local MCP server;
- no localhost port discovery;
- no public endpoint operated by this project;
- no router port forwarding;
- outbound HTTPS only;
- Godot commands execute in-process with low latency.

## Tunnel protocol implementation

The addon uses the canonical plural endpoints:

```text
GET  /v1/tunnels/{tunnel_id}
GET  /v1/tunnels/{tunnel_id}/poll?limit=10&timeout_ms=15000
POST /v1/tunnels/{tunnel_id}/response
```

Every control-plane request includes:

```text
Authorization: Bearer <runtime API key>
X-Tunnel-Client-Name: godot-mcp-chatgpt
X-Tunnel-Client-Version: <plugin version>
X-Tunnel-Client-Wire-Protocol-Version: 2026-08-25
X-Tunnel-Client-Instance-Id: <per-process opaque id>
X-Tunnel-MCP-Server-Info: {"version":1,"channels":[{"name":"main","proc_affinity":true}]}
```

The `main` channel advertises process affinity because editor state and the in-process command registry belong to one Godot process.

## MCP handling inside Godot

There is intentionally no separate MCP server object. The tunnel client handles the small server-side MCP surface needed by ChatGPT:

- `initialize`
- `ping`
- `tools/list`
- `tools/call`
- no-ID MCP notifications (`notify_ack`)
- tunnel `session_termination`

`tools/list` is generated from the live Godot `CommandRegistry`. `tools/call` invokes the registered Callable directly and converts the result to MCP text content.

## Request lifecycle

1. Godot long-polls the tunnel control plane.
2. The poll returns zero or more commands.
3. Commands are processed sequentially in the editor to avoid mutation races.
4. JSON-RPC commands are dispatched in-process.
5. The addon posts a correlated response with the original `request_id` in JSON and `shard_token` in `X-Tunnel-Shard-Token`.
6. `response_timeout` is anchored to local poll receipt time. Expired commands are dropped rather than answered late.
7. Transient poll/response failures use bounded exponential backoff with jitter.
8. 401/403 stop the loop and surface `authentication_failed` in the dock.

## Tool boundary

Current tools cover the smallest useful game-development loop:

```text
inspect project
create/open/save scene
inspect scene tree
create/change/delete node
read/write/attach GDScript
run/stop project
```

The next tool expansion should prioritize high-frequency Godot workflows rather than bulk-porting every upstream tool.

## Development-only test harness

`server/` is a local control-plane protocol simulator. It implements enough of the official tunnel endpoints to test the GDScript client without requiring real OpenAI credentials.

It is protected from Godot resource scanning by `server/.gdignore` and is never part of the release addon.

## Non-goals

- custom public relay infrastructure;
- local stdio MCP compatibility;
- local Node MCP bridge;
- general shell/desktop automation;
- exposing arbitrary OS commands;
- replacing Git or a coding agent.
