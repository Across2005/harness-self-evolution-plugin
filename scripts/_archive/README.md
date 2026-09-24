# `scripts/_archive/` — 一次性兼容性探针（保留作历史证据）

本目录是**归档**，不是工具目录。这里的东西**不要**在日常开发或安装流程里调用。

## 为什么归档而不是删除

这些文件是历次 DSH 兼容性测试（2026-09-17 起）的临时物，它们的价值不在「能跑」，
而在**记录了当时是怎么验的**——「崩溃栈 → 宿主源码 → 逐行确认」那条链路的现场。
删掉会让后续维护者重新踩一遍同样的坑；留在 `scripts/` 根下又会和正式脚本混在一起，
干扰阅读（2026-09-22 复验报告 §4.5 指出的仓库卫生问题）。

所以：**移进这里，保留原文，明确标注「非工具」。**

## 内容

| 文件 | 当时用途 |
|---|---|
| `_dsh_overlay_mcp.yml` | 用 `--patch` overlay 挂载 mcp-client 行的最小样例（证明 patch 方言正确） |
| `_dsh_web_full_overlay.yml` | web profile 的完整 overlay（合并 skill-filesystem + mcp 两件事） |
| `_enable_skill_fs_overlay.yml` | 单独启用 `skill-filesystem` 的 overlay（诊断「底部一直重新连接中」） |
| `_dsh_compat_probe.mjs` | 早期 MCP 直连探针（`tools/list` 计数与工具名比对） |
| `_e2e_mcp_full.mjs` | 端到端 MCP 全链路探针（20 KB，逐工具调用） |
| `_run_real.mjs` | 真实宿主环境下的调用脚本 |
| `_miniapp_*.{mjs,ps1}` | MiniMax Code 时代的小程序探针（v3.0.0 已砍除该宿主，纯历史） |
| `_notice_probe.ps1` | 启动告警文案探针（验证 `verification notice` 的输出） |
| `_miniapp_stderr.log` | 上述探针留下的 stderr 片段 |

## 现在的正式工具在哪

| 需要做的事 | 用这个 |
|---|---|
| 把插件装进某棵 DSH 树（注入挂载行） | `scripts/install-dsh.ps1` |
| **改安装器后必须跑**的回归套件 | `scripts/test-install-dsh.ps1`（+ `scripts/test-patch-layer.mjs`） |
| fork/CI 里改仓库路径字面量 | `scripts/replace-paths.ps1` |
| 零污染实验（overlay 挂载） | 见 `docs/deploy/deepseek-harness.md` § Install: the `--patch` overlay path（模板已内联在文档里，不需要本目录的文件） |

## 维护约定

- **新增**探针：请带日期前缀（如 `_2026-09-22_<what>.ps1`）直接放进本目录，
  不要放回 `scripts/` 根下。
- **不要**让任何正式脚本 import / 点源 / 调用本目录的文件。
- 本目录**不**参与 `package.json` 的 `files`（发布产物不含它）。
