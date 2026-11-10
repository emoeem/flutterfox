use std::future::Future;
use std::sync::{
    Arc, RwLock,
    atomic::{AtomicU64, Ordering},
};
use std::time::{Duration, Instant};

/// fire-and-forget spawn：任务 panic 时向用户发一条通知而不是静默消失。
///
/// 各任务内部的业务 Err 分支自己发 Notification；这里兜住 panic 那条路——
/// 此前歌词/搜索任务 panic 只有全局 hook 的一条日志，用户只看到功能静默失效。
fn spawn_reported<F>(events: broadcast::Sender<ApplicationEvent>, what: &'static str, future: F)
where
    F: Future<Output = ()> + Send + 'static,
{
    let task = tokio::spawn(future);
    tokio::spawn(async move {
        if let Err(join_error) = task.await
            && join_error.is_panic()
        {
            let _ = events.send(ApplicationEvent::Notification {
                message: format!("{what}处理异常退出，请重试"),
            });
        }
    });
}

use lx_core::model::source::PlayerState;
use lx_core::traits::player::{PlayerBackend, PlayerEvent};
use lx_lyric::service::LyricService;
use lx_source::manager::SourceManager;
use tokio::sync::broadcast;

/// 播放器离散事件接收：没有事件源时永久挂起，避免 select! 分支空转。
async fn recv_player_event(
    receiver: &mut Option<tokio::sync::mpsc::UnboundedReceiver<PlayerEvent>>,
) -> Option<PlayerEvent> {
    match receiver {
        Some(receiver) => receiver.recv().await,
        None => std::future::pending().await,
    }
}

/// 随机模式的下一首：排除当前曲；单曲队列返回自身。
fn random_other(index: usize, len: usize) -> usize {
    if len <= 1 {
        return index;
    }
    let nanos = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|elapsed| elapsed.subsec_nanos() as usize)
        .unwrap_or(0);
    (index + 1 + nanos % (len - 1)) % len
}

use crate::event::{ApplicationCommand, ApplicationEvent, BrowseKind};
use crate::ports::{ConfigStore, DownloadTaskInfo, DownloadsEngine, LibraryStore};
use crate::services::{
    LyricsService, PlaybackService, PlaylistService, QueueService, SearchService,
};
use crate::state::ApplicationState;

const EVENT_CAPACITY: usize = 256;
/// 播放进度广播节流：位置 watcher 每帧都在变，前端 4Hz 足够平滑。
const PROGRESS_INTERVAL: Duration = Duration::from_millis(250);

#[derive(Clone)]
pub struct ApplicationService {
    state: Arc<RwLock<ApplicationState>>,
    events: broadcast::Sender<ApplicationEvent>,
    playback: PlaybackService,
    search: SearchService,
    queue: QueueService,
    lyrics: LyricsService,
    playlists: PlaylistService,
    library: Option<Arc<dyn LibraryStore>>,
    config_store: Option<Arc<dyn ConfigStore>>,
    downloads: Option<Arc<dyn DownloadsEngine>>,
    sources: Arc<SourceManager>,
    /// 扫码登录的取消标志：QrLoginCancel 置位，轮询任务每轮检查。
    qr_cancel: Arc<std::sync::atomic::AtomicBool>,
    /// 当前账号歌单同步的取消/进度控制；SyncCancel 操作最近一次同步。
    sync_control: Arc<std::sync::Mutex<crate::sync::SyncControl>>,
    /// 推送计划在预览与执行间复用，避免执行时重新读取远端集合。
    push_plan:
        Arc<std::sync::Mutex<Option<(lx_core::model::source::SourceId, lx_core::sync::SyncPlan)>>>,
    request_id: Arc<AtomicU64>,
    playback_request_id: Arc<AtomicU64>,
    browse_request_id: Arc<AtomicU64>,
}

impl ApplicationService {
    pub fn new(
        player: Arc<dyn PlayerBackend>,
        sources: Arc<SourceManager>,
        lyrics: Arc<LyricService>,
        effects: Arc<dyn crate::services::PlaybackEffects>,
        library: Option<Arc<dyn LibraryStore>>,
        config_store: Option<Arc<dyn ConfigStore>>,
        downloads: Option<Arc<dyn DownloadsEngine>>,
    ) -> Self {
        let playback = PlaybackService::new(Arc::clone(&player), Arc::clone(&sources), effects);
        let (events, _) = broadcast::channel(EVENT_CAPACITY);
        Self {
            state: Arc::new(RwLock::new(ApplicationState::default())),
            events,
            playback,
            search: SearchService::new(Arc::clone(&sources)),
            queue: QueueService::new(),
            lyrics: LyricsService::new(lyrics),
            playlists: PlaylistService::with_sources(Arc::clone(&sources)),
            library,
            config_store,
            downloads,
            sources,
            qr_cancel: Arc::new(std::sync::atomic::AtomicBool::new(false)),
            sync_control: Arc::new(std::sync::Mutex::new(crate::sync::SyncControl::default())),
            push_plan: Arc::new(std::sync::Mutex::new(None)),
            request_id: Arc::new(AtomicU64::new(0)),
            playback_request_id: Arc::new(AtomicU64::new(0)),
            browse_request_id: Arc::new(AtomicU64::new(0)),
        }
    }

    /// 当前启用音源的显式能力声明，供 GUI 决定入口/空态。
    pub fn source_capabilities(&self) -> Vec<crate::state::SourceCapabilityInfo> {
        self.sources
            .enabled_sources()
            .into_iter()
            .map(|source| {
                let capabilities = self.sources.capabilities(source);
                crate::state::SourceCapabilityInfo {
                    id: source.as_str().to_string(),
                    name: source.display_name().to_string(),
                    playlists: capabilities.playlists,
                    playlist_categories: capabilities.playlist_categories,
                    playlist_search: capabilities.playlist_search,
                    album: capabilities.album,
                    artist: capabilities.artist,
                    leaderboard: capabilities.leaderboard,
                    login: capabilities.login,
                    qr_login: capabilities.qr_login,
                }
            })
            .collect()
    }

    /// 本地曲库快照（扫描结果直接从这里读取，避免每轮扫描重复广播大列表）。
    pub fn local_songs(&self) -> Vec<lx_core::model::song::SongInfo> {
        self.sources.local_source().all_songs()
    }

    pub fn subscribe(&self) -> ApplicationEventStream {
        ApplicationEventStream {
            receiver: self.events.subscribe(),
        }
    }

    pub fn state(&self) -> ApplicationState {
        self.state.read().unwrap_or_else(|e| e.into_inner()).clone()
    }

    /// 启动播放器事件泵：把 `PlayerBackend` 的 state/position/duration watcher
    /// 与离散事件接到应用状态和广播通道上。
    ///
    /// 在此之前 application 层从不消费这些 watcher，GUI 的进度条、时长、
    /// 暂停状态、自动切歌与播放模式全部停在不动的初始值上。
    /// 宿主（runtime/FFI 或移动端）应在 tokio 上下文里调用一次。
    pub fn start_playback_pump(&self) {
        let Ok(handle) = tokio::runtime::Handle::try_current() else {
            // 静默 return 会让「进度/时长恒 0、Ended 自动切歌失效、播放错误
            // 不可见」变成不可排查的故障（P0-02 根因即此处）。GUI 路径没有
            // tracing subscriber，必须 eprintln 才能出现在 stdout/stderr。
            tracing::warn!(
                "start_playback_pump: 当前线程无 tokio 上下文，播放泵未启动；\
                 进度/时长/Ended/播放错误将停更。宿主应在 tokio 上下文调用本函数。"
            );
            eprintln!(
                "voicefox: start_playback_pump 失败——当前线程无 tokio 上下文，\
                 播放泵未启动（进度/时长/Ended/播放错误将停更）"
            );
            return;
        };
        eprintln!("voicefox: playback pump started");
        let service = self.clone();
        let player = self.playback.player();
        let mut state_rx = player.state_watcher();
        let mut position_rx = player.position_watcher();
        let mut duration_rx = player.duration_watcher();
        let mut player_events = player.take_event_receiver();
        handle.spawn(async move {
            let mut last_emit = Instant::now();
            service.push_playback_snapshot(true, &mut last_emit);
            loop {
                let alive = tokio::select! {
                    changed = state_rx.changed() => changed.is_ok(),
                    changed = position_rx.changed() => changed.is_ok(),
                    changed = duration_rx.changed() => changed.is_ok(),
                    event = recv_player_event(&mut player_events) => {
                        if let Some(event) = event {
                            service.handle_player_event(event).await;
                        }
                        true
                    }
                };
                if !alive {
                    break;
                }
                service.push_playback_snapshot(
                    last_emit.elapsed() >= PROGRESS_INTERVAL,
                    &mut last_emit,
                );
            }
        });
    }

