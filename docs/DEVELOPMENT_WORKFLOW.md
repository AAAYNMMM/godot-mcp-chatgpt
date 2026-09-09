# Development Workflow

English | [简体中文](DEVELOPMENT_WORKFLOW.zh-CN.md)

This document defines the repository's development bookkeeping rules. It is not optional process documentation: it is part of the definition of done for development work.

## 1. Sources of truth

Use the documents for different levels of truth:

| Document | Purpose | What it may claim |
| --- | --- | --- |
| `README.md` | Public product entry | Released or explicitly validated user-facing behavior only |
| `docs/TOOL_REFERENCE.md` | Public tool contract | Tools available on the validated release/main baseline only |
| `CHANGELOG.md` | Release history | Shipped changes only |
| `docs/DEVELOPMENT_PLAN.md` | Long-term roadmap | Milestones, architecture rules and planned phases |
| `docs/DEVELOPMENT_<version>.md` | Version record | Active tracker while developing; closed technical record after release |
| `docs/PROGRESS.md` | Current status / handoff | Current release, actual validation, current limitations, and current priorities |

Do not copy unvalidated work-in-progress claims into README, Tool Reference or Changelog.

## 2. Definition of done

A development task is **not complete** merely because code was written.

A task may be marked complete only when all applicable items are true:

1. implementation is present;
2. the relevant targeted validation was actually run;
3. failures found by that validation were resolved or explicitly recorded as blockers;
4. `docs/PROGRESS.md` was updated with the result;
5. the active version tracker was updated when an active version exists;
6. the Simplified Chinese counterpart was synchronized for development documents that have a paired translation.

If validation has not run yet, use `implemented / validation pending`, not `complete`.

## 3. Required progress update cadence

Update `docs/PROGRESS.md` **after every logically complete task**, before moving to the next task.

Examples of a task boundary:

- credential storage implementation + credential round-trip test;
- Project command module + Godot compile test;
- Scene/Node module + Godot compile test;
- runtime debugger bridge + runtime smoke test;
- production registration + full catalogue/schema test;
- release regression + release commit.

Do not wait until the end of a long multi-hour development session to reconstruct progress from memory.

## 4. Progress entry format

Each completed task entry should record:

```text
Task:
Status:
Files / module:
What changed:
Validation actually run:
Result:
Known limitation / blocker:
Exact next task:
```

Keep entries factual. Never promote an unrun test to a pass, and never describe a simulator result as a real ChatGPT production result.

## 5. Status vocabulary

Use these states consistently:

- `planned` — accepted work, implementation not started;
- `in progress` — active implementation;
- `implemented / validation pending` — code exists but required validation has not passed;
- `targeted validation passed` — module-level validation passed, broader integration still pending;
- `blocked` — cannot proceed without resolving a named blocker;
- `integration passed` — integrated production path passed its defined integration test;
- `release validated` — full release gate passed;
- `complete` — the task's intended acceptance criteria and documentation update are complete.

## 6. Active-version tracker

Large development versions must have a dedicated tracker such as:

```text
docs/DEVELOPMENT_0.4.md
docs/DEVELOPMENT_0.4.zh-CN.md
```

The tracker should contain:

- scope and non-goals;
- module checklist;
- tool groups;
- validation gates;
- security decisions;
- known blockers;
- exact release acceptance criteria.

It is allowed to describe uncommitted working-tree work, but that status must be explicit.

## 7. Bilingual rule

Development-plan, active-version and progress documents are maintained in English and Simplified Chinese.

When a task changes one of these documents, update its paired translation in the same task. Exact identifiers, commands, tool names, error strings, hashes and version numbers must not be translated.

## 8. Release-document boundary

During active development:

- `docs/DEVELOPMENT_<version>.md` may list tools that are still being built;
- `docs/PROGRESS.md` may describe uncommitted working-tree state;
- `docs/TOOL_REFERENCE.md` must continue to describe the last validated public baseline until the new version passes integration/release gates.

Only after release validation should the public Tool Reference, README and Changelog be promoted to the new capability set.

## 9. Required gate before commit/push

Before a development version is pushed as a validated baseline, run the applicable gates and record them in `docs/PROGRESS.md`:

- Godot target-version script compilation;
- focused module tests;
- MCP tool catalogue/schema validation;
- local Streamable HTTP MCP test;
- official tunnel-client integration test when transport-facing code changed;
- real Godot GUI smoke for editor mutations;
- credential persistence/restart test when credential code changed;
- secret scan;
- BOM / `git diff --check` / repository hygiene checks;
- documentation link checks when docs changed materially.

The exact gates may expand, but they may not silently shrink for convenience.

## 10. Handoff rule

Before ending a development window, `docs/PROGRESS.md` must state:

- current branch / intended version;
- completed work since the previous entry;
- validation evidence;
- current blocker;
- exact next task;
- whether work is committed/pushed or only present in the durable working tree.

A new development window should read, in order:

1. `docs/ARCHITECTURE.md`
2. `docs/DEVELOPMENT_PLAN.md`
3. active `docs/DEVELOPMENT_<version>.md`
4. `docs/PROGRESS.md`

before changing architecture or tool contracts.
## 11. Release closure and history

After a version is published:

- change its active version tracker into a closed release record;
- remove stale `in progress`, blocker, and next-task language for that version;
- keep `PROGRESS.md` concise and current;
- move long chronological implementation history to `PROGRESS_ARCHIVE_<range>.md`;
- keep future candidate work in `DEVELOPMENT_PLAN.md`.

Public users should not need to read historical WIP logs to understand the current release.