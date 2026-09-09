# Development Progress

This file is the handoff source of truth for future ChatGPT windows and development sessions.

## Project identity

- Repository: `https://github.com/AAAYNMMM/godot-mcp-chatgpt`
- Owner: `AAAYNMMM`
- Branch: `main`
- Visibility: public
- Development interface requested by user: `MCPcoding`
- Finished product dependency on CWapi: **none**
- Target Godot: Godot 4.7.2 Standard x64
- Godot scripting: GDScript
- Main user platform: Windows

## Goal

Build a purpose-specific remote MCP path:

```text
Web ChatGPT
  -> remote MCP (Streamable HTTP)
  -> authenticated tunnel/relay
  -> local bridge
  -> localhost Godot addon
  -> Godot Editor
```

Connection UX target:

```text
Tunnel ID + API Key
```

This should replace using CWapi Coding mode as the runtime control path for Godot. MCPcoding is only being used to develop this repository.

## Current status

Last updated: 2026-09-09

### Completed

- [x] User approved the Web ChatGPT -> MCP -> Godot architecture.
- [x] Decided not to use a GitHub fork.
- [x] Decided to migrate/reimplement only required upstream pieces.
- [x] Created public GitHub repository `AAAYNMMM/godot-mcp-chatgpt`.
- [x] Confirmed the repository has a `main` branch.
- [x] Opened a dedicated MCPcoding durable workspace for this repository.
- [x] Added the initial development plan.
- [x] Added this progress/handoff document.

### Important environment note

When repository creation was performed through MCPcoding, CWapi's process environment had:

```text
GH_CONFIG_DIR=E:\Downloads\cwapi2005\CWapi-data\auth\github
```

That location was not logged into GitHub.

The user's actual Windows GitHub CLI configuration was found at:

```text
C:\Users\11830\AppData\Roaming\GitHub CLI
```

Using that directory explicitly confirmed the active authenticated account:

```text
AAAYNMMM
```

For future local `gh` commands through MCPcoding, if `gh auth status` unexpectedly reports no login, invoke it with the user's global config, for example in PowerShell:

```powershell
$env:GH_CONFIG_DIR='C:\Users\11830\AppData\Roaming\GitHub CLI'
gh auth status
```

Do not ask the user to log in again unless that global config genuinely stops working.

## Architecture decisions locked in

- [x] Godot-side listener stays localhost-only.
- [x] Public exposure happens through a dedicated relay/tunnel layer.
- [x] Prefer an outbound persistent local connection instead of inbound port forwarding.
- [x] Public MCP target is Streamable HTTP.
- [x] Tunnel ID identifies a local connection but is not the secret.
- [x] API key is the authentication secret.
- [x] Do not route editor operations through Coding mode in the finished product.
- [x] Do not add arbitrary shell execution as a default Godot MCP feature.
- [x] Optimize the MCP tool surface for Web ChatGPT rather than exposing a huge static catalog by default.
- [x] Preserve MIT attribution/license notices for any migrated upstream source.

## Upstream candidates

Primary projects to audit next:

- `NPGameDev/godot-mcp-server`
- `NPGameDev/godot-mcp-toolkit`

Do not blindly copy the full repositories. Inspect license and component boundaries first.

## Next task — Phase 1

Status: **NOT STARTED**

The next window should do the following without asking the user to restate the project:

1. Open/resume this exact repository with MCPcoding:
   - repository URL: `https://github.com/AAAYNMMM/godot-mcp-chatgpt.git`
   - target ref: `main`
2. Read:
   - `docs/DEVELOPMENT_PLAN.md`
   - `docs/PROGRESS.md`
3. Audit the two upstream projects:
   - exact license files;
   - server package/runtime;
   - MCP entrypoint/transport;
   - Godot bridge;
   - tool registry/schema;
   - addon entrypoint;
   - addon local socket;
   - addon request dispatch.
4. Write the audit result back into this file or a new `docs/UPSTREAM_AUDIT.md`.
5. Add repository licensing files:
   - project `LICENSE`;
   - `THIRD_PARTY_NOTICES.md`.
6. Migrate only the smallest local working slice.
7. Build/test it.
8. Update this file before ending the development session.

## Phase tracking

| Phase | State | Notes |
|---|---|---|
| 0. Repository + continuity docs | In progress | Initial docs being committed |
| 1. Upstream audit + minimal migration | Not started | Next task |
| 2. Streamable HTTP MCP | Not started | Preserve local baseline first |
| 3. Tunnel ID + API key | Not started | Includes relay/reconnect |
| 4. Godot editor UX | Not started | Dock/panel controls |
| 5. Web GPT optimization | Not started | Tool discovery/compact schemas |
| 6. Hardening + release | Not started | Tests, packaging, security |

## Development-session update rule

Every meaningful development session should update this file before finishing.

Record:
- date;
- commit SHA;
- files/components added;
- tests run and results;
- decisions changed;
- known bugs/blockers;
- the single best next task.

This is required so a new Web ChatGPT window can resume without relying on chat memory.

## Known blockers

None at the architecture/documentation stage.

## Best next action

Start the upstream audit and establish a local working baseline before implementing any Internet-facing relay code.
