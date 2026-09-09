# 当前项目状态

[English](PROGRESS.md) | 简体中文

本文是**当前状态的唯一进度入口**。0.3/0.4 开发周期的大量历史流水已经归档到 [PROGRESS_ARCHIVE_0.3-0.4.zh-CN.md](PROGRESS_ARCHIVE_0.3-0.4.zh-CN.md)，不再与当前状态混在一起。

## 当前 Release

| 项目 | 值 |
| --- | --- |
| 最新 Release | **v0.4.0** |
| Release 源码 Commit | `f12d268b5bca087ae8cef744f9cb7ab8877848e8` |
| Release Tag | `v0.4.0` |
| 主要平台 | Windows x64 |
| 已验证 Godot | 4.7.2 Standard x64 |
| 生产 MCP 工具 | **119** |
| Connector 路线 | Web ChatGPT + OpenAI Secure MCP Tunnel |
| Release 状态 | 已发布并验证 |
| 当前开发目标 | **v0.5.0 能力迁移** |
| v0.5 Public Tool 目标 | **默认 <=50 个 MCP Tools** |

Release：<https://github.com/AAAYNMMM/godot-mcp-chatgpt/releases/tag/v0.4.0>

## 生产架构

```text
Web ChatGPT
  ↓
OpenAI Secure MCP Tunnel
  ↓
官方 OpenAI tunnel-client
  ↓
Godot loopback Streamable HTTP MCP
  ↓
CommandRegistry
  ↓
Godot Editor API / Editor Debugger
```

本项目不实现 OpenAI Tunnel wire protocol，Tunnel Transport 兼容性由官方 runtime 负责。

## v0.4.0 已交付

- 119 个生产工具：Project、InputMap、Scene、Node、Script、Resource、ClassDB、Editor、Debugger、Runtime、Diagnostics、Batch。
- Runtime API Key 保存到 Windows Credential Manager。
- 重启自动重连与 Forget Saved Credentials。
- 基于 Godot Editor Debugger 的 Runtime Bridge。
- 有边界的运行诊断。
- 有上限、非事务的 Batch。
- Windows x64 项目级一键安装器。
- 可手动安装的 addon ZIP + SHA-256 清单。
- 使用 `ProjectSettings.save()` 确保 Runtime autoload 持久化。
- 中英双语用户/维护者文档。

## 验证状态

以下验证是**实际执行过**的：

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

真实 ChatGPT 回归通过真实 Connector 实际验证了 Editor 修改、Runtime 修改/读回、Diagnostics、Batch 和安全边界。

## 当前限制

这些是当前产品限制，不是 0.4.0 blocker：

- 目前只打包并验证 Windows x64。
- Godot 4.7.2 是明确验证基线；其他 Godot 4.x 需要单独兼容验证。
- Windows 安装器当前没有代码签名。
- 当前还没有 Screenshot/Vision、确定性输入注入和 Frame Step Playtest 工具。
- `batch.execute` 不是事务，不会回滚之前成功的操作。
- Runtime 修改不会自动写回保存的 Editor Scene。

## 当前文档状态

v0.4.0 文档成熟度整理已经完成：

- README 改成“Release/用户优先”，不再先讲开发历史；
- v0.4.0 明确关闭，不再显示 WIP；
- 当前进度压缩，历史流水归档；
- Development Plan 区分“已完成里程碑”和“未来候选方向”；
- Tool Reference 补充 Editor/Runtime 边界和常见错误；
- 新增可复现的 `RELEASING` 发布 Checklist。

## 最近完成的维护任务 — 文档成熟度整理

状态：**完成 / 验证通过**。

本次在不修改插件/Runtime 代码的前提下，把 v0.4.0 发布后的文档体系从“开发历史优先”整理成“Release / 用户优先”。

完成内容：

- 重写 README：第一屏突出价值、最新 Release、安装、能力、安全、验证和文档导航；
- `DEVELOPMENT_0.4` 从 WIP Tracker 正式关闭为 Release Record；
- 当前 `PROGRESS` 从长篇时间流水压缩成简洁当前状态；
- 0.3/0.4 的完整开发流水保留到明确 Archive；
- 重写 Development Plan，严格区分已完成里程碑和未来候选；
- Tool Reference 增加 Editor/Runtime 目标语义和常见错误；
- 新增中英双语可复现 Release Checklist；
- 清理公开 Architecture/FAQ 中影响成熟度的内部开发故事表述；
- Contributing/Development Workflow 与“发布收口 + 历史归档”规则对齐。

实际执行验证：

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

本任务没有修改任何插件/Runtime 源码。
## 当前开发 — v0.5.0 能力迁移

状态：**Phase A–C targeted validation passed；最终真实 Web ChatGPT 集成验证延后**。

下一里程碑已经锁定，完整范围见 [v0.5.0 能力迁移计划](DEVELOPMENT_0.5.zh-CN.md)。

Scope 规则：

