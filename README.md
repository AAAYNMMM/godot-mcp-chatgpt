# godot-mcp-chatgpt

**Control a real Godot project from Web ChatGPT through OpenAI Secure MCP Tunnel.**

English | [简体中文](README.zh-CN.md)

`godot-mcp-chatgpt` is a project-scoped Godot editor addon that gives Web ChatGPT a compact MCP surface for editing, running, inspecting, testing, observing, and debugging the Godot project you have open.

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

- **47 default public MCP tools** backed by **230 internal atomic commands**. Long-tail operations are grouped into compact `*.manage` tools instead of exposing hundreds of flat schemas.
- **Real editor mutation** with Scene/Node/Script/Resource operations, high-level content authoring, Undo/Redo, and transactional rollback for reversible editor operations.
- **Visual observation** through MCP image content: editor viewport, Camera3D/cinematic, and running-game screenshots.
- **Deterministic playtesting** with InputMap editing plus keyboard, mouse, gamepad button/axis, and InputAction injection.
- **Runtime inspection/control**: live SceneTree, properties, method calls, UI discovery, performance, logs, and play-state controls.
- **World authoring** for TileMap/TileSet, GridMap/MeshLibrary, and CSG.
- **GDScript workflows** with whole-file write, anchor patching, validation/diagnostics, and a bounded test runner.
- **High-level content authoring** for animation, materials/shaders, audio, particles, camera, theme/UI, curve/gradient/noise, environment, and physics shapes.
- **Third-party custom tools** with addon ownership checks, explicit safety hints, schema validation, default-disabled opt-in, and at most two promoted public tools.
- **Real Web ChatGPT Connector regression tested** against Godot **4.7.2 Standard x64**, including actual screenshot image return and inspection.

## Latest release

**v0.5.0** — Windows x64, verified with **Godot 4.7.2 Standard x64**.

