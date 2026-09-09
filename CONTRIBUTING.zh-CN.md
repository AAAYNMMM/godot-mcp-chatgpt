# 贡献指南

[English](CONTRIBUTING.md) | 简体中文

感谢你帮助改进 `godot-mcp-chatgpt`。

这个项目更看重：**小而清晰、可测试、能真正改善 Godot 工作流的改动**，而不是一次性堆大量未经验证的工具。

## 什么贡献最有价值

特别欢迎：

- 其他 Godot 4.x 版本的可复现兼容性结果；
- 有明确前后对比的 bug 修复；
- 能解决真实编辑器工作流的新 MCP 工具；
- 更好的错误信息和诊断；
- 安全加固；
- Windows 打包改进；
- macOS/Linux 运行时支持；
- 新用户视角的文档修正；
- 能复现真实连接器问题的测试。

## 做大功能前

建议先开 Issue，并说明：

1. 你在 Godot 里真正想完成什么；
2. 当前工具为什么做不到或很麻烦；
3. 最小需要新增什么能力；
4. 它是只读、修改型还是破坏型；
5. 如何在一次性测试项目中验证。

这样可以避免 MCP 工具面不断膨胀，同时让模型更容易稳定选择正确工具。

## 架构规则

当前生产架构是有意设计的：

```text
ChatGPT
 -> OpenAI Secure MCP Tunnel
 -> 官方 OpenAI tunnel-client
 -> Godot loopback Streamable HTTP MCP
 -> Godot CommandRegistry
 -> Godot Editor API
```

没有明确兼容性原因和架构讨论前，不要再用自定义 Tunnel 实现替换官方 tunnel-client。

不要把 CWapi 加成运行时依赖。

## 工具设计原则

新工具应当：

- 解决重复出现的真实用户工作流；
- 名称和职责单一；
- JSON Schema 尽量紧凑；
- MCP annotations 必须真实；
- 避免任意文件系统或 Shell 权限；
- 适用时保持 `res://` 边界；
- 返回结构化、可理解的错误；
- 能在一次性场景/项目里安全测试；
- 避免和已有工具只换名字重复实现。

如果一个工作流天然属于一次操作，优先考虑有价值的批处理，而不是拆成大量往返调用。

## 开发环境

当前明确验证：

```text
Windows x64
Godot 4.7.2 Standard x64
GDScript
```

仓库 `server/` 下还有仅供开发使用的 TypeScript control-plane 测试桩。

## 提交前测试

有实质代码改动时，至少运行相关检查。

Godot 脚本应在目标 Godot 版本下成功编译。

测试桩：

```text
cd server
npm install
npm run build
npm test
```

如果修改了 Transport 或编辑器控制层，并且本地环境支持，还应跑真实 Godot GUI production smoke。

没有实际运行的测试，不要写成“已通过”。

## 文档

面向用户的文档应尽量保持英文 + 简体中文双语。

新增用户文档优先采用配对文件：

```text
NAME.md
NAME.zh-CN.md
```

翻译时命令、标识符、真实报错文本保持原样。

除非仓库策略明确改变，否则不要添加装饰性截图、徽章、GIF 或其他图片。

## 开发进度记录规则

对仓库开发任务来说，进度文档属于 Definition of Done 的一部分。

每完成一个逻辑独立任务后：

1. 先执行对应的目标验证；
2. 如果存在 Active Version，更新对应 `docs/DEVELOPMENT_<version>.md` 追踪文档；
3. 更新 `docs/PROGRESS.md`，记录真实结果和当前下一优先方向；
4. 同步简体中文版本；
5. 然后才能进入下一项任务。

只写完代码但没有完成验证和进度更新，仍然属于开发中状态。

详细规则见 [开发工作流](docs/DEVELOPMENT_WORKFLOW.zh-CN.md)。
## 安全

永远不要提交：

- Runtime API Key；
- Tunnel 凭据；
- Shard Token；
- 含秘密的生成 profile；
- 只用于本地测试的私人项目数据。

修改鉴权、本地 HTTP、文件系统工具或进程启动前，请读 [SECURITY.zh-CN.md](SECURITY.zh-CN.md)。

## PR 范围

小 PR 更容易评审。尽量不要在一个 PR 里混合：

- Transport 重构；
- 大量工具扩展；
- 文档整体重做；
- 无关格式调整。

除非它们确实不可分割。

## Bug 报告

高质量报告建议包含：

```text
操作系统：
Godot 版本：
插件版本/commit：
面板到 connected：是/否
ChatGPT 连接器创建：是/否
发现工具数量：
最小复现：
完整但不含秘密的报错：
```

不要提交任何凭据。

## License

提交贡献即表示你同意贡献内容按本仓库项目许可证提供。第三方代码必须保留原有许可证和 attribution 要求。