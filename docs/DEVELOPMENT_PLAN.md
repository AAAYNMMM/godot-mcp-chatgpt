# Development Plan

English | [简体中文](DEVELOPMENT_PLAN.zh-CN.md)

## 1. Product goal

Build a small Godot 4.x editor addon that lets Web ChatGPT control the Godot editor through OpenAI Secure MCP Tunnel while the user only supplies:

1. Tunnel ID
2. Runtime API Key

The addon should feel like a native Godot integration. Users should not need CWapi, Codex, Node.js, a local MCP client, or manual port configuration.

## 2. Locked architecture decision

As of 2026-09-09 / version 0.3.0:

```text
Web ChatGPT
  -> OpenAI Secure MCP Tunnel
  -> official bundled tunnel-client
  -> loopback Streamable HTTP MCP hosted by Godot
  -> Godot command registry
  -> Godot Editor API
```

Do **not** reintroduce the previous direct GDScript implementation of OpenAI control-plane `/poll` and `/response` unless this decision is explicitly revisited with new evidence.

Also do not add as the normal user path:

- stdio MCP;
- Node MCP bridge;
- localhost WebSocket bridge;
- custom public relay;
- `.mcp.json` local-client setup.

## 3. Why the architecture changed

The direct GDScript tunnel client passed a local protocol simulator but ChatGPT connector creation still failed. CWapi was inspected because its tunnel connector creates successfully. CWapi's real architecture is:

```text
official tunnel-client
  -> localhost Streamable HTTP MCP
```

It does not reimplement the OpenAI tunnel protocol. Version 0.3.0 adopts that proven pattern.

## 4. Current production components

### Godot EditorPlugin

- bottom `MCP ChatGPT` panel;
- Tunnel ID + Runtime API Key inputs;
- Connect / Disconnect;
- status/log display.

### Tunnel runner

- starts bundled official OpenAI tunnel-client;
- creates the tunnel-client profile;
- injects Runtime API Key through `CONTROL_PLANE_API_KEY` only for child-process startup;
- persists Tunnel ID only;
- monitors/stops the tunnel process.

### Loopback MCP server

- binds only to `127.0.0.1`;
- random high port + random path token;
- Streamable HTTP JSON/SSE behavior;
- `server/discover`;
- `initialize`;
- `ping`;
- `tools/list`;
- `tools/call`;
- notification ACK;
- HTTP DELETE session termination.

### Godot command registry

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

## 5. Milestones

### Phase 0 — Repository continuity
Status: complete.

- public repository;
- README;
- architecture/development/progress documents.

### Phase 1 — Godot editor-control skeleton
Status: complete.

- EditorPlugin;
- connection panel;
- command registry;
- first useful scene/node/script/editor tools;
- Godot 4.7.2 compilation.

### Phase 2 — Transport exploration
Status: complete/superseded.

A custom public relay + WSS path was built and tested, then removed from production design.

### Phase 3 — Direct GDScript Secure Tunnel client
Status: complete/superseded.

The direct `/poll` + `/response` implementation was useful for learning the contract but failed the real ChatGPT connector creation path. It has been removed from production code.

### Phase 4 — Official tunnel-client architecture
Status: implemented and locally validated.

Acceptance already passed locally:

- same official `tunnel-client.exe` used by the user's working CWapi installation;
- real Godot 4.7.2 GUI;
- Go MCP SDK 1.7 client compatibility;
- `server/discover`;
- initialization;
- 13-tool discovery;
- tool call execution;
- scene/node/script mutation and save/readback;
- notification handling;
- session termination.

### Phase 5 — Real ChatGPT connector test
Status: **complete** on 2026-09-09.

Acceptance flow:

1. user enters real Tunnel ID + Runtime API Key in Godot;
2. official tunnel-client remains running;
3. ChatGPT creates a Tunnel connector using the same Tunnel ID;
4. ChatGPT discovers all 13 tools;
5. ChatGPT calls `godot.get_status`;
6. ChatGPT creates/modifies a disposable test scene;
7. the result appears visibly in Godot.

Real connector creation succeeded with the production 0.3.0 architecture. Future failures should be debugged against this known-good baseline before changing transport architecture.

### Phase 6 — Tool expansion
Status: **next** after the successful real connector validation.

Priority order:

- richer node/property inspection;
- scene open/close;
- resources;
- project settings and InputMap;
- signals;
- ClassDB lookup;
- editor/runtime errors;
- playtest diagnostics;
- batch node/property operations;
- optional screenshot workflow if it remains efficient and safe.

### Phase 7 — Release hardening

- improve tunnel-client health/readiness reporting in the Godot panel;
- secure key lifecycle/clear UX;
- clean-project addon installation test;
- Windows packaging/release ZIP;
- additional Godot 4.x compatibility testing;
- macOS/Linux tunnel-client packaging if desired;
- third-party binary provenance/license audit;
- runtime update strategy for future official tunnel-client releases.

## 6. Performance rules

- no shell/CLI hop for ordinary Godot tool execution;
- the loopback MCP hop is acceptable because it is the boundary required by the official tunnel client;
- serialize editor mutations by default;
- keep tool schemas compact;
- add batch tools where they materially reduce ChatGPT round trips;
- do not bulk-port hundreds of low-value tools before real usage shows they are needed.

## 7. Security rules

- never log Runtime API Keys;
- never write the Runtime API Key into the tunnel profile;
- use a restricted runtime key, not an admin key;
- local MCP binds only to loopback;
- local MCP URL includes a random unguessable path token;
- filesystem tools remain project-scoped;
- destructive annotations must be accurate;
- existing scenes require explicit `overwrite: true` before replacement.

## 8. Continuation rule

Every meaningful development window must update `docs/PROGRESS.md` with:

- completed changes;
- tests actually run;
- current blocker, if any;
- exact next task.

A new ChatGPT window should read `README.md`, `docs/ARCHITECTURE.md`, and `docs/PROGRESS.md` before making architecture changes.