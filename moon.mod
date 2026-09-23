name = "Across2005/harness-self-evolution"

// mooncakes 发布版本（0.x.y 线）：registry 当前硬性要求 major=0，
// 与产品版本解耦（产品版本见 README / plugin.json）。发布线先例：
// 0.1.0 ↔ 产品 v2.4.0，0.2.5 ↔ 产品 v2.5.0，0.2.6 ↔ 产品 v2.6.0。
// 本版 0.3.0 ↔ 产品 v2.7.0/v3.0.0（DSH-only 塌缩，已发布）；
// 0.3.1 ↔ 产品 v3.0.0 文档整理（去重/去冗余，行为不变，产物含清理后的文档）；
// 0.3.2 ↔ 产品 v3.1.0（启动路径可移植化：安装期注入 + 插件侧自解析，
//        扫描根随 dsh_home 派生，出厂清单去 scan_targets，cache_version 3→4）；
// 0.3.3 ↔ 产品 v3.1.0 仅更新 mooncakes 包简介（description），源码与行为不变。
version = "0.3.3"

readme = "README.md"

repository = "https://github.com/Across2005/harness-self-evolution-plugin"

license = "MIT"

keywords = [ "harness", "evolution", "self-improvement", "matt-pocock", "mcp" ]

// native 是唯一可行后端：moonbitlang/async 的 @fs/@stdio/@process/@signal
// 只在 native 后端有实现（其 internal/event_loop/moon.pkg 的 targets 表把
// fs.mbt/io.mbt 限定为 ["native","wasm"]、event_loop.mbt 限定为 ["native"]；
// js 后端只有 event_loop.js.mbt + timer.js.mbt + js_async 的 Promise 互操作）。

preferred_target = "native"

source = "src"

description = "面向 DeepSeek Harness（DSH）的全盘自进化 stdio MCP 插件（MoonBit 原生）：14 个工具完成 扫描→监控→提案→审批→执行 闭环，含子 Agent 工厂与只读运行时快照；人工审批闸门 + 确定性回滚。v3.0 起 DSH 单宿主，v3.1 启动路径可移植化。"

// 版本必须锁死在 0.20.1：0.21.x 起 async 使用 `noraise + nocancel` 效果标注语法，
// 撰写时（moon 0.1.20260819）无法解析（报 [3002] Parse error, unexpected token `+`）。
// 当前工具链 0.1.20260904（errdefer 已实测可用），async 0.21.x 未复测，维持锁定；
// 升级工具链并复测后方可放宽此约束。
import {
  "moonbitlang/async@0.20.1",
}
