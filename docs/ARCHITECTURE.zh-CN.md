# 架构

[English](ARCHITECTURE.md) | 简体中文

## 已锁定的生产架构

从 `0.3.0` 起，生产链路固定为：

```text
ChatGPT / 支持 OpenAI MCP 的产品
              |
              | OpenAI Secure MCP Tunnel
              v
      OpenAI tunnel service
              |
              v
 官方 OpenAI tunnel-client
      （插件内置子进程）
              |
              | Streamable HTTP MCP
              | 127.0.0.1:<随机端口>/<随机路径>
              v
   local_mcp_server.gd
              |
              v
      CommandRegistry
              |
              v
        Godot Editor
```

关键决定：**Godot 不自己实现 OpenAI Tunnel wire protocol。** Tunnel 兼容性由官方 OpenAI `tunnel-client` 负责。

关键设计是：**Godot 不实现 OpenAI Tunnel wire protocol**。Tunnel Transport 由官方 OpenAI `tunnel-client` 负责，本插件专注本地 MCP Server 和 Godot 集成。

## 为什么最终选择这个架构

早期版本曾经用 GDScript 自己实现 control-plane `/poll` 和 `/response`。本地协议仿真可以通过，Godot 也能显示 connected，但真实 ChatGPT 创建连接器仍然失败。

早期曾验证过自定义直连 Tunnel 实现，但真实 ChatGPT Connector 路径不满足生产要求。因此生产架构改为：

```text
官方 tunnel-client
 -> localhost Streamable HTTP MCP
```

0.3.0 因此切换到同一设计思想。

好处：

- 不运营自建公网 Relay；
- 不复制 OpenAI Tunnel 兼容逻辑；
- 用户仍然只需要 Tunnel ID + Runtime API Key；
- Tunnel 行为跟随官方 runtime；
- Godot 工具执行仍然在编辑器进程内完成；
- loopback MCP 不对外网开放。

2026-09-09 真实 ChatGPT 连接器创建成功，进一步验证了这套架构。

## 官方 tunnel-client 子进程

`tunnel_client_runner.gd` 负责：

1. 校验 Tunnel ID 和 Runtime API Key；
2. 启动 loopback MCP Server；
3. 生成包含 Tunnel ID 和本地 MCP URL 的 profile；
4. profile 只写 `api_key: env:CONTROL_PLANE_API_KEY`；
5. 临时把 key 放入 Godot 进程环境；
6. 执行内置 `tunnel-client.exe run --profile-file ...`；
7. 子进程创建后立即从 Godot 父进程环境移除 key；
8. 监控子进程，Disconnect/退出时清理本地 MCP。

Profile 概念结构：

```yaml
config_version: 1
control_plane:
  tunnel_id: <tunnel id>
  api_key: env:CONTROL_PLANE_API_KEY
health:
  listen_addr: 127.0.0.1:0
admin_ui:
  open_browser: false
mcp:
  server_urls:
    - channel: main
      url: http://127.0.0.1:<random>/mcp/<random>
```

## Godot 本地 Streamable HTTP MCP

`local_mcp_server.gd` 使用 Godot `TCPServer` / `StreamPeerTCP` 实现一个很小的 loopback-only MCP Server。

特性：

- 仅绑定 `127.0.0.1`；
- 每次随机高位端口；
- 每次随机路径 token；
- 限制请求 body 大小；
- 编辑器修改请求串行执行，避免 mutation race；
- 支持 Streamable HTTP 客户端需要的 JSON/SSE 响应；
- 支持通知 ACK 和 session termination。

当前处理：

- `server/discover`
- `initialize`
- `ping`
- `tools/list`
- `tools/call`
- 无 ID 生命周期通知
- HTTP `DELETE` session termination

## Godot 工具边界

0.4.0 当前暴露 **119 个工具**，围绕真实 Godot 工作流组织，而不是提供通用 Shell：

```text
Project / InputMap
Scene / Node / Signal / Group / Metadata
Script / Resource
ClassDB
Editor
Debugger / Runtime
Diagnostics
Batch
```

项目 File / Resource 操作仍限制在 `res://`。编辑器 mutation 通过 Godot command layer 串行处理。精确参数以实时 `tools/list` schema 为准，完整索引见：[工具参考](TOOL_REFERENCE.zh-CN.md)。

## Runtime Debugger 路径

Runtime 读取和控制不会再开启另一个公网网络服务，而是使用 Godot 自己的 Debugger 通道：

```text
MCP runtime.* / debugger.* tool
 -> RuntimeDebuggerManager
 -> EditorDebuggerPlugin / EditorDebuggerSession
 -> Godot remote-debug channel
 -> EngineDebugger
 -> GodotMCPChatGPTRuntime autoload
 -> 运行中 SceneTree
```

Runtime Bridge 可以读取/修改运行中节点、调用方法、读取部分 Performance monitor，并 pause/resume SceneTree。Runtime 修改不会自动写回保存的编辑器 Scene。

插件被禁用时会清理保留的 autoload，并兼容 `res://` 和 Godot 4.7.2 `uid://` 引用。
## 内置运行时

当前 Windows runtime：

```text
OpenAI tunnel-client
version: 0.0.10+105e17a79a36e4e5c897fd698ed2b8dbf935b144
SHA-256: D893D8127EEE35070D265C1BE29BFE008F8D9FCB476E7FEBF56C8FDC6C0615C8
```

Apache-2.0 LICENSE 和 NOTICE 位于 `addons/godot_mcp_chatgpt/bin/`。

## 开发测试桩

`server/` 只用于开发，模拟足够的 OpenAI control plane 行为，让**官方** tunnel-client 能在本地完成端到端测试。

最有价值的 smoke 路径：

```text
control-plane stub
 -> 内置官方 tunnel-client.exe
 -> Godot loopback MCP
 -> 真实 Godot 4.7.2 GUI
 -> 119 个真实工具
```

0.4.0 已通过 119-tool catalogue/schema 和代表性真实行为门禁；2026-09-10 又通过真实 ChatGPT Connector 全能力回归，结果 `REAL_CHATGPT_GODOT_MCP_0_4_TEST=PASS`。

## 明确不做

- 自建公网 Relay；
- 再用 GDScript 直接实现 OpenAI `/poll` / `/response`；
- 普通用户走 stdio MCP；
- localhost WebSocket bridge；
- 通用 Shell/桌面自动化；
- 任意 OS 命令暴露；
- 取代 Git 或完整 coding agent。