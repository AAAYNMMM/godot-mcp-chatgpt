# 更新日志

[English](CHANGELOG.md) | 简体中文

项目仍处于早期阶段。这里记录对用户真正有意义的版本节点，而不是每一次内部实验。

## 0.3.0 — 官方 tunnel-client 架构

日期：2026-09-09

### 主要变化

- 生产 Transport 切换为**官方 OpenAI `tunnel-client`**。
- Godot 内新增 loopback **Streamable HTTP MCP** Server。
- 插件内置已经验证的 Windows `tunnel-client.exe`，并附 LICENSE/NOTICE。
- 用户使用流程仍然只有 **Tunnel ID + Runtime API Key**。
- Runtime API Key 继续保持不持久化。
- 增加官方客户端路径所需的 `server/discover` 和新旧 MCP 兼容行为。
- 增加 HTTP `DELETE` session termination。
- 保留初始 13 个高频 Godot 工具。

### 验证

已经通过：

```text
Godot 4.7.2 脚本编译
Go MCP SDK v1.7 兼容
官方 tunnel-client bridge smoke
真实 Godot 4.7.2 GUI production smoke
真实 OpenAI Tunnel + ChatGPT 连接器创建
```

真实 ChatGPT 连接器于 2026-09-09 创建成功。

### 架构变化

生产代码删除旧的 GDScript OpenAI `/poll` + `/response` 直连实现。

现在生产链路：

```text
ChatGPT
 -> OpenAI Secure MCP Tunnel
 -> 官方 OpenAI tunnel-client
 -> Godot loopback Streamable HTTP MCP
 -> Godot Editor API
```

## 0.2.3 — 连接器兼容性排查

- 给旧直连 Tunnel 实现增加 `server/discover`。
- 确认“本地协议 simulator 能通过”不足以证明真实 ChatGPT 连接器兼容。
- 这一版本帮助定位到：应该对照一个 known-good 官方 Tunnel runtime。

## 0.2.2 — 编辑器面板可用性

- 连接 UI 移到 Godot 底部明显可见的 **MCP ChatGPT** 面板。
- 改善第一次使用体验。

## 0.2.1 — 凭据持久化加固

- 不再把 Runtime API Key 写入 Godot EditorSettings。
- Tunnel ID 继续持久化，方便使用。

## 0.2.0 及更早 — Transport 原型

- 建立初始 Godot EditorPlugin 和 CommandRegistry。
- 加入第一批 scene/node/script/editor 工具。
- 探索过自建 Relay 和 GDScript 直连 Secure Tunnel。
- 这些 Transport 实验都已经被 0.3.0 官方 runtime 架构取代。