    /// 读播放器当前快照写进应用状态；位置变化按 `PROGRESS_INTERVAL` 节流广播，
    /// 状态迁移（播放/暂停/停止）则立即广播。
    fn push_playback_snapshot(&self, allow_emit: bool, last_emit: &mut Instant) {
        let player = self.playback.player();
        let next_state = *player.state_watcher().borrow();
        let position = *player.position_watcher().borrow();
        let duration = *player.duration_watcher().borrow();
        let volume = player.volume();
        let (state_changed, changed) = {
            let mut state = self.state.write().unwrap_or_else(|e| e.into_inner());
            let state_changed = state.playback.state != next_state;
            let changed = state_changed
                || state.playback.position != position
                || state.playback.duration != duration
                || state.playback.volume != volume;
            state.playback.state = next_state;
            state.playback.position = position;
            state.playback.duration = duration;
            state.playback.volume = volume;
            (state_changed, changed)
        };
        // 歌词高亮跟随真实播放位置（此前只在换曲时更新一次）。
        self.lyrics.update_position(position);
        if changed && (allow_emit || state_changed) {
            *last_emit = Instant::now();
            let _ = self.events.send(ApplicationEvent::PlaybackProgress {
                state: next_state,
                position,
                duration,
            });
        }
    }

    async fn handle_player_event(&self, event: PlayerEvent) {
        match event {
            PlayerEvent::Ended { generation } => {
                let current = self
                    .state
                    .read()
                    .unwrap_or_else(|e| e.into_inner())
                    .playback
                    .generation;
                // 旧代次的 Ended 是换曲竞态，忽略。
                if generation != 0 && current != 0 && generation != current {
                    return;
                }
                if let Err(error) = self.advance_after_end().await {
                    self.emit(ApplicationEvent::PlaybackFailed {
                        request_id: 0,
                        error,
                    });
                }
            }
            PlayerEvent::Error { message, .. } => {
                let request_id = self.request_id.load(Ordering::Acquire);
                self.emit(ApplicationEvent::PlaybackFailed {
                    request_id,
                    error: message,
                });
            }
            PlayerEvent::Playing { .. } | PlayerEvent::Buffering { .. } => {}
        }
    }

    /// 曲目自然结束后的推进：单曲循环、随机、顺序到尾部停止，其余列表循环。
    async fn advance_after_end(&self) -> Result<(), String> {
        let (songs, index) = self.queue.snapshot();
        if songs.is_empty() {
            return Ok(());
        }
        match self.play_mode().as_str() {
            "single-loop" => self.play(songs, index).await,
            "random" => {
                let next = random_other(index, songs.len());
                self.play(songs, next).await
            }
            "none" => {
                if index + 1 < songs.len() {
                    self.play(songs, index + 1).await
                } else {
                    self.playback.stop();
                    self.emit(ApplicationEvent::PlaybackStopped);
                    Ok(())
                }
            }
            _ => {
                let next = (index + 1) % songs.len();
                self.play(songs, next).await
            }
        }
    }

    /// 配置里的播放模式字符串（`none` / `list-loop` / `single-loop` / `random`）。
    fn play_mode(&self) -> String {
        self.config_store
            .as_ref()
            .map(|store| store.get().player.play_mode)
            .unwrap_or_else(|| "list-loop".to_string())
    }

    pub fn playback(&self) -> PlaybackService {
        self.playback.clone()
    }
    pub fn search(&self) -> SearchService {
        self.search.clone()
    }
    pub fn queue(&self) -> QueueService {
        self.queue.clone()
    }
    pub fn lyrics(&self) -> LyricsService {
        self.lyrics.clone()
    }
    pub fn playlists(&self) -> PlaylistService {
        self.playlists.clone()
    }

