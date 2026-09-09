# 开发进度 / 新窗口交接

[English](PROGRESS.md) | 简体中文

最后更新：2026-09-09

仓库：`AAAYNMMM/godot-mcp-chatgpt`

分支：`main`

当前版本候选：`0.3.0`

0.3.0 核心实现提交：

```text
2a70cd1ed084df0d2ee5fff7c596c5ff5a3e93d8
```

## 当前架构 — 新窗口必须先看

生产链路：

```text
Web ChatGPT
 -> OpenAI Secure MCP Tunnel
 -> 插件内置官方 OpenAI tunnel-client.exe
 -> Godot loopback Streamable HTTP MCP
 -> Godot CommandRegistry
 -> Godot Editor API
```

旧版 GDScript `/poll` + `/response` 直连实现已经废弃并从生产代码删除。

原因：旧实现能在本地 simulator 里通过，也能显示 connected，但真实 ChatGPT 连接器创建失败。只读检查 CWapi 后确认，CWapi 真正可用的方式是**官方 tunnel-client + localhost Streamable HTTP MCP**。0.3.0 已采用同样设计思想，而且真实 ChatGPT 连接器已经创建成功。

除非出现新的明确证据并重新做架构决策，否则不要恢复旧直连实现。

## 当前用户体验

Godot 底部面板：

```text
MCP ChatGPT
```

用户只输入：

```text
Tunnel ID
Runtime API Key
```

点 Connect 后插件自动：

1. 在 `127.0.0.1` 启动随机端口 MCP Server；
2. 生成随机 MCP 路径；
3. 生成 tunnel-client profile；
4. profile 使用 `env:CONTROL_PLANE_API_KEY`；
5. 启动内置官方 tunnel-client；
6. 子进程启动后清除 Godot 父进程环境中的 key；
7. Disconnect 时清理本地 MCP 和子进程。

插件只持久化 Tunnel ID，不持久化 Runtime API Key。

## 内置官方运行时

```text
addons/godot_mcp_chatgpt/bin/windows/tunnel-client.exe
```

版本：

```text
0.0.10+105e17a79a36e4e5c897fd698ed2b8dbf935b144
```

SHA-256：

```text
D893D8127EEE35070D265C1BE29BFE008F8D9FCB476E7FEBF56C8FDC6C0615C8
```

Apache-2.0 LICENSE 和 NOTICE 已放进 `addons/godot_mcp_chatgpt/bin/`。

## 当前 13 个 Godot 工具

```text
godot.get_status
project.get_info
scene.get_tree
scene.create
scene.save
node.create
node.set_property
node.delete
script.read
script.write
script.attach
editor.run_project
editor.stop
```

## 关键文件

```text
addons/godot_mcp_chatgpt/plugin.gd
addons/godot_mcp_chatgpt/ui/connection_dock.gd
addons/godot_mcp_chatgpt/web/tunnel_client_runner.gd
addons/godot_mcp_chatgpt/web/local_mcp_server.gd
addons/godot_mcp_chatgpt/core/command_registry.gd
addons/godot_mcp_chatgpt/core/builtin_commands.gd
```

开发测试桩：

```text
server/
```

## 已完成的验证

### Godot 4.7.2 编译

所有插件 GDScript 在 Godot 4.7.2 下强制加载成功。

### Godot 本地 MCP

已经验证：

```text
server/discover
initialize
tools/list
tools/call
```

### Go MCP SDK 1.7

真实 `github.com/modelcontextprotocol/go-sdk v1.7.0` 客户端成功连接 Godot loopback MCP，并完成工具发现/调用。

```text
GO_SDK_SMOKE_OK
```

### 官方 tunnel-client bridge

使用与工作中的 CWapi 相同官方 tunnel-client，经过本地 control-plane stub 转发到 Godot MCP：

```text
OFFICIAL_TUNNEL_BRIDGE=PASS
```

### Production plugin smoke

真实 Godot 4.7.2 GUI + 内置官方 tunnel-client + 13 个真实工具：

```text
PRODUCTION_PLUGIN_SMOKE=PASS
```

Smoke 覆盖：

