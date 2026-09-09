# 更新日志

[English](CHANGELOG.md) | 简体中文

项目仍处于早期阶段。这里记录对用户真正有意义的版本节点，而不是每一次内部实验。

## 0.4.0 — 完整 Godot 编辑器 / Runtime MCP 能力面

日期：2026-09-10

### 主要变化

- 生产 MCP 工具从 **13 个扩展到 119 个**。
- 新增 Project 发现/搜索/设置/Autoload/插件与 InputMap 编辑能力。
- 新增丰富 Scene/Node 读取与编辑：open/close/reload/instantiate、属性、方法、Group、Metadata、Signal。
- 新增 Script 自省/验证/编辑器状态，以及 Resource 创建/编辑/保存/复制/依赖能力。
- 新增实时 **ClassDB** 查询，让 ChatGPT 直接读取当前 Godot 4.7.2 API，而不是依靠模型记忆猜 API。
- 新增 Editor 状态/控制、Godot Debugger Session，以及运行中 SceneTree/property/method/performance/pause/resume Runtime Bridge。
- 新增有边界的 `diagnostics.run_capture`，分开返回 stdout/stderr、exit code、timeout、duration。
- 新增有上限、非事务的 `batch.execute`，支持 `stop_on_error` 并拒绝递归 Batch。
- Runtime API Key 改为保存到 Windows Credential Manager，支持 Godot 重启后自动重连，并增加 **Forget Saved Credentials**。
- Resource 路径统一安全校验；`node.create.parent_path` schema 明确 `.` 表示编辑场景根节点。
- 新增 Windows x64 项目级单文件安装器：内嵌完整 addon，可选择任意 Godot 项目，默认自动启用插件，支持无写死路径的干净安装与升级。
- Runtime autoload 添加/删除后显式调用 `ProjectSettings.save()`，确保新安装到外部项目时 Runtime bridge 立即持久化。

### 安全 / 可靠性

- Runtime API Key 作为 Windows Generic Credential 保存，不进入项目、生成的 tunnel profile、EditorSettings 或 Git。
- Tunnel ID 继续保存在 Godot EditorSettings。
- File / Resource 操作仍限定在 `res://`；路径穿越和项目外路径会被拒绝。
- Runtime 修改只影响运行中实例，不会自动写回保存的编辑器场景。
- Runtime autoload 生命周期兼容 Godot 4.7.2 `uid://` 正规化，并在插件被禁用时清理。
- 生产 runner 已删除开发测试用 fake credential / TEST_MODE 钩子。

### 验证

已经通过：

```text
Godot 4.7.2 addon load/compile
npm build + test
119-tool catalogue/schema gate
官方 tunnel-client production smoke
Credential 保存 -> 重启自动连接 -> Forget -> 再次重启
Runtime autoload disable/re-enable lifecycle
BOM / secret / diff / 文档链接门禁
真实 ChatGPT Connector 全能力回归
REAL_CHATGPT_GODOT_MCP_0_4_TEST=PASS
INSTALLER_SMOKE=PASS version=0.4.0
```

真实 Connector 回归由 ChatGPT 本身完成编辑器修改、Runtime 读写、Diagnostics、Batch 和安全边界验证。
## 0.3.0 — 官方 tunnel-client 架构

日期：2026-09-09

### 主要变化

- 生产 Transport 切换为**官方 OpenAI `tunnel-client`**。
- Godot 内新增 loopback **Streamable HTTP MCP** Server。
- 插件内置已经验证的 Windows `tunnel-client.exe`，并附 LICENSE/NOTICE。
- 用户使用流程仍然只有 **Tunnel ID + Runtime API Key**。
- Runtime API Key 继续保持不持久化。
- 增加官方客户端路径所需的 `server/discover` 和新旧 MCP 兼容行为。
- 增加 HTTP `DELETE` session termination。
- 保留初始 13 个高频 Godot 工具。

### 验证

已经通过：

```text
Godot 4.7.2 脚本编译
Go MCP SDK v1.7 兼容
官方 tunnel-client bridge smoke
真实 Godot 4.7.2 GUI production smoke
真实 OpenAI Tunnel + ChatGPT 连接器创建
```

真实 ChatGPT 连接器于 2026-09-09 创建成功。

### 架构变化

生产代码删除旧的 GDScript OpenAI `/poll` + `/response` 直连实现。

现在生产链路：

```text
ChatGPT
 -> OpenAI Secure MCP Tunnel
 -> 官方 OpenAI tunnel-client
 -> Godot loopback Streamable HTTP MCP
 -> Godot Editor API
```

## 0.2.3 — 连接器兼容性排查

- 给旧直连 Tunnel 实现增加 `server/discover`。
- 确认“本地协议 simulator 能通过”不足以证明真实 ChatGPT 连接器兼容。
- 这一版本帮助定位到：应该对照一个 known-good 官方 Tunnel runtime。

## 0.2.2 — 编辑器面板可用性

- 连接 UI 移到 Godot 底部明显可见的 **MCP ChatGPT** 面板。
- 改善第一次使用体验。

## 0.2.1 — 凭据持久化加固

- 不再把 Runtime API Key 写入 Godot EditorSettings。
- Tunnel ID 继续持久化，方便使用。

## 0.2.0 及更早 — Transport 原型

- 建立初始 Godot EditorPlugin 和 CommandRegistry。
- 加入第一批 scene/node/script/editor 工具。
- 探索过自建 Relay 和 GDScript 直连 Secure Tunnel。
- 这些 Transport 实验都已经被 0.3.0 官方 runtime 架构取代。