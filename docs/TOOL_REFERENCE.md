# Tool Reference

English | [简体中文](TOOL_REFERENCE.zh-CN.md)

Version **0.5.0** exposes **47 default public MCP tools** backed by **230 internal atomic commands**. The live `tools/list` JSON Schema is authoritative for exact arguments, managed-operation enums, and annotations.

## Compact surface model

v0.5 separates the public MCP catalogue from the internal atomic command registry:

- **31 direct tools** cover the highest-frequency inspect/edit/run/test paths.
- **16 `*.manage` tools** route long-tail operations through a bounded `op` enum plus `params` object.
- every internal atomic command is reachable through at least one public route;
- default public count is 47; enabled third-party Custom Tools may promote at most two additional tools, keeping the hard limit below 50;
- callers that hard-code v0.4's 119 flat public names must migrate to the v0.5 compact surface.

For `*.manage`, choose an `op` advertised by the live schema. `params` is then validated against the selected atomic command's own schema before execution.

## Core conventions

- Project file paths stay inside `res://`; traversal such as `res://../...` is rejected.
- Edited-scene node paths are relative to the edited scene root; use `.` for the root.
- Runtime node paths are relative to the live current scene unless an absolute runtime path is explicitly supported.
- Runtime calls may accept `session_id`/`timeout_ms` where the selected operation supports them.
- `batch.execute` is bounded and non-atomic.
- `batch.execute_transaction` only claims rollback for operations classified as reversible.
- `diagnostics.run_capture` only launches the current Godot executable against the current project; it is not an arbitrary shell/process tool.
- Screenshot tools return bounded MCP image content.
- Custom tools are addon-owned, schema-validated, explicitly safety-annotated, and disabled by default.

## Public direct tools (31)

| Tool | Role |
| --- | --- |
| `godot.get_status` | Direct high-frequency operation |
| `project.inspect` | Direct high-frequency operation |
| `project.search_text` | Direct high-frequency operation |
| `scene.get_current` | Direct high-frequency operation |
| `scene.get_tree` | Direct high-frequency operation |
| `scene.open` | Direct high-frequency operation |
| `scene.save` | Direct high-frequency operation |
| `node.create` | Direct high-frequency operation |
| `node.find` | Direct high-frequency operation |
| `node.get_properties` | Direct high-frequency operation |
| `node.set_property` | Direct high-frequency operation |
| `script.read` | Direct high-frequency operation |
| `script.write` | Direct high-frequency operation |
| `script.patch` | Direct high-frequency operation |
| `script.validate` | Direct high-frequency operation |
| `script.attach` | Direct high-frequency operation |
| `classdb.search` | Direct high-frequency operation |
| `editor.take_screenshot` | Direct high-frequency operation |
| `editor.run_project` | Direct high-frequency operation |
| `editor.run_custom_scene` | Direct high-frequency operation |
| `runtime.status` | Direct high-frequency operation |
| `runtime.get_tree` | Direct high-frequency operation |
| `runtime.inspect` | Direct high-frequency operation |
| `runtime.get_property` | Direct high-frequency operation |
| `runtime.set_property` | Direct high-frequency operation |
| `runtime.call_method` | Direct high-frequency operation |
| `diagnostics.run_capture` | Direct high-frequency operation |
| `batch.execute` | Direct high-frequency operation |
| `batch.execute_transaction` | Direct high-frequency operation |
| `logs.read` | Direct high-frequency operation |
| `test.run` | Direct high-frequency operation |

## Managed domain tools (16)

| Tool | Role |
| --- | --- |
| `project.manage` | Long-tail domain operations via `op` + `params` |
| `input_map.manage` | Long-tail domain operations via `op` + `params` |
| `scene.manage` | Long-tail domain operations via `op` + `params` |
| `node.manage` | Long-tail domain operations via `op` + `params` |
| `script.manage` | Long-tail domain operations via `op` + `params` |
| `resource.manage` | Long-tail domain operations via `op` + `params` |
| `classdb.manage` | Long-tail domain operations via `op` + `params` |
| `editor.manage` | Long-tail domain operations via `op` + `params` |
| `debugger.manage` | Long-tail domain operations via `op` + `params` |
| `runtime.manage` | Long-tail domain operations via `op` + `params` |
| `logs.manage` | Long-tail domain operations via `op` + `params` |
| `test.manage` | Long-tail domain operations via `op` + `params` |
| `autoload.manage` | Long-tail domain operations via `op` + `params` |
| `content.manage` | Long-tail domain operations via `op` + `params` |
| `world.manage` | Long-tail domain operations via `op` + `params` |
| `custom.manage` | Long-tail domain operations via `op` + `params` |

### Important managed domains

- `content.manage`: high-level Animation, Material/Shader, Audio, Particle, Camera, Theme/UI, Curve/Gradient/Noise, Environment, and Physics Shape authoring.
- `world.manage`: TileMap/TileSet, GridMap/MeshLibrary, and CSG authoring/inspection.
- `autoload.manage`: autoload mutation and inspection.
- `logs.manage`: log cursor/filter/clear and related long-tail log operations.
- `test.manage`: test discovery and long-tail test-runner operations.
- `custom.manage`: list/get/invoke/enable-disable of registered third-party tools.
- `debugger.manage`: debugger session/breakpoint/profiler/native-debugger operations where the current Godot runtime exposes them.

## Godot value encoding

Common non-JSON Godot values use tagged objects. Example `Vector3`:

```json
{
  "__godot_type": "Vector3",
  "x": 1,
  "y": 2,
  "z": 3
}
```

The shared codec also handles common Vector/Transform/Color/NodePath values, arrays/dictionaries, resource references, and structured object summaries.

## Typical workflows

### Inspect → edit → validate → run

```text
project.inspect
scene.get_tree
classdb.search
node.set_property / script.patch
scene.save
script.validate
editor.run_project
runtime.inspect
logs.read
editor.take_screenshot
```

### Transactional editor change

Use `batch.execute_transaction` when every requested mutation is reversible. If a later reversible step fails, earlier reversible steps are rolled back. Do not use it to claim rollback for irreversible operations.

### World authoring

Use `world.manage` and select an advertised TileMap/TileSet, GridMap, or CSG `op`. The v0.5 real Connector acceptance verified cell/item mutation, bounded reads, Undo/Redo, atlas metadata/image content, MeshLibrary listing, and CSG operation changes.

### Third-party Custom Tools

Custom tools register from a real addon, must bind handlers to that addon, declare `read_only` and `destructive` safety properties, and start disabled. Enabled promoted tools can appear dynamically as `custom.<name>`; disabling them removes the promoted public entry again.

## Safety boundaries

v0.5 regression coverage includes path traversal/project-external rejection, resource/path validation, scene-root deletion denial, bounded diagnostics/images/input/log/test payloads, transaction rollback classification, Custom Tool ownership/schema/enablement checks, and no generic arbitrary-shell MCP tool.

## Real validation

The final real Web ChatGPT Connector regression on **2026-09-10** used Godot **4.7.2-stable (official)** and verified the compact surface through the actual Web ChatGPT → Secure MCP Tunnel → Godot Editor/Runtime path. It included real screenshot image content and Custom Tool promotion from 47 to 48 tools, then back to 47 after disable.

```text
CATALOGUE_SCHEMA_GATE=PASS tools=47
COMPACT_TOOL_SURFACE_GATE=PASS public=47 atomic=230
REAL_CHATGPT_GODOT_MCP_0_5_TEST=PASS
```

See [Examples](EXAMPLES.md), [Quick Start](QUICKSTART.md), and [Security](../SECURITY.md).
