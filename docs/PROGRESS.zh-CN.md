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
## 0.4.0 完全体开发 — 当前工作区

状态更新时间：2026-09-09。

当前追踪：[`DEVELOPMENT_0.4.zh-CN.md`](DEVELOPMENT_0.4.zh-CN.md)

开发流程：[`DEVELOPMENT_WORKFLOW.zh-CN.md`](DEVELOPMENT_WORKFLOW.zh-CN.md)

公开已验证基线仍然是 **0.3.0**。以下 0.4.0 能力存在于持久工作区，**尚未**升级到公开 Tool Reference，也没有作为已验证 release 基线推送。

### Task：Windows Credential Manager 持久化

状态：**targeted validation passed；集成/重启验证待完成**。

文件 / 模块：

```text
tools/credential-helper/
addons/godot_mcp_chatgpt/bin/windows/godot-mcp-credential.exe
addons/godot_mcp_chatgpt/web/credential_store.gd
addons/godot_mcp_chatgpt/web/tunnel_client_runner.gd
addons/godot_mcp_chatgpt/ui/connection_dock.gd
```

完成内容：

- 只读检查 CWapi，确认 Runtime API Key 使用 Windows Credential Manager Generic Credential；
- 使用相同 Windows 存储机制，但采用独立 `godot-mcp-chatgpt/...` Credential Target；
- tunnel profile 继续只写 `api_key: env:CONTROL_PLANE_API_KEY`；
- 增加保存凭据存在/读/写/删除和 Forget Saved Credentials；
- 准备通过保存的 Tunnel ID + Credential Manager API Key 自动重连。

实际验证：

- helper 隔离 `write -> present -> read -> delete -> present` round trip；
- 读取值和测试 secret 一致；
- 测试 Credential 验证后已删除；
- Godot 4.7.2 成功加载 `credential_store.gd` 和修改后的凭据相关插件脚本。

结果：凭据存储专项验证通过。

已知限制 / blocker：尚未执行“关闭 Godot -> 重启 -> 自动连接”和“Forget -> 重启 -> 要求重新输入”的生产 smoke。

### Task：Project / ProjectSettings / InputMap 能力模块

状态：**targeted validation passed**。

文件 / 模块：

```text
addons/godot_mcp_chatgpt/core/command_utils.gd
addons/godot_mcp_chatgpt/commands/project_commands.gd
```

完成内容：项目总览/发现/搜索、ProjectSettings、Autoload/Plugin 发现、项目范围文件操作和 InputMap 操作。

实际验证：Godot 4.7.2 加载公共 command utility 和 Project 命令模块，无 parse/compile error。

结果：模块编译通过。仍待生产 registry 集成。

### Task：Scene / Node 能力模块

状态：**targeted validation passed**。

文件 / 模块：

```text
addons/godot_mcp_chatgpt/commands/scene_node_commands.gd
```

完成内容：Scene 生命周期/聚合读取，以及更完整的 Node inspect/mutation、Group、Signal、Metadata 操作。

实际验证：修正 Godot 4.7 严格类型/作用域问题后，Godot 4.7.2 成功加载最终模块，无 parse/compile error。

结果：模块编译通过。仍待生产 registry 集成和 GUI 行为 smoke。

### Task：Script / Resource 能力模块

状态：**targeted validation passed**。

文件 / 模块：

```text
addons/godot_mcp_chatgpt/commands/script_resource_commands.gd
```

完成内容：Script 自省/验证/编辑器状态辅助，以及 Resource inspect/get/set/create/save/duplicate/dependencies/call。

实际验证：Godot 4.7.2 成功加载重写后的模块，无 parse/compile error。

结果：模块编译通过。仍需代表性真实 Resource 修改集成 smoke。

### Task：ClassDB 自省模块

状态：**targeted validation passed**。

文件 / 模块：

```text
addons/godot_mcp_chatgpt/commands/classdb_commands.gd
```

完成内容：当前 Godot 引擎 ClassDB search/inspect/properties/methods/signals/enums/constants/inheritance/can-instantiate。

实际验证：修正保留标识符问题后，Godot 4.7.2 成功加载模块，无 parse/compile error。

结果：模块编译通过。

### Task：开发文档体系完善

状态：**complete**。

文件 / 模块：

```text
docs/DEVELOPMENT_WORKFLOW.md
docs/DEVELOPMENT_WORKFLOW.zh-CN.md
docs/DEVELOPMENT_0.4.md
docs/DEVELOPMENT_0.4.zh-CN.md
docs/DEVELOPMENT_PLAN.md
docs/DEVELOPMENT_PLAN.zh-CN.md
docs/PROGRESS.md
docs/PROGRESS.zh-CN.md
CONTRIBUTING.md
CONTRIBUTING.zh-CN.md
```

完成内容：

- 明确 README、Tool Reference、Changelog、Development Plan、版本追踪和 Progress 各自的事实边界；
- 将进度文档写入 Definition of Done；
- 强制每完成一个逻辑独立任务后，先更新 Progress + 当前版本 tracker，再进入下一项；
- 统一开发状态词和验证证据要求；
- 新增 0.4.0 完全体 checklist 和 release gates；
- 真实登记当前未提交 0.4.0 工作区状态，不提前污染公开 0.3.0 Tool Reference。

实际验证：`PAIR_CHECK=PASS`、`LINK_CHECK=PASS`、`LITERAL_NEWLINE_CHECK=PASS`、`DOC_BOM_CHECK=PASS`、`DOC_DIFF_CHECK=PASS`。

结果：开发进度管理已经形成强制逐任务更新规则。

## 0.4.0 当前 blocker

没有已知架构 blocker。主要剩余开发是 Editor 状态/控制、捕获诊断、Debugger/Runtime Bridge 和 Batch。新增模块尚未注册进生产 command registry。

已登记一个 WIP 仓库卫生问题：`plugin.cfg` 在中间编辑时意外带入 UTF-8 BOM。它尚未推送，完整插件/release gate 前必须清理。

## 0.4.0 精确下一项任务

**实现 Editor 状态/控制模块，并执行 Godot 4.7.2 专项编译/行为验证。该任务通过后必须立即更新本 Progress 和 0.4.0 tracker，然后才能开始 Runtime/Debugger 工作。**