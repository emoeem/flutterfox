//! Flutter <-> Rust boundary for Voicefox.
//!
//! This crate deliberately contains no TUI code and does not expose Rust
//! synchronization primitives, player backends, or source-manager internals.
//! The actual platform bootstrap is supplied by the host/runtime layer.

mod frb_generated;

use std::sync::Arc;
use std::time::Duration;

use lx_core::model::song::SongInfo;
use voicefox_application::{
    ApplicationCommand, ApplicationEvent, ApplicationEventKind, ApplicationService,
};

pub mod api;

#[derive(Debug, Clone)]
pub struct SongDto {
    pub id: String,
    pub source: String,
    pub name: String,
    pub singer: String,
    pub album_name: String,
    pub duration_ms: u64,
    pub cover_url: Option<String>,
}

impl From<SongInfo> for SongDto {
    fn from(song: SongInfo) -> Self {
        Self {
            id: song.id,
            source: song.source.as_str().to_string(),
            name: song.name,
            singer: song.singer,
            album_name: song.album_name,
            duration_ms: song.duration.as_millis() as u64,
            cover_url: song.cover_url,
        }
    }
}

/// 音源字符串 → SourceId（SongDto 与 QrLoginStart 共用）。
pub(crate) fn parse_source(value: &str) -> Result<lx_core::model::source::SourceId, String> {
    use lx_core::model::source::SourceId;
    match value {
        "kw" => Ok(SourceId::Kw),
        "kg" => Ok(SourceId::Kg),
        "tx" => Ok(SourceId::Tx),
        "wy" => Ok(SourceId::Wy),
        "mg" => Ok(SourceId::Mg),
        "bili" => Ok(SourceId::Bili),
        "soda" => Ok(SourceId::Soda),
        "qianqian" => Ok(SourceId::Qianqian),
        "joox" => Ok(SourceId::Joox),
        "jamendo" => Ok(SourceId::Jamendo),
        "fivesing" => Ok(SourceId::Fivesing),
        "apple" => Ok(SourceId::Apple),
        "local" => Ok(SourceId::Local),
        other => Err(format!("unknown source: {other}")),
    }
}

impl SongDto {
    fn into_song(self) -> Result<SongInfo, String> {
        let source = parse_source(&self.source)?;
        let mut song = SongInfo::new(self.id, source, self.name, self.singer);
        song.album_name = self.album_name;
        song.duration = Duration::from_millis(self.duration_ms);
        song.cover_url = self.cover_url;
        Ok(song)
    }
}

pub struct VoicefoxState {
    pub playback: PlaybackDto,
    pub queue: Vec<SongDto>,
    pub queue_index: u32,
    pub search: SearchDto,
    pub lyrics: LyricsDto,
    pub playlists: Vec<PlaylistDto>,
    pub favorites: Vec<SongDto>,
    pub favorite_playlists: Vec<PlaylistDto>,
    pub history: Vec<SongDto>,
    pub custom_playlists: Vec<CustomPlaylistSummaryDto>,
    pub downloads: Vec<DownloadTaskDto>,
}

#[derive(Debug, Clone)]
pub struct CustomPlaylistSummaryDto {
    pub id: String,
    pub name: String,
    pub cover_url: Option<String>,
    pub song_count: u32,
}

#[derive(Debug, Clone)]
pub struct DownloadTaskDto {
    pub id: u64,
    pub name: String,
    pub singer: String,
    pub source: String,
    pub quality: String,
    pub dest: String,
    pub state: String,
    pub active: bool,
    pub downloaded: u64,
    pub total: Option<u64>,
    pub error: Option<String>,
    pub trigger_auto_cache: bool,
}

/// 配置的 FFI 子集镜像：只覆盖 GUI 设置页 v1 编辑面。
/// 回写时打在「当前完整配置」上，未镜像字段（keybindings/local_music 等）原样保留。
#[derive(Debug, Clone)]
pub struct ConfigDto {
    pub theme: String,
    pub volume: u32,
    pub playback_speed: f64,
    pub play_mode: String,
    pub history_limit: u32,
    pub default_source: String,
    pub enabled_sources: Vec<String>,
    pub js_sources_first: bool,
    pub download_dir: String,
    pub download_quality: Option<String>,
    pub download_concurrency: u32,
    pub show_translation: bool,
    pub show_yrc: bool,
    pub lyric_offset_ms: i32,
    pub proxy_url: String,
    pub network_timeout_secs: u64,
}

