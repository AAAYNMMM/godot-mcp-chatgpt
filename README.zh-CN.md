# godot-mcp-chatgpt

**让 Web ChatGPT 通过 OpenAI Secure MCP Tunnel 直接控制真实 Godot 项目。**

[English](README.md) | 简体中文

`godot-mcp-chatgpt` 是一个项目级 Godot EditorPlugin。它给 Web ChatGPT 提供直接操作当前 Godot 项目的 MCP 工具，让 ChatGPT 不只是“在聊天里给代码”，而是能真正读取、修改、运行、诊断和调试你正在开发的项目。

```text
Web ChatGPT
    ↓
OpenAI Secure MCP Tunnel
    ↓
官方 OpenAI tunnel-client
    ↓
Godot 内置本地 MCP Server
    ↓
Godot Editor + Runtime Debugger
```

当前 Windows 版本正常使用时，不需要 Claude Desktop、Cursor、Codex CLI、本地 MCP 客户端、自建公网 Relay、Node.js 运行时或手动配置端口。

## 核心能力

- **119 个 Godot MCP 工具**，覆盖 Project、InputMap、Scene、Node、Script、Resource、ClassDB、Editor、Debugger、Runtime、Diagnostics、Batch。
- **直接修改真实编辑器项目**：创建场景、写脚本、改节点/Resource、保存、运行、检查、修复、再运行。
- **Runtime Debugger**：读取运行中 SceneTree、读写 Runtime 属性、调用方法、查看性能、暂停和恢复。
- **实时 ClassDB 查询**：直接读取当前 Godot 版本 API，而不是只依赖模型记忆。
- **运行诊断**：捕获 stdout、stderr、exit code、timeout、duration。
- **Windows Credential Manager**：保存 Runtime API Key、支持重启自动连接和 Forget。
- **Windows x64 单文件一键安装器**，同时提供可手动解压的 addon ZIP。
- 已通过 **真实 Web ChatGPT + Godot 4.7.2** 全能力回归。

## 最新版本

**v0.4.0** — Windows x64，已验证 **Godot 4.7.2 Standard x64**。

