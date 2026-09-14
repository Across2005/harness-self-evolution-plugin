// Copyright (c) 2026. All rights reserved.
// Licensed under the MIT License.
//
// sandbox.mbt — 安全沙箱的纯逻辑层。
//
// 所有文件 I/O 通过 @store.SandboxStore 实例执行（不变量①）。

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

/// 纯函数：扫描文本中的敏感数据。
pub fn scan_sensitive(text : String) -> Array[SensitiveHit] {
  let hits : Array[SensitiveHit] = []
  let lines = text.split("\n")
  let mut line_num = 0

  for line in lines {
    let lower = line.to_lower()
    let preview = if line.length() > 80 { line[:80].to_owned() } else { line.to_owned() }

    if lower.contains("api_key") || lower.contains("apikey") || lower.contains("api-key") {
      hits.push({ kind: ApiKey, line: line_num, preview })
      line_num = line_num + 1
      continue
    }
    if lower.contains("bearer ") || lower.contains("access_token") || lower.contains("refresh_token") || (lower.contains("token") && !lower.contains("tokenizer")) {
      hits.push({ kind: Token, line: line_num, preview })
      line_num = line_num + 1
      continue
    }
    if lower.contains("password") || lower.contains("passwd") || lower.contains("secret") || lower.contains("credential") {
      hits.push({ kind: Password, line: line_num, preview })
      line_num = line_num + 1
      continue
    }
    if lower.contains("private_key") || lower.contains("privkey") || lower.contains("begin private key") || lower.contains("begin rsa") {
      hits.push({ kind: PrivateKey, line: line_num, preview })
      line_num = line_num + 1
      continue
    }
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
          let snippet = if j + 20 < len { text[i:j + 20].to_owned() } else { text[i:].to_owned() }
          hits.push({ kind: EnvAssignment, line: 0, preview: snippet })
        }
      }
    }
    i = i + 1
  }

  hits
}

/// 检查路径是否在边界目录内。
fn is_within_boundary(target_path : String, boundary_root : String) -> Bool {
  let target = @util.path_normalize(target_path)
  let boundary = @util.path_normalize(boundary_root)
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
} derive(ToJson)

/// 入口函数：修改前安全检查。
pub async fn sandbox_pre_check(
  files_to_modify : Array[String],
  boundary_root : String,
  sandbox_dir : String,
) -> PreCheckResult {
  let store = @store.SandboxStore::new()
  store.ensure_dir(sandbox_dir)

  let backups : Array[FileBackup] = []
  let all_sensitive : Array[SensitiveHit] = []

  for file_path in files_to_modify {
    if !is_within_boundary(file_path, boundary_root) {
      @util.log_warn(
        "Sandbox",
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

    match store.backup_file(file_path, backup_path) {
      Ok(_) => {
        let original = store.read_text(file_path)
        let hits = scan_sensitive(original)
        let has_sensitive = hits.length() > 0

        if has_sensitive {
          @util.log_warn(
            "Sandbox",
            "⚠ 文件 \{file_path} 包含 \{hits.length()} 处敏感数据，备份已创建",
          )
        }

        backups.push({ original_path: norm_path, backup_path, has_sensitive, sensitive_hits: hits })
        for hit in hits {
          all_sensitive.push(hit)
        }
      }
      Err(msg) => {
        @util.log_warn("Sandbox", "备份跳过: \{msg}")
      }
    }
  }

  if all_sensitive.length() > 0 {
    @util.log_warn(
      "Sandbox",
      "⚠ 共 \{files_to_modify.length()} 个文件中有敏感数据，请在修改后验证完整性",
    )
  }

  { sandbox_dir, boundary_root, backups, sensitive_summary: all_sensitive }
}

/// 原子写入：越界检查 + store 层写入。
pub async fn sandbox_atomic_write(
  target_path : String,
  content : String,
  boundary_root : String,
) -> Result[Unit, String] {
  guard is_within_boundary(target_path, boundary_root) else {
    return Err("拒绝写入：\{target_path} 超出修改边界 \{boundary_root}")
  }
  let store = @store.SandboxStore::new()
  store.atomic_write(target_path, content)
  Ok(())
}

/// 验证单个文件的敏感数据完整性。
async fn verify_one_backup(store : @store.SandboxStore, backup : FileBackup) -> Array[String] {
  let errors : Array[String] = []
  let modified = store.read_text(backup.original_path)

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
  let store = @store.SandboxStore::new()
  let all_errors : Array[String] = []

  for backup in result.backups {
    if backup.has_sensitive {
      let errors = verify_one_backup(store, backup)
      for e in errors {
        all_errors.push(e)
      }
    }
  }

  if all_errors.length() > 0 {
    @util.log_warn(
      "Sandbox",
      "⚠ 发现 \{all_errors.length()} 处敏感数据完整性问题，建议 rollback",
    )
  }

  all_errors
}

/// 回滚：从备份恢复所有文件（逆序）。
pub async fn sandbox_restore_all(result : PreCheckResult) -> Unit {
  let store = @store.SandboxStore::new()
  let len = result.backups.length()
  let mut idx = len
  while idx > 0 {
    idx = idx - 1
    let backup = result.backups[idx]
    store.restore_file(backup.backup_path, backup.original_path)
    @util.log_warn("Sandbox", "↩ 已恢复: \{backup.original_path}")
  }
}

/// 清理：验证通过后丢弃所有备份。
pub async fn sandbox_discard_backups(result : PreCheckResult) -> Unit {
  let store = @store.SandboxStore::new()
  for backup in result.backups {
    store.remove_backup(backup.backup_path)
  }
  store.cleanup_sandbox_dir(result.sandbox_dir)
}
