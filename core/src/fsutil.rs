//! 文件系统原语：数据目录解析（含旧目录迁移）与原子写。
//!
//! 从 runtime/src/storage.rs 下沉而来——download crate 只用到这两个能力，
//! 若留在 runtime 会造成 download → runtime → application 的依赖环。

use std::io::Write;
use std::path::{Path, PathBuf};

fn data_dir_path() -> PathBuf {
    dirs::data_dir()
        .or_else(dirs::config_dir)
        .unwrap_or_else(|| PathBuf::from("."))
        .join("voicefox")
}

/// 0.3.12 之前的数据目录：`~/.config/voicefox/data`。
fn legacy_data_dir() -> PathBuf {
    dirs::config_dir()
        .unwrap_or_else(|| PathBuf::from("."))
        .join("voicefox")
        .join("data")
}

/// 0.3.12 之前的目录里由本模块（或同一数据目录）落盘的业务文件。
const LEGACY_DATA_FILES: &[&str] = &[
    "favorites.json",
    "favorite_playlists.json",
    "custom_playlists.json",
    "history.json",
    "playback_state.json",
    "downloads.json",
    "netease_collections.json",
];

/// 把旧数据目录迁移到当前数据目录，返回当前数据目录。
///
/// 背景：0.3.12 把数据目录从 `~/.config/voicefox/data` 改成了
/// `~/.local/share/voicefox`，但只改了路径、没有搬数据，于是升级后收藏、
/// 历史和播放会话全部读不到（新目录是空的），旧文件则一直留在旧目录里。
///
/// 迁移**绝不覆盖当前目录里已有的文件**，分两步：
/// 1. 当前目录整体不存在时，直接 `rename` 整个旧目录；
/// 2. 当前目录已存在时，逐文件补迁缺失项（典型情况：新目录已经重建了
///    收藏/历史，只剩 `playback_state.json` 没搬过来）。
fn migrate_legacy_data_dir() -> PathBuf {
    let target = data_dir_path();
    migrate_data_dir(&target, &legacy_data_dir());
    target
}

/// [`migrate_legacy_data_dir`](migrate_legacy_data_dir) 的实际实现。
///
/// 目录参数显式传入，便于测试覆盖"整体搬迁"和"逐文件补迁"两条路径。
pub fn migrate_data_dir(target: &Path, legacy: &Path) {
    if target == legacy {
        return;
    }

    if !target.exists() && legacy.is_dir() {
        if let Some(parent) = target.parent() {
            let _ = std::fs::create_dir_all(parent);
        }
        match std::fs::rename(legacy, target) {
            Ok(()) => {
                tracing::info!("已把旧数据目录迁移到 {}", target.display());
                return;
            }
            Err(error) => tracing::warn!("整体迁移旧数据目录失败，改为逐文件补迁: {error}"),
        }
    }

    if !legacy.is_dir() {
        return;
    }
    if let Err(error) = std::fs::create_dir_all(target) {
        tracing::warn!("创建数据目录失败: {error}");
        return;
    }
    for name in LEGACY_DATA_FILES {
        let (source, destination) = (legacy.join(name), target.join(name));
        // 已经有新数据时绝不回退覆盖，否则会把用户 0.3.12 之后的收藏/历史冲掉。
        if destination.exists() || !source.is_file() {
            continue;
        }
        if std::fs::rename(&source, &destination).is_ok()
            || std::fs::copy(&source, &destination).is_ok()
        {
            tracing::info!("已从旧数据目录迁移 {name}");
        }
    }
}

/// 数据目录。首次调用时会顺带完成旧目录迁移，因此无论调用方是
/// `Storage`、下载记录还是远程缓存，拿到的都是迁移后的路径。
pub fn default_data_dir() -> PathBuf {
    static MIGRATION: std::sync::Once = std::sync::Once::new();
    MIGRATION.call_once(|| {
        migrate_legacy_data_dir();
    });
    data_dir_path()
}

pub fn save_atomic(path: &Path, content: &[u8]) -> Result<(), String> {
    save_atomic_impl(path, content, true)
}

/// 原子写但不做 fsync：只保证不出现半截文件，不保证断电后内容还在。
/// 适用于可再生的缓存型数据（如播放会话），避免 5 秒一次的持久化
/// 在 TUI 线程上产生磁盘刷写停顿。
pub fn save_atomic_relaxed(path: &Path, content: &[u8]) -> Result<(), String> {
    save_atomic_impl(path, content, false)
}

/// 只写临时文件不换名，由 [`commit_staged`] 完成最终落盘。
pub fn stage_atomic(path: &Path, content: &[u8]) -> Result<PathBuf, String> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).map_err(|error| error.to_string())?;
    }
    let temp_path = path.with_extension(format!(
        "json.tmp-{}-{}",
        std::process::id(),
        STORAGE_TEMP_SEQ.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
    ));
    let mut file = std::fs::File::create(&temp_path).map_err(|error| error.to_string())?;
    file.write_all(content).map_err(|error| error.to_string())?;
    file.sync_all().map_err(|error| error.to_string())?;
    Ok(temp_path)
}

