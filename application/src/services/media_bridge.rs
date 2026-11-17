//! GUI 桌面媒体会话桥（Batch F §9.3）。
//!
//! 把 [`ApplicationService`] 的播放态构建 [`MediaSnapshot`] 推给平台媒体
//! 后端（Linux MPRIS），把桌面控件的 [`MediaCommand`] 翻译回
//! [`ApplicationCommand`] 走既有 dispatch 链——与 TUI 的
//! `app/src/media_controls.rs` 同源语义，快照/命令数据结构经
//! media-session crate 共享（§9.2 提取），不再各写一套。
//!
//! 纯映射逻辑（播放模式映射 / 快照构建 / 命令翻译 / 跳转纪元）跨平台
//! 编译并单测；D-Bus 运行时接线仅 Linux 编译（Windows 无会话总线，
//! 运行时验收留 Linux 会话，见交接文档开放项）。

use std::time::{Duration, Instant};

use lx_core::model::source::PlayerState;

use crate::event::ApplicationCommand;
use crate::state::{ApplicationState, PlaybackSnapshot};
use media_session::media_session::{MediaCommand, MediaLoopStatus, MediaSnapshot};
// 仅运行时接线消费（Linux）；测试构建下 is_snapshot_relevant 不编译，
// 顶层导入会报 unused，故随 cfg 下沉。
#[cfg(target_os = "linux")]
use crate::event::ApplicationEvent;
// 同上：ApplicationService 仅被 Linux 运行时段消费；Windows/测试构建不导入
// （Batch CI-Fix 修复：该导入缺失使 cfg(linux) 段在 Linux CI 上 E0425 ×5——
// 本文件从未在 Linux 编译过，交接文档「cfg-linux 编译验证留 Linux CI」欠账）。
#[cfg(target_os = "linux")]
use crate::service::ApplicationService;
#[cfg(target_os = "linux")]
use media_session::media_session::MediaHandle;

// ── 平台无关纯逻辑 ─────────────────────────────────────────────────────

/// 配置 play_mode 字符串 → (MPRIS loop_status, shuffle)。
/// 与 TUI `media_controls.rs` 的 PlayMode 映射同源（§9.2 解耦枚举）；
/// `none` 与未知值同口径（顺序播放、无随机）。
fn map_loop_status(play_mode: &str) -> (MediaLoopStatus, bool) {
    match play_mode {
        "single-loop" => (MediaLoopStatus::Track, false),
        "list-loop" => (MediaLoopStatus::Playlist, false),
        "random" => (MediaLoopStatus::None, true),
        _ => (MediaLoopStatus::None, false),
    }
}

/// [`ApplicationState`] → [`MediaSnapshot`]（epoch 由调用方经
/// [`BridgeEpoch`] 推进后写入，这里先置 0 占位）。
fn build_snapshot(state: &ApplicationState, play_mode: &str, position_epoch: u64) -> MediaSnapshot {
    let (loop_status, shuffle) = map_loop_status(play_mode);
    MediaSnapshot::new(
        state.playback.state,
        state.playback.song.as_ref(),
        state.playback.position,
        state.playback.duration,
        state.playback.volume,
        loop_status,
        shuffle,
        state.queue.songs.len(),
        position_epoch,
    )
}

