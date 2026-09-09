# v0.4.0 发布记录

[English](DEVELOPMENT_0.4.md) | 简体中文

状态：**完成 / 已发布**
发布日期：**2026-09-10**
Release Tag：**`v0.4.0`**
Release 源码 Commit：**`f12d268b5bca087ae8cef744f9cb7ab8877848e8`**

本文是 v0.4.0 的**已关闭技术记录**，不再作为 WIP Tracker。

## 1. 版本目标

把早期 Tunnel 验证原型收口成一个可独立安装、可由 Web ChatGPT 直接使用的 Godot MCP 产品：

```text
Web ChatGPT
  ↓
OpenAI Secure MCP Tunnel
  ↓
内置官方 tunnel-client
  ↓
Godot loopback Streamable HTTP MCP
  ↓
Godot Editor / Runtime 工具层
```

## 2. 架构决定

v0.4.0 延续 0.3.0 已确定的生产架构：

- 不在 GDScript 中重新实现 OpenAI Tunnel wire protocol；
- 内置并启动官方 OpenAI `tunnel-client`；
- MCP Server 直接运行在 Godot 内部，仅监听 loopback；
- Godot Editor/Runtime 操作留在插件内；
- 给 ChatGPT 暴露直接的 MCP Tool Surface。

这套架构作为当前 Release 基线。

## 3. 已交付能力

v0.4.0 共 **119 个工具**：

| Family | 数量 |
| --- | ---: |
| godot | 1 |
| project | 13 |
| input_map | 6 |
| scene | 12 |
| node | 23 |
| script | 10 |
| resource | 8 |
| classdb | 9 |
| editor | 20 |
| debugger | 4 |
| runtime | 11 |
| diagnostics | 1 |
| batch | 1 |
| **合计** | **119** |

完整索引见 [工具参考](TOOL_REFERENCE.zh-CN.md)。

## 4. Credential 生命周期

Runtime API Key：

- 首次成功连接后保存到 Windows Credential Manager；
- 不写入 `project.godot`、EditorSettings、生成的 Tunnel Profile 或 Git；
- 重启 Godot 后可自动重连；
- 可以通过 **Forget Saved Credentials** 删除。

Tunnel ID 和 Key 使用本插件自己的 Namespace，不复用 CWapi 数据。

## 5. Runtime Debugger

v0.4.0 增加 Editor → Runtime Bridge：

```text
MCP Tool
  ↓
EditorPlugin
  ↓
EditorDebuggerPlugin / Session
  ↓
EngineDebugger Message Channel
  ↓
runtime_bridge.gd
  ↓
运行中 SceneTree
```

Release 已支持：

- Runtime Tree / Status；
- 节点检查/查找；
- 属性读写；
- 方法调用；
- Group；
- Performance；
- Pause / Resume；
- Debugger Session / Breakpoint / Profiler。

Runtime 修改只影响运行中实例；除非另有 Editor Tool 修改并保存项目，否则不会自动写回 Editor Scene。

## 6. Diagnostics 与 Batch

`diagnostics.run_capture`：

- 只允许启动当前 Godot executable + 当前项目；
- stdout / stderr 分开捕获；
- 返回 exit code、timeout、duration 和有上限输出；
- 不是通用 Shell MCP。

`batch.execute`：

- 顺序执行现有 MCP Tool；
- 最多 50 项；
- 支持 `stop_on_error`；
- 拒绝递归 Batch；
- 非事务，没有 rollback 保证。

## 7. 安装器与 Release 产物

v0.4.0 包含：

```text
godot-mcp-chatgpt-v0.4.0-windows-x64-installer.exe
godot-mcp-chatgpt-v0.4.0-addon.zip
SHA256SUMS.txt
```

安装器行为：

- 用户选择任意目标 `project.godot`；
- 没有用户/项目硬编码路径；
- 只安装到所选项目；
- 默认自动启用插件；
- 支持干净升级替换；
- 保留其他 EditorPlugin；
- 使用 Staging / Backup / Rollback；
- 成功后清理临时安装数据。

安装器验证过程中还修复了 Runtime Autoload 持久化：添加/移除后显式执行 `ProjectSettings.save()`。

## 8. 安全边界

Release 关键边界：

- 文件/Resource 只允许 `res://`；
- 拒绝路径穿越；
- 不允许删除当前编辑 Scene Root；
- 覆盖 Scene 需要显式允许；
- 本地 MCP 仅 loopback；
- Diagnostics 有边界；
- Batch 有边界且非事务；
- Windows Credential Manager 保存 Key；
- 不提供任意 Shell MCP。

详见 [安全](../SECURITY.zh-CN.md)。

## 9. 验证记录

实际通过：

```text
Godot 4.7.2 addon load/compile
npm build
npm test
CATALOGUE_SCHEMA_GATE=PASS tools=119
PRODUCTION_PLUGIN_SMOKE=PASS
REAL_CHATGPT_GODOT_MCP_0_4_TEST=PASS
RUNTIME_AUTOLOAD_LIFECYCLE_NODE_SMOKE=PASS
INSTALLER_CLEAN_INSTALL=PASS
INSTALLER_UPGRADE=PASS
INSTALLER_NO_ENABLE=PASS
INSTALLER_INVALID_PROJECT=PASS
INSTALLER_GODOT_4_7_2_LOAD=PASS
INSTALLER_SMOKE=PASS version=0.4.0
ADDON_ZIP_EXACT_CHECK=PASS files=46
SHA256SUMS_VERIFY=PASS
RELEASE_REMOTE_ASSET_VERIFY=PASS
BOM_CHECK=PASS
SECRET_CHECK=PASS real=0
LINK_CHECK=PASS
NO_IMAGE_MARKUP=PASS
```

## 10. 已解决 Follow-up

- 非法 Resource 源路径返回 `INVALID_PATH`；
- `node.create.parent_path` 明确 `.` 表示当前编辑场景根节点；
- Runtime Autoload 添加/删除会立即持久化；
- 一键安装器支持中文和空格项目路径；
- 安装器升级会清理旧 addon stale 文件，但不会删除其他插件。

## 11. 当前非阻塞限制

- 目前只打包/验证 Windows x64；
- Godot 4.7.2 是明确验证基线；
- 安装器没有代码签名；
- 0.4.0 不包含 Screenshot / Input / Frame Step Playtest；
- 真实回归中一次 Scene Activation 旧状态观察和一次 MCP 网络失败都无法复现。

## 12. 关闭状态

v0.4.0 **没有未解决 Release Blocker**。

后续工作统一进入 [开发计划](DEVELOPMENT_PLAN.zh-CN.md)，不再继续堆到这份已关闭版本记录中。