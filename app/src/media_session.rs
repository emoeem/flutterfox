//! 平台媒体会话共享层：已提取至 media-session crate（Batch F §9.2，
//! GUI 与 TUI 共用 MPRIS 协议翻译，不从零实现两套 D-Bus 服务）。
//! TUI 经本模块 re-export 保持 `crate::media_session::…` 引用路径不变。
//!
//! souvlaki 事件翻译（Windows SMTC / macOS Now Playing）随迁至 crate
//! （translate_event 提升为 pub）。

pub use media_session::media_session::{
    MediaCommand, MediaHandle, MediaLoopStatus, MediaSnapshot, channel, translate_event,
};
