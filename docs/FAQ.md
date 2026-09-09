# FAQ and Troubleshooting

[English] | [简体中文](FAQ.zh-CN.md)

## Do I need CWapi?

No. CWapi was useful as a known-good reference during development, but `godot-mcp-chatgpt` 0.3.0 bundles the official OpenAI `tunnel-client` and hosts its own local Godot MCP server.

## Do I need Codex, Cursor or Claude Desktop?

No. The point of this project is to let **Web ChatGPT** reach the Godot editor through Secure MCP Tunnel.

## Do I need Node.js?

Not for normal runtime use. `server/` contains a development-only test harness and is ignored by Godot.

## Why does the addon bundle an executable?

The executable is the official OpenAI `tunnel-client`. Earlier development builds attempted to implement the tunnel wire protocol directly in GDScript. That path could connect to the tunnel but failed real ChatGPT connector creation. The production design now delegates tunnel compatibility to the official runtime and keeps the Godot side focused on MCP + editor tools.

## What does `Status: connected` mean?

In 0.3.0 it means:

- the local Godot MCP server started;
- the official `tunnel-client` child process started and remains alive.

It does **not** by itself prove that ChatGPT has already discovered tools. Tool discovery from ChatGPT is the final confirmation.

## The ChatGPT connector fails to create

Check:

1. Godot is still open.
2. The addon is enabled.
3. The panel shows `Status: connected`.
4. ChatGPT uses exactly the same Tunnel ID.
5. The Runtime API Key has the required tunnel permissions.
6. You are creating a Tunnel connection, not entering the local `127.0.0.1` URL manually.

0.3.0 has been verified with a successful real connector creation flow.

## Godot says connected but ChatGPT shows no tools

Try:

1. keep Godot open;
2. disconnect/reconnect the Godot panel;
3. refresh or recreate the ChatGPT connector using the same Tunnel ID;
4. verify that only one intended Godot instance is using that tunnel;
5. check the last non-secret message in the MCP ChatGPT panel.

Do not send Runtime API Keys in bug reports.

## I restarted Godot and the API key field is empty

Expected. The addon intentionally does not persist the Runtime API Key. Enter it again and reconnect.

## Where is the API key stored?

The addon persists only Tunnel ID in Godot `EditorSettings`. The Runtime API Key is used to start the official tunnel-client through `CONTROL_PLANE_API_KEY` and is not written into the generated tunnel profile.

## Does the local MCP server listen on my LAN?

No. It binds to `127.0.0.1` only, on a random high port with a random per-run path.

## Can ChatGPT run arbitrary shell commands on my computer?

Not through the current Godot tool surface. There is no generic shell MCP tool.

## Can it edit files outside the Godot project?

Current file tools are restricted to `res://` and reject `..` traversal.

## Why did `scene.create` refuse to create a scene that already exists?

This is a safety feature. Existing scenes are not overwritten unless `overwrite: true` is explicitly provided.

## Why can ChatGPT not inspect a property I need?

0.3.0 has `node.set_property`, but rich property enumeration is not implemented yet. Check the roadmap before treating that as a connection failure.

## Why can ChatGPT not open an existing scene?

Dedicated `scene.open` support is not in the initial 13-tool milestone yet.

## Which Godot versions are supported?

The current verified target is Godot 4.7.2 Standard x64 on Windows. Other Godot 4.x versions may work, but should be treated as unverified until tested.

If you test another version, a useful issue includes:

```text
Godot version:
OS:
Plugin version:
Connector created successfully: yes/no
Tools discovered: count
First failing tool/error:
```

## Does the renderer matter?

Not to the MCP transport. The project was developed with low-overhead/Compatibility-friendly Godot workflows in mind, but the connector itself is editor/tooling infrastructure.

## Can multiple ChatGPT conversations use the same tunnel?

The tunnel/runtime may accept multiple remote calls, but Godot editor mutation is stateful. Treat one active editing workflow per Godot instance as the safest default until multi-session behavior is deliberately tested and documented.

## Why not expose hundreds of Godot tools immediately?

Large MCP tool surfaces increase maintenance cost, context/tool-schema overhead and ambiguity. This project prefers a smaller set of high-frequency tools, then expands based on real user workflows.

## How should I report a bug?

Please include:

- Godot version;
- OS;
- plugin commit/version;
- whether the panel reached `connected`;
- whether connector creation succeeded;
- exact non-secret error text;
- smallest steps to reproduce;
- whether the problem is read-only, scene/node/script mutation, or editor run/stop.

Never include API keys, shard tokens or credentials.

## I have a tool idea. What makes a good proposal?

Describe the workflow, not only the method name. Good example:

> I need to inspect a node's editable properties before changing them, because currently ChatGPT must guess property names.

That is more actionable than:

> Add 100 more node tools.

See [CONTRIBUTING.md](../CONTRIBUTING.md).