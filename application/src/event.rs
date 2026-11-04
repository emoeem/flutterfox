use std::time::Duration;

use lx_core::model::leaderboard::LeaderboardInfo;
use lx_core::model::playlist::{Album, Artist, Playlist, PlaylistCategory};
use lx_core::model::song::SongInfo;
use lx_core::model::source::{PlayerState, SourceId};

#[derive(Debug, Clone)]
pub enum ApplicationCommand {
    Search {
        keyword: String,
        source: Option<SourceId>,
    },
    SearchMore {
        keyword: String,
        page: u32,
        source: Option<SourceId>,
    },
    Play {
        songs: Vec<SongInfo>,
        index: usize,
    },
    PlayCurrent,
    Pause,
    Resume,
    Toggle,
    Stop,
    Seek(Duration),
    /// 设置播放器音量（0-100）。与 ConfigUpdate 的 volume 字段分开：
    /// 前者立即作用于播放引擎，后者负责持久化。
    SetVolume(u32),
    QueueAdd {
        song: SongInfo,
        next: bool,
    },
    QueueRemove {
        index: usize,
    },
    QueueClear,
    Next,
    Previous,
    PlaybackFailed {
        request_id: u64,
        error: String,
    },
    RestorePlayback {
        songs: Vec<SongInfo>,
        index: usize,
        position: Duration,
        paused: bool,
    },
    LoadLyrics {
        song: SongInfo,
    },
    PlaylistOpen {
        playlist: Playlist,
    },
    PlaylistSet(Vec<Playlist>),
    // ── 收藏 / 历史 / 自定义歌单（经 LibraryStore 端口落到 runtime Storage）──
    /// GUI 启动时拉一次库状态（publish_library），之后靠 LibraryChanged 增量。
    LibraryRefresh,
    FavoritesAdd {
        song: SongInfo,
    },
    FavoritesRemove {
        song: SongInfo,
    },
    FavoritePlaylistAdd {
        playlist: Playlist,
    },
    FavoritePlaylistRemove {
        playlist: Playlist,
    },
    HistoryRemove {
        song: SongInfo,
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
        songs: Vec<SongInfo>,
    },
    CustomPlaylistRemoveSong {
        id: String,
        song: SongInfo,
    },
    /// 读取单个自建歌单（含曲目）。结果走 `BrowseLoaded`，
    /// `kind = CustomPlaylist`、`source = local`、`id = 歌单 id`。
    CustomPlaylistDetail {
        id: String,
    },
    // ── 配置（经 ConfigStore 端口）──
    /// 全量替换并持久化。
    ConfigUpdate {
        config: Box<lx_core::model::config::Config>,
    },
    /// 请求一次 ConfigChanged 广播（GUI 启动时拉取现状）。
    ConfigGet,
    // ── 下载（经 DownloadsEngine 端口）──
    DownloadEnqueue {
        song: SongInfo,
    },
    DownloadCancel {
        id: u64,
    },
    DownloadClearFinished,
    // ── 扫码登录（直接走 SourceManager）──
    QrLoginStart {
        source: SourceId,
        kind: lx_core::model::login::QrLoginKind,
    },
    QrLoginCancel,
    // ── 本地音乐扫描 ──
    LocalScan {
        paths: Vec<String>,
        max_depth: u32,
    },
    // ── 账号歌单镜像（远程缓存，只读）──
    /// 列出某平台缓存的账号歌单（不含红心集合）。
    AccountPlaylists {
        source: SourceId,
    },
    /// 读取某平台镜像缓存里的红心歌曲。
    AccountFavorites {
        source: SourceId,
    },
    /// 读取缓存里的单个账号歌单曲目。
    AccountPlaylistDetail {
        source: SourceId,
        playlist_id: String,
    },
    // ── 账号歌单同步（远端 → 本地镜像缓存）──
    /// 只读预览：拉一次远端，报告将新增/更新/移除多少。
    SyncPreview {
        source: SourceId,
    },
    /// 执行同步：把远端歌单写入镜像缓存。
    SyncRun {
        source: SourceId,
    },
    /// 取消进行中的同步。
    SyncCancel,
    /// 列出推送目标（远端歌单与红心集合）。
    PushTargets {
        source: SourceId,
    },
    /// 在远端新建推送目标歌单。
    PushCreateTarget {
        source: SourceId,
        name: String,
    },
    /// 生成本地集合到远端目标的追加计划。
    PushPlan {
        source: SourceId,
        local: crate::sync::LocalPushCollection,
        target: crate::sync::PushTargetOption,
    },
    /// 执行最近生成的推送计划。
    PushRun {
        source: SourceId,
    },
    /// 取消进行中的推送。
    PushCancel,
    // ── 浏览数据面（歌单 / 排行榜 / 歌手 / 专辑）──
    /// 歌单分类目录。分类能力不一的音源由 `SourceCapabilities::playlist_categories` 声明；
    /// 未实现分类的在线音源仍可浏览「推荐」歌单。
    PlaylistCategories {
        source: SourceId,
    },
    Playlists {
        source: SourceId,
        category: String,
        page: u32,
    },
    PlaylistDetail {
        source: SourceId,
        playlist_id: String,
        page: u32,
    },
    LeaderboardBoards {
        source: SourceId,
    },
    LeaderboardSongs {
        source: SourceId,
        board_id: String,
        page: u32,
    },
    ArtistSongs {
        artist: Artist,
        page: u32,
    },
    ArtistAlbums {
        artist: Artist,
        page: u32,
    },
    AlbumSongs {
        album: Album,
        page: u32,
    },
}

