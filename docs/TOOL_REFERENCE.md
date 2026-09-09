# Tool Reference

[English] | [简体中文](TOOL_REFERENCE.zh-CN.md)

Version **0.4.0** exposes **119 MCP tools**. This document is a human-readable index; the live `tools/list` JSON Schema remains authoritative for exact arguments.

## Core conventions

- Project file paths stay inside `res://`; traversal such as `res://../...` is rejected with `INVALID_PATH`.
- Edited-scene node paths are relative to the edited scene root. Use `.` for the root. For `node.create.parent_path`, do **not** pass the root node name.
- Runtime node paths are relative to the live current scene unless an absolute runtime path is explicitly supported by that tool.
- Runtime tools accept optional `session_id` and `timeout_ms` when multiple debugger sessions or custom timeouts matter.
- `batch.execute` is ordered and bounded, but **non-atomic**: successful earlier operations are not rolled back if a later operation fails.
- `diagnostics.run_capture` only launches the current Godot executable against the current project; it is not a general shell/process tool.

## Operational model and common failures

Before using a tool, identify which state it targets:

| Target | Typical tools | Requirement | Persists to project? |
| --- | --- | --- | --- |
| Editor project | `project.*`, `scene.*`, `node.*`, `script.*`, `resource.*` | Godot editor/plugin loaded | Usually yes when the tool saves/persists |
| Editor control | `editor.*` | Godot editor/plugin loaded | Depends on operation |
| Runtime | `runtime.*`, `debugger.*` | Active debugger/runtime session | No, unless a separate editor tool persists a change |
| Diagnostics | `diagnostics.run_capture` | Current Godot executable/project | No project mutation by the runner itself |
| Batch | `batch.execute` | Same requirements as nested tools | Depends on nested tools |

Common error codes:

| Code | Meaning / next action |
| --- | --- |
| `INVALID_PATH` | Path escaped `res://` or failed path validation. Use a project-relative `res://` path. |
| `NODE_NOT_FOUND` | Edited-scene/runtime node path did not resolve. Inspect the tree first. |
| `PROPERTY_NOT_FOUND` | Property is unavailable on that object/class. Inspect properties or ClassDB. |
| `METHOD_NOT_FOUND` | Method is unavailable. Inspect methods/ClassDB before calling. |
| `RUNTIME_NOT_RUNNING` | Start a scene/project and wait for an active debugger session. |
| `RUNTIME_REQUEST_TIMEOUT` | Runtime request did not complete in the timeout; inspect session/runtime state. |
| `ROOT_DELETE_DENIED` | The edited scene root cannot be deleted. |
| `BATCH_RECURSION_DENIED` | `batch.execute` cannot invoke itself recursively. |
| `BATCH_TOO_LARGE` | Split the request into smaller batches. |

For mutating workflows, inspect first and save deliberately. For runtime workflows, remember that runtime state and saved editor state are separate.
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

The 0.4.0 codec also handles many other common Variant types, arrays/dictionaries, resource references, and structured object summaries.

## Complete 119-tool index

### godot (1)

| Tool | Purpose |
| --- | --- |
| `godot.get_status` | Return the connected Godot editor status and version. |

### project (13)

| Tool | Purpose |
| --- | --- |
| `project.delete_file` | Delete a project file inside res://. |
| `project.find_files` | Find project files by glob-like pattern, extension, or substring. |
| `project.get_autoloads` | List configured project autoloads/singletons. |
| `project.get_info` | Return basic information about the currently open Godot project. |
| `project.get_plugins` | List editor plugins configured in project.godot. |
| `project.get_setting` | Read one ProjectSettings value. |
| `project.inspect` | Return a high-value overview of the current Godot project. |
| `project.list_directory` | List files and directories under a res:// path. |
| `project.list_settings` | List ProjectSettings names and values, optionally filtered by prefix. |
| `project.make_directory` | Create a directory inside res://. |
| `project.move_file` | Move or rename a project file inside res://. |
| `project.search_text` | Search text across project text files with file/line context. |
| `project.set_setting` | Set and persist one ProjectSettings value. |

### input_map (6)

| Tool | Purpose |
| --- | --- |
| `input_map.add_action` | Create or update an InputMap action and persist it. |
| `input_map.add_event` | Add a keyboard/mouse/joypad event to an InputMap action and persist it. |
| `input_map.clear_action_events` | Remove all events from an InputMap action and persist it. |
| `input_map.get_action` | Inspect one InputMap action. |
| `input_map.list` | List all InputMap actions with deadzones and events. |
| `input_map.remove_action` | Remove an InputMap action and persist it. |

### scene (12)