```text
server/discover
initialize
notifications/initialized
tools/list
godot.get_status
scene.create
node.create
node.set_property
script.write
script.read
script.attach
scene.save
scene.get_tree
session termination
```

测试创建一次性场景，并验证 `Player.position == Vector3(4, 5, 6)`。

## 真实 ChatGPT 连接器验证

**状态：成功 — 2026-09-09。**

用户使用真实 OpenAI Tunnel ID / Runtime API Key，在生产 0.3.0 架构下成功创建 ChatGPT 连接器。

验证链路：

```text
Godot 4.7.2
 -> 内置官方 OpenAI tunnel-client
 -> OpenAI Secure MCP Tunnel
 -> ChatGPT connector creation
 -> SUCCESS
```

这已经是当前 known-good baseline。未来出现连接问题时，优先对照这条基线排查，不要直接重写 Transport。

## 当前阻塞

连接器创建没有阻塞。

下一阶段主要是：

- 通过真实连接器继续调用 `godot.get_status` 和一次性场景写入；
- 根据真实使用体验调整工具接口；
- 扩展高价值工具；
- 做干净 Windows 发布包。

## 下一步

1. 真实 ChatGPT 连接器调用 `godot.get_status`；
2. 通过真实连接器创建一次性可见场景/节点；
3. 记录工具易用性问题；
4. Phase 6 从属性读取、scene open/close 开始；
5. 准备首个用户友好的 Windows release ZIP 和 release notes。

## 双语文档重构

真实连接器验证成功后，于 2026-09-09 完成。

用户文档已经从“开发过程记录”改成以第一次使用体验为中心，目前中英双语覆盖：

```text
README
快速上手
常用示例
工具参考
FAQ / 排错
架构
Secure Tunnel 设置
开发计划
开发进度 / 交接
贡献指南
安全说明
更新日志
```

后续文档规则：

- 面向用户的文档尽量保持英文 + 简体中文；
- 使用 `NAME.md` / `NAME.zh-CN.md` 配对；
- README 聚焦项目价值、安装连接、真实验证和清晰限制；
- 除非仓库策略明确改变，否则不添加图片、截图、徽章或 GIF；
- 真实测试和仿真测试必须明确区分，不夸大验证范围。
## 仓库/工作区规则

- 本项目只操作 `AAAYNMMM/godot-mcp-chatgpt`；
- 不修改 CWapi；之前只读检查它来确认可用 Tunnel 架构；
- Godot 当前开发目标：Windows + Godot 4.7.2 Standard + GDScript；
- 每个有实质进展的新窗口都要同步更新中英文进度文档。
## 0.4.0 完全体开发 — 当前工作区

状态更新时间：2026-09-09。

当前追踪：[`DEVELOPMENT_0.4.zh-CN.md`](DEVELOPMENT_0.4.zh-CN.md)

开发流程：[`DEVELOPMENT_WORKFLOW.zh-CN.md`](DEVELOPMENT_WORKFLOW.zh-CN.md)

公开已验证基线仍然是 **0.3.0**。以下 0.4.0 能力存在于持久工作区，**尚未**升级到公开 Tool Reference，也没有作为已验证 release 基线推送。

### Task：Windows Credential Manager 持久化

状态：**targeted validation passed；集成/重启验证待完成**。

文件 / 模块：

```text
tools/credential-helper/
addons/godot_mcp_chatgpt/bin/windows/godot-mcp-credential.exe
addons/godot_mcp_chatgpt/web/credential_store.gd
addons/godot_mcp_chatgpt/web/tunnel_client_runner.gd
addons/godot_mcp_chatgpt/ui/connection_dock.gd
```

完成内容：

- 只读检查 CWapi，确认 Runtime API Key 使用 Windows Credential Manager Generic Credential；
- 使用相同 Windows 存储机制，但采用独立 `godot-mcp-chatgpt/...` Credential Target；
- tunnel profile 继续只写 `api_key: env:CONTROL_PLANE_API_KEY`；
- 增加保存凭据存在/读/写/删除和 Forget Saved Credentials；
- 准备通过保存的 Tunnel ID + Credential Manager API Key 自动重连。

实际验证：