#[derive(Debug, Clone)]
// PlaybackStarted 内联 SongInfo 是最大变体：事件只是经通道短暂流转的
// 短命对象，装箱要波及所有构造与匹配点，尺寸收益不值得。
#[allow(clippy::large_enum_variant)]
pub enum ApplicationEvent {
    StateChanged(Box<crate::ApplicationState>),
    SearchStarted {
        request_id: u64,
        keyword: String,
    },
    SearchCompleted {
        request_id: u64,
        keyword: String,
        page: u32,
        append: bool,
        items: Vec<SongInfo>,
        has_more: bool,
    },
    SearchFailed {
        request_id: u64,
        error: String,
    },
    PlaybackStarted {
        request_id: u64,
        song: SongInfo,
        source_index: Option<usize>,
    },
    PlaybackPaused,
    PlaybackResumed,
    PlaybackStopped,
    PlaybackEnded,
    /// 播放器 watcher 的快照（进度/时长/状态）。由播放泵合并后低频广播，
    /// 前端据此增量刷新播放条，不需要整份 state 拉取。
    PlaybackProgress {
        state: PlayerState,
        position: Duration,
        duration: Duration,
    },
    PlaybackFailed {
        request_id: u64,
        error: String,
    },
    QueueChanged {
        queue: Vec<SongInfo>,
        index: usize,
    },
    LyricsChanged {
        song_id: String,
    },
    PlaylistChanged {
        playlists: Vec<Playlist>,
    },
    Notification {
        message: String,
    },
    /// 收藏/历史/自定义歌单有任何变化的信号；数据本体看 StateChanged 快照。
    LibraryChanged,
    /// 新建自建歌单成功：带回生成的 id，前端可立即把歌曲加进去。
    /// 与本事件前后脚发出的 `LibraryChanged` 负责刷新列表快照。
    CustomPlaylistCreated {
        id: String,
        name: String,
    },
    /// 下载任务列表有变化；数据本体看 StateChanged 快照的 downloads 字段。
    DownloadsChanged,
    /// 配置被替换（含 ConfigGet 的应答）。
    ConfigChanged {
        config: Box<lx_core::model::config::Config>,
    },
    /// 二维码已生成；`image_png_base64` 与 `url` 二选一。
    QrLoginCreated {
        session: lx_core::model::login::QrLoginSession,
    },
    /// 扫码状态推进；终态后不再轮询。
    QrLoginPolled {
        source: SourceId,
        status: String,
        message: String,
        user_name: Option<String>,
    },
    /// 本地扫描完成。
    LocalScanCompleted {
        warnings: Vec<String>,
    },
    /// 同步预览就绪（未写任何缓存）。
    SyncPreviewReady {
        source: SourceId,
        preview: Box<crate::sync::NeteaseSyncPreview>,
    },
    /// 同步进度（远端拉取完成后的缓存写入阶段）。
    SyncProgress {
        source: SourceId,
        done: usize,
        total: usize,
    },
    /// 同步完成，镜像缓存已更新。
    SyncCompleted {
        source: SourceId,
        report: Box<crate::sync::NeteaseSyncReport>,
    },
    /// 同步失败（取消也走这里，`error` 为「同步已取消」）。
    SyncFailed {
        source: SourceId,
        error: String,
    },
    /// 可选远端推送目标已就绪。
    PushTargetsReady {
        source: SourceId,
        targets: Vec<crate::sync::PushTargetOption>,
    },
    /// 远端歌单创建成功。
    PushTargetCreated {
        source: SourceId,
        target: crate::sync::PushTargetOption,
    },
    /// 推送 Diff 预览已就绪。
    PushPlanReady {
        source: SourceId,
        preview: Box<crate::sync::PushPlanPreview>,
    },
    /// 推送进度。
    PushProgress {
        source: SourceId,
        done: usize,
        total: usize,
    },
    /// 推送执行完成。
    PushCompleted {
        source: SourceId,
        report: Box<crate::sync::PushReport>,
    },
    /// 推送失败（取消也走这里，error 为「同步已取消」）。
    PushFailed {
        source: SourceId,
        error: String,
    },
    /// 浏览请求成功。`items`/`albums`/`boards`/`playlists` 按 [`BrowseKind`] 取用；
    /// 音源不支持该能力时仍发本事件（数据为空、`message` 说明原因），
    /// 前端据此展示空态而不是把「不支持」当运行时错误。
    BrowseLoaded {
        request_id: u64,
        kind: BrowseKind,
        source: SourceId,
        id: String,
        page: u32,
        items: Vec<SongInfo>,
        albums: Vec<Album>,
        boards: Vec<LeaderboardInfo>,
        playlists: Vec<Playlist>,
        categories: Vec<PlaylistCategory>,
        has_more: bool,
        message: Option<String>,
    },
    BrowseFailed {
        request_id: u64,
        kind: BrowseKind,
        source: SourceId,
        id: String,
        error: String,
    },
}