    pub async fn dispatch(&self, command: ApplicationCommand) -> Result<(), String> {
        match command {
            ApplicationCommand::Search { keyword, source } => {
                self.start_search(keyword, 1, source, false).await
            }
            ApplicationCommand::SearchMore {
                keyword,
                page,
                source,
            } => self.start_search(keyword, page, source, true).await,
            ApplicationCommand::Play { songs, index } => self.play(songs, index).await,
            ApplicationCommand::PlayCurrent => {
                let (songs, index) = self.queue.snapshot();
                self.play(songs, index).await
            }
            ApplicationCommand::Pause => {
                self.playback.pause();
                self.emit(ApplicationEvent::PlaybackPaused);
                Ok(())
            }
            ApplicationCommand::Resume => {
                self.playback.resume();
                self.emit(ApplicationEvent::PlaybackResumed);
                Ok(())
            }
            ApplicationCommand::Toggle => {
                self.playback.toggle();
                // 立即读回播放器状态并广播：此前 Toggle 既不写快照也不发事件，
                // 播放/暂停按钮点下去 UI 毫无反应。
                let mut last_emit = Instant::now();
                self.push_playback_snapshot(true, &mut last_emit);
                Ok(())
            }
            ApplicationCommand::SetVolume(volume) => {
                self.playback.set_volume(volume);
                let mut last_emit = Instant::now();
                self.push_playback_snapshot(true, &mut last_emit);
                Ok(())
            }
            ApplicationCommand::Stop => {
                self.playback.stop();
                self.emit(ApplicationEvent::PlaybackStopped);
                Ok(())
            }
            ApplicationCommand::Seek(position) => {
                self.playback.seek(position);
                Ok(())
            }
            ApplicationCommand::QueueAdd { song, next } => {
                let was_empty = self.queue.snapshot().0.is_empty();
                self.queue.add(song.clone(), next);
                self.publish_queue();
                if was_empty {
                    let (songs, index) = self.queue.snapshot();
                    if let Some(current) = songs.get(index).cloned() {
                        self.play(songs, index).await?;
                        self.emit(ApplicationEvent::Notification {
                            message: format!("开始播放: {} - {}", current.name, current.singer),
                        });
                    }
                }
                Ok(())
            }
            ApplicationCommand::QueueRemove { index } => {
                self.queue.remove(index);
                self.publish_queue();
                Ok(())
            }
            ApplicationCommand::QueueClear => {
                self.queue.clear();
                self.publish_queue();
                Ok(())
            }
            ApplicationCommand::Next => {
                let (songs, index) = self.queue.snapshot();
                if songs.is_empty() {
                    return Ok(());
                }
                let next = if self.play_mode() == "random" {
                    random_other(index, songs.len())
                } else {
                    (index + 1) % songs.len()
                };
                self.play(songs, next).await
            }
            ApplicationCommand::Previous => {
                let (songs, index) = self.queue.snapshot();
                if songs.is_empty() {
                    return Ok(());
                }
                let len = songs.len();
                let previous = if self.play_mode() == "random" {
                    random_other(index, len)
                } else if index == 0 {
                    len - 1
                } else {
                    index - 1
                };
                self.play(songs, previous).await
            }
            ApplicationCommand::PlaybackFailed { request_id, error } => {
                if self.request_id.load(Ordering::Acquire) != request_id {
                    return Ok(());
                }
                let (songs, index) = self.queue.snapshot();
                if songs.len() > 1 {
                    let next = (index + 1) % songs.len();
                    self.emit(ApplicationEvent::Notification {
                        message: format!("{}；已跳过当前歌曲", error),
                    });
                    self.play(songs, next).await
                } else {
                    self.emit(ApplicationEvent::PlaybackFailed {
                        request_id,
                        error: error.clone(),
                    });
                    Err(error)
                }
            }
            ApplicationCommand::RestorePlayback {
                songs,
                index,
                position,
                paused,
            } => {
                let _ = (position, paused);
                self.play_with_restore(songs, index, position, paused).await
            }
            ApplicationCommand::LoadLyrics { song } => {
                let generation = self.state().playback.generation;
                let lyrics = self.lyrics.clone();
                let events = self.events.clone();
                let state = Arc::clone(&self.state);
                spawn_reported(events.clone(), "歌词加载", async move {
                    match lyrics.load(&song, generation).await {
                        Ok(value) => {
                            state.write().unwrap_or_else(|e| e.into_inner()).lyrics = Some(value);
                            let _ =
                                events.send(ApplicationEvent::LyricsChanged { song_id: song.id });
                        }
                        Err(error) => {
                            let _ = events.send(ApplicationEvent::Notification {
                                message: format!("歌词加载失败: {error}"),
                            });
                        }
                    }
                });
                Ok(())
            }
            ApplicationCommand::PlaylistOpen { playlist } => {
                self.playlists.upsert(playlist);
                self.publish_playlists();
                Ok(())
            }
            ApplicationCommand::PlaylistSet(playlists) => {
                self.playlists.replace(playlists);
                self.publish_playlists();
                Ok(())
            }
            ApplicationCommand::LibraryRefresh => {
                self.publish_library();
                Ok(())
            }
            ApplicationCommand::FavoritesAdd { song } => {
                let store = self.library()?;
                store.add_favorite(&song);
                self.publish_library();
                Ok(())
            }
            ApplicationCommand::FavoritesRemove { song } => {
                let store = self.library()?;
                store.remove_favorite(&song);
                self.publish_library();
                Ok(())
            }
            ApplicationCommand::FavoritePlaylistAdd { playlist } => {
                let store = self.library()?;
                store.add_favorite_playlist(&playlist);
                self.publish_library();
                Ok(())
            }
            ApplicationCommand::FavoritePlaylistRemove { playlist } => {
                let store = self.library()?;
                store.remove_favorite_playlist(&playlist);
                self.publish_library();
                Ok(())
            }
            ApplicationCommand::HistoryRemove { song } => {
                let store = self.library()?;
                store.remove_history(&song);
                self.publish_library();
                Ok(())
            }
            ApplicationCommand::HistoryClear => {
                let store = self.library()?;
                store.clear_history();
                self.publish_library();
                Ok(())
            }
            ApplicationCommand::CustomPlaylistCreate { name } => {
                let store = self.library()?;
                let created = store.create_custom_playlist(&name);
                match created {
                    Ok(playlist) => {
                        self.publish_library();
                        self.emit(ApplicationEvent::CustomPlaylistCreated {
                            id: playlist.id,
                            name: playlist.name,
                        });
                        Ok(())
                    }
                    Err(error) => Err(error),
                }
            }
            ApplicationCommand::CustomPlaylistRename { id, name } => {
                let store = self.library()?;
                let result = store.rename_custom_playlist(&id, &name);
                if result.is_ok() {
                    self.publish_library();
                }
                result
            }
            ApplicationCommand::CustomPlaylistDelete { id } => {
                let store = self.library()?;
                let result = store.delete_custom_playlist(&id).map(|_| ());
                if result.is_ok() {
                    self.publish_library();
                }
                result
            }
            ApplicationCommand::CustomPlaylistAddSongs { id, songs } => {
                let store = self.library()?;
                let count = songs.len();
                let result = store.add_songs_to_custom_playlist(&id, &songs);
                match result {
                    Ok((added, skipped)) => {
                        self.publish_library();
                        self.emit(ApplicationEvent::Notification {
                            message: format!("已加入 {added}/{count} 首（重复跳过 {skipped}）"),
                        });
                        Ok(())
                    }
                    Err(error) => Err(error),
                }
            }
            ApplicationCommand::CustomPlaylistRemoveSong { id, song } => {
                let store = self.library()?;
                let result = store
                    .remove_song_from_custom_playlist(&id, &song)
                    .map(|_| ());
                if result.is_ok() {
                    self.publish_library();
                }
                result
            }
            ApplicationCommand::CustomPlaylistDetail { id } => {
                // 本地存储直读，无须异步任务；结果复用浏览数据面，
                // 前端按 `custom_playlist|local|<id>` 分槽。
                let store = self.library()?;
                let request_id = self.next_browse_request();
                match store.custom_playlist(&id) {
                    Some(playlist) => {
                        self.emit(ApplicationEvent::BrowseLoaded {
                            request_id,
                            kind: BrowseKind::CustomPlaylist,
                            source: lx_core::model::source::SourceId::Local,
                            id,
                            page: 1,
                            items: playlist.songs,
                            albums: vec![],
                            boards: vec![],
                            playlists: vec![],
                            categories: vec![],
                            has_more: false,
                            message: None,
                        });
                        Ok(())
                    }
                    None => {
                        self.emit(ApplicationEvent::BrowseFailed {
                            request_id,
                            kind: BrowseKind::CustomPlaylist,
                            source: lx_core::model::source::SourceId::Local,
                            id,
                            error: "自建歌单不存在或已被删除".to_string(),
                        });
                        Ok(())
                    }
                }
            }
            ApplicationCommand::ConfigUpdate { config } => {
                let store = self
                    .config_store
                    .clone()
                    .ok_or_else(|| "配置存储不可用".to_string())?;
                let result = store.set(*config);
                if result.is_ok() {
                    self.emit(ApplicationEvent::ConfigChanged {
                        config: Box::new(store.get()),
                    });
                }
                result
            }
            ApplicationCommand::ConfigGet => {
                let store = self
                    .config_store
                    .clone()
                    .ok_or_else(|| "配置存储不可用".to_string())?;
                self.emit(ApplicationEvent::ConfigChanged {
                    config: Box::new(store.get()),
                });
                Ok(())
            }
            ApplicationCommand::DownloadEnqueue { song } => {
                let engine = self
                    .downloads
                    .clone()
                    .ok_or_else(|| "下载引擎不可用".to_string())?;
                if engine.enqueue(song) {
                    self.publish_downloads(engine.snapshot());
                } else {
                    self.emit(ApplicationEvent::Notification {
                        message: "该歌曲已在下载队列中".to_string(),
                    });
                }
                Ok(())
            }
            ApplicationCommand::DownloadCancel { id } => {
                if let Some(engine) = self.downloads.as_ref() {
                    engine.cancel(id);
                    self.publish_downloads(engine.snapshot());
                }
                Ok(())
            }
            ApplicationCommand::DownloadClearFinished => {
                if let Some(engine) = self.downloads.as_ref() {
                    engine.clear_finished();
                    self.publish_downloads(engine.snapshot());
                }
                Ok(())
            }
            ApplicationCommand::QrLoginStart { source, kind } => {
                self.start_qr_login(source, kind).await
            }
            ApplicationCommand::QrLoginCancel => {
                self.qr_cancel
                    .store(true, std::sync::atomic::Ordering::SeqCst);
                Ok(())
            }
            ApplicationCommand::LocalScan { paths, max_depth } => {
                let sources = Arc::clone(&self.sources);
                let events = self.events.clone();
                spawn_reported(events.clone(), "本地扫描", async move {
                    let local = sources.local_source();
                    let result = tokio::task::spawn_blocking(move || local.scan(&paths, max_depth))
                        .await
                        .unwrap_or_default();
                    let _ = events.send(ApplicationEvent::LocalScanCompleted { warnings: result });
                });
                Ok(())
            }
            ApplicationCommand::AccountPlaylists { source } => {
                let request_id = self.next_browse_request();
                match account_playlists(source) {
                    Some(playlists) => {
                        self.emit(ApplicationEvent::BrowseLoaded {
                            request_id,
                            kind: BrowseKind::AccountPlaylists,
                            source,
                            id: String::new(),
                            page: 1,
                            items: vec![],
                            albums: vec![],
                            boards: vec![],
                            playlists,
                            categories: vec![],
                            has_more: false,
                            message: None,
                        });
                    }
                    None => self.emit(ApplicationEvent::BrowseLoaded {
                        request_id,
                        kind: BrowseKind::AccountPlaylists,
                        source,
                        id: String::new(),
                        page: 1,
                        items: vec![],
                        albums: vec![],
                        boards: vec![],
                        playlists: vec![],
                        categories: vec![],
                        has_more: false,
                        message: Some("该平台没有账号歌单镜像（当前支持网易云与 QQ 音乐）".into()),
                    }),
                }
                Ok(())
            }
            ApplicationCommand::AccountFavorites { source } => {
                let request_id = self.next_browse_request();
                let supported = matches!(
                    source,
                    lx_core::model::source::SourceId::Wy | lx_core::model::source::SourceId::Tx
                );
                let songs = if supported {
                    crate::remote_cache::favorites_songs(source)
                } else {
                    vec![]
                };
                self.emit(ApplicationEvent::BrowseLoaded {
                    request_id,
                    kind: BrowseKind::AccountFavorites,
                    source,
                    id: "favorites".into(),
                    page: 1,
                    items: songs,
                    albums: vec![],
                    boards: vec![],
                    playlists: vec![],
                    categories: vec![],
                    has_more: false,
                    message: if supported {
                        None
                    } else {
                        Some("账号红心镜像仅支持网易云与 QQ 音乐".into())
                    },
                });
                Ok(())
            }
            ApplicationCommand::AccountPlaylistDetail {
                source,
                playlist_id,
            } => {
                let request_id = self.next_browse_request();
                match crate::remote_cache::playlist(source, &playlist_id) {
                    Some(collection) => {
                        self.emit(ApplicationEvent::BrowseLoaded {
                            request_id,
                            kind: BrowseKind::AccountPlaylistDetail,
                            source,
                            id: playlist_id,
                            page: 1,
                            items: collection.songs,
                            albums: vec![],
                            boards: vec![],
                            playlists: vec![],
                            categories: vec![],
                            has_more: false,
                            message: None,
                        });
                    }
                    None => self.emit(ApplicationEvent::BrowseFailed {
                        request_id,
                        kind: BrowseKind::AccountPlaylistDetail,
                        source,
                        id: playlist_id,
                        error: "账号歌单缓存中没有该歌单，请先同步".to_string(),
                    }),
                }
                Ok(())
            }
            ApplicationCommand::SyncPreview { source } => {
                let events = self.events.clone();
                spawn_reported(events.clone(), "账号歌单预览", async move {
                    match crate::sync::preview_source(source).await {
                        Ok(preview) => {
                            let _ = events.send(ApplicationEvent::SyncPreviewReady {
                                source,
                                preview: Box::new(preview),
                            });
                        }
                        Err(error) => {
                            let _ = events.send(ApplicationEvent::SyncFailed { source, error });
                        }
                    }
                });
                Ok(())
            }
            ApplicationCommand::SyncRun { source } => {
                let control = crate::sync::SyncControl::default();
                *self.sync_control.lock().unwrap_or_else(|e| e.into_inner()) = control.clone();
                let events = self.events.clone();
                spawn_reported(events.clone(), "账号歌单同步", async move {
                    // 进度轮询：拉取阶段没有粒度，进度在缓存写入阶段推进；
                    // 完成/取消后 abort。
                    let monitor_control = control.clone();
                    let monitor_events = events.clone();
                    let monitor = tokio::spawn(async move {
                        loop {
                            let (done, total) = monitor_control.progress();
                            let _ = monitor_events.send(ApplicationEvent::SyncProgress {
                                source,
                                done,
                                total,
                            });
                            tokio::time::sleep(std::time::Duration::from_millis(300)).await;
                        }
                    });
                    let result = crate::sync::sync_source_with_control(source, &control).await;
                    monitor.abort();
                    match result {
                        Ok(report) => {
                            let _ = events.send(ApplicationEvent::SyncCompleted {
                                source,
                                report: Box::new(report),
                            });
                        }
                        Err(error) => {
                            let _ = events.send(ApplicationEvent::SyncFailed { source, error });
                        }
                    }
                });
                Ok(())
            }
            ApplicationCommand::SyncCancel => {
                self.sync_control
                    .lock()
                    .unwrap_or_else(|e| e.into_inner())
                    .cancel();
                Ok(())
            }
            ApplicationCommand::PushTargets { source } => {
                let events = self.events.clone();
                spawn_reported(events.clone(), "推送目标读取", async move {
                    match crate::sync::push_list_targets(source).await {
                        Ok(targets) => {
                            let _ =
                                events.send(ApplicationEvent::PushTargetsReady { source, targets });
                        }
                        Err(error) => {
                            let _ = events.send(ApplicationEvent::PushFailed { source, error });
                        }
                    }
                });
                Ok(())
            }
            ApplicationCommand::PushCreateTarget { source, name } => {
                let events = self.events.clone();
                spawn_reported(events.clone(), "推送歌单创建", async move {
                    match crate::sync::push_create_target(source, &name).await {
                        Ok(target) => {
                            let _ =
                                events.send(ApplicationEvent::PushTargetCreated { source, target });
                        }
                        Err(error) => {
                            let _ = events.send(ApplicationEvent::PushFailed { source, error });
                        }
                    }
                });
                Ok(())
            }
            ApplicationCommand::PushPlan {
                source,
                local,
                target,
            } => {
                let events = self.events.clone();
                let saved_plan = Arc::clone(&self.push_plan);
                spawn_reported(events.clone(), "推送预览", async move {
                    match crate::sync::push_plan(source, &local, &target).await {
                        Ok((preview, plan)) => {
                            *saved_plan.lock().unwrap_or_else(|e| e.into_inner()) =
                                Some((source, plan));
                            let _ = events.send(ApplicationEvent::PushPlanReady {
                                source,
                                preview: Box::new(preview),
                            });
                        }
                        Err(error) => {
                            let _ = events.send(ApplicationEvent::PushFailed { source, error });
                        }
                    }
                });
                Ok(())
            }
            ApplicationCommand::PushRun { source } => {
                let plan = self
                    .push_plan
                    .lock()
                    .unwrap_or_else(|e| e.into_inner())
                    .take()
                    .filter(|(planned_source, _)| *planned_source == source);
                let Some((_, plan)) = plan else {
                    self.emit(ApplicationEvent::PushFailed {
                        source,
                        error: "推送计划已失效，请重新预览".into(),
                    });
                    return Ok(());
                };
                let control = crate::sync::SyncControl::default();
                *self.sync_control.lock().unwrap_or_else(|e| e.into_inner()) = control.clone();
                let events = self.events.clone();
                spawn_reported(events.clone(), "歌单推送", async move {
                    let monitor_control = control.clone();
                    let monitor_events = events.clone();
                    let monitor = tokio::spawn(async move {
                        loop {
                            let (done, total) = monitor_control.progress();
                            let _ = monitor_events.send(ApplicationEvent::PushProgress {
                                source,
                                done,
                                total,
                            });
                            tokio::time::sleep(std::time::Duration::from_millis(300)).await;
                        }
                    });
                    let result = crate::sync::push_execute(source, &plan, &control).await;
                    monitor.abort();
                    match result {
                        Ok(report) => {
                            let _ = events.send(ApplicationEvent::PushCompleted {
                                source,
                                report: Box::new(report),
                            });
                        }
                        Err(error) => {
                            let _ = events.send(ApplicationEvent::PushFailed { source, error });
                        }
                    }
                });
                Ok(())
            }
            ApplicationCommand::PushCancel => {
                self.sync_control
                    .lock()
                    .unwrap_or_else(|e| e.into_inner())
                    .cancel();
                Ok(())
            }
            ApplicationCommand::PlaylistCategories { source } => {
                if !self.sources.capabilities(source).playlist_categories {
                    // 有歌单浏览能力但没有分类目录的音源：发空分类 + 说明，
                    // 前端只用默认「推荐」入口，不出现伪造分类。
                    self.emit(ApplicationEvent::BrowseLoaded {
                        request_id: self.next_browse_request(),
                        kind: BrowseKind::PlaylistCategories,
                        source,
                        id: String::new(),
                        page: 1,
                        items: vec![],
                        albums: vec![],
                        boards: vec![],
                        playlists: vec![],
                        categories: vec![],
                        has_more: false,
                        message: Some("该音源不提供歌单分类，仅可浏览推荐歌单".to_string()),
                    });
                    return Ok(());
                }
                let request_id = self.next_browse_request();
                let sources = Arc::clone(&self.sources);
                let events = self.events.clone();
                spawn_reported(events.clone(), "歌单分类", async move {
                    match sources.playlist_categories(source).await {
                        Ok(categories) => {
                            let _ = events.send(ApplicationEvent::BrowseLoaded {
                                request_id,
                                kind: BrowseKind::PlaylistCategories,
                                source,
                                id: String::new(),
                                page: 1,
                                items: vec![],
                                albums: vec![],
                                boards: vec![],
                                playlists: vec![],
                                categories,
                                has_more: false,
                                message: None,
                            });
                        }
                        Err(error) => {
                            let _ = events.send(ApplicationEvent::BrowseFailed {
                                request_id,
                                kind: BrowseKind::PlaylistCategories,
                                source,
                                id: String::new(),
                                error: error.to_string(),
                            });
                        }
                    }
                });
                Ok(())
            }
            ApplicationCommand::Playlists {
                source,
                category,
                page,
            } => {
                if !self.sources.capabilities(source).playlists {
                    self.emit_browse_unavailable(
                        BrowseKind::Playlists,
                        source,
                        &category,
                        "该音源不支持歌单浏览",
                    );
                    return Ok(());
                }
                let request_id = self.next_browse_request();
                let sources = Arc::clone(&self.sources);
                let events = self.events.clone();
                spawn_reported(events.clone(), "歌单列表", async move {
                    match sources.playlists(source, &category, page).await {
                        Ok(playlists) => {
                            let has_more = !playlists.is_empty();
                            let _ = events.send(ApplicationEvent::BrowseLoaded {
                                request_id,
                                kind: BrowseKind::Playlists,
                                source,
                                id: category,
                                page,
                                items: vec![],
                                albums: vec![],
                                boards: vec![],
                                playlists,
                                categories: vec![],
                                has_more,
                                message: None,
                            });
                        }
                        Err(error) => {
                            let _ = events.send(ApplicationEvent::BrowseFailed {
                                request_id,
                                kind: BrowseKind::Playlists,
                                source,
                                id: category,
                                error: error.to_string(),
                            });
                        }
                    }
                });
                Ok(())
            }
            ApplicationCommand::PlaylistDetail {
                source,
                playlist_id,
                page,
            } => {
                if !self.sources.capabilities(source).playlists {
                    self.emit_browse_unavailable(
                        BrowseKind::PlaylistDetail,
                        source,
                        &playlist_id,
                        "该音源不支持歌单详情",
                    );
                    return Ok(());
                }
                let request_id = self.next_browse_request();
                let sources = Arc::clone(&self.sources);
                let events = self.events.clone();
                spawn_reported(events.clone(), "歌单详情", async move {
                    match sources.playlist_detail(source, &playlist_id, page).await {
                        Ok(items) => {
                            let has_more = !items.is_empty();
                            let _ = events.send(ApplicationEvent::BrowseLoaded {
                                request_id,
                                kind: BrowseKind::PlaylistDetail,
                                source,
                                id: playlist_id,
                                page,
                                items,
                                albums: vec![],
                                boards: vec![],
                                playlists: vec![],
                                categories: vec![],
                                has_more,
                                message: None,
                            });
                        }
                        Err(error) => {
                            let _ = events.send(ApplicationEvent::BrowseFailed {
                                request_id,
                                kind: BrowseKind::PlaylistDetail,
                                source,
                                id: playlist_id,
                                error: error.to_string(),
                            });
                        }
                    }
                });
                Ok(())
            }
            ApplicationCommand::LeaderboardBoards { source } => {
                if !self.sources.capabilities(source).leaderboard {
                    self.emit_browse_unavailable(
                        BrowseKind::LeaderboardBoards,
                        source,
                        "",
                        "该音源不支持排行榜",
                    );
                    return Ok(());
                }
                let request_id = self.next_browse_request();
                let sources = Arc::clone(&self.sources);
                let events = self.events.clone();
                spawn_reported(events.clone(), "榜单目录", async move {
                    match sources.leaderboard_boards(source).await {
                        Ok(boards) => {
                            let _ = events.send(ApplicationEvent::BrowseLoaded {
                                request_id,
                                kind: BrowseKind::LeaderboardBoards,
                                source,
                                id: String::new(),
                                page: 1,
                                items: vec![],
                                albums: vec![],
                                boards,
                                playlists: vec![],
                                categories: vec![],
                                has_more: false,
                                message: None,
                            });
                        }
                        Err(error) => {
                            let _ = events.send(ApplicationEvent::BrowseFailed {
                                request_id,
                                kind: BrowseKind::LeaderboardBoards,
                                source,
                                id: String::new(),
                                error: error.to_string(),
                            });
                        }
                    }
                });
                Ok(())
            }
            ApplicationCommand::LeaderboardSongs {
                source,
                board_id,
                page,
            } => {
                if !self.sources.capabilities(source).leaderboard {
                    self.emit_browse_unavailable(
                        BrowseKind::LeaderboardSongs,
                        source,
                        &board_id,
                        "该音源不支持排行榜",
                    );
                    return Ok(());
                }
                let request_id = self.next_browse_request();
                let sources = Arc::clone(&self.sources);
                let events = self.events.clone();
                spawn_reported(events.clone(), "榜单歌曲", async move {
                    match sources.leaderboard(source, &board_id, page, 50).await {
                        Ok(result) => {
                            let _ = events.send(ApplicationEvent::BrowseLoaded {
                                request_id,
                                kind: BrowseKind::LeaderboardSongs,
                                source,
                                id: board_id,
                                page,
                                items: result.items,
                                albums: vec![],
                                boards: vec![],
                                playlists: vec![],
                                categories: vec![],
                                has_more: result.has_more,
                                message: None,
                            });
                        }
                        Err(error) => {
                            let _ = events.send(ApplicationEvent::BrowseFailed {
                                request_id,
                                kind: BrowseKind::LeaderboardSongs,
                                source,
                                id: board_id,
                                error: error.to_string(),
                            });
                        }
                    }
                });
                Ok(())
            }
            ApplicationCommand::ArtistSongs { artist, page } => {
                if !self.sources.capabilities(artist.source).artist {
                    self.emit_browse_unavailable(
                        BrowseKind::ArtistSongs,
                        artist.source,
                        &artist.id,
                        "该音源不支持歌手详情",
                    );
                    return Ok(());
                }
                let request_id = self.next_browse_request();
                let sources = Arc::clone(&self.sources);
                let events = self.events.clone();
                spawn_reported(events.clone(), "歌手歌曲", async move {
                    match sources.artist_songs(&artist, page, 100).await {
                        Ok(result) => {
                            let _ = events.send(ApplicationEvent::BrowseLoaded {
                                request_id,
                                kind: BrowseKind::ArtistSongs,
                                source: artist.source,
                                id: artist.id,
                                page,
                                items: result.items,
                                albums: vec![],
                                boards: vec![],
                                playlists: vec![],
                                categories: vec![],
                                has_more: result.has_more,
                                message: None,
                            });
                        }
                        Err(error) => {
                            let _ = events.send(ApplicationEvent::BrowseFailed {
                                request_id,
                                kind: BrowseKind::ArtistSongs,
                                source: artist.source,
                                id: artist.id,
                                error: error.to_string(),
                            });
                        }
                    }
                });
                Ok(())
            }
            ApplicationCommand::ArtistAlbums { artist, page } => {
                if !self.sources.capabilities(artist.source).artist {
                    self.emit_browse_unavailable(
                        BrowseKind::ArtistAlbums,
                        artist.source,
                        &artist.id,
                        "该音源不支持歌手详情",
                    );
                    return Ok(());
                }
                let request_id = self.next_browse_request();
                let sources = Arc::clone(&self.sources);
                let events = self.events.clone();
                spawn_reported(events.clone(), "歌手专辑", async move {
                    match sources.artist_albums(&artist, page, 100).await {
                        Ok(albums) => {
                            let has_more = !albums.is_empty();
                            let _ = events.send(ApplicationEvent::BrowseLoaded {
                                request_id,
                                kind: BrowseKind::ArtistAlbums,
                                source: artist.source,
                                id: artist.id,
                                page,
                                items: vec![],
                                albums,
                                boards: vec![],
                                playlists: vec![],
                                categories: vec![],
                                has_more,
                                message: None,
                            });
                        }
                        Err(error) => {
                            let _ = events.send(ApplicationEvent::BrowseFailed {
                                request_id,
                                kind: BrowseKind::ArtistAlbums,
                                source: artist.source,
                                id: artist.id,
                                error: error.to_string(),
                            });
                        }
                    }
                });
                Ok(())
            }
            ApplicationCommand::AlbumSongs { album, page } => {
                if !self.sources.capabilities(album.source).album {
                    self.emit_browse_unavailable(
                        BrowseKind::AlbumSongs,
                        album.source,
                        &album.id,
                        "该音源不支持专辑",
                    );
                    return Ok(());
                }
                let request_id = self.next_browse_request();
                let sources = Arc::clone(&self.sources);
                let events = self.events.clone();
                spawn_reported(events.clone(), "专辑曲目", async move {
                    match sources.album_songs(&album, page, 100).await {
                        Ok(result) => {
                            let _ = events.send(ApplicationEvent::BrowseLoaded {
                                request_id,
                                kind: BrowseKind::AlbumSongs,
                                source: album.source,
                                id: album.id,
                                page,
                                items: result.items,
                                albums: vec![],
                                boards: vec![],
                                playlists: vec![],
                                categories: vec![],
                                has_more: result.has_more,
                                message: None,
                            });
                        }
                        Err(error) => {
                            let _ = events.send(ApplicationEvent::BrowseFailed {
                                request_id,
                                kind: BrowseKind::AlbumSongs,
                                source: album.source,
                                id: album.id,
                                error: error.to_string(),
                            });
                        }
                    }
                });
                Ok(())
            }
        }
    }

