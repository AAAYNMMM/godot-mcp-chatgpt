# 0.4.0 完全体开发追踪

[English](DEVELOPMENT_0.4.md) | 简体中文

目标版本：**0.4.0**

分支：`main` 持久开发工作区

本轮开发期间的公开已验证基线：**0.3.0**

本文档状态：同时追踪已提交基线，以及明确标注的未提交工作区开发状态。

## 1. 目标

0.4.0 是能力全面扩展版本。目标不是勉强可用的 Demo 工具集，而是让 Godot MCP 能够较完整地自行发现、理解、修改、运行、检查和调试真实 Godot 项目，尽量不再需要用户手工转述日常项目上下文。

完整闭环目标：

```text
读取项目
 -> 发现文件/场景/脚本/资源
 -> 查询 Godot 4.7.2 真实 API
 -> 修改项目/编辑器状态
 -> 保存
 -> 运行
 -> 获取诊断/运行时状态
 -> 修复
 -> 再验证
```

## 2. 不可退回的架构

0.4.0 保持 0.3.0 已真实验证的连接架构：

```text
ChatGPT
 -> OpenAI Secure MCP Tunnel
 -> 官方内置 tunnel-client
 -> Godot loopback Streamable HTTP MCP
 -> command registry
 -> Godot Editor / Runtime APIs
```

禁止重新引入已经删除的自定义 OpenAI Tunnel wire client。

## 3. API Key 持久化

决策：复用 CWapi 的**存储类型和系统机制**，但不复用它的 Credential Target。

已只读检查 CWapi：它通过 `CredWriteW`、`CredReadW`、`CredDeleteW` 使用 Windows Credential Manager 的 Generic Credential。

0.4.0 使用相同机制，但独立 Target：

```text
godot-mcp-chatgpt/0.4/OpenAI/Tunnel/APIKey
```

不能使用 CWapi 的 `CWapi/2.0/...` Target，避免两个产品互相覆盖凭据。

目标行为：

```text
第一次：
Tunnel ID + Runtime API Key
 -> 保存 Tunnel ID
 -> API Key 写入 Windows Credential Manager
 -> 启动 tunnel-client

以后重启 Godot：
保存的 Tunnel ID + Credential Manager API Key
 -> 自动重连
```

Tunnel profile 仍然只能包含：

```yaml
api_key: env:CONTROL_PLANE_API_KEY
```

### 凭据状态

| 项目 | 状态 | 证据 / 剩余门禁 |
| --- | --- | --- |
| Windows credential helper | targeted validation passed | 隔离 write/present/read/delete round trip 通过 |
| Godot credential-store wrapper | targeted validation passed | Godot 4.7.2 脚本加载通过 |
| UI 保存/忘记凭据流程 | implemented / validation pending | 仍需完整生产 UI smoke |
| Godot 重启后自动连接 | implemented / validation pending | 尚未执行跨进程重启测试 |
| Secret/profile 泄漏回归 | planned | 最终 secret scan + profile 检查 |

## 4. 能力矩阵

以下状态描述当前持久工作区，不代表公开 0.3.0 release。

| 范围 | 状态 | 内容 |
| --- | --- | --- |
| 公共 Variant/Object 编解码 | targeted validation passed | Variant 编解码、属性/方法/Signal 描述、输出限制 |
| Project 发现/搜索 | targeted validation passed | inspect/list/find/search |
| ProjectSettings | targeted validation passed | get/set/list |
| InputMap | targeted validation passed | list/get/add/remove/events |
| 项目文件操作 | targeted validation passed | `res://` 内 mkdir/move/delete |
| Scene 生命周期 | targeted validation passed | current/open/list/close/reload/save/instantiate/inspect |
| Node 自省 | targeted validation passed | inspect/properties/methods/find |
| Node 修改 | targeted validation passed | rename/reparent/duplicate/move/call |
| Groups | targeted validation passed | read/add/remove |
| Signals | targeted validation passed | 连接读取/connect/disconnect |
| Metadata | targeted validation passed | read/set/remove |
| Script 自省 | targeted validation passed | info/validate/open-state/reload/save/detach |
| Resource 自省/修改 | targeted validation passed | inspect/get/set/create/save/duplicate/dependencies/call |
| ClassDB 自省 | targeted validation passed | search/inspect/properties/methods/signals/enums/constants/inheritance |
| Editor 状态 | planned | selection、打开场景/脚本、filesystem、play state |
| 捕获运行诊断 | planned | stdout/stderr 和退出状态 |
| Editor Debugger 集成 | planned | debugger session/message/break state |
| Runtime bridge | planned | runtime tree/node/property/method/group/performance |
| Batch | planned | 有边界的批量操作与逐项结果 |
| 聚合 Inspect | in progress | 已有 `scene.inspect`、`node.inspect`；仍需 project/editor/runtime 聚合 |
| 生产 command 注册 | planned | 新模块尚未暴露给生产插件 |
| 完整 MCP schema/catalogue 验证 | planned | 注册完成后执行 |
| 完整生产 Tunnel 回归 | planned | 正式升级前必须执行 |

