//! 平台媒体会话共享层：已提取至 media-session crate（Batch F §9.2，
//! GUI 与 TUI 共用协议翻译，不从零实现两套桌面媒体集成）。
//! TUI 经本模块 re-export 保持 `crate::media_session::…` 引用路径不变。
//!
//! 平台门控与 crate 侧一致：`channel`/`translate_event` 只被 souvlaki
//! 后端（smtc/nowplaying，cfg windows/macos）消费，crate 侧也只在那两个
//! 平台编译——无条件 re-export 会在 Linux 上 E0432「configured out」
//! 并级联毒化本模块（Batch CI-Fix2 修复；该 shim 的 Linux 形态自
//! Batch F 起从未被编译过）。

pub use media_session::media_session::{MediaCommand, MediaHandle, MediaLoopStatus, MediaSnapshot};

#[cfg(any(target_os = "windows", target_os = "macos"))]
pub use media_session::media_session::{channel, translate_event};
