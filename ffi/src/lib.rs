//! Flutter <-> Rust boundary for Voicefox.
//!
//! This crate deliberately contains no TUI code and does not expose Rust
//! synchronization primitives, player backends, or source-manager internals.
//! The actual platform bootstrap is supplied by the host/runtime layer.

mod frb_generated;

pub mod crash_log;

use std::sync::Arc;
use std::time::Duration;

use lx_core::model::song::SongInfo;
use lx_core::traits::player::PlayerBackend;
use voicefox_application::{
    ApplicationCommand, ApplicationEvent, ApplicationEventKind, ApplicationService,
    HostPlayerBackend, HostPlayerCommand,
};

pub mod api;

#[derive(Debug, Clone)]
pub struct SongDto {
    pub id: String,
    pub source: String,
    pub name: String,
    pub singer: String,
    /// 稳定的歌手 ID；音源未提供时为空，UI 回退到展示名。
    pub artist_id: Option<String>,
    pub album_name: String,
    /// 稳定的专辑 ID；音源未提供时为空，UI 回退到展示名。
    pub album_id: Option<String>,
    pub duration_ms: u64,
    pub cover_url: Option<String>,
}

impl From<SongInfo> for SongDto {
    fn from(song: SongInfo) -> Self {
        let artist_id = song
            .extra
            .get("artist_id")
            .map(|value| value.trim().to_string())
            .filter(|value| !value.is_empty());
        let album_id = {
            let value = song.album_id.trim();
            (!value.is_empty()).then(|| value.to_string())
        };
        Self {
            id: song.id,
            source: song.source.as_str().to_string(),
            name: song.name,
            singer: song.singer,
            artist_id,
            album_name: song.album_name,
            album_id,
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
        if let Some(album_id) = self.album_id.filter(|value| !value.trim().is_empty()) {
            song.album_id = album_id;
        }
        if let Some(artist_id) = self.artist_id.filter(|value| !value.trim().is_empty()) {
            song.extra.insert("artist_id".to_string(), artist_id);
        }
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
    /// 已启用在线音源的能力声明（歌单/排行榜/歌手/专辑入口判定）。
    pub sources: Vec<SourceCapabilitiesDto>,
    /// 本地扫描结果（直接读 SourceManager 的本地曲库快照）。
    pub local_songs: Vec<SongDto>,
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
    /// 完整歌曲载荷：失败/取消任务的「重试」按钮用它重新入队。
    pub song: SongDto,
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
    pub dynamic_color: bool,
    /// GUI 明暗三态（`system`/`light`/`dark`），镜像 `theme.mode`。
    pub theme_mode: String,
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
    /// 本地音乐目录与扫描深度（只读镜像，供本地音乐页触发扫描）。
    pub local_music_enabled: bool,
    pub local_music_paths: Vec<String>,
    pub local_music_max_depth: u32,
}

impl ConfigDto {
    fn from_config(config: &lx_core::model::config::Config) -> Self {
        Self {
            theme: config.theme.name.clone(),
            dynamic_color: config.theme.dynamic_color,
            theme_mode: config.theme.mode.clone(),
            volume: config.player.volume,
            playback_speed: config.player.playback_speed,
            // play_mode 在配置里本身就是字符串（"list-loop" 等）。此前用
            // Debug 格式化会带出引号，回写时把引号写进配置，每保存一次再叠一层。
            play_mode: config.player.play_mode.clone(),
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
                .map(|quality| quality_token(quality).to_string()),
            download_concurrency: config.download.concurrent_songs as u32,
            show_translation: config.lyric.show_translation,
            show_yrc: config.lyric.show_yrc,
            lyric_offset_ms: config.lyric.offset,
            proxy_url: config.network.proxy_url.clone(),
            network_timeout_secs: config.network.timeout,
            local_music_enabled: config.local_music.enabled,
            local_music_paths: config.local_music.paths.clone(),
            local_music_max_depth: config.local_music.max_depth,
        }
    }

    /// 把子集字段落回完整配置：以 `base` 为底，未镜像字段原样保留。
    fn apply_to(self, base: &lx_core::model::config::Config) -> lx_core::model::config::Config {
        use lx_core::model::source::SourceId;
        let mut config = base.clone();
        config.theme.name = self.theme;
        config.theme.dynamic_color = self.dynamic_color;
        // 明暗三态必须是合法 token；未知值保留原配置。
        config.theme.mode = match self.theme_mode.as_str() {
            "system" | "light" | "dark" => self.theme_mode.clone(),
            _ => base.theme.mode.clone(),
        };
        config.player.volume = self.volume;
        config.player.playback_speed = self.playback_speed;
        // play_mode 必须是四个合法 token 之一；未知值保留原配置，避免把
        // 历史脏数据（引号叠加）继续写回去。
        config.player.play_mode = match self.play_mode.as_str() {
            "none" | "list-loop" | "single-loop" | "random" => self.play_mode.clone(),
            _ => base.player.play_mode.clone(),
        };
        config.player.history_limit = self.history_limit as usize;
        config.source.default = parse_source(&self.default_source).unwrap_or(base.source.default);
        config.source.enabled = self
            .enabled_sources
            .iter()
            .filter_map(|source| parse_source(source).ok())
            .collect::<Vec<SourceId>>();
        config.source.js_first = self.js_sources_first;
        config.download.dir = self.download_dir;
        config.download.quality = self.download_quality.as_deref().map(|quality| {
            match quality {
                "128k" | "low128" => lx_core::model::source::Quality::Low128,
                "320k" | "high320" => lx_core::model::source::Quality::High320,
                "flac" => lx_core::model::source::Quality::Flac,
                "flac24bit" | "flac24" => lx_core::model::source::Quality::Flac24,
                // 未知 token 保留原设置，不再静默降级到 128k。
                _ => base
                    .download
                    .quality
                    .unwrap_or(lx_core::model::source::Quality::High320),
            }
        });
        config.download.concurrent_songs = self.download_concurrency as usize;
        config.lyric.show_translation = self.show_translation;
        config.lyric.show_yrc = self.show_yrc;
        config.lyric.offset = self.lyric_offset_ms;
        config.network.proxy_url = self.proxy_url;
        config.network.timeout = self.network_timeout_secs;
        config.local_music.enabled = self.local_music_enabled;
        config.local_music.paths = self.local_music_paths;
        config.local_music.max_depth = self.local_music_max_depth;
        config
    }
}

/// `Quality` → FFI/Dart 使用的稳定 token（与配置 serde 名一致）。
fn quality_token(quality: lx_core::model::source::Quality) -> &'static str {
    use lx_core::model::source::Quality;
    match quality {
        Quality::Low128 => "128k",
        Quality::High320 => "320k",
        Quality::Flac => "flac",
        Quality::Flac24 => "flac24bit",
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
    /// 请求进行中（GUI 显示加载态，而不是空态）。
    pub loading: bool,
    /// 最近一次失败的可见原因；成功后为 None。
    pub error: Option<String>,
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

#[derive(Debug, Clone)]
pub struct PlaylistCategoryDto {
    pub id: String,
    pub name: String,
    pub source: String,
    pub group: Option<String>,
    pub count: u32,
    pub hot: bool,
}

impl From<lx_core::model::playlist::PlaylistCategory> for PlaylistCategoryDto {
    fn from(value: lx_core::model::playlist::PlaylistCategory) -> Self {
        Self {
            id: value.id,
            name: value.name,
            source: value.source.as_str().to_string(),
            group: value.group,
            count: value.count,
            hot: value.hot,
        }
    }
}

#[derive(Debug, Clone)]
pub struct LeaderboardDto {
    pub id: String,
    pub name: String,
    pub source: String,
    pub update: Option<String>,
}

impl From<lx_core::model::leaderboard::LeaderboardInfo> for LeaderboardDto {
    fn from(value: lx_core::model::leaderboard::LeaderboardInfo) -> Self {
        Self {
            id: value.id,
            name: value.name,
            source: value.source.as_str().to_string(),
            update: value.update,
        }
    }
}

#[derive(Debug, Clone)]
pub struct ArtistDto {
    pub id: String,
    pub name: String,
    pub source: String,
    pub cover_url: Option<String>,
}

impl ArtistDto {
    pub fn into_artist(self) -> Result<lx_core::model::playlist::Artist, String> {
        let source = parse_source(&self.source)?;
        Ok(lx_core::model::playlist::Artist {
            id: self.id,
            name: self.name,
            source,
            cover_url: self.cover_url,
        })
    }
}

#[derive(Debug, Clone)]
pub struct AlbumDto {
    pub id: String,
    pub name: String,
    pub source: String,
    pub cover_url: Option<String>,
    pub artist: String,
}

impl From<lx_core::model::playlist::Album> for AlbumDto {
    fn from(value: lx_core::model::playlist::Album) -> Self {
        Self {
            id: value.id,
            name: value.name,
            source: value.source.as_str().to_string(),
            cover_url: value.cover_url,
            artist: value.artist,
        }
    }
}

impl AlbumDto {
    pub fn into_album(self) -> Result<lx_core::model::playlist::Album, String> {
        let source = parse_source(&self.source)?;
        Ok(lx_core::model::playlist::Album {
            id: self.id,
            name: self.name,
            source,
            cover_url: self.cover_url,
            artist: self.artist,
        })
    }
}

/// 音源能力位：前端据此隐藏入口或展示「该音源不支持」空态。
#[derive(Debug, Clone)]
pub struct SourceCapabilitiesDto {
    pub id: String,
    pub name: String,
    pub playlists: bool,
    pub playlist_categories: bool,
    pub playlist_search: bool,
    pub album: bool,
    pub artist: bool,
    pub leaderboard: bool,
    pub login: bool,
    pub qr_login: bool,
}

impl From<voicefox_application::SourceCapabilityInfo> for SourceCapabilitiesDto {
    fn from(value: voicefox_application::SourceCapabilityInfo) -> Self {
        Self {
            id: value.id,
            name: value.name,
            playlists: value.playlists,
            playlist_categories: value.playlist_categories,
            playlist_search: value.playlist_search,
            album: value.album,
            artist: value.artist,
            leaderboard: value.leaderboard,
            login: value.login,
            qr_login: value.qr_login,
        }
    }
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
                loading: value.search.loading,
                error: value.search.error,
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
                    song: task.song.into(),
                    state: task.state,
                    active: task.active,
                    downloaded: task.downloaded,
                    total: task.total,
                    error: task.error,
                    trigger_auto_cache: task.trigger_auto_cache,
                })
                .collect(),
            sources: vec![],
            local_songs: vec![],
        }
    }
}

