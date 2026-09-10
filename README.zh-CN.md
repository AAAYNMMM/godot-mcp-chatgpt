# godot-mcp-chatgpt

**通过 OpenAI Secure MCP Tunnel，让 Web ChatGPT 直接控制真实 Godot 项目。**

[English](README.md) | 简体中文

`godot-mcp-chatgpt` 是项目级 Godot Editor 插件，为 Web ChatGPT 提供紧凑的 MCP 工具面，可以直接编辑、运行、检查、测试、观察和调试当前打开的 Godot 项目。

```text
Web ChatGPT
    ↓
OpenAI Secure MCP Tunnel
    ↓
官方 OpenAI tunnel-client
    ↓
Godot 本地 MCP Server
    ↓
Godot Editor + Runtime Debugger
```

当前 Windows 构建正常使用时不需要 Claude Desktop、Cursor、Codex CLI、本地 MCP Client、自建公网 Relay、Node.js Runtime 或手动配置端口。

## 核心能力

- **默认 47 个 Public MCP Tools**，后端保留 **230 个 Internal Atomic Commands**；长尾能力通过紧凑 `*.manage` 聚合，不再暴露数百个扁平 Schema。
- **真实 Editor 修改**：Scene / Node / Script / Resource、高层内容创作、Undo/Redo，以及仅对可回滚操作成立的 Transaction rollback。
- **视觉观察**：通过 MCP image content 返回 Editor Viewport、Camera3D/Cinematic、Running Game 截图。
- **确定性 Playtest**：InputMap 编辑，并可注入键盘、鼠标、手柄 Button/Axis 与 InputAction。
- **Runtime 检查与控制**：Live SceneTree、属性读写、方法调用、UI Discovery、性能、日志和播放状态。
- **World Authoring**：TileMap/TileSet、GridMap/MeshLibrary、CSG。
- **GDScript 工作流**：整文件写入、Anchor Patch、Validate/Diagnostics 与有边界 Test Runner。
- **高层 Content Authoring**：Animation、Material/Shader、Audio、Particle、Camera、Theme/UI、Curve/Gradient/Noise、Environment、Physics Shape。
- **第三方 Custom Tool**：Addon Owner 校验、显式安全 Hint、Schema Validation、默认禁用 Opt-in，以及最多 2 个 promoted public tools。
- 已使用 **Godot 4.7.2 Standard x64** 做真实 Web ChatGPT Connector 全量回归，包括截图真实回传并由 ChatGPT 实际查看。

## 最新版本

**v0.5.0** — Windows x64，已验证 **Godot 4.7.2 Standard x64**。

