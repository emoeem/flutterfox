use std::future::Future;
use std::sync::{
    Arc, RwLock,
    atomic::{AtomicU64, Ordering},
};

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
use lx_core::traits::player::PlayerBackend;
use lx_lyric::service::LyricService;
use lx_source::manager::SourceManager;
use tokio::sync::broadcast;

use crate::event::{ApplicationCommand, ApplicationEvent};
use crate::ports::{ConfigStore, DownloadsEngine, DownloadTaskInfo, LibraryStore};
use crate::services::{
    LyricsService, PlaybackService, PlaylistService, QueueService, SearchService,
};
use crate::state::ApplicationState;

const EVENT_CAPACITY: usize = 256;

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
    request_id: Arc<AtomicU64>,
    playback_request_id: Arc<AtomicU64>,
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
            request_id: Arc::new(AtomicU64::new(0)),
            playback_request_id: Arc::new(AtomicU64::new(0)),
        }
    }

    pub fn subscribe(&self) -> ApplicationEventStream {
        ApplicationEventStream {
            receiver: self.events.subscribe(),
        }
    }

    pub fn state(&self) -> ApplicationState {
        self.state.read().unwrap_or_else(|e| e.into_inner()).clone()
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
                let next = (index + 1) % songs.len();
                self.play(songs, next).await
            }
            ApplicationCommand::Previous => {
                let (songs, index) = self.queue.snapshot();
                if songs.is_empty() {
                    return Ok(());
                }
                let len = songs.len();
                let previous = if index == 0 { len - 1 } else { index - 1 };
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
                let result = store.create_custom_playlist(&name).map(|_| ());
                if result.is_ok() {
                    self.publish_library();
                }
                result
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
                            message: format!(
                                "已加入 {added}/{count} 首（重复跳过 {skipped}）"
                            ),
                        });
                        Ok(())
                    }
                    Err(error) => Err(error),
                }
            }
            ApplicationCommand::CustomPlaylistRemoveSong { id, song } => {
                let store = self.library()?;
                let result = store.remove_song_from_custom_playlist(&id, &song).map(|_| ());
                if result.is_ok() {
                    self.publish_library();
                }
                result
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
                    let result =
                        tokio::task::spawn_blocking(move || local.scan(&paths, max_depth))
                            .await
                            .unwrap_or_default();
                    let _ = events.send(ApplicationEvent::LocalScanCompleted {
                        warnings: result,
                    });
                });
                Ok(())
            }
        }
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
        {
            let mut state = self.state.write().unwrap_or_else(|e| e.into_inner());
            state.search.keyword = keyword.clone();
            state.search.source = source;
            state.search.page = page;
            state.search.request_id = request_id;
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
            match search.search(&keyword, page, source).await {
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
                    let _ = events.send(ApplicationEvent::SearchFailed { request_id, error });
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
            self.favorites.lock().unwrap_or_else(|e| e.into_inner()).clone()
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
            vec![]
        }
        fn custom_playlist(&self, _id: &str) -> Option<CustomPlaylist> {
            None
        }
        fn create_custom_playlist(&self, _name: &str) -> Result<CustomPlaylist, String> {
            Err("not implemented".into())
        }
        fn rename_custom_playlist(&self, _id: &str, _name: &str) -> Result<(), String> {
            Err("not implemented".into())
        }
        fn delete_custom_playlist(&self, _id: &str) -> Result<bool, String> {
            Err("not implemented".into())
        }
        fn add_song_to_custom_playlist(
            &self,
            _id: &str,
            _song: &SongInfo,
        ) -> Result<bool, String> {
            Err("not implemented".into())
        }
        fn add_songs_to_custom_playlist(
            &self,
            _id: &str,
            _songs: &[SongInfo],
        ) -> Result<(usize, usize), String> {
            Err("not implemented".into())
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
}
