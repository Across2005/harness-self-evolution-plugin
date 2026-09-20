///|
/// 配置文件监听所需的最小原语：一次读盘 + 一个纯比较函数。
///
/// **为什么放在 store 而不是 harness_evolution/main.mbt**：
/// main 是 `pkgtype(kind: "executable")` 包，工具链明确警告 main 包不得放
/// `_test.mbt`（见 `src/harness_evolution/moon.pkg` 的注释）。缺陷 3a 的修复点
/// 在 watcher 的**首轮基线初始化**上，只有把它抽成可调用的原语，测试才能钉住
/// 「预置基线 → 首轮不误报」这条行为；留在 main 里则完全不可测。
///
/// 而 store 是本仓唯一被授权做文件系统 I/O 的包（架构不变量① / G3），
/// 读盘原语天然属于这里。
///
/// 拆分方式刻意保持**最小**：`config_mtime` 承担副作用，`config_changed`
/// 是零副作用的纯函数 —— 后者可以用字面量元组穷举全部四种组合，
/// 不必依赖真实文件系统的时间戳精度（那会引入 flaky）。

///|
/// 读取配置文件当前的修改时间。
///
/// 返回 `None` 覆盖两种情况：文件不存在，或文件存在但 `mtime` 读不到
/// （权限不足、竞态删除等）。对监听器而言这两者的语义相同 ——
/// 「这一轮看不见文件」。
///
/// 注意 `@fs.exists` / `@fs.mtime` 都是**读**操作，不在 G3 的写操作清单内；
/// 放在 store 是就着语义就近，并非越权豁免的需要。
pub async fn config_mtime(path : StringView) -> (Int64, Int)? {
  if @fs.exists(path) {
    Some(@fs.mtime(path)) catch {
      _ => None
    }
  } else {
    None
  }
}

///|
/// 纯函数：比较上一轮基线与本轮读数，判断配置是否发生变化。
///
/// 四种组合的语义：
/// - `(None, None)`：两轮都没有文件 → 无变化
/// - `(Some(_), None)`：文件被删除 → 变化
/// - `(None, Some(_))`：文件在监听期间被创建 → 变化
/// - `(Some(a), Some(b))`：秒或纳秒任一不同 → 变化
///
/// **`(None, Some(_)) => true` 必须保留**：它是「启动时不存在、之后才出现」
/// 的唯一检测通路。缺陷 3a 的修复**不能**靠把它改成 `false` 达成 ——
/// 那会吃掉真实的「先删除、再重新创建」场景。修复走的是**预置基线**
/// （见 `src/harness_evolution/main.mbt` 的 `config_watcher_loop`），
/// 让 `None` 只代表「启动时确实没有文件」，而不是「还没看过」。
pub fn config_changed(
  last : (Int64, Int)?,
  current : (Int64, Int)?,
) -> Bool {
  match (last, current) {
    (None, None) => false
    (Some(_), None) => true
    (None, Some(_)) => true
    (Some((old_sec, old_nsec)), Some((new_sec, new_nsec))) =>
      old_sec != new_sec || old_nsec != new_nsec
  }
}