import crypto from "node:crypto";
import http from "node:http";
import express from "express";

interface TunnelCommand {
  request_id: string;
  shard_token: string;
  command_type: string;
  channel: string;
  created_at: string;
  response_timeout?: string;
  headers: Record<string, string[]>;
  jsonrpc?: Record<string, unknown>;
}

interface Waiter {
  resolve: () => void;
  timer: NodeJS.Timeout;
}

export interface SecureTunnelStubOptions {
  host?: string;
  port?: number;
  tunnelId?: string;
  apiKey?: string;
}

export function createSecureTunnelStub(options: SecureTunnelStubOptions = {}) {
  const host = options.host ?? "127.0.0.1";
  const port = options.port ?? Number(process.env.TUNNEL_STUB_PORT ?? "8790");
  const tunnelId = options.tunnelId ?? process.env.GODOT_MCP_CHATGPT_TUNNEL_ID ?? "tunnel_0123456789abcdef0123456789abcdef";
  const apiKey = options.apiKey ?? process.env.GODOT_MCP_CHATGPT_API_KEY ?? "devkey_123456789012345678901234567890";
  const queue: TunnelCommand[] = [];
  const expectedShard = new Map<string, string>();
  const responses = new Map<string, any>();
  const pollWaiters = new Set<Waiter>();
  const responseWaiters = new Map<string, Set<Waiter>>();

  const app = express();
  app.disable("x-powered-by");
  app.use(express.json({ limit: "1mb" }));

  function authorized(req: express.Request): boolean {
    return req.params.tunnelId === tunnelId && req.headers.authorization === `Bearer ${apiKey}`;
  }

  function validClientContract(req: express.Request): boolean {
    // Keep the simulator backward-compatible with released official clients.
    // Newer wire/instance headers are additive and older tunnel-client builds
    // (including the one currently bundled by CWapi) legitimately omit them.
    if (!req.headers["x-tunnel-client-name"]) return false;
    if (!req.headers["x-tunnel-client-version"]) return false;
    const raw = req.headers["x-tunnel-mcp-server-info"];
    // The official tunnel-client may omit server-info during early startup.
    // It is additive/optional metadata in the control-plane contract.
    if (raw === undefined) return true;
    if (typeof raw !== "string") return false;
    try {
      const info = JSON.parse(raw);
      return (info?.version === 1 || info?.version === 2)
        && Array.isArray(info.channels)
        && info.channels.some((channel: any) => channel?.name === "main");
    } catch {
      return false;
    }
  }

  function guard(req: express.Request, res: express.Response): boolean {
    if (!authorized(req)) { res.status(401).json({ error: "unauthorized" }); return false; }
    if (!validClientContract(req)) { res.status(400).json({ error: "invalid client contract headers" }); return false; }
    return true;
  }

  function wakePollers(): void {
    for (const waiter of pollWaiters) {
      clearTimeout(waiter.timer);
      waiter.resolve();
    }
    pollWaiters.clear();
  }

  function wakeResponse(requestId: string): void {
    const waiters = responseWaiters.get(requestId);
    if (!waiters) return;
    for (const waiter of waiters) {
      clearTimeout(waiter.timer);
      waiter.resolve();
    }
    responseWaiters.delete(requestId);
  }

  app.get("/v1/tunnels/:tunnelId", (req, res) => {
    if (!guard(req, res)) return;
    res.json({ id: tunnelId, status: "active" });
  });

  app.get("/v1/tunnels/:tunnelId/poll", async (req, res) => {
    if (!guard(req, res)) return;
    if (queue.length === 0) {
      const requested = Math.max(1, Math.min(Number(req.query.timeout_ms ?? 15000), 15000));
      await new Promise<void>((resolve) => {
        const waiter: Waiter = { resolve, timer: setTimeout(resolve, requested) };
        pollWaiters.add(waiter);
        waiter.timer.unref?.();
      });
    }
    if (queue.length === 0) return res.status(204).end();
    const limit = Math.max(1, Math.min(Number(req.query.limit ?? 25), 25));
    res.json({ commands: queue.splice(0, limit) });
  });

  app.post("/v1/tunnels/:tunnelId/response", (req, res) => {
    if (!guard(req, res)) return;
    const requestId = String(req.body?.request_id ?? "");
    const shard = String(req.headers["x-tunnel-shard-token"] ?? "");
    if (!requestId || expectedShard.get(requestId) !== shard) return res.status(400).json({ error: "bad correlation" });
    responses.set(requestId, req.body);
    wakeResponse(requestId);
    res.json({ status: "ok" });
  });

  app.post("/dev/enqueue", (req, res) => {
    const commandType = String(req.body?.command_type ?? "jsonrpc");
    const requestId = crypto.randomUUID();
    const shardToken = crypto.randomBytes(18).toString("hex");
    const command: TunnelCommand = {
      request_id: requestId,
      shard_token: shardToken,
      command_type: commandType,
      channel: String(req.body?.channel ?? "main"),
      created_at: new Date().toISOString(),
      response_timeout: req.body?.response_timeout ?? "30s",
      headers: req.body?.headers && typeof req.body.headers === "object" ? req.body.headers : {},
    };
    if (commandType === "jsonrpc") command.jsonrpc = req.body?.jsonrpc ?? {};
    queue.push(command);
    expectedShard.set(requestId, shardToken);
    wakePollers();
    res.json({ request_id: requestId });
  });

  app.get("/dev/response/:requestId", async (req, res) => {
    const requestId = String(req.params.requestId);
    if (!responses.has(requestId)) {
      const timeoutMs = Math.max(1, Math.min(Number(req.query.timeout_ms ?? 5000), 30000));
      await new Promise<void>((resolve) => {
        const waiter: Waiter = { resolve, timer: setTimeout(resolve, timeoutMs) };
        const set = responseWaiters.get(requestId) ?? new Set<Waiter>();
        set.add(waiter);
        responseWaiters.set(requestId, set);
      });
    }
    if (!responses.has(requestId)) return res.status(204).end();
    const value = responses.get(requestId);
    responses.delete(requestId);
    expectedShard.delete(requestId);
    res.json(value);
  });

  app.get("/health", (_req, res) => res.json({ ok: true, queued: queue.length, responses: responses.size }));
  const server = http.createServer(app);

  return {
    app,
    server,
    tunnelId,
    apiKey,
    async start() {
      await new Promise<void>((resolve, reject) => {
        server.once("error", reject);
        server.listen(port, host, () => { server.off("error", reject); resolve(); });
      });
      const address = server.address();
      if (!address || typeof address === "string") throw new Error("stub did not bind");
      return { host, port: address.port };
    },
    async stop() {
      wakePollers();
      for (const sets of responseWaiters.values()) for (const waiter of sets) { clearTimeout(waiter.timer); waiter.resolve(); }
      responseWaiters.clear();
      if (server.listening) await new Promise<void>((resolve, reject) => server.close((err) => err ? reject(err) : resolve()));
    },
  };
}

if (import.meta.url === new URL(`file:///${process.argv[1]?.replace(/\\/g, "/")}`).href) {
  const stub = createSecureTunnelStub();
  const bound = await stub.start();
  console.log(`[secure-tunnel-stub] listening on http://${bound.host}:${bound.port}`);
  const shutdown = async () => { await stub.stop(); process.exit(0); };
  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
}
