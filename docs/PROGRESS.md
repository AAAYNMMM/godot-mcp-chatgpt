# Current Project Status

English | [简体中文](PROGRESS.zh-CN.md)

This document is the **current-state source of truth**. Detailed historical development logs from the 0.3/0.4 implementation cycle were archived in [PROGRESS_ARCHIVE_0.3-0.4.md](PROGRESS_ARCHIVE_0.3-0.4.md).

## Current release

| Item | Value |
| --- | --- |
| Latest release | **v0.5.0** |
| Release source commit | `v0.5.0 tag target` |
| Release tag | `v0.5.0` |
| Primary platform | Windows x64 |
| Verified Godot | 4.7.2 Standard x64 |
| Default public MCP tools | **47** |
| Internal atomic commands | **230** |
| Connector path | Web ChatGPT + OpenAI Secure MCP Tunnel |
| Release state | Validated; packaging/publication in progress |
| v0.5 capability migration | **Complete** |
| Public-tool limit | **<50; validated at 47 default / 48 with one promoted custom tool** |

Release page: <https://github.com/AAAYNMMM/godot-mcp-chatgpt/releases/tag/v0.5.0>

## Production architecture

```text
Web ChatGPT
  ↓
OpenAI Secure MCP Tunnel
  ↓
official OpenAI tunnel-client
  ↓
Godot loopback Streamable HTTP MCP
  ↓
CommandRegistry
  ↓
Godot Editor API / Editor Debugger
```

The project does not implement the OpenAI tunnel wire protocol. The official runtime owns tunnel transport compatibility.

## Shipped in v0.4.0

- 119 production tools across Project, InputMap, Scene, Node, Script, Resource, ClassDB, Editor, Debugger, Runtime, Diagnostics, and Batch.
- Windows Credential Manager persistence for Runtime API Key.
- Automatic reconnect after restart and Forget Saved Credentials.
- Runtime debugger bridge using Godot's editor debugger path.
- Bounded captured diagnostics.
- Bounded non-atomic batch execution.
- Windows x64 one-click project installer.
- Portable addon ZIP and SHA-256 manifest.
- Runtime autoload persistence via `ProjectSettings.save()`.
- English + Simplified Chinese user and maintainer documentation.

## Validation status

The release and installer are considered validated because the following were actually run:

```text
CATALOGUE_SCHEMA_GATE=PASS tools=119
PRODUCTION_PLUGIN_SMOKE=PASS
REAL_CHATGPT_GODOT_MCP_0_4_TEST=PASS
RUNTIME_AUTOLOAD_LIFECYCLE_NODE_SMOKE=PASS
INSTALLER_SMOKE=PASS version=0.4.0
ADDON_ZIP_EXACT_CHECK=PASS files=46
SHA256SUMS_VERIFY=PASS
RELEASE_REMOTE_ASSET_VERIFY=PASS
```

The real ChatGPT regression exercised editor mutation, Runtime mutation/readback, Diagnostics, Batch, and safety boundaries through the real Connector.

## Known limitations

These are current product limitations, not release blockers:

- Windows x64 is the only packaged/verified OS target.
- Godot 4.7.2 is the verified compatibility baseline; other Godot 4.x versions need explicit testing.
- The Windows installer is not code-signed.
- The project does not yet expose screenshot/vision capture, deterministic input injection, or frame-step playtest tools.
- `batch.execute` is non-atomic and does not roll back earlier successful operations.
- Runtime changes do not automatically persist back into the saved editor scene.

## Current documentation state

The v0.4.0 documentation maturity pass has been completed:

- README is release/user-first instead of development-history-first.
- v0.4.0 is marked closed rather than WIP.
- current progress is concise and historical logs are archived.
- Development Plan distinguishes completed milestones from future candidates.
- Tool Reference documents runtime/editor boundaries and common errors.
- a repeatable release checklist is documented in `RELEASING.md`.

## Latest completed maintenance task — documentation maturity pass

Status: **complete / validation passed**.

The post-v0.4.0 documentation set was reorganized from development-history-first to release/user-first without changing plugin/runtime code.

Completed:

- rewrote README around value, latest release, installation, capabilities, safety, validation, and documentation navigation;
- closed `DEVELOPMENT_0.4` as a release record instead of leaving WIP state;
- reduced current `PROGRESS` from a long chronological log to a concise current-state document;
- preserved the 0.3/0.4 chronological implementation history in an explicit archive;
- rewrote Development Plan to separate completed milestones from future candidates;
- added Editor/Runtime target semantics and common error guidance to Tool Reference;
- added a repeatable bilingual Release checklist;
- removed internal development-story wording from public Architecture/FAQ where it distracted from the current design;
- aligned Contributing/Development Workflow with release closure and archive rules.

Validation actually run:

