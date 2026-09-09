# godot-mcp-chatgpt

**Control a real Godot project from Web ChatGPT through OpenAI Secure MCP Tunnel.**

English | [简体中文](README.zh-CN.md)

`godot-mcp-chatgpt` is a project-scoped Godot editor addon that gives Web ChatGPT a direct MCP tool surface for editing, running, inspecting, and debugging the Godot project you have open.

```text
Web ChatGPT
    ↓
OpenAI Secure MCP Tunnel
    ↓
official OpenAI tunnel-client
    ↓
Godot-hosted local MCP server
    ↓
Godot Editor + Runtime Debugger
```

No Claude Desktop, Cursor, Codex CLI, local MCP client, custom public relay, Node.js runtime, or manual port configuration is required for normal use on the current Windows build.

## Highlights

- **119 Godot MCP tools** covering Project, InputMap, Scene, Node, Script, Resource, ClassDB, Editor, Debugger, Runtime, Diagnostics, and Batch.
- **Real editor mutation**: create scenes, write scripts, change nodes/resources, save, run, inspect, fix, and rerun.
- **Runtime debugging**: inspect the live SceneTree, read/write runtime properties, call methods, view performance data, pause, and resume.
- **Live Godot API discovery** through ClassDB instead of relying only on model memory.
- **Captured diagnostics** with stdout, stderr, exit code, timeout, and duration.
- **Windows Credential Manager** storage for the Runtime API Key, automatic reconnect, and an explicit Forget action.
- **Single-file Windows x64 installer** plus a portable addon ZIP.
- **Real Web ChatGPT regression tested** against Godot 4.7.2.

## Latest release

**v0.4.0** — Windows x64, verified with **Godot 4.7.2 Standard x64**.

