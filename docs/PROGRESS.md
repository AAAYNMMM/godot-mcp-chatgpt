# Current Project Status

English | [简体中文](PROGRESS.zh-CN.md)

This document is the **current-state source of truth**. Detailed historical development logs from the 0.3/0.4 implementation cycle were archived in [PROGRESS_ARCHIVE_0.3-0.4.md](PROGRESS_ARCHIVE_0.3-0.4.md).

## Current release

| Item | Value |
| --- | --- |
| Latest release | **v0.4.0** |
| Release source commit | `f12d268b5bca087ae8cef744f9cb7ab8877848e8` |
| Release tag | `v0.4.0` |
| Primary platform | Windows x64 |
| Verified Godot | 4.7.2 Standard x64 |
| Production MCP tools | **119** |
| Connector path | Web ChatGPT + OpenAI Secure MCP Tunnel |
| Release state | Published and validated |

Release page: <https://github.com/AAAYNMMM/godot-mcp-chatgpt/releases/tag/v0.4.0>

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
## Next priorities

No single next feature is committed yet. Candidate priorities are:

1. screenshot / visual inspection;
2. deterministic input injection and playtest helpers;
3. frame stepping, runtime logs, and test workflows;
4. tunnel health/readiness diagnostics;
5. broader Godot 4.x compatibility validation;
6. CI / repository automation and Windows signing strategy.

Do not increase the tool count only for the sake of a larger number.

## Documentation ownership

- User entry: [README](../README.md)
- Setup: [Quick Start](QUICKSTART.md)
- Tool behavior: [Tool Reference](TOOL_REFERENCE.md)
- Security: [Security](../SECURITY.md)
- Architecture: [Architecture](ARCHITECTURE.md)
- Roadmap: [Development Plan](DEVELOPMENT_PLAN.md)
- Release process: [Releasing](RELEASING.md)
- Closed 0.4 technical record: [Development 0.4](DEVELOPMENT_0.4.md)
- Historical implementation log: [0.3–0.4 archive](PROGRESS_ARCHIVE_0.3-0.4.md)