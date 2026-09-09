# godot-mcp-chatgpt

**让 Web ChatGPT 通过 OpenAI Secure MCP Tunnel 直接控制 Godot 编辑器。**

[English](README.md) | 简体中文

`godot-mcp-chatgpt` 是一个面向真实 Godot 项目的编辑器插件。它不是只在聊天里给你代码建议，而是把一组高频 Godot 编辑器能力通过 MCP 暴露给 ChatGPT，让 ChatGPT 可以真正读取和修改你当前打开的 Godot 项目。

普通用户的使用流程刻意做得很简单：

```text
安装插件 -> 启用插件 -> 填 Tunnel ID + Runtime API Key -> Connect -> 在 ChatGPT 中使用 Godot 工具
```

当前 Windows 版本运行时**不需要 CWapi、Codex、Node.js、本地 MCP 客户端、自建公网 Relay 或手动配置端口**。

## 为什么做这个项目

很多 AI + Godot 工作流仍然需要你不断在 ChatGPT、代码文件、场景树和编辑器之间复制粘贴。这个项目希望把循环缩短成：

```text
你在 ChatGPT 里描述需求
        ↓
ChatGPT 调用 Godot MCP 工具
        ↓
Godot 编辑器直接修改真实项目
        ↓
你马上检查或运行结果
```

它适合用来：

- 快速做玩法原型；
- 创建和修改场景、节点；
- 编写并挂载 GDScript；
- 修改节点属性；
- 查看当前场景树；
- 启动和停止游戏；
- 不依赖桌面 AI 客户端，让 Web ChatGPT 直接操作 Godot 编辑器。

## 当前状态

当前开发版本：**0.4.0**

当前主要目标环境：

- Windows x64；
- Godot **4.7.2 Standard x64**；
- GDScript 项目；
- 可配合 Compatibility Renderer 使用，渲染器不影响 MCP 连接方式。

### 真实连接已验证

2026-09-10，0.4.0 已通过真实 ChatGPT Connector 的完整用户链路回归：

```text
Godot 4.7.2
  -> 插件内置官方 OpenAI tunnel-client
  -> OpenAI Secure MCP Tunnel
  -> 真实 ChatGPT Connector
  -> 发现 119 个 Godot MCP tools
  -> 编辑器 + Runtime + Diagnostics + Batch 真实调用
  -> REAL_CHATGPT_GODOT_MCP_0_4_TEST=PASS
```

测试真实创建并重开场景、编辑节点/脚本/Resource、查询 Godot 4.7.2 ClassDB、修改运行时节点并确认不会误写回编辑器场景、捕获进程错误/退出码、执行有边界 Batch，并验证路径与删除安全边界。
## ChatGPT 现在能做什么

0.4.0 当前暴露 **119 个工具**，覆盖完整 Godot 开发闭环：

| 类别 | 工具数 | 覆盖范围 |
| --- | ---: | --- |
| Godot | 1 | 连接、编辑器和版本状态 |
| Project | 13 | 项目总览、文件、搜索、设置、Autoload、插件 |
| InputMap | 6 | Action 与输入事件 |
| Scene | 12 | 创建、打开、重载、检查、保存、实例化、关闭 |
| Node | 23 | 属性、方法、Group、Metadata、Signal、层级编辑 |
| Script | 10 | 读写、检查、验证、挂载/卸载、编辑器状态 |
| Resource | 8 | 创建、检查、编辑、保存、复制、依赖、方法调用 |
| ClassDB | 9 | 当前 Godot 版本 API 自省 |
| Editor | 20 | Selection、FileSystem、Script Editor、保存与运行控制 |
| Debugger | 4 | Session、断点、Profiler 控制 |
| Runtime | 11 | 运行中 SceneTree、属性/方法、性能、暂停/恢复 |
| Diagnostics | 1 | 有边界启动 Godot 子进程并捕获 stdout/stderr/exit/timeout |
| Batch | 1 | 有上限、顺序执行的多工具调用 |

现在已经能形成真正开发所需要的循环：

```text
读取项目 -> 理解 API -> 修改 -> 保存 -> 运行 -> 读取 Runtime/错误 -> 修复 -> 再运行
```

完整 119-tool 索引和关键参数约定见：[工具参考](docs/TOOL_REFERENCE.zh-CN.md)。
## 5 分钟快速上手

### 1. 安装插件

