# ROADMAP — harness-self-evolution-plugin

## 当前版本：v3.2.0

> v2.6.0 已于 2026-09-17 发布（性能优化与缺陷修复：C1 定向重扫 + S1–S6 整改，测试 420→424；同批发布 mooncakes 0.2.6）。
> v2.5.0 已于 2026-09-16 发布（工程质量版本：全仓评审修复 56 个问题、测试 383→420）。
>
> 远端与发布状态：v3.2.0 已发布到 GitHub、GitLink 与 mooncakes `0.3.5`；工具面 16 个、M7 真实派发与注入面已完成。

## v3.1（已完成：启动路径可移植化 A/B/C/E）

> 2026-09-20：兼容性实测暴露「出厂挂载行写死本机路径」——换机器/换树时 `command` 指向
> 不存在的文件，**该插件静默不挂载**（一行 warning，harness 照常启动）；且插件回落
> `~/.dsh`，user 作用域定义落进宿主不读的另一棵树。决策与证据见 `CONTEXT.md` § v3.1 决策记录。

| 切片 | 内容 | 状态 |
|---|---|---|
| A1 | 出厂挂载行改 **`disabled: true` + 零机器路径**（先例：`dsh-base` 的 `- id: hmr … disabled: true`） | ✅ |
| A2 | 新增 `scripts/install-dsh.ps1`：按目标树解析 `$DSH_HOME`，以 **id 定向覆盖行**注入 profile patch 层（标记块幂等；`-DryRun` / `-Uninstall` / `-SkipPluginAdd` / `-Verify`） | ✅ |
| A3 | `paths.mbt::dsh_home()` 新增**安装路径推导**档（`<X>/profiles/<name>/node_modules/…` → `X`，取自 `@env.current_dir()` / `@env.args()[0]`），优先级 `$DSH_HOME` > 推导 > `~/.dsh` | ✅ |
| A4 | `default_scan_roots()` 随 `dsh_home()` 派生（`@store.dsh_profiles_dir()`），与 user 作用域同源 | ✅ |
| B | 出厂 `.dsh-plugin/plugin.json` 删除 `scan_targets`（表达不了 `<DSH home>`，且旧值带多宿主时代的 `.agents/skills` / `.openclaw-autoclaw/skills`） | ✅ |
| C | `read_manifest_meta` 对非 JSON 清单（`SKILL.md`）短路，消掉每 skill 一条 `Cannot parse … SKILL.md` 噪声；判据 `manifest_is_json` 为纯函数 | ✅ |
| E | `cache_version` 3 → 4：清掉多宿主时代 + `target_paths` 临时扫描留下的陈旧档案 | ✅ |

**验证**：`moon check --deny-warn` 零错零警；`moon test` **443 → 453**（新增 10 条：安装路径推导 5 /
默认根派生 1 / 清单判定与回退 2 / G8 出厂清单无 `scan_targets` + G9 出厂行禁用且无机器路径 2）；
G5b 锚点同步；版本五处一并升 **3.1.0**（`moon.mod` 0.3.2）。
**未做**：缺陷 9 生态数据源、`dsh-watcher` 挂载（D/F 本轮不碰）。

## v3.2（2026-09-24：缺陷 9 注入面 + M7 真实派发 + 文档纠偏）

| 切片 | 内容 | 状态 |
|------|------|------|
| P0 | 提交安装器回归网与复验报告；DESIGN「启动时扫描」失实纠偏 | ✅ |
| P1 | 新增 `record_tool_call` / `record_user_feedback`（工具 14→16）；data_gaps/面板文案改为「注入面已暴露」 | ✅ |
| P2 | `process_task` / `real_validation` 真实实现（`@process.collect_output`）；生产装配注入；X9/X10 测试重写 | ✅ |
| P3 | 面板 `npm test` 验收；`miniapps/` 残留处置；版本 3.2.0 五处一致 | ✅ |

**验证**：`moon check --deny-warn` 零错零警；`moon test` **457/457**；`pwsh -File scripts/test-install-dsh.ps1` **7/7**；`dsh-evolution-panel` `npm test` **18/18**；`build.ps1 -Task all` EXIT=0。

## 2026-09-22 复验修复（v3.1.0 补丁线；**产品版本不升** —— 协议与工具面零变更）

> 2026-09-22：独立复验（`COMPATIBILITY_RECHECK_2026-09-22.md`）在**安装器**里发现一个
> 阻塞缺陷 —— 出厂空 patch 层（注释 + `[]`）上追加块序列项会写出非法 YAML，
> `parsePatchList` throw 让 **profile 完全无法 boot**，而触发条件正是新 profile 的默认状态。
> 同时更正两处文档失真（`failOnStartupError` 的致命性、`engines` 键名）。
> 决策与证据见 `CONTEXT.md` § 2026-09-22 复验决策记录。

