# Releasing

English | [简体中文](RELEASING.zh-CN.md)

This checklist turns the v0.4.0 release procedure into a repeatable maintainer workflow.

## 1. Release source must be coherent

Before tagging:

- working tree contains only intended release changes;
- plugin version and public docs agree;
- `CHANGELOG` contains the release;
- `README` describes released behavior only;
- `PROGRESS` has no stale blocker/WIP claims for the release;
- `DEVELOPMENT_<version>` is ready to close.

## 2. Required validation

Run the tests relevant to the changed surface. For a release touching the complete addon, the v0.4.0 baseline includes:

```text
Godot addon load/compile
npm build
npm test
catalogue/schema gate
production plugin smoke
credential lifecycle when credential code changed
runtime autoload lifecycle when runtime lifecycle changed
installer smoke when installer/package changed
documentation link/BOM/format checks
secret scan
```

For a public capability release, perform a real ChatGPT Connector regression when practical.

Do not mark a gate PASS unless it actually ran.

## 3. Repository hygiene

Verify:

- no `.local-test/`, `.mcp-smoke/`, `.mcp-real-test/`, `dist/`, payload temp files, or secrets are staged;
- `git diff --check` passes;
- UTF-8 BOM policy passes;
- documentation links resolve;
- generated artifacts are excluded from source commits unless intentionally versioned.

## 4. Commit and push source first

Release artifacts must be built from the exact source commit that will be tagged.

Recommended order:

```text
validate
→ commit
→ push
→ verify local/origin alignment
→ build artifacts from that exact commit
```

## 5. Build release artifacts

For the Windows installer release:

```powershell
powershell -ExecutionPolicy Bypass -File tools/installer/build.ps1
```

Expected outputs:

```text
godot-mcp-chatgpt-v<version>-windows-x64-installer.exe
godot-mcp-chatgpt-v<version>-addon.zip
SHA256SUMS.txt
```

## 6. Re-test built artifacts

Do not assume a successful source test proves the built installer.

At minimum verify:

- clean install;
- upgrade;
- invalid project rejection;
- Unicode/space path;
- Godot load of the installed addon;
- embedded/released addon file set matches source;
- SHA-256 manifest matches actual artifacts.

## 7. Publish the GitHub Release

Create the version tag against the exact validated release commit.

Upload:

- installer EXE;
- addon ZIP;
- SHA-256 manifest.

Do not move an existing public release tag to a later documentation-only commit.

## 8. Verify remote assets

After publication:

1. read back the GitHub Release metadata;
2. confirm tag target;
3. download the published assets again;
4. compare their hashes with the locally validated artifacts.

The release is not considered fully verified until the remote assets match.

## 9. Close documentation state

After successful publication:

- mark the version record complete/released;
- update `PROGRESS` to current state;
- archive historical implementation logs if they make current status unclear;
- keep future work in `DEVELOPMENT_PLAN`.

A documentation-only commit after the tag is acceptable as long as the release tag remains attached to the exact validated source commit.