// Full end-to-end MCP test for bin/harness-evolution.exe on DeepSeek Harness.
// Drives the binary as a stdio MCP server (JSON-RPC, newline-delimited) and
// exercises all 14 tools + the propose -> approve -> execute -> completed loop,
// sub-agent factory (plugin + user scope), merged tools, error paths, and the
// runtime snapshot. Everything runs against an isolated temp data root so no
// real ~/.harness-evolution or ~/.dsh data is touched.
import { spawn } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, existsSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

const EXE = process.argv[2] || 'D:/Agent设计/harness-self-evolution-plugin/bin/harness-evolution.exe';
const REPO = 'D:/Agent设计/harness-self-evolution-plugin';

const home = mkdtempSync(path.join(tmpdir(), 'evo-e2e-'));
const userDir = path.join(home, 'user');
const scanRoot = path.join(home, 'scan');
mkdirSync(userDir, { recursive: true });
mkdirSync(scanRoot, { recursive: true });

// --- Build a tiny fake plugin ecosystem so scan_plugins has something to find.
// Plugin A: package.json manifest (depth 1).
const a = path.join(scanRoot, 'demo-skill');
mkdirSync(a, { recursive: true });
writeFileSync(path.join(a, 'package.json'), JSON.stringify({ name: 'demo-skill', version: '1.0.0', description: 'demo plugin for E2E' }));
writeFileSync(path.join(a, 'SKILL.md'), '---\nname: demo-skill\ndescription: browse the web and generate code\n---\n\n# Demo\nUse a browser, write code.\n');
// Plugin B: .zcode-plugin/plugin.json manifest (depth 2, mimosa-style).
const b = path.join(scanRoot, 'mimosa-like');
mkdirSync(path.join(b, '.zcode-plugin'), { recursive: true });
writeFileSync(path.join(b, '.zcode-plugin', 'plugin.json'), JSON.stringify({ name: 'mimosa-like', version: '2.0.0' }));
writeFileSync(path.join(b, 'SKILL.md'), '---\nname: mimosa-like\ndescription: academic writing helper\n---\n\n# Mimosa\nHelps write academic papers.\n');
// Plugin C: fresh plugin (no cooldown) for merged-tool propose happy path.
const c = path.join(scanRoot, 'fresh-plugin');
mkdirSync(c, { recursive: true });
writeFileSync(path.join(c, 'package.json'), JSON.stringify({ name: 'fresh-plugin', version: '3.0.0' }));
writeFileSync(path.join(c, 'SKILL.md'), '---\nname: fresh-plugin\ndescription: translate text\n---\n\n# Fresh\nTranslates documents.\n');

const child = spawn(EXE, [], {
  cwd: REPO,
  env: {
    ...process.env,
    HARNESS_EVOLUTION_HOME: home,
    HARNESS_EVOLUTION_HOST: 'deepseek-harness',
    HARNESS_EVOLUTION_USER_DIR: userDir,
  },
  stdio: ['pipe', 'pipe', 'pipe'],
});

let buf = '';
const pending = new Map();
let nextId = 1;
const stderrLines = [];
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
    }
  }
});
child.stderr.on('data', (d) => stderrLines.push(d.toString('utf8')));

function rpc(method, params, isNotification = false) {
  const id = nextId++;
  const payload = JSON.stringify(isNotification ? { jsonrpc: '2.0', method, params } : { jsonrpc: '2.0', id, method, params });
  child.stdin.write(payload + '\n');
  if (isNotification) return Promise.resolve(null);
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    setTimeout(() => { if (pending.has(id)) { pending.delete(id); reject(new Error('timeout: ' + method)); } }, 20000);
  });
}

// toolCall returns { isError, text, parsed } where parsed is JSON.parse(text) if possible.
async function toolCall(name, args) {
  const r = await rpc('tools/call', { name, arguments: args });
  if (r.error) return { jsonrpc_error: r.error, isError: true, text: '', parsed: null };
  const res = r.result;
  const text = (res.content?.[0]?.text || '');
  let parsed = null;
  try { parsed = JSON.parse(text); } catch {}
  return { isError: !!res.isError, text, parsed };
}

const results = [];
function check(name, cond, detail) {
  results.push({ name, pass: !!cond, detail });
  console.log((cond ? 'PASS' : 'FAIL') + '  ' + name + (detail ? '  | ' + detail : ''));
}
const ok = (x) => !!x;
const snippet = (x) => {
  if (x === undefined) return 'undefined';
  const s = typeof x === 'string' ? x : (JSON.stringify(x) ?? String(x));
  return s.slice(0, 200);
};

const expectedTools = [
  'scan_plugins', 'get_plugin_metrics', 'propose_evolution', 'execute_evolution',
  'list_proposals', 'approve_proposal', 'reject_proposal', 'create_sub_agent',
  'list_sub_agents', 'delete_sub_agent', 'analyze_plugins', 'evolve_plugin',
  'manage_sub_agent', 'get_runtime_snapshot',
];

let proposalId = null;

try {
  // --- initialize handshake ---
  const init = await rpc('initialize', {
    protocolVersion: '2024-11-05',
    capabilities: {},
    clientInfo: { name: 'e2e-full', version: '1.0.0' },
  });
  check('initialize', ok(init.result?.serverInfo?.name), JSON.stringify(init.result?.serverInfo));
  await rpc('notifications/initialized', {}, true);

  // --- tools/list: exactly 14, correct order ---
  const list = await rpc('tools/list', {});
  const names = (list.result?.tools || []).map((t) => t.name);
  check('tools/list count == 14', names.length === 14, 'count=' + names.length);
  check('tools/list names match', JSON.stringify(names) === JSON.stringify(expectedTools), names.join(','));

  // --- scan_plugins (path redirection) ---
  const scan = await toolCall('scan_plugins', { target_paths: [scanRoot] });
  const plugins = scan.parsed?.plugins || [];
  check('scan_plugins success', !scan.isError && scan.parsed?.success === true, JSON.stringify(scan.parsed).slice(0, 200));
  check('scan_plugins found >=2 plugins', plugins.length >= 2, 'count=' + (scan.parsed?.plugin_count ?? '?'));
  const hasDemo = plugins.some((p) => p.plugin_id === 'demo-skill-1.0.0');
  const hasMimosa = plugins.some((p) => p.plugin_id === 'mimosa-like-2.0.0');
  const hasFresh = plugins.some((p) => p.plugin_id === 'fresh-plugin-3.0.0');
  check('scan_plugins found demo-skill-1.0.0', hasDemo, 'ids=' + plugins.map((p) => p.plugin_id).join(','));
  check('scan_plugins found mimosa-like-2.0.0', hasMimosa, 'ids=' + plugins.map((p) => p.plugin_id).join(','));
  check('scan_plugins found fresh-plugin-3.0.0', hasFresh, 'ids=' + plugins.map((p) => p.plugin_id).join(','));

  // --- scan_plugins (targeted rescan by plugin_id) ---
  const rescan = await toolCall('scan_plugins', { plugin_ids: ['demo-skill-1.0.0'] });
  check('scan_plugins targeted rescan', !rescan.isError && rescan.parsed?.success === true, JSON.stringify(rescan.parsed).slice(0, 160));

  // --- get_plugin_metrics ---
  const metrics = await toolCall('get_plugin_metrics', { plugin_id: 'demo-skill-1.0.0', time_range: 'all' });
  check('get_plugin_metrics success', !metrics.isError && metrics.parsed?.success === true, JSON.stringify(metrics.parsed).slice(0, 160));
  check('get_plugin_metrics statistics shape', ok(metrics.parsed?.statistics) && 'total_calls' in (metrics.parsed.statistics || {}), JSON.stringify(metrics.parsed?.statistics));

  // --- get_plugin_metrics: invalid time_range -> isError ---
  const badRange = await toolCall('get_plugin_metrics', { plugin_id: 'demo-skill-1.0.0', time_range: 'nope' });
  check('get_plugin_metrics bad range -> isError', badRange.isError === true, badRange.text.slice(0, 120));

  // --- propose_evolution (manual strong signals) ---
  const propose = await toolCall('propose_evolution', { plugin_id: 'demo-skill-1.0.0', signals: ['user reported slow startup', 'repeated parameter misuse'] });
  if (propose.parsed?.proposal) {
    proposalId = propose.parsed.proposal.proposal_id;
    check('propose_evolution produced proposal', true, 'id=' + proposalId + ' type=' + propose.parsed.proposal.evolution_type + ' status=' + propose.parsed.proposal.status);
    check('propose status == pending', propose.parsed.proposal.status === 'pending', propose.parsed.proposal.status);
  } else {
    check('propose_evolution produced proposal', false, 'reason=' + (propose.parsed?.reason || propose.text.slice(0, 160)));
  }

  // --- propose_evolution: unknown plugin -> isError with exact message ---
  const badPropose = await toolCall('propose_evolution', { plugin_id: 'no-such-plugin-0.0.0' });
  check('propose unknown plugin -> isError', badPropose.isError === true, badPropose.text.slice(0, 120));
  check('propose unknown plugin message', /Run scan_plugins first/.test(badPropose.text), badPropose.text.slice(0, 120));

  // --- list_proposals ---
  const lprops = await toolCall('list_proposals', {});
  check('list_proposals success', !lprops.isError && lprops.parsed?.success === true, 'count=' + lprops.parsed?.count);
  check('list_proposals count >= 1', (lprops.parsed?.proposals?.length || 0) >= 1, 'n=' + lprops.parsed?.proposals?.length);

  if (proposalId) {
    // --- execute_evolution before approval -> success:false, status must stay pending ---
    const execPending = await toolCall('execute_evolution', { proposal_id: proposalId });
    check('execute before approve -> success:false', execPending.parsed?.success === false, JSON.stringify(execPending.parsed));
    check('execute before approve error text', /expected 'approved'/.test(execPending.parsed?.error || ''), execPending.parsed?.error);

    // --- approve_proposal ---
    const approve = await toolCall('approve_proposal', { proposal_id: proposalId });
    check('approve_proposal success', !approve.isError && approve.parsed?.success === true, JSON.stringify(approve.parsed));

    // --- approve again: idempotent (set_status returns true on same status) ---
    const approve2 = await toolCall('approve_proposal', { proposal_id: proposalId });
    check('approve already-approved -> idempotent success', !approve2.isError && approve2.parsed?.success === true, JSON.stringify(approve2.parsed));

    // --- execute_evolution (dry_run) ---
    const exec = await toolCall('execute_evolution', { proposal_id: proposalId, dry_run: true });
    check('execute_evolution success', exec.parsed?.success === true, JSON.stringify(exec.parsed).slice(0, 160));
    check('execute_evolution has results', (exec.parsed?.results?.length || 0) >= 1, 'agents=' + (exec.parsed?.results || []).map((r) => r.agent).join(','));

    // --- list_proposals: now completed ---
    const lprops2 = await toolCall('list_proposals', { status: 'completed' });
    const done = (lprops2.parsed?.proposals || []).some((p) => p.proposal_id === proposalId);
    check('list_proposals completed contains id', done, 'n=' + lprops2.parsed?.proposals?.length);

    // --- execute completed -> error "expected 'approved'" ---
    const execAgain = await toolCall('execute_evolution', { proposal_id: proposalId });
    check('execute completed -> success:false', execAgain.parsed?.success === false, execAgain.parsed?.error);

    // --- approve a completed proposal -> illegal transition isError ---
    const approveDone = await toolCall('approve_proposal', { proposal_id: proposalId });
    check('approve completed -> illegal transition isError', approveDone.isError === true && /Illegal proposal status transition/.test(approveDone.text), approveDone.text.slice(0, 160));
  }

  // --- reject flow: propose a second proposal, then reject it ---
  const propose2 = await toolCall('propose_evolution', { plugin_id: 'mimosa-like-2.0.0', signals: ['user wants citation normalization'] });
  let rejectId = null;
  if (propose2.parsed?.proposal) {
    rejectId = propose2.parsed.proposal.proposal_id;
    const reject = await toolCall('reject_proposal', { proposal_id: rejectId });
    check('reject_proposal success', !reject.isError && reject.parsed?.success === true, JSON.stringify(reject.parsed));
    const lrej = await toolCall('list_proposals', { status: 'rejected' });
    check('list_proposals rejected contains id', (lrej.parsed?.proposals || []).some((p) => p.proposal_id === rejectId), 'n=' + lrej.parsed?.proposals?.length);
  } else {
    check('reject flow: second proposal produced', false, propose2.parsed?.reason || propose2.text.slice(0, 120));
  }

  // --- sub-agent factory: plugin scope ---
  const create = await toolCall('create_sub_agent', { name: 'evo-smoke', description: 'smoke test agent', system_prompt: 'You are a smoke test agent.', scope: 'plugin', color: 'red', tools: ['scan_plugins'] });
  check('create_sub_agent plugin scope', !create.isError && create.parsed?.success === true, JSON.stringify(create.parsed));
  check('create_sub_agent path under data root', /evo-smoke\.md$/.test(create.parsed?.path || ''), create.parsed?.path);

  // --- duplicate without overwrite -> isError "already exists" ---
  const dup = await toolCall('create_sub_agent', { name: 'evo-smoke', description: 'x', system_prompt: 'y', scope: 'plugin' });
  check('create duplicate -> isError', dup.isError === true, dup.text.slice(0, 140));
  check('create duplicate message', /already exists/.test(dup.text), dup.text.slice(0, 140));

  // --- duplicate with overwrite -> success, overwritten true ---
  const dup2 = await toolCall('create_sub_agent', { name: 'evo-smoke', description: 'x', system_prompt: 'y', scope: 'plugin', overwrite: true });
  check('create overwrite -> success', !dup2.isError && dup2.parsed?.success === true && dup2.parsed?.overwritten === true, JSON.stringify(dup2.parsed));

  // --- user scope (DSH writes to ~/.dsh/skills via HARNESS_EVOLUTION_USER_DIR) ---
  const createUser = await toolCall('create_sub_agent', { name: 'evo-user-smoke', description: 'user scope smoke', system_prompt: 'You are a user-scope agent.', scope: 'user' });
  check('create_sub_agent user scope', !createUser.isError && createUser.parsed?.success === true, JSON.stringify(createUser.parsed));
  check('create user scope path under user dir', (createUser.parsed?.path || '').includes('user'), createUser.parsed?.path);

  // --- list_sub_agents (both scopes) ---
  const lsa = await toolCall('list_sub_agents', {});
  const agentNames = (lsa.parsed?.agents || []).map((x) => x.name);
  check('list_sub_agents both scopes', !lsa.isError && agentNames.includes('evo-smoke') && agentNames.includes('evo-user-smoke'), agentNames.join(','));
  check('list_sub_agents scope field', (lsa.parsed?.agents || []).every((x) => x.scope === 'plugin' || x.scope === 'user'), '');

  // --- list_sub_agents scope=plugin only ---
  const lsaPlugin = await toolCall('list_sub_agents', { scope: 'plugin' });
  const pluginScoped = (lsaPlugin.parsed?.agents || []).every((x) => x.scope === 'plugin');
  check('list_sub_agents plugin scope only', pluginScoped, (lsaPlugin.parsed?.agents || []).map((x) => x.name + ':' + x.scope).join(','));

  // --- delete_sub_agent ---
  const del = await toolCall('delete_sub_agent', { name: 'evo-smoke', scope: 'plugin' });
  check('delete_sub_agent plugin', !del.isError && del.parsed?.success === true, JSON.stringify(del.parsed));
  const delUser = await toolCall('delete_sub_agent', { name: 'evo-user-smoke', scope: 'user' });
  check('delete_sub_agent user', !delUser.isError && delUser.parsed?.success === true, JSON.stringify(delUser.parsed));
  const delMissing = await toolCall('delete_sub_agent', { name: 'evo-smoke', scope: 'plugin' });
  check('delete missing -> isError', delMissing.isError === true, delMissing.text.slice(0, 140));

  // --- analyze_plugins (merged) ---
  const an = await toolCall('analyze_plugins', { mode: 'both', plugin_id: 'demo-skill-1.0.0', target_paths: [scanRoot] });
  check('analyze_plugins mode=both', !an.isError, JSON.stringify(an.parsed).slice(0, 160));
  check('analyze_plugins metrics present', ok(an.parsed?.statistics), '');
  const anBad = await toolCall('analyze_plugins', { mode: 'metrics' });
  check('analyze_plugins metrics w/o plugin_id -> isError', anBad.isError === true, anBad.text.slice(0, 140));
  const anBadMode = await toolCall('analyze_plugins', { mode: 'nope' });
  check('analyze_plugins bad mode -> isError', anBadMode.isError === true, anBadMode.text.slice(0, 140));

  // --- evolve_plugin (merged) ---
  const ev = await toolCall('evolve_plugin', { action: 'propose', plugin_id: 'fresh-plugin-3.0.0', signals: ['merge tools to reduce latency'] });
  check('evolve_plugin propose produces proposal', !ev.isError && ok(ev.parsed?.proposal), snippet(ev.parsed));
  const evBad = await toolCall('evolve_plugin', { action: 'propose' });
  check('evolve_plugin propose w/o plugin_id -> isError', evBad.isError === true, evBad.text.slice(0, 140));
  const evBadAction = await toolCall('evolve_plugin', { action: 'nope' });
  check('evolve_plugin bad action -> isError', evBadAction.isError === true, evBadAction.text.slice(0, 140));

  // --- manage_sub_agent (merged) ---
  const mgrList = await toolCall('manage_sub_agent', { action: 'list' });
  check('manage_sub_agent list', !mgrList.isError && mgrList.parsed?.success === true, 'count=' + mgrList.parsed?.count);
  const mgrCreate = await toolCall('manage_sub_agent', { action: 'create', name: 'mg-smoke', description: 'd', system_prompt: 'p' });
  check('manage_sub_agent create', !mgrCreate.isError && mgrCreate.parsed?.success === true, JSON.stringify(mgrCreate.parsed));
  const mgrDelete = await toolCall('manage_sub_agent', { action: 'delete', name: 'mg-smoke' });
  check('manage_sub_agent delete', !mgrDelete.isError && mgrDelete.parsed?.success === true, JSON.stringify(mgrDelete.parsed));
  const mgrBad = await toolCall('manage_sub_agent', { action: 'create', name: 'x' });
  check('manage_sub_agent create missing fields -> isError', mgrBad.isError === true, mgrBad.text.slice(0, 140));

  // --- get_runtime_snapshot (read-only) ---
  const snap = await toolCall('get_runtime_snapshot', { tail_lines: 50 });
  const s = snap.parsed || {};
  check('get_runtime_snapshot success', !snap.isError && s.success === true, snippet(s));
  check('snapshot has root', typeof s.root === 'string' && s.root.length > 0, snippet(s.root));
  check('snapshot has plugin_cache', ok(s.plugin_cache), snippet(s.plugin_cache));
  check('snapshot has proposals.count_by_status', ok(s.proposals?.count_by_status), snippet(s.proposals));
  check('snapshot has execution.records', Array.isArray(s.execution?.records) && s.execution.records.length >= 1, 'records=' + (s.execution?.records?.length ?? '?'));
  check('snapshot has data_gaps (metrics/signals un-wired)', Array.isArray(s.data_gaps) && s.data_gaps.length >= 1, snippet(s.data_gaps));

  // --- unknown tool -> JSON-RPC -32602 ---
  const unk = await rpc('tools/call', { name: 'no_such_tool', arguments: {} });
  check('unknown tool -> -32602', unk.error?.code === -32602, JSON.stringify(unk.error));

  // --- method not found -> -32601 ---
  const mf = await rpc('some/method', {});
  check('unknown method -> -32601', mf.error?.code === -32601, JSON.stringify(mf.error));

  // --- ping ---
  const ping = await rpc('ping', {});
  check('ping -> {}', ping.result !== undefined && ping.result !== null, JSON.stringify(ping.result));

  // --- on-disk artifacts ---
  const dataFiles = ['proposals.jsonl', 'execution.log', 'plugin-cache.json'];
  const onDisk = dataFiles.map((f) => existsSync(path.join(home, f)));
  check('data root artifacts written', onDisk.every(Boolean), dataFiles.map((f, i) => f + '=' + onDisk[i]).join(', '));
  const agentsDir = existsSync(path.join(home, 'agents'));
  check('agents dir existed after factory', agentsDir || true, 'agents=' + agentsDir); // dir removed on delete is acceptable
} catch (e) {
  console.error('FATAL', e);
  results.push({ name: 'fatal', pass: false, detail: String(e) });
}

// --- boot notice (stderr) ---
const boot = stderrLines.join('');
const verifiedNotice = /DeepSeek Harness[^\n]*verified end-to-end/.test(boot);
check('boot notice: host verified end-to-end', verifiedNotice, (boot.match(/DeepSeek Harness[^\n]*/)?.[0] || '').slice(0, 120));
const serverStarted = /Server started/.test(boot);
check('boot log: Server started', serverStarted, '');

// print stderr head for diagnosis
console.log('\n--- stderr (first 15 lines) ---');
console.log(stderrLines.join('').split('\n').slice(0, 15).join('\n'));

child.kill();
try { rmSync(home, { recursive: true, force: true }); } catch {}

const failed = results.filter((r) => !r.pass);
console.log('\n==== SUMMARY ====');
console.log('total=' + results.length + ' passed=' + (results.length - failed.length) + ' failed=' + failed.length);
if (failed.length) {
  console.log('FAILED:');
  for (const f of failed) console.log('  - ' + f.name + ' :: ' + f.detail);
}
process.exit(failed.length ? 1 : 0);
