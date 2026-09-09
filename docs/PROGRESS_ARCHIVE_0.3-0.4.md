> **Archived historical implementation log.** For current state, see [Progress](PROGRESS.md).

# Development Progress / Handoff

English | [简体中文](PROGRESS_ARCHIVE_0.3-0.4.zh-CN.md)

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
<Godot 4.7.2 executable>
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

### Task: Editor state/control module

Status: **targeted validation passed**.

File / module:

```text
addons/godot_mcp_chatgpt/commands/editor_commands.gd
```

What changed: added editor aggregate inspection, scene-node selection read/write/clear, filesystem scan/import state and controls, FileSystem selection, Script editor state/open/close, play-state inspection, run main/current/custom scene, stop playing, and save-all controls. The module was registered into the 0.4 WIP plugin for real EditorPlugin-context validation.

Validation actually run:

- Godot 4.7.2 loaded the complete plugin with EditorCommands registered;
- real Godot GUI + bundled official tunnel-client + local control-plane smoke discovered 31 tools;
- `editor.inspect`, `editor.get_filesystem_state`, and `editor.get_script_state` returned real editor state;
- `editor.set_selection` selected the generated Player node and `editor.clear_selection` cleared it;
- `editor.run_current_scene` entered playing state, `editor.get_playing_scene` confirmed it, and `editor.stop_playing` returned to stopped state;
- result: `PRODUCTION_PLUGIN_SMOKE=PASS`.

Also resolved the tracked WIP `plugin.cfg` UTF-8 BOM before the real plugin smoke. Full repository BOM scanning remains a release gate.

### Task: Runtime / Debugger bridge

Status: **targeted validation passed**.

Files / modules:

```text
addons/godot_mcp_chatgpt/debug/editor_debugger_bridge.gd
addons/godot_mcp_chatgpt/debug/runtime_debugger_manager.gd
addons/godot_mcp_chatgpt/runtime/runtime_bridge.gd
addons/godot_mcp_chatgpt/commands/runtime_debugger_commands.gd
```

What changed: added Godot-native debugger transport between the editor plugin and the running game, without a second network listener. Runtime tools cover status/tree/inspect/find/property read-write/method calls/groups/performance/pause-resume. Debugger tools expose sessions, breakpoints and profiler toggles. Runtime requests support optional `session_id` and bounded `timeout_ms`.

Validation actually run:

- all four Runtime/Debugger modules loaded under Godot 4.7.2;
- the WIP production plugin registered the debugger plugin and runtime bridge;
- the real editor launched the disposable scene with `--remote-debug tcp://127.0.0.1:...`;
- the runtime bridge emitted a ready message through Godot's EngineDebugger channel;
- official tunnel production smoke discovered 46 tools;
- `runtime.status` returned the live scene and node count;
- `runtime.get_tree` returned SecureRoot -> Player;
- `runtime.get_property` read Player.position as (4,5,6);
- `runtime.set_property` changed the live Player.position to (7,8,9) and returned the new live value;
- `runtime.call_method` called `get_child_count` on the live root;
- `runtime.get_performance`, `runtime.pause`, and `runtime.resume` succeeded;
- `debugger.get_sessions` reported the active debugger session;
- final result after removing temporary diagnostic prints: `PRODUCTION_PLUGIN_SMOKE=PASS`.

Result: the runtime/debugger loop is functional through the same official tunnel-client production path.

### Task: Captured-run diagnostics

Status: **targeted validation passed**.

Files / modules:

```text
addons/godot_mcp_chatgpt/commands/diagnostics_commands.gd
tools/run-helper/main.go
addons/godot_mcp_chatgpt/bin/windows/godot-mcp-runner.exe
```

What changed: added bounded `diagnostics.run_capture`. It can only launch the current Godot executable against the current project and an optional `res://` scene; it does not expose arbitrary shell/executable access. A dedicated Windows helper captures stdout/stderr separately and returns exit code, timeout, duration and truncation state.

