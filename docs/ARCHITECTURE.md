# Architecture

English | [简体中文](ARCHITECTURE.zh-CN.md)

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

The key design decision is that **Godot does not implement the OpenAI tunnel wire protocol**. The official OpenAI `tunnel-client` owns the tunnel transport; the addon focuses on the local MCP server and Godot integration.

## Why this architecture

A direct custom tunnel implementation was evaluated during early development, but it did not satisfy the real ChatGPT Connector path. Production therefore delegates tunnel compatibility to the official OpenAI runtime and keeps the Godot side on the standard local MCP boundary.

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

The generated profile uses the official tunnel-client profile model:

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

Version 0.5.0 exposes **47 default public tools** backed by **230 internal atomic commands**, grouped around real Godot workflows rather than a generic shell:

```text
Project / InputMap
Scene / Node / Signal / Group / Metadata
Script / Resource
ClassDB
Editor
Debugger / Runtime
Diagnostics
Batch
```

Project file and Resource operations remain inside `res://`. Editor mutations are serialized through the Godot command layer. Exact tool schemas are documented by `tools/list`; see [Tool Reference](TOOL_REFERENCE.md).

## Runtime debugger path

Runtime inspection/control does not open another public network service. It uses Godot's own debugger channel:

```text
MCP runtime.* / debugger.* tool
 -> RuntimeDebuggerManager
 -> EditorDebuggerPlugin / EditorDebuggerSession
 -> Godot remote-debug channel
 -> EngineDebugger
 -> GodotMCPChatGPTRuntime autoload
 -> live SceneTree
```

The runtime bridge can inspect/change live nodes, call methods, read selected performance monitors, and pause/resume the running SceneTree. Runtime mutations are not automatically written back into the saved editor scene.

The reserved autoload is cleaned up when the plugin is disabled and resolves both `res://` and Godot 4.7.2 `uid://` references.
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
 -> 47 default public tools / 230 internal atomic commands
```

The 0.5.0 path passes compact catalogue/schema and representative behavior gates with 47 default public tools and 230 internal atomic commands. The final real Web ChatGPT Connector regression completed successfully on 2026-09-10 with `REAL_CHATGPT_GODOT_MCP_0_5_TEST=PASS`.

## Non-goals

- custom public relay infrastructure;
- direct GDScript implementation of OpenAI `/poll` and `/response`;
- stdio MCP compatibility for normal users;
- localhost WebSocket bridges;
- general shell/desktop automation;
- arbitrary OS command exposure;
- replacing Git or a coding agent.