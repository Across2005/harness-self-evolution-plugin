# 设计规格：砍掉 MiniMax Code 兼容，塌缩为 DSH-only（v3.0.0）

> 状态：待用户评审。基线 `main @ 9e62c1e`（v2.7.0 未提交批次之上）。
> 触发：交接 §3.1 的 Standards 发现 + 用户决定撤销「多宿主」这一过度声明。

## 0. 背景与实证依据

本插件历史上声称同时支持两个宿主：DeepSeek Harness（DSH）与 MiniMax Code，用
`HARNESS_EVOLUTION_HOST` 选择、`host_agents_dir(host)` 分发、启动序列点名验证状态。

对照 **DSH 0.1.6-alpha.1 真实源码**（`dsh-runtime-0.1.6-alpha.1.zip`）取证：

- `@deepseek-ai/dsh-home-paths::resolveDshHome`（index.js:73-76）是**单根**模型
  `explicit ?? ($DSH_HOME 非空 ?? ~/.dsh)`，**不存在 host / MiniMax 概念**。
- 全部 240 个 `@deepseek-ai/*` 包中，`minimax` 仅出现在
  `dsh-client-ui-settings-models` 里作为 **LLM 模型供应商** `minimax-cn`
  （`MINIMAX_CN_API_KEY`），与"把 MiniMax Code 当作加载本插件的宿主"无关。

结论：`minimax-code` 宿主分支、`~/.minimax/agents/`、扫描根
`~/.minimax/plugins|extensions`、`HARNESS_EVOLUTION_HOST=minimax-code` 全为本插件
单方面声明，DSH 源码不参与、无法佐证。移除它不触碰任何 DSH 真实契约。

### frontmatter 契约（本轮顺带核验，结论：已兼容，不改代码）

- `factory::render` 仅输出 `name/description/color/tools`，**不含任何 invocation 键**
  → 不触发 DSH `parseInvocationPolicy` 对 legacy camelCase 键
  （`modelInvocable`/`userInvocable`/`disableModelInvocation`）的抛错忽略路径。
- `factory::validate_name`（白名单 `a-z0-9-`、不以 `-` 首尾、无 `--`、长 1..64）
  **等价于** DSH `SKILL_NAME = /^[a-z0-9]+(?:-[a-z0-9]+)*$/`。凡被本插件接受的名字，
  DSH 一定能发现。
- 落地：**不改动 render/validate**，仅新增一条回归测试钉死
  「`validate_name` 接受集 ⟺ DSH isSkillName 语义」，防止将来放宽字符集导致定义静默失效。
  （若 `factory_wbtest` 已有等价逐字符用例则跳过，避免重复。）

## 1. 目标与非目标

**目标**
- 删除 MiniMax Code 兼容的一切声明与代码分支。
- 把 host 抽象塌缩为 DSH 单一宿主（移除多宿主脚手架本身）。
- 保留 `dsh_home()`/`dsh_agents_dir()`/`is_absolute_path()`（DSH home 路由收敛成果）。
- 版本升到 **3.0.0**（破坏性：移除已文档化的 `HARNESS_EVOLUTION_HOST` 契约与多宿主能力）。

**非目标（本轮不做，另立提案）**
- 不引入 DSH 的第二个 user skill 根 `~/.agents/skills`（`agentsHome`/`$DSH_AGENTS_HOME`，
  rank 500）—— 记为后续项。
- 不重写 `dsh_home()` 的空白处理逻辑；仅把上一轮 #4 那句**不准确**的
  「对齐宿主 resolveDshHome」注释改诚实（见 §4.6）。

## 2. 架构决策

- **D1 彻底塌缩 host 维度**：移除 `host_agents_dir`、`unknown_host_warning`、
  `host_verification_notice` 与全部 `HARNESS_EVOLUTION_HOST` 读取。单宿主下 host 选择器
  是浅抽象，违背 Deep Module 原则，删。
- **D2 保留 `HARNESS_EVOLUTION_USER_DIR` 显式覆盖**：它是测试注入与高级用户覆盖的入口，
  与多宿主无关，保留为 `user_agents_dir()` 的最高优先级臂。
- **D3 扫描根去 minimax、留 `~/.agents/plugins`**：后者是 speculative 通用约定，非 MiniMax
  声明，保留（4→2 根）。
- **D4 MiniMax 发行物一并删**：`docs/deploy/mavis.md`（MiniMax 部署整篇）与
  `miniapps/harness-evolution-panel/.minimax-plugin/`（MiniMax 打包清单）删除。

## 3. 组件与接口变化

- `store/paths.mbt`
  - 删：`host_agents_dir`、`unknown_host_warning`、`host_verification_notice`。
  - 改：`user_agents_dir()` → `HARNESS_EVOLUTION_USER_DIR` 覆盖（`expand_home`）
    否则 `dsh_agents_dir()`。塌缩后**消除**原 `host_agents_dir("deepseek-harness")`
    派生的嵌套兜底（连同 §3.1 的 #3 不可达 `~/.dsh/skills/` 臂一并消失）。
  - 保持公开签名：`user_agents_dir()` 仍 `pub fn -> String`，调用方无感。
- `scanner/scanner.mbt`：`default_scan_roots() -> [~/.dsh/profiles/, ~/.agents/plugins]`。
- `mcp/tools.mbt` / `mcp/schema.mbt`：工具/属性描述删去「Minimax Code 为 ~/.minimax/agents/」子句。
- `harness_evolution/main.mbt`：删启动序列两处 `match @store.unknown_host_warning()`
  与 `match @store.host_verification_notice()`（现 main.mbt:181-195）。
