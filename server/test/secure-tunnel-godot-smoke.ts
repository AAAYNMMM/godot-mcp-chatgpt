import assert from "node:assert/strict";

const base = process.env.TUNNEL_STUB_URL ?? "http://127.0.0.1:8790";
let rpcSeq = 0;

async function enqueue(body: Record<string, unknown>): Promise<any> {
  const enq = await fetch(`${base}/dev/enqueue`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  assert.equal(enq.status, 200);
  const { request_id } = await enq.json() as any;
  const response = await fetch(`${base}/dev/response/${request_id}?timeout_ms=10000`);
  assert.notEqual(response.status, 204, `no tunnel response for ${JSON.stringify(body)}`);
  assert.equal(response.status, 200);
  return response.json();
}

async function rpc(method: string, params: Record<string, unknown> = {}): Promise<any> {
  const id = `rpc-${++rpcSeq}`;
  const envelope = await enqueue({
    command_type: "jsonrpc",
    jsonrpc: { jsonrpc: "2.0", id, method, params },
    response_timeout: "30s",
  });
  assert.equal(envelope.resp_type, "jsonrpc_response");
  assert.equal(envelope.resp_code, 200);
  assert.equal(envelope.resp_json?.id, id);
  if (envelope.resp_json?.error) throw new Error(`${method}: ${JSON.stringify(envelope.resp_json.error)}`);
  return envelope.resp_json?.result;
}

async function tool(name: string, args: Record<string, unknown> = {}): Promise<any> {
  const result = await rpc("tools/call", { name, arguments: args });
  const text = result?.content?.[0]?.type === "text" ? result.content[0].text : "";
  if (result?.isError) throw new Error(`${name}: ${text}`);
  return JSON.parse(text);
}

for (let i = 0; i < 80; i++) {
  try {
    const health = await fetch(`${base}/health`);
    if (health.ok) break;
  } catch {}
  await new Promise((resolve) => setTimeout(resolve, 100));
  if (i === 79) throw new Error("secure tunnel stub is not running");
}

const discover = await rpc("server/discover", {
  _meta: {
    "io.modelcontextprotocol/protocolVersion": "2026-07-28",
    "io.modelcontextprotocol/clientInfo": { name: "secure-tunnel-smoke", version: "1.0.0" },
  },
});
assert.deepEqual(discover.supportedVersions, ["2026-07-28"]);
assert.ok(discover.capabilities.tools);
assert.equal(discover.resultType, "complete");
assert.equal(discover.ttlMs, 0);
assert.equal(discover.cacheScope, "private");
assert.equal(discover._meta?.["io.modelcontextprotocol/serverInfo"]?.name, "godot-mcp-chatgpt");

const init = await rpc("initialize", {
  protocolVersion: "2025-11-25",
  capabilities: {},
  clientInfo: { name: "secure-tunnel-smoke", version: "1.0.0" },
});
assert.equal(init.protocolVersion, "2025-11-25");
assert.equal(init.serverInfo.name, "godot-mcp-chatgpt");
assert.ok(init.capabilities.tools);

const initializedAck = await enqueue({
  command_type: "jsonrpc",
  jsonrpc: { jsonrpc: "2.0", method: "notifications/initialized", params: {} },
});
assert.equal(initializedAck.resp_type, "notify_ack");
assert.equal(initializedAck.resp_code, 204);

const listed = await rpc("tools/list");
const names = new Set(listed.tools.map((item: any) => item.name));
for (const required of [
  "godot.get_status", "project.get_info", "scene.create", "scene.get_tree", "scene.save",
  "node.create", "node.set_property", "node.delete", "script.write", "script.read", "script.attach",
  "editor.run_project", "editor.stop",
]) assert.ok(names.has(required), `missing tool ${required}`);

const status = await tool("godot.get_status");
assert.match(status.godot_version, /^4\.7\.2/);
assert.equal(status.editor, true);

await tool("scene.create", { path: "res://.mcp-smoke/secure-generated.tscn", root_type: "Node3D", root_name: "SecureRoot", overwrite: true });
const created = await tool("node.create", { parent_path: ".", type: "Node3D", name: "Player" });
assert.equal(created.name, "Player");

const property = await tool("node.set_property", {
  node_path: "Player",
  property: "position",
  value: { __godot_type: "Vector3", x: 4, y: 5, z: 6 },
});
assert.deepEqual(property.value, { __godot_type: "Vector3", x: 4, y: 5, z: 6 });

const scriptContent = "extends Node3D\n\nvar secure_tunnel_smoke: int = 77\n";
await tool("script.write", { path: "res://.mcp-smoke/secure-player.gd", content: scriptContent });
const read = await tool("script.read", { path: "res://.mcp-smoke/secure-player.gd" });
assert.equal(read.content, scriptContent);
await tool("script.attach", { node_path: "Player", script_path: "res://.mcp-smoke/secure-player.gd" });
await tool("scene.save");

const tree = await tool("scene.get_tree", { max_depth: 4 });
assert.equal(tree.root.name, "SecureRoot");
assert.equal(tree.root.children[0]?.name, "Player");

const terminated = await enqueue({ command_type: "session_termination", headers: { "Mcp-Session-Id": ["smoke-session"] } });
assert.equal(terminated.resp_type, "session_termination_response");
assert.equal(terminated.resp_code, 204);

// A valid zero response timeout is immediately expired and must not produce a late response.
const expiredEnqueue = await fetch(`${base}/dev/enqueue`, {
  method: "POST",
  headers: { "content-type": "application/json" },
  body: JSON.stringify({
    command_type: "jsonrpc",
    response_timeout: "0s",
    jsonrpc: { jsonrpc: "2.0", id: "expired-rpc", method: "ping", params: {} },
  }),
});
const expiredId = (await expiredEnqueue.json() as any).request_id;
const expiredResponse = await fetch(`${base}/dev/response/${expiredId}?timeout_ms=350`);
assert.equal(expiredResponse.status, 204);

console.log(JSON.stringify({
  ok: true,
  transport: "openai-secure-mcp-tunnel-protocol",
  godot: status.godot_version,
  tools: listed.tools.length,
  scene: tree.scene_file,
  player: property.value,
}, null, 2));
