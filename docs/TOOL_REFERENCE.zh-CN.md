# 工具参考

[English](TOOL_REFERENCE.md) | 简体中文

**0.4.0** 共暴露 **119 个 MCP 工具**。本文是面向用户的索引；每次连接时 `tools/list` 返回的实时 JSON Schema 才是具体参数的最终权威。

## 核心约定

- 项目文件路径必须位于 `res://` 内；`res://../...` 等路径穿越会返回 `INVALID_PATH`。
- 编辑器场景中的节点路径相对于“当前编辑场景根节点”。根节点使用 `.`。特别是 `node.create.parent_path`：**不要填根节点名称，填 `.`**。
- Runtime 节点路径默认相对于运行中 `current_scene`。
- Runtime 工具支持可选 `session_id` 和 `timeout_ms`，可用于多个 Debugger Session 或自定义等待时间。
- `batch.execute` 有顺序、有上限，但**不是事务**；前面成功的操作不会因为后面失败而自动回滚。
- `diagnostics.run_capture` 只能启动当前 Godot executable + 当前项目，不是通用 Shell/任意进程执行工具。

## 运行目标与常见错误

调用 Tool 前先确认它操作的是哪一层：

| 目标 | 常见 Tool | 前提 | 是否写回项目 |
| --- | --- | --- | --- |
| Editor Project | `project.*`、`scene.*`、`node.*`、`script.*`、`resource.*` | Godot Editor/插件已加载 | 需要保存/持久化的操作通常会写回 |
| Editor 控制 | `editor.*` | Godot Editor/插件已加载 | 取决于操作 |
| Runtime | `runtime.*`、`debugger.*` | 有活动 Debugger/Runtime Session | 不会，除非另外调用 Editor Tool 持久化 |
| Diagnostics | `diagnostics.run_capture` | 当前 Godot executable/project | Runner 本身不修改项目 |
| Batch | `batch.execute` | 取决于内部 Tool | 取决于内部 Tool |

常见错误：

| Code | 含义 / 下一步 |
| --- | --- |
| `INVALID_PATH` | 路径越过 `res://` 或验证失败；改用项目内 `res://` 路径。 |
| `NODE_NOT_FOUND` | Editor/Runtime 节点路径找不到；先读取 SceneTree。 |
| `PROPERTY_NOT_FOUND` | 对象/类没有该属性；先 Inspect 或查 ClassDB。 |
| `METHOD_NOT_FOUND` | 对象/类没有该方法；先查 Methods/ClassDB。 |
| `RUNTIME_NOT_RUNNING` | 先启动 Scene/Project，并等待 Debugger Session。 |
| `RUNTIME_REQUEST_TIMEOUT` | Runtime 请求超时；检查 Session/运行状态。 |
| `ROOT_DELETE_DENIED` | 不允许删除当前编辑 Scene Root。 |
| `BATCH_RECURSION_DENIED` | `batch.execute` 不允许递归调用自己。 |
| `BATCH_TOO_LARGE` | 请求超过 Batch 上限；拆成更小批次。 |

修改型工作流建议先 Inspect，再明确保存。Runtime 状态和 Editor 保存状态是两套不同状态。
## Godot Variant 编码

JSON 本身没有 Vector3 等 Godot 类型，因此常用类型用带标签对象传递。例如：

```json
{
  "__godot_type": "Vector3",
  "x": 1,
  "y": 2,
  "z": 3
}
```

0.4.0 的公共 Variant codec 还覆盖多种 Vector/Transform/Color/NodePath、数组、字典、Resource 引用和对象摘要。

## 类别总览

| 类别 | 数量 | 主要能力 |
| --- | ---: | --- |
| Godot | 1 | 连接、编辑器和版本状态 |
| Project | 13 | 项目总览、文件、搜索、ProjectSettings、Autoload、插件 |
| InputMap | 6 | 输入 Action 与事件 |
| Scene | 12 | 场景创建、打开、检查、保存、重载、实例化和关闭 |
| Node | 23 | 节点属性、方法、Group、Metadata、Signal 与层级编辑 |
| Script | 10 | 脚本读写、解析、验证、挂载和 Script Editor 状态 |
| Resource | 8 | Resource 创建、检查、编辑、保存、复制和依赖 |
| ClassDB | 9 | 直接查询当前 Godot 版本的类、属性、方法、Signal、枚举和常量 |
| Editor | 20 | Selection、FileSystem、Script Editor、保存和运行控制 |
| Debugger | 4 | 调试 Session、断点和 Profiler |
| Runtime | 11 | 运行时 SceneTree、节点属性/方法、性能、暂停和恢复 |
| Diagnostics | 1 | 有边界启动 Godot 子进程并读取 stdout/stderr/exit/timeout |
| Batch | 1 | 有上限、按顺序的多工具执行 |

## 完整 119-tool 索引

### Godot (1)

连接、编辑器和版本状态。

- `godot.get_status`

### Project (13)

项目总览、文件、搜索、ProjectSettings、Autoload、插件。

- `project.delete_file`
- `project.find_files`
- `project.get_autoloads`
- `project.get_info`
- `project.get_plugins`
- `project.get_setting`
- `project.inspect`
- `project.list_directory`
- `project.list_settings`
- `project.make_directory`
- `project.move_file`
- `project.search_text`
- `project.set_setting`

### InputMap (6)

输入 Action 与事件。

- `input_map.add_action`
- `input_map.add_event`
- `input_map.clear_action_events`
- `input_map.get_action`
- `input_map.list`
- `input_map.remove_action`

### Scene (12)

场景创建、打开、检查、保存、重载、实例化和关闭。

