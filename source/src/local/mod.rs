pub mod cache;
pub mod metadata;
pub mod scanner;

pub use metadata::MetadataEdit;

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex, RwLock, mpsc};
use std::thread::{self, JoinHandle};
use std::time::Duration;

use async_trait::async_trait;
use notify::event::{AccessKind, AccessMode};
use notify::{EventKind, RecursiveMode, Watcher, recommended_watcher};

use lx_core::model::lyric::LyricData;
use lx_core::model::song::SongInfo;
use lx_core::model::source::{QUALITY_ORDER, Quality, SourceId};
use lx_core::traits::source::{FetchError, MusicSource, SearchError, SearchResult, SongUrl};

/// 扫描到的本地歌曲。`file_path` 是来源文件路径：普通歌曲为其音频文件，
/// CUE 分轨为其 CUE 文件（播放用的音频路径在 `song.file_path`）。
#[derive(Debug, Clone)]
pub struct LocalSong {
    pub song: SongInfo,
    pub file_path: PathBuf,
}

/// 文件元数据读取失败时保留的诊断信息。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LocalScanFailure {
    pub path: PathBuf,
    pub error: String,
}

/// 已入库歌曲对应的文件被删除后保留的诊断信息。
#[derive(Debug, Clone)]
pub struct MissingLocalSong {
    pub path: PathBuf,
    pub song: SongInfo,
}

/// 疑似重复歌曲组。
#[derive(Debug, Clone)]
pub struct DuplicateLocalSongs {
    pub key: String,
    pub songs: Vec<SongInfo>,
}

/// 最近一次扫描的统计信息。
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct LocalScanStats {
    pub discovered: usize,
    pub reused: usize,
    pub parsed: usize,
    pub failed: usize,
    pub removed: usize,
    /// 扩展名不属于音频/CUE 而被跳过的文件数（§5.10「无音频文件」列）。
    pub skipped: usize,
}

struct WatcherHandle {
    stop: Arc<std::sync::atomic::AtomicBool>,
    wake: mpsc::Sender<()>,
    join: Option<JoinHandle<()>>,
}

impl Drop for WatcherHandle {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::SeqCst);
        let _ = self.wake.send(());
        if let Some(join) = self.join.take() {
            let _ = join.join();
        }
    }
}

/// 本地音源
pub struct LocalSource {
    /// 已扫描的歌曲列表（按目录分组）
    songs: RwLock<Arc<HashMap<PathBuf, Vec<LocalSong>>>>,
    /// 每个文件的轻量指纹，用于增量扫描和目录监听。
    fingerprints: RwLock<Arc<HashMap<PathBuf, scanner::FileFingerprint>>>,
    /// 最近一次扫描无法解析的文件。
    failures: RwLock<Arc<Vec<LocalScanFailure>>>,
    /// 最近一次扫描发现已消失的歌曲。
    missing: RwLock<Arc<Vec<MissingLocalSong>>>,
    /// 最近一次扫描时各根目录的目录签名；签名未变时跳过全目录遍历。
    last_scan_signatures: RwLock<HashMap<PathBuf, scanner::DirSignature>>,
    scan_stats: RwLock<LocalScanStats>,
    /// 当前加载的目录列表
    loaded_paths: RwLock<Vec<PathBuf>>,
    /// 每个来源文件的首次发现时间（Unix 秒）；为「最近添加」排序预留。
    first_seen: RwLock<HashMap<PathBuf, i64>>,
    scan_generation: AtomicU64,
    scan_in_progress: AtomicU64,
    /// 最近一次成功提交扫描结果的序号；页面据此判断排序缓存是否需要重建。
    library_generation: AtomicU64,
    watch_generation: AtomicU64,
    /// 协作式取消标志：`cancel_scan()` 置位，扫描在下一个检查点提前返回
    /// 且不提交（已提交结果保持不变）。注意这是单例共享标志：watcher
    /// 线程的强制重扫（TUI-only，GUI 不调用 start_watcher）也会被它取消。
    scan_cancel: AtomicBool,
    /// 最近一次扫描是否被取消（事件负载用；下一次扫描开始时清零）。
    last_scan_cancelled: AtomicBool,
    /// 曲库缓存文件路径；`None` 表示不持久化（测试与旧构造路径）。
    cache_path: Option<PathBuf>,
    watcher: Mutex<Option<WatcherHandle>>,
}

impl LocalSource {
    pub fn new() -> Self {
        Self {
            songs: RwLock::new(Arc::new(HashMap::new())),
            fingerprints: RwLock::new(Arc::new(HashMap::new())),
            failures: RwLock::new(Arc::new(Vec::new())),
            missing: RwLock::new(Arc::new(Vec::new())),
            last_scan_signatures: RwLock::new(HashMap::new()),
            scan_stats: RwLock::new(LocalScanStats::default()),
            loaded_paths: RwLock::new(Vec::new()),
            first_seen: RwLock::new(HashMap::new()),
            scan_generation: AtomicU64::new(0),
            scan_in_progress: AtomicU64::new(0),
            library_generation: AtomicU64::new(0),
            watch_generation: AtomicU64::new(0),
            scan_cancel: AtomicBool::new(false),
            last_scan_cancelled: AtomicBool::new(false),
            cache_path: None,
            watcher: Mutex::new(None),
        }
    }

    /// 生产构造：从默认数据目录加载曲库缓存（§8.4 重启后仍在）。
    ///
    /// 加载在构造内同步完成——GUI 的首个状态快照就带着本地歌曲，页面
    /// 「曲库为空才自动扫描」的条件因此不会在每次启动时触发全量扫描。
    pub fn with_default_cache() -> Self {
        Self::with_cache_path(lx_core::fsutil::default_data_dir().join("local_library.json"))
    }

