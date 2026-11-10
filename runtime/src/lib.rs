use async_trait::async_trait;
use lx_core::model::config::Config;
use lx_core::model::song::SongInfo;
use lx_core::model::source::{PlayerState, Quality};
use lx_core::traits::player::PlayerBackend;
use lx_lyric::service::LyricService;
use lx_source::manager::SourceManager;
use std::path::PathBuf;
use std::sync::{Arc, RwLock};
use voicefox_application::{ApplicationService, PlaybackEffects};

mod cover;
pub mod storage;
pub use cover::{CoverService, CoverState, is_usable_remote_url, sweep_temp_files};
pub use storage::{SavedPlayerState, Storage};
pub use voicefox_application::resolve_cover_url;

/// FFI 同步引导路径（无 ambient tokio）自建的进程级 runtime。
/// OnceLock 保证进程存活期持有：ApplicationRuntime 局部 drop 后泵任务仍存活
/// （ffi/src/lib.rs new_desktop/new_host 里的 ApplicationRuntime 是局部变量，
/// 函数返回即 drop；Arc 只存进去会在几秒后被 shutdown，泵刚启动就被取消）。
static OWNED_RUNTIME: std::sync::OnceLock<Arc<tokio::runtime::Runtime>> =
    std::sync::OnceLock::new();

/// 确保当前线程有 tokio 上下文（供 FFI 同步引导与测试复用）。
///
/// 返回 Some(guard) = 本线程原本没有 ambient runtime，已进入进程级 owned
/// multi-thread runtime（multi-thread flavor：泵任务里 advance_after_end 会
/// await 含同步 mpv FFI 与 JS 音源解析的 play 链，current_thread flavor 会
/// 把泵阻塞停摆）；返回 None = 已有 ambient runtime，调用方行为不变。
/// guard 必须活到所有 `tokio::spawn` / `Handle::try_current()` 调用点之后。
fn enter_sync_bootstrap_runtime() -> Option<tokio::runtime::EnterGuard<'static>> {
    if tokio::runtime::Handle::try_current().is_ok() {
        return None;
    }
    let runtime: &'static tokio::runtime::Runtime = OWNED_RUNTIME
        .get_or_init(|| {
            // GUI 引导没有 tracing subscriber：这条一次性日志直达 stderr，
            // 用于确认同步引导路径确实拿到了 tokio 上下文（P0-02 诊断锚点）。
            eprintln!("voicefox: 同步引导路径无 ambient tokio，已创建进程级 multi-thread runtime");
            Arc::new(
                tokio::runtime::Builder::new_multi_thread()
                    .enable_all()
                    .build()
                    .expect("build owned tokio runtime for FFI sync bootstrap"),
            )
        })
        .as_ref();
    Some(runtime.enter())
}

#[cfg(test)]
mod sync_bootstrap_tests {
    use super::*;

    /// P0-02 回归：纯同步线程（模拟 FRB NormalTask 的线程池直跑）调用
    /// enter_sync_bootstrap_runtime 后，`Handle::try_current()` 必须可用——
    /// 否则 ApplicationService::start_playback_pump 会静默 return，进度/时长
    /// 恒 0、Ended/播放错误事件无消费者。
    #[test]
    fn sync_bootstrap_path_provides_tokio_context() {
        std::thread::spawn(|| {
            assert!(
                tokio::runtime::Handle::try_current().is_err(),
                "前置条件：测试线程不应有 ambient tokio runtime"
            );
            let guard = enter_sync_bootstrap_runtime();
            assert!(
                tokio::runtime::Handle::try_current().is_ok(),
                "P0-02：同步引导路径必须提供 tokio 上下文，否则播放泵静默不启动"
            );
            drop(guard);
            // guard 释放只退出上下文，runtime 仍被 OnceLock 持有（泵任务存活）。
            assert!(OWNED_RUNTIME.get().is_some());
        })
        .join()
        .unwrap();
    }

    /// 有 ambient runtime 的调用方（FRB async 上下文 / TUI block_on）不受影响：
    /// 不进入 owned runtime，也不污染外部上下文。
    #[tokio::test]
    async fn ambient_runtime_path_is_untouched() {
        let outer = tokio::runtime::Handle::try_current().expect("tokio::test 提供上下文");
        let guard = enter_sync_bootstrap_runtime();
        assert!(guard.is_none(), "已有 ambient runtime 时不得再 enter");
        let inner = tokio::runtime::Handle::try_current().expect("上下文仍在");
        assert_eq!(outer.id(), inner.id(), "不得切换到 owned runtime");
    }
}