impl ConfigDto {
    fn from_config(config: &lx_core::model::config::Config) -> Self {
        Self {
            theme: config.theme.name.clone(),
            volume: config.player.volume,
            playback_speed: config.player.playback_speed,
            play_mode: format!("{:?}", config.player.play_mode).to_lowercase(),
            history_limit: config.player.history_limit as u32,
            default_source: config.source.default.as_str().to_string(),
            enabled_sources: config
                .source
                .enabled
                .iter()
                .map(|source| source.as_str().to_string())
                .collect(),
            js_sources_first: config.source.js_first,
            download_dir: config.download.dir.clone(),
            download_quality: config
                .download
                .quality
                .map(|quality| format!("{:?}", quality)),
            download_concurrency: config.download.concurrent_songs as u32,
            show_translation: config.lyric.show_translation,
            show_yrc: config.lyric.show_yrc,
            lyric_offset_ms: config.lyric.offset,
            proxy_url: config.network.proxy_url.clone(),
            network_timeout_secs: config.network.timeout,
        }
    }

    /// 把子集字段落回完整配置：以 `base` 为底，未镜像字段原样保留。
    fn apply_to(self, base: &lx_core::model::config::Config) -> lx_core::model::config::Config {
        use lx_core::model::source::SourceId;
        let mut config = base.clone();
        config.theme.name = self.theme;
        config.player.volume = self.volume;
        config.player.playback_speed = self.playback_speed;
        // play_mode 在配置里就是字符串（"list-loop"/"single-loop"/"random"/"none"）
        config.player.play_mode = self.play_mode;
        config.player.history_limit = self.history_limit as usize;
        config.source.default = parse_source(&self.default_source)
            .unwrap_or(base.source.default);
        config.source.enabled = self
            .enabled_sources
            .iter()
            .filter_map(|source| parse_source(source).ok())
            .collect::<Vec<SourceId>>();
        config.source.js_first = self.js_sources_first;
        config.download.dir = self.download_dir;
        config.download.quality = self.download_quality.and_then(|quality| match quality.as_str() {
            "high320" | "320k" => Some(lx_core::model::source::Quality::High320),
            "flac" => Some(lx_core::model::source::Quality::Flac),
            "flac24bit" => Some(lx_core::model::source::Quality::Flac24),
            _ => Some(lx_core::model::source::Quality::Low128),
        });
        config.download.concurrent_songs = self.download_concurrency as usize;
        config.lyric.show_translation = self.show_translation;
        config.lyric.show_yrc = self.show_yrc;
        config.lyric.offset = self.lyric_offset_ms;
        config.network.proxy_url = self.proxy_url;
        config.network.timeout = self.network_timeout_secs;
        config
    }
}

#[derive(Debug, Clone)]
pub struct QrLoginSessionDto {
    pub source: String,
    pub kind: String,
    pub key: String,
    pub url: String,
    pub image_png_base64: Option<String>,
    pub expires_in: u64,
}

#[derive(Debug, Clone)]
pub struct SearchDto {
    pub keyword: String,
    pub page: u32,
    pub has_more: bool,
    pub items: Vec<SongDto>,
    pub request_id: u64,
}

#[derive(Debug, Clone)]
pub struct LyricLineDto {
    pub timestamp_ms: u64,
    pub duration_ms: u64,
    pub text: String,
}

#[derive(Debug, Clone, Default)]
pub struct LyricsDto {
    pub current_line: u32,
    pub position_ms: u64,
    pub lines: Vec<LyricLineDto>,
    pub translation: Option<String>,
    pub is_empty: bool,
}

#[derive(Debug, Clone)]
pub struct PlaylistDto {
    pub id: String,
    pub name: String,
    pub source: String,
    pub cover_url: Option<String>,
    pub song_count: u32,
    pub description: Option<String>,
}

impl PlaylistDto {
    fn into_playlist(self) -> Result<lx_core::model::playlist::Playlist, String> {
        let source = parse_source(&self.source)?;
        Ok(lx_core::model::playlist::Playlist {
            id: self.id,
            name: self.name,
            source,
            cover_url: self.cover_url,
            song_count: self.song_count,
            description: self.description,
            play_count: None,
            creator: None,
            link: None,
            extra: Default::default(),
        })
    }
}

#[derive(Debug, Clone)]
pub struct PlaybackDto {
    pub state: String,
    pub song: Option<SongDto>,
    pub position_ms: u64,
    pub duration_ms: u64,
    pub volume: u32,
    pub generation: u64,
}

