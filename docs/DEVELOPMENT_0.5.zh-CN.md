# v0.5.0 能力迁移计划

[English](DEVELOPMENT_0.5.md) | 简体中文

状态：**已锁定范围 / 尚未开始实现**

基线版本：**v0.4.0**

能力参考基线：[hi-godot/godot-ai](https://github.com/hi-godot/godot-ai)。本计划于 2026-09-10 对照其当前 `docs/TOOLS.md` 和 tool-surface 设计说明完成审计。

本文是下一开发里程碑的当前追踪文档。只有实际实现并通过验证、同时更新公开 Release 文档后，本文中的能力才能算“已发布”。

## 1. 目标

v0.5.0 有两条绑定在一起的主线：

1. 迁移 Godot AI 当前已有、而 `godot-mcp-chatgpt` v0.4.0 缺失的实用 Godot 能力；
2. 把当前 119 个扁平 MCP tools 压缩为紧凑的 domain 工具面，同时保留底层全部原子能力。

目标闭环：

```text
ChatGPT 检查项目
→ 修改场景 / 脚本 / Resource
→ 运行游戏
→ 看到 Editor / Game 画面
→ 注入可复现的玩家输入
→ 逐帧 / 调试 Runtime
→ 读取结构化日志
→ 运行测试
→ 创建高级 Godot 内容
→ 验证并修复
```

从 v0.5 开始，工具数量不再作为产品指标。真正的指标是：能力覆盖、可靠性、可发现性和 schema 成本。

## 2. 本轮迁移的锁定决策

### 2.1 迁移能力，不迁 Godot AI 架构

所有新 Godot / Editor / Runtime 能力必须落在现有架构里：

```text
Web ChatGPT
  ↓
OpenAI Secure MCP Tunnel
  ↓
official tunnel-client
  ↓
Godot 内置 Streamable HTTP MCP
  ↓
紧凑 Public MCP Catalogue
  ↓
内部 Atomic CommandRegistry
  ↓
Godot Editor API / EditorDebuggerPlugin / EngineDebugger
```

语言边界：

| 层 | 语言 / 机制 |
| --- | --- |
| Godot Editor 操作 | **GDScript** |
| Runtime / Game 操作 | **GDScript**，继续走现有 debugger bridge |
| Public MCP catalogue / domain dispatch | **GDScript** |
| MCP image content 序列化 | **GDScript** |
| Undo/Redo / 原子编辑操作 | **GDScript** + Godot `EditorUndoRedoManager` |
| GDScript Test Runner | **GDScript** |
| Windows Credential Manager helper | Go，沿用现有实现 |
| Windows Installer | Go，沿用现有实现 |
| 有边界 Godot 子进程输出捕获 | Go，沿用现有实现 |
| 新 OS 原生 helper | 只有 Godot API 确实无法合理实现时才考虑 Go |

**不要**为了照搬上游实现而引入 Python、FastMCP、`uv`、Node.js、C# 或第二套 WebSocket Server。

### 2.2 四个明确不迁移项

以下 Godot AI 能力 / 组件**不进入本轮迁移**：

| 不迁移项 | 决策 |
| --- | --- |
| `godot://...` MCP Resources | 不迁 |
| MCP client 自动配置 | 不迁 |
| Python / FastMCP Server | 不迁 |
| Godot AI WebSocket Bridge | 不迁 |

这是本次能力审计范围内明确写死的四个排除项。

### 2.3 已经等价或更强的能力不重复实现

如果 v0.4.0 已经拥有等价能力或更通用能力，继续保留我们的实现，只把它映射到新的紧凑工具面，不再复制第二套。

典型保留项：

- Scene / Node CRUD 与层级检查；
- Node property / method / group / metadata / signal；
- Script read / write / attach / detach / introspection；
- 通用 Resource 检查和修改；
- ProjectSettings 与文件系统操作；
- 基础 InputMap 编辑；
- ClassDB（我们当前已经更细）；
- Editor selection / filesystem / script state；
- Runtime SceneTree、Node property / method；
- 有边界 diagnostics child-run；
- 当前项目级 Runtime Debugger 的 `session_id` 路由。

Godot AI 的跨 Editor `session_activate` / session list 不需要再复制一层：我们的每个 Secure MCP Tunnel endpoint 本身就绑定一个项目级 Godot 插件；运行时 Debugger 调用已经支持显式 `session_id`。对本项目目标来说，这项能力已由架构等价满足。

## 3. 必须迁移的缺失能力

下面是 v0.5.0 必做范围。每一项可以落成某个 compact domain 的 op，也可以增强现有内部 atomic command；**不代表每一项都新增一个顶层 MCP tool**。

### 3.1 视觉观察与 Game Liveness

| 能力 | v0.4.0 缺口 | v0.5 动作 | 实现层 |
| --- | --- | --- | --- |
| MCP image content | 当前 tools/call 只返回 text content | 增加 MCP `image` content，同时保留普通结构化 text result | GDScript MCP Server |
| Editor 3D viewport 截图 | 缺失 | 增加 screenshot mode | GDScript Editor |
| Editor 2D viewport 截图 | 缺失 | 增加 screenshot mode | GDScript Editor |
| Camera3D / cinematic 渲染截图 | 缺失 | 增加有尺寸上限的 screenshot mode | GDScript Editor / Runtime |
| Running Game framebuffer | 缺失 | 增加 Game Screenshot | GDScript Runtime / Editor |
| Project Run Liveness | `editor.run_project` 只负责启动，不区分 Runtime 是否真正 ready | 增加 launching/live/break/stopped 等状态和 recent error hints | GDScript Editor / Debugger |
| Runtime UI 元素发现 | 缺失 | 枚举运行中的 `Control` 和有边界的关键属性 | GDScript Runtime |

Screenshot 必须有尺寸 / 字节上限，默认内存返回，不得顺手向项目外任意写文件。

### 3.2 输入注入与确定性 Playtest

必须支持：

- Keyboard press / release；
- Mouse button / motion / wheel；
- Gamepad button / axis；
- InputMap action press / release + strength；
- Input state 查询；
- 按 frame 调度的 `input_sequence`；
- sequence 结束后明确返回仍处于按下状态的 action，并支持清理释放。

`input_sequence` 必须在运行中的 Godot 游戏进程内完成调度，这样 Tunnel / 网络往返延迟不会改变帧时序。

实现：**GDScript，继续扩展现有 runtime bridge，通过 EditorDebugger / EngineDebugger 通信。** 不增加第二套 Runtime Transport。

### 3.3 Native Debugger 控制

v0.4.0 的 `runtime.pause/resume` 是 SceneTree pause。v0.5 还要迁移 Godot 原生 debugger 语义：

- debugger suspend；
- debugger resume；
- next frame / 单帧推进；
- 更完整的 debug / break status；
- 明确区分“Gameplay SceneTree Pause”和“Debugger Suspend”。

实现：**GDScript EditorDebuggerPlugin / EditorDebuggerSession API**，并用当前 Godot 版本 ClassDB / 实际 API 做 feature detection。

### 3.4 Live Logs 与 Diagnostics 可观察性

迁移日志能力，不迁 Python Transport：

- Editor / Plugin 日志 Ring Buffer；
- Running Game 日志 Buffer；
- Combined Log；
- Godot 能提供时返回结构化 error / warning / source / line / stack；
- Cursor 增量读取和 truncated 标记；
- 每次 Game Run 独立 run id，能区分当前与历史运行；
- Clear 操作，Debugger Errors UI 清理必须显式；
- 可靠情况下，在 Tool Result 上提供“自上次调用新增 Error / Warning”的提示；
- 即使 Game Helper 没有真正 Ready，也要尽量能看到 Boot / Parse / Load Failure。

现有 `diagnostics.run_capture` 继续保留，用于干净、有边界的子进程验证。Live Logs 是新增路径，不替代 Diagnostics。

实现：以 **GDScript** 为主；现有 Go run-helper 继续只负责 Child Process Capture。

### 3.5 Script Authoring 增强

必须增加：

- Anchor-based Script Patch（`old_text` → `new_text`）；
- 歧义检测；
- 可选 `replace_all`；
- Script write / patch 后直接返回 GDScript Validation 结果；
- Godot 能提供时返回当前文件范围的结构化 diagnostics；
- 明确区分“文件写成功”和“脚本解析成功”。

现有 `script.write`、`script.validate`、`script.get_info` 继续作为底层通用能力。

### 3.6 Test Runner

新增 Editor 内 GDScript Test Layer：

- Discover / List Test Suites；
- Run 一个或多个 Suite；
- 结构化 Pass / Fail / Error；
- Duration / Assertion Detail；
- 获取最近一次结果；
- 对同一个 Editor Session 中 dependency 缓存可能导致的 stale validation 给出明确 freshness warning；
- 有边界输出和确定性清理。

实现：**GDScript**。不要为了这个引入 pytest Runtime 依赖。

### 3.7 Undo/Redo 与 Atomic Editing

v0.4.0 `batch.execute` 是明确 Non-Atomic。v0.5 要补上缺失的 Editor Transaction 能力：

- 可以安全接入 `EditorUndoRedoManager` 的 Editor Mutation 应变成 Undoable；
- Result 明确返回是否 Undoable；
- 对支持的 Editor Mutation 增加 grouped batch + first-error rollback / undo；
- File Write、外部 Process、Scene Open/Close 等无法可靠回滚的操作保留明确 Non-Atomic 路径；
- 不能对 Godot 无法真正恢复的操作虚假宣称 Atomic。

这不是只新增一个 Batch Tool，而是 Editor Mutation 语义整体升级。

### 3.8 仍缺失的 Editor 操作

迁移：

- 与 Game Runtime Performance 不同的 Editor Monitor / Performance Snapshot；
- Plugin Reload：包含 FileSystem Rescan、Readiness Check、适配我们 In-Process Transport 的有边界恢复；
- Editor Quit：标记为 Destructive，行为明确；
- Live Game Eval / Command：只有在单独 Security Review 定义出有边界 Contract 后才实现；
- 上面提到的 Log Clear。

`game_eval` 不能成为绕过“禁止通用 OS Shell / 任意项目外执行”安全边界的后门。

### 3.9 InputMap 幂等 Helper

在现有 InputMap 基础上补：

- ensure action；
- ensure binding；
- bind-event 时避免重复 Binding 的幂等语义。

这些应该作为 `input_map.manage` 的 op，而不是新增顶层工具。

### 3.10 Autoload 管理

现有 Autoload Inspect 保留，新增：

- Add Autoload；
- Remove Autoload；
- Conflict Validation；
- `ProjectSettings.save()` 持久化；
- `GodotMCPChatGPTRuntime` 保留名称保护。

### 3.11 Animation Authoring

迁移完整高层 Animation 能力：

- 按需创建 AnimationPlayer / Library / Clip；
- 删除 Animation；
- Validate；
- Property Track；
- Method Track；
- Track Key 增加 / 更新；
- Autoplay；
- Play / Stop；
- List / Get；
- Simple Animation Helper；
- Fade / Slide / Shake / Pulse Preset。

必须使用 Godot 原生 Resource + `EditorUndoRedoManager`，不要创建自定义 Animation 文件格式。

### 3.12 Material / Shader Authoring

迁移：

- Material Create；
- Material Param；
- Shader Param；
- Get / List / Inspect；
- Assign / Apply To Node；
- 有边界的常用 Preset。

底层继续复用我们的通用 `resource.*`，新 Domain 只提供高层易用能力。

### 3.13 Audio Authoring

迁移：

- 按场景需要创建 AudioStreamPlayer / 2D / 3D；
- Set Stream；
- Playback Config；
- 安全范围内 Play / Stop；
- List / Inspect Audio Players。

### 3.14 Particle Authoring

迁移：

- 创建 Particle Node / Resource；
- Main Params；
- Process Material Params；
- Draw Pass；
- Restart；
- Inspect；
- 常用 Presets。

### 3.15 Camera Authoring

迁移：

- Camera2D / Camera3D Create；
- Common Configure；
- Camera2D Limits；
- Camera2D Damping；
- Follow Helper；
- Get / List；
- 常用 Presets。

### 3.16 Theme / UI Authoring

Theme：

- Create Theme；
- Set Color；
- Set Constant；
- Set Font Size；
- 创建 / 应用有边界的 StyleBoxFlat；
- Apply Theme。

UI：

- Anchor / Layout Preset；
- Text Update；
- 高层 Layout Building；
- 有边界 Draw Recipe / Control Construction Helper。

必须使用正常 Godot Control / Theme API，创建后仍然能被普通 Editor / Node / Resource 工具检查和修改。

### 3.17 Resource 高层 Helper

不重复我们的通用 Resource CRUD，只补缺失高层能力：

- 通用 Node / Resource Setter 不够方便时的 Resource Assignment Helper；
- Curve Point Editing；
- Environment Create / Configure；
- Physics Shape Auto-Fit；
- Physics Shape Generate；
- GradientTexture Create；
- NoiseTexture Create。

### 3.18 TileMap / TileSet

迁移：

- Set Cell；
- Set Rect Cells；
- Clear；
- 读取用于验证的 Used / Selected Cells；
- Atlas Tiles 检查；
- Atlas Source Image / Resource Metadata 检查。

实现必须以 Godot 4.7 实际 API 为准，在硬编码前先用 ClassDB / 实际运行验证 TileMap / TileSet API。

### 3.19 GridMap

迁移：

- Set Item；
- Fill Region；
- Clear；
- Get Used Cells；
- List MeshLibrary Items。

### 3.20 CSG

迁移：

- 创建常用 CSG Node；
- 配置 CSG Operation；
- 校验 Parent / Type Constraint。

### 3.21 第三方 Custom Tool 扩展

用本项目原生方式迁移扩展能力：

- 其他 Godot Addon 可以向本插件注册有边界 Custom MCP Command；
- List Registered Commands；
- Invoke Enabled Command；
- Per-command Enable / Disable；
- 只允许少量、显式请求的 Custom Command Promotion 成 First-class Public Tool；
- 强制 Schema Validation + Destructive / Read-only Hint；
- Custom Tool 不允许仅靠注册就绕过核心 Path / Security Boundary。

实现：围绕现有 CommandRegistry 做 **GDScript Extension API**。不引入 Python Plugin System。

## 4. Public Tool Surface 压缩

### 4.1 为什么要压缩

v0.4.0 当前公开 119 个顶层 MCP tools。Web ChatGPT 已经实测可用，但如果 v0.5 继续按同样方式增加 Tool，Discovery 和 Schema 成本会越来越差。

v0.5.0 正式把**内部 Commands**和**公开 MCP Tools**分层。

作为参考，2026-09-10 审计到的 Godot AI 当前 Public MCP Surface 是 **46 tools：19 个高频 Named Tools + 27 个 Domain Rollups**；其插件内部 Command Surface 并不会因为 Public Tool 压缩而删除。我们采用同一原则，但不复制其 Python 注册层。

### 4.2 两层模型

```text
Public Compact MCP Surface（目标 <= 50）
                 ↓
        Domain Op Dispatch / Validation
                 ↓
Internal Atomic CommandRegistry（现有 119 + 迁移新增）
                 ↓
          Godot Editor / Runtime API
```

规则：

- 为了减少 Public Tool Count，不删除 Atomic Command 实现；
- Batch 和内部回归测试继续使用 Atomic Command Name；
- 高频动作保留 Named Tool；
- 长尾动作放进一个 `domain.manage`；
- 每个 `domain.manage` 使用 `op` enum + `params` object；
- Dispatcher 用底层 Atomic Command Schema 校验 `params`；
- 未知 `op` 返回结构化错误和建议；
- Description 必须包含该 Domain 的搜索关键词和支持操作；
- Runtime / Debugger Domain 保留可选 `session_id`；
- 顶层 Schema 尽量使用有边界结构和 `additionalProperties=false`。

### 4.3 Public Surface 目标

初始目标：**40–50 个 Public MCP Tools**。Release Gate 默认要求 **<=50**，除非真实 Web ChatGPT 可用性测试证明需要例外。

建议保留的高频 Named Tools 大致包括：

- Status / Project Inspect；
- Scene Hierarchy / Open / Save；
- Node Create / Find / Get Properties / Set Property；
- Script Write / Attach / Patch；
- Resource / ClassDB Inspect；
- Project Run；
- Screenshot；
- Logs Read；
- Test Run；
- Runtime Status；
- Batch Execute。

长尾能力放进以下 Domain：

```text
project.manage
filesystem.manage
scene.manage
node.manage
script.manage
resource.manage
classdb.manage
editor.manage
debugger.manage
runtime.manage
input_map.manage
diagnostics.manage
test.manage
animation.manage
material.manage
audio.manage
particle.manage
camera.manage
theme.manage
ui.manage
autoload.manage
tilemap.manage
tileset.manage
gridmap.manage
csg.manage
custom.manage
```

具体 Named / Rollup 划分在实现阶段最终确定，但“默认 Public Surface <=50”和“内部 Atomic Commands 不删除”已经锁定。

### 4.4 兼容性策略

v0.5.0 对那些硬编码 v0.4 顶层 Tool Name 的 Caller 可能是 Tool-Surface Breaking Release。Web ChatGPT 正常会重新 Discover 当前 Catalogue，因此优先发布干净的 Compact Surface，而不是永久保留 119 个 Public Alias。

Release 前评估是否低成本提供一个**默认关闭的 Legacy Registration Mode**。它不能增加默认 Compact Tool Count，也不是完成本次迁移的必要条件。

## 5. 迁移阶段

### Phase A — Compact Surface 基础

状态：**已实现 / Official Tunnel 验证通过；最终真实 Web ChatGPT 集成验证延后**。

已实现：

- 新增 `core/public_tool_surface.gd`，作为 Public / Internal Catalogue 边界；
- v0.4 的 119 个 Atomic Command 继续保留在 `CommandRegistry`；
- 默认公开 **39 个 MCP Tools**：29 个高频 Direct Tools + 10 个 Domain `*.manage` Rollup；
- v0.4 每一个 Atomic Command 都至少有一个 Public Route；
- `*.manage(op, params)` 会按目标 Atomic Command Schema 在服务端再次验证 `params`；
- Direct Tool 保留 v0.4 原有错误语义；
- Batch 继续直接访问 Internal Atomic Command Name；
- Official Tunnel Production Smoke 已改为：既有完整行为测试遇到 Long-tail Atomic Name 时自动经过 Compact Domain Surface；
- 增加派生覆盖门禁，证明 **39 Public → 119 Atomic** 全覆盖。

实际通过：

```text
Godot 4.7.2 addon load/parse: PASS
npm run build: PASS
npm test: PASS
CATALOGUE_SCHEMA_GATE=PASS tools=39
COMPACT_TOOL_SURFACE_GATE=PASS public=39 atomic=119
PRODUCTION_PLUGIN_SMOKE=PASS
```

Phase A 剩余门禁：必须在**新的 Web ChatGPT 对话**里重新发现 39 个工具，并真实调用 Direct + Manage + Batch。真实 Connector 回归通过前，不开始 Phase B。

### Phase B — Observe / Play / Debug / Diagnose

状态：**targeted validation passed**。

已实现并验证：

- MCP `image` Content 序列化；
- Editor 3D / 2D Viewport Screenshot、Cinematic Camera3D Screenshot、运行中 Game Screenshot；
- Screenshot Resolution / PNG Byte 上限；
- Project Run / Runtime Liveness 状态；
- Runtime UI `Control` 枚举；
- Keyboard / Mouse / Gamepad / InputAction 注入；
- Game-process 内 Frame-timed `input_sequence`，带 Step/Frame 上限与 Held Action 清理；
- Runtime Input State；
- Native Debugger Suspend / Resume / Next Frame / Status；
- Editor / Game Log Ring Buffer、Cursor、Run ID、Clear；
- Editor Performance Monitor；
- 有边界 Plugin Refresh 和 confirm-gated Editor Quit；
- 受限 `runtime.evaluate`：使用 Godot `Expression` 在指定 Runtime Node 上求值，不暴露 OS Shell / 外部进程。

实现保持现有 GDScript + EditorDebugger/EngineDebugger 架构，没有引入 Python/FastMCP/WebSocket。

实际验证：

```text
Godot 4.7.2 addon load/parse: PASS
npm run build: PASS
CATALOGUE_SCHEMA_GATE=PASS tools=42
COMPACT_TOOL_SURFACE_GATE=PASS public=42 atomic=139
PHASE_B_RUNTIME_INPUT=PASS key/mouse/gamepad/action/sequence
PHASE_B_MCP_IMAGE=PASS game screenshot image/png
PHASE_B_RUNTIME_UI=PASS
PHASE_B_LOGS=PASS editor/game
PHASE_B_RUNTIME_EVAL=PASS
PRODUCTION_PLUGIN_SMOKE=PASS
```

真实 Web ChatGPT 验证按要求统一延后到 Phase F。

### Phase C — Script / Test / Transaction

状态：**planned**。

- Script Patch；
- Write Diagnostics；
- GDScript Test Runner / Results；
- InputMap Ensure Helper；
- Eligible Editor Mutation UndoRedo；
- 支持范围内 Atomic / Rollback Batch；
- Autoload Add / Remove。

### Phase D — 高层内容创作

状态：**planned**。

- Animation；
- Material / Shader；
- Audio；
- Particles；
- Camera；
- Theme；
- UI / Layout / Draw Recipe；
- Resource Helpers。

### Phase E — World Building / Extensibility

状态：**planned**。

- TileMap / TileSet；
- GridMap；
- CSG；
- 第三方 Custom Tool Register / Invoke。

### Phase F — 全量迁移回归 / Release Hardening

状态：**planned**。

- Compact Surface Tool Count / Schema Gate；
- 对照锁定迁移矩阵做 Capability Parity Audit；
- Godot 4.7.2 Compile / Load；
- 真实 Editor Behavior；
- 真实 Runtime Playtest Sequence；
- Screenshot 通过真实 ChatGPT Connector 返回；
- Logs / Test / UndoRedo Regression；
- Installer Upgrade Regression；
- 最终 Release Asset 精确 Commit 重建和校验；
- 中英文 Public Docs + Upstream Acknowledgement。

## 6. 必须通过的验证门禁

任何迁移 Domain 都不能因为“GDScript 能编译”就算完成。

每个 Domain 按适用范围至少验证：

1. Godot 4.7.2 Script Parse / Load；
2. Schema Registration / Duplicate-op；
3. 真实 Editor Targeted Behavior；
4. Editor Mutation 的 Undo / Redo；
5. Path / Security Boundary；
6. 涉及 Game-side 时的 Runtime / Debugger Round-trip；
7. Payload / Timeout Bound；
8. 通过 Official Tunnel Path 的真实 Compact MCP Call；
9. 每一项逻辑任务完成后先更新 Progress + Active Tracker，再继续下一项。

Release 级至少需要：

```text
COMPACT_TOOL_SURFACE_GATE=PASS tools<=50
CAPABILITY_MIGRATION_MATRIX=PASS
PRODUCTION_PLUGIN_SMOKE=PASS
REAL_CHATGPT_GODOT_MCP_0_5_TEST=PASS
```

实际开发开始后，各 Family 还必须增加自己的验证 Marker。

## 7. 安全要求

迁移不能放松 v0.4 安全边界：

- Project File Write 保持在 `res://`；
- 不提供 Arbitrary OS Shell MCP Tool；
- Screenshot 有边界，默认只在内存返回；
- Input Injection 只作用于当前 Godot Game / Editor 路径；
- `game_eval` 实现前必须先锁定有边界 Security Contract；
- Custom Tool 需要 Opt-in + Schema Validation，不能静默扩大核心权限；
- Editor Quit 标记 Destructive；
- Atomic Batch 不得对不可逆操作宣称 Rollback；
- Credential 不进入 Project / Git。

## 8. 上游参考与许可证

Godot AI 是独立的 MIT 开源项目，本项目在 v0.5 迁移中将它作为**能力与设计参考**。

仓库：<https://github.com/hi-godot/godot-ai>

实现规则：

- 能用 Godot 原生 API 自己实现时，优先重新实现；
- 如果后续实质 Port / Derive Godot AI 源码，必须保留对应 Copyright / MIT Notice；
- 发生源码派生时，立即更新 `THIRD_PARTY_NOTICES.md` 和中文版本，不能拖到 Release 前一天才处理；
- 不复制它的 Python / FastMCP / WebSocket Transport Stack；
- Attribution 随迁移代码同步维护。

## 9. 当前状态

状态：**Phase A–B targeted validation passed；最终真实 Web ChatGPT 集成验证延后**。

已经锁定：

- v0.5.0 就是能力迁移里程碑；
- 除四个明确排除项外，上面审计出来的缺失 Godot-side 能力全部进入必做范围；
- 我们已有等价 / 更强能力不重复实现；
- 新 Godot 能力以 GDScript 为主；
- Default Public MCP Surface <=50；
- Internal Atomic Commands 继续供实现 / 测试层使用；
- README 明确致谢并说明 Godot AI 是能力 / Tool-Surface 设计参考。

## 9.1 规划文档验证

```text
MIGRATION_SCOPE_GATE=PASS
EXCLUSION_GATE=PASS count=4
COMPACT_TOOL_PLAN_GATE=PASS target<=50
UPSTREAM_COMPRESSION_REFERENCE=PASS 46=19+27
README_GODOT_AI_ACK=PASS
DOC_LINK_CHECK=PASS files=36
DIFF_CHECK=PASS
DOC_ONLY_SCOPE=PASS
PLANNING_DOC_GATES=PASS
```

## 10. 精确下一项实现任务

**开始 Phase C：Script Patch / Write Diagnostics / GDScript Test Runner / InputMap Ensure / UndoRedo + Transactional Batch / Autoload Mutation。真实 Web ChatGPT 测试继续延后到 Phase F。**