| Tool | Purpose |
| --- | --- |
| `scene.close` | Close the current edited scene. |
| `scene.create` | Create a new .tscn scene, save it under res://, and open it in the editor. |
| `scene.get_current` | Return the currently edited scene. |
| `scene.get_tree` | Return the edited scene tree with node names and classes. |
| `scene.get_unsaved` | List scenes with unsaved changes. |
| `scene.inspect` | Inspect scene structure with scripts, groups, metadata, signals and property summaries. |
| `scene.instantiate` | Instantiate a PackedScene into the current scene. |
| `scene.list_open` | List open editor scenes and roots. |
| `scene.open` | Open an existing .tscn scene in the editor. |
| `scene.reload` | Reload an open scene from disk. |
| `scene.save` | Save the currently edited scene. Optionally save to a new res:// .tscn path. |
| `scene.save_all` | Save all open scenes. |

### node (23)

| Tool | Purpose |
| --- | --- |
| `node.add_to_group` | Add a node to a group. |
| `node.call_method` | Call a method on a node with JSON-encoded arguments. |
| `node.connect_signal` | Connect a source node signal to a target node method. |
| `node.create` | Create a Godot node under a parent in the currently edited scene. |
| `node.delete` | Delete a non-root node from the currently edited scene. |
| `node.disconnect_signal` | Disconnect a source node signal from a target node method. |
| `node.duplicate` | Duplicate a node in the edited scene. |
| `node.find` | Find nodes by name substring, class, group or script path. |
| `node.get_groups` | List groups for a node. |
| `node.get_metadata` | List or read metadata from a node. |
| `node.get_methods` | List methods available on a node. |
| `node.get_properties` | Read node property metadata and values with filtering. |
| `node.get_property` | Read one node property. |
| `node.get_signal_connections` | List outgoing connections for one or all node signals. |
| `node.get_signals` | List signals exposed by a node. |
| `node.inspect` | Return rich information about one node. |
| `node.move_child` | Change a child node's order under its parent. |
| `node.remove_from_group` | Remove a node from a group. |
| `node.remove_metadata` | Remove node metadata. |
| `node.rename` | Rename a node. |
| `node.reparent` | Move a node under a new parent. |
| `node.set_metadata` | Set node metadata. |
| `node.set_property` | Set a property on a node in the currently edited scene. |

### script (10)

| Tool | Purpose |
| --- | --- |
| `script.attach` | Attach a res:// GDScript resource to a node in the edited scene. |
| `script.detach` | Detach the script from a node. |
| `script.get_info` | Inspect a script's base type, class name, properties, methods, signals and constants. |
| `script.get_unsaved` | List unsaved script-editor files. |
| `script.list_open` | List scripts currently open in the Godot script editor. |
| `script.read` | Read a UTF-8 script or text file inside res://. |
| `script.reload_open` | Reload open scripts from disk. |
| `script.save_all` | Save all open scripts. |
| `script.validate` | Parse/compile GDScript source without attaching it to a node. |
| `script.write` | Write UTF-8 GDScript or text content to a file inside res://. |

### resource (8)

| Tool | Purpose |
| --- | --- |
| `resource.call_method` | Call a method on a Resource and return the result. |
| `resource.create` | Create a Resource class, set initial properties and save it. |
| `resource.duplicate` | Duplicate a Resource to another path. |
| `resource.get_dependencies` | List ResourceLoader dependencies and UID information. |
| `resource.get_property` | Read one property from a Resource. |
| `resource.inspect` | Inspect a Resource, including properties, methods and signals. |
| `resource.save` | Save a loaded Resource, optionally to a new path. |
| `resource.set_property` | Set and save one Resource property. |

### classdb (9)

| Tool | Purpose |
| --- | --- |
| `classdb.can_instantiate` | Check whether a Godot class exists and can be instantiated. |
| `classdb.get_constants` | List integer constants for a Godot class. |
| `classdb.get_enums` | List enums and enum values for a Godot class. |
| `classdb.get_inheritance` | Return the inheritance chain for a Godot class. |
| `classdb.get_methods` | List methods for a Godot class. |
| `classdb.get_properties` | List properties for a Godot class. |
| `classdb.get_signals` | List signals for a Godot class. |
| `classdb.inspect` | Inspect a Godot class: inheritance, properties, methods, signals, constants and enums. |
| `classdb.search` | Search Godot ClassDB classes by substring with inheritance and instantiability. |

### editor (20)

