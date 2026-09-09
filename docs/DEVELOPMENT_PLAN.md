# Development Plan

## 1. Project purpose

`godot-mcp-chatgpt` is a standalone open-source project that makes a local Godot Editor controllable from Web ChatGPT through MCP without routing editor operations through CWapi Coding mode.

Primary target architecture:

```text
Web ChatGPT
    |
    | MCP over HTTPS (Streamable HTTP)
    v
Public relay / tunnel endpoint
    |
    | tunnel_id + api_key authentication
    v
Local godot-mcp-chatgpt bridge
    |
    | localhost WebSocket / local RPC
    v
Godot MCP Toolkit-compatible editor addon
    |
    v
Godot Editor / current project
```

The design goal is low-latency, direct editor control: scene operations, node edits, scripts, play/stop, error inspection, project settings, and other Godot-specific actions should be native MCP tool calls rather than indirect shell/file operations.

## 2. Repository policy

- Repository: `AAAYNMMM/godot-mcp-chatgpt`
- Default branch: `main`
- Visibility: public
- This repository is **not** a GitHub fork.
- Only required code will be migrated or reimplemented.
- Upstream MIT-licensed code may be reused when useful, with required copyright and license notices preserved.
- Do not modify CWapi for this project.
- Do not couple the runtime to a CWapi Coding workspace.
- Development may use MCPcoding as the implementation tool, but the finished product must run independently of CWapi.

## 3. Upstream projects to evaluate

Initial source candidates:

1. `NPGameDev/godot-mcp-server`
   - TypeScript MCP server/bridge.
   - Useful pieces: Godot bridge, tool registration, schemas, MCP tool surface.
2. `NPGameDev/godot-mcp-toolkit`
   - Godot editor addon.
   - Useful pieces: editor-side RPC/tool execution, scene/editor integration.
3. Other Godot MCP implementations may be consulted only for protocol/transport ideas when licensing permits.

Before copying source files:
- verify the exact upstream license in-repository;
- copy the relevant license notice;
- document migrated files/components;
- avoid importing unnecessary code.

## 4. Product requirements

### 4.1 Web-first MCP transport

The public-facing MCP endpoint must support modern remote MCP transport, with Streamable HTTP as the first target.

Expected endpoint shape:

```text
https://<relay-host>/mcp
```

The Web ChatGPT side should not need local `stdio`, Node process spawning, or access to `127.0.0.1`.

### 4.2 Tunnel identity

Each running local client receives or stores a stable connection identifier:

```text
tunnel_id = godot_<random-id>
```

The relay maps that identifier to the correct connected local Godot client.

Requirements:
- unique enough to prevent collision;
- reconnectable;
- rotatable;
- never treated as a secret by itself.

### 4.3 API key authentication

Each local connection has an API key:

```text
gdmcp_<high-entropy-secret>
```

Requirements:
- high entropy;
- never logged in plaintext;
- stored locally with restricted access where practical;
- revocable/regeneratable;
- required for remote MCP access;
- compare using timing-safe logic where applicable.

The intended user experience is similar to CWapi's simple `Tunnel ID + API Key` pairing, but the implementation is purpose-built for Godot MCP.

### 4.4 Local-only Godot exposure

The Godot editor addon must **not** expose an unauthenticated public listener.

Preferred boundary:

```text
Internet
   |
relay
   |
authenticated outbound tunnel
   |
local bridge
   |
127.0.0.1
   |
Godot addon
```

The Godot-side socket/RPC endpoint stays bound to localhost.

### 4.5 Outbound connection preference

Prefer a local agent that establishes an outbound persistent connection to the relay. This avoids requiring router port-forwarding or exposing a local HTTP server directly to the Internet.

Candidate relay transports:
- WebSocket for long-lived bidirectional tunnel traffic;
- HTTPS control endpoints;
- Streamable HTTP on the Web ChatGPT-facing MCP side.

### 4.6 Sessions and reconnects

Required behavior:
- local client reconnects automatically after transient network failure;
- tunnel identity remains stable unless regenerated;
- MCP sessions are isolated;
- in-flight requests fail clearly if the local Godot instance disconnects;
- stale sessions expire;
- relay must not route a request to the wrong tunnel.

### 4.7 Permission modes

Plan for three permission profiles:

- `read_only`
  - inspect project/editor state only.
- `safe`
  - common scene/script/resource edits, run/stop, no arbitrary OS execution.
- `full`
  - all supported Godot MCP actions.

Default for public releases should be `safe`.

Arbitrary shell execution is not a core requirement and should not be added merely to reproduce Coding mode.

## 5. Tool-surface design

A large Godot MCP tool catalog can consume substantial context. The Web ChatGPT version should optimize discovery.

Preferred model:

```text
small core tool set
    |
discover/search tools
    |
load/use specialized tools on demand
```

Initial core categories:
- connection/status;
- project information;
- scene tree inspection;
- create/update/delete node;
- scene open/save;
- script create/read/update/attach;
- run/stop game;
- editor/runtime errors;
- resource/project settings lookup.

Later categories can include:
- signals;
- input map;
- animation;
- shaders/materials;
- navigation;
- physics;
- UI;
- profiler/debugger;
- import/export.

The exact protocol should favor compact schemas and batched operations where they materially reduce round trips.

## 6. Proposed repository layout

```text
godot-mcp-chatgpt/
├─ README.md
├─ LICENSE
├─ THIRD_PARTY_NOTICES.md
├─ docs/
│  ├─ DEVELOPMENT_PLAN.md
│  ├─ PROGRESS.md
│  ├─ ARCHITECTURE.md
│  ├─ PROTOCOL.md
│  └─ SECURITY.md
├─ server/
│  ├─ src/
│  │  ├─ mcp/
│  │  ├─ auth/
│  │  ├─ tunnel/
│  │  ├─ relay/
│  │  └─ godot/
│  ├─ package.json
│  └─ tsconfig.json
├─ addon/
│  └─ addons/
│     └─ godot_mcp_chatgpt/
├─ shared/
│  └─ protocol/
├─ tests/
│  ├─ unit/
│  ├─ integration/
│  └─ fixtures/
└─ scripts/
```

This layout is a target, not a requirement to create every directory immediately.

## 7. Component architecture

### A. Web MCP gateway

Responsibilities:
- expose `/mcp`;
- validate API key and tunnel identity;
- create MCP sessions;
- translate MCP tool calls into tunnel RPC;
- return results/errors to Web ChatGPT.

### B. Relay

Responsibilities:
- track connected local agents;
- map `tunnel_id -> connection`;
- enforce authentication;
- heartbeat and expiry;
- request correlation;
- rate/size limits;
- prevent cross-tunnel routing.

The relay may initially live in the same process as the MCP gateway. Split it only when there is a practical deployment reason.

### C. Local bridge

Responsibilities:
- connect outbound to relay;
- authenticate;
- maintain heartbeat/reconnect;
- discover the local Godot addon;
- forward tool requests/results;
- expose local diagnostics.

### D. Godot addon

Responsibilities:
- editor integration;
- execute Godot-specific operations;
- keep local transport on localhost;
- return structured results/errors;
- never trust remote payloads blindly.

Where possible, migrate proven editor-side behavior from compatible MIT-licensed upstream code rather than rebuilding every Godot operation.

## 8. Security requirements

Minimum requirements before public remote access:

- API key authentication;
- TLS on public endpoints;
- localhost-only Godot listener;
- no secret logging;
- max request/body sizes;
- request timeouts;
- heartbeat and stale connection cleanup;
- per-tunnel isolation;
- permission modes;
- validation of tool arguments;
- no arbitrary filesystem path escape from project scope unless explicitly allowed;
- no automatic arbitrary process execution in default modes;
- rate limiting or abuse protection on public relay;
- key regeneration and disconnect controls.

Threats to cover in `docs/SECURITY.md`:
- leaked API key;
- tunnel ID enumeration;
- replay;
- malicious MCP caller;
- malformed Godot RPC payload;
- cross-session response mix-up;
- denial of service;
- path traversal;
- unsafe script/file edits;
- compromised relay.

## 9. Performance targets

This project exists partly to reduce latency compared with using Coding mode as a device-control path.

Targets for local/editor operations:
- avoid spawning a shell for ordinary Godot actions;
- keep one persistent local bridge connection;
- one remote MCP call should normally map to one Godot RPC request;
- support batched node/property operations later;
- avoid re-sending the entire tool catalog on every operation when protocol/client behavior permits;
- keep JSON payloads compact and structured.