    /// 从指定文件加载缓存，供测试与自定义数据目录使用。
    pub fn with_cache_path(path: PathBuf) -> Self {
        let mut source = Self::new();
        source.cache_path = Some(path.clone());
        let Some(cache::LoadedCache {
            loaded_paths: paths,
            groups,
            fingerprints,
            failures,
            first_seen,
        }) = cache::load(&path)
        else {
            return source;
        };
        // 磁盘漂移校验：源文件已消失的歌曲不进渲染快照，转入 missing
        //（播放列表/历史的路径语义保留）；指纹一并丢弃，修复路径交给
        // 下次扫描（重新发现则按新增计，不静默删除用户数据）。
        let mut kept_groups: HashMap<PathBuf, Vec<LocalSong>> = HashMap::new();
        let mut kept_fingerprints: HashMap<PathBuf, scanner::FileFingerprint> = HashMap::new();
        let mut missing = Vec::new();
        for (root, songs) in groups {
            let kept: Vec<LocalSong> = songs
                .into_iter()
                .filter(|local| {
                    if local.file_path.exists() {
                        true
                    } else {
                        missing.push(MissingLocalSong {
                            path: local.file_path.clone(),
                            song: local.song.clone(),
                        });
                        false
                    }
                })
                .collect();
            if !kept.is_empty() {
                kept_fingerprints.extend(
                    fingerprints
                        .iter()
                        .filter(|(file, _)| kept.iter().any(|local| &local.file_path == *file))
                        .map(|(file, fingerprint)| (file.clone(), *fingerprint)),
                );
                kept_groups.insert(root, kept);
            }
        }
        let first_seen = first_seen
            .into_iter()
            .filter(|(file, _)| kept_fingerprints.contains_key(file))
            .collect::<HashMap<_, _>>();
        let discovered = kept_fingerprints.len();
        *source.songs.write().unwrap_or_else(|e| e.into_inner()) = Arc::new(kept_groups);
        *source
            .fingerprints
            .write()
            .unwrap_or_else(|e| e.into_inner()) = Arc::new(kept_fingerprints);
        *source.failures.write().unwrap_or_else(|e| e.into_inner()) = Arc::new(failures);
        *source.missing.write().unwrap_or_else(|e| e.into_inner()) =
            Arc::new(deduplicate_missing(missing));
        *source
            .loaded_paths
            .write()
            .unwrap_or_else(|e| e.into_inner()) = paths;
        *source.first_seen.write().unwrap_or_else(|e| e.into_inner()) = first_seen;
        *source.scan_stats.write().unwrap_or_else(|e| e.into_inner()) = LocalScanStats {
            discovered,
            ..LocalScanStats::default()
        };
        // 代次 +1：页面排序缓存按代次重建，加载后的快照才能被消费。
        source.library_generation.fetch_add(1, Ordering::Release);
        source
    }

    /// 请求取消当前扫描；没有扫描在跑时是空操作（页面只在扫描中显示
    /// 取消按钮）。取消 = 本次扫描不提交，已提交结果保持不变。
    pub fn cancel_scan(&self) {
        self.scan_cancel.store(true, Ordering::SeqCst);
    }

    /// 最近一次扫描是否被取消（事件负载判定用）。
    pub fn last_scan_was_cancelled(&self) -> bool {
        self.last_scan_cancelled.load(Ordering::SeqCst)
    }

    /// 曲库代次，每次扫描提交新结果时递增。
    pub fn library_generation(&self) -> u64 {
        self.library_generation.load(Ordering::Acquire)
    }

    pub fn begin_scan(&self) -> u64 {
        // 新扫描开始：清掉上一轮遗留的取消请求与取消标记（没有扫描在跑
        // 时请求取消是空操作，不该波及之后的新扫描）。
        self.scan_cancel.store(false, Ordering::SeqCst);
        self.last_scan_cancelled.store(false, Ordering::SeqCst);
        let generation = self.scan_generation.fetch_add(1, Ordering::SeqCst) + 1;
        self.scan_in_progress
            .fetch_max(generation, Ordering::SeqCst);
        generation
    }

    /// 当前是否被请求取消（扫描检查点用）。
    fn scan_cancelled(&self) -> bool {
        self.scan_cancel.load(Ordering::SeqCst)
    }

    pub fn is_scanning(&self) -> bool {
        self.scan_in_progress.load(Ordering::SeqCst) != 0
    }

    /// 扫描指定目录并加载歌曲
    pub fn scan(&self, paths: &[String], max_depth: u32) -> Vec<String> {
        let generation = self.begin_scan();
        self.scan_for_generation(paths, max_depth, generation, false)
    }

