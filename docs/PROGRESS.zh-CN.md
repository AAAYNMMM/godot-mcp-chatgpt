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
## 后续优先方向

当前没有锁死某一个下一功能。候选方向：

1. Screenshot / 视觉检查；
2. 确定性输入注入与 Playtest；
3. Frame Step、Runtime Log、测试工作流；
4. Tunnel Health/Readiness 诊断；
5. 更多 Godot 4.x 兼容验证；
6. CI / 仓库自动化和 Windows 代码签名策略。

不要为了数字继续无意义增加 Tool 数量。

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