Metrics to add:
- relay RTT;
- relay-to-local RTT;
- local-to-Godot execution time;
- end-to-end tool call duration;
- reconnect count;
- failed request count.

## 10. Development phases

### Phase 0 — Repository and continuity documentation

Deliverables:
- public repository;
- development plan;
- progress/handoff document;
- README linking project docs.

Acceptance:
- a new ChatGPT window can read the repository and understand the current architecture, constraints, and next task without relying on previous chat history.

### Phase 1 — Upstream audit and minimal migration

Tasks:
- inspect upstream repository structure and exact licenses;
- identify minimum server bridge files;
- identify minimum addon files;
- create `THIRD_PARTY_NOTICES.md`;
- migrate only required components;
- make the imported code build/run locally before transport redesign.

Acceptance:
- local MCP bridge can talk to the Godot addon using the original/local transport;
- imported license obligations are documented.

### Phase 2 — Remote Streamable HTTP MCP

Tasks:
- replace/add remote MCP transport;
- expose `/mcp`;
- basic health endpoint;
- MCP session handling;
- map MCP requests to existing Godot bridge.

Acceptance:
- a remote MCP client can invoke a simple Godot read operation through HTTP.

### Phase 3 — Tunnel + API key

Tasks:
- outbound local tunnel connection;
- tunnel registration;
- API key generation/validation;
- relay request correlation;
- reconnect/heartbeat;
- stale connection cleanup.

Acceptance:
- remote caller using valid `tunnel_id + api_key` reaches the correct local Godot instance;
- invalid credentials cannot invoke tools.

### Phase 4 — Godot editor UX

Tasks:
- addon dock/panel;
- connection state;
- copy Tunnel ID;
- copy/regenerate API key;
- connect/disconnect;
- permission profile selector;
- diagnostic logs without secrets.

Acceptance:
- user can configure and operate the remote connection from inside Godot without command-line setup for normal use.

### Phase 5 — Web GPT optimization

Tasks:
- reduce default tool surface;
- add tool discovery;
- compact schemas;
- batch common operations;
- normalize errors;
- tune timeouts and reconnect behavior.

Acceptance:
- common editor workflows require materially fewer round trips and less MCP context than the unoptimized upstream server.

### Phase 6 — Hardening and release

Tasks:
- automated tests;
- Windows packaging;
- relay deployment guide;
- threat-model review;
- versioned protocol;
- compatibility notes for supported Godot versions.

Acceptance:
- reproducible setup from a clean Windows machine;
- documented upgrade path;
- no known critical authentication/session isolation defects.

## 11. Initial technical choices

Unless testing disproves them:

- Server/local bridge: TypeScript + Node.js.
- MCP SDK: official Model Context Protocol TypeScript SDK.
- Public MCP transport: Streamable HTTP.
- Tunnel transport: WebSocket or another persistent bidirectional transport.
- Godot addon: GDScript, compatible with Godot 4.7.x Standard.
- Godot local endpoint: loopback only.
- Data format: JSON-RPC-like structured messages with explicit request IDs.
- Tests: unit tests for auth/routing plus integration tests with a fake Godot bridge before relying on a real editor.

## 12. Non-goals for the first version

- Replacing Git or a full coding agent.
- General remote desktop control.
- Arbitrary OS automation.
- Cloud project storage.
- Multi-user collaborative Godot editing.
- Running a language model locally.
- Reimplementing every upstream Godot tool before the remote path works.

## 13. First implementation task after this plan

The next development window should begin with **Phase 1 — Upstream audit and minimal migration**.

Concrete order:

1. Inspect `NPGameDev/godot-mcp-server` license, package metadata, entrypoint, bridge, and tool registration.
2. Inspect `NPGameDev/godot-mcp-toolkit` license, plugin entrypoint, local socket implementation, and RPC dispatch.
3. Record exact reusable components in `docs/PROGRESS.md`.
4. Add `LICENSE` and `THIRD_PARTY_NOTICES.md`.
5. Migrate the smallest buildable server + addon slice.
6. Run install/build/static checks.
7. Confirm local bridge-to-addon connectivity before implementing remote transport.

Do not start by building the public relay. Preserve a working local baseline first.