impl From<voicefox_application::ApplicationState> for VoicefoxState {
    fn from(value: voicefox_application::ApplicationState) -> Self {
        let lyrics = value
            .lyrics
            .as_ref()
            .map(|state| LyricsDto {
                current_line: state.current_line as u32,
                position_ms: state.position_ms,
                lines: state
                    .lines
                    .iter()
                    .map(|line| LyricLineDto {
                        timestamp_ms: line.timestamp,
                        duration_ms: line.duration,
                        text: line.text.clone(),
                    })
                    .collect(),
                translation: state.translation.clone(),
                is_empty: state.is_empty,
            })
            .unwrap_or_default();
        Self {
            playback: PlaybackDto {
                state: format!("{:?}", value.playback.state).to_lowercase(),
                song: value.playback.song.map(Into::into),
                position_ms: value.playback.position.as_millis() as u64,
                duration_ms: value.playback.duration.as_millis() as u64,
                volume: value.playback.volume,
                generation: value.playback.generation,
            },
            queue: value.queue.songs.into_iter().map(Into::into).collect(),
            queue_index: value.queue.index as u32,
            search: SearchDto {
                keyword: value.search.keyword,
                page: value.search.page,
                has_more: value.search.has_more,
                items: value.search.items.into_iter().map(Into::into).collect(),
                request_id: value.search.request_id,
            },
            lyrics,
            playlists: value
                .playlists
                .into_iter()
                .map(|playlist| PlaylistDto {
                    id: playlist.id,
                    name: playlist.name,
                    source: playlist.source.as_str().to_string(),
                    cover_url: playlist.cover_url,
                    song_count: playlist.song_count,
                    description: playlist.description,
                })
                .collect(),
            favorites: value.favorites.into_iter().map(Into::into).collect(),
            favorite_playlists: value
                .favorite_playlists
                .into_iter()
                .map(|playlist| PlaylistDto {
                    id: playlist.id,
                    name: playlist.name,
                    source: playlist.source.as_str().to_string(),
                    cover_url: playlist.cover_url,
                    song_count: playlist.song_count,
                    description: playlist.description,
                })
                .collect(),
            history: value.history.into_iter().map(Into::into).collect(),
            custom_playlists: value
                .custom_playlists
                .into_iter()
                .map(|summary| CustomPlaylistSummaryDto {
                    id: summary.id,
                    name: summary.name,
                    cover_url: summary.cover_url,
                    song_count: summary.song_count,
                })
                .collect(),
            downloads: value
                .downloads
                .into_iter()
                .map(|task| DownloadTaskDto {
                    id: task.id,
                    name: task.name,
                    singer: task.singer,
                    source: task.source.as_str().to_string(),
                    quality: format!("{:?}", task.quality),
                    dest: task.dest,
                    state: task.state,
                    active: task.active,
                    downloaded: task.downloaded,
                    total: task.total,
                    error: task.error,
                    trigger_auto_cache: task.trigger_auto_cache,
                })
                .collect(),
        }
    }
}

#[derive(Debug, Clone)]
pub struct VoicefoxEvent {
    pub kind: String,
    pub request_id: u64,
    pub keyword: Option<String>,
    pub page: u32,
    pub append: bool,
    pub has_more: bool,
    pub message: Option<String>,
    pub song: Option<SongDto>,
    pub items: Vec<SongDto>,
    pub queue: Vec<SongDto>,
    pub queue_index: u32,
    pub qr_session: Option<QrLoginSessionDto>,
    pub status: Option<String>,
    pub user_name: Option<String>,
    pub warnings: Vec<String>,
    pub config: Option<ConfigDto>,
}

