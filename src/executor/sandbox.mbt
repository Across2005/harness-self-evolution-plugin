// Copyright (c) 2026. All rights reserved.
// Licensed under the MIT License.
//
// sandbox.mbt — 安全沙箱的纯逻辑层。
//
// 所有文件 I/O 通过 @store.sandbox_* 函数执行（不变量①）。

/// 敏感数据模式类型。
pub(all) enum SensitivePatternKind {
  ApiKey
  Token
  Password
  PrivateKey
  EnvAssignment
  AuthHeader
} derive(Eq, Debug, ToJson)

/// 敏感数据命中记录。
pub(all) struct SensitiveHit {
  kind : SensitivePatternKind
  line : Int
  preview : String
} derive(ToJson)

/// 判断关键字后是否紧跟赋值/引号/冒号分隔符。
/// X5：分隔符集**不含空格与制表** —— 否则 "the token in the cache" 这类
/// 英文句子里的同形词会因后跟空格而误报。
fn is_assignment_context(line : String, keyword_pos : Int, keyword_len : Int) -> Bool {
  let after = keyword_pos + keyword_len
  if after >= line.length() { return false }
  let c = line[after]
  c == '=' || c == ':' || c == '"' || c == '\''
}

/// 判断关键词是否出现在同一行 `=` / `:` 的**左侧**（中间允许空格/制表）。
/// X5：password/secret 类关键词从「无条件命中」收紧为赋值上下文判定，
/// 允许 `password = x` 这种等号前有空格的常见写法。
fn is_left_of_assignment(line : String, keyword_pos : Int, keyword_len : Int) -> Bool {
  let mut i = keyword_pos + keyword_len
  let len = line.length()
  while i < len && (line[i] == ' ' || line[i] == '\t') {
    i = i + 1
  }
  if i >= len { return false }
  line[i] == '=' || line[i] == ':'
}

/// 从第一个关键字位置开始查找子串。
fn find_substr(line : String, needle : String) -> Int {
  let nlen = needle.length()
  let llen = line.length()
  if nlen > llen { return -1 }
  let mut i = 0
  while i <= llen - nlen {
    let mut ok = true
    let mut j = 0
    while j < nlen {
      if line[i + j] != needle[j] {
        ok = false
        break
      }
      j = j + 1
    }
    if ok { return i }
    i = i + 1
  }
  -1
}