/// 桌面控件命令 → GUI [`ApplicationCommand`]。
///
/// 返回 `None` 表示当前态无需动作（如已在播放时收到 Play）或本桥不
/// 执行的命令（`Quit`：GUI 窗口生命周期归宿主，Rust 侧无从优雅关闭，
/// 由命令循环记日志忽略——TUI 的退出语义不直接搬入 GUI）。
fn translate_command(
    command: &MediaCommand,
    playback: &PlaybackSnapshot,
) -> Option<ApplicationCommand> {
    match command {
        MediaCommand::Quit => None,
        MediaCommand::Play => match playback.state {
            PlayerState::Paused => Some(ApplicationCommand::Resume),
            PlayerState::Idle | PlayerState::Stopped => Some(ApplicationCommand::PlayCurrent),
            PlayerState::Playing | PlayerState::Loading => None,
        },
        MediaCommand::Pause => match playback.state {
            PlayerState::Playing | PlayerState::Loading => Some(ApplicationCommand::Pause),
            PlayerState::Idle | PlayerState::Paused | PlayerState::Stopped => None,
        },
        MediaCommand::Toggle => match playback.state {
            PlayerState::Playing | PlayerState::Loading => Some(ApplicationCommand::Pause),
            PlayerState::Paused => Some(ApplicationCommand::Resume),
            PlayerState::Idle | PlayerState::Stopped => Some(ApplicationCommand::PlayCurrent),
        },
        // stop 幂等；未播放时下发无害。
        MediaCommand::Stop => Some(ApplicationCommand::Stop),
        MediaCommand::Next => Some(ApplicationCommand::Next),
        MediaCommand::Previous => Some(ApplicationCommand::Previous),
        // 相对跳转按当前快照位置折算绝对位置；负值截到 0，越界交播放器收敛。
        MediaCommand::SeekBy(offset_micros) => {
            let current = i64::try_from(playback.position.as_micros()).unwrap_or(i64::MAX);
            let target = (current + *offset_micros).max(0) as u64;
            Some(ApplicationCommand::Seek(Duration::from_micros(target)))
        }
        MediaCommand::SetPosition(position) => Some(ApplicationCommand::Seek(*position)),
        MediaCommand::SetVolume(volume) => {
            let volume = (volume.clamp(0.0, 1.0) * 100.0).round() as u32;
            Some(ApplicationCommand::SetVolume(volume))
        }
    }
}

/// 位置漂移超过该阈值视为跳转：远大于 4Hz 进度广播的正常推进量，
/// 远小于肉眼可感的误报区间（缓冲停顿表现为位置冻结而非跳变）。
const SEEK_DRIFT_THRESHOLD: Duration = Duration::from_millis(1500);

/// 跳转纪元推进器：MPRIS 层以纪元变化发 seeked 信号。
///
/// GUI 侧的跳转来源全部在此汇成单个单调计数：
/// - 换曲 / 重放：`state.playback.generation` 每次 play 都变；
/// - seek：dispatch 只改播放器不产生事件，由 [`BridgeEpoch::observe_position`]
///   的位置不连续检测兜底（MPRIS 发起的 seek 与 GUI 滑杆 seek 同路）；
/// - 防御：trackid 变化（generation 理论上已覆盖）。
#[derive(Debug, Default)]
struct BridgeEpoch {
    epoch: u64,
    last_generation: u64,
    last_track_path: String,
    last_observation: Option<(PlayerState, Duration, Instant)>,
    seek_hint: bool,
}

impl BridgeEpoch {
    /// 依据本次快照与 generation 推进纪元；返回当前值。
    fn advance(&mut self, snapshot: &MediaSnapshot, generation: u64) -> u64 {
        if generation != self.last_generation
            || snapshot.track_path != self.last_track_path
            || self.seek_hint
        {
            self.epoch += 1;
            self.last_generation = generation;
            self.last_track_path = snapshot.track_path.clone();
            self.seek_hint = false;
        }
        self.epoch
    }

    /// 记录进度观测；同态连续观测间的不连续位置视为跳转。
    ///
    /// Loading 期位置可能停滞或回退（加载而非跳转），不做判定；
    /// 暂停期位置本不该动，任何变化都来自 seek。
    fn observe_position(&mut self, state: PlayerState, position: Duration) {
        let now = Instant::now();
        if let Some((last_state, last_position, last_at)) = self.last_observation
            && last_state == state
        {
            match state {
                // 播放中：期望位置 = 上次位置 + 墙钟推进；超出漂移即跳转。
                PlayerState::Playing => {
                    let expected =
                        last_position.saturating_add(now.saturating_duration_since(last_at));
                    if position.abs_diff(expected) > SEEK_DRIFT_THRESHOLD {
                        self.seek_hint = true;
                    }
                }
                // 暂停中位置本不该动，任何变化都来自 seek。
                PlayerState::Paused
                    if position.abs_diff(last_position) > Duration::from_millis(50) =>
                {
                    self.seek_hint = true;
                }
                // Loading 期位置可能停滞或回退（加载而非跳转），不做判定。
                _ => {}
            }
        }
        self.last_observation = match state {
            PlayerState::Idle | PlayerState::Stopped => None,
            other => Some((other, position, now)),
        };
    }
}

// ── Linux 运行时接线 ──────────────────────────────────────────────────

