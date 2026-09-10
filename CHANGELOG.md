# Changelog

English | [简体中文](CHANGELOG.zh-CN.md)

This changelog records released user-facing milestones and compatibility-impacting changes.

## 0.5.0 — Capability migration and compact MCP surface

Date: 2026-09-10

### Highlights

- Replaced the 119-flat-tool public catalogue with **47 default public tools** while expanding the internal registry to **230 atomic commands**.
- Added compact `*.manage` domain routing with full atomic-command coverage and a hard public limit below 50.
- Added MCP screenshots/image content for editor viewport, Camera3D/cinematic, running game, and TileSet atlas inspection.
- Added deterministic input/playtest operations, live logs, GDScript test runner, script anchor patching/diagnostics, Undo/Redo workflows, and reversible editor transactions.
- Added high-level content authoring for Animation, Material/Shader, Audio, Particle, Camera, Theme/UI, Curve/Gradient/Noise, Environment, and Physics Shapes.
- Added TileMap/TileSet, GridMap/MeshLibrary, and CSG world-authoring operations.
- Added opt-in third-party Custom Tools with addon/handler ownership binding, required safety hints, schema validation, bounded payloads, persistent enable/disable, and at most two promoted public tools.
- Intentionally did not migrate `godot://` MCP Resources, MCP client auto-config, Python/FastMCP server, or Godot AI's WebSocket bridge.

### Compatibility

This is a public tool-surface breaking change for clients that hard-code v0.4 tool names. Web ChatGPT normally re-discovers the live MCP catalogue. Internal atomic capabilities remain reachable through direct or managed public routes.

### Validation

```text
CATALOGUE_SCHEMA_GATE=PASS tools=47
COMPACT_TOOL_SURFACE_GATE=PASS public=47 atomic=230
PHASE_E_WORLD_EXTENSIBILITY=PASS
CAPABILITY_MIGRATION_MATRIX=PASS excluded=4 public=47 atomic=230
PRODUCTION_PLUGIN_SMOKE=PASS
FULL_OFFICIAL_TUNNEL_SMOKE=PASS
REAL_CHATGPT_GODOT_MCP_0_5_TEST=PASS
INSTALLER_CLEAN_INSTALL=PASS
INSTALLER_UPGRADE=PASS
INSTALLER_GODOT_4_7_2_LOAD=PASS
INSTALLED_ADDON_EXACT_MATCH=PASS files=70
```

The real Web ChatGPT Connector acceptance verified actual editor/runtime mutation and readback, screenshot image return and inspection, TileSet image content, world authoring, input injection, logs, tests, transactions, Custom Tool enable/schema/invoke/disable/promotion, and final cleanup.

### Known non-blocking observations

- One recoverable tunnel `network_error: Connection failed` occurred; the editor stayed online and immediate retry succeeded.
- Native Debugger operations may return `ok=true` while `debuggable=false` and have no effect.
- `editor.manage(op="stop")` can report unsupported while `stop_playing` succeeds.
## 0.4.0 — Full Godot editor/runtime MCP surface

Date: 2026-09-10

### Highlights

- Expanded the production MCP surface from **13 to 119 tools**.
- Added Project discovery/search/settings/autoload/plugin tools and InputMap editing.
- Added rich Scene/Node inspection and editing: open/close/reload/instantiate, properties, methods, groups, metadata and signals.
- Added Script introspection/validation/editor-state tools and Resource create/edit/save/duplicate/dependency tools.
- Added live Godot **ClassDB** introspection so ChatGPT can query the actual Godot 4.7.2 API instead of guessing from model memory.
- Added Editor state/control tools, Godot Debugger sessions, and a runtime bridge for live SceneTree/property/method/performance/pause/resume operations.
- Added bounded `diagnostics.run_capture` with separate stdout/stderr, exit code, timeout and duration.
- Added bounded non-atomic `batch.execute` with `stop_on_error` and recursion denial.
- Added Windows Credential Manager persistence for the Runtime API Key, automatic reconnect after restart, and **Forget Saved Credentials**.
- Added explicit Resource path validation and clearer `node.create.parent_path` schema guidance.
- Added a single-file Windows x64 project installer that embeds the addon, lets users select any Godot project, enables the plugin by default, and supports clean upgrades without hard-coded paths.
- Runtime autoload add/remove now calls `ProjectSettings.save()` so newly installed external projects persist the Runtime bridge immediately.