    fn next_browse_request(&self) -> u64 {
        self.browse_request_id.fetch_add(1, Ordering::SeqCst) + 1
    }

    /// 能力不支持时发「成功但为空」的浏览事件：前端走空态，不当错误处理。
    fn emit_browse_unavailable(
        &self,
        kind: BrowseKind,
        source: lx_core::model::source::SourceId,
        id: &str,
        message: &str,
    ) {
        self.emit(ApplicationEvent::BrowseLoaded {
            request_id: self.next_browse_request(),
            kind,
            source,
            id: id.to_string(),
            page: 1,
            items: vec![],
            albums: vec![],
            boards: vec![],
            playlists: vec![],
            categories: vec![],
            has_more: false,
            message: Some(message.to_string()),
        });
    }

    /// 扫码登录：生成二维码 → 轮询状态直至终态/取消。
    async fn start_qr_login(
        &self,
        source: lx_core::model::source::SourceId,
        kind: lx_core::model::login::QrLoginKind,
    ) -> Result<(), String> {
        let sources = Arc::clone(&self.sources);
        let events = self.events.clone();
        let cancel = Arc::clone(&self.qr_cancel);
        cancel.store(false, std::sync::atomic::Ordering::SeqCst);
        spawn_reported(events.clone(), "扫码登录", async move {
            let session = match sources.create_qr_login_kind(source, kind).await {
                Ok(session) => session,
                Err(error) => {
                    let _ = events.send(ApplicationEvent::QrLoginPolled {
                        source,
                        status: "failed".to_string(),
                        message: format!("生成二维码失败: {error}"),
                        user_name: None,
                    });
                    return;
                }
            };
            let _ = events.send(ApplicationEvent::QrLoginCreated {
                session: session.clone(),
            });
            loop {
                if cancel.load(std::sync::atomic::Ordering::SeqCst) {
                    return;
                }
                tokio::time::sleep(std::time::Duration::from_secs(2)).await;
                if cancel.load(std::sync::atomic::Ordering::SeqCst) {
                    return;
                }
                match sources.check_qr_login(source, &session.key).await {
                    Ok(result) => {
                        let terminal = result.status.is_terminal();
                        let _ = events.send(ApplicationEvent::QrLoginPolled {
                            source,
                            status: format!("{:?}", result.status).to_lowercase(),
                            message: result.message,
                            user_name: result.user_name,
                        });
                        if terminal {
                            return;
                        }
                    }
                    Err(error) => {
                        let _ = events.send(ApplicationEvent::QrLoginPolled {
                            source,
                            status: "failed".to_string(),
                            message: format!("轮询失败: {error}"),
                            user_name: None,
                        });
                        return;
                    }
                }
            }
        });
        Ok(())
    }

