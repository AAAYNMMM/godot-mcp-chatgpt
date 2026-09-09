# Real OpenAI Secure MCP Tunnel Test

This is the first test that cannot be fully automated without the user's own OpenAI tunnel/runtime credentials and ChatGPT connector UI.

## What the Godot addon needs

Only two values:

```text
Tunnel ID
Runtime API Key
```

Do not paste the Runtime API Key into a ChatGPT conversation or commit it to Git.

## 1. Create or select a tunnel

Open:

```text
https://platform.openai.com/settings/organization/tunnels
```

Create or select the tunnel that will be used for this Godot editor instance.

The resulting identifier looks like a tunnel ID and must be the same tunnel selected later in ChatGPT.

## 2. Create a Runtime API Key

Open:

```text
https://platform.openai.com/settings/organization/api-keys
```

Create a **Restricted** runtime key for the user/principal that will run Godot.

Minimum tunnel permissions according to the current OpenAI tunnel-client documentation:

```text
Tunnels: Read
Tunnels: Use
```

Do not use an Admin API key as the long-lived Godot runtime credential.

## 3. Connect Godot

Enable the addon and open the **Godot MCP ChatGPT** dock.

Enter locally:

```text
Tunnel ID: <your tunnel id>
API Key:   <your restricted runtime key>
```

Press **Connect**.

Expected states:

```text
connecting
connected
```

Common error states:

```text
credentials_required
authentication_failed
tunnel_not_found
connection_error
reconnecting
```

The API key is masked in the dock and must not be printed to the Godot output log.

## 4. Attach ChatGPT to the same tunnel

Open:

```text
https://chatgpt.com/#settings/Connectors
```

In a product/workspace that supports Secure MCP Tunnel connectors:

1. create/configure the connector;
2. choose **Connection: Tunnel**;
3. select or paste the same Tunnel ID;
4. scan/discover tools while the Godot editor remains open.

The Godot addon itself replaces the normal `tunnel-client run ...` process, so no separate tunnel-client executable should be running for this tunnel during the test.

## 5. First read test

Ask ChatGPT to call:

```text
godot.get_status
```

Expected result includes:

```text
godot_version: 4.7.2...
editor: true
project_name: ...
```

## 6. First visible write test

Use a disposable test path, not an important game scene.

Suggested sequence:

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

Verify the scene and node visibly appear in Godot.

## 7. What to report back after the test

Do **not** send the API key.

Useful information:

- whether Godot dock reached `connected`;
- whether ChatGPT discovered all 13 tools;
- exact error text/status if discovery failed;
- result of `godot.get_status`;
- whether the disposable scene/node appeared in Godot;
- relevant Godot log lines that do not contain secrets.

## Product availability note

Secure MCP Tunnel and full custom MCP capabilities are controlled by OpenAI product/plan/workspace permissions and may change over time. If **Connection: Tunnel** is absent or disabled, verify current product availability and workspace permissions before changing the Godot protocol implementation.
