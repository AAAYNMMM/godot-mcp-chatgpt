# Development Plan

## 1. Product goal

Build a small Godot 4.x editor addon that lets Web ChatGPT control the Godot editor through OpenAI Secure MCP Tunnel with only two user-provided values:

1. Tunnel ID
2. Runtime API Key

Production runtime must be Godot-only.

## 2. Locked architecture decision

As of 2026-09-09:

```text
Web ChatGPT
  -> OpenAI Secure MCP Tunnel
  -> direct HTTPS tunnel protocol in Godot
  -> in-process MCP request handling
  -> Godot command registry
  -> Godot Editor API
```

Do **not** reintroduce:

- stdio MCP;
- local MCP server;
- Node bridge;
- localhost WebSocket bridge;
- custom public relay;
- `.mcp.json` client configuration as the normal connection path.

The repository's Node code is test infrastructure only.

## 3. Protocol contract

Reference implementation/documentation:

- `openai/tunnel-client`
- canonical wire protocol: `docs/protocol.md` in that project
- wire contract version currently implemented: `2026-08-25`

Required control-plane calls:

```text
GET /v1/tunnels/{id}
GET /v1/tunnels/{id}/poll
POST /v1/tunnels/{id}/response
```

The Godot implementation must preserve opaque request IDs/shard tokens, correlate responses exactly, stop on auth failures, use bounded retries for transient failures, and never log API keys/shard tokens.

## 4. MCP surface

Initial MCP server behavior implemented directly in Godot:

- initialize
- ping
- tools/list
- tools/call
- lifecycle notification ACK
- session termination ACK

No prompts/resources/roots capability is advertised yet.

## 5. Current Godot tool milestone

Current 13 tools:

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

File operations remain inside `res://`.

## 6. Milestones

### Phase 0 — Repository continuity
Status: complete.

- public repository;
- README;
- development plan;
- progress handoff.

### Phase 1 — Direct Godot addon skeleton
Status: complete.

- EditorPlugin;
- connection dock;
- command registry;
- initial tools;
- Godot 4.7.2 script compilation.

### Phase 2 — Transport exploration
Status: superseded/complete.

A custom Relay + WSS implementation was built and successfully tested against real Godot. It was then removed from the production design after the official OpenAI Secure MCP Tunnel client/protocol became the better fit.

Do not restore this architecture unless the official tunnel becomes technically unusable and the decision is explicitly revisited.

### Phase 3 — Direct Secure MCP Tunnel client
Status: complete for local protocol simulation.

Implemented:

- metadata validation request;
- bearer authentication;
- official client headers;
- 15-second long poll;
- command batch processing;
- response correlation;
- response POST;
- retry/backoff;
- auth failure state;
- MCP initialize/tools/call handling;
- notification/session termination ACK;
- response timeout drop behavior;
- real Godot GUI smoke test.

### Phase 4 — Real OpenAI control-plane test
Status: next; requires user-operated credentials/UI.

Acceptance flow:

1. user creates/selects an OpenAI tunnel;
2. user creates a restricted Runtime API Key with Tunnels Read + Use;
3. user enters both in Godot dock;
4. Godot status becomes connected;
5. user configures ChatGPT connector with Connection: Tunnel and same tunnel ID;
6. ChatGPT discovers tools;
7. ChatGPT calls `godot.get_status`;
8. ChatGPT creates/modifies a disposable test scene;
9. verify resulting scene in the visible Godot editor.

### Phase 5 — Tool expansion
After real tunnel success.

Priorities:

- node.get_properties / richer property inspection;
- scene.open / close;
- resource create/edit;
- project settings + InputMap;
- signals;
- ClassDB lookup;
- editor/runtime error inspection;
- playtest diagnostics;
- batched node/property operations;
- optional screenshots if supported safely/efficiently.

### Phase 6 — Release hardening

- OS-grade credential storage or an explicit secure-storage strategy;
- key clear/rotate UX;
- connection health diagnostics;
- protocol compatibility tests against newer tunnel wire versions;
- addon packaging/release ZIP;
- clean-project installation test;
- Godot compatibility matrix;
- license/notice audit.

## 7. Performance rules

- no shell spawn for ordinary Godot operations;
- no local network hop;
- process tunnel commands sequentially by default to protect editor state;
- keep tool schemas compact;
- prefer high-value tools over a huge eager catalogue;
- batch operations later when they materially reduce tunnel round trips.

## 8. Security rules

- never log API keys or shard tokens;
- runtime key must be restricted to minimum tunnel permissions;
- no admin key in the Godot addon;
- outbound control-plane host defaults to `https://api.openai.com`;
- alternate control-plane URL is development-only through environment variable;
- filesystem tools remain project-scoped unless explicitly designed otherwise;
- destructive tool annotations must be honest;
- existing scenes are not overwritten without explicit `overwrite: true`.

## 9. Continuation rule

Every meaningful development window must update `docs/PROGRESS.md` with:

- completed changes;
- tests actually run;
- current blocking issue;
- exact next task.

A new ChatGPT window should read `README.md`, `docs/ARCHITECTURE.md`, and `docs/PROGRESS.md` before changing architecture.