    /// 下载快照桥：runtime 的轮询任务调用，刷新 state 并广播。
    pub fn publish_downloads(&self, tasks: Vec<DownloadTaskInfo>) {
        {
            let mut state = self.state.write().unwrap_or_else(|e| e.into_inner());
            state.downloads = tasks;
        }
        self.emit(ApplicationEvent::DownloadsChanged);
    }

    /// 库存储端口缺失时的统一错误（纯 playback/search 等用途不受影响）。
    fn library(&self) -> Result<std::sync::Arc<dyn LibraryStore>, String> {
        self.library
            .clone()
            .ok_or_else(|| "本地存储不可用".to_string())
    }

    /// 刷新收藏/历史/自定义歌单快照并广播 LibraryChanged + StateChanged。
    fn publish_library(&self) {
        let Some(store) = self.library.as_ref() else {
            return;
        };
        {
            let mut state = self.state.write().unwrap_or_else(|e| e.into_inner());
            state.favorites = store.favorites();
            state.favorite_playlists = store.favorite_playlists();
            state.history = store.history();
            state.custom_playlists = store.custom_playlist_summaries();
        }
        self.emit(ApplicationEvent::LibraryChanged);
    }

    async fn start_search(
        &self,
        keyword: String,
        page: u32,
        source: Option<lx_core::model::source::SourceId>,
        append: bool,
    ) -> Result<(), String> {
        let request_id = self.request_id.fetch_add(1, Ordering::SeqCst) + 1;
        // SearchMore 兜底必须在覆盖 state.search.source 之前读：append 且调用方
        // 未带 source（旧客户端/聚合路径之外的兜底）时沿用本次查询建立时的
        // 音源过滤；若先写 None 再读就永远是 None（P1-04 陷阱）。
        let effective_source = if append {
            source.or_else(|| {
                self.state
                    .read()
                    .unwrap_or_else(|e| e.into_inner())
                    .search
                    .source
            })
        } else {
            source
        };
        {
            let mut state = self.state.write().unwrap_or_else(|e| e.into_inner());
            state.search.keyword = keyword.clone();
            state.search.source = effective_source;
            state.search.page = page;
            state.search.request_id = request_id;
            state.search.loading = true;
            state.search.error = None;
            if !append {
                state.search.items.clear();
            }
        }
        self.emit(ApplicationEvent::SearchStarted {
            request_id,
            keyword: keyword.clone(),
        });

        let search = self.search.clone();
        let events = self.events.clone();
        let state = Arc::clone(&self.state);
        spawn_reported(events.clone(), "搜索", async move {
            match search.search(&keyword, page, effective_source).await {
                Ok((items, has_more)) => {
                    let mut current = state.write().unwrap_or_else(|e| e.into_inner());
                    if current.search.request_id != request_id {
                        return;
                    }
                    if append {
                        current.search.items.extend(items.clone());
                    } else {
                        current.search.items = items.clone();
                    }
                    current.search.has_more = has_more;
                    current.search.page = page;
                    current.search.loading = false;
                    current.search.error = None;
                    let _ = events.send(ApplicationEvent::SearchCompleted {
                        request_id,
                        keyword: keyword.clone(),
                        page,
                        append,
                        items,
                        has_more,
                    });
                }
                Err(error) => {
                    if state
                        .read()
                        .unwrap_or_else(|e| e.into_inner())
                        .search
                        .request_id
                        != request_id
                    {
                        return;
                    }
                    let _ = events.send(ApplicationEvent::SearchFailed {
                        request_id,
                        error: error.clone(),
                    });
                    // 失败原因留在状态里，GUI 直接渲染错误态。
                    {
                        let mut current = state.write().unwrap_or_else(|e| e.into_inner());
                        if current.search.request_id == request_id {
                            current.search.loading = false;
                            current.search.error = Some(error);
                        }
                    }
                }
            }
        });
        Ok(())
    }

