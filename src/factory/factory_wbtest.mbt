///|
/// factory 包的行为测试。全部经 `AgentFactory::with_dirs` 把两个作用域
/// 指向 `@fs.tmpdir`，**绝不触碰真实的 `~/.zcode/agents`** ——
/// user 作用域的磁盘后果在这里是可回收的临时目录。

// ============================================================================
// 校验规则：正反用例
// ============================================================================

///|
/// 造一个默认合法的定义，单个字段可覆盖 —— 各校验规则的正反用例都从它出发，
/// 保证失败只来自被测的那个字段。
fn make_def(
  name? : String = "code-generator",
  description? : String = "按提案实现代码",
  system_prompt? : String = "You are a code generator.",
  tools? : Array[String] = ["Read", "Write"],
  color? : String? = Some("blue"),
) -> AgentDefinition {
  { name, description, system_prompt, tools, color }
}

///|
test "a well-formed definition passes validation" {
  // 全字段指定
  make_def().validate()
  // 可选字段全缺席
  make_def(tools=[], color=None).validate()
}

///|
test "name validation enforces kebab-case in 1..64 characters" {
  // 正：小写字母 / 数字 / 连字符的合法组合
  make_def(name="a").validate()
  make_def(name="code-generator-2").validate()
  make_def(name="0-0").validate()
  // 反：空 / 超长 / 非法字符 / 连字符位置 / 连续连字符
  for
    bad in [
      "", // 空
      "a".repeat(65), // 65 字符
      "Code-Generator", // 大写
      "code generator", // 空白
      "代码生成", // 非 ASCII
      "-lead", // 以 - 开头
      "trail-", // 以 - 结尾
      "dou--ble", // 连续 --
    ] {
    let msg = try {
      make_def(name=bad).validate()
      ""
    } catch {
      e => e.to_string()
    }
    assert_true(
      msg.contains("invalid sub-agent name"),
      msg="expected name rule failure for \"\{bad}\", got: \{msg}",
    )
  }
  // 恰好 64 字符是合法的
  make_def(name="a".repeat(64)).validate()
}

///|
test "description validation requires a single line in 1..1024 characters" {
  make_def(description="一句话职责").validate()
  for
    bad in [
      "", // 空
      "d".repeat(1025), // 1025 字符
      "line1\nline2", // \n
      "line1\r\nline2", // \r\n
    ] {
    let msg = try {
      make_def(description=bad).validate()
      ""
    } catch {
      e => e.to_string()
    }
    assert_true(
      msg.contains("invalid sub-agent description"),
      msg="expected description rule failure, got: \{msg}",
    )
  }
  make_def(description="d".repeat(1024)).validate()
}

///|
test "system_prompt validation requires 1..65536 characters" {
  make_def(system_prompt="你好").validate()
  for bad in ["", "x".repeat(65537)] {
    let msg = try {
      make_def(system_prompt=bad).validate()
      ""
    } catch {
      e => e.to_string()
    }
    assert_true(
      msg.contains("invalid sub-agent system_prompt"),
      msg="expected system_prompt rule failure, got: \{msg}",
    )
  }
  // 65536 恰好合法；system_prompt 允许换行
  make_def(system_prompt="x".repeat(65536)).validate()
  make_def(system_prompt="第一行\n第二行").validate()
}

///|
test "color validation allows only lowercase letters in 1..20" {
  make_def(color=None).validate()
  make_def(color=Some("blue")).validate()
  for bad in ["", "Blue", "blue1", "深蓝", "b".repeat(21)] {
    let msg = try {
      make_def(color=Some(bad)).validate()
      ""
    } catch {
      e => e.to_string()
    }
    assert_true(
      msg.contains("invalid sub-agent color"),
      msg="expected color rule failure for \"\{bad}\", got: \{msg}",
    )
  }
}