Validation actually run: official tunnel-client production smoke discovered 47 tools; a success scene captured `CAPTURE_STDOUT_OK` with exit code 0; an error scene captured `push_error` on stderr and exit code 7; a blocking scene was forcibly terminated by the helper at a 300ms timeout and returned `timed_out=true` / exit code -1. Final result: `PRODUCTION_PLUGIN_SMOKE=PASS`.

Result: captured-run diagnostics now provide a truthful stdout/stderr/exit/timeout loop without pretending to scrape the Output dock.

### Task: Batch operations

Status: **targeted validation passed**.

File / module:

```text
addons/godot_mcp_chatgpt/commands/batch_commands.gd
```

What changed: added non-atomic `batch.execute` with a maximum of 50 ordered existing MCP tool calls, per-item results, optional `stop_on_error`, total payload limits, and explicit denial of recursive `batch.*` calls.

Validation actually run: Godot 4.7.2 compilation passed; official tunnel production smoke discovered 48 tools; sequential `godot.get_status` + `project.get_info` succeeded; an unknown middle tool stopped the batch correctly; recursive invocation returned `BATCH_RECURSION_DENIED`; a 51-operation request returned `BATCH_TOO_LARGE`; final result `PRODUCTION_PLUGIN_SMOKE=PASS`.

Result: Batch targeted validation passed and is explicitly non-atomic with no rollback promise.

### Task: 0.4.0 unified registration and representative full-surface integration

Status: **integration passed**.

What changed: wired Project / InputMap / Scene / Node / Script / Resource / ClassDB / Editor / Debugger / Runtime / Diagnostics / Batch into the production CommandRegistry; CommandRegistry now rejects duplicate names explicitly; fixed safe summaries for editor scene roots not inside SceneTree; fixed stale freshly-written GDScript metadata in `script.get_info`; `project.set_setting(name, null)` now has explicit deletion semantics.

Validation actually run: full Godot 4.7.2 addon compilation passed; bundled official tunnel-client production smoke discovered **119 tools**; `CATALOGUE_SCHEMA_GATE=PASS tools=119` validated unique names, name format, descriptions, recursive inputSchema structure, required fields, `additionalProperties=false`, `readOnlyHint`, and `destructiveHint`. Representative real behavior covered Project/settings/file search+move+delete, InputMap, Scene lifecycle/inspect, Node property/method/group/metadata/duplicate/rename, Script introspection/validate/detach, Signal connect/disconnect, Resource create/get/set/duplicate/save/dependencies/call, ClassDB, Editor, Runtime, Diagnostics and Batch. Temporary InputMap/ProjectSetting values are cleaned up by the smoke. Final result: `PRODUCTION_PLUGIN_SMOKE=PASS` with no MCP script errors in Godot stderr.

Result: the 119-tool 0.4.0 surface now has coherent production registration plus a representative behavior baseline. It is not release-ready yet: credential restart/forget, autoload cleanup, repository release gates and a real ChatGPT 0.4 regression remain.

### Task: Credential restart lifecycle

Status: **integration passed**.

Validation actually run on Windows with an isolated `godot-mcp-chatgpt/test/...` Credential Manager target and isolated Godot APPDATA:

- first connection persisted the Runtime API Key and Tunnel ID;
- a fresh Godot process restarted with no API Key environment value and auto-connected using the saved Credential Manager key;
- the forget flow deleted both saved key and Tunnel ID;
- a third restart did not auto-connect and returned to credentials-required/waiting state;
- result: `CREDENTIAL_RESTART_SMOKE=PASS`.

The production Credential Manager target was not touched by this test.

### Task: Runtime autoload lifecycle and plugin cleanup

Status: **integration passed**.

What changed: RuntimeDebuggerManager now removes its reserved runtime autoload when the plugin is disabled, checks conflicts before registering the debugger plugin, and accepts both `res://` and Godot 4.7.2 `uid://` autoload references when they resolve to the plugin runtime bridge.

Validation actually run in a real headless Godot 4.7.2 editor using a temporary test EditorPlugin:

- target plugin enabled -> runtime autoload resolved to `runtime_bridge.gd`;
- disable -> autoload removed;
- re-enable -> Godot rewrote the autoload as `uid://...`, manager accepted it and runtime autoload resolved correctly;
- final disable -> autoload removed again;
- result: `RUNTIME_AUTOLOAD_LIFECYCLE_SMOKE=PASS`.

### Task: Real ChatGPT Connector 0.4.0 full-surface regression

Status: **real connector validation passed**.

On 2026-09-10 a fresh real ChatGPT conversation exercised the user-created Connector against the current Godot 4.7.2 editor. The Connector exposed **119 tools** and real calls covered Project, ClassDB, Scene, Node, Groups/Metadata, Script, Signals, Resource, ProjectSettings, InputMap, Editor, Debugger/Runtime, Diagnostics, Batch, and security boundaries.

Key results:

- `REAL_CHATGPT_GODOT_MCP_0_4_TEST=PASS`;
- runtime Player.position changed from Vector3(2,3,4) to Vector3(7,8,9) and read back correctly; after stopping, the editor scene remained Vector3(2,3,4), proving runtime changes did not leak into the editor scene;
- `runtime.call_method` returned `Player.add_values(12, 30) = 42`;
- Diagnostics returned exit code 0 for the normal scene and captured `MCP_REAL_ERROR_TEST` with exit code 7 for the error scene;
- Batch ordering, stop-on-error, and `BATCH_RECURSION_DENIED` all passed;
- path traversal, project-external paths, scene-root deletion, and invalid class/property/method requests were rejected;
- temporary ProjectSetting/InputMap entries were cleaned up and the test did not modify the plugin directory, API Key, Tunnel ID, or Windows Credential Manager.

Non-blocking follow-ups:

1. RESOLVED: all Resource source paths now validate before load; `res://../outside.tres` returns `INVALID_PATH` and is covered by production smoke;
2. RESOLVED: `node.create.parent_path` MCP schema now explicitly says `.` means the edited-scene root and the root node name should not be used;
3. one transient old-scene observation after `scene.create` and one `mcp_network_error` were not reproducible; keep them as observation items, not 0.4.0 blockers.
### Task: 0.4.0 final release gates and public documentation

Status: **release validation passed**.

Final validation actually run after the real Connector regression and follow-up fixes:

```text
Godot 4.7.2 addon load: PASS
Go helper gofmt/build/test: PASS
CREDENTIAL_HELPER_FINAL=PASS
npm build: PASS
npm test: PASS
CATALOGUE_SCHEMA_GATE=PASS tools=119
PRODUCTION_PLUGIN_SMOKE=PASS
Resource traversal -> INVALID_PATH regression: PASS
node.create parent_path schema guidance regression: PASS
BOM_CHECK=PASS
LITERAL_NEWLINE_CHECK=PASS
SECRET_CHECK=PASS real=0
TOOL_REFERENCE_COVERAGE=PASS tools=119
LINK_CHECK=PASS
NO_IMAGE_MARKUP=PASS
VERSION_CHECK=PASS 0.4.0
git diff --check: PASS
TEST_ARTIFACT_HYGIENE=PASS
```

Public bilingual docs were promoted to 0.4.0: README, Tool Reference, Quick Start, FAQ, Architecture, Secure Tunnel, Security, Development Plan and Changelog. The six real-Connector test assets remain locally under ignored `res://.mcp-real-test/` for visual inspection and will not enter Git.

### Task: 0.4.0 commit and push

Status: **complete**.

- Release baseline commit: `3f8ce7e` (`release: complete 0.4.0 Godot MCP surface`);
- pushed successfully to `origin/main`;
- the validated 119-tool / real Connector / Credential / Runtime / Diagnostics / Batch / release-gate baseline remains the 0.4.0 source of truth;
- one-click installer / Release packaging is intentionally paused per user request.

### Task: One-click Windows project installer

Status: **integration passed**.