- helper 隔离 `write -> present -> read -> delete -> present` round trip；
- 读取值和测试 secret 一致；
- 测试 Credential 验证后已删除；
- Godot 4.7.2 成功加载 `credential_store.gd` 和修改后的凭据相关插件脚本。

结果：凭据存储专项验证通过。

已知限制 / blocker：尚未执行“关闭 Godot -> 重启 -> 自动连接”和“Forget -> 重启 -> 要求重新输入”的生产 smoke。

### Task：Project / ProjectSettings / InputMap 能力模块

状态：**targeted validation passed**。

文件 / 模块：

```text
addons/godot_mcp_chatgpt/core/command_utils.gd
addons/godot_mcp_chatgpt/commands/project_commands.gd
```

完成内容：项目总览/发现/搜索、ProjectSettings、Autoload/Plugin 发现、项目范围文件操作和 InputMap 操作。

实际验证：Godot 4.7.2 加载公共 command utility 和 Project 命令模块，无 parse/compile error。

结果：模块编译通过。仍待生产 registry 集成。

### Task：Scene / Node 能力模块

状态：**targeted validation passed**。

文件 / 模块：

```text
addons/godot_mcp_chatgpt/commands/scene_node_commands.gd
```

完成内容：Scene 生命周期/聚合读取，以及更完整的 Node inspect/mutation、Group、Signal、Metadata 操作。

实际验证：修正 Godot 4.7 严格类型/作用域问题后，Godot 4.7.2 成功加载最终模块，无 parse/compile error。

结果：模块编译通过。仍待生产 registry 集成和 GUI 行为 smoke。

### Task：Script / Resource 能力模块

状态：**targeted validation passed**。

文件 / 模块：

```text
addons/godot_mcp_chatgpt/commands/script_resource_commands.gd
```

完成内容：Script 自省/验证/编辑器状态辅助，以及 Resource inspect/get/set/create/save/duplicate/dependencies/call。

实际验证：Godot 4.7.2 成功加载重写后的模块，无 parse/compile error。

结果：模块编译通过。仍需代表性真实 Resource 修改集成 smoke。

### Task：ClassDB 自省模块

状态：**targeted validation passed**。

文件 / 模块：

```text
addons/godot_mcp_chatgpt/commands/classdb_commands.gd
```

完成内容：当前 Godot 引擎 ClassDB search/inspect/properties/methods/signals/enums/constants/inheritance/can-instantiate。

实际验证：修正保留标识符问题后，Godot 4.7.2 成功加载模块，无 parse/compile error。

结果：模块编译通过。

### Task：开发文档体系完善

状态：**complete**。

文件 / 模块：

```text
docs/DEVELOPMENT_WORKFLOW.md
docs/DEVELOPMENT_WORKFLOW.zh-CN.md
docs/DEVELOPMENT_0.4.md
docs/DEVELOPMENT_0.4.zh-CN.md
docs/DEVELOPMENT_PLAN.md
docs/DEVELOPMENT_PLAN.zh-CN.md
docs/PROGRESS.md
docs/PROGRESS.zh-CN.md
CONTRIBUTING.md
CONTRIBUTING.zh-CN.md
```

完成内容：

- 明确 README、Tool Reference、Changelog、Development Plan、版本追踪和 Progress 各自的事实边界；
- 将进度文档写入 Definition of Done；
- 强制每完成一个逻辑独立任务后，先更新 Progress + 当前版本 tracker，再进入下一项；
- 统一开发状态词和验证证据要求；
- 新增 0.4.0 完全体 checklist 和 release gates；
- 真实登记当前未提交 0.4.0 工作区状态，不提前污染公开 0.3.0 Tool Reference。

实际验证：`PAIR_CHECK=PASS`、`LINK_CHECK=PASS`、`LITERAL_NEWLINE_CHECK=PASS`、`DOC_BOM_CHECK=PASS`、`DOC_DIFF_CHECK=PASS`。

结果：开发进度管理已经形成强制逐任务更新规则。

### Task：Editor 状态/控制模块

状态：**targeted validation passed**。

文件 / 模块：

```text
addons/godot_mcp_chatgpt/commands/editor_commands.gd
```

