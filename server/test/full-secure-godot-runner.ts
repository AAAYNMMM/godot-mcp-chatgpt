import { spawn, spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createSecureTunnelStub } from "../src/secureTunnelStub.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const serverDir = path.resolve(here, "..");
const repoDir = path.resolve(serverDir, "..");

function resolveGodot(): string {
  const configured = process.env.GODOT_BIN?.trim();
  if (configured && fs.existsSync(configured)) return configured;
  if (process.platform === "win32") {
    const where = spawnSync("where.exe", ["godot.exe"], { encoding: "utf8" });
    const discovered = where.status === 0 ? String(where.stdout).split(/\r?\n/).find(Boolean)?.trim() : "";
    if (discovered && fs.existsSync(discovered)) return discovered;
    const local = process.env.LOCALAPPDATA;
    if (local) {
      const candidate = path.join(local, "Programs", "Godot", "4.7.2", "godot.exe");
      if (fs.existsSync(candidate)) return candidate;
    }
  }
  return "godot";
}

async function killTree(pid: number): Promise<void> {
  if (!Number.isFinite(pid) || pid <= 0) return;
  if (process.platform === "win32") {
    spawnSync("taskkill.exe", ["/PID", String(pid), "/T", "/F"], { stdio: "ignore" });
  } else {
    try { process.kill(-pid, "SIGTERM"); } catch {}
  }
}

const stub = createSecureTunnelStub({ port: 8790 });
const bound = await stub.start();
const godotBin = resolveGodot();
let godotOut = "";
let godotErr = "";
let godot: ReturnType<typeof spawn> | undefined;
try {
  godot = spawn(godotBin, ["--headless", "--editor", "--path", repoDir], {
    cwd: repoDir,
    detached: process.platform !== "win32",
    env: {
      ...process.env,
      GODOT_MCP_CHATGPT_TUNNEL_ID: stub.tunnelId,
      GODOT_MCP_CHATGPT_API_KEY: stub.apiKey,
      GODOT_MCP_CHATGPT_CONTROL_PLANE_URL: `http://${bound.host}:${bound.port}`,
    },
    stdio: ["ignore", "pipe", "pipe"],
  });
  godot.stdout?.on("data", (chunk) => { godotOut = (godotOut + String(chunk)).slice(-200_000); });
  godot.stderr?.on("data", (chunk) => { godotErr = (godotErr + String(chunk)).slice(-200_000); });

  await new Promise((resolve) => setTimeout(resolve, 2200));
  if (godot.exitCode !== null) throw new Error(`Godot exited during startup with code ${godot.exitCode}\n${godotErr}`);

  const runner = process.execPath;
  const tsxCli = path.join(serverDir, "node_modules", "tsx", "dist", "cli.mjs");
  const smoke = spawn(runner, [tsxCli, "test/secure-tunnel-godot-smoke.ts"], {
    cwd: serverDir,
    env: { ...process.env, TUNNEL_STUB_URL: `http://${bound.host}:${bound.port}` },
    stdio: ["ignore", "pipe", "pipe"],
  });
  let smokeOut = "";
  let smokeErr = "";
  smoke.stdout?.on("data", (chunk) => { smokeOut += String(chunk); process.stdout.write(chunk); });
  smoke.stderr?.on("data", (chunk) => { smokeErr += String(chunk); process.stderr.write(chunk); });
  const smokeStatus = await new Promise<number>((resolve, reject) => {
    const timer = setTimeout(() => { void killTree(smoke.pid ?? -1); reject(new Error("secure Godot smoke timed out")); }, 240_000);
    smoke.once("error", (error) => { clearTimeout(timer); reject(error); });
    smoke.once("close", (code) => { clearTimeout(timer); resolve(code ?? 1); });
  });
  if (smokeStatus !== 0) {
    console.error("--- TEST GODOT STDOUT ---\n" + godotOut);
    console.error("--- TEST GODOT STDERR ---\n" + godotErr);
    process.exitCode = smokeStatus;
  } else {
    console.log("FULL_OFFICIAL_TUNNEL_SMOKE=PASS");
  }
} finally {
  if (godot?.pid) await killTree(godot.pid);
  await stub.stop();
}