Implemented a distributable Windows x64 single-file installer under `tools/installer/`. The installer embeds the complete `addons/godot_mcp_chatgpt/` payload, asks the user to select a target project's `project.godot`, installs only into that project's `addons/godot_mcp_chatgpt/`, enables the editor plugin by default, supports upgrade replacement with backup/rollback behavior, and does not hard-code any user or machine path. A portable addon ZIP and SHA-256 manifest are produced by the same reproducible build script.

During clean-project validation, a real external-project issue was found: Godot 4.7.2 `add_autoload_singleton()` made the Runtime bridge available in the editor session but did not immediately persist it to disk. `RuntimeDebuggerManager` now calls `ProjectSettings.save()` after adding/removing its reserved autoload and reports save failures instead of silently relying on later editor persistence.

Validation actually run with a project path containing spaces and Chinese characters:

```text
INSTALLER_CLEAN_INSTALL=PASS
INSTALLER_UPGRADE=PASS
INSTALLER_NO_ENABLE=PASS
INSTALLER_INVALID_PROJECT=PASS
INSTALLER_GODOT_4_7_2_LOAD=PASS
RUNTIME_AUTOLOAD_LIFECYCLE_NODE_SMOKE=PASS
INSTALLER_SMOKE=PASS version=0.4.0
```

The upgrade regression also verified that unrelated editor plugins are preserved, stale files inside the old `godot_mcp_chatgpt` addon are removed, the MCP plugin entry is not duplicated, CRLF is preserved in `project.godot`, and temporary install/backup directories are cleaned up. Public installer documentation was updated in README, Quick Start, CHANGELOG and SECURITY, including the unsigned/SmartScreen note and SHA-256 verification path.
### Task: Installer pre-commit release gates

Status: **release validation passed**.

Final pre-commit results after the installer, Runtime autoload persistence fix, public docs and payload hash regression:

```text
npm build: PASS
npm test: PASS
CATALOGUE_SCHEMA_GATE=PASS tools=119
PRODUCTION_PLUGIN_SMOKE=PASS
RUNTIME_AUTOLOAD_LIFECYCLE_NODE_SMOKE=PASS
INSTALLER_SMOKE=PASS version=0.4.0
installed addon full file-set/SHA-256 match: PASS
DIFF_CHECK=PASS
BOM_CHECK=PASS
INSTALLER_HARDCODE_CHECK=PASS
LINK_CHECK=PASS
NO_IMAGE_MARKUP=PASS
SECRET_CHECK=PASS fixtures=3 real=0
VERSION_CHECK=PASS 0.4.0
ARTIFACT_HYGIENE=PASS
INSTALLER_PRECOMMIT_GATES=PASS
```

### Task: GitHub Release v0.4.0 publication

Status: **complete**.

Published the validated Windows release at https://github.com/AAAYNMMM/godot-mcp-chatgpt/releases/tag/v0.4.0.

Release source/tag:

- source commit: `f12d268b5bca087ae8cef744f9cb7ab8877848e8`;
- remote tag `v0.4.0` resolves to the same commit;
- release is neither draft nor prerelease.

Uploaded assets:

```text
godot-mcp-chatgpt-v0.4.0-windows-x64-installer.exe
godot-mcp-chatgpt-v0.4.0-addon.zip
SHA256SUMS.txt
```

Final commit-based artifact validation:

```text
BUILD_COMMIT_CHECK=PASS f12d268b5bca
INSTALLER_SMOKE=PASS version=0.4.0
ADDON_ZIP_EXACT_CHECK=PASS files=46
SHA256SUMS_VERIFY=PASS
RELEASE_REMOTE_ASSET_VERIFY=PASS
```

The three assets were downloaded back from GitHub Release after upload and their SHA-256 values matched the locally validated artifacts byte-for-byte.

## 0.4.0 current blocker

No known 0.4.0 release blocker remains. The installer source is on `main`, tag `v0.4.0` points to the validated installer commit, and the GitHub Release assets were remotely re-downloaded and hash-verified.

## 0.4.0 exact next task

**0.4.0 is published. Wait for the user to choose the next development task.**
