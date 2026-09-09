# v0.4.0 Release Record

English | [简体中文](DEVELOPMENT_0.4.zh-CN.md)

Status: **complete / released**
Release date: **2026-09-10**
Release tag: **`v0.4.0`**
Release source commit: **`f12d268b5bca087ae8cef744f9cb7ab8877848e8`**

This is a **closed technical record** for v0.4.0. It is not an active WIP tracker.

## 1. Release goal

Turn the earlier tunnel proof-of-concept into a self-contained, user-installable Godot MCP product for Web ChatGPT:

```text
Web ChatGPT
  ↓
OpenAI Secure MCP Tunnel
  ↓
official bundled tunnel-client
  ↓
Godot loopback Streamable HTTP MCP
  ↓
Godot editor/runtime tool surface
```

## 2. Architecture decision

v0.4.0 keeps the production transport decision established in 0.3.0:

- do not reimplement the OpenAI tunnel wire protocol in GDScript;
- bundle and launch the official OpenAI `tunnel-client`;
- host the MCP server inside Godot on loopback;
- keep Godot editor/runtime operations in the plugin;
- expose a direct MCP tool surface to ChatGPT.

This architecture is considered the release baseline.

## 3. Shipped capability

v0.4.0 exposes **119 tools**:

| Family | Count |
| --- | ---: |
| godot | 1 |
| project | 13 |
| input_map | 6 |
| scene | 12 |
| node | 23 |
| script | 10 |
| resource | 8 |
| classdb | 9 |
| editor | 20 |
| debugger | 4 |
| runtime | 11 |
| diagnostics | 1 |
| batch | 1 |
| **Total** | **119** |

The full index is in [Tool Reference](TOOL_REFERENCE.md).

## 4. Credential lifecycle

The Runtime API Key:

- is stored in Windows Credential Manager after successful connection;
- is not stored in `project.godot`, EditorSettings, the generated tunnel profile, or Git;
- can be reused for automatic reconnect;
- can be removed with **Forget Saved Credentials**.

Tunnel ID and key use the plugin's own credential/settings namespace and do not reuse CWapi data.

## 5. Runtime debugger

v0.4.0 adds an editor-to-runtime bridge:

```text
MCP tool
  ↓
EditorPlugin
  ↓
EditorDebuggerPlugin / session
  ↓
EngineDebugger message channel
  ↓
runtime_bridge.gd
  ↓
live SceneTree
```

Supported release behavior includes:

- runtime tree/status;
- node inspection/find;
- property read/write;
- method calls;
- groups;
- performance values;
- pause/resume;
- debugger sessions/breakpoints/profiler controls.

Runtime mutations remain runtime-only unless an editor-side tool separately changes/saves the project.

## 6. Diagnostics and Batch

`diagnostics.run_capture`:

- launches only the current Godot executable/current project;
- captures stdout/stderr separately;
- returns exit code, timeout state, duration, and bounded output;
- is not a general shell MCP tool.

`batch.execute`:

- executes registered MCP tools sequentially;
- is bounded to 50 operations;
- supports `stop_on_error`;
- rejects recursive Batch;
- is non-atomic and has no rollback guarantee.

## 7. Installer and release artifacts

v0.4.0 includes:

```text
godot-mcp-chatgpt-v0.4.0-windows-x64-installer.exe
godot-mcp-chatgpt-v0.4.0-addon.zip
SHA256SUMS.txt
```

Installer behavior:

- user selects any target `project.godot`;
- no user/project path is hard-coded;
- installs only into the selected project;
- enables the plugin by default;
- supports clean upgrade replacement;
- preserves unrelated editor plugins;
- uses staging/backup/rollback behavior;
- cleans temporary install data.

During installer validation, Runtime autoload persistence was hardened with `ProjectSettings.save()` after add/remove.

## 8. Security boundaries

Release boundaries include:

- `res://`-only file/resource mutation;
- traversal rejection;
- edited-scene root delete denial;
- explicit scene overwrite;
- loopback-only local MCP;
- bounded Diagnostics;
- bounded non-atomic Batch;
- protected Windows credential storage;
- no arbitrary shell MCP surface.

See [Security](../SECURITY.md).

## 9. Validation record

Actually passed:

```text
Godot 4.7.2 addon load/compile
npm build
npm test
CATALOGUE_SCHEMA_GATE=PASS tools=119
PRODUCTION_PLUGIN_SMOKE=PASS
REAL_CHATGPT_GODOT_MCP_0_4_TEST=PASS
RUNTIME_AUTOLOAD_LIFECYCLE_NODE_SMOKE=PASS
INSTALLER_CLEAN_INSTALL=PASS
INSTALLER_UPGRADE=PASS
INSTALLER_NO_ENABLE=PASS
INSTALLER_INVALID_PROJECT=PASS
INSTALLER_GODOT_4_7_2_LOAD=PASS
INSTALLER_SMOKE=PASS version=0.4.0
ADDON_ZIP_EXACT_CHECK=PASS files=46
SHA256SUMS_VERIFY=PASS
RELEASE_REMOTE_ASSET_VERIFY=PASS
BOM_CHECK=PASS
SECRET_CHECK=PASS real=0
LINK_CHECK=PASS
NO_IMAGE_MARKUP=PASS
```

## 10. Resolved release follow-ups

- invalid Resource source paths return `INVALID_PATH`;
- `node.create.parent_path` explicitly documents `.` as the edited-scene root;
- Runtime autoload add/remove persists immediately;
- the one-click installer handles spaces and Unicode project paths;
- installer upgrade removes stale addon files without deleting unrelated plugins.

## 11. Known non-blocking limitations

- Windows x64 only packaged/verified;
- Godot 4.7.2 is the verified baseline;
- installer is unsigned;
- screenshot/input/frame-step playtest tooling is not part of 0.4.0;
- one transient scene-activation observation and one transient MCP network failure from the real regression were not reproducible.

## 12. Closure

There is **no open v0.4.0 release blocker**.

Future work belongs in [Development Plan](DEVELOPMENT_PLAN.md), not in this closed release record.