```text
DOC_LINK_CHECK=PASS files=34
DOC_NO_IMAGE=PASS
DOC_BOM_CHECK=PASS
DOC_UTF8_CHECK=PASS
DOC_LOCAL_PATH_CHECK=PASS
DIFF_CHECK=PASS
VERSION_CHECK=PASS 0.4.0
TOOL_REFERENCE_COUNT=PASS 119
STALE_ACTIVE_DOC_STATE=PASS
DEV_PLAN_HEADING_CHECK=PASS
README_STRUCTURE_CHECK=PASS
```

No plugin/runtime source file was changed by this task.
## Released milestone — v0.5.0 capability migration

Status: **complete; all migration phases and final real Web ChatGPT Connector acceptance passed**.

The next milestone is now locked. See [v0.5.0 Capability Migration Plan](DEVELOPMENT_0.5.md).

Scope rules:

- migrate all audited Godot-side capabilities missing from v0.4.0;
- do not duplicate capabilities we already provide equivalently or more generally;
- explicitly do **not** migrate MCP Resources (`godot://...`), MCP client auto-config, Python/FastMCP server, or the Godot AI WebSocket bridge;
- implement new Godot capabilities GDScript-first inside the existing Editor/Runtime architecture;
- compress the default public MCP tool surface from 119 flat tools to a **<=50-tool** compact domain surface while keeping internal atomic commands.

Required migration families include screenshots/image responses, deterministic input/playtest, native frame stepping, live logs, script patch/write diagnostics, GDScript tests, UndoRedo/rollback semantics, Animation/Material/Audio/Particle/Camera/Theme/UI authoring, Resource helpers, TileMap/TileSet, GridMap, CSG, Autoload mutation, and custom third-party tool registration.

### Latest completed planning task — migration scope lock

Status: **complete / documentation validation passed**.

Completed:

- audited the current Godot AI public tool/domain capability surface;
- separated equivalent/better v0.4 capabilities from real gaps;
- locked the four explicit exclusions;
- locked GDScript-first / Go-only-for-OS-helper language boundaries;
- defined the compact public-surface architecture and <=50 release target;
- created the bilingual v0.5 active tracker;
- updated the roadmap and README to acknowledge Godot AI as a capability/design reference.

### Planning-document validation

```text
DOC_LINK_CHECK=PASS files=36
DOC_NO_IMAGE=PASS
DOC_BOM_CHECK=PASS
DOC_UTF8_CHECK=PASS
DOC_LOCAL_PATH_CHECK=PASS
MIGRATION_SCOPE_GATE=PASS
EXCLUSION_GATE=PASS count=4
COMPACT_TOOL_PLAN_GATE=PASS target<=50
UPSTREAM_COMPRESSION_REFERENCE=PASS 46=19+27
README_GODOT_AI_ACK=PASS
DIFF_CHECK=PASS
DOC_ONLY_SCOPE=PASS
```

### Phase A implementation — compact public tool surface

Status: **implemented and validated through the final real Web ChatGPT Connector regression**.

Implemented:

- added `PublicToolSurface` between MCP `tools/list/tools/call` and the internal `CommandRegistry`;
- compressed the default surface to **39 tools** (29 direct + 10 manage) without deleting the 119 atomic commands;
- kept all 119 v0.4 atomic capabilities reachable;
- added `*.manage(op, params)` schema validation and structured unknown-op errors;
- kept Batch internal-atomic behavior unchanged;
- upgraded the official-tunnel smoke to route existing long-tail behavior tests through manage tools.

Validation actually run:

```text
Godot 4.7.2 addon load/parse: PASS
npm run build: PASS
npm test: PASS
CATALOGUE_SCHEMA_GATE=PASS tools=39
COMPACT_TOOL_SURFACE_GATE=PASS public=39 atomic=119
PRODUCTION_PLUGIN_SMOKE=PASS
```

### Phase B implementation — observe, play, debug, diagnose

Status: **targeted validation passed**.

- Public surface: 42; internal atomic commands: 139.
- MCP image + running-game screenshot: PASS.
- Runtime UI discovery: PASS.
- Keyboard/mouse/gamepad/InputAction/input-sequence: PASS.
- Native debugger controls/status implemented with targeted state regression.
- Editor/game logs: PASS.
- Runtime bounded evaluate: PASS.
- Editor performance/refresh/confirm-gated quit implemented.

```text
CATALOGUE_SCHEMA_GATE=PASS tools=42
COMPACT_TOOL_SURFACE_GATE=PASS public=42 atomic=139
PRODUCTION_PLUGIN_SMOKE=PASS
```

### Phase C implementation — script/test/transaction workflow

Status: **targeted validation passed**.

- Public surface: 47; internal atomic commands: 153.
- Script patch/write diagnostics: PASS.
- GDScript test runner: PASS, 2/2.
- InputMap ensure helpers: PASS.
- Autoload lifecycle: PASS.
- Core node-mutation UndoRedo: PASS.
- Editor undo/redo: PASS.
- Transactional batch commit/rollback: PASS.
- Unsupported transaction-operation preflight rejection: PASS.
- Official OpenAI Tunnel production smoke: PASS.

