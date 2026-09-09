# Third-Party Notices

This project was designed with reference to the following open-source projects.

## OpenAI Secure MCP Tunnel client

Project: `openai/tunnel-client`

License: Apache License 2.0

The Godot tunnel implementation follows the publicly documented Secure MCP Tunnel wire protocol, endpoint shapes, headers, correlation rules, and lifecycle behavior. The production addon is an independent GDScript implementation and does not bundle the tunnel-client binary.

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

The original local stdio/Node/localhost bridge architecture was evaluated early in development but is not part of the final production runtime.

Upstream repository:

```text
https://github.com/NPGameDev/godot-mcp-server
```

If future development copies substantial source rather than independently implementing behavior/protocol contracts, preserve the relevant upstream copyright and license notices alongside the copied material.
