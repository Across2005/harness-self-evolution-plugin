name = "across2005/harness-self-evolution"

version = "2.0.0"

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

description = "DeepSeek Harness 全盘自进化升级插件（MoonBit native）"

// 版本必须锁死在 0.20.1：0.21.x 起 async 使用 `noraise + nocancel` 效果标注语法，
// 本机 moon 0.1.20260819 无法解析（报 [3002] Parse error, unexpected token `+`）。
// 升级工具链后方可放宽此约束。
import {
  "moonbitlang/async@0.20.1",
}
