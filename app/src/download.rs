//! 兼容垫片：下载引擎已抽为独立的 voicefox-download crate。
//! 保留 crate::download::{DownloadManager, DownloadState, DownloadTaskView} 路径，
//! TUI 无需改动引用方式；子模块路径（engine/manager 等）测试代码直接用 voicefox_download::。
pub use voicefox_download::naming;
pub use voicefox_download::{DownloadManager, DownloadState, DownloadTaskView};
