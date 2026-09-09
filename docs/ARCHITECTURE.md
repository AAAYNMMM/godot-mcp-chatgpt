# Architecture

## Locked production topology

As of version `0.3.0`, the production architecture is:

```text
ChatGPT / supported OpenAI MCP product
              |
              | MCP over OpenAI Secure MCP Tunnel
              v
      OpenAI tunnel service
              |
              v
 official OpenAI tunnel-client
    (bundled child process)
              |
              | Streamable HTTP MCP
              | 127.0.0.1:<random>/<random-path>
              v
   local_mcp_server.gd
              |
              v
      CommandRegistry
              |
              v
        Godot Editor
```

The key design decision is that **Godot does not implement the OpenAI tunnel wire protocol**. The official OpenAI `tunnel-client` is the tunnel implementation. This mirrors the working CWapi connection pattern that was inspected during development.

## Why this architecture

An earlier build implemented OpenAI control-plane polling and response posting directly in GDScript. It could pass a local simulator but ChatGPT connector creation failed in production. Inspection of CWapi showed the important difference: CWapi launches the official OpenAI tunnel client and exposes a local Streamable HTTP MCP server to it.

Version 0.3.0 therefore replaced the custom tunnel implementation with the same pattern.

Benefits:

- no project-operated public relay;
- no reimplementation of OpenAI tunnel compatibility details;
- user still provides only Tunnel ID + Runtime API Key;
- tunnel behavior follows the official runtime;
- Godot-specific calls remain in-process after the one loopback MCP hop;
- the loopback MCP endpoint is not exposed outside the machine.

## Official tunnel-client process

`tunnel_client_runner.gd`:

1. validates the two user inputs;
2. starts a loopback MCP server;
3. writes a private profile containing the Tunnel ID and local MCP URL;
4. writes `api_key: env:CONTROL_PLANE_API_KEY`, never the plaintext key;
5. temporarily places the key in the Godot process environment;
6. starts the bundled official `tunnel-client.exe` with `run --profile-file ...`;
7. removes the key from the Godot process environment immediately after child creation;
8. watches the child process and tears down the local MCP server on disconnect/exit.

The generated profile shape intentionally matches the CWapi pattern:

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

A development-only environment override can set a non-production control-plane URL for protocol simulation. Normal users never configure this.

## Local Streamable HTTP MCP

`local_mcp_server.gd` is a small loopback-only MCP server implemented with Godot `TCPServer`/`StreamPeerTCP`.

Properties:

- bind address: `127.0.0.1` only;
- random high port per run;
- random path token per run;
- maximum request body limit;
- request processing serialized to protect mutable editor state;
- supports normal JSON and SSE response forms expected by Streamable HTTP clients;
- supports notification acknowledgement and session termination.

Implemented MCP methods:

- `server/discover`
- `initialize`
- `ping`
- `tools/list`
- `tools/call`
- no-ID lifecycle notifications
- HTTP `DELETE` session termination

`server/discover` advertises the versions supported by the current Go MCP SDK/tunnel-client compatibility path, including the modern `2026-07-28` protocol and older compatible versions.

## Godot command boundary

The current 13 tools are deliberately focused on the minimum useful editor-development loop:

```text
godot.get_status
project.get_info
scene.get_tree
scene.create
scene.save
node.create
node.set_property
node.delete
script.read
script.write
script.attach
editor.run_project
editor.stop
```

File operations remain inside `res://`. Editor mutations are processed sequentially.

## Bundled runtime

Current Windows runtime:

```text
OpenAI tunnel-client
version: 0.0.10+105e17a79a36e4e5c897fd698ed2b8dbf935b144
SHA-256: D893D8127EEE35070D265C1BE29BFE008F8D9FCB476E7FEBF56C8FDC6C0615C8
```

The Apache-2.0 license and NOTICE are included under `addons/godot_mcp_chatgpt/bin/`.

## Development-only test harness

`server/` simulates enough of the OpenAI control plane to exercise the **official** tunnel-client locally. It is not the production relay and is not required by end users.

The highest-value smoke test is:

```text
control-plane stub
 -> official bundled tunnel-client.exe
 -> Godot loopback MCP
 -> real Godot 4.7.2 GUI
 -> 13 real tools
```

This path passed before the 0.3.0 release candidate was prepared.

## Non-goals

- custom public relay infrastructure;
- direct GDScript implementation of OpenAI `/poll` and `/response`;
- stdio MCP compatibility for normal users;
- localhost WebSocket bridges;
- general shell/desktop automation;
- arbitrary OS command exposure;
- replacing Git or a coding agent.