    pub fn scan_for_generation(
        &self,
        paths: &[String],
        max_depth: u32,
        generation: u64,
        force: bool,
    ) -> Vec<String> {
        let _completion = ScanCompletion {
            source: self,
            generation,
        };
        // 快照只克隆 Arc 句柄（廉价）。旧代码在这里把整库深拷贝成 all_songs，
        // 但循环里被重扫的根目录会整组覆盖，监听器触发的重扫等于白白复制整个
        // 曲库。现在只把本次真正重扫的根目录写进新快照，其余条目在循环结束后
        // 才按需搬入（见下方补全逻辑），未变化的条目因此只复制一次。
        let previous_songs = self.songs.read().unwrap_or_else(|e| e.into_inner()).clone();
        let previous_fingerprints = self
            .fingerprints
            .read()
            .unwrap_or_else(|e| e.into_inner())
            .clone();
        let previous_missing = self
            .missing
            .read()
            .unwrap_or_else(|e| e.into_inner())
            .clone();
        let previous_signatures = self
            .last_scan_signatures
            .read()
            .unwrap_or_else(|e| e.into_inner())
            .clone();
        let mut all_songs: HashMap<PathBuf, Vec<LocalSong>> = HashMap::new();
        let mut all_fingerprints: HashMap<PathBuf, scanner::FileFingerprint> = HashMap::new();
        let mut failures = Vec::new();
        let mut signatures: HashMap<PathBuf, scanner::DirSignature> = HashMap::new();
        let mut missing = previous_missing
            .iter()
            .filter(|item| !item.path.exists())
            .cloned()
            .collect::<Vec<_>>();
        let mut errors = Vec::new();
        let previous_file_count = previous_fingerprints.len();
        let mut reused = 0;
        let mut parsed = 0;
        let mut skipped = 0;

        for path_str in paths {
            // 取消检查点：每个根目录处理前退出。取消 = 本次扫描不提交，
            // 已提交的曲库快照保持原样（§5.10 流程 4：可取消，不整体回滚）。
            if self.scan_cancelled() {
                self.scan_cancel.store(false, Ordering::SeqCst);
                self.last_scan_cancelled.store(true, Ordering::SeqCst);
                return errors;
            }
            let path = expand_path(path_str);
            // 单文件导入（§5.10 流程 2「选择文件」）：直接解析该文件。
            // 分组键落在父目录（canonical）——与目录扫描共享同一 root
            // 语义，之后对父目录的整目录扫描会按文件路径去重合并，
            // 不会产生重复记录（§8.4:862）。
            if path.is_file() {
                let source_key = scanner::canonicalize_public(&path);
                let root = path
                    .parent()
                    .map(|parent| {
                        parent
                            .canonicalize()
                            .unwrap_or_else(|_| parent.to_path_buf())
                    })
                    .unwrap_or_else(|| source_key.clone());
                let mut report = scanner::scan_single_file(&path);
                let previously_known = previous_fingerprints.get(&source_key)
                    == report.fingerprints.get(&source_key)
                    && previous_songs.get(&root).is_some_and(|songs| {
                        songs.iter().any(|local| local.file_path == source_key)
                    });
                if previously_known {
                    // 指纹未变：计入复用，不重复计解析数。
                    reused += report.songs.len();
                } else {
                    parsed += report.parsed;
                }
                let mut merged = previous_songs.get(&root).cloned().unwrap_or_default();
                // 本次扫描覆盖的来源文件替换旧记录，其余保留。
                merged.retain(|local| !report.fingerprints.contains_key(&local.file_path));
                merged.extend(report.songs);
                all_songs.insert(root, merged);
                all_fingerprints.extend(report.fingerprints.drain());
                failures.extend(report.failures.into_iter().map(|failure| LocalScanFailure {
                    path: failure.path,
                    error: failure.error,
                }));
                continue;
            }
            if !path.exists() || !path.is_dir() {
                errors.push(format!("目录不存在: {}", path_str));
                let root = path.canonicalize().unwrap_or(path);
                if let Some(previous_root) = previous_songs.get(&root) {
                    missing.extend(previous_root.iter().map(|local| MissingLocalSong {
                        path: local.file_path.clone(),
                        song: local.song.clone(),
                    }));
                }
                continue;
            }

            let root = path.canonicalize().unwrap_or(path);
            // 无变化快路径：目录签名一致且本次没有任何变化证据时，直接
            // 沿用上次的歌曲与指纹，跳过全目录遍历。注意目录 mtime 只反映
            // 增删/重命名，不反映文件原地修改，因此监听器等“已知有变化”
            // 的调用方必须传 force 绕过此快路径。
            if !force
                && let (Some(previous), Some(current)) = (
                    previous_signatures.get(&root),
                    scanner::DirSignature::from_path(&root),
                )
                && *previous == current
                && previous_songs.contains_key(&root)
            {
                // 歌曲与指纹都不在这里复制：它们未变化，交给循环结束后的补全
                // 逻辑从快照里各搬一次（旧代码会先把整库深拷贝一遍）。
                reused += previous_songs[&root].len();
                signatures.insert(root, current);
                continue;
            }

            // 复用映射按来源文件分组：普通歌曲一对一，一个 CUE 文件对应
            // 它的全部分轨。CUE 轨与整轨歌曲不再共用音频路径做 key。
            let mut previous: HashMap<PathBuf, Vec<LocalSong>> = HashMap::new();
            for local in previous_songs.get(&root).into_iter().flatten() {
                previous
                    .entry(local.file_path.clone())
                    .or_default()
                    .push(local.clone());
            }
            let previous_root_fingerprints = previous
                .keys()
                .filter_map(|file| {
                    previous_fingerprints
                        .get(file)
                        .copied()
                        .map(|fingerprint| (file.clone(), fingerprint))
                })
                .collect::<HashMap<_, _>>();
            let report = scanner::scan_directory_incremental(
                &root,
                max_depth,
                &previous,
                &previous_root_fingerprints,
                Some(&self.scan_cancel),
            );
            let songs = report.songs;
            let count = songs.len();
            let current_root_paths = report
                .fingerprints
                .keys()
                .cloned()
                .collect::<std::collections::HashSet<_>>();
            reused += report.reused;
            parsed += report.parsed;
            skipped += report.skipped;
            all_fingerprints.extend(report.fingerprints);
            failures.extend(report.failures.into_iter().map(|failure| LocalScanFailure {
                path: failure.path,
                error: failure.error,
            }));

            // Keep a lightweight record for files removed since the previous snapshot. This is
            // useful for playlists/history, where the path is still meaningful to the user.
            if let Some(previous_root) = previous_songs.get(&root) {
                for local in previous_root {
                    if !current_root_paths.contains(&local.file_path) && !local.file_path.exists() {
                        missing.push(MissingLocalSong {
                            path: local.file_path.clone(),
                            song: local.song.clone(),
                        });
                    }
                }
            }

            let signature = scanner::DirSignature::from_path(&root);
            if let Some(signature) = signature {
                signatures.insert(root.clone(), signature);
            }
            all_songs.insert(root, songs);
            if count > 0 {
                tracing::info!("扫描本地音乐: {} 首 ({})", count, path_str);
            }
        }

        if self.scan_generation.load(Ordering::SeqCst) != generation {
            return errors;
        }
        // 补全本次没有重扫的根目录（未纳入 paths 的旧目录、命中快路径的目录、
        // 以及临时不可用的目录）与它们的指纹、目录签名，保持快照内容与旧实现
        // 完全一致；只有这里会复制未变化的条目，且每个条目只复制一次。
        for (root, songs) in previous_songs.iter() {
            if !all_songs.contains_key(root) {
                all_songs.insert(root.clone(), songs.clone());
            }
        }
        for (file, fingerprint) in previous_fingerprints.iter() {
            if !all_fingerprints.contains_key(file) {
                all_fingerprints.insert(file.clone(), *fingerprint);
            }
        }
        for (root, signature) in previous_signatures {
            signatures.entry(root).or_insert(signature);
        }
        let present = all_fingerprints
            .keys()
            .cloned()
            .collect::<std::collections::HashSet<_>>();
        *self.scan_stats.write().unwrap_or_else(|e| e.into_inner()) = LocalScanStats {
            discovered: all_fingerprints.len(),
            reused,
            parsed,
            failed: failures.len(),
            removed: previous_file_count.saturating_sub(all_fingerprints.len()),
            skipped,
        };
        // 扫描提交点持久化曲库缓存（§8.4：重启后仍在）。新文件的首次
        // 发现时间在这里补记，为「最近添加」排序预留。写失败只记日志。
        // 写盘在快照 move 进各锁之前完成，直接借用本地集合，不额外克隆。
        if let Some(cache_path) = &self.cache_path {
            let now = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map(|value| value.as_secs() as i64)
                .unwrap_or_default();
            {
                let mut first_seen = self.first_seen.write().unwrap_or_else(|e| e.into_inner());
                for file in all_fingerprints.keys() {
                    first_seen.entry(file.clone()).or_insert(now);
                }
            }
            let first_seen = self.first_seen.read().unwrap_or_else(|e| e.into_inner());
            let loaded: Vec<PathBuf> = paths.iter().map(|path| expand_path(path)).collect();
            cache::store(
                cache_path,
                &loaded,
                &all_songs,
                &all_fingerprints,
                &failures,
                &first_seen,
            );
        }
        *self.songs.write().unwrap_or_else(|e| e.into_inner()) = Arc::new(all_songs);
        *self.fingerprints.write().unwrap_or_else(|e| e.into_inner()) = Arc::new(all_fingerprints);
        *self.failures.write().unwrap_or_else(|e| e.into_inner()) = Arc::new(failures);
        missing.retain(|item| !present.contains(&item.path));
        *self.missing.write().unwrap_or_else(|e| e.into_inner()) =
            Arc::new(deduplicate_missing(missing));
        *self
            .last_scan_signatures
            .write()
            .unwrap_or_else(|e| e.into_inner()) = signatures;
        *self.loaded_paths.write().unwrap_or_else(|e| e.into_inner()) =
            paths.iter().map(|path| expand_path(path)).collect();
        self.library_generation.fetch_add(1, Ordering::Release);

        if errors.is_empty() {
            let total: usize = self
                .songs
                .read()
                .unwrap_or_else(|e| e.into_inner())
                .values()
                .map(|v| v.len())
                .sum();
            tracing::info!("本地音乐扫描完成，共 {} 首", total);
        }

        errors
    }