完成内容：新增 Editor 聚合状态、场景节点选择读取/设置/清空、filesystem 扫描/导入状态与控制、FileSystem 选择、Script Editor 状态/打开/关闭、play 状态、运行 main/current/custom scene、停止运行以及 save-all。为了验证真实 EditorPlugin 上下文，该模块已经接入 0.4 WIP 插件。

实际验证：

- Godot 4.7.2 成功加载注册 EditorCommands 后的完整插件；
- 真实 Godot GUI + 内置官方 tunnel-client + 本地 control-plane smoke 发现 31 个工具；
- `editor.inspect`、`editor.get_filesystem_state`、`editor.get_script_state` 返回真实 Editor 状态；
- `editor.set_selection` 成功选择生成的 Player 节点，`editor.clear_selection` 成功清空；
- `editor.run_current_scene` 进入 playing，`editor.get_playing_scene` 确认运行状态，`editor.stop_playing` 成功停止；
- 结果：`PRODUCTION_PLUGIN_SMOKE=PASS`。

同时在真实插件 smoke 前清除了此前登记的 WIP `plugin.cfg` UTF-8 BOM；release gate 仍需执行全仓库 BOM 扫描。

### Task：Runtime / Debugger Bridge

状态：**targeted validation passed**。

文件 / 模块：

```text
addons/godot_mcp_chatgpt/debug/editor_debugger_bridge.gd
addons/godot_mcp_chatgpt/debug/runtime_debugger_manager.gd
addons/godot_mcp_chatgpt/runtime/runtime_bridge.gd
addons/godot_mcp_chatgpt/commands/runtime_debugger_commands.gd
```

完成内容：使用 Godot 自身 Debugger 通道打通 EditorPlugin 与运行中游戏，不新增第二个网络监听端口。Runtime 工具覆盖 status/tree/inspect/find/property 读写/method call/groups/performance/pause-resume；Debugger 工具覆盖 session、断点和 profiler 控制。Runtime 请求支持可选 `session_id` 和有边界的 `timeout_ms`。

实际验证：

- 4 个 Runtime/Debugger 模块全部通过 Godot 4.7.2 加载；
- 0.4 WIP 生产插件成功注册 DebuggerPlugin 和 runtime bridge；
- 真实 Editor 以 `--remote-debug tcp://127.0.0.1:...` 启动一次性测试场景；
- runtime bridge 通过 EngineDebugger Channel 向 Editor 发送 ready；
- official tunnel production smoke 发现 46 个工具；
- `runtime.status` 返回真实运行 Scene 和 node count；
- `runtime.get_tree` 返回 SecureRoot -> Player；
- `runtime.get_property` 读到 Player.position=(4,5,6)；
- `runtime.set_property` 把 live Player.position 改成 (7,8,9) 并读回新值；
- `runtime.call_method` 成功在 live root 调用 `get_child_count`；
- `runtime.get_performance`、`runtime.pause`、`runtime.resume` 均成功；
- `debugger.get_sessions` 返回 active session；
- 移除临时诊断 print 后最终结果仍为 `PRODUCTION_PLUGIN_SMOKE=PASS`。

结果：Runtime/Debugger 闭环已经通过和生产相同的官方 tunnel-client 路径。

### Task：捕获运行诊断

状态：**targeted validation passed**。

文件 / 模块：

```text
addons/godot_mcp_chatgpt/commands/diagnostics_commands.gd
tools/run-helper/main.go
addons/godot_mcp_chatgpt/bin/windows/godot-mcp-runner.exe
```

完成内容：新增有边界的 `diagnostics.run_capture`。它只启动当前 Godot executable + 当前项目 + 可选 `res://` Scene，不提供任意 shell/executable MCP 能力；通过独立 Windows helper 分离捕获 stdout/stderr，并返回 exit code、timeout、duration 和截断状态。

实际验证：官方 tunnel-client production smoke 发现 47 个 tools；正常测试场景捕获 `CAPTURE_STDOUT_OK` 且 exit code 0；错误场景通过 `push_error` 捕获 stderr 并返回 exit code 7；阻塞场景在 300ms timeout 后被 helper 强制终止并返回 `timed_out=true` / exit code -1。最终结果：`PRODUCTION_PLUGIN_SMOKE=PASS`。

