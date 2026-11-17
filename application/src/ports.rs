//! GUI 侧的存储/引擎端口。
//!
//! TUI 直用 runtime 的具体类型；GUI 走本模块的 trait，由 runtime 提供实现。
//! application 不能依赖 runtime（runtime → application），故端口只引用 lx-core 模型。

use lx_core::model::playlist::{CustomPlaylist, CustomPlaylistSummary, Playlist};
use lx_core::model::song::SongInfo;

/// 收藏 / 收藏歌单 / 自定义歌单 / 历史的存储端口（runtime 的 Storage 实现）。
///
/// 方法面刻意与 Storage 现有方法一一对应：TUI 不经此端口，GUI 不直触 Storage。
pub trait LibraryStore: Send + Sync {
    fn favorites(&self) -> Vec<SongInfo>;
    fn add_favorite(&self, song: &SongInfo) -> bool;
    fn remove_favorite(&self, song: &SongInfo) -> bool;
    fn is_favorite(&self, song: &SongInfo) -> bool;

    fn favorite_playlists(&self) -> Vec<Playlist>;
    fn add_favorite_playlist(&self, playlist: &Playlist) -> bool;
    fn remove_favorite_playlist(&self, playlist: &Playlist) -> bool;

    fn history(&self) -> Vec<SongInfo>;
    fn remove_history(&self, song: &SongInfo) -> bool;
    fn clear_history(&self) -> bool;

    fn custom_playlist_summaries(&self) -> Vec<CustomPlaylistSummary>;
    fn custom_playlist(&self, id: &str) -> Option<CustomPlaylist>;
    fn create_custom_playlist(&self, name: &str) -> Result<CustomPlaylist, String>;
    fn rename_custom_playlist(&self, id: &str, name: &str) -> Result<(), String>;
    fn delete_custom_playlist(&self, id: &str) -> Result<bool, String>;
    fn add_song_to_custom_playlist(&self, id: &str, song: &SongInfo) -> Result<bool, String>;
    fn add_songs_to_custom_playlist(
        &self,
        id: &str,
        songs: &[SongInfo],
    ) -> Result<(usize, usize), String>;
    fn remove_song_from_custom_playlist(&self, id: &str, song: &SongInfo) -> Result<bool, String>;
}

/// 配置读写端口（runtime 实现：内存替换 + TOML 落盘）。
pub trait ConfigStore: Send + Sync {
    fn get(&self) -> lx_core::model::config::Config;
    /// 全量替换并持久化；播放器侧效果（音量等）由前端另行下发。
    fn set(&self, config: lx_core::model::config::Config) -> Result<(), String>;
}

/// 下载任务在 GUI 边界上的投影（避免 application 依赖 download crate：
/// download 历史上依赖 runtime 的存储助手，现在依赖已断开，但保持端口
/// DTO 仍然是更稳的边界——下载内部类型演化不波及 FFI）。
#[derive(Debug, Clone, PartialEq)]
pub struct DownloadTaskInfo {
    pub id: u64,
    pub name: String,
    pub singer: String,
    pub source: lx_core::model::source::SourceId,
    pub quality: lx_core::model::source::Quality,
    pub dest: String,
    /// 完整歌曲载荷：失败/取消任务用它重新入队（UI 重试按钮）。
    pub song: SongInfo,
    /// 下载状态的人类可读标签（排队中/下载中/已完成/失败…）。
    pub state: String,
    /// 是否仍在活跃（排队/解析/下载/写标签）。
    pub active: bool,
    pub downloaded: u64,
    pub total: Option<u64>,
    pub error: Option<String>,
    pub trigger_auto_cache: bool,
}

/// 下载引擎端口（runtime 包装 voicefox-download::DownloadManager 实现）。
pub trait DownloadsEngine: Send + Sync {
    /// 入队一首歌；重复任务返回 false。
    fn enqueue(&self, song: SongInfo) -> bool;
    fn cancel(&self, id: u64);
    /// 暂停任务；非进行中任务是空操作。
    fn pause(&self, id: u64) {
        let _ = id;
    }
    /// 继续暂停的任务：需要音源管理器重新解析播放地址（同源才续传）。
    fn resume(&self, id: u64, sources: &std::sync::Arc<lx_source::manager::SourceManager>) -> bool {
        let _ = (id, sources);
        false
    }
    /// 删除已完成任务的本地文件并回收下载记录；不可删除返回 false。
    fn delete_file(&self, id: u64) -> bool {
        let _ = id;
        false
    }
    fn clear_finished(&self);
    fn snapshot(&self) -> Vec<DownloadTaskInfo>;
    fn active_count(&self) -> usize;
}
