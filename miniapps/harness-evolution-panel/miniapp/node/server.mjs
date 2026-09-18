// miniapp/node/server.mjs
// HTTP frontend for the harness-evolution Mini App.
//
// Protocol rules (runtime-api.md):
//   - stdout is reserved for the Host Connector NDJSON protocol; never write to stdout.
//   - All logging must go through context.logger, not console.log/process.stderr.
//   - start(context) must not perform business calls; only install routes and start the listener.
//   - Resolve start() only after the listener accepts connections.

import { readFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { join } from 'node:path';
import { spawn } from 'node:child_process';

const PROTOCOL_VERSION = '2024-11-05';
const EXE_FALLBACK = 'D:/Agent设计/harness-self-evolution-plugin/bin/harness-evolution.exe';

let mcp = null;

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => {
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
      } catch (err) {
        reject(err);
      }
    });
    req.on('error', reject);
  });
}

function writeJson(res, status, payload) {
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
  });
  res.end(JSON.stringify(payload));
}

function mcpFrame(id, method, params) {
  return JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n';
}

async function ensureMcp(logger) {
  if (mcp && mcp.ready) return mcp;

  const exe = process.env.HARNESS_EVOLUTION_EXE || EXE_FALLBACK;
  logger.info('spawning harness-evolution exe', { exe });

  const child = spawn(exe, [], {
    stdio: ['pipe', 'pipe', 'pipe'],
    env: {
      ...process.env,
      HARNESS_EVOLUTION_HOST: process.env.HARNESS_EVOLUTION_HOST || 'minimax-code',
    },
    windowsHide: true,
  });

  const pending = new Map();
  let nextId = 1;
  let buf = '';

  child.stdout.on('data', (chunk) => {
    buf += chunk.toString('utf8');
    let nl;
    while ((nl = buf.indexOf('\n')) >= 0) {
      const line = buf.slice(0, nl).trim();
      buf = buf.slice(nl + 1);
      if (!line) continue;
      try {
        const msg = JSON.parse(line);
        if (msg.id != null && pending.has(msg.id)) {
          const { resolve, reject } = pending.get(msg.id);
          pending.delete(msg.id);
          if (msg.error) reject(new Error(msg.error.message || JSON.stringify(msg.error)));
          else resolve(msg.result);
        }
      } catch {
        // ignore non-JSON lines
      }
    }
  });

  // Forward child stderr to logger; never to process.stderr (Host protocol).
  child.stderr.on('data', (chunk) => {
    const text = chunk.toString('utf8').trim();
    if (text) logger.debug('exe-stderr', { text: text.slice(0, 500) });
  });

  child.on('exit', (code, signal) => {
    for (const { reject } of pending.values()) {
      reject(new Error(`mcp exited (code=${code} signal=${signal})`));
    }
    pending.clear();
    mcp = null;
  });

  function request(method, params) {
    return new Promise((resolve, reject) => {
      const id = nextId++;
      pending.set(id, { resolve, reject });
      child.stdin.write(mcpFrame(id, method, params));
    });
  }

  const initResult = await request('initialize', {
    protocolVersion: PROTOCOL_VERSION,
    capabilities: {},
    clientInfo: { name: 'harness-evolution-panel', version: '1.0.0' },
  });
  // initialized notification (no id)
  child.stdin.write(
    JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' }) + '\n',
  );

  mcp = { child, request, ready: true, serverInfo: initResult?.serverInfo ?? null };
  logger.info('mcp handshake complete', { serverInfo: mcp.serverInfo });
  return mcp;
}

async function handleApi(req, res, pathname, logger) {
  try {
    const client = await ensureMcp(logger);

    if (req.method === 'GET' && pathname === '/dashboard/api/status') {
      writeJson(res, 200, {
        ok: true,
        serverInfo: client.serverInfo,
        pid: client.child.pid,
        exe: process.env.HARNESS_EVOLUTION_EXE || EXE_FALLBACK,
      });
      return;
    }

    if (req.method === 'GET' && pathname === '/dashboard/api/tools') {
      const result = await client.request('tools/list', {});
      writeJson(res, 200, { ok: true, tools: result?.tools ?? [] });
      return;
    }

    if (req.method === 'POST' && pathname === '/dashboard/api/call') {
      const body = await readBody(req);
      const { name, arguments: args } = body ?? {};
      if (typeof name !== 'string' || !name) {
        writeJson(res, 400, { ok: false, error: 'name is required' });
        return;
      }
      const result = await client.request('tools/call', { name, arguments: args ?? {} });
      writeJson(res, 200, { ok: true, result });
      return;
    }

    writeJson(res, 404, { ok: false, error: 'not_found' });
  } catch (err) {
    logger.error('api handler failed', { message: String(err?.message ?? err) });
    writeJson(res, 500, { ok: false, error: String(err?.message ?? err) });
  }
}

export async function start(context) {
  const { logger } = context;
  const indexHtml = await readFile(
    join(context.pluginRoot, 'miniapp/client/index.html'),
    'utf8',
  );

  const server = createServer(async (req, res) => {
    const url = new URL(req.url ?? '/', 'http://miniapp.local');
    const pathname = url.pathname;

    if (req.method === 'GET' && pathname === '/dashboard') {
      res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
      res.end(indexHtml);
      return;
    }

    if (pathname.startsWith('/dashboard/api/')) {
      await handleApi(req, res, pathname, logger);
      return;
    }

    res.writeHead(404, { 'content-type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({ error: 'not_found' }));
  });

  await new Promise((resolve, reject) => {
    const onError = (error) => reject(error);
    server.once('error', onError);
    server.listen(context.listen.port, context.listen.host, () => {
      server.off('error', onError);
      logger.info('listener ready', { port: context.listen.port });
      resolve();
    });
  });

  let disposal;
  const dispose = () => {
    if (disposal) return disposal;
    if (mcp && mcp.child) {
      try {
        mcp.child.stdin.end();
      } catch {
        // ignore
      }
    }
    disposal = new Promise((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });
    return disposal;
  };
  const onAbort = () => {
    void dispose().catch(() => {});
  };
  context.signal.addEventListener('abort', onAbort, { once: true });
  if (context.signal.aborted) await dispose();

  return { dispose };
}