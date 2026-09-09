# godot-mcp-chatgpt

Remote MCP bridge for Web ChatGPT to control the Godot editor directly, without using a general-purpose coding workspace as the runtime control path.

Target path:

```text
Web ChatGPT
  -> MCP over HTTPS
  -> authenticated relay/tunnel
  -> local bridge
  -> Godot editor addon
  -> Godot
```

The intended pairing UX is a simple **Tunnel ID + API Key** while keeping the Godot-side listener bound to localhost.

## Development status

The project is currently in the architecture/bootstrap stage.

- [Development plan](docs/DEVELOPMENT_PLAN.md)
- [Progress and new-window handoff](docs/PROGRESS.md)

The next milestone is an upstream audit and minimal local migration from compatible MIT-licensed Godot MCP projects, followed by a working local bridge baseline before remote transport is added.
