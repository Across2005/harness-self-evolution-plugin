// Real run: full-sweep scan + propose -> approve -> execute (non-dry-run)
// against the REAL data root (~/.harness-evolution/v2), exactly as DSH's
// mcp-client would drive the binary. Prints a step-by-step process trace.
import { spawn } from 'node:child_process';
import path from 'node:path';

const EXE = 'D:/Agent设计/harness-self-evolution-plugin/bin/harness-evolution.exe';
const REPO = 'D:/Agent设计/harness-self-evolution-plugin';

const child = spawn(EXE, [], {
  cwd: REPO,
  env: { ...process.env, HARNESS_EVOLUTION_HOST: 'deepseek-harness' }, // real data root (default)
  stdio: ['pipe', 'pipe', 'pipe'],
});

let buf = '';
const pending = new Map();
let nextId = 1;
child.stdout.on('data', (d) => {
  buf += d.toString('utf8');
  let i;
  while ((i = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, i).trim(); buf = buf.slice(i + 1);
    if (!line) continue;
    let m; try { m = JSON.parse(line); } catch { continue; }
    if (m.id !== undefined && pending.has(m.id)) { pending.get(m.id).resolve(m); pending.delete(m.id); }
  }
});
child.stderr.on('data', () => {}); // ignore server logs (we surface our own trace)

function rpc(method, params) {
  const id = nextId++;
  child.stdin.write(JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n');
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    setTimeout(() => { if (pending.has(id)) { pending.delete(id); reject(new Error('timeout: ' + method)); } }, 180000);
  });
}
async function call(name, args) {
  const r = await rpc('tools/call', { name, arguments: args });
  if (r.error) return { isError: true, text: JSON.stringify(r.error), parsed: null };
  const text = (r.result?.content?.[0]?.text || '');
  let parsed = null; try { parsed = JSON.parse(text); } catch {}
  return { isError: !!r.result?.isError, text, parsed };
}
const stamp = () => new Date().toISOString().slice(11, 23);
const log = (s) => console.log('[' + stamp() + '] ' + s);

try {
  await rpc('initialize', { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'real-run', version: '1.0.0' } });
  await rpc('notifications/initialized', {});

  // ---- existing proposals (to avoid cooldown when picking a target) ----
  const before = await call('list_proposals', {});
  const recentIds = new Set((before.parsed?.proposals || []).map((p) => p.plugin_id));
  log('STEP 1/7  已有提案 ' + (before.parsed?.count ?? '?') + ' 条（涉及插件 ' + [...recentIds].join(', ') + '）');

  // ---- full sweep scan (全盘更新 skill) ----
  log('STEP 2/7  全盘扫描（force_rescan=true，覆盖全部扫描根）...');
  const t0 = Date.now();
  const scan = await call('scan_plugins', { force_rescan: true });
  const plugins = scan.parsed?.plugins || [];
  log('STEP 2/7  完成，耗时 ' + (Date.now() - t0) + 'ms，发现 ' + (scan.parsed?.plugin_count ?? 0) + ' 个插件');
  for (const p of plugins) {
    console.log('    - ' + p.plugin_id + '  (type=' + p.type + ', tools=' + p.tools_count + ')');
  }

  // ---- pick a target not under cooldown ----
  const target = plugins.find((p) => !recentIds.has(p.plugin_id)) || plugins[0];
  if (!target) { log('无可用插件，退出'); child.kill(); process.exit(0); }
  log('STEP 3/7  选取目标插件: ' + target.plugin_id);

  // ---- metrics (real, read-only) ----
  const m = await call('get_plugin_metrics', { plugin_id: target.plugin_id, time_range: 'all' });
  log('STEP 4/7  指标: ' + JSON.stringify(m.parsed?.statistics || m.text));

  // ---- propose ----
  const prop = await call('propose_evolution', { plugin_id: target.plugin_id, signals: ['real end-to-end run: full sweep refresh'] });
  if (!prop.parsed?.proposal) {
    log('STEP 5/7  提案未产出: reason=' + (prop.parsed?.reason || prop.text));
    child.kill(); process.exit(0);
  }
  const pid = prop.parsed.proposal.proposal_id;
  log('STEP 5/7  提案已生成: ' + pid + ' (type=' + prop.parsed.proposal.evolution_type + ', principle=' + prop.parsed.proposal.matt_pocock_principle + ')');

  // ---- approve ----
  const appr = await call('approve_proposal', { proposal_id: pid });
  log('STEP 6/7  审批: ' + (appr.isError ? 'FAIL ' + appr.text : appr.parsed?.message));

  // ---- execute (real, non-dry-run) ----
  log('STEP 7/7  执行（非 dry-run）...');
  const ex = await call('execute_evolution', { proposal_id: pid, dry_run: false });
  log('STEP 7/7  执行结果 success=' + ex.parsed?.success + (ex.parsed?.error ? ' error=' + ex.parsed.error : ''));
  for (const r of ex.parsed?.results || []) {
    console.log('    - agent=' + r.agent + '  success=' + r.success + '  ' + r.duration_ms + 'ms' + (r.error ? '  err=' + r.error : ''));
  }

  // ---- final state ----
  const after = await call('list_proposals', {});
  const snap = await call('get_runtime_snapshot', { tail_lines: 25 });
  log('最终提案计数: ' + JSON.stringify(after.parsed?.proposals?.map((p) => p.proposal_id + ':' + p.status)));
  log('快照 count_by_status: ' + JSON.stringify(snap.parsed?.proposals?.count_by_status));
  log('快照 data_gaps: ' + JSON.stringify(snap.parsed?.data_gaps));
  log('DONE');
} catch (e) {
  console.error('FATAL', e);
  process.exitCode = 1;
} finally {
  child.kill();
}
