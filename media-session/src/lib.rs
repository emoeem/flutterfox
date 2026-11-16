//! 平台媒体会话共享层（Batch F §9.2：GUI 与 TUI 共用 MPRIS 协议翻译，
//! 不从零实现两套 D-Bus 服务）。
//!
//! 快照 / 命令的数据结构在 [`media_session`]（与 Windows SMTC / macOS
//! Now Playing 共用的平台无关纯数据）；[`mpris`] 只做 zbus 协议翻译：
//! 把 [`media_session::MediaSnapshot`] 映射到 org.mpris.MediaPlayer2
//! 属性，把桌面发来的 D-Bus 调用转成 [`media_session::MediaCommand`]。
//! 自 TUI app/src/{media_session,mpris}.rs 原样迁入（Batch F §9.2），
//! TUI 侧改为消费本 crate。

pub mod media_session;

#[cfg(target_os = "linux")]
pub mod mpris;
