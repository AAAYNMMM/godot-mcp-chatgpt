# 第三方组件说明

[English](THIRD_PARTY_NOTICES.md) | 简体中文

这份中文文件用于帮助用户理解仓库里的第三方组件。**具体许可证法律文本以对应上游原始 LICENSE / NOTICE 为准。**

## OpenAI Secure MCP Tunnel client

项目：`openai/tunnel-client`

许可证：Apache License 2.0

当前 Windows 插件内置版本：

```text
0.0.10+105e17a79a36e4e5c897fd698ed2b8dbf935b144
```

`tunnel-client.exe` SHA-256：

```text
D893D8127EEE35070D265C1BE29BFE008F8D9FCB476E7FEBF56C8FDC6C0615C8
```

生产插件会启动这份官方 runtime，并把它连接到 Godot 内部 loopback Streamable HTTP MCP Server。当前生产版本不再自己实现 OpenAI Tunnel wire protocol。

上游 Apache-2.0 LICENSE 和 NOTICE 保存在：

```text
addons/godot_mcp_chatgpt/bin/LICENSE.openai-tunnel-client.txt
addons/godot_mcp_chatgpt/bin/NOTICE.openai-tunnel-client.txt
```

上游仓库：

```text
https://github.com/openai/tunnel-client
```

## Godot MCP Toolkit

项目：`NPGameDev/godot-mcp-toolkit`

许可证：MIT

开发早期参考了它在 Godot 编辑器控制、场景生命周期和工具设计方面的思路。当前项目没有复用其品牌或美术资源。

上游：

```text
https://github.com/NPGameDev/godot-mcp-toolkit
```

## Godot MCP Server

项目：`NPGameDev/godot-mcp-server`

许可证：MIT

早期评估过其本地 MCP/bridge 架构。当前插件使用自己很小的 Godot-hosted Streamable HTTP MCP Server，并使用官方 OpenAI tunnel-client，而不是上游 Node bridge。

上游：

```text
https://github.com/NPGameDev/godot-mcp-server
```

如果未来直接复制了大量第三方源码，而不是仅参考公开协议/行为，必须同时保留对应版权和许可证声明。
## Godot AI

项目：`hi-godot/godot-ai`

许可证：MIT

Godot AI 当前的 Godot-side 能力面、GDScript Handler 设计，以及把 100+ 扁平 MCP Tool 压缩为 Compact Domain / Rollup Surface 的思路，是 v0.5.0 能力迁移计划的重要参考。

当前本项目**不依赖** Godot AI，也不会迁移其 Python/FastMCP Server、WebSocket Bridge、MCP Client Auto-config 或 `godot://...` Resources。

如果后续迁移实质复制或派生 Godot AI 源码，对应文件/模块必须保留适用的 MIT Copyright / License Notice，并在本文同步记录。

上游仓库：

```text
https://github.com/hi-godot/godot-ai
```
