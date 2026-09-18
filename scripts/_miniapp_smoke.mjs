// Smoke test: load Mini App server.mjs with a stub context and probe its routes.
import { start } from 'file:///D:/Agent%E8%AE%BE%E8%AE%A1/harness-self-evolution-plugin/miniapps/harness-evolution-panel/miniapp/node/server.mjs';
import net from 'node:net';

function freePort() {
  return new Promise((resolve, reject) => {
    const s = net.createServer();
    s.once('error', reject);
    s.listen(0, '127.0.0.1', () => {
      const p = s.address().port;
      s.close(() => resolve(p));
    });
  });
}

const ac = new AbortController();
const port = await freePort();
const ctx = {
  pluginRoot: 'D:/Agent\u8bbe\u8ba1/harness-self-evolution-plugin/miniapps/harness-evolution-panel',
  listen: { port, host: '127.0.0.1' },
  signal: ac.signal,
};

const handle = await start(ctx);
console.log('[smoke] Mini App started on', port);

await new Promise((r) => setTimeout(r, 200));

async function probe(path) {
  try {
    const resp = await fetch(`http://127.0.0.1:${port}${path}`);
    const text = await resp.text();
    console.log(`[smoke] ${path} -> ${resp.status} (${text.length} bytes)`);
    if (text.length < 200) console.log('  body:', text);
    else console.log('  head:', text.slice(0, 120), '…');
  } catch (e) {
    console.log(`[smoke] ${path} ERR:`, e.message);
  }
}

await probe('/dashboard');
await probe('/dashboard/api/status');
await probe('/dashboard/api/tools');

await handle.dispose();
ac.abort();
console.log('[smoke] done');
process.exit(0);