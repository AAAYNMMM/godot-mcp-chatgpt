import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

const repo = path.resolve(import.meta.dirname, "../..");
const versionMatch = fs.readFileSync(path.join(repo, "addons/godot_mcp_chatgpt/plugin.cfg"), "utf8").match(/version="([^"]+)"/);
if (!versionMatch) throw new Error("plugin version not found");
const version = versionMatch[1];
const installer = process.argv[2] ? path.resolve(process.argv[2]) : path.join(repo, `dist/v${version}/godot-mcp-chatgpt-v${version}-windows-x64-installer.exe`);
const godotExe = process.argv[3] || process.env.GODOT_EXE || "";
const root = path.join(repo, ".local-test", "installer");
const projectA = path.join(root, "Installer Test 项目");
const projectB = path.join(root, "No Enable 项目");
const resultDir = path.join(root, "results");

function write(p, text) {
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, text, "utf8");
}

function runInstaller(project, extra = [], resultName = "result.json") {
  const result = path.join(resultDir, resultName);
  fs.rmSync(result, { force: true });
  const child = spawnSync(installer, ["--project", project, "--silent", "--result", result, ...extra], {
    cwd: repo,
    windowsHide: true,
    encoding: "utf8",
    timeout: 30000,
  });
  const parsed = fs.existsSync(result) ? JSON.parse(fs.readFileSync(result, "utf8")) : null;
  return { child, parsed, result };
}

function listFiles(rootDir) {
  const out = [];
  function visit(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) visit(full);
      else out.push(path.relative(rootDir, full).replaceAll("\\", "/"));
    }
  }
  visit(rootDir);
  return out.sort();
}

function sha256(file) {
  return crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
}

function assertAddonExact(installedRoot) {
  const sourceRoot = path.join(repo, "addons/godot_mcp_chatgpt");
  const sourceFiles = listFiles(sourceRoot);
  const installedFiles = listFiles(installedRoot);
  assert.deepEqual(installedFiles, sourceFiles, "installed addon file set differs from source addon");
  for (const rel of sourceFiles) {
    assert.equal(sha256(path.join(installedRoot, rel)), sha256(path.join(sourceRoot, rel)), `addon payload hash mismatch: ${rel}`);
  }
}

function assertNoInstallTemps(project) {
  const names = fs.readdirSync(project);
  assert.ok(!names.some((n) => n.startsWith(".godot-mcp-chatgpt-install-")), `staging residue in ${project}`);
  assert.ok(!names.some((n) => n.startsWith(".godot-mcp-project-")), `project temp residue in ${project}`);
  const addons = path.join(project, "addons");
  if (fs.existsSync(addons)) {
    assert.ok(!fs.readdirSync(addons).some((n) => n.startsWith("godot_mcp_chatgpt.backup-")), `addon backup residue in ${project}`);
  }
}

fs.rmSync(root, { recursive: true, force: true });
fs.mkdirSync(resultDir, { recursive: true });
assert.ok(fs.existsSync(installer), `installer missing: ${installer}`);

// Project A: CRLF + an existing unrelated plugin. This also proves spaces + Unicode argv handling.
write(path.join(projectA, "project.godot"), [
  "; Engine configuration file.",
  "config_version=5",
  "",
  "[application]",
  "config/name=\"Installer Smoke 项目\"",
  "",
  "[editor_plugins]",
  "enabled=PackedStringArray(\"res://addons/other/plugin.cfg\")",
  "",
].join("\r\n"));
write(path.join(projectA, "addons/other/plugin.cfg"), "[plugin]\nname=\"Other\"\n");

let run = runInstaller(projectA, [], "install.json");
assert.equal(run.child.error, undefined, `installer spawn error: ${run.child.error}`);
assert.equal(run.child.status, 0, `install exit=${run.child.status} stderr=${run.child.stderr}`);
assert.ok(run.parsed?.ok, `install result not ok: ${JSON.stringify(run.parsed)}`);
assert.equal(run.parsed.version, version);
assert.equal(run.parsed.upgraded, false);
assert.equal(run.parsed.enabled, true);
assert.equal(path.normalize(run.parsed.project), path.normalize(projectA));
const targetA = path.join(projectA, "addons/godot_mcp_chatgpt");
assert.ok(fs.existsSync(path.join(targetA, "plugin.cfg")));
assert.ok(fs.existsSync(path.join(targetA, "bin/windows/tunnel-client.exe")));
assert.ok(fs.existsSync(path.join(targetA, "bin/windows/godot-mcp-credential.exe")));
assert.ok(fs.existsSync(path.join(targetA, "bin/windows/godot-mcp-runner.exe")));
assertAddonExact(targetA);
let projectText = fs.readFileSync(path.join(projectA, "project.godot"), "utf8");
assert.ok(projectText.includes("res://addons/other/plugin.cfg"), "existing plugin was lost");
assert.ok(projectText.includes("res://addons/godot_mcp_chatgpt/plugin.cfg"), "MCP plugin not enabled");
assert.equal((projectText.match(/res:\/\/addons\/godot_mcp_chatgpt\/plugin\.cfg/g) || []).length, 1, "MCP plugin enabled more than once");
assert.ok(projectText.includes("\r\n"), "CRLF style was not preserved");
assertNoInstallTemps(projectA);
console.log("INSTALLER_CLEAN_INSTALL=PASS");