    /// 获取所有本地歌曲
    pub fn all_songs(&self) -> Vec<SongInfo> {
        self.songs
            .read()
            .unwrap_or_else(|e| e.into_inner())
            .values()
            .flat_map(|songs| songs.iter().map(|s| s.song.clone()))
            .collect()
    }

    pub fn song_count(&self) -> usize {
        self.songs
            .read()
            .unwrap_or_else(|e| e.into_inner())
            .values()
            .map(Vec::len)
            .sum()
    }

    /// 从当前扫描结果中移除一个文件，避免异步复扫完成前仍显示已删除歌曲。
    pub fn remove_by_path(&self, path: &Path) -> bool {
        let canonical = path.canonicalize().unwrap_or_else(|_| path.to_path_buf());
        let mut songs_guard = self.songs.write().unwrap_or_else(|e| e.into_inner());
        let groups = Arc::make_mut(&mut songs_guard);
        let mut removed = false;
        for songs in groups.values_mut() {
            let previous_len = songs.len();
            // 除来源文件外，还按播放路径匹配：删除整轨音频时，引用它的
            // CUE 分轨（来源是 CUE 文件）也必须一并移除。
            songs.retain(|song| {
                song.file_path != path
                    && song.file_path != canonical
                    && song.song.file_path.as_deref() != Some(path)
                    && song.song.file_path != Some(canonical.clone())
            });
            removed |= songs.len() != previous_len;
        }
        groups.retain(|_, songs| !songs.is_empty());
        if removed {
            // 让目录签名失效，下一次扫描必须重新遍历目录，否则无变化
            // 快路径会把刚才删除的文件带回来。
            let root = path
                .canonicalize()
                .or_else(|_| canonical.canonicalize())
                .unwrap_or_else(|_| canonical.clone());
            let mut signatures = self
                .last_scan_signatures
                .write()
                .unwrap_or_else(|e| e.into_inner());
            if let Some(root_key) = signatures.keys().find(|key| root.starts_with(key)).cloned() {
                signatures.remove(&root_key);
            } else {
                signatures.remove(&root);
            }
            let mut fingerprints_guard =
                self.fingerprints.write().unwrap_or_else(|e| e.into_inner());
            let fingerprints = Arc::make_mut(&mut fingerprints_guard);
            fingerprints.remove(path);
            fingerprints.remove(&canonical);
            let mut failures_guard = self.failures.write().unwrap_or_else(|e| e.into_inner());
            Arc::make_mut(&mut failures_guard)
                .retain(|failure| failure.path != path && failure.path != canonical);
            let mut missing_guard = self.missing.write().unwrap_or_else(|e| e.into_inner());
            Arc::make_mut(&mut missing_guard)
                .retain(|missing| missing.path != path && missing.path != canonical);
        }
        removed
    }

    /// 根据路径查找歌曲
    pub fn find_by_path(&self, path: &PathBuf) -> Option<SongInfo> {
        for songs in self
            .songs
            .read()
            .unwrap_or_else(|e| e.into_inner())
            .values()
        {
            if let Some(s) = songs.iter().find(|s| &s.file_path == path) {
                return Some(s.song.clone());
            }
        }
        None
    }

    /// 使用 lofty 将标签/封面写回文件，并立即刷新内存中的歌曲元数据。
    pub fn edit_metadata(&self, path: &Path, edit: &MetadataEdit) -> Result<SongInfo, String> {
        metadata::write_metadata(path, edit)?;
        let mut song = metadata::read_metadata(path)?;
        let canonical = path.canonicalize().unwrap_or_else(|_| path.to_path_buf());
        song.file_path = Some(canonical.clone());
        let mut songs_guard = self.songs.write().unwrap_or_else(|e| e.into_inner());
        let groups = Arc::make_mut(&mut songs_guard);
        for songs in groups.values_mut() {
            if let Some(local) = songs.iter_mut().find(|local| local.file_path == canonical) {
                local.song = song.clone();
            }
        }
        Ok(song)
    }

    /// 获取已加载的目录
    pub fn loaded_paths(&self) -> Vec<PathBuf> {
        self.loaded_paths
            .read()
            .unwrap_or_else(|e| e.into_inner())
            .clone()
    }

    /// 增量刷新当前已加载目录，不改变目录配置。
    pub fn refresh(&self, max_depth: u32) -> Vec<String> {
        let paths = self
            .loaded_paths()
            .into_iter()
            .map(|path| path.to_string_lossy().into_owned())
            .collect::<Vec<_>>();
        self.scan(&paths, max_depth)
    }

    /// 最近一次扫描中无法解析的文件。
    pub fn scan_failures(&self) -> Vec<LocalScanFailure> {
        (**self.failures.read().unwrap_or_else(|e| e.into_inner())).clone()
    }

    /// 最近一次扫描统计。
    pub fn scan_stats(&self) -> LocalScanStats {
        *self.scan_stats.read().unwrap_or_else(|e| e.into_inner())
    }

    /// 与 `scan_failures` 等价的便捷别名，便于页面按“损坏文件”语义读取。
    pub fn corrupt_files(&self) -> Vec<LocalScanFailure> {
        self.scan_failures()
    }

    /// 最近一次扫描中从文件系统消失的歌曲。
    pub fn missing_songs(&self) -> Vec<MissingLocalSong> {
        (**self.missing.read().unwrap_or_else(|e| e.into_inner())).clone()
    }

    /// 最近一次扫描中无法解析的文件数量（供界面渲染，避免整表克隆）。
    pub fn failure_count(&self) -> usize {
        self.failures
            .read()
            .unwrap_or_else(|e| e.into_inner())
            .len()
    }