    fn playback_quality(&self) -> lx_core::model::source::Quality {
        self.playback.quality()
    }
    fn auto_toggle(&self) -> bool {
        self.playback.auto_toggle()
    }

    async fn play_with_restore(
        &self,
        songs: Vec<lx_core::model::song::SongInfo>,
        index: usize,
        position: std::time::Duration,
        paused: bool,
    ) -> Result<(), String> {
        let request_id = self.playback_request_id.fetch_add(1, Ordering::SeqCst) + 1;
        let Some(song) = songs.get(index).cloned() else {
            return Err("播放索引超出队列范围".to_string());
        };
        self.queue.replace(songs, index);
        match self
            .playback
            .play(
                &song,
                self.playback_quality(),
                self.auto_toggle(),
                Some((position, paused)),
                false,
            )
            .await
        {
            Ok((generation, resolved_song)) => {
                let (queue, index) = self.queue.snapshot();
                let mut state = self.state.write().unwrap_or_else(|e| e.into_inner());
                state.queue = crate::state::QueueState {
                    songs: queue,
                    index,
                };
                state.playback.state = if paused {
                    PlayerState::Paused
                } else {
                    PlayerState::Playing
                };
                state.playback.song = Some(resolved_song.clone());
                state.playback.generation = generation;
                state.playback.volume = self.playback.volume();
                drop(state);
                self.emit(ApplicationEvent::PlaybackStarted {
                    request_id,
                    song: resolved_song,
                    source_index: self.playback.source_index(),
                });
                self.publish_queue();
                Ok(())
            }
            Err(error) => {
                self.emit(ApplicationEvent::PlaybackFailed {
                    request_id,
                    error: error.clone(),
                });
                Err(error)
            }
        }
    }

