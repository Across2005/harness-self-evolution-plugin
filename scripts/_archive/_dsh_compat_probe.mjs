// DSH compatibility probe: drive bin/harness-evolution.exe as a stdio MCP server.
// Isolated data dir via HARNESS_EVOLUTION_HOME so we never touch real ~/.harness-evolution data.
import { spawn } from 'node:child_process';
import { mkdtempSync, writeFileSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

const EXE = process.argv[2];
const home = mkdtempSync(path.join(tmpdir(), 'dsh-compat-'));

// Build a tiny fake plugin tree so scan_plugins has something to find.
const scanRoot = path.join(home, 'scan');
const fake = path.join(scanRoot, 'plugins', 'demo-skill-1.0.0');
mkdirSync(fake, { recursive: true });
writeFileSync(path.join(fake, 'SKILL.md'), '---\nname: demo-skill\ndescription: demo plugin for DSH compat test\n---\n\n# Demo\n');

const child = spawn(EXE, [], {
  cwd: scanRoot,
  env: { ...process.env, HARNESS_EVOLUTION_HOME: home, HARNESS_EVOLUTION_HOST: 'deepseek-harness' },
  stdio: ['pipe', 'pipe', 'pipe'],
});

let buf = '';
const pending = new Map();
let nextId = 1;
child.stdout.on('data', (d) => {
  buf += d.toString('utf8');
  let idx;
  while ((idx = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, idx).trim();
    buf = buf.slice(idx + 1);
    if (!line) continue;
    let msg;
    try { msg = JSON.parse(line); } catch { console.error('[stdout non-json]', line.slice(0, 200)); continue; }
    if (msg.id !== undefined && pending.has(msg.id)) {
      const { resolve } = pending.get(msg.id);
      pending.delete(msg.id);
      resolve(msg);
    } else {
      console.error('[notification]', JSON.stringify(msg).slice(0, 160));
    }
  }
});
child.stderr.on('data', (d) => console.error('[stderr]', d.toString('utf8').slice(0, 300)));

function rpc(method, params, isNotification = false) {
  const id = nextId++;
  const payload = JSON.stringify(isNotification ? { jsonrpc: '2.0', method, params } : { jsonrpc: '2.0', id, method, params });
  child.stdin.write(payload + '\n');
  if (isNotification) return Promise.resolve(null);
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    setTimeout(() => { if (pending.has(id)) { pending.delete(id); reject(new Error('timeout: ' + method)); } }, 15000);
  });
}

const results = {};
try {
  const init = await rpc('initialize', {
    protocolVersion: '2024-11-05',
    capabilities: {},
    clientInfo: { name: 'dsh-compat-probe', version: '1.0.0' },
  });
  results.initialize = init.result ? {
    protocolVersion: init.result.protocolVersion,
    server: init.result.serverInfo,
    capabilities: Object.keys(init.result.capabilities || {}),
  } : init;
  await rpc('notifications/initialized', {}, true);

  const list = await rpc('tools/list', {});
  results.tools_list = { count: (list.result?.tools || []).length, names: (list.result?.tools || []).map(t => t.name) };

  const scan = await rpc('tools/call', { name: 'scan_plugins', arguments: { dirs: [scanRoot] } });
  const sc = scan.result;
  results.scan_plugins = { isError: !!sc.isError, text: (sc.content?.[0]?.text || '').slice(0, 400) };

  const prop = await rpc('tools/call', { name: 'list_proposals', arguments: { status: 'pending' } });
  results.list_proposals = { isError: !!prop.result.isError, text: (prop.result.content?.[0]?.text || '').slice(0, 200) };

  // Unknown tool must produce a JSON-RPC error or tool error, not a crash.
  const bad = await rpc('tools/call', { name: 'no_such_tool', arguments: {} });
  results.unknown_tool = bad.error ? { jsonrpc_error: bad.error.code } : { isError: !!bad.result.isError };

  const snap = await rpc('tools/call', { name: 'get_runtime_snapshot', arguments: {} });
  results.get_runtime_snapshot = { isError: !!snap.result.isError, text: (snap.result.content?.[0]?.text || '').slice(0, 300) };
} catch (e) {
  results.fatal = String(e);
}
console.log('PROBE_RESULTS ' + JSON.stringify(results, null, 2));
child.kill();
process.exit(0);