**Windows x64 推荐方式：**从 [GitHub Releases](https://github.com/AAAYNMMM/godot-mcp-chatgpt/releases) 下载 `godot-mcp-chatgpt-v0.4.0-windows-x64-installer.exe`，运行后选择目标 Godot 项目的 `project.godot`。安装器会：

- 只安装到 `<所选项目>/addons/godot_mcp_chatgpt/`；
- 默认自动启用 EditorPlugin；
- 已安装旧版本时直接升级；
- 不包含任何写死的用户路径或项目路径。

当前安装器还没有代码签名，因此 Windows SmartScreen 可能提示“未知发布者”。如需校验下载文件，请使用同一个 Release 中的 `SHA256SUMS.txt`。

**手动方式：**下载 addon ZIP 并解压，最终确认存在：

```text
<你的项目>/addons/godot_mcp_chatgpt/plugin.cfg
```

手动安装后打开：

```text
项目 -> 项目设置 -> 插件
```

并启用 **Godot MCP ChatGPT**。

项目/插件加载完成后，Godot 底部会出现 **MCP ChatGPT** 面板。

### 2. 准备 OpenAI Tunnel

你只需要两项：

```text
Tunnel ID
Runtime API Key
```

建议使用专门的受限 Runtime API Key，只给当前工作区所需的 Tunnel 权限。不要把 key 发到 GitHub Issue、截图或聊天消息里。

详细步骤见：[快速上手](docs/QUICKSTART.zh-CN.md)。

### 3. 在 Godot 里连接

在底部 **MCP ChatGPT** 面板中填入 Tunnel ID 和 Runtime API Key，然后点 **Connect**。

预期状态：

```text
Status: connected
```

在 0.4.0 中，`connected` 表示官方 `tunnel-client` 子进程正在运行。最终连接是否成立，以 ChatGPT 能否发现并调用工具为准。首次成功连接后，Runtime API Key 会安全保存到 Windows Credential Manager，后续重启 Godot 可自动重连。

### 4. 在 ChatGPT 创建连接器

在 ChatGPT 中创建连接器，选择 **Connection: Tunnel**，并选择或填写同一个 Tunnel ID。

使用期间保持 Godot 编辑器打开。

### 5. 先做一个安全的只读测试

可以先让 ChatGPT 调：

```text
调用 godot.get_status，告诉我当前 Godot 版本和项目名称。
```

然后再测试一个一次性场景：

```text
创建 res://mcp_test/main.tscn，根节点是 Node3D，名字 MCPTest；
添加一个名为 RemoteNode 的 Node3D 子节点，位置设为 (1, 2, 3)，然后保存场景。
```

## 它是怎么工作的

生产运行方式采用了已经在 CWapi 中验证可用的连接模式，但**运行本插件并不需要 CWapi**：

```text
Web ChatGPT
      |
      | MCP over OpenAI Secure MCP Tunnel
      v
OpenAI tunnel service
      |
      v
官方 OpenAI tunnel-client.exe
      |
      | 127.0.0.1 上的 Streamable HTTP MCP
      v
Godot MCP ChatGPT 插件
      |
      | 编辑器进程内命令调用
      v
Godot Editor API
```

关键设计是：**本项目不自己重写 OpenAI Tunnel wire protocol**。Tunnel 兼容性由官方 OpenAI `tunnel-client` 负责；插件只负责本机 Godot MCP Server 和 Godot 工具层。

详细说明见：[架构](docs/ARCHITECTURE.zh-CN.md)。

## 安全设计

插件尽量把边界收窄：

- 本地 MCP Server 只监听 `127.0.0.1`；
- 每次启动使用随机高位端口和随机 URL 路径；
- Tunnel ID 持久化在 Godot `EditorSettings`；
- Windows 下 Runtime API Key 作为 Generic Credential 保存到 Windows Credential Manager，不进入项目文件或 Git；
- 生成的 tunnel profile 不包含明文 Key，只引用 `env:CONTROL_PLANE_API_KEY`；
- 子进程启动后，Key 会从 Godot 父进程环境变量中清除；
- **Forget Saved Credentials** 会删除保存的 Tunnel ID 和 Credential Manager 条目；
- 当前文件工具只能操作 `res://`，并拒绝 `..` 路径穿越；
- `scene.create` 默认拒绝覆盖已有场景，必须显式传 `overwrite: true`；
- 不提供通用 Shell 执行 MCP 工具。

建议使用专门的受限 Runtime API Key，而不是 Admin Key。

更多见：[安全说明](SECURITY.zh-CN.md)。

## 这个项目不是什么

它不是：

- 通用远程桌面控制器；
- Git 或版本控制替代品；
- 通用 Shell Agent；
- Godot 编辑器 UI 的替代品；
- “已经覆盖所有 Godot API”的项目。

当前目标是先把少量高频工具做稳定，再根据真实工作流扩展，而不是单纯堆工具数量。

## 路线图

近期重点已经转向兼容性和分发加固：

- 如果未来具备代码签名条件，提供更友好的 Windows 签名分发；
- 更多 Godot 4.x 版本和操作系统兼容测试；
- 在 Godot 提供稳定 Editor API 的前提下继续深化 Debugger / Profiler；
- 如后续采用对应官方 Tunnel runtime，再考虑 macOS / Linux 打包；
- 持续根据真实 ChatGPT Connector 回归加固行为和安全边界。

详细见：[开发计划](docs/DEVELOPMENT_PLAN.zh-CN.md)。

## 文档

| 文档 | English | 简体中文 |
| --- | --- | --- |
| 快速上手 | [QUICKSTART.md](docs/QUICKSTART.md) | [QUICKSTART.zh-CN.md](docs/QUICKSTART.zh-CN.md) |
| 工具参考 | [TOOL_REFERENCE.md](docs/TOOL_REFERENCE.md) | [TOOL_REFERENCE.zh-CN.md](docs/TOOL_REFERENCE.zh-CN.md) |
| 常用示例 | [EXAMPLES.md](docs/EXAMPLES.md) | [EXAMPLES.zh-CN.md](docs/EXAMPLES.zh-CN.md) |
| FAQ / 排错 | [FAQ.md](docs/FAQ.md) | [FAQ.zh-CN.md](docs/FAQ.zh-CN.md) |
| 架构 | [ARCHITECTURE.md](docs/ARCHITECTURE.md) | [ARCHITECTURE.zh-CN.md](docs/ARCHITECTURE.zh-CN.md) |
| Secure Tunnel | [SECURE_TUNNEL.md](docs/SECURE_TUNNEL.md) | [SECURE_TUNNEL.zh-CN.md](docs/SECURE_TUNNEL.zh-CN.md) |
| 开发计划 | [DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md) | [DEVELOPMENT_PLAN.zh-CN.md](docs/DEVELOPMENT_PLAN.zh-CN.md) |
| 开发交接 | [PROGRESS.md](docs/PROGRESS.md) | [PROGRESS.zh-CN.md](docs/PROGRESS.zh-CN.md) |
| 贡献指南 | [CONTRIBUTING.md](CONTRIBUTING.md) | [CONTRIBUTING.zh-CN.md](CONTRIBUTING.zh-CN.md) |
| 更新日志 | [CHANGELOG.md](CHANGELOG.md) | [CHANGELOG.zh-CN.md](CHANGELOG.zh-CN.md) |
| 安全 | [SECURITY.md](SECURITY.md) | [SECURITY.zh-CN.md](SECURITY.zh-CN.md) |

## 内置第三方运行时

当前 Windows 插件包含官方 OpenAI `tunnel-client`：

```text
addons/godot_mcp_chatgpt/bin/windows/tunnel-client.exe
```

0.3.0 验证时使用的运行时版本：

```text
0.0.10+105e17a79a36e4e5c897fd698ed2b8dbf935b144
```

SHA-256：

```text
D893D8127EEE35070D265C1BE29BFE008F8D9FCB476E7FEBF56C8FDC6C0615C8
```

对应 Apache-2.0 LICENSE 和 NOTICE 已放在插件 runtime 目录旁。详细见：[第三方说明](THIRD_PARTY_NOTICES.md)。

## 参与贡献

欢迎提交 Issue、可复现 bug、兼容性测试结果、工具建议和范围清晰的 PR。最有价值的贡献通常来自一个真实 Godot 工作流，而不是为了增加工具数量而增加工具。

准备做较大改动前，请先读：[CONTRIBUTING.zh-CN.md](CONTRIBUTING.zh-CN.md)。

## 支持项目

如果这个项目确实减少了你在 Godot + ChatGPT 之间来回复制粘贴的时间，可以给仓库一个 Star，让更多 Godot 用户更容易发现它。比 Star 更有价值的是：提交一个简短、清晰、真实的工作流 Issue，告诉我们“哪一步还不够顺”。

## License

项目源码许可证见：[LICENSE](LICENSE)。

内置第三方组件保留各自许可证，见 `addons/godot_mcp_chatgpt/bin/` 和 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。