| Tool | Purpose |
| --- | --- |
| `editor.clear_selection` | Clear the current scene-node selection. |
| `editor.close_script` | Close a script file in the Godot Script editor. |
| `editor.get_filesystem_state` | Return Godot editor filesystem scan/import state and current FileSystem selection. |
| `editor.get_playing_scene` | Return the scene path currently being played by the editor. |
| `editor.get_script_state` | Return open/current/unsaved scripts in the Script editor. |
| `editor.get_selection` | Return selected scene nodes and FileSystem paths. |
| `editor.inspect` | Return a high-value snapshot of the Godot editor state. |
| `editor.is_playing` | Return whether the editor is currently running a game scene. |
| `editor.open_script` | Open a project script in the Godot Script editor at an optional line and column. |
| `editor.reimport_files` | Reimport one or more project resource files through the Godot editor filesystem. |
| `editor.run_current_scene` | Run the currently edited scene. |
| `editor.run_custom_scene` | Run a specific res:// .tscn scene. |
| `editor.run_main_scene` | Run the project's configured main scene. |
| `editor.run_project` | Run the project's main scene from the Godot editor. |
| `editor.save_all` | Save all open scenes and scripts. |
| `editor.scan_filesystem` | Ask the Godot editor filesystem to rescan project files. |
| `editor.select_file` | Select a res:// file in the Godot FileSystem dock. |
| `editor.set_selection` | Replace or extend the selected scene nodes by path. |
| `editor.stop` | Stop the currently running project or scene. |
| `editor.stop_playing` | Stop the scene currently being played by the Godot editor. |

### debugger (4)

| Tool | Purpose |
| --- | --- |
| `debugger.get_breakpoints` | Return breakpoints currently known by the Godot Script editor. |
| `debugger.get_sessions` | Return active Godot debugger sessions and break/debuggable state. |
| `debugger.set_breakpoint` | Enable or disable a breakpoint in an active debugger session. |
| `debugger.toggle_profiler` | Enable or disable a named Godot debugger profiler in an active session. |

### runtime (11)

| Tool | Purpose |
| --- | --- |
| `runtime.call_method` | Call a method on a live runtime node with structured arguments. |
| `runtime.find` | Find live runtime nodes by name substring, class, or group. |
| `runtime.get_groups` | Return groups for a live runtime node. |
| `runtime.get_performance` | Return selected live Godot Performance monitors. |
| `runtime.get_property` | Read one property from a live runtime node. |
| `runtime.get_tree` | Return the live runtime SceneTree under current_scene. |
| `runtime.inspect` | Inspect one live runtime node, including properties/groups/script. |
| `runtime.pause` | Pause the running SceneTree. |
| `runtime.resume` | Resume a paused running SceneTree. |
| `runtime.set_property` | Set one property on a live runtime node. This affects the running instance, not the saved scene. |
| `runtime.status` | Inspect the connected running game's status. |

### diagnostics (1)

| Tool | Purpose |
| --- | --- |
| `diagnostics.run_capture` | Run the current Godot project in a bounded child process and capture stdout, stderr, exit state, duration, and timeout state separately. |

### batch (1)

| Tool | Purpose |
| --- | --- |
| `batch.execute` | Execute a bounded sequence of existing Godot MCP tools in order. This is non-atomic and does not roll back earlier successful operations. |

## Important workflows

### Create under the scene root

For `node.create`, use:

```json
{
  "parent_path": ".",
  "type": "CharacterBody3D",
  "name": "Player"
}
```

The edited-scene root name itself is not a relative child path.

### Inspect before editing

For unfamiliar projects, prefer high-value aggregate reads first:

```text
project.inspect
scene.inspect
node.inspect
script.get_info
classdb.inspect
```

Then use focused property/search tools only where needed. This reduces MCP round trips and avoids guessing Godot APIs from model memory.

### Runtime debugging

A typical runtime loop is:

```text
editor.run_current_scene
debugger.get_sessions
runtime.status
runtime.get_tree
runtime.get_property / runtime.set_property
runtime.call_method
runtime.get_performance
editor.stop_playing
```

Runtime property changes affect the live instance. The real 0.4.0 Connector regression verified that a live `Player.position` change did not leak back into the saved editor scene.

### Captured diagnostics

`diagnostics.run_capture` returns separate stdout/stderr, exit code, timeout state, duration, and truncation state. Use it when you need a bounded run whose output ChatGPT can inspect directly.

### Batch

`batch.execute` accepts a bounded ordered list of existing MCP tool calls and supports `stop_on_error`. Recursive `batch.*` invocation is rejected with `BATCH_RECURSION_DENIED`.

## Safety boundaries

0.4.0 regression coverage includes:

- `res://../...` traversal rejection;
- project-external path rejection;
- edited-scene root delete denial;
- invalid Node class/property/method rejection;
- Resource path validation before load/save;
- bounded diagnostics child processes;
- bounded, non-recursive Batch execution;
- no generic arbitrary shell MCP tool.

## Validation

The complete real ChatGPT Connector regression on 2026-09-10 discovered all **119 tools** and ended with:

```text
REAL_CHATGPT_GODOT_MCP_0_4_TEST=PASS
```

See [Examples](EXAMPLES.md), [Quick Start](QUICKSTART.md), and [Security](../SECURITY.md).