## 5. 当前工作区模块

0.4.0 当前开发包含：

```text
addons/godot_mcp_chatgpt/core/command_utils.gd
addons/godot_mcp_chatgpt/commands/project_commands.gd
addons/godot_mcp_chatgpt/commands/scene_node_commands.gd
addons/godot_mcp_chatgpt/commands/script_resource_commands.gd
addons/godot_mcp_chatgpt/commands/classdb_commands.gd
addons/godot_mcp_chatgpt/web/credential_store.gd
tools/credential-helper/
addons/godot_mcp_chatgpt/bin/windows/godot-mcp-credential.exe
```

在生产注册和发布门禁通过之前，这些**不属于公开 release 的正式工具契约**。

## 6. Tool Family 目标

0.4.0 追求功能族完整，而不是单纯追求工具数量：

```text
godot.*
project.*
input_map.*
scene.*
node.*
script.*
resource.*
classdb.*
editor.*
debugger.*
runtime.*
batch.*
```

一个功能族只有在正常读取、修改（适用时）、发现、验证/错误处理和安全边界都覆盖后，才算完整。

## 7. Runtime / Debug 设计

运行时控制优先使用 Godot 自己的 Debugger 通道：

```text
Editor MCP
 -> EditorDebuggerPlugin / EditorDebuggerSession
 -> EngineDebugger message channel
 -> runtime bridge
 -> running SceneTree
```

不能为了 Runtime 控制再暴露第二个公网监听端口。

Godot 4.7.2 没有简单公开 API 可以直接抓取 Output Dock 全部文本，因此诊断功能必须真实实现，例如捕获运行进程或 Debugger Message，不能虚假宣称读取了无法通过支持 API 获取的 UI Output。

## 8. 安全要求

- 文件写操作继续限制在 `res://`；
- 不提供任意 shell MCP tool；
- method-call 工具必须结构化报错并有边界；
- batch 必须限制数量/数据量；
- 递归 inspect 必须限制深度/条目数；
- destructive annotation 必须准确；
- 覆盖已有 Scene 继续要求显式确认参数；
- Credential 不能写日志、不能通过 MCP 返回；
- Runtime API Key 不能进入项目文件或 Git。

## 9. 验证门禁

0.4.0 在以下门禁通过之前，不能升级公开 Tool Reference。

### 模块门禁

- [x] Credential helper 隔离 round trip
- [x] Credential GDScript 编译
- [x] Project 命令模块编译
- [x] Scene/Node 命令模块编译
- [x] Script/Resource 命令模块编译
- [x] ClassDB 命令模块编译
- [ ] Editor 命令模块编译
- [ ] Runtime/Debugger 模块编译
- [ ] Batch 模块编译

### 集成门禁

- [ ] 所有 0.4.0 模块注册进生产插件
- [ ] Godot 4.7.2 全插件脚本编译
- [ ] 工具名唯一性验证
- [ ] 全 MCP input schema 验证
- [ ] tool annotation 验证
- [ ] loopback MCP `tools/list` + 代表性 `tools/call`
- [ ] 真实 Godot GUI editor 读写 smoke
- [ ] Credential 保存 -> 重启 Godot -> 自动重连
- [ ] Forget Credential -> 重启 -> 要求重新输入
- [ ] 捕获运行诊断 smoke
- [ ] Runtime Debugger Bridge smoke
- [ ] official tunnel-client 集成回归
- [ ] 真实 ChatGPT connector discovery/call 回归

### 仓库/发布门禁

- [ ] 删除 WIP `plugin.cfg` 意外 UTF-8 BOM，并扫描所有文本
- [ ] Secret scan
- [ ] `git diff --check`
- [ ] 测试产物 / 生成文件卫生检查
- [ ] 文档相对链接检查
- [ ] 更新英文 + 中文 Tool Reference
- [ ] 更新 README 能力摘要
- [ ] 更新 CHANGELOG
- [ ] 凭据/runtime surface 有实质变化时更新 SECURITY
- [ ] 完整基线一致后才 commit/push

## 10. 当前 blocker

没有已知架构 blocker。

当前实现刻意**尚未注册到生产 command registry**。仍需完成 Editor、Runtime/Debugger、Batch 和完整集成验证。

还有一个已知工作区卫生问题：WIP `plugin.cfg` 在中间编辑时意外带入 UTF-8 BOM。必须在全插件/发布验证前清掉。

## 11. 精确下一项任务

1. 实现并编译 Editor 状态/控制模块；
2. 该任务 targeted validation 通过后，**立即更新 `docs/PROGRESS.md`**；
3. 再实现 Runtime/Debugger Bridge；
4. 再次先更新 Progress，之后才能进入下一任务。

后续所有任务边界遵循 [开发工作流](DEVELOPMENT_WORKFLOW.zh-CN.md)。