impl From<ApplicationEvent> for VoicefoxEvent {
    fn from(value: ApplicationEvent) -> Self {
        let kind = match value.kind() {
            ApplicationEventKind::StateChanged => "state_changed",
            ApplicationEventKind::Search => "search",
            ApplicationEventKind::Playback => "playback",
            ApplicationEventKind::Queue => "queue",
            ApplicationEventKind::Lyrics => "lyrics",
            ApplicationEventKind::Playlist => "playlist",
            ApplicationEventKind::Notification => "notification",
            ApplicationEventKind::Library => "library",
            ApplicationEventKind::Downloads => "downloads",
            ApplicationEventKind::Config => "config",
            ApplicationEventKind::QrLogin => "qr_login",
            ApplicationEventKind::LocalMusic => "local_music",
        }
        .to_string();
        let empty = || Self {
            kind: kind.clone(),
            request_id: 0,
            keyword: None,
            page: 0,
            append: false,
            has_more: false,
            message: None,
            song: None,
            items: vec![],
            queue: vec![],
            queue_index: 0,
            qr_session: None,
            status: None,
            user_name: None,
            warnings: vec![],
            config: None,
        };
        match value {
            ApplicationEvent::SearchStarted {
                request_id,
                keyword,
            } => Self {
                kind,
                request_id,
                keyword: Some(keyword),
                page: 1,
                append: false,
                has_more: false,
                message: None,
                song: None,
                items: vec![],
                queue: vec![],
                queue_index: 0,
                qr_session: None,
                status: None,
                user_name: None,
                warnings: vec![],
                config: None,
            },
            ApplicationEvent::SearchCompleted {
                request_id,
                keyword,
                page,
                append,
                items,
                has_more,
            } => Self {
                kind,
                request_id,
                keyword: Some(keyword),
                page,
                append,
                has_more,
                message: None,
                song: None,
                items: items.into_iter().map(Into::into).collect(),
                queue: vec![],
                queue_index: 0,
                qr_session: None,
                status: None,
                user_name: None,
                warnings: vec![],
                config: None,
            },
            ApplicationEvent::SearchFailed { request_id, error }
            | ApplicationEvent::PlaybackFailed { request_id, error } => {
                let mut event = empty();
                event.kind = kind;
                event.request_id = request_id;
                event.message = Some(error);
                event
            }
            ApplicationEvent::PlaybackStarted {
                request_id, song, ..
            } => Self {
                kind,
                request_id,
                keyword: None,
                page: 0,
                append: false,
                has_more: false,
                message: None,
                song: Some(song.into()),
                items: vec![],
                queue: vec![],
                queue_index: 0,
                qr_session: None,
                status: None,
                user_name: None,
                warnings: vec![],
                config: None,
            },
            ApplicationEvent::QueueChanged { queue, index } => Self {
                kind,
                request_id: 0,
                keyword: None,
                page: 0,
                append: false,
                has_more: false,
                message: None,
                song: None,
                items: vec![],
                queue: queue.into_iter().map(Into::into).collect(),
                queue_index: index as u32,
                qr_session: None,
                status: None,
                user_name: None,
                warnings: vec![],
                config: None,
            },
            ApplicationEvent::Notification { message } => {
                let mut event = empty();
                event.kind = kind;
                event.message = Some(message);
                event
            }
            ApplicationEvent::QrLoginCreated { session } => {
                let mut event = empty();
                event.qr_session = Some(QrLoginSessionDto {
                    source: session.source.as_str().to_string(),
                    kind: format!("{:?}", session.kind).to_lowercase(),
                    key: session.key,
                    url: session.url,
                    image_png_base64: session.image_png,
                    expires_in: session.expires_in,
                });
                event
            }
            ApplicationEvent::QrLoginPolled {
                source,
                status,
                message,
                user_name,
            } => {
                let mut event = empty();
                event.message = Some(message);
                event.status = Some(status);
                event.user_name = user_name;
                event.keyword = Some(source.as_str().to_string());
                event
            }
            ApplicationEvent::LocalScanCompleted { warnings } => {
                let mut event = empty();
                event.warnings = warnings;
                event
            }
            ApplicationEvent::ConfigChanged { config } => {
                let mut event = empty();
                event.config = Some(ConfigDto::from_config(&config));
                event
            }
            ApplicationEvent::LibraryChanged
            | ApplicationEvent::DownloadsChanged
            | ApplicationEvent::StateChanged(_)
            | ApplicationEvent::PlaybackPaused
            | ApplicationEvent::PlaybackResumed
            | ApplicationEvent::PlaybackStopped
            | ApplicationEvent::PlaybackEnded
            | ApplicationEvent::LyricsChanged { .. }
            | ApplicationEvent::PlaylistChanged { .. } => empty(),
        }
    }
}

/// Thread-safe application handle owned by the Flutter-facing layer.
#[derive(Clone)]
pub struct VoicefoxController {
    application: ApplicationService,
    /// 当前完整配置的共享读取口：ConfigUpdate 每次合并都取最新值。
    config_base: Option<Arc<std::sync::RwLock<lx_core::model::config::Config>>>,
}