pub fn commit_staged(temp_path: &Path, target: &Path) -> Result<(), String> {
    #[cfg(windows)]
    {
        let old_path = target.with_extension(format!("json.old-{}", std::process::id()));
        if target.exists() {
            std::fs::rename(target, &old_path).map_err(|error| error.to_string())?;
        }
        match std::fs::rename(temp_path, target) {
            Ok(()) => {
                let _ = std::fs::remove_file(&old_path);
                Ok(())
            }
            Err(error) => {
                let _ = std::fs::rename(&old_path, target);
                Err(error.to_string())
            }
        }
    }
    #[cfg(not(windows))]
    {
        std::fs::rename(temp_path, target).map_err(|error| error.to_string())
    }
}

pub fn save_atomic_impl(path: &Path, content: &[u8], durable: bool) -> Result<(), String> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).map_err(|error| error.to_string())?;
    }
    let temp_path = path.with_extension(format!(
        "json.tmp-{}-{}",
        std::process::id(),
        STORAGE_TEMP_SEQ.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
    ));
    let result = (|| {
        let mut file = std::fs::File::create(&temp_path).map_err(|error| error.to_string())?;
        file.write_all(content).map_err(|error| error.to_string())?;
        // 数据落盘后再换名，避免断电时目录项先于数据持久化，留下空文件。
        if durable {
            file.sync_all().map_err(|error| error.to_string())?;
        }
        drop(file);

        #[cfg(windows)]
        {
            // Windows 不支持覆盖式 rename：先把旧文件挪走（而非删除），
            // 换名失败时把它挪回来，保证任何时刻目标文件都存在。
            let old_path = path.with_extension(format!("json.old-{}", std::process::id()));
            if path.exists() {
                std::fs::rename(path, &old_path).map_err(|error| error.to_string())?;
            }
            match std::fs::rename(&temp_path, path) {
                Ok(()) => {
                    let _ = std::fs::remove_file(&old_path);
                }
                Err(error) => {
                    let _ = std::fs::rename(&old_path, path);
                    return Err(error.to_string());
                }
            }
        }

        #[cfg(not(windows))]
        std::fs::rename(&temp_path, path).map_err(|error| error.to_string())?;

        #[cfg(unix)]
        if durable
            && let Some(parent) = path.parent()
            && let Ok(dir) = std::fs::File::open(parent)
        {
            let _ = dir.sync_all();
        }
        Ok(())
    })();
    if result.is_err() {
        let _ = std::fs::remove_file(temp_path);
    }
    result
}

static STORAGE_TEMP_SEQ: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn whole_directory_migration_renames_the_legacy_dir() {
        let base = std::env::temp_dir().join(format!("vfs-fsutil-{}", std::process::id()));
        let legacy = base.join("legacy");
        let target = base.join("target");
        std::fs::create_dir_all(&legacy).unwrap();
        std::fs::write(legacy.join("favorites.json"), b"[]").unwrap();

        migrate_data_dir(&target, &legacy);

        assert!(target.join("favorites.json").is_file());
        let _ = std::fs::remove_dir_all(&base);
    }

    #[test]
    fn per_file_migration_never_overwrites_existing_data() {
        let base = std::env::temp_dir().join(format!("vfs-fsutil2-{}", std::process::id()));
        let legacy = base.join("legacy");
        let target = base.join("target");
        std::fs::create_dir_all(&legacy).unwrap();
        std::fs::create_dir_all(&target).unwrap();
        std::fs::write(legacy.join("history.json"), b"legacy").unwrap();
        std::fs::write(target.join("history.json"), b"current").unwrap();

        migrate_data_dir(&target, &legacy);

        assert_eq!(
            std::fs::read_to_string(target.join("history.json")).unwrap(),
            "current"
        );
        let _ = std::fs::remove_dir_all(&base);
    }

    #[test]
    fn save_atomic_leaves_no_temp_files_and_round_trips() {
        let base = std::env::temp_dir().join(format!("vfs-fsutil3-{}", std::process::id()));
        let path = base.join("sub").join("data.json");
        save_atomic(&path, b"hello").unwrap();
        save_atomic(&path, b"world").unwrap();
        assert_eq!(std::fs::read(&path).unwrap(), b"world");
        let entries: Vec<_> = std::fs::read_dir(path.parent().unwrap())
            .unwrap()
            .filter_map(Result::ok)
            .map(|e| e.file_name().to_string_lossy().to_string())
            .collect();
        assert_eq!(entries, vec!["data.json".to_string()]);
        let _ = std::fs::remove_dir_all(&base);
    }
}