///|
test "tools validation rejects empty, oversized and shape-breaking entries" {
  make_def(tools=[]).validate()
  make_def(tools=["Read", "Write", "Edit", "Bash"]).validate()
  for
    bad in [
      [""], // 空项
      ["t".repeat(65)], // 65 字符
      ["Read,Write"], // 逗号破坏列表
      ["[Read]"], // 方括号破坏列表
      ["Read Write"], // 空白
      ["Read\tTab"], // 制表符
    ] {
    let msg = try {
      make_def(tools=bad).validate()
      ""
    } catch {
      e => e.to_string()
    }
    assert_true(
      msg.contains("invalid sub-agent tool name"),
      msg="expected tools rule failure, got: \{msg}",
    )
  }
}

// ============================================================================
// render / parse 往返
// ============================================================================

///|
/// 渲染形状逐字节钉死：frontmatter 键序、可选键缺席、正文与末尾换行。
test "render produces the exact frontmatter shape" {
  // 全字段
  inspect(
    render(make_def(system_prompt="提示词正文")),
    content=(
      #|---
      #|name: code-generator
      #|description: 按提案实现代码
      #|color: blue
      #|tools: [Read, Write]
      #|---
      #|
      #|提示词正文
      #|
    ),
  )
  // 可选键缺席：color 与 tools 都不渲染；tools 空数组 = 未指定
  inspect(
    render(make_def(tools=[], color=None, system_prompt="正文")),
    content=(
      #|---
      #|name: code-generator
      #|description: 按提案实现代码
      #|---
      #|
      #|正文
      #|
    ),
  )
}

///|
/// render → parse 必须是恒等往返 —— 这是「文件里写的就是结构化定义」
/// 的机器化表述，格式一旦漂移（比如键序、空行处理变了）这条先红。
test "render and parse round-trip losslessly" {
  let defs : Array[AgentDefinition] = [
    make_def(),
    make_def(tools=[], color=None),
    make_def(tools=["Read"], color=None),
    make_def(system_prompt="第一段\n\n第二段\n第三段"),
    make_def(name="validator", tools=["Read", "Bash"], color=Some("red")),
  ]
  for def in defs {
    assert_eq(parse(render(def)), Some(def))
  }
}

///|
test "parse accepts a YAML subset with unknown keys and CRLF tolerated" {
  // 未知键忽略；键值里的 ':' 不截断；注释与空行跳过
  let text =
    #|---
    #|name: judge
    #|model: some-model
    #|description: 视觉验收: 只判不改
    #|# a comment line
    #|tools: [Read, Bash]
    #|---
    #|
    #|正文第一行
    #|
  let parsed = parse(text)
  assert_eq(
    parsed,
    Some({
      name: "judge",
      description: "视觉验收: 只判不改",
      system_prompt: "正文第一行",
      tools: ["Read", "Bash"],
      color: None,
    }),
  )
  // CRLF 容忍
  assert_eq(
    parse("---\r\nname: a\r\ndescription: d\r\n---\r\n\r\nbody\r\n"),
    Some({
      name: "a",
      description: "d",
      system_prompt: "body",
      tools: [],
      color: None,
    }),
  )
  // tools 无空格分隔也接受；空列表 = 未指定
  assert_eq(
    parse("---\nname: a\ndescription: d\ntools: [Read,Bash]\n---\n\nbody\n"),
    Some({
      name: "a",
      description: "d",
      system_prompt: "body",
      tools: ["Read", "Bash"],
      color: None,
    }),
  )
  assert_eq(
    parse("---\nname: a\ndescription: d\ntools: []\n---\n\nbody\n"),
    Some({
      name: "a",
      description: "d",
      system_prompt: "body",
      tools: [],
      color: None,
    }),
  )
}

///|
test "parse strips paired quotes from frontmatter values" {
  // 真实世界的 agent 文件普遍给值加引号（实测 ~/.zcode/agents/coder.md
  // 写的是 `name: "coder"`），不剥引号会让 list 返回 "\"coder\"" 这种名字
  let parsed = parse(
    "---\nname: \"coder\"\ndescription: \"负责代码编辑和编后审查\"\ncolor: 'red'\ntools: [\"Read\", 'Bash']\n---\n\n正文\n",
  )
  assert_eq(
    parsed,
    Some({
      name: "coder",
      description: "负责代码编辑和编后审查",
      system_prompt: "正文",
      tools: ["Read", "Bash"],
      color: Some("red"),
    }),
  )
  // 只剥**成对**的引号：值内部或单侧的引号原样保留
  assert_eq(
    parse("---\nname: a\ndescription: say \"hi\" to: world\n---\n\nbody\n"),
    Some({
      name: "a",
      description: "say \"hi\" to: world",
      system_prompt: "body",
      tools: [],
      color: None,
    }),
  )
}