- 迁移能力审计中 v0.4.0 真正缺失的全部 Godot-side 能力；
- 我们已经等价或更通用的能力不重复实现；
- 明确**不迁移** MCP Resources（`godot://...`）、MCP Client Auto-config、Python/FastMCP Server、Godot AI WebSocket Bridge；
- 新 Godot 能力继续 GDScript-first，保持现有 Editor / Runtime 架构；
- 把默认 Public MCP Tool Surface 从 119 个扁平 Tool 压缩为 **<=50 个** Compact Domain Tools，同时保留 Internal Atomic Commands。

必做迁移 Family 包括 Screenshot/Image、确定性 Input/Playtest、Native Frame Step、Live Logs、Script Patch/Write Diagnostics、GDScript Tests、UndoRedo/Rollback、Animation/Material/Audio/Particle/Camera/Theme/UI、Resource Helpers、TileMap/TileSet、GridMap、CSG、Autoload Mutation 和第三方 Custom Tool Registration。

### 最近完成的规划任务 — 迁移范围锁定

状态：**完成 / 文档验证通过**。

已完成：

- 审计 Godot AI 当前 Public Tool / Domain 能力面；
- 区分我们 v0.4 已等价/更强能力与真实缺口；
- 锁定四个明确排除项；
- 锁定 GDScript-first、Go 只做 OS Helper 的语言边界；
- 定义 Compact Public Surface 架构和 <=50 Release 目标；
- 新建中英文 v0.5 Active Tracker；
- 更新 Roadmap，并在 README 明确致谢 Godot AI 能力/Tool-Surface 设计参考。

### 本轮规划文档验证

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

### Phase A 实现 — Compact Public Tool Surface

状态：**已实现 / Official Tunnel 验证通过；最终真实 Web ChatGPT 集成验证延后**。

已实现：

- 在 MCP `tools/list/tools/call` 与 Internal `CommandRegistry` 之间增加 `PublicToolSurface`；
- 默认工具面压缩到 **39 个 Tools**（29 Direct + 10 Manage），但不删除 119 个 Atomic Commands；
- v0.4 的 119 个 Atomic 能力全部仍然可达；
- 增加 `*.manage(op, params)` Schema Validation 和结构化 Unknown-op Error；
- Batch 继续保持 Internal Atomic 行为；
- Official Tunnel Smoke 已升级，既有 Long-tail 行为测试会真实经过 Manage Tools。

实际执行：

```text
Godot 4.7.2 addon load/parse: PASS
npm run build: PASS
npm test: PASS
CATALOGUE_SCHEMA_GATE=PASS tools=39
COMPACT_TOOL_SURFACE_GATE=PASS public=39 atomic=119
PRODUCTION_PLUGIN_SMOKE=PASS
```

### Phase B — Observe / Play / Debug / Diagnose

状态：**targeted validation passed**。

- Public Surface：42；Internal Atomic：139；
- MCP Image + Game Screenshot：PASS；
- Runtime UI：PASS；
- Keyboard / Mouse / Gamepad / InputAction / Input Sequence：PASS；
- Native Debugger Control / Status：已实现并通过状态回归；
- Editor/Game Logs：PASS；
- Runtime Evaluate：PASS；
- Editor Performance / Refresh / confirm-gated Quit：已实现。

```text
CATALOGUE_SCHEMA_GATE=PASS tools=42
COMPACT_TOOL_SURFACE_GATE=PASS public=42 atomic=139
PRODUCTION_PLUGIN_SMOKE=PASS
```

### Phase C — Script / Test / Transaction

状态：**targeted validation passed**。

- Public Surface：47；Internal Atomic：153；
- Script Patch / Write Diagnostics：PASS；
- GDScript Test Runner：PASS，2/2；
- InputMap Ensure：PASS；
- Autoload Lifecycle：PASS；
- Core Node Mutation UndoRedo：PASS；
- Editor Undo / Redo：PASS；
- Transaction Batch Commit / Rollback：PASS；
- Unsupported Transaction Operation Preflight Reject：PASS；
- Official OpenAI Tunnel Production Smoke：PASS。

```text
CATALOGUE_SCHEMA_GATE=PASS tools=47
COMPACT_TOOL_SURFACE_GATE=PASS public=47 atomic=153
PRODUCTION_PLUGIN_SMOKE=PASS
```

### 精确下一项实现任务

**开始 Phase D：Animation / Material / Shader / Audio / Particles / Camera / Theme / UI / Resource Helpers。真实 Web ChatGPT Connector 测试继续统一留到 Phase F。**

## 文档职责

- 用户入口：[README](../README.zh-CN.md)
- 安装连接：[快速上手](QUICKSTART.zh-CN.md)
- 工具行为：[工具参考](TOOL_REFERENCE.zh-CN.md)
- 安全边界：[安全](../SECURITY.zh-CN.md)
- 架构：[架构](ARCHITECTURE.zh-CN.md)
- 路线图：[开发计划](DEVELOPMENT_PLAN.zh-CN.md)
- 发布流程：[发布](RELEASING.zh-CN.md)
- 已关闭 0.4 技术记录：[Development 0.4](DEVELOPMENT_0.4.zh-CN.md)
- 历史开发流水：[0.3–0.4 归档](PROGRESS_ARCHIVE_0.3-0.4.zh-CN.md)