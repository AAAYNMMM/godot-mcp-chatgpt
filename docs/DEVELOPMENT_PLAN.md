# Development Plan

English | [简体中文](DEVELOPMENT_PLAN.zh-CN.md)

This document separates **released milestones** from **future candidate work**. Released behavior belongs in README/Tool Reference/CHANGELOG; unreleased ideas must remain clearly marked as planned.

## 1. Product goal

Make Web ChatGPT a practical Godot development surface:

```text
describe work in ChatGPT
→ inspect the real Godot project
→ query the live Godot API
→ edit
→ save
→ run
→ inspect runtime / diagnostics
→ fix
```

The product should remain project-scoped, low-friction, explicit about destructive actions, and usable without a desktop AI client.

## 2. Current production architecture

```text
Web ChatGPT
  ↓
OpenAI Secure MCP Tunnel
  ↓
official bundled tunnel-client
  ↓
Godot loopback Streamable HTTP MCP
  ↓
CommandRegistry
  ↓
Godot Editor API / Editor Debugger
```

Locked principles:

- use the official OpenAI tunnel runtime;
- keep the local MCP endpoint loopback-only;
- keep ordinary Godot operations in-process;
- keep file/resource mutation inside `res://`;
- do not add arbitrary shell execution without explicit security review;
- do not expand the tool count only for vanity metrics.

## 3. Released milestones

### Phase 0 — Repository continuity

Status: **complete**.

- repository structure and bilingual documentation established;
- source/build/test boundaries documented.

### Phase 1 — Godot editor-control skeleton

Status: **complete**.

- EditorPlugin;
- bottom panel;
- command registry;
- initial scene/node/script/editor operations.

### Phase 2 — Transport exploration

Status: **complete / superseded**.

- early direct transport experiments established requirements;
- production no longer uses the custom direct tunnel implementation.

### Phase 3 — Direct GDScript tunnel prototype

Status: **complete / superseded**.

- useful as a local proof;
- rejected as the production architecture after real Connector incompatibility.

### Phase 4 — Official tunnel-client architecture

Status: **complete** in v0.3.0.

- official OpenAI `tunnel-client`;
- Godot-hosted loopback Streamable HTTP MCP;
- real ChatGPT Connector creation validated.

### Phase 5 — Real ChatGPT Connector baseline

Status: **complete**.

- real Connector discovery/call path validated;
- transport moved from proof-of-concept to production baseline.

### Phase 6 — Full 0.4.0 Godot MCP surface

Status: **complete** in v0.4.0.

- 119 tools;
- Project/InputMap/Scene/Node/Script/Resource/ClassDB/Editor;
- Runtime Debugger;
- Diagnostics;
- Batch;
- Credential Manager lifecycle;
- real full-surface ChatGPT regression.

See [v0.4.0 Release Record](DEVELOPMENT_0.4.md).

### Phase 7 — Release hardening

Status: **complete for the v0.4.0 Windows release**.

- project-scoped Windows x64 installer;
- addon ZIP and SHA-256 manifest;
- clean install and upgrade regression;
- Unicode/space path regression;
- Runtime autoload persistence hardening;
- Release assets re-downloaded and hash-verified;
- public bilingual documentation release pass.

## 4. Candidate next milestone

No 0.5.0 scope is locked yet. Candidate work should be prioritized by impact on the real autonomous development loop.

### A. Eyes and playtest controls

Priority candidate:

- screenshot / frame capture;
- deterministic input injection;
- input sequences;
- frame-step control;
- richer runtime logs;
- automated playtest/test-result workflows.

Goal:

```text
ChatGPT edits game
→ runs it
→ sees output
→ sends player input
→ advances deterministically
→ reads state/logs
→ fixes issues
```

### B. Tunnel operations UX

- explicit health/readiness state;
- tunnel-client version/update visibility;
- sanitized diagnostics report;
- clearer external-process/status handling.

### C. Compatibility

- additional Godot 4.x regression matrix;
- Windows versions beyond the current test machine;
- macOS/Linux packaging only if a supported runtime distribution path is established.

### D. Distribution maturity

- code signing/reputation strategy;
- reproducible CI validation;
- automated release gates where they can be made reliable.

## 5. Performance rules

- no shell/CLI hop for ordinary editor operations;
- keep schemas compact and descriptive;
- prefer bounded Batch where it genuinely reduces round trips;
- do not create high-frequency polling loops without a concrete need;
- keep Runtime/diagnostic payloads bounded.

## 6. Security rules

- project file/resource writes stay in `res://`;
- destructive operations require explicit behavior and clear errors;
- local MCP stays loopback-only;
- credentials remain outside project/Git;
- arbitrary shell/process execution is out of scope unless separately reviewed;
- Batch remains bounded and non-atomic;
- Runtime mutations must remain distinct from persisted editor mutations.

See [Security](../SECURITY.md).

## 7. Release discipline

A milestone is not complete until:

1. implementation exists;
2. targeted validation actually ran;
3. failures are fixed or recorded as blockers;
4. current progress is updated;
5. active release tracking is updated;
6. bilingual public docs are synchronized where applicable;
7. release artifacts are rebuilt from the exact release commit;
8. published assets are verified.

Follow [Development Workflow](DEVELOPMENT_WORKFLOW.md) and [Releasing](RELEASING.md).

## 8. Documentation rule

Do not mix historical WIP state with current product state.

- `README` — released user-facing entry;
- `TOOL_REFERENCE` — released tool behavior;
- `CHANGELOG` — shipped changes;
- `PROGRESS` — concise current status;
- `DEVELOPMENT_<version>` — closed release record once published;
- `PROGRESS_ARCHIVE_*` — historical implementation log;
- `DEVELOPMENT_PLAN` — released milestones + clearly marked candidate work.