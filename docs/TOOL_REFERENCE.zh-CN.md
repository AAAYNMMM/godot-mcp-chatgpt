# 工具参考

[English](TOOL_REFERENCE.md) | 简体中文

0.3.0 当前提供 13 个高频工具。工具面刻意保持精简：先把真实编辑器工作流做稳定，再扩展覆盖范围。

## 只读工具

### `godot.get_status`

参数：无。

返回当前 Godot 版本、是否处于编辑器环境、当前项目名。

示例：

```text
调用 godot.get_status，总结当前编辑器状态。
```

### `project.get_info`

参数：无。

返回：

- 项目名；
- `project.godot` 绝对路径；
- 当前编辑场景路径（如果有）。

### `scene.get_tree`

参数：

| 名称 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `max_depth` | integer | 否 | 0-32，默认 8 |

返回当前编辑场景树，包括节点名、类名和相对路径。

### `script.read`

参数：

| 名称 | 类型 | 必填 |
| --- | --- | --- |
| `path` | string | 是 |

`path` 必须位于 `res://` 内，不能包含 `..` 路径穿越。

示例：

```text
读取 res://player/player.gd，并说明它现在做什么。
```

## 场景工具

### `scene.create`

创建、保存并在编辑器中打开新的 `.tscn` 场景。

参数：

| 名称 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `path` | string | 是 | 必须是 `res://...tscn` |
| `root_type` | string | 否 | 根节点 Godot 类型 |
| `root_name` | string | 否 | 可选根节点名 |
| `overwrite` | boolean | 否 | 默认 false |

安全行为：已有场景默认不会被覆盖，只有显式传 `overwrite: true` 才允许替换。

示例：

```text
创建 res://prototype/test.tscn，根节点 Node3D，名字 TestRoot，不要覆盖已有文件。
```

### `scene.save`

参数：

| 名称 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `path` | string | 否 | 可选的新 `res://...tscn` 路径 |

不传 `path` 时，保存当前编辑场景到原路径。

## 节点工具

### `node.create`

参数：

| 名称 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `type` | string | 是 | Godot 类名，例如 `Node3D` |
| `parent_path` | string | 否 | 相对场景根节点；`.` 表示根节点 |
| `name` | string | 否 | 可选节点名 |

示例：

```text
在场景根节点下添加一个名为 Player 的 CharacterBody3D。
```

### `node.set_property`

参数：

| 名称 | 类型 | 必填 |
| --- | --- | --- |
| `node_path` | string | 是 |
| `property` | string | 是 |
| `value` | 任意可映射 JSON 值 | 是 |

常见 Godot 类型可以使用带类型标记的对象。例如 Vector3：

```json
{
  "__godot_type": "Vector3",
  "x": 1,
  "y": 2,
  "z": 3
}
```

示例：

```text
把 Player.position 设置为 Vector3(1, 2, 3)。
```

### `node.delete`

参数：

| 名称 | 类型 | 必填 |
| --- | --- | --- |
| `node_path` | string | 是 |

不能通过这个工具删除当前编辑场景的根节点。

## 脚本工具

### `script.write`

参数：

| 名称 | 类型 | 必填 |
| --- | --- | --- |
| `path` | string | 是 |
| `content` | string | 是 |

写入 `res://` 内的 UTF-8 文本文件。

示例：

```text
新建 res://player/player.gd，写一个包含 exported move_speed float 的 GDScript，不要改其他文件。
```

### `script.attach`

参数：

| 名称 | 类型 | 必填 |
| --- | --- | --- |
| `node_path` | string | 是 |
| `script_path` | string | 是 |

把已有 `res://` Script 资源挂载到当前编辑场景中的节点。

## 编辑器工具

### `editor.run_project`

参数：无。

通过 Godot 编辑器 API 运行项目主场景。

### `editor.stop`

参数：无。

停止当前运行中的项目或场景。

## 推荐的提问方式

更推荐描述最终结果和约束：

```text
在 res://prototype/ 下创建一个一次性测试场景。
根节点用 Node3D，添加 Player 节点；新建并挂载一个 move_speed = 5.0 的简单 GDScript。
保存场景，不要覆盖任何已有文件。
```

除非你在调试 MCP 工具层，否则不需要人工逐条指定 RPC。

## 当前限制

0.3.0 还没有专门工具覆盖：

- 打开任意已有场景；
- 丰富的属性枚举；
- Resource / Material；
- InputMap；
- Signal；
- ClassDB；
- 编辑器/运行时错误日志；
- 截图；
- 任意 Shell 命令。

后续计划见：[开发计划](DEVELOPMENT_PLAN.zh-CN.md)。