[下载最新 Release](https://github.com/AAAYNMMM/godot-mcp-chatgpt/releases/latest)

| 项目 | 状态 |
| --- | --- |
| Windows x64 | 已验证 |
| Godot 4.7.2 | 已验证 |
| GDScript 项目 | 已验证 |
| Web ChatGPT Connector | 已验证 |
| 默认 Public MCP Tools | **47** |
| Internal Atomic Commands | **230** |
| macOS / Linux 安装包 | 当前未提供 |
| Code-signed Installer | 当前未提供 |

Installer 当前没有代码签名，因此 Windows SmartScreen 可能显示未知发布者警告；Release 同时提供 `SHA256SUMS.txt` 用于完整性校验。

## 快速安装

### 1. 安装到 Godot 项目

Windows x64 推荐：

1. 从 Releases 下载 `godot-mcp-chatgpt-v0.5.0-windows-x64-installer.exe`。
2. 运行 Installer。
3. 选择目标项目的 `project.godot`。
4. 如果项目已经打开，重新打开/重启 Godot 项目。

Installer 只会写入所选项目：

```text
<project>/addons/godot_mcp_chatgpt/
<project>/project.godot
```

它默认启用 Editor Plugin，也支持原地升级。手动安装可直接解压 Addon ZIP，确保 `<project>/addons/godot_mcp_chatgpt/plugin.cfg` 存在，然后在 **Project → Project Settings → Plugins** 启用 **Godot MCP ChatGPT**。

### 2. 连接插件

打开底部 **MCP ChatGPT** 面板，填写 `Tunnel ID` 和 `Runtime API Key`，点击 **Connect**。首次成功连接后，Runtime API Key 会保存到 Windows Credential Manager，用于自动重连；**Forget Saved Credentials** 可删除保存的 Key 和 Tunnel ID。

### 3. 在 ChatGPT 添加 Connector

为 OpenAI Secure MCP Tunnel 创建/使用 ChatGPT Connector，并确认 Godot 工具已经发现。第一条安全请求可以是：

```text
检查当前 Godot 项目和当前场景，不要修改任何内容。
```

完整流程见 [快速上手](docs/QUICKSTART.zh-CN.md)。

## Public Tool 模型

v0.5.0 把 v0.4.0 的 119 个扁平 Public Tools 改为 **47 个默认 Public Tools**，同时在内部保留并扩展到 **230 个 Atomic Commands**。

Public Surface 由 31 个高频 Direct Tools 与 16 个 Compact Domain Router 组成：

```text
project.manage   input_map.manage  scene.manage     node.manage
script.manage    resource.manage   classdb.manage   editor.manage
debugger.manage  runtime.manage    logs.manage      test.manage
autoload.manage  content.manage    world.manage     custom.manage
```

每个 `*.manage` 使用 `op` + `params`；实时 MCP Schema 会列出允许的操作，Server 再按照对应 Atomic Command Schema 校验 `params`。完整 47 个公开名称见 [工具参考](docs/TOOL_REFERENCE.zh-CN.md)。

这是有意的 Tool-Surface Breaking Change：硬编码 v0.4 Public Tool Name 的调用方需要适配；Web ChatGPT 正常会自动重新发现实时 Catalogue。

## 安全边界

- Project 文件/Resource 路径限制在 `res://` 内，拒绝路径穿越和项目外路径；
- Scene 覆盖和破坏性操作必须显式调用并带正确 Annotation；
- `diagnostics.run_capture` 是有边界 Godot Runner，不是任意 Shell；
- `batch.execute` 仍是有边界 Non-Atomic；`batch.execute_transaction` 只对可逆操作声明 rollback；
- Screenshot 是有边界 MCP image content，不提供任意文件系统截图；
- Input Injection 只作用于已连接的 Godot Editor/Runtime 路径；
- Custom Tool 必须属于注册 Addon、Schema 校验、显式安全 Hint、默认禁用；
- Runtime 修改不会自动写回保存的 Editor Scene；
- 本地 MCP Endpoint 只绑定 loopback，供官方 tunnel client 使用；
- Runtime API Key 使用 Windows Credential Manager 保存，不写入 Project/Git。

处理包含敏感或破坏性工作流的项目之前请阅读 [安全说明](SECURITY.zh-CN.md)。

## 验证

v0.5.0 在 2026-09-10 完成了本地、Official Tunnel、Installer、Repository Hygiene 和**真实 Web ChatGPT Connector** 一次性回归。

关键 Marker：

```text
CATALOGUE_SCHEMA_GATE=PASS tools=47
COMPACT_TOOL_SURFACE_GATE=PASS public=47 atomic=230
PHASE_E_WORLD_EXTENSIBILITY=PASS
CAPABILITY_MIGRATION_MATRIX=PASS excluded=4 public=47 atomic=230
PRODUCTION_PLUGIN_SMOKE=PASS
FULL_OFFICIAL_TUNNEL_SMOKE=PASS
REAL_CHATGPT_GODOT_MCP_0_5_TEST=PASS
```

真实 Connector 验证覆盖 Project/Script、Scene/Node/UndoRedo、高层 Content/Animation、TileMap/TileSet 图片 Content、GridMap、CSG、输入注入、Runtime/UI、Screenshot、Logs、Tests、Batch/Transaction、Custom Tool Promotion 和最终 Cleanup。

本轮保留 3 个非阻断观察：

- Tunnel 曾出现一次可恢复 `network_error: Connection failed`，Editor 仍在线，立即重试成功；
- Native Debugger 在 `debuggable=false` 时当前可能 no-op 但仍返回 `ok=true`；
- `editor.manage(op="stop")` 可能报 unsupported，而独立 `stop_playing` 操作可以正常停止。

## 文档

### 用户

| 文档 | 用途 |
| --- | --- |
| [快速上手](docs/QUICKSTART.zh-CN.md) | 安装、连接、第一次安全调用 |
| [工具参考](docs/TOOL_REFERENCE.zh-CN.md) | v0.5 Compact Public Surface 与约定 |
| [常用示例](docs/EXAMPLES.zh-CN.md) | 实用 Prompt 与工作流 |
| [FAQ](docs/FAQ.zh-CN.md) | 常见问题与排障 |
| [安全](SECURITY.zh-CN.md) | Trust Boundary 与安全行为 |
| [架构](docs/ARCHITECTURE.zh-CN.md) | 生产架构与组件职责 |
| [Secure Tunnel](docs/SECURE_TUNNEL.zh-CN.md) | Tunnel/Runtime 行为与排障 |

### 维护者

| 文档 | 用途 |
| --- | --- |
| [Contributing](CONTRIBUTING.zh-CN.md) | 贡献规则 |
| [开发计划](docs/DEVELOPMENT_PLAN.zh-CN.md) | 已完成里程碑与后续方向 |
| [开发工作流](docs/DEVELOPMENT_WORKFLOW.zh-CN.md) | Definition of Done 与文档规则 |
| [发布流程](docs/RELEASING.zh-CN.md) | Release Checklist |
| [当前进度](docs/PROGRESS.zh-CN.md) | 当前 Repository/Release 状态 |
| [0.5.0 发布记录](docs/DEVELOPMENT_0.5.zh-CN.md) | v0.5 能力迁移实现与验证记录 |
| [0.4.0 发布记录](docs/DEVELOPMENT_0.4.zh-CN.md) | 已关闭 v0.4 技术记录 |

## 范围与上游参考

v0.5.0 已迁移审计中缺失的 Godot-side 能力，同时明确排除 4 个不属于本项目架构目标的 Transport/Client 项：`godot://...` MCP Resources、MCP Client Auto-config、Python/FastMCP Server、Godot AI WebSocket Bridge。已有等价或更强能力不重复实现。

[Godot AI](https://github.com/hi-godot/godot-ai) 是成熟的 MIT Godot MCP 开源项目。v0.5 将它的能力面和 Compact Domain/Rollup 设计作为重要参考；`godot-mcp-chatgpt` 仍是面向 Web ChatGPT 的独立实现，不依赖 Godot AI 的 Transport/Client Stack。

## 参与贡献

欢迎提交 Issue 和聚焦的 Pull Request。高质量报告应包含 Godot 版本/OS、复现步骤、相关 MCP 请求、期望/实际行为、非敏感日志，以及问题属于 Editor、Runtime、Transport、Installer 还是 Documentation。

## License

项目源码许可证见 [LICENSE](LICENSE)。Bundled 官方 OpenAI `tunnel-client` 保留其上游 License/NOTICE，见 [Third-Party Notices](THIRD_PARTY_NOTICES.zh-CN.md)。