impl VoicefoxController {
    /// Construct the desktop runtime without depending on the TUI crate.
    #[cfg(feature = "desktop-mpv")]
    pub fn new_desktop() -> Result<Self, String> {
        let (config, path) = voicefox_runtime::load_config().map_err(|e| e.to_string())?;
        let runtime = voicefox_runtime::ApplicationRuntime::desktop(config, path)
            .map_err(|e| e.to_string())?;
        Ok(Self::from_application(runtime.application())
            .with_config_base(Arc::clone(&runtime.config)))
    }

    /// Host bootstrap supplies the already-configured ApplicationService.
    /// This keeps libmpv/native audio selection outside the Flutter ABI.
    pub fn from_application(application: ApplicationService) -> Self {
        Self {
            application,
            config_base: None,
        }
    }

    /// 桌面/宿主引导后调用：注入完整配置的共享读取口（runtime 持有的那份）。
    pub fn with_config_base(
        mut self,
        base: Arc<std::sync::RwLock<lx_core::model::config::Config>>,
    ) -> Self {
        self.config_base = Some(base);
        self
    }

    pub fn state(&self) -> VoicefoxState {
        self.application.state().into()
    }

    pub async fn dispatch(&self, command: FfiCommand) -> Result<(), String> {
        // ConfigUpdate 需要完整配置做底：子集字段打在 config_base 上再下发。
        let application = match command {
            FfiCommand::ConfigUpdate { config } => {
                let base = self
                    .config_base
                    .as_ref()
                    .ok_or_else(|| "配置存储不可用".to_string())?;
                let current = base.read().unwrap_or_else(|e| e.into_inner()).clone();
                ApplicationCommand::ConfigUpdate {
                    config: Box::new(config.apply_to(&current)),
                }
            }
            other => other.into_application()?,
        };
        self.application.dispatch(application).await
    }

    pub fn subscribe(&self) -> VoicefoxEventStream {
        VoicefoxEventStream {
            inner: self.application.subscribe(),
        }
    }
}

pub struct VoicefoxEventStream {
    inner: voicefox_application::ApplicationEventStream,
}

impl VoicefoxEventStream {
    pub async fn next(&mut self) -> Result<VoicefoxEvent, String> {
        self.inner
            .recv()
            .await
            .map(Into::into)
            .map_err(|e| e.to_string())
    }
}

#[derive(Debug, Clone)]
pub enum FfiCommand {
    Pause,
    Resume,
    Toggle,
    Stop,
    SeekMs(u64),
    PlaySong { song: SongDto },
    QueueAdd { song: SongDto, next: bool },
    QueueRemove { index: u32 },
    QueueClear,
    Next,
    Previous,
    Search { keyword: String },
    SearchMore { keyword: String, page: u32 },
    // ── 库（收藏/历史/自定义歌单）──
    LibraryRefresh,
    FavoritesAdd { song: SongDto },
    FavoritesRemove { song: SongDto },
    FavoritePlaylistAdd { playlist: PlaylistDto },
    FavoritePlaylistRemove { playlist: PlaylistDto },
    HistoryRemove { song: SongDto },
    HistoryClear,
    CustomPlaylistCreate { name: String },
    CustomPlaylistRename { id: String, name: String },
    CustomPlaylistDelete { id: String },
    CustomPlaylistAddSongs { id: String, songs: Vec<SongDto> },
    CustomPlaylistRemoveSong { id: String, song: SongDto },
    // ── 配置 ──
    ConfigGet,
    ConfigUpdate { config: ConfigDto },
    // ── 下载 ──
    DownloadEnqueue { song: SongDto },
    DownloadCancel { id: u64 },
    DownloadClearFinished,
    // ── 扫码登录 ──
    QrLoginStart { source: String, kind: String },
    QrLoginCancel,
    // ── 本地扫描 ──
    LocalScan { paths: Vec<String>, max_depth: u32 },
}