结果：captured-run diagnostics 已形成真实 stdout/stderr/exit/timeout 闭环，不依赖虚假读取 Output Dock。

### Task：Batch 操作

状态：**targeted validation passed**。

文件 / 模块：

```text
addons/godot_mcp_chatgpt/commands/batch_commands.gd
```

完成内容：新增非事务的 `batch.execute`，最多 50 项，顺序执行现有 MCP tools，返回逐项结果，支持 `stop_on_error`，限制总 payload，并拒绝任何 `batch.*` 递归调用。

实际验证：Godot 4.7.2 编译通过；official tunnel production smoke 发现 48 个 tools；成功顺序执行 `godot.get_status` + `project.get_info`；中间未知工具时正确 stop-on-error；递归调用返回 `BATCH_RECURSION_DENIED`；51 项请求返回 `BATCH_TOO_LARGE`；最终 `PRODUCTION_PLUGIN_SMOKE=PASS`。

结果：Batch 模块专项验证通过，明确为非原子操作，不承诺 rollback。

### Task：0.4.0 统一注册与全功能代表性集成

状态：**integration passed**。

完成内容：将 Project / InputMap / Scene / Node / Script / Resource / ClassDB / Editor / Debugger / Runtime / Diagnostics / Batch 全部接入生产 CommandRegistry；CommandRegistry 增加重复工具名显式拒绝；修复 editor scene root 不在 SceneTree 时的安全摘要；修复 `script.get_info` 对刚写入 GDScript 的缓存陈旧问题；`project.set_setting(name, null)` 现在提供明确删除语义。

实际验证：Godot 4.7.2 全插件编译通过；bundled official tunnel-client production smoke 发现 **119 tools**；`CATALOGUE_SCHEMA_GATE=PASS tools=119`，全量验证工具名唯一、命名格式、description、递归 inputSchema、required、`additionalProperties=false`、`readOnlyHint`、`destructiveHint`。代表性真实行为覆盖 Project/Settings/file search+move+delete、InputMap、Scene lifecycle/inspect、Node property/method/group/metadata/duplicate/rename、Script introspection/validate/detach、Signal connect/disconnect、Resource create/get/set/duplicate/save/dependencies/call、ClassDB、Editor、Runtime、Diagnostics、Batch。测试临时 InputMap action 和 ProjectSetting 会自清理。最终 `PRODUCTION_PLUGIN_SMOKE=PASS`，Godot stderr 无 MCP 脚本错误。

结果：119-tool 0.4.0 功能面已经形成统一生产注册和代表性行为基线；尚不能发布，仍需 Credential 跨重启/Forget、autoload 清理、仓库 release gates 和真实 ChatGPT 0.4 回归。

### 任务：凭据跨重启生命周期

状态：**集成验证通过**。

已在 Windows 上使用隔离的 `godot-mcp-chatgpt/test/...` Credential Manager target 和隔离 Godot APPDATA 真实验证：

- 首次连接成功保存 Runtime API Key 与 Tunnel ID；
- 全新 Godot 进程在不提供 API Key 环境变量的情况下，从 Credential Manager 读取已保存 Key 并自动连接；
- Forget 流程删除已保存 Key 与 Tunnel ID；
- 再次重启后不再自动连接，回到等待/需要凭据状态；
- 结果：`CREDENTIAL_RESTART_SMOKE=PASS`。

该测试没有触碰生产 Credential Manager target。

### 任务：Runtime autoload 生命周期与插件清理

状态：**集成验证通过**。

完成内容：RuntimeDebuggerManager 在插件禁用时会移除其保留的 runtime autoload；autoload 冲突检查提前到 debugger plugin 注册之前；同时兼容 Godot 4.7.2 将 autoload 正规化为 `uid://` 的情况，只要 UID 最终解析到本插件的 runtime bridge 就视为匹配。

已在真实 Godot 4.7.2 headless editor 中通过临时测试 EditorPlugin 验证：

- 目标插件启用 -> runtime autoload 正确解析到 `runtime_bridge.gd`；
- 禁用 -> autoload 被移除；
- 重新启用 -> Godot 将 autoload 写成 `uid://...`，manager 正确识别并恢复 runtime autoload；
- 再次禁用 -> autoload 再次被清理；
- 结果：`RUNTIME_AUTOLOAD_LIFECYCLE_SMOKE=PASS`。