- `scene.close`
- `scene.create`
- `scene.get_current`
- `scene.get_tree`
- `scene.get_unsaved`
- `scene.inspect`
- `scene.instantiate`
- `scene.list_open`
- `scene.open`
- `scene.reload`
- `scene.save`
- `scene.save_all`

### Node (23)

节点属性、方法、Group、Metadata、Signal 与层级编辑。

- `node.add_to_group`
- `node.call_method`
- `node.connect_signal`
- `node.create`
- `node.delete`
- `node.disconnect_signal`
- `node.duplicate`
- `node.find`
- `node.get_groups`
- `node.get_metadata`
- `node.get_methods`
- `node.get_properties`
- `node.get_property`
- `node.get_signal_connections`
- `node.get_signals`
- `node.inspect`
- `node.move_child`
- `node.remove_from_group`
- `node.remove_metadata`
- `node.rename`
- `node.reparent`
- `node.set_metadata`
- `node.set_property`

### Script (10)

脚本读写、解析、验证、挂载和 Script Editor 状态。

- `script.attach`
- `script.detach`
- `script.get_info`
- `script.get_unsaved`
- `script.list_open`
- `script.read`
- `script.reload_open`
- `script.save_all`
- `script.validate`
- `script.write`

### Resource (8)

Resource 创建、检查、编辑、保存、复制和依赖。

- `resource.call_method`
- `resource.create`
- `resource.duplicate`
- `resource.get_dependencies`
- `resource.get_property`
- `resource.inspect`
- `resource.save`
- `resource.set_property`

### ClassDB (9)

直接查询当前 Godot 版本的类、属性、方法、Signal、枚举和常量。

- `classdb.can_instantiate`
- `classdb.get_constants`
- `classdb.get_enums`
- `classdb.get_inheritance`
- `classdb.get_methods`
- `classdb.get_properties`
- `classdb.get_signals`
- `classdb.inspect`
- `classdb.search`

### Editor (20)

Selection、FileSystem、Script Editor、保存和运行控制。

- `editor.clear_selection`
- `editor.close_script`
- `editor.get_filesystem_state`
- `editor.get_playing_scene`
- `editor.get_script_state`
- `editor.get_selection`
- `editor.inspect`
- `editor.is_playing`
- `editor.open_script`
- `editor.reimport_files`
- `editor.run_current_scene`
- `editor.run_custom_scene`
- `editor.run_main_scene`
- `editor.run_project`
- `editor.save_all`
- `editor.scan_filesystem`
- `editor.select_file`
- `editor.set_selection`
- `editor.stop`
- `editor.stop_playing`

### Debugger (4)

调试 Session、断点和 Profiler。

- `debugger.get_breakpoints`
- `debugger.get_sessions`
- `debugger.set_breakpoint`
- `debugger.toggle_profiler`

### Runtime (11)

运行时 SceneTree、节点属性/方法、性能、暂停和恢复。

- `runtime.call_method`
- `runtime.find`
- `runtime.get_groups`
- `runtime.get_performance`
- `runtime.get_property`
- `runtime.get_tree`
- `runtime.inspect`
- `runtime.pause`
- `runtime.resume`
- `runtime.set_property`
- `runtime.status`

### Diagnostics (1)

有边界启动 Godot 子进程并读取 stdout/stderr/exit/timeout。

- `diagnostics.run_capture`

### Batch (1)

有上限、按顺序的多工具执行。

- `batch.execute`

## 重要使用方式

### 在场景根节点下创建节点

`node.create` 的根节点写法：

```json
{
  "parent_path": ".",
  "type": "CharacterBody3D",
  "name": "Player"
}
```

根节点名称本身不是“相对根节点的子路径”。真实 ChatGPT 回归中已经验证该约定。

### 先理解，再修改

面对陌生项目，推荐先调用：

```text
project.inspect
scene.inspect
node.inspect
script.get_info
classdb.inspect
```

这些聚合工具能显著减少 MCP 往返次数，也能避免 ChatGPT 依靠模型记忆去猜当前 Godot 版本 API。

### Runtime Debugger

典型流程：

```text
editor.run_current_scene
debugger.get_sessions
runtime.status
runtime.get_tree
runtime.get_property / runtime.set_property
runtime.call_method
runtime.get_performance
editor.stop_playing
```

真实 0.4.0 回归中，运行时 `Player.position` 被从 `(2,3,4)` 改成 `(7,8,9)`；停止运行后编辑器场景仍保持 `(2,3,4)`，证明 Runtime 修改没有误写回保存场景。

### Diagnostics

`diagnostics.run_capture` 分开返回 stdout、stderr、exit code、timeout、duration 和截断状态，适合让 ChatGPT 自己完成“运行 -> 看错误 -> 修复 -> 再运行”的闭环。

### Batch

`batch.execute` 可以顺序执行一组已有 MCP tools，支持 `stop_on_error`。递归调用 `batch.*` 会返回 `BATCH_RECURSION_DENIED`。

## 安全边界

0.4.0 已实际回归：

- `res://../...` 路径穿越拒绝；
- 项目外路径拒绝；
- Scene root 删除拒绝；
- 非法 Node class/property/method 拒绝；
- Resource 在 load/save 前执行 `res://` 路径检查；
- Diagnostics 子进程有 timeout 和输出上限；
- Batch 有数量/payload 上限并拒绝递归；
- 不提供通用任意 Shell MCP 工具。

## 真实验证

2026-09-10 使用真实 ChatGPT Connector 完整发现并调用 119 个工具，最终结果：

```text
REAL_CHATGPT_GODOT_MCP_0_4_TEST=PASS
```

更多见：[常用示例](EXAMPLES.zh-CN.md)、[快速上手](QUICKSTART.zh-CN.md)、[安全说明](../SECURITY.zh-CN.md)。
