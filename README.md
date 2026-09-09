# godot-mcp-chatgpt

**Control the Godot editor from Web ChatGPT through OpenAI Secure MCP Tunnel.**

English | [简体中文](README.zh-CN.md)

`godot-mcp-chatgpt` is a Godot editor addon for people who want ChatGPT to work on a real Godot project instead of only suggesting code in chat. The addon exposes a focused set of Godot editor tools through MCP, while the bundled official OpenAI `tunnel-client` handles the secure remote connection.

The normal workflow is deliberately small:

```text
Install addon -> Enable plugin -> Enter Tunnel ID + Runtime API Key -> Connect -> Use Godot tools from ChatGPT
```

No CWapi, Codex, Node.js, local MCP client, custom public relay, or manual port setup is required at runtime on the current Windows build.

## Why this project

Typical AI-assisted Godot workflows still require a lot of copying between chat, code, the scene tree, and the editor. This project is aimed at a more direct loop:

```text
You describe the change in ChatGPT
        ↓
ChatGPT calls Godot MCP tools
        ↓
Godot editor changes the real project
        ↓
You immediately inspect or run the result
```

That makes it useful for:

- building small gameplay prototypes;
- creating and editing scenes and nodes;
- writing and attaching GDScript;
- changing node properties;
- inspecting the current scene tree;
- starting and stopping the project;
- letting a Web ChatGPT session operate the editor without a desktop AI client.

## Current status

Current development version: **0.4.0**

Current primary target:

- Windows x64;
- Godot **4.7.2 Standard x64**;
- GDScript projects;
- Godot Compatibility Renderer is suitable and does not affect the MCP transport.

### Real connection verified

On 2026-09-10 the 0.4.0 build passed a full real-user regression through a real ChatGPT Connector:

```text
Godot 4.7.2
  -> bundled official OpenAI tunnel-client
  -> OpenAI Secure MCP Tunnel
  -> real ChatGPT Connector
  -> 119 Godot MCP tools discovered
  -> editor + runtime + diagnostics + batch calls
  -> REAL_CHATGPT_GODOT_MCP_0_4_TEST=PASS
```

The test created and reopened scenes, edited nodes/scripts/resources, queried Godot 4.7.2 ClassDB, changed a live runtime node without leaking the change back into the saved editor scene, captured process errors/exit codes, exercised bounded batch calls, and verified path/delete safety boundaries.
## What ChatGPT can do today

Version 0.4.0 exposes **119 tools** across the full Godot development loop:

| Area | Tools | What it covers |
| --- | ---: | --- |
| Godot | 1 | Connection/editor/version status |
| Project | 13 | Project inspection, files, search, settings, autoloads, plugins |
| InputMap | 6 | Actions and input events |
| Scene | 12 | Create/open/reload/inspect/save/instantiate/close |
| Node | 23 | Properties, methods, groups, metadata, signals, hierarchy editing |
| Script | 10 | Read/write/inspect/validate/attach/detach/editor state |
| Resource | 8 | Create/inspect/edit/save/duplicate/dependencies/methods |
| ClassDB | 9 | Live Godot API introspection |
| Editor | 20 | Selection, filesystem, scripts, save and play control |
| Debugger | 4 | Sessions, breakpoints and profiler control |
| Runtime | 11 | Live SceneTree inspection/control and performance |
| Diagnostics | 1 | Bounded Godot child-run with stdout/stderr/exit/timeout |
| Batch | 1 | Ordered bounded multi-tool execution |

This means ChatGPT can now perform the loop that matters for real development:

```text
inspect project -> understand API -> edit -> save -> run -> inspect runtime/error -> fix -> rerun
```

See [Tool Reference](docs/TOOL_REFERENCE.md) for the complete 119-tool index and important argument conventions.
## 5-minute quick start

### 1. Install the addon