| 切片 | 内容 | 状态 |
|---|---|---|
| F1 | `install-dsh.ps1` 修 flow 序列 `[]` 阻塞缺陷：先整行删 `[]` 再判定；加写前守卫；卸载补回 `[]` 使文件可逆 | ✅ |
| F2 | 新增回归网：`scripts/test-install-dsh.ps1`（7 场景，临时树跑真实脚本）+ `scripts/test-patch-layer.mjs`（用**宿主 js-yaml** 判合法） | ✅ |
| F3 | 改写 `failOnStartupError` 语义（6 处文档 + 1 处源码注释）：真实语义是「拒绝该插件激活 + 一行 warning」，**不**中止 harness；真正致命的是 patch 层解析失败 | ✅ |
| F4 | `engines` 键名统一为宿主权威键 `dsh`（两处清单一致）+ 文档标注「声明性、宿主不校验」+ 守卫 G10 | ✅ |
| F5 | 刷新出厂 `bin/harness-evolution.exe`（此前落后源码一个修订） | ✅ |
| F6 | `scripts/` 一次性探针脚本归档到 `scripts/_archive/` | ✅ |

**验证**：`moon check --deny-warn` 零错零警；`moon test` **453 → 454**（新增 G10：两处清单的
`engines` 键名统一为宿主的 `dsh`）；`pwsh -File scripts/test-install-dsh.ps1` **7/7 全绿**
（含出厂空模板这一历史触发态）。

## v2.7（进行中：运行时可视化 + 清单迁移）

> 2026-09-18：开发机完成**实机接入**——DSH web profile（宿主自己那棵 home）装入本插件 + 面板，
> 重启后 14 个 `mcp__harness-evolution__*` 工具在会话内可用。实践、判据与坑见
> `docs/dsh-compatibility.md` §5（多 home 现实 / 生效时机 / `.dsh-module-fallback`）。
>
> 2026-09-18：**撤销 ZCode 宿主支持与「多平台」承诺**，只保留两个已验证宿主
> （DeepSeek Harness + Minimax Code）。该变更并入 v2.7.0，发版核对清单相应多一项：
> `.dsh-plugin/plugin.json` 的 `engines` 去掉 `zcode`。详见文末「已取消」节。
>
> 2026-09-20：**砍掉 MiniMax Code 兼容、host 抽象塌缩为 DSH 单宿主（v3.0.0，破坏性）**。
> 移除 `HARNESS_EVOLUTION_HOST` / `host_agents_dir` / MiniMax 扫描根 / 两条宿主告警函数；
> 删 `docs/deploy/mavis.md`、`.minimax-plugin/` 清单、`specs/minimax-code-support.md`。
> 依据：DSH 0.1.6 源码中不存在「MiniMax Code 宿主」概念（仅将 MiniMax 当 LLM 供应商），
> 属过度声明。设计见 `docs/specs/2026-09-20-dsh-only-collapse-design.md`；`moon test` 446→443。

**主线一：运行时内容可视化**（计划见 `fluid-horizon-wagtail`，浮窗载体 = DSH Web）

| 切片 | 内容 | 状态 |
|------|------|------|
| 数据面 A | `get_runtime_snapshot` 第 14 个 MCP 工具：四段快照 + `data_gaps` 如实点名缺陷 9 | ✅ 落地，测试 424→432 |
| 数据面 B | `execution.jsonl` 同源双写（文本行一字不改）+ `read_tail` 优先镜像/回落 | ✅ 落地 |
| 呈现面 | `dsh-evolution-panel/` DSH Web 浮窗（管道总览 / DAG 实时时间线 / 指标卡） | 🔬 本机 GUI home 已挂载（boot 日志 `[dsh-evolution-panel] loaded`），待可视化验收 |
| 待决 | scanner 是否把 `.dsh-plugin/plugin.json` 列为清单形态（清单形态 6→4 后，此为 4→5；BUILD §5 偏差 10） | ⏳ 需决策 |

**主线二：`.dsh-plugin` 清单迁移**——自述清单改名已完成；配置链的旧路径（`.zcode-plugin/plugin.json`）
回退已随 ZCode 撤销一并**删除**（破坏性，迁移见 `BUILD.md` §2.3），文档同步已完成。

**v2.7.0 发版核对清单**（既有先例：五处解耦推进）：五处均已推进 —— `moon.mod` 0.2.6→**0.3.0**、`package.json` 与 `.dsh-plugin/plugin.json` 2.6.0→**2.7.0**、`src/mcp/jsonrpc.mbt` 的 `server_version`→**2.7.0**、`DESIGN.md` §4.1 镜像块→**2.7.0**、`skills/harness-evolution/SKILL.md` frontmatter→**2.7.0**；同批附带站点：`README.md` 版本行、`AGENTS.md` §版本信息、`docs/deploy/mavis.md` 清单镜像、`docs/deploy/deepseek-harness.md` 的冒烟期望输出（`serverInfo.version`）。~~`cordis.patch.yml` version 2.4.0 一并同步~~（已销账：改为挂载行方言，无 version 字段）；README 徽章与工具表 ~~424/13→432/14~~（已销账：README 重写后不再内嵌徽章/计数；现为 **443/14**（v3.0.0 删 3 条宿主用例））。

