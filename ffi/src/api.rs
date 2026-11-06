//! flutter_rust_bridge entry points.
//!
//! The generated Dart bindings should expose only DTOs/commands/streams from
//! this module; ApplicationService itself never crosses the Flutter ABI.

pub use crate::{
    FfiCommand, HostHeaderDto, HostPlayerCommandDto, HostPlayerStream, LyricLineDto, LyricsDto,
    PlaylistDto, SearchDto, SongDto, VoicefoxController, VoicefoxEvent, VoicefoxEventStream,
    VoicefoxState,
};

use lx_core::traits::player::PlayerEvent;

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
/// Phase 8 移动端引导：转发型播放后端 + 常规 runtime（无 mpv）。
///
/// 桌面构建也可调用（不触碰 mpv），但桌面验收路径仍是 new_desktop。
/// 引导后：`host_player_stream` 收播放指令（play/pause/seek/...），
/// `host_player_report` / `host_player_report_event` 回流真实
/// state/position/duration 与 Ended/Error 事件。
pub fn new_host() -> Result<VoicefoxController, String> {
    VoicefoxController::new_host()
}

/// 播放指令流（Rust→Dart 反向信号面）。与 VoicefoxEventStream 同为
/// 「Dart 持流轮询 next」模式；Lagged（宿主消费落后丢指令）返回 Err，
/// 由 Dart 侧重订阅并重拉状态。
pub fn host_player_stream(controller: &VoicefoxController) -> HostPlayerStream {
    HostPlayerStream {
        inner: controller
            .host_player()
            .expect("host_player_stream 仅在 new_host 引导的控制器上可用")
            .subscribe(),
    }
}

/// 宿主回流真实播放状态/进度/时长（Dart→Rust）。写入转发后端的 watch
/// 观察者，经 service.rs 观察者泵进入既有 ApplicationEventStream →
/// Flutter 事件流。时长未知报 0（`--:--` 规则）。
pub fn host_player_report(
    controller: &VoicefoxController,
    state: String,
    position_ms: u64,
    duration_ms: u64,
) -> Result<(), String> {
    let backend = controller
        .host_player()
        .ok_or_else(|| "控制器未启用转发型播放后端".to_string())?;
    let state = parse_host_state(&state).ok_or_else(|| {
        format!("未知播放状态 '{state}'（期望 idle/loading/playing/paused/stopped）")
    })?;
    backend.report_state(state);
    backend.report_position(std::time::Duration::from_millis(position_ms));
    backend.report_duration(std::time::Duration::from_millis(duration_ms));
    Ok(())
}

/// 宿主回流离散播放事件：ended（驱动队列推进）/ error / buffering /
/// playing（generation 对齐宿主当前代次）。
pub fn host_player_report_event(
    controller: &VoicefoxController,
    kind: String,
    generation: u64,
    message: Option<String>,
) -> Result<(), String> {
    use lx_core::model::source::PlayerState;
    let backend = controller
        .host_player()
        .ok_or_else(|| "控制器未启用转发型播放后端".to_string())?;
    let event = match kind.as_str() {
        "ended" => PlayerEvent::Ended { generation },
        "error" => PlayerEvent::Error {
            generation,
            message: message.unwrap_or_default(),
        },
        "buffering" => PlayerEvent::Buffering {
            generation,
            percent: message
                .as_deref()
                .and_then(|m| m.parse::<f64>().ok())
                .unwrap_or(0.0),
        },
        "playing" => {
            backend.report_state(PlayerState::Playing);
            PlayerEvent::Playing { generation }
        }
        other => return Err(format!("未知播放事件 '{other}'（期望 ended/error/buffering/playing）")),
    };
    backend.report_event(event);
    Ok(())
}

fn parse_host_state(state: &str) -> Option<lx_core::model::source::PlayerState> {
    use lx_core::model::source::PlayerState;
    Some(match state {
        "idle" => PlayerState::Idle,
        "loading" => PlayerState::Loading,
        "playing" => PlayerState::Playing,
        "paused" => PlayerState::Paused,
        "stopped" => PlayerState::Stopped,
        _ => return None,
    })
}

/// 取一条播放指令（与 event_next 同模式：Dart 持流轮询）。
pub async fn host_player_next(
    stream: &mut HostPlayerStream,
) -> Result<HostPlayerCommandDto, String> {
    stream.next().await
}

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