///|
test "parse returns None for non-definition content" {
  // 无围栏
  assert_true(parse("just some markdown\n") is None)
  // 只有开围栏
  assert_true(parse("---\nname: a\n") is None)
  // 缺 name
  assert_true(parse("---\ndescription: d\n---\n\nbody\n") is None)
  // 缺 description
  assert_true(parse("---\nname: a\n---\n\nbody\n") is None)
  // 空内容
  assert_true(parse("") is None)
}

// ============================================================================
// 全链路：create → list → delete（两个作用域）
// ============================================================================

///|
/// 全链路。plugin 与 user 两个作用域各来一遍；
/// list(None) 先 plugin 后 user（决策 D10）。
async test "create, list and delete work across both scopes" {
  let tmp_a = @fs.tmpdir(prefix="evo-factory-plugin-")
  defer @fs.rmdir(tmp_a, recursive=true)
  let tmp_b = @fs.tmpdir(prefix="evo-factory-user-")
  defer @fs.rmdir(tmp_b, recursive=true)
  let factory = AgentFactory::with_dirs("\{tmp_a}/agents", "\{tmp_b}/agents")

  // 两个作用域各创建一个
  let (plugin_path, created) = factory.create(
    make_def(name="code-generator"),
    @types.AgentScope::Plugin,
  )
  assert_false(created)
  assert_true(plugin_path.has_prefix(@util.path_normalize(tmp_a)))
  let (user_path, _) = factory.create(
    make_def(name="test-writer"),
    @types.AgentScope::User,
  )
  assert_true(user_path.has_prefix(@util.path_normalize(tmp_b)))
  assert_true(user_path.contains("/agents/test-writer.md"))

  // list(None)：两个作用域都列，先 plugin 后 user
  let all = factory.list(None)
  assert_eq(all.length(), 2)
  let (scope0, def0, path0) = all[0]
  assert_eq(scope0, @types.AgentScope::Plugin)
  assert_eq(def0.name, "code-generator")
  assert_eq(path0, plugin_path)
  let (scope1, def1, _) = all[1]
  assert_eq(scope1, @types.AgentScope::User)
  assert_eq(def1.name, "test-writer")

  // list(Some(scope)) 只列对应作用域
  assert_eq(factory.list(Some(@types.AgentScope::Plugin)).length(), 1)
  assert_eq(factory.list(Some(@types.AgentScope::User)).length(), 1)
  assert_eq(
    factory.list(Some(@types.AgentScope::User))[0].0,
    @types.AgentScope::User,
  )

  // 落盘内容确实是 frontmatter 格式
  let raw = @fs.read_file("\{tmp_a}/agents/code-generator.md").text()
  assert_true(raw.has_prefix("---\nname: code-generator\n"))

  // 删除：返回被删路径，且文件真的没了
  let deleted = factory.delete("code-generator", @types.AgentScope::Plugin)
  assert_eq(deleted, plugin_path)
  assert_eq(@fs.exists(plugin_path), false)
  assert_eq(factory.list(Some(@types.AgentScope::Plugin)).length(), 0)
  assert_eq(factory.list(None).length(), 1)
}

