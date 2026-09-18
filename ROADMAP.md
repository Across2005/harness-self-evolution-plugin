# ROADMAP — harness-self-evolution-plugin

> v2.6.0 已于 2026-09-17 发布（性能优化与缺陷修复：C1 定向重扫 + S1–S6 整改，测试 420→424；同批发布 mooncakes 0.2.6）。
> v2.5.0 已于 2026-09-16 发布（工程质量版本：全仓评审修复 56 个问题、测试 383→420）。

## v2.7（进行中：运行时可视化 + 清单迁移）

> 2026-09-18：开发机完成**实机接入**——DSH web profile（宿主自己那棵 home）装入本插件 + 面板，
> 重启后 14 个 `mcp__harness-evolution__*` 工具在会话内可用。实践、判据与坑见
> `docs/dsh-compatibility.md` §5（多 home 现实 / 生效时机 / `.dsh-module-fallback`）。
>
> 2026-09-18：**撤销 ZCode 宿主支持与「多平台」承诺**，只保留两个已验证宿主
> （DeepSeek Harness + Minimax Code）。该变更并入 v2.7.0，发版核对清单相应多一项：
> `.dsh-plugin/plugin.json` 的 `engines` 去掉 `zcode`。详见文末「已取消」节。

**主线一：运行时内容可视化**（计划见 `fluid-horizon-wagtail`，浮窗载体 = DSH Web）

| 切片 | 内容 | 状态 |
|------|------|------|
| 数据面 A | `get_runtime_snapshot` 第 14 个 MCP 工具：四段快照 + `data_gaps` 如实点名缺陷 9 | ✅ 落地，测试 424→432 |
| 数据面 B | `execution.jsonl` 同源双写（文本行一字不改）+ `read_tail` 优先镜像/回落 | ✅ 落地 |
| 呈现面 | `dsh-evolution-panel/` DSH Web 浮窗（管道总览 / DAG 实时时间线 / 指标卡） | 🔬 本机 GUI home 已挂载（boot 日志 `[dsh-evolution-panel] loaded`），待可视化验收 |
| 待决 | scanner 是否把 `.dsh-plugin/plugin.json` 列为清单形态（清单形态 6→4 后，此为 4→5；BUILD §5 偏差 10） | ⏳ 需决策 |

**主线二：`.dsh-plugin` 清单迁移**——自述清单改名已完成；配置链的旧路径（`.zcode-plugin/plugin.json`）
回退已随 ZCode 撤销一并**删除**（破坏性，迁移见 `BUILD.md` §2.3），文档同步已完成。

**v2.7.0 发版核对清单**（既有先例：五处解耦推进）：`moon.mod` 0.2.6→0.3.0、`package.json` 与 `.dsh-plugin/plugin.json` 2.6.0→2.7.0、`jsonrpc.mbt` server_version、`DESIGN.md` §4.1 镜像块、`skills/harness-evolution/SKILL.md` frontmatter；~~`cordis.patch.yml` version 2.4.0 一并同步~~（已销账：改为挂载行方言，无 version 字段）；README 徽章与工具表 ~~424/13→432/14~~（已销账：README 重写后不再内嵌徽章/计数；现为 434/14）。

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
