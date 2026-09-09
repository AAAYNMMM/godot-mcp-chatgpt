# Real OpenAI Secure MCP Tunnel Test

This is the next test that requires the user's own OpenAI Tunnel ID / Runtime API Key and ChatGPT connector UI.

Version `0.3.0` no longer implements the OpenAI tunnel protocol directly in GDScript. The addon launches the bundled official OpenAI `tunnel-client.exe`, which forwards the tunnel to a private loopback Streamable HTTP MCP server inside Godot.

## What the user needs

Only:

```text
Tunnel ID
Runtime API Key
```

Do not paste the Runtime API Key into chat or commit it to Git.

## 1. Open the Godot panel

Enable **Godot MCP ChatGPT** under Godot plugins if necessary.

Open the bottom panel:

```text
MCP ChatGPT
```

It contains Tunnel ID, Runtime API Key, Connect/Disconnect, status, and one short log line.

## 2. Enter the real credentials

Enter the same Tunnel ID that will be selected in ChatGPT.

Enter a dedicated restricted Runtime API Key with the tunnel permissions required by the current OpenAI setup.

Press **Connect**.

Expected successful startup states:

```text
starting
connected
```

In version 0.3.0, `connected` means the official tunnel-client child process started and remains alive. It does not by itself prove that ChatGPT has already discovered the tools.

Potential local failure states include:

```text
credentials_required
runtime_missing
registry_unavailable
local_mcp_error
profile_error
runtime_error
```

The Runtime API Key is not persisted by the addon.

## 3. Create the ChatGPT connector

In the ChatGPT/workspace UI that supports custom MCP over Secure Tunnel:

1. create/configure a connector;
2. choose **Connection: Tunnel**;
3. select or paste the same Tunnel ID;
4. let ChatGPT discover the MCP server/tools while Godot remains open.

The expected production path is:

```text
ChatGPT
 -> OpenAI Secure MCP Tunnel
 -> bundled official tunnel-client.exe
 -> Godot loopback Streamable HTTP MCP
 -> Godot editor tools
```

No CWapi process is part of this path.

## 4. First read test

Use the connector to call:

```text
godot.get_status
```

Expected data includes:

```text
godot_version: 4.7.2...
editor: true
project_name: ...
```

ChatGPT should discover 13 tools in the current build.

## 5. First visible write test

Use a disposable test location, not an important game scene.

Suggested calls:

```text
scene.create
  path: res://mcp_real_test/main.tscn
  root_type: Node3D
  root_name: MCPRealTest

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

Verify the scene and node visibly appear in the Godot editor.

## 6. What to report if creation still fails

Do **not** send the Runtime API Key.

Useful information:

- Godot panel state;
- the panel's last non-secret log message;
- exact ChatGPT connector error text/screenshot;
- whether the official `tunnel-client.exe` process is still running;
- non-secret Godot Output lines beginning with `[GodotMCPChatGPT]`.

If connector creation fails while the tunnel-client stays alive, the next debugging step is to expose/read the official tunnel-client readiness/health details rather than replacing the architecture again.

## 7. Security behavior to verify

The generated profile should contain:

```yaml
api_key: env:CONTROL_PLANE_API_KEY
```

It must not contain the plaintext Runtime API Key.

The addon stores the Tunnel ID in Godot EditorSettings but does not store the Runtime API Key.