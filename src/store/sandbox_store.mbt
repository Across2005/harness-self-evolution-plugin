// Copyright (c) 2026. All rights reserved.
// Licensed under the MIT License.
//
// sandbox_store.mbt — 安全沙箱的文件 I/O 层。
//
// 遵循不变量①：持久化 I/O 只存在于 store/。
// 所有函数均为模块级（无 struct），无 unused-self 警告。
// 原子写与备份复用同包 jsonl.mbt 的 `unique_tmp_path` + `rename_or_cleanup`
// 配方（★ S9/S11），不再各自手写固定 `.tmp` 的版本。

/// 为单个文件创建备份。返回备份路径。
///
/// · 读取与写入都是**字节级**往返（★ S11b）：`@fs.read_file(..).binary()`
///   拿原始字节、`write_file` 直收 `Bytes`。旧实现 `.text()` 做文本往返，
///   非 UTF-8 字节（如 GBK 编码的源文件）会被替换成 U+FFFD，
///   备份在落盘那一刻就已永久损毁。
/// · 写备份走「临时文件 + rename」原子替换（★ S11a）。旧实现
///   CreateOrTruncate **原地截断**写备份，写中途崩溃会留下半截备份，
///   restore 读到它就会把半截内容当成原始版本放回 —— 备份是原始内容的
///   唯一副本，绝不允许半成品。
pub async fn sandbox_backup_file(
  target_path : String,
  backup_path : String,
) -> Result[String, String] {
  guard @fs.exists(target_path) else {
    return Err("文件不存在，无需备份: \{target_path}")
  }
  let original = @fs.read_file(target_path).binary()
  let tmp = unique_tmp_path(backup_path)
  @fs.write_file(tmp, original, create_mode=CreateOrTruncate)
  rename_or_cleanup(tmp, backup_path)
  Ok(backup_path)
}

/// 备份文件是否存在（★ S3）。
///
/// 单次 stat 取代「整文件读取 + catch 判空」：`sandbox_pre_check` 的
/// 「备份已存在则跳过覆盖」判定只需要存在性，读全文是纯浪费 ——
/// 备份大小与源文件同量级，每次 pre_check 都白读一遍。
/// 收口在 store 层，维持不变量①（持久化 I/O 只存在于 store/）。
pub async fn sandbox_backup_exists(path : String) -> Bool {
  @fs.exists(path)
}

/// 读取文件全部文本内容。
pub async fn sandbox_read_text(path : String) -> String {
  @fs.read_file(path).text()
}

/// 从备份恢复文件。备份缺失 → raise Failure（★ S11c）：
/// 「没恢复」与「恢复完成」必须可区分 —— 旧实现静默 return 会让
/// executor 的回滚流程误以为已还原，带着未回滚的修改继续跑。
pub async fn sandbox_restore_file(
  backup_path : String,
  original_path : String,
) -> Unit {
  if !@fs.exists(backup_path) {
    raise Failure("no backup to restore: \{backup_path}")
  }
  // 字节级往返，理由同 sandbox_backup_file（★ S11b）：
  // 备份里躺着的可能就是非 UTF-8 的原始字节。
  let content = @fs.read_file(backup_path).binary()
  @fs.write_file(original_path, content, create_mode=CreateOrTruncate)
}

/// 删除单个备份文件。
pub async fn sandbox_remove_backup(backup_path : String) -> Unit {
  if @fs.exists(backup_path) {
    @fs.remove(backup_path)
  }
}

/// 清理空的沙箱目录。
///
/// `include_hidden=true` 显式传（★ S12，与 agent_defs / cache 的既有口径
/// 一致）：readdir 只统计真实存在的子项，隐藏子项也不例外 ——
/// 语义上自明，不依赖上游缺省值。
pub async fn sandbox_cleanup_dir(sandbox_dir : String) -> Unit {
  if @fs.exists(sandbox_dir) {
    let entries = @fs.readdir(sandbox_dir, include_hidden=true) catch {
      _ => return
    }
    if entries.length() == 0 {
      @fs.remove(sandbox_dir)
    }
  }
}

/// 确保目录存在（递归创建）。
pub async fn sandbox_ensure_dir(dir : String) -> Unit {
  if !@fs.exists(dir) {
    @fs.mkdir(dir, recursive=true)
  }
}

/// 原子写入：先写**唯一命名**的临时文件，再 rename（★ S9）。
/// 旧实现固定 `<target>.tmp`，两个原子写交错时会互相踩踏
/// （A 写 tmp → B 写同一 tmp → A rename 改走了 B 的半成品），
/// 与 jsonl.mbt 的 `unique_tmp_path` / `rename_or_cleanup` 同一配方。
pub async fn sandbox_atomic_write(
  target_path : String,
  content : String,
) -> Unit {
  let dir = @util.path_dirname(target_path)
  if dir != "." && dir != "/" && !@fs.exists(dir) {
    @fs.mkdir(dir, recursive=true)
  }
  let tmp = unique_tmp_path(target_path)
  @fs.write_file(tmp, content, create_mode=CreateOrTruncate)
  rename_or_cleanup(tmp, target_path)
}
