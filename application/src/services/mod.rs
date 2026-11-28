mod host_player;
mod lyrics;
// 桥内纯逻辑由测试消费、运行时接线由 Linux(MPRIS)/Windows(SMTC) 消费：
// 其余构建(macOS GUI)整体编译掉，避免 dead_code 告警。
#[cfg(any(target_os = "linux", target_os = "windows", test))]
mod media_bridge;
mod playback;
mod playlist;
mod queue;
mod search;

pub use host_player::{HostHeaderPair, HostPlayerBackend, HostPlayerCommand};
pub use lyrics::LyricsService;
pub use playback::{PlaybackEffects, PlaybackService, resolve_cover_url};
pub use playlist::PlaylistService;
pub use queue::QueueService;
pub use search::SearchService;

#[cfg(any(target_os = "linux", target_os = "windows"))]
pub use media_bridge::spawn_media_session_bridge;

#[cfg(test)]
pub mod test_support;