#[derive(Debug, Clone)]
pub struct SyncRowDto {
    pub name: String,
    /// "歌单" / "红心"。
    pub kind: String,
    pub cached: u32,
    pub remote: u32,
    /// "新增" / "更新" / "相同"。
    pub status: String,
}

#[derive(Debug, Clone)]
pub struct SyncFailureDto {
    pub name: String,
    pub reason: String,
}

#[derive(Debug, Clone)]
pub struct SyncPreviewDto {
    pub playlists: u32,
    pub favorites: u32,
    pub songs: u32,
    pub added: u32,
    pub updated: u32,
    pub removed: u32,
    pub failures: Vec<SyncFailureDto>,
    pub rows: Vec<SyncRowDto>,
}

#[derive(Debug, Clone)]
pub struct SyncReportDto {
    pub playlists: u32,
    pub favorites: u32,
    pub songs: u32,
    pub added: u32,
    pub updated: u32,
    pub removed: u32,
    pub failures: Vec<SyncFailureDto>,
}

#[derive(Debug, Clone)]
pub struct PushTargetDto {
    /// "playlist" / "favorites"，作为稳定的 wire 值。
    pub kind: String,
    pub id: String,
    pub name: String,
    pub song_count: u32,
}

#[derive(Debug, Clone)]
pub struct PushPreviewDto {
    pub target_name: String,
    pub target_kind: String,
    pub local_songs: u32,
    pub remote_songs: u32,
    pub additions: u32,
    pub matched: u32,
    pub unmatched: u32,
    pub samples: Vec<String>,
}

