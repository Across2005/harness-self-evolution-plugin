// Real end-to-end test: scan_plugins via the Mini App panel server.
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
const h = await start(ctx);
await new Promise((r) => setTimeout(r, 200));
const r = await fetch('http://127.0.0.1:' + port + '/dashboard/api/call', {
  method: 'POST',
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ name: 'scan_plugins', arguments: {} }),
});
const txt = await r.text();
console.log('SCAN status=' + r.status);
console.log('body_head=' + txt.slice(0, 800));
await h.dispose();
ac.abort();
process.exit(0);