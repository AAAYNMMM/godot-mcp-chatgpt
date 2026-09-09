# Changelog

English | [简体中文](CHANGELOG.zh-CN.md)

This project is still early. The changelog records meaningful user-facing milestones rather than every internal experiment.

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