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

当前开发版本：**0.3.0**

当前主要目标环境：

- Windows x64；
- Godot **4.7.2 Standard x64**；
- GDScript 项目；
- 可配合 Compatibility Renderer 使用，渲染器不影响 MCP 连接方式。

### 真实连接已验证

2026-09-09 已经完成真实用户链路验证：

```text
Godot 4.7.2
  -> 插件内置官方 OpenAI tunnel-client
  -> OpenAI Secure MCP Tunnel
  -> ChatGPT 创建连接器
  -> 成功
```

在真实连接器成功之前，生产链路也已经通过真实 Godot GUI 自动 smoke test，覆盖工具发现、场景/节点/脚本修改、保存回读和 session termination。

## ChatGPT 现在能做什么

当前插件暴露 **13 个工具**：

| 类别 | 工具 | 用途 |
| --- | --- | --- |
| Godot | `godot.get_status` | 获取 Godot、编辑器和项目状态 |
| Project | `project.get_info` | 获取基础项目信息 |
| Scene | `scene.create` | 创建 `.tscn` 场景 |
| Scene | `scene.get_tree` | 查看当前编辑场景树 |
| Scene | `scene.save` | 保存当前场景 |
| Node | `node.create` | 向当前场景添加节点 |
| Node | `node.set_property` | 修改节点属性 |
| Node | `node.delete` | 删除非根节点 |
| Script | `script.write` | 写入项目 GDScript 文件 |
| Script | `script.read` | 读取项目脚本 |
| Script | `script.attach` | 给节点挂载 GDScript |
| Editor | `editor.run_project` | 运行 Godot 项目 |
| Editor | `editor.stop` | 停止运行中的项目 |

参数和示例见：[工具参考](docs/TOOL_REFERENCE.zh-CN.md)。

## 5 分钟快速上手

### 1. 安装插件

把这个目录放进你的 Godot 项目：

```text
addons/godot_mcp_chatgpt/
```

然后打开：

```text
项目 -> 项目设置 -> 插件
```

启用 **Godot MCP ChatGPT**。

Godot 底部会出现 **MCP ChatGPT** 面板。

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

在 0.3.0 中，这表示官方 `tunnel-client` 子进程已经启动并保持运行。最终是否连接成功，应以 ChatGPT 能否发现工具为准。

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
- Godot `EditorSettings` 只持久化 Tunnel ID；
- Runtime API Key 不写入生成的 profile；
- profile 使用 `env:CONTROL_PLANE_API_KEY`；
- 子进程启动后，key 会从 Godot 父进程环境变量中清除；
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

近期优先级：

- 更丰富的节点/属性读取；
- 打开/关闭场景；
- Resource 创建与编辑；
- ProjectSettings 和 InputMap；
- Signal 编辑；
- ClassDB 查询；
- 编辑器/运行时错误读取；
- Playtest 诊断；
- 批量节点/属性操作；
- 干净的插件 ZIP 发布包；
- 更多 Godot 4.x 版本和操作系统兼容测试。

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