[下载最新 Release](https://github.com/AAAYNMMM/godot-mcp-chatgpt/releases/latest)

| 项目 | 状态 |
| --- | --- |
| Windows x64 | 已验证 |
| Godot 4.7.2 | 已验证 |
| GDScript 项目 | 已验证 |
| Web ChatGPT Connector | 已验证 |
| macOS / Linux 安装包 | 当前未提供 |
| 已签名 Windows 安装器 | 当前未提供 |

当前安装器没有代码签名，因此 Windows SmartScreen 可能提示“未知发布者”。Release 内包含 `SHA256SUMS.txt`，可用于完整性校验。

## 快速安装

### 1. 安装到 Godot 项目

Windows x64 推荐方式：

1. 从 Releases 下载 `godot-mcp-chatgpt-v0.4.0-windows-x64-installer.exe`。
2. 运行安装器。
3. 选择目标项目的 `project.godot`。
4. 如果该项目已经在 Godot 中打开，安装后重新打开/重启项目。

安装器只会写入所选项目：

```text
<项目>/addons/godot_mcp_chatgpt/
<项目>/project.godot
```

默认会自动启用 EditorPlugin，也支持覆盖升级已有版本。

手动方式：下载 addon ZIP 并解压，最终确认：

```text
<项目>/addons/godot_mcp_chatgpt/plugin.cfg
```

然后在：

```text
项目 -> 项目设置 -> 插件
```

启用 **Godot MCP ChatGPT**。

### 2. 连接插件

打开 Godot 底部的 **MCP ChatGPT** 面板，填写：

```text
Tunnel ID
Runtime API Key
```

点击 **Connect**。

第一次成功连接后，Runtime API Key 会保存到 Windows Credential Manager，之后可以自动重连。需要清除时使用 **Forget Saved Credentials**，会同时移除保存的 Key 和 Tunnel ID。

### 3. 在 ChatGPT 中添加 Connector

为你的 OpenAI Secure MCP Tunnel 创建/使用 ChatGPT Connector，然后确认 ChatGPT 能发现 Godot 工具。

第一次建议先发送只读请求：

```text
检查当前 Godot 项目和当前场景，不要修改任何内容。
```

完整流程见：[快速上手](docs/QUICKSTART.zh-CN.md)。

## ChatGPT 可以控制什么

0.4.0 暴露 **119 个工具**：

| 类别 | 数量 | 主要能力 |
| --- | ---: | --- |
| Godot | 1 | 连接、编辑器、版本状态 |
| Project | 13 | 项目总览、文件、搜索、设置、Autoload、插件 |
| InputMap | 6 | Action 与输入事件 |
| Scene | 12 | 创建、打开、重载、检查、保存、实例化、关闭 |
| Node | 23 | 属性、方法、Group、Metadata、Signal、层级 |
| Script | 10 | 读写、检查、验证、挂载/卸载、编辑器状态 |
| Resource | 8 | 创建、检查、编辑、保存、复制、依赖、方法 |
| ClassDB | 9 | 当前 Godot API 自省 |
| Editor | 20 | Selection、FileSystem、Script、保存、运行控制 |
| Debugger | 4 | Session、断点、Profiler |
| Runtime | 11 | 运行中 SceneTree、属性、方法、性能、暂停/恢复 |
| Diagnostics | 1 | 有边界启动 Godot 子进程并捕获输出 |
| Batch | 1 | 有上限、顺序执行的多工具调用 |

预期开发闭环：

```text
读取项目
→ 查询真实 Godot API
→ 修改
→ 保存
→ 运行
→ 读取 Runtime / Diagnostics
→ 修复
→ 再运行
```

完整索引和参数约定见：[工具参考](docs/TOOL_REFERENCE.zh-CN.md)。

## 安全边界

这个插件本来就具备修改项目的能力，所以设计目标不是“假装没有破坏能力”，而是把危险操作限制在明确边界内。

0.4.0 的关键边界：

- 项目文件和 Resource 路径限制在 `res://`；
- 路径穿越和项目外路径会被拒绝；
- 不允许删除当前编辑场景根节点；
- 覆盖已有场景需要显式允许；
- `diagnostics.run_capture` 是受限 Godot Runner，不是任意 Shell；
- `batch.execute` 有上限且不是事务；
- Runtime 修改只影响运行中实例，不会自动写回保存的编辑器场景；
- 本地 MCP 只监听 loopback，并用于内置官方 Tunnel Client；
- Runtime API Key 使用 Windows Credential Manager，不写进项目或普通配置文件。

在给包含敏感数据或危险自动化的项目开放远程操作前，请阅读 [安全说明](SECURITY.zh-CN.md)。

## 架构

生产链路：

```text
ChatGPT
  ↓
OpenAI Secure MCP Tunnel
  ↓
官方 tunnel-client.exe
  ↓
127.0.0.1:<随机端口>/mcp/<随机路径>
  ↓
Godot Streamable HTTP MCP
  ↓
CommandRegistry
  ↓
Godot Editor API / Editor Debugger
```

本项目**不重新实现 OpenAI Tunnel wire protocol**。官方 OpenAI runtime 负责 Tunnel 兼容，本仓库负责 Godot MCP Server、Godot 工具层、一键安装器和编辑器/Runtime 集成。

详细见：[架构](docs/ARCHITECTURE.zh-CN.md) 和 [Secure Tunnel](docs/SECURE_TUNNEL.zh-CN.md)。

## 验证

v0.4.0 实际通过：

```text
Godot 4.7.2 addon load/compile
119-tool catalogue/schema gate
official tunnel-client production smoke
真实 Web ChatGPT Connector 全能力回归
Runtime autoload 持久化生命周期
Credential 保存 -> 重启自动连接 -> Forget -> 再重启
安装器干净安装 / 升级 / 非法路径 / no-enable
中文 + 空格项目路径安装
安装后 addon 全文件 SHA-256 对比
GitHub Release 资产重新下载 SHA-256 对比
```

关键标记：

```text
CATALOGUE_SCHEMA_GATE=PASS tools=119
PRODUCTION_PLUGIN_SMOKE=PASS
REAL_CHATGPT_GODOT_MCP_0_4_TEST=PASS
INSTALLER_SMOKE=PASS version=0.4.0
RELEASE_REMOTE_ASSET_VERIFY=PASS
```

当前版本状态和已知限制见：[进度](docs/PROGRESS.zh-CN.md)。

## 文档

### 用户文档

| 文档 | 用途 |
| --- | --- |
| [快速上手](docs/QUICKSTART.zh-CN.md) | 安装、连接、第一次安全调用 |
| [工具参考](docs/TOOL_REFERENCE.zh-CN.md) | 完整 119-tool 索引和约定 |
| [示例](docs/EXAMPLES.zh-CN.md) | 实际 Prompt 和开发工作流 |
| [FAQ](docs/FAQ.zh-CN.md) | 常见问题和排错 |
| [安全](SECURITY.zh-CN.md) | 信任边界和安全行为 |
| [架构](docs/ARCHITECTURE.zh-CN.md) | 生产架构与组件职责 |
| [Secure Tunnel](docs/SECURE_TUNNEL.zh-CN.md) | Tunnel/runtime 行为和排错 |

### 维护者文档

| 文档 | 用途 |
| --- | --- |
| [贡献指南](CONTRIBUTING.zh-CN.md) | 贡献规则和开发要求 |
| [开发计划](docs/DEVELOPMENT_PLAN.zh-CN.md) | 已发布里程碑和后续方向 |
| [开发工作流](docs/DEVELOPMENT_WORKFLOW.zh-CN.md) | Definition of Done 和文档规则 |
| [发布流程](docs/RELEASING.zh-CN.md) | 可复现 Release checklist |
| [当前进度](docs/PROGRESS.zh-CN.md) | 当前仓库/版本状态 |
| [0.4.0 发布记录](docs/DEVELOPMENT_0.4.zh-CN.md) | v0.4.0 已关闭技术记录 |
| [0.5.0 能力迁移计划](docs/DEVELOPMENT_0.5.zh-CN.md) | 当前能力迁移与 Compact Tool Surface 开发计划 |

英文文档可通过各中文文档顶部链接切换。

## 路线图

下一里程碑已经锁定为 **v0.5.0 Capability Migration**，有两个目标：

1. 迁移能力审计中 v0.4.0 仍缺失的 Godot-side 能力；
2. 把默认 Public MCP Surface 从 119 个扁平 Tool 压缩为 **<=50 个** Compact Domain Tools，同时保留内部 Atomic Commands。

迁移范围包括 Screenshot/Image、确定性 Input/Playtest、Native Frame Step、Live Logs、Script Patch/Write Diagnostics、GDScript Tests、UndoRedo/Rollback、高层 Animation/Material/Audio/Particle/Camera/Theme/UI、Resource Helpers、TileMap/TileSet、GridMap、CSG、Autoload Mutation 和第三方 Custom Tool Registration。

明确**不迁移** `godot://...` MCP Resources、MCP Client Auto-config、Python/FastMCP Server、Godot AI WebSocket Bridge。我们已经等价或更强的 v0.4 能力也不会重复实现。

详细见：[v0.5.0 能力迁移计划](docs/DEVELOPMENT_0.5.zh-CN.md) 和 [开发计划](docs/DEVELOPMENT_PLAN.zh-CN.md)。

## 参与贡献

欢迎 Issue 和聚焦的 Pull Request。高质量问题报告最好包含：

- Godot 版本和操作系统；
- 可复现步骤；
- 对应 MCP Tool/请求；
- 预期结果与实际结果；
- 不含秘密信息的日志；
- 问题属于 Editor、Runtime、Transport、Installer 还是文档。

详细见：[贡献指南](CONTRIBUTING.zh-CN.md)。

## License

项目源码遵循 [LICENSE](LICENSE)。

内置官方 OpenAI `tunnel-client` 保留其上游 License 和 NOTICE，详见 [第三方声明](THIRD_PARTY_NOTICES.zh-CN.md)。

## 致谢与相关项目

[Godot AI](https://github.com/hi-godot/godot-ai) 是一个成熟的 MIT Godot MCP 开源项目。v0.5 能力迁移计划会把它当前的能力面和 Compact Domain / Rollup Tool Surface 设计作为重要参考。

`godot-mcp-chatgpt` 仍然保持独立实现，专注 Web ChatGPT，并且**不依赖** Godot AI、Python/FastMCP、它的 MCP Client 配置层、`godot://` Resources 或 WebSocket Bridge。如果后续迁移过程中实质 Port / Derive Godot AI 源码，会按 MIT 要求把对应 Attribution 写入 [第三方声明](THIRD_PARTY_NOTICES.zh-CN.md)。