[Download the latest release](https://github.com/AAAYNMMM/godot-mcp-chatgpt/releases/latest)

| Item | Status |
| --- | --- |
| Windows x64 | Verified |
| Godot 4.7.2 | Verified |
| GDScript projects | Verified |
| Web ChatGPT Connector | Verified |
| Default public MCP tools | **47** |
| Internal atomic commands | **230** |
| macOS / Linux package | Not currently provided |
| Code-signed installer | Not currently provided |

The installer is unsigned, so Windows SmartScreen may show an unknown-publisher warning. The Release includes `SHA256SUMS.txt` for integrity verification.

## Quick install

### 1. Install into a Godot project

Recommended on Windows x64:

1. Download `godot-mcp-chatgpt-v0.5.0-windows-x64-installer.exe` from Releases.
2. Run it.
3. Select the target project's `project.godot`.
4. Reopen/restart the project if it was already open in Godot.

The installer writes only to the selected project:

```text
<project>/addons/godot_mcp_chatgpt/
<project>/project.godot
```

It enables the editor plugin by default and supports upgrading an existing installation. Manual alternative: extract the addon ZIP so `<project>/addons/godot_mcp_chatgpt/plugin.cfg` exists, then enable **Godot MCP ChatGPT** under **Project → Project Settings → Plugins**.

### 2. Connect the plugin

Open the **MCP ChatGPT** bottom panel, enter your `Tunnel ID` and `Runtime API Key`, then press **Connect**. After the first successful connection, the Runtime API Key is stored in Windows Credential Manager for automatic reconnect. **Forget Saved Credentials** removes the stored key and Tunnel ID.

### 3. Add the Connector in ChatGPT

Create/use the ChatGPT Connector for your OpenAI Secure MCP Tunnel and verify that the Godot tools are discovered. A safe first request is:

```text
Inspect the current Godot project and current scene. Do not modify anything.
```

See [Quick Start](docs/QUICKSTART.md) for the full walkthrough.

## Public tool model

v0.5.0 intentionally changes the public catalogue from v0.4.0's 119 flat tools to **47 default public tools** while retaining **230 atomic commands** internally.

The public surface contains 31 high-frequency direct tools plus 16 compact domain routers:

```text
project.manage   input_map.manage  scene.manage     node.manage
script.manage    resource.manage   classdb.manage   editor.manage
debugger.manage  runtime.manage    logs.manage      test.manage
autoload.manage  content.manage    world.manage     custom.manage
```

Each `*.manage` tool takes an `op` and `params`; the live MCP schema advertises allowed operations and the server validates `params` against the selected atomic command schema. See [Tool Reference](docs/TOOL_REFERENCE.md) for all 47 public names and usage conventions.

This compact surface is a deliberate tool-surface breaking change for callers that hard-code v0.4 public tool names. Web ChatGPT normally re-discovers the live catalogue automatically.

## Safety model

The addon can change the current project, so destructive behavior is bounded rather than hidden.

- project file/resource paths are restricted to `res://`; traversal and project-external paths are rejected;
- scene overwrite and destructive actions require explicit operations and annotations;
- `diagnostics.run_capture` is a bounded Godot runner, not an arbitrary shell tool;
- `batch.execute` remains bounded/non-atomic, while `batch.execute_transaction` only claims rollback for reversible operations;
- screenshots are bounded MCP image content rather than arbitrary filesystem capture;
- input injection targets the connected Godot editor/runtime path;
- custom tools are addon-owned, schema-validated, explicitly safety-annotated, and disabled by default;
- runtime changes do not automatically write back into saved editor scenes;
- the local MCP endpoint binds to loopback for the bundled official tunnel client;
- Runtime API Key persistence uses Windows Credential Manager rather than project/config files.

Read [Security](SECURITY.md) before exposing a project with sensitive or destructive workflows.

## Validation

v0.5.0 passed the consolidated local, Official Tunnel, installer, repository-hygiene, and **real Web ChatGPT Connector** regression on 2026-09-10.

Key markers:

```text
CATALOGUE_SCHEMA_GATE=PASS tools=47
COMPACT_TOOL_SURFACE_GATE=PASS public=47 atomic=230
PHASE_E_WORLD_EXTENSIBILITY=PASS
CAPABILITY_MIGRATION_MATRIX=PASS excluded=4 public=47 atomic=230
PRODUCTION_PLUGIN_SMOKE=PASS
FULL_OFFICIAL_TUNNEL_SMOKE=PASS
REAL_CHATGPT_GODOT_MCP_0_5_TEST=PASS
```

The real Connector regression exercised Project/Script, Scene/Node/UndoRedo, high-level content and animation, TileMap/TileSet image content, GridMap, CSG, input injection, live Runtime/UI inspection, screenshots, logs, tests, Batch/Transaction, Custom Tool promotion, and cleanup through Web ChatGPT itself.

Known non-blocking observations from that regression:

- one recoverable tunnel `network_error: Connection failed`; the editor remained online and an immediate retry succeeded;
- Native Debugger commands currently no-op while `debuggable=false` but may still return `ok=true`;
- `editor.manage(op="stop")` can report unsupported while the dedicated `stop_playing` operation succeeds.

## Documentation

### Users

| Document | Purpose |
| --- | --- |
| [Quick Start](docs/QUICKSTART.md) | Install, connect, and make the first safe call |
| [Tool Reference](docs/TOOL_REFERENCE.md) | v0.5 compact public surface and conventions |
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
| [0.5.0 Release Record](docs/DEVELOPMENT_0.5.md) | v0.5 capability-migration implementation and validation record |
| [0.4.0 Release Record](docs/DEVELOPMENT_0.4.md) | Closed v0.4 technical record |

Simplified Chinese documents are linked from their English counterparts.

## Scope and upstream reference

v0.5.0 migrated the audited missing Godot-side capabilities while intentionally excluding four transport/client architecture items that do not belong in this project: `godot://...` MCP Resources, MCP client auto-configuration, a Python/FastMCP server, and Godot AI's WebSocket bridge. Existing equivalent or stronger capabilities were retained rather than duplicated.

[Godot AI](https://github.com/hi-godot/godot-ai) is a mature MIT-licensed Godot MCP project. Its capability surface and compact domain/rollup design were used as an important reference for the v0.5 migration. `godot-mcp-chatgpt` remains an independent implementation focused on Web ChatGPT and does not depend on Godot AI's transport/client stack.

## Contributing

Issues and focused pull requests are welcome. Useful reports include the Godot version/OS, exact reproduction steps, relevant MCP request, expected vs actual behavior, non-secret logs, and whether the issue is editor-time, runtime, transport, installer, or documentation related.

See [Contributing](CONTRIBUTING.md).

## License

Project source is licensed under [LICENSE](LICENSE). The bundled official OpenAI `tunnel-client` retains its upstream license and NOTICE; see [Third-Party Notices](THIRD_PARTY_NOTICES.md).
