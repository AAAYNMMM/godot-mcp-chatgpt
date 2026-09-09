# 开发进度 / 新窗口交接

[English](PROGRESS.md) | 简体中文

最后更新：2026-09-09

仓库：`AAAYNMMM/godot-mcp-chatgpt`

分支：`main`

当前版本候选：`0.3.0`

0.3.0 核心实现提交：

```text
2a70cd1ed084df0d2ee5fff7c596c5ff5a3e93d8
```

## 当前架构 — 新窗口必须先看

生产链路：

```text
Web ChatGPT
 -> OpenAI Secure MCP Tunnel
 -> 插件内置官方 OpenAI tunnel-client.exe
 -> Godot loopback Streamable HTTP MCP
 -> Godot CommandRegistry
 -> Godot Editor API
```

旧版 GDScript `/poll` + `/response` 直连实现已经废弃并从生产代码删除。

原因：旧实现能在本地 simulator 里通过，也能显示 connected，但真实 ChatGPT 连接器创建失败。只读检查 CWapi 后确认，CWapi 真正可用的方式是**官方 tunnel-client + localhost Streamable HTTP MCP**。0.3.0 已采用同样设计思想，而且真实 ChatGPT 连接器已经创建成功。

除非出现新的明确证据并重新做架构决策，否则不要恢复旧直连实现。

## 当前用户体验

Godot 底部面板：

```text
MCP ChatGPT
```

用户只输入：

```text
Tunnel ID
Runtime API Key
```

点 Connect 后插件自动：

1. 在 `127.0.0.1` 启动随机端口 MCP Server；
2. 生成随机 MCP 路径；
3. 生成 tunnel-client profile；
4. profile 使用 `env:CONTROL_PLANE_API_KEY`；
5. 启动内置官方 tunnel-client；
6. 子进程启动后清除 Godot 父进程环境中的 key；
7. Disconnect 时清理本地 MCP 和子进程。

插件只持久化 Tunnel ID，不持久化 Runtime API Key。

## 内置官方运行时

```text
addons/godot_mcp_chatgpt/bin/windows/tunnel-client.exe
```

版本：

```text
0.0.10+105e17a79a36e4e5c897fd698ed2b8dbf935b144
```

SHA-256：

```text
D893D8127EEE35070D265C1BE29BFE008F8D9FCB476E7FEBF56C8FDC6C0615C8
```

Apache-2.0 LICENSE 和 NOTICE 已放进 `addons/godot_mcp_chatgpt/bin/`。

## 当前 13 个 Godot 工具

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

## 关键文件

```text
addons/godot_mcp_chatgpt/plugin.gd
addons/godot_mcp_chatgpt/ui/connection_dock.gd
addons/godot_mcp_chatgpt/web/tunnel_client_runner.gd
addons/godot_mcp_chatgpt/web/local_mcp_server.gd
addons/godot_mcp_chatgpt/core/command_registry.gd
addons/godot_mcp_chatgpt/core/builtin_commands.gd
```

开发测试桩：

```text
server/
```

## 已完成的验证

### Godot 4.7.2 编译

所有插件 GDScript 在 Godot 4.7.2 下强制加载成功。

### Godot 本地 MCP

已经验证：

```text
server/discover
initialize
tools/list
tools/call
```

### Go MCP SDK 1.7

真实 `github.com/modelcontextprotocol/go-sdk v1.7.0` 客户端成功连接 Godot loopback MCP，并完成工具发现/调用。

```text
GO_SDK_SMOKE_OK
```

### 官方 tunnel-client bridge

使用与工作中的 CWapi 相同官方 tunnel-client，经过本地 control-plane stub 转发到 Godot MCP：

```text
OFFICIAL_TUNNEL_BRIDGE=PASS
```

### Production plugin smoke

真实 Godot 4.7.2 GUI + 内置官方 tunnel-client + 13 个真实工具：

```text
PRODUCTION_PLUGIN_SMOKE=PASS
```

Smoke 覆盖：

```text
server/discover
initialize
notifications/initialized
tools/list
godot.get_status
scene.create
node.create
node.set_property
script.write
script.read
script.attach
scene.save
scene.get_tree
session termination
```

测试创建一次性场景，并验证 `Player.position == Vector3(4, 5, 6)`。

## 真实 ChatGPT 连接器验证

**状态：成功 — 2026-09-09。**

用户使用真实 OpenAI Tunnel ID / Runtime API Key，在生产 0.3.0 架构下成功创建 ChatGPT 连接器。

验证链路：

```text
Godot 4.7.2
 -> 内置官方 OpenAI tunnel-client
 -> OpenAI Secure MCP Tunnel
 -> ChatGPT connector creation
 -> SUCCESS
```

这已经是当前 known-good baseline。未来出现连接问题时，优先对照这条基线排查，不要直接重写 Transport。

## 当前阻塞

连接器创建没有阻塞。

下一阶段主要是：

- 通过真实连接器继续调用 `godot.get_status` 和一次性场景写入；
- 根据真实使用体验调整工具接口；
- 扩展高价值工具；
- 做干净 Windows 发布包。

## 下一步

1. 真实 ChatGPT 连接器调用 `godot.get_status`；
2. 通过真实连接器创建一次性可见场景/节点；
3. 记录工具易用性问题；
4. Phase 6 从属性读取、scene open/close 开始；
5. 准备首个用户友好的 Windows release ZIP 和 release notes。

## 双语文档重构

真实连接器验证成功后，于 2026-09-09 完成。

用户文档已经从“开发过程记录”改成以第一次使用体验为中心，目前中英双语覆盖：

```text
README
快速上手
常用示例
工具参考
FAQ / 排错
架构
Secure Tunnel 设置
开发计划
开发进度 / 交接
贡献指南
安全说明
更新日志
```

后续文档规则：

- 面向用户的文档尽量保持英文 + 简体中文；
- 使用 `NAME.md` / `NAME.zh-CN.md` 配对；
- README 聚焦项目价值、安装连接、真实验证和清晰限制；
- 除非仓库策略明确改变，否则不添加图片、截图、徽章或 GIF；
- 真实测试和仿真测试必须明确区分，不夸大验证范围。
## 仓库/工作区规则

- 本项目只操作 `AAAYNMMM/godot-mcp-chatgpt`；
- 不修改 CWapi；之前只读检查它来确认可用 Tunnel 架构；
- Godot 当前开发目标：Windows + Godot 4.7.2 Standard + GDScript；
- 每个有实质进展的新窗口都要同步更新中英文进度文档。