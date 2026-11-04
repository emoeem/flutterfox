//! flutter_rust_bridge entry points.
//!
//! The generated Dart bindings should expose only DTOs/commands/streams from
//! this module; ApplicationService itself never crosses the Flutter ABI.

pub use crate::{
    FfiCommand, LyricLineDto, LyricsDto, PlaylistDto, SearchDto, SongDto, VoicefoxController,
    VoicefoxEvent, VoicefoxEventStream, VoicefoxState,
};

pub fn command_pause() -> FfiCommand {
    FfiCommand::Pause
}
pub fn command_resume() -> FfiCommand {
    FfiCommand::Resume
}
pub fn command_toggle() -> FfiCommand {
    FfiCommand::Toggle
}
pub fn command_stop() -> FfiCommand {
    FfiCommand::Stop
}
pub fn command_next() -> FfiCommand {
    FfiCommand::Next
}
pub fn command_previous() -> FfiCommand {
    FfiCommand::Previous
}
pub fn command_search(keyword: String, source: Option<String>) -> FfiCommand {
    FfiCommand::Search { keyword, source }
}
pub fn command_search_more(keyword: String, page: u32) -> FfiCommand {
    FfiCommand::SearchMore { keyword, page }
}
pub fn command_play(song: SongDto) -> FfiCommand {
    FfiCommand::PlaySong { song }
}
pub fn command_queue_add(song: SongDto) -> FfiCommand {
    FfiCommand::QueueAdd { song, next: false }
}
pub fn command_queue_remove(index: u32) -> FfiCommand {
    FfiCommand::QueueRemove { index }
}
pub fn command_queue_clear() -> FfiCommand {
    FfiCommand::QueueClear
}

/// FRB 生成代码无条件引用此函数，因此签名必须始终存在；
/// 非 mpv 构建（移动端）运行时返回明确错误，移动端应改用 from_application 引导。
pub fn new_desktop() -> Result<VoicefoxController, String> {
    #[cfg(feature = "desktop-mpv")]
    {
        // libmpv 初始化要求 LC_NUMERIC 为 "C"：GTK 宿主会把它设成用户区域
        // （如 zh_CN），导致 mpv 初始化直接失败。只影响本进程，无需还原。
        unsafe { libc::setlocale(libc::LC_NUMERIC, c"C".as_ptr()) };
        VoicefoxController::new_desktop()
    }
    #[cfg(not(feature = "desktop-mpv"))]
    {
        Err("desktop-mpv backend is not compiled into this build; bootstrap via from_application instead".to_string())
    }
}

/// 宿主引导：注入进程级数据目录覆盖（App 私有目录）。
///
/// Android 上 `dirs::data_dir()` 为 `None`，`default_data_dir` 会回退到
/// `"."`（进程工作目录）。宿主应在构造 ApplicationService 之前调用本
/// 函数，把 PathProvider 拿到的 App 私有目录传进来；有覆盖时跳过旧目录
/// 迁移。桌面端无需调用（`None` 即回到平台默认路径）。
pub fn set_data_dir(path: Option<String>) {
    lx_core::fsutil::set_data_dir_override(path.map(std::path::PathBuf::from));
}

pub fn state(controller: &VoicefoxController) -> VoicefoxState {
    controller.state()
}

pub async fn dispatch(controller: &VoicefoxController, command: FfiCommand) -> Result<(), String> {
    controller.dispatch(command).await
}

pub fn subscribe(controller: &VoicefoxController) -> VoicefoxEventStream {
    controller.subscribe()
}

pub async fn event_next(stream: &mut VoicefoxEventStream) -> Result<VoicefoxEvent, String> {
    stream.next().await
}