///|
/// 已存在且 overwrite=false → raise（消息含 already exists）；
/// overwrite=true → 覆盖且返回 overwritten=true。
async test "create refuses duplicates unless overwrite is explicit" {
  let tmp = @fs.tmpdir(prefix="evo-factory-dup-")
  defer @fs.rmdir(tmp, recursive=true)
  let factory = AgentFactory::with_dirs("\{tmp}/a", "\{tmp}/b")
  let (path, _) = factory.create(
    make_def(name="doc-writer", system_prompt="v1"),
    @types.AgentScope::Plugin,
  )
  let msg = try {
    let _ = factory.create(
      make_def(name="doc-writer", system_prompt="v2"),
      @types.AgentScope::Plugin,
    )
    ""
  } catch {
    e => e.to_string()
  }
  assert_true(msg.contains("already exists"))
  // 报错不产生副作用：旧内容原样保留
  let kept = factory.list(Some(@types.AgentScope::Plugin))
  assert_eq(kept.length(), 1)
  assert_eq(kept[0].1.system_prompt, "v1")
  // 显式 overwrite → 覆盖并报告
  let (path2, overwritten) = factory.create(
    make_def(name="doc-writer", system_prompt="v2"),
    @types.AgentScope::Plugin,
    overwrite=true,
  )
  assert_true(overwritten)
  assert_eq(path2, path)
  let updated = factory.list(Some(@types.AgentScope::Plugin))
  assert_eq(updated[0].1.system_prompt, "v2")
  // 覆盖路径同样适用于 user 作用域
  let _ = factory.create(
    make_def(name="doc-writer", system_prompt="u1"),
    @types.AgentScope::User,
  )
  let (_, overwritten_user) = factory.create(
    make_def(name="doc-writer", system_prompt="u2"),
    @types.AgentScope::User,
    overwrite=true,
  )
  assert_true(overwritten_user)
}

///|
/// 非法定义在触碰磁盘之前就被拒绝（先校验后写入）。
async test "create rejects an invalid definition without writing anything" {
  let tmp = @fs.tmpdir(prefix="evo-factory-bad-")
  defer @fs.rmdir(tmp, recursive=true)
  let factory = AgentFactory::with_dirs("\{tmp}/a", "\{tmp}/b")
  let msg = try {
    let _ = factory.create(make_def(name="Bad_Name"), @types.AgentScope::Plugin)
    ""
  } catch {
    e => e.to_string()
  }
  assert_true(msg.contains("invalid sub-agent name"))
  // 两个作用域都没有留下文件
  assert_eq(factory.list(None).length(), 0)
}

///|
/// 删除不存在的名字 → raise（区分「删错了名字」与「删除成功」）。
async test "delete raises for a missing definition" {
  let tmp = @fs.tmpdir(prefix="evo-factory-del-")
  defer @fs.rmdir(tmp, recursive=true)
  let factory = AgentFactory::with_dirs("\{tmp}/a", "\{tmp}/b")
  let msg = try {
    let _ = factory.delete("ghost", @types.AgentScope::Plugin)
    ""
  } catch {
    e => e.to_string()
  }
  assert_true(msg.contains("not found"))
}

///|
/// 手改坏的一个 .md 不能把其余定义全部遮住：
/// list 跳过解析失败的文件并告警，整体不失败。
async test "list skips unparseable files instead of failing" {
  let tmp = @fs.tmpdir(prefix="evo-factory-corrupt-")
  defer @fs.rmdir(tmp, recursive=true)
  let factory = AgentFactory::with_dirs("\{tmp}/a", "\{tmp}/b")
  let _ = factory.create(make_def(name="good-one"), @types.AgentScope::Plugin)
  // 直接往定义目录塞两类坏文件：无围栏的 .md、有围栏但缺 description 的 .md
  @fs.write_file(
    "\{tmp}/a/broken.md",
    "no frontmatter here",
    create_mode=CreateOrTruncate,
  )
  @fs.write_file(
    "\{tmp}/a/no-desc.md",
    "---\nname: no-desc\n---\n\nbody\n",
    create_mode=CreateOrTruncate,
  )
  // 顺带一个非 .md 文件，验证 list 的扩展名过滤
  @fs.write_file(
    "\{tmp}/a/README.txt",
    "not a definition",
    create_mode=CreateOrTruncate,
  )
  let listed = factory.list(Some(@types.AgentScope::Plugin))
  assert_eq(listed.length(), 1)
  assert_eq(listed[0].1.name, "good-one")
  // 非法 name 但带合法 frontmatter 的文件：parse 本身不校验 kebab-case，
  // 列表照常返回 —— 形状校验只发生在 create 的写入口（与设计一致）
}