/// Linux 桌面引导处调用：注册 MPRIS 桥（配置关闭则静默不启动）。
///
/// 独立线程 + 专用 tokio 运行时（与 FFI-R07 看门狗同构的自足装配），
/// 不依赖 FRB 的运行时内部；D-Bus 不可用 / 服务启动失败只记日志，
/// 不影响应用启动——桌面控件降级为不可用。
#[cfg(target_os = "linux")]
pub fn spawn_mpris_bridge(application: ApplicationService) {
    if !application.mpris_enabled() {
        return;
    }
    let spawned = std::thread::Builder::new()
        .name("mpris-bridge".to_string())
        .spawn(move || run_bridge(application));
    if let Err(error) = spawned {
        tracing::warn!("mpris bridge thread failed to start: {error}");
    }
}

#[cfg(target_os = "linux")]
fn run_bridge(application: ApplicationService) {
    let runtime = match tokio::runtime::Builder::new_multi_thread()
        .worker_threads(2)
        .enable_all()
        .build()
    {
        Ok(runtime) => runtime,
        Err(error) => {
            tracing::warn!("mpris bridge runtime failed: {error}");
            return;
        }
    };
    let (handle, commands) = match runtime.block_on(media_session::mpris::start()) {
        Ok(parts) => parts,
        Err(error) => {
            tracing::warn!("MPRIS unavailable: {error:#}");
            return;
        }
    };
    runtime.spawn(run_command_loop(application.clone(), commands));
    // 快照循环驻留在本线程的 block_on 里；事件源关闭（应用退出）时收束，
    // 运行时随函数返回 drop，命令循环任务一并终止。
    if let Err(error) = runtime.block_on(run_snapshot_loop(application, handle)) {
        tracing::warn!("mpris snapshot loop stopped: {error}");
    }
}

/// 快照生产循环：订阅应用事件，相关事件触发全量重建。
/// 快照逐字段差异比对在 MPRIS 层完成（`apply_snapshot`），重复快照
/// 不会产生多余的 D-Bus 信号。
#[cfg(target_os = "linux")]
async fn run_snapshot_loop(
    application: ApplicationService,
    handle: MediaHandle,
) -> Result<(), crate::service::ApplicationEventStreamError> {
    let mut events = application.subscribe();
    let mut epoch = BridgeEpoch::default();
    // 初始快照：桌面控件连上即可见当前状态，不等下一次事件。
    push_snapshot(&application, &handle, &mut epoch);
    loop {
        match events.recv().await {
            Ok(event) => {
                if let ApplicationEvent::PlaybackProgress {
                    state, position, ..
                } = &event
                {
                    epoch.observe_position(*state, *position);
                }
                if is_snapshot_relevant(&event) {
                    push_snapshot(&application, &handle, &mut epoch);
                }
            }
            // Lagged：丢事件不可修复，重建全量快照对齐当前态后继续。
            Err(crate::service::ApplicationEventStreamError::Lagged(count)) => {
                tracing::warn!("mpris snapshot loop lagged by {count} events; rebuilding");
                push_snapshot(&application, &handle, &mut epoch);
            }
            // Closed：应用在退出，收束循环（返回 Err 仅为形式统一）。
            Err(error @ crate::service::ApplicationEventStreamError::Closed) => {
                return Err(error);
            }
        }
    }
}

/// 影响快照内容的事件全集；搜索/歌词/下载等高频无关事件不触发重建。
#[cfg(target_os = "linux")]
fn is_snapshot_relevant(event: &ApplicationEvent) -> bool {
    matches!(
        event,
        ApplicationEvent::StateChanged(_)
            | ApplicationEvent::PlaybackStarted { .. }
            | ApplicationEvent::PlaybackPaused
            | ApplicationEvent::PlaybackResumed
            | ApplicationEvent::PlaybackStopped
            | ApplicationEvent::PlaybackEnded
            | ApplicationEvent::PlaybackProgress { .. }
            | ApplicationEvent::PlaybackFailed { .. }
            | ApplicationEvent::QueueChanged { .. }
            | ApplicationEvent::ConfigChanged { .. }
    )
}

#[cfg(target_os = "linux")]
fn push_snapshot(application: &ApplicationService, handle: &MediaHandle, epoch: &mut BridgeEpoch) {
    let state = application.state();
    let mut snapshot = build_snapshot(&state, &application.play_mode(), 0);
    snapshot.position_epoch = epoch.advance(&snapshot, state.playback.generation);
    handle.update(snapshot);
}

