# 常用示例

[English](EXAMPLES.md) | 简体中文

下面这些示例按**普通用户对 ChatGPT 说话的方式**来写，不要求你自己手动调用 MCP RPC。ChatGPT 会从当前工具集中选择合适工具。

## 1. 看当前打开了什么

```text
用 Godot 连接器检查当前编辑器。
告诉我 Godot 版本、项目名、当前编辑场景，并读取深度 4 的场景树。
不要修改任何东西。
```

常用工具：`godot.get_status`、`project.get_info`、`scene.get_tree`。

## 2. 创建一个一次性 3D 测试场景

```text
创建一个一次性测试场景 res://mcp_test/basic_3d.tscn。
根节点用 Node3D，名字 Basic3DTest。
添加一个 Node3D 子节点 Marker，位置设为 (1, 2, 3)。
保存场景。不要覆盖已有文件。
```

## 3. 创建带 GDScript 的玩家测试场景

```text
创建 res://prototype/player_test.tscn，根节点 Node3D，名字 PlayerTest。
添加一个名为 Player 的 CharacterBody3D 子节点。
新建 res://prototype/player.gd，加入 exported float move_speed，默认值 5.0，
然后把脚本挂载到 Player。
保存场景。
不要修改 res://prototype/ 之外的文件，也不要覆盖已有文件。
```

这个例子一次覆盖场景、节点、脚本三类工具。

## 4. 修改前先读脚本

```text
先读取 res://player/player.gd。
解释它当前负责什么，并告诉我如果要加入 move_speed，最小安全改动是什么。
现在先不要写文件。
```

重要项目推荐采用这个模式：先读，再改。

## 5. 做一个范围明确的脚本修改

```text
读取 res://player/player.gd。
然后只修改这个文件，加入 exported float move_speed = 5.0。
保留无关代码，不要创建或修改其他文件。
```

当前 `script.write` 是整文件写入，所以要求 ChatGPT 先读文件，对保护已有代码很重要。

## 6. 给当前场景添加节点

```text
先检查当前场景树。
如果已经打开场景，就在根节点下添加一个名为 SpawnPoint 的 Node3D。
把 SpawnPoint.position 设为 (0, 1, 0)，然后保存当前场景。
如果没有打开场景，不要新建，直接告诉我。
```

## 7. 运行项目

```text
先确认当前连接的是哪个项目，然后运行项目主场景。
不要修改任何文件。
```

结束时：

```text
停止当前正在运行的 Godot 项目。
```

## 8. 要求“小型可验证原型”，不要一上来重写全项目

推荐：

```text
在 res://prototype/ 下做一个最小测试场景，证明移动结构能工作。
和现有正式场景隔离，不要覆盖任何东西。
```

风险更高：

```text
把我的整个项目架构重写一遍。
```

当前工具集最适合的是：**小范围、肉眼可见、容易验证的编辑器改动**。

## 9. 给 ChatGPT 明确安全约束

很实用的句子：

```text
不要覆盖已有文件。
修改前先读取文件。
只操作 res://prototype/。
不要删除节点。
使用一次性测试场景。
如果当前工具不支持，就停止并报告，不要猜。
```

这些约束可以和插件本身的安全保护一起使用。

## 10. 判断是“连接问题”还是“缺工具”

```text
先调用 godot.get_status。
再读取当前场景树。
如果两者都正常，请判断我的需求是不是超出了当前工具范围，
不要把“缺能力”当成“连接失败”。
```

当前准确能力边界见：[工具参考](TOOL_REFERENCE.zh-CN.md)。