struct RuntimePlaybackEffects {
    storage: Arc<Storage>,
    cover: Arc<CoverService>,
    config: Arc<RwLock<Config>>,
}
#[async_trait]
impl PlaybackEffects for RuntimePlaybackEffects {
    fn existing_download(&self, song: &SongInfo) -> Option<PathBuf> {
        let c = self.config.read().unwrap_or_else(|e| e.into_inner());
        let dir = if c.download.dir.trim().is_empty() {
            dirs::download_dir().unwrap_or_else(|| PathBuf::from("."))
        } else {
            expand_home(&c.download.dir)
        };
        let stem = sanitize_filename(&format!("{} - {}", song.name, song.singer));
        ["mp3", "flac", "m4a", "aac", "ogg", "opus", "wav"]
            .iter()
            .map(|e| dir.join(format!("{stem}.{e}")))
            .find(|p| p.is_file())
    }
    fn record_history(&self, song: &SongInfo) {
        let n = self
            .config
            .read()
            .unwrap_or_else(|e| e.into_inner())
            .player
            .history_limit;
        self.storage.add_history(song, n)
    }
    fn prepare_cover(&self, song: &SongInfo, show: bool) -> Option<String> {
        if show
            && self
                .config
                .read()
                .unwrap_or_else(|e| e.into_inner())
                .ui
                .show_cover
        {
            song.cover_url.clone()
        } else {
            self.cover.clear();
            None
        }
    }
    async fn load_cover(&self, url: Option<String>) -> Result<(), String> {
        self.cover.load(url).await
    }
    async fn cache_cover(&self, url: Option<String>) -> Option<String> {
        self.cover.cache_path(url).await.ok().flatten()
    }
    fn cover_url_is_usable(&self, url: &str) -> bool {
        is_usable_remote_url(url)
    }
    fn album_cover_notification(&self) -> bool {
        self.config
            .read()
            .unwrap_or_else(|e| e.into_inner())
            .notification
            .album_cover
    }
    fn track_change_notification(&self) -> bool {
        self.config
            .read()
            .unwrap_or_else(|e| e.into_inner())
            .notification
            .track_change
    }
    fn fade_in_ms(&self) -> u64 {
        self.config
            .read()
            .unwrap_or_else(|e| e.into_inner())
            .player
            .fade_in_ms
    }
    fn quality(&self) -> Quality {
        self.config
            .read()
            .unwrap_or_else(|e| e.into_inner())
            .player
            .quality
    }
    fn auto_toggle(&self) -> bool {
        self.config
            .read()
            .unwrap_or_else(|e| e.into_inner())
            .source
            .auto_toggle
    }
}