#[derive(Debug, Clone)]
pub struct PushReportDto {
    pub target_name: String,
    pub added: u32,
    pub already_present: u32,
    pub unmatched: u32,
    pub failed: Vec<String>,
}

/// 本地扫描统计（§5.10 流程 5：新增/复用/失败/跳过/移除）。
#[derive(Debug, Clone)]
pub struct ScanStatsDto {
    /// 本次发现的全部音频/CUE 文件数。
    pub discovered: u32,
    /// 指纹命中直接复用的歌曲数（未重新解析标签）。
    pub reused: u32,
    /// 本次实际解析入库的歌曲数（新增）。
    pub parsed: u32,
    /// 解析失败的文件数（重扫即重试，失败不回滚其余结果）。
    pub failed: u32,
    /// 已消失文件的记录数。
    pub removed: u32,
    /// 扩展名不属于音频/CUE 而被跳过的文件数（「无音频文件」）。
    pub skipped: u32,
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
    // ── 播放进度（kind == "progress"，由播放器 watcher 泵低频广播）──
    pub position_ms: u64,
    pub duration_ms: u64,
    pub playback_state: Option<String>,
    pub qr_session: Option<QrLoginSessionDto>,
    pub status: Option<String>,
    pub user_name: Option<String>,
    pub warnings: Vec<String>,
    /// 本地扫描统计（kind == "local_music" 且未取消时携带）。
    pub scan_stats: Option<ScanStatsDto>,
    /// 本地扫描是否被用户取消（取消的扫描不提交，stats 为空）。
    pub scan_cancelled: bool,
    pub config: Option<ConfigDto>,
    // ── 浏览数据面（kind == "browse"）──
    pub browse_kind: Option<String>,
    pub source: Option<String>,
    pub id: Option<String>,
    pub playlists: Vec<PlaylistDto>,
    pub categories: Vec<PlaylistCategoryDto>,
    pub albums: Vec<AlbumDto>,
    pub boards: Vec<LeaderboardDto>,
    // ── 账号歌单同步（kind == "sync"）──
    pub sync_preview: Option<SyncPreviewDto>,
    pub sync_report: Option<SyncReportDto>,
    pub progress_done: u32,
    pub progress_total: u32,
    // ── 本地 → 远端推送 ──
    pub push_targets: Vec<PushTargetDto>,
    pub push_target: Option<PushTargetDto>,
    pub push_preview: Option<PushPreviewDto>,
    pub push_report: Option<PushReportDto>,
}

