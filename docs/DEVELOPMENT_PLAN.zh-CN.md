# 开发计划

[English](DEVELOPMENT_PLAN.md) | 简体中文

## 1. 产品目标

做一个小而实用的 Godot 4.x 编辑器插件，让 Web ChatGPT 通过 OpenAI Secure MCP Tunnel 控制真实 Godot 编辑器，而用户只需要提供：

1. Tunnel ID
2. Runtime API Key

普通用户不应该需要 CWapi、Codex、Node.js、本地 MCP Client 或手动配置端口。

## 2. 已锁定架构

从 2026-09-09 / 0.3.0 起：

```text
Web ChatGPT
 -> OpenAI Secure MCP Tunnel
 -> 插件内置官方 tunnel-client
 -> Godot loopback Streamable HTTP MCP
 -> Godot CommandRegistry
 -> Godot Editor API
```

除非未来有新的明确证据和架构讨论，否则不要恢复旧的 GDScript `/poll` + `/response` 实现。

普通用户路径也不要重新引入：

- stdio MCP；
- Node MCP bridge；
- localhost WebSocket；
- 自建公网 Relay；
- `.mcp.json` 本地客户端配置。

## 3. 为什么改架构

旧版 GDScript Tunnel Client 能过本地 simulator，却不能通过真实 ChatGPT 连接器创建。CWapi 的可用实现证明：官方 tunnel-client + localhost Streamable HTTP MCP 是更可靠的路线。

0.3.0 已经用真实 ChatGPT 连接器创建成功验证这项决定。

## 4. 当前组件

### Godot EditorPlugin

- 底部 `MCP ChatGPT` 面板；
- Tunnel ID + Runtime API Key；
- Connect / Disconnect；
- 状态和简短日志。

### Tunnel runner

- 启动内置官方 tunnel-client；
- 生成 profile；
- 用 `CONTROL_PLANE_API_KEY` 临时传 key；
- Tunnel ID 保存到 EditorSettings，Runtime API Key 保存到 Windows Credential Manager；
- 监控并停止子进程。

### Loopback MCP Server

- 只绑定 `127.0.0.1`；
- 随机端口 + 随机路径；
- Streamable HTTP JSON/SSE；
- `server/discover` / `initialize` / `ping` / `tools/list` / `tools/call`；
- notification ACK；
- HTTP DELETE session termination。

### 当前 Godot 工具

0.4.0 当前暴露 **119 个工具**，覆盖 Project/InputMap、Scene/Node、Script/Resource、ClassDB、Editor、Debugger/Runtime、Diagnostics 和 Batch。

完整索引见：[工具参考](TOOL_REFERENCE.zh-CN.md)。
## 5. 里程碑

## 5. 里程碑

### Phase 0 — 仓库与连续开发
状态：完成。

### Phase 1 — Godot 编辑器控制骨架
状态：完成。

### Phase 2 — 自建 Relay/WSS 探索
状态：完成但已废弃。

### Phase 3 — GDScript 直连 Secure Tunnel
状态：完成但已废弃。

### Phase 4 — 官方 tunnel-client 架构
状态：完成并本地验证。

已通过：

- 与 CWapi 验证相同的官方 tunnel-client runtime；
- 真实 Godot 4.7.2 GUI；
- Go MCP SDK 1.7；
- `server/discover`；
- initialization；
- 13 工具发现；
- scene/node/script 修改与保存回读；
- 通知；
- session termination。

### Phase 5 — 真实 ChatGPT 连接器
状态：**完成（2026-09-09）**。

真实用户 Tunnel ID / Runtime API Key 已成功创建 ChatGPT Tunnel 连接器。

### Phase 6 — 工具扩展 / 0.4.0 完全体开发
状态：**进行中**。

当前详细追踪：[`docs/DEVELOPMENT_0.4.zh-CN.md`](DEVELOPMENT_0.4.zh-CN.md)。

完成范围：

1. 119-tool 生产 registry；
2. Project 搜索/设置、InputMap；
3. Scene/Node 丰富读取与编辑；
4. Signal / Group / Metadata；
5. Script 自省/验证、Resource；
6. ClassDB 实时 API 自省；
7. Editor 控制 + Debugger/Runtime Bridge；
8. 有边界 captured diagnostics；
9. 有边界、非事务 Batch；
10. Windows Credential Manager 保存 + 重启自动连接；
11. 真实 ChatGPT Connector 全能力回归：`REAL_CHATGPT_GODOT_MCP_0_4_TEST=PASS`。
### Phase 7 — 发布加固
状态：**进行中**。

- Godot 面板增加更清晰的 tunnel health/readiness；
- 更完整的 key 清除/轮换 UX；
- 干净项目安装测试；
- Windows 发布 ZIP；
- 更多 Godot 4.x 兼容测试；
- macOS/Linux runtime 打包；
- 第三方二进制来源和许可证审计；
- 官方 tunnel-client 更新策略。

## 6. 性能原则

- 普通 Godot 工具调用不走 Shell/CLI；
- loopback MCP hop 是官方 tunnel-client 所需边界，可以接受；
- 编辑器 mutation 默认串行；
- Tool Schema 保持紧凑；
- 真正能减少 round-trip 时再增加 batch tool；
- 不为了“数量好看”一次性迁几百个低价值工具。

## 7. 安全原则

- 不记录/回显 Runtime API Key；
- Runtime API Key 只保存到 Windows Credential Manager，不写入项目/Git/tunnel profile；
- 使用受限 key；
- MCP 只监听 loopback；
- MCP URL 使用随机路径；
- 文件操作保持项目内；
- destructive annotation 必须准确；
- 场景覆盖必须显式 `overwrite: true`。

## 8. 连续开发规则

**每完成一个逻辑独立开发任务后，都必须先更新 `docs/PROGRESS.md` / `docs/PROGRESS.zh-CN.md`，再开始下一项任务。** 只有“实现完成 + 适用验证完成 + 进度文档更新”都完成后，任务才算完成。

详细规则见 [`docs/DEVELOPMENT_WORKFLOW.zh-CN.md`](DEVELOPMENT_WORKFLOW.zh-CN.md)。每次更新至少记录：

- 完成内容；
- 实际跑过的测试；
- 当前阻塞；
- 下一步。

新窗口在改架构前，必须先读 ARCHITECTURE、本计划、当前版本追踪文档和 PROGRESS。