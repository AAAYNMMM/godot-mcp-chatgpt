# 安全说明

[English](SECURITY.md) | 简体中文

`godot-mcp-chatgpt` 会让经过授权的远程 ChatGPT Connector 读取和修改真实 Godot 项目。因此 0.4.0 把文件系统范围、凭据保存、Runtime 控制、进程执行和破坏性操作都作为明确安全边界。

## 0.4.0 运行链路

```text
ChatGPT
 -> OpenAI Secure MCP Tunnel
 -> 官方 OpenAI tunnel-client
 -> 随机 127.0.0.1 Streamable HTTP MCP endpoint
 -> Godot CommandRegistry
 -> Godot Editor API
      或
 -> EditorDebuggerPlugin -> EngineDebugger -> 运行中的游戏
```

插件本身不重写 OpenAI Tunnel wire protocol。

## 本地 MCP 暴露范围

Godot 内置 MCP Server：

- 只监听 `127.0.0.1`；
- 每次启动随机高位端口；
- 每次启动随机 URL path；
- 只作为插件内置官方 tunnel-client 的本地后端；
- 不主动监听局域网或公网接口。

## Runtime API Key 保存

Windows 0.4.0：

- Tunnel ID 保存在 Godot `EditorSettings`；
- Runtime API Key 作为 **Windows Generic Credential** 保存到 Windows Credential Manager；
- 插件独立 Credential target：`godot-mcp-chatgpt/0.4/OpenAI/Tunnel/APIKey`；
- 明文 Key 不进入 `project.godot`、Git 或生成的 tunnel YAML profile；
- profile 只引用 `env:CONTROL_PLANE_API_KEY`；
- Godot 启动官方 `tunnel-client` 时临时设置该环境变量，子进程启动后立即从 Godot 父进程环境删除，并清空插件内存中的 Key；
- 运行中的 `tunnel-client` 子进程会继承该环境值，这是进程启动机制本身所需；
- **Forget Saved Credentials** 会同时删除保存的 Tunnel ID 和 Windows Credential Manager 条目。

如果本机 Windows 用户账户已经被攻破，或者某个进程拥有足够权限，同用户进程环境仍可能被检查。Credential Manager 的目标是防止 Key 泄漏到项目、Git 和普通配置文件，而不是对已失陷本机账户提供沙箱。

建议为这个 Tunnel 使用专门、受限、最小权限的 Runtime API Key。

## 文件系统边界

项目 File / Resource 工具只允许在 `res://` 内操作。

0.4.0 会明确拒绝：

- `res://../...` 路径穿越；
- Windows 绝对路径或其他项目外路径；
- Resource load/save 前发现的非法源路径或目标路径。

真实 ChatGPT Connector 回归已经验证这些边界。未来如果要访问 `res://` 之外的文件，必须单独做安全评审。

## Scene / Node 安全保护

例如：

- `scene.create` 默认不能覆盖已有 Scene，除非显式传 `overwrite: true`；
- `node.delete` 不能删除当前编辑 Scene root；
- 非法 Node class/property/method 返回错误，不会退化成任意操作；
- Signal / Group / Metadata 编辑只作用于当前 Godot 项目和场景。

## Runtime Debugger 边界

0.4.0 使用 Godot 自己的 Debugger 通道：

```text
EditorDebuggerPlugin
 <-> Godot remote-debug session
 <-> EngineDebugger
 <-> GodotMCPChatGPTRuntime autoload
```

它不会再打开第二个公网网络监听。Runtime 修改只影响正在运行的实例，不会自动写回保存的编辑器 Scene。

插件被禁用时会清理保留的 runtime autoload，并兼容 Godot 4.7.2 的 `uid://` 路径正规化。

## Diagnostics 边界

`diagnostics.run_capture` **不是**通用 Shell / 任意进程工具。

它只允许启动：

- 当前 Godot executable；
- 当前项目；
- 可选项目内 `res://` Scene；
- 并受到 timeout 和输出大小上限控制。

返回 stdout、stderr、exit code、timeout、duration 和截断状态。

## Batch 边界

`batch.execute`：

- 有 operation 数量和 payload 上限；
- 只能执行已经注册的 MCP tools；
- 拒绝递归调用 `batch.*`；
- 支持第一项错误后停止；
- **不是事务**，不会回滚前面已经成功的操作。

