//! 本地曲库持久化缓存（§8.4：重启后仍在）。
//!
//! 扫描提交点把整库快照（分组歌曲 + 文件指纹 + 解析失败清单 + 首次发现
//! 时间）写到数据目录的 `local_library.json`，`LocalSource` 构造时同步
//! 加载，重启后无需重新扫描即可渲染（`local_songs()` 快照非空，页面自动
//! 全量扫描条件随之不再命中）。损坏或版本不符时静默丢弃，下次扫描重建。
//!
//! 与下载记录（downloads.json）的分工：本缓存只服务「本地库渲染加速」，
//! 不是用户数据的唯一副本；加载时对指纹做存在性校验，源文件已消失的
//! 歌曲转入 `missing`（播放列表/历史的路径语义仍然保留），不静默丢弃
//! 用户可见信息（§8.4:856）。

use std::collections::HashMap;
use std::path::{Path, PathBuf};

use lx_core::model::song::SongInfo;

use crate::local::{LocalScanFailure, LocalSong};

/// 当前格式版本；加载时版本不符直接丢弃（下次扫描重建）。
pub const CACHE_VERSION: u32 = 1;

/// 磁盘格式。`SongInfo` 本身可 serde，原样落盘；指纹的 `u128` 纳秒时间戳
/// serde_json 不支持，转字符串存储。
#[derive(serde::Serialize, serde::Deserialize)]
struct CacheFile {
    version: u32,
    paths: Vec<String>,
    groups: HashMap<String, Vec<CacheSong>>,
    fingerprints: HashMap<String, CacheFingerprint>,
    #[serde(default)]
    failures: Vec<CacheFailure>,
    #[serde(default)]
    first_seen: HashMap<String, i64>,
}

#[derive(serde::Serialize, serde::Deserialize)]
struct CacheSong {
    song: SongInfo,
    /// 来源文件路径：普通歌曲为音频文件，CUE 分轨为 CUE 文件。
    file_path: String,
}

#[derive(serde::Serialize, serde::Deserialize)]
struct CacheFingerprint {
    size: u64,
    modified_unix_nanos: String,
}

#[derive(serde::Serialize, serde::Deserialize)]
struct CacheFailure {
    path: String,
    error: String,
}

/// 扫描提交点写入；写失败只记日志（缓存是加速项，不阻塞扫描）。
pub fn store(
    path: &Path,
    loaded_paths: &[PathBuf],
    groups: &HashMap<PathBuf, Vec<LocalSong>>,
    fingerprints: &HashMap<PathBuf, crate::local::scanner::FileFingerprint>,
    failures: &[LocalScanFailure],
    first_seen: &HashMap<PathBuf, i64>,
) {
    let file = CacheFile {
        version: CACHE_VERSION,
        paths: loaded_paths
            .iter()
            .map(|value| value.display().to_string())
            .collect(),
        groups: groups
            .iter()
            .map(|(root, songs)| {
                (
                    root.display().to_string(),
                    songs
                        .iter()
                        .map(|local| CacheSong {
                            song: local.song.clone(),
                            file_path: local.file_path.display().to_string(),
                        })
                        .collect(),
                )
            })
            .collect(),
        fingerprints: fingerprints
            .iter()
            .map(|(file, fingerprint)| {
                (
                    file.display().to_string(),
                    CacheFingerprint {
                        size: fingerprint.size,
                        modified_unix_nanos: fingerprint.modified_unix_nanos.to_string(),
                    },
                )
            })
            .collect(),
        failures: failures
            .iter()
            .map(|failure| CacheFailure {
                path: failure.path.display().to_string(),
                error: failure.error.clone(),
            })
            .collect(),
        first_seen: first_seen
            .iter()
            .map(|(file, seen)| (file.display().to_string(), *seen))
            .collect(),
    };
    match serde_json::to_string(&file) {
        Ok(raw) => {
            if let Err(error) = std::fs::write(path, raw) {
                tracing::warn!(%error, "本地曲库缓存写入失败");
            }
        }
        Err(error) => tracing::warn!(%error, "本地曲库缓存序列化失败"),
    }
}

/// 加载结果：与 `store` 的参数一一对应（快照 + 首次发现时间）。
pub struct LoadedCache {
    pub loaded_paths: Vec<PathBuf>,
    pub groups: HashMap<PathBuf, Vec<LocalSong>>,
    pub fingerprints: HashMap<PathBuf, crate::local::scanner::FileFingerprint>,
    pub failures: Vec<LocalScanFailure>,
    pub first_seen: HashMap<PathBuf, i64>,
}

/// 加载缓存；`None` 表示没有缓存、损坏或版本不符（调用方按空库处理）。
pub fn load(path: &Path) -> Option<LoadedCache> {
    let raw = std::fs::read_to_string(path).ok()?;
    let parsed: CacheFile = serde_json::from_str(&raw).ok()?;
    if parsed.version != CACHE_VERSION {
        tracing::warn!(version = parsed.version, "本地曲库缓存版本不符，丢弃");
        return None;
    }
    let groups = parsed
        .groups
        .into_iter()
        .map(|(root, songs)| {
            (
                PathBuf::from(&root),
                songs
                    .into_iter()
                    .map(|cached| LocalSong {
                        song: cached.song,
                        file_path: PathBuf::from(cached.file_path),
                    })
                    .collect::<Vec<_>>(),
            )
        })
        .collect::<HashMap<_, _>>();
    let fingerprints = parsed
        .fingerprints
        .into_iter()
        .map(|(file, fingerprint)| {
            (
                PathBuf::from(&file),
                crate::local::scanner::FileFingerprint {
                    size: fingerprint.size,
                    modified_unix_nanos: fingerprint
                        .modified_unix_nanos
                        .parse::<u128>()
                        .unwrap_or(0),
                },
            )
        })
        .collect::<HashMap<_, _>>();
    let failures = parsed
        .failures
        .into_iter()
        .map(|failure| LocalScanFailure {
            path: PathBuf::from(failure.path),
            error: failure.error,
        })
        .collect::<Vec<_>>();
    let first_seen = parsed
        .first_seen
        .into_iter()
        .map(|(file, seen)| (PathBuf::from(file), seen))
        .collect::<HashMap<_, _>>();
    let loaded_paths = parsed
        .paths
        .into_iter()
        .map(PathBuf::from)
        .collect::<Vec<_>>();
    Some(LoadedCache {
        loaded_paths,
        groups,
        fingerprints,
        failures,
        first_seen,
    })
}
