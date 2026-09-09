# 开发工作流

[English](DEVELOPMENT_WORKFLOW.md) | 简体中文

本文档规定仓库的开发记录规则。它不是可选的流程说明，而是开发任务 Definition of Done 的一部分。

## 1. 信息来源分工

不同文档负责不同层级的事实：

| 文档 | 用途 | 允许声明的内容 |
| --- | --- | --- |
| `README.md` | 面向用户的项目入口 | 已发布或已明确真实验证的用户能力 |
| `docs/TOOL_REFERENCE.md` | 正式工具契约 | 当前已验证 release/main 基线中的工具 |
| `CHANGELOG.md` | 发布历史 | 已交付的改动 |
| `docs/DEVELOPMENT_PLAN.md` | 长期路线图 | 里程碑、架构规则、计划阶段 |
| `docs/DEVELOPMENT_<version>.md` | 当前版本开发追踪 | 工作区实现状态、验证状态、阻塞项 |
| `docs/PROGRESS.md` | 交接与时间线事实 | 真正完成了什么、真正跑过什么测试、当前阻塞、下一项任务 |

未经验证的开发中能力不能提前写成 README、Tool Reference 或 Changelog 的正式能力。

## 2. 完成定义

开发任务不能因为“代码写完了”就标记为完成。

只有满足所有适用条件后，任务才可以标记为 **complete**：

1. 实现已经存在；
2. 对应的目标验证已经真实执行；
3. 验证发现的问题已经解决，或明确登记为 blocker；
4. `docs/PROGRESS.md` 已更新结果；
5. 当前版本追踪文档已同步状态；
6. 有中英文配对的开发文档已同步简体中文版。

如果代码已写但还没验证，应写 `implemented / validation pending`，不能写 `complete`。

## 3. 强制进度更新频率

**每完成一个逻辑独立任务后，都必须先更新 `docs/PROGRESS.md`，再进入下一项任务。**

典型任务边界：

- 凭据保存实现 + 凭据读写测试；
- Project 命令模块 + Godot 编译验证；
- Scene/Node 模块 + Godot 编译验证；
- Runtime Debugger Bridge + 运行时 smoke；
- 生产注册 + 完整 catalogue/schema 测试；
- Release 回归 + 发布提交。

不要等数小时开发结束后再靠聊天记录和记忆反推进度。

## 4. Progress 条目格式

每个完成任务应记录：

```text
Task:
Status:
Files / module:
What changed:
Validation actually run:
Result:
Known limitation / blocker:
Exact next task:
```

只记录事实。没有实际跑过的测试不能写 PASS；模拟器验证不能描述成真实 ChatGPT 生产验证。

## 5. 统一状态词

统一使用：

- `planned` — 已确定要做，尚未开始；
- `in progress` — 正在开发；
- `implemented / validation pending` — 代码已存在，所需验证尚未通过；
- `targeted validation passed` — 模块级验证通过，完整集成仍未验证；
- `blocked` — 存在明确阻塞项；
- `integration passed` — 已集成的生产路径通过定义好的集成测试；
- `release validated` — 完整发布门禁通过；
- `complete` — 任务验收条件和文档更新均完成。

## 6. 当前版本追踪文档

大型开发版本必须建立独立追踪，例如：

```text
docs/DEVELOPMENT_0.4.md
docs/DEVELOPMENT_0.4.zh-CN.md
```

应记录：

- 范围和非目标；
- 模块 checklist；
- 工具分组；
- 验证门禁；
- 安全决策；
- 已知 blocker；
- 精确发布验收条件。

它可以描述尚未提交的持久工作区代码，但必须明确标记状态。

## 7. 中英双语规则

Development Plan、当前版本追踪和 Progress 必须维护英文 + 简体中文。

一个任务修改这些文档时，同一任务内更新对应翻译。工具名、命令、错误字符串、哈希和版本号保持原文，不翻译。

## 8. 开发文档与发布文档边界

开发期间：

- `docs/DEVELOPMENT_<version>.md` 可以列出正在开发的工具；
- `docs/PROGRESS.md` 可以描述未提交的工作区状态；
- `docs/TOOL_REFERENCE.md` 在新版本通过集成/发布门禁之前，必须继续描述最后一个已验证公开基线。

新版本完整验证后，再统一升级 README、Tool Reference 和 Changelog。

## 9. 提交/推送前门禁

开发版本作为已验证基线推送前，应执行适用门禁并把结果记录到 `docs/PROGRESS.md`：

- 目标 Godot 版本全脚本编译；
- 模块专项测试；
- MCP tool catalogue/schema 验证；
- 本地 Streamable HTTP MCP 测试；
- 修改 Tunnel 相关代码时执行 official tunnel-client 集成测试；
- 编辑器修改能力执行真实 Godot GUI smoke；
- 修改凭据代码时执行凭据保存 + 重启恢复测试；
- secret scan；
- BOM / `git diff --check` / 仓库卫生检查；
- 大规模文档改动执行链接检查。

门禁可以增加，不能为了方便悄悄减少。

## 10. 交接规则

结束开发窗口前，`docs/PROGRESS.md` 必须明确：

- 当前分支 / 目标版本；
- 上次记录后完成的工作；
- 验证证据；
- 当前 blocker；
- 精确下一项任务；
- 当前工作是已 commit/push，还是只存在持久工作区。

新开发窗口在修改架构或工具契约前应按顺序阅读：

1. `docs/ARCHITECTURE.md`
2. `docs/DEVELOPMENT_PLAN.md`
3. 当前 `docs/DEVELOPMENT_<version>.md`
4. `docs/PROGRESS.md`