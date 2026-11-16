mod host_player;
mod lyrics;
// 桥内纯逻辑由测试消费、运行时接线由 Linux 消费：非 Linux 非 test 构建
// 整体编译掉，避免 dead_code 告警。
#[cfg(any(target_os = "linux", test))]
mod mpris_bridge;
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

#[cfg(target_os = "linux")]
pub use mpris_bridge::spawn_mpris_bridge;

#[cfg(test)]
pub mod test_support;
