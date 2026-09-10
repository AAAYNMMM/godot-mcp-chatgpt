# 工具参考

[English](TOOL_REFERENCE.md) | 简体中文

**0.5.0** 默认公开 **47 个 MCP Tools**，后端保留 **230 个 Internal Atomic Commands**。具体参数、Managed Operation Enum 和 Annotation 以每次连接的实时 `tools/list` JSON Schema 为最终权威。

## Compact Surface 模型

v0.5 把 Public MCP Catalogue 与 Internal Atomic Command Registry 分层：

- **31 个 Direct Tools** 覆盖最高频 Inspect/Edit/Run/Test 路径；
- **16 个 `*.manage` Tools** 通过有边界的 `op` Enum + `params` 承载长尾操作；
- 每个 Internal Atomic Command 至少有一个 Public Route；
- 默认 Public 数量 47；启用的第三方 Custom Tool 最多额外 Promote 2 个，硬上限仍低于 50；
- 硬编码 v0.4 119 个扁平 Public Tool Name 的调用方需要迁移到 v0.5 Compact Surface。

调用 `*.manage` 时，从实时 Schema 提供的 `op` 中选择操作；Server 会再用对应 Atomic Command 自己的 Schema 校验 `params`。

## 核心约定

- Project 文件路径必须位于 `res://` 内，拒绝 `res://../...` 等路径穿越；
- Editor Scene 节点路径相对于当前编辑场景根节点，根节点使用 `.`；
- Runtime 节点路径默认相对于 Live Current Scene；
- 支持的 Runtime 操作可带 `session_id` / `timeout_ms`；
- `batch.execute` 有边界但 Non-Atomic；
- `batch.execute_transaction` 只对被分类为可逆的操作声明 rollback；
- `diagnostics.run_capture` 只启动当前 Godot executable + 当前项目，不是 Arbitrary Shell；
- Screenshot 返回有边界 MCP image content；
- Custom Tool 必须属于 Addon、通过 Schema 校验、显式声明安全属性，并默认禁用。

## Public Direct Tools（31）

| Tool | 角色 |
| --- | --- |
| `godot.get_status` | 高频 Direct Operation |
| `project.inspect` | 高频 Direct Operation |
| `project.search_text` | 高频 Direct Operation |
| `scene.get_current` | 高频 Direct Operation |
| `scene.get_tree` | 高频 Direct Operation |
| `scene.open` | 高频 Direct Operation |
| `scene.save` | 高频 Direct Operation |
| `node.create` | 高频 Direct Operation |
| `node.find` | 高频 Direct Operation |
| `node.get_properties` | 高频 Direct Operation |
| `node.set_property` | 高频 Direct Operation |
| `script.read` | 高频 Direct Operation |
| `script.write` | 高频 Direct Operation |
| `script.patch` | 高频 Direct Operation |
| `script.validate` | 高频 Direct Operation |
| `script.attach` | 高频 Direct Operation |
| `classdb.search` | 高频 Direct Operation |
| `editor.take_screenshot` | 高频 Direct Operation |
| `editor.run_project` | 高频 Direct Operation |
| `editor.run_custom_scene` | 高频 Direct Operation |
| `runtime.status` | 高频 Direct Operation |
| `runtime.get_tree` | 高频 Direct Operation |
| `runtime.inspect` | 高频 Direct Operation |
| `runtime.get_property` | 高频 Direct Operation |
| `runtime.set_property` | 高频 Direct Operation |
| `runtime.call_method` | 高频 Direct Operation |
| `diagnostics.run_capture` | 高频 Direct Operation |
| `batch.execute` | 高频 Direct Operation |
| `batch.execute_transaction` | 高频 Direct Operation |
| `logs.read` | 高频 Direct Operation |
| `test.run` | 高频 Direct Operation |

## Managed Domain Tools（16）