/// 命令消费循环：桌面控件 → [`translate_command`] → 既有 dispatch 链。
/// 单条命令失败只记日志，循环不中断（媒体键不因一次解析失败失灵）。
#[cfg(target_os = "linux")]
async fn run_command_loop(
    application: ApplicationService,
    mut commands: tokio::sync::mpsc::UnboundedReceiver<MediaCommand>,
) {
    while let Some(command) = commands.recv().await {
        if matches!(command, MediaCommand::Quit) {
            tracing::info!("mpris quit ignored (GUI window lifecycle is host-owned)");
            continue;
        }
        let playback = application.state().playback;
        match translate_command(&command, &playback) {
            Some(application_command) => {
                if let Err(error) = application.dispatch(application_command).await {
                    tracing::warn!("mpris command {command:?} failed: {error}");
                }
            }
            // 当前态无需动作（如已在播放收到 Play）；如实跳过。
            None => {}
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{BridgeEpoch, build_snapshot, map_loop_status, translate_command};
    use crate::event::ApplicationCommand;
    use crate::state::{ApplicationState, PlaybackSnapshot};
    use lx_core::model::source::PlayerState;
    use media_session::media_session::{MediaCommand, MediaLoopStatus, MediaSnapshot};
    use std::time::{Duration, Instant};

    fn default_state() -> ApplicationState {
        ApplicationState::default()
    }

    /// ApplicationCommand 内含 Config 等非 PartialEq 载荷，全枚举 derive
    /// 不划算；本批测试子集用 Debug 文本比对保证结构一致。
    fn expect_command(result: Option<ApplicationCommand>, expected: &ApplicationCommand) {
        assert!(
            matches!(&result, Some(got) if format!("{got:?}") == format!("{expected:?}")),
            "命令不匹配：{result:?} != {expected:?}"
        );
    }

    fn expect_none(result: Option<ApplicationCommand>) {
        assert!(result.is_none(), "应无命令，实际 {result:?}");
    }

    // ── map_loop_status ────────────────────────────────────────────────

    #[test]
    fn play_mode_maps_to_loop_status_and_shuffle() {
        assert_eq!(
            map_loop_status("single-loop"),
            (MediaLoopStatus::Track, false)
        );
        assert_eq!(
            map_loop_status("list-loop"),
            (MediaLoopStatus::Playlist, false)
        );
        assert_eq!(map_loop_status("random"), (MediaLoopStatus::None, true));
        assert_eq!(map_loop_status("none"), (MediaLoopStatus::None, false));
        // 未知值与 none 同口径。
        assert_eq!(map_loop_status(""), (MediaLoopStatus::None, false));
        assert_eq!(map_loop_status("???"), (MediaLoopStatus::None, false));
    }

    // ── build_snapshot ────────────────────────────────────────────────

    #[test]
    fn snapshot_reflects_state_volume_and_queue_len() {
        let mut state = default_state();
        state.playback.volume = 42;
        state.queue.songs = vec![lx_core::model::song::SongInfo::new(
            "1".to_string(),
            lx_core::model::source::SourceId::Bili,
            "A".to_string(),
            "B".to_string(),
        )];
        let snapshot = build_snapshot(&state, "list-loop", 7);
        assert_eq!(snapshot.volume, 0.42);
        assert_eq!(snapshot.loop_status, "Playlist");
        assert!(!snapshot.shuffle);
        assert_eq!(snapshot.position_epoch, 7);
        assert!(snapshot.can_go_next, "队列非空即可下一首");
    }

    #[test]
    fn idle_state_without_song_reports_stopped_default_track() {
        let state = default_state();
        let snapshot = build_snapshot(&state, "none", 0);
        assert_eq!(snapshot.playback_status, "Stopped");
        assert_eq!(
            snapshot.track_path,
            "/org/mpris/MediaPlayer2/TrackList/NoTrack"
        );
        assert!(!snapshot.can_go_next, "空队列不可切歌");
    }

    // ── translate_command ─────────────────────────────────────────────

    fn playback(state: PlayerState) -> PlaybackSnapshot {
        PlaybackSnapshot {
            state,
            ..PlaybackSnapshot::default()
        }
    }

    #[test]
    fn play_resumes_when_paused_and_starts_current_when_idle() {
        expect_command(
            translate_command(&MediaCommand::Play, &playback(PlayerState::Paused)),
            &ApplicationCommand::Resume,
        );
        expect_command(
            translate_command(&MediaCommand::Play, &playback(PlayerState::Idle)),
            &ApplicationCommand::PlayCurrent,
        );
        expect_command(
            translate_command(&MediaCommand::Play, &playback(PlayerState::Stopped)),
            &ApplicationCommand::PlayCurrent,
        );
        // 已在播放/加载中：无需动作。
        expect_none(translate_command(
            &MediaCommand::Play,
            &playback(PlayerState::Playing),
        ));
        expect_none(translate_command(
            &MediaCommand::Play,
            &playback(PlayerState::Loading),
        ));
    }

    #[test]
    fn pause_only_when_active() {
        expect_command(
            translate_command(&MediaCommand::Pause, &playback(PlayerState::Playing)),
            &ApplicationCommand::Pause,
        );
        expect_command(
            translate_command(&MediaCommand::Pause, &playback(PlayerState::Loading)),
            &ApplicationCommand::Pause,
        );
        expect_none(translate_command(
            &MediaCommand::Pause,
            &playback(PlayerState::Paused),
        ));
        expect_none(translate_command(
            &MediaCommand::Pause,
            &playback(PlayerState::Idle),
        ));
    }

    #[test]
    fn toggle_covers_all_four_player_states() {
        expect_command(
            translate_command(&MediaCommand::Toggle, &playback(PlayerState::Playing)),
            &ApplicationCommand::Pause,
        );
        expect_command(
            translate_command(&MediaCommand::Toggle, &playback(PlayerState::Loading)),
            &ApplicationCommand::Pause,
        );
        expect_command(
            translate_command(&MediaCommand::Toggle, &playback(PlayerState::Paused)),
            &ApplicationCommand::Resume,
        );
        expect_command(
            translate_command(&MediaCommand::Toggle, &playback(PlayerState::Idle)),
            &ApplicationCommand::PlayCurrent,
        );
        expect_command(
            translate_command(&MediaCommand::Toggle, &playback(PlayerState::Stopped)),
            &ApplicationCommand::PlayCurrent,
        );
    }

    #[test]
    fn next_previous_stop_pass_through() {
        expect_command(
            translate_command(&MediaCommand::Next, &playback(PlayerState::Playing)),
            &ApplicationCommand::Next,
        );
        expect_command(
            translate_command(&MediaCommand::Previous, &playback(PlayerState::Playing)),
            &ApplicationCommand::Previous,
        );
        expect_command(
            translate_command(&MediaCommand::Stop, &playback(PlayerState::Playing)),
            &ApplicationCommand::Stop,
        );
    }

    #[test]
    fn seek_by_translates_relative_to_snapshot_position() {
        let mut snapshot = playback(PlayerState::Playing);
        snapshot.position = Duration::from_secs(30);
        expect_command(
            translate_command(&MediaCommand::SeekBy(5_000_000), &snapshot),
            &ApplicationCommand::Seek(Duration::from_secs(35)),
        );
        // 后退越过 0：截到 0。
        expect_command(
            translate_command(&MediaCommand::SeekBy(-60_000_000), &snapshot),
            &ApplicationCommand::Seek(Duration::ZERO),
        );
        // 从 0 后退同样截到 0。
        snapshot.position = Duration::ZERO;
        expect_command(
            translate_command(&MediaCommand::SeekBy(-1_000_000), &snapshot),
            &ApplicationCommand::Seek(Duration::ZERO),
        );
    }

    #[test]
    fn set_position_passes_through_as_absolute_seek() {
        expect_command(
            translate_command(
                &MediaCommand::SetPosition(Duration::from_secs(12)),
                &playback(PlayerState::Paused),
            ),
            &ApplicationCommand::Seek(Duration::from_secs(12)),
        );
    }

    #[test]
    fn set_volume_scales_to_0_100_and_clamps() {
        expect_command(
            translate_command(
                &MediaCommand::SetVolume(0.5),
                &playback(PlayerState::Playing),
            ),
            &ApplicationCommand::SetVolume(50),
        );
        // 越界 clamp 到 [0,1]。
        expect_command(
            translate_command(
                &MediaCommand::SetVolume(2.0),
                &playback(PlayerState::Playing),
            ),
            &ApplicationCommand::SetVolume(100),
        );
        expect_command(
            translate_command(
                &MediaCommand::SetVolume(-1.0),
                &playback(PlayerState::Playing),
            ),
            &ApplicationCommand::SetVolume(0),
        );
    }

    #[test]
    fn quit_is_not_executed_by_gui_bridge() {
        expect_none(translate_command(
            &MediaCommand::Quit,
            &playback(PlayerState::Playing),
        ));
    }

    // ── BridgeEpoch ───────────────────────────────────────────────────

    fn snapshot_with_track(track_path: &str) -> MediaSnapshot {
        MediaSnapshot {
            track_path: track_path.to_string(),
            ..MediaSnapshot::default()
        }
    }

    #[test]
    fn epoch_bumps_on_generation_change() {
        let mut epoch = BridgeEpoch::default();
        let snapshot = snapshot_with_track("/track/a");
        assert_eq!(epoch.advance(&snapshot, 1), 1, "首次观测即建立基线");
        assert_eq!(epoch.advance(&snapshot, 1), 1, "无变化不推进");
        assert_eq!(epoch.advance(&snapshot, 2), 2, "generation 变化推进一次");
    }

    #[test]
    fn epoch_bumps_once_when_track_and_generation_change_together() {
        let mut epoch = BridgeEpoch::default();
        assert_eq!(epoch.advance(&snapshot_with_track("/track/a"), 1), 1);
        // 换曲：generation 与 trackid 同帧变化只推进一次，不重复发 seeked。
        assert_eq!(epoch.advance(&snapshot_with_track("/track/b"), 2), 2);
    }

    #[test]
    fn epoch_bumps_on_seek_hint_and_clears_it() {
        let mut epoch = BridgeEpoch::default();
        let snapshot = snapshot_with_track("/track/a");
        assert_eq!(epoch.advance(&snapshot, 1), 1);
        epoch.seek_hint = true;
        assert_eq!(epoch.advance(&snapshot, 1), 2, "seek 提示推进一次");
        assert_eq!(epoch.advance(&snapshot, 1), 2, "提示已消费，不再推进");
    }

    #[test]
    fn playing_drift_beyond_threshold_is_seek() {
        let mut epoch = BridgeEpoch::default();
        epoch.observe_position(PlayerState::Playing, Duration::from_secs(10));
        // 时间正常推进：漂移小，不是 seek。
        std::thread::sleep(Duration::from_millis(30));
        epoch.observe_position(PlayerState::Playing, Duration::from_secs_f64(10.03));
        assert!(!epoch.seek_hint);
        // 突然前进 10s：超出 1.5s 阈值，判定为 seek。
        epoch.observe_position(PlayerState::Playing, Duration::from_secs(20));
        assert!(epoch.seek_hint);
    }

    #[test]
    fn paused_position_change_is_seek() {
        let mut epoch = BridgeEpoch::default();
        epoch.observe_position(PlayerState::Paused, Duration::from_secs(10));
        epoch.observe_position(PlayerState::Paused, Duration::from_secs(10));
        assert!(!epoch.seek_hint, "暂停中位置不动不是 seek");
        epoch.observe_position(PlayerState::Paused, Duration::from_secs(25));
        assert!(epoch.seek_hint, "暂停中位置变化必然来自 seek");
    }

    #[test]
    fn loading_and_stopped_observations_never_hint() {
        let mut epoch = BridgeEpoch::default();
        // Loading 期位置可能停滞/回退（加载而非跳转），不做判定。
        epoch.observe_position(PlayerState::Loading, Duration::ZERO);
        epoch.observe_position(PlayerState::Loading, Duration::from_secs(30));
        assert!(!epoch.seek_hint);
        // Stopped 重置基线。
        epoch.observe_position(PlayerState::Stopped, Duration::ZERO);
        assert!(epoch.last_observation.is_none());
    }

    #[test]
    fn baseline_resets_on_state_transition() {
        let mut epoch = BridgeEpoch::default();
        epoch.observe_position(PlayerState::Playing, Duration::from_secs(10));
        // 暂停后再恢复：状态转换重置基线，恢复后的正常位置不判为 seek。
        epoch.observe_position(PlayerState::Paused, Duration::from_secs(10));
        std::thread::sleep(Duration::from_millis(20));
        epoch.observe_position(PlayerState::Playing, Duration::from_secs_f64(10.01));
        assert!(!epoch.seek_hint);
    }

    #[test]
    fn instant_baseline_is_recent() {
        // 防御：确认 Instant::now 与 elapsed 组合在 Windows//Linux 一致可用。
        let at = Instant::now();
        assert!(at.elapsed() < Duration::from_secs(1));
    }
}
