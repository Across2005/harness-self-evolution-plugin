///|
/// `ScanConfig::from_plugin_json`（2.2.0 接通 `scan_targets` 配置孤岛）的
/// 专项单元测试。
///
/// 全部用例都是**纯解析**：不触碰文件系统。`~` 展开的断言用
/// `@util.expand_home` 自身做对照（它的 env 解析语义已由
/// `util/path_test.mbt` 的 `"expand_home resolves ~ against HOME/USERPROFILE/cwd
/// in that order"` 单独钉住，这里不重复）。

///|
/// 构造一个只含 `scan_targets` 的最小 plugin.json。
/// 签名带 `raise`：`@json.parse` 是可抛错函数（同 `tools_wbtest.mbt` 的惯例）。
fn parse_targets(inline : String) -> (ScanConfig, Array[String]) raise {
  ScanConfig::from_plugin_json(@json.parse(inline), "/cache/plugin-cache.json")
}

///|
/// 缺失 `scan_targets` 段 → 默认根 + 无告警（「没配」是最常见的正常态）。
test "scan_targets absent falls back to default roots silently" {
  let raw =
    #|{"name":"harness-self-evolution","evolution_config":{"intensity":"50%"}}
  let (cfg, warns) = parse_targets(raw)
  assert_eq(warns.length(), 0)
  assert_eq(cfg.roots, default_scan_roots())
  // 缓存路径原样透传
  assert_eq(cfg.cache_path, "/cache/plugin-cache.json")
  // 深度走默认发现深度
  assert_eq(cfg.max_depth, max_discovery_depth)
}

///|
/// 非对象入参 → 默认根 + 无告警（与 from_json_checked 的「非对象整体回落」一致）。
test "scan_targets on a non-object json falls back silently" {
  let raw =
    #|"just a string"
  let (cfg, warns) = parse_targets(raw)
  assert_eq(warns.length(), 0)
  assert_eq(cfg.roots, default_scan_roots())
}

///|
/// `scan_targets` 不是数组 → 默认根 + 点名告警。
test "scan_targets of a wrong type warns and falls back" {
  let raw =
    #|{"scan_targets":"~/.zcode/skills"}
  let (cfg, warns) = parse_targets(raw)
  assert_eq(cfg.roots, default_scan_roots())
  assert_eq(warns.length(), 1)
  assert_true(warns[0].contains("scan_targets"))
  assert_true(warns[0].contains("fell back"))
}

///|
/// 正常数组 → 逐项 expand_home，替换默认根。
test "scan_targets replaces the default roots and expands home" {
  let raw =
    #|{"scan_targets":["~/skills-a","C:/abs/skills-b","~/skills-c"]}
  let (cfg, warns) = parse_targets(raw)
  assert_eq(warns.length(), 0)
  assert_eq(cfg.roots.length(), 3)
  assert_eq(cfg.roots[0], @util.expand_home("~/skills-a"))
  assert_eq(cfg.roots[1], "C:/abs/skills-b")
  assert_eq(cfg.roots[2], @util.expand_home("~/skills-c"))
  // 确实替换而非拼接：默认根不出现在结果里
  for r in default_scan_roots() {
    assert_false(cfg.roots.contains(r))
  }
}

///|
/// 混入非字符串元素 → 跳过该元素并按下标点名；其余字符串照常生效。
test "scan_targets skips non-string items with a named warning" {
  let raw =
    #|{"scan_targets":["~/ok-a",42,"~/ok-b",true]}
  let (cfg, warns) = parse_targets(raw)
  assert_eq(cfg.roots.length(), 2)
  assert_eq(cfg.roots[0], @util.expand_home("~/ok-a"))
  assert_eq(cfg.roots[1], @util.expand_home("~/ok-b"))
  assert_eq(warns.length(), 2)
  assert_true(warns[0].contains("scan_targets[1]"))
  assert_true(warns[1].contains("scan_targets[3]"))
}

///|
/// 空字符串元素 → 跳过并按下标点名。
test "scan_targets skips empty-string items with a named warning" {
  let raw =
    #|{"scan_targets":["~/ok",""]}
  let (cfg, warns) = parse_targets(raw)
  assert_eq(cfg.roots.length(), 1)
  assert_eq(cfg.roots[0], @util.expand_home("~/ok"))
  assert_eq(warns.length(), 1)
  assert_true(warns[0].contains("scan_targets[1]"))
}

///|
/// 显式空数组 → 默认根 + 告警（空列表等于关掉整个扫描，属退化取值）。
test "scan_targets empty array warns and falls back to defaults" {
  let raw =
    #|{"scan_targets":[]}
  let (cfg, warns) = parse_targets(raw)
  assert_eq(cfg.roots, default_scan_roots())
  assert_eq(warns.length(), 1)
  assert_true(warns[0].contains("no usable path"))
}

///|
/// 全部元素都被过滤掉 → 等同空数组：默认根 + 既有告警 + 回落告警。
test "scan_targets with only unusable items falls back and keeps item warnings" {
  let raw =
    #|{"scan_targets":[1,2,3]}
  let (cfg, warns) = parse_targets(raw)
  assert_eq(cfg.roots, default_scan_roots())
  // 3 条逐项告警 + 1 条回落告警
  assert_eq(warns.length(), 4)
  assert_true(warns[3].contains("no usable path"))
}