/// 检查 env var key 是否合法（>=3 字符，只含 A-Z/0-9/_）。
fn is_valid_env_key(key : String) -> Bool {
  if key.length() < 3 { return false }
  for c in key {
    if !((c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_') {
      return false
    }
  }
  true
}

/// 纯函数：扫描文本中的敏感数据。
///
/// 短匹配策略（H1，X5 收紧）：通用关键字（token/private）要求**紧跟**
/// `=`/`:`/引号分隔符（不再接受空格/制表）；password/passwd/secret/credential
/// 要求出现在同一行 `=`/`:` 的左侧（允许中间隔空格/制表），
/// 避免匹配代码注释或英文句子中的同形词。
/// 行号一律 1 基（X6）：逐行扫描从 1 计数，env 扫描按换行偏移换算。
pub fn scan_sensitive(text : String) -> Array[SensitiveHit] {
  let hits : Array[SensitiveHit] = []
  let lines = text.split("\n")
  let mut line_num = 1

  for line in lines {
    let lower = line.to_lower().to_owned()
    let preview = if line.length() > 80 { line[:80].to_owned() } else { line.to_owned() }

    // API Key — 高确定性关键字，无需分隔符
    if lower.contains("api_key") || lower.contains("apikey") || lower.contains("api-key") {
      hits.push({ kind: ApiKey, line: line_num, preview })
      line_num = line_num + 1
      continue
    }

    // Token — 高确定性前缀无需分隔；通用 "token" 要求分隔符
    if lower.contains("bearer ") || lower.contains("access_token") || lower.contains("refresh_token") {
      hits.push({ kind: Token, line: line_num, preview })
      line_num = line_num + 1
      continue
    }
    let token_pos = find_substr(lower, "token")
    if token_pos >= 0 && !lower.contains("tokenizer") && !lower.contains("tokenize") && is_assignment_context(lower, token_pos, 5) {
      hits.push({ kind: Token, line: line_num, preview })
      line_num = line_num + 1
      continue
    }

    // Password / Secret / Credential — 要求出现在同一行 `=`/`:` 左侧（X5）
    let mut pw_pos = find_substr(lower, "password")
    let mut pw_len = 8
    if pw_pos < 0 {
      pw_pos = find_substr(lower, "passwd")
      pw_len = 6
    }
    if pw_pos >= 0 && is_left_of_assignment(lower, pw_pos, pw_len) {
      hits.push({ kind: Password, line: line_num, preview })
      line_num = line_num + 1
      continue
    }
    let secret_pos = find_substr(lower, "secret")
    if secret_pos >= 0 && is_left_of_assignment(lower, secret_pos, 6) {
      hits.push({ kind: Password, line: line_num, preview })
      line_num = line_num + 1
      continue
    }
    let cred_pos = find_substr(lower, "credential")
    if cred_pos >= 0 && is_left_of_assignment(lower, cred_pos, 10) {
      hits.push({ kind: Password, line: line_num, preview })
      line_num = line_num + 1
      continue
    }

    // Private Key — 高确定性关键字
    if lower.contains("private_key") || lower.contains("privkey") || lower.contains("begin private key") || lower.contains("begin rsa") {
      hits.push({ kind: PrivateKey, line: line_num, preview })
      line_num = line_num + 1
      continue
    }
    // 通用 "private" 要求分隔符
    let priv_pos = find_substr(lower, "private")
    if priv_pos >= 0 && is_assignment_context(lower, priv_pos, 7) {
      hits.push({ kind: PrivateKey, line: line_num, preview })
      line_num = line_num + 1
      continue
    }

    // Auth Header — 高确定性关键字（含冒号，天然有分隔）
    if lower.contains("authorization:") || lower.contains("x-api-key:") {
      hits.push({ kind: AuthHeader, line: line_num, preview })
      line_num = line_num + 1
      continue
    }

    line_num = line_num + 1
  }

  // 环境变量赋值扫描。X6：按换行偏移换算真实行号（1 基），
  // 之前恒写 0 会让人读消息里的行号没有意义。
  let mut env_line = 1
  let mut i = 0
  let len = text.length()
  while i < len {
    if text[i] == '\n' {
      env_line = env_line + 1
    } else if i == 0 || text[i - 1] == '\n' || text[i - 1] == ' ' {
      let mut j = i
      while j < len && ((text[j] >= 'A' && text[j] <= 'Z') || text[j] == '_') {
        j = j + 1
      }
      if j > i && j < len && text[j] == '=' {
        let eq_end = j + 1
        if eq_end < len && text[eq_end] != ' ' && text[eq_end] != '\n' {
          if is_valid_env_key(text[i:j].to_owned()) {
            let snippet = if j + 20 < len { text[i:j + 20].to_owned() } else { text[i:].to_owned() }
            hits.push({ kind: EnvAssignment, line: env_line, preview: snippet })
          }
        }
      }
    }
    i = i + 1
  }

  hits
}

/// 判断归一化后的路径是否仍含未消解的 `..` 段（相对路径开头，
/// `path_lexical_resolve` 无法在词法上消解它们 —— 见 util/path.mbt）。
fn has_unresolved_dotdot(p : String) -> Bool {
  for seg in p.split("/") {
    if seg.to_owned() == ".." {
      return true
    }
  }
  false
}

/// 检查路径是否在边界目录内。
/// L3: 统一转小写比较（Windows 大小写不敏感）。
///
/// X1：target 与 boundary 先经 `path_lexical_resolve` 消解 `.` 与非开头的
/// `..` 段，堵住 `"boundary/../外"` 式穿越；仍含未消解 `..`（相对路径开头）
/// 的结果视为不可判定，一律拒绝。
///
/// ★ 已知限制（X7）：本检查**仅词法边界，不解析符号链接** ——
/// 经 symlink 指向边界外的路径在此无法识别。`moonbitlang/async/fs` 虽有
/// `realpath`，但 executor 包构建依赖未引入 fs（见 moon.pkg），且文件 I/O
/// 按不变量①收口在 store 层，故暂无法在写入前复核真实路径。
fn is_within_boundary(target_path : String, boundary_root : String) -> Bool {
  let target = @util.path_lexical_resolve(target_path).to_lower()
  let boundary = @util.path_lexical_resolve(boundary_root).to_lower()
  if has_unresolved_dotdot(target) || has_unresolved_dotdot(boundary) {
    return false
  }
  if target == boundary { return true }
  target.has_prefix("\{boundary}/")
}

/// 单个文件的备份记录。
pub(all) struct FileBackup {
  original_path : String
  backup_path : String
  has_sensitive : Bool
  sensitive_hits : Array[SensitiveHit]
} derive(ToJson)

/// Pre-Check 结果。
pub(all) struct PreCheckResult {
  sandbox_dir : String
  boundary_root : String
  backups : Array[FileBackup]
  sensitive_summary : Array[SensitiveHit]
  modified_paths : Array[String]
} derive(ToJson)

/// FNV-1a（32 位）哈希的 8 位 hex 字符串，供 flat_name 消歧（X4）。
/// 用 Int 存位模式：`& 0xF` 取 nibble 时天然屏蔽算术右移的符号扩展，
/// 乘法溢出按 32 位回绕，与规范 FNV-1a 语义一致。
fn fnv1a_hex(s : String) -> String {
  // 2166136261（0x811C9DC5）按带符号 32 位表示
  let mut h = -2128831035
  let n = s.length()
  for i in 0..<n {
    h = h ^ s[i].to_int()
    h = h * 16777619
  }
  let hex : Array[Char] = [
    '0', '1', '2', '3', '4', '5', '6', '7',
    '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
  ]
  let buf = StringBuilder(size_hint=8)
  for shift in [28, 24, 20, 16, 12, 8, 4, 0] {
    buf.write_char(hex[(h >> shift) & 0xF])
  }
  buf.to_string()
}

/// 入口函数：修改前安全检查。
pub async fn sandbox_pre_check(
  files_to_modify : Array[String],
  boundary_root : String,
  sandbox_dir : String,
) -> PreCheckResult {
  // M1: 确保沙箱目录存在
  @store.sandbox_ensure_dir(sandbox_dir)

  let backups : Array[FileBackup] = []
  let all_sensitive : Array[SensitiveHit] = []

  for file_path in files_to_modify {
    if !is_within_boundary(file_path, boundary_root) {
      @util.log_warn(
        "sandbox:pre_check",
        "⛔ 文件 \{file_path} 超出修改边界 \{boundary_root}，拒绝备份",
      )
      continue
    }

    let norm_path = @util.path_normalize(file_path)
    let flat_name = norm_path
      .replace_all(old="/", new="__")
      .replace_all(old="\\", new="__")
      .replace_all(old=":", new="_")
    // X4: 分隔符折叠有碰撞（d:/x/y.md 与 d:/x__y.md 同映射）——
    // 末尾附完整路径的 FNV-1a 短哈希消歧
    let backup_path = @util.path_join(
      sandbox_dir,
      "\{flat_name}_\{fnv1a_hex(norm_path)}.bak",
    )

    // X2: 备份已存在说明此前已 pre_check 过 —— 跳过覆盖写入，
    // 保留最早的原始版本。否则二次备份会把已修改的内容当成
    // 「原始版本」覆盖备份，rollback 恢复的就不是原件。
    let backup_exists : Result[String, String] = Ok(
      @store.sandbox_read_text(backup_path),
    ) catch {
      _ => Err("backup missing")
    }
    match backup_exists {
      Ok(_) =>
        @util.log_warn(
          "sandbox:backup",
          "备份已存在，跳过覆盖（保留最早原始版本）: \{file_path}",
        )
      Err(_) =>
        match @store.sandbox_backup_file(file_path, backup_path) {
          Ok(_) => ()
          Err(msg) => {
            @util.log_warn("sandbox:backup", "备份跳过: \{msg}")
            continue
          }
        }
    }

    let original = @store.sandbox_read_text(file_path)
    let hits = scan_sensitive(original)
    let has_sensitive = hits.length() > 0

    if has_sensitive {
      @util.log_warn(
        "sandbox:sensitive",
        "⚠ 文件 \{file_path} 包含 \{hits.length()} 处敏感数据，备份已创建",
      )
    }

    backups.push({ original_path: norm_path, backup_path, has_sensitive, sensitive_hits: hits })
    for hit in hits {
      all_sensitive.push(hit)
    }
  }

  if all_sensitive.length() > 0 {
    @util.log_warn(
      "sandbox:pre_check",
      "⚠ 共 \{files_to_modify.length()} 个文件中有敏感数据，请在修改后验证完整性",
    )
  }

  { sandbox_dir, boundary_root, backups, sensitive_summary: all_sensitive, modified_paths: [] }
}

/// 原子写入：越界检查 + store 层写入。
/// M2: 记录被修改的路径。
pub async fn sandbox_atomic_write(
  target_path : String,
  content : String,
  boundary_root : String,
  result : PreCheckResult,
) -> Result[Unit, String] {
  guard is_within_boundary(target_path, boundary_root) else {
    return Err("拒绝写入：\{target_path} 超出修改边界 \{boundary_root}")
  }
  @store.sandbox_atomic_write(target_path, content)
  // M2: 追踪已修改路径
  result.modified_paths.push(@util.path_normalize(target_path))
  Ok(())
}

/// 验证单个文件的敏感数据完整性。
async fn verify_one_backup(backup : FileBackup) -> Array[String] {
  let errors : Array[String] = []
  let modified = @store.sandbox_read_text(backup.original_path)

  for hit in backup.sensitive_hits {
    match hit.kind {
      ApiKey => {
        if !modified.to_lower().contains("api_key") && !modified.to_lower().contains("apikey") && !modified.to_lower().contains("api-key") {
          errors.push("API Key 模式在 \{backup.original_path} 中消失（原行 \{hit.line}）")
        }
      }
      Token => {
        if !modified.to_lower().contains("token") && !modified.to_lower().contains("bearer") {
          errors.push("Token 模式在 \{backup.original_path} 中消失（原行 \{hit.line}）")
        }
      }
      Password => {
        if !modified.to_lower().contains("password") && !modified.to_lower().contains("secret") {
          errors.push("Password/Secret 模式在 \{backup.original_path} 中消失（原行 \{hit.line}）")
        }
      }
      AuthHeader => {
        if !modified.to_lower().contains("authorization:") {
          errors.push("Authorization header 在 \{backup.original_path} 中消失（原行 \{hit.line}）")
        }
      }
      EnvAssignment => {
        let preview = hit.preview
        let mut eq_pos = -1
        let mut ci = 0
        while ci < preview.length() {
          if preview[ci] == '=' {
            eq_pos = ci
            break
          }
          ci = ci + 1
        }
        if eq_pos > 0 {
          let key = preview[:eq_pos].to_owned()
          if !modified.contains(key) {
            errors.push("环境变量 \{key} 在 \{backup.original_path} 中消失")
          }
        }
      }
      PrivateKey => {
        if !modified.to_lower().contains("private") {
          errors.push("Private key 标记在 \{backup.original_path} 中消失（原行 \{hit.line}）")
        }
      }
    }
  }

  errors
}

/// 修改后验证：检查所有备份的敏感数据完整性。
pub async fn sandbox_post_verify(result : PreCheckResult) -> Array[String] {
  let all_errors : Array[String] = []

  for backup in result.backups {
    if backup.has_sensitive {
      let errors = verify_one_backup(backup)
      for e in errors {
        all_errors.push(e)
      }
    }
  }

  if all_errors.length() > 0 {
    @util.log_warn(
      "sandbox:post_verify",
      "⚠ 发现 \{all_errors.length()} 处敏感数据完整性问题，建议 rollback",
    )
  }

  all_errors
}

/// 回滚：从备份恢复已修改的文件（逆序）。
/// M2: 只恢复 modified_paths 中包含的文件，跳过未触及的。
/// X3: 先对比 modified_paths 与 backups —— 已修改但**无备份**的路径
/// （如本次会话新建的文件）无法自动恢复，必须明确告警，
/// 不能静默跳过更不能谎称「未修改」。
pub async fn sandbox_restore_all(result : PreCheckResult) -> Unit {
  for p in result.modified_paths {
    let mut has_backup = false
    for backup in result.backups {
      if backup.original_path == p {
        has_backup = true
        break
      }
    }
    if !has_backup {
      @util.log_warn(
        "sandbox:restore",
        "⚠ 已修改但无备份，无法自动恢复: \{p}",
      )
    }
  }
  let len = result.backups.length()
  let mut idx = len
  while idx > 0 {
    idx = idx - 1
    let backup = result.backups[idx]
    // M2: 只恢复确实被修改过的文件
    let mut was_modified = false
    for p in result.modified_paths {
      if p == backup.original_path {
        was_modified = true
        break
      }
    }
    if was_modified {
      @store.sandbox_restore_file(backup.backup_path, backup.original_path)
      @util.log_warn("sandbox:restore", "↩ 已恢复: \{backup.original_path}")
    } else {
      @util.log_warn("sandbox:restore", "- 跳过（未修改）: \{backup.original_path}")
    }
  }
}

/// 清理：验证通过后丢弃所有备份。
pub async fn sandbox_discard_backups(result : PreCheckResult) -> Unit {
  for backup in result.backups {
    @store.sandbox_remove_backup(backup.backup_path)
  }
  @store.sandbox_cleanup_dir(result.sandbox_dir)
}