### 任务：真实 ChatGPT Connector 0.4.0 全能力回归

状态：**真实连接器验证通过**。

2026-09-10 在真实 ChatGPT 新会话中，通过用户实际创建的 Connector 对当前 Godot 4.7.2 编辑器进行了完整 MCP 回归。Connector 暴露 **119 个工具**，并真实验证 Project、ClassDB、Scene、Node、Groups/Metadata、Script、Signals、Resource、ProjectSettings、InputMap、Editor、Debugger/Runtime、Diagnostics、Batch 与安全边界。

关键结果：

- `REAL_CHATGPT_GODOT_MCP_0_4_TEST=PASS`；
- Runtime 中将 Player.position 从 Vector3(2,3,4) 改为 Vector3(7,8,9)，读回一致；停止运行后编辑器场景仍为 Vector3(2,3,4)，证明 runtime 修改未误写回编辑器场景；
- `runtime.call_method` 实测 `Player.add_values(12, 30) = 42`；
- Diagnostics 正常场景 exit code 0，错误场景精确捕获 `MCP_REAL_ERROR_TEST` 且 exit code 7；
- Batch 顺序执行、stop_on_error 和 `BATCH_RECURSION_DENIED` 均通过；
- 路径穿越、项目外路径、Scene root 删除、非法 class/property/method 均被拒绝；
- 测试结束后 ProjectSetting / InputMap 临时项均已清理，未修改插件目录、API Key、Tunnel ID 或 Windows Credential Manager。

非阻塞 follow-up：

1. 已解决：所有 Resource 源路径在 load 前统一校验；`res://../outside.tres` 现在返回 `INVALID_PATH`，并已加入 production smoke；
2. 已解决：`node.create.parent_path` MCP schema 已明确 `.` 表示编辑场景根节点，不应填写根节点名称；
3. 一次 `scene.create` 后短暂看到旧场景、一次 `mcp_network_error` 均无法稳定复现，继续作为观察项，不作为 0.4.0 blocker。
### 任务：0.4.0 最终 release gates 与公开文档晋级

状态：**release 验证通过**。

真实 Connector 回归和 follow-up 修复完成后，最终实际执行：

```text
Godot 4.7.2 addon load: PASS
Go helper gofmt/build/test: PASS
CREDENTIAL_HELPER_FINAL=PASS
npm build: PASS
npm test: PASS
CATALOGUE_SCHEMA_GATE=PASS tools=119
PRODUCTION_PLUGIN_SMOKE=PASS
Resource traversal -> INVALID_PATH regression: PASS
node.create parent_path schema guidance regression: PASS
BOM_CHECK=PASS
LITERAL_NEWLINE_CHECK=PASS
SECRET_CHECK=PASS real=0
TOOL_REFERENCE_COVERAGE=PASS tools=119
LINK_CHECK=PASS
NO_IMAGE_MARKUP=PASS
VERSION_CHECK=PASS 0.4.0
git diff --check: PASS
TEST_ARTIFACT_HYGIENE=PASS
```

公开双语文档已晋级 0.4.0：README、Tool Reference、Quick Start、FAQ、Architecture、Secure Tunnel、Security、Development Plan、Changelog。真实 Connector 产生的 6 个测试资产继续保留在本地忽略目录 `res://.mcp-real-test/`，供用户肉眼检查，不会进入 Git。

### 任务：0.4.0 提交与推送

状态：**完成**。

- 发布基线提交：`3f8ce7e` (`release: complete 0.4.0 Godot MCP surface`)；
- 已推送到 `origin/main`；
- 0.4.0 真实 Connector、119-tool、Credential、Runtime、Diagnostics、Batch 与 release gates 均保持通过；
- 按用户要求，一键安装器 / Release 打包任务暂不开始。

### 任务：Windows 项目级一键安装器

状态：**集成验证通过**。