**Recommended on Windows x64:** download `godot-mcp-chatgpt-v0.4.0-windows-x64-installer.exe` from [GitHub Releases](https://github.com/AAAYNMMM/godot-mcp-chatgpt/releases), run it, and select the target project's `project.godot` file. The installer:

- installs only to `<selected-project>/addons/godot_mcp_chatgpt/`;
- enables the editor plugin automatically;
- supports upgrading an existing installation;
- does not contain a hard-coded user/project path.

The current executable is not code-signed, so Windows SmartScreen may show an unknown-publisher warning. Verify the accompanying `SHA256SUMS.txt` from the same Release if you want to confirm the downloaded file.

**Manual alternative:** download the addon ZIP and extract it so this file exists:

```text
<your-project>/addons/godot_mcp_chatgpt/plugin.cfg
```

For a manual install, open:

```text
Project -> Project Settings -> Plugins
```

and enable **Godot MCP ChatGPT**.

A bottom editor panel named **MCP ChatGPT** will appear after the project/plugin is loaded.

### 2. Prepare an OpenAI tunnel

You need:

```text
Tunnel ID
Runtime API Key
```

Use a restricted Runtime API Key with the tunnel permissions required by your OpenAI workspace. Do not paste the key into GitHub issues, screenshots, or chat messages.

Detailed setup: [Quick Start](docs/QUICKSTART.md)

### 3. Connect Godot

In the **MCP ChatGPT** panel, enter the Tunnel ID and Runtime API Key, then press **Connect**.

Expected panel state:

```text
Status: connected
```

In 0.4.0, `connected` means the official `tunnel-client` child process is alive. The definitive proof is successful tool discovery/calls from ChatGPT. After the first successful connection, the Runtime API Key is stored in Windows Credential Manager and can be reused for automatic reconnect.

### 4. Create the ChatGPT connector

In ChatGPT, create a connector using **Connection: Tunnel** and select/paste the same Tunnel ID.

Keep Godot open while using the connector.

### 5. Try a safe first request

Start with a read-only request such as:

```text
Call godot.get_status and tell me which Godot version and project are open.
```

Then try a disposable scene:

```text
Create res://mcp_test/main.tscn with a Node3D root named MCPTest,
add a Node3D child named RemoteNode at position (1, 2, 3),
and save the scene.
```

## How it works

The production runtime deliberately follows the connection pattern proven by the working CWapi tunnel integration, but CWapi itself is **not** required:

```text
Web ChatGPT
      |
      | MCP over OpenAI Secure MCP Tunnel
      v
OpenAI tunnel service
      |
      v
official OpenAI tunnel-client.exe
      |
      | Streamable HTTP MCP on 127.0.0.1
      v
Godot MCP ChatGPT addon
      |
      | in-process command dispatch
      v
Godot Editor API
```

The important design choice is that this project does **not** reimplement OpenAI's tunnel wire protocol. The official OpenAI tunnel runtime owns tunnel compatibility; the addon only hosts the local Godot MCP server and Godot tool layer.

Read [Architecture](docs/ARCHITECTURE.md) for details.

## Security model

The addon is intentionally narrow:

- the local MCP server binds only to `127.0.0.1`;
- it uses a random high port and random per-run URL path;
- the Tunnel ID is persisted in Godot `EditorSettings`;
- on Windows, the Runtime API Key is stored as a Generic Credential in Windows Credential Manager, not in the project or Git;
- the generated tunnel profile never contains the plaintext key and references `env:CONTROL_PLANE_API_KEY`;
- the key is removed from the parent Godot process environment after child startup;
- **Forget Saved Credentials** removes the saved Tunnel ID and Credential Manager entry;
- current file tools stay inside `res://` and reject `..` traversal;
- `scene.create` will not overwrite an existing scene unless `overwrite: true` is explicitly supplied;
- there is no generic shell execution MCP tool.

Use a dedicated restricted runtime key rather than an admin key.

See [Security](SECURITY.md).

## What this project is not

This is not intended to be:

- a general remote-desktop controller;
- a replacement for Git or source control;
- a general shell agent;
- a replacement for Godot's editor UI;
- a promise that every Godot API is already exposed.

The goal is a small, reliable, high-value editor tool surface first, then expand based on real workflows.

## Roadmap

Near-term priorities now focus on compatibility and distribution hardening:

- code-signed/reputation-friendly Windows distribution if a signing path becomes available;
- compatibility testing across more Godot 4.x versions and operating systems;
- deeper debugger/profiler workflows where Godot exposes stable editor APIs;
- macOS/Linux packaging if official tunnel runtimes are adopted there;
- continued hardening based on real ChatGPT Connector regressions.

See [Development Plan](docs/DEVELOPMENT_PLAN.md).

## Documentation

| Document | English | 简体中文 |
| --- | --- | --- |
| Quick start | [QUICKSTART.md](docs/QUICKSTART.md) | [QUICKSTART.zh-CN.md](docs/QUICKSTART.zh-CN.md) |
| Tool reference | [TOOL_REFERENCE.md](docs/TOOL_REFERENCE.md) | [TOOL_REFERENCE.zh-CN.md](docs/TOOL_REFERENCE.zh-CN.md) |
| Practical examples | [EXAMPLES.md](docs/EXAMPLES.md) | [EXAMPLES.zh-CN.md](docs/EXAMPLES.zh-CN.md) |
| FAQ / troubleshooting | [FAQ.md](docs/FAQ.md) | [FAQ.zh-CN.md](docs/FAQ.zh-CN.md) |
| Architecture | [ARCHITECTURE.md](docs/ARCHITECTURE.md) | [ARCHITECTURE.zh-CN.md](docs/ARCHITECTURE.zh-CN.md) |
| Secure Tunnel notes | [SECURE_TUNNEL.md](docs/SECURE_TUNNEL.md) | [SECURE_TUNNEL.zh-CN.md](docs/SECURE_TUNNEL.zh-CN.md) |
| Development plan | [DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md) | [DEVELOPMENT_PLAN.zh-CN.md](docs/DEVELOPMENT_PLAN.zh-CN.md) |
| Development handoff | [PROGRESS.md](docs/PROGRESS.md) | [PROGRESS.zh-CN.md](docs/PROGRESS.zh-CN.md) |
| Contributing | [CONTRIBUTING.md](CONTRIBUTING.md) | [CONTRIBUTING.zh-CN.md](CONTRIBUTING.zh-CN.md) |
| Changelog | [CHANGELOG.md](CHANGELOG.md) | [CHANGELOG.zh-CN.md](CHANGELOG.zh-CN.md) |
| Security | [SECURITY.md](SECURITY.md) | [SECURITY.zh-CN.md](SECURITY.zh-CN.md) |

## Bundled third-party runtime

The current Windows addon bundles the official OpenAI `tunnel-client` runtime at:

```text
addons/godot_mcp_chatgpt/bin/windows/tunnel-client.exe
```

Runtime identity used for 0.4.0 validation:

```text
0.0.10+105e17a79a36e4e5c897fd698ed2b8dbf935b144
```

SHA-256:

```text
D893D8127EEE35070D265C1BE29BFE008F8D9FCB476E7FEBF56C8FDC6C0615C8
```

The Apache-2.0 license and NOTICE are bundled beside the runtime. See [Third-Party Notices](THIRD_PARTY_NOTICES.md).

## Contributing

Issues, reproducible bug reports, compatibility results, tool ideas, and focused pull requests are welcome. The most valuable contributions are usually based on a real Godot workflow rather than adding tools only to increase the tool count.

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a large change.

## Support the project

If this project removes friction from your Godot + ChatGPT workflow, starring the repository helps other Godot users find it. More useful than a star, though, is a concise issue describing a real workflow that should be easier.

## License

Project source: see [LICENSE](LICENSE).

Bundled third-party components keep their own license notices under `addons/godot_mcp_chatgpt/bin/` and in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).