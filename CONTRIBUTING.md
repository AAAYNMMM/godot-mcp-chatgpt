# Contributing

[English] | [简体中文](CONTRIBUTING.zh-CN.md)

Thanks for helping improve `godot-mcp-chatgpt`.

The project values **small, testable improvements that make a real Godot workflow easier** over large speculative tool dumps.

## Good contributions

Especially useful contributions include:

- reproducible compatibility results on another Godot 4.x version;
- focused bug fixes with a clear before/after case;
- a new MCP tool justified by a concrete editor workflow;
- better error messages or diagnostics;
- security hardening;
- Windows packaging improvements;
- work toward macOS/Linux runtime support;
- documentation corrections from first-time users;
- tests that reproduce a real connector failure.

## Before proposing a large feature

Open an issue first and describe:

1. what you are trying to do in Godot;
2. what is impossible or awkward with the current tools;
3. what minimum new capability would unlock the workflow;
4. whether it is read-only, mutating, or destructive;
5. how it can be tested in a disposable project.

This keeps the MCP surface compact and easier for models to use reliably.

## Architecture rule

The current production topology is intentional:

```text
ChatGPT
 -> OpenAI Secure MCP Tunnel
 -> official OpenAI tunnel-client
 -> Godot loopback Streamable HTTP MCP
 -> Godot CommandRegistry
 -> Godot Editor API
```

Do not replace the official tunnel-client with another custom implementation without a concrete compatibility reason and an architecture discussion.

Do not add CWapi as a runtime dependency.

## Tool design guidelines

A new tool should:

- solve a repeated user workflow;
- have a narrow name and responsibility;
- use a compact JSON schema;
- expose honest MCP annotations;
- avoid arbitrary filesystem or shell access;
- preserve `res://` boundaries where applicable;
- return structured, useful error information;
- be safe to test on a disposable scene/project;
- avoid duplicating another tool with slightly different naming.

Prefer one useful batch operation over many tiny round trips when the workflow naturally belongs together.

## Development environment

Current validated target:

```text
Windows x64
Godot 4.7.2 Standard x64
GDScript
```

The repository also contains a development-only TypeScript control-plane harness under `server/`.

## Required checks

Before submitting a meaningful code change, run the relevant checks.

Godot scripts should compile under the target Godot version.

Test harness:

```text
cd server
npm install
npm run build
npm test
```

For transport/editor changes, also run the production Godot GUI smoke path if your environment supports it.

A contribution should not claim a test passed unless it was actually run.

## Documentation

User-facing documentation should remain available in English and Simplified Chinese when practical.

For a new user-facing document, prefer paired files:

```text
NAME.md
NAME.zh-CN.md
```

Keep commands, identifiers and exact error strings unchanged when translating.

Do not add decorative screenshots, badges, GIFs or other images unless the repository policy changes explicitly.

## Development progress bookkeeping

For repository development work, documentation is part of the definition of done.

After every logically complete task:

1. run the relevant targeted validation;
2. update the active `docs/DEVELOPMENT_<version>.md` tracker when an active version exists;
3. update `docs/PROGRESS.md` with the actual result and current next priority;
4. synchronize the Simplified Chinese counterpart;
5. only then move to the next task.

Code written without the required validation/progress update is still work in progress.

See [Development Workflow](docs/DEVELOPMENT_WORKFLOW.md).
## Security

Never commit:

- Runtime API Keys;
- Tunnel credentials;
- shard tokens;
- generated profiles containing secrets;
- private project data used only for local testing.

Read [SECURITY.md](SECURITY.md) before changing authentication, local HTTP behavior, filesystem tools or process startup.

## Pull request scope

Smaller PRs are easier to review. Avoid mixing:

- a transport rewrite;
- a large tool expansion;
- documentation redesign;
- unrelated formatting changes

into one change unless they are inseparable.

## Bug reports

Useful reports include:

```text
OS:
Godot version:
Plugin version/commit:
Panel reached connected: yes/no
ChatGPT connector created: yes/no
Tools discovered:
Minimal reproduction:
Exact non-secret error:
```

Never include credentials.

## License

By contributing, you agree that your contribution is provided under the repository's project license. Third-party code must keep its original license and attribution requirements.