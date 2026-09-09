# Changelog

English | [简体中文](CHANGELOG.zh-CN.md)

This project is still early. The changelog records meaningful user-facing milestones rather than every internal experiment.

## 0.3.0 — Official tunnel-client architecture

Date: 2026-09-09

### Highlights

- Switched production transport to the **official OpenAI `tunnel-client`**.
- Added a Godot-hosted loopback **Streamable HTTP MCP** server.
- Bundled the validated Windows `tunnel-client.exe` runtime with license/NOTICE.
- Kept the user flow at only **Tunnel ID + Runtime API Key**.
- Preserved non-persistence of Runtime API Key.
- Added `server/discover` and modern/legacy MCP compatibility behavior required by the official client path.
- Added HTTP `DELETE` session termination handling.
- Kept the initial focused 13-tool Godot surface.

### Validation

Passed:

```text
Godot 4.7.2 script compilation
Go MCP SDK v1.7 compatibility
Official tunnel-client bridge smoke
Real Godot 4.7.2 GUI production smoke
Real OpenAI Tunnel + ChatGPT connector creation
```

The real connector creation succeeded on 2026-09-09.

### Architecture change

Removed the production direct-GDScript implementation of OpenAI `/poll` + `/response`.

Production is now:

```text
ChatGPT
 -> OpenAI Secure MCP Tunnel
 -> official OpenAI tunnel-client
 -> Godot loopback Streamable HTTP MCP
 -> Godot Editor API
```

## 0.2.3 — Connector compatibility investigation

- Added `server/discover` compatibility to the earlier direct tunnel implementation.
- Confirmed that local protocol simulation alone was not enough to prove real ChatGPT connector compatibility.
- This version helped identify the need to compare against a known-good tunnel runtime.

## 0.2.2 — Editor panel usability

- Moved the connection UI to a visible Godot bottom panel named **MCP ChatGPT**.
- Improved the first-run user flow.

## 0.2.1 — Credential persistence hardening

- Stopped persisting Runtime API Key in Godot editor settings.
- Kept Tunnel ID persistence for convenience.

## 0.2.0 and earlier — Transport prototyping

- Built the initial Godot editor plugin and command registry.
- Added the first scene/node/script/editor tools.
- Explored a custom relay and later a direct GDScript Secure Tunnel client.
- These transport experiments were superseded by the 0.3.0 official-runtime architecture.