impl From<ApplicationEvent> for VoicefoxEvent {
    fn from(value: ApplicationEvent) -> Self {
        let kind = match value.kind() {
            ApplicationEventKind::StateChanged => "state_changed",
            ApplicationEventKind::Progress => "progress",
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
            ApplicationEventKind::Browse => "browse",
            ApplicationEventKind::Sync => "sync",
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
            position_ms: 0,
            duration_ms: 0,
            playback_state: None,
            qr_session: None,
            status: None,
            user_name: None,
            warnings: vec![],
            scan_stats: None,
            scan_cancelled: false,
            config: None,
            browse_kind: None,
            source: None,
            id: None,
            playlists: vec![],
            categories: vec![],
            albums: vec![],
            boards: vec![],
            sync_preview: None,
            sync_report: None,
            progress_done: 0,
            progress_total: 0,
            push_targets: vec![],
            push_target: None,
            push_preview: None,
            push_report: None,
        };
        match value {
            ApplicationEvent::SearchStarted {
                request_id,
                keyword,
            } => Self {
                kind: kind.clone(),
                request_id,
                keyword: Some(keyword),
                page: 1,
                ..empty()
            },
            ApplicationEvent::SearchCompleted {
                request_id,
                keyword,
                page,
                append,
                items,
                has_more,
            } => Self {
                kind: kind.clone(),
                request_id,
                keyword: Some(keyword),
                page,
                append,
                has_more,
                items: items.into_iter().map(Into::into).collect(),
                ..empty()
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
                kind: kind.clone(),
                request_id,
                song: Some(song.into()),
                ..empty()
            },
            ApplicationEvent::QueueChanged { queue, index } => Self {
                kind: kind.clone(),
                queue: queue.into_iter().map(Into::into).collect(),
                queue_index: index as u32,
                ..empty()
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
            ApplicationEvent::LocalScanCompleted {
                warnings,
                stats,
                cancelled,
            } => {
                let mut event = empty();
                event.warnings = warnings;
                event.scan_cancelled = cancelled;
                event.scan_stats = stats.map(|stats| ScanStatsDto {
                    discovered: stats.discovered as u32,
                    reused: stats.reused as u32,
                    parsed: stats.parsed as u32,
                    failed: stats.failed as u32,
                    removed: stats.removed as u32,
                    skipped: stats.skipped as u32,
                });
                event
            }
            ApplicationEvent::ConfigChanged { config } => {
                let mut event = empty();
                event.config = Some(ConfigDto::from_config(&config));
                event
            }
            ApplicationEvent::BrowseLoaded {
                request_id,
                kind: browse_kind,
                source,
                id,
                page,
                items,
                albums,
                boards,
                playlists,
                categories,
                has_more,
                message,
            } => Self {
                kind: kind.clone(),
                request_id,
                page,
                append: page > 1,
                has_more,
                message,
                items: items.into_iter().map(Into::into).collect(),
                browse_kind: Some(browse_kind.as_str().to_string()),
                source: Some(source.as_str().to_string()),
                id: Some(id),
                playlists: playlists
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
                categories: categories.into_iter().map(Into::into).collect(),
                albums: albums.into_iter().map(Into::into).collect(),
                boards: boards.into_iter().map(Into::into).collect(),
                ..empty()
            },
            ApplicationEvent::BrowseFailed {
                request_id,
                kind: browse_kind,
                source,
                id,
                error,
            } => {
                let mut event = empty();
                event.request_id = request_id;
                event.message = Some(error);
                event.browse_kind = Some(browse_kind.as_str().to_string());
                event.source = Some(source.as_str().to_string());
                event.id = Some(id);
                event
            }
            ApplicationEvent::CustomPlaylistCreated { id, name } => {
                let mut event = empty();
                event.id = Some(id);
                event.message = Some(name);
                event
            }
            ApplicationEvent::SyncPreviewReady { source, preview } => {
                let mut event = empty();
                event.source = Some(source.as_str().to_string());
                event.status = Some("preview".into());
                event.sync_preview = Some(SyncPreviewDto {
                    playlists: preview.playlists as u32,
                    favorites: preview.favorites as u32,
                    songs: preview.songs as u32,
                    added: preview.added as u32,
                    updated: preview.updated as u32,
                    removed: preview.removed as u32,
                    failures: preview
                        .failed
                        .iter()
                        .map(|(name, reason)| SyncFailureDto {
                            name: name.clone(),
                            reason: reason.clone(),
                        })
                        .collect(),
                    rows: preview
                        .rows
                        .iter()
                        .map(|row| SyncRowDto {
                            name: row.name.clone(),
                            kind: row.kind.clone(),
                            cached: row.cached as u32,
                            remote: row.remote as u32,
                            status: row.status.clone(),
                        })
                        .collect(),
                });
                event
            }
            ApplicationEvent::SyncProgress {
                source,
                done,
                total,
            } => {
                let mut event = empty();
                event.source = Some(source.as_str().to_string());
                event.status = Some("progress".into());
                event.progress_done = done as u32;
                event.progress_total = total as u32;
                event
            }
            ApplicationEvent::SyncCompleted { source, report } => {
                let mut event = empty();
                event.source = Some(source.as_str().to_string());
                event.status = Some("completed".into());
                event.sync_report = Some(SyncReportDto {
                    playlists: report.playlists as u32,
                    favorites: report.favorites as u32,
                    songs: report.songs as u32,
                    added: report.added as u32,
                    updated: report.updated as u32,
                    removed: report.removed as u32,
                    failures: report
                        .failed
                        .iter()
                        .map(|(name, reason)| SyncFailureDto {
                            name: name.clone(),
                            reason: reason.clone(),
                        })
                        .collect(),
                });
                event
            }
            ApplicationEvent::SyncFailed { source, error } => {
                let mut event = empty();
                event.source = Some(source.as_str().to_string());
                event.status = Some("failed".into());
                event.message = Some(error);
                event
            }
            ApplicationEvent::PushTargetsReady { source, targets } => {
                let mut event = empty();
                event.source = Some(source.as_str().to_string());
                event.status = Some("push_targets".into());
                event.push_targets = targets.into_iter().map(Into::into).collect();
                event
            }
            ApplicationEvent::PushTargetCreated { source, target } => {
                let mut event = empty();
                event.source = Some(source.as_str().to_string());
                event.status = Some("push_target_created".into());
                event.push_target = Some(target.into());
                event
            }
            ApplicationEvent::PushPlanReady { source, preview } => {
                let mut event = empty();
                event.source = Some(source.as_str().to_string());
                event.status = Some("push_preview".into());
                event.push_preview = Some((*preview).into());
                event
            }
            ApplicationEvent::PushProgress {
                source,
                done,
                total,
            } => {
                let mut event = empty();
                event.source = Some(source.as_str().to_string());
                event.status = Some("push_progress".into());
                event.progress_done = done as u32;
                event.progress_total = total as u32;
                event
            }
            ApplicationEvent::PushCompleted { source, report } => {
                let mut event = empty();
                event.source = Some(source.as_str().to_string());
                event.status = Some("push_completed".into());
                event.push_report = Some((*report).into());
                event
            }
            ApplicationEvent::PushFailed { source, error } => {
                let mut event = empty();
                event.source = Some(source.as_str().to_string());
                event.status = Some("push_failed".into());
                event.message = Some(error);
                event
            }
            ApplicationEvent::PlaybackProgress {
                state,
                position,
                duration,
            } => {
                let mut event = empty();
                event.position_ms = position.as_millis() as u64;
                event.duration_ms = duration.as_millis() as u64;
                event.playback_state = Some(
                    match state {
                        lx_core::model::source::PlayerState::Idle => "idle",
                        lx_core::model::source::PlayerState::Loading => "loading",
                        lx_core::model::source::PlayerState::Playing => "playing",
                        lx_core::model::source::PlayerState::Paused => "paused",
                        lx_core::model::source::PlayerState::Stopped => "stopped",
                    }
                    .to_string(),
                );
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

impl From<voicefox_application::sync::PushTargetOption> for PushTargetDto {
    fn from(target: voicefox_application::sync::PushTargetOption) -> Self {
        Self {
            kind: match target.kind {
                lx_core::sync::SyncCollectionKind::Playlist => "playlist",
                lx_core::sync::SyncCollectionKind::Favorites => "favorites",
            }
            .into(),
            id: target.id,
            name: target.name,
            song_count: target.song_count as u32,
        }
    }
}

impl From<voicefox_application::sync::PushPlanPreview> for PushPreviewDto {
    fn from(preview: voicefox_application::sync::PushPlanPreview) -> Self {
        Self {
            target_name: preview.target_name,
            target_kind: preview.target_kind,
            local_songs: preview.local_songs as u32,
            remote_songs: preview.remote_songs as u32,
            additions: preview.additions as u32,
            matched: preview.matched as u32,
            unmatched: preview.unmatched as u32,
            samples: preview.samples,
        }
    }
}

impl From<voicefox_application::sync::PushReport> for PushReportDto {
    fn from(report: voicefox_application::sync::PushReport) -> Self {
        Self {
            target_name: report.target_name,
            added: report.added as u32,
            already_present: report.already_present as u32,
            unmatched: report.unmatched as u32,
            failed: report
                .failed
                .into_iter()
                .map(|(song, artist, reason)| format!("{song} - {artist}: {reason}"))
                .collect(),
        }
    }
}

/// Thread-safe application handle owned by the Flutter-facing layer.
#[derive(Clone)]
pub struct VoicefoxController {
    application: ApplicationService,
    /// 当前完整配置的共享读取口：ConfigUpdate 每次合并都取最新值。
    config_base: Option<Arc<std::sync::RwLock<lx_core::model::config::Config>>>,
    /// 移动端转发型播放后端句柄（Phase 8 批次一）；桌面引导为 None，
    /// 桌面路径不触碰。
    host_player: Option<Arc<HostPlayerBackend>>,
}

impl VoicefoxController {
    /// Construct the desktop runtime without depending on the TUI crate.
    #[cfg(feature = "desktop-mpv")]
    pub fn new_desktop() -> Result<Self, String> {
        let (config, path) = voicefox_runtime::load_config().map_err(|e| e.to_string())?;
        // P1-05/P2-08：GUI 无 TUI 的 tracing 落盘，panic 面接 crash.log
        // 取证（引擎级 SIGABRT 无 unwind 不经此 hook，边界见 crash_log 模块注释）。
        crate::crash_log::install_gui_panic_hook(
            path.parent().unwrap_or_else(|| std::path::Path::new(".")),
        );
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
            host_player: None,
        }
    }

    /// Phase 8 移动端引导：转发型播放后端 + 常规 runtime（无 mpv）。
    ///
    /// 与 new_desktop 同构，仅播放后端不同：HostPlayerBackend 不做音频
    /// 解码，把播放指令转发给宿主（Dart 侧 just_audio），宿主回流
    /// state/position/duration。移动 ABI（--no-default-features）下
    /// new_desktop 不可用，宿主应走本函数。
    pub fn new_host() -> Result<Self, String> {
        let (config, path) = voicefox_runtime::load_config().map_err(|e| e.to_string())?;
        let backend = Arc::new(HostPlayerBackend::new());
        // FFI-R07：常驻存活看门狗（std 线程）。宿主断连/回流断流时把
        // Loading/Playing 强制回落 Stopped，避免 UI 永久冻结在最后快照。
        // 5s 检查间隔 / 20s 回流静默阈值：远小于用户可感知的故障时长，
        // 远大于正常回流节奏（500ms 节流）。
        backend.start_liveness_watchdog(
            std::time::Duration::from_secs(5),
            std::time::Duration::from_secs(20),
        );
        let runtime = voicefox_runtime::ApplicationRuntime::from_parts(
            config,
            path,
            Arc::clone(&backend) as Arc<dyn PlayerBackend>,
        )
        .map_err(|e| e.to_string())?;
        Ok(Self::from_application(runtime.application())
            .with_config_base(Arc::clone(&runtime.config))
            .with_host_player(backend))
    }

    /// 挂接转发型后端句柄（new_host 内部使用）。
    pub fn with_host_player(mut self, backend: Arc<HostPlayerBackend>) -> Self {
        self.host_player = Some(backend);
        self
    }

    /// 转发型后端句柄（仅 new_host 引导时为 Some；桌面 None）。
    pub fn host_player(&self) -> Option<Arc<HostPlayerBackend>> {
        self.host_player.clone()
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
        let mut state: VoicefoxState = self.application.state().into();
        state.sources = self
            .application
            .source_capabilities()
            .into_iter()
            .map(Into::into)
            .collect();
        // FFI-R09（A-2）：state() 不再携带 local_songs 全量快照——大曲库下
        // 每次调用是 O(n) 克隆 + FFI 序列化，而本地曲目只在扫描/导入/删除后
        // 才变化。改由 [api::local_songs] 独立拉取（Dart 在引导与
        // local_music 事件时调用），播放/搜索/下载等高频事件不再搬运曲库。
        state
    }

    /// 本地曲库全量快照（FFI-R09 A-2：从 state() 拆出的独立读取口）。
    pub fn local_songs(&self) -> Vec<SongDto> {
        self.application
            .local_songs()
            .into_iter()
            .map(Into::into)
            .collect()
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

/// 自定义请求头键值对（application HostHeaderPair 的 FRB 可翻译镜像；
/// 外部 crate 类型 FRB 一律 opaque，Dart 拿不到字段，故在 ffi 侧镜像）。
#[derive(Debug, Clone)]
pub struct HostHeaderDto {
    pub name: String,
    pub value: String,
}

/// 转发给宿主（Dart/just_audio）的播放指令 DTO。
/// application `HostPlayerCommand` 的镜像，由 [HostPlayerStream] 转换。
/// `command_id` 供宿主 ack 回销（hostPlayerAck）；歌曲域指令的
/// `generation` 供宿主丢弃过期命令（lag 后缓冲旧命令不得直打当前曲目）。
#[derive(Debug, Clone)]
pub enum HostPlayerCommandDto {
    /// 播放指定 URL；headers 为国内音源自定义请求头（逐请求透传）。
    Play {
        url: String,
        generation: u64,
        headers: Vec<HostHeaderDto>,
        command_id: u64,
    },
    Pause {
        command_id: u64,
        generation: u64,
    },
    Resume {
        command_id: u64,
        generation: u64,
    },
    Stop {
        command_id: u64,
        generation: u64,
    },
    Toggle {
        command_id: u64,
        generation: u64,
    },
    /// 定位到绝对位置（毫秒）。
    Seek {
        position_ms: u64,
        command_id: u64,
        generation: u64,
    },
    SetVolume {
        volume: u32,
        command_id: u64,
    },
    SetSpeed {
        speed: f64,
        command_id: u64,
    },
}

impl From<HostPlayerCommand> for HostPlayerCommandDto {
    fn from(command: HostPlayerCommand) -> Self {
        match command {
            HostPlayerCommand::Play {
                url,
                generation,
                headers,
                command_id,
            } => Self::Play {
                url,
                generation,
                headers: headers
                    .into_iter()
                    .map(|pair| HostHeaderDto {
                        name: pair.name,
                        value: pair.value,
                    })
                    .collect(),
                command_id,
            },
            HostPlayerCommand::Pause {
                command_id,
                generation,
            } => Self::Pause {
                command_id,
                generation,
            },
            HostPlayerCommand::Resume {
                command_id,
                generation,
            } => Self::Resume {
                command_id,
                generation,
            },
            HostPlayerCommand::Stop {
                command_id,
                generation,
            } => Self::Stop {
                command_id,
                generation,
            },
            HostPlayerCommand::Toggle {
                command_id,
                generation,
            } => Self::Toggle {
                command_id,
                generation,
            },
            HostPlayerCommand::Seek {
                position_ms,
                command_id,
                generation,
            } => Self::Seek {
                position_ms,
                command_id,
                generation,
            },
            HostPlayerCommand::SetVolume { volume, command_id } => {
                Self::SetVolume { volume, command_id }
            }
            HostPlayerCommand::SetSpeed { speed, command_id } => {
                Self::SetSpeed { speed, command_id }
            }
        }
    }
}

/// 播放指令流（Dart 持流轮询 next；与 VoicefoxEventStream 同模式）。
pub struct HostPlayerStream {
    inner: tokio::sync::broadcast::Receiver<HostPlayerCommand>,
}

impl HostPlayerStream {
    pub async fn next(&mut self) -> Result<HostPlayerCommandDto, String> {
        match self.inner.recv().await {
            Ok(command) => Ok(command.into()),
            Err(tokio::sync::broadcast::error::RecvError::Lagged(skipped)) => Err(format!(
                "host player stream lagged, skipped {skipped} commands; resubscribe and resync"
            )),
            Err(e) => Err(e.to_string()),
        }
    }
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
    /// 立即设置播放器音量（0-100）；持久化由 ConfigUpdate 负责。
    SetVolume {
        volume: u32,
    },
    PlaySong {
        song: SongDto,
    },
    QueueAdd {
        song: SongDto,
        next: bool,
    },
    QueueRemove {
        index: u32,
    },
    QueueClear,
    Next,
    Previous,
    Search {
        keyword: String,
        /// 可选音源过滤；None 为聚合搜索。不合法的 id 报错。
        source: Option<String>,
    },
    SearchMore {
        keyword: String,
        page: u32,
        /// 可选音源过滤；None 为聚合搜索（Rust 侧 append 时兜底沿用本次查询
        /// 建立时的过滤，见 ApplicationService::start_search）。
        source: Option<String>,
    },
    // ── 库（收藏/历史/自定义歌单）──
    LibraryRefresh,
    FavoritesAdd {
        song: SongDto,
    },
    FavoritesRemove {
        song: SongDto,
    },
    FavoritePlaylistAdd {
        playlist: PlaylistDto,
    },
    FavoritePlaylistRemove {
        playlist: PlaylistDto,
    },
    HistoryRemove {
        song: SongDto,
    },
    HistoryClear,
    CustomPlaylistCreate {
        name: String,
    },
    CustomPlaylistRename {
        id: String,
        name: String,
    },
    CustomPlaylistDelete {
        id: String,
    },
    CustomPlaylistAddSongs {
        id: String,
        songs: Vec<SongDto>,
    },
    CustomPlaylistRemoveSong {
        id: String,
        song: SongDto,
    },
    CustomPlaylistDetail {
        id: String,
    },
    // ── 歌词 ──
    /// P2-17：手动重新获取当前歌曲歌词（自动获取失败/为空时的兜底入口）。
    LoadLyrics {
        song: SongDto,
    },
    // ── 配置 ──
    ConfigGet,
    ConfigUpdate {
        config: ConfigDto,
    },
    // ── 下载 ──
    DownloadEnqueue {
        song: SongDto,
    },
    DownloadCancel {
        id: u64,
    },
    DownloadPause {
        id: u64,
    },
    DownloadResume {
        id: u64,
    },
    DownloadDeleteFile {
        id: u64,
    },
    DownloadClearFinished,
    // ── 扫码登录 ──
    QrLoginStart {
        source: String,
        kind: String,
    },
    QrLoginCancel,
    // ── 本地扫描 ──
    LocalScan {
        paths: Vec<String>,
        max_depth: u32,
    },
    LocalScanCancel,
    // ── 账号歌单镜像 / 同步 ──
    AccountPlaylists {
        source: String,
    },
    AccountFavorites {
        source: String,
    },
    AccountPlaylistDetail {
        source: String,
        playlist_id: String,
    },
    SyncPreview {
        source: String,
    },
    SyncRun {
        source: String,
    },
    SyncCancel,
    PushTargets {
        source: String,
    },
    PushCreateTarget {
        source: String,
        name: String,
    },
    PushPlan {
        source: String,
        local_name: String,
        local_songs: Vec<SongDto>,
        is_favorites: bool,
        target_kind: String,
        target_id: String,
        target_name: String,
        target_song_count: u32,
    },
    PushRun {
        source: String,
    },
    PushCancel,
    // ── 浏览数据面（歌单 / 排行榜 / 歌手 / 专辑）──
    PlaylistCategories {
        source: String,
    },
    PlaylistList {
        source: String,
        category: String,
        page: u32,
    },
    PlaylistDetail {
        source: String,
        playlist_id: String,
        page: u32,
    },
    LeaderboardBoards {
        source: String,
    },
    LeaderboardSongs {
        source: String,
        board_id: String,
        page: u32,
    },
    ArtistSongs {
        artist: ArtistDto,
        page: u32,
    },
    ArtistAlbums {
        artist: ArtistDto,
        page: u32,
    },
    AlbumSongs {
        album: AlbumDto,
        page: u32,
    },
    /// 播放一组歌曲（列表/榜单/专辑的「播放全部」），复用现有队列播放语义。
    PlaySongs {
        songs: Vec<SongDto>,
        index: u32,
    },
}

impl FfiCommand {
    fn into_application(self) -> Result<ApplicationCommand, String> {
        Ok(match self {
            FfiCommand::Pause => ApplicationCommand::Pause,
            FfiCommand::Resume => ApplicationCommand::Resume,
            FfiCommand::Toggle => ApplicationCommand::Toggle,
            FfiCommand::Stop => ApplicationCommand::Stop,
            FfiCommand::SeekMs(ms) => ApplicationCommand::Seek(Duration::from_millis(ms)),
            FfiCommand::SetVolume { volume } => ApplicationCommand::SetVolume(volume.min(100)),
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
            FfiCommand::Search { keyword, source } => ApplicationCommand::Search {
                keyword,
                source: match source {
                    Some(id) => Some(parse_source(&id)?),
                    None => None,
                },
            },
            FfiCommand::SearchMore {
                keyword,
                page,
                source,
            } => ApplicationCommand::SearchMore {
                keyword,
                page,
                source: match source {
                    Some(id) => Some(parse_source(&id)?),
                    None => None,
                },
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
            FfiCommand::LoadLyrics { song } => ApplicationCommand::LoadLyrics {
                song: song.into_song()?,
            },
            FfiCommand::CustomPlaylistCreate { name } => {
                ApplicationCommand::CustomPlaylistCreate { name }
            }
            FfiCommand::CustomPlaylistRename { id, name } => {
                ApplicationCommand::CustomPlaylistRename { id, name }
            }
            FfiCommand::CustomPlaylistDelete { id } => {
                ApplicationCommand::CustomPlaylistDelete { id }
            }
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
            FfiCommand::CustomPlaylistDetail { id } => {
                ApplicationCommand::CustomPlaylistDetail { id }
            }
            FfiCommand::ConfigGet => ApplicationCommand::ConfigGet,
            FfiCommand::DownloadEnqueue { song } => ApplicationCommand::DownloadEnqueue {
                song: song.into_song()?,
            },
            FfiCommand::DownloadCancel { id } => ApplicationCommand::DownloadCancel { id },
            FfiCommand::DownloadPause { id } => ApplicationCommand::DownloadPause { id },
            FfiCommand::DownloadResume { id } => ApplicationCommand::DownloadResume { id },
            FfiCommand::DownloadDeleteFile { id } => ApplicationCommand::DownloadDeleteFile { id },
            FfiCommand::DownloadClearFinished => ApplicationCommand::DownloadClearFinished,
            FfiCommand::QrLoginStart { source, kind } => ApplicationCommand::QrLoginStart {
                source: parse_source(&source)?,
                kind: match kind.as_str() {
                    "wechat" => lx_core::model::login::QrLoginKind::WeChat,
                    _ => lx_core::model::login::QrLoginKind::Standard,
                },
            },
            FfiCommand::QrLoginCancel => ApplicationCommand::QrLoginCancel,
            FfiCommand::LocalScan { paths, max_depth } => {
                ApplicationCommand::LocalScan { paths, max_depth }
            }
            FfiCommand::LocalScanCancel => ApplicationCommand::LocalScanCancel,
            FfiCommand::AccountPlaylists { source } => ApplicationCommand::AccountPlaylists {
                source: parse_source(&source)?,
            },
            FfiCommand::AccountFavorites { source } => ApplicationCommand::AccountFavorites {
                source: parse_source(&source)?,
            },
            FfiCommand::AccountPlaylistDetail {
                source,
                playlist_id,
            } => ApplicationCommand::AccountPlaylistDetail {
                source: parse_source(&source)?,
                playlist_id,
            },
            FfiCommand::SyncPreview { source } => ApplicationCommand::SyncPreview {
                source: parse_source(&source)?,
            },
            FfiCommand::SyncRun { source } => ApplicationCommand::SyncRun {
                source: parse_source(&source)?,
            },
            FfiCommand::SyncCancel => ApplicationCommand::SyncCancel,
            FfiCommand::PushTargets { source } => ApplicationCommand::PushTargets {
                source: parse_source(&source)?,
            },
            FfiCommand::PushCreateTarget { source, name } => ApplicationCommand::PushCreateTarget {
                source: parse_source(&source)?,
                name,
            },
            FfiCommand::PushPlan {
                source,
                local_name,
                local_songs,
                is_favorites,
                target_kind,
                target_id,
                target_name,
                target_song_count,
            } => {
                let kind = match target_kind.as_str() {
                    "playlist" => lx_core::sync::SyncCollectionKind::Playlist,
                    "favorites" => lx_core::sync::SyncCollectionKind::Favorites,
                    _ => return Err("未知的推送目标类型".into()),
                };
                ApplicationCommand::PushPlan {
                    source: parse_source(&source)?,
                    local: voicefox_application::sync::LocalPushCollection {
                        name: local_name,
                        songs: local_songs
                            .into_iter()
                            .map(SongDto::into_song)
                            .collect::<Result<_, _>>()?,
                        is_favorites,
                    },
                    target: voicefox_application::sync::PushTargetOption {
                        kind,
                        id: target_id,
                        name: target_name,
                        song_count: target_song_count as usize,
                    },
                }
            }
            FfiCommand::PushRun { source } => ApplicationCommand::PushRun {
                source: parse_source(&source)?,
            },
            FfiCommand::PushCancel => ApplicationCommand::PushCancel,
            FfiCommand::PlaylistCategories { source } => ApplicationCommand::PlaylistCategories {
                source: parse_source(&source)?,
            },
            FfiCommand::PlaylistList {
                source,
                category,
                page,
            } => ApplicationCommand::Playlists {
                source: parse_source(&source)?,
                category,
                page,
            },
            FfiCommand::PlaylistDetail {
                source,
                playlist_id,
                page,
            } => ApplicationCommand::PlaylistDetail {
                source: parse_source(&source)?,
                playlist_id,
                page,
            },
            FfiCommand::LeaderboardBoards { source } => ApplicationCommand::LeaderboardBoards {
                source: parse_source(&source)?,
            },
            FfiCommand::LeaderboardSongs {
                source,
                board_id,
                page,
            } => ApplicationCommand::LeaderboardSongs {
                source: parse_source(&source)?,
                board_id,
                page,
            },
            FfiCommand::ArtistSongs { artist, page } => ApplicationCommand::ArtistSongs {
                artist: artist.into_artist()?,
                page,
            },
            FfiCommand::ArtistAlbums { artist, page } => ApplicationCommand::ArtistAlbums {
                artist: artist.into_artist()?,
                page,
            },
            FfiCommand::AlbumSongs { album, page } => ApplicationCommand::AlbumSongs {
                album: album.into_album()?,
                page,
            },
            FfiCommand::PlaySongs { songs, index } => ApplicationCommand::Play {
                songs: songs
                    .into_iter()
                    .map(SongDto::into_song)
                    .collect::<Result<_, _>>()?,
                index: index as usize,
            },
            // ConfigUpdate 在 VoicefoxController::dispatch 里特判（需要 config_base）
            FfiCommand::ConfigUpdate { .. } => {
                unreachable!("handled in VoicefoxController::dispatch")
            }
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

    #[test]
    fn config_roundtrip_is_idempotent() {
        let config = lx_core::model::config::Config::default();
        let dto = ConfigDto::from_config(&config);
        // play_mode 是字符串，不能再被 Debug 加引号。
        assert_eq!(dto.play_mode, "list-loop");

        let once = dto.apply_to(&config);
        assert_eq!(once.player.play_mode, "list-loop");

        // 连续保存三次不得膨胀（旧的引号叠加 bug 会在这里被抓住）。
        let mut current = config;
        for _ in 0..3 {
            let dto = ConfigDto::from_config(&current);
            current = dto.apply_to(&current);
            assert_eq!(current.player.play_mode, "list-loop");
        }
    }

    #[test]
    fn download_quality_roundtrip_keeps_320k() {
        use lx_core::model::source::Quality;
        let mut config = lx_core::model::config::Config::default();
        config.download.quality = Some(Quality::High320);

        let dto = ConfigDto::from_config(&config);
        assert_eq!(dto.download_quality.as_deref(), Some("320k"));

        let applied = dto.apply_to(&config);
        assert_eq!(applied.download.quality, Some(Quality::High320));
    }

    #[test]
    fn invalid_play_mode_keeps_previous_value() {
        let config = lx_core::model::config::Config::default();
        let mut dto = ConfigDto::from_config(&config);
        dto.play_mode = "\"list-loop\"".to_string();
        let applied = dto.apply_to(&config);
        assert_eq!(applied.player.play_mode, "list-loop");
    }

    #[test]
    fn theme_mode_roundtrip_and_default() {
        let config = lx_core::model::config::Config::default();
        assert_eq!(config.theme.mode, "system");
        let dto = ConfigDto::from_config(&config);
        assert_eq!(dto.theme_mode, "system");
        let applied = dto.apply_to(&config);
        assert_eq!(applied.theme.mode, "system");

        // 合法 token 写入；未知值保留原配置。
        let mut dto = ConfigDto::from_config(&applied);
        dto.theme_mode = "dark".to_string();
        let dark = dto.clone().apply_to(&applied);
        assert_eq!(dark.theme.mode, "dark");
        dto.theme_mode = "bogus".to_string();
        assert_eq!(dto.apply_to(&dark).theme.mode, "dark");
    }
}