### Security / reliability

- Runtime API Key is stored as a Windows Generic Credential, not in the project, generated tunnel profile, EditorSettings, or Git.
- Tunnel ID remains in Godot EditorSettings.
- File/Resource operations remain bounded to `res://`; traversal and project-external paths are rejected.
- Runtime changes affect the live game instance and are not written back to the saved editor scene unless an editor-side tool explicitly changes/saves it.
- Runtime autoload lifecycle now handles Godot 4.7.2 `uid://` normalization and cleans up when the plugin is disabled.
- Production runner no longer contains test-mode fake credential hooks.

### Validation

Passed:

```text
Godot 4.7.2 addon load/compile
npm build + test
119-tool catalogue/schema gate
Official tunnel-client production smoke
Credential save -> restart auto-connect -> Forget -> restart
Runtime autoload disable/re-enable lifecycle
BOM / secret / diff / documentation-link gates
Real ChatGPT Connector full-surface regression
REAL_CHATGPT_GODOT_MCP_0_4_TEST=PASS
INSTALLER_SMOKE=PASS version=0.4.0
```

The real Connector regression exercised editor changes, runtime mutation/readback, diagnostics, Batch and security boundaries through ChatGPT itself.
## 0.3.0 — Official tunnel-client architecture

Date: 2026-09-09

### Highlights

- Switched production transport to the **official OpenAI `tunnel-client`**.
- Added a Godot-hosted loopback **Streamable HTTP MCP** server.
- Bundled the validated Windows `tunnel-client.exe` runtime with license/NOTICE.
- Kept the user flow at only **Tunnel ID + Runtime API Key**.
- Preserved non-persistence of Runtime API Key.
- Added `server/discover` and modern/legacy MCP compatibility behavior required by the official client path.
- Added HTTP `DELETE` session termination handling.
- Kept the initial focused 13-tool Godot surface.

### Validation

Passed:

```text
Godot 4.7.2 script compilation
Go MCP SDK v1.7 compatibility
Official tunnel-client bridge smoke
Real Godot 4.7.2 GUI production smoke
Real OpenAI Tunnel + ChatGPT connector creation
```

The real connector creation succeeded on 2026-09-09.

### Architecture change

Removed the production direct-GDScript implementation of OpenAI `/poll` + `/response`.

Production is now:

```text
ChatGPT
 -> OpenAI Secure MCP Tunnel
 -> official OpenAI tunnel-client
 -> Godot loopback Streamable HTTP MCP
 -> Godot Editor API
```

## 0.2.3 — Connector compatibility investigation

- Added `server/discover` compatibility to the earlier direct tunnel implementation.
- Confirmed that local protocol simulation alone was not enough to prove real ChatGPT connector compatibility.
- This version helped identify the need to compare against a known-good tunnel runtime.

## 0.2.2 — Editor panel usability

- Moved the connection UI to a visible Godot bottom panel named **MCP ChatGPT**.
- Improved the first-run user flow.

## 0.2.1 — Credential persistence hardening

- Stopped persisting Runtime API Key in Godot editor settings.
- Kept Tunnel ID persistence for convenience.

## 0.2.0 and earlier — Transport prototyping

- Built the initial Godot editor plugin and command registry.
- Added the first scene/node/script/editor tools.
- Explored a custom relay and later a direct GDScript Secure Tunnel client.
- These transport experiments were superseded by the 0.3.0 official-runtime architecture.