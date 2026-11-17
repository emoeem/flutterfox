//! UI 无关的 Voicefox Application Service 层。
//!
//! 这一层是 Flutter FFI 与现有 TUI 之间的稳定业务边界：
//! - 不依赖 ratatui/crossterm
//! - 不暴露 Arc/Mutex/Tokio channel 给 frontend
//! - frontend 通过 Command/Event/State DTO 与服务交互。
//!
//! 当前服务复用已有 core/source/player/lyric 能力；TUI 的旧 AppAction
//! 会在迁移期由 frontend adapter 映射到 ApplicationCommand。

pub mod event;
pub mod playlist;
pub mod ports;
pub mod remote_cache;
pub mod service;
pub mod state;
pub mod sync;

pub use event::{ApplicationCommand, ApplicationEvent, ApplicationEventKind, BrowseKind};
pub use ports::{ConfigStore, DownloadTaskInfo, DownloadsEngine, LibraryStore};
pub use service::{ApplicationEventStream, ApplicationEventStreamError, ApplicationService};
pub use state::{
    ApplicationState, PlaybackSnapshot, QueueState, SearchState, SourceCapabilityInfo,
};

pub use services::{
    HostHeaderPair, HostPlayerBackend, HostPlayerCommand, LyricsService, PlaybackEffects,
    PlaybackService, PlaylistService, QueueService, SearchService, resolve_cover_url,
};

/// 桌面媒体会话桥(Batch F §9.3 引入 Linux MPRIS;SMTC 接入泛化跨平台):
/// Linux MPRIS / Windows SMTC 注册入口,桌面引导处调用。
#[cfg(any(target_os = "linux", target_os = "windows"))]
pub use services::spawn_media_session_bridge;

mod services;