    /// 最近一次扫描中从文件系统消失的歌曲数量（供界面渲染，避免整表克隆）。
    pub fn missing_count(&self) -> usize {
        self.missing.read().unwrap_or_else(|e| e.into_inner()).len()
    }

    /// 与 `missing_songs` 等价的便捷别名。
    pub fn missing_files(&self) -> Vec<MissingLocalSong> {
        self.missing_songs()
    }

    /// 返回疑似重复歌曲。重复判定基于规范化的标题、歌手、专辑和时长，
    /// 不需要读取整个音频文件，适合在界面中即时展示。
    pub fn duplicate_groups(&self) -> Vec<DuplicateLocalSongs> {
        let mut groups: HashMap<String, Vec<SongInfo>> = HashMap::new();
        for song in self.all_songs() {
            groups.entry(duplicate_key(&song)).or_default().push(song);
        }
        let mut duplicates = groups
            .into_iter()
            .filter(|(_, songs)| songs.len() > 1)
            .map(|(key, mut songs)| {
                songs.sort_by(|a, b| a.file_path.cmp(&b.file_path));
                DuplicateLocalSongs { key, songs }
            })
            .collect::<Vec<_>>();
        duplicates.sort_by(|a, b| a.key.cmp(&b.key));
        duplicates
    }

    /// 与 `duplicate_groups` 等价的便捷别名。
    pub fn duplicates(&self) -> Vec<DuplicateLocalSongs> {
        self.duplicate_groups()
    }

    /// 最近一次监听器更新的序号。序号变化时，调用者应重新读取 `all_songs()`。
    pub fn watch_generation(&self) -> u64 {
        self.watch_generation.load(Ordering::Acquire)
    }

    /// 启动跨平台文件系统监听器。
    ///
    /// `notify` 负责接收原生创建/删除/修改事件，收到一批事件后再调用增量扫描；
    /// 未变化的文件仍由指纹缓存复用。重复调用会停止旧监听器。
    pub fn start_watcher(
        self: &Arc<Self>,
        paths: Vec<String>,
        max_depth: u32,
        interval: Duration,
    ) -> Result<(), String> {
        self.stop_watcher();
        if paths.is_empty() {
            return Ok(());
        }
        let stop = Arc::new(std::sync::atomic::AtomicBool::new(false));
        let stop_thread = Arc::clone(&stop);
        let (wake_tx, wake_rx) = mpsc::channel();
        let (event_tx, event_rx) = mpsc::channel::<notify::Result<notify::Event>>();
        let mut fs_watcher = recommended_watcher(move |event: notify::Result<notify::Event>| {
            if matches!(&event, Ok(event) if is_non_mutating_access(event)) {
                return;
            }
            let _ = event_tx.send(event);
        })
        .map_err(|error| format!("创建文件监听器失败: {error}"))?;
        for path in &paths {
            let path = expand_path(path);
            if path.is_dir() {
                fs_watcher
                    .watch(&path, RecursiveMode::Recursive)
                    .map_err(|error| format!("监听目录 {} 失败: {error}", path.display()))?;
            }
        }
        let weak = Arc::downgrade(self);
        let interval = interval.max(Duration::from_millis(250));
        let initial_paths = paths.clone();
        let join = thread::spawn(move || {
            // 调用方（扫描动作）通常已经完成一次扫描；此时 loaded_paths 非空，
            // 跳过线程内的初始扫描，避免同一份目录同时跑两遍扫描把内存峰值翻倍。
            // 仅在从未扫描过时补一次初始扫描，让监听器先于首次显式扫描也能工作。
            if let Some(source) = weak.upgrade()
                && source.loaded_paths().is_empty()
            {
                let generation = source.begin_scan();
                let _ = source.scan_for_generation(&initial_paths, max_depth, generation, false);
            }
            while !stop_thread.load(Ordering::Acquire) {
                if wake_rx.try_recv().is_ok() {
                    break;
                }
                match event_rx.recv_timeout(interval) {
                    Ok(Ok(_event)) => {
                        // Coalesce editor save bursts into one scan.
                        while event_rx.try_recv().is_ok() {}
                    }
                    Ok(Err(error)) => {
                        tracing::warn!("本地文件监听失败: {error}");
                        continue;
                    }
                    Err(mpsc::RecvTimeoutError::Timeout) => continue,
                    Err(mpsc::RecvTimeoutError::Disconnected) => break,
                }
                if stop_thread.load(Ordering::Acquire) {
                    break;
                }
                let Some(source) = weak.upgrade() else {
                    break;
                };
                // 文件系统事件本身就是“有变化”的证据；目录签名探测不到
                // 原地修改（不改变目录 mtime），必须强制重新遍历。未变化
                // 的文件仍由指纹缓存复用，代价可控。
                let generation = source.begin_scan();
                let _ = source.scan_for_generation(&paths, max_depth, generation, true);
                source.watch_generation.fetch_add(1, Ordering::AcqRel);
            }
            drop(fs_watcher);
            let _ = wake_rx;
        });
        *self.watcher.lock().unwrap_or_else(|e| e.into_inner()) = Some(WatcherHandle {
            stop,
            wake: wake_tx,
            join: Some(join),
        });
        Ok(())
    }

    /// 停止目录监听器。
    pub fn stop_watcher(&self) {
        self.watcher
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .take();
    }
}

/// 判断事件是否为非破坏性访问，避免监听器自激。
fn is_non_mutating_access(event: &notify::Event) -> bool {
    matches!(
        event.kind,
        EventKind::Access(AccessKind::Close(AccessMode::Read))
            | EventKind::Access(AccessKind::Open(_))
            | EventKind::Access(AccessKind::Read)
    )
}

impl Drop for LocalSource {
    fn drop(&mut self) {
        // WatcherHandle 的 Drop 会停止并 join 线程。
        let _ = self.watcher.get_mut().ok().and_then(Option::take);
    }
}

fn deduplicate_missing(mut missing: Vec<MissingLocalSong>) -> Vec<MissingLocalSong> {
    let mut seen = std::collections::HashSet::new();
    missing.retain(|item| seen.insert(item.path.clone()));
    missing.sort_by(|a, b| a.path.cmp(&b.path));
    missing
}

fn duplicate_key(song: &SongInfo) -> String {
    let normalize = |value: &str| {
        value
            .split_whitespace()
            .collect::<Vec<_>>()
            .join(" ")
            .to_lowercase()
    };
    format!(
        "{}\u{1f}{}\u{1f}{}\u{1f}{}",
        normalize(&song.name),
        normalize(&song.singer),
        normalize(&song.album_name),
        song.duration.as_millis()
    )
}

struct ScanCompletion<'a> {
    source: &'a LocalSource,
    generation: u64,
}

