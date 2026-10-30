//! 兼容垫片：播放队列/播放模式已迁至 voicefox-application::playlist。
//! 保留 crate::playlist::{manager, mode} 路径，TUI 无需改动引用方式。
pub use voicefox_application::playlist::{manager, mode};