[Download the latest release](https://github.com/AAAYNMMM/godot-mcp-chatgpt/releases/latest)

| Item | Status |
| --- | --- |
| Windows x64 | Verified |
| Godot 4.7.2 | Verified |
| GDScript projects | Verified |
| Web ChatGPT Connector | Verified |
| macOS / Linux package | Not currently provided |
| Code-signed installer | Not currently provided |

The installer is unsigned, so Windows SmartScreen may show an unknown-publisher warning. The Release includes `SHA256SUMS.txt` for integrity verification.

## Quick install

### 1. Install into a Godot project

Recommended on Windows x64:

1. Download `godot-mcp-chatgpt-v0.4.0-windows-x64-installer.exe` from Releases.
2. Run it.
3. Select the target project's `project.godot`.
4. Reopen/restart the project if it was already open in Godot.

The installer writes only to the selected project:

```text
<project>/addons/godot_mcp_chatgpt/
<project>/project.godot
```

It enables the editor plugin by default and supports upgrading an existing installation.

Manual alternative: extract the addon ZIP so this file exists:

```text
<project>/addons/godot_mcp_chatgpt/plugin.cfg
```

Then enable **Godot MCP ChatGPT** in:

```text
Project -> Project Settings -> Plugins
```

### 2. Connect the plugin

Open the **MCP ChatGPT** bottom panel and provide:

```text
Tunnel ID
Runtime API Key
```

Press **Connect**.

After the first successful connection, the Runtime API Key is stored in Windows Credential Manager and can be reused for automatic reconnect. Use **Forget Saved Credentials** when you want to remove the stored key and Tunnel ID.

### 3. Add the Connector in ChatGPT

Create/use the ChatGPT Connector for your OpenAI Secure MCP Tunnel, then verify that Godot tools are discovered.

A safe first request is:

```text
Inspect the current Godot project and current scene. Do not modify anything.
```

For a full walkthrough, see [Quick Start](docs/QUICKSTART.md).

## What ChatGPT can control

Version 0.4.0 exposes **119 tools**:

| Area | Tools | Main coverage |
| --- | ---: | --- |
| Godot | 1 | Connection/editor/version status |
| Project | 13 | Project inspection, files, search, settings, autoloads, plugins |
| InputMap | 6 | Actions and input events |
| Scene | 12 | Create/open/reload/inspect/save/instantiate/close |
| Node | 23 | Properties, methods, groups, metadata, signals, hierarchy |
| Script | 10 | Read/write/inspect/validate/attach/detach/editor state |
| Resource | 8 | Create/inspect/edit/save/duplicate/dependencies/methods |
| ClassDB | 9 | Live Godot API introspection |
| Editor | 20 | Selection, filesystem, scripts, save and play control |
| Debugger | 4 | Sessions, breakpoints, profiler |
| Runtime | 11 | Live SceneTree, properties, methods, performance, pause/resume |
| Diagnostics | 1 | Bounded Godot child-run with captured output |
| Batch | 1 | Ordered bounded multi-tool execution |

The intended development loop is:

```text
inspect
→ understand the live Godot API
→ edit
→ save
→ run
→ inspect runtime / diagnostics
→ fix
→ rerun
```

See [Tool Reference](docs/TOOL_REFERENCE.md) for the complete index and usage conventions.

## Safety model

The addon is intentionally capable of changing the current project, so destructive behavior is bounded rather than hidden.

Important boundaries in 0.4.0:

- project file/resource paths are restricted to `res://`;
- traversal and project-external paths are rejected;
- deleting the edited scene root is denied;
- scene overwrite requires explicit opt-in;
- `diagnostics.run_capture` is a bounded Godot runner, not an arbitrary shell tool;
- `batch.execute` is bounded and non-atomic;
- runtime changes affect the live game instance and do not automatically write back into the saved editor scene;
- the local MCP endpoint binds to loopback and is intended for the bundled official tunnel client;
- Runtime API Key persistence uses Windows Credential Manager rather than project/config files.

Read [Security](SECURITY.md) before exposing a project that contains sensitive or destructive workflows.

## Architecture

Production transport:

```text
ChatGPT
  ↓
OpenAI Secure MCP Tunnel
  ↓
official tunnel-client.exe
  ↓
127.0.0.1:<random>/mcp/<random>
  ↓
Godot Streamable HTTP MCP
  ↓
CommandRegistry
  ↓
Godot Editor API / Editor Debugger
```

The project does **not** reimplement the OpenAI tunnel wire protocol. The official OpenAI runtime owns tunnel compatibility; this repository owns the Godot MCP server, Godot tool layer, installer, and editor/runtime integration.

See [Architecture](docs/ARCHITECTURE.md) and [Secure Tunnel](docs/SECURE_TUNNEL.md).

## Validation

The v0.4.0 release passed:

```text
Godot 4.7.2 addon load/compile
119-tool catalogue/schema gate
official tunnel-client production smoke
real Web ChatGPT Connector full-surface regression
Runtime autoload persistence lifecycle
Credential save -> restart auto-connect -> Forget -> restart
installer clean install / upgrade / invalid-path / no-enable
Unicode + space project path install
installed addon full file-set SHA-256 comparison
Release asset SHA-256 re-download verification
```

Key markers:

```text
CATALOGUE_SCHEMA_GATE=PASS tools=119
PRODUCTION_PLUGIN_SMOKE=PASS
REAL_CHATGPT_GODOT_MCP_0_4_TEST=PASS
INSTALLER_SMOKE=PASS version=0.4.0
RELEASE_REMOTE_ASSET_VERIFY=PASS
```

Current release state and known limitations are tracked in [Progress](docs/PROGRESS.md).

## Documentation

### Users

| Document | Purpose |
| --- | --- |
| [Quick Start](docs/QUICKSTART.md) | Install, connect, and make the first safe call |
| [Tool Reference](docs/TOOL_REFERENCE.md) | Complete 119-tool index and conventions |
| [Examples](docs/EXAMPLES.md) | Practical prompts and workflows |
| [FAQ](docs/FAQ.md) | Common questions and troubleshooting |
| [Security](SECURITY.md) | Trust boundaries and safety behavior |
| [Architecture](docs/ARCHITECTURE.md) | Production architecture and component responsibilities |
| [Secure Tunnel](docs/SECURE_TUNNEL.md) | Tunnel/runtime behavior and troubleshooting |

### Maintainers

| Document | Purpose |
| --- | --- |
| [Contributing](CONTRIBUTING.md) | Contribution rules and development expectations |
| [Development Plan](docs/DEVELOPMENT_PLAN.md) | Released milestones and future priorities |
| [Development Workflow](docs/DEVELOPMENT_WORKFLOW.md) | Definition of done and documentation rules |
| [Releasing](docs/RELEASING.md) | Repeatable release checklist |
| [Progress](docs/PROGRESS.md) | Current repository/release status |
| [0.4.0 Release Record](docs/DEVELOPMENT_0.4.md) | Closed technical record for v0.4.0 |
| [0.5.0 Capability Migration Plan](docs/DEVELOPMENT_0.5.md) | Active plan for capability migration and compact tool surface |

Simplified Chinese documents are linked from their English counterparts.

## Roadmap

The next milestone is now locked as **v0.5.0 Capability Migration**. It has two goals:

1. migrate the audited Godot-side capabilities that are still missing from v0.4.0;
2. compress the default public MCP surface from 119 flat tools to a compact **<=50-tool** domain surface while retaining internal atomic commands.

The migration includes screenshot/image responses, deterministic input/playtest, native frame stepping, live logs, script patch/write diagnostics, GDScript tests, UndoRedo/rollback semantics, high-level Animation/Material/Audio/Particle/Camera/Theme/UI authoring, Resource helpers, TileMap/TileSet, GridMap, CSG, Autoload mutation, and third-party custom tool registration.

The migration explicitly does **not** include `godot://...` MCP Resources, MCP client auto-configuration, a Python/FastMCP server, or Godot AI's WebSocket bridge. Existing equivalent or stronger v0.4 capabilities are retained instead of duplicated.

See [v0.5.0 Capability Migration Plan](docs/DEVELOPMENT_0.5.md) and [Development Plan](docs/DEVELOPMENT_PLAN.md).

## Contributing

Issues and focused pull requests are welcome. The most useful reports include:

- Godot version and OS;
- exact reproduction steps;
- the relevant MCP tool/request;
- expected vs actual behavior;
- non-secret logs;
- whether the issue is editor-time, runtime, transport, installer, or documentation related.

See [Contributing](CONTRIBUTING.md).

## License

Project source is licensed under the terms in [LICENSE](LICENSE).

The bundled official OpenAI `tunnel-client` retains its upstream license and NOTICE. See [Third-Party Notices](THIRD_PARTY_NOTICES.md).

## Acknowledgements and related work

[Godot AI](https://github.com/hi-godot/godot-ai) is a mature MIT-licensed Godot MCP project. Its current capability surface and compact domain/rollup tool design are used as an important reference for the v0.5 migration plan.

`godot-mcp-chatgpt` remains an independent implementation focused on Web ChatGPT and does **not** depend on Godot AI, Python/FastMCP, its MCP client configuration layer, its `godot://` Resources, or its WebSocket bridge. Where future migration work ports or derives substantial Godot AI source code, the applicable MIT attribution will be recorded in [Third-Party Notices](THIRD_PARTY_NOTICES.md).
