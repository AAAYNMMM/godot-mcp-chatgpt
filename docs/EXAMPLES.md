# Practical Examples

English | [简体中文](EXAMPLES.zh-CN.md)

These examples are written as **normal user requests**, not raw MCP calls. ChatGPT can choose the appropriate tools from the current tool surface.

## 1. Check what is open

```text
Use the Godot connector to inspect the current editor.
Tell me the Godot version, project name, currently edited scene, and the scene tree up to depth 4.
Do not modify anything.
```

Useful tools: `godot.get_status`, `project.get_info`, `scene.get_tree`.

## 2. Create a disposable 3D test scene

```text
Create a new disposable scene at res://mcp_test/basic_3d.tscn.
Use Node3D as the root and name it Basic3DTest.
Add a Node3D child named Marker at position (1, 2, 3).
Save the scene. Do not overwrite an existing file.
```

## 3. Create a player scene with GDScript

```text
Create res://prototype/player_test.tscn with a Node3D root named PlayerTest.
Add a CharacterBody3D child named Player.
Create res://prototype/player.gd with an exported float move_speed defaulting to 5.0,
and attach the script to Player.
Save the scene.
Do not touch files outside res://prototype/ and do not overwrite existing files.
```

This demonstrates scene, node and script tools in one workflow.

## 4. Read a script before changing anything

```text
Read res://player/player.gd first.
Explain its current responsibilities and list the smallest safe change needed to add move_speed.
Do not write any files yet.
```

This is a good pattern for important projects: inspect first, mutate second.

## 5. Make a constrained script edit

```text
Read res://player/player.gd.
Then update only that file so it has an exported float move_speed = 5.0.
Preserve unrelated code and do not create or modify other files.
```

Current limitation: `script.write` writes full file content, so asking ChatGPT to read first is important when preserving existing code.

## 6. Add a node to the current scene

```text
Inspect the current scene tree.
If there is a root scene open, add a Node3D child named SpawnPoint under the root.
Set SpawnPoint.position to (0, 1, 0), then save the current scene.
Do not create a new scene if none is open; report that instead.
```

## 7. Run the project

```text
Check which project is connected, then run the project's main scene.
Do not modify any files.
```

When finished:

```text
Stop the currently running Godot project.
```

## 8. Ask for a safe prototype, not a giant rewrite

Good:

```text
Build a minimal test scene under res://prototype/ that proves the movement structure works.
Keep it isolated from existing game scenes and do not overwrite anything.
```

Riskier:

```text
Rewrite my whole project architecture.
```

The current tool set is best at **small, visible, verifiable editor changes**.

## 9. Give ChatGPT explicit safety constraints

Useful phrases:

```text
Do not overwrite existing files.
Read the file before changing it.
Only work under res://prototype/.
Do not delete nodes.
Use a disposable scene.
Stop and report if the required tool is not available.
```

These constraints complement the addon's built-in safeguards.

## 10. Diagnose whether a problem is connection or capability

```text
First call godot.get_status.
Then list the current scene tree.
If both work, tell me whether my requested operation is unsupported by the current tool set rather than treating it as a connection failure.
```

See [Tool Reference](TOOL_REFERENCE.md) for the exact current capability boundary.