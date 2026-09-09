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
- 只持久化 Tunnel ID；
- 监控并停止子进程。

### Loopback MCP Server

- 只绑定 `127.0.0.1`；
- 随机端口 + 随机路径；
- Streamable HTTP JSON/SSE；
- `server/discover` / `initialize` / `ping` / `tools/list` / `tools/call`；
- notification ACK；
- HTTP DELETE session termination。

### 当前 Godot 工具

```text
godot.get_status
project.get_info
scene.get_tree
scene.create
scene.save
node.create
node.set_property
node.delete
script.read
script.write
script.attach
editor.run_project
editor.stop
```

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

### Phase 6 — 工具扩展
状态：**下一阶段**。

优先级：

1. 更完整的节点/属性读取；
2. scene open/close；
3. Resource；
4. ProjectSettings / InputMap；
5. Signal；
6. ClassDB；
7. 编辑器/运行时错误；
8. Playtest 诊断；
9. 批量节点/属性操作；
10. 如确有价值，再评估截图工作流。

### Phase 7 — 发布加固

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

- 不记录 Runtime API Key；
- 不把 key 写入 tunnel profile；
- 使用受限 key；
- MCP 只监听 loopback；
- MCP URL 使用随机路径；
- 文件操作保持项目内；
- destructive annotation 必须准确；
- 场景覆盖必须显式 `overwrite: true`。

## 8. 连续开发规则

每个有实质进展的开发窗口都更新 `docs/PROGRESS.md` / `docs/PROGRESS.zh-CN.md`：

- 完成内容；
- 实际跑过的测试；
- 当前阻塞；
- 下一步。

新窗口在改架构前，必须先读 README、ARCHITECTURE 和 PROGRESS。