/// 浏览数据面的请求/事件类型。前端按这个字符串路由，不要依赖枚举序号。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BrowseKind {
    PlaylistCategories,
    Playlists,
    PlaylistDetail,
    LeaderboardBoards,
    LeaderboardSongs,
    ArtistSongs,
    ArtistAlbums,
    AlbumSongs,
    /// 本地自建歌单详情（不经在线音源）。
    CustomPlaylist,
    /// 账号歌单列表（远程缓存镜像）。
    AccountPlaylists,
    /// 账号歌单详情（远程缓存镜像）。
    AccountPlaylistDetail,
    /// 账号红心歌曲（远程缓存镜像）。
    AccountFavorites,
}

impl BrowseKind {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::PlaylistCategories => "playlist_categories",
            Self::Playlists => "playlists",
            Self::PlaylistDetail => "playlist_detail",
            Self::LeaderboardBoards => "leaderboard_boards",
            Self::LeaderboardSongs => "leaderboard_songs",
            Self::ArtistSongs => "artist_songs",
            Self::ArtistAlbums => "artist_albums",
            Self::AlbumSongs => "album_songs",
            Self::CustomPlaylist => "custom_playlist",
            Self::AccountPlaylists => "account_playlists",
            Self::AccountPlaylistDetail => "account_playlist_detail",
            Self::AccountFavorites => "account_favorites",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ApplicationEventKind {
    StateChanged,
    Progress,
    Search,
    Playback,
    Queue,
    Lyrics,
    Playlist,
    Notification,
    Library,
    Downloads,
    Config,
    QrLogin,
    LocalMusic,
    Browse,
    Sync,
}

impl ApplicationEvent {
    pub fn kind(&self) -> ApplicationEventKind {
        match self {
            Self::StateChanged(_) => ApplicationEventKind::StateChanged,
            Self::SearchStarted { .. }
            | Self::SearchCompleted { .. }
            | Self::SearchFailed { .. } => ApplicationEventKind::Search,
            Self::PlaybackStarted { .. }
            | Self::PlaybackPaused
            | Self::PlaybackResumed
            | Self::PlaybackStopped
            | Self::PlaybackEnded
            | Self::PlaybackFailed { .. } => ApplicationEventKind::Playback,
            Self::PlaybackProgress { .. } => ApplicationEventKind::Progress,
            Self::QueueChanged { .. } => ApplicationEventKind::Queue,
            Self::LyricsChanged { .. } => ApplicationEventKind::Lyrics,
            Self::PlaylistChanged { .. } => ApplicationEventKind::Playlist,
            Self::Notification { .. } => ApplicationEventKind::Notification,
            Self::LibraryChanged | Self::CustomPlaylistCreated { .. } => {
                ApplicationEventKind::Library
            }
            Self::DownloadsChanged => ApplicationEventKind::Downloads,
            Self::ConfigChanged { .. } => ApplicationEventKind::Config,
            Self::QrLoginCreated { .. } | Self::QrLoginPolled { .. } => {
                ApplicationEventKind::QrLogin
            }
            Self::LocalScanCompleted { .. } => ApplicationEventKind::LocalMusic,
            Self::SyncPreviewReady { .. }
            | Self::SyncProgress { .. }
            | Self::SyncCompleted { .. }
            | Self::SyncFailed { .. }
            | Self::PushTargetsReady { .. }
            | Self::PushTargetCreated { .. }
            | Self::PushPlanReady { .. }
            | Self::PushProgress { .. }
            | Self::PushCompleted { .. }
            | Self::PushFailed { .. } => ApplicationEventKind::Sync,
            Self::BrowseLoaded { .. } | Self::BrowseFailed { .. } => ApplicationEventKind::Browse,
        }
    }

    pub fn player_state(&self) -> Option<PlayerState> {
        match self {
            Self::PlaybackStarted { .. } => Some(PlayerState::Playing),
            Self::PlaybackPaused => Some(PlayerState::Paused),
            Self::PlaybackResumed => Some(PlayerState::Playing),
            Self::PlaybackStopped => Some(PlayerState::Stopped),
            Self::PlaybackProgress { state, .. } => Some(*state),
            _ => None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn event_kind_is_stable_for_frontend_routing() {
        let event = ApplicationEvent::PlaybackPaused;
        assert_eq!(event.kind(), ApplicationEventKind::Playback);
        assert_eq!(event.player_state(), Some(PlayerState::Paused));
    }

    #[test]
    fn queue_and_search_events_have_distinct_kinds() {
        assert_eq!(
            ApplicationEvent::QueueChanged {
                queue: vec![],
                index: 0
            }
            .kind(),
            ApplicationEventKind::Queue
        );
        assert_eq!(
            ApplicationEvent::SearchStarted {
                request_id: 1,
                keyword: "x".into()
            }
            .kind(),
            ApplicationEventKind::Search
        );
    }
}
