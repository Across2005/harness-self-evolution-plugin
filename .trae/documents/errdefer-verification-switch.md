# errdefer 验证与切换计划

## 摘要

上一轮评审修复中，`rename_or_cleanup`（src/store/jsonl.mbt）原计划使用 MoonBit 的 `errdefer` 语法做错误路径清理，但当时工具链（moon 0.1.20260819）解析失败，改用「catch 只捕获 + 普通代码清理再重抛」的等价结构，并在注释与补充决策中记录了该限制。

**关键新事实**：本机工具链已升级为 `moon 0.1.20260904 (94521db 2026-09-04)`。errdefer 的可用性前提已变化，需在新工具链上重新实测。用户已选定方案：**验证后切换 errdefer（推荐）**——能编译就切换到官方推荐写法并补注释，不能就维持现状并修正过时注释表述。

## 现状分析

| 项 | 现状 | 证据 |
|----|------|------|
| 工具链 | moon 0.1.20260904（上一轮实测 errdefer 失败时是 0.1.20260819） | `moon version` 实测 |
| Feature flags | `rr_moon_mod,rr_moon_pkg`，与 errdefer 无关（moon.mod/moon.pkg 解析开关） | `moon version` 输出 |
| 目标函数 | `rename_or_cleanup`，catch+清理+重抛结构 | [jsonl.mbt:370-381](../../src/store/jsonl.mbt) |
| 过时注释① | L367-369：「本工具链（moon 0.1.20260819）尚无 errdefer 语法」——版本号已过时 | [jsonl.mbt:367-369](../../src/store/jsonl.mbt) |
| 过时注释② | moon.mod L25-26 引用旧版本号 0.1.20260819（关于 async 锁定，与 errdefer 无关但同源过时） | [moon.mod:25-26](../../moon.mod) |
| 影响面 | 全仓 grep 确认仅此一处涉及 errdefer；try? 无使用点 | grep 实测 |

## 变更方案

### 步骤 1：最小实验（决定走哪个分支）

直接把 `rename_or_cleanup` 改为 errdefer 写法（改动本身就是最小实验，无需 scratch 文件）：

```moonbit
async fn rename_or_cleanup(tmp : String, target : String) -> Unit {
  errdefer @fs.remove(tmp) catch { _ => () }
  @fs.rename(tmp, target)
}
```

运行 `moon check`（先单包 `src/store`，失败信息更聚焦）：

- **通过** → 进入步骤 2（正式切换）
- **Parse error** → 尝试块形式 `errdefer { @fs.remove(tmp) catch { _ => () } }`；仍失败 → `git checkout` 回滚该单文件，进入步骤 3

### 步骤 2：正式切换（errdefer 可用分支）

1. **jsonl.mbt**：应用上述改写（含块形式备选）
2. **更新注释 L359-369**：改述为「moon 0.1.20260904 实测支持 errdefer（2026-09-15），错误路径清理改用官方推荐的 errdefer 写法；errdefer 仅在带错退出时执行，成功路径不触发，语义与原结构等价」
3. **moon.mod L25-26 注释**：版本号表述修正为「撰写时（moon 0.1.20260819）无法解析；当前工具链 0.1.20260904，async 0.21.x 未复测，维持锁定」

### 步骤 3：维持现状分支（errdefer 仍不可用）

1. **回滚** jsonl.mbt 的实验性改动（`git checkout -- src/store/jsonl.mbt`）
2. **更新注释 L367-369**：版本号改为 0.1.20260904 并注明实测日期（2026-09-15），表述从「本工具链」改为「实测 moon 0.1.20260904 仍无 errdefer」
3. **moon.mod L25-26 注释**：同步骤 2 第 3 点的版本号修正

### 明确不做（范围外）

- **不升级 moonbitlang/async 依赖**：0.21.x 的 `noraise + nocancel` 语法在新工具链上未复测，属独立决策，需另行验证
- **不新增测试**：这是行为零变化的语法重构，420 个现有测试已守护行为
- **不动其他文件**：全仓仅此一处涉及 errdefer

## 验证（切换后或维持现状后重跑）

| 级别 | 命令 | 判定标准 |
|------|------|---------|
| T0 | `moon check --deny-warn` | 0 错 0 警 |
| T1 | `moon test` | 420/420 全绿（基线 420，本任务不新增用例） |
| T2 | `moon build` | exit 0，架构守卫 G1-G5b 通过 |

任一级失败立即停止并报告，不顺手修复。

## 假设与决策

- **决策**：用户已选定「验证后切换 errdefer（推荐）」
- **假设**：工具链升级未影响 async 0.20.1 兼容性（T0-T2 将验证此假设）
- **回滚**：单文件 `git checkout`，零风险；moon.mod 仅注释行变更，不影响依赖解析
- **async 0.21.x 解析探测**：明确排除在本次范围外，如需可后续单独立项（改 moon.mod → moon check → 回滚的廉价探测，约 2 分钟）
