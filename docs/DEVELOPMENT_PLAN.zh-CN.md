# 开发计划

[English](DEVELOPMENT_PLAN.md) | 简体中文

本文严格区分**已经发布的里程碑**与**未来候选工作**。已经发布的行为写进 README / Tool Reference / CHANGELOG；未发布想法必须明确标记为 Planned/Candidate，不能写得像已经交付。

## 1. 产品目标

让 Web ChatGPT 真正形成 Godot 开发闭环：

```text
在 ChatGPT 描述需求
→ 读取真实 Godot 项目
→ 查询当前 Godot API
→ 修改
→ 保存
→ 运行
→ 读取 Runtime / Diagnostics
→ 修复
```

产品保持项目级、低摩擦、危险操作边界清楚，并且不要求桌面 AI 客户端。

## 2. 当前生产架构

```text
Web ChatGPT
  ↓
OpenAI Secure MCP Tunnel
  ↓
内置官方 tunnel-client
  ↓
Godot loopback Streamable HTTP MCP
  ↓
CommandRegistry
  ↓
Godot Editor API / Editor Debugger
```

锁定原则：

- 使用官方 OpenAI Tunnel Runtime；
- 本地 MCP 只监听 loopback；
- 普通 Godot 操作保持进程内调用；
- 文件/Resource 修改限制在 `res://`；
- 不经过独立安全评审，不增加任意 Shell；
- 不为了 Tool 数量好看而继续堆工具。

## 3. 已发布里程碑

### Phase 0 — 仓库连续性

状态：**完成**。

- 建立仓库结构和中英双语文档；
- 明确源码/构建/测试边界。

### Phase 1 — Godot Editor 控制骨架

状态：**完成**。

- EditorPlugin；
- Bottom Panel；
- Command Registry；
- 初始 Scene/Node/Script/Editor 操作。

### Phase 2 — Transport 探索

状态：**完成 / 已被替代**。

- 早期直连实验明确了需求；
- 生产不再使用自定义直连 Tunnel 实现。

### Phase 3 — GDScript 直连 Tunnel 原型

状态：**完成 / 已被替代**。

- 作为本地 Proof 有价值；
- 真实 Connector 不兼容后不再作为生产架构。

### Phase 4 — 官方 tunnel-client 架构

状态：**v0.3.0 完成**。

- 官方 OpenAI `tunnel-client`；
- Godot 内 loopback Streamable HTTP MCP；
- 真实 ChatGPT Connector 创建验证通过。

### Phase 5 — 真实 ChatGPT Connector 基线

状态：**完成**。

- 真实 Connector discovery/call 验证；
- Transport 从 Proof 进入生产基线。

### Phase 6 — 0.4.0 完整 Godot MCP Surface

状态：**v0.4.0 完成**。

- 119 tools；
- Project/InputMap/Scene/Node/Script/Resource/ClassDB/Editor；
- Runtime Debugger；
- Diagnostics；
- Batch；
- Credential Manager 生命周期；
- 真实 ChatGPT 全能力回归。

详见 [v0.4.0 发布记录](DEVELOPMENT_0.4.zh-CN.md)。

### Phase 7 — Release 加固

状态：**v0.4.0 Windows Release 已完成**。

- Windows x64 项目级安装器；
- addon ZIP + SHA-256；
- 干净安装与升级回归；
- 中文/空格路径回归；
- Runtime Autoload 持久化加固；
- Release 资产重新下载并校验哈希；
- 中英文公开文档发布整理。

## 4. 下一里程碑候选方向

当前还没有锁死 0.5.0 Scope。下一步应按“真实自动开发闭环价值”排序。

### A. 眼睛 + Playtest 控制

优先候选：

- Screenshot / Frame Capture；
- 确定性输入注入；
- Input Sequence；
- Frame Step；
- 更完整 Runtime Log；
- 自动 Playtest / Test Result 工作流。

目标：

```text
ChatGPT 修改游戏
→ 运行
→ 看画面
→ 发送玩家输入
→ 确定性推进
→ 读取状态/日志
→ 自动修复
```

### B. Tunnel 运维 UX

- 明确 Health / Readiness；
- Tunnel Client 版本/更新可见；
- 脱敏诊断报告；
- 更清楚的外部进程/连接状态。

### C. 兼容性

- 更多 Godot 4.x 回归矩阵；
- 更多 Windows 环境；
- 只有在建立可靠 Runtime 分发路线后再考虑 macOS/Linux。

### D. 分发成熟度

- Windows 代码签名/信誉策略；
- 可复现 CI；
- 能稳定自动化的 Release Gate。

## 5. 性能原则

- 普通 Editor 操作不走 Shell/CLI；
- Schema 保持紧凑清晰；
- 只有确实减少 Round Trip 时才使用 Batch；
- 没有明确需求时不增加高频 Polling；
- Runtime/Diagnostics 输出保持有上限。

## 6. 安全原则

- 项目文件/Resource 写入限制在 `res://`；
- Destructive 操作必须有明确行为和错误；
- Local MCP 只监听 loopback；
- Credential 不进入项目/Git；
- 任意 Shell/Process Execution 默认不在范围内；
- Batch 有上限且非事务；
- Runtime 修改与持久化 Editor 修改严格区分。

详见 [安全](../SECURITY.zh-CN.md)。

## 7. Release 纪律

一个 Milestone 只有在以下全部满足后才算完成：

1. 实现存在；
2. 目标验证真实执行；
3. 失败已经修复或记录为 blocker；
4. Current Progress 更新；
5. Active Release Tracker 更新；
6. 对应中英公开文档同步；
7. Release 产物从精确 Commit 重建；
8. 发布后的资产重新验证。

遵循 [开发工作流](DEVELOPMENT_WORKFLOW.zh-CN.md) 和 [发布流程](RELEASING.zh-CN.md)。

## 8. 文档规则

不要把历史 WIP 状态和当前产品状态混在一起。

- `README` — 已发布用户入口；
- `TOOL_REFERENCE` — 已发布 Tool 行为；
- `CHANGELOG` — 已发布变化；
- `PROGRESS` — 精简当前状态；
- `DEVELOPMENT_<version>` — 发布后转为关闭版本记录；
- `PROGRESS_ARCHIVE_*` — 历史实现流水；
- `DEVELOPMENT_PLAN` — 已发布里程碑 + 明确标注的未来候选。