- `factory/factory.mbt`：**无代码改动**；新增等价回归测试。

## 4. 改动清单（单一事实来源：逐文件）

### 4.1 源码（可执行）
- `src/store/paths.mbt`：删 3 函数 + `HARNESS_EVOLUTION_HOST` 读取；重写 `user_agents_dir`；
  清理 L22、L120-145、L216-226、L253-321 的宿主/minimax 叙述注释。
- `src/scanner/scanner.mbt`：L44-76 去两条 minimax 根 + 注释 L21/L48-53。
- `src/mcp/tools.mbt`：L347/353/359 三条 description。
- `src/mcp/schema.mbt`：L274/307 两条 description。
- `src/harness_evolution/main.mbt`：L181-195 删两处启动点名。

### 4.2 自述清单与打包物
- `.dsh-plugin/plugin.json`：`version` 2.7.0→**3.0.0**；删 `engines.minimax-code`；
  从 `scan_targets` 删 `~/.minimax/plugins/`、`~/.minimax/extensions/`（留
  `~/.dsh/profiles/`、`~/.agents/skills/`、`~/.openclaw-autoclaw/skills/`）。
- 删除 `miniapps/harness-evolution-panel/.minimax-plugin/`（整目录）。

### 4.3 文档
- 删除 `docs/deploy/mavis.md`，清理所有指向它的链接（README/DEPLOY/DSH_* 等）。
- 去宿主开关与 minimax 目录表述：`docs/dsh-compatibility.md`、`docs/code-architecture.md`、
  `docs/deploy/deepseek-harness.md`、`ROADMAP.md`、`BUILD.md`、`SKILL.md`、
  `skills/harness-evolution/SKILL.md`、`CONTEXT.md`、`DESIGN.md`、`AGENTS.md`、
  `README.md`、`DSH_INTEGRATION.md`。
- `code-architecture.md` § Adding a new host：改写为「本插件仅支持 DSH 单一宿主」，
  移除多宿主扩展指引。
- 版本镜像行（package.json、jsonrpc `server_version`、DESIGN §4.1、AGENTS 版本块、
  README、SKILL frontmatter、deploy 冒烟期望）统一 2.7.0→**3.0.0**。

### 4.4 测试
- `src/store/store_wbtest.mbt`：删 `does not hijack the minimax-code host`、
  `host verification notice reflects the current verification matrix`、
  `unknown host yields a startup warning ...` 及一切引用被删函数/环境变量的用例。
- `src/scanner/scanner_wbtest.mbt`：若有 `default_scan_roots().length()` 断言 4→2。
- `src/factory/factory_wbtest.mbt`：新增 name-charset ≡ DSH isSkillName 用例（若无等价物）。

### 4.5 G5b 硬编码测试数锚点（已知坑，必须同步）
- `src/mcp/architecture_test.mbt`：删/增用例后**重算总数**，更新 `assert_eq(...length(), 446)`
  与相邻注释；否则 T2 架构守卫失败。

### 4.6 附带诚实性修正
- `src/store/paths.mbt::dsh_home` 上一轮 #4 的注释「偏离宿主…对齐 resolveDshHome」
  改准确：宿主对使用值**不裁剪**（仅对空判 trim），本插件刻意 trim 并把带首尾空白的值
  判为回落 —— 是**有意的更安全偏离**，据实描述。

## 5. 不变量核对（AGENTS.md / CONTEXT.md）
- **一个字符串枚举只有一张 wire 表**：`HARNESS_EVOLUTION_HOST` 取值为裸字符串、非 wire 枚举，
  删除不影响 `agent_scope_wire`；实现前二次确认无 host wire 表。
- **默认数据目录只有一处定义**：`dsh_home()` 仍是唯一收口点。
- **JSONL I/O 只在 store/**、**包依赖严格分层**：本次不新增跨层边；factory 仍依赖 store/types/util，
  被 mcp 依赖（G1 不变）。

## 6. 回滚与兼容影响
- 破坏性：任何仍设 `HARNESS_EVOLUTION_HOST=minimax-code` 的宿主（历史 launch shim）在 3.0.0 下
  会**忽略该变量**并走 DSH 目录。需在 CHANGELOG/ROADMAP 显式声明。
- 原版本经 v2.6.0-held 机制保留可回退。

## 7. 验证计划（三级，按交接 §4）
- **T0** `.\build.ps1 -Task check`（`moon check --deny-warn --target native`）零警。
- **T1** `.\build.ps1 -Task test`（`moon test --target native`）全绿，且数量与新锚点一致；
  frontmatter 等价用例、塌缩后 `user_agents_dir` 回落用例通过。
- **T2** `.\build.ps1 -Task build` 出 release exe + `dsh-evolution-panel` `npm run build`/`npm test`
  （删 `.minimax-plugin` 不得弄断 `client-bundle-contract`/`client-mount`）+
  协议冒烟 `evo-t2-smoke2.ps1` 版本回显 3.0.0、stdout 零非 JSON、user-scope 落 `<DSH_HOME>/skills`。
- 全仓 `git grep -i minimax`（排除节点模块/锁）应**仅剩** LLM 供应商无关命中或为零。

## 8. 待办（本 spec 之外）
- B#1：把 DSH 第二 user skill 根 `~/.agents/skills`（`agentsHome`/`$DSH_AGENTS_HOME`）纳入模型。
- 是否把 evolution panel 以 DSH 打包（而非已删的 MiniMax 打包）加载，续 §3.3 遗留。