// Upgrade must replace the whole addon and remove stale files while preserving project plugin configuration.
write(path.join(targetA, "STALE_OLD_FILE.txt"), "must disappear");
run = runInstaller(path.join(projectA, "project.godot"), [], "upgrade.json");
assert.equal(run.child.status, 0, `upgrade exit=${run.child.status} stderr=${run.child.stderr}`);
assert.ok(run.parsed?.ok);
assert.equal(run.parsed.upgraded, true);
assert.equal(run.parsed.enabled, true);
assert.ok(!fs.existsSync(path.join(targetA, "STALE_OLD_FILE.txt")), "stale file survived upgrade");
projectText = fs.readFileSync(path.join(projectA, "project.godot"), "utf8");
assert.equal((projectText.match(/res:\/\/addons\/godot_mcp_chatgpt\/plugin\.cfg/g) || []).length, 1, "upgrade duplicated plugin entry");
assert.ok(projectText.includes("res://addons/other/plugin.cfg"), "upgrade removed unrelated plugin");
assertNoInstallTemps(projectA);
console.log("INSTALLER_UPGRADE=PASS");

// Project B: --no-enable must install files without creating editor_plugins state.
write(path.join(projectB, "project.godot"), "config_version=5\n\n[application]\nconfig/name=\"No Enable\"\n");
run = runInstaller(projectB, ["--no-enable"], "no-enable.json");
assert.equal(run.child.status, 0);
assert.ok(run.parsed?.ok);
assert.equal(run.parsed.enabled, false);
assert.ok(fs.existsSync(path.join(projectB, "addons/godot_mcp_chatgpt/plugin.cfg")));
const noEnableText = fs.readFileSync(path.join(projectB, "project.godot"), "utf8");
assert.ok(!noEnableText.includes("res://addons/godot_mcp_chatgpt/plugin.cfg"), "--no-enable modified plugin list");
assertNoInstallTemps(projectB);
console.log("INSTALLER_NO_ENABLE=PASS");

// Invalid project must fail silently, return JSON, and must not create the path.
const missing = path.join(root, "Missing Project 路径");
run = runInstaller(missing, [], "invalid.json");
assert.equal(run.child.status, 11, `invalid project exit=${run.child.status}`);
assert.equal(run.parsed?.ok, false);
assert.match(run.parsed?.message || "", /does not exist/i);
assert.ok(!fs.existsSync(missing), "invalid path was created");
console.log("INSTALLER_INVALID_PROJECT=PASS");

// Optional real Godot validation. No machine path is hard-coded in this test.
if (godotExe) {
  assert.ok(fs.existsSync(godotExe), `Godot executable missing: ${godotExe}`);
  const appData = path.join(root, "godot-appdata");
  fs.mkdirSync(appData, { recursive: true });
  const testTarget = `godot-mcp-chatgpt/test/installer-${Date.now()}`;
  const env = {
    ...process.env,
    APPDATA: appData,
    GODOT_MCP_CHATGPT_CREDENTIAL_TEST_TARGET: testTarget,
  };
  delete env.GODOT_MCP_CHATGPT_TUNNEL_ID;
  delete env.GODOT_MCP_CHATGPT_API_KEY;
  delete env.GODOT_MCP_CHATGPT_CONTROL_PLANE_URL;
  const godot = spawnSync(godotExe, ["--path", projectA, "--editor", "--headless", "--quit-after", "5"], {
    cwd: projectA,
    env,
    encoding: "utf8",
    timeout: 30000,
    windowsHide: true,
  });
  assert.equal(godot.error, undefined, `Godot spawn error: ${godot.error}`);
  assert.equal(godot.status, 0, `Godot exit=${godot.status}\nstdout=${godot.stdout}\nstderr=${godot.stderr}`);
  const combined = `${godot.stdout}\n${godot.stderr}`;
  assert.match(combined, /\[GodotMCPChatGPT\] Editor plugin loaded\./, "installed plugin did not load in Godot");
  assert.ok(!/Parse Error|SCRIPT ERROR|Failed to load script/i.test(combined), `Godot plugin load errors:\n${combined}`);
  const afterGodot = fs.readFileSync(path.join(projectA, "project.godot"), "utf8");
  assert.ok(afterGodot.includes("GodotMCPChatGPTRuntime"), "runtime autoload was not registered by installed plugin");
  console.log("INSTALLER_GODOT_4_7_2_LOAD=PASS");
}

console.log(`INSTALLER_SMOKE=PASS version=${version}`);
