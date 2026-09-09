# godot-mcp-chatgpt

Direct Web MCP control for the Godot Editor.

## Goal

```text
Web ChatGPT
  -> Web MCP relay
  -> Tunnel ID + API Key
  -> Godot addon outbound WSS connection
  -> Godot Editor
```

This project does **not** use the traditional local stdio MCP + Node bridge architecture. The normal user enables the addon, enters a Tunnel ID and API Key, and connects.

## Current status

The first Godot 4.7.2 addon skeleton is implemented and loads successfully. It includes:

- a Godot dock for Tunnel ID + API Key;
- outbound WSS relay client/reconnect logic;
- remote tool catalogue registration;
- tool call/result dispatch;
- a small command registry;
- `godot.get_status` and `project.get_info` test commands.

The public Web MCP relay is the next major component.

## Development

The repository root is a minimal Godot development project. With Godot 4.7.2 installed:

```powershell
& 'C:\Users\11830\AppData\Local\Programs\Godot\4.7.2\godot.exe' --editor --path .
```

Headless plugin-load validation:

```powershell
& 'C:\Users\11830\AppData\Local\Programs\Godot\4.7.2\godot.exe' --headless --editor --path . --quit
```

For a development relay endpoint, set:

```text
GODOT_MCP_CHATGPT_RELAY_URL=wss://...
```

Normal release users should not need to set the relay URL.

## Continuity

Read:

- `docs/DEVELOPMENT_PLAN.md`
- `docs/PROGRESS.md`

before continuing implementation in a new development window.
