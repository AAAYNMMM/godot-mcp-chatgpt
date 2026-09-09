# Quick Start

[English] | [简体中文](QUICKSTART.zh-CN.md)

This guide is written for users who want to get from a fresh Godot project to a working ChatGPT connector with the fewest moving parts.

## Requirements

Current tested setup:

- Windows x64;
- Godot 4.7.2 Standard x64;
- a Godot project you can edit;
- access to OpenAI Secure MCP Tunnel in the OpenAI/ChatGPT workspace you plan to use;
- a Tunnel ID;
- a restricted Runtime API Key for that tunnel.

You do **not** need CWapi, Node.js, Codex, Claude Desktop, Cursor, or another local MCP client at runtime.

## Step 1 — Install the addon

Place the addon at:

```text
<your-project>/addons/godot_mcp_chatgpt/
```

The folder must contain `plugin.cfg`.

In Godot open:

```text
Project -> Project Settings -> Plugins
```

Enable **Godot MCP ChatGPT**.

Expected result: a bottom panel named **MCP ChatGPT** appears.

## Step 2 — Prepare the OpenAI tunnel

Create or select a Secure MCP Tunnel in your OpenAI workspace.

Keep the Tunnel ID. It should look like a tunnel identifier, for example:

```text
tunnel_...
```

Create a dedicated restricted Runtime API Key for tunnel use. Do not reuse an admin key just because it is convenient.

Never commit the Runtime API Key or paste it into a public issue.

## Step 3 — Connect from Godot

Open the bottom **MCP ChatGPT** panel and enter:

```text
Tunnel ID
Runtime API Key
```

Press **Connect**.

Expected state:

```text
Status: connected
```

In version 0.4.0 this means the bundled official OpenAI `tunnel-client` process is alive and the local Godot MCP endpoint is available to it. After the first successful connection, the Runtime API Key is stored in Windows Credential Manager for automatic reconnect.

If the state does not become connected, jump to [FAQ](FAQ.md).

## Step 4 — Create the ChatGPT connector

In ChatGPT connector settings:

1. create a new connector;
2. select **Connection: Tunnel**;
3. choose or paste the same Tunnel ID;
4. create/save the connector while Godot remains open.

The 0.4.0 path has passed a full real ChatGPT Connector regression with all 119 tools discovered and exercised across editor/runtime workflows.

## Step 5 — Test read access first

Ask ChatGPT to use the connector and call:

```text
godot.get_status
```

A healthy result should include a Godot version beginning with `4.7.2` in the currently tested environment, plus editor/project information.

Then try:

```text
project.get_info
```

If these work, remote MCP discovery and read calls are healthy.

## Step 6 — Test a disposable write

Do not use an important production scene for the first write test.

Suggested safe sequence:

```text
scene.create
  path: res://mcp_test/main.tscn
  root_type: Node3D
  root_name: MCPTest

node.create
  parent_path: .
  type: Node3D
  name: RemoteNode

node.set_property
  node_path: RemoteNode
  property: position
  value: {"__godot_type":"Vector3","x":1,"y":2,"z":3}

scene.save
```

Verify in the visible Godot editor that:

- `main.tscn` exists;
- the root is `MCPTest`;
- `RemoteNode` exists;
- its position is `(1, 2, 3)`.

## Step 7 — Use it like a development tool

A productive request usually describes the desired result rather than micromanaging every tool call. For example:

```text
In the current Godot project, create a simple player test scene with a Node3D root,
a CharacterBody3D named Player, and attach a new GDScript that exposes move_speed.
Save it under res://prototype/player_test.tscn. Do not overwrite existing files.
```

The current surface contains 119 tools. If ChatGPT cannot inspect or change something, check the [Tool Reference](TOOL_REFERENCE.md) and the live tool schema before assuming the connection is broken.

## Disconnecting

Press **Disconnect** in the Godot panel before rotating credentials or changing tunnels.

On Windows 0.4.0, the Runtime API Key is stored in Windows Credential Manager after a successful connection, so the addon can automatically reconnect after restarting Godot. Use **Forget Saved Credentials** if you want to remove the stored key and Tunnel ID.

## First troubleshooting checks

If something fails, check in this order:

1. Is the Godot plugin enabled?
2. Does the bottom panel show `Status: connected`?
3. Is the ChatGPT connector using the exact same Tunnel ID?
4. Is Godot still open?
5. Does the Runtime API Key have the required tunnel permissions?
6. Can ChatGPT discover `godot.get_status`?
7. Is the requested operation part of the current 119-tool surface, and are you using the argument conventions in the Tool Reference?

More: [FAQ / Troubleshooting](FAQ.md).