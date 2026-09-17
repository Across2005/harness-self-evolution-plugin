# ROADMAP — harness-self-evolution-plugin

> v2.6.0 已于 2026-09-17 发布（性能优化与缺陷修复：C1 定向重扫 + S1–S6 整改，测试 420→424；同批发布 mooncakes 0.2.6）。
> v2.5.0 已于 2026-09-16 发布（工程质量版本：全仓评审修复 56 个问题、测试 383→420）。

## v2.7（进行中：运行时可视化 + 清单迁移）

**主线一：运行时内容可视化**（计划见 `fluid-horizon-wagtail`，浮窗载体 = DSH Web）

| 切片 | 内容 | 状态 |
|------|------|------|
| 数据面 A | `get_runtime_snapshot` 第 14 个 MCP 工具：四段快照 + `data_gaps` 如实点名缺陷 9 | ✅ 落地，测试 424→432 |
| 数据面 B | `execution.jsonl` 同源双写（文本行一字不改）+ `read_tail` 优先镜像/回落 | ✅ 落地 |
| 呈现面 | `dsh-evolution-panel/` DSH Web 浮窗（管道总览 / DAG 实时时间线 / 指标卡） | ⏳ 阻塞：需 DSH `0.1.2-rc.1` 源码 checkout |
| 待决 | `.dsh-plugin/plugin.json` 是否列为 scanner 第 7 种清单形态（BUILD §5 偏差 10） | ⏳ 需决策 |

**主线二：`.dsh-plugin` 清单迁移**——自述清单改名（配置链保留旧路径兼容回退），文档同步进行中。

**v2.7.0 发版核对清单**（既有先例：五处解耦推进）：`moon.mod` 0.2.6→0.3.0、`package.json` 与 `.dsh-plugin/plugin.json` 2.6.0→2.7.0、`jsonrpc.mbt` server_version、`DESIGN.md` §4.1 镜像块、`skills/harness-evolution/SKILL.md` frontmatter；**`cordis.patch.yml` version 2.4.0 一并同步**（BUILD §5 偏差 1 在此销账）；README 徽章与工具表 424/13→432/14。

**候选（先 grill 对齐再立项）**：monitor 数据源接通（缺陷 9，依赖宿主回调）、M7 真实派发（`docs/subagent-factory.md` §4 设计就绪）。

## 已取消：跨平台分发（原 v2.6 / v2.7 预留目标）

> 2026-09-17 决策取消。本项目是 MoonBit 项目，能否编译取决于 MoonBit 工具链对目标系统的支持——工具链（moon 0.1.20260904）已支持 Windows / Linux / macOS，用户在目标平台上用源码包（GitHub / GitLink / mooncakes）自行构建即可，项目无需维护预编译三平台二进制。

原路线（不再执行）：GitHub Actions CI 构建矩阵 → v2.7.0 release 三平台二进制附件 → `install.sh` / `install.ps1` 安装脚本 → `dsh plugin` 免构建集成 → L4 沙盒验证。