impl FfiCommand {
    fn into_application(self) -> Result<ApplicationCommand, String> {
        Ok(match self {
            FfiCommand::Pause => ApplicationCommand::Pause,
            FfiCommand::Resume => ApplicationCommand::Resume,
            FfiCommand::Toggle => ApplicationCommand::Toggle,
            FfiCommand::Stop => ApplicationCommand::Stop,
            FfiCommand::SeekMs(ms) => ApplicationCommand::Seek(Duration::from_millis(ms)),
            FfiCommand::PlaySong { song } => ApplicationCommand::Play {
                songs: vec![song.into_song()?],
                index: 0,
            },
            FfiCommand::QueueAdd { song, next } => ApplicationCommand::QueueAdd {
                song: song.into_song()?,
                next,
            },
            FfiCommand::QueueRemove { index } => ApplicationCommand::QueueRemove {
                index: index as usize,
            },
            FfiCommand::QueueClear => ApplicationCommand::QueueClear,
            FfiCommand::Next => ApplicationCommand::Next,
            FfiCommand::Previous => ApplicationCommand::Previous,
            FfiCommand::Search { keyword } => ApplicationCommand::Search {
                keyword,
                source: None,
            },
            FfiCommand::SearchMore { keyword, page } => ApplicationCommand::SearchMore {
                keyword,
                page,
                source: None,
            },
            FfiCommand::LibraryRefresh => ApplicationCommand::LibraryRefresh,
            FfiCommand::FavoritesAdd { song } => ApplicationCommand::FavoritesAdd {
                song: song.into_song()?,
            },
            FfiCommand::FavoritesRemove { song } => ApplicationCommand::FavoritesRemove {
                song: song.into_song()?,
            },
            FfiCommand::FavoritePlaylistAdd { playlist } => {
                ApplicationCommand::FavoritePlaylistAdd {
                    playlist: playlist.into_playlist()?,
                }
            }
            FfiCommand::FavoritePlaylistRemove { playlist } => {
                ApplicationCommand::FavoritePlaylistRemove {
                    playlist: playlist.into_playlist()?,
                }
            }
            FfiCommand::HistoryRemove { song } => ApplicationCommand::HistoryRemove {
                song: song.into_song()?,
            },
            FfiCommand::HistoryClear => ApplicationCommand::HistoryClear,
            FfiCommand::CustomPlaylistCreate { name } => {
                ApplicationCommand::CustomPlaylistCreate { name }
            }
            FfiCommand::CustomPlaylistRename { id, name } => {
                ApplicationCommand::CustomPlaylistRename { id, name }
            }
            FfiCommand::CustomPlaylistDelete { id } => ApplicationCommand::CustomPlaylistDelete { id },
            FfiCommand::CustomPlaylistAddSongs { id, songs } => {
                let mut converted = Vec::with_capacity(songs.len());
                for song in songs {
                    converted.push(song.into_song()?);
                }
                ApplicationCommand::CustomPlaylistAddSongs {
                    id,
                    songs: converted,
                }
            }
            FfiCommand::CustomPlaylistRemoveSong { id, song } => {
                ApplicationCommand::CustomPlaylistRemoveSong {
                    id,
                    song: song.into_song()?,
                }
            }
            FfiCommand::ConfigGet => ApplicationCommand::ConfigGet,
            FfiCommand::DownloadEnqueue { song } => ApplicationCommand::DownloadEnqueue {
                song: song.into_song()?,
            },
            FfiCommand::DownloadCancel { id } => ApplicationCommand::DownloadCancel { id },
            FfiCommand::DownloadClearFinished => ApplicationCommand::DownloadClearFinished,
            FfiCommand::QrLoginStart { source, kind } => ApplicationCommand::QrLoginStart {
                source: parse_source(&source)?,
                kind: match kind.as_str() {
                    "wechat" => lx_core::model::login::QrLoginKind::WeChat,
                    _ => lx_core::model::login::QrLoginKind::Standard,
                },
            },
            FfiCommand::QrLoginCancel => ApplicationCommand::QrLoginCancel,
            FfiCommand::LocalScan { paths, max_depth } => ApplicationCommand::LocalScan {
                paths,
                max_depth,
            },
            // ConfigUpdate 在 VoicefoxController::dispatch 里特判（需要 config_base）
            FfiCommand::ConfigUpdate { .. } => unreachable!("handled in VoicefoxController::dispatch"),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use voicefox_application::ApplicationEvent;

    #[test]
    fn playback_event_maps_to_stable_ffi_shape() {
        let event = VoicefoxEvent::from(ApplicationEvent::PlaybackStarted {
            request_id: 42,
            song: SongInfo::new(
                "test".into(),
                lx_core::model::source::SourceId::Kw,
                "Test".into(),
                "Artist".into(),
            ),
            source_index: Some(3),
        });
        assert_eq!(event.kind, "playback");
        assert_eq!(event.request_id, 42);
        assert!(event.song.is_some());
    }

    #[test]
    fn command_mapping_does_not_expose_application_types() {
        let command = FfiCommand::SeekMs(1_250);
        assert!(
            matches!(command.into_application().unwrap(), ApplicationCommand::Seek(d) if d == Duration::from_millis(1_250))
        );
    }
}
