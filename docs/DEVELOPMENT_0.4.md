# 0.4.0 Full-Capability Development Tracker

English | [简体中文](DEVELOPMENT_0.4.zh-CN.md)

Target version: **0.4.0**

Branch: `main` durable development workspace

Public validated baseline while this work is in progress: **0.3.0**

Status of this document: tracks both committed baseline and explicitly marked uncommitted working-tree work.

## 1. Goal

0.4.0 is the capability-expansion release. The goal is not a minimal demo surface. The target is a broadly useful Godot editor/runtime MCP that can independently discover, understand, modify, run, inspect and debug a real Godot project without requiring the user to manually relay routine project context.

The full loop should become:

```text
inspect project
 -> discover files/scenes/scripts/resources
 -> inspect Godot 4.7.2 APIs
 -> modify project/editor state
 -> save
 -> run
 -> collect diagnostics/runtime state
 -> repair
 -> validate again
```

## 2. Non-negotiable architecture

0.4.0 keeps the known-good 0.3.0 transport:

```text
ChatGPT
 -> OpenAI Secure MCP Tunnel
 -> official bundled tunnel-client
 -> Godot loopback Streamable HTTP MCP
 -> command registry
 -> Godot Editor / Runtime APIs
```

Do not reintroduce the removed custom OpenAI tunnel wire client.

## 3. Credential persistence

Decision: match CWapi's storage class, not its credential namespace.

CWapi was inspected read-only and uses Windows Credential Manager with Generic Credentials through `CredWriteW`, `CredReadW` and `CredDeleteW`.

0.4.0 uses the same mechanism with its own target:

```text
godot-mcp-chatgpt/0.4/OpenAI/Tunnel/APIKey
```

The project must never reuse CWapi's `CWapi/2.0/...` target, because the two products must not overwrite each other's secrets.

Expected behavior:

```text
first connection:
Tunnel ID + Runtime API Key
 -> save Tunnel ID
 -> save Runtime API Key in Windows Credential Manager
 -> start tunnel-client

next Godot startup:
saved Tunnel ID + Credential Manager API Key
 -> automatic reconnect
```

The generated tunnel profile must still contain only:

```yaml
api_key: env:CONTROL_PLANE_API_KEY
```

### Credential status

| Item | Status | Evidence / remaining gate |
| --- | --- | --- |
| Windows credential helper | targeted validation passed | isolated write/present/read/delete round trip passed |
| Godot credential-store wrapper | targeted validation passed | Godot 4.7.2 script load passed |
| UI save/forget flow | implemented / validation pending | production UI integration still needs full smoke |
| automatic reconnect after Godot restart | implemented / validation pending | cross-process restart test not yet run |
| secret/profile leak regression | planned | final secret scan + profile inspection required |

## 4. Capability matrix

These statuses describe the current durable working tree, not the public 0.3.0 release.

| Area | Status | Scope |
| --- | --- | --- |
| Shared Variant/object codec | targeted validation passed | Godot Variant encoding/decoding, property/method/signal summaries, limits |
| Project discovery/search | targeted validation passed | inspect/list/find/search |
| ProjectSettings | targeted validation passed | get/set/list |
| InputMap | targeted validation passed | list/get/add/remove/events |
| Project file operations | targeted validation passed | mkdir/move/delete inside `res://` |
| Scene lifecycle | targeted validation passed | current/open/list/close/reload/save/instantiate/inspect |
| Node introspection | targeted validation passed | inspect/properties/methods/find |
| Node mutation | targeted validation passed | rename/reparent/duplicate/move/call |
| Groups | targeted validation passed | read/add/remove |
| Signals | targeted validation passed | inspect connections/connect/disconnect |
| Metadata | targeted validation passed | read/set/remove |
| Script introspection | targeted validation passed | info/validation/open-state/reload/save/detach |
| Resource introspection/mutation | targeted validation passed | inspect/get/set/create/save/duplicate/dependencies/call |
| ClassDB self-inspection | targeted validation passed | search/inspect/properties/methods/signals/enums/constants/inheritance |
| Editor state/control | targeted validation passed | inspect/selection/filesystem/script state/play controls/save-all |
| Captured run diagnostics | targeted validation passed | separate stdout/stderr, exit code, timeout, duration, truncation state |
| Editor debugger integration | targeted validation passed | debugger sessions, breakpoints/profiler controls, Godot debugger messaging |
| Runtime bridge | targeted validation passed | live tree/inspect/find/property/method/group/performance/pause-resume |
| Batch operations | targeted validation passed | max 50 items, ordered execution, per-item results, stop-on-error, recursion denial |
| High-level aggregate inspection | targeted validation passed | project/scene/node/editor/runtime aggregate inspection now exists |
| Production command registration | in progress | Editor module is registered for WIP validation; remaining 0.4 modules are not yet exposed |
| Full MCP schema/catalogue validation | integration passed | all 119 names/schemas/required fields/annotations passed gates |
| Full production tunnel regression | integration passed | bundled official tunnel-client production smoke passed |

## 5. Working-tree modules

Current 0.4.0 work includes:

```text
addons/godot_mcp_chatgpt/core/command_utils.gd
addons/godot_mcp_chatgpt/commands/project_commands.gd
addons/godot_mcp_chatgpt/commands/scene_node_commands.gd
addons/godot_mcp_chatgpt/commands/script_resource_commands.gd
addons/godot_mcp_chatgpt/commands/classdb_commands.gd
addons/godot_mcp_chatgpt/commands/editor_commands.gd
addons/godot_mcp_chatgpt/commands/runtime_debugger_commands.gd
addons/godot_mcp_chatgpt/debug/editor_debugger_bridge.gd
addons/godot_mcp_chatgpt/debug/runtime_debugger_manager.gd
addons/godot_mcp_chatgpt/runtime/runtime_bridge.gd
addons/godot_mcp_chatgpt/web/credential_store.gd
tools/credential-helper/
addons/godot_mcp_chatgpt/bin/windows/godot-mcp-credential.exe
```

These are **not yet the public release contract** until the production registration and release gates pass.

## 6. Tool-family target

0.4.0 aims to cover these families rather than an arbitrary numeric tool count:

```text
godot.*
project.*
input_map.*
scene.*
node.*
script.*
resource.*
classdb.*
editor.*
debugger.*
runtime.*
batch.*
```

A family is considered complete only when normal read, mutation (where applicable), discovery, validation/error behavior and safety boundaries are covered.

## 7. Runtime/debug design

The runtime path should use Godot's own debugger transport where possible:

```text
Editor MCP
 -> EditorDebuggerPlugin / EditorDebuggerSession
 -> EngineDebugger message channel
 -> runtime bridge
 -> running SceneTree
```

Do not expose a second public network listener for runtime control.

For console diagnostics, Godot 4.7.2 does not expose a simple public API for scraping the Output dock. Use a truthful implementation such as a captured run process / debugger messages rather than claiming to read UI output that is not available through a supported API.

## 8. Safety requirements

- filesystem mutation remains scoped to `res://`;
- no arbitrary shell MCP tool;
- method-call tools must return structured errors and remain bounded;
- batch execution must have count/size limits;
- recursive inspection must have depth/item limits;
- destructive tools must have accurate MCP annotations;
- existing-scene overwrite remains explicit;
- credential values must never be logged or returned by MCP;
- Runtime API Key must not be stored in project files or Git.

## 9. Validation gates

0.4.0 cannot be promoted to the public Tool Reference until all applicable gates pass.

### Module gates

- [x] Credential helper isolated round trip
- [x] Credential GDScript compilation
- [x] Project command module compilation
- [x] Scene/Node command module compilation
- [x] Script/Resource command module compilation
- [x] ClassDB command module compilation
- [x] Editor command module compilation + real EditorPlugin behavior smoke
- [x] Runtime/debugger module compilation + real runtime bridge smoke
- [x] Batch module compilation + production smoke

### Integration gates

- [x] Register all 0.4.0 modules in production plugin (119 tools)
- [x] Full addon script compilation under Godot 4.7.2
- [x] Validate unique tool names
- [x] Validate all MCP input schemas
- [x] Validate tool annotations
- [x] Loopback / official tunnel MCP `tools/list` + representative `tools/call`
- [x] Real Godot GUI editor read/write smoke
- [x] Credential save -> Godot restart -> automatic reconnect
- [x] Credential forget -> restart -> credential required
- [x] Captured-run diagnostics smoke
- [x] Runtime debugger bridge smoke
- [x] Official tunnel-client integration regression
- [x] Real ChatGPT connector discovery/call regression

### Repository/release gates

- [x] Remove UTF-8 BOM from WIP `plugin.cfg` and scan all text files
- [x] Secret scan
- [x] `git diff --check`
- [x] Test-artifact / generated-file hygiene
- [x] Documentation relative-link check
- [x] Update English + Chinese Tool Reference
- [x] Update README capability summary
- [x] Update CHANGELOG
- [x] Update SECURITY if credential/runtime surface changed materially
- [ ] Commit and push only after the validated baseline is coherent

### Credential restart lifecycle

Status: **integration passed**.

- [x] first save -> Credential Manager
- [x] Godot restart -> automatic reconnect without re-entering API Key
- [x] forget credentials -> key + Tunnel ID removed
- [x] restart after forget -> credentials required
- [x] isolated test target used; production credential target untouched

### Runtime autoload lifecycle

Status: **integration passed**.

- [x] plugin enable -> runtime autoload present
- [x] plugin disable -> runtime autoload removed
- [x] plugin re-enable -> runtime autoload restored
- [x] Godot 4.7.2 `uid://` autoload references resolve to the runtime bridge
- [x] final disable leaves no runtime autoload residue

### Real ChatGPT Connector regression

Status: **real connector validation passed**.

- [x] real ChatGPT Connector discovered 119 tools
- [x] full editor read/write loop
- [x] Runtime Debugger live tree/property/method/pause/resume
- [x] Diagnostics stdout/stderr/exit code
- [x] Batch ordering/stop-on-error/recursion denial
- [x] Security boundaries
- [x] `REAL_CHATGPT_GODOT_MCP_0_4_TEST=PASS`

Resolved follow-ups: invalid Resource paths now return `INVALID_PATH`, and `node.create.parent_path` schema explicitly documents `.` as the edited-scene root. Continue observing the non-reproducible scene activation and transient network events.

## 10. Current blocker

No known release blocker remains. All code, integration, credential, runtime lifecycle, real Connector, repository hygiene and bilingual documentation gates are green.

## 11. Exact next task

1. commit the coherent 0.4.0 baseline;
2. push `main`;
3. start the separate one-click installer/release packaging task.