    async fn play(
        &self,
        songs: Vec<lx_core::model::song::SongInfo>,
        index: usize,
    ) -> Result<(), String> {
        let (songs, index, bili_note) = self.playback.expand_bili_parts(songs, index).await;
        if let Some(note) = bili_note {
            self.emit(ApplicationEvent::Notification { message: note });
        }
        let request_id = self.playback_request_id.fetch_add(1, Ordering::SeqCst) + 1;
        let Some(song) = songs.get(index).cloned() else {
            return Err("播放索引超出队列范围".to_string());
        };
        self.queue.replace(songs, index);
        match self
            .playback
            .play(
                &song,
                self.playback_quality(),
                self.auto_toggle(),
                None,
                true,
            )
            .await
        {
            Ok((generation, resolved_song)) => {
                let (queue, index) = self.queue.snapshot();
                {
                    let mut state = self.state.write().unwrap_or_else(|e| e.into_inner());
                    state.queue = crate::state::QueueState {
                        songs: queue,
                        index,
                    };
                    state.playback.state = PlayerState::Playing;
                    state.playback.song = Some(resolved_song.clone());
                    state.playback.generation = generation;
                    state.playback.volume = self.playback.volume();
                }
                self.emit(ApplicationEvent::PlaybackStarted {
                    request_id,
                    song: resolved_song.clone(),
                    source_index: self.playback.source_index(),
                });
                self.publish_queue();
                let lyrics = self.lyrics.clone();
                let events = self.events.clone();
                let state = Arc::clone(&self.state);
                spawn_reported(events.clone(), "歌词加载", async move {
                    match lyrics.load(&resolved_song, generation).await {
                        Ok(value) => {
                            state.write().unwrap_or_else(|e| e.into_inner()).lyrics = Some(value);
                            let _ = events.send(ApplicationEvent::LyricsChanged {
                                song_id: resolved_song.id.clone(),
                            });
                        }
                        Err(error) => {
                            let _ = events.send(ApplicationEvent::Notification {
                                message: format!("歌词加载失败: {error}"),
                            });
                        }
                    }
                });
                Ok(())
            }
            Err(error) => {
                self.emit(ApplicationEvent::PlaybackFailed {
                    request_id,
                    error: error.clone(),
                });
                Err(error)
            }
        }
    }

    fn publish_queue(&self) {
        let (songs, index) = self.queue.snapshot();
        self.state.write().unwrap_or_else(|e| e.into_inner()).queue = crate::state::QueueState {
            songs: songs.clone(),
            index,
        };
        self.emit(ApplicationEvent::QueueChanged {
            queue: songs,
            index,
        });
    }

    fn publish_playlists(&self) {
        let playlists = self.playlists.snapshot();
        self.state
            .write()
            .unwrap_or_else(|e| e.into_inner())
            .playlists = playlists.clone();
        self.emit(ApplicationEvent::PlaylistChanged { playlists });
    }

    fn emit(&self, event: ApplicationEvent) {
        let is_state = matches!(event, ApplicationEvent::StateChanged(_));
        let _ = self.events.send(event);
        if !is_state {
            let snapshot = self.state();
            let _ = self
                .events
                .send(ApplicationEvent::StateChanged(Box::new(snapshot)));
        }
    }
}

pub struct ApplicationEventStream {
    receiver: broadcast::Receiver<ApplicationEvent>,
}

impl ApplicationEventStream {
    pub async fn recv(&mut self) -> Result<ApplicationEvent, ApplicationEventStreamError> {
        self.receiver
            .recv()
            .await
            .map_err(ApplicationEventStreamError::from)
    }
}

#[derive(Debug, thiserror::Error)]
pub enum ApplicationEventStreamError {
    #[error("application event stream lagged by {0} events")]
    Lagged(u64),
    #[error("application event stream closed")]
    Closed,
}

impl From<broadcast::error::RecvError> for ApplicationEventStreamError {
    fn from(value: broadcast::error::RecvError) -> Self {
        match value {
            broadcast::error::RecvError::Lagged(value) => Self::Lagged(value),
            broadcast::error::RecvError::Closed => Self::Closed,
        }
    }
}

/// 远程缓存里的账号歌单 → 浏览数据面的 `Playlist`（不含红心集合）。
///
/// 返回 `None` 表示该平台没有镜像槽位（当前只有网易云 / QQ 音乐），
/// 与「有槽位但缓存为空」区分开：前者走能力提示，后者走空态。
fn account_playlists(
    source: lx_core::model::source::SourceId,
) -> Option<Vec<lx_core::model::playlist::Playlist>> {
    crate::remote_cache::with_source(source, account_playlists_from)
}