pub struct ApplicationRuntime {
    application: ApplicationService,
    pub config: Arc<RwLock<Config>>,
    pub config_path: PathBuf,
    pub storage: Arc<Storage>,
    pub cover: Arc<CoverService>,
    pub player: Arc<dyn PlayerBackend>,
    pub sources: Arc<SourceManager>,
    pub lyrics: Arc<LyricService>,
}
impl ApplicationRuntime {
    pub fn from_parts(
        config: Config,
        config_path: PathBuf,
        player: Arc<dyn PlayerBackend>,
    ) -> anyhow::Result<Self> {
        lx_source::configure_network(&config.network.proxy_url, config.network.timeout);
        player.set_volume(config.player.volume);
        player.set_playback_speed(config.player.playback_speed);
        player.set_audio_output_device(&config.player.audio_device);
        let sources = Arc::new(SourceManager::new(
            config.source.default,
            &config.source.enabled,
        ));
        let lyrics = Arc::new(LyricService::new(Arc::new(
            lx_lyric::fetcher::SourceLyricFetcher::new(Arc::clone(&sources)),
        )));
        lyrics.set_translation_enabled(config.lyric.show_translation);
        lyrics.set_yrc_enabled(config.lyric.show_yrc);
        lyrics.set_offset_ms(config.lyric.offset);
        let storage = Arc::new(Storage::new());
        storage.trim_history(config.player.history_limit);
        let cover = Arc::new(CoverService::new(
            &config.network.proxy_url,
            config.network.timeout,
        ));
        let shared = Arc::new(RwLock::new(config.clone()));
        let effects: Arc<dyn PlaybackEffects> = Arc::new(RuntimePlaybackEffects {
            storage: Arc::clone(&storage),
            cover: Arc::clone(&cover),
            config: Arc::clone(&shared),
        });
        // FFI 同步引导路径（ffi new_desktop / new_host 都是同步 Rust 函数，经 FRB
        // NormalTask 在线程池直跑，见 flutter_rust_bridge 2.13.0
        // handler/implementation/executor.rs execute_sync）没有 ambient tokio 上下文：
        // 播放泵（ApplicationService::start_playback_pump 的 Handle::try_current
        // guard）与下面的 downloads spawn 都会静默/直接失败（P0-02 根因）。
        // enter_sync_bootstrap_runtime 见函数文档；enter 作用域必须覆盖整个
        // 函数体（downloads 构造 :196、spawn :230 与泵启动 :233）。
        // 有 ambient runtime 的调用方（FRB async 上下文）行为不变。
        let _enter_owned = enter_sync_bootstrap_runtime();
        // DownloadManager 构造需要 tokio 句柄：经上面的 enter 兜底后，
        // 同步引导路径也能拿到。
        let downloads_manager = tokio::runtime::Handle::try_current()
            .ok()
            .map(|handle| Arc::new(voicefox_download::DownloadManager::new(&config, handle)));

        // 配置保存后立即热应用：此前这些设置只在启动时读一次，改完要重启才生效。
        let apply: Arc<dyn Fn(&lx_core::model::config::Config) + Send + Sync> = {
            let player = Arc::clone(&player);
            let lyrics = Arc::clone(&lyrics);
            let downloads = downloads_manager.clone();
            Arc::new(move |config: &lx_core::model::config::Config| {
                player.set_volume(config.player.volume);
                player.set_playback_speed(config.player.playback_speed);
                player.set_audio_output_device(&config.player.audio_device);
                lx_source::configure_network(&config.network.proxy_url, config.network.timeout);
                lyrics.set_translation_enabled(config.lyric.show_translation);
                lyrics.set_yrc_enabled(config.lyric.show_yrc);
                lyrics.set_offset_ms(config.lyric.offset);
                if let Some(manager) = &downloads {
                    manager.sync_config(config);
                }
            })
        };

        let config_store = Arc::new(RuntimeConfigStore {
            config: Arc::clone(&shared),
            path: config_path.clone(),
            apply: Some(apply),
        });
        let downloads: Option<Arc<dyn voicefox_application::DownloadsEngine>> = downloads_manager
            .map(|manager| {
                Arc::new(RuntimeDownloads {
                    manager,
                    sources: Arc::clone(&sources),
                }) as Arc<dyn voicefox_application::DownloadsEngine>
            });
        let application = ApplicationService::new(
            Arc::clone(&player),
            Arc::clone(&sources),
            Arc::clone(&lyrics),
            effects,
            Some(Arc::clone(&storage) as Arc<dyn voicefox_application::LibraryStore>),
            Some(config_store as Arc<dyn voicefox_application::ConfigStore>),
            downloads.clone(),
        );
        if let Some(engine) = downloads {
            tokio::spawn(downloads_bridge(application.clone(), engine));
        }
        // 播放器 watcher/事件接进应用层：进度、时长、暂停状态、自动切歌。
        application.start_playback_pump();
        Ok(Self {
            application,
            config: shared,
            config_path,
            storage,
            cover,
            player,
            sources,
            lyrics,
        })
    }
    #[cfg(feature = "desktop-mpv")]
    pub fn desktop(config: Config, path: PathBuf) -> anyhow::Result<Self> {
        let p: Arc<dyn PlayerBackend> = Arc::new(lx_player::engine::MpvEngine::new()?);
        Self::from_parts(config, path, p)
    }
    pub fn application(&self) -> ApplicationService {
        self.application.clone()
    }
    pub fn state(&self) -> voicefox_application::ApplicationState {
        self.application.state()
    }
    pub fn player_state(&self) -> PlayerState {
        *self.player.state_watcher().borrow()
    }
}
pub mod config_loader;

/// 配置热更新回调：保存后立即把可热更新设置应用到播放器/网络/歌词/下载。
type ConfigApplyCallback = Arc<dyn Fn(&lx_core::model::config::Config) + Send + Sync>;

/// [`voicefox_application::ConfigStore`] 的 runtime 实现：内存替换 + TOML 落盘，
/// 并在保存后立即把可热更新的设置应用到播放器/网络/歌词/下载。
struct RuntimeConfigStore {
    config: Arc<RwLock<lx_core::model::config::Config>>,
    path: std::path::PathBuf,
    apply: Option<ConfigApplyCallback>,
}

