# 安全说明

[English](SECURITY.md) | 简体中文

`godot-mcp-chatgpt` 会让远程 ChatGPT 会话具备修改真实 Godot 项目的能力。这很有用，但也意味着工具权限边界必须保持清晰、尽量收窄。

## 当前安全模型

0.3.0 的运行链路：

```text
ChatGPT
 -> OpenAI Secure MCP Tunnel
 -> 官方 OpenAI tunnel-client
 -> 127.0.0.1 Streamable HTTP MCP
 -> Godot 编辑器工具
```

### 本地 MCP 暴露范围

Godot 内置 MCP Server：

- 只绑定 `127.0.0.1`；
- 每次运行选择随机高位端口；
- 每次运行选择随机 URL 路径；
- 设计上不直接暴露给局域网或公网。

### Runtime API Key 处理

插件：

- 只持久化 Tunnel ID；
- 不把 Runtime API Key 持久化进 Godot `EditorSettings`；
- 不把明文 key 写入生成的 tunnel profile；
- profile 通过 `env:CONTROL_PLANE_API_KEY` 引用；
- 子进程启动后，从 Godot 父进程环境变量中移除 key。

用户应该创建专门的受限 Runtime API Key，只授予 OpenAI 工作区实际需要的最小 Tunnel 权限。

### 文件系统边界

当前文件工具限制在 `res://` 内，并拒绝 `..` 路径穿越。

这是有意设置的边界。未来任何扩大文件系统访问范围的功能，都应该视为安全敏感改动。

### 破坏性操作

当前保护示例：

- `scene.create` 默认拒绝覆盖已有场景，只有显式传 `overwrite: true` 才允许；
- `node.delete` 不能删除当前编辑场景根节点；
- 适用的破坏性工具会使用正确 MCP annotations；
- 当前没有通用任意 Shell 执行工具。

## 用户使用建议

在真实项目中使用时：

1. 使用 Git 或其他版本控制；
2. 大规模 AI 修改前先 commit/checkpoint；
3. 使用受限 Runtime API Key；
4. 不要把 key 发到聊天、截图或 Issue；
5. 不熟悉的工作流先在一次性场景测试；
6. 保存/提交前检查破坏性改动；
7. 轮换 Tunnel 凭据前先 Disconnect。

## 当前信任边界

项目默认：

- 运行 Godot 的本地 Windows 账号是可信的；
- 内置官方 OpenAI tunnel runtime 作为第三方组件被信任；
- 你选择的 OpenAI/ChatGPT 工作区和 Tunnel 是你明确授权访问该 Godot 实例的。

本项目不会试图把 Godot 编辑器与它自己加载的插件进程做沙箱隔离。

## 报告安全问题

不要在公开 Issue 中发布密钥，也不要公开包含真实用户凭据的可利用漏洞细节。

一个有价值的安全报告应包含：

- 受影响插件版本/commit；
- 操作系统/Godot 版本；
- 明确影响；
- 最小复现步骤；
- 是否突破了 `res://`、仅 loopback 网络、凭据处理或破坏性操作边界；
- 只包含不敏感日志。

如果仓库暂时没有配置私密安全报告渠道，可以先开一个**不包含敏感细节**的公开 Issue，请求私密联系方式。不要贴凭据或私人项目数据。

## 第三方运行时

内置 OpenAI `tunnel-client` 保留上游许可证和 NOTICE。运行时版本和 SHA-256 已记录在 README 和 `addons/godot_mcp_chatgpt/bin/RUNTIME_INFO.txt`。

## 需要额外安全评审的改动

以下类型应视为安全敏感：

- 任意 Shell/进程执行；
- 访问 `res://` 之外的文件；
- 监听非 loopback 网卡；
- 持久化 Runtime API Key；
- 把本地 MCP endpoint 直接公开到公网；
- 移除覆盖/删除保护；
- 在官方 Tunnel 路径之外接受未鉴权远程 transport。