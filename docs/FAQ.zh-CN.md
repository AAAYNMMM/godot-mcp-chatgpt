# FAQ 与排错

[English](FAQ.md) | 简体中文

## 需要 CWapi 吗？

不需要。开发过程中 CWapi 作为“已经验证可用的连接方式”提供了参考，但 `godot-mcp-chatgpt` 0.3.0 已经内置官方 OpenAI `tunnel-client`，并自己提供 Godot 本地 MCP Server。

## 需要 Codex、Cursor 或 Claude Desktop 吗？

不需要。这个项目的目标就是让 **Web ChatGPT** 通过 Secure MCP Tunnel 直接访问 Godot 编辑器。

## 需要 Node.js 吗？

普通用户运行时不需要。仓库里的 `server/` 只是开发测试桩，Godot 会忽略它。

## 为什么插件里要带一个 exe？

这个 exe 是官方 OpenAI `tunnel-client`。早期开发版本尝试用 GDScript 自己实现 Tunnel wire protocol，虽然能连接 Tunnel，但真实 ChatGPT 连接器创建失败。0.3.0 改为把 Tunnel 兼容性交给官方运行时，Godot 插件只负责 MCP 和编辑器工具。

## `Status: connected` 到底表示什么？

0.3.0 中表示：

- Godot 本地 MCP Server 已启动；
- 官方 `tunnel-client` 子进程已经启动并保持运行。

它**不等于**“ChatGPT 已经发现工具”。最终应以 ChatGPT 能否发现并调用工具为准。

## ChatGPT 创建连接器失败

按这个顺序检查：

1. Godot 是否还开着；
2. 插件是否启用；
3. 面板是否显示 `Status: connected`；
4. ChatGPT 是否使用了完全相同的 Tunnel ID；
5. Runtime API Key 是否具备所需 Tunnel 权限；
6. 创建的是 Tunnel 连接，而不是手动填本地 `127.0.0.1` URL。

0.3.0 已经完成真实 ChatGPT 连接器创建验证，并成功通过。

## Godot 显示 connected，但 ChatGPT 看不到工具

可以尝试：

1. 保持 Godot 打开；
2. 在 Godot 面板 Disconnect 后重新 Connect；
3. 用同一个 Tunnel ID 刷新或重新创建 ChatGPT 连接器；
4. 确认没有多个不需要的 Godot 实例抢同一个 Tunnel；
5. 查看 MCP ChatGPT 面板最后一条不含密钥的日志。

不要把 Runtime API Key 发到 Issue 或聊天里。

## 重启 Godot 后 API Key 为空

这是设计行为。插件故意不持久化 Runtime API Key。重新输入后 Connect 即可。

## API Key 存在哪里？

插件只把 Tunnel ID 写进 Godot `EditorSettings`。Runtime API Key 通过 `CONTROL_PLANE_API_KEY` 用于启动官方 tunnel-client，不会写进生成的 profile。

## 本地 MCP Server 会监听局域网吗？

不会。它只绑定 `127.0.0.1`，使用随机高位端口和每次启动随机路径。

## ChatGPT 能通过这个插件执行任意 Shell 命令吗？

当前不能。Godot MCP 工具里没有通用 Shell 工具。

## 能修改 Godot 项目目录以外的文件吗？

当前文件工具限制在 `res://`，并拒绝 `..` 路径穿越。

## 为什么 `scene.create` 不肯覆盖已有场景？

这是安全设计。只有显式传 `overwrite: true` 才允许覆盖。

## 为什么 ChatGPT 看不到我需要的节点属性？

0.3.0 有 `node.set_property`，但还没有完整的属性枚举工具。先看路线图，不要把“缺工具”误判成“连接失败”。

## 为什么不能打开已有场景？

初始 13 工具里还没有专门的 `scene.open`。

## 支持哪些 Godot 版本？

当前明确验证的是 Windows 上的 Godot 4.7.2 Standard x64。其他 Godot 4.x 版本可能可用，但在测试前都应视为“未验证”。

如果你测试了其他版本，一个高质量 Issue 最好包含：

```text
Godot 版本：
操作系统：
插件版本：
连接器创建成功：是/否
发现工具数量：
第一个失败工具/报错：
```

## 渲染器有影响吗？

对 MCP 连接方式没有影响。项目开发时偏向低开销/Compatibility 友好的 Godot 工作流，但连接器本身属于编辑器工具基础设施。

## 多个 ChatGPT 对话能共用一个 Tunnel 吗？

Tunnel/运行时可能能接收多个远程调用，但 Godot 编辑器修改是有状态的。在多会话行为被专门测试前，最稳妥的默认方式是：一个 Godot 实例对应一个主要编辑工作流。

## 为什么不一次性暴露几百个 Godot 工具？

超大的 MCP 工具面会增加维护成本、工具 schema 上下文开销和模型选择歧义。本项目优先做少量高频工具，然后按真实用户工作流扩展。

## 怎么提交一个高质量 bug？

请提供：

- Godot 版本；
- 操作系统；
- 插件 commit/版本；
- Godot 面板是否到 `connected`；
- ChatGPT 连接器是否创建成功；
- 完整但不含密钥的报错；
- 最小复现步骤；
- 问题属于只读、场景/节点/脚本修改，还是运行/停止。

不要提交 API Key、Shard Token 或其他凭据。

## 我有一个新工具想法，怎么提更有价值？

描述“真实工作流”，不要只说方法名。例如：

> 我需要在修改节点前读取它可编辑的属性列表，现在 ChatGPT 只能猜属性名。

这比：

> 再加 100 个节点工具。

更容易设计出正确接口。

更多见：[CONTRIBUTING.zh-CN.md](../CONTRIBUTING.zh-CN.md)。