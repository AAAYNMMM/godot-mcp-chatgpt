# Development Progress / Handoff

English | [简体中文](PROGRESS.zh-CN.md)

Last updated: 2026-09-09

Repository: `AAAYNMMM/godot-mcp-chatgpt`

Branch: `main`

Current release candidate: `0.3.0`

0.3.0 implementation commit: `2a70cd1ed084df0d2ee5fff7c596c5ff5a3e93d8`

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

## Real ChatGPT connector validation

**Status: SUCCESS — 2026-09-09.**

The user completed the real production setup with their own OpenAI Tunnel ID / Runtime API Key and reported that the ChatGPT connector was **created successfully**.

This validates the architecture beyond local simulation:

```text
Godot 4.7.2
 -> bundled official OpenAI tunnel-client
 -> OpenAI Secure MCP Tunnel
 -> ChatGPT connector creation
 -> success
```

This is now the known-good baseline. Do not revert to the old direct GDScript tunnel implementation when debugging future issues.

The next product task is no longer connector creation. It is to exercise real tool calls from ChatGPT, then expand the high-value Godot tool surface and release packaging.
## Current blocker

No automated/local blocker remains for the 0.3.0 architecture.

No connector-creation blocker remains. Real ChatGPT connector creation succeeded on 2026-09-09.

## Exact next task

1. exercise the real connector with `godot.get_status`;
2. execute a disposable visible scene/node write through the real ChatGPT connector;
3. record any real-world tool ergonomics issues;
4. begin Phase 6 tool expansion, starting with property inspection and scene open/close;
5. prepare a clean Windows addon release package and first public-facing release notes.

## Bilingual documentation refresh

Completed after the real connector validation on 2026-09-09.

User-facing documentation was reorganized around first-time adoption rather than internal development history. The repository now provides paired English / Simplified Chinese documentation for:

```text
README
Quick Start
Practical Examples
Tool Reference
FAQ / Troubleshooting
Architecture
Secure Tunnel setup
Development Plan
Development Progress / Handoff
Contributing
Security
Changelog
```

Documentation policy for future work:

- keep user-facing docs English + Simplified Chinese when practical;
- use paired `NAME.md` / `NAME.zh-CN.md` files;
- keep the README focused on value, setup, real validation and clear limitations;
- do not add images, screenshots, badges or GIFs unless the repository policy is explicitly changed;
- document real tests as real tests, and do not turn simulated success into stronger claims.
## Repository/workspace notes

- Work only in `AAAYNMMM/godot-mcp-chatgpt` for this project.
- Do not modify CWapi; it was inspected read-only to understand the known-good tunnel integration pattern.
- The user's global GitHub CLI authentication is under their Windows user profile and can be reused if MCPcoding does not inherit it automatically.
- Godot development target is currently Windows + Godot 4.7.2 Standard + GDScript.
## 0.4.0 full-capability development — active working tree

Status updated: 2026-09-09.

Active tracker: [`DEVELOPMENT_0.4.md`](DEVELOPMENT_0.4.md)

Development process: [`DEVELOPMENT_WORKFLOW.md`](DEVELOPMENT_WORKFLOW.md)

Public validated baseline remains **0.3.0**. The 0.4.0 capability work below exists in the durable working tree and has **not** been promoted to the public Tool Reference or pushed as a validated release baseline.

### Task: Windows Credential Manager persistence

Status: **targeted validation passed; integration/restart validation pending**.

Files / module:

```text
tools/credential-helper/
addons/godot_mcp_chatgpt/bin/windows/godot-mcp-credential.exe
addons/godot_mcp_chatgpt/web/credential_store.gd
addons/godot_mcp_chatgpt/web/tunnel_client_runner.gd
addons/godot_mcp_chatgpt/ui/connection_dock.gd
```

What changed:

- inspected CWapi read-only and confirmed its Runtime API Key is stored as a Windows Credential Manager Generic Credential;
- implemented the same Windows storage mechanism under an independent `godot-mcp-chatgpt/...` credential target;
- kept the tunnel profile on `api_key: env:CONTROL_PLANE_API_KEY`;
- added saved-key presence/read/write/delete plumbing and a Forget Saved Credentials flow;
- prepared automatic reconnect from saved Tunnel ID + Credential Manager key.

Validation actually run:

- isolated helper `write -> present -> read -> delete -> present` round trip;
- read value matched the test secret;
- test credential was removed after the test;
- Godot 4.7.2 loaded `credential_store.gd` and the modified credential-related addon scripts successfully.

Result: targeted credential storage behavior passed.

Known limitation / blocker: Godot process restart -> automatic reconnect and Forget -> restart behavior have not yet been production-smoke tested.

### Task: Project / ProjectSettings / InputMap capability module

Status: **targeted validation passed**.

Files / module:

```text
addons/godot_mcp_chatgpt/core/command_utils.gd
addons/godot_mcp_chatgpt/commands/project_commands.gd
```

What changed: added project inspection/discovery/search, project settings, autoload/plugin discovery, project-scoped file operations and InputMap operations.

Validation actually run: Godot 4.7.2 loaded the shared command utility and Project command module without parse/compile errors.

Result: module compilation passed. Production registry integration remains pending.

### Task: Scene / Node capability module

Status: **targeted validation passed**.

File / module:

```text
addons/godot_mcp_chatgpt/commands/scene_node_commands.gd
```

What changed: added scene lifecycle/inspection and broad Node inspection/mutation, group, signal and metadata operations.

Validation actually run: after resolving Godot 4.7 strict typing/scope issues, Godot 4.7.2 loaded the final module without parse/compile errors.

Result: module compilation passed. Production registry integration and GUI behavior smoke remain pending.

### Task: Script / Resource capability module

Status: **targeted validation passed**.

File / module:

```text
addons/godot_mcp_chatgpt/commands/script_resource_commands.gd
```

What changed: added script introspection/validation/editor state helpers and Resource inspection/mutation/create/save/duplicate/dependency/method operations.

Validation actually run: Godot 4.7.2 loaded the rewritten module without parse/compile errors.

Result: module compilation passed. Representative real Resource mutations still require integration smoke.

### Task: ClassDB self-inspection module

Status: **targeted validation passed**.

File / module:

```text
addons/godot_mcp_chatgpt/commands/classdb_commands.gd
```

What changed: added current-engine ClassDB search/inspect/properties/methods/signals/enums/constants/inheritance/can-instantiate capabilities.

Validation actually run: Godot 4.7.2 loaded the module without parse/compile errors after correcting reserved-identifier usage.

Result: module compilation passed.

### Task: Development documentation system

Status: **complete**.

Files / module:

```text
docs/DEVELOPMENT_WORKFLOW.md
docs/DEVELOPMENT_WORKFLOW.zh-CN.md
docs/DEVELOPMENT_0.4.md
docs/DEVELOPMENT_0.4.zh-CN.md
docs/DEVELOPMENT_PLAN.md
docs/DEVELOPMENT_PLAN.zh-CN.md
docs/PROGRESS.md
docs/PROGRESS.zh-CN.md
CONTRIBUTING.md
CONTRIBUTING.zh-CN.md
```

What changed:

- established explicit source-of-truth roles for public docs, roadmap, active-version tracking and handoff progress;
- made progress documentation part of the definition of done;
- required a Progress + active-version update after every logically complete task and before starting the next task;
- standardized task status vocabulary and validation evidence;
- added a dedicated 0.4.0 full-capability checklist and release gates;
- recorded current uncommitted 0.4.0 work honestly without promoting it into the public 0.3.0 Tool Reference.

Validation actually run: `PAIR_CHECK=PASS`, `LINK_CHECK=PASS`, `LITERAL_NEWLINE_CHECK=PASS`, `DOC_BOM_CHECK=PASS`, and `DOC_DIFF_CHECK=PASS`.

Result: development bookkeeping now has an explicit per-task update rule.

## 0.4.0 current blocker

No architecture blocker is known. Major remaining implementation areas are Editor state/control, captured diagnostics, Debugger/Runtime bridge and batch operations. The new modules are not yet registered into the production command registry.

A WIP repository-hygiene issue is explicitly tracked: `plugin.cfg` currently contains an accidental UTF-8 BOM from intermediate editing. It has not been pushed and must be removed before the full-addon/release gates.

## 0.4.0 exact next task

**Implement the Editor state/control module and run its Godot 4.7.2 targeted compilation/behavior validation. Immediately update this Progress document and the 0.4.0 tracker after that task passes, before starting Runtime/Debugger work.**