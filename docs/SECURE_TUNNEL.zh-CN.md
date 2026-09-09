# OpenAI Secure MCP Tunnel 设置

[English](SECURE_TUNNEL.md) | 简体中文

0.3.0 使用插件内置的官方 OpenAI `tunnel-client.exe`，并由 Godot 自己提供 loopback Streamable HTTP MCP Server。

**2026-09-09 已完成真实生产连接器验证并创建成功。**

## 生产链路

```text
ChatGPT
 -> OpenAI Secure MCP Tunnel
 -> 插件内置官方 tunnel-client.exe
 -> Godot loopback Streamable HTTP MCP
 -> Godot 编辑器工具
```

运行时不依赖 CWapi。

## 用户需要什么

只有：

```text
Tunnel ID
Runtime API Key
```

不要把 Runtime API Key 贴到聊天、Git、截图或公开 Issue。

## 1. 启用插件

Godot 中打开：

```text
项目 -> 项目设置 -> 插件
```

启用 **Godot MCP ChatGPT**。

然后打开底部：

```text
MCP ChatGPT
```

## 2. 填 Tunnel 凭据

Tunnel ID 必须和之后在 ChatGPT 连接器里使用的完全一致。

Runtime API Key 建议使用专门的受限 key，只授予工作区实际需要的 Tunnel 权限。

点击 **Connect**。

预期状态：

```text
starting
connected
```

0.3.0 中，`connected` 表示 Godot 本地 MCP Server 已运行，官方 tunnel-client 子进程也保持存活。最终是否真正接通，应以 ChatGPT 能否发现工具为准。

Runtime API Key 不会被插件持久化。

## 3. 在 ChatGPT 创建连接器

在 ChatGPT 连接器设置中：

1. 创建连接器；
2. 选择 **Connection: Tunnel**；
3. 选择或填写同一个 Tunnel ID；
4. 创建和使用期间保持 Godot 打开。

0.3.0 的真实验证已经成功走通这条连接器创建流程。

## 4. 验证工具发现

当前版本应发现 13 个工具。

先测试：

```text
godot.get_status
```

正常结果应包含：

```text
godot_version: 4.7.2...
editor: true
project_name: ...
```

再测试：

```text
project.get_info
```

## 5. 验证可见写入

使用一次性路径：

```text
scene.create
  path: res://mcp_real_test/main.tscn
  root_type: Node3D
  root_name: MCPRealTest

node.create
  parent_path: .
  type: Node3D
  name: RemoteNode

node.set_property
  node_path: RemoteNode
  property: position
  value: {"__godot_type":"Vector3","x":1,"y":2,"z":3}

scene.save
```

然后直接在 Godot 里确认场景和节点出现。

## 点 Connect 后插件自动做什么

插件会：

1. 在 `127.0.0.1` 启动私有 MCP Server；
2. 随机选择高位端口；
3. 生成随机 MCP URL 路径；
4. 生成 tunnel-client profile；
5. profile 只写 `api_key: env:CONTROL_PLANE_API_KEY`；
6. 启动内置官方 tunnel-client；
7. 子进程启动后，从 Godot 父进程环境变量移除 key；
8. Disconnect 时停止相关进程并清理本地 MCP。

## Profile 结构

大致形态：

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

明文 Runtime API Key 不应该出现在 profile 中。

## 本地失败状态

面板可能出现：

```text
credentials_required
runtime_missing
registry_unavailable
local_mcp_error
profile_error
runtime_error
```

如果面板已经 `connected`，但 ChatGPT 发现不到工具，请看 [FAQ / 排错](FAQ.zh-CN.md)。

## 报 bug 时提供什么

不要发送 Runtime API Key。

有价值的信息：

- Godot 版本；
- 插件版本/commit；
- 面板状态；
- 最后一条不含秘密的面板日志；
- ChatGPT 连接器是否创建成功；
- 发现工具数量；
- 完整但不含秘密的报错；
- Godot Output 中以 `[GodotMCPChatGPT]` 开头且不含秘密的日志。

## 安全检查

正常配置应满足：

- 本地 MCP 地址是 `127.0.0.1`；
- 本地端口/路径每次运行生成；
- profile 中是 `env:CONTROL_PLANE_API_KEY`，不是明文 key；
- 插件只持久化 Tunnel ID；
- 重启 Godot 后 Runtime API Key 需要重新输入。