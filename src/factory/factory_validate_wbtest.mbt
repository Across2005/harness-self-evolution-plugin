///|
/// X11/X12 的回归网：validate_description 收紧与 validate_template 复用规范校验。
///
/// 单独成文件的原因：factory_wbtest.mbt 归另一文件所有权，本文件只承载
/// 新增规则用例；make_def 复用 factory_wbtest.mbt 里的同名夹具
/// （白盒测试文件同包编译，失败只来自被测字段）。

///|
/// X11 回归网：render 对 description 原样拼接，以下值会产出宿主
/// 拒载/解析歧义的非法 YAML frontmatter，必须在 validate 入口被拒绝。
test "description validation rejects values that would break YAML frontmatter" {
  for
    bad in [
      "a: b", // 含 ": " → 宿主解析成第二个映射键
      "[tool]", // 以 YAML 指示符 [ 开头
      "{a: b}", // 以 { 开头
      "\"quoted", // 以 " 开头（未配对）
      "'single", // 以 ' 开头
      "*anchor", // 以 * 开头
      "&anchor", // 以 & 开头
      "!tag", // 以 ! 开头
      "|block", // 以 | 开头
      ">folded", // 以 > 开头
      "%directive", // 以 % 开头
      "@at", // 以 @ 开头
      "`tick", // 以 ` 开头
      "trailing\"", // 包裹引号不配对（只有尾引号）
      "trailing'", // 单引号不配对
    ] {
    let msg = try {
      make_def(description=bad).validate()
      ""
    } catch {
      e => e.to_string()
    }
    assert_true(
      msg.contains("invalid sub-agent description"),
      msg="expected YAML rule failure for \"\{bad}\", got: \{msg}",
    )
  }
  // 正例：冒号后无空格、非指示符开头、引号只出现在中间
  make_def(description="a:b").validate()
  make_def(description="say \"hi\" there").validate()
  make_def(description="一句话职责").validate()
}

///|
/// X12 回归网：validate_template 在 parse 成功后复用 AgentDefinition::validate
/// —— 旧实现只查长度，放行了 name 字符集非法（如 "Bad_Name"）的模板。
test "validate_template reuses the full definition validation" {
  // 合法模板通过
  match validate_template(render(make_def(name="code-generator"))) {
    Ok(_) => ()
    Err(msg) => abort("valid template rejected: \{msg}")
  }
  // name 字符集非法 —— 旧实现只查长度会放行，新实现必须拒绝
  let msg = match validate_template(render(make_def(name="Bad_Name"))) {
    Ok(_) => ""
    Err(m) => m
  }
  assert_true(
    msg.contains("invalid sub-agent name"),
    msg="expected name rule failure, got: \{msg}",
  )
  // 非 frontmatter 文本仍按解析失败处理
  match validate_template("just some markdown") {
    Err(_) => ()
    Ok(_) => abort("non-frontmatter content must not validate")
  }
}
