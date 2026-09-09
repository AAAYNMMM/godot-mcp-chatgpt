import assert from "node:assert/strict";
import test from "node:test";
import { createSecureTunnelStub } from "../src/secureTunnelStub.js";

const TUNNEL = "tunnel_contract_test_1234";
const KEY = "sk-test-contract-abcdefghijklmnopqrstuvwxyz";
const CLIENT_HEADERS = {
  Authorization: `Bearer ${KEY}`,
  "X-Tunnel-Client-Name": "godot-mcp-chatgpt",
  "X-Tunnel-Client-Version": "0.2.0",
  "X-Tunnel-Client-Wire-Protocol-Version": "2026-08-25",
  "X-Tunnel-Client-Instance-Id": "fixture-instance",
  "X-Tunnel-MCP-Server-Info": JSON.stringify({ version: 1, channels: [{ name: "main", proc_affinity: true }] }),
};

test("secure tunnel stub enforces auth, client contract, and response correlation", async () => {
  const stub = createSecureTunnelStub({ host: "127.0.0.1", port: 0, tunnelId: TUNNEL, apiKey: KEY });
  const bound = await stub.start();
  const base = `http://127.0.0.1:${bound.port}`;

  const unauthorized = await fetch(`${base}/v1/tunnels/${TUNNEL}`, {
    headers: { ...CLIENT_HEADERS, Authorization: "Bearer wrong" },
  });
  assert.equal(unauthorized.status, 401);

  const badContract = await fetch(`${base}/v1/tunnels/${TUNNEL}`, {
    headers: { Authorization: `Bearer ${KEY}` },
  });
  assert.equal(badContract.status, 400);

  const metadata = await fetch(`${base}/v1/tunnels/${TUNNEL}`, { headers: CLIENT_HEADERS });
  assert.equal(metadata.status, 200);

  const enqueued = await fetch(`${base}/dev/enqueue`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      command_type: "jsonrpc",
      jsonrpc: { jsonrpc: "2.0", id: "rpc-1", method: "ping", params: {} },
    }),
  });
  const { request_id } = await enqueued.json() as any;

  const poll = await fetch(`${base}/v1/tunnels/${TUNNEL}/poll?limit=10&timeout_ms=100`, { headers: CLIENT_HEADERS });
  assert.equal(poll.status, 200);
  const pollBody = await poll.json() as any;
  assert.equal(pollBody.commands.length, 1);
  assert.equal(pollBody.commands[0].request_id, request_id);
  const shard = pollBody.commands[0].shard_token;

  const posted = await fetch(`${base}/v1/tunnels/${TUNNEL}/response`, {
    method: "POST",
    headers: { ...CLIENT_HEADERS, "content-type": "application/json", "X-Tunnel-Shard-Token": shard },
    body: JSON.stringify({ request_id, channel: "main", resp_code: 200, resp_type: "jsonrpc_response", resp_json: { jsonrpc: "2.0", id: "rpc-1", result: {} } }),
  });
  assert.equal(posted.status, 200);

  const received = await fetch(`${base}/dev/response/${request_id}?timeout_ms=100`);
  assert.equal(received.status, 200);
  const responseBody = await received.json() as any;
  assert.equal(responseBody.resp_type, "jsonrpc_response");
  assert.equal(responseBody.resp_json.id, "rpc-1");

  await stub.stop();
});