```text
CATALOGUE_SCHEMA_GATE=PASS tools=47
COMPACT_TOOL_SURFACE_GATE=PASS public=47 atomic=153
PRODUCTION_PLUGIN_SMOKE=PASS
```

### Phase D implementation — high-level content authoring

Status: **targeted validation passed**.

- Public surface: 48; internal atomic commands: 211.
- Animation authoring/lifecycle/presets + UndoRedo: PASS.
- Material/Shader, Audio, Particles, Camera: PASS.
- Theme/UI helpers: PASS.
- Curve/Environment/Physics Shape/Gradient/Noise helpers: PASS.
- Saved-resource reload and cross-type regression: PASS.
- Official OpenAI Tunnel production smoke: PASS.

```text
CATALOGUE_SCHEMA_GATE=PASS tools=48
COMPACT_TOOL_SURFACE_GATE=PASS public=48 atomic=211
PRODUCTION_PLUGIN_SMOKE=PASS
```
### Phase E implementation — world building and extensibility

Status: **targeted validation passed**.

- Base public surface: 47; internal atomic commands: 230; enabled promoted custom tools remain bounded below the <=50 release cap.
- TileMapLayer/TileSet atlas write-read-image workflows: PASS, including bounded selected-cell reads and UndoRedo.
- GridMap/MeshLibrary set/fill/clear/read workflows: PASS, including UndoRedo and fill bounds.
- CSG create/operation editing: PASS, including UndoRedo.
- Custom Tool opt-in, addon/handler ownership, explicit safety hints, schema validation, payload bounds, promotion and refresh behavior: PASS.
- Official OpenAI Tunnel production path: PASS.

### Phase F consolidated migration regression

Status: **complete; local/Official-Tunnel/installer/hygiene gates and final real Web ChatGPT Connector acceptance passed**.

Validation actually run on 2026-09-10:

```text
npm run build: PASS
npm test: PASS
CATALOGUE_SCHEMA_GATE=PASS tools=47
COMPACT_TOOL_SURFACE_GATE=PASS public=47 atomic=230
PHASE_E_WORLD_EXTENSIBILITY=PASS
CAPABILITY_MIGRATION_MATRIX=PASS excluded=4 public=47 atomic=230
PRODUCTION_PLUGIN_SMOKE=PASS
FULL_OFFICIAL_TUNNEL_SMOKE=PASS
REAL_CHATGPT_GODOT_MCP_0_5_TEST=PASS
credential-helper Go compile: PASS
run-helper Go compile: PASS
INSTALLER_BUILD=PASS
INSTALLER_CLEAN_INSTALL=PASS
INSTALLER_UPGRADE=PASS
INSTALLER_PRESERVE_UNRELATED=PASS
INSTALLER_STALE_CLEANUP=PASS
INSTALLER_NO_ENABLE=PASS
INSTALLER_INVALID_PROJECT=PASS
INSTALLER_GODOT_4_7_2_LOAD=PASS
INSTALLED_ADDON_EXACT_MATCH=PASS files=70
BOM_CHECK=PASS files=69
SECRET_CHECK=PASS fixtures=1 real=0
DOC_LINK_CHECK=PASS files=36 local_links=157
DOC_NO_IMAGE=PASS
INSTALLER_HARDCODE_CHECK=PASS
DIFF_CHECK=PASS
PROJECT_GODOT_HYGIENE=PASS
SMOKE_RESIDUE_CHECK=PASS
FINAL_HYGIENE=PASS
```

The direct `go test` entry for the installer is intentionally not a standalone gate because the installer uses `//go:embed payload.zip`; its supported `build.ps1` path generates that payload and passed.

Final real Web ChatGPT Connector acceptance completed: `REAL_CHATGPT_GODOT_MCP_0_5_TEST=PASS`. It verified real screenshots/image content, Runtime/UI, input, logs/tests/transactions, World Authoring, Custom Tool promotion, and cleanup.
### Exact next implementation task

**v0.5.0 is release-ready. Build and verify release artifacts from the exact release commit, publish the `v0.5.0` tag/Release, then verify remote asset hashes.**

## Documentation ownership

- User entry: [README](../README.md)
- Setup: [Quick Start](QUICKSTART.md)
- Tool behavior: [Tool Reference](TOOL_REFERENCE.md)
- Security: [Security](../SECURITY.md)
- Architecture: [Architecture](ARCHITECTURE.md)
- Roadmap: [Development Plan](DEVELOPMENT_PLAN.md)
- Closed v0.5 release record: [Development 0.5](DEVELOPMENT_0.5.md)
- Release process: [Releasing](RELEASING.md)
- Closed 0.4 technical record: [Development 0.4](DEVELOPMENT_0.4.md)
- Historical implementation log: [0.3–0.4 archive](PROGRESS_ARCHIVE_0.3-0.4.md)