| Tool | 角色 |
| --- | --- |
| `project.manage` | 通过 `op` + `params` 访问长尾 Domain Operations |
| `input_map.manage` | 通过 `op` + `params` 访问长尾 Domain Operations |
| `scene.manage` | 通过 `op` + `params` 访问长尾 Domain Operations |
| `node.manage` | 通过 `op` + `params` 访问长尾 Domain Operations |
| `script.manage` | 通过 `op` + `params` 访问长尾 Domain Operations |
| `resource.manage` | 通过 `op` + `params` 访问长尾 Domain Operations |
| `classdb.manage` | 通过 `op` + `params` 访问长尾 Domain Operations |
| `editor.manage` | 通过 `op` + `params` 访问长尾 Domain Operations |
| `debugger.manage` | 通过 `op` + `params` 访问长尾 Domain Operations |
| `runtime.manage` | 通过 `op` + `params` 访问长尾 Domain Operations |
| `logs.manage` | 通过 `op` + `params` 访问长尾 Domain Operations |
| `test.manage` | 通过 `op` + `params` 访问长尾 Domain Operations |
| `autoload.manage` | 通过 `op` + `params` 访问长尾 Domain Operations |
| `content.manage` | 通过 `op` + `params` 访问长尾 Domain Operations |
| `world.manage` | 通过 `op` + `params` 访问长尾 Domain Operations |
| `custom.manage` | 通过 `op` + `params` 访问长尾 Domain Operations |

### 重要 Managed Domains

- `content.manage`：Animation、Material/Shader、Audio、Particle、Camera、Theme/UI、Curve/Gradient/Noise、Environment、Physics Shape 高层创作。
- `world.manage`：TileMap/TileSet、GridMap/MeshLibrary、CSG。
- `autoload.manage`：Autoload 增删与检查。
- `logs.manage`：Log Cursor/Filter/Clear 等长尾日志操作。
- `test.manage`：Test Discovery 与 Test Runner 长尾操作。
- `custom.manage`：第三方工具 list/get/invoke/enable-disable。
- `debugger.manage`：当前 Godot Runtime 真正支持时的 Debugger Session、Breakpoint、Profiler、Native Debugger 操作。

## Godot Variant 编码

常见非 JSON Godot 类型使用带标签对象，例如 `Vector3`：

```json
{
  "__godot_type": "Vector3",
  "x": 1,
  "y": 2,
  "z": 3
}
```

共享 Codec 还覆盖常用 Vector/Transform/Color/NodePath、Array/Dictionary、Resource Reference 和结构化 Object Summary。

## 常用工作流

### Inspect → Edit → Validate → Run

```text
project.inspect
scene.get_tree
classdb.search
node.set_property / script.patch
scene.save
script.validate
editor.run_project
runtime.inspect
logs.read
editor.take_screenshot
```

### Transaction Editor 修改

只有当所有请求操作都可逆时使用 `batch.execute_transaction`。后续可逆步骤失败时，之前成功的可逆步骤会 rollback；不可逆操作不能宣称 rollback。

### World Authoring

使用 `world.manage`，从实时 Schema 选择 TileMap/TileSet、GridMap 或 CSG `op`。v0.5 真实 Connector 验收已经验证 Cell/Item Mutation、有边界读取、Undo/Redo、Atlas Metadata/Image Content、MeshLibrary Listing 与 CSG Operation 修改。

### 第三方 Custom Tool

Custom Tool 必须由真实 Addon 注册，Handler 必须属于该 Addon，强制声明 `read_only` / `destructive`，并默认 Disabled。启用的 promoted tool 可动态出现为 `custom.<name>`；Disable 后会再次从 Public Surface 消失。

## 安全边界

v0.5 回归覆盖 Path Traversal/Project External 拒绝、Resource/Path 校验、Scene Root Delete 拒绝、有边界 Diagnostics/Image/Input/Logs/Test Payload、Transaction Rollback 分类、Custom Tool Ownership/Schema/Enablement，以及不提供通用任意 Shell MCP Tool。

## 真实验证

最终真实 Web ChatGPT Connector 回归于 **2026-09-10** 使用 **Godot 4.7.2-stable (official)**，通过真实 Web ChatGPT → Secure MCP Tunnel → Godot Editor/Runtime 链路验证 Compact Surface；包含真实 Screenshot Image Content，以及 Custom Tool Enable 时 47→48、Disable 后 48→47 的动态 Public Surface。

```text
CATALOGUE_SCHEMA_GATE=PASS tools=47
COMPACT_TOOL_SURFACE_GATE=PASS public=47 atomic=230
REAL_CHATGPT_GODOT_MCP_0_5_TEST=PASS
```

更多见：[常用示例](EXAMPLES.zh-CN.md)、[快速上手](QUICKSTART.zh-CN.md)、[安全说明](../SECURITY.zh-CN.md)。
