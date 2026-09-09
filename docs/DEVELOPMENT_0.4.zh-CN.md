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
| Editor 状态/控制 | targeted validation passed | inspect、selection、filesystem、script state、play 控制、save-all |
| 捕获运行诊断 | targeted validation passed | stdout/stderr 分离捕获、exit code、timeout、duration、截断状态 |
| Editor Debugger 集成 | targeted validation passed | debugger session、断点/profiler 控制、Godot debugger message |
| Runtime bridge | targeted validation passed | live tree/inspect/find/property/method/group/performance/pause-resume |
| Batch | targeted validation passed | 最多 50 项、顺序执行、逐项结果、stop-on-error、递归拒绝 |
| 聚合 Inspect | targeted validation passed | project/scene/node/editor/runtime 聚合读取均已具备 |
| 生产 command 注册 | in progress | Editor 模块已为 WIP 行为验证接入；其余 0.4 模块尚未全部暴露 |
| 完整 MCP schema/catalogue 验证 | integration passed | 119 tools 名称/schema/required/annotations 全量门禁通过 |
| 完整生产 Tunnel 回归 | integration passed | bundled official tunnel-client production smoke 通过 |

## 5. 当前工作区模块

0.4.0 当前开发包含：

```text
addons/godot_mcp_chatgpt/core/command_utils.gd
addons/godot_mcp_chatgpt/commands/project_commands.gd
addons/godot_mcp_chatgpt/commands/scene_node_commands.gd
addons/godot_mcp_chatgpt/commands/script_resource_commands.gd
addons/godot_mcp_chatgpt/commands/classdb_commands.gd
addons/godot_mcp_chatgpt/commands/editor_commands.gd
addons/godot_mcp_chatgpt/commands/runtime_debugger_commands.gd
addons/godot_mcp_chatgpt/debug/editor_debugger_bridge.gd
addons/godot_mcp_chatgpt/debug/runtime_debugger_manager.gd
addons/godot_mcp_chatgpt/runtime/runtime_bridge.gd
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
- [x] Editor 命令模块编译 + 真实 EditorPlugin 行为 smoke
- [x] Runtime/Debugger 模块编译 + 真实 runtime bridge smoke
- [x] Batch 模块编译 + production smoke

### 集成门禁

- [x] 所有 0.4.0 模块注册进生产插件（119 tools）
- [x] Godot 4.7.2 全插件脚本编译
- [x] 工具名唯一性验证
- [x] 全 MCP input schema 验证
- [x] tool annotation 验证
- [x] loopback / official tunnel MCP `tools/list` + 代表性 `tools/call`
- [x] 真实 Godot GUI editor 读写 smoke
- [x] Credential 保存 -> 重启 Godot -> 自动重连
- [x] Forget Credential -> 重启 -> 要求重新输入
- [x] 捕获运行诊断 smoke
- [x] Runtime Debugger Bridge smoke
- [x] official tunnel-client 集成回归
- [x] 真实 ChatGPT connector discovery/call 回归

### 仓库/发布门禁

- [x] 删除 WIP `plugin.cfg` 意外 UTF-8 BOM，并扫描所有文本
- [x] Secret scan
- [x] `git diff --check`
- [x] 测试产物 / 生成文件卫生检查
- [x] 文档相对链接检查
- [x] 更新英文 + 中文 Tool Reference
- [x] 更新 README 能力摘要
- [x] 更新 CHANGELOG
- [x] 凭据/runtime surface 有实质变化时更新 SECURITY
- [ ] 完整基线一致后才 commit/push

### 凭据跨重启生命周期

状态：**集成验证通过**。

- [x] 首次保存 -> Windows Credential Manager
- [x] 重启 Godot -> 无需重新输入 API Key 自动连接
- [x] Forget -> Key 与 Tunnel ID 一并删除
- [x] Forget 后重启 -> 重新要求凭据
- [x] 使用隔离测试 target，未触碰生产凭据 target

### Runtime autoload 生命周期

状态：**集成验证通过**。

- [x] 插件启用 -> runtime autoload 存在
- [x] 插件禁用 -> runtime autoload 被移除
- [x] 插件重新启用 -> runtime autoload 恢复
- [x] Godot 4.7.2 `uid://` autoload 引用可正确解析到 runtime bridge
- [x] 最终禁用后无 runtime autoload 残留

### 真实 ChatGPT Connector 回归

状态：**真实连接器验证通过**。

- [x] 真实 ChatGPT Connector 发现 119 tools
- [x] 编辑器读写完整闭环
- [x] Runtime Debugger live tree/property/method/pause/resume
- [x] Diagnostics stdout/stderr/exit code
- [x] Batch 顺序/stop-on-error/递归拒绝
- [x] Security boundaries
- [x] `REAL_CHATGPT_GODOT_MCP_0_4_TEST=PASS`

已解决 follow-up：Resource 非法路径已统一返回 `INVALID_PATH`，`node.create.parent_path` schema 已明确 `.` 表示编辑场景根节点。无法复现的 scene activation / transient network error 继续观察。

## 10. 当前 blocker

当前没有已知 release blocker。代码、集成、Credential、Runtime lifecycle、真实 Connector、仓库卫生和双语公开文档门禁均已通过。

## 11. 精确下一项任务

1. 提交一致的 0.4.0 基线；
2. 推送 `main`；
3. 开始独立的一键安装器 / Release 打包任务。
