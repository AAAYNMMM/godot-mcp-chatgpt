# Security

[English] | [简体中文](SECURITY.zh-CN.md)

`godot-mcp-chatgpt` lets an authorized remote ChatGPT Connector read and change a live Godot project. Version 0.4.0 therefore treats filesystem reach, credential storage, runtime control, process execution, and destructive operations as explicit security boundaries.

## 0.4.0 runtime path

```text
ChatGPT
 -> OpenAI Secure MCP Tunnel
 -> official OpenAI tunnel-client
 -> random 127.0.0.1 Streamable HTTP MCP endpoint
 -> Godot CommandRegistry
 -> Godot Editor API
      or
 -> EditorDebuggerPlugin -> EngineDebugger -> running game
```

The addon does not implement the OpenAI tunnel wire protocol itself.

## Local MCP exposure

The Godot-hosted MCP server:

- binds only to `127.0.0.1`;
- chooses a random high port per run;
- chooses a random URL path per run;
- is intended only as the local backend for the bundled official tunnel client;
- does not intentionally listen on LAN/public interfaces.

## Runtime API Key handling

On Windows 0.4.0:

- Tunnel ID is persisted in Godot `EditorSettings`;
- Runtime API Key is stored as a **Windows Generic Credential** in Windows Credential Manager;
- the plugin-specific credential target is `godot-mcp-chatgpt/0.4/OpenAI/Tunnel/APIKey`;
- the plaintext key is not written into `project.godot`, Git, or the generated tunnel YAML profile;
- the generated profile references `env:CONTROL_PLANE_API_KEY`;
- Godot temporarily sets that environment variable while spawning the official `tunnel-client`, then removes it from the parent Godot process environment and clears its in-memory copy;
- the child `tunnel-client` necessarily inherits the environment value while it is running;
- **Forget Saved Credentials** removes both the saved Tunnel ID and the Windows Credential Manager entry.

A sufficiently privileged process running as the same Windows user may be able to inspect another process environment while the tunnel client is alive. Credential Manager persistence protects the key from project/Git/config-file leakage; it is not a sandbox against a compromised local account.

Use a dedicated restricted Runtime API Key with only the tunnel permissions required by the intended OpenAI workspace.

## Filesystem boundary

Project file and Resource tools operate inside `res://`.

0.4.0 explicitly rejects:

- `res://../...` traversal;
- Windows/absolute project-external file paths;
- invalid Resource source/target paths before Resource load/save.

The real ChatGPT Connector regression verified these boundaries. Expanding filesystem access outside `res://` requires separate security review.

## Scene and node safeguards

Examples:

- `scene.create` refuses to overwrite an existing scene unless `overwrite: true` is supplied;
- `node.delete` refuses to delete the edited scene root;
- invalid Node classes/properties/methods return errors rather than falling back to arbitrary behavior;
- signal/group/metadata edits remain scoped to the current Godot project/scene.

## Runtime Debugger boundary

0.4.0 adds a runtime bridge using Godot's own debugger channel:

```text
EditorDebuggerPlugin
 <-> Godot remote-debug session
 <-> EngineDebugger
 <-> GodotMCPChatGPTRuntime autoload
```

The bridge does not open a second public network listener. Runtime changes affect the running instance; they are not automatically written back to the saved editor scene.

The reserved autoload is removed when the editor plugin is disabled and supports Godot 4.7.2 `uid://` path normalization.

## Diagnostics boundary

`diagnostics.run_capture` is deliberately not a generic process/shell tool.

It can only launch:

- the current Godot executable;
- against the current project;
- with an optional project-local `res://` scene;
- with bounded timeout and output size.

It returns separate stdout/stderr, exit code, timeout state, duration and truncation state.

## Batch boundary

`batch.execute`:

- has a bounded operation count and payload size;
- executes existing registered MCP tools only;
- rejects recursive `batch.*` invocation;
- can stop on the first error;
- is **non-atomic** and does not roll back earlier successful operations.

## No arbitrary shell MCP tool

Version 0.4.0 does not expose a generic arbitrary shell/PowerShell/cmd executable tool through MCP. Adding one would materially change the trust boundary and requires explicit security review.

## Recommended user practices

1. Use Git or another version-control system.
2. Commit/checkpoint important work before large AI-driven edits.
3. Use a dedicated restricted Runtime API Key.
4. Never paste active credentials into chats, screenshots, issues, logs, or test fixtures.
5. Test unfamiliar destructive workflows in disposable scenes first.
6. Review large edits before committing them.
7. Use **Forget Saved Credentials** before rotating/removing access if you no longer want automatic reconnect.
8. Treat anyone with access to the authorized ChatGPT workspace/tunnel as able to exercise the MCP permissions you exposed.

## Validation

0.4.0 security/reliability validation includes:

```text
BOM_CHECK=PASS
SECRET_CHECK=PASS
CATALOGUE_SCHEMA_GATE=PASS tools=119
PRODUCTION_PLUGIN_SMOKE=PASS
CREDENTIAL_RESTART_SMOKE=PASS
RUNTIME_AUTOLOAD_LIFECYCLE_SMOKE=PASS
REAL_CHATGPT_GODOT_MCP_0_4_TEST=PASS
```

The real Connector test exercised traversal rejection, project-external path rejection, scene-root delete denial, invalid class/property/method errors, bounded Diagnostics, and Batch recursion denial.

## Supported trust boundary

The project assumes:

- the local Windows account running Godot is trusted;
- the official OpenAI tunnel runtime is trusted as a bundled third-party component;
- the selected OpenAI/ChatGPT workspace and tunnel are intentionally authorized to access this Godot instance;
- Godot itself and project scripts/plugins run with the permissions of the local Godot process.

The addon does not attempt to sandbox Godot from its own plugins or from a compromised local account.

## Reporting a security issue

Do not publish secrets or an active exploit containing user credentials in a public issue.

A useful security report should include:

- affected plugin version/commit;
- OS and Godot version;
- clear impact;
- minimal reproduction steps;
- whether the issue crosses `res://`, loopback networking, Credential Manager handling, Runtime Debugger, Diagnostics, Batch, or destructive-operation boundaries;
- non-secret logs only.

If no private reporting channel is configured, open a public issue containing only non-sensitive metadata and ask for a private contact path.

## Third-party runtime

The bundled official OpenAI `tunnel-client` retains its upstream Apache-2.0 license and NOTICE. Runtime identity and SHA-256 are documented in the README and `addons/godot_mcp_chatgpt/bin/RUNTIME_INFO.txt`.

## Changes requiring extra security review

Treat these as security-sensitive:

- arbitrary shell/process execution beyond the bounded Godot diagnostics runner;
- access outside `res://`;
- non-loopback MCP listeners;
- changing Runtime API Key storage away from Windows Credential Manager without an equivalent protected store;
- exposing the local MCP endpoint directly to the Internet;
- weakening overwrite/delete/path safeguards;
- accepting unauthenticated remote transports outside the official tunnel path.