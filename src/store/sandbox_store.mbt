// Copyright (c) 2026. All rights reserved.
// Licensed under the MIT License.
//
// sandbox_store.mbt — 安全沙箱的文件 I/O 层。
//
// 遵循不变量①：持久化 I/O 只存在于 store/。
// 所有函数均为模块级（无 struct），无 unused-self 警告。

/// 为单个文件创建备份。返回备份路径。
pub async fn sandbox_backup_file(
  target_path : String,
  backup_path : String,
) -> Result[String, String] {
  guard @fs.exists(target_path) else {
    return Err("文件不存在，无需备份: \{target_path}")
  }

  let original = @fs.read_file(target_path).text()
  @fs.write_file(backup_path, original, create_mode=CreateOrTruncate)
  Ok(backup_path)
}

/// 读取文件全部文本内容。
pub async fn sandbox_read_text(path : String) -> String {
  @fs.read_file(path).text()
}

/// 从备份恢复文件。
pub async fn sandbox_restore_file(
  backup_path : String,
  original_path : String,
) -> Unit {
  if @fs.exists(backup_path) {
    let content = @fs.read_file(backup_path).text()
    @fs.write_file(original_path, content, create_mode=CreateOrTruncate)
  }
}

/// 删除单个备份文件。
pub async fn sandbox_remove_backup(backup_path : String) -> Unit {
  if @fs.exists(backup_path) {
    @fs.remove(backup_path)
  }
}

/// 清理空的沙箱目录。
pub async fn sandbox_cleanup_dir(sandbox_dir : String) -> Unit {
  if @fs.exists(sandbox_dir) {
    let entries = @fs.readdir(sandbox_dir) catch {
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

/// 原子写入：先写 `.tmp`，再 rename。
pub async fn sandbox_atomic_write(
  target_path : String,
  content : String,
) -> Unit {
  let dir = @util.path_dirname(target_path)
  if dir != "." && dir != "/" && !@fs.exists(dir) {
    @fs.mkdir(dir, recursive=true)
  }

  let tmp = "\{target_path}.tmp"
  @fs.write_file(tmp, content, create_mode=CreateOrTruncate)
  @fs.rename(tmp, target_path)
}
