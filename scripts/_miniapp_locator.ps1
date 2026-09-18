$ErrorActionPreference = 'Stop'
$smokeScript = 'D:\Agent\u8bbe\u8ba1\harness-self-evolution-plugin\_miniapp_smoke.mjs'
# Also probe /dashboard/api/call with scan_plugins as a real end-to-end check
$ext = @'
import { start } from 'file:///D:/Agent%E8%AE%BE%E8%AE%A1/harness-self-evolution-plugin/miniapps/harness-evolution-panel/miniapp/node/server.mjs';
import net from 'node:net';
function freePort(){return new Promise((r,j)=>{const s=net.createServer();s.once('error',j);s.listen(0,'127.0.0.1',()=>{const p=s.address().port;s.close(()=>r(p));});});}
const ac=new AbortController();
const port=await freePort();
const ctx={pluginRoot:'D:/Agent\u8bbe\u8ba1/harness-self-evolution-plugin/miniapps/harness-evolution-panel',listen:{port,host:'127.0.0.1'},signal:ac.signal};
const h=await start(ctx);
await new Promise(r=>setTimeout(r,200));
const r=await fetch('http://127.0.0.1:'+port+'/dashboard/api/call',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({name:'scan_plugins',arguments:{}})});
const txt=await r.text();
console.log('SCAN status='+r.status+' body_first_500='+txt.slice(0,500));
await h.dispose();ac.abort();process.exit(0);
'@
[System.IO.File]::WriteAllText('D:\Agent\u8bbe\u8ba1\harness-self-evolution-plugin\_miniapp_call.mjs', $ext, [System.Text.UTF8Encoding]::new($false))
node 'D:\Agent\u8bbe\u8ba1\harness-self-evolution-plugin\_miniapp_call.mjs' 2>&1 | Out-String