impl Drop for ScanCompletion<'_> {
    fn drop(&mut self) {
        let _ = self.source.scan_in_progress.compare_exchange(
            self.generation,
            0,
            Ordering::SeqCst,
            Ordering::SeqCst,
        );
    }
}

#[async_trait]
impl MusicSource for LocalSource {
    fn id(&self) -> SourceId {
        SourceId::Local
    }

    fn name(&self) -> &str {
        "本地音乐"
    }

    async fn search(
        &self,
        keyword: &str,
        page: u32,
        limit: u32,
    ) -> Result<SearchResult, SearchError> {
        let all = self.all_songs();
        let keyword = keyword.to_lowercase();

        let matching: Vec<SongInfo> = if keyword.is_empty() {
            all
        } else {
            all.into_iter()
                .filter(|s| {
                    s.name.to_lowercase().contains(&keyword)
                        || s.singer.to_lowercase().contains(&keyword)
                        || s.album_name.to_lowercase().contains(&keyword)
                })
                .collect()
        };
        let total = matching.len();
        let limit = limit.max(1) as usize;
        let start = page.saturating_sub(1) as usize * limit;
        let items = matching.into_iter().skip(start).take(limit).collect();

        Ok(SearchResult {
            total: total as u32,
            has_more: start.saturating_add(limit) < total,
            items,
        })
    }

    async fn get_song_url(
        &self,
        song: &SongInfo,
        _quality: Quality,
    ) -> Result<SongUrl, FetchError> {
        if let Some(url) = song.extra.get("import_url")
            && (url.starts_with("http://") || url.starts_with("https://"))
        {
            return Ok(SongUrl {
                url: url.clone(),
                quality: song
                    .qualities
                    .iter()
                    .next_back()
                    .copied()
                    .unwrap_or(Quality::High320),
                duration: song.duration,
                cover_url: song.cover_url.clone(),
                qualities: song.qualities.iter().copied().collect(),
                headers: vec![],
                size: None,
                size_is_advisory: false,
                md5: None,
                candidate_urls: vec![],
                max_chunk_size: 0,
            });
        }
        let path = match song.file_path.as_ref() {
            Some(p) => p.clone(),
            None => {
                let p = PathBuf::from(&song.id);
                if p.exists() {
                    p
                } else {
                    return Err(FetchError::NotFound);
                }
            }
        };

        let qualities: Vec<Quality> = song.qualities.iter().copied().collect();

        Ok(SongUrl {
            url: path.to_string_lossy().to_string(),
            quality: qualities.last().copied().unwrap_or(Quality::High320),
            duration: song.duration,
            cover_url: song.cover_url.clone(),
            qualities,
            headers: vec![],
            size: None,
            size_is_advisory: false,
            md5: None,
            candidate_urls: vec![],
            max_chunk_size: 0,
        })
    }

    async fn get_lyric(&self, song: &SongInfo) -> Result<LyricData, FetchError> {
        let audio_path = song.file_path.clone().or_else(|| {
            let path = PathBuf::from(&song.id);
            path.exists().then_some(path)
        });

        if let Some(audio_path) = audio_path {
            let content = tokio::task::spawn_blocking(move || read_local_lyric(&audio_path))
                .await
                .map_err(|error| FetchError::Other(format!("读取本地歌词任务失败: {error}")))?;
            if let Some(content) = content {
                return Ok(LyricData {
                    lyric: content,
                    ..Default::default()
                });
            }
        }
        Ok(LyricData::default())
    }

    async fn get_cover_url(&self, song: &SongInfo) -> Result<String, FetchError> {
        if let Some(cover) = &song.cover_url {
            return Ok(cover.clone());
        }
        Err(FetchError::NotFound)
    }

    /// 本地文件的规格由文件本身决定，四个档位都可能出现
    fn supported_qualities(&self) -> Vec<Quality> {
        QUALITY_ORDER.to_vec()
    }
}

impl Default for LocalSource {
    fn default() -> Self {
        Self::new()
    }
}

fn expand_path(value: &str) -> PathBuf {
    if let Some(relative) = value.strip_prefix("~/")
        && let Some(home) = dirs::home_dir()
    {
        return home.join(relative);
    }
    PathBuf::from(value)
}

fn read_local_lyric(audio_path: &Path) -> Option<String> {
    let lrc_path = audio_path.with_extension("lrc");
    if let Some(content) = read_text_file(&lrc_path)
        && !content.trim().is_empty()
    {
        return Some(content);
    }
    metadata::read_embedded_lyric(audio_path).ok().flatten()
}

/// 读取文本文件。UTF-8 解析失败时降级用 GB18030 解码，兼容 GBK 编码的外挂歌词。
fn read_text_file(path: &Path) -> Option<String> {
    let bytes = std::fs::read(path).ok()?;
    match String::from_utf8(bytes) {
        Ok(content) => Some(content),
        Err(error) => {
            let (content, _, _) = encoding_rs::GB18030.decode(error.as_bytes());
            tracing::warn!(
                "外挂歌词不是有效 UTF-8，已用 GB18030 降级解码: {}",
                path.display()
            );
            Some(content.into_owned())
        }
    }
}

#[cfg(test)]
mod tests {
    use std::collections::HashMap;
    use std::path::PathBuf;
    use std::sync::Arc;

    use lx_core::model::song::SongInfo;
    use lx_core::model::source::SourceId;

    use super::{LocalSong, LocalSource, MissingLocalSong, scanner};

    #[test]
    fn stale_scan_cannot_replace_newer_paths() {
        let source = LocalSource::new();
        let stale_generation = source.begin_scan();
        let current_generation = source.begin_scan();

        source.scan_for_generation(&[], 0, current_generation, false);
        source.scan_for_generation(&[".".to_string()], 0, stale_generation, false);

        assert!(source.loaded_paths().is_empty());
        assert!(!source.is_scanning());
    }

    #[test]
    fn stale_scan_completion_does_not_clear_newer_scan_state() {
        let source = LocalSource::new();
        let stale_generation = source.begin_scan();
        let current_generation = source.begin_scan();

        source.scan_for_generation(&[], 0, stale_generation, false);
        assert!(source.is_scanning());

        source.scan_for_generation(&[], 0, current_generation, false);
        assert!(!source.is_scanning());
    }