已在 `tools/installer/` 实现可分发的 Windows x64 单文件安装器。安装器内嵌完整 `addons/godot_mcp_chatgpt/`，用户只需选择目标项目的 `project.godot`；安装目标固定为该项目自己的 `addons/godot_mcp_chatgpt/`，默认自动启用编辑器插件，支持升级替换、旧版本备份/失败回滚，不包含任何用户或机器硬编码路径。同一构建脚本还会生成可手动解压的 addon ZIP 和 SHA-256 校验文件。

干净项目验证过程中发现了一个真实外部项目问题：Godot 4.7.2 的 `add_autoload_singleton()` 会让 Runtime bridge 在当前 Editor 会话中生效，但不会立即可靠写回磁盘。现在 `RuntimeDebuggerManager` 在添加/删除保留 autoload 后显式调用 `ProjectSettings.save()`，保存失败会明确返回/警告，不再依赖 Godot 之后某个时机自动持久化。

已使用包含空格和中文的项目路径真实验证：

```text
INSTALLER_CLEAN_INSTALL=PASS
INSTALLER_UPGRADE=PASS
INSTALLER_NO_ENABLE=PASS
INSTALLER_INVALID_PROJECT=PASS
INSTALLER_GODOT_4_7_2_LOAD=PASS
RUNTIME_AUTOLOAD_LIFECYCLE_NODE_SMOKE=PASS
INSTALLER_SMOKE=PASS version=0.4.0
```

升级回归同时确认：不会删除其他 EditorPlugin、旧版 `godot_mcp_chatgpt` 内的 stale 文件会被清除、不会重复添加插件 entry、`project.godot` 的 CRLF 会保留、临时安装/备份目录会清理干净。 公开安装说明也已同步到 README、Quick Start、CHANGELOG、SECURITY，并明确未签名/SmartScreen 提示及 SHA-256 校验方式。
### 任务：安装器提交前 Release 门禁

状态：**release 验证通过**。

安装器、Runtime autoload 持久化修复、公开文档和 payload 全文件哈希回归完成后的最终提交前结果：

```text
npm build: PASS
npm test: PASS
CATALOGUE_SCHEMA_GATE=PASS tools=119
PRODUCTION_PLUGIN_SMOKE=PASS
RUNTIME_AUTOLOAD_LIFECYCLE_NODE_SMOKE=PASS
INSTALLER_SMOKE=PASS version=0.4.0
installed addon full file-set/SHA-256 match: PASS
DIFF_CHECK=PASS
BOM_CHECK=PASS
INSTALLER_HARDCODE_CHECK=PASS
LINK_CHECK=PASS
NO_IMAGE_MARKUP=PASS
SECRET_CHECK=PASS fixtures=3 real=0
VERSION_CHECK=PASS 0.4.0
ARTIFACT_HYGIENE=PASS
INSTALLER_PRECOMMIT_GATES=PASS
```

### 任务：GitHub Release v0.4.0 发布

状态：**完成**。

已发布经过验证的 Windows 正式版本：https://github.com/AAAYNMMM/godot-mcp-chatgpt/releases/tag/v0.4.0

Release 源与 tag：

- 源 commit：`f12d268b5bca087ae8cef744f9cb7ab8877848e8`；
- 远端 tag `v0.4.0` 指向同一 commit；
- Release 不是 draft，也不是 prerelease。

上传资产：

```text
godot-mcp-chatgpt-v0.4.0-windows-x64-installer.exe
godot-mcp-chatgpt-v0.4.0-addon.zip
SHA256SUMS.txt
```

最终基于 commit 的产物验证：

```text
BUILD_COMMIT_CHECK=PASS f12d268b5bca
INSTALLER_SMOKE=PASS version=0.4.0
ADDON_ZIP_EXACT_CHECK=PASS files=46
SHA256SUMS_VERIFY=PASS
RELEASE_REMOTE_ASSET_VERIFY=PASS
```

上传后又从 GitHub Release 重新下载三个资产，并逐个比较 SHA-256；线上文件与本地已验证产物完全一致。

## 0.4.0 当前 blocker

当前没有已知 0.4.0 release blocker。安装器源码已进入 `main`，`v0.4.0` tag 指向经过验证的安装器 commit，GitHub Release 资产也已经远程重新下载并完成哈希复核。

## 0.4.0 精确下一项任务

**0.4.0 已发布。等待用户指定下一项开发任务。**
