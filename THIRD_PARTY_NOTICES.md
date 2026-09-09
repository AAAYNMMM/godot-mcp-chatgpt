# Third-Party Notices

English | [简体中文](THIRD_PARTY_NOTICES.zh-CN.md)

This project uses or was designed with reference to the following open-source projects.

## OpenAI Secure MCP Tunnel client

Project: `openai/tunnel-client`

License: Apache License 2.0

Version bundled in the current Windows development addon:

```text
0.0.10+105e17a79a36e4e5c897fd698ed2b8dbf935b144
```

SHA-256 of `addons/godot_mcp_chatgpt/bin/windows/tunnel-client.exe`:

```text
D893D8127EEE35070D265C1BE29BFE008F8D9FCB476E7FEBF56C8FDC6C0615C8
```

The production addon launches this official runtime and points it at the Godot-hosted loopback Streamable HTTP MCP server. The project no longer reimplements the OpenAI tunnel wire protocol in production.

The upstream Apache-2.0 license and NOTICE are preserved in:

```text
addons/godot_mcp_chatgpt/bin/LICENSE.openai-tunnel-client.txt
addons/godot_mcp_chatgpt/bin/NOTICE.openai-tunnel-client.txt
```

Upstream repository:

```text
https://github.com/openai/tunnel-client
```

## Godot MCP Toolkit

Project: `NPGameDev/godot-mcp-toolkit`

License: MIT

The project was studied as a reference for Godot editor-control behavior, scene lifecycle concerns, and tool design. Branding/artwork from that project is not reused.

Upstream repository:

```text
https://github.com/NPGameDev/godot-mcp-toolkit
```

## Godot MCP Server

Project: `NPGameDev/godot-mcp-server`

License: MIT

Its local MCP/bridge architecture was evaluated during early design work. The current addon uses its own small Godot-hosted Streamable HTTP MCP server and the official OpenAI tunnel-client rather than the upstream Node bridge.

Upstream repository:

```text
https://github.com/NPGameDev/godot-mcp-server
```

If future development copies substantial upstream source instead of independently implementing behavior/protocol contracts, preserve the relevant copyright and license notices alongside the copied material.