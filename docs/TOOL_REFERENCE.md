# Tool Reference

[English] | [简体中文](TOOL_REFERENCE.zh-CN.md)

Version 0.3.0 exposes 13 focused tools. The surface is intentionally small: high-frequency editor work first, broad API coverage later.

## Read-only tools

### `godot.get_status`

Arguments: none.

Returns the connected Godot version, whether the call is running in the editor, and the current project name.

Example request:

```text
Use godot.get_status and summarize the current editor state.
```

### `project.get_info`

Arguments: none.

Returns:

- project name;
- absolute `project.godot` path;
- currently edited scene path, if any.

### `scene.get_tree`

Arguments:

| Name | Type | Required | Notes |
| --- | --- | --- | --- |
| `max_depth` | integer | no | 0-32, default 8 |

Returns a serialized view of the currently edited scene tree with node name, class and relative path.

### `script.read`

Arguments:

| Name | Type | Required |
| --- | --- | --- |
| `path` | string | yes |

`path` must remain inside `res://` and cannot contain `..` traversal.

Example:

```text
Read res://player/player.gd and explain what it currently does.
```

## Scene tools

### `scene.create`

Creates, saves and opens a new `.tscn` scene.

Arguments:

| Name | Type | Required | Notes |
| --- | --- | --- | --- |
| `path` | string | yes | Must be `res://...tscn` |
| `root_type` | string | no | Defaults to a basic node type in the implementation |
| `root_name` | string | no | Optional root name |
| `overwrite` | boolean | no | Defaults false |

Safety behavior: an existing scene is not replaced unless `overwrite: true` is explicitly passed.

Example:

```text
Create res://prototype/test.tscn with a Node3D root named TestRoot. Do not overwrite existing files.
```

### `scene.save`

Arguments:

| Name | Type | Required | Notes |
| --- | --- | --- | --- |
| `path` | string | no | Optional new `res://...tscn` path |

Without `path`, saves the currently edited scene to its existing location.

## Node tools

### `node.create`

Arguments:

| Name | Type | Required | Notes |
| --- | --- | --- | --- |
| `type` | string | yes | Godot class name, e.g. `Node3D` |
| `parent_path` | string | no | Relative to edited scene root; `.` means root |
| `name` | string | no | Optional node name |

Example:

```text
Add a CharacterBody3D named Player under the scene root.
```

### `node.set_property`

Arguments:

| Name | Type | Required |
| --- | --- | --- |
| `node_path` | string | yes |
| `property` | string | yes |
| `value` | any JSON-compatible value | yes |

Common Godot value types can use tagged objects. Example Vector3:

```json
{
  "__godot_type": "Vector3",
  "x": 1,
  "y": 2,
  "z": 3
}
```

Example request:

```text
Set Player.position to Vector3(1, 2, 3).
```

### `node.delete`

Arguments:

| Name | Type | Required |
| --- | --- | --- |
| `node_path` | string | yes |

The edited scene root cannot be deleted through this tool.

## Script tools

### `script.write`

Arguments:

| Name | Type | Required |
| --- | --- | --- |
| `path` | string | yes |
| `content` | string | yes |

Writes UTF-8 text inside `res://`.

Example:

```text
Write a new res://player/player.gd GDScript with an exported move_speed float, but do not modify unrelated files.
```

### `script.attach`

Arguments:

| Name | Type | Required |
| --- | --- | --- |
| `node_path` | string | yes |
| `script_path` | string | yes |

Attaches an existing `res://` Script resource to a node in the edited scene.

## Editor tools

### `editor.run_project`

Arguments: none.

Starts the project's main scene through Godot's editor API.

### `editor.stop`

Arguments: none.

Stops the currently running project or scene.

## Recommended request style

Good requests describe the outcome and constraints:

```text
Create a disposable test scene under res://prototype/. Use a Node3D root and add a Player node.
Write and attach a simple GDScript with move_speed = 5.0. Save the scene. Do not overwrite existing files.
```

Less useful requests manually dictate every RPC unless you are debugging the tool layer.

## Current limitations

0.3.0 does not yet expose dedicated tools for:

- opening arbitrary existing scenes;
- rich property enumeration;
- resources/materials;
- InputMap;
- signals;
- ClassDB lookup;
- editor/runtime error logs;
- screenshots;
- arbitrary shell commands.

See the [Development Plan](DEVELOPMENT_PLAN.md) for planned expansion.