impl voicefox_application::ConfigStore for RuntimeConfigStore {
    fn get(&self) -> lx_core::model::config::Config {
        self.config
            .read()
            .unwrap_or_else(|e| e.into_inner())
            .clone()
    }
    fn set(&self, config: lx_core::model::config::Config) -> Result<(), String> {
        config_loader::save(&config, &self.path).map_err(|error| error.to_string())?;
        *self.config.write().unwrap_or_else(|e| e.into_inner()) = config.clone();
        if let Some(apply) = &self.apply {
            apply(&config);
        }
        Ok(())
    }
}

/// [`voicefox_application::DownloadsEngine`] 的 runtime 实现，包装
/// voicefox-download 的 DownloadManager；通知走内部通道，由桥任务转发。
struct RuntimeDownloads {
    manager: Arc<voicefox_download::DownloadManager>,
    sources: Arc<lx_source::manager::SourceManager>,
}

impl voicefox_application::DownloadsEngine for RuntimeDownloads {
    fn enqueue(&self, song: lx_core::model::song::SongInfo) -> bool {
        let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
        // 通知排空：下载进度的 AppAction 通知对 GUI 无意义（状态靠快照），丢弃即可。
        tokio::spawn(async move { while rx.recv().await.is_some() {} });
        self.manager.enqueue(song, Arc::clone(&self.sources), tx)
    }
    fn cancel(&self, id: u64) {
        self.manager.cancel(id)
    }
    fn clear_finished(&self) {
        self.manager.clear_finished()
    }
    fn snapshot(&self) -> Vec<voicefox_application::DownloadTaskInfo> {
        self.manager
            .snapshot()
            .into_iter()
            .map(|task| voicefox_application::DownloadTaskInfo {
                id: task.id,
                name: task.name,
                singer: task.singer,
                source: task.source,
                quality: task.quality,
                dest: task.dest.display().to_string(),
                song: task.song,
                state: task.state.label().to_string(),
                active: task.state.is_active(),
                downloaded: task.progress.downloaded,
                total: if task.progress.total > 0 {
                    Some(task.progress.total)
                } else {
                    None
                },
                error: task.error,
                trigger_auto_cache: matches!(
                    task.trigger,
                    voicefox_download::manager::DownloadTrigger::AutoCache
                ),
            })
            .collect()
    }
    fn active_count(&self) -> usize {
        self.manager.active_count()
    }
}

/// 下载快照轮询桥：活跃任务存在时每 500ms 推一次变更，空闲时不发事件。
async fn downloads_bridge(
    service: voicefox_application::ApplicationService,
    engine: Arc<dyn voicefox_application::DownloadsEngine>,
) {
    let mut last: Vec<voicefox_application::DownloadTaskInfo> = Vec::new();
    loop {
        tokio::time::sleep(std::time::Duration::from_millis(500)).await;
        let current = engine.snapshot();
        if current != last {
            service.publish_downloads(current.clone());
            last = current;
        }
    }
}

pub fn default_config_path() -> PathBuf {
    // 移动端宿主先经 set_data_dir_override 注入 App 私有目录，config 就近落那里：
    // ProjectDirs/dirs 在 Android 上全是 None，旧回退 "." 会把配置写进只读的
    // 进程工作目录（真机 EROFS 实测）。
    if let Some(dir) = lx_core::fsutil::data_dir_override() {
        return dir.join("config.toml");
    }
    directories::ProjectDirs::from("", "", "voicefox")
        .map(|project| project.config_dir().to_path_buf())
        .unwrap_or_else(|| {
            dirs::config_dir()
                .unwrap_or_else(|| PathBuf::from("."))
                .join("voicefox")
        })
        .join("config.toml")
}
pub fn load_config() -> anyhow::Result<(Config, PathBuf)> {
    config_loader::load("")
}
fn expand_home(v: &str) -> PathBuf {
    if let Some(r) = v.strip_prefix("~/")
        && let Some(h) = dirs::home_dir()
    {
        return h.join(r);
    }
    PathBuf::from(v)
}
fn sanitize_filename(v: &str) -> String {
    let mut s = v
        .chars()
        .map(|c| if "/\\:*?\"<>|".contains(c) { '_' } else { c })
        .collect::<String>();
    while s.ends_with('.') || s.ends_with(' ') {
        s.pop();
    }
    if s.is_empty() { "unknown".into() } else { s }
}
