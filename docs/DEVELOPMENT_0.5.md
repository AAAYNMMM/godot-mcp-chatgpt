# v0.5.0 Capability Migration Plan

English | [简体中文](DEVELOPMENT_0.5.zh-CN.md)

Status: **planned / scope locked; implementation not started**

Baseline release: **v0.4.0**

Reference capability surface: [hi-godot/godot-ai](https://github.com/hi-godot/godot-ai), audited against its current `docs/TOOLS.md` and tool-surface guidance on 2026-09-10.

This document is the active tracker for the next development milestone. Nothing in this file is a released capability until implementation and validation are complete and the public release documentation is updated.

## 1. Goal

v0.5.0 has two linked goals:

1. migrate the useful Godot-side capabilities that Godot AI currently has and `godot-mcp-chatgpt` v0.4.0 does not;
2. compress the public MCP tool surface from the current 119 flat tools to a compact domain-oriented surface without deleting the underlying capabilities.

The intended result is a stronger autonomous game-development loop:

```text
ChatGPT inspects project
→ edits scenes/scripts/resources
→ runs game
→ sees editor/game framebuffer
→ injects deterministic player input
→ steps/debugs runtime
→ reads structured logs
→ runs tests
→ edits high-level Godot content
→ verifies and fixes
```

Tool count is no longer a product metric. Capability coverage, reliability, discoverability, and schema cost are the metrics.

## 2. Product decisions locked for this migration

### 2.1 Migrate capabilities, not Godot AI's architecture

New Godot/editor/runtime capabilities must fit the existing architecture:

```text
Web ChatGPT
  ↓
OpenAI Secure MCP Tunnel
  ↓
official tunnel-client
  ↓
Godot-hosted Streamable HTTP MCP
  ↓
compact public MCP catalogue
  ↓
internal atomic CommandRegistry
  ↓
Godot Editor API / EditorDebuggerPlugin / EngineDebugger
```

Language boundary:

| Layer | Language / mechanism |
| --- | --- |
| Godot Editor operations | **GDScript** |
| Runtime/game operations | **GDScript** through the existing debugger bridge |
| Public MCP catalogue and domain dispatch | **GDScript** |
| MCP image-content serialization | **GDScript** |
| Undo/Redo and atomic editor actions | **GDScript** using Godot `EditorUndoRedoManager` |
| GDScript test runner | **GDScript** |
| Windows Credential Manager helper | Go, existing |
| Windows installer | Go, existing |
| Bounded child-process output capture | Go, existing |
| New OS-native helper | Go only when a Godot API cannot reasonably provide the capability |

Do **not** introduce Python, FastMCP, `uv`, Node.js, C#, or another WebSocket server merely to copy an upstream implementation.

### 2.2 Four explicit exclusions

The following Godot AI capabilities/components are **not part of the migration**:

| Excluded item | Decision |
| --- | --- |
| MCP Resources such as `godot://...` | Do not migrate |
| MCP client auto-configuration | Do not migrate |
| Python / FastMCP server | Do not migrate |
| Godot AI WebSocket bridge | Do not migrate |

These are the explicit scope exclusions for the audited capability surface.

### 2.3 Do not duplicate equivalent or stronger capabilities

If v0.4.0 already provides an equivalent or more general capability, retain the existing implementation and expose it through the new compact surface instead of porting a second implementation.

Examples:

- Scene/Node CRUD and hierarchy inspection;
- node properties/methods/groups/metadata/signals;
- script read/write/attach/detach/introspection;
- generic Resource inspection/mutation;
- ProjectSettings and filesystem operations;
- basic InputMap editing;
- ClassDB inspection (our current surface is already more granular);
- editor selection/filesystem/script state;
- runtime SceneTree/node property/method inspection;
- bounded diagnostics child-run;
- debugger session routing already needed by our project-scoped runtime bridge.

Godot AI's cross-editor `session_activate`/session list is treated as architecturally satisfied for this product: each Secure MCP tunnel endpoint is bound to one project-scoped Godot addon, while runtime debugger calls already support explicit debugger `session_id` routing. No second multi-editor routing layer is required.

## 3. Missing capabilities that must be migrated

The following list is the required v0.5.0 migration scope. A row may be implemented as a new operation on a compact domain tool or as an enhancement to an existing internal command; it does not imply one new top-level MCP tool per row.

### 3.1 Visual observation and game liveness

| Capability | v0.4.0 gap | v0.5 action | Layer |
| --- | --- | --- | --- |
| MCP image content | tools/call currently serializes text only | Add MCP `image` content support while preserving normal structured text results | GDScript MCP server |
| Editor 3D viewport capture | Missing | Add screenshot mode | GDScript editor |
| Editor 2D viewport capture | Missing | Add screenshot mode | GDScript editor |
| Camera3D/cinematic render capture | Missing | Add screenshot mode with bounded dimensions | GDScript editor/runtime |
| Running game framebuffer | Missing | Add game screenshot path | GDScript runtime/editor |
| Project-run liveness | `editor.run_project` starts play but does not classify helper/runtime readiness | Enhance run/status with launching/live/break/stopped style state and recent-error hints | GDScript editor/debugger |
| Runtime UI element discovery | Missing | Enumerate relevant live `Control` elements and bounded properties | GDScript runtime |

Screenshot responses must be bounded by dimension/byte caps and must not write arbitrary files outside the project as a side effect.

### 3.2 Input and deterministic playtest

Required runtime operations:

- keyboard press/release;
- mouse button/motion/wheel input;
- gamepad button/axis input;
- InputMap action press/release with strength;
- input-state inspection;
- frame-timed `input_sequence` with ordered steps and hard step/frame bounds;
- explicit release/cleanup of actions still held after a sequence.

`input_sequence` must execute in the running Godot process so network/tunnel latency cannot change frame timing.

Implementation: **GDScript in the existing runtime bridge**, reached through EditorDebugger/EngineDebugger. Do not add a second runtime transport.

### 3.3 Native debugger control

v0.4.0 already has runtime `pause`/`resume` by changing SceneTree paused state. v0.5 must additionally support the missing native-debugger semantics where Godot exposes them:

- debugger suspend;
- debugger resume;
- next-frame / single-frame advance;
- richer debug/break status;
- clean distinction between gameplay SceneTree pause and debugger suspension.

Implementation: **GDScript EditorDebuggerPlugin / EditorDebuggerSession APIs**, with feature detection against the live Godot version.

### 3.4 Logs and diagnostics observability

Migrate the useful log workflow, not its Python transport:

- editor/plugin log ring buffer;
- running-game log buffer;
- combined reads;
- structured error/warning entries where Godot exposes source/line/stack details;
- incremental cursor reads with truncation indication;
- per-game-run identity so old and current run output are distinguishable;
- clear operation, with debugger-visible error clearing kept explicit;
- recent/new error and warning hints after tool calls where reliable;
- boot/parse/load failure visibility even when the game process never reaches runtime helper readiness.

Keep `diagnostics.run_capture` for clean bounded child-process validation; logs are an additional live-editor/runtime path, not a replacement.

Implementation: primarily **GDScript**, with the existing Go run-helper retained only for child-process capture.

### 3.5 Script authoring improvements

Required additions:

- anchor-based script patch (`old_text` → `new_text`);
- ambiguity detection;
- optional `replace_all`;
- per-write GDScript validation result returned with script writes/patches;
- structured diagnostics scoped to the written file where Godot exposes them;
- clear distinction between “file written” and “script parsed successfully”.

Existing `script.write`, `script.validate`, and `script.get_info` remain the underlying general capabilities.

### 3.6 Test runner

Add an in-editor GDScript test layer:

- discover/list test suites;
- run one or more suites;
- structured pass/fail/error results;
- duration and assertion details;
- retrieve most recent results;
- explicit cache/freshness warning when dependency changes can make same-editor validation stale;
- bounded output and deterministic cleanup.

Implementation: **GDScript**. Do not add pytest as a runtime dependency.

### 3.7 Undo/Redo and atomic editing

v0.4.0 `batch.execute` is intentionally non-atomic. v0.5 must add missing editor transaction behavior:

- editor mutations that can safely use `EditorUndoRedoManager` should become undoable;
- responses should state whether an operation is undoable;
- add grouped batch execution with rollback/undo-on-first-error for supported editor mutations;
- retain a clearly documented non-atomic path for operations that cannot be rolled back (file writes, external process execution, scene open/close where appropriate);
- never claim atomicity across operations that Godot cannot actually reverse.

This is a semantic migration, not only a new Batch tool name.

### 3.8 Editor operations still missing

Migrate:

- editor performance/monitor snapshot where distinct from live game performance;
- plugin reload with filesystem rescan/readiness checks and bounded reconnect behavior appropriate to our in-process transport;
- editor quit with destructive annotation and explicit safe behavior;
- live-game evaluation/command capability only after a separate security review defines a bounded contract (no generic OS shell and no arbitrary project-external execution);
- log clear behavior described above.

`game_eval` must not become a loophole that defeats the project's “no arbitrary shell/process MCP tool” security boundary.

### 3.9 InputMap idempotent helpers

Existing InputMap editing remains. Add the missing idempotent semantics:

- ensure action;
- ensure binding;
- bind-event helper behavior that avoids duplicate bindings.

These should be ops under the compact InputMap domain, not new top-level tools.

### 3.10 Autoload management

Existing autoload inspection remains. Add:

- add autoload;
- remove autoload;
- conflict validation;
- explicit `ProjectSettings.save()` persistence;
- reserved-name protection for `GodotMCPChatGPTRuntime`.

### 3.11 Animation authoring

Migrate the missing high-level Animation capability set:

- create AnimationPlayer/library/clip as needed;
- delete animation;
- validate animation;
- add property track;
- add method track;
- add/update keys required by those tracks;
- autoplay;
- play/stop;
- list/get;
- simple animation helper;
- fade/slide/shake/pulse presets.

Use Godot Resources and `EditorUndoRedoManager`; do not create a parallel animation file format.

### 3.12 Material and shader authoring

Migrate:

- material creation;
- material parameter update;
- shader parameter update;
- inspect/get/list;
- assign/apply to node;
- useful bounded presets.

Generic `resource.*` remains available internally; the new domain provides higher-level ergonomics.

### 3.13 Audio authoring

Migrate:

- AudioStreamPlayer / 2D / 3D creation where appropriate;
- set stream;
- playback configuration;
- play/stop preview/control where safe;
- list/inspect audio players.

### 3.14 Particle authoring

Migrate:

- create particle nodes/resources;
- main parameters;
- process material parameters;
- draw pass configuration;
- restart;
- inspect;
- useful presets.

### 3.15 Camera authoring

Migrate:

- Camera2D/Camera3D creation;
- common configuration;
- Camera2D limits;
- Camera2D damping;
- follow helper;
- get/list;
- useful presets.

### 3.16 Theme and UI authoring

Theme operations:

- create Theme;
- set color;
- set constant;
- set font size;
- create/apply bounded StyleBoxFlat values;
- apply theme.

UI operations:

- anchor/layout presets;
- text updates;
- higher-level layout building;
- bounded draw-recipe/control construction helpers.

These must use normal Godot Control/Theme APIs and remain inspectable/editable after creation.

### 3.17 Resource helper operations

Do not duplicate our existing general Resource CRUD. Add only the missing high-level helpers:

- resource assignment ergonomics where generic Node/Resource setters are insufficient;
- Curve point editing;
- Environment creation/configuration helper;
- physics-shape auto-fit;
- physics-shape generation;
- GradientTexture creation;
- NoiseTexture creation.

### 3.18 TileMap / TileSet

Migrate:

- set one cell;
- set rectangular cell ranges;
- clear;
- read used/selected cells needed for verification;
- inspect atlas tiles;
- inspect atlas source image/resource metadata needed for tile selection.

Implementation must target Godot 4.7 APIs and validate TileMap/TileSet API changes through ClassDB before hard-coding assumptions.

### 3.19 GridMap

Migrate:

- set item;
- fill region;
- clear;
- read used cells;
- list mesh-library items.

### 3.20 CSG

Migrate:

- create common CSG nodes;
- configure CSG operation;
- validate parent/type constraints.

### 3.21 Third-party custom tool extension

Migrate the missing extensibility concept in a form native to this addon:

- third-party Godot addons can register bounded custom MCP commands with this plugin;
- list registered custom commands;
- invoke enabled custom commands;
- per-command enable/disable;
- optional promotion of a small capped set to first-class public tools only when explicitly requested;
- schema validation and destructive/read-only hints are mandatory;
- custom tools cannot bypass project path/security boundaries merely by registration.

Implementation: **GDScript extension API around our CommandRegistry**. No Python plugin system.

## 4. Public tool-surface compression

### 4.1 Why

v0.4.0 exposes 119 separate top-level MCP tools. That is proven to work with Web ChatGPT, but continuing the same pattern while adding the v0.5 capability set would make discovery and schema cost worse.

v0.5.0 therefore separates **internal commands** from **public MCP tools**.

As a reference point, the Godot AI surface audited on 2026-09-10 exposes **46 public MCP tools: 19 high-traffic named tools + 27 domain rollups**; its plugin command surface remains independent from that public compression. We adopt the same separation principle without copying its Python registration layer.

### 4.2 Two-layer model

```text
Public compact MCP surface (target: <= 50 tools)
                 ↓
      domain op dispatch/validation
                 ↓
Internal atomic CommandRegistry (119 existing + migrated commands)
                 ↓
        Godot editor/runtime APIs
```

Rules:

- do not delete atomic command implementations merely to reduce public tool count;
- `batch` and internal regression tests continue to address atomic command names;
- the public catalogue exposes high-frequency verbs directly and long-tail verbs through one `domain.manage` tool per domain;
- every `domain.manage` takes an `op` enum plus a `params` object;
- the dispatcher validates `params` against the underlying atomic command schema;
- unknown `op` returns a structured error and suggestions;
- descriptions include the domain's searchable keywords and supported operations;
- runtime/debugger domains keep optional `session_id` routing;
- top-level schemas remain bounded and use `additionalProperties=false` where practical.

### 4.3 Target public shape

Initial target: **40–50 public MCP tools**, with a hard release gate of **<= 50** unless a measured Web ChatGPT usability test justifies an exception.

High-frequency named tools should remain directly discoverable, approximately:

- status/project inspection;
- scene hierarchy/open/save;
- node create/find/get-properties/set-property;
- script write/attach/patch;
- resource/ClassDB inspection;
- project run;
- screenshot;
- logs read;
- test run;
- runtime status;
- batch execute.

Long-tail operations should roll up under domains such as:

```text
project.manage
filesystem.manage
scene.manage
node.manage
script.manage
resource.manage
classdb.manage
editor.manage
debugger.manage
runtime.manage
input_map.manage
diagnostics.manage
test.manage
animation.manage
material.manage
audio.manage
particle.manage
camera.manage
theme.manage
ui.manage
autoload.manage
tilemap.manage
tileset.manage
gridmap.manage
csg.manage
custom.manage
```

The exact named-vs-rollup split is implementation work, but the <=50 default surface and “internal commands remain atomic” architecture are locked.

### 4.4 Compatibility strategy

v0.5.0 may be a tool-surface breaking release for callers that hard-code v0.4 top-level tool names. Web ChatGPT normally re-discovers the live catalogue, so the preferred migration is to publish the compact surface cleanly rather than keep 119 public aliases forever.

Before release, evaluate whether an **optional, disabled-by-default legacy registration mode** is low-cost. It must not increase the default compact tool count and is not required to complete the capability migration.

## 5. Migration phases

### Phase A — Compact-surface foundation

Status: **planned**.

- add internal/public catalogue separation;
- add `domain.manage` dispatcher;
- migrate all existing v0.4 capability access to the compact surface;
- preserve atomic CommandRegistry behavior;
- add public-tool-count/schema gates;
- real ChatGPT regression before adding new capability families.

### Phase B — Observe, play, debug, diagnose

Status: **planned**.

- MCP image content;
- screenshots;
- run liveness;
- UI element discovery;
- keyboard/mouse/gamepad/action input;
- deterministic input sequence;
- native debugger step/status;
- live editor/game logs;
- editor monitor/reload/quit/game-eval bounded design.

### Phase C — Script/test/transaction workflow

Status: **planned**.

- script patch;
- write diagnostics;
- GDScript test runner/results;
- InputMap ensure helpers;
- UndoRedo conversion for eligible editor mutations;
- atomic/rollback Batch for supported operations;
- autoload add/remove.

### Phase D — High-level content authoring

Status: **planned**.

- Animation;
- Material/shader;
- Audio;
- Particles;
- Camera;
- Theme;
- UI/layout/draw recipes;
- resource helper operations.

### Phase E — World building and extensibility

Status: **planned**.

- TileMap/TileSet;
- GridMap;
- CSG;
- custom third-party tool registration/invocation.

### Phase F — Full migration regression and release hardening

Status: **planned**.

- compact-surface tool-count/schema gate;
- capability parity audit against the locked migration matrix;
- Godot 4.7.2 compile/load;
- real editor behavior tests;
- real runtime playtest sequence;
- screenshot returned through real ChatGPT Connector;
- logs/test/UndoRedo regression;
- installer upgrade regression;
- clean release asset rebuild and verification;
- bilingual public docs and acknowledgements.

## 6. Required validation gates

No migrated domain is complete just because its GDScript compiles.

Each domain must pass, as applicable:

1. Godot 4.7.2 script parse/load;
2. schema registration and duplicate-op checks;
3. targeted real-editor behavior test;
4. undo/redo behavior where the domain mutates editor state;
5. path/security boundary tests;
6. runtime/debugger round-trip when game-side behavior is involved;
7. bounded payload/timeout tests;
8. real compact-surface MCP call through the official tunnel path;
9. progress + active tracker update before the next domain starts.

Release-level required markers will include at minimum:

```text
COMPACT_TOOL_SURFACE_GATE=PASS tools<=50
CAPABILITY_MIGRATION_MATRIX=PASS
PRODUCTION_PLUGIN_SMOKE=PASS
REAL_CHATGPT_GODOT_MCP_0_5_TEST=PASS
```

Additional family-specific markers must be added as implementation begins.

## 7. Security requirements

Migration does not relax v0.4 security boundaries.

- project filesystem writes remain under `res://`;
- no arbitrary OS shell MCP tool;
- image capture is bounded and memory-only by default;
- input injection only targets the running Godot game/editor path;
- `game_eval` requires an explicit bounded contract before implementation;
- custom third-party tools are opt-in, schema-validated, and cannot silently widen core permissions;
- editor quit is destructive and must be annotated accordingly;
- atomic Batch must not claim rollback for irreversible operations;
- credentials remain outside project/Git.

## 8. Upstream reference and licensing

Godot AI is an MIT-licensed independent project and is used as a **capability and design reference** for this migration.

Repository: <https://github.com/hi-godot/godot-ai>

Rules for implementation:

- prefer reimplementation against Godot's own APIs when practical;
- when substantial source code is ported or derived from Godot AI, preserve the applicable copyright/MIT notice;
- record derived areas in `THIRD_PARTY_NOTICES.md` and its Simplified Chinese counterpart;
- do not copy its Python/FastMCP/WebSocket transport stack into this project;
- attribution must be updated as migration code lands, not postponed until release day.

## 9. Current status

Status: **planning complete / implementation not started**.

Locked decisions:

- v0.5.0 is the capability-migration milestone;
- all audited missing Godot-side capabilities above are required except the four explicit exclusions;
- existing equivalent/better capabilities are retained instead of duplicated;
- new Godot capability code is GDScript-first;
- default public MCP surface target is <=50 tools;
- internal atomic commands remain available to the implementation/test layers;
- README acknowledges Godot AI as an upstream capability/design reference.

## 9.1 Planning-document validation

```text
MIGRATION_SCOPE_GATE=PASS
EXCLUSION_GATE=PASS count=4
COMPACT_TOOL_PLAN_GATE=PASS target<=50
UPSTREAM_COMPRESSION_REFERENCE=PASS 46=19+27
README_GODOT_AI_ACK=PASS
DOC_LINK_CHECK=PASS files=36
DIFF_CHECK=PASS
DOC_ONLY_SCOPE=PASS
PLANNING_DOC_GATES=PASS
```

## 10. Exact next implementation task

**Build Phase A: separate the public MCP catalogue from the internal atomic CommandRegistry, introduce the domain-manage dispatcher, map the existing v0.4 capabilities onto a <=50-tool compact surface, and run a full real ChatGPT regression before migrating new capability families.**
