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
fn is_assignment_context(line : String, keyword_pos : Int, keyword_len : Int) -> Bool {
  let after = keyword_pos + keyword_len
  if after >= line.length() { return false }
  let c = line[after]
  c == '=' || c == ':' || c == '"' || c == '\'' || c == ' ' || c == '\t'
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
/// 短匹配策略（H1）：通用关键字（token/password/secret/credential/private）
/// 要求后跟 `=`/`:`/`"`/`'`/空格 分隔符，避免匹配代码注释或英文句子中的同形词。
pub fn scan_sensitive(text : String) -> Array[SensitiveHit] {
  let hits : Array[SensitiveHit] = []
  let lines = text.split("\n")
  let mut line_num = 0

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

    // Password / Secret / Credential — 高确定性关键字无需分隔；通用词要求分隔符
    if lower.contains("password") || lower.contains("passwd") {
      hits.push({ kind: Password, line: line_num, preview })
      line_num = line_num + 1
      continue
    }
    let secret_pos = find_substr(lower, "secret")
    if secret_pos >= 0 && is_assignment_context(lower, secret_pos, 6) {
      hits.push({ kind: Password, line: line_num, preview })
      line_num = line_num + 1
      continue
    }
    let cred_pos = find_substr(lower, "credential")
    if cred_pos >= 0 && is_assignment_context(lower, cred_pos, 10) {
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

  // 环境变量赋值扫描
  let mut i = 0
  let len = text.length()
  while i < len {
    if i == 0 || text[i - 1] == '\n' || text[i - 1] == ' ' {
      let mut j = i
      while j < len && ((text[j] >= 'A' && text[j] <= 'Z') || text[j] == '_') {
        j = j + 1
      }
      if j > i && j < len && text[j] == '=' {
        let eq_end = j + 1
        if eq_end < len && text[eq_end] != ' ' && text[eq_end] != '\n' {
          if is_valid_env_key(text[i:j].to_owned()) {
            let snippet = if j + 20 < len { text[i:j + 20].to_owned() } else { text[i:].to_owned() }
            hits.push({ kind: EnvAssignment, line: 0, preview: snippet })
          }
        }
      }
    }
    i = i + 1
  }

  hits
}

/// 检查路径是否在边界目录内。
/// L3: 统一转小写比较（Windows 大小写不敏感）。
fn is_within_boundary(target_path : String, boundary_root : String) -> Bool {
  let target = @util.path_normalize(target_path).to_lower()
  let boundary = @util.path_normalize(boundary_root).to_lower()
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
    let backup_path = @util.path_join(sandbox_dir, "\{flat_name}.bak")

    match @store.sandbox_backup_file(file_path, backup_path) {
      Ok(_) => {
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
      Err(msg) => {
        @util.log_warn("sandbox:backup", "备份跳过: \{msg}")
      }
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
pub async fn sandbox_restore_all(result : PreCheckResult) -> Unit {
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