    #[test]
    fn deleted_file_is_removed_from_the_current_library_snapshot() {
        let source = LocalSource::new();
        let path = PathBuf::from("/music/removed.mp3");
        let mut song = SongInfo::new(
            path.to_string_lossy().into_owned(),
            SourceId::Local,
            "removed".to_string(),
            "artist".to_string(),
        );
        song.file_path = Some(path.clone());
        Arc::make_mut(&mut *source.songs.write().unwrap_or_else(|e| e.into_inner())).insert(
            PathBuf::from("/music"),
            vec![LocalSong {
                song,
                file_path: path.clone(),
            }],
        );

        assert!(source.remove_by_path(&path));
        assert!(source.all_songs().is_empty());
        assert!(
            source
                .songs
                .read()
                .unwrap_or_else(|e| e.into_inner())
                .is_empty()
        );
        assert!(!source.remove_by_path(&path));
    }

    #[test]
    fn duplicate_groups_use_normalized_metadata() {
        let source = LocalSource::new();
        let mut first = SongInfo::new(
            "/music/one.flac".to_string(),
            SourceId::Local,
            "  Song  ".to_string(),
            "Artist".to_string(),
        );
        first.album_name = "Album".to_string();
        first.duration = std::time::Duration::from_secs(180);
        first.file_path = Some(PathBuf::from("/music/one.flac"));
        let mut second = first.clone();
        second.id = "/music/two.flac".to_string();
        second.file_path = Some(PathBuf::from("/music/two.flac"));
        Arc::make_mut(&mut *source.songs.write().unwrap_or_else(|e| e.into_inner())).insert(
            PathBuf::from("/music"),
            vec![
                LocalSong {
                    song: first,
                    file_path: PathBuf::from("/music/one.flac"),
                },
                LocalSong {
                    song: second,
                    file_path: PathBuf::from("/music/two.flac"),
                },
            ],
        );

        let groups = source.duplicate_groups();
        assert_eq!(groups.len(), 1);
        assert_eq!(groups[0].songs.len(), 2);
    }

    #[test]
    fn missing_entries_are_deduplicated() {
        let source = LocalSource::new();
        let path = PathBuf::from("/music/gone.flac");
        let song = SongInfo::new(
            path.to_string_lossy().into_owned(),
            SourceId::Local,
            "gone".to_string(),
            "artist".to_string(),
        );
        *source.missing.write().unwrap_or_else(|e| e.into_inner()) = Arc::new(vec![
            MissingLocalSong {
                path: path.clone(),
                song: song.clone(),
            },
            MissingLocalSong { path, song },
        ]);
        // A refresh with no configured paths still keeps the diagnostic until the path returns.
        source.scan(&[], 0);
        assert_eq!(source.missing_files().len(), 1);
    }

