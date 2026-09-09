# OpenAI Secure MCP Tunnel Setup

English | [简体中文](SECURE_TUNNEL.zh-CN.md)

Version `0.4.0` uses the bundled official OpenAI `tunnel-client.exe` and a loopback Streamable HTTP MCP server hosted by Godot.

The real production connector path and full 119-tool surface were successfully validated through ChatGPT on **2026-09-10**.

## Production path

```text
ChatGPT
 -> OpenAI Secure MCP Tunnel
 -> bundled official tunnel-client.exe
 -> Godot loopback Streamable HTTP MCP
 -> Godot editor tools
```

CWapi is not part of the runtime path.

## What the user needs

Only:

```text
Tunnel ID
Runtime API Key
```

Never paste the Runtime API Key into chat, Git, screenshots or public issues.

## 1. Enable the addon

In Godot:

```text
Project -> Project Settings -> Plugins
```

Enable **Godot MCP ChatGPT**.

Open the bottom panel:

```text
MCP ChatGPT
```

## 2. Enter the tunnel credentials

Enter the same Tunnel ID that you will later select in ChatGPT.

Enter a dedicated restricted Runtime API Key with the tunnel permissions required by your OpenAI workspace.

Press **Connect**.

Expected state transition:

```text
starting
connected
```

In 0.4.0, `connected` means the local MCP server is running and the official tunnel-client child process remains alive. The final confirmation is successful tool discovery/calls from ChatGPT.

After the first successful Windows connection, the Runtime API Key is stored in Windows Credential Manager as a Generic Credential. It is not written into the project, EditorSettings, Git, or the generated tunnel profile.

## 3. Create the ChatGPT connector

In ChatGPT connector settings:

1. create a connector;
2. choose **Connection: Tunnel**;
3. select or paste the same Tunnel ID;
4. keep Godot open while the connector is created and used.

This exact path passed a full real 0.4.0 ChatGPT Connector regression.

## 4. Verify tool discovery

The current 0.4.0 build should expose **119 tools**.

Start with:

```text
godot.get_status
```

Expected result includes:

```text
godot_version: 4.7.2...
editor: true
project_name: ...
```

Then try:

```text
project.get_info
```

## 5. Verify a visible write

Use a disposable path:

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

Verify directly in Godot that the scene and node appear.

## What the addon does automatically

When you press Connect, the addon:

1. starts a private loopback MCP server on `127.0.0.1`;
2. selects a random high port;
3. generates a random MCP URL path;
4. generates a tunnel-client profile;
5. writes only `api_key: env:CONTROL_PLANE_API_KEY` into that profile;
6. starts the bundled official tunnel-client;
7. removes the key from the parent Godot environment after child startup;
8. monitors the tunnel process and cleans up on disconnect.

## Generated profile shape

Conceptually:

```yaml
config_version: 1
control_plane:
  tunnel_id: <tunnel id>
  api_key: env:CONTROL_PLANE_API_KEY
health:
  listen_addr: 127.0.0.1:0
admin_ui:
  open_browser: false
mcp:
  server_urls:
    - channel: main
      url: http://127.0.0.1:<random>/mcp/<random>
```

The plaintext Runtime API Key must not appear in the profile.

## Local failure states

The panel can surface states such as:

```text
credentials_required
runtime_missing
registry_unavailable
local_mcp_error
profile_error
runtime_error
```

If the panel reaches `connected` but ChatGPT cannot discover tools, use [FAQ / Troubleshooting](FAQ.md).

## What to include in a bug report

Do not send the Runtime API Key.

Useful information:

- Godot version;
- plugin version/commit;
- panel state;
- last non-secret panel log message;
- whether ChatGPT connector creation succeeded;
- discovered tool count;
- exact non-secret error text;
- non-secret Godot Output lines beginning with `[GodotMCPChatGPT]`.

## Security checks

A healthy setup should satisfy:

- local MCP address is `127.0.0.1`;
- local port/path are generated per run;
- profile contains `env:CONTROL_PLANE_API_KEY`, not the key;
- Tunnel ID is persisted in Godot EditorSettings;
- Runtime API Key is persisted in Windows Credential Manager after successful connection;
- restart can auto-connect using the saved Tunnel ID + Credential Manager key; use **Forget Saved Credentials** to remove both.