> **发版时另需一步，本轮刻意不做**：`BUILD.md` 与 `docs/deploy/deepseek-harness.md` 安装示例里的
> `#v2.6.0` 是**指向已发布产物**的 tag，不是工作树版本号。v2.7.0 未打 tag 前把它改成 `#v2.7.0`
> 会描述一个不存在的产物，故留到真正 push + tag 时一并改。

**v2.7.0 缺陷修复批次（2026-09-19）**：

| 项 | 内容 | 状态 |
|---|---|---|
| 缺陷 3a | ConfigWatcher **首轮必然误报**：`config_watcher_loop` 进 `while` 前未预置 mtime 基线，首轮 `(None, Some(_))` 恒真 → 每次启动都打一条假的 `Config file changed`。修复走**预置基线**（原语抽到 `store/config_watch.mbt`，main 包不可放测试），不把 `(None, Some(_))` 改成 `false`（那会吃掉「先删除再创建」场景）。新增 store 4 用例 + G7 源码守卫 | ✅ |
| 缺陷 3b | 旧 `proposals.jsonl` 行缺 `decay_factor` | ⛔ **刻意不回填**：容忍解码已闭合该缺陷、字段无消费方，且那 4 行是容忍解码的唯一真实样本 |
| 缺陷 3c | 双 profile 树 `$DSH_HOME` 路由收敛：`paths.mbt` 新增 `dsh_home()`（`$DSH_HOME` → `~/.dsh`，空/空白视为未设置，相对路径不采用），DSH 的 user 作用域随之落到宿主真正在读的那棵树；挂载行 `env` 显式转发（宿主 `scrubbedParentEnv` 丢弃全部 `DSH_*`，继承拿不到） | ✅ |
| 客户端产物契约 | `dsh-evolution-panel` client 入口加 `deps.onlyBundle`（防误内联）+ 新增产物契约测试（防漏内联）；两条修复方向互补，前者单独拦不住本次「zod 未内联」回归 | ✅ |

**候选（先 grill 对齐再立项）**：monitor 数据源接通（缺陷 9，依赖宿主回调）、M7 真实派发（`docs/subagent-factory.md` §4 设计就绪）。

## 已取消：ZCode 宿主支持（2026-09-18 决策）

> 撤销「ZCode 宿主」这一**声明式**承诺（从未真机验证），插件只保留两个**已端到端验证**的宿主：
> DeepSeek Harness（主宿主）与 Minimax Code。同步取消「多平台」表述——是双宿主，不是多平台。

删除分三层，不留半截状态：

1. **宿主支持**：`paths.mbt` 的 `host_agents_dir` / `host_verification_notice` 的 zcode 分支、
   `default_scan_roots()` 的两条 `~/.zcode/**`、`.dsh-plugin/plugin.json` 的 `engines.zcode`
   与两条 `~/.zcode/*` scan_target、工具描述里的 `~/.zcode/agents/`、`docs/deploy/zcode.md`、
   各处宿主矩阵与「声明待验证」表述。
2. **扫描清单形态**：不再把 `.zcode-plugin/plugin.json` / `.zcode-plugin-seed.json` 当插件清单
   （清单形态 6 → 4：`package.json` / `.claude-plugin/plugin.json` / `.mcp.json` / `SKILL.md`）。
3. **配置链回退**：不再读取旧布局 `<cwd>/.zcode-plugin/plugin.json`（**破坏性变更**）。

**迁移**：把 `.zcode-plugin/plugin.json` 改名为 `.dsh-plugin/plugin.json`（内容不变）；
此前依赖 ZCode 宿主目录落盘 user 作用域定义的用法，改用 `HARNESS_EVOLUTION_USER_DIR` 显式指定目录。

**验证**：`moon check --deny-warn` 零错零警；`moon test` **434/434**（撤销时只改断言与夹具、
未增删用例，G5b 锚点维持 434）；功能复验 `HARNESS_EVOLUTION_HOST=zcode` → 未识别告警 + 回落 DSH，
`Supported values: minimax-code, deepseek-harness`；新二进制已装入 `bin/`。

## 已取消：跨平台分发（原 v2.6 / v2.7 预留目标）

> 2026-09-17 决策取消。本项目是 MoonBit 项目，能否编译取决于 MoonBit 工具链对目标系统的支持——工具链（moon 0.1.20260904）已支持 Windows / Linux / macOS，用户在目标平台上用源码包（GitHub / GitLink / mooncakes）自行构建即可，项目无需维护预编译三平台二进制。

原路线（不再执行）：GitHub Actions CI 构建矩阵 → v2.7.0 release 三平台二进制附件 → `install.sh` / `install.ps1` 安装脚本 → `dsh plugin` 免构建集成 → L4 沙盒验证。