    #[test]
    fn incremental_reuse_keeps_every_song_from_the_same_source_file() {
        // 整轨歌曲与其 CUE 分轨共用同一音频路径；复用映射必须按来源文件
        // 分组保留全部条目，而不是互相顶替只剩一条。
        let dir = std::env::temp_dir().join(format!(
            "voicefox-reuse-{}-{}",
            std::process::id(),
            std::thread::current().name().unwrap_or("test")
        ));
        std::fs::create_dir_all(&dir).unwrap();
        let audio = dir.join("album.flac");
        std::fs::write(&audio, b"stub").unwrap();

        let fingerprint = scanner::FileFingerprint::from_path(&audio).unwrap();
        let make_song = |id: &str| {
            let mut song = SongInfo::new(
                id.to_string(),
                SourceId::Local,
                id.to_string(),
                "artist".to_string(),
            );
            song.file_path = Some(audio.clone());
            LocalSong {
                song,
                file_path: audio.clone(),
            }
        };
        let previous = HashMap::from([(
            audio.clone(),
            vec![make_song("album.flac"), make_song("album.flac#01")],
        )]);
        let previous_fingerprints = HashMap::from([(audio.clone(), fingerprint)]);

        let report =
            scanner::scan_directory_incremental(&dir, 0, &previous, &previous_fingerprints, None);

        assert_eq!(report.reused, 2);
        assert_eq!(report.songs.len(), 2);
        assert!(
            report
                .songs
                .iter()
                .any(|local| local.song.id == "album.flac#01")
        );

        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn deleting_the_audio_file_also_removes_its_cue_tracks() {
        let source = LocalSource::new();
        let audio = PathBuf::from("/music/album.flac");
        let cue = PathBuf::from("/music/album.cue");
        let mut track = SongInfo::new(
            "/music/album.cue#01".to_string(),
            SourceId::Local,
            "track".to_string(),
            "artist".to_string(),
        );
        track.file_path = Some(audio.clone());
        Arc::make_mut(&mut *source.songs.write().unwrap_or_else(|e| e.into_inner())).insert(
            PathBuf::from("/music"),
            vec![LocalSong {
                song: track,
                // CUE 轨的来源文件是 CUE 文件本身，播放路径在 song.file_path
                file_path: cue,
            }],
        );

        assert!(source.remove_by_path(&audio));
        assert!(source.all_songs().is_empty());
    }

    #[test]
    fn forced_scan_bypasses_the_unchanged_directory_fast_path() {
        // 目录签名不反映文件原地修改；force 必须绕过快路径重新遍历，
        // 否则修改后的文件状态（这里表现为解析失败清单）永远不会更新。
        let dir = std::env::temp_dir().join(format!(
            "voicefox-force-{}-{}",
            std::process::id(),
            std::thread::current().name().unwrap_or("test")
        ));
        std::fs::create_dir_all(&dir).unwrap();
        let audio = dir.join("broken.flac");
        std::fs::write(&audio, b"first version").unwrap();

        let source = LocalSource::new();
        let paths = vec![dir.to_string_lossy().into_owned()];
        let generation = source.begin_scan();
        source.scan_for_generation(&paths, 0, generation, false);
        assert_eq!(source.scan_failures().len(), 1, "首次扫描应记录损坏文件");

        // 原地修改文件内容：目录签名不变，快路径会整体沿用旧结果，
        // 连失败清单都被跳过。
        std::fs::write(&audio, b"second version with different size").unwrap();
        let generation = source.begin_scan();
        source.scan_for_generation(&paths, 0, generation, false);
        assert!(source.scan_failures().is_empty(), "快路径应跳过遍历");

        let generation = source.begin_scan();
        source.scan_for_generation(&paths, 0, generation, true);
        assert_eq!(source.scan_failures().len(), 1, "force 后应重新解析该文件");

        std::fs::remove_dir_all(&dir).ok();
    }

    /// 合成一段可被 lofty 解析的最小 PCM WAV（§5.10 导入端到端夹具）。
    fn write_wav(path: &std::path::Path) {
        let sample_rate = 8000u32;
        let samples = 800usize;
        let data_len = (samples * 2) as u32;
        let mut bytes: Vec<u8> = Vec::new();
        bytes.extend_from_slice(b"RIFF");
        bytes.extend_from_slice(&(36 + data_len).to_le_bytes());
        bytes.extend_from_slice(b"WAVE");
        bytes.extend_from_slice(b"fmt ");
        bytes.extend_from_slice(&16u32.to_le_bytes());
        bytes.extend_from_slice(&1u16.to_le_bytes());
        bytes.extend_from_slice(&1u16.to_le_bytes());
        bytes.extend_from_slice(&sample_rate.to_le_bytes());
        bytes.extend_from_slice(&(sample_rate * 2).to_le_bytes());
        bytes.extend_from_slice(&2u16.to_le_bytes());
        bytes.extend_from_slice(&16u16.to_le_bytes());
        bytes.extend_from_slice(b"data");
        bytes.extend_from_slice(&data_len.to_le_bytes());
        for index in 0..samples {
            let t = index as f32 / sample_rate as f32;
            let value = (t * 440.0 * 2.0 * std::f32::consts::PI).sin() * 8000.0;
            bytes.extend_from_slice(&(value as i16).to_le_bytes());
        }
        std::fs::write(path, bytes).unwrap();
    }

    fn scratch_dir(tag: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!(
            "voicefox-local-{}-{}-{}",
            tag,
            std::process::id(),
            std::thread::current()
                .name()
                .unwrap_or("t")
                .replace("::", "_")
        ));
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn ten_thousand_files_rescan_reuses_fingerprints_without_reparsing() {
        let dir = scratch_dir("10k");
        for index in 0..10_000 {
            write_wav(&dir.join(format!("track-{index:05}.wav")));
        }
        let source = LocalSource::new();
        source.scan(&[dir.display().to_string()], 0);
        let first = source.scan_stats();
        assert_eq!(first.discovered, 10_000, "首轮应发现全部文件");
        assert_eq!(first.parsed, 10_000, "首轮全部需解析");

        // 复扫：目录签名未变 → 快路径整组复用；10k 条可用性契约
        // reused==10000 / parsed==0。
        source.scan(&[dir.display().to_string()], 0);
        let second = source.scan_stats();
        assert_eq!(second.reused, 10_000);
        assert_eq!(second.parsed, 0);
        assert_eq!(source.all_songs().len(), 10_000);
        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn cancelled_scan_keeps_last_committed_snapshot() {
        let dir = scratch_dir("cancel");
        write_wav(&dir.join("a.wav"));
        let source = LocalSource::new();
        source.scan(&[dir.display().to_string()], 0);
        let before = source.all_songs().len();
        assert_eq!(before, 1);

        // 取消下一次扫描：检查点提前返回，已提交结果不回滚。
        let generation = source.begin_scan();
        source.cancel_scan();
        let errors = source.scan_for_generation(&[dir.display().to_string()], 0, generation, false);
        assert!(errors.is_empty());
        assert!(source.last_scan_was_cancelled());
        assert_eq!(source.all_songs().len(), before, "取消后曲库快照不变");
        assert!(!source.is_scanning());
        assert_eq!(source.loaded_paths().len(), 1, "保留上一次提交的目录集");

        // 取消标志已消费：下一次扫描正常提交。
        source.scan(&[dir.display().to_string()], 0);
        assert!(!source.last_scan_was_cancelled());
        assert_eq!(source.all_songs().len(), 1);
        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn single_file_import_groups_under_parent_and_rescan_does_not_duplicate() {
        let dir = scratch_dir("single-file");
        write_wav(&dir.join("one.wav"));
        write_wav(&dir.join("two.wav"));
        let source = LocalSource::new();

        // 单文件导入 one.wav：分组键 = 父目录 canonical。
        source.scan(&[dir.join("one.wav").display().to_string()], 0);
        assert_eq!(source.all_songs().len(), 1);
        let paths = source.loaded_paths();
        assert_eq!(paths.len(), 1);
        assert!(paths[0].is_file(), "loaded_paths 记录文件路径本身");

        // 再导入同目录 two.wav：与 one.wav 合并在同一父目录组，不互顶。
        source.scan(&[dir.join("two.wav").display().to_string()], 0);
        assert_eq!(source.all_songs().len(), 2);

        // 重扫父目录：目录扫描覆盖同组，指纹复用，不产生重复记录（§8.4:862）。
        let stats = {
            source.scan(&[dir.display().to_string()], 0);
            source.scan_stats()
        };
        assert_eq!(source.all_songs().len(), 2, "目录重扫不得重复建记录");
        assert_eq!(stats.reused, 2);
        assert_eq!(stats.parsed, 0);
        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn library_cache_survives_restart_and_enables_incremental_rescan() {
        let dir = scratch_dir("cache");
        write_wav(&dir.join("a.wav"));
        write_wav(&dir.join("b.wav"));
        let cache = dir.join("local_library.json");
        let paths = vec![dir.display().to_string()];

        {
            let source = LocalSource::with_cache_path(cache.clone());
            source.scan(&paths, 0);
            assert_eq!(source.all_songs().len(), 2);
        }
        assert!(cache.exists(), "扫描提交点应写缓存");

        // 「重启」：新构造同步加载缓存，local_songs 快照非空。
        let restarted = LocalSource::with_cache_path(cache.clone());
        assert_eq!(
            restarted.all_songs().len(),
            2,
            "构造内同步加载，首帧快照即非空"
        );
        assert_eq!(restarted.loaded_paths().len(), 1);

        // 重扫走指纹增量：不重新解析。
        restarted.scan(&paths, 0);
        let stats = restarted.scan_stats();
        assert_eq!(stats.reused, 2);
        assert_eq!(stats.parsed, 0);

        // 磁盘漂移：源文件消失的歌曲不进快照，缓存文件本身保留。
        std::fs::remove_file(dir.join("b.wav")).unwrap();
        let drifted = LocalSource::with_cache_path(cache.clone());
        assert_eq!(drifted.all_songs().len(), 1);
        assert_eq!(drifted.missing_songs().len(), 1);
        assert!(cache.exists(), "漂移不静默删用户数据，修复走下次扫描");
        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn skipped_counts_non_audio_files() {
        let dir = scratch_dir("skipped");
        write_wav(&dir.join("a.wav"));
        std::fs::write(dir.join("cover.jpg"), b"image").unwrap();
        std::fs::write(dir.join("notes.txt"), b"notes").unwrap();
        let source = LocalSource::new();
        source.scan(&[dir.display().to_string()], 0);
        let stats = source.scan_stats();
        assert_eq!(stats.discovered, 1);
        assert_eq!(stats.skipped, 2, "非音频扩展名计入「无音频文件」列");
        std::fs::remove_dir_all(&dir).ok();
    }
}