/// 纯映射：只保留普通歌单（红心集合归收藏页），封面取第一首歌的封面。
fn account_playlists_from(
    collections: &[lx_core::sync::SyncCollection],
) -> Vec<lx_core::model::playlist::Playlist> {
    collections
        .iter()
        .filter(|collection| collection.kind == lx_core::sync::SyncCollectionKind::Playlist)
        .map(|collection| lx_core::model::playlist::Playlist {
            id: collection.id.clone(),
            name: collection.name.clone(),
            source: collection.source,
            cover_url: collection
                .songs
                .first()
                .and_then(|song| song.cover_url.clone()),
            song_count: collection.songs.len() as u32,
            description: None,
            play_count: None,
            creator: None,
            link: None,
            extra: Default::default(),
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use std::sync::Mutex;

    use lx_core::model::playlist::{CustomPlaylist, CustomPlaylistSummary, Playlist};
    use lx_core::model::song::SongInfo;
    use tokio::sync::broadcast;

    use super::*;
    use crate::ports::LibraryStore;

    #[derive(Default)]
    struct MockLibrary {
        favorites: Mutex<Vec<SongInfo>>,
        custom: Mutex<Vec<CustomPlaylist>>,
    }

    fn song(id: &str) -> SongInfo {
        SongInfo {
            id: id.to_string(),
            source: lx_core::model::source::SourceId::Kw,
            name: format!("song-{id}"),
            singer: "tester".to_string(),
            album_name: String::new(),
            album_id: String::new(),
            duration: std::time::Duration::ZERO,
            cover_url: None,
            qualities: Default::default(),
            audio: None,
            extra: Default::default(),
            toggle_source: None,
            file_ext: None,
            file_path: None,
        }
    }

    impl LibraryStore for MockLibrary {
        fn favorites(&self) -> Vec<SongInfo> {
            self.favorites
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .clone()
        }
        fn add_favorite(&self, song: &SongInfo) -> bool {
            let mut list = self.favorites.lock().unwrap_or_else(|e| e.into_inner());
            if list.iter().any(|item| item.id == song.id) {
                return false;
            }
            list.push(song.clone());
            true
        }
        fn remove_favorite(&self, song: &SongInfo) -> bool {
            let mut list = self.favorites.lock().unwrap_or_else(|e| e.into_inner());
            let old = list.len();
            list.retain(|item| item.id != song.id);
            list.len() != old
        }
        fn is_favorite(&self, song: &SongInfo) -> bool {
            self.favorites
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .iter()
                .any(|item| item.id == song.id)
        }
        fn favorite_playlists(&self) -> Vec<Playlist> {
            vec![]
        }
        fn add_favorite_playlist(&self, _playlist: &Playlist) -> bool {
            true
        }
        fn remove_favorite_playlist(&self, _playlist: &Playlist) -> bool {
            true
        }
        fn history(&self) -> Vec<SongInfo> {
            vec![]
        }
        fn remove_history(&self, _song: &SongInfo) -> bool {
            true
        }
        fn clear_history(&self) -> bool {
            true
        }
        fn custom_playlist_summaries(&self) -> Vec<CustomPlaylistSummary> {
            self.custom
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .iter()
                .map(|playlist| CustomPlaylistSummary {
                    id: playlist.id.clone(),
                    name: playlist.name.clone(),
                    cover_url: None,
                    song_count: playlist.songs.len() as u32,
                })
                .collect()
        }
        fn custom_playlist(&self, id: &str) -> Option<CustomPlaylist> {
            self.custom
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .iter()
                .find(|playlist| playlist.id == id)
                .cloned()
        }
        fn create_custom_playlist(&self, name: &str) -> Result<CustomPlaylist, String> {
            let mut list = self.custom.lock().unwrap_or_else(|e| e.into_inner());
            let playlist = CustomPlaylist {
                id: format!("custom-{}", list.len() + 1),
                name: name.to_string(),
                songs: vec![],
                created_at_unix_nanos: 0,
                updated_at_unix_nanos: 0,
            };
            list.push(playlist.clone());
            Ok(playlist)
        }
        fn rename_custom_playlist(&self, _id: &str, _name: &str) -> Result<(), String> {
            Err("not implemented".into())
        }
        fn delete_custom_playlist(&self, _id: &str) -> Result<bool, String> {
            Err("not implemented".into())
        }
        fn add_song_to_custom_playlist(&self, id: &str, song: &SongInfo) -> Result<bool, String> {
            self.add_songs_to_custom_playlist(id, std::slice::from_ref(song))
                .map(|(added, _)| added > 0)
        }
        fn add_songs_to_custom_playlist(
            &self,
            id: &str,
            songs: &[SongInfo],
        ) -> Result<(usize, usize), String> {
            let mut list = self.custom.lock().unwrap_or_else(|e| e.into_inner());
            let playlist = list
                .iter_mut()
                .find(|playlist| playlist.id == id)
                .ok_or_else(|| "自定义歌单不存在".to_string())?;
            let before = playlist.songs.len();
            for song in songs {
                if !playlist
                    .songs
                    .iter()
                    .any(|item| item.id == song.id && item.source == song.source)
                {
                    playlist.songs.push(song.clone());
                }
            }
            let added = playlist.songs.len() - before;
            Ok((added, songs.len() - added))
        }
        fn remove_song_from_custom_playlist(
            &self,
            _id: &str,
            _song: &SongInfo,
        ) -> Result<bool, String> {
            Err("not implemented".into())
        }
    }

    fn service_with_library() -> (ApplicationService, broadcast::Receiver<ApplicationEvent>) {
        let (events, receiver) = broadcast::channel(64);
        let mut service = test_service();
        service.library = Some(Arc::new(MockLibrary::default()));
        // 重建广播通道（test_service 里已经建了一个），保证 receiver 能收到
        service.events = events;
        (service, receiver)
    }

    fn test_service() -> ApplicationService {
        let player: Arc<dyn PlayerBackend> = crate::services::test_support::null_player();
        let sources = Arc::new(SourceManager::new(
            lx_core::model::source::SourceId::Kw,
            &[lx_core::model::source::SourceId::Kw],
        ));
        let lyrics = Arc::new(LyricService::new(Arc::new(
            lx_lyric::fetcher::SourceLyricFetcher::new(Arc::clone(&sources)),
        )));
        let effects: Arc<dyn crate::services::PlaybackEffects> =
            Arc::new(crate::services::test_support::NullEffects);
        ApplicationService::new(player, sources, lyrics, effects, None, None, None)
    }

    /// P0-02 回归：泵启动（tokio 上下文内）→ position/duration watcher 变化
    /// → PlaybackProgress 事件按 4Hz 节流广播。运行环境无 tokio 上下文时泵
    /// 静默不启动（修复前的桌面路径），本测试因收不到事件而失败。
    #[tokio::test]
    async fn playback_pump_broadcasts_progress_for_watch_changes() {
        let player = crate::services::test_support::manual_player();
        let sources = Arc::new(SourceManager::new(
            lx_core::model::source::SourceId::Kw,
            &[lx_core::model::source::SourceId::Kw],
        ));
        let lyrics = Arc::new(LyricService::new(Arc::new(
            lx_lyric::fetcher::SourceLyricFetcher::new(Arc::clone(&sources)),
        )));
        let effects: Arc<dyn crate::services::PlaybackEffects> =
            Arc::new(crate::services::test_support::NullEffects);
        let service = ApplicationService::new(
            Arc::clone(&player) as Arc<dyn PlayerBackend>,
            Arc::clone(&sources),
            lyrics,
            effects,
            None,
            None,
            None,
        );
        let mut receiver = service.subscribe();

        service.start_playback_pump();
        player.push_duration(Duration::from_secs(200));
        player.push_position(Duration::from_millis(1500));

        // 泵以 250ms 节流；首推在节流窗口内可能被抑制，等窗口过后再推一次。
        tokio::time::sleep(Duration::from_millis(300)).await;
        player.push_position(Duration::from_millis(1800));

        let deadline = tokio::time::Instant::now() + Duration::from_secs(3);
        let mut progress_seen = None;
        while tokio::time::Instant::now() < deadline {
            match tokio::time::timeout(Duration::from_millis(300), receiver.recv()).await {
                Ok(Ok(ApplicationEvent::PlaybackProgress { position, .. })) => {
                    progress_seen = Some(position);
                    break;
                }
                Ok(Ok(_)) => continue,
                Ok(Err(_)) | Err(_) => break,
            }
        }
        let position =
            progress_seen.expect("P0-02：泵应把 position watcher 变化广播为 PlaybackProgress");
        // 250ms 节流窗口内首推可能先于窗口过期而即时广播（state/首次变更语义），
        // 因此只断言「事件携带的是推送后的真实位置」，不断言具体哪一次推送。
        assert!(
            position >= Duration::from_millis(1500),
            "广播的位置应来自推送的 watcher 值，实际 {position:?}"
        );
    }

    #[tokio::test]
    async fn favorites_add_and_remove_flow_through_the_port() {
        let (service, mut receiver) = service_with_library();

        service
            .dispatch(ApplicationCommand::FavoritesAdd { song: song("1") })
            .await
            .unwrap();
        assert_eq!(service.state().favorites.len(), 1);

        // LibraryChanged 事件按序到达
        let mut saw_library = false;
        while let Ok(event) = receiver.try_recv() {
            if matches!(event, ApplicationEvent::LibraryChanged) {
                saw_library = true;
                break;
            }
        }
        assert!(saw_library, "收藏变更应发出 LibraryChanged");

        service
            .dispatch(ApplicationCommand::FavoritesRemove { song: song("1") })
            .await
            .unwrap();
        assert!(service.state().favorites.is_empty());
    }

    #[tokio::test]
    async fn library_commands_fail_cleanly_without_a_store() {
        let service = test_service();
        let error = service
            .dispatch(ApplicationCommand::FavoritesAdd { song: song("1") })
            .await
            .unwrap_err();
        assert_eq!(error, "本地存储不可用");
    }

    #[tokio::test]
    async fn custom_playlist_create_and_detail_round_trip() {
        let (events, mut receiver) = broadcast::channel(256);
        let mut service = test_service();
        service.library = Some(Arc::new(MockLibrary::default()));
        service.events = events;

        service
            .dispatch(ApplicationCommand::CustomPlaylistCreate {
                name: "通勤".into(),
            })
            .await
            .unwrap();

        // 快照同步刷新，创建事件带回 id（前端据此「新建并立即加歌」）。
        assert_eq!(service.state().custom_playlists.len(), 1);
        let mut created_id = None;
        while let Ok(event) = receiver.try_recv() {
            if let ApplicationEvent::CustomPlaylistCreated { id, name } = event {
                assert_eq!(name, "通勤");
                created_id = Some(id);
            }
        }
        let id = created_id.expect("创建事件应带回 id");

        service
            .dispatch(ApplicationCommand::CustomPlaylistAddSongs {
                id: id.clone(),
                songs: vec![song("1"), song("2")],
            })
            .await
            .unwrap();
        while receiver.try_recv().is_ok() {}

        service
            .dispatch(ApplicationCommand::CustomPlaylistDetail { id: id.clone() })
            .await
            .unwrap();

        let mut detail = None;
        while let Ok(event) = receiver.try_recv() {
            if let ApplicationEvent::BrowseLoaded {
                kind,
                source,
                id: event_id,
                items,
                ..
            } = event
            {
                assert_eq!(kind, BrowseKind::CustomPlaylist);
                assert_eq!(source, lx_core::model::source::SourceId::Local);
                assert_eq!(event_id, id);
                detail = Some(items);
            }
        }
        let songs = detail.expect("详情应发出 BrowseLoaded");
        assert_eq!(songs.len(), 2);
    }

    #[tokio::test]
    async fn custom_playlist_detail_missing_emits_browse_failed() {
        let (service, mut receiver) = service_with_library();
        service
            .dispatch(ApplicationCommand::CustomPlaylistDetail {
                id: "missing".into(),
            })
            .await
            .unwrap();

        let mut failed = false;
        while let Ok(event) = receiver.try_recv() {
            if let ApplicationEvent::BrowseFailed {
                kind,
                source,
                error,
                ..
            } = event
            {
                assert_eq!(kind, BrowseKind::CustomPlaylist);
                assert_eq!(source, lx_core::model::source::SourceId::Local);
                assert!(error.contains("不存在"), "错误信息应说明歌单不存在");
                failed = true;
            }
        }
        assert!(failed, "缺失歌单应发出 BrowseFailed");
    }

    #[test]
    fn account_playlists_mapping_drops_favorites_and_keeps_counts() {
        use lx_core::model::source::SourceId;
        use lx_core::sync::{SyncCollection, SyncCollectionKind};

        let collection = |kind, id: &str, name: &str, songs: usize| SyncCollection {
            kind,
            id: id.to_string(),
            name: name.to_string(),
            source: SourceId::Wy,
            songs: (0..songs)
                .map(|index| song(&format!("{id}-{index}")))
                .collect(),
        };
        let mapped = account_playlists_from(&[
            collection(SyncCollectionKind::Playlist, "p1", "通勤", 2),
            collection(SyncCollectionKind::Favorites, "fav", "我喜欢的音乐", 5),
        ]);

        assert_eq!(mapped.len(), 1, "红心集合不进账号歌单列表");
        assert_eq!(mapped[0].id, "p1");
        assert_eq!(mapped[0].name, "通勤");
        assert_eq!(mapped[0].song_count, 2);
        assert_eq!(mapped[0].source, SourceId::Wy);
    }
}
