# Security

[English] | [简体中文](SECURITY.zh-CN.md)

`godot-mcp-chatgpt` gives a remote ChatGPT session the ability to change a live Godot project. That is useful, but it also means the tool boundary should stay explicit and narrow.

## Current security model

Version 0.3.0 uses this runtime path:

```text
ChatGPT
 -> OpenAI Secure MCP Tunnel
 -> official OpenAI tunnel-client
 -> 127.0.0.1 Streamable HTTP MCP
 -> Godot editor tools
```

### Local MCP exposure

The Godot-hosted MCP server:

- binds only to `127.0.0.1`;
- chooses a random high port per run;
- chooses a random URL path per run;
- is not intended to be reachable from the LAN or Internet directly.

### Runtime API Key handling

The addon:

- persists Tunnel ID only;
- does not persist the Runtime API Key in Godot `EditorSettings`;
- does not write the plaintext key into the generated tunnel profile;
- references the key as `env:CONTROL_PLANE_API_KEY`;
- removes the key from the parent Godot process environment after the child process is started.

Users should create a dedicated restricted Runtime API Key with the minimum tunnel permissions required by their OpenAI workspace.

### Filesystem boundary

Current file tools operate inside `res://` and reject `..` traversal.

This is a deliberate boundary. A future feature that expands filesystem reach should be treated as a security-sensitive design change.

### Destructive operations

Examples of current safeguards:

- `scene.create` refuses to overwrite an existing scene unless `overwrite: true` is explicitly provided;
- `node.delete` cannot delete the edited scene root;
- MCP annotations mark destructive operations where applicable;
- there is no generic arbitrary shell execution tool.

## User safety recommendations

When using the addon on a real project:

1. use Git or another version-control system;
2. commit or checkpoint important work before large AI-driven edits;
3. use a restricted Runtime API Key;
4. do not share the key in chat, screenshots or issues;
5. test unfamiliar workflows in disposable scenes first;
6. review destructive changes before saving/committing them;
7. disconnect the addon before rotating tunnel credentials.

## Supported trust boundary

The project assumes:

- the local Windows account running Godot is trusted;
- the official OpenAI tunnel runtime is trusted as a bundled third-party component;
- the selected OpenAI/ChatGPT workspace and tunnel are intentionally authorized to access this Godot instance.

The project does not attempt to sandbox the Godot editor from its own plugin process.

## Reporting a security issue

Do not publish secrets or an active exploit containing user credentials in a public issue.

A useful private/security report should include:

- affected plugin version/commit;
- affected OS/Godot version;
- clear impact;
- minimal reproduction steps;
- whether the issue crosses `res://`, loopback-only networking, credential handling, or destructive-operation boundaries;
- non-secret logs only.

If there is no private reporting channel configured yet, open a public issue with **only non-sensitive metadata** asking for a private contact path. Do not include exploit details that expose credentials or private project data.

## Third-party runtime

The bundled OpenAI `tunnel-client` keeps its upstream license and NOTICE. Its runtime identity and SHA-256 are documented in the README and `addons/godot_mcp_chatgpt/bin/RUNTIME_INFO.txt`.

## Scope changes that require extra review

Treat these as security-sensitive:

- arbitrary shell/process execution;
- access outside `res://`;
- listening on non-loopback interfaces;
- persisting Runtime API Keys;
- exposing the local MCP endpoint publicly;
- removing overwrite/delete safeguards;
- accepting unauthenticated remote transports outside the official tunnel path.