## 安装器边界

Windows x64 安装器是项目级安装器，不扫描项目，也不做全局安装。用户必须明确选择一个 `project.godot`，安装器只会写入：

```text
<所选项目>/addons/godot_mcp_chatgpt/
<所选项目>/project.godot
```

安装前会校验目标项目；内嵌 addon 解包时有路径穿越检查；升级时先在所选项目内 staging，再备份已有 `godot_mcp_chatgpt`，新版本激活失败时会恢复旧版本；不会删除其他 EditorPlugin entry；成功后会清理安装临时目录和备份。

安装器不需要管理员权限，也不包含写死的用户/项目路径。当前 Release EXE 未做代码签名；需要校验来源时，请使用发布页提供的 `SHA256SUMS.txt`。

## 不提供通用 Shell MCP

0.4.0 不暴露通用任意 Shell / PowerShell / cmd / executable MCP 工具。未来如果增加，会显著扩大信任边界，必须单独做安全评审。

## 用户建议

1. 使用 Git 或其他版本控制。
2. 大规模 AI 修改前先 commit / checkpoint。
3. 使用专门的受限 Runtime API Key。
4. 不要把真实 Key 放进聊天、截图、Issue、日志或测试夹具。
5. 不熟悉的破坏性工作流先在临时 Scene 中测试。
6. 大修改提交前先检查 diff。
7. 如果不再希望自动重连，轮换/取消权限前使用 **Forget Saved Credentials**。
8. 把能够访问已授权 ChatGPT workspace/tunnel 的主体视为拥有相应 MCP 操作权限。

## 验证

0.4.0 已通过：

```text
BOM_CHECK=PASS
SECRET_CHECK=PASS
CATALOGUE_SCHEMA_GATE=PASS tools=119
PRODUCTION_PLUGIN_SMOKE=PASS
CREDENTIAL_RESTART_SMOKE=PASS
RUNTIME_AUTOLOAD_LIFECYCLE_SMOKE=PASS
REAL_CHATGPT_GODOT_MCP_0_4_TEST=PASS
```

真实 Connector 测试实际覆盖了路径穿越拒绝、项目外路径拒绝、Scene root 删除拒绝、非法 class/property/method、Diagnostics 边界和 Batch 递归拒绝。

## 信任边界

项目假设：

- 运行 Godot 的本机 Windows 账户可信；
- 插件内置的官方 OpenAI tunnel runtime 作为第三方组件可信；
- 选择的 OpenAI/ChatGPT workspace 与 tunnel 是有意授权访问当前 Godot 实例的；
- Godot 自身、项目脚本和插件都拥有 Godot 本地进程权限。

插件不会尝试把 Godot 从它自己的插件或已经失陷的本机账户中沙箱隔离。

## 报告安全问题

不要在公开 Issue 中发布真实凭据或包含用户凭据的可用 exploit。

有效安全报告应包含：

- 受影响插件版本/commit；
- OS 与 Godot 版本；
- 明确影响；
- 最小复现步骤；
- 是否越过 `res://`、loopback、Credential Manager、Runtime Debugger、Diagnostics、Batch 或破坏性操作边界；
- 只提供不含秘密的日志。

如果暂时没有私密报告渠道，可以只发不敏感元数据的公开 Issue，请求私密联系方式，不要公开凭据或可直接利用细节。

## 第三方 Runtime

插件内置官方 OpenAI `tunnel-client`，保留上游 Apache-2.0 LICENSE 和 NOTICE。Runtime 版本及 SHA-256 见 README 和 `addons/godot_mcp_chatgpt/bin/RUNTIME_INFO.txt`。

## 需要额外安全评审的变化

以下变化都应视为安全敏感：

- 超出当前有边界 Godot diagnostics runner 的任意 Shell/进程执行；
- 访问 `res://` 之外文件；
- 非 loopback MCP 监听；
- 把 Runtime API Key 从 Windows Credential Manager 改到保护程度更低的存储；
- 直接向公网暴露本地 MCP endpoint；
- 弱化覆盖/删除/路径保护；
- 官方 Tunnel 之外的未认证远程 transport。