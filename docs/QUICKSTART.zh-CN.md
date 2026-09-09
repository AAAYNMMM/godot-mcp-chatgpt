# 快速上手

[English](QUICKSTART.md) | 简体中文

这份指南面向第一次使用的用户，目标是用尽可能少的步骤，把一个普通 Godot 项目连接到 Web ChatGPT。

## 需要什么

当前已验证环境：

- Windows x64；
- Godot 4.7.2 Standard x64；
- 一个可以修改的 Godot 项目；
- 你的 OpenAI/ChatGPT 工作区能够使用 Secure MCP Tunnel；
- 一个 Tunnel ID；
- 一个用于该 Tunnel 的受限 Runtime API Key。

运行时**不需要** CWapi、Node.js、Codex、Claude Desktop、Cursor 或其他本地 MCP 客户端。

## 第 1 步：安装插件

把插件放到：

```text
<你的项目>/addons/godot_mcp_chatgpt/
```

目录里应当能看到 `plugin.cfg`。

在 Godot 中打开：

```text
项目 -> 项目设置 -> 插件
```

启用 **Godot MCP ChatGPT**。

预期结果：Godot 底部出现 **MCP ChatGPT** 面板。

## 第 2 步：准备 OpenAI Tunnel

在你的 OpenAI 工作区创建或选择一个 Secure MCP Tunnel。

记住 Tunnel ID，例如：

```text
tunnel_...
```

再创建一个专门用于 Tunnel 的受限 Runtime API Key。不要为了省事长期使用 Admin Key。

不要把 Runtime API Key 提交进 Git，也不要贴到公开 Issue。

## 第 3 步：在 Godot 中连接

打开底部 **MCP ChatGPT** 面板，填入：

```text
Tunnel ID
Runtime API Key
```

点击 **Connect**。

预期状态：

```text
Status: connected
```

在 0.3.0 中，这表示插件内置的官方 OpenAI `tunnel-client` 子进程已经正常运行，并且本地 Godot MCP endpoint 已经准备好供它访问。

如果状态没有变成 connected，请直接看 [FAQ / 排错](FAQ.zh-CN.md)。

## 第 4 步：在 ChatGPT 创建连接器

在 ChatGPT 的连接器设置中：

1. 创建新连接器；
2. 选择 **Connection: Tunnel**；
3. 选择或填写和 Godot 中完全相同的 Tunnel ID；
4. 保持 Godot 打开的情况下创建/保存连接器。

0.3.0 已经完成过真实 ChatGPT 连接器创建测试，并成功通过。

## 第 5 步：先测试只读能力

先让 ChatGPT 调用：

```text
godot.get_status
```

在当前测试环境中，正常结果应包含以 `4.7.2` 开头的 Godot 版本，以及编辑器/项目信息。

再测试：

```text
project.get_info
```

如果这两个都能调用，说明远程 MCP 工具发现和只读调用已经正常。

## 第 6 步：测试一次性写入

第一次写入不要拿重要场景做实验。

建议按这个安全流程：

```text
scene.create
  path: res://mcp_test/main.tscn
  root_type: Node3D
  root_name: MCPTest

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

然后直接在 Godot 里确认：

- `main.tscn` 已创建；
- 根节点是 `MCPTest`；
- 存在 `RemoteNode`；
- position 是 `(1, 2, 3)`。

## 第 7 步：按真实开发方式使用

实际使用时，更推荐描述“你想要的结果”，而不是手动指挥每一个 MCP 工具。例如：

```text
在当前 Godot 项目中创建一个简单的玩家测试场景：
根节点 Node3D，添加名为 Player 的 CharacterBody3D，
新建并挂载一个 GDScript，暴露 move_speed 变量。
保存到 res://prototype/player_test.tscn，不要覆盖已有文件。
```

当前能力面已经达到 119 tools。如果 ChatGPT 暂时无法读取或修改某个东西，先查看 [工具参考](TOOL_REFERENCE.zh-CN.md)和实时 tool schema，不要直接判断为“连接坏了”。

## 断开连接

更换 Tunnel 或轮换凭据前，先在 Godot 面板点 **Disconnect**。

Windows 0.4.0 在首次成功连接后会把 Runtime API Key 保存到 Windows Credential Manager，重启 Godot 后可自动重连。使用 **Forget Saved Credentials** 可以删除保存的 Key 和 Tunnel ID。

## 最先检查的排错项

如果失败，按这个顺序看：

1. Godot 插件是否启用？
2. 底部是否显示 `Status: connected`？
3. ChatGPT 连接器是否用了完全相同的 Tunnel ID？
4. Godot 是否仍然开着？
5. Runtime API Key 是否具备所需 Tunnel 权限？
6. ChatGPT 能否发现 `godot.get_status`？
7. 你要求的操作是否属于当前 119-tool 能力面，并且参数是否符合 Tool Reference 约定？

更多见：[FAQ / 排错](FAQ.zh-CN.md)。