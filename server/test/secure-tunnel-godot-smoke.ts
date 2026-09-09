import assert from "node:assert/strict";

const base = process.env.TUNNEL_STUB_URL ?? "http://127.0.0.1:8790";
let rpcSeq = 0;
let publicToolNames = new Set<string>();

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

async function toolEventually(name: string, args: Record<string, unknown> = {}, attempts = 40): Promise<any> {
  let last: unknown;
  for (let i = 0; i < attempts; i++) {
    try { return await tool(name, args); } catch (error) { last = error; }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw last;
}

async function toolRaw(name: string, args: Record<string, unknown> = {}): Promise<any> {
  let publicName = name;
  let publicArgs: Record<string, unknown> = args;
  if (!publicToolNames.has(name)) {
    const dot = name.indexOf(".");
    if (dot > 0) {
      const domain = name.slice(0, dot);
      const op = name.slice(dot + 1);
      const manageName = domain + ".manage";
      if (publicToolNames.has(manageName)) {
        publicName = manageName;
        publicArgs = { op, params: args };
      }
    }
  }
  const result = await rpc("tools/call", { name: publicName, arguments: publicArgs });
  const text = result?.content?.[0]?.type === "text" ? result.content[0].text : "";
  return { isError: Boolean(result?.isError), body: text ? JSON.parse(text) : null, text, publicName, content: result?.content ?? [] };
}

async function tool(name: string, args: Record<string, unknown> = {}): Promise<any> {
  const raw = await toolRaw(name, args);
  if (raw.isError) throw new Error(`${name}: ${raw.text}`);
  return raw.body;
}

function validateSchemaShape(schema: any, path = "schema"): void {
  assert.ok(schema && typeof schema === "object" && !Array.isArray(schema), `${path} must be an object`);
  if (schema.type !== undefined) {
    const allowed = new Set(["object", "array", "string", "integer", "number", "boolean", "null"]);
    if (Array.isArray(schema.type)) for (const value of schema.type) assert.ok(allowed.has(value), `${path}.type invalid: ${value}`);
    else assert.ok(allowed.has(schema.type), `${path}.type invalid: ${schema.type}`);
  }
  if (schema.properties !== undefined) {
    assert.ok(schema.properties && typeof schema.properties === "object" && !Array.isArray(schema.properties), `${path}.properties must be object`);
    for (const [key, child] of Object.entries(schema.properties)) validateSchemaShape(child, `${path}.properties.${key}`);
  }
  if (schema.required !== undefined) {
    assert.ok(Array.isArray(schema.required), `${path}.required must be array`);
    assert.equal(new Set(schema.required).size, schema.required.length, `${path}.required has duplicates`);
    for (const key of schema.required) {
      assert.equal(typeof key, "string", `${path}.required entries must be strings`);
      assert.ok(schema.properties && Object.prototype.hasOwnProperty.call(schema.properties, key), `${path} requires undeclared property ${key}`);
    }
  }
  if (schema.items !== undefined) validateSchemaShape(schema.items, `${path}.items`);
  if (schema.enum !== undefined) assert.ok(Array.isArray(schema.enum), `${path}.enum must be array`);
  if (schema.additionalProperties !== undefined) assert.ok(typeof schema.additionalProperties === "boolean" || (schema.additionalProperties && typeof schema.additionalProperties === "object"), `${path}.additionalProperties invalid`);
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
assert.ok(discover.supportedVersions.includes("2026-07-28"));
assert.ok(discover.supportedVersions.includes("2025-11-25"));
assert.ok(discover.capabilities.tools);
assert.equal(discover.ttlMs, 0);
assert.equal(discover.cacheScope, "public");

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
assert.equal(initializedAck.resp_code, 202);

const listed = await rpc("tools/list");
const names = new Set<string>(listed.tools.map((item: any) => String(item.name)));
const toolNames = listed.tools.map((item: any) => item.name);
publicToolNames = names;
assert.equal(new Set(toolNames).size, toolNames.length, "duplicate MCP tool names");
for (const item of listed.tools) {
  assert.match(item.name, /^[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*$/, `invalid tool name ${item.name}`);
  assert.equal(typeof item.description, "string", `${item.name} description type`);
  assert.ok(item.description.trim().length > 0, `${item.name} description empty`);
  validateSchemaShape(item.inputSchema, `${item.name}.inputSchema`);
  assert.equal(item.inputSchema.type, "object", `${item.name} root schema must be object`);
  assert.equal(item.inputSchema.additionalProperties, false, `${item.name} must reject unknown arguments`);
  assert.ok(item.annotations && typeof item.annotations === "object", `${item.name} missing annotations`);
  assert.equal(typeof item.annotations.readOnlyHint, "boolean", `${item.name} readOnlyHint missing`);
  assert.equal(typeof item.annotations.destructiveHint, "boolean", `${item.name} destructiveHint missing`);
}
console.log(`CATALOGUE_SCHEMA_GATE=PASS tools=${toolNames.length}`);
const nodeCreateSchema = listed.tools.find((item: any) => item.name === "node.create")?.inputSchema;
assert.match(nodeCreateSchema?.properties?.parent_path?.description ?? "", /Use \. for the scene root/);

const expectedDirect = [
  "godot.get_status", "project.inspect", "project.search_text",
  "scene.get_current", "scene.get_tree", "scene.open", "scene.save",
  "node.create", "node.find", "node.get_properties", "node.set_property",
  "script.read", "script.write", "script.patch", "script.validate", "script.attach",
  "resource.inspect", "classdb.search", "classdb.inspect",
  "editor.inspect", "editor.take_screenshot", "editor.run_project", "editor.run_custom_scene",
  "runtime.status", "runtime.get_tree", "runtime.inspect", "runtime.get_property",
  "runtime.set_property", "runtime.call_method", "diagnostics.run_capture", "batch.execute", "logs.read",
];
const expectedManage = [
  "project.manage", "input_map.manage", "scene.manage", "node.manage", "script.manage",
  "resource.manage", "classdb.manage", "editor.manage", "debugger.manage", "runtime.manage", "logs.manage", "test.manage", "autoload.manage",
];
for (const required of [...expectedDirect, ...expectedManage]) assert.ok(names.has(required), "missing compact public tool " + required);
assert.equal(toolNames.length, 47, "unexpected compact public tool count");
assert.ok(toolNames.length <= 50, "compact public tool surface exceeds release gate");
let derivedAtomicCount = 4;
for (const manageName of expectedManage) {
  const manage = listed.tools.find((item: any) => item.name === manageName);
  assert.ok(manage, "missing " + manageName);
  const ops = manage.inputSchema?.properties?.op?.enum;
  assert.ok(Array.isArray(ops) && ops.length > 0, manageName + " missing op enum");
  derivedAtomicCount += ops.length;
}
assert.equal(derivedAtomicCount, 153, "compact surface does not cover all registered atomic commands");
console.log("COMPACT_TOOL_SURFACE_GATE=PASS public=" + toolNames.length + " atomic=" + derivedAtomicCount);

const invalidManagedParams = await toolRaw("project.get_info", { unexpected: true });
assert.equal(invalidManagedParams.publicName, "project.manage");
assert.equal(invalidManagedParams.isError, true);
assert.equal(invalidManagedParams.body?.code, "INVALID_ARGUMENTS");

// Phase C: script diagnostics / patch / GDScript tests / ensure helpers / autoload.
const invalidWrite = await tool("script.write", { path: "res://.mcp-smoke/phase-c-invalid.gd", content: "extends Node\nfunc broken( -> void:\n\tpass\n" });
assert.equal(invalidWrite.written, true);
assert.equal(invalidWrite.valid, false);
const invalidDiag = await tool("script.get_diagnostics", { path: "res://.mcp-smoke/phase-c-invalid.gd" });
assert.equal(invalidDiag.valid, false);
await tool("script.write", { path: "res://.mcp-smoke/phase-c-invalid.gd", content: "extends Node\nfunc fixed() -> int:\n\treturn 42\n" });
const validDiag = await tool("script.get_diagnostics", { path: "res://.mcp-smoke/phase-c-invalid.gd" });
assert.equal(validDiag.valid, true);

await tool("script.write", { path: "res://.mcp-smoke/patch-target.gd", content: "extends RefCounted\nconst TOKEN = 1\nconst TOKEN2 = 1\n" });
const ambiguousPatch = await toolRaw("script.patch", { path: "res://.mcp-smoke/patch-target.gd", find: "= 1", replace: "= 2" });
assert.equal(ambiguousPatch.isError, true);
assert.equal(ambiguousPatch.body?.code, "PATCH_AMBIGUOUS");
const patched = await tool("script.patch", { path: "res://.mcp-smoke/patch-target.gd", find: "const TOKEN = 1", replace: "const TOKEN = 42", require_valid: true });
assert.equal(patched.written, true);
assert.equal(patched.valid, true);
assert.equal(patched.replacements, 1);

await tool("input_map.remove_action", { action: "mcp_phase_c_ensure" });
await toolRaw("autoload.remove", { name: "McpPhaseCTest" });
const ensureAction1 = await tool("input_map.ensure_action", { action: "mcp_phase_c_ensure", deadzone: 0.3 });
assert.equal(ensureAction1.created, true);
const ensureAction2 = await tool("input_map.ensure_action", { action: "mcp_phase_c_ensure", deadzone: 0.3 });
assert.equal(ensureAction2.already_exists, true);
const ensureEvent1 = await tool("input_map.ensure_event", { action: "mcp_phase_c_ensure", event: { type: "key", keycode: 90 } });
assert.equal(ensureEvent1.already_bound, false);
const ensureEvent2 = await tool("input_map.ensure_event", { action: "mcp_phase_c_ensure", event: { type: "key", keycode: 90 } });
assert.equal(ensureEvent2.already_bound, true);

await tool("script.write", { path: "res://.mcp-smoke/phase-c-autoload.gd", content: "extends Node\n" });
const autoloadAdded = await tool("autoload.add", { name: "McpPhaseCTest", path: "res://.mcp-smoke/phase-c-autoload.gd", singleton: true });
assert.equal(autoloadAdded.persisted, true);
const autoloads = await tool("autoload.list");
assert.ok(autoloads.autoloads.some((entry: any) => entry.name === "McpPhaseCTest"));
const reservedAutoload = await toolRaw("autoload.remove", { name: "GodotMCPChatGPTRuntime" });
assert.equal(reservedAutoload.isError, true);
assert.equal(reservedAutoload.body?.code, "RESERVED_AUTOLOAD");
const autoloadRemoved = await tool("autoload.remove", { name: "McpPhaseCTest" });
assert.equal(autoloadRemoved.removed, true);

await tool("project.make_directory", { path: "res://.mcp-smoke/tests" });
const testSource = '@tool\nextends "res://addons/godot_mcp_chatgpt/testing/test_suite.gd"\n\nfunc test_math() -> void:\n\tassert_eq(20 + 22, 42)\n\nfunc test_truth() -> bool:\n\tassert_true(true)\n\treturn true\n';
await tool("script.write", { path: "res://.mcp-smoke/tests/test_phase_c.gd", content: testSource });
const testList = await tool("test.list", { root: "res://.mcp-smoke/tests" });
assert.equal(testList.count, 1);
assert.equal(testList.suites[0].count, 2);
const testRun = await tool("test.run", { root: "res://.mcp-smoke/tests", max_tests: 10 });
assert.equal(testRun.ok, true);
assert.equal(testRun.tests, 2);
assert.equal(testRun.passed, 2);
assert.equal(testRun.failed, 0);
const cachedTests = await tool("test.get_results");
assert.equal(cachedTests.tests, 2);

const batchRead = await tool("batch.execute", {
  operations: [
    { tool: "godot.get_status", arguments: {} },
    { tool: "project.get_info", arguments: {} },
  ],
  stop_on_error: true,
});
assert.equal(batchRead.executed, 2);
assert.equal(batchRead.stopped, false);
assert.equal(batchRead.atomic, false);
assert.ok(batchRead.results.every((item: any) => item.ok));

const batchStop = await tool("batch.execute", {
  operations: [
    { tool: "godot.get_status", arguments: {} },
    { tool: "missing.tool", arguments: {} },
    { tool: "project.get_info", arguments: {} },
  ],
  stop_on_error: true,
});
assert.equal(batchStop.executed, 2);
assert.equal(batchStop.stopped, true);
assert.equal(batchStop.failed_index, 1);
assert.equal(batchStop.results[1]?.ok, false);

const batchRecursive = await tool("batch.execute", {
  operations: [{ tool: "batch.execute", arguments: { operations: [{ tool: "godot.get_status" }] } }],
});
assert.equal(batchRecursive.executed, 1);
assert.equal(batchRecursive.stopped, true);
assert.equal(batchRecursive.results[0]?.error?.code, "BATCH_RECURSION_DENIED");

const tooManyOps = Array.from({ length: 51 }, () => ({ tool: "godot.get_status", arguments: {} }));
const batchLimit = await toolRaw("batch.execute", { operations: tooManyOps });
assert.equal(batchLimit.isError, true);
assert.equal(batchLimit.body?.code, "BATCH_TOO_LARGE");

const invalidResourcePath = await toolRaw("resource.inspect", { path: "res://../outside.tres" });
assert.equal(invalidResourcePath.isError, true);
assert.equal(invalidResourcePath.body?.code, "INVALID_PATH");

const editorBefore = await tool("editor.inspect");
assert.equal(editorBefore.playing, false);
assert.equal(typeof editorBefore.filesystem.scanning, "boolean");
assert.ok(Array.isArray(editorBefore.selection.nodes));
const editorFs = await tool("editor.get_filesystem_state");
assert.equal(typeof editorFs.importing, "boolean");
const editorScripts = await tool("editor.get_script_state");
assert.ok(Array.isArray(editorScripts.open));
const status = await tool("godot.get_status");
assert.match(status.godot_version, /^4\.7\.2/);
assert.equal(status.editor, true);

const projectOverview = await tool("project.inspect");
assert.equal(projectOverview.name, "Godot MCP ChatGPT Dev");
assert.ok(Array.isArray(projectOverview.plugins));
const projectPlugins = await tool("project.get_plugins");
assert.ok(Array.isArray(projectPlugins));
const projectList = await tool("project.list_directory", { path: "res://", recursive: false });
assert.ok(projectList.items.some((item: any) => item.name === "addons"));
const projectFind = await tool("project.find_files", { query: "plugin.gd", root: "res://addons", limit: 20 });
assert.ok(projectFind.files.some((path: string) => path.endsWith("addons/godot_mcp_chatgpt/plugin.gd")));

await tool("project.set_setting", { name: "godot_mcp_chatgpt/smoke_setting", value: 12345 });
const smokeSetting = await tool("project.get_setting", { name: "godot_mcp_chatgpt/smoke_setting" });
assert.equal(smokeSetting.exists, true);
assert.equal(smokeSetting.value, 12345);
const listedSettings = await tool("project.list_settings", { prefix: "godot_mcp_chatgpt/", limit: 20 });
assert.ok(listedSettings.settings.some((item: any) => item.name === "godot_mcp_chatgpt/smoke_setting"));

await tool("input_map.add_action", { action: "mcp_smoke_action", deadzone: 0.25 });
await tool("input_map.add_event", { action: "mcp_smoke_action", event: { type: "key", keycode: 32 } });
const inputAction = await tool("input_map.get_action", { action: "mcp_smoke_action" });
assert.equal(inputAction.action, "mcp_smoke_action");
assert.equal(inputAction.events.length, 1);
const inputList = await tool("input_map.list");
assert.ok(inputList.some((item: any) => item.action === "mcp_smoke_action"));
const clearedInput = await tool("input_map.clear_action_events", { action: "mcp_smoke_action" });
assert.equal(clearedInput.events.length, 0);

await tool("project.make_directory", { path: "res://.mcp-smoke/move-test" });
await tool("script.write", { path: "res://.mcp-smoke/move-source.gd", content: "extends RefCounted\n" });
await tool("project.move_file", { from: "res://.mcp-smoke/move-source.gd", to: "res://.mcp-smoke/move-test/moved.gd" });
const movedFind = await tool("project.find_files", { query: "moved.gd", root: "res://.mcp-smoke", limit: 20 });
assert.ok(movedFind.files.includes("res://.mcp-smoke/move-test/moved.gd"));
await tool("project.delete_file", { path: "res://.mcp-smoke/move-test/moved.gd" });

await tool("scene.create", { path: "res://.mcp-smoke/secure-generated.tscn", root_type: "Node3D", root_name: "SecureRoot", overwrite: true });
const created = await tool("node.create", { parent_path: ".", type: "Node3D", name: "Player" });
assert.equal(created.name, "Player");
const editorSelection = await tool("editor.set_selection", { node_paths: ["Player"], clear_first: true });
assert.equal(editorSelection.selection.nodes.length, 1);
assert.equal(editorSelection.selection.nodes[0]?.name, "Player");
const clearedSelection = await tool("editor.clear_selection");
assert.equal(clearedSelection.nodes.length, 0);

const undoNode = await tool("node.create", { parent_path: ".", type: "Node3D", name: "UndoNode" });
assert.equal(undoNode.undoable, true);
const undoSet = await tool("node.set_property", { node_path: "UndoNode", property: "position", value: { __godot_type: "Vector3", x: 5, y: 6, z: 7 } });
assert.equal(undoSet.undoable, true);
const undoStateBefore = await tool("editor.get_undo_state");
assert.equal(undoStateBefore.has_undo, true);
const undoResult = await tool("editor.undo");
assert.equal(undoResult.performed, true);
const afterUndo = await tool("node.get_property", { node_path: "UndoNode", property: "position" });
assert.deepEqual(afterUndo.value, { __godot_type: "Vector3", x: 0, y: 0, z: 0 });
const redoResult = await tool("editor.redo");
assert.equal(redoResult.performed, true);
const afterRedo = await tool("node.get_property", { node_path: "UndoNode", property: "position" });
assert.deepEqual(afterRedo.value, { __godot_type: "Vector3", x: 5, y: 6, z: 7 });

const txSuccess = await tool("batch.execute_transaction", { operations: [
  { tool: "node.set_property", arguments: { node_path: "UndoNode", property: "position", value: { __godot_type: "Vector3", x: 1, y: 1, z: 1 } } },
  { tool: "node.create", arguments: { parent_path: ".", type: "Node", name: "TransactionalNode" } },
] });
assert.equal(txSuccess.atomic, true);
assert.equal(txSuccess.committed, true);
assert.equal(txSuccess.undo_actions, 2);
const txNode = await tool("node.find", { name_contains: "TransactionalNode" });
assert.equal(txNode.count, 1);
const beforeFailedTx = await tool("node.get_property", { node_path: "UndoNode", property: "position" });
const txRollback = await tool("batch.execute_transaction", { operations: [
  { tool: "node.set_property", arguments: { node_path: "UndoNode", property: "position", value: { __godot_type: "Vector3", x: 9, y: 9, z: 9 } } },
  { tool: "node.set_property", arguments: { node_path: "UndoNode", property: "definitely_missing", value: 1 } },
] });
assert.equal(txRollback.atomic, true);
assert.equal(txRollback.committed, false);
assert.equal(txRollback.rolled_back, true);
const afterFailedTx = await tool("node.get_property", { node_path: "UndoNode", property: "position" });
assert.deepEqual(afterFailedTx.value, beforeFailedTx.value);
const unsupportedTx = await toolRaw("batch.execute_transaction", { operations: [{ tool: "script.write", arguments: { path: "res://.mcp-smoke/nope.gd", content: "extends RefCounted\n" } }] });
assert.equal(unsupportedTx.isError, true);
assert.equal(unsupportedTx.body?.code, "TRANSACTION_TOOL_NOT_UNDOABLE");

const property = await tool("node.set_property", {
  node_path: "Player",
  property: "position",
  value: { __godot_type: "Vector3", x: 4, y: 5, z: 6 },
});
assert.deepEqual(property.value, { __godot_type: "Vector3", x: 4, y: 5, z: 6 });

const sceneCurrent = await tool("scene.get_current");
assert.equal(sceneCurrent.open, true);
assert.equal(sceneCurrent.path, "res://.mcp-smoke/secure-generated.tscn");
const sceneOpenList = await tool("scene.list_open");
assert.ok(sceneOpenList.paths.includes("res://.mcp-smoke/secure-generated.tscn"));
const sceneInspect = await tool("scene.inspect", { max_depth: 4, property_mode: "storage", max_properties: 40 });
assert.equal(sceneInspect.root.name, "SecureRoot");

const nodeInspect = await tool("node.inspect", { node_path: "Player", property_mode: "storage", max_properties: 80 });
assert.equal(nodeInspect.node.name, "Player");
const nodePosition = await tool("node.get_property", { node_path: "Player", property: "position" });
assert.deepEqual(nodePosition.value, { __godot_type: "Vector3", x: 4, y: 5, z: 6 });
const nodeProperties = await tool("node.get_properties", { node_path: "Player", mode: "all", name_contains: "position", limit: 20 });
assert.ok(nodeProperties.properties.some((item: any) => item.name === "position"));
const nodeMethods = await tool("node.get_methods", { node_path: "Player", name_contains: "get_child_count", limit: 20 });
assert.ok(nodeMethods.methods.some((item: any) => item.name === "get_child_count"));
const editorNodeCall = await tool("node.call_method", { node_path: "Player", method: "get_child_count", arguments: [] });
assert.equal(editorNodeCall.result, 0);

await tool("node.add_to_group", { node_path: "Player", group: "mcp_smoke_group", persistent: true });
const playerGroups = await tool("node.get_groups", { node_path: "Player" });
assert.ok(playerGroups.groups.includes("mcp_smoke_group"));
const groupFind = await tool("node.find", { group: "mcp_smoke_group", limit: 20 });
assert.ok(groupFind.nodes.some((item: any) => item.name === "Player"));
await tool("node.remove_from_group", { node_path: "Player", group: "mcp_smoke_group" });

await tool("node.set_metadata", { node_path: "Player", key: "mcp_smoke_meta", value: { nested: 77 } });
const playerMeta = await tool("node.get_metadata", { node_path: "Player", key: "mcp_smoke_meta" });
assert.equal(playerMeta.exists, true);
assert.equal(playerMeta.value.nested, 77);
await tool("node.remove_metadata", { node_path: "Player", key: "mcp_smoke_meta" });
const removedMeta = await tool("node.get_metadata", { node_path: "Player", key: "mcp_smoke_meta" });
assert.equal(removedMeta.exists, false);

const duplicatedNode = await tool("node.duplicate", { node_path: "Player", name: "PlayerClone" });
assert.equal(duplicatedNode.name, "PlayerClone");
const renamedNode = await tool("node.rename", { node_path: "PlayerClone", name: "PlayerCopy" });
assert.equal(renamedNode.name, "PlayerCopy");
await tool("node.move_child", { node_path: "PlayerCopy", index: 0 });
await tool("node.delete", { node_path: "PlayerCopy" });

const scriptContent = "extends Node3D\n\nsignal smoke_signal\nvar secure_tunnel_smoke: int = 77\nvar key_events: int = 0\nvar mouse_events: int = 0\nvar joy_events: int = 0\n\nfunc _ready() -> void:\n\tprint(\"CAPTURE_STDOUT_OK\")\n\nfunc _input(event: InputEvent) -> void:\n\tif event is InputEventKey:\n\t\tkey_events += 1\n\telif event is InputEventMouseButton or event is InputEventMouseMotion:\n\t\tmouse_events += 1\n\telif event is InputEventJoypadButton or event is InputEventJoypadMotion:\n\t\tjoy_events += 1\n\nfunc _on_smoke() -> void:\n\tpass\n";
await tool("script.write", { path: "res://.mcp-smoke/secure-player.gd", content: scriptContent });
const read = await tool("script.read", { path: "res://.mcp-smoke/secure-player.gd" });
assert.equal(read.content, scriptContent);
await tool("script.attach", { node_path: "Player", script_path: "res://.mcp-smoke/secure-player.gd" });
const scriptInfo = await tool("script.get_info", { path: "res://.mcp-smoke/secure-player.gd" });
assert.equal(scriptInfo.instance_base_type, "Node3D");
assert.ok(scriptInfo.methods.some((item: any) => item.name === "_on_smoke"));
assert.ok(scriptInfo.signals.some((item: any) => item.name === "smoke_signal"));
const scriptValid = await tool("script.validate", { source: scriptContent });
assert.equal(scriptValid.valid, true);

const playerSignals = await tool("node.get_signals", { node_path: "Player" });
assert.ok(playerSignals.signals.some((item: any) => item.name === "smoke_signal"));
await tool("node.connect_signal", { node_path: "Player", signal: "smoke_signal", target_path: "Player", method: "_on_smoke" });
const smokeConnections = await tool("node.get_signal_connections", { node_path: "Player", signal: "smoke_signal" });
assert.ok(smokeConnections.connections.some((item: any) => item.method === "_on_smoke"));
await tool("node.disconnect_signal", { node_path: "Player", signal: "smoke_signal", target_path: "Player", method: "_on_smoke" });
const smokeDisconnected = await tool("node.get_signal_connections", { node_path: "Player", signal: "smoke_signal" });
assert.equal(smokeDisconnected.connections.length, 0);

await tool("script.detach", { node_path: "Player" });
const detachedInspect = await tool("node.inspect", { node_path: "Player", property_mode: "none" });
assert.equal(detachedInspect.script, "");
await tool("script.attach", { node_path: "Player", script_path: "res://.mcp-smoke/secure-player.gd" });

await tool("scene.save");
const resourceCreated = await tool("resource.create", {
  class: "Resource",
  path: "res://.mcp-smoke/smoke-resource.tres",
  properties: { resource_name: "SmokeResource" },
});
assert.equal(resourceCreated.class, "Resource");
const resourceInspect = await tool("resource.inspect", { path: "res://.mcp-smoke/smoke-resource.tres", property_mode: "storage", include_methods: true, limit: 100 });
assert.equal(resourceInspect.resource.class, "Resource");
const resourceName = await tool("resource.get_property", { path: "res://.mcp-smoke/smoke-resource.tres", property: "resource_name" });
assert.equal(resourceName.value, "SmokeResource");
const resourceChanged = await tool("resource.set_property", { path: "res://.mcp-smoke/smoke-resource.tres", property: "resource_name", value: "SmokeResource2" });
assert.equal(resourceChanged.value, "SmokeResource2");
const resourceCopy = await tool("resource.duplicate", { path: "res://.mcp-smoke/smoke-resource.tres", target_path: "res://.mcp-smoke/smoke-resource-copy.tres", deep: true });
assert.equal(resourceCopy.class, "Resource");
await tool("resource.save", { path: "res://.mcp-smoke/smoke-resource.tres", target_path: "res://.mcp-smoke/smoke-resource-saved.tres" });
const resourceDeps = await tool("resource.get_dependencies", { path: "res://.mcp-smoke/smoke-resource.tres" });
assert.ok(Array.isArray(resourceDeps.dependencies));
const resourceCall = await tool("resource.call_method", { path: "res://.mcp-smoke/smoke-resource.tres", method: "get_class", arguments: [] });
assert.equal(resourceCall.result, "Resource");

const classSearch = await tool("classdb.search", { query: "Node3D", limit: 50 });
assert.ok(classSearch.classes.some((item: any) => item.class === "Node3D"));
const classInspect = await tool("classdb.inspect", { class: "Node3D", include_inherited: true, limit: 200 });
assert.equal(classInspect.class, "Node3D");
assert.ok(classInspect.inheritance.includes("Node"));
const classMethods = await tool("classdb.get_methods", { class: "Node", include_inherited: true, name_contains: "get_child_count", limit: 50 });
assert.ok(classMethods.methods.some((item: any) => item.name === "get_child_count"));
const classCan = await tool("classdb.can_instantiate", { class: "Node3D" });
assert.equal(classCan.exists, true);
assert.equal(classCan.can_instantiate, true);

const textSearch = await tool("project.search_text", { query: "secure_tunnel_smoke", root: "res://.mcp-smoke", extensions: ["gd"], limit: 20 });
assert.ok(textSearch.matches.some((item: any) => item.path === "res://.mcp-smoke/secure-player.gd"));

const editorPerf = await tool("editor.get_performance");
assert.equal(typeof editorPerf.monitors.fps, "number");
const editorLogs = await tool("logs.read", { source: "editor", limit: 20 });
assert.ok(Array.isArray(editorLogs.entries));

await tool("node.create", { parent_path: ".", type: "Label", name: "PhaseBLabel" });
await tool("node.set_property", { node_path: "PhaseBLabel", property: "text", value: "PHASE_B_UI" });
await tool("input_map.add_action", { action: "mcp_phase_b_action", deadzone: 0.2 });
const editorRun = await tool("editor.run_current_scene");
assert.equal(editorRun.playing, true);
const editorPlaying = await tool("editor.get_playing_scene");
assert.equal(editorPlaying.playing, true);
const runtimeStatus = await toolEventually("runtime.status");
const debuggerSessions = await tool("debugger.get_sessions");
assert.ok(debuggerSessions.sessions.some((session: any) => session.active));
assert.equal(runtimeStatus.current_scene, "res://.mcp-smoke/secure-generated.tscn");
assert.ok(runtimeStatus.node_count >= 2);
const debugStatus = await toolEventually("runtime.get_debug_status");
assert.equal(typeof debugStatus.process_ticks, "number");
const uiElements = await tool("runtime.get_ui_elements", { limit: 50 });
assert.ok(uiElements.elements.some((item: any) => item.name === "PhaseBLabel" && item.text === "PHASE_B_UI"));
await tool("runtime.input_key", { keycode: 65, pressed: true });
await tool("runtime.input_key", { keycode: 65, pressed: false });
await tool("runtime.input_mouse", { kind: "button", button: 1, pressed: true, x: 20, y: 30 });
await tool("runtime.input_mouse", { kind: "button", button: 1, pressed: false, x: 20, y: 30 });
await tool("runtime.input_mouse", { kind: "motion", x: 25, y: 35, dx: 5, dy: 5 });
await tool("runtime.input_gamepad", { kind: "button", device: 0, button: 0, pressed: true });
await tool("runtime.input_gamepad", { kind: "button", device: 0, button: 0, pressed: false });
const keyEventCount = await tool("runtime.get_property", { node_path: "Player", property: "key_events" });
const mouseEventCount = await tool("runtime.get_property", { node_path: "Player", property: "mouse_events" });
const joyEventCount = await tool("runtime.get_property", { node_path: "Player", property: "joy_events" });
assert.ok(keyEventCount.value >= 2, "keyboard injection did not reach _input");
assert.ok(mouseEventCount.value >= 3, "mouse injection did not reach _input");
assert.ok(joyEventCount.value >= 2, "gamepad injection did not reach _input");
const evalResult = await tool("runtime.evaluate", { node_path: "Player", expression: "a * 2 + b", variables: { a: 20, b: 2 } });
assert.equal(evalResult.value, 42);
const actionPressed = await tool("runtime.input_action", { action: "mcp_phase_b_action", pressed: true, strength: 0.75 });
assert.equal(actionPressed.pressed, true);
const inputState = await tool("runtime.get_input_state", { actions: ["mcp_phase_b_action"] });
assert.equal(inputState.actions.mcp_phase_b_action.pressed, true);
await tool("runtime.input_action", { action: "mcp_phase_b_action", pressed: false });
const sequence = await tool("runtime.input_sequence", { steps: [
  { at_frame: 0, event: { type: "action", action: "mcp_phase_b_action", pressed: true } },
  { at_frame: 2, event: { type: "action", action: "mcp_phase_b_action", pressed: false } },
], release_actions: true, timeout_ms: 10000 });
assert.equal(sequence.completed, true);
assert.equal(sequence.steps, 2);
const screenshotRaw = await toolRaw("editor.take_screenshot", { source: "game", max_resolution: 512, timeout_ms: 10000 });
assert.equal(screenshotRaw.isError, false);
assert.ok(screenshotRaw.content.some((item: any) => item.type === "image" && item.mimeType === "image/png" && typeof item.data === "string" && item.data.length > 100));
const gameLogs = await tool("logs.read", { source: "game", limit: 100 });
assert.ok(Array.isArray(gameLogs.entries));
assert.ok(gameLogs.entries.some((entry: any) => String(entry.text ?? "").includes("CAPTURE_STDOUT_OK")), "running-game log capture missing CAPTURE_STDOUT_OK");
const nativeStatus = await tool("debugger.get_status");
assert.equal(nativeStatus.active, true);
const runtimeTree = await tool("runtime.get_tree", { max_depth: 4 });
assert.equal(runtimeTree.root.name, "SecureRoot");
assert.equal(runtimeTree.root.children[0]?.name, "Player");
const runtimePosition = await tool("runtime.get_property", { node_path: "Player", property: "position" });
assert.deepEqual(runtimePosition.value, { __godot_type: "Vector3", x: 4, y: 5, z: 6 });
const runtimeChanged = await tool("runtime.set_property", { node_path: "Player", property: "position", value: { __godot_type: "Vector3", x: 7, y: 8, z: 9 } });
assert.deepEqual(runtimeChanged.value, { __godot_type: "Vector3", x: 7, y: 8, z: 9 });
const runtimeCall = await tool("runtime.call_method", { node_path: ".", method: "get_child_count", arguments: [] });
assert.ok(runtimeCall.result >= 2, `expected at least Player + PhaseBLabel children, got ${runtimeCall.result}`);
const runtimePerf = await tool("runtime.get_performance");
assert.equal(typeof runtimePerf.fps, "number");
const paused = await tool("runtime.pause");
assert.equal(paused.paused, true);
const resumed = await tool("runtime.resume");
assert.equal(resumed.paused, false);
const editorStopped = await tool("editor.stop_playing");
assert.equal(editorStopped.playing, false);

const tree = await tool("scene.get_tree", { max_depth: 4 });
assert.equal(tree.root.name, "SecureRoot");
assert.equal(tree.root.children[0]?.name, "Player");

const captureSuccess = await tool("diagnostics.run_capture", {
  scene: "res://.mcp-smoke/secure-generated.tscn",
  quit_after: 4,
  timeout_ms: 10000,
});
assert.equal(captureSuccess.process_ok, true);
assert.equal(captureSuccess.exit_code, 0);
assert.equal(captureSuccess.timed_out, false);
assert.match(captureSuccess.stdout, /CAPTURE_STDOUT_OK/);

await tool("scene.create", { path: "res://.mcp-smoke/capture-error.tscn", root_type: "Node", root_name: "CaptureError", overwrite: true });
const errorScript = "extends Node\n\nfunc _ready() -> void:\n\tpush_error(\"CAPTURE_ERROR_OK\")\n\tget_tree().quit(7)\n";
await tool("script.write", { path: "res://.mcp-smoke/capture-error.gd", content: errorScript });
await tool("script.attach", { node_path: ".", script_path: "res://.mcp-smoke/capture-error.gd" });
await tool("scene.save");
const captureError = await tool("diagnostics.run_capture", {
  scene: "res://.mcp-smoke/capture-error.tscn",
  quit_after: 30,
  timeout_ms: 10000,
});
assert.equal(captureError.process_ok, false);
assert.equal(captureError.exit_code, 7);
assert.equal(captureError.timed_out, false);
assert.match(captureError.stderr, /CAPTURE_ERROR_OK/);

await tool("scene.create", { path: "res://.mcp-smoke/capture-timeout.tscn", root_type: "Node", root_name: "CaptureTimeout", overwrite: true });
const timeoutScript = "extends Node\n\nfunc _ready() -> void:\n\tOS.delay_msec(5000)\n";
await tool("script.write", { path: "res://.mcp-smoke/capture-timeout.gd", content: timeoutScript });
await tool("script.attach", { node_path: ".", script_path: "res://.mcp-smoke/capture-timeout.gd" });
await tool("scene.save");
const captureTimeout = await tool("diagnostics.run_capture", {
  scene: "res://.mcp-smoke/capture-timeout.tscn",
  quit_after: 30,
  timeout_ms: 300,
});
assert.equal(captureTimeout.process_ok, false);
assert.equal(captureTimeout.timed_out, true);
assert.equal(captureTimeout.exit_code, -1);

const reopenedSecure = await tool("scene.open", { path: "res://.mcp-smoke/secure-generated.tscn" });
assert.equal(reopenedSecure.opened, true);
const currentAfterOpen = await tool("scene.get_current");
assert.equal(currentAfterOpen.path, "res://.mcp-smoke/secure-generated.tscn");
const reloadedSecure = await tool("scene.reload", { path: "res://.mcp-smoke/secure-generated.tscn" });
assert.equal(reloadedSecure.reloaded, true);
const instantiated = await tool("scene.instantiate", { scene_path: "res://.mcp-smoke/capture-error.tscn", parent_path: ".", name: "DiagnosticInstance" });
assert.equal(instantiated.path, "DiagnosticInstance");
await tool("node.delete", { node_path: "DiagnosticInstance" });
const saveAllScenes = await tool("scene.save_all");
assert.equal(saveAllScenes.saved, true);

const openedScript = await tool("editor.open_script", { path: "res://.mcp-smoke/secure-player.gd", line: 1, column: 0, grab_focus: false });
assert.ok(openedScript.scripts.open.includes("res://.mcp-smoke/secure-player.gd"));
const openScripts = await tool("script.list_open");
assert.ok(openScripts.open.includes("res://.mcp-smoke/secure-player.gd"));
const scriptsSaved = await tool("script.save_all");
assert.equal(scriptsSaved.saved, true);
const scriptsReloaded = await tool("script.reload_open");
assert.equal(scriptsReloaded.reloaded, true);
const closedScript = await tool("editor.close_script", { path: "res://.mcp-smoke/secure-player.gd" });
assert.ok(!closedScript.scripts.open.includes("res://.mcp-smoke/secure-player.gd"));

const closedScene = await tool("scene.close");
assert.equal(closedScene.closed, true);
const reopenedAfterClose = await tool("scene.open", { path: "res://.mcp-smoke/secure-generated.tscn" });
assert.equal(reopenedAfterClose.opened, true);

await tool("input_map.remove_action", { action: "mcp_phase_c_ensure" });
await tool("project.delete_file", { path: "res://.mcp-smoke/phase-c-invalid.gd" });
await tool("project.delete_file", { path: "res://.mcp-smoke/patch-target.gd" });
await tool("project.delete_file", { path: "res://.mcp-smoke/phase-c-autoload.gd" });
await tool("project.delete_file", { path: "res://.mcp-smoke/tests/test_phase_c.gd" });
await tool("input_map.remove_action", { action: "mcp_phase_b_action" });
const removedAction = await tool("input_map.remove_action", { action: "mcp_smoke_action" });
assert.equal(removedAction.removed, true);
const removedActionCheck = await toolRaw("input_map.get_action", { action: "mcp_smoke_action" });
assert.equal(removedActionCheck.isError, true);
assert.equal(removedActionCheck.body?.code, "ACTION_NOT_FOUND");
const removedSetting = await tool("project.set_setting", { name: "godot_mcp_chatgpt/smoke_setting", value: null });
assert.equal(removedSetting.exists, false);
const removedSettingCheck = await tool("project.get_setting", { name: "godot_mcp_chatgpt/smoke_setting" });
assert.equal(removedSettingCheck.exists, false);

const terminated = await enqueue({ command_type: "session_termination", headers: { "Mcp-Session-Id": ["smoke-session"] } });
assert.equal(terminated.resp_type, "session_termination_response");
assert.equal(terminated.resp_code, 204);

console.log(JSON.stringify({
  ok: true,
  transport: "official-openai-tunnel-client",
  godot: status.godot_version,
  tools: listed.tools.length,
  scene: tree.scene_file